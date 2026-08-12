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
#   * Any uncertainty allows the call. A skill that is not installed, state
#     that cannot be recorded, a payload that will not parse -- each of these
#     lets the tool through rather than blocking work on a hook's bad day.
#
# Known limitation: the loaded-skill check reads the transcript, which keeps its
# pre-compaction records, and markers live for a week. After /compact or
# --resume a skill can read as loaded while its content is gone from context.

HD_STATE_ROOT="${TMPDIR:-/tmp}/honeydew-ai-hooks"

# Where the skills ship, resolved next to these hooks. Codex sets PLUGIN_ROOT
# (and CLAUDE_PLUGIN_ROOT for compatibility), so either serves as a fallback if
# the hook is ever invoked in a way that hides its own path.
HD_SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" 2>/dev/null && pwd)" \
  || HD_SKILLS_DIR="$(cd "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-/nonexistent}}/skills" 2>/dev/null && pwd)" \
  || HD_SKILLS_DIR=""

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
# Codex records a [$name](path/SKILL.md) reference or a read of the file itself.
# Both harnesses' forms are matched, since one set of scripts serves both.
#
# Every pattern is structural. Matching the bare skill name would also match
# this hook's own reason text, disabling the check without the skill ever
# loading -- which is why the short name is only ever matched inside [$...] or
# a SKILL.md path.
hd_skill_loaded() {
  local transcript="$1" skill="$2" short="${2#*:}"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
  grep -qF -e "\"name\":\"Skill\",\"input\":{\"skill\":\"$skill\"" \
           -e "<command-name>/$skill</command-name>" \
           -e "[\$$short]" \
           -e "skills/$short/SKILL.md" -- "$transcript"
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
  parsed="$(printf '%s' "$hd_input" | jq -r '
    (.tool_name // ""), (.session_id // ""), (.transcript_path // "")' 2>/dev/null)" \
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
# named and there is thus nothing to block on. Reaches the model without
# rendering in the transcript; suppressOutput states that explicitly.
hd_emit() {
  jq -n --arg ctx "$1" '{
    suppressOutput: true,
    hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}
  }'
}

# hd_retry_note <skill> -- shared tail: say the block is one-shot, so a model
# that cannot load the skill does not conclude Honeydew is unavailable.
hd_retry_note() {
  printf "Load the '%s' skill -- the Skill tool on Claude Code, its SKILL.md on Codex -- then repeat this call. This check blocks a call only once per session, so the retry will go through either way." "$1"
}
