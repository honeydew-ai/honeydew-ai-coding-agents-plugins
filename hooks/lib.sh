#!/bin/bash
# Shared helpers for the Honeydew PreToolUse guide hooks.
#
# Reminders are emitted as additionalContext (model-only) rather than
# systemMessage, which renders in the user's transcript on every tool call.
# Each reminder fires at most once per session, and not at all once the
# relevant skill has been loaded.
#
# Known limitation: both suppression gates outlive the context they stand in
# for. The transcript keeps its pre-compaction records and markers live for a
# week, so after /compact or --resume a skill can read as "already loaded"
# while its content is no longer in context.

HD_STATE_ROOT="${TMPDIR:-/tmp}/honeydew-ai-hooks"

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

# hd_skill_loaded <transcript_path> <skill>
# Matches the Skill tool_use record or the slash-command form specifically.
# A bare skill-name grep would also match our own reminder text, so the hook
# would silence itself after the first fire without the skill ever loading.
hd_skill_loaded() {
  local transcript="$1" skill="$2"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
  grep -qF -e "\"name\":\"Skill\",\"input\":{\"skill\":\"$skill\"" \
           -e "<command-name>/$skill</command-name>" -- "$transcript"
}

# hd_first_time <session_id> <transcript_path> <key>
# True at most once per (session, key). mkdir is the atomic test-and-set: a
# batch of parallel tool calls races here, and only one invocation may win.
# Any failure to record state returns false, keeping the hook silent -- the
# repetition is the bug being fixed, so state trouble must not reinstate it.
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

# hd_should_remind <session_id> <transcript_path> <skill>
# Marker first: after the first matching tool call in a session this costs a
# stat() and skips the transcript scan entirely.
hd_should_remind() {
  hd_first_time "$1" "$2" "$3" || return 1
  ! hd_skill_loaded "$2" "$3"
}

# hd_read_input -- parse the hook payload on stdin with a single jq call,
# setting hd_input plus tool_name / session_id / transcript. Absent or
# malformed input yields empty strings rather than a nonzero exit: a hook that
# dies reports a failure to the user, which is the noise being removed here.
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

# hd_emit <text> -- additionalContext reaches the model; suppressOutput keeps
# the hook's own stdout out of the user's transcript.
hd_emit() {
  jq -n --arg ctx "$1" '{
    suppressOutput: true,
    hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}
  }'
}
