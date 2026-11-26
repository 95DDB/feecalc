---
id: FEE-SC-07-03
chapter: 7
rules: [FEE-API-01, FEE-API-02, FEE-API-06, FEE-API-07, FEE-CALC-01, FEE-CALC-06]
roles: [deployment, client]
---
# Nothing is kept between requests: a second copy and a restart answer alike

## Setup

The deployment starts two copies of the service side by side on one
machine: copy A with `PORT` set to `8081` and copy B with `PORT` set to
`8082`. Any two free ports will do. Neither copy has received a request yet.

## Steps

1. The client sends `GET /fee?amount=725000` to copy A.
2. The client sends `GET /fee`, with no amount, to copy A.
3. The client sends `GET /fee?amount=1250000` to copy A.
4. The client sends `GET /fee?amount=725000` to copy A again.
5. The client sends `GET /fee?amount=725000` to copy B. It is the first
   request copy B receives.
6. The deployment stops copy A and starts it again with `PORT` set to
   `8081`.
7. The client sends `GET /fee?amount=725000` to copy A.

## Expected

- Steps 1, 4, 5 and 7 are each answered with 200 and the same JSON object,
  `{"amount": 725000, "fee": 2175, "net": 722825}`.
- Step 2 is answered with 400 and a JSON object of the form
  `{"error": "<what is wrong>"}` that contains no fee.
- Step 3 is answered with 200 and `{"amount": 1250000, "fee": 3750, "net": 1246250}`.
- The refusal of step 2 and the other amount of step 3 leave no trace in
  the answer of step 4.
- Copy B, which saw none of the earlier requests, answers as copy A does.
- The restart of step 6 loses nothing: step 7 is answered as step 1 was.
