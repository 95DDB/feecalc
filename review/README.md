# AI review

Two reviewers from different vendors read every PR. A high-severity finding
from either one blocks the merge until it is fixed or dismissed with a reason.

## What is here

| File | Purpose |
| --- | --- |
| `findings.schema.json` | The one format every reviewer writes |
| `reviewers/stub.sh` | Placeholder reviewer: reports nothing and says it is a stub |
| `../scripts/review-gate.py` | Reads the findings and decides whether the PR may merge |
| `../REVIEW.md` | What reviewers look for, and what counts as high severity |

## Turning the stubs into real reviewers

1. Add one script per vendor under `reviewers/`. Each takes the reviewer name,
   reads the diff against `$BASE_SHA` and `$RUNNER_TEMP/REVIEW.md`, and prints
   one findings document to stdout.
2. Point each matrix entry in `.github/workflows/ai-review.yml` at its script
   and give it that vendor's API key as a secret. A reviewer job gets a
   read-only repository token and no other secret.
3. Set the repository variable `AI_REVIEW_MODE` to `enforce`.

In `enforce` mode the gate needs two completed reviews from two vendors. Until
then it runs in `stub` mode and passes every PR while saying that no AI review
happened, so a human must approve every PR during that time.

## Dismissing a finding

Add a line to the PR description:

    dismiss <finding-id>: <reason>

The reason is recorded in the gate's summary.
