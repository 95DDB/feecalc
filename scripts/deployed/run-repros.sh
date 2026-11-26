#!/usr/bin/env bash
# Replays every confirmed failure from earlier deployed checks.
# Each script in tests/repro/ reproduces one failure an agent once found; it
# must exit 0 when the behavior is correct. One failing script blocks the merge.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

shopt -s nullglob
scripts=(tests/repro/*.sh)
if (( ${#scripts[@]} == 0 )); then
  echo "No repro scripts yet (tests/repro/ is empty)."; exit 0
fi

failed=0
for script in "${scripts[@]}"; do
  if bash "$script"; then echo "ok    $script"
  else echo "FAIL  $script"; failed=1; fi
done
exit $failed
