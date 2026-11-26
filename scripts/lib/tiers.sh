#!/usr/bin/env bash
# Shared helpers for reading tiers.txt. Source this file; do not run it.

TIERS_FILE="${TIERS_FILE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/tiers.txt}"

# Dependency manifests and lockfiles are critical wherever they live.
MANIFEST_NAMES='Cargo.toml Cargo.lock package.json package-lock.json pnpm-lock.yaml yarn.lock pyproject.toml uv.lock poetry.lock requirements.txt go.mod go.sum foundry.toml remappings.txt'

# tiers_lookup <repo-relative path>  ->  prints "<tier> <critical>" or "? ?"
tiers_lookup() {
  awk -v p="$1" '
    /^[[:space:]]*(#|$)/ { next }
    {
      pat = $1
      if (pat ~ /\/$/) { hit = (index(p, pat) == 1) } else { hit = (p == pat) }
      if (hit && length(pat) > best) { best = length(pat); t = $2; c = $3 }
    }
    END { if (best) print t, c; else print "? ?" }
  ' "$TIERS_FILE"
}

# is_manifest <path>  ->  exit 0 when the file is a dependency manifest or lockfile
is_manifest() {
  local base
  base=$(basename "$1")
  case " $MANIFEST_NAMES " in *" $base "*) return 0 ;; esac
  [[ "$base" == requirements*.txt ]]
}

# is_critical <path>  ->  exit 0 when a code owner must approve changes to it
is_critical() {
  local out
  out=$(tiers_lookup "$1")
  [[ "${out#* }" == "yes" ]] || is_manifest "$1"
}
