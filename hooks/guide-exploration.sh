#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hd_read_input

hd_should_remind "$session_id" "$transcript" "honeydew-ai:model-exploration" || exit 0

hd_emit "This session is exploring the Honeydew semantic model. If you have not already loaded the 'honeydew-ai:model-exploration' skill, invoke the Skill tool with skill 'honeydew-ai:model-exploration' for guidance on discovery workflows and available MCP tools."
