# AI-52: the fee calculation — design

Ticket: [AI-52](https://horizenlabs.atlassian.net/browse/AI-52), "Implement the fee
calculation: rate, rounding up, limits, refusal and net amount". Tier 1.
Specification: feecalc specification, version 8, chapter 6.

## Intent

One place decides the fee. Today `core/` is an empty package. This ticket puts
the fee calculation there as a pure function, so that the HTTP service
(AI-54) can ask it and never compute a fee or a net amount itself.

## Rules implemented

| Rule | Requirement |
| --- | --- |
| FEE-CALC-01 | For an accepted amount the fee is 0.30% of the amount (amount × 30 / 10,000), rounded as FEE-CALC-02 says and limited as FEE-CALC-03 says. |
| FEE-CALC-02 | When 0.30% of the amount is not a whole number, the fee is rounded up to the next whole unit. |
| FEE-CALC-03 | The fee is at least 10 units and at most 5,000 units. |
| FEE-CALC-04 | The calculation refuses, with an error and without a fee, any amount that is not an integer greater than zero. |
| FEE-CALC-06 | For an accepted amount the calculation returns the fee and the net amount together, and the net amount equals the amount minus the fee. |

FEE-CALC-05 is withdrawn: there is no largest amount, and none is built.

## Scope

**Changes**

- `core/fee.py`, new: the calculation, its result type and its error.
- `tests/core/test_fee.py`, new: the tests.
- `tests/core/test_placeholder.py`, deleted. Its own docstring says the first
  story that implements a fee rule replaces it.
- `README.md`: the status line, which says "no feature is built yet". The
  ticket's owner asked for this on 26 November 2026, although the file is
  outside the ticket's paths.
- `pyproject.toml`: `"*.md"` joins ruff's `extend-exclude`. Also asked for by
  the ticket's owner on 26 November 2026, and also outside the ticket's
  paths. It loosens a check: `ruff format --check` no longer looks at the
  Python code blocks in any Markdown file of the repository. The check does
  not need it today, because the code blocks in this design and in the plan
  were formatted before the exclusion was added; both local reviewers
  reported it as high under `REVIEW.md`, and the owner chose to keep it.

**Must not change**

- `api/` and `web/` (the ticket's no-change list). Neither exists yet and
  neither is created here.
- `scenarios/`. The chapter 6 scenarios go through `GET /fee`, so they keep
  waiting for FEE-API-01 and FEE-API-02 after this ticket.
- `scripts/check-architecture.py` and `CORE_IMPORTS`. The design needs only
  `dataclasses`, which is already allowed.
- `pyproject.toml`, apart from the ruff exclusion above: no new dependency.
- `core/__init__.py` stays empty. Callers import from `core.fee`.

`rules-implemented.txt` gets the five rule IDs from `/hl:open-pr`, not from
the implementation.

## Approaches

The specification fixes the arithmetic. What it leaves open is the shape of
the interface that `api/` will call. All three choices below are the
implementer's; none came from the ticket.

**The result**

| Option | Trade-off |
| --- | --- |
| `tuple[int, int]` | Least code. The caller tells fee from net by position, and both are `int`, so swapping them passes the type checker. |
| `NamedTuple` | Named fields, but still unpacks by position, so the same swap is possible. |
| **Frozen dataclass `FeeResult(fee, net)`** — picked | Named fields only, and a caller cannot change a result after the fact. A few lines more. |

**The refusal**

| Option | Trade-off |
| --- | --- |
| Built-in `TypeError` / `ValueError` | No new name. The caller cannot tell a refusal from a defect that happens to raise the same built-in. |
| **One class, `InvalidAmountError(ValueError)`** — picked | One thing to catch means "the calculation refused the amount". It is still a `ValueError`, which is what Python calls a bad value. |
| A class per reason | Nothing needs to tell the reasons apart: the message already says what is wrong. |

**What counts as an integer**

| Option | Trade-off |
| --- | --- |
| `isinstance(amount, int) and not isinstance(amount, bool)` | Refuses `bool`, accepts every other subclass of `int`, including one that overrides arithmetic or comparison. |
| **`type(amount) is int`** — picked | Refuses `bool` and every other subclass in one check. The cost is that an `IntEnum` member is refused too; nothing in the system passes one. |

## Interface

```python
# core/fee.py
class InvalidAmountError(ValueError): ...


@dataclass(frozen=True)
class FeeResult:
    fee: int
    net: int


def calculate_fee(amount: int) -> FeeResult: ...
```

| | |
| --- | --- |
| Input | `amount`: the transfer amount in whole units. Accepted only when `type(amount) is int` and `amount > 0`. |
| Result | `FeeResult(fee, net)`, both `int`, with `net == amount - fee`. The amount itself is not part of the result (Appendix A); the caller already has it. |
| Refusal | `InvalidAmountError` with a message that says what is wrong. Nothing is returned, so there is no fee, not even 0 or `None`. |
| Data | None. Nothing is read, written or kept. |

The steps, in the specification's order:

1. Refuse an amount whose type is not exactly `int`. Message: `amount must be
   an integer, not <type name>`.
2. Refuse an amount of zero or below. Message: `amount must be greater than
   zero`.
3. Raw fee, rounded up: `-(-amount * 30 // 10_000)`.
4. Limits: below 10 becomes 10, above 5,000 becomes 5,000.
5. Return the fee with `amount - fee`.

The limits come after rounding, as the specification's prose has it. It says
the order is a design choice, and both orders give the same fee.

The rate, the divisor and the two limits are named module constants. They are
not parameters: the ticket asks for one fee schedule.

## Edge cases and error behaviour

| Case | Behaviour |
| --- | --- |
| Raw fee whole (10,000 → 30) | Not rounded: the fee is 30, not 31. |
| Raw fee halfway (7,500 → 22.5) | Up, to 23. Not to the even neighbour 22. |
| Smallest fraction (20,001 → 60.003) | Up, to 61. |
| 3,000 (raw 9), 3,001 (raw 9.003), 3,333 (raw 9.999) | Fee 10: once from the minimum, twice from rounding. |
| 3,334 (raw 10.002) | Fee 11, the first above the minimum. |
| 1,666,333 (raw 4,998.999) | Fee 4,999, the last below the maximum. |
| 1,666,334 (raw 4,999.002) | Fee 5,000, reached by rounding. |
| 1,666,667 (raw 5,000.001) | Rounds to 5,001, limited to 5,000. |
| Amounts 1 to 9 | Fee 10, net negative, answered as computed (OPEN-4). 10 gives net 0. |
| Very large amounts (10^20, 10^5000) | Accepted. Fee 5,000. |
| 0, negative amounts | Refused. |
| `True`, `False` | Refused: `bool` is not exactly `int`. |
| `5.0`, `5.5`, `"5"`, `None`, `Decimal`, a subclass of `int` | Refused. |
| A negative integer of more than 4,300 digits | Refused with `InvalidAmountError` and the ordinary message. See the threat notes. |

## How each rule is tested

All tests are in `tests/core/test_fee.py`. Each rule has example tests at its
limits and a Hypothesis property, as `CLAUDE.md` asks. Each is written before
the code that makes it pass, and is seen to fail first.

| Rule | Examples | Property |
| --- | --- | --- |
| FEE-CALC-01 | Whole raw fees inside the limits: 10,000 → 30; 250,000 → 750; 480,000 → 1,440; 1,000,000 → 3,000. | For every positive amount, the fee equals an independent oracle: `Fraction(amount * 30, 10_000)`, `math.ceil`, then the limits. The oracle shares no arithmetic with the code. |
| FEE-CALC-02 | 10,100 → 31; 10,200 → 31; 12,400 → 38; 7,500 → 23; 5,500 → 17; 20,001 → 61; and 10,000 stays 30. | For every amount from 3,334 to 1,666,333, where no limit applies, the fee is the smallest whole number that is not below 0.30%: `fee * 10_000 >= amount * 30 > (fee - 1) * 10_000`. |
| FEE-CALC-03 | Minimum: 1, 1,000, 3,000, 3,001, 3,333 → 10; 3,334 → 11. Maximum: 1,666,333 → 4,999; 1,666,334, 1,666,666, 1,666,667, 2,000,000, 10^20, 10^5000 → 5,000. | For every positive amount, `10 <= fee <= 5_000`. |
| FEE-CALC-04 | 0, -1, -480,000, `-(10**5000)`, `True`, `False`, `1.0`, `5.5`, `"5"`, `None`, `Decimal(5)`, a subclass of `int`: each raises `InvalidAmountError` with a message. | Every integer of zero or below raises it. Every generated boolean, float, text, bytes and `None` raises it. |
| FEE-CALC-06 | 1 → (10, -9); 5 → (10, -5); 9 → (10, -1); 10 → (10, 0); 11 → (10, 1); 250,000 → (750, 249,250). A result cannot be changed after it is returned. | For every positive amount, `net == amount - fee`, and both are exactly `int`. |

The tests use the specification's four examples and others worked out here.
`make verify` holds `core/` to 100% line and branch coverage.

## Constraints

- **Dependencies.** None at run time. `core/fee.py` imports `dataclasses`
  only, which `CORE_IMPORTS` lists.
- **Integers only.** No float, no `/`, no `round`. `check-architecture.py`
  enforces it.
- **Purity.** No input or output, no module-level state.
- **Performance.** One multiplication by 30 and one floor division by 10,000.
  The cost grows linearly with the number of digits of the amount.
- **Compatibility.** This is the first interface of `core/`. AI-54 builds on
  `calculate_fee`, `FeeResult` and `InvalidAmountError`.

## Threat notes

**Assets.** The fee and the net amount: they decide money. And the guarantee
that one place computes them (FEE-SYS-01).

**Trust boundary.** `core/` is called by `api/` with a value that came from
an untrusted request. `core/` does not rely on its caller having checked the
value: it checks the type and the sign itself (FEE-CALC-04).

**Invariants.** For an accepted amount: `10 <= fee <= 5_000`; the fee is the
limited, rounded-up 0.30%; `net == amount - fee`; both are exactly `int`. For
any other value: an error and no result. In both cases: no side effect.

**Known attacks and pitfalls on this pattern, and the answer here**

| Pitfall | Applies? | Answer |
| --- | --- | --- |
| Integer division that truncates, so the fee rounds in the payer's favour, small amounts pay nothing, and a large transfer is split into small ones to dodge the fee. This is the commonest finding on fee code in public audit reports. | Yes | The fee rounds up, never down, and is never below 10. Splitting a transfer costs at least 10 per part, so it pays more, not less. The multiplication happens before the division, so nothing is lost before rounding. |
| The ceiling idiom written with the parentheses in the wrong place: `-(-a) // b` is plain floor division. | Yes | The code uses `-(-amount * 30 // 10_000)` as `CLAUDE.md` gives it. The FEE-CALC-02 examples and property fail for a floor. |
| Floating point in a money calculation. | Excluded | No float exists in `core/`; the architecture check fails the build if one appears. |
| `bool` is a subclass of `int`: `isinstance(True, int)` is true, so `True` would be charged as an amount of 1. | Yes | The check is `type(amount) is int`. |
| A subclass of `int` that overrides `*`, `//` or `<=` and so chooses its own fee. | Yes | Same check: only exact `int` is accepted. |
| A negative amount giving a negative fee, or a fee of 10 on a negative amount. | Yes | Refused before any arithmetic. |
| Python's limit on converting an integer to or from decimal text (4,300 digits by default, CVE-2020-10735). Formatting a huge amount into an error message raises a bare `ValueError` with an unrelated message, and the conversion is the slow operation the limit exists to stop. | Yes | `core/` never turns the amount into text. The error messages name the type, never the value. Arithmetic on a huge integer is not limited and stays linear. Bounding the length of a request is the HTTP service's job (AI-54). |
| An error message that repeats the caller's input and ends up in a JSON answer or on the demo page. | Yes | The messages contain no input. Only a built-in type name can vary. |
| A caller changing the result before answering with it. | Yes | `FeeResult` is frozen. |
| Fixed-width integer overflow. | No | Python integers have no fixed width. |

## What was read

- Run time: Python 3.12.3 (`.python-version` says 3.12). Test tools as pinned
  in `pyproject.toml`: pytest 9.2.0, hypothesis 6.170.17.
- Web, 26 November 2026, searching for the technology only:
  - Floor division rounds toward negative infinity, and `-(-a // b)` is the
    ceiling: the search returned secondary sources and python.org mailing-list
    and tracker threads (issue 46639, `math.ceildiv`), not the language
    reference itself. The claim also rests on what was known beforehand, and
    was checked by running the idiom against `math.ceil(Fraction(...))` for
    the amounts in this design.
  - The integer string conversion limit: default 4,300 digits, base 10 and
    other bases that are not a power of two, raises `ValueError`
    (CVE-2020-10735, fixed in the September 2022 releases). Confirmed on
    Python 3.12.3: `str(-(10**5000))` raises it.
  - `bool` as a subclass of `int`: python.org tracker and list threads
    (issue 45891).
  - Rounding direction in fee code: public audit findings and write-ups.
    These are blogs and contest reports, not primary sources; they were used
    to name the pitfall, not as authority.

## Left to the builder

Test names and the exact wording of the two error messages, within what this
design says they contain.
