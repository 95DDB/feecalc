#!/usr/bin/env bash
# Fails when a command that CI runs is missing from the Makefile's ci target,
# so that `make ci` cannot drift away from the workflow it mirrors.
#
# Reads the `gates` and `checks` jobs of the workflow. A step that cannot run
# locally carries the comment "# ci-only" on its run line and is skipped.
# A run command is one line: anything longer goes in a script that both the
# workflow and the Makefile call. A step may not set working-directory: write
# `cd <dir> && <command>` so that the Makefile can repeat it word for word.
#
# A command counts as present when a line of the ci recipe contains it. This
# compares text, not behavior: `tool test || true` still contains `tool test`.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
WORKFLOW="${WORKFLOW:-.github/workflows/ci.yml}"
MAKEFILE="${MAKEFILE:-Makefile}"

for file in "$WORKFLOW" "$MAKEFILE"; do
  [[ -f "$file" ]] || { echo "CI mirror: cannot read $file"; exit 1; }
done

# The ci target's recipe lines as the shell receives them: no leading tab, @
# or -, and $$ as $. Commented-out lines do not count.
grep -q '^ci:' "$MAKEFILE" || { echo "CI mirror: cannot read a ci target in $MAKEFILE"; exit 1; }
recipes=$(awk '
  /^ci:/ { in_ci = 1; next }
  in_ci && /^\t/ { sub(/^\t[@-]*/, ""); gsub(/\$\$/, "$"); if ($0 !~ /^[[:space:]]*#/) print; next }
  in_ci && /^[^[:space:]]/ { in_ci = 0 }
' "$MAKEFILE")

# One line "<job> job" per job found, "<job> run <command>" per run line, and
# "<job> dir" per working-directory.
runs=$(awk '
  /^jobs:[[:space:]]*$/ { in_jobs = 1; next }
  in_jobs && /^[^[:space:]#]/ { in_jobs = 0 }
  in_jobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
    job = $1; sub(/:$/, "", job)
    if (job == "gates" || job == "checks") print job " job"
    next
  }
  in_jobs && (job == "gates" || job == "checks") && /^[[:space:]]+(- )?run:/ {
    line = $0; sub(/^[[:space:]]+(- )?run:[[:space:]]*/, "", line); sub(/[[:space:]]+$/, "", line)
    print job " run " line
  }
  in_jobs && (job == "gates" || job == "checks") && /^[[:space:]]+(- )?working-directory:/ { print job " dir" }
' "$WORKFLOW")

fail=0; found=" "; compared=" "
while read -r job kind command; do
  [[ -z "$job" ]] && continue
  found+="$job "
  if [[ "$kind" == "dir" ]]; then
    echo "CI mirror: a step in the '$job' job sets working-directory. Write 'cd <dir> && <command>' in its run line instead."
    fail=1; continue
  fi
  [[ "$kind" == "run" ]] || continue
  [[ "$command" == *"# ci-only"* ]] && continue
  if [[ -z "$command" || "$command" == \|* || "$command" == \>* ]]; then
    echo "CI mirror: a run command in the '$job' job spans several lines. Put it in a script that both the workflow and the Makefile call."
    fail=1; continue
  fi
  compared+="$job "
  if ! grep -qF -- "$command" <<<"$recipes"; then
    echo "CI mirror: the '$job' job runs a command that is not in the ci target of $MAKEFILE: $command"
    fail=1
  fi
done <<<"$runs"

for job in gates checks; do
  if [[ "$found" != *" $job "* ]]; then
    echo "CI mirror: cannot read the '$job' job in $WORKFLOW"; fail=1
  elif [[ "$compared" != *" $job "* ]]; then
    echo "CI mirror: cannot read a run command in the '$job' job of $WORKFLOW"; fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  echo
  echo "Add the missing commands to the Makefile's ci target, or mark a step that cannot run locally with '# ci-only'."
  exit 1
fi
echo "CI mirror: every command of the gates and checks jobs is in the ci target of $MAKEFILE."
