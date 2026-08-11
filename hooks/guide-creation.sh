#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

skill_hint=""

case "$tool_name" in
  *create_context_item*|*update_context_item*)
    skill_hint="honeydew-ai:context-item-creation"
    ;;
  *import_tables*)
    skill_hint="honeydew-ai:entity-creation"
    ;;
  *create_entity*)
    skill_hint="honeydew-ai:entity-creation"
    ;;
  *create_object*|*update_object*)
    # Detect object type by searching yaml_text with jq (avoids newline issues)
    skill_hint=$(printf '%s' "$hd_input" | jq -r '
      (.tool_input.yaml_text // "") as $y
      | if   ($y | test("type:\\s*metric"))    then "honeydew-ai:metric-creation"
        elif ($y | test("type:\\s*attribute")) then "honeydew-ai:attribute-creation"
        elif ($y | test("type:\\s*domain"))    then "honeydew-ai:domain-creation"
        elif ($y | test("type:\\s*entity"))    then "honeydew-ai:entity-creation"
        elif ($y | test("relations:"))          then "honeydew-ai:relation-creation"
        else "" end' 2>/dev/null || true)
    ;;
esac

# additionalContext arrives with the tool result, so this steers the calls that
# follow rather than gating the one in flight -- hence "before your next", not
# "BEFORE proceeding".
if [ -n "$skill_hint" ]; then
  hd_should_remind "$session_id" "$transcript" "$skill_hint" || exit 0
  hd_emit "This session is creating or modifying Honeydew objects. If you have not already loaded the relevant skill, invoke the Skill tool with skill '$skill_hint' before your next create or update call. The skill contains critical guidance on required fields, naming conventions, and correct YAML structure. After creation, always run the 'honeydew-ai:validation' skill to verify the object works correctly."
else
  # No detected type means there is no single skill to check the transcript
  # for, so this path is marker-gated only.
  hd_first_time "$session_id" "$transcript" "creation-generic" || exit 0
  hd_emit "This session is creating or modifying Honeydew objects. If you have not already loaded the relevant skill, invoke the appropriate Skill tool before your next create or update call. Available skills: honeydew-ai:metric-creation (metrics), honeydew-ai:attribute-creation (attributes), honeydew-ai:entity-creation (entities), honeydew-ai:relation-creation (relations), honeydew-ai:domain-creation (domains), honeydew-ai:context-item-creation (context items). After creation, always run honeydew-ai:validation."
fi
