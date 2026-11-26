---
id: FEE-SC-08-01
chapter: 8
rules: [FEE-WEB-01, FEE-WEB-02, FEE-API-01, FEE-API-02, FEE-API-04, FEE-CALC-01, FEE-CALC-03, FEE-CALC-04, FEE-CALC-06]
roles: [person, client]
---
# The demo page shows the fee and net amount that /fee answers, and the error when /fee refuses

## Setup

The service is running. A person has a web browser that can reach it. A
client can send requests to the same service directly, to compare.

## Steps

1. The person opens `/` of the service in the browser.
2. The person enters `64000` in the amount field.
3. The client sends `GET /fee?amount=64000` to the same service.
4. The person enters `7` in the amount field.
5. The person enters `0` in the amount field.
6. The client sends `GET /fee?amount=0` to the same service.
7. The person enters `-64000` in the amount field.

## Expected

- Step 1 answers with the demo page: one page with a field for the amount.
- After step 2 the page shows the fee, 192, and the net amount, 63808.
- Step 3 is answered with 200 and `{"amount": 64000, "fee": 192, "net": 63808}`:
  the page shows the same fee and the same net amount as `/fee` answers
  (FEE-SYS-01).
- After step 4 the page shows the fee, 10, and the net amount, -3. The
  negative net amount is shown as answered: it is not hidden, not shown as
  0 and not shown as 3.
- After step 5 the page shows an error message, and it shows no fee: no fee
  for 0, and no longer the fee of 10 from step 4.
- Step 6 is answered with 400 and a JSON object of the form
  `{"error": "<what is wrong>"}`. The message the page showed after step 5
  is the message of this answer.
- After step 7 the page shows an error message and no fee (FEE-SYS-03).
