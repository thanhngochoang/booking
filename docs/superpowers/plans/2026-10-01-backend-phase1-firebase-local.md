# Local Backend, Phase 1: Firebase Emulator Suite + Cloud Functions (TypeScript) Implementation Plan

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

### Task 9: Performance check

**Files:**
- Create: `app_flutter/firebase/functions/test/perf/get_contact_link.perf.test.ts`, `app_flutter/test/data/backend/backend_call_budget_test.dart`
- Modify: `app_flutter/README.md` (budget table)

**Interfaces:**
- Consumes: everything above; npm script `test:perf` (Task 4).
- Produces: the budgets below, asserted where they can be measured locally.

| What | Measured where | Budget | When |
|---|---|---|---|
| Firestore reads per `getContactLink` | domain test (fakes) + emulator read-count test (real adapters) | unlocked ≤ 3 documents in ≤ 2 round trips; refused at the subject: 1 document, 1 round trip; malformed: 0 | now (Tasks 3, 6) |
| Firestore writes per call | integration + perf | exactly 1 (`ContactAccessLog`) per well-formed request, also under 10 concurrent calls; 0 for malformed | now |
| Request / response size | perf test | ≤ 128 bytes each (measured: request 63 B, response 48 B) | now |
| Bundle `lib/index.js` | perf test | < 150 KB, Firebase SDKs external (measured: about 10 KB) | now |
| Emulator latency, warm p95 | perf test | < 500 ms (measured: p95 about 14 ms). Smoke budget only: catches an extra round trip, a sleep or a heavy import; the emulator has no network hop and no cold-start isolation, so it says nothing about production | now |
| Emulator first call | perf test | < 5 s (measured: about 0.6 s, worker start) | now |
| Production warm p95 (server execution) | Cloud Monitoring, cloud deploy plan | < 300 ms | later |
| Production end-to-end p95 from a Vietnamese phone | client trace, cloud deploy plan | < 600 ms | later |
| Cold start | Cloud Monitoring, cloud deploy plan | p95 < 2.5 s; `minInstances: 0` at launch; set `minInstances: 1` on `getContactLink` only if cold starts exceed 5 % of calls | later |
| Region | `CALLABLE_OPTIONS.region`, client `functionsRegion` (tests compare both) | `asia-southeast1`; the Firestore database should be in the same region (check in the cloud deploy plan) | now |
| Client | Flutter tests below + 2b `ContactLauncher` | one `getContactLink` call per tap, no prefetch, no polling, no automatic retry; 10 s client timeout = server timeout | now |

- [ ] **Step 1: Write the budget tests**

```ts
// app_flutter/firebase/functions/test/perf/get_contact_link.perf.test.ts
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { statSync } from 'node:fs';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { LAN, SEED_PASSWORD } from '../../seed/fixtures.js';

// Local smoke budgets. The emulator runs the function in a local Node worker with no network hop,
// so these numbers only catch regressions (an extra round trip, a sleep, a heavy import);
// production latency and cold starts are measured in the cloud deploy plan.
const LOCAL_FIRST_CALL_MS = 5_000;
const LOCAL_WARM_P95_MS = 500;
const WARM_CALLS = 50;
const MAX_PAYLOAD_BYTES = 128;
const MAX_BUNDLE_BYTES = 150_000;
const DATA = { bookingId: 'seed-booking-accepted', channel: 'zalo' };

let app: App;
let db: Firestore;
let token: string;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'perf-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  token = await signIn('lan.customer@seed.test', SEED_PASSWORD);
});
after(async () => {
  await deleteApp(app);
});

const percentile = (sorted: number[], p: number): number =>
  sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)] ?? Number.NaN;

test('latency on the emulator stays inside the smoke budget', async () => {
  const t0 = performance.now();
  const first = await callCallable('getContactLink', DATA, token);
  const firstMs = performance.now() - t0;
  assert.equal(first.status, 200, first.text);
  for (let i = 0; i < 5; i++) await callCallable('getContactLink', DATA, token);
  const samples: number[] = [];
  for (let i = 0; i < WARM_CALLS; i++) {
    const start = performance.now();
    const res = await callCallable('getContactLink', DATA, token);
    samples.push(performance.now() - start);
    assert.equal(res.status, 200, res.text);
  }
  samples.sort((a, b) => a - b);
  const p50 = percentile(samples, 50);
  const p95 = percentile(samples, 95);
  console.log(`getContactLink (emulator): first ${firstMs.toFixed(0)} ms, p50 ${p50.toFixed(0)} ms, p95 ${p95.toFixed(0)} ms over ${WARM_CALLS} warm calls`);
  assert.ok(firstMs < LOCAL_FIRST_CALL_MS, `first call ${firstMs.toFixed(0)} ms`);
  assert.ok(p95 < LOCAL_WARM_P95_MS, `p95 ${p95.toFixed(0)} ms`);
});

test('request and response stay tiny', async () => {
  const requestBytes = Buffer.byteLength(JSON.stringify({ data: DATA }));
  const res = await callCallable('getContactLink', DATA, token);
  const responseBytes = Buffer.byteLength(res.text);
  console.log(`getContactLink payload: request ${requestBytes} B, response ${responseBytes} B`);
  assert.ok(requestBytes <= MAX_PAYLOAD_BYTES, `${requestBytes} B`);
  assert.ok(responseBytes <= MAX_PAYLOAD_BYTES, `${responseBytes} B`);
});

test('exactly one log write per call, also under 10 concurrent calls', async () => {
  const count = async () =>
    (await db.collection('contact_access_log').where('requesterId', '==', LAN).count().get()).data().count;
  const before = await count();
  const results = await Promise.all(Array.from({ length: 10 }, () => callCallable('getContactLink', DATA, token)));
  for (const r of results) assert.equal(r.status, 200, r.text);
  assert.equal(await count(), before + 10);
});

test('the bundle stays small for fast cold starts', () => {
  const bytes = statSync('lib/index.js').size;
  console.log(`lib/index.js: ${bytes} B (firebase-admin and firebase-functions are external)`);
  assert.ok(bytes < MAX_BUNDLE_BYTES, `${bytes} B`);
});
```

```dart
// test/data/backend/backend_call_budget_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('getContactLink is called from one data adapter at most', () {
    final callers = _dartFiles('lib')
        .where((f) => f.readAsStringSync().contains("'getContactLink'"))
        .map((f) => f.path)
        .toList();
    expect(callers.length, lessThanOrEqualTo(1), reason: '$callers');
    for (final path in callers) {
      expect(path, startsWith('lib/data/'));
    }
  });

  test('nothing that talks to callables or the contact link polls', () {
    final polling = RegExp(r'Timer\.periodic|Stream\.periodic');
    final offenders = _dartFiles('lib')
        .where((f) {
          final s = f.readAsStringSync();
          final talksToServer =
              s.contains('httpsCallable') ||
              s.contains('ContactLinkRepository') ||
              s.contains('ContactLauncher');
          return talksToServer && polling.hasMatch(s);
        })
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run and record**

This task measures code that already exists, so these tests are guards and are expected to pass on the first run. If one fails, it is a real regression: fix the code, not the budget.

Run (from `app_flutter/firebase/functions`, outside the sandbox): `npm run test:perf`
Expected (numbers from a dry run on an Apple-silicon Mac; yours will differ but must stay inside the budgets):

```
getContactLink (emulator): first 604 ms, p50 12 ms, p95 14 ms over 50 warm calls
getContactLink payload: request 63 B, response 48 B
lib/index.js: 10414 B (firebase-admin and firebase-functions are external)
ℹ tests 4
ℹ pass 4
ℹ fail 0
```

Run (from `app_flutter/`): `flutter test test/data/backend`
Expected: PASS (9 tests: 7 from Task 8, 2 here).

If plan 2b is done, also run `flutter test test/data/contact` and confirm its launcher tests still assert one `FakeContactLinkRepository.requests` entry per open (one call per tap).

- [ ] **Step 3: Write the budgets down**

Append to the "Local backend (Firebase Emulator Suite)" section of `app_flutter/README.md`:

```markdown
### Performance budgets (getContactLink)

| What | Budget | Checked by |
|---|---|---|
| Firestore reads | ≤ 3 documents in ≤ 2 round trips (locked: 1) | `packages/domain` tests, `test/integration/read_budget.test.ts` |
| Firestore writes | exactly 1 `contact_access_log` row per well-formed call | integration + perf tests |
| Payload | request and response ≤ 128 B | `npm run test:perf` |
| Bundle | `lib/index.js` < 150 KB | `npm run test:perf` |
| Emulator warm p95 | < 500 ms (smoke only, not a production number) | `npm run test:perf` |
| Production warm p95 / cold start | < 300 ms / < 2.5 s, `minInstances: 0` until measured | cloud deploy plan (Cloud Monitoring) |
| Client | one call per tap, no polling, 10 s timeout, region `asia-southeast1` | `test/data/backend/*` |
```

- [ ] **Step 4: Commit**

```bash
git add app_flutter/firebase/functions/test/perf app_flutter/test/data/backend/backend_call_budget_test.dart app_flutter/README.md
git commit -m "perf(functions): getContactLink read, write, payload, bundle and latency budgets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Goal coverage:** one command with import/export, watch build and first-run seed (Task 7); all emulators plus UI configured in the existing `firebase.json` (Task 4); seed with verified/unverified photographers, contact flags, private numbers, a customer with and one without a phone, and accepted/requested/cancelled/completed bookings (Task 5); debug app wiring for Android emulator, Genymotion, iOS Simulator and real devices, with debug-only Android cleartext, iOS `NSAllowsLocalNetworking` and platform-file tests (Task 8); `getContactLink` (Tasks 2–3 rules, 4 plumbing, 6 wiring) and reusable `makeRequirePhone` (Tasks 2, 6) with tests; performance budgets (Task 9); docs, `CLAUDE.md` and CI (Task 7). Later plans are listed in "Out of scope".
- **Contract match with plan 2b:** request `{bookingId | registrationId, channel: call|zalo|whatsapp}` (`parseContactLinkRequest`, strict); response `{url}` only (handler and integration test check the whole body); URLs byte-identical to `contactUriFor`, including `zaloPhone ?? phone`, `whatsappPhone ?? phone`, `wa.me` without `+` (domain tests plus a TS port of `isAllowedContactUri`); errors with `details.code` and message `contact_locked` for locked, `permission_denied` / `not_found` / `invalid_argument` otherwise (`linkErrorFromCode` maps all of them to "unavailable"); unlock window identical to `contactAccessForBooking` (30 days inclusive, unknown completion locked, `reviewed` included); one `ContactAccessLog` row per well-formed request with `granted` true or false; no number logged.
- **Placeholders:** none. Every file is given in full; the only conditional step is the 2b adapter edit in Task 8, which also updates 2b's plan text and is guarded by a test either way.
- **Type consistency:** `GetContactLinkDeps`, `BookingRecord`, `RegistrationRecord`, `PhotographerContact`, `ContactAccessLogEntry`, `CallableInput`, `CALLABLE_OPTIONS`, `REGION`/`functionsRegion`, `EmulatorConfig` ports and the seed ids are named identically in code, tests, README and the plan tables.
- **Verified, not assumed:** the expected outputs (test counts 25/41/53, 15/21 unit, 15 integration, 4 perf, the 404 text, the callable error body, the export/import log lines, the measured latencies and sizes) come from a dry run of this exact code in a scratch copy of the repo layout, with the existing `firestore.rules` and rules tests passing against the new `firebase.json`. That dry run is also how two traps were found and fixed in the plan: `set -e` aborting on `scripts/env.sh`, and the Functions emulator's Unix socket being blocked by the Claude sandbox. The Dart emulator APIs and their `automaticHostMapping` parameters were checked in the sources of cloud_firestore 6.10.0, firebase_auth 6.7.0, cloud_functions 6.5.0 and firebase_storage 13.6.0; the Dart code of Task 8/9 was not compiled in the dry run.
- **Risks to watch:** (1) Using the app's real project id with the emulators: safe while every SDK is routed locally (seed guard, debug-only wiring); firebase-tools prints "You are not currently authenticated" and is fine without a login. If a developer needs a `demo-*` id, the app cannot follow on Android (native auto-init), so keep the default. (2) `firebase-functions` 7 / `firebase-admin` 14 exist; upgrading belongs to the cloud deploy plan together with a newer `firebase-tools`. (3) The functions bundle relies on esbuild resolving the `paths` alias; `npm run build` fails loudly if it does not, and the deployable `lib/index.js` never references `packages/`. (4) Cloud deploy is not exercised here: `predeploy` builds, but App Check, IAM and the Firestore database location are decided in the cloud plan. (5) A real iPhone over the LAN shows the local-network permission prompt; refusing it blocks the emulators until it is re-enabled in Settings.
