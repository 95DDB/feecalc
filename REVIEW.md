# Review instructions

Written for any model. Every reviewer gets this file from the base branch,
the diff, the ticket's rules, and the design and plan when they exist.

## Passes

Run three passes and tag each finding with its pass.

- **bugs**: logic errors, broken edge cases, regressions, tests that cannot fail.
- **security**: injection, missing authorization, secrets or personal data in
  code or logs, unsafe handling of keys, new dependencies nobody asked for.
- **compliance**: the change implements the ticket's rules and nothing else;
  it matches the design and the plan; it touches no path on the no-change list.

## Severity

- **high**: would break specified behavior, lose or leak data or funds, weaken a
  security property, or weaken a test or a gate. A high finding blocks the merge.
- **medium**: a real defect that does not meet the bar above.
- **low**: style, naming, small improvements.

Report at most five low findings; summarize the rest as a count.

## Always high

- An edit that makes an existing test weaker, skips it or deletes it.
- A change to `.github/`, `.claude/`, `scripts/`, `review/`, `tiers.txt` or this
  file that loosens a check.
- A dependency added or upgraded without a mention in the PR description.

## In this repository

Rule IDs are those of the feecalc specification. CWE numbers are MITRE's; API4
is "Unrestricted Resource Consumption" in the OWASP API Security Top 10 of 2023.

Always high:

- Arithmetic on an amount, a fee or a net amount outside `core/`, in `api/` or in
  `web/index.html`, or a fee or net amount that does not come from the fee calculation
  (FEE-SYS-01).
- A fee in `core/` that is not rounded up: `amount * 30 // 10_000` without the step that
  rounds up, or rounding to the nearest unit (FEE-CALC-02).
- A change to the rate of 30 in 10,000, to the limits of 10 and 5,000, or to which amounts
  are accepted, that no rule of the ticket asks for (FEE-CALC-01, -03, -04).
- An amount accepted that is not an `int` greater than zero, a `bool` included, or a refused
  amount answered with a fee of 0 or `None` instead of an error (FEE-CALC-04).
- A net amount clamped at zero, or a largest amount introduced (FEE-CALC-06, OPEN-2, OPEN-4).
- A path in `api/` that answers 200, or an answer with a `fee` key, when the amount is
  missing, not an integer or refused; a default fee in an `except` (FEE-SYS-03, FEE-API-02).
- A file path built from the request, or a handler that derives from
  `SimpleHTTPRequestHandler` (CWE-22, FEE-API-05).
- An entry in `dependencies` in `pyproject.toml`, or a change there that loosens a check: a
  rule set removed, an ignore added, `strict` dropped, a coverage threshold lowered.
- A module or name added to the lists in `scripts/check-architecture.py`.

Medium unless the finding meets the bar for high:

- An exception while reading the amount that is not turned into a 400: `int()` on more than
  4,300 digits, a missing, empty or repeated `amount` (CWE-20, API4).
- An error answer that carries a traceback, a file path or the text of an exception
  (CWE-209).
- Parsing of the amount that accepts more spellings than the PR description states: `int()`
  alone takes spaces, a sign, leading zeros, underscores and non-ASCII digits (OPEN-3).
- State kept between requests, or a write to disk: a module-level dict, cache or counter, a
  file, a log file (FEE-API-07).
- A JSON answer assembled by string formatting instead of `json.dumps`.
- A path other than `/fee`, `/health` and `/` that is not answered with 404, `/fee/` and
  `/index.html` included (FEE-API-05).
- In `web/index.html`: `innerHTML`, `document.write` or `eval` fed with the answer of `/fee`
  or with what the person typed (CWE-79); a fee shown when the answer was not 200
  (FEE-WEB-02); a request to another origin, or a script or stylesheet loaded from one.
- A test of a fee rule that leaves out the amounts at a limit (3,333 and 3,334; 1,666,666
  and 1,666,667), a non-whole raw fee, or the amounts 1, 9 and 10.

Not a weakened test: deleting `tests/core/test_placeholder.py` in the PR that adds the
first real test of `core/`.

## Do not report

- Anything the linter or the formatter already enforces.
- Generated files.
- Files under `docs/superpowers/`, except where they contradict the code.

## Output

One JSON document per reviewer, in the format of `review/findings.schema.json`.
Give every finding an `id` that stays the same if the review runs again on the
same code, and list the specification rule IDs it relates to.
