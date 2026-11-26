#!/usr/bin/env bash
# Reports the highest tier and the critical paths a change touches.
# Usage: tier-check.sh <base-ref>        compares <base-ref>...HEAD
#        tier-check.sh --files f1 f2 ... classifies the given files
# Prints a Markdown summary. Writes critical=true|false and tier=<n> to
# $GITHUB_OUTPUT when that variable is set. Always exits 0: it informs,
# CODEOWNERS and the ruleset enforce.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/lib/tiers.sh
source scripts/lib/tiers.sh

files=()
if [[ "${1:-}" == "--files" ]]; then
  shift; files=("$@")
else
  base="${1:?usage: tier-check.sh <base-ref> | --files <file>...}"
  while IFS= read -r f; do files+=("$f"); done < <(git diff --name-only "$base"...HEAD)
fi

top_tier=""; critical=(); manifests=(); unclassified=()
for f in "${files[@]}"; do
  read -r tier crit <<<"$(tiers_lookup "$f")"
  [[ "$tier" == "?" ]] && unclassified+=("$f")
  if [[ "$tier" =~ ^[123]$ ]] && { [[ -z "$top_tier" ]] || (( tier < top_tier )); }; then top_tier=$tier; fi
  if is_manifest "$f"; then manifests+=("$f"); critical+=("$f")
  elif [[ "$crit" == "yes" ]]; then critical+=("$f"); fi
done

echo "### Tier check"
echo
echo "- Files changed: ${#files[@]}"
echo "- Highest tier touched: ${top_tier:-none (no product code)}"
if (( ${#critical[@]} )); then
  echo "- Critical paths touched: **yes** — a code owner must approve"
  printf '  - `%s`\n' "${critical[@]}"
else
  echo "- Critical paths touched: no"
fi
if (( ${#manifests[@]} )); then
  echo "- Dependency files changed — confirm every new dependency was chosen by a person:"
  printf '  - `%s`\n' "${manifests[@]}"
fi
if (( ${#unclassified[@]} )); then
  echo "- Not classified in tiers.txt:"
  printf '  - `%s`\n' "${unclassified[@]}"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  { echo "critical=$( (( ${#critical[@]} )) && echo true || echo false )"
    echo "tier=${top_tier:-none}"; } >> "$GITHUB_OUTPUT"
fi
