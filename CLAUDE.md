# feecalc

<!-- Keep this file under a page. /hl:bootstrap-repo drafts it and a person
     owns it. Afterwards add a line only when the agent has got something
     wrong, and remove lines that no longer apply. -->

## Commands

- Run every tool through `uv run --locked`, as the `checks` job in CI does: `ruff format --check .`,
  `ruff check .`, `python scripts/check-architecture.py`, `mypy`, `coverage run -m pytest`,
  `coverage report`, `pip-audit`. One test: `uv run --locked pytest tests/core -k <name>`
- Before reporting a task done: `make verify`, and paste its output
- Before pushing: `make ci`. The pre-push hook runs it; run `make setup` once per clone

## How work is done here

- Work from the ticket. It carries the rules to implement; implement nothing else.
- When the ticket needs a design and a plan, write them with Superpowers, with the
  ticket key in both file names, and commit them before any code.
- Tests come first. On a bug fix, commit the failing test, then fix the code.
  Never edit a committed test to make it pass.
- If the code departs from the plan, update the plan in the same PR.
- Files under `docs/superpowers/` record past changes. Do not treat them as
  current rules; the ticket and the code are.
- Read `docs/lessons.md` when a failure repeats. Read `docs/decisions/` before
  changing something that looks deliberate.

## Conventions

- Compute a fee or a net amount in `core/` only. `api/` passes on what `core/` returned and
  `web/` shows what `/fee` answered; neither adds, subtracts, rounds or supplies a default.
- In `core/`, work in integers. Round the fee up with `-(-amount * 30 // 10_000)`; plain `//`
  rounds down.
- Accept an amount only if it is an `int` greater than zero. Refuse a `bool`: `True` is an
  `int` in Python. A refusal raises an error; it never returns a fee of 0 or `None`.
- Return the fee and the net amount from one call. Answer a negative or zero net amount as
  computed, and set no largest amount.
- `core/` imports only what `CORE_IMPORTS` in `scripts/check-architecture.py` lists, and `api/`
  only the standard library and `core`. Add no run-time dependency: `dependencies` in
  `pyproject.toml` stays empty.
- In `api/`, turn every failure to read the amount into a 400 with `{"error": ...}` and no
  `fee` key. That includes a missing, empty or repeated `amount`, and the `ValueError` that
  `int()` raises for more than 4,300 digits.
- Decide which spellings count as an integer, say so in the PR description and test each
  one. `int()` alone also accepts `" 5 "`, `"+5"`, `"007"`, `"1_000"` and non-ASCII digits.
- Answer `/fee`, `/health` and `/` and nothing else. Subclass `BaseHTTPRequestHandler`, never
  `SimpleHTTPRequestHandler`, and read `web/index.html` from a fixed path, never from the
  request path.
- Keep nothing between requests and write nothing to disk: no module-level cache or counter,
  no file, no log file.
- Keep `web/index.html` one static file with plain JavaScript and no build step. Put answers
  on the page with `textContent`, never `innerHTML`.
- Put tests in `tests/<part>/`. Test a fee rule at each limit and with a non-whole raw fee,
  and as a Hypothesis property over all amounts, not only with the specification's examples.

## Things the agent gets wrong

<!-- One line each. Added when a mistake happens twice. -->
