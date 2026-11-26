"""Tests of the fee calculation, each named after the rule it proves."""

import dataclasses
import math
from decimal import Decimal
from fractions import Fraction
from typing import Any

import pytest
from hypothesis import given
from hypothesis import strategies as st

from core.fee import FeeResult, InvalidAmountError, calculate_fee

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
