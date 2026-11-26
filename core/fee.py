"""The fee calculation: the only place in the system that decides a fee."""

from dataclasses import dataclass

FEE_RATE_BASIS_POINTS = 30
BASIS_POINTS = 10_000


@dataclass(frozen=True)
class FeeResult:
    fee: int
    net: int


def calculate_fee(amount: int) -> FeeResult:
    # `//` rounds down, so negating before and after rounds the fee up.
    fee = -(-amount * FEE_RATE_BASIS_POINTS // BASIS_POINTS)
    return FeeResult(fee=fee, net=amount - fee)
