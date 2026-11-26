#!/usr/bin/env bash
# Fails when a critical path in tiers.txt has no owner in .github/CODEOWNERS,
# or when the template's placeholder owner is still in place.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/lib/tiers.sh
source scripts/lib/tiers.sh

CODEOWNERS=.github/CODEOWNERS
fail=0

[[ -f "$CODEOWNERS" ]] || { echo "$CODEOWNERS is missing"; exit 1; }

# has_owner <pattern>: a CODEOWNERS line with exactly this pattern and at least one owner
has_owner() {
  awk -v want="$1" '
    /^[[:space:]]*(#|$)/ { next }
    $1 == want && NF >= 2 { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$CODEOWNERS"
}

while read -r path _tier critical _; do
  [[ -z "$path" || "$path" == \#* || "$critical" != "yes" ]] && continue
  has_owner "/$path" || { echo "No code owner for critical path: /$path"; fail=1; }
done < "$TIERS_FILE"

# CODEOWNERS must protect itself.
has_owner "/.github/" || has_owner "/.github/CODEOWNERS" || {
  echo "CODEOWNERS does not own itself (add /.github/)"; fail=1; }

for name in $MANIFEST_NAMES; do
  has_owner "$name" || { echo "No code owner for dependency file: $name"; fail=1; }
done

if grep -q '@YOUR-ORG/' "$CODEOWNERS" && [[ "${IS_TEMPLATE:-false}" != "true" ]]; then
  echo "CODEOWNERS still names the placeholder @YOUR-ORG/ team"; fail=1
fi

[[ $fail -eq 0 ]] || exit 1
echo "CODEOWNERS: every critical path has an owner."
