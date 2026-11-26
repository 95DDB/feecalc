"""The fee calculation: the only place in the system that decides a fee."""

from dataclasses import dataclass

FEE_RATE_BASIS_POINTS = 30
BASIS_POINTS = 10_000
MIN_FEE = 10
MAX_FEE = 5_000


class InvalidAmountError(ValueError):
    """The calculation refused the amount; the message says what is wrong."""


@dataclass(frozen=True)
class FeeResult:
    fee: int
    net: int


def calculate_fee(amount: int) -> FeeResult:
    # An exact type check also refuses bool, which is a subclass of int.
    # The messages never contain the amount: turning a very large integer
    # into text raises an error of its own.
    if type(amount) is not int:
        raise InvalidAmountError(
            f"amount must be an integer, not {type(amount).__name__}"
        )
    if amount <= 0:
        raise InvalidAmountError("amount must be greater than zero")
    # `//` rounds down, so negating before and after rounds the fee up.
    fee = -(-amount * FEE_RATE_BASIS_POINTS // BASIS_POINTS)
    fee = min(max(fee, MIN_FEE), MAX_FEE)
    return FeeResult(fee=fee, net=amount - fee)
