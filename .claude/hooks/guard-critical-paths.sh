#!/usr/bin/env bash
# PreToolUse on Edit and Write. An edit to a critical path or to a dependency
# file pauses until the person at the keyboard approves it.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
TIERS_FILE="$PROJECT_DIR/tiers.txt"
# shellcheck source=scripts/lib/tiers.sh
source "$PROJECT_DIR/scripts/lib/tiers.sh"

file=$(jq -r '.tool_input.file_path // ""')
[[ -z "$file" ]] && exit 0
file=$(rel_path "$file")

if is_manifest "$file"; then
  ask "$file is a dependency file. Approve only if you chose this dependency change yourself."
fi
read -r _tier critical <<<"$(tiers_lookup "$file")"
if [[ "$critical" == "yes" ]]; then
  ask "$file is on a critical path (tiers.txt). A code owner will have to approve this change."
fi
exit 0
