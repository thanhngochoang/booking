# SDD ledger — plan: docs/superpowers/plans/2026-10-01-backend-phase2-selfhosted-postgres.md

Unit: Plan 9 (`backend-phase2`)
Branch: `plan/9-backend-phase2`

## Tasks & Commits
- Task 1: Scaffold self-hosted API with health endpoint, compose stack and CI (`36330a8`)
- Task 2: Slice migrations from relational schema with rollback tests (`0f11126`)
- Task 3: OpenAPI contract, error envelope, ULIDs and reuse of the phase 1 domain module (`ddacd9e`)
- Task 4: Authentication with Firebase ID tokens & POST /v1/me with auth identities (`f0b2fb5`)
- Task 5: Public profile, set_role and owner-only private contact with authorization matrix tests (`f0147f0`)
- Task 6: Photographer contact channels, private numbers, service area and S34 setup (`8055acd`)
- Task 7: get_contact_link with contact access log and a shared contract world (`a0510d1`)
- Task 8: Flutter HTTP adapters for the self-hosted slice behind existing ports (`c9031c0`)
- Task 9: One contract suite per port across Fake, Firestore and HTTP, plus openapi drift test (`a5474fa`)
- Task 10: Idempotent Firestore to PostgreSQL import tool with dry-run and roundtrip tests (`e0078ec`)
- Task 11: Performance check (deferred to Plan 16 per standing rules).

## Rulings
- Fastify 5 route handler / inject typing: `fastify.HTTPMethods` includes `'query'`, mismatching `light-my-request`'s `InjectOptions.method`. Test helpers declare `type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'`.
- Task 8 `UserRepository`: implemented `setAvatar` on `HttpUserRepository` by throwing `UnimplementedError` (storage and avatar upload endpoints will be in a future phase; phase 2 slice handles profile metadata).
- Task 8 `AndroidManifest.xml`: combined `usesCleartextTraffic="true"` onto existing debug `<application>` node alongside `networkSecurityConfig`.
- Task 9 `fake_cloud_firestore`: existing version `^4.3.0` resolved cleanly with `yaml: ^3.1.4`, permitting all in-memory Firestore contracts to run without emulator dependency.
- Task 10 `export/`: added to `services/api/.gitignore` to avoid checking in any exported personal data.

## Deferred
- Task 11 performance check moved to Plan 16 (`docs/superpowers/plans/2026-10-02-final-battery-performance.md`).
