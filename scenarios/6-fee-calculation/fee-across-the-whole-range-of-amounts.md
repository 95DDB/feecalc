---
id: FEE-SC-06-01
chapter: 6
rules: [FEE-CALC-01, FEE-CALC-02, FEE-CALC-03, FEE-CALC-06, FEE-API-01]
roles: [client]
---
# The fee is 0.30% of the amount, rounded up, never below 10 and never above 5,000

## Setup

The service is running and the client can reach it. The fee calculation has
no way in of its own, so every amount is asked through `GET /fee`.

## Steps

1. The client sends `GET /fee?amount=<amount>` once for each amount in the
   table below, in any order. The amount is written in digits only, without
   separators.

| Amount | 0.30% of the amount | Fee | Net amount | What it shows |
|---|---|---|---|---|
| 480000 | 1,440 | 1440 | 478560 | A whole number within the limits. |
| 12400 | 37.2 | 38 | 12362 | Rounded up, although 37 is nearer. |
| 7500 | 22.5 | 23 | 7477 | A halfway value goes up, not to the even neighbour 22. |
| 20001 | 60.003 | 61 | 19940 | The smallest fraction still rounds up. |
| 3000 | 9 | 10 | 2990 | Below the minimum, so the fee is 10. |
| 3333 | 9.999 | 10 | 3323 | The last amount whose fee is the minimum. |
| 3334 | 10.002 | 11 | 3323 | The first amount whose fee is above the minimum. |
| 1666333 | 4,998.999 | 4999 | 1661334 | The last amount whose fee is below the maximum. |
| 1666334 | 4,999.002 | 5000 | 1661334 | Rounding up reaches the maximum exactly. |
| 1666667 | 5,000.001 | 5000 | 1661667 | Above the maximum, so the fee is 5,000. |
| 3000000 | 9,000 | 5000 | 2995000 | Far above the maximum. |
| 5000000000000 | 15,000,000,000 | 5000 | 4999999995000 | There is no largest amount. |
| 100000000000000000000 | 300,000,000,000,000,000 | 5000 | 99999999999999995000 | There is no largest amount. |

## Expected

- Every request is answered with 200.
- Every answer is the JSON object `{"amount": <amount>, "fee": <fee>, "net": <net amount>}`
  with the amount that was asked and the fee and the net amount of its row.
- In every answer the amount, the fee and the net amount are whole numbers
  (FEE-SYS-02): none is written with a fraction or as text.
- In every answer the net amount equals the amount minus the fee.
- No answer carries a fee below 10 or above 5000.
- No amount is refused for being too large.
