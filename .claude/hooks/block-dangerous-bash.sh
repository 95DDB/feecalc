#!/usr/bin/env bash
# PreToolUse on Bash. Blocks recursive force deletes, force pushes, pushes that
# skip the pre-push checks and any push to the default branch. Changes reach the default branch through a PR.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

cmd=$(jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# rm with both a recursive and a force flag, in any order or spelling
if grep -Eq '(^|[;&|(]|[[:space:]])rm[[:space:]]' <<<"$cmd"; then
  rm_args=$(grep -Eo '(^|[;&|(]|[[:space:]])rm[[:space:]][^;&|]*' <<<"$cmd" || true)
  if grep -Eq '(^|[[:space:]])(-[[:alnum:]]*[rR]|--recursive)' <<<"$rm_args" &&
     grep -Eq '(^|[[:space:]])(-[[:alnum:]]*f|--force)' <<<"$rm_args"; then
    block "Blocked: recursive force delete. Remove specific files, or ask the person you work for."
  fi
fi

# "push" must be the git subcommand, not a word in a commit message. Global
# options such as -C <dir> or -c <key=value> may sit between git and push.
git_push='git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--?[A-Za-z][^[:space:]]*)*[[:space:]]+push'
if grep -Eq "${git_push}([[:space:]]|\$)" <<<"$cmd"; then
  push_args=$(grep -Eo "${git_push}[^;&|]*" <<<"$cmd")
  if grep -Eq '(^|[[:space:]])(--force|--force-with-lease[^[:space:]]*|-f|\+[^[:space:]]+)([[:space:]]|$)' <<<"$push_args"; then
    block "Blocked: force push. History on shared branches is never rewritten."
  fi
  if grep -Eq '(^|[[:space:]])--no-verify([[:space:]]|$)' <<<"$push_args"; then
    block "Blocked: push without the pre-push checks. Fix what 'make ci' reports."
  fi
  default_re='(main|master)'
  if grep -Eq "(^|[[:space:]:/])${default_re}([[:space:]]|\$)" <<<"$push_args"; then
    block "Blocked: push to the default branch. Open a pull request from the ticket branch."
  fi
  # A bare "git push" pushes the current branch.
  if [[ "$(current_branch)" =~ ^${default_re}$ ]] &&
     ! grep -Eq 'push[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+[^-[:space:]]' <<<"$push_args"; then
    block "Blocked: you are on the default branch. Switch to the ticket branch before pushing."
  fi
fi
exit 0
