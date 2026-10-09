# V1 Thanh toán dùng chung mọi chủ thể: subject-independent payments, settlement dispatch and one S04.04 Implementation Plan

> **Rules emulator tests and Functions integration tests (standing rule):** this plan touches `firestore.indexes.json` only (no rule change). Functions integration tests are updated but run only outside the sandbox (CI runs them). Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Issue:** #200 (Thanh toán · V1 thanh toán dùng chung mọi chủ thể), section "V1" under "Việc mới cần plan" in `2026-10-08-s04-reconciliation.md`. **Blocked by:** nothing (#129 S04 merged in #154; #134 S06 merged in #193). **Blocks:** #202 (S13–S14 · Chụp ngay: thanh toán (V1); the `instant_request` subject, dispatch plan Task 11 + customer plan Task 8, also blocked by #140) and #203 (S21 · Phí xác minh (V1); the `verification_fee` subject, also blocked by #135). **Parallel with V2 #201** (`2026-10-08-v2-refund-destination.md`, also blocked by nothing): either may land first; see "V1 and V2 in either order" below (≈ 8 files overlap). **Branch:** `plan/200-thanh-toan-chung` (from `project.py claim 200`). PR into `develop` titled `feat(payments): subject-independent payments V1 [#200]`.

**Goal:** Any payment subject (booking today, event tickets in this plan; Chụp ngay `instant_request` and the verification fee `verification_fee` later) pays on #129's model: a `created` payment with a `PB XXXXXX` transfer code, VietQR or a wallet link, a 15-minute (or hold-length) validity, the signed webhook and the 5-minute reconciliation, the mis-transfer table and automatic refunds. The domain dispatches every incoming transfer, expiry, "Kiểm tra lại" and fake confirmation to the subject's own `SubjectSettler`. The app has one S04.04 (`PaymentScreen`) for every subject. Event tickets (S11.03) move onto it; the old ticket path (`createDepositIntent`, `checkPaymentStatus`, `confirmFakeTicketPayment`, `PaymentProviderCode`, pay URL sheet) is removed. Bookings behave exactly as after #129.

**Architecture:** `packages/domain` gets the extension point the old S04 plan promised (its Decision 22) on #129's real names: `payment_ports.ts` (`PaymentInstructions`, `SubjectSettler`), `payment_settlement.ts` (`PaymentLookup`, `SettlementDeps`, pure `applyTransfer`/`expireUnpaid`, `settleTransfer`, domain `confirmFakePayment`) and new shared helpers in `create_payment.ts` (`newSubjectPayment`, `freshPaymentId`, `issuePaymentInstructions`, `instructionsOf`, `checkSubjectPayments`, `readPaymentInstructions`). Booking and tickets become two registered settlers (`BookingPaymentSettler` in `handle_transfer.ts`, `TicketPaymentSettler` in `event_payments.ts`); #129's booking entry points stay as thin booking-only wrappers so its tests pass unchanged. Idempotency stays #129's: the `payment_notifications/{provider}_{txnId}` record is written in the same transaction as the subject's writes. Functions add `liveSettlementDeps()` (`infra/live_payments.ts`) and a cross-subject `FirestorePaymentLookup`; the webhook, `paymentClock` and `confirmFakePayment` go through it; one new callable `getPaymentInstructions`. The app gets `lib/data/payments/` (`PaymentInstructions`, `PaymentsRepository`) and `lib/features/payment/` (`PaySubject`, `PaymentController`, `PaymentScreen`, `openPayment`, the QR and wallet views moved from `features/booking/`).

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 `onCall`/`onRequest`/`onSchedule`, `node --test` via tsx), Firestore indexes. Flutter, Riverpod 3, go_router, `qr_flutter`, `flutter_test` with the fakes in `test/support/`.

**Spec:**
- `docs/superpowers/plans/2026-10-08-s04-reconciliation.md` "V1" (scope) and its table (real #129 names).
- `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §3.1–§3.4 (methods, flow, mis-transfer table, fake webhook), §5 (refunds), §9 (ports, idempotency), §12–§13.
- `docs/superpowers/plans/2026-10-07-s04-booking-payment.md` Decision 22 and its Contract "extension point" block (the names consumers quote) and `docs/superpowers/plans/2026-10-07-s04-payments.md` (what #129 built).
- Mock `docs/design/ui-mock.html` `#S04.04` (layout and copy, every subject), `#S11.03` ("Thanh toán đủ giá vé như booking (Chuyển khoản QR, MoMo, ZaloPay)… giữ chỗ 10 phút"), `#S11.04-pending`.
- `docs/superpowers/specs/screens/booking.md` S04.04, `screens/events.md` S11.03/S11.04.
- Cost unit prices: `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`.

## Contract with existing code

Checked 2026-10-08 on `develop` 4e25834. Every task's Step 1 re-checks the part it touches; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- **Domain (`packages/domain/src`)**
  - `escrow.ts`: `PaymentSubject = 'booking' | 'event_registration'` (a type, no const array); `Payment` with `method?`, `transferCode?`, `expiresAt?`, `receivedAmount?`, `eventId?` (tickets), no `instructions`; `PAYMENT_METHODS`, `isPaymentMethod`, `applyRefundToPayment`, `isEscrowRefund`, `LEDGER_ENTRY_TYPES` (`payment_received`, `ticket_received`, …), `verifyPaymentLedgerInvariant`.
  - `booking.ts`: `PAYMENT_PROVIDERS = ['momo','vnpay','fake']`, `BookingCheckout {paymentId, method, amount, expiresAt, transferCode, attempt, qrPayload?, bankName?, accountMasked?, payUrl?, bankAppsUrl?}`.
  - `booking_ports.ts`: `TransferNotification`, `PaymentInstructions` (the **gateway answer**: `providerRef?`, `qrPayload?`, `bankName?`, `accountMasked?`, `payUrl?`, `bankAppsUrl?`), `TransferOutcome`, `TransferRecord`, `BookingTx` (`getTransferRecord`, `saveTransferRecord`), `BookingStore` (`findPaymentsByTransferCode`, `getTransferRecord`, `findPaymentsToReconcile`, `findOverduePayments` — the last two booking-only), `PaymentGateway {provider, createPayment({paymentId, bookingId, amount, method, transferCode, expiresAt, idempotencyKey}), queryTransfers, createDepositIntent, issueRefund, checkPaymentStatus}`, `BookingDeps`.
  - `create_payment.ts`: `createPayment(deps, {bookingId, customerId, method})` → `CreatePaymentResult {paymentId, checkout}`; private `freshPaymentId(deps)`; calls the gateway **inside** its transaction.
  - `handle_transfer.ts`: `TransferResult`, `transferRecordId`, private `matchPayment` (booking only) and private `applyTransfer(tx, deps, payment, booking, n, now)`, `handleTransferNotification(deps, n)`, `assertPaymentPayer`, `checkPayment`.
  - `booking_payment_paths.ts` (not exported from `index.ts`): `markPaid`, `paymentReceivedEntry`, `moveDraftToRequested`, `refundLatePayment`, `expireOpenPayment`.
  - `payment_sweeps.ts`: `runPaymentSweeps(deps: BookingDeps)` → `PaymentSweepResults {reconciled, expired, refunded, reconcileFailed, expireFailed}`; booking checkout payments only.
  - `transfer_rules.ts`: `TransferDecision`, `decideTransfer`. `refunds.ts`: `PAYMENT_REFUND_REASONS`, `transferRefund`, `dispatchRefund`, `dispatchRefunds` (gateway throw → `failed` + `manual`, Ruling 7). `payment_code.ts`: `transferCodeFor`, `transferCodesIn`.
  - `fake_payment_gateway.ts`: `FAKE_COLLECTION_ACCOUNT`, `FakePaymentGateway` (`createPaymentCalls`, `queryTransfersCalls`, `pushTransfer`, `markPaid`, `paidPayments`, `issuedRefunds`, `refundCalls`, `refundFailureId`, `refundThrowCount`, `queryThrowIds`, `createDepositIntent`, `checkPaymentStatus`).
  - Tickets: `event_payments.ts` (`ticketIdempotencyKey(regId, provider)`, `parseTicketProvider`, `ticketPayeeOf`, `newTicketPayment`, `issueTicketIntent` (→ `createDepositIntent`), private `dispatchTicketRefund` (throw → `failed`), `resendTicketRefund`, `TICKET_REFUND_RESEND_AFTER_MINUTES`, `handleTicketPayment`, `confirmFakeTicketPayment`, `checkTicketPayment` (→ `checkPaymentStatus`), `refundTicket`, `cancelEventWithRefunds`, `releaseEventHolds`, `stampTicketRelease`); `event_registration.ts` (`registerEvent` takes `provider`, `RegisterResult.payUrl`, `RegisterDeps = EventDeps & {gateway?}`); `event_ports.ts` (`EventTx`, `EventStore.pendingTicketRefunds`, `EventPaymentDeps = EventDeps & {gateway}`); `event_sweeps.ts` (step `refund_resend`); `event.ts` `HOLD_MINUTES = 10`.
  - Memory: `MemoryBookingStore` (`payments`, `transferRecords` maps), `MemoryEventStore` (`payments`, `refunds` maps, no transfer records). Test support: `test/support/booking_world.ts` (`createBookingWorld`, `ControllableClock`, `SequentialIdGen`), `test/support/event_world.ts` (`createEventWorld`, callers `cu1`…).
- **Functions (`app_flutter/firebase/functions/src`)**
  - `callables/payment.ts`: `handleCreatePayment`, `handleCheckPayment`, `handleConfirmFakePayment(request, deps: BookingDeps, env)` (signs a fake body and runs `handlePaymentWebhook` in-process; booking payments only; returns `{outcome}`), `FAKE_TRANSFER_KINDS`, `FAKE_OVERPAY_VND`, `FAKE_WRONG_CONTENT`.
  - `http/payment_webhook.ts`: `handlePaymentWebhook(req, deps: BookingDeps, env)`, `servePaymentWebhook`. `scheduled/payment_clock.ts`: `handlePaymentClock(deps = liveBookingDeps())`.
  - `infra/live_booking.ts` (`getSharedFakeGateway`, `liveBookingDeps`), `infra/live_event.ts` (`liveEventPaymentDeps`), `infra/fake_payments.ts` (`fakePaymentsAllowed`, `checkoutGatewayAvailable`, `assertFakePaymentsAllowed`), `infra/fake_webhook.ts`.
  - `infra/booking_firestore.ts`: `paymentToFirestore`/`paymentFromFirestore` (subject whitelist `booking | event_registration` at ~line 308 for refunds), `transferRecordToFirestore`/`FromFirestore`, `PAYMENT_NOTIFICATIONS_COLLECTION`, `FirestoreBookingStore` (`findPaymentsToReconcile`/`findOverduePayments` filter `subjectType == 'booking'`, `method in PAYMENT_METHODS`). `infra/event_firestore.ts` `FirestoreEventStore`.
  - `callables/event.ts`: `handleRegisterEvent` (`provider`, `payUrl`), `handleConfirmFakeTicketPayment`, `handleCheckTicketPayment`. `index.ts` exports `createPayment`, `checkPayment`, `confirmFakePayment`, `paymentWebhook`, `paymentClock`, `registerEvent`, `confirmFakeTicketPayment`, `checkTicketPayment`.
  - Tests: `test/unit/payment_callables.test.ts`, `payment_webhook.test.ts`, `payment_clock.test.ts`, `event_payment_callables.test.ts`, `booking_clock_ticket_release.test.ts` (uses `confirmFakeTicketPayment`), `booking_firestore.test.ts`; integration `test/integration/event_paid.test.ts`.
- **App (`app_flutter/lib`)**
  - `core/payments.dart`: `PaymentProviderCode {momo, vnpay}`, `PayMethod {bankQr, momo, zaloPay}` with `.provider` and `.code`.
  - `data/booking/booking_checkout.dart` (`BookingCheckout`, `bookingCheckoutFrom`), `booking_repository.dart` (`createPayment`, `checkPayment`, `confirmFakePayment({paymentId, kind})`, `FakeTransferKind`, `BookingErrorCode`, `bookingErrorOf`), `payments_mode.dart` (`realPaymentsProvider`).
  - `features/booking/payment_pending_screen.dart` (S04.04, route `/b/:id/pay` in `lib/app/router.dart`), `qr_checkout_view.dart` (`QrCheckoutView({booking, checkout})`, renews through `createPayment`), `wallet_waiting_view.dart` (`WalletWaitingView({booking, checkout})`, `checkPayment`), `fake_payment_sheet.dart` (`FakeTransferButton`, `FakePaymentSheet`), `payment_snack.dart`, `booking_sheet_page.dart` (`_handleOutcome`: wallet + real → `checkout.payUrl`, then `context.replace('/b/$id/pay')`).
  - Events: `data/events/event_repository.dart` (`RegisterOutcome.payUrl`, `register(…, PaymentProviderCode? provider)`, `confirmFakeTicketPayment`, `checkTicketPayment`, `FakeEventRepository.registerProviders`), `firestore_event_repository.dart`, `features/events/register_controller.dart` (`method.provider`), `register_sheet.dart` (`showRegisterSheet(context, {event})`, `_pay` → `openTicketPayment`), `ticket_payment_sheet.dart` (`openTicketPayment`, `TicketPaymentSheet`), `tickets_tab.dart` (`_continuePayment`), `event_providers.dart` (`myEventRegistrationProvider(eventId)`), `EventRegistration` (`paymentId`, `quantity`, `amount`, `holdExpiresAt`, `event.title`).
  - Core: `CountdownPill`, `SignatureLoader`, `DotRingLoader`, `AsyncView`, `EmptyState`, `ErrorState`, `AppButton`, `showAppSheet`, `ScreenCode`, `ScreenCodes.awaitingPayment = 'S04.04'`, `externalLauncherProvider`, `clockProvider`, `formatMoney`.
  - Tests: `test/features/booking/payment_pending_screen_test.dart` (≈ 30 cases), `test/support/fake_booking_repository.dart` (`fakeConfirms`), `test/features/events/register_sheet_test.dart`, `tickets_tab_test.dart`, `test/data/booking/booking_checkout_test.dart` (asserts `PayMethod.zaloPay.provider` at line 98), `test/data/events/firestore_event_repository_test.dart` (`provider: PaymentProviderCode.momo` at line 658).

## Contract (others consume these; exact signatures)

### Domain (`packages/domain/src`, all exported from `index.ts`)

```ts
// escrow.ts
export const PAYMENT_SUBJECTS = ['booking', 'event_registration'] as const; // #202 appends 'instant_request', #203 'verification_fee'
export type PaymentSubject = (typeof PAYMENT_SUBJECTS)[number];
export const isPaymentSubject = (v: unknown): v is PaymentSubject => /* string in PAYMENT_SUBJECTS */;
// Payment gains (server-only; payments are denied to clients):
//   readonly instructions?: GatewayInstructions;   // how to pay, as the gateway answered, without providerRef

// booking_ports.ts
/** The gateway's answer to createPayment. Renamed from #129's `PaymentInstructions` (Decision 4). */
export interface GatewayInstructions {
  readonly providerRef?: string; readonly qrPayload?: string; readonly bankName?: string;
  readonly accountMasked?: string; readonly payUrl?: string; readonly bankAppsUrl?: string;
}
// PaymentGateway.createPayment params: `bookingId` → `subjectType: PaymentSubject; subjectId: string`
//   (paymentId, amount, method, transferCode, expiresAt, idempotencyKey unchanged); returns GatewayInstructions.
// PaymentGateway loses createDepositIntent and checkPaymentStatus (Task 3).

// payment_ports.ts (new)
/** How to pay one payment, for any subject; what S04.04 shows. Flat like #129's BookingCheckout. */
export interface PaymentInstructions {
  readonly paymentId: string; readonly subjectType: PaymentSubject; readonly subjectId: string;
  readonly method: PaymentMethod; readonly amount: number;
  readonly expiresAt: string;      // ISO-8601 UTC
  readonly transferCode: string;   // 'PB XXXXXX'
  readonly qrPayload?: string; readonly bankName?: string; readonly accountMasked?: string;
  readonly payUrl?: string; readonly bankAppsUrl?: string;
}
/** One payment subject's money rules, over the subject's own store (Decision 1). */
export interface SubjectSettler {
  /**
   * Applies one matched transfer in ONE transaction of the subject's store: if the record
   * `transferRecordId(transfer)` exists → 'duplicate'; else read the payment and the subject, `applyTransfer`,
   * write the subject's changes, any refund (`transferRefund` / `applyRefundToPayment`) and the transfer record
   * (`transferRecordOf(transfer, outcome, paymentId)`). After commit it sends each new refund with `this.dispatchRefund`.
   */
  settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>>;
  /** A `created` payment past expiresAt: `expireUnpaid` in the subject's transaction, then dispatch its refund. */
  expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'>;
  /**
   * Sends one refund and stores the outcome in the subject's store. V1: #129's refund dispatch (booking `dispatchRefunds`,
   * tickets `dispatchTicketRefund`; Decision 8). After #201: `sendRefundOnce` + a transaction applying `mergeRefundOutcome`.
   * Re-sends of pending refunds do NOT go through this registry: they use V2's `RefundSubjects` (`liveRefundSubjects()`).
   */
  dispatchRefund(refund: Refund, payment: Payment): Promise<Refund>;
  /** The subject's own status code after a payment ('requested', 'paid', 'gone', …). */
  statusOf(payment: Payment): Promise<string>;
}

// payment_settlement.ts (new)
export interface PaymentLookup {
  getPayment(id: string): Promise<Payment | null>;
  /** Every payment with this transferCode, any subject and status. */
  findPaymentsByTransferCode(code: string): Promise<readonly Payment[]>;
  getTransferRecord(id: string): Promise<TransferRecord | null>;
  /** Stores a `needs_review` record (no payment matched); a second call with the same id is a no-op. */
  saveUnmatchedTransfer(record: TransferRecord): Promise<void>;
  /** `created` payments with a method (checkout payments) of any subject, createdAt <= createdBefore. */
  findPaymentsToReconcile(createdBefore: Date, limit?: number): Promise<readonly Payment[]>;
  /** The same set with expiresAt <= now. */
  findOverduePayments(now: Date, limit?: number): Promise<readonly Payment[]>;
}
export interface SettlementDeps {
  readonly payments: PaymentLookup;
  readonly gateway: PaymentGateway;
  readonly clock: Clock;
  /** Required. booking and event_registration are registered like any other subject (Decision 1). */
  readonly subjects: Readonly<Partial<Record<PaymentSubject, SubjectSettler>>>;
}
export interface TransferResult { readonly outcome: TransferOutcome; readonly paymentId?: string } // moved from handle_transfer.ts
export const transferRecordId: (n: Pick<TransferNotification, 'provider' | 'txnId'>) => string; // moved, unchanged
export function transferRecordOf(n: TransferNotification, outcome: Exclude<TransferOutcome, 'duplicate'>, paymentId?: string): TransferRecord;
/** Pure: what one transfer does to a payment (#129's decideTransfer) and its received-ledger entry. */
export function applyTransfer(p: { payment: Payment; transfer: TransferNotification; ledgerEntryId: string; now: Date }):
  { payment: Payment; ledgerEntry: LedgerEntry; decision: TransferDecision; excess: number };
/** Pure: an open payment nobody finished paying → expired, escrow refunded, refund of receivedAmount (underpaid_expired) if > 0. */
export function expireUnpaid(p: { payment: Payment; refundId: string; ledgerEntryId: string; now: Date }):
  { payment: Payment; refund: Refund | null; ledgerEntry: LedgerEntry | null };
export async function settleTransfer(deps: SettlementDeps, n: TransferNotification): Promise<TransferResult>;
/** Dev/emulator tool and CLIs: simulates a transfer of `kind` to the caller's own payment (Decision 9). */
export async function confirmFakePayment(deps: SettlementDeps, caller: { readonly uid: string }, raw: unknown /* {paymentId, kind?} */):
  Promise<{ outcome: TransferOutcome; subjectType: PaymentSubject; paymentStatus: PaymentStatus; subjectStatus: string }>;

// create_payment.ts (additions; createPayment itself unchanged in behaviour)
export function newSubjectPayment(p: {
  id: string; subjectType: PaymentSubject; subjectId: string; payerId: string; payeeId: string;
  amount: number; method: PaymentMethod; provider: PaymentProvider; idempotencyKey: string; now: Date; expiresAt: Date;
}): Payment; // status created, escrowStatus held, transferCode = transferCodeFor(id), receivedAmount 0, expiresAt ISO
/** A payment id whose transfer code no payment of any subject or status uses (#129 Decision 5, now cross-subject). */
export async function freshPaymentId(payments: Pick<PaymentLookup, 'findPaymentsByTransferCode'>, ids: IdGenerator): Promise<string>;
/** Outside any transaction: gateway.createPayment, then save(providerRef, instructions) (the caller's short tx, only while still created). */
export async function issuePaymentInstructions(gateway: PaymentGateway, payment: Payment,
  save: (providerRef: string | undefined, instructions: GatewayInstructions) => Promise<void>): Promise<PaymentInstructions>;
/** From the stored payment (reuse on a second tap); null without method, transferCode, expiresAt or instructions. */
export function instructionsOf(payment: Payment): PaymentInstructions | null;
/** "Kiểm tra lại" for any subject: queryTransfers for each created payment, settleTransfer each; true when one is now paid. */
export async function checkSubjectPayments(deps: SettlementDeps, payments: readonly Payment[]): Promise<boolean>;
/** getPaymentInstructions: payer only; instructions of a `created` payment, else null. */
export async function readPaymentInstructions(deps: Pick<SettlementDeps, 'payments'>, caller: { readonly uid: string },
  raw: unknown /* {paymentId} */): Promise<PaymentInstructions | null>;

// refunds.ts: no change in V1 (V2 #201 owns it: sendRefundOnce, mergeRefundOutcome, transferRefund({destination}))

// handle_transfer.ts
export class BookingPaymentSettler implements SubjectSettler { constructor(deps: BookingDeps) }
export function bookingPaymentLookup(store: BookingStore): PaymentLookup;   // booking-only adapter (#129 queries)
export function bookingSettlement(deps: BookingDeps): SettlementDeps;        // { payments: bookingPaymentLookup, subjects: { booking } }
export function asSettlement(deps: SettlementDeps | BookingDeps): SettlementDeps; // 'subjects' in deps ? deps : bookingSettlement(deps)
// unchanged signatures, now wrappers: handleTransferNotification(deps: BookingDeps, n) = settleTransfer(bookingSettlement(deps), n);
//   checkPayment(deps: BookingDeps, input); assertPaymentPayer(deps: BookingDeps, paymentId, customerId)
// payment_sweeps.ts
export async function runPaymentSweeps(deps: SettlementDeps | BookingDeps): Promise<PaymentSweepResults>; // results type unchanged
//   merged with V2: runPaymentSweeps(deps: SettlementDeps | BookingDeps, extras?: PaymentSweepExtras) (V2's `resend` step stays last)

// memory_payment_lookup.ts (new; tests and consumers' worlds)
export interface PaymentSource { readonly payments: ReadonlyMap<string, Payment>; readonly transferRecords: Map<string, TransferRecord> }
export class MemoryPaymentLookup implements PaymentLookup { constructor(sources: readonly PaymentSource[]) } // unmatched → sources[0]

// fake_payment_gateway.ts (moved from Functions callables/payment.ts, which re-exports them)
export const FAKE_TRANSFER_KINDS = ['exact', 'under', 'over', 'wrong_content'] as const;
export type FakeTransferKind = (typeof FAKE_TRANSFER_KINDS)[number];
export const FAKE_OVERPAY_VND = 50_000;
export const FAKE_WRONG_CONTENT = 'CHUYEN TIEN';
/** provider 'fake', txnId `fake_${id}_${kind}_${now ms}`, amount amount | floor(amount/2) | amount + 50 000, content code | 'CHUYEN TIEN'. */
export function fakeTransferFor(payment: Payment & { readonly transferCode: string }, kind: FakeTransferKind, now: Date): TransferNotification;
// FakePaymentGateway loses createDepositIntent, checkPaymentStatus, markPaid, paidPayments (Task 3).

// Tickets
// event_ports.ts: EventPaymentDeps = EventDeps & { gateway: PaymentGateway; payments: PaymentLookup }
//   EventTx gains getTransferRecord(id: string): Promise<TransferRecord | null>; putTransferRecord(r: TransferRecord): void
// event_payments.ts
export class TicketPaymentSettler implements SubjectSettler { constructor(deps: EventPaymentDeps) }
export const ticketIdempotencyKey: (registrationId: string, method: PaymentMethod) => string; // `tkt_${regId}_${method}`
export function newTicketPayment(p: { id: string; event: Pick<EventRecord, 'id' | 'host'>; registrationId: string; payerId: string;
  method: PaymentMethod; provider: PaymentProvider; amount: number; now: Date; expiresAt: Date }): Payment; // newSubjectPayment + eventId
export function checkTicketPayment(deps: EventPaymentDeps & { settlement: SettlementDeps }, caller: EventCaller, raw: unknown):
  Promise<{ paid: boolean; status: RegistrationStatus }>; // contract of the callable unchanged
// event_registration.ts: raw `method?: PaymentMethod` replaces `provider`; RegisterResult.instructions: PaymentInstructions | null
//   replaces payUrl; RegisterDeps = EventDeps & { gateway?: PaymentGateway; payments?: PaymentLookup }
// removed: handleTicketPayment, confirmFakeTicketPayment, issueTicketIntent, parseTicketProvider
// kept as #129/10c left them (V2 rewrites or removes them): dispatchTicketRefund (now also the ticket settler's dispatchRefund),
//   resendTicketRefund, runEventSweeps step refund_resend
```

### Callables and HTTP (Functions, `asia-southeast1`)

| Name | Input | Output | Change |
|---|---|---|---|
| `confirmFakePayment` (`PAYMENT_CALLABLE_OPTIONS`) | `{paymentId, kind?}` | `{outcome}` | any subject whose payment has a transfer code (was booking only); still the signed in-process webhook; `not_eligible` when the subject has no settler |
| `getPaymentInstructions` (new, `PAYMENT_CALLABLE_OPTIONS`) | `{paymentId}` | `{instructions: PaymentInstructions \| null}` | payer only; `not_found`, `permission_denied`, `invalid_argument` |
| `registerEvent` | `{eventId, quantity, name, method?: 'bank_qr'\|'momo'\|'zalopay'}` | `{registrationId, status, paymentId, instructions, holdExpiresAt}` | `method` replaces `provider`, `instructions` replaces `payUrl` |
| `checkTicketPayment` | `{eventId, registrationId}` | `{paid, status}` | unchanged contract; asks `queryTransfers` through `checkSubjectPayments` |
| `paymentWebhook` | as #129 | as #129 | settles every subject through `liveSettlementDeps()` |
| `paymentClock` | — | — | sweeps every subject through `liveSettlementDeps()` |
| removed | `confirmFakeTicketPayment` | — | the app uses `confirmFakePayment` |

```ts
// infra/live_payments.ts (new)
export function liveSettlementDeps(): SettlementDeps;
//   { payments: new FirestorePaymentLookup(db()), gateway: getSharedFakeGateway(), clock,
//     subjects: { booking: new BookingPaymentSettler(liveBookingDeps()),
//                 event_registration: new TicketPaymentSettler(liveEventPaymentDeps()) } }  // #202, #203 add their line here
// infra/payment_firestore.ts (new)
export class FirestorePaymentLookup implements PaymentLookup { constructor(firestore: Firestore) }
// http/payment_webhook.ts: handlePaymentWebhook(req, deps: SettlementDeps | BookingDeps, env?); servePaymentWebhook(req, res, deps: SettlementDeps | BookingDeps, env?)
//   merged with V2: handlePaymentWebhook(req, deps: SettlementDeps | BookingDeps, env?, refundSubjects?: RefundSubjects)
//   (transfer bodies → settleTransfer(asSettlement(deps), n); V2's refund bodies → applyRefundEvent as V2 wrote it)
// scheduled/payment_clock.ts: handlePaymentClock(deps: SettlementDeps | BookingDeps = liveSettlementDeps())
//   merged with V2: handlePaymentClock(deps: SettlementDeps | BookingDeps = liveSettlementDeps(), extras?: PaymentClockExtras)
// callables/payment.ts: handleConfirmFakePayment(request, deps: SettlementDeps | BookingDeps, env?); handleGetPaymentInstructions(request, deps: SettlementDeps)
```

### App (`app_flutter/lib`)

```dart
// core/payments.dart — PaymentProviderCode and PayMethod.provider removed
enum PayMethod { bankQr('bank_qr'), momo('momo'), zaloPay('zalopay'); final String code; static PayMethod? fromCode(String? c); }

// data/payments/payment_instructions.dart (new)
class PaymentInstructions {
  const PaymentInstructions({required this.paymentId, required this.method, required this.amount, required this.expiresAt,
    required this.transferCode, this.attempt, this.qrPayload, this.bankName, this.accountMasked, this.payUrl, this.bankAppsUrl});
  final String paymentId; final PayMethod method; final int amount; final DateTime expiresAt /* UTC */;
  final String transferCode; final int? attempt; final String? qrPayload, bankName, accountMasked, payUrl, bankAppsUrl;
  bool isExpiredAt(DateTime now); Duration remainingAt(DateTime now); // never negative; == and hashCode over every field
}
PaymentInstructions? paymentInstructionsFrom(Object? raw); // Timestamp | DateTime | ISO expiresAt; null when malformed
// data/booking/booking_checkout.dart: BookingCheckout gains `PaymentInstructions toInstructions()` (class otherwise unchanged)

// data/payments/payments_repository.dart (new)
enum FakeTransferKind { exact, under, over, wrongContent } // moved from booking_repository.dart, which re-exports it
class PaymentCheck { const PaymentCheck({required this.paid, this.instructions}); final bool paid; final PaymentInstructions? instructions; }
abstract class PaymentsRepository {
  /// confirmFakePayment {paymentId, kind}: returns the outcome code ('paid', 'partial', 'paid_with_refund', 'needs_review', …).
  Future<String> confirmFake(String paymentId, {FakeTransferKind kind = FakeTransferKind.exact});
  /// getPaymentInstructions {paymentId}; null when the payment is no longer open.
  Future<PaymentInstructions?> instructions(String paymentId);
}
class FunctionsPaymentsRepository implements PaymentsRepository { … } // throws BookingException(code)
final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) => FunctionsPaymentsRepository());

// data/events/event_repository.dart: register(eventId, {required quantity, required name, PayMethod? method});
//   RegisterOutcome.instructions (PaymentInstructions?) replaces payUrl; confirmFakeTicketPayment removed.

// features/payment/pay_subject.dart (new) — #202 adds InstantPay(requestId), #203 adds VerificationFeePay()
sealed class PaySubject { const PaySubject(); }
final class BookingPay extends PaySubject { const BookingPay(this.bookingId); final String bookingId; } // == / hashCode by fields
final class TicketPay extends PaySubject { const TicketPay(this.eventId, this.registrationId); final String eventId; final String registrationId; }
String payPathOf(PaySubject s); // '/b/{id}/pay' | '/e/{eventId}/pay/{regId}'

// features/payment/payment_controller.dart (new)
typedef PayWho = ({String name, String detail}); // "{name} · {detail}" line (payQrWho)
enum PayGoneKind { booking, ticket }
sealed class PayView { const PayView(); }
final class PayLoading extends PayView { const PayLoading(); }
final class PayOpen extends PayView { const PayOpen({required this.instructions, required this.who, required this.canRenew}); … }
final class PayDone extends PayView { const PayDone(this.path); final String path; }
final class PayGone extends PayView { const PayGone(this.kind, this.actionPath); final PayGoneKind kind; final String actionPath; }
final class PayFailed extends PayView { const PayFailed(this.code); final BookingErrorCode code; } // a missing QR could not be created/read
class PaymentController extends Notifier<PayView> {
  PaymentController(this.subject);
  final PaySubject subject;
  void seed(PaymentInstructions? initial); // route extra; shown until the subject's stream says otherwise
  Future<void> renew();                    // "Tạo QR mới"; throws (bookingErrorOf maps it); only when PayOpen.canRenew
  Future<bool> check();                    // "Kiểm tra lại"
  void retry();                            // PayFailed → PayLoading, loads again
}
final paymentControllerProvider =
    NotifierProvider.autoDispose.family<PaymentController, PayView, PaySubject>(PaymentController.new);

// features/payment/payment_screen.dart (new) — S04.04 for every subject
class PaymentScreen extends ConsumerStatefulWidget { const PaymentScreen({super.key, required this.subject, this.initial});
  final PaySubject subject; final PaymentInstructions? initial; }
// features/payment/open_payment.dart (new)
/// After createPayment / registerEvent / inviteInstant / startFee: wallet + real payments → launch payUrl;
/// then push (or replace) payPathOf(subject) with `extra: instructions`.
Future<void> openPayment(BuildContext context, WidgetRef ref,
    {required PaySubject subject, required PaymentInstructions instructions, bool replace = false});
// features/payment/qr_checkout_view.dart, wallet_waiting_view.dart (moved from features/booking, generalised)
class QrCheckoutView extends ConsumerWidget { const QrCheckoutView({super.key, required this.instructions, required this.who,
  required this.canRenew, required this.renewing, required this.onRenew, required this.onBack}); }
class WalletWaitingView extends ConsumerWidget { const WalletWaitingView({super.key, required this.instructions, required this.who,
  required this.checking, required this.onCheck}); }
// features/payment/fake_transfer_sheet.dart (renamed from features/booking/fake_payment_sheet.dart)
class FakeTransferButton extends ConsumerWidget { const FakeTransferButton({super.key, required this.paymentId}); }
class FakeTransferSheet extends ConsumerStatefulWidget { const FakeTransferSheet({super.key, required this.paymentId}); } // four kinds
```

Routes: `/b/:id/pay` → `PaymentScreen(subject: BookingPay(id), initial: state.extra as PaymentInstructions?)`; new `/e/:eventId/pay/:regId` → `PaymentScreen(subject: TicketPay(eventId, regId), initial: …)`. Screen code `ScreenCodes.awaitingPayment` (`label: 'ticket'` for tickets).

l10n (`lib/l10n/app_vi.arb`), new: `payTicketExpiredBody` "Chưa nhận được thanh toán nên chỗ giữ đã nhả. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.", `payBackToEvent` "Về sự kiện". Reused: `payQrWho`, `ticketCount`, `registerHoldExpired`, `registerDone`, `registerOpenChat`, every `payQr*`/`payWallet*`/`fakeTransfer*` key of #129. Removed when unused after Task 7 (check with grep): `fakeTicketPayTitle`, `fakePayBody`, `fakePayConfirm`, `ticketPayFakeDisabled`, `ticketPayFailed`, `registerHold`.

### Names consumers quote that differ (owners of #202, #203, V2: read this)

| Quoted (old S04 plan) | V1 | Why |
|---|---|---|
| `SubjectSettler.settle(paymentId, t, payer): Promise<TransferDecision>` | `settle(paymentId, transfer: TransferNotification): Promise<Exclude<TransferOutcome,'needs_review'>>` | #129's types; `payer` is V2's (it adds an optional third parameter) |
| `SubjectSettler.statusOf(subjectId)` | `statusOf(payment: Payment)` | a ticket needs `payment.eventId` to find its registration |
| `applyTransfer({payment, transfer, payer, ledgerEntryId, now})` | no `payer` (V2 adds `payer?`); `decision` is #129's `TransferDecision` union; `excess` also top level | no `appliedTransferIds`: idempotency is the transfer record (Decision 3) |
| `PaymentInstructions` with `code`, `qr: VietQrInstructions \| null`, `payUrl: string \| null` | flat: `transferCode`, `qrPayload?`, `bankName?`, `accountMasked?`, `payUrl?`, `bankAppsUrl?`, plus `subjectType`, `subjectId` | same shape as #129's `bookings/{id}.checkout`; "bank_qr has qr.payload" tests read `qrPayload` |
| #129's gateway answer `PaymentInstructions` (`booking_ports.ts`) | `GatewayInstructions` | the generic name goes to the app-facing type |
| `issuePaymentInstructions(gateway, payment, save, returnUrl?)`, `save(providerRef, {qr, payUrl})` | no `returnUrl`; `save(providerRef, instructions: GatewayInstructions)` | no gateway takes a return URL; the app returns via S04.04's stream |
| `SettlementDeps {bookings, events, payments, cipher, clock, subjects?}` | `{payments, gateway, clock, subjects}` (`subjects` required) | booking and tickets are settlers too; `cipher` is V2's |
| `SettlementOutcome` / `'unmatched'` | `TransferResult {outcome, paymentId?}`, outcome `needs_review` | #129's names |
| `reconcilePayments` | `runPaymentSweeps(deps: SettlementDeps \| BookingDeps)` | #129's name |
| `sendRefundOnce` / `mergeRefundOutcome` in a settler's `dispatchRefund` | V1's two settlers keep #129's dispatch (`dispatchRefunds`, `dispatchTicketRefund`); after #201 every settler uses `sendRefundOnce` + `mergeRefundOutcome` | those two are V2's (#201); new subjects (#202, #203) land after both and use V2's |
| refund re-send for every subject through `SettlementDeps.subjects` / `reconcilePayments` | V2's `RefundSubjects` registry (`RefundSubjectHandler {resend, record}`, `liveRefundSubjects()`); a new subject registers there **and** in `liveSettlementDeps()` | V2 Decision 8: V2 ships without V1 |
| `PaymentsRepository.confirmFake(paymentId)` returns the subject status | returns the outcome code; optional `kind` | the callable answers `{outcome}` (#129 tests pin it) |
| `FakeWalletSheet` | not built: S04.04's `FakeTransferButton` → `FakeTransferSheet` serves QR and wallets | #129 Decision 17 (test "the wallet waiting view has the simulator too") |
| `VietQrCard`, `FakeTransferSheet({instructions})` | `QrCheckoutView`, `FakeTransferSheet({paymentId})` | #129's widgets, moved |
| `newSubjectPayment({id: deps.ids.newId(), …})` | same signature; draw `id` with `freshPaymentId(payments, ids)` | cross-subject code uniqueness (Decision 5) |

## Global Constraints

- Payments spec §3.3 mis-transfer table and #129 Decisions 5–8 apply to every subject unchanged: exact → paid; over → paid + excess refunded (`overpaid_excess`); under → stays `created`, top-ups add up, at expiry everything received is refunded (`underpaid_expired`); at or after `expiresAt` → refunded (`late_transfer`); to a paid/refunded payment → refunded (`extra_transfer`); no match → `needs_review`. Refunds are automatic.
- Payments spec §9: "mọi lệnh gọi ra ngoài có `idempotencyKey`"; the webhook is idempotent by the provider's transaction id (`payment_notifications/{provider}_{txnId}`), stores the raw body, and verifies the signature (Functions, `x-pb-signature`).
- Event tickets: hold 10 minutes (`HOLD_MINUTES`), "Huỷ trước 48 giờ hoàn 100%", one active registration per user, never oversell; a free event never touches payments ("Không thu phí", never "0₫").
- Mock S04.04 copy and layout as #129 built them (`screens/booking.md` S04.04); tickets reuse them with the "{tên sự kiện} · {n} vé" line.
- CLAUDE.md: business rules only in `packages/domain` (no Firebase or Node imports; `purity.test.ts`); Functions thin, region `asia-southeast1`; `cloud_firestore`/`cloud_functions` only in `lib/data/**`, `firebase_options.dart`, `main.dart`; imports `package:photobooking/...`, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; one primary action per screen; strings in `app_vi.arb` + `flutter gen-l10n`; the app never trusts a redirect, only the subject's status.
- Data model: ULID ids (`deps.ids.newId()`), UTC ISO instants in the domain, `Timestamp` only in adapters, integer VND, string enum codes.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder per command; bounded pumps, no `pumpAndSettle` on screens with `DotRingLoader`/`SignatureLoader`.
- Domain: `(cd packages/domain && npm test && npm run typecheck && npm run lint)`. Functions: `(cd app_flutter/firebase/functions && npm test && npm run lint && npm run typecheck && npm run build)`.
- Commits: Conventional Commits, subject ends with `[#200]`, body ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (owner's rule; never the Claude line).

## Key decisions

| # | Decision | Why / if wrong |
|---|---|---|
| 1 | **Every subject is a registered settler.** `SettlementDeps.subjects` is required; `settleTransfer`, `runPaymentSweeps`, `checkSubjectPayments` and `confirmFakePayment` dispatch only through it (no built-in booking branch). A payment whose subject has no settler: transfer → `needs_review` record, sweep → skipped, fake confirm → `not_eligible`. | One code path; #202/#203 add one line to `liveSettlementDeps()`. |
| 2 | **#129's entry points stay, as booking-only wrappers**, so its domain and Functions tests pass with no edit: `handleTransferNotification(deps: BookingDeps, n)`, `checkPayment`, `assertPaymentPayer`; `runPaymentSweeps`, `handlePaymentWebhook`, `servePaymentWebhook`, `handlePaymentClock`, `handleConfirmFakePayment` take `SettlementDeps \| BookingDeps` (`asSettlement`). The only allowed edit to a #129 test is one forced by the port rename `bookingId` → `subjectId` (none assert it on 2026-10-08). Any other #129 assertion change: stop and ledger. | "Booking unchanged" is checked by #129's own suite. |
| 3 | **Idempotency stays #129's transfer record**, written inside each settler's transaction (`EventTx` gains `getTransferRecord`/`putTransferRecord`; in Firestore every store writes the same `payment_notifications` collection). No `appliedTransferIds`. Unmatched transfers are saved by `PaymentLookup.saveUnmatchedTransfer`. | A webhook retry or a reconciliation repeat is a no-op whatever the subject. |
| 4 | **`PaymentInstructions` is the flat #129 checkout shape plus `subjectType`/`subjectId`**; the gateway answer is renamed `GatewayInstructions` and stored on `Payment.instructions` (server-only). The app gets instructions from the call that opened the payment, the booking mirror (`bookings/{id}.checkout`, kept), or `getPaymentInstructions`. | Reuses #129's screen and parsing; no second mirror per subject. |
| 5 | **Transfer codes are unique across subjects**: `freshPaymentId` checks `findPaymentsByTransferCode` over every payment; booking `createPayment` and tickets use it; new subjects should. | An old QR can never pay another subject's payment. |
| 6 | **Ticket payments**: `expiresAt = holdExpiresAt` (10 min), `provider = gateway.provider`, idempotency `tkt_{regId}_{method}`; same method twice reuses the payment and its instructions; another method opens a second payment for the same hold (as with providers today); no "Tạo QR mới" (a new QR would need a new hold). Ledger type stays `ticket_received`. | Keeps 10c's hold rules; the countdown on S04.04 is the hold. |
| 7 | **Ticket transfers follow the §3.3 table** through `applyTransfer`. `paid` keeps 10c's live check (held, not expired, event not cancelled) → ticket `paid`, seats move, contact snapshot; otherwise 100% `applyRefundToPayment` `late_payment_hold_expired`. The registration refund mark rule is unchanged (held, or cancelled and this is its payment). | Same customer-visible results as 10c (Task 3 ports its tests). |
| 8 | **V1 does not touch refund sending.** `SubjectSettler.dispatchRefund` defaults to #129's dispatch: booking `dispatchRefunds` (Ruling 7), tickets today's `dispatchTicketRefund`; `refunds.ts` is not edited. After #201 (whichever lands second does it): settlers use `sendRefundOnce` + `mergeRefundOutcome`, settlers capture the payer with `payerAccountOf` before their transaction and pass `destination` to `transferRefund`, and re-sends of `pending` refunds go through V2's `RefundSubjects` (`liveRefundSubjects()`), never through `SettlementDeps.subjects`. | V1 and V2 land in either order; refund rules have one owner (#201). |
| 9 | **Fake confirmation:** the callable keeps #129's signed in-process webhook (its tests stay), now for any subject with a transfer code, body built by `fakeTransferFor`. The domain `confirmFakePayment` (CLIs such as #202's `npm run instant`, domain tests) builds the same transfer and calls `settleTransfer` directly. `confirmFakeTicketPayment` is removed (domain, callable, app). Guard unchanged (`assertFakePaymentsAllowed` before any read). | One simulator for every subject. |
| 10 | **One S04.04**: `PaymentScreen(subject)` + `PaymentController`, which `switch`es on the sealed `PaySubject` to a private binding per subject (watch → `PayView`, `renew`, `check`). Adding a subject = a variant, its route and its `case` (#202, #203). Booking keeps its route, mirror, copy, behaviour and test names. | The extension point the old plan promised. |
| 11 | **No `FakeWalletSheet`**: every S04.04 (QR and wallet views) has #129's four-kind simulator. | #129 Decision 17. |
| 12 | **S11.03 after "Thanh toán"**: `registerEvent(method)` → the sheet closes → `openPayment(subject: TicketPay(…))`; S04.04 shows the hold countdown. Paid → `/bookings?tab=events&highlight={regId}` with the `registerDone` SnackBar and its "Vào nhóm chat" action (today's `showRegisterSheet` behaviour). Hold gone (cancelled/refunded/other registration) → `EmptyState` `registerHoldExpired` / `payTicketExpiredBody` / `payBackToEvent` (`/e/{eventId}`). QR at 00:00 → the single primary is "Về sự kiện". | Mock S11.03: pay "như booking"; no countdown in the sheet. |
| 13 | **"Thanh toán tiếp" (S11.04-pending)** calls `checkTicketPayment`, then pushes `payPathOf(TicketPay)` without `extra`; S04.04 reads instructions with `getPaymentInstructions`. It no longer calls `registerEvent` again. | No side-effecting call to read instructions. |
| 14 | **`PaymentProviderCode` and `PayMethod.provider` removed.** | Nothing sends a provider any more. |
| 15 | **Reconcile/expire queries cover every subject** (`FirestorePaymentLookup`: `status == created`, `method in PAYMENT_METHODS`, then `createdAt` / `expiresAt`; two new composite indexes). Ticket payments created before V1 have no `method`: never reconciled (dev data only; ledger). | Only checkout payments have a method. |
| 16 | **`getPaymentInstructions`** answers only the payer, only for a `created` payment (else `null`). | Payments stay denied to clients. |

## Review Focus

1. A transfer to a **ticket** payment arrives by webhook, then again by reconciliation: settled once by `TicketPaymentSettler` (one `ticket_received`, one record), never `needs_review`. Pinned: Task 3 `a webhook-style transfer reaches TicketPaymentSettler, then a repeat is duplicate`; Task 4 webhook test.
2. A payment whose subject has **no settler** yet (an `instant_request` payment before #202 registers it): webhook → 200 `needs_review`, sweep skips it and finishes the batch, fake confirm → `not_eligible`; nothing crashes. Pinned in Task 2.
3. The ticket **hold runs out on S04.04** before any sweep: the screen shows the expired state with only "Về sự kiện"; a transfer after it is refunded (`late_transfer`) and the ticket shows "Đang hoàn". Pinned: Task 3 `a transfer after the hold expired…`, Task 7 `at 00:00 the only button is a primary "Về sự kiện"`.
4. **Booking regression**: every #129 domain and Functions test passes unedited; the ported S04.04 booking tests keep their names and expectations. Pinned by Task 1–4 Step 5 and Task 6 Step 2.
5. **Code collision across subjects**: a ticket payment never gets a code an old booking payment used. Pinned: Task 1 `freshPaymentId skips an id whose code any payment of any subject uses`, Task 3 `a ticket payment's code is fresh across subjects`.

## File structure

- Domain create: `src/payment_ports.ts`, `src/payment_settlement.ts`, `src/memory_payment_lookup.ts`, `test/payment_settlement.test.ts`, `test/settlement_dispatch.test.ts`, `test/ticket_settlement.test.ts`.
- Domain modify: `escrow.ts`, `booking_ports.ts`, `create_payment.ts`, `handle_transfer.ts`, `booking_payment_paths.ts`, `payment_sweeps.ts`, `fake_payment_gateway.ts`, `event_payments.ts`, `event_registration.ts`, `event_ports.ts`, `memory_event_store.ts`, `index.ts`; tests `create_payment.test.ts` (additions only), `event_payments.test.ts`, `event_registration.test.ts`; support `booking_world.ts` (+`settlement`), `event_world.ts` (+ payment world).
- Functions create: `src/infra/live_payments.ts`, `src/infra/payment_firestore.ts`, `test/unit/live_payments.test.ts`. Modify: `src/callables/payment.ts`, `src/callables/event.ts`, `src/http/payment_webhook.ts`, `src/scheduled/payment_clock.ts`, `src/infra/booking_firestore.ts`, `src/infra/event_firestore.ts`, `src/infra/live_event.ts`, `src/infra/fake_payments.ts` (doc comment), `src/index.ts`, `app_flutter/firebase/firestore.indexes.json`; tests `payment_callables.test.ts`, `payment_webhook.test.ts`, `payment_clock.test.ts` (additions only), `event_payment_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `booking_firestore.test.ts`, `test/integration/event_paid.test.ts`.
- App create: `lib/data/payments/payment_instructions.dart`, `lib/data/payments/payments_repository.dart`, `lib/features/payment/{pay_subject,payment_controller,payment_screen,open_payment,fake_transfer_sheet}.dart`, `test/support/fake_payments_repository.dart`, `test/data/payments/*_test.dart`, `test/features/payment/*_test.dart`.
- App move: `lib/features/booking/{qr_checkout_view,wallet_waiting_view,payment_snack}.dart` → `lib/features/payment/`. Delete: `lib/features/booking/payment_pending_screen.dart`, `fake_payment_sheet.dart`, `lib/features/events/ticket_payment_sheet.dart`, `test/features/booking/payment_pending_screen_test.dart` (ported).
- App modify: `lib/core/payments.dart`, `lib/data/booking/booking_checkout.dart`, `booking_repository.dart`, `lib/data/events/event_repository.dart`, `firestore_event_repository.dart`, `lib/features/booking/booking_sheet_page.dart`, `lib/features/events/{register_controller,register_sheet,tickets_tab,event_screen}.dart`, `lib/app/router.dart`, `lib/l10n/app_vi.arb`; tests listed per task.
- Docs (Task 8): specs, reconciliation table, ledger `docs/superpowers/handover/ledger-v1-subject-payments.md`.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore upper bound nam5 $0.06/100K reads, $0.18/100K writes (Singapore **chưa xác nhận**); Functions Tier 2, 2M calls and 180K vCPU-s free per month. Assumptions: paid tickets 100/month at 1,000 MAU and 1,000 at 10,000 MAU; bookings as #129 (300 / 3,000 a month); S04.04 opened without route `extra` (resume, "Thanh toán tiếp") once per 3 payments.

- **Per user action.** Ticket "Thanh toán": as today (register transaction) + 1 read (`freshPaymentId`) + 1 read/1 write (save instructions, as `issueTicketIntent` did). A settled ticket transfer: ≈ 6 reads, 7 writes (was ≈ 5/6 via the fake confirm; +1 read +1 write for the transfer record). S04.04 without `extra`: 1 callable, 1 read. Bookings: +1 write field (`instructions`) inside the existing payment write: 0 extra operations.
- **Scheduled jobs:** `paymentClock` keeps its 2 queries every 5 min (8,640 runs/month → ≈ 17K reads, unchanged: the queries swap filters, not count); each open ticket payment adds ≈ 1 read per run while open (≤ 3 runs of a 10-minute hold) → ≈ 300 reads/month at (b), 3,000 at (c).
- **New callable:** `getPaymentInstructions` ≈ 130/month at (b), 1,300 at (c), inside the free 2M calls and 180K vCPU-s. Removed: `confirmFakeTicketPayment` (dev only). No new trigger, Storage or paid API.
- **Monthly totals.** (b) 1,000 MAU: ≈ 1,500 extra reads, ≈ 300 extra writes → **< $0.01/month**. (c) 10,000 MAU: ≈ 15K reads, ≈ 3K writes → **≈ $0.015/month**. Below $5 at (c); no mitigation needed.

## V1 and V2 (#201) in either order

Neither blocks the other. V2 owns the refund model and refund sending (`sendRefundOnce`, `mergeRefundOutcome`, `payerAccountOf`, `transferRefund({destination})` returning `{refund, ledgerEntry, payment}`, `RefundSubjects`/`liveRefundSubjects()`, the `resend` step of `runPaymentSweeps`); V1 owns payment creation, matching and dispatch by subject. They overlap in these files (whichever PR lands second rebases and ledgers it):

| File | V1 | V2 | Merge rule |
|---|---|---|---|
| `handle_transfer.ts` | body moves into `BookingPaymentSettler.settle`; wrapper | payer capture, `destination` on refunds | V2's capture goes into `BookingPaymentSettler.settle` (before its transaction) |
| `booking_payment_paths.ts` | `expireOpenPayment` uses `expireUnpaid` | refunds carry `destination`, `refundedAmount` | `expireUnpaid` gains `destination?` and returns the payment with `refundedAmount` |
| `payment_sweeps.ts` | `SettlementDeps \| BookingDeps`, dispatch by subject | `extras?: PaymentSweepExtras`, step `resend` last | `runPaymentSweeps(deps: SettlementDeps \| BookingDeps, extras?)`; `resend` uses `asSettlement(deps)`'s booking deps as V2 wrote it |
| `event_payments.ts` | `TicketPaymentSettler`, method/instructions | `dispatchTicketRefund` = `sendRefundOnce` + `ticketRefundHandler`; `resendTicketRefund` removed | the settler's `dispatchRefund` calls V2's `dispatchTicketRefund` |
| `http/payment_webhook.ts` | `deps: SettlementDeps \| BookingDeps`, `settleTransfer` | refund bodies, `refundSubjects?` | both (Contract → Functions comment) |
| `callables/payment.ts` | generic fake confirm, `getPaymentInstructions` | `FAKE_PAYER` in the fake body | `fakeTransferFor` adds V2's `FAKE_PAYER` when it exists |
| `infra/live_booking.ts`, `infra/live_event.ts` | `payments: FirestorePaymentLookup` on event deps | `cipher: liveAccountCipher()` | both fields |

Also both edit (additive, rebase only): `escrow.ts`, `booking_ports.ts` (V1 renames `PaymentInstructions` → `GatewayInstructions` and the `createPayment` param; V2 changes `issueRefund`), `fake_payment_gateway.ts`, `event_ports.ts`, `index.ts` (domain and Functions), `infra/booking_firestore.ts`, `scheduled/payment_clock.ts`. If V2 is already on `develop` when a V1 task starts, its Step 1 lists V2's names and the task uses them (no `dispatchRefunds` Ruling-7 assumption in new tests). If V1 lands first and tickets pay by bank QR, V2 Task 3 binds `PAYMENT_SECRETS` on `cancelEvent` and `eventClock` (its own note).

---

### Task 1: Domain contract: generic payment model and pure helpers

**Files:**
- Create: `packages/domain/src/payment_ports.ts`, `packages/domain/src/payment_settlement.ts` (pure part), `packages/domain/test/payment_settlement.test.ts`
- Modify: `escrow.ts` (`PAYMENT_SUBJECTS`, `isPaymentSubject`, `Payment.instructions`), `booking_ports.ts` (`GatewayInstructions`, `createPayment` params), `create_payment.ts` (`newSubjectPayment`, exported `freshPaymentId`, `issuePaymentInstructions`, `instructionsOf`; `createPayment` uses `freshPaymentId(deps.store, deps.ids)`, passes `subjectType: 'booking', subjectId`, and stores `instructions` on the payment), `handle_transfer.ts` (private `applyTransfer` uses the pure one; `TransferResult`, `transferRecordId` move to `payment_settlement.ts` and are imported back), `booking_payment_paths.ts` (`expireOpenPayment` uses `expireUnpaid`; `markPaid`/`paymentReceivedEntry` deleted if unused), `fake_payment_gateway.ts` (param rename; `FAKE_TRANSFER_KINDS`, `FakeTransferKind`, `FAKE_OVERPAY_VND`, `FAKE_WRONG_CONTENT`, `fakeTransferFor`), `index.ts`, `test/create_payment.test.ts` (new cases appended)

**Interfaces:**
- Consumes: #129's `decideTransfer`, `transferRefund`, `transferCodeFor`, `TransferNotification`, `TransferRecord`.
- Produces: everything in Contract → Domain from `escrow.ts`, `booking_ports.ts`, `payment_ports.ts` (types only), `payment_settlement.ts` (`PaymentLookup`, `SettlementDeps`, `TransferResult`, `transferRecordId`, `transferRecordOf`, `applyTransfer`, `expireUnpaid`), `create_payment.ts` (`newSubjectPayment`, `freshPaymentId`, `issuePaymentInstructions`, `instructionsOf`), `fake_payment_gateway.ts` (fake kinds, `fakeTransferFor`).
- `applyTransfer` rules (port of #129's private one, pure):
  - `expiresAt` = `payment.expiresAt ?? createdAt + PAYMENT_EXPIRY_MINUTES` (as today); `decision = decideTransfer({status, amount, receivedBefore: receivedAmount ?? 0, expiresAt, transferAmount, receivedAt})`.
  - `ledgerEntry`: type `ticket_received` when `subjectType === 'event_registration'`, else `payment_received`; `accountOwnerId 'platform_escrow'`, `amount = transfer.amount`, `note = \`Payment for ${subjectType} ${subjectId}\``, `at = now`.
  - `partial` → `{...payment, receivedAmount: decision.received, updatedAt}`; `paid` → `status 'paid'`, `escrowStatus 'held'`, `receivedAmount = amount`, `paidAt = updatedAt = now`; `refund` → payment unchanged. `excess` = `decision.kind === 'paid' ? decision.excess : 0`.
- `expireUnpaid`: throws `DomainError('conflict')` unless `status === 'created'`; payment → `expired`, escrow `refunded`; refund = `transferRefund({…, amount: receivedAmount, reason: 'underpaid_expired'})` only when `receivedAmount > 0`.
- `issuePaymentInstructions`: `DomainError('conflict')` unless the payment has `method`, `transferCode`, `expiresAt` and is `created`; calls `gateway.createPayment({paymentId, subjectType, subjectId, amount, method, transferCode, expiresAt, idempotencyKey})` once; calls `save(providerRef, rest)`; returns `instructionsOf({...payment, instructions: rest})`.

- [ ] **Step 1: Contract check** of the domain files above (`grep -rn "PaymentInstructions\|createPayment(" packages/domain/src app_flutter/firebase/functions/src` lists every user of the renamed type and port param); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `payment_settlement.test.ts`:
    - `applyTransfer: exact → paid, receivedAmount = amount, one payment_received entry of the transfer amount`;
    - `applyTransfer: under then top-up → partial with the running total, then paid with excess 0`;
    - `applyTransfer: over → paid with excess = the part above the amount` (1 500 000 + 1 600 000 transfer → excess 100 000);
    - `applyTransfer: a late transfer or one to a paid payment → refund decision, payment unchanged, ledger still records it`;
    - `applyTransfer: a ticket payment records ticket_received`;
    - `expireUnpaid: nothing received → expired, escrow refunded, no refund`;
    - `expireUnpaid: 400 000 received → one underpaid_expired refund of 400 000 with fromEscrow false and its refund_issued entry`;
    - `expireUnpaid refuses a payment that is not created`;
    - `transferRecordOf builds id provider_txnId and keeps raw and receivedAt`.
  - `create_payment.test.ts` (append):
    - `newSubjectPayment sets created, held, the PB code of its id, zero received and an ISO expiresAt`;
    - `instructionsOf rebuilds the instructions from the stored payment and is null without them`;
    - `issuePaymentInstructions calls the gateway once with subjectType and subjectId and saves providerRef and instructions`;
    - `issuePaymentInstructions refuses a payment without method, code or expiry (conflict)`;
    - `freshPaymentId skips an id whose code any payment of any subject uses`;
    - `createPayment stores the gateway instructions on the booking payment`.
    - `fakeTransferFor gives the amounts and contents of the four kinds` (in `payment_settlement.test.ts`).
- [ ] **Step 3:** Run `cd packages/domain && npm test`. The new tests fail.
- [ ] **Step 4: Implement** as above. Booking behaviour must not change: `createPayment` still calls the gateway inside its transaction (Decision 2); only its id draw and the extra `instructions` field change.
- [ ] **Step 5:** `npm test`, `npm run typecheck`, `npm run lint` green; **every #129 test unedited** (`git diff --stat packages/domain/test` shows only `create_payment.test.ts` additions and the new files).
- [ ] **Step 6: Commit:** `feat(domain): generic payment instructions, newSubjectPayment and pure applyTransfer/expireUnpaid [#200]`.

### Task 2: Domain settlement dispatch: settleTransfer, settlers, sweeps, check, fake confirm

**Files:**
- Create: `packages/domain/src/memory_payment_lookup.ts`, `packages/domain/test/settlement_dispatch.test.ts`
- Modify: `payment_settlement.ts` (`settleTransfer`, private `matchPayment` moved from `handle_transfer.ts` and made cross-subject, `confirmFakePayment`), `create_payment.ts` (`checkSubjectPayments`, `readPaymentInstructions`), `handle_transfer.ts` (`BookingPaymentSettler`, `bookingPaymentLookup`, `bookingSettlement`, `asSettlement`; `handleTransferNotification` becomes the wrapper), `payment_sweeps.ts` (`runPaymentSweeps(deps: SettlementDeps | BookingDeps)`), `index.ts`, `test/support/booking_world.ts` (`settlement: SettlementDeps` = `{payments: new MemoryPaymentLookup([store]), gateway, clock, subjects: {booking: new BookingPaymentSettler(deps)}}`)

**Interfaces:**
- Consumes: Task 1.
- Produces: `settleTransfer`, `confirmFakePayment`, `checkSubjectPayments`, `readPaymentInstructions`, `BookingPaymentSettler`, `bookingPaymentLookup`, `bookingSettlement`, `asSettlement`, `MemoryPaymentLookup`, `PaymentSource`, `runPaymentSweeps(SettlementDeps | BookingDeps)`; `BookingWorld.settlement`.
- `settleTransfer(deps, n)` order:
  1. Invalid notification (#129's `validNotification`) → `DomainError('invalid_argument')`.
  2. `deps.payments.getTransferRecord(transferRecordId(n))` exists → `{outcome: 'duplicate', paymentId?}`.
  3. `matchPayment`: for each code of `transferCodesIn(content)`, candidates = `findPaymentsByTransferCode(code)` with `createdAt <= receivedAt` **and a settler for their subject**; the open one wins, else the newest (#129 rule).
  4. None → `saveUnmatchedTransfer(transferRecordOf(n, 'needs_review'))` → `{outcome: 'needs_review'}`.
  5. Else `{outcome: await deps.subjects[p.subjectType]!.settle(p.id, n), paymentId: p.id}`.
- `BookingPaymentSettler` (body = #129 code moved, not rewritten):
  - `settle` = the transaction of today's `handleTransferNotification` from "seen → duplicate" on (payment, booking, applyTransfer path, `saveTransferRecord`), then refunds after commit through `this.dispatchRefund`.
  - `expire` = today's sweep transaction (`created`, `expiresAt <= now` → `expireOpenPayment`), then dispatch.
  - `dispatchRefund(refund, payment)` = `(await dispatchRefunds(deps, [{refund, provider: payment.provider}]))[0]`.
  - `statusOf(payment)` = the booking's `status`, or `'gone'` when the booking no longer exists.
- `bookingPaymentLookup(store)`: forwards `getPayment`, `findPaymentsByTransferCode`, `getTransferRecord`, `findPaymentsToReconcile`, `findOverduePayments` (booking-only, #129); `saveUnmatchedTransfer` = `store.runTransaction(tx => seen ? no-op : tx.saveTransferRecord(r))`.
- `runPaymentSweeps(raw)`: `deps = asSettlement(raw)`; reconcile = #129 loop over `deps.payments.findPaymentsToReconcile(cutoff)` skipping payments without `transferCode` or without a settler, `settleTransfer` per transfer; expire = for `findOverduePayments(now)` with a settler: `settler.expire(p.id, now)`; `'expired'` → `expired += 1` and `refunded += 1` when `(p.receivedAmount ?? 0) > 0`; a throw → `expireFailed += 1`. Counts and per-item isolation exactly as #129.
- `checkSubjectPayments(deps, payments)`: for each `created` payment with a `transferCode`: `gateway.queryTransfers({paymentId, transferCode, providerRef})` then `settleTransfer` each; afterwards true when any of them re-reads as `paid`.
- `confirmFakePayment(deps, caller, raw)`: `{paymentId}` must be an id (`invalid_argument`), `kind` ∈ `FAKE_TRANSFER_KINDS` (default `exact`), payment exists (`not_found`), `payerId === caller.uid` (`permission_denied`), has a `transferCode` (`conflict`), its subject has a settler (`not_eligible`); `settleTransfer(deps, fakeTransferFor(p, kind, now))`; then `{outcome, subjectType, paymentStatus: (re-read).status, subjectStatus: await settler.statusOf(re-read)}`.
- `readPaymentInstructions`: payer only (`not_found` / `permission_denied` / `invalid_argument`); `status === 'created'` → `instructionsOf(p)`, else `null`.

- [ ] **Step 1: Contract check** (Task 1 names; `handleTransferNotification`, `runPaymentSweeps`, `MemoryBookingStore` maps); ledger differences.
- [ ] **Step 2: Failing tests** in `settlement_dispatch.test.ts`. A test-only `RecordingSettler` for a made-up subject (`'test_subject' as PaymentSubject`) records calls and keeps payments in a `PaymentSource`.
  - `settleTransfer hands a booking transfer to subjects.booking with the same outcome as handleTransferNotification`;
  - `settleTransfer hands another subject's transfer to its settler`;
  - `a payment whose subject has no settler is needs_review and only the transfer record is written` (Review Focus 2);
  - `unmatched content is needs_review once; the second delivery is duplicate`;
  - `a repeated transfer is duplicate without calling the settler`;
  - `the open payment wins over an older closed payment with the same code`;
  - `a payment created after the transfer is never matched`;
  - `runPaymentSweeps reconciles and expires every subject through its settler and counts them`;
  - `runPaymentSweeps skips a subject without a settler and still finishes the batch` (Review Focus 2);
  - `a settler.expire that throws is counted as expireFailed and the next payment still expires`;
  - `checkSubjectPayments settles a transfer found by queryTransfers and returns true; false when nothing arrived`;
  - `confirmFakePayment exact/under/over/wrong_content give paid/partial/paid_with_refund/needs_review through the settler`;
  - `confirmFakePayment: another payer is permission_denied; no settler is not_eligible; it returns statusOf`;
  - `readPaymentInstructions: the payer gets a created payment's instructions; null once paid; another user is permission_denied`;
  - `BookingPaymentSettler.statusOf gives the booking status, and gone when the draft was deleted`;
  - `MemoryPaymentLookup sees the payments of every source and stores an unmatched record once`.
- [ ] **Step 3:** Run `npm test`. The new tests fail.
- [ ] **Step 4: Implement.** Move code, do not rewrite it: `git diff` of `handle_transfer.ts` should read as a move into the settler plus the wrapper.
- [ ] **Step 5:** `npm test`, `npm run typecheck`, `npm run lint` green; `handle_transfer.test.ts`, `payment_sweeps.test.ts`, `create_payment.test.ts` (old cases) and `escrow*.test.ts` pass **unedited** (Review Focus 4).
- [ ] **Step 6: Commit:** `feat(domain): settleTransfer dispatches by subject; booking is the first SubjectSettler [#200]`.

### Task 3: Domain: tickets on the shared model

**Files:**
- Create: `packages/domain/test/ticket_settlement.test.ts`
- Modify: `event_payments.ts` (`TicketPaymentSettler`; `ticketIdempotencyKey`/`newTicketPayment` per Contract; `checkTicketPayment` via `checkSubjectPayments`; delete `handleTicketPayment`, `confirmFakeTicketPayment`, `issueTicketIntent`, `parseTicketProvider`; `dispatchTicketRefund` becomes the settler's `dispatchRefund` body, still used by `refundTicket`/`resendTicketRefund`), `event_registration.ts` (`method`, `freshPaymentId`, `issuePaymentInstructions`/`instructionsOf`, `RegisterResult.instructions`), `event_ports.ts` (`EventPaymentDeps.payments`, `EventTx.getTransferRecord`/`putTransferRecord`), `memory_event_store.ts` (`transferRecords` map, tx methods; it is a `PaymentSource`), `booking_ports.ts` (drop `createDepositIntent`, `checkPaymentStatus`), `fake_payment_gateway.ts` (drop them and `markPaid`/`paidPayments`), `index.ts`, `test/event_payments.test.ts`, `test/event_registration.test.ts`, `test/support/event_world.ts` (`createTicketPaymentWorld()` → `{w, gateway, deps: EventPaymentDeps, settlement}` with `subjects.event_registration`, `MemoryPaymentLookup([w.store])`, and a `payTicket(paymentId, kind = 'exact')` helper that runs `confirmFakePayment`)

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: `TicketPaymentSettler`, ticket Contract lines, `createTicketPaymentWorld`.
- `registerEvent`: raw `method` (`isPaymentMethod`, else `invalid_argument`; absent on a paid event's first tap → `invalid_argument`, absent on "Thanh toán tiếp" → reuse the hold's current payment). When `method` is present and the deps have `payments`, draw `freshPaymentId(deps.payments, deps.ids)` **before** the transaction. Inside: reuse rules as today with `method` in place of `provider`; a new payment = `newTicketPayment({… method, provider: gateway.provider, expiresAt: holdExpiresAt})`. After commit: `instructionsOf(payment)` when stored, else `issuePaymentInstructions(gateway, payment, save)` where `save` writes `providerRef` + `instructions` in an events transaction while the payment is still `created` (today's `issueTicketIntent` pattern).
- `TicketPaymentSettler.settle(paymentId, n)` — one events transaction, all reads first: record seen → `'duplicate'`; payment (must be `event_registration` with `eventId`, else `not_found`), registration, event, contact (as `handleTicketPayment` read it). Then `applyTransfer`:
  - `partial` → put payment → `'partial'`.
  - `refund` → put the `transferRefund` (reason from the decision, `providerRef = n.txnId`) and its ledger entry; refund mark on the registration by Decision 7's rule → `'refunded'`.
  - `paid` → today's `handleTicketPayment` branches (live → ticket `paid`, contact snapshot, seats; not live → `applyRefundToPayment` 100% `late_payment_hold_expired`, mark, seats back) → `'paid'` / `'refunded'`; `excess > 0` adds a `transferRefund` `overpaid_excess` → `'paid_with_refund'` when live.
  - Always `putTransferRecord(transferRecordOf(n, outcome, paymentId))`. After commit `this.dispatchRefund` for each new refund.
- `expire(paymentId, now)`: events transaction; `created` and `expiresAt <= now` → `expireUnpaid`; put payment, refund, ledger; dispatch → `'expired'`, else `'unchanged'`.
- `statusOf(payment)`: the registration's `status`, or `'gone'`.
- `checkTicketPayment`: same checks as today (owner, `held` with a `paymentId`); then `checkSubjectPayments(deps.settlement, [payment])`; re-read the registration → `{paid: status === 'paid', status}`.

- [ ] **Step 1: Contract check** (10c ticket code, `MemoryEventStore` tx guard, `event_world.ts`); `grep -rn "provider\b" packages/domain/src/event_registration.ts`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `ticket_settlement.test.ts`:
    - `a paid registration holds seats and returns VietQR instructions for bank_qr` (`qrPayload` contains the transfer code; `expiresAt` = `holdExpiresAt`; `transferCode` matches `/^PB /`);
    - `a paid event needs a known method` (`'vnpay'` and missing → `invalid_argument`);
    - `the same method twice reuses the payment and its instructions (one gateway call)`;
    - `another method opens a second payment for the same hold`;
    - `Thanh toán tiếp without a method keeps the hold's payment`;
    - `a ticket payment's code is fresh across subjects` (a booking payment already holds the first drawn code) (Review Focus 5);
    - `an exact transfer makes the ticket paid and moves held to registered` (one `ticket_received`, contact snapshot);
    - `a webhook-style transfer reaches TicketPaymentSettler, then a repeat is duplicate` (through `settleTransfer`) (Review Focus 1);
    - `under then top-up pays the ticket; over refunds only the excess`;
    - `a transfer after the hold expired is refunded (late_transfer) and marks the ticket refund pending` (Review Focus 3);
    - `a second payment paid after the first is refunded and the paid ticket is untouched`;
    - `confirmFakePayment on a ticket: payer only; returns the registration status`;
    - `checkTicketPayment settles a transfer the gateway reports`;
    - `runPaymentSweeps expires an unpaid ticket payment and refunds what it received`;
    - `statusOf gives the registration status`;
    - `ledger: ticket_received then refund_issued keep invariant 11`.
  - `event_payments.test.ts`: the groups "paid registration" and "ticket payment" are replaced by the file above (delete them there); the refund, refund-state and escrow groups stay and replace every `confirmFakeTicketPayment`/`markPaid` call with `payTicket(…)`; their assertions do not change.
  - `event_registration.test.ts`: every `provider:` input becomes `method:`; `paid events are not_eligible without a payment gateway` unchanged.
- [ ] **Step 3:** Run `npm test`. The new tests fail.
- [ ] **Step 4: Implement.** Fix the compile errors the port removals cause.
- [ ] **Step 5:** `npm test`, `npm run typecheck`, `npm run lint` green (`purity.test.ts` included).
- [ ] **Step 6: Commit:** `feat(domain): event tickets pay through the shared settlement; drop deposit intents [#200]`.

### Task 4: Functions: liveSettlementDeps, cross-subject lookup, webhook, clock, callables, indexes

**Files:**
- Create: `src/infra/live_payments.ts`, `src/infra/payment_firestore.ts`, `test/unit/live_payments.test.ts`
- Modify: `src/infra/booking_firestore.ts` (payment `instructions` map; refund/payment subject read via `isPaymentSubject`), `src/infra/event_firestore.ts` (`getTransferRecord`/`putTransferRecord` on `payment_notifications` with `transferRecordTo/FromFirestore`), `src/infra/live_event.ts` (`payments: new FirestorePaymentLookup(db())`), `src/http/payment_webhook.ts`, `src/scheduled/payment_clock.ts`, `src/callables/payment.ts` (generic `handleConfirmFakePayment`, `handleGetPaymentInstructions`; re-export the fake kinds from the domain), `src/callables/event.ts` (`method`, `instructions`; delete `handleConfirmFakeTicketPayment`; `handleCheckTicketPayment(request, deps & {settlement})`), `src/infra/fake_payments.ts` (doc comment), `src/index.ts`, `app_flutter/firebase/firestore.indexes.json`; tests `payment_callables.test.ts`, `payment_webhook.test.ts`, `payment_clock.test.ts` (append only), `event_payment_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `booking_firestore.test.ts`, `test/integration/event_paid.test.ts`, `test/integration/booking.test.ts` (unchanged unless it breaks)

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: Contract → Callables and HTTP; `liveSettlementDeps()`, `FirestorePaymentLookup`.
- `FirestorePaymentLookup`: `getPayment`, `findPaymentsByTransferCode` (`transferCode ==`), `getTransferRecord`, `saveUnmatchedTransfer` (`create()`; an `already-exists` error is swallowed), `findPaymentsToReconcile` (`status == 'created'`, `method in PAYMENT_METHODS`, `createdAt <=`), `findOverduePayments` (`status == 'created'`, `method in`, `expiresAt <=`); mapping through `paymentFromFirestore`.
- Indexes added: `payments (status ASC, method ASC, createdAt ASC)` and `payments (status ASC, method ASC, expiresAt ASC)`; the #129 booking indexes stay (`FirestoreBookingStore` still uses them through `bookingPaymentLookup`).
- `handleConfirmFakePayment(request, deps, env)`: `assertFakePaymentsAllowed(env)` first; `d = asSettlement(deps)`; `kind` check; payer check through `d.payments.getPayment` (`not_found`/`permission_denied`); no `transferCode` → `conflict`; no settler → `not_eligible`; body = `JSON.stringify` of `fakeTransferFor(...)` without `provider`/`raw`; sign; `handlePaymentWebhook({provider: 'fake', rawBody, headers}, d, env)`; return `{outcome}`.
- `index.ts`: `paymentWebhook` → `servePaymentWebhook(req, res, liveSettlementDeps())`; `paymentClock` → `handlePaymentClock(liveSettlementDeps())`; `confirmFakePayment` → `handleConfirmFakePayment(request, liveSettlementDeps())`; new `getPaymentInstructions = onCall(PAYMENT_CALLABLE_OPTIONS, (r) => handleGetPaymentInstructions(r, liveSettlementDeps()))`; `checkTicketPayment` → `{...liveEventPaymentDeps(), settlement: liveSettlementDeps()}`; remove `confirmFakeTicketPayment` (the CI deploy uses `--force`).

- [ ] **Step 1: Contract check** (Functions files above, `firestore.indexes.json` payment entries); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `payment_webhook.test.ts` (append): `a signed transfer for a ticket payment is settled by the ticket settler (200 paid)` (memory `SettlementDeps` with both settlers) (Review Focus 1); `a transfer for a subject without a settler is 200 needs_review` (Review Focus 2).
  - `payment_callables.test.ts` (append): `confirmFakePayment pays a ticket payment through the webhook path`; `confirmFakePayment for a subject without a settler is not_eligible`; `getPaymentInstructions returns a created payment's instructions to its payer, null once paid, permission_denied for another user, unauthenticated refused`.
  - `payment_clock.test.ts` (append): `the clock expires a ticket payment through liveSettlementDeps-shaped deps`.
  - `live_payments.test.ts`: `liveSettlementDeps registers booking and event_registration settlers and one gateway`.
  - `event_payment_callables.test.ts`: `registerEvent takes method and returns instructions`; `registerEvent refuses provider-only input (invalid_argument)`; `there is no confirmFakeTicketPayment export`; `checkTicketPayment applies a transfer the gateway reports` (replaces the `markPaid` case); the guard matrix cases stay.
  - `booking_clock_ticket_release.test.ts`: pay with `payTicket` instead of `confirmFakeTicketPayment`; assertions unchanged.
  - `booking_firestore.test.ts`: `round-trips Payment with instructions for each subject`; `a refund with subjectType event_registration keeps it`.
  - Integration (written, not run): `event_paid.test.ts` registers with `method: 'bank_qr'`, confirms with `confirmFakePayment`, sees the ticket `paid`.
- [ ] **Step 3:** Run `cd app_flutter/firebase/functions && npm test`. The new tests fail.
- [ ] **Step 4: Implement.** Logs stay as #129 (provider, txnId, outcome; never the body or payer).
- [ ] **Step 5:** `npm test`, `npm run lint`, `npm run typecheck`, `npm run build` green; domain `npm test` still green; #129's Functions tests pass **unedited**. Ledger: integration tests written, not run.
- [ ] **Step 6: Commit:** `feat(functions): liveSettlementDeps; webhook, clock and fake confirm settle every subject; getPaymentInstructions [#200]`.

### Task 5: App data: PaymentInstructions, PaymentsRepository, PayMethod, events repository

**Files:**
- Create: `lib/data/payments/payment_instructions.dart`, `lib/data/payments/payments_repository.dart`, `test/support/fake_payments_repository.dart`, `test/data/payments/payment_instructions_test.dart`, `test/data/payments/payments_repository_test.dart`
- Modify: `lib/core/payments.dart`, `lib/data/booking/booking_checkout.dart` (`toInstructions()`), `lib/data/booking/booking_repository.dart` (re-export `FakeTransferKind`), `lib/data/events/event_repository.dart` (+ `FakeEventRepository`: `registerMethods` replaces `registerProviders`; paid holds return fake instructions "PB 7F3K2Q", BIDV, `9624 •••• 3812`, expiring at `holdExpiresAt`), `firestore_event_repository.dart`, `lib/features/events/register_controller.dart` (`method: args.paid ? state.method : null`), `lib/features/booking/fake_payment_sheet.dart` and `lib/features/events/ticket_payment_sheet.dart` (minimal switch to `paymentsRepositoryProvider.confirmFake` so the commit compiles; both files go in Tasks 6–7), tests `test/data/booking/booking_checkout_test.dart` (drop the `.provider` line), `test/data/events/firestore_event_repository_test.dart`, `test/features/events/register_sheet_test.dart` (`registerMethods`)

**Interfaces:**
- Consumes: the callables of Task 4.
- Produces: Contract → App `PayMethod`, `PaymentInstructions`, `paymentInstructionsFrom`, `BookingCheckout.toInstructions`, `FakeTransferKind`, `PaymentCheck`, `PaymentsRepository`, `FunctionsPaymentsRepository`, `paymentsRepositoryProvider`, events `register(method:)`, `RegisterOutcome.instructions`.
- `FakePaymentsRepository` (test support): `confirms` (`List<(String, FakeTransferKind)>`), `instructionsById` (`Map<String, PaymentInstructions?>`), `onConfirm` (callback the booking world wires to `FakeBookingRepository.confirmFakePayment`, so a confirmed booking moves to `requested` exactly as today), `nextError`.
- `BookingRepository.confirmFakePayment` stays (#129's tests and e2e use it); S04.04 stops calling it in Task 6.

- [ ] **Step 1: Contract check;** `grep -rn "PaymentProviderCode\|\.provider\b\|payUrl\|confirmFakeTicketPayment" lib test`; ledger the list.
- [ ] **Step 2: Failing tests:**
  - `paymentInstructionsFrom parses the callable map (ISO expiresAt → UTC) and a Timestamp`;
  - `a missing or malformed map is null` (no paymentId, unknown method, no transferCode);
  - `remainingAt never goes negative and isExpiredAt flips at expiresAt`;
  - `BookingCheckout.toInstructions keeps every field and the attempt`;
  - `PayMethod codes round-trip and there is no provider`;
  - `confirmFake sends {paymentId, kind: 'wrong_content'} and returns the outcome`;
  - `instructions sends {paymentId} and parses null`;
  - `register sends method: 'momo' and parses instructions` (Firestore event repository);
  - `FakeEventRepository records the method of every register call`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.** Delete `PaymentProviderCode`, `EventRepository.confirmFakeTicketPayment` and its fakes.
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/data`, then `test/features/events`, then `test/features/booking` green.
- [ ] **Step 6: Commit:** `feat(data): PaymentInstructions and PaymentsRepository; tickets register with a payment method [#200]`.

### Task 6: One S04.04: features/payment with the booking subject

**Files:**
- Create: `lib/features/payment/pay_subject.dart`, `payment_controller.dart`, `payment_screen.dart`, `open_payment.dart`, `fake_transfer_sheet.dart`; `test/features/payment/pay_subject_test.dart`, `open_payment_test.dart`, `payment_screen_test.dart` (ported from `test/features/booking/payment_pending_screen_test.dart`)
- Move (git mv, then generalise): `lib/features/booking/qr_checkout_view.dart`, `wallet_waiting_view.dart`, `payment_snack.dart` → `lib/features/payment/`
- Delete: `lib/features/booking/payment_pending_screen.dart`, `lib/features/booking/fake_payment_sheet.dart`, `test/features/booking/payment_pending_screen_test.dart`
- Modify: `lib/app/router.dart` (`/b/:id/pay`), `lib/features/booking/booking_sheet_page.dart` (`_handleOutcome` → `openPayment(context, ref, subject: BookingPay(id), instructions: checkout.toInstructions(), replace: true)`), `test/support/booking_world.dart` (wires `FakePaymentsRepository` with `onConfirm`), tests that import the moved files (`booking_sheet_test.dart`, `submit_test.dart`, the two e2e tests: imports only)

**Interfaces:**
- Consumes: Task 5; `bookingProvider(id)`, `bookingRepositoryProvider` (`createPayment`, `checkPayment`), `photographerProfileProvider(uid)`, `realPaymentsProvider`, `externalLauncherProvider`, `clockProvider`, `bookingPath(...)`.
- Produces: Contract → App `features/payment/*`.
- Booking binding (private, `case BookingPay(:final bookingId)` in `PaymentController`), behaviour = today's `PaymentPendingScreen`:
  - watch `bookingProvider(id)`: `null` → `PayGone(PayGoneKind.booking, bookingPath(last known photographer, service) ?? '/home')`; `status != draft` → `PayDone('/b/$id?paid=1')`; draft with `checkout` → `PayOpen(checkout.toInstructions(), who: (photographer display name, serviceSnapshot.name), canRenew: true)`; draft without `checkout` → `createPayment(bankQr)` once (failure → `PayFailed(bookingErrorOf(e))`, `retry()` tries again).
  - `renew()` → `createPayment(bookingId, method: current.method)`; the stream brings the new checkout.
  - `check()` → `checkPayment(bookingId).paid`.
- `PaymentScreen`: app bar `payQrTitle` (QR) / `payTitle` (wallet); `PayLoading` → `DotRingLoader`; `PayOpen` → `QrCheckoutView` or `WalletWaitingView`; `PayDone` → one post-frame `context.go(path)`; `PayGone` → `EmptyState` (booking: `payExpiredTitle`, `payExpiredBody`, `payBookAgain` | `payGoHome`); `PayFailed` → `ErrorState` with retry. Renew errors → `showPaymentSnack` with `payAttemptsExceeded` / `bookNetworkError` / `bookTryAgain` (as today).
- `QrCheckoutView` keeps #129's layout, keys and semantics; the only changes are its inputs (`instructions`, `who`, callbacks) and, when `canRenew` is false, the expired footer's single primary is `payBackToEvent` calling `onBack` (used by Task 7).
- `FakeTransferSheet` = #129's `FakePaymentSheet` calling `paymentsRepositoryProvider.confirmFake(paymentId, kind: kind)`.
- `openPayment`: `instructions.method != bankQr && ref.read(realPaymentsProvider) && payUrl != null` → `externalLauncherProvider.open(payUrl)`; then `replace ? context.replace(path, extra: instructions) : context.push(path, extra: instructions)`.

- [ ] **Step 1: Contract check** (the booking files above and their tests); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `pay_subject_test.dart`: `payPathOf gives /b/{id}/pay and /e/{eventId}/pay/{regId}`; `subjects with the same fields are equal and share a hash` (family key).
  - `open_payment_test.dart`: `bank_qr pushes S04.04 with the instructions as extra`; `a wallet with real payments opens payUrl then S04.04`; `a wallet in fake mode goes straight to S04.04`; `replace: true replaces the current route`.
  - `payment_screen_test.dart`: every case of the old `payment_pending_screen_test.dart` with **the same name and assertions** (`pumpBookingRoute(path: '/b/booking_1/pay')`), except that the fake-sheet cases assert `payments.confirms` instead of `repo.fakeConfirms` (Review Focus 4); plus `the route extra renders the QR before the booking stream answers`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/features/payment`, then `test/features/booking`, then `test/core` green.
- [ ] **Step 6: Commit:** `feat(payment): one S04.04 for every payment subject, booking first [#200]`.

### Task 7: Tickets pay on S04.04 (S11.03, S11.04-pending)

**Files:**
- Create: `test/features/payment/payment_screen_ticket_test.dart`
- Delete: `lib/features/events/ticket_payment_sheet.dart`
- Modify: `lib/features/payment/pay_subject.dart` (`TicketPay`), `payment_controller.dart` (`case TicketPay`), `payment_screen.dart` (ticket done SnackBar, gone texts), `lib/app/router.dart` (`/e/:eventId/pay/:regId`), `lib/features/events/register_sheet.dart` (`showRegisterSheet(context, ref, {event})`: a held outcome closes the sheet, then `openPayment(subject: TicketPay(eventId, regId), instructions: outcome.instructions!)`; the in-sheet countdown and `_pay` go), `register_controller.dart` (a `held` outcome is returned like a free one, carrying `instructions`), `event_screen.dart` (passes `ref`), `tickets_tab.dart` (`_continuePayment`, Decision 13), `lib/l10n/app_vi.arb` (two new keys, removals), tests `test/features/events/register_sheet_test.dart`, `tickets_tab_test.dart`, `event_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 5–6; `myEventRegistrationProvider(eventId)`, `eventRepositoryProvider.checkTicketPayment`, `paymentsRepositoryProvider.instructions`.
- Produces: `TicketPay`, route `/e/:eventId/pay/:regId`, `showRegisterSheet(BuildContext context, WidgetRef ref, {required EventDetail event})`.
- Ticket binding (`case TicketPay(:final eventId, :final registrationId)`):
  - watch `myEventRegistrationProvider(eventId)`: the registration with id `registrationId` and status `paid` → `PayDone('/bookings?tab=events&highlight=$registrationId')`; `held` → `PayOpen(seeded instructions ?? await PaymentsRepository.instructions(paymentId), who: (event.title, l10n-free count passed as int → view formats `ticketCount`), canRenew: false)`; instructions `null` (payment closed) or any other status/id → `PayGone(PayGoneKind.ticket, '/e/$eventId')`.
  - `check()` → `checkTicketPayment(eventId, registrationId).paid`. No `renew`.
- `PaymentScreen` for `TicketPay`: `ScreenCode(…, label: 'ticket')`; on `PayDone` shows `registerDone` with action `registerOpenChat` (push `/e/$eventId/chat`) then `go(path)`; `PayGone(ticket)` → `registerHoldExpired` / `payTicketExpiredBody` / `payBackToEvent`.
- l10n: add `payTicketExpiredBody`, `payBackToEvent` (Contract); delete the keys listed in Contract that `grep` finds unused; `flutter gen-l10n`.

- [ ] **Step 1: Contract check** (register sheet, tickets tab, router); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `payment_screen_ticket_test.dart`:
    - `TicketPay shows the QR, 500.000₫, "Photo walk phố cổ · 2 vé", "Chờ thanh toán" and "Còn 10:00"`;
    - `at 00:00 the only button is a primary "Về sự kiện" and it opens /e/{eventId}` (Review Focus 3);
    - `a paid registration goes to /bookings?tab=events&highlight={regId} with "Đăng ký thành công" and "Vào nhóm chat"` (the `registerDone`/`registerOpenChat` values);
    - `a cancelled hold shows "Chỗ giữ đã hết hạn" with "Về sự kiện"`;
    - `without extra the instructions come from PaymentsRepository.instructions`;
    - `a closed payment (instructions null) shows the expired state`;
    - `wallet "Kiểm tra lại" calls checkTicketPayment`;
    - `fake mode simulator confirms through PaymentsRepository.confirmFake`;
    - `one primary button at a time`; `fits 320 dp at 1.3x text, light and dark`.
  - `register_sheet_test.dart`: `Thanh toán registers with the chosen method code, closes the sheet and opens /e/{id}/pay/{regId} with the instructions`; `a wallet with real payments opens payUrl then S04.04`; `a free event still closes with the ticket and opens the tickets tab`; the old cases "Thanh toán starts the hold countdown", "fake mode confirms through the ticket payment sheet", "real mode opens payUrl", "an expired hold says Chỗ giữ đã hết hạn" are deleted (their behaviour now lives on S04.04 and is covered above).
  - `tickets_tab_test.dart`: `Thanh toán tiếp checks first, then opens S04.04 for the hold`; `Thanh toán tiếp on a hold the gateway already has does not open S04.04`; the pay-URL case is replaced by `Thanh toán tiếp with real payments opens S04.04 (Mở lại there)`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/features/payment`, then `test/features/events`, then `test/features/booking`, then `test/l10n` green; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit:** `feat(events): S11.03 tickets pay on the shared S04.04 [#200]`.

### Task 8: Specs, data model, reconciliation table and ledger

**Files:**
- Modify:
  - `docs/superpowers/specs/screens/booking.md` S04.04: serves every subject (`PaymentScreen`, routes `/b/:id/pay`, `/e/:eventId/pay/:regId`; ticket line, gone state and "Về sự kiện"; data from the subject's stream plus `getPaymentInstructions`).
  - `docs/superpowers/specs/screens/events.md` S11.03/S11.04: `registerEvent {method}` returns `instructions`; after "Thanh toán" → S04.04; "Thanh toán tiếp" → S04.04; no `payUrl`, no MoMo/VNPay providers.
  - `docs/superpowers/specs/components/shared-components.md`: `PaymentScreen`, `QrCheckoutView`, `WalletWaitingView`, `FakeTransferSheet` under `features/payment`.
  - `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §9: one paragraph on the subject extension point (`SubjectSettler`, `liveSettlementDeps`, transfer record per subject).
  - `docs/superpowers/specs/data-model/domain-model.md` (`PaymentSubject` list, `Payment.instructions`), `relational-schema.md` (`payments.instructions` jsonb, subject check list).
  - `docs/superpowers/plans/2026-10-08-s04-reconciliation.md`: rows marked "V1" become (a)/(b) with the real names and "#200"; the deviation table of this plan is linked from the V1 section.
  - `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2: S04.04 "Làm bởi" adds the PR of #200; S11.03 status cell links the PR.
- Create: `docs/superpowers/handover/ledger-v1-subject-payments.md`.

- [ ] **Step 1: Ledger** (English prose, Vietnamese copy verbatim): every task's Step 1 findings; Decisions 1–16 as taken; the deviation table; the removed strings; skipped suites (Functions integration tests written, not run); deploy order (Functions with the indexes, then the app; `confirmFakeTicketPayment` deleted with `--force`); dev ticket payments without `method` are never reconciled (Decision 15); Deferred below.
- [ ] **Step 2:** Edit the docs in the house style (Vietnamese specs, English code names). Check every string quoted in `screens/booking.md` S04.04 and `screens/events.md` S11.03 against `app_vi.arb`.
- [ ] **Step 3:** `git diff --stat` shows only docs in this task.
- [ ] **Step 4: Commit:** `docs(payments): shared S04.04, ticket payments and the subject extension point in specs and ledger [#200]`.

## Deferred

- Refund to the sender's account, `awaiting_account`, refund re-send under the same id for every subject in `paymentClock`, refund webhook: V2 (#201); it replaces the settlers' #129 dispatch with `sendRefundOnce` + `mergeRefundOutcome` and the ticket `refund_resend` step with its `RefundSubjects` re-send.
- Subjects `instant_request` (#202) and `verification_fee` (#203): each adds its code to `PAYMENT_SUBJECTS`, a settler, one line in `liveSettlementDeps()`, a `RefundSubjectHandler` in V2's `liveRefundSubjects()`, a `PaySubject` variant, route and `case`.
- Platform revenue ledger entries (`gateway_fee`, `payout_fee`, `revenue_received`): V3.
- The real payment intermediary (its signature scheme, secret, collection account, refund API); card methods.
- Mock frames `#S04.04-expired`, `#S04.04-wait` and a ticket variant of `#S04.04` (the existing frame's layout is reused).
