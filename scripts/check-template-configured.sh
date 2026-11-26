#!/usr/bin/env bash
# Fails in a repo created from the template while placeholders remain.
# Passes in the template repository itself (IS_TEMPLATE=true).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [[ "${IS_TEMPLATE:-false}" == "true" ]]; then
  echo "Template repository: placeholder check skipped."; exit 0
fi

left=$(grep -rIl 'TEMPLATE-PLACEHOLDER' --exclude-dir=.git --exclude-dir=scripts --exclude=README.md . || true)
if [[ -n "$left" ]]; then
  echo "Placeholders from the template are still in:"; echo "$left" | sed 's/^/  /'
  echo "Replace each TEMPLATE-PLACEHOLDER with the project's real value."
  exit 1
fi
echo "No template placeholders left."
