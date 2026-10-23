# services

Contracts of the phase-2 services. The self-hosted API itself (`services/api/`, Fastify + PostgreSQL)
moved to its own repository on 2026-10-23, history included: https://github.com/thanhngochoang/booking-be.
Older plans under `docs/superpowers/plans/` still say `services/api`; read that as the booking-be repo.
The app keeps a snapshot of its contract in `app_flutter/test/data/contracts/`.

- `dispatch/` — instant-booking dispatch service contract (phase 1 runs on Cloud Functions, #140).
- `recommender/` — recommender service contract.
