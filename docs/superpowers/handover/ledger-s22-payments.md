# Handover ledger — S22 payment history and refund account (issue #141)

Plan: `docs/superpowers/plans/2026-10-07-s22-payments-account.md`, Tasks 6–11 (Tasks 1–5 were #205, ledger `ledger-s22-account-privacy.md`). Branch `plan/141-s22-payments-account` from `origin/develop` 723955fb. Target merge: `develop`.

Screens: S22.01 Lịch sử thanh toán (`/me/payments`) and S22.04 Tài khoản nhận hoàn (sheet), with entry points on S05.02, S05.03, S09.02, S11.04 and S18.02. Specs: main spec §2 and §3i.5, payments spec §5, `screens/account.md` (S22.01, S22.04, S09.02), `screens/booking.md` (S05.02, S05.03), `screens/events.md` (S11.04), `screens/disputes-help.md` (S18.02), data model (`domain-model.md`, `relational-schema.md`), `docs/legal/terms-and-help-notes.md` P15–P16.

## Merged before this unit (on 723955fb)

All the plan's soft and hard dependencies had merged, so nothing is written against Contract names only:

- #129 escrow and VietQR checkout (#154), #134 payouts and `FakeAccountNameLookup` (#193), #138 notification hooks incl. `notifyRefundAccountNeeded` (#155), #148 S09.02 groups (#188).
- V1 #200 subject payments (#228), V2 #201 refund destination (#234).
- #205 delete account and privacy (#268): the `paymentsData` group and the money blockers already existed.
- #140 Chụp ngay (#285, #295) and #202 Chụp ngay payments (#298): instant payments and refunds write S22.01 rows now. The plan's note "Chụp ngay hiện khi #140 ghi khoản" is dropped.
- #142 disputes (#297): dispute refunds go through this unit's S22.04 (`DisputeRefund`), and the S18.02 entry is built here, not carried.

## Built per task

### Task 6: payer payment history, domain and Functions (d88f9d25, fix 28401cb9)
- Domain `payer_history.ts`: `PAYER_ROW_STATUSES`, `PayerRowStatus`, `RefundKind`/`refundKindOf`, `PayerRefundView`, `PayerSubjectView` (structured title parts), `EMPTY_PAYER_SUBJECT`, `PayerPaymentRow`, `PayerTotals`, `paymentHasMoney`, `destinationLabel`, `payerRowOf`, `payerTotals`, `PayerHistoryTx`/`PayerHistoryStore` (transactional), `refreshPayerHistory`, `refreshPayerHistoryOfSubject`; `memory_payer_history_store.ts` (strict).
- Functions: `infra/payer_history_firestore.ts` (field whitelist, subject builders, `FirestorePayerHistoryStore`); trigger `onRefundWritten` (`triggers/refund_write.ts`); `onPaymentWritten` refreshes the row when `status`, `escrowStatus`, `receivedAmount`, `refundedAmount`, milestones or `payeeId` change (earnings first, payer row last); `triggers/booking_payer_rows.ts` from `onBookingWrite` (status, day, photographer).
- Rules: `users/{uid}/payments/{paymentId}` owner read, no client write; totals use the existing `users/{uid}/private/{docId}` owner-read rule.
- Data export (#205's `data_export_firestore.ts`) now exports the history rows (`paymentHistoryForExport`), no raw payments.
- Seed: payer rows and totals for Lan and Giang computed with the same pure functions; Lan's cancelled Chụp ngay request with a refunded MoMo payment.

### Task 7: refund account, domain and Functions (05e3774b, fix 42ec41a4)
- Domain `refund_account.ts`: `RefundSubjectRef`, `PendingRefundView`, `RefundAccountDeps {bookings, events, disputes, lookup, clock}`, `pendingRefundFor`, `lookupRefundAccount`, `chooseRefundAccount`, `confirmDueRefundAccounts`, `announceRefundAccountNeeded`; `escrow.ts`: `REFUND_ACCOUNT_CONFIRM_HOURS = 24`, `needsAccountChoice`, `canChooseRefundAccount`, `Refund.candidate`, `Refund.accountLookups`, `applyRefundToPayment({waitForAccount})`; `booking.ts`: `refundAccountNeeded`.
- `commit_transition`, `refundTicket` (and so `cancelEventWithRefunds`), `resolveDispute` pass `waitForAccount`; `payment_sweeps.ts` gains step 4 `confirmDueRefundAccounts` (batch 100) at the end of the payment clock.
- Functions: callables `pendingRefund` (`CALLABLE_OPTIONS`), `lookupRefundAccount` (secret `PAYOUT_ACCOUNT_KEY`), `chooseRefundAccount` (`PAYMENT_CALLABLE_OPTIONS`); `infra/live_refund_account.ts` (fake lookup echoes the caller's normalised display name, only where `lookupMode()` is `fake`); `onRefundWritten` sends the notice first, then refreshes the row; `paymentClock` gets the step through `handlePaymentClock` (`PaymentClockExtras.refundAccounts`).
- `docs/FIREBASE-SETUP.md` §12 lists the two new callables that bind the key.

### Task 8: app data (6a224fdf; Task 8 review fixes 306b6cc0)
- `lib/data/payments/payment_history.dart`: `PayerRowStatus` and `PayerSubjectType` (both with `unknown`), `PayerRefundView`, `PayerPaymentRow`, `PaymentTotals`, sealed `RefundSubject` (`BookingRefund`, `TicketRefund`, `DisputeRefund`), `PendingRefund`, `RefundAccountChoice`.
- `payments_repository.dart`: `FirebasePaymentsRepository` (renamed from `FunctionsPaymentsRepository`) with `watchHistory`, `watchTotals`, `pendingRefund`, `lookupRefundAccount`, `chooseRefundAccount`; `paymentHistoryProvider(limit)`, `paymentTotalsProvider`. Errors as `BookingException(code)`; network failures read `network`; other errors are rethrown untouched.
- `Booking.refundAccountNeeded` (freezed); `FakePaymentsRepository` gains the new calls.

### Task 9: S22.04 sheet and entry points (6f91f792; fixes d42c13e1 server, c60c67b1 app)
- `lib/features/payments/refund_account_sheet.dart`, `refund_account_controller.dart` (`pendingRefundProvider`, `RefundAccountController`).
- Entry points: S05.03 after cancel (`openRefundAccountAfterCancel`, only `checkout?.method == bankQr`), S05.02 card `_RefundAccountCard` while `refundAccountNeeded`, S11.04 after a refunded ticket cancel, S18.02 `_RefundAccountEntry` from `pendingRefund({disputeId})`. `BankField` gains an optional `label`.

### Task 10: S22.01 screen and S09.02 row (bc08abb5; fix 9a3636d4 domain, 6c286503 app)
- `lib/features/payments/payment_history_screen.dart`, `payment_history_controller.dart` (`paymentsPageSize = 20`, `paymentsLimitProvider`, month groups, `refundSubjectOf`); route `/me/payments`; S09.02 "Lịch sử thanh toán" first in the `paymentsData` group (key `settings-payment-history`).
- `EarningRow` gains three optional slots: `statusLabel`, `action`, `footer` (S06.05 unchanged); `shared-components.md` notes them.

Fix round 1 (re-review folded into the final review):
- Domain: `pendingRefundFor({bookingId})` and `({eventId, registrationId})` also return a waiting dispute refund through `waitingRefundsOf` (booking kinds `booking|dispute`, ticket kinds `ticket|dispute` plus the registration's own `refundId`), oldest by `(createdAt, id)`; `chooseRefundAccount` lands on the refund shown. `payerRowOf` takes `eventId = p.eventId ?? subject.eventId`.
- App: core `MonthHeader` (`.first` / `.month`, `monthLabel`) and `groupByVnMonth` exported from `core.dart`; the earnings `groupByMonth` is a wrapper and the private copies are gone. Later months are `.nsec` (uppercase `labelSmall`, 0.08em, muted), which changes S06.05 (its test now reads THÁNG 9 / THÁNG 12/2025).
- A failed "Xem thêm" keeps the rows with one `ErrorState` below; totals and rows both failing give one `ErrorState`; totals alone fail into their own error. Dispute and wait pills follow `AppColorsDark` in dark mode. An unknown-status row with a known subject keeps its detail link. New widget test: a dispute-refund booking row opens S22.04.
- Decision 6 consequence: `booking.refundAccountNeeded` is raised only by `commit_transition` policy refunds, so a dispute refund on a booking shows the S22.01 button and S22.04 but not the S05.02 card.

### Final review and final wave (server 9bb382e9, app 95bf27ee)

Final review (server, app, docs in parallel): 0 Critical; server 3 Important, app 1 Important, docs 5 Important (the fix round not folded in; this commit).

Server (`9bb382e9`):
- S1: `openRows` in `payer_history_firestore.ts` also reads `users/{payer}/private/paymentTotals` inside the refresh transaction (before any write), so two concurrent refreshes of one payer contend and the totals cannot drift. Unit test asserts the path is among the strict fake's reads; no emulator test of two concurrent refreshes (not feasible with the fake; emulator suites are not run here).
- S2: `triggers/instant_payer_rows.ts` (`handleInstantPayerRows`), called from `onInstantRequestWrite` after `handleInstantRequestWrite`, refreshes the payer row only on a `status` change of an existing request (`no_match` ↔ `choosing` no longer leaves "đang tìm thợ" stale).
- S3: `refreshPayerHistoryOfSubject` refreshes every id, remembers the first error and rethrows after the loop (one failing payment no longer starves the others).
- S4: `lookupRefundAccount` throws `not_found` when the counting `ledger.update` returns null, before the bank call (bank asked 0 times).
- S9: the rules-test seed row uses `photographerName`/`serviceName` (and null `eventTitle`/`quantity`/`areaLabel`) instead of `title`; written, not run.
- S10 ruling: a refund whose payment is missing cannot name its booking (the booking id lives on the payment; `Refund` has no `subjectId`), so `leaveDueQueue`'s payment-missing branch cannot lower `refundAccountNeeded`. Staff own that refund (`failed`, `manual`, `payment_missing`). Comment in code, no behaviour change.

App (`95bf27ee`):
- A1: after a conflict `_destination()` names the account only when the S22.01 row's refund is `pending` or `done`; for `awaiting_account` or `failed` it returns null and the sheet shows the generic `refundAccountAlreadySent`. Ruling: the repository `watchHistory` has no server-only read, so no non-cached read was added.
- A2: comments corrected (the rows are the newest payments by creation time; an older payment's refund is not found and the sheet points to S22.01).
- A3: `PopScope(canPop: !state.sending)` around the sheet body: barrier tap and Back cannot dismiss it while the choice is being sent.
- A4: named constants `_pillWaitAlpha`, `_pillDisputeAlpha`, `_pillMaxWidthFraction` (no opacity token exists).
- A5: the sheet's error text uses `AppColorsDark.error` / `AppColors.error` by brightness.
- A6: `wallet` is true only for a refund with a `method` other than `bank_transfer` (a refund without a method is not a wallet refund).
- A7 answer: yes, `pendingRefund` right after a cancel finds the refund. `commit_transition.ts` calls `tx.addRefund(...)` in the same transaction as the status change (and sets `refundAccountNeeded`), and `cancelRegistration` awaits `refundTicket` before the callable returns.

### Task 11: docs (71377237, then the fold-in commit of the fix round and final wave)
- Main spec §2 status cells for S22.01 and S22.04 link [#141]; §3i.5 as built; payments spec §5 "Đã làm ở #141"; screen specs above; data model; terms notes P15–P16; this ledger.
- Data model gap closed while there: `payments.payer_id` (and `Payment.payerId`) was missing from `relational-schema.md` / `domain-model.md` although the code and #205's index `payments (payerId, createdAt desc)` use it.

## Rulings and decisions as built

Decisions 1–8 of the plan, with what changed:

1. **History is a server-written projection** (as planned). The store is transactional (`PayerHistoryStore.runTransaction`, reads before writes) instead of the flat Contract interface, because payment and refund triggers fire together.
2. **Which payments get a row:** not only `receivedAmount > 0`. A row exists when the payment was ever paid (`paidAt` or status paid/partially_refunded/refunded), or `receivedAmount > 0`, or it has any refund. Wallet and legacy payments carry no `receivedAmount`, and a late transfer to an expired QR leaves it 0.
3. **Row status precedence** (as planned), with two rulings: a waiting refund that S22.04 cannot settle (Chụp ngay, S21 fee) reads `refunding`, never `refund_account_needed`; `amount` is what the customer sent (paid: `amount` + excess refunds; never paid: open QR `receivedAmount` + refunds, expired QR the sum of its refunds). `heldAmount` follows escrow, with booking milestones only the `held|disputed` ones. A 50% cancel whose refund is pending stays `refunding` and still counts its held half.
4. **Chụp ngay rows:** real rows (#202 merged), not a fixture. `searching` = request `choosing|pending_payment|searching`; `cancelled` = `abandoned|cancelled_by_customer|no_show_customer` (`no_match` is not cancelled: money is still held and the customer may reopen).
5. **Refund-account window:** opt-in. `applyRefundToPayment({waitForAccount: true})` only from `commit_transition` (every booking cancel, decline, expiry, studio-fault cancel with a refund), `refundTicket` and `resolveDispute`. Every other path keeps V2's rule (send to the payer at once, wait only without one): excess refunds, `booking_payment_paths` (`late_payment_draft_expired`, `provider_not_accepting`), ticket late payment, Chụp ngay, S21 fee.
6. **Mirrors:** `bookings/{id}.refundAccountNeeded`; ticket `refundStatus`; no flag on disputes (S18.02 calls `pendingRefund({disputeId})`). The notification has one emitter, `onRefundWritten` → `announceRefundAccountNeeded` (not the use cases, whose deps carry no `NotifyDeps`), deduped by #138 per refund id.
7. **Other account:** two calls as planned. The holder name is looked up and shown, never typed; no name match with the payer (owner question 2, default). `chooseRefundAccount({use: 'candidate'})` also carries the shown `bankCode` and `accountLast4` and answers `conflict` when the stored candidate differs (a later lookup replaced it) or when the refund already left `awaiting_account` to another destination (lost to the 24-hour default). A payer choice is idempotent.
8. **Name lookup port:** #134's `FakeAccountNameLookup` reused; no second fake. Lookups are capped per refund per Vietnam day at `NAME_LOOKUPS_PER_DAY` (20), charged in a transaction before the bank call, every attempt counts; the 21st is `limit_exceeded`.

Other rulings from the task reviews:

- Titles are composed by the app from structured parts (`photographerName`, `serviceName`, `eventTitle`, `quantity`, `areaLabel`, `toPlatform`) with `payTitleBooking` / `payTitleTicket` / `payTitleInstant` / `verifyFeeTitle`; the server stores no Vietnamese titles.
- `method` is nullable (legacy payments); `PayerSubjectType` includes `verification_fee`; rows gain `toPlatform` ("Đã thanh toán").
- Unknown status or subject codes are kept as a neutral generic row (badge from the server's `open` flag); an unknown subject has no detail link, an unknown status with a known subject keeps it. Only a null document is skipped.
- The due-default queue cannot starve: a due refund the default cannot send leaves the queue (payment gone → `failed` + `manual` + `payment_missing`; otherwise `confirmBy` cleared).
- Routing: a refund whose reason is `dispute:<id>` goes to the dispute ledger, `event_registration` to the ticket ledger, everything else to the booking ledger; Chụp ngay and S21-fee refunds are `not_eligible`.
- App: inputs locked while a lookup runs; after a `conflict` the sheet re-reads `pendingRefund` and names the actual destination from the S22.01 row, or points to Lịch sử thanh toán; no device-clock pre-check.
- Accepted UI deviations from the mock: explicit "Tra tên chủ tài khoản" button (mock looks up automatically; every attempt counts toward the 20/day cap); a "Hoàn về tài khoản đã chuyển" link back from the other-account form; S22.01 status as the mock's plain-text `.st` pill (S06.05 renders the same mock class as an uppercase badge); `formatDay` for every meta date; month groups by `createdAt`; "Xem vé" uses `go` (shell tab); "Xem yêu cầu Chụp ngay" is shown (`/instant/:id` exists); `EarningRow` breakdown lines instead of `MoneyBreakdown` (mock `.brk`).
- S05.03 gate: `booking.checkout?.method == bankQr` (checkout is kept after payment); tickets have no method field, so a refunded ticket cancel always asks `pendingRefund` once (the server's null keeps wallet tickets from opening the sheet).

V2 / V1 contract differences found:

- V2 added `confirmBy` but never set it; #141 sets it. V2's `awaiting_account` meant "bank transfer without payer"; for the three policy paths above it now also means "waiting for the customer's choice for 24 hours".
- 26 V2-era domain tests and one Functions test now confirm the paying account first (or pay by wallet) because those cancels no longer send at once; none was weakened.
- Plan Contract `RefundAccountDeps.payments` dropped (it is `bookings.store`), `disputes` added.
- `REFUND_ACCOUNT_CONFIRM_HOURS` and `needsAccountChoice` live in `escrow.ts` (import cycle), exported from the index.
- `PaymentSweepResults` gains `refundAccountsConfirmed` and `confirmFailed`.

Extra strings beyond the plan's l10n block:

- Task 9: `refundAccountLookupLimit`, `refundAccountLookupError`, `refundAccountAlreadySent`, `refundAccountFailed`, `refundAccountLoadError`; fix round: `refundAccountLookupStale`, `refundAccountBackToPayer`, `refundAccountWentTo`.
- Task 10: `paymentsLoadError`, `payMetaToday`, `payTitleBooking`, `payDetailRefund`.

## Skipped emulator suites (written, not run; CI runs them)

- Rules: `app_flutter/firebase/rules-test/rules.test.mjs`, describe `S22.01 payment history` (owner reads `users/{uid}/payments/*`, another user cannot, no client writes).
- Functions integration: `test/integration/payer_history.test.ts`, `test/integration/refund_account.test.ts` (cancel → awaiting → choose payer → done, notice, row, masked view, permission, idempotency), and the updated `test/integration/dispute.test.ts` (split refund waits, `pendingRefund({disputeId})`, choose, done).

## Deploy order

1. **Firestore rules and indexes** first: the `users/{uid}/payments` read rule, and V2's index `refunds (status, confirmBy)` that `awaitingRefundsDue` needs. `users/{uid}/payments` ordered by `createdAt desc` uses the automatic single-field index; the subcollection id `payments` equals the root collection's, so root composite indexes on `payments` also cover the rows (nothing queries a `payments` collection group).
2. **Cloud Functions** (behind `BLAZE_ENABLED`; off on the dev project today, so this runs on the emulators): trigger `onRefundWritten`; callables `pendingRefund`, `lookupRefundAccount`, `chooseRefundAccount` (both bind the existing `PAYOUT_ACCOUNT_KEY`, no new secret); the changed `onPaymentWritten` and `onBookingWrite`; `paymentClock` with the step `confirmDueRefundAccounts`. Existing rows are written when each payment or refund is next touched; a one-off backfill is not part of this unit (the seed computes them).
3. **App** last (S22.01, S22.04 and the entry points read the new rows, flag and callables).

## Carry

- **#140 / #202 Chụp ngay and #203 S21 fee:** their bank-QR refunds without a paying account wait in `awaiting_account` with no customer entry (S22.04 answers `not_eligible`; S22.01 reads "Đang hoàn"). Staff work (S23.03) until those subjects get an account choice.
- **#148** owns the rest of S09.02 mock parity.
- **#205 (optional):** the money blockers of S22.02 read `payments`/`refunds` directly (Decision 12); they may read the history rows now that they exist (same kinds and amounts).
- **#207 (Huỷ phần bàn giao):** its milestone-2 refund should decide whether it waits for the account (`waitForAccount`) like the other policy refunds; without it, a payer refund is sent at once and a no-payer one waits and shows on S22.01.
- **`booking_payment_paths` no-payer refunds** (`late_payment_draft_expired`, `provider_not_accepting`) wait without `refundAccountNeeded` (no booking to show it on); they are reachable from S22.01 only. Raising the flag would be a domain change.
- **#299:** the owner moves the Firebase backend (Functions, rules, domain) to booking-be after #141 lands; these triggers, callables and the clock step move with it.
- Pre-existing, not changed: integration `event_paid.test.ts` calls `registerEvent` with `provider: 'momo'` while the callable reads `method`.

## Deferred

- Plan Deferred list: email delivery of the data copy; Google Play's web deletion request; real account-name lookup and real bank refunds (licensed intermediary, #129 Deferred; refunds stay on the fake gateway); staff tools for failed/manual refunds and `needs_review` payments (S23.02, S23.03, #83); jobs/quotes payments (#139); export of chat and post images as files; remote recommender filtering of hidden profiles; self-hosted parity of the new collections (phase 2 #90, now booking-be).
- Final-wave Deferred (the other final-review items were fixed in 9bb382e9 and 95bf27ee):
  - **Per-customer lookup counter** (real-adapter issue): lookups are capped per refund, not per customer, so a customer with many no-payer refunds waiting gets 20 a day each. With the real bank adapter this is a holder-name oracle risk (enumerating accounts through the name lookup); the cap must move to the customer when the real adapter lands. The fake lookup only echoes the caller's own name.
  - **`refund_write` refresh on lookup-only writes**: `onRefundWritten` has no filter on what changed, so a write that only bumps `accountLookups` / `candidate` (each name lookup) also runs the notice check and the payer-row refresh (idempotent churn).
  - **Ticket day and title stale on event edit**: ticket rows carry the event's day and title as written at the last payment or refund refresh; editing the event does not refresh them (booking rows do refresh on day or photographer change).
  - **`monthLabel` reuses the `earningsMonth*` keys** (S06.05's) for S22.01 month headings; give S22.01 its own keys only if the wording diverges.
  - **Epoch fallback for a malformed `createdAt`**: the app reads a malformed `createdAt` as `paidAt`, then as the epoch (oldest group), to keep the row; the epoch group is a placeholder, not a real date.
- Cost notes: a refunded ticket cancel and each view of a resolved dispute with a refund call `pendingRefund` once; a cancel with a refund may refresh the payer row up to three times (booking, payment and refund triggers; idempotent).

## Questions for the owner

1. **Data copy delivery** (plan question 1, #205's half): an in-app download link valid 7 days (built) instead of "gửi link qua email trong 48 giờ"?
2. **Refund to another person's account** (plan question 2): built as allowed, with the looked-up name shown and kept on the refund. Keep, or require the name to match the paying account?
3. **No answer on S22.04** (plan question 3): built as "send to the paying account after 24 hours"; without a paying account the refund waits. Keep?
4. **S22.01 status pill vs S06.05 badge** (Task 10): S22.01 follows the mock's plain-text pill, S06.05 renders the same mock class as an uppercase badge. Should the two screens match, and which way?
