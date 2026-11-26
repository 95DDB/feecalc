"""Tests of the fee calculation, named after the rule of the specification they prove."""

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
