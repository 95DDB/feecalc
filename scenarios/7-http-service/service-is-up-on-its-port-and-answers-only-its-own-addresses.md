---
id: FEE-SC-07-01
chapter: 7
rules: [FEE-API-03, FEE-API-05, FEE-API-06]
roles: [deployment, client]
---
# The service is up on its port and answers only its own addresses

## Setup

No copy of the service is running. Ports 8080 and 9090 are free on the
machine. Any other free port can stand in for 9090.

## Steps

1. The deployment starts the service with the `PORT` environment variable
   not set.
2. The deployment sends `GET /health` to port 8080.
3. The deployment stops the service and starts it again with `PORT` set to
   `9090`.
4. The deployment sends `GET /health` to port 9090.
5. The client sends each of these requests to port 9090:
   `GET /healthz`, `GET /health/status`, `GET /fees?amount=250000`,
   `GET /fee/250000`, `GET /index.html`, `GET /web/index.html`.

## Expected

- Step 2 is answered with 200 and the JSON object `{"status": "ok"}`.
- Step 4 is answered with 200 and the JSON object `{"status": "ok"}`: the
  service listens on the port that `PORT` names.
- Each of the six requests of step 5 is answered with 404.
