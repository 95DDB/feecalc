#!/usr/bin/env bash
# Validates every eval case. Running the cases against a coding agent is a
# stub: wire it up here once an API key and a budget exist.
set -euo pipefail
cd "$(dirname "$0")"

shopt -s nullglob
cases=(cases/*.json)
echo "### Agent evals"
echo
if (( ${#cases[@]} == 0 )); then echo "No eval cases."; exit 1; fi

bad=0
for file in "${cases[@]}"; do
  if jq -e '
      (.id | type == "string" and length > 0) and
      (.prompt | type == "string" and length > 0) and
      (.checks | type == "array" and length > 0 and all(type == "string")) and
      (.allowed_tools | type == "array" and all(type == "string"))
    ' "$file" >/dev/null 2>&1; then
    echo "- valid: \`$file\`"
  else
    echo "- INVALID: \`$file\` (needs id, prompt, checks[], allowed_tools[])"; bad=1
  fi
done
(( bad == 0 )) || exit 1

echo
echo "> ${#cases[@]} case(s) valid. **The runner is a stub: no case was executed.**"
