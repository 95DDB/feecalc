---
id: FEE-SC-07-02
chapter: 7
rules: [FEE-API-01, FEE-API-02, FEE-CALC-01, FEE-CALC-06]
roles: [client]
---
# A fee request is answered as JSON, or refused with 400 and no guessed fee

## Setup

The service is running and the client can reach it.

## Steps

1. The client sends `GET /fee?amount=36000`.
2. The client sends `GET /fee`, with no amount.
3. The client sends `GET /fee?value=36000`, the amount under another name.
4. The client sends `GET /fee?amount=`, the amount left empty.
5. The client sends `GET /fee?amount=ten`.
6. The client sends `GET /fee?amount=12abc`.
7. The client sends `GET /fee?amount=10.5`.

## Expected

- Step 1 is answered with 200 and the JSON object
  `{"amount": 36000, "fee": 108, "net": 35892}`.
- In the answer of step 1 the amount, the fee and the net amount are whole
  numbers: none is written with a fraction or as text.
- Steps 2 to 7 are each answered with 400.
- Each answer of steps 2 to 7 is a JSON object of the form
  `{"error": "<what is wrong>"}`: the value of `error` is a message a
  developer can read, and it says what is wrong with the request.
- None of the answers of steps 2 to 7 contains a fee (FEE-SYS-03). In
  particular step 6 is not answered with the fee for 12, and step 7 is not
  answered with the fee for 10 or for 11.
