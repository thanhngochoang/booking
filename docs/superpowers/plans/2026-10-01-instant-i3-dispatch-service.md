# Instant booking I3: dispatch service (`services/dispatch`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `services/dispatch` serves every operation of `services/dispatch/api/openapi.yaml` for "Chụp ngay": price list per city, request creation with a locked price and an escrowed payment, photographer presence in Redis GEO, a matcher that sends one 30-second offer at a time with no double offers, accept as a single PostgreSQL transaction, live tracking with Goong ETA, arrival, shoot, completion, cancellation with the §4 money table written to the shared ledger, and a Firestore read-only mirror plus FCM pushes so the app needs no polling. Timers are durable BullMQ jobs, so a restart loses nothing. It joins backend phase 2's Docker Compose with a `dispatch` schema and a Redis service, and passes a load test of 2,000 photographers in 3 cities and 100 requests per minute with p95 first offer < 2 s, matcher p95 < 50 ms and zero duplicate offers.

**Architecture:** Same stack and patterns as backend phase 2 (`services/api`): a Fastify 5 server whose routes take method, URL and JSON schemas from the OpenAPI file at boot, Kysely over `pg`, `node-pg-migrate` plain-SQL migrations (own history table `pgmigrations_dispatch`), the same Firebase ID token verifier (copied, drift-tested), the same flat error envelope, Testcontainers. Business rules come only from `packages/dispatch-core` (plan I2) through `src/domain/core.ts`. Everything outside the process is a port with a fake: `PaymentGateway` (fake now, MoMo/VNPay in plan I6), `MirrorWriter` (Firestore via firebase-admin, or memory), `PushSender` (FCM, or recording), `EtaProvider`/`AreaResolver` (Goong with timeout and estimate fallback), `Scheduler` (BullMQ, or a manual scheduler driven by a fake clock in tests). PostgreSQL is the truth (requests, offers, money); Redis holds what may expire (presence, locks, search state, timers, persisted with AOF); Firestore is only the realtime copy the app listens to.

**Tech Stack:** Node 22, TypeScript 5.7, Fastify 5, Kysely 0.27 + `pg` 8, `node-pg-migrate` 7, `jose` 5, `ulidx` 2, `yaml` 2, `openapi-typescript` 7, `esbuild` 0.24, Vitest 2 + Testcontainers 10 (`postgis/postgis:16-3.4-alpine`, `redis:7.4-alpine`) — all as in phase 2 — plus `ioredis` 5, `bullmq` 5, `pino` 9, `firebase-admin` 13 (phase 1's version), `ajv` 8 + `ajv-formats` 3 (contract checks in tests), k6 0.54 (Docker image, as phase 2). Firestore rules tests: `@firebase/rules-unit-testing` in `app_flutter/firebase/rules-test` (existing).

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (all of it: §2 flows, §3 states and rounds, §4 money, §5 architecture and modules, §6 API, §7 data and Firestore rules, §9 location and battery, §10 edge cases, §11 tests); `services/dispatch/api/openapi.yaml` (paths, schemas, enums, error codes, `*Mirror` documents); `docs/superpowers/specs/data-model/README.md` (§2 conventions, §2.9 version and idempotency keys, §3 ports, §4 matrix: `payments`, `ledger_entries` Svc-only); `docs/superpowers/specs/data-model/domain-model.md` (§4 enums, §5 escrow, §6 invariants 11–12); `docs/superpowers/specs/data-model/relational-schema.md` §2.4 (money tables) and §2.8 (dispatch DDL, used verbatim); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b.1 (phone required), §3g (escrow and ledger).

**Prerequisite (all must be done first):**

- `docs/superpowers/plans/2026-10-01-instant-i2-dispatch-core.md`: `packages/dispatch-core` with the barrel `src/index.ts` exporting `DispatchConfig`, `ConfigBook`, `configForCity`, `defaultBook`, `DEFAULT_CONFIG`, `DispatchError`, `DISPATCH_ERROR_CODES`, `isDispatchError`, `transition`, `OPEN_JOB_STATUSES`, `ACTIVE_STATUSES`, `quotePrice`, `parseSurge`, `quoteCancel`, `settleCompleted`, `settleNoMatch`, `graceEndsAt`, `lateDeadline`, `readinessReasons`, `PhotographerFacts`, `rankCandidates`, `OnlineCandidate`, `startSearch`, `nextSearchStep`, `onNobodyLeft`, `searchEndsAt`, `lastOfferAt`, `radiusKm`, `SearchState`, `decideArrival`, `distanceM`, `estimateEta`, `etaFromReasons`, `typicalMatchMinutes`, `systemClock`, `systemRng`, `manualClock`, `seededRng`, `addMs` and the contract enums.
- `docs/superpowers/plans/2026-10-01-backend-phase2-selfhosted-postgres.md`: `services/api` with its migrations (`users`, `files`, `user_contacts`, `photographers`, `photographer_contact_numbers`, `set_updated_at()`), `services/api/src/auth/identity.ts`, `services/api/docker-compose.yml` (`db`, `migrate`, `api`, `k6` profile `perf`), `services/api/test/migrations.test.ts`. The dispatch service reads profiles, phones and photographer stats from those tables, so the app must use the self-hosted backend for profile and contact (phase 2 `SELFHOSTED_REPOS`) or the phase 2 Firestore import must have run.
- `docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md`: the Firestore emulator configuration in `app_flutter/firebase/firebase.json` (used by the rules tests and the mirror suite).

## Key decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Where it runs | `services/dispatch/`, its own `package.json`, image and migration history; joins `services/api/docker-compose.yml` (one PostgreSQL, schema `dispatch`, plus a `redis` service) | Spec §5 "PostgreSQL dùng chung cơ sở dữ liệu của backend giai đoạn 2 (schema `dispatch`)"; one compose for local dev. |
| 2 | Database image | `postgis/postgis:16-3.4-alpine` replaces `postgres:16.4-alpine` in compose and tests | §2.8 needs PostGIS (`geography`, GiST, `ST_Covers`); same PostgreSQL 16 major. |
| 3 | Shared money tables | Created by a new migration in `services/api/migrations` (§2.4 verbatim) unless the payments plan already created them | `payments`/`ledger_entries` are shared by bookings, events and instant requests; they belong to the api's migration history. Dispatch only writes `subject_type = 'instant_request'` rows. |
| 4 | Auth | Copy of `services/api/src/auth/identity.ts` below a marker line, with a test that fails when the two drift | Same verification (Google JWKS / emulator tokens) without coupling the two builds or their `node_modules`. |
| 5 | Error envelope | `{code, message, requestId, details?}`; codes are exactly the contract's `ErrorCode`; HTTP status from one map | Same as phase 2, plus `details` (contract: `not_eligible.reasons`, `price_changed.amountVnd`). |
| 6 | Contract nullability | The contract loader rewrites OpenAPI `nullable` into JSON Schema (`type: [T, "null"]`, `anyOf`) and drops `x-*`, descriptions and unknown formats | Ajv and fast-json-stringify then agree on `allOf + nullable` fields of this contract (a risk phase 2 listed). |
| 7 | Timers | BullMQ delayed jobs on one queue: `match`, `offer-expire`, `search-timeout`, `payment-timeout`, `auto-complete`, `no-show`, `refund`; job id `name-key-dueMs` (no `:`); every handler is idempotent and re-checks PostgreSQL; a boot-time `reconcile` re-adds timers from PostgreSQL | Spec §5, §10 restart rule; duplicates and lost jobs are harmless. |
| 8 | One offer per photographer | `SET offerlock:{uid} <offerId> NX PX 30000` before inserting the offer; released with compare-and-delete | Spec §5 `matcher`; the lock lives exactly as long as the offer. |
| 9 | One matcher per request | `SET matchlock:{requestId} NX PX 10000` around a run, plus "no pending offer for this request" | No two concurrent runs send two offers for one request. |
| 10 | Accept | One transaction: lock the request row, then the offer row (`SELECT … FOR UPDATE`, always in that order), check pending + unexpired by the server clock + `searching`, update, withdraw any other pending offer; the unique index `instant_requests_one_open_job` refuses a second open job | Spec §5 `offers`, §10. |
| 11 | Mirror writes | Full `InstantRequestMirror` rebuilt from PostgreSQL + Redis after each commit, written with an `updatedAt` guard (a slower writer never moves the app back); offer docs deleted only if they still hold that offer | Exact contract documents, no drift between partial updates. |
| 12 | Area of an offer | Goong reverse geocode at request creation (commune, district), else the address minus its first segment | Spec §2.2 "điểm hẹn ở mức khu phố"; no exact address before accept. |
| 13 | Initial ETA (lateness rule) | The accepted offer's `near` reason (`etaMinutes`) | Plan I2 decision 10; DDL verbatim, no new column. |
| 14 | Ledger | capture `deposit_received +amount`; refunds `refund_issued −refund` with a `refunds` row; platform part `fee_charged +platform`; the photographer's part stays `held` with `payee_id` and `release_after` (= +24 h) for the escrow release job of the payments plan / I6 | Spec main §3g, domain-model §5 escrow, invariant 11. |
| 15 | Device tokens and FCM payload | `PushTokenSource` port; first adapter reads Firestore `devices/{uid}_{installId}` as plan I4's app writes them; FCM `offer` data carries every `InstantOfferMirror` field (plan I4 Task 6) | One source of tokens for both apps; S53 opens from the notification alone. The self-hosted `devices` table replaces only the adapter. |
| 16 | Payments in local and tests | `PAYMENTS=fake`: `FakePaymentGateway` with an HMAC-signed webhook, plus `POST /v1/dev/payments/{id}/succeed`; refused in production | Same code path as real providers (webhook → `handlePaymentEvent`). |

## Global Constraints

- Commands run from `services/dispatch/` with Node ≥ 22.11 and a running Docker daemon (Testcontainers starts PostGIS and Redis; `TEST_DATABASE_URL` / `TEST_REDIS_URL` reuse the compose services instead). Rules tests run from `app_flutter/firebase/rules-test` (`npm test`). Before any command, once per shell from the repo root: `source scripts/env.sh >/dev/null && export HOME="$PWD/.home"`.
- **What was verified while writing this plan (Claude Code sandbox, no Docker daemon):** every task's file set was type-checked on its own (`tsc --noEmit` on a staged tree after each task), `npm run build` bundles, the 22 unit tests that need no container pass (config, fake gateway + gateway contract, Goong, FCM), the app boots with the contract and every route registers (contract test with an unreachable database), `FirestoreMirrorWriter` passes its 3 tests on the Firestore emulator, and the Firestore rules tests pass (4 new + the existing ones). The PostgreSQL/Redis suites, k6 and Docker Compose were **not** run here: run them in Tasks 6–16 as written. Sandbox notes for executors: the `tsx` CLI's IPC pipe is refused inside the sandbox (use `node --import tsx`, as the npm scripts do); the Firestore emulator works with `HOME` pointing at a writable folder.
- Wire format: the contract's. JSON keys camelCase, instants ISO-8601 UTC, money integer VND, enums the contract's string codes, request and offer ids ULID (`^[0-9A-HJKMNP-TV-Z]{26}$`), user ids Firebase uids.
- **No business rule in the service:** states, rounds, tiers, scores, prices, fees, arrival distance come from `packages/dispatch-core` through `src/domain/core.ts` only.
- **Clients never write a status, a mirror document or money.** Firestore rules deny every client write to `instant_*`; only this service writes them (Admin SDK).
- **Privacy:** the exact meet point leaves the server only to the assigned photographer (`AcceptResponse`, mirror `meetPoint` from `assigned` on); offers carry the neighbourhood only; the photographer's live position is one overwritten document deleted at arrival or end; no location history is stored; phone numbers never appear in this service's responses, mirror documents or logs; the Goong key is never logged; logs never carry tokens or fix coordinates.
- **Money:** every settlement satisfies `refund + photographer + platform = amount` (dispatch-core), and every ledger write happens in the same transaction as the status change.
- `.env.example` holds test values only; real secrets (Goong key, Firebase credentials, provider keys) come from the environment.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `services/dispatch/api/openapi.yaml` (modify) | Contract fixes (Task 1) |
| `docs/superpowers/specs/data-model/relational-schema.md`, `domain-model.md` (modify) | Schema fixes (Task 1) |
| `services/dispatch/package.json`, `package-lock.json`, `tsconfig.json`, `vitest.config.ts`, `vitest.mirror.config.ts`, `.gitignore`, `.env.example`, `Dockerfile`, `Dockerfile.dockerignore`, `README.md` (create / modify) | Project, image, docs |
| `src/config.ts`, `errors.ts`, `ids.ts`, `metrics.ts`, `deps.ts`, `app.ts`, `wiring.ts`, `server.ts` (create) | Env config, error envelope, ULIDs, timings, ports bundle, app factory, production wiring, process entry |
| `src/domain/core.ts` (create) | The only import point of `packages/dispatch-core` |
| `src/contract/openapi.ts`, `src/generated/api.ts` (create; second is generated) | Contract loader and types |
| `src/auth/identity.ts`, `src/auth/plugin.ts` (create) | Copied Firebase ID token verifier; auth hook |
| `src/db/database.ts`, `migrate.ts`, `migrate-cli.ts`, `migrations/1790899200001_dispatch_schema.sql` (create) | Kysely types, migration runner, §2.8 DDL |
| `services/api/migrations/1790899100001_money_tables.sql`, `services/api/test/migrations.test.ts` (create / modify) | §2.4 money tables |
| `src/redis/client.ts`, `src/redis/keys.ts` (create) | Connections, key names, compare-and-delete |
| `src/payments/gateway.ts`, `fake.ts`, `registry.ts`, `ledger.ts`, `events.ts` (create) | `PaymentGateway` port (for I6), fake, registry, ledger writes, payment events and refunds |
| `src/mirror/mirror.ts`, `src/mirror/firestore.ts` (create) | `MirrorWriter` port, memory and Firestore adapters |
| `src/push/push.ts`, `src/eta/eta.ts`, `src/eta/goong.ts` (create) | FCM sender and token source; ETA and area ports, Goong client |
| `src/jobs/scheduler.ts`, `src/jobs/handlers.ts` (create) | BullMQ and manual schedulers; job handlers and reconcile |
| `src/catalog/catalog.ts`, `src/settings/facts.ts`, `src/settings/settings.ts`, `src/presence/presence.ts` (create) | Cities, prices, typical match; photographer facts and settings; presence |
| `src/requests/rows.ts`, `publish.ts`, `create.ts`, `trip.ts`, `cancel.ts` (create) | Request rows and search/trip state, mirror composition, create, trip steps, cancellation |
| `src/matcher/matcher.ts`, `src/offers/offers.ts` (create) | Matcher runs, no-match; accept, decline, expire |
| `src/routes/*.ts` (create) | HTTP handlers per area |
| `src/tools/seed-dev.ts`, `perf/simulate.ts`, `perf/k6-dispatch.js` (create) | Dev catalog; load-test harness |
| `test/*.test.ts`, `test/payments/*`, `test/helpers.ts`, `test/global-setup.ts`, `test/mirror-schema.ts` (create) | Tests |
| `app_flutter/firebase/firestore.rules`, `rules-test/instant.test.mjs`, `rules-test/package.json` (modify / create) | Rules for `instant_*` |
| `services/api/docker-compose.yml`, `services/api/.env.example` (modify) | PostGIS, Redis, dispatch services |
| `.github/workflows/dispatch.yml` (create) | CI |

---

### Task 1: Contract and schema fixes found while planning

The contract and §2.8 have defects the service cannot work around. Fix them first (documentation only, no code):

| # | Defect | Fix |
|---|---|---|
| 1 | `postLocation` answers 429 but `ErrorCode` has no code for it | add `limit_exceeded` (already in `domain-model.md` §4) |
| 2 | Operations on `{requestId}`/`{offerId}` other than cancel have no 404 for an unknown id | add `'404'` to `confirmComplete`, `postLocation`, `arrive`, `startShoot`, `finishShoot`, `acceptOffer`, `declineOffer` |
| 3 | `arrive` 422 does not say which code and details | document `not_eligible` with `details.reasons` `too_far` / `reason_required` |
| 4 | VNPay sends its IPN as a **GET** with `vnp_*` query parameters and expects `{"RspCode": …}` with HTTP 200; MoMo expects 204; the contract had only a JSON POST with an empty 200 | path-level `provider` parameter, POST with provider-defined 200 body or 204, and a GET operation `paymentWebhookQuery` (plan I6 implements both) |
| 5 | `radiusKm: enum [3, 6, 10]` contradicts per-city configuration (spec §3.2 "để trong cấu hình theo thành phố") | integer 1..50 |
| 6 | Every operation can answer 400 (body breaks the contract) and 401 (no token) but few list them | one sentence in `info.description` |
| 7 | §2.8 DDL references `photographers(id)`; the phase 2 table's key is `photographers(user_id)`: the migration would fail | `references photographers(user_id)` (4 places) |
| 8 | §7 of the spec lists a GiST index on `cities.boundary`, §2.8 does not create it; `POST /v1/requests` looks up "one open request per customer" with no index on `customer_id` | add `cities_boundary` (GiST) and `instant_requests_customer (customer_id, status)` |
| 9 | `payments.provider` allows only `momo`, `vnpay`; the contract's `PaymentProvider` has `fake` | allow `fake` (local and test only; refused by config in production) |
| 10 | `domain-model.md` §4 `PaymentSubject` lacks `instant_request` (the DDL has it); `PaymentProvider` lacks `fake` | add both |

**Files:**
- Modify: `services/dispatch/api/openapi.yaml`, `docs/superpowers/specs/data-model/relational-schema.md`, `docs/superpowers/specs/data-model/domain-model.md`

**Interfaces:**
- Produces: contract operation `paymentWebhookQuery` (`GET /v1/payments/webhook/{provider}`); `ErrorCode` + `limit_exceeded`; §2.8 indexes `cities_boundary`, `instant_requests_customer`.

- [ ] **Step 1: Edit `services/dispatch/api/openapi.yaml`**

In `info.description`, replace the line

```yaml
    - Lỗi luôn có dạng `Error` với `code` lấy từ `ErrorCode` của data-model.
```

with

```yaml
    - Lỗi luôn có dạng `Error` với `code` lấy từ `ErrorCode` của data-model. Ngoài các mã
      liệt kê ở từng thao tác, thao tác nào cũng có thể trả 400 `invalid_argument` (thân hoặc
      tham số sai hợp đồng) và 401 `unauthenticated` (thiếu hoặc sai token, trừ thao tác `security: []`).
```

In each of the operations `confirmComplete`, `postLocation`, `arrive`, `startShoot`, `finishShoot`, `acceptOffer` and `declineOffer`, add directly below their `'403': { $ref: '#/components/responses/Error' }` line:

```yaml
        '404': { $ref: '#/components/responses/Error' }
```

In `arrive`, replace `'422': { $ref: '#/components/responses/Error' }` with:

```yaml
        '422':
          description: 'not_eligible với details {"reasons": ["too_far"], "distanceM": 850} hoặc {"reasons": ["reason_required"]} (force khi GPS kém cần lý do)'
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
```

Replace the whole `/v1/payments/webhook/{provider}:` path item with:

```yaml
  /v1/payments/webhook/{provider}:
    parameters:
      - name: provider
        in: path
        required: true
        schema: { $ref: '#/components/schemas/PaymentProvider' }
    post:
      operationId: paymentWebhook
      summary: Cổng thanh toán báo kết quả (MoMo IPN; kế hoạch I6); xác thực bằng chữ ký của cổng
      description: |
        Thân và mã trả lời theo quy ước của từng cổng (cổng đọc câu trả lời): MoMo chờ 204,
        cổng giả (`fake`, chỉ khi PAYMENTS=fake) ký thân bằng HMAC-SHA256 ở header `x-fake-signature`.
        Idempotent: báo lại cùng giao dịch không đổi gì.
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema: { type: object, additionalProperties: true }
      responses:
        '200':
          description: Đã ghi nhận (thân theo cổng)
          content:
            application/json:
              schema: { type: object, additionalProperties: true }
        '204': { description: Đã ghi nhận (MoMo) }
        '400': { $ref: '#/components/responses/Error' }
        '401': { $ref: '#/components/responses/Error' }
    get:
      operationId: paymentWebhookQuery
      summary: Cổng báo kết quả qua query string (VNPay IPN gọi bằng GET; kế hoạch I6)
      description: |
        VNPay gửi IPN bằng GET với tham số `vnp_*` và chờ thân JSON `{"RspCode": "00", "Message": "..."}`
        với HTTP 200 kể cả khi từ chối (mã lỗi nằm trong `RspCode`).
      security: []
      responses:
        '200':
          description: Câu trả lời theo cổng
          content:
            application/json:
              schema: { type: object, additionalProperties: true }
        '400': { $ref: '#/components/responses/Error' }
```

In `components.schemas.ErrorCode`, replace the enum's last line `             unauthenticated, internal]` with:

```yaml
             limit_exceeded, unauthenticated, internal]
      description: 'limit_exceeded: quá tần suất cho phép (postLocation: 1 lần / 5 giây), HTTP 429'
```

In `InstantRequestMirror`, replace `radiusKm: { type: integer, enum: [3, 6, 10], description: Bán kính đang tìm (S48) }` with:

```yaml
        radiusKm:
          type: integer
          minimum: 1
          maximum: 50
          description: Bán kính đang tìm (S48); v1 là 3, 6 hoặc 10 nhưng mỗi thành phố cấu hình được (spec §3.2)
```

- [ ] **Step 2: Edit `relational-schema.md`**

In §2.8 replace every `references photographers(id)` with `references photographers(user_id)` (4 lines: `instant_requests.photographer_id`, `instant_offers.photographer_id`, `photographer_instant_settings.photographer_id`, `photographer_reliability.photographer_id`).

Directly after the `create table dispatch.cities (…);` statement add:

```sql
create index cities_boundary on dispatch.cities using gist (boundary);
```

Directly after `create index instant_requests_status_city on dispatch.instant_requests (status, city_id);` add:

```sql
create index instant_requests_customer on dispatch.instant_requests (customer_id, status);
```

In §2.4 `payments`, replace `  provider        text not null check (provider in ('momo','vnpay')),` with:

```sql
  provider        text not null check (provider in ('momo','vnpay','fake')),   -- fake: chỉ local/test (PAYMENTS=fake)
```

- [ ] **Step 3: Edit `domain-model.md` §4**

Replace the rows

```
| `PaymentSubject` | `booking`, `event_registration` | |
| `PaymentProvider` | `momo`, `vnpay` | |
```

with

```
| `PaymentSubject` | `booking`, `event_registration`, `instant_request` | `instant_request`: Chụp ngay (`dispatch.instant_requests`) |
| `PaymentProvider` | `momo`, `vnpay`, `fake` | `fake` chỉ ở môi trường local/test (`PAYMENTS=fake`), máy chủ từ chối khi `NODE_ENV=production` |
```

- [ ] **Step 4: Check the edits**

Run (repo root):

```bash
grep -c "operationId:" services/dispatch/api/openapi.yaml
grep -c "'404': { \$ref" services/dispatch/api/openapi.yaml
grep -c "photographers(id)" docs/superpowers/specs/data-model/relational-schema.md
grep -n "limit_exceeded, unauthenticated" services/dispatch/api/openapi.yaml
```

Expected: `17`, `8`, `0`, one line. (Task 2's contract loader parses the file; Task 6's contract test checks every operation is routed.)

- [ ] **Step 5: Commit**

```bash
git add services/dispatch/api/openapi.yaml docs/superpowers/specs/data-model
git commit -m "docs(dispatch): contract and schema fixes (limit_exceeded, 404s, VNPay GET IPN, radius range, photographers FK, indexes, fake provider)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Scaffold `services/dispatch`: config, errors, ids, contract loader, test containers

**Files:**
- Create: `services/dispatch/package.json`, `services/dispatch/tsconfig.json`, `services/dispatch/vitest.config.ts`, `services/dispatch/.gitignore`, `services/dispatch/.env.example`, `services/dispatch/src/config.ts`, `services/dispatch/src/errors.ts`, `services/dispatch/src/ids.ts`, `services/dispatch/src/domain/core.ts`, `services/dispatch/src/contract/openapi.ts`, `services/dispatch/src/generated/api.ts` (generated), `services/dispatch/src/db/migrate.ts`, `services/dispatch/src/db/migrate-cli.ts`, `services/dispatch/test/global-setup.ts`, `services/dispatch/test/config.test.ts`

**Interfaces:**
- Consumes: `configForCity`, `defaultBook`, `ConfigBook`, `DeepPartial`, `DispatchConfig`, `DISPATCH_ERROR_CODES`, `isDispatchError` (plan I2).
- Produces:
  - `type AuthMode`, `PaymentsMode = 'fake' | 'live'`, `MirrorMode = 'firestore' | 'memory'`, `PushMode = 'fcm' | 'log'`, `Role = 'all' | 'api' | 'worker'`; `interface ServiceConfig { port; host; databaseUrl; redisUrl; dbPoolMax; authMode; firebaseProjectId; logLevel; nodeEnv; role; payments; fakePaymentSecret; mirror; push; goongApiKey: string | null; goongTimeoutMs; metricsEndpoint; book: ConfigBook }`; `loadConfig(env?): ServiceConfig` (refuses emulator auth, fake payments, memory mirror and the metrics endpoint in production); `loadBook(path?): ConfigBook` (`DISPATCH_CONFIG_PATH` JSON `{base, cities}`, validated).
  - `type ApiErrorCode`, `API_ERROR_CODES`, `HTTP_STATUS: Record<ApiErrorCode, number>`, `class ApiError(code, message?, details?)`, `installErrorHandling(app)`; envelope `{ code, message, requestId, details? }`; `DispatchError` from the domain maps the same way.
  - `newId(now?): string` (ULID), `ULID_PATTERN`, `ID_PATTERN`, `isValidId(v)`.
  - `loadContract(path?)`, `toFastifySchema(node)`, `registerContractSchemas(app, contract)`, `operations(contract)`, `operation(contract, operationId): { method; url; schema; bodyRequired }`, `route(contract, operationId)` (route options; an optional body defaults to `{}`), `toFastifyUrl(path)`.
  - `migrate(databaseUrl, direction, opts?)` (history table `pgmigrations_dispatch`), `migrateAll(databaseUrl)` (api migrations, then dispatch), `API_MIGRATIONS_DIR`, `DEFAULT_MIGRATIONS_DIR`; CLI `node dist/db/migrate-cli.js up|down [n|all]`.

HTTP status of each code (clients branch on `code` only):

| Code | Status | | Code | Status |
|---|---|---|---|---|
| `invalid_argument` | 400 | | `price_changed`, `no_match` | 409 |
| `unauthenticated` | 401 | | `phone_required`, `not_eligible`, `outside_service_area` | 422 |
| `permission_denied`, `contact_locked` | 403 | | `limit_exceeded` | 429 |
| `not_found` | 404 | | `internal` | 500 |
| `conflict`, `already_assigned`, `offer_expired` | 409 | | | |

- [ ] **Step 1: Create the project files and install**

```json
// services/dispatch/package.json
{
  "name": "@nag/dispatch",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22.11.0"
  },
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "esbuild src/server.ts src/db/migrate-cli.ts --bundle --platform=node --target=node22 --format=esm --packages=external --sourcemap --outdir=dist",
    "start": "node dist/server.js",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "gen:types": "openapi-typescript api/openapi.yaml -o src/generated/api.ts",
    "migrate": "node --import tsx src/db/migrate-cli.ts"
  },
  "dependencies": {
    "bullmq": "^5.34.0",
    "fastify": "^5.1.0",
    "firebase-admin": "^13.10.0",
    "ioredis": "^5.4.1",
    "jose": "^5.9.6",
    "kysely": "^0.27.5",
    "node-pg-migrate": "^7.8.0",
    "pg": "^8.13.1",
    "pino": "^9.5.0",
    "ulidx": "^2.4.1",
    "yaml": "^2.6.1"
  },
  "devDependencies": {
    "@testcontainers/postgresql": "^10.16.0",
    "@testcontainers/redis": "^10.16.0",
    "@types/node": "^22.10.1",
    "@types/pg": "^8.11.10",
    "ajv": "^8.17.1",
    "ajv-formats": "^3.0.1",
    "esbuild": "^0.24.0",
    "openapi-typescript": "^7.4.4",
    "tsx": "^4.19.2",
    "typescript": "^5.7.2",
    "vitest": "^2.1.8"
  }
}
```

(JSON has no comments: the first line above only names the file; do not write it into the file. Later tasks add the scripts `test:mirror` (Task 4), `seed:dev` (Task 8) and `simulate` (Task 16).)

```json
// services/dispatch/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2023", "DOM"],
    "types": ["node"],
    "strict": true,
    "noEmit": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src", "test", "perf/simulate.ts", "vitest.config.ts", "vitest.mirror.config.ts"]
}
```

(JSON has no comments: the first line above only names the file; do not write it into the file.)

```ts
// services/dispatch/vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globalSetup: ['./test/global-setup.ts'],
    include: ['test/**/*.test.ts'],
    // Test files share one database and one Redis and reset them: run them one at a time.
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 180_000,
  },
});
```

```gitignore
# services/dispatch/.gitignore
node_modules/
dist/
coverage/
.env
```

```bash
# services/dispatch/.env.example
# Copy to services/dispatch/.env (gitignored) for host-side runs (npm run dev / migrate / simulate).
# Test values only: never put real secrets here. docker compose (services/api/docker-compose.yml)
# sets the container values itself.
DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag
REDIS_URL=redis://localhost:6380
PORT=8090
NODE_ENV=development
LOG_LEVEL=info
ROLE=all
AUTH_MODE=firebase-emulator
FIREBASE_PROJECT_ID=demo-nag
# fake: built-in fake gateway + POST /v1/dev/payments/{id}/succeed (refused in production).
# live: real providers (plan I6).
PAYMENTS=fake
FAKE_PAYMENT_SECRET=fake-secret-for-local-dev-only
# memory: mirror kept in process (app cannot see it). firestore: needs FIRESTORE_EMULATOR_HOST or credentials.
MIRROR=memory
# FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
PUSH=log
# Leave empty to use the straight-line ETA estimate. Never commit a real key.
GOONG_API_KEY=
GOONG_TIMEOUT_MS=1500
METRICS_ENDPOINT=true
# Optional per-city overrides of the dispatch tunables (JSON {base, cities}).
# DISPATCH_CONFIG_PATH=./dispatch-config.json
```

Then install to create the lock file:

```bash
cd services/dispatch && npm install
```

Expected: `added N packages`, `package-lock.json` created, no `ERR!` lines.

- [ ] **Step 2: Write the failing test**

```ts
// services/dispatch/test/config.test.ts
import { writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';
import { configForCity } from '../src/domain/core.js';

const base = { DATABASE_URL: 'postgres://x@localhost/x', REDIS_URL: 'redis://localhost:6379', FIREBASE_PROJECT_ID: 'demo-nag' };

describe('loadConfig', () => {
  it('has safe defaults: firebase auth, live payments, Firestore mirror, FCM, port 8090', () => {
    const c = loadConfig({ ...base });
    expect(c).toMatchObject({ authMode: 'firebase', payments: 'live', mirror: 'firestore', push: 'fcm', port: 8090, role: 'all', goongApiKey: null, metricsEndpoint: false });
  });

  it('refuses test-only modes in production', () => {
    expect(() => loadConfig({ ...base, AUTH_MODE: 'firebase-emulator' })).toThrow(/refused/);
    expect(() => loadConfig({ ...base, PAYMENTS: 'fake', FAKE_PAYMENT_SECRET: 'x'.repeat(16) })).toThrow(/refused/);
    expect(() => loadConfig({ ...base, MIRROR: 'memory' })).toThrow(/refused/);
    expect(() => loadConfig({ ...base, METRICS_ENDPOINT: 'true' })).toThrow(/refused/);
  });

  it('PAYMENTS=fake needs a secret', () => {
    expect(() => loadConfig({ ...base, NODE_ENV: 'development', PAYMENTS: 'fake' })).toThrow(/FAKE_PAYMENT_SECRET/);
    expect(loadConfig({ ...base, NODE_ENV: 'development', PAYMENTS: 'fake', FAKE_PAYMENT_SECRET: 's'.repeat(16) }).payments).toBe('fake');
  });

  it('reads per-city overrides from DISPATCH_CONFIG_PATH and validates them', () => {
    const path = join(tmpdir(), `dispatch-config-${Date.now()}.json`);
    writeFileSync(path, JSON.stringify({ base: { offerTtlMs: 25_000 }, cities: { hcm: { pricing: { payoutRateBps: 7_500 } } } }));
    const c = loadConfig({ ...base, DISPATCH_CONFIG_PATH: path });
    expect(configForCity(c.book, 'hcm')).toMatchObject({ offerTtlMs: 25_000, pricing: { payoutRateBps: 7_500 } });
    expect(configForCity(c.book, 'hn').pricing.payoutRateBps).toBe(8_000);
    writeFileSync(path, JSON.stringify({ cities: { hcm: { scoring: { weights: { eta: 0.9 } } } } }));
    expect(() => loadConfig({ ...base, DISPATCH_CONFIG_PATH: path })).toThrow(/sum to 1/);
  });

  it('keeps the Goong key out of everything but the config object', () => {
    const c = loadConfig({ ...base, GOONG_API_KEY: ' goong-secret ' });
    expect(c.goongApiKey).toBe('goong-secret');
  });
});
```

```ts
// services/dispatch/test/global-setup.ts
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { RedisContainer, type StartedRedisContainer } from '@testcontainers/redis';


let pg: StartedPostgreSqlContainer | undefined;
let redis: StartedRedisContainer | undefined;

/**
 * Real PostgreSQL + PostGIS and Redis (spec §11). TEST_DATABASE_URL / TEST_REDIS_URL reuse the
 * compose services instead (database name must end in _test; Redis DB 15 is used and flushed).
 */
export async function setup(): Promise<void> {
  if (process.env.TEST_DATABASE_URL) {
    if (!new URL(process.env.TEST_DATABASE_URL).pathname.endsWith('_test')) {
      throw new Error('TEST_DATABASE_URL must name a database ending in _test (tests truncate tables)');
    }
  } else {
    pg = await new PostgreSqlContainer('postgis/postgis:16-3.4-alpine')
      .withDatabase('nag_test')
      .withUsername('nag')
      .withPassword('nag_test_only')
      .start();
    process.env.TEST_DATABASE_URL = pg.getConnectionUri();
  }
  if (!process.env.TEST_REDIS_URL) {
    redis = await new RedisContainer('redis:7.4-alpine').start();
    process.env.TEST_REDIS_URL = `${redis.getConnectionUrl()}/15`;
  }
}

export async function teardown(): Promise<void> {
  await redis?.stop();
  await pg?.stop();
}
```

- [ ] **Step 3: Run and see it fail**

Run: `npm test`
Expected: FAIL, `Failed to load url ../src/config.js` (and `../src/domain/core.js`).

- [ ] **Step 4: Implement**

```ts
// services/dispatch/src/domain/core.ts
/**
 * The only file in services/dispatch that knows where the pure dispatch domain lives
 * (packages/dispatch-core, plan I2). Rules are imported, never copied.
 */
export * from '../../../../packages/dispatch-core/src/index.js';
```

```ts
// services/dispatch/src/config.ts
import { readFileSync } from 'node:fs';

import { configForCity, defaultBook, type ConfigBook, type DeepPartial, type DispatchConfig } from './domain/core.js';

export type AuthMode = 'firebase' | 'firebase-emulator';
export type PaymentsMode = 'fake' | 'live';
export type MirrorMode = 'firestore' | 'memory';
export type PushMode = 'fcm' | 'log';
export type Role = 'all' | 'api' | 'worker';

export interface ServiceConfig {
  port: number;
  host: string;
  databaseUrl: string;
  redisUrl: string;
  dbPoolMax: number;
  authMode: AuthMode;
  firebaseProjectId: string;
  logLevel: string;
  nodeEnv: string;
  role: Role;
  payments: PaymentsMode;
  /** HMAC key of the fake gateway's webhook (PAYMENTS=fake only). */
  fakePaymentSecret: string;
  mirror: MirrorMode;
  push: PushMode;
  /** Goong Distance Matrix / Geocode key; null → estimate only. Never logged. */
  goongApiKey: string | null;
  goongTimeoutMs: number;
  /** Exposes GET /internal/metrics (matcher timings) for the load test. */
  metricsEndpoint: boolean;
  /** Base values + per-city overrides of every dispatch tunable (plan I2 DispatchConfig). */
  book: ConfigBook;
}

function required(env: NodeJS.ProcessEnv, key: string): string {
  const v = env[key];
  if (v === undefined || v.trim() === '') throw new Error(`${key} is required`);
  return v.trim();
}

function int(env: NodeJS.ProcessEnv, key: string, fallback: number, min: number, max: number): number {
  const raw = env[key];
  const n = raw === undefined || raw === '' ? fallback : Number(raw);
  if (!Number.isInteger(n) || n < min || n > max) throw new Error(`${key} must be an integer between ${min} and ${max}`);
  return n;
}

function oneOf<T extends string>(env: NodeJS.ProcessEnv, key: string, allowed: readonly T[], fallback: T): T {
  const v = (env[key] ?? fallback) as T;
  if (!allowed.includes(v)) throw new Error(`${key} must be one of ${allowed.join(', ')}`);
  return v;
}

/** DISPATCH_CONFIG_PATH: JSON `{ "base": {…partial…}, "cities": { "<cityId>": {…partial…} } }`. */
export function loadBook(path: string | undefined): ConfigBook {
  if (!path) return defaultBook();
  const parsed = JSON.parse(readFileSync(path, 'utf8')) as {
    base?: DeepPartial<DispatchConfig>;
    cities?: Record<string, DeepPartial<DispatchConfig>>;
  };
  const withBase = defaultBook({ __base__: parsed.base ?? {} });
  const base = configForCity(withBase, '__base__');
  const book: ConfigBook = { base, cities: parsed.cities ?? {} };
  for (const city of Object.keys(book.cities)) configForCity(book, city); // validate every city now
  return book;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): ServiceConfig {
  const nodeEnv = env.NODE_ENV ?? 'production';
  const prod = nodeEnv === 'production';
  const authMode = oneOf<AuthMode>(env, 'AUTH_MODE', ['firebase', 'firebase-emulator'], 'firebase');
  if (authMode === 'firebase-emulator' && prod) {
    throw new Error('AUTH_MODE=firebase-emulator accepts unsigned tokens and is refused when NODE_ENV=production');
  }
  const payments = oneOf<PaymentsMode>(env, 'PAYMENTS', ['fake', 'live'], 'live');
  if (payments === 'fake' && prod) throw new Error('PAYMENTS=fake is refused when NODE_ENV=production');
  const mirror = oneOf<MirrorMode>(env, 'MIRROR', ['firestore', 'memory'], 'firestore');
  if (mirror === 'memory' && prod) throw new Error('MIRROR=memory is refused when NODE_ENV=production');
  const metricsEndpoint = env.METRICS_ENDPOINT === 'true';
  if (metricsEndpoint && prod) throw new Error('METRICS_ENDPOINT=true is refused when NODE_ENV=production');
  const goong = env.GOONG_API_KEY?.trim();
  return {
    port: int(env, 'PORT', 8090, 1, 65_535),
    host: env.HOST ?? '0.0.0.0',
    databaseUrl: required(env, 'DATABASE_URL'),
    redisUrl: required(env, 'REDIS_URL'),
    dbPoolMax: int(env, 'DB_POOL_MAX', 10, 1, 50),
    authMode,
    firebaseProjectId: required(env, 'FIREBASE_PROJECT_ID'),
    logLevel: env.LOG_LEVEL ?? 'info',
    nodeEnv,
    role: oneOf<Role>(env, 'ROLE', ['all', 'api', 'worker'], 'all'),
    payments,
    fakePaymentSecret: payments === 'fake' ? required(env, 'FAKE_PAYMENT_SECRET') : '',
    mirror,
    push: oneOf<PushMode>(env, 'PUSH', ['fcm', 'log'], 'fcm'),
    goongApiKey: goong ? goong : null,
    goongTimeoutMs: int(env, 'GOONG_TIMEOUT_MS', 1_500, 100, 10_000),
    metricsEndpoint,
    book: loadBook(env.DISPATCH_CONFIG_PATH),
  };
}
```

```ts
// services/dispatch/src/errors.ts
import type { FastifyError, FastifyInstance } from 'fastify';

import { DISPATCH_ERROR_CODES, isDispatchError, type DispatchErrorCode } from './domain/core.js';

/** HTTP-only codes (same two as services/api). */
export const TRANSPORT_CODES = ['unauthenticated', 'internal'] as const;
export type ApiErrorCode = DispatchErrorCode | (typeof TRANSPORT_CODES)[number];
export const API_ERROR_CODES: readonly ApiErrorCode[] = [...DISPATCH_ERROR_CODES, ...TRANSPORT_CODES];

/** Clients branch on `code`; the status only follows the contract's response list. */
export const HTTP_STATUS: Record<ApiErrorCode, number> = {
  invalid_argument: 400,
  unauthenticated: 401,
  permission_denied: 403,
  contact_locked: 403,
  not_found: 404,
  conflict: 409,
  already_assigned: 409,
  offer_expired: 409,
  price_changed: 409,
  no_match: 409,
  phone_required: 422,
  not_eligible: 422,
  outside_service_area: 422,
  limit_exceeded: 429,
  internal: 500,
};

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    message: string = code,
    readonly details?: Readonly<Record<string, unknown>>,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  get status(): number {
    return HTTP_STATUS[this.code];
  }
}

export interface ErrorBody {
  code: ApiErrorCode;
  message: string;
  requestId: string;
  details?: Readonly<Record<string, unknown>>;
}

const body = (code: ApiErrorCode, message: string, requestId: string, details?: Readonly<Record<string, unknown>>): ErrorBody =>
  details === undefined ? { code, message, requestId } : { code, message, requestId, details };

/** Any error carrying one of our codes (ApiError, DispatchError, or the copied auth verifier's error). */
function coded(err: unknown): { code: ApiErrorCode; message: string; details?: Readonly<Record<string, unknown>> } | null {
  if (err instanceof ApiError) return { code: err.code, message: err.message, details: err.details };
  if (isDispatchError(err)) return { code: err.code, message: err.code, details: err.details };
  return null;
}

export function installErrorHandling(app: FastifyInstance): void {
  app.setErrorHandler((err: FastifyError, req, reply) => {
    const c = coded(err);
    if (c) return reply.status(HTTP_STATUS[c.code]).send(body(c.code, c.message, req.id, c.details));
    if (err.validation) {
      return reply.status(400).send(body('invalid_argument', 'request does not match the API contract', req.id));
    }
    if (typeof err.statusCode === 'number' && err.statusCode >= 400 && err.statusCode < 500) {
      return reply.status(err.statusCode).send(body('invalid_argument', 'malformed request', req.id));
    }
    // Never echo the original message: it may carry SQL, coordinates or a provider key.
    req.log.error({ err: { name: err.name, code: (err as { code?: unknown }).code } }, 'unhandled error');
    return reply.status(500).send(body('internal', 'internal error', req.id));
  });
  app.setNotFoundHandler((req, reply) => reply.status(404).send(body('not_found', 'no such route', req.id)));
}
```

```ts
// services/dispatch/src/ids.ts
import { monotonicFactory } from 'ulidx';

const nextUlid = monotonicFactory();

/** Contract `Id`: ULID, Crockford base32. */
export const ULID_PATTERN = /^[0-9A-HJKMNP-TV-Z]{26}$/;
/** data-model README §2.1: Firebase uids and other ids, 1–64 chars of [A-Za-z0-9_-]. */
export const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

export function newId(now: number = Date.now()): string {
  return nextUlid(now);
}

export function isValidId(v: unknown): v is string {
  return typeof v === 'string' && ID_PATTERN.test(v);
}
```

```ts
// services/dispatch/src/contract/openapi.ts
// Same approach as services/api/src/contract/openapi.ts (phase 2 Task 3): routes take method, URL and
// JSON schemas from the contract at boot. Two additions for this contract: OpenAPI 3.0 `nullable` is
// rewritten to JSON Schema (`type: [T, 'null']` / `anyOf`) so Ajv and fast-json-stringify agree, and
// non-JSON-Schema keys (`x-*`, `description`, `example`, unknown `format`s) are dropped.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import type { FastifyInstance, FastifySchema, HTTPMethods } from 'fastify';
import { parse } from 'yaml';

export type Json = null | boolean | number | string | Json[] | { [k: string]: Json };
type Ref = { $ref: string };

interface Parameter {
  name: string;
  in: 'path' | 'query' | 'header';
  required?: boolean;
  schema: Json;
}

interface Operation {
  operationId: string;
  parameters?: Array<Parameter | Ref>;
  requestBody?: { required?: boolean; content?: Record<string, { schema: Json }> };
  responses: Record<string, { content?: Record<string, { schema: Json }> } | Ref>;
}

const METHODS = ['get', 'post', 'put', 'patch', 'delete'] as const;
type PathItem = { parameters?: Array<Parameter | Ref> } & Partial<Record<(typeof METHODS)[number], Operation>>;

export interface Contract {
  paths: Record<string, PathItem>;
  components: { schemas: Record<string, Json>; parameters?: Record<string, Parameter> };
}

export interface ContractOperation {
  operationId: string;
  method: HTTPMethods;
  path: string;
  url: string;
}

export const DEFAULT_CONTRACT_PATH = fileURLToPath(new URL('../../api/openapi.yaml', import.meta.url));

export function loadContract(path: string = process.env.CONTRACT_PATH ?? DEFAULT_CONTRACT_PATH): Contract {
  return parse(readFileSync(path, 'utf8')) as Contract;
}

export const toFastifyUrl = (path: string): string => path.replace(/\{(\w+)\}/g, ':$1');

const DROP = new Set(['example', 'description', 'summary', 'x-firestore-path']);
const KEEP_FORMATS = new Set(['date-time', 'uri', 'email']);

/** OpenAPI 3.0 schema → JSON Schema for Fastify (refs become shared-schema ids `Name#`). */
export function toFastifySchema(node: Json): Json {
  if (Array.isArray(node)) return node.map(toFastifySchema);
  if (node === null || typeof node !== 'object') return node;
  const out: { [k: string]: Json } = {};
  for (const [k, v] of Object.entries(node)) {
    if (DROP.has(k) || k.startsWith('x-') || k === 'nullable') continue;
    if (k === 'format' && typeof v === 'string' && !KEEP_FORMATS.has(v)) continue;
    if (k === '$ref' && typeof v === 'string') {
      out.$ref = `${v.replace('#/components/schemas/', '')}#`;
      continue;
    }
    out[k] = toFastifySchema(v);
  }
  if (node.nullable !== true) return out;
  if (typeof out.type === 'string' && out.allOf === undefined && out.$ref === undefined) {
    const nullable: { [k: string]: Json } = { ...out, type: [out.type, 'null'] };
    if (Array.isArray(out.enum)) nullable.enum = [...out.enum, null];
    return nullable;
  }
  return { anyOf: [out, { type: 'null' }] };
}

export function registerContractSchemas(app: FastifyInstance, contract: Contract): void {
  for (const [name, schema] of Object.entries(contract.components.schemas)) {
    app.addSchema({ $id: name, ...(toFastifySchema(schema) as Record<string, Json>) });
  }
}

function resolveParameter(contract: Contract, p: Parameter | Ref): Parameter {
  if (!('$ref' in p)) return p;
  const name = p.$ref.replace('#/components/parameters/', '');
  const found = contract.components.parameters?.[name];
  if (!found) throw new Error(`unknown parameter ${p.$ref}`);
  return found;
}

export function operations(contract: Contract): ContractOperation[] {
  const out: ContractOperation[] = [];
  for (const [path, item] of Object.entries(contract.paths)) {
    for (const m of METHODS) {
      const op = item[m];
      if (op) out.push({ operationId: op.operationId, method: m.toUpperCase() as HTTPMethods, path, url: toFastifyUrl(path) });
    }
  }
  return out;
}

export interface RouteOptions {
  method: HTTPMethods;
  url: string;
  schema: FastifySchema;
  /** false: the body may be absent (`requestBody.required` not true); the route defaults it to {}. */
  bodyRequired: boolean;
}

export function operation(contract: Contract, operationId: string): RouteOptions {
  for (const [path, item] of Object.entries(contract.paths)) {
    for (const m of METHODS) {
      const op = item[m];
      if (!op || op.operationId !== operationId) continue;
      const schema: FastifySchema = {};
      const params = [...(item.parameters ?? []), ...(op.parameters ?? [])].map((p) => resolveParameter(contract, p));
      const pathParams = params.filter((p) => p.in === 'path');
      if (pathParams.length > 0) {
        schema.params = {
          type: 'object',
          additionalProperties: false,
          required: pathParams.map((p) => p.name),
          properties: Object.fromEntries(pathParams.map((p) => [p.name, toFastifySchema(p.schema)])),
        };
      }
      const query = params.filter((p) => p.in === 'query');
      if (query.length > 0) {
        schema.querystring = {
          type: 'object',
          additionalProperties: false,
          required: query.filter((p) => p.required === true).map((p) => p.name),
          properties: Object.fromEntries(query.map((p) => [p.name, toFastifySchema(p.schema)])),
        };
      }
      const bodySchema = op.requestBody?.content?.['application/json']?.schema;
      if (bodySchema) schema.body = toFastifySchema(bodySchema);
      const response: Record<string, Json> = {};
      for (const [status, r] of Object.entries(op.responses)) {
        if (!status.startsWith('2') || '$ref' in r) continue;
        const s = r.content?.['application/json']?.schema;
        if (s) response[status] = toFastifySchema(s);
      }
      if (Object.keys(response).length > 0) schema.response = response;
      return {
        method: m.toUpperCase() as HTTPMethods,
        url: toFastifyUrl(path),
        schema,
        bodyRequired: op.requestBody?.required === true,
      };
    }
  }
  throw new Error(`operation ${operationId} is not in the API contract`);
}

/** Fastify route options of an operation; an optional body defaults to {} before validation. */
export function route(contract: Contract, operationId: string) {
  const { bodyRequired, ...opts } = operation(contract, operationId);
  if (bodyRequired || opts.schema.body === undefined) return opts;
  return {
    ...opts,
    preValidation: async (req: { body: unknown }) => {
      if (req.body === undefined || req.body === null) req.body = {};
    },
  };
}
```

```ts
// services/dispatch/src/db/migrate.ts
import { fileURLToPath } from 'node:url';

import { runner } from 'node-pg-migrate';

/** services/dispatch/migrations from source; the image sets MIGRATIONS_DIR. */
export const DEFAULT_MIGRATIONS_DIR = fileURLToPath(new URL('../../migrations', import.meta.url));
/** services/api/migrations (phase 2 tables + the shared money tables); used by tests and the dev tools. */
export const API_MIGRATIONS_DIR = fileURLToPath(new URL('../../../api/migrations', import.meta.url));

/**
 * Dispatch keeps its own migration history (`pgmigrations_dispatch`) next to services/api's
 * (`pgmigrations`), so each service migrates independently in the same database. Dispatch
 * migrations need the api ones first (FKs to users and photographers).
 */
export function migrate(
  databaseUrl: string,
  direction: 'up' | 'down',
  opts: { count?: number; dir?: string; table?: string; log?: (msg: string) => void } = {},
): Promise<unknown> {
  return runner({
    databaseUrl,
    dir: opts.dir ?? process.env.MIGRATIONS_DIR ?? DEFAULT_MIGRATIONS_DIR,
    direction,
    count: opts.count ?? (direction === 'up' ? Infinity : 1),
    migrationsTable: opts.table ?? 'pgmigrations_dispatch',
    checkOrder: true,
    singleTransaction: true,
    log: opts.log ?? (() => {}),
  });
}

/** api migrations then dispatch migrations (test setup and local tools). */
export async function migrateAll(databaseUrl: string): Promise<void> {
  await migrate(databaseUrl, 'up', { dir: API_MIGRATIONS_DIR, table: 'pgmigrations' });
  await migrate(databaseUrl, 'up');
}
```

```ts
// services/dispatch/src/db/migrate-cli.ts
import { migrate } from './migrate.js';

const [direction, countArg] = process.argv.slice(2);
if (direction !== 'up' && direction !== 'down') {
  console.error('usage: migrate-cli up|down [n|all]');
  process.exit(2);
}
const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is required');
  process.exit(2);
}
const count = countArg === 'all' ? Infinity : countArg ? Number(countArg) : undefined;
await migrate(url, direction, { count, log: (m) => console.log(m) });
console.log(`dispatch migrations ${direction}: done`);
```

Generate the contract types (commit the output; never edit it by hand):

```bash
npm run gen:types
```

Expected: `🚀 api/openapi.yaml → src/generated/api.ts`; the file declares `components['schemas']['InstantRequestMirror']` with `radiusKm?: number` and `ErrorCode` including `"limit_exceeded"`.

- [ ] **Step 5: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean (it also type-checks `packages/dispatch-core` through the shim); `Test Files  1 passed (1)`, `Tests  5 passed (5)`. The global setup starts `postgis/postgis:16-3.4-alpine` and `redis:7.4-alpine` once (first run pulls the images).

- [ ] **Step 6: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): scaffold dispatch service with config, error envelope, ULIDs, contract loader and test containers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `PaymentGateway` port (the interface plan I6 implements), fake gateway, registry

This task defines the payment port precisely so plan I6 (real MoMo/VNPay) only adds two classes and registers them in `buildGateways`; nothing else in the service changes.

**Files:**
- Create: `services/dispatch/src/payments/gateway.ts`, `services/dispatch/src/payments/fake.ts`, `services/dispatch/src/payments/registry.ts`, `services/dispatch/test/payments/gateway-contract.ts`, `services/dispatch/test/payments/fake-gateway.test.ts`

**Interfaces:**
- Consumes: `PaymentProvider` (plan I2), `ServiceConfig` (Task 2).
- Produces (exact; I6 depends on these names and shapes):

```ts
export interface CreatePaymentInput {
  paymentId: string;            // payments.id (ULID) = the provider's order id
  idempotencyKey: string;       // payments.idempotency_key = `instant:<requestId>`
  subject: { type: 'instant_request'; id: string };
  amountVnd: number;            // integer VND > 0
  description: string;          // Vietnamese, ≤ 200 chars
  returnUrl: string;            // app deep link `photobooking://instant/<requestId>`; never proof of payment
  expiresAt: Date;              // created + 15 min (PAYMENT_WINDOW_MS)
}
export interface CreatePaymentResult { paymentUrl: string; providerRef: string | null; raw: Record<string, unknown> }
export interface WebhookRequest {
  provider: PaymentProvider; method: 'GET' | 'POST';
  headers: Readonly<Record<string, string | undefined>>;   // lower-cased names
  query: Readonly<Record<string, string>>;                 // VNPay IPN parameters
  rawBody: string;                                         // exact body ('' for GET); verify signatures over this
}
export type PaymentEvent =
  | { kind: 'paid'; paymentId: string; providerRef: string; amountVnd: number; raw: Record<string, unknown> }
  | { kind: 'failed'; paymentId: string; providerRef: string | null; reason: string; raw: Record<string, unknown> };
export type WebhookVerification = { ok: true; event: PaymentEvent } | { ok: false; reason: 'invalid_signature' | 'malformed' };
export type WebhookOutcome = 'processed' | 'duplicate' | 'unknown_payment' | 'amount_mismatch' | 'invalid_signature' | 'malformed' | 'error';
export interface WebhookAck { status: number; headers?: Readonly<Record<string, string>>; body: unknown /* null = empty body */ }
export interface RefundInput {
  refundId: string;             // refunds.id (ULID) = the provider's refund request id
  idempotencyKey: string;       // `instant:<requestId>:refund`
  paymentId: string; providerRef: string | null;
  amountVnd: number;            // > 0, ≤ paymentAmountVnd
  paymentAmountVnd: number; reason: string;
}
export type RefundResult =
  | { status: 'done'; providerRef: string | null; raw: Record<string, unknown> }
  | { status: 'pending'; providerRef: string | null; raw: Record<string, unknown> }
  | { status: 'manual'; reason: string; raw: Record<string, unknown> }
  | { status: 'failed'; reason: string; retryable: boolean; raw: Record<string, unknown> };
export interface PaymentGateway {
  readonly provider: PaymentProvider;
  createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult>;
  verifyWebhook(req: WebhookRequest): Promise<WebhookVerification>;   // pure: signature + shape, no database
  acknowledge(outcome: WebhookOutcome): WebhookAck;                   // the provider's expected answer
  refund(input: RefundInput): Promise<RefundResult>;
}
export interface PaymentGateways { get(provider: PaymentProvider): PaymentGateway | undefined; enabled(): PaymentProvider[] }
export function gatewayRegistry(list: readonly PaymentGateway[]): PaymentGateways;
export function buildGateways(config: Pick<ServiceConfig, 'payments' | 'fakePaymentSecret'>): PaymentGateways; // I6 appends its gateways for PAYMENTS=live
```

  - How the service uses the port (I6 must not change this): `createRequest` (Task 10) calls `createPayment` once per request with the keys above and stores `providerRef` and `raw` on the `payments` row; the webhook routes (Task 10) call `verifyWebhook` → `handlePaymentEvent(deps, event): Promise<WebhookOutcome>` (idempotent by `payments.status`) → `acknowledge(outcome)`; the `refund` job (Task 10) calls `refund` and maps `done` → `refunds.status = 'done'`, `pending` → unchanged (I6's webhook or poller finishes it), `manual` → `refunds.manual = true`, `failed` + `retryable` → thrown (BullMQ retries 8 times with exponential backoff from 30 s), `failed` otherwise → `status 'failed', manual true`.
  - `FakePaymentGateway(secret)` (`provider = 'fake'`): `paymentUrl = fake://pay/<requestId>`; webhook = POST JSON `{"paymentId", "status": "paid" | "failed", "amountVnd"}` signed with `x-fake-signature: hex(HMAC-SHA256(secret, rawBody))`; `fakeSignature(secret, rawBody)`; `refunds` (recorded inputs) and `nextRefund` (test switch).
  - `runGatewayContract(name, fixture: GatewayFixture)` in `test/payments/gateway-contract.ts`: the behaviour every gateway must have; I6 calls it for MoMo and VNPay with its own signed fixtures.

- [ ] **Step 1: Write the failing tests**

```ts
// services/dispatch/test/payments/gateway-contract.ts
import { describe, expect, it } from 'vitest';

import type { PaymentGateway, WebhookRequest } from '../../src/payments/gateway.js';

/**
 * Behaviour every PaymentGateway must have. Plan I6 runs this same suite for MoMo and VNPay:
 *   runGatewayContract('momo', { make: () => new MomoGateway(sandbox), paidWebhook: signedMomoIpn, tamperedWebhook: brokenMomoIpn })
 */
export interface GatewayFixture {
  make(): PaymentGateway;
  /** A correctly signed provider callback reporting `paymentId` paid with `amountVnd`. */
  paidWebhook(paymentId: string, amountVnd: number): WebhookRequest;
  /** The same callback with the signature broken. */
  tamperedWebhook(paymentId: string, amountVnd: number): WebhookRequest;
}

export function runGatewayContract(name: string, f: GatewayFixture): void {
  describe(`PaymentGateway contract: ${name}`, () => {
    const input = {
      paymentId: '01J9ZPAY000000000000000000', idempotencyKey: 'instant:01J9ZREQ000000000000000000',
      subject: { type: 'instant_request' as const, id: '01J9ZREQ000000000000000000' }, amountVnd: 600_000,
      description: 'Chụp ngay p60', returnUrl: 'photobooking://instant/01J9ZREQ000000000000000000', expiresAt: new Date('2026-10-01T08:15:00Z'),
    };

    it('creates a payment URL and keeps no secret in raw', async () => {
      const r = await f.make().createPayment(input);
      expect(r.paymentUrl.length).toBeGreaterThan(0);
      expect(JSON.stringify(r.raw)).not.toMatch(/secret|password|card/i);
    });

    it('verifies a signed paid callback into a paid event for our payment id and amount', async () => {
      const v = await f.make().verifyWebhook(f.paidWebhook(input.paymentId, input.amountVnd));
      expect(v).toMatchObject({ ok: true, event: { kind: 'paid', paymentId: input.paymentId, amountVnd: input.amountVnd } });
    });

    it('refuses a tampered callback', async () => {
      const v = await f.make().verifyWebhook(f.tamperedWebhook(input.paymentId, input.amountVnd));
      expect(v).toEqual({ ok: false, reason: 'invalid_signature' });
    });

    it('acknowledges every outcome with an HTTP status', () => {
      const g = f.make();
      for (const o of ['processed', 'duplicate', 'unknown_payment', 'amount_mismatch', 'invalid_signature', 'malformed', 'error'] as const) {
        const ack = g.acknowledge(o);
        expect(ack.status).toBeGreaterThanOrEqual(200);
        expect(ack.status).toBeLessThan(600);
      }
      expect(g.acknowledge('processed').status).toBeLessThan(300);
      expect(g.acknowledge('duplicate').status).toBeLessThan(300);
    });

    it('refunds with our refund id and idempotency key', async () => {
      const r = await f.make().refund({
        refundId: '01J9ZREF000000000000000000', idempotencyKey: 'instant:01J9ZREQ000000000000000000:refund',
        paymentId: input.paymentId, providerRef: 'ref', amountVnd: 480_000, paymentAmountVnd: 600_000, reason: 'instant en_route_fee',
      });
      expect(['done', 'pending', 'manual', 'failed']).toContain(r.status);
    });
  });
}
```

```ts
// services/dispatch/test/payments/fake-gateway.test.ts
import { describe, expect, it } from 'vitest';

import { FakePaymentGateway, fakeSignature } from '../../src/payments/fake.js';
import type { WebhookRequest } from '../../src/payments/gateway.js';
import { buildGateways } from '../../src/payments/registry.js';
import { runGatewayContract } from './gateway-contract.js';

const SECRET = 'fake-secret-for-tests-only';
const hook = (body: object, signature?: string): WebhookRequest => {
  const rawBody = JSON.stringify(body);
  return { provider: 'fake', method: 'POST', headers: { 'x-fake-signature': signature ?? fakeSignature(SECRET, rawBody) }, query: {}, rawBody };
};

runGatewayContract('fake', {
  make: () => new FakePaymentGateway(SECRET),
  paidWebhook: (paymentId, amountVnd) => hook({ paymentId, status: 'paid', amountVnd }),
  tamperedWebhook: (paymentId, amountVnd) => hook({ paymentId, status: 'paid', amountVnd }, 'f'.repeat(64)),
});

describe('FakePaymentGateway', () => {
  it('pays to fake://pay/<requestId> as the contract says', async () => {
    const r = await new FakePaymentGateway(SECRET).createPayment({
      paymentId: 'P', idempotencyKey: 'instant:R', subject: { type: 'instant_request', id: 'R' }, amountVnd: 1_000,
      description: 'x', returnUrl: 'photobooking://instant/R', expiresAt: new Date(),
    });
    expect(r.paymentUrl).toBe('fake://pay/R');
  });

  it('a body changed after signing is refused; GET is malformed', async () => {
    const g = new FakePaymentGateway(SECRET);
    const ok = hook({ paymentId: 'P', status: 'paid', amountVnd: 1_000 });
    expect((await g.verifyWebhook({ ...ok, rawBody: ok.rawBody.replace('1000', '1') })).ok).toBe(false);
    expect(await g.verifyWebhook({ ...ok, method: 'GET' })).toEqual({ ok: false, reason: 'malformed' });
  });

  it('refuses short secrets; PAYMENTS=live has no gateway until I6', () => {
    expect(() => new FakePaymentGateway('short')).toThrow(/16/);
    expect(buildGateways({ payments: 'live', fakePaymentSecret: '' }).enabled()).toEqual([]);
    expect(buildGateways({ payments: 'fake', fakePaymentSecret: SECRET }).enabled()).toEqual(['fake']);
  });
});
```

- [ ] **Step 2: Run and see them fail**

Run: `npm test -- test/payments`
Expected: FAIL, `Failed to load url ../../src/payments/fake.js`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/payments/gateway.ts
/**
 * PaymentGateway port (data-model README §3). Plan I3 ships the `fake` provider; plan I6 adds
 * MoMo and VNPay by implementing this interface and registering them in `buildGateways`
 * (src/payments/registry.ts). Nothing else in the service changes for I6.
 *
 * Rules every implementation follows:
 *  - Money is integer VND. Ids are ours (`paymentId` = payments.id, `refundId` = refunds.id) and
 *    are the provider's order / request ids, so a retried call is recognisable.
 *  - `idempotencyKey` is stable per business operation; calling twice with the same key must not
 *    charge or refund twice (send it as the provider's idempotency/request id when supported).
 *  - Only a verified webhook (signature checked by `verifyWebhook`) moves a request to `searching`;
 *    the app's redirect after payment is never trusted (spec §4).
 *  - No card, wallet or account number is ever returned in `raw`, logged, or stored.
 */
import type { PaymentProvider } from '../domain/core.js';

export interface CreatePaymentInput {
  /** payments.id (ULID): the provider's order id. */
  paymentId: string;
  /** payments.idempotency_key, `instant:<requestId>`. */
  idempotencyKey: string;
  subject: { type: 'instant_request'; id: string };
  /** Integer VND > 0. */
  amountVnd: number;
  /** Shown by the provider, Vietnamese, ≤ 200 characters. */
  description: string;
  /** Where the provider sends the user afterwards (app deep link). Not proof of payment. */
  returnUrl: string;
  /** The provider must refuse to take money after this instant. */
  expiresAt: Date;
}

export interface CreatePaymentResult {
  /** URL the app opens (https for real providers; `fake://pay/<requestId>` for the fake one). */
  paymentUrl: string;
  /** Provider's transaction / order reference when it gives one at creation. */
  providerRef: string | null;
  /** Stored in payments.raw: the provider's response minus secrets. */
  raw: Record<string, unknown>;
}

/** A provider callback exactly as it arrived (headers lower-cased). */
export interface WebhookRequest {
  provider: PaymentProvider;
  method: 'GET' | 'POST';
  headers: Readonly<Record<string, string | undefined>>;
  /** Query string (VNPay IPN carries everything here). */
  query: Readonly<Record<string, string>>;
  /** Body as received, UTF-8 ('' for GET); signatures are checked over this, not a re-serialisation. */
  rawBody: string;
}

export type PaymentEvent =
  | { kind: 'paid'; paymentId: string; providerRef: string; amountVnd: number; raw: Record<string, unknown> }
  | { kind: 'failed'; paymentId: string; providerRef: string | null; reason: string; raw: Record<string, unknown> };

export type WebhookVerification =
  | { ok: true; event: PaymentEvent }
  | { ok: false; reason: 'invalid_signature' | 'malformed' };

/** What the service did with a callback; the gateway turns it into the provider's expected answer. */
export type WebhookOutcome =
  | 'processed'
  | 'duplicate'
  | 'unknown_payment'
  | 'amount_mismatch'
  | 'invalid_signature'
  | 'malformed'
  | 'error';

export interface WebhookAck {
  status: number;
  headers?: Readonly<Record<string, string>>;
  /** JSON body, or null for an empty body (e.g. MoMo's 204). */
  body: unknown;
}

export interface RefundInput {
  /** refunds.id (ULID): the provider's refund request id. */
  refundId: string;
  /** `instant:<requestId>:refund`. */
  idempotencyKey: string;
  paymentId: string;
  /** payments.provider_ref of the captured payment. */
  providerRef: string | null;
  /** Integer VND > 0, ≤ paymentAmountVnd. */
  amountVnd: number;
  /** The captured amount (VNPay picks full vs partial refund from it). */
  paymentAmountVnd: number;
  /** Short English reason for the provider log, e.g. "instant free_searching". */
  reason: string;
}

export type RefundResult =
  /** Money is on its way back. */
  | { status: 'done'; providerRef: string | null; raw: Record<string, unknown> }
  /** Accepted, final answer comes later (refunds.status stays pending). */
  | { status: 'pending'; providerRef: string | null; raw: Record<string, unknown> }
  /** The provider cannot refund automatically: an admin refunds by hand (refunds.manual = true, spec §3g.3). */
  | { status: 'manual'; reason: string; raw: Record<string, unknown> }
  | { status: 'failed'; reason: string; retryable: boolean; raw: Record<string, unknown> };

export interface PaymentGateway {
  readonly provider: PaymentProvider;
  createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult>;
  /** Pure check of signature and shape; no database access. */
  verifyWebhook(req: WebhookRequest): Promise<WebhookVerification>;
  acknowledge(outcome: WebhookOutcome): WebhookAck;
  refund(input: RefundInput): Promise<RefundResult>;
}

export interface PaymentGateways {
  get(provider: PaymentProvider): PaymentGateway | undefined;
  enabled(): PaymentProvider[];
}

export function gatewayRegistry(list: readonly PaymentGateway[]): PaymentGateways {
  const map = new Map(list.map((g) => [g.provider, g] as const));
  return { get: (p) => map.get(p), enabled: () => [...map.keys()] };
}
```

```ts
// services/dispatch/src/payments/fake.ts
import { createHmac, timingSafeEqual } from 'node:crypto';

import type {
  CreatePaymentInput, CreatePaymentResult, PaymentGateway, RefundInput, RefundResult, WebhookAck, WebhookOutcome,
  WebhookRequest, WebhookVerification,
} from './gateway.js';

/** HMAC-SHA256 hex of the raw body: the `x-fake-signature` header. */
export function fakeSignature(secret: string, rawBody: string): string {
  return createHmac('sha256', secret).update(rawBody, 'utf8').digest('hex');
}

/**
 * PAYMENTS=fake (local, tests, load test; refused in production). Behaves like a real provider at
 * the port: a payment URL, a signed webhook, an acknowledgement, refunds that succeed — so I6's
 * providers drop into the same code paths and the shared gateway contract test.
 * Webhook body: `{"paymentId": "...", "status": "paid" | "failed", "amountVnd": 600000}`.
 */
export class FakePaymentGateway implements PaymentGateway {
  readonly provider = 'fake' as const;
  readonly refunds: RefundInput[] = [];
  /** Tests flip this to exercise retries and the manual path. */
  nextRefund: RefundResult['status'] = 'done';

  constructor(private readonly secret: string) {
    if (secret.length < 16) throw new Error('FAKE_PAYMENT_SECRET must be at least 16 characters');
  }

  async createPayment(input: CreatePaymentInput): Promise<CreatePaymentResult> {
    return {
      paymentUrl: `fake://pay/${input.subject.id}`,
      providerRef: `fake-${input.paymentId}`,
      raw: { provider: 'fake', amountVnd: input.amountVnd, expiresAt: input.expiresAt.toISOString() },
    };
  }

  async verifyWebhook(req: WebhookRequest): Promise<WebhookVerification> {
    if (req.method !== 'POST') return { ok: false, reason: 'malformed' };
    const given = req.headers['x-fake-signature'] ?? '';
    const want = fakeSignature(this.secret, req.rawBody);
    const a = Buffer.from(given, 'utf8');
    const b = Buffer.from(want, 'utf8');
    if (a.length !== b.length || !timingSafeEqual(a, b)) return { ok: false, reason: 'invalid_signature' };
    let body: { paymentId?: unknown; status?: unknown; amountVnd?: unknown };
    try {
      body = JSON.parse(req.rawBody) as typeof body;
    } catch {
      return { ok: false, reason: 'malformed' };
    }
    if (typeof body.paymentId !== 'string') return { ok: false, reason: 'malformed' };
    const raw = { provider: 'fake', status: body.status };
    if (body.status === 'paid' && typeof body.amountVnd === 'number' && Number.isSafeInteger(body.amountVnd)) {
      return { ok: true, event: { kind: 'paid', paymentId: body.paymentId, providerRef: `fake-${body.paymentId}`, amountVnd: body.amountVnd, raw } };
    }
    if (body.status === 'failed') {
      return { ok: true, event: { kind: 'failed', paymentId: body.paymentId, providerRef: `fake-${body.paymentId}`, reason: 'declined', raw } };
    }
    return { ok: false, reason: 'malformed' };
  }

  acknowledge(outcome: WebhookOutcome): WebhookAck {
    switch (outcome) {
      case 'processed':
      case 'duplicate':
      case 'unknown_payment':
      case 'amount_mismatch':
        // Like real providers: answer 200 for anything we recorded or will never accept, so they stop retrying.
        return { status: 200, body: { ok: true, outcome } };
      case 'invalid_signature':
        return { status: 401, body: { code: 'unauthenticated', message: 'invalid signature' } };
      case 'malformed':
        return { status: 400, body: { code: 'invalid_argument', message: 'malformed webhook' } };
      case 'error':
        return { status: 500, body: { code: 'internal', message: 'internal error' } };
    }
  }

  async refund(input: RefundInput): Promise<RefundResult> {
    this.refunds.push(input);
    switch (this.nextRefund) {
      case 'done':
        return { status: 'done', providerRef: `fake-refund-${input.refundId}`, raw: { provider: 'fake' } };
      case 'pending':
        return { status: 'pending', providerRef: `fake-refund-${input.refundId}`, raw: { provider: 'fake' } };
      case 'manual':
        return { status: 'manual', reason: 'fake manual', raw: { provider: 'fake' } };
      case 'failed':
        return { status: 'failed', reason: 'fake failure', retryable: true, raw: { provider: 'fake' } };
    }
  }
}
```

```ts
// services/dispatch/src/payments/registry.ts
import type { ServiceConfig } from '../config.js';
import { FakePaymentGateway } from './fake.js';
import { gatewayRegistry, type PaymentGateway, type PaymentGateways } from './gateway.js';

/**
 * The gateways this process accepts. PAYMENTS=fake → only `fake`.
 * PAYMENTS=live → the real providers; plan I6 appends `new MomoGateway(...)` and
 * `new VnpayGateway(...)` to `live` below. Until then a live process has no gateway and
 * POST /v1/requests answers invalid_argument "payment provider not enabled".
 */
export function buildGateways(config: Pick<ServiceConfig, 'payments' | 'fakePaymentSecret'>): PaymentGateways {
  if (config.payments === 'fake') return gatewayRegistry([new FakePaymentGateway(config.fakePaymentSecret)]);
  const live: PaymentGateway[] = [];
  return gatewayRegistry(live);
}
```

- [ ] **Step 4: Run and see them pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  2 passed (2)`, `Tests  13 passed (13)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): PaymentGateway port with fake provider, registry and a shared gateway contract suite for I6

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 4: `MirrorWriter` port, Firestore adapter and the `instant_*` rules

**Files:**
- Create: `services/dispatch/src/mirror/mirror.ts`, `services/dispatch/src/mirror/firestore.ts`, `services/dispatch/test/mirror-schema.ts`, `services/dispatch/test/firestore-mirror.test.ts`, `services/dispatch/vitest.mirror.config.ts`, `app_flutter/firebase/rules-test/instant.test.mjs`
- Modify: `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/rules-test/package.json`, `services/dispatch/package.json`

**Interfaces:**
- Consumes: `components['schemas']` (Task 2), `loadContract`, `toFastifySchema` (Task 2).
- Produces:
  - `type InstantRequestMirror`, `InstantTrackMirror`, `InstantOfferMirror` (= the contract schemas).
  - `interface MirrorWriter { putRequest(requestId, doc): Promise<void>; putTrack(requestId, doc); deleteTrack(requestId); putOffer(photographerId, doc); deleteOffer(photographerId, offerId) }` with the semantics: `putRequest` never overwrites a stored doc whose `updatedAt` is later; `deleteOffer` deletes only if the doc still holds `offerId`.
  - `class MemoryMirrorWriter implements MirrorWriter` (`requests`, `tracks`, `offers` maps, `writes` counter); `class FirestoreMirrorWriter(db: Firestore)` (collections `instant_requests`, `instant_tracks`, `instant_offers`; plain JSON values: ISO strings, integers; undefined keys omitted).
  - Test helper `expectMirror(name, doc)`: valid against the contract schema and no key outside it.
  - Firestore rules: `instant_requests/{id}` and `instant_tracks/{id}` readable only by the request's `customerId` and `photographerId`; `instant_offers/{uid}` only by that uid; no client write anywhere.

- [ ] **Step 1: Write the failing tests**

```ts
// services/dispatch/test/mirror-schema.ts
import { Ajv } from 'ajv';
import addFormats from 'ajv-formats';
import { expect } from 'vitest';

import { loadContract, toFastifySchema, type Json } from '../src/contract/openapi.js';

const contract = loadContract();
const ajv = new Ajv({ strict: false, allErrors: true });
addFormats(ajv);
for (const [name, schema] of Object.entries(contract.components.schemas)) {
  ajv.addSchema({ $id: name, ...(toFastifySchema(schema) as Record<string, Json>) });
}

type MirrorName = 'InstantRequestMirror' | 'InstantTrackMirror' | 'InstantOfferMirror';

/** A Firestore doc written by the service is exactly a contract *Mirror: valid, and no key outside the schema. */
export function expectMirror(name: MirrorName, doc: unknown): void {
  const validate = ajv.getSchema(name);
  if (!validate) throw new Error(`no schema ${name}`);
  expect(validate(doc), JSON.stringify(validate.errors)).toBe(true);
  const props = Object.keys((contract.components.schemas[name] as { properties: Record<string, unknown> }).properties);
  for (const key of Object.keys(doc as object)) expect(props, `${name}.${key} is not in the contract`).toContain(key);
}
```

```ts
// services/dispatch/test/firestore-mirror.test.ts
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { FirestoreMirrorWriter } from '../src/mirror/firestore.js';
import type { InstantRequestMirror } from '../src/mirror/mirror.js';
import { expectMirror } from './mirror-schema.js';

// Runs against the Firestore emulator only: `npm run test:mirror` (see package.json) starts it.
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;

describe.runIf(enabled)('FirestoreMirrorWriter on the emulator', () => {
  let app: App;
  let fs: Firestore;
  let mirror: FirestoreMirrorWriter;
  beforeAll(() => {
    app = initializeApp({ projectId: 'demo-nag' }, `mirror-${Date.now()}`);
    fs = getFirestore(app);
    mirror = new FirestoreMirrorWriter(fs);
  });
  afterAll(async () => deleteApp(app));

  const doc = (status: InstantRequestMirror['status'], updatedAt: string): InstantRequestMirror => ({
    status, customerId: 'c1', photographerId: null, photographer: null, packageCode: 'p60', genre: 'portrait', amountVnd: 600_000,
    expand: false, round: 1, radiusKm: 3, searchEndsAt: '2026-10-01T08:05:00.000Z', etaMinutes: null, etaEstimated: false,
    graceEndsAt: null, meetPoint: null, requestedAt: '2026-10-01T08:00:00.000Z', assignedAt: null, arrivedAt: null,
    startedAt: null, finishedAt: null, refundVnd: null, updatedAt,
  });

  it('writes plain JSON values (ISO strings, integers), never Timestamps', async () => {
    await mirror.putRequest('r1', doc('searching', '2026-10-01T08:00:01.000Z'));
    const snap = await fs.collection('instant_requests').doc('r1').get();
    expectMirror('InstantRequestMirror', snap.data());
    expect(typeof snap.get('updatedAt')).toBe('string');
  });

  it('an older writer never overwrites a newer state', async () => {
    await mirror.putRequest('r2', doc('assigned', '2026-10-01T08:00:05.000Z'));
    await mirror.putRequest('r2', doc('searching', '2026-10-01T08:00:04.000Z'));
    expect((await fs.collection('instant_requests').doc('r2').get()).get('status')).toBe('assigned');
  });

  it('deleteOffer removes only the offer it was asked to remove; tracks are one doc', async () => {
    const offer = { offerId: 'o2', requestId: 'r', packageCode: 'p60' as const, genre: 'portrait' as const, payoutVnd: 480_000, distanceKm: 1.2, travelMinutes: 6, area: 'Quận 1', note: null, expiresAt: '2026-10-01T08:00:30.000Z' };
    await mirror.putOffer('p1', offer);
    await mirror.deleteOffer('p1', 'o1');
    expect((await fs.collection('instant_offers').doc('p1').get()).exists).toBe(true);
    await mirror.deleteOffer('p1', 'o2');
    expect((await fs.collection('instant_offers').doc('p1').get()).exists).toBe(false);
    await mirror.putTrack('r', { lat: 10.77, lng: 106.69, accuracyM: 12, headingDeg: 90, at: '2026-10-01T08:01:00.000Z' });
    await mirror.putTrack('r', { lat: 10.78, lng: 106.69, accuracyM: 12, headingDeg: null, at: '2026-10-01T08:01:10.000Z' });
    expect((await fs.collection('instant_tracks').doc('r').get()).get('lat')).toBe(10.78);
    await mirror.deleteTrack('r');
    expect((await fs.collection('instant_tracks').doc('r').get()).exists).toBe(false);
  });
});
```

```ts
// services/dispatch/vitest.mirror.config.ts
import { defineConfig } from 'vitest/config';

// The Firestore mirror suite needs only the Firestore emulator (no PostgreSQL, no Redis).
export default defineConfig({ test: { include: ['test/firestore-mirror.test.ts'], testTimeout: 30_000 } });
```

```js
// app_flutter/firebase/rules-test/instant.test.mjs
// Firestore rules for the instant booking mirrors (plan I3, Task 5; spec §7 and §11 "Rules").
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nag-instant',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => env.cleanup());

const REQUEST = { status: 'en_route', customerId: 'cust', photographerId: 'pho', packageCode: 'p60', genre: 'portrait',
  amountVnd: 600000, expand: false, round: 1, requestedAt: '2026-10-01T08:00:00.000Z', updatedAt: '2026-10-01T08:01:00.000Z' };
const TRACK = { lat: 10.77, lng: 106.69, accuracyM: 12, at: '2026-10-01T08:01:00.000Z' };
const OFFER = { offerId: '01J9ZXFF000000000000000000', requestId: 'r1', packageCode: 'p60', genre: 'portrait', payoutVnd: 480000,
  distanceKm: 1.2, travelMinutes: 6, area: 'Phường Bến Thành, Quận 1', note: null, expiresAt: '2026-10-01T08:00:30.000Z' };

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'instant_requests/r1'), REQUEST);
    await setDoc(doc(db, 'instant_requests/r2'), { ...REQUEST, status: 'searching', photographerId: null });
    await setDoc(doc(db, 'instant_tracks/r1'), TRACK);
    await setDoc(doc(db, 'instant_offers/pho'), OFFER);
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

test('instant_requests: the customer and the assigned photographer read; nobody else', async () => {
  await assertSucceeds(getDoc(doc(as('cust'), 'instant_requests/r1')));
  await assertSucceeds(getDoc(doc(as('pho'), 'instant_requests/r1')));
  await assertFails(getDoc(doc(as('stranger'), 'instant_requests/r1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'instant_requests/r1')));
  await assertSucceeds(getDoc(doc(as('cust'), 'instant_requests/r2')));
  await assertFails(getDoc(doc(as('pho'), 'instant_requests/r2')));
});

test('instant_tracks: only the two parties of the request; not the photographer of another request', async () => {
  await assertSucceeds(getDoc(doc(as('cust'), 'instant_tracks/r1')));
  await assertSucceeds(getDoc(doc(as('pho'), 'instant_tracks/r1')));
  await assertFails(getDoc(doc(as('stranger'), 'instant_tracks/r1')));
  await assertFails(getDoc(doc(as('cust'), 'instant_tracks/r404')));
});

test('instant_offers/{uid}: only that photographer, also before an offer exists', async () => {
  await assertSucceeds(getDoc(doc(as('pho'), 'instant_offers/pho')));
  await assertSucceeds(getDoc(doc(as('other'), 'instant_offers/other')));
  await assertFails(getDoc(doc(as('cust'), 'instant_offers/pho')));
  await assertFails(getDoc(doc(as('other'), 'instant_offers/pho')));
});

test('clients never write any instant_* document, not even their own', async () => {
  for (const [uid, path, data] of [
    ['cust', 'instant_requests/r1', { status: 'completed' }],
    ['pho', 'instant_requests/r1', { status: 'completed' }],
    ['cust', 'instant_requests/new', REQUEST],
    ['pho', 'instant_tracks/r1', TRACK],
    ['pho', 'instant_offers/pho', OFFER],
  ]) {
    await assertFails(setDoc(doc(as(uid), path), data));
    await assertFails(updateDoc(doc(as(uid), path), { x: 1 }));
    await assertFails(deleteDoc(doc(as(uid), path)));
  }
});
```

Plan I4 (photographer app) writes the same `instant_*` rules: if its block is already in `firestore.rules` when you get here, keep one copy (this one is identical in effect) and keep both test files.

In `app_flutter/firebase/rules-test/package.json`, change the `test` script's last argument from `'node --test rules.test.mjs'` to `'node --test rules.test.mjs instant.test.mjs'` (if another plan already added files there, append ` instant.test.mjs` to its list).

In `services/dispatch/package.json` add the script:

```json
    "test:mirror": "npx --prefix ../../app_flutter/firebase/rules-test firebase emulators:exec --config ../../app_flutter/firebase/firebase.json --only firestore --project demo-nag 'vitest run --config vitest.mirror.config.ts'",
```

- [ ] **Step 2: Run and see them fail**

Run (from `app_flutter/firebase/rules-test`): `npm test`
Expected: the four `instant_*` tests fail (`assertSucceeds` on reads: the catch-all rule denies them); the existing rules tests still pass.

Run (from `services/dispatch`): `npm run test:mirror`
Expected: FAIL, `Failed to load url ../src/mirror/firestore.js`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/mirror/mirror.ts
import type { components } from '../generated/api.js';

export type InstantRequestMirror = components['schemas']['InstantRequestMirror'];
export type InstantTrackMirror = components['schemas']['InstantTrackMirror'];
export type InstantOfferMirror = components['schemas']['InstantOfferMirror'];

/**
 * Read-only realtime copy for the app (spec §5, contract `*Mirror` schemas, `x-firestore-path`).
 * Only this service writes; Firestore rules deny every client write.
 */
export interface MirrorWriter {
  /**
   * Overwrites instant_requests/{requestId} unless the stored doc has a later `updatedAt`
   * (two writers racing never move the app backwards).
   */
  putRequest(requestId: string, doc: InstantRequestMirror): Promise<void>;
  /** instant_tracks/{requestId}: one document, overwritten (no history, spec §7). */
  putTrack(requestId: string, doc: InstantTrackMirror): Promise<void>;
  deleteTrack(requestId: string): Promise<void>;
  /** instant_offers/{photographerId}: the one pending offer of that photographer. */
  putOffer(photographerId: string, doc: InstantOfferMirror): Promise<void>;
  /** Deletes instant_offers/{photographerId} only if it still holds `offerId`. */
  deleteOffer(photographerId: string, offerId: string): Promise<void>;
}

/** Test and MIRROR=memory implementation, with a write counter for the payload/battery tests. */
export class MemoryMirrorWriter implements MirrorWriter {
  readonly requests = new Map<string, InstantRequestMirror>();
  readonly tracks = new Map<string, InstantTrackMirror>();
  readonly offers = new Map<string, InstantOfferMirror>();
  writes = 0;

  async putRequest(requestId: string, doc: InstantRequestMirror): Promise<void> {
    this.writes++;
    const cur = this.requests.get(requestId);
    if (cur && cur.updatedAt > doc.updatedAt) return;
    this.requests.set(requestId, structuredClone(doc));
  }
  async putTrack(requestId: string, doc: InstantTrackMirror): Promise<void> {
    this.writes++;
    this.tracks.set(requestId, structuredClone(doc));
  }
  async deleteTrack(requestId: string): Promise<void> {
    this.writes++;
    this.tracks.delete(requestId);
  }
  async putOffer(photographerId: string, doc: InstantOfferMirror): Promise<void> {
    this.writes++;
    this.offers.set(photographerId, structuredClone(doc));
  }
  async deleteOffer(photographerId: string, offerId: string): Promise<void> {
    this.writes++;
    if (this.offers.get(photographerId)?.offerId === offerId) this.offers.delete(photographerId);
  }
}
```

```ts
// services/dispatch/src/mirror/firestore.ts
import type { Firestore } from 'firebase-admin/firestore';

import type { InstantOfferMirror, InstantRequestMirror, InstantTrackMirror, MirrorWriter } from './mirror.js';

/**
 * Firestore adapter of MirrorWriter (firebase-admin). Documents are written exactly as the
 * contract's *Mirror schemas: camelCase keys, ISO-8601 strings for instants (not Timestamps),
 * integer VND. Undefined optional keys are omitted, nulls are kept.
 */
export class FirestoreMirrorWriter implements MirrorWriter {
  constructor(private readonly db: Firestore) {}

  async putRequest(requestId: string, doc: InstantRequestMirror): Promise<void> {
    const ref = this.db.collection('instant_requests').doc(requestId);
    await this.db.runTransaction(async (tx) => {
      const cur = await tx.get(ref);
      const stored = cur.get('updatedAt') as string | undefined;
      if (stored !== undefined && stored > doc.updatedAt) return;
      tx.set(ref, clean(doc));
    });
  }

  async putTrack(requestId: string, doc: InstantTrackMirror): Promise<void> {
    await this.db.collection('instant_tracks').doc(requestId).set(clean(doc));
  }

  async deleteTrack(requestId: string): Promise<void> {
    await this.db.collection('instant_tracks').doc(requestId).delete();
  }

  async putOffer(photographerId: string, doc: InstantOfferMirror): Promise<void> {
    await this.db.collection('instant_offers').doc(photographerId).set(clean(doc));
  }

  async deleteOffer(photographerId: string, offerId: string): Promise<void> {
    const ref = this.db.collection('instant_offers').doc(photographerId);
    await this.db.runTransaction(async (tx) => {
      const cur = await tx.get(ref);
      if (cur.exists && cur.get('offerId') === offerId) tx.delete(ref);
    });
  }
}

function clean<T extends object>(doc: T): Record<string, unknown> {
  return Object.fromEntries(Object.entries(doc).filter(([, v]) => v !== undefined));
}
```

In `app_flutter/firebase/firestore.rules`, insert directly above `    match /{document=**} {`:

```
    // Chụp ngay (instant booking): read-only mirrors written by services/dispatch with the Admin SDK
    // (spec 2026-10-01-instant-booking-design.md §7). Clients never write them.
    function instantParty(requestId) {
      let r = get(/databases/$(database)/documents/instant_requests/$(requestId)).data;
      return r.customerId == request.auth.uid || r.get('photographerId', null) == request.auth.uid;
    }

    match /instant_requests/{requestId} {
      allow read: if signedIn()
        && (resource.data.customerId == request.auth.uid
            || resource.data.get('photographerId', null) == request.auth.uid);
      allow write: if false;
    }

    match /instant_tracks/{requestId} {
      allow read: if signedIn() && instantParty(requestId);
      allow write: if false;
    }

    match /instant_offers/{photographerId} {
      allow read: if isOwner(photographerId);
      allow write: if false;
    }
```

- [ ] **Step 4: Run and see them pass**

Run (from `app_flutter/firebase/rules-test`): `npm test`
Expected: every test passes, including `instant_requests: the customer and the assigned photographer read; nobody else`, `instant_tracks: only the two parties of the request; …`, `instant_offers/{uid}: only that photographer, also before an offer exists` and `clients never write any instant_* document, not even their own`; `ℹ fail 0`.

Run (from `services/dispatch`): `npm run test:mirror`
Expected: `✓ test/firestore-mirror.test.ts (3 tests)`, `Tests  3 passed (3)`. (Verified while writing this plan.)

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  2 passed | 1 skipped (3)`, `Tests  13 passed | 3 skipped (16)` (the Firestore mirror suite skips without the emulator).

- [ ] **Step 5: Commit**

```bash
git add services/dispatch app_flutter/firebase/firestore.rules app_flutter/firebase/rules-test
git commit -m "feat(dispatch): Firestore mirror writer and read-only instant_* rules with emulator tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Push, Goong ETA and area, schedulers, metrics, Redis connections

**Files:**
- Create: `services/dispatch/src/push/push.ts`, `services/dispatch/src/eta/eta.ts`, `services/dispatch/src/eta/goong.ts`, `services/dispatch/src/jobs/scheduler.ts`, `services/dispatch/src/metrics.ts`, `services/dispatch/src/redis/client.ts`, `services/dispatch/test/goong.test.ts`, `services/dispatch/test/push.test.ts`

**Interfaces:**
- Consumes: `estimateEta`, `DispatchConfig`, `LatLng`, `InstantRequestStatus` (plan I2).
- Produces:
  - `type PushMessage = ({ type: 'offer' } & InstantOfferMirror) | { type: 'assigned'; requestId; etaMinutes } | { type: 'status'; requestId; status; noShowAvailable? }` — the FCM data contract plan I4's app parses (`type=offer` + every `InstantOfferMirror` field; `assigned` + `requestId`; `status` + `requestId`, `status`; all values strings); `interface PushSender { send(uid, message): Promise<void> }` (never throws); `interface PushTokenSource { tokensFor(uid): Promise<string[]> }`; `toData(m): Record<string, string>` (null/undefined keys left out); `FcmPushSender(messaging, tokens, log)` (offers and assignment: Android data-only `high` priority, APNs priority 10 alert with sound, offers `interruption-level: time-sensitive`; status: normal priority background; offer TTL ends with the offer); `FirestoreTokenSource(db)` (plan I4's `devices/{uid}_{installId}` documents `{userId, provider: 'fcm', token, platform, lastSeenAt}`, at most 10); `RecordingPushSender` (`sent`, `to(uid)`).
  - `interface EtaResult { minutes; estimated }`, `interface EtaProvider { eta(from, to, cfg): Promise<EtaResult> }`, `interface AreaResolver { areaOf(point): Promise<string | null> }`, `estimateProvider`, `noAreaResolver`, `areaFromAddress(address, cityName)`; `GoongEtaProvider({ apiKey, timeoutMs, fetch?, log?, baseUrl? })` implementing both (Distance Matrix `vehicle=bike`, Geocode `commune, district`; any failure → estimate / null; the key only in outgoing URLs, never logged).
  - `JOB_NAMES`, `type JobName`, `type JobHandlers = Partial<Record<JobName, (key: string) => Promise<void>>>`, `interface Scheduler { schedule(name, key, at: Date): Promise<void> }`, `jobId(name, key, at)`, `BullScheduler(connection, now, queueName?)` (`queue`, `close()`), `startWorker(connection, handlers, queueName?, concurrency?)`, `ManualScheduler` (`jobs`, `pending(name?)`, `handlers`, `runDue(now)`).
  - `class Metrics { observe(name, ms); summary(); reset() }`.
  - `createRedis(url)` (commands, auto-pipelining), `createBullConnection(url)` (`maxRetriesPerRequest: null`, required by BullMQ).

- [ ] **Step 1: Write the failing tests**

```ts
// services/dispatch/test/goong.test.ts
import { describe, expect, it } from 'vitest';

import { DEFAULT_CONFIG } from '../src/domain/core.js';
import { areaFromAddress } from '../src/eta/eta.js';
import { GoongEtaProvider } from '../src/eta/goong.js';

const A = { lat: 10.7725, lng: 106.698 };
const B = { lat: 10.8231, lng: 106.6297 };
const KEY = 'goong-key-never-logged';

function provider(respond: (url: string) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>, logs: string[] = []) {
  const urls: string[] = [];
  const p = new GoongEtaProvider({
    apiKey: KEY,
    timeoutMs: 50,
    fetch: (url) => {
      urls.push(url);
      return respond(url);
    },
    log: (msg, extra) => logs.push(`${msg} ${JSON.stringify(extra ?? {})}`),
  });
  return { p, urls, logs };
}

const json = (body: unknown, status = 200) => Promise.resolve({ ok: status < 400, status, json: async () => body });

describe('Goong Distance Matrix (spec §3.2, §10)', () => {
  it('uses Goong duration (motorbike), whole minutes rounded up', async () => {
    const { p, urls } = provider(() => json({ rows: [{ elements: [{ status: 'OK', duration: { value: 610 }, distance: { value: 7_900 } }] }] }));
    expect(await p.eta(A, B, DEFAULT_CONFIG)).toEqual({ minutes: 11, estimated: false });
    expect(urls[0]).toContain('/DistanceMatrix?origins=10.772500,106.698000&destinations=10.823100,106.629700&vehicle=bike&api_key=');
  });

  it('falls back to the straight-line estimate on HTTP errors, bad bodies and timeouts', async () => {
    const estimate = { minutes: 40, estimated: true }; // ≈ 9.4 km × 1.4 at 20 km/h
    expect(await provider(() => json({ error: 'quota' }, 429)).p.eta(A, B, DEFAULT_CONFIG)).toEqual(estimate);
    expect(await provider(() => json({ rows: [{ elements: [{ status: 'ZERO_RESULTS' }] }] })).p.eta(A, B, DEFAULT_CONFIG)).toEqual(estimate);
    const slow = provider((url) => new Promise((_, reject) => setTimeout(() => reject(Object.assign(new Error(url), { name: 'TimeoutError' })), 100)));
    expect(await slow.p.eta(A, B, DEFAULT_CONFIG)).toEqual(estimate);
  });

  it('never logs the API key, even when the error message contains the URL', async () => {
    const logs: string[] = [];
    const { p } = provider((url) => Promise.reject(new Error(`failed ${url}`)), logs);
    await p.eta(A, B, DEFAULT_CONFIG);
    await p.areaOf(A);
    expect(logs.length).toBeGreaterThan(0);
    for (const l of logs) expect(l).not.toContain(KEY);
  });

  it('area: "commune, district" from Geocode; null on failure; address fallback', async () => {
    const ok = provider(() => json({ results: [{ compound: { commune: 'Phường Bến Thành', district: 'Quận 1', province: 'Hồ Chí Minh' } }] }));
    expect(await ok.p.areaOf(A)).toBe('Phường Bến Thành, Quận 1');
    expect(await provider(() => json({}, 500)).p.areaOf(A)).toBeNull();
    expect(areaFromAddress('12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh', 'Hồ Chí Minh')).toBe('Phường Bến Thành, Quận 1');
    expect(areaFromAddress('Chợ Bến Thành', 'Hồ Chí Minh')).toBe('Hồ Chí Minh');
  });
});
```

```ts
// services/dispatch/test/push.test.ts
import type { Messaging } from 'firebase-admin/messaging';
import { describe, expect, it } from 'vitest';

import { FcmPushSender, toData, type PushMessage } from '../src/push/push.js';

const OFFER: PushMessage = {
  type: 'offer', offerId: '01J9ZXFF000000000000000000', requestId: '01J9ZREQ000000000000000000', packageCode: 'p60', genre: 'portrait',
  payoutVnd: 480_000, distanceKm: 1.2, travelMinutes: 6, area: 'Phường Bến Thành, Quận 1', note: null, expiresAt: '2026-10-01T08:00:30.000Z',
};

describe('FCM data messages (spec §5: offer, assigned, status)', () => {
  it('an offer carries every offer field as a string; null fields are left out', () => {
    expect(toData(OFFER)).toEqual({
      type: 'offer', offerId: OFFER.offerId, requestId: OFFER.requestId, packageCode: 'p60', genre: 'portrait', payoutVnd: '480000',
      distanceKm: '1.2', travelMinutes: '6', area: 'Phường Bến Thành, Quận 1', expiresAt: '2026-10-01T08:00:30.000Z',
    });
  });

  it('are string maps far below the 4 KB FCM limit', () => {
    const msgs: PushMessage[] = [
      OFFER,
      { type: 'assigned', requestId: OFFER.requestId, etaMinutes: 12 },
      { type: 'status', requestId: OFFER.requestId, status: 'arrived', noShowAvailable: true },
    ];
    for (const m of msgs) {
      const data = toData(m);
      for (const v of Object.values(data)) expect(typeof v).toBe('string');
      expect(Buffer.byteLength(JSON.stringify(data))).toBeLessThan(512);
    }
  });

  it('offers go out high priority, with a TTL that ends with the offer, and an alert with sound', async () => {
    const calls: unknown[] = [];
    const messaging = { sendEachForMulticast: async (m: unknown) => (calls.push(m), { failureCount: 0, successCount: 1, responses: [] }) } as unknown as Messaging;
    const sender = new FcmPushSender(messaging, { tokensFor: async () => ['t1', 't2'] }, () => {});
    await sender.send('p1', { ...OFFER, expiresAt: new Date(Date.now() + 30_000).toISOString() });
    const m = calls[0] as { tokens: string[]; android: { priority: string; ttl: number }; apns: { headers: Record<string, string>; payload: { aps: Record<string, unknown> } } };
    expect(m.tokens).toEqual(['t1', 't2']);
    expect(m.android.priority).toBe('high');
    expect(m.android.ttl).toBeGreaterThan(25_000);
    expect(m.android.ttl).toBeLessThanOrEqual(30_000);
    expect(m.apns.headers['apns-priority']).toBe('10');
    expect(m.apns.payload.aps.sound).toBe('default');
    expect(m.apns.payload.aps['interruption-level']).toBe('time-sensitive');
  });

  it('status updates are normal priority background pushes; failures never throw', async () => {
    const calls: unknown[] = [];
    const messaging = { sendEachForMulticast: async (m: unknown) => (calls.push(m), { failureCount: 0, successCount: 1, responses: [] }) } as unknown as Messaging;
    await new FcmPushSender(messaging, { tokensFor: async () => ['t'] }, () => {}).send('c1', { type: 'status', requestId: 'r', status: 'arrived' });
    expect((calls[0] as { android: { priority: string } }).android.priority).toBe('normal');
    const broken = { sendEachForMulticast: async () => { throw new Error('fcm down'); } } as unknown as Messaging;
    const logs: string[] = [];
    await new FcmPushSender(broken, { tokensFor: async () => ['t'] }, (msg) => logs.push(msg)).send('c1', OFFER);
    expect(logs).toEqual(['push_failed']);
  });

  it('no token, no call', async () => {
    let called = false;
    const messaging = { sendEachForMulticast: async () => { called = true; return { failureCount: 0 }; } } as unknown as Messaging;
    await new FcmPushSender(messaging, { tokensFor: async () => [] }, () => {}).send('c1', OFFER);
    expect(called).toBe(false);
  });
});
```

- [ ] **Step 2: Run and see them fail**

Run: `npm test -- test/goong.test.ts test/push.test.ts`
Expected: FAIL, `Failed to load url ../src/eta/goong.js` and `../src/push/push.js`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/push/push.ts
import type { Firestore } from 'firebase-admin/firestore';
import type { Messaging } from 'firebase-admin/messaging';

import type { InstantRequestStatus } from '../domain/core.js';
import type { InstantOfferMirror } from '../mirror/mirror.js';

/**
 * FCM data messages (spec §5: offer, assigned, status), as plan I4's app parses them: all values
 * are strings (FCM data maps); `offer` carries every InstantOfferMirror field so S53 can open from
 * the notification alone, even before the Firestore listener is up.
 */
export type PushMessage =
  | ({ type: 'offer' } & InstantOfferMirror)
  | { type: 'assigned'; requestId: string; etaMinutes: number }
  | { type: 'status'; requestId: string; status: InstantRequestStatus; noShowAvailable?: boolean };

export interface PushSender {
  /** Best effort: never throws (a lost push is covered by the mirror listener, spec §10). */
  send(uid: string, message: PushMessage): Promise<void>;
}

export interface PushTokenSource {
  tokensFor(uid: string): Promise<string[]>;
}

/** Wire form of a message: FCM `data` map (null and undefined keys are left out). */
export function toData(m: PushMessage): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(m)) if (v !== undefined && v !== null) out[k] = String(v);
  return out;
}

/** Vietnamese notification text for the alert part (offers and assignment ring the phone). */
const ALERT: Partial<Record<PushMessage['type'], { title: string; body: string }>> = {
  offer: { title: 'Có việc chụp ngay gần bạn', body: 'Mở ứng dụng để nhận trong 30 giây' },
  assigned: { title: 'Đã có nhiếp ảnh gia nhận', body: 'Nhiếp ảnh gia đang đến chỗ bạn' },
};

export class FcmPushSender implements PushSender {
  constructor(
    private readonly messaging: Messaging,
    private readonly tokens: PushTokenSource,
    private readonly log: (msg: string, extra?: Record<string, unknown>) => void,
  ) {}

  async send(uid: string, m: PushMessage): Promise<void> {
    try {
      const tokens = await this.tokens.tokensFor(uid);
      if (tokens.length === 0) return;
      const urgent = m.type === 'offer' || m.type === 'assigned';
      const ttlMs = m.type === 'offer' ? Math.max(1_000, Date.parse(m.expiresAt) - Date.now()) : 3_600_000;
      const alert = ALERT[m.type];
      const res = await this.messaging.sendEachForMulticast({
        tokens,
        data: toData(m),
        android: { priority: urgent ? 'high' : 'normal', ttl: ttlMs },
        apns: {
          headers: {
            'apns-priority': urgent ? '10' : '5',
            'apns-push-type': alert ? 'alert' : 'background',
            'apns-expiration': String(Math.floor((Date.now() + ttlMs) / 1000)),
          },
          // Offers are time-sensitive on iOS (shown through Focus); the app needs no background mode for them.
          payload: {
            aps: alert
              ? { alert, sound: 'default', ...(m.type === 'offer' ? { 'interruption-level': 'time-sensitive' } : {}) }
              : { contentAvailable: true },
          },
        },
      });
      if (res.failureCount > 0) this.log('push_partial_failure', { type: m.type, failures: res.failureCount });
    } catch (err) {
      this.log('push_failed', { type: m.type, error: (err as Error).name });
    }
  }
}

/**
 * Device tokens as plan I4's app registers them: Firestore `devices/{uid}_{installId}`
 * `{userId, provider: 'fcm', token, platform, lastSeenAt}` (entity `Device`, owner-written).
 * When the self-hosted `devices` table takes over (push plan), only this class changes.
 */
export class FirestoreTokenSource implements PushTokenSource {
  constructor(private readonly db: Firestore) {}

  async tokensFor(uid: string): Promise<string[]> {
    const snap = await this.db.collection('devices').where('userId', '==', uid).limit(10).get();
    return snap.docs
      .filter((d) => d.get('provider') === 'fcm')
      .map((d) => d.get('token') as unknown)
      .filter((t): t is string => typeof t === 'string' && t.length > 0);
  }
}

/** PUSH=log and tests: records every message. */
export class RecordingPushSender implements PushSender {
  readonly sent: Array<{ uid: string; message: PushMessage }> = [];
  async send(uid: string, message: PushMessage): Promise<void> {
    this.sent.push({ uid, message });
  }
  to(uid: string): PushMessage[] {
    return this.sent.filter((s) => s.uid === uid).map((s) => s.message);
  }
}
```

```ts
// services/dispatch/src/eta/eta.ts
import { estimateEta, type DispatchConfig, type LatLng } from '../domain/core.js';

export interface EtaResult {
  minutes: number;
  /** true: straight-line estimate (Goong unavailable or failed), shown as "ước tính" (spec §10). */
  estimated: boolean;
}

export interface EtaProvider {
  eta(from: LatLng, to: LatLng, cfg: Pick<DispatchConfig, 'eta'>): Promise<EtaResult>;
}

/** Neighbourhood-level label for offers ("Phường Bến Thành, Quận 1"), never the exact address. */
export interface AreaResolver {
  areaOf(point: LatLng): Promise<string | null>;
}

export const estimateProvider: EtaProvider = {
  async eta(from, to, cfg) {
    return { minutes: estimateEta(from, to, cfg).minutes, estimated: true };
  },
};

export const noAreaResolver: AreaResolver = { areaOf: async () => null };

/**
 * Fallback area from the address the customer picked: drop the first segment (house number and
 * street) and keep at most the next two ("12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh" →
 * "Phường Bến Thành, Quận 1"); the city name when nothing is left.
 */
export function areaFromAddress(address: string, cityName: string): string {
  const parts = address.split(',').map((p) => p.trim()).filter((p) => p.length > 0);
  const rest = parts.slice(1, 3);
  return rest.length > 0 ? rest.join(', ') : cityName;
}
```

```ts
// services/dispatch/src/eta/goong.ts
import { estimateEta, type DispatchConfig, type LatLng } from '../domain/core.js';
import type { AreaResolver, EtaProvider, EtaResult } from './eta.js';

type FetchFn = (url: string, init: { signal: AbortSignal }) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

export interface GoongOptions {
  apiKey: string;
  timeoutMs: number;
  fetch?: FetchFn;
  /** Never receives the URL or the key. */
  log?: (msg: string, extra?: Record<string, unknown>) => void;
  baseUrl?: string;
}

const ll = (p: LatLng): string => `${p.lat.toFixed(6)},${p.lng.toFixed(6)}`;

/**
 * Goong Distance Matrix (motorbike) for the accepted photographer only (spec §3.2), at most once a
 * minute per request (the caller gates it). Any failure, timeout or quota error falls back to the
 * straight-line estimate with `estimated: true` (spec §10). The key lives only in the URL and is
 * never logged.
 */
export class GoongEtaProvider implements EtaProvider, AreaResolver {
  private readonly fetch: FetchFn;
  private readonly base: string;

  constructor(private readonly o: GoongOptions) {
    this.fetch = o.fetch ?? ((url, init) => globalThis.fetch(url, init));
    this.base = o.baseUrl ?? 'https://rsapi.goong.io';
  }

  async eta(from: LatLng, to: LatLng, cfg: Pick<DispatchConfig, 'eta'>): Promise<EtaResult> {
    const fallback = (): EtaResult => ({ minutes: estimateEta(from, to, cfg).minutes, estimated: true });
    const url = `${this.base}/DistanceMatrix?origins=${ll(from)}&destinations=${ll(to)}&vehicle=bike&api_key=${encodeURIComponent(this.o.apiKey)}`;
    try {
      const res = await this.fetch(url, { signal: AbortSignal.timeout(this.o.timeoutMs) });
      if (!res.ok) {
        this.o.log?.('goong_eta_http_error', { status: res.status });
        return fallback();
      }
      const body = (await res.json()) as { rows?: Array<{ elements?: Array<{ status?: string; duration?: { value?: number } }> }> };
      const el = body.rows?.[0]?.elements?.[0];
      const seconds = el?.duration?.value;
      if (el?.status !== 'OK' || typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0) {
        this.o.log?.('goong_eta_no_route', {});
        return fallback();
      }
      return { minutes: Math.max(1, Math.ceil(seconds / 60)), estimated: false };
    } catch (err) {
      this.o.log?.('goong_eta_failed', { error: (err as Error).name });
      return fallback();
    }
  }

  async areaOf(point: LatLng): Promise<string | null> {
    const url = `${this.base}/Geocode?latlng=${ll(point)}&api_key=${encodeURIComponent(this.o.apiKey)}`;
    try {
      const res = await this.fetch(url, { signal: AbortSignal.timeout(this.o.timeoutMs) });
      if (!res.ok) return null;
      const body = (await res.json()) as { results?: Array<{ compound?: { commune?: string; district?: string } }> };
      const c = body.results?.[0]?.compound;
      const parts = [c?.commune, c?.district].filter((p): p is string => typeof p === 'string' && p.trim() !== '');
      return parts.length > 0 ? parts.join(', ') : null;
    } catch (err) {
      this.o.log?.('goong_geocode_failed', { error: (err as Error).name });
      return null;
    }
  }
}
```

```ts
// services/dispatch/src/jobs/scheduler.ts
import { Queue, Worker, type ConnectionOptions } from 'bullmq';

/** Durable timers of the service (spec §5: BullMQ delayed jobs in persistent Redis). */
export const JOB_NAMES = [
  'match',
  'offer-expire',
  'search-timeout',
  'payment-timeout',
  'auto-complete',
  'no-show',
  'refund',
] as const;
export type JobName = (typeof JOB_NAMES)[number];

/** Each feature task adds its handlers (src/jobs/handlers.ts); a job without one fails and is retried. */
export type JobHandlers = Partial<Record<JobName, (key: string) => Promise<void>>>;

export interface Scheduler {
  /** Runs handlers[name](key) at `at` (now or past = as soon as possible). Same name+key+at twice = once. */
  schedule(name: JobName, key: string, at: Date): Promise<void>;
}

/** BullMQ job id: no ':' allowed, unique per (name, key, due time). */
export const jobId = (name: JobName, key: string, at: Date): string => `${name}-${key}-${at.getTime()}`;

export class BullScheduler implements Scheduler {
  readonly queue: Queue;

  constructor(
    connection: ConnectionOptions,
    private readonly now: () => Date,
    queueName = 'dispatch',
  ) {
    this.queue = new Queue(queueName, {
      connection,
      defaultJobOptions: { removeOnComplete: true, removeOnFail: 1_000, attempts: 3, backoff: { type: 'exponential', delay: 1_000 } },
    });
  }

  async schedule(name: JobName, key: string, at: Date): Promise<void> {
    const delay = Math.max(0, at.getTime() - this.now().getTime());
    const opts = name === 'refund' ? { attempts: 8, backoff: { type: 'exponential' as const, delay: 30_000 } } : {};
    await this.queue.add(name, { key }, { jobId: jobId(name, key, at), delay, ...opts });
  }

  async close(): Promise<void> {
    await this.queue.close();
  }
}

export function startWorker(connection: ConnectionOptions, handlers: JobHandlers, queueName = 'dispatch', concurrency = 16): Worker {
  return new Worker(
    queueName,
    async (job) => {
      const handler = handlers[job.name as JobName];
      if (!handler) throw new Error(`no handler for job ${job.name}`);
      await handler((job.data as { key: string }).key);
    },
    { connection, concurrency },
  );
}

/** Tests: jobs wait until runDue() with a manual clock; no Redis, no real time. */
export class ManualScheduler implements Scheduler {
  readonly jobs: Array<{ name: JobName; key: string; at: Date; id: string }> = [];
  private readonly seen = new Set<string>();
  handlers: JobHandlers | null = null;

  async schedule(name: JobName, key: string, at: Date): Promise<void> {
    const id = jobId(name, key, at);
    if (this.seen.has(id)) return;
    this.seen.add(id);
    this.jobs.push({ name, key, at, id });
  }

  pending(name?: JobName): Array<{ name: JobName; key: string; at: Date }> {
    return this.jobs.filter((j) => name === undefined || j.name === name);
  }

  /** Runs every job due at `now`, oldest first, including jobs those jobs schedule for ≤ now. */
  async runDue(now: Date): Promise<number> {
    if (!this.handlers) throw new Error('ManualScheduler.handlers is not set');
    let ran = 0;
    for (;;) {
      this.jobs.sort((a, b) => a.at.getTime() - b.at.getTime());
      const i = this.jobs.findIndex((j) => j.at.getTime() <= now.getTime());
      if (i < 0) return ran;
      const [job] = this.jobs.splice(i, 1);
      if (!job) return ran;
      const handler = this.handlers[job.name];
      if (!handler) throw new Error(`no handler for job ${job.name}`);
      await handler(job.key);
      ran++;
      if (ran > 10_000) throw new Error('runDue: runaway job loop');
    }
  }
}
```

```ts
// services/dispatch/src/metrics.ts
/** Tiny in-process timing histograms (matcher run, first offer), read by GET /internal/metrics in load tests. */
export class Metrics {
  private readonly samples = new Map<string, number[]>();
  private readonly cap = 50_000;

  observe(name: string, ms: number): void {
    const list = this.samples.get(name) ?? [];
    if (list.length >= this.cap) list.shift();
    list.push(ms);
    this.samples.set(name, list);
  }

  summary(): Record<string, { count: number; p50: number; p95: number; p99: number; max: number }> {
    const out: Record<string, { count: number; p50: number; p95: number; p99: number; max: number }> = {};
    for (const [name, list] of this.samples) {
      const s = [...list].sort((a, b) => a - b);
      const q = (p: number) => s[Math.min(s.length - 1, Math.floor(p * s.length))] ?? 0;
      out[name] = { count: s.length, p50: q(0.5), p95: q(0.95), p99: q(0.99), max: s[s.length - 1] ?? 0 };
    }
    return out;
  }

  reset(): void {
    this.samples.clear();
  }
}
```

```ts
// services/dispatch/src/redis/client.ts
import { Redis } from 'ioredis';

/** One connection for commands; BullMQ opens its own (it needs maxRetriesPerRequest: null). */
export function createRedis(url: string): Redis {
  return new Redis(url, { maxRetriesPerRequest: 2, enableAutoPipelining: true, lazyConnect: false });
}

export function createBullConnection(url: string): Redis {
  return new Redis(url, { maxRetriesPerRequest: null, enableReadyCheck: false });
}
```

- [ ] **Step 4: Run and see them pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  4 passed | 1 skipped (5)`, `Tests  22 passed | 3 skipped (25)` (the Firestore mirror suite skips without the emulator). (The Goong and FCM tests were run while writing this plan: 9 passed.)

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): FCM sender, Goong ETA and area with estimate fallback, BullMQ and manual schedulers, metrics

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: App, auth, wiring, test harness and the compose services

**Files:**
- Create: `services/dispatch/src/db/database.ts`, `services/dispatch/src/redis/keys.ts`, `services/dispatch/src/deps.ts`, `services/dispatch/src/auth/identity.ts`, `services/dispatch/src/auth/plugin.ts`, `services/dispatch/src/app.ts`, `services/dispatch/src/routes/health.ts`, `services/dispatch/src/wiring.ts`, `services/dispatch/src/server.ts`, `services/dispatch/src/jobs/handlers.ts`, `services/dispatch/test/helpers.ts`, `services/dispatch/test/contract.test.ts`, `services/dispatch/test/health.test.ts`, `services/dispatch/test/auth-drift.test.ts`, `services/dispatch/Dockerfile`, `services/dispatch/Dockerfile.dockerignore`, `.github/workflows/dispatch.yml`
- Modify: `services/api/docker-compose.yml`, `services/api/.env.example`, `services/dispatch/README.md`

**Interfaces:**
- Consumes: everything of Tasks 2–5; `services/api/src/auth/identity.ts` (phase 2 Task 4) as the source of the copied verifier.
- Produces:
  - `interface Database` (Kysely) with `users`, `files`, `user_contacts`, `photographers`, `photographer_contact_numbers`, `photographer_specialties` (read only, columns used here), `payments`, `refunds`, `ledger_entries`, and `dispatch.cities`, `dispatch.instant_packages`, `dispatch.instant_requests`, `dispatch.instant_offers`, `dispatch.photographer_instant_settings`, `dispatch.photographer_reliability`; `type Db`, `type Exec = Kysely<Database> | Transaction<Database>`; `createDb(url, max)`; `ewktPoint(p: LatLng): string`; `detectSpecialties(db): Promise<boolean>`.
  - `keys.online(cityId)`, `presence(uid)`, `facts(uid)`, `offerLock(uid)`, `matchLock(requestId)`, `search(requestId)`, `trip(requestId)`, `locationGate(requestId)`, `etaGate(requestId)`, `typical(cityId)`; `COMPARE_AND_DELETE` (Lua).
  - `interface Deps { db; redis; clock; rng; book; mirror; push; eta; area; gateways; scheduler; metrics; log; hasSpecialties; returnUrlFor(requestId) }`, `interface RouteDeps extends Deps { contract }`.
  - `Principal`, `IdentityVerifier`, `JwksVerifier`, `EmulatorVerifier`, `firebaseVerifier`, `claimsToPrincipal`, `authProviderCode` (copied); `installAuth(app, verifier)`, `principalOf(req)`.
  - `buildApp({ deps, verifier, contract?, metricsEndpoint? }): Promise<FastifyInstance>`; `app.routeTable`; `GET /v1/health` → `200 {"ok":true,"redis":true,"postgres":true}` or 503; `GET /internal/metrics` + `POST /internal/metrics/reset` (only with `metricsEndpoint`, outside `/v1`, refused in production).
  - `wire(config)` → production `Deps`, `BullScheduler`, BullMQ connection, `close()`; `createLogger(level)` (redacts authorization, signatures, api keys).
  - `jobHandlers(deps): JobHandlers` (empty until Task 10).
  - Test helpers: `PROJECT_ID`, `FAKE_SECRET`, `T0`, `testDb()`, `testRedis()`, `testWorld(db, redis, over?)` → `{ deps, clock, scheduler, mirror, push, gateway, runDue(), advance(ms) }`, `emulatorToken(uid)`, `as(uid)`, `testApp(world, opts?)`, `resetAll(db, redis)`, `HCM`, `HN`, `north(p, km)`, `PACKAGES`, `seedCatalog(db)`, `addCustomer(db, uid, opts?)`, `addPhotographer(db, uid, opts?)`, `fixAt(p, at, accuracyM?)`, `paidRequest(app, customer, opts?)`, `online(app, uid, p, at, helpReady?)`.

- [ ] **Step 1: Write the failing tests**

```ts
// services/dispatch/test/helpers.ts
import { Redis } from 'ioredis';
import { sql } from 'kysely';
import pino from 'pino';
import type { FastifyInstance } from 'fastify';

import { buildApp } from '../src/app.js';
import { EmulatorVerifier } from '../src/auth/identity.js';
import { createDb, ewktPoint, type Db } from '../src/db/database.js';
import type { Deps } from '../src/deps.js';
import { defaultBook, manualClock, seededRng, type ConfigBook, type LatLng, type ManualClock } from '../src/domain/core.js';
import { estimateProvider, noAreaResolver, type AreaResolver, type EtaProvider } from '../src/eta/eta.js';
import { jobHandlers } from '../src/jobs/handlers.js';
import { ManualScheduler } from '../src/jobs/scheduler.js';
import { Metrics } from '../src/metrics.js';
import { MemoryMirrorWriter } from '../src/mirror/mirror.js';
import { FakePaymentGateway } from '../src/payments/fake.js';
import { gatewayRegistry } from '../src/payments/gateway.js';
import { RecordingPushSender } from '../src/push/push.js';

export const PROJECT_ID = 'demo-nag-test';
export const FAKE_SECRET = 'fake-secret-for-tests-only';
export const T0 = new Date('2026-10-01T08:00:00.000Z');

export const testDb = (): Db => {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is set by test/global-setup.ts');
  return createDb(url, 8);
};

export const testRedis = (): Redis => {
  const url = process.env.TEST_REDIS_URL;
  if (!url) throw new Error('TEST_REDIS_URL is set by test/global-setup.ts');
  return new Redis(url, { maxRetriesPerRequest: 2 });
};

export interface TestWorld {
  deps: Deps;
  clock: ManualClock;
  scheduler: ManualScheduler;
  mirror: MemoryMirrorWriter;
  push: RecordingPushSender;
  gateway: FakePaymentGateway;
  /** Runs every job due at the manual clock's now. */
  runDue(): Promise<number>;
  /** Advances the clock and runs what became due. */
  advance(ms: number): Promise<void>;
}

export function testWorld(db: Db, redis: Redis, over: { book?: ConfigBook; eta?: EtaProvider; area?: AreaResolver } = {}): TestWorld {
  const clock = manualClock(T0);
  const scheduler = new ManualScheduler();
  const mirror = new MemoryMirrorWriter();
  const push = new RecordingPushSender();
  const gateway = new FakePaymentGateway(FAKE_SECRET);
  const deps: Deps = {
    db, redis, clock, rng: seededRng(1), book: over.book ?? defaultBook(), mirror, push,
    eta: over.eta ?? estimateProvider, area: over.area ?? noAreaResolver, gateways: gatewayRegistry([gateway]),
    scheduler, metrics: new Metrics(), log: pino({ level: 'silent' }), hasSpecialties: false,
    returnUrlFor: (id) => `photobooking://instant/${id}`,
  };
  scheduler.handlers = jobHandlers(deps);
  return {
    deps, clock, scheduler, mirror, push, gateway,
    runDue: () => scheduler.runDue(clock.now()),
    async advance(ms) {
      clock.advance(ms);
      await scheduler.runDue(clock.now());
    },
  };
}

/** What the Firebase Auth emulator issues: an unsigned JWT (same as services/api's helper). */
export function emulatorToken(uid: string): string {
  const now = Math.floor(Date.now() / 1000);
  const enc = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${PROJECT_ID}`, aud: PROJECT_ID, sub: uid, user_id: uid,
    iat: now, auth_time: now, exp: now + 3600, firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

export const as = (uid: string) => ({ authorization: `Bearer ${emulatorToken(uid)}` });

export function testApp(w: TestWorld, opts: { metricsEndpoint?: boolean } = {}): Promise<FastifyInstance> {
  return buildApp({ deps: w.deps, verifier: new EmulatorVerifier({ projectId: PROJECT_ID }), metricsEndpoint: opts.metricsEndpoint });
}

/** Empties every table the service touches and the Redis test database. */
export async function resetAll(db: Db, redis: Redis): Promise<void> {
  await sql`truncate table dispatch.instant_offers, dispatch.instant_requests, dispatch.photographer_reliability,
    dispatch.photographer_instant_settings, dispatch.instant_packages, dispatch.cities,
    ledger_entries, refunds, payout_items, payouts, payout_accounts, payments,
    photographer_contact_numbers, photographers, user_contacts, auth_identities, users, files restart identity cascade`.execute(db);
  await redis.flushdb();
}

/** Ho Chi Minh City centre (Bến Thành) and Hà Nội centre (Hồ Gươm). */
export const HCM: LatLng = { lat: 10.7725, lng: 106.698 };
export const HN: LatLng = { lat: 21.0287, lng: 105.8524 };
/** A point `km` north of `p`. */
export const north = (p: LatLng, km: number): LatLng => ({ lat: p.lat + km / 111.19508, lng: p.lng });

const box = (c: LatLng, d: number) =>
  `SRID=4326;POLYGON((${c.lng - d} ${c.lat - d}, ${c.lng + d} ${c.lat - d}, ${c.lng + d} ${c.lat + d}, ${c.lng - d} ${c.lat + d}, ${c.lng - d} ${c.lat - d}))`;

export const PACKAGES = { p30: '01J9ZP30000000000000000000', p60: '01J9ZP60000000000000000000', p120: '01J9ZP12000000000000000000' } as const;

/** Two active cities, price list v1 (p30 300k, p60 500k, p120 900k), HCM surge 1.20. */
export async function seedCatalog(db: Db): Promise<void> {
  await db
    .insertInto('dispatch.cities')
    .values([
      { id: 'hcm', name: 'Hồ Chí Minh', boundary: box(HCM, 0.3), surge: '1.20', active: true },
      { id: 'hn', name: 'Hà Nội', boundary: box(HN, 0.3), surge: '1.00', active: true },
    ])
    .execute();
  await db
    .insertInto('dispatch.instant_packages')
    .values([
      { id: PACKAGES.p30, code: 'p30', duration_min: 30, photos: 10, price_vnd: 300_000, price_list_version: 1 },
      { id: PACKAGES.p60, code: 'p60', duration_min: 60, photos: 20, price_vnd: 500_000, price_list_version: 1 },
      { id: PACKAGES.p120, code: 'p120', duration_min: 120, photos: 40, price_vnd: 900_000, price_list_version: 1 },
    ])
    .execute();
}

export async function addCustomer(db: Db, uid: string, opts: { phone?: boolean; name?: string } = {}): Promise<void> {
  await db.insertInto('users').values({ id: uid, display_name: opts.name ?? `Khách ${uid}`, role: 'customer' }).execute();
  if (opts.phone ?? true) {
    await db.insertInto('user_contacts').values({ user_id: uid, phone_e164: `+8490${String(Math.abs(hash(uid)) % 10_000_000).padStart(7, '0')}` }).execute();
  }
}

export interface PhotographerOpts {
  verified?: boolean;
  rating?: number;
  reviews?: number;
  helpReady?: boolean;
  acceptedVersion?: number | null;
  onboarding?: boolean;
  phone?: boolean;
}

export async function addPhotographer(db: Db, uid: string, o: PhotographerOpts = {}): Promise<void> {
  await db.insertInto('users').values({ id: uid, display_name: `Thợ ${uid}`, role: 'photographer' }).execute();
  await db
    .insertInto('photographers')
    .values({ user_id: uid, onboarding_complete: o.onboarding ?? true, verified: o.verified ?? true, rating_avg: o.rating ?? 4.8, review_count: o.reviews ?? 20 })
    .execute();
  if (o.phone ?? true) {
    await db.insertInto('photographer_contact_numbers').values({ photographer_id: uid, phone_e164: `+8491${String(Math.abs(hash(uid)) % 10_000_000).padStart(7, '0')}` }).execute();
  }
  const accepted = o.acceptedVersion === undefined ? 1 : o.acceptedVersion;
  await db
    .insertInto('dispatch.photographer_instant_settings')
    .values({ photographer_id: uid, price_list_version_accepted: accepted, help_ready: o.helpReady ?? false, updated_at: T0 })
    .execute();
}

function hash(s: string): number {
  let h = 0;
  for (const ch of s) h = (Math.imul(h, 31) + ch.charCodeAt(0)) | 0;
  return h;
}

export const fixAt = (p: LatLng, at: Date, accuracyM = 15) => ({ lat: p.lat, lng: p.lng, accuracyM, at: at.toISOString() });

/** A request paid with the fake gateway and searching; returns its id. */
export async function paidRequest(
  app: FastifyInstance,
  customer: string,
  o: { at?: LatLng; expand?: boolean; packageId?: string; amount?: number } = {},
): Promise<string> {
  const res = await app.inject({
    method: 'POST', url: '/v1/requests', headers: as(customer),
    payload: {
      packageId: o.packageId ?? PACKAGES.p60, genre: 'portrait', meetPoint: { ...(o.at ?? HCM), address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' },
      expand: o.expand ?? false, expectedAmountVnd: o.amount ?? 600_000, provider: 'fake',
    },
  });
  if (res.statusCode !== 201) throw new Error(`create request: ${res.statusCode} ${res.body}`);
  const id = (res.json() as { requestId: string }).requestId;
  const paid = await app.inject({ method: 'POST', url: `/v1/dev/payments/${id}/succeed`, headers: as(customer) });
  if (paid.statusCode !== 204) throw new Error(`pay: ${paid.statusCode} ${paid.body}`);
  return id;
}

/** Puts a photographer online at `p` through the API. */
export async function online(app: FastifyInstance, uid: string, p: LatLng, at: Date, helpReady?: boolean): Promise<void> {
  const res = await app.inject({ method: 'PUT', url: '/v1/presence', headers: as(uid), payload: { online: true, ...(helpReady === undefined ? {} : { helpReady }), fix: fixAt(p, at) } });
  if (res.statusCode !== 200) throw new Error(`presence ${uid}: ${res.statusCode} ${res.body}`);
}

export { ewktPoint };
```

```ts
// services/dispatch/test/contract.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { loadContract, operations, toFastifySchema } from '../src/contract/openapi.js';
import { API_ERROR_CODES, HTTP_STATUS } from '../src/errors.js';
import { testApp, testDb, testRedis, testWorld } from './helpers.js';

/** Operations whose routes arrive in later tasks; each task removes its own. Empty at the end. */
const PENDING = new Set<string>([
  'listPackages', 'createRequest', 'cancelRequest', 'confirmComplete', 'postLocation', 'arrive',
  'startShoot', 'finishShoot', 'putPresence', 'getInstantSettings', 'putInstantSettings', 'acceptOffer',
  'declineOffer', 'paymentWebhook', 'paymentWebhookQuery', 'devPaymentSucceed',
]);

const contract = loadContract();
const db = testDb();
const redis = testRedis();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp(testWorld(db, redis));
  await app.ready();
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});

describe('dispatch contract (services/dispatch/api/openapi.yaml)', () => {
  it('every operation is routed or still pending (devPaymentSucceed too: the test world uses the fake gateway)', () => {
    for (const op of operations(contract)) {
      const routed = app.hasRoute({ method: op.method, url: op.url });
      if (PENDING.has(op.operationId)) expect(routed, `${op.operationId} is routed now: remove it from PENDING`).toBe(false);
      else expect(routed, `${op.operationId} ${op.method} ${op.path}`).toBe(true);
    }
  });

  it('every /v1 route is in the contract', () => {
    const known = new Set(operations(contract).map((o) => `${o.method} ${o.url}`));
    for (const r of app.routeTable.filter((r) => r.url.startsWith('/v1/'))) expect(known.has(`${r.method} ${r.url}`), `${r.method} ${r.url}`).toBe(true);
  });

  it('the server error codes are exactly the contract ErrorCode enum', () => {
    const enumCodes = (contract.components.schemas.ErrorCode as { enum: string[] }).enum;
    expect([...API_ERROR_CODES].sort()).toEqual([...enumCodes].sort());
    for (const code of API_ERROR_CODES) expect(HTTP_STATUS[code]).toBeGreaterThanOrEqual(400);
  });

  it('nullable becomes JSON Schema and non-schema keys are dropped', () => {
    expect(toFastifySchema({ type: 'integer', nullable: true, description: 'x' })).toEqual({ type: ['integer', 'null'] });
    expect(toFastifySchema({ allOf: [{ $ref: '#/components/schemas/Instant' }], nullable: true })).toEqual({ anyOf: [{ allOf: [{ $ref: 'Instant#' }] }, { type: 'null' }] });
    expect(toFastifySchema({ type: 'integer', format: 'int64', 'x-firestore-path': 'a/b' })).toEqual({ type: 'integer' });
  });
});
```

```ts
// services/dispatch/test/health.test.ts
import type { Redis } from 'ioredis';
import { afterAll, describe, expect, it } from 'vitest';

import { testApp, testDb, testRedis, testWorld } from './helpers.js';

const db = testDb();
const redis = testRedis();
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

describe('GET /v1/health', () => {
  it('is public and reports Redis and PostgreSQL', async () => {
    const app = await testApp(testWorld(db, redis));
    const res = await app.inject({ method: 'GET', url: '/v1/health' });
    expect([res.statusCode, res.json()]).toEqual([200, { ok: true, redis: true, postgres: true }]);
    await app.close();
  });

  it('answers 503 when Redis is down', async () => {
    const down = { ping: async () => { throw new Error('ECONNREFUSED'); } } as unknown as Redis;
    const w = testWorld(db, redis);
    const app = await testApp({ ...w, deps: { ...w.deps, redis: down } });
    const res = await app.inject({ method: 'GET', url: '/v1/health' });
    expect([res.statusCode, res.json()]).toEqual([503, { ok: false, redis: false, postgres: true }]);
    await app.close();
  });
});
```

```ts
// services/dispatch/test/auth-drift.test.ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { EmulatorVerifier } from '../src/auth/identity.js';
import { ApiError } from '../src/errors.js';
import { PROJECT_ID, emulatorToken } from './helpers.js';

const read = (rel: string) => readFileSync(fileURLToPath(new URL(rel, import.meta.url)), 'utf8');
const MARKER = '// ---- copied verbatim below this line ----\n';

describe('Firebase ID token verification is the one of services/api', () => {
  it('the code below the marker is identical to services/api/src/auth/identity.ts', () => {
    const mine = read('../src/auth/identity.ts');
    const theirs = read('../../api/src/auth/identity.ts');
    const body = mine.slice(mine.indexOf(MARKER) + MARKER.length);
    const start = theirs.indexOf('/** Public keys of Firebase ID tokens');
    expect(start).toBeGreaterThan(0);
    expect(body).toBe(theirs.slice(start));
  });

  it('accepts the emulator token of its project and refuses others', async () => {
    const v = new EmulatorVerifier({ projectId: PROJECT_ID });
    expect((await v.verify(emulatorToken('u1'))).uid).toBe('u1');
    await expect(v.verify('not-a-jwt')).rejects.toBeInstanceOf(ApiError);
    await expect(new EmulatorVerifier({ projectId: 'other' }).verify(emulatorToken('u1'))).rejects.toBeInstanceOf(ApiError);
  });
});
```

- [ ] **Step 2: Run and see them fail**

Run: `npm test -- test/contract.test.ts test/health.test.ts test/auth-drift.test.ts`
Expected: FAIL, `Failed to load url ../src/app.js` (and `../src/auth/identity.js`, `../src/db/database.js`).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/db/database.ts
import { Kysely, PostgresDialect, type ColumnType, type Transaction } from 'kysely';
import pg from 'pg';

import type { Genre, InstantRequestStatus, LatLng, OfferOutcome, PackageCode, PaymentProvider } from '../domain/core.js';

// Same parsers as services/api (phase 2 Task 1): int8 → safe JS number, date stays yyyy-MM-dd.
pg.types.setTypeParser(20, (v: string) => {
  const n = Number(v);
  if (!Number.isSafeInteger(n)) throw new RangeError(`int8 value ${v} exceeds Number.MAX_SAFE_INTEGER`);
  return n;
});
pg.types.setTypeParser(1082, (v: string) => v);

type CreatedAt = ColumnType<Date, Date | string | undefined, never>;
type UpdatedAt = ColumnType<Date, Date | string | undefined, Date | string>;
type Opt<T> = ColumnType<T | null, T | null | undefined, T | null>;
type Def<T> = ColumnType<T, T | undefined, T>;
/** PostGIS geography: written as EWKT text (`SRID=4326;POINT(lng lat)`), read with ST_X/ST_Y. */
type Geography = ColumnType<string, string, string>;
/** numeric: pg returns text. */
type Numeric = ColumnType<string, number | string, number | string>;
type DefNumeric = ColumnType<string, number | string | undefined, number | string>;


// ---- phase 2 tables this service reads (columns used here only; DDL in relational-schema.md §2.1–2.2) ----
export interface UsersTable {
  id: string;
  display_name: Def<string>;
  avatar_file_id: Opt<string>;
  role: Opt<'customer' | 'photographer'>;
  deleted_at: Opt<Date>;
}
export interface FilesTable {
  id: string;
  storage_provider: string;
  storage_key: string;
}
export interface UserContactsTable {
  user_id: string;
  phone_e164: string;
}
export interface PhotographersTable {
  user_id: string;
  verified: Def<boolean>;
  onboarding_complete: Def<boolean>;
  rating_avg: DefNumeric;
  review_count: Def<number>;
  completed_count: Def<number>;
}
export interface PhotographerContactNumbersTable {
  photographer_id: string;
  phone_e164: string;
}
export interface PhotographerSpecialtiesTable {
  photographer_id: string;
  specialty_id: string;
  level: number;
}

// ---- relational-schema.md §2.4 money tables (shared; this service writes subject_type 'instant_request') ----
export type PaymentStatus = 'created' | 'paid' | 'failed' | 'refunded' | 'partially_refunded';
export type EscrowStatus = 'held' | 'released' | 'paid_out' | 'partially_refunded' | 'refunded' | 'disputed';
export type LedgerEntryType =
  | 'deposit_received' | 'ticket_received' | 'refund_issued' | 'escrow_released' | 'payout_paid' | 'fee_charged' | 'adjustment';

export interface PaymentsTable {
  id: string;
  subject_type: 'booking' | 'event_registration' | 'instant_request';
  subject_id: string;
  payee_id: Opt<string>;
  provider: PaymentProvider;
  amount: number;
  currency: Def<string>;
  status: PaymentStatus;
  escrow_status: Def<EscrowStatus>;
  release_after: Opt<Date>;
  released_at: Opt<Date>;
  provider_ref: Opt<string>;
  raw: Opt<unknown>;
  idempotency_key: string;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}
export interface RefundsTable {
  id: string;
  payment_id: string;
  amount: number;
  percent: Opt<number>;
  status: 'pending' | 'done' | 'failed';
  manual: Def<boolean>;
  created_at: CreatedAt;
}
export interface LedgerEntriesTable {
  id: string;
  type: LedgerEntryType;
  payment_id: Opt<string>;
  refund_id: Opt<string>;
  payout_id: Opt<string>;
  account_owner_id: Opt<string>;
  amount: number;
  currency: Def<string>;
  note: Opt<string>;
  at: ColumnType<Date, Date | string | undefined, never>;
}

// ---- relational-schema.md §2.8 (schema dispatch) ----
export interface CitiesTable {
  id: string;
  name: string;
  boundary: Geography;
  surge: DefNumeric;
  active: Def<boolean>;
}
export interface InstantPackagesTable {
  id: string;
  code: PackageCode;
  duration_min: number;
  photos: number;
  price_vnd: number;
  price_list_version: number;
  active: Def<boolean>;
}
export interface InstantRequestsTable {
  id: string;
  customer_id: string;
  package_id: string;
  city_id: string;
  genre: Genre;
  meet_point: Geography;
  meet_address: string;
  note: Opt<string>;
  expand: Def<boolean>;
  amount_vnd: number;
  payout_vnd: number;
  status: InstantRequestStatus;
  photographer_id: Opt<string>;
  round: Def<1 | 2>;
  requested_at: Date;
  assigned_at: Opt<Date>;
  arrived_at: Opt<Date>;
  started_at: Opt<Date>;
  finished_at: Opt<Date>;
  completed_at: Opt<Date>;
  cancelled_at: Opt<Date>;
  cancel_reason: Opt<string>;
  version: Def<number>;
}
export interface InstantOffersTable {
  id: string;
  request_id: string;
  photographer_id: string;
  round: 1 | 2;
  score: Numeric;
  reasons: ColumnType<unknown, string, string>;
  offered_at: Date;
  expires_at: Date;
  outcome: OfferOutcome;
  decided_at: Opt<Date>;
}
export interface PhotographerInstantSettingsTable {
  photographer_id: string;
  price_list_version_accepted: Opt<number>;
  help_ready: Def<boolean>;
  home_city_id: Opt<string>;
  updated_at: Date;
}
export interface PhotographerReliabilityTable {
  photographer_id: string;
  offers: Def<number>;
  accepted: Def<number>;
  cancelled: Def<number>;
  no_show: Def<number>;
  updated_at: Date;
}

export interface Database {
  users: UsersTable;
  files: FilesTable;
  user_contacts: UserContactsTable;
  photographers: PhotographersTable;
  photographer_contact_numbers: PhotographerContactNumbersTable;
  photographer_specialties: PhotographerSpecialtiesTable;
  payments: PaymentsTable;
  refunds: RefundsTable;
  ledger_entries: LedgerEntriesTable;
  'dispatch.cities': CitiesTable;
  'dispatch.instant_packages': InstantPackagesTable;
  'dispatch.instant_requests': InstantRequestsTable;
  'dispatch.instant_offers': InstantOffersTable;
  'dispatch.photographer_instant_settings': PhotographerInstantSettingsTable;
  'dispatch.photographer_reliability': PhotographerReliabilityTable;
}

export type Db = Kysely<Database>;
/** A connection or an open transaction: queries that must also run inside one take this. */
export type Exec = Kysely<Database> | Transaction<Database>;

export function createDb(databaseUrl: string, max: number): Db {
  return new Kysely<Database>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({ connectionString: databaseUrl, max, idleTimeoutMillis: 30_000, connectionTimeoutMillis: 2_000 }),
    }),
  });
}


/** EWKT for parameters bound to geography columns (`SRID=4326;POINT(lng lat)`). */
export const ewktPoint = (p: LatLng): string => `SRID=4326;POINT(${p.lng} ${p.lat})`;

/** Is photographer_specialties there (phase 2's "Profile, rest" plan creates it)? Checked once at boot. */
export async function detectSpecialties(db: Db): Promise<boolean> {
  const r = await db
    .selectNoFrom((eb) => eb.fn<string | null>('to_regclass', [eb.val('public.photographer_specialties')]).as('t'))
    .executeTakeFirst();
  return r?.t !== null && r?.t !== undefined;
}
```

```ts
// services/dispatch/src/redis/keys.ts
/** Every Redis key of the service (spec §5). TTLs are set where the key is written. */
export const keys = {
  /** GEO set of online photographers of a city (GEOADD/GEOSEARCH). Members outlive presence; stale ones are pruned. */
  online: (cityId: string) => `online:${cityId}`,
  /** Hash {cityId, lat, lng, accuracyM, at, helpReady}; PX = presence TTL (10 min). Gone = offline. */
  presence: (uid: string) => `presence:${uid}`,
  /** JSON PhotographerFacts cached for the matcher; same TTL as presence. */
  facts: (uid: string) => `pfacts:${uid}`,
  /** Value = offerId; SET NX PX offerTtl: at most one open offer per photographer. */
  offerLock: (uid: string) => `offerlock:${uid}`,
  /** SET NX PX: one matcher run per request at a time. */
  matchLock: (requestId: string) => `matchlock:${requestId}`,
  /** Hash: SearchState + area + cityName of a searching request (no TTL; deleted when the search ends). */
  search: (requestId: string) => `search:${requestId}`,
  /** Hash {etaMinutes, etaEstimated} of an assigned request (deleted when it ends). */
  trip: (requestId: string) => `trip:${requestId}`,
  /** SET NX PX 5000: location rate limit (spec §6). */
  locationGate: (requestId: string) => `locgate:${requestId}`,
  /** SET NX PX 60000: Goong at most once a minute (spec §5). */
  etaGate: (requestId: string) => `etagate:${requestId}`,
  /** JSON {v}: typicalMatchMinutes of a city, PX 10 minutes. */
  typical: (cityId: string) => `typical:${cityId}`,
} as const;

/** Deletes a key only if it still holds `value` (releasing an offer lock we own). */
export const COMPARE_AND_DELETE = `
if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end`;
```

```ts
// services/dispatch/src/deps.ts
import type { Redis } from 'ioredis';
import type { Logger } from 'pino';

import type { Contract } from './contract/openapi.js';
import type { Db } from './db/database.js';
import type { Clock, ConfigBook, Rng } from './domain/core.js';
import type { AreaResolver, EtaProvider } from './eta/eta.js';
import type { Scheduler } from './jobs/scheduler.js';
import type { Metrics } from './metrics.js';
import type { MirrorWriter } from './mirror/mirror.js';
import type { PaymentGateways } from './payments/gateway.js';
import type { PushSender } from './push/push.js';

/** Everything the use cases need; tests swap any port for a fake. */
export interface Deps {
  db: Db;
  redis: Redis;
  clock: Clock;
  rng: Rng;
  book: ConfigBook;
  mirror: MirrorWriter;
  push: PushSender;
  eta: EtaProvider;
  area: AreaResolver;
  gateways: PaymentGateways;
  scheduler: Scheduler;
  metrics: Metrics;
  log: Logger;
  /** photographer_specialties exists (profile plan applied); false → genreMatch uses "not enough data". */
  hasSpecialties: boolean;
  /** App deep link the payment provider returns to. */
  returnUrlFor(requestId: string): string;
}

export interface RouteDeps extends Deps {
  contract: Contract;
}
```

`src/auth/identity.ts` is phase 2's file with a different import header. Copy `services/api/src/auth/identity.ts` from the line `/** Public keys of Firebase ID tokens …` to the end, below the marker line, so it reads:

```ts
// services/dispatch/src/auth/identity.ts
// Copied from services/api/src/auth/identity.ts (backend phase 2, Task 4): the same verification of
// Firebase ID tokens (Google's securetoken JWKS, or the Auth emulator's unsigned tokens in local dev).
// Only the import header differs; test/auth-drift.test.ts fails if the code below the marker drifts.
import {
  createRemoteJWKSet,
  decodeJwt,
  decodeProtectedHeader,
  jwtVerify,
  type JWTPayload,
  type JWTVerifyGetKey,
} from 'jose';

import type { Clock } from '../domain/core.js';
import { ApiError } from '../errors.js';
import { isValidId } from '../ids.js';

type AuthProvider = 'password' | 'google' | 'facebook' | 'apple' | 'oidc';

// ---- copied verbatim below this line ----
/** Public keys of Firebase ID tokens (the IdentityProvider port, data-model README §3). */
export const FIREBASE_JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

export interface Principal {
  /** = users.id (the Firebase uid today). */
  uid: string;
  /** Firebase `sign_in_provider`, e.g. google.com, facebook.com, password. */
  signInProvider: string;
  /** The subject at that provider, kept in auth_identities for the IdP switch (README §6 step 5). */
  providerSubject: string;
  email: string | null;
}

export interface IdentityVerifier {
  /** Throws ApiError('unauthenticated'). */
  verify(token: string): Promise<Principal>;
}

const issuerFor = (projectId: string): string => `https://securetoken.google.com/${projectId}`;

export function claimsToPrincipal(p: JWTPayload): Principal {
  const uid = p.sub;
  if (!isValidId(uid)) throw new ApiError('unauthenticated', 'token subject is not a valid id');
  const firebase = (typeof p.firebase === 'object' && p.firebase !== null ? p.firebase : {}) as {
    sign_in_provider?: unknown;
    identities?: Record<string, unknown>;
  };
  const signInProvider = typeof firebase.sign_in_provider === 'string' ? firebase.sign_in_provider : 'custom';
  const ids = firebase.identities?.[signInProvider];
  const first = Array.isArray(ids) && typeof ids[0] === 'string' ? ids[0] : null;
  return {
    uid,
    signInProvider,
    providerSubject: signInProvider === 'password' || first === null ? uid : first,
    email: typeof p.email === 'string' ? p.email : null,
  };
}

export function authProviderCode(signInProvider: string): AuthProvider {
  switch (signInProvider) {
    case 'password':
      return 'password';
    case 'google.com':
      return 'google';
    case 'facebook.com':
      return 'facebook';
    case 'apple.com':
      return 'apple';
    default:
      return 'oidc';
  }
}

/** Verifies RS256 tokens of one Firebase project against a JWKS (remote in production). */
export class JwksVerifier implements IdentityVerifier {
  constructor(private readonly opts: { jwks: JWTVerifyGetKey; projectId: string; clock?: Clock }) {}

  async verify(token: string): Promise<Principal> {
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(token, this.opts.jwks, {
        issuer: issuerFor(this.opts.projectId),
        audience: this.opts.projectId,
        algorithms: ['RS256'],
        currentDate: this.opts.clock?.now(),
      }));
    } catch {
      throw new ApiError('unauthenticated', 'invalid or expired token');
    }
    return claimsToPrincipal(payload);
  }
}

export function firebaseVerifier(projectId: string): JwksVerifier {
  // createRemoteJWKSet caches keys and refetches only on an unknown kid.
  return new JwksVerifier({ jwks: createRemoteJWKSet(new URL(FIREBASE_JWKS_URL)), projectId });
}

/**
 * Accepts the Firebase Auth emulator's unsigned tokens (alg "none") for one project.
 * loadConfig refuses this mode when NODE_ENV=production.
 */
export class EmulatorVerifier implements IdentityVerifier {
  constructor(private readonly opts: { projectId: string; clock?: Clock }) {}

  async verify(token: string): Promise<Principal> {
    let alg: unknown;
    let payload: JWTPayload;
    try {
      alg = decodeProtectedHeader(token).alg;
      payload = decodeJwt(token);
    } catch {
      throw new ApiError('unauthenticated', 'invalid token');
    }
    const now = Math.floor((this.opts.clock?.now() ?? new Date()).getTime() / 1000);
    if (
      alg !== 'none' ||
      payload.iss !== issuerFor(this.opts.projectId) ||
      payload.aud !== this.opts.projectId ||
      typeof payload.exp !== 'number' ||
      payload.exp <= now
    ) {
      throw new ApiError('unauthenticated', 'invalid or expired emulator token');
    }
    return claimsToPrincipal(payload);
  }
}
```

(If phase 2's final file differs from this copy below the marker, keep phase 2's version: the drift test compares the two.)

```ts
// services/dispatch/src/auth/plugin.ts
import type { FastifyInstance, FastifyRequest } from 'fastify';

import { ApiError } from '../errors.js';
import type { IdentityVerifier, Principal } from './identity.js';

declare module 'fastify' {
  interface FastifyRequest {
    principal: Principal | null;
  }
  interface FastifyContextConfig {
    /** Route needs no bearer token (health, provider webhooks, internal metrics). */
    public?: boolean;
  }
  interface FastifyInstance {
    routeTable: Array<{ method: string; url: string }>;
  }
}

/** Same hook as services/api: every route needs a bearer token unless `config.public`. */
export function installAuth(app: FastifyInstance, verifier: IdentityVerifier): void {
  app.decorateRequest('principal', null);
  app.addHook('onRequest', async (req) => {
    if (req.is404 || req.routeOptions.config.public === true) return;
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) throw new ApiError('unauthenticated', 'missing bearer token');
    req.principal = await verifier.verify(header.slice('Bearer '.length).trim());
  });
}

export function principalOf(req: FastifyRequest): Principal {
  if (!req.principal) throw new ApiError('unauthenticated', 'missing bearer token');
  return req.principal;
}
```

```ts
// services/dispatch/src/routes/health.ts
import type { FastifyInstance } from 'fastify';
import { sql } from 'kysely';

import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';

/** GET /v1/health: public; 503 unless both Redis and PostgreSQL answer. */
export function registerHealthRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route({
    ...route(deps.contract, 'health'),
    config: { public: true },
    handler: async (_req, reply) => {
      const [redis, postgres] = await Promise.all([
        deps.redis.ping().then((p) => p === 'PONG', () => false),
        sql`select 1`.execute(deps.db).then(() => true, () => false),
      ]);
      return reply.status(redis && postgres ? 200 : 503).send({ ok: redis && postgres, redis, postgres });
    },
  });
}
```

```ts
// services/dispatch/src/app.ts
import Fastify, { type FastifyBaseLogger, type FastifyInstance } from 'fastify';

import type { IdentityVerifier } from './auth/identity.js';
import { installAuth } from './auth/plugin.js';
import { loadContract, registerContractSchemas, type Contract } from './contract/openapi.js';
import type { Deps, RouteDeps } from './deps.js';
import { installErrorHandling } from './errors.js';
import { registerHealthRoutes } from './routes/health.js';

export interface AppOptions {
  deps: Deps;
  verifier: IdentityVerifier;
  contract?: Contract;
  /** GET /internal/metrics (load test only; refused in production by loadConfig). */
  metricsEndpoint?: boolean;
}

export async function buildApp(o: AppOptions): Promise<FastifyInstance> {
  const app = Fastify({
    // pino's Logger is a FastifyBaseLogger; the cast keeps FastifyInstance at its default generics.
    loggerInstance: o.deps.log as FastifyBaseLogger,
    keepAliveTimeout: 65_000,
    bodyLimit: 16 * 1024,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } },
  });
  const routeTable: Array<{ method: string; url: string }> = [];
  app.decorate('routeTable', routeTable);
  app.addHook('onRoute', (r) => {
    for (const method of [r.method].flat()) if (method !== 'HEAD') routeTable.push({ method, url: r.url });
  });
  const contract = o.contract ?? loadContract();
  registerContractSchemas(app, contract);
  installErrorHandling(app);
  installAuth(app, o.verifier);
  const deps: RouteDeps = { ...o.deps, contract };
  registerHealthRoutes(app, deps);
  if (o.metricsEndpoint) {
    app.get('/internal/metrics', { config: { public: true } }, async () => o.deps.metrics.summary());
    app.post('/internal/metrics/reset', { config: { public: true } }, async () => {
      o.deps.metrics.reset();
      return { ok: true };
    });
  }
  return app;
}
```

```ts
// services/dispatch/src/jobs/handlers.ts
import type { Deps } from '../deps.js';
import type { JobHandlers } from './scheduler.js';

/** Timer handlers by job name. Each feature task adds its own; a job without a handler fails and BullMQ retries it. */
export function jobHandlers(_deps: Deps): JobHandlers {
  return {};
}
```

```ts
// services/dispatch/src/wiring.ts
import { initializeApp, type App } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import pino, { type Logger } from 'pino';

import type { ServiceConfig } from './config.js';
import { createDb, detectSpecialties } from './db/database.js';
import type { Deps } from './deps.js';
import { systemClock, systemRng } from './domain/core.js';
import { estimateProvider, noAreaResolver } from './eta/eta.js';
import { GoongEtaProvider } from './eta/goong.js';
import { BullScheduler } from './jobs/scheduler.js';
import { Metrics } from './metrics.js';
import { FirestoreMirrorWriter } from './mirror/firestore.js';
import { MemoryMirrorWriter } from './mirror/mirror.js';
import { buildGateways } from './payments/registry.js';
import { FcmPushSender, FirestoreTokenSource, RecordingPushSender } from './push/push.js';
import { createBullConnection, createRedis } from './redis/client.js';

/** Logs never carry tokens, coordinates of a fix, or the Goong key (it only lives in outgoing URLs). */
export function createLogger(level: string): Logger {
  return pino({ level, redact: ['req.headers.authorization', 'req.headers["x-fake-signature"]', '*.apiKey', '*.api_key'] });
}

export async function wire(config: ServiceConfig): Promise<{ deps: Deps; scheduler: BullScheduler; bullConnection: ReturnType<typeof createBullConnection>; close(): Promise<void> }> {
  const log = createLogger(config.logLevel);
  const db = createDb(config.databaseUrl, config.dbPoolMax);
  const redis = createRedis(config.redisUrl);
  const bullConnection = createBullConnection(config.redisUrl);
  const scheduler = new BullScheduler(bullConnection, () => systemClock.now());
  let firebase: App | null = null;
  const needFirebase = config.mirror === 'firestore' || config.push === 'fcm';
  if (needFirebase) firebase = initializeApp({ projectId: config.firebaseProjectId }, 'dispatch');
  const firestore = firebase ? getFirestore(firebase) : null;
  const goong = config.goongApiKey
    ? new GoongEtaProvider({ apiKey: config.goongApiKey, timeoutMs: config.goongTimeoutMs, log: (msg, extra) => log.warn(extra ?? {}, msg) })
    : null;
  const deps: Deps = {
    db,
    redis,
    clock: systemClock,
    rng: systemRng,
    book: config.book,
    mirror: config.mirror === 'firestore' && firestore ? new FirestoreMirrorWriter(firestore) : new MemoryMirrorWriter(),
    push:
      config.push === 'fcm' && firebase && firestore
        ? new FcmPushSender(getMessaging(firebase), new FirestoreTokenSource(firestore), (msg, extra) => log.warn(extra ?? {}, msg))
        : new RecordingPushSender(),
    eta: goong ?? estimateProvider,
    area: goong ?? noAreaResolver,
    gateways: buildGateways(config),
    scheduler,
    metrics: new Metrics(),
    log,
    hasSpecialties: await detectSpecialties(db),
    returnUrlFor: (requestId) => `photobooking://instant/${requestId}`,
  };
  return {
    deps,
    scheduler,
    bullConnection,
    async close() {
      await scheduler.close();
      redis.disconnect();
      bullConnection.disconnect();
      await db.destroy();
    },
  };
}
```

```ts
// services/dispatch/src/server.ts
import { buildApp } from './app.js';
import { EmulatorVerifier, firebaseVerifier } from './auth/identity.js';
import { loadConfig } from './config.js';
import { jobHandlers } from './jobs/handlers.js';
import { startWorker } from './jobs/scheduler.js';
import { wire } from './wiring.js';

const config = loadConfig();
const w = await wire(config);
const verifier =
  config.authMode === 'firebase' ? firebaseVerifier(config.firebaseProjectId) : new EmulatorVerifier({ projectId: config.firebaseProjectId });

const worker = config.role === 'api' ? null : startWorker(w.bullConnection, jobHandlers(w.deps));
const app = config.role === 'worker' ? null : await buildApp({ deps: w.deps, verifier, metricsEndpoint: config.metricsEndpoint });

async function shutdown(): Promise<void> {
  await app?.close();
  await worker?.close();
  await w.close();
}
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    void shutdown().then(() => process.exit(0));
  });
}
if (app) await app.listen({ port: config.port, host: config.host });
```

```dockerfile
# services/dispatch/Dockerfile
# syntax=docker/dockerfile:1.7
# Build context is the repository root (see services/api/docker-compose.yml).
FROM node:22.11.0-alpine3.20 AS build
WORKDIR /repo/services/dispatch
COPY services/dispatch/package.json services/dispatch/package-lock.json ./
RUN npm ci
COPY packages/dispatch-core/ /repo/packages/dispatch-core/
COPY services/dispatch/ ./
RUN npm run build

FROM node:22.11.0-alpine3.20
WORKDIR /app
ENV NODE_ENV=production
COPY services/dispatch/package.json services/dispatch/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /repo/services/dispatch/dist ./dist
COPY services/dispatch/migrations ./migrations
COPY services/dispatch/api ./api
ENV MIGRATIONS_DIR=/app/migrations
ENV CONTRACT_PATH=/app/api/openapi.yaml
USER node
EXPOSE 8090
CMD ["node", "dist/server.js"]
```

```gitignore
# services/dispatch/Dockerfile.dockerignore  (BuildKit reads <Dockerfile>.dockerignore next to the Dockerfile)
*
!services/dispatch/package.json
!services/dispatch/package-lock.json
!services/dispatch/tsconfig.json
!services/dispatch/src/**
!services/dispatch/api/**
!services/dispatch/migrations/**
!packages/dispatch-core/src/**
!packages/dispatch-core/package.json
```

```yaml
# .github/workflows/dispatch.yml
name: dispatch
on:
  push:
    branches: [flutter-rewrite, develop, main]
  pull_request:
    paths:
      - 'services/dispatch/**'
      - 'packages/dispatch-core/**'
      - 'services/api/migrations/**'
      - 'app_flutter/firebase/firestore.rules'
      - '.github/workflows/dispatch.yml'
jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/dispatch
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
          cache-dependency-path: services/dispatch/package-lock.json
      - run: npm ci
      - name: Generated types match the contract
        run: npm run gen:types && git diff --exit-code src/generated/api.ts
      - run: npm run typecheck
      - run: npm run build
      - run: npm test
```

In `services/api/docker-compose.yml`:

1. Replace `    image: postgres:16.4-alpine` (service `db`) with `    image: postgis/postgis:16-3.4-alpine` (same PostgreSQL 16 major; adds PostGIS for the `dispatch` schema). If a `db-data` volume already exists from phase 2, it keeps working: PostGIS is only installed into the database by the dispatch migration (`create extension if not exists postgis`).
2. Add below the `x-api-env` anchor:

```yaml
x-dispatch-build: &dispatch-build
  context: ../..
  dockerfile: services/dispatch/Dockerfile

x-dispatch-env: &dispatch-env
  DATABASE_URL: postgres://${POSTGRES_USER:-nag}:${POSTGRES_PASSWORD:-nag_local_only}@db:5432/${POSTGRES_DB:-nag}
  REDIS_URL: redis://redis:6379
  NODE_ENV: ${NODE_ENV:-development}
  PORT: "8090"
  HOST: 0.0.0.0
  DB_POOL_MAX: ${DB_POOL_MAX:-10}
  AUTH_MODE: ${AUTH_MODE:-firebase-emulator}
  FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:-demo-nag}
  LOG_LEVEL: ${LOG_LEVEL:-info}
  PAYMENTS: ${DISPATCH_PAYMENTS:-fake}
  FAKE_PAYMENT_SECRET: ${FAKE_PAYMENT_SECRET:-fake-secret-for-local-dev-only}
  MIRROR: ${DISPATCH_MIRROR:-memory}
  FIRESTORE_EMULATOR_HOST: ${FIRESTORE_EMULATOR_HOST:-host.docker.internal:8080}
  PUSH: ${DISPATCH_PUSH:-log}
  GOONG_API_KEY: ${GOONG_API_KEY:-}
  METRICS_ENDPOINT: ${DISPATCH_METRICS:-true}
```

3. Add the services (after `api`):

```yaml
  redis:
    image: redis:7.4-alpine
    # AOF: BullMQ timers and presence survive a restart (spec §10).
    command: ["redis-server", "--appendonly", "yes", "--appendfsync", "everysec"]
    ports: ["${REDIS_PORT:-6380}:6379"]
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 2s
      timeout: 3s
      retries: 30

  dispatch-migrate:
    build: *dispatch-build
    image: nag-dispatch:local
    command: ["node", "dist/db/migrate-cli.js", "up"]
    environment: *dispatch-env
    depends_on:
      migrate: { condition: service_completed_successfully }

  dispatch:
    build: *dispatch-build
    image: nag-dispatch:local
    environment: *dispatch-env
    ports: ["${DISPATCH_PORT:-8090}:8090"]
    extra_hosts: ["host.docker.internal:host-gateway"]
    depends_on:
      dispatch-migrate: { condition: service_completed_successfully }
      redis: { condition: service_healthy }
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8090/v1/health || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 12
```

4. Under `volumes:` add `  redis-data:`.

In `services/api/.env.example`, append:

```bash
# Dispatch service (Chụp ngay), see services/dispatch/README.md
REDIS_PORT=6380
DISPATCH_PORT=8090
DISPATCH_PAYMENTS=fake
DISPATCH_MIRROR=memory
DISPATCH_PUSH=log
# Leave empty locally (straight-line ETA estimate). Never commit a real key.
GOONG_API_KEY=
```

Append to `services/dispatch/README.md`:

````markdown
## Chạy local

Dịch vụ chạy trong Docker Compose của backend giai đoạn 2 (`services/api/docker-compose.yml`): PostgreSQL 16 + PostGIS (schema `dispatch`), Redis 7 (AOF), `dispatch-migrate`, `dispatch` ở cổng 8090.

```bash
cd services/api
docker compose up --build -d                        # db, redis, migrate, api, dispatch-migrate, dispatch
docker compose run --rm dispatch node dist/tools/seed-dev.js   # 3 thành phố + bảng giá v1 (chỉ để dev)
curl -s localhost:8090/v1/health                    # {"ok":true,"redis":true,"postgres":true}

cd ../dispatch
npm ci && npm test                                  # cần Docker (Testcontainers: PostGIS + Redis)
npm run test:mirror                                 # FirestoreMirrorWriter trên Firestore emulator
```

Mặc định local: `PAYMENTS=fake` (có `POST /v1/dev/payments/{id}/succeed`), `MIRROR=memory`, `PUSH=log`, không có khoá Goong (ETA ước tính). Để app thấy bản sao realtime, chạy Firestore emulator (backend giai đoạn 1) và đặt `DISPATCH_MIRROR=firestore`.
````

- [ ] **Step 4: Run and see them pass**

Run: `npm run typecheck && npm test && npm run build`
Expected: clean; `Test Files  7 passed | 1 skipped (8)`, `Tests  30 passed | 3 skipped (33)` (the Firestore mirror suite skips without the emulator); `dist/server.js` and `dist/db/migrate-cli.js` written. If `auth-drift` fails, phase 2 changed its verifier: copy its new code below the marker.

- [ ] **Step 5: Bring the stack up**

```bash
cd services/api
docker compose up --build -d
curl -s localhost:8090/v1/health
curl -s localhost:8090/v1/nope
docker compose down
```

Expected: `{"ok":true,"redis":true,"postgres":true}`, then `{"code":"not_found","message":"no such route","requestId":"req-…"}`.

- [ ] **Step 6: Commit**

```bash
git add services/dispatch services/api/docker-compose.yml services/api/.env.example .github/workflows/dispatch.yml
git commit -m "feat(dispatch): app factory, Firebase token auth, wiring, test harness and compose services (PostGIS, Redis, dispatch)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Migrations: shared money tables and the `dispatch` schema

**Files:**
- Create: `services/api/migrations/1790899100001_money_tables.sql`, `services/dispatch/migrations/1790899200001_dispatch_schema.sql`, `services/dispatch/test/migrations.test.ts`
- Modify: `services/dispatch/test/global-setup.ts`, `services/api/test/migrations.test.ts`

**Interfaces:**
- Consumes: `migrate`, `migrateAll` (Task 2); helpers (Task 6); `relational-schema.md` §2.4 and §2.8 after Task 1.
- Produces: tables `payments`, `refunds`, `payout_accounts`, `payouts`, `payout_items`, `ledger_entries` (public, api history `pgmigrations`) and `dispatch.cities`, `instant_packages`, `instant_requests`, `instant_offers`, `photographer_instant_settings`, `photographer_reliability` with every column, check, unique, index and FK of §2.8 (history `pgmigrations_dispatch`).

- [ ] **Step 1: Check whether the money tables exist already**

Run (repo root): `grep -l "create table payments" services/api/migrations/*.sql`
- No output: create `services/api/migrations/1790899100001_money_tables.sql` in Step 4 as written.
- A file is listed (phase 2's payments plan landed first): do **not** create the money migration; instead create `services/api/migrations/1790899100001_payments_fake_provider.sql` with

```sql
-- relational-schema.md §2.4 after plan I3 Task 1: provider 'fake' (local and test only).
-- Up Migration
alter table payments drop constraint payments_provider_check;
alter table payments add constraint payments_provider_check check (provider in ('momo','vnpay','fake'));
-- Down Migration
alter table payments drop constraint payments_provider_check;
alter table payments add constraint payments_provider_check check (provider in ('momo','vnpay'));
```

and skip the `services/api/test/migrations.test.ts` edit below (that plan already lists the tables).

- [ ] **Step 2: Write the failing test**

```ts
// services/dispatch/test/migrations.test.ts
import pg from 'pg';
import { sql } from 'kysely';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { API_MIGRATIONS_DIR, migrate, migrateAll } from '../src/db/migrate.js';
import { HCM, T0, addCustomer, addPhotographer, ewktPoint, resetAll, seedCatalog, testDb, testRedis, PACKAGES } from './helpers.js';

/** relational-schema.md §2.8, columns in DDL order. */
const EXPECTED: Record<string, string[]> = {
  cities: ['id', 'name', 'boundary', 'surge', 'active'],
  instant_offers: ['id', 'request_id', 'photographer_id', 'round', 'score', 'reasons', 'offered_at', 'expires_at', 'outcome', 'decided_at'],
  instant_packages: ['id', 'code', 'duration_min', 'photos', 'price_vnd', 'price_list_version', 'active'],
  instant_requests: [
    'id', 'customer_id', 'package_id', 'city_id', 'genre', 'meet_point', 'meet_address', 'note', 'expand', 'amount_vnd',
    'payout_vnd', 'status', 'photographer_id', 'round', 'requested_at', 'assigned_at', 'arrived_at', 'started_at',
    'finished_at', 'completed_at', 'cancelled_at', 'cancel_reason', 'version',
  ],
  photographer_instant_settings: ['photographer_id', 'price_list_version_accepted', 'help_ready', 'home_city_id', 'updated_at'],
  photographer_reliability: ['photographer_id', 'offers', 'accepted', 'cancelled', 'no_show', 'updated_at'],
};

async function withClient<T>(url: string, f: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: url });
  await c.connect();
  try {
    return await f(c);
  } finally {
    await c.end();
  }
}

const columns = (url: string) =>
  withClient(url, async (c) => {
    const r = await c.query<{ table_name: string; column_name: string }>(
      `select table_name, column_name from information_schema.columns where table_schema = 'dispatch' order by table_name, ordinal_position`,
    );
    const out: Record<string, string[]> = {};
    for (const row of r.rows) (out[row.table_name] ??= []).push(row.column_name);
    return out;
  });

describe('dispatch migrations', () => {
  const name = `mig_dispatch_${Date.now()}_test`;
  const scratch = (() => {
    const u = new URL(process.env.TEST_DATABASE_URL ?? '');
    u.pathname = `/${name}`;
    return u.toString();
  })();
  beforeAll(() => withClient(process.env.TEST_DATABASE_URL ?? '', (c) => c.query(`create database ${name}`)));
  afterAll(() => withClient(process.env.TEST_DATABASE_URL ?? '', (c) => c.query(`drop database if exists ${name} with (force)`)));

  it('the dispatch schema matches relational-schema.md §2.8 column for column', async () => {
    await migrateAll(scratch);
    expect(await columns(scratch)).toEqual(EXPECTED);
  });

  it('has the indexes of §2.8 (with Task 1 additions)', async () => {
    const names = await withClient(scratch, async (c) =>
      (await c.query<{ indexname: string }>(`select indexname from pg_indexes where schemaname = 'dispatch'`)).rows.map((r) => r.indexname),
    );
    expect(names).toEqual(expect.arrayContaining([
      'cities_boundary', 'instant_requests_status_city', 'instant_requests_customer', 'instant_requests_meet_point',
      'instant_requests_one_open_job', 'instant_offers_request', 'instant_offers_photographer_outcome',
    ]));
  });

  it('the shared money tables exist and accept provider fake', async () => {
    const tables = await withClient(scratch, async (c) =>
      (await c.query<{ table_name: string }>(`select table_name from information_schema.tables where table_schema = 'public'`)).rows.map((r) => r.table_name),
    );
    expect(tables).toEqual(expect.arrayContaining(['payments', 'refunds', 'ledger_entries', 'payouts', 'payout_items', 'payout_accounts']));
    const check = await withClient(scratch, async (c) =>
      (await c.query<{ def: string }>(`select pg_get_constraintdef(oid) as def from pg_constraint where conrelid = 'payments'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%provider%'`)).rows[0]?.def,
    );
    expect(check).toContain("'fake'");
  });

  it('rolls back the dispatch schema completely and applies again', async () => {
    await migrate(scratch, 'down', { count: Infinity });
    expect(await columns(scratch)).toEqual({});
    await migrate(scratch, 'up');
    expect(Object.keys(await columns(scratch)).sort()).toEqual(Object.keys(EXPECTED).sort());
    expect(API_MIGRATIONS_DIR).toMatch(/services\/api\/migrations$/);
  });
});

describe('constraints of §2.8', () => {
  const db = testDb();
  const redis = testRedis();
  afterAll(async () => {
    redis.disconnect();
    await db.destroy();
  });
  beforeEach(async () => {
    await resetAll(db, redis);
    await seedCatalog(db);
    await addCustomer(db, 'c1');
    await addCustomer(db, 'c2');
    await addPhotographer(db, 'p1');
  });

  const request = (id: string, customer: string, status: string, photographer: string | null) =>
    db.insertInto('dispatch.instant_requests').values({
      id, customer_id: customer, package_id: PACKAGES.p60, city_id: 'hcm', genre: 'portrait', meet_point: ewktPoint(HCM),
      meet_address: 'x', amount_vnd: 600_000, payout_vnd: 480_000, status: status as never, photographer_id: photographer, requested_at: T0,
    });

  it('one open job per photographer (instant_requests_one_open_job)', async () => {
    await request('r1', 'c1', 'en_route', 'p1').execute();
    await expect(request('r2', 'c2', 'assigned', 'p1').execute()).rejects.toThrow(/instant_requests_one_open_job/);
    await request('r3', 'c2', 'completed', 'p1').execute();
  });

  it('never the same photographer twice for a request; payout ≤ amount; known statuses only', async () => {
    await request('r1', 'c1', 'searching', null).execute();
    const offer = (id: string) => db.insertInto('dispatch.instant_offers').values({
      id, request_id: 'r1', photographer_id: 'p1', round: 1, score: 0.8, reasons: '[]', offered_at: T0, expires_at: T0, outcome: 'pending',
    });
    await offer('o1').execute();
    await expect(offer('o2').execute()).rejects.toThrow(/duplicate key/);
    await expect(request('r9', 'c2', 'requested', null).execute()).rejects.toThrow(/check constraint/);
    await expect(sql`update dispatch.instant_requests set payout_vnd = 600001 where id = 'r1'`.execute(db)).rejects.toThrow(/check constraint/);
  });
});
```

Replace `services/dispatch/test/global-setup.ts` with (migrations now run once before the suites):

```ts
// services/dispatch/test/global-setup.ts
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { RedisContainer, type StartedRedisContainer } from '@testcontainers/redis';

import { migrateAll } from '../src/db/migrate.js';

let pg: StartedPostgreSqlContainer | undefined;
let redis: StartedRedisContainer | undefined;

/**
 * Real PostgreSQL + PostGIS and Redis (spec §11). TEST_DATABASE_URL / TEST_REDIS_URL reuse the
 * compose services instead (database name must end in _test; Redis DB 15 is used and flushed).
 */
export async function setup(): Promise<void> {
  if (process.env.TEST_DATABASE_URL) {
    if (!new URL(process.env.TEST_DATABASE_URL).pathname.endsWith('_test')) {
      throw new Error('TEST_DATABASE_URL must name a database ending in _test (tests truncate tables)');
    }
  } else {
    pg = await new PostgreSqlContainer('postgis/postgis:16-3.4-alpine')
      .withDatabase('nag_test')
      .withUsername('nag')
      .withPassword('nag_test_only')
      .start();
    process.env.TEST_DATABASE_URL = pg.getConnectionUri();
  }
  if (!process.env.TEST_REDIS_URL) {
    redis = await new RedisContainer('redis:7.4-alpine').start();
    process.env.TEST_REDIS_URL = `${redis.getConnectionUrl()}/15`;
  }
  await migrateAll(process.env.TEST_DATABASE_URL);
}

export async function teardown(): Promise<void> {
  await redis?.stop();
  await pg?.stop();
}
```

In `services/api/test/migrations.test.ts` (phase 2), the `EXPECTED` map lists every public table: add, in alphabetical position,

```ts
    ledger_entries: ['id', 'type', 'payment_id', 'refund_id', 'payout_id', 'account_owner_id', 'amount', 'currency', 'note', 'at'],
    payments: [
      'id', 'subject_type', 'subject_id', 'payee_id', 'provider', 'amount', 'currency', 'status', 'escrow_status', 'release_after',
      'released_at', 'provider_ref', 'raw', 'idempotency_key', 'created_at', 'updated_at',
    ],
    payout_accounts: ['id', 'user_id', 'bank_code', 'account_number_enc', 'account_last4', 'holder_name', 'active', 'created_at'],
    payout_items: ['payout_id', 'payment_id', 'amount'],
    payouts: [
      'id', 'payee_id', 'account_id', 'amount', 'currency', 'status', 'reference', 'approved_by', 'failure_reason', 'created_at',
      'scheduled_at', 'paid_at',
    ],
    refunds: ['id', 'payment_id', 'amount', 'percent', 'status', 'manual', 'created_at'],
```

- [ ] **Step 3: Run and see it fail**

Run: `npm test -- test/migrations.test.ts`
Expected: FAIL, `expected {} to deeply equal { cities: [...], … }` (no dispatch tables yet).

- [ ] **Step 4: Implement**

```sql
-- services/api/migrations/1790899100001_money_tables.sql
-- relational-schema.md §2.4: payments, refunds, payout accounts, payouts, payout items, ledger entries,
-- verbatim after plan I3 Task 1 (provider 'fake' for local and test environments).
-- Shared by every payment subject; services/dispatch writes subject_type 'instant_request'.
-- Up Migration
create table payments (
  id              text primary key,
  subject_type    text not null check (subject_type in ('booking','event_registration','instant_request')),
  subject_id      text not null,
  payee_id        text references users(id),      -- nhiếp ảnh gia / chủ sự kiện nhận tiền; null = nền tảng
  provider        text not null check (provider in ('momo','vnpay','fake')),
  amount          bigint not null check (amount >= 0),
  currency        char(3) not null default 'VND',
  status          text not null check (status in ('created','paid','failed','refunded','partially_refunded')),
  escrow_status   text not null default 'held' check (escrow_status in ('held','released','paid_out','partially_refunded','refunded','disputed')),
  release_after   timestamptz,                    -- hết cửa sổ khiếu nại
  released_at     timestamptz,
  provider_ref    text,
  raw             jsonb,                          -- phản hồi thô của cổng
  idempotency_key text not null unique,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_payments_subject on payments (subject_type, subject_id);
create index ix_payments_release on payments (escrow_status, release_after) where escrow_status = 'held';

create table refunds (
  id         text primary key,
  payment_id text not null references payments(id),
  amount     bigint not null check (amount > 0),
  percent    smallint check (percent between 0 and 100),
  status     text not null check (status in ('pending','done','failed')),
  manual     boolean not null default false,
  created_at timestamptz not null default now()
);

create table payout_accounts (                    -- 🔒
  id                 text primary key,
  user_id            text not null references users(id) on delete cascade,
  bank_code          text not null,
  account_number_enc bytea not null,              -- mã hoá ở tầng ứng dụng/KMS
  account_last4      char(4) not null,
  holder_name        text not null,
  active             boolean not null default true,
  created_at         timestamptz not null default now()
);
create unique index ux_payout_accounts_active on payout_accounts (user_id) where active;

create table payouts (
  id             text primary key,
  payee_id       text not null references users(id),
  account_id     text not null references payout_accounts(id),
  amount         bigint not null check (amount > 0),
  currency       char(3) not null default 'VND',
  status         text not null check (status in ('pending','on_hold','processing','paid','failed')),
  reference      text,                             -- mã giao dịch ngân hàng
  approved_by    text references users(id),
  failure_reason text,
  created_at     timestamptz not null default now(),
  scheduled_at   timestamptz, paid_at timestamptz
);
create table payout_items (
  payout_id  text not null references payouts(id) on delete cascade,
  payment_id text not null references payments(id),
  amount     bigint not null check (amount > 0),
  primary key (payout_id, payment_id)
);

create table ledger_entries (                     -- bất biến, chỉ thêm
  id              text primary key,
  type            text not null check (type in ('deposit_received','ticket_received','refund_issued','escrow_released','payout_paid','fee_charged','adjustment')),
  payment_id      text references payments(id),
  refund_id       text references refunds(id),
  payout_id       text references payouts(id),
  account_owner_id text references users(id),      -- người được ghi có (nhiếp ảnh gia) hoặc null = nền tảng
  amount          bigint not null,                 -- có dấu
  currency        char(3) not null default 'VND',
  note            text,
  at              timestamptz not null default now()
);
create index ix_ledger_payment on ledger_entries (payment_id, at);
create index ix_ledger_owner on ledger_entries (account_owner_id, at);

create trigger trg_payments_updated_at before update on payments
  for each row execute function set_updated_at();

-- Down Migration
drop table ledger_entries;
drop table payout_items;
drop table payouts;
drop table payout_accounts;
drop table refunds;
drop table payments;
```

```sql
-- services/dispatch/migrations/1790899200001_dispatch_schema.sql
-- relational-schema.md §2.8 (schema dispatch), verbatim after Task 1's two fixes:
-- photographers(user_id) as the FK target, and the indexes instant_requests_customer and cities_boundary.
-- Up Migration
create schema if not exists dispatch;
create extension if not exists postgis;

create table dispatch.cities (
  id          text primary key,
  name        text not null,
  boundary    geography(Polygon, 4326) not null,
  surge       numeric(3,2) not null default 1.00 check (surge >= 1.00 and surge <= 3.00),
  active      boolean not null default false
);
create index cities_boundary on dispatch.cities using gist (boundary);

create table dispatch.instant_packages (
  id                 text primary key,           -- ULID
  code               text not null,              -- 'p30' | 'p60' | 'p120'
  duration_min       integer not null check (duration_min > 0),
  photos             integer not null check (photos >= 0),
  price_vnd          bigint not null check (price_vnd > 0),
  price_list_version integer not null,
  active             boolean not null default true,
  unique (code, price_list_version)
);

create table dispatch.instant_requests (
  id              text primary key,
  customer_id     text not null references users(id),
  package_id      text not null references dispatch.instant_packages(id),
  city_id         text not null references dispatch.cities(id),
  genre           text not null,
  meet_point      geography(Point, 4326) not null,
  meet_address    text not null,
  note            text check (char_length(note) <= 140),
  expand          boolean not null default false,
  amount_vnd      bigint not null check (amount_vnd > 0),
  payout_vnd      bigint not null check (payout_vnd >= 0 and payout_vnd <= amount_vnd),
  status          text not null check (status in ('pending_payment','payment_failed','searching','assigned','en_route','arrived','in_progress','completed','no_match','cancelled_by_customer','no_show_customer','disputed')),
  photographer_id text references photographers(user_id),
  round           smallint not null default 1 check (round in (1,2)),
  requested_at    timestamptz not null,
  assigned_at     timestamptz,
  arrived_at      timestamptz,
  started_at      timestamptz,
  finished_at     timestamptz,
  completed_at    timestamptz,
  cancelled_at    timestamptz,
  cancel_reason   text,
  version         integer not null default 0
);
create index instant_requests_status_city on dispatch.instant_requests (status, city_id);
create index instant_requests_customer on dispatch.instant_requests (customer_id, status);
create index instant_requests_meet_point on dispatch.instant_requests using gist (meet_point);
-- One open job per photographer.
create unique index instant_requests_one_open_job on dispatch.instant_requests (photographer_id)
  where status in ('assigned','en_route','arrived','in_progress');

create table dispatch.instant_offers (
  id              text primary key,
  request_id      text not null references dispatch.instant_requests(id),
  photographer_id text not null references photographers(user_id),
  round           smallint not null check (round in (1,2)),
  score           numeric(5,4) not null,
  reasons         jsonb not null default '[]',
  offered_at      timestamptz not null,
  expires_at      timestamptz not null,
  outcome         text not null check (outcome in ('pending','accepted','declined','expired','withdrawn')),
  decided_at      timestamptz,
  unique (request_id, photographer_id)
);
create index instant_offers_request on dispatch.instant_offers (request_id);
create index instant_offers_photographer_outcome on dispatch.instant_offers (photographer_id, outcome);

create table dispatch.photographer_instant_settings (
  photographer_id            text primary key references photographers(user_id),
  price_list_version_accepted integer,
  help_ready                 boolean not null default false,
  home_city_id               text references dispatch.cities(id),
  updated_at                 timestamptz not null
);

create table dispatch.photographer_reliability (
  photographer_id text primary key references photographers(user_id),
  offers          integer not null default 0,
  accepted        integer not null default 0,
  cancelled       integer not null default 0,
  no_show         integer not null default 0,
  updated_at      timestamptz not null
);

-- Down Migration
drop table dispatch.photographer_reliability;
drop table dispatch.photographer_instant_settings;
drop table dispatch.instant_offers;
drop table dispatch.instant_requests;
drop table dispatch.instant_packages;
drop table dispatch.cities;
drop schema dispatch;
```

- [ ] **Step 5: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  8 passed | 1 skipped (9)`, `Tests  36 passed | 3 skipped (39)` (the Firestore mirror suite skips without the emulator). If node-pg-migrate reports `Not run migration … is preceding already run migration`, a later api migration ran before this one on that database: keep the `1790899100001` prefix and recreate the test database.

Run (from `services/api`): `npm test -- test/migrations.test.ts`
Expected: phase 2's migration tests still pass with the money tables listed.

Run: `cd ../api && docker compose up --build -d && docker compose logs dispatch-migrate | tail -n 2 && docker compose down`
Expected: the last log line is `dispatch migrations up: done`.

- [ ] **Step 6: Commit**

```bash
git add services/dispatch services/api/migrations services/api/test/migrations.test.ts
git commit -m "feat(dispatch): dispatch schema (relational-schema 2.8) and shared money tables (2.4) migrations with column-for-column tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 8: Cities, price list and `GET /v1/packages`

**Files:**
- Create: `services/dispatch/src/catalog/catalog.ts`, `services/dispatch/src/routes/catalog.ts`, `services/dispatch/src/tools/seed-dev.ts`, `services/dispatch/test/catalog.test.ts`
- Modify: `services/dispatch/src/app.ts`, `services/dispatch/test/contract.test.ts`, `services/dispatch/package.json`

**Interfaces:**
- Consumes: `parseSurge`, `quotePrice`, `typicalMatchMinutes`, `configForCity` (plan I2); `ewktPoint`, `Db` (Task 6); `keys.typical` (Task 6).
- Produces:
  - `interface City { id; name; surge /* hundredths */ }`, `interface PricedPackage { id; code; durationMin; photos; basePriceVnd; priceVnd; payoutVnd; priceListVersion }`.
  - `cityAtQuery(db, p)`, `cityAt(db, p): Promise<City | null>` (`ST_Covers` on the active cities), `cityById(db, id)`, `currentPriceListVersion(db): Promise<number>` (highest version with active packages), `pricedPackages(db, city, cfg)`, `matchSamplesQuery(db, cityId, since)`, `typicalMatch(deps, cityId, cfg): Promise<number | null>` (cached 10 minutes in `typical:{cityId}`), `cityConfig(deps, cityId): DispatchConfig`.
  - `GET /v1/packages?cityId=` or `?lat=&lng=` (`listPackages`) → `PackagesResponse`; `invalid_argument` without both, `outside_service_area` (422) outside every active city.
  - `seedDev(db)`, `DEV_CITIES`, `DEV_PACKAGES`; CLI `node dist/tools/seed-dev.js` (idempotent; dev values only, not the production price list: spec open questions 1–2).

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/catalog.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { HCM, HN, PACKAGES, T0, addCustomer, as, ewktPoint, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld } from './helpers.js';

const db = testDb();
const redis = testRedis();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp(testWorld(db, redis));
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});
beforeEach(async () => {
  await resetAll(db, redis);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
});

const get = (q: string) => app.inject({ method: 'GET', url: `/v1/packages?${q}`, headers: as('c1') });

describe('GET /v1/packages (S47, S52)', () => {
  it('prices are package × city surge, rounded to 1,000 ₫, with the photographer payout', async () => {
    const res = await get('cityId=hcm');
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      cityId: 'hcm', cityName: 'Hồ Chí Minh', priceListVersion: 1, surge: 1.2, typicalMatchMinutes: null,
      packages: [
        { id: PACKAGES.p30, code: 'p30', durationMin: 30, photos: 10, priceVnd: 360_000, payoutVnd: 288_000 },
        { id: PACKAGES.p60, code: 'p60', durationMin: 60, photos: 20, priceVnd: 600_000, payoutVnd: 480_000 },
        { id: PACKAGES.p120, code: 'p120', durationMin: 120, photos: 40, priceVnd: 1_080_000, payoutVnd: 864_000 },
      ],
    });
  });

  it('finds the city from lat/lng (PostGIS ST_Covers)', async () => {
    expect((await get(`lat=${HN.lat}&lng=${HN.lng}`)).json().cityId).toBe('hn');
    expect((await get(`lat=${HCM.lat}&lng=${HCM.lng}`)).json().cityId).toBe('hcm');
  });

  it('outside every open city → outside_service_area; nothing given → invalid_argument', async () => {
    const out = await get('lat=16.0544&lng=108.2022');
    expect(out.statusCode).toBe(422);
    expect(out.json().code).toBe('outside_service_area');
    expect((await get('')).statusCode).toBe(400);
  });

  it('typicalMatchMinutes: median of the last 7 days once there are 20 samples', async () => {
    const rows = Array.from({ length: 20 }, (_, i) => ({
      id: `r${String(i).padStart(2, '0')}`, customer_id: 'c1', package_id: PACKAGES.p60, city_id: 'hcm', genre: 'portrait' as const,
      meet_point: ewktPoint(HCM), meet_address: 'x', amount_vnd: 600_000, payout_vnd: 480_000, status: 'completed' as const,
      requested_at: new Date(T0.getTime() - 86_400_000 + i * 60_000),
      assigned_at: new Date(T0.getTime() - 86_400_000 + i * 60_000 + (i < 10 ? 6 : 8) * 60_000),
    }));
    await db.insertInto('dispatch.instant_requests').values(rows).execute();
    expect((await get('cityId=hcm')).json().typicalMatchMinutes).toBe(7);
  });
});
```

In `test/contract.test.ts` remove `'listPackages'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/catalog.test.ts test/contract.test.ts`
Expected: FAIL. `catalog.test.ts`: `GET /v1/packages` answers 404 `not_found` (no route yet); `contract.test.ts`: `listPackages GET /v1/packages: expected false to be true`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/catalog/catalog.ts
import { sql } from 'kysely';

import { ewktPoint, type Db } from '../db/database.js';
import { configForCity, parseSurge, quotePrice, typicalMatchMinutes, type DispatchConfig, type LatLng, type PackageCode } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { keys } from '../redis/keys.js';

export interface City {
  id: string;
  name: string;
  /** Hundredths (1.20 → 120). */
  surge: number;
}

export interface PricedPackage {
  id: string;
  code: PackageCode;
  durationMin: number;
  photos: number;
  basePriceVnd: number;
  priceVnd: number;
  payoutVnd: number;
  priceListVersion: number;
}

export const cityAtQuery = (db: Db, p: LatLng) =>
  db
    .selectFrom('dispatch.cities')
    .select(['id', 'name', 'surge'])
    .where('active', '=', true)
    .where(sql<boolean>`ST_Covers(boundary, ${ewktPoint(p)}::geography)`)
    .limit(1);

export async function cityAt(db: Db, p: LatLng): Promise<City | null> {
  const r = await cityAtQuery(db, p).executeTakeFirst();
  return r ? { id: r.id, name: r.name, surge: parseSurge(r.surge) } : null;
}

export async function cityById(db: Db, id: string): Promise<City | null> {
  const r = await db.selectFrom('dispatch.cities').select(['id', 'name', 'surge']).where('id', '=', id).where('active', '=', true).executeTakeFirst();
  return r ? { id: r.id, name: r.name, surge: parseSurge(r.surge) } : null;
}

/** The current price list is the highest version that has active packages. */
export async function currentPriceListVersion(db: Db): Promise<number> {
  const r = await db
    .selectFrom('dispatch.instant_packages')
    .select((eb) => eb.fn.max('price_list_version').as('v'))
    .where('active', '=', true)
    .executeTakeFirst();
  return r?.v ?? 0;
}

export async function pricedPackages(db: Db, city: City, cfg: DispatchConfig): Promise<{ version: number; packages: PricedPackage[] }> {
  const version = await currentPriceListVersion(db);
  const rows = await db
    .selectFrom('dispatch.instant_packages')
    .selectAll()
    .where('active', '=', true)
    .where('price_list_version', '=', version)
    .orderBy('duration_min')
    .execute();
  return {
    version,
    packages: rows.map((r) => {
      const q = quotePrice(r.price_vnd, city.surge, cfg);
      return {
        id: r.id, code: r.code, durationMin: r.duration_min, photos: r.photos, basePriceVnd: r.price_vnd,
        priceVnd: q.amountVnd, payoutVnd: q.payoutVnd, priceListVersion: r.price_list_version,
      };
    }),
  };
}

/** Assigned − requested of the last 7 days in the city (spec §2.1); includes the seconds spent paying. */
export const matchSamplesQuery = (db: Db, cityId: string, since: Date) =>
  db
    .selectFrom('dispatch.instant_requests')
    .select(sql<number>`extract(epoch from (assigned_at - requested_at)) * 1000`.as('ms'))
    .where('city_id', '=', cityId)
    .where('status', 'in', ['assigned', 'en_route', 'arrived', 'in_progress', 'completed', 'disputed'])
    .where('assigned_at', '>=', since)
    .limit(5_000);

/** Cached 10 minutes per city: GET /v1/packages is hot, the 7-day median moves slowly. */
export async function typicalMatch(deps: Pick<Deps, 'db' | 'clock' | 'redis'>, cityId: string, cfg: DispatchConfig): Promise<number | null> {
  const cached = await deps.redis.get(keys.typical(cityId));
  if (cached !== null) return (JSON.parse(cached) as { v: number | null }).v;
  const since = new Date(deps.clock.now().getTime() - cfg.stats.typicalMatchWindowMs);
  const rows = await matchSamplesQuery(deps.db, cityId, since).execute();
  const v = typicalMatchMinutes(rows.map((r) => Number(r.ms)), cfg);
  await deps.redis.set(keys.typical(cityId), JSON.stringify({ v }), 'PX', 600_000);
  return v;
}

export const cityConfig = (deps: Pick<Deps, 'book'>, cityId: string): DispatchConfig => configForCity(deps.book, cityId);
```

```ts
// services/dispatch/src/routes/catalog.ts
import type { FastifyInstance } from 'fastify';

import { cityAt, cityById, cityConfig, pricedPackages, typicalMatch } from '../catalog/catalog.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import { DispatchError } from '../domain/core.js';
import { ApiError } from '../errors.js';
import type { components } from '../generated/api.js';

type S = components['schemas'];

export function registerCatalogRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Querystring: { cityId?: string; lat?: number; lng?: number } }>({
    ...route(deps.contract, 'listPackages'),
    handler: async (req) => {
      const q = req.query;
      if (!q.cityId && (q.lat === undefined || q.lng === undefined)) throw new ApiError('invalid_argument', 'cityId or lat/lng is required');
      const city = q.cityId ? await cityById(deps.db, q.cityId) : await cityAt(deps.db, { lat: q.lat ?? 0, lng: q.lng ?? 0 });
      if (!city) throw new DispatchError('outside_service_area');
      const cfg = cityConfig(deps, city.id);
      const { version, packages } = await pricedPackages(deps.db, city, cfg);
      return {
        cityId: city.id,
        cityName: city.name,
        priceListVersion: version,
        surge: city.surge / 100,
        typicalMatchMinutes: await typicalMatch(deps, city.id, cfg),
        packages: packages.map((p) => ({ id: p.id, code: p.code, durationMin: p.durationMin, photos: p.photos, priceVnd: p.priceVnd, payoutVnd: p.payoutVnd })),
      } satisfies S['PackagesResponse'];
    },
  });
}
```

```ts
// services/dispatch/src/tools/seed-dev.ts
// Local/dev catalog: three cities and price list v1. NOT the production price list or boundaries:
// those are open questions 1 and 2 of the spec (product owner decides); production loads them by migration later.
// Run: DATABASE_URL=… npm run seed:dev   (idempotent)
import { createDb, type Db } from '../db/database.js';

export const DEV_CITIES = [
  { id: 'hcm', name: 'Hồ Chí Minh', center: { lat: 10.7769, lng: 106.7009 }, half: 0.3, surge: '1.00' },
  { id: 'hn', name: 'Hà Nội', center: { lat: 21.0278, lng: 105.8342 }, half: 0.3, surge: '1.00' },
  { id: 'dn', name: 'Đà Nẵng', center: { lat: 16.0544, lng: 108.2022 }, half: 0.2, surge: '1.00' },
] as const;

export const DEV_PACKAGES = [
  { id: '01J9ZP30000000000000000000', code: 'p30', duration_min: 30, photos: 10, price_vnd: 300_000 },
  { id: '01J9ZP60000000000000000000', code: 'p60', duration_min: 60, photos: 20, price_vnd: 500_000 },
  { id: '01J9ZP12000000000000000000', code: 'p120', duration_min: 120, photos: 40, price_vnd: 900_000 },
] as const;

const box = (c: { lat: number; lng: number }, d: number) =>
  `SRID=4326;POLYGON((${c.lng - d} ${c.lat - d}, ${c.lng + d} ${c.lat - d}, ${c.lng + d} ${c.lat + d}, ${c.lng - d} ${c.lat + d}, ${c.lng - d} ${c.lat - d}))`;

export async function seedDev(db: Db): Promise<void> {
  for (const c of DEV_CITIES) {
    await db
      .insertInto('dispatch.cities')
      .values({ id: c.id, name: c.name, boundary: box(c.center, c.half), surge: c.surge, active: true })
      .onConflict((oc) => oc.column('id').doUpdateSet({ name: c.name, boundary: box(c.center, c.half), active: true }))
      .execute();
  }
  for (const p of DEV_PACKAGES) {
    await db
      .insertInto('dispatch.instant_packages')
      .values({ ...p, price_list_version: 1, active: true })
      .onConflict((oc) => oc.column('id').doNothing())
      .execute();
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL is required');
    process.exit(2);
  }
  const db = createDb(url, 2);
  await seedDev(db);
  await db.destroy();
  console.log('dispatch dev catalog: 3 cities, 3 packages (price list v1)');
}
```

In `src/app.ts` add the import

```ts
import { registerCatalogRoutes } from './routes/catalog.js';
```

and, after the previous `register…Routes(app, deps);` line,

```ts
  registerCatalogRoutes(app, deps);
```

In `services/dispatch/package.json`, add ` src/tools/seed-dev.ts` to the `build` script's entry points (after `src/db/migrate-cli.ts`) and add the script

```json
    "seed:dev": "node --import tsx src/tools/seed-dev.ts",
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  9 passed | 1 skipped (10)`, `Tests  40 passed | 3 skipped (43)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): cities, surge-priced packages and typical match time (GET /v1/packages)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Photographer facts, instant settings and presence (Redis GEO, 10-minute TTL)

**Files:**
- Create: `services/dispatch/src/settings/facts.ts`, `services/dispatch/src/settings/settings.ts`, `services/dispatch/src/presence/presence.ts`, `services/dispatch/src/routes/presence.ts`, `services/dispatch/test/settings-presence.test.ts`
- Modify: `services/dispatch/src/app.ts`, `services/dispatch/test/contract.test.ts`

**Interfaces:**
- Consumes: `readinessReasons`, `PhotographerFacts`, `DispatchError` (plan I2); `cityAt`, `cityConfig`, `currentPriceListVersion` (Task 8); `keys` (Task 6).
- Produces:
  - `loadFacts(db, uid, hasSpecialties): Promise<PhotographerFacts | null>` (photographers + users + contact numbers + instant settings + reliability; specialty levels when `photographer_specialties` exists), `bumpReliability(db: Exec, uid, field: 'offers' | 'accepted' | 'cancelled' | 'no_show', now)`.
  - `interface InstantSettingsView` (= contract `InstantSettings`); `getInstantSettings(deps, uid)`, `putInstantSettings(deps, uid, { acceptPriceListVersion?, helpReady? })` (only the current version, else `conflict`).
  - `interface PresenceInput { online; helpReady?; fix? }`, `interface PresenceState { online; helpReady; cityId; expiresAt }`; `putPresence(deps, uid, input)`: online → readiness re-checked (`not_eligible {reasons}`), one `MULTI`: `ZREM` old city if it changed, `GEOADD online:{city}`, `HSET presence:{uid}` + `PEXPIRE` TTL, `SET pfacts:{uid}` JSON `PX` TTL; offline → removed. `refreshCachedFacts(deps, uid)` keeps the remaining TTL.
  - Routes `getInstantSettings`, `putInstantSettings`, `putPresence`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/settings-presence.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { keys } from '../src/redis/keys.js';
import { HCM, HN, T0, addCustomer, addPhotographer, as, fixAt, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld } from './helpers.js';

const db = testDb();
const redis = testRedis();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp(testWorld(db, redis));
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});
beforeEach(async () => {
  await resetAll(db, redis);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addPhotographer(db, 'p1');
  await addPhotographer(db, 'p2', { acceptedVersion: null, phone: false });
});

const presence = (uid: string, payload: object) => app.inject({ method: 'PUT', url: '/v1/presence', headers: as(uid), payload });

describe('instant settings (S52)', () => {
  it('shows the current price list and eligibility', async () => {
    const ok = await app.inject({ method: 'GET', url: '/v1/instant-settings', headers: as('p1') });
    expect(ok.json()).toEqual({ acceptedPriceListVersion: 1, currentPriceListVersion: 1, helpReady: false, eligible: true, reasons: [] });
    const not = await app.inject({ method: 'GET', url: '/v1/instant-settings', headers: as('p2') });
    expect(not.json()).toMatchObject({ acceptedPriceListVersion: null, eligible: false, reasons: ['no_phone', 'price_list_not_accepted'] });
  });

  it('accepts only the current version; turns on "Sẵn sàng hỗ trợ"', async () => {
    const stale = await app.inject({ method: 'PUT', url: '/v1/instant-settings', headers: as('p2'), payload: { acceptPriceListVersion: 0 } });
    expect(stale.statusCode).toBe(409);
    expect(stale.json().code).toBe('conflict');
    const res = await app.inject({ method: 'PUT', url: '/v1/instant-settings', headers: as('p2'), payload: { acceptPriceListVersion: 1, helpReady: true } });
    expect(res.json()).toMatchObject({ acceptedPriceListVersion: 1, helpReady: true, reasons: ['no_phone'] });
  });

  it('a customer has no instant settings', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/instant-settings', headers: as('c1') })).statusCode).toBe(403);
  });
});

describe('PUT /v1/presence (spec §5 presence)', () => {
  it('online: GEOADD online:{city}, presence TTL 10 minutes, facts cached', async () => {
    const res = await presence('p1', { online: true, fix: fixAt(HCM, T0) });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ online: true, helpReady: false, cityId: 'hcm', expiresAt: '2026-10-01T08:10:00.000Z' });
    expect(await redis.geopos(keys.online('hcm'), 'p1')).toHaveLength(1);
    const ttl = await redis.pttl(keys.presence('p1'));
    expect(ttl).toBeGreaterThan(590_000);
    expect(ttl).toBeLessThanOrEqual(600_000);
    expect(JSON.parse((await redis.get(keys.facts('p1'))) ?? '{}')).toMatchObject({ uid: 'p1', verified: true, acceptedPriceListVersion: 1 });
  });

  it('offline removes everything', async () => {
    await presence('p1', { online: true, fix: fixAt(HCM, T0) });
    expect((await presence('p1', { online: false })).json()).toEqual({ online: false, helpReady: false, cityId: null, expiresAt: null });
    expect(await redis.zscore(keys.online('hcm'), 'p1')).toBeNull();
    expect(await redis.exists(keys.presence('p1'), keys.facts('p1'))).toBe(0);
  });

  it('moving to another city leaves the old GEO set', async () => {
    await presence('p1', { online: true, fix: fixAt(HCM, T0) });
    await presence('p1', { online: true, fix: fixAt(HN, T0) });
    expect(await redis.zscore(keys.online('hcm'), 'p1')).toBeNull();
    expect(await redis.zscore(keys.online('hn'), 'p1')).not.toBeNull();
  });

  it('not_eligible with every reason; never left online', async () => {
    const r = await presence('p2', { online: true, fix: fixAt(HCM, T0) });
    expect(r.statusCode).toBe(422);
    expect(r.json()).toMatchObject({ code: 'not_eligible', details: { reasons: ['no_phone', 'price_list_not_accepted'] } });
    expect((await presence('p1', { online: true })).json().details).toEqual({ reasons: ['location_denied'] });
    expect((await presence('p1', { online: true, fix: fixAt({ lat: 16.05, lng: 108.2 }, T0) })).json().details).toEqual({ reasons: ['outside_city'] });
    expect(await redis.zcard(keys.online('hcm'))).toBe(0);
  });

  it('customers cannot go online', async () => {
    expect((await presence('c1', { online: true, fix: fixAt(HCM, T0) })).statusCode).toBe(403);
  });

  it('helpReady in the body is saved and cached', async () => {
    const r = await presence('p1', { online: true, helpReady: true, fix: fixAt(HCM, T0) });
    expect(r.json().helpReady).toBe(true);
    expect(JSON.parse((await redis.get(keys.facts('p1'))) ?? '{}').helpReady).toBe(true);
  });
});
```

In `test/contract.test.ts` remove `'getInstantSettings'`, `'putInstantSettings'`, `'putPresence'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/settings-presence.test.ts`
Expected: FAIL: every request answers 404 `not_found` (routes missing).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/settings/facts.ts
import type { Db, Exec } from '../db/database.js';
import type { PhotographerFacts } from '../domain/core.js';

/**
 * PhotographerFacts from the shared PostgreSQL rows (phase 2 tables + dispatch settings and
 * reliability). null: not a photographer (no photographers row, or the user is deleted).
 */
export async function loadFacts(db: Db, uid: string, hasSpecialties: boolean): Promise<PhotographerFacts | null> {
  const row = await db
    .selectFrom('photographers as p')
    .innerJoin('users as u', 'u.id', 'p.user_id')
    .leftJoin('photographer_contact_numbers as n', 'n.photographer_id', 'p.user_id')
    .leftJoin('dispatch.photographer_instant_settings as s', 's.photographer_id', 'p.user_id')
    .leftJoin('dispatch.photographer_reliability as r', 'r.photographer_id', 'p.user_id')
    .select([
      'p.user_id', 'p.onboarding_complete', 'p.verified', 'p.rating_avg', 'p.review_count',
      'n.phone_e164', 's.price_list_version_accepted', 's.help_ready',
      'r.offers', 'r.accepted', 'r.cancelled', 'r.no_show',
    ])
    .where('p.user_id', '=', uid)
    .where('u.deleted_at', 'is', null)
    .executeTakeFirst();
  if (!row) return null;
  let specialtyLevels: PhotographerFacts['specialtyLevels'] = null;
  if (hasSpecialties) {
    const rows = await db.selectFrom('photographer_specialties').select(['specialty_id', 'level']).where('photographer_id', '=', uid).execute();
    specialtyLevels = Object.fromEntries(rows.map((r) => [r.specialty_id, Math.min(3, Math.max(1, r.level)) as 1 | 2 | 3]));
  }
  return {
    uid,
    onboardingComplete: row.onboarding_complete,
    hasPhone: row.phone_e164 !== null,
    verified: row.verified,
    ratingAvg: row.review_count > 0 ? Number(row.rating_avg) : null,
    reviewCount: row.review_count,
    acceptedPriceListVersion: row.price_list_version_accepted ?? null,
    helpReady: row.help_ready ?? false,
    reliability: { offers: row.offers ?? 0, accepted: row.accepted ?? 0, cancelled: row.cancelled ?? 0, noShow: row.no_show ?? 0 },
    specialtyLevels,
  };
}

/** +1 on a reliability counter (row created on first use). */
export async function bumpReliability(
  db: Exec,
  uid: string,
  field: 'offers' | 'accepted' | 'cancelled' | 'no_show',
  now: Date,
): Promise<void> {
  await db
    .insertInto('dispatch.photographer_reliability')
    .values({ photographer_id: uid, [field]: 1, updated_at: now })
    .onConflict((oc) => oc.column('photographer_id').doUpdateSet((eb) => ({ [field]: eb(`dispatch.photographer_reliability.${field}`, '+', 1), updated_at: now })))
    .execute();
}
```

```ts
// services/dispatch/src/settings/settings.ts
import { currentPriceListVersion } from '../catalog/catalog.js';
import { DispatchError, readinessReasons } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { refreshCachedFacts } from '../presence/presence.js';
import { loadFacts } from './facts.js';

export interface InstantSettingsView {
  acceptedPriceListVersion: number | null;
  currentPriceListVersion: number;
  helpReady: boolean;
  eligible: boolean;
  reasons: Array<'profile_incomplete' | 'no_phone' | 'price_list_not_accepted' | 'outside_city' | 'location_denied'>;
}

/**
 * S52 header (spec §2.2 step 1). `eligible`/`reasons` cover what the server knows without a
 * location (profile, phone, price list); city and location are checked at PUT /v1/presence.
 */
export async function getInstantSettings(deps: Deps, uid: string): Promise<InstantSettingsView> {
  const facts = await loadFacts(deps.db, uid, deps.hasSpecialties);
  if (!facts) throw new DispatchError('permission_denied', { reason: 'not a photographer' });
  const current = await currentPriceListVersion(deps.db);
  const reasons = readinessReasons(facts, { currentPriceListVersion: current, inCity: true, hasLocation: true });
  return { acceptedPriceListVersion: facts.acceptedPriceListVersion, currentPriceListVersion: current, helpReady: facts.helpReady, eligible: reasons.length === 0, reasons };
}

/** Accepts the current price list (only the current version: anything else is conflict) and/or sets helpReady. */
export async function putInstantSettings(deps: Deps, uid: string, body: { acceptPriceListVersion?: number; helpReady?: boolean }): Promise<InstantSettingsView> {
  const facts = await loadFacts(deps.db, uid, deps.hasSpecialties);
  if (!facts) throw new DispatchError('permission_denied', { reason: 'not a photographer' });
  const current = await currentPriceListVersion(deps.db);
  if (body.acceptPriceListVersion !== undefined && body.acceptPriceListVersion !== current) {
    throw new DispatchError('conflict', { reason: 'price list changed', currentPriceListVersion: current });
  }
  const now = deps.clock.now();
  await deps.db
    .insertInto('dispatch.photographer_instant_settings')
    .values({
      photographer_id: uid,
      price_list_version_accepted: body.acceptPriceListVersion ?? facts.acceptedPriceListVersion,
      help_ready: body.helpReady ?? facts.helpReady,
      updated_at: now,
    })
    .onConflict((oc) =>
      oc.column('photographer_id').doUpdateSet({
        ...(body.acceptPriceListVersion !== undefined ? { price_list_version_accepted: body.acceptPriceListVersion } : {}),
        ...(body.helpReady !== undefined ? { help_ready: body.helpReady } : {}),
        updated_at: now,
      }),
    )
    .execute();
  await refreshCachedFacts(deps, uid);
  return getInstantSettings(deps, uid);
}
```

```ts
// services/dispatch/src/presence/presence.ts
import { cityAt, cityConfig, currentPriceListVersion } from '../catalog/catalog.js';
import { DispatchError, readinessReasons, type LatLng, type PhotographerFacts } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { keys } from '../redis/keys.js';
import { loadFacts } from '../settings/facts.js';

export interface PresenceInput {
  online: boolean;
  helpReady?: boolean;
  fix?: LatLng & { accuracyM: number; at: string };
}

export interface PresenceState {
  online: boolean;
  helpReady: boolean;
  cityId: string | null;
  expiresAt: Date | null;
}

/**
 * PUT /v1/presence (spec §5 `presence`): GEOADD online:{cityId} + presence:{uid} with a 10-minute
 * TTL. Going online re-checks readiness every time (profile, phone, price list, city, location).
 * 8 Redis commands when online (one MULTI), 4 when offline.
 */
export async function putPresence(deps: Deps, uid: string, input: PresenceInput): Promise<PresenceState> {
  const facts = await loadFacts(deps.db, uid, deps.hasSpecialties);
  if (!facts) throw new DispatchError('permission_denied', { reason: 'not a photographer' });
  const previousCity = await deps.redis.hget(keys.presence(uid), 'cityId');

  if (input.helpReady !== undefined && input.helpReady !== facts.helpReady) {
    await deps.db
      .insertInto('dispatch.photographer_instant_settings')
      .values({ photographer_id: uid, help_ready: input.helpReady, updated_at: deps.clock.now() })
      .onConflict((oc) => oc.column('photographer_id').doUpdateSet({ help_ready: input.helpReady, updated_at: deps.clock.now() }))
      .execute();
    facts.helpReady = input.helpReady;
  }

  if (!input.online) {
    await goOffline(deps, uid, previousCity);
    return { online: false, helpReady: facts.helpReady, cityId: null, expiresAt: null };
  }

  const city = input.fix ? await cityAt(deps.db, input.fix) : null;
  const reasons = readinessReasons(facts, {
    currentPriceListVersion: await currentPriceListVersion(deps.db),
    inCity: city !== null,
    hasLocation: input.fix !== undefined,
  });
  if (reasons.length > 0 || !city || !input.fix) {
    await goOffline(deps, uid, previousCity);
    throw new DispatchError('not_eligible', { reasons });
  }

  const cfg = cityConfig(deps, city.id);
  const ttl = cfg.presence.ttlMs;
  const now = deps.clock.now();
  const tx = deps.redis.multi();
  if (previousCity && previousCity !== city.id) tx.zrem(keys.online(previousCity), uid);
  tx.geoadd(keys.online(city.id), input.fix.lng, input.fix.lat, uid);
  tx.hset(keys.presence(uid), {
    cityId: city.id,
    lat: String(input.fix.lat),
    lng: String(input.fix.lng),
    accuracyM: String(input.fix.accuracyM),
    at: input.fix.at,
    helpReady: facts.helpReady ? '1' : '0',
  });
  tx.pexpire(keys.presence(uid), ttl);
  tx.set(keys.facts(uid), JSON.stringify(facts satisfies PhotographerFacts), 'PX', ttl);
  await tx.exec();
  return { online: true, helpReady: facts.helpReady, cityId: city.id, expiresAt: new Date(now.getTime() + ttl) };
}

async function goOffline(deps: Deps, uid: string, cityId: string | null): Promise<void> {
  const tx = deps.redis.multi();
  if (cityId) tx.zrem(keys.online(cityId), uid);
  tx.del(keys.presence(uid), keys.facts(uid));
  await tx.exec();
}

/** Re-cache facts after settings or reliability changed, keeping the remaining TTL. */
export async function refreshCachedFacts(deps: Deps, uid: string): Promise<void> {
  const ttl = await deps.redis.pttl(keys.facts(uid));
  if (ttl <= 0) return;
  const facts = await loadFacts(deps.db, uid, deps.hasSpecialties);
  if (facts) await deps.redis.set(keys.facts(uid), JSON.stringify(facts), 'PX', ttl);
}
```

```ts
// services/dispatch/src/routes/presence.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { putPresence } from '../presence/presence.js';
import { getInstantSettings, putInstantSettings } from '../settings/settings.js';

type S = components['schemas'];

export function registerPresenceRoutes(app: FastifyInstance, deps: RouteDeps): void {
  const c = deps.contract;
  app.route({
    ...route(c, 'getInstantSettings'),
    handler: async (req) => getInstantSettings(deps, principalOf(req).uid) satisfies Promise<S['InstantSettings']>,
  });
  app.route<{ Body: S['InstantSettingsBody'] }>({
    ...route(c, 'putInstantSettings'),
    handler: async (req) => putInstantSettings(deps, principalOf(req).uid, req.body) satisfies Promise<S['InstantSettings']>,
  });
  app.route<{ Body: S['PresenceBody'] }>({
    ...route(c, 'putPresence'),
    handler: async (req) => {
      const s = await putPresence(deps, principalOf(req).uid, req.body);
      return { online: s.online, helpReady: s.helpReady, cityId: s.cityId, expiresAt: s.expiresAt?.toISOString() ?? null } satisfies S['PresenceResponse'];
    },
  });
}
```

In `src/app.ts` add the import

```ts
import { registerPresenceRoutes } from './routes/presence.js';
```

and, after the previous `register…Routes(app, deps);` line,

```ts
  registerPresenceRoutes(app, deps);
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  10 passed | 1 skipped (11)`, `Tests  49 passed | 3 skipped (52)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): instant settings, readiness and Redis GEO presence with a 10-minute TTL

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Requests, payments, ledger and the request mirror

**Files:**
- Create: `services/dispatch/src/requests/rows.ts`, `services/dispatch/src/requests/publish.ts`, `services/dispatch/src/requests/create.ts`, `services/dispatch/src/payments/ledger.ts`, `services/dispatch/src/payments/events.ts`, `services/dispatch/src/routes/requests.ts`, `services/dispatch/src/routes/payments.ts`, `services/dispatch/test/requests.test.ts`
- Modify: `services/dispatch/src/jobs/handlers.ts` (replace), `services/dispatch/src/app.ts`, `services/dispatch/test/contract.test.ts`

**Interfaces:**
- Consumes: `quotePrice`, `transition`, `ACTIVE_STATUSES`, `startSearch`, `searchEndsAt`, `settleNoMatch`, `graceEndsAt`, `radiusKm`, `SearchState` (plan I2); the payment port (Task 3); `MirrorWriter` (Task 4); `Scheduler` (Task 5); catalog (Task 8).
- Produces:
  - `interface RequestRow { id; customerId; packageId; packageCode; durationMin; cityId; genre; meetPoint; meetAddress; note; expand; amountVnd; payoutVnd; status; photographerId; round; requestedAt; assignedAt; arrivedAt; startedAt; finishedAt; completedAt; cancelledAt; version }`; `requestQuery(db, id)`, `loadRequest(db: Exec, id, lock?)` (with `lock`: `SELECT id … FOR UPDATE` first); `interface SearchRecord { state: SearchState; area }`, `loadSearch`, `saveSearch` (`search:{id}` hash); `interface TripRecord { etaMinutes; etaEstimated }`, `loadTrip`, `saveTrip` (`trip:{id}`); `bump()` (`version + 1`).
  - `photographerCard(db, uid)`, `composeRequestMirror(deps, row, at): Promise<InstantRequestMirror>`, `publishRequest(deps, requestId)` (time taken before the read; mirror failures are logged, never thrown).
  - `PAYMENT_WINDOW_MS` (15 min), `activeRequestQuery(db, customerId)`, `interface CreateRequestInput`, `createRequest(deps, customerId, input): Promise<{ requestId; amountVnd; paymentUrl }>` — checks in order: provider enabled (`invalid_argument`), city (`outside_service_area`), package of the current price list (`invalid_argument`), profile (`permission_denied`) and phone (`phone_required`), one active request per customer under a per-customer advisory lock (`conflict`), price (`price_changed {amountVnd}`).
  - `paymentForRequest(trx, requestId)` (locked), `recordCapture(trx, paymentId, amount, now)`, `applySplit(trx, { paymentId, collectedVnd, split, photographerId, releaseAfter, now, note }): Promise<string | null>` (refund row + `refund_issued`, `fee_charged`, payment status/escrow/payee/release_after; throws if the split does not add up).
  - `handlePaymentEvent(deps, event): Promise<WebhookOutcome>` (`pending_payment → searching`, search state, `match` now, `search-timeout`; a payment after cancel or timeout is refunded in full), `expirePayment(deps, requestId)` (job `payment-timeout`), `executeRefund(deps, refundId)` (job `refund`), `heldVnd(deps, paymentId)`.
  - Routes `createRequest`, `paymentWebhook` (POST), `paymentWebhookQuery` (GET), `devPaymentSucceed` (only with the fake gateway).

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/requests.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { buildApp } from '../src/app.js';
import { EmulatorVerifier } from '../src/auth/identity.js';
import { gatewayRegistry } from '../src/payments/gateway.js';
import { fakeSignature } from '../src/payments/fake.js';
import { heldVnd } from '../src/payments/events.js';
import { keys } from '../src/redis/keys.js';
import { expectMirror } from './mirror-schema.js';
import {
  FAKE_SECRET, HCM, PACKAGES, PROJECT_ID, addCustomer, as, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeAll(async () => {
  w = testWorld(db, redis);
  app = await testApp(w);
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});
beforeEach(async () => {
  await resetAll(db, redis);
  await seedCatalog(db);
  await addCustomer(db, 'c1', { name: 'Lan' });
  await addCustomer(db, 'c2', { phone: false });
  w.scheduler.jobs.length = 0;
  w.mirror.requests.clear();
});

const body = (over: object = {}) => ({
  packageId: PACKAGES.p60, genre: 'portrait', meetPoint: { ...HCM, address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' },
  note: 'Áo trắng, cổng chợ', expand: false, expectedAmountVnd: 600_000, provider: 'fake', ...over,
});
const create = (uid: string, over: object = {}) => app.inject({ method: 'POST', url: '/v1/requests', headers: as(uid), payload: body(over) });
const webhook = (payload: object, signature?: string) => {
  const raw = JSON.stringify(payload);
  return app.inject({
    method: 'POST', url: '/v1/payments/webhook/fake', payload: raw,
    headers: { 'content-type': 'application/json', 'x-fake-signature': signature ?? fakeSignature(FAKE_SECRET, raw) },
  });
};
const paymentOf = (requestId: string) =>
  db.selectFrom('payments').selectAll().where('subject_type', '=', 'instant_request').where('subject_id', '=', requestId).executeTakeFirstOrThrow();

describe('POST /v1/requests (S47)', () => {
  it('locks the price, creates the payment and the pending_payment mirror', async () => {
    const res = await create('c1');
    expect(res.statusCode).toBe(201);
    const { requestId, amountVnd, paymentUrl } = res.json() as { requestId: string; amountVnd: number; paymentUrl: string };
    expect(requestId).toMatch(/^[0-9A-HJKMNP-TV-Z]{26}$/);
    expect(amountVnd).toBe(600_000);
    expect(paymentUrl).toBe(`fake://pay/${requestId}`);
    const pay = await paymentOf(requestId);
    expect(pay).toMatchObject({ provider: 'fake', amount: 600_000, status: 'created', escrow_status: 'held', idempotency_key: `instant:${requestId}` });
    const row = await db.selectFrom('dispatch.instant_requests').selectAll().where('id', '=', requestId).executeTakeFirstOrThrow();
    expect(row).toMatchObject({ status: 'pending_payment', amount_vnd: 600_000, payout_vnd: 480_000, city_id: 'hcm', round: 1, note: 'Áo trắng, cổng chợ' });
    const mirror = w.mirror.requests.get(requestId);
    expectMirror('InstantRequestMirror', mirror);
    expect(mirror).toMatchObject({ status: 'pending_payment', customerId: 'c1', meetPoint: null, photographerId: null });
    expect(w.scheduler.pending('payment-timeout').map((j) => j.key)).toEqual([requestId]);
    expect(await redis.hget(keys.search(requestId), 'area')).toBe('Phường Bến Thành, Quận 1');
  });

  it('phone_required, outside_service_area, price_changed (with the new amount), unknown package, disabled provider', async () => {
    expect((await create('c2')).json()).toMatchObject({ code: 'phone_required' });
    expect((await create('c2')).statusCode).toBe(422);
    const out = await create('c1', { meetPoint: { lat: 16.05, lng: 108.2, address: 'Đà Nẵng' } });
    expect([out.statusCode, out.json().code]).toEqual([422, 'outside_service_area']);
    const changed = await create('c1', { expectedAmountVnd: 500_000 });
    expect([changed.statusCode, changed.json().code, changed.json().details]).toEqual([409, 'price_changed', { amountVnd: 600_000 }]);
    expect((await create('c1', { packageId: '01J9ZZZZZZZZZZZZZZZZZZZZZZ' })).statusCode).toBe(400);
    expect((await create('c1', { provider: 'momo' })).json()).toMatchObject({ code: 'invalid_argument', message: 'payment provider not enabled' });
  });

  it('one open request per customer, also when two arrive at once', async () => {
    const [a, b] = await Promise.all([create('c1'), create('c1')]);
    expect([a.statusCode, b.statusCode].sort()).toEqual([201, 409]);
  });
});

describe('payment → searching (webhook, never the redirect)', () => {
  it('a signed paid webhook starts the search, once', async () => {
    const { requestId } = (await create('c1')).json() as { requestId: string };
    const pay = await paymentOf(requestId);
    const first = await webhook({ paymentId: pay.id, status: 'paid', amountVnd: 600_000 });
    expect(first.statusCode).toBe(200);
    expect(first.json()).toEqual({ ok: true, outcome: 'processed' });
    const again = await webhook({ paymentId: pay.id, status: 'paid', amountVnd: 600_000 });
    expect(again.json()).toEqual({ ok: true, outcome: 'duplicate' });
    expect((await paymentOf(requestId)).status).toBe('paid');
    expect(await heldVnd(w.deps, pay.id)).toBe(600_000);
    const ledger = await db.selectFrom('ledger_entries').select(['type', 'amount']).where('payment_id', '=', pay.id).execute();
    expect(ledger).toEqual([{ type: 'deposit_received', amount: 600_000 }]);
    expect(w.mirror.requests.get(requestId)).toMatchObject({ status: 'searching', round: 1, radiusKm: 3, searchEndsAt: '2026-10-01T08:05:00.000Z' });
    expect(w.scheduler.pending('match').map((j) => j.key)).toContain(requestId);
    expect(w.scheduler.pending('search-timeout').map((j) => j.at.toISOString())).toEqual(['2026-10-01T08:05:00.000Z']);
  });

  it('bad signature → 401; wrong amount → recorded as mismatch, nothing changes', async () => {
    const { requestId } = (await create('c1')).json() as { requestId: string };
    const pay = await paymentOf(requestId);
    expect((await webhook({ paymentId: pay.id, status: 'paid', amountVnd: 600_000 }, 'f'.repeat(64))).statusCode).toBe(401);
    expect((await webhook({ paymentId: pay.id, status: 'paid', amountVnd: 1_000 })).json().outcome).toBe('amount_mismatch');
    expect((await paymentOf(requestId)).status).toBe('created');
  });

  it('failed payment → payment_failed', async () => {
    const { requestId } = (await create('c1')).json() as { requestId: string };
    await webhook({ paymentId: (await paymentOf(requestId)).id, status: 'failed' });
    expect(w.mirror.requests.get(requestId)?.status).toBe('payment_failed');
  });

  it('unpaid after 15 minutes → payment_failed; a late payment is refunded in full', async () => {
    const { requestId } = (await create('c1')).json() as { requestId: string };
    await w.advance(15 * 60_000);
    expect(w.mirror.requests.get(requestId)?.status).toBe('payment_failed');
    const pay = await paymentOf(requestId);
    await webhook({ paymentId: pay.id, status: 'paid', amountVnd: 600_000 });
    await w.runDue();
    expect(await paymentOf(requestId)).toMatchObject({ status: 'refunded', escrow_status: 'refunded' });
    expect(await heldVnd(w.deps, pay.id)).toBe(0);
    expect(await db.selectFrom('refunds').select(['amount', 'status']).where('payment_id', '=', pay.id).execute()).toEqual([{ amount: 600_000, status: 'done' }]);
    expect(w.gateway.refunds.map((r) => r.idempotencyKey)).toContain(`instant:${requestId}:refund`);
  });

  it('the dev endpoint exists only with the fake gateway', async () => {
    const live = await buildApp({ deps: { ...w.deps, gateways: gatewayRegistry([]) }, verifier: new EmulatorVerifier({ projectId: PROJECT_ID }) });
    const res = await live.inject({ method: 'POST', url: '/v1/dev/payments/01J9ZZZZZZZZZZZZZZZZZZZZZZ/succeed', headers: as('c1') });
    expect(res.statusCode).toBe(404);
    await live.close();
  });
});
```

In `test/contract.test.ts` remove `'createRequest'`, `'paymentWebhook'`, `'paymentWebhookQuery'`, `'devPaymentSucceed'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/requests.test.ts`
Expected: FAIL: `expected 404 to be 201` and similar (`POST /v1/requests` and the webhooks are not routed yet).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/requests/rows.ts
import { sql } from 'kysely';

import type { Exec } from '../db/database.js';
import type { Genre, InstantRequestStatus, LatLng, PackageCode, Round, SearchState } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { keys } from '../redis/keys.js';

export type { Exec };

export interface RequestRow {
  id: string;
  customerId: string;
  packageId: string;
  packageCode: PackageCode;
  durationMin: number;
  cityId: string;
  genre: Genre;
  meetPoint: LatLng;
  meetAddress: string;
  note: string | null;
  expand: boolean;
  amountVnd: number;
  payoutVnd: number;
  status: InstantRequestStatus;
  photographerId: string | null;
  round: Round;
  requestedAt: Date;
  assignedAt: Date | null;
  arrivedAt: Date | null;
  startedAt: Date | null;
  finishedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  version: number;
}

export const requestQuery = (db: Exec, id: string) =>
  db
    .selectFrom('dispatch.instant_requests as r')
    .innerJoin('dispatch.instant_packages as k', 'k.id', 'r.package_id')
    .select([
      'r.id', 'r.customer_id', 'r.package_id', 'k.code', 'k.duration_min', 'r.city_id', 'r.genre', 'r.meet_address', 'r.note',
      'r.expand', 'r.amount_vnd', 'r.payout_vnd', 'r.status', 'r.photographer_id', 'r.round', 'r.requested_at',
      'r.assigned_at', 'r.arrived_at', 'r.started_at', 'r.finished_at', 'r.completed_at', 'r.cancelled_at', 'r.version',
      sql<number>`ST_Y(r.meet_point::geometry)`.as('lat'),
      sql<number>`ST_X(r.meet_point::geometry)`.as('lng'),
    ])
    .where('r.id', '=', id);

/** Loads a request; with `lock`, first takes the row lock (SELECT … FOR UPDATE) inside the transaction. */
export async function loadRequest(db: Exec, id: string, lock = false): Promise<RequestRow | null> {
  if (lock) {
    const locked = await db.selectFrom('dispatch.instant_requests').select('id').where('id', '=', id).forUpdate().executeTakeFirst();
    if (!locked) return null;
  }
  const r = await requestQuery(db, id).executeTakeFirst();
  if (!r) return null;
  return {
    id: r.id, customerId: r.customer_id, packageId: r.package_id, packageCode: r.code, durationMin: r.duration_min, cityId: r.city_id,
    genre: r.genre, meetPoint: { lat: Number(r.lat), lng: Number(r.lng) }, meetAddress: r.meet_address, note: r.note,
    expand: r.expand, amountVnd: r.amount_vnd, payoutVnd: r.payout_vnd, status: r.status, photographerId: r.photographer_id,
    round: r.round, requestedAt: r.requested_at, assignedAt: r.assigned_at, arrivedAt: r.arrived_at, startedAt: r.started_at,
    finishedAt: r.finished_at, completedAt: r.completed_at, cancelledAt: r.cancelled_at, version: r.version,
  };
}

/** Search state of a searching request, plus what offers need (neighbourhood label). */
export interface SearchRecord {
  state: SearchState;
  area: string;
}

export async function loadSearch(deps: Pick<Deps, 'redis'>, requestId: string): Promise<SearchRecord | null> {
  const h = await deps.redis.hgetall(keys.search(requestId));
  if (!h.startedAt) return null;
  return {
    state: {
      startedAt: new Date(Number(h.startedAt)),
      expand: h.expand === '1',
      round: h.round === '2' ? 2 : 1,
      radiusIndex: Number(h.radiusIndex ?? 0),
      roundStartedAt: new Date(Number(h.roundStartedAt ?? h.startedAt)),
    },
    area: h.area ?? '',
  };
}

export async function saveSearch(deps: Pick<Deps, 'redis'>, requestId: string, rec: SearchRecord): Promise<void> {
  await deps.redis.hset(keys.search(requestId), {
    startedAt: String(rec.state.startedAt.getTime()),
    expand: rec.state.expand ? '1' : '0',
    round: String(rec.state.round),
    radiusIndex: String(rec.state.radiusIndex),
    roundStartedAt: String(rec.state.roundStartedAt.getTime()),
    area: rec.area,
  });
}

export interface TripRecord {
  etaMinutes: number;
  etaEstimated: boolean;
}

export async function loadTrip(deps: Pick<Deps, 'redis'>, requestId: string): Promise<TripRecord | null> {
  const h = await deps.redis.hgetall(keys.trip(requestId));
  if (!h.etaMinutes) return null;
  return { etaMinutes: Number(h.etaMinutes), etaEstimated: h.etaEstimated === '1' };
}

export async function saveTrip(deps: Pick<Deps, 'redis'>, requestId: string, t: TripRecord): Promise<void> {
  await deps.redis.hset(keys.trip(requestId), { etaMinutes: String(t.etaMinutes), etaEstimated: t.etaEstimated ? '1' : '0' });
}

/** Version bump that every status change performs (data-model README §2.9). */
export const bump = () => sql<number>`version + 1`;
```

```ts
// services/dispatch/src/requests/publish.ts
import { cityConfig } from '../catalog/catalog.js';
import { graceEndsAt, radiusKm, searchEndsAt } from '../domain/core.js';
import type { Deps } from '../deps.js';
import type { InstantRequestMirror } from '../mirror/mirror.js';
import { loadRequest, loadSearch, loadTrip, type Exec, type RequestRow } from './rows.js';

const iso = (d: Date | null): string | null => (d === null ? null : d.toISOString());

export async function photographerCard(db: Exec, uid: string): Promise<NonNullable<InstantRequestMirror['photographer']> | null> {
  const r = await db
    .selectFrom('photographers as p')
    .innerJoin('users as u', 'u.id', 'p.user_id')
    .leftJoin('files as f', 'f.id', 'u.avatar_file_id')
    .select(['u.display_name', 'f.storage_provider', 'f.storage_key', 'p.verified', 'p.rating_avg', 'p.review_count', 'p.completed_count'])
    .where('p.user_id', '=', uid)
    .executeTakeFirst();
  if (!r) return null;
  return {
    uid,
    displayName: r.display_name,
    avatarUrl: r.storage_provider === 'external' ? r.storage_key : null,
    verified: r.verified,
    rating: r.review_count > 0 ? Number(r.rating_avg) : null,
    completedShoots: r.completed_count,
  };
}

/** The InstantRequestMirror of a request, built from PostgreSQL (truth) and Redis (search/trip state). */
export async function composeRequestMirror(deps: Deps, row: RequestRow, at: Date): Promise<InstantRequestMirror> {
  const cfg = cityConfig(deps, row.cityId);
  const search = row.status === 'searching' ? await loadSearch(deps, row.id) : null;
  const trip = row.status === 'assigned' || row.status === 'en_route' ? await loadTrip(deps, row.id) : null;
  const refunded = await deps.db
    .selectFrom('refunds as f')
    .innerJoin('payments as p', 'p.id', 'f.payment_id')
    .select((eb) => eb.fn.sum<number>('f.amount').as('total'))
    .where('p.subject_type', '=', 'instant_request')
    .where('p.subject_id', '=', row.id)
    .where('f.status', '<>', 'failed')
    .executeTakeFirst();
  const refundTotal = refunded?.total === null || refunded?.total === undefined ? null : Number(refunded.total);
  const showGrace = row.status === 'assigned' || row.status === 'en_route';
  return {
    status: row.status,
    customerId: row.customerId,
    photographerId: row.photographerId,
    photographer: row.photographerId ? await photographerCard(deps.db, row.photographerId) : null,
    packageCode: row.packageCode,
    genre: row.genre,
    amountVnd: row.amountVnd,
    expand: row.expand,
    round: row.round,
    ...(search
      ? { radiusKm: radiusKm(search.state, cfg), searchEndsAt: searchEndsAt(search.state, cfg).toISOString() }
      : { searchEndsAt: null }),
    etaMinutes: trip?.etaMinutes ?? null,
    etaEstimated: trip?.etaEstimated ?? false,
    graceEndsAt: showGrace ? iso(graceEndsAt(row.assignedAt, cfg)) : null,
    meetPoint: row.assignedAt !== null ? { lat: row.meetPoint.lat, lng: row.meetPoint.lng, address: row.meetAddress } : null,
    requestedAt: row.requestedAt.toISOString(),
    assignedAt: iso(row.assignedAt),
    arrivedAt: iso(row.arrivedAt),
    startedAt: iso(row.startedAt),
    finishedAt: iso(row.finishedAt),
    refundVnd: refundTotal,
    updatedAt: at.toISOString(),
  };
}

/** Re-reads the request and overwrites its mirror. Call after every commit that changed it. */
export async function publishRequest(deps: Deps, requestId: string): Promise<void> {
  const at = deps.clock.now(); // taken before the read: a slower, older writer loses (MirrorWriter.putRequest)
  const row = await loadRequest(deps.db, requestId);
  if (!row) return;
  try {
    await deps.mirror.putRequest(requestId, await composeRequestMirror(deps, row, at));
  } catch (err) {
    deps.log.warn({ requestId, error: (err as Error).name }, 'mirror_write_failed');
  }
}
```

```ts
// services/dispatch/src/requests/create.ts
import { sql } from 'kysely';

import { cityAt, cityConfig, currentPriceListVersion } from '../catalog/catalog.js';
import { ewktPoint } from '../db/database.js';
import { ACTIVE_STATUSES, DispatchError, quotePrice, type Genre, type PaymentProvider } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { areaFromAddress } from '../eta/eta.js';
import { ApiError } from '../errors.js';
import { newId } from '../ids.js';
import { keys } from '../redis/keys.js';
import { publishRequest } from './publish.js';
import type { Exec } from './rows.js';

/** How long the customer has to pay before the request becomes payment_failed. */
export const PAYMENT_WINDOW_MS = 15 * 60_000;

/** The customer's open request, if any (index instant_requests_customer). */
export const activeRequestQuery = (db: Exec, customerId: string) =>
  db.selectFrom('dispatch.instant_requests').select('id').where('customer_id', '=', customerId).where('status', 'in', ACTIVE_STATUSES);

export interface CreateRequestInput {
  packageId: string;
  genre: Genre;
  meetPoint: { lat: number; lng: number; address: string };
  note?: string;
  expand: boolean;
  expectedAmountVnd: number;
  provider: PaymentProvider;
}

export interface CreatedRequest {
  requestId: string;
  amountVnd: number;
  paymentUrl: string;
}

/**
 * POST /v1/requests (spec §4, §6): price locked into the request, one payment row, status
 * pending_payment. Checks, in order: provider enabled, service area, package, profile and phone
 * (phone_required, spec main §3b.1), one active request per customer, price unchanged.
 */
export async function createRequest(deps: Deps, customerId: string, input: CreateRequestInput): Promise<CreatedRequest> {
  const gateway = deps.gateways.get(input.provider);
  if (!gateway) throw new ApiError('invalid_argument', 'payment provider not enabled');
  const city = await cityAt(deps.db, input.meetPoint);
  if (!city) throw new DispatchError('outside_service_area');
  const cfg = cityConfig(deps, city.id);
  const version = await currentPriceListVersion(deps.db);
  const pkg = await deps.db
    .selectFrom('dispatch.instant_packages')
    .selectAll()
    .where('id', '=', input.packageId)
    .where('active', '=', true)
    .where('price_list_version', '=', version)
    .executeTakeFirst();
  if (!pkg) throw new ApiError('invalid_argument', 'unknown package');
  const profile = await deps.db
    .selectFrom('users as u')
    .leftJoin('user_contacts as c', 'c.user_id', 'u.id')
    .select(['u.id', 'c.phone_e164'])
    .where('u.id', '=', customerId)
    .where('u.deleted_at', 'is', null)
    .executeTakeFirst();
  if (!profile) throw new DispatchError('permission_denied', { reason: 'no profile' });
  if (!profile.phone_e164) throw new DispatchError('phone_required');
  const quote = quotePrice(pkg.price_vnd, city.surge, cfg);
  if (quote.amountVnd !== input.expectedAmountVnd) throw new DispatchError('price_changed', { amountVnd: quote.amountVnd });

  const now = deps.clock.now();
  const requestId = newId(now.getTime());
  const paymentId = newId(now.getTime());
  await deps.db.transaction().execute(async (trx) => {
    // Serialise this customer's creates so "one active request" holds under concurrency.
    await sql`select pg_advisory_xact_lock(hashtext(${`instant:${customerId}`}))`.execute(trx);
    const open = await activeRequestQuery(trx, customerId).executeTakeFirst();
    if (open) throw new DispatchError('conflict', { reason: 'an instant request is already open', requestId: open.id });
    await trx
      .insertInto('dispatch.instant_requests')
      .values({
        id: requestId, customer_id: customerId, package_id: pkg.id, city_id: city.id, genre: input.genre,
        meet_point: ewktPoint(input.meetPoint), meet_address: input.meetPoint.address, note: input.note ?? null,
        expand: input.expand, amount_vnd: quote.amountVnd, payout_vnd: quote.payoutVnd, status: 'pending_payment',
        round: 1, requested_at: now,
      })
      .execute();
    await trx
      .insertInto('payments')
      .values({
        id: paymentId, subject_type: 'instant_request', subject_id: requestId, provider: input.provider,
        amount: quote.amountVnd, status: 'created', idempotency_key: `instant:${requestId}`,
      })
      .execute();
  });

  const created = await gateway.createPayment({
    paymentId,
    idempotencyKey: `instant:${requestId}`,
    subject: { type: 'instant_request', id: requestId },
    amountVnd: quote.amountVnd,
    description: `Chụp ngay ${pkg.code} - ${requestId}`,
    returnUrl: deps.returnUrlFor(requestId),
    expiresAt: new Date(now.getTime() + PAYMENT_WINDOW_MS),
  });
  await deps.db.updateTable('payments').set({ provider_ref: created.providerRef, raw: JSON.stringify(created.raw) }).where('id', '=', paymentId).execute();

  // The offer shows only the neighbourhood (spec §2.2): resolve it now, while the customer pays.
  const area = (await deps.area.areaOf(input.meetPoint)) ?? areaFromAddress(input.meetPoint.address, city.name);
  await deps.redis.hset(keys.search(requestId), 'area', area);
  await deps.scheduler.schedule('payment-timeout', requestId, new Date(now.getTime() + PAYMENT_WINDOW_MS));
  await publishRequest(deps, requestId);
  return { requestId, amountVnd: quote.amountVnd, paymentUrl: created.paymentUrl };
}
```

```ts
// services/dispatch/src/payments/ledger.ts
import type { Transaction } from 'kysely';

import type { Database } from '../db/database.js';
import type { MoneySplit } from '../domain/core.js';
import { newId } from '../ids.js';

type Trx = Transaction<Database>;

/**
 * Ledger conventions for instant requests (relational-schema.md §2.4, spec main §3g.5), append-only:
 *  - capture:      deposit_received  +amount   (account_owner_id null: the platform holds it, escrow `held`)
 *  - refund:       refund_issued     −refund   (refund_id set)
 *  - settlement:   fee_charged       +platform (only when > 0; informational, not part of *_received)
 * The photographer's share stays held on the payment (payee_id, release_after) until the escrow
 * release job (payments plan / I6) writes `escrow_released`. Invariant (domain-model §6.11):
 * Σ deposit_received + Σ refund_issued = amount − refunds = photographerVnd + platformVnd.
 */
/** The request's payment row, locked. */
export function paymentForRequest(trx: Trx, requestId: string) {
  return trx
    .selectFrom('payments')
    .select(['id', 'amount', 'status', 'provider_ref'])
    .where('subject_type', '=', 'instant_request')
    .where('subject_id', '=', requestId)
    .forUpdate()
    .executeTakeFirst();
}

export async function recordCapture(trx: Trx, paymentId: string, amount: number, now: Date): Promise<void> {
  await trx
    .insertInto('ledger_entries')
    .values({ id: newId(now.getTime()), type: 'deposit_received', payment_id: paymentId, amount, note: 'instant_request', at: now })
    .execute();
}

/**
 * Applies a settlement split to the captured payment: refund row + refund_issued, fee_charged,
 * payee/escrow fields. Returns the refund id when money goes back (the `refund` job calls the gateway).
 */
export async function applySplit(
  trx: Trx,
  input: {
    paymentId: string;
    collectedVnd: number;
    split: MoneySplit;
    photographerId: string | null;
    releaseAfter: Date | null;
    now: Date;
    note: string;
  },
): Promise<string | null> {
  const { split, now } = input;
  if (split.refundVnd + split.photographerVnd + split.platformVnd !== input.collectedVnd) {
    throw new Error(`settlement does not add up for payment ${input.paymentId}`);
  }
  let refundId: string | null = null;
  if (split.refundVnd > 0) {
    refundId = newId(now.getTime());
    const percent = Math.floor((split.refundVnd * 100) / input.collectedVnd);
    await trx.insertInto('refunds').values({ id: refundId, payment_id: input.paymentId, amount: split.refundVnd, percent, status: 'pending' }).execute();
    await trx
      .insertInto('ledger_entries')
      .values({ id: newId(now.getTime()), type: 'refund_issued', payment_id: input.paymentId, refund_id: refundId, amount: -split.refundVnd, note: input.note, at: now })
      .execute();
  }
  if (split.platformVnd > 0) {
    await trx
      .insertInto('ledger_entries')
      .values({ id: newId(now.getTime()), type: 'fee_charged', payment_id: input.paymentId, amount: split.platformVnd, note: input.note, at: now })
      .execute();
  }
  const fullRefund = split.refundVnd === input.collectedVnd;
  const partial = split.refundVnd > 0 && !fullRefund;
  await trx
    .updateTable('payments')
    .set({
      status: fullRefund ? 'refunded' : partial ? 'partially_refunded' : 'paid',
      escrow_status: fullRefund ? 'refunded' : partial ? 'partially_refunded' : 'held',
      payee_id: split.photographerVnd > 0 ? input.photographerId : null,
      release_after: split.photographerVnd > 0 ? input.releaseAfter : null,
    })
    .where('id', '=', input.paymentId)
    .execute();
  return refundId;
}
```

```ts
// services/dispatch/src/payments/events.ts
import { sql } from 'kysely';

import { cityById, cityConfig } from '../catalog/catalog.js';
import { searchEndsAt, settleNoMatch, startSearch, transition } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { publishRequest } from '../requests/publish.js';
import { bump, loadRequest, saveSearch } from '../requests/rows.js';
import { keys } from '../redis/keys.js';
import type { PaymentEvent, WebhookOutcome } from './gateway.js';
import { applySplit, recordCapture } from './ledger.js';

/**
 * use case handle_payment_notification for instant requests: a verified provider event (or the
 * dev endpoint) moves pending_payment → searching and starts the search. Idempotent.
 */
type TxResult =
  | { outcome: 'unknown_payment' | 'duplicate' | 'amount_mismatch' }
  | { outcome: 'processed'; requestId: string; refundId: string | null; search: { expand: boolean; cityId: string } | null };

export async function handlePaymentEvent(deps: Deps, event: PaymentEvent): Promise<WebhookOutcome> {
  const now = deps.clock.now();
  const result = await deps.db.transaction().execute(async (trx): Promise<TxResult> => {
    const pay = await trx
      .selectFrom('payments')
      .select(['id', 'amount', 'status', 'subject_type', 'subject_id'])
      .where('id', '=', event.paymentId)
      .forUpdate()
      .executeTakeFirst();
    if (!pay || pay.subject_type !== 'instant_request') return { outcome: 'unknown_payment' };
    const req = await loadRequest(trx, pay.subject_id, true);
    if (!req) return { outcome: 'unknown_payment' };
    if (pay.status !== 'created') return { outcome: 'duplicate' };

    if (event.kind === 'failed') {
      await trx.updateTable('payments').set({ status: 'failed', provider_ref: event.providerRef, raw: JSON.stringify(event.raw) }).where('id', '=', pay.id).execute();
      const t = transition(req, 'payment_failed', now, cityConfig(deps, req.cityId));
      if (t.ok) {
        await trx.updateTable('dispatch.instant_requests').set({ status: t.to, version: bump() }).where('id', '=', req.id).execute();
      }
      return { outcome: 'processed', requestId: req.id, refundId: null, search: null };
    }

    if (event.amountVnd !== pay.amount) return { outcome: 'amount_mismatch' };
    await trx.updateTable('payments').set({ status: 'paid', provider_ref: event.providerRef, raw: JSON.stringify(event.raw) }).where('id', '=', pay.id).execute();
    await recordCapture(trx, pay.id, pay.amount, now);

    const t = transition(req, 'payment_succeeded', now, cityConfig(deps, req.cityId));
    if (t.ok) {
      await trx.updateTable('dispatch.instant_requests').set({ status: 'searching', version: bump() }).where('id', '=', req.id).execute();
      return { outcome: 'processed', requestId: req.id, refundId: null, search: { expand: req.expand, cityId: req.cityId } };
    }
    // Paid after the customer cancelled or the payment window closed: give it all back.
    const refundId = await applySplit(trx, {
      paymentId: pay.id, collectedVnd: pay.amount, split: settleNoMatch(pay.amount), photographerId: null,
      releaseAfter: null, now, note: 'instant late payment',
    });
    return { outcome: 'processed', requestId: req.id, refundId, search: null };
  });

  if (result.outcome !== 'processed') {
    if (result.outcome === 'amount_mismatch') deps.log.error({ paymentId: event.paymentId }, 'payment_amount_mismatch');
    return result.outcome;
  }
  if (result.search) {
    const cfg = cityConfig(deps, result.search.cityId);
    const state = startSearch(now, result.search.expand);
    const area = (await deps.redis.hget(keys.search(result.requestId), 'area')) ?? (await cityById(deps.db, result.search.cityId))?.name ?? '';
    await saveSearch(deps, result.requestId, { state, area });
    await deps.scheduler.schedule('match', result.requestId, now);
    await deps.scheduler.schedule('search-timeout', result.requestId, searchEndsAt(state, cfg));
  }
  if (result.refundId) await deps.scheduler.schedule('refund', result.refundId, now);
  await publishRequest(deps, result.requestId);
  return 'processed';
}

/** Job `payment-timeout`: still unpaid after the payment window → payment_failed (spec §10). */
export async function expirePayment(deps: Deps, requestId: string): Promise<void> {
  const now = deps.clock.now();
  const changed = await deps.db.transaction().execute(async (trx) => {
    const req = await loadRequest(trx, requestId, true);
    if (!req || req.status !== 'pending_payment') return false;
    // The payment row stays `created`: if the provider confirms late, handlePaymentEvent refunds it in full.
    await trx.updateTable('dispatch.instant_requests').set({ status: 'payment_failed', version: bump() }).where('id', '=', requestId).execute();
    return true;
  });
  if (changed) await publishRequest(deps, requestId);
}

/** Job `refund`: asks the provider to send a pending refund back (retried by BullMQ on retryable failures). */
export async function executeRefund(deps: Deps, refundId: string): Promise<void> {
  const r = await deps.db
    .selectFrom('refunds as f')
    .innerJoin('payments as p', 'p.id', 'f.payment_id')
    .select(['f.id', 'f.amount', 'f.status', 'f.manual', 'p.id as payment_id', 'p.amount as payment_amount', 'p.provider', 'p.provider_ref', 'p.subject_id'])
    .where('f.id', '=', refundId)
    .executeTakeFirst();
  if (!r || r.status !== 'pending' || r.manual) return;
  const gw = deps.gateways.get(r.provider);
  if (!gw) {
    await deps.db.updateTable('refunds').set({ manual: true }).where('id', '=', refundId).execute();
    return;
  }
  const res = await gw.refund({
    refundId: r.id,
    idempotencyKey: `instant:${r.subject_id}:refund`,
    paymentId: r.payment_id,
    providerRef: r.provider_ref,
    amountVnd: r.amount,
    paymentAmountVnd: r.payment_amount,
    reason: 'instant refund',
  });
  switch (res.status) {
    case 'done':
      await deps.db.updateTable('refunds').set({ status: 'done' }).where('id', '=', refundId).execute();
      return;
    case 'pending':
      return;
    case 'manual':
      await deps.db.updateTable('refunds').set({ manual: true }).where('id', '=', refundId).execute();
      return;
    case 'failed':
      if (res.retryable) throw new Error(`refund ${refundId} failed, will retry`);
      await deps.db.updateTable('refunds').set({ status: 'failed', manual: true }).where('id', '=', refundId).execute();
  }
}

/** Ledger total of a payment: Σ deposit_received + Σ refund_issued (what is still held). */
export async function heldVnd(deps: Pick<Deps, 'db'>, paymentId: string): Promise<number> {
  const r = await deps.db
    .selectFrom('ledger_entries')
    .select(sql<string>`coalesce(sum(amount) filter (where type in ('deposit_received','refund_issued')), 0)`.as('held'))
    .where('payment_id', '=', paymentId)
    .executeTakeFirstOrThrow();
  return Number(r.held);
}
```

```ts
// services/dispatch/src/routes/requests.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { createRequest } from '../requests/create.js';

type S = components['schemas'];

export function registerRequestRoutes(app: FastifyInstance, deps: RouteDeps): void {
  const c = deps.contract;
  app.route<{ Body: S['CreateRequestBody'] }>({
    ...route(c, 'createRequest'),
    handler: async (req, reply) => {
      const b = req.body;
      const created = await createRequest(deps, principalOf(req).uid, {
        packageId: b.packageId, genre: b.genre, meetPoint: b.meetPoint, note: b.note, expand: b.expand,
        expectedAmountVnd: b.expectedAmountVnd, provider: b.provider,
      });
      return reply.status(201).send(created satisfies S['CreateRequestResponse']);
    },
  });
}
```

```ts
// services/dispatch/src/routes/payments.ts
import type { FastifyInstance, FastifyRequest } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import { DispatchError, isPaymentProvider, type PaymentProvider } from '../domain/core.js';
import { ApiError } from '../errors.js';
import { handlePaymentEvent } from '../payments/events.js';
import type { WebhookOutcome, WebhookRequest } from '../payments/gateway.js';
import { loadRequest } from '../requests/rows.js';

function webhookRequest(req: FastifyRequest<{ Params: { provider: string } }>, provider: PaymentProvider): WebhookRequest {
  const headers: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(req.headers)) headers[k.toLowerCase()] = Array.isArray(v) ? v.join(',') : v;
  const query: Record<string, string> = {};
  for (const [k, v] of Object.entries((req.query ?? {}) as Record<string, unknown>)) if (typeof v === 'string') query[k] = v;
  return { provider, method: req.method === 'GET' ? 'GET' : 'POST', headers, query, rawBody: (req as { rawBody?: string }).rawBody ?? '' };
}

/**
 * Provider webhooks (MoMo POST, VNPay GET, fake POST) and, only with the fake gateway, the dev
 * endpoint. Webhooks are public: the gateway's signature check is the authentication.
 */
export function registerPaymentRoutes(app: FastifyInstance, deps: RouteDeps): void {
  const c = deps.contract;
  void app.register(async (scope) => {
    // Signatures are over the exact body bytes: keep them (scoped to this plugin only).
    scope.removeContentTypeParser('application/json');
    scope.addContentTypeParser('application/json', { parseAs: 'string' }, (req, body, done) => {
      (req as { rawBody?: string }).rawBody = body as string;
      try {
        done(null, body === '' ? {} : JSON.parse(body as string));
      } catch {
        done(new ApiError('invalid_argument', 'body is not JSON'), undefined);
      }
    });
    for (const operationId of ['paymentWebhook', 'paymentWebhookQuery'] as const) {
      const opts = route(c, operationId);
      scope.route<{ Params: { provider: string } }>({
        ...opts,
        schema: { params: opts.schema.params }, // the body and the answer belong to the provider
        config: { public: true },
        handler: async (req, reply) => {
          const provider = req.params.provider;
          const gw = isPaymentProvider(provider) ? deps.gateways.get(provider) : undefined;
          if (!gw || !isPaymentProvider(provider)) throw new DispatchError('not_found');
          const v = await gw.verifyWebhook(webhookRequest(req, provider));
          let outcome: WebhookOutcome;
          if (!v.ok) outcome = v.reason;
          else {
            try {
              outcome = await handlePaymentEvent(deps, v.event);
            } catch (err) {
              req.log.error({ error: (err as Error).name }, 'payment_webhook_failed');
              outcome = 'error';
            }
          }
          const ack = gw.acknowledge(outcome);
          if (ack.headers) void reply.headers(ack.headers);
          return ack.body === null ? reply.status(ack.status).send() : reply.status(ack.status).send(ack.body);
        },
      });
    }
  });

  if (!deps.gateways.get('fake')) return;
  app.route<{ Params: { requestId: string } }>({
    ...route(c, 'devPaymentSucceed'),
    handler: async (req, reply) => {
      const r = await loadRequest(deps.db, req.params.requestId);
      if (!r) throw new DispatchError('not_found');
      if (r.customerId !== principalOf(req).uid) throw new DispatchError('permission_denied');
      const pay = await deps.db
        .selectFrom('payments')
        .select(['id', 'amount'])
        .where('subject_type', '=', 'instant_request')
        .where('subject_id', '=', r.id)
        .executeTakeFirstOrThrow();
      await handlePaymentEvent(deps, { kind: 'paid', paymentId: pay.id, providerRef: `fake-${pay.id}`, amountVnd: pay.amount, raw: { provider: 'fake', dev: true } });
      return reply.status(204).send();
    },
  });
}
```

Replace `services/dispatch/src/jobs/handlers.ts` with:

```ts
// services/dispatch/src/jobs/handlers.ts
import type { Deps } from '../deps.js';
import { executeRefund, expirePayment } from '../payments/events.js';
import type { JobHandlers } from './scheduler.js';

/** Timer handlers by job name. Each feature task adds its own; a job without a handler fails and BullMQ retries it. */
export function jobHandlers(deps: Deps): JobHandlers {
  return {
    'payment-timeout': (requestId) => expirePayment(deps, requestId),
    refund: (refundId) => executeRefund(deps, refundId),
  };
}
```

In `src/app.ts` add the import

```ts
import { registerRequestRoutes } from './routes/requests.js';
import { registerPaymentRoutes } from './routes/payments.js';
```

and, after the previous `register…Routes(app, deps);` line,

```ts
  registerRequestRoutes(app, deps);
  registerPaymentRoutes(app, deps);
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  11 passed | 1 skipped (12)`, `Tests  57 passed | 3 skipped (60)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): instant requests with locked price, fake-gateway payments, webhooks, ledger capture and refunds, request mirror

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Matcher: rounds, radius, offer locks, no-match refund

**Files:**
- Create: `services/dispatch/src/matcher/matcher.ts`, `services/dispatch/test/matcher.test.ts`
- Modify: `services/dispatch/src/jobs/handlers.ts` (replace)

**Interfaces:**
- Consumes: `nextSearchStep`, `onNobodyLeft`, `lastOfferAt`, `searchEndsAt`, `rankCandidates`, `settleNoMatch`, `OPEN_JOB_STATUSES`, `addMs` (plan I2); `loadRequest`, `loadSearch`, `saveSearch`, `publishRequest`, `applySplit`, `paymentForRequest` (Task 10); `bumpReliability` (Task 9); `keys`, `COMPARE_AND_DELETE` (Task 6).
- Produces:
  - `type MatchResult = { kind: 'offered'; offerId; photographerId } | { kind: 'waiting'; retryAt } | { kind: 'no_match' } | { kind: 'skipped'; reason: 'locked' | 'not_searching' | 'offer_pending' | 'no_state' }`.
  - `runMatch(deps, requestId): Promise<MatchResult>` (one run under `matchlock:{id}`; observes `matcher_ms` and `first_offer_ms`); `finishNoMatch(deps, req)`; `searchTimeout(deps, requestId)` (job `search-timeout`, reschedules itself when the end moved).
  - Hot query builders (EXPLAIN in Task 16): `offeredQuery(db, requestId)`, `busyQuery(db, ids)`, `pendingOfferQuery(db, requestId)`.
  - Redis per run that offers: `SET matchlock NX PX`, `HGETALL search`, `GEOSEARCH … BYRADIUS r km ASC COUNT 50 WITHCOORD`, `MGET pfacts:*`, `SET offerlock:{uid} <offerId> NX PX 30000`, `HSET search`, `EVAL` (release), plus the mirror read of `search`; stale GEO members (no `pfacts`) are removed with `ZREM`.

Run steps: request must be `searching` with no pending offer → `nextSearchStep` (time limits, round 2 switch) → no offer if it could not run its 30 s before the end → candidates from `GEOSEARCH` + cached facts → `rankCandidates` with `excluded` (every photographer already offered this request, from `instant_offers`) and `busy` (open job, from the one-open-job index) → first candidate whose `offerlock` is free gets the offer (insert with `ON CONFLICT (request_id, photographer_id) DO NOTHING`, reliability `offers + 1`), mirror `instant_offers/{uid}`, FCM `offer` (the same fields), job `offer-expire` at +30 s. Nobody eligible → `onNobodyLeft` (widen now, or early round 2, or `match` again in 5 s); everybody locked → `match` again in 5 s without widening.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/matcher.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { heldVnd } from '../src/payments/events.js';
import { keys } from '../src/redis/keys.js';
import { expectMirror } from './mirror-schema.js';
import {
  HCM, addCustomer, addPhotographer, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});
beforeAll(() => undefined);

const pendingOffers = () => db.selectFrom('dispatch.instant_offers').selectAll().where('outcome', '=', 'pending').execute();

describe('matcher (spec §3.2, §5)', () => {
  it('offers the best nearby priority photographer first, with the contract offer mirror and a push', async () => {
    await addPhotographer(db, 'near');
    await addPhotographer(db, 'far');
    await online(app, 'near', north(HCM, 0.5), w.clock.now());
    await online(app, 'far', north(HCM, 2.5), w.clock.now());
    const id = await paidRequest(app, 'c1');
    await w.runDue();
    const [offer] = await pendingOffers();
    expect(offer).toMatchObject({ request_id: id, photographer_id: 'near', round: 1 });
    expect(Number(offer?.score)).toBeGreaterThan(0.5);
    expect((offer?.reasons as Array<{ code: string }>).map((r) => r.code)).toContain('near');
    const doc = w.mirror.offers.get('near');
    expectMirror('InstantOfferMirror', doc);
    expect(doc).toEqual({
      offerId: offer?.id, requestId: id, packageCode: 'p60', genre: 'portrait', payoutVnd: 480_000, distanceKm: 0.5, travelMinutes: 3,
      area: 'Phường Bến Thành, Quận 1', note: null, expiresAt: '2026-10-01T08:00:30.000Z',
    });
    expect(w.push.to('near')).toEqual([{ type: 'offer', ...doc }]);
    expect(await redis.get(keys.offerLock('near'))).toBe(offer?.id);
    expect(w.scheduler.pending('offer-expire').map((j) => [j.key, j.at.toISOString()])).toEqual([[offer?.id, '2026-10-01T08:00:30.000Z']]);
    const rel = await db.selectFrom('dispatch.photographer_reliability').selectAll().where('photographer_id', '=', 'near').executeTakeFirstOrThrow();
    expect(rel.offers).toBe(1);
  });

  it('widens 3 → 6 → 10 km only when nobody is left in the current radius', async () => {
    await addPhotographer(db, 'at5');
    await online(app, 'at5', north(HCM, 5), w.clock.now());
    const id = await paidRequest(app, 'c1');
    await w.runDue();
    expect((await pendingOffers()).map((o) => o.photographer_id)).toEqual(['at5']);
    expect(w.mirror.requests.get(id)).toMatchObject({ radiusKm: 6, round: 1 });
  });

  it('round 1 skips the expanded tier; with "Mở rộng tìm kiếm" round 2 reaches them', async () => {
    await addPhotographer(db, 'newbie', { verified: false });
    await online(app, 'newbie', north(HCM, 1), w.clock.now());
    const plain = await paidRequest(app, 'c1');
    await w.runDue();
    expect(await pendingOffers()).toEqual([]);
    expect(w.scheduler.pending('match').length).toBeGreaterThan(0); // waiting, looks again in 5 s
    await w.advance(5 * 60_000);
    expect(w.mirror.requests.get(plain)?.status).toBe('no_match');

    await addCustomer(db, 'c2');
    const wide = await paidRequest(app, 'c2', { expand: true });
    await w.runDue();
    const [offer] = await pendingOffers();
    expect(offer).toMatchObject({ request_id: wide, photographer_id: 'newbie', round: 2 });
    expect(w.mirror.requests.get(wide)).toMatchObject({ round: 2, radiusKm: 10 });
  });

  it('nobody within 5 minutes → no_match, 100 % refund, customer told', async () => {
    const id = await paidRequest(app, 'c1');
    await w.runDue();
    await w.advance(5 * 60_000);
    const mirror = w.mirror.requests.get(id);
    expectMirror('InstantRequestMirror', mirror);
    expect(mirror).toMatchObject({ status: 'no_match', refundVnd: 600_000 });
    const pay = await db.selectFrom('payments').selectAll().where('subject_id', '=', id).executeTakeFirstOrThrow();
    expect(pay).toMatchObject({ status: 'refunded', escrow_status: 'refunded' });
    expect(await heldVnd(w.deps, pay.id)).toBe(0);
    expect(w.push.to('c1')).toContainEqual({ type: 'status', requestId: id, status: 'no_match' });
    expect(await redis.exists(keys.search(id))).toBe(0);
  });

  it('presence that expired (TTL) is pruned and never offered', async () => {
    await addPhotographer(db, 'gone');
    await online(app, 'gone', north(HCM, 0.5), w.clock.now());
    await redis.del(keys.facts('gone'), keys.presence('gone')); // what the 10-minute TTL does
    await paidRequest(app, 'c1');
    await w.runDue();
    expect(await pendingOffers()).toEqual([]);
    expect(await redis.zscore(keys.online('hcm'), 'gone')).toBeNull();
  });

  it('a photographer holding another offer is skipped (one open offer per photographer)', async () => {
    await addPhotographer(db, 'only');
    await online(app, 'only', north(HCM, 0.5), w.clock.now());
    await addCustomer(db, 'c2');
    const first = await paidRequest(app, 'c1');
    await w.runDue();
    const second = await paidRequest(app, 'c2');
    await w.runDue();
    const offers = await pendingOffers();
    expect(offers.map((o) => [o.request_id, o.photographer_id])).toEqual([[first, 'only']]);
    expect(second).not.toBe(first);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/matcher.test.ts`
Expected: FAIL, `no handler for job match` (the scheduler has nothing to run yet).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/matcher/matcher.ts
import { cityConfig, currentPriceListVersion } from '../catalog/catalog.js';
import {
  OPEN_JOB_STATUSES, addMs, lastOfferAt, nextSearchStep, onNobodyLeft, rankCandidates, searchEndsAt, settleNoMatch,
  type DispatchConfig, type OnlineCandidate, type PhotographerFacts, type SearchState,
} from '../domain/core.js';
import type { Db } from '../db/database.js';
import type { Deps } from '../deps.js';
import { newId } from '../ids.js';
import { applySplit, paymentForRequest } from '../payments/ledger.js';
import { publishRequest } from '../requests/publish.js';
import { bump, loadRequest, loadSearch, saveSearch, type RequestRow } from '../requests/rows.js';
import { COMPARE_AND_DELETE, keys } from '../redis/keys.js';
import { bumpReliability } from '../settings/facts.js';

export type MatchResult =
  | { kind: 'offered'; offerId: string; photographerId: string }
  | { kind: 'waiting'; retryAt: Date }
  | { kind: 'no_match' }
  | { kind: 'skipped'; reason: 'locked' | 'not_searching' | 'offer_pending' | 'no_state' };

/**
 * One matcher run for a searching request (spec §5 `matcher`): applies the round/radius policy,
 * GEOSEARCH online:{city}, filters and scores with dispatch-core, then reserves the best free
 * photographer with SET offerlock:{uid} NX PX offerTtl and creates the offer. At most one pending
 * offer per request and per photographer; never the same photographer twice for a request.
 */
export async function runMatch(deps: Deps, requestId: string): Promise<MatchResult> {
  const started = performance.now();
  const lockKey = keys.matchLock(requestId);
  const token = newId();
  if ((await deps.redis.set(lockKey, token, 'PX', 10_000, 'NX')) !== 'OK') return { kind: 'skipped', reason: 'locked' };
  try {
    const result = await matchLocked(deps, requestId);
    deps.metrics.observe('matcher_ms', performance.now() - started);
    return result;
  } finally {
    await deps.redis.eval(COMPARE_AND_DELETE, 1, lockKey, token);
  }
}

async function matchLocked(deps: Deps, requestId: string): Promise<MatchResult> {
  const req = await loadRequest(deps.db, requestId);
  if (!req || req.status !== 'searching') return { kind: 'skipped', reason: 'not_searching' };
  const pending = await pendingOfferQuery(deps.db, requestId).executeTakeFirst();
  if (pending) return { kind: 'skipped', reason: 'offer_pending' };
  const rec = await loadSearch(deps, requestId);
  if (!rec) return { kind: 'skipped', reason: 'no_state' };
  const cfg = cityConfig(deps, req.cityId);
  const version = await currentPriceListVersion(deps.db);
  let state = rec.state;

  // Bounded: each pass widens the radius or switches round; at most radii + 2 passes.
  for (let pass = 0; pass < cfg.round1.radiiKm.length + 2; pass++) {
    const now = deps.clock.now();
    const step = nextSearchStep(state, now, cfg);
    state = step.state;
    if (step.kind === 'no_match') {
      await finishNoMatch(deps, req);
      return { kind: 'no_match' };
    }
    if (now.getTime() > lastOfferAt(state, cfg).getTime()) {
      // An offer sent now could not run its 30 s before the search ends: let the timeout close it.
      await saveSearch(deps, requestId, { state, area: rec.area });
      return { kind: 'waiting', retryAt: searchEndsAt(state, cfg) };
    }
    const candidates = await onlineNear(deps, req, step.radiusKm, cfg);
    const ids = candidates.map((c) => c.facts.uid);
    const [excluded, busy] = await Promise.all([offeredBefore(deps, requestId), busyAmong(deps, ids)]);
    const ranked = rankCandidates(
      { meetPoint: req.meetPoint, genre: req.genre, round: step.round, radiusKm: step.radiusKm, currentPriceListVersion: version, candidates, excluded, busy },
      cfg,
      deps.rng,
    );
    if (ranked.length === 0) {
      const next = onNobodyLeft(state, now, cfg);
      state = next.state;
      if (next.kind === 'retry_now') continue;
      await saveSearch(deps, requestId, { state, area: rec.area });
      await deps.scheduler.schedule('match', requestId, next.retryAt);
      await publishRequest(deps, requestId);
      return { kind: 'waiting', retryAt: next.retryAt };
    }
    for (const c of ranked) {
      const offerId = newId(now.getTime());
      if ((await deps.redis.set(keys.offerLock(c.uid), offerId, 'PX', cfg.offerTtlMs, 'NX')) !== 'OK') continue;
      const created = await createOffer(deps, req, state, c, offerId, now, cfg);
      if (!created) {
        await deps.redis.eval(COMPARE_AND_DELETE, 1, keys.offerLock(c.uid), offerId);
        continue;
      }
      await saveSearch(deps, requestId, { state, area: rec.area });
      const expiresAt = addMs(now, cfg.offerTtlMs);
      const offerDoc = {
        offerId, requestId, packageCode: req.packageCode, genre: req.genre, payoutVnd: req.payoutVnd,
        distanceKm: c.distanceKm, travelMinutes: c.etaMinutes, area: rec.area, note: req.note, expiresAt: expiresAt.toISOString(),
      };
      await deps.mirror.putOffer(c.uid, offerDoc);
      await deps.push.send(c.uid, { type: 'offer', ...offerDoc });
      await deps.scheduler.schedule('offer-expire', offerId, expiresAt);
      deps.metrics.observe('first_offer_ms', now.getTime() - state.startedAt.getTime());
      await publishRequest(deps, requestId);
      return { kind: 'offered', offerId, photographerId: c.uid };
    }
    // Everyone in range already holds another offer: look again shortly, same radius.
    const retryAt = new Date(Math.min(now.getTime() + cfg.idleRetryMs, searchEndsAt(state, cfg).getTime()));
    await saveSearch(deps, requestId, { state, area: rec.area });
    await deps.scheduler.schedule('match', requestId, retryAt);
    return { kind: 'waiting', retryAt };
  }
  await saveSearch(deps, requestId, { state, area: rec.area });
  const retryAt = addMs(deps.clock.now(), cfg.idleRetryMs);
  await deps.scheduler.schedule('match', requestId, retryAt);
  return { kind: 'waiting', retryAt };
}

/** GEOSEARCH + cached facts; members whose presence expired are pruned from the GEO set. */
async function onlineNear(deps: Deps, req: RequestRow, radiusKm: number, cfg: DispatchConfig): Promise<OnlineCandidate[]> {
  const hits = (await deps.redis.geosearch(
    keys.online(req.cityId), 'FROMLONLAT', req.meetPoint.lng, req.meetPoint.lat, 'BYRADIUS', radiusKm, 'km',
    'ASC', 'COUNT', cfg.candidateLimit, 'WITHCOORD',
  )) as Array<[string, [string, string]]>;
  if (hits.length === 0) return [];
  const raw = await deps.redis.mget(...hits.map(([uid]) => keys.facts(uid)));
  const out: OnlineCandidate[] = [];
  const stale: string[] = [];
  hits.forEach(([uid, [lng, lat]], i) => {
    const json = raw[i];
    if (!json) {
      stale.push(uid);
      return;
    }
    out.push({ facts: JSON.parse(json) as PhotographerFacts, location: { lat: Number(lat), lng: Number(lng) } });
  });
  if (stale.length > 0) await deps.redis.zrem(keys.online(req.cityId), ...stale);
  return out;
}

/** Hot queries of the matcher, exported for the EXPLAIN test (Task 16). */
export const offeredQuery = (db: Db, requestId: string) =>
  db.selectFrom('dispatch.instant_offers').select('photographer_id').where('request_id', '=', requestId);

export const busyQuery = (db: Db, ids: string[]) =>
  db.selectFrom('dispatch.instant_requests').select('photographer_id').where('photographer_id', 'in', ids).where('status', 'in', OPEN_JOB_STATUSES);

export const pendingOfferQuery = (db: Db, requestId: string) =>
  db.selectFrom('dispatch.instant_offers').select('id').where('request_id', '=', requestId).where('outcome', '=', 'pending');

async function offeredBefore(deps: Deps, requestId: string): Promise<Set<string>> {
  const rows = await offeredQuery(deps.db, requestId).execute();
  return new Set(rows.map((r) => r.photographer_id));
}

async function busyAmong(deps: Deps, ids: string[]): Promise<Set<string>> {
  if (ids.length === 0) return new Set();
  const rows = await busyQuery(deps.db, ids).execute();
  return new Set(rows.map((r) => r.photographer_id).filter((v): v is string => v !== null));
}

async function createOffer(
  deps: Deps,
  req: RequestRow,
  state: SearchState,
  c: { uid: string; score: number; reasons: unknown[] },
  offerId: string,
  now: Date,
  cfg: DispatchConfig,
): Promise<boolean> {
  return deps.db.transaction().execute(async (trx) => {
    const locked = await loadRequest(trx, req.id, true);
    if (!locked || locked.status !== 'searching') return false;
    const inserted = await trx
      .insertInto('dispatch.instant_offers')
      .values({
        id: offerId, request_id: req.id, photographer_id: c.uid, round: state.round, score: c.score,
        reasons: JSON.stringify(c.reasons), offered_at: now, expires_at: addMs(now, cfg.offerTtlMs), outcome: 'pending',
      })
      .onConflict((oc) => oc.columns(['request_id', 'photographer_id']).doNothing())
      .returning('id')
      .executeTakeFirst();
    if (!inserted) return false;
    if (locked.round !== state.round) {
      await trx.updateTable('dispatch.instant_requests').set({ round: state.round, version: bump() }).where('id', '=', req.id).execute();
    }
    await bumpReliability(trx, c.uid, 'offers', now);
    return true;
  });
}

/** Search over without a photographer: no_match, pending offers withdrawn, 100 % refund (spec §3.2, §4). */
export async function finishNoMatch(deps: Deps, req: RequestRow): Promise<void> {
  const now = deps.clock.now();
  const outcome = await deps.db.transaction().execute(async (trx) => {
    const locked = await loadRequest(trx, req.id, true);
    if (!locked || locked.status !== 'searching') return null;
    await trx.updateTable('dispatch.instant_requests').set({ status: 'no_match', version: bump() }).where('id', '=', req.id).execute();
    const withdrawn = await trx
      .updateTable('dispatch.instant_offers')
      .set({ outcome: 'withdrawn', decided_at: now })
      .where('request_id', '=', req.id)
      .where('outcome', '=', 'pending')
      .returning(['id', 'photographer_id'])
      .execute();
    const pay = await paymentForRequest(trx, req.id);
    let refundId: string | null = null;
    if (pay && pay.status === 'paid') {
      refundId = await applySplit(trx, {
        paymentId: pay.id, collectedVnd: pay.amount, split: settleNoMatch(pay.amount), photographerId: null,
        releaseAfter: null, now, note: 'instant no_match',
      });
    }
    return { withdrawn, refundId };
  });
  if (!outcome) return;
  for (const w of outcome.withdrawn) {
    await deps.redis.eval(COMPARE_AND_DELETE, 1, keys.offerLock(w.photographer_id), w.id);
    await deps.mirror.deleteOffer(w.photographer_id, w.id);
  }
  if (outcome.refundId) await deps.scheduler.schedule('refund', outcome.refundId, now);
  await deps.redis.del(keys.search(req.id));
  await publishRequest(deps, req.id);
  await deps.push.send(req.customerId, { type: 'status', requestId: req.id, status: 'no_match' });
}

/** Job `search-timeout`: closes the search when its (possibly moved) end has come. */
export async function searchTimeout(deps: Deps, requestId: string): Promise<void> {
  const req = await loadRequest(deps.db, requestId);
  if (!req || req.status !== 'searching') return;
  const rec = await loadSearch(deps, requestId);
  const cfg = cityConfig(deps, req.cityId);
  if (rec) {
    const step = nextSearchStep(rec.state, deps.clock.now(), cfg);
    if (step.kind === 'search') {
      await deps.scheduler.schedule('search-timeout', requestId, searchEndsAt(step.state, cfg));
      return;
    }
  }
  await finishNoMatch(deps, req);
}
```

Replace `services/dispatch/src/jobs/handlers.ts` with:

```ts
// services/dispatch/src/jobs/handlers.ts
import type { Deps } from '../deps.js';
import { runMatch, searchTimeout } from '../matcher/matcher.js';
import { executeRefund, expirePayment } from '../payments/events.js';
import type { JobHandlers } from './scheduler.js';

/** Timer handlers by job name. Each feature task adds its own; a job without a handler fails and BullMQ retries it. */
export function jobHandlers(deps: Deps): JobHandlers {
  return {
    'payment-timeout': (requestId) => expirePayment(deps, requestId),
    refund: (refundId) => executeRefund(deps, refundId),
    match: async (requestId) => {
      await runMatch(deps, requestId);
    },
    'search-timeout': (requestId) => searchTimeout(deps, requestId),
  };
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  12 passed | 1 skipped (13)`, `Tests  63 passed | 3 skipped (66)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): matcher with GEOSEARCH, offer locks, radius and round policy, no-match refund

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Offers: accept in one transaction, decline, 30-second expiry

**Files:**
- Create: `services/dispatch/src/offers/offers.ts`, `services/dispatch/src/routes/offers.ts`, `services/dispatch/test/offers.test.ts`
- Modify: `services/dispatch/src/jobs/handlers.ts` (replace), `services/dispatch/src/app.ts`, `services/dispatch/test/contract.test.ts`

**Interfaces:**
- Consumes: `transition`, `etaFromReasons` (plan I2); `loadRequest`, `saveTrip`, `publishRequest` (Task 10); `refreshCachedFacts` (Task 9); `EtaProvider` (Task 5).
- Produces:
  - `interface AcceptResult { requestId; meetPoint: { lat; lng; address }; customerName }` (= `AcceptResponse`); `acceptOffer(deps, photographerId, offerId)`: `not_found` / `permission_denied` / `offer_expired` (not pending, or `now ≥ expires_at` by the server clock) / `already_assigned` (another photographer won, or this offer was withdrawn) / `conflict` (the photographer already has an open job: unique index `instant_requests_one_open_job`). After commit: release the lock, delete offer docs, keep only `area` in `search:{id}`, ETA from Goong (or the offer's estimate when presence expired), `etagate` set, mirror, FCM `assigned` to the customer, facts refreshed.
  - `declineOffer(deps, photographerId, offerId, reason?)` (`conflict` when already decided; reason logged), `expireOffer(deps, offerId)` (job `offer-expire`; no-op if decided or not yet due); both schedule `match` now.
  - Routes `acceptOffer`, `declineOffer`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/offers.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { expectMirror } from './mirror-schema.js';
import {
  HCM, addCustomer, addPhotographer, as, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1', { name: 'Lan' });
  await addPhotographer(db, 'p1');
  await addPhotographer(db, 'p2');
  await online(app, 'p1', north(HCM, 0.5), w.clock.now());
  await online(app, 'p2', north(HCM, 1.5), w.clock.now());
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const offerOf = async (uid: string) =>
  (await db.selectFrom('dispatch.instant_offers').select('id').where('photographer_id', '=', uid).where('outcome', '=', 'pending').executeTakeFirstOrThrow()).id;
const pendingOffers = () => db.selectFrom('dispatch.instant_offers').selectAll().where('outcome', '=', 'pending').execute();
const accept = (uid: string, offerId: string) => app.inject({ method: 'POST', url: `/v1/offers/${offerId}/accept`, headers: as(uid) });
const decline = (uid: string, offerId: string, payload?: object) =>
  app.inject({ method: 'POST', url: `/v1/offers/${offerId}/decline`, headers: as(uid), ...(payload ? { payload } : {}) });

describe('accept (S53 "Nhận")', () => {
  it('assigns, returns the exact address, mirrors the photographer card, ETA and grace window', async () => {
    const id = await paidRequest(app, 'c1');
    await w.runDue();
    const offerId = await offerOf('p1');
    w.clock.advance(5_000);
    const res = await accept('p1', offerId);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ requestId: id, meetPoint: { ...HCM, address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' }, customerName: 'Lan' });
    const m = w.mirror.requests.get(id);
    expectMirror('InstantRequestMirror', m);
    expect(m).toMatchObject({
      status: 'assigned', photographerId: 'p1', etaMinutes: 3, etaEstimated: true, assignedAt: '2026-10-01T08:00:05.000Z',
      graceEndsAt: '2026-10-01T08:02:05.000Z', meetPoint: { ...HCM, address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' },
      photographer: { uid: 'p1', displayName: 'Thợ p1', avatarUrl: null, verified: true, rating: 4.8, completedShoots: 0 },
    });
    expect(w.mirror.offers.has('p1')).toBe(false);
    expect(w.push.to('c1')).toContainEqual({ type: 'assigned', requestId: id, etaMinutes: 3 });
    const rel = await db.selectFrom('dispatch.photographer_reliability').select(['offers', 'accepted']).where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
    expect(rel).toEqual({ offers: 1, accepted: 1 });
  });

  it('the server clock decides: 30 s after the offer it is offer_expired, even before the expiry job ran', async () => {
    await paidRequest(app, 'c1');
    await w.runDue();
    const offerId = await offerOf('p1');
    w.clock.advance(30_000);
    const res = await accept('p1', offerId);
    expect([res.statusCode, res.json().code]).toEqual([409, 'offer_expired']);
  });

  it('someone else\'s offer → 403; unknown offer → 404', async () => {
    await paidRequest(app, 'c1');
    await w.runDue();
    expect((await accept('p2', await offerOf('p1'))).statusCode).toBe(403);
    expect((await accept('p1', '01J9ZZZZZZZZZZZZZZZZZZZZZZ')).statusCode).toBe(404);
  });
});

describe('expiry (30 s, spec §3.2)', () => {
  it('30 s without an answer → the next photographer; the first is never asked again', async () => {
    const id = await paidRequest(app, 'c1');
    await w.runDue();
    expect((await pendingOffers()).map((o) => o.photographer_id)).toEqual(['p1']);
    await w.advance(30_000);
    expect((await pendingOffers()).map((o) => o.photographer_id)).toEqual(['p2']);
    expect(w.mirror.offers.has('p1')).toBe(false);
    await w.advance(30_000);
    const all = await db.selectFrom('dispatch.instant_offers').select(['photographer_id', 'outcome']).where('request_id', '=', id).orderBy('id').execute();
    expect(all).toEqual([{ photographer_id: 'p1', outcome: 'expired' }, { photographer_id: 'p2', outcome: 'expired' }]);
    expect(await pendingOffers()).toEqual([]);
  });
});

describe('decline (S53 "Từ chối")', () => {
  it('moves to the next photographer at once; a reason is optional', async () => {
    await paidRequest(app, 'c1');
    await w.runDue();
    expect((await decline('p1', await offerOf('p1'), { reason: 'too_far' })).statusCode).toBe(204);
    await w.runDue();
    expect(await offerOf('p2')).toBeTruthy();
    expect((await decline('p2', await offerOf('p2'))).statusCode).toBe(204);
  });

  it('declining twice is a conflict; an unknown reason is a 400', async () => {
    await paidRequest(app, 'c1');
    await w.runDue();
    const offerId = await offerOf('p1');
    expect((await decline('p1', offerId, { reason: 'lazy' })).statusCode).toBe(400);
    await decline('p1', offerId);
    expect((await decline('p1', offerId)).statusCode).toBe(409);
  });
});

describe('one open job per photographer', () => {
  it('a photographer with an open job cannot accept another one', async () => {
    await addCustomer(db, 'c2');
    const first = await paidRequest(app, 'c1');
    await w.runDue();
    await accept('p1', await offerOf('p1'));
    const second = await paidRequest(app, 'c2');
    // Force an offer to the busy photographer (the matcher never would).
    await db.insertInto('dispatch.instant_offers').values({
      id: '01J9ZXFF000000000000000001', request_id: second, photographer_id: 'p1', round: 1, score: 0.9, reasons: '[]',
      offered_at: w.clock.now(), expires_at: new Date(w.clock.now().getTime() + 30_000), outcome: 'pending',
    }).execute();
    const res = await accept('p1', '01J9ZXFF000000000000000001');
    expect([res.statusCode, res.json().code]).toEqual([409, 'conflict']);
    expect(first).not.toBe(second);
  });
});
```

In `test/contract.test.ts` remove `'acceptOffer'`, `'declineOffer'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/offers.test.ts`
Expected: FAIL: accept and decline answer 404 (not routed) and the expiry test stops at `no handler for job offer-expire`.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/offers/offers.ts
import { cityConfig } from '../catalog/catalog.js';
import { DispatchError, etaFromReasons, transition, type DeclineReason } from '../domain/core.js';
import type { Deps } from '../deps.js';
import { publishRequest } from '../requests/publish.js';
import { bump, loadRequest, saveTrip } from '../requests/rows.js';
import { COMPARE_AND_DELETE, keys } from '../redis/keys.js';
import { refreshCachedFacts } from '../presence/presence.js';
import { bumpReliability } from '../settings/facts.js';

export interface AcceptResult {
  requestId: string;
  meetPoint: { lat: number; lng: number; address: string };
  customerName: string;
}

/**
 * POST /v1/offers/{id}/accept (spec §5 `offers`): one PostgreSQL transaction that succeeds only
 * while the offer is pending and unexpired by the server clock and the request is still searching.
 * Locks: the request row first, then the offer row (same order everywhere → no deadlock). The
 * unique index instant_requests_one_open_job refuses a second open job for the photographer.
 */
export async function acceptOffer(deps: Deps, photographerId: string, offerId: string): Promise<AcceptResult> {
  const now = deps.clock.now();
  const head = await deps.db.selectFrom('dispatch.instant_offers').select(['request_id', 'photographer_id']).where('id', '=', offerId).executeTakeFirst();
  if (!head) throw new DispatchError('not_found');
  if (head.photographer_id !== photographerId) throw new DispatchError('permission_denied');

  const accepted = await deps.db.transaction().execute(async (trx) => {
    const req = await loadRequest(trx, head.request_id, true);
    const offer = await trx.selectFrom('dispatch.instant_offers').selectAll().where('id', '=', offerId).forUpdate().executeTakeFirstOrThrow();
    if (!req) throw new DispatchError('not_found');
    if (req.status !== 'searching') {
      throw new DispatchError(req.photographerId !== null && req.photographerId !== photographerId ? 'already_assigned' : 'offer_expired');
    }
    if (offer.outcome === 'withdrawn') throw new DispatchError('already_assigned');
    if (offer.outcome !== 'pending' || now.getTime() >= offer.expires_at.getTime()) throw new DispatchError('offer_expired');
    const t = transition(req, 'accept', now, cityConfig(deps, req.cityId));
    if (!t.ok) throw new DispatchError('offer_expired');
    try {
      await trx
        .updateTable('dispatch.instant_requests')
        .set({ status: 'assigned', photographer_id: photographerId, assigned_at: now, version: bump() })
        .where('id', '=', req.id)
        .execute();
    } catch (err) {
      if ((err as { constraint?: string }).constraint === 'instant_requests_one_open_job') {
        throw new DispatchError('conflict', { reason: 'you already have an open instant job' });
      }
      throw err;
    }
    await trx.updateTable('dispatch.instant_offers').set({ outcome: 'accepted', decided_at: now }).where('id', '=', offerId).execute();
    const others = await trx
      .updateTable('dispatch.instant_offers')
      .set({ outcome: 'withdrawn', decided_at: now })
      .where('request_id', '=', req.id)
      .where('outcome', '=', 'pending')
      .returning(['id', 'photographer_id'])
      .execute();
    await bumpReliability(trx, photographerId, 'accepted', now);
    const customer = await trx.selectFrom('users').select('display_name').where('id', '=', req.customerId).executeTakeFirst();
    return { req, others, customerName: customer?.display_name ?? '', offerEta: etaFromReasons(offer.reasons as Array<{ code: string; etaMinutes?: number }>) };
  });

  const { req } = accepted;
  await deps.redis.eval(COMPARE_AND_DELETE, 1, keys.offerLock(photographerId), offerId);
  await deps.mirror.deleteOffer(photographerId, offerId);
  for (const o of accepted.others) {
    await deps.redis.eval(COMPARE_AND_DELETE, 1, keys.offerLock(o.photographer_id), o.id);
    await deps.mirror.deleteOffer(o.photographer_id, o.id);
  }
  // Search over; keep only `area` (needed again if the photographer cancels and the search restarts).
  await deps.redis.hdel(keys.search(req.id), 'startedAt', 'expand', 'round', 'radiusIndex', 'roundStartedAt');
  // Real ETA only for the photographer who accepted (spec §3.2); fallback inside the provider.
  const presence = await deps.redis.hmget(keys.presence(photographerId), 'lat', 'lng');
  const eta =
    presence[0] && presence[1]
      ? await deps.eta.eta({ lat: Number(presence[0]), lng: Number(presence[1]) }, req.meetPoint, cityConfig(deps, req.cityId))
      : { minutes: accepted.offerEta ?? 1, estimated: true }; // presence expired: the estimate the offer was made with
  await saveTrip(deps, req.id, { etaMinutes: eta.minutes, etaEstimated: eta.estimated });
  await deps.redis.set(keys.etaGate(req.id), '1', 'PX', cityConfig(deps, req.cityId).tracking.etaRefreshMs);
  await publishRequest(deps, req.id);
  await deps.push.send(req.customerId, { type: 'assigned', requestId: req.id, etaMinutes: eta.minutes });
  await refreshCachedFacts(deps, photographerId);
  return { requestId: req.id, meetPoint: { ...req.meetPoint, address: req.meetAddress }, customerName: accepted.customerName };
}

/** Decline (S53 "Từ chối") or expiry: the offer closes, the photographer is never asked again for this request. */
async function closeOffer(deps: Deps, offerId: string, outcome: 'declined' | 'expired', photographerId: string | null): Promise<boolean> {
  const now = deps.clock.now();
  const closed = await deps.db.transaction().execute(async (trx) => {
    const head = await trx.selectFrom('dispatch.instant_offers').select(['request_id']).where('id', '=', offerId).executeTakeFirst();
    if (!head) return null;
    await loadRequest(trx, head.request_id, true);
    const offer = await trx.selectFrom('dispatch.instant_offers').selectAll().where('id', '=', offerId).forUpdate().executeTakeFirstOrThrow();
    if (photographerId !== null && offer.photographer_id !== photographerId) throw new DispatchError('permission_denied');
    if (offer.outcome !== 'pending') return { offer, changed: false };
    if (outcome === 'expired' && now.getTime() < offer.expires_at.getTime()) return { offer, changed: false };
    await trx.updateTable('dispatch.instant_offers').set({ outcome, decided_at: now }).where('id', '=', offerId).execute();
    return { offer, changed: true };
  });
  if (!closed) {
    if (photographerId !== null) throw new DispatchError('not_found');
    return false;
  }
  if (!closed.changed) {
    if (photographerId !== null) throw new DispatchError(closed.offer.outcome === 'expired' ? 'offer_expired' : 'conflict');
    return false;
  }
  await deps.redis.eval(COMPARE_AND_DELETE, 1, keys.offerLock(closed.offer.photographer_id), offerId);
  await deps.mirror.deleteOffer(closed.offer.photographer_id, offerId);
  await deps.scheduler.schedule('match', closed.offer.request_id, now);
  return true;
}

export async function declineOffer(deps: Deps, photographerId: string, offerId: string, reason: DeclineReason | undefined): Promise<void> {
  await closeOffer(deps, offerId, 'declined', photographerId);
  deps.log.info({ offerId, reason: reason ?? null }, 'offer_declined');
}

/** Job `offer-expire`: 30 s passed without an answer (server time is the referee, spec §10). */
export async function expireOffer(deps: Deps, offerId: string): Promise<void> {
  await closeOffer(deps, offerId, 'expired', null);
}
```

```ts
// services/dispatch/src/routes/offers.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { acceptOffer, declineOffer } from '../offers/offers.js';

type S = components['schemas'];
type Params = { offerId: string };

export function registerOfferRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Params: Params }>({
    ...route(deps.contract, 'acceptOffer'),
    handler: async (req) => acceptOffer(deps, principalOf(req).uid, req.params.offerId) satisfies Promise<S['AcceptResponse']>,
  });
  app.route<{ Params: Params; Body: { reason?: S['DeclineReason'] } }>({
    ...route(deps.contract, 'declineOffer'),
    handler: async (req, reply) => {
      await declineOffer(deps, principalOf(req).uid, req.params.offerId, req.body.reason);
      return reply.status(204).send();
    },
  });
}
```

Replace `services/dispatch/src/jobs/handlers.ts` with:

```ts
// services/dispatch/src/jobs/handlers.ts
import type { Deps } from '../deps.js';
import { runMatch, searchTimeout } from '../matcher/matcher.js';
import { expireOffer } from '../offers/offers.js';
import { executeRefund, expirePayment } from '../payments/events.js';
import type { JobHandlers } from './scheduler.js';

/** Timer handlers by job name. Each feature task adds its own; a job without a handler fails and BullMQ retries it. */
export function jobHandlers(deps: Deps): JobHandlers {
  return {
    'payment-timeout': (requestId) => expirePayment(deps, requestId),
    refund: (refundId) => executeRefund(deps, refundId),
    match: async (requestId) => {
      await runMatch(deps, requestId);
    },
    'search-timeout': (requestId) => searchTimeout(deps, requestId),
    'offer-expire': (offerId) => expireOffer(deps, offerId),
  };
}
```

In `src/app.ts` add the import

```ts
import { registerOfferRoutes } from './routes/offers.js';
```

and, after the previous `register…Routes(app, deps);` line,

```ts
  registerOfferRoutes(app, deps);
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  13 passed | 1 skipped (14)`, `Tests  70 passed | 3 skipped (73)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): accept as one locked transaction, decline and server-clock offer expiry

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 13: Trip: location, ETA refresh, arrive, start, finish, completion

**Files:**
- Create: `services/dispatch/src/requests/trip.ts`, `services/dispatch/test/trip.test.ts`
- Modify: `services/dispatch/src/routes/requests.ts` (replace), `services/dispatch/src/jobs/handlers.ts` (replace), `services/dispatch/test/contract.test.ts`

**Interfaces:**
- Consumes: `transition`, `decideArrival`, `distanceM`, `settleCompleted`, `addMs` (plan I2); `applySplit`, `paymentForRequest`, `loadRequest`, `saveTrip`, `publishRequest` (Task 10); `EtaProvider` (Task 5).
- Produces:
  - `interface Fix extends LatLng { accuracyM; headingDeg?; speedMps?; at }`.
  - `postLocation(deps, uid, requestId, fix)`: only the assigned photographer, only `assigned`/`en_route` (first fix → `en_route`), `SET locgate NX PX 5000` else `limit_exceeded` (429), overwrites `instant_tracks/{id}`, Goong at most once a minute (`SET etagate NX PX 60000`), mirror when something changed.
  - `arrive(deps, uid, requestId, { fix, force?, reason? })`: `not_eligible { reasons: ['too_far' | 'reason_required'], distanceM }`; forced arrivals logged (`arrive_forced`, distance and accuracy, no coordinates); deletes the track doc and trip state; job `no-show` at +15 min; FCM `status` to the customer.
  - `startShoot`, `finishShoot` (sets `finishedAt`, stays `in_progress`, job `auto-complete` at +2 h), `confirmComplete(deps, customerId, requestId)`, `autoComplete(deps, requestId)` (job; no-op when already completed), `noShowDue(deps, requestId)` (job; FCM `status` with `noShowAvailable: true` to the photographer).
  - Completion settlement in the same transaction: `fee_charged +platform`, `payments.payee_id = photographer`, `release_after = completed + 24 h`, escrow `held` (released later by the escrow job of the payments plan / I6).
  - Routes `postLocation`, `arrive`, `startShoot`, `finishShoot`, `confirmComplete`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/trip.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import type { EtaProvider } from '../src/eta/eta.js';
import { heldVnd } from '../src/payments/events.js';
import { expectMirror } from './mirror-schema.js';
import {
  HCM, addCustomer, addPhotographer, as, fixAt, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
let etaCalls = 0;
const countingEta: EtaProvider = {
  async eta() {
    etaCalls++;
    return { minutes: 9, estimated: false };
  },
};
let id: string;

beforeEach(async () => {
  await resetAll(db, redis);
  etaCalls = 0;
  w = testWorld(db, redis, { eta: countingEta });
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addPhotographer(db, 'p1');
  await online(app, 'p1', north(HCM, 2), w.clock.now());
  id = await paidRequest(app, 'c1');
  await w.runDue();
  const offer = await db.selectFrom('dispatch.instant_offers').select('id').where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
  await app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as('p1') });
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const post = (path: string, uid = 'p1', payload?: object) =>
  app.inject({ method: 'POST', url: `/v1/requests/${id}/${path}`, headers: as(uid), ...(payload ? { payload } : {}) });

describe('on the way (S49, S54)', () => {
  it('the first location makes it en_route and writes the one track doc', async () => {
    const res = await post('location', 'p1', fixAt(north(HCM, 1.8), w.clock.now()));
    expect(res.statusCode).toBe(204);
    expect(w.mirror.requests.get(id)?.status).toBe('en_route');
    const track = w.mirror.tracks.get(id);
    expectMirror('InstantTrackMirror', track);
    expect(track).toMatchObject({ accuracyM: 15, headingDeg: null });
  });

  it('at most one location every 5 s (429 limit_exceeded)', async () => {
    await post('location', 'p1', fixAt(north(HCM, 1.8), w.clock.now()));
    const fast = await post('location', 'p1', fixAt(north(HCM, 1.7), w.clock.now()));
    expect([fast.statusCode, fast.json().code]).toEqual([429, 'limit_exceeded']);
  });

  it('Goong at most once a minute per request (the accept counts as the first)', async () => {
    expect(etaCalls).toBe(1);
    for (let i = 0; i < 12; i++) {
      await redis.del(`locgate:${id}`); // the 5 s gate is real time in Redis; this test is about the ETA gate
      await post('location', 'p1', fixAt(north(HCM, 1.8 - i * 0.05), w.clock.now()));
    }
    expect(etaCalls).toBe(1);
    await redis.del(`etagate:${id}`, `locgate:${id}`); // what one minute does
    await post('location', 'p1', fixAt(north(HCM, 1), w.clock.now()));
    expect(etaCalls).toBe(2);
    expect(w.mirror.requests.get(id)).toMatchObject({ etaMinutes: 9, etaEstimated: false });
  });

  it('only the assigned photographer may post', async () => {
    expect((await post('location', 'c1', fixAt(HCM, w.clock.now()))).statusCode).toBe(403);
  });
});

describe('arrive (≤ 200 m, or forced with a reason when GPS is poor)', () => {
  it('too far with good GPS is refused even when forced', async () => {
    const r = await post('arrive', 'p1', { fix: fixAt(north(HCM, 1), w.clock.now(), 10), force: true, reason: 'x' });
    expect(r.statusCode).toBe(422);
    expect(r.json()).toMatchObject({ code: 'not_eligible', details: { reasons: ['too_far'], distanceM: 1000 } });
  });

  it('poor GPS needs a reason, then it is accepted', async () => {
    const noReason = await post('arrive', 'p1', { fix: fixAt(north(HCM, 0.5), w.clock.now(), 150), force: true });
    expect(noReason.json().details).toMatchObject({ reasons: ['reason_required'] });
    expect((await post('arrive', 'p1', { fix: fixAt(north(HCM, 0.5), w.clock.now(), 150), force: true, reason: 'Trong hẻm' })).statusCode).toBe(204);
  });

  it('within 200 m: arrived, track deleted, no-show timer set', async () => {
    await post('location', 'p1', fixAt(north(HCM, 0.5), w.clock.now()));
    expect((await post('arrive', 'p1', { fix: fixAt(north(HCM, 0.1), w.clock.now()) })).statusCode).toBe(204);
    expect(w.mirror.requests.get(id)?.status).toBe('arrived');
    expect(w.mirror.tracks.has(id)).toBe(false);
    expect(w.scheduler.pending('no-show').map((j) => j.at.toISOString())).toEqual(['2026-10-01T08:15:00.000Z']);
    await w.advance(15 * 60_000);
    expect(w.push.to('p1')).toContainEqual({ type: 'status', requestId: id, status: 'arrived', noShowAvailable: true });
  });
});

describe('shoot and completion', () => {
  const arriveNow = () => post('arrive', 'p1', { fix: fixAt(HCM, w.clock.now()) });

  it('start → finish → customer confirms: completed, photographer share held for the dispute window, fee booked', async () => {
    await arriveNow();
    expect((await post('start')).statusCode).toBe(204);
    w.clock.advance(60 * 60_000);
    expect((await post('finish')).statusCode).toBe(204);
    expect(w.mirror.requests.get(id)).toMatchObject({ status: 'in_progress', finishedAt: '2026-10-01T09:00:00.000Z' });
    expect((await post('confirm-complete', 'p1')).statusCode).toBe(403);
    expect((await post('confirm-complete', 'c1')).statusCode).toBe(204);
    expect(w.mirror.requests.get(id)?.status).toBe('completed');
    const pay = await db.selectFrom('payments').selectAll().where('subject_id', '=', id).executeTakeFirstOrThrow();
    expect(pay).toMatchObject({ status: 'paid', escrow_status: 'held', payee_id: 'p1' });
    expect(pay.release_after?.toISOString()).toBe('2026-10-02T09:00:00.000Z');
    const fee = await db.selectFrom('ledger_entries').select('amount').where('payment_id', '=', pay.id).where('type', '=', 'fee_charged').executeTakeFirstOrThrow();
    expect(fee.amount).toBe(120_000);
    expect(await heldVnd(w.deps, pay.id)).toBe(600_000);
  });

  it('completes by itself 2 hours after "Hoàn thành"', async () => {
    await arriveNow();
    await post('start');
    await post('finish');
    await w.advance(2 * 60 * 60_000 - 1);
    expect(w.mirror.requests.get(id)?.status).toBe('in_progress');
    await w.advance(1);
    expect(w.mirror.requests.get(id)?.status).toBe('completed');
  });

  it('out of order steps are conflicts', async () => {
    expect((await post('start')).statusCode).toBe(409);
    expect((await post('finish')).statusCode).toBe(409);
    expect((await post('confirm-complete', 'c1')).statusCode).toBe(409);
  });
});
```

In `test/contract.test.ts` remove `'postLocation'`, `'arrive'`, `'startShoot'`, `'finishShoot'`, `'confirmComplete'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/trip.test.ts`
Expected: FAIL: the trip endpoints answer 404 (not routed).

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/requests/trip.ts
import { cityConfig } from '../catalog/catalog.js';
import {
  DispatchError, addMs, decideArrival, distanceM, settleCompleted, transition, type InstantEvent, type LatLng,
} from '../domain/core.js';
import type { Deps } from '../deps.js';
import { applySplit, paymentForRequest } from '../payments/ledger.js';
import { keys } from '../redis/keys.js';
import { bump, loadRequest, saveTrip, type RequestRow } from './rows.js';
import { publishRequest } from './publish.js';

export interface Fix extends LatLng {
  accuracyM: number;
  headingDeg?: number | null;
  speedMps?: number | null;
  at: string;
}

function requirePhotographer(req: RequestRow | null, uid: string): RequestRow {
  if (!req) throw new DispatchError('not_found');
  if (req.photographerId !== uid) throw new DispatchError('permission_denied');
  return req;
}

/**
 * Applies one state-machine event in a transaction (row lock), stamps the patch columns, and
 * returns the row as it was before. Throws conflict when the machine refuses.
 */
async function apply(deps: Deps, requestId: string, event: InstantEvent, check: (r: RequestRow | null) => RequestRow): Promise<RequestRow> {
  const now = deps.clock.now();
  return deps.db.transaction().execute(async (trx) => {
    const req = check(await loadRequest(trx, requestId, true));
    const t = transition(req, event, now, cityConfig(deps, req.cityId));
    if (!t.ok) throw new DispatchError('conflict', { reason: t.reason });
    await trx
      .updateTable('dispatch.instant_requests')
      .set({
        status: t.to,
        version: bump(),
        ...(t.patch.arrivedAt ? { arrived_at: t.patch.arrivedAt } : {}),
        ...(t.patch.startedAt ? { started_at: t.patch.startedAt } : {}),
        ...(t.patch.finishedAt ? { finished_at: t.patch.finishedAt } : {}),
        ...(t.patch.completedAt ? { completed_at: t.patch.completedAt } : {}),
      })
      .where('id', '=', requestId)
      .execute();
    if (t.to === 'completed') {
      const pay = await paymentForRequest(trx, requestId);
      if (pay && pay.status === 'paid') {
        const cfg = cityConfig(deps, req.cityId);
        await applySplit(trx, {
          paymentId: pay.id, collectedVnd: pay.amount, split: settleCompleted(pay.amount, req.payoutVnd),
          photographerId: req.photographerId, releaseAfter: addMs(now, cfg.completion.disputeWindowMs), now, note: 'instant completed',
        });
      }
    }
    return req;
  });
}

/**
 * POST /v1/requests/{id}/location (spec §5 `tracking`, §6): at most once per 5 s (429), overwrites
 * instant_tracks/{id}, refreshes the ETA with Goong at most once a minute. The first fix moves
 * assigned → en_route.
 */
export async function postLocation(deps: Deps, uid: string, requestId: string, fix: Fix): Promise<void> {
  const req = requirePhotographer(await loadRequest(deps.db, requestId), uid);
  if (req.status !== 'assigned' && req.status !== 'en_route') throw new DispatchError('conflict', { reason: `no tracking in ${req.status}` });
  const cfg = cityConfig(deps, req.cityId);
  if ((await deps.redis.set(keys.locationGate(requestId), '1', 'PX', cfg.tracking.minIntervalMs, 'NX')) !== 'OK') {
    throw new DispatchError('limit_exceeded', { retryAfterMs: cfg.tracking.minIntervalMs });
  }
  let changed = false;
  if (req.status === 'assigned') {
    await apply(deps, requestId, 'start_route', (r) => requirePhotographer(r, uid));
    changed = true;
  }
  await deps.mirror.putTrack(requestId, { lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM, headingDeg: fix.headingDeg ?? null, at: fix.at });
  if ((await deps.redis.set(keys.etaGate(requestId), '1', 'PX', cfg.tracking.etaRefreshMs, 'NX')) === 'OK') {
    const eta = await deps.eta.eta(fix, req.meetPoint, cfg);
    await saveTrip(deps, requestId, { etaMinutes: eta.minutes, etaEstimated: eta.estimated });
    changed = true;
  }
  if (changed) await publishRequest(deps, requestId);
}

/** POST …/arrive: ≤ 200 m, or forced with a reason when GPS accuracy is poor (logged). */
export async function arrive(deps: Deps, uid: string, requestId: string, body: { fix: Fix; force?: boolean; reason?: string }): Promise<void> {
  const req = requirePhotographer(await loadRequest(deps.db, requestId), uid);
  const cfg = cityConfig(deps, req.cityId);
  const d = Math.round(distanceM(body.fix, req.meetPoint));
  const decision = decideArrival({ distanceM: d, accuracyM: body.fix.accuracyM, force: body.force ?? false, reason: body.reason ?? null }, cfg);
  if (!decision.ok) throw new DispatchError('not_eligible', { reasons: [decision.reason], distanceM: d });
  const before = await apply(deps, requestId, 'arrive', (r) => requirePhotographer(r, uid));
  if (decision.forced) deps.log.warn({ requestId, distanceM: d, accuracyM: body.fix.accuracyM, reason: body.reason }, 'arrive_forced');
  await deps.mirror.deleteTrack(requestId);
  await deps.redis.del(keys.trip(requestId), keys.etaGate(requestId), keys.locationGate(requestId));
  await deps.scheduler.schedule('no-show', requestId, addMs(deps.clock.now(), cfg.cancellation.noShowWaitMs));
  await publishRequest(deps, requestId);
  await deps.push.send(before.customerId, { type: 'status', requestId, status: 'arrived' });
}

export async function startShoot(deps: Deps, uid: string, requestId: string): Promise<void> {
  const before = await apply(deps, requestId, 'start', (r) => requirePhotographer(r, uid));
  await publishRequest(deps, requestId);
  await deps.push.send(before.customerId, { type: 'status', requestId, status: 'in_progress' });
}

/** "Hoàn thành": finishedAt set, status stays in_progress until the customer confirms or 2 h pass. */
export async function finishShoot(deps: Deps, uid: string, requestId: string): Promise<void> {
  const before = await apply(deps, requestId, 'finish', (r) => requirePhotographer(r, uid));
  const cfg = cityConfig(deps, before.cityId);
  await deps.scheduler.schedule('auto-complete', requestId, addMs(deps.clock.now(), cfg.completion.autoCompleteMs));
  await publishRequest(deps, requestId);
  await deps.push.send(before.customerId, { type: 'status', requestId, status: 'in_progress' });
}

async function complete(deps: Deps, requestId: string, event: 'confirm_complete' | 'auto_complete', check: (r: RequestRow | null) => RequestRow): Promise<void> {
  const before = await apply(deps, requestId, event, check);
  await deps.redis.del(keys.search(requestId), keys.trip(requestId));
  await publishRequest(deps, requestId);
  if (before.photographerId) await deps.push.send(before.photographerId, { type: 'status', requestId, status: 'completed' });
  await deps.push.send(before.customerId, { type: 'status', requestId, status: 'completed' });
}

export async function confirmComplete(deps: Deps, uid: string, requestId: string): Promise<void> {
  await complete(deps, requestId, 'confirm_complete', (r) => {
    if (!r) throw new DispatchError('not_found');
    if (r.customerId !== uid) throw new DispatchError('permission_denied');
    return r;
  });
}

/** Job `auto-complete`: 2 hours after "Hoàn thành" (no-op if the customer already confirmed). */
export async function autoComplete(deps: Deps, requestId: string): Promise<void> {
  try {
    await complete(deps, requestId, 'auto_complete', (r) => {
      if (!r) throw new DispatchError('not_found');
      return r;
    });
  } catch (err) {
    if (err instanceof DispatchError && (err.code === 'conflict' || err.code === 'not_found')) return;
    throw err;
  }
}

/** Job `no-show`: 15 minutes at the meet point; tells the photographer they may report a no-show. */
export async function noShowDue(deps: Deps, requestId: string): Promise<void> {
  const req = await loadRequest(deps.db, requestId);
  if (!req || req.status !== 'arrived' || !req.photographerId) return;
  await deps.push.send(req.photographerId, { type: 'status', requestId, status: 'arrived', noShowAvailable: true });
}
```

Replace `services/dispatch/src/routes/requests.ts` with:

```ts
// services/dispatch/src/routes/requests.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { createRequest } from '../requests/create.js';
import { arrive, confirmComplete, finishShoot, postLocation, startShoot } from '../requests/trip.js';

type S = components['schemas'];
type Id = { requestId: string };

export function registerRequestRoutes(app: FastifyInstance, deps: RouteDeps): void {
  const c = deps.contract;
  app.route<{ Body: S['CreateRequestBody'] }>({
    ...route(c, 'createRequest'),
    handler: async (req, reply) => {
      const b = req.body;
      const created = await createRequest(deps, principalOf(req).uid, {
        packageId: b.packageId, genre: b.genre, meetPoint: b.meetPoint, note: b.note, expand: b.expand,
        expectedAmountVnd: b.expectedAmountVnd, provider: b.provider,
      });
      return reply.status(201).send(created satisfies S['CreateRequestResponse']);
    },
  });
  app.route<{ Params: Id; Body: S['LocationFix'] }>({
    ...route(c, 'postLocation'),
    handler: async (req, reply) => {
      await postLocation(deps, principalOf(req).uid, req.params.requestId, req.body);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id; Body: S['ArriveBody'] }>({
    ...route(c, 'arrive'),
    handler: async (req, reply) => {
      await arrive(deps, principalOf(req).uid, req.params.requestId, req.body);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id }>({
    ...route(c, 'startShoot'),
    handler: async (req, reply) => {
      await startShoot(deps, principalOf(req).uid, req.params.requestId);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id }>({
    ...route(c, 'finishShoot'),
    handler: async (req, reply) => {
      await finishShoot(deps, principalOf(req).uid, req.params.requestId);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id }>({
    ...route(c, 'confirmComplete'),
    handler: async (req, reply) => {
      await confirmComplete(deps, principalOf(req).uid, req.params.requestId);
      return reply.status(204).send();
    },
  });
}
```

Replace `services/dispatch/src/jobs/handlers.ts` with:

```ts
// services/dispatch/src/jobs/handlers.ts
import type { Deps } from '../deps.js';
import { runMatch, searchTimeout } from '../matcher/matcher.js';
import { expireOffer } from '../offers/offers.js';
import { executeRefund, expirePayment } from '../payments/events.js';
import { autoComplete, noShowDue } from '../requests/trip.js';
import type { JobHandlers } from './scheduler.js';

/** Timer handlers by job name. Each feature task adds its own; a job without a handler fails and BullMQ retries it. */
export function jobHandlers(deps: Deps): JobHandlers {
  return {
    'payment-timeout': (requestId) => expirePayment(deps, requestId),
    refund: (refundId) => executeRefund(deps, refundId),
    match: async (requestId) => {
      await runMatch(deps, requestId);
    },
    'search-timeout': (requestId) => searchTimeout(deps, requestId),
    'offer-expire': (offerId) => expireOffer(deps, offerId),
    'auto-complete': (requestId) => autoComplete(deps, requestId),
    'no-show': (requestId) => noShowDue(deps, requestId),
  };
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  14 passed | 1 skipped (15)`, `Tests  80 passed | 3 skipped (83)`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): live tracking with rate limit and Goong ETA, arrival rule, shoot, completion with escrow settlement

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Cancellation for both sides (S55), with `dryRun`

**Files:**
- Create: `services/dispatch/src/requests/cancel.ts`, `services/dispatch/test/cancel.test.ts`
- Modify: `services/dispatch/src/routes/requests.ts` (replace), `services/dispatch/test/contract.test.ts`

**Interfaces:**
- Consumes: `quoteCancel`, `lateDeadline`, `etaFromReasons`, `startSearch`, `searchEndsAt`, `addMs` (plan I2); `applySplit`, `paymentForRequest` (Task 10); `bumpReliability` (Task 9).
- Produces:
  - `interface CancelResult { rule; refundVnd; photographerVnd; platformVnd; graceEndsAt: string | null }` (= `CancelQuote`).
  - `cancelRequest(deps, uid, requestId, { dryRun, reason? })`: actor from the token (customer or the assigned photographer, else `permission_denied`; unknown → `not_found`); `dryRun` only quotes; otherwise the quote is recomputed under the row lock with the server clock and applied in one transaction (status, `cancelled_at`, `cancel_reason`, pending offers withdrawn, refund + ledger via `applySplit` when `settlesNow`, the photographer's share held with `release_after` = +24 h, reliability penalty). `photographer_cancel` → back to `searching` without the photographer (`photographer_id`, `assigned_at` cleared, `round` 1), a new search starts at once and never re-offers them (their accepted offer stays in `instant_offers`).
  - Route `cancelRequest`.

- [ ] **Step 1: Write the failing test**

```ts
// services/dispatch/test/cancel.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { heldVnd } from '../src/payments/events.js';
import {
  HCM, addCustomer, addPhotographer, as, fixAt, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addPhotographer(db, 'p1');
  await addPhotographer(db, 'p2');
  await online(app, 'p1', north(HCM, 1), w.clock.now());
  await online(app, 'p2', north(HCM, 2), w.clock.now());
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

const cancel = (id: string, uid: string, dryRun: boolean) => app.inject({ method: 'POST', url: `/v1/requests/${id}/cancel`, headers: as(uid), payload: { dryRun } });
async function assigned(): Promise<string> {
  const id = await paidRequest(app, 'c1');
  await w.runDue();
  const offer = await db.selectFrom('dispatch.instant_offers').select('id').where('photographer_id', '=', 'p1').where('outcome', '=', 'pending').executeTakeFirstOrThrow();
  expect((await app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as('p1') })).statusCode).toBe(200);
  return id;
}
async function money(id: string) {
  const pay = await db.selectFrom('payments').selectAll().where('subject_id', '=', id).executeTakeFirstOrThrow();
  const refunds = await db.selectFrom('refunds').select(['amount']).where('payment_id', '=', pay.id).execute();
  return { pay, refunded: refunds.reduce((s, r) => s + r.amount, 0), held: await heldVnd(w.deps, pay.id) };
}

describe('S55: dryRun shows exactly what the cancellation then does (spec §4)', () => {
  const cases: Array<[string, () => Promise<string>, number, string, number, number]> = [
    // name, setup → requestId, minutes to wait, rule, refund, photographer
    ['searching', () => paidRequest(app, 'c1'), 0, 'free_searching', 600_000, 0],
    ['within 2 minutes of assigned', assigned, 1, 'free_grace', 600_000, 0],
    ['on the way after 2 minutes', assigned, 3, 'en_route_fee', 480_000, 120_000],
  ];
  for (const [name, setup, wait, rule, refund, photographer] of cases) {
    it(name, async () => {
      const id = await setup();
      w.clock.advance(wait * 60_000);
      const quote = await cancel(id, 'c1', true);
      expect(quote.statusCode).toBe(200);
      expect(quote.json()).toMatchObject({ rule, refundVnd: refund, photographerVnd: photographer, platformVnd: 0 });
      const applied = await cancel(id, 'c1', false);
      expect(applied.json()).toEqual(quote.json());
      expect(w.mirror.requests.get(id)?.status).toBe('cancelled_by_customer');
      await w.runDue();
      const m = await money(id);
      expect(m.refunded).toBe(refund);
      expect(m.held).toBe(photographer);
      expect(m.refunded + m.held).toBe(600_000);
      expect(m.pay.payee_id).toBe(photographer > 0 ? 'p1' : null);
      expect((await cancel(id, 'c1', false)).statusCode).toBe(409);
    });
  }

  it('grace end is in the quote while assigned', async () => {
    const id = await assigned();
    expect((await cancel(id, 'c1', true)).json().graceEndsAt).toBe('2026-10-01T08:02:00.000Z');
  });

  it('photographer later than the initial ETA + 15 min: 100 % back, photographer penalised', async () => {
    const id = await assigned();
    // p1 was 1 km away: estimate 5 min → late after 20 min.
    w.clock.advance(19 * 60_000);
    expect((await cancel(id, 'c1', true)).json().rule).toBe('en_route_fee');
    w.clock.advance(60_000);
    expect((await cancel(id, 'c1', false)).json()).toMatchObject({ rule: 'photographer_fault', refundVnd: 600_000 });
    const rel = await db.selectFrom('dispatch.photographer_reliability').select('no_show').where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
    expect(rel.no_show).toBe(1);
  });

  it('the photographer cancels: the request searches again without them, nothing is refunded yet', async () => {
    const id = await assigned();
    expect((await cancel(id, 'p1', false)).json()).toMatchObject({ rule: 'photographer_cancel', refundVnd: 600_000 });
    expect(w.mirror.requests.get(id)).toMatchObject({ status: 'searching', photographerId: null, meetPoint: null });
    await w.runDue();
    const offers = await db.selectFrom('dispatch.instant_offers').select(['photographer_id', 'outcome']).where('request_id', '=', id).orderBy('id').execute();
    expect(offers).toEqual([{ photographer_id: 'p1', outcome: 'accepted' }, { photographer_id: 'p2', outcome: 'pending' }]);
    expect((await money(id)).held).toBe(600_000);
    const rel = await db.selectFrom('dispatch.photographer_reliability').select('cancelled').where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
    expect(rel.cancelled).toBe(1);
  });

  it('no-show: the photographer reports it after 15 minutes at the meet point → 50 / 50', async () => {
    const id = await assigned();
    await app.inject({ method: 'POST', url: `/v1/requests/${id}/arrive`, headers: as('p1'), payload: { fix: fixAt(HCM, w.clock.now()) } });
    w.clock.advance(14 * 60_000);
    expect((await cancel(id, 'p1', false)).statusCode).toBe(409);
    w.clock.advance(60_000);
    expect((await cancel(id, 'p1', false)).json()).toMatchObject({ rule: 'no_show', refundVnd: 300_000, photographerVnd: 300_000 });
    expect(w.mirror.requests.get(id)?.status).toBe('no_show_customer');
    await w.runDue();
    expect((await money(id)).held).toBe(300_000);
  });

  it('strangers cannot cancel; unknown request → 404', async () => {
    const id = await paidRequest(app, 'c1');
    await addCustomer(db, 'c9');
    expect((await cancel(id, 'c9', true)).statusCode).toBe(403);
    expect((await cancel('01J9ZZZZZZZZZZZZZZZZZZZZZZ', 'c1', true)).statusCode).toBe(404);
  });
});
```

In `test/contract.test.ts` remove `'cancelRequest'` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/cancel.test.ts`
Expected: FAIL: `POST /v1/requests/{id}/cancel` answers 404.

- [ ] **Step 3: Implement**

```ts
// services/dispatch/src/requests/cancel.ts
import { cityConfig } from '../catalog/catalog.js';
import {
  DispatchError, addMs, etaFromReasons, lateDeadline, quoteCancel, searchEndsAt, startSearch, type CancelQuote,
} from '../domain/core.js';
import type { Deps } from '../deps.js';
import { applySplit, paymentForRequest } from '../payments/ledger.js';
import { COMPARE_AND_DELETE, keys } from '../redis/keys.js';
import { bumpReliability } from '../settings/facts.js';
import { publishRequest } from './publish.js';
import { bump, loadRequest, saveSearch, type Exec, type RequestRow } from './rows.js';

export interface CancelResult {
  rule: CancelQuote['rule'];
  refundVnd: number;
  photographerVnd: number;
  platformVnd: number;
  graceEndsAt: string | null;
}

const wire = (q: CancelQuote): CancelResult => ({
  rule: q.rule, refundVnd: q.refundVnd, photographerVnd: q.photographerVnd, platformVnd: q.platformVnd,
  graceEndsAt: q.graceEndsAt?.toISOString() ?? null,
});

/** Initial ETA of the accepted offer (its `near` reason) → the 15-minute lateness rule. */
async function lateDeadlineOf(db: Exec, req: RequestRow, cfg: ReturnType<typeof cityConfig>): Promise<Date | null> {
  if (!req.assignedAt || !req.photographerId) return null;
  const offer = await db
    .selectFrom('dispatch.instant_offers')
    .select('reasons')
    .where('request_id', '=', req.id)
    .where('photographer_id', '=', req.photographerId)
    .where('outcome', '=', 'accepted')
    .executeTakeFirst();
  const eta = offer ? etaFromReasons(offer.reasons as Array<{ code: string; etaMinutes?: number }>) : null;
  return eta === null ? null : lateDeadline(req.assignedAt, eta, cfg);
}

async function quoteFor(db: Exec, deps: Deps, req: RequestRow, uid: string, now: Date): Promise<CancelQuote> {
  const actor = req.customerId === uid ? 'customer' : req.photographerId === uid ? 'photographer' : null;
  if (!actor) throw new DispatchError('permission_denied');
  const cfg = cityConfig(deps, req.cityId);
  const paid = req.status !== 'pending_payment';
  return quoteCancel(
    {
      actor, status: req.status, collectedVnd: paid ? req.amountVnd : 0, assignedAt: req.assignedAt, arrivedAt: req.arrivedAt,
      lateDeadline: await lateDeadlineOf(db, req, cfg), now,
    },
    cfg,
  );
}

/**
 * POST /v1/requests/{id}/cancel (spec §4, S55). `dryRun` returns the quote without changing
 * anything; otherwise the same quote, recomputed under the row lock with the server clock, is
 * applied: status, money (refund + ledger), reliability penalty. A photographer's cancellation
 * puts the request back to searching without them (spec §3.1).
 */
export async function cancelRequest(deps: Deps, uid: string, requestId: string, body: { dryRun: boolean; reason?: string }): Promise<CancelResult> {
  const now = deps.clock.now();
  if (body.dryRun) {
    const req = await loadRequest(deps.db, requestId);
    if (!req) throw new DispatchError('not_found');
    return wire(await quoteFor(deps.db, deps, req, uid, now));
  }
  const done = await deps.db.transaction().execute(async (trx) => {
    const req = await loadRequest(trx, requestId, true);
    if (!req) throw new DispatchError('not_found');
    const q = await quoteFor(trx, deps, req, uid, now);
    const cfg = cityConfig(deps, req.cityId);
    if (q.nextStatus === 'searching') {
      await trx
        .updateTable('dispatch.instant_requests')
        .set({ status: 'searching', photographer_id: null, assigned_at: null, round: 1, version: bump() })
        .where('id', '=', requestId)
        .execute();
    } else {
      await trx
        .updateTable('dispatch.instant_requests')
        .set({ status: q.nextStatus, cancelled_at: now, cancel_reason: body.reason ?? q.rule, version: bump() })
        .where('id', '=', requestId)
        .execute();
    }
    const withdrawn = await trx
      .updateTable('dispatch.instant_offers')
      .set({ outcome: 'withdrawn', decided_at: now })
      .where('request_id', '=', requestId)
      .where('outcome', '=', 'pending')
      .returning(['id', 'photographer_id'])
      .execute();
    let refundId: string | null = null;
    if (q.settlesNow) {
      const pay = await paymentForRequest(trx, requestId);
      if (pay && pay.status === 'paid') {
        refundId = await applySplit(trx, {
          paymentId: pay.id, collectedVnd: pay.amount, split: q, photographerId: req.photographerId,
          releaseAfter: addMs(now, cfg.completion.disputeWindowMs), now, note: `instant ${q.rule}`,
        });
      }
    }
    if (q.reliabilityPenalty && req.photographerId) await bumpReliability(trx, req.photographerId, q.reliabilityPenalty === 'no_show' ? 'no_show' : 'cancelled', now);
    return { req, q, withdrawn, refundId };
  });

  const { req, q } = done;
  for (const w of done.withdrawn) {
    await deps.redis.eval(COMPARE_AND_DELETE, 1, keys.offerLock(w.photographer_id), w.id);
    await deps.mirror.deleteOffer(w.photographer_id, w.id);
  }
  if (done.refundId) await deps.scheduler.schedule('refund', done.refundId, now);
  await deps.mirror.deleteTrack(requestId);
  await deps.redis.del(keys.trip(requestId), keys.etaGate(requestId), keys.locationGate(requestId));
  if (q.nextStatus === 'searching') {
    const cfg = cityConfig(deps, req.cityId);
    const state = startSearch(now, req.expand);
    const area = (await deps.redis.hget(keys.search(requestId), 'area')) ?? '';
    await saveSearch(deps, requestId, { state, area });
    await deps.scheduler.schedule('match', requestId, now);
    await deps.scheduler.schedule('search-timeout', requestId, searchEndsAt(state, cfg));
  } else {
    await deps.redis.del(keys.search(requestId));
  }
  await publishRequest(deps, requestId);
  const other = uid === req.customerId ? req.photographerId : req.customerId;
  if (other) await deps.push.send(other, { type: 'status', requestId, status: q.nextStatus });
  return wire(q);
}
```

Replace `services/dispatch/src/routes/requests.ts` with:

```ts
// services/dispatch/src/routes/requests.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { route } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { cancelRequest } from '../requests/cancel.js';
import { createRequest } from '../requests/create.js';
import { arrive, confirmComplete, finishShoot, postLocation, startShoot } from '../requests/trip.js';

type S = components['schemas'];
type Id = { requestId: string };

export function registerRequestRoutes(app: FastifyInstance, deps: RouteDeps): void {
  const c = deps.contract;
  app.route<{ Body: S['CreateRequestBody'] }>({
    ...route(c, 'createRequest'),
    handler: async (req, reply) => {
      const b = req.body;
      const created = await createRequest(deps, principalOf(req).uid, {
        packageId: b.packageId, genre: b.genre, meetPoint: b.meetPoint, note: b.note, expand: b.expand,
        expectedAmountVnd: b.expectedAmountVnd, provider: b.provider,
      });
      return reply.status(201).send(created satisfies S['CreateRequestResponse']);
    },
  });
  app.route<{ Params: Id; Body: S['CancelBody'] }>({
    ...route(c, 'cancelRequest'),
    handler: async (req) => cancelRequest(deps, principalOf(req).uid, req.params.requestId, req.body) satisfies Promise<S['CancelQuote']>,
  });
  app.route<{ Params: Id; Body: S['LocationFix'] }>({
    ...route(c, 'postLocation'),
    handler: async (req, reply) => {
      await postLocation(deps, principalOf(req).uid, req.params.requestId, req.body);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id; Body: S['ArriveBody'] }>({
    ...route(c, 'arrive'),
    handler: async (req, reply) => {
      await arrive(deps, principalOf(req).uid, req.params.requestId, req.body);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id }>({
    ...route(c, 'startShoot'),
    handler: async (req, reply) => {
      await startShoot(deps, principalOf(req).uid, req.params.requestId);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id }>({
    ...route(c, 'finishShoot'),
    handler: async (req, reply) => {
      await finishShoot(deps, principalOf(req).uid, req.params.requestId);
      return reply.status(204).send();
    },
  });
  app.route<{ Params: Id }>({
    ...route(c, 'confirmComplete'),
    handler: async (req, reply) => {
      await confirmComplete(deps, principalOf(req).uid, req.params.requestId);
      return reply.status(204).send();
    },
  });
}
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  15 passed | 1 skipped (16)`, `Tests  88 passed | 3 skipped (91)`. `PENDING` in `test/contract.test.ts` is now empty: every contract operation is routed.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "feat(dispatch): cancellation quotes and settlement for customers and photographers, re-search after a photographer cancels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Concurrency, real timers and restart resilience

**Files:**
- Create: `services/dispatch/test/concurrency.test.ts`, `services/dispatch/test/bullmq.test.ts`
- Modify: `services/dispatch/src/jobs/handlers.ts` (replace), `services/dispatch/src/server.ts` (replace)

**Interfaces:**
- Consumes: everything above; `BullScheduler`, `startWorker` (Task 5).
- Produces: `reconcile(deps): Promise<{ searching; offers; finishing; refunds }>` (boot: re-adds `match` + `search-timeout` for every `searching` request, `offer-expire` for every pending offer, `auto-complete` for finished shoots, `refund` for pending refunds of the last 7 days; idempotent); `server.ts` runs it whenever the process has a worker (`ROLE=all|worker`).

Tests (spec §11 "Dịch vụ"): 50 simultaneous requests and 30 photographers, every matcher run twice at once (duplicate job delivery) → never two pending offers for one photographer or one request, and each `offerlock` equals the photographer's pending offer; two photographers accepting the same request at the same moment → exactly one `200`, the other `already_assigned`, the loser's offer `withdrawn`; accept racing the expiry job at 29.999 s → the server clock decides; real BullMQ delayed jobs with a compressed search (offers 400 ms, round 2 s, total 4 s): expiry hands over to the next photographer and the search ends in `no_match` with a completed refund; a worker stopped with an offer open and restarted after the offer's time → `reconcile` + the persisted jobs carry on and the next photographer gets the offer.

- [ ] **Step 1: Write the tests**

```ts
// services/dispatch/test/concurrency.test.ts
import type { FastifyInstance } from 'fastify';
import { sql } from 'kysely';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { runMatch } from '../src/matcher/matcher.js';
import { expireOffer } from '../src/offers/offers.js';
import { keys } from '../src/redis/keys.js';
import {
  HCM, PACKAGES, addCustomer, addPhotographer, as, north, online, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeEach(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
});
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

async function createAndPay(customer: string): Promise<string> {
  const res = await app.inject({
    method: 'POST', url: '/v1/requests', headers: as(customer),
    payload: { packageId: PACKAGES.p60, genre: 'portrait', meetPoint: { ...HCM, address: 'Chợ Bến Thành' }, expand: false, expectedAmountVnd: 600_000, provider: 'fake' },
  });
  const id = (res.json() as { requestId: string }).requestId;
  await app.inject({ method: 'POST', url: `/v1/dev/payments/${id}/succeed`, headers: as(customer) });
  return id;
}

describe('concurrency (spec §11)', () => {
  it('50 simultaneous requests never offer one photographer twice at the same time', async () => {
    for (let i = 0; i < 30; i++) {
      await addPhotographer(db, `p${i}`);
      await online(app, `p${i}`, north(HCM, 0.2 + (i % 10) * 0.25), w.clock.now());
    }
    for (let i = 0; i < 50; i++) await addCustomer(db, `c${i}`);
    const ids = await Promise.all(Array.from({ length: 50 }, (_, i) => createAndPay(`c${i}`)));
    // Every request's matcher at once, twice (duplicate job deliveries), on separate connections.
    const results = await Promise.all([...ids, ...ids].map((id) => runMatch(w.deps, id)));
    expect(results.filter((r) => r.kind === 'offered')).toHaveLength(30);

    const perPhotographer = await sql<{ photographer_id: string; n: number }>`
      select photographer_id, count(*)::int as n from dispatch.instant_offers where outcome = 'pending' group by photographer_id having count(*) > 1`.execute(db);
    expect(perPhotographer.rows).toEqual([]);
    const perRequest = await sql<{ request_id: string; n: number }>`
      select request_id, count(*)::int as n from dispatch.instant_offers where outcome = 'pending' group by request_id having count(*) > 1`.execute(db);
    expect(perRequest.rows).toEqual([]);
    for (let i = 0; i < 30; i++) {
      const lock = await redis.get(keys.offerLock(`p${i}`));
      const pending = await db.selectFrom('dispatch.instant_offers').select('id').where('photographer_id', '=', `p${i}`).where('outcome', '=', 'pending').executeTakeFirst();
      expect(lock).toBe(pending?.id ?? null);
    }
  });

  it('two photographers accept the same request at the same moment: exactly one wins', async () => {
    await addCustomer(db, 'c1');
    await addPhotographer(db, 'p1');
    await addPhotographer(db, 'p2');
    const id = await createAndPay('c1');
    const now = w.clock.now();
    const offer = (oid: string, uid: string) => ({
      id: oid, request_id: id, photographer_id: uid, round: 1 as const, score: 0.8, reasons: '[]', offered_at: now,
      expires_at: new Date(now.getTime() + 30_000), outcome: 'pending' as const,
    });
    // Two pending offers for one request can only come from a bug or a race; the accept must still hold.
    await db.insertInto('dispatch.instant_offers').values([offer('01J9ZXFF00000000000000000A', 'p1'), offer('01J9ZXFF00000000000000000B', 'p2')]).execute();
    const [a, b] = await Promise.all([
      app.inject({ method: 'POST', url: '/v1/offers/01J9ZXFF00000000000000000A/accept', headers: as('p1') }),
      app.inject({ method: 'POST', url: '/v1/offers/01J9ZXFF00000000000000000B/accept', headers: as('p2') }),
    ]);
    const codes = [a, b].map((r) => (r.statusCode === 200 ? 'won' : r.json().code)).sort();
    expect(codes).toEqual(['already_assigned', 'won']);
    const row = await db.selectFrom('dispatch.instant_requests').select(['status', 'photographer_id']).where('id', '=', id).executeTakeFirstOrThrow();
    const winner = a.statusCode === 200 ? 'p1' : 'p2';
    expect(row).toEqual({ status: 'assigned', photographer_id: winner });
    const outcomes = await db.selectFrom('dispatch.instant_offers').select(['photographer_id', 'outcome']).where('request_id', '=', id).orderBy('photographer_id').execute();
    expect(outcomes).toEqual([
      { photographer_id: 'p1', outcome: winner === 'p1' ? 'accepted' : 'withdrawn' },
      { photographer_id: 'p2', outcome: winner === 'p2' ? 'accepted' : 'withdrawn' },
    ]);
  });

  it('accept racing the expiry job at the 30 s boundary: one outcome, never both', async () => {
    await addCustomer(db, 'c1');
    await addPhotographer(db, 'p1');
    await online(app, 'p1', north(HCM, 0.5), w.clock.now());
    const id = await createAndPay('c1');
    await w.runDue();
    const offer = await db.selectFrom('dispatch.instant_offers').select('id').where('request_id', '=', id).executeTakeFirstOrThrow();
    w.clock.advance(29_999);
    const [res] = await Promise.all([
      app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as('p1') }),
      expireOffer(w.deps, offer.id),
    ]);
    const final = await db.selectFrom('dispatch.instant_offers').select('outcome').where('id', '=', offer.id).executeTakeFirstOrThrow();
    expect(res.statusCode).toBe(200); // the job is not due yet at 29.999 s: the server clock is the referee
    expect(final.outcome).toBe('accepted');
  });
});
```

```ts
// services/dispatch/test/bullmq.test.ts
import type { FastifyInstance } from 'fastify';
import type { Worker } from 'bullmq';
import { afterAll, afterEach, beforeEach, describe, expect, it } from 'vitest';

import type { Deps } from '../src/deps.js';
import { defaultBook, systemClock } from '../src/domain/core.js';
import { jobHandlers, reconcile } from '../src/jobs/handlers.js';
import { BullScheduler, startWorker } from '../src/jobs/scheduler.js';
import { createBullConnection } from '../src/redis/client.js';
import {
  HCM, addCustomer, addPhotographer, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld,
} from './helpers.js';

/** Real BullMQ delayed jobs and real time, with the search compressed to seconds. */
const FAST = defaultBook();
const fastBook = {
  base: {
    ...FAST.base,
    offerTtlMs: 400,
    idleRetryMs: 200,
    round1: { maxMs: 2_000, radiiKm: [3, 6, 10] },
    round2: { maxMs: 2_000, radiusKm: 10 },
    totalSearchMs: 4_000,
  },
  cities: {},
};

const db = testDb();
const redis = testRedis();
const url = process.env.TEST_REDIS_URL ?? '';
let deps: Deps;
let app: FastifyInstance;
let scheduler: BullScheduler;
let worker: Worker | null = null;
const conn = createBullConnection(url);

const until = async (f: () => Promise<boolean>, ms: number): Promise<void> => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await f()) return;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error('condition not met in time');
};
const offers = (id: string) => db.selectFrom('dispatch.instant_offers').select(['photographer_id', 'outcome']).where('request_id', '=', id).orderBy('id').execute();
const status = async (id: string) => (await db.selectFrom('dispatch.instant_requests').select('status').where('id', '=', id).executeTakeFirstOrThrow()).status;

beforeEach(async () => {
  await resetAll(db, redis);
  scheduler = new BullScheduler(conn, () => systemClock.now(), `dispatch-test-${Date.now()}`);
  const w = testWorld(db, redis, { book: fastBook });
  deps = { ...w.deps, clock: systemClock, scheduler };
  app = await testApp({ ...w, deps });
  worker = startWorker(conn, jobHandlers(deps), scheduler.queue.name);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addPhotographer(db, 'p1');
  await addPhotographer(db, 'p2');
});
afterEach(async () => {
  await worker?.close();
  await scheduler.queue.obliterate({ force: true });
  await scheduler.close();
  await app.close();
});
afterAll(async () => {
  conn.disconnect();
  redis.disconnect();
  await db.destroy();
});

describe('timers on BullMQ (spec §5, §11)', () => {
  it('offer expiry hands over to the next photographer, then the search times out into no_match with a refund', async () => {
    await online(app, 'p1', north(HCM, 0.5), new Date());
    await online(app, 'p2', north(HCM, 1.0), new Date());
    const id = await paidRequest(app, 'c1');
    await until(async () => (await offers(id)).length === 1, 2_000);
    await until(async () => (await offers(id)).length === 2, 2_000);
    expect((await offers(id))[0]).toEqual({ photographer_id: 'p1', outcome: 'expired' });
    await until(async () => (await status(id)) === 'no_match', 4_000);
    await until(async () => {
      const r = await db.selectFrom('refunds as f').innerJoin('payments as p', 'p.id', 'f.payment_id').select('f.status').where('p.subject_id', '=', id).executeTakeFirst();
      return r?.status === 'done';
    }, 2_000);
  });

  it('a restart in the middle of a search loses nothing: the next process picks the jobs up', async () => {
    await online(app, 'p1', north(HCM, 0.5), new Date());
    await online(app, 'p2', north(HCM, 1.0), new Date());
    const id = await paidRequest(app, 'c1');
    await until(async () => (await offers(id)).length === 1, 2_000);
    await worker?.close(); // the process dies with an offer open
    worker = null;
    await new Promise((r) => setTimeout(r, 600)); // the offer's 400 ms pass while nothing runs
    worker = startWorker(conn, jobHandlers(deps), scheduler.queue.name); // a new process starts
    expect((await reconcile(deps)).searching).toBe(1);
    await until(async () => (await offers(id)).some((o) => o.photographer_id === 'p2'), 2_000);
    expect((await offers(id))[0]).toEqual({ photographer_id: 'p1', outcome: 'expired' });
  });
});
```

- [ ] **Step 2: Run and see them fail**

Run: `npm test -- test/concurrency.test.ts test/bullmq.test.ts`
Expected: the concurrency tests pass already (they exercise Tasks 10–12); `bullmq.test.ts` FAILS to load: `SyntaxError: The requested module '../src/jobs/handlers.js' does not provide an export named 'reconcile'`.

- [ ] **Step 3: Implement**

Replace `services/dispatch/src/jobs/handlers.ts` with:

```ts
// services/dispatch/src/jobs/handlers.ts
import { sql } from 'kysely';

import { cityConfig } from '../catalog/catalog.js';
import type { Deps } from '../deps.js';
import { searchEndsAt } from '../domain/core.js';
import { runMatch, searchTimeout } from '../matcher/matcher.js';
import { expireOffer } from '../offers/offers.js';
import { executeRefund, expirePayment } from '../payments/events.js';
import { loadSearch } from '../requests/rows.js';
import { autoComplete, noShowDue } from '../requests/trip.js';
import type { JobHandlers } from './scheduler.js';

export function jobHandlers(deps: Deps): JobHandlers {
  return {
    'payment-timeout': (requestId) => expirePayment(deps, requestId),
    refund: (refundId) => executeRefund(deps, refundId),
    match: async (requestId) => {
      await runMatch(deps, requestId);
    },
    'search-timeout': (requestId) => searchTimeout(deps, requestId),
    'offer-expire': (offerId) => expireOffer(deps, offerId),
    'auto-complete': (requestId) => autoComplete(deps, requestId),
    'no-show': (requestId) => noShowDue(deps, requestId),
  };
}

/**
 * Boot-time reconciliation (spec §10 "Dịch vụ điều phối sập"): PostgreSQL is the truth; make sure
 * every open item has its timer even if Redis lost jobs. Re-adding an existing job id is a no-op.
 */
export async function reconcile(deps: Deps): Promise<{ searching: number; offers: number; finishing: number; refunds: number }> {
  const now = deps.clock.now();
  const searching = await deps.db.selectFrom('dispatch.instant_requests').select(['id', 'city_id']).where('status', '=', 'searching').execute();
  for (const r of searching) {
    const rec = await loadSearch(deps, r.id);
    await deps.scheduler.schedule('match', r.id, now);
    await deps.scheduler.schedule('search-timeout', r.id, rec ? searchEndsAt(rec.state, cityConfig(deps, r.city_id)) : now);
  }
  const offers = await deps.db.selectFrom('dispatch.instant_offers').select(['id', 'expires_at']).where('outcome', '=', 'pending').execute();
  for (const o of offers) await deps.scheduler.schedule('offer-expire', o.id, o.expires_at);
  const finishing = await deps.db
    .selectFrom('dispatch.instant_requests')
    .select(['id', 'finished_at', 'city_id'])
    .where('status', '=', 'in_progress')
    .where('finished_at', 'is not', null)
    .execute();
  for (const f of finishing) {
    if (f.finished_at) {
      await deps.scheduler.schedule('auto-complete', f.id, new Date(f.finished_at.getTime() + cityConfig(deps, f.city_id).completion.autoCompleteMs));
    }
  }
  const refunds = await deps.db
    .selectFrom('refunds as f')
    .innerJoin('payments as p', 'p.id', 'f.payment_id')
    .select('f.id')
    .where('p.subject_type', '=', 'instant_request')
    .where('f.status', '=', 'pending')
    .where('f.manual', '=', false)
    .where(sql<boolean>`f.created_at > now() - interval '7 days'`)
    .execute();
  for (const f of refunds) await deps.scheduler.schedule('refund', f.id, now);
  return { searching: searching.length, offers: offers.length, finishing: finishing.length, refunds: refunds.length };
}
```

Replace `services/dispatch/src/server.ts` with:

```ts
// services/dispatch/src/server.ts
import { buildApp } from './app.js';
import { EmulatorVerifier, firebaseVerifier } from './auth/identity.js';
import { loadConfig } from './config.js';
import { jobHandlers, reconcile } from './jobs/handlers.js';
import { startWorker } from './jobs/scheduler.js';
import { wire } from './wiring.js';

const config = loadConfig();
const w = await wire(config);
const verifier =
  config.authMode === 'firebase' ? firebaseVerifier(config.firebaseProjectId) : new EmulatorVerifier({ projectId: config.firebaseProjectId });

const worker = config.role === 'api' ? null : startWorker(w.bullConnection, jobHandlers(w.deps));
if (worker) {
  const r = await reconcile(w.deps);
  w.deps.log.info(r, 'reconciled open requests');
}
const app = config.role === 'worker' ? null : await buildApp({ deps: w.deps, verifier, metricsEndpoint: config.metricsEndpoint });

async function shutdown(): Promise<void> {
  await app?.close();
  await worker?.close();
  await w.close();
}
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    void shutdown().then(() => process.exit(0));
  });
}
if (app) await app.listen({ port: config.port, host: config.host });
```

- [ ] **Step 4: Run and see them pass**

Run: `npm run typecheck && npm test`
Expected: clean; `Test Files  17 passed | 1 skipped (18)`, `Tests  93 passed | 3 skipped (96)`. The BullMQ tests take about 10 s. If the concurrency test shows two pending offers for one photographer, the offer lock is not taken before the insert: fix `runMatch`, never loosen the test.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch
git commit -m "test(dispatch): no double offers under 50 concurrent requests, one accept winner, BullMQ timers and restart reconciliation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Performance check

**Files:**
- Create: `services/dispatch/perf/simulate.ts`, `services/dispatch/perf/k6-dispatch.js`, `services/dispatch/test/perf-explain.test.ts`, `services/dispatch/test/budget.test.ts`, `services/dispatch/test/payload.test.ts`
- Modify: `services/api/docker-compose.yml`, `services/dispatch/package.json`, `services/dispatch/README.md`

**Interfaces:**
- Consumes: the hot query builders `requestQuery`, `activeRequestQuery`, `offeredQuery`, `pendingOfferQuery`, `busyQuery`; `GET /internal/metrics` (`matcher_ms`, `first_offer_ms`); the dev catalog (Task 8).
- Produces: EXPLAIN assertions for the hot queries; Redis command budgets per step; Firestore write budget per request; payload byte budgets; the load harness (`npm run simulate -- seed | online | bots [min] | report`) and k6 scenario with thresholds.

Budgets:

| What | Where | Budget | Why |
|---|---|---|---|
| First offer after payment | load test (`report`) | p95 < 2 s | spec §11 |
| Matcher run (Redis + PostgreSQL + ranking) | load test (`/internal/metrics`) | p95 < 50 ms | spec §11 |
| Duplicate offers | load test (`report`) | 0 photographers with two overlapping open offers; 0 re-offers | spec §3.2, §11 |
| `createRequest`, `devPaymentSucceed` | k6 | p95 < 300 ms / < 200 ms; `http_req_failed` < 1 % | customer waits on these |
| Hot queries | `perf-explain.test.ts` (60k requests, 180k offers) | index scans only, no `Seq Scan` | §2.8 indexes (+ Task 1's `instant_requests_customer`) |
| Redis commands | `budget.test.ts` | presence update ≤ 8; create + pay ≤ 8; matcher run that offers ≤ 14; accept ≤ 12; location ≤ 6; arrive ≤ 6; start + finish + confirm ≤ 12; whole request ≤ 110 | one command server per city cluster; ~1,700 commands/s at 100 requests/min with 2,000 photographers refreshing presence |
| Firestore writes per request | `budget.test.ts` | ≤ 25 (one request doc per change, one offer doc + delete, 10 track writes + delete) | billing and the app's listener traffic |
| Payloads | `payload.test.ts` | packages ≤ 640 B, create ≤ 160 B, accept ≤ 220 B, cancel quote ≤ 160 B; mirror request ≤ 1,100 B, offer ≤ 400 B, track ≤ 140 B; FCM data < 512 B (Task 5; the offer carries the whole offer) | radio time on 3G/4G |

`GET /v1/packages` reads the 7-day median from a 10-minute Redis cache (`typical:{city}`), so its seq-scan-prone aggregate runs at most 6 times an hour per city; the city lookup (`ST_Covers` on a handful of rows) is exempt from the no-seq-scan rule.

**Battery and network impact on the app (for plans I4/I5):** no polling anywhere — status, offers and the photographer's position arrive through Firestore listeners on three small documents, and FCM only wakes the app (high priority only for offers and assignment). While on the way, the app sends a fix every 10–15 s (spec §9); the server accepts at most one per 5 s (429 `limit_exceeded` beyond, so a buggy client cannot drain the battery or the quota) and calls Goong at most once a minute. While available, the app re-sends presence only when it moved > 300 m or every 5 minutes, before `expiresAt` (10-minute TTL). The track document is deleted at arrival, so the customer's listener goes quiet and the map can stop.

- [ ] **Step 1: Write the server tests**

```ts
// services/dispatch/test/perf-explain.test.ts
import { CompiledQuery, sql, type Compilable } from 'kysely';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { busyQuery, offeredQuery, pendingOfferQuery } from '../src/matcher/matcher.js';
import { activeRequestQuery } from '../src/requests/create.js';
import { requestQuery } from '../src/requests/rows.js';
import { T0, resetAll, seedCatalog, testDb, testRedis } from './helpers.js';

interface PlanNode {
  'Node Type': string;
  'Relation Name'?: string;
  'Index Name'?: string;
  Plans?: PlanNode[];
}
const db = testDb();
const redis = testRedis();
const nodes = (n: PlanNode): PlanNode[] => [n, ...(n.Plans ?? []).flatMap(nodes)];

async function explain(q: Compilable): Promise<PlanNode[]> {
  const c = q.compile();
  const r = await db.executeQuery<{ 'QUERY PLAN': Array<{ Plan: PlanNode }> }>(CompiledQuery.raw(`explain (format json) ${c.sql}`, [...c.parameters]));
  return nodes(r.rows[0]!['QUERY PLAN'][0]!.Plan);
}

beforeAll(async () => {
  await resetAll(db, redis);
  await seedCatalog(db);
  // A busy month: 20k customers, 2k photographers, 60k requests, 180k offers.
  await sql`insert into users (id, display_name, role) select 'c' || g, 'C', 'customer' from generate_series(1, 20000) g`.execute(db);
  await sql`insert into users (id, display_name, role) select 'p' || g, 'P', 'photographer' from generate_series(1, 2000) g`.execute(db);
  await sql`insert into photographers (user_id, onboarding_complete) select 'p' || g, true from generate_series(1, 2000) g`.execute(db);
  await sql`insert into dispatch.instant_requests (id, customer_id, package_id, city_id, genre, meet_point, meet_address,
      amount_vnd, payout_vnd, status, photographer_id, requested_at, assigned_at)
    select 'r' || g, 'c' || (g % 20000 + 1), '01J9ZP60000000000000000000', case when g % 3 = 0 then 'hn' else 'hcm' end, 'portrait',
      'SRID=4326;POINT(106.698 10.7725)', 'x', 600000, 480000,
      case when g % 500 = 0 then 'en_route' when g % 7 = 0 then 'no_match' else 'completed' end,
      case when g % 500 = 0 then 'p' || (g / 500) when g % 7 = 0 then null else 'p' || (g % 2000 + 1) end,
      ${T0}::timestamptz - (g || ' minutes')::interval, ${T0}::timestamptz - (g || ' minutes')::interval + interval '6 minutes'
    from generate_series(1, 60000) g`.execute(db);
  await sql`insert into dispatch.instant_offers (id, request_id, photographer_id, round, score, reasons, offered_at, expires_at, outcome)
    select 'o' || g || '_' || k, 'r' || g, 'p' || ((g + k * 7) % 2000 + 1), 1, 0.5, '[]', ${T0}, ${T0}, 'declined'
    from generate_series(1, 60000) g, generate_series(1, 3) k`.execute(db);
  await sql`analyze`.execute(db);
}, 180_000);
afterAll(async () => {
  await resetAll(db, redis);
  redis.disconnect();
  await db.destroy();
});

const INDEX_NODES = new Set(['Index Scan', 'Index Only Scan', 'Bitmap Index Scan']);
const ids = Array.from({ length: 50 }, (_, i) => `p${i * 40 + 1}`);

describe('hot queries use the indexes of relational-schema.md §2.8', () => {
  it.each<[string, () => Compilable, string[]]>([
    ['load request (every operation)', () => requestQuery(db, 'r12345'), ['instant_requests_pkey', 'instant_packages_pkey']],
    ['one open request per customer (create)', () => activeRequestQuery(db, 'c123'), ['instant_requests_customer']],
    ['offered before (matcher)', () => offeredQuery(db, 'r12345'), ['instant_offers_request']],
    ['pending offer of a request (matcher)', () => pendingOfferQuery(db, 'r12345'), ['instant_offers_request']],
    ['busy photographers among 50 candidates (matcher)', () => busyQuery(db, ids), ['instant_requests_one_open_job']],
  ])('%s: no sequential scan on a large table', async (_name, build, indexes) => {
    const plan = await explain(build());
    expect(plan.filter((n) => n['Node Type'] === 'Seq Scan').map((n) => n['Relation Name'])).toEqual([]);
    expect(plan.filter((n) => INDEX_NODES.has(n['Node Type'])).map((n) => n['Index Name'])).toEqual(expect.arrayContaining(indexes));
  });
});
```

```ts
// services/dispatch/test/budget.test.ts
import type { FastifyInstance } from 'fastify';
import type { Redis } from 'ioredis';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import {
  HCM, addCustomer, addPhotographer, as, fixAt, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

/** Counts every command our Redis client sends (BullMQ uses its own connection; ManualScheduler here). */
function counting(redis: Redis): { reset(): void; count(): number; names(): Record<string, number> } {
  const seen: Record<string, number> = {};
  const original = redis.sendCommand.bind(redis);
  redis.sendCommand = ((cmd: { name: string }, ...rest: unknown[]) => {
    seen[cmd.name] = (seen[cmd.name] ?? 0) + 1;
    return (original as (...a: unknown[]) => unknown)(cmd, ...rest);
  }) as typeof redis.sendCommand;
  return {
    reset: () => { for (const k of Object.keys(seen)) delete seen[k]; },
    count: () => Object.values(seen).reduce((a, b) => a + b, 0),
    names: () => ({ ...seen }),
  };
}

const db = testDb();
const redis = testRedis();
const meter = counting(redis);
let w: TestWorld;
let app: FastifyInstance;
beforeAll(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  for (let i = 0; i < 20; i++) await addPhotographer(db, `p${i}`);
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});

describe('Redis and Firestore budget of one request (spec §5; Task 16)', () => {
  it('stays within the per-step command budgets and the mirror write budget', async () => {
    const steps: Record<string, number> = {};
    const measure = async (name: string, budget: number, f: () => Promise<unknown>) => {
      meter.reset();
      await f();
      steps[name] = meter.count();
      expect(meter.count(), `${name}: ${JSON.stringify(meter.names())}`).toBeLessThanOrEqual(budget);
    };
    for (let i = 0; i < 20; i++) await online(app, `p${i}`, north(HCM, 0.3 + i * 0.1), w.clock.now());
    await measure('presence update', 8, () => online(app, 'p0', north(HCM, 0.3), w.clock.now()));
    w.mirror.writes = 0;
    let id = '';
    await measure('create + pay', 8, async () => {
      id = await paidRequest(app, 'c1');
    });
    await measure('matcher run that offers', 14, () => w.runDue());
    const offer = await db.selectFrom('dispatch.instant_offers').select(['id', 'photographer_id']).where('request_id', '=', id).executeTakeFirstOrThrow();
    await measure('accept', 12, () => app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as(offer.photographer_id) }));
    for (let i = 0; i < 10; i++) {
      await redis.del(`locgate:${id}`);
      await measure(`location ${i}`, 6, () => app.inject({ method: 'POST', url: `/v1/requests/${id}/location`, headers: as(offer.photographer_id), payload: fixAt(north(HCM, 0.3 - i * 0.02), w.clock.now()) }));
    }
    await measure('arrive', 6, () => app.inject({ method: 'POST', url: `/v1/requests/${id}/arrive`, headers: as(offer.photographer_id), payload: { fix: fixAt(HCM, w.clock.now()) } }));
    await measure('start + finish + confirm', 12, async () => {
      await app.inject({ method: 'POST', url: `/v1/requests/${id}/start`, headers: as(offer.photographer_id) });
      await app.inject({ method: 'POST', url: `/v1/requests/${id}/finish`, headers: as(offer.photographer_id) });
      await app.inject({ method: 'POST', url: `/v1/requests/${id}/confirm-complete`, headers: as('c1') });
    });
    const total = Object.entries(steps).filter(([k]) => k !== 'presence update').reduce((s, [, v]) => s + v, 0);
    expect(total, JSON.stringify(steps)).toBeLessThanOrEqual(110);
    // Firestore: one request doc per state change, one offer doc, ten track writes, one delete each.
    expect(w.mirror.writes).toBeLessThanOrEqual(25);
    console.log('redis commands per step', steps, 'mirror writes', w.mirror.writes);
  });
});
```

```ts
// services/dispatch/test/payload.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import {
  HCM, PACKAGES, addCustomer, addPhotographer, as, north, online, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeAll(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addPhotographer(db, 'p1');
  await online(app, 'p1', north(HCM, 0.5), w.clock.now());
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});

const bytes = (v: unknown) => Buffer.byteLength(JSON.stringify(v));

describe('payload sizes (mobile radio time and Firestore document size; Task 16)', () => {
  it('API responses and mirror documents stay small', async () => {
    const pk = await app.inject({ method: 'GET', url: '/v1/packages?cityId=hcm', headers: as('c1') });
    expect(pk.rawPayload.byteLength).toBeLessThanOrEqual(640);
    const created = await app.inject({
      method: 'POST', url: '/v1/requests', headers: as('c1'),
      payload: { packageId: PACKAGES.p60, genre: 'portrait', meetPoint: { ...HCM, address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' }, expand: false, expectedAmountVnd: 600_000, provider: 'fake' },
    });
    expect(created.rawPayload.byteLength).toBeLessThanOrEqual(160);
    const id = (created.json() as { requestId: string }).requestId;
    await app.inject({ method: 'POST', url: `/v1/dev/payments/${id}/succeed`, headers: as('c1') });
    await w.runDue();
    expect(bytes(w.mirror.offers.get('p1'))).toBeLessThanOrEqual(400);
    const offer = await db.selectFrom('dispatch.instant_offers').select('id').executeTakeFirstOrThrow();
    const acc = await app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as('p1') });
    expect(acc.rawPayload.byteLength).toBeLessThanOrEqual(220);
    expect(bytes(w.mirror.requests.get(id))).toBeLessThanOrEqual(1_100);
    const quote = await app.inject({ method: 'POST', url: `/v1/requests/${id}/cancel`, headers: as('c1'), payload: { dryRun: true } });
    expect(quote.rawPayload.byteLength).toBeLessThanOrEqual(160);
    await app.inject({ method: 'POST', url: `/v1/requests/${id}/location`, headers: as('p1'), payload: { ...north(HCM, 0.4), accuracyM: 8, headingDeg: 180, speedMps: 6, at: w.clock.now().toISOString() } });
    expect(bytes(w.mirror.tracks.get(id))).toBeLessThanOrEqual(140);
  });
});
```

- [ ] **Step 2: Run them**

Run: `npm test -- test/perf-explain.test.ts test/budget.test.ts test/payload.test.ts`
Expected: PASS (5 + 1 + 1); the whole suite (`npm test`) now reports `Test Files  20 passed | 1 skipped (21)`, `Tests  100 passed | 3 skipped (103)`; `budget.test.ts` prints the commands per step and the mirror writes. If a plan shows `Seq Scan`, the query does not match an index of §2.8: rewrite the query; add an index only together with a `relational-schema.md` edit and a new migration. If a budget is exceeded, the printed per-command counts show which call crept in.

- [ ] **Step 3: Write the load harness and the k6 scenario**

```ts
// services/dispatch/perf/simulate.ts
// Load-test harness for services/dispatch (plan I3, Task 16; spec §11 "Tải").
//   npm run simulate -- seed      2,000 photographers in 3 cities, 1,200 customers with phones
//   npm run simulate -- online    every photographer PUT /v1/presence (emulator tokens)
//   npm run simulate -- bots 11   photographers answer offers for 11 minutes (accept 70 %, decline 15 %, ignore 15 %)
//   npm run simulate -- report    first-offer p95, matcher p95, duplicate offers; exit 1 on a missed threshold
// Env: DATABASE_URL (host port of the compose db), API_URL (default http://localhost:8090), FIREBASE_PROJECT_ID.
import { sql } from 'kysely';

import { createDb } from '../src/db/database.js';
import { seededRng } from '../src/domain/core.js';
import { DEV_CITIES, seedDev } from '../src/tools/seed-dev.js';

const API = process.env.API_URL ?? 'http://localhost:8090';
const PROJECT = process.env.FIREBASE_PROJECT_ID ?? 'demo-nag';
export const PHOTOGRAPHERS = 2_000;
export const CUSTOMERS = 1_200;
const pid = (i: number) => `sim_p_${String(i).padStart(4, '0')}`;
const cid = (i: number) => `sim_c_${String(i).padStart(4, '0')}`;
/** 50 % HCM, 35 % HN, 15 % DN. */
const cityOf = (i: number) => (i % 20 < 10 ? DEV_CITIES[0] : i % 20 < 17 ? DEV_CITIES[1] : DEV_CITIES[2]);

function token(uid: string): string {
  const now = Math.floor(Date.now() / 1000);
  const enc = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${PROJECT}`, aud: PROJECT, sub: uid, user_id: uid, iat: now, auth_time: now, exp: now + 6 * 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

async function call(uid: string, method: string, path: string, body?: unknown): Promise<{ status: number; json: unknown }> {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { authorization: `Bearer ${token(uid)}`, ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? (JSON.parse(text) as unknown) : null };
}

function spot(i: number) {
  const rng = seededRng(i + 1);
  const c = cityOf(i);
  const km = rng() * 8;
  const a = rng() * 2 * Math.PI;
  return { lat: c.center.lat + (km / 111.2) * Math.cos(a), lng: c.center.lng + (km / 109.0) * Math.sin(a) };
}

async function pool<T>(items: T[], size: number, f: (t: T) => Promise<void>): Promise<void> {
  let next = 0;
  await Promise.all(Array.from({ length: size }, async () => {
    while (next < items.length) await f(items[next++] as T);
  }));
}

const db = createDb(process.env.DATABASE_URL ?? 'postgres://nag:nag_local_only@localhost:5433/nag', 10);
const cmd = process.argv[2];

if (cmd === 'seed') {
  await seedDev(db);
  await sql`insert into users (id, display_name, role) select 'sim_c_' || lpad(g::text, 4, '0'), 'Khách ' || g, 'customer'
    from generate_series(0, ${sql.lit(CUSTOMERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into user_contacts (user_id, phone_e164) select 'sim_c_' || lpad(g::text, 4, '0'), '+8490' || lpad(g::text, 7, '0')
    from generate_series(0, ${sql.lit(CUSTOMERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into users (id, display_name, role) select 'sim_p_' || lpad(g::text, 4, '0'), 'Thợ ' || g, 'photographer'
    from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into photographers (user_id, onboarding_complete, verified, rating_avg, review_count)
    select 'sim_p_' || lpad(g::text, 4, '0'), true, g % 4 <> 0, 4.2 + (g % 8) / 10.0, g % 30
    from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into photographer_contact_numbers (photographer_id, phone_e164) select 'sim_p_' || lpad(g::text, 4, '0'), '+8491' || lpad(g::text, 7, '0')
    from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into dispatch.photographer_instant_settings (photographer_id, price_list_version_accepted, help_ready, updated_at)
    select 'sim_p_' || lpad(g::text, 4, '0'), 1, g % 5 = 0, now() from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  console.log(`seeded ${PHOTOGRAPHERS} photographers, ${CUSTOMERS} customers, 3 cities`);
} else if (cmd === 'online') {
  let ok = 0;
  await pool([...Array(PHOTOGRAPHERS).keys()], 50, async (i) => {
    const r = await call(pid(i), 'PUT', '/v1/presence', { online: true, fix: { ...spot(i), accuracyM: 30, at: new Date().toISOString() } });
    if (r.status === 200) ok++;
  });
  console.log(`online: ${ok}/${PHOTOGRAPHERS}`);
} else if (cmd === 'bots') {
  const minutes = Number(process.argv[3] ?? 11);
  const end = Date.now() + minutes * 60_000;
  const seen = new Set<string>();
  const rng = seededRng(2026);
  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
  let lastRefresh = Date.now();
  const trip = async (uid: string, requestId: string, meet: { lat: number; lng: number }, customer: string) => {
    await sleep(2_000);
    await call(uid, 'POST', `/v1/requests/${requestId}/location`, { ...meet, accuracyM: 10, at: new Date().toISOString() });
    await call(uid, 'POST', `/v1/requests/${requestId}/arrive`, { fix: { ...meet, accuracyM: 10, at: new Date().toISOString() } });
    await call(uid, 'POST', `/v1/requests/${requestId}/start`);
    await sleep(2_000);
    await call(uid, 'POST', `/v1/requests/${requestId}/finish`);
    await call(customer, 'POST', `/v1/requests/${requestId}/confirm-complete`);
  };
  while (Date.now() < end) {
    const pending = await db
      .selectFrom('dispatch.instant_offers as o')
      .innerJoin('dispatch.instant_requests as r', 'r.id', 'o.request_id')
      .select(['o.id', 'o.photographer_id', 'o.request_id', 'r.customer_id'])
      .where('o.outcome', '=', 'pending')
      .where('o.photographer_id', 'like', 'sim_p_%')
      .execute();
    for (const o of pending) {
      if (seen.has(o.id)) continue;
      seen.add(o.id);
      const roll = rng();
      const delay = 1_000 + rng() * 4_000;
      void (async () => {
        await sleep(delay);
        if (roll < 0.7) {
          const r = await call(o.photographer_id, 'POST', `/v1/offers/${o.id}/accept`);
          if (r.status === 200) {
            const meet = (r.json as { meetPoint: { lat: number; lng: number } }).meetPoint;
            await trip(o.photographer_id, o.request_id, meet, o.customer_id);
          }
        } else if (roll < 0.85) {
          await call(o.photographer_id, 'POST', `/v1/offers/${o.id}/decline`, { reason: 'busy' });
        }
      })();
    }
    if (Date.now() - lastRefresh > 4 * 60_000) {
      lastRefresh = Date.now();
      void pool([...Array(PHOTOGRAPHERS).keys()], 20, async (i) => {
        await call(pid(i), 'PUT', '/v1/presence', { online: true, fix: { ...spot(i), accuracyM: 30, at: new Date().toISOString() } });
      });
    }
    await sleep(300);
  }
  console.log(`bots: answered ${seen.size} offers`);
} else if (cmd === 'report') {
  const first = await sql<{ p50: number; p95: number; n: number }>`
    with starts as (
      select p.subject_id as request_id, min(l.at) as search_at from ledger_entries l join payments p on p.id = l.payment_id
      where l.type = 'deposit_received' and p.subject_type = 'instant_request' group by p.subject_id),
    firsts as (
      select o.request_id, min(o.offered_at) as first_at from dispatch.instant_offers o group by o.request_id)
    select percentile_cont(0.5) within group (order by extract(epoch from f.first_at - s.search_at) * 1000) as p50,
           percentile_cont(0.95) within group (order by extract(epoch from f.first_at - s.search_at) * 1000) as p95,
           count(*)::int as n
    from starts s join firsts f using (request_id)`.execute(db);
  const dup = await sql<{ n: number }>`
    select count(*)::int as n from dispatch.instant_offers a join dispatch.instant_offers b
      on a.photographer_id = b.photographer_id and a.id < b.id
     and a.offered_at < least(coalesce(b.decided_at, b.expires_at), b.expires_at)
     and b.offered_at < least(coalesce(a.decided_at, a.expires_at), a.expires_at)`.execute(db);
  const reoffer = await sql<{ n: number }>`
    select count(*)::int as n from (select request_id, photographer_id from dispatch.instant_offers group by 1, 2 having count(*) > 1) x`.execute(db);
  const statuses = await sql<{ status: string; n: number }>`select status, count(*)::int as n from dispatch.instant_requests group by status order by 2 desc`.execute(db);
  const metrics = (await (await fetch(`${API}/internal/metrics`)).json()) as Record<string, { p95: number; count: number }>;
  const f = first.rows[0] ?? { p50: Number.NaN, p95: Number.NaN, n: 0 };
  const checks: Array<[string, boolean, string]> = [
    ['first offer p95 < 2 s', Number(f.p95) < 2_000, `${Math.round(Number(f.p95))} ms over ${f.n} requests (p50 ${Math.round(Number(f.p50))} ms)`],
    ['matcher p95 < 50 ms', (metrics.matcher_ms?.p95 ?? Infinity) < 50, `${metrics.matcher_ms?.p95?.toFixed(1)} ms over ${metrics.matcher_ms?.count} runs`],
    ['no photographer holds two open offers', (dup.rows[0]?.n ?? 1) === 0, `${dup.rows[0]?.n} overlaps`],
    ['nobody offered the same request twice', (reoffer.rows[0]?.n ?? 1) === 0, `${reoffer.rows[0]?.n} pairs`],
  ];
  console.log('requests by status', Object.fromEntries(statuses.rows.map((r) => [r.status, r.n])));
  for (const [name, ok, detail] of checks) console.log(`${ok ? '✓' : '✗'} ${name}: ${detail}`);
  await db.destroy();
  process.exit(checks.every(([, ok]) => ok) ? 0 : 1);
} else {
  console.error('usage: simulate seed | online | bots [minutes] | report');
  process.exit(2);
}
await db.destroy();
```

```js
// services/dispatch/perf/k6-dispatch.js
// Customer load for services/dispatch (plan I3, Task 16; spec §11): 100 requests per minute for 10 minutes
// across 3 cities, each paid through the fake gateway. Run with `npm run simulate -- bots 11` alongside.
import http from 'k6/http';
import { check } from 'k6';
import exec from 'k6/execution';
import encoding from 'k6/encoding';

const BASE = __ENV.API_URL || 'http://dispatch:8090';
const PROJECT = __ENV.FIREBASE_PROJECT_ID || 'demo-nag';
const CITIES = [
  { id: 'hcm', lat: 10.7769, lng: 106.7009 },
  { id: 'hn', lat: 21.0278, lng: 105.8342 },
  { id: 'dn', lat: 16.0544, lng: 108.2022 },
];

function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const enc = (o) => encoding.b64encode(JSON.stringify(o), 'rawurl');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${PROJECT}`, aud: PROJECT, sub: uid, user_id: uid, iat: now, auth_time: now, exp: now + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

export const options = {
  scenarios: {
    customers: { executor: 'constant-arrival-rate', rate: 100, timeUnit: '1m', duration: '10m', preAllocatedVUs: 20, maxVUs: 60 },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{op:createRequest}': ['p(95)<300'],
    'http_req_duration{op:devPaymentSucceed}': ['p(95)<200'],
  },
};

export function setup() {
  const prices = {};
  for (const c of CITIES) {
    const r = http.get(`${BASE}/v1/packages?cityId=${c.id}`, { headers: { authorization: `Bearer ${token('sim_c_0000')}` } });
    if (r.status !== 200) throw new Error(`seed first: GET /v1/packages ${c.id} answered ${r.status}`);
    const p60 = r.json('packages').find((p) => p.code === 'p60');
    prices[c.id] = { packageId: p60.id, amount: p60.priceVnd };
  }
  return prices;
}

export default function (prices) {
  const i = exec.scenario.iterationInTest;
  const uid = `sim_c_${String(i).padStart(4, '0')}`;
  const city = CITIES[i % 3];
  const jitter = (n) => (Math.random() - 0.5) * n;
  const headers = { authorization: `Bearer ${token(uid)}`, 'content-type': 'application/json' };
  const body = {
    packageId: prices[city.id].packageId, genre: 'portrait',
    meetPoint: { lat: city.lat + jitter(0.08), lng: city.lng + jitter(0.08), address: 'Điểm hẹn thử tải' },
    expand: i % 4 === 0, expectedAmountVnd: prices[city.id].amount, provider: 'fake',
  };
  const created = http.post(`${BASE}/v1/requests`, JSON.stringify(body), { headers, tags: { op: 'createRequest' } });
  if (!check(created, { 'created 201': (r) => r.status === 201 })) return;
  const id = created.json('requestId');
  const paid = http.post(`${BASE}/v1/dev/payments/${id}/succeed`, null, { headers: { authorization: headers.authorization }, tags: { op: 'devPaymentSucceed' } });
  check(paid, { 'paid 204': (r) => r.status === 204 });
}
```

In `services/dispatch/package.json` add the script:

```json
    "simulate": "node --import tsx perf/simulate.ts"
```

In `services/api/docker-compose.yml` add the service:

```yaml
  k6-dispatch:
    image: grafana/k6:0.54.0
    profiles: [perf]
    command: ["run", "/perf/k6-dispatch.js"]
    environment:
      API_URL: http://dispatch:8090
      FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:-demo-nag}
    volumes:
      - ../dispatch/perf:/perf:ro
    depends_on:
      dispatch: { condition: service_healthy }
```

Append to `services/dispatch/README.md`:

````markdown
## Pin và mạng của ứng dụng

- Ứng dụng **không cần hỏi lại (polling)**: trạng thái, lời mời và vị trí đến qua listener Firestore (`instant_requests/{id}`, `instant_offers/{uid}`, `instant_tracks/{id}`); FCM chỉ đánh thức app.
- Vị trí khi đang đến: dịch vụ nhận tối đa 1 lần / 5 giây (429 `limit_exceeded`); ứng dụng gửi 10–15 giây một lần (spec §9). Khi sẵn sàng: gửi lại khi đi > 300 m hoặc 5 phút, trước `expiresAt` (TTL 10 phút).
- Goong Distance Matrix chỉ cho người đã nhận, tối đa 1 lần / phút / yêu cầu.
- Kiểm tra hiệu năng (plan I3 Task 16): `npm run simulate -- seed|online|bots|report` và k6 (`docker compose --profile perf run --rm k6-dispatch`).
````

- [ ] **Step 4: Run the load test (2,000 photographers, 3 cities, 100 requests/min for 10 min)**

```bash
cd services/api
LOG_LEVEL=warn docker compose up --build -d
cd ../dispatch
export DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag API_URL=http://localhost:8090
npm run simulate -- seed
npm run simulate -- online
curl -s -X POST localhost:8090/internal/metrics/reset
npm run simulate -- bots 11 &          # photographers answer offers while k6 runs
(cd ../api && docker compose --profile perf run --rm k6-dispatch); echo "k6 exit: $?"
wait
npm run simulate -- report; echo "report exit: $?"
cd ../api && docker compose down
```

Expected: `online: 2000/2000`; k6 prints `✓` for `http_req_failed`, `http_req_duration{op:createRequest}` and `{op:devPaymentSucceed}` and `k6 exit: 0`; `report` prints `requests by status { completed: …, no_match: …, … }` and four `✓` lines (`first offer p95 < 2 s`, `matcher p95 < 50 ms`, `no photographer holds two open offers`, `nobody offered the same request twice`) and `report exit: 0`. Run the whole sequence three times and record the medians in the PR. If a threshold fails twice, profile before changing it: `EXPLAIN ANALYZE` the matcher queries from Step 1, `redis-cli --latency` against port 6380, and `docker stats` for CPU throttling of `dispatch`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch services/api/docker-compose.yml
git commit -m "perf(dispatch): EXPLAIN, Redis and Firestore budgets, payload sizes, load harness and k6 scenario

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - §2.1 customer flow: packages and typical match time (Task 8), phone check and price lock, payment then `searching` only on a verified webhook (Task 10), S48 radius/round/end in the mirror (Tasks 10–11), S49 photographer card, ETA, grace window (Task 12), arrival and shoot (Task 13), no-match refund (Task 11), S55 cancel with `dryRun` (Task 14). §2.2 photographer flow: S52 settings and presence with readiness reasons (Task 9), S53 offer doc with neighbourhood area, payout, distance, travel time, 30 s, high-priority push (Task 11), accept/decline (Task 12), S54 tracking, ≤ 200 m arrival or forced with reason (Task 13), one open job (index + Task 12 test).
  - §3.1 all transitions through `transition()` (plan I2) in every write path; §3.2 rounds, radius, 30 s, total 10 min, one open offer per photographer (`offerlock`), never re-offer (`excluded` + unique index) (Tasks 11, 15).
  - §4 prices, payout, escrow, the cancellation table, ledger entries and the invariant (Tasks 10, 13, 14; `heldVnd` checks in tests).
  - §5 modules presence / matcher / offers / tracking / payments / api, Redis GEO + `SET NX PX` + BullMQ, PostgreSQL row locks, Firestore read-only mirror, Goong only for the accepted photographer (Tasks 5–14); deployment in compose with schema `dispatch` (Tasks 6–7).
  - §6 every operation of the contract (contract test with an empty `PENDING` after Task 14) plus the webhook GET added in Task 1.
  - §7 DDL verbatim after the Task 1 fixes, indexes, no presence in PostgreSQL, one track document deleted at the end, Firestore rules (Task 4).
  - §9 presence TTL, location rate limit, no history (Tasks 9, 13, 16). §10 edge cases: payment failure and timeout, late payment refunded, two accepts, expiry at the boundary, lost FCM (mirror), Goong failure (estimate), outside area, price change, too far, auto-complete, restart (Tasks 10–15).
  - §11 service tests (concurrency, timers, TTL, restart) and load test with the three thresholds (Tasks 15–16); rules tests (Task 4).
- **Placeholders:** none. Generated files (`src/generated/api.ts`, `package-lock.json`) come from the commands given; `jobHandlers` starts empty in Task 6 by design and gains its handlers in Tasks 10–15.
- **Type consistency:** `Deps`/`RouteDeps`, `RequestRow`, `SearchRecord`, `TripRecord`, `MirrorWriter` and the three `*Mirror` types, `PushMessage`, `EtaProvider`/`AreaResolver`, `Scheduler`/`JobHandlers`/`JobName`, the `PaymentGateway` family (`CreatePaymentInput`, `WebhookRequest`, `PaymentEvent`, `WebhookOutcome`, `WebhookAck`, `RefundInput`, `RefundResult`, `PaymentGateways`), `CancelResult`, `AcceptResult`, `MatchResult` are spelled the same in code, tests, the load harness and this plan's interface lists. Every task's file set was type-checked as a staged tree while writing the plan.
- **Contract changes (Task 1):** `limit_exceeded` in `ErrorCode`; 404 on seven operations; `arrive` 422 documented; webhook path-level parameter, provider-defined 200/204, new `GET` (`paymentWebhookQuery`) for VNPay IPN; `radiusKm` integer 1..50 instead of an enum; a sentence on 400/401. Schema: `photographers(user_id)` FKs, `cities_boundary` and `instant_requests_customer` indexes, provider `fake`; domain-model `PaymentSubject` + `instant_request`, `PaymentProvider` + `fake`.
- **Deviations (decided, recorded in the PR):**
  1. The money tables of §2.4 are created here (api migration history) when the payments plan has not run yet.
  2. Instant payments use the ledger type `deposit_received` for the capture (the payment row's `subject_type` tells them apart); no new ledger type.
  3. The lateness rule uses the offer's estimated ETA (plan I2 decision 10).
  4. `typicalMatchMinutes` measures `assigned_at − requested_at` (includes the seconds spent paying): §2.8 stores no search start in PostgreSQL.
  5. Device tokens are read from Firestore `devices/{uid}_{installId}` (written by plan I4's app) until the push plan's `devices` table; without tokens, offers still reach an open app through the mirror (§10). The FCM data keys (offer = every `InstantOfferMirror` field) follow plan I4 Task 6; they are not in the OpenAPI contract.
  6. Customer phone and photographer profile are read from the phase 2 PostgreSQL tables only.
  7. `photographers.completed_count` (S49 "completedShoots") is not incremented by instant jobs (its owner is `transition_booking`); the escrow release (`escrow_released`) and disputes are not implemented here.
  8. Decline reasons are logged, not stored (§2.8 has no column).
- **Deferred to later plans:** real MoMo/VNPay gateways and the escrow release job (I6); the dispute endpoint (`completed → disputed` exists in the state machine; no API yet); device token registration (push plan); production deployment (Cloud Run, Memorystore with AOF, secrets for the Goong key and Firebase credentials); surge time windows (open question 1); production cities and price list (open questions 1–2).
- **Risks to watch:**
  1. PostgreSQL row locks and the per-customer advisory lock under load: the load test watches `http_req_failed` and the matcher p95; deadlocks would show as 500s (lock order is always request row, then offer row).
  2. BullMQ job id rules (no `:`; `name-key-dueMs`) and `maxRetriesPerRequest: null` on its connection; the BullMQ test fails loudly otherwise.
  3. Ajv / fast-json-stringify on the rewritten `nullable` schemas: the contract and mirror-schema tests cover every schema the app reads.
  4. `postgis/postgis:16-3.4-alpine` on Apple silicon runs under emulation in some Docker setups (slower, still correct); the load numbers must come from an amd64 host or be marked as emulated.
  5. The auth copy can drift from phase 2: the drift test fails the build when it does.
  6. Firestore costs scale with track writes (one every 10–15 s per active trip): the budget test pins them; a higher rate needs a WebSocket channel instead (spec §5).
  7. The Docker-dependent suites were not run while writing this plan (no Docker daemon in the authoring sandbox); the first executor run of Tasks 6–16 is their first real run.
