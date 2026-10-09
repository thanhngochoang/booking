# N1 · Cổng nhận đơn (orderBlocker, BlockGate) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (standing rule):** this plan changes no `firestore.rules` and no indexes. It adds one Functions integration test: write it, do not run it; CI runs it. Record the skip in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **Detail level (owner, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** One shared order gate that every order path calls: `orderBlocker` / `assertOrderAllowed` check that the provider accepts orders and then that neither party blocked the other (`BlockGate`), answering `not_accepting_orders` or the new error code `blocked`. `createBookingDraft` and `createPayment` use it today; quotes (#139), Chụp ngay (#140), studio assignment (#136) and collaborators (#151) call it without waiting for S20 (#144).

**Architecture:** Domain (`packages/domain`): new `order_gate.ts` (`OrderGateDeps`, `orderBlocker`, `assertOrderAllowed`), new `block_ports.ts` (`BlockGate`, `blockDocId`), new `fake_block_gate.ts` (`FakeBlockGate`), `blocked` in `ERROR_CODES`; `BookingDeps` gains a required `blocks: BlockGate`. Functions: `FirestoreBlockGate` reads `blocks/{blockerId}_{blockedId}` (the documents #144 will write; until then none exist and the gate answers false), `liveBlockGate()`, `blocked` → `failed-precondition`. App: `BookingErrorCode.blocked` and the copy `bookingErrBlocked` on the booking sheet and the S04.04 payment screen.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2, Admin SDK, `node --test`); Flutter, Riverpod 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3i.3 (S20: "không đặt lịch được với nhau"); `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §3, §7 (only verified, onboarded providers take orders; `createPayment` re-checks); `docs/superpowers/plans/2026-10-07-INDEX.md` (owner rule: every order path goes through `orderBlocker`/`assertOrderAllowed`); `2026-10-08-s04-reconciliation.md` (rows `OrderGateDeps …` and "Decision 9 (1)": #129 built neither); `2026-10-07-s20-report-block.md` Decisions 1–2 (block storage and what the server refuses: this plan is the gate slice of it).

**Issue:** #198 (Nền · Cổng nhận đơn (orderBlocker, BlockGate)). **Blocked by:** nothing (#129 S04 and #134 S06 are merged). **Blocks:** #144 (S20), #139 (S15–S16), #140 (S13–S14), #136 (S26), #151 (S27). **Branch:** `plan/198-cong-nhan-don` from `origin/develop`, PR into `develop` titled `feat(orders): shared order gate and BlockGate [#198]`.

**Owns (others consume):** `OrderGateDeps`, `orderBlocker`, `assertOrderAllowed`, `BlockGate`, `blockDocId`, `FakeBlockGate`, the error code `blocked` (domain + callable mapping), `FirestoreBlockGate`, `liveBlockGate()`, Dart `BookingErrorCode.blocked`, l10n `bookingErrBlocked`. **Does not own:** writing blocks (`blockUser`/`unblockUser`, the per-user index, rules for `blocks`: #144), block checks outside order paths (`openInquiry`, `sendMessage`, `getContactLink`, `registerEvent`: #144), the settlement re-check in `handleTransferNotification` (#135 S21 Decision 15).

## Contract with existing code

Checked 2026-10-08 on `develop` 4e25834. Each task's first step re-checks the names it uses; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `ERROR_CODES` / `ErrorCode` / `DomainError(code)` (`errors.ts`; has `not_accepting_orders`, no `blocked`); `ProviderOrderGate { acceptsOrders(photographerId): Promise<boolean> }` and `BookingDeps {store, services, providers, contacts, gateway, clock, ids}` (`booking_ports.ts:23, 200`); `createBookingDraft(deps: BookingDeps, rawInput)` (`create_booking.ts`: validate → `getService` (`not_found`) → inline `deps.providers.acceptsOrders(input.photographerId)` (`not_accepting_orders`) → `price_changed` → phone → transaction); `createPayment(deps: BookingDeps, {bookingId, customerId, method})` (`create_payment.ts`: method and id checks → `requireCustomerPhone` → `getPaymentsForBooking` → transaction that reads the booking and throws `not_found` / `permission_denied` / `conflict` / `day_taken`; **no gate**); `BookingStore.getBooking(id)` (plain read, `booking_ports.ts:118`); pure `acceptsOrders(fields)` (`provider_orders.ts`, different thing, same name); `FakePaymentGateway` (`fake_payment_gateway.ts`, the pattern for a fake in `src`); `index.ts` re-exports every module. Test world `test/support/booking_world.ts` (`createBookingWorld()` builds `BookingDeps` with `providers: { acceptsOrders: async (id) => acceptsOrders(providers.get(id)) }`, `newDraft`, `payDraft`); `test/create_booking.test.ts` has the describe with `refuses a provider that is not verified with not_accepting_orders`, `checks the service before the provider`, `checks the provider before price and phone`.
- Functions (`app_flutter/firebase/functions`): `TRANSPORT_CODE: Record<ErrorCode, FunctionsErrorCode>` + `toHttpsError` (`src/callables/errors.ts`; the `Record` makes a missing code a type error); `liveBookingDeps()` (`src/infra/live_booking.ts`), `FirestoreProviderOrderGate` (`src/infra/booking_readers.ts`), `db()` (`src/infra/admin.ts`); `BookingDeps` literals in `test/unit/booking_callables.test.ts:34` (`createTestDeps`, provider `closed1` refused), `booking_clock_ticket_release.test.ts:79`, `event_payment_callables.test.ts:83`, `support/payment_world.ts:49`; `test/unit/errors.test.ts` (`each domain code has a fitting transport code` lists every code); fake-Firestore pattern `{…} as unknown as Firestore` (`photographer_write.test.ts:71`); `test/integration/booking.test.ts`. `npm test` runs through `tsx` (no typecheck); `npm run build` typechecks.
- Firestore today: no `blocks` collection; rules end in a catch-all deny, so only the Admin SDK can ever write `blocks/*` (#144 adds the blocker's read rule).
- App (`app_flutter/lib`): `enum BookingErrorCode {dayTaken, phoneRequired, priceChanged, notEligible, notAcceptingOrders, deadlinePassed, conflict, permissionDenied, notFound, invalidArgument, paymentAttemptsExceeded, network, unknown}`, `bookingErrorOf`, `_codeToBookingError` (`data/booking/booking_repository.dart:15–90`); exhaustive `switch` on it in `features/booking/booking_flow_controller.dart:302` (`_handleError`) and `features/booking/booking_sheet_page.dart:107` (`_handleError`, SnackBar copy); `payment_pending_screen.dart:64` and `qr_checkout_view.dart:96` map `paymentAttemptsExceeded` and fall back to `bookTryAgain`; `test/support/fake_booking_repository.dart` `_serverCodeFor` (exhaustive), `nextError`, `nextPaymentError`; l10n `bookNotAcceptingOrders` "Nhiếp ảnh gia này chưa nhận đặt lịch." (last key of `app_vi.arb`), `payAttemptsExceeded`.

## Global Constraints

- Owner rule (INDEX 2026-10-07): "Mọi đường tạo đơn … kiểm cổng bằng `orderBlocker`/`assertOrderAllowed` (`ProviderOrderGate`: thợ đang nhận đơn, rồi `BlockGate` của S20)". Order of checks: provider gate first, then blocks; `not_accepting_orders` wins over `blocked`.
- Spec §3i.3: blocked pairs "không đặt lịch được với nhau (booking đang có vẫn giữ để không mất tiền …)": the gate refuses new orders and new payments only; it never touches an existing booking, payment or refund.
- Error code `blocked`, transport `failed-precondition`, `details.code: 'blocked'` (same shape as every domain code).
- CLAUDE.md: rules in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions are thin adapters; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `package:photobooking/...` imports, features import `core/core.dart`; Firebase only in `lib/data/**` (nothing Firebase in this plan's app part). Code comments do not link `docs/superpowers` (that folder does not ship); state the fact instead.
- Block document path (shared with #144, do not change): `blocks/{blockerId}_{blockedId}`; "A blocked B" = that document exists. Absent documents mean "not blocked".
- Commits: Conventional Commits, subject ends with `[#198]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: domain `cd packages/domain && npm test && npm run typecheck && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; Flutter `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; the Functions integration test is written, not run.

## Decisions

1. **Where the gate lives.** `order_gate.ts` (not `create_booking.ts`, which #152 reshapes with `buildBookingDraft`), re-exported from `index.ts`. `BlockGate` and `blockDocId` live in `block_ports.ts`; #144 adds its block store ports to the same file and its pure block model to `block.ts` (without redefining `blockDocId`).
2. **`OrderGateDeps.blocks` is optional, `BookingDeps.blocks` is required.** Optional matches the contract the consuming plans already wrote (`JobDeps extends OrderGateDeps`, `blocks?: BlockGate`); required on `BookingDeps` makes the compiler refuse a live or test booking deps without a gate. Consumers' live deps must set `blocks: liveBlockGate()` (Global Constraint for #139/#140/#136/#151; their plans already say so).
3. **Who is "customer" and "provider".** `orderBlocker(deps, {customerId, providerId})` checks `providers.acceptsOrders(providerId)` and `blocks.isBlockedEitherWay(customerId, providerId)`. Callers pass the person who orders and the person who would do the work (studio assignment: customer ↔ assignee).
4. **`createPayment` re-check.** A plain `deps.store.getBooking(bookingId)` before the transaction; the gate runs only when that booking exists, belongs to the caller and is a `draft`, with `providerId = booking.photographerId`. Otherwise the transaction answers as today (`not_found`, `permission_denied`, `conflict`), so a stranger never learns about a block. The gate runs after `requireCustomerPhone` and before any payment is read or created, so a refusal writes nothing; the held draft then expires through `bookingClock` as any abandoned draft does.
5. **`FirestoreBlockGate`.** One `getAll` of `blocks/{a}_{b}` and `blocks/{b}_{a}`; true when either exists. No cache (a block must apply at once). Before #144 lands no such document exists, so behaviour is unchanged.
6. **App copy.** `bookingErrBlocked` "Không đặt lịch được với người này." on the booking sheet (SnackBar, no "Thử lại") and on S04.04 when "Tạo QR mới" or the first QR is refused. The text does not say who blocked whom (spec: no notice to the blocked person).

## Contract

### Domain (`packages/domain/src`)

```ts
// errors.ts: ERROR_CODES gains
  /** The customer and the provider blocked each other in either direction; no new order between them. */
  'blocked',

// block_ports.ts
/** "blockerId blocked blockedId" is the document `blocks/{blockDocId(blockerId, blockedId)}`. */
export const blockDocId = (blockerId: string, blockedId: string): string => `${blockerId}_${blockedId}`;
/** Whether either user blocked the other. */
export interface BlockGate {
  isBlockedEitherWay(a: string, b: string): Promise<boolean>;
}

// fake_block_gate.ts
export class FakeBlockGate implements BlockGate {
  constructor(pairs?: Iterable<readonly [blockerId: string, blockedId: string]>);
  block(blockerId: string, blockedId: string): void;
  unblock(blockerId: string, blockedId: string): void;
  /** Every isBlockedEitherWay call as [a, b], in order. */
  readonly calls: ReadonlyArray<readonly [string, string]>;
  isBlockedEitherWay(a: string, b: string): Promise<boolean>;
}

// order_gate.ts
export type OrderBlock = 'not_accepting_orders' | 'blocked';
export interface OrderGateDeps {
  readonly providers: ProviderOrderGate;
  /** Missing → blocks are not checked. Every live deps sets it (liveBlockGate()). */
  readonly blocks?: BlockGate;
}
export interface OrderParties { readonly customerId: string; readonly providerId: string }
/** Provider gate first, then blocks. null = the order may go ahead. */
export async function orderBlocker(deps: OrderGateDeps, p: OrderParties): Promise<OrderBlock | null>;
/** Throws DomainError(orderBlocker's answer) when it is not null. */
export async function assertOrderAllowed(deps: OrderGateDeps, p: OrderParties): Promise<void>;

// booking_ports.ts: BookingDeps gains
  readonly blocks: BlockGate;
// create_booking.ts: the inline acceptsOrders check becomes
//   await assertOrderAllowed(deps, { customerId: input.customerId, providerId: input.photographerId });
// create_payment.ts: Decision 4.
```

### Functions (`app_flutter/firebase/functions/src`)

```ts
// infra/safety_firestore.ts (#144 adds its block and report stores to this file)
export class FirestoreBlockGate implements BlockGate {
  constructor(firestore?: Firestore);           // default db()
  isBlockedEitherWay(a: string, b: string): Promise<boolean>;   // Decision 5
}
// infra/live_safety.ts (#144 adds liveBlockDeps(), liveReportDeps())
export function liveBlockGate(): BlockGate;     // new FirestoreBlockGate(db())
// infra/live_booking.ts: liveBookingDeps() gains `blocks: liveBlockGate()`
// callables/errors.ts: TRANSPORT_CODE gains `blocked: 'failed-precondition'`
```

### App (Dart)

```dart
// lib/data/booking/booking_repository.dart
enum BookingErrorCode { …, notAcceptingOrders, blocked, … }   // _codeToBookingError: 'blocked' → blocked
```
l10n (`app_vi.arb`, exact): `bookingErrBlocked` "Không đặt lịch được với người này." (`@bookingErrBlocked` description: "S04: createBooking/createPayment refused because the customer and the photographer blocked each other (blocked).")

## Review Focus

1. **Block in either direction.** `blocks/{customer}_{provider}` and `blocks/{provider}_{customer}` must both refuse. Pinned by Task 1 `orderBlocker returns blocked when the provider blocked the customer` / `… when the customer blocked the provider` and Task 2 `FirestoreBlockGate is true for either document`.
2. **No block documents yet.** Until #144 writes `blocks/*`, every booking must still go through. Pinned by Task 2 `FirestoreBlockGate is false when neither document exists` and the unchanged `createBookingDraft` suite.
3. **A stranger probing `createPayment`.** Calling it on someone else's booking must still answer `permission_denied`, never `blocked`. Pinned by Task 1 `createPayment by another customer answers permission_denied even for a blocked pair`.
4. **A deps object without a gate.** A live `BookingDeps` without `blocks` would silently skip blocks. Pinned by the required field (Task 1) and `npm run build` in Task 2 (typecheck of `liveBookingDeps`).
5. **Old app or other screens showing a generic error.** S04.04 "Tạo QR mới" refused with `blocked` must not say "Thử lại" forever. Pinned by Task 3 `"Tạo QR mới" refused with blocked shows "Không đặt lịch được với người này."`.

## Chi phí Google

Unit prices (cost spec `2026-10-07-google-cloud-costs.md`): Firestore $0.06/100K reads (nam5 upper bound, **chưa xác nhận** for Singapore); a `getAll` of a missing document is billed as one read. **Functions (one rule for every plan, cost spec §12):** this plan adds no function, trigger or scheduled job; the extra work inside `createBooking`/`createPayment` is a few milliseconds → $0 at (b) and (c). Assumptions as S20: 300 (b) / 3,000 (c) bookings per month, ~1.2 `createPayment` calls per booking.

| Action | Reads | Writes | Notes |
|---|---|---|---|
| `createBooking` | +2 | 0 | `getAll` of the two block documents |
| `createPayment` | +4 | 0 | booking pre-read, provider document, two block documents |

Reads/month: (b) 300 × 2 + 360 × 4 ≈ 2.0K → **$0.001**; (c) ≈ 20K → **$0.012**. No Storage, no paid API.

**Conclusion:** about **$0.001/month at (b)** and **$0.01/month at (c)**; under $5, no mitigation needed. (Later order paths of #139/#140/#136/#151 count their own `+2` per gate call.)

## File structure

- `packages/domain/src/order_gate.ts` (new): the gate, nothing else.
- `packages/domain/src/block_ports.ts` (new): `BlockGate`, `blockDocId` (#144 extends).
- `packages/domain/src/fake_block_gate.ts` (new): in-memory gate for tests of every package.
- `packages/domain/test/order_gate.test.ts` (new).
- `app_flutter/firebase/functions/src/infra/safety_firestore.ts`, `src/infra/live_safety.ts` (new, #144 extends); `test/unit/safety_firestore.test.ts` (new).
- Modified: `errors.ts`, `booking_ports.ts`, `create_booking.ts`, `create_payment.ts`, `index.ts`, domain booking world and tests; functions `errors.ts`, `live_booking.ts`, deps literals in four unit test files, `errors.test.ts`, `booking_callables.test.ts`, `test/integration/booking.test.ts`; app `booking_repository.dart`, `booking_flow_controller.dart`, `booking_sheet_page.dart`, `payment_pending_screen.dart`, `qr_checkout_view.dart`, `app_vi.arb`, `fake_booking_repository.dart`, their tests; `docs/superpowers/specs/data-model/domain-model.md` (ErrorCode row); ledger.

## Tasks

### Task 1: Domain — order gate, BlockGate, `blocked`

**Files:**
- Create: `packages/domain/src/order_gate.ts`, `block_ports.ts`, `fake_block_gate.ts`; `packages/domain/test/order_gate.test.ts`
- Modify: `src/errors.ts`, `src/booking_ports.ts` (`BookingDeps.blocks`), `src/create_booking.ts`, `src/create_payment.ts`, `src/index.ts` (export the three new modules), `test/support/booking_world.ts` (`blocks: FakeBlockGate` in deps and on `BookingWorld`), `test/create_booking.test.ts`, `test/create_payment.test.ts`, every other domain test that builds a `BookingDeps` literal (the typecheck lists them); `docs/superpowers/specs/data-model/domain-model.md` (`ErrorCode` row: add `blocked`, "khách và thợ đã chặn nhau (một trong hai chiều); không đơn mới giữa hai người")

**Interfaces:**
- Consumes: `ProviderOrderGate`, `DomainError`, `BookingStore.getBooking`.
- Produces: Contract §Domain (exact names other plans import from `@photobooking/domain`).

- [ ] **Step 1:** Contract check (domain bullet); ledger differences. #199 (`2026-10-08-n2-booking-draft.md`, `buildBookingDraft`) runs in parallel and edits other lines of `create_booking.ts`; whichever merges second rebases: the `acceptsOrders` call between the service check and the price check is the only line this plan changes there.
- [ ] **Step 2: Failing tests.** `order_gate.test.ts` (a `FakeBlockGate` and a map-backed `ProviderOrderGate`):
  - `orderBlocker returns null for an accepting provider and no block`;
  - `orderBlocker returns not_accepting_orders for a provider who does not accept orders`;
  - `orderBlocker returns blocked when the provider blocked the customer` (`new FakeBlockGate([['p1', 'c1']])`) and `… when the customer blocked the provider` (`[['c1', 'p1']]`);
  - `a block between other people does not refuse` (`[['c1', 'p2']]` → null for c1/p1);
  - `not_accepting_orders wins over blocked and the block gate is not consulted` (`gate.calls` is empty);
  - `without blocks deps orderBlocker ignores blocks`;
  - `assertOrderAllowed throws DomainError with the blocker code and resolves when null`;
  - `FakeBlockGate unblock removes only that direction`.
  `create_booking.test.ts` (in the existing provider describe): `refuses a blocked pair with blocked and holds nothing` (`world.blocks.block('p1', 'c1')`; no availability day, no draft); `the provider check still runs before price and phone` (existing test stays green). `create_payment.test.ts`: `refuses a provider who stopped accepting orders with not_accepting_orders` (draft made, then `world.providers.set('p1', {verified: false, onboardingComplete: true})`; no payment written, `gateway.createPaymentCalls` empty); `refuses a blocked pair with blocked` (draft, then `world.blocks.block('c1', 'p1')`; nothing written); `createPayment by another customer answers permission_denied even for a blocked pair` (`c2` with a phone calls on c1's draft while `p1` blocked `c1`).
- [ ] **Step 3:** `cd packages/domain && npm test`; the new tests fail.
- [ ] **Step 4: Implement** per Contract and Decisions 1–4. `createPayment`, between `requireCustomerPhone` and `getPaymentsForBooking`:
  ```ts
  const pre = await deps.store.getBooking(input.bookingId);
  if (pre && pre.customerId === input.customerId && pre.status === 'draft') {
    await assertOrderAllowed(deps, { customerId: pre.customerId, providerId: pre.photographerId });
  }
  ```
  Update every `BookingDeps` literal the typecheck flags with `blocks: new FakeBlockGate()`.
- [ ] **Step 5:** `npm test && npm run typecheck && npm run lint` green (incl. `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): shared order gate with BlockGate and the blocked error [#198]`.

### Task 2: Functions — FirestoreBlockGate, live wiring, error mapping

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/safety_firestore.ts`, `src/infra/live_safety.ts`; `test/unit/safety_firestore.test.ts`
- Modify: `src/callables/errors.ts`, `src/infra/live_booking.ts`; `BookingDeps` literals in `test/unit/booking_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `event_payment_callables.test.ts`, `support/payment_world.ts` (`blocks: new FakeBlockGate()` from `@photobooking/domain`; `createTestDeps` returns the gate); `test/unit/errors.test.ts`, `test/unit/booking_callables.test.ts`; integration `test/integration/booking.test.ts` (written, not run)

**Interfaces:**
- Consumes: Task 1 (`BlockGate`, `blockDocId`, `FakeBlockGate`, `'blocked'`).
- Produces: Contract §Functions; #139/#140/#136/#151 put `blocks: liveBlockGate()` in their live deps.

- [ ] **Step 1:** Contract check (functions bullet).
- [ ] **Step 2: Failing tests.** `safety_firestore.test.ts` with a fake `{ doc: (p) => ({ path: p }), getAll: async (...refs) => refs.map((r) => ({ exists: existing.has(r.path) })) } as unknown as Firestore`: `FirestoreBlockGate is false when neither document exists`; `FirestoreBlockGate is true for either document` (`blocks/c1_p1` alone, then `blocks/p1_c1` alone); `FirestoreBlockGate reads both documents in one getAll` (one call, paths `blocks/c1_p1` and `blocks/p1_c1`). `errors.test.ts`: add `blocked: 'failed-precondition'` to the expected map; `blocked maps to failed-precondition with details.code blocked`. `booking_callables.test.ts`: `createBooking refuses a blocked pair with failed-precondition and details.code blocked`; `createPayment refuses a blocked pair with failed-precondition and details.code blocked` (draft first, then block). Integration (written, not run): `a block document either way makes createBooking answer failed-precondition blocked` (Admin SDK writes `blocks/{photographer}_{customer}` with `{blockerId, blockedId, createdAt}`, then the customer's `createBooking`; delete it and the same call succeeds).
- [ ] **Step 3:** `npm test`; the new tests fail.
- [ ] **Step 4: Implement** per Contract and Decision 5 (paths through `blockDocId`).
- [ ] **Step 5:** `npm test && npm run build` (functions) green; domain `npm test` still green.
- [ ] **Step 6: Commit** `feat(functions): FirestoreBlockGate and blocked error for createBooking and createPayment [#198]`.

### Task 3: App — `BookingErrorCode.blocked`, copy, ledger

**Files:**
- Modify: `app_flutter/lib/data/booking/booking_repository.dart`, `lib/features/booking/booking_flow_controller.dart`, `lib/features/booking/booking_sheet_page.dart`, `lib/features/booking/payment_pending_screen.dart`, `lib/features/booking/qr_checkout_view.dart`, `lib/l10n/app_vi.arb` (+ `flutter gen-l10n`), `test/support/fake_booking_repository.dart` (`_serverCodeFor`: `blocked` → `'blocked'`); tests `test/data/booking/booking_repository_test.dart`, `test/features/booking/submit_test.dart`, `test/features/booking/booking_flow_controller_test.dart`, `test/features/booking/payment_pending_screen_test.dart`
- Create: `docs/superpowers/handover/ledger-n1-order-gate.md`

**Interfaces:**
- Consumes: server `details.code: 'blocked'` (Task 2).
- Produces: `BookingErrorCode.blocked`, `bookingErrBlocked` (#144 S20 Task 6 and the order plans reuse them).

- [ ] **Step 1:** Contract check (app bullet).
- [ ] **Step 2: Failing tests.** `booking_repository_test.dart`: `bookingErrorOf maps blocked to blocked`. `booking_flow_controller_test.dart`: `blocked clears the draft id and goes idle with error blocked; the profile is not re-read`. `submit_test.dart` (same set-up as the `not_accepting_orders` test): `a blocked pair refused by the server shows "Không đặt lịch được với người này."` with no "Thử lại" and `paymentCalls` empty; `blocked from createPayment shows the same text and does not open /pay` (`nextPaymentError = BookingErrorCode.blocked`). `payment_pending_screen_test.dart` (same set-up as the fourth-attempt test): `"Tạo QR mới" refused with blocked shows "Không đặt lịch được với người này."`.
- [ ] **Step 3:** Run `test/data/booking`, then `test/features/booking`; the new tests fail (and the exhaustive switches stop compiling once the enum value exists).
- [ ] **Step 4: Implement.** `blocked` sits after `notAcceptingOrders` in the enum; the controller groups it with `deadlinePassed`/`notFound`/`notAcceptingOrders` (clear `bookingId`, idle, `error: err`); the sheet shows `l10n.bookingErrBlocked` like `bookNotAcceptingOrders`; `payment_pending_screen` and `qr_checkout_view` map `blocked` → `bookingErrBlocked` before their `bookTryAgain` fallback. Add the key with its description; `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; the two folders green; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Ledger** `docs/superpowers/handover/ledger-n1-order-gate.md`: what shipped per task; contract differences found in Step 1s; integration test written not run; for consumers: import names (Contract), `blocks: liveBlockGate()` in every live deps that reaches `orderBlocker`, `FakeBlockGate` in test worlds, `bookingErrBlocked` copy; #144 extends `block_ports.ts`, `safety_firestore.ts`, `live_safety.ts` and writes `blocks/{blockerId}_{blockedId}`; deploy order (Functions, then the app; an old app shows its generic error for `blocked`).
- [ ] **Step 7: Commit** `feat(booking): blocked error copy on the booking sheet and payment screen [#198]`.

## Deferred

- Writing blocks, the per-user block index, rules and indexes for `blocks`, hiding content, and block checks on inquiries, messages, contact links and event registration: #144 (S20).
- Gate calls in quotes (#139), Chụp ngay invites (#140), studio assignment (#136), collaborators (#151): in their plans.
- The settlement re-check in `handleTransferNotification` (a payment arriving after the provider stopped accepting orders or a block): #135 S21 Decision 15 for `not_accepting_orders`; a block arriving between QR and transfer is accepted (the money is held in escrow and the booking goes through support, spec §3i.3 "booking đang có vẫn giữ").
- Self-hosted parity (`services/api`, Go backend #90).
