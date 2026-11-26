#!/usr/bin/env bash
# Self-tests for the hooks and gate scripts. Runs in a throwaway repo, so it
# never touches the working tree. Needs bash, git, jq, make, python3.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
# expect <name> <expected exit code> <command...>
expect() {
  local name="$1" want="$2"; shift 2
  "$@" >"$TMP/out" 2>"$TMP/err"; local got=$?
  if [[ "$got" == "$want" ]]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL  $name: exit $got, wanted $want"; sed 's/^/        /' "$TMP/err" | head -5; fi
}
# expect_out <name> <pattern> <command...>: command must succeed and print the pattern
expect_out() {
  local name="$1" pattern="$2"; shift 2
  if "$@" >"$TMP/out" 2>"$TMP/err" && grep -q -- "$pattern" "$TMP/out"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL  $name: output lacks '$pattern'"; fi
}
# expect_silent <name> <command...>: command must succeed and print nothing
expect_silent() {
  local name="$1"; shift
  if "$@" >"$TMP/out" 2>"$TMP/err" && [[ ! -s "$TMP/out" ]]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL  $name: expected no output"; fi
}

# --- A throwaway repo built from this repo's tooling plus fixtures ------------
# Only the hooks and scripts under test come from the real repo. The tier map,
# CODEOWNERS, Makefile and test patterns are fixtures, so these tests give the
# same result in the template and in every repository created from it.
REPO="$TMP/repo"; FX="$ROOT/scripts/tests/fixtures"
mkdir -p "$REPO" && cd "$REPO" || exit 1
cp -a "$ROOT/.claude" "$ROOT/.githooks" "$ROOT/scripts" "$ROOT/review" .
mkdir -p .github evals/cases docs/superpowers/plans tests/repro src
cp "$FX/tiers.txt" tiers.txt && cp "$FX/CODEOWNERS" .github/CODEOWNERS && cp "$FX/Makefile" Makefile
cp "$FX/test-patterns.txt" .claude/hooks/test-patterns.txt
cp "$ROOT/evals/run.sh" evals/run.sh && cp "$FX/eval-case.json" evals/cases/example.json
rm -f .claude/settings.local.json
git init -q -b main . && git config user.email t@example.com && git config user.name tester
# Never ask for a signing passphrase: these tests also run before every push.
git config commit.gpgsign false
echo "x = 1" > src/a.py && echo "def test_a(): pass" > tests/test_a.py
git add -A && git commit -q -m "initial"
export CLAUDE_PROJECT_DIR="$REPO"
H="$REPO/.claude/hooks"

bash_hook() { jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | "$H/block-dangerous-bash.sh"; }
edit_hook() { jq -n --arg f "$2" '{tool_name: "Edit", tool_input: {file_path: $f}}' | "$H/$1"; }

# --- block-dangerous-bash ----------------------------------------------------
export HL_CURRENT_BRANCH=HL-1-feature
expect "rm -rf blocked"               2 bash_hook 'rm -rf build'
expect "rm -fr blocked"               2 bash_hook 'cd x && rm -fr build'
expect "rm -r -f blocked"             2 bash_hook 'rm -r -f build'
expect "rm --recursive --force"       2 bash_hook 'rm --recursive --force build'
expect "plain rm allowed"             0 bash_hook 'rm notes.txt'
expect "rm -r without force allowed"  0 bash_hook 'rm -r build'
expect "grep -r allowed"              0 bash_hook 'grep -rf patterns.txt src'
expect "push to main blocked"         2 bash_hook 'git push origin main'
expect "push HEAD:main blocked"       2 bash_hook 'git push origin HEAD:main'
expect "push -C dir to master"        2 bash_hook 'git -C /tmp/r push origin master'
expect "force push blocked"           2 bash_hook 'git push --force origin HL-1-feature'
expect "push -f blocked"              2 bash_hook 'git push -f'
expect "force-with-lease blocked"     2 bash_hook 'git push --force-with-lease origin HL-1-feature'
expect "push ticket branch allowed"   0 bash_hook 'git push -u origin HL-1-feature'
expect "bare push on ticket branch"   0 bash_hook 'git push'
expect "commit message with push"     0 bash_hook 'git commit -m "explain push to main"'
expect "branch named maintenance"     0 bash_hook 'git push origin HL-2-maintenance'
HL_CURRENT_BRANCH=main expect "bare push on main blocked" 2 bash_hook 'git push'
expect "push --no-verify blocked"     2 bash_hook 'git push --no-verify origin HL-1-feature'
expect "push with --no-verify after the branch blocked" 2 bash_hook 'git push origin HL-1-feature --no-verify'

# --- protect-tests -----------------------------------------------------------
export HL_CURRENT_BRANCH=HL-7-fix-overflow
expect "committed test locked on a fix"   2 edit_hook protect-tests.sh tests/test_a.py
expect "absolute path handled"            2 edit_hook protect-tests.sh "$REPO/tests/test_a.py"
expect "new test allowed on a fix"        0 edit_hook protect-tests.sh tests/test_new.py
expect "source file allowed on a fix"     0 edit_hook protect-tests.sh src/a.py
export HL_CURRENT_BRANCH=HL-8-add-prefix
expect "test editable on a feature"       0 edit_hook protect-tests.sh tests/test_a.py
HL_TASK_TYPE=bugfix expect "HL_TASK_TYPE=bugfix locks tests" 2 edit_hook protect-tests.sh tests/test_a.py

# --- guard-critical-paths ----------------------------------------------------
expect_out    "workflow edit asks"     '"permissionDecision": "ask"' edit_hook guard-critical-paths.sh .github/workflows/ci.yml
expect_out    "manifest edit asks"     '"permissionDecision": "ask"' edit_hook guard-critical-paths.sh services/api/Cargo.toml
expect_out    "tiers.txt edit asks"    '"permissionDecision": "ask"' edit_hook guard-critical-paths.sh tiers.txt
expect_silent "source edit is silent"  edit_hook guard-critical-paths.sh src/a.py
expect_silent "docs edit is silent"    edit_hook guard-critical-paths.sh docs/lessons.md

# --- format-changed-file -----------------------------------------------------
expect "format hook never blocks" 0 edit_hook format-changed-file.sh src/a.py

# --- verify-before-stop ------------------------------------------------------
stop_hook() { jq -n --argjson a "$1" '{stop_hook_active: $a}' | "$H/verify-before-stop.sh"; }
expect "stop: clean tree passes"        0 stop_hook false
echo "x = 2" > src/a.py
expect "stop: verify passes"            0 stop_hook false
cp Makefile "$TMP/Makefile.bak"
printf '\nverify:\n\t@echo "1 test failed"; exit 1\n' >> Makefile 2>/dev/null
expect "stop: failing verify blocks"    2 stop_hook false
expect "stop: no second loop"           0 stop_hook true
cp "$TMP/Makefile.bak" Makefile && git checkout -q -- src/a.py

# --- pre-push ----------------------------------------------------------------
expect "pre-push: passes when make ci passes"        0 .githooks/pre-push
cp Makefile "$TMP/Makefile.bak"
printf '\nci:\n\t@echo "1 check failed"; exit 1\n' >> Makefile 2>/dev/null
expect "pre-push: stops the push when make ci fails" 2 .githooks/pre-push
cp "$TMP/Makefile.bak" Makefile

# --- tiers and CODEOWNERS ----------------------------------------------------
expect "classified: passes"                 0 ./scripts/check-classified.sh
mkdir newdir && echo hi > newdir/f && git add newdir
expect "classified: new directory fails"    1 ./scripts/check-classified.sh
git rm -rq --cached newdir && rm -rf newdir
printf 'contracts/ 1 no\n' >> tiers.txt
expect "classified: Tier 1 must be critical" 1 ./scripts/check-classified.sh
git checkout -q -- tiers.txt
IS_TEMPLATE=false expect "codeowners: placeholder fails" 1 ./scripts/check-codeowners.sh
IS_TEMPLATE=true expect "codeowners: template passes" 0 ./scripts/check-codeowners.sh
grep -v '^/scripts/' .github/CODEOWNERS > "$TMP/co" && cp "$TMP/co" .github/CODEOWNERS
IS_TEMPLATE=true expect "codeowners: missing owner fails" 1 ./scripts/check-codeowners.sh
git checkout -q -- .github/CODEOWNERS
expect_out "tier-check: critical flagged" 'Critical paths touched: \*\*yes\*\*' ./scripts/tier-check.sh --files .github/workflows/ci.yml src/a.py
expect_out "tier-check: tier reported"    'Highest tier touched: 2'            ./scripts/tier-check.sh --files src/a.py
expect_out "tier-check: nothing critical" 'Critical paths touched: no'         ./scripts/tier-check.sh --files src/a.py docs/lessons.md
IS_TEMPLATE=false expect "template check: placeholders fail" 1 ./scripts/check-template-configured.sh
IS_TEMPLATE=true expect "template check: template passes" 0 ./scripts/check-template-configured.sh

# --- ci mirror ---------------------------------------------------------------
M="$TMP/mirror"; mkdir "$M"
# workflow <checks job> [other jobs]: a workflow whose gates job runs ./a.sh
workflow() { printf 'name: CI\njobs:\n  gates:\n    steps:\n      - name: a\n        run: ./a.sh\n%s%s' "$1" "${2:-}" > "$M/ci.yml"; }
# checks_job <step...>: the text of a checks job with these steps
checks_job() { printf '  checks:\n    steps:\n'; printf '      - %s\n' "$@"; }
recipes() { { echo "ci:"; printf '\t%s\n' "$@"; } > "$M/Makefile"; }
mirror() { WORKFLOW="$M/ci.yml" MAKEFILE="$M/Makefile" ./scripts/check-ci-mirror.sh; }
workflow "$(checks_job 'run: tool test')"$'\n'; recipes './a.sh' '@tool test'
expect "mirror: same commands pass"             0 mirror
recipes './a.sh'
mirror >"$TMP/out" 2>&1; got=$?
if [[ $got == 1 ]] && grep -q 'tool test' "$TMP/out"; then pass=$((pass + 1))
else fail=$((fail + 1)); echo "FAIL  mirror: missing command fails: exit $got, or the command is not named"; fi
recipes './a.sh' 'cd sub && tool test'
expect "mirror: contained in a longer recipe"   0 mirror
workflow "$(checks_job 'run: tool test' 'run: ./report.sh >> "$GITHUB_STEP_SUMMARY" # ci-only')"$'\n'; recipes './a.sh' 'tool test'
expect "mirror: ci-only step is skipped"        0 mirror
workflow "$(checks_job 'run: tool "$HOME"')"$'\n'; recipes './a.sh' 'tool "$$HOME"'
expect "mirror: dollar in a recipe"             0 mirror
workflow "$(checks_job 'run: |')"$'\n'; recipes './a.sh' 'tool test'
expect "mirror: multi-line run fails"           1 mirror
workflow ""
expect "mirror: no checks job fails"            1 mirror
workflow "$(checks_job 'uses: actions/checkout@abc')"$'\n'
expect "mirror: job without commands fails"     1 mirror
workflow "$(checks_job 'run: tool test')"$'\n' $'  secret-scan:\n    steps:\n      - run: curl x\n'
expect "mirror: other jobs are not read"        0 mirror
workflow "$(checks_job 'run: tool test')"$'\n'; recipes './a.sh' '# tool test'
expect "mirror: a commented-out recipe does not count" 1 mirror
printf 'ci:\n\t./a.sh\nverify:\n\ttool test\n' > "$M/Makefile"
expect "mirror: a command under another target does not count" 1 mirror
printf 'verify:\n\t./a.sh\n\ttool test\n' > "$M/Makefile"
expect "mirror: a Makefile without a ci target fails" 1 mirror
workflow "$(checks_job $'run: tool test\n        working-directory: sub')"$'\n'; recipes './a.sh' 'tool test'
expect "mirror: working-directory is refused"   1 mirror

# --- review gate -------------------------------------------------------------
F="$TMP/findings"; mkdir "$F"
gate() { python3 ./scripts/review-gate.py --findings-dir "$F" --dismissals "$TMP/body" "$@"; }
finding() { jq -n --arg r "$1" --arg v "$2" --arg s "$3" --argjson f "$4" '{reviewer: $r, vendor: $v, status: $s, findings: $f}' > "$F/$1.json"; }
high='[{"id": "sec-1", "pass": "security", "severity": "high", "title": "Key written to log", "file": "src/a.py"}]'
: > "$TMP/body"
./review/reviewers/stub.sh reviewer-a > "$F/reviewer-a.json"; ./review/reviewers/stub.sh reviewer-b > "$F/reviewer-b.json"
expect "gate: stub mode passes"             0 gate --mode stub
expect "gate: stubs fail in enforce"        1 gate --mode enforce
finding reviewer-a anthropic ok '[]'; finding reviewer-b openai ok '[{"id": "n-1", "pass": "bugs", "severity": "low", "title": "naming"}]'
expect "gate: two vendors, no high"         0 gate --mode enforce
finding reviewer-b openai ok "$high"
expect "gate: open high blocks"             1 gate --mode enforce
echo "dismiss sec-1: false positive, the value is a public key" > "$TMP/body"
expect "gate: dismissed high passes"        0 gate --mode enforce
echo "dismiss sec-1:" > "$TMP/body"
expect "gate: dismissal needs a reason"     1 gate --mode enforce
: > "$TMP/body"; finding reviewer-b anthropic ok '[]'
expect "gate: one vendor is not enough"     1 gate --mode enforce
finding reviewer-b openai error '[]'
expect "gate: reviewer error blocks"        1 gate --mode enforce
echo '{"reviewer": "x"' > "$F/reviewer-b.json"
expect "gate: bad JSON is rejected"         2 gate --mode enforce

# --- evals and repro scripts -------------------------------------------------
expect "evals: example case is valid"       0 ./evals/run.sh
expect "repros: empty set passes"           0 ./scripts/deployed/run-repros.sh
printf '#!/usr/bin/env bash\nexit 1\n' > tests/repro/0001-example.sh
expect "repros: failing script blocks"      1 ./scripts/deployed/run-repros.sh

# --- scenarios and the list of implemented rules --------------------------------
git add -A && git commit -q -m "state before the scenario tests"
mkdir -p scenarios/06-fees scenarios/07-api
# scn <file> <id> <chapter> <rules, comma separated>
scn() { printf -- '---\nid: %s\nchapter: %s\nrules: [%s]\nroles: [client]\n---\n# A scenario\n\n## Steps\n\n1. Ask.\n\n## Expected\n\n- An answer.\n' "$2" "$3" "$4" > "$1"; }
scn scenarios/06-fees/minimum.md FEE-SC-06-01 6 "FEE-CALC-01, FEE-CALC-03"
scn scenarios/07-api/refusal.md FEE-SC-07-01 7 "FEE-API-02"
echo "# What this folder holds" > scenarios/README.md
runnable() { ./scripts/scenarios-runnable.sh 2>/dev/null; }
waiting()  { ./scripts/scenarios-runnable.sh 2>&1 >/dev/null; }
printf '# The rules this branch implements.\nFEE-CALC-01\n' > rules-implemented.txt
expect_silent "runnable: none while one of its rules is missing" runnable
expect_out "runnable: says which rule a scenario waits for" "minimum.md: FEE-CALC-03" waiting
printf 'FEE-CALC-01\nFEE-CALC-03\n' > rules-implemented.txt
expect "runnable: exactly the scenario whose rules are all there" 0 bash -c '[[ "$(./scripts/scenarios-runnable.sh 2>/dev/null)" == "scenarios/06-fees/minimum.md" ]]'
expect_out "stub: names the scenarios it would play" "scenarios/06-fees/minimum.md" ./scripts/deployed/agent-stub.sh
echo "no header here" > scenarios/07-api/broken.md
expect "runnable: a scenario without its rules is an error" 1 ./scripts/scenarios-runnable.sh
rm scenarios/07-api/broken.md
rm rules-implemented.txt
expect_silent "runnable: no list means nothing is implemented" runnable

list() { printf '%s\n' "$@" > rules-implemented.txt; }
expect "list: a repository without one passes"  0 ./scripts/check-implemented-rules.sh
list '# The rules this branch implements.' FEE-CALC-01 FEE-CALC-03
expect "list: well formed passes"               0 ./scripts/check-implemented-rules.sh
list FEE-CALC-03 FEE-CALC-01
expect "list: unsorted fails"                   1 ./scripts/check-implemented-rules.sh
list FEE-CALC-01 FEE-CALC-01
expect "list: a rule twice fails"               1 ./scripts/check-implemented-rules.sh
list FEE-CALC-01 'FEE-CALC-03 done'
expect "list: a line that is not a rule ID fails" 1 ./scripts/check-implemented-rules.sh
list FEE-CALC-01 FEE-CALC-03
git add -A && git commit -q -m "two rules implemented"; before=$(git rev-parse HEAD)
list FEE-API-02 FEE-CALC-01 FEE-CALC-03; git add -A && git commit -q -m "a third"
expect "list: adding a rule passes"             0 ./scripts/check-implemented-rules.sh "$before"
list FEE-API-02 FEE-CALC-01; git add -A && git commit -q -m "one rule taken off"
expect "list: a rule may not leave the list"    1 ./scripts/check-implemented-rules.sh "$before"
scn scenarios/06-fees/minimum.md FEE-SC-06-01 6 "FEE-CALC-01, FEE-CALC-03, FEE-CALC-04"
git add -A && git commit -q -m "its scenario was updated in the same change"
expect "list: unless its scenarios change too"  0 ./scripts/check-implemented-rules.sh "$before"

echo
echo "Self-tests: $pass passed, $fail failed."
[[ $fail -eq 0 ]]
