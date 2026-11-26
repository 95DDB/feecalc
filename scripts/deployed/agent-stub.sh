#!/usr/bin/env bash
# Placeholder for the agent that tries out the deployed build.
# The real job gets the environment address and the runnable scenarios, plays
# them, and writes one reproduction script per failure into $REPRO_OUT.
# CI then runs those scripts; only a failure that reproduces blocks the merge.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# The scenarios whose rules are all in rules-implemented.txt.
runnable=$(./scripts/scenarios-runnable.sh)
count=$(grep -c . <<<"$runnable" || true)
echo "Deployed-check agent is not configured. No scenarios were played."
echo "It would have played $count scenario(s):"
[[ -z "$runnable" ]] || sed 's/^/  /' <<<"$runnable"
