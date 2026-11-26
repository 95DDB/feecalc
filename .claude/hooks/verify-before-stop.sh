#!/usr/bin/env bash
# Stop. Before the agent reports a task done, run `make verify` when the
# working tree has changes. A failure sends the output back to the agent.
set -uo pipefail
source "$(dirname "$0")/lib.sh"

# Do not loop: if this hook already sent the agent back once, let it stop.
[[ "$(jq -r '.stop_hook_active // false')" == "true" ]] && exit 0

cd "$PROJECT_DIR" || exit 0
[[ -z "$(git status --porcelain 2>/dev/null)" ]] && exit 0
make -n verify >/dev/null 2>&1 || exit 0

if ! out=$(make -s verify 2>&1); then
  { echo "make verify failed. Fix the code, not the check, then finish."
    echo "--- last lines of output ---"
    tail -n 40 <<<"$out"; } >&2
  exit 2
fi
exit 0
