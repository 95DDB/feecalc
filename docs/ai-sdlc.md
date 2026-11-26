# AI-SDLC scaffolding

This repository follows the Horizen Labs AI-SDLC process. The gates, hooks and
scaffolding come from the `neutral` template; `.hl-template` records the
source and the commit. This page describes those parts as they stand here.

## What works today, and what is a stub

| Part | State |
| --- | --- |
| Hooks in `.claude/hooks/` | Working, with self-tests |
| Tier map, CODEOWNERS check, tier report | Working, with self-tests |
| CI mirror check, pre-push hook | Working, with self-tests |
| Secret scan | Working (gitleaks, pinned by version and checksum) |
| Review gate (`scripts/review-gate.py`) | Working, with self-tests |
| The `checks` job in CI, `make verify`, `make ci` | Working. The README lists the checks |
| AI reviewers | **Stub.** They report nothing. See `review/README.md` |
| Deployed check | **Stub and switched off.** See the workflow file |
| Scenarios (`scenarios/`, `rules-implemented.txt`) | Empty until `/hl:write-scenarios` runs. Choosing the runnable ones works; the agent that plays them is the stub above |
| Agent evals | **Stub.** Validates the cases; runs none |

While the reviewers are stubs, no AI reads the code. Keep the shadow ruleset,
which requires a human approval on every PR, until `AI_REVIEW_MODE` is `enforce`.

## How the pieces map to the process

| Process step | Where it lives |
| --- | --- |
| Tier of a change, critical paths | `tiers.txt`, `.github/CODEOWNERS`, `scripts/tier-check.sh` |
| New directory must be classified | `scripts/check-classified.sh` |
| Tests cannot be edited during a bug fix | `.claude/hooks/protect-tests.sh` |
| No `rm -rf`, no push to the default branch | `.claude/hooks/block-dangerous-bash.sh` |
| Edits to critical paths and dependency files ask first | `.claude/hooks/guard-critical-paths.sh` |
| Verify before reporting done | `.claude/hooks/verify-before-stop.sh` runs `make verify` |
| The same checks locally as in CI | `make ci`; `scripts/check-ci-mirror.sh` fails when the two differ |
| Checks before every push | `.githooks/pre-push`, switched on by `make setup` |
| Two-vendor AI review, high severity blocks | `.github/workflows/ai-review.yml`, `scripts/review-gate.py` |
| Review rules read from the base branch | `ai-review.yml` takes `REVIEW.md` and the gate script from the base commit |
| Deployed check, repro scripts block | `.github/workflows/deployed-check.yml`, `tests/repro/` |
| Scenarios, and which of them can run | `scenarios/`, `rules-implemented.txt`, `scripts/scenarios-runnable.sh`, `scripts/check-implemented-rules.sh` |
| Evals for the agent's configuration | `.github/workflows/agent-evals.yml`, `evals/` |
| Per-ticket design and plan | `docs/superpowers/` |
| Decisions and lessons | `docs/decisions/`, `docs/lessons.md` |

## Repository variables

| Variable | Values | Default |
| --- | --- | --- |
| `AI_REVIEW_MODE` | `stub`, `enforce` | `stub` |
| `DEPLOYED_CHECK_ENABLED` | `true`, anything else | off |

## Required status checks for the ruleset

`gates`, `checks`, `secret-scan`, `review-gate`. Add `deployed-check` once it is switched
on. `evals` is not required, because it does not run on every PR.

## Limits to know

- A hook binds the agent, not a person at a shell. CI and the ruleset are the
  enforcement; the hooks stop mistakes earlier.
- The pre-push hook runs only in a clone where `make setup` was run, and a
  person can skip it.
- `protect-tests.sh` decides "bug fix" from the branch name (`fix`, `bugfix` or
  `hotfix` as a word) or from `HL_TASK_TYPE=bugfix`. A fix on a branch named
  otherwise is not protected.
- Permission deny rules in `.claude/settings.json` cover the agent's file tools.
  They bind shell commands only when the sandbox is on, which the organization's
  managed settings control.
- A PR can change a workflow file. `.github/` is a critical path for that
  reason: a code owner has to approve it.
