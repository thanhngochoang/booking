# Nền · Booking nháp dùng chung (buildBookingDraft, milestoneAmounts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests (2026-10-02, user):** this plan changes no `firestore.rules`, `storage.rules` or indexes and adds no Function, so there is no rules-test or Functions integration suite to write. Unit suites only.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`). No Flutter change.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** One pure booking-draft builder (`buildBookingDraft`) that every order path uses, with an extension point where the job-post (#139), studio (#136) and add-on (#190) units each add their own optional input without touching each other's lines, and one milestone split rule (`milestoneAmounts`) for display and for #152's payment split. `createBookingDraft` is refactored onto the builder with no behaviour change other than the new `revisionsIncluded` field.

**Architecture:** Domain only, plus the two Firestore mappers that would otherwise drop the new fields. `packages/domain/src/create_booking.ts` gains `BookingDraftCore`, `BookingDraftInput` (core + reserved slots), `draftTotal` and `buildBookingDraft`; `createBookingDraft` keeps its validation, provider check, price check, phone check and transaction and writes `buildBookingDraft(...)`. `booking_policy.ts` gains the free-revision rule (`clampRevisions`, `DEFAULT_REVISIONS`, `REVISIONS_MAX`), `ServiceRecord` gains `revisions?`, `Booking` gains `revisionsIncluded?`. New `milestones.ts` holds only the kinds, the default 50/50 percents and `milestoneAmounts`; the milestone model and state machine stay in #152. Functions: `bookingToFirestore`/`bookingFromFirestore` map `revisionsIncluded`, and `FirestoreServiceCatalog` reads `deliverables.revisions`.

**Tech Stack:** TypeScript, `node --test` via `tsx`, ESLint (`typescript-eslint` strict); Functions unit tests (`node --test`), `firebase-admin` types in the adapters only.

**Spec:** `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §4.1 (two milestones, default 50/50, the second gets the remainder; `Service.revisions = 1` default, 0–5) and §4.2 (`BookingTerms`, quotes use the same booking); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §4 (two milestones); `docs/superpowers/specs/data-model/domain-model.md` §2.4 and §6 invariant 18 (milestones sum to the payment net); `docs/superpowers/plans/2026-10-07-INDEX.md` ("Mọi đường tạo đơn … dựng booking bằng `buildBookingDraft`"); `docs/superpowers/plans/2026-10-08-s04-reconciliation.md` (row `BookingDraftInput`, `buildBookingDraft`: #129 did not build it).

**Issue:** #199 (Nền · Booking nháp dùng chung (buildBookingDraft, milestoneAmounts)). Split out of #152 on 2026-10-08 (was #152 Task 2 part and Task 3 part) so #152, #139, #136 and #190 stop blocking each other.

**Blocked by:** nothing. **Blocks:** #152 (S05 bàn giao hai lớp), #139 (S15–S16), #136 (S26), #190 (dịch vụ đi kèm). Runs in parallel with #198 (order gate `assertOrderAllowed`); see Decision 6.

**Branch:** `plan/199-booking-nhap` from `origin/develop`; PR into `develop` titled `feat(booking): shared booking draft builder and milestone amounts [#199]`.

## Contract with existing code

Checked 2026-10-08 on `develop` 4e25834 (after #129 #154, #130 #156, #138 #155, #147 #159, #134 #193). Task Step 1 re-checks; if a member named here does not exist, stop and report instead of guessing.

- `packages/domain/src/create_booking.ts`: `createBookingDraft(deps: BookingDeps, rawInput: unknown): Promise<Booking>` builds the `Booking` literal inline inside `deps.store.runTransaction`, in this order: `validateCreateBookingDraftInput(rawInput, now)` → `deps.services.getService` (`not_found` when missing, inactive or another photographer's) → `deps.providers.acceptsOrders` (`not_accepting_orders`) → `expectedPrice !== service.price` (`price_changed`) → `requireCustomerPhone` + `deps.contacts.get` → `computeDeposit(service.price)`, `addMinutesToTime(start, durationMinutes)` → transaction (day `off|booked` → `day_taken`; `pending` allowed only for the customer's own draft, which is deleted with its contact snapshot) → `deps.ids.newId()` → `tx.setBooking`, `tx.setAvailabilityDay(..., {state: 'pending', bookingId})`, `tx.setContactSnapshot`.
- `booking_policy.ts`: `DRAFT_EXPIRY_MINUTES = 30`, `computeDeposit(price): {deposit, remaining}` (100 % up front: `deposit = price`, `remaining = 0`), `addMinutesToTime(start, durationMinutes)`.
- `booking_ports.ts`: `ServiceRecord {id, photographerId, name, price, durationMinutes, active}`; `ServiceCatalog.getService`.
- `booking.ts`: `Booking` (fields `id … payableUntil?, version, createdAt, updatedAt`; no `revisionsIncluded`).
- `errors.ts`: `DomainError(code)`, code `invalid_argument` exists.
- `index.ts`: `export * from './create_booking.js'`, `'./booking_policy.js'` (no `milestones.js`).
- Functions: `src/infra/booking_firestore.ts` `bookingToFirestore(b)` writes the **whole** document (explicit field list, `set`), `bookingFromFirestore(id, d)`; `src/infra/booking_readers.ts` `FirestoreServiceCatalog.getService` maps `photographers/{uid}/services/{id}` inline; `test/unit/booking_firestore.test.ts` has the shared `round-trips Booking through Firestore conversion` test. The app writes package deliverables as `deliverables {photoCount, editedCount, deliveryDays}` (no `revisions` yet; the S08.01 editor field is #146's).
- Test world: `packages/domain/test/support/booking_world.ts` `createBookingWorld()` → `{deps, store, clock (ControllableClock, 2026-10-10T10:00Z), ids (SequentialIdGen), services: Map<string, ServiceRecord> ('srv_01': 1 000 000 VND, 120 min), providers, contacts}`.

## Global Constraints

- CLAUDE.md: business rules in `packages/domain` (no Firebase, Google Cloud or `node:*` imports in `src/`, enforced by ESLint and `purity.test.ts`); Functions stay thin adapters.
- Data conventions (`data-model/README.md`): integer VND, ISO-8601 UTC instants, string enum codes (`shoot`, `delivery`).
- Money rule (CLAUDE.md, payments spec §4): the customer pays 100 % up front; two milestones; every money step reads `booking.deposit` → `payment.amount`. This plan does not change any amount: `deposit` stays `computeDeposit(service.price).deposit`.
- Milestones (10‑05 §4.1): `shoot = ⌊net × shoot% / 100⌋`, `delivery = net − shoot` (the second milestone takes the rounding remainder); default 50/50.
- Revisions (10‑05 §4.1, #152 Decision 4): `revisionsIncluded = clamp(service.revisions ?? 1, 0, 5)`, integer.
- The order gate is not in scope: `createBookingDraft` keeps calling `deps.providers.acceptsOrders` at the same place; #198 swaps that call for `assertOrderAllowed`.
- Tests: domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run lint && npm run build`.
- Commits: Conventional Commits, subject ends with `[#199]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Key decisions

| # | Decision | Why |
|---|---|---|
| 1 | The builder lives in `create_booking.ts` (not a new file). | #139, #136, #190 and #152 plans already name `create_booking.ts`; no consumer has to rename an import. |
| 2 | **Extension point = reserved slot markers** in three places of `create_booking.ts` (import block, `BookingDraftInput`, the spread in `buildBookingDraft`) plus one money hook `draftTotal`. Each consumer writes only under its own marker; markers are separated by an unchanged line so parallel branches merge without conflict. Each slot's helper (`quoteDraftFields`, `studioDraftFields`, `addonDraftFields`) lives in the consumer's own module and returns `{}` when its input is absent. | Three units extend the builder in parallel (waves 4–5). Editing one shared literal or one shared import line makes every merge a conflict; separate markers make each change a separate hunk. Returning `{}` keeps a plain booking's shape identical (pinned by a key-set test the consumers must keep green). |
| 3 | **Money hook `draftTotal(i)`** returns `i.service.price` today; #190 replaces only its body with `bookingTotal(i.service, i.addons ?? [])`. `deposit`/`remaining` = `computeDeposit(draftTotal(i))`. No slot may override `deposit`/`remaining` through the spread. | One place decides the amount; a spread that silently overrides money would be easy to miss in review. |
| 4 | `revisionsIncluded` moves here from #152: `DEFAULT_REVISIONS = 1`, `REVISIONS_MAX = 5`, `clampRevisions(v: unknown): number` in `booking_policy.ts` (policy constants live there); `ServiceRecord.revisions?: number`; `Booking.revisionsIncluded?: number`, always set by the builder. | The builder snapshots it (so every order path gets it, cross-plan review finding 21); a quote passes `terms.revisions` as its synthetic service's `revisions` (#139 Decision 1). Optional on `Booking` because older documents lack it; readers use `b.revisionsIncluded ?? DEFAULT_REVISIONS`. |
| 5 | `milestones.ts` holds only `MILESTONE_KINDS`, `MilestoneKind`, `DEFAULT_MILESTONE_PERCENTS` and `milestoneAmounts`. #152 adds the statuses, `PaymentMilestone`, `splitMilestones` (built on `milestoneAmounts`), release and dispute to the same file. | #139 shows quote amounts with `milestoneAmounts` and #190 pins payout lines on it; neither needs the state machine. One definition (cross-plan review finding 6). |
| 6 | Order gate untouched: the `acceptsOrders` call stays between the service check and the price check. #198 swaps it for `assertOrderAllowed` in its own PR. | #198 runs in parallel; the builder is pure and never sees the gate, so the two PRs touch different lines. |
| 7 | `milestoneAmounts` validates (`invalid_argument` for a negative or non-integer net, or percents that are not two integers in 0–100 summing to 100) and uses exact integer arithmetic (`net = 100q + r` → `shoot = q·p + ⌊r·p / 100⌋`). | Money: a silent wrong split is worse than an error, and `net × p` loses precision above 2^53 / 100. |
| 8 | The Firestore mappers carry `revisionsIncluded` and `ServiceRecord.revisions` in this PR. | `bookingToFirestore` writes the whole document with `set`, so an unmapped field is erased by the next transition (#152 Review Focus 3). |

## Contract

What the consumers (#152, #139, #136, #190) use. Names are final.

```ts
// packages/domain/src/booking_policy.ts
export const DEFAULT_REVISIONS = 1;
export const REVISIONS_MAX = 5;
/** Free revision rounds of a package or quote: non-number or NaN → 1; else truncated to an integer and clamped to 0–5. */
export function clampRevisions(v: unknown): number;

// packages/domain/src/booking_ports.ts
interface ServiceRecord { …; readonly revisions?: number }   // from deliverables.revisions; a quote passes terms.revisions

// packages/domain/src/booking.ts
interface Booking { …; readonly revisionsIncluded?: number } // set by buildBookingDraft; absent on older documents

// packages/domain/src/create_booking.ts
/** What every order path supplies. */
export interface BookingDraftCore {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  /** The package; a quote passes a synthetic record (#139). `serviceId` = `service.id`. */
  readonly service: ServiceRecord;
  readonly day: string;     // yyyy-MM-dd
  readonly start: string;   // HH:mm
  readonly place: Booking['place'];
  readonly note?: string;
  readonly now: Date;
}
/** Core + the optional fields of later units, one slot each (Decision 2). */
export interface BookingDraftInput extends BookingDraftCore { /* slots, see layout below */ }
/** The amount the customer pays; #190 replaces the body (Decision 3). */
export function draftTotal(i: BookingDraftInput): number;
/**
 * Pure. status 'draft'; serviceId = service.id; serviceSnapshot {name, price, durationMinutes};
 * end = addMinutesToTime(start, durationMinutes); {deposit, remaining} = computeDeposit(draftTotal(i));
 * payableUntil = now + DRAFT_EXPIRY_MINUTES; revisionsIncluded = clampRevisions(service.revisions);
 * version 1; createdAt = updatedAt = now.toISOString(); then each slot's fields.
 */
export function buildBookingDraft(i: BookingDraftInput): Booking;
export function createBookingDraft(deps: BookingDeps, rawInput: unknown): Promise<Booking>; // unchanged signature

// packages/domain/src/milestones.ts (new; #152 extends the same file)
export const MILESTONE_KINDS = ['shoot', 'delivery'] as const;
export type MilestoneKind = (typeof MILESTONE_KINDS)[number];
export const DEFAULT_MILESTONE_PERCENTS: Readonly<Record<MilestoneKind, number>> = { shoot: 50, delivery: 50 };
/** shoot = ⌊net × percents.shoot / 100⌋, delivery = net − shoot. Throws DomainError('invalid_argument') (Decision 7). */
export function milestoneAmounts(
  net: number,
  percents?: Readonly<Record<MilestoneKind, number>>,
): { shoot: number; delivery: number };
```

**Slot layout in `create_booking.ts`** (exact markers; a consumer adds lines directly under its own marker and edits nothing else in these three blocks):

```ts
// ── Draft slots: imports (one block per unit; edit only your own) ──
// slot #139 (quotes)

// slot #136 (studio)

// slot #190 (add-ons)

// ── end draft slot imports ──

export interface BookingDraftInput extends BookingDraftCore {
  // slot #139 (quotes): readonly quote?: { jobId: string; quoteId: string; terms: BookingTerms };

  // slot #136 (studio): readonly providerType?: ProviderType | null;

  // slot #190 (add-ons): readonly addons?: readonly AddonLine[]; readonly pickup?: BookingPickup;
}

export function draftTotal(i: BookingDraftInput): number {
  return i.service.price; // slot #190 (add-ons): bookingTotal(i.service, i.addons ?? [])
}

export function buildBookingDraft(i: BookingDraftInput): Booking {
  const core = coreDraft(i);
  return {
    ...core,
    // slot #139 (quotes): ...quoteDraftFields(i),

    // slot #136 (studio): ...studioDraftFields(i, core),

    // slot #190 (add-ons): ...addonDraftFields(i),
  };
}
```

The comment after each marker is the field the consumer's plan already specifies (#139 Decision 1, #136 Decision 8, #190 Contract); the consumer turns that comment into code. `coreDraft(i)` is module-private. A slot helper must return `{}` (not `{field: undefined}`) when its input is absent.

## File structure

- Create `packages/domain/src/milestones.ts`, `packages/domain/test/milestones.test.ts`.
- Modify `packages/domain/src/create_booking.ts` (builder, slots, refactor), `booking_policy.ts` (revision rule), `booking_ports.ts` (`ServiceRecord.revisions?`), `booking.ts` (`revisionsIncluded?`), `index.ts` (`export * from './milestones.js'`); tests `test/create_booking.test.ts`, `test/booking_policy.test.ts`.
- Modify `app_flutter/firebase/functions/src/infra/booking_firestore.ts`, `src/infra/booking_readers.ts` (extract `serviceRecordOf`); tests `test/unit/booking_firestore.test.ts`, create `test/unit/booking_readers.test.ts`.
- Create `docs/superpowers/handover/ledger-n2-booking-draft.md`.

## Review Focus

1. **A plain booking gains a stray key** (a slot writing `undefined`/`null`, or a future slot leaking into package bookings): Firestore `set` rejects `undefined` and the app would read a package booking as a quote or studio booking. Pinned: Task 2 `a plain draft has exactly the core keys`.
2. **Milestones that do not add up to the net** for odd amounts, uneven percents or very large amounts. Pinned: Task 1 `shoot + delivery equals net for every net and percent pair` and `exact at Number.MAX_SAFE_INTEGER`.
3. **Bad split input producing money silently** (percents not summing to 100, fractional percents, a negative or fractional net). Pinned: Task 1 `invalid input is invalid_argument`.
4. **Older documents** (bookings without `revisionsIncluded`, packages without `deliverables.revisions`): must read as absent, never as 0 free rounds. Pinned: Task 2 `clampRevisions` table; Task 3 `a booking without revisionsIncluded reads it as undefined`, `a package without deliverables.revisions has no revisions`.
5. **The refactor changes `createBookingDraft`** (error order, replaced own draft, id draw, day hold, contact snapshot). Pinned: every existing `create_booking.test.ts` test unchanged and green, plus Task 2 `createBookingDraft writes exactly buildBookingDraft(...)`.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`. No new Firestore read or write per user action (the package document is already read by `createBooking`; `revisionsIncluded` is one more integer, ≈ 20 bytes, on a booking document that is already written). No new Function, scheduled job, Storage object or paid API. **Conclusion: +$0/month** at (b) 1,000 MAU and at (c) 10,000 MAU.

## Tasks

### Task 1: `milestoneAmounts` and the default split

**Files:**
- Create: `packages/domain/src/milestones.ts`, `packages/domain/test/milestones.test.ts`
- Modify: `packages/domain/src/index.ts`

**Interfaces:**
- Consumes: `DomainError` (`errors.ts`).
- Produces: Contract → `milestones.ts` (`MILESTONE_KINDS`, `MilestoneKind`, `DEFAULT_MILESTONE_PERCENTS`, `milestoneAmounts`), exported from `index.ts`.

- [ ] **Step 1: Contract check.** `ls packages/domain/src/milestones.ts` must not exist; `DomainError('invalid_argument')` exists. Ledger differences.
- [ ] **Step 2: Failing tests** in `milestones.test.ts`:
  - `default 50/50: 1_500_001 → shoot 750_000, delivery 750_001`.
  - `percents {shoot: 30, delivery: 70} on 1_000_001 → 300_000 / 700_001`.
  - `3_400_000 → 1_700_000 / 1_700_000` (the number #190 pins its payout line on).
  - `0 → 0 / 0`; `{shoot: 0, delivery: 100} on 999 → 0 / 999`; `{shoot: 100, delivery: 0} on 999 → 999 / 0`.
  - `shoot + delivery equals net for every net and percent pair` (nets 0–1,000 and 1_000_000–1_000_100, shoot% 0–100 step 1: sum equals net, `shoot === Math.floor(net * p / 100)`).
  - `exact at Number.MAX_SAFE_INTEGER`: 50/50 → shoot `4_503_599_627_370_495`, delivery `4_503_599_627_370_496`.
  - `invalid input is invalid_argument`: net `-1`, `1.5`, `NaN`, `Number.MAX_SAFE_INTEGER + 2`; percents `{60, 60}`, `{50.5, 49.5}`, `{-10, 110}`.
  - `DEFAULT_MILESTONE_PERCENTS is 50/50 and MILESTONE_KINDS is ['shoot', 'delivery']`.
  - `milestoneAmounts is exported from the package index` (import from `../src/index.js`).
- [ ] **Step 3:** `cd packages/domain && npm test` — the new tests fail (module missing).
- [ ] **Step 4: Implement** `milestoneAmounts(net, percents = DEFAULT_MILESTONE_PERCENTS)` in `milestones.ts`; validation per Decision 7 (`Number.isSafeInteger(net) && net >= 0`; both percents safe integers in 0–100; `shoot + delivery === 100`). Exact split, the one part easy to get wrong:
  ```ts
  const q = Math.floor(net / 100), r = net % 100;
  const shoot = q * percents.shoot + Math.floor((r * percents.shoot) / 100);
  return { shoot, delivery: net - shoot };
  ```
  Add `export * from './milestones.js';` to `index.ts` next to `escrow.js`.
- [ ] **Step 5:** `npm test && npm run lint` green (incl. `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): milestoneAmounts and the default 50/50 milestone split [#199]`.

### Task 2: `buildBookingDraft`, the slots and the revision rule

**Files:**
- Modify: `packages/domain/src/create_booking.ts`, `booking_policy.ts`, `booking_ports.ts`, `booking.ts`; tests `packages/domain/test/create_booking.test.ts`, `booking_policy.test.ts`

**Interfaces:**
- Consumes: `computeDeposit`, `addMinutesToTime`, `DRAFT_EXPIRY_MINUTES` (`booking_policy.ts`), `ServiceRecord`, `BookingDeps`.
- Produces: Contract → `booking_policy.ts` (`DEFAULT_REVISIONS`, `REVISIONS_MAX`, `clampRevisions`), `ServiceRecord.revisions?`, `Booking.revisionsIncluded?`, `create_booking.ts` (`BookingDraftCore`, `BookingDraftInput` with the three slot markers, `draftTotal`, `buildBookingDraft`; `createBookingDraft` unchanged signature).

- [ ] **Step 1: Contract check.** `createBookingDraft` still builds its literal inline and calls `acceptsOrders` between the service and price checks; `grep -rn "buildBookingDraft\|clampRevisions\|revisionsIncluded" packages/domain/src` is empty. If #198 has merged first and replaced the `acceptsOrders` call, keep its call exactly where it is. Ledger differences.
- [ ] **Step 2: Failing tests.**
  - `booking_policy.test.ts`: `clampRevisions: undefined → 1, null → 1, 'x' → 1, NaN → 1, 0 → 0, 2 → 2, 2.5 → 2, 7 → 5, -1 → 0, Infinity → 5`.
  - `create_booking.test.ts`, new `describe('buildBookingDraft')` with `BASE: BookingDraftInput = {id: 'b_x', customerId: 'c1', photographerId: 'p1', service: <srv_01 record>, day: '2026-10-15', start: '14:00', place: {name: 'Nhà thờ Lớn'}, note: 'Chụp áo dài', now: new Date('2026-10-10T10:00:00.000Z')}`:
    - `builds the draft from the core input`: `status 'draft'`, `serviceId 'srv_01'`, `serviceSnapshot {name, price: 1_000_000, durationMinutes: 120}`, `end '16:00'`, `deposit 1_000_000`, `remaining 0`, `payableUntil '2026-10-10T10:30:00.000Z'`, `version 1`, `createdAt === updatedAt === '2026-10-10T10:00:00.000Z'`.
    - `is pure`: two calls with the same input are `deepEqual`, and the input object is unchanged (`structuredClone` before/after).
    - `a plain draft has exactly the core keys`: `Object.keys(...).sort()` equals `['createdAt', 'customerId', 'day', 'deposit', 'end', 'id', 'note', 'payableUntil', 'photographerId', 'place', 'remaining', 'revisionsIncluded', 'serviceId', 'serviceSnapshot', 'start', 'status', 'updatedAt', 'version']` and no value is `undefined`. (Consumers keep this test green: their slots add nothing to a plain draft.)
    - `snapshots revisionsIncluded from service.revisions, default 1`: no `revisions` → 1; `revisions: 3` → 3; `revisions: 9` → 5.
    - `deposit comes from draftTotal`: `draftTotal(BASE) === 1_000_000` and `buildBookingDraft(BASE).deposit === computeDeposit(draftTotal(BASE)).deposit`.
    - `a quote-style synthetic service works`: `service.id ''`, `price 2_500_000`, `durationMinutes 180`, `revisions 0` → `serviceId ''`, `deposit 2_500_000`, `end '17:00'`, `revisionsIncluded 0`.
  - `createBookingDraft writes exactly buildBookingDraft(...)`: after `const booking = await newDraft(world, {note: 'Chụp áo dài'})` (`DRAFT_INPUT` + note, from `test/support/booking_world.ts`), `assert.deepEqual(await world.store.getBooking(booking.id), buildBookingDraft({id: booking.id, customerId: 'c1', photographerId: 'p1', service: world.services.get('srv_01')!, day: '2026-10-15', start: '14:00', place: {name: 'Nhà thờ Lớn'}, note: 'Chụp áo dài', now: world.clock.now()}))`.
  - Every existing test in `create_booking.test.ts` stays as is (order: `not_found` before `not_accepting_orders` before `price_changed`/`phone_required`; own draft replaced; `day_taken`; nothing written on refusal).
- [ ] **Step 3:** `cd packages/domain && npm test` — the new tests fail.
- [ ] **Step 4: Implement.** Revision rule in `booking_policy.ts` (`typeof v !== 'number' || Number.isNaN(v)` → `DEFAULT_REVISIONS`; else `Math.min(REVISIONS_MAX, Math.max(0, Math.trunc(v)))`, `Infinity` → 5). `readonly revisions?: number` on `ServiceRecord` (doc: "free revision rounds; `deliverables.revisions` of the package, a quote's `terms.revisions`"), `readonly revisionsIncluded?: number` on `Booking`. In `create_booking.ts`: `BookingDraftCore`, the slot layout of Contract **verbatim** (markers, blank lines between slots, the `// ── … ──` fences), module-private `coreDraft(i)`, `draftTotal`, `buildBookingDraft`. Refactor `createBookingDraft`: same steps in the same order (Contract with existing code); drop the local `computeDeposit`/`addMinutesToTime` calls; inside the transaction keep `const bookingId = deps.ids.newId()` at the same point and write `const booking = buildBookingDraft({id: bookingId, customerId: input.customerId, photographerId: input.photographerId, service, day: input.day, start: input.start, place: input.place, note: input.note, now})`. Update the file's top comment: "Every order path builds its booking with `buildBookingDraft`; later units extend it only through the slots."
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): shared buildBookingDraft with extension slots and free revision rounds [#199]`.

### Task 3: Firestore mapping, ledger

**Files:**
- Modify: `app_flutter/firebase/functions/src/infra/booking_firestore.ts`, `src/infra/booking_readers.ts`, `test/unit/booking_firestore.test.ts`
- Create: `app_flutter/firebase/functions/test/unit/booking_readers.test.ts`, `docs/superpowers/handover/ledger-n2-booking-draft.md`

**Interfaces:**
- Consumes: Task 2 (`Booking.revisionsIncluded?`, `ServiceRecord.revisions?`).
- Produces: `export function serviceRecordOf(id: string, photographerId: string, d: DocumentData): ServiceRecord` in `booking_readers.ts` (used by `FirestoreServiceCatalog.getService`; today's defaults unchanged: `name ''`, `price 0`, `durationMinutes 60`, `active` unless `false`); `bookingToFirestore` writes `revisionsIncluded: b.revisionsIncluded ?? null`; `bookingFromFirestore` returns `revisionsIncluded` only when the stored value is a number.

- [ ] **Step 1: Contract check** of the two mappers and `getService`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `booking_firestore.test.ts`: extend the shared `round-trips Booking through Firestore conversion` test (add `revisionsIncluded: 2` to `sampleBooking`, assert it is restored); new `a booking without revisionsIncluded reads it as undefined` (doc built by `bookingToFirestore` of a booking without it, then the field deleted → `restored.revisionsIncluded === undefined`; and with stored `null` → `undefined`).
  - `booking_readers.test.ts`: `serviceRecordOf reads deliverables.revisions` (`{name: 'Cưới', price: 3_000_000, durationMinutes: 240, deliverables: {revisions: 2}}` → `revisions 2`); `a package without deliverables.revisions has no revisions` (no `revisions` key); `a non-number revisions is ignored` (`'2'` → no key); `defaults are unchanged` (`{}` → `name ''`, `price 0`, `durationMinutes 60`, `active true`; `active: false` → `false`).
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` — the new tests fail.
- [ ] **Step 4: Implement** the two mappings and `serviceRecordOf`; `getService` returns `serviceRecordOf(snap.id, photographerId, d)`.
- [ ] **Step 5:** `npm test && npm run lint && npm run build` (functions) and `cd packages/domain && npm test` green.
- [ ] **Step 6: Ledger** `docs/superpowers/handover/ledger-n2-booking-draft.md`: Decisions 1–8 as rulings; the slot markers as merged (copy the three blocks); whether #198 had merged first (Task 2 Step 1); the consumers' one-line instructions: #139 fills slot "quotes" (`quote?`, `quoteDraftFields`), #136 slot "studio" (`providerType?: ProviderType | null`, optional, `studioDraftFields(i, core)`), #190 slot "add-ons" (`addons?`, `pickup?`, `addonDraftFields`, and the body of `draftTotal`), #152 adds the milestone model to `milestones.ts` and reads `b.revisionsIncluded ?? DEFAULT_REVISIONS`; skipped suites: none.
- [ ] **Step 7: Commit** `feat(functions): map revisionsIncluded and package revisions; N2 ledger [#199]`.

## Deferred / not here

- Order gate (`assertOrderAllowed`, `orderBlocker`): #198.
- Milestone model, `splitMilestones`, release, payouts and earnings per milestone: #152 Task 3.
- `revisionsIncluded` in the Flutter `Booking` and S05.06/S05.07 display: #152.
- Editing "Số lần sửa" in the package editor (S08.01, writes `deliverables.revisions`): #146.
- Quote, studio and add-on fields: #139, #136, #190 through their slots.
