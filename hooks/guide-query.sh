#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

hd_should_remind "$session_id" "$transcript" "honeydew-ai:query" || exit 0

case "$tool_name" in
  *ask_deep_analysis*)
    hd_emit "You are about to run a deep analysis query. If you have not already loaded the 'honeydew-ai:query' skill, invoke the Skill tool with skill 'honeydew-ai:query' BEFORE proceeding. The skill explains the three query methods (structured, natural language, deep analysis) and their correct parameters."
    ;;
  *get_data_from_fields*|*get_sql_from_fields*)
    hd_emit "You are about to query data through Honeydew. If you have not already loaded the 'honeydew-ai:query' skill, invoke the Skill tool with skill 'honeydew-ai:query' BEFORE proceeding. The skill explains the three query methods and their correct parameters. For filter expressions, also load 'honeydew-ai:filtering'."
    ;;
  *)
    hd_emit "You are about to query data through Honeydew. If you have not already loaded the 'honeydew-ai:query' skill, invoke the Skill tool with skill 'honeydew-ai:query' BEFORE proceeding. The skill explains the three query methods and their correct parameters."
    ;;
esac
