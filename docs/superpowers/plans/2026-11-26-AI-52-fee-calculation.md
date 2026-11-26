# AI-52 Fee Calculation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the fee calculation in `core/` as a pure function that returns the fee and the net amount for an accepted amount and refuses every other value.

**Architecture:** One module, `core/fee.py`, with one function, a frozen result type and one error class. Integer arithmetic only. The function is grown rule by rule: each task adds the tests of one rule, sees them fail, then adds the few lines that make them pass.

**Tech Stack:** Python 3.12, standard library only at run time (`dataclasses`). Tests: pytest 9.2.0, hypothesis 6.170.17.

**Spec:** `docs/superpowers/specs/2026-11-26-AI-52-fee-calculation-design.md`. Ticket AI-52; feecalc specification version 8, chapter 6.

## Global Constraints

- Rules implemented: FEE-CALC-01, FEE-CALC-02, FEE-CALC-03, FEE-CALC-04, FEE-CALC-06. Nothing else.
- Touch only `core/fee.py`, `tests/core/test_fee.py`, `tests/core/test_placeholder.py` (deleted), the status line of `README.md` (Task 5) and ruff's `extend-exclude` in `pyproject.toml`. The last two are outside the ticket's paths; the ticket's owner asked for both on 26 November 2026. Do not create or change `api/`, `web/`, `scenarios/`, `scripts/` or `core/__init__.py`, and add no dependency.
- `pyproject.toml` was changed before Task 1: `"*.md"` joined ruff's `extend-exclude`, so that `ruff format` leaves the code blocks in this plan and in the design alone.
- `rules-implemented.txt` is updated by `/hl:open-pr`, not here.
- `core/fee.py` imports `dataclasses` only. No float literal, no `/`, and none of the names `float`, `round`, `open`, `print`, `input`.
- Round the fee up with `-(-amount * 30 // 10_000)`. Plain `//` rounds down.
- Accept an amount only when `type(amount) is int` and `amount > 0`. A refusal raises; it never returns a fee of 0 or `None`.
- Never turn the amount into text: no f-string, `str()` or `repr()` of the value, in code or in an error message.
- No module-level state other than constants.
- Run every tool through `uv run --locked`. One test: `uv run --locked pytest tests/core -k <name>`.
- A committed test is never edited to make it pass. Each task commits its failing tests first, then the code.
- Commit unsigned (`git commit --no-gpg-sign`), with the trailer `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.
- Every test function is annotated `-> None`; `mypy` runs in strict mode over the tests too.

## Review Focus

Inputs the specification implies without spelling out. Each is pinned by a test in the task named.

1. A negative integer of more than 4,300 digits: refused with the ordinary message, not with Python's own "Exceeds the limit" `ValueError`. Task 4.
2. `True` and `False`: refused, not charged as amounts 1 and 0. Task 4.
3. A whole-valued float such as `1.0`, and `nan`: refused, not converted. Task 4.
4. A subclass of `int`: refused. Task 4.
5. A positive integer of 5,001 digits: accepted, fee 5,000. Task 3.

## File Structure

| File | Responsibility |
| --- | --- |
| `core/fee.py` (create) | `calculate_fee`, `FeeResult`, `InvalidAmountError`, and the four constants. |
| `tests/core/test_fee.py` (create) | Every test of the five rules, named `test_calc_<rule number>_...`. |
| `tests/core/test_placeholder.py` (delete) | Its docstring says the first fee story replaces it. |

An integer of more than 4,300 digits cannot be a bare `pytest.mark.parametrize` value: pytest builds the test id with `str()`, which raises. Wrap it as `pytest.param(<value>, ..., id="<name>")`.

---

### Task 1: The rate on whole raw fees, and the result (FEE-CALC-01, FEE-CALC-06)

**Files:**
- Create: `core/fee.py`
- Create: `tests/core/test_fee.py`
- Delete: `tests/core/test_placeholder.py`

**Interfaces:**
- Produces: `core.fee.calculate_fee(amount: int) -> FeeResult`; `core.fee.FeeResult`, a frozen dataclass with fields `fee: int` and `net: int`, in that order; in the test module, the strategy `positive_amounts`.

- [ ] **Step 1: Write the failing tests**

`tests/core/test_fee.py`, with a one-line module docstring:

```python
import dataclasses

import pytest
from hypothesis import given
from hypothesis import strategies as st

from core.fee import FeeResult, calculate_fee

# The bounded half samples the amounts where no limit applies.
# The other half has no upper bound.
positive_amounts = st.one_of(
    st.integers(min_value=1, max_value=2_000_000), st.integers(min_value=1)
)


@pytest.mark.parametrize(
    ("amount", "fee"),
    [(10_000, 30), (250_000, 750), (480_000, 1_440), (1_000_000, 3_000)],
)
def test_calc_01_fee_is_30_basis_points_when_that_is_whole(
    amount: int, fee: int
) -> None:
    assert calculate_fee(amount).fee == fee


def test_calc_06_returns_fee_and_net_together() -> None:
    assert calculate_fee(250_000) == FeeResult(fee=750, net=249_250)


@given(positive_amounts)
def test_calc_06_net_is_amount_minus_fee_in_whole_units(amount: int) -> None:
    result = calculate_fee(amount)
    assert result.net == amount - result.fee
    assert type(result.fee) is int
    assert type(result.net) is int


def test_calc_06_result_cannot_be_changed() -> None:
    result = calculate_fee(250_000)
    with pytest.raises(dataclasses.FrozenInstanceError):
        result.fee = 0  # type: ignore[misc]
```

Delete `tests/core/test_placeholder.py` with `git rm`.

- [ ] **Step 2: Run the tests and see them fail**

Run: `uv run --locked pytest tests/core`
Expected: collection error, `ModuleNotFoundError: No module named 'core.fee'`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/core/test_fee.py tests/core/test_placeholder.py
git commit --no-gpg-sign -m "AI-52 Test the fee rate and the result of the calculation"
```

- [ ] **Step 4: Implement `calculate_fee(amount: int) -> FeeResult` in `core/fee.py`**

Module constants `FEE_RATE_BASIS_POINTS = 30` and `BASIS_POINTS = 10_000`. `FeeResult` is `@dataclass(frozen=True)`. In this task the fee is `amount * FEE_RATE_BASIS_POINTS // BASIS_POINTS` and the net amount is `amount - fee`. No rounding up, no limits and no checks yet: Tasks 2 to 4 add each against a failing test.

- [ ] **Step 5: Run the tests and see them pass**

Run: `uv run --locked pytest tests/core`
Expected: 7 passed.

- [ ] **Step 6: Commit**

```bash
git add core/fee.py
git commit --no-gpg-sign -m "AI-52 Add the fee calculation: rate and net amount"
```

---

### Task 2: Rounding up (FEE-CALC-02)

**Files:**
- Modify: `core/fee.py`
- Modify: `tests/core/test_fee.py` (append only)

**Interfaces:**
- Consumes: `calculate_fee`, from Task 1.

- [ ] **Step 1: Write the failing tests**

Append:

```python
@pytest.mark.parametrize(
    ("amount", "fee"),
    [(10_100, 31), (10_200, 31), (12_400, 38), (7_500, 23), (5_500, 17), (20_001, 61)],
)
def test_calc_02_fraction_of_a_unit_rounds_up(amount: int, fee: int) -> None:
    assert calculate_fee(amount).fee == fee


@given(st.integers(min_value=3_334, max_value=1_666_333))
def test_calc_02_fee_is_smallest_whole_number_not_below_the_rate(amount: int) -> None:
    fee = calculate_fee(amount).fee
    assert fee * 10_000 >= amount * 30 > (fee - 1) * 10_000
```

7,500 and 5,500 have a raw fee that ends in .5: they tell rounding up from rounding half to even. 3,334 to 1,666,333 is the range where neither limit applies.

- [ ] **Step 2: Run the tests and see them fail**

Run: `uv run --locked pytest tests/core -k calc_02`
Expected: 7 failed. For 10,100 the message is `assert 30 == 31`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/core/test_fee.py
git commit --no-gpg-sign -m "AI-52 Test that the fee rounds up"
```

- [ ] **Step 4: Round the raw fee up in `calculate_fee`**

Replace the floor division with exactly `-(-amount * FEE_RATE_BASIS_POINTS // BASIS_POINTS)`. Keep the parentheses as written: `-(-a) // b` is a floor. Add one comment that says why the double negation is there.

- [ ] **Step 5: Run the tests and see them pass**

Run: `uv run --locked pytest tests/core`
Expected: 14 passed. `test_calc_01_...[10000-30]` still passes: a whole raw fee is not pushed up.

- [ ] **Step 6: Commit**

```bash
git add core/fee.py
git commit --no-gpg-sign -m "AI-52 Round the fee up to the next whole unit"
```

---

### Task 3: The limits (FEE-CALC-03, and the whole of FEE-CALC-01)

**Files:**
- Modify: `core/fee.py`
- Modify: `tests/core/test_fee.py` (append; add two imports)

**Interfaces:**
- Consumes: `calculate_fee`, `FeeResult`, `positive_amounts`, from Task 1.

- [ ] **Step 1: Write the failing tests**

Add `import math` and `from fractions import Fraction` to the imports, and append:

```python
@pytest.mark.parametrize(
    ("amount", "fee"),
    [
        (1, 10),
        (1_000, 10),
        (3_000, 10),
        (3_001, 10),
        (3_333, 10),
        (3_334, 11),
        (1_666_333, 4_999),
        (1_666_334, 5_000),
        (1_666_666, 5_000),
        (1_666_667, 5_000),
        (2_000_000, 5_000),
        (10**20, 5_000),
        pytest.param(10**5000, 5_000, id="10^5000"),
    ],
)
def test_calc_03_fee_at_and_around_the_limits(amount: int, fee: int) -> None:
    assert calculate_fee(amount).fee == fee


@given(positive_amounts)
def test_calc_03_fee_is_never_outside_the_limits(amount: int) -> None:
    assert 10 <= calculate_fee(amount).fee <= 5_000


@given(positive_amounts)
def test_calc_01_fee_matches_an_independent_calculation(amount: int) -> None:
    raw_fee = math.ceil(Fraction(amount * 30, 10_000))
    assert calculate_fee(amount).fee == min(max(raw_fee, 10), 5_000)


@pytest.mark.parametrize(
    ("amount", "fee", "net"),
    [(1, 10, -9), (5, 10, -5), (9, 10, -1), (10, 10, 0), (11, 10, 1)],
)
def test_calc_06_net_is_answered_as_computed_when_the_fee_exceeds_the_amount(
    amount: int, fee: int, net: int
) -> None:
    assert calculate_fee(amount) == FeeResult(fee=fee, net=net)
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `uv run --locked pytest tests/core -k "calc_03 or independent or exceeds"`
Expected: 14 failed, 6 passed. The six that pass already are the amounts from 3,001 to 1,666,666, where rounding alone gives the fee; they pin the edges of the limits. For amount 1 the message is `assert 1 == 10`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/core/test_fee.py
git commit --no-gpg-sign -m "AI-52 Test the minimum and maximum fee"
```

- [ ] **Step 4: Apply the limits in `calculate_fee`**

Module constants `MIN_FEE = 10` and `MAX_FEE = 5_000`. After rounding, a fee below `MIN_FEE` becomes `MIN_FEE` and a fee above `MAX_FEE` becomes `MAX_FEE`. The net amount is computed from the limited fee.

- [ ] **Step 5: Run the tests and see them pass**

Run: `uv run --locked pytest tests/core`
Expected: 34 passed.

- [ ] **Step 6: Commit**

```bash
git add core/fee.py
git commit --no-gpg-sign -m "AI-52 Limit the fee to between 10 and 5,000 units"
```

---

### Task 4: Refusal (FEE-CALC-04)

**Files:**
- Modify: `core/fee.py`
- Modify: `tests/core/test_fee.py` (append; add imports)

**Interfaces:**
- Consumes: `calculate_fee`, from Task 1.
- Produces: `core.fee.InvalidAmountError`, a subclass of `ValueError`. AI-54 catches it.

- [ ] **Step 1: Write the failing tests**

Add `from decimal import Decimal` and `from typing import Any`, extend the import from `core.fee` with `InvalidAmountError`, and append:

```python
class _IntSubclass(int):
    pass


def test_calc_04_refusal_is_caught_as_a_value_error() -> None:
    with pytest.raises(ValueError, match="greater than zero"):
        calculate_fee(0)


@pytest.mark.parametrize(
    "amount", [0, -1, -480_000, pytest.param(-(10**5000), id="-10^5000")]
)
def test_calc_04_refuses_zero_and_below(amount: int) -> None:
    with pytest.raises(InvalidAmountError) as refusal:
        calculate_fee(amount)
    assert str(refusal.value) == "amount must be greater than zero"


@pytest.mark.parametrize(
    "amount",
    [True, False, 1.0, 5.5, float("nan"), "5", None, Decimal(5), _IntSubclass(100)],
)
def test_calc_04_refuses_what_is_not_an_integer(amount: Any) -> None:
    with pytest.raises(InvalidAmountError) as refusal:
        calculate_fee(amount)
    assert (
        str(refusal.value) == f"amount must be an integer, not {type(amount).__name__}"
    )


@given(st.integers(max_value=0))
def test_calc_04_refuses_every_integer_of_zero_or_below(amount: int) -> None:
    with pytest.raises(InvalidAmountError):
        calculate_fee(amount)


@given(st.one_of(st.booleans(), st.floats(), st.text(), st.binary(), st.none()))
def test_calc_04_refuses_every_value_that_is_not_an_integer(amount: Any) -> None:
    with pytest.raises(InvalidAmountError):
        calculate_fee(amount)
```

`pytest.raises` proves "without a fee": a call that raises returns nothing.

Changed during implementation: the first test was `assert issubclass(InvalidAmountError, ValueError)`. It now calls the function and catches the refusal as a `ValueError`, so it proves what a caller relies on and not how the class is declared.

The whole file imports `InvalidAmountError`, so Step 2 fails at import. To see each test fail on behaviour, add the bare class first and run again: 16 failed, most with `DID NOT RAISE`.

- [ ] **Step 2: Run the tests and see them fail**

Run: `uv run --locked pytest tests/core`
Expected: collection error, `ImportError: cannot import name 'InvalidAmountError' from 'core.fee'`.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/core/test_fee.py
git commit --no-gpg-sign -m "AI-52 Test that the calculation refuses a bad amount"
```

- [ ] **Step 4: Add `InvalidAmountError` and the two checks to `core/fee.py`**

`class InvalidAmountError(ValueError)`. At the top of `calculate_fee`, before any arithmetic and in this order:

1. `type(amount) is not int` raises `InvalidAmountError(f"amount must be an integer, not {type(amount).__name__}")`.
2. `amount <= 0` raises `InvalidAmountError("amount must be greater than zero")`.

The messages are exact. Neither contains the amount's value.

- [ ] **Step 5: Run the tests and see them pass**

Run: `uv run --locked pytest tests/core`
Expected: 50 passed.

- [ ] **Step 6: Commit**

```bash
git add core/fee.py
git commit --no-gpg-sign -m "AI-52 Refuse an amount that is not an integer above zero"
```

---

### Task 5: The status line of the README

**Files:**
- Modify: `README.md:8-9`

No test: the line is prose. It changes only after Task 4, when it is true.

- [ ] **Step 1: Replace the status paragraph**

New text: "**Status:** the fee calculation is built, in `core/fee.py`. The HTTP service and the demo page are not built yet."

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit --no-gpg-sign -m "AI-52 Say in the README that the fee calculation is built"
```

---

## Finish

- [ ] **Run the project's checks**

Run: `make verify`
Expected: every command exits 0; `coverage report --include='core/*' --fail-under=100` shows `core/fee.py` at 100% with no missing line or branch. Paste the output in the report.

- [ ] **Check the scope of the diff**

Run: `git diff --stat main...HEAD`
Expected: only `core/fee.py`, `tests/core/test_fee.py`, `tests/core/test_placeholder.py`, `README.md`, `pyproject.toml` and the two files under `docs/superpowers/`.

- [ ] **Hand over**

If the code departed from this plan or from the design, update both files in the same branch. Then `/hl:open-pr`, which adds the five rule IDs to `rules-implemented.txt` and runs `make ci` through the pre-push hook. The PR description carries the three interface choices from the design's "Approaches" section, and names `README.md` and `pyproject.toml` as changes outside the ticket's paths that its owner asked for. It describes the `pyproject.toml` change as a loosened check, in those words: `ruff format` no longer looks at the Python code blocks in any Markdown file. `REVIEW.md` rates an added exclusion high, so the description says what is switched off, why, and that keeping the code blocks formatted instead was the alternative.
