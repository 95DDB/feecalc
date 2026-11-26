#!/usr/bin/env bash
# PreToolUse on Edit and Write. During a bug fix, a test that is already
# committed cannot be edited: the agent fixes the code, not the check.
# A new test file can be written freely until its first commit, so the
# failing test that reproduces the bug comes first.
#
# A session counts as a bug fix when the branch name contains fix, bugfix or
# hotfix as a word, or when HL_TASK_TYPE=bugfix is set.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

file=$(jq -r '.tool_input.file_path // ""')
[[ -z "$file" ]] && exit 0
file=$(rel_path "$file")

is_test=1
while IFS= read -r pattern; do
  [[ -z "$pattern" || "$pattern" == \#* ]] && continue
  if grep -Eq -- "$pattern" <<<"$file"; then is_test=0; break; fi
done < "$(dirname "$0")/test-patterns.txt"
(( is_test == 0 )) || exit 0

branch=$(current_branch)
if [[ "${HL_TASK_TYPE:-}" != "bugfix" ]] &&
   ! grep -Eq '(^|[/_-])(fix|bugfix|hotfix)([/_-]|$)' <<<"$branch"; then
  exit 0
fi

if git -C "$PROJECT_DIR" cat-file -e "HEAD:$file" 2>/dev/null; then
  block "Blocked: $file is a committed test and this is a bug fix. Fix the code, not the test. If the test itself is wrong, stop and tell the person you work for."
fi
exit 0
