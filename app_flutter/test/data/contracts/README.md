# Contract snapshot of the self-hosted backend

`openapi.yaml` and `contract-world.json` are copies of `api/openapi.yaml` and
`test/fixtures/contract-world.json` in the backend repository
https://github.com/thanhngochoang/booking-be (the former `services/api/` of this repo).

- `test/data/http/openapi_drift_test.dart` checks the hand-written HTTP client against `openapi.yaml`.
- `contract_world.dart` reads `contract-world.json`, the fixture world the backend seeds with
  `npm run seed:contract`; `selfhosted_contracts_test.dart` runs against that stack.

When the backend contract changes, copy both files again and make the app follow.

`day_pricing_cases.json` is a copy of `packages/domain/test/fixtures/day_pricing_cases.json` in the same
repository; `test/data/pricing/day_pricing_test.dart` runs it against the Dart port. Copy it again when it changes.
