# V2 Refund to the payer account, refund re-send and refund webhook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (standing rule):** write them, do not run them; CI runs them. Record the skip in the ledger. This plan does not change `firestore.rules` (`payments`, `refunds`, `payment_notifications` stay server-only); it changes `firestore.indexes.json`. No battery/performance, device build or iOS steps.

> **Detail level ("ở giữa", owner):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

> **Functions package between tasks:** `app_flutter/firebase/functions` compiles `packages/domain/src` directly (`tsconfig` path `@photobooking/domain`). Tasks 1–3 change only the domain (and one Dart enum); the Functions typecheck is expected to fail from Task 2 until Task 4 brings it back. Run only the domain (and Flutter) checks in Tasks 1–3.

**Goal:** A bank-QR refund goes back to the account that paid. The server keeps the sender's account from the first matched transfer (number encrypted), every refund knows how it is paid back (`gateway` for wallets and tickets, `bank_transfer` to a stored account for bank QR) and waits in `awaiting_account` when there is no account to send to. A refund whose gateway call threw stays `pending` and the payment clock sends it again under the same refund id until it is done (or, after 6 failed calls, goes to staff). A provider can report a refund's final outcome through the existing payment webhook. Tickets use the same re-send; the event clock's own re-send step goes away.

**Architecture:** Pure rules in `packages/domain`: the refund model (`RefundMethod`, `StoredBankAccount`, `awaiting_account`, `Payment.payer`, `Payment.refundedAmount`), payer capture (`payerAccountOf`), and the two halves every refund dispatcher uses: `sendRefundOnce` (one gateway call, never throws) and `mergeRefundOutcome` (what to store, inside the subject's own transaction). A small registry, `RefundSubjects`, lets subjects whose documents the booking store does not own (tickets now, V1's subjects later) take part in the re-send and in refund events. `runPaymentSweeps` gains a named re-send step; `applyRefundEvent` applies a provider's refund event. Functions stay thin: the lazy `AccountCipher` from `PAYOUT_ACCOUNT_KEY` (S06's AES-256-GCM) goes into `BookingDeps`/`EventPaymentDeps`, the functions that can encrypt or decrypt bind the secret, the fake webhook carries the payer's account number (redacted before it is stored) and a refund event type, and Firestore gets the new fields and two queries.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 `onCall`/`onRequest`/`onSchedule`, `node --test` via tsx), Firestore indexes; Flutter (one enum value, `flutter_test`).

**Spec:**
- `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §3.3 (excess and late money "hoàn về tài khoản đã chuyển"), §5 (VietQR: "Chi một khoản về tài khoản đã chuyển (số tài khoản, tên, ngân hàng lấy từ webhook)"; "Thiếu thông tin người chuyển → bắt buộc khai tài khoản"; `Refund` gains `method` (`gateway` | `bank_transfer`), a masked and encrypted destination, `providerRef`, `failureReason?`), §9 (port, idempotency keys, fakes simulate webhooks), §13 (tests).
- `docs/superpowers/plans/2026-10-08-s04-reconciliation.md` section "V2" (this unit's scope) and its table rows marked V2.
- `docs/superpowers/plans/2026-10-07-s04-booking-payment.md` Decisions 7–8 and its Contract (the superseded plan whose V2 names the consumers quote).
- Consumers whose quoted names this plan keeps: `2026-10-07-s22-payments-account.md` (#141, Decisions 5–7, Tasks 2, 3, 5–7), `2026-10-07-s13-s14-dispatch-provider.md` (#140, `InstantPaymentSettler.dispatchRefund`), `2026-10-07-s18-disputes-help.md` (#142, Task 2 `dispatchDisputeRefund`).
- `docs/superpowers/specs/data-model/` (`README.md` conventions, `domain-model.md`, `relational-schema.md`); cost unit prices `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`.

**Issue:** #201 (Thanh toán · V2 hoàn về tài khoản người chuyển, gửi lại hoàn tiền).

**Branch:** `plan/201-hoan-tien` from `origin/develop`; PR into `develop` titled `feat(payments): refund to payer account and refund re-send V2 [#201]`.

**Blocked by:** nothing. V2 changes the refund record and the refund dispatch path that booking payments (#129, merged in #154) and tickets already share; it does not touch how a payment is created or which subject a transfer settles, which is all V1 (#200, `2026-10-08-v1-subject-payments.md`) changes. V1 later routes its subjects through this plan's seams: `sendRefundOnce`, `mergeRefundOutcome`, `payerAccountOf`, `transferRefund({destination})` and a `RefundSubjectHandler` registered in `liveRefundSubjects()` (Decision 8). **Overlap with #200 (parallel):** both edit `handle_transfer.ts`, `booking_payment_paths.ts`, `payment_sweeps.ts`, `event_payments.ts`, `http/payment_webhook.ts`, `callables/payment.ts`, `infra/live_booking.ts`, `infra/live_event.ts`; whichever lands second rebases. If #200 lands first and tickets already pay by bank QR, Task 3 also binds `PAYMENT_SECRETS` on `cancelEvent` and `eventClock` (ticket refunds can then be `bank_transfer`) and ledgers it.

**Unblocks:** #141 S22 (hard: Decisions 5–7 build on `awaiting_account`, `Payment.payer`, `refundedAmount`, `awaitingRefundsDue`); #142 S18 (`dispatchDisputeRefund` switches to `sendRefundOnce` + `mergeRefundOutcome`); #140 S13–S14 (`InstantPaymentSettler.dispatchRefund`, re-send of its refunds).

**Owns (others consume):** `RefundMethod`, `REFUND_METHODS`, `refundMethodOf`, `StoredBankAccount`, `RefundDestination`, `PayerBankAccount`, refund status `awaiting_account`, `Payment.payer`, `Payment.refundedAmount`, `Refund.method`/`destination`/`confirmBy`/`attempts`/`lastAttemptAt`/`failureReason`, `payerAccountOf`, `revealDestination`, `sendRefundOnce`, `mergeRefundOutcome`, `RefundSendDeps`, `REFUND_RESEND_AFTER_MINUTES`, `REFUND_MAX_ATTEMPTS`, `RefundSubjectHandler`, `RefundSubjects`, `bookingRefundHandler`, `ticketRefundHandler`, `resendPendingRefunds`, `RefundEvent`, `applyRefundEvent`, `BookingDeps.cipher`, `EventPaymentDeps.cipher`, `BookingTx.getRefund`, `BookingStore.getRefund`/`findPendingRefunds`/`awaitingRefundsDue`; Functions `lazyAccountCipher`, `liveAccountCipher`, `liveRefundSubjects`, `PAYMENT_SECRETS`, `FAKE_PAYER`, `PaymentClockExtras`.

## Contract with existing code

Checked 2026-10-08 on `develop` 4e25834. Every task's Step 1 re-checks the part it touches (V1 may have merged meanwhile); adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- **Domain (`packages/domain/src`)**
  - `escrow.ts`: `PAYMENT_METHODS`, `PaymentMethod`, `PaymentSubject = 'booking' | 'event_registration'`, `Payment` (`method?`, `transferCode?`, `expiresAt?`, `receivedAmount?`; no `payer`, no `refundedAmount`), `REFUND_STATUSES = ['pending','done','failed']`, `Refund` (`fromEscrow`, `reason?`, `providerRef?`, `subjectType?`; no `method`/`destination`/`attempts`), `isEscrowRefund`, `escrowRefundedTotal`, `applyRefundToPayment({payment, refundId, percent, ledgerEntryId, reason?, now})` → `{payment, refund, ledgerEntry}` (refund `pending`, `fromEscrow: true`), `verifyPaymentLedgerInvariant(payment, refunds, entries)`.
  - `refunds.ts`: `PAYMENT_REFUND_REASONS`, `transferRefund({payment, refundId, ledgerEntryId, amount, reason, providerRef?, now})` → `{refund, ledgerEntry}` (does not change the payment); private `recordDispatch` (writes `done` or `failed` + `manual` with `tx.addRefund`, no re-read; sets `booking.depositRefundedAt` once when an escrow refund of a booking is `done`); `dispatchRefund(deps, refund, provider)` (a gateway throw propagates); `dispatchRefunds(deps, items)` (a throw → `failed` + `manual`, #129 Ruling 7).
  - `booking_ports.ts`: `TransferNotification.payer?: {bankCode?, accountMasked?, name?}`; `PaymentGateway.issueRefund({paymentId, refundId, amount, provider, providerRef?})` → `{success, providerRef?, error?}`; `BookingTx` (no `getRefund`); `BookingStore` (`getRefundsForPayment`, no single-refund read, no refund queries); `BookingDeps {store, services, providers, contacts, gateway, clock, ids}`.
  - `handle_transfer.ts`: private `applyTransfer(tx, deps, payment, booking, n, now)` (refunds via `transferRefund` with `providerRef: n.txnId`; the `refund` case does not write the payment), `handleTransferNotification`, `checkPayment`, `transferRecordId`.
  - `booking_payment_paths.ts` (internal): `markPaid`, `paymentReceivedEntry`, `moveDraftToRequested`, `refundLatePayment` (`applyRefundToPayment` 100%), `expireOpenPayment` (writes `expired` first, then `transferRefund` `underpaid_expired`).
  - `create_payment.ts` and `payment_sweeps.ts` call `dispatchRefunds`; `commit_transition.ts` calls `dispatchRefund` after its transaction; `runPaymentSweeps(deps)` → `PaymentSweepResults {reconciled, expired, refunded, reconcileFailed, expireFailed}`.
  - `event_payments.ts`: private `dispatchTicketRefund(deps, refund, payment)` (throw → `failed`; writes only while the stored refund is `pending`; mirrors `refundStatus` on the registration), exported `resendTicketRefund`, `TICKET_REFUND_RESEND_AFTER_MINUTES = 10`, `refundTicket`, `handleTicketPayment`. `event_ports.ts`: `EventTx.getRefund`/`putRefund`/`getPayment`/`getRegistration`/`putRegistration`, `EventStore.pendingTicketRefunds(before, limit)`, `EventPaymentDeps extends EventDeps { gateway }`, `RegistrationDoc.refundStatus?: RefundStatus | null`. `event_sweeps.ts`: `runEventSweeps(deps: EventDeps & {gateway?}, onError)` with steps `close | complete | consent | refund | refund_resend` → `{closed, completed, consentExpired, refunded, refundsResent}`.
  - `payout_ports.ts`: `AccountCipher {encrypt(plain), decrypt(enc)}`. `payout_account.ts`: `normalizeAccountNumber`, `normalizeHolderName`, `accountLast4`. `vn_banks.ts`: `bankByCode(code)` → `VnBank {code, bin, shortName, name}`.
  - `fake_payment_gateway.ts` `FakePaymentGateway`: `issuedRefunds`, `refundCalls`, `refundFailureId`, `refundThrowCount`, `pushTransfer`. `memory_booking_store.ts` (`refunds` map). Tests: `test/support/booking_world.ts` (`createBookingWorld`, `transferOf` without `payer`, `payDraft`), `test/escrow_refunds.test.ts` (`manualRefund` literal), and the Ruling 7 tests that expect `failed` + `manual` on a throw: `handle_transfer.test.ts:346`, `payment_sweeps.test.ts:180`, `create_payment.test.ts:295`, `escrow_refunds.test.ts:212`, `event_payments.test.ts:296` and `:408`.
- **Functions (`app_flutter/firebase/functions`)**
  - `src/infra/account_cipher.ts`: `aesGcmCipher(keyB64)`, `encryptSyncForSeed`. `src/infra/live_payout.ts` builds its own lazy cipher. `src/config.ts`: `PAYOUT_ACCOUNT_KEY = defineSecret(...)` (declared after `PAYMENT_CALLABLE_OPTIONS`/`WEBHOOK_OPTIONS`), `PAYMENT_CALLABLE_OPTIONS`, `WEBHOOK_OPTIONS`, `PAYMENT_CLOCK_OPTIONS`, `SCHEDULE_OPTIONS`, `CREATE_PAYOUTS_OPTIONS` (binds the secret). The secret exists in every project (created for S06; `docs/FIREBASE-SETUP.md` §12) and in `.secret.local`.
  - `src/infra/live_booking.ts` `liveBookingDeps()`, `getSharedFakeGateway()`; `src/infra/live_event.ts` `liveEventPaymentDeps()`.
  - `src/infra/booking_firestore.ts`: `paymentToFirestore`/`paymentFromFirestore`, `refundToFirestore`/`refundFromFirestore` (shared with `event_firestore.ts`), `REFUNDS_COLLECTION = 'refunds'` (booking and ticket refunds live in the same collection), `FirestoreBookingStore`. `src/infra/event_firestore.ts` `pendingTicketRefunds` (index `refunds (subjectType, status, createdAt)`).
  - `src/infra/fake_webhook.ts`: `parseFakeTransfer` (payer `bankCode`/`accountMasked`/`name`, `raw` = the body as received), `signFakeWebhook`, `verifyFakeWebhook`. `src/http/payment_webhook.ts`: `handlePaymentWebhook(req, deps, env)`, `servePaymentWebhook`. `src/callables/payment.ts`: `handleConfirmFakePayment` (body without `payer`). `src/scheduled/payment_clock.ts` `handlePaymentClock(deps)`. `src/scheduled/event_clock.ts` `EventClockResults.refundsResent` (#138 Decision 14 kept it). `tools/clock.ts` (`events | bookings`).
  - `src/index.ts`: `createPayment`/`checkPayment`/`confirmFakePayment` (`PAYMENT_CALLABLE_OPTIONS`), `paymentWebhook` (`WEBHOOK_OPTIONS`), `paymentClock` (`PAYMENT_CLOCK_OPTIONS`), `transitionBooking` (`CALLABLE_OPTIONS`), `bookingClock` (`{...SCHEDULE_OPTIONS, timeoutSeconds: 300}`), ticket callables `registerEvent`/`cancelRegistration`/`confirmFakeTicketPayment`/`checkTicketPayment` (`PAYMENT_CALLABLE_OPTIONS`), `cancelEvent`, `eventClock`.
  - `seed/fixtures.ts`: seed booking payments are `bank_qr` without a payer; the cancelled booking's refund has `status: 'completed'` (not a `RefundStatus`).
  - Tests: `test/unit/support/payment_world.ts` (`paymentWorld()` builds `BookingDeps`), `payment_clock.test.ts`, `payment_webhook.test.ts`, `payment_callables.test.ts`, `booking_firestore.test.ts` (shared round-trips), `event_clock.test.ts`, `event_firestore.test.ts`, `clock_cli.test.ts`, `config.test.ts`, `booking_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `event_payment_callables.test.ts`.
- **App:** `lib/data/events/event_registration.dart` `TicketRefundStatus {pending, done, failed}` with `code => name` and `fromCode` (unknown → null); `tickets_tab.dart` shows "Đang hoàn" unless the status is null or `done`. No booking refund status is shown in the app.

## Global Constraints

- Spec §5: a bank-QR refund is a payout "về tài khoản đã chuyển (số tài khoản, tên, ngân hàng lấy từ webhook)"; "Thiếu thông tin người chuyển → bắt buộc khai tài khoản" (here: `awaiting_account`; the form is #141's S22.04). Wallet refunds use the wallet's refund API. `Refund.method` ∈ `gateway` | `bank_transfer`.
- Spec §9 and #129: every outgoing call carries an idempotency key; for refunds it is the refund id (`issueRefund.refundId`), so sending a refund again never pays twice.
- The plain account number is never stored, logged or returned: encrypted with `AccountCipher` (AES-256-GCM, key `PAYOUT_ACCOUNT_KEY`), shown only as `accountLast4`; it exists in plain form only in the webhook request and in the one `issueRefund` call. Logs carry ids, counts and outcome codes only.
- Money rules (CLAUDE.md, do not weaken): the refund policy and amounts do not change here; escrow math still reads `escrowRefundedTotal` (`fromEscrow`), never `refundedAmount`.
- CLAUDE.md: business rules only in `packages/domain` (no Firebase or Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; domain ids/instants/money per `data-model/README.md` (opaque ids, UTC ISO strings, integer VND, string enum codes); Dart imports `package:photobooking/...`.
- Code comments, docs and config written by this plan never link to `docs/superpowers/` (that folder does not ship); state the fact inline.
- Commands: domain `(cd packages/domain && npm test && npm run lint && npm run typecheck)`; Functions `(cd app_flutter/firebase/functions && npm test && npm run build)`; Flutter from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`: `flutter test --no-pub --timeout 60s <file>`, `flutter analyze`.
- Commits: Conventional Commits, subject ends with `[#201]`, body ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (owner's rule; never the Claude line).

## Decisions

1. **Not blocked by V1.** See "Blocked by". The refund registry (Decision 8) is the one seam V1 needs that the old plan put inside `SettlementDeps.subjects`; here it is separate so V2 ships alone. V1's `SubjectSettler.dispatchRefund` is written as `sendRefundOnce` + its own transaction with `mergeRefundOutcome`, exactly as the consumers quote.
2. **Payer capture.** The payer is the sender of the **first transfer that counts toward the payment** (`partial` or `paid`); later senders never replace it. `payerAccountOf` builds it only from a complete payer: `bankCode` (any non-empty code; `bankName` = `bankByCode(code)?.shortName ?? code`), `accountNumber` passing `normalizeAccountNumber`, `name` passing `normalizeHolderName`; anything less → no payer. It encrypts before the transaction; an encrypt failure makes the whole notification fail (webhook 500, provider retries), never a silent payment without payer. A refunded transfer (late or extra) does not set `payment.payer`.
3. **Where a refund goes.** `method = refundMethodOf(payment.method)`: `bank_qr` → `bank_transfer`; wallets, tickets and older payments without a method → `gateway`. Destination for `bank_transfer`: a transfer refund (`fromEscrow: false`) goes to the sender of the transfer being refunded (`overpaid_excess`, `late_transfer`, `extra_transfer`), falling back to `payment.payer`; `underpaid_expired` and every escrow refund go to `payment.payer` (when two senders paid parts, the sum goes to the first; Needs the owner 1). `source = 'payer'` (#141 adds `'customer'`). No destination → `awaiting_account`: not sent, not re-sent, `lastAttemptAt` absent, `depositRefundedAt` not set; #141 moves it on. `gateway` refunds never wait.
4. **`Payment.refundedAmount`** = Σ `amount` of every refund record of the payment (any status, any `fromEscrow`), written in the same transaction that adds the refund. Payments written before V2 have no field. `verifyPaymentLedgerInvariant` also checks it when present. Release, payouts and earnings keep using `escrowRefundedTotal`.
5. **Dispatch rule (replaces #129 Ruling 7 and the ticket rule).** `sendRefundOnce` makes at most one gateway call and never throws: only a `pending` refund is sent; `success` → `done`; `success` + `pending: true` (an asynchronous provider) → stays `pending` with `providerRef`, `attempts + 1`; `success: false` → `failed`, `manual`, `failureReason = error ?? 'gateway_refused'`; a throw (or a decrypt failure) → stays `pending`, `attempts + 1`, `lastAttemptAt = now`, unless that was the `REFUND_MAX_ATTEMPTS`-th (6th) call, then `failed`, `manual`, `failureReason 'gateway_unavailable'` (staff, S23.03). A `pending` `bank_transfer` refund without a destination never calls the gateway: `failed`, `manual`, `'no_destination'`. `dispatchRefund` therefore no longer throws for gateway errors.
6. **Storing an outcome.** Every writer re-reads the refund in its transaction and writes `mergeRefundOutcome(stored, next)` only when it is not null: a `done` refund never changes; an `awaiting_account` refund is never changed by an outcome; a `failed` refund changes only to `done` (a late provider confirmation); only outcome fields are copied (`status`, `manual`, `providerRef`, `failureReason`, `attempts` = max of both, `lastAttemptAt`, `updatedAt`), so fields other plans add (`destination`, `confirmBy`, #141's `candidate`) survive.
7. **Re-send under the same id in the payment clock.** A refund gets `lastAttemptAt = createdAt` when it is created `pending` and `lastAttemptAt = now` on every send. `runPaymentSweeps` gains the named last step `resend`: refunds with `status == 'pending'` and `lastAttemptAt <= now − REFUND_RESEND_AFTER_MINUTES` (10), oldest first, ≤ 100 per run, **every subject** (one `refunds` collection), each in its own try/catch. This replaces the event clock's `refund_resend` step: `resendTicketRefund`, `TICKET_REFUND_RESEND_AFTER_MINUTES`, `EventStore.pendingTicketRefunds` and `refundsResent` in `runEventSweeps`/`EventClockResults` are removed (#138 Decision 14 kept `refundsResent` only until this unit). Pending refunds stored before V2 have no `lastAttemptAt` and are not re-sent (dev data; ledger).
8. **`RefundSubjects`.** `RefundSubjectHandler {resend(refund), record(next)}` keyed by `PaymentSubject`. Booking is built in (`bookingRefundHandler(deps)`, used when `subjectType` is `booking` or absent); tickets register `ticketRefundHandler(liveEventPaymentDeps())` in `liveRefundSubjects()`; V1/#140 register theirs there (`resend` = their settler's `dispatchRefund`, `record` = a transaction applying `mergeRefundOutcome` and their mirror). A refund whose subject has no handler is skipped by the re-send (counted in `resendSkipped`, logged as a count) and answered `refund_unknown` by `applyRefundEvent`.
9. **Refund webhook on the existing endpoint.** `paymentWebhook?provider=fake` accepts a second body type `{"type":"refund","refundId","status":"done"|"failed","providerRef"?,"failureReason"?}` with the same signature; a body without `type` (or `"transfer"`) is a transfer as today. `applyRefundEvent` is idempotent by Decision 6; no `payment_notifications` record (the refund document holds the outcome; logs carry `refundId` and the outcome). An unknown refund id, or a provider that differs from the payment's, → 200 `{ok:true, outcome:'refund_unknown'}` (no retry storm). The real intermediary's event format comes with its adapter.
10. **Gateway port.** `issueRefund` params gain `method: RefundMethod` and `destination?: PayerBankAccount` (plain, decrypted by `sendRefundOnce` just before the call, never kept); the result gains `pending?: boolean`. The fake records the last request per refund id (`refundRequests`) and answers `pending` for ids in `refundPendingIds`.
11. **Cipher wiring and secrets.** `BookingDeps.cipher` and `EventPaymentDeps.cipher` are required. Live: one lazy cipher reading `PAYOUT_ACCOUNT_KEY` on first use (`liveAccountCipher()`), so functions that never touch an account never read the secret. `PAYMENT_SECRETS = [PAYOUT_ACCOUNT_KEY]` is bound wherever a transfer can be captured or a `bank_transfer` refund sent: `PAYMENT_CALLABLE_OPTIONS` (booking `createPayment`, `checkPayment`, `confirmFakePayment`, and the ticket callables that share the options), `WEBHOOK_OPTIONS`, `PAYMENT_CLOCK_OPTIONS`, new `BOOKING_REFUND_CALLABLE_OPTIONS` (`transitionBooking`: cancel/decline refunds) and new `BOOKING_CLOCK_OPTIONS` (`bookingClock`: expired requests are refunded). `cancelEvent` and `eventClock` do not need it while tickets refund through the gateway.
12. **Plain number never stored.** The fake webhook's `payer.accountNumber` is verified with the raw bytes, then `raw` on `payment_notifications` is the body with `payer.accountNumber` replaced by `"•••• " + last 4` (re-serialised JSON). `TransferNotification.payer.accountNumber` lives only in memory.
13. **`confirmBy` and `awaitingRefundsDue` belong here, the 24-hour rule to #141.** V2 adds `Refund.confirmBy?: string | null` (never set by V2), the query `awaitingRefundsDue(now, limit)` (`status == 'awaiting_account' && confirmBy <= now`, oldest first) and its index; #141 sets `confirmBy` and runs `confirmDueRefundAccounts` after the `resend` step.
14. **Fake and seed data carry a payer.** `confirmFakePayment` bodies include `FAKE_PAYER` (`bankCode 'VCB'`, `accountNumber '0071000123456'`, `name 'KHACH THU NGHIEM'`; test values), so dev refunds are sent, not left waiting. Seed `bank_qr` payments get an encrypted payer (`encryptSyncForSeed` with the emulator key) and `refundedAmount`; the cancelled seed refund becomes `status 'done'`, `method 'bank_transfer'`, destination = that payer.
15. **App.** Only `TicketRefundStatus.awaitingAccount` (code `awaiting_account`, read as "Đang hoàn" by the existing rule) so #141's ticket waits are not shown as refunded. S22.01/S22.04 and booking mirrors are #141.

## Needs the owner (defaults applied)

1. A payment paid in parts from two different accounts that then expires or is cancelled: default one refund of the sum to the first sender (Decision 3). Alternative: one refund per sender (more refunds, per-transfer bookkeeping).
2. A gateway that keeps throwing: default 6 calls (about an hour at one re-send per 10 minutes) and then staff (`failed` + `manual`). Alternative: re-send forever.

## Contract

### Firestore (server-only; rules unchanged)

- `payments/{id}` gains `payer: {bankCode, bankName, accountNumberEnc, accountLast4, holderName} | null` and `refundedAmount: int | null`.
- `refunds/{id}`: `status` adds `awaiting_account`; gains `method: 'gateway' | 'bank_transfer'` (missing → `gateway`), `destination: {bankCode, bankName, accountNumberEnc, accountLast4, holderName, source: 'payer' | 'customer'} | null`, `confirmBy: Timestamp | null`, `attempts: int` (missing → 0), `lastAttemptAt: Timestamp | null`, `failureReason: string | null`.
- `payment_notifications/{id}.raw`: `payer.accountNumber` redacted (Decision 12).
- `firestore.indexes.json`: add `refunds (status ASC, lastAttemptAt ASC)` and `refunds (status ASC, confirmBy ASC)`; remove `refunds (subjectType ASC, status ASC, createdAt ASC)` once a grep shows no query uses it.

### Domain (`packages/domain/src`)

```ts
// escrow.ts
export const REFUND_STATUSES = ['awaiting_account', 'pending', 'done', 'failed'] as const;
export const REFUND_METHODS = ['gateway', 'bank_transfer'] as const;
export type RefundMethod = (typeof REFUND_METHODS)[number];
/** bank_qr → bank_transfer; momo, zalopay, undefined (tickets, older payments) → gateway. */
export function refundMethodOf(method: PaymentMethod | undefined): RefundMethod;
/** A bank account as the server keeps it: number encrypted (AccountCipher), last 4 and names for display. */
export interface StoredBankAccount {
  readonly bankCode: string;          // VN_BANKS code, e.g. 'VCB'
  readonly bankName: string;          // VnBank.shortName ('Vietcombank'), or the code when unknown
  readonly accountNumberEnc: string;
  readonly accountLast4: string;
  readonly holderName: string;        // normalizeHolderName form, e.g. 'NGUYEN THANH HA'
}
export type RefundDestination = StoredBankAccount & { readonly source: 'payer' | 'customer' };
// Payment gains:  readonly payer?: StoredBankAccount | null;  readonly refundedAmount?: number;
// Refund gains:   readonly method: RefundMethod;  readonly destination?: RefundDestination | null;
//                 readonly confirmBy?: string | null;  readonly attempts: number;
//                 readonly lastAttemptAt?: string;  readonly failureReason?: string;
// applyRefundToPayment: same params; refund method/destination per Decision 3 (destination = payment.payer),
//   status awaiting_account when bank_transfer without payer, else pending with attempts 0, lastAttemptAt = now;
//   returned payment.refundedAmount = (payment.refundedAmount ?? 0) + refund.amount.

// booking_policy.ts
export const REFUND_RESEND_AFTER_MINUTES = 10;
export const REFUND_MAX_ATTEMPTS = 6;

// booking_ports.ts
// TransferNotification.payer gains: readonly accountNumber?: string   (plain; memory only)
export interface PayerBankAccount { readonly bankCode: string; readonly accountNumber: string; readonly holderName: string }
// PaymentGateway.issueRefund params gain: readonly method: RefundMethod; readonly destination?: PayerBankAccount;
//   result gains: readonly pending?: boolean   (success + pending: accepted, outcome comes later)
// BookingTx gains:    getRefund(id: string): Promise<Refund | null>;
// BookingStore gains: getRefund(id: string): Promise<Refund | null>;
//   /** status pending, lastAttemptAt <= before, any subject, oldest first. */
//   findPendingRefunds(before: Date, limit?: number): Promise<readonly Refund[]>;
//   /** status awaiting_account, confirmBy <= now (rows without confirmBy never), oldest first. */
//   awaitingRefundsDue(now: Date, limit: number): Promise<readonly Refund[]>;
// BookingDeps gains:  readonly cipher: AccountCipher;   (type imported from payout_ports.ts)

// payer_account.ts (new)
/** Decision 2: a complete payer → encrypted StoredBankAccount; anything less → null. */
export async function payerAccountOf(cipher: AccountCipher, payer: TransferNotification['payer']): Promise<StoredBankAccount | null>;
/** The plain account for the one gateway call. */
export async function revealDestination(cipher: AccountCipher, d: StoredBankAccount): Promise<PayerBankAccount>;

// refunds.ts
// transferRefund params gain: readonly destination?: StoredBankAccount | null   (Decision 3)
//   returns { refund, ledgerEntry, payment }   (payment = input with refundedAmount + amount; status unchanged)
export interface RefundSendDeps { readonly gateway: PaymentGateway; readonly cipher: AccountCipher; readonly clock: Clock }
/** Decision 5. At most one gateway call under refund.id; never throws; non-pending → returned unchanged, no call. */
export async function sendRefundOnce(d: RefundSendDeps, refund: Refund, payment: Pick<Payment, 'id' | 'provider'>): Promise<Refund>;
/** Decision 6. What to store after an outcome; null = leave the stored refund as it is. */
export function mergeRefundOutcome(stored: Refund, next: Refund): Refund | null;
// dispatchRefund(deps, refund, provider) and dispatchRefunds(deps, items): signatures unchanged; both are now
//   sendRefundOnce + bookingRefundHandler(deps).record(next); gateway errors never throw.

// refund_subjects.ts (new)
export interface RefundSubjectHandler {
  /** Sends a pending refund again under its id and stores the outcome in the subject's own transaction. */
  resend(refund: Refund): Promise<Refund>;
  /** Stores an outcome (mergeRefundOutcome + the subject's mirrors); null when nothing changed. */
  record(next: Refund): Promise<Refund | null>;
}
export type RefundSubjects = Readonly<Partial<Record<PaymentSubject, RefundSubjectHandler>>>;
/** Booking refunds: record re-reads the refund in a BookingTx, merges, and sets booking.depositRefundedAt once
 *  when an escrow refund becomes done (the rule refunds.ts has today). */
export function bookingRefundHandler(deps: BookingDeps): RefundSubjectHandler;
export async function resendPendingRefunds(deps: BookingDeps, subjects: RefundSubjects, limit?: number /* 100 */):
  Promise<{ readonly resent: number; readonly skipped: number; readonly failed: number }>;
export interface RefundEvent {
  readonly provider: PaymentProvider; readonly refundId: string; readonly status: 'done' | 'failed';
  readonly providerRef?: string; readonly failureReason?: string;
}
export async function applyRefundEvent(deps: BookingDeps, e: RefundEvent, subjects?: RefundSubjects):
  Promise<'refund_applied' | 'refund_unknown'>;

// payment_sweeps.ts
export interface PaymentSweepExtras { readonly refundSubjects?: RefundSubjects }
export async function runPaymentSweeps(deps: BookingDeps, extras?: PaymentSweepExtras): Promise<PaymentSweepResults>;
// PaymentSweepResults gains: refundsResent, resendSkipped, resendFailed   (step 'resend', last; #141 appends after it)

// event_payments.ts / event_ports.ts / event_sweeps.ts
// EventPaymentDeps gains: readonly cipher: AccountCipher
export function ticketRefundHandler(deps: EventPaymentDeps): RefundSubjectHandler; // record mirrors registration.refundStatus
// removed: resendTicketRefund, TICKET_REFUND_RESEND_AFTER_MINUTES, EventStore.pendingTicketRefunds,
//   EventSweepStep 'refund_resend', runEventSweeps result field refundsResent
// runEventSweeps(deps: EventDeps & Partial<Pick<EventPaymentDeps, 'gateway' | 'cipher'>>, onError)  (refund step needs both)

// fake_payment_gateway.ts
// FakePaymentGateway gains: readonly refundRequests: Map<string, { method: RefundMethod; destination?: PayerBankAccount }>;
//   readonly refundPendingIds: Set<string>;   (answer { success: true, pending: true, providerRef })
```

`sendRefundOnce` (the part easy to get wrong):

```ts
export async function sendRefundOnce(d: RefundSendDeps, refund: Refund, payment: Pick<Payment, 'id' | 'provider'>): Promise<Refund> {
  if (refund.status !== 'pending') return refund;
  const at = d.clock.now().toISOString();
  const attempts = refund.attempts + 1;
  const stop = (failureReason: string, n = attempts): Refund => ({ ...refund, status: 'failed', manual: true, failureReason, attempts: n, lastAttemptAt: at, updatedAt: at });
  if (refund.method === 'bank_transfer' && !refund.destination) return stop('no_destination', refund.attempts); // no call made
  let result: Awaited<ReturnType<PaymentGateway['issueRefund']>>;
  try {
    const destination = refund.method === 'bank_transfer' && refund.destination
      ? await revealDestination(d.cipher, refund.destination) : undefined;
    result = await d.gateway.issueRefund({
      paymentId: payment.id, refundId: refund.id, amount: refund.amount, provider: payment.provider,
      providerRef: refund.providerRef, method: refund.method, ...(destination ? { destination } : {}),
    });
  } catch {
    if (attempts >= REFUND_MAX_ATTEMPTS) return stop('gateway_unavailable');
    return { ...refund, attempts, lastAttemptAt: at, updatedAt: at };
  }
  if (!result.success) return stop(result.error ?? 'gateway_refused');
  const providerRef = result.providerRef ?? refund.providerRef;
  if (result.pending) return { ...refund, providerRef, attempts, lastAttemptAt: at, updatedAt: at };
  return { ...refund, status: 'done', manual: false, providerRef, attempts, lastAttemptAt: at, updatedAt: at };
}
```

### Functions (`app_flutter/firebase/functions/src`)

```ts
// infra/account_cipher.ts
export function lazyAccountCipher(readKey: () => string): AccountCipher; // aesGcmCipher(readKey()) built on first use
// infra/live_booking.ts
export function liveAccountCipher(): AccountCipher; // lazyAccountCipher(() => PAYOUT_ACCOUNT_KEY.value())
// liveBookingDeps() gains cipher: liveAccountCipher(); live_event.ts liveEventPaymentDeps() too; live_payout.ts reuses lazyAccountCipher
// infra/live_refunds.ts (new)
export function liveRefundSubjects(): RefundSubjects; // { event_registration: ticketRefundHandler(liveEventPaymentDeps()) }
// config.ts (PAYOUT_ACCOUNT_KEY moves above the option objects)
export const PAYMENT_SECRETS = [PAYOUT_ACCOUNT_KEY];
// PAYMENT_CALLABLE_OPTIONS, WEBHOOK_OPTIONS, PAYMENT_CLOCK_OPTIONS gain secrets: PAYMENT_SECRETS
export const BOOKING_REFUND_CALLABLE_OPTIONS = { ...CALLABLE_OPTIONS, secrets: PAYMENT_SECRETS } as const satisfies CallableOptions;
export const BOOKING_CLOCK_OPTIONS = { ...SCHEDULE_OPTIONS, timeoutSeconds: 300, secrets: PAYMENT_SECRETS } as const satisfies ScheduleOptions;
// infra/fake_webhook.ts
export const FAKE_PAYER = { bankCode: 'VCB', accountNumber: '0071000123456', name: 'KHACH THU NGHIEM' } as const; // test values
export type FakeWebhookBody = { readonly kind: 'transfer'; readonly transfer: TransferNotification } | { readonly kind: 'refund'; readonly event: RefundEvent };
export function parseFakeWebhook(rawBody: string): FakeWebhookBody; // DomainError('invalid_argument') on any other shape
// parseFakeTransfer stays (transfer bodies only); payer.accountNumber: string ≤ 32 chars; raw redacted (Decision 12)
// http/payment_webhook.ts
export async function handlePaymentWebhook(req: WebhookRequest, deps: BookingDeps, env?: Env, refundSubjects?: RefundSubjects): Promise<WebhookResponse>;
// refund body → applyRefundEvent → 200 {ok:true, outcome}; log 'paymentWebhook handled' {provider, refundId, outcome}
// scheduled/payment_clock.ts
export interface PaymentClockExtras { readonly refundSubjects?: RefundSubjects } // default liveRefundSubjects()
export async function handlePaymentClock(deps?: BookingDeps, extras?: PaymentClockExtras): Promise<PaymentSweepResults>;
// tools/clock.ts: command `payments` → handlePaymentClock(); USAGE 'usage: npm run clock -- events | bookings | payments   (local emulators only)'
```

### App (`app_flutter/lib`)

`TicketRefundStatus {pending('pending'), awaitingAccount('awaiting_account'), done('done'), failed('failed')}` with a `code` field; `fromCode` matches `code`.

## Review Focus

1. **Two senders of one refund at once** (the inline dispatch right after a cancel and the clock's re-send, or a provider's `done` event arriving before the dispatch stores its `pending` answer): one refund id at the provider, and the stored refund ends `done`, never back to `pending` or `failed`. Pin: Task 2 `a refund event done before the dispatch answer is stored stays done`; Task 3 `the re-send racing an inline dispatch pays once and ends done`.
2. **The plain account number leaks** into `payments`, `refunds`, `payment_notifications.raw`, a log line or a callable answer. Pin: Task 2 `the plain number is nowhere in the store after capture, refund and dispatch`; Task 4 `the stored raw body has the account number redacted` and `webhook logs never contain the payer`.
3. **A late or extra transfer from someone else's account**: that money goes back to that account, and the payment's payer (where cancel refunds go) stays the first sender. Pin: Task 2 `a late transfer from another account is refunded to it and payment.payer is unchanged`.
4. **The gateway is down for a long time**: refunds stay `pending`, are re-sent every 10 minutes under the same id, and after the 6th failed call go to staff; never a second refund id, never a crash of the clock. Pin: Task 1 `the 6th throw is failed, manual, gateway_unavailable`; Task 3 `a refund that keeps throwing is re-sent until it goes to staff`.
5. **No payer known** (a dev payment from before V2, or a provider that sends no account): the cancel refund waits in `awaiting_account`, is not sent, not re-sent and the booking is not marked refunded. Pin: Task 2 `no payer: the cancel refund is awaiting_account, not sent, depositRefundedAt unset`; Task 3 `awaiting_account and failed refunds are never re-sent`.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore nam5 upper bound $0.06/100K reads, $0.18/100K writes (Singapore **chưa xác nhận**); Secret Manager $0.03/10,000 accesses after 10,000 free per month, $0.06 per active version (the existing `PAYOUT_ACCOUNT_KEY` version, no new one). **Functions (one rule for every plan, cost spec §12):** at (b) 1,000 MAU new invocations and CPU fit the free tier → $0; at (c) 10,000 MAU the app already uses the free tier up, so extra work is charged at Tier 2 ($0.40/M invocations, $0.0000336/vCPU-s). Assumptions: 300 bookings/month at (b), 3,000 at (c); 15% of paid bookings refunded (cancel, decline, expiry); 5% of transfers are over/late/extra.

- **Per user action.** Pay by transfer: payer capture rides in the existing payment write (+0). A late or extra transfer: +1 payment write (`refundedAmount`). Each refund dispatch: +1 read (the transaction now re-reads the refund before writing). A refund event from the provider: 1 invocation, ≈ 3 reads (refund, payment, booking), ≤ 2 writes.
- **Scheduled jobs.** No new job. The payment clock adds one `findPendingRefunds` query per run (8,640 runs/month, ≥ 1 read each ≈ 8,640 reads); the event clock loses its `pendingTicketRefunds` query (same count): net 0. Re-sent refunds are rare (gateway outages): ≈ 3 reads, 1 write each.
- **Secret Manager.** The functions that newly bind `PAYOUT_ACCOUNT_KEY` read it once per instance start: a few thousand accesses/month at (b) and (c), inside the 10,000 free.
- **Monthly totals.** (b): reads ≈ 45 (dispatch re-reads) + 50 (events) ≈ 100 → < $0.001; writes ≈ 30 → < $0.001; **≈ +$0.00/month**. (c): ≈ 1,000 reads, 300 writes, ≈ 500 invocations → **≈ +$0.01/month**. Below $5; no mitigation needed.

## Tasks

### Task 1: Domain — refund model, payer account, `sendRefundOnce`, `mergeRefundOutcome`

**Files:**
- Create: `packages/domain/src/payer_account.ts`, `packages/domain/test/payer_account.test.ts`, `packages/domain/test/refund_send.test.ts`, `packages/domain/test/support/test_cipher.ts`
- Modify: `packages/domain/src/escrow.ts`, `refunds.ts`, `booking_ports.ts`, `booking_policy.ts`, `fake_payment_gateway.ts`, `index.ts`, `event_payments.ts` (its direct `issueRefund` call passes `method`), `packages/domain/test/escrow.test.ts`, `escrow_refunds.test.ts` (`manualRefund` gains `method: 'gateway'`, `attempts: 0`), `booking_policy.test.ts` (constants)

**Interfaces:**
- Produces: everything under `escrow.ts`, `booking_policy.ts`, `booking_ports.ts` (types only: `TransferNotification.payer.accountNumber`, `PayerBankAccount`, `issueRefund` params/result), `payer_account.ts`, `RefundSendDeps`/`sendRefundOnce`/`mergeRefundOutcome` and `FakePaymentGateway` in the Contract. `test/support/test_cipher.ts`: `export const TEST_CIPHER: AccountCipher` = `'enc:' +` the reversed plain text (so the plain number never appears as a substring), `decrypt` reverses it, any other input throws.
- This task does not change flows yet: `applyRefundToPayment` and `transferRefund` set `method: refundMethodOf(payment.method)`, `attempts: 0`, `lastAttemptAt: at`, status `pending` as before; destination, `awaiting_account` and `refundedAmount` come in Task 2. The two direct `issueRefund` callers (`refunds.ts`, `event_payments.ts`) pass `method: refund.method` until Tasks 2–3 replace them.

- [ ] **Step 1: Contract check** of `escrow.ts`, `refunds.ts`, `booking_ports.ts`, `payout_ports.ts` (`AccountCipher`), `payout_account.ts`, `vn_banks.ts`, `fake_payment_gateway.ts`; `grep -rn "status: 'pending'\|REFUND_STATUSES\|issueRefund" packages/domain` to find every refund literal and reader; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `escrow.test.ts`: `REFUND_STATUSES lists awaiting_account, pending, done, failed`; `refundMethodOf: bank_qr → bank_transfer; momo, zalopay, undefined → gateway`; `applyRefundToPayment sets method from the payment, attempts 0 and lastAttemptAt now`; `verifyPaymentLedgerInvariant fails when refundedAmount is present and differs from the sum of refunds` and `passes when it is absent`.
  - `payer_account.test.ts`: `a complete payer becomes a StoredBankAccount` (`{bankCode: 'VCB', accountNumber: '0071 000 123 456', name: 'Nguyễn Thanh Hà'}` → `bankName 'Vietcombank'`, `accountLast4 '3456'`, `holderName 'NGUYEN THANH HA'`, `accountNumberEnc` decrypts with `TEST_CIPHER` to `'0071000123456'` and does not contain it); `an unknown bank code keeps the code as bank name`; `no number, a bad number, no name, a bad name or no bank code → null`; `undefined payer → null`; `revealDestination returns bankCode, the plain number and holderName`.
  - `refund_send.test.ts` (`sendRefundOnce` with `FakePaymentGateway`, `TEST_CIPHER`, a fixed clock):
    - `a pending gateway refund is done with the provider ref, attempts 1, lastAttemptAt now`;
    - `a bank_transfer refund sends method and the decrypted destination` (`refundRequests.get(id)` = `{method: 'bank_transfer', destination: {bankCode: 'VCB', accountNumber: '0071000123456', holderName: 'NGUYEN THANH HA'}}`);
    - `an answer pending keeps the refund pending with providerRef and attempts + 1`;
    - `success false is failed, manual, failureReason from the gateway error`;
    - `a throw keeps it pending with attempts + 1 and lastAttemptAt now, and does not throw`;
    - `a decrypt failure is handled like a throw`;
    - `the 6th throw is failed, manual, gateway_unavailable` (start with `attempts: 5`; Review Focus 4);
    - `awaiting_account, done and failed refunds are returned unchanged without a gateway call` (`refundCalls` empty);
    - `a pending bank_transfer refund without destination is failed, manual, no_destination, without a call`;
    - `sending the same refund twice reaches the gateway under one id` (`issuedRefunds.size === 1`).
  - `refund_send.test.ts` (`mergeRefundOutcome`): `null when the stored refund is done`; `null when the stored refund is awaiting_account`; `a failed refund accepts done and nothing else`; `pending accepts pending, done and failed`; `only outcome fields are copied` (stored `destination`, `confirmBy` and an extra field survive; `next.amount` changed is ignored); `attempts is the larger of the two`.
- [ ] **Step 3:** Run `(cd packages/domain && npm test)`; the new tests fail.
- [ ] **Step 4: Implement** per the Contract and the `sendRefundOnce` sample. `payerAccountOf` uses `normalizeAccountNumber`, `normalizeHolderName`, `accountLast4`, `bankByCode`. Export the new names from `index.ts`.
- [ ] **Step 5:** `(cd packages/domain && npm test && npm run lint && npm run typecheck)` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): refund method, payer account and one-shot refund send [#201]`.

### Task 2: Domain — payer capture, refund destination and the booking dispatch

**Files:**
- Create: `packages/domain/src/refund_subjects.ts` (only `RefundSubjectHandler`, `RefundSubjects`, `bookingRefundHandler` in this task), `packages/domain/test/refund_destination.test.ts`
- Modify: `packages/domain/src/booking_ports.ts` (`BookingTx.getRefund`, `BookingStore.getRefund`/`findPendingRefunds`/`awaitingRefundsDue`, `BookingDeps.cipher`), `memory_booking_store.ts`, `escrow.ts` (`applyRefundToPayment` routing and `refundedAmount`), `refunds.ts` (`transferRefund` destination + payment; `dispatchRefund`/`dispatchRefunds` = `sendRefundOnce` + `bookingRefundHandler(deps).record`; `recordDispatch` removed), `handle_transfer.ts`, `booking_payment_paths.ts`, `index.ts`, `test/support/booking_world.ts` (`cipher: TEST_CIPHER`; `transferOf` gains `payer?: TransferNotification['payer'] | null`, default `TEST_PAYER = {bankCode: 'VCB', accountNumber: '0071000123456', name: 'NGUYEN THANH HA', accountMasked: '•••• 3456'}`, `null` → no payer), and the Ruling 7 tests listed in the Contract (`handle_transfer.test.ts`, `payment_sweeps.test.ts`, `create_payment.test.ts`, `escrow_refunds.test.ts`: a throw now leaves `pending`, `attempts 1`, `manual false`)

**Interfaces:**
- Consumes: Task 1.
- Produces: `BookingDeps.cipher`; the `BookingStore`/`BookingTx` members of the Contract (memory: `findPendingRefunds` filters `status === 'pending' && lastAttemptAt && Date.parse(lastAttemptAt) <= before`, sorted by `lastAttemptAt`; `awaitingRefundsDue` likewise on `confirmBy`); `transferRefund` with `destination` returning `payment`; `bookingRefundHandler(deps)` (`record(next)`: one transaction reading the refund, the payment and, for an escrow refund of a booking becoming `done`, the booking — all reads before writes — then `mergeRefundOutcome`; `resend(refund)`: `sendRefundOnce(deps, refund, payment)` with the payment read from the store, then `record`).
- Flow rules:
  - `handleTransferNotification`: `payerAccountOf(deps.cipher, n.payer)` **before** the transaction; `applyTransfer` threads one `current: Payment` and writes it last: on `partial`/`paid` it sets `payer: current.payer ?? captured` (Decision 2); every refund it creates uses `transferRefund({..., destination: captured ?? current.payer})` for transfer refunds and `applyRefundToPayment` (destination `payer` of the threaded payment) for the late path; `current.refundedAmount` grows with each refund; the `refund` case now writes the payment too.
  - `expireOpenPayment`: one `setPayment` with `status 'expired'`, escrow `refunded` and the new `refundedAmount`; refund destination `payment.payer`.
  - `applyRefundToPayment`: Decision 3 routing (destination `{...payment.payer, source: 'payer'}`; no payer on a `bank_transfer` → `awaiting_account`, no `lastAttemptAt`) and Decision 4 `refundedAmount`.
  - `commit_transition.ts` keeps calling `dispatchRefund`: an `awaiting_account` refund is returned unchanged by `sendRefundOnce` and nothing is written.

- [ ] **Step 1: Contract check** of `handle_transfer.ts` (`applyTransfer` cases), `booking_payment_paths.ts`, `commit_transition.ts`, `create_payment.ts`, `memory_booking_store.ts` (whether it refuses reads after writes in a transaction), `booking_world.ts`; ledger differences.
- [ ] **Step 2: Failing tests** in `refund_destination.test.ts` (with `createBookingWorld`, `payDraft`, `transferOf`, `transitionBooking`):
  - `the first counted transfer stores the payer encrypted with bank name, last 4 and holder`;
  - `a later payer does not replace the first` (under then top-up from another account);
  - `a transfer without a complete payer stores no payer`;
  - `an over-transfer refunds the excess to that transfer's sender: bank_transfer, source payer, pending, done after dispatch`;
  - `a late transfer from another account is refunded to it and payment.payer is unchanged` (pay, then a late transfer with payer `{bankCode: 'TCB', accountNumber: '1903000099998888', name: 'TRAN VAN B'}`; the refund destination is TCB `8888`; Review Focus 3);
  - `an expired under-paid payment refunds what it received to the payer`;
  - `a customer cancel of a bank_qr booking refunds to payment.payer and the gateway gets the plain account`;
  - `a wallet payment's cancel refund is gateway with no destination`;
  - `no payer: the cancel refund is awaiting_account, not sent, depositRefundedAt unset` (pay with `payer: null`, cancel ≥ 48 h before; `refundCalls` empty; Review Focus 5);
  - `refundedAmount equals the sum of refunds after paid_with_refund, refunded, expiry, late-draft and cancel` (one assertion per outcome, and `verifyPaymentLedgerInvariant` holds);
  - `the plain number is nowhere in the store after capture, refund and dispatch` (`JSON.stringify` of every map in `MemoryBookingStore` does not contain `'0071000123456'`; Review Focus 2);
  - `a refund event done before the dispatch answer is stored stays done` (call `bookingRefundHandler(deps).record({...refund, status: 'done'})`, then record a `pending` answer: stored stays `done`; Review Focus 1);
  - `dispatchRefund on a refund already done makes no gateway call`.
  - Updated Ruling 7 tests: `a throwing gateway leaves the refund pending with attempts 1` in each of the four files.
- [ ] **Step 3:** Run `(cd packages/domain && npm test)`; the new tests fail.
- [ ] **Step 4: Implement.** Memory store: `getRefund` inside and outside the transaction, the two queries. Keep every transaction's reads before its first write.
- [ ] **Step 5:** `(cd packages/domain && npm test && npm run lint && npm run typecheck)` green. Do not run the Functions package (preamble).
- [ ] **Step 6: Commit** `feat(domain): keep the payer account and refund bank transfers to it [#201]`.

### Task 3: Domain and app — re-send in the payment clock, refund events, tickets on the same path

**Files:**
- Modify: `packages/domain/src/refund_subjects.ts` (`resendPendingRefunds`, `RefundEvent`, `applyRefundEvent`), `payment_sweeps.ts` (`PaymentSweepExtras`, step `resend`), `event_payments.ts` (`dispatchTicketRefund` = `sendRefundOnce` + `ticketRefundHandler(deps).record`; export `ticketRefundHandler`; remove `resendTicketRefund`, `TICKET_REFUND_RESEND_AFTER_MINUTES`), `event_ports.ts` (`EventPaymentDeps.cipher`; remove `EventStore.pendingTicketRefunds`), `memory_event_store.ts`, `event_sweeps.ts` (drop step `refund_resend` and `refundsResent`; deps type per Contract), `index.ts`; tests `packages/domain/test/payment_sweeps.test.ts`, `event_payments.test.ts` (`pay` gets `cipher: TEST_CIPHER`; the two throw tests now expect `pending`), `event_sweeps.test.ts`, new `packages/domain/test/refund_subjects.test.ts`
- App: `app_flutter/lib/data/events/event_registration.dart`, `app_flutter/test/data/events/event_registration_test.dart` (create if missing)

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: `resendPendingRefunds`, `RefundEvent`, `applyRefundEvent`, `PaymentSweepExtras`, the new `PaymentSweepResults` fields, `ticketRefundHandler`, `EventPaymentDeps.cipher` (Contract).
- Rules:
  - `resendPendingRefunds(deps, subjects, limit = 100)`: `deps.store.findPendingRefunds(now − REFUND_RESEND_AFTER_MINUTES, limit)`; handler = `bookingRefundHandler(deps)` for `subjectType` `booking` or absent, else `subjects[subjectType]`; no handler → `skipped + 1`; `handler.resend(r)` in its own try/catch → `resent + 1` or `failed + 1`.
  - `runPaymentSweeps`: step 3 `resend` after `expire`, wrapped so a query failure counts as `resendFailed` and never fails the sweep.
  - `applyRefundEvent`: `deps.store.getRefund(e.refundId)` and its payment; missing, or `payment.provider !== e.provider` → `refund_unknown`; next = `{...stored, status: e.status, manual: e.status === 'failed', providerRef: e.providerRef ?? stored.providerRef, failureReason: e.failureReason, updatedAt: now}`; booking → `bookingRefundHandler(deps).record(next)`, other subjects → `subjects[type]?.record(next)` (no handler → `refund_unknown`); otherwise `refund_applied`.
  - `ticketRefundHandler(deps).record(next)`: the existing ticket transaction (re-read refund and registration, write only per `mergeRefundOutcome`, mirror `refundStatus` when `reg.refundId === refund.id`); `resend` reads the payment in an `EventTx`.

- [ ] **Step 1: Contract check** of `event_payments.ts` (`dispatchTicketRefund`, `resendTicketRefund`, callers), `event_sweeps.ts`, `memory_event_store.ts`, `payment_sweeps.ts`; `grep -rn "refundsResent\|pendingTicketRefunds\|resendTicketRefund\|TICKET_REFUND_RESEND" packages app_flutter/firebase/functions` and ledger the Functions hits for Task 4.
- [ ] **Step 2: Failing tests.**
  - `payment_sweeps.test.ts`: `the payment clock re-sends a pending refund after 10 minutes under the same id and marks it done` (gateway throws once at dispatch; +9 min → nothing; +10 min → `refundCalls` has the id twice, `issuedRefunds.size === 1`, `refundsResent 1`); `awaiting_account and failed refunds are never re-sent`; `a refund that keeps throwing is re-sent until it goes to staff` (`refundThrowCount = 99`, run the clock every 10 minutes: after the 6th call `failed`, `manual`, `gateway_unavailable`, then no more calls; Review Focus 4); `the re-send racing an inline dispatch pays once and ends done` (`Promise.all([dispatchRefund(...), runPaymentSweeps(...)])`; Review Focus 1); `a ticket refund goes to refundSubjects.event_registration`; `a refund of a subject without a handler is skipped and counted`; `one failing handler does not stop the batch` (`resendFailed 1`, the next refund still sent).
  - `refund_subjects.test.ts`: `a refund event done moves a pending refund to done and sets depositRefundedAt once`; `a failed refund becomes done on a later done event`; `a done refund never changes on a failed event`; `an unknown refund id is refund_unknown`; `a provider that differs from the payment's is refund_unknown`; `a ticket refund event is recorded by subjects.event_registration`; `an awaiting_account refund ignores an event`.
  - `event_payments.test.ts`: `a throwing ticket refund stays pending and the registration still says pending`; `ticketRefundHandler.record mirrors done on the registration`; `ticketRefundHandler.resend sends under the same id`.
  - `event_sweeps.test.ts`: the `refund_resend` cases are removed; `runEventSweeps returns closed, completed, consentExpired, refunded`.
  - Flutter `event_registration_test.dart`: `fromCode reads awaiting_account as awaitingAccount and its code round-trips`; `unknown codes are null`.
- [ ] **Step 3:** Run the domain tests and `flutter test --no-pub --timeout 60s test/data/events/event_registration_test.dart`; the new tests fail.
- [ ] **Step 4: Implement.** Dart: `enum TicketRefundStatus { pending('pending'), awaitingAccount('awaiting_account'), done('done'), failed('failed'); const TicketRefundStatus(this.code); final String code; … }`; check every `.code`/`.name` use with `grep -rn "TicketRefundStatus" lib test`.
- [ ] **Step 5:** Domain `npm test && npm run lint && npm run typecheck` green; `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/data/events test/features/events` green.
- [ ] **Step 6: Commit** `feat(payments): re-send pending refunds from the payment clock and apply refund events [#201]`.

### Task 4: Functions — cipher and secrets, Firestore, webhook, clocks, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/live_refunds.ts`, `test/unit/refund_wiring.test.ts`
- Modify: `src/config.ts`, `src/index.ts` (`transitionBooking` → `BOOKING_REFUND_CALLABLE_OPTIONS`, `bookingClock` → `BOOKING_CLOCK_OPTIONS`, `paymentWebhook` passes `liveRefundSubjects()`), `src/infra/account_cipher.ts`, `src/infra/live_booking.ts`, `src/infra/live_event.ts`, `src/infra/live_payout.ts`, `src/infra/booking_firestore.ts` (payment `payer`/`refundedAmount`; refund fields; `getRefund` on the store and in the transaction adapter; `findPendingRefunds`, `awaitingRefundsDue`), `src/infra/event_firestore.ts` (remove `pendingTicketRefunds`), `src/infra/fake_webhook.ts`, `src/http/payment_webhook.ts`, `src/callables/payment.ts` (body `payer: FAKE_PAYER`), `src/scheduled/payment_clock.ts`, `src/scheduled/event_clock.ts` (drop `refundsResent` and its doc line), `tools/clock.ts`, `seed/fixtures.ts`, `seed/README.md`, `app_flutter/firebase/firestore.indexes.json`; tests `test/unit/support/payment_world.ts` and the three files that build `BookingDeps`/`EventPaymentDeps` (`cipher` = a test `aesGcmCipher` with a fixed 32-byte key), `booking_firestore.test.ts`, `payment_webhook.test.ts`, `payment_clock.test.ts`, `payment_callables.test.ts`, `event_clock.test.ts`, `event_firestore.test.ts`, `clock_cli.test.ts`, `config.test.ts`, `seed_fixtures.test.ts`; integration `test/integration/booking.test.ts` (cancel after a fake payment → refund `done` with `method 'bank_transfer'`), written, not run

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: the Functions Contract.

- [ ] **Step 1: Contract check** of the files above and Task 3's ledgered grep hits; confirm `PAYOUT_ACCOUNT_KEY` is in `.secret.local`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `booking_firestore.test.ts`: extend the shared `round-trips Booking through Firestore conversion`'s sibling payment and refund round-trips (do not add a second booking round-trip): `a payment round-trips payer and refundedAmount, and stores no plain number`; `a refund round-trips method, destination, confirmBy, attempts, lastAttemptAt, failureReason and status awaiting_account`; `a refund without method or attempts reads as gateway and 0`.
  - `payment_webhook.test.ts`: `a transfer with payer.accountNumber stores the payer encrypted on the payment`; `the stored raw body has the account number redacted` (`payment_notifications` raw contains `•••• 3456`, not `0071000123456`; Review Focus 2); `a refund body done moves the refund to done (200 refund_applied)`; `a refund body for an unknown id answers 200 refund_unknown`; `a refund body with a bad signature is 401`; `a refund body with a bad status is 400`; `webhook logs never contain the payer` (no holder name, number or last 4 in any log line).
  - `payment_callables.test.ts`: `confirmFakePayment sends FAKE_PAYER, so a cancel refund is sent by bank transfer`.
  - `payment_clock.test.ts`: the existing count assertion gains `refundsResent: 0, resendSkipped: 0, resendFailed: 0`; `the clock re-sends a pending refund through the default subjects` (pass `{refundSubjects: {}}` and a booking refund); logs still counts only.
  - `event_clock.test.ts` / `clock_cli.test.ts`: results without `refundsResent`; `npm run clock -- payments runs handlePaymentClock` and prints `paymentClock: reconciled=…`.
  - `refund_wiring.test.ts`: `every function that can capture a payer or send a bank refund binds PAYOUT_ACCOUNT_KEY` (`PAYMENT_CALLABLE_OPTIONS`, `WEBHOOK_OPTIONS`, `PAYMENT_CLOCK_OPTIONS`, `BOOKING_REFUND_CALLABLE_OPTIONS`, `BOOKING_CLOCK_OPTIONS` each have `secrets` containing it); `lazyAccountCipher reads the key only on first use` (a counter in `readKey`: 0 after construction, 1 after two encrypts); `liveRefundSubjects has an event_registration handler`.
  - `seed_fixtures.test.ts`: `seed bank_qr payments have an encrypted payer and refundedAmount`; `the cancelled seed refund is done, bank_transfer, to the seed payer`.
- [ ] **Step 3:** Run `(cd app_flutter/firebase/functions && npm test)`; the new tests fail (and the typecheck is red since Task 2).
- [ ] **Step 4: Implement.** Firestore queries: `findPendingRefunds` = `where('status','==','pending').where('lastAttemptAt','<=',ts).orderBy('lastAttemptAt').limit(limit)`; `awaitingRefundsDue` likewise on `confirmBy`. Indexes per the Contract; remove the old `refunds (subjectType, status, createdAt)` only after `grep -rn "subjectType', '=='" src` shows no refunds query left (ledger the grep). `docs/FIREBASE-SETUP.md` §12: list the functions that now bind the key (one sentence, no link to plans).
- [ ] **Step 5:** `(cd app_flutter/firebase/functions && npm test && npm run build)` green; domain checks still green.
- [ ] **Step 6: Commit** `feat(functions): refund destination, refund events and re-send wiring [#201]`.

### Task 5: Specs, data model and ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` (§5: one paragraph "đã làm ở #201" with Decisions 2, 3, 5, 7, 9 in Vietnamese; §9: `issueRefund` params/result as built), `docs/superpowers/specs/data-model/domain-model.md` (`Payment.payer`, `refundedAmount`; `Refund` fields; enums `RefundStatus`, `RefundMethod`), `docs/superpowers/specs/data-model/relational-schema.md` (`payments.payer_*`, `refunded_amount`; `refunds.method`, `destination_*`, `confirm_by`, `attempts`, `last_attempt_at`, `failure_reason`; status check list), `docs/superpowers/plans/2026-10-08-s04-reconciliation.md` (rows marked V2 → "(a) #201" with the real names; the V2 section gets one line "Đã làm ở #201"), `app_flutter/firebase/functions/seed/README.md` (seed payer, re-checked)
- Create: `docs/superpowers/handover/ledger-v2-refund-destination.md`

- [ ] **Step 1:** Write the docs in the house style (Vietnamese specs, English code names).
- [ ] **Step 2:** Ledger: what shipped per task; Decisions 1–15 as built and every contract difference found in a Step 1; skipped suites (Functions integration `booking.test.ts`); deploy order: (1) indexes `refunds (status, lastAttemptAt)` and `(status, confirmBy)` finish building before the functions (the payment clock's `resend` step errors until then; it is caught and counted); (2) functions: `PAYOUT_ACCOUNT_KEY` now bound to the functions in Decision 11 (the secret already exists in every project); (3) app build. Data notes: pending refunds written before V2 are not re-sent; dev payments without a payer refund into `awaiting_account`. Carry to #141 (`confirmBy`, `awaitingRefundsDue` and `BookingTx.getRefund` exist; derive "policy" from `fromEscrow`), #142 (`dispatchDisputeRefund` = `sendRefundOnce` + its transaction with `mergeRefundOutcome`), #140/#200 (register handlers in `liveRefundSubjects()`; use `payerAccountOf` and `transferRefund({destination})`), the real intermediary unit (its refund event format and signature).
- [ ] **Step 3: Commit** `docs(payments): refund destination, re-send and refund webhook in specs and data model [#201]`.

## Deferred

- S22.04 (confirm the payer account or another one), the 24-hour default (`confirmBy`, `confirmDueRefundAccounts`), `bookings/{id}.refundAccountNeeded`, payment history S22.01: #141.
- The real intermediary's refund API, refund event format and webhook signature (payments spec §10–11).
- One refund per sender when a payment was paid in parts from several accounts (Needs the owner 1).
- Ticket payments by bank QR (and with them `bank_transfer` ticket refunds and the secret on ticket functions): V1 (#200).
- Staff handling of `failed` + `manual` refunds and `needs_review` transfers: S23 (phase 1.5).
