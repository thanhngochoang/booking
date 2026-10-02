# Local Backend, Phase 1: Firebase Emulator Suite + Cloud Functions (TypeScript) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **Added 2026-10-02:** Tasks 10–14 implement spec `docs/superpowers/specs/2026-10-02-photographer-write-function-design.md`: the Firestore trigger `onPhotographerWrite` scores `photographers/{uid}.skills` ("Độ khớp hồ sơ") and removes evidence that is not the photographer's own post; S38 shows the server's number and no longer computes it on the device; CI tests and deploys the functions. They need Tasks 1–7 (domain package, functions project, emulator harness, CI) and plan 2c (done). Task 14 brings the **CI deploy of Cloud Functions** forward from "Out of scope: Cloud deploy" (the spec asks for it); App Check enforcement, production latency/cold-start measurement and the `minInstances` decision stay out of scope.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A developer runs the whole backend on their machine with one command (`scripts/backend-local.sh`): Auth, Firestore, Functions, Storage and the Emulator UI, with saved data and deterministic seed accounts. A debug build of the Flutter app started with `--dart-define=USE_EMULATORS=true` talks to it (Android emulator, Genymotion, iOS Simulator, real device). The first server function the client plans already rely on, `getContactLink`, is implemented with unit, emulator-integration and performance tests, together with a reusable server-side `requirePhone(uid)` guard.

**Architecture:** Business rules live in a new pure TypeScript package `packages/domain` (no Firebase, no Node imports; enforced by lint and a test), written as use cases over ports, so a self-hosted server can reuse it in phase 2 (data-model README §1.4, §3, §5). `app_flutter/firebase/functions` is a thin Firebase codebase: Firestore adapters for the ports, the `onCall` wrapper that maps domain errors to callable errors, and wiring. esbuild bundles `src/` plus `packages/domain` into `lib/index.js`, so the deployable folder never depends on a path outside itself. The emulator configuration extends the existing `app_flutter/firebase/firebase.json`. The Flutter app connects to the emulators only in debug builds that ask for it, from `main.dart` (the one place outside adapters allowed to import Firebase).

**Tech Stack:** Node 22+ (CI and the Cloud Functions runtime: `nodejs22`), TypeScript 5.9 strict, ESLint 9 + typescript-eslint 8, `node:test` run through `tsx` (same runner family as `firebase/rules-test`, which uses `node --test`), esbuild 0.28, `firebase-functions` 6 (v2 `onCall`), `firebase-admin` 13, `firebase-tools` ^14 (same as `rules-test`); Flutter: `cloud_functions`, `firebase_storage`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b.1–3b.2 (contact rules, `getContactLink`, `phone_required`), §3e.4–3e.5 (recommender phasing, `packages/recommender-core` precedent), §3g (escrow, later), §6 (order), §7 (tests); `docs/superpowers/specs/data-model/README.md` (§1 principles, §2 ids/time/money/enums/error codes, §3 ports, §4 authorization matrix: `photographer_contact_numbers` "người khác chỉ qua use case `get_contact_link`", `contact_access_log` Svc-only, §5 use cases); `docs/superpowers/specs/data-model/domain-model.md` (§2.7 `ContactAccessLog`, §4 `ErrorCode`, `ContactChannel`, §5 "Mở khoá liên hệ"); `services/recommender/README.md` (phase 1 = pure TS package without Firebase, wrapped later); **contract**: `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md` section "Out of scope: the server side" and Task 4 (`callableData`, `contactUriFor`, `linkErrorFromCode`, `FunctionsContactLinkRepository`), Task 7 (`contactAccessForBooking` boundaries).

**Prerequisite:** none for Tasks 1–7 and 9 (server side). Task 8 works with or without plan 2b executed (it edits 2b's adapter if present and its plan text either way). Running the app on **iOS** additionally needs a separate, not yet written "iOS enablement" plan (`flutterfire configure` for an iOS app, `GoogleService-Info.plist`, an iOS entry in `lib/firebase_options.dart`, which today only has Android and throws `UnsupportedError` elsewhere); this plan does the iOS emulator wiring so that plan only has to register the app.

## Decisions (read before Task 1)

| Topic | Decision | Why |
|---|---|---|
| Functions location | `app_flutter/firebase/functions/` | `firebase.json` resolves `functions[].source` relative to itself and already lives in `app_flutter/firebase/`, next to `firestore.rules` and `rules-test/`. One Firebase project folder, one `--config`. |
| Pure domain location | `packages/domain/` at the repo root (`@photobooking/domain`) | `services/recommender/README.md` and spec §3e.4 already put pure TypeScript packages in `packages/` (`packages/recommender-core`). A sibling package is reusable by a phase-2 server (e.g. `services/api/`) without importing anything from the Firebase folder. |
| Consuming the package | tsconfig `paths` alias `@photobooking/domain` → `../../../packages/domain/src/index`, resolved by `tsc`, `tsx` and esbuild; esbuild bundles it | No `file:` dependency, no npm workspaces (Cloud Functions deploys upload only the functions folder). `firebase-admin`/`firebase-functions` stay external. |
| Module format | ESM (`"type": "module"`), relative imports with `.js` extensions, `moduleResolution: Bundler` | Matches `rules-test` (ESM) and runs unbundled on Node later. |
| Region | `asia-southeast1` (Singapore) for every function | Closest Cloud Functions region to Vietnam. The client must call the same region (`FirebaseFunctions.instanceFor(region:)`); Task 8 makes it a single constant on both sides with tests that compare them. |
| Emulator project id | `scripts/backend-local.sh`: `$FIREBASE_PROJECT`, else `project_id` of `app_flutter/android/app/google-services.json`, else `demo-nag`. Tests and CI: always `demo-nag`. | On Android, the google-services plugin initialises the native default app with the real project id before Dart runs; `Firebase.initializeApp(options:)` then returns that app, so the app cannot be pointed at a `demo-*` id. The callable URL and the emulator data are keyed by project id, so the emulators must use the app's id. Safe because every SDK in play (Admin in functions and seed, client in the app) is routed to the emulators; the seed refuses to run unless both emulator hosts are local. |
| Hosts | `firebase.json` binds `127.0.0.1` (Android emulator via `10.0.2.2`, iOS Simulator). `--lan` writes a gitignored copy with `0.0.0.0` for Genymotion (`10.0.3.2`) and real devices. | Nothing is exposed on the LAN unless asked for. |
| Default app host | Android `10.0.2.2`, other platforms `127.0.0.1`; `--dart-define=EMULATOR_HOST=…` overrides (Genymotion `10.0.3.2`, real device = Mac LAN IP, or `127.0.0.1` with `adb reverse`). | Genymotion cannot be told apart from the Android emulator without a new dependency (`device_info_plus`); an explicit define is simpler and is printed by the script. |
| `ContactAccessLog` storage | Firestore collection `contact_access_log/{ulid}` (same name as the relational table), fields `requesterId, subjectType, subjectId, channel, granted, at`; client access denied by rules | domain-model §2.7, README §4 (`A` read, `Svc` write). |
| Error mapping | `HttpsError(<transport code>, <domain code>, {code: <domain code>})`; unauthenticated → `HttpsError('unauthenticated', 'permission_denied', {code: 'permission_denied'})` | The client (`FunctionsContactLinkRepository`) reads `details.code`, falling back to the message; only `contact_locked` is special. |
| Registration subject | Request shape accepted and domain rule implemented and tested; production wiring has no registration reader yet, so `registrationId` answers `not_found` (and is logged) | Event registrations do not exist yet (plan 3b of the spec adds them and plugs a `RegistrationReader` into `liveContactDeps`). |
| `reviewed` bookings | Unlocked for 30 days after completion, like `completed` | Matches the client's `contactAccessForBooking` (2b Task 7), which the app already uses as the UI hint. |
| App Check | Not enforced (`enforceAppCheck: false`) in phase 1 | The emulators do not verify App Check tokens; the cloud deploy plan enables it with the client provider. |
| Package versions | `firebase-functions` ^6.6, `firebase-admin` ^13.10, `typescript` ^5.9 | `firebase-functions` 7 / `firebase-admin` 14 and TypeScript 7 exist, but 6/13 are the versions known to work with `firebase-tools` ^14 and with typescript-eslint 8 (`typescript <6.1`). |

## Out of scope: later plans

Marked here so nobody adds them to this plan:

- **`transitionBooking`** (all booking transitions, `phone_required` via `makeRequirePhone` from Task 6, `bookings.customerContact` snapshot, `AvailabilityDay`, notifications).
- **`createDeposit` / payments** (`paymentWebhook`, MoMo/VNPay, escrow `held → released`, ledger, refunds, payouts).
- **`registerEvent`** and the rest of events (registration reader for `getContactLink`, `cancelRegistration`, `checkInRegistration`).
- **`recommend` / `recommendFeedback`** with `packages/recommender-core`.
- **Scheduled jobs** (`expire_requests`, `releaseExpiredHolds`, `closeEvents`, `releaseEscrow`, redacting `customerContact` 30 days after completion).
- **Cloud deploy** (real project deploy, App Check enforcement, IAM, production latency and cold-start measurement, `minInstances` decision) and **iOS enablement**.

## Global Constraints

- **Node commands** (Tasks 1–7, 9): from the repo root, once per shell: `source scripts/env.sh >/dev/null && export HOME="$PWD/.home"` (JDK 17 for the Firestore emulator, `NODE_EXTRA_CA_CERTS` for the corporate TLS gateway, tool caches inside the repo). Then `cd` into the package named by the step. Node ≥ 22 (`node -v`); CI uses 22, a newer local Node is fine.
- **Flutter commands** (Task 8, 9): from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint; `flutter analyze` fails on infos).
- **Sandbox notes (Claude Code):** `allowLocalBinding: true` is already set in `.claude/settings.local.json`. `npm install` needs `registry.npmjs.org`; the first emulator start downloads the emulator jars from `storage.googleapis.com` (cached under `.home/.cache/firebase/emulators`). The **Functions emulator listens on a Unix socket in `$TMPDIR`**; inside the Claude Code sandbox that fails with `Error: listen EPERM: operation not permitted …/fire_emu_….sock` and every callable returns an error. Run `npm run test:integration`, `npm run test:perf` and `scripts/backend-local.sh` outside the sandbox (or allow Unix sockets in the sandbox settings); unit tests and rules tests run inside it. npm 11 prints `npm warn install-scripts` for `esbuild` and `re2`: harmless (esbuild ships its binary as an optional dependency; `re2` is optional for firebase-tools).
- **Purity:** nothing in `packages/domain/src` imports anything but its own modules (no `firebase*`, `@google-cloud/*`, `node:*`); `packages/domain` has no runtime dependencies. Functions code holds no business rule: checks belong in the domain package.
- **Data conventions** (`data-model/README.md` §2): ids are opaque `[A-Za-z0-9_-]{1,64}` (new ids are ULIDs), instants are UTC (`Date` in TS, `Timestamp` only inside adapters), money is integer VND, enums are string codes, error codes are the `ErrorCode` list.
- **Contact rules (product decisions, do not weaken):** a photographer number leaves the server only inside the URL returned by `getContactLink`, only to the customer of an unlocked subject, only for a channel the photographer switched on. No number in responses outside `url`, in `ContactAccessLog`, in error messages or in logs. Every well-formed request writes exactly one `ContactAccessLog` row (granted or refused) before it is answered; if the row cannot be written, the call fails.
- **URL formats** (identical to the client's `contactUriFor`): `tel:+84…`, `https://zalo.me/<digits>`, `https://wa.me/<digits>` (no `+`); Zalo uses `zaloPhone ?? phone`, WhatsApp `whatsappPhone ?? phone`.
- **Flutter Firebase isolation:** `cloud_functions`, `firebase_storage` and the other `firebase_*` packages only in `lib/data/**` adapters, `lib/firebase_options.dart` and `lib/main.dart`. Emulators are used only when `kDebugMode` and `--dart-define=USE_EMULATORS=true`; release and profile builds can never reach them.
- **Test values only:** seed accounts use `@seed.test` addresses and a documented test password; seed numbers are fictional. The seed writes only to emulators.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Emulator tests in Tasks 10–14 run on CI only** (rule 2026-10-02): write `test/integration/*` and the rules tests, never run `npm run test:integration` or `rules-test` `npm test` locally, and do not wait for an emulator `Expected:`. Unit tests run locally: `npm test` (node `--test` through `tsx`) and `flutter test --no-pub`.
- **Server-owned skills fields (Tasks 10–14):** `skills.completeness` (0–100), `skills.completenessNext` (`specialties | levels | evidence | styles | languages | audiences | extras`, or `null` at 100), `skills.updatedAt`, `skills.evidenceRemovedAt` are written only by `onPhotographerWrite` through the Admin SDK. The app never computes the score or the next step. Weights (spec 3e.2): specialties 25, levels 20, evidence for every level-3 genre 20, styles 10, languages 10, audiences 10, extras 5.
- **Trigger options (Task 11):** Firestore v2 `onDocumentWritten('photographers/{uid}')`, region `asia-southeast1`, `memory 256MiB`, `timeoutSeconds 30`, `maxInstances 10`, `minInstances 0`, `retry: true`.
- **Evidence:** at most 18 post ids per run, read in one `db.getAll`; a post counts when it exists, has no `deletedAt`, and its owner (`authorId`, else `photographerId`, the same rule as the app's `postFromFirestore`) is the photographer. A level-3 genre left without evidence becomes level 2.
- **Deploy only through CI** (`firebase-deploy.yml` job `deploy-functions`); never `firebase deploy` from a machine.
- **Flutter commands (Task 13):** as for Task 8; run tests with `flutter test --no-pub` and `flutter analyze --no-pub`.

## Review Focus (Tasks 10–14)

- **Trigger re-entry loop:** the Function's own write changes only server fields, so the next run must stop at `unchanged` before any read; after a write that also cleaned `specialties`, the next run reads once, finds the stored score current (`up_to_date`) and writes nothing, so there is never a third write. Pinned by Task 10 (`unchanged`, `up_to_date` tests) and Task 11 (integration "saving the same skills again writes nothing more").
- **A user save while the Function runs:** the update carries `precondition: { lastUpdateTime }` of the snapshot the trigger got; a newer save makes it fail with FAILED_PRECONDITION (or NOT_FOUND after a delete), the Function returns `stale` without retrying, and the trigger of the newer save scores it. Pinned by Task 10 (`stale`) and Task 11 (`isStaleWriteError`, deleted-document writer).
- **Evidence of a deleted post** (document gone, or `deletedAt` set), of another photographer, or of a customer's real-shoot post is removed, a level-3 genre without evidence drops to level 2, `evidenceRemovedAt` is set and S38 says so once per removal. Pinned by Task 10 (`isOwnEvidencePost`, `cleanEvidence`, use case), Task 11 (integration) and Task 13 (SnackBar once, a newer removal shows again).
- **A profile with no skills:** a `photographers/{uid}` document without `skills` is left untouched; skills with no genre score 10 (Vietnamese) with next step `specialties`; a profile never scored shows "Chưa có điểm" + "Lưu để tính độ khớp" on S38. Pinned by Tasks 10, 11 (integration) and 13.
- **A malformed skills map:** not a map or `schemaVersion !== 1` → `warn` log, nothing written; malformed entries inside a schema-1 map are read tolerantly like `skillsFromMap` (dropped, bad level → 2, duplicates once) and an evidence id that is not an opaque id (`a/b`) is never read (a `doc('a/b')` would throw and retry forever) and is removed; malformed server fields read by the app become `null`. Pinned by Tasks 10, 11 and 13.

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/package.json`, `tsconfig.json`, `eslint.config.js`, `.gitignore` (create) | Pure package tooling; lint bans Firebase/Node imports in `src/` |
| `packages/domain/src/errors.ts` (create) | `ERROR_CODES`, `ErrorCode`, `DomainError` |
| `packages/domain/src/ids.ts` (create) | `isId`, `newUlid` |
| `packages/domain/src/phone.ts` (create) | `normalizePhone`, `isVnE164`, `isInternationalE164` (same rules as the Dart `phone.dart`) |
| `packages/domain/src/contact.ts` (create) | channels, `contactUrlFor`, `bookingContactUnlocked`, `ticketContactUnlocked`, `parseContactLinkRequest` |
| `packages/domain/src/ports.ts` (create) | `Clock`, `IdGenerator`, readers, `ContactAccessLogWriter` |
| `packages/domain/src/require_phone.ts` (create) | `requirePhone`, `requireCustomerPhone` |
| `packages/domain/src/get_contact_link.ts` (create) | use case `getContactLink` |
| `packages/domain/src/index.ts` (create) | barrel |
| `packages/domain/test/*.test.ts`, `test/client_allow_list.ts` (create) | unit tests; TS port of the client URL allow-list |
| `app_flutter/firebase/firebase.json` (modify) | functions codebase, storage, all emulators, UI, ports |
| `app_flutter/firebase/storage.rules`, `.gitignore` (create) | deny-all storage rules; ignore emulator data, LAN config, build output |
| `app_flutter/firebase/firestore.rules`, `rules-test/rules.test.mjs` (modify) | `contact_access_log` server-only + test |
| `app_flutter/firebase/functions/package.json`, `tsconfig.json`, `eslint.config.js`, `build.mjs` (create) | Functions tooling and bundling |
| `app_flutter/firebase/functions/src/config.ts` (create) | `REGION`, `CALLABLE_OPTIONS` |
| `app_flutter/firebase/functions/src/callables/errors.ts`, `get_contact_link.ts` (create) | `toHttpsError`, `handleGetContactLink` |
| `app_flutter/firebase/functions/src/infra/admin.ts`, `firestore.ts`, `live.ts`, `require_phone.ts` (create) | Admin init, Firestore adapters, wiring, `makeRequirePhone` |
| `app_flutter/firebase/functions/src/index.ts` (create) | exports `getContactLink` |
| `app_flutter/firebase/functions/seed/fixtures.ts`, `apply.ts`, `seed.ts`, `emulator_client.ts`, `try_contact_link.ts`, `README.md` (create) | seed data, CLI, emulator REST client, manual call helper, account list |
| `app_flutter/firebase/functions/test/unit/*`, `test/integration/*`, `test/perf/*` (create) | tests |
| `scripts/backend-local.sh` (create) | the one command |
| `app_flutter/README.md`, `CLAUDE.md`, `.github/workflows/flutter.yml`, `docs/superpowers/specs/data-model/relational-schema.md` (modify) | docs, CI, mapping row |
| `app_flutter/pubspec.yaml`, `pubspec.lock` (modify) | `cloud_functions`, `firebase_storage` |
| `app_flutter/lib/data/backend/backend_config.dart` (create) | `functionsRegion`, `EmulatorConfig`, `resolveEmulatorConfig` |
| `app_flutter/lib/main.dart` (modify) | connect to the emulators |
| `app_flutter/android/app/src/debug/AndroidManifest.xml` (modify), `android/app/src/debug/res/xml/network_security_config.xml` (create) | debug-only cleartext |
| `app_flutter/ios/Runner/Info.plist` (modify) | `NSAllowsLocalNetworking` |
| `app_flutter/lib/data/contact/functions_contact_link_repository.dart` (modify if present), plan 2b text (modify) | region + timeout |
| `app_flutter/test/data/backend/*.dart`, `test/emulator_platform_config_test.dart` (create) | Flutter tests |
| `packages/domain/src/skills.ts`, `src/score_skills.ts`, `test/skills.test.ts`, `test/score_skills.test.ts`, `test/fixtures/skills_completeness.json` (create, Task 10) | `parseSkills`, evidence rules, `skillsCompleteness`, loop guard; use case `scorePhotographerSkills` over ports; shared score table |
| `app_flutter/firebase/functions/src/infra/skills_firestore.ts`, `src/infra/live_skills.ts`, `src/triggers/photographer_write.ts`, `test/unit/photographer_write.test.ts`, `test/integration/photographer_write.test.ts` (create, Task 11); `src/config.ts`, `src/index.ts` (modify) | posts reader, preconditioned writer, wiring, trigger `onPhotographerWrite` |
| `app_flutter/firebase/firestore.rules`, `rules-test/rules.test.mjs` (modify, Task 12) | pin `completenessNext`, `evidenceRemovedAt` |
| `app_flutter/lib/data/skills/skills_server_info.dart` (create), `skills_repository.dart`, `firestore_skills_repository.dart`, `skills_providers.dart`, `lib/core/widgets/completeness_meter.dart`, `lib/features/skills/*` (modify), `lib/data/skills/skills_completeness.dart` (delete) (Task 13) | S38 shows the server score |
| `.github/workflows/flutter.yml`, `firebase-deploy.yml`, `docs/FIREBASE-SETUP.md`, specs, mock, plan 2d2 (modify, Task 14) | CI job, deploy job, setup, docs |

---

### Task 1: `packages/domain` scaffold, error codes, ids and phone rules

**Files:**
- Create: `packages/domain/package.json`, `packages/domain/tsconfig.json`, `packages/domain/eslint.config.js`, `packages/domain/.gitignore`, `packages/domain/src/errors.ts`, `packages/domain/src/ids.ts`, `packages/domain/src/phone.ts`, `packages/domain/src/index.ts`, `packages/domain/test/phone.test.ts`, `packages/domain/test/ids.test.ts`, `packages/domain/test/purity.test.ts`

**Interfaces:**
- Consumes: the phone rules and test vectors of plan 2a Task 1 (`lib/core/phone.dart`).
- Produces:
  - `const ERROR_CODES: readonly ['day_taken','phone_required','contact_locked','sold_out','deadline_passed','limit_exceeded','invalid_argument','permission_denied','not_found','conflict']`, `type ErrorCode`, `class DomainError extends Error { readonly code: ErrorCode }`, `isDomainError(e: unknown): e is DomainError`.
  - `isId(v: unknown): v is string`, `newUlid(nowMs: number, random?: (length: number) => Uint8Array): string`.
  - `normalizePhone(input: string, options?: { international?: boolean }): string | null`, `isVnE164(v: unknown): v is string`, `isInternationalE164(v: unknown): v is string`.

- [ ] **Step 1: Create the package tooling and install**

```json
// packages/domain/package.json
{
  "name": "@photobooking/domain",
  "version": "0.1.0",
  "private": true,
  "description": "Backend-agnostic business rules (no Firebase). Used by Cloud Functions now and by a self-hosted server later.",
  "type": "module",
  "exports": { ".": "./src/index.ts" },
  "engines": { "node": ">=22" },
  "scripts": {
    "typecheck": "tsc -p tsconfig.json",
    "lint": "eslint .",
    "test": "node --import tsx --test \"test/**/*.test.ts\""
  },
  "devDependencies": {
    "@eslint/js": "^9.39.0",
    "@types/node": "^22.20.0",
    "eslint": "^9.39.0",
    "tsx": "^4.23.0",
    "typescript": "^5.9.3",
    "typescript-eslint": "^8.71.0"
  }
}
```

(JSON has no comments: the `// path` line above each block names the file; do not write it into the file.)

```json
// packages/domain/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2023",
    "lib": ["ES2023"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["node"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["src", "test"]
}
```

```js
// packages/domain/eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules/**'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['**/*.js'],
    languageOptions: { globals: { process: 'readonly', console: 'readonly' } },
  },
  {
    files: ['src/**/*.ts'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [{
          group: ['firebase', 'firebase/*', 'firebase-admin', 'firebase-admin/*', 'firebase-functions',
            'firebase-functions/*', '@firebase/*', '@google-cloud/*', 'node:*'],
          message: 'packages/domain is backend-agnostic: no Firebase, Google Cloud or Node imports in src/.',
        }],
      }],
    },
  },
);
```

```gitignore
# packages/domain/.gitignore
node_modules/
```

Run (from `packages/domain`): `npm install`
Expected: `package-lock.json` created; `npm warn install-scripts … esbuild` is harmless.

- [ ] **Step 2: Write the failing tests**

```ts
// packages/domain/test/phone.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { isInternationalE164, isVnE164, normalizePhone } from '../src/index.js';

// Same vectors as app_flutter/test/core/phone_test.dart (plan 2a, Task 1).
describe('normalizePhone', () => {
  const valid: Record<string, string> = {
    '0903123456': '+84903123456',
    '+84 903 123 456': '+84903123456',
    '0903.123.456': '+84903123456',
    '(090) 312-3456': '+84903123456',
    '+84903123456': '+84903123456',
    '0321234567': '+84321234567',
  };
  for (const [input, e164] of Object.entries(valid)) {
    test(`accepts ${input}`, () => assert.equal(normalizePhone(input), e164));
  }

  const invalid = [
    '', '090312345', '0123456789', '09031234567', '0203123456',
    '+84 023 123 456', '+14155552671', 'abc', '0903 123 45a',
  ];
  for (const input of invalid) {
    test(`rejects "${input}"`, () => assert.equal(normalizePhone(input), null));
  }

  test('international accepts other countries, still rejects malformed +84', () => {
    assert.equal(normalizePhone('+1 415 555 2671', { international: true }), '+14155552671');
    assert.equal(normalizePhone('+84012345678', { international: true }), null);
    assert.equal(normalizePhone('+123', { international: true }), null);
  });
});

describe('stored-number checks', () => {
  test('isVnE164 only accepts the stored Vietnamese form', () => {
    assert.equal(isVnE164('+84903123456'), true);
    for (const v of ['0903123456', '+8490312345', '+84123456789', '+14155552671', 84903123456, null, undefined]) {
      assert.equal(isVnE164(v), false, String(v));
    }
  });

  test('isInternationalE164 accepts + and 8-15 digits', () => {
    assert.equal(isInternationalE164('+14155552671'), true);
    assert.equal(isInternationalE164('+84903123456'), true);
    for (const v of ['14155552671', '+123', '+1234567890123456', '+1 415', 5]) {
      assert.equal(isInternationalE164(v), false, String(v));
    }
  });
});
```

```ts
// packages/domain/test/ids.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { isId, newUlid } from '../src/index.js';

describe('ids', () => {
  test('isId accepts opaque 1-64 char ids and refuses paths', () => {
    for (const ok of ['a', 'seed-booking-accepted', 'AbC_123-x', '01ARYZ6S41TSV4RRFFQ69G5FAV', 'x'.repeat(64)]) {
      assert.equal(isId(ok), true, ok);
    }
    for (const bad of ['', 'x'.repeat(65), 'a/b', '../x', 'a b', 'ä', 5, null]) {
      assert.equal(isId(bad), false, String(bad));
    }
  });

  test('newUlid encodes the time like the ULID spec', () => {
    const zeros = (n: number) => new Uint8Array(n);
    assert.equal(newUlid(1469918176385, zeros), `01ARYZ6S41${'0'.repeat(16)}`);
    assert.equal(newUlid(0, zeros), '0'.repeat(26));
  });

  test('newUlid is 26 Crockford characters, a valid id, and sorts by time', () => {
    const a = newUlid(1_700_000_000_000);
    const b = newUlid(1_700_000_000_001);
    assert.match(a, /^[0-9A-HJKMNP-TV-Z]{26}$/);
    assert.equal(isId(a), true);
    assert.ok(a < b);
  });

  test('newUlid gives different ids in the same millisecond', () => {
    const ids = new Set(Array.from({ length: 1000 }, () => newUlid(1_700_000_000_000)));
    assert.equal(ids.size, 1000);
  });

  test('newUlid refuses times outside 48 bits', () => {
    assert.throws(() => newUlid(-1), RangeError);
    assert.throws(() => newUlid(2 ** 48), RangeError);
    assert.throws(() => newUlid(1.5), RangeError);
  });
});
```

```ts
// packages/domain/test/purity.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

function sources(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sources(path);
    return path.endsWith('.ts') ? [path] : [];
  });
}

const specifiers = (code: string): string[] =>
  [...code.matchAll(/(?:import|export)\s[^'"]*?from\s+['"]([^'"]+)['"]/g)].map((m) => m[1] ?? '');

test('domain source imports only its own modules (no Firebase, no Node APIs)', () => {
  const offenders = sources(join(root, 'src')).flatMap((file) =>
    specifiers(readFileSync(file, 'utf8'))
      .filter((s) => !s.startsWith('./') && !s.startsWith('../'))
      .map((s) => `${file}: ${s}`));
  assert.deepEqual(offenders, []);
});

test('domain package has no runtime dependencies', () => {
  const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')) as { dependencies?: unknown };
  assert.equal(pkg.dependencies, undefined);
});
```

- [ ] **Step 3: Run and see it fail**

Run (from `packages/domain`): `npm test`
Expected: FAIL. `phone.test.ts` and `ids.test.ts` stop with `ERR_MODULE_NOT_FOUND` for `src/index.js`; `purity.test.ts` fails with `ENOENT` on `src`.

- [ ] **Step 4: Implement**

```ts
// packages/domain/src/errors.ts
/** Stable business error codes (data-model/domain-model.md §4 `ErrorCode`). */
export const ERROR_CODES = [
  'day_taken',
  'phone_required',
  'contact_locked',
  'sold_out',
  'deadline_passed',
  'limit_exceeded',
  'invalid_argument',
  'permission_denied',
  'not_found',
  'conflict',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/** A refused use case. The message is the code itself, so nothing else can leak. */
export class DomainError extends Error {
  constructor(readonly code: ErrorCode) {
    super(code);
    this.name = 'DomainError';
  }
}

export const isDomainError = (e: unknown): e is DomainError => e instanceof DomainError;
```

```ts
// packages/domain/src/ids.ts
const ID = /^[A-Za-z0-9_-]{1,64}$/;

/** Opaque id (data-model README §2.1): 1–64 chars of `[A-Za-z0-9_-]`, so never a path. */
export const isId = (v: unknown): v is string => typeof v === 'string' && ID.test(v);

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const MAX_TIME = 2 ** 48 - 1;

export type RandomBytes = (length: number) => Uint8Array;

const systemRandom: RandomBytes = (length) => globalThis.crypto.getRandomValues(new Uint8Array(length));

/** ULID: 10 chars of millisecond time + 16 random chars, Crockford base32, sorts by time. */
export function newUlid(nowMs: number, random: RandomBytes = systemRandom): string {
  if (!Number.isInteger(nowMs) || nowMs < 0 || nowMs > MAX_TIME) {
    throw new RangeError('ULID time must be an integer between 0 and 2^48 - 1');
  }
  let time = '';
  let t = nowMs;
  for (let i = 0; i < 10; i++) {
    time = CROCKFORD.charAt(t % 32) + time;
    t = Math.floor(t / 32);
  }
  const bytes = random(16);
  let rest = '';
  for (let i = 0; i < 16; i++) rest += CROCKFORD.charAt((bytes[i] ?? 0) % 32);
  return time + rest;
}
```

```ts
// packages/domain/src/phone.ts
// Same rules as app_flutter/lib/core/phone.dart (plan 2a), so client and server agree.
const VN = /^(?:\+84|0)([35789]\d{8})$/;
const VN_E164 = /^\+84[35789]\d{8}$/;
const INTERNATIONAL = /^\+\d{8,15}$/;

const compact = (s: string): string => s.replace(/[\s.\-()]/g, '');

/**
 * E.164 for a valid number, else null. Spaces, dots, dashes and brackets are ignored.
 * `international` also accepts other countries (`+` and 8–15 digits), for WhatsApp.
 */
export function normalizePhone(input: string, options: { international?: boolean } = {}): string | null {
  const s = compact(input);
  const national = VN.exec(s)?.[1];
  if (national !== undefined) return `+84${national}`;
  // A malformed +84 number must not slip through as "international".
  if (options.international === true && !s.startsWith('+84') && INTERNATIONAL.test(s)) return s;
  return null;
}

/** The stored form of a Vietnamese number: `+84` and 9 digits starting with 3, 5, 7, 8 or 9. */
export const isVnE164 = (v: unknown): v is string => typeof v === 'string' && VN_E164.test(v);

/** Any stored international number: `+` and 8–15 digits (WhatsApp's own number). */
export const isInternationalE164 = (v: unknown): v is string => typeof v === 'string' && INTERNATIONAL.test(v);
```

```ts
// packages/domain/src/index.ts
export * from './errors.js';
export * from './ids.js';
export * from './phone.js';
```

- [ ] **Step 5: Run and see it pass**

Run (from `packages/domain`): `npm run typecheck && npm run lint && npm test`
Expected: typecheck and lint print nothing after their headers; the test summary ends with `ℹ tests 25`, `ℹ pass 25`, `ℹ fail 0`.

- [ ] **Step 6: Commit**

```bash
git add packages/domain
git commit -m "feat(domain): pure TypeScript package with error codes, ULIDs and phone rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Contact rules and the `requirePhone` guard (pure)

**Files:**
- Create: `packages/domain/src/contact.ts`, `packages/domain/src/ports.ts`, `packages/domain/src/require_phone.ts`, `packages/domain/test/client_allow_list.ts`, `packages/domain/test/contact.test.ts`, `packages/domain/test/require_phone.test.ts`
- Modify: `packages/domain/src/index.ts`

**Interfaces:**
- Consumes: Task 1 (`DomainError`, `isId`, `isVnE164`, `isInternationalE164`); the client contract of plan 2b Task 4 (`callableData`, `contactUriFor`, `isAllowedContactUri`) and Task 7 (`contactAccessForBooking`: 30 days inclusive, unknown completion locked, `reviewed` like `completed`).
- Produces:
  - `type ContactChannel = 'in_app' | 'call' | 'zalo' | 'whatsapp'`, `type ExternalChannel`, `EXTERNAL_CHANNELS`, `isExternalChannel(v)`.
  - `interface ContactChannels { call; zalo; whatsapp }` (booleans), `interface ContactNumbers { phone: string; zaloPhone?: string | null; whatsappPhone?: string | null }`.
  - `numberFor(channel, numbers): string`, `contactUrlFor(channel: ExternalChannel, numbers: ContactNumbers): string | null`.
  - `bookingContactUnlocked({status, completedAt: Date | null}, now: Date): boolean`, `ticketContactUnlocked({status, eventEndsAt: Date | null}, now: Date): boolean`, `BOOKING_CONTACT_DAYS = 30`, `TICKET_CONTACT_DAYS = 7`.
  - `type ContactSubject = {type: 'booking'; id} | {type: 'event_registration'; id}`, `parseContactLinkRequest(data: unknown): {subject: ContactSubject; channel: ExternalChannel}` (throws `DomainError('invalid_argument')`).
  - Ports (first part): `Clock { now(): Date }`, `IdGenerator { newId(): string }`, `UserContactRecord { phone?: unknown }`, `UserContactReader { get(uid): Promise<UserContactRecord | null> }`.
  - `requirePhone(contact: UserContactRecord | null): string` (throws `DomainError('phone_required')`), `requireCustomerPhone(contacts: UserContactReader, uid: string): Promise<string>`.

- [ ] **Step 1: Write the failing tests**

```ts
// packages/domain/test/client_allow_list.ts
// Test-only TypeScript port of the client's `isAllowedContactUri` (plan 2b, Task 4): the server
// must only ever build URLs that the app agrees to open.
const E164 = /^\+\d{8,15}$/;
const DIGITS_PATH = /^\/\d{8,15}$/;

export function isAllowedContactUrl(raw: string, channel: string): boolean {
  if (channel === 'call') return raw.startsWith('tel:') && E164.test(raw.slice('tel:'.length));
  const host = channel === 'zalo' ? 'zalo.me' : channel === 'whatsapp' ? 'wa.me' : null;
  if (host === null) return false;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  return url.protocol === 'https:'
    && url.hostname === host
    && url.port === ''
    && url.username === ''
    && url.password === ''
    && url.search === ''
    && url.hash === ''
    && DIGITS_PATH.test(url.pathname);
}
```

```ts
// packages/domain/test/contact.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DomainError,
  bookingContactUnlocked,
  contactUrlFor,
  parseContactLinkRequest,
  ticketContactUnlocked,
  type ContactNumbers,
  type ExternalChannel,
} from '../src/index.js';
import { isAllowedContactUrl } from './client_allow_list.js';

const vn: ContactNumbers = { phone: '+84903123456' };
const own: ContactNumbers = { phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671' };
const external: ExternalChannel[] = ['call', 'zalo', 'whatsapp'];
const NOW = new Date('2026-10-01T12:00:00Z');
const daysAgo = (days: number, extraMs = 0) => new Date(NOW.getTime() - days * 86_400_000 - extraMs);

describe('contactUrlFor: the exact URL formats (same as the client)', () => {
  test('call is tel: with the plus', () => assert.equal(contactUrlFor('call', vn), 'tel:+84903123456'));
  test('zalo is https://zalo.me/ with digits only', () =>
    assert.equal(contactUrlFor('zalo', vn), 'https://zalo.me/84903123456'));
  test('whatsapp is https://wa.me/ without the plus', () =>
    assert.equal(contactUrlFor('whatsapp', vn), 'https://wa.me/84903123456'));
  test('own Zalo and WhatsApp numbers are used, call keeps the main one', () => {
    assert.equal(contactUrlFor('call', own), 'tel:+84903123456');
    assert.equal(contactUrlFor('zalo', own), 'https://zalo.me/84912345678');
    assert.equal(contactUrlFor('whatsapp', own), 'https://wa.me/14155552671');
  });
  test('every URL passes the client allow-list for its own channel', () => {
    for (const c of external) assert.equal(isAllowedContactUrl(contactUrlFor(c, own) ?? '', c), true, c);
  });
  test('a stored number that is not valid for the channel never becomes a URL', () => {
    assert.equal(contactUrlFor('call', { phone: '0903123456' }), null);
    assert.equal(contactUrlFor('zalo', { phone: '+84903123456', zaloPhone: '+14155552671' }), null);
    assert.equal(contactUrlFor('whatsapp', { phone: '+84903123456', whatsappPhone: '+123' }), null);
    assert.equal(contactUrlFor('call', { phone: '+84903123456?x=1' }), null);
  });
});

describe('booking contact unlock (domain-model §5; client contactAccessForBooking)', () => {
  test('open from the deposit until the booking is over', () => {
    for (const status of ['requested', 'accepted', 'upcoming']) {
      assert.equal(bookingContactUnlocked({ status, completedAt: null }, NOW), true, status);
    }
  });
  test('closed for drafts, bookings that fell through and unknown codes', () => {
    for (const status of ['draft', 'declined', 'expired', 'cancelled', 'refunded', '']) {
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(1) }, NOW), false, status);
    }
  });
  test('completed and reviewed stay open for 30 days, inclusive', () => {
    for (const status of ['completed', 'reviewed']) {
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(29) }, NOW), true, status);
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(30) }, NOW), true, status);
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(30, 1000) }, NOW), false, status);
      assert.equal(bookingContactUnlocked({ status, completedAt: null }, NOW), false, status);
    }
  });
});

describe('ticket contact unlock', () => {
  test('a paid ticket is open until 7 days after the event, inclusive', () => {
    const tomorrow = new Date(NOW.getTime() + 86_400_000);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: tomorrow }, NOW), true);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: daysAgo(7) }, NOW), true);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: daysAgo(7, 1000) }, NOW), false);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: null }, NOW), false);
  });
  test('held, cancelled and refunded tickets are closed', () => {
    for (const status of ['held', 'cancelled', 'refunded']) {
      assert.equal(ticketContactUnlocked({ status, eventEndsAt: NOW }, NOW), false, status);
    }
  });
});

describe('parseContactLinkRequest (wire contract of getContactLink)', () => {
  test('booking and registration requests', () => {
    assert.deepEqual(parseContactLinkRequest({ bookingId: 'b1', channel: 'zalo' }), {
      subject: { type: 'booking', id: 'b1' },
      channel: 'zalo',
    });
    assert.deepEqual(parseContactLinkRequest({ registrationId: 'r9', channel: 'whatsapp' }), {
      subject: { type: 'event_registration', id: 'r9' },
      channel: 'whatsapp',
    });
  });
  test('anything else is invalid_argument', () => {
    const bad: unknown[] = [
      null, 'b1', [], {}, { bookingId: 'b1' },
      { bookingId: 'b1', channel: 'in_app' }, { bookingId: 'b1', channel: 'sms' },
      { bookingId: 'b1', registrationId: 'r1', channel: 'call' },
      { bookingId: 'a/b', channel: 'call' }, { bookingId: '', channel: 'call' }, { bookingId: 5, channel: 'call' },
      { bookingId: 'b1', channel: 'call', phone: '+84903123456' },
    ];
    for (const data of bad) {
      assert.throws(
        () => parseContactLinkRequest(data),
        (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument',
        JSON.stringify(data),
      );
    }
  });
});
```

```ts
// packages/domain/test/require_phone.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, requireCustomerPhone, requirePhone } from '../src/index.js';

const phoneRequired = (e: unknown) => e instanceof DomainError && e.code === 'phone_required';

describe('requirePhone', () => {
  test('returns the stored Vietnamese number', () => {
    assert.equal(requirePhone({ phone: '+84903123456' }), '+84903123456');
  });

  test('missing, malformed or foreign numbers are phone_required', () => {
    for (const contact of [null, {}, { phone: '' }, { phone: '0903123456' }, { phone: '+14155552671' }, { phone: 84903123456 }]) {
      assert.throws(() => requirePhone(contact), phoneRequired, JSON.stringify(contact));
    }
  });

  test('requireCustomerPhone reads the contact of that user only', async () => {
    const asked: string[] = [];
    const contacts = {
      get: async (uid: string) => {
        asked.push(uid);
        return uid === 'c1' ? { phone: '+84903123456' } : null;
      },
    };
    assert.equal(await requireCustomerPhone(contacts, 'c1'), '+84903123456');
    await assert.rejects(requireCustomerPhone(contacts, 'c2'), phoneRequired);
    assert.deepEqual(asked, ['c1', 'c2']);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run (from `packages/domain`): `npm test`
Expected: FAIL. `contact.test.ts` and `require_phone.test.ts` fail with `SyntaxError: The requested module '../src/index.js' does not provide an export named 'bookingContactUnlocked'` (and `'requireCustomerPhone'`); the 25 tests of Task 1 still pass.

- [ ] **Step 3: Implement**

```ts
// packages/domain/src/contact.ts
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { isInternationalE164, isVnE164 } from './phone.js';

/** Contact channel codes (domain-model.md §4 `ContactChannel`). */
export const CONTACT_CHANNELS = ['in_app', 'call', 'zalo', 'whatsapp'] as const;
export type ContactChannel = (typeof CONTACT_CHANNELS)[number];

/** Channels that leave the app; only these get a server-built URL. */
export type ExternalChannel = Exclude<ContactChannel, 'in_app'>;
export const EXTERNAL_CHANNELS: readonly ExternalChannel[] = ['call', 'zalo', 'whatsapp'];

export const isExternalChannel = (v: unknown): v is ExternalChannel =>
  typeof v === 'string' && (EXTERNAL_CHANNELS as readonly string[]).includes(v);

/** Public on/off flags (`photographers/{uid}.contactChannels`). */
export interface ContactChannels {
  readonly call: boolean;
  readonly zalo: boolean;
  readonly whatsapp: boolean;
}

/** Private numbers (`photographers/{uid}/private/contact`), E.164. */
export interface ContactNumbers {
  readonly phone: string;
  readonly zaloPhone?: string | null;
  readonly whatsappPhone?: string | null;
}

/** The number a channel dials: the own Zalo/WhatsApp number, else the main phone. */
export function numberFor(channel: ExternalChannel, numbers: ContactNumbers): string {
  switch (channel) {
    case 'call':
      return numbers.phone;
    case 'zalo':
      return numbers.zaloPhone ?? numbers.phone;
    case 'whatsapp':
      return numbers.whatsappPhone ?? numbers.phone;
  }
}

/**
 * The one URL the app opens, exactly what the client's `contactUriFor` builds (plan 2b, Task 4):
 * `tel:+84…`, `https://zalo.me/84…`, `https://wa.me/<digits>` (no plus). Null when the stored number
 * is not valid for the channel, so a bad record never becomes a URL.
 */
export function contactUrlFor(channel: ExternalChannel, numbers: ContactNumbers): string | null {
  const number = numberFor(channel, numbers);
  const valid = channel === 'whatsapp' ? isInternationalE164(number) : isVnE164(number);
  if (!valid) return null;
  const digits = number.slice(1);
  switch (channel) {
    case 'call':
      return `tel:${number}`;
    case 'zalo':
      return `https://zalo.me/${digits}`;
    case 'whatsapp':
      return `https://wa.me/${digits}`;
  }
}

export const BOOKING_CONTACT_DAYS = 30;
export const TICKET_CONTACT_DAYS = 7;
const DAY_MS = 86_400_000;

/**
 * `contact_unlocked` for a booking (domain-model.md §5): `requested | accepted | upcoming`, or
 * `completed | reviewed` for 30 days after completion (inclusive; unknown completion time stays
 * locked). Same boundaries as the client's `contactAccessForBooking` (plan 2b, Task 7).
 */
export function bookingContactUnlocked(
  booking: { readonly status: string; readonly completedAt: Date | null },
  now: Date,
): boolean {
  switch (booking.status) {
    case 'requested':
    case 'accepted':
    case 'upcoming':
      return true;
    case 'completed':
    case 'reviewed':
      return booking.completedAt !== null
        && now.getTime() - booking.completedAt.getTime() <= BOOKING_CONTACT_DAYS * DAY_MS;
    default:
      return false;
  }
}

/** `contact_unlocked` for an event ticket: `paid`, until 7 days after the event ends (inclusive). */
export function ticketContactUnlocked(
  registration: { readonly status: string; readonly eventEndsAt: Date | null },
  now: Date,
): boolean {
  return registration.status === 'paid'
    && registration.eventEndsAt !== null
    && now.getTime() - registration.eventEndsAt.getTime() <= TICKET_CONTACT_DAYS * DAY_MS;
}

/** What a contact link is for. `event_registration` is the `PaymentSubject` code. */
export type ContactSubject =
  | { readonly type: 'booking'; readonly id: string }
  | { readonly type: 'event_registration'; readonly id: string };

export interface ContactLinkRequest {
  readonly subject: ContactSubject;
  readonly channel: ExternalChannel;
}

const REQUEST_KEYS = new Set(['bookingId', 'registrationId', 'channel']);

/**
 * Wire payload of `getContactLink`: `{bookingId | registrationId, channel}`, exactly one id,
 * no other key. Anything else is `invalid_argument`.
 */
export function parseContactLinkRequest(data: unknown): ContactLinkRequest {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new DomainError('invalid_argument');
  }
  const d = data as Record<string, unknown>;
  if (!Object.keys(d).every((k) => REQUEST_KEYS.has(k))) throw new DomainError('invalid_argument');
  const hasBooking = 'bookingId' in d;
  const hasRegistration = 'registrationId' in d;
  if (hasBooking === hasRegistration) throw new DomainError('invalid_argument');
  const id = hasBooking ? d.bookingId : d.registrationId;
  const channel = d.channel;
  if (!isId(id) || !isExternalChannel(channel)) throw new DomainError('invalid_argument');
  return {
    subject: hasBooking ? { type: 'booking', id } : { type: 'event_registration', id },
    channel,
  };
}
```

```ts
// packages/domain/src/ports.ts
// Ports: what the domain needs from the outside. Firebase adapters live in
// app_flutter/firebase/functions/src/infra; a self-hosted server writes its own.

export interface Clock {
  now(): Date;
}

export interface IdGenerator {
  newId(): string;
}

/** `users/{uid}/private/contact` as stored. The domain validates it; it is not trusted. */
export interface UserContactRecord {
  readonly phone?: unknown;
}

export interface UserContactReader {
  get(uid: string): Promise<UserContactRecord | null>;
}
```

```ts
// packages/domain/src/require_phone.ts
import { DomainError } from './errors.js';
import { isVnE164 } from './phone.js';
import type { UserContactReader, UserContactRecord } from './ports.js';

/**
 * `phone_required` guard (spec §3b.2): a customer needs a valid Vietnamese number before a booking
 * request or an event registration. Returns the E.164 number to snapshot into the booking.
 */
export function requirePhone(contact: UserContactRecord | null): string {
  const phone = contact?.phone;
  if (!isVnE164(phone)) throw new DomainError('phone_required');
  return phone;
}

/** Reads `users/{uid}/private/contact` through the port and applies [requirePhone]. */
export async function requireCustomerPhone(contacts: UserContactReader, uid: string): Promise<string> {
  return requirePhone(await contacts.get(uid));
}
```

Replace `packages/domain/src/index.ts` with:

```ts
export * from './errors.js';
export * from './ids.js';
export * from './phone.js';
export * from './contact.js';
export * from './ports.js';
export * from './require_phone.js';
```

- [ ] **Step 4: Run and see it pass**

Run (from `packages/domain`): `npm run typecheck && npm run lint && npm test`
Expected: clean typecheck and lint; `ℹ tests 41`, `ℹ pass 41`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/domain
git commit -m "feat(domain): contact unlock rules, contact URLs, request contract and phone_required guard

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Use case `getContactLink` over ports

**Files:**
- Create: `packages/domain/src/get_contact_link.ts`, `packages/domain/test/get_contact_link.test.ts`
- Modify: `packages/domain/src/ports.ts` (replace), `packages/domain/src/index.ts`

**Interfaces:**
- Consumes: Task 2 (`parseContactLinkRequest`, `bookingContactUnlocked`, `ticketContactUnlocked`, `contactUrlFor`, `Clock`, `IdGenerator`).
- Produces:
  - Ports: `BookingRecord { id; customerId; photographerId; status: string; completedAt: Date | null }`, `BookingReader { get(id): Promise<BookingRecord | null> }` (1 document), `RegistrationRecord { id; userId; photographerId: string | null; status; eventEndsAt: Date | null }`, `RegistrationReader`, `PhotographerContact { channels: ContactChannels | null; numbers: ContactNumbers | null }`, `PhotographerContactReader { read(photographerId): Promise<PhotographerContact> }` (2 documents, 1 round trip), `ContactAccessLogEntry { id; requesterId; subjectType: 'booking' | 'event_registration'; subjectId; channel: ContactChannel; granted: boolean; at: Date }`, `ContactAccessLogWriter { append(entry): Promise<void> }`.
  - `interface GetContactLinkDeps { bookings; registrations?; photographers; log; clock; ids }`.
  - `getContactLink(requesterId: string, data: unknown, deps: GetContactLinkDeps): Promise<{ url: string }>`; throws `DomainError` with `invalid_argument` (nothing read, nothing logged), `not_found`, `permission_denied`, `contact_locked` (all logged with `granted: false`).
  - Read budget: unlocked call 3 documents in 2 round trips; refused before the photographer step 1 document in 1 round trip; exactly 1 log write per well-formed request.

- [ ] **Step 1: Write the failing test**

```ts
// packages/domain/test/get_contact_link.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DomainError,
  getContactLink,
  type BookingRecord,
  type ContactAccessLogEntry,
  type ContactChannels,
  type ContactNumbers,
  type GetContactLinkDeps,
  type RegistrationRecord,
} from '../src/index.js';

const NOW = new Date('2026-10-01T12:00:00Z');
const DAY = 86_400_000;
const allOn: ContactChannels = { call: true, zalo: true, whatsapp: true };
const own: ContactNumbers = { phone: '+84912000001', zaloPhone: '+84912000002', whatsappPhone: '+14155550101' };
const booking = (over: Partial<BookingRecord> = {}): BookingRecord => ({
  id: 'b1', customerId: 'c1', photographerId: 'p1', status: 'accepted', completedAt: null, ...over,
});

interface Setup {
  bookings?: BookingRecord[];
  registrations?: RegistrationRecord[];
  channels?: ContactChannels | null;
  numbers?: ContactNumbers | null;
  failLog?: boolean;
}

/** Fakes that count what a Firestore (or SQL) adapter would read. */
function harness(s: Setup = {}) {
  const reads = { documents: 0, roundTrips: 0 };
  const logs: ContactAccessLogEntry[] = [];
  let next = 0;
  const registrations = s.registrations;
  const deps: GetContactLinkDeps = {
    bookings: {
      async get(id) {
        reads.documents += 1;
        reads.roundTrips += 1;
        return (s.bookings ?? [booking()]).find((b) => b.id === id) ?? null;
      },
    },
    ...(registrations === undefined ? {} : {
      registrations: {
        async get(id: string) {
          reads.documents += 1;
          reads.roundTrips += 1;
          return registrations.find((r) => r.id === id) ?? null;
        },
      },
    }),
    photographers: {
      async read() {
        reads.documents += 2;
        reads.roundTrips += 1;
        return {
          channels: s.channels === undefined ? allOn : s.channels,
          numbers: s.numbers === undefined ? own : s.numbers,
        };
      },
    },
    log: {
      async append(entry) {
        if (s.failLog === true) throw new Error('log unavailable');
        logs.push(entry);
      },
    },
    clock: { now: () => NOW },
    ids: { newId: () => `log-${++next}` },
  };
  return { deps, reads, logs };
}

const isCode = (code: string) => (e: unknown) => e instanceof DomainError && e.code === code;

describe('getContactLink', () => {
  test('an unlocked booking gets the URL of each channel', async () => {
    const { deps } = harness();
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), { url: 'tel:+84912000001' });
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps), { url: 'https://zalo.me/84912000002' });
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'whatsapp' }, deps), { url: 'https://wa.me/14155550101' });
  });

  test('reads 3 documents in 2 round trips and writes 1 log row', async () => {
    const { deps, reads, logs } = harness();
    await getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps);
    assert.deepEqual(reads, { documents: 3, roundTrips: 2 });
    assert.equal(logs.length, 1);
  });

  test('the log row has the spec fields and no number', async () => {
    const { deps, logs } = harness();
    await getContactLink('c1', { bookingId: 'b1', channel: 'whatsapp' }, deps);
    assert.deepEqual(logs, [{
      id: 'log-1', requesterId: 'c1', subjectType: 'booking', subjectId: 'b1', channel: 'whatsapp', granted: true, at: NOW,
    }]);
    const text = JSON.stringify(logs);
    for (const digits of ['912000001', '912000002', '4155550101']) assert.ok(!text.includes(digits), digits);
  });

  test('locked bookings are contact_locked and the photographer is never read', async () => {
    for (const status of ['draft', 'declined', 'expired', 'cancelled']) {
      const { deps, reads, logs } = harness({ bookings: [booking({ status })] });
      await assert.rejects(getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), isCode('contact_locked'), status);
      assert.deepEqual(reads, { documents: 1, roundTrips: 1 }, status);
      assert.equal(logs[0]?.granted, false, status);
    }
  });

  test('completed bookings follow the 30-day window', async () => {
    const recent = harness({ bookings: [booking({ status: 'completed', completedAt: new Date(NOW.getTime() - 3 * DAY) })] });
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'call' }, recent.deps), { url: 'tel:+84912000001' });
    const old = harness({ bookings: [booking({ status: 'reviewed', completedAt: new Date(NOW.getTime() - 31 * DAY) })] });
    await assert.rejects(getContactLink('c1', { bookingId: 'b1', channel: 'call' }, old.deps), isCode('contact_locked'));
  });

  test("someone else's booking is permission_denied and logged", async () => {
    const { deps, reads, logs } = harness();
    await assert.rejects(getContactLink('p1', { bookingId: 'b1', channel: 'call' }, deps), isCode('permission_denied'));
    assert.deepEqual(reads, { documents: 1, roundTrips: 1 });
    assert.deepEqual(logs.map((l) => [l.requesterId, l.granted]), [['p1', false]]);
  });

  test('an unknown booking is not_found and logged', async () => {
    const { deps, logs } = harness({ bookings: [] });
    await assert.rejects(getContactLink('c1', { bookingId: 'nope', channel: 'call' }, deps), isCode('not_found'));
    assert.equal(logs.length, 1);
    assert.equal(logs[0]?.subjectId, 'nope');
  });

  test('a switched-off channel, missing data or a malformed number are not_found', async () => {
    const cases: Setup[] = [
      { channels: { call: true, zalo: false, whatsapp: true } },
      { channels: null },
      { numbers: null },
      { numbers: { phone: '+84912000001', zaloPhone: '0912000002' } },
    ];
    for (const setup of cases) {
      const { deps, logs } = harness(setup);
      await assert.rejects(
        getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps),
        isCode('not_found'),
        JSON.stringify(setup),
      );
      assert.equal(logs[0]?.granted, false);
    }
  });

  test('malformed requests are invalid_argument: nothing read, nothing logged', async () => {
    const { deps, reads, logs } = harness();
    for (const data of [null, {}, { bookingId: 'b1', channel: 'in_app' }, { bookingId: 'b1/x', channel: 'call' }]) {
      await assert.rejects(getContactLink('c1', data, deps), isCode('invalid_argument'));
    }
    assert.deepEqual(reads, { documents: 0, roundTrips: 0 });
    assert.equal(logs.length, 0);
  });

  test('registrations are not_found until the events plan wires a reader', async () => {
    const { deps, logs } = harness();
    await assert.rejects(getContactLink('c1', { registrationId: 'r1', channel: 'call' }, deps), isCode('not_found'));
    assert.deepEqual(logs.map((l) => [l.subjectType, l.subjectId, l.granted]), [['event_registration', 'r1', false]]);
  });

  test('registrations with a reader follow the ticket rule', async () => {
    const reg = (over: Partial<RegistrationRecord>): RegistrationRecord => ({
      id: 'r1', userId: 'c1', photographerId: 'p1', status: 'paid', eventEndsAt: new Date(NOW.getTime() - DAY), ...over,
    });
    const ask = (uid: string, r: RegistrationRecord) =>
      getContactLink(uid, { registrationId: 'r1', channel: 'call' }, harness({ registrations: [r] }).deps);
    assert.deepEqual(await ask('c1', reg({})), { url: 'tel:+84912000001' });
    await assert.rejects(ask('c1', reg({ eventEndsAt: new Date(NOW.getTime() - 8 * DAY) })), isCode('contact_locked'));
    await assert.rejects(ask('c2', reg({})), isCode('permission_denied'));
    await assert.rejects(ask('c1', reg({ photographerId: null })), isCode('not_found'));
  });

  test('a failing log write fails the call: no URL without an audit row', async () => {
    const { deps } = harness({ failLog: true });
    await assert.rejects(getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), /log unavailable/);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run (from `packages/domain`): `npm test`
Expected: FAIL. `get_contact_link.test.ts` fails with `does not provide an export named 'getContactLink'`; the other 41 tests pass.

- [ ] **Step 3: Implement**

Replace `packages/domain/src/ports.ts` with:

```ts
// packages/domain/src/ports.ts
import type { ContactChannel, ContactChannels, ContactNumbers, ContactSubject } from './contact.js';

// Ports: what the domain needs from the outside. Firebase adapters live in
// app_flutter/firebase/functions/src/infra; a self-hosted server writes its own.

export interface Clock {
  now(): Date;
}

export interface IdGenerator {
  newId(): string;
}

/** `users/{uid}/private/contact` as stored. The domain validates it; it is not trusted. */
export interface UserContactRecord {
  readonly phone?: unknown;
}

export interface UserContactReader {
  get(uid: string): Promise<UserContactRecord | null>;
}

export interface BookingRecord {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  /** `BookingStatus` code; unknown codes are treated as locked. */
  readonly status: string;
  readonly completedAt: Date | null;
}

export interface BookingReader {
  /** One document. */
  get(id: string): Promise<BookingRecord | null>;
}

export interface RegistrationRecord {
  readonly id: string;
  readonly userId: string;
  /** Host photographer; null for platform-hosted events (no photographer number to open). */
  readonly photographerId: string | null;
  /** `RegistrationStatus` code. */
  readonly status: string;
  readonly eventEndsAt: Date | null;
}

export interface RegistrationReader {
  /** One document. */
  get(id: string): Promise<RegistrationRecord | null>;
}

export interface PhotographerContact {
  readonly channels: ContactChannels | null;
  readonly numbers: ContactNumbers | null;
}

export interface PhotographerContactReader {
  /** Public flags and private numbers together: two documents in one round trip. */
  read(photographerId: string): Promise<PhotographerContact>;
}

/** One row of `ContactAccessLog` (domain-model.md §2.7). Never holds a number. */
export interface ContactAccessLogEntry {
  readonly id: string;
  readonly requesterId: string;
  readonly subjectType: ContactSubject['type'];
  readonly subjectId: string;
  readonly channel: ContactChannel;
  readonly granted: boolean;
  readonly at: Date;
}

export interface ContactAccessLogWriter {
  append(entry: ContactAccessLogEntry): Promise<void>;
}
```

```ts
// packages/domain/src/get_contact_link.ts
import {
  bookingContactUnlocked,
  contactUrlFor,
  parseContactLinkRequest,
  ticketContactUnlocked,
  type ContactSubject,
  type ExternalChannel,
} from './contact.js';
import { DomainError, type ErrorCode } from './errors.js';
import type {
  BookingReader,
  Clock,
  ContactAccessLogWriter,
  IdGenerator,
  PhotographerContactReader,
  RegistrationReader,
} from './ports.js';

export interface GetContactLinkDeps {
  readonly bookings: BookingReader;
  /** Absent until event registrations exist (events plan): registration requests are then `not_found`. */
  readonly registrations?: RegistrationReader;
  readonly photographers: PhotographerContactReader;
  readonly log: ContactAccessLogWriter;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

type Outcome = { readonly url: string } | { readonly error: ErrorCode };
type Party = { readonly photographerId: string } | { readonly error: ErrorCode };

/**
 * Use case `get_contact_link` (data-model README §5). Order of checks: request shape, caller is the
 * customer of the subject, contact unlocked, channel switched on and stored number valid.
 * Every well-formed request writes exactly one ContactAccessLog row (granted or not) before it is
 * answered; the number only ever leaves inside the returned URL.
 * Reads: the subject (1 document), then the photographer's flags and numbers (2 documents, 1 round trip).
 */
export async function getContactLink(
  requesterId: string,
  data: unknown,
  deps: GetContactLinkDeps,
): Promise<{ url: string }> {
  const { subject, channel } = parseContactLinkRequest(data);
  const at = deps.clock.now();
  const outcome = await decide(requesterId, subject, channel, at, deps);
  await deps.log.append({
    id: deps.ids.newId(),
    requesterId,
    subjectType: subject.type,
    subjectId: subject.id,
    channel,
    granted: 'url' in outcome,
    at,
  });
  if ('error' in outcome) throw new DomainError(outcome.error);
  return { url: outcome.url };
}

async function decide(
  requesterId: string,
  subject: ContactSubject,
  channel: ExternalChannel,
  now: Date,
  deps: GetContactLinkDeps,
): Promise<Outcome> {
  const party = await findParty(requesterId, subject, now, deps);
  if ('error' in party) return party;
  const { channels, numbers } = await deps.photographers.read(party.photographerId);
  if (channels === null || !channels[channel] || numbers === null) return { error: 'not_found' };
  const url = contactUrlFor(channel, numbers);
  return url === null ? { error: 'not_found' } : { url };
}

async function findParty(
  requesterId: string,
  subject: ContactSubject,
  now: Date,
  deps: GetContactLinkDeps,
): Promise<Party> {
  if (subject.type === 'booking') {
    const booking = await deps.bookings.get(subject.id);
    if (booking === null) return { error: 'not_found' };
    if (booking.customerId !== requesterId) return { error: 'permission_denied' };
    if (!bookingContactUnlocked(booking, now)) return { error: 'contact_locked' };
    return { photographerId: booking.photographerId };
  }
  const registration = deps.registrations ? await deps.registrations.get(subject.id) : null;
  if (registration === null || registration.photographerId === null) return { error: 'not_found' };
  if (registration.userId !== requesterId) return { error: 'permission_denied' };
  if (!ticketContactUnlocked(registration, now)) return { error: 'contact_locked' };
  return { photographerId: registration.photographerId };
}
```

Append to `packages/domain/src/index.ts`:

```ts
export * from './get_contact_link.js';
```

- [ ] **Step 4: Run and see it pass**

Run (from `packages/domain`): `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 53`, `ℹ pass 53`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/domain
git commit -m "feat(domain): getContactLink use case with ports, audit row and read budget

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Functions project, emulator configuration and callable plumbing

**Files:**
- Create: `app_flutter/firebase/functions/package.json`, `tsconfig.json`, `eslint.config.js`, `build.mjs`, `src/config.ts`, `src/callables/errors.ts`, `src/callables/get_contact_link.ts`, `src/infra/admin.ts`, `src/infra/firestore.ts`, `src/index.ts`, `test/unit/errors.test.ts`, `test/unit/get_contact_link_handler.test.ts`, `test/unit/firestore_mapping.test.ts`, `test/unit/config.test.ts`; `app_flutter/firebase/storage.rules`, `app_flutter/firebase/.gitignore`
- Modify: `app_flutter/firebase/firebase.json`

**Interfaces:**
- Consumes: `@photobooking/domain` (Tasks 1–3); existing `firebase.json` (firestore rules/indexes, auth 9099, firestore 8080, UI disabled) and `rules-test/package.json` (`firebase emulators:exec --config ../firebase.json --only firestore --project demo-nag`).
- Produces:
  - `REGION = 'asia-southeast1'`, `CALLABLE_OPTIONS` (`region`, `memory: '256MiB'`, `timeoutSeconds: 10`, `maxInstances: 10`, `minInstances: 0`, `enforceAppCheck: false`).
  - `toHttpsError(e: unknown): HttpsError`.
  - `interface CallableInput { auth?: { uid: string }; data: unknown }`, `handleGetContactLink(request: CallableInput, deps: GetContactLinkDeps): Promise<{ url: string }>`.
  - `db(): Firestore` (lazy Admin init).
  - Adapters (all reads through `db.getAll`): `CONTACT_ACCESS_LOG = 'contact_access_log'`, `bookingFromDoc`, `lastCompletedAt`, `channelsFromDoc`, `numbersFromDoc`, `firestoreBookingReader(db)`, `firestorePhotographerContactReader(db)`, `firestoreContactAccessLog(db)`, `firestoreUserContactReader(db)`.
  - npm scripts: `typecheck`, `lint`, `build`, `build:watch`, `test`, `test:integration`, `test:perf`, `seed`, `try:contact` (the last four get their files in Tasks 5, 6 and 9).
  - Emulator ports: auth 9099, firestore 8080, functions 5001, storage 9199, hub 4400, logging 4500, UI 4000.

- [ ] **Step 1: Tooling, configuration and install**

```json
// app_flutter/firebase/functions/package.json
{
  "name": "photobooking-functions",
  "private": true,
  "description": "Cloud Functions for photobooking: thin Firebase adapters around packages/domain.",
  "type": "module",
  "main": "lib/index.js",
  "engines": { "node": "22" },
  "scripts": {
    "typecheck": "tsc -p tsconfig.json",
    "lint": "eslint .",
    "build": "npm run typecheck && node build.mjs",
    "build:watch": "node build.mjs --watch",
    "test": "node --import tsx --test \"test/unit/**/*.test.ts\"",
    "test:integration": "npm run build && JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true firebase emulators:exec --config ../firebase.json --project demo-nag --only auth,firestore,functions \"node --import tsx --test --test-concurrency=1 'test/integration/**/*.test.ts'\"",
    "test:perf": "npm run build && JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true firebase emulators:exec --config ../firebase.json --project demo-nag --only auth,firestore,functions \"node --import tsx --test --test-concurrency=1 'test/perf/**/*.test.ts'\"",
    "seed": "node --import tsx seed/seed.ts",
    "try:contact": "node --import tsx seed/try_contact_link.ts"
  },
  "dependencies": {
    "firebase-admin": "^13.10.0",
    "firebase-functions": "^6.6.0"
  },
  "devDependencies": {
    "@eslint/js": "^9.39.0",
    "@types/node": "^22.20.0",
    "esbuild": "^0.28.0",
    "eslint": "^9.39.0",
    "firebase-tools": "^14.27.0",
    "tsx": "^4.23.0",
    "typescript": "^5.9.3",
    "typescript-eslint": "^8.71.0"
  }
}
```

```json
// app_flutter/firebase/functions/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2023",
    "lib": ["ES2023"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["node"],
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true,
    "noEmit": true,
    "paths": {
      "@photobooking/domain": ["../../../packages/domain/src/index"]
    }
  },
  "include": ["src", "test", "seed"]
}
```

```js
// app_flutter/firebase/functions/eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules/**', 'lib/**'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['**/*.js', '**/*.mjs'],
    languageOptions: { globals: { process: 'readonly', console: 'readonly' } },
  },
  {
    // Business rules belong in packages/domain; here only adapters and wiring.
    files: ['src/config.ts'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [{ group: ['firebase-admin', 'firebase-admin/*'], message: 'config.ts holds options only.' }],
      }],
    },
  },
);
```

```js
// app_flutter/firebase/functions/build.mjs
// Bundles src/ and packages/domain into lib/index.js. firebase-admin and firebase-functions stay
// external (installed from package.json), so the deployed folder never needs the ../../../packages path.
import { build, context } from 'esbuild';

const options = {
  entryPoints: ['src/index.ts'],
  outfile: 'lib/index.js',
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  sourcemap: true,
  external: ['firebase-admin', 'firebase-functions'],
  tsconfig: 'tsconfig.json',
  logLevel: 'info',
};

if (process.argv.includes('--watch')) {
  const ctx = await context(options);
  await ctx.watch();
} else {
  await build(options);
}
```

Replace `app_flutter/firebase/firebase.json` with:

```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "storage": { "rules": "storage.rules" },
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "runtime": "nodejs22",
      "ignore": ["node_modules", ".git", "*.log", "src", "test", "seed", "build.mjs", "tsconfig.json", "eslint.config.js"],
      "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
    }
  ],
  "emulators": {
    "singleProjectMode": true,
    "auth": { "host": "127.0.0.1", "port": 9099 },
    "firestore": { "host": "127.0.0.1", "port": 8080 },
    "functions": { "host": "127.0.0.1", "port": 5001 },
    "storage": { "host": "127.0.0.1", "port": 9199 },
    "hub": { "host": "127.0.0.1", "port": 4400 },
    "logging": { "host": "127.0.0.1", "port": 4500 },
    "ui": { "enabled": true, "host": "127.0.0.1", "port": 4000 }
  }
}
```

(`emulators:exec`, used by the tests, never starts the UI; the existing rules tests keep using `--only firestore`.)

```
// app_flutter/firebase/storage.rules
rules_version = '2';
// Nothing is client-accessible yet: the avatar, portfolio and chat-image plans open their own
// paths (owner-only writes, size and content-type checks) together with their rules tests.
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

(Write the file without the first `// app_flutter/...` line.)

```gitignore
# app_flutter/firebase/.gitignore
# Emulator data saved by scripts/backend-local.sh, and its --lan copy of firebase.json
.emulator-data/
.firebase.lan.json
# Cloud Functions dependencies and bundle
functions/node_modules/
functions/lib/
# Emulator logs (firestore-debug.log, firebase-debug.log, ui-debug.log …)
*-debug.log
```

Run (from `app_flutter/firebase/functions`): `npm install`
Expected: `package-lock.json` created; `npm warn install-scripts … re2` is harmless.

- [ ] **Step 2: Write the failing tests**

```ts
// app_flutter/firebase/functions/test/unit/errors.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import { DomainError, ERROR_CODES, type ErrorCode } from '@photobooking/domain';
import { toHttpsError } from '../../src/callables/errors.js';

describe('toHttpsError', () => {
  test('domain codes travel as message and details.code (what the client reads)', () => {
    const e = toHttpsError(new DomainError('contact_locked'));
    assert.equal(e.code, 'failed-precondition');
    assert.equal(e.message, 'contact_locked');
    assert.deepEqual(e.details, { code: 'contact_locked' });
  });

  test('each domain code has a fitting transport code', () => {
    const expected: Record<ErrorCode, string> = {
      invalid_argument: 'invalid-argument',
      permission_denied: 'permission-denied',
      not_found: 'not-found',
      contact_locked: 'failed-precondition',
      phone_required: 'failed-precondition',
      day_taken: 'already-exists',
      sold_out: 'resource-exhausted',
      deadline_passed: 'failed-precondition',
      limit_exceeded: 'resource-exhausted',
      conflict: 'aborted',
    };
    for (const code of ERROR_CODES) assert.equal(toHttpsError(new DomainError(code)).code, expected[code], code);
  });

  test('unexpected errors become internal and leak nothing', () => {
    const e = toHttpsError(new Error('Firestore said +84912000001'));
    assert.equal(e.code, 'internal');
    assert.equal(e.message, 'internal');
    assert.deepEqual(e.details, { code: 'internal' });
  });

  test('an HttpsError passes through unchanged', () => {
    const original = new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
    assert.equal(toHttpsError(original), original);
  });
});
```

```ts
// app_flutter/firebase/functions/test/unit/get_contact_link_handler.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import type { BookingRecord, ContactAccessLogEntry, GetContactLinkDeps } from '@photobooking/domain';
import { handleGetContactLink } from '../../src/callables/get_contact_link.js';

const accepted: BookingRecord = { id: 'b1', customerId: 'c1', photographerId: 'p1', status: 'accepted', completedAt: null };

function fakes(bookings: BookingRecord[]): { deps: GetContactLinkDeps; logs: ContactAccessLogEntry[] } {
  const logs: ContactAccessLogEntry[] = [];
  const deps: GetContactLinkDeps = {
    bookings: { get: async (id) => bookings.find((b) => b.id === id) ?? null },
    photographers: {
      read: async () => ({ channels: { call: true, zalo: true, whatsapp: false }, numbers: { phone: '+84912000001' } }),
    },
    log: { append: async (e) => { logs.push(e); } },
    clock: { now: () => new Date('2026-10-01T12:00:00Z') },
    ids: { newId: () => 'log-1' },
  };
  return { deps, logs };
}

const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
  e instanceof HttpsError
  && e.code === code
  && (detailsCode === undefined || (e.details as { code?: string }).code === detailsCode);

describe('handleGetContactLink', () => {
  test('a signed-in customer gets { url } and nothing else', async () => {
    const { deps } = fakes([accepted]);
    const result = await handleGetContactLink({ auth: { uid: 'c1' }, data: { bookingId: 'b1', channel: 'call' } }, deps);
    assert.deepEqual(result, { url: 'tel:+84912000001' });
    assert.deepEqual(Object.keys(result), ['url']);
  });

  test('no auth is unauthenticated with details.code permission_denied, and nothing is logged', async () => {
    const { deps, logs } = fakes([accepted]);
    await assert.rejects(
      handleGetContactLink({ data: { bookingId: 'b1', channel: 'call' } }, deps),
      httpsError('unauthenticated', 'permission_denied'),
    );
    assert.equal(logs.length, 0);
  });

  test('contact_locked reaches the client exactly as the contract says', async () => {
    const { deps } = fakes([{ ...accepted, status: 'cancelled' }]);
    await assert.rejects(
      handleGetContactLink({ auth: { uid: 'c1' }, data: { bookingId: 'b1', channel: 'call' } }, deps),
      (e: unknown) => httpsError('failed-precondition', 'contact_locked')(e) && (e as HttpsError).message === 'contact_locked',
    );
  });

  test('a switched-off channel is not-found', async () => {
    const { deps } = fakes([accepted]);
    await assert.rejects(
      handleGetContactLink({ auth: { uid: 'c1' }, data: { bookingId: 'b1', channel: 'whatsapp' } }, deps),
      httpsError('not-found', 'not_found'),
    );
  });
});
```

```ts
// app_flutter/firebase/functions/test/unit/firestore_mapping.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { bookingFromDoc, channelsFromDoc, lastCompletedAt, numbersFromDoc } from '../../src/infra/firestore.js';

const t = (iso: string) => Timestamp.fromDate(new Date(iso));

describe('Firestore → domain mapping', () => {
  test('booking: ids, status and completedAt from the timeline', () => {
    assert.deepEqual(
      bookingFromDoc('b1', {
        customerId: 'c1',
        photographerId: 'p1',
        status: 'completed',
        timeline: [{ status: 'requested', at: t('2026-09-01T00:00:00Z') }, { status: 'completed', at: t('2026-09-20T10:00:00Z') }],
      }),
      { id: 'b1', customerId: 'c1', photographerId: 'p1', status: 'completed', completedAt: new Date('2026-09-20T10:00:00Z') },
    );
  });

  test('booking: a top-level completedAt wins over the timeline', () => {
    const b = bookingFromDoc('b1', {
      customerId: 'c1',
      photographerId: 'p1',
      status: 'completed',
      completedAt: t('2026-09-21T00:00:00Z'),
      timeline: [{ status: 'completed', at: t('2026-09-20T00:00:00Z') }],
    });
    assert.deepEqual(b?.completedAt, new Date('2026-09-21T00:00:00Z'));
  });

  test('booking: a missing doc or unusable ids give null', () => {
    assert.equal(bookingFromDoc('b1', undefined), null);
    assert.equal(bookingFromDoc('b1', { customerId: 'c1', photographerId: 'a/b', status: 'accepted' }), null);
    assert.equal(bookingFromDoc('b1', { customerId: 'c1', photographerId: 'p1' }), null);
  });

  test('lastCompletedAt takes the latest completed entry and ignores junk', () => {
    assert.deepEqual(
      lastCompletedAt([
        { status: 'completed', at: t('2026-09-01T00:00:00Z') },
        'x',
        null,
        { status: 'completed', at: 'yesterday' },
        { status: 'completed', at: t('2026-09-05T00:00:00Z') },
      ]),
      new Date('2026-09-05T00:00:00Z'),
    );
    assert.equal(lastCompletedAt(undefined), null);
  });

  test('channels are strict booleans; numbers need a phone', () => {
    assert.deepEqual(channelsFromDoc({ contactChannels: { call: true, zalo: 'yes', acceptInquiries: true } }), {
      call: true,
      zalo: false,
      whatsapp: false,
    });
    assert.equal(channelsFromDoc({}), null);
    assert.equal(channelsFromDoc(undefined), null);
    assert.deepEqual(numbersFromDoc({ phone: '+84912000001', zaloPhone: '+84912000002' }), {
      phone: '+84912000001',
      zaloPhone: '+84912000002',
      whatsappPhone: null,
    });
    assert.equal(numbersFromDoc({ zaloPhone: '+84912000002' }), null);
  });
});
```

```ts
// app_flutter/firebase/functions/test/unit/config.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CALLABLE_OPTIONS, REGION } from '../../src/config.js';

test('callables run in asia-southeast1 with small, bounded instances', () => {
  assert.equal(REGION, 'asia-southeast1');
  assert.equal(CALLABLE_OPTIONS.region, REGION);
  assert.equal(CALLABLE_OPTIONS.memory, '256MiB');
  assert.equal(CALLABLE_OPTIONS.timeoutSeconds, 10);
  assert.equal(CALLABLE_OPTIONS.maxInstances, 10);
  assert.equal(CALLABLE_OPTIONS.minInstances, 0);
});

test('App Check is not enforced in phase 1 (the emulators do not verify it)', () => {
  assert.equal(CALLABLE_OPTIONS.enforceAppCheck, false);
});
```

- [ ] **Step 3: Run and see it fail**

Run (from `app_flutter/firebase/functions`): `npm test`
Expected: FAIL, all four files with `ERR_MODULE_NOT_FOUND` (`src/callables/errors.js`, `src/callables/get_contact_link.js`, `src/infra/firestore.js`, `src/config.js`).

- [ ] **Step 4: Implement**

```ts
// app_flutter/firebase/functions/src/config.ts
import type { CallableOptions } from 'firebase-functions/v2/https';

/**
 * Every function runs in Singapore, the closest Cloud Functions region to Vietnam.
 * The Flutter app uses the same value (lib/data/backend/backend_config.dart, `functionsRegion`).
 */
export const REGION = 'asia-southeast1';

/**
 * Options shared by every callable. Passed explicitly to each `onCall` (not through
 * setGlobalOptions) so the value cannot depend on module evaluation order.
 * App Check is not enforced in phase 1: the emulators do not verify App Check tokens; the cloud
 * deploy plan turns `enforceAppCheck` on together with the client's App Check provider.
 */
export const CALLABLE_OPTIONS = {
  region: REGION,
  memory: '256MiB',
  timeoutSeconds: 10,
  maxInstances: 10,
  minInstances: 0,
  enforceAppCheck: false,
} as const satisfies CallableOptions;
```

```ts
// app_flutter/firebase/functions/src/callables/errors.ts
import { HttpsError, type FunctionsErrorCode } from 'firebase-functions/v2/https';
import { isDomainError, type ErrorCode } from '@photobooking/domain';

const TRANSPORT_CODE: Record<ErrorCode, FunctionsErrorCode> = {
  invalid_argument: 'invalid-argument',
  permission_denied: 'permission-denied',
  not_found: 'not-found',
  contact_locked: 'failed-precondition',
  phone_required: 'failed-precondition',
  day_taken: 'already-exists',
  sold_out: 'resource-exhausted',
  deadline_passed: 'failed-precondition',
  limit_exceeded: 'resource-exhausted',
  conflict: 'aborted',
};

/**
 * Domain refusal → callable error. The client reads `details.code` (falling back to the message),
 * so both carry the stable code. Anything unexpected becomes `internal` and says nothing more.
 */
export function toHttpsError(e: unknown): HttpsError {
  if (e instanceof HttpsError) return e;
  if (isDomainError(e)) return new HttpsError(TRANSPORT_CODE[e.code], e.code, { code: e.code });
  return new HttpsError('internal', 'internal', { code: 'internal' });
}
```

```ts
// app_flutter/firebase/functions/src/callables/get_contact_link.ts
import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { getContactLink, type GetContactLinkDeps } from '@photobooking/domain';
import { toHttpsError } from './errors.js';

/** The part of a callable request the handler uses (a `CallableRequest` fits). */
export interface CallableInput {
  readonly auth?: { readonly uid: string } | undefined;
  readonly data: unknown;
}

/**
 * Callable `getContactLink` (contract: plan 2b "Out of scope"): `{bookingId | registrationId, channel}`
 * → `{url}`. Errors carry `details.code`: `contact_locked`, `permission_denied`, `not_found`,
 * `invalid_argument`.
 */
export async function handleGetContactLink(request: CallableInput, deps: GetContactLinkDeps): Promise<{ url: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    return await getContactLink(uid, request.data, deps);
  } catch (e) {
    const error = toHttpsError(e);
    // Codes only: never the request, the URL or a number.
    logger.info('getContactLink refused', { code: error.message });
    throw error;
  }
}
```

```ts
// app_flutter/firebase/functions/src/infra/admin.ts
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

/**
 * The Admin SDK's Firestore, initialised on first use (not at import) to keep cold starts short.
 * In the emulator, FIRESTORE_EMULATOR_HOST routes it to the local Firestore.
 */
export function db(): Firestore {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}
```

```ts
// app_flutter/firebase/functions/src/infra/firestore.ts
import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  isId,
  type BookingReader,
  type BookingRecord,
  type ContactAccessLogWriter,
  type ContactChannels,
  type ContactNumbers,
  type PhotographerContactReader,
  type UserContactReader,
} from '@photobooking/domain';

// Firestore adapters for the domain ports. Every read goes through `db.getAll` (one call = one
// round trip), so the read budget of each use case can be counted and asserted.

/** Firestore collection of `ContactAccessLog` (relational table `contact_access_log`). */
export const CONTACT_ACCESS_LOG = 'contact_access_log';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return null;
}

/** Latest `timeline[]` entry with status `completed` (bookings have no `completedAt` field yet). */
export function lastCompletedAt(timeline: unknown): Date | null {
  if (!Array.isArray(timeline)) return null;
  let latest: Date | null = null;
  for (const entry of timeline) {
    if (typeof entry !== 'object' || entry === null) continue;
    const { status, at } = entry as { status?: unknown; at?: unknown };
    const when = toDate(at);
    if (status === 'completed' && when !== null && (latest === null || when > latest)) latest = when;
  }
  return latest;
}

export function bookingFromDoc(id: string, d: DocumentData | undefined): BookingRecord | null {
  if (d === undefined) return null;
  const customerId: unknown = d.customerId;
  const photographerId: unknown = d.photographerId;
  const status: unknown = d.status;
  if (!isId(customerId) || !isId(photographerId) || typeof status !== 'string') return null;
  return { id, customerId, photographerId, status, completedAt: toDate(d.completedAt) ?? lastCompletedAt(d.timeline) };
}

export function channelsFromDoc(d: DocumentData | undefined): ContactChannels | null {
  const raw: unknown = d?.contactChannels;
  if (typeof raw !== 'object' || raw === null) return null;
  const c = raw as Record<string, unknown>;
  return { call: c.call === true, zalo: c.zalo === true, whatsapp: c.whatsapp === true };
}

export function numbersFromDoc(d: DocumentData | undefined): ContactNumbers | null {
  if (d === undefined || typeof d.phone !== 'string') return null;
  return {
    phone: d.phone,
    zaloPhone: typeof d.zaloPhone === 'string' ? d.zaloPhone : null,
    whatsappPhone: typeof d.whatsappPhone === 'string' ? d.whatsappPhone : null,
  };
}

export function firestoreBookingReader(db: Firestore): BookingReader {
  return {
    async get(id) {
      const [snap] = await db.getAll(db.collection('bookings').doc(id));
      return bookingFromDoc(id, snap?.data());
    },
  };
}

export function firestorePhotographerContactReader(db: Firestore): PhotographerContactReader {
  return {
    async read(photographerId) {
      const [pub, priv] = await db.getAll(
        db.collection('photographers').doc(photographerId),
        db.doc(`photographers/${photographerId}/private/contact`),
      );
      return { channels: channelsFromDoc(pub?.data()), numbers: numbersFromDoc(priv?.data()) };
    },
  };
}

export function firestoreContactAccessLog(db: Firestore): ContactAccessLogWriter {
  return {
    async append(e) {
      await db.collection(CONTACT_ACCESS_LOG).doc(e.id).create({
        requesterId: e.requesterId,
        subjectType: e.subjectType,
        subjectId: e.subjectId,
        channel: e.channel,
        granted: e.granted,
        at: Timestamp.fromDate(e.at),
      });
    },
  };
}

export function firestoreUserContactReader(db: Firestore): UserContactReader {
  return {
    async get(uid) {
      const [snap] = await db.getAll(db.doc(`users/${uid}/private/contact`));
      const d = snap?.data();
      return d === undefined ? null : { phone: d.phone };
    },
  };
}
```

```ts
// app_flutter/firebase/functions/src/index.ts
// Entry point of the Cloud Functions codebase. Each export is one deployed function.
// getContactLink is wired in Task 6 of the backend phase-1 plan.
export {};
```

- [ ] **Step 5: Run and see it pass; rules tests still pass**

Run (from `app_flutter/firebase/functions`): `npm run lint && npm test && npm run build`
Expected: lint clean; `ℹ tests 15`, `ℹ pass 15`, `ℹ fail 0` (the handler test prints one JSON log line per refusal, codes only); build prints `lib/index.js` and `⚡ Done`.

Run (from `app_flutter/firebase/rules-test`): `npm test`
Expected: every rules test passes, as before (the new `functions`, `storage` and emulator entries do not affect `--only firestore`).

- [ ] **Step 6: Commit**

```bash
git add app_flutter/firebase/firebase.json app_flutter/firebase/storage.rules app_flutter/firebase/.gitignore app_flutter/firebase/functions
git commit -m "feat(functions): TypeScript Cloud Functions codebase, emulator suite config and callable plumbing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Deterministic seed data and the emulator test harness

**Files:**
- Create: `app_flutter/firebase/functions/seed/fixtures.ts`, `seed/apply.ts`, `seed/seed.ts`, `seed/emulator_client.ts`, `seed/try_contact_link.ts`, `seed/README.md`, `test/unit/seed_fixtures.test.ts`, `test/integration/seed.test.ts`

**Interfaces:**
- Consumes: `REGION` (Task 4); `bookingContactUnlocked`, `isId`, `isVnE164`, `isInternationalE164` (domain); the Firestore shapes of plans 2a/2b (`users/{uid}`, `users/{uid}/private/contact`, `photographers/{uid}` with `contactChannels`, `photographers/{uid}/private/contact`) and of the original spec (`bookings/{id}` with `customerId, photographerId, serviceId, service{}, date, start, end, location, status, deposit{}, remaining, timeline[]`).
- Produces:
  - Constants `SEED_PASSWORD = 'seed-password-1'`, `LAN`, `MINH`, `AN`, `BINH`, `SEED_USERS`, `SEED_CUSTOMER_PHONES`, `SEED_PHOTOGRAPHERS`, `SEED_SERVICES`, `SEED_BOOKINGS`; `seedDocuments(now: Date): SeedDocument[]` (16 documents).
  - `applySeed(db: Firestore, auth: Auth, now: Date): Promise<void>` (idempotent).
  - `emulatorProject()`, `signIn(email, password): Promise<string>`, `callCallable(name, data, idToken?): Promise<CallableResponse>` with `{status, text, result?, error?: {message, status, details}}`, `resetEmulators()`.
  - CLI `npm run seed` (refuses non-local hosts), `npm run try:contact -- <email> <bookingId> <channel>`.

| Seed id | Login | What it exercises |
|---|---|---|
| `seed-customer-lan` | `lan.customer@seed.test` | customer with phone `+84903000001` |
| `seed-customer-minh` | `minh.nophone@seed.test` | customer without phone (`phone_required`) |
| `seed-photographer-an` | `an.verified@seed.test` | verified; call + Zalo + WhatsApp; `+84912000001`, Zalo `+84912000002`, WhatsApp `+14155550101` |
| `seed-photographer-binh` | `binh.unverified@seed.test` | unverified; call only; `+84987000001` |
| `seed-booking-accepted` | Lan ↔ An | unlocked |
| `seed-booking-requested-binh` | Lan ↔ Bình | unlocked, only `call` switched on |
| `seed-booking-cancelled` | Lan ↔ An | `contact_locked` |
| `seed-booking-completed-recent` | Lan ↔ An | completed 3 days before seeding: unlocked |
| `seed-booking-completed-old` | Lan ↔ An | completed 40 days before seeding: `contact_locked` |

- [ ] **Step 1: Write the failing tests**

```ts
// app_flutter/firebase/functions/test/unit/seed_fixtures.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { bookingContactUnlocked, isId, isInternationalE164, isVnE164 } from '@photobooking/domain';
import { SEED_PASSWORD, SEED_PHOTOGRAPHERS, SEED_USERS, seedDocuments } from '../../seed/fixtures.js';

const NOW = new Date('2026-10-01T12:00:00Z');

function bookingDoc(id: string): { status: string; timeline: { status: string; at: Date }[] } {
  const doc = seedDocuments(NOW).find((d) => d.path === `bookings/${id}`);
  if (doc === undefined) throw new Error(`no seed booking ${id}`);
  return doc.data as { status: string; timeline: { status: string; at: Date }[] };
}

describe('seed fixtures', () => {
  test('every path segment is a valid opaque id', () => {
    for (const d of seedDocuments(NOW)) {
      for (const segment of d.path.split('/')) assert.ok(isId(segment), d.path);
    }
  });

  test('accounts are test-only', () => {
    for (const u of SEED_USERS) assert.match(u.email, /@seed\.test$/);
    assert.ok(SEED_PASSWORD.length >= 6, 'the Auth emulator needs at least 6 characters');
  });

  test('numbers are valid and only in private documents', () => {
    for (const d of seedDocuments(NOW)) {
      if (d.path.includes('/private/')) continue;
      assert.doesNotMatch(JSON.stringify(d.data), /\+\d{8,15}/, d.path);
      assert.ok(!Object.keys(d.data).some((k) => /phone/i.test(k)), d.path);
    }
    for (const p of SEED_PHOTOGRAPHERS) {
      assert.ok(isVnE164(p.numbers.phone), p.uid);
      if (p.numbers.zaloPhone !== undefined) assert.ok(isVnE164(p.numbers.zaloPhone), p.uid);
      if (p.numbers.whatsappPhone !== undefined) assert.ok(isInternationalE164(p.numbers.whatsappPhone), p.uid);
    }
  });

  test('money follows the deposit rule: floor(30%) and the rest, integer VND', () => {
    for (const d of seedDocuments(NOW).filter((x) => x.path.startsWith('bookings/'))) {
      const data = d.data as { service: { price: number }; deposit: { amount: number }; remaining: number };
      assert.equal(data.deposit.amount, Math.floor(data.service.price * 0.3), d.path);
      assert.equal(data.deposit.amount + data.remaining, data.service.price, d.path);
      assert.ok(Number.isInteger(data.remaining), d.path);
    }
  });

  test('the bookings cover unlocked and locked contact', () => {
    const unlocked = (id: string) => {
      const b = bookingDoc(id);
      const completedAt = b.timeline.filter((e) => e.status === 'completed').at(-1)?.at ?? null;
      return bookingContactUnlocked({ status: b.status, completedAt }, NOW);
    };
    assert.equal(unlocked('seed-booking-accepted'), true);
    assert.equal(unlocked('seed-booking-requested-binh'), true);
    assert.equal(unlocked('seed-booking-completed-recent'), true);
    assert.equal(unlocked('seed-booking-cancelled'), false);
    assert.equal(unlocked('seed-booking-completed-old'), false);
  });

  test('deterministic for a given clock', () => {
    assert.deepEqual(seedDocuments(NOW), seedDocuments(NOW));
  });
});
```

```ts
// app_flutter/firebase/functions/test/integration/seed.test.ts
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { SEED_BOOKINGS, SEED_PASSWORD, SEED_USERS, seedDocuments } from '../../seed/fixtures.js';

let app: App;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'seed-test');
});
after(async () => {
  await deleteApp(app);
});

describe('seed on the emulators', () => {
  test('writes every document and can run twice', async () => {
    const now = new Date();
    await applySeed(getFirestore(app), getAuth(app), now);
    await applySeed(getFirestore(app), getAuth(app), now);
    const db = getFirestore(app);
    for (const d of seedDocuments(now)) assert.ok((await db.doc(d.path).get()).exists, d.path);
    assert.equal((await db.collection('bookings').count().get()).data().count, SEED_BOOKINGS.length);
    assert.equal((await getAuth(app).listUsers()).users.length, SEED_USERS.length);
  });

  test('every seed account signs in with the documented password', async () => {
    for (const u of SEED_USERS) assert.ok((await signIn(u.email, SEED_PASSWORD)).length > 100, u.email);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run (from `app_flutter/firebase/functions`): `npm test`
Expected: FAIL: `seed_fixtures.test.ts` with `ERR_MODULE_NOT_FOUND` for `seed/fixtures.js`; the other 15 pass.

Run (outside the Claude sandbox, see Global Constraints): `npm run test:integration`
Expected: the emulators start (`✔ All emulators ready`), then `seed.test.ts` fails with `ERR_MODULE_NOT_FOUND`, and the script exits non-zero.

- [ ] **Step 3: Implement**

```ts
// app_flutter/firebase/functions/seed/fixtures.ts
// Deterministic local test data for the Firebase emulators. Test values only: these accounts
// and numbers exist nowhere but in the local emulators. Listed in seed/README.md.

export const SEED_PASSWORD = 'seed-password-1';
export const SEED_CREATED_AT = new Date('2026-09-01T00:00:00Z');

const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;

export const LAN = 'seed-customer-lan';
export const MINH = 'seed-customer-minh';
export const AN = 'seed-photographer-an';
export const BINH = 'seed-photographer-binh';

export interface SeedUser {
  readonly uid: string;
  readonly email: string;
  readonly displayName: string;
  readonly role: 'customer' | 'photographer';
}

export const SEED_USERS: readonly SeedUser[] = [
  { uid: LAN, email: 'lan.customer@seed.test', displayName: 'Lan (seed)', role: 'customer' },
  { uid: MINH, email: 'minh.nophone@seed.test', displayName: 'Minh (seed, no phone)', role: 'customer' },
  { uid: AN, email: 'an.verified@seed.test', displayName: 'An Studio (seed)', role: 'photographer' },
  { uid: BINH, email: 'binh.unverified@seed.test', displayName: 'Bình (seed)', role: 'photographer' },
];

/** Private customer numbers (`users/{uid}/private/contact`). Minh has none, for `phone_required`. */
export const SEED_CUSTOMER_PHONES: Readonly<Record<string, string>> = { [LAN]: '+84903000001' };

export interface SeedPhotographer {
  readonly uid: string;
  readonly verified: boolean;
  readonly bio: string;
  readonly city: string;
  readonly radiusKm: number;
  readonly specialties: readonly string[];
  readonly channels: { readonly call: boolean; readonly zalo: boolean; readonly whatsapp: boolean; readonly acceptInquiries: boolean };
  readonly numbers: { readonly phone: string; readonly zaloPhone?: string; readonly whatsappPhone?: string };
}

export const SEED_PHOTOGRAPHERS: readonly SeedPhotographer[] = [
  {
    uid: AN,
    verified: true,
    bio: 'Chân dung và cưới, ánh sáng tự nhiên.',
    city: 'Hà Nội',
    radiusKm: 20,
    specialties: ['portrait', 'wedding'],
    channels: { call: true, zalo: true, whatsapp: true, acceptInquiries: true },
    numbers: { phone: '+84912000001', zaloPhone: '+84912000002', whatsappPhone: '+14155550101' },
  },
  {
    uid: BINH,
    verified: false,
    bio: 'Ảnh gia đình cuối tuần.',
    city: 'Đà Nẵng',
    radiusKm: 15,
    specialties: ['family'],
    channels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    numbers: { phone: '+84987000001' },
  },
];

export interface SeedService {
  readonly id: string;
  readonly photographerId: string;
  readonly name: string;
  /** Integer VND. */
  readonly price: number;
  readonly durationMinutes: number;
}

export const SEED_SERVICES: readonly SeedService[] = [
  { id: 'seed-service-portrait', photographerId: AN, name: 'Chân dung 2 giờ', price: 1_500_000, durationMinutes: 120 },
  { id: 'seed-service-family', photographerId: BINH, name: 'Gia đình 90 phút', price: 1_200_000, durationMinutes: 90 },
];

export interface SeedBooking {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  readonly serviceId: string;
  readonly status: string;
  readonly date: string;
  readonly start: string;
  readonly end: string;
  readonly place: string;
  /** Days between completion and seeding; null when not completed. */
  readonly completedDaysAgo: number | null;
}

export const SEED_BOOKINGS: readonly SeedBooking[] = [
  { id: 'seed-booking-accepted', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'accepted', date: '2026-10-20', start: '08:00', end: '10:00', place: 'Hồ Hoàn Kiếm, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-requested-binh', customerId: LAN, photographerId: BINH, serviceId: 'seed-service-family', status: 'requested', date: '2026-10-25', start: '16:00', end: '17:30', place: 'Biển Mỹ Khê, Đà Nẵng', completedDaysAgo: null },
  { id: 'seed-booking-cancelled', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'cancelled', date: '2026-10-22', start: '08:00', end: '10:00', place: 'Văn Miếu, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-completed-recent', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-27', start: '08:00', end: '10:00', place: 'Hồ Tây, Hà Nội', completedDaysAgo: 3 },
  { id: 'seed-booking-completed-old', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-08-20', start: '08:00', end: '10:00', place: 'Phố cổ, Hà Nội', completedDaysAgo: 40 },
];

export interface SeedDocument {
  readonly path: string;
  readonly data: Record<string, unknown>;
}

const TIMELINE: Readonly<Record<string, readonly string[]>> = {
  requested: ['requested'],
  accepted: ['requested', 'accepted'],
  cancelled: ['requested', 'accepted', 'cancelled'],
  completed: ['requested', 'accepted', 'upcoming', 'completed'],
};

function bookingData(b: SeedBooking, now: Date): Record<string, unknown> {
  const service = SEED_SERVICES.find((s) => s.id === b.serviceId);
  if (service === undefined) throw new Error(`unknown seed service ${b.serviceId}`);
  const deposit = Math.floor(service.price * 0.3);
  const steps = TIMELINE[b.status] ?? [b.status];
  const last = b.completedDaysAgo === null
    ? new Date(SEED_CREATED_AT.getTime() + (steps.length - 1) * HOUR_MS)
    : new Date(now.getTime() - b.completedDaysAgo * DAY_MS);
  const timeline = steps.map((status, i) => ({ status, at: new Date(last.getTime() - (steps.length - 1 - i) * HOUR_MS) }));
  const createdAt = timeline[0]?.at ?? last;
  return {
    customerId: b.customerId,
    photographerId: b.photographerId,
    serviceId: b.serviceId,
    service: { name: service.name, price: service.price, durationMinutes: service.durationMinutes },
    date: b.date,
    start: b.start,
    end: b.end,
    location: { name: b.place },
    note: 'Seed booking',
    status: b.status,
    deposit: { amount: deposit, provider: 'momo', paymentId: b.id.replace('seed-booking-', 'seed-payment-'), paidAt: createdAt },
    remaining: service.price - deposit,
    timeline,
    createdAt,
    updatedAt: last,
  };
}

/** Every Firestore document of the seed, in write order. Pure: same `now`, same documents. */
export function seedDocuments(now: Date): SeedDocument[] {
  const at = SEED_CREATED_AT;
  const docs: SeedDocument[] = [];
  for (const u of SEED_USERS) {
    docs.push({ path: `users/${u.uid}`, data: { displayName: u.displayName, role: u.role, createdAt: at, updatedAt: at } });
  }
  for (const [uid, phone] of Object.entries(SEED_CUSTOMER_PHONES)) {
    docs.push({
      path: `users/${uid}/private/contact`,
      data: { phone, phoneVerified: false, allowZalo: true, allowWhatsApp: false, updatedAt: at },
    });
  }
  for (const p of SEED_PHOTOGRAPHERS) {
    docs.push({
      path: `photographers/${p.uid}`,
      data: {
        bio: p.bio,
        specialties: [...p.specialties],
        serviceArea: { city: p.city, radiusKm: p.radiusKm },
        contactChannels: { ...p.channels },
        onboardingComplete: true,
        verified: p.verified,
        ...(p.verified ? { verifiedAt: at } : {}),
        createdAt: at,
        updatedAt: at,
      },
    });
    docs.push({ path: `photographers/${p.uid}/private/contact`, data: { ...p.numbers, updatedAt: at } });
  }
  for (const s of SEED_SERVICES) {
    docs.push({
      path: `photographers/${s.photographerId}/services/${s.id}`,
      data: { name: s.name, price: s.price, currency: 'VND', durationMinutes: s.durationMinutes, active: true, createdAt: at },
    });
  }
  for (const b of SEED_BOOKINGS) docs.push({ path: `bookings/${b.id}`, data: bookingData(b, now) });
  return docs;
}
```

```ts
// app_flutter/firebase/functions/seed/apply.ts
import type { Auth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { SEED_PASSWORD, SEED_USERS, seedDocuments } from './fixtures.js';

/** Writes the seed into the emulators. Idempotent: fixed ids, documents replaced, users updated. */
export async function applySeed(db: Firestore, auth: Auth, now: Date): Promise<void> {
  for (const u of SEED_USERS) {
    const props = { email: u.email, password: SEED_PASSWORD, displayName: u.displayName, emailVerified: true };
    try {
      await auth.updateUser(u.uid, props);
    } catch (e) {
      if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
      await auth.createUser({ uid: u.uid, ...props });
    }
  }
  const batch = db.batch();
  for (const d of seedDocuments(now)) batch.set(db.doc(d.path), d.data);
  await batch.commit();
}
```

```ts
// app_flutter/firebase/functions/seed/seed.ts
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applySeed } from './apply.js';
import { SEED_BOOKINGS, SEED_USERS } from './fixtures.js';

// CLI: `npm run seed` (scripts/backend-local.sh runs it). Refuses anything but local emulators.
const LOCAL = /^(127\.0\.0\.1|localhost|0\.0\.0\.0|\[::1\]):\d+$/;
for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
  const value = process.env[key];
  if (value === undefined || !LOCAL.test(value)) {
    console.error(`Refusing to seed: ${key} must point at a local emulator (got ${value ?? 'nothing'}).`);
    process.exit(1);
  }
}
const project = process.env.GCLOUD_PROJECT;
if (project === undefined || project === '') {
  console.error('Refusing to seed: GCLOUD_PROJECT is not set.');
  process.exit(1);
}

initializeApp({ projectId: project });
await applySeed(getFirestore(), getAuth(), new Date());
console.log(`Seeded ${SEED_USERS.length} users and ${SEED_BOOKINGS.length} bookings into ${project} (emulators).`);
console.log('Accounts: app_flutter/firebase/functions/seed/README.md');
```

```ts
// app_flutter/firebase/functions/seed/emulator_client.ts
import { REGION } from '../src/config.js';

// Talks to the emulators over their REST endpoints, like the app does: Auth sign-in and the
// callable protocol (POST {data} → {result} | {error}). Used by the integration tests and try_contact_link.ts.

const host = (key: string, fallback: string): string => process.env[key] ?? fallback;
const authHost = () => host('FIREBASE_AUTH_EMULATOR_HOST', '127.0.0.1:9099');
const firestoreHost = () => host('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8080');
const functionsHost = () => host('FUNCTIONS_EMULATOR_HOST', '127.0.0.1:5001');

export function emulatorProject(): string {
  const project = process.env.GCLOUD_PROJECT;
  if (project === undefined || project === '') throw new Error('GCLOUD_PROJECT is not set (run under firebase emulators:exec)');
  return project;
}

/** Signs in on the Auth emulator and returns an ID token. */
export async function signIn(email: string, password: string): Promise<string> {
  const res = await fetch(
    `http://${authHost()}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }) },
  );
  const body = (await res.json()) as { idToken?: string };
  if (!res.ok || body.idToken === undefined) throw new Error(`sign-in failed for ${email}: HTTP ${res.status}`);
  return body.idToken;
}

export interface CallableResponse {
  readonly status: number;
  /** Raw response body, for asserting what travels over the wire. */
  readonly text: string;
  readonly result?: unknown;
  readonly error?: { readonly message?: string; readonly status?: string; readonly details?: unknown };
}

/** Invokes a callable exactly like the Firebase client SDK does. */
export async function callCallable(name: string, data: unknown, idToken?: string): Promise<CallableResponse> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (idToken !== undefined) headers.Authorization = `Bearer ${idToken}`;
  const res = await fetch(`http://${functionsHost()}/${emulatorProject()}/${REGION}/${name}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let parsed: { result?: unknown; error?: CallableResponse['error'] } = {};
  try {
    parsed = JSON.parse(text) as typeof parsed;
  } catch {
    // Not a callable response (for example the emulator's 404 for an unknown function).
  }
  return { status: res.status, text, ...parsed };
}

/** Empties Firestore and Auth of the emulator project (emulator-only REST endpoints). */
export async function resetEmulators(): Promise<void> {
  const project = emulatorProject();
  await fetch(`http://${firestoreHost()}/emulator/v1/projects/${project}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`http://${authHost()}/emulator/v1/projects/${project}/accounts`, { method: 'DELETE' });
}
```

```ts
// app_flutter/firebase/functions/seed/try_contact_link.ts
import { SEED_PASSWORD } from './fixtures.js';
import { callCallable, signIn } from './emulator_client.js';

// Manual check: npm run try:contact -- <seed email> <bookingId> <call|zalo|whatsapp>
const [email, bookingId, channel] = process.argv.slice(2);
if (email === undefined || bookingId === undefined || channel === undefined) {
  console.error('Usage: npm run try:contact -- <seed email> <bookingId> <call|zalo|whatsapp>');
  process.exit(2);
}
const token = await signIn(email, SEED_PASSWORD);
const res = await callCallable('getContactLink', { bookingId, channel }, token);
console.log(res.status, res.text);
```

````markdown
<!-- app_flutter/firebase/functions/seed/README.md -->
# Seed data (local emulators only)

`scripts/backend-local.sh` loads this seed on the first start (or with `--fresh` / `--seed`).
Source: `fixtures.ts`. **Test values only**: these accounts and numbers exist only in the
local Auth and Firestore emulators; the seed refuses to run unless `FIRESTORE_EMULATOR_HOST`
and `FIREBASE_AUTH_EMULATOR_HOST` point at a local host.

Password for every account: `seed-password-1`

| Account (email) | uid | Role | Notes |
|---|---|---|---|
| `lan.customer@seed.test` | `seed-customer-lan` | customer | private phone `+84903000001` (Zalo allowed) |
| `minh.nophone@seed.test` | `seed-customer-minh` | customer | no phone: server answers `phone_required` |
| `an.verified@seed.test` | `seed-photographer-an` | photographer | verified, Hà Nội; Gọi + Zalo + WhatsApp; `+84912000001`, Zalo `+84912000002`, WhatsApp `+14155550101` |
| `binh.unverified@seed.test` | `seed-photographer-binh` | photographer | not verified, Đà Nẵng; Gọi only; `+84987000001` |

| Booking | Customer ↔ photographer | Status | `getContactLink` |
|---|---|---|---|
| `seed-booking-accepted` | Lan ↔ An | accepted | unlocked (all three channels) |
| `seed-booking-requested-binh` | Lan ↔ Bình | requested | `call` only; `zalo`/`whatsapp` → `not_found` |
| `seed-booking-cancelled` | Lan ↔ An | cancelled | `contact_locked` |
| `seed-booking-completed-recent` | Lan ↔ An | completed 3 days before seeding | unlocked |
| `seed-booking-completed-old` | Lan ↔ An | completed 40 days before seeding | `contact_locked` |

Try a call while the emulators run (from `app_flutter/firebase/functions`, with the project id
`scripts/backend-local.sh` printed):

```bash
GCLOUD_PROJECT=<project> npm run try:contact -- lan.customer@seed.test seed-booking-accepted zalo
# 200 {"result":{"url":"https://zalo.me/84912000002"}}
```
````

(Write the README without the first `<!-- … -->` line.)

- [ ] **Step 4: Run and see it pass**

Run (from `app_flutter/firebase/functions`): `npm run lint && npm test`
Expected: lint clean; `ℹ tests 21`, `ℹ pass 21`, `ℹ fail 0`.

Run (outside the sandbox): `npm run test:integration`
Expected: `✔ seed on the emulators`, `ℹ tests 2`, `ℹ pass 2`, `ℹ fail 0`, then `✔ Script exited successfully (code 0)`.

- [ ] **Step 5: Commit**

```bash
git add app_flutter/firebase/functions
git commit -m "feat(functions): deterministic emulator seed, account list and emulator test client

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Wire `getContactLink` and `requirePhone`; ContactAccessLog rules; emulator integration tests

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/live.ts`, `src/infra/require_phone.ts`, `test/integration/get_contact_link.test.ts`, `test/integration/read_budget.test.ts`, `test/integration/require_phone.test.ts`
- Modify: `app_flutter/firebase/functions/src/index.ts`, `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/rules-test/rules.test.mjs`, `docs/superpowers/specs/data-model/relational-schema.md`

**Interfaces:**
- Consumes: Tasks 3–5 (`getContactLink`, `requireCustomerPhone`, adapters, `CALLABLE_OPTIONS`, `handleGetContactLink`, seed, `callCallable`, `signIn`).
- Produces:
  - Deployed function `getContactLink` (region `asia-southeast1`), emulator URL `http://127.0.0.1:5001/<project>/asia-southeast1/getContactLink`.
  - `liveContactDeps(): GetContactLinkDeps` (no registration reader yet).
  - `makeRequirePhone(firestore: Firestore): (uid: string) => Promise<string>` for the later `transitionBooking` / `registerEvent` plans.
  - Wire results (as seen by the client): success body `{"result":{"url":"…"}}`; refusal body e.g. `{"error":{"details":{"code":"contact_locked"},"message":"contact_locked","status":"FAILED_PRECONDITION"}}`; statuses `PERMISSION_DENIED`, `UNAUTHENTICATED`, `NOT_FOUND`, `INVALID_ARGUMENT`.
  - Rule: `contact_access_log/{logId}` no client read or write.

- [ ] **Step 1: Write the failing tests**

```ts
// app_flutter/firebase/functions/test/integration/get_contact_link.test.ts
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// The real callable on the Functions emulator, invoked with an Auth emulator ID token.
// App Check is not enforced locally (CALLABLE_OPTIONS.enforceAppCheck = false).

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'contact-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (uid: string | null, data: unknown) =>
  callCallable('getContactLink', data, uid === null ? undefined : tokens.get(uid));
const logsOf = async (uid: string) =>
  (await db.collection('contact_access_log').where('requesterId', '==', uid).get()).docs.map((d) => d.data());

describe('getContactLink on the emulators', () => {
  test('the customer of an accepted booking gets each URL, and only the URL', async () => {
    const expected: Record<string, string> = {
      call: 'tel:+84912000001',
      zalo: 'https://zalo.me/84912000002',
      whatsapp: 'https://wa.me/14155550101',
    };
    for (const [channel, url] of Object.entries(expected)) {
      const res = await call(LAN, { bookingId: 'seed-booking-accepted', channel });
      assert.equal(res.status, 200, res.text);
      // The whole body is {"result":{"url":…}}: the number travels only inside the URL.
      assert.deepEqual(JSON.parse(res.text), { result: { url } });
    }
  });

  test('a locked booking answers contact_locked exactly as the client expects', async () => {
    for (const bookingId of ['seed-booking-cancelled', 'seed-booking-completed-old']) {
      const res = await call(LAN, { bookingId, channel: 'call' });
      assert.equal(res.error?.status, 'FAILED_PRECONDITION', res.text);
      assert.equal(res.error?.message, 'contact_locked');
      assert.deepEqual(res.error?.details, { code: 'contact_locked' });
      assert.doesNotMatch(res.text, /\d{9}/);
    }
  });

  test('a booking completed 3 days ago is still open', async () => {
    const res = await call(LAN, { bookingId: 'seed-booking-completed-recent', channel: 'call' });
    assert.deepEqual(res.result, { url: 'tel:+84912000001' });
  });

  test('only the customer may ask: the photographer and other customers are refused', async () => {
    for (const uid of [AN, MINH]) {
      const res = await call(uid, { bookingId: 'seed-booking-accepted', channel: 'call' });
      assert.equal(res.error?.status, 'PERMISSION_DENIED', res.text);
      assert.deepEqual(res.error?.details, { code: 'permission_denied' });
    }
  });

  test('signed-out calls are unauthenticated', async () => {
    const res = await call(null, { bookingId: 'seed-booking-accepted', channel: 'call' });
    assert.equal(res.error?.status, 'UNAUTHENTICATED', res.text);
  });

  test('a channel the photographer switched off is not found; the one switched on works', async () => {
    const off = await call(LAN, { bookingId: 'seed-booking-requested-binh', channel: 'zalo' });
    assert.equal(off.error?.status, 'NOT_FOUND', off.text);
    const on = await call(LAN, { bookingId: 'seed-booking-requested-binh', channel: 'call' });
    assert.deepEqual(on.result, { url: 'tel:+84987000001' });
  });

  test('registration links are not found until the events plan', async () => {
    const res = await call(LAN, { registrationId: 'seed-registration-1', channel: 'call' });
    assert.equal(res.error?.status, 'NOT_FOUND', res.text);
  });

  test('malformed requests are invalid and leave no log row', async () => {
    const before = (await logsOf(MINH)).length;
    for (const data of [{}, { bookingId: 'seed-booking-accepted', channel: 'in_app' }, { bookingId: 'a/b', channel: 'call' }]) {
      const res = await call(MINH, data);
      assert.equal(res.error?.status, 'INVALID_ARGUMENT', res.text);
    }
    assert.equal((await logsOf(MINH)).length, before);
  });

  test('every answered request wrote one ContactAccessLog row without any number', async () => {
    const rows = await logsOf(LAN);
    // 3 granted + 2 locked + 1 recent + 2 on Bình's booking (1 refused) + 1 registration.
    assert.equal(rows.length, 9);
    assert.equal(rows.filter((r) => r.granted === true).length, 5);
    for (const r of rows) {
      assert.deepEqual(Object.keys(r).sort(), ['at', 'channel', 'granted', 'requesterId', 'subjectId', 'subjectType']);
      assert.ok(r.at instanceof Timestamp);
      assert.doesNotMatch(JSON.stringify({ ...r, at: null }), /\d{9}/);
    }
  });
});
```

```ts
// app_flutter/firebase/functions/test/integration/read_budget.test.ts
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getContactLink, type GetContactLinkDeps } from '@photobooking/domain';
import {
  firestoreBookingReader,
  firestoreContactAccessLog,
  firestorePhotographerContactReader,
} from '../../src/infra/firestore.js';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { LAN } from '../../seed/fixtures.js';

let app: App;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'budget-test');
  await applySeed(getFirestore(app), getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

/** Counts what the real adapters read; they read only through getAll (asserted below). */
function counted(db: Firestore): { documents: number; roundTrips: number } {
  const reads = { documents: 0, roundTrips: 0 };
  const getAll = db.getAll.bind(db);
  Object.assign(db, {
    getAll: (...refs: Parameters<Firestore['getAll']>) => {
      reads.roundTrips += 1;
      reads.documents += refs.length;
      return getAll(...refs);
    },
  });
  return reads;
}

test('an unlocked call reads 3 documents in 2 round trips; a locked one reads 1', async () => {
  const db = getFirestore(app);
  const reads = counted(db);
  let n = 0;
  const deps: GetContactLinkDeps = {
    bookings: firestoreBookingReader(db),
    photographers: firestorePhotographerContactReader(db),
    log: firestoreContactAccessLog(db),
    clock: { now: () => new Date() },
    ids: { newId: () => `budget-${++n}` },
  };
  assert.deepEqual(
    await getContactLink(LAN, { bookingId: 'seed-booking-accepted', channel: 'zalo' }, deps),
    { url: 'https://zalo.me/84912000002' },
  );
  assert.deepEqual(reads, { documents: 3, roundTrips: 2 });
  reads.documents = 0;
  reads.roundTrips = 0;
  await assert.rejects(getContactLink(LAN, { bookingId: 'seed-booking-cancelled', channel: 'zalo' }, deps));
  assert.deepEqual(reads, { documents: 1, roundTrips: 1 });
});

test('the adapters read only through getAll, so the count above is complete', () => {
  const src = readFileSync('src/infra/firestore.ts', 'utf8');
  assert.doesNotMatch(src, /\.get\(\)/);
  assert.doesNotMatch(src, /\.where\(|\.collectionGroup\(|runTransaction|\.listDocuments\(/);
});
```

```ts
// app_flutter/firebase/functions/test/integration/require_phone.test.ts
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { DomainError } from '@photobooking/domain';
import { makeRequirePhone } from '../../src/infra/require_phone.js';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { LAN, MINH } from '../../seed/fixtures.js';

let app: App;
const phoneRequired = (e: unknown) => e instanceof DomainError && e.code === 'phone_required';

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'phone-test');
  await applySeed(getFirestore(app), getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

test('requirePhone returns the stored number or refuses with phone_required', async () => {
  const requirePhone = makeRequirePhone(getFirestore(app));
  assert.equal(await requirePhone(LAN), '+84903000001');
  await assert.rejects(requirePhone(MINH), phoneRequired);
  await assert.rejects(requirePhone('seed-nobody'), phoneRequired);
});

test('a malformed stored number is phone_required too', async () => {
  const db = getFirestore(app);
  await db.doc('users/seed-bad-phone/private/contact').set({ phone: '0903000001' });
  await assert.rejects(makeRequirePhone(db)('seed-bad-phone'), phoneRequired);
});
```

Append to `app_flutter/firebase/rules-test/rules.test.mjs` (uses the existing imports `doc`, `setDoc`, `getDoc`, `assertFails` and `env`):

```js
test('contact access log is server-only: no client reads or writes, not even the requester', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'contact_access_log/l1'), {
    requesterId: 'u1', subjectType: 'booking', subjectId: 'b1', channel: 'call', granted: true,
  }));
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(getDoc(doc(db, 'contact_access_log/l1')));
  await assertFails(setDoc(doc(db, 'contact_access_log/l2'), { requesterId: 'u1' }));
});
```

- [ ] **Step 2: Run and see it fail**

Run (from `app_flutter/firebase/functions`, outside the sandbox): `npm run test:integration`
Expected: FAIL. `get_contact_link.test.ts`: every test fails with status 404 and the body `Function asia-southeast1-getContactLink does not exist, valid functions are:` (nothing is exported yet). `require_phone.test.ts`: `ERR_MODULE_NOT_FOUND` for `src/infra/require_phone.js`. `read_budget.test.ts` and `seed.test.ts` pass already (the adapters exist since Task 4; this test pins their budget).

The rules test passes before the rule change too (the catch-all `match /{document=**}` already denies); it pins the policy so a later broad rule cannot open the log.

- [ ] **Step 3: Implement**

```ts
// app_flutter/firebase/functions/src/infra/live.ts
import { newUlid, type GetContactLinkDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { firestoreBookingReader, firestoreContactAccessLog, firestorePhotographerContactReader } from './firestore.js';

/**
 * Production wiring of getContactLink. `registrations` is left out on purpose: event registrations
 * do not exist yet, so registration requests answer `not_found` until the events plan adds a reader.
 */
export function liveContactDeps(): GetContactLinkDeps {
  const firestore = db();
  return {
    bookings: firestoreBookingReader(firestore),
    photographers: firestorePhotographerContactReader(firestore),
    log: firestoreContactAccessLog(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
```

```ts
// app_flutter/firebase/functions/src/infra/require_phone.ts
import type { Firestore } from 'firebase-admin/firestore';
import { requireCustomerPhone } from '@photobooking/domain';
import { firestoreUserContactReader } from './firestore.js';

/**
 * Server-side `phone_required` guard for transitionBooking(requested) and registerEvent (later plans):
 *   const requirePhone = makeRequirePhone(db());
 *   const phone = await requirePhone(uid); // E.164, or throws DomainError('phone_required')
 * One document read (`users/{uid}/private/contact`).
 */
export function makeRequirePhone(firestore: Firestore): (uid: string) => Promise<string> {
  const contacts = firestoreUserContactReader(firestore);
  return (uid) => requireCustomerPhone(contacts, uid);
}
```

Replace `app_flutter/firebase/functions/src/index.ts` with:

```ts
import { onCall } from 'firebase-functions/v2/https';
import { handleGetContactLink } from './callables/get_contact_link.js';
import { CALLABLE_OPTIONS } from './config.js';
import { liveContactDeps } from './infra/live.js';

// Entry point of the Cloud Functions codebase. Each export is one deployed function.

/** `{bookingId | registrationId, channel}` → `{url}`; contract in plan 2b "Out of scope". */
export const getContactLink = onCall(CALLABLE_OPTIONS, (request) => handleGetContactLink(request, liveContactDeps()));
```

In `app_flutter/firebase/firestore.rules`, insert directly before the final catch-all block `match /{document=**} {`:

```
    // ContactAccessLog: written only by getContactLink through the Admin SDK (rules do not apply
    // to it). No client may read or write it, not even the requester.
    match /contact_access_log/{logId} {
      allow read, write: if false;
    }

```

In `docs/superpowers/specs/data-model/relational-schema.md` §3, after the row

```
| `recommendation_logs/{id}` | `recommendation_logs` | |
```

add

```
| `contact_access_log/{id}` | `contact_access_log` | Ghi bởi `getContactLink` (Admin SDK), id ULID; client không đọc/ghi; không chứa số điện thoại |
```

- [ ] **Step 4: Run and see it pass**

Run (from `app_flutter/firebase/functions`): `npm run lint && npm test`
Expected: lint clean; `ℹ tests 21`, `ℹ pass 21`.

Run (outside the sandbox): `npm run test:integration`
Expected: `✔ functions[asia-southeast1-getContactLink]: http function initialized (http://127.0.0.1:5001/demo-nag/asia-southeast1/getContactLink).`, then `ℹ tests 15`, `ℹ pass 15`, `ℹ fail 0`, `✔ Script exited successfully (code 0)`.

Run (from `app_flutter/firebase/rules-test`): `npm test`
Expected: all rules tests pass, including the new one.

- [ ] **Step 5: Commit**

```bash
git add app_flutter/firebase docs/superpowers/specs/data-model/relational-schema.md
git commit -m "feat(functions): getContactLink callable, server-side requirePhone and server-only access log

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: One command, docs and CI

**Files:**
- Create: `scripts/backend-local.sh`
- Modify: `app_flutter/README.md`, `CLAUDE.md`, `.github/workflows/flutter.yml`

**Interfaces:**
- Consumes: `scripts/env.sh` (JDK, `NODE_EXTRA_CA_CERTS`; written for interactive shells), npm scripts `build`, `build:watch` (`node build.mjs --watch`), `seed` (Tasks 4–5), `firebase.json` hosts/ports.
- Produces: `scripts/backend-local.sh [--fresh] [--seed] [--lan] [--help]`: installs missing node_modules, builds, starts the esbuild watcher, starts all emulators in the foreground with `--import` (when saved data exists) and `--export-on-exit app_flutter/firebase/.emulator-data`, seeds on first start, prints the `flutter run` lines per target. Ctrl-C saves the data and stops the watcher. Exit code 2 for an unknown option.

- [ ] **Step 1: Run the missing command (fails)**

Run (repo root): `scripts/backend-local.sh --help`
Expected: `zsh: no such file or directory: scripts/backend-local.sh` (or `bash: …: No such file or directory`).

- [ ] **Step 2: Implement the script**

```bash
#!/usr/bin/env bash
# Local backend in one command: Firebase Emulator Suite (Auth, Firestore, Functions, Storage, UI)
# with saved data, the Cloud Functions build in watch mode, and the seed on first start.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/backend-local.sh [--fresh] [--seed] [--lan] [--help]

Starts the Firebase Emulator Suite for app_flutter (Auth 9099, Firestore 8080, Functions 5001,
Storage 9199, Emulator UI http://127.0.0.1:4000) and rebuilds Cloud Functions on every change.
Data is saved to app_flutter/firebase/.emulator-data on Ctrl-C and loaded on the next start.

  --fresh   delete the saved emulator data first (then seed)
  --seed    apply the seed again on top of the saved data
  --lan     listen on 0.0.0.0 instead of 127.0.0.1 (Genymotion, real devices on the same Wi-Fi)
  --help    show this text

Project id: $FIREBASE_PROJECT, else project_info.project_id of
app_flutter/android/app/google-services.json, else demo-nag.
Seed accounts: app_flutter/firebase/functions/seed/README.md
EOF
}

FRESH=0 SEED=0 LAN=0
for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=1 ;;
    --seed) SEED=1 ;;
    --lan) LAN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FB="$ROOT/app_flutter/firebase"
FN="$FB/functions"
DOMAIN="$ROOT/packages/domain"
DATA="$FB/.emulator-data"
CONFIG="$FB/firebase.json"

# JDK for the Firestore emulator and the corporate CA for npm (NODE_EXTRA_CA_CERTS).
# env.sh is written for interactive shells (some of its lines return non-zero), so relax -e/-u.
set +eu
# shellcheck source=scripts/env.sh
source "$ROOT/scripts/env.sh" >/dev/null
set -eu
export HOME="$ROOT/.home"   # firebase-tools and npm write their caches inside the repo
mkdir -p "$HOME"
export JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true

command -v node >/dev/null || { echo "Node.js 22 or newer is required (brew install node@22)." >&2; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 22 ] || { echo "Node.js 22 or newer is required, found $(node -v)." >&2; exit 1; }

GS="$ROOT/app_flutter/android/app/google-services.json"
if [ -n "${FIREBASE_PROJECT:-}" ]; then
  PROJECT="$FIREBASE_PROJECT"
elif [ -f "$GS" ]; then
  PROJECT="$(node -p 'require(process.argv[1]).project_info.project_id' "$GS")"
else
  PROJECT=demo-nag
fi

[ -d "$DOMAIN/node_modules" ] || npm --prefix "$DOMAIN" ci
[ -d "$FN/node_modules" ] || npm --prefix "$FN" ci
npm --prefix "$FN" run --silent build

if [ "$LAN" = 1 ]; then
  CONFIG="$FB/.firebase.lan.json"
  node -e '
    const fs = require("fs");
    const [src, dst] = process.argv.slice(1);
    const c = JSON.parse(fs.readFileSync(src, "utf8"));
    for (const v of Object.values(c.emulators)) if (v && typeof v === "object" && "host" in v) v.host = "0.0.0.0";
    fs.writeFileSync(dst, JSON.stringify(c, null, 2));
  ' "$FB/firebase.json" "$CONFIG"
fi

if [ "$FRESH" = 1 ]; then rm -rf "$DATA"; fi
IMPORT=()
if [ -f "$DATA/firebase-export-metadata.json" ]; then
  IMPORT=(--import "$DATA")
else
  SEED=1
fi

seed_when_ready() {
  for _ in $(seq 1 120); do
    if curl -fsS "http://127.0.0.1:8080/" >/dev/null 2>&1 && curl -fsS "http://127.0.0.1:9099/" >/dev/null 2>&1; then
      FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT="$PROJECT" \
        npm --prefix "$FN" run --silent seed
      return
    fi
    sleep 1
  done
  echo "Emulators did not answer within 120 s; seed skipped (run again with --seed)." >&2
}

WATCH_PID="" SEED_PID=""
cleanup() {
  [ -z "$WATCH_PID" ] || kill "$WATCH_PID" 2>/dev/null || true
  [ -z "$SEED_PID" ] || kill "$SEED_PID" 2>/dev/null || true
}
trap cleanup EXIT

(cd "$FN" && exec node build.mjs --watch) &
WATCH_PID=$!
if [ "$SEED" = 1 ]; then
  seed_when_ready &
  SEED_PID=$!
fi

cat <<EOF
Project: $PROJECT   Emulator UI: http://127.0.0.1:4000   Data: $DATA
Run the app (debug) against it, from app_flutter/:
  Android emulator   flutter run --dart-define=USE_EMULATORS=true
  iOS Simulator      flutter run --dart-define=USE_EMULATORS=true                (after the iOS enablement plan)
  Genymotion         flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2   (start with --lan)
  Real device        flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=<this Mac's LAN IP>   (start with --lan)
Ctrl-C stops everything and saves the data.
EOF

cd "$FN"
"$FN/node_modules/.bin/firebase" emulators:start \
  --config "$CONFIG" --project "$PROJECT" \
  ${IMPORT[@]+"${IMPORT[@]}"} --export-on-exit "$DATA"
```

Save as `scripts/backend-local.sh` and run `chmod +x scripts/backend-local.sh`. Notes: the emulators run in the foreground so Ctrl-C reaches `firebase` directly and the export runs; `${IMPORT[@]+…}` keeps macOS's bash 3.2 happy with an empty array under `set -u`.

- [ ] **Step 3: Check the script**

Run: `bash -n scripts/backend-local.sh && scripts/backend-local.sh --help | head -1; scripts/backend-local.sh --bogus; echo "exit=$?"`
Expected: `Usage: scripts/backend-local.sh [--fresh] [--seed] [--lan] [--help]`, then `Unknown option: --bogus`, the usage on stderr, and `exit=2`.

Run (outside the sandbox): `scripts/backend-local.sh --fresh`
Expected, in order: `Project: <your project id>   Emulator UI: http://127.0.0.1:4000 …`, `✔  All emulators ready! It is now safe to connect your app.`, `Seeded 4 users and 5 bookings into <project> (emulators).`. In a second terminal (from `app_flutter/firebase/functions`): `GCLOUD_PROJECT=<project> npm run try:contact -- lan.customer@seed.test seed-booking-accepted zalo` prints `200 {"result":{"url":"https://zalo.me/84912000002"}}`; with `seed-booking-cancelled call` it prints `400 {"error":{"details":{"code":"contact_locked"},"message":"contact_locked","status":"FAILED_PRECONDITION"}}`. Ctrl-C in the first terminal prints `✔  Export complete`; `app_flutter/firebase/.emulator-data/` contains `auth_export`, `firestore_export`, `storage_export`, `firebase-export-metadata.json`. Start again without flags: the log shows `firestore: Importing data from …` and `auth: Importing accounts from …` and no `Seeded` line; `try:contact … seed-booking-accepted call` prints `200 {"result":{"url":"tel:+84912000001"}}`. Editing any file in `functions/src` prints a new `lib/index.js` line from the watcher and the Functions emulator reloads.

- [ ] **Step 4: Docs**

In `app_flutter/README.md`, add this section after the `## Tests` section:

````markdown
## Local backend (Firebase Emulator Suite)

One command from the repo root (Node 22+, JDK 17 via `scripts/env.sh`):

```bash
scripts/backend-local.sh            # start; reuses saved data, seeds on the first run
scripts/backend-local.sh --fresh    # wipe saved data, then seed
scripts/backend-local.sh --seed     # re-apply the seed on top of saved data
scripts/backend-local.sh --lan      # listen on 0.0.0.0 (Genymotion, real devices)
```

| Service | Port | Notes |
|---|---|---|
| Emulator UI | 4000 | http://127.0.0.1:4000 |
| Auth | 9099 | seed accounts: `firebase/functions/seed/README.md` (password `seed-password-1`) |
| Firestore | 8080 | rules from `firebase/firestore.rules` |
| Functions | 5001 | `asia-southeast1`, rebuilt by `node build.mjs --watch` |
| Storage | 9199 | rules from `firebase/storage.rules` (deny all for now) |

Data is saved to `firebase/.emulator-data/` (gitignored) on Ctrl-C. The emulator project id is the
app's own (`android/app/google-services.json`), because Android initialises Firebase natively with it;
override with `FIREBASE_PROJECT=…`.

Run the debug app against it (from `app_flutter/`):

| Target | Command | Backend flag |
|---|---|---|
| Android emulator | `flutter run --dart-define=USE_EMULATORS=true` (host `10.0.2.2`) | — |
| iOS Simulator | `flutter run --dart-define=USE_EMULATORS=true` (host `127.0.0.1`); needs the iOS enablement plan first | — |
| Genymotion | `flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2` | `--lan` |
| Real Android/iOS device | `--dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=$(ipconfig getifaddr en0)` (same Wi-Fi) | `--lan` |
| Real Android via USB | `adb reverse tcp:9099 tcp:9099 && adb reverse tcp:8080 tcp:8080 && adb reverse tcp:5001 tcp:5001 && adb reverse tcp:9199 tcp:9199`, then `--dart-define=EMULATOR_HOST=127.0.0.1` | — |

Only debug builds honour `USE_EMULATORS`; the app logs `Firebase: using local emulators at <host>`.
When switching an installed app between the cloud and the emulators, clear its data first
(`adb shell pm clear com.thanhbk.photobooking`) so a cloud sign-in is not reused. App Check is not
enforced locally. Inside the Claude Code sandbox the Functions emulator cannot open its Unix socket;
run the script and the emulator tests outside it.

Backend tests:

```bash
(cd ../packages/domain && npm test)                                         # pure rules, no emulator
(cd firebase/functions && npm test && npm run test:integration)              # unit + emulator integration
(cd firebase/functions && npm run test:perf)                                 # local performance budgets
```
````

In `CLAUDE.md`, under "### Commands (run from `app_flutter/`)", replace the code block

```bash
source ../scripts/env.sh && export HOME="$PWD/../.home"   # project-local Flutter/JDK; HOME avoids tool-telemetry writes outside the sandbox
export PATH="$PWD/../.flutter/bin:$PATH"
flutter analyze && flutter test
dart run tool/gen_tokens.dart      # after editing design-system/tokens.json
flutter gen-l10n                   # after editing lib/l10n/app_vi.arb
```

with

```bash
source ../scripts/env.sh && export HOME="$PWD/../.home"   # project-local Flutter/JDK; HOME avoids tool-telemetry writes outside the sandbox
export PATH="$PWD/../.flutter/bin:$PATH"
flutter analyze && flutter test
dart run tool/gen_tokens.dart      # after editing design-system/tokens.json
flutter gen-l10n                   # after editing lib/l10n/app_vi.arb
../scripts/backend-local.sh        # local backend: Auth/Firestore/Functions/Storage emulators + UI :4000, seed; --fresh, --seed, --lan
flutter run --dart-define=USE_EMULATORS=true                                          # debug app → local backend (Android emulator 10.0.2.2, iOS Simulator 127.0.0.1)
flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2     # Genymotion (backend with --lan); real device: the Mac's LAN IP
(cd ../packages/domain && npm test)                                                   # pure domain rules (TypeScript, no Firebase)
(cd firebase/functions && npm test && npm run test:integration)                       # Cloud Functions unit + emulator tests (outside the Claude sandbox)
```

and, in "### Rules to follow", after the **Firebase isolation** bullet, add:

```markdown
- **Server code**: Cloud Functions live in `app_flutter/firebase/functions` (thin adapters: callables, Firestore access, wiring; region `asia-southeast1`); business rules live in `packages/domain` (TypeScript, no Firebase or Node imports, enforced by lint and a test) so a self-hosted server can reuse them. Seed accounts for the emulators are listed in `app_flutter/firebase/functions/seed/README.md` (test values only).
```

- [ ] **Step 5: CI**

In `.github/workflows/flutter.yml`, change the `pull_request` paths to

```yaml
    paths: ['app_flutter/**', 'design-system/**', 'packages/**', '.github/workflows/flutter.yml']
```

and add after the step `Firestore rules tests (emulator)`:

```yaml
      - name: Domain package (pure TypeScript)
        working-directory: packages/domain
        run: npm ci && npm run typecheck && npm run lint && npm test
      - name: Cloud Functions (unit + emulator integration)
        working-directory: app_flutter/firebase/functions
        run: npm ci && npm run lint && npm test && npm run test:integration
```

(The job already sets up Java 17 and Node 22.)

- [ ] **Step 6: Commit**

```bash
git add scripts/backend-local.sh app_flutter/README.md CLAUDE.md .github/workflows/flutter.yml
git commit -m "feat(dev): one-command local backend with saved data, seed and functions watch; docs and CI

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Flutter debug builds talk to the emulators (Android, Genymotion, iOS, device)

**Files:**
- Create: `app_flutter/lib/data/backend/backend_config.dart`, `app_flutter/android/app/src/debug/res/xml/network_security_config.xml`, `app_flutter/test/data/backend/backend_config_test.dart`, `app_flutter/test/emulator_platform_config_test.dart`
- Modify: `app_flutter/pubspec.yaml`, `app_flutter/pubspec.lock`, `app_flutter/lib/main.dart`, `app_flutter/android/app/src/debug/AndroidManifest.xml`, `app_flutter/ios/Runner/Info.plist`, `app_flutter/lib/data/contact/functions_contact_link_repository.dart` (only if plan 2b created it), `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md`

**Interfaces:**
- Consumes: `firebase/firebase.json` ports, `firebase/functions/src/config.ts` `REGION` (Task 4); `FirebaseFirestore.useFirestoreEmulator(host, port, {sslEnabled, automaticHostMapping})`, `FirebaseAuth.useAuthEmulator(host, port, {automaticHostMapping})` (verified in the pub cache: cloud_firestore 6.10.0, firebase_auth 6.7.0), `FirebaseFunctions.instanceFor({app, region})`, `useFunctionsEmulator(host, port, {automaticHostMapping})` (cloud_functions 6.5.0), `FirebaseStorage.useStorageEmulator(host, port, {automaticHostMapping})` (firebase_storage 13.6.0).
- Produces:
  - `const functionsRegion = 'asia-southeast1'`.
  - `class EmulatorConfig { const EmulatorConfig(String host); final String host; int get authPort => 9099; int get firestorePort => 8080; int get functionsPort => 5001; int get storagePort => 9199; }`.
  - `EmulatorConfig? resolveEmulatorConfig({required bool debugBuild, required bool useEmulators, required String hostOverride, required TargetPlatform platform})` (throws `ArgumentError` for a host with scheme, port, path or spaces), `EmulatorConfig? emulatorConfigFromEnvironment()` (`kDebugMode`, `USE_EMULATORS`, `EMULATOR_HOST`, `defaultTargetPlatform`).
  - Android: debug-only `network_security_config.xml` (cleartext permitted) referenced from the debug manifest; release/profile unchanged. iOS: `NSAppTransportSecurity` → `NSAllowsLocalNetworking = true` (local network only; no arbitrary loads).

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/backend/backend_config_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/backend/backend_config.dart';

EmulatorConfig? _resolve({
  bool debug = true,
  bool use = true,
  String host = '',
  TargetPlatform platform = TargetPlatform.android,
}) => resolveEmulatorConfig(
  debugBuild: debug,
  useEmulators: use,
  hostOverride: host,
  platform: platform,
);

void main() {
  test('off unless a debug build asks for it', () {
    expect(_resolve(use: false), isNull);
    expect(_resolve(debug: false), isNull);
    expect(_resolve(debug: false, host: '192.168.1.20'), isNull);
  });

  test('default host: 10.0.2.2 on Android, 127.0.0.1 on the iOS Simulator', () {
    expect(_resolve()!.host, '10.0.2.2');
    expect(_resolve(platform: TargetPlatform.iOS)!.host, '127.0.0.1');
    expect(_resolve(platform: TargetPlatform.macOS)!.host, '127.0.0.1');
  });

  test('EMULATOR_HOST wins: Genymotion, real device, adb reverse', () {
    expect(_resolve(host: '10.0.3.2')!.host, '10.0.3.2');
    expect(_resolve(host: ' 192.168.1.20 ', platform: TargetPlatform.iOS)!.host, '192.168.1.20');
    expect(_resolve(host: 'my-mac.local')!.host, 'my-mac.local');
    expect(_resolve(host: '127.0.0.1')!.host, '127.0.0.1');
  });

  test('a host with a scheme, port, path or space is refused', () {
    for (final bad in ['http://10.0.2.2', '10.0.2.2:8080', '10.0.2.2/x', 'a b']) {
      expect(() => _resolve(host: bad), throwsArgumentError, reason: bad);
    }
  });

  test('ports match firebase/firebase.json', () {
    final config =
        jsonDecode(File('firebase/firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final emulators = config['emulators'] as Map<String, dynamic>;
    int port(String name) =>
        (emulators[name] as Map<String, dynamic>)['port'] as int;
    final c = _resolve()!;
    expect(c.authPort, port('auth'));
    expect(c.firestorePort, port('firestore'));
    expect(c.functionsPort, port('functions'));
    expect(c.storagePort, port('storage'));
  });

  test('the client calls the region the server deploys to', () {
    final server = File(
      'firebase/functions/src/config.ts',
    ).readAsStringSync();
    expect(server, contains("REGION = '$functionsRegion'"));
  });

  test('no adapter uses the default (us-central1) Functions instance', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => RegExp(
            r'FirebaseFunctions\.instance\b',
          ).hasMatch(f.readAsStringSync()),
        )
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
```

```dart
// test/emulator_platform_config_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug builds may use cleartext to reach the emulators; release may not', () {
    final debug = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      debug,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    final config = File(
      'android/app/src/debug/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(config, contains('cleartextTrafficPermitted="true"'));

    final main = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(main, isNot(contains('usesCleartextTraffic')));
    expect(main, isNot(contains('networkSecurityConfig')));
    expect(
      File('android/app/src/main/res/xml/network_security_config.xml')
          .existsSync(),
      isFalse,
    );
  });

  test('iOS allows plain HTTP to the local network only', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(
        r'<key>NSAppTransportSecurity</key>\s*<dict>\s*<key>NSAllowsLocalNetworking</key>\s*<true/>\s*</dict>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
  });

  test('the emulator plugins are dependencies', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('cloud_functions:'));
    expect(pubspec, contains('firebase_storage:'));
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/backend/backend_config_test.dart test/emulator_platform_config_test.dart`
Expected: FAIL: `backend_config.dart` not found; the platform tests fail on the missing `networkSecurityConfig`, `NSAllowsLocalNetworking` and dependencies. (If plan 2b is done, the "default instance" test would also flag `lib/data/contact/functions_contact_link_repository.dart`.)

- [ ] **Step 3: Implement**

```bash
flutter pub add cloud_functions firebase_storage
grep -nE "cloud_functions:|firebase_storage:" pubspec.yaml
```

(If plan 2b already added `cloud_functions`, `pub add` only refreshes its constraint.)

```dart
// lib/data/backend/backend_config.dart
import 'package:flutter/foundation.dart';

/// Region of every callable Cloud Function: Singapore, the closest region to
/// Vietnam. Same value as `REGION` in firebase/functions/src/config.ts.
const functionsRegion = 'asia-southeast1';

/// Where the local Firebase Emulator Suite listens (ports of
/// firebase/firebase.json).
class EmulatorConfig {
  const EmulatorConfig(this.host);

  final String host;

  int get authPort => 9099;
  int get firestorePort => 8080;
  int get functionsPort => 5001;
  int get storagePort => 9199;
}

final _host = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9.\-]*[A-Za-z0-9])?$');

/// The emulators are used only by debug builds started with
/// `--dart-define=USE_EMULATORS=true`; otherwise null (cloud backend).
/// Default host: `10.0.2.2` on Android (the emulator's alias for this Mac),
/// `127.0.0.1` elsewhere (iOS Simulator). `--dart-define=EMULATOR_HOST=…`
/// overrides it: `10.0.3.2` for Genymotion, the Mac's LAN IP for a real
/// device, `127.0.0.1` with `adb reverse`.
EmulatorConfig? resolveEmulatorConfig({
  required bool debugBuild,
  required bool useEmulators,
  required String hostOverride,
  required TargetPlatform platform,
}) {
  if (!debugBuild || !useEmulators) return null;
  final override = hostOverride.trim();
  if (override.isNotEmpty) {
    if (!_host.hasMatch(override)) {
      throw ArgumentError.value(
        override,
        'EMULATOR_HOST',
        'expected a host name or IPv4 address, without scheme, port or path',
      );
    }
    return EmulatorConfig(override);
  }
  return EmulatorConfig(
    platform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1',
  );
}

/// [resolveEmulatorConfig] for this build and device.
EmulatorConfig? emulatorConfigFromEnvironment() => resolveEmulatorConfig(
  debugBuild: kDebugMode,
  useEmulators: const bool.fromEnvironment('USE_EMULATORS'),
  hostOverride: const String.fromEnvironment('EMULATOR_HOST'),
  platform: defaultTargetPlatform,
);
```

Replace `lib/main.dart` with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/app/app.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (_, prefs) = await (
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ).wait;
  final emulators = emulatorConfigFromEnvironment();
  if (emulators != null) await _connectEmulators(emulators);
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const _Root(),
    ),
  );
}

/// Debug builds started with `--dart-define=USE_EMULATORS=true` talk to the
/// local Firebase Emulator Suite (scripts/backend-local.sh) instead of the
/// cloud project. Runs before any other Firebase call. The host is already
/// resolved for the device, so the SDKs' own localhost mapping is turned off.
Future<void> _connectEmulators(EmulatorConfig e) async {
  // No offline cache: it would mix cloud and emulator documents (same project id).
  final firestore = FirebaseFirestore.instance
    ..settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator(
    e.host,
    e.firestorePort,
    automaticHostMapping: false,
  );
  await FirebaseAuth.instance.useAuthEmulator(
    e.host,
    e.authPort,
    automaticHostMapping: false,
  );
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(
    e.host,
    e.functionsPort,
    automaticHostMapping: false,
  );
  await FirebaseStorage.instance.useStorageEmulator(
    e.host,
    e.storagePort,
    automaticHostMapping: false,
  );
  debugPrint('Firebase: using local emulators at ${e.host}');
}

class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final avatarUrl = ref.watch(currentProfileProvider).value?.avatarUrl;
    final useAvatar =
        ref.watch(buttonStyleProvider) == ButtonStyleMode.avatar &&
        avatarUrl != null;
    return MyApp(
      router: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      ctaAvatar: useAvatar ? NetworkImage(avatarUrl) : null,
    );
  }
}
```

(`settings` must be set before `useFirestoreEmulator`: the emulator call copies the current settings and only replaces the host.)

Replace `android/app/src/debug/AndroidManifest.xml` with:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- The INTERNET permission is required for development. Specifically,
         the Flutter tool needs it to communicate with the running application
         to allow setting breakpoints, to provide hot reload, etc.
    -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Debug builds only: plain HTTP to the local Firebase emulators (USE_EMULATORS).
         Release and profile builds keep Android's default (cleartext blocked). -->
    <application android:networkSecurityConfig="@xml/network_security_config"/>
</manifest>
```

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- android/app/src/debug/res/xml/network_security_config.xml
     Debug builds only. The Firebase emulators speak plain HTTP on the Android emulator (10.0.2.2),
     Genymotion (10.0.3.2), adb reverse (127.0.0.1) or the Mac's LAN IP for a real device, which is
     unknown at build time, hence a base config instead of per-domain entries. -->
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

In `ios/Runner/Info.plist`, insert after

```xml
	<key>LSRequiresIPhoneOS</key>
	<true/>
```

the lines

```xml
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
```

(Auth, Functions and Storage use URLSession and need this for `http://127.0.0.1` and LAN hosts; it allows local hosts only. On a real iPhone, iOS asks once for local-network access: allow it.)

Region and timeout for the callable client (plan 2b):
- If `lib/data/contact/functions_contact_link_repository.dart` exists, change its constructor initialiser from `: _functions = functions ?? FirebaseFunctions.instance;` to `: _functions = functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);`, add `import 'package:photobooking/data/backend/backend_config.dart';`, and change `.httpsCallable('getContactLink')` to `.httpsCallable('getContactLink', options: HttpsCallableOptions(timeout: const Duration(seconds: 10)))` (matches the server's `timeoutSeconds: 10`; if the analyzer asks for `const`, make the whole options object `const`).
- In every case, make the same two edits in the code block `// lib/data/contact/functions_contact_link_repository.dart` of `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md` (Task 4), so a later run of 2b produces the same code; the "default Functions instance" test catches it otherwise.

- [ ] **Step 4: Run and see it pass**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: analyze clean; all tests pass, including the 7 backend-config and 3 platform-config tests.

- [ ] **Step 5: Manual check (documented, no Flutter integration test)**

A Flutter `integration_test` against the emulators would need a running device plus the emulators in CI; not worth it in phase 1 (the server side is covered by Tasks 5–6). Check by hand and paste the results into the PR:

1. Terminal A (repo root, outside the sandbox): `scripts/backend-local.sh --fresh` → `All emulators ready`, `Seeded 4 users and 5 bookings …`.
2. Terminal B (`app_flutter/`), Android emulator: `flutter run --dart-define=USE_EMULATORS=true` → the log shows `Firebase: using local emulators at 10.0.2.2`.
3. Sign in with `lan.customer@seed.test` / `seed-password-1` → the customer home opens and the profile shows "Lan (seed)". Emulator UI → Authentication shows the sign-in; Firestore shows `users/seed-customer-lan`.
4. Change something that writes (Settings → switch role, or S42 edit name) and see the document change in the Emulator UI → writes go to the emulators, not the cloud project.
5. Genymotion: restart the backend with `--lan`; `flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2`; repeat step 3.
6. Real Android device: either `--lan` and `EMULATOR_HOST=$(ipconfig getifaddr en0)`, or the four `adb reverse` lines from the README and `EMULATOR_HOST=127.0.0.1`; repeat step 3.
7. iOS Simulator (only after the iOS enablement plan): `flutter run -d <simulator> --dart-define=USE_EMULATORS=true`; repeat step 3.
8. `flutter run` without the define: no emulator log line; the app uses the cloud project. `flutter run --release --dart-define=USE_EMULATORS=true`: also no emulator line (debug only).
9. `getContactLink` from the app needs S32 (plan 2b + the booking plan); until then: `GCLOUD_PROJECT=<project> npm run try:contact -- lan.customer@seed.test seed-booking-accepted zalo` from `app_flutter/firebase/functions` → `200 {"result":{"url":"https://zalo.me/84912000002"}}`.

- [ ] **Step 6: Commit**

```bash
git add lib/data/backend lib/main.dart pubspec.yaml pubspec.lock android/app/src/debug ios/Runner/Info.plist test/data/backend test/emulator_platform_config_test.dart ../docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md
git add lib/data/contact 2>/dev/null || true
git commit -m "feat(app): debug builds connect to the local Firebase emulators on Android, Genymotion, iOS and devices

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-backend-phase1-firebase-local.md"). Nothing to do here.

---

### Task 10: Pure skills rules and the `scorePhotographerSkills` use case (`packages/domain`)

**Files:**
- Create: `packages/domain/src/skills.ts`, `packages/domain/src/score_skills.ts`, `packages/domain/test/skills.test.ts`, `packages/domain/test/score_skills.test.ts`, `packages/domain/test/fixtures/skills_completeness.json`
- Modify: `packages/domain/src/index.ts`

**Interfaces:**
- Consumes: Task 1 (`isId`, the purity lint and test); the Dart reading rules of `app_flutter/lib/data/skills/photographer_skills.dart` (`skillsFromMap`: non-map → nothing, malformed entries dropped, duplicate genre ids once, level outside 1..3 → 2, non-int years → null, string lists deduplicated, non-strings dropped) and the score cases of `app_flutter/test/data/skills/skills_completeness_test.dart` (ported into the JSON table; Task 13 deletes the Dart file); spec 3e.2 weights.
- Produces (all exported from `@photobooking/domain`):
  - `SKILLS_SCHEMA_VERSION = 1`, `SERVER_SKILL_FIELDS = ['completeness', 'completenessNext', 'updatedAt', 'evidenceRemovedAt'] as const`.
  - `type SkillLevel = 1 | 2 | 3`; `interface SpecialtySkill { id: string; level: SkillLevel; years: number | null; evidencePostIds: readonly string[] }`; `interface Skills { specialties: readonly SpecialtySkill[]; styles, extras, languages, audiences: readonly string[]; yearsExperience: number | null }` (all `readonly`).
  - `parseSkills(raw: unknown): Skills | null` (null = malformed: not a map, or `schemaVersion !== 1`).
  - `MAX_EVIDENCE_READS = 18`; `evidenceIds(skills: Skills): string[]`; `interface EvidencePostRecord { authorId?: unknown; photographerId?: unknown; deletedAt?: unknown }`; `isOwnEvidencePost(uid: string, post: EvidencePostRecord | undefined): boolean`; `cleanEvidence(skills: Skills, ownedIds: ReadonlySet<string>): { skills: Skills; removed: boolean }`.
  - `COMPLETENESS_STEPS` (`'specialties','levels','evidence','styles','languages','audiences','extras'`), `type CompletenessStep`, `COMPLETENESS_POINTS: Readonly<Record<CompletenessStep, number>>`, `interface Completeness { percent: number; next: CompletenessStep | null }`, `skillsCompleteness(skills: Skills): Completeness`.
  - `sameClientSkills(before: unknown, after: unknown): boolean` (equal after dropping `SERVER_SKILL_FIELDS`; key order ignored).
  - `interface StoredSpecialty { id: string; level: SkillLevel; years?: number; evidencePostIds: readonly string[] }`, `toStoredSpecialties(specialties: readonly SpecialtySkill[]): StoredSpecialty[]` (the app's `skillsToMap` shape).
  - Ports and use case: `interface SkillsWriteEvent { uid: string; before: unknown; after: unknown; deleted: boolean }` (`before`/`after` = the raw `skills` values), `interface OwnedPostsReader { owned(uid: string, postIds: readonly string[]): Promise<ReadonlySet<string>> }`, `interface SkillsScoreUpdate { completeness: number; completenessNext: CompletenessStep | null; specialties: readonly StoredSpecialty[] | null }` (`specialties` non-null only when evidence was removed), `interface SkillsScoreWriter { write(update: SkillsScoreUpdate): Promise<'written' | 'stale'> }`, `interface ScoreSkillsDeps { posts: OwnedPostsReader; writer: SkillsScoreWriter }`, `type ScoreSkillsOutcome = 'deleted' | 'no_skills' | 'unchanged' | 'malformed' | 'up_to_date' | 'written' | 'stale'`, `type SkillsScorePlan`, `planSkillsScore(e: SkillsWriteEvent): SkillsScorePlan`, `scorePhotographerSkills(e: SkillsWriteEvent, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome>`.

- [ ] **Step 1: Write the shared score table**

```json
// packages/domain/test/fixtures/skills_completeness.json
{
  "about": "Profile score cases (spec 3e.2). Ported from app_flutter/test/data/skills/skills_completeness_test.dart, which Task 13 deletes. Skills are stored maps as the app writes them.",
  "cases": [
    { "name": "nothing chosen: 0, first step is choosing a genre", "skills": { "schemaVersion": 1 }, "percent": 0, "next": "specialties" },
    { "name": "a new photographer with Vietnamese ticked starts at 10", "skills": { "schemaVersion": 1, "languages": ["vi"] }, "percent": 10, "next": "specialties" },
    { "name": "one genre at Thành thạo earns genre, level and evidence points", "skills": { "schemaVersion": 1, "specialties": [{ "id": "portrait", "level": 2, "evidencePostIds": [] }], "languages": ["vi"] }, "percent": 75, "next": "styles" },
    { "name": "a Chuyên sâu genre without evidence: evidence is next", "skills": { "schemaVersion": 1, "specialties": [{ "id": "couple", "level": 2, "evidencePostIds": [] }, { "id": "portrait", "level": 3, "evidencePostIds": [] }], "styles": ["film"], "extras": ["retouch"], "languages": ["vi", "en"], "audiences": ["couple"] }, "percent": 80, "next": "evidence" },
    { "name": "a complete profile is 100 with no next step", "skills": { "schemaVersion": 1, "specialties": [{ "id": "portrait", "level": 3, "evidencePostIds": ["a"] }], "styles": ["film"], "extras": ["retouch"], "languages": ["vi"], "audiences": ["couple"] }, "percent": 100, "next": null },
    { "name": "a level outside 1..3 counts as Thành thạo", "skills": { "schemaVersion": 1, "specialties": [{ "id": "portrait", "level": 7 }], "styles": ["film"], "languages": ["vi"] }, "percent": 85, "next": "audiences" },
    { "name": "tags without a genre", "skills": { "schemaVersion": 1, "styles": ["film"], "extras": ["retouch"], "languages": ["vi"], "audiences": ["couple"] }, "percent": 35, "next": "specialties" },
    { "name": "a duplicate genre counts once, the first entry wins", "skills": { "schemaVersion": 1, "specialties": [{ "id": "portrait", "level": 3, "evidencePostIds": ["a"] }, { "id": "portrait", "level": 1, "evidencePostIds": [] }], "languages": ["vi", "vi"] }, "percent": 75, "next": "styles" },
    { "name": "only extras missing", "skills": { "schemaVersion": 1, "specialties": [{ "id": "portrait", "level": 1, "evidencePostIds": [] }], "styles": ["film"], "languages": ["vi"], "audiences": ["couple"] }, "percent": 95, "next": "extras" }
  ]
}
```

(Write the file without the first `// packages/...` line.)

- [ ] **Step 2: Write the failing tests**

```ts
// packages/domain/test/skills.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  COMPLETENESS_POINTS,
  COMPLETENESS_STEPS,
  MAX_EVIDENCE_READS,
  cleanEvidence,
  evidenceIds,
  isOwnEvidencePost,
  parseSkills,
  sameClientSkills,
  skillsCompleteness,
  toStoredSpecialties,
  type SkillLevel,
  type Skills,
  type SpecialtySkill,
} from '../src/index.js';

const genre = (id: string, level: SkillLevel = 2, evidencePostIds: string[] = [], years: number | null = null): SpecialtySkill =>
  ({ id, level, years, evidencePostIds });
const skills = (over: Partial<Skills> = {}): Skills =>
  ({ specialties: [], styles: [], extras: [], languages: [], audiences: [], yearsExperience: null, ...over });

describe('parseSkills', () => {
  test("reads the stored shape (the app's skillsToMap) and ignores server fields", () => {
    assert.deepEqual(
      parseSkills({
        schemaVersion: 1,
        specialties: [
          { id: 'portrait', level: 3, years: 6, evidencePostIds: ['p1', 'p2'] },
          { id: 'couple', level: 1, evidencePostIds: [] },
        ],
        styles: ['film'],
        extras: ['retouch'],
        languages: ['vi', 'en'],
        audiences: ['couple'],
        yearsExperience: 6,
        completeness: 72,
        completenessNext: 'audiences',
      }),
      skills({
        specialties: [genre('portrait', 3, ['p1', 'p2'], 6), genre('couple', 1)],
        styles: ['film'],
        extras: ['retouch'],
        languages: ['vi', 'en'],
        audiences: ['couple'],
        yearsExperience: 6,
      }),
    );
  });

  test('anything but a schema-1 map is malformed', () => {
    for (const raw of [undefined, null, 'portrait', 5, [], ['portrait'], {}, { schemaVersion: 2 }, { schemaVersion: '1' }]) {
      assert.equal(parseSkills(raw), null, JSON.stringify(raw) ?? 'undefined');
    }
  });

  test('tolerant like skillsFromMap: bad entries dropped, bad level is 2, duplicates once', () => {
    assert.deepEqual(
      parseSkills({
        schemaVersion: 1,
        specialties: [
          'portrait',
          null,
          { level: 3 },
          { id: 7 },
          { id: 'wedding', level: 9, years: 'six', evidencePostIds: ['a', 5, 'a', 'b'] },
          { id: 'wedding', level: 3, evidencePostIds: ['z'] },
          { id: 'family', level: '3' },
        ],
        styles: 'film',
        extras: ['retouch', 'retouch', 1],
        languages: ['vi'],
        yearsExperience: 6.5,
      }),
      skills({ specialties: [genre('wedding', 2, ['a', 'b']), genre('family', 2)], extras: ['retouch'], languages: ['vi'] }),
    );
  });
});

describe('evidence', () => {
  test('evidenceIds: every opaque id once, at most 18; other ids are never read', () => {
    assert.deepEqual(
      evidenceIds(skills({ specialties: [genre('portrait', 3, ['a', 'b', 'a/b']), genre('couple', 2, ['b', 'c', ''])] })),
      ['a', 'b', 'c'],
    );
    const many = Array.from({ length: 7 }, (_, i) => genre(`g${i}`, 2, [`x${i}a`, `x${i}b`, `x${i}c`]));
    assert.equal(MAX_EVIDENCE_READS, 18);
    assert.equal(evidenceIds(skills({ specialties: many })).length, MAX_EVIDENCE_READS);
  });

  test('isOwnEvidencePost: a live post of this photographer only', () => {
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u1', photographerId: 'u1' }), true);
    assert.equal(isOwnEvidencePost('u1', { photographerId: 'u1' }), true, 'older posts without authorId');
    assert.equal(isOwnEvidencePost('u1', { authorId: 'c9', photographerId: 'u1' }), false, "a customer's real-shoot post");
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u2', photographerId: 'u2' }), false);
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u1', deletedAt: new Date() }), false, 'soft-deleted');
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u1', deletedAt: null }), true);
    assert.equal(isOwnEvidencePost('u1', undefined), false, 'missing document');
  });

  test('cleanEvidence removes posts of other photographers and posts that are gone', () => {
    const s = skills({
      specialties: [genre('couple', 2, ['own1', 'other', 'gone']), genre('family', 1, ['own2'])],
      languages: ['vi'],
    });
    assert.deepEqual(cleanEvidence(s, new Set(['own1', 'own2'])), {
      skills: skills({ specialties: [genre('couple', 2, ['own1']), genre('family', 1, ['own2'])], languages: ['vi'] }),
      removed: true,
    });
  });

  test('a Chuyên sâu genre left without evidence drops to Thành thạo; one post left keeps it', () => {
    const s = skills({ specialties: [genre('portrait', 3, ['other']), genre('wedding', 3, ['own', 'gone'])] });
    assert.deepEqual(cleanEvidence(s, new Set(['own'])).skills.specialties, [genre('portrait', 2, []), genre('wedding', 3, ['own'])]);
  });

  test('nothing to remove: the same skills object and removed false', () => {
    const s = skills({ specialties: [genre('portrait', 3, ['a'])] });
    const result = cleanEvidence(s, new Set(['a', 'unrelated']));
    assert.equal(result.removed, false);
    assert.equal(result.skills, s);
  });
});

describe('skillsCompleteness', () => {
  test('weights of spec 3e.2, highest first, 100 in total', () => {
    assert.deepEqual([...COMPLETENESS_STEPS], ['specialties', 'levels', 'evidence', 'styles', 'languages', 'audiences', 'extras']);
    assert.deepEqual(COMPLETENESS_STEPS.map((s) => COMPLETENESS_POINTS[s]), [25, 20, 20, 10, 10, 10, 5]);
  });

  const table = JSON.parse(readFileSync(new URL('./fixtures/skills_completeness.json', import.meta.url), 'utf8')) as {
    cases: { name: string; skills: unknown; percent: number; next: string | null }[];
  };
  for (const c of table.cases) {
    test(c.name, () => {
      const s = parseSkills(c.skills);
      assert.ok(s !== null, 'fixture skills must parse');
      assert.deepEqual(skillsCompleteness(s), { percent: c.percent, next: c.next });
    });
  }
});

describe('sameClientSkills', () => {
  const base = { schemaVersion: 1, specialties: [{ id: 'portrait', level: 2, evidencePostIds: ['a'] }], languages: ['vi'] };

  test("server fields are ignored (the Function's own write)", () => {
    const after = { ...base, completeness: 75, completenessNext: 'styles', updatedAt: new Date(), evidenceRemovedAt: new Date() };
    assert.equal(sameClientSkills(base, after), true);
  });

  test('key order does not matter; any client change does', () => {
    assert.equal(
      sameClientSkills(base, { languages: ['vi'], specialties: [{ evidencePostIds: ['a'], level: 2, id: 'portrait' }], schemaVersion: 1 }),
      true,
    );
    assert.equal(sameClientSkills(base, { ...base, languages: ['vi', 'en'] }), false);
    assert.equal(sameClientSkills(base, { ...base, specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }] }), false);
    assert.equal(sameClientSkills(base, { ...base, styles: [] }), false);
  });

  test('no skills before is never the same as skills after', () => {
    assert.equal(sameClientSkills(undefined, base), false);
    assert.equal(sameClientSkills(undefined, undefined), true);
  });
});

test("toStoredSpecialties writes the app's shape: years only when known", () => {
  assert.deepEqual(toStoredSpecialties([genre('portrait', 3, ['a'], 6), genre('couple')]), [
    { id: 'portrait', level: 3, years: 6, evidencePostIds: ['a'] },
    { id: 'couple', level: 2, evidencePostIds: [] },
  ]);
});
```

```ts
// packages/domain/test/score_skills.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  isOwnEvidencePost,
  scorePhotographerSkills,
  type EvidencePostRecord,
  type ScoreSkillsDeps,
  type SkillsScoreUpdate,
  type SkillsWriteEvent,
} from '../src/index.js';

const P = 'p1';

function fakes(posts: Record<string, EvidencePostRecord> = {}, writeResult: 'written' | 'stale' = 'written') {
  const reads: string[][] = [];
  const writes: SkillsScoreUpdate[] = [];
  const deps: ScoreSkillsDeps = {
    posts: {
      async owned(uid, ids) {
        reads.push([...ids]);
        return new Set(ids.filter((id) => isOwnEvidencePost(uid, posts[id])));
      },
    },
    writer: {
      async write(update) {
        writes.push(update);
        return writeResult;
      },
    },
  };
  return { deps, reads, writes };
}

const ev = (before: unknown, after: unknown, deleted = false): SkillsWriteEvent => ({ uid: P, before, after, deleted });
const saved = (over: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }],
  languages: ['vi'],
  ...over,
});

describe('scorePhotographerSkills', () => {
  test('a deleted profile is skipped without reading or writing', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(saved(), undefined, true), f.deps), 'deleted');
    assert.deepEqual([f.reads, f.writes], [[], []]);
  });

  test('a profile without skills is skipped', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, undefined), f.deps), 'no_skills');
    assert.deepEqual(f.writes, []);
  });

  test("a change of server fields only (the Function's own write) stops before any read", async () => {
    const f = fakes({ own: { authorId: P } });
    const before = saved({ specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own'] }] });
    const after = { ...before, completeness: 100, completenessNext: null, updatedAt: new Date() };
    assert.equal(await scorePhotographerSkills(ev(before, after), f.deps), 'unchanged');
    assert.deepEqual([f.reads, f.writes], [[], []]);
  });

  test('a malformed skills value is not scored and nothing is written', async () => {
    for (const after of ['portrait', [], { specialties: [] }, { schemaVersion: 2 }]) {
      const f = fakes();
      assert.equal(await scorePhotographerSkills(ev(undefined, after), f.deps), 'malformed', JSON.stringify(after));
      assert.deepEqual(f.writes, []);
    }
  });

  test('evidence of another photographer, of a deleted post or with a bad id is removed; Chuyên sâu drops', async () => {
    const f = fakes({
      own: { authorId: P, photographerId: P },
      theirs: { authorId: 'p2', photographerId: 'p2' },
      trashed: { authorId: P, deletedAt: new Date() },
    });
    const after = saved({
      specialties: [
        { id: 'portrait', level: 3, evidencePostIds: ['theirs', 'trashed', 'a/b'] },
        { id: 'couple', level: 2, years: 4, evidencePostIds: ['own', 'missing'] },
      ],
      styles: ['film'],
    });
    assert.equal(await scorePhotographerSkills(ev(undefined, after), f.deps), 'written');
    assert.deepEqual(f.reads, [['theirs', 'trashed', 'own', 'missing']], 'one read, bad id never read');
    assert.deepEqual(f.writes, [
      {
        completeness: 85,
        completenessNext: 'audiences',
        specialties: [
          { id: 'portrait', level: 2, evidencePostIds: [] },
          { id: 'couple', level: 2, years: 4, evidencePostIds: ['own'] },
        ],
      },
    ]);
  });

  test('no evidence: no read; score and next step written, specialties left alone', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), f.deps), 'written');
    assert.deepEqual(f.reads, []);
    assert.deepEqual(f.writes, [{ completeness: 75, completenessNext: 'styles', specialties: null }]);
  });

  test('the re-run after the Function removed evidence finds the score current and writes nothing', async () => {
    const f = fakes({ own: { authorId: P } });
    const before = saved({ specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own', 'theirs'] }] });
    const after = saved({
      specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own'] }],
      completeness: 75,
      completenessNext: 'styles',
      updatedAt: new Date(),
      evidenceRemovedAt: new Date(),
    });
    assert.equal(await scorePhotographerSkills(ev(before, after), f.deps), 'up_to_date');
    assert.deepEqual(f.writes, []);
  });

  test('a photographer with no genre yet scores 10 and is told to choose one', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, { schemaVersion: 1, specialties: [], languages: ['vi'] }), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 10, completenessNext: 'specialties', specialties: null }]);
  });

  test('a stored score without completenessNext (an older run) is written again', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, saved({ completeness: 75 })), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 75, completenessNext: 'styles', specialties: null }]);
  });

  test('a user save during the run makes the write stale; the next trigger scores it', async () => {
    const f = fakes({}, 'stale');
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), f.deps), 'stale');
    assert.equal(f.writes.length, 1);
  });

  test('a failed post read rejects (so Functions retries) and writes nothing', async () => {
    const writes: SkillsScoreUpdate[] = [];
    const deps: ScoreSkillsDeps = {
      posts: { owned: () => Promise.reject(new Error('unavailable')) },
      writer: {
        async write(update) {
          writes.push(update);
          return 'written';
        },
      },
    };
    const after = saved({ specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['a'] }] });
    await assert.rejects(scorePhotographerSkills(ev(undefined, after), deps), /unavailable/);
    assert.deepEqual(writes, []);
  });
});
```

- [ ] **Step 3: Run and see it fail**

Run (from `packages/domain`): `npm test`
Expected: FAIL. `skills.test.ts` and `score_skills.test.ts` stop with `SyntaxError: The requested module '../src/index.js' does not provide an export named …`; the other files still pass (`ℹ pass 53`).

- [ ] **Step 4: Implement the pure rules**

```ts
// packages/domain/src/skills.ts
// Photographer skills (spec 3e.2–3e.3): the reading rules of the app's skillsFromMap
// (app_flutter/lib/data/skills/photographer_skills.dart), the evidence check and the
// "Độ khớp hồ sơ" score. Pure: the Function onPhotographerWrite wires it to Firestore.
import { isId } from './ids.js';

export const SKILLS_SCHEMA_VERSION = 1;

/** Fields of `photographers/{uid}.skills` written only by the server (Admin SDK). */
export const SERVER_SKILL_FIELDS = ['completeness', 'completenessNext', 'updatedAt', 'evidenceRemovedAt'] as const;

/** 1 Cơ bản, 2 Thành thạo, 3 Chuyên sâu. */
export type SkillLevel = 1 | 2 | 3;

export interface SpecialtySkill {
  readonly id: string;
  readonly level: SkillLevel;
  readonly years: number | null;
  readonly evidencePostIds: readonly string[];
}

/** The client-owned part of `photographers/{uid}.skills`. */
export interface Skills {
  readonly specialties: readonly SpecialtySkill[];
  readonly styles: readonly string[];
  readonly extras: readonly string[];
  readonly languages: readonly string[];
  readonly audiences: readonly string[];
  readonly yearsExperience: number | null;
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

const integer = (v: unknown): number | null => (typeof v === 'number' && Number.isInteger(v) ? v : null);

/** Strings only, each once, in their first order (Dart `_strings`). */
function strings(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return [...new Set(v.filter((x): x is string => typeof x === 'string'))];
}

/**
 * The stored skills map → Skills, or null when it is not a schema-1 map (malformed: the
 * Function logs it and writes nothing). Inside a schema-1 map it is as tolerant as the app:
 * malformed genres are dropped, a duplicate genre id counts once (first wins), a level outside
 * 1..3 reads as 2, non-integer years read as null.
 */
export function parseSkills(raw: unknown): Skills | null {
  if (!isRecord(raw) || raw.schemaVersion !== SKILLS_SCHEMA_VERSION) return null;
  const specialties: SpecialtySkill[] = [];
  const seen = new Set<string>();
  const list: unknown = raw.specialties;
  if (Array.isArray(list)) {
    for (const e of list) {
      if (!isRecord(e)) continue;
      const id = e.id;
      if (typeof id !== 'string' || seen.has(id)) continue;
      seen.add(id);
      const lv = e.level;
      specialties.push({
        id,
        level: lv === 1 || lv === 3 ? lv : 2,
        years: integer(e.years),
        evidencePostIds: strings(e.evidencePostIds),
      });
    }
  }
  return {
    specialties,
    styles: strings(raw.styles),
    extras: strings(raw.extras),
    languages: strings(raw.languages),
    audiences: strings(raw.audiences),
    yearsExperience: integer(raw.yearsExperience),
  };
}

/** 6 genres × 3 posts: the most one run reads (spec 3e.2). */
export const MAX_EVIDENCE_READS = 18;

/**
 * Post ids to look up, each once, at most 18. Ids that are not opaque ids are left out: they
 * cannot be a post (and `doc('a/b')` would throw), so cleanEvidence removes them.
 */
export function evidenceIds(skills: Skills): string[] {
  const ids = new Set(skills.specialties.flatMap((s) => s.evidencePostIds).filter(isId));
  return [...ids].slice(0, MAX_EVIDENCE_READS);
}

/** The fields of a `posts/{id}` document the evidence check reads. */
export interface EvidencePostRecord {
  readonly authorId?: unknown;
  readonly photographerId?: unknown;
  readonly deletedAt?: unknown;
}

/**
 * Evidence must be the photographer's own live post: the document exists, has no `deletedAt`,
 * and its owner (`authorId`, else `photographerId`, like the app's postFromFirestore) is `uid`.
 * A customer's real-shoot post about the photographer (`authorId` = the customer) does not count.
 */
export function isOwnEvidencePost(uid: string, post: EvidencePostRecord | undefined): boolean {
  if (post === undefined || (post.deletedAt !== undefined && post.deletedAt !== null)) return false;
  const owner = typeof post.authorId === 'string' ? post.authorId : post.photographerId;
  return owner === uid;
}

/** Keeps only owned evidence; a level-3 genre left with none becomes level 2. */
export function cleanEvidence(skills: Skills, ownedIds: ReadonlySet<string>): { skills: Skills; removed: boolean } {
  let removed = false;
  const specialties = skills.specialties.map((sp): SpecialtySkill => {
    const kept = sp.evidencePostIds.filter((id) => ownedIds.has(id));
    if (kept.length === sp.evidencePostIds.length) return sp;
    removed = true;
    return { ...sp, level: sp.level === 3 && kept.length === 0 ? 2 : sp.level, evidencePostIds: kept };
  });
  return removed ? { skills: { ...skills, specialties }, removed } : { skills, removed };
}

/** Score parts of spec 3e.2, highest weight first; `next` is the first one missing. */
export const COMPLETENESS_STEPS = ['specialties', 'levels', 'evidence', 'styles', 'languages', 'audiences', 'extras'] as const;

export type CompletenessStep = (typeof COMPLETENESS_STEPS)[number];

export const COMPLETENESS_POINTS: Readonly<Record<CompletenessStep, number>> = {
  specialties: 25,
  levels: 20,
  evidence: 20,
  styles: 10,
  languages: 10,
  audiences: 10,
  extras: 5,
};

export interface Completeness {
  /** 0..100; shown only to the photographer. */
  readonly percent: number;
  /** First missing step, or null at 100. */
  readonly next: CompletenessStep | null;
}

function done(s: Skills, step: CompletenessStep): boolean {
  const any = s.specialties.length > 0;
  switch (step) {
    case 'specialties':
      return any;
    case 'levels':
      return any && s.specialties.every((x) => x.level >= 1 && x.level <= 3);
    case 'evidence':
      return any && s.specialties.every((x) => x.level !== 3 || x.evidencePostIds.length > 0);
    case 'styles':
      return s.styles.length > 0;
    case 'languages':
      return s.languages.length > 0;
    case 'audiences':
      return s.audiences.length > 0;
    case 'extras':
      return s.extras.length > 0;
  }
}

/** "Độ khớp hồ sơ" (spec 3e.2) and the first missing step. */
export function skillsCompleteness(s: Skills): Completeness {
  let percent = 0;
  let next: CompletenessStep | null = null;
  for (const step of COMPLETENESS_STEPS) {
    if (done(s, step)) percent += COMPLETENESS_POINTS[step];
    else next ??= step;
  }
  return { percent, next };
}

const SERVER_FIELDS = new Set<string>(SERVER_SKILL_FIELDS);

function clientPart(v: unknown): unknown {
  if (!isRecord(v)) return v;
  return Object.fromEntries(Object.entries(v).filter(([k]) => !SERVER_FIELDS.has(k)));
}

function deepEqual(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true;
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => deepEqual(x, b[i]));
  }
  if (!isRecord(a) || !isRecord(b)) return false;
  const keys = Object.keys(a);
  return keys.length === Object.keys(b).length && keys.every((k) => Object.hasOwn(b, k) && deepEqual(a[k], b[k]));
}

/**
 * The loop guard: true when the two raw skills values differ only in server fields, so the
 * write that fired the trigger was the Function's own (or an identical save) and needs no work.
 */
export function sameClientSkills(before: unknown, after: unknown): boolean {
  return deepEqual(clientPart(before), clientPart(after));
}

/** A genre as the app stores it (`skillsToMap`): `years` only when known. */
export interface StoredSpecialty {
  readonly id: string;
  readonly level: SkillLevel;
  readonly years?: number;
  readonly evidencePostIds: readonly string[];
}

export function toStoredSpecialties(specialties: readonly SpecialtySkill[]): StoredSpecialty[] {
  return specialties.map((s) => ({
    id: s.id,
    level: s.level,
    ...(s.years === null ? {} : { years: s.years }),
    evidencePostIds: [...s.evidencePostIds],
  }));
}
```

- [ ] **Step 5: Implement the use case over ports**

```ts
// packages/domain/src/score_skills.ts
// Use case behind the Firestore trigger onPhotographerWrite (spec 2026-10-02 §2): skip what needs
// no work, check the evidence with one read, score, write once. Firestore lives in the adapters.
import {
  cleanEvidence,
  evidenceIds,
  parseSkills,
  sameClientSkills,
  skillsCompleteness,
  toStoredSpecialties,
  type CompletenessStep,
  type Skills,
  type StoredSpecialty,
} from './skills.js';

/** One write of `photographers/{uid}`: the raw `skills` values before and after. */
export interface SkillsWriteEvent {
  readonly uid: string;
  readonly before: unknown;
  readonly after: unknown;
  /** The document itself was deleted. */
  readonly deleted: boolean;
}

/** Which of `postIds` are the photographer's own live posts (one batched read). */
export interface OwnedPostsReader {
  owned(uid: string, postIds: readonly string[]): Promise<ReadonlySet<string>>;
}

export interface SkillsScoreUpdate {
  readonly completeness: number;
  readonly completenessNext: CompletenessStep | null;
  /** The cleaned genres when evidence was removed (then `evidenceRemovedAt` is set too); else null. */
  readonly specialties: readonly StoredSpecialty[] | null;
}

/**
 * Writes the server fields only if the document is still the one the trigger saw; `stale` when
 * it changed (a newer save, whose own trigger scores it) or was deleted. Other failures throw.
 */
export interface SkillsScoreWriter {
  write(update: SkillsScoreUpdate): Promise<'written' | 'stale'>;
}

export interface ScoreSkillsDeps {
  readonly posts: OwnedPostsReader;
  readonly writer: SkillsScoreWriter;
}

export type ScoreSkillsOutcome = 'deleted' | 'no_skills' | 'unchanged' | 'malformed' | 'up_to_date' | 'written' | 'stale';

export type SkillsScorePlan =
  | { readonly kind: 'skip'; readonly reason: 'deleted' | 'no_skills' | 'unchanged' | 'malformed' }
  | { readonly kind: 'score'; readonly skills: Skills };

/** What a write needs, decided without any read. `unchanged` is the re-entry guard. */
export function planSkillsScore(e: SkillsWriteEvent): SkillsScorePlan {
  if (e.deleted) return { kind: 'skip', reason: 'deleted' };
  if (e.after === undefined) return { kind: 'skip', reason: 'no_skills' };
  if (sameClientSkills(e.before, e.after)) return { kind: 'skip', reason: 'unchanged' };
  const skills = parseSkills(e.after);
  return skills === null ? { kind: 'skip', reason: 'malformed' } : { kind: 'score', skills };
}

const storedField = (raw: unknown, key: string): unknown =>
  typeof raw === 'object' && raw !== null && !Array.isArray(raw) ? (raw as Record<string, unknown>)[key] : undefined;

/**
 * Scores `photographers/{uid}.skills` and removes evidence that is not the photographer's own.
 * Idempotent: a re-run finds the score current (`up_to_date`) and writes nothing. Read and write
 * failures propagate so Cloud Functions retries the event.
 */
export async function scorePhotographerSkills(e: SkillsWriteEvent, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const plan = planSkillsScore(e);
  if (plan.kind === 'skip') return plan.reason;
  const ids = evidenceIds(plan.skills);
  const owned = ids.length === 0 ? new Set<string>() : await deps.posts.owned(e.uid, ids);
  const { skills, removed } = cleanEvidence(plan.skills, owned);
  const { percent, next } = skillsCompleteness(skills);
  if (!removed && storedField(e.after, 'completeness') === percent && storedField(e.after, 'completenessNext') === next) {
    return 'up_to_date';
  }
  return deps.writer.write({
    completeness: percent,
    completenessNext: next,
    specialties: removed ? toStoredSpecialties(skills.specialties) : null,
  });
}
```

Append to `packages/domain/src/index.ts`:

```ts
export * from './skills.js';
export * from './score_skills.js';
```

- [ ] **Step 6: Run and see it pass**

Run (from `packages/domain`): `npm run typecheck && npm run lint && npm test`
Expected: typecheck and lint clean (the purity lint and `purity.test.ts` accept `src/skills.ts` and `src/score_skills.ts`: relative imports only); `ℹ tests 86`, `ℹ pass 86`, `ℹ fail 0` (53 before + 22 in `skills.test.ts` + 11 in `score_skills.test.ts`).

- [ ] **Step 7: Commit**

```bash
git add packages/domain
git commit -m "feat(domain): skills parsing, evidence check, profile score and the scorePhotographerSkills use case

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Firestore trigger `onPhotographerWrite` (adapters, wiring, emulator test)

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/skills_firestore.ts`, `src/infra/live_skills.ts`, `src/triggers/photographer_write.ts`, `test/unit/photographer_write.test.ts`, `test/integration/photographer_write.test.ts`
- Modify: `app_flutter/firebase/functions/src/config.ts`, `app_flutter/firebase/functions/src/index.ts`

**Interfaces:**
- Consumes: Task 10 (`scorePhotographerSkills`, `isOwnEvidencePost`, `ScoreSkillsDeps`, `OwnedPostsReader`, `SkillsScoreWriter`, `SkillsScoreUpdate`, `ScoreSkillsOutcome`); Task 4 (`REGION`, `db()`, build, npm scripts `test` and `test:integration`, the `--only auth,firestore,functions` emulator run); Task 5 (`emulatorProject`, `resetEmulators`); Task 6 (`src/index.ts` exporting `getContactLink`, `liveContactDeps`).
- Produces:
  - `TRIGGER_OPTIONS = { region: REGION, memory: '256MiB', timeoutSeconds: 30, maxInstances: 10, minInstances: 0, retry: true }` in `src/config.ts`.
  - `POSTS = 'posts'`, `firestoreOwnedPostsReader(db: Firestore): OwnedPostsReader` (one `db.getAll`), `skillsUpdateFields(update: SkillsScoreUpdate): DocumentData`, `isStaleWriteError(e: unknown): boolean` (gRPC 9 FAILED_PRECONDITION, 5 NOT_FOUND), `firestoreSkillsScoreWriter(db: Firestore, uid: string, lastUpdateTime: Timestamp | undefined): SkillsScoreWriter`.
  - `liveSkillsDeps(uid: string, lastUpdateTime: Timestamp | undefined): ScoreSkillsDeps`.
  - `interface PhotographerWriteInput { uid: string; before: DocumentData | undefined; after: DocumentData | undefined }`, `handlePhotographerWrite(input, deps): Promise<ScoreSkillsOutcome>` (logs `warn` for `malformed`, `info` for `written`/`stale`).
  - Deployed function `onPhotographerWrite` (Firestore v2 `onDocumentWritten('photographers/{uid}')`, `asia-southeast1`).

- [ ] **Step 1: Write the failing tests**

```ts
// app_flutter/firebase/functions/test/unit/photographer_write.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { ScoreSkillsDeps, SkillsScoreUpdate } from '@photobooking/domain';
import { REGION, TRIGGER_OPTIONS } from '../../src/config.js';
import { firestoreSkillsScoreWriter, isStaleWriteError, skillsUpdateFields } from '../../src/infra/skills_firestore.js';
import { handlePhotographerWrite } from '../../src/triggers/photographer_write.js';

const serverTime = (v: unknown) => v instanceof FieldValue && v.isEqual(FieldValue.serverTimestamp());

describe('onPhotographerWrite plumbing', () => {
  test('trigger options: Singapore, small, bounded, retried', () => {
    assert.deepEqual(TRIGGER_OPTIONS, {
      region: REGION,
      memory: '256MiB',
      timeoutSeconds: 30,
      maxInstances: 10,
      minInstances: 0,
      retry: true,
    });
  });

  test('update fields: score with server time; specialties and evidenceRemovedAt only after a removal', () => {
    const plain = skillsUpdateFields({ completeness: 75, completenessNext: 'styles', specialties: null });
    assert.deepEqual(Object.keys(plain).sort(), ['skills.completeness', 'skills.completenessNext', 'skills.updatedAt']);
    assert.equal(plain['skills.completeness'], 75);
    assert.equal(plain['skills.completenessNext'], 'styles');
    assert.ok(serverTime(plain['skills.updatedAt']));
    const cleaned = skillsUpdateFields({
      completeness: 100,
      completenessNext: null,
      specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }],
    });
    assert.equal(cleaned['skills.completenessNext'], null);
    assert.deepEqual(cleaned['skills.specialties'], [{ id: 'portrait', level: 2, evidencePostIds: [] }]);
    assert.ok(serverTime(cleaned['skills.evidenceRemovedAt']));
  });

  test('stale writes are FAILED_PRECONDITION and NOT_FOUND; anything else is rethrown', () => {
    assert.equal(isStaleWriteError({ code: 9 }), true);
    assert.equal(isStaleWriteError({ code: 5 }), true);
    assert.equal(isStaleWriteError({ code: 14 }), false);
    assert.equal(isStaleWriteError(new Error('boom')), false);
    assert.equal(isStaleWriteError(null), false);
  });

  test('a write for a deleted document (no update time) touches nothing', async () => {
    const writer = firestoreSkillsScoreWriter({} as Firestore, 'p1', undefined);
    assert.equal(await writer.write({ completeness: 10, completenessNext: 'specialties', specialties: null }), 'stale');
  });

  test('the handler passes the skills maps of both snapshots to the use case', async () => {
    const writes: SkillsScoreUpdate[] = [];
    const deps: ScoreSkillsDeps = {
      posts: { owned: async () => new Set<string>() },
      writer: {
        write: async (u) => {
          writes.push(u);
          return 'written';
        },
      },
    };
    const outcome = await handlePhotographerWrite(
      {
        uid: 'p1',
        before: { bio: 'x' },
        after: {
          bio: 'x',
          skills: { schemaVersion: 1, specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }], languages: ['vi'] },
        },
      },
      deps,
    );
    assert.equal(outcome, 'written');
    assert.deepEqual(writes, [{ completeness: 75, completenessNext: 'styles', specialties: null }]);
  });

  test('the handler skips a deleted document and a malformed skills value (warning logged)', async () => {
    const deps: ScoreSkillsDeps = {
      posts: { owned: async () => new Set<string>() },
      writer: { write: async () => assert.fail('nothing may be written') },
    };
    assert.equal(await handlePhotographerWrite({ uid: 'p1', before: { skills: {} }, after: undefined }, deps), 'deleted');
    assert.equal(await handlePhotographerWrite({ uid: 'p1', before: undefined, after: { skills: 'portrait' } }, deps), 'malformed');
  });
});
```

```ts
// app_flutter/firebase/functions/test/integration/photographer_write.test.ts
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';

// The real trigger on the Functions emulator: Admin writes to photographers/{uid} fire it.
// CI only (rule 2026-10-02); not run while executing the plan.

const P = 'skills-p1';
const OTHER = 'skills-p2';
let app: App;
let db: Firestore;

const post = (author: string) => ({
  authorId: author,
  photographerId: author,
  serviceId: 'seed-service-portrait',
  imageUrls: ['https://example.test/1.jpg'],
  createdAt: Timestamp.now(),
});

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'skills-test');
  db = getFirestore(app);
  await db.doc('posts/ev-own').set(post(P));
  await db.doc('posts/ev-theirs').set(post(OTHER));
});
after(async () => {
  await deleteApp(app);
});

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const skillsOf = async (uid: string) =>
  (await db.doc(`photographers/${uid}`).get()).data()?.skills as Record<string, unknown> | undefined;

async function scored(uid: string, timeoutMs = 20_000): Promise<Record<string, unknown>> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const s = await skillsOf(uid);
    if (s?.completeness !== undefined) return s;
    if (Date.now() > end) throw new Error('onPhotographerWrite did not score the profile in time');
    await sleep(250);
  }
}

const clientSkills = {
  schemaVersion: 1,
  specialties: [
    { id: 'portrait', level: 3, evidencePostIds: ['ev-theirs'] },
    { id: 'couple', level: 2, evidencePostIds: ['ev-own', 'ev-gone'] },
  ],
  styles: ['film'],
  extras: [],
  languages: ['vi'],
  audiences: [],
  yearsExperience: null,
};

describe('onPhotographerWrite on the emulators', () => {
  test('foreign and missing evidence is removed, the level drops and the score is written', async () => {
    await db.doc(`photographers/${P}`).set({ onboardingComplete: false, verified: false, skills: clientSkills, updatedAt: Timestamp.now() });
    const s = await scored(P);
    assert.deepEqual(s.specialties, [
      { id: 'portrait', level: 2, evidencePostIds: [] },
      { id: 'couple', level: 2, evidencePostIds: ['ev-own'] },
    ]);
    assert.equal(s.completeness, 85);
    assert.equal(s.completenessNext, 'audiences');
    assert.ok(s.updatedAt instanceof Timestamp);
    assert.ok(s.evidenceRemovedAt instanceof Timestamp);
  });

  test('saving the same skills again writes nothing more', async () => {
    const first = await scored(P);
    // What the app sends next time: the cleaned client part plus a new top-level updatedAt.
    await db.doc(`photographers/${P}`).set({ skills: { ...clientSkills, specialties: first.specialties }, updatedAt: Timestamp.now() }, { merge: true });
    await sleep(5_000);
    const again = await skillsOf(P);
    assert.ok(again !== undefined);
    assert.equal((again.updatedAt as Timestamp).toMillis(), (first.updatedAt as Timestamp).toMillis());
    assert.equal(again.completeness, 85);
  });

  test('a profile without skills is left alone', async () => {
    await db.doc(`photographers/${OTHER}`).set({ onboardingComplete: false, verified: false, bio: 'Chưa có kỹ năng' });
    await sleep(3_000);
    assert.equal(await skillsOf(OTHER), undefined);
  });
});
```

- [ ] **Step 2: Run the unit tests and see them fail**

Run (from `app_flutter/firebase/functions`): `npm test`
Expected: FAIL. `photographer_write.test.ts` does not load (`TRIGGER_OPTIONS` is not exported by `src/config.js`, `ERR_MODULE_NOT_FOUND` for `src/infra/skills_firestore.js`); the other 21 tests pass.

The integration test is **CI only**: do not run `npm run test:integration` here (Global Constraints). Before this task's code it would time out waiting for the score.

- [ ] **Step 3: Implement**

In `app_flutter/firebase/functions/src/config.ts`, add below the existing `import type { CallableOptions } …` line:

```ts
import type { DocumentOptions } from 'firebase-functions/v2/firestore';
```

and append at the end of the file:

```ts
/**
 * Options of every Firestore trigger (onPhotographerWrite, spec 2026-10-02 §2). `retry: true`:
 * a failed read or write is retried; the use case is idempotent (precondition + loop guard).
 */
export const TRIGGER_OPTIONS = {
  region: REGION,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 10,
  minInstances: 0,
  retry: true,
} as const satisfies Omit<DocumentOptions, 'document'>;
```

```ts
// app_flutter/firebase/functions/src/infra/skills_firestore.ts
import { FieldValue, type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { isOwnEvidencePost, type OwnedPostsReader, type SkillsScoreUpdate, type SkillsScoreWriter } from '@photobooking/domain';

// Firestore adapters of the onPhotographerWrite ports. Reads go through one `db.getAll`.

export const POSTS = 'posts';

export function firestoreOwnedPostsReader(db: Firestore): OwnedPostsReader {
  return {
    async owned(uid, postIds) {
      if (postIds.length === 0) return new Set<string>();
      const snaps = await db.getAll(...postIds.map((id) => db.collection(POSTS).doc(id)));
      return new Set(snaps.filter((s) => isOwnEvidencePost(uid, s.exists ? s.data() : undefined)).map((s) => s.id));
    },
  };
}

/** Field paths of the single update (dotted, so the client-owned part of `skills` stays as is). */
export function skillsUpdateFields(update: SkillsScoreUpdate): DocumentData {
  return {
    'skills.completeness': update.completeness,
    'skills.completenessNext': update.completenessNext,
    'skills.updatedAt': FieldValue.serverTimestamp(),
    ...(update.specialties === null
      ? {}
      : { 'skills.specialties': update.specialties, 'skills.evidenceRemovedAt': FieldValue.serverTimestamp() }),
  };
}

/** gRPC FAILED_PRECONDITION (9: changed since the trigger's snapshot) or NOT_FOUND (5: deleted). */
export function isStaleWriteError(e: unknown): boolean {
  if (typeof e !== 'object' || e === null || !('code' in e)) return false;
  return e.code === 9 || e.code === 5;
}

/**
 * Writes only if `photographers/{uid}` still has the update time of the snapshot the trigger got.
 * A newer save fails the precondition: `stale`, no retry (that save's own trigger scores it).
 */
export function firestoreSkillsScoreWriter(db: Firestore, uid: string, lastUpdateTime: Timestamp | undefined): SkillsScoreWriter {
  return {
    async write(update) {
      if (lastUpdateTime === undefined) return 'stale';
      try {
        await db.collection('photographers').doc(uid).update(skillsUpdateFields(update), { lastUpdateTime });
        return 'written';
      } catch (e) {
        if (isStaleWriteError(e)) return 'stale';
        throw e;
      }
    },
  };
}
```

```ts
// app_flutter/firebase/functions/src/infra/live_skills.ts
import type { Timestamp } from 'firebase-admin/firestore';
import type { ScoreSkillsDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { firestoreOwnedPostsReader, firestoreSkillsScoreWriter } from './skills_firestore.js';

/** Production wiring of onPhotographerWrite for one event (the writer carries its precondition). */
export function liveSkillsDeps(uid: string, lastUpdateTime: Timestamp | undefined): ScoreSkillsDeps {
  const firestore = db();
  return {
    posts: firestoreOwnedPostsReader(firestore),
    writer: firestoreSkillsScoreWriter(firestore, uid, lastUpdateTime),
  };
}
```

```ts
// app_flutter/firebase/functions/src/triggers/photographer_write.ts
import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { scorePhotographerSkills, type ScoreSkillsDeps, type ScoreSkillsOutcome } from '@photobooking/domain';

/** The two snapshots of one `photographers/{uid}` write; `after` undefined when it was deleted. */
export interface PhotographerWriteInput {
  readonly uid: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

export async function handlePhotographerWrite(input: PhotographerWriteInput, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const outcome = await scorePhotographerSkills(
    { uid: input.uid, before: input.before?.skills, after: input.after?.skills, deleted: input.after === undefined },
    deps,
  );
  if (outcome === 'malformed') {
    // The rules refuse such writes; reaching here means an Admin write or a rules gap.
    logger.warn('onPhotographerWrite: skills do not match the schema; nothing written', { uid: input.uid });
  } else if (outcome === 'written' || outcome === 'stale') {
    logger.info('onPhotographerWrite', { uid: input.uid, outcome });
  }
  return outcome;
}
```

Replace `app_flutter/firebase/functions/src/index.ts` with:

```ts
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { handleGetContactLink } from './callables/get_contact_link.js';
import { CALLABLE_OPTIONS, TRIGGER_OPTIONS } from './config.js';
import { liveContactDeps } from './infra/live.js';
import { liveSkillsDeps } from './infra/live_skills.js';
import { handlePhotographerWrite } from './triggers/photographer_write.js';

// Entry point of the Cloud Functions codebase. Each export is one deployed function.

/** `{bookingId | registrationId, channel}` → `{url}`; contract in plan 2b "Out of scope". */
export const getContactLink = onCall(CALLABLE_OPTIONS, (request) => handleGetContactLink(request, liveContactDeps()));

/**
 * Scores `photographers/{uid}.skills` ("Độ khớp hồ sơ") and removes evidence that is not the
 * photographer's own post (spec 2026-10-02-photographer-write-function-design.md).
 */
export const onPhotographerWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'photographers/{uid}' }, async (event) => {
  const uid = event.params.uid;
  const after = event.data?.after;
  const live = after?.exists === true ? after : undefined;
  await handlePhotographerWrite(
    { uid, before: event.data?.before.data(), after: live?.data() },
    liveSkillsDeps(uid, live?.updateTime),
  );
});
```

- [ ] **Step 4: Run and see it pass**

Run (from `app_flutter/firebase/functions`): `npm run lint && npm run typecheck && npm test && npm run build`
Expected: lint and typecheck clean; `ℹ tests 27`, `ℹ pass 27`, `ℹ fail 0` (21 before + 6; the malformed case prints one `WARNING` JSON log line with the uid only); build prints `lib/index.js` and `⚡ Done`.

CI runs `npm run test:integration` (Task 14): its log shows `✔ functions: Loaded functions definitions from source: getContactLink, onPhotographerWrite`, the three `onPhotographerWrite on the emulators` tests pass and `ℹ fail 0`. Not run locally.

- [ ] **Step 5: Commit**

```bash
git add app_flutter/firebase/functions
git commit -m "feat(functions): onPhotographerWrite scores skills and removes invalid evidence server-side

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Rules pin `completenessNext` and `evidenceRemovedAt` as server-owned

**Files:**
- Modify: `app_flutter/firebase/firestore.rules` (function `validSkills`), `app_flutter/firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Consumes: the existing `validSkills(k, before)` (keys allow-list and the `k.diff(before).affectedKeys()` pin of `completeness`/`updatedAt`) and the rules-test helpers `goodSkills`, `genre`, `skillsOwner`, `writeSkills`, imports `doc`, `setDoc`, `getDoc`, `updateDoc`, `deleteField`, `serverTimestamp`, `Timestamp`, `assert`, `assertSucceeds`, `assertFails` (plan 2c); Task 11's field names.
- Produces: rule "a client may neither set, change nor remove `skills.completenessNext` or `skills.evidenceRemovedAt`; the app's merge save keeps them" (same policy as `completeness` and `skills.updatedAt`).

- [ ] **Step 1: Write the failing rules tests**

Append to `app_flutter/firebase/rules-test/rules.test.mjs`, after the test `'the adapter merge save keeps server skills fields; changing or removing them fails'`:

```js
test('completenessNext and evidenceRemovedAt are server-only like completeness', async () => {
  const stamp = Timestamp.fromMillis(8000);
  const server = { completeness: 85, completenessNext: 'audiences', updatedAt: stamp, evidenceRemovedAt: stamp };
  const db = await skillsOwner('k12', { skills: { ...goodSkills(), ...server } });
  const ref = doc(db, 'photographers/k12');
  // Exact shape of FirestoreSkillsRepository.save: the stored server fields survive the merge.
  await assertSucceeds(setDoc(ref, { skills: { ...goodSkills(), styles: ['film'] }, updatedAt: serverTimestamp() }, { merge: true }));
  const snap = await getDoc(ref);
  assert.equal(snap.data().skills.completenessNext, 'audiences');
  assert.equal(snap.data().skills.evidenceRemovedAt.toMillis(), 8000);
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), completenessNext: 'styles' }));
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), completenessNext: null }));
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), evidenceRemovedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { 'skills.completenessNext': deleteField() }));
  await assertFails(updateDoc(ref, { 'skills.evidenceRemovedAt': deleteField() }));
  // None stored yet: the client cannot add them either, not even as null.
  const fresh = await skillsOwner('k13');
  await assertFails(writeSkills(fresh, 'k13', { ...goodSkills(), completenessNext: null }));
  await assertFails(writeSkills(fresh, 'k13', { ...goodSkills(), evidenceRemovedAt: Timestamp.fromMillis(1) }));
  await assertSucceeds(writeSkills(fresh, 'k13', goodSkills()));
});

test('expression budget: the largest valid skills save still passes with all four server fields stored', async () => {
  const ids = (p) => [`${p}1`, `${p}2`, `${p}3`];
  const largest = {
    ...goodSkills(),
    specialties: [
      genre('portrait', 3, ids('a')), genre('wedding', 3, ids('b')), genre('couple', 3, ids('c')),
      genre('family', 2, ids('d')), genre('graduation', 2, ids('e')), { ...genre('event', 1, ids('f')), years: 50 },
    ],
    styles: ['natural_light', 'film', 'minimal', 'editorial'],
    extras: ['retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light'],
    languages: ['vi', 'en', 'zh', 'ko', 'ja'],
    audiences: ['couple', 'family_kids', 'business', 'foreigner'],
  };
  const stamp = Timestamp.fromMillis(9000);
  const db = await skillsOwner('k14', {
    skills: { ...largest, completeness: 100, completenessNext: null, updatedAt: stamp, evidenceRemovedAt: stamp },
  });
  await assertSucceeds(setDoc(doc(db, 'photographers/k14'), {
    skills: { ...largest, yearsExperience: 7 },
    updatedAt: serverTimestamp(),
  }, { merge: true }));
});
```

- [ ] **Step 2: (CI only) the new tests fail before the rule change**

Do not run the rules tests locally (banner at the top of this plan; record the skip in the ledger). On CI, before Step 3, the first new test fails at the first `assertSucceeds` (the stored `completenessNext` key is outside `validSkills`' allow-list, so every save of that profile is refused); the second fails the same way.

- [ ] **Step 3: Implement**

In `app_flutter/firebase/firestore.rules`, replace

```
    // skills.completeness and skills.updatedAt are written by Cloud Functions only: each must equal
    // the stored value, and be absent (not even null) when none is stored.
    function validSkills(k, before) {
      return k is map
        && k.keys().hasOnly(['schemaVersion', 'specialties', 'styles', 'extras', 'languages',
                             'audiences', 'yearsExperience', 'completeness', 'updatedAt'])
        && k.get('schemaVersion', 0) == 1
        && !k.diff(before).affectedKeys().hasAny(['completeness', 'updatedAt'])
```

with

```
    // skills.completeness, completenessNext, updatedAt and evidenceRemovedAt are written by the
    // Cloud Function onPhotographerWrite only: each must equal the stored value, and be absent (not
    // even null) when none is stored. The two extra names add 4 list entries to a request, far
    // inside the 1000-expression budget (rules test "expression budget …" pins the largest save).
    function validSkills(k, before) {
      return k is map
        && k.keys().hasOnly(['schemaVersion', 'specialties', 'styles', 'extras', 'languages',
                             'audiences', 'yearsExperience', 'completeness', 'completenessNext',
                             'updatedAt', 'evidenceRemovedAt'])
        && k.get('schemaVersion', 0) == 1
        && !k.diff(before).affectedKeys().hasAny(['completeness', 'completenessNext', 'updatedAt',
                                                  'evidenceRemovedAt'])
```

(The Function writes through the Admin SDK, which rules do not apply to.)

- [ ] **Step 4: (CI only) all rules tests pass**

Not run locally. CI (`flutter.yml` step "Firestore rules tests (emulator)" and `firebase-deploy.yml` job `test`) runs `npm test` in `app_flutter/firebase/rules-test`; it must end with `ℹ fail 0`, and blocks the rules deploy otherwise. If CI reports `Exceeded maximum number of expressions`, the budget test names the cause: report it instead of loosening `validSpecialties`.

- [ ] **Step 5: Commit**

```bash
git add app_flutter/firebase/firestore.rules app_flutter/firebase/rules-test/rules.test.mjs
git commit -m "feat(rules): skills.completenessNext and skills.evidenceRemovedAt are server-owned

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: S38 shows the server's score; the on-device score is deleted

**Files:**
- Create: `app_flutter/lib/data/skills/skills_server_info.dart`, `app_flutter/test/data/skills/no_device_score_test.dart`
- Modify: `app_flutter/lib/data/skills/skills_repository.dart`, `lib/data/skills/firestore_skills_repository.dart`, `lib/data/skills/skills_providers.dart`, `lib/core/widgets/completeness_meter.dart`, `lib/features/skills/skills_draft_store.dart`, `lib/features/skills/skills_controller.dart`, `lib/features/skills/skills_screen.dart`, `lib/l10n/app_vi.arb` (+ generated `lib/l10n/app_localizations*.dart`), `test/data/skills/skills_repository_test.dart`, `test/core/widgets/completeness_meter_test.dart`, `test/features/skills/skills_controller_test.dart`, `test/features/skills/skills_screen_test.dart`
- Delete: `app_flutter/lib/data/skills/skills_completeness.dart`, `app_flutter/test/data/skills/skills_completeness_test.dart` (its cases live in `packages/domain/test/fixtures/skills_completeness.json`, Task 10)

**Interfaces:**
- Consumes: Task 11's stored fields (`skills.completeness` int 0..100, `skills.completenessNext` step code or null, `skills.evidenceRemovedAt` Timestamp); plan 2c: `PhotographerSkills`, `skillsFromMap`, `skillsToMap`, `SkillsRepository`, `FakeSkillsRepository` (`seed`, `stored`, `loadCalls`, `saveCalls`, `failLoadWith`, `failSaveWith`, `holdSave`), `FirestoreSkillsRepository`, `skillsRepositoryProvider`, `photographerSkillsProvider`, `SkillsDraftStore`, `SkillsController`, `SkillsEditorState`, `CompletenessMeter`, test support `SkillsWorld` (`skills`, `prefs`, `uid`) and `skillsApp`.
- Produces:
  - `enum CompletenessStepCode { specialties, levels, evidence, styles, languages, audiences, extras }` with `static CompletenessStepCode? fromCode(Object? code)` (code = `name`).
  - `class SkillsServerInfo { const SkillsServerInfo({int? completeness, CompletenessStepCode? next, DateTime? evidenceRemovedAt}); static const none; }` (value equality; `evidenceRemovedAt` is UTC).
  - `SkillsServerInfo skillsServerInfoFromMap(Object? raw, DateTime? Function(Object? value) instant)`.
  - `class SkillsSnapshot { const SkillsSnapshot(PhotographerSkills skills, [SkillsServerInfo server = SkillsServerInfo.none]); }`.
  - `SkillsRepository.load(String uid) → Future<SkillsSnapshot>` (was `Future<PhotographerSkills>`); `FakeSkillsRepository.seedServer(String uid, SkillsServerInfo info)`.
  - `photographerSkillsSnapshotProvider` (`FutureProvider.autoDispose.family<SkillsSnapshot, String>`, the one read); `photographerSkillsProvider` keeps its type and derives from it (plan 2d2 uses both; Task 14 updates its text).
  - `CompletenessMeter({required int? percent, String? nextHint})`: `null` shows "Chưa có điểm" and an empty bar.
  - `SkillsDraftStore.evidenceSeenKeyFor(uid)` = `'skillsEvidenceSeen.<uid>'`, `evidenceRemovedSeen(uid) → DateTime?`, `markEvidenceRemovedSeen(uid, DateTime at)`.
  - `SkillsEditorState`: new `server` (`SkillsServerInfo`), `scored` (the skills the server number belongs to: the saved skills at open), `evidenceRemovedNotice` (bool), getter `scoreOutdated` (`draft != scored`); the getter `completeness` is removed. `SkillsController.evidenceRemovedNoticeShown()`.
  - l10n: `completenessNone` "Chưa có điểm", `skillsFitSaveToScore` "Lưu để tính độ khớp", `skillsFitSaveToUpdate` "Lưu để cập nhật độ khớp", `skillsEvidenceRemoved` "Một số minh chứng không hợp lệ đã được gỡ", `skillsHintEvidenceAny` "Thêm ảnh minh chứng cho thể loại Chuyên sâu"; the six `skillsHint*` strings lose their `{percent}` (the server stores the next step, not the score after it).

S38 hint, in order (spec §3): no server number → "Lưu để tính độ khớp"; number and `draft != scored` → keep the number, "Lưu để cập nhật độ khớp"; otherwise by `completenessNext` (`null` → "Hồ sơ kỹ năng đã đầy đủ"; `evidence` names the first level-3 genre of `scored` without posts).

- [ ] **Step 1: Write the failing tests**

Replace `test/data/skills/skills_repository_test.dart` with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

const skills = PhotographerSkills(
  specialties: [
    SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1']),
  ],
  styles: ['film'],
  languages: ['vi'],
  yearsExperience: 4,
);

void contract(String name, Future<SkillsRepository> Function() create) {
  group('$name contract', () {
    test('a photographer without skills loads as empty, not scored', () async {
      final snap = await (await create()).load('nobody');
      expect(snap.skills, PhotographerSkills.empty);
      expect(snap.server, SkillsServerInfo.none);
    });

    test('save then load returns the same skills', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect((await repo.load('u1')).skills, skills);
    });

    test('a second save replaces lists and clears years', () async {
      final repo = await create();
      await repo.save('u1', skills);
      const next = PhotographerSkills(
        specialties: [SpecialtySkill(id: 'wedding')],
        styles: ['minimal'],
        languages: ['en'],
      );
      await repo.save('u1', next);
      expect((await repo.load('u1')).skills, next);
    });

    test('photographers are kept apart', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect((await repo.load('u2')).skills, PhotographerSkills.empty);
    });
  });
}

void main() {
  contract('fake', () async => FakeSkillsRepository());
  contract(
    'firestore',
    () async => FirestoreSkillsRepository(db: FakeFirebaseFirestore()),
  );

  test('the fake counts calls, seeds and fails on demand', () async {
    final repo = FakeSkillsRepository()..seed('u1', skills);
    expect((await repo.load('u1')).skills, skills);
    expect(repo.loadCalls, 1);
    repo.failSaveWith = StateError('offline');
    await expectLater(
      repo.save('u1', PhotographerSkills.empty),
      throwsStateError,
    );
    expect(repo.stored('u1'), skills);
    expect(repo.saveCalls, 1);
    repo.failLoadWith = StateError('offline');
    await expectLater(repo.load('u1'), throwsStateError);
  });

  test('the fake returns the seeded server info and keeps it across saves', () async {
    const info = SkillsServerInfo(
      completeness: 75,
      next: CompletenessStepCode.styles,
    );
    final repo = FakeSkillsRepository()
      ..seed('u1', skills)
      ..seedServer('u1', info);
    expect((await repo.load('u1')).server, info);
    await repo.save('u1', PhotographerSkills.initial);
    expect((await repo.load('u1')).server, info);
  });

  group('Firestore adapter', () {
    test('writes photographers/{uid}.skills in the spec shape and keeps other fields', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'bio': 'Chân dung',
        'onboardingComplete': false,
        'skills': {
          'completeness': 40,
          'completenessNext': 'styles',
          'styles': ['editorial'],
        },
      });
      await FirestoreSkillsRepository(db: db).save('u1', skills);
      final data = (await db.collection('photographers').doc('u1').get())
          .data()!;
      expect(data['bio'], 'Chân dung');
      expect(data['updatedAt'], isA<Timestamp>());
      final stored = Map<String, dynamic>.from(data['skills'] as Map);
      expect(
        stored['completeness'],
        40,
        reason: 'server-owned, never written by the client',
      );
      expect(stored['completenessNext'], 'styles');
      expect(stored['schemaVersion'], 1);
      expect(stored['styles'], ['film']);
      expect(stored['specialties'], [
        {
          'id': 'portrait',
          'level': 3,
          'evidencePostIds': ['p1'],
        },
      ]);
      expect(stored['yearsExperience'], 4);
    });

    test(
      'a document with only the old flat specialties list has no skills yet',
      () async {
        final db = FakeFirebaseFirestore();
        await db.collection('photographers').doc('u1').set({
          'specialties': ['wedding'],
        });
        final snap = await FirestoreSkillsRepository(db: db).load('u1');
        expect(snap.skills, PhotographerSkills.empty);
        expect(snap.server, SkillsServerInfo.none);
      },
    );

    test('reads the server fields of onPhotographerWrite; times as UTC', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'skills': {
          ...skillsToMap(skills),
          'completeness': 85,
          'completenessNext': 'audiences',
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 2, 8)),
          'evidenceRemovedAt': Timestamp.fromDate(
            DateTime.utc(2026, 10, 2, 8, 30),
          ),
        },
      });
      final snap = await FirestoreSkillsRepository(db: db).load('u1');
      expect(snap.skills, skills);
      expect(
        snap.server,
        SkillsServerInfo(
          completeness: 85,
          next: CompletenessStepCode.audiences,
          evidenceRemovedAt: DateTime.utc(2026, 10, 2, 8, 30),
        ),
      );
      expect(snap.server.evidenceRemovedAt!.isUtc, isTrue);
    });

    test('not scored yet, or malformed server fields, read as null', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'skills': skillsToMap(skills),
      });
      await db.collection('photographers').doc('u2').set({
        'skills': {
          ...skillsToMap(skills),
          'completeness': 140,
          'completenessNext': 'bogus',
          'evidenceRemovedAt': '2026-10-02',
        },
      });
      await db.collection('photographers').doc('u3').set({
        'skills': {...skillsToMap(skills), 'completeness': '85'},
      });
      final repo = FirestoreSkillsRepository(db: db);
      for (final uid in ['u1', 'u2', 'u3']) {
        expect((await repo.load(uid)).server, SkillsServerInfo.none, reason: uid);
      }
    });
  });

  test('providers: built-in catalogue and one read per photographer', () async {
    final repo = FakeSkillsRepository()
      ..seed('u1', skills)
      ..seedServer('u1', const SkillsServerInfo(completeness: 90));
    final container = ProviderContainer(
      overrides: [skillsRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    expect(
      container.read(skillCatalogProvider).ids(SkillGroup.language),
      hasLength(5),
    );
    final a = container.listen(photographerSkillsProvider('u1'), (_, _) {});
    final b = container.listen(
      photographerSkillsSnapshotProvider('u1'),
      (_, _) {},
    );
    addTearDown(a.close);
    addTearDown(b.close);
    expect(
      await container.read(photographerSkillsProvider('u1').future),
      skills,
    );
    expect(
      (await container.read(photographerSkillsSnapshotProvider('u1').future))
          .server
          .completeness,
      90,
    );
    expect(repo.loadCalls, 1);
  });
}
```

```dart
// test/data/skills/no_device_score_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app never computes the profile score (spec 2026-10-02 §3)', () {
    expect(
      File('lib/data/skills/skills_completeness.dart').existsSync(),
      isFalse,
    );
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('skills_completeness'))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
```

In `test/core/widgets/completeness_meter_test.dart`, add inside `main()` after the test `'clamps to 0..100 and works without a hint'`:

```dart
  testWidgets('not scored yet: "Chưa có điểm", empty bar, the hint still shows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        const CompletenessMeter(percent: null, nextHint: 'Lưu để tính độ khớp'),
      ),
    );
    expect(find.text('Chưa có điểm'), findsOneWidget);
    expect(find.text('Lưu để tính độ khớp'), findsOneWidget);
    expect(
      tester
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor,
      0,
    );
    expect(
      tester.getSemantics(find.byType(CompletenessMeter)),
      isSemantics(
        label: 'Độ khớp hồ sơ',
        value: 'Chưa có điểm',
        hint: 'Lưu để tính độ khớp',
      ),
    );
    handle.dispose();
  });
```

In `test/features/skills/skills_controller_test.dart`, add the import `import 'package:photobooking/data/skills/skills_server_info.dart';` after the `skills_rules.dart` import; in the first test replace `    expect(_st(c).completeness.percent, 10);` with

```dart
    expect(_st(c).server, SkillsServerInfo.none);
    expect(_st(c).evidenceRemovedNotice, isFalse);
```

and add at the end of `main()`:

```dart
  test('the server score stays while editing; scoreOutdated follows the draft', () async {
    const info = SkillsServerInfo(
      completeness: 75,
      next: CompletenessStepCode.styles,
    );
    final (_, c) = await _open(
      saved: _wedding,
      before: (w) async => w.skills.seedServer(w.uid, info),
    );
    expect(_st(c).server, info);
    expect(_st(c).scored, _wedding);
    expect(_st(c).scoreOutdated, isFalse);
    _ctrl(c).toggleTag(SkillGroup.style, 'film');
    expect(_st(c).server, info);
    expect(_st(c).scoreOutdated, isTrue);
    expect(await _ctrl(c).submit(), SkillsSubmitResult.saved);
    expect(_st(c).server, info, reason: 'no number is computed on the device');
    expect(
      _st(c).scoreOutdated,
      isTrue,
      reason: 'the Function scores the new skills; S38 shows it next time',
    );
  });

  test('evidence removed by the server: notice once, a newer removal again', () async {
    final at = DateTime.utc(2026, 10, 2, 8);
    final (w, c) = await _open(
      saved: _wedding,
      before: (world) async {
        world.skills.seedServer(
          world.uid,
          SkillsServerInfo(completeness: 75, evidenceRemovedAt: at),
        );
        await SkillsDraftStore(world.prefs).markEvidenceRemovedSeen(
          world.uid,
          at.subtract(const Duration(minutes: 1)),
        );
      },
    );
    expect(_st(c).evidenceRemovedNotice, isTrue);
    await _ctrl(c).evidenceRemovedNoticeShown();
    expect(_st(c).evidenceRemovedNotice, isFalse);
    expect(SkillsDraftStore(w.prefs).evidenceRemovedSeen(w.uid), at);
    expect(w.prefs.getInt('skillsEvidenceSeen.${w.uid}'), at.millisecondsSinceEpoch);
  });

  test('evidence removal already seen: no notice', () async {
    final at = DateTime.utc(2026, 10, 2, 8);
    final (_, c) = await _open(
      saved: _wedding,
      before: (w) async {
        w.skills.seedServer(
          w.uid,
          SkillsServerInfo(completeness: 75, evidenceRemovedAt: at),
        );
        await SkillsDraftStore(w.prefs).markEvidenceRemovedSeen(w.uid, at);
      },
    );
    expect(_st(c).evidenceRemovedNotice, isFalse);
  });
```

In `test/features/skills/skills_screen_test.dart`, add the import `import 'package:photobooking/data/skills/skills_server_info.dart';` after the `photographer_skills.dart` import. In the first test replace

```dart
      expect(
        tester
            .widget<CompletenessMeter>(find.byType(CompletenessMeter))
            .percent,
        10,
      );
      expect(find.text('Chọn ít nhất 1 thể loại để lên 75%'), findsOneWidget);
```

with

```dart
      expect(
        tester
            .widget<CompletenessMeter>(find.byType(CompletenessMeter))
            .percent,
        isNull,
      );
      expect(find.text('Chưa có điểm'), findsOneWidget);
      expect(find.text('Lưu để tính độ khớp'), findsOneWidget);
```

In the test `'Chuyên sâu without evidence: warning, and Tiếp tục saves nothing'` replace

```dart
      expect(
        find.text('Thêm ảnh minh chứng cho Chân dung để lên 75%'),
        findsOneWidget,
      );
```

with

```dart
      expect(find.text('Lưu để tính độ khớp'), findsOneWidget);
```

and add before the test `'the app router registers the three skills routes'`:

```dart
  const portrait = PhotographerSkills(
    specialties: [SpecialtySkill(id: 'portrait')],
    languages: ['vi'],
  );

  Future<void> seedScore(SkillsWorld w, SkillsServerInfo info) async =>
      w.skills.seedServer(w.uid, info);

  int? meterPercent(WidgetTester tester) => tester
      .widget<CompletenessMeter>(find.byType(CompletenessMeter))
      .percent;

  testWidgets('S38 shows the server score and the hint for its next step', (
    tester,
  ) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: portrait,
      before: (w) => seedScore(
        w,
        const SkillsServerInfo(
          completeness: 75,
          next: CompletenessStepCode.styles,
        ),
      ),
    );
    expect(meterPercent(tester), 75);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Chọn phong cách'), findsOneWidget);
  });

  testWidgets('an edit keeps the saved number and asks to save to update it', (
    tester,
  ) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: portrait,
      before: (w) => seedScore(
        w,
        const SkillsServerInfo(
          completeness: 75,
          next: CompletenessStepCode.styles,
        ),
      ),
    );
    await _tapKey(tester, 'style-film');
    expect(meterPercent(tester), 75);
    expect(find.text('Lưu để cập nhật độ khớp'), findsOneWidget);
    expect(find.text('Chọn phong cách'), findsNothing);
  });

  testWidgets('next step evidence names the Chuyên sâu genre without posts', (
    tester,
  ) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: const PhotographerSkills(
        specialties: [SpecialtySkill(id: 'portrait', level: 3)],
        languages: ['vi'],
      ),
      before: (w) => seedScore(
        w,
        const SkillsServerInfo(
          completeness: 55,
          next: CompletenessStepCode.evidence,
        ),
      ),
    );
    expect(find.text('Thêm ảnh minh chứng cho Chân dung'), findsOneWidget);
  });

  testWidgets('a complete profile says so', (tester) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: portrait,
      before: (w) => seedScore(w, const SkillsServerInfo(completeness: 100)),
    );
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Hồ sơ kỹ năng đã đầy đủ'), findsOneWidget);
  });

  testWidgets('evidence removed by the server: the SnackBar shows once', (
    tester,
  ) async {
    _tallPhone(tester);
    final removedAt = DateTime.utc(2026, 10, 2, 8);
    final w = await _pump(
      tester,
      at: '/profile/skills',
      saved: portrait,
      before: (world) => seedScore(
        world,
        SkillsServerInfo(
          completeness: 75,
          next: CompletenessStepCode.styles,
          evidenceRemovedAt: removedAt,
        ),
      ),
    );
    expect(
      find.text('Một số minh chứng không hợp lệ đã được gỡ'),
      findsOneWidget,
    );
    expect(SkillsDraftStore(w.prefs).evidenceRemovedSeen(w.uid), removedAt);
    // Open S38 again on the same device: no second notice.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(skillsApp(w, initialLocation: '/profile/skills'));
    await tester.pumpAndSettle();
    expect(find.byType(CompletenessMeter), findsOneWidget);
    expect(
      find.text('Một số minh chứng không hợp lệ đã được gỡ'),
      findsNothing,
    );
  });
```

- [ ] **Step 2: Run and see it fail**

Run (from `app_flutter/`): `flutter test --no-pub test/data/skills test/core/widgets/completeness_meter_test.dart test/features/skills`
Expected: FAIL to compile: `Error when reading 'lib/data/skills/skills_server_info.dart': No such file or directory`, then `Undefined name 'SkillsServerInfo'` / `The method 'seedServer' isn't defined`; `no_device_score_test.dart` fails because `lib/data/skills/skills_completeness.dart` exists.

- [ ] **Step 3: Server info and the repository**

```dart
// lib/data/skills/skills_server_info.dart
import 'package:photobooking/data/skills/photographer_skills.dart';

/// Step codes of `skills.completenessNext`, written by the Cloud Function
/// `onPhotographerWrite` (`COMPLETENESS_STEPS` in packages/domain), highest
/// weight first. The app shows them; it never computes them.
enum CompletenessStepCode {
  specialties,
  levels,
  evidence,
  styles,
  languages,
  audiences,
  extras;

  static CompletenessStepCode? fromCode(Object? code) {
    for (final c in values) {
      if (c.name == code) return c;
    }
    return null;
  }
}

/// What the server wrote into `photographers/{uid}.skills`. All null until
/// the Function has scored the skills once.
class SkillsServerInfo {
  const SkillsServerInfo({
    this.completeness,
    this.next,
    this.evidenceRemovedAt,
  });

  static const none = SkillsServerInfo();

  /// "Độ khớp hồ sơ", 0..100.
  final int? completeness;

  /// The first missing step; null when complete or not scored yet.
  final CompletenessStepCode? next;

  /// UTC instant of the last time the Function removed invalid evidence.
  final DateTime? evidenceRemovedAt;

  @override
  bool operator ==(Object other) =>
      other is SkillsServerInfo &&
      other.completeness == completeness &&
      other.next == next &&
      other.evidenceRemovedAt == evidenceRemovedAt;

  @override
  int get hashCode => Object.hash(completeness, next, evidenceRemovedAt);

  @override
  String toString() =>
      'SkillsServerInfo($completeness, ${next?.name}, $evidenceRemovedAt)';
}

/// Reads the server fields of a stored skills map. [instant] turns the stored
/// time value into a [DateTime] (the adapter passes its own converter, so no
/// Firebase type reaches this file). Anything malformed reads as null.
SkillsServerInfo skillsServerInfoFromMap(
  Object? raw,
  DateTime? Function(Object? value) instant,
) {
  if (raw is! Map) return SkillsServerInfo.none;
  final c = raw['completeness'];
  return SkillsServerInfo(
    completeness: c is int && c >= 0 && c <= 100 ? c : null,
    next: CompletenessStepCode.fromCode(raw['completenessNext']),
    evidenceRemovedAt: instant(raw['evidenceRemovedAt'])?.toUtc(),
  );
}

/// One read of `photographers/{uid}.skills`: the client part and the
/// server's part.
class SkillsSnapshot {
  const SkillsSnapshot(this.skills, [this.server = SkillsServerInfo.none]);

  final PhotographerSkills skills;
  final SkillsServerInfo server;

  @override
  bool operator ==(Object other) =>
      other is SkillsSnapshot && other.skills == skills && other.server == server;

  @override
  int get hashCode => Object.hash(skills, server);
}
```

Replace `lib/data/skills/skills_repository.dart` with:

```dart
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

/// Reads and writes `photographers/{uid}.skills`. One-shot reads only: the
/// skills change when their owner saves them, so no screen needs a listener.
abstract class SkillsRepository {
  /// The skills ([PhotographerSkills.empty] when none are saved) and what the
  /// server wrote about them ([SkillsServerInfo.none] until scored).
  Future<SkillsSnapshot> load(String uid);

  /// Writes the client-owned part (never the server fields `completeness`,
  /// `completenessNext`, `updatedAt`, `evidenceRemovedAt` inside `skills`).
  /// Callers validate with `validateSkills` first.
  Future<void> save(String uid, PhotographerSkills skills);
}

class FakeSkillsRepository implements SkillsRepository {
  final _stored = <String, PhotographerSkills>{};
  final _server = <String, SkillsServerInfo>{};
  int loadCalls = 0;
  int saveCalls = 0;
  Object? failLoadWith;
  Object? failSaveWith;

  /// When set, [save] waits for it (a save still in flight).
  Future<void>? holdSave;

  void seed(String uid, PhotographerSkills skills) => _stored[uid] = skills;

  /// What `onPhotographerWrite` would have written; kept across [save], like
  /// the merge write keeps the server fields.
  void seedServer(String uid, SkillsServerInfo info) => _server[uid] = info;

  PhotographerSkills? stored(String uid) => _stored[uid];

  @override
  Future<SkillsSnapshot> load(String uid) async {
    loadCalls++;
    final failure = failLoadWith;
    if (failure != null) throw failure;
    return SkillsSnapshot(
      _stored[uid] ?? PhotographerSkills.empty,
      _server[uid] ?? SkillsServerInfo.none,
    );
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) async {
    saveCalls++;
    final hold = holdSave;
    if (hold != null) await hold;
    final failure = failSaveWith;
    if (failure != null) throw failure;
    _stored[uid] = skills;
  }
}
```

Replace `lib/data/skills/firestore_skills_repository.dart` with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

/// `photographers/{uid}.skills` on Firestore. The merge write keeps the
/// server's fields (`completeness`, `completenessNext`, `updatedAt`,
/// `evidenceRemovedAt`, written by `onPhotographerWrite`) and every other
/// field of the document.
class FirestoreSkillsRepository implements SkillsRepository {
  FirestoreSkillsRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  @override
  Future<SkillsSnapshot> load(String uid) async {
    final raw = (await _doc(uid).get()).data()?['skills'];
    return SkillsSnapshot(
      skillsFromMap(raw),
      skillsServerInfoFromMap(raw, _instant),
    );
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) => _doc(uid).set({
    'skills': skillsToMap(skills),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

DateTime? _instant(Object? v) => v is Timestamp ? v.toDate().toUtc() : null;
```

Replace `lib/data/skills/skills_providers.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

final skillsRepositoryProvider = Provider<SkillsRepository>(
  (ref) => FirestoreSkillsRepository(),
);

/// The skills catalogue. Built in today; a remote `taxonomy/skills` reader
/// (with this list as fallback) can override it without touching screens.
final skillCatalogProvider = Provider<TaxonomyCatalog>(
  (ref) => builtInSkillCatalog,
);

/// A photographer's skills and the server's score of them, read once while
/// a screen shows them. Invalidate this one after a save.
final photographerSkillsSnapshotProvider = FutureProvider.autoDispose
    .family<SkillsSnapshot, String>(
      (ref, uid) => ref.watch(skillsRepositoryProvider).load(uid),
      retry: (_, _) => null,
    );

/// Any photographer's skills (S03); the same single read as
/// [photographerSkillsSnapshotProvider].
final photographerSkillsProvider = FutureProvider.autoDispose
    .family<PhotographerSkills, String>(
      (ref, uid) async =>
          (await ref.watch(photographerSkillsSnapshotProvider(uid).future))
              .skills,
      retry: (_, _) => null,
    );
```

- [ ] **Step 4: The meter, the device mark and the strings**

Replace `lib/core/widgets/completeness_meter.dart` with:

```dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// "Độ khớp hồ sơ 72%" with a gradient bar and the next thing to do
/// (S38, later S30 and S22). Only the photographer sees it. The number is
/// the server's (`skills.completeness`); [percent] is null until the server
/// has scored the profile ("Chưa có điểm", empty bar).
class CompletenessMeter extends StatelessWidget {
  const CompletenessMeter({super.key, required this.percent, this.nextHint});

  final int? percent;
  final String? nextHint;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final p = percent?.clamp(0, 100);
    final value = p == null ? l.completenessNone : l.completenessPercent(p);
    final radius = BorderRadius.circular(AppRadius.full);
    return Semantics(
      container: true,
      label: l.completenessTitle,
      value: value,
      hint: nextHint,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.completenessTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          SizedBox(
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: radius,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (p ?? 0) / 100,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ctaGradientFor(theme.brightness),
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (nextHint != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              nextHint!,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
```

Replace `lib/features/skills/skills_draft_store.dart` with:

```dart
// lib/features/skills/skills_draft_store.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// The unsaved S38 draft, kept on this device so leaving the screen (or the
/// app) loses nothing. It may be incomplete; Firestore only ever gets valid
/// skills. Also remembers which evidence removal S38 already announced.
class SkillsDraftStore {
  SkillsDraftStore(this._prefs);
  final SharedPreferences _prefs;

  static String keyFor(String uid) => 'skillsDraft.$uid';

  static String evidenceSeenKeyFor(String uid) => 'skillsEvidenceSeen.$uid';

  PhotographerSkills? read(String uid) {
    final raw = _prefs.getString(keyFor(uid));
    if (raw == null) return null;
    try {
      return skillsFromMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String uid, PhotographerSkills skills) async {
    await _prefs.setString(keyFor(uid), jsonEncode(skillsToMap(skills)));
  }

  Future<void> clear(String uid) async {
    await _prefs.remove(keyFor(uid));
  }

  /// The last `skills.evidenceRemovedAt` this device told the photographer
  /// about (UTC), or null.
  DateTime? evidenceRemovedSeen(String uid) {
    final ms = _prefs.getInt(evidenceSeenKeyFor(uid));
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> markEvidenceRemovedSeen(String uid, DateTime at) async {
    await _prefs.setInt(evidenceSeenKeyFor(uid), at.millisecondsSinceEpoch);
  }
}

final skillsDraftStoreProvider = Provider<SkillsDraftStore>(
  (ref) => SkillsDraftStore(ref.watch(sharedPreferencesProvider)),
);
```

In `lib/l10n/app_vi.arb`, replace

```
  "skillsHintSpecialty": "Chọn ít nhất 1 thể loại để lên {percent}%",
  "@skillsHintSpecialty": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintEvidence": "Thêm ảnh minh chứng cho {name} để lên {percent}%",
  "@skillsHintEvidence": {"placeholders": {"name": {"type": "String"}, "percent": {"type": "int"}}},
  "skillsHintStyles": "Chọn phong cách để lên {percent}%",
  "@skillsHintStyles": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintLanguages": "Chọn ngôn ngữ để lên {percent}%",
  "@skillsHintLanguages": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintAudiences": "Chọn khách phù hợp để lên {percent}%",
  "@skillsHintAudiences": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintExtras": "Chọn kỹ năng thêm để lên {percent}%",
  "@skillsHintExtras": {"placeholders": {"percent": {"type": "int"}}},
  "skillsHintDone": "Hồ sơ kỹ năng đã đầy đủ",
```

with

```
  "skillsHintSpecialty": "Chọn ít nhất 1 thể loại",
  "skillsHintEvidence": "Thêm ảnh minh chứng cho {name}",
  "@skillsHintEvidence": {"placeholders": {"name": {"type": "String"}}},
  "skillsHintEvidenceAny": "Thêm ảnh minh chứng cho thể loại Chuyên sâu",
  "skillsHintStyles": "Chọn phong cách",
  "skillsHintLanguages": "Chọn ngôn ngữ",
  "skillsHintAudiences": "Chọn khách phù hợp",
  "skillsHintExtras": "Chọn kỹ năng thêm",
  "skillsHintDone": "Hồ sơ kỹ năng đã đầy đủ",
  "skillsFitSaveToScore": "Lưu để tính độ khớp",
  "skillsFitSaveToUpdate": "Lưu để cập nhật độ khớp",
  "skillsEvidenceRemoved": "Một số minh chứng không hợp lệ đã được gỡ",
```

and replace

```
  "completenessPercent": "{percent}%",
```

with

```
  "completenessNone": "Chưa có điểm",
  "completenessPercent": "{percent}%",
```

Run (from `app_flutter/`): `flutter gen-l10n`
Expected: no output; `lib/l10n/app_localizations.dart` now declares `String get skillsHintSpecialty;` and `String skillsHintEvidence(String name);`.

- [ ] **Step 5: Controller**

Replace `lib/features/skills/skills_controller.dart` with:

```dart
// lib/features/skills/skills_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_rules.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';
import 'package:photobooking/features/skills/skills_analytics.dart';
import 'package:photobooking/features/skills/skills_draft_store.dart';

/// [busy]: a submit is already running; this one did nothing.
enum SkillsSubmitResult { saved, invalid, failed, busy }

class SkillsEditorState {
  const SkillsEditorState({
    required this.saved,
    required this.start,
    required this.draft,
    this.restoredDraft = false,
    this.showIssues = false,
    this.issues = const [],
    this.saving = false,
    this.server = SkillsServerInfo.none,
    this.scored = PhotographerSkills.empty,
    this.evidenceRemovedNotice = false,
  });

  /// What Firestore holds.
  final PhotographerSkills saved;

  /// What the screen opened with (saved skills or the device draft).
  final PhotographerSkills start;
  final PhotographerSkills draft;

  /// The draft came from the device, not from the server.
  final bool restoredDraft;

  /// Issues are shown after the first refused "Tiếp tục".
  final bool showIssues;
  final List<SkillIssue> issues;
  final bool saving;

  /// What `onPhotographerWrite` stored when the screen opened. Never
  /// computed on the device (spec 2026-10-02 §3).
  final SkillsServerInfo server;

  /// The skills [server] describes: the saved skills at open.
  final PhotographerSkills scored;

  /// The Function removed evidence since this device last said so.
  final bool evidenceRemovedNotice;

  /// Leaving now asks "Lưu bản nháp?".
  bool get dirty => draft != start;

  /// The server does not have this draft yet.
  bool get unsaved => draft != saved;

  /// The number shown belongs to other skills than the draft: S38 keeps it
  /// and says "Lưu để cập nhật độ khớp".
  bool get scoreOutdated => draft != scored;

  bool get canSubmit => draft.specialties.isNotEmpty && !saving;

  bool hasIssue(SkillIssueCode code, {String? itemId}) =>
      showIssues &&
      issues.any(
        (i) => i.code == code && (itemId == null || i.itemId == itemId),
      );

  SkillsEditorState copyWith({
    PhotographerSkills? saved,
    PhotographerSkills? start,
    PhotographerSkills? draft,
    bool? showIssues,
    List<SkillIssue>? issues,
    bool? saving,
    bool? evidenceRemovedNotice,
  }) => SkillsEditorState(
    saved: saved ?? this.saved,
    start: start ?? this.start,
    draft: draft ?? this.draft,
    restoredDraft: restoredDraft,
    showIssues: showIssues ?? this.showIssues,
    issues: issues ?? this.issues,
    saving: saving ?? this.saving,
    server: server,
    scored: scored,
    evidenceRemovedNotice: evidenceRemovedNotice ?? this.evidenceRemovedNotice,
  );
}

/// S38/S39 editor: loads once, edits a draft (copied to the device on every
/// change), validates and saves once. No listener, no timer.
class SkillsController extends AsyncNotifier<SkillsEditorState> {
  late String _uid;
  late TaxonomyCatalog _catalog;
  late SkillsDraftStore _drafts;
  late SkillsEventLogger _log;

  @override
  Future<SkillsEditorState> build() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) throw StateError('signed_out');
    _uid = uid;
    _catalog = ref.read(skillCatalogProvider);
    _drafts = ref.read(skillsDraftStoreProvider);
    _log = ref.read(skillsAnalyticsProvider);
    final snapshot = await ref.read(skillsRepositoryProvider).load(uid);
    final saved = snapshot.skills;
    final local = _drafts.read(uid);
    final opened = local ?? _baseline(saved);
    final draft = await _withoutDeletedEvidence(opened);
    final removedAt = snapshot.server.evidenceRemovedAt;
    final seen = _drafts.evidenceRemovedSeen(uid);
    return SkillsEditorState(
      saved: saved,
      start: draft,
      draft: draft,
      restoredDraft: local != null && local != _baseline(saved),
      server: snapshot.server,
      scored: saved,
      evidenceRemovedNotice:
          removedAt != null && (seen == null || removedAt.isAfter(seen)),
    );
  }

  /// What the screen shows when there is no device draft: the saved skills,
  /// or [PhotographerSkills.initial] for a photographer with none.
  static PhotographerSkills _baseline(PhotographerSkills saved) =>
      saved.isEmpty ? PhotographerSkills.initial : saved;

  Future<PhotographerSkills> _withoutDeletedEvidence(
    PhotographerSkills s,
  ) async {
    // At most 6 genres x 3 posts; a malformed draft must not fan out more.
    final ids = s.evidencePostIds.take(18).toList();
    if (ids.isEmpty) return s;
    final posts = ref.read(postRepositoryProvider);
    try {
      final found = await Future.wait(ids.map(posts.byId));
      return withoutMissingEvidence(s, {
        for (final p in found)
          if (p != null) p.id,
      });
    } catch (_) {
      // Offline: keep the list; the server re-checks evidence.
      return s;
    }
  }

  /// S38 showed "Một số minh chứng không hợp lệ đã được gỡ": remember the
  /// removal on this device so the next open stays quiet.
  Future<void> evidenceRemovedNoticeShown() async {
    final current = state.value;
    final at = current?.server.evidenceRemovedAt;
    if (current == null || at == null || !current.evidenceRemovedNotice) {
      return;
    }
    state = AsyncData(current.copyWith(evidenceRemovedNotice: false));
    await _drafts.markEvidenceRemovedSeen(_uid, at);
  }

  SkillEdit? toggleSpecialty(String id) =>
      _apply((s) => withSpecialtyToggled(s, id, _catalog));

  SkillEdit? setLevel(String id, int level) =>
      _apply((s) => withSpecialtyLevel(s, id, level));

  SkillEdit? toggleTag(SkillGroup group, String id) =>
      _apply((s) => withTagToggled(s, group, id, _catalog));

  SkillEdit? setEvidence(String specialtyId, List<String> postIds) {
    final e = _apply((s) => withEvidence(s, specialtyId, postIds));
    if (e != null && e.accepted) {
      _log('skill_evidence_set', {
        'skillId': specialtyId,
        'count': e.skills.specialty(specialtyId)!.evidencePostIds.length,
      });
    }
    return e;
  }

  void setYears(int? years) =>
      _apply((s) => SkillEdit(withYearsExperience(s, years)));

  SkillEdit? _apply(SkillEdit Function(PhotographerSkills draft) edit) {
    final current = state.value;
    if (current == null || current.saving) return null;
    final result = edit(current.draft);
    if (!result.accepted || result.skills == current.draft) return result;
    state = AsyncData(
      current.copyWith(
        draft: result.skills,
        issues: current.showIssues
            ? validateSkills(result.skills, _catalog, previous: current.saved)
            : const [],
      ),
    );
    unawaited(
      result.skills == _baseline(current.saved)
          ? _drafts.clear(_uid)
          : _drafts.write(_uid, result.skills),
    );
    return result;
  }

  Future<SkillsSubmitResult> submit() async {
    final current = state.value;
    if (current == null) return SkillsSubmitResult.failed;
    if (current.saving) return SkillsSubmitResult.busy;
    final issues = validateSkills(
      current.draft,
      _catalog,
      previous: current.saved,
    );
    if (issues.isNotEmpty) {
      state = AsyncData(current.copyWith(showIssues: true, issues: issues));
      return SkillsSubmitResult.invalid;
    }
    if (!current.unsaved) {
      // Set before the first await so a second tap sees it (one push).
      state = AsyncData(current.copyWith(saving: true));
      await _drafts.clear(_uid);
      if (ref.mounted) {
        state = AsyncData(
          SkillsEditorState(
            saved: current.saved,
            start: current.draft,
            draft: current.draft,
            server: current.server,
            scored: current.scored,
          ),
        );
      }
      return SkillsSubmitResult.saved;
    }
    final repo = ref.read(skillsRepositoryProvider);
    state = AsyncData(
      current.copyWith(saving: true, showIssues: false, issues: const []),
    );
    try {
      await repo.save(_uid, current.draft);
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(saving: false));
      return SkillsSubmitResult.failed;
    }
    await _drafts.clear(_uid);
    _log('skills_save', {
      'specialties': current.draft.specialties.length,
      'expert': current.draft.expertCount,
    });
    if (ref.mounted) {
      state = AsyncData(
        SkillsEditorState(
          saved: current.draft,
          start: current.draft,
          draft: current.draft,
          // The Function scores the saved skills; S38 shows it next time.
          server: current.server,
          scored: current.scored,
        ),
      );
      ref.invalidate(photographerSkillsSnapshotProvider(_uid));
    }
    return SkillsSubmitResult.saved;
  }

  /// "Bỏ thay đổi": forget the device draft and go back to the saved skills.
  /// Does nothing while a save is in flight (that save wins).
  Future<void> discardDraft() async {
    if (state.value?.saving ?? false) return;
    await _drafts.clear(_uid);
    final current = state.value;
    if (current == null || current.saving || !ref.mounted) return;
    final base = _baseline(current.saved);
    state = AsyncData(
      current.copyWith(
        start: base,
        draft: base,
        showIssues: false,
        issues: const [],
      ),
    );
  }
}

final skillsControllerProvider =
    AsyncNotifierProvider.autoDispose<SkillsController, SkillsEditorState>(
      SkillsController.new,
      retry: (_, _) => null,
    );
```

- [ ] **Step 6: Screen**

In `lib/features/skills/skills_screen.dart`:

1. Add `import 'dart:async';` and an empty line above `import 'package:flutter/material.dart';`, and replace `import 'package:photobooking/data/skills/skills_completeness.dart';` with `import 'package:photobooking/data/skills/skills_server_info.dart';`.
2. In `_onLoaded`, replace the line `      if (s.restoredDraft) _snack(context.l10n.skillsDraftRestored);` with:

```dart
      final l = context.l10n;
      final messenger = ScaffoldMessenger.of(context);
      // Queued, not replacing each other: both can apply to the same open.
      if (s.restoredDraft) {
        messenger.showSnackBar(SnackBar(content: Text(l.skillsDraftRestored)));
      }
      if (s.evidenceRemovedNotice) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.skillsEvidenceRemoved)),
        );
        unawaited(_ctrl.evidenceRemovedNoticeShown());
      }
```

3. In `_content`, delete the line `    final report = s.completeness;` and replace

```dart
                    child: CompletenessMeter(
                      percent: report.percent,
                      nextHint: _hintText(l, catalog, report),
                    ),
```

with

```dart
                    child: CompletenessMeter(
                      percent: s.server.completeness,
                      nextHint: _hintText(l, catalog, s),
                    ),
```

4. Replace the whole top-level function `String _hintText(AppLocalizations l, TaxonomyCatalog catalog, CompletenessReport report) { … }` with:

```dart
/// The meter's hint (spec 2026-10-02 §3): no server number yet → save to
/// get one; the draft differs from the scored skills → save to update it;
/// otherwise the server's next step.
String _hintText(
  AppLocalizations l,
  TaxonomyCatalog catalog,
  SkillsEditorState s,
) {
  if (s.server.completeness == null) return l.skillsFitSaveToScore;
  if (s.scoreOutdated) return l.skillsFitSaveToUpdate;
  return switch (s.server.next) {
    null => l.skillsHintDone,
    CompletenessStepCode.specialties ||
    CompletenessStepCode.levels => l.skillsHintSpecialty,
    CompletenessStepCode.evidence => _evidenceHint(l, catalog, s.scored),
    CompletenessStepCode.styles => l.skillsHintStyles,
    CompletenessStepCode.languages => l.skillsHintLanguages,
    CompletenessStepCode.audiences => l.skillsHintAudiences,
    CompletenessStepCode.extras => l.skillsHintExtras,
  };
}

/// Names the first Chuyên sâu genre without posts in the scored skills.
String _evidenceHint(
  AppLocalizations l,
  TaxonomyCatalog catalog,
  PhotographerSkills scored,
) {
  for (final sp in scored.specialties) {
    if (sp.isExpert && sp.evidencePostIds.isEmpty) {
      return l.skillsHintEvidence(catalog.label(SkillGroup.specialty, sp.id));
    }
  }
  return l.skillsHintEvidenceAny;
}
```

- [ ] **Step 7: Delete the on-device score**

```bash
git rm lib/data/skills/skills_completeness.dart test/data/skills/skills_completeness_test.dart
```

- [ ] **Step 8: Run and see it pass**

Run (from `app_flutter/`): `flutter test --no-pub test/data/skills test/core/widgets/completeness_meter_test.dart test/features/skills`
Expected: `All tests passed!`.

Run: `dart format lib test && flutter analyze --no-pub && flutter test --no-pub`
Expected: `No issues found!`, then `All tests passed!` (no golden renders S38 or the meter today).

- [ ] **Step 9: Commit**

```bash
git add lib/data/skills lib/core/widgets/completeness_meter.dart lib/features/skills lib/l10n test/data/skills test/core/widgets/completeness_meter_test.dart test/features/skills
git commit -m "feat(skills): S38 shows the server's profile score; no score is computed on the device

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: CI job, deploy job, setup doc and the spec/doc updates

**Files:**
- Modify: `.github/workflows/flutter.yml`, `.github/workflows/firebase-deploy.yml`, `docs/FIREBASE-SETUP.md`, `CLAUDE.md`, `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§3e.2, §3e.3, S38 row), `docs/superpowers/specs/screens/photographer.md` (S38), `docs/superpowers/specs/components/shared-components.md` (`CompletenessMeter`), `docs/superpowers/specs/data-model/domain-model.md`, `docs/superpowers/specs/data-model/relational-schema.md`, `docs/design/ui-mock.html` (S38 hint), `docs/superpowers/plans/2026-10-01-step2d2-photographer-profile.md` (uses the deleted `skillsCompleteness`)

**Interfaces:**
- Consumes: Task 7's CI steps in `flutter.yml` (`Domain package (pure TypeScript)`, `Cloud Functions (unit + emulator integration)`, `pull_request.paths` with `packages/**`); the existing `firebase-deploy.yml` jobs `test` and `deploy` (GitHub environments `dev`/`production`, `vars.FIREBASE_PROJECT_ID`, `secrets.FIREBASE_SERVICE_ACCOUNT`, skip while the id is unset); npm scripts `typecheck`, `lint`, `test`, `test:integration` (Tasks 1, 4); Task 13's `photographerSkillsSnapshotProvider` and `CompletenessMeter(percent: int?)`.
- Produces: `flutter.yml` job `functions` (Node 22, Java 17): domain `npm ci`, typecheck, lint, test; functions `npm ci`, lint, typecheck, unit test, `test:integration` on the emulators (auth, firestore, functions). `firebase-deploy.yml`: `paths` add `packages/**` and `app_flutter/firebase/functions/**`; job `functions-test` (same checks); job `deploy-functions` (`needs: [test, functions-test]`) running `firebase deploy --only functions --project "$PROJECT_ID"` for `dev` (push `flutter-rewrite`/`develop`) and `production` (push `main`), skipped while `FIREBASE_PROJECT_ID` is unset, independent of the rules `deploy` job. `docs/FIREBASE-SETUP.md` §11.

- [ ] **Step 1: `flutter.yml`: a separate `functions` job**

In `.github/workflows/flutter.yml`, delete the two steps Task 7 added to job `test`:

```yaml
      - name: Domain package (pure TypeScript)
        working-directory: packages/domain
        run: npm ci && npm run typecheck && npm run lint && npm test
      - name: Cloud Functions (unit + emulator integration)
        working-directory: app_flutter/firebase/functions
        run: npm ci && npm run lint && npm test && npm run test:integration
```

and append this job at the end of the file (after the two `# Android build …` comment lines of job `test`, at the indentation of `test:`):

```yaml
  # Domain rules and Cloud Functions (spec 2026-10-02 §4). The emulator tests run here only,
  # never while executing plans (rule 2026-10-02).
  functions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - name: Domain package (pure TypeScript)
        working-directory: packages/domain
        run: npm ci && npm run typecheck && npm run lint && npm test
      - name: Cloud Functions (lint, typecheck, unit)
        working-directory: app_flutter/firebase/functions
        run: npm ci && npm run lint && npm run typecheck && npm test
      - name: Cloud Functions (emulator integration)
        working-directory: app_flutter/firebase/functions
        run: npm run test:integration
```

(The `pull_request.paths` line already lists `packages/**` since Task 7; `app_flutter/**` covers the functions folder.)

- [ ] **Step 2: `firebase-deploy.yml`: test and deploy the functions**

Replace the header comment and the `push` trigger

```yaml
# Deploys Firestore rules + indexes from app_flutter/firebase/ after the emulator
# rules tests pass. Storage rules deploy only on manual run.
```

with

```yaml
# Deploys Firestore rules + indexes from app_flutter/firebase/ after the emulator
# rules tests pass, and the Cloud Functions after the domain/functions tests pass
# (separate job: a functions failure never blocks the rules). Storage rules deploy
# only on manual run. Functions need the Blaze plan, the APIs and IAM roles of
# docs/FIREBASE-SETUP.md section 11.
```

and

```yaml
    paths: ['app_flutter/firebase/**', '.github/workflows/firebase-deploy.yml']
```

with

```yaml
    paths: ['app_flutter/firebase/**', 'app_flutter/firebase/functions/**', 'packages/**', '.github/workflows/firebase-deploy.yml']
```

Insert after job `test` (before `  deploy:`):

```yaml
  functions-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - name: Domain package (pure TypeScript)
        working-directory: packages/domain
        run: npm ci && npm run typecheck && npm run lint && npm test
      - name: Cloud Functions (lint, typecheck, unit, emulator integration)
        working-directory: app_flutter/firebase/functions
        run: npm ci && npm run lint && npm run typecheck && npm test && npm run test:integration

```

Append at the end of the file:

```yaml

  deploy-functions:
    needs: [test, functions-test]
    runs-on: ubuntu-latest
    environment: ${{ github.event_name == 'workflow_dispatch' && inputs.target || (github.ref_name == 'main' && 'production' || 'dev') }}
    env:
      PROJECT_ID: ${{ vars.FIREBASE_PROJECT_ID }}
    defaults:
      run:
        working-directory: app_flutter/firebase/functions
    steps:
      - name: Skip when the environment has no project
        if: ${{ env.PROJECT_ID == '' }}
        working-directory: .
        run: echo "::warning::FIREBASE_PROJECT_ID is not set for this environment; Cloud Functions not deployed."
      - uses: actions/checkout@v4
        if: ${{ env.PROJECT_ID != '' }}
      - uses: actions/setup-node@v4
        if: ${{ env.PROJECT_ID != '' }}
        with: { node-version: '22' }
      - run: npm ci
        if: ${{ env.PROJECT_ID != '' }}
      - uses: google-github-actions/auth@v2
        if: ${{ env.PROJECT_ID != '' }}
        with:
          credentials_json: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
      # predeploy (firebase.json) runs `npm run build`: typecheck + esbuild bundle with packages/domain.
      # --force lets the CLI set the Artifact Registry cleanup policy on the first deploy and remove
      # functions that are no longer in src/index.ts, without an interactive prompt.
      - name: Deploy Cloud Functions
        if: ${{ env.PROJECT_ID != '' }}
        run: >
          npx firebase deploy --config ../firebase.json --non-interactive --force
          --project "$PROJECT_ID" --only functions
```

(`working-directory: .` on the skip step: before checkout, `app_flutter/firebase/functions` does not exist yet.)

- [ ] **Step 3: Check both workflows parse and name the jobs**

Run (repo root): `ruby -ryaml -e 'a = YAML.load_file(".github/workflows/flutter.yml"); b = YAML.load_file(".github/workflows/firebase-deploy.yml"); puts a["jobs"].keys.join(","), b["jobs"].keys.join(","), b["jobs"]["deploy-functions"]["needs"].join(","), b[true]["push"]["paths"].join(",")'`
Expected:

```
test,functions
test,functions-test,deploy,deploy-functions
test,functions-test
app_flutter/firebase/**,app_flutter/firebase/functions/**,packages/**,.github/workflows/firebase-deploy.yml
```

(Ruby's YAML 1.1 reads the key `on` as `true`.) Run: `grep -c "test:integration" .github/workflows/flutter.yml .github/workflows/firebase-deploy.yml`
Expected: `.github/workflows/flutter.yml:1` and `.github/workflows/firebase-deploy.yml:1`.

- [ ] **Step 4: `docs/FIREBASE-SETUP.md`**

In section 10, replace

```markdown
Workflow `.github/workflows/firebase-deploy.yml` có 2 job: `test` chạy `npm test` trên emulator, `deploy` chỉ chạy khi test pass.
```

with

```markdown
Workflow `.github/workflows/firebase-deploy.yml` có 4 job: `test` chạy test rules trên emulator, `deploy` (rules và indexes) chỉ chạy khi `test` pass; `functions-test` chạy test của `packages/domain` và Cloud Functions (cả test emulator), `deploy-functions` chỉ chạy khi `test` và `functions-test` pass (điều kiện riêng ở mục 11). Hai job deploy độc lập: functions lỗi không chặn deploy rules.
```

and add this row at the end of the first table of section 10 (after the "Chạy tay" row):

```markdown
| Push hoặc chạy tay như trên, khi có thay đổi trong `app_flutter/firebase/**` hoặc `packages/**` | như trên | Cloud Functions (`getContactLink`, `onPhotographerWrite`), job `deploy-functions` |
```

Insert before `## Sự cố thường gặp`:

```markdown
## 11. Cloud Functions (deploy qua CI)

Job `deploy-functions` deploy codebase `app_flutter/firebase/functions` (region `asia-southeast1`: `getContactLink`, `onPhotographerWrite`) bằng `firebase deploy --only functions`. Không deploy từ máy. Làm các bước dưới đây một lần cho mỗi project: **dev** ngay, **production** khi đã có project.

1. **Gói Blaze.** Firebase Console → ⚙ → **Usage and billing** → **Details & settings** → **Modify plan** → **Blaze**. Cloud Functions không chạy trên gói Spark. Nên đặt budget alert (ví dụ 5 USD) trong Google Cloud Billing.
2. **Bật API** tại `https://console.cloud.google.com/apis/library?project=<project-id>`: Cloud Functions API, Cloud Build API, Artifact Registry API, Eventarc API, Cloud Run Admin API. Service account của CI không có quyền bật API, nên bật trước bằng tay.
3. **Thêm role cho service account CI** (`github-firebase-deploy`, mục 10.1) ở trang IAM `https://console.cloud.google.com/iam-admin/iam?project=<project-id>`:

   | Role | Để làm gì |
   |------|-----------|
   | Cloud Functions Developer (`roles/cloudfunctions.developer`) | Tạo và cập nhật function |
   | Service Account User (`roles/iam.serviceAccountUser`) | Cho function chạy bằng service account mặc định |
   | Artifact Registry Writer (`roles/artifactregistry.writer`) | Lưu image build của function |
   | Cloud Run Admin (`roles/run.admin`) | Function thế hệ 2 chạy trên Cloud Run |
   | Eventarc Admin (`roles/eventarc.admin`) | Tạo trigger Firestore của `onPhotographerWrite` |

4. **Chạy thử**: **Run workflow** như 10.3. Kiểm tra: job `deploy-functions` xanh; Console → **Functions** có `getContactLink` và `onPhotographerWrite` ở `asia-southeast1`. Trong app, sửa kỹ năng ở S38 rồi lưu, mở lại S38: "Độ khớp hồ sơ" hiện số do server ghi (trước lần lưu đầu tiên là "Chưa có điểm").

Workflow chạy với `--force` để Firebase CLI tự đặt chính sách dọn image cũ trong Artifact Registry ở lần deploy đầu và xoá function không còn trong `src/index.ts`. Thiếu điều kiện nào thì chỉ job `deploy-functions` đỏ, kèm thông báo của Firebase CLI; job `deploy` (rules) không bị ảnh hưởng.

| Lỗi trong log | Cách sửa |
|---------------|----------|
| `must be on the Blaze (pay-as-you-go) plan` | Bước 1. |
| `... API has not been used in project ... or it is disabled` | Bật API được nêu (bước 2), chờ vài phút rồi chạy lại. |
| `Permission 'cloudfunctions.functions.create' denied`, `iam.serviceAccounts.actAs`, `artifactregistry...`, `run.services...`, `eventarc.triggers...` | Thiếu role tương ứng (bước 3). |
| `Since this is your first time using 2nd gen functions, we need a little bit longer to finish setting everything up` | Lần đầu dùng Eventarc: chờ vài phút rồi chạy lại. |

```

In the last section ("Test rules không cần project thật"), replace

```markdown
CI (`.github/workflows/flutter.yml`) cũng chạy bước này cho mọi PR.
```

with

```markdown
CI (`.github/workflows/flutter.yml`) cũng chạy bước này cho mọi PR, cùng job `functions` (test của `packages/domain` và Cloud Functions, kể cả test trên emulator). Test emulator chỉ chạy trên CI.
```

- [ ] **Step 5: `CLAUDE.md`**

In the last paragraph of "### Commands (run from `app_flutter/`)", replace

```text
deploys Firestore to GitHub environment `dev`
```

with

```text
deploys Firestore and the Cloud Functions (job `deploy-functions`, after the domain and functions tests; the project must be on Blaze) to GitHub environment `dev`
```

and replace

```text
`docs/FIREBASE-SETUP.md` (sections 6, 9, 10)
```

with

```text
`docs/FIREBASE-SETUP.md` (sections 6, 9, 10, 11)
```

- [ ] **Step 6: Spec updates (spec 2026-10-02 §6)**

Each item is one exact replacement (old text, then new text).

`docs/superpowers/specs/2026-10-01-remaining-screens.md`, §3e.2:

```text
Do Function tính, chỉ để nhắc nhiếp ảnh gia; không hiện cho khách.
```

```text
Do Function `onPhotographerWrite` tính (app không tính), lưu cùng `completenessNext` (mã bước còn thiếu đầu tiên: `specialties | levels | evidence | styles | languages | audiences | extras`, `null` khi đủ 100); chỉ để nhắc nhiếp ảnh gia; không hiện cho khách.
```

Same file, §3e.3 code block, the line

```text
  completeness: 72            # Function tính
```

becomes

```text
  completeness: 72            # Function tính
  completenessNext: "audiences"  # Function ghi; null khi đủ 100
  evidenceRemovedAt           # Function ghi khi gỡ minh chứng không hợp lệ
```

Same file, §3e.3 first bullet, two replacements:

```text
(trừ `completeness`, `updatedAt` do Function ghi)
```

```text
(trừ `completeness`, `completenessNext`, `updatedAt`, `evidenceRemovedAt` do Function ghi)
```

and

```text
client không ghi các trường do server sở hữu (`completeness`, `skills.updatedAt`).
```

```text
client không ghi các trường do server sở hữu (`completeness`, `completenessNext`, `skills.updatedAt`, `evidenceRemovedAt`).
```

Same file, §3e.3 second bullet:

```text
Kiểm quyền sở hữu minh chứng và tính `completeness` sẽ do Function `onPhotographerWrite` làm (đang thiết kế, **chưa xây**); đến lúc đó app hiện điểm tính trên máy cùng công thức.
```

```text
Function `onPhotographerWrite` kiểm quyền sở hữu minh chứng (gỡ id không phải bài còn sống của chính họ, hạ "Chuyên sâu" không còn minh chứng xuống "Thành thạo", ghi `evidenceRemovedAt`) và tính `completeness`; app không tính điểm (spec `2026-10-02-photographer-write-function-design.md`).
```

Same file, §3e.3 third bullet (whole line):

```text
- Function `onPhotographerWrite` (chưa xây) sẽ kiểm tra lược đồ, kiểm `evidencePostIds` thuộc bài của chính họ, tính `completeness`, rồi báo dịch vụ gợi ý cập nhật chỉ mục (3e.4).
```

```text
- Function `onPhotographerWrite` (Firestore trigger `photographers/{uid}`, `asia-southeast1`; backend phase 1, Task 10–14) đọc lược đồ bằng `parseSkills` (`packages/domain`), kiểm `evidencePostIds` bằng một lần `getAll`, tính `completeness`/`completenessNext`, ghi một lần với precondition `lastUpdateTime`; bỏ qua lần ghi chỉ đổi trường server. Báo dịch vụ gợi ý cập nhật chỉ mục (3e.4) để plan recommender.
```

Same file, code table row S38:

```text
`skills.completeness` cập nhật sau khi lưu. |
```

```text
`skills.completeness` do Function tính sau khi lưu; S38 hiện số đó ở lần mở sau. |
```

`docs/superpowers/specs/screens/photographer.md`, S38 **Dữ liệu**:

```text
Độ khớp hồ sơ tính ngay trên máy bằng đúng công thức 3e.2 (`skillsCompleteness`); khi có Function `onPhotographerWrite` thì Function ghi `completeness` theo cùng công thức.
```

```text
Độ khớp hồ sơ và bước kế tiếp do Function `onPhotographerWrite` tính (`skills.completeness`, `skills.completenessNext`); app chỉ hiện số đã lưu: chưa có số → "Chưa có điểm" + "Lưu để tính độ khớp"; nháp khác bản đã lưu → giữ số, gợi ý "Lưu để cập nhật độ khớp"; còn lại gợi ý theo `completenessNext` (không kèm "để lên N%", vì server không lưu số sau bước đó). Khi Function gỡ minh chứng không hợp lệ (`skills.evidenceRemovedAt` mới hơn mốc `skillsEvidenceSeen.<uid>` trên máy), lần mở S38 kế tiếp báo "Một số minh chứng không hợp lệ đã được gỡ" một lần.
```

`docs/superpowers/specs/components/shared-components.md`:

```text
`CompletenessMeter({required int percent, String? nextHint})`. Hàng tiêu đề + phần trăm, thanh gradient, dòng gợi ý việc kế tiếp. Dùng ở S38, S30, S22.
```

```text
`CompletenessMeter({required int? percent, String? nextHint})`. Hàng tiêu đề + phần trăm, thanh gradient, dòng gợi ý việc kế tiếp. `percent` là số server ghi (`skills.completeness`); `null` (chưa tính) hiện "Chưa có điểm" và thanh rỗng. Dùng ở S38, S30, S22.
```

`docs/superpowers/specs/data-model/domain-model.md`, row `PhotographerStats`:

```text
`nextFreeDate?`, `skillsCompleteness` |
```

```text
`nextFreeDate?`, `skillsCompleteness`, `skillsCompletenessNext?` (mã bước còn thiếu đầu tiên), `skillsEvidenceRemovedAt?` (lần Function gỡ minh chứng gần nhất) |
```

`docs/superpowers/specs/data-model/relational-schema.md`, the line

```text
  skills_completeness  smallint not null default 0 check (skills_completeness between 0 and 100),
```

becomes

```text
  skills_completeness  smallint not null default 0 check (skills_completeness between 0 and 100),
  skills_completeness_next text check (skills_completeness_next in ('specialties', 'levels', 'evidence', 'styles', 'languages', 'audiences', 'extras')),
  skills_evidence_removed_at timestamptz,
```

and in its mapping table

```text
`skills.completeness`→`skills_completeness` |
```

```text
`skills.completeness`→`skills_completeness`; `skills.completenessNext`→`skills_completeness_next`; `skills.evidenceRemovedAt`→`skills_evidence_removed_at` |
```

`docs/design/ui-mock.html`, S38 meter hint (the hint no longer carries a number; this spec is newer than the mock):

```text
Thêm ảnh minh chứng cho Chân dung để lên 85%
```

```text
Thêm ảnh minh chứng cho Chân dung
```

- [ ] **Step 7: Plan 2d2 reads the server score**

Plan 2d2 (runs after this plan) still uses the deleted `skillsCompleteness`. In `docs/superpowers/plans/2026-10-01-step2d2-photographer-profile.md`, make these exact replacements (old, then new):

1. In the S03 header widget's import block, delete the line

```text
import 'package:photobooking/data/skills/skills_completeness.dart';
```

2. Add a line after

```text
    final skills = ref.watch(photographerSkillsProvider(s.id)).value ?? PhotographerSkills.empty;
```

so it reads

```text
    final skills = ref.watch(photographerSkillsProvider(s.id)).value ?? PhotographerSkills.empty;
    final skillsScore = ref.watch(photographerSkillsSnapshotProvider(s.id)).value?.server.completeness;
```

3. ```text
                CompletenessMeter(percent: skillsCompleteness(skills).percent),
   ```
   ```text
                CompletenessMeter(percent: skillsScore),
   ```

4. ```text
      ..invalidate(photographerSkillsProvider(widget.uid));
   ```
   ```text
      ..invalidate(photographerSkillsSnapshotProvider(widget.uid));
   ```

5. Task 7 **Interfaces**:
   ```text
`photographerSkillsProvider`, `skillsCompleteness`, `CompletenessMeter`
   ```
   ```text
`photographerSkillsProvider`, `photographerSkillsSnapshotProvider` (server score, backend phase 1 Task 13), `CompletenessMeter`
   ```
   and
   ```text
(device-computed `skillsCompleteness`)
   ```
   ```text
(server `skills.completeness`; "Chưa có điểm" until the Function has scored)
   ```

6. Task 7 Step 3:
   ```text
`package:photobooking/data/skills/skills_completeness.dart`, 
   ```
   (with its trailing space) → nothing.

7. `_SkillsTile.build`:
   ```text
    final skills = ref.watch(photographerSkillsProvider(uid)).value;
   ```
   ```text
    final skills = ref.watch(photographerSkillsSnapshotProvider(uid)).value;
   ```
   then
   ```text
              child: CompletenessMeter(percent: skillsCompleteness(skills).percent),
   ```
   ```text
              child: CompletenessMeter(percent: skills.server.completeness),
   ```
   then
   ```text
          ref.invalidate(photographerSkillsProvider(uid));
   ```
   ```text
          ref.invalidate(photographerSkillsSnapshotProvider(uid));
   ```

8. Header lines listing the consumed 2c names:
   ```text
`skillsCompleteness(PhotographerSkills).percent`, `CompletenessMeter({required int percent, String? nextHint})`
   ```
   ```text
`photographerSkillsSnapshotProvider` → `SkillsSnapshot.server.completeness` (backend phase 1 Task 13), `CompletenessMeter({required int? percent, String? nextHint})`
   ```
   and
   ```text
`skillsCompleteness`/`CompletenessMeter`
   ```
   ```text
`photographerSkillsSnapshotProvider`/`CompletenessMeter`
   ```

Run (repo root): `grep -n "skillsCompleteness\|skills_completeness" docs/superpowers/plans/2026-10-01-step2d2-photographer-profile.md docs/superpowers/specs/screens/photographer.md docs/superpowers/specs/2026-10-01-remaining-screens.md; grep -c "để lên" docs/design/ui-mock.html`
Expected: the first grep prints nothing, then `0`.

- [ ] **Step 8: Commit**

```bash
git add .github/workflows/flutter.yml .github/workflows/firebase-deploy.yml docs/FIREBASE-SETUP.md CLAUDE.md docs/superpowers/specs docs/design/ui-mock.html docs/superpowers/plans/2026-10-01-step2d2-photographer-profile.md
git commit -m "ci(functions): test and deploy Cloud Functions; docs for onPhotographerWrite and the server score

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

After the push, CI must show job `functions` green (domain, unit and the emulator tests of Tasks 6, 11) and, on `firebase-deploy`, `functions-test` green; `deploy-functions` deploys to `dev` once §11 is done, or prints the `FIREBASE_PROJECT_ID is not set` warning. Record the CI run URL in the ledger.
