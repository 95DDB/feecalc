#!/usr/bin/env bash
# Lists the scenarios the deployed check can play on this branch.
# A scenario is runnable when every rule it names is in rules-implemented.txt.
# Prints the path of each runnable scenario on stdout, one per line. Reports
# every other scenario on stderr, with the rules it still waits for.
# Exit codes: 0 listed · 1 a scenario file does not name its rules
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

implemented=" $(grep -vE '^[[:space:]]*(#|$)' rules-implemented.txt 2>/dev/null | tr '\n' ' ')"
[[ -d scenarios ]] || exit 0

bad=0
while IFS= read -r file; do
  # The "rules: [A, B]" line of the header between the two --- lines.
  rules=$(awk 'NR == 1 && $0 != "---" { exit }
               NR > 1 && $0 == "---" { exit }
               /^rules:/ { sub(/^rules:[[:space:]]*/, ""); print; exit }' "$file" | tr -d "[]\"'" | tr ',' ' ')
  if [[ -z "${rules// /}" ]]; then
    echo "error    $file: no 'rules:' line in its header" >&2; bad=1; continue
  fi
  missing=()
  for rule in $rules; do
    [[ "$implemented" == *" $rule "* ]] || missing+=("$rule")
  done
  if (( ${#missing[@]} )); then
    echo "waiting  $file: ${missing[*]}" >&2
  else
    echo "$file"
  fi
done < <(find scenarios -type f -name '*.md' ! -iname 'README.md' | sort)
exit $bad
