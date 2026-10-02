# Backend Phase 2: Self-hosted API + PostgreSQL (first vertical slice) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A developer runs `docker compose up` in `services/api/` and gets PostgreSQL 16 with the slice schema plus a TypeScript API that serves the user profile, the private customer contact (`UserContact`), photographer contact channels / numbers / service area and the `get_contact_link` use case, authenticated with the same Firebase ID tokens the app already has. The Flutter app switches those four repositories from the Firebase adapters to HTTP adapters with `--dart-define=BACKEND=selfhosted --dart-define=BASE_URL=…`, and one contract test suite per port proves that the Fake, Firebase and HTTP adapters behave the same.

**Architecture:** `services/api/` is a Fastify 5 server. Its routes take method, URL and JSON schemas from one OpenAPI file (`services/api/api/openapi.yaml`) at boot, so the server cannot drift from the contract; TypeScript types are generated from the same file. Data access is Kysely over `pg` against tables created by SQL migrations copied from `relational-schema.md`. Business rules (`contact_unlocked`, contact URL shapes, the `ErrorCode` catalogue) are **imported** from phase 1's pure domain module, never re-implemented. Firebase Auth stays the identity provider: the API verifies Firebase ID tokens against Google's JWKS (or the Auth emulator's unsigned tokens in local dev). The app gains a thin `ApiClient` (`package:http`, one keep-alive client, gzip) and one HTTP adapter per port, selected per repository by a compile-time `BackendConfig`.

**Tech Stack:** Node 22, TypeScript 5, Fastify 5 + `@fastify/compress`, Kysely + `pg`, `node-pg-migrate` (plain SQL migrations), `jose`, `ulidx`, `yaml`, `openapi-typescript`, `esbuild`, Vitest + Testcontainers, k6 (Docker image), `firebase-admin` (import tool only), Docker Compose (PostgreSQL 16.4, Adminer 4.8.1). Flutter: `http` (new), `yaml` and `fake_cloud_firestore` (new, dev only).

**Spec:** `docs/superpowers/specs/data-model/README.md` (§2 conventions, §3 ports, §4 authorization matrix, §5 use cases, §6 migration steps, §7 acceptance criteria, §8 open questions 1, 2, 3, 5); `docs/superpowers/specs/data-model/domain-model.md` (§2.1 `User`, `UserContact`, `AuthIdentity`, `File`; §2.2 `Photographer`, `ContactChannels`, `ContactNumbers`; §2.7 `ContactAccessLog`; §4 `ErrorCode`, `ContactChannel`, `BookingStatus`; §5 "Mở khoá liên hệ"); `docs/superpowers/specs/data-model/relational-schema.md` (§1 DDL conventions, §2.1, §2.2, §2.4, §2.7 tables, §3 Firestore mapping, §5 export/import order); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b (contact and phone), §3g (escrow, out of scope here), §6 (order); `services/recommender/README.md` and `services/recommender/api/openapi.yaml` (contract style).

**Prerequisite (all must be done first):**

- `docs/superpowers/plans/2026-10-01-step2a-phone-and-customer-contact.md`: `UserContact`, `UserContactRepository { Stream<UserContact?> watch(String uid); Future<void> save(String uid, {required String phone, required bool allowZalo, required bool allowWhatsApp}); }`, `FirestoreUserContactRepository({FirebaseFirestore? db})`, `FakeUserContactRepository`, `userContactRepositoryProvider` in `lib/data/user/user_contact_providers.dart`.
- `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md`: `ContactChannel` (core), `ContactChannels`, `ContactNumbers`, `ServiceArea` (`lib/data/photographer/photographer_contact.dart`), `PhotographerContactRepository` + `FirestorePhotographerContactRepository({FirebaseFirestore? db})` + `FakePhotographerContactRepository`, `photographerContactRepositoryProvider`; `ContactSubject`, `ContactLinkError`, `ContactLinkException`, `ContactLinkRepository`, `callableData`, `contactUriFor`, `parseLinkResponse`, `linkErrorFromCode`, `FakeContactLinkRepository` (`lib/data/contact/contact_link_repository.dart`), `contactLinkRepositoryProvider` (`lib/data/contact/contact_providers.dart`).
- `docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md`: Cloud Functions in TypeScript with a **pure domain module** (no `firebase*` imports). Its pure package lives at `packages/domain` (barrel `packages/domain/src/index.ts`). Phase 1's final names are `ERROR_CODES`, `ErrorCode`, `DomainError`, `bookingContactUnlocked`, `ticketContactUnlocked`, `contactUrlFor`, `ExternalChannel`, `ContactNumbers`; this plan's shim (Task 3) maps `contactUnlocked` → `bookingContactUnlocked` and `contactUrl` → `contactUrlFor` with `as` aliases. **The executor must open phase 1's final layout before Task 3** and adjust only `services/api/src/domain/index.ts` (path or aliases); if a function is missing there, add it to phase 1's domain module with its unit test, never to `services/api`.

## Key decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Where | New top-level `services/api/`, sibling of `services/recommender/` | `services/` already holds independently deployable backends with their own contract; the API is not part of the Flutter package (`app_flutter/`) and must not be built by Gradle (root). The Docker build context is the repo root only so the bundle can include phase 1's domain module. |
| 2 | Language | TypeScript on Node 22 | data-model README §8 Q2 and `services/recommender/README.md` ("đề xuất TypeScript để dùng chung kiểu với Cloud Functions"); phase 1 writes the use cases in TypeScript, so phase 2 runs the **same** domain code (README §1.4 "Logic nghiệp vụ nằm ngoài nơi chạy"). CI already uses Node 22. |
| 3 | Framework | Fastify 5 (not NestJS) | Small surface, JSON-schema validation (Ajv) and response serialisation (fast-json-stringify) built in: a response schema without a `phone` property cannot leak one. Low per-request overhead for the p95 budget of Task 11. NestJS adds DI/decorators the slice does not need. |
| 4 | DB access | Kysely (typed query builder) over `pg`; hand-written table types, verified against the live schema by the migration test | Typed queries without an ORM model that would compete with `relational-schema.md` as the source of truth (README §1.2). `pg` parsers: `int8` → JS number with a safe-integer check (integer VND, README §2.3), `date` → `yyyy-MM-dd` string (README §2.2). |
| 5 | Migrations | `node-pg-migrate` with plain `.sql` files (`-- Up Migration` / `-- Down Migration`); DDL copied verbatim from `relational-schema.md` for the slice tables only; runnable from tests (programmatic `runner`) and from the container | Same SQL as the spec, real rollback, no second schema language. Later clusters add their own migrations (README §6 "mỗi bậc triển khai độc lập và quay lui được"). |
| 6 | Auth | Keep Firebase Auth as the IdP; the API verifies Firebase ID tokens with `jose` against `securetoken@system.gserviceaccount.com` JWKS (`AUTH_MODE=firebase`), or accepts the Auth emulator's unsigned tokens (`AUTH_MODE=firebase-emulator`, refused when `NODE_ENV=production`). No local JWT issuer. | README §6 changes `IdentityProvider` **last** (step 5) and §8 Q5 is still open; a local issuer would force a second login in the app now. A JWKS verifier is exactly the "OIDC/JWT; xác minh bằng JWKS" target of README §3, so step 5 is a config change (new JWKS URL/issuer). `auth_identities` rows are filled on every `POST /v1/me` so step 5 can map users without re-registration. |
| 7 | Contract | `services/api/api/openapi.yaml` (same layout and style as `services/recommender/api/openapi.yaml`, path version `/v1`); server routes are built **from** it; `openapi-typescript` generates `src/generated/api.ts` (drift-checked in CI) | One file defines the wire. |
| 8 | Dart client | Hand-written `ApiClient` + per-port mappers in `lib/data/http/wire.dart`, checked against `openapi.yaml` by a Dart drift test (Task 9) instead of `openapi-generator` | The slice has 11 operations; the `dart`/`dart-dio` generators add thousands of lines, `built_value`/`intl` constraints that fight the app's pins (`intl ^0.20.3` from `flutter_localizations`) and a JVM/Docker step in every client change. The drift test gives the same guarantee for what the app actually calls. |
| 9 | Error envelope | `{ "code": ErrorCode, "message": string, "requestId": string }` (flat, same shape as recommender `Error`), stable codes from `domain-model.md` §4 plus two transport-only codes `unauthenticated` (401) and `internal` (500) | README §2.8 "Mã lỗi `snake_case` ổn định"; adding codes is a compatible change (README §2.4). The client branches on `code`, never on `message` or status. |
| 10 | Ids, time, money | New ids are ULID (`ulidx`, README §8 Q3 recommendation); Firebase uids are kept as `users.id`; instants are `timestamptz` and ISO-8601 UTC on the wire; money columns are `bigint` read as JS numbers | README §2.1–2.3. |
| 11 | Realtime | No `RealtimeChannel` in this slice. HTTP `watch` = one GET per subscription + the adapter's own writes; **no polling** | Battery (Task 11). Changes made on another device appear the next time a screen subscribes; WebSocket/SSE is its own later plan (README §3 `RealtimeChannel`). |
| 12 | Avatar | Social avatar URLs become a `files` row with `storage_provider = 'external'`, `storage_key = <url>`; the API resolves it back to `avatarUrl` | Keeps README §2.6 ("chỉ lưu khoá lưu trữ … URL dựng lúc chạy") without a storage service yet; the Storage plan replaces `external` with real keys. |

## Later plans (not in this slice)

In the order of data-model README §6 step 4 ("nội dung → hồ sơ → booking → sự kiện → chat"), adjusted because this slice already covers the identity/profile/contact part that plans 2a/2b define on the client:

| # | Plan | Content |
|---|---|---|
| 1 | Content | `posts`, `post_images`, `post_hashtags`, `likes`, `saves`, `follows` + feed queries (client ports from plan 3b1) |
| 2 | Profile, rest | `services` writes, `photographer_specialties`/`skill_tags`, `taxonomy_items` seed, `availability_days`, `complete_photographer_profile` |
| 3 | Bookings | `bookings` writes through `create_booking_deposit` / `transition_booking` with `version`, `booking_events`, `booking_contacts`, server-side `phone_required` (spec §3b.2) |
| 4 | Payments and escrow | `payments`, `refunds`, `ledger_entries`, `payout_accounts`, `payouts`, MoMo/VNPay `PaymentGateway`, `release_escrow` (spec §3g) |
| 5 | Events | `events`, `event_registrations`, `event_posts`; `get_contact_link` for `registrationId` |
| 6 | Chat and realtime | `chats`, `chat_members`, `messages`, `send_message_guard`, `RealtimeChannel` (WebSocket/SSE + `LISTEN/NOTIFY`) |
| 7 | Storage | `FileStorage` + `MediaUrlResolver` (S3/MinIO), migrate `external` avatars and Firebase Storage URLs to keys |
| 8 | Recommender, push, scheduler | `services/recommender` behind the API, `PushGateway`, `Scheduler` |
| 9 | Migration steps 3 and 5 | Firestore → PostgreSQL replication for parallel run; `IdentityProvider` switch using `auth_identities` |

## Global Constraints

- Server commands run from `services/api/` with Node ≥ 22.11 and a running Docker daemon (Testcontainers starts `postgres:16.4-alpine` for the tests). Flutter commands run from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`; run `dart format lib test` before each Flutter commit.
- Wire format (README §2): JSON keys `camelCase`; instants ISO-8601 UTC (`…Z`); money integer VND + `currency`; enums are the string codes of `domain-model.md` §4; ids match `^[A-Za-z0-9_-]{1,64}$`; errors use the Error envelope with a stable `code`.
- **Phone numbers never appear in a public response, a log line, an error message or `contact_access_log`.** Only `GET/PUT /v1/users/{id}/contact` (owner), `GET /v1/photographers/{id}/contact-numbers` (owner) and `PUT …/contact-setup` (owner) carry numbers; `POST /v1/contact-links` returns one URL. Private responses carry `Cache-Control: no-store`.
- Authorization is the matrix of data-model README §4, enforced in the route handlers and covered by table-driven tests per row of the slice.
- Clients never write server-owned fields: `phoneVerified`, `verified`, `staffRole`, counters, `onboardingComplete` outside `completeContactSetup`. Request schemas use `additionalProperties: false` and Ajv runs with `removeAdditional: false`, so an extra field is a 400, not silently dropped.
- Domain rules are imported only through `services/api/src/domain/index.ts`. `firebase-admin` appears only in `services/api/tools/firestore-import/`. The server verifies tokens with `jose`, not with a Firebase SDK.
- Flutter: `package:photobooking/...` imports only; `cloud_firestore`/`firebase_*` and `package:http` only in `lib/data/**`, `lib/firebase_options.dart`, `lib/main.dart`. Domain/features keep depending on the repository interfaces of plans 2a/2b, unchanged.
- `.env.example` holds test values only; real secrets never enter the repo (`services/api/.gitignore` ignores `.env`).
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `services/api/package.json`, `package-lock.json`, `tsconfig.json`, `vitest.config.ts`, `.gitignore`, `.env.example`, `README.md` (create) | Node project, scripts, test config, local env template |
| `services/api/Dockerfile`, `Dockerfile.dockerignore`, `docker-compose.yml`, `docker/initdb/01-test-db.sql` (create) | Image (context = repo root), `db` + `migrate` + `api` + `adminer` (profile `tools`) + `k6` (profile `perf`) |
| `services/api/api/openapi.yaml` (create) | The contract |
| `services/api/migrations/*.sql` (create) | Slice DDL from `relational-schema.md` |
| `services/api/src/config.ts`, `server.ts`, `app.ts`, `deps.ts`, `fastify-augment.ts` (create) | Config, process entry, app factory, shared route deps, Fastify type augmentation |
| `services/api/src/db/database.ts`, `migrate.ts`, `migrate-cli.ts` (create) | Kysely types and pool, migration runner |
| `services/api/src/domain/index.ts` (create) | The only import point of phase 1's domain module |
| `services/api/src/errors.ts`, `ids.ts`, `wire.ts` (create) | Error envelope and HTTP mapping, ULID, ISO helper |
| `services/api/src/contract/openapi.ts`, `src/generated/api.ts` (create; second is generated) | Load contract, register schemas, build route options |
| `services/api/src/auth/identity.ts`, `auth/plugin.ts` (create) | Token verifiers, `Principal`, auth hook, owner check |
| `services/api/src/repos/users.ts`, `repos/photographers.ts`, `repos/contact-links.ts` (create) | Typed queries |
| `services/api/src/use-cases/get-contact-link.ts` (create) | Pure decision of `get_contact_link` |
| `services/api/src/routes/health.ts`, `me.ts`, `users.ts`, `photographers.ts`, `contact-links.ts` (create) | HTTP handlers |
| `services/api/src/tools/contract-world.ts`, `tools/seed-contract.ts`, `test/fixtures/contract-world.json` (create) | Shared fixture world for server tests, Flutter contract tests and k6 |
| `services/api/tools/firestore-import/*.ts` (create) | Firestore → NDJSON → PostgreSQL for the slice |
| `services/api/perf/k6-slice.js` (create) | Latency budget run |
| `services/api/test/*.test.ts`, `test/global-setup.ts`, `test/helpers.ts` (create) | Server tests |
| `.github/workflows/api.yml` (create) | CI for the API |
| `docs/superpowers/specs/data-model/domain-model.md` (modify) | Transport-only error codes |
| `app_flutter/pubspec.yaml`, `pubspec.lock`, `dart_test.yaml` (modify/create) | `http`; dev `yaml`, `fake_cloud_firestore`; `selfhosted` tag |
| `app_flutter/lib/data/backend_config.dart` (create) | `BACKEND`, `BASE_URL`, `SELFHOSTED_REPOS` |
| `app_flutter/lib/data/auth/id_token_source.dart` (create) | `IdTokenSource` port + Firebase and static implementations |
| `app_flutter/lib/data/http/api_client.dart`, `local_watch.dart`, `wire.dart`, `api_providers.dart` (create) | HTTP plumbing and wire mappers |
| `app_flutter/lib/data/user/http_user_repository.dart`, `http_user_contact_repository.dart`, `lib/data/photographer/http_photographer_contact_repository.dart`, `lib/data/contact/http_contact_link_repository.dart` (create) | HTTP adapters |
| `app_flutter/lib/data/auth/auth_providers.dart`, `lib/data/user/user_contact_providers.dart`, `lib/data/photographer/photographer_contact_providers.dart`, `lib/data/contact/contact_providers.dart` (modify) | Adapter selection |
| `app_flutter/android/app/src/debug/AndroidManifest.xml` (modify) | Cleartext HTTP to the local API in debug builds only |
| `app_flutter/test/data/http/*`, `test/data/contracts/*` (create) | Client unit, drift and contract tests |

---

### Task 1: Scaffold `services/api`, health endpoint, Compose and CI

**Files:**
- Create: `services/api/package.json`, `services/api/tsconfig.json`, `services/api/vitest.config.ts`, `services/api/.gitignore`, `services/api/.env.example`, `services/api/README.md`, `services/api/Dockerfile`, `services/api/Dockerfile.dockerignore`, `services/api/docker-compose.yml`, `services/api/docker/initdb/01-test-db.sql`, `services/api/src/config.ts`, `services/api/src/fastify-augment.ts`, `services/api/src/db/database.ts`, `services/api/src/routes/health.ts`, `services/api/src/app.ts`, `services/api/src/server.ts`, `services/api/test/global-setup.ts`, `services/api/test/helpers.ts`, `services/api/test/config.test.ts`, `services/api/test/health.test.ts`, `.github/workflows/api.yml`

**Interfaces:**
- Produces:
  - `type AuthMode = 'firebase' | 'firebase-emulator'`; `interface Config { port: number; host: string; databaseUrl: string; dbPoolMax: number; authMode: AuthMode; firebaseProjectId: string; logLevel: string; nodeEnv: string }`; `loadConfig(env?: NodeJS.ProcessEnv): Config` (throws on missing/invalid values and on `firebase-emulator` with `NODE_ENV=production`).
  - `createDb(databaseUrl: string, max: number): Kysely<Database>`; `interface Database` (empty until Task 2).
  - `interface AppDeps { db: Kysely<Database>; logLevel?: string }`; `buildApp(deps: AppDeps): Promise<FastifyInstance>`.
  - `GET /v1/health` → `200 {"status":"ok","db":"ok"}` or `503 {"status":"degraded","db":"down"}`; public.
  - Test helpers: `testDatabaseUrl(): string`, `testDb(): Kysely<Database>`, `testApp(deps): Promise<FastifyInstance>`.

- [ ] **Step 1: Create the project files**

```json
// services/api/package.json
{
  "name": "@nag/api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22.11.0" },
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "esbuild src/server.ts --bundle --platform=node --target=node22 --format=esm --packages=external --sourcemap --outdir=dist",
    "start": "node dist/server.js",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "@fastify/compress": "^8.0.1",
    "fastify": "^5.1.0",
    "jose": "^5.9.6",
    "kysely": "^0.27.5",
    "node-pg-migrate": "^7.8.0",
    "pg": "^8.13.1",
    "ulidx": "^2.4.1",
    "yaml": "^2.6.1"
  },
  "devDependencies": {
    "@testcontainers/postgresql": "^10.16.0",
    "@types/node": "^22.10.1",
    "@types/pg": "^8.11.10",
    "esbuild": "^0.24.0",
    "openapi-typescript": "^7.4.4",
    "tsx": "^4.19.2",
    "typescript": "^5.7.2",
    "vitest": "^2.1.8"
  }
}
```

(JSON has no comments: the first line above only names the file; do not write it into the file.)

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2023"],
    "types": ["node"],
    "strict": true,
    "noEmit": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src", "test", "tools", "vitest.config.ts"]
}
```

Save the block above as `services/api/tsconfig.json`.

```ts
// services/api/vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globalSetup: ['./test/global-setup.ts'],
    include: ['test/**/*.test.ts', 'tools/**/*.test.ts'],
    // Test files share one database and truncate it: run them one at a time.
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 180_000,
  },
});
```

```gitignore
# services/api/.gitignore
node_modules/
dist/
coverage/
.env
export/
```

```bash
# services/api/.env.example
# Copy to services/api/.env (gitignored). Test values only: never put real secrets here.
# docker compose reads this file for ${VAR} interpolation; every value has a default
# in docker-compose.yml, so `docker compose up` also works without a .env file.

POSTGRES_USER=nag
POSTGRES_PASSWORD=nag_local_only
POSTGRES_DB=nag
POSTGRES_PORT=5433

API_PORT=8787
DB_POOL_MAX=10
LOG_LEVEL=info
NODE_ENV=development

# firebase-emulator: accepts the Auth emulator's unsigned ID tokens (and the ones the
#   contract tests and k6 craft). Refused when NODE_ENV=production.
# firebase: verifies real Firebase ID tokens against Google's JWKS. Use this when the
#   app runs against the real Firebase project; set FIREBASE_PROJECT_ID to the
#   projectId in app_flutter/lib/firebase_options.dart.
AUTH_MODE=firebase-emulator
FIREBASE_PROJECT_ID=demo-nag

# Host-side tools (npm run migrate / seed:contract / import:firestore):
DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag
# Tests: leave unset to let Testcontainers start a throwaway database, or point at
# the compose database created by docker/initdb (name must end in _test):
# TEST_DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag_test
```

```sql
-- services/api/docker/initdb/01-test-db.sql
-- Runs once, when the db volume is created. Tests may use it via TEST_DATABASE_URL.
create database nag_test;
```

```ts
// services/api/src/config.ts
export type AuthMode = 'firebase' | 'firebase-emulator';

export interface Config {
  port: number;
  host: string;
  databaseUrl: string;
  dbPoolMax: number;
  authMode: AuthMode;
  firebaseProjectId: string;
  logLevel: string;
  nodeEnv: string;
}

function required(env: NodeJS.ProcessEnv, key: string): string {
  const v = env[key];
  if (v === undefined || v.trim() === '') throw new Error(`${key} is required`);
  return v.trim();
}

function int(env: NodeJS.ProcessEnv, key: string, fallback: number, min: number, max: number): number {
  const raw = env[key];
  const n = raw === undefined || raw === '' ? fallback : Number(raw);
  if (!Number.isInteger(n) || n < min || n > max) {
    throw new Error(`${key} must be an integer between ${min} and ${max}`);
  }
  return n;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const nodeEnv = env.NODE_ENV ?? 'production';
  const authMode = env.AUTH_MODE ?? 'firebase';
  if (authMode !== 'firebase' && authMode !== 'firebase-emulator') {
    throw new Error('AUTH_MODE must be firebase or firebase-emulator');
  }
  if (authMode === 'firebase-emulator' && nodeEnv === 'production') {
    throw new Error('AUTH_MODE=firebase-emulator accepts unsigned tokens and is refused when NODE_ENV=production');
  }
  return {
    port: int(env, 'PORT', 8787, 1, 65_535),
    host: env.HOST ?? '0.0.0.0',
    databaseUrl: required(env, 'DATABASE_URL'),
    dbPoolMax: int(env, 'DB_POOL_MAX', 10, 1, 50),
    authMode,
    firebaseProjectId: required(env, 'FIREBASE_PROJECT_ID'),
    logLevel: env.LOG_LEVEL ?? 'info',
    nodeEnv,
  };
}
```

```ts
// services/api/src/fastify-augment.ts
export {};

declare module 'fastify' {
  interface FastifyContextConfig {
    /** Route needs no bearer token (only /v1/health). */
    public?: boolean;
  }
}
```

```ts
// services/api/src/db/database.ts
import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';

// int8 (bigint money, count(*)) → number; refuse values a JS number cannot hold exactly.
pg.types.setTypeParser(20, (v: string) => {
  const n = Number(v);
  if (!Number.isSafeInteger(n)) throw new RangeError(`int8 value ${v} exceeds Number.MAX_SAFE_INTEGER`);
  return n;
});
// date stays 'yyyy-MM-dd': a calendar day in Asia/Ho_Chi_Minh, not an instant.
pg.types.setTypeParser(1082, (v: string) => v);

// Tables arrive with the migrations (Task 2).
// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface Database {}

export function createDb(databaseUrl: string, max: number): Kysely<Database> {
  return new Kysely<Database>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({
        connectionString: databaseUrl,
        max,
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 2_000,
      }),
    }),
  });
}
```

```ts
// services/api/src/routes/health.ts
import type { FastifyInstance } from 'fastify';
import { sql, type Kysely } from 'kysely';

import type { Database } from '../db/database.js';

export function registerHealthRoutes(app: FastifyInstance, deps: { db: Kysely<Database> }): void {
  app.get('/v1/health', { config: { public: true } }, async (_req, reply) => {
    try {
      await sql`select 1`.execute(deps.db);
      return { status: 'ok', db: 'ok' };
    } catch {
      return reply.status(503).send({ status: 'degraded', db: 'down' });
    }
  });
}
```

```ts
// services/api/src/app.ts
import Fastify, { type FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';

import type { Database } from './db/database.js';
import { registerHealthRoutes } from './routes/health.js';

export interface AppDeps {
  db: Kysely<Database>;
  /** Pino level; omit to disable logging (tests). */
  logLevel?: string;
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    logger: deps.logLevel ? { level: deps.logLevel, redact: ['req.headers.authorization'] } : false,
    keepAliveTimeout: 65_000,
    bodyLimit: 16 * 1024,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } },
  });
  registerHealthRoutes(app, deps);
  return app;
}
```

```ts
// services/api/src/server.ts
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDb } from './db/database.js';

const config = loadConfig();
const db = createDb(config.databaseUrl, config.dbPoolMax);
const app = await buildApp({ db, logLevel: config.logLevel });

async function shutdown(): Promise<void> {
  await app.close();
  await db.destroy();
}
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    void shutdown().then(() => process.exit(0));
  });
}

await app.listen({ port: config.port, host: config.host });
```

```ts
// services/api/test/global-setup.ts
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

let container: StartedPostgreSqlContainer | undefined;

export async function setup(): Promise<void> {
  const given = process.env.TEST_DATABASE_URL;
  if (given) {
    if (!new URL(given).pathname.endsWith('_test')) {
      throw new Error('TEST_DATABASE_URL must name a database ending in _test (tests truncate tables)');
    }
    return;
  }
  container = await new PostgreSqlContainer('postgres:16.4-alpine')
    .withDatabase('nag_test')
    .withUsername('nag')
    .withPassword('nag_test_only')
    .start();
  process.env.TEST_DATABASE_URL = container.getConnectionUri();
}

export async function teardown(): Promise<void> {
  await container?.stop();
}
```

```ts
// services/api/test/helpers.ts
import type { FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';

import { buildApp, type AppDeps } from '../src/app.js';
import { createDb, type Database } from '../src/db/database.js';

export function testDatabaseUrl(): string {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is set by test/global-setup.ts');
  return url;
}

export function testDb(): Kysely<Database> {
  return createDb(testDatabaseUrl(), 4);
}

export function testApp(deps: AppDeps): Promise<FastifyInstance> {
  return buildApp(deps);
}
```

```dockerfile
# services/api/Dockerfile
# syntax=docker/dockerfile:1.7
# Build context is the repository root (see docker-compose.yml).
FROM node:22.11.0-alpine3.20 AS build
WORKDIR /repo/services/api
COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci
COPY services/api/ ./
RUN npm run build

FROM node:22.11.0-alpine3.20
WORKDIR /app
ENV NODE_ENV=production
COPY services/api/package.json services/api/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /repo/services/api/dist ./dist
USER node
EXPOSE 8787
CMD ["node", "dist/server.js"]
```

```gitignore
# services/api/Dockerfile.dockerignore  (BuildKit reads <Dockerfile>.dockerignore next to the Dockerfile)
*
!services/api/package.json
!services/api/package-lock.json
!services/api/tsconfig.json
!services/api/src/**
!services/api/api/**
!services/api/migrations/**
!services/api/test/fixtures/**
!packages/domain/**
```

```yaml
# services/api/docker-compose.yml
name: nag-api

x-api-build: &api-build
  context: ../..
  dockerfile: services/api/Dockerfile

x-api-env: &api-env
  DATABASE_URL: postgres://${POSTGRES_USER:-nag}:${POSTGRES_PASSWORD:-nag_local_only}@db:5432/${POSTGRES_DB:-nag}
  NODE_ENV: ${NODE_ENV:-development}
  PORT: "8787"
  HOST: 0.0.0.0
  DB_POOL_MAX: ${DB_POOL_MAX:-10}
  AUTH_MODE: ${AUTH_MODE:-firebase-emulator}
  FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:-demo-nag}
  LOG_LEVEL: ${LOG_LEVEL:-info}

services:
  db:
    image: postgres:16.4-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-nag}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-nag_local_only}
      POSTGRES_DB: ${POSTGRES_DB:-nag}
      TZ: UTC
    ports: ["${POSTGRES_PORT:-5433}:5432"]
    volumes:
      - db-data:/var/lib/postgresql/data
      - ./docker/initdb:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 2s
      timeout: 3s
      retries: 30

  api:
    build: *api-build
    image: nag-api:local
    environment: *api-env
    ports: ["${API_PORT:-8787}:8787"]
    depends_on:
      db: { condition: service_healthy }
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:8787/v1/health || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 12

  adminer:
    image: adminer:4.8.1
    profiles: [tools]
    environment:
      ADMINER_DEFAULT_SERVER: db
    ports: ["${ADMINER_PORT:-8081}:8080"]
    depends_on:
      db: { condition: service_healthy }

volumes:
  db-data:
```

````markdown
<!-- services/api/README.md -->
# api (self-hosted backend, phase 2)

First vertical slice of the self-hosted backend described in
`docs/superpowers/specs/data-model/`. Plan: `docs/superpowers/plans/2026-10-01-backend-phase2-selfhosted-postgres.md`.
Contract: [`api/openapi.yaml`](api/openapi.yaml).

```bash
cd services/api
cp .env.example .env               # optional, defaults work
docker compose up --build -d       # db + migrate + api on :8787
curl -s localhost:8787/v1/health   # {"status":"ok","db":"ok"}
docker compose --profile tools up -d adminer   # http://localhost:8081 (server db, user nag)
docker compose down                # keep data; add -v to drop the volume

npm ci && npm test                 # needs Docker (Testcontainers)
```

Run the app against it: `flutter run --dart-define=BACKEND=selfhosted --dart-define=BASE_URL=http://10.0.2.2:8787`
(Android emulator; iOS simulator: `http://localhost:8787`). The app signs in with the real Firebase
project, so start the API with `AUTH_MODE=firebase` and that project's `FIREBASE_PROJECT_ID`.
````

```yaml
# .github/workflows/api.yml
name: api
on:
  push:
    branches: [flutter-rewrite, develop, main]
  pull_request:
    paths:
      - 'services/api/**'
      - 'packages/domain/**'
      - '.github/workflows/api.yml'
jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/api
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
          cache-dependency-path: services/api/package-lock.json
      - run: npm ci
      - run: npm run typecheck
      - run: npm run build
      - run: npm test
```

Then install to create the lock file:

```bash
cd services/api && npm install
```

Expected: `added N packages`, `package-lock.json` created, no `ERR!` lines.

- [ ] **Step 2: Write the failing tests**

```ts
// services/api/test/config.test.ts
import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';

const base = { DATABASE_URL: 'postgres://x@localhost/x', FIREBASE_PROJECT_ID: 'demo-nag' };

describe('loadConfig', () => {
  it('has safe defaults: firebase auth, pool of 10, port 8787', () => {
    const c = loadConfig({ ...base });
    expect(c).toMatchObject({ authMode: 'firebase', dbPoolMax: 10, port: 8787, nodeEnv: 'production' });
  });

  it('refuses emulator tokens in production', () => {
    expect(() => loadConfig({ ...base, AUTH_MODE: 'firebase-emulator', NODE_ENV: 'production' })).toThrow(/refused/);
    expect(loadConfig({ ...base, AUTH_MODE: 'firebase-emulator', NODE_ENV: 'development' }).authMode).toBe('firebase-emulator');
  });

  it('rejects missing and out-of-range values', () => {
    expect(() => loadConfig({ FIREBASE_PROJECT_ID: 'p' })).toThrow(/DATABASE_URL/);
    expect(() => loadConfig({ ...base, DB_POOL_MAX: '0' })).toThrow(/DB_POOL_MAX/);
    expect(() => loadConfig({ ...base, AUTH_MODE: 'jwt' })).toThrow(/AUTH_MODE/);
  });
});
```

```ts
// services/api/test/health.test.ts
import { afterAll, describe, expect, it } from 'vitest';

import { createDb } from '../src/db/database.js';
import { testApp, testDb } from './helpers.js';

const db = testDb();
afterAll(() => db.destroy());

describe('GET /v1/health', () => {
  it('is public and reports the database', async () => {
    const app = await testApp({ db });
    const res = await app.inject({ method: 'GET', url: '/v1/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: 'ok', db: 'ok' });
    await app.close();
  });

  it('answers 503 when the database is unreachable', async () => {
    const down = createDb('postgres://nag:x@127.0.0.1:1/none_test', 1);
    const app = await testApp({ db: down });
    const res = await app.inject({ method: 'GET', url: '/v1/health' });
    expect(res.statusCode).toBe(503);
    expect(res.json()).toEqual({ status: 'degraded', db: 'down' });
    await app.close();
    await down.destroy();
  });
});
```

- [ ] **Step 3: Run the tests and the build**

Run: `npm run typecheck && npm test && npm run build`
Expected: typecheck clean; `Test Files  2 passed (2)`, `Tests  5 passed (5)`; `dist/server.js` written. (These files were written together with the code in Step 1 because a scaffold has nothing to fail against; if any test fails, fix the code, not the test.)

- [ ] **Step 4: Bring the stack up**

```bash
docker compose up --build -d
curl -s localhost:8787/v1/health
docker compose down
```

Expected: `{"status":"ok","db":"ok"}`.

- [ ] **Step 5: Commit**

```bash
git add services/api .github/workflows/api.yml
git commit -m "feat(api): scaffold self-hosted API with health endpoint, compose stack and CI

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Slice migrations from `relational-schema.md`

**Files:**
- Create: `services/api/migrations/1790812800001_accounts.sql`, `services/api/migrations/1790812800002_photographers.sql`, `services/api/migrations/1790812800003_bookings_contact_log.sql`, `services/api/src/db/migrate.ts`, `services/api/src/db/migrate-cli.ts`, `services/api/test/migrations.test.ts`
- Modify: `services/api/src/db/database.ts` (full table types), `services/api/test/global-setup.ts`, `services/api/test/helpers.ts`, `services/api/package.json`, `services/api/Dockerfile`, `services/api/docker-compose.yml`

**Interfaces:**
- Consumes: `createDb`, `testDatabaseUrl`, `testDb` (Task 1).
- Produces:
  - Tables `files`, `users`, `user_contacts`, `auth_identities`, `taxonomy_items`, `photographers`, `photographer_contact_channels`, `photographer_contact_numbers`, `services`, `bookings`, `booking_events`, `contact_access_log`, with every column, check, unique, index and FK of `relational-schema.md` for these tables (`bookings.chat_id` has no FK yet: the chat plan adds `fk_bookings_chat`), plus `set_updated_at()` triggers on every table with `updated_at`.
  - `migrate(databaseUrl: string, direction: 'up' | 'down', opts?: { count?: number; dir?: string; log?: (msg: string) => void }): Promise<unknown>`; CLI `node dist/db/migrate-cli.js up|down [n|all]`.
  - `Database` with `FilesTable`, `UsersTable`, `UserContactsTable`, `AuthIdentitiesTable`, `TaxonomyItemsTable`, `PhotographersTable`, `PhotographerContactChannelsTable`, `PhotographerContactNumbersTable`, `ServicesTable`, `BookingsTable`, `BookingEventsTable`, `ContactAccessLogTable`; exported unions `UserRole`, `StaffRole`, `AuthProvider`, `BookingStatus`, `ContactChannelCode`.
  - Test helper `resetDb(db: Kysely<Database>): Promise<void>` (truncates every slice table).

- [ ] **Step 1: Write the failing test**

```ts
// services/api/test/migrations.test.ts
import pg from 'pg';
import { sql } from 'kysely';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { BookingStatus } from '../src/db/database.js';
import { migrate } from '../src/db/migrate.js';
import { resetDb, testDatabaseUrl, testDb } from './helpers.js';

/** relational-schema.md §2, slice tables, columns in DDL order. */
const EXPECTED: Record<string, string[]> = {
  auth_identities: ['id', 'user_id', 'provider', 'subject', 'email', 'created_at'],
  booking_events: ['id', 'booking_id', 'status', 'actor_id', 'at'],
  bookings: [
    'id', 'customer_id', 'photographer_id', 'service_id', 'service_name', 'service_price',
    'service_duration_minutes', 'day', 'start_time', 'end_time', 'place_name', 'place_lat', 'place_lng',
    'note', 'status', 'deposit_amount', 'remaining_amount', 'currency', 'deposit_provider',
    'deposit_paid_at', 'deposit_refunded_at', 'accept_deadline', 'cancelled_by', 'cancel_reason',
    'cancelled_at', 'cancel_refund_percent', 'chat_id', 'version', 'created_at', 'updated_at',
  ],
  contact_access_log: ['id', 'requester_id', 'subject_type', 'subject_id', 'channel', 'granted', 'at'],
  files: [
    'id', 'owner_user_id', 'storage_provider', 'storage_key', 'mime_type', 'size_bytes', 'width', 'height',
    'blurhash', 'created_at',
  ],
  photographer_contact_channels: ['photographer_id', 'call_enabled', 'zalo_enabled', 'whatsapp_enabled'],
  photographer_contact_numbers: ['photographer_id', 'phone_e164', 'zalo_phone_e164', 'whatsapp_phone_e164'],
  photographers: [
    'user_id', 'bio', 'years_experience', 'service_city', 'service_lat', 'service_lng', 'service_radius_km',
    'cover_file_id', 'verified', 'verified_at', 'onboarding_complete', 'accepts_inquiries', 'rating_avg',
    'review_count', 'completed_count', 'response_minutes_median', 'starting_price', 'next_free_date',
    'skills_completeness', 'created_at', 'updated_at',
  ],
  services: [
    'id', 'photographer_id', 'name', 'specialty_id', 'duration_minutes', 'price', 'currency', 'photo_count',
    'edited_count', 'delivery_days', 'cover_file_id', 'active', 'created_at', 'updated_at',
  ],
  taxonomy_items: ['id', 'grp', 'label_vi', 'parent_id', 'sort_order', 'active'],
  user_contacts: ['user_id', 'phone_e164', 'phone_verified', 'allow_zalo', 'allow_whatsapp', 'updated_at'],
  users: [
    'id', 'display_name', 'avatar_file_id', 'role', 'staff_role', 'city', 'locale', 'created_at', 'updated_at',
    'deleted_at',
  ],
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

async function columns(url: string): Promise<Record<string, string[]>> {
  return withClient(url, async (c) => {
    const r = await c.query<{ table_name: string; column_name: string }>(
      `select table_name, column_name from information_schema.columns
        where table_schema = 'public' and table_name <> 'pgmigrations'
        order by table_name, ordinal_position`,
    );
    const out: Record<string, string[]> = {};
    for (const row of r.rows) (out[row.table_name] ??= []).push(row.column_name);
    return out;
  });
}

describe('migrations', () => {
  const name = `mig_${Date.now()}_test`;
  const scratch = (() => {
    const u = new URL(testDatabaseUrl());
    u.pathname = `/${name}`;
    return u.toString();
  })();

  beforeAll(() => withClient(testDatabaseUrl(), (c) => c.query(`create database ${name}`)));
  afterAll(() => withClient(testDatabaseUrl(), (c) => c.query(`drop database if exists ${name} with (force)`)));

  it('apply all: the slice tables match relational-schema.md column for column', async () => {
    await migrate(scratch, 'up');
    expect(await columns(scratch)).toEqual(EXPECTED);
  });

  it('indexes of relational-schema.md exist', async () => {
    const names = await withClient(scratch, async (c) =>
      (await c.query<{ indexname: string }>(`select indexname from pg_indexes where schemaname = 'public'`)).rows.map(
        (r) => r.indexname,
      ),
    );
    expect(names).toEqual(
      expect.arrayContaining([
        'ix_taxonomy_items_grp',
        'ix_services_photographer',
        'ix_bookings_customer',
        'ix_bookings_photographer',
        'ux_bookings_active_day',
        'ix_booking_events_booking',
      ]),
    );
  });

  it('rolls back completely, then applies again', async () => {
    await migrate(scratch, 'down', { count: Infinity });
    expect(await columns(scratch)).toEqual({});
    const fn = await withClient(scratch, (c) =>
      c.query<{ n: number }>(`select count(*)::int as n from pg_proc where proname = 'set_updated_at'`),
    );
    expect(fn.rows[0]?.n).toBe(0);
    await migrate(scratch, 'up');
    expect(Object.keys(await columns(scratch)).sort()).toEqual(Object.keys(EXPECTED).sort());
  });
});

describe('constraints from relational-schema.md', () => {
  const db = testDb();
  afterAll(() => db.destroy());
  beforeEach(() => resetDb(db));

  async function graph(): Promise<void> {
    await db.insertInto('users').values([
      { id: 'c1', display_name: 'Khách', role: 'customer' },
      { id: 'p1', display_name: 'Thợ', role: 'photographer' },
    ]).execute();
    await db.insertInto('photographers').values({ user_id: 'p1' }).execute();
    await db.insertInto('services').values({ id: 's1', photographer_id: 'p1', name: 'Gói', duration_minutes: 60, price: 1_000_000 }).execute();
  }

  const booking = (id: string, over: { status?: BookingStatus; remaining_amount?: number } = {}) => ({
    id, customer_id: 'c1', photographer_id: 'p1', service_id: 's1', service_name: 'Gói', service_price: 1_000_000,
    service_duration_minutes: 60, day: '2026-11-02', start_time: '09:00', end_time: '10:00', status: 'accepted' as const,
    deposit_amount: 300_000, remaining_amount: 700_000, ...over,
  });

  it('user_contacts refuses a number that is not E.164', async () => {
    await graph();
    await expect(db.insertInto('user_contacts').values({ user_id: 'c1', phone_e164: '0903123456' }).execute()).rejects.toThrow(/check constraint/);
    await db.insertInto('user_contacts').values({ user_id: 'c1', phone_e164: '+84903123456' }).execute();
  });

  it('bookings: deposit + remaining must equal the snapshot price', async () => {
    await graph();
    await expect(db.insertInto('bookings').values(booking('b1', { remaining_amount: 600_000 })).execute()).rejects.toThrow(/check constraint/);
  });

  it('bookings: one active booking per photographer and day', async () => {
    await graph();
    await db.insertInto('bookings').values(booking('b1')).execute();
    await expect(db.insertInto('bookings').values(booking('b2', { status: 'requested' })).execute()).rejects.toThrow(/ux_bookings_active_day/);
    await db.insertInto('bookings').values(booking('b3', { status: 'declined' })).execute();
  });

  it('contact_access_log: channel must be a ContactChannel code', async () => {
    await graph();
    await expect(
      db.insertInto('contact_access_log').values({ id: 'l1', requester_id: 'c1', subject_type: 'booking', subject_id: 'b1', channel: 'sms' as never, granted: false }).execute(),
    ).rejects.toThrow(/check constraint/);
  });

  it('updated_at is bumped by the trigger on update', async () => {
    await graph();
    const before = await db.selectFrom('users').select('updated_at').where('id', '=', 'c1').executeTakeFirstOrThrow();
    await sql`select pg_sleep(0.01)`.execute(db);
    await db.updateTable('users').set({ display_name: 'Lan' }).where('id', '=', 'c1').execute();
    const after = await db.selectFrom('users').select('updated_at').where('id', '=', 'c1').executeTakeFirstOrThrow();
    expect(after.updated_at.getTime()).toBeGreaterThan(before.updated_at.getTime());
  });

  it('money comes back as a JS integer and a day as yyyy-MM-dd', async () => {
    await graph();
    await db.insertInto('bookings').values(booking('b1')).execute();
    const row = await db.selectFrom('bookings').select(['service_price', 'day']).where('id', '=', 'b1').executeTakeFirstOrThrow();
    expect(row).toEqual({ service_price: 1_000_000, day: '2026-11-02' });
  });
});
```

Append to `services/api/test/helpers.ts`:

```ts
import { sql } from 'kysely';

/** Empties every slice table (FK order handled by CASCADE). */
export async function resetDb(db: Kysely<Database>): Promise<void> {
  await sql`truncate table contact_access_log, booking_events, bookings, services,
    photographer_contact_numbers, photographer_contact_channels, photographers, taxonomy_items,
    auth_identities, user_contacts, users, files restart identity cascade`.execute(db);
}
```

(Put the `import { sql } from 'kysely';` line with the other imports at the top of the file and change `import type { Kysely } from 'kysely';` to `import { sql, type Kysely } from 'kysely';`.)

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/migrations.test.ts`
Expected: FAIL, `Cannot find module '../src/db/migrate.js'`.

- [ ] **Step 3: Implement**

```sql
-- services/api/migrations/1790812800001_accounts.sql
-- relational-schema.md §1 and §2.1 (devices: later, with the push plan).
-- Up Migration
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end $$ language plpgsql;

create table files (
  id               text primary key,
  owner_user_id    text,
  storage_provider text not null,
  storage_key      text not null,
  mime_type        text not null,
  size_bytes       bigint not null check (size_bytes >= 0),
  width            int, height int,
  blurhash         text,
  created_at       timestamptz not null default now(),
  unique (storage_provider, storage_key)
);

create table users (
  id           text primary key,
  display_name text not null default '',
  avatar_file_id text references files(id),
  role         text check (role in ('customer','photographer')),
  staff_role   text check (staff_role in ('admin','sales')),
  city         text,
  locale       text not null default 'vi',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
alter table files add constraint fk_files_owner foreign key (owner_user_id) references users(id);

create table user_contacts (
  user_id        text primary key references users(id) on delete cascade,
  phone_e164     text not null check (phone_e164 ~ '^\+[0-9]{8,15}$'),
  phone_verified boolean not null default false,
  allow_zalo     boolean not null default true,
  allow_whatsapp boolean not null default false,
  updated_at     timestamptz not null default now()
);

create table auth_identities (
  id         text primary key,
  user_id    text not null references users(id) on delete cascade,
  provider   text not null check (provider in ('password','google','facebook','apple','oidc')),
  subject    text not null,
  email      text,
  created_at timestamptz not null default now(),
  unique (provider, subject)
);

create trigger trg_users_updated_at before update on users
  for each row execute function set_updated_at();
create trigger trg_user_contacts_updated_at before update on user_contacts
  for each row execute function set_updated_at();

-- Down Migration
drop table auth_identities;
drop table user_contacts;
alter table files drop constraint fk_files_owner;
drop table users;
drop table files;
drop function set_updated_at();
```

```sql
-- services/api/migrations/1790812800002_photographers.sql
-- relational-schema.md §2.2: taxonomy, photographers, public channel flags, private numbers, services.
-- Up Migration
create table taxonomy_items (
  id         text primary key,
  grp        text not null check (grp in ('specialty','style','extra','language','audience','area')),
  label_vi   text not null,
  parent_id  text references taxonomy_items(id),
  sort_order int not null default 0,
  active     boolean not null default true
);
create index ix_taxonomy_items_grp on taxonomy_items (grp, sort_order);

create table photographers (
  user_id              text primary key references users(id) on delete cascade,
  bio                  text not null default '',
  years_experience     smallint check (years_experience between 0 and 50),
  service_city         text,
  service_lat          double precision, service_lng double precision,
  service_radius_km    smallint,
  cover_file_id        text references files(id),
  verified             boolean not null default false,
  verified_at          timestamptz,
  onboarding_complete  boolean not null default false,
  accepts_inquiries    boolean not null default true,
  rating_avg           numeric(3,2) not null default 0,
  review_count         int not null default 0,
  completed_count      int not null default 0,
  response_minutes_median int,
  starting_price       bigint,
  next_free_date       date,
  skills_completeness  smallint not null default 0 check (skills_completeness between 0 and 100),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table photographer_contact_channels (
  photographer_id text primary key references photographers(user_id) on delete cascade,
  call_enabled     boolean not null default false,
  zalo_enabled     boolean not null default false,
  whatsapp_enabled boolean not null default false
);

create table photographer_contact_numbers (
  photographer_id text primary key references photographers(user_id) on delete cascade,
  phone_e164      text not null check (phone_e164 ~ '^\+[0-9]{8,15}$'),
  zalo_phone_e164 text, whatsapp_phone_e164 text
);

create table services (
  id               text primary key,
  photographer_id  text not null references photographers(user_id) on delete cascade,
  name             text not null,
  specialty_id     text references taxonomy_items(id),
  duration_minutes int not null check (duration_minutes > 0),
  price            bigint not null check (price > 0),
  currency         char(3) not null default 'VND',
  photo_count      int, edited_count int, delivery_days int,
  cover_file_id    text references files(id),
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index ix_services_photographer on services (photographer_id) where active;

create trigger trg_photographers_updated_at before update on photographers
  for each row execute function set_updated_at();
create trigger trg_services_updated_at before update on services
  for each row execute function set_updated_at();

-- Down Migration
drop table services;
drop table photographer_contact_numbers;
drop table photographer_contact_channels;
drop table photographers;
drop table taxonomy_items;
```

```sql
-- services/api/migrations/1790812800003_bookings_contact_log.sql
-- relational-schema.md §2.4 (bookings, booking_events) and §2.7 (contact_access_log).
-- bookings.chat_id gets its FK (fk_bookings_chat) in the chat plan.
-- Up Migration
create table bookings (
  id               text primary key,
  customer_id      text not null references users(id),
  photographer_id  text not null references photographers(user_id),
  service_id       text not null references services(id),
  service_name     text not null,
  service_price    bigint not null check (service_price > 0),
  service_duration_minutes int not null,
  day              date not null,
  start_time       time not null,
  end_time         time not null check (end_time > start_time),
  place_name       text, place_lat double precision, place_lng double precision,
  note             text,
  status           text not null check (status in ('draft','requested','accepted','declined','expired','cancelled','upcoming','completed','reviewed')),
  deposit_amount   bigint not null check (deposit_amount >= 0),
  remaining_amount bigint not null check (remaining_amount >= 0),
  currency         char(3) not null default 'VND',
  deposit_provider text check (deposit_provider in ('momo','vnpay')),
  deposit_paid_at  timestamptz, deposit_refunded_at timestamptz,
  accept_deadline  timestamptz,
  cancelled_by     text check (cancelled_by in ('customer','photographer','system')),
  cancel_reason    text, cancelled_at timestamptz, cancel_refund_percent smallint,
  chat_id          text,
  version          int not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (deposit_amount + remaining_amount = service_price)
);
create index ix_bookings_customer on bookings (customer_id, status, day);
create index ix_bookings_photographer on bookings (photographer_id, status, day);
create unique index ux_bookings_active_day on bookings (photographer_id, day) where status in ('requested','accepted','upcoming');

create table booking_events (
  id         text primary key,
  booking_id text not null references bookings(id) on delete cascade,
  status     text not null,
  actor_id   text references users(id),
  at         timestamptz not null default now()
);
create index ix_booking_events_booking on booking_events (booking_id, at);

create table contact_access_log (
  id text primary key, requester_id text not null references users(id),
  subject_type text not null, subject_id text not null,
  channel text not null check (channel in ('in_app','call','zalo','whatsapp')),
  granted boolean not null, at timestamptz not null default now()
);

create trigger trg_bookings_updated_at before update on bookings
  for each row execute function set_updated_at();

-- Down Migration
drop table contact_access_log;
drop table booking_events;
drop table bookings;
```

```ts
// services/api/src/db/migrate.ts
import { fileURLToPath } from 'node:url';

import { runner } from 'node-pg-migrate';

/** services/api/migrations when run from source; the image sets MIGRATIONS_DIR. */
export const DEFAULT_MIGRATIONS_DIR = fileURLToPath(new URL('../../migrations', import.meta.url));

export function migrate(
  databaseUrl: string,
  direction: 'up' | 'down',
  opts: { count?: number; dir?: string; log?: (msg: string) => void } = {},
): Promise<unknown> {
  return runner({
    databaseUrl,
    dir: opts.dir ?? process.env.MIGRATIONS_DIR ?? DEFAULT_MIGRATIONS_DIR,
    direction,
    count: opts.count ?? (direction === 'up' ? Infinity : 1),
    migrationsTable: 'pgmigrations',
    checkOrder: true,
    singleTransaction: true,
    log: opts.log ?? (() => {}),
  });
}
```

```ts
// services/api/src/db/migrate-cli.ts
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
console.log(`migrations ${direction}: done`);
```

Replace `services/api/src/db/database.ts` with:

```ts
// services/api/src/db/database.ts
import { Kysely, PostgresDialect, type ColumnType } from 'kysely';
import pg from 'pg';

// int8 (bigint money, count(*)) → number; refuse values a JS number cannot hold exactly.
pg.types.setTypeParser(20, (v: string) => {
  const n = Number(v);
  if (!Number.isSafeInteger(n)) throw new RangeError(`int8 value ${v} exceeds Number.MAX_SAFE_INTEGER`);
  return n;
});
// date stays 'yyyy-MM-dd': a calendar day in Asia/Ho_Chi_Minh, not an instant.
pg.types.setTypeParser(1082, (v: string) => v);

/** `default now()`, never written by the API. */
type CreatedAt = ColumnType<Date, Date | string | undefined, never>;
/** Defaulted on insert; the set_updated_at trigger bumps it on update. */
type UpdatedAt = ColumnType<Date, Date | string | undefined, Date | string>;
/** Nullable column, optional on insert. */
type Opt<T> = ColumnType<T | null, T | null | undefined, T | null>;
/** Column with a database default, optional on insert. */
type Def<T> = ColumnType<T, T | undefined, T>;

export type UserRole = 'customer' | 'photographer';
export type StaffRole = 'admin' | 'sales';
export type AuthProvider = 'password' | 'google' | 'facebook' | 'apple' | 'oidc';
export type BookingStatus =
  | 'draft' | 'requested' | 'accepted' | 'declined' | 'expired' | 'cancelled' | 'upcoming' | 'completed' | 'reviewed';
export type ContactChannelCode = 'in_app' | 'call' | 'zalo' | 'whatsapp';

export interface FilesTable {
  id: string;
  owner_user_id: Opt<string>;
  storage_provider: string;
  storage_key: string;
  mime_type: string;
  size_bytes: number;
  width: Opt<number>;
  height: Opt<number>;
  blurhash: Opt<string>;
  created_at: CreatedAt;
}

export interface UsersTable {
  id: string;
  display_name: Def<string>;
  avatar_file_id: Opt<string>;
  role: Opt<UserRole>;
  staff_role: Opt<StaffRole>;
  city: Opt<string>;
  locale: Def<string>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
  deleted_at: Opt<Date>;
}

export interface UserContactsTable {
  user_id: string;
  phone_e164: string;
  phone_verified: Def<boolean>;
  allow_zalo: Def<boolean>;
  allow_whatsapp: Def<boolean>;
  updated_at: UpdatedAt;
}

export interface AuthIdentitiesTable {
  id: string;
  user_id: string;
  provider: AuthProvider;
  subject: string;
  email: Opt<string>;
  created_at: CreatedAt;
}

export interface TaxonomyItemsTable {
  id: string;
  grp: 'specialty' | 'style' | 'extra' | 'language' | 'audience' | 'area';
  label_vi: string;
  parent_id: Opt<string>;
  sort_order: Def<number>;
  active: Def<boolean>;
}

export interface PhotographersTable {
  user_id: string;
  bio: Def<string>;
  years_experience: Opt<number>;
  service_city: Opt<string>;
  service_lat: Opt<number>;
  service_lng: Opt<number>;
  service_radius_km: Opt<number>;
  cover_file_id: Opt<string>;
  verified: Def<boolean>;
  verified_at: Opt<Date>;
  onboarding_complete: Def<boolean>;
  accepts_inquiries: Def<boolean>;
  /** numeric(3,2): pg returns a string, kept as is (derived, read-only here). */
  rating_avg: Def<string>;
  review_count: Def<number>;
  completed_count: Def<number>;
  response_minutes_median: Opt<number>;
  starting_price: Opt<number>;
  next_free_date: Opt<string>;
  skills_completeness: Def<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface PhotographerContactChannelsTable {
  photographer_id: string;
  call_enabled: Def<boolean>;
  zalo_enabled: Def<boolean>;
  whatsapp_enabled: Def<boolean>;
}

export interface PhotographerContactNumbersTable {
  photographer_id: string;
  phone_e164: string;
  zalo_phone_e164: Opt<string>;
  whatsapp_phone_e164: Opt<string>;
}

export interface ServicesTable {
  id: string;
  photographer_id: string;
  name: string;
  specialty_id: Opt<string>;
  duration_minutes: number;
  price: number;
  currency: Def<string>;
  photo_count: Opt<number>;
  edited_count: Opt<number>;
  delivery_days: Opt<number>;
  cover_file_id: Opt<string>;
  active: Def<boolean>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface BookingsTable {
  id: string;
  customer_id: string;
  photographer_id: string;
  service_id: string;
  service_name: string;
  service_price: number;
  service_duration_minutes: number;
  day: string;
  start_time: string;
  end_time: string;
  place_name: Opt<string>;
  place_lat: Opt<number>;
  place_lng: Opt<number>;
  note: Opt<string>;
  status: BookingStatus;
  deposit_amount: number;
  remaining_amount: number;
  currency: Def<string>;
  deposit_provider: Opt<'momo' | 'vnpay'>;
  deposit_paid_at: Opt<Date>;
  deposit_refunded_at: Opt<Date>;
  accept_deadline: Opt<Date>;
  cancelled_by: Opt<'customer' | 'photographer' | 'system'>;
  cancel_reason: Opt<string>;
  cancelled_at: Opt<Date>;
  cancel_refund_percent: Opt<number>;
  chat_id: Opt<string>;
  version: Def<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface BookingEventsTable {
  id: string;
  booking_id: string;
  status: string;
  actor_id: Opt<string>;
  at: ColumnType<Date, Date | string | undefined, never>;
}

export interface ContactAccessLogTable {
  id: string;
  requester_id: string;
  subject_type: string;
  subject_id: string;
  channel: ContactChannelCode;
  granted: boolean;
  at: ColumnType<Date, Date | string | undefined, never>;
}

export interface Database {
  files: FilesTable;
  users: UsersTable;
  user_contacts: UserContactsTable;
  auth_identities: AuthIdentitiesTable;
  taxonomy_items: TaxonomyItemsTable;
  photographers: PhotographersTable;
  photographer_contact_channels: PhotographerContactChannelsTable;
  photographer_contact_numbers: PhotographerContactNumbersTable;
  services: ServicesTable;
  bookings: BookingsTable;
  booking_events: BookingEventsTable;
  contact_access_log: ContactAccessLogTable;
}

export function createDb(databaseUrl: string, max: number): Kysely<Database> {
  return new Kysely<Database>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({
        connectionString: databaseUrl,
        max,
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 2_000,
      }),
    }),
  });
}
```

In `services/api/test/global-setup.ts`, add `import { migrate } from '../src/db/migrate.js';` and migrate the test database in both branches: replace the body of `setup()` with

```ts
  const given = process.env.TEST_DATABASE_URL;
  if (given) {
    if (!new URL(given).pathname.endsWith('_test')) {
      throw new Error('TEST_DATABASE_URL must name a database ending in _test (tests truncate tables)');
    }
    await migrate(given, 'up');
    return;
  }
  container = await new PostgreSqlContainer('postgres:16.4-alpine')
    .withDatabase('nag_test')
    .withUsername('nag')
    .withPassword('nag_test_only')
    .start();
  process.env.TEST_DATABASE_URL = container.getConnectionUri();
  await migrate(process.env.TEST_DATABASE_URL, 'up');
```

In `services/api/package.json` replace the `build` script and add `migrate`:

```json
    "build": "esbuild src/server.ts src/db/migrate-cli.ts --bundle --platform=node --target=node22 --format=esm --packages=external --sourcemap --outdir=dist",
    "migrate": "tsx src/db/migrate-cli.ts",
```

In `services/api/Dockerfile`, final stage, after `COPY --from=build … ./dist` add:

```dockerfile
COPY services/api/migrations ./migrations
ENV MIGRATIONS_DIR=/app/migrations
```

In `services/api/docker-compose.yml` add a `migrate` service (before `api`) and make `api` wait for it:

```yaml
  migrate:
    build: *api-build
    image: nag-api:local
    command: ["node", "dist/db/migrate-cli.js", "up"]
    environment: *api-env
    depends_on:
      db: { condition: service_healthy }
```

and change the `depends_on` of `api` to:

```yaml
    depends_on:
      migrate: { condition: service_completed_successfully }
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean; `Tests  14 passed (14)` (config 3, health 2, migrations 3, constraints 6). If node-pg-migrate reports `Not run migration … is preceding already run migration`, the file prefixes are out of order: keep the `1790812800001…003` names.

Run: `docker compose up --build -d && docker compose logs migrate | tail -n 3 && docker compose down`
Expected: the last log line is `migrations up: done`.

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat(api): slice migrations from the relational schema with rollback tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Domain reuse, error envelope, ids and the OpenAPI contract

**Files:**
- Create: `services/api/src/domain/index.ts`, `services/api/src/errors.ts`, `services/api/src/ids.ts`, `services/api/src/wire.ts`, `services/api/src/deps.ts`, `services/api/api/openapi.yaml`, `services/api/src/contract/openapi.ts`, `services/api/src/generated/api.ts` (generated), `services/api/test/domain-shim.test.ts`, `services/api/test/errors.test.ts`, `services/api/test/contract.test.ts`
- Modify: `services/api/src/app.ts` (replace), `services/api/src/routes/health.ts` (replace), `services/api/src/fastify-augment.ts`, `services/api/package.json`, `services/api/Dockerfile`, `.github/workflows/api.yml`, `docs/superpowers/specs/data-model/domain-model.md`

**Interfaces:**
- Consumes (from phase 1's domain module, through the shim only):
  - `ERROR_CODES: readonly ErrorCode[]` and `type ErrorCode` = the 10 codes of `domain-model.md` §4.
  - `type ExternalChannel = 'call' | 'zalo' | 'whatsapp'`; `interface ContactNumbers { phone: string; zaloPhone?: string | null; whatsappPhone?: string | null }`.
  - `contactUnlocked(subject: { status: BookingStatus; completedAt: Date | null }, now: Date): boolean` (`requested | accepted | upcoming` true; `completed | reviewed` true while `now - completedAt ≤ 30 days`, false when `completedAt` is null; everything else false).
  - `contactUrl(channel: ExternalChannel, numbers: ContactNumbers): string` (`tel:+84…`, `https://zalo.me/84…`, `https://wa.me/<digits>`; Zalo uses `zaloPhone ?? phone`, WhatsApp `whatsappPhone ?? phone`), identical to plan 2b's `contactUriFor`.
- Produces:
  - `type ApiErrorCode = ErrorCode | 'unauthenticated' | 'internal'`; `API_ERROR_CODES`; `HTTP_STATUS: Record<ApiErrorCode, number>`; `class ApiError extends Error { code: ApiErrorCode; status: number }`; `installErrorHandling(app)`; envelope `{ code, message, requestId }`.
  - `newId(now?: number): string` (ULID), `ID_PATTERN`, `isValidId(v): v is string`; `iso(d: Date): string`.
  - `interface Clock { now(): Date }`, `systemClock`, `interface RouteDeps { db; contract; clock }`.
  - `interface Contract`, `loadContract(path?)`, `registerContractSchemas(app, contract)`, `operation(contract, operationId): { method; url; schema }`, `operations(contract): ContractOperation[]`, `toFastifySchema(node)`.
  - `AppDeps { db; contract?; clock?; logLevel? }`; `app.routeTable` (every registered method + URL, for the contract test).
  - Contract operations: `health`, `ensureProfile`, `getUser`, `updateUser`, `setRole`, `getUserContact`, `saveUserContact`, `getContactChannels`, `getContactNumbers`, `getServiceArea`, `completeContactSetup`, `getContactLink`.

- [ ] **Step 1: Read phase 1's domain barrel**

Open `packages/domain/src/index.ts` (or wherever phase 1 put its pure domain barrel; check that plan's File Structure). Note the exported names for the six items under "Consumes". Write the shim in Step 4 with those names (alias with `as` when they differ). If one is missing, add it to phase 1's domain module with a unit test in phase 1's test suite, commit that separately (`feat(domain): …`), then continue. Also check that the module imports nothing outside its own folder except npm packages; any npm package it uses must be added to `services/api/package.json` `dependencies` with the same version range.

- [ ] **Step 2: Write the failing tests**

```ts
// services/api/test/domain-shim.test.ts
import { describe, expect, it } from 'vitest';

import { ERROR_CODES, contactUnlocked, contactUrl } from '../src/domain/index.js';

type Status = Parameters<typeof contactUnlocked>[0]['status'];
const now = new Date('2026-10-01T12:00:00Z');
const ago = (ms: number) => new Date(now.getTime() - ms);
const DAY = 86_400_000;

describe('phase 1 domain module, as reused by the API', () => {
  it('lists the ErrorCode catalogue of domain-model.md §4', () => {
    expect([...ERROR_CODES].sort()).toEqual([
      'conflict', 'contact_locked', 'day_taken', 'deadline_passed', 'invalid_argument',
      'limit_exceeded', 'not_found', 'permission_denied', 'phone_required', 'sold_out',
    ]);
  });

  it.each<[Status, boolean]>([
    ['requested', true], ['accepted', true], ['upcoming', true],
    ['draft', false], ['declined', false], ['expired', false], ['cancelled', false],
  ])('booking %s → unlocked %s', (status, expected) => {
    expect(contactUnlocked({ status, completedAt: null }, now)).toBe(expected);
  });

  it('completed and reviewed stay unlocked for 30 days after completion', () => {
    for (const status of ['completed', 'reviewed'] as Status[]) {
      expect(contactUnlocked({ status, completedAt: ago(29 * DAY) }, now)).toBe(true);
      expect(contactUnlocked({ status, completedAt: ago(30 * DAY) }, now)).toBe(true);
      expect(contactUnlocked({ status, completedAt: ago(30 * DAY + 1000) }, now)).toBe(false);
      expect(contactUnlocked({ status, completedAt: null }, now)).toBe(false);
    }
  });

  it('builds the URL shapes of plan 2b', () => {
    const vn = { phone: '+84903123456' };
    expect(contactUrl('call', vn)).toBe('tel:+84903123456');
    expect(contactUrl('zalo', vn)).toBe('https://zalo.me/84903123456');
    expect(contactUrl('whatsapp', vn)).toBe('https://wa.me/84903123456');
    const own = { phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671' };
    expect(contactUrl('call', own)).toBe('tel:+84903123456');
    expect(contactUrl('zalo', own)).toBe('https://zalo.me/84912345678');
    expect(contactUrl('whatsapp', own)).toBe('https://wa.me/14155552671');
  });
});
```

```ts
// services/api/test/errors.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { API_ERROR_CODES, ApiError, HTTP_STATUS } from '../src/errors.js';
import { ID_PATTERN, isValidId, newId } from '../src/ids.js';
import { iso } from '../src/wire.js';
import { testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp({ db });
  app.get('/test/locked', { config: { public: true } }, async () => {
    throw new ApiError('contact_locked', 'contact opens once the booking is paid');
  });
  app.get('/test/crash', { config: { public: true } }, async () => {
    throw new Error('db said: +84903123456 secret');
  });
  app.post('/test/contact', { config: { public: true }, schema: { body: { $ref: 'SaveUserContactRequest#' } } }, async () => ({ ok: true }));
  await app.ready();
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

describe('error envelope', () => {
  it('every code has an HTTP status', () => {
    for (const code of API_ERROR_CODES) expect(HTTP_STATUS[code], code).toBeGreaterThanOrEqual(400);
    expect(HTTP_STATUS.contact_locked).toBe(403);
    expect(HTTP_STATUS.unauthenticated).toBe(401);
  });

  it('an ApiError becomes {code, message, requestId}', async () => {
    const res = await app.inject({ method: 'GET', url: '/test/locked' });
    expect(res.statusCode).toBe(403);
    expect(res.json()).toEqual({ code: 'contact_locked', message: 'contact opens once the booking is paid', requestId: expect.any(String) });
  });

  it('a body that breaks the contract is invalid_argument, extra fields included', async () => {
    const bad = await app.inject({ method: 'POST', url: '/test/contact', payload: { phone: '0903123456', allowZalo: true, allowWhatsApp: false } });
    expect(bad.statusCode).toBe(400);
    expect(bad.json().code).toBe('invalid_argument');
    const extra = await app.inject({ method: 'POST', url: '/test/contact', payload: { phone: '+84903123456', allowZalo: true, allowWhatsApp: false, phoneVerified: true } });
    expect(extra.statusCode).toBe(400);
    const ok = await app.inject({ method: 'POST', url: '/test/contact', payload: { phone: '+84903123456', allowZalo: true, allowWhatsApp: false } });
    expect(ok.statusCode).toBe(200);
  });

  it('an unknown route is not_found', async () => {
    const res = await app.inject({ method: 'GET', url: '/v1/nope' });
    expect(res.statusCode).toBe(404);
    expect(res.json().code).toBe('not_found');
  });

  it('an unexpected error is internal and leaks nothing', async () => {
    const res = await app.inject({ method: 'GET', url: '/test/crash' });
    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({ code: 'internal', message: 'internal error', requestId: expect.any(String) });
    expect(res.body).not.toContain('84903123456');
  });
});

describe('ids and instants', () => {
  it('new ids are 26-character ULIDs, time ordered, valid ids', () => {
    const a = newId(1_000);
    const b = newId(2_000);
    expect(a).toHaveLength(26);
    expect(a < b).toBe(true);
    expect(ID_PATTERN.test(a)).toBe(true);
    expect(isValidId('Xg7sD9kPq2NfwT4LmR8vYc1BzA03')).toBe(true); // a Firebase uid
    expect(isValidId('a/b')).toBe(false);
    expect(isValidId('x'.repeat(65))).toBe(false);
  });

  it('instants go on the wire as ISO-8601 UTC', () => {
    expect(iso(new Date(Date.UTC(2026, 9, 12, 8, 30)))).toBe('2026-10-12T08:30:00.000Z');
  });
});
```

```ts
// services/api/test/contract.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { loadContract, operations, toFastifyUrl } from '../src/contract/openapi.js';
import { testApp, testDb } from './helpers.js';

/** Operations whose routes arrive in later tasks. Task 7 empties this set. */
const PENDING = new Set<string>([
  'ensureProfile', 'getUser', 'updateUser', 'setRole', 'getUserContact', 'saveUserContact',
  'getContactChannels', 'getContactNumbers', 'getServiceArea', 'completeContactSetup', 'getContactLink',
]);

const contract = loadContract();
const db = testDb();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp({ db });
  await app.ready();
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

describe('API contract', () => {
  it('every contract operation is routed (or still pending)', () => {
    for (const op of operations(contract)) {
      const routed = app.hasRoute({ method: op.method, url: op.url });
      if (PENDING.has(op.operationId)) {
        expect(routed, `${op.operationId} is routed now: remove it from PENDING`).toBe(false);
      } else {
        expect(routed, `${op.operationId} ${op.method} ${op.path}`).toBe(true);
      }
    }
  });

  it('every /v1 route is in the contract', () => {
    const known = new Set(operations(contract).map((o) => `${o.method} ${o.url}`));
    for (const r of app.routeTable.filter((r) => r.url.startsWith('/v1/'))) {
      expect(known.has(`${r.method} ${r.url}`), `${r.method} ${r.url}`).toBe(true);
    }
  });

  it('property names are camelCase and phone fields live only in private schemas', () => {
    const PRIVATE = new Set(['UserContact', 'SaveUserContactRequest', 'ContactNumbers']);
    for (const [name, schema] of Object.entries(contract.components.schemas)) {
      const props = (schema as { properties?: Record<string, unknown> }).properties ?? {};
      for (const key of Object.keys(props)) {
        expect(key, `${name}.${key}`).toMatch(/^[a-z][A-Za-z0-9]*$/);
        if (/phone/i.test(key) && !/^allow/.test(key)) expect(PRIVATE.has(name), `${name}.${key}`).toBe(true);
      }
    }
  });

  it('path templates map to Fastify URLs', () => {
    expect(toFastifyUrl('/v1/users/{userId}/contact')).toBe('/v1/users/:userId/contact');
  });
});
```

- [ ] **Step 3: Run and see them fail**

Run: `npm test -- test/domain-shim.test.ts test/errors.test.ts test/contract.test.ts`
Expected: FAIL, `Cannot find module '../src/domain/index.js'` (and `../src/errors.js`, `../src/contract/openapi.js`).

- [ ] **Step 4: Implement**

```ts
// services/api/src/domain/index.ts
/**
 * The only file in services/api that knows where phase 1's pure domain module
 * lives (created by docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md).
 * Rules are imported, never copied: Cloud Functions and this API run the same
 * code. If phase 1 uses other names, alias them here (`export { x as y }`).
 */
// Phase 1 names (packages/domain): bookingContactUnlocked, contactUrlFor.
// If their parameters differ from the signatures under "Consumes", wrap them
// here instead of aliasing; nothing else in services/api changes.
export {
  ERROR_CODES,
  bookingContactUnlocked as contactUnlocked,
  contactUrlFor as contactUrl,
} from '../../../../packages/domain/src/index.js';
export type {
  ContactNumbers,
  ErrorCode,
  ExternalChannel,
} from '../../../../packages/domain/src/index.js';
```

```ts
// services/api/src/errors.ts
import type { FastifyError, FastifyInstance } from 'fastify';

import { ERROR_CODES, type ErrorCode } from './domain/index.js';

/** HTTP-only codes, added to the domain catalogue (domain-model.md §4). */
export const TRANSPORT_CODES = ['unauthenticated', 'internal'] as const;
export type ApiErrorCode = ErrorCode | (typeof TRANSPORT_CODES)[number];
export const API_ERROR_CODES: readonly ApiErrorCode[] = [...ERROR_CODES, ...TRANSPORT_CODES];

/** Clients branch on `code`; the status is only HTTP plumbing. */
export const HTTP_STATUS: Record<ApiErrorCode, number> = {
  invalid_argument: 400,
  unauthenticated: 401,
  permission_denied: 403,
  contact_locked: 403,
  not_found: 404,
  conflict: 409,
  day_taken: 409,
  sold_out: 409,
  phone_required: 422,
  deadline_passed: 422,
  limit_exceeded: 429,
  internal: 500,
};

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    message: string = code,
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
}

const body = (code: ApiErrorCode, message: string, requestId: string): ErrorBody => ({ code, message, requestId });

export function installErrorHandling(app: FastifyInstance): void {
  app.setErrorHandler((err: FastifyError, req, reply) => {
    if (err instanceof ApiError) {
      return reply.status(err.status).send(body(err.code, err.message, req.id));
    }
    if (err.validation) {
      return reply.status(400).send(body('invalid_argument', 'request does not match the API contract', req.id));
    }
    if (typeof err.statusCode === 'number' && err.statusCode >= 400 && err.statusCode < 500) {
      return reply.status(err.statusCode).send(body('invalid_argument', 'malformed request', req.id));
    }
    // Never echo the original message: it may carry SQL or personal data.
    req.log.error({ err }, 'unhandled error');
    return reply.status(500).send(body('internal', 'internal error', req.id));
  });
  app.setNotFoundHandler((req, reply) => reply.status(404).send(body('not_found', 'no such route', req.id)));
}
```

```ts
// services/api/src/ids.ts
import { monotonicFactory } from 'ulidx';

const nextUlid = monotonicFactory();

/** data-model README §2.1: opaque, immutable, ≤ 64 chars of [A-Za-z0-9_-]. */
export const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/** New ids are ULIDs (26 chars, time ordered). Firebase uids are kept as they are. */
export function newId(now: number = Date.now()): string {
  return nextUlid(now);
}

export function isValidId(v: unknown): v is string {
  return typeof v === 'string' && ID_PATTERN.test(v);
}
```

```ts
// services/api/src/wire.ts
/** Instants on the wire: ISO-8601 in UTC (data-model README §2.2). */
export const iso = (d: Date): string => d.toISOString();
```

```ts
// services/api/src/deps.ts
import type { Kysely } from 'kysely';

import type { Contract } from './contract/openapi.js';
import type { Database } from './db/database.js';

export interface Clock {
  now(): Date;
}

export const systemClock: Clock = { now: () => new Date() };

/** What every route module receives. */
export interface RouteDeps {
  db: Kysely<Database>;
  contract: Contract;
  clock: Clock;
}
```

```yaml
# services/api/api/openapi.yaml
openapi: 3.0.3
info:
  title: NAG self-hosted API
  version: 0.1.0
  description: |
    Phase 2 of the backend migration (docs/superpowers/specs/data-model/README.md §6), first
    vertical slice: profile, private customer contact, photographer contact channels/numbers
    and get_contact_link. Conventions (README §2): camelCase JSON, ISO-8601 UTC instants,
    integer VND, string enum codes, opaque ids. Every error uses the Error schema; clients
    branch on `code`, never on `message`. Phone numbers appear only in owner-only operations.
    The server builds its routes and validators from this file.
servers:
  - url: http://localhost:8787
    description: services/api/docker-compose.yml
security:
  - firebaseIdToken: []
paths:
  /v1/health:
    get:
      operationId: health
      summary: Liveness and database reachability
      security: []
      responses:
        '200':
          description: Up
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Health' }
        '503':
          description: Database unreachable
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Health' }
  /v1/me:
    post:
      operationId: ensureProfile
      summary: Create the caller's profile when missing (never overwrites) and record the sign-in identity
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/EnsureProfileRequest' }
      responses:
        '200':
          description: The existing profile
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserProfile' }
        '201':
          description: Created
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserProfile' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
  /v1/users/{userId}:
    parameters:
      - $ref: '#/components/parameters/UserId'
    get:
      operationId: getUser
      summary: Public profile (any signed-in user)
      responses:
        '200':
          description: Profile
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserProfile' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '404': { $ref: '#/components/responses/NotFound' }
    patch:
      operationId: updateUser
      summary: Change the owner's display name
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/UpdateUserRequest' }
      responses:
        '200':
          description: Updated profile
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserProfile' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/users/{userId}/role:
    parameters:
      - $ref: '#/components/parameters/UserId'
    put:
      operationId: setRole
      summary: Use case set_role; the first switch to photographer creates the photographer row
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/SetRoleRequest' }
      responses:
        '200':
          description: Updated profile
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserProfile' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/users/{userId}/contact:
    parameters:
      - $ref: '#/components/parameters/UserId'
    get:
      operationId: getUserContact
      summary: The owner's private contact (owner only)
      responses:
        '200':
          description: Contact
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserContact' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '404': { $ref: '#/components/responses/NotFound' }
    put:
      operationId: saveUserContact
      summary: Create or replace the owner's contact; a changed number becomes unverified
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/SaveUserContactRequest' }
      responses:
        '200':
          description: Stored contact
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserContact' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/photographers/{photographerId}/contact-channels:
    parameters:
      - $ref: '#/components/parameters/PhotographerId'
    get:
      operationId: getContactChannels
      summary: Public channel flags (no numbers)
      responses:
        '200':
          description: Flags
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ContactChannels' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/photographers/{photographerId}/contact-numbers:
    parameters:
      - $ref: '#/components/parameters/PhotographerId'
    get:
      operationId: getContactNumbers
      summary: The photographer's private numbers (owner only; others use getContactLink)
      responses:
        '200':
          description: Numbers
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ContactNumbers' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/photographers/{photographerId}/service-area:
    parameters:
      - $ref: '#/components/parameters/PhotographerId'
    get:
      operationId: getServiceArea
      summary: City and radius (others see it once onboarding is complete)
      responses:
        '200':
          description: Area
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ServiceArea' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/photographers/{photographerId}/contact-setup:
    parameters:
      - $ref: '#/components/parameters/PhotographerId'
    put:
      operationId: completeContactSetup
      summary: S34 "Hoàn tất" in one transaction (area, flags, numbers, onboardingComplete)
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/ContactSetupRequest' }
      responses:
        '204':
          description: Stored
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403': { $ref: '#/components/responses/Forbidden' }
        '404': { $ref: '#/components/responses/NotFound' }
  /v1/contact-links:
    post:
      operationId: getContactLink
      summary: Use case get_contact_link; one URL when contact is unlocked, logged in contact_access_log
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/ContactLinkRequest' }
      responses:
        '200':
          description: The URL to open
          content:
            application/json:
              schema: { $ref: '#/components/schemas/ContactLinkResponse' }
        '400': { $ref: '#/components/responses/BadRequest' }
        '401': { $ref: '#/components/responses/Unauthenticated' }
        '403':
          description: permission_denied (not the customer) or contact_locked (not unlocked yet)
          content:
            application/json:
              schema: { $ref: '#/components/schemas/Error' }
        '404': { $ref: '#/components/responses/NotFound' }
components:
  securitySchemes:
    firebaseIdToken:
      type: http
      scheme: bearer
      bearerFormat: Firebase ID token (Auth emulator tokens when AUTH_MODE=firebase-emulator)
  parameters:
    UserId:
      name: userId
      in: path
      required: true
      schema: { $ref: '#/components/schemas/Id' }
    PhotographerId:
      name: photographerId
      in: path
      required: true
      schema: { $ref: '#/components/schemas/Id' }
  responses:
    BadRequest:
      description: invalid_argument
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    Unauthenticated:
      description: unauthenticated
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    Forbidden:
      description: permission_denied
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    NotFound:
      description: not_found
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
  schemas:
    Id:
      type: string
      pattern: '^[A-Za-z0-9_-]{1,64}$'
    ErrorCode:
      type: string
      enum: [day_taken, phone_required, contact_locked, sold_out, deadline_passed, limit_exceeded,
             invalid_argument, permission_denied, not_found, conflict, unauthenticated, internal]
    Error:
      type: object
      required: [code, message, requestId]
      properties:
        code: { $ref: '#/components/schemas/ErrorCode' }
        message: { type: string }
        requestId: { type: string }
    Health:
      type: object
      required: [status, db]
      properties:
        status: { type: string, enum: [ok, degraded] }
        db: { type: string, enum: [ok, down] }
    UserProfile:
      type: object
      additionalProperties: false
      required: [id, displayName, role, avatarUrl]
      properties:
        id: { $ref: '#/components/schemas/Id' }
        displayName: { type: string }
        role: { type: string, nullable: true, enum: [customer, photographer, null] }
        avatarUrl: { type: string, nullable: true }
    EnsureProfileRequest:
      type: object
      additionalProperties: false
      required: [displayName]
      properties:
        displayName: { type: string, minLength: 1, maxLength: 80 }
        avatarUrl: { type: string, format: uri, maxLength: 2048 }
    UpdateUserRequest:
      type: object
      additionalProperties: false
      required: [displayName]
      properties:
        displayName: { type: string, minLength: 1, maxLength: 80 }
    SetRoleRequest:
      type: object
      additionalProperties: false
      required: [role]
      properties:
        role: { type: string, enum: [customer, photographer] }
    VnPhone:
      type: string
      description: Vietnamese mobile number, E.164
      pattern: '^\+84[35789][0-9]{8}$'
    UserContact:
      type: object
      additionalProperties: false
      required: [phone, phoneVerified, allowZalo, allowWhatsApp, updatedAt]
      properties:
        phone: { $ref: '#/components/schemas/VnPhone' }
        phoneVerified: { type: boolean, description: Set only by a server process (verification is a later plan) }
        allowZalo: { type: boolean }
        allowWhatsApp: { type: boolean }
        updatedAt: { type: string, format: date-time }
    SaveUserContactRequest:
      type: object
      additionalProperties: false
      required: [phone, allowZalo, allowWhatsApp]
      properties:
        phone: { $ref: '#/components/schemas/VnPhone' }
        allowZalo: { type: boolean }
        allowWhatsApp: { type: boolean }
    ContactChannels:
      type: object
      additionalProperties: false
      required: [call, zalo, whatsapp, acceptInquiries]
      properties:
        call: { type: boolean }
        zalo: { type: boolean }
        whatsapp: { type: boolean }
        acceptInquiries: { type: boolean }
    ContactNumbers:
      type: object
      additionalProperties: false
      required: [phone]
      properties:
        phone: { $ref: '#/components/schemas/VnPhone' }
        zaloPhone: { type: string, nullable: true, pattern: '^\+84[35789][0-9]{8}$' }
        whatsappPhone: { type: string, nullable: true, pattern: '^\+[0-9]{8,15}$' }
    ServiceArea:
      type: object
      additionalProperties: false
      required: [city, radiusKm]
      properties:
        city: { type: string, minLength: 2, maxLength: 80 }
        radiusKm: { type: integer, minimum: 1, maximum: 200 }
    ContactSetupRequest:
      type: object
      additionalProperties: false
      required: [area, channels, numbers]
      properties:
        area: { $ref: '#/components/schemas/ServiceArea' }
        channels: { $ref: '#/components/schemas/ContactChannels' }
        numbers: { $ref: '#/components/schemas/ContactNumbers' }
    ExternalChannel:
      type: string
      enum: [call, zalo, whatsapp]
    ContactLinkRequest:
      type: object
      additionalProperties: false
      required: [channel]
      properties:
        bookingId: { $ref: '#/components/schemas/Id' }
        registrationId: { $ref: '#/components/schemas/Id' }
        channel: { $ref: '#/components/schemas/ExternalChannel' }
      oneOf:
        - required: [bookingId]
        - required: [registrationId]
    ContactLinkResponse:
      type: object
      additionalProperties: false
      required: [url]
      properties:
        url: { type: string, description: 'tel:+84…, https://zalo.me/84…, https://wa.me/<digits>' }
```

```ts
// services/api/src/contract/openapi.ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import type { FastifyInstance, FastifySchema, HTTPMethods } from 'fastify';
import { parse } from 'yaml';

type Json = null | boolean | number | string | Json[] | { [k: string]: Json };
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
  requestBody?: { content?: Record<string, { schema: Json }> };
  responses: Record<string, { content?: Record<string, { schema: Json }> } | Ref>;
}

type PathItem = { parameters?: Array<Parameter | Ref> } & Partial<Record<(typeof METHODS)[number], Operation>>;

export interface Contract {
  paths: Record<string, PathItem>;
  components: { schemas: Record<string, Json>; parameters?: Record<string, Parameter> };
}

export interface ContractOperation {
  operationId: string;
  method: HTTPMethods;
  /** OpenAPI template, e.g. /v1/users/{userId}. */
  path: string;
  /** Fastify URL, e.g. /v1/users/:userId. */
  url: string;
}

const METHODS = ['get', 'post', 'put', 'patch', 'delete'] as const;

export const DEFAULT_CONTRACT_PATH = fileURLToPath(new URL('../../api/openapi.yaml', import.meta.url));

export function loadContract(path: string = process.env.CONTRACT_PATH ?? DEFAULT_CONTRACT_PATH): Contract {
  return parse(readFileSync(path, 'utf8')) as Contract;
}

export const toFastifyUrl = (path: string): string => path.replace(/\{(\w+)\}/g, ':$1');

/** OpenAPI → Fastify JSON schema: local refs become shared-schema ids, `example` is dropped. */
export function toFastifySchema(node: Json): Json {
  if (Array.isArray(node)) return node.map(toFastifySchema);
  if (node === null || typeof node !== 'object') return node;
  const out: { [k: string]: Json } = {};
  for (const [k, v] of Object.entries(node)) {
    if (k === 'example') continue;
    if (k === '$ref' && typeof v === 'string') {
      out.$ref = `${v.replace('#/components/schemas/', '')}#`;
      continue;
    }
    out[k] = toFastifySchema(v);
  }
  return out;
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

/** Method, URL and validation/serialisation schemas of one operation, straight from the contract. */
export function operation(
  contract: Contract,
  operationId: string,
): { method: HTTPMethods; url: string; schema: FastifySchema } {
  for (const [path, item] of Object.entries(contract.paths)) {
    for (const m of METHODS) {
      const op = item[m];
      if (!op || op.operationId !== operationId) continue;
      const schema: FastifySchema = {};
      const params = [...(item.parameters ?? []), ...(op.parameters ?? [])]
        .map((p) => resolveParameter(contract, p))
        .filter((p) => p.in === 'path');
      if (params.length > 0) {
        schema.params = {
          type: 'object',
          additionalProperties: false,
          required: params.map((p) => p.name),
          properties: Object.fromEntries(params.map((p) => [p.name, toFastifySchema(p.schema)])),
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
      return { method: m.toUpperCase() as HTTPMethods, url: toFastifyUrl(path), schema };
    }
  }
  throw new Error(`operation ${operationId} is not in the API contract`);
}
```

Replace `services/api/src/fastify-augment.ts`:

```ts
// services/api/src/fastify-augment.ts
export {};

declare module 'fastify' {
  interface FastifyContextConfig {
    /** Route needs no bearer token (only /v1/health). */
    public?: boolean;
  }
  interface FastifyInstance {
    /** Every registered method + URL (HEAD excluded), for the contract test. */
    routeTable: Array<{ method: string; url: string }>;
  }
}
```

Replace `services/api/src/routes/health.ts`:

```ts
// services/api/src/routes/health.ts
import type { FastifyInstance } from 'fastify';
import { sql } from 'kysely';

import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';

export function registerHealthRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route({
    ...operation(deps.contract, 'health'),
    config: { public: true },
    handler: async (_req, reply) => {
      try {
        await sql`select 1`.execute(deps.db);
        return { status: 'ok', db: 'ok' };
      } catch {
        return reply.status(503).send({ status: 'degraded', db: 'down' });
      }
    },
  });
}
```

Replace `services/api/src/app.ts`:

```ts
// services/api/src/app.ts
import compress from '@fastify/compress';
import Fastify, { type FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';

import { loadContract, registerContractSchemas, type Contract } from './contract/openapi.js';
import type { Database } from './db/database.js';
import { systemClock, type Clock, type RouteDeps } from './deps.js';
import { installErrorHandling } from './errors.js';
import { registerHealthRoutes } from './routes/health.js';

export interface AppDeps {
  db: Kysely<Database>;
  /** Defaults to api/openapi.yaml (CONTRACT_PATH in the image). */
  contract?: Contract;
  clock?: Clock;
  /** Pino level; omit to disable logging (tests). */
  logLevel?: string;
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    logger: deps.logLevel ? { level: deps.logLevel, redact: ['req.headers.authorization'] } : false,
    keepAliveTimeout: 65_000,
    bodyLimit: 16 * 1024,
    // Extra properties are an error, not silently dropped (clients never write server fields).
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } },
  });

  const routeTable: Array<{ method: string; url: string }> = [];
  app.decorate('routeTable', routeTable);
  app.addHook('onRoute', (r) => {
    for (const method of [r.method].flat()) if (method !== 'HEAD') routeTable.push({ method, url: r.url });
  });

  const contract = deps.contract ?? loadContract();
  registerContractSchemas(app, contract);
  installErrorHandling(app);
  // Slice payloads are < 1 KiB and stay uncompressed; anything larger is gzipped.
  await app.register(compress, { global: true, threshold: 1024, encodings: ['gzip'] });

  const routeDeps: RouteDeps = { db: deps.db, contract, clock: deps.clock ?? systemClock };
  registerHealthRoutes(app, routeDeps);
  return app;
}
```

In `services/api/package.json` add the script:

```json
    "gen:types": "openapi-typescript api/openapi.yaml -o src/generated/api.ts",
```

and generate the types (commit the output; never edit it by hand):

```bash
npm run gen:types
```

Expected: `🚀 api/openapi.yaml → src/generated/api.ts`; the file declares `export interface components { schemas: { … UserContact: { phone: string; … } … } }`.

In `services/api/Dockerfile`, build stage, insert before `RUN npm run build`:

```dockerfile
COPY packages/domain/ /repo/packages/domain/
```

and in the final stage, after the migrations lines:

```dockerfile
COPY services/api/api ./api
ENV CONTRACT_PATH=/app/api/openapi.yaml
```

In `.github/workflows/api.yml`, after `- run: npm ci` add:

```yaml
      - name: Generated types match the contract
        run: npm run gen:types && git diff --exit-code src/generated/api.ts
```

In `docs/superpowers/specs/data-model/domain-model.md` §4, replace the `ErrorCode` row's note `Mã lỗi nghiệp vụ ổn định` with:

```
Mã lỗi nghiệp vụ ổn định. Tầng HTTP của máy chủ riêng thêm hai mã giao vận `unauthenticated` (401) và `internal` (500); use case không dùng hai mã này
```

- [ ] **Step 5: Run and see them pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean (it also type-checks phase 1's domain files through the shim); `Tests  35 passed (35)` (14 before + domain-shim 10 + errors 7 + contract 4). If the domain-shim tests fail, phase 1's behaviour differs from plan 2b's contract: fix phase 1 (both the Functions and this API must agree with the app), not the test.

Run: `npm run build && docker compose up --build -d && curl -s localhost:8787/v1/health && curl -s localhost:8787/v1/nope && docker compose down`
Expected: `{"status":"ok","db":"ok"}` then `{"code":"not_found","message":"no such route","requestId":"req-…"}`.

- [ ] **Step 6: Commit**

```bash
git add services/api .github/workflows/api.yml docs/superpowers/specs/data-model/domain-model.md
git commit -m "feat(api): OpenAPI contract, error envelope, ULIDs and reuse of the phase 1 domain module

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Authentication with Firebase ID tokens and `POST /v1/me`

**Files:**
- Create: `services/api/src/auth/identity.ts`, `services/api/src/auth/plugin.ts`, `services/api/src/repos/users.ts`, `services/api/src/routes/me.ts`, `services/api/test/auth.test.ts`, `services/api/test/me.test.ts`
- Modify: `services/api/src/app.ts`, `services/api/src/server.ts`, `services/api/test/helpers.ts` (replace), `services/api/test/contract.test.ts`

**Interfaces:**
- Consumes: `ApiError`, `isValidId`, `newId`, `operation`, `RouteDeps`, `Clock` (Task 3); `AuthProvider`, `UserRole`, `Database` (Task 2).
- Produces:
  - `interface Principal { uid: string; signInProvider: string; providerSubject: string; email: string | null }`; `interface IdentityVerifier { verify(token: string): Promise<Principal> }` (throws `ApiError('unauthenticated')`).
  - `class JwksVerifier({ jwks: JWTVerifyGetKey; projectId: string; clock?: Clock })`, `firebaseVerifier(projectId): JwksVerifier` (Google securetoken JWKS), `class EmulatorVerifier({ projectId: string; clock?: Clock })`, `claimsToPrincipal(payload): Principal`, `authProviderCode(signInProvider): AuthProvider`, `FIREBASE_JWKS_URL`.
  - `installAuth(app, verifier)`, `principalOf(req): Principal`, `requireSelf(req, subjectId): Principal` (`permission_denied` for anyone else).
  - `interface PublicProfile { id: string; displayName: string; role: UserRole | null; avatarUrl: string | null }`; `profileQuery(db, id)`, `findProfile(db, id): Promise<PublicProfile | null>`, `ensureProfile(db, principal, input: { displayName: string; avatarUrl?: string }): Promise<{ profile: PublicProfile; created: boolean }>`.
  - `POST /v1/me` (`ensureProfile`): 201 created / 200 existing; writes `users`, `files` (external avatar) and `auth_identities` (idempotent).
  - `AppDeps.verifier: IdentityVerifier` (required).
  - Test helpers: `PROJECT_ID`, `testVerifier`, `tokenFor(uid, opts?)`, `bearer(uid, opts?)`, `emulatorToken(uid, opts?)`, `testApp(deps)` (verifier defaulted), `resetDb`.

- [ ] **Step 1: Write the failing tests**

Replace `services/api/test/helpers.ts`:

```ts
// services/api/test/helpers.ts
import type { FastifyInstance } from 'fastify';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK, type KeyLike } from 'jose';
import { sql, type Kysely } from 'kysely';

import { buildApp, type AppDeps } from '../src/app.js';
import { JwksVerifier } from '../src/auth/identity.js';
import { createDb, type Database } from '../src/db/database.js';

export const PROJECT_ID = 'demo-nag-test';

export function testDatabaseUrl(): string {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is set by test/global-setup.ts');
  return url;
}

export function testDb(): Kysely<Database> {
  return createDb(testDatabaseUrl(), 4);
}

/** Empties every slice table (FK order handled by CASCADE). */
export async function resetDb(db: Kysely<Database>): Promise<void> {
  await sql`truncate table contact_access_log, booking_events, bookings, services,
    photographer_contact_numbers, photographer_contact_channels, photographers, taxonomy_items,
    auth_identities, user_contacts, users, files restart identity cascade`.execute(db);
}

// A local RS256 key stands in for Google's securetoken key: the same JwksVerifier
// class runs in production with the remote JWKS.
const keys = await generateKeyPair('RS256', { extractable: true });
const publicJwk: JWK = { ...(await exportJWK(keys.publicKey)), kid: 'test-key', alg: 'RS256', use: 'sig' };
export const testVerifier = new JwksVerifier({ jwks: createLocalJWKSet({ keys: [publicJwk] }), projectId: PROJECT_ID });

export interface TokenOptions {
  provider?: string;
  identities?: Record<string, string[]>;
  email?: string;
  audience?: string;
  issuer?: string;
  /** Expiry as epoch seconds; default one hour from now. */
  exp?: number;
  key?: KeyLike;
}

export function tokenFor(uid: string, o: TokenOptions = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({
    user_id: uid,
    auth_time: now,
    ...(o.email ? { email: o.email } : {}),
    firebase: { sign_in_provider: o.provider ?? 'password', identities: o.identities ?? {} },
  })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(o.issuer ?? `https://securetoken.google.com/${PROJECT_ID}`)
    .setAudience(o.audience ?? PROJECT_ID)
    .setSubject(uid)
    .setIssuedAt(now)
    .setExpirationTime(o.exp ?? now + 3600)
    .sign(o.key ?? keys.privateKey);
}

export async function bearer(uid: string, o?: TokenOptions): Promise<{ authorization: string }> {
  return { authorization: `Bearer ${await tokenFor(uid, o)}` };
}

/** What the Firebase Auth emulator issues: an unsigned JWT (alg "none"). */
export function emulatorToken(uid: string, o: { projectId?: string; exp?: number } = {}): string {
  const projectId = o.projectId ?? PROJECT_ID;
  const now = Math.floor(Date.now() / 1000);
  const enc = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${projectId}`,
    aud: projectId,
    sub: uid,
    user_id: uid,
    iat: now,
    auth_time: now,
    exp: o.exp ?? now + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

export function testApp(deps: Omit<AppDeps, 'verifier'> & Partial<Pick<AppDeps, 'verifier'>>): Promise<FastifyInstance> {
  return buildApp({ verifier: testVerifier, ...deps });
}
```

```ts
// services/api/test/auth.test.ts
import type { FastifyInstance } from 'fastify';
import { generateKeyPair } from 'jose';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { authProviderCode, claimsToPrincipal, EmulatorVerifier } from '../src/auth/identity.js';
import { ApiError } from '../src/errors.js';
import { bearer, emulatorToken, PROJECT_ID, testApp, testDb, tokenFor } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const me = (headers: Record<string, string>) =>
  app.inject({ method: 'POST', url: '/v1/me', headers, payload: { displayName: 'Lan' } });

describe('bearer tokens on /v1/*', () => {
  it('no token → 401 with the error envelope', async () => {
    const res = await me({});
    expect(res.statusCode).toBe(401);
    expect(res.json()).toMatchObject({ code: 'unauthenticated', requestId: expect.any(String) });
  });

  it('a token signed by another key → 401', async () => {
    const other = await generateKeyPair('RS256');
    expect((await me(await bearer('u1', { key: other.privateKey }))).statusCode).toBe(401);
  });

  it('wrong audience, wrong issuer or expired → 401', async () => {
    expect((await me(await bearer('u1', { audience: 'other-project' }))).statusCode).toBe(401);
    expect((await me(await bearer('u1', { issuer: 'https://evil.example' }))).statusCode).toBe(401);
    expect((await me(await bearer('u1', { exp: Math.floor(Date.now() / 1000) - 60 }))).statusCode).toBe(401);
  });

  it('a subject that is not a valid id → 401', async () => {
    expect((await me(await bearer('bad/uid'))).statusCode).toBe(401);
  });

  it('health stays public', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/health' })).statusCode).toBe(200);
  });
});

describe('EmulatorVerifier', () => {
  const v = new EmulatorVerifier({ projectId: PROJECT_ID });

  it('accepts the emulator\'s unsigned token for its project', async () => {
    expect((await v.verify(emulatorToken('u1'))).uid).toBe('u1');
  });

  it('refuses signed tokens, other projects and expired tokens', async () => {
    await expect(v.verify(await tokenFor('u1'))).rejects.toBeInstanceOf(ApiError);
    await expect(v.verify(emulatorToken('u1', { projectId: 'other' }))).rejects.toBeInstanceOf(ApiError);
    await expect(v.verify(emulatorToken('u1', { exp: Math.floor(Date.now() / 1000) - 1 }))).rejects.toBeInstanceOf(ApiError);
    await expect(v.verify('not-a-jwt')).rejects.toBeInstanceOf(ApiError);
  });
});

describe('claims', () => {
  it('a social sign-in keeps the provider\'s own subject; password keeps the uid', () => {
    const google = claimsToPrincipal({
      sub: 'u1', email: 'lan@example.com',
      firebase: { sign_in_provider: 'google.com', identities: { 'google.com': ['1098765'] } },
    });
    expect(google).toEqual({ uid: 'u1', signInProvider: 'google.com', providerSubject: '1098765', email: 'lan@example.com' });
    const pw = claimsToPrincipal({ sub: 'u2', firebase: { sign_in_provider: 'password', identities: { email: ['a@b.vn'] } } });
    expect(pw.providerSubject).toBe('u2');
  });

  it('maps Firebase provider ids to AuthProvider codes', () => {
    expect(authProviderCode('google.com')).toBe('google');
    expect(authProviderCode('facebook.com')).toBe('facebook');
    expect(authProviderCode('apple.com')).toBe('apple');
    expect(authProviderCode('password')).toBe('password');
    expect(authProviderCode('oidc.keycloak')).toBe('oidc');
  });
});
```

```ts
// services/api/test/me.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { bearer, resetDb, testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});
beforeEach(() => resetDb(db));

const post = async (uid: string, payload: object, o?: Parameters<typeof bearer>[1]) =>
  app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(uid, o), payload });

describe('POST /v1/me (ensureProfile)', () => {
  it('creates the profile once (201) and never overwrites it (200)', async () => {
    const first = await post('u1', { displayName: 'Lan' });
    expect(first.statusCode).toBe(201);
    expect(first.json()).toEqual({ id: 'u1', displayName: 'Lan', role: null, avatarUrl: null });
    const again = await post('u1', { displayName: 'Someone else' });
    expect(again.statusCode).toBe(200);
    expect(again.json().displayName).toBe('Lan');
  });

  it('records the sign-in identity once; the email stays private', async () => {
    const o = { provider: 'google.com', identities: { 'google.com': ['1098765'] }, email: 'lan@example.com' };
    const res = await post('u1', { displayName: 'Lan' }, o);
    await post('u1', { displayName: 'Lan' }, o);
    expect(res.body).not.toContain('lan@example.com');
    const rows = await db.selectFrom('auth_identities').select(['user_id', 'provider', 'subject', 'email']).execute();
    expect(rows).toEqual([{ user_id: 'u1', provider: 'google', subject: '1098765', email: 'lan@example.com' }]);
  });

  it('keeps a social avatar as an external file and returns its URL', async () => {
    const url = 'https://lh3.googleusercontent.com/a/photo.jpg';
    const res = await post('u1', { displayName: 'Lan', avatarUrl: url });
    expect(res.json().avatarUrl).toBe(url);
    const file = await db.selectFrom('files').select(['storage_provider', 'storage_key', 'owner_user_id']).executeTakeFirstOrThrow();
    expect(file).toEqual({ storage_provider: 'external', storage_key: url, owner_user_id: 'u1' });
  });

  it('validates the body against the contract', async () => {
    expect((await post('u1', { displayName: '' })).statusCode).toBe(400);
    expect((await post('u1', { displayName: 'Lan', role: 'photographer' })).json().code).toBe('invalid_argument');
  });

  it('a deleted account cannot recreate itself', async () => {
    await post('u1', { displayName: 'Lan' });
    await db.updateTable('users').set({ deleted_at: new Date() }).where('id', '=', 'u1').execute();
    const res = await post('u1', { displayName: 'Lan' });
    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('permission_denied');
  });
});
```

In `services/api/test/contract.test.ts` remove `'ensureProfile', ` from `PENDING`.

- [ ] **Step 2: Run and see them fail**

Run: `npm test -- test/auth.test.ts test/me.test.ts`
Expected: FAIL, `Cannot find module '../src/auth/identity.js'`.

- [ ] **Step 3: Implement**

```ts
// services/api/src/auth/identity.ts
import {
  createRemoteJWKSet,
  decodeJwt,
  decodeProtectedHeader,
  jwtVerify,
  type JWTPayload,
  type JWTVerifyGetKey,
} from 'jose';

import type { AuthProvider } from '../db/database.js';
import type { Clock } from '../deps.js';
import { ApiError } from '../errors.js';
import { isValidId } from '../ids.js';

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

```ts
// services/api/src/auth/plugin.ts
import type { FastifyInstance, FastifyRequest } from 'fastify';

import { ApiError } from '../errors.js';
import type { IdentityVerifier, Principal } from './identity.js';

declare module 'fastify' {
  interface FastifyRequest {
    principal: Principal | null;
  }
}

/** Every route needs a bearer token unless its config says `public: true`. */
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

/** Authorization matrix "S": only the subject itself. */
export function requireSelf(req: FastifyRequest, subjectId: string): Principal {
  const p = principalOf(req);
  if (p.uid !== subjectId) throw new ApiError('permission_denied', 'only the owner can do this');
  return p;
}
```

```ts
// services/api/src/repos/users.ts
import type { Kysely } from 'kysely';

import { authProviderCode, type Principal } from '../auth/identity.js';
import type { Database, UserRole } from '../db/database.js';
import { ApiError } from '../errors.js';
import { newId } from '../ids.js';

/** users/{uid} as everyone may see it: never a phone, never an email. */
export interface PublicProfile {
  id: string;
  displayName: string;
  role: UserRole | null;
  avatarUrl: string | null;
}

export const profileQuery = (db: Kysely<Database>, id: string) =>
  db
    .selectFrom('users as u')
    .leftJoin('files as f', 'f.id', 'u.avatar_file_id')
    .select(['u.id', 'u.display_name', 'u.role', 'f.storage_provider', 'f.storage_key'])
    .where('u.id', '=', id)
    .where('u.deleted_at', 'is', null);

export async function findProfile(db: Kysely<Database>, id: string): Promise<PublicProfile | null> {
  const r = await profileQuery(db, id).executeTakeFirst();
  if (!r) return null;
  return {
    id: r.id,
    displayName: r.display_name,
    role: r.role,
    // MediaUrlResolver for real storage keys arrives with the Storage plan.
    avatarUrl: r.storage_provider === 'external' ? r.storage_key : null,
  };
}

/** Creates users/{uid} when missing (never overwrites) and records the sign-in identity. */
export async function ensureProfile(
  db: Kysely<Database>,
  p: Principal,
  input: { displayName: string; avatarUrl?: string },
): Promise<{ profile: PublicProfile; created: boolean }> {
  return db.transaction().execute(async (trx) => {
    const inserted = await trx
      .insertInto('users')
      .values({ id: p.uid, display_name: input.displayName })
      .onConflict((oc) => oc.column('id').doNothing())
      .returning('id')
      .executeTakeFirst();
    const created = inserted !== undefined;
    if (created && input.avatarUrl) {
      await trx
        .insertInto('files')
        .values({
          id: newId(),
          owner_user_id: p.uid,
          storage_provider: 'external',
          storage_key: input.avatarUrl,
          mime_type: 'image/*',
          size_bytes: 0,
        })
        .onConflict((oc) => oc.columns(['storage_provider', 'storage_key']).doNothing())
        .execute();
      const file = await trx
        .selectFrom('files')
        .select('id')
        .where('storage_provider', '=', 'external')
        .where('storage_key', '=', input.avatarUrl)
        .executeTakeFirstOrThrow();
      await trx.updateTable('users').set({ avatar_file_id: file.id }).where('id', '=', p.uid).execute();
    }
    await trx
      .insertInto('auth_identities')
      .values({
        id: newId(),
        user_id: p.uid,
        provider: authProviderCode(p.signInProvider),
        subject: p.providerSubject,
        email: p.email,
      })
      .onConflict((oc) => oc.columns(['provider', 'subject']).doNothing())
      .execute();
    const profile = await findProfile(trx, p.uid);
    if (!profile) throw new ApiError('permission_denied', 'this account was deleted');
    return { profile, created };
  });
}
```

```ts
// services/api/src/routes/me.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { ensureProfile } from '../repos/users.js';

type S = components['schemas'];

export function registerMeRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Body: S['EnsureProfileRequest'] }>({
    ...operation(deps.contract, 'ensureProfile'),
    handler: async (req, reply) => {
      const { profile, created } = await ensureProfile(deps.db, principalOf(req), req.body);
      return reply.status(created ? 201 : 200).send(profile);
    },
  });
}
```

In `services/api/src/app.ts`:
- add imports `import type { IdentityVerifier } from './auth/identity.js';`, `import { installAuth } from './auth/plugin.js';`, `import { registerMeRoutes } from './routes/me.js';`;
- add to `AppDeps` the field `verifier: IdentityVerifier;` (first field after `db`);
- after `installErrorHandling(app);` add `installAuth(app, deps.verifier);`;
- after `registerHealthRoutes(app, routeDeps);` add `registerMeRoutes(app, routeDeps);`.

In `services/api/src/server.ts` add `import { EmulatorVerifier, firebaseVerifier } from './auth/identity.js';` and replace the `buildApp` line with:

```ts
const verifier =
  config.authMode === 'firebase'
    ? firebaseVerifier(config.firebaseProjectId)
    : new EmulatorVerifier({ projectId: config.firebaseProjectId });
const app = await buildApp({ db, verifier, logLevel: config.logLevel });
```

- [ ] **Step 4: Run and see them pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean; `Tests  49 passed (49)` (35 + auth 9 + me 5).

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat(api): verify Firebase ID tokens and add POST /v1/me with auth identities

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Public profile and private customer contact

**Files:**
- Create: `services/api/src/routes/users.ts`, `services/api/test/users.test.ts`
- Modify: `services/api/src/repos/users.ts`, `services/api/src/db/database.ts`, `services/api/src/app.ts`, `services/api/test/contract.test.ts`

**Interfaces:**
- Consumes: `findProfile`, `profileQuery`, `PublicProfile` (Task 4); `principalOf`, `requireSelf` (Task 4); `operation`, `ApiError`, `iso` (Task 3).
- Produces:
  - `isForeignKeyViolation(e: unknown): boolean` (`database.ts`).
  - `updateDisplayName(db, id, displayName): Promise<PublicProfile | null>`; `setRole(db, id, role: UserRole): Promise<PublicProfile | null>` (first `photographer` inserts `photographers(user_id)`, later calls keep that row); `interface UserContactDto { phone: string; phoneVerified: boolean; allowZalo: boolean; allowWhatsApp: boolean; updatedAt: string }`; `contactQuery(db, userId)`; `findContact(db, userId): Promise<UserContactDto | null>`; `saveContact(db, userId, input: { phone: string; allowZalo: boolean; allowWhatsApp: boolean }): Promise<UserContactDto>` (keeps `phone_verified` only when the number is unchanged; `not_found` when the user row is missing).
  - Routes `getUser` (U), `updateUser` (S), `setRole` (S), `getUserContact` (S, `Cache-Control: no-store`), `saveUserContact` (S, `no-store`).

- [ ] **Step 1: Write the failing test**

```ts
// services/api/test/users.test.ts
import type { FastifyInstance, HTTPMethods } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { bearer, resetDb, testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const OWNER = 'u_owner';
const OTHER = 'u_other';
const CONTACT = { phone: '+84903123456', allowZalo: true, allowWhatsApp: false };

type Actor = 'anon' | 'owner' | 'other';
const headersFor = async (a: Actor): Promise<Record<string, string>> =>
  a === 'anon' ? {} : bearer(a === 'owner' ? OWNER : OTHER);

async function call(actor: Actor, method: HTTPMethods, url: string, payload?: object) {
  return app.inject({ method, url, headers: await headersFor(actor), ...(payload ? { payload } : {}) });
}

beforeEach(async () => {
  await resetDb(db);
  for (const uid of [OWNER, OTHER]) {
    await app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(uid), payload: { displayName: uid } });
  }
  await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, CONTACT);
});

const MATRIX: Array<{ op: string; method: HTTPMethods; url: string; payload?: object; expect: Record<Actor, number> }> = [
  { op: 'getUser', method: 'GET', url: `/v1/users/${OWNER}`, expect: { anon: 401, owner: 200, other: 200 } },
  { op: 'updateUser', method: 'PATCH', url: `/v1/users/${OWNER}`, payload: { displayName: 'Minh' }, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'setRole', method: 'PUT', url: `/v1/users/${OWNER}/role`, payload: { role: 'customer' }, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'getUserContact', method: 'GET', url: `/v1/users/${OWNER}/contact`, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'saveUserContact', method: 'PUT', url: `/v1/users/${OWNER}/contact`, payload: CONTACT, expect: { anon: 401, owner: 200, other: 403 } },
];

describe('authorization matrix (data-model README §4: users U read / S write, user_contacts S / S)', () => {
  for (const row of MATRIX) {
    for (const actor of ['anon', 'owner', 'other'] as const) {
      it(`${row.op} as ${actor} → ${row.expect[actor]}`, async () => {
        const res = await call(actor, row.method, row.url, row.payload);
        expect(res.statusCode).toBe(row.expect[actor]);
      });
    }
  }
});

describe('profile and contact behaviour', () => {
  it('the public profile never carries a phone number', async () => {
    const res = await call('other', 'GET', `/v1/users/${OWNER}`);
    expect(res.json()).toEqual({ id: OWNER, displayName: OWNER, role: null, avatarUrl: null });
    expect(res.body).not.toMatch(/phone|\+?84\d{9}/i);
  });

  it('a changed number becomes unverified; a toggle keeps verification', async () => {
    await db.updateTable('user_contacts').set({ phone_verified: true }).where('user_id', '=', OWNER).execute();
    const toggle = await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, allowWhatsApp: true });
    expect(toggle.json()).toMatchObject({ phone: '+84903123456', phoneVerified: true, allowWhatsApp: true });
    const changed = await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, phone: '+84912345678' });
    expect(changed.json()).toMatchObject({ phone: '+84912345678', phoneVerified: false });
    expect(Date.parse(changed.json().updatedAt)).not.toBeNaN();
  });

  it('only Vietnamese E.164 numbers are accepted', async () => {
    for (const phone of ['0903123456', '+8490312345', '+84123456789', '+14155552671']) {
      const res = await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, phone });
      expect(res.statusCode, phone).toBe(400);
    }
  });

  it('a client cannot set phoneVerified or staffRole', async () => {
    expect((await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, phoneVerified: true })).statusCode).toBe(400);
    expect((await call('owner', 'PATCH', `/v1/users/${OWNER}`, { displayName: 'Minh', staffRole: 'admin' })).statusCode).toBe(400);
  });

  it('a user without a profile row gets not_found for its contact', async () => {
    const res = await app.inject({ method: 'PUT', url: '/v1/users/u_new/contact', headers: await bearer('u_new'), payload: CONTACT });
    expect(res.statusCode).toBe(404);
    expect(res.json().code).toBe('not_found');
    const get = await app.inject({ method: 'GET', url: '/v1/users/u_new/contact', headers: await bearer('u_new') });
    expect(get.statusCode).toBe(404);
  });

  it('setRole(photographer) creates the photographer row once and keeps its progress', async () => {
    const res = await call('owner', 'PUT', `/v1/users/${OWNER}/role`, { role: 'photographer' });
    expect(res.json().role).toBe('photographer');
    await db.updateTable('photographers').set({ onboarding_complete: true }).where('user_id', '=', OWNER).execute();
    await call('owner', 'PUT', `/v1/users/${OWNER}/role`, { role: 'customer' });
    await call('owner', 'PUT', `/v1/users/${OWNER}/role`, { role: 'photographer' });
    const row = await db.selectFrom('photographers').select('onboarding_complete').where('user_id', '=', OWNER).executeTakeFirstOrThrow();
    expect(row.onboarding_complete).toBe(true);
  });

  it('private contact responses are not cacheable', async () => {
    const res = await call('owner', 'GET', `/v1/users/${OWNER}/contact`);
    expect(res.headers['cache-control']).toBe('no-store');
  });

  it('an unknown user is not_found', async () => {
    const res = await call('owner', 'GET', '/v1/users/nobody');
    expect(res.statusCode).toBe(404);
  });
});
```

In `services/api/test/contract.test.ts` remove `'getUser', 'updateUser', 'setRole', 'getUserContact', 'saveUserContact', ` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/users.test.ts`
Expected: FAIL, most cases get `404` (routes missing), e.g. `getUser as owner → 200: expected 404 to be 200`.

- [ ] **Step 3: Implement**

Append to `services/api/src/db/database.ts`:

```ts
/** Postgres foreign_key_violation (SQLSTATE 23503). */
export function isForeignKeyViolation(e: unknown): boolean {
  return typeof e === 'object' && e !== null && (e as { code?: unknown }).code === '23503';
}
```

Append to `services/api/src/repos/users.ts` (and add `import { sql } from 'kysely';` next to the Kysely type import, `import { isForeignKeyViolation } from '../db/database.js';` and `import { iso } from '../wire.js';`):

```ts
export async function updateDisplayName(db: Kysely<Database>, id: string, displayName: string): Promise<PublicProfile | null> {
  const r = await db
    .updateTable('users')
    .set({ display_name: displayName })
    .where('id', '=', id)
    .where('deleted_at', 'is', null)
    .returning('id')
    .executeTakeFirst();
  return r ? findProfile(db, id) : null;
}

/** Use case set_role. The first switch to photographer creates the photographer row. */
export async function setRole(db: Kysely<Database>, id: string, role: UserRole): Promise<PublicProfile | null> {
  return db.transaction().execute(async (trx) => {
    const r = await trx
      .updateTable('users')
      .set({ role })
      .where('id', '=', id)
      .where('deleted_at', 'is', null)
      .returning('id')
      .executeTakeFirst();
    if (!r) return null;
    if (role === 'photographer') {
      await trx.insertInto('photographers').values({ user_id: id }).onConflict((oc) => oc.column('user_id').doNothing()).execute();
    }
    return findProfile(trx, id);
  });
}

export interface UserContactDto {
  phone: string;
  phoneVerified: boolean;
  allowZalo: boolean;
  allowWhatsApp: boolean;
  updatedAt: string;
}

export const contactQuery = (db: Kysely<Database>, userId: string) =>
  db
    .selectFrom('user_contacts')
    .select(['phone_e164', 'phone_verified', 'allow_zalo', 'allow_whatsapp', 'updated_at'])
    .where('user_id', '=', userId);

const toContact = (r: {
  phone_e164: string;
  phone_verified: boolean;
  allow_zalo: boolean;
  allow_whatsapp: boolean;
  updated_at: Date;
}): UserContactDto => ({
  phone: r.phone_e164,
  phoneVerified: r.phone_verified,
  allowZalo: r.allow_zalo,
  allowWhatsApp: r.allow_whatsapp,
  updatedAt: iso(r.updated_at),
});

export async function findContact(db: Kysely<Database>, userId: string): Promise<UserContactDto | null> {
  const r = await contactQuery(db, userId).executeTakeFirst();
  return r ? toContact(r) : null;
}

/** One statement: a changed number is unverified, a toggle keeps the server's flag. */
export async function saveContact(
  db: Kysely<Database>,
  userId: string,
  input: { phone: string; allowZalo: boolean; allowWhatsApp: boolean },
): Promise<UserContactDto> {
  try {
    const r = await db
      .insertInto('user_contacts')
      .values({
        user_id: userId,
        phone_e164: input.phone,
        phone_verified: false,
        allow_zalo: input.allowZalo,
        allow_whatsapp: input.allowWhatsApp,
      })
      .onConflict((oc) =>
        oc.column('user_id').doUpdateSet((eb) => ({
          phone_e164: eb.ref('excluded.phone_e164'),
          allow_zalo: eb.ref('excluded.allow_zalo'),
          allow_whatsapp: eb.ref('excluded.allow_whatsapp'),
          phone_verified: sql<boolean>`case when user_contacts.phone_e164 = excluded.phone_e164
            then user_contacts.phone_verified else false end`,
        })),
      )
      .returning(['phone_e164', 'phone_verified', 'allow_zalo', 'allow_whatsapp', 'updated_at'])
      .executeTakeFirstOrThrow();
    return toContact(r);
  } catch (e) {
    if (isForeignKeyViolation(e)) throw new ApiError('not_found', 'create the profile first (POST /v1/me)');
    throw e;
  }
}
```

```ts
// services/api/src/routes/users.ts
import type { FastifyInstance } from 'fastify';

import { principalOf, requireSelf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import { ApiError } from '../errors.js';
import type { components } from '../generated/api.js';
import { findContact, findProfile, saveContact, setRole, updateDisplayName } from '../repos/users.js';

type S = components['schemas'];
interface UserParams {
  userId: string;
}

const missingProfile = () => new ApiError('not_found', 'create the profile first (POST /v1/me)');

export function registerUserRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Params: UserParams }>({
    ...operation(deps.contract, 'getUser'),
    handler: async (req) => {
      principalOf(req);
      const profile = await findProfile(deps.db, req.params.userId);
      if (!profile) throw new ApiError('not_found', 'no such user');
      return profile;
    },
  });

  app.route<{ Params: UserParams; Body: S['UpdateUserRequest'] }>({
    ...operation(deps.contract, 'updateUser'),
    handler: async (req) => {
      requireSelf(req, req.params.userId);
      const profile = await updateDisplayName(deps.db, req.params.userId, req.body.displayName);
      if (!profile) throw missingProfile();
      return profile;
    },
  });

  app.route<{ Params: UserParams; Body: S['SetRoleRequest'] }>({
    ...operation(deps.contract, 'setRole'),
    handler: async (req) => {
      requireSelf(req, req.params.userId);
      const profile = await setRole(deps.db, req.params.userId, req.body.role);
      if (!profile) throw missingProfile();
      return profile;
    },
  });

  app.route<{ Params: UserParams }>({
    ...operation(deps.contract, 'getUserContact'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.userId);
      reply.header('cache-control', 'no-store');
      const contact = await findContact(deps.db, req.params.userId);
      if (!contact) throw new ApiError('not_found', 'no contact saved yet');
      return contact;
    },
  });

  app.route<{ Params: UserParams; Body: S['SaveUserContactRequest'] }>({
    ...operation(deps.contract, 'saveUserContact'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.userId);
      reply.header('cache-control', 'no-store');
      return saveContact(deps.db, req.params.userId, req.body);
    },
  });
}
```

In `services/api/src/app.ts` add `import { registerUserRoutes } from './routes/users.js';` and, after `registerMeRoutes(app, routeDeps);`, `registerUserRoutes(app, routeDeps);`.

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean; `Tests  72 passed (72)` (49 + matrix 15 + behaviour 8).

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat(api): public profile, set_role and owner-only private contact with authorization matrix tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Photographer contact channels, numbers, service area and contact setup

**Files:**
- Create: `services/api/src/repos/photographers.ts`, `services/api/src/routes/photographers.ts`, `services/api/test/photographers.test.ts`
- Modify: `services/api/src/app.ts`, `services/api/test/contract.test.ts`

**Interfaces:**
- Consumes: `requireSelf`, `principalOf` (Task 4); `ApiError`, `operation` (Task 3).
- Produces:
  - `interface ChannelsDto { call: boolean; zalo: boolean; whatsapp: boolean; acceptInquiries: boolean }`, `interface NumbersDto { phone: string; zaloPhone: string | null; whatsappPhone: string | null }`, `interface AreaDto { city: string; radiusKm: number }`.
  - `channelsQuery(db, id)`, `findChannels(db, id): Promise<ChannelsDto | null>` (`acceptInquiries` = `photographers.accepts_inquiries`); `numbersQuery(db, id)`, `findNumbers(db, id): Promise<NumbersDto | null>`; `serviceAreaQuery(db, id)`, `findServiceArea(db, id): Promise<{ area: AreaDto; onboardingComplete: boolean } | null>`.
  - `completeContactSetup(db, uid, input: { area: AreaDto; channels: ChannelsDto; numbers: { phone: string; zaloPhone?: string | null; whatsappPhone?: string | null } }): Promise<void>` (one transaction; `permission_denied` unless `users.role = 'photographer'`; `not_found` without a profile; numbers row replaced entirely).
  - Routes `getContactChannels` (U), `getContactNumbers` (S, `no-store`), `getServiceArea` (U when `onboarding_complete`, S always, otherwise `not_found`), `completeContactSetup` (S, 204).

- [ ] **Step 1: Write the failing test**

```ts
// services/api/test/photographers.test.ts
import type { FastifyInstance, HTTPMethods } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { bearer, resetDb, testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const OWNER = 'p_owner';
const OTHER = 'u_other';
const SETUP = {
  area: { city: 'Hà Nội', radiusKm: 20 },
  channels: { call: true, zalo: true, whatsapp: false, acceptInquiries: true },
  numbers: { phone: '+84903123456', zaloPhone: '+84912345678' },
};

type Actor = 'anon' | 'owner' | 'other';
const headersFor = async (a: Actor): Promise<Record<string, string>> =>
  a === 'anon' ? {} : bearer(a === 'owner' ? OWNER : OTHER);
async function call(actor: Actor, method: HTTPMethods, url: string, payload?: object) {
  return app.inject({ method, url, headers: await headersFor(actor), ...(payload ? { payload } : {}) });
}
const base = `/v1/photographers/${OWNER}`;

async function photographer(uid: string): Promise<void> {
  await app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(uid), payload: { displayName: uid } });
  await app.inject({ method: 'PUT', url: `/v1/users/${uid}/role`, headers: await bearer(uid), payload: { role: 'photographer' } });
}

beforeEach(async () => {
  await resetDb(db);
  await photographer(OWNER);
  await app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(OTHER), payload: { displayName: OTHER } });
  await call('owner', 'PUT', `${base}/contact-setup`, SETUP);
});

const MATRIX: Array<{ op: string; method: HTTPMethods; url: string; payload?: object; expect: Record<Actor, number> }> = [
  { op: 'getContactChannels', method: 'GET', url: `${base}/contact-channels`, expect: { anon: 401, owner: 200, other: 200 } },
  { op: 'getContactNumbers', method: 'GET', url: `${base}/contact-numbers`, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'getServiceArea', method: 'GET', url: `${base}/service-area`, expect: { anon: 401, owner: 200, other: 200 } },
  { op: 'completeContactSetup', method: 'PUT', url: `${base}/contact-setup`, payload: SETUP, expect: { anon: 401, owner: 204, other: 403 } },
];

describe('authorization matrix (README §4: channels U / S, numbers S / S, photographers U if onboarded)', () => {
  for (const row of MATRIX) {
    for (const actor of ['anon', 'owner', 'other'] as const) {
      it(`${row.op} as ${actor} → ${row.expect[actor]}`, async () => {
        expect((await call(actor, row.method, row.url, row.payload)).statusCode).toBe(row.expect[actor]);
      });
    }
  }
});

describe('contact setup (S34)', () => {
  it('stores area, flags and numbers and completes onboarding', async () => {
    expect((await call('other', 'GET', `${base}/contact-channels`)).json()).toEqual(SETUP.channels);
    expect((await call('owner', 'GET', `${base}/contact-numbers`)).json()).toEqual({ phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: null });
    expect((await call('other', 'GET', `${base}/service-area`)).json()).toEqual(SETUP.area);
    const row = await db.selectFrom('photographers').select(['onboarding_complete', 'accepts_inquiries']).where('user_id', '=', OWNER).executeTakeFirstOrThrow();
    expect(row).toEqual({ onboarding_complete: true, accepts_inquiries: true });
  });

  it('public flags carry no number', async () => {
    const res = await call('other', 'GET', `${base}/contact-channels`);
    expect(res.body).not.toMatch(/phone|\+?84\d{9}/i);
  });

  it('saving again without an own Zalo number clears it', async () => {
    await call('owner', 'PUT', `${base}/contact-setup`, { ...SETUP, numbers: { phone: '+84903123456' } });
    expect((await call('owner', 'GET', `${base}/contact-numbers`)).json().zaloPhone).toBeNull();
  });

  it('only photographers can set contact channels', async () => {
    const res = await call('other', 'PUT', `/v1/photographers/${OTHER}/contact-setup`, SETUP);
    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('permission_denied');
    const none = await app.inject({ method: 'PUT', url: '/v1/photographers/p_new/contact-setup', headers: await bearer('p_new'), payload: SETUP });
    expect(none.statusCode).toBe(404);
  });

  it('the contract rejects a foreign Zalo number, a malformed WhatsApp number, a bad radius or city', async () => {
    const bad = [
      { ...SETUP, numbers: { phone: '+84903123456', zaloPhone: '+14155552671' } },
      { ...SETUP, numbers: { phone: '+84903123456', whatsappPhone: '14155552671' } },
      { ...SETUP, area: { city: 'Hà Nội', radiusKm: 0 } },
      { ...SETUP, area: { city: 'H', radiusKm: 20 } },
      { ...SETUP, channels: { ...SETUP.channels, sms: true } },
    ];
    for (const payload of bad) expect((await call('owner', 'PUT', `${base}/contact-setup`, payload)).statusCode).toBe(400);
  });

  it('before setup everything is not_found', async () => {
    await photographer('p_fresh');
    const h = await bearer('p_fresh');
    for (const path of ['contact-channels', 'contact-numbers', 'service-area']) {
      const res = await app.inject({ method: 'GET', url: `/v1/photographers/p_fresh/${path}`, headers: h });
      expect(res.statusCode, path).toBe(404);
    }
  });

  it('an unfinished profile hides its area from others but not from its owner', async () => {
    await db.updateTable('photographers').set({ onboarding_complete: false }).where('user_id', '=', OWNER).execute();
    expect((await call('owner', 'GET', `${base}/service-area`)).statusCode).toBe(200);
    expect((await call('other', 'GET', `${base}/service-area`)).statusCode).toBe(404);
  });

  it('numbers are not cacheable', async () => {
    expect((await call('owner', 'GET', `${base}/contact-numbers`)).headers['cache-control']).toBe('no-store');
  });
});
```

In `services/api/test/contract.test.ts` remove `'getContactChannels', 'getContactNumbers', 'getServiceArea', 'completeContactSetup', ` from `PENDING`.

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/photographers.test.ts`
Expected: FAIL, e.g. `getContactChannels as owner → 200: expected 404 to be 200`.

- [ ] **Step 3: Implement**

```ts
// services/api/src/repos/photographers.ts
import type { Kysely } from 'kysely';

import type { Database } from '../db/database.js';
import { ApiError } from '../errors.js';

export interface ChannelsDto {
  call: boolean;
  zalo: boolean;
  whatsapp: boolean;
  acceptInquiries: boolean;
}

export interface NumbersDto {
  phone: string;
  zaloPhone: string | null;
  whatsappPhone: string | null;
}

export interface AreaDto {
  city: string;
  radiusKm: number;
}

export const channelsQuery = (db: Kysely<Database>, id: string) =>
  db
    .selectFrom('photographer_contact_channels as c')
    .innerJoin('photographers as p', 'p.user_id', 'c.photographer_id')
    .select(['c.call_enabled', 'c.zalo_enabled', 'c.whatsapp_enabled', 'p.accepts_inquiries'])
    .where('c.photographer_id', '=', id);

export async function findChannels(db: Kysely<Database>, id: string): Promise<ChannelsDto | null> {
  const r = await channelsQuery(db, id).executeTakeFirst();
  return r
    ? { call: r.call_enabled, zalo: r.zalo_enabled, whatsapp: r.whatsapp_enabled, acceptInquiries: r.accepts_inquiries }
    : null;
}

export const numbersQuery = (db: Kysely<Database>, id: string) =>
  db
    .selectFrom('photographer_contact_numbers')
    .select(['phone_e164', 'zalo_phone_e164', 'whatsapp_phone_e164'])
    .where('photographer_id', '=', id);

export async function findNumbers(db: Kysely<Database>, id: string): Promise<NumbersDto | null> {
  const r = await numbersQuery(db, id).executeTakeFirst();
  return r ? { phone: r.phone_e164, zaloPhone: r.zalo_phone_e164, whatsappPhone: r.whatsapp_phone_e164 } : null;
}

export const serviceAreaQuery = (db: Kysely<Database>, id: string) =>
  db.selectFrom('photographers').select(['service_city', 'service_radius_km', 'onboarding_complete']).where('user_id', '=', id);

export async function findServiceArea(
  db: Kysely<Database>,
  id: string,
): Promise<{ area: AreaDto; onboardingComplete: boolean } | null> {
  const r = await serviceAreaQuery(db, id).executeTakeFirst();
  if (!r || r.service_city === null || r.service_radius_km === null) return null;
  return { area: { city: r.service_city, radiusKm: r.service_radius_km }, onboardingComplete: r.onboarding_complete };
}

/** S34 "Hoàn tất": area, public flags and private numbers in one transaction, then onboarding done. */
export async function completeContactSetup(
  db: Kysely<Database>,
  uid: string,
  input: {
    area: AreaDto;
    channels: ChannelsDto;
    numbers: { phone: string; zaloPhone?: string | null; whatsappPhone?: string | null };
  },
): Promise<void> {
  await db.transaction().execute(async (trx) => {
    const user = await trx
      .selectFrom('users')
      .select('role')
      .where('id', '=', uid)
      .where('deleted_at', 'is', null)
      .executeTakeFirst();
    if (!user) throw new ApiError('not_found', 'create the profile first (POST /v1/me)');
    if (user.role !== 'photographer') throw new ApiError('permission_denied', 'only photographers set contact channels');

    await trx
      .insertInto('photographers')
      .values({
        user_id: uid,
        service_city: input.area.city,
        service_radius_km: input.area.radiusKm,
        accepts_inquiries: input.channels.acceptInquiries,
        onboarding_complete: true,
      })
      .onConflict((oc) =>
        oc.column('user_id').doUpdateSet((eb) => ({
          service_city: eb.ref('excluded.service_city'),
          service_radius_km: eb.ref('excluded.service_radius_km'),
          accepts_inquiries: eb.ref('excluded.accepts_inquiries'),
          onboarding_complete: true,
        })),
      )
      .execute();

    await trx
      .insertInto('photographer_contact_channels')
      .values({
        photographer_id: uid,
        call_enabled: input.channels.call,
        zalo_enabled: input.channels.zalo,
        whatsapp_enabled: input.channels.whatsapp,
      })
      .onConflict((oc) =>
        oc.column('photographer_id').doUpdateSet((eb) => ({
          call_enabled: eb.ref('excluded.call_enabled'),
          zalo_enabled: eb.ref('excluded.zalo_enabled'),
          whatsapp_enabled: eb.ref('excluded.whatsapp_enabled'),
        })),
      )
      .execute();

    // The whole row is replaced, so a cleared own number really goes away.
    await trx
      .insertInto('photographer_contact_numbers')
      .values({
        photographer_id: uid,
        phone_e164: input.numbers.phone,
        zalo_phone_e164: input.numbers.zaloPhone ?? null,
        whatsapp_phone_e164: input.numbers.whatsappPhone ?? null,
      })
      .onConflict((oc) =>
        oc.column('photographer_id').doUpdateSet((eb) => ({
          phone_e164: eb.ref('excluded.phone_e164'),
          zalo_phone_e164: eb.ref('excluded.zalo_phone_e164'),
          whatsapp_phone_e164: eb.ref('excluded.whatsapp_phone_e164'),
        })),
      )
      .execute();
  });
}
```

```ts
// services/api/src/routes/photographers.ts
import type { FastifyInstance } from 'fastify';

import { principalOf, requireSelf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import { ApiError } from '../errors.js';
import type { components } from '../generated/api.js';
import { completeContactSetup, findChannels, findNumbers, findServiceArea } from '../repos/photographers.js';

type S = components['schemas'];
interface PhotographerParams {
  photographerId: string;
}

export function registerPhotographerRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Params: PhotographerParams }>({
    ...operation(deps.contract, 'getContactChannels'),
    handler: async (req) => {
      principalOf(req);
      const channels = await findChannels(deps.db, req.params.photographerId);
      if (!channels) throw new ApiError('not_found', 'contact channels are not set up');
      return channels;
    },
  });

  app.route<{ Params: PhotographerParams }>({
    ...operation(deps.contract, 'getContactNumbers'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.photographerId);
      reply.header('cache-control', 'no-store');
      const numbers = await findNumbers(deps.db, req.params.photographerId);
      if (!numbers) throw new ApiError('not_found', 'contact numbers are not set up');
      return numbers;
    },
  });

  app.route<{ Params: PhotographerParams }>({
    ...operation(deps.contract, 'getServiceArea'),
    handler: async (req) => {
      const p = principalOf(req);
      const found = await findServiceArea(deps.db, req.params.photographerId);
      // Others see a photographer only once onboarding is complete (README §4).
      if (!found || (!found.onboardingComplete && p.uid !== req.params.photographerId)) {
        throw new ApiError('not_found', 'service area is not set up');
      }
      return found.area;
    },
  });

  app.route<{ Params: PhotographerParams; Body: S['ContactSetupRequest'] }>({
    ...operation(deps.contract, 'completeContactSetup'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.photographerId);
      await completeContactSetup(deps.db, req.params.photographerId, req.body);
      return reply.status(204).send();
    },
  });
}
```

In `services/api/src/app.ts` add `import { registerPhotographerRoutes } from './routes/photographers.js';` and, after `registerUserRoutes(app, routeDeps);`, `registerPhotographerRoutes(app, routeDeps);`.

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean; `Tests  92 passed (92)` (72 + matrix 12 + setup 8).

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat(api): photographer contact channels, private numbers, service area and S34 setup

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `get_contact_link` with `ContactAccessLog`, and the shared contract world

**Files:**
- Create: `services/api/src/use-cases/get-contact-link.ts`, `services/api/src/repos/contact-links.ts`, `services/api/src/routes/contact-links.ts`, `services/api/src/tools/contract-world.ts`, `services/api/src/tools/seed-contract.ts`, `services/api/test/fixtures/contract-world.json`, `services/api/test/contact-links.test.ts`
- Modify: `services/api/src/app.ts`, `services/api/package.json`, `services/api/test/contract.test.ts`

**Interfaces:**
- Consumes: `contactUnlocked`, `contactUrl`, `ExternalChannel` (shim, Task 3); `principalOf` (Task 4); `isForeignKeyViolation` (Task 5); `newId` (Task 3).
- Produces:
  - `interface ContactLinkRow { customer_id: string; status: BookingStatus; completed_at: Date | null; call_enabled: boolean | null; zalo_enabled: boolean | null; whatsapp_enabled: boolean | null; phone_e164: string | null; zalo_phone_e164: string | null; whatsapp_phone_e164: string | null }`.
  - `decideContactLink(row: ContactLinkRow | undefined, requesterId: string, channel: ExternalChannel, now: Date): string` — the URL, or throws `not_found` (no booking / channel off / no number), `permission_denied` (not the booking's customer), `contact_locked` (not unlocked). Checks run in this order, matching plan 2b's fake.
  - `bookingContactQuery(db, bookingId)` (one statement: booking, latest `completed` event, channels, numbers); `logContactAccess(db, { requesterId, subjectType: 'booking' | 'event_registration', subjectId, channel, granted, at }): Promise<void>` (skips silently when the requester has no `users` row).
  - Route `getContactLink`: request `{ bookingId | registrationId, channel }`, response `{ url }`, `Cache-Control: no-store`, exactly one `contact_access_log` row per answered request; `registrationId` → `not_found` until the events plan.
  - `contractWorld: ContractWorld`, `seedContractWorld(db, now, world?)` (idempotent); CLI `node dist/tools/seed-contract.js` / `npm run seed:contract`.
  - `test/fixtures/contract-world.json`: users `ctr_customer`, `ctr_other`; photographers `ctr_photographer` (all channels, own Zalo/WhatsApp numbers) and `ctr_photographer_zalo` (Zalo only); nine bookings with `unlocked` stated per booking (read by the Flutter contract tests of Task 9 and by k6 in Task 11).

- [ ] **Step 1: Write the failing test**

```json
{
  "comment": "Shared fixture world: services/api tests, Flutter contract tests (Task 9) and k6 (Task 11). Bookings belong to `customer`; `unlocked` states the expected rule of domain-model.md §5 at seed time; completedDaysAgo is relative to the seed time.",
  "customer": "ctr_customer",
  "otherCustomer": "ctr_other",
  "photographers": {
    "ctr_photographer": {
      "numbers": { "phone": "+84903123456", "zaloPhone": "+84912345678", "whatsappPhone": "+14155552671" },
      "channels": { "call": true, "zalo": true, "whatsapp": true, "acceptInquiries": true }
    },
    "ctr_photographer_zalo": {
      "numbers": { "phone": "+84987654321" },
      "channels": { "call": false, "zalo": true, "whatsapp": false, "acceptInquiries": true }
    }
  },
  "bookings": [
    { "id": "ctr_b_requested", "photographerId": "ctr_photographer", "status": "requested", "day": "2026-11-02", "completedDaysAgo": null, "unlocked": true },
    { "id": "ctr_b_accepted", "photographerId": "ctr_photographer", "status": "accepted", "day": "2026-11-03", "completedDaysAgo": null, "unlocked": true },
    { "id": "ctr_b_upcoming", "photographerId": "ctr_photographer", "status": "upcoming", "day": "2026-11-04", "completedDaysAgo": null, "unlocked": true },
    { "id": "ctr_b_draft", "photographerId": "ctr_photographer", "status": "draft", "day": "2026-11-05", "completedDaysAgo": null, "unlocked": false },
    { "id": "ctr_b_declined", "photographerId": "ctr_photographer", "status": "declined", "day": "2026-11-06", "completedDaysAgo": null, "unlocked": false },
    { "id": "ctr_b_cancelled", "photographerId": "ctr_photographer", "status": "cancelled", "day": "2026-11-07", "completedDaysAgo": null, "unlocked": false },
    { "id": "ctr_b_completed_recent", "photographerId": "ctr_photographer", "status": "completed", "day": "2026-09-26", "completedDaysAgo": 5, "unlocked": true },
    { "id": "ctr_b_completed_old", "photographerId": "ctr_photographer", "status": "completed", "day": "2026-08-31", "completedDaysAgo": 31, "unlocked": false },
    { "id": "ctr_b_zalo_only", "photographerId": "ctr_photographer_zalo", "status": "accepted", "day": "2026-11-03", "completedDaysAgo": null, "unlocked": true }
  ]
}
```

Save the JSON above as `services/api/test/fixtures/contract-world.json`.

```ts
// services/api/test/contact-links.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { contractWorld, seedContractWorld, type WorldBooking } from '../src/tools/contract-world.js';
import { decideContactLink, type ContactLinkRow } from '../src/use-cases/get-contact-link.js';
import { ApiError } from '../src/errors.js';
import { bearer, resetDb, testApp, testDb } from './helpers.js';

const NOW = new Date('2026-10-01T12:00:00Z');
const db = testDb();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp({ db, clock: { now: () => NOW } });
  await resetDb(db);
  await seedContractWorld(db, NOW);
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const CHANNELS = ['call', 'zalo', 'whatsapp'] as const;
type Channel = (typeof CHANNELS)[number];

const link = async (uid: string, payload: object) =>
  app.inject({ method: 'POST', url: '/v1/contact-links', headers: await bearer(uid), payload });

/** Independent oracle of plan 2b's URL shapes and domain-model.md §5. */
function expected(b: WorldBooking, channel: Channel): { status: number; code?: string; url?: string } {
  const p = contractWorld.photographers[b.photographerId]!;
  if (!b.unlocked) return { status: 403, code: 'contact_locked' };
  if (!p.channels[channel]) return { status: 404, code: 'not_found' };
  const n =
    channel === 'call' ? p.numbers.phone : channel === 'zalo' ? (p.numbers.zaloPhone ?? p.numbers.phone) : (p.numbers.whatsappPhone ?? p.numbers.phone);
  const url = channel === 'call' ? `tel:${n}` : channel === 'zalo' ? `https://zalo.me/${n.slice(1)}` : `https://wa.me/${n.slice(1)}`;
  return { status: 200, url };
}

describe('get_contact_link over the contract world', () => {
  for (const b of contractWorld.bookings) {
    for (const channel of CHANNELS) {
      const want = expected(b, channel);
      it(`${b.id} ${channel} → ${want.url ?? want.code}`, async () => {
        const res = await link(contractWorld.customer, { bookingId: b.id, channel });
        expect(res.statusCode).toBe(want.status);
        if (want.url) expect(res.json()).toEqual({ url: want.url });
        else expect(res.json().code).toBe(want.code);
      });
    }
  }
});

describe('who may ask, and what is refused', () => {
  it('another customer is refused', async () => {
    const res = await link(contractWorld.otherCustomer, { bookingId: 'ctr_b_accepted', channel: 'call' });
    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('permission_denied');
  });

  it('the photographer cannot use the customer endpoint for its own booking', async () => {
    expect((await link('ctr_photographer', { bookingId: 'ctr_b_accepted', channel: 'call' })).json().code).toBe('permission_denied');
  });

  it('an unknown booking is not_found', async () => {
    expect((await link(contractWorld.customer, { bookingId: 'nope', channel: 'call' })).statusCode).toBe(404);
  });

  it('a registration is not served yet (events plan)', async () => {
    expect((await link(contractWorld.customer, { registrationId: 'r1', channel: 'call' })).json().code).toBe('not_found');
  });

  it('exactly one of bookingId and registrationId', async () => {
    expect((await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', registrationId: 'r1', channel: 'call' })).statusCode).toBe(400);
    expect((await link(contractWorld.customer, { channel: 'call' })).statusCode).toBe(400);
  });

  it('the in-app channel has no link', async () => {
    expect((await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', channel: 'in_app' })).statusCode).toBe(400);
  });

  it('needs a token', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/contact-links', payload: { bookingId: 'ctr_b_accepted', channel: 'call' } });
    expect(res.statusCode).toBe(401);
  });

  it('answers are not cacheable and a refusal never carries the number', async () => {
    const ok = await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', channel: 'zalo' });
    expect(ok.headers['cache-control']).toBe('no-store');
    const locked = await link(contractWorld.customer, { bookingId: 'ctr_b_declined', channel: 'call' });
    expect(locked.body).not.toMatch(/\d{9}/);
  });
});

describe('contact_access_log', () => {
  beforeEach(async () => {
    await resetDb(db);
    await seedContractWorld(db, NOW);
  });

  it('logs every decision once, granted or not, without any number', async () => {
    await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', channel: 'call' });
    await link(contractWorld.customer, { bookingId: 'ctr_b_declined', channel: 'zalo' });
    await link(contractWorld.customer, { bookingId: 'nope', channel: 'whatsapp' });
    const rows = await db
      .selectFrom('contact_access_log')
      .select(['requester_id', 'subject_type', 'subject_id', 'channel', 'granted', 'at'])
      .orderBy('id')
      .execute();
    expect(rows).toEqual([
      { requester_id: 'ctr_customer', subject_type: 'booking', subject_id: 'ctr_b_accepted', channel: 'call', granted: true, at: NOW },
      { requester_id: 'ctr_customer', subject_type: 'booking', subject_id: 'ctr_b_declined', channel: 'zalo', granted: false, at: NOW },
      { requester_id: 'ctr_customer', subject_type: 'booking', subject_id: 'nope', channel: 'whatsapp', granted: false, at: NOW },
    ]);
  });

  it('a caller without a profile is answered but not logged', async () => {
    expect((await link('ghost', { bookingId: 'ctr_b_accepted', channel: 'call' })).statusCode).toBe(403);
    expect(await db.selectFrom('contact_access_log').selectAll().execute()).toEqual([]);
  });

  it('seeding twice changes nothing', async () => {
    await seedContractWorld(db, NOW);
    const bookings = await db.selectFrom('bookings').select((eb) => eb.fn.countAll<number>().as('n')).executeTakeFirstOrThrow();
    const events = await db.selectFrom('booking_events').select((eb) => eb.fn.countAll<number>().as('n')).executeTakeFirstOrThrow();
    expect([bookings.n, events.n]).toEqual([9, 2]);
  });
});

describe('decideContactLink', () => {
  const row = (over: Partial<ContactLinkRow> = {}): ContactLinkRow => ({
    customer_id: 'c1', status: 'completed', completed_at: new Date(NOW.getTime() - 30 * 86_400_000),
    call_enabled: true, zalo_enabled: false, whatsapp_enabled: false,
    phone_e164: '+84903123456', zalo_phone_e164: null, whatsapp_phone_e164: null, ...over,
  });
  const code = (f: () => unknown) => {
    try {
      f();
    } catch (e) {
      return (e as ApiError).code;
    }
    return 'ok';
  };

  it('30 days after completion is still open, one second later is locked; off or missing number is not_found', () => {
    expect(decideContactLink(row(), 'c1', 'call', NOW)).toBe('tel:+84903123456');
    expect(code(() => decideContactLink(row({ completed_at: new Date(NOW.getTime() - 30 * 86_400_000 - 1000) }), 'c1', 'call', NOW))).toBe('contact_locked');
    expect(code(() => decideContactLink(row(), 'c1', 'zalo', NOW))).toBe('not_found');
    expect(code(() => decideContactLink(row({ phone_e164: null }), 'c1', 'call', NOW))).toBe('not_found');
    expect(code(() => decideContactLink(undefined, 'c1', 'call', NOW))).toBe('not_found');
    expect(code(() => decideContactLink(row(), 'c2', 'call', NOW))).toBe('permission_denied');
  });
});
```

In `services/api/test/contract.test.ts` replace the `PENDING` declaration with

```ts
/** Every operation is routed now; keep the set so a new contract operation must be listed until it lands. */
const PENDING = new Set<string>();
```

and add inside `describe('API contract', …)`:

```ts
  it('no operation is pending', () => {
    expect([...PENDING]).toEqual([]);
  });
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test -- test/contact-links.test.ts`
Expected: FAIL, `Cannot find module '../src/tools/contract-world.js'`.

- [ ] **Step 3: Implement**

```ts
// services/api/src/use-cases/get-contact-link.ts
import type { BookingStatus } from '../db/database.js';
import { contactUnlocked, contactUrl, type ExternalChannel } from '../domain/index.js';
import { ApiError } from '../errors.js';

/** What bookingContactQuery returns for one booking. */
export interface ContactLinkRow {
  customer_id: string;
  status: BookingStatus;
  completed_at: Date | null;
  call_enabled: boolean | null;
  zalo_enabled: boolean | null;
  whatsapp_enabled: boolean | null;
  phone_e164: string | null;
  zalo_phone_e164: string | null;
  whatsapp_phone_e164: string | null;
}

/**
 * Use case get_contact_link (data-model README §5, domain-model.md §5 "Mở khoá liên hệ").
 * Order: exists → caller is the customer → unlocked → channel on with a number.
 */
export function decideContactLink(
  row: ContactLinkRow | undefined,
  requesterId: string,
  channel: ExternalChannel,
  now: Date,
): string {
  if (!row) throw new ApiError('not_found', 'booking not found');
  if (row.customer_id !== requesterId) {
    throw new ApiError('permission_denied', 'only the customer of this booking can open its contact');
  }
  if (!contactUnlocked({ status: row.status, completedAt: row.completed_at }, now)) {
    throw new ApiError('contact_locked', 'contact opens once the booking is paid');
  }
  const enabled = channel === 'call' ? row.call_enabled : channel === 'zalo' ? row.zalo_enabled : row.whatsapp_enabled;
  if (enabled !== true || row.phone_e164 === null) throw new ApiError('not_found', 'this channel is not available');
  return contactUrl(channel, {
    phone: row.phone_e164,
    zaloPhone: row.zalo_phone_e164,
    whatsappPhone: row.whatsapp_phone_e164,
  });
}
```

```ts
// services/api/src/repos/contact-links.ts
import type { Kysely } from 'kysely';

import { isForeignKeyViolation, type ContactChannelCode, type Database } from '../db/database.js';
import { newId } from '../ids.js';

/** One round trip: booking, last completion instant, the photographer's flags and numbers. */
export const bookingContactQuery = (db: Kysely<Database>, bookingId: string) =>
  db
    .selectFrom('bookings as b')
    .leftJoin('photographer_contact_channels as c', 'c.photographer_id', 'b.photographer_id')
    .leftJoin('photographer_contact_numbers as n', 'n.photographer_id', 'b.photographer_id')
    .select((eb) => [
      'b.customer_id',
      'b.status',
      eb
        .selectFrom('booking_events as e')
        .select((e) => e.fn.max('e.at').as('at'))
        .whereRef('e.booking_id', '=', 'b.id')
        .where('e.status', '=', 'completed')
        .as('completed_at'),
      'c.call_enabled',
      'c.zalo_enabled',
      'c.whatsapp_enabled',
      'n.phone_e164',
      'n.zalo_phone_e164',
      'n.whatsapp_phone_e164',
    ])
    .where('b.id', '=', bookingId);

export interface ContactAccess {
  requesterId: string;
  subjectType: 'booking' | 'event_registration';
  subjectId: string;
  channel: ContactChannelCode;
  granted: boolean;
  at: Date;
}

/** ContactAccessLog (domain-model.md §2.7): who asked for which channel of what, and the answer. Never a number. */
export async function logContactAccess(db: Kysely<Database>, a: ContactAccess): Promise<void> {
  try {
    await db
      .insertInto('contact_access_log')
      .values({
        id: newId(a.at.getTime()),
        requester_id: a.requesterId,
        subject_type: a.subjectType,
        subject_id: a.subjectId,
        channel: a.channel,
        granted: a.granted,
        at: a.at,
      })
      .execute();
  } catch (e) {
    // A token whose uid has no users row (never called POST /v1/me) cannot own a booking: nothing to audit.
    if (!isForeignKeyViolation(e)) throw e;
  }
}
```

```ts
// services/api/src/routes/contact-links.ts
import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { ExternalChannel } from '../domain/index.js';
import { ApiError } from '../errors.js';
import { bookingContactQuery, logContactAccess } from '../repos/contact-links.js';
import { decideContactLink, type ContactLinkRow } from '../use-cases/get-contact-link.js';

interface ContactLinkBody {
  bookingId?: string;
  registrationId?: string;
  channel: ExternalChannel;
}

export function registerContactLinkRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Body: ContactLinkBody }>({
    ...operation(deps.contract, 'getContactLink'),
    handler: async (req, reply) => {
      const p = principalOf(req);
      reply.header('cache-control', 'no-store');
      const { channel } = req.body;
      const now = deps.clock.now();

      if (req.body.bookingId === undefined) {
        // The schema's oneOf guarantees registrationId here; event registrations arrive with the events plan.
        await logContactAccess(deps.db, {
          requesterId: p.uid, subjectType: 'event_registration', subjectId: req.body.registrationId ?? '',
          channel, granted: false, at: now,
        });
        throw new ApiError('not_found', 'event registrations are not served by this API yet');
      }

      const bookingId = req.body.bookingId;
      let granted = false;
      try {
        const row = (await bookingContactQuery(deps.db, bookingId).executeTakeFirst()) as ContactLinkRow | undefined;
        const url = decideContactLink(row, p.uid, channel, now);
        granted = true;
        return { url };
      } finally {
        await logContactAccess(deps.db, { requesterId: p.uid, subjectType: 'booking', subjectId: bookingId, channel, granted, at: now });
      }
    },
  });
}
```

```ts
// services/api/src/tools/contract-world.ts
import type { Kysely } from 'kysely';

import world from '../../test/fixtures/contract-world.json' with { type: 'json' };
import type { BookingStatus, Database } from '../db/database.js';

export interface WorldBooking {
  id: string;
  photographerId: string;
  status: BookingStatus;
  day: string;
  completedDaysAgo: number | null;
  unlocked: boolean;
}

export interface WorldPhotographer {
  numbers: { phone: string; zaloPhone?: string; whatsappPhone?: string };
  channels: { call: boolean; zalo: boolean; whatsapp: boolean; acceptInquiries: boolean };
}

export interface ContractWorld {
  customer: string;
  otherCustomer: string;
  photographers: Record<string, WorldPhotographer>;
  bookings: WorldBooking[];
}

export const contractWorld = world as ContractWorld;

const DAY_MS = 86_400_000;

/** Idempotent: upserts every row of the world; booking events are rebuilt per booking. */
export async function seedContractWorld(db: Kysely<Database>, now: Date, w: ContractWorld = contractWorld): Promise<void> {
  await db.transaction().execute(async (trx) => {
    const users = [
      { id: w.customer, display_name: 'Khách hợp đồng', role: 'customer' as const },
      { id: w.otherCustomer, display_name: 'Khách khác', role: 'customer' as const },
      ...Object.keys(w.photographers).map((id) => ({ id, display_name: `Thợ ảnh ${id}`, role: 'photographer' as const })),
    ];
    await trx
      .insertInto('users')
      .values(users)
      .onConflict((oc) =>
        oc.column('id').doUpdateSet((eb) => ({ display_name: eb.ref('excluded.display_name'), role: eb.ref('excluded.role'), deleted_at: null })),
      )
      .execute();

    for (const [id, p] of Object.entries(w.photographers)) {
      await trx
        .insertInto('photographers')
        .values({ user_id: id, onboarding_complete: true, accepts_inquiries: p.channels.acceptInquiries, service_city: 'Hà Nội', service_radius_km: 20 })
        .onConflict((oc) => oc.column('user_id').doUpdateSet({ onboarding_complete: true, accepts_inquiries: p.channels.acceptInquiries }))
        .execute();
      await trx
        .insertInto('photographer_contact_channels')
        .values({ photographer_id: id, call_enabled: p.channels.call, zalo_enabled: p.channels.zalo, whatsapp_enabled: p.channels.whatsapp })
        .onConflict((oc) =>
          oc.column('photographer_id').doUpdateSet({ call_enabled: p.channels.call, zalo_enabled: p.channels.zalo, whatsapp_enabled: p.channels.whatsapp }),
        )
        .execute();
      const numbers = {
        phone_e164: p.numbers.phone,
        zalo_phone_e164: p.numbers.zaloPhone ?? null,
        whatsapp_phone_e164: p.numbers.whatsappPhone ?? null,
      };
      await trx
        .insertInto('photographer_contact_numbers')
        .values({ photographer_id: id, ...numbers })
        .onConflict((oc) => oc.column('photographer_id').doUpdateSet(numbers))
        .execute();
      await trx
        .insertInto('services')
        .values({ id: `${id}_service`, photographer_id: id, name: 'Gói hợp đồng', duration_minutes: 120, price: 1_000_000 })
        .onConflict((oc) => oc.column('id').doNothing())
        .execute();
    }

    for (const b of w.bookings) {
      await trx
        .insertInto('bookings')
        .values({
          id: b.id, customer_id: w.customer, photographer_id: b.photographerId, service_id: `${b.photographerId}_service`,
          service_name: 'Gói hợp đồng', service_price: 1_000_000, service_duration_minutes: 120,
          day: b.day, start_time: '09:00', end_time: '11:00', status: b.status,
          deposit_amount: 300_000, remaining_amount: 700_000,
        })
        .onConflict((oc) => oc.column('id').doUpdateSet({ status: b.status, day: b.day, customer_id: w.customer }))
        .execute();
      await trx.deleteFrom('booking_events').where('booking_id', '=', b.id).execute();
      if (b.completedDaysAgo !== null) {
        await trx
          .insertInto('booking_events')
          .values({ id: `${b.id}_completed`, booking_id: b.id, status: 'completed', at: new Date(now.getTime() - b.completedDaysAgo * DAY_MS) })
          .execute();
      }
    }
  });
}
```

```ts
// services/api/src/tools/seed-contract.ts
import { createDb } from '../db/database.js';
import { seedContractWorld } from './contract-world.js';

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is required');
  process.exit(2);
}
if (process.env.NODE_ENV === 'production') {
  console.error('refusing to seed contract fixtures with NODE_ENV=production');
  process.exit(2);
}
const db = createDb(url, 1);
await seedContractWorld(db, new Date());
await db.destroy();
console.log('contract world seeded');
```

In `services/api/src/app.ts` add `import { registerContactLinkRoutes } from './routes/contact-links.js';` and, after `registerPhotographerRoutes(app, routeDeps);`, `registerContactLinkRoutes(app, routeDeps);`.

In `services/api/package.json` replace `build` and add `seed:contract`:

```json
    "build": "esbuild src/server.ts src/db/migrate-cli.ts src/tools/seed-contract.ts --bundle --platform=node --target=node22 --format=esm --packages=external --sourcemap --outdir=dist",
    "seed:contract": "tsx src/tools/seed-contract.ts",
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean; `Tests  132 passed (132)` (92 + world matrix 27 + refusals 8 + log 3 + decide 1 + contract "no operation is pending" 1), 0 failed.

Run the stack end to end:

```bash
npm run build
docker compose up --build -d
docker compose run --rm api node dist/tools/seed-contract.js
TOKEN=$(node -e "const e=o=>Buffer.from(JSON.stringify(o)).toString('base64url');const n=Math.floor(Date.now()/1e3);console.log(e({alg:'none',typ:'JWT'})+'.'+e({iss:'https://securetoken.google.com/demo-nag',aud:'demo-nag',sub:'ctr_customer',user_id:'ctr_customer',iat:n,auth_time:n,exp:n+3600,firebase:{sign_in_provider:'password',identities:{}}})+'.')")
curl -s -X POST localhost:8787/v1/contact-links -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d '{"bookingId":"ctr_b_accepted","channel":"zalo"}'
curl -s -X POST localhost:8787/v1/contact-links -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d '{"bookingId":"ctr_b_declined","channel":"zalo"}'
docker compose down
```

Expected: `contract world seeded`, then `{"url":"https://zalo.me/84912345678"}`, then `{"code":"contact_locked","message":"contact opens once the booking is paid","requestId":"req-…"}`.

- [ ] **Step 5: Commit**

```bash
git add services/api
git commit -m "feat(api): get_contact_link with contact access log and a shared contract world

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Flutter HTTP adapters behind the existing ports

**Files:**
- Create: `app_flutter/lib/data/backend_config.dart`, `app_flutter/lib/data/auth/id_token_source.dart`, `app_flutter/lib/data/http/api_client.dart`, `app_flutter/lib/data/http/local_watch.dart`, `app_flutter/lib/data/http/wire.dart`, `app_flutter/lib/data/http/api_providers.dart`, `app_flutter/lib/data/user/http_user_repository.dart`, `app_flutter/lib/data/user/http_user_contact_repository.dart`, `app_flutter/lib/data/photographer/http_photographer_contact_repository.dart`, `app_flutter/lib/data/contact/http_contact_link_repository.dart`, `app_flutter/test/data/backend_config_test.dart`, `app_flutter/test/data/http/mock_api.dart`, `app_flutter/test/data/http/api_client_test.dart`, `app_flutter/test/data/http/local_watch_test.dart`, `app_flutter/test/data/http/http_adapters_test.dart`, `app_flutter/test/data/http/provider_selection_test.dart`
- Modify: `app_flutter/pubspec.yaml`, `app_flutter/pubspec.lock`, `app_flutter/lib/data/auth/auth_providers.dart`, `app_flutter/lib/data/user/user_contact_providers.dart`, `app_flutter/lib/data/photographer/photographer_contact_providers.dart`, `app_flutter/lib/data/contact/contact_providers.dart`, `app_flutter/android/app/src/debug/AndroidManifest.xml`

**Interfaces:**
- Consumes: `UserRepository`, `UserProfile`, `UserRole`, `AuthUser`, `FirestoreUserRepository` (existing); plan 2a's `UserContact`, `UserContactRepository`, `FirestoreUserContactRepository`; plan 2b's `ContactChannels`, `ContactNumbers`, `ServiceArea`, `PhotographerContactRepository`, `FirestorePhotographerContactRepository`, `ContactSubject`, `ContactChannel`, `ContactLinkRepository`, `ContactLinkException`, `ContactLinkError`, `callableData`, `parseLinkResponse`, `linkErrorFromCode`, `FunctionsContactLinkRepository`; the contract of Task 3.
- Produces:
  - `enum Backend { firebase, selfhosted }`; `enum SelfhostedRepo { users, userContact, photographerContact, contactLink }` with `code`; `class BackendConfig { factory BackendConfig.parse({required String backend, String baseUrl = '', String repos = ''}); factory BackendConfig.fromEnvironment(); const BackendConfig.firebase(); final Backend backend; final Uri? baseUrl; final Set<SelfhostedRepo> repos; bool uses(SelfhostedRepo) }` (dart-defines `BACKEND`, `BASE_URL`, `SELFHOSTED_REPOS`; release builds require https).
  - `abstract class IdTokenSource { Future<String?> token({bool forceRefresh = false}); }`, `FirebaseIdTokenSource({FirebaseAuth? auth})`, `StaticIdTokenSource(String? value)`.
  - `class ApiException implements Exception { const ApiException(int status, String code); static const network, malformed, unauthenticated; }`; `class ApiClient({required Uri baseUrl, required IdTokenSource tokens, http.Client? client, Duration timeout}) { get, post, put, patch, close, uriFor }`; `String errorCodeOf(String body)`.
  - `Stream<T> fetchThenLocal<T>(Future<T> Function() fetch, Stream<T> local)`.
  - `wire.dart`: `ApiPaths`, `apiOperations`, `ensureProfileBody`, `updateUserBody`, `setRoleBody`, `profileFromJson`, `userContactFromJson`, `saveContactBody`, `channelsFromJson`, `numbersFromJson`, `areaFromJson`, `contactSetupBody`.
  - `HttpUserRepository({required ApiClient api})`, `HttpUserContactRepository({required ApiClient api})`, `HttpPhotographerContactRepository({required ApiClient api})`, `HttpContactLinkRepository({required ApiClient api})`, each with `dispose()` where it holds a stream controller.
  - `backendConfigProvider`, `idTokenSourceProvider`, `apiClientProvider`; the four repository providers pick the HTTP adapter when `config.uses(...)`.

- [ ] **Step 1: Add the dependency**

```bash
flutter pub add http
grep -n "^  http:" pubspec.yaml
```

Expected: one line `  http: ^1.x.y` under `dependencies:` (pub picks the version that resolves with the current lock).

- [ ] **Step 2: Write the failing tests**

```dart
// test/data/backend_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/backend_config.dart';

void main() {
  test('the default is Firebase for everything', () {
    final c = BackendConfig.parse(backend: 'firebase');
    expect(c.backend, Backend.firebase);
    for (final r in SelfhostedRepo.values) {
      expect(c.uses(r), isFalse);
    }
  });

  test('selfhosted with a base URL moves the whole slice', () {
    final c = BackendConfig.parse(backend: 'selfhosted', baseUrl: 'http://10.0.2.2:8787');
    expect(c.baseUrl, Uri.parse('http://10.0.2.2:8787'));
    for (final r in SelfhostedRepo.values) {
      expect(c.uses(r), isTrue);
    }
  });

  test('SELFHOSTED_REPOS moves only the listed repositories', () {
    final c = BackendConfig.parse(
      backend: 'selfhosted',
      baseUrl: 'https://api.example.vn',
      repos: 'userContact, contactLink',
    );
    expect(c.uses(SelfhostedRepo.userContact), isTrue);
    expect(c.uses(SelfhostedRepo.contactLink), isTrue);
    expect(c.uses(SelfhostedRepo.users), isFalse);
    expect(c.uses(SelfhostedRepo.photographerContact), isFalse);
  });

  test('bad values fail loudly at startup', () {
    expect(() => BackendConfig.parse(backend: 'supabase'), throwsArgumentError);
    expect(() => BackendConfig.parse(backend: 'selfhosted'), throwsArgumentError);
    expect(
      () => BackendConfig.parse(backend: 'selfhosted', baseUrl: 'ftp://x'),
      throwsArgumentError,
    );
    expect(
      () => BackendConfig.parse(backend: 'selfhosted', baseUrl: 'http://x', repos: 'chat'),
      throwsArgumentError,
    );
  });
}
```

```dart
// test/data/http/mock_api.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/http/api_client.dart';

typedef MockHandler = (int, Object?) Function(http.Request request);

http.Response jsonResponse(int status, Object? body) => body == null
    ? http.Response('', status)
    : http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

Map<String, Object?> apiError(String code) => {
  'code': code,
  'message': code,
  'requestId': 'req-1',
};

/// A tiny in-memory API: handlers keyed by "METHOD /path"; anything else is
/// the server's not_found envelope. Records every request.
class MockApi {
  MockApi([Map<String, MockHandler>? routes]) : routes = routes ?? {};
  final Map<String, MockHandler> routes;
  final requests = <http.Request>[];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final handler = routes['${request.method} ${request.url.path}'];
    if (handler == null) return jsonResponse(404, apiError('not_found'));
    final (status, body) = handler(request);
    return jsonResponse(status, body);
  });

  ApiClient api({IdTokenSource tokens = const StaticIdTokenSource('t0')}) =>
      ApiClient(
        baseUrl: Uri.parse('http://api.test'),
        tokens: tokens,
        client: client,
      );

  List<String> get calls => [
    for (final r in requests) '${r.method} ${r.url.path}',
  ];
}
```

```dart
// test/data/http/api_client_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/http/api_client.dart';

import 'mock_api.dart';

class _CountingTokens implements IdTokenSource {
  final refreshes = <bool>[];
  @override
  Future<String?> token({bool forceRefresh = false}) async {
    refreshes.add(forceRefresh);
    return forceRefresh ? 'fresh' : 'stale';
  }
}

void main() {
  test('sends the bearer token, JSON in and out', () async {
    final api = MockApi({
      'PUT /v1/x': (r) {
        expect(r.headers['authorization'], 'Bearer t0');
        expect(r.headers['accept'], 'application/json');
        expect(r.headers['content-type'], startsWith('application/json'));
        expect(jsonDecode(r.body), {'a': 1});
        return (200, {'ok': 'Thợ ảnh'});
      },
    });
    expect(await api.api().put('/v1/x', {'a': 1}), {'ok': 'Thợ ảnh'});
  });

  test('a 401 refreshes the token and retries once', () async {
    final tokens = _CountingTokens();
    final api = MockApi({
      'GET /v1/x': (r) => r.headers['authorization'] == 'Bearer fresh'
          ? (200, {'ok': true})
          : (401, apiError('unauthenticated')),
    });
    expect(await api.api(tokens: tokens).get('/v1/x'), {'ok': true});
    expect(tokens.refreshes, [false, true]);
    expect(api.requests, hasLength(2));
  });

  test('errors carry the server code, or "unknown" for a foreign body', () async {
    final api = MockApi({
      'GET /v1/locked': (_) => (403, apiError('contact_locked')),
      'GET /v1/html': (_) => (502, null),
    });
    await expectLater(
      api.api().get('/v1/locked'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'contact_locked')),
    );
    await expectLater(
      api.api().get('/v1/html'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'unknown')
          .having((e) => e.status, 'status', 502)),
    );
  });

  test('a network failure is the client-side "network" code', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    final api = ApiClient(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('t'),
      client: client,
    );
    await expectLater(
      api.get('/v1/x'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.network)),
    );
  });

  test('signed out: no request at all', () async {
    final api = MockApi();
    await expectLater(
      api.api(tokens: const StaticIdTokenSource(null)).get('/v1/x'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthenticated')),
    );
    expect(api.requests, isEmpty);
  });

  test('a base URL with a path prefix keeps it', () {
    final api = ApiClient(
      baseUrl: Uri.parse('https://h.example/api/'),
      tokens: const StaticIdTokenSource('t'),
    );
    expect(api.uriFor('/v1/me').toString(), 'https://h.example/api/v1/me');
    api.close();
  });
}
```

```dart
// test/data/http/local_watch_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/http/local_watch.dart';

void main() {
  test('emits the fetched value, then local writes', () async {
    final local = StreamController<int>.broadcast();
    final seen = <int>[];
    final sub = fetchThenLocal(() async => 1, local.stream).listen(seen.add);
    await pumpEventQueue();
    local.add(2);
    await pumpEventQueue();
    expect(seen, [1, 2]);
    await sub.cancel();
    expect(local.hasListener, isFalse);
  });

  test('writes made during the fetch arrive after it, in order', () async {
    final local = StreamController<int>.broadcast();
    final gate = Completer<int>();
    final seen = <int>[];
    fetchThenLocal(() => gate.future, local.stream).listen(seen.add);
    await pumpEventQueue();
    local
      ..add(2)
      ..add(3);
    gate.complete(1);
    await pumpEventQueue();
    expect(seen, [1, 2, 3]);
  });

  test('a failed fetch is an error event; later writes still arrive', () async {
    final local = StreamController<int>.broadcast();
    final events = <Object>[];
    fetchThenLocal<int>(() async => throw StateError('down'), local.stream)
        .listen(events.add, onError: events.add);
    await pumpEventQueue();
    local.add(5);
    await pumpEventQueue();
    expect(events.first, isA<StateError>());
    expect(events.last, 5);
  });
}
```

```dart
// test/data/http/http_adapters_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

import 'mock_api.dart';

const _contactJson = {
  'phone': '+84903123456',
  'phoneVerified': false,
  'allowZalo': true,
  'allowWhatsApp': false,
  'updatedAt': '2026-10-01T00:00:00.000Z',
};

Map<String, Object?> _profile(String name, {String? role}) => {
  'id': 'u1',
  'displayName': name,
  'role': role,
  'avatarUrl': null,
};

void main() {
  test('user contact: 404 reads as "none yet", a stored contact maps', () async {
    final api = MockApi();
    final repo = HttpUserContactRepository(api: api.api());
    expect(await repo.watch('u1').first, isNull);
    api.routes['GET /v1/users/u1/contact'] = (_) => (200, _contactJson);
    expect(await repo.watch('u1').first, const UserContact(phone: '+84903123456'));
  });

  test('user contact: save sends exactly the contract body; a live watch sees it', () async {
    final api = MockApi({
      'PUT /v1/users/u1/contact': (r) {
        expect(jsonDecode(r.body), {
          'phone': '+84903123456',
          'allowZalo': true,
          'allowWhatsApp': false,
        });
        return (200, _contactJson);
      },
    });
    final repo = HttpUserContactRepository(api: api.api());
    final live = expectLater(
      repo.watch('u1'),
      emitsInOrder([isNull, const UserContact(phone: '+84903123456')]),
    );
    await pumpEventQueue();
    await repo.save('u1', phone: '+84903123456', allowZalo: true, allowWhatsApp: false);
    await live;
  });

  test('profile: ensureProfile posts name and avatar, setRole puts the code', () async {
    final api = MockApi({
      'POST /v1/me': (r) {
        expect(jsonDecode(r.body), {
          'displayName': 'Lan',
          'avatarUrl': 'https://lh3.googleusercontent.com/a.jpg',
        });
        return (201, _profile('Lan'));
      },
      'PUT /v1/users/u1/role': (r) {
        expect(jsonDecode(r.body), {'role': 'photographer'});
        return (200, _profile('Lan', role: 'photographer'));
      },
    });
    final repo = HttpUserRepository(api: api.api());
    final p = await repo.ensureProfile(
      const AuthUser(
        uid: 'u1',
        email: 'lan@example.com',
        displayName: 'Lan',
        photoUrl: 'https://lh3.googleusercontent.com/a.jpg',
      ),
    );
    expect(p.needsRole, isTrue);
    expect(p.email, 'lan@example.com');
    await repo.setRole('u1', UserRole.photographer);
    expect(api.calls, ['POST /v1/me', 'PUT /v1/users/u1/role']);
  });

  test('setDisplayName before the profile exists creates it', () async {
    var created = false;
    final api = MockApi({
      'PATCH /v1/users/u1': (_) =>
          created ? (200, _profile('Minh')) : (404, apiError('not_found')),
      'POST /v1/me': (_) {
        created = true;
        return (201, _profile('Minh'));
      },
    });
    await HttpUserRepository(api: api.api()).setDisplayName('u1', 'Minh');
    expect(api.calls, ['PATCH /v1/users/u1', 'POST /v1/me', 'PATCH /v1/users/u1']);
  });

  test('photographer contact: one PUT for the setup, 404 reads as null, a 403 is an error', () async {
    final api = MockApi({
      'PUT /v1/photographers/p1/contact-setup': (r) {
        expect(jsonDecode(r.body), {
          'area': {'city': 'Hà Nội', 'radiusKm': 20},
          'channels': {'call': true, 'zalo': false, 'whatsapp': false, 'acceptInquiries': true},
          'numbers': {'phone': '+84903123456'},
        });
        return (204, null);
      },
      'GET /v1/photographers/p2/contact-numbers': (_) => (403, apiError('permission_denied')),
    });
    final repo = HttpPhotographerContactRepository(api: api.api());
    expect(await repo.watchChannels('p1').first, isNull);
    await repo.completeContactSetup(
      'p1',
      area: const ServiceArea(city: 'Hà Nội', radiusKm: 20),
      channels: const ContactChannels(call: true),
      numbers: const ContactNumbers(phone: '+84903123456'),
    );
    await expectLater(
      repo.watchNumbers('p2').first,
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'permission_denied')),
    );
  });

  test('contact link: URL on success, contact_locked → locked, anything else → unavailable, in-app sends nothing', () async {
    final api = MockApi({
      'POST /v1/contact-links': (r) {
        final body = jsonDecode(r.body) as Map<String, Object?>;
        return switch (body['bookingId']) {
          'b_ok' => (200, {'url': 'https://zalo.me/84912345678'}),
          'b_locked' => (403, apiError('contact_locked')),
          _ => (404, apiError('not_found')),
        };
      },
    });
    final repo = HttpContactLinkRepository(api: api.api());
    expect(
      await repo.link(subject: const ContactSubject.booking('b_ok'), channel: ContactChannel.zalo),
      Uri.parse('https://zalo.me/84912345678'),
    );
    Matcher error(ContactLinkError e) =>
        throwsA(isA<ContactLinkException>().having((x) => x.error, 'error', e));
    await expectLater(
      repo.link(subject: const ContactSubject.booking('b_locked'), channel: ContactChannel.call),
      error(ContactLinkError.locked),
    );
    await expectLater(
      repo.link(subject: const ContactSubject.booking('nope'), channel: ContactChannel.call),
      error(ContactLinkError.unavailable),
    );
    final before = api.requests.length;
    await expectLater(
      repo.link(subject: const ContactSubject.booking('b_ok'), channel: ContactChannel.inApp),
      error(ContactLinkError.unavailable),
    );
    expect(api.requests.length, before);
  });

  test('a body that is not the contract shape is "malformed"', () async {
    final api = MockApi({'GET /v1/users/u1': (_) => (200, {'name': 'x'})});
    await expectLater(
      HttpUserRepository(api: api.api()).watch('u1').first,
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiException.malformed)),
    );
  });
}
```

```dart
// test/data/http/provider_selection_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

ProviderContainer _container(BackendConfig config) {
  final c = ProviderContainer(
    overrides: [
      backendConfigProvider.overrideWithValue(config),
      idTokenSourceProvider.overrideWithValue(const StaticIdTokenSource('t')),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('BACKEND=selfhosted puts the four slice repositories on one ApiClient', () {
    final c = _container(
      BackendConfig.parse(backend: 'selfhosted', baseUrl: 'http://localhost:8787'),
    );
    expect(c.read(userRepositoryProvider), isA<HttpUserRepository>());
    expect(c.read(userContactRepositoryProvider), isA<HttpUserContactRepository>());
    expect(c.read(photographerContactRepositoryProvider), isA<HttpPhotographerContactRepository>());
    expect(c.read(contactLinkRepositoryProvider), isA<HttpContactLinkRepository>());
    expect(identical(c.read(apiClientProvider), c.read(apiClientProvider)), isTrue);
  });

  test('SELFHOSTED_REPOS=userContact moves only that repository', () {
    final config = BackendConfig.parse(
      backend: 'selfhosted',
      baseUrl: 'http://localhost:8787',
      repos: 'userContact',
    );
    final c = _container(config);
    expect(c.read(userContactRepositoryProvider), isA<HttpUserContactRepository>());
    expect(config.uses(SelfhostedRepo.users), isFalse);
  });
}
```

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/data/backend_config_test.dart test/data/http`
Expected: FAIL to compile, `backend_config.dart`, `id_token_source.dart`, `api_client.dart` … not found.

- [ ] **Step 4: Implement**

```dart
// lib/data/backend_config.dart
import 'package:flutter/foundation.dart';

enum Backend { firebase, selfhosted }

/// Repositories of the first self-hosted slice that can move to the HTTP API
/// one by one (data-model README §6 step 4: "theo từng thực thể").
enum SelfhostedRepo {
  users('users'),
  userContact('userContact'),
  photographerContact('photographerContact'),
  contactLink('contactLink');

  const SelfhostedRepo(this.code);
  final String code;
}

/// Which adapter each port uses. Set at build time:
/// `--dart-define=BACKEND=selfhosted --dart-define=BASE_URL=http://10.0.2.2:8787`
/// and optionally `--dart-define=SELFHOSTED_REPOS=userContact,contactLink`.
class BackendConfig {
  const BackendConfig._(this.backend, this.baseUrl, this.repos);
  const BackendConfig.firebase()
    : this._(Backend.firebase, null, const <SelfhostedRepo>{});

  factory BackendConfig.parse({
    required String backend,
    String baseUrl = '',
    String repos = '',
  }) {
    switch (backend) {
      case 'firebase':
        return const BackendConfig.firebase();
      case 'selfhosted':
        final uri = Uri.tryParse(baseUrl);
        final ok =
            uri != null &&
            (uri.isScheme('http') || uri.isScheme('https')) &&
            uri.host.isNotEmpty;
        if (!ok) {
          throw ArgumentError.value(baseUrl, 'BASE_URL', 'must be an http(s) URL when BACKEND=selfhosted');
        }
        if (kReleaseMode && !uri.isScheme('https')) {
          throw ArgumentError.value(baseUrl, 'BASE_URL', 'release builds need https');
        }
        final codes = repos
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        final selected = codes.isEmpty
            ? SelfhostedRepo.values.toSet()
            : {
                for (final code in codes)
                  SelfhostedRepo.values.firstWhere(
                    (r) => r.code == code,
                    orElse: () => throw ArgumentError.value(code, 'SELFHOSTED_REPOS', 'unknown repository'),
                  ),
              };
        return BackendConfig._(Backend.selfhosted, uri, selected);
      default:
        throw ArgumentError.value(backend, 'BACKEND', 'must be firebase or selfhosted');
    }
  }

  factory BackendConfig.fromEnvironment() => BackendConfig.parse(
    backend: const String.fromEnvironment('BACKEND', defaultValue: 'firebase'),
    baseUrl: const String.fromEnvironment('BASE_URL'),
    repos: const String.fromEnvironment('SELFHOSTED_REPOS'),
  );

  final Backend backend;
  final Uri? baseUrl;
  final Set<SelfhostedRepo> repos;

  bool uses(SelfhostedRepo repo) =>
      backend == Backend.selfhosted && repos.contains(repo);
}
```

```dart
// lib/data/auth/id_token_source.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Port: the bearer token for the self-hosted API. Firebase Auth stays the
/// identity provider in phase 2, so this is the signed-in user's ID token.
abstract class IdTokenSource {
  /// Null while signed out. [forceRefresh] is used once after a 401.
  Future<String?> token({bool forceRefresh = false});
}

class FirebaseIdTokenSource implements IdTokenSource {
  FirebaseIdTokenSource({fb.FirebaseAuth? auth}) : _auth = auth;
  final fb.FirebaseAuth? _auth;

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    final user = (_auth ?? fb.FirebaseAuth.instance).currentUser;
    // The SDK caches the token and refreshes it only near expiry, so this is
    // not a network call per request.
    return user?.getIdToken(forceRefresh);
  }
}

/// Fixed token, for tests and the contract runs.
class StaticIdTokenSource implements IdTokenSource {
  const StaticIdTokenSource(this.value);
  final String? value;

  @override
  Future<String?> token({bool forceRefresh = false}) async => value;
}
```

```dart
// lib/data/http/api_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:photobooking/data/auth/id_token_source.dart';

/// A failed call to the self-hosted API. [code] is the server's stable error
/// code (`contact_locked`, `not_found`, …) or one of the client-side codes
/// below. Never carries the response body, so nothing private reaches logs.
class ApiException implements Exception {
  const ApiException(this.status, this.code);
  final int status;
  final String code;

  static const network = 'network';
  static const malformed = 'malformed';
  static const unauthenticated = 'unauthenticated';

  @override
  String toString() => 'ApiException($status, $code)';
}

/// Reads `code` from the error envelope `{code, message, requestId}`.
String errorCodeOf(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map && json['code'] is String) return json['code'] as String;
    return 'unknown';
  } on FormatException {
    return 'unknown';
  }
}

/// One instance per app: a single `http.Client` keeps connections alive and
/// (on mobile, through `dart:io`) asks for and inflates gzip by itself.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required IdTokenSource tokens,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _base = baseUrl,
       _tokens = tokens,
       _http = client ?? http.Client();

  final Uri _base;
  final IdTokenSource _tokens;
  final http.Client _http;
  final Duration timeout;

  Future<Object?> get(String path) => _send('GET', path);
  Future<Object?> post(String path, Map<String, Object?> body) =>
      _send('POST', path, body);
  Future<Object?> put(String path, Map<String, Object?> body) =>
      _send('PUT', path, body);
  Future<Object?> patch(String path, Map<String, Object?> body) =>
      _send('PATCH', path, body);

  void close() => _http.close();

  Uri uriFor(String path) {
    final prefix = _base.path.endsWith('/')
        ? _base.path.substring(0, _base.path.length - 1)
        : _base.path;
    return _base.replace(path: '$prefix$path');
  }

  Future<Object?> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    var res = await _once(method, path, body, forceRefresh: false);
    if (res.statusCode == 401) {
      res = await _once(method, path, body, forceRefresh: true);
    }
    final status = res.statusCode;
    final text = utf8.decode(res.bodyBytes);
    if (status >= 200 && status < 300) {
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } on FormatException {
        throw ApiException(status, ApiException.malformed);
      }
    }
    throw ApiException(status, errorCodeOf(text));
  }

  Future<http.Response> _once(
    String method,
    String path,
    Map<String, Object?>? body, {
    required bool forceRefresh,
  }) async {
    final token = await _tokens.token(forceRefresh: forceRefresh);
    if (token == null) {
      throw const ApiException(401, ApiException.unauthenticated);
    }
    final req = http.Request(method, uriFor(path))
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'application/json';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, ApiException.network);
    } on http.ClientException {
      throw const ApiException(0, ApiException.network);
    }
  }
}
```

```dart
// lib/data/http/local_watch.dart
import 'dart:async';

/// `watch` over plain HTTP without polling: one [fetch] per subscription,
/// then every value from [local] (the adapter's own writes). Writes made
/// while the fetch runs are delivered after it, in order. Changes made on
/// another device show up the next time a screen subscribes.
Stream<T> fetchThenLocal<T>(Future<T> Function() fetch, Stream<T> local) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  out = StreamController<T>(
    onListen: () {
      final pending = <T>[];
      var fetched = false;
      void drain() {
        fetched = true;
        pending.forEach(out.add);
        pending.clear();
      }

      sub = local.listen((v) => fetched ? out.add(v) : pending.add(v));
      fetch().then(
        (v) {
          out.add(v);
          drain();
        },
        onError: (Object e, StackTrace s) {
          out.addError(e, s);
          drain();
        },
      );
    },
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
```

```dart
// lib/data/http/wire.dart
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// Paths of services/api/api/openapi.yaml. Ids are opaque [A-Za-z0-9_-].
abstract final class ApiPaths {
  static const me = '/v1/me';
  static String user(String id) => '/v1/users/${Uri.encodeComponent(id)}';
  static String userRole(String id) => '${user(id)}/role';
  static String userContact(String id) => '${user(id)}/contact';
  static String photographer(String id) =>
      '/v1/photographers/${Uri.encodeComponent(id)}';
  static String contactChannels(String id) => '${photographer(id)}/contact-channels';
  static String contactNumbers(String id) => '${photographer(id)}/contact-numbers';
  static String serviceArea(String id) => '${photographer(id)}/service-area';
  static String contactSetup(String id) => '${photographer(id)}/contact-setup';
  static const contactLinks = '/v1/contact-links';
}

/// Every (method, contract path) the app calls; test/data/http/openapi_drift_test.dart
/// checks each against openapi.yaml.
const apiOperations = <(String, String)>[
  ('POST', '/v1/me'),
  ('GET', '/v1/users/{userId}'),
  ('PATCH', '/v1/users/{userId}'),
  ('PUT', '/v1/users/{userId}/role'),
  ('GET', '/v1/users/{userId}/contact'),
  ('PUT', '/v1/users/{userId}/contact'),
  ('GET', '/v1/photographers/{photographerId}/contact-channels'),
  ('GET', '/v1/photographers/{photographerId}/contact-numbers'),
  ('GET', '/v1/photographers/{photographerId}/service-area'),
  ('PUT', '/v1/photographers/{photographerId}/contact-setup'),
  ('POST', '/v1/contact-links'),
];

Never _malformed() => throw const ApiException(200, ApiException.malformed);

Map<String, dynamic> _map(Object? json) =>
    json is Map<String, dynamic> ? json : _malformed();

String _name(String raw) => raw.length > 80 ? raw.substring(0, 80) : raw;

/// Same fallback name as FirestoreUserRepository.ensureProfile.
Map<String, Object?> ensureProfileBody(AuthUser user) {
  final given = user.displayName?.trim() ?? '';
  final name = given.isNotEmpty
      ? given
      : (user.email?.split('@').first ?? 'Người dùng');
  return {
    'displayName': _name(name.isEmpty ? 'Người dùng' : name),
    if (user.photoUrl != null) 'avatarUrl': user.photoUrl,
  };
}

Map<String, Object?> updateUserBody(String displayName) => {
  'displayName': _name(displayName),
};

Map<String, Object?> setRoleBody(UserRole role) => {'role': role.name};

UserProfile profileFromJson(Object? json) {
  final m = _map(json);
  if (m['id'] is! String || m['displayName'] is! String) _malformed();
  try {
    return UserProfile.fromJson({
      'uid': m['id'],
      'displayName': m['displayName'],
      'role': m['role'],
      'avatarUrl': m['avatarUrl'],
    });
  } on Object {
    _malformed();
  }
}

UserContact userContactFromJson(Object? json) {
  final m = _map(json);
  final phone = m['phone'];
  if (phone is! String) _malformed();
  return UserContact(
    phone: phone,
    phoneVerified: m['phoneVerified'] == true,
    allowZalo: m['allowZalo'] != false,
    allowWhatsApp: m['allowWhatsApp'] == true,
  );
}

Map<String, Object?> saveContactBody({
  required String phone,
  required bool allowZalo,
  required bool allowWhatsApp,
}) => {'phone': phone, 'allowZalo': allowZalo, 'allowWhatsApp': allowWhatsApp};

ContactChannels channelsFromJson(Object? json) =>
    ContactChannels.fromMap(_map(json)) ?? _malformed();

ContactNumbers numbersFromJson(Object? json) =>
    ContactNumbers.fromMap(_map(json)) ?? _malformed();

ServiceArea areaFromJson(Object? json) =>
    ServiceArea.fromMap(_map(json)) ?? _malformed();

Map<String, Object?> contactSetupBody({
  required ServiceArea area,
  required ContactChannels channels,
  required ContactNumbers numbers,
}) => {
  'area': area.toMap(),
  'channels': channels.toMap(),
  'numbers': numbers.toMap(),
};
```

```dart
// lib/data/http/api_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/http/api_client.dart';

final backendConfigProvider = Provider<BackendConfig>(
  (ref) => BackendConfig.fromEnvironment(),
);

final idTokenSourceProvider = Provider<IdTokenSource>(
  (ref) => FirebaseIdTokenSource(),
);

/// Built only when some repository uses the self-hosted backend.
final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(backendConfigProvider).baseUrl;
  if (base == null) {
    throw StateError('BASE_URL is required when BACKEND=selfhosted');
  }
  final client = ApiClient(
    baseUrl: base,
    tokens: ref.watch(idTokenSourceProvider),
  );
  ref.onDispose(client.close);
  return client;
});
```

```dart
// lib/data/user/http_user_repository.dart
import 'dart:async';

import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/local_watch.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';

/// UserRepository over the self-hosted API (users table).
class HttpUserRepository implements UserRepository {
  HttpUserRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  final _writes =
      StreamController<({String uid, UserProfile? profile})>.broadcast();

  void _emit(String uid, UserProfile p) => _writes.add((uid: uid, profile: p));

  Future<UserProfile?> _get(String uid) async {
    try {
      return profileFromJson(await _api.get(ApiPaths.user(uid)));
    } on ApiException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  @override
  Stream<UserProfile?> watch(String uid) => fetchThenLocal(
    () => _get(uid),
    _writes.stream.where((w) => w.uid == uid).map((w) => w.profile),
  );

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    final p = profileFromJson(
      await _api.post(ApiPaths.me, ensureProfileBody(user)),
    ).copyWith(email: user.email);
    _emit(user.uid, p);
    return p;
  }

  @override
  Future<void> setRole(String uid, UserRole role) async {
    _emit(uid, profileFromJson(await _api.put(ApiPaths.userRole(uid), setRoleBody(role))));
  }

  /// Safe to race ensureProfile, like the Firestore adapter: creates the
  /// profile when it does not exist yet.
  @override
  Future<void> setDisplayName(String uid, String name) async {
    Object? json;
    try {
      json = await _api.patch(ApiPaths.user(uid), updateUserBody(name));
    } on ApiException catch (e) {
      if (e.code != 'not_found') rethrow;
      await _api.post(ApiPaths.me, updateUserBody(name));
      json = await _api.patch(ApiPaths.user(uid), updateUserBody(name));
    }
    _emit(uid, profileFromJson(json));
  }

  void dispose() => _writes.close();
}
```

```dart
// lib/data/user/http_user_contact_repository.dart
import 'dart:async';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/local_watch.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

/// UserContactRepository over the self-hosted API (user_contacts, owner only).
class HttpUserContactRepository implements UserContactRepository {
  HttpUserContactRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  final _writes =
      StreamController<({String uid, UserContact? contact})>.broadcast();

  Future<UserContact?> _get(String uid) async {
    try {
      return userContactFromJson(await _api.get(ApiPaths.userContact(uid)));
    } on ApiException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  @override
  Stream<UserContact?> watch(String uid) => fetchThenLocal(
    () => _get(uid),
    _writes.stream.where((w) => w.uid == uid).map((w) => w.contact),
  );

  /// One PUT: the server keeps or resets `phoneVerified` itself, so there is
  /// no read-before-write like the Firestore adapter needs.
  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    final json = await _api.put(
      ApiPaths.userContact(uid),
      saveContactBody(phone: phone, allowZalo: allowZalo, allowWhatsApp: allowWhatsApp),
    );
    _writes.add((uid: uid, contact: userContactFromJson(json)));
  }

  void dispose() => _writes.close();
}
```

```dart
// lib/data/photographer/http_photographer_contact_repository.dart
import 'dart:async';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/local_watch.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

typedef _Setup = ({
  String uid,
  ServiceArea area,
  ContactChannels channels,
  ContactNumbers numbers,
});

/// PhotographerContactRepository over the self-hosted API.
class HttpPhotographerContactRepository implements PhotographerContactRepository {
  HttpPhotographerContactRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  final _writes = StreamController<_Setup>.broadcast();

  Future<T?> _orNull<T>(String path, T Function(Object?) read) async {
    try {
      return read(await _api.get(path));
    } on ApiException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  Stream<T?> _watch<T>(String id, String path, T Function(Object?) read, T Function(_Setup) pick) =>
      fetchThenLocal<T?>(
        () => _orNull(path, read),
        _writes.stream.where((w) => w.uid == id).map(pick),
      );

  @override
  Stream<ContactChannels?> watchChannels(String photographerId) => _watch(
    photographerId,
    ApiPaths.contactChannels(photographerId),
    channelsFromJson,
    (w) => w.channels,
  );

  /// Owner only: anyone else gets an ApiException('permission_denied') event.
  @override
  Stream<ContactNumbers?> watchNumbers(String photographerId) => _watch(
    photographerId,
    ApiPaths.contactNumbers(photographerId),
    numbersFromJson,
    (w) => w.numbers,
  );

  @override
  Stream<ServiceArea?> watchServiceArea(String photographerId) => _watch(
    photographerId,
    ApiPaths.serviceArea(photographerId),
    areaFromJson,
    (w) => w.area,
  );

  /// One PUT; the server writes area, flags, numbers and onboardingComplete
  /// in one transaction.
  @override
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) async {
    await _api.put(
      ApiPaths.contactSetup(uid),
      contactSetupBody(area: area, channels: channels, numbers: numbers),
    );
    _writes.add((uid: uid, area: area, channels: channels, numbers: numbers));
  }

  void dispose() => _writes.close();
}
```

```dart
// lib/data/contact/http_contact_link_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/wire.dart';

/// get_contact_link over the self-hosted API. Same request and response as
/// the callable (`callableData`, `parseLinkResponse`); the URL is still
/// checked by ContactLauncher's allow-list before it is opened.
class HttpContactLinkRepository implements ContactLinkRepository {
  HttpContactLinkRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async {
    if (!channel.isExternal) {
      throw const ContactLinkException(ContactLinkError.unavailable);
    }
    try {
      return parseLinkResponse(
        await _api.post(ApiPaths.contactLinks, callableData(subject, channel)),
      );
    } on ApiException catch (e) {
      throw ContactLinkException(linkErrorFromCode(e.code));
    }
  }
}
```

Provider selection. In `lib/data/auth/auth_providers.dart` add the imports

```dart
import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
```

and replace

```dart
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(),
);
```

with

```dart
final userRepositoryProvider = Provider<UserRepository>((ref) {
  if (ref.watch(backendConfigProvider).uses(SelfhostedRepo.users)) {
    final repo = HttpUserRepository(api: ref.watch(apiClientProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return FirestoreUserRepository();
});
```

In `lib/data/user/user_contact_providers.dart` (plan 2a) add the imports `backend_config.dart`, `http/api_providers.dart`, `user/http_user_contact_repository.dart` (as `package:photobooking/data/...`) and replace

```dart
final userContactRepositoryProvider = Provider<UserContactRepository>(
  (ref) => FirestoreUserContactRepository(),
);
```

with

```dart
final userContactRepositoryProvider = Provider<UserContactRepository>((ref) {
  if (ref.watch(backendConfigProvider).uses(SelfhostedRepo.userContact)) {
    final repo = HttpUserContactRepository(api: ref.watch(apiClientProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return FirestoreUserContactRepository();
});
```

In `lib/data/photographer/photographer_contact_providers.dart` (plan 2b) add the imports `backend_config.dart`, `http/api_providers.dart`, `photographer/http_photographer_contact_repository.dart` and replace

```dart
final photographerContactRepositoryProvider =
    Provider<PhotographerContactRepository>(
      (ref) => FirestorePhotographerContactRepository(),
    );
```

with

```dart
final photographerContactRepositoryProvider =
    Provider<PhotographerContactRepository>((ref) {
      if (ref.watch(backendConfigProvider).uses(SelfhostedRepo.photographerContact)) {
        final repo = HttpPhotographerContactRepository(
          api: ref.watch(apiClientProvider),
        );
        ref.onDispose(repo.dispose);
        return repo;
      }
      return FirestorePhotographerContactRepository();
    });
```

In `lib/data/contact/contact_providers.dart` (plan 2b) add the imports `backend_config.dart`, `http/api_providers.dart`, `contact/http_contact_link_repository.dart` and replace

```dart
final contactLinkRepositoryProvider = Provider<ContactLinkRepository>(
  (ref) => FunctionsContactLinkRepository(),
);
```

with

```dart
final contactLinkRepositoryProvider = Provider<ContactLinkRepository>((ref) {
  if (ref.watch(backendConfigProvider).uses(SelfhostedRepo.contactLink)) {
    return HttpContactLinkRepository(api: ref.watch(apiClientProvider));
  }
  return FunctionsContactLinkRepository();
});
```

If plans 2a/2b were executed with different provider text (for example `dart format` re-wrapped it), replace the provider whose name matches; keep its type and name.

In `android/app/src/debug/AndroidManifest.xml`, inside `<manifest>` after the `<uses-permission …/>` line, add (debug builds only; release keeps cleartext off):

```xml
    <!-- Debug only: lets the app reach the local API over http://10.0.2.2:8787. -->
    <application android:usesCleartextTraffic="true" />
```

- [ ] **Step 5: Run and see them pass**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: analyze clean; every test passes, among them the 22 new ones (config 4, client 6, local watch 3, adapters 7, providers 2).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data test/data android/app/src/debug/AndroidManifest.xml
git commit -m "feat(data): HTTP adapters for the self-hosted slice behind the existing ports

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: One contract suite per port, run against Fake, Firestore and HTTP; contract drift test

**Files:**
- Create: `app_flutter/test/data/contracts/contract_world.dart`, `app_flutter/test/data/contracts/emulator_token.dart`, `app_flutter/test/data/contracts/user_repository_contract.dart`, `app_flutter/test/data/contracts/user_contact_contract.dart`, `app_flutter/test/data/contracts/photographer_contact_contract.dart`, `app_flutter/test/data/contracts/contact_link_contract.dart`, `app_flutter/test/data/contracts/fake_contracts_test.dart`, `app_flutter/test/data/contracts/firestore_contracts_test.dart`, `app_flutter/test/data/contracts/selfhosted_contracts_test.dart`, `app_flutter/test/data/http/openapi_drift_test.dart`, `app_flutter/dart_test.yaml`
- Modify: `app_flutter/pubspec.yaml`, `app_flutter/pubspec.lock`

**Interfaces:**
- Consumes: every adapter of Task 8 and of plans 2a/2b; `services/api/test/fixtures/contract-world.json` and `services/api/api/openapi.yaml` (read from disk, relative to `app_flutter/`); `apiOperations`, `ApiPaths` and the body builders of `wire.dart`.
- Produces:
  - `typedef Create<R> = Future<({R repo, String uid})> Function();`
  - `void userRepositoryContract(String label, Create<UserRepository> create)` (5 tests), `void userContactRepositoryContract(String label, Create<UserContactRepository> create)` (4), `void photographerContactRepositoryContract(String label, Create<PhotographerContactRepository> create)` (4), `void contactLinkRepositoryContract(String label, Future<ContactLinkRepository> Function(ContactWorld world) create)` (29).
  - `class ContactWorld { static ContactWorld load(); final String customer; final String otherCustomer; final Map<String, ({ContactNumbers numbers, ContactChannels channels})> photographers; final List<WorldBooking> bookings; }`, `typedef WorldBooking = ({String id, String photographerId, String status, bool unlocked})`.
  - `String emulatorIdToken(String uid, {String projectId = 'demo-nag'})`.
  - Tag `selfhosted` (declared in `dart_test.yaml`); the HTTP run is skipped unless `--dart-define=API_BASE_URL=…` is given.

- [ ] **Step 1: Add the dev dependencies**

```bash
flutter pub add --dev yaml fake_cloud_firestore
grep -nE "^  (yaml|fake_cloud_firestore):" pubspec.yaml
```

Expected: both under `dev_dependencies:`. If pub cannot resolve `fake_cloud_firestore` against `cloud_firestore ^6.10.0`, do not downgrade `cloud_firestore`: run `flutter pub add --dev yaml` only, skip `firestore_contracts_test.dart` below, and write in the PR description that the Firestore run of the contracts moves to the emulator integration tests of the phase 1 plan.

```yaml
# dart_test.yaml
tags:
  selfhosted:
    # Talks to services/api over the network: allow slower runs.
    timeout: 2x
```

- [ ] **Step 2: Write the suites (the tests of this task)**

```dart
// test/data/contracts/contract_world.dart
import 'dart:convert';
import 'dart:io';

import 'package:photobooking/data/photographer/photographer_contact.dart';

/// The fixture world shared with services/api (seeded there by
/// `npm run seed:contract`). Path is relative to app_flutter/.
const contractWorldPath = '../services/api/test/fixtures/contract-world.json';

typedef WorldBooking = ({
  String id,
  String photographerId,
  String status,
  bool unlocked,
});

class ContactWorld {
  ContactWorld._(this.customer, this.otherCustomer, this.photographers, this.bookings);

  static ContactWorld load() {
    final j = jsonDecode(File(contractWorldPath).readAsStringSync()) as Map<String, dynamic>;
    final photographers = {
      for (final MapEntry(:key, :value)
          in (j['photographers'] as Map<String, dynamic>).entries)
        key: (
          numbers: ContactNumbers.fromMap((value as Map<String, dynamic>)['numbers'] as Map<String, dynamic>)!,
          channels: ContactChannels.fromMap(value['channels'])!,
        ),
    };
    final bookings = [
      for (final b in (j['bookings'] as List).cast<Map<String, dynamic>>())
        (
          id: b['id'] as String,
          photographerId: b['photographerId'] as String,
          status: b['status'] as String,
          unlocked: b['unlocked'] as bool,
        ),
    ];
    return ContactWorld._(
      j['customer'] as String,
      j['otherCustomer'] as String,
      photographers,
      bookings,
    );
  }

  final String customer;
  final String otherCustomer;
  final Map<String, ({ContactNumbers numbers, ContactChannels channels})> photographers;
  final List<WorldBooking> bookings;
}
```

```dart
// test/data/contracts/emulator_token.dart
import 'dart:convert';

/// An ID token shaped like the Firebase Auth emulator's (unsigned, alg
/// "none"). services/api accepts it only with AUTH_MODE=firebase-emulator,
/// which it refuses in production.
String emulatorIdToken(String uid, {String projectId = 'demo-nag'}) {
  String enc(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'none', 'typ': 'JWT'})}.${enc({
    'iss': 'https://securetoken.google.com/$projectId',
    'aud': projectId,
    'sub': uid,
    'user_id': uid,
    'iat': now,
    'auth_time': now,
    'exp': now + 3600,
    'firebase': {'sign_in_provider': 'password', 'identities': <String, Object?>{}},
  })}.';
}
```

```dart
// test/data/contracts/user_repository_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';

typedef Create<R> = Future<({R repo, String uid})> Function();

AuthUser _user(String uid, String name) =>
    AuthUser(uid: uid, email: '$uid@example.com', displayName: name);

/// Behaviour every UserRepository adapter must share (data-model README §7.3).
void userRepositoryContract(String label, Create<UserRepository> create) {
  group('$label UserRepository contract', () {
    test('watch of a missing profile emits null', () async {
      final h = await create();
      expect(await h.repo.watch(h.uid).first, isNull);
    });

    test('ensureProfile creates a role-less profile and never overwrites it', () async {
      final h = await create();
      final p = await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      expect((p.uid, p.displayName, p.role), (h.uid, 'Lan', null));
      final again = await h.repo.ensureProfile(_user(h.uid, 'Someone else'));
      expect(again.displayName, 'Lan');
    });

    test('setDisplayName works before and after ensureProfile', () async {
      final h = await create();
      await h.repo.setDisplayName(h.uid, 'Minh');
      expect((await h.repo.watch(h.uid).first)?.displayName, 'Minh');
      await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      expect((await h.repo.watch(h.uid).first)?.displayName, 'Minh');
    });

    test('setRole shows in watch and survives ensureProfile', () async {
      final h = await create();
      await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      await h.repo.setRole(h.uid, UserRole.photographer);
      expect((await h.repo.watch(h.uid).first)?.role, UserRole.photographer);
      expect((await h.repo.ensureProfile(_user(h.uid, 'Lan'))).role, UserRole.photographer);
    });

    test("a live watch sees the adapter's own writes", () async {
      final h = await create();
      await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      final seen = expectLater(
        h.repo.watch(h.uid).map((p) => p?.displayName),
        emitsThrough('Minh'),
      );
      await h.repo.setDisplayName(h.uid, 'Minh');
      await seen;
    });
  });
}
```

```dart
// test/data/contracts/user_contact_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

import 'user_repository_contract.dart';

void userContactRepositoryContract(String label, Create<UserContactRepository> create) {
  group('$label UserContactRepository contract', () {
    test('no contact yet emits null', () async {
      final h = await create();
      expect(await h.repo.watch(h.uid).first, isNull);
    });

    test('a saved contact reads back unverified with its permissions', () async {
      final h = await create();
      await h.repo.save(h.uid, phone: '+84903123456', allowZalo: false, allowWhatsApp: true);
      expect(
        await h.repo.watch(h.uid).first,
        const UserContact(phone: '+84903123456', allowZalo: false, allowWhatsApp: true),
      );
    });

    test('a live watch sees saves', () async {
      final h = await create();
      final seen = expectLater(
        h.repo.watch(h.uid),
        emitsThrough(const UserContact(phone: '+84912345678')),
      );
      await h.repo.save(h.uid, phone: '+84912345678', allowZalo: true, allowWhatsApp: false);
      await seen;
    });

    test('a toggle keeps the number; a new number replaces it', () async {
      final h = await create();
      await h.repo.save(h.uid, phone: '+84903123456', allowZalo: true, allowWhatsApp: false);
      await h.repo.save(h.uid, phone: '+84903123456', allowZalo: false, allowWhatsApp: false);
      expect((await h.repo.watch(h.uid).first)?.phone, '+84903123456');
      await h.repo.save(h.uid, phone: '+84987654321', allowZalo: false, allowWhatsApp: false);
      final now = await h.repo.watch(h.uid).first;
      expect((now?.phone, now?.phoneVerified), ('+84987654321', false));
    });
  });
}
```

```dart
// test/data/contracts/photographer_contact_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

import 'user_repository_contract.dart';

const _area = ServiceArea(city: 'Hà Nội', radiusKm: 20);
const _channels = ContactChannels(call: true, zalo: true);
const _numbers = ContactNumbers(phone: '+84903123456', zaloPhone: '+84912345678');

void photographerContactRepositoryContract(
  String label,
  Create<PhotographerContactRepository> create,
) {
  group('$label PhotographerContactRepository contract', () {
    test('before setup there are no channels, numbers or area', () async {
      final h = await create();
      expect(await h.repo.watchChannels(h.uid).first, isNull);
      expect(await h.repo.watchNumbers(h.uid).first, isNull);
      expect(await h.repo.watchServiceArea(h.uid).first, isNull);
    });

    test('completeContactSetup stores the three parts', () async {
      final h = await create();
      await h.repo.completeContactSetup(h.uid, area: _area, channels: _channels, numbers: _numbers);
      expect(await h.repo.watchChannels(h.uid).first, _channels);
      expect(await h.repo.watchNumbers(h.uid).first, _numbers);
      expect(await h.repo.watchServiceArea(h.uid).first, _area);
    });

    test('saving again without an own Zalo number clears it', () async {
      final h = await create();
      await h.repo.completeContactSetup(h.uid, area: _area, channels: _channels, numbers: _numbers);
      await h.repo.completeContactSetup(
        h.uid,
        area: _area,
        channels: _channels,
        numbers: const ContactNumbers(phone: '+84903123456'),
      );
      expect((await h.repo.watchNumbers(h.uid).first)?.zaloPhone, isNull);
    });

    test('a live channels watch sees the setup', () async {
      final h = await create();
      final seen = expectLater(h.repo.watchChannels(h.uid), emitsThrough(_channels));
      await h.repo.completeContactSetup(h.uid, area: _area, channels: _channels, numbers: _numbers);
      await seen;
    });
  });
}
```

```dart
// test/data/contracts/contact_link_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';

import 'contract_world.dart';

Matcher _fails(ContactLinkError e) =>
    throwsA(isA<ContactLinkException>().having((x) => x.error, 'error', e));

/// Runs every booking of the shared world × every outside channel. The URL
/// must equal plan 2b's reference `contactUriFor`, so the server's phase 1
/// `contactUrl` and the app's function are checked against each other.
void contactLinkRepositoryContract(
  String label,
  Future<ContactLinkRepository> Function(ContactWorld world) create,
) {
  final world = ContactWorld.load();
  const outside = [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp];

  group('$label ContactLinkRepository contract', () {
    for (final b in world.bookings) {
      for (final channel in outside) {
        test('${b.id} ${channel.code}', () async {
          final repo = await create(world);
          final p = world.photographers[b.photographerId]!;
          final future = repo.link(subject: ContactSubject.booking(b.id), channel: channel);
          if (!b.unlocked) {
            await expectLater(future, _fails(ContactLinkError.locked));
          } else if (p.channels.external.contains(channel)) {
            expect(await future, contactUriFor(channel, p.numbers));
          } else {
            await expectLater(future, _fails(ContactLinkError.unavailable));
          }
        });
      }
    }

    test('an unknown booking is unavailable', () async {
      final repo = await create(world);
      await expectLater(
        repo.link(subject: const ContactSubject.booking('ctr_b_missing'), channel: ContactChannel.call),
        _fails(ContactLinkError.unavailable),
      );
    });

    test('the in-app channel never has a link', () async {
      final repo = await create(world);
      await expectLater(
        repo.link(subject: ContactSubject.booking(world.bookings.first.id), channel: ContactChannel.inApp),
        _fails(ContactLinkError.unavailable),
      );
    });
  });
}
```

```dart
// test/data/contracts/fake_contracts_test.dart
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';

import 'contact_link_contract.dart';
import 'photographer_contact_contract.dart';
import 'user_contact_contract.dart';
import 'user_repository_contract.dart';

void main() {
  userRepositoryContract('Fake', () async => (repo: FakeUserRepository(), uid: 'u1'));
  userContactRepositoryContract('Fake', () async => (repo: FakeUserContactRepository(), uid: 'u1'));
  photographerContactRepositoryContract(
    'Fake',
    () async => (repo: FakePhotographerContactRepository(), uid: 'p1'),
  );
  contactLinkRepositoryContract('Fake', (world) async {
    final fake = FakeContactLinkRepository();
    for (final b in world.bookings) {
      final p = world.photographers[b.photographerId]!;
      fake.add(
        ContactSubject.booking(b.id),
        numbers: p.numbers,
        channels: p.channels,
        unlocked: b.unlocked,
      );
    }
    return fake;
  });
}
```

```dart
// test/data/contracts/firestore_contracts_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';

import 'photographer_contact_contract.dart';
import 'user_contact_contract.dart';
import 'user_repository_contract.dart';

/// The Firebase adapters against an in-memory Firestore. Rules are tested
/// separately (firebase/rules-test); this checks the adapters' behaviour.
/// ContactLinkRepository's Firebase adapter (a callable) runs in phase 1's
/// emulator tests.
void main() {
  userRepositoryContract(
    'Firestore',
    () async => (repo: FirestoreUserRepository(db: FakeFirebaseFirestore()), uid: 'u1'),
  );
  userContactRepositoryContract(
    'Firestore',
    () async => (repo: FirestoreUserContactRepository(db: FakeFirebaseFirestore()), uid: 'u1'),
  );
  photographerContactRepositoryContract(
    'Firestore',
    () async => (repo: FirestorePhotographerContactRepository(db: FakeFirebaseFirestore()), uid: 'p1'),
  );
}
```

```dart
// test/data/contracts/selfhosted_contracts_test.dart
@Tags(['selfhosted'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

import 'contact_link_contract.dart';
import 'emulator_token.dart';
import 'photographer_contact_contract.dart';
import 'user_contact_contract.dart';
import 'user_repository_contract.dart';

/// Needs the compose stack with AUTH_MODE=firebase-emulator and the contract
/// world seeded:
///   cd services/api && docker compose up --build -d
///   docker compose run --rm api node dist/tools/seed-contract.js
///   cd ../../app_flutter && flutter test test/data/contracts/selfhosted_contracts_test.dart \
///     --tags selfhosted --dart-define=API_BASE_URL=http://localhost:8787
const _base = String.fromEnvironment('API_BASE_URL');
const _project = String.fromEnvironment('API_PROJECT_ID', defaultValue: 'demo-nag');

var _n = 0;
String _freshUid() => 'ctr_${DateTime.now().microsecondsSinceEpoch}_${_n++}';

ApiClient _api(String uid) => ApiClient(
  baseUrl: Uri.parse(_base),
  tokens: StaticIdTokenSource(emulatorIdToken(uid, projectId: _project)),
);

void main() {
  // Real sockets: no widget-test HTTP override in this file.
  HttpOverrides.global = null;
  final skip = _base.isEmpty
      ? 'needs the compose stack: --dart-define=API_BASE_URL=http://localhost:8787'
      : null;

  group('selfhosted', skip: skip, () {
    userRepositoryContract('HTTP', () async {
      final uid = _freshUid();
      return (repo: HttpUserRepository(api: _api(uid)), uid: uid);
    });

    userContactRepositoryContract('HTTP', () async {
      final uid = _freshUid();
      final api = _api(uid);
      await HttpUserRepository(api: api).ensureProfile(AuthUser(uid: uid, displayName: 'Hợp đồng'));
      return (repo: HttpUserContactRepository(api: api), uid: uid);
    });

    photographerContactRepositoryContract('HTTP', () async {
      final uid = _freshUid();
      final api = _api(uid);
      final users = HttpUserRepository(api: api);
      await users.ensureProfile(AuthUser(uid: uid, displayName: 'Thợ hợp đồng'));
      await users.setRole(uid, UserRole.photographer);
      return (repo: HttpPhotographerContactRepository(api: api), uid: uid);
    });

    contactLinkRepositoryContract(
      'HTTP',
      (world) async => HttpContactLinkRepository(api: _api(world.customer)),
    );
  });
}
```

```dart
// test/data/http/openapi_drift_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:yaml/yaml.dart';

/// The hand-written client against services/api/api/openapi.yaml: if the
/// contract changes, this fails until the app follows.
void main() {
  final doc = loadYaml(File('../services/api/api/openapi.yaml').readAsStringSync()) as YamlMap;
  final paths = doc['paths'] as YamlMap;
  final schemas = (doc['components'] as YamlMap)['schemas'] as YamlMap;

  YamlMap resolve(Object? node) {
    var n = node! as YamlMap;
    while (n.containsKey(r'$ref')) {
      n = schemas[(n[r'$ref'] as String).split('/').last] as YamlMap;
    }
    return n;
  }

  test('every call the app makes exists in the contract', () {
    for (final (method, path) in apiOperations) {
      final item = paths[path] as YamlMap?;
      expect(item, isNotNull, reason: path);
      expect(item![method.toLowerCase()], isNotNull, reason: '$method $path');
    }
  });

  test('ApiPaths builds exactly those paths', () {
    String fill(String template) => template.replaceAll(RegExp(r'\{\w+\}'), 'id1');
    expect(
      {
        ApiPaths.me,
        ApiPaths.user('id1'),
        ApiPaths.userRole('id1'),
        ApiPaths.userContact('id1'),
        ApiPaths.contactChannels('id1'),
        ApiPaths.contactNumbers('id1'),
        ApiPaths.serviceArea('id1'),
        ApiPaths.contactSetup('id1'),
        ApiPaths.contactLinks,
      },
      {for (final (_, p) in apiOperations) fill(p)},
    );
  });

  test('request bodies use only contract properties, and all required ones', () {
    void check(String name, Map<String, Object?> body) {
      final s = resolve(schemas[name]);
      final props = s['properties'] as YamlMap;
      final required = (s['required'] as YamlList?)?.cast<String>() ?? const <String>[];
      expect(props.keys.toSet().containsAll(body.keys), isTrue, reason: '$name: ${body.keys}');
      for (final r in required) {
        expect(body.containsKey(r), isTrue, reason: '$name needs $r');
      }
      for (final MapEntry(:key, :value) in body.entries) {
        final ref = (props[key] as YamlMap)[r'$ref'] as String?;
        if (value is Map<String, Object?> && ref != null) check(ref.split('/').last, value);
      }
    }

    check(
      'EnsureProfileRequest',
      ensureProfileBody(const AuthUser(uid: 'u1', displayName: 'Lan', photoUrl: 'https://x.test/a.jpg')),
    );
    check('UpdateUserRequest', updateUserBody('Lan'));
    check('SetRoleRequest', setRoleBody(UserRole.photographer));
    check('SaveUserContactRequest', saveContactBody(phone: '+84903123456', allowZalo: true, allowWhatsApp: false));
    check(
      'ContactSetupRequest',
      contactSetupBody(
        area: const ServiceArea(city: 'Hà Nội', radiusKm: 20),
        channels: const ContactChannels(call: true),
        numbers: const ContactNumbers(phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671'),
      ),
    );
    check('ContactLinkRequest', callableData(const ContactSubject.booking('b1'), ContactChannel.zalo));
  });

  test('response mappers accept a contract-shaped sample of every response schema', () {
    Object? sample(Object? node) {
      final s = resolve(node);
      final values = s['enum'] as YamlList?;
      if (values != null) return values.firstWhere((v) => v != null);
      return switch (s['type']) {
        'object' => {
          for (final key in (s['required'] as YamlList).cast<String>())
            key: sample((s['properties'] as YamlMap)[key]),
        },
        'boolean' => true,
        'integer' => 20,
        _ when s['format'] == 'date-time' => '2026-10-01T00:00:00Z',
        _ when (s['pattern'] as String?)?.contains('84') ?? false => '+84903123456',
        _ => 'id1',
      };
    }

    expect(() => profileFromJson(sample(schemas['UserProfile'])), returnsNormally);
    expect(() => userContactFromJson(sample(schemas['UserContact'])), returnsNormally);
    expect(() => channelsFromJson(sample(schemas['ContactChannels'])), returnsNormally);
    expect(() => numbersFromJson(sample(schemas['ContactNumbers'])), returnsNormally);
    expect(() => areaFromJson(sample(schemas['ServiceArea'])), returnsNormally);
    expect(() => parseLinkResponse(sample(schemas['ContactLinkResponse'])), returnsNormally);
  });
}
```

- [ ] **Step 3: Run the default suites and see them pass**

Run: `dart format test && flutter analyze && flutter test test/data/contracts test/data/http/openapi_drift_test.dart`
Expected: analyze clean; `+59 ~42: All tests passed!` (Fake 42, Firestore 13, drift 4 pass; the 42 HTTP tests are skipped). A Firestore failure means the Firebase adapter diverges from the port's documented behaviour: fix the adapter (or, if the fake Firestore lacks a feature, note it and keep the test), not the contract.

- [ ] **Step 4: Run the HTTP suite against the compose stack**

```bash
cd ../services/api && npm run build && docker compose up --build -d && docker compose run --rm api node dist/tools/seed-contract.js && cd ../../app_flutter
flutter test test/data/contracts/selfhosted_contracts_test.dart --tags selfhosted --dart-define=API_BASE_URL=http://localhost:8787
(cd ../services/api && docker compose down)
```

Expected: `contract world seeded`, then `+42: All tests passed!`. A failing `ctr_b_* zalo/whatsapp` case means phase 1's `contactUrl` and plan 2b's `contactUriFor` disagree: fix the one that departs from spec §3b.4.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock dart_test.yaml test/data/contracts test/data/http/openapi_drift_test.dart
git commit -m "test(data): shared repository contracts for Fake, Firestore and HTTP adapters, contract drift check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Data migration for the slice: Firestore → NDJSON → PostgreSQL

**Files:**
- Create: `services/api/tools/firestore-import/map.ts`, `services/api/tools/firestore-import/ndjson.ts`, `services/api/tools/firestore-import/export.ts`, `services/api/tools/firestore-import/firestore-source.ts`, `services/api/tools/firestore-import/memory-source.ts`, `services/api/tools/firestore-import/load.ts`, `services/api/tools/firestore-import/cli.ts`, `services/api/tools/firestore-import/map.test.ts`, `services/api/tools/firestore-import/export.test.ts`, `services/api/tools/firestore-import/load.test.ts`
- Modify: `services/api/package.json`, `services/api/package-lock.json`

**Interfaces:**
- Consumes: `createDb`, `Database` (Task 2); `findProfile` (Task 4, to prove imported avatars resolve); `resetDb`, `testDb` (test helpers). Firestore layout from `relational-schema.md` §3 and plans 2a/2b: `users/{uid}` (`displayName`, `avatarUrl`, `role`, `createdAt`, `updatedAt`), `users/{uid}/private/contact` (`phone`, `phoneVerified`, `allowZalo`, `allowWhatsApp`, `updatedAt`), `photographers/{uid}` (`bio`, `yearsExperience`, `verified`, `onboardingComplete`, `serviceArea{city, radiusKm, center?}`, `contactChannels{call, zalo, whatsapp, acceptInquiries}`, `createdAt`, `updatedAt`), `photographers/{uid}/private/contact` (`phone`, `zaloPhone?`, `whatsappPhone?`).
- Produces:
  - Pure mappers `toIso`, `mapUser`, `mapUserContact`, `mapPhotographer`, `mapPhotographerNumbers` returning `Mapped<T> = { ok: true; value: T } | { ok: false; reason: string }`, row types `FileRow`, `UserRow`, `UserContactRow`, `PhotographerRow`, `ChannelsRow`, `NumbersRow`; `avatarFileId(uid)`.
  - `interface DocSource { list(collection): AsyncIterable<SourceDoc>; get(path): Promise<Record<string, unknown> | null> }`; `firestoreSource(db: Firestore, pageSize?)` (paged by document id); `memorySource(docs)`.
  - `SLICE_TABLES` (FK order of `relational-schema.md` §5), `Manifest { schemaVersion: 1; source: 'firestore'; exportedAt; tables: Record<SliceTable, { rows; sha256 }>; rejected }`; `exportSlice(src, outDir, now?)` → `<table>.ndjson`, `rejected.ndjson` (source path + reason, never a value), `manifest.json`.
  - `loadSlice(db, dir, { dryRun }): Promise<LoadReport>` — verifies SHA-256 and row counts against the manifest, upserts in one transaction (unchanged rows are not touched, so a re-run is a no-op), checks that every exported id is in the database, rolls back on `--dry-run` or any mismatch; `class ImportCheckError`.
  - CLI: `npm run import:firestore -- export --out <dir>` and `npm run import:firestore -- load --in <dir> [--dry-run]`.

- [ ] **Step 1: Add the dependency and script**

```bash
npm install --save-dev firebase-admin@^13.0.1
```

In `services/api/package.json` add the script:

```json
    "import:firestore": "tsx tools/firestore-import/cli.ts",
```

- [ ] **Step 2: Write the failing tests**

```ts
// services/api/tools/firestore-import/memory-source.ts
import type { DocSource } from './export.js';

/** In-memory Firestore stand-in keyed by document path ("users/u1", "users/u1/private/contact"). */
export function memorySource(docs: Record<string, Record<string, unknown>>): DocSource {
  return {
    async *list(collection: string) {
      for (const [path, data] of Object.entries(docs)) {
        const parts = path.split('/');
        if (parts.length === 2 && parts[0] === collection) yield { id: parts[1]!, data };
      }
    },
    async get(path: string) {
      return docs[path] ?? null;
    },
  };
}

const ts = (iso: string) => ({ toDate: () => new Date(iso) });

/** Two valid users, one invalid id, one malformed customer phone, one orphan photographer. */
export const FIXTURE: Record<string, Record<string, unknown>> = {
  'users/u_lan': {
    displayName: 'Lan', role: 'customer', avatarUrl: 'https://lh3.googleusercontent.com/a/lan.jpg',
    createdAt: ts('2026-09-01T00:00:00Z'), updatedAt: ts('2026-09-02T00:00:00Z'),
  },
  'users/u_lan/private/contact': { phone: '+84903123456', allowZalo: true, allowWhatsApp: false, phoneVerified: false },
  'users/p_minh': { displayName: 'Minh', role: 'photographer' },
  'users/p_minh/private/contact': { phone: '0903123456' },
  'photographers/p_minh': {
    bio: 'Chân dung', yearsExperience: 5, onboardingComplete: true, verified: false,
    serviceArea: { city: 'Hà Nội', radiusKm: 20, center: { latitude: 21.03, longitude: 105.85 } },
    contactChannels: { call: true, zalo: true, whatsapp: false, acceptInquiries: true },
  },
  'photographers/p_minh/private/contact': { phone: '+84912345678', zaloPhone: '+84987654321' },
  'users/bad$id': { displayName: 'X' },
  'photographers/p_ghost': { bio: '' },
};
```

```ts
// services/api/tools/firestore-import/map.test.ts
import { describe, expect, it } from 'vitest';

import { mapPhotographer, mapPhotographerNumbers, mapUser, mapUserContact, toIso } from './map.js';

describe('Firestore → row mapping (relational-schema.md §3)', () => {
  it('turns Timestamps, Dates and ISO strings into ISO-8601 UTC; junk into null', () => {
    expect(toIso({ toDate: () => new Date('2026-09-01T07:00:00+07:00') })).toBe('2026-09-01T00:00:00.000Z');
    expect(toIso(new Date(Date.UTC(2026, 0, 1)))).toBe('2026-01-01T00:00:00.000Z');
    expect(toIso('2026-01-01T00:00:00Z')).toBe('2026-01-01T00:00:00.000Z');
    expect(toIso(1735689600000)).toBeNull();
    expect(toIso(undefined)).toBeNull();
  });

  it('users: keeps the uid, maps the avatar to an external file, rejects bad ids and roles', () => {
    const m = mapUser('u1', { displayName: 'Lan', role: 'customer', avatarUrl: 'https://x.test/a.jpg' });
    expect(m).toEqual({
      ok: true,
      value: {
        user: { id: 'u1', display_name: 'Lan', role: 'customer', avatar_file_id: 'avatar_u1', created_at: null, updated_at: null },
        file: { id: 'avatar_u1', storage_provider: 'external', storage_key: 'https://x.test/a.jpg', mime_type: 'image/*', size_bytes: 0, owner_user_id: 'u1' },
      },
    });
    expect(mapUser('a$b', {}).ok).toBe(false);
    expect(mapUser('u1', { role: 'admin' }).ok).toBe(false);
    expect(mapUser('u1', {})).toMatchObject({ ok: true, value: { user: { display_name: '', role: null }, file: null } });
  });

  it('user contacts: E.164 only, documented defaults', () => {
    expect(mapUserContact('u1', { phone: '+84903123456' })).toEqual({
      ok: true,
      value: { user_id: 'u1', phone_e164: '+84903123456', phone_verified: false, allow_zalo: true, allow_whatsapp: false, updated_at: null },
    });
    expect(mapUserContact('u1', { phone: '0903123456' })).toEqual({ ok: false, reason: 'phone is not E.164' });
  });

  it('photographers: flattened area, centre, flags and acceptInquiries', () => {
    const m = mapPhotographer('p1', {
      bio: 'x', yearsExperience: 60, onboardingComplete: true,
      serviceArea: { city: 'Huế', radiusKm: 15, center: { latitude: 16.46, longitude: 107.59 } },
      contactChannels: { zalo: true, acceptInquiries: false },
    });
    expect(m).toEqual({
      ok: true,
      value: {
        photographer: {
          user_id: 'p1', bio: 'x', years_experience: null, service_city: 'Huế', service_lat: 16.46, service_lng: 107.59,
          service_radius_km: 15, verified: false, onboarding_complete: true, accepts_inquiries: false, created_at: null, updated_at: null,
        },
        channels: { photographer_id: 'p1', call_enabled: false, zalo_enabled: true, whatsapp_enabled: false },
      },
    });
  });

  it('photographer numbers: main number required, optional ones must be valid when present', () => {
    expect(mapPhotographerNumbers('p1', { phone: '+84903123456' })).toEqual({
      ok: true, value: { photographer_id: 'p1', phone_e164: '+84903123456', zalo_phone_e164: null, whatsapp_phone_e164: null },
    });
    expect(mapPhotographerNumbers('p1', { phone: '+84903123456', whatsappPhone: '14155552671' }).ok).toBe(false);
    expect(mapPhotographerNumbers('p1', {}).ok).toBe(false);
  });
});
```

```ts
// services/api/tools/firestore-import/export.test.ts
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { exportSlice } from './export.js';
import { FIXTURE, memorySource } from './memory-source.js';
import { sha256 } from './ndjson.js';

describe('exportSlice', () => {
  it('writes one NDJSON file per table plus a manifest with counts and SHA-256', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'nag-export-'));
    const m = await exportSlice(memorySource(FIXTURE), dir, new Date('2026-10-01T00:00:00Z'));
    expect(Object.fromEntries(Object.entries(m.tables).map(([t, v]) => [t, v.rows]))).toEqual({
      files: 1, users: 2, user_contacts: 1, photographers: 1, photographer_contact_channels: 1, photographer_contact_numbers: 1,
    });
    expect(m).toMatchObject({ schemaVersion: 1, source: 'firestore', exportedAt: '2026-10-01T00:00:00.000Z', rejected: 3 });
    for (const [table, meta] of Object.entries(m.tables)) {
      expect(sha256(await readFile(join(dir, `${table}.ndjson`), 'utf8')), table).toBe(meta.sha256);
    }
    const manifest = JSON.parse(await readFile(join(dir, 'manifest.json'), 'utf8'));
    expect(manifest).toEqual(m);
  });

  it('lists what it skipped and why, without any value', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'nag-export-'));
    await exportSlice(memorySource(FIXTURE), dir);
    const text = await readFile(join(dir, 'rejected.ndjson'), 'utf8');
    expect(text.trim().split('\n').map((l) => JSON.parse(l))).toEqual([
      { source: 'users/p_minh/private/contact', reason: 'phone is not E.164' },
      { source: 'users/bad$id', reason: 'id is not [A-Za-z0-9_-]{1,64}' },
      { source: 'photographers/p_ghost', reason: 'no users document' },
    ]);
    expect(text).not.toContain('0903123456');
  });
});
```

```ts
// services/api/tools/firestore-import/load.test.ts
import { appendFile, mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { findProfile } from '../../src/repos/users.js';
import { resetDb, testDb } from '../../test/helpers.js';
import { exportSlice } from './export.js';
import { ImportCheckError, loadSlice } from './load.js';
import { FIXTURE, memorySource } from './memory-source.js';

const db = testDb();
afterAll(() => db.destroy());
beforeEach(() => resetDb(db));

async function exported(): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), 'nag-load-'));
  await exportSlice(memorySource(FIXTURE), dir);
  return dir;
}

const EXPECTED = {
  files: { file: 1, inDb: 1 },
  users: { file: 2, inDb: 2 },
  user_contacts: { file: 1, inDb: 1 },
  photographers: { file: 1, inDb: 1 },
  photographer_contact_channels: { file: 1, inDb: 1 },
  photographer_contact_numbers: { file: 1, inDb: 1 },
};

describe('loadSlice', () => {
  it('--dry-run checks everything and writes nothing', async () => {
    const report = await loadSlice(db, await exported(), { dryRun: true });
    expect(report).toEqual({ dryRun: true, tables: EXPECTED });
    expect(await db.selectFrom('users').selectAll().execute()).toEqual([]);
  });

  it('loads with ids kept, counts matching, and a second run changes nothing', async () => {
    const dir = await exported();
    expect(await loadSlice(db, dir, { dryRun: false })).toEqual({ dryRun: false, tables: EXPECTED });
    const before = await db.selectFrom('users').select(['id', 'updated_at']).orderBy('id').execute();
    expect(before.map((r) => r.id)).toEqual(['p_minh', 'u_lan']);
    expect(before[1]?.updated_at.toISOString()).toBe('2026-09-02T00:00:00.000Z');

    expect(await loadSlice(db, dir, { dryRun: false })).toEqual({ dryRun: false, tables: EXPECTED });
    const after = await db.selectFrom('users').select(['id', 'updated_at']).orderBy('id').execute();
    expect(after).toEqual(before);

    expect((await findProfile(db, 'u_lan'))?.avatarUrl).toBe('https://lh3.googleusercontent.com/a/lan.jpg');
    const numbers = await db.selectFrom('photographer_contact_numbers').selectAll().executeTakeFirstOrThrow();
    expect(numbers).toEqual({ photographer_id: 'p_minh', phone_e164: '+84912345678', zalo_phone_e164: '+84987654321', whatsapp_phone_e164: null });
  });

  it('a file that does not match its manifest stops the import before any write', async () => {
    const dir = await exported();
    await appendFile(join(dir, 'users.ndjson'), '{"id":"intruder","display_name":"x","role":null,"avatar_file_id":null,"created_at":null,"updated_at":null}\n');
    await expect(loadSlice(db, dir, { dryRun: false })).rejects.toBeInstanceOf(ImportCheckError);
    expect(await db.selectFrom('users').selectAll().execute()).toEqual([]);
  });
});
```

- [ ] **Step 3: Run and see them fail**

Run: `npm test -- tools/firestore-import`
Expected: FAIL, `Cannot find module './map.js'` (and `./export.js`, `./load.js`, `./ndjson.js`).

- [ ] **Step 4: Implement**

```ts
// services/api/tools/firestore-import/map.ts
/** Pure Firestore document → relational row mapping for the slice (relational-schema.md §3). */
const ID = /^[A-Za-z0-9_-]{1,64}$/;
const E164 = /^\+[0-9]{8,15}$/;

export type Mapped<T> = { ok: true; value: T } | { ok: false; reason: string };
const ok = <T>(value: T): Mapped<T> => ({ ok: true, value });
const fail = <T>(reason: string): Mapped<T> => ({ ok: false, reason });

type Doc = Record<string, unknown>;

export interface FileRow {
  id: string;
  storage_provider: 'external';
  storage_key: string;
  mime_type: string;
  size_bytes: number;
  owner_user_id: string;
}
export interface UserRow {
  id: string;
  display_name: string;
  role: 'customer' | 'photographer' | null;
  avatar_file_id: string | null;
  created_at: string | null;
  updated_at: string | null;
}
export interface UserContactRow {
  user_id: string;
  phone_e164: string;
  phone_verified: boolean;
  allow_zalo: boolean;
  allow_whatsapp: boolean;
  updated_at: string | null;
}
export interface PhotographerRow {
  user_id: string;
  bio: string;
  years_experience: number | null;
  service_city: string | null;
  service_lat: number | null;
  service_lng: number | null;
  service_radius_km: number | null;
  verified: boolean;
  onboarding_complete: boolean;
  accepts_inquiries: boolean;
  created_at: string | null;
  updated_at: string | null;
}
export interface ChannelsRow {
  photographer_id: string;
  call_enabled: boolean;
  zalo_enabled: boolean;
  whatsapp_enabled: boolean;
}
export interface NumbersRow {
  photographer_id: string;
  phone_e164: string;
  zalo_phone_e164: string | null;
  whatsapp_phone_e164: string | null;
}

/** Firestore Timestamp (has toDate()), Date or ISO string → ISO-8601 UTC; anything else → null. */
export function toIso(v: unknown): string | null {
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'object' && v !== null && typeof (v as { toDate?: unknown }).toDate === 'function') {
    return (v as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof v === 'string' && !Number.isNaN(Date.parse(v))) return new Date(v).toISOString();
  return null;
}

const asMap = (v: unknown): Doc | null => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Doc) : null);
const intIn = (v: unknown, min: number, max: number): number | null =>
  typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max ? v : null;
const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);

/** Deterministic, so a re-run upserts the same file row. */
export const avatarFileId = (uid: string): string => `avatar_${uid}`;

export function mapUser(id: string, d: Doc): Mapped<{ user: UserRow; file: FileRow | null }> {
  if (!ID.test(id)) return fail('id is not [A-Za-z0-9_-]{1,64}');
  const role = d.role ?? null;
  if (role !== null && role !== 'customer' && role !== 'photographer') return fail('unknown role');
  const url = typeof d.avatarUrl === 'string' && /^https?:\/\//.test(d.avatarUrl) ? d.avatarUrl : null;
  const fileId = avatarFileId(id);
  const file: FileRow | null =
    url && ID.test(fileId)
      ? { id: fileId, storage_provider: 'external', storage_key: url, mime_type: 'image/*', size_bytes: 0, owner_user_id: id }
      : null;
  return ok({
    user: {
      id,
      display_name: typeof d.displayName === 'string' ? d.displayName : '',
      role,
      avatar_file_id: file?.id ?? null,
      created_at: toIso(d.createdAt),
      updated_at: toIso(d.updatedAt),
    },
    file,
  });
}

export function mapUserContact(uid: string, d: Doc): Mapped<UserContactRow> {
  if (typeof d.phone !== 'string' || !E164.test(d.phone)) return fail('phone is not E.164');
  return ok({
    user_id: uid,
    phone_e164: d.phone,
    phone_verified: d.phoneVerified === true,
    allow_zalo: d.allowZalo !== false,
    allow_whatsapp: d.allowWhatsApp === true,
    updated_at: toIso(d.updatedAt),
  });
}

export function mapPhotographer(uid: string, d: Doc): Mapped<{ photographer: PhotographerRow; channels: ChannelsRow | null }> {
  const area = asMap(d.serviceArea);
  const center = asMap(area?.center);
  const channels = asMap(d.contactChannels);
  return ok({
    photographer: {
      user_id: uid,
      bio: typeof d.bio === 'string' ? d.bio : '',
      years_experience: intIn(d.yearsExperience, 0, 50),
      service_city: typeof area?.city === 'string' ? area.city : null,
      service_lat: num(center?.latitude),
      service_lng: num(center?.longitude),
      service_radius_km: intIn(area?.radiusKm, 1, 200),
      verified: d.verified === true,
      onboarding_complete: d.onboardingComplete === true,
      accepts_inquiries: channels?.acceptInquiries !== false,
      created_at: toIso(d.createdAt),
      updated_at: toIso(d.updatedAt),
    },
    channels: channels
      ? {
          photographer_id: uid,
          call_enabled: channels.call === true,
          zalo_enabled: channels.zalo === true,
          whatsapp_enabled: channels.whatsapp === true,
        }
      : null,
  });
}

export function mapPhotographerNumbers(uid: string, d: Doc): Mapped<NumbersRow> {
  if (typeof d.phone !== 'string' || !E164.test(d.phone)) return fail('phone is not E.164');
  const optional = (v: unknown): string | null | undefined =>
    v === undefined || v === null ? null : typeof v === 'string' && E164.test(v) ? v : undefined;
  const zalo = optional(d.zaloPhone);
  const whatsapp = optional(d.whatsappPhone);
  if (zalo === undefined) return fail('zaloPhone is not E.164');
  if (whatsapp === undefined) return fail('whatsappPhone is not E.164');
  return ok({ photographer_id: uid, phone_e164: d.phone, zalo_phone_e164: zalo, whatsapp_phone_e164: whatsapp });
}
```

```ts
// services/api/tools/firestore-import/ndjson.ts
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

export const sha256 = (text: string): string => createHash('sha256').update(text).digest('hex');

/** One JSON object per line, snake_case keys, trailing newline. */
export async function writeNdjson(path: string, rows: readonly object[]): Promise<{ rows: number; sha256: string }> {
  const text = rows.map((r) => `${JSON.stringify(r)}\n`).join('');
  await writeFile(path, text, 'utf8');
  return { rows: rows.length, sha256: sha256(text) };
}

export async function readNdjson<T>(path: string): Promise<{ rows: T[]; sha256: string }> {
  const text = await readFile(path, 'utf8');
  return {
    rows: text
      .split('\n')
      .filter((l) => l.length > 0)
      .map((l) => JSON.parse(l) as T),
    sha256: sha256(text),
  };
}
```

```ts
// services/api/tools/firestore-import/export.ts
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

import { mapPhotographer, mapPhotographerNumbers, mapUser, mapUserContact } from './map.js';
import { writeNdjson } from './ndjson.js';

/** relational-schema.md §5 order, restricted to the slice. */
export const SLICE_TABLES = [
  'files',
  'users',
  'user_contacts',
  'photographers',
  'photographer_contact_channels',
  'photographer_contact_numbers',
] as const;
export type SliceTable = (typeof SLICE_TABLES)[number];

export interface Manifest {
  schemaVersion: 1;
  source: 'firestore';
  exportedAt: string;
  tables: Record<SliceTable, { rows: number; sha256: string }>;
  rejected: number;
}

export interface SourceDoc {
  id: string;
  data: Record<string, unknown>;
}

export interface DocSource {
  list(collection: string): AsyncIterable<SourceDoc>;
  get(path: string): Promise<Record<string, unknown> | null>;
}

interface Rejected {
  source: string;
  reason: string;
}

export async function exportSlice(src: DocSource, outDir: string, now: Date = new Date()): Promise<Manifest> {
  const rows: Record<SliceTable, object[]> = {
    files: [], users: [], user_contacts: [], photographers: [], photographer_contact_channels: [], photographer_contact_numbers: [],
  };
  const rejected: Rejected[] = [];
  const userIds = new Set<string>();

  for await (const doc of src.list('users')) {
    const m = mapUser(doc.id, doc.data);
    if (!m.ok) {
      rejected.push({ source: `users/${doc.id}`, reason: m.reason });
      continue;
    }
    userIds.add(doc.id);
    rows.users.push(m.value.user);
    if (m.value.file) rows.files.push(m.value.file);
    const contact = await src.get(`users/${doc.id}/private/contact`);
    if (contact) {
      const c = mapUserContact(doc.id, contact);
      if (c.ok) rows.user_contacts.push(c.value);
      else rejected.push({ source: `users/${doc.id}/private/contact`, reason: c.reason });
    }
  }

  for await (const doc of src.list('photographers')) {
    if (!userIds.has(doc.id)) {
      rejected.push({ source: `photographers/${doc.id}`, reason: 'no users document' });
      continue;
    }
    const m = mapPhotographer(doc.id, doc.data);
    if (!m.ok) {
      rejected.push({ source: `photographers/${doc.id}`, reason: m.reason });
      continue;
    }
    rows.photographers.push(m.value.photographer);
    if (m.value.channels) rows.photographer_contact_channels.push(m.value.channels);
    const numbers = await src.get(`photographers/${doc.id}/private/contact`);
    if (numbers) {
      const n = mapPhotographerNumbers(doc.id, numbers);
      if (n.ok) rows.photographer_contact_numbers.push(n.value);
      else rejected.push({ source: `photographers/${doc.id}/private/contact`, reason: n.reason });
    }
  }

  await mkdir(outDir, { recursive: true });
  const tables = {} as Manifest['tables'];
  for (const t of SLICE_TABLES) tables[t] = await writeNdjson(join(outDir, `${t}.ndjson`), rows[t]);
  await writeNdjson(join(outDir, 'rejected.ndjson'), rejected);
  const manifest: Manifest = { schemaVersion: 1, source: 'firestore', exportedAt: now.toISOString(), tables, rejected: rejected.length };
  await writeFile(join(outDir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  return manifest;
}
```

```ts
// services/api/tools/firestore-import/firestore-source.ts
import { FieldPath, type Firestore, type QueryDocumentSnapshot } from 'firebase-admin/firestore';

import type { DocSource } from './export.js';

/**
 * Reads Firestore with firebase-admin, paged by document id. Points at the
 * emulator when FIRESTORE_EMULATOR_HOST is set, else at the project of
 * GOOGLE_APPLICATION_CREDENTIALS. Read-only.
 */
export function firestoreSource(db: Firestore, pageSize = 500): DocSource {
  return {
    async *list(collection: string) {
      let last: QueryDocumentSnapshot | undefined;
      for (;;) {
        let q = db.collection(collection).orderBy(FieldPath.documentId()).limit(pageSize);
        if (last) q = q.startAfter(last);
        const page = await q.get();
        for (const d of page.docs) yield { id: d.id, data: d.data() };
        if (page.size < pageSize) return;
        last = page.docs[page.docs.length - 1];
      }
    },
    async get(path: string) {
      const s = await db.doc(path).get();
      return s.exists ? (s.data() ?? null) : null;
    },
  };
}
```

```ts
// services/api/tools/firestore-import/load.ts
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import { sql, type Kysely, type Transaction } from 'kysely';

import type { Database } from '../../src/db/database.js';
import { SLICE_TABLES, type Manifest, type SliceTable } from './export.js';
import type { ChannelsRow, FileRow, NumbersRow, PhotographerRow, UserContactRow, UserRow } from './map.js';
import { readNdjson } from './ndjson.js';

export class ImportCheckError extends Error {}

export interface LoadReport {
  dryRun: boolean;
  tables: Record<SliceTable, { file: number; inDb: number }>;
}

class DryRunRollback extends Error {
  constructor(readonly report: LoadReport) {
    super('dry run');
  }
}

const PK: Record<SliceTable, string> = {
  files: 'id',
  users: 'id',
  user_contacts: 'user_id',
  photographers: 'user_id',
  photographer_contact_channels: 'photographer_id',
  photographer_contact_numbers: 'photographer_id',
};

const chunks = <T>(rows: T[], size = 500): T[][] =>
  Array.from({ length: Math.ceil(rows.length / size) }, (_, i) => rows.slice(i * size, (i + 1) * size));

const stamps = (r: { created_at?: string | null; updated_at: string | null }) => ({
  ...(r.created_at ? { created_at: r.created_at } : {}),
  ...(r.updated_at ? { updated_at: r.updated_at } : {}),
});

type Trx = Transaction<Database>;

// Every upsert skips rows whose values are unchanged, so no trigger fires and a re-run is a no-op.
async function upsertFiles(trx: Trx, rows: FileRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('files')
      .values(c.map((r) => ({ ...r, owner_user_id: null })))
      .onConflict((oc) =>
        oc
          .column('id')
          .doUpdateSet((eb) => ({ storage_key: eb.ref('excluded.storage_key') }))
          .where(sql<boolean>`files.storage_key is distinct from excluded.storage_key`),
      )
      .execute();
  }
}

async function upsertUsers(trx: Trx, rows: UserRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('users')
      .values(c.map((r) => ({ id: r.id, display_name: r.display_name, role: r.role, avatar_file_id: r.avatar_file_id, ...stamps(r) })))
      .onConflict((oc) =>
        oc
          .column('id')
          .doUpdateSet((eb) => ({
            display_name: eb.ref('excluded.display_name'),
            role: eb.ref('excluded.role'),
            avatar_file_id: eb.ref('excluded.avatar_file_id'),
          }))
          .where(sql<boolean>`(users.display_name, users.role, users.avatar_file_id)
            is distinct from (excluded.display_name, excluded.role, excluded.avatar_file_id)`),
      )
      .execute();
  }
}

async function setFileOwners(trx: Trx, rows: FileRow[]): Promise<void> {
  if (rows.length === 0) return;
  await sql`update files set owner_user_id = data.owner
    from unnest(${rows.map((r) => r.id)}::text[], ${rows.map((r) => r.owner_user_id)}::text[]) as data(id, owner)
    where files.id = data.id and files.owner_user_id is distinct from data.owner`.execute(trx);
}

async function upsertUserContacts(trx: Trx, rows: UserContactRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('user_contacts')
      .values(c.map((r) => ({
        user_id: r.user_id, phone_e164: r.phone_e164, phone_verified: r.phone_verified,
        allow_zalo: r.allow_zalo, allow_whatsapp: r.allow_whatsapp, ...stamps(r),
      })))
      .onConflict((oc) =>
        oc
          .column('user_id')
          .doUpdateSet((eb) => ({
            phone_e164: eb.ref('excluded.phone_e164'),
            phone_verified: eb.ref('excluded.phone_verified'),
            allow_zalo: eb.ref('excluded.allow_zalo'),
            allow_whatsapp: eb.ref('excluded.allow_whatsapp'),
          }))
          .where(sql<boolean>`(user_contacts.phone_e164, user_contacts.phone_verified, user_contacts.allow_zalo, user_contacts.allow_whatsapp)
            is distinct from (excluded.phone_e164, excluded.phone_verified, excluded.allow_zalo, excluded.allow_whatsapp)`),
      )
      .execute();
  }
}

async function upsertPhotographers(trx: Trx, rows: PhotographerRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('photographers')
      .values(c.map((r) => ({
        user_id: r.user_id, bio: r.bio, years_experience: r.years_experience, service_city: r.service_city,
        service_lat: r.service_lat, service_lng: r.service_lng, service_radius_km: r.service_radius_km,
        verified: r.verified, onboarding_complete: r.onboarding_complete, accepts_inquiries: r.accepts_inquiries,
        ...stamps(r),
      })))
      .onConflict((oc) =>
        oc
          .column('user_id')
          .doUpdateSet((eb) => ({
            bio: eb.ref('excluded.bio'),
            years_experience: eb.ref('excluded.years_experience'),
            service_city: eb.ref('excluded.service_city'),
            service_lat: eb.ref('excluded.service_lat'),
            service_lng: eb.ref('excluded.service_lng'),
            service_radius_km: eb.ref('excluded.service_radius_km'),
            verified: eb.ref('excluded.verified'),
            onboarding_complete: eb.ref('excluded.onboarding_complete'),
            accepts_inquiries: eb.ref('excluded.accepts_inquiries'),
          }))
          .where(sql<boolean>`(photographers.bio, photographers.years_experience, photographers.service_city,
              photographers.service_lat, photographers.service_lng, photographers.service_radius_km,
              photographers.verified, photographers.onboarding_complete, photographers.accepts_inquiries)
            is distinct from (excluded.bio, excluded.years_experience, excluded.service_city,
              excluded.service_lat, excluded.service_lng, excluded.service_radius_km,
              excluded.verified, excluded.onboarding_complete, excluded.accepts_inquiries)`),
      )
      .execute();
  }
}

async function upsertChannels(trx: Trx, rows: ChannelsRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('photographer_contact_channels')
      .values(c)
      .onConflict((oc) =>
        oc
          .column('photographer_id')
          .doUpdateSet((eb) => ({
            call_enabled: eb.ref('excluded.call_enabled'),
            zalo_enabled: eb.ref('excluded.zalo_enabled'),
            whatsapp_enabled: eb.ref('excluded.whatsapp_enabled'),
          }))
          .where(sql<boolean>`(photographer_contact_channels.call_enabled, photographer_contact_channels.zalo_enabled,
              photographer_contact_channels.whatsapp_enabled)
            is distinct from (excluded.call_enabled, excluded.zalo_enabled, excluded.whatsapp_enabled)`),
      )
      .execute();
  }
}

async function upsertNumbers(trx: Trx, rows: NumbersRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('photographer_contact_numbers')
      .values(c)
      .onConflict((oc) =>
        oc
          .column('photographer_id')
          .doUpdateSet((eb) => ({
            phone_e164: eb.ref('excluded.phone_e164'),
            zalo_phone_e164: eb.ref('excluded.zalo_phone_e164'),
            whatsapp_phone_e164: eb.ref('excluded.whatsapp_phone_e164'),
          }))
          .where(sql<boolean>`(photographer_contact_numbers.phone_e164, photographer_contact_numbers.zalo_phone_e164,
              photographer_contact_numbers.whatsapp_phone_e164)
            is distinct from (excluded.phone_e164, excluded.zalo_phone_e164, excluded.whatsapp_phone_e164)`),
      )
      .execute();
  }
}

/**
 * Loads an export into PostgreSQL in one transaction (data-model README §6 step 2):
 * checksums and counts first, then upserts in FK order, then every exported id
 * must be present. Any mismatch, or dryRun, rolls everything back.
 */
export async function loadSlice(db: Kysely<Database>, dir: string, opts: { dryRun: boolean }): Promise<LoadReport> {
  const manifest = JSON.parse(await readFile(join(dir, 'manifest.json'), 'utf8')) as Manifest;
  if (manifest.schemaVersion !== 1) throw new ImportCheckError(`unsupported schemaVersion ${String(manifest.schemaVersion)}`);
  const data = {} as Record<SliceTable, Record<string, unknown>[]>;
  for (const t of SLICE_TABLES) {
    const { rows, sha256 } = await readNdjson<Record<string, unknown>>(join(dir, `${t}.ndjson`));
    const meta = manifest.tables[t];
    if (sha256 !== meta.sha256) throw new ImportCheckError(`${t}.ndjson checksum does not match manifest.json`);
    if (rows.length !== meta.rows) throw new ImportCheckError(`${t}.ndjson has ${rows.length} rows, manifest says ${meta.rows}`);
    data[t] = rows;
  }

  try {
    return await db.transaction().execute(async (trx) => {
      await upsertFiles(trx, data.files as unknown as FileRow[]);
      await upsertUsers(trx, data.users as unknown as UserRow[]);
      await setFileOwners(trx, data.files as unknown as FileRow[]);
      await upsertUserContacts(trx, data.user_contacts as unknown as UserContactRow[]);
      await upsertPhotographers(trx, data.photographers as unknown as PhotographerRow[]);
      await upsertChannels(trx, data.photographer_contact_channels as unknown as ChannelsRow[]);
      await upsertNumbers(trx, data.photographer_contact_numbers as unknown as NumbersRow[]);

      const tables = {} as LoadReport['tables'];
      for (const t of SLICE_TABLES) {
        const ids = data[t].map((r) => String(r[PK[t]]));
        const r = await sql<{ n: number }>`select count(*)::int as n from ${sql.table(t)}
          where ${sql.ref(PK[t])} = any(${ids}::text[])`.execute(trx);
        const inDb = r.rows[0]?.n ?? 0;
        if (inDb !== ids.length) throw new ImportCheckError(`${t}: ${ids.length} exported, ${inDb} present after load`);
        tables[t] = { file: ids.length, inDb };
      }
      const report: LoadReport = { dryRun: opts.dryRun, tables };
      if (opts.dryRun) throw new DryRunRollback(report);
      return report;
    });
  } catch (e) {
    if (e instanceof DryRunRollback) return e.report;
    throw e;
  }
}
```

```ts
// services/api/tools/firestore-import/cli.ts
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { createDb } from '../../src/db/database.js';
import { exportSlice } from './export.js';
import { firestoreSource } from './firestore-source.js';
import { loadSlice } from './load.js';

const USAGE = `usage:
  import:firestore export --out <dir>         env FIREBASE_PROJECT_ID, and FIRESTORE_EMULATOR_HOST or GOOGLE_APPLICATION_CREDENTIALS
  import:firestore load --in <dir> [--dry-run] env DATABASE_URL`;

const [command, ...args] = process.argv.slice(2);
const flag = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

if (command === 'export') {
  const out = flag('--out');
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!out || !projectId) {
    console.error(USAGE);
    process.exit(2);
  }
  initializeApp({ projectId });
  const manifest = await exportSlice(firestoreSource(getFirestore()), out);
  console.table(Object.fromEntries(Object.entries(manifest.tables).map(([t, m]) => [t, { rows: m.rows }])));
  console.log(`rejected: ${manifest.rejected} (reasons in ${out}/rejected.ndjson)`);
} else if (command === 'load') {
  const dir = flag('--in');
  const url = process.env.DATABASE_URL;
  if (!dir || !url) {
    console.error(USAGE);
    process.exit(2);
  }
  const db = createDb(url, 2);
  try {
    const report = await loadSlice(db, dir, { dryRun: args.includes('--dry-run') });
    console.table(report.tables);
    console.log(report.dryRun ? 'dry run: checked and rolled back, nothing written' : 'loaded: counts match');
  } catch (e) {
    console.error(e instanceof Error ? e.message : String(e));
    process.exitCode = 1;
  } finally {
    await db.destroy();
  }
} else {
  console.error(USAGE);
  process.exit(2);
}
```

- [ ] **Step 5: Run and see them pass**

Run: `npm run typecheck && npm test`
Expected: typecheck clean; `Tests  142 passed (142)` (132 + map 5 + export 2 + load 3).

- [ ] **Step 6: Rehearse against the Firestore emulator**

With phase 1's emulator running (`firebase emulators:start --only firestore` from `app_flutter/firebase`, port 8080 per `firebase.json`) and some data in it, and the compose stack up:

```bash
FIREBASE_PROJECT_ID=demo-nag FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run import:firestore -- export --out ./export/rehearsal
DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag npm run import:firestore -- load --in ./export/rehearsal --dry-run
DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag npm run import:firestore -- load --in ./export/rehearsal
DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag npm run import:firestore -- load --in ./export/rehearsal
```

Expected: the export prints a table of row counts and `rejected: N`; the dry run prints the same counts with `file` = `inDb` and `dry run: checked and rolled back, nothing written`; both loads print the table and `loaded: counts match` (the second one changes no row). `./export/` is gitignored; it holds personal data, delete it after the rehearsal (`rm -r ./export/rehearsal`).

- [ ] **Step 7: Commit**

```bash
git add services/api
git commit -m "feat(api): idempotent Firestore to PostgreSQL import for the slice with dry run and count checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-backend-phase2-selfhosted-postgres.md"). Nothing to do here.
