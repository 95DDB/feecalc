#!/usr/bin/env bash
# PostToolUse on Edit and Write. Formats the file that just changed, when the
# Makefile has a fmt target. Never blocks: the edit has already happened.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

file=$(jq -r '.tool_input.file_path // ""')
[[ -z "$file" || ! -f "$file" ]] && exit 0
cd "$PROJECT_DIR" || exit 0
if make -n fmt >/dev/null 2>&1; then
  make -s fmt FILE="$(rel_path "$file")" >/dev/null 2>&1 || true
fi
exit 0
