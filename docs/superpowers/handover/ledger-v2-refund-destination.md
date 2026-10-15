# Handover ledger — V2 refund destination, refund events and re-send wiring (issue #201)

Plan: `docs/superpowers/plans/2026-10-08-v2-refund-destination.md`, Tasks 1–5. Branch `plan/201-hoan-tien`.

---

## 1. What shipped per task

### Task 1: Domain types, ports, policy and one-shot refund send
- Commit: `9a89357` (`feat(domain): refund method, payer account and one-shot refund send [#201]`).
- Shipped:
  - `StoredBankAccount`, `RefundDestination`, `PayerBankAccount`, `RefundMethod`, `refundMethodOf`.
  - `Payment.payer` (encrypted bank account, display last4, names), `Payment.refundedAmount`.
  - `Refund` fields: `method`, `destination`, `confirmBy`, `attempts`, `lastAttemptAt`, `failureReason`.
  - `REFUND_STATUSES` gains `awaiting_account`.
  - `REFUND_RESEND_AFTER_MINUTES = 10`, `REFUND_MAX_ATTEMPTS = 6`.
  - `PaymentGateway.issueRefund` parameters extended with `method` and decrypted `destination?: PayerBankAccount`, and result `pending?: boolean`.
  - Pure domain rules: `sendRefundOnce`, `mergeRefundOutcome`.

### Task 2: Payer capture, refund destination and app ticket status
- Commit: `144707c` (`feat(domain): keep the payer account and refund bank transfers to it [#201]`).
- Shipped:
  - `BookingDeps.cipher` and `EventPaymentDeps.cipher` (`AccountCipher`).
  - Capture payer bank account on first qualifying transfer (`handleTransferNotification`), encrypting via cipher and storing on `Payment.payer`.
  - Refund destination assignment on bank transfers: `applyRefundToPayment` targets `payment.payer`; `transferRefund` targets transfer sender, fallback to `payment.payer`.
  - Missing destination on bank transfer creates refund in `awaiting_account` status.
  - `Payment.refundedAmount` updated in atomic transactions for all refunds.
  - App `TicketRefundStatus.awaitingAccount` (`awaiting_account`), read as "Đang hoàn" in tickets tab.

### Task 3: Refund events, re-send sweep in payment clock and subjects registry
- Commit: `10d94a6` (`feat(payments): re-send pending refunds from the payment clock and apply refund events [#201]`).
- Shipped:
  - `RefundSubjectHandler`, `RefundSubjects`, `RefundEvent`.
  - `bookingRefundHandler(deps)` and `ticketRefundHandler(deps)`.
  - `applyRefundEvent(deps, refundSubjects, event)`: idempotent processing of refund events via `mergeRefundOutcome`.
  - `runPaymentSweeps` step `resend`: finds pending refunds older than 10 minutes, invokes subject handler `resend`, logs counters `refundsResent`, `resendSkipped`, `resendFailed`.
  - Removal of ticket refund resend from `eventClock` (`resendTicketRefund`, `TICKET_REFUND_RESEND_AFTER_MINUTES`, `pendingTicketRefunds`, `refundsResent` removed from `runEventSweeps`).

### Task 4: Functions wiring, Firestore mappers, secrets and Fake webhook
- Commit: `9b326d0` (`feat(functions): refund destination, refund events and re-send wiring [#201]`).
- Shipped:
  - `liveRefundSubjects()` exporting `ticketRefundHandler(liveEventPaymentDeps())`.
  - `lazyAccountCipher(readKey)` reading `PAYOUT_ACCOUNT_KEY` only upon first use.
  - Bound `PAYMENT_SECRETS = [PAYOUT_ACCOUNT_KEY]` to `PAYMENT_CALLABLE_OPTIONS`, `WEBHOOK_OPTIONS`, `PAYMENT_CLOCK_OPTIONS`, `BOOKING_REFUND_CALLABLE_OPTIONS`, and `BOOKING_CLOCK_OPTIONS`.
  - `booking_firestore.ts`: Firestore serialization/deserialization for `Payment.payer`, `Payment.refundedAmount`, and `Refund` fields (`method`, `destination`, `confirmBy`, `attempts`, `lastAttemptAt`, `failureReason`).
  - Firestore indexes in `firestore.indexes.json`: added `refunds (status ASC, lastAttemptAt ASC)` and `refunds (status ASC, confirmBy ASC)`; removed obsolete `refunds (subjectType ASC, status ASC, createdAt ASC)`.
  - Redaction in `fake_webhook.ts`: raw body stored in `payment_notifications/{id}` redacts `payer.accountNumber` to `•••• <last4>`.
  - `paymentWebhook` handles refund events `{ type: 'refund', refundId, status, providerRef?, failureReason? }`.
  - CLI `tools/clock.ts`: added `payments` command calling `handlePaymentClock()`.
  - Seed fixtures updated with encrypted seed payer and done bank transfer refund.

### Task 5: Specs, data model and ledger
- Commit: `docs(payments): v2 refund destination spec, schema and ledger [#201]`.
- Shipped:
  - Updated `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §5 & §9.
  - Updated `docs/superpowers/specs/data-model/domain-model.md`.
  - Updated `docs/superpowers/specs/data-model/relational-schema.md`.
  - Updated `docs/superpowers/plans/2026-10-08-s04-reconciliation.md`.
  - Updated `app_flutter/firebase/functions/seed/README.md`.
  - Created `docs/superpowers/handover/ledger-v2-refund-destination.md`.

---

## 2. Decisions 1–15 as built

1. **Not blocked by V1:** `RefundSubjects` and `liveRefundSubjects()` provide an independent registry for booking and ticket refunds without depending on V1 `SubjectSettler`.
2. **Payer capture:** Payer captured from the first transfer that counts towards the payment (`partial` or `paid`). Encrypted before writing to `Payment.payer`.
3. **Where a refund goes:** `method = refundMethodOf(payment.method)` (`bank_qr` → `bank_transfer`, others → `gateway`). Bank transfer targets `destination = payment.payer` with `source: 'payer'`. If no destination is available, status is `awaiting_account`.
4. **`Payment.refundedAmount`:** Maintained as total refund sum across all refunds in payment transactions.
5. **Dispatch rule:** `sendRefundOnce` performs a single gateway call; retries up to 6 times before transitioning to `failed` + `manual`.
6. **Storing an outcome:** `mergeRefundOutcome` protects `done` and `awaiting_account` refunds while updating attempts, lastAttemptAt, and failureReason.
7. **Re-send in payment clock:** `runPaymentSweeps` handles `resend` for all pending refunds across subjects using query `findPendingRefunds(before, limit)`.
8. **`RefundSubjects`:** Decoupled handlers with `resend(refund)` and `record(next)`.
9. **Refund webhook on existing endpoint:** `paymentWebhook?provider=fake` handles both transfers and refunds. Unknown refunds reply with 200 `{ ok: true, outcome: 'refund_unknown' }`.
10. **Gateway port:** `issueRefund` accepts decrypted `destination?: PayerBankAccount` and returns `pending?: boolean`.
11. **Cipher wiring and secrets:** `PAYOUT_ACCOUNT_KEY` lazily loaded and bound to relevant booking, webhook, and payment callable/clock functions.
12. **Plain number never stored:** Webhook raw payloads redact account numbers to `•••• <last4>`.
13. **`confirmBy` and `awaitingRefundsDue`:** Added to model and store; automated confirmation logic deferred to #141.
14. **Fake and seed data:** `confirmFakePayment` sends `FAKE_PAYER`. Seed fixtures store encrypted payer and done bank transfer refund.
15. **App:** `TicketRefundStatus.awaitingAccount` added; UI screens S22.01/S22.04 deferred to #141.

---

## 3. Deploy order

1. **Firestore indexes:**
   - Deploy `app_flutter/firebase/firestore.indexes.json` first:
     - `refunds (status ASC, lastAttemptAt ASC)`
     - `refunds (status ASC, confirmBy ASC)`
   - Wait until indexes finish building in Firebase Console before deploying functions.
2. **Cloud Functions:**
   - Deploy Cloud Functions. Ensure `PAYOUT_ACCOUNT_KEY` secret is accessible to `paymentWebhook`, `paymentClock`, `transitionBooking`, `bookingClock`, `createPayment`, `checkPayment`, `confirmFakePayment`.
3. **App build:**
   - Deploy Flutter client app containing `TicketRefundStatus.awaitingAccount`.

---

## 4. Data notes

- Pending refunds created before V2 do not have `lastAttemptAt` and will not be swept by `findPendingRefunds`.
- Dev payments created without a payer account will refund into `awaiting_account` status instead of failing.
- Integration tests in `test/integration/booking.test.ts` for functions were written/retained without emulator execution during local unit runs.

---

## 5. Carry forward to future issues

- **#141:** Customer-facing UI S22.04 to confirm or change refund account; 24h timer expiration with `awaitingRefundsDue` and `confirmDueRefundAccounts`; `bookings/{id}.refundAccountNeeded`.
- **#142:** Dispute refund dispatch (`dispatchDisputeRefund` using `sendRefundOnce` + `mergeRefundOutcome`).
- **#140 / #200:** Register additional subject handlers in `liveRefundSubjects()`; support `payerAccountOf` and `transferRefund({ destination })`.
- **Intermediary integration:** Real intermediary refund API, webhook event format, and cryptographic signature verification.
