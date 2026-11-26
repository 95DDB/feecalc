---
id: FEE-SC-06-03
chapter: 6
rules: [FEE-CALC-01, FEE-CALC-03, FEE-CALC-06, FEE-API-01]
roles: [client]
---
# When the fee is larger than the amount, the net amount is answered as computed

## Setup

The service is running and the client can reach it. The fee calculation has
no way in of its own, so every amount is asked through `GET /fee`.

## Steps

1. The client sends `GET /fee?amount=1`, the smallest amount.
2. The client sends `GET /fee?amount=3`.
3. The client sends `GET /fee?amount=9`.
4. The client sends `GET /fee?amount=10`.
5. The client sends `GET /fee?amount=11`.

## Expected

- All five requests are answered with 200. None is refused because the fee
  is larger than the amount.
- Step 1 answers `{"amount": 1, "fee": 10, "net": -9}`.
- Step 2 answers `{"amount": 3, "fee": 10, "net": -7}`.
- Step 3 answers `{"amount": 9, "fee": 10, "net": -1}`.
- Step 4 answers `{"amount": 10, "fee": 10, "net": 0}`.
- Step 5 answers `{"amount": 11, "fee": 10, "net": 1}`.
- In every answer the fee is the minimum of 10: it is not lowered to the
  amount, and the net amount is not raised to 0.
