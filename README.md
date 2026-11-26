# feecalc

feecalc answers one question: what fee will this transfer cost? A client sends
a transfer amount and gets back the amount, the fee and the net amount, which
is the amount minus the fee. It exists so that one place owns the calculation,
instead of every client computing a fee of its own.

**Status:** the fee calculation is built, in `core/fee.py`. The HTTP service
and the demo page are not built yet.

## The fee

- The fee is 0.30% of the amount, at least 10 units and at most 5,000 units.
- Amounts, fees and net amounts are whole units of the smallest denomination.
  There are no fractions of a unit.
- When 0.30% of the amount is not a whole number, the fee is rounded up to the
  next whole unit.
- Every whole amount greater than zero is accepted. Anything else is refused
  with an error and is never answered with a fee.

| Amount | Fee | Net amount | Why |
| ---: | ---: | ---: | --- |
| 1,000 | 10 | 990 | 0.30% is 3, below the minimum |
| 250,000 | 750 | 249,250 | Within the limits |
| 10,100 | 31 | 10,069 | 0.30% is 30.3, rounded up |
| 2,000,000 | 5,000 | 1,995,000 | 0.30% is 6,000, above the maximum |

## The HTTP service

| Request | Answer |
| --- | --- |
| `GET /fee?amount=<integer>`, amount accepted | 200, `{"amount": <integer>, "fee": <integer>, "net": <integer>}` |
| `GET /fee`, amount missing, not an integer, or refused | 400, `{"error": "<what is wrong>"}` |
| `GET /health` | 200, `{"status": "ok"}` |
| `GET /` | The demo page |
| Any other path | 404 |

The service listens on the port in the `PORT` environment variable, or on 8080
when it is not set. It keeps nothing between requests and writes nothing to
disk.

## Layout

| Path | What it holds | Tier |
| --- | --- | --- |
| `core/` | The fee calculation: a pure function in integer arithmetic. It depends on nothing. | 1, critical |
| `api/` | The HTTP service, the only way in from outside. It depends on `core/`. Not created yet. | 2 |
| `web/` | The demo page for the sales demo: one static file, served at `/`. Not created yet. | 3 |
| `tests/` | The tests, one directory per part. `tests/core/` is critical like `core/`. | As the part |
| `scripts/`, `.github/`, `.claude/`, `review/`, `scenarios/`, `evals/`, `docs/` | The AI-SDLC scaffolding. See [docs/ai-sdlc.md](docs/ai-sdlc.md). | None |

`tiers.txt` is the binding list of tiers and critical paths, and
`.github/CODEOWNERS` names who approves a change to a critical path.

## Development

You need [uv](https://docs.astral.sh/uv/), which installs Python 3.12 and the
pinned tools, and bash, git, jq and make.

    make setup     # once per clone: switches on the git hooks
    make verify    # the fast checks
    make ci        # everything CI runs; the pre-push hook runs it

The code uses only the Python standard library at run time. The tools below
are development dependencies, pinned in `uv.lock`.

| Check | Command | What it catches |
| --- | --- | --- |
| Format | `uv run --locked ruff format --check .` | Unformatted code |
| Lint and security lint | `uv run --locked ruff check .` | Likely bugs, unsafe calls, a blind `except` |
| Guarantees of the specification | `uv run --locked python scripts/check-architecture.py` | A float, a `/` division or input and output in `core/`; an import in `core/` or `api/` that the architecture forbids |
| Type check | `uv run --locked mypy` | A value of the wrong type, in strict mode |
| Tests | `uv run --locked coverage run -m pytest` | A broken rule |
| Coverage | `uv run --locked coverage report` | Less than 90% of the branches in `core/` and `api/` tested |
| Coverage of Tier 1 | `uv run --locked coverage report --include='core/*' --fail-under=100` | Any untested branch in the fee calculation |
| Dependency audit | `uv run --locked pip-audit` | A known vulnerability in a pinned tool |

`make verify` runs all of them but the audit. `make ci` runs them all, after
the gates that check the scaffolding itself.

## How work is done here

Work starts from a ticket that carries the rules to implement. `CLAUDE.md`
holds the conventions for writing code here, `REVIEW.md` the rules for
reviewing it, and [docs/ai-sdlc.md](docs/ai-sdlc.md) describes the gates,
hooks and review steps.
