#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

hd_should_remind "$session_id" "$transcript" "honeydew-ai:query" || exit 0

# additionalContext is delivered with the tool result, so this cannot gate the
# call in flight -- it can only steer the calls that follow. The wording says so
# rather than promising ordering the mechanism does not provide.
#
# Every branch names the filtering skill: the reminder fires once per session,
# so whichever query tool runs first has to carry the whole hint.
case "$tool_name" in
  *initiate_analysis*)
    hd_emit "This session is running a deep analysis query through Honeydew. If you have not already loaded the 'honeydew-ai:query' skill, invoke the Skill tool with skill 'honeydew-ai:query' before your next Honeydew call. The skill explains the three query methods (structured, natural language, deep analysis) and their correct parameters. For filter expressions, also load 'honeydew-ai:filtering'."
    ;;
  *)
    hd_emit "This session is querying data through Honeydew. If you have not already loaded the 'honeydew-ai:query' skill, invoke the Skill tool with skill 'honeydew-ai:query' before your next Honeydew call. The skill explains the three query methods and their correct parameters. For filter expressions, also load 'honeydew-ai:filtering'."
    ;;
esac
