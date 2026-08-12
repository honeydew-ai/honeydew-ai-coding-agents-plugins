#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

hd_should_block "$session_id" "$transcript" "honeydew-ai:query" || exit 0

case "$tool_name" in
  *initiate_analysis*)
    hd_deny "This deep analysis call needs the 'honeydew-ai:query' skill, which is not loaded in this session. The skill explains the three query methods (structured, natural language, deep analysis) and their correct parameters. $(hd_retry_note honeydew-ai:query)"
    ;;
  *)
    hd_deny "This Honeydew query needs the 'honeydew-ai:query' skill, which is not loaded in this session. The skill explains the three query methods and their correct parameters; load 'honeydew-ai:filtering' as well if this query uses filter expressions. $(hd_retry_note honeydew-ai:query)"
    ;;
esac
