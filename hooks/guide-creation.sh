#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

# A relations: key that actually opens a block, as opposed to the word appearing
# in a description or an empty relations: [] carried through a round trip. The
# key must start its line and be followed by a list item, because the payloads
# this has to tell apart differ only in that: "relations:\n  - name: customers"
# is relation work, "relations: []" on an entity that has none is not.
rels_re='(^|\n)[ \t]*relations:[ \t]*(\n[ \t]*-|\[[ \t]*\{)'

skill_hints=""

case "$tool_name" in
  *create_context_item*|*update_context_item*)
    skill_hints="honeydew-ai:context-item-creation"
    ;;
  *import_tables*)
    skill_hints="honeydew-ai:entity-creation"
    ;;
  *create_entity*)
    # entity_yaml, not yaml_text -- and it may carry relations inline, which is
    # the same both-skills payload the create_object branch handles below.
    # Falls back to the entity skill alone if the payload will not parse.
    skill_hints=$(printf '%s' "$hd_input" | jq -r --arg re "$rels_re" '
      ["honeydew-ai:entity-creation"]
      + (if ((.tool_input.entity_yaml // "") | test($re))
         then ["honeydew-ai:relation-creation"] else [] end)
      | .[]' 2>/dev/null) || skill_hints=""
    [ -n "$skill_hints" ] || skill_hints="honeydew-ai:entity-creation"
    ;;
  *create_object*|*update_object*)
    # Detect object type by searching yaml_text with jq (avoids newline issues).
    #
    # One type wins, as before -- a metric is not an entity, and testing every
    # branch unconditionally made any YAML that merely contained the word
    # relations: demand the relation skill. The entity branch is the exception:
    # a relation is not a standalone object, it lives inside its source
    # entity's YAML, so that one payload is governed by two skills at once and
    # emits both. entity-creation covers the source and key, relation-creation
    # the join and the rule that rewriting a relations: block drops whatever it
    # omits. An if/elif chain could only ever name one of them, and testing
    # type: entity first made the relation branch unreachable for every payload
    # the relation-creation skill documents.
    skill_hints=$(printf '%s' "$hd_input" | jq -r --arg re "$rels_re" '
      (.tool_input.yaml_text // "") as $y
      | if   ($y | test("type:\\s*metric"))    then ["honeydew-ai:metric-creation"]
        elif ($y | test("type:\\s*attribute")) then ["honeydew-ai:attribute-creation"]
        elif ($y | test("type:\\s*domain"))    then ["honeydew-ai:domain-creation"]
        elif ($y | test("type:\\s*entity"))
          then ["honeydew-ai:entity-creation"]
               + (if ($y | test($re)) then ["honeydew-ai:relation-creation"] else [] end)
        elif ($y | test($re))                  then ["honeydew-ai:relation-creation"]
        else [] end
      | .[]' 2>/dev/null || true)
    ;;
esac

hints=()
while IFS= read -r hint; do
  [ -n "$hint" ] || continue
  # Never block on a skill the model has no way to load.
  hd_skill_available "$hint" || continue
  hints+=("$hint")
done <<< "$skill_hints"

if [ ${#hints[@]} -gt 0 ]; then
  # One marker per (session, payload shape), claimed before anything reads the
  # transcript. Two properties depend on claiming it here rather than per skill:
  #
  #   * A batch of parallel tool calls has exactly one winner, so a two-skill
  #     payload produces one deny naming both. Racing per-skill markers split
  #     that into two denies of half the answer each.
  #   * The transcript scan stays behind the cheap check, once per shape, not
  #     once per skill per call.
  #
  # The bound is therefore at most one deny per (session, shape) rather than per
  # (session, skill): a session can be blocked once for an entity write and once
  # for an entity-with-relations write. Both name what to load, and both are
  # bounded by the handful of payload shapes that exist.
  key="creation"
  for hint in "${hints[@]}"; do key="$key+${hint#*:}"; done
  hd_first_time "$session_id" "$transcript" "$key" || exit 0

  missing=()
  for hint in "${hints[@]}"; do
    hd_skill_loaded "$transcript" "$hint" || missing+=("$hint")
  done
  [ ${#missing[@]} -gt 0 ] || exit 0

  if [ ${#missing[@]} -gt 1 ]; then
    subject="skills, which are"; covers="They cover"; without="them"
  else
    subject="skill, which is"; covers="The skill covers"; without="it"
  fi
  hd_deny "Creating or modifying this Honeydew object needs the $(hd_quote_list "${missing[@]}") $subject not loaded in this session. $covers required fields, naming conventions and correct YAML structure, and writing the object without $without risks a malformed definition. $(hd_retry_note "${missing[@]}") After the object is created, run the 'honeydew-ai:validation' skill to verify it works."
else
  # No detected type means no specific skill to require. Blocking on an
  # unrecognised payload would stop work over a guess, so this path stays
  # advisory: name the candidates once and let the call through.
  hd_first_time "$session_id" "$transcript" "creation-generic" || exit 0
  hd_emit "This session is creating or modifying Honeydew objects. If you have not already loaded the relevant skill, load the appropriate skill before your next create or update call. Available skills: honeydew-ai:metric-creation (metrics), honeydew-ai:attribute-creation (attributes), honeydew-ai:entity-creation (entities), honeydew-ai:relation-creation (relations), honeydew-ai:domain-creation (domains), honeydew-ai:context-item-creation (context items). After creation, always run honeydew-ai:validation."
fi
