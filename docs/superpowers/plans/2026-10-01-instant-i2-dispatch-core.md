# Instant booking I2: `packages/dispatch-core` (pure dispatch domain) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure TypeScript package `packages/dispatch-core` holds every business rule of "Chụp ngay": the request state machine, the offer round and radius policy, eligibility tiers, scoring with reasons, the ETA estimate, pricing with surge, and the cancellation / no-show money table, all driven by one configuration object with per-city overrides. It has no I/O and no infrastructure import (enforced by a purity test and lint), takes time and randomness as parameters, and is proven by unit and property tests plus micro-benchmarks. Plan I3 (`services/dispatch`) runs these rules; it never re-implements them.

**Architecture:** Same shape as backend phase 1's `packages/domain`: ESM package, no runtime dependencies, `node:test` run through `tsx`, ESLint 9 with `no-restricted-imports`, a purity test that scans `src/`. Modules are small and layered: `types` (wire codes copied from the contract) → `config` (all tunables, validated, per-city merge) → `state-machine`, `geo`, `pricing` → `cancellation`, `eligibility`, `scoring` → `matcher` (rank candidates) and `rounds` (when to widen, switch round or give up) → `arrival`, `stats`. Money is integer VND and ratios are basis points, so no rule uses floating point for money. The service consumes the barrel `src/index.ts` through one shim file (`services/dispatch/src/domain/core.ts`, plan I3), exactly like phase 2 consumes `packages/domain`.

**Tech Stack:** Node 22+, TypeScript 5.9 strict (`noUncheckedIndexedAccess`, `verbatimModuleSyntax`), ESLint 9 + typescript-eslint 8, `node:test` through `tsx` 4, no runtime dependency. Same versions as `packages/domain` (backend phase 1, Task 1).

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (§2 flows, §3.1 state machine, §3.2 rounds, tiers, score, ETA, §4 prices and the cancellation table, §9 presence TTL, §10 edge cases, §11 "Domain (unit, không hạ tầng)"); `services/dispatch/api/openapi.yaml` (enums `InstantRequestStatus`, `Genre`, `PackageCode`, `CancelRule`, `DeclineReason`, `PaymentProvider`, eligibility reasons, `ErrorCode`); `docs/superpowers/specs/data-model/README.md` §2 (ids, UTC, integer VND with floor rounding, string enums, error codes); `docs/superpowers/specs/data-model/domain-model.md` §4 (`ErrorCode`), §6 (invariants); `docs/superpowers/specs/data-model/relational-schema.md` §2.8 (`instant_offers.score numeric(5,4)`, `reasons jsonb`, the one-open-job index); `services/recommender/README.md` and main spec §3e.4–§3e.6 (the `Scorer` shape and rules-v1 smoothing reused here).

**Prerequisite:** `docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md` Task 1 is done (it establishes `packages/` as the home of pure TypeScript packages and the tooling copied here). Nothing else: this package imports nothing from `packages/domain` or `packages/recommender-core`.

## Key decisions

| # | Question | Decision | Why |
|---|---|---|---|
| 1 | Package location and name | `packages/dispatch-core`, npm name `@photobooking/dispatch-core` | Spec §5 and `services/dispatch/README.md` name it; sibling of `packages/domain` (phase 1). |
| 2 | Dependency on `packages/domain` / `recommender-core` | None | `recommender-core` does not exist yet and must not block dispatch; `packages/domain` error codes lack the instant codes. The scorer implements the same `Scorer` shape (named, versioned, components in 0..1, reasons) so the two can be merged later without changing callers. |
| 3 | Time and randomness | Every rule takes `now: Date` (or a `Clock`) and an optional `Rng`; only `src/clock.ts` touches `Date`/`Math.random` | Deterministic tests; the purity test enforces it. |
| 4 | Money maths | Integer VND, ratios in basis points (`payoutRateBps: 8000`), surge in hundredths (`1.20` → `120`); shares are `floor(amount × bps / 10000)` and the remainder goes to the other party | data-model README §2.3 ("làm tròn xuống… phần dư thuộc phần còn lại"); spec §4 "không lệch 1 ₫". |
| 5 | Price rounding | `amount = round_half_up(base × surge, 1,000 ₫)`, never below 1,000 ₫ | Spec §4 "làm tròn tới 1.000 ₫"; half-up is the usual retail rounding. |
| 6 | Round 2 start | At the 5-minute mark, or earlier as soon as round 1 has found nobody even at 10 km (only when `expand`); round 2 lasts ≤ 5 minutes and the whole search ≤ 10 minutes | Spec §3.2 limits ("tối đa 5 phút", "tổng 10 phút") without making a customer who ticked "Mở rộng" wait 5 minutes for nothing. |
| 7 | Radius growth | Only when the matcher finds no eligible, unexcluded candidate at the current radius; never shrinks | Spec §3.2 "mỗi khi hết người trong bán kính hiện tại". |
| 8 | Not-enough-data fallbacks | Quality bar waives the rating check below 5 reviews and the cancel-rate check below 10 jobs (then only "verified" counts); `genreMatch` = 0.5 when no skills data exists; rating and reliability components are Bayesian-smoothed toward priors | Spec §3.2 "chưa đủ dữ liệu thì chỉ cần đã xác minh"; same smoothing as rules-v1 (§3e.6). |
| 9 | Ties | Higher score, then shorter ETA, then a random key from the injected `Rng`, then uid | Fair rotation between equal photographers; deterministic under a seeded `Rng`. |
| 10 | Initial ETA for the lateness rule | The ETA the accepted offer was scored with, kept in the offer's `near` reason (`etaMinutes`) | `instant_offers.reasons jsonb` already stores it; §2.8 has no ETA column and the DDL is used verbatim. |

## Global Constraints

- **Commands:** from the repo root, once per shell: `source scripts/env.sh >/dev/null && export HOME="$PWD/.home"`, then `cd packages/dispatch-core`. Node ≥ 22 (`node -v`).
- **Sandbox notes (Claude Code):** `npm install` needs `registry.npmjs.org`. The `tsx` CLI opens an IPC pipe that the sandbox refuses (`listen EPERM … tsx-*.pipe`); every script here uses `node --import tsx` instead, which works inside the sandbox. This plan's code was run in a scratch copy with Node 24: `npm run typecheck`, `npm run lint`, `npm test` (284 tests) and `npm run bench` all pass.
- **Purity:** nothing in `src/` imports anything but its own modules (no `node:*`, Redis, PostgreSQL, Firebase, HTTP clients); no `Date.now()`, `new Date()`, `Math.random()`, `performance.now()`, timers, `fetch` or `process` outside `src/clock.ts`; no runtime `dependencies`. Enforced by `test/purity.test.ts` and `eslint.config.js`.
- **Wire codes are the contract's:** every enum string equals `services/dispatch/api/openapi.yaml` (tested literally in Task 1). Money is integer VND; instants are `Date` (UTC); ratios are basis points; surge is hundredths.
- **Invariant:** for every quote and settlement, `refundVnd + photographerVnd + platformVnd = collectedVnd`, all non-negative safe integers (property test over ~20,000 amounts per rule, Task 6).
- **No business rule outside this package:** plan I3 imports these functions through `services/dispatch/src/domain/core.ts` only. A missing rule is added here with its test, never in the service.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `packages/dispatch-core/package.json`, `tsconfig.json`, `eslint.config.js`, `.gitignore` (create) | Pure package tooling; lint bans infrastructure imports, timers, `fetch`, `process` in `src/` |
| `src/types.ts` (create) | Contract enums (`InstantRequestStatus`, `Genre`, `PackageCode`, `CancelRule`, `DeclineReason`, `EligibilityReason`, `OfferOutcome`, `PaymentProvider`), `Round`, `LatLng`, `GENRE_SPECIALTY`, guards |
| `src/errors.ts` (create) | `DISPATCH_ERROR_CODES`, `DispatchError` |
| `src/clock.ts` (create) | `Clock`, `Rng`, `systemClock`, `systemRng`, `manualClock`, `seededRng`, `addMs` |
| `src/config.ts` (create) | `DispatchConfig`, `DEFAULT_CONFIG`, `ConfigBook`, `configForCity`, `validateConfig`, `defaultBook` |
| `src/state-machine.ts` (create) | `INSTANT_EVENTS`, `TRANSITIONS`, `transition`, `OPEN_JOB_STATUSES`, `TERMINAL_STATUSES`, `ACTIVE_STATUSES` |
| `src/geo.ts` (create) | `haversineKm`, `distanceM`, `estimateEta`, `isLatLng` |
| `src/pricing.ts` (create) | `parseSurge`, `quotePrice`, `shareVnd`, `assertVnd` |
| `src/cancellation.ts` (create) | `quoteCancel`, `settleCompleted`, `settleNoMatch`, `graceEndsAt`, `lateDeadline` |
| `src/eligibility.ts` (create) | `PhotographerFacts`, `readinessReasons`, `meetsQualityBar`, `cancelRate`, `tierOf` |
| `src/scoring.ts` (create) | `Scorer` shape, `dispatchScorerV1`, components, `etaFromReasons` |
| `src/matcher.ts` (create) | `rankCandidates` (pure matcher core) |
| `src/rounds.ts` (create) | `SearchState`, `startSearch`, `nextSearchStep`, `onNobodyLeft`, `searchEndsAt`, `radiusKm`, `lastOfferAt` |
| `src/arrival.ts`, `src/stats.ts` (create) | `decideArrival`; `typicalMatchMinutes`, `locationAllowed` |
| `src/index.ts` (create) | Barrel |
| `test/*.test.ts`, `test/support/facts.ts` (create) | Unit and property tests |
| `bench/run.ts` (create) | Micro-benchmarks with thresholds |
| `.github/workflows/dispatch-core.yml` (create) | CI |

---

### Task 1: Scaffold, contract codes, errors, clock and the purity test

**Files:**
- Create: `packages/dispatch-core/package.json`, `packages/dispatch-core/tsconfig.json`, `packages/dispatch-core/eslint.config.js`, `packages/dispatch-core/.gitignore`, `packages/dispatch-core/src/types.ts`, `packages/dispatch-core/src/errors.ts`, `packages/dispatch-core/src/clock.ts`, `packages/dispatch-core/src/index.ts`, `packages/dispatch-core/test/purity.test.ts`, `packages/dispatch-core/test/types.test.ts`, `.github/workflows/dispatch-core.yml`

**Interfaces:**
- Consumes: the enums of `services/dispatch/api/openapi.yaml` (with `limit_exceeded` added to `ErrorCode` by plan I3 Task 1).
- Produces:
  - `INSTANT_REQUEST_STATUSES`, `GENRES`, `PACKAGE_CODES`, `CANCEL_RULES`, `DECLINE_REASONS`, `ELIGIBILITY_REASONS`, `OFFER_OUTCOMES`, `PAYMENT_PROVIDERS` (readonly tuples) and their union types `InstantRequestStatus`, `Genre`, `PackageCode`, `CancelRule`, `DeclineReason`, `EligibilityReason`, `OfferOutcome`, `PaymentProvider`; `type Round = 1 | 2`; `interface LatLng { lat: number; lng: number }`; `GENRE_SPECIALTY: Readonly<Record<Genre, string>>`; guards `isInstantRequestStatus`, `isGenre`, `isPackageCode`, `isCancelRule`, `isDeclineReason`, `isPaymentProvider` (`(v: unknown) => v is T`).
  - `DISPATCH_ERROR_CODES`, `type DispatchErrorCode`, `class DispatchError extends Error { readonly code: DispatchErrorCode; readonly details?: Readonly<Record<string, unknown>> }`, `isDispatchError(e: unknown): e is DispatchError`.
  - `interface Clock { now(): Date }`, `type Rng = () => number`, `systemClock`, `systemRng`, `manualClock(start: Date | string): ManualClock` (`advance(ms)`, `set(at)`), `seededRng(seed: number): Rng`, `addMs(d: Date, ms: number): Date`.

- [ ] **Step 1: Create the package tooling and install**

```json
// packages/dispatch-core/package.json
{
  "name": "@photobooking/dispatch-core",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "exports": { ".": "./src/index.ts" },
  "engines": { "node": ">=22" },
  "scripts": {
    "typecheck": "tsc -p tsconfig.json",
    "lint": "eslint .",
    "test": "node --import tsx --test \"test/**/*.test.ts\"",
    "bench": "node --import tsx bench/run.ts"
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

(JSON has no comments: the first line above only names the file; do not write it into the file.)

```json
// packages/dispatch-core/tsconfig.json
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
  "include": ["src", "test", "bench"]
}
```

(JSON has no comments: the first line above only names the file; do not write it into the file.)

```js
// packages/dispatch-core/eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

const INFRA = [
  'firebase', 'firebase/*', 'firebase-admin', 'firebase-admin/*', 'firebase-functions', 'firebase-functions/*',
  '@firebase/*', '@google-cloud/*', 'node:*', 'redis', 'ioredis', 'bullmq', 'pg', 'pg-*', 'kysely', 'fastify',
  '@fastify/*', 'undici', 'axios',
];

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
          group: INFRA,
          message: 'packages/dispatch-core is pure: no Redis, PostgreSQL, Firebase, HTTP or Node imports in src/.',
        }],
      }],
      'no-restricted-globals': ['error',
        { name: 'fetch', message: 'No I/O in dispatch-core.' },
        { name: 'setTimeout', message: 'Time is injected (Clock); timers belong to the service.' },
        { name: 'setInterval', message: 'Time is injected (Clock); timers belong to the service.' },
        { name: 'process', message: 'No environment access in dispatch-core: pass config in.' },
      ],
    },
  },
);
```

```gitignore
# packages/dispatch-core/.gitignore
node_modules/
```

Run (from `packages/dispatch-core`): `npm install`
Expected: `package-lock.json` created; `npm warn install-scripts … esbuild` is harmless.

- [ ] **Step 2: Write the failing tests**

```ts
// packages/dispatch-core/test/purity.test.ts
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
  [...code.matchAll(/(?:import|export)\s[^'"]*?from\s+['"]([^'"]+)['"]|import\(\s*['"]([^'"]+)['"]\s*\)/g)].map(
    (m) => m[1] ?? m[2] ?? '',
  );

test('dispatch-core source imports only its own modules (no Redis, PostgreSQL, Firebase, Node)', () => {
  const offenders = sources(join(root, 'src')).flatMap((file) =>
    specifiers(readFileSync(file, 'utf8'))
      .filter((s) => !s.startsWith('./') && !s.startsWith('../'))
      .map((s) => `${file}: ${s}`));
  assert.deepEqual(offenders, []);
});

test('only clock.ts reads the real clock or Math.random', () => {
  const offenders = sources(join(root, 'src'))
    .filter((f) => !f.endsWith('clock.ts'))
    .flatMap((file) => {
      const code = readFileSync(file, 'utf8');
      return [/Date\.now\(/, /new Date\(\)/, /Math\.random\(/, /performance\.now\(/]
        .filter((re) => re.test(code))
        .map((re) => `${file}: ${re.source}`);
    });
  assert.deepEqual(offenders, []);
});

test('no timers, fetch or environment access in src/', () => {
  const offenders = sources(join(root, 'src')).flatMap((file) => {
    const code = readFileSync(file, 'utf8');
    return [/\bsetTimeout\(/, /\bsetInterval\(/, /\bfetch\(/, /\bprocess\./]
      .filter((re) => re.test(code))
      .map((re) => `${file}: ${re.source}`);
  });
  assert.deepEqual(offenders, []);
});

test('dispatch-core has no runtime dependencies', () => {
  const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')) as { dependencies?: unknown };
  assert.equal(pkg.dependencies, undefined);
});
```

```ts
// packages/dispatch-core/test/types.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CANCEL_RULES, DECLINE_REASONS, DISPATCH_ERROR_CODES, DispatchError, ELIGIBILITY_REASONS, GENRES, GENRE_SPECIALTY,
  INSTANT_REQUEST_STATUSES, OFFER_OUTCOMES, PACKAGE_CODES, PAYMENT_PROVIDERS, isDispatchError, isGenre,
  isInstantRequestStatus, manualClock, seededRng,
} from '../src/index.js';

// Literal copies of services/dispatch/api/openapi.yaml (and relational-schema.md §2.8 checks).
describe('codes match the contract', () => {
  test('InstantRequestStatus', () => {
    assert.deepEqual([...INSTANT_REQUEST_STATUSES], [
      'pending_payment', 'payment_failed', 'searching', 'assigned', 'en_route', 'arrived', 'in_progress', 'completed',
      'no_match', 'cancelled_by_customer', 'no_show_customer', 'disputed',
    ]);
  });
  test('Genre, PackageCode, CancelRule, DeclineReason, eligibility reasons, providers, offer outcomes', () => {
    assert.deepEqual([...GENRES], ['portrait', 'couple', 'family', 'small_event', 'product']);
    assert.deepEqual([...PACKAGE_CODES], ['p30', 'p60', 'p120']);
    assert.deepEqual([...CANCEL_RULES], ['free_searching', 'free_grace', 'en_route_fee', 'no_show', 'photographer_fault', 'photographer_cancel']);
    assert.deepEqual([...DECLINE_REASONS], ['too_far', 'busy', 'genre_mismatch', 'other']);
    assert.deepEqual([...ELIGIBILITY_REASONS], ['profile_incomplete', 'no_phone', 'price_list_not_accepted', 'outside_city', 'location_denied']);
    assert.deepEqual([...PAYMENT_PROVIDERS], ['momo', 'vnpay', 'fake']);
    assert.deepEqual([...OFFER_OUTCOMES], ['pending', 'accepted', 'declined', 'expired', 'withdrawn']);
  });
  test('ErrorCode without the transport-only codes', () => {
    assert.deepEqual([...DISPATCH_ERROR_CODES].sort(), [
      'already_assigned', 'conflict', 'contact_locked', 'invalid_argument', 'limit_exceeded', 'no_match', 'not_eligible',
      'not_found', 'offer_expired', 'outside_service_area', 'permission_denied', 'phone_required', 'price_changed',
    ]);
  });
  test('every genre maps to a taxonomy specialty', () => {
    assert.deepEqual(GENRE_SPECIALTY, { portrait: 'portrait', couple: 'couple', family: 'family', small_event: 'event', product: 'product' });
  });
  test('guards', () => {
    assert.equal(isGenre('portrait'), true);
    assert.equal(isGenre('wedding'), false);
    assert.equal(isInstantRequestStatus('searching'), true);
    assert.equal(isInstantRequestStatus('requested'), false);
  });
});

describe('errors, clock and rng', () => {
  test('DispatchError carries a code and details; the message is the code', () => {
    const e = new DispatchError('not_eligible', { reasons: ['no_phone'] });
    assert.equal(e.message, 'not_eligible');
    assert.deepEqual(e.details, { reasons: ['no_phone'] });
    assert.equal(isDispatchError(e), true);
    assert.equal(isDispatchError(new Error('x')), false);
  });
  test('manualClock advances and sets', () => {
    const c = manualClock('2026-10-01T08:00:00.000Z');
    c.advance(30_000);
    assert.equal(c.now().toISOString(), '2026-10-01T08:00:30.000Z');
    c.set('2026-10-02T00:00:00.000Z');
    assert.equal(c.now().toISOString(), '2026-10-02T00:00:00.000Z');
    assert.throws(() => manualClock('nope'), RangeError);
  });
  test('seededRng is deterministic and in [0, 1)', () => {
    const a = seededRng(42);
    const b = seededRng(42);
    for (let i = 0; i < 1000; i++) {
      const x = a();
      assert.equal(x, b());
      assert.ok(x >= 0 && x < 1);
    }
    assert.notEqual(seededRng(1)(), seededRng(2)());
  });
});
```

- [ ] **Step 3: Run and see it fail**

Run: `npm test`
Expected: FAIL. `types.test.ts` stops with `ERR_MODULE_NOT_FOUND` for `src/index.js`; `purity.test.ts` fails with `ENOENT` on `src`.

- [ ] **Step 4: Implement**

```ts
// packages/dispatch-core/src/types.ts
/** Wire codes of services/dispatch/api/openapi.yaml, spelled exactly as in the contract. */
export const INSTANT_REQUEST_STATUSES = [
  'pending_payment',
  'payment_failed',
  'searching',
  'assigned',
  'en_route',
  'arrived',
  'in_progress',
  'completed',
  'no_match',
  'cancelled_by_customer',
  'no_show_customer',
  'disputed',
] as const;
export type InstantRequestStatus = (typeof INSTANT_REQUEST_STATUSES)[number];

export const GENRES = ['portrait', 'couple', 'family', 'small_event', 'product'] as const;
export type Genre = (typeof GENRES)[number];

export const PACKAGE_CODES = ['p30', 'p60', 'p120'] as const;
export type PackageCode = (typeof PACKAGE_CODES)[number];

export const CANCEL_RULES = [
  'free_searching',
  'free_grace',
  'en_route_fee',
  'no_show',
  'photographer_fault',
  'photographer_cancel',
] as const;
export type CancelRule = (typeof CANCEL_RULES)[number];

export const DECLINE_REASONS = ['too_far', 'busy', 'genre_mismatch', 'other'] as const;
export type DeclineReason = (typeof DECLINE_REASONS)[number];

export const ELIGIBILITY_REASONS = [
  'profile_incomplete',
  'no_phone',
  'price_list_not_accepted',
  'outside_city',
  'location_denied',
] as const;
export type EligibilityReason = (typeof ELIGIBILITY_REASONS)[number];

export const OFFER_OUTCOMES = ['pending', 'accepted', 'declined', 'expired', 'withdrawn'] as const;
export type OfferOutcome = (typeof OFFER_OUTCOMES)[number];

export const PAYMENT_PROVIDERS = ['momo', 'vnpay', 'fake'] as const;
export type PaymentProvider = (typeof PAYMENT_PROVIDERS)[number];

export type Round = 1 | 2;

export interface LatLng {
  lat: number;
  lng: number;
}

/** Genre of a request → specialty id of the taxonomy (relational-schema.md §6 seed). */
export const GENRE_SPECIALTY: Readonly<Record<Genre, string>> = {
  portrait: 'portrait',
  couple: 'couple',
  family: 'family',
  small_event: 'event',
  product: 'product',
};

const has = <T extends string>(list: readonly T[], v: unknown): v is T =>
  typeof v === 'string' && (list as readonly string[]).includes(v);

export const isInstantRequestStatus = (v: unknown): v is InstantRequestStatus => has(INSTANT_REQUEST_STATUSES, v);
export const isGenre = (v: unknown): v is Genre => has(GENRES, v);
export const isPackageCode = (v: unknown): v is PackageCode => has(PACKAGE_CODES, v);
export const isCancelRule = (v: unknown): v is CancelRule => has(CANCEL_RULES, v);
export const isDeclineReason = (v: unknown): v is DeclineReason => has(DECLINE_REASONS, v);
export const isPaymentProvider = (v: unknown): v is PaymentProvider => has(PAYMENT_PROVIDERS, v);
```

```ts
// packages/dispatch-core/src/errors.ts
/**
 * Business error codes the dispatch domain can raise: the `ErrorCode` enum of
 * services/dispatch/api/openapi.yaml minus the transport-only codes
 * (`unauthenticated`, `internal`), which only the HTTP layer produces.
 */
export const DISPATCH_ERROR_CODES = [
  'phone_required',
  'contact_locked',
  'invalid_argument',
  'permission_denied',
  'not_found',
  'conflict',
  'limit_exceeded',
  'no_match',
  'offer_expired',
  'already_assigned',
  'not_eligible',
  'outside_service_area',
  'price_changed',
] as const;

export type DispatchErrorCode = (typeof DISPATCH_ERROR_CODES)[number];

/** A refused operation. `details` follows the contract's `Error.details` (e.g. `{reasons: [...]}`). */
export class DispatchError extends Error {
  constructor(
    readonly code: DispatchErrorCode,
    readonly details?: Readonly<Record<string, unknown>>,
  ) {
    super(code);
    this.name = 'DispatchError';
  }
}

export const isDispatchError = (e: unknown): e is DispatchError => e instanceof DispatchError;
```

```ts
// packages/dispatch-core/src/clock.ts
/** Time and randomness are injected so every rule is deterministic under test. */
export interface Clock {
  now(): Date;
}

/** Returns a float in [0, 1). */
export type Rng = () => number;

/** The only places in dispatch-core that read the real clock or Math.random. */
export const systemClock: Clock = { now: () => new Date() };
export const systemRng: Rng = () => Math.random();

export interface ManualClock extends Clock {
  advance(ms: number): void;
  set(at: Date | string): void;
}

export function manualClock(start: Date | string): ManualClock {
  let t = new Date(start).getTime();
  if (Number.isNaN(t)) throw new RangeError(`invalid start time ${String(start)}`);
  return {
    now: () => new Date(t),
    advance(ms) {
      t += ms;
    },
    set(at) {
      t = new Date(at).getTime();
    },
  };
}

/** mulberry32: small, fast, good enough for tie-breaks and property tests. */
export function seededRng(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const addMs = (d: Date, ms: number): Date => new Date(d.getTime() + ms);
```

```ts
// packages/dispatch-core/src/index.ts
export * from './types.js';
export * from './errors.js';
export * from './clock.js';
```

```yaml
# .github/workflows/dispatch-core.yml
name: dispatch-core
on:
  push:
    branches: [flutter-rewrite, develop, main]
  pull_request:
    paths:
      - 'packages/dispatch-core/**'
      - '.github/workflows/dispatch-core.yml'
jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/dispatch-core
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
          cache-dependency-path: packages/dispatch-core/package-lock.json
      - run: npm ci
      - run: npm run typecheck
      - run: npm run lint
      - run: npm test
```

- [ ] **Step 5: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: typecheck and lint print nothing after their headers; `ℹ tests 12`, `ℹ pass 12`, `ℹ fail 0`.

- [ ] **Step 6: Commit**

```bash
git add packages/dispatch-core .github/workflows/dispatch-core.yml
git commit -m "feat(dispatch-core): pure package with contract codes, errors, injected clock and rng, purity test

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Configuration with every tunable, per city

**Files:**
- Create: `packages/dispatch-core/src/config.ts`, `packages/dispatch-core/test/config.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `interface DispatchConfig` with `offerTtlMs`, `round1 { maxMs; radiiKm }`, `round2 { maxMs; radiusKm }`, `totalSearchMs`, `idleRetryMs`, `candidateLimit`, `eta { detourFactor; speedKmh; normMaxMin }`, `scoring { weights { eta; genre; rating; reliability }; helpReadyBonus; genreLevelScores; genreUnknown; ratingPrior { m; c }; reliabilityPrior { m; acceptRate; cancelRate } }`, `eligibility { minRating; minReviews; maxCancelRate; minJobsForCancelRate }`, `pricing { payoutRateBps; roundToVnd }`, `cancellation { graceMs; enRouteFeeBps; noShowWaitMs; noShowPhotographerBps; lateToleranceMs }`, `arrival { maxDistanceM; poorAccuracyM }`, `completion { autoCompleteMs; disputeWindowMs }`, `presence { ttlMs }`, `tracking { minIntervalMs; etaRefreshMs }`, `stats { typicalMatchWindowMs; typicalMatchMinSamples }`.
  - `DEFAULT_CONFIG: DispatchConfig` (the v1 values of spec §3.2, §4, §9, §10); `type DeepPartial<T>`; `interface ConfigBook { base: DispatchConfig; cities: Readonly<Record<string, DeepPartial<DispatchConfig>>> }`; `validateConfig(c): DispatchConfig` (throws `RangeError` listing every problem); `configForCity(book, cityId): DispatchConfig`; `defaultBook(cities?): ConfigBook`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/config.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, configForCity, defaultBook, validateConfig, type DispatchConfig } from '../src/index.js';

describe('DEFAULT_CONFIG is the v1 table of spec §3.2 and §4', () => {
  test('offer and rounds', () => {
    assert.equal(DEFAULT_CONFIG.offerTtlMs, 30_000);
    assert.equal(DEFAULT_CONFIG.round1.maxMs, 300_000);
    assert.deepEqual([...DEFAULT_CONFIG.round1.radiiKm], [3, 6, 10]);
    assert.deepEqual(DEFAULT_CONFIG.round2, { maxMs: 300_000, radiusKm: 10 });
    assert.equal(DEFAULT_CONFIG.totalSearchMs, 600_000);
  });
  test('scoring, eta, eligibility', () => {
    assert.deepEqual(DEFAULT_CONFIG.scoring.weights, { eta: 0.45, genre: 0.25, rating: 0.15, reliability: 0.15 });
    assert.equal(DEFAULT_CONFIG.scoring.helpReadyBonus, 0.05);
    assert.deepEqual(DEFAULT_CONFIG.eta, { detourFactor: 1.4, speedKmh: 20, normMaxMin: 45 });
    assert.deepEqual(DEFAULT_CONFIG.eligibility, { minRating: 4.5, minReviews: 5, maxCancelRate: 0.1, minJobsForCancelRate: 10 });
  });
  test('money, cancellation, arrival, completion, presence, tracking', () => {
    assert.deepEqual(DEFAULT_CONFIG.pricing, { payoutRateBps: 8_000, roundToVnd: 1_000 });
    assert.deepEqual(DEFAULT_CONFIG.cancellation, {
      graceMs: 120_000, enRouteFeeBps: 2_000, noShowWaitMs: 900_000, noShowPhotographerBps: 5_000, lateToleranceMs: 900_000,
    });
    assert.deepEqual(DEFAULT_CONFIG.arrival, { maxDistanceM: 200, poorAccuracyM: 100 });
    assert.deepEqual(DEFAULT_CONFIG.completion, { autoCompleteMs: 7_200_000, disputeWindowMs: 86_400_000 });
    assert.equal(DEFAULT_CONFIG.presence.ttlMs, 600_000);
    assert.deepEqual(DEFAULT_CONFIG.tracking, { minIntervalMs: 5_000, etaRefreshMs: 60_000 });
  });
  test('validates', () => {
    assert.equal(validateConfig(DEFAULT_CONFIG), DEFAULT_CONFIG);
  });
});

describe('per-city overrides', () => {
  const book = defaultBook({
    hcm: { pricing: { payoutRateBps: 7_500 }, round1: { radiiKm: [2, 5, 10] } },
    hn: { offerTtlMs: 20_000 },
  });
  test('a city overrides only what it names', () => {
    const hcm = configForCity(book, 'hcm');
    assert.equal(hcm.pricing.payoutRateBps, 7_500);
    assert.equal(hcm.pricing.roundToVnd, 1_000);
    assert.deepEqual([...hcm.round1.radiiKm], [2, 5, 10]);
    assert.equal(hcm.round1.maxMs, 300_000);
    assert.equal(configForCity(book, 'hn').offerTtlMs, 20_000);
  });
  test('an unknown city gets the base', () => {
    assert.deepEqual(configForCity(book, 'dn'), DEFAULT_CONFIG);
  });
  test('overrides never mutate the base', () => {
    configForCity(book, 'hcm');
    assert.equal(DEFAULT_CONFIG.pricing.payoutRateBps, 8_000);
  });
  test('an unknown key is refused', () => {
    const bad = defaultBook({ x: { nope: 1 } as never });
    assert.throws(() => configForCity(bad, 'x'), /unknown config key nope/);
  });
});

describe('validateConfig refuses inconsistent values', () => {
  const tweak = (f: (c: DispatchConfig) => void): DispatchConfig => {
    const c = structuredClone(DEFAULT_CONFIG) as DispatchConfig;
    f(c);
    return c;
  };
  const cases: Array<[string, (c: DispatchConfig) => void, RegExp]> = [
    ['weights not summing to 1', (c) => { c.scoring.weights.eta = 0.5; }, /sum to 1/],
    ['radii not increasing', (c) => { c.round1.radiiKm = [3, 3, 10]; }, /increase/],
    ['round 2 narrower than round 1', (c) => { c.round2.radiusKm = 6; }, /widest/],
    ['round 1 longer than the search', (c) => { c.round1.maxMs = 700_000; }, /totalSearchMs/],
    ['offer longer than round 1', (c) => { c.offerTtlMs = 300_000; }, /offerTtlMs must be </],
    ['payout over 100 %', (c) => { c.pricing.payoutRateBps = 10_001; }, /payoutRateBps/],
    ['fractional money step', (c) => { c.pricing.roundToVnd = 0.5; }, /roundToVnd/],
    ['detour below 1', (c) => { c.eta.detourFactor = 0.9; }, /detourFactor/],
    ['negative grace', (c) => { c.cancellation.graceMs = -1; }, /graceMs/],
    ['empty radii', (c) => { c.round1.radiiKm = []; }, /empty/],
  ];
  for (const [name, f, re] of cases) {
    test(name, () => assert.throws(() => validateConfig(tweak(f)), re));
  }
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `DEFAULT_CONFIG`, `configForCity`, `defaultBook`, `validateConfig`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/config.ts
/**
 * Every tunable of instant booking (spec 2026-10-01-instant-booking-design.md §3.2, §4, §9, §10).
 * Values are v1 defaults; a city may override any of them (ConfigBook.cities).
 * Money ratios are basis points (1 bps = 0.01 %) so all money maths stays in integers.
 */
export interface DispatchConfig {
  /** One offer is open this long (§3.2: 30 s). */
  offerTtlMs: number;
  round1: {
    /** §3.2: round 1 lasts at most 5 minutes. */
    maxMs: number;
    /** Radius steps, used in order each time the current radius has nobody left (3 → 6 → 10 km). */
    radiiKm: readonly number[];
  };
  round2: {
    /** §3.2: round 2 (only when the customer ticked "Mở rộng tìm kiếm") adds at most 5 minutes. */
    maxMs: number;
    radiusKm: number;
  };
  /** §3.2: total search time; past it the request is no_match and refunded 100 %. */
  totalSearchMs: number;
  /** Nobody available even at the widest radius: look again after this long. */
  idleRetryMs: number;
  /** At most this many nearest photographers are read per matcher run (GEOSEARCH COUNT). */
  candidateLimit: number;
  eta: {
    /** §3.2: straight line × 1.4 … */
    detourFactor: number;
    /** … at 20 km/h. */
    speedKmh: number;
    /** An ETA of this many minutes or more scores 0 on the eta component. */
    normMaxMin: number;
  };
  scoring: {
    /** §3.2: score = 0.45·eta + 0.25·genreMatch + 0.15·rating + 0.15·reliability. Must sum to 1. */
    weights: { eta: number; genre: number; rating: number; reliability: number };
    /** §3.2: "Sẵn sàng hỗ trợ" adds 0.05 in round 1. */
    helpReadyBonus: number;
    /** Score of specialty levels 1, 2, 3 for the requested genre (same as recommender rules-v1 §3e.6). */
    genreLevelScores: readonly [number, number, number];
    /** genreMatch when the photographer has no skills data at all ("not enough data"). */
    genreUnknown: number;
    /** Bayesian rating smoothing (v·R + m·C)/(v + m), then (x − 3)/2 (recommender rules-v1 §3e.6). */
    ratingPrior: { m: number; c: number };
    /** Smoothing of acceptance and cancellation rates for photographers with little history. */
    reliabilityPrior: { m: number; acceptRate: number; cancelRate: number };
  };
  eligibility: {
    /** §3.2 priority tier quality bar: rating ≥ 4.5 with ≥ 5 reviews … */
    minRating: number;
    minReviews: number;
    /** … instant cancellation rate ≤ 10 % once the photographer has ≥ 10 instant jobs. */
    maxCancelRate: number;
    minJobsForCancelRate: number;
  };
  pricing: {
    /** §4: photographer gets payoutRate of the price (proposed 80 %). */
    payoutRateBps: number;
    /** §4: final price is rounded to 1,000 ₫. */
    roundToVnd: number;
  };
  cancellation: {
    /** §4: free cancellation within 2 minutes after assigned. */
    graceMs: number;
    /** §4: customer cancels while the photographer is on the way: photographer keeps 20 %. */
    enRouteFeeBps: number;
    /** §4: photographer waited 15 minutes at the meet point without the customer. */
    noShowWaitMs: number;
    /** §4: no_show_customer: photographer keeps 50 %. */
    noShowPhotographerBps: number;
    /** §4: photographer later than 15 minutes past the initial ETA → customer may cancel for 100 %. */
    lateToleranceMs: number;
  };
  arrival: {
    /** §2.2: "Đã đến" only within 200 m … */
    maxDistanceM: number;
    /** … unless GPS accuracy is worse than 100 m, then forced with a reason (§10). */
    poorAccuracyM: number;
  };
  completion: {
    /** §3.1: completed automatically 2 hours after the photographer's "Hoàn thành". */
    autoCompleteMs: number;
    /** §3.1: disputed only within 24 hours of completed. */
    disputeWindowMs: number;
  };
  presence: {
    /** §5: presence:{uid} TTL 10 minutes. */
    ttlMs: number;
  };
  tracking: {
    /** §6: location at most once every 5 seconds. */
    minIntervalMs: number;
    /** §5: Goong Distance Matrix at most once a minute per request. */
    etaRefreshMs: number;
  };
  stats: {
    /** §2.1: "Thường có người nhận trong khoảng {n} phút" is the median of the last 7 days … */
    typicalMatchWindowMs: number;
    /** … hidden below this many samples ("chưa đủ dữ liệu thì ẩn"). */
    typicalMatchMinSamples: number;
  };
}

const MIN = 60_000;

export const DEFAULT_CONFIG: DispatchConfig = Object.freeze<DispatchConfig>({
  offerTtlMs: 30_000,
  round1: { maxMs: 5 * MIN, radiiKm: [3, 6, 10] },
  round2: { maxMs: 5 * MIN, radiusKm: 10 },
  totalSearchMs: 10 * MIN,
  idleRetryMs: 5_000,
  candidateLimit: 50,
  eta: { detourFactor: 1.4, speedKmh: 20, normMaxMin: 45 },
  scoring: {
    weights: { eta: 0.45, genre: 0.25, rating: 0.15, reliability: 0.15 },
    helpReadyBonus: 0.05,
    genreLevelScores: [0.4, 0.7, 1.0],
    genreUnknown: 0.5,
    ratingPrior: { m: 10, c: 4.3 },
    reliabilityPrior: { m: 10, acceptRate: 0.7, cancelRate: 0.05 },
  },
  eligibility: { minRating: 4.5, minReviews: 5, maxCancelRate: 0.1, minJobsForCancelRate: 10 },
  pricing: { payoutRateBps: 8_000, roundToVnd: 1_000 },
  cancellation: {
    graceMs: 2 * MIN,
    enRouteFeeBps: 2_000,
    noShowWaitMs: 15 * MIN,
    noShowPhotographerBps: 5_000,
    lateToleranceMs: 15 * MIN,
  },
  arrival: { maxDistanceM: 200, poorAccuracyM: 100 },
  completion: { autoCompleteMs: 120 * MIN, disputeWindowMs: 24 * 60 * MIN },
  presence: { ttlMs: 10 * MIN },
  tracking: { minIntervalMs: 5_000, etaRefreshMs: MIN },
  stats: { typicalMatchWindowMs: 7 * 24 * 60 * MIN, typicalMatchMinSamples: 20 },
});

export type DeepPartial<T> = {
  [K in keyof T]?: T[K] extends readonly unknown[] ? T[K] : T[K] extends object ? DeepPartial<T[K]> : T[K];
};

/** Base values plus per-city overrides, keyed by dispatch.cities.id. */
export interface ConfigBook {
  base: DispatchConfig;
  cities: Readonly<Record<string, DeepPartial<DispatchConfig>>>;
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

function merge<T>(base: T, over: DeepPartial<T> | undefined): T {
  if (over === undefined) return base;
  const out: Record<string, unknown> = { ...(base as Record<string, unknown>) };
  for (const [k, v] of Object.entries(over as Record<string, unknown>)) {
    if (v === undefined) continue;
    if (!(k in out)) throw new RangeError(`unknown config key ${k}`);
    const cur = out[k];
    out[k] = isPlainObject(v) && isPlainObject(cur) ? merge(cur, v) : v;
  }
  return out as T;
}

const near = (a: number, b: number): boolean => Math.abs(a - b) < 1e-9;

/** Throws RangeError listing every invalid value. */
export function validateConfig(c: DispatchConfig): DispatchConfig {
  const errors: string[] = [];
  const posInt = (name: string, v: number) => {
    if (!Number.isInteger(v) || v <= 0) errors.push(`${name} must be a positive integer`);
  };
  const unit = (name: string, v: number) => {
    if (!(v >= 0 && v <= 1)) errors.push(`${name} must be within 0..1`);
  };
  const bps = (name: string, v: number) => {
    if (!Number.isInteger(v) || v < 0 || v > 10_000) errors.push(`${name} must be an integer 0..10000`);
  };
  posInt('offerTtlMs', c.offerTtlMs);
  posInt('round1.maxMs', c.round1.maxMs);
  posInt('round2.maxMs', c.round2.maxMs);
  posInt('totalSearchMs', c.totalSearchMs);
  posInt('idleRetryMs', c.idleRetryMs);
  posInt('candidateLimit', c.candidateLimit);
  if (c.round1.radiiKm.length === 0) errors.push('round1.radiiKm must not be empty');
  c.round1.radiiKm.forEach((r, i) => {
    if (!(r > 0)) errors.push(`round1.radiiKm[${i}] must be > 0`);
    const prev = c.round1.radiiKm[i - 1];
    if (prev !== undefined && r <= prev) errors.push('round1.radiiKm must increase');
  });
  const widest = c.round1.radiiKm[c.round1.radiiKm.length - 1] ?? 0;
  if (c.round2.radiusKm < widest) errors.push('round2.radiusKm must be ≥ the widest round 1 radius');
  if (c.round1.maxMs > c.totalSearchMs) errors.push('round1.maxMs must be ≤ totalSearchMs');
  if (c.offerTtlMs >= c.round1.maxMs) errors.push('offerTtlMs must be < round1.maxMs');
  if (!(c.eta.detourFactor >= 1)) errors.push('eta.detourFactor must be ≥ 1');
  if (!(c.eta.speedKmh > 0)) errors.push('eta.speedKmh must be > 0');
  if (!(c.eta.normMaxMin > 0)) errors.push('eta.normMaxMin must be > 0');
  const w = c.scoring.weights;
  for (const [k, v] of Object.entries(w)) unit(`scoring.weights.${k}`, v);
  if (!near(w.eta + w.genre + w.rating + w.reliability, 1)) errors.push('scoring.weights must sum to 1');
  unit('scoring.helpReadyBonus', c.scoring.helpReadyBonus);
  c.scoring.genreLevelScores.forEach((v, i) => unit(`scoring.genreLevelScores[${i}]`, v));
  unit('scoring.genreUnknown', c.scoring.genreUnknown);
  if (!(c.scoring.ratingPrior.m >= 0)) errors.push('scoring.ratingPrior.m must be ≥ 0');
  if (!(c.scoring.ratingPrior.c >= 1 && c.scoring.ratingPrior.c <= 5)) errors.push('scoring.ratingPrior.c must be within 1..5');
  if (!(c.scoring.reliabilityPrior.m >= 0)) errors.push('scoring.reliabilityPrior.m must be ≥ 0');
  unit('scoring.reliabilityPrior.acceptRate', c.scoring.reliabilityPrior.acceptRate);
  unit('scoring.reliabilityPrior.cancelRate', c.scoring.reliabilityPrior.cancelRate);
  if (!(c.eligibility.minRating >= 1 && c.eligibility.minRating <= 5)) errors.push('eligibility.minRating must be within 1..5');
  if (!Number.isInteger(c.eligibility.minReviews) || c.eligibility.minReviews < 0) errors.push('eligibility.minReviews must be an integer ≥ 0');
  unit('eligibility.maxCancelRate', c.eligibility.maxCancelRate);
  if (!Number.isInteger(c.eligibility.minJobsForCancelRate) || c.eligibility.minJobsForCancelRate < 0) {
    errors.push('eligibility.minJobsForCancelRate must be an integer ≥ 0');
  }
  bps('pricing.payoutRateBps', c.pricing.payoutRateBps);
  posInt('pricing.roundToVnd', c.pricing.roundToVnd);
  posInt('cancellation.graceMs', c.cancellation.graceMs);
  bps('cancellation.enRouteFeeBps', c.cancellation.enRouteFeeBps);
  posInt('cancellation.noShowWaitMs', c.cancellation.noShowWaitMs);
  bps('cancellation.noShowPhotographerBps', c.cancellation.noShowPhotographerBps);
  posInt('cancellation.lateToleranceMs', c.cancellation.lateToleranceMs);
  posInt('arrival.maxDistanceM', c.arrival.maxDistanceM);
  posInt('arrival.poorAccuracyM', c.arrival.poorAccuracyM);
  posInt('completion.autoCompleteMs', c.completion.autoCompleteMs);
  posInt('completion.disputeWindowMs', c.completion.disputeWindowMs);
  posInt('presence.ttlMs', c.presence.ttlMs);
  posInt('tracking.minIntervalMs', c.tracking.minIntervalMs);
  posInt('tracking.etaRefreshMs', c.tracking.etaRefreshMs);
  posInt('stats.typicalMatchWindowMs', c.stats.typicalMatchWindowMs);
  posInt('stats.typicalMatchMinSamples', c.stats.typicalMatchMinSamples);
  if (errors.length > 0) throw new RangeError(`invalid dispatch config: ${errors.join('; ')}`);
  return c;
}

/** Base merged with the city's overrides, validated. Unknown cities get the base. */
export function configForCity(book: ConfigBook, cityId: string): DispatchConfig {
  return validateConfig(merge(book.base, book.cities[cityId]));
}

export function defaultBook(cities: ConfigBook['cities'] = {}): ConfigBook {
  return { base: DEFAULT_CONFIG, cities };
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './config.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 30`, `ℹ pass 30`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): dispatch configuration with v1 defaults, validation and per-city overrides

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Request state machine (spec §3.1)

**Files:**
- Create: `packages/dispatch-core/src/state-machine.ts`, `packages/dispatch-core/test/state-machine.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `DispatchConfig` (`completion`, `cancellation`) (Task 2); `InstantRequestStatus` (Task 1).
- Produces:
  - `INSTANT_EVENTS` = `payment_succeeded`, `payment_failed`, `accept`, `start_route`, `arrive`, `start`, `finish`, `confirm_complete`, `auto_complete`, `search_timeout`, `customer_cancel`, `photographer_cancel`, `report_no_show`, `open_dispute`; `type InstantEvent`.
  - `TRANSITIONS: Readonly<Record<InstantEvent, readonly InstantRequestStatus[]>>` (allowed source statuses), `canStartFrom(event, status): boolean`.
  - `interface RequestSnapshot { status; assignedAt: Date | null; arrivedAt: Date | null; finishedAt: Date | null; completedAt: Date | null }`; `interface TransitionPatch { assignedAt?: Date | null; arrivedAt?; startedAt?; finishedAt?; completedAt?; cancelledAt?; clearPhotographer?: true }`.
  - `transition(s: RequestSnapshot, event: InstantEvent, now: Date, cfg: Pick<DispatchConfig, 'completion' | 'cancellation'>): { ok: true; from; to; patch } | { ok: false; code: 'conflict'; reason: string }`.
  - `OPEN_JOB_STATUSES` (= the predicate of `instant_requests_one_open_job`), `TERMINAL_STATUSES`, `ACTIVE_STATUSES` (one per customer).

The machine, as tested (every other `(status, event)` pair is refused with `conflict`):

| From | Event | To | Guard |
|---|---|---|---|
| `pending_payment` | `payment_succeeded` / `payment_failed` / `customer_cancel` | `searching` / `payment_failed` / `cancelled_by_customer` | |
| `searching` | `accept` / `search_timeout` / `customer_cancel` | `assigned` / `no_match` / `cancelled_by_customer` | |
| `assigned` | `start_route` / `arrive` / `customer_cancel` / `photographer_cancel` | `en_route` / `arrived` / `cancelled_by_customer` / `searching` | `photographer_cancel` clears the photographer |
| `en_route` | `arrive` / `customer_cancel` / `photographer_cancel` | `arrived` / `cancelled_by_customer` / `searching` | |
| `arrived` | `start` / `customer_cancel` / `report_no_show` | `in_progress` / `cancelled_by_customer` / `no_show_customer` | no-show only ≥ 15 min after `arrivedAt` |
| `in_progress` | `finish` / `confirm_complete` / `auto_complete` | `in_progress` (sets `finishedAt`) / `completed` / `completed` | finish once; confirm needs `finishedAt`; auto ≥ 2 h after it |
| `completed` | `open_dispute` | `disputed` | ≤ 24 h after `completedAt` |

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/state-machine.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DEFAULT_CONFIG, INSTANT_EVENTS, INSTANT_REQUEST_STATUSES, OPEN_JOB_STATUSES, TERMINAL_STATUSES, transition,
  type InstantEvent, type InstantRequestStatus, type RequestSnapshot,
} from '../src/index.js';

const T0 = new Date('2026-10-01T08:00:00.000Z');
const at = (min: number) => new Date(T0.getTime() + min * 60_000);

/** Spec §3.1, written out by hand: every (from, event) pair that may succeed and where it goes. */
const ALLOWED: Record<string, InstantRequestStatus> = {
  'pending_payment payment_succeeded': 'searching',
  'pending_payment payment_failed': 'payment_failed',
  'pending_payment customer_cancel': 'cancelled_by_customer',
  'searching accept': 'assigned',
  'searching search_timeout': 'no_match',
  'searching customer_cancel': 'cancelled_by_customer',
  'assigned start_route': 'en_route',
  'assigned arrive': 'arrived',
  'assigned customer_cancel': 'cancelled_by_customer',
  'assigned photographer_cancel': 'searching',
  'en_route arrive': 'arrived',
  'en_route customer_cancel': 'cancelled_by_customer',
  'en_route photographer_cancel': 'searching',
  'arrived start': 'in_progress',
  'arrived customer_cancel': 'cancelled_by_customer',
  'arrived report_no_show': 'no_show_customer',
  'in_progress finish': 'in_progress',
  'in_progress confirm_complete': 'completed',
  'in_progress auto_complete': 'completed',
  'completed open_dispute': 'disputed',
};

/** A snapshot whose time guards are satisfied at `now` = at(1000). */
function ready(status: InstantRequestStatus, event: InstantEvent): RequestSnapshot {
  const finishedAt = event === 'finish' ? null : at(0);
  return { status, assignedAt: at(0), arrivedAt: at(0), finishedAt, completedAt: event === 'open_dispute' ? at(999) : at(0) };
}

describe('every transition of spec §3.1', () => {
  for (const from of INSTANT_REQUEST_STATUSES) {
    for (const event of INSTANT_EVENTS) {
      const expected = ALLOWED[`${from} ${event}`];
      test(`${from} --${event}--> ${expected ?? 'refused'}`, () => {
        const r = transition(ready(from, event), event, at(1000), DEFAULT_CONFIG);
        if (expected === undefined) {
          assert.equal(r.ok, false);
          if (!r.ok) assert.equal(r.code, 'conflict');
        } else {
          assert.equal(r.ok, true, r.ok ? '' : r.reason);
          if (r.ok) assert.equal(r.to, expected);
        }
      });
    }
  }
});

describe('time guards and patches', () => {
  const snap = (s: Partial<RequestSnapshot> & { status: InstantRequestStatus }): RequestSnapshot => ({
    assignedAt: null, arrivedAt: null, finishedAt: null, completedAt: null, ...s,
  });

  test('accept stamps assignedAt; photographer_cancel clears the photographer and assignedAt', () => {
    const a = transition(snap({ status: 'searching' }), 'accept', at(1), DEFAULT_CONFIG);
    assert.deepEqual(a, { ok: true, from: 'searching', to: 'assigned', patch: { assignedAt: at(1) } });
    const c = transition(snap({ status: 'en_route', assignedAt: at(1) }), 'photographer_cancel', at(3), DEFAULT_CONFIG);
    assert.deepEqual(c, { ok: true, from: 'en_route', to: 'searching', patch: { clearPhotographer: true, assignedAt: null } });
  });

  test('finish once, keeping in_progress; confirm needs finish', () => {
    const f = transition(snap({ status: 'in_progress' }), 'finish', at(60), DEFAULT_CONFIG);
    assert.deepEqual(f, { ok: true, from: 'in_progress', to: 'in_progress', patch: { finishedAt: at(60) } });
    assert.equal(transition(snap({ status: 'in_progress', finishedAt: at(60) }), 'finish', at(61), DEFAULT_CONFIG).ok, false);
    assert.equal(transition(snap({ status: 'in_progress' }), 'confirm_complete', at(61), DEFAULT_CONFIG).ok, false);
    const c = transition(snap({ status: 'in_progress', finishedAt: at(60) }), 'confirm_complete', at(61), DEFAULT_CONFIG);
    assert.deepEqual(c, { ok: true, from: 'in_progress', to: 'completed', patch: { completedAt: at(61) } });
  });

  test('auto_complete exactly 2 hours after finish, not before', () => {
    const s = snap({ status: 'in_progress', finishedAt: at(0) });
    assert.equal(transition(s, 'auto_complete', new Date(at(120).getTime() - 1), DEFAULT_CONFIG).ok, false);
    assert.equal(transition(s, 'auto_complete', at(120), DEFAULT_CONFIG).ok, true);
  });

  test('no-show only after 15 minutes at the meet point', () => {
    const s = snap({ status: 'arrived', arrivedAt: at(0) });
    assert.equal(transition(s, 'report_no_show', at(14), DEFAULT_CONFIG).ok, false);
    const r = transition(s, 'report_no_show', at(15), DEFAULT_CONFIG);
    assert.deepEqual(r, { ok: true, from: 'arrived', to: 'no_show_customer', patch: { cancelledAt: at(15) } });
  });

  test('dispute only within 24 hours of completed', () => {
    const s = snap({ status: 'completed', completedAt: at(0) });
    assert.equal(transition(s, 'open_dispute', at(24 * 60), DEFAULT_CONFIG).ok, true);
    assert.equal(transition(s, 'open_dispute', new Date(at(24 * 60).getTime() + 1), DEFAULT_CONFIG).ok, false);
  });

  test('customer cancel stamps cancelledAt from every step before in_progress', () => {
    for (const status of ['pending_payment', 'searching', 'assigned', 'en_route', 'arrived'] as const) {
      const r = transition(snap({ status }), 'customer_cancel', at(5), DEFAULT_CONFIG);
      assert.deepEqual(r, { ok: true, from: status, to: 'cancelled_by_customer', patch: { cancelledAt: at(5) } });
    }
    assert.equal(transition(snap({ status: 'in_progress' }), 'customer_cancel', at(5), DEFAULT_CONFIG).ok, false);
  });

  test('terminal statuses accept no event', () => {
    for (const status of TERMINAL_STATUSES) {
      for (const event of INSTANT_EVENTS) {
        assert.equal(transition(ready(status, event), event, at(1000), DEFAULT_CONFIG).ok, false, `${status} ${event}`);
      }
    }
  });

  test('open-job statuses match the unique index of relational-schema.md §2.8', () => {
    assert.deepEqual([...OPEN_JOB_STATUSES], ['assigned', 'en_route', 'arrived', 'in_progress']);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `INSTANT_EVENTS`, `OPEN_JOB_STATUSES`, `TERMINAL_STATUSES`, `transition`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/state-machine.ts
import type { DispatchConfig } from './config.js';
import type { InstantRequestStatus } from './types.js';

/**
 * Request state machine (spec §3.1). Only the dispatch service applies events;
 * clients call the API and never write a status.
 */
export const INSTANT_EVENTS = [
  'payment_succeeded',
  'payment_failed',
  'accept',
  'start_route',
  'arrive',
  'start',
  'finish',
  'confirm_complete',
  'auto_complete',
  'search_timeout',
  'customer_cancel',
  'photographer_cancel',
  'report_no_show',
  'open_dispute',
] as const;
export type InstantEvent = (typeof INSTANT_EVENTS)[number];

/** Statuses each event may start from (before time guards). */
export const TRANSITIONS: Readonly<Record<InstantEvent, readonly InstantRequestStatus[]>> = {
  payment_succeeded: ['pending_payment'],
  payment_failed: ['pending_payment'],
  accept: ['searching'],
  start_route: ['assigned'],
  // A photographer already at the meet point may never post a location first.
  arrive: ['assigned', 'en_route'],
  start: ['arrived'],
  finish: ['in_progress'],
  confirm_complete: ['in_progress'],
  auto_complete: ['in_progress'],
  search_timeout: ['searching'],
  customer_cancel: ['pending_payment', 'searching', 'assigned', 'en_route', 'arrived'],
  photographer_cancel: ['assigned', 'en_route'],
  report_no_show: ['arrived'],
  open_dispute: ['completed'],
};

const TARGET: Readonly<Record<InstantEvent, InstantRequestStatus | 'same'>> = {
  payment_succeeded: 'searching',
  payment_failed: 'payment_failed',
  accept: 'assigned',
  start_route: 'en_route',
  arrive: 'arrived',
  start: 'in_progress',
  finish: 'same',
  confirm_complete: 'completed',
  auto_complete: 'completed',
  search_timeout: 'no_match',
  customer_cancel: 'cancelled_by_customer',
  photographer_cancel: 'searching',
  report_no_show: 'no_show_customer',
  open_dispute: 'disputed',
};

/** A photographer holds at most one of these (unique index instant_requests_one_open_job). */
export const OPEN_JOB_STATUSES: readonly InstantRequestStatus[] = ['assigned', 'en_route', 'arrived', 'in_progress'];

/** No event leaves these. `completed` still accepts open_dispute inside its window. */
export const TERMINAL_STATUSES: readonly InstantRequestStatus[] = [
  'payment_failed',
  'no_match',
  'cancelled_by_customer',
  'no_show_customer',
  'disputed',
];

/** A customer holds at most one request in these at a time. */
export const ACTIVE_STATUSES: readonly InstantRequestStatus[] = [
  'pending_payment',
  'searching',
  'assigned',
  'en_route',
  'arrived',
  'in_progress',
];

export interface RequestSnapshot {
  status: InstantRequestStatus;
  assignedAt: Date | null;
  arrivedAt: Date | null;
  finishedAt: Date | null;
  completedAt: Date | null;
}

/** Columns the service writes with the new status (instant_requests). */
export interface TransitionPatch {
  assignedAt?: Date | null;
  arrivedAt?: Date;
  startedAt?: Date;
  finishedAt?: Date;
  completedAt?: Date;
  cancelledAt?: Date;
  /** photographer_cancel: photographer_id back to null, the request searches again. */
  clearPhotographer?: true;
}

export type TransitionResult =
  | { ok: true; from: InstantRequestStatus; to: InstantRequestStatus; patch: TransitionPatch }
  | { ok: false; code: 'conflict'; reason: string };

const refuse = (reason: string): TransitionResult => ({ ok: false, code: 'conflict', reason });

export function canStartFrom(event: InstantEvent, status: InstantRequestStatus): boolean {
  return TRANSITIONS[event].includes(status);
}

export function transition(
  s: RequestSnapshot,
  event: InstantEvent,
  now: Date,
  cfg: Pick<DispatchConfig, 'completion' | 'cancellation'>,
): TransitionResult {
  if (!canStartFrom(event, s.status)) return refuse(`${event} is not allowed from ${s.status}`);
  const t = now.getTime();
  const patch: TransitionPatch = {};
  switch (event) {
    case 'accept':
      patch.assignedAt = now;
      break;
    case 'arrive':
      patch.arrivedAt = now;
      break;
    case 'start':
      patch.startedAt = now;
      break;
    case 'finish':
      if (s.finishedAt !== null) return refuse('already finished');
      patch.finishedAt = now;
      break;
    case 'confirm_complete':
      if (s.finishedAt === null) return refuse('the photographer has not finished yet');
      patch.completedAt = now;
      break;
    case 'auto_complete':
      if (s.finishedAt === null) return refuse('the photographer has not finished yet');
      if (t < s.finishedAt.getTime() + cfg.completion.autoCompleteMs) return refuse('auto-complete is not due yet');
      patch.completedAt = now;
      break;
    case 'customer_cancel':
      patch.cancelledAt = now;
      break;
    case 'photographer_cancel':
      patch.clearPhotographer = true;
      patch.assignedAt = null;
      break;
    case 'report_no_show':
      if (s.arrivedAt === null || t < s.arrivedAt.getTime() + cfg.cancellation.noShowWaitMs) {
        return refuse('the customer still has time to arrive');
      }
      patch.cancelledAt = now;
      break;
    case 'open_dispute':
      if (s.completedAt === null || t > s.completedAt.getTime() + cfg.completion.disputeWindowMs) {
        return refuse('the dispute window is closed');
      }
      break;
    case 'payment_succeeded':
    case 'payment_failed':
    case 'start_route':
    case 'search_timeout':
      break;
  }
  const target = TARGET[event];
  return { ok: true, from: s.status, to: target === 'same' ? s.status : target, patch };
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './state-machine.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 206`, `ℹ pass 206`, `ℹ fail 0` (168 generated pair tests + 8 guard tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): instant request state machine with every allowed and refused transition tested

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Distance and the ETA estimate (straight line × 1.4 at 20 km/h)

**Files:**
- Create: `packages/dispatch-core/src/geo.ts`, `packages/dispatch-core/test/geo.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `DispatchConfig['eta']`, `LatLng`.
- Produces: `isLatLng(v: unknown): v is LatLng`; `haversineKm(a: LatLng, b: LatLng): number`; `distanceM(a, b): number`; `interface EtaEstimate { distanceKm: number; minutes: number }`; `estimateEta(from, to, cfg: Pick<DispatchConfig, 'eta'>): EtaEstimate` (distance to one decimal, minutes rounded up, at least 1).

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/geo.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, distanceM, estimateEta, haversineKm, isLatLng } from '../src/index.js';

const BEN_THANH = { lat: 10.7725, lng: 106.698 };
const NHA_THO_DUC_BA = { lat: 10.7798, lng: 106.699 };
const HO_GUOM = { lat: 21.0287, lng: 105.8524 };
/** Kilometres per degree of latitude on the haversine sphere. */
const KM_PER_DEG = (Math.PI * 6371.0088) / 180;

describe('haversine', () => {
  test('known distances', () => {
    assert.equal(haversineKm(BEN_THANH, BEN_THANH), 0);
    const km = haversineKm(BEN_THANH, NHA_THO_DUC_BA);
    assert.ok(km > 0.8 && km < 0.83, String(km));
    const hcmHn = haversineKm(BEN_THANH, HO_GUOM);
    assert.ok(hcmHn > 1135 && hcmHn < 1145, String(hcmHn));
    assert.ok(Math.abs(distanceM(BEN_THANH, NHA_THO_DUC_BA) - km * 1000) < 1e-6);
  });
  test('one degree of latitude ≈ 111.2 km', () => {
    const km = haversineKm({ lat: 0, lng: 0 }, { lat: 1, lng: 0 });
    assert.ok(Math.abs(km - 111.195) < 0.01, String(km));
  });
  test('isLatLng', () => {
    assert.equal(isLatLng(BEN_THANH), true);
    for (const bad of [null, {}, { lat: 91, lng: 0 }, { lat: 0, lng: 181 }, { lat: Number.NaN, lng: 0 }, { lat: '1', lng: 2 }]) {
      assert.equal(isLatLng(bad), false, JSON.stringify(bad));
    }
  });
});

describe('ETA estimate: straight line × 1.4 at 20 km/h (spec §3.2)', () => {
  test('10 km → 42 minutes', () => {
    const from = { lat: 0, lng: 0 };
    const to = { lat: 10 / KM_PER_DEG, lng: 0 };
    assert.deepEqual(estimateEta(from, to, DEFAULT_CONFIG), { distanceKm: 10, minutes: 42 });
  });
  test('rounds minutes up, never below 1, distance to one decimal', () => {
    assert.deepEqual(estimateEta(BEN_THANH, BEN_THANH, DEFAULT_CONFIG), { distanceKm: 0, minutes: 1 });
    const e = estimateEta(BEN_THANH, NHA_THO_DUC_BA, DEFAULT_CONFIG);
    assert.deepEqual(e, { distanceKm: 0.8, minutes: 4 }); // 0.82 km × 1.4 / 20 km/h = 3.4 min → 4
  });
  test('the config drives it', () => {
    const from = { lat: 0, lng: 0 };
    const to = { lat: 10 / KM_PER_DEG, lng: 0 };
    assert.equal(estimateEta(from, to, { eta: { detourFactor: 1, speedKmh: 60, normMaxMin: 45 } }).minutes, 10);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `distanceM`, `estimateEta`, `haversineKm`, `isLatLng`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/geo.ts
import type { DispatchConfig } from './config.js';
import type { LatLng } from './types.js';

const EARTH_RADIUS_KM = 6371.0088;
const rad = (deg: number): number => (deg * Math.PI) / 180;

export function isLatLng(v: unknown): v is LatLng {
  if (typeof v !== 'object' || v === null) return false;
  const { lat, lng } = v as { lat?: unknown; lng?: unknown };
  return (
    typeof lat === 'number' && typeof lng === 'number' &&
    Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
  );
}

/** Great-circle distance (haversine). */
export function haversineKm(a: LatLng, b: LatLng): number {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

export const distanceM = (a: LatLng, b: LatLng): number => haversineKm(a, b) * 1000;

export interface EtaEstimate {
  /** Straight-line distance, one decimal (InstantOfferMirror.distanceKm). */
  distanceKm: number;
  /** Whole minutes, at least 1 (InstantOfferMirror.travelMinutes, InstantRequestMirror.etaMinutes). */
  minutes: number;
}

/**
 * Spec §3.2: straight line × detourFactor at speedKmh. Used for scoring every candidate and as the
 * fallback ETA when Goong fails (§10). Never calls a map API.
 */
export function estimateEta(from: LatLng, to: LatLng, cfg: Pick<DispatchConfig, 'eta'>): EtaEstimate {
  const km = haversineKm(from, to);
  // 1e-9 keeps float noise (10.0000000001 km) from adding a whole minute.
  const minutes = Math.max(1, Math.ceil(((km * cfg.eta.detourFactor) / cfg.eta.speedKmh) * 60 - 1e-9));
  return { distanceKm: Math.round(km * 10) / 10, minutes };
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './geo.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 212`, `ℹ pass 212`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): haversine distance and the straight-line ETA estimate

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Pricing: package × surge, rounded to 1,000 ₫, payout rate

**Files:**
- Create: `packages/dispatch-core/src/pricing.ts`, `packages/dispatch-core/test/pricing.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `DispatchConfig['pricing']`.
- Produces: `parseSurge(v: string | number): number` (hundredths 100..300, from `numeric(3,2)` text); `formatSurge(hundredths): number`; `MAX_SHARE_BASE`; `assertVnd(v: number): void`; `shareVnd(amountVnd: number, bps: number): number` (floor); `interface PriceQuote { amountVnd; payoutVnd; platformVnd }`; `quotePrice(basePriceVnd: number, surgeHundredths: number, cfg: Pick<DispatchConfig, 'pricing'>): PriceQuote`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/pricing.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, parseSurge, quotePrice, seededRng, shareVnd } from '../src/index.js';

describe('surge', () => {
  test('numeric(3,2) text and numbers become hundredths', () => {
    assert.equal(parseSurge('1.00'), 100);
    assert.equal(parseSurge('1.2'), 120);
    assert.equal(parseSurge('2.35'), 235);
    assert.equal(parseSurge(1.15), 115);
    assert.equal(parseSurge('3.00'), 300);
  });
  test('outside 1.00..3.00 or malformed is refused', () => {
    for (const bad of ['0.99', '3.01', '1.234', 'abc', '', '-1']) assert.throws(() => parseSurge(bad), RangeError, bad);
  });
});

describe('price = package × surge, rounded half up to 1,000 ₫; payout 80 % (spec §4)', () => {
  const cases: Array<[number, number, number, number]> = [
    // base, surge, amount, payout
    [500_000, 100, 500_000, 400_000],
    [500_000, 120, 600_000, 480_000],
    [450_000, 115, 518_000, 414_400], // 517,500 → 518,000 (half up)
    [450_000, 111, 500_000, 400_000], // 499,500 → 500,000
    [333_333, 100, 333_000, 266_400], // 333,333 → 333,000
  ];
  test('table', () => {
    for (const [base, surge, amount, payout] of cases) {
      const q = quotePrice(base, surge, DEFAULT_CONFIG);
      assert.deepEqual(q, { amountVnd: amount, payoutVnd: payout, platformVnd: amount - payout }, `${base} × ${surge}`);
    }
  });
  test('large prices stay exact', () => {
    // 1,234,567 × 1.75 = 2,160,492.25 → 2,160,000
    assert.deepEqual(quotePrice(1_234_567, 175, DEFAULT_CONFIG), { amountVnd: 2_160_000, payoutVnd: 1_728_000, platformVnd: 432_000 });
  });
  test('never below one rounding step', () => {
    assert.equal(quotePrice(100, 100, DEFAULT_CONFIG).amountVnd, 1_000);
  });
  test('payoutRate is configurable', () => {
    assert.deepEqual(quotePrice(500_000, 100, { pricing: { payoutRateBps: 7_500, roundToVnd: 1_000 } }), {
      amountVnd: 500_000, payoutVnd: 375_000, platformVnd: 125_000,
    });
  });
  test('invalid input is refused', () => {
    assert.throws(() => quotePrice(0, 100, DEFAULT_CONFIG), RangeError);
    assert.throws(() => quotePrice(1.5, 100, DEFAULT_CONFIG), RangeError);
    assert.throws(() => quotePrice(500_000, 99, DEFAULT_CONFIG), RangeError);
    assert.throws(() => quotePrice(500_000, 1.2, DEFAULT_CONFIG), RangeError);
  });
  test('property: amount is a multiple of 1,000 within ±500 ₫ of base × surge; payout + platform = amount', () => {
    const rng = seededRng(7);
    for (let i = 0; i < 20_000; i++) {
      const base = 1_000 + Math.floor(rng() * 20_000_000);
      const surge = 100 + Math.floor(rng() * 201);
      const q = quotePrice(base, surge, DEFAULT_CONFIG);
      assert.equal(q.amountVnd % 1_000, 0);
      assert.ok(Math.abs(q.amountVnd - (base * surge) / 100) <= 500, `${base} × ${surge}`);
      assert.equal(q.payoutVnd + q.platformVnd, q.amountVnd);
      assert.ok(q.payoutVnd >= 0 && q.platformVnd >= 0);
    }
  });
  test('shareVnd rounds down', () => {
    assert.equal(shareVnd(999, 5_000), 499);
    assert.equal(shareVnd(1_000, 2_000), 200);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `parseSurge`, `quotePrice`, `shareVnd`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/pricing.ts
import type { DispatchConfig } from './config.js';

/**
 * Surge as an integer number of hundredths (numeric(3,2) "1.20" → 120), 100..300
 * (dispatch.cities check constraint). Integers keep the money maths exact.
 */
export function parseSurge(v: string | number): number {
  const text = typeof v === 'number' ? v.toFixed(2) : v.trim();
  if (!/^\d+(\.\d{1,2})?$/.test(text)) throw new RangeError(`surge ${String(v)} is not a decimal with ≤ 2 places`);
  const [whole = '0', frac = ''] = text.split('.');
  const hundredths = Number(whole) * 100 + Number(frac.padEnd(2, '0'));
  if (hundredths < 100 || hundredths > 300) throw new RangeError(`surge ${text} must be within 1.00..3.00`);
  return hundredths;
}

export const formatSurge = (hundredths: number): number => hundredths / 100;

/** Largest amount whose basis-point product is still an exact JS integer. */
export const MAX_SHARE_BASE = Math.floor(Number.MAX_SAFE_INTEGER / 10_000);

/** Basis-point share, rounded down to the đồng (data-model README §2.3: the rest goes to "the remainder"). */
export function shareVnd(amountVnd: number, bps: number): number {
  assertVnd(amountVnd);
  if (!Number.isInteger(bps) || bps < 0 || bps > 10_000) throw new RangeError(`bps ${bps} must be 0..10000`);
  if (amountVnd > MAX_SHARE_BASE) throw new RangeError(`amount ${amountVnd} is too large for exact basis-point maths`);
  return Math.floor((amountVnd * bps) / 10_000);
}

export function assertVnd(v: number): void {
  if (!Number.isSafeInteger(v) || v < 0) throw new RangeError(`amount ${v} must be a non-negative integer VND`);
}

export interface PriceQuote {
  /** What the customer pays: package price × surge, rounded half up to roundToVnd. */
  amountVnd: number;
  /** What the photographer earns: floor(amount × payoutRate). */
  payoutVnd: number;
  /** Platform fee: amount − payout. */
  platformVnd: number;
}

/** Spec §4: price locked into the request at submission time. */
export function quotePrice(
  basePriceVnd: number,
  surgeHundredths: number,
  cfg: Pick<DispatchConfig, 'pricing'>,
): PriceQuote {
  assertVnd(basePriceVnd);
  if (basePriceVnd === 0) throw new RangeError('package price must be > 0');
  if (!Number.isInteger(surgeHundredths) || surgeHundredths < 100 || surgeHundredths > 300) {
    throw new RangeError(`surge ${surgeHundredths} must be 100..300 hundredths`);
  }
  const step = cfg.pricing.roundToVnd;
  // base × surge is in hundredths of a đồng; round half up to `step` đồng.
  const unit = 100 * step;
  const amountVnd = Math.max(step, Math.floor((basePriceVnd * surgeHundredths + unit / 2) / unit) * step);
  const payoutVnd = shareVnd(amountVnd, cfg.pricing.payoutRateBps);
  return { amountVnd, payoutVnd, platformVnd: amountVnd - payoutVnd };
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './pricing.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 221`, `ℹ pass 221`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): instant pricing with city surge, 1,000 VND rounding and payout rate

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Cancellation and no-show money table (spec §4)

**Files:**
- Create: `packages/dispatch-core/src/cancellation.ts`, `packages/dispatch-core/test/cancellation.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `shareVnd`, `assertVnd` (Task 5); `DispatchError` (Task 1); `DispatchConfig['cancellation']` (Task 2).
- Produces:
  - `interface MoneySplit { refundVnd; photographerVnd; platformVnd }`.
  - `interface CancelQuote extends MoneySplit { rule: CancelRule; graceEndsAt: Date | null; nextStatus: InstantRequestStatus; settlesNow: boolean; reliabilityPenalty: 'cancelled' | 'no_show' | null }`.
  - `interface CancelContext { actor: 'customer' | 'photographer'; status; collectedVnd; assignedAt; arrivedAt; lateDeadline: Date | null; now: Date }`.
  - `quoteCancel(ctx, cfg): CancelQuote` (throws `DispatchError('conflict')` where cancelling is not allowed), `graceEndsAt(assignedAt, cfg)`, `lateDeadline(assignedAt, initialEtaMinutes, cfg)`, `settleCompleted(collectedVnd, payoutVnd): MoneySplit`, `settleNoMatch(collectedVnd): MoneySplit`.

The table as implemented (amounts for a 600,000 ₫ request):

| Who / when | Rule | Refund | Photographer | Platform | Next status |
|---|---|---|---|---|---|
| Customer, `pending_payment` or `searching` | `free_searching` | 100 % (0 before payment) | 0 | 0 | `cancelled_by_customer` |
| Customer, `assigned`/`en_route`, < 2 min after assigned | `free_grace` | 600,000 | 0 | 0 | `cancelled_by_customer` |
| Customer, `assigned`/`en_route`, past initial ETA + 15 min | `photographer_fault` (penalty `no_show`) | 600,000 | 0 | 0 | `cancelled_by_customer` |
| Customer, `assigned`/`en_route` after 2 min, or `arrived` | `en_route_fee` | 480,000 | 120,000 | 0 | `cancelled_by_customer` |
| Photographer, `assigned`/`en_route` | `photographer_cancel` (penalty `cancelled`, `settlesNow: false`) | 600,000 (guaranteed) | 0 | 0 | `searching` |
| Photographer, `arrived` ≥ 15 min | `no_show` | 300,000 | 300,000 | 0 | `no_show_customer` |
| `no_match` | `settleNoMatch` | 600,000 | 0 | 0 | |
| `completed` | `settleCompleted` | 0 | 480,000 | 120,000 | |

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/cancellation.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CANCEL_RULES, DEFAULT_CONFIG, DispatchError, lateDeadline, quoteCancel, seededRng, settleCompleted, settleNoMatch,
  type CancelContext, type CancelQuote, type CancelRule, type InstantRequestStatus,
} from '../src/index.js';

const T0 = new Date('2026-10-01T08:00:00.000Z');
const at = (min: number) => new Date(T0.getTime() + min * 60_000);
const AMOUNT = 600_000;

function ctx(over: Partial<CancelContext> & Pick<CancelContext, 'actor' | 'status'>): CancelContext {
  return { collectedVnd: AMOUNT, assignedAt: at(0), arrivedAt: null, lateDeadline: at(30), now: at(1), ...over };
}
const money = (q: CancelQuote) => [q.rule, q.refundVnd, q.photographerVnd, q.platformVnd];

describe('spec §4 table, row by row', () => {
  test('customer cancels while searching: 100 %', () => {
    const q = quoteCancel(ctx({ actor: 'customer', status: 'searching', assignedAt: null }), DEFAULT_CONFIG);
    assert.deepEqual(money(q), ['free_searching', 600_000, 0, 0]);
    assert.equal(q.nextStatus, 'cancelled_by_customer');
    assert.equal(q.graceEndsAt, null);
  });

  test('customer cancels before paying: nothing to refund', () => {
    const q = quoteCancel(ctx({ actor: 'customer', status: 'pending_payment', collectedVnd: 0, assignedAt: null }), DEFAULT_CONFIG);
    assert.deepEqual(money(q), ['free_searching', 0, 0, 0]);
  });

  test('customer cancels within 2 minutes of assigned: 100 %, grace end reported', () => {
    for (const status of ['assigned', 'en_route'] as const) {
      const q = quoteCancel(ctx({ actor: 'customer', status, now: new Date(at(2).getTime() - 1) }), DEFAULT_CONFIG);
      assert.deepEqual(money(q), ['free_grace', 600_000, 0, 0]);
      assert.deepEqual(q.graceEndsAt, at(2));
    }
  });

  test('customer cancels on the way after 2 minutes: 80 % back, photographer keeps 20 %', () => {
    const q = quoteCancel(ctx({ actor: 'customer', status: 'en_route', now: at(2) }), DEFAULT_CONFIG);
    assert.deepEqual(money(q), ['en_route_fee', 480_000, 120_000, 0]);
    assert.equal(q.reliabilityPenalty, null);
  });

  test('customer cancels after the photographer arrived: same fee as on the way', () => {
    const q = quoteCancel(ctx({ actor: 'customer', status: 'arrived', arrivedAt: at(10), now: at(12) }), DEFAULT_CONFIG);
    assert.deepEqual(money(q), ['en_route_fee', 480_000, 120_000, 0]);
  });

  test('photographer later than ETA + 15 min: customer cancels for 100 %, photographer penalised', () => {
    const q = quoteCancel(ctx({ actor: 'customer', status: 'en_route', lateDeadline: at(30), now: at(30) }), DEFAULT_CONFIG);
    assert.deepEqual(money(q), ['photographer_fault', 600_000, 0, 0]);
    assert.equal(q.reliabilityPenalty, 'no_show');
    const early = quoteCancel(ctx({ actor: 'customer', status: 'en_route', lateDeadline: at(30), now: at(29) }), DEFAULT_CONFIG);
    assert.equal(early.rule, 'en_route_fee');
  });

  test('photographer cancels: customer keeps 100 %, the request searches again, nothing settles now', () => {
    for (const status of ['assigned', 'en_route'] as const) {
      const q = quoteCancel(ctx({ actor: 'photographer', status }), DEFAULT_CONFIG);
      assert.deepEqual(money(q), ['photographer_cancel', 600_000, 0, 0]);
      assert.equal(q.nextStatus, 'searching');
      assert.equal(q.settlesNow, false);
      assert.equal(q.reliabilityPenalty, 'cancelled');
    }
  });

  test('photographer reports a no-show after waiting 15 minutes: 50 / 50', () => {
    const q = quoteCancel(ctx({ actor: 'photographer', status: 'arrived', arrivedAt: at(10), now: at(25) }), DEFAULT_CONFIG);
    assert.deepEqual(money(q), ['no_show', 300_000, 300_000, 0]);
    assert.equal(q.nextStatus, 'no_show_customer');
  });

  test('photographer cannot report a no-show before 15 minutes', () => {
    assert.throws(
      () => quoteCancel(ctx({ actor: 'photographer', status: 'arrived', arrivedAt: at(10), now: at(24) }), DEFAULT_CONFIG),
      (e: unknown) => e instanceof DispatchError && e.code === 'conflict',
    );
  });

  test('no_match and completed', () => {
    assert.deepEqual(settleNoMatch(AMOUNT), { refundVnd: 600_000, photographerVnd: 0, platformVnd: 0 });
    assert.deepEqual(settleCompleted(AMOUNT, 480_000), { refundVnd: 0, photographerVnd: 480_000, platformVnd: 120_000 });
    assert.throws(() => settleCompleted(AMOUNT, 600_001), RangeError);
  });

  test('statuses where nobody may cancel', () => {
    const forbidden: Array<[CancelContext['actor'], InstantRequestStatus]> = [
      ['customer', 'in_progress'], ['customer', 'completed'], ['customer', 'no_match'], ['customer', 'payment_failed'],
      ['customer', 'cancelled_by_customer'], ['customer', 'no_show_customer'], ['customer', 'disputed'],
      ['photographer', 'pending_payment'], ['photographer', 'searching'], ['photographer', 'in_progress'],
      ['photographer', 'completed'], ['photographer', 'no_match'],
    ];
    for (const [actor, status] of forbidden) {
      assert.throws(() => quoteCancel(ctx({ actor, status }), DEFAULT_CONFIG), DispatchError, `${actor} ${status}`);
    }
  });

  test('lateDeadline = assigned + initial ETA + 15 minutes', () => {
    assert.deepEqual(lateDeadline(at(0), 12, DEFAULT_CONFIG), at(27));
    assert.throws(() => lateDeadline(at(0), 1.5, DEFAULT_CONFIG), RangeError);
  });
});

describe('property: refund + photographer + platform == collected, for every rule and many amounts', () => {
  const scenarios: Array<[CancelRule, (amount: number) => CancelContext]> = [
    ['free_searching', (a) => ctx({ actor: 'customer', status: 'searching', collectedVnd: a, assignedAt: null })],
    ['free_grace', (a) => ctx({ actor: 'customer', status: 'assigned', collectedVnd: a, now: at(1) })],
    ['en_route_fee', (a) => ctx({ actor: 'customer', status: 'en_route', collectedVnd: a, now: at(5) })],
    ['no_show', (a) => ctx({ actor: 'photographer', status: 'arrived', collectedVnd: a, arrivedAt: at(0), now: at(15) })],
    ['photographer_fault', (a) => ctx({ actor: 'customer', status: 'en_route', collectedVnd: a, now: at(31) })],
    ['photographer_cancel', (a) => ctx({ actor: 'photographer', status: 'en_route', collectedVnd: a })],
  ];

  test('the scenarios cover every CancelRule', () => {
    assert.deepEqual(scenarios.map(([r]) => r).sort(), [...CANCEL_RULES].sort());
  });

  const rng = seededRng(2026);
  const amounts = [0, 1, 2, 3, 999, 1_000, 1_001, 4_999, 5_000, 99_999, 500_000, 517_500, Math.floor(Number.MAX_SAFE_INTEGER / 10_000)];
  for (let i = 0; i < 20_000; i++) amounts.push(Math.floor(rng() * 50_000_000));

  for (const [rule, make] of scenarios) {
    test(`${rule}: ${amounts.length} amounts, no đồng lost or created`, () => {
      for (const a of amounts) {
        const q = quoteCancel(make(a), DEFAULT_CONFIG);
        assert.equal(q.rule, rule);
        assert.equal(q.refundVnd + q.photographerVnd + q.platformVnd, a, `${rule} ${a}`);
        for (const v of [q.refundVnd, q.photographerVnd, q.platformVnd]) assert.ok(Number.isSafeInteger(v) && v >= 0, `${rule} ${a}`);
      }
    });
  }

  test('completion and no_match too', () => {
    for (const a of amounts) {
      const payout = Math.floor((a * 8_000) / 10_000);
      const c = settleCompleted(a, payout);
      assert.equal(c.refundVnd + c.photographerVnd + c.platformVnd, a);
      const n = settleNoMatch(a);
      assert.equal(n.refundVnd + n.photographerVnd + n.platformVnd, a);
    }
  });

  test('refused amounts', () => {
    for (const bad of [-1, 1.5, Number.NaN]) {
      assert.throws(() => quoteCancel(ctx({ actor: 'customer', status: 'searching', collectedVnd: bad }), DEFAULT_CONFIG), RangeError);
    }
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `lateDeadline`, `quoteCancel`, `settleCompleted`, `settleNoMatch`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/cancellation.ts
import type { DispatchConfig } from './config.js';
import { DispatchError } from './errors.js';
import { assertVnd, shareVnd } from './pricing.js';
import type { CancelRule, InstantRequestStatus } from './types.js';

/**
 * Spec §4 money table. Every quote satisfies refundVnd + photographerVnd + platformVnd = collectedVnd,
 * all three non-negative integers (tested over many amounts).
 */
export interface MoneySplit {
  refundVnd: number;
  photographerVnd: number;
  platformVnd: number;
}

export interface CancelQuote extends MoneySplit {
  rule: CancelRule;
  /** End of the free 2-minute window after assigned (null before assigned). */
  graceEndsAt: Date | null;
  /** Status after the cancellation. photographer_cancel goes back to searching. */
  nextStatus: InstantRequestStatus;
  /** false: no money moves now (photographer_cancel: the request searches again). */
  settlesNow: boolean;
  /** Counter of photographer_reliability to increment, if any. */
  reliabilityPenalty: 'cancelled' | 'no_show' | null;
}

export interface CancelContext {
  actor: 'customer' | 'photographer';
  status: InstantRequestStatus;
  /** What the gateway confirmed (0 while pending_payment). */
  collectedVnd: number;
  assignedAt: Date | null;
  arrivedAt: Date | null;
  /** assignedAt + initial ETA + lateToleranceMs (lateDeadline()); null when unknown. */
  lateDeadline: Date | null;
  now: Date;
}

type Cfg = Pick<DispatchConfig, 'cancellation'>;

const full = (collected: number): MoneySplit => ({ refundVnd: collected, photographerVnd: 0, platformVnd: 0 });

function keep(collected: number, photographerBps: number): MoneySplit {
  const photographerVnd = shareVnd(collected, photographerBps);
  return { refundVnd: collected - photographerVnd, photographerVnd, platformVnd: 0 };
}

export function graceEndsAt(assignedAt: Date | null, cfg: Cfg): Date | null {
  return assignedAt === null ? null : new Date(assignedAt.getTime() + cfg.cancellation.graceMs);
}

/** §4 / §10: the photographer is "late" past the initial ETA plus 15 minutes. */
export function lateDeadline(assignedAt: Date, initialEtaMinutes: number, cfg: Cfg): Date {
  if (!Number.isInteger(initialEtaMinutes) || initialEtaMinutes < 0) throw new RangeError('initial ETA must be whole minutes ≥ 0');
  return new Date(assignedAt.getTime() + initialEtaMinutes * 60_000 + cfg.cancellation.lateToleranceMs);
}

/** Throws DispatchError('conflict') when the actor may not cancel in this status (yet). */
export function quoteCancel(ctx: CancelContext, cfg: Cfg): CancelQuote {
  assertVnd(ctx.collectedVnd);
  const t = ctx.now.getTime();
  const grace = graceEndsAt(ctx.assignedAt, cfg);
  const quote = (
    rule: CancelRule,
    split: MoneySplit,
    nextStatus: InstantRequestStatus,
    extra: Partial<Pick<CancelQuote, 'settlesNow' | 'reliabilityPenalty'>> = {},
  ): CancelQuote => ({
    rule,
    ...split,
    graceEndsAt: grace,
    nextStatus,
    settlesNow: extra.settlesNow ?? true,
    reliabilityPenalty: extra.reliabilityPenalty ?? null,
  });

  if (ctx.actor === 'customer') {
    switch (ctx.status) {
      case 'pending_payment':
      case 'searching':
        return quote('free_searching', full(ctx.collectedVnd), 'cancelled_by_customer');
      case 'assigned':
      case 'en_route':
        if (grace !== null && t < grace.getTime()) {
          return quote('free_grace', full(ctx.collectedVnd), 'cancelled_by_customer');
        }
        if (ctx.lateDeadline !== null && t >= ctx.lateDeadline.getTime()) {
          return quote('photographer_fault', full(ctx.collectedVnd), 'cancelled_by_customer', {
            reliabilityPenalty: 'no_show',
          });
        }
        return quote('en_route_fee', keep(ctx.collectedVnd, cfg.cancellation.enRouteFeeBps), 'cancelled_by_customer');
      case 'arrived':
        // The photographer is there: same fee as a late cancellation on the way.
        return quote('en_route_fee', keep(ctx.collectedVnd, cfg.cancellation.enRouteFeeBps), 'cancelled_by_customer');
      default:
        throw new DispatchError('conflict', { reason: `customer cannot cancel in ${ctx.status}` });
    }
  }

  switch (ctx.status) {
    case 'assigned':
    case 'en_route':
      return quote('photographer_cancel', full(ctx.collectedVnd), 'searching', {
        settlesNow: false,
        reliabilityPenalty: 'cancelled',
      });
    case 'arrived': {
      const waitedEnough = ctx.arrivedAt !== null && t >= ctx.arrivedAt.getTime() + cfg.cancellation.noShowWaitMs;
      if (!waitedEnough) throw new DispatchError('conflict', { reason: 'wait for the customer before reporting a no-show' });
      return quote('no_show', keep(ctx.collectedVnd, cfg.cancellation.noShowPhotographerBps), 'no_show_customer');
    }
    default:
      throw new DispatchError('conflict', { reason: `photographer cannot cancel in ${ctx.status}` });
  }
}

/** completed: the photographer's payout and the platform fee, nothing refunded. */
export function settleCompleted(collectedVnd: number, payoutVnd: number): MoneySplit {
  assertVnd(collectedVnd);
  assertVnd(payoutVnd);
  if (payoutVnd > collectedVnd) throw new RangeError('payout cannot exceed the amount collected');
  return { refundVnd: 0, photographerVnd: payoutVnd, platformVnd: collectedVnd - payoutVnd };
}

/** no_match (and payment never captured twice): everything back. */
export function settleNoMatch(collectedVnd: number): MoneySplit {
  assertVnd(collectedVnd);
  return full(collectedVnd);
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './cancellation.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 242`, `ℹ pass 242`, `ℹ fail 0` (the six property tests each check 20,013 amounts).

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): cancellation and no-show money table with the no-dong-lost property test

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Readiness and eligibility tiers (priority vs expanded)

**Files:**
- Create: `packages/dispatch-core/src/eligibility.ts`, `packages/dispatch-core/test/eligibility.test.ts`, `packages/dispatch-core/test/support/facts.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `DispatchConfig['eligibility']`, `EligibilityReason`.
- Produces:
  - `interface PhotographerFacts { uid; onboardingComplete; hasPhone; verified; ratingAvg: number | null; reviewCount; acceptedPriceListVersion: number | null; helpReady; reliability { offers; accepted; cancelled; noShow }; specialtyLevels: Readonly<Record<string, 1 | 2 | 3>> | null }` (plan I3 builds it from PostgreSQL and caches it in Redis as JSON).
  - `interface ReadinessContext { currentPriceListVersion; inCity; hasLocation }`; `readinessReasons(f, ctx): EligibilityReason[]` (contract order; `location_denied` replaces `outside_city` when there is no fix).
  - `cancelRate(r): number`; `type QualityCheck = 'verified' | 'rating' | 'cancel_rate'`; `meetsQualityBar(f, cfg): { ok; waived: QualityCheck[]; failed: QualityCheck[] }`.
  - `type Tier = 'priority' | 'expanded'`; `tierOf(f, currentPriceListVersion, cfg): Tier | null`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/support/facts.ts
import type { PhotographerFacts } from '../../src/index.js';

/** A ready photographer who meets the quality bar; override what a test needs. */
export function facts(over: Partial<PhotographerFacts> & { uid: string }): PhotographerFacts {
  return {
    onboardingComplete: true,
    hasPhone: true,
    verified: true,
    ratingAvg: 4.8,
    reviewCount: 20,
    acceptedPriceListVersion: 3,
    helpReady: false,
    reliability: { offers: 40, accepted: 30, cancelled: 1, noShow: 0 },
    specialtyLevels: { portrait: 3, couple: 2 },
    ...over,
  };
}
```

```ts
// packages/dispatch-core/test/eligibility.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, cancelRate, meetsQualityBar, readinessReasons, tierOf } from '../src/index.js';
import { facts } from './support/facts.js';

const CTX = { currentPriceListVersion: 3, inCity: true, hasLocation: true };

describe('readiness (who may switch on "Sẵn sàng chụp ngay", spec §2.2)', () => {
  test('a complete photographer is ready', () => {
    assert.deepEqual(readinessReasons(facts({ uid: 'p' }), CTX), []);
  });
  test('every missing condition is reported, in contract order', () => {
    const f = facts({ uid: 'p', onboardingComplete: false, hasPhone: false, acceptedPriceListVersion: 2 });
    assert.deepEqual(readinessReasons(f, { ...CTX, inCity: false }), ['profile_incomplete', 'no_phone', 'price_list_not_accepted', 'outside_city']);
    assert.deepEqual(readinessReasons(facts({ uid: 'p', acceptedPriceListVersion: null }), CTX), ['price_list_not_accepted']);
  });
  test('no location fix means location_denied (city unknown, so not also outside_city)', () => {
    assert.deepEqual(readinessReasons(facts({ uid: 'p' }), { ...CTX, hasLocation: false, inCity: false }), ['location_denied']);
  });
});

describe('quality bar of the priority tier (spec §3.2)', () => {
  test('verified, rating ≥ 4.5 with ≥ 5 reviews, cancel rate ≤ 10 % with ≥ 10 jobs', () => {
    assert.deepEqual(meetsQualityBar(facts({ uid: 'p' }), DEFAULT_CONFIG), { ok: true, waived: [], failed: [] });
  });
  test('rating 4.49 with enough reviews fails; exactly 4.5 passes', () => {
    assert.deepEqual(meetsQualityBar(facts({ uid: 'p', ratingAvg: 4.49 }), DEFAULT_CONFIG).failed, ['rating']);
    assert.equal(meetsQualityBar(facts({ uid: 'p', ratingAvg: 4.5 }), DEFAULT_CONFIG).ok, true);
  });
  test('cancel rate just above 10 % fails; exactly 10 % passes', () => {
    const over = facts({ uid: 'p', reliability: { offers: 40, accepted: 30, cancelled: 3, noShow: 1 } });
    assert.deepEqual(meetsQualityBar(over, DEFAULT_CONFIG).failed, ['cancel_rate']);
    const edge = facts({ uid: 'p', reliability: { offers: 40, accepted: 30, cancelled: 2, noShow: 1 } });
    assert.equal(cancelRate(edge.reliability), 0.1);
    assert.equal(meetsQualityBar(edge, DEFAULT_CONFIG).ok, true);
  });
  test('not enough data: only "verified" is required', () => {
    const fresh = facts({ uid: 'p', ratingAvg: 3.0, reviewCount: 4, reliability: { offers: 9, accepted: 9, cancelled: 5, noShow: 0 } });
    assert.deepEqual(meetsQualityBar(fresh, DEFAULT_CONFIG), { ok: true, waived: ['rating', 'cancel_rate'], failed: [] });
    assert.deepEqual(meetsQualityBar({ ...fresh, verified: false }, DEFAULT_CONFIG).failed, ['verified']);
    const noReviews = facts({ uid: 'p', ratingAvg: null, reviewCount: 0 });
    assert.deepEqual(meetsQualityBar(noReviews, DEFAULT_CONFIG).waived, ['rating']);
  });
});

describe('tiers', () => {
  test('quality bar → priority; helpReady → priority even below the bar; otherwise expanded', () => {
    assert.equal(tierOf(facts({ uid: 'a' }), 3, DEFAULT_CONFIG), 'priority');
    assert.equal(tierOf(facts({ uid: 'b', verified: false, helpReady: true }), 3, DEFAULT_CONFIG), 'priority');
    assert.equal(tierOf(facts({ uid: 'c', verified: false }), 3, DEFAULT_CONFIG), 'expanded');
    assert.equal(tierOf(facts({ uid: 'd', ratingAvg: 4.0 }), 3, DEFAULT_CONFIG), 'expanded');
  });
  test('not ready → no tier at all', () => {
    assert.equal(tierOf(facts({ uid: 'e', acceptedPriceListVersion: 2 }), 3, DEFAULT_CONFIG), null);
    assert.equal(tierOf(facts({ uid: 'f', onboardingComplete: false, helpReady: true }), 3, DEFAULT_CONFIG), null);
    assert.equal(tierOf(facts({ uid: 'g', hasPhone: false }), 3, DEFAULT_CONFIG), null);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `cancelRate`, `meetsQualityBar`, `readinessReasons`, `tierOf`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/eligibility.ts
import type { DispatchConfig } from './config.js';
import type { EligibilityReason } from './types.js';

/** What dispatch knows about a photographer (PostgreSQL rows, cached in Redis by the service). */
export interface PhotographerFacts {
  uid: string;
  /** photographers.onboarding_complete (S08.01 + S08.05 done). */
  onboardingComplete: boolean;
  /** photographer_contact_numbers row exists. */
  hasPhone: boolean;
  verified: boolean;
  /** photographers.rating_avg; null when there is no review. */
  ratingAvg: number | null;
  reviewCount: number;
  /** photographer_instant_settings.price_list_version_accepted. */
  acceptedPriceListVersion: number | null;
  /** photographer_instant_settings.help_ready ("Sẵn sàng hỗ trợ"). */
  helpReady: boolean;
  /** photographer_reliability counters. */
  reliability: { offers: number; accepted: number; cancelled: number; noShow: number };
  /** Specialty id → level 1..3 (S08.02). null: no skills data available at all. */
  specialtyLevels: Readonly<Record<string, 1 | 2 | 3>> | null;
}

export interface ReadinessContext {
  currentPriceListVersion: number;
  /** The photographer's location is inside an active city. */
  inCity: boolean;
  /** The app sent a location fix. */
  hasLocation: boolean;
}

/**
 * Why "Sẵn sàng chụp ngay" cannot be switched on (spec §2.2 step 1); empty = may go online.
 * Order follows the contract enum.
 */
export function readinessReasons(f: PhotographerFacts, ctx: ReadinessContext): EligibilityReason[] {
  const out: EligibilityReason[] = [];
  if (!f.onboardingComplete) out.push('profile_incomplete');
  if (!f.hasPhone) out.push('no_phone');
  if (f.acceptedPriceListVersion !== ctx.currentPriceListVersion) out.push('price_list_not_accepted');
  if (!ctx.hasLocation) out.push('location_denied');
  else if (!ctx.inCity) out.push('outside_city');
  return out;
}

/** Instant cancellation rate: (cancelled + no-show) per accepted job. */
export function cancelRate(r: PhotographerFacts['reliability']): number {
  return r.accepted === 0 ? 0 : (r.cancelled + r.noShow) / r.accepted;
}

export type QualityCheck = 'verified' | 'rating' | 'cancel_rate';

export interface QualityResult {
  ok: boolean;
  /** Checks skipped for lack of data ("chưa đủ dữ liệu thì chỉ cần đã xác minh"). */
  waived: QualityCheck[];
  failed: QualityCheck[];
}

/** Spec §3.2 "đạt chuẩn": verified, rating ≥ 4.5 with ≥ 5 reviews, cancel rate ≤ 10 % with ≥ 10 jobs. */
export function meetsQualityBar(f: PhotographerFacts, cfg: Pick<DispatchConfig, 'eligibility'>): QualityResult {
  const e = cfg.eligibility;
  const waived: QualityCheck[] = [];
  const failed: QualityCheck[] = [];
  if (!f.verified) failed.push('verified');
  if (f.reviewCount < e.minReviews || f.ratingAvg === null) waived.push('rating');
  else if (f.ratingAvg < e.minRating) failed.push('rating');
  if (f.reliability.accepted < e.minJobsForCancelRate) waived.push('cancel_rate');
  else if (cancelRate(f.reliability) > e.maxCancelRate) failed.push('cancel_rate');
  return { ok: failed.length === 0, waived, failed };
}

export type Tier = 'priority' | 'expanded';

/**
 * Round 1 takes `priority` only; round 2 takes both.
 * priority = ready and (quality bar or helpReady); expanded = ready (profile complete and price list accepted).
 */
export function tierOf(
  f: PhotographerFacts,
  currentPriceListVersion: number,
  cfg: Pick<DispatchConfig, 'eligibility'>,
): Tier | null {
  const ready = f.onboardingComplete && f.hasPhone && f.acceptedPriceListVersion === currentPriceListVersion;
  if (!ready) return null;
  return f.helpReady || meetsQualityBar(f, cfg).ok ? 'priority' : 'expanded';
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './eligibility.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 251`, `ℹ pass 251`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): readiness reasons, quality bar with not-enough-data fallbacks, priority and expanded tiers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Scoring with reasons (the shared `Scorer` shape)

**Files:**
- Create: `packages/dispatch-core/src/scoring.ts`, `packages/dispatch-core/test/scoring.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `PhotographerFacts` (Task 7), `GENRE_SPECIALTY`, `Genre`, `Round` (Task 1), `DispatchConfig['scoring' | 'eta']`.
- Produces:
  - `interface Scorer<Candidate, Context, Code extends string> { readonly name: string; readonly version: string; score(candidate, context): Scored<Code> }`; `interface Scored<Code> { score: number; breakdown: Readonly<Record<string, number>>; reasons: ScoreReason<Code>[] }`; `interface ScoreReason<Code> { code; value; contribution; etaMinutes?; distanceKm? }` (same shape `packages/recommender-core` will implement for `rules-v1`; documented, not imported).
  - `DISPATCH_REASON_CODES` = `near`, `skill_match`, `top_rated`, `reliable`, `help_ready` (the first three are the recommender's codes with the same meaning); `type DispatchReasonCode`.
  - `clamp01`, `round4`, `weightedSum(weights, components)`, `etaComponent`, `genreComponent`, `ratingComponent`, `reliabilityComponent`.
  - `interface DispatchCandidate { facts; distanceKm; etaMinutes }`, `interface DispatchScoringContext { genre; round }`, `dispatchScorerV1(cfg): Scorer<DispatchCandidate, DispatchScoringContext, DispatchReasonCode>` (`name: 'dispatch-v1'`).
  - `etaFromReasons(reasons): number | null` (reads the `near` reason back from `instant_offers.reasons`).

Score = `0.45·eta + 0.25·genre + 0.15·rating + 0.15·reliability` (+ `0.05` with "Sẵn sàng hỗ trợ" in round 1), rounded to 4 decimals so it fits `numeric(5,4)` (max 1.05). Components: `eta = clamp01(1 − minutes / 45)`; `genre` = 1.0 / 0.7 / 0.4 for specialty level 3 / 2 / 1 of the requested genre (0 if not declared, 0.5 without skills data); `rating` = `((v·R + 10·4.3)/(v + 10) − 3) / 2`; `reliability` = smoothed accept rate × (1 − smoothed cancel rate) with priors 0.7 and 0.05 over 10 pseudo-observations.

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/scoring.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DEFAULT_CONFIG, dispatchScorerV1, etaComponent, etaFromReasons, genreComponent, ratingComponent, reliabilityComponent,
  weightedSum,
} from '../src/index.js';
import { facts } from './support/facts.js';

const scorer = dispatchScorerV1(DEFAULT_CONFIG);

describe('components, each in 0..1', () => {
  test('eta: 0 min → 1, 45 min or more → 0, linear between', () => {
    assert.equal(etaComponent(0, DEFAULT_CONFIG), 1);
    assert.equal(etaComponent(45, DEFAULT_CONFIG), 0);
    assert.equal(etaComponent(90, DEFAULT_CONFIG), 0);
    assert.ok(Math.abs(etaComponent(9, DEFAULT_CONFIG) - 0.8) < 1e-12);
  });
  test('genre: level 3/2/1 → 1.0/0.7/0.4; not declared → 0; no skills data → 0.5', () => {
    const f = facts({ uid: 'p', specialtyLevels: { portrait: 3, couple: 2, family: 1 } });
    assert.equal(genreComponent(f, 'portrait', DEFAULT_CONFIG), 1);
    assert.equal(genreComponent(f, 'couple', DEFAULT_CONFIG), 0.7);
    assert.equal(genreComponent(f, 'family', DEFAULT_CONFIG), 0.4);
    assert.equal(genreComponent(f, 'product', DEFAULT_CONFIG), 0);
    assert.equal(genreComponent(facts({ uid: 'q', specialtyLevels: { event: 2 } }), 'small_event', DEFAULT_CONFIG), 0.7);
    assert.equal(genreComponent(facts({ uid: 'r', specialtyLevels: null }), 'portrait', DEFAULT_CONFIG), 0.5);
  });
  test('rating: Bayesian smoothing toward 4.3, then (x − 3)/2', () => {
    // (20·4.8 + 10·4.3)/30 = 4.6333 → 0.81667
    assert.ok(Math.abs(ratingComponent(facts({ uid: 'p' }), DEFAULT_CONFIG) - 0.816667) < 1e-5);
    // no reviews → prior 4.3 → 0.65
    assert.ok(Math.abs(ratingComponent(facts({ uid: 'p', ratingAvg: null, reviewCount: 0 }), DEFAULT_CONFIG) - 0.65) < 1e-12);
    assert.equal(ratingComponent(facts({ uid: 'p', ratingAvg: 5, reviewCount: 100_000 }), DEFAULT_CONFIG) <= 1, true);
  });
  test('reliability: smoothed accept rate × (1 − smoothed cancel rate)', () => {
    // accept (30 + 7)/(40 + 10) = 0.74; cancel (1 + 0.5)/(30 + 10) = 0.0375 → 0.71225
    assert.ok(Math.abs(reliabilityComponent(facts({ uid: 'p' }), DEFAULT_CONFIG) - 0.71225) < 1e-9);
    // a newcomer sits at the prior: 0.7 × 0.95
    const fresh = facts({ uid: 'n', reliability: { offers: 0, accepted: 0, cancelled: 0, noShow: 0 } });
    assert.ok(Math.abs(reliabilityComponent(fresh, DEFAULT_CONFIG) - 0.665) < 1e-9);
  });
});

describe('dispatch-v1 score (spec §3.2)', () => {
  const c = { facts: facts({ uid: 'p' }), distanceKm: 1.3, etaMinutes: 6 };

  test('is the weighted sum, rounded to 4 decimals', () => {
    const s = scorer.score(c, { genre: 'portrait', round: 1 });
    const expected = 0.45 * (1 - 6 / 45) + 0.25 * 1 + 0.15 * ratingComponent(c.facts, DEFAULT_CONFIG) + 0.15 * 0.71225;
    assert.equal(s.score, Math.round(expected * 10_000) / 10_000);
    assert.equal(scorer.name, 'dispatch-v1');
  });

  test('helpReady adds 0.05 in round 1 only, and says so', () => {
    const help = { ...c, facts: facts({ uid: 'p', helpReady: true }) };
    const r1 = scorer.score(help, { genre: 'portrait', round: 1 });
    const r2 = scorer.score(help, { genre: 'portrait', round: 2 });
    assert.ok(Math.abs(r1.score - r2.score - 0.05) < 1e-9);
    assert.ok(r1.reasons.some((r) => r.code === 'help_ready'));
    assert.ok(!r2.reasons.some((r) => r.code === 'help_ready'));
  });

  test('reasons: every component, highest contribution first; near carries the ETA it was based on', () => {
    const s = scorer.score(c, { genre: 'portrait', round: 2 });
    assert.deepEqual(s.reasons.map((r) => r.code), ['near', 'skill_match', 'top_rated', 'reliable']);
    for (let i = 1; i < s.reasons.length; i++) {
      assert.ok((s.reasons[i - 1]?.contribution ?? 0) >= (s.reasons[i]?.contribution ?? 0));
    }
    assert.equal(etaFromReasons(s.reasons), 6);
    assert.equal(s.reasons.find((r) => r.code === 'near')?.distanceKm, 1.3);
    assert.equal(etaFromReasons(JSON.parse(JSON.stringify(s.reasons)) as typeof s.reasons), 6); // survives jsonb
  });

  test('closer wins when everything else is equal; genre can beat a little distance', () => {
    const near = scorer.score({ ...c, etaMinutes: 5 }, { genre: 'portrait', round: 2 }).score;
    const far = scorer.score({ ...c, etaMinutes: 20 }, { genre: 'portrait', round: 2 }).score;
    assert.ok(near > far);
    const specialist = scorer.score({ ...c, etaMinutes: 8 }, { genre: 'portrait', round: 2 }).score;
    const generalist = scorer.score({ ...c, etaMinutes: 6, facts: facts({ uid: 'g', specialtyLevels: {} }) }, { genre: 'portrait', round: 2 }).score;
    assert.ok(specialist > generalist);
  });

  test('score stays within numeric(5,4)', () => {
    const best = scorer.score({ facts: facts({ uid: 'b', helpReady: true, ratingAvg: 5, reviewCount: 1000 }), distanceKm: 0, etaMinutes: 0 }, { genre: 'portrait', round: 1 });
    assert.ok(best.score <= 1.05 && best.score >= 0);
  });

  test('weightedSum', () => {
    assert.equal(weightedSum({ a: 0.5, b: 0.5 }, { a: 1, b: 0 }), 0.5);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `dispatchScorerV1`, `etaComponent`, `etaFromReasons`, `genreComponent`, `ratingComponent`, `reliabilityComponent`, `weightedSum`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/scoring.ts
import type { DispatchConfig } from './config.js';
import type { PhotographerFacts } from './eligibility.js';
import { GENRE_SPECIALTY, type Genre, type Round } from './types.js';

/**
 * Scorer shape shared with packages/recommender-core (spec §3e.4: a named, versioned, pure Scorer
 * whose components are normalised to 0..1 and which explains itself with reason codes).
 * dispatch-core does not import recommender-core: both packages implement this same shape so a
 * later refactor can move it to one place without changing callers.
 */
export interface Scorer<Candidate, Context, Code extends string> {
  readonly name: string;
  readonly version: string;
  score(candidate: Candidate, context: Context): Scored<Code>;
}

export interface Scored<Code extends string> {
  /** Weighted sum (+ bonus), rounded to 4 decimals (dispatch.instant_offers.score numeric(5,4)). */
  score: number;
  /** Every component in 0..1, for logs. */
  breakdown: Readonly<Record<string, number>>;
  /** Every contributing component, highest contribution first (written to instant_offers.reasons). */
  reasons: ScoreReason<Code>[];
}

export interface ScoreReason<Code extends string> {
  code: Code;
  /** Component value 0..1. */
  value: number;
  /** weight × value (or the bonus itself). */
  contribution: number;
  /** Only on `near`: the estimate the offer was based on (initial ETA for the lateness rule). */
  etaMinutes?: number;
  distanceKm?: number;
}

/** Same codes as the recommender where the meaning is the same (`near`, `skill_match`, `top_rated`). */
export const DISPATCH_REASON_CODES = ['near', 'skill_match', 'top_rated', 'reliable', 'help_ready'] as const;
export type DispatchReasonCode = (typeof DISPATCH_REASON_CODES)[number];

export const clamp01 = (v: number): number => (v < 0 ? 0 : v > 1 ? 1 : v);
export const round4 = (v: number): number => Math.round(v * 10_000) / 10_000;

export function weightedSum<K extends string>(weights: Readonly<Record<K, number>>, components: Readonly<Record<K, number>>): number {
  let s = 0;
  for (const k of Object.keys(weights) as K[]) s += weights[k] * components[k];
  return s;
}

export interface DispatchCandidate {
  facts: PhotographerFacts;
  distanceKm: number;
  etaMinutes: number;
}

export interface DispatchScoringContext {
  genre: Genre;
  round: Round;
}

type ScoringCfg = Pick<DispatchConfig, 'scoring' | 'eta'>;

export function etaComponent(etaMinutes: number, cfg: ScoringCfg): number {
  return clamp01(1 - etaMinutes / cfg.eta.normMaxMin);
}

export function genreComponent(f: PhotographerFacts, genre: Genre, cfg: ScoringCfg): number {
  if (f.specialtyLevels === null) return cfg.scoring.genreUnknown;
  const level = f.specialtyLevels[GENRE_SPECIALTY[genre]];
  return level === undefined ? 0 : cfg.scoring.genreLevelScores[level - 1] ?? 0;
}

export function ratingComponent(f: PhotographerFacts, cfg: ScoringCfg): number {
  const { m, c } = cfg.scoring.ratingPrior;
  const v = f.ratingAvg === null ? 0 : f.reviewCount;
  const smoothed = (v * (f.ratingAvg ?? c) + m * c) / (v + m || 1);
  return clamp01((smoothed - 3) / 2);
}

export function reliabilityComponent(f: PhotographerFacts, cfg: ScoringCfg): number {
  const { m, acceptRate, cancelRate } = cfg.scoring.reliabilityPrior;
  const r = f.reliability;
  const accept = (r.accepted + m * acceptRate) / (r.offers + m || 1);
  const cancel = (r.cancelled + r.noShow + m * cancelRate) / (r.accepted + m || 1);
  return clamp01(clamp01(accept) * (1 - clamp01(cancel)));
}

/** Spec §3.2: score = 0.45·eta + 0.25·genreMatch + 0.15·rating + 0.15·reliability (+0.05 helpReady in round 1). */
export function dispatchScorerV1(cfg: ScoringCfg): Scorer<DispatchCandidate, DispatchScoringContext, DispatchReasonCode> {
  const w = cfg.scoring.weights;
  return {
    name: 'dispatch-v1',
    version: '1.0.0',
    score(c, ctx) {
      const eta = etaComponent(c.etaMinutes, cfg);
      const genre = genreComponent(c.facts, ctx.genre, cfg);
      const rating = ratingComponent(c.facts, cfg);
      const reliability = reliabilityComponent(c.facts, cfg);
      const bonus = ctx.round === 1 && c.facts.helpReady ? cfg.scoring.helpReadyBonus : 0;
      const reasons: ScoreReason<DispatchReasonCode>[] = [
        { code: 'near', value: round4(eta), contribution: round4(w.eta * eta), etaMinutes: c.etaMinutes, distanceKm: c.distanceKm },
        { code: 'skill_match', value: round4(genre), contribution: round4(w.genre * genre) },
        { code: 'top_rated', value: round4(rating), contribution: round4(w.rating * rating) },
        { code: 'reliable', value: round4(reliability), contribution: round4(w.reliability * reliability) },
      ];
      if (bonus > 0) reasons.push({ code: 'help_ready', value: 1, contribution: round4(bonus) });
      reasons.sort((a, b) => b.contribution - a.contribution || DISPATCH_REASON_CODES.indexOf(a.code) - DISPATCH_REASON_CODES.indexOf(b.code));
      return {
        score: round4(weightedSum(w, { eta, genre, rating, reliability }) + bonus),
        breakdown: { eta, genre, rating, reliability, bonus },
        reasons,
      };
    },
  };
}

/** The ETA an offer was scored with (the `near` reason), e.g. read back from instant_offers.reasons. */
export function etaFromReasons(reasons: readonly { code: string; etaMinutes?: number }[]): number | null {
  const near = reasons.find((r) => r.code === 'near');
  return near?.etaMinutes ?? null;
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './scoring.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 261`, `ℹ pass 261`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): dispatch-v1 scorer with explainable reasons in the shared Scorer shape

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Matcher core: filter, score and order candidates

**Files:**
- Create: `packages/dispatch-core/src/matcher.ts`, `packages/dispatch-core/test/matcher.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `tierOf` (Task 7), `estimateEta`, `haversineKm` (Task 4), `dispatchScorerV1`, `Scorer` (Task 8), `Rng` (Task 1).
- Produces: `interface OnlineCandidate { facts: PhotographerFacts; location: LatLng }`; `interface MatchInput { meetPoint; genre; round; radiusKm; currentPriceListVersion; candidates: readonly OnlineCandidate[]; excluded: ReadonlySet<string>; busy: ReadonlySet<string> }`; `interface RankedCandidate { uid; tier; score; reasons; distanceKm; etaMinutes }`; `rankCandidates(input, cfg, rng?, scorer?): RankedCandidate[]`.

Rules: never a photographer in `excluded` (already offered this request: "không mời lại") or `busy` (holding an offer or an open job); round 1 takes only `priority`, round 2 takes `priority` and `expanded`; candidates outside `radiusKm` (haversine, not trusting the GEO index blindly) are dropped.

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/matcher.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, rankCandidates, seededRng, type MatchInput, type OnlineCandidate } from '../src/index.js';
import { facts } from './support/facts.js';

const MEET = { lat: 10.7725, lng: 106.698 };
/** A point `km` north of the meet point. */
const north = (km: number) => ({ lat: MEET.lat + km / 111.19508, lng: MEET.lng });

function input(candidates: OnlineCandidate[], over: Partial<MatchInput> = {}): MatchInput {
  return {
    meetPoint: MEET, genre: 'portrait', round: 1, radiusKm: 3, currentPriceListVersion: 3,
    candidates, excluded: new Set(), busy: new Set(), ...over,
  };
}

describe('rankCandidates', () => {
  test('orders by score: nearer first when profiles are equal', () => {
    const r = rankCandidates(input([
      { facts: facts({ uid: 'far' }), location: north(2.5) },
      { facts: facts({ uid: 'near' }), location: north(0.5) },
      { facts: facts({ uid: 'mid' }), location: north(1.5) },
    ]), DEFAULT_CONFIG);
    assert.deepEqual(r.map((c) => c.uid), ['near', 'mid', 'far']);
    assert.equal(r[0]?.tier, 'priority');
    assert.deepEqual([r[0]?.distanceKm, r[0]?.etaMinutes], [0.5, 3]);
  });

  test('round 1 takes the priority tier only; round 2 takes the expanded tier too', () => {
    const cands = [
      { facts: facts({ uid: 'top' }), location: north(1) },
      { facts: facts({ uid: 'new', verified: false }), location: north(0.5) },
      { facts: facts({ uid: 'helper', verified: false, helpReady: true }), location: north(2) },
    ];
    assert.deepEqual(rankCandidates(input(cands), DEFAULT_CONFIG).map((c) => c.uid).sort(), ['helper', 'top']);
    assert.deepEqual(
      rankCandidates(input(cands, { round: 2, radiusKm: 10 }), DEFAULT_CONFIG).map((c) => c.uid).sort(),
      ['helper', 'new', 'top'],
    );
  });

  test('never re-offers, skips busy photographers, the radius and the not-ready', () => {
    const r = rankCandidates(input([
      { facts: facts({ uid: 'declined' }), location: north(0.2) },
      { facts: facts({ uid: 'busy' }), location: north(0.3) },
      { facts: facts({ uid: 'outside' }), location: north(3.2) },
      { facts: facts({ uid: 'old-prices', acceptedPriceListVersion: 2 }), location: north(0.4) },
      { facts: facts({ uid: 'ok' }), location: north(2.9) },
    ], { excluded: new Set(['declined']), busy: new Set(['busy']) }), DEFAULT_CONFIG);
    assert.deepEqual(r.map((c) => c.uid), ['ok']);
  });

  test('help-ready bonus can lift a slightly farther photographer in round 1', () => {
    const r = rankCandidates(input([
      { facts: facts({ uid: 'plain' }), location: north(1.0) },
      { facts: facts({ uid: 'helper', helpReady: true }), location: north(1.5) },
    ]), DEFAULT_CONFIG);
    assert.equal(r[0]?.uid, 'helper');
  });

  test('ties: shorter ETA, then rng, then uid; deterministic for a seed', () => {
    const same = ['c', 'a', 'b'].map((uid) => ({ facts: facts({ uid }), location: north(1) }));
    assert.deepEqual(rankCandidates(input(same), DEFAULT_CONFIG).map((c) => c.uid), ['a', 'b', 'c']);
    const s1 = rankCandidates(input(same), DEFAULT_CONFIG, seededRng(1)).map((c) => c.uid);
    const s1again = rankCandidates(input(same), DEFAULT_CONFIG, seededRng(1)).map((c) => c.uid);
    assert.deepEqual(s1, s1again);
    assert.deepEqual([...s1].sort(), ['a', 'b', 'c']);
  });

  test('empty input → empty result', () => {
    assert.deepEqual(rankCandidates(input([]), DEFAULT_CONFIG), []);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `rankCandidates`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/matcher.ts
import type { Rng } from './clock.js';
import type { DispatchConfig } from './config.js';
import { tierOf, type PhotographerFacts, type Tier } from './eligibility.js';
import { estimateEta, haversineKm } from './geo.js';
import { dispatchScorerV1, type DispatchReasonCode, type ScoreReason, type Scorer, type DispatchCandidate, type DispatchScoringContext } from './scoring.js';
import type { Genre, LatLng, Round } from './types.js';

/** A photographer returned by GEOSEARCH, with the facts the service cached for them. */
export interface OnlineCandidate {
  facts: PhotographerFacts;
  location: LatLng;
}

export interface MatchInput {
  meetPoint: LatLng;
  genre: Genre;
  round: Round;
  radiusKm: number;
  currentPriceListVersion: number;
  candidates: readonly OnlineCandidate[];
  /** Already offered this request (declined, expired, withdrawn, accepted): never offered again. */
  excluded: ReadonlySet<string>;
  /** Holding an open offer (offerlock) or an open job. */
  busy: ReadonlySet<string>;
}

export interface RankedCandidate {
  uid: string;
  tier: Tier;
  score: number;
  reasons: ScoreReason<DispatchReasonCode>[];
  distanceKm: number;
  etaMinutes: number;
}

type MatchCfg = Pick<DispatchConfig, 'eta' | 'scoring' | 'eligibility'>;

/**
 * Pure core of the matcher (spec §5 `matcher`): filter by round tier, exclusions, busy and radius,
 * score, and order best first. Ties: higher score, then shorter ETA, then a random key (rng) or uid.
 */
export function rankCandidates(
  input: MatchInput,
  cfg: MatchCfg,
  rng?: Rng,
  scorer: Scorer<DispatchCandidate, DispatchScoringContext, DispatchReasonCode> = dispatchScorerV1(cfg),
): RankedCandidate[] {
  const ranked: RankedCandidate[] = [];
  const tieKey = new Map<string, number>();
  for (const c of input.candidates) {
    const uid = c.facts.uid;
    if (input.excluded.has(uid) || input.busy.has(uid)) continue;
    const tier = tierOf(c.facts, input.currentPriceListVersion, cfg);
    if (tier === null || (input.round === 1 && tier !== 'priority')) continue;
    if (haversineKm(input.meetPoint, c.location) > input.radiusKm) continue;
    const eta = estimateEta(c.location, input.meetPoint, cfg);
    const scored = scorer.score({ facts: c.facts, distanceKm: eta.distanceKm, etaMinutes: eta.minutes }, { genre: input.genre, round: input.round });
    ranked.push({
      uid,
      tier,
      score: scored.score,
      reasons: scored.reasons,
      distanceKm: eta.distanceKm,
      etaMinutes: eta.minutes,
    });
    tieKey.set(uid, rng ? rng() : 0);
  }
  const key = (uid: string): number => tieKey.get(uid) ?? 0;
  ranked.sort(
    (a, b) =>
      b.score - a.score || a.etaMinutes - b.etaMinutes || key(a.uid) - key(b.uid) || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0),
  );
  return ranked;
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './matcher.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 267`, `ℹ pass 267`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): pure matcher core ranking eligible, unexcluded photographers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Round and radius policy (30 s offers, 3 → 6 → 10 km, round 2, 10 minutes)

**Files:**
- Create: `packages/dispatch-core/src/rounds.ts`, `packages/dispatch-core/test/rounds.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `DispatchConfig` (`round1`, `round2`, `totalSearchMs`, `idleRetryMs`, `offerTtlMs`), `Round`.
- Produces:
  - `interface SearchState { startedAt: Date; expand: boolean; round: Round; radiusIndex: number; roundStartedAt: Date }` (plan I3 keeps it in Redis `search:{requestId}`).
  - `startSearch(now, expand): SearchState`; `radiusKm(s, cfg): number`; `round1EndsAt(s, cfg): Date`; `searchEndsAt(s, cfg): Date` (shown as `InstantRequestMirror.searchEndsAt`); `lastOfferAt(s, cfg): Date` (an offer must fit its 30 s before the end).
  - `type SearchStep = { kind: 'search'; state; round; radiusKm } | { kind: 'no_match'; state }`; `nextSearchStep(s, now, cfg): SearchStep` (applies time limits, switches to round 2 at 5 minutes when `expand`).
  - `type EmptyOutcome = { kind: 'retry_now'; state } | { kind: 'wait'; state; retryAt: Date }`; `onNobodyLeft(s, now, cfg): EmptyOutcome` (widen; or early round 2 when `expand`; or wait `idleRetryMs`, never past the end).

The policy, as tested: without "Mở rộng", the search ends 5 minutes after it started (`no_match`, 100 % refund); with it, round 2 (10 km, expanded tier) starts at 5 minutes or as soon as round 1 has nobody even at 10 km, lasts at most 5 minutes, and the whole search never exceeds 10 minutes. One offer is open at a time per request (the service enforces it) and each lasts `offerTtlMs` (30 s).

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/rounds.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, lastOfferAt, nextSearchStep, onNobodyLeft, radiusKm, round1EndsAt, searchEndsAt, startSearch } from '../src/index.js';

const T0 = new Date('2026-10-01T08:00:00.000Z');
const at = (sec: number) => new Date(T0.getTime() + sec * 1000);

describe('round 1: priority tier, radius 3 → 6 → 10 km, at most 5 minutes', () => {
  test('starts at 3 km', () => {
    const s = startSearch(T0, false);
    assert.deepEqual(nextSearchStep(s, T0, DEFAULT_CONFIG), { kind: 'search', state: s, round: 1, radiusKm: 3 });
  });

  test('widens only when nobody is left at the current radius', () => {
    let s = startSearch(T0, false);
    const steps: number[] = [radiusKm(s, DEFAULT_CONFIG)];
    for (let i = 0; i < 2; i++) {
      const o = onNobodyLeft(s, at(10), DEFAULT_CONFIG);
      assert.equal(o.kind, 'retry_now');
      s = o.state;
      steps.push(radiusKm(s, DEFAULT_CONFIG));
    }
    assert.deepEqual(steps, [3, 6, 10]);
  });

  test('at 10 km with nobody and no expand: wait and look again in 5 s', () => {
    const s = { ...startSearch(T0, false), radiusIndex: 2 };
    assert.deepEqual(onNobodyLeft(s, at(60), DEFAULT_CONFIG), { kind: 'wait', state: s, retryAt: at(65) });
  });

  test('no expand: no_match at 5 minutes', () => {
    const s = startSearch(T0, false);
    assert.deepEqual(searchEndsAt(s, DEFAULT_CONFIG), at(300));
    assert.equal(nextSearchStep(s, at(299.999), DEFAULT_CONFIG).kind, 'search');
    assert.equal(nextSearchStep(s, at(300), DEFAULT_CONFIG).kind, 'no_match');
  });

  test('the wait never goes past the end of the search', () => {
    const s = { ...startSearch(T0, false), radiusIndex: 2 };
    const o = onNobodyLeft(s, at(298), DEFAULT_CONFIG);
    assert.deepEqual(o.kind === 'wait' ? o.retryAt : null, at(300));
  });
});

describe('round 2: only with "Mở rộng tìm kiếm", 10 km, at most 5 more minutes, 10 minutes in total', () => {
  test('starts when round 1 time is up', () => {
    const s = startSearch(T0, true);
    assert.deepEqual(round1EndsAt(s, DEFAULT_CONFIG), at(300));
    const step = nextSearchStep(s, at(300), DEFAULT_CONFIG);
    assert.equal(step.kind, 'search');
    if (step.kind === 'search') {
      assert.deepEqual([step.round, step.radiusKm], [2, 10]);
      assert.deepEqual(searchEndsAt(step.state, DEFAULT_CONFIG), at(600));
    }
    assert.equal(nextSearchStep(step.state, at(600), DEFAULT_CONFIG).kind, 'no_match');
  });

  test('starts early once round 1 has run out of people at 10 km, and still lasts at most 5 minutes', () => {
    const s = { ...startSearch(T0, true), radiusIndex: 2 };
    const o = onNobodyLeft(s, at(40), DEFAULT_CONFIG);
    assert.equal(o.kind, 'retry_now');
    assert.deepEqual([o.state.round, radiusKm(o.state, DEFAULT_CONFIG)], [2, 10]);
    assert.deepEqual(searchEndsAt(o.state, DEFAULT_CONFIG), at(340));
  });

  test('round 2 empty: wait, never beyond the end', () => {
    const s = { ...startSearch(T0, true), round: 2 as const, roundStartedAt: at(300) };
    assert.deepEqual(onNobodyLeft(s, at(400), DEFAULT_CONFIG), { kind: 'wait', state: s, retryAt: at(405) });
  });

  test('expand while still in round 1: the provisional end is the 10-minute total', () => {
    assert.deepEqual(searchEndsAt(startSearch(T0, true), DEFAULT_CONFIG), at(600));
  });

  test('a new offer must fit before the end: last offer 30 s before', () => {
    assert.deepEqual(lastOfferAt(startSearch(T0, false), DEFAULT_CONFIG), at(270));
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `lastOfferAt`, `nextSearchStep`, `onNobodyLeft`, `radiusKm`, `round1EndsAt`, `searchEndsAt`, `startSearch`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/rounds.ts
import type { DispatchConfig } from './config.js';
import type { Round } from './types.js';

/**
 * Search policy (spec §3.2). Round 1 (priority tier) widens 3 → 6 → 10 km each time the current
 * radius has nobody left, for at most 5 minutes. Round 2 (expanded tier, 10 km) runs only when the
 * customer ticked "Mở rộng tìm kiếm", for at most 5 more minutes; it starts early when round 1 has
 * already run out of people at its widest radius. The whole search never exceeds 10 minutes.
 */
export interface SearchState {
  startedAt: Date;
  expand: boolean;
  round: Round;
  /** Index into round1.radiiKm (round 1 only). */
  radiusIndex: number;
  roundStartedAt: Date;
}

type Cfg = Pick<DispatchConfig, 'round1' | 'round2' | 'totalSearchMs' | 'idleRetryMs' | 'offerTtlMs'>;

export function startSearch(now: Date, expand: boolean): SearchState {
  return { startedAt: now, expand, round: 1, radiusIndex: 0, roundStartedAt: now };
}

const at = (base: Date, ms: number): Date => new Date(base.getTime() + ms);

export function radiusKm(s: SearchState, cfg: Cfg): number {
  if (s.round === 2) return cfg.round2.radiusKm;
  const radii = cfg.round1.radiiKm;
  return radii[Math.min(s.radiusIndex, radii.length - 1)] ?? cfg.round2.radiusKm;
}

/** When round 1 stops (5 minutes after the search started). */
export function round1EndsAt(s: SearchState, cfg: Cfg): Date {
  return at(s.startedAt, cfg.round1.maxMs);
}

/** When the search gives up (no_match). Shown as InstantRequestMirror.searchEndsAt. */
export function searchEndsAt(s: SearchState, cfg: Cfg): Date {
  const total = at(s.startedAt, cfg.totalSearchMs).getTime();
  if (!s.expand) return new Date(Math.min(total, round1EndsAt(s, cfg).getTime()));
  if (s.round === 1) return new Date(total);
  return new Date(Math.min(total, s.roundStartedAt.getTime() + cfg.round2.maxMs));
}

/** The last moment a new offer may be sent: its 30 s must end before the search does. */
export function lastOfferAt(s: SearchState, cfg: Cfg): Date {
  return at(searchEndsAt(s, cfg), -cfg.offerTtlMs);
}

function toRound2(s: SearchState, now: Date): SearchState {
  return { ...s, round: 2, radiusIndex: 0, roundStartedAt: now };
}

export type SearchStep =
  /** Run the matcher with these parameters. */
  | { kind: 'search'; state: SearchState; round: Round; radiusKm: number }
  /** Time is up: no_match and refund 100 %. */
  | { kind: 'no_match'; state: SearchState };

/** Called before each matcher run: applies the time limits. */
export function nextSearchStep(s: SearchState, now: Date, cfg: Cfg): SearchStep {
  let state = s;
  if (state.round === 1 && now.getTime() >= round1EndsAt(state, cfg).getTime() && state.expand) {
    state = toRound2(state, now);
  }
  if (now.getTime() >= searchEndsAt(state, cfg).getTime()) return { kind: 'no_match', state };
  return { kind: 'search', state, round: state.round, radiusKm: radiusKm(state, cfg) };
}

export type EmptyOutcome =
  /** Widened the radius or moved to round 2: run the matcher again now. */
  | { kind: 'retry_now'; state: SearchState }
  /** Nobody anywhere in range: try again at retryAt (new photographers may come online). */
  | { kind: 'wait'; state: SearchState; retryAt: Date };

/** Called when the matcher found nobody to offer at the current radius. */
export function onNobodyLeft(s: SearchState, now: Date, cfg: Cfg): EmptyOutcome {
  if (s.round === 1) {
    if (s.radiusIndex < cfg.round1.radiiKm.length - 1) {
      return { kind: 'retry_now', state: { ...s, radiusIndex: s.radiusIndex + 1 } };
    }
    if (s.expand) return { kind: 'retry_now', state: toRound2(s, now) };
  }
  const retry = Math.min(now.getTime() + cfg.idleRetryMs, searchEndsAt(s, cfg).getTime());
  return { kind: 'wait', state: s, retryAt: new Date(retry) };
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './rounds.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 277`, `ℹ pass 277`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): search policy with radius steps, optional round 2 and the 10-minute limit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Arrival check, typical match time, location rate limit

**Files:**
- Create: `packages/dispatch-core/src/arrival.ts`, `packages/dispatch-core/src/stats.ts`, `packages/dispatch-core/test/rules.test.ts`
- Modify: `packages/dispatch-core/src/index.ts`

**Interfaces:**
- Consumes: `DispatchConfig` (`arrival`, `stats`, `tracking`).
- Produces: `type ArrivalDecision = { ok: true; forced: boolean } | { ok: false; reason: 'too_far' | 'reason_required' }`; `decideArrival({ distanceM, accuracyM, force, reason }, cfg): ArrivalDecision`; `typicalMatchMinutes(samplesMs: readonly number[], cfg): number | null`; `locationAllowed(lastAt: Date | null, now: Date, cfg): boolean`.

- [ ] **Step 1: Write the failing test**

```ts
// packages/dispatch-core/test/rules.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_CONFIG, decideArrival, locationAllowed, typicalMatchMinutes } from '../src/index.js';

describe('arrival (spec §2.2, §10)', () => {
  const d = (distanceM: number, accuracyM: number, force = false, reason: string | null = null) =>
    decideArrival({ distanceM, accuracyM, force, reason }, DEFAULT_CONFIG);
  test('within 200 m: arrived', () => {
    assert.deepEqual(d(200, 10), { ok: true, forced: false });
  });
  test('farther with good GPS: refused even when forced', () => {
    assert.deepEqual(d(201, 10), { ok: false, reason: 'too_far' });
    assert.deepEqual(d(500, 100, true, 'x'), { ok: false, reason: 'too_far' });
  });
  test('farther with poor GPS (> 100 m): forced with a reason', () => {
    assert.deepEqual(d(500, 101), { ok: false, reason: 'too_far' });
    assert.deepEqual(d(500, 150, true, '  '), { ok: false, reason: 'reason_required' });
    assert.deepEqual(d(500, 150, true, 'GPS trong hẻm'), { ok: true, forced: true });
  });
});

describe('typical match minutes (spec §2.1)', () => {
  const min = (m: number) => m * 60_000;
  test('hidden below 20 samples', () => {
    assert.equal(typicalMatchMinutes(Array.from({ length: 19 }, () => min(5)), DEFAULT_CONFIG), null);
  });
  test('median, rounded to whole minutes, at least 1', () => {
    const odd = [...Array.from({ length: 10 }, () => min(2)), min(7), ...Array.from({ length: 10 }, () => min(9))];
    assert.equal(typicalMatchMinutes(odd, DEFAULT_CONFIG), 7);
    const even = [...Array.from({ length: 10 }, () => min(4)), ...Array.from({ length: 10 }, () => min(5))];
    assert.equal(typicalMatchMinutes(even, DEFAULT_CONFIG), 5); // 4.5 → 5
    assert.equal(typicalMatchMinutes(Array.from({ length: 20 }, () => 1_000), DEFAULT_CONFIG), 1);
  });
  test('ignores invalid samples', () => {
    const s = [...Array.from({ length: 20 }, () => min(3)), -1, Number.NaN];
    assert.equal(typicalMatchMinutes(s, DEFAULT_CONFIG), 3);
  });
});

describe('location rate limit (spec §6)', () => {
  const t = new Date('2026-10-01T08:00:00.000Z');
  test('once per 5 seconds', () => {
    assert.equal(locationAllowed(null, t, DEFAULT_CONFIG), true);
    assert.equal(locationAllowed(new Date(t.getTime() - 4_999), t, DEFAULT_CONFIG), false);
    assert.equal(locationAllowed(new Date(t.getTime() - 5_000), t, DEFAULT_CONFIG), true);
  });
});
```

- [ ] **Step 2: Run and see it fail**

Run: `npm test`
Expected: FAIL. The new test file stops with `SyntaxError: The requested module '../src/index.js' does not provide an export named '…'` (one of `decideArrival`, `locationAllowed`, `typicalMatchMinutes`); the earlier test files still pass.

- [ ] **Step 3: Implement**

```ts
// packages/dispatch-core/src/arrival.ts
import type { DispatchConfig } from './config.js';

export type ArrivalDecision =
  | { ok: true; forced: boolean }
  /** Refused with not_eligible; `reason` goes into Error.details.reasons. */
  | { ok: false; reason: 'too_far' | 'reason_required' };

/**
 * Spec §2.2 step 3 and §10: "Đã đến" only within 200 m; with poor GPS (accuracy > 100 m) the
 * photographer may force it with a written reason, which the service logs.
 */
export function decideArrival(
  input: { distanceM: number; accuracyM: number; force: boolean; reason: string | null },
  cfg: Pick<DispatchConfig, 'arrival'>,
): ArrivalDecision {
  if (input.distanceM <= cfg.arrival.maxDistanceM) return { ok: true, forced: false };
  if (!input.force || input.accuracyM <= cfg.arrival.poorAccuracyM) return { ok: false, reason: 'too_far' };
  if (input.reason === null || input.reason.trim() === '') return { ok: false, reason: 'reason_required' };
  return { ok: true, forced: true };
}
```

```ts
// packages/dispatch-core/src/stats.ts
import type { DispatchConfig } from './config.js';

/**
 * Spec §2.1: "Thường có người nhận trong khoảng {n} phút" = median time from search start to
 * assigned over the last 7 days in the city; null (hidden on S13.01) below the minimum sample size.
 */
export function typicalMatchMinutes(samplesMs: readonly number[], cfg: Pick<DispatchConfig, 'stats'>): number | null {
  const valid = samplesMs.filter((v) => Number.isFinite(v) && v >= 0);
  if (valid.length < cfg.stats.typicalMatchMinSamples) return null;
  const sorted = [...valid].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  const median = sorted.length % 2 === 1 ? (sorted[mid] ?? 0) : ((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2;
  return Math.max(1, Math.round(median / 60_000));
}

/** Spec §6: location at most once per minIntervalMs. */
export function locationAllowed(lastAt: Date | null, now: Date, cfg: Pick<DispatchConfig, 'tracking'>): boolean {
  return lastAt === null || now.getTime() - lastAt.getTime() >= cfg.tracking.minIntervalMs;
}
```

Append to `packages/dispatch-core/src/index.ts`:

```ts
export * from './arrival.js';
export * from './stats.js';
```

The barrel is now:

```ts
// packages/dispatch-core/src/index.ts
export * from './types.js';
export * from './errors.js';
export * from './clock.js';
export * from './config.js';
export * from './state-machine.js';
export * from './geo.js';
export * from './pricing.js';
export * from './cancellation.js';
export * from './eligibility.js';
export * from './scoring.js';
export * from './matcher.js';
export * from './rounds.js';
export * from './arrival.js';
export * from './stats.js';
```

- [ ] **Step 4: Run and see it pass**

Run: `npm run typecheck && npm run lint && npm test`
Expected: clean; `ℹ tests 284`, `ℹ pass 284`, `ℹ fail 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core
git commit -m "feat(dispatch-core): arrival distance rule, typical match minutes and the location rate rule

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-instant-i2-dispatch-core.md"). Nothing to do here.
