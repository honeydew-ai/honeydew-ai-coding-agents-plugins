#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

hd_should_block "$session_id" "$transcript" "honeydew-ai:model-exploration" || exit 0

hd_deny "Exploring the Honeydew semantic model needs the 'honeydew-ai:model-exploration' skill, which is not loaded in this session. The skill covers discovery workflows and which MCP tool answers which question. $(hd_retry_note honeydew-ai:model-exploration)"
