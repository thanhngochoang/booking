# Contract snapshot of the self-hosted backend

`openapi.yaml` and `contract-world.json` are copies of `api/openapi.yaml` and
`test/fixtures/contract-world.json` in the backend repository
https://github.com/thanhngochoang/booking-be (the former `services/api/` of this repo).

- `test/data/http/openapi_drift_test.dart` checks the hand-written HTTP client against `openapi.yaml`.
- `contract_world.dart` reads `contract-world.json`, the fixture world the backend seeds with
  `npm run seed:contract`; `selfhosted_contracts_test.dart` runs against that stack.

When the backend contract changes, copy both files again and make the app follow.
