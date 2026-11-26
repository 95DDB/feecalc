#!/usr/bin/env bash
# Checks rules-implemented.txt, the list of rules this branch's code claims to
# implement: one rule ID per line, sorted, none twice.
# Usage: check-implemented-rules.sh [base-ref]
# With a base ref it also refuses a change that takes a rule off the list. A
# rule leaves the list only when its requirement changed, and then the same
# change updates its scenarios, which a code owner approves.
# Exit codes: 0 fine, or the repository has no list · 1 a problem
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

LIST=rules-implemented.txt
[[ -f "$LIST" ]] || { echo "No $LIST: nothing to check."; exit 0; }
ids() { grep -vE '^[[:space:]]*(#|$)' || true; }

fail=0
current=$(ids < "$LIST")
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[A-Z][A-Z0-9]*(-[A-Z][A-Z0-9]*)+-[0-9]{2,}$ ]] ||
    { echo "$LIST: '$line' is not a rule ID such as GV1-KEY-07."; fail=1; }
done <<<"$current"
[[ "$current" == "$(LC_ALL=C sort <<<"$current")" ]] || { echo "$LIST: the rules are not sorted."; fail=1; }
twice=$(LC_ALL=C sort <<<"$current" | uniq -d | tr '\n' ' ')
[[ -z "$twice" ]] || { echo "$LIST: listed more than once: $twice"; fail=1; }

base="${1:-}"
if [[ -n "$base" ]]; then
  from=$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")
  gone=$(LC_ALL=C comm -23 <(git show "$from:$LIST" 2>/dev/null | ids | LC_ALL=C sort) <(LC_ALL=C sort <<<"$current") | tr '\n' ' ')
  if [[ -n "${gone// /}" ]] && [[ -z "$(git diff --name-only "$from" HEAD -- scenarios/)" ]]; then
    echo "$LIST: left the list: $gone"
    echo "A rule leaves the list only when its requirement changed, together with a change to its scenarios."
    fail=1
  fi
fi

(( fail )) && exit 1
echo "$LIST: well formed."
