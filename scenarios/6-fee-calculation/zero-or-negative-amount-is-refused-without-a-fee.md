---
id: FEE-SC-06-02
chapter: 6
rules: [FEE-CALC-04, FEE-API-02]
roles: [client]
---
# An amount of zero or below is refused, and never answered with a fee

## Setup

The service is running and the client can reach it. The fee calculation has
no way in of its own, so every amount is asked through `GET /fee`.

## Steps

1. The client sends `GET /fee?amount=0`.
2. The client sends `GET /fee?amount=-1`.
3. The client sends `GET /fee?amount=-480000`.

## Expected

- Each of the three requests is answered with 400.
- Each answer is a JSON object of the form `{"error": "<what is wrong>"}`: the
  value of `error` is a message a developer can read, and it says what is
  wrong with the amount.
- None of the three answers contains a fee (FEE-SYS-03): not a fee of 0, not
  the minimum fee of 10, and for `-480000` not a fee of 1440 or -1440.
