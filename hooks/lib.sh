#!/bin/bash
# Shared helpers for the Honeydew PreToolUse guide hooks.
#
# These hooks gate a tool call on its skill being loaded. additionalContext
# cannot do that -- it is delivered with the tool result, after the call it was
# attached to has already run -- so the only mechanism that establishes the
# ordering "skill first, then call" is permissionDecision: deny, which blocks
# the call and hands the reason back to the model to act on and retry.
#
# Denying is therefore deliberately conservative:
#
#   * At most one deny per (session, skill). The marker is claimed by the deny
#     itself, so a model that retries without loading the skill is never
#     blocked a second time and cannot be locked out of Honeydew.
#   * Uncertainty about the hook's own footing allows the call: a skill that is
#     not installed, state that cannot be recorded, a payload that will not
#     parse. None of these block work on a hook's bad day.
#   * Not being able to prove the skill is loaded -- no transcript, or a
#     transcript without a load record -- does block, once. That is the gate
#     doing its job, and it is bounded by the one-block-per-skill rule.
#
# Known limitations of reading the transcript to decide whether a skill loaded:
#
#   * It keeps pre-compaction records, and markers live for a week, so after
#     /compact or --resume a skill can read as loaded while its content is gone.
#   * A transcript that quotes a load pattern as ordinary text -- a session
#     working on these hooks, printing '<command-name>/honeydew-ai:query...'
#     to check it -- reads as a load. Only self-referential sessions like that
#     hit it, and it fails open (allows the call), so it costs a gate, not work.
#     Fixing it properly means parsing each record structurally instead of
#     grepping raw text.

HD_STATE_ROOT="${TMPDIR:-/tmp}/honeydew-ai-hooks"

# Where the skills ship, resolved next to these hooks. hooks.json invokes the
# scripts by absolute path, and bash's logical cd resolves ../skills correctly
# even through the plugins/honeydew-ai/hooks wrapper symlink, so no plugin-root
# env fallback is needed: if that path did not expand, this file was never
# sourced in the first place.
HD_SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" 2>/dev/null && pwd)" || HD_SKILLS_DIR=""

# Filesystem-safe form of an arbitrary string.
hd_slug() { printf '%s' "${1//[^A-Za-z0-9._-]/_}"; }

# hd_state_dir <session_id> <transcript_path>
# Marker directory for this session. Falls back to the transcript path when the
# payload carries no session_id, so unrelated sessions never share a key.
hd_state_dir() {
  local key="${1:-}"
  [ -n "$key" ] || key="${2:-}"
  [ -n "$key" ] || return 1
  printf '%s/%s' "$HD_STATE_ROOT" "$(hd_slug "$key")"
}

# Drop marker directories from sessions older than a week. -mindepth 1 keeps
# find from matching -- and rm -rf'ing -- the state root itself.
hd_sweep_old_state() {
  find "$HD_STATE_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +7 \
    -exec rm -rf {} + 2>/dev/null || true
}

# hd_skill_available <skill>  -- "honeydew-ai:query" -> skills/query/SKILL.md
# Never block on a skill the model has no way to load.
hd_skill_available() {
  [ -n "$HD_SKILLS_DIR" ] || return 1
  [ -f "$HD_SKILLS_DIR/${1#*:}/SKILL.md" ]
}

# hd_skill_loaded <transcript_path> <skill>
# Claude Code records a load as a Skill tool_use record or a slash command;
# Codex records it as a [$name](...) markdown reference.
#
# Every pattern must be structural -- tied to the shape of a record that only
# exists because a skill was loaded. A SKILL.md *path* is emphatically not such
# a pattern, and matching one is a mistake worth naming: Codex opens every
# session with a catalog of installed skills, each listed with its own
# "(file: .../skills/<name>/SKILL.md)", so a path match reads as "loaded" from
# turn 1 and no call is ever gated. The same substring appears whenever an
# agent greps or edits this repo, which silently disabled the gate on Claude
# Code too. A skill being listed, read, or discussed is not a skill in context.
#
# Consequence on Codex, accepted deliberately: the catalog gives the model
# descriptions, not skill content, so "not loaded" is usually the truth there
# and the first Honeydew call per skill is blocked once. That is the design --
# one bounded block, then the retry proceeds.
#
# Each harness is matched only against its own forms. Pooling them meant a
# Claude Code session that merely printed Codex's [$name](...) syntax -- writing
# these hooks, for one -- suppressed its own gate.
hd_skill_loaded() {
  local transcript="$1" skill="$2" short="${2#*:}"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
  if head -n 1 -- "$transcript" 2>/dev/null | grep -qE '"type": *"session_meta"'; then
    # Codex rollout: a load is a [$name](...) reference the user actually sent,
    # so the match is scoped to a user_message record rather than loose prose.
    grep -qE "\"type\": *\"user_message\".*\[\\\$${short}\]\(" -- "$transcript"
  else
    grep -qF -e "\"name\":\"Skill\",\"input\":{\"skill\":\"$skill\"" \
             -e "<command-name>/$skill</command-name>" -- "$transcript"
  fi
}

# hd_first_time <session_id> <transcript_path> <key>
# True at most once per (session, key). mkdir is the atomic test-and-set: a
# batch of parallel tool calls races here, and only one invocation may win.
hd_first_time() {
  local dir marker
  dir="$(hd_state_dir "$1" "$2")" || return 1
  marker="$dir/$(hd_slug "$3")"
  [ -d "$marker" ] && return 1
  mkdir -p "$dir" 2>/dev/null || return 1
  hd_sweep_old_state
  mkdir "$marker" 2>/dev/null || return 1
  return 0
}

# hd_should_block <session_id> <transcript_path> <skill>
# Cheap checks first, so the transcript scan runs at most once per session.
hd_should_block() {
  hd_skill_available "$3" || return 1
  hd_first_time "$1" "$2" "$3" || return 1
  ! hd_skill_loaded "$2" "$3"
}

# hd_read_input -- parse the hook payload on stdin with a single jq call,
# setting hd_input plus tool_name / session_id / transcript. Absent or
# malformed input yields empty strings rather than a nonzero exit, and an
# empty session_id/transcript pair cannot claim a marker, so the call is
# allowed rather than blocked on an unreadable payload.
hd_read_input() {
  tool_name=""; session_id=""; transcript=""
  hd_input="$(cat)" || hd_input=""
  local parsed
  # agent_transcript_path is the subagent-turn fallback: without it a Honeydew
  # call inside a Codex subagent has no transcript to read and gets blocked once
  # for no reason. Defensive -- that payload shape is not verified here.
  parsed="$(printf '%s' "$hd_input" | jq -r '
    (.tool_name // ""),
    (.session_id // ""),
    (if (.transcript_path // "") != "" then .transcript_path
     else (.agent_transcript_path // "") end)' 2>/dev/null)" \
    || return 0
  {
    read -r tool_name || true
    read -r session_id || true
    read -r transcript || true
  } <<< "$parsed"
}

# hd_deny <reason> -- block this call and tell the model how to proceed.
# permissionDecisionReason is the current field; systemMessage is carried too so
# the reason still reaches the model on harnesses that only read that one. A
# blocked call is visible either way, and this fires at most once per skill.
hd_deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    },
    systemMessage: $r
  }'
}

# hd_emit <text> -- advisory only, for the case where no specific skill can be
# named and there is thus nothing to block on. additionalContext reaches the
# model without rendering in the transcript. No suppressOutput: Codex rejects
# that field on PreToolUse and would discard the whole payload.
hd_emit() {
  jq -n --arg ctx "$1" '{
    hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}
  }'
}

# hd_quote_list <item>... -- "'a'" / "'a' and 'b'" / "'a', 'b' and 'c'"
hd_quote_list() {
  local out=""
  while [ $# -gt 0 ]; do
    if [ -z "$out" ]; then
      out="'$1'"
    elif [ $# -eq 1 ]; then
      out="$out and '$1'"
    else
      out="$out, '$1'"
    fi
    shift
  done
  printf '%s' "$out"
}

# hd_retry_note <skill>... -- shared tail: say the block is one-shot, so a model
# that cannot load the skill does not conclude Honeydew is unavailable. Takes
# more than one skill because a single payload can need more than one: relations
# live inside entity YAML, so one write is governed by two skills.
hd_retry_note() {
  local list noun theirs
  list="$(hd_quote_list "$@")"
  noun="skill"; theirs="its"
  if [ $# -gt 1 ]; then noun="skills"; theirs="their"; fi
  printf "Load the %s %s -- the Skill tool on Claude Code, %s SKILL.md on Codex -- then repeat this call. This check blocks a call only once per session, so the retry will go through either way." "$list" "$noun" "$theirs"
}
