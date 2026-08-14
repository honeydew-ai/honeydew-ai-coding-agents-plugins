#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

skill_hints=""

case "$tool_name" in
  *create_context_item*|*update_context_item*)
    skill_hints="honeydew-ai:context-item-creation"
    ;;
  *import_tables*)
    skill_hints="honeydew-ai:entity-creation"
    ;;
  *create_entity*)
    skill_hints="honeydew-ai:entity-creation"
    ;;
  *create_object*|*update_object*)
    # Detect object type by searching yaml_text with jq (avoids newline issues).
    #
    # Every match is emitted, one skill per line, rather than the first hit
    # winning. A relation is not a standalone object -- it lives inside its
    # source entity's YAML -- so a relation write is always also an entity
    # write, and the two skills govern different halves of it: entity-creation
    # the source and key, relation-creation the join and the rule that
    # rewriting the relations: block drops whatever it omits. An if/elif chain
    # had to order those two, and testing type: entity first made the
    # relation-creation branch unreachable for every payload the
    # relation-creation skill documents.
    skill_hints=$(printf '%s' "$hd_input" | jq -r '
      (.tool_input.yaml_text // "") as $y
      | [ (if ($y | test("type:\\s*metric"))    then "honeydew-ai:metric-creation"    else empty end),
          (if ($y | test("type:\\s*attribute")) then "honeydew-ai:attribute-creation" else empty end),
          (if ($y | test("type:\\s*domain"))    then "honeydew-ai:domain-creation"    else empty end),
          (if ($y | test("type:\\s*entity"))    then "honeydew-ai:entity-creation"    else empty end),
          (if ($y | test("relations:"))         then "honeydew-ai:relation-creation"  else empty end) ]
      | .[]' 2>/dev/null || true)
    ;;
esac

if [ -n "$skill_hints" ]; then
  # Check every hinted skill before deciding, so a payload governed by two
  # skills produces one deny naming both rather than a deny per retry. Each
  # hd_should_block call claims its own per-skill marker, keeping the
  # at-most-one-deny-per-(session, skill) bound intact.
  missing=""
  while IFS= read -r hint; do
    [ -n "$hint" ] || continue
    if hd_should_block "$session_id" "$transcript" "$hint"; then
      missing="${missing:+$missing }$hint"
    fi
  done <<< "$skill_hints"

  [ -n "$missing" ] || exit 0

  set -- $missing
  if [ $# -gt 1 ]; then
    subject="skills, which are"; covers="They cover"; without="them"
  else
    subject="skill, which is"; covers="The skill covers"; without="it"
  fi
  hd_deny "Creating or modifying this Honeydew object needs the $(hd_quote_list "$@") $subject not loaded in this session. $covers required fields, naming conventions and correct YAML structure, and writing the object without $without risks a malformed definition. $(hd_retry_note "$@") After the object is created, run the 'honeydew-ai:validation' skill to verify it works."
else
  # No detected type means no specific skill to require. Blocking on an
  # unrecognised payload would stop work over a guess, so this path stays
  # advisory: name the candidates once and let the call through.
  hd_first_time "$session_id" "$transcript" "creation-generic" || exit 0
  hd_emit "This session is creating or modifying Honeydew objects. If you have not already loaded the relevant skill, load the appropriate skill before your next create or update call. Available skills: honeydew-ai:metric-creation (metrics), honeydew-ai:attribute-creation (attributes), honeydew-ai:entity-creation (entities), honeydew-ai:relation-creation (relations), honeydew-ai:domain-creation (domains), honeydew-ai:context-item-creation (context items). After creation, always run honeydew-ai:validation."
fi
