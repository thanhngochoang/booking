# Handover ledger — plan S04 full payment, VietQR checkout and payment webhook (issue #129)

Plan: `docs/superpowers/plans/2026-10-07-s04-payments.md`, Tasks 1–9. Branch `plan/129-s04-dat-lich-thanh-toan` (plan commit a1e90d7; Tasks 1–8 up to 9446d9d, then the docs commit). Merge base 9023612.

## Built
- Domain: `UPFRONT_PERCENT = 100` (was `DEPOSIT_PERCENT = 30`); `PAYMENT_STATUSES` created, paid, expired, needs_review, refunded, partially_refunded (`failed` dropped); `PAYMENT_METHODS` bank_qr, momo, zalopay (reserved: domestic_card, intl_card); ledger `payment_received` (legacy `deposit_received` still read); constants `PAYMENT_EXPIRY_MINUTES = 15`, `PAYMENT_RECONCILE_AFTER_MINUTES = 3`, `DRAFT_PAYMENT_GRACE_MINUTES = 5`, `MAX_PAYMENT_ATTEMPTS = 3`.
- Domain, transfer code and QR: "PB " + 6 chars of `23456789ABCDEFGHJKMNPQRSTVWXYZ` from a FNV-1a hash of the payment id, unique across all payments (Ruling 6), matching ignores payments created after the transfer's `receivedAt`; VietQR EMVCo payload with CRC16-CCITT-FALSE (`vietqr.ts`).
- Domain, use cases: `createPayment`, `handleTransferNotification` (outcomes paid, paid_with_refund, partial, refunded, needs_review, duplicate), `checkPayment`, `runPaymentSweeps` (reconcile every 5 minutes for created booking payments older than 3 minutes, expiry, failure counters); refund reasons `overpaid_excess`, `underpaid_expired`, `late_transfer`, `extra_transfer`; a refund whose dispatch throws ends `failed` + `manual` (Ruling 7); expired payments get `escrowStatus` refunded (Ruling 4); `Booking.checkout` mirror and `payableUntil`; `payment_notifications/{provider}_{txnId}` records.
- Functions: callables `createPayment {bookingId, method}`, `checkPayment {bookingId}`, `confirmFakePayment {paymentId, kind exact|under|over|wrong_content}` (fake-gated); `paymentWebhook` (`onRequest`, `?provider=fake`, header `x-pb-signature: sha256=<hex HMAC-SHA256(raw body)>`, secret env `FAKE_PAYMENT_WEBHOOK_SECRET` (test value), statuses 200/400/401/404/405/500); `paymentClock` every 5 minutes; `createDeposit`/`checkDeposit` removed; new Firestore indexes; rules deny `payment_notifications`.
- App: `PayMethodSelector` and `CountdownPill` in core (the pill is a live region only at 5:00, 1:00, 0:10 and 0, Ruling 8); S04.03 per mock (two money rows, one helper line, selector, CTA "Thanh toán {amount}"); S04.04 VietQR view, wallet waiting view and fake-transfer sheet; every "cọc" removed from `app_vi.arb` (keys keep their old names, values changed).

## Docs changed in Task 9
- `screens/booking.md`: S04.03 and S04.04 rewritten to the build (arb key names in the "Chuỗi" lists); "cọc" stripped from S05.02, S05.03, S05.04 (booking `requested` đã thanh toán) and S04.05 (`s33_privacy`).
- `screens/photographer.md`: S06.01 ("đã trả 450K", "Đang giữ", toast "đã hoàn tiền"), S06.03 (`s23_refundNote` "{name} được hoàn 100% ({amount}) và nhận lý do này."); `screens/account.md`: `s42_phoneHint` "… sau khi bạn thanh toán."
- `components/shared-components.md`: new `PayMethodSelector` and `CountdownPill`; `EscrowNotice` texts and `MoneyBreakdown` lines without deposit; the stale `ProviderPicker` entry (MoMo | VNPay) replaced by `PayMethodSelector` + `PayMethodPicker` (S11.03); usage table updated.
- `data-model/README.md` §2.3 (100% up front; no more 30% split) and the use-case table (`createPayment`, `paymentWebhook`, `checkPayment`, `paymentClock`); `domain-model.md` (`Booking.checkout`/`payableUntil`, `Payment.method/transferCode/expiresAt/receivedAmount`, `Refund.reason`, new `PaymentNotification`, `PaymentStatus`, `PaymentMethod`, `TransferOutcome`, `LedgerEntryType`, invariants 2 and 11, a Payment state machine); `relational-schema.md` §2.4 (`payments` columns, status check, unique `transfer_code`, `refunds.reason/provider_ref`, `bookings.checkout/payable_until`, table `payment_notifications`, migration map).
- `2026-10-06-payments-payouts-design.md`: §3.2 step 4 now names `paymentWebhook` → `handleTransferNotification`; §9 port list is `PaymentGateway { provider, createPayment, queryTransfers, issueRefund }`; new §3.4 (fake provider signature, body, response codes, transfer code format and matching, constants) and a sentence in §9 that `verifyWebhook` lives in Functions (domain purity), the port has `createPayment`, `queryTransfers`, `refund`; §3.2 step 1 now says one helper line instead of an `EscrowNotice`.
- `2026-10-01-remaining-screens.md`: the S04.03 and S04.04 "Trạng thái" cells read "✅ thanh toán 100%, VietQR (#129)" (they replace "đã làm (4b)" and its notes about the missing map in step 3 and the S05.02 return). Fix round 1: the per-screen state table rows (S04.03, S04.04, S05.02, S05.03) and the escrow sentence near line 696 were also rewritten to the build, and the S04.03 status cell keeps " · bước địa điểm chưa có bản đồ".

## Rulings
Verbatim from the SDD progress ledger (`.superpowers/sdd/2026-10-07-s04-payments/progress-plan-129-s04-dat-lich-thanh-toan.md`), in order. Rulings 5 and 6 rename plan interfaces; Ruling 8 replaces the plan's per-second live region. The docs above describe what was built.

- Ruling 1: T3 keeps the old domain deposit API (createDeposit, confirmFakePayment, checkDeposit, handlePaymentNotification export) in place; T4 deletes them together with the functions handlers — keeps each commit's functions tests runnable — cost if wrong: dead code lives one task longer.
- Ruling 2: Between T3 and T4 `functions npm run typecheck` may fail (FirestoreBookingStore lacks the new store methods); T3 must keep `functions npm test` green and T4 restores typecheck/build — cost if wrong: one intermediate commit does not typecheck in functions.
- Ruling 3: T5 regenerates freezed/json code with `dart run build_runner build --delete-conflicting-outputs` and commits the generated files (they are tracked) — cost if wrong: none beyond build time.
- Task 2: review 1 (be56773): Important — ledger invariant classifies by free-text refund reason. Ruling: literal rule by payment status (paid: received − refunded = amount; expired: = 0), no Refund.kind field — simplest, matches Decision 10 — cost if wrong: Task 3 adds a field later.
- Ruling 4: expired payments get escrowStatus 'refunded' (nothing held; keeps them out of escrow release queries) — Task 2 left no 'none' value — cost if wrong: a later enum value + migration of dev rows.
- Task 3: implementer DONE_WITH_CONCERNS (6d218dd). Ruling 5: accept interface deviations — findPaymentsByTransferCode (any status) instead of findOpenPaymentByTransferCode (needed to refund a paid-old-QR), reuse getPaymentsForBooking, TransferOutcome in booking_ports.ts, getTransferRecord on BookingTx — plan names were illustrative; Task 4 brief must use the real names — cost if wrong: renames.
- Ruling 6: transfer codes unique across all payments (any status) + matchPayment ignores payments created after receivedAt — overrides Decision 5 "open payments" — cost if wrong: one extra lookup per createPayment.
- Ruling 7: refund dispatch throws in this unit's paths mark the refund failed+manual (same as success:false) and the rest continue; no new pending-refund retry sweep — cost if wrong: network blips need staff handling until a retry sweep exists.
- Ruling 8: CountdownPill liveRegion only at countdown.dart's announce thresholds and at zero — overrides plan's "Semantics(liveRegion: true)" — cost if wrong: screen-reader users hear fewer updates.

Pre-flight table rows that cite Rulings 1–3 (same file):

```
| T3 ↔ T4 | createPayment, handleTransferNotification, checkPayment, assertPaymentPayer, runPaymentSweeps, BookingStore methods | T3 deleting domain confirmFakePayment/checkDeposit/createDeposit breaks functions handlers until T4 → Ruling 1 |
| T3 ↔ T4 | BookingStore interface grows in T3; FirestoreBookingStore implements it in T4 | functions typecheck red between T3 and T4 → Ruling 2 |
| T3 self | "delete create_deposit.ts if nothing imports it" vs functions still importing | Ruling 1 |
| T5 self | Booking is freezed (booking.freezed.dart, booking.g.dart tracked) → needs build_runner | Ruling 3 |
```

## Deferred
From the plan:
- The real intermediary: its signature scheme, secret (`defineSecret`) and VietQR account. Payments spec §10–11; the issue #129 item stays open.
- Milestone release (2 mốc) and the field rename `deposit` → `terms.price` (#130 delivery, #134 earnings). The copy already promises "2 mốc"; escrow release is still the whole payment after completion + 24 h.
- Refunds to the sender's account with the S22.04 confirmation, and payment history S22.01 (#141).
- `needs_review` handling and the daily statement reconciliation (S23.02, staff). Nothing writes `needs_review` on a `Payment`; unmatched transfers only get a `payment_notifications` record.
- Moving ticket payments (S11.03) to `createPayment` and the webhook (#137). Tickets keep `createDepositIntent`, `checkPaymentStatus`, `confirmFakeTicketPayment`.
- Card methods (`domestic_card`, `intl_card`; config flag off).
- Old dev drafts without `payableUntil` are not swept.
- Step 3 (S04.03 flow, place step) still has no map: "bước địa điểm chưa có bản đồ" stays open in the S04.03 status cell of `2026-10-01-remaining-screens.md`.

## Minor findings (deferred)
Verbatim from the SDD ledger, grouped by task. Lines tagged FINAL REVIEW TRIAGE are for the whole-branch review to rule on.

### Task 1
- Task 1: minor (deferred): create_deposit.ts:3 doc still says 30% (file removed in T4)
- Task 1: minor (deferred): seed refund_done row hard-codes service price 1_500_000
- Task 1: minor (deferred): booking_policy.json constants block not read by any test

### Task 2
- Task 2: minor (deferred): decideTransfer treats NaN dates as on-time (fails open) — final review to triage
- Task 2: minor (deferred): needs_review payment → extra_transfer refund not in plan (documented choice)
- Task 2: minor (deferred): no golden vector for transferCodeFor
- Task 2: minor (deferred): vietqr bin/account not validated
- Task 2: minor (deferred): invariant false for created payments — Task 3 must not call it on created

### Task 3
- Task 3: minor (deferred): idempotency key pay_${bookingId}_${attempt} not tied to paymentId (gateway call inside tx closure) — real-intermediary unit
- Task 3: minor (deferred): reconcile only looks at created payments; missed webhook for expired payment never found
- Task 3: minor (deferred): checkPayment/reconcile re-match by memo instead of provider-named payment
- Task 3: minor (deferred): needs_review TransferRecord keeps only raw (no amount/content)
- Task 3: minor (deferred): checkout/payableUntil survive draft→requested
- Task 3: minor (deferred): createPayment checks phone before ownership/draft
- Task 3: minor (deferred): invariant for refunded status weak (received>=amount only)
- Task 3: minor (deferred): matchPayment depends on provider receivedAt being UTC-comparable (T4 normalises fake; real adapter must too)
- Task 3: minor (deferred): sweep catch blocks drop error detail (counts only)
- Task 3: minor (deferred): store failure in recordDispatch leaves refund pending with no retry
- Task 3: minor (deferred): code uniqueness checked outside the creating transaction (race very unlikely)
- Task 3: minor (deferred): legacy dispatchRefund (cancel flows) still leaves pending on throw

### Task 4
- Task 4: minor (deferred, FINAL REVIEW TRIAGE): earnings count created/unpaid QR payments as "Đang giữ" (escrowStatus held at creation; pre-existing with createDeposit)
- Task 4: minor (deferred): receivedAt parsing lenient (Date.parse)
- Task 4: minor (deferred): integration test hard-codes fake secret
- Task 4: minor (deferred): (transferCode,status) index unused
- Task 4: minor (deferred): dev webhook public with committed test secret (fake money; real unit uses defineSecret)

### Task 5
- Task 5: minor (deferred): bookingCheckoutFrom `as String?` on method throws for non-string (whole booking null)
- Task 5: minor (deferred): naive ISO expiresAt parsed as local
- Task 5: minor (deferred): fake keeps checkout after paid; no hashCode test; fake doesn't enforce 3-attempt cap

### Task 6
- Task 6: minor (deferred): PayMethodSelector raw sizes/border widths/opacity (mock-derived) instead of tokens
- Task 6: minor (deferred): review_step_test expects "Gói Gói Chân Dung" (fixture name)
- Task 6: minor (deferred): after payment_attempts_exceeded at S04.03, new draft for same slot may hit day_taken (old draft holds the day until payableUntil)

### Task 7
- Task 7: minor (deferred, FINAL REVIEW TRIAGE): "Tạo QR mới" ignores returned checkout; slow snapshot re-enables button and a second tap burns an attempt
- Task 7: minor (deferred): sub-second remainder floors (00:00 shown before expiry; 14:59 at start)
- Task 7: minor (deferred): orphan arb keys fakePayTitle/fakePayConfirm
- Task 7: minor (deferred): empty photographer name renders " · service"
- Task 7: minor (deferred): no double-tap test for in-flight "Tạo QR mới"

### Task 8
- Task 8: minor (deferred, FINAL REVIEW TRIAGE): packages/domain/src/notification_render.ts:71,75,82,87 push bodies still say "Cọc…"
- Task 8: minor (deferred): no-cọc test misses NFD/unaccented forms; test names still say "deposit"

## Not run (sandbox)
- The Firestore rules emulator tests (`app_flutter/firebase/rules-test`, including the new "payment_notifications is denied to clients" test) and the Functions integration tests (`npm run test:integration`, including the payment webhook flow against the emulators) were written but not run in the sandbox; CI runs them on push. The other checks (domain and Functions unit tests, typecheck, lint, Flutter analyze and tests) ran inside the sandbox during each task.

## Issue #129 items
- The item "Chặn confirmFakePayment…" of #129 was already merged in #126 (commit 347326a); `confirmFakePayment` is guarded by `assertFakePaymentsAllowed` and now also takes `kind`.

## Notes for the next unit
- Task 3: handoff to T4: reconcile query must skip legacy/ticket created payments; underpaid_expired refund is one refund without providerRef (real adapter may need per-transfer refunds → defer to intermediary unit). (the sweep skips payments without a transfer code, so tickets and legacy payments are left alone)
- Push bodies in `packages/domain/src/notification_render.ts` (lines ~71–87) still say "Cọc…" (Task 8 triage item).
- Stored names stay `deposit`/`remaining`/`depositProvider`/`depositPaidAt` (Decision 1); `deposit` is the full price and `remaining` is 0. Arb keys such as `bookDepositToday`, `payAwaitingDeposit` keep their names with new values.
- The dev webhook is public with a committed test secret (fake money only); the real provider unit must use `defineSecret` and its own signature scheme.
