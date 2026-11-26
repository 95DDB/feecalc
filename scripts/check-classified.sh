#!/usr/bin/env bash
# Fails when a top-level file or directory is missing from tiers.txt,
# or when tiers.txt holds an invalid or unsafe line.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/lib/tiers.sh
source scripts/lib/tiers.sh

fail=0

# 1. Every line is well formed, and Tier 1 is always critical.
while read -r path tier critical extra; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  if [[ -n "${extra:-}" || ! "$tier" =~ ^(1|2|3|-)$ || ! "$critical" =~ ^(yes|no)$ ]]; then
    echo "tiers.txt: bad line for '$path' (want: <path> <1|2|3|-> <yes|no>)"; fail=1
  elif [[ "$tier" == "1" && "$critical" != "yes" ]]; then
    echo "tiers.txt: '$path' is Tier 1, so it must be critical"; fail=1
  fi
done < "$TIERS_FILE"

# 2. Every tracked top-level entry is classified.
while read -r entry; do
  [[ -z "$entry" ]] && continue
  if [[ "$(tiers_lookup "$entry")" == "? ?" ]]; then
    echo "Not classified in tiers.txt: $entry"; fail=1
  fi
done < <(git ls-files | awk -F/ '{ print (NF > 1) ? $1 "/" : $1 }' | sort -u)

if [[ $fail -ne 0 ]]; then
  echo
  echo "Add the missing entries to tiers.txt with a tier and a critical flag."
  exit 1
fi
echo "tiers.txt: every top-level entry is classified."
