#!/bin/bash
# Shared helpers for the Honeydew PreToolUse guide hooks.
#
# Reminders are emitted as additionalContext (model-only) rather than
# systemMessage, which renders in the user's transcript on every tool call.
# Each reminder fires at most once per session, and not at all once the
# relevant skill has been loaded.

# Per-session marker directory.
hd_state_dir() {
  local sid="${1:-nosession}"
  printf '%s/honeydew-ai-hooks/%s' "${TMPDIR:-/tmp}" "${sid//[^A-Za-z0-9._-]/_}"
}

# hd_skill_loaded <transcript_path> <skill>
# Matches the Skill tool_use record or the slash-command form specifically.
# A bare skill-name grep would also match our own reminder text, so the hook
# would silence itself after the first fire without the skill ever loading.
hd_skill_loaded() {
  local transcript="$1" skill="$2"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
  grep -qF "\"name\":\"Skill\",\"input\":{\"skill\":\"$skill\"" "$transcript" && return 0
  grep -qF "<command-name>/$skill</command-name>" "$transcript" && return 0
  return 1
}

# hd_first_time <session_id> <key>
# True once per (session, key); creates the marker as a side effect.
hd_first_time() {
  local dir marker
  dir="$(hd_state_dir "$1")"
  marker="$dir/${2//[^A-Za-z0-9._-]/_}"
  [ -e "$marker" ] && return 1
  mkdir -p "$dir" 2>/dev/null || return 0
  find "${TMPDIR:-/tmp}/honeydew-ai-hooks" -maxdepth 1 -type d -mtime +7 \
    -exec rm -rf {} + 2>/dev/null || true
  : > "$marker" 2>/dev/null || true
  return 0
}

# hd_should_remind <session_id> <transcript_path> <skill>
# Marker first: after the first matching tool call in a session this costs a
# stat() and skips the transcript scan entirely.
hd_should_remind() {
  hd_first_time "$1" "$3" || return 1
  ! hd_skill_loaded "$2" "$3"
}

# hd_read_input -- parse the hook payload on stdin with a single jq call,
# setting tool_name / session_id / transcript / yaml_text.
hd_read_input() {
  local input
  input=$(cat)
  {
    read -r tool_name
    read -r session_id
    read -r transcript
  } < <(printf '%s' "$input" | jq -r '
    (.tool_name // ""), (.session_id // ""), (.transcript_path // "")')
  hd_input="$input"
}

# hd_emit <text>
hd_emit() {
  jq -n --arg ctx "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
}
