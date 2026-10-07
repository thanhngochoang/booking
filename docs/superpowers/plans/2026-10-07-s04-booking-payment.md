# S04 · Đặt lịch & thanh toán (100% upfront, VietQR, one payment model) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (2026-10-02, user):** this plan changes `firestore.rules`, indexes and adds Functions (one HTTP function). Write the rules tests and the integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A customer pays 100% of the package when booking, by Chuyển khoản QR (VietQR, default), MoMo or ZaloPay; S04.04 shows the VietQR with a 15-minute countdown, "Tạo QR mới" and "Mở app ngân hàng"; the server learns about money through a signed webhook and a 5-minute reconciliation, and handles exact, short, over, late and duplicate transfers automatically. Event tickets use the same payment-method model and the same S04.04 screen. Everything runs on the fake gateway (emulator and dev project only); the real licensed intermediary is deferred.

**Architecture:** `packages/domain` gets one payment model shared by bookings and tickets: `PaymentMethod` (`bank_qr`, `momo`, `zalopay`, cards reserved) separate from `PaymentProvider` (the intermediary; only `fake` is wired), a renamed `PaymentGateway` port (`createPayment`, `queryPayment`, `refund`, `verifyWebhook`, spec §9), a pure transfer settlement (`decideTransfer`/`applyTransfer`) applied inside the subject's own transaction (booking draft → requested, ticket hold → paid), excess refunds (overpaid, late, duplicate, underpaid at expiry) kept apart from policy refunds, one refund dispatch rule (a gateway throw leaves the refund `pending` for a re-send under the same id), and `reconcilePayments` (query stale intents, expire, re-send refunds). The `FakePaymentGateway` builds a real VietQR payload (EMVCo + CRC16), signs webhooks with HMAC and keeps its transfers in a ledger port so reconciliation can find a "lost webhook". Functions stay thin: `createPayment`/`checkPayment`/`confirmFakePayment`/`simulateFakeTransfer` callables, the `paymentWebhook` HTTP function, and a payment step in the existing 5-minute `eventClock` schedule (no new Scheduler job). The booking keeps `amount` instead of `deposit`/`remaining`. The app gets `PayMethod` (one enum for S04.03 and S11.03), `PaymentInstructions`, a shared `features/payment/` (S04.04 for bookings and tickets, fake sheets) and the 100% copy on S04/S05/S06.

**Tech Stack:** TypeScript (`packages/domain`, `node --test`; Functions v2 `onCall`, `onRequest`, `onSchedule`, `node:crypto` HMAC in the adapter only), Firestore rules and indexes; Flutter, Riverpod 3, go_router, freezed (`Booking`), `qr_flutter` (existing), `flutter_test`, fakes in `test/support/`.

**Spec:** `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §1 (M1–M3), §3 (3.1 methods, 3.2 flow, 3.3 wrong transfers), §5 (refund by method), §9 (ports), §12 (S04.03, S04.04), §13 (tests); `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §4.1–4.2 (100%, "bỏ deposit/remaining"); `docs/superpowers/specs/screens/booking.md` S04.03, S04.04, S05.02, S05.03; main spec `2026-10-01-remaining-screens.md` §2 (S04 rows), §3g (ledger, escrow); `docs/legal/terms-and-help-notes.md` P1, P7, P10, P11; mock `docs/design/ui-mock.html` `#S04.03`, `#S04.04`, `#S05.02`, `#S05.03`, `#S06.01`, `#S06.03`, `#S11.03`, `#S11.04-pending`; handover `docs/superpowers/handover/ledger-events-10c.md` ("Carried to #129").

**Issue:** #129 (S04 · Đặt lịch & thanh toán). Item 1 of the issue ("Chặn `confirmFakePayment` ngoài emulator và project dev") is **DONE** (`app_flutter/firebase/functions/src/infra/fake_payments.ts`, `assertFakePaymentsAllowed`, plan 10c Task 9); this plan reuses that gate and does not re-plan it. Item 5 ("Kết nối tổ chức trung gian thật") is Deferred.

**Branch:** `plan/129-s04-booking-payment` (claimed with `project.py claim 129`), PR into `develop` titled `feat(payments): 100% upfront, VietQR and one payment model for bookings and tickets [#129]`.

**Execution wave:** 1 (cross-plan review 2026-10-07). **Blocked by:** none. **Owns (other plans consume, never redefine):** the payment model and callables (`createPayment`, `checkPayment`, `confirmFakePayment`, VietQR, `PaymentInstructions`), refund dispatch and idempotency by refund id, the payment-subject extension point (Decision 22), the shared booking-draft builder and order gates (Decision 23), the Dart `PayMethod`, `PayMethodList`/`PayMethodPicker` and `features/payment/` (S04.04 for every subject).

## Global Constraints

- Payments spec M2: "Khách trả **100%** khi đặt … Không còn "cọc"." M3: "Phương thức lúc ra mắt: **chuyển khoản VietQR** (mặc định) và **ví MoMo, ZaloPay**. Thẻ nội địa và thẻ quốc tế thiết kế sẵn chỗ, bật sau."
- Payments spec §3.1: "`PaymentProvider` (tổ chức trung gian …) tách khỏi `PaymentMethod`: `bank_qr` (mặc định), `momo`, `zalopay`; để sẵn `domestic_card`, `intl_card` (tắt bằng cờ cấu hình)."
- Payments spec §3.2: "`createPayment` tạo `Payment` (`status = created`, `expiresAt` = +15 phút)"; webhook "kiểm chữ ký, idempotent theo mã giao dịch của họ, lưu bản gốc"; "Job **đối soát** mỗi 5 phút hỏi trạng thái các khoản `created` quá 3 phút".
- Payments spec §3.3 table, verbatim: "Đúng số tiền, đúng nội dung, còn hạn | `paid`"; "Thừa tiền | `paid`; phần thừa hoàn về tài khoản đã chuyển (§5)"; "Thiếu tiền | giữ `created` tới hết hạn; hết hạn → hoàn toàn bộ số đã nhận"; "Chuyển sau khi hết hạn | hoàn toàn bộ số đã nhận; booking không tạo"; "Không khớp được khoản nào (sai nội dung) | `needs_review`, staff xử lý ở S23.02". `PaymentStatus`: `created`, `paid`, `expired`, `needs_review`, `refunded`, `partially_refunded` (plus the existing `failed`).
- Payments spec §5: "Ví MoMo / ZaloPay | API hoàn của ví"; "VietQR | **Chi một khoản** về tài khoản đã chuyển (số tài khoản, tên, ngân hàng lấy từ webhook)"; "`Refund` thêm `method` (`gateway` \| `bank_transfer`), `destinationAccount?` (che, mã hoá), `providerRef`, `failureReason?`". The S22.04 confirmation sheet is issue #141 (Decision 11).
- Payments spec §9: "`PaymentGateway { createPayment, queryPayment, refund, verifyWebhook }`"; "Bản cài đặt: `Fake*Gateway` (emulator, dev, test; mô phỏng webhook và chuyển sai)"; "Webhook là HTTP function (`onRequest`) có kiểm chữ ký; mọi lệnh gọi ra ngoài có `idempotencyKey`."
- Payments spec §8: `LedgerEntryType` uses `payment_received` instead of `deposit_received` (the payout types `platform_fee`, `tax_withheld`, `gateway_fee`, `payout_fee`, `revenue_received` arrive with #134).
- Owner ruling 2026-10-07: money does not need to work for real; everything goes through the fake gateway, gated by `fakePaymentsAllowed()` (emulator with a `demo-*` project, or the dev project `booking-c1922`). No real intermediary, no new Secret Manager secret, no deploy-only gate. `booking-c1922` is on Spark: everything is tested on the emulators (`scripts/backend-local.sh`).
- Owner rule (2026-10-07): anything that creates a booking calls `ProviderOrderGate` (`packages/domain/src/booking_ports.ts`, `acceptsOrders`, error `not_accepting_orders`); `createBookingDraft` already does, `createPayment` re-checks (Decision 9).
- CLAUDE.md: business rules in `packages/domain` (no Firebase or Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1` (`REGION` in `config.ts`); Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; imports `package:photobooking/...`, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; one `AppButton.primary` per screen; every screen/sheet in `ScreenCode`; `AsyncView` for every `AsyncValue`.
- `data-model/README.md`: ids are ULIDs/opaque strings, instants are UTC ISO strings in the domain (`Timestamp` only in adapters), money is integer VND, enums are string codes.
- Commits: Conventional Commits, subject ends with `[#129]`, message ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Clock steps (shared rule with every plan that adds a step to `bookingClock`/`eventClock`): add the step as a named entry at the end of the handler's step list, each in its own try/catch that logs and continues; do not change existing parameters; a new dependency goes into an optional last `extras` object (`EventClockExtras` / `BookingClockExtras` in the same scheduled file; create the interface if absent, one optional field per plan, defaulting to its `live*Deps()`).
- Tests: domain `cd packages/domain && npm test && npm run lint && npm run typecheck`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; Flutter from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`: `flutter test --no-pub --timeout 60s <file or folder>` one folder at a time (never the whole suite in one command; bounded pumps, no endless animation or timer left running: inject `clockProvider`, `pump(Duration)` instead of `pumpAndSettle` around `SignatureLoader`/countdowns); `flutter analyze`. Rules tests (`app_flutter/firebase/rules-test/rules.test.mjs`) and Functions integration tests (`test/integration/*.test.ts`) are written, not run.

## Decisions

1. **Field rename, legacy read.** `Booking.deposit`/`remaining` become `amount` (= `serviceSnapshot.price`, paid in full); `depositProvider` → `paymentMethod`, `depositPaidAt` → `paidAt`, `depositRefunded` → `refundedAmount`, `depositRefundedAt` → `refundedAt`; new `draftExpiresAt`. Adapters (Functions and app) read the old names when the new ones are missing (`amount ?? deposit`, …) so emulator/dev data needs no backfill; writes use only the new names. Spec 10-05 §4.2 ("Bỏ `deposit` / `remaining`") wins over the current data model, which this plan updates. `services/api` (self-hosted, phase 2) keeps its SQL until #90.
2. **Method vs provider.** `Payment.method` is what the customer chose; `Payment.provider` is the intermediary (`fake` today). Legacy payments with `provider: 'momo'|'vnpay'` read as `method: momo|bank_qr`, `provider: fake` (`legacyMethodOf`). The 10c mapping "Chuyển khoản QR / ZaloPay → `vnpay`" (owner question 5 of 10c) is retired: the app sends `bank_qr`, `momo`, `zalopay`.
3. **Payment code** (the transfer content) = `PB` + the last 6 characters of the payment ULID (Crockford base32, upper case), shown as `PB 7F3K2Q`; no uniqueness guard. Matching parses `PB`+6 from the free text (case, spaces and punctuation ignored, as bank apps mangle them). Two live (`created`) payments with the same code → the transfer is `ambiguous` → `needs_review` (≈ n²/2³¹ per 15-minute window; logged).
4. **One transaction per transfer.** A transfer is applied inside the subject's own transaction (booking: `BookingStore.runTransaction`; ticket: `EventStore.runTransaction`), which reads the payment and the subject and writes payment, ledger, refund(s) and subject together. Idempotency is `payment.appliedTransferIds` checked inside that transaction (webhook retries, webhook vs reconciliation race, fake confirm twice). `payment_events/{provider}_{eventId}` is an audit copy of every gateway event (raw body, outcome), written after; it is not the idempotency guard.
5. **Cumulative short transfers.** While a payment is `created` and not expired, transfers add up in `receivedAmount`; reaching `amount` makes it `paid` (excess refunded). At expiry the reconciliation refunds everything received and not yet refunded (`underpaid_expired`). Spec only says "giữ created tới hết hạn" (owner question 1).
6. **Refund kinds.** `Refund.kind`: `policy` (cancel/decline/expiry/event cancel; a share of the price) or `excess` (overpaid, late, duplicate, underpaid at expiry; money that was never part of the price). Escrow release and earnings/payout net amounts subtract **policy** refunds only (`policyRefundTotal`); legacy refunds without `kind` count as policy. Without this an overpaid booking would pay the photographer less than the price (Review Focus 1).
7. **Refund destination (this plan).** `bank_qr` refunds are `bank_transfer` to the payer account captured from the first matched transfer (`Payment.payer`, number encrypted with the existing `AccountCipher`/`PAYOUT_ACCOUNT_KEY`, last 4 shown); wallet refunds are `gateway`. A `bank_transfer` refund with no payer account waits in the new status `awaiting_account` (never happens with the fake, whose transfers always carry a payer). #141 adds the S22.04 confirmation window for policy refunds and the "Dùng tài khoản khác" form on top of this.
8. **Refund dispatch (10c carry N2).** One rule for bookings and tickets: the gateway answers `done` → `done`; `failed` → `failed` + `manual`; `pending` (asynchronous provider) → stays `pending` with `providerRef`; a **throw** → stays `pending`, `attempts + 1`, `lastAttemptAt` set, re-sent by `reconcilePayments` after 10 minutes under the **same refund id** (10c carry: "the real gateway adapter must treat `refundId` as the idempotency key", now in the port contract and pinned by a fake test). A refund webhook event may move `pending|failed → done|failed` and `failed → done`; `done` never changes. The outcome is written only while the stored refund is not `done`.
9. **Gate on payment too, and once more at settlement (single place).** `createPayment` re-checks `ProviderOrderGate.acceptsOrders(booking.photographerId)` and refuses with `not_accepting_orders` (a provider revoked between the draft and the payment must not receive money). Money that still arrives for such a draft (webhook, reconciliation, `checkPayment`, fake confirm) is settled by `settleBookingTransfer`, the single place for this rule: it reads `acceptsOrders` before its transaction and, when false, refunds 100% as a policy refund with reason `provider_not_accepting` instead of moving the draft to `requested`; the booking stays `draft` and the draft sweep frees the day. Nothing is stranded and no provider who stopped accepting orders receives a booking. #135 (S21 Decision 15) relies on this and adds no rule of its own.
10. **Draft lifetime.** `createBookingDraft` sets `draftExpiresAt = createdAt + 30 min`. Each payment sets `expiresAt = now + 15 min` and pushes `draftExpiresAt = max(draftExpiresAt, expiresAt + 5 min)`. "Tạo QR mới" is refused with `deadline_passed` once `now + 15 min > createdAt + 60 min` (the photographer's day stays "Chờ" at most ~65 minutes; owner question 2). The draft sweep queries `status == draft && draftExpiresAt <= now`; legacy drafts without the field are left (dev only; `backend-local.sh --fresh`).
11. **#141 boundary.** This plan builds the refund model (`method`, `destination`, `awaiting_account`, payer capture) and sends bank refunds to the payer account at once. S22.04 (confirm / other account), the 24-hour default and the payment history are #141.
12. **Payments mode.** Functions `paymentsMode()` = `fake` where `fakePaymentsAllowed()` is true, else `off`. In `off` the gateway refuses every call with `not_eligible` (the app already maps it to `bookPaymentsOff` "Thanh toán chưa mở trên máy chủ này."). Before this plan production silently created fake intents; now it refuses until a real adapter exists.
13. **Reconciliation runs in the existing 5-minute `eventClock` export** (`handleEventClock` then `handlePaymentClock`, each in its own try/catch): no new Cloud Scheduler job (cost spec §13.4, §14.2). The ticket-refund re-send moves from `runEventSweeps` (`refund_resend`) into `reconcilePayments` (both subjects, one query), so it is not done twice.
14. **10c carry M7.** `checkTicketPayment` still asks the gateway only about the registration's current payment; an earlier intent of the same hold paid with another method now arrives through the webhook or the reconciliation query and is refunded as `duplicate`/`late` by `settleTicketTransfer`. No change to `checkTicketPayment` beyond the port rename.
15. **Tickets on S04.04.** S11.03 with "Chuyển khoản QR" opens the same S04.04 screen (route `/e/:eventId/pay/:regId`, screen code `S04.04`, label `ticket`); the ticket QR expires with the hold (`expiresAt = holdExpiresAt`, 10 minutes), so the countdown shows the shorter of the two. "Tạo QR mới" on a ticket is not offered (the hold ends with the QR; the customer registers again). When the registration becomes `paid`, S04.04 lands on `/bookings?tab=events&highlight={regId}` (the same route `register_sheet.dart` uses for free tickets), so #138's ticket primer (S17.03, asked when a highlighted ticket shows) also follows a paid ticket.
16. **Wallets.** MoMo/ZaloPay: `createPayment` returns `payUrl`; fake mode shows `FakeWalletSheet` (confirm through `confirmFakePayment`), real mode launches `payUrl`; both then show S04.04's wait variant ("Đang chờ xác nhận", vibration loader) until the booking/registration stream moves on. On app resume S04.04 calls `checkPayment`.
17. **"Mở app ngân hàng".** Fake mode: opens `FakeTransferSheet` (Chuyển đúng / thiếu / thừa / sau khi QR hết hạn) that calls `simulateFakeTransfer`, which posts a signed webhook through the same handler as `paymentWebhook`. Real mode (the bank-app chooser with VietQR deeplinks from the intermediary) is Deferred; with `REAL_PAYMENTS=true` and no real adapter the server is `off` anyway.
18. **Milestones (#130).** The 50/50 milestone release needs delivery approval (S05.06, #130). Until #130 lands, the existing single release (`completed` + 24 h, `bookingClock` step 5) releases the full amount minus policy refunds. The S04.03 copy already states the product rule ("chuyển cho thợ theo 2 mốc"); money is fake, and the ledger records that `REAL_PAYMENTS` must stay off until #130 and the real adapter land.
19. **Unified fake confirmation.** One callable `confirmFakePayment({paymentId})` for bookings and tickets (it builds a synthetic exact transfer); `confirmFakeTicketPayment` is removed, the app's `EventRepository.confirmFakeTicketPayment` and `BookingRepository.confirmFakePayment` move to `PaymentsRepository.confirmFake`. Nothing is deployed (Spark), so renamed callables need no compatibility window; likewise `createDeposit` → `createPayment`, `checkDeposit` → `checkPayment`.
20. **No underpaid UI.** S04.04 does not show "đã nhận một phần" (payments are server-only reads and the mock has no such state); the rule line already says short transfers are refunded automatically.
21. **`refund_done` for bookings** (found while planning): `booking_notifications.ts` fires on `refundedAt`, which nothing ever set. The booking refund dispatch now sets `refundedAt` (and `refundedAmount`) on the booking when a refund becomes `done`.
22. **Payment subjects of other plans (extension point, cross-plan review 2026-10-07).** Every money flow of the app runs on this plan's model: Chụp ngay (#140, subject `instant_request`) and the verification fee (#135, subject `verification_fee`) add a subject; quotes (#139), studio (#136) and collaborator jobs (#151, when they charge a customer) create ordinary bookings (subject `booking`). An extension subject never copies settlement code: its owner (1) adds its code to `PaymentSubject` in `escrow.ts`, (2) builds its payment with `newSubjectPayment` and its instructions with `issuePaymentInstructions`, (3) implements a `SubjectSettler` (`settle`, `expire`, `dispatchRefund`, `statusOf`) over its own store, using the pure `applyTransfer`, `excessRefund`, `expireUnpaid`, `sendRefundOnce` and `mergeRefundOutcome` of this plan, and (4) registers it in `liveSettlementDeps().subjects`. `settleTransfer`, `confirmFakePayment` and `reconcilePayments` (expiry and refund re-send) dispatch on `payment.subjectType`: `booking` and `event_registration` are built in; any other subject goes to `deps.subjects[subjectType]`, and a subject with no settler is `unmatched` (audit row, nothing written). Refund re-send for every subject is `reconcilePayments`' alone (no subject sweep re-sends refunds). In the app the owner adds a `PaySubject` variant, its route and its `case` in `PaymentController` (status stream → paid/gone, title row, whether "Tạo QR mới" is offered); S04.04 and `PayMethodList` are reused, never rebuilt.
23. **One booking-draft builder and one order gate (cross-plan review 2026-10-07).** `createBookingDraft` builds its booking with the pure `buildBookingDraft(input)` and checks `assertOrderAllowed(deps, {customerId, providerId})` (today: `ProviderOrderGate` → `not_accepting_orders`). Every other order path calls the same two functions instead of building a booking or calling the gate itself: quote bookings (#139 `createQuoteBookingDraft`), studio bookings (#136), collaborator jobs (#151 where they create a booking), and, for the gate only, Chụp ngay invites (#140, per invitee with the non-throwing `orderBlocker`). Later plans extend them in place, once: #130 adds `revisionsIncluded` to `buildBookingDraft`, #136 the studio fields, #139 the quote fields (`source`, `quoteId`, `terms`), #144 (S20) the `BlockGate` check (`blocked`) to `orderBlocker`. A field added there therefore reaches every order path.

## Needs the owner

1. **Short transfers that are topped up** before the QR expires: complete the payment (default, Decision 5), or refund each short transfer and ask for a new exact one?
2. **How long a draft may hold the photographer's day** across "Tạo QR mới": 60 minutes from the booking request (default, Decision 10), or another cap?

## Contract

### Existing code this plan builds on (checked 2026-10-07 on `develop` 812afd6)

Task 1 Step 1, Task 3 Step 1 and Task 4 Step 1 re-check; adapt and ledger any difference; if a name below does not exist, stop and report.

- Domain (`packages/domain/src`): `booking.ts` (`PAYMENT_PROVIDERS = ['momo','vnpay','fake']`, `Booking` with `deposit`, `remaining`, `depositRefunded`, `depositProvider`, `depositPaidAt`, `depositRefundedAt`), `booking_policy.ts` (`DEPOSIT_PERCENT = 30`, `computeDeposit`, `computeRefund(deposit, percent)`, `refundPercent`, `DRAFT_EXPIRY_MINUTES = 30`), `booking_ports.ts` (`PaymentGateway { createDepositIntent, issueRefund, checkPaymentStatus }`, `BookingTx`, `BookingStore.findUnpaidDraftsOlderThan`, `findReleasableEscrows`, `getPaymentsForBooking`, `getRefundsForPayment`, `BookingDeps { store, services, providers, contacts, gateway, clock, ids }`), `create_booking.ts`, `create_deposit.ts` (`createDeposit`, key `dep_${bookingId}_${provider}`), `handle_payment.ts` (`handlePaymentNotification`, `confirmFakePayment`, `checkDeposit`), `refunds.ts` (`dispatchRefund`: a throw propagates), `commit_transition.ts` (policy refunds, `releaseAfter`), `booking_sweeps.ts` (step 1 drafts, step 5 release with `totalRefunded` of all refunds), `escrow.ts` (`PAYMENT_STATUSES`, `Payment`, `Refund`, `LEDGER_ENTRY_TYPES` with `deposit_received`, `createDepositPayment`, `applyRefundToPayment`, `releaseEscrowPayment`, `verifyPaymentLedgerInvariant`), `fake_payment_gateway.ts`, `event_payments.ts` (`ticketIdempotencyKey`, `parseTicketProvider`, `newTicketPayment`, `issueTicketIntent`, `dispatchTicketRefund` (throw → `failed`), `resendTicketRefund`, `handleTicketPayment`, `confirmFakeTicketPayment`, `checkTicketPayment`, `refundTicket`, `TICKET_REFUND_RESEND_AFTER_MINUTES`), `event_registration.ts` (`registerEvent` with `provider`, returns `payUrl`), `event_ports.ts` (`EventTx` payment/refund/ledger methods, `EventStore.pendingTicketRefunds`, `EventPaymentDeps`), `event_sweeps.ts` (`runEventSweeps` step `refund_resend`), `booking_notifications.ts` (`refund_done` on `depositRefundedAt`), `notification_render.ts` ("Cọc …" bodies), `earnings_ports.ts`/`refresh_earnings.ts` (`refundedTotal`), `payout_use_cases.ts` (`net = amount − refundedTotal`), `payout_ports.ts` (`AccountCipher`), `vn_banks.ts` (`VN_BANKS`, `bankByCode`), `ids.ts`, `errors.ts`, `index.ts`. Test support: `test/support/booking_world.ts`, `event_world.ts`, `payout_world.ts`; memory stores `memory_booking_store.ts`, `memory_event_store.ts`.
- Functions (`app_flutter/firebase/functions/src`): `config.ts` (`REGION`, `CALLABLE_OPTIONS`, `PAYMENT_CALLABLE_OPTIONS`, `SCHEDULE_OPTIONS`, `DEV_PROJECT_ID`, `currentProjectId`, `PAYOUT_ACCOUNT_KEY`, `payoutsMode`), `infra/fake_payments.ts` (`fakePaymentsAllowed`, `assertFakePaymentsAllowed`), `infra/live_booking.ts` (`getSharedFakeGateway`, `liveBookingDeps`), `infra/live_event.ts` (`liveEventPaymentDeps`), `infra/live_payout.ts` (lazy `aesGcmCipher(PAYOUT_ACCOUNT_KEY.value())`), `infra/booking_firestore.ts` (`PAYMENTS_COLLECTION`, `REFUNDS_COLLECTION`, `LEDGER_COLLECTION`, `bookingToFirestore`/`FromFirestore`, `paymentToFirestore`/`FromFirestore`, `refundToFirestore`/`FromFirestore`, `FirestoreBookingStore`), `infra/event_firestore.ts`, `infra/earnings_firestore.ts`/`payout_firestore.ts` (`refundedTotal`), `callables/booking.ts` (`handleCreateDeposit`, `handleConfirmFakePayment`, `handleCheckDeposit`), `callables/event.ts` (`handleConfirmFakeTicketPayment`, `handleCheckTicketPayment`, `handleRegisterEvent`), `callables/errors.ts` (`TRANSPORT_CODE`), `scheduled/event_clock.ts` (`handleEventClock`), `scheduled/booking_clock.ts`, `index.ts` exports `createDeposit`, `confirmFakePayment`, `checkDeposit`, `confirmFakeTicketPayment`, `checkTicketPayment`, `eventClock` (every 5 minutes); `seed/fixtures.ts` (payments `seed-payment-<bookingId>`), `seed/README.md`. No `onRequest` function exists yet.
- Rules/indexes: `payments`, `refunds`, `ledger_entries` are `allow read, write: if false`; indexes `bookings (status, createdAt)`, `payments (escrowStatus, releaseAfter)`, `payments (eventId, status, escrowStatus)`, `refunds (subjectType, status, createdAt)`.
- App: `lib/core/payments.dart` (`PaymentProviderCode { momo, vnpay }`, `PayMethod { bankQr, momo, zaloPay }` with `.provider`), `lib/core/widgets/provider_picker.dart` (`ProviderPicker`, `PayMethodPicker`, `_ProviderButton`), `lib/data/booking/` (`booking.dart` freezed `Booking`, `booking_rules.dart` (`BookingRules.depositPercent`, `computeDeposit`, top-level `depositFor`, `refundAmountAt`), `booking_repository.dart` (`createDeposit`, `confirmFakePayment`, `checkDeposit`, `CreateDepositResponse`, `ConfirmPaymentResponse`, `CheckDepositResponse`), `firestore_booking_repository.dart`, `payments_mode.dart` (`realPaymentsProvider` = `REAL_PAYMENTS`)), `lib/data/events/event_repository.dart` (`register(..., PaymentProviderCode? provider)`, `RegisterOutcome.payUrl`, `confirmFakeTicketPayment`, `checkTicketPayment`, fake), `firestore_event_repository.dart`, `lib/features/booking/` (`booking_flow_state.dart` `provider`, `depositVnd`; `booking_flow_controller.dart` `submit` → `createDeposit`, `GoToPayment`; `booking_sheet_page.dart` `_handleOutcome`; `steps/review_step.dart`; `payment_pending_screen.dart` (S04.04, `checkDeposit`, "Đổi cổng"); `fake_payment_sheet.dart`; `booking_detail_screen.dart`; `booking_view_rules.dart`; `cancel_sheet.dart`; `decline_sheet.dart`), `features/work/work_screen.dart` (`workDepositPaid`), `features/events/` (`register_controller.dart` `method`, `register_sheet.dart` `_pay`, `ticket_payment_sheet.dart` `openTicketPayment`/`TicketPaymentSheet`, `tickets_tab.dart` `_continuePayment`), `lib/app/router.dart` (`/b/:id/pay`, `/e/:eventId`), `lib/core/screen_codes.dart` (`awaitingPayment = 'S04.04'`), `AppIcons` (`wallet`, `lock`, `info`; no `qrCode`, `copy`), `CountdownText(deadline, builder, onExpired, now)`, `SignatureLoader(size, wave)`, `BookingCard`, `MoneyBreakdown`/`MoneyLine`, `EmptyState`, `showAppSheet`, `externalLauncherProvider`, `clockProvider`. Tests: `test/support/fake_booking_repository.dart`, `booking_world.dart`, `event_world.dart`, `booking_fixtures.dart`; `test/features/booking/*` (review_step, payment_pending_screen, submit, booking_flow_controller, booking_sheet, booking_detail_screen, cancel_sheet, decline_sheet, my_bookings_screen, booking_flow_e2e, booking_lifecycle_e2e), `test/features/events/register_sheet_test.dart`, `tickets_tab_test.dart`, `test/data/booking/*`.

### Data model (Firestore, server-only unless stated)

- `bookings/{id}` (client read by the two parties, unchanged rules): `amount` (int VND, = price), `paymentMethod` (`bank_qr|momo|zalopay|null` until paid), `paidAt`, `refundedAmount`, `refundedAt`, `draftExpiresAt` (Timestamp); removed: `deposit`, `remaining`, `depositProvider`, `depositPaidAt`, `depositRefunded`, `depositRefundedAt` (read as fallback only).
- `payments/{id}` (server-only): existing fields + `method`, `provider` (`fake`), `code` (`PB7F3K2Q`), `expiresAt`, `receivedAmount`, `refundedAmount`, `appliedTransferIds` (array, capped at 20), `payer` (`{bankBin, bankName, accountLast4, accountNumberEnc, holderName}` | null), `instructions` (`{qr: {payload, bankBin, bankName, accountName, accountMasked, content} | null, payUrl: string | null}` | null). `status` adds `expired`, `needs_review`.
- `refunds/{id}` (server-only): + `kind` (`policy|excess`), `method` (`gateway|bank_transfer`), `destination` (`{bankBin, bankName, accountLast4, accountNumberEnc, holderName, source: 'payer'|'customer'}` | null), `failureReason`, `attempts`, `lastAttemptAt`; `status` adds `awaiting_account`.
- `ledger_entries`: type `payment_received` replaces `deposit_received` (legacy entries read as `payment_received`); one entry per applied transfer with the transfer amount.
- `payment_events/{provider}_{eventId}` (new, server-only): `{provider, kind: 'transfer'|'refund', eventId, paymentId|null, outcome: SettlementOutcome|'refund_applied'|'refund_unknown', raw: string (≤ 16 KB), receivedAt}`.
- `fake_gateway_transfers/{transactionId}` (new, server-only, written only where fake payments are allowed): the fake intermediary's own record of a simulated transfer (`TransferEvent` fields + `code`), read by `FakePaymentGateway.queryPayment`.

### Domain (packages/domain/src) — names later tasks cite exactly

```ts
// payments.ts (new)
export const PAYMENT_METHODS = ['bank_qr', 'momo', 'zalopay', 'domestic_card', 'intl_card'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];
export const ENABLED_PAYMENT_METHODS: readonly PaymentMethod[] = ['bank_qr', 'momo', 'zalopay'];
/** An enabled method code, else DomainError('invalid_argument'). */
export function parsePaymentMethod(v: unknown): PaymentMethod;
export const PAYMENT_PROVIDERS = ['fake', 'ninepay', 'zalopay', 'vnpay', 'nganluong'] as const; // moved here from booking.ts
export type PaymentProvider = (typeof PAYMENT_PROVIDERS)[number];
/** Data written before #129: 'momo' → momo, 'vnpay' → bank_qr, anything else → null. */
export function legacyMethodOf(provider: unknown): PaymentMethod | null;
export const PAYMENT_EXPIRY_MINUTES = 15;
export const DRAFT_HOLD_MINUTES = 30;
export const DRAFT_MAX_MINUTES = 60;
export const LATE_TRANSFER_GRACE_MINUTES = 5;
export const RECONCILE_AFTER_MINUTES = 3;
export const REFUND_RESEND_AFTER_MINUTES = 10; // TICKET_REFUND_RESEND_AFTER_MINUTES stays as an alias
export function paymentCodeOf(paymentId: string): string;   // 'PB' + last 6 chars, upper case
export function displayPaymentCode(code: string): string;   // 'PB7F3K2Q' → 'PB 7F3K2Q'
export function paymentCodeIn(content: string): string | null; // 'ck pb-7f3k2q cam on' → 'PB7F3K2Q'
export type RefundMethod = 'gateway' | 'bank_transfer';
export function refundMethodOf(method: PaymentMethod): RefundMethod; // bank_qr → bank_transfer, else gateway

// vietqr.ts (new)
export interface VietQrInput { readonly bankBin: string; readonly accountNumber: string; readonly amount: number; readonly content: string }
export function crc16Ccitt(s: string): string;            // CRC-16/CCITT-FALSE, 4 upper-case hex
export function buildVietQrPayload(i: VietQrInput): string; // EMVCo dynamic QR, NAPAS GUID A000000727, service QRIBFTTA, currency 704, country VN, tag 62/08 = content

// payment_ports.ts (new; booking_ports.ts re-exports PaymentGateway from here)
export interface VietQrInstructions { readonly payload: string; readonly bankBin: string; readonly bankName: string; readonly accountName: string; readonly accountMasked: string; readonly content: string }
export interface PaymentInstructions {
  readonly paymentId: string; readonly method: PaymentMethod; readonly amount: number;
  readonly code: string;        // display form 'PB 7F3K2Q'
  readonly expiresAt: string;   // ISO
  readonly qr: VietQrInstructions | null;
  readonly payUrl: string | null;
}
export interface PayerBankAccount { readonly bankBin: string; readonly accountNumber: string; readonly holderName: string }
export interface TransferEvent {
  readonly kind: 'transfer'; readonly provider: PaymentProvider;
  readonly transactionId: string;   // the provider's id: idempotency of the event
  readonly paymentId?: string;      // wallets: our order id
  readonly content?: string;        // bank transfers: the text the payer typed
  readonly amount: number; readonly receivedAt: string;
  readonly payer?: PayerBankAccount | null;
}
export interface RefundEvent {
  readonly kind: 'refund'; readonly provider: PaymentProvider; readonly refundId: string;
  readonly status: 'done' | 'failed'; readonly providerRef?: string; readonly failureReason?: string;
}
export type GatewayEvent = TransferEvent | RefundEvent;
export interface PaymentGateway {
  readonly provider: PaymentProvider;
  createPayment(r: {
    paymentId: string; subjectType: PaymentSubject; subjectId: string; amount: number;
    method: PaymentMethod; code: string; expiresAt: string; returnUrl?: string;
  }): Promise<{ providerRef?: string; qr?: VietQrInstructions; payUrl?: string }>;
  /** Every incoming movement the provider knows for this payment (reconciliation, "Kiểm tra"). */
  queryPayment(r: { paymentId: string; method: PaymentMethod; code: string; providerRef?: string }): Promise<readonly TransferEvent[]>;
  /**
   * `refundId` IS the idempotency key: every adapter MUST send it to the provider, so a repeated
   * call (re-send after a crash or a throw) never pays twice and returns the first outcome.
   * A throw means "outcome unknown": the refund stays `pending` and is sent again under the same id.
   */
  refund(r: {
    refundId: string; paymentId: string; amount: number; method: PaymentMethod;
    providerRef?: string; destination?: PayerBankAccount;
  }): Promise<{ status: 'done' | 'pending' | 'failed'; providerRef?: string; failureReason?: string }>;
  /** Parses a webhook; throws DomainError('permission_denied') when the signature does not verify. */
  verifyWebhook(r: { headers: Readonly<Record<string, string | undefined>>; rawBody: string }): Promise<readonly GatewayEvent[]>;
}

// escrow.ts (changed)
export const PAYMENT_STATUSES = ['created', 'paid', 'expired', 'needs_review', 'failed', 'refunded', 'partially_refunded'] as const;
export interface StoredBankAccount { readonly bankBin: string; readonly bankName: string; readonly accountLast4: string; readonly accountNumberEnc: string; readonly holderName: string }
// Payment gains: method, provider (PaymentProvider from payments.ts), code, expiresAt, receivedAmount,
//   refundedAmount, appliedTransferIds, payer?: StoredBankAccount | null,
//   instructions?: { qr: VietQrInstructions | null; payUrl: string | null } | null
export const REFUND_STATUSES = ['awaiting_account', 'pending', 'done', 'failed'] as const;
export type RefundKind = 'policy' | 'excess';
export type ExcessReason = 'overpaid' | 'late_transfer' | 'duplicate_transfer' | 'underpaid_expired';
// Refund gains: kind, method: RefundMethod, destination?: (StoredBankAccount & { source: 'payer' | 'customer' }) | null,
//   failureReason?, attempts, lastAttemptAt?
export const LEDGER_ENTRY_TYPES = ['payment_received', 'ticket_received', 'refund_issued', 'escrow_released', 'payout_paid', 'fee_charged', 'adjustment'] as const;
/** Σ amount of refunds whose kind is not 'excess' (legacy refunds without kind count). */
export function policyRefundTotal(refunds: readonly Refund[]): number;
// applyRefundToPayment(...) → kind 'policy', method/destination from the payment, refundedAmount += amount,
//   status 'awaiting_account' for bank_transfer without payer, else 'pending'
export function excessRefund(p: {
  payment: Payment; refundId: string; amount: number; reason: ExcessReason; ledgerEntryId: string; now: Date;
}): { payment: Payment; refund: Refund; ledgerEntry: LedgerEntry }; // status/escrow unchanged; refundedAmount += amount
// verifyPaymentLedgerInvariant(p, refunds, entries): Σ *_received === p.receivedAmount and Σ |refund_issued| === Σ refunds.amount

// payment_settlement.ts (new)
export type TransferDecision = 'paid' | 'underpaid' | 'late' | 'duplicate' | 'already_applied';
/** Pure, spec §3.3: what one transfer does to a payment. */
export function decideTransfer(p: Payment, t: TransferEvent): { decision: TransferDecision; excess: number };
/** Pure: the payment and ledger entry after a transfer (receivedAmount, appliedTransferIds, payer first-wins, paid + paidAt). */
export function applyTransfer(p: {
  payment: Payment; transfer: TransferEvent; payer: StoredBankAccount | null; ledgerEntryId: string; now: Date;
}): { payment: Payment; ledgerEntry: LedgerEntry; decision: TransferDecision; excess: number };
export type SettlementOutcome = TransferDecision | 'unmatched' | 'ambiguous';
export interface PaymentLookup {
  byId(id: string): Promise<Payment | null>;
  /** Payments with this code in created | expired | paid, newest first, at most 3. */
  byCode(code: string): Promise<readonly Payment[]>;
  /** created, createdAt <= before, oldest first. */
  staleCreated(before: Date, limit: number): Promise<readonly Payment[]>;
  /** created, expiresAt <= now. */
  expiredCreated(now: Date, limit: number): Promise<readonly Payment[]>;
  /** pending refunds (both subjects) whose lastAttemptAt (else createdAt) <= before. */
  pendingRefunds(before: Date, limit: number): Promise<readonly Refund[]>;
  getRefund(id: string): Promise<Refund | null>;
  recordEvent(e: { provider: PaymentProvider; kind: 'transfer' | 'refund'; eventId: string; paymentId: string | null; outcome: string; raw: string | null }): Promise<void>;
}
export interface SettlementDeps {
  readonly bookings: BookingDeps;          // gains cipher (below)
  readonly events: EventPaymentDeps;       // gains cipher (below)
  readonly payments: PaymentLookup;
  readonly cipher: AccountCipher;
  readonly clock: Clock;
}
export async function settleTransfer(deps: SettlementDeps, t: TransferEvent): Promise<SettlementOutcome>;
export async function applyRefundEvent(deps: SettlementDeps, e: RefundEvent): Promise<'refund_applied' | 'refund_unknown'>;
/** The HTTP handler's body: verify, then settle each event; returns outcomes for the audit. */
export async function handlePaymentWebhook(deps: SettlementDeps, req: { headers: Readonly<Record<string, string | undefined>>; rawBody: string }): Promise<readonly string[]>;
export async function reconcilePayments(deps: SettlementDeps, onError?: (step: string, id: string, e: unknown) => void):
  Promise<{ queried: number; settled: number; expired: number; refundsResent: number }>;

// booking side (handle_payment.ts is replaced by booking_payments.ts; create_deposit.ts by create_payment.ts)
export async function createPayment(deps: BookingDeps, input: { bookingId: string; customerId: string; method: unknown; renew?: unknown; returnUrl?: string }): Promise<PaymentInstructions>;
export async function checkPayment(deps: BookingDeps, input: { bookingId: string; customerId: string }): Promise<{ paid: boolean; booking: Booking | null; instructions: PaymentInstructions | null }>;
export async function settleBookingTransfer(deps: BookingDeps, paymentId: string, t: TransferEvent, payer: StoredBankAccount | null): Promise<TransferDecision>;
export async function dispatchRefund(deps: BookingDeps, refund: Refund, payment: Payment): Promise<Refund>; // refunds.ts, Decision 8
export async function confirmFakePayment(deps: SettlementDeps, caller: { uid: string }, raw: unknown):
  Promise<{ subjectType: PaymentSubject; paymentStatus: PaymentStatus; subjectStatus: string }>;
export async function simulateFakeTransfer(deps: SettlementDeps & { fake: FakePaymentGateway }, caller: { uid: string; name: string }, raw: unknown):
  Promise<{ outcome: SettlementOutcome | 'recorded' }>;
// raw: { paymentId, amount: int > 0, late?: boolean, deliverWebhook?: boolean (default true) }. Payer only. Builds the transfer
// (content = displayPaymentCode(code), payer FAKE_PAYER with holder = normalizeHolderName(caller name) ?? 'KHACH THU NGHIEM',
// receivedAt = late ? expiresAt + 1 min : now), fake.recordTransfer(...), then unless deliverWebhook === false
// runs handlePaymentWebhook(deps, fake.webhookFor([transfer])) — the HTTP function's own code path. Returns 'recorded' as
// outcome when the webhook is not delivered.

// ---- extension point for other subjects (Decision 22) ----
// escrow.ts: PaymentSubject stays 'booking' | 'event_registration' here; #140 adds 'instant_request', #135 adds 'verification_fee'.
// payment_ports.ts
export interface SubjectSettler {
  /** Applies one transfer inside the subject's own transaction; same contract as settleBookingTransfer (idempotent by transactionId). */
  settle(paymentId: string, t: TransferEvent, payer: StoredBankAccount | null): Promise<TransferDecision>;
  /** A `created` payment past expiresAt: status expired, excess refund of what was received (expireUnpaid), in the subject's transaction. */
  expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'>;
  /** Sends one refund (sendRefundOnce) and stores the outcome (mergeRefundOutcome) in the subject's transaction. */
  dispatchRefund(refund: Refund, payment: Payment): Promise<Refund>;
  /** The subject's status code after a payment ('searching', 'paid', …), for confirmFakePayment's answer. */
  statusOf(subjectId: string): Promise<string>;
}
// SettlementDeps gains: readonly subjects?: Readonly<Partial<Record<PaymentSubject, SubjectSettler>>>;
// settleTransfer / confirmFakePayment / reconcilePayments dispatch on payment.subjectType (booking, event_registration built in;
//   else deps.subjects[subjectType]; missing → 'unmatched'); PaymentLookup.pendingRefunds covers every subject.

// create_payment.ts — shared by every subject
export function newSubjectPayment(p: {
  id: string; subjectType: PaymentSubject; subjectId: string; payerId: string; payeeId: string;
  amount: number; method: PaymentMethod; provider: PaymentProvider; idempotencyKey: string; now: Date; expiresAt: Date;
}): Payment; // status created, escrowStatus held, code = paymentCodeOf(id), receivedAmount 0, refundedAmount 0, appliedTransferIds [], payer null
export async function issuePaymentInstructions(gateway: PaymentGateway, payment: Payment,
  save: (providerRef: string | undefined, instructions: { qr: VietQrInstructions | null; payUrl: string | null }) => Promise<void>,
  returnUrl?: string): Promise<PaymentInstructions>; // gateway.createPayment outside any transaction, then save() (the caller's short tx, only while still created)
export function instructionsOf(payment: Payment): PaymentInstructions | null; // from the stored payment (reuse on a second tap)
/** "Kiểm tra" for any subject: queryPayment for each created payment, settleTransfer every transfer found; true when one is now paid. */
export async function checkSubjectPayments(deps: SettlementDeps, payments: readonly Payment[]): Promise<boolean>;

// payment_settlement.ts — pure helpers used by the built-in subjects and by SubjectSettler implementations
export function expireUnpaid(p: { payment: Payment; refundId: string; ledgerEntryId: string; now: Date }):
  { payment: Payment; refund: Refund | null; ledgerEntry: LedgerEntry | null }; // status expired; refund (kind excess, underpaid_expired) only when receivedAmount − refundedAmount > 0

// refunds.ts — Decision 8 in two halves, shared by every subject
/** Calls gateway.refund once under refund.id; never throws for a gateway failure. awaiting_account → returned unchanged, no call. */
export async function sendRefundOnce(d: { gateway: PaymentGateway; cipher: AccountCipher; clock: Clock }, refund: Refund, payment: Payment): Promise<Refund>;
/** The stored refund after an outcome: null (leave as is) when stored is done; else next. */
export function mergeRefundOutcome(stored: Refund, next: Refund): Refund | null;

// create_booking.ts — Decision 23: the one booking-draft builder and the one order gate
export interface BookingDraftInput {
  readonly id: string; readonly customerId: string; readonly photographerId: string;
  readonly service: ServiceRecord;          // a quote passes a synthetic record (#139)
  readonly day: string; readonly start: string; readonly place: Booking['place']; readonly note: Booking['note'];
  readonly now: Date;
}
export function buildBookingDraft(i: BookingDraftInput): Booking; // status draft, serviceSnapshot, end, amount = upfrontAmount(price),
  // draftExpiresAt = now + DRAFT_HOLD_MINUTES, version 1. Extended in place by #130 (revisionsIncluded), #136 (studio fields), #139 (quote fields)
export interface OrderGateDeps { readonly providers: ProviderOrderGate } // #144 adds `readonly blocks?: BlockGate`
/** Every order path (owner rule 5). Today: acceptsOrders false → 'not_accepting_orders'. #144 appends BlockGate → 'blocked'. */
export async function orderBlocker(deps: OrderGateDeps, p: { customerId: string; providerId: string }): Promise<'not_accepting_orders' | 'blocked' | null>;
export async function assertOrderAllowed(deps: OrderGateDeps, p: { customerId: string; providerId: string }): Promise<void>; // throws DomainError(code)

// BookingDeps gains: readonly cipher: AccountCipher
// BookingStore: findUnpaidDraftsOlderThan → findExpiredDrafts(now: Date, limit?: number)
// booking_policy.ts: DEPOSIT_PERCENT/computeDeposit removed; export function upfrontAmount(price: number): number (= price; throws on < 0);
//   computeRefund(amount, percent) (parameter renamed)

// ticket side (event_payments.ts)
// newTicketPayment gains method, code, expiresAt (= holdExpiresAt), provider = gateway.provider
export async function settleTicketTransfer(deps: EventPaymentDeps, paymentId: string, t: TransferEvent, payer: StoredBankAccount | null): Promise<TransferDecision>;
export async function dispatchTicketRefund(deps: EventPaymentDeps, refund: Refund, payment: Payment): Promise<Refund>; // exported, Decision 8
// registerEvent raw input: `method` replaces `provider` (parsePaymentMethod); RegisterResult: `instructions?: PaymentInstructions` replaces `payUrl`
// EventPaymentDeps gains: readonly cipher: AccountCipher; EventStore.pendingTicketRefunds removed (PaymentLookup.pendingRefunds)
// handleTicketPayment, confirmFakeTicketPayment (domain), resendTicketRefund removed

// fake_payment_gateway.ts (rewritten)
export const FAKE_COLLECTION_ACCOUNT = { bankBin: '970418', bankName: 'BIDV', accountNumber: '962400003812', accountMasked: '9624 •••• 3812', accountName: 'TAI KHOAN THU HO THU NGHIEM' } as const;
export const FAKE_PAYER = { bankBin: '970436', accountNumber: '0071000123456' } as const; // holder = the caller's folded name
export interface FakeTransferLedger { add(t: TransferEvent & { code: string }): Promise<void>; listFor(q: { paymentId: string; code: string }): Promise<readonly TransferEvent[]> }
export interface MessageSigner { sign(body: string): string; verify(body: string, signature: string): boolean }
export class FakePaymentGateway implements PaymentGateway {
  readonly provider = 'fake';
  constructor(opts: { ledger: FakeTransferLedger; signer: MessageSigner });
  readonly issuedRefunds: Map<string, number>; readonly refundCalls: string[];
  refundFailureId?: string; refundThrowId?: string; refundPendingId?: string;
  /** What the fake intermediary would POST for these events (header 'x-fake-signature'). */
  webhookFor(events: readonly GatewayEvent[]): { headers: Record<string, string>; rawBody: string };
  /** The fake intermediary books a simulated transfer (queryPayment finds it later). */
  recordTransfer(t: TransferEvent & { code: string }): Promise<void>;
}
export class MemoryFakeTransferLedger implements FakeTransferLedger { /* tests */ }
```

### Callables and HTTP (Functions, `asia-southeast1`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `createPayment` (callable, `PAYMENT_CALLABLE_OPTIONS`, secrets `PAYOUT_ACCOUNT_KEY`) | `{bookingId, method: 'bank_qr'|'momo'|'zalopay', renew?: bool}` | `PaymentInstructions` | `invalid_argument`, `phone_required`, `not_found`, `permission_denied`, `conflict` (not a draft), `day_taken`, `deadline_passed` (draft too old for a new QR), `not_accepting_orders`, `not_eligible` (payments off) |
| `checkPayment` (callable) | `{bookingId}` | `{paid: bool, status: BookingStatus, instructions: PaymentInstructions|null}` | `not_found`, `permission_denied` |
| `confirmFakePayment` (callable, fake gate first) | `{paymentId}` | `{subjectType, paymentStatus, subjectStatus}` | `fake_payments_disabled` (failed-precondition), `not_found`, `permission_denied` |
| `simulateFakeTransfer` (callable, fake gate first) | `{paymentId, amount, late?, deliverWebhook?}` | `{outcome}` | `fake_payments_disabled`, `invalid_argument`, `not_found`, `permission_denied` |
| `paymentWebhook` (`onRequest`, region `asia-southeast1`, 256 MiB, 30 s, `maxInstances` 10, secrets `PAYOUT_ACCOUNT_KEY`) | POST, raw JSON body, header `x-fake-signature` | `200 {ok: true, outcomes}` | 405 not POST; 404 when the provider is `fake` and fake payments are not allowed; 413 body > 64 KB; 401 bad signature; 500 unexpected (the provider retries; idempotent) |
| `registerEvent` (changed) | `{eventId, quantity, name, method?}` | registration + `instructions?` | as today |
| `checkTicketPayment` (unchanged contract) | `{eventId, registrationId}` | `{paid, status}` | as today |
| removed | `createDeposit`, `checkDeposit`, `confirmFakeTicketPayment` | — | — |
| `eventClock` (existing schedule, every 5 minutes) | — | runs `handleEventClock()` then `handlePaymentClock()` (`reconcilePayments`) | each step logs its own failure |

### Rules and indexes

- Rules: explicit `match /payment_events/{id} { allow read, write: if false; }` and `match /fake_gateway_transfers/{id} { allow read, write: if false; }` next to `event_hashtags`; `payments`, `refunds`, `ledger_entries` unchanged (server-only); `bookings` unchanged (server-written).
- Indexes added: `payments (status, createdAt)`, `payments (status, expiresAt)`, `payments (code, createdAt desc)`, `bookings (status, draftExpiresAt)`, `refunds (status, lastAttemptAt)`. Removed after a grep shows no query uses them: `refunds (subjectType, status, createdAt)`, `bookings (status, createdAt)` (the draft sweep was its only user; check `findAutoCompletions` and others first).

### App (Dart) — names later tasks cite exactly

```dart
// lib/core/payments.dart (replaces PaymentProviderCode and the old PayMethod)
enum PayMethod {
  bankQr('bank_qr'), momo('momo'), zaloPay('zalopay');
  const PayMethod(this.code);
  final String code;
  /// 'vnpay' (data before #129) reads as bankQr; unknown → null.
  static PayMethod? fromCode(String? code);
  bool get isWallet => this != PayMethod.bankQr;
}

// lib/data/payments/payment_instructions.dart (new)
class VietQr { const VietQr({required this.payload, required this.bankBin, required this.bankName, required this.accountName, required this.accountMasked, required this.content}); … }
class PaymentInstructions {
  const PaymentInstructions({required this.paymentId, required this.method, required this.amount, required this.code, required this.expiresAt, this.qr, this.payUrl});
  final String paymentId; final PayMethod method; final int amount; final String code; final DateTime expiresAt; final VietQr? qr; final String? payUrl;
  bool expiredAt(DateTime now) => !now.isBefore(expiresAt);
}
PaymentInstructions? paymentInstructionsFrom(Object? raw);

// lib/data/payments/payments_repository.dart (new)
enum FakeTransferKind { exact, short, over, late }
abstract class PaymentsRepository {
  /// confirmFakePayment: returns the subject status ('requested', 'paid', 'cancelled', …).
  Future<String> confirmFake(String paymentId);
  Future<String> simulateTransfer({required String paymentId, required int amount, bool late = false});
}
class FunctionsPaymentsRepository implements PaymentsRepository { … } // throws BookingException(code)
final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) => FunctionsPaymentsRepository());

// lib/data/booking/booking_repository.dart (changed)
class PaymentCheck { const PaymentCheck({required this.paid, this.instructions}); final bool paid; final PaymentInstructions? instructions; }
// BookingRepository: createDeposit/confirmFakePayment/checkDeposit removed;
Future<PaymentInstructions> createPayment({required String bookingId, required PayMethod method, bool renew = false});
Future<PaymentCheck> checkPayment({required String bookingId});
// Booking (freezed): amount, paymentMethod (String?), paidAt, refundedAmount, refundedAt, draftExpiresAt replace deposit*/remaining
// BookingRules: depositPercent/computeDeposit/depositFor removed; refundAmountAt(b, now) = b.amount * pct ~/ 100

// lib/data/events/event_repository.dart (changed)
// register(eventId, {quantity, name, PayMethod? method}); RegisterOutcome.instructions (PaymentInstructions?) replaces payUrl;
// confirmFakeTicketPayment removed (PaymentsRepository.confirmFake)

// lib/core/widgets/pay_method_picker.dart (renamed from provider_picker.dart; export from core.dart)
class PayMethodList extends StatelessWidget { const PayMethodList({super.key, required this.value, required this.onChanged, this.enabled = true}); } // S04.03 radiogroup
class PayMethodPicker extends StatelessWidget { … } // S11.03 button row, now on the new PayMethod
// ProviderPicker removed.

// lib/features/payment/ (new feature folder; Decision 22: #140 adds InstantPay(requestId), #135 adds VerificationFeePay(attemptId),
// each with its route and its case in PaymentController — no other S04.04 screen is built anywhere)
sealed class PaySubject { const PaySubject(); }
final class BookingPay extends PaySubject { const BookingPay(this.bookingId); final String bookingId; }
final class TicketPay extends PaySubject { const TicketPay(this.eventId, this.registrationId); final String eventId; final String registrationId; }
String payPathOf(PaySubject s); // '/b/{id}/pay' | '/e/{eventId}/pay/{regId}'
class PaymentScreen extends ConsumerStatefulWidget { const PaymentScreen({super.key, required this.subject, this.initial}); final PaySubject subject; final PaymentInstructions? initial; } // S04.04
/// After createPayment / registerEvent: bank_qr → push S04.04; wallet → FakeWalletSheet (fake) or launch payUrl (real), then S04.04.
Future<void> openPayment(BuildContext context, WidgetRef ref, {required PaySubject subject, required PaymentInstructions instructions, bool replace = false});
class VietQrCard extends StatelessWidget { const VietQrCard({super.key, required this.instructions, required this.title, required this.now, this.expired = false}); }
class FakeTransferSheet extends ConsumerStatefulWidget { const FakeTransferSheet({super.key, required this.instructions}); }
class FakeWalletSheet extends ConsumerStatefulWidget { const FakeWalletSheet({super.key, required this.instructions}); } // replaces FakePaymentSheet and TicketPaymentSheet
```

- Routes: `/b/:id/pay` → `PaymentScreen(subject: BookingPay(id), initial: state.extra as PaymentInstructions?)`; new `/e/:eventId/pay/:regId` → `PaymentScreen(subject: TicketPay(eventId, regId), initial: extra)`.
- `AppIcons` adds `qrCode = Symbols.qr_code_2_rounded`, `copy = Symbols.content_copy_rounded`, `bank = Symbols.account_balance_rounded`.
- Screen codes: unchanged (`awaitingPayment = 'S04.04'`; the ticket use passes `label: 'ticket'`).

### l10n (`lib/l10n/app_vi.arb`) — key: exact text

New:
- `bookPayFull`: "Thanh toán 100%"
- `bookHoldNote`: "Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả."
- `bookPayAmount`: "Thanh toán {amount}"
- `payMethodBankQrHint`: "Miễn phí · xác nhận ngay"
- `payQrTitle`: "Chuyển khoản QR"
- `payAwaiting`: "Chờ thanh toán" (replaces `payAwaitingDeposit`)
- `payQrTimeLeft`: "Còn {time}"
- `payQrTimeLeftLabel`: "QR còn hiệu lực {minutes} phút {seconds} giây"
- `payQrImageLabel`: "Mã VietQR {amount}, nội dung {code}"
- `payQrBank`: "Ngân hàng"
- `payQrBankNote`: "Tài khoản thu hộ của trung gian thanh toán"
- `payQrAccount`: "Số tài khoản"
- `payQrContent`: "Nội dung"
- `payCopy`: "Sao chép"
- `payCopied`: "Đã sao chép nội dung chuyển khoản"
- `payQrRule`: "Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động."
- `payNewQr`: "Tạo QR mới"
- `payOpenBankApp`: "Mở app ngân hàng"
- `payQrExpired`: "QR đã hết hạn"
- `payQrExpiredBody`: "Tạo QR mới để thanh toán. Tiền đã chuyển vào QR cũ sẽ được hoàn tự động."
- `payExpiredBadge`: "Hết hạn"
- `payChangeMethod`: "Đổi phương thức"
- `payWaitTitle`: "Đang chờ xác nhận"
- `payWaitBody`: "{method} chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ tới {time}."
- `payReopenWallet`: "Mở lại {method}"
- `payRegisterAgain`: "Đăng ký lại" (ticket QR expired with its hold)
- `fakeTransferTitle`: "Chuyển khoản thử"
- `fakeTransferBody`: "Bản dùng thử: không có tiền thật. Chọn cách chuyển để xem app xử lý."
- `fakeTransferExact`: "Chuyển đúng {amount}"
- `fakeTransferShort`: "Chuyển thiếu {amount}"
- `fakeTransferOver`: "Chuyển thừa {amount}"
- `fakeTransferLate`: "Chuyển sau khi QR hết hạn"
- `fakeTransferSent`: "Đã gửi giao dịch thử"
- `timelineNoMorePay`: "Không trả thêm tại buổi chụp" (replaces `timelinePayAtShoot`)
- `cancelYouGetBackPct`: "Bạn sẽ nhận lại ({pct}% số đã trả)" (replaces `cancelYouGetBack`)
- `workPaid`: "đã thanh toán {amount}" (replaces `workDepositPaid`)

Changed values (key unchanged):
- `phonePrivacy`: "Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán."
- `editProfilePhoneHint`: "Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán."
- `escrowNoticeHeld`: "{amount} đang được giữ an toàn"
- `escrowNoticeHeldPhotographer`: "{amount} đang được giữ, chuyển cho bạn theo 2 mốc"
- `payExpiredBody`: "Chưa nhận được tiền trong thời hạn nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại."
- `timelineSent`: "Đã gửi & thanh toán"
- `timelineExpired`: "Hết hạn, đã hoàn 100%"
- `detailPaidToast`: "Đã thanh toán {amount}, tiền được giữ an toàn." (placeholder `name` removed)
- `detailCancelCustomer`: "Huỷ yêu cầu · hoàn {pct}%"
- `cancelRefundPhotographer`: "{name} được hoàn 100%"
- `cancelDonePhotographer`: "Đã huỷ. {name} được hoàn 100%"
- `bookingsEmptyPendingBody`: "Yêu cầu đã thanh toán, đang chờ nhiếp ảnh gia nhận sẽ hiện ở đây."
- `workRequestExpired`: "Yêu cầu {name} đã hết hạn, đã hoàn 100%"
- `declineRefundNote`: "{name} được hoàn 100% ({amount}) và nhận lý do này."
- `declineDoneToast`: "Đã từ chối. {name} được hoàn 100%."
- `chatSysRequested`: "Đã thanh toán. Chờ nhiếp ảnh gia nhận trong 24 giờ."
- `earningsEmptyBody`: "Khoản đầu tiên hiện ở đây khi khách đặt lịch và thanh toán cho bạn."

Removed (after the last use is gone): `bookDepositToday`, `bookRemaining`, `bookPolicy`, `bookPay`, `escrowNoticeDeposit` (only S04.03 used it), `payAwaitingDeposit`, `payCheckAgain`, `payNotYet`, `payChangeProvider`, `payProviderFake`, `payProviderNamed`, `payProviderGeneric`, `payPendingTitle`, `payPendingBody`, `fakePaymentTitle`, `fakePaymentSuccess`, `fakePaymentCancel`, `timelinePayAtShoot`, `cancelYouGetBack`, `workDepositPaid`. `fakePayTitle`, `fakePayBody`, `fakePayConfirm`, `fakeTicketPayTitle`, `ticketPayFakeDisabled`, `ticketPayFailed` stay (used by `FakeWalletSheet`).

Server copy (`notification_render.ts`, Vietnamese, exact; the mock `#S17.01` text, identical to #138's Contract "Changed copies", so whichever plan lands second finds it already done): declined `Đã hoàn ${percent}% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.`; expired `Yêu cầu đã hết hạn. Đã hoàn ${percent}% số bạn đã trả.`; cancelled suffix ` Hoàn ${percent}% số bạn đã trả.`; `refund_done` body `Tiền buổi chụp #${bookingId.slice(-4).toUpperCase()} đã về tài khoản của bạn.`

## Review Focus

1. **Overpaid booking, then release** — the photographer must receive the full price after the dispute window; the excess refund must not be subtracted (today `booking_sweeps.ts` step 5 and `refundedTotal` subtract every refund). Pin: Task 2 `release after an overpaid transfer pays the full price` and Task 3 `refundedTotal ignores excess refunds` (earnings and payouts).
2. **Old QR paid after "Tạo QR mới"** — the old payment is `expired`; its transfer must be refunded in full (`late_transfer`) and the booking must still be paid exactly once by the new QR; paying both QRs in time refunds the second as `duplicate`. Pin: Task 2 `a transfer to an expired QR is refunded and does not pay the booking` and `two QRs paid in time: the second is refunded as duplicate`.
3. **Same transfer delivered twice** (webhook retry; webhook and reconciliation racing; fake confirm tapped twice) — applied once. Pin: Task 2 `the same transaction id applies once` (memory store, sequential and `Promise.all`) and Task 3 webhook test `a repeated webhook body changes nothing`.
4. **Gateway refund throws** — the refund stays `pending`, is re-sent after 10 minutes under the same id, and the fake pays once; a later `failed` result must not hide a `done` from the webhook. Pin: Task 2 `a throwing refund stays pending and is re-sent once under the same id` and `a refund webhook moves failed to done`.
5. **Webhook security** — a wrong signature, an empty body, or a fake-provider webhook on a project where fake payments are not allowed writes nothing. Pin: Task 3 `paymentWebhook: bad signature → 401, nothing written`, `fake provider on production project → 404`.

Also pinned (not in the five): a draft with a live QR is not swept (Task 2), `refund_done` fires for a booking refund (Task 2), S04.04 countdown reaching zero switches to the expired variant without a running timer (Task 6).

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`: Firestore $0.06/100K reads, $0.18/100K writes, $0.02/100K deletes (nam5 upper bound; Singapore **chưa xác nhận**); Scheduler $0.10/job/month beyond 3 free.

**Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s.

**Per user action (reads/writes):**

| Action | Reads | Writes | get / listener | Notes |
|---|---|---|---|---|
| S04.03 "Thanh toán" (createBooking + createPayment) | createBooking as today (~4) + createPayment ~5 (booking, availability, payments of booking ≤ 3, contact, photographer gate 1) | +3 (payment, instructions, booking `draftExpiresAt`) | callable | no pagination needed (≤ 3 payments per booking) |
| S04.04 open | 1 (existing `bookings/{id}` listener) | 0 | listener (status must flip live) | instructions come from the route or `checkPayment` |
| App resume on S04.04 (`checkPayment`) | ~4 | 0–5 (only if a transfer is found) | callable | |
| Webhook / simulated transfer | ~5 (payment by code: 1 query ≤ 3 docs, booking, availability, contact snapshot) | ~6 (payment, ledger, booking, booking event, audit `payment_events`, refund when excess) | — | was ~5 writes via `confirmFakePayment`; +1 audit |
| "Tạo QR mới" | ~4 | 3 (old expired, new payment, booking) | callable | |
| Reconciliation (per 5-minute run) | 3 queries (min 1 read each) + docs found | 0 normally | scheduled | |

**New functions and jobs:** callables `createPayment`, `checkPayment` (replace `createDeposit`, `checkDeposit`: no net change), `simulateFakeTransfer` (dev/emulator only: 0 in production), HTTP `paymentWebhook` (~1.2 per payment). Invocations/month: (b) ~400 payments (300 bookings + 100 paid tickets) → ~2,000; (c) ~4,000 payments → ~20,000 (charged at (c) under the Functions rule above). No new Scheduler job: reconciliation joins the existing `eventClock` (every 5 minutes, 8,640 runs/month), adding ~0.1 s CPU and 3 queries per run: 8,640 × 3 ≈ 26,000 reads/month plus documents found (≈ 2 per payment).

**Storage:** none. **Paid APIs:** none (fake). The real intermediary's fees are outside Google (Deferred).

**Conclusion:**
- (b) 1,000 MAU: reads ≈ 400 × 15 + 26,000 + 800 ≈ 33,000 → $0.02; writes +3 × 400 = 1,200 → $0.002; Functions within free tier → **≈ +$0.02/month**.
- (c) 10,000 MAU: reads ≈ 4,000 × 15 + 26,000 + 8,000 ≈ 94,000 → $0.06; writes +12,000 → $0.02; invocations ~20,000 + 8,640 schedule runs ≈ $0.01, CPU ≈ 4,000 × 0.2 + 864 ≈ 1,700 vCPU-s ≈ $0.06 (Tier 2, Functions rule above) → **≈ +$0.15/month**. Below $5: no mitigation needed. Firestore numbers use the nam5 upper bound (Singapore chưa xác nhận).

---

### Task 1: Domain — the 100% payment model, methods, gateway port and fake gateway

**Files:**
- Create: `packages/domain/src/payments.ts`, `packages/domain/src/vietqr.ts`, `packages/domain/src/payment_ports.ts`, `packages/domain/src/create_payment.ts`; tests `packages/domain/test/payments.test.ts`, `vietqr.test.ts`, `create_payment.test.ts`, `fake_payment_gateway.test.ts`
- Modify: `packages/domain/src/booking.ts` (rename fields, drop `PAYMENT_PROVIDERS`), `booking_policy.ts`, `booking_ports.ts` (re-export gateway, `BookingDeps.cipher`, `findExpiredDrafts`), `create_booking.ts` (`amount`, `draftExpiresAt`), `escrow.ts` (Payment/Refund/Ledger fields; `createDepositPayment` removed), `fake_payment_gateway.ts` (rewrite), `event_payments.ts` and `event_registration.ts` (method, code, expiresAt, instructions; still settling exact payments only, Task 2 adds the rest), `event_ports.ts` (`EventPaymentDeps.cipher`), `memory_booking_store.ts`, `memory_event_store.ts`, `index.ts`
- Rename: `packages/domain/src/handle_payment.ts` → `booking_payments.ts` (`git mv`; `checkDeposit` becomes `checkPayment`, `handlePaymentNotification` stays until Task 2)
- Delete: `packages/domain/src/create_deposit.ts`, `packages/domain/test/deposit.test.ts` (its cases move to `create_payment.test.ts`)
- Test support: `packages/domain/test/support/booking_world.ts`, `event_world.ts` (fake gateway with `MemoryFakeTransferLedger` and a test signer `{sign: b => 'sig:' + b.length, verify: (b, s) => s === 'sig:' + b.length}`, a reversible test cipher `enc:` + plain)
- Modify tests that build the old shapes: `create_booking.test.ts`, `booking_policy.test.ts`, `escrow.test.ts`, `event_payments.test.ts`, `event_registration.test.ts`, `transition_booking.test.ts`, `booking_sweeps.test.ts`

**Interfaces:**
- Consumes: `isId`, `newUlid`, `DomainError`, `requireCustomerPhone`, `ProviderOrderGate`, `AccountCipher` (`payout_ports.ts`), `VN_BANKS`.
- Produces: everything under Contract → Domain from `payments.ts`, `vietqr.ts`, `payment_ports.ts` (incl. the `SubjectSettler` interface), the changed `escrow.ts` types, `newSubjectPayment`, `issuePaymentInstructions`, `instructionsOf`, `buildBookingDraft`, `BookingDraftInput`, `OrderGateDeps`, `orderBlocker`, `assertOrderAllowed` (Decision 23; `createBookingDraft` and `createPayment` use them), `createPayment`, `checkPayment` (in this task a reported transfer whose amount covers the payment is applied through the existing `handlePaymentNotification`, fields renamed; Task 2 replaces that call with `settleBookingTransfer`), `FakePaymentGateway`, `MemoryFakeTransferLedger`, `upfrontAmount`, `findExpiredDrafts`.

- [ ] **Step 1: Contract check** of the domain names in "Existing code"; ledger any difference.
- [ ] **Step 2: Failing tests:**
  - `payments.test.ts`: `parsePaymentMethod accepts bank_qr, momo, zalopay`; `refuses domestic_card, intl_card, vnpay, '' and numbers with invalid_argument`; `legacyMethodOf maps momo → momo, vnpay → bank_qr, fake → null`; `paymentCodeOf takes PB and the last 6 characters upper-cased` (`01J9ZK3Q7F3K2Q` → `PB7F3K2Q`); `displayPaymentCode inserts one space`; `paymentCodeIn finds the code in 'CK pb-7f3k2q cam on', 'PB 7F3K2Q', 'NGUYEN VAN A PB7F3K2Q'`; `paymentCodeIn returns null without PB or with I/L/O/U in the six characters`; `refundMethodOf: bank_qr → bank_transfer, wallets → gateway`.
  - `vietqr.test.ts`: `crc16Ccitt('123456789') is 29B1`; `the payload for BIDV 962400003812, 1.500.000₫, 'PB 7F3K2Q' is exactly 00020101021238560010A0000007270126000697041801129624000038120208QRIBFTTA5303704540715000005802VN62130809PB 7F3K2Q6304064A`; `amount must be a positive integer and content ≤ 25 ASCII characters (else invalid_argument)`.
  - `booking_policy.test.ts`: `upfrontAmount is the full price`; `computeRefund(1500000, 50) is 750000`; remove the deposit cases.
  - `create_booking.test.ts`: `a draft carries amount = price, no deposit/remaining`; `draftExpiresAt is createdAt + 30 minutes`; `buildBookingDraft is pure and createBookingDraft writes exactly its result` (Decision 23); `orderBlocker returns not_accepting_orders for a provider who does not accept orders, null otherwise`; `assertOrderAllowed throws DomainError(not_accepting_orders)`.
  - `create_payment.test.ts` (shared helpers): `newSubjectPayment sets created, held, the PB code and zero received`; `instructionsOf rebuilds the stored instructions and returns null without them`.
  - `create_payment.test.ts`: `bank_qr returns instructions with the VietQR payload, display code and expiresAt = now + 15 min`; `momo returns a payUrl and no qr`; `a second tap with the same method reuses the live payment and does not call the gateway again`; `a second tap after the gateway failed re-issues instructions for the same payment`; `another method creates a second payment for the same draft`; `renew expires the live payment of that method and creates a new one with a new code`; `renew after 45 minutes is refused with deadline_passed` (createdAt + 60 < now + 15); `createPayment moves draftExpiresAt to expiresAt + 5 minutes`; `refuses a provider that no longer accepts orders with not_accepting_orders`; `refuses a non-draft with conflict, another customer with permission_denied, a lost day with day_taken, a customer without phone with phone_required`; `the payment amount is the booking amount`.
  - `fake_payment_gateway.test.ts`: `createPayment bank_qr uses the fake collection account (masked 9624 •••• 3812)`; `queryPayment returns the ledger's transfers for the payment id or code`; `refund is idempotent by refund id: two calls pay once` (10c carry); `refundFailureId → failed, refundThrowId → throws, refundPendingId → pending`; `webhookFor + verifyWebhook round-trips the events`; `verifyWebhook with a changed body throws permission_denied`.
  - `event_registration.test.ts` / `event_payments.test.ts`: `a paid registration creates a payment with method, code and expiresAt = holdExpiresAt`; `registerEvent returns instructions instead of payUrl`; `an unknown method is invalid_argument`; existing cases switch `provider: 'momo'` to `method: 'momo'`.
- [ ] **Step 3: Run** `cd packages/domain && npm test` → the new tests fail (missing modules/exports).
- [ ] **Step 4: Implement.**
  - `vietqr.ts` (pure, no Node APIs; UTF-8 bytes via a small manual encoder since content is ASCII-only after validation):
    ```ts
    const tlv = (tag: string, v: string) => `${tag}${String(v.length).padStart(2, '0')}${v}`;
    export function crc16Ccitt(s: string): string {
      let crc = 0xffff;
      for (let i = 0; i < s.length; i++) {
        crc ^= s.charCodeAt(i) << 8;
        for (let b = 0; b < 8; b++) crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
      }
      return crc.toString(16).toUpperCase().padStart(4, '0');
    }
    export function buildVietQrPayload(i: VietQrInput): string {
      // validate: digits-only bin/account, integer amount > 0, /^[\x20-\x7e]{1,25}$/ content
      const org = tlv('00', i.bankBin) + tlv('01', i.accountNumber);
      const mai = tlv('00', 'A000000727') + tlv('01', org) + tlv('02', 'QRIBFTTA');
      const body = tlv('00', '01') + tlv('01', '12') + tlv('38', mai) + tlv('53', '704')
        + tlv('54', String(i.amount)) + tlv('58', 'VN') + tlv('62', tlv('08', i.content)) + '6304';
      return body + crc16Ccitt(body);
    }
    ```
  - `create_payment.ts`: validate, `requireCustomerPhone`, gate (`deps.providers.acceptsOrders`), then one transaction (draft/owner/day checks, live payment lookup via `tx`'s payments of the booking, renew/expire, new payment with `code = paymentCodeOf(id)`, `expiresAt`, `receivedAmount 0`, `refundedAmount 0`, `appliedTransferIds []`, booking `draftExpiresAt`), then **outside** the transaction `deps.gateway.createPayment(...)` and a second short transaction that stores `providerRef` + `instructions` only while the payment is still `created` (same pattern as today's `issueTicketIntent`). Return `PaymentInstructions` built from the stored payment. Booking amount is `booking.amount`.
  - `checkPayment` (in `booking_payments.ts`, which replaces `handle_payment.ts`): booking not draft → `{paid: true}`; else for each `created` payment of the booking `gateway.queryPayment`; a transfer total that covers the amount goes through `handlePaymentNotification` (Task 2 swaps in `settleBookingTransfer` and the full §3.3 table); returns the latest live payment's instructions.
  - Ticket side: `newTicketPayment` takes `method`, sets `code`, `expiresAt = holdExpiresAt`, `provider = gateway.provider`; `issueTicketIntent` → `issuePaymentInstructions(gateway, payment, save, returnUrl?)` (Contract signature) shared by every subject (it lives in `create_payment.ts` and takes a store-agnostic `save(providerRef, instructions)` callback); booking and ticket payments are built with `newSubjectPayment`.
  - `create_booking.ts`: move the booking literal into `buildBookingDraft` and the gate into `orderBlocker`/`assertOrderAllowed` (Decision 23); `createBookingDraft` keeps its validation, phone check and transaction.
  - Booking field rename everywhere the type checker points (domain only in this task; Functions/app in Tasks 3–4).
- [ ] **Step 5: Run** `cd packages/domain && npm test && npm run lint && npm run typecheck` → pass (including `purity.test.ts`: no `node:crypto` in the domain).
- [ ] **Step 6: Commit** `feat(domain): 100% payment model, payment methods, VietQR and the gateway port [#129]` (TonyH trailer).

### Task 2: Domain — settlement, excess refunds, refund dispatch and reconciliation

**Files:**
- Create: `packages/domain/src/payment_settlement.ts`, `packages/domain/src/memory_payment_lookup.ts`, tests `packages/domain/test/payment_settlement.test.ts`, `reconcile_payments.test.ts`, `booking_payments.test.ts`
- Modify: `booking_payments.ts` (`settleBookingTransfer` replaces `handlePaymentNotification`; `checkPayment` uses it), `escrow.ts` (`excessRefund`, `policyRefundTotal`, `applyRefundToPayment` destination/status, invariant), `refunds.ts` (`dispatchRefund` Decision 8, booking `refundedAt`/`refundedAmount`), `commit_transition.ts` (refund through the new `applyRefundToPayment`; dispatch with the payment), `booking_sweeps.ts` (step 1 `findExpiredDrafts`; step 5 uses `policyRefundTotal`), `booking_notifications.ts` (`refundedAt`/`refundedAmount` instead of `depositRefunded*`), `notification_render.ts` (copy in Contract), `event_payments.ts` (`settleTicketTransfer`, `dispatchTicketRefund` Decision 8, `refundTicket` through the new refund shape; remove `handleTicketPayment`, `resendTicketRefund`, domain `confirmFakeTicketPayment`), `event_sweeps.ts` (drop step `refund_resend`), `event_ports.ts` (drop `pendingTicketRefunds`), `refresh_earnings.ts` + `payout_use_cases.ts` (net = amount − `policyRefundTotal`; the `refundedTotal` port keeps its name, its contract becomes "policy refunds only"), memory stores, `index.ts`
- Test: also `escrow.test.ts`, `booking_sweeps.test.ts`, `event_payments.test.ts`, `refresh_earnings.test.ts`, `payout_use_cases.test.ts`, `booking_notifications.test.ts`, `notification_render.test.ts`

**Interfaces:**
- Consumes: Task 1 types, `FakePaymentGateway`, `MemoryFakeTransferLedger`.
- Produces: `decideTransfer`, `applyTransfer`, `settleTransfer`, `settleBookingTransfer`, `settleTicketTransfer`, `applyRefundEvent`, `handlePaymentWebhook`, `reconcilePayments`, `confirmFakePayment` (generic), `simulateFakeTransfer`, `dispatchRefund`, `dispatchTicketRefund`, `sendRefundOnce`, `mergeRefundOutcome`, `expireUnpaid`, `checkSubjectPayments`, the `SettlementDeps.subjects` dispatch (Decision 22), `excessRefund`, `policyRefundTotal`, `PaymentLookup`, `SettlementDeps`, `MemoryPaymentLookup` (`packages/domain/src/memory_payment_lookup.ts`, over the memory booking and event stores, like the other memory stores).

- [ ] **Step 1: Failing tests:**
  - `payment_settlement.test.ts` (`decideTransfer`, table-driven, spec §3.3): `exact amount before expiry → paid, excess 0`; `over amount → paid, excess = difference`; `short → underpaid`; `two short transfers reaching the price before expiry → paid` (Decision 5); `receivedAt after expiresAt → late, excess = transfer amount`; `transfer to an expired payment → late`; `transfer to a paid payment → duplicate`; `an applied transaction id → already_applied`.
  - `booking_payments.test.ts`: `an exact transfer moves the draft to requested, sets paidAt, paymentMethod and acceptDeadline, and writes one payment_received entry`; `an overpaid transfer pays the booking and creates an excess refund of the difference to the payer account`; `a short transfer keeps the draft and the payment created`; `a transfer to an expired QR is refunded and does not pay the booking` (Review Focus 2); `two QRs paid in time: the second is refunded as duplicate` (Review Focus 2); `the same transaction id applies once` (sequential and `Promise.all`, Review Focus 3); `a transfer after the draft was swept refunds the whole amount` (existing late-payment rule, kind policy, reason `late_payment_draft_expired`); `the payer account is captured once, encrypted, last 4 kept`; `a bank_qr refund without payer waits in awaiting_account and is not sent`; `release after an overpaid transfer pays the full price` (Review Focus 1, through `runBookingSweeps` step 5); `a cancel 24–48 h before refunds 50% of the price as policy, and release pays the other 50%`; `ledger invariant: Σ received − Σ refunded matches the payment` (`verifyPaymentLedgerInvariant`).
  - `refunds` (in `booking_payments.test.ts`): `a throwing refund stays pending, attempts 1, lastAttemptAt set` (Review Focus 4); `a done refund sets booking.refundedAt and refundedAmount` (Decision 21); `a refund webhook moves failed to done; done never changes`; `a pending gateway answer keeps the refund pending with providerRef`.
  - `booking_payments.test.ts` (Decision 9): `a transfer for a draft whose provider stopped accepting orders refunds 100% (policy, provider_not_accepting) and leaves the draft`.
  - extension point (in `payment_settlement.test.ts`, with a test `SubjectSettler` for a made-up subject cast into `PaymentSubject`): `settleTransfer hands an unknown built-in subject to deps.subjects`; `a subject without a settler is unmatched and writes nothing but the audit`; `reconcilePayments expires and re-sends refunds of an extension subject through its settler`; `confirmFakePayment returns the settler's statusOf`; `checkSubjectPayments settles a transfer found by queryPayment and returns true`; `expireUnpaid refunds only received − refunded`; `sendRefundOnce: throw → pending, attempts + 1; failed → failed + manual; awaiting_account → no gateway call`; `mergeRefundOutcome never overwrites done`.
  - `settleTransfer` (in `payment_settlement.test.ts`): `matches by paymentId for wallets`; `matches by code inside free text for bank transfers`; `no payment for the code → unmatched, audit recorded, nothing else written`; `two live payments with the same code → ambiguous, nothing applied`; `a ticket payment is settled through the ticket handler (hold → paid, seats move)`; `a ticket transfer after the hold expired is refunded and the seats are not taken`.
  - `handlePaymentWebhook`: `verifies, settles each event and returns outcomes`; `a bad signature throws permission_denied and writes nothing`.
  - `reconcile_payments.test.ts`: `a created payment older than 3 minutes with a transfer in the fake ledger is settled` (lost webhook); `an expired created payment becomes expired and refunds what was received` (`underpaid_expired`); `an expired payment with nothing received is just expired`; `a pending refund older than 10 minutes is re-sent once under the same id and the fake pays once` (Review Focus 4); `a refund sent less than 10 minutes ago is left alone`; `one failing payment does not stop the others (onError called)`.
  - `booking_sweeps.test.ts`: `a draft with a live QR is not swept` (`draftExpiresAt` in the future); `an expired draft is swept and its day freed`.
  - `confirmFakePayment`/`simulateFakeTransfer`: `only the payer may confirm`; `confirm builds an exact transfer and pays a booking`; `confirm pays a ticket`; `simulate short then exact completes the payment`; `simulate late is refunded`; `simulate with deliverWebhook false only writes the fake ledger (the reconciliation finds it)`.
  - `refresh_earnings.test.ts`/`payout_use_cases.test.ts`: `net ignores excess refunds` (Review Focus 1).
  - `notification_render.test.ts`: the four new bodies (Contract), no "Cọc" anywhere.
- [ ] **Step 2: Run** `cd packages/domain && npm test` → the new tests fail.
- [ ] **Step 3: Implement.** The hard part is the booking handler; sample:
  ```ts
  export async function settleBookingTransfer(deps: BookingDeps, paymentId: string, t: TransferEvent,
      payer: StoredBankAccount | null): Promise<TransferDecision> {
    const box: { refunds: Refund[]; payment: Payment | null } = { refunds: [], payment: null };
    // Decision 9: the gate is a plain read before the transaction (provider id from a pre-read of payment → booking)
    const accepting = await gateOfPayment(deps, paymentId); // true when the booking or payment is missing (the tx decides)
    const decision = await deps.store.runTransaction(async (tx) => {
      box.refunds = []; box.payment = null;                // a retried transaction starts clean
      const now = deps.clock.now();
      const p0 = await tx.getPayment(paymentId);
      if (!p0 || p0.subjectType !== 'booking') throw new DomainError('not_found');
      const booking = await tx.getBooking(p0.subjectId);
      const day = booking ? await tx.getAvailabilityDay(booking.photographerId, booking.day) : null;
      // ---- writes from here ----
      const applied = applyTransfer({ payment: p0, transfer: t, payer, ledgerEntryId: deps.ids.newId(), now });
      if (applied.decision === 'already_applied') return applied.decision;
      let p = applied.payment;
      await tx.addLedgerEntry(applied.ledgerEntry);
      if (applied.decision === 'paid') {
        const live = booking?.status === 'draft' && day?.state === 'pending' && day.bookingId === booking.id;
        if (live && accepting) { /* booking → requested, paymentMethod, paidAt, acceptDeadline, escrowStatus held, event row (today's body) */ }
        else {
          const r = applyRefundToPayment({ payment: p, refundId: deps.ids.newId(), percent: 100,
            ledgerEntryId: deps.ids.newId(), reason: live ? 'provider_not_accepting' : 'late_payment_draft_expired', now });
          p = r.payment; await tx.addRefund(r.refund); await tx.addLedgerEntry(r.ledgerEntry); box.refunds.push(r.refund);
        }
      }
      if (applied.excess > 0) {
        const reason: ExcessReason = applied.decision === 'paid' ? 'overpaid'
          : applied.decision === 'late' ? 'late_transfer' : 'duplicate_transfer';
        const r = excessRefund({ payment: p, refundId: deps.ids.newId(), amount: applied.excess, reason,
          ledgerEntryId: deps.ids.newId(), now });
        p = r.payment; await tx.addRefund(r.refund); await tx.addLedgerEntry(r.ledgerEntry); box.refunds.push(r.refund);
      }
      await tx.setPayment(p); box.payment = p;
      return applied.decision;
    });
    for (const r of box.refunds) if (r.status === 'pending' && box.payment) await dispatchRefund(deps, r, box.payment);
    return decision;
  }
  ```
  `settleTicketTransfer` mirrors it on `EventTx` (writes are `tx.put*`, all reads first; live = registration `held`, event not cancelled, hold not expired; paid → registration `paid`, contact snapshot, seats move; else 100% refund `late_payment_hold_expired` and the registration refund mark, as today's `handleTicketPayment`). `applyTransfer` caps `appliedTransferIds` at the last 20 ids. `gateOfPayment` (private): a plain read of the payment and its booking, then `orderBlocker(deps, {customerId, providerId}) !== 'not_accepting_orders'`. `dispatchRefund`/`dispatchTicketRefund` are `sendRefundOnce` followed by a transaction that applies `mergeRefundOutcome` (the same two halves extension subjects use): `awaiting_account` → return unchanged; decrypt `destination.accountNumberEnc` with `deps.cipher`; `try { result = await gateway.refund(...) } catch { result = null }`; then a transaction that re-reads the refund and writes only while it is not `done` (`null` → `pending`, `attempts + 1`, `lastAttemptAt = now`). Booking: when the stored refund becomes `done`, set `booking.refundedAmount` (Σ done policy refunds) and `refundedAt`. `reconcilePayments` order: query stale → settle; expire; resend (Decision 13). `settleTransfer` encrypts the payer number with `deps.cipher` before calling the subject handler (bank transfers only), resolves `bankName` from `VN_BANKS` by BIN (unknown BIN → the BIN itself), and records the audit with `deps.payments.recordEvent`.
- [ ] **Step 4: Run** `cd packages/domain && npm test && npm run lint && npm run typecheck` → pass.
- [ ] **Step 5: Commit** `feat(domain): settle transfers, excess refunds, refund re-send and reconciliation [#129]`.

### Task 3: Functions — adapters, callables, webhook, payment clock, rules, indexes, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/fake_gateway.ts` (`HmacSigner`, `FirestoreFakeTransferLedger`, `liveFakeGateway()`, `OffPaymentGateway`), `src/infra/payment_firestore.ts` (`FirestorePaymentLookup`), `src/infra/live_payments.ts` (`liveSettlementDeps()`), `src/callables/payment.ts` (`handleCreatePayment`, `handleCheckPayment`, `handleConfirmFakePayment`, `handleSimulateFakeTransfer`), `src/http/payment_webhook.ts` (`handlePaymentWebhookRequest`), `src/scheduled/payment_clock.ts` (`handlePaymentClock`); tests `test/unit/payment_callables.test.ts`, `payment_webhook.test.ts`, `payment_clock.test.ts`, `fake_gateway.test.ts`, `payment_firestore.test.ts`; integration (written, not run) `test/integration/payment.test.ts`
- Modify: `src/config.ts` (`paymentsMode()`, `FAKE_WEBHOOK_KEY` = env `FAKE_WEBHOOK_KEY` ?? `'fake-webhook-dev-key'`), `src/infra/live_booking.ts` (gateway by mode, `cipher`; `getSharedFakeGateway` removed), `src/infra/live_event.ts` (same gateway, `cipher`), `src/infra/booking_firestore.ts` (booking/payment/refund mapping, legacy read, `findExpiredDrafts`), `src/infra/event_firestore.ts` (payment/refund mapping via the shared functions; `pendingTicketRefunds` removed), `src/infra/earnings_firestore.ts` + `src/infra/payout_firestore.ts` (`refundedTotal` excludes `kind == 'excess'`), `src/callables/booking.ts` (remove deposit handlers), `src/callables/event.ts` (`method`, `instructions`; remove `handleConfirmFakeTicketPayment`), `src/callables/errors.ts` (no new domain code; table unchanged), `src/scheduled/event_clock.ts`, `src/index.ts`, `seed/fixtures.ts`, `seed/README.md`, `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/firestore.indexes.json`, `app_flutter/firebase/rules-test/rules.test.mjs`; existing tests `test/unit/booking_callables.test.ts`, `event_payment_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `booking_firestore.test.ts`, `earnings_firestore.test.ts`, `seed_fixtures.test.ts`, `config.test.ts`, `test/integration/booking.test.ts`, `event_paid.test.ts`

**Interfaces:**
- Consumes: Task 1–2 domain exports; `fakePaymentsAllowed`, `assertFakePaymentsAllowed`, `aesGcmCipher`, `PAYOUT_ACCOUNT_KEY`, `PAYMENT_CALLABLE_OPTIONS`, `toHttpsError`.
- Produces: the callables/HTTP table in Contract; `paymentsMode(env?): 'fake' | 'off'`; `liveSettlementDeps(): SettlementDeps`.

- [ ] **Step 1: Contract check** of the Functions names; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `config.test.ts`: `paymentsMode is fake on the emulator with a demo project and on the dev project, off elsewhere`.
  - `fake_gateway.test.ts`: `HmacSigner verifies its own signature and rejects a changed body` (timing-safe compare); `liveFakeGateway in off mode refuses every call with not_eligible`.
  - `payment_callables.test.ts`: `createPayment returns VietQR instructions for bank_qr`; `createPayment maps not_accepting_orders and deadline_passed to failed-precondition`; `createPayment in off mode → failed-precondition not_eligible`; `checkPayment returns paid after a transfer in the fake ledger`; `confirmFakePayment refuses with fake_payments_disabled before any read on a production project`; `confirmFakePayment pays a booking and a ticket`; `simulateFakeTransfer refuses another user's payment with permission_denied`; `simulateFakeTransfer amount must be a positive integer`.
  - `payment_webhook.test.ts`: `POST with a valid signature settles and returns 200 with outcomes`; `bad signature → 401, nothing written` (Review Focus 5); `GET → 405`; `body over 64 KB → 413`; `fake provider on a production project → 404` (Review Focus 5); `a repeated webhook body changes nothing` (Review Focus 3); `an unexpected error → 500`.
  - `payment_clock.test.ts`: `eventClock runs the payment clock even when the event sweep throws`; `the payment clock logs a failing payment and continues`.
  - `booking_firestore.test.ts`: create the shared `booking round-trips every field` test (a `Booking` with every field set, `bookingToFirestore` → `bookingFromFirestore` deep-equals it); every later plan that adds a booking field (#130, #139, #142, #141, #136, #151) extends this one fixture instead of writing its own (cross-plan review finding 41; the whole-document `set` erases any unmapped field).
  - `booking_firestore.test.ts` / `payment_firestore.test.ts`: `a legacy booking with deposit/remaining reads as amount = deposit`, `legacy depositProvider vnpay reads as paymentMethod bank_qr`; `a payment round-trips method, code, expiresAt, receivedAmount, payer (no plain number stored), instructions`; `a legacy payment without method reads method from provider and provider fake`; `refunds round-trip kind, method, destination, attempts, lastAttemptAt`; `byCode returns at most 3 newest`.
  - `earnings_firestore.test.ts`: `refundedTotal ignores excess refunds` (Review Focus 1).
  - `event_payment_callables.test.ts`: `registerEvent takes method and returns instructions`; existing `confirmFakeTicketPayment` cases move to `confirmFakePayment`.
  - `seed_fixtures.test.ts`: `seed payments carry method bank_qr, provider fake, code, expiresAt and receivedAmount = amount when paid`; `seed bookings carry amount and no deposit`.
  - Rules (written, not run): `no client reads or writes payment_events or fake_gateway_transfers`; existing payments/refunds denials still hold.
  - Integration (written, not run): `createPayment, simulate transfer, booking becomes requested`; `webhook with a wrong signature is refused`; `QR expiry refunds a short transfer through eventClock`; update `booking.test.ts` and `event_paid.test.ts` to the new callables.
- [ ] **Step 3: Run** `cd app_flutter/firebase/functions && npm test` → the new tests fail.
- [ ] **Step 4: Implement.**
  - `HmacSigner(key)`: `createHmac('sha256', key).update(body).digest('hex')`; verify with `timingSafeEqual` on equal-length buffers (different length → false).
  - `FirestoreFakeTransferLedger`: `fake_gateway_transfers/{transactionId}` (fields of `TransferEvent` + `code`, Timestamps for instants); `listFor` = query `paymentId == id` plus query `code == code`, merged by id.
  - `liveSettlementDeps()`: one gateway instance (fake or off), `cipher` lazy from `PAYOUT_ACCOUNT_KEY` like `livePayoutAccountDeps`, `bookings: liveBookingDeps()`, `events: liveEventPaymentDeps()`, `payments: new FirestorePaymentLookup(db())`.
  - `handlePaymentWebhookRequest(req, res, deps, env = process.env)`: POST only; `rawBody = req.rawBody?.toString('utf8') ?? ''`; size check; provider detection = header `x-fake-signature` present → `fake`; if `fake` and `!fakePaymentsAllowed(env)` → 404 before any read; `handlePaymentWebhook` → 200; `DomainError('permission_denied')` → 401; anything else → log code only, 500. Never log the body or the payer account.
  - `index.ts`: `createPayment`, `checkPayment`, `confirmFakePayment`, `simulateFakeTransfer` (all `{...PAYMENT_CALLABLE_OPTIONS, secrets: [PAYOUT_ACCOUNT_KEY]}`), `paymentWebhook = onRequest({ region: REGION, memory: '256MiB', timeoutSeconds: 30, maxInstances: 10, minInstances: 0, secrets: [PAYOUT_ACCOUNT_KEY] }, (req, res) => handlePaymentWebhookRequest(req, res, liveSettlementDeps()))`; `eventClock` gains `secrets: [PAYOUT_ACCOUNT_KEY]` and runs `handleEventClock()` then `handlePaymentClock()` each in try/catch; remove `createDeposit`, `checkDeposit`, `confirmFakeTicketPayment`.
  - `handleSimulateFakeTransfer`: assert the fake gate first, read the caller's `users/{uid}.displayName`, then call the domain `simulateFakeTransfer(deps, {uid, name}, request.data)` with `deps.fake` = the live fake gateway (in `off` mode the gate has already refused).
  - Seed: bookings with `amount`; payments with the new fields; one booking in `draft` with a live `bank_qr` payment for S04.04 manual testing (customer `khach@seed.test` or the existing seed customer; name it in `seed/README.md`), and the README lines: "S04.04: open the draft booking of …; 'Mở app ngân hàng' simulates transfers (emulator only)".
  - Indexes and rules as in Contract.
- [ ] **Step 5: Run** `cd app_flutter/firebase/functions && npm test && npm run build` and `cd packages/domain && npm test` → pass. Ledger: rules tests and `test/integration/payment.test.ts` written, not run.
- [ ] **Step 6: Commit** `feat(functions): createPayment, signed payment webhook, fake transfers and payment reconciliation [#129]`.

### Task 4: App data — PayMethod, PaymentInstructions, Booking amount, repositories

**Files:**
- Create: `app_flutter/lib/data/payments/payment_instructions.dart`, `lib/data/payments/payments_repository.dart`; tests `test/data/payments/payment_instructions_test.dart`, `test/data/payments/payments_repository_test.dart`, `test/support/fake_payments_repository.dart`
- Modify: `lib/core/payments.dart`, `lib/data/booking/booking.dart` (+ regenerate `booking.freezed.dart`, `booking.g.dart`), `lib/data/booking/booking_rules.dart`, `lib/data/booking/booking_repository.dart`, `lib/data/booking/firestore_booking_repository.dart`, `lib/data/booking/contact_access.dart` (if it reads deposit fields), `lib/data/events/event_repository.dart` (+ fake), `lib/data/events/firestore_event_repository.dart`, `test/support/fake_booking_repository.dart`, `test/support/booking_world.dart`, `test/support/booking_fixtures.dart`, `test/support/event_world.dart`, `test/data/booking/booking_repository_test.dart`, `booking_rules_test.dart`, `fake_booking_repository_test.dart`, `test/data/events/firestore_event_repository_test.dart`
- Every compile error the rename causes in `lib/features/**` is fixed minimally here (e.g. `b.deposit` → `b.amount`) so `flutter analyze` stays clean; screen changes and copy are Tasks 5–7.

**Interfaces:**
- Consumes: callables `createPayment`, `checkPayment`, `confirmFakePayment`, `simulateFakeTransfer`, `registerEvent` (`method`, `instructions`).
- Produces: Contract → App `PayMethod`, `PaymentInstructions`, `VietQr`, `paymentInstructionsFrom`, `PaymentsRepository`, `FunctionsPaymentsRepository`, `paymentsRepositoryProvider`, `FakeTransferKind`, `PaymentCheck`, `BookingRepository.createPayment/checkPayment`, `Booking.amount/paymentMethod/paidAt/refundedAmount/refundedAt/draftExpiresAt`, `EventRepository.register(method:)`, `RegisterOutcome.instructions`; test fakes `FakePaymentsRepository` (records calls, scripted results).

- [ ] **Step 1: Contract check** (app data names); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `payment_instructions_test.dart`: `parses a bank_qr map with qr and expiresAt (ISO and Timestamp-like)`; `parses a wallet map with payUrl and no qr`; `returns null for a map without paymentId or with an unknown method`; `expiredAt is true at and after expiresAt`.
  - `PayMethod` (in `test/core/payments_test.dart`): `fromCode maps bank_qr, momo, zalopay`; `legacy vnpay reads as bankQr`; `unknown → null`.
  - `booking_repository_test.dart` (mapping): `a booking map with amount parses`; `a legacy map with deposit/remaining/depositProvider parses amount = deposit and paymentMethod from the provider`; `refundedAmount/refundedAt fall back to depositRefunded/depositRefundedAt`.
  - `booking_rules_test.dart`: `refundAmountAt is pct of the full amount` (≥ 48 h 100%, 24–48 h 50%, < 24 h 0); no deposit helpers left.
  - `payments_repository_test.dart` (with a fake `FirebaseFunctions` callable stub, as other Functions repositories test): `confirmFake sends paymentId and returns subjectStatus`; `simulateTransfer sends amount and late`; `a functions error with details.code becomes BookingException(code)`.
  - `firestore_event_repository_test.dart`: `register sends method code and parses instructions`.
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/data/payments`, then `test/data/booking`, `test/core` → fail.
- [ ] **Step 4: Implement.** Regenerate freezed: `dart run build_runner build --delete-conflicting-outputs`. Remove `PaymentProviderCode`; replace its uses (compile-driven). `FunctionsPaymentsRepository` uses `FirebaseFunctions.instanceFor(region: functionsRegion)` with a 35 s timeout (the callables are `PAYMENT_CALLABLE_OPTIONS`, 30 s), same error mapping as `FirestoreBookingRepository._call`.
- [ ] **Step 5: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/data/payments`; `… test/data/booking`; `… test/data/events`; `… test/core` → pass.
- [ ] **Step 6: Commit** `feat(data): PayMethod, payment instructions and the booking amount in the app [#129]`.

### Task 5: S04.03 Xem lại & thanh toán (100%, method list)

**Files:**
- Create: `app_flutter/lib/core/widgets/pay_method_picker.dart` (move `PayMethodPicker` + `_ProviderButton` here, add `PayMethodList`; delete `provider_picker.dart`; update `lib/core/core.dart` export), test `test/core/widgets/pay_method_picker_test.dart`
- Modify: `lib/core/theme/app_icons.dart` (`qrCode`, `copy`, `bank`), `lib/features/booking/booking_flow_state.dart` (`method` replaces `provider`, default `PayMethod.bankQr`; `depositVnd` removed; `amountVnd` = `priceVnd`), `lib/features/booking/booking_flow_controller.dart` (`setMethod`; `submit` → `createPayment`; `GoToPayment(bookingId, instructions)`), `lib/features/booking/booking_sheet_page.dart` (`_handleOutcome` → `openPayment(..., replace: true)`), `lib/features/booking/steps/review_step.dart`, `lib/l10n/app_vi.arb` (S04.03 keys), `docs/superpowers/specs/screens/booking.md` (S04.03 section rewritten to 100%, methods, new strings), `docs/superpowers/specs/components/shared-components.md` (`ProviderPicker` → `PayMethodList`/`PayMethodPicker`)
- Test: `test/features/booking/review_step_test.dart`, `submit_test.dart`, `booking_flow_controller_test.dart`, `booking_sheet_test.dart`, `booking_flow_e2e_test.dart`

**Interfaces:**
- Consumes: `PayMethod`, `PaymentInstructions`, `BookingRepository.createPayment`, `openPayment` (Task 6 — in this task `_handleOutcome` calls a temporary `context.replace(payPathOf(BookingPay(id)), extra: instructions)`; Task 6 swaps in `openPayment`), `PayMethodList`.
- Produces: `PayMethodList({value, onChanged, enabled})`; `BookingFlowState.method`; `BookingFlowController.setMethod(PayMethod)`; `GoToPayment { bookingId; PaymentInstructions instructions }`.

**Backend wiring:** `createBooking` (existing) then `createPayment({bookingId, method})` via `FirestoreBookingRepository`; errors through `bookingErrorOf` (`deadline_passed`, `not_accepting_orders`, `not_eligible` already mapped); no Firestore reads besides the existing profile/packages providers.

**Mock parity (`#S04.03`):** header "Xem lại" + "4 / 4"; `BookingCard` (thumb, "Minh Trí · Chân dung 2 giờ", "T7 12/10 · 15:30–17:30", place); one row with "Ghi chú" and "SĐT của bạn" (existing `IntrinsicHeight` row); money table with two lines only: "Gói {name}" + price, bold "Thanh toán 100%" + price (no "Còn lại", no 30%); one quiet tertiary line `bookHoldNote` (no `EscrowNotice` box, no separate policy paragraph); `PayMethodList` as a radiogroup (Semantics `payMethodLabel`): full-width "Chuyển khoản QR" option with radio dot, icon tile `AppIcons.qrCode`, subtitle "Miễn phí · xác nhận ngay", selected by default; second row of two half-width options "MoMo" and "ZaloPay" with icon tile `AppIcons.wallet`; primary button "Thanh toán {giá}" (full price). Selected option: primary border + `primarySubtle` fill (60-30-10: accent only for the selected state).

- [ ] **Step 1: Failing tests:**
  - `pay_method_picker_test.dart`: `PayMethodList shows three options, Chuyển khoản QR with its hint`; `tapping MoMo calls onChanged(momo)`; `selected option exposes selected semantics and the group label`; `fits 320dp at 1.3x text without overflow`; `disabled list ignores taps`; `PayMethodPicker (S11.03 row) still shows the three buttons`.
  - `review_step_test.dart`: `shows Thanh toán 100% with the full price and no Còn lại line`; `shows the hold note "Tiền được giữ tới khi bạn nhận ảnh…"`; `Chuyển khoản QR is selected by default`; `the primary button reads "Thanh toán 1.500.000₫"`; `choosing ZaloPay updates the state`; no `EscrowNotice` in the tree.
  - `submit_test.dart`/`booking_flow_controller_test.dart`: `submit creates the booking then createPayment with the chosen method`; `GoToPayment carries the instructions`; `deadline_passed from createPayment shows bookTryAgain and keeps the sheet`; `not_accepting_orders from createPayment shows bookNotAcceptingOrders`.
  - `booking_flow_e2e_test.dart`: the happy path reaches the S04.04 route with `extra` instructions.
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/booking` and `… test/core/widgets` → fail.
- [ ] **Step 3: Implement**; arb keys; `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/core/widgets`; `… test/features/booking` → pass.
- [ ] **Step 5: Commit** `feat(booking): S04.03 pays 100% with Chuyển khoản QR, MoMo or ZaloPay [#129]`.

### Task 6: S04.04 payment screen (VietQR, countdown, new QR, wallets) for bookings and tickets

**Files:**
- Create: `app_flutter/lib/features/payment/pay_subject.dart` (`PaySubject`, `BookingPay`, `TicketPay`, `payPathOf`), `lib/features/payment/payment_screen.dart`, `lib/features/payment/payment_controller.dart`, `lib/features/payment/open_payment.dart`, `lib/features/payment/widgets/viet_qr_card.dart`, `lib/features/payment/widgets/pay_wait_view.dart`, `lib/features/payment/fake_transfer_sheet.dart`, `lib/features/payment/fake_wallet_sheet.dart`; tests `test/features/payment/payment_screen_test.dart`, `viet_qr_card_test.dart`, `fake_transfer_sheet_test.dart`, `open_payment_test.dart`
- Modify: `lib/app/router.dart` (`/b/:id/pay` → `PaymentScreen`, new `/e/:eventId/pay/:regId`), `lib/features/booking/booking_sheet_page.dart` (use `openPayment`), `lib/features/events/register_sheet.dart` (`_pay` → `openPayment(TicketPay)`), `lib/features/events/register_controller.dart` (`method` is the new `PayMethod`; `provider:` → `method:`), `lib/features/events/tickets_tab.dart` (`_continuePayment` → `openPayment` with the instructions from `register(...)` "Thanh toán tiếp"), `lib/l10n/app_vi.arb` (S04.04 and fake-sheet keys), `docs/design/ui-mock.html` (two new frames, below), `docs/superpowers/specs/screens/booking.md` (S04.04 section rewritten), `docs/superpowers/specs/screens/events.md` (S11.03: Chuyển khoản QR → S04.04)
- Delete: `lib/features/booking/payment_pending_screen.dart`, `lib/features/booking/fake_payment_sheet.dart`, `lib/features/events/ticket_payment_sheet.dart` (and their tests: `test/features/booking/payment_pending_screen_test.dart` cases move to `payment_screen_test.dart`)
- Test (update): `test/features/events/register_sheet_test.dart`, `tickets_tab_test.dart`, `test/features/booking/booking_lifecycle_e2e_test.dart`

**Interfaces:**
- Consumes: `PaymentInstructions`, `BookingRepository.createPayment(renew: true)`/`checkPayment`, `EventRepository.register`/`checkTicketPayment`/registration stream (existing provider used by `register_sheet.dart`), `PaymentsRepository.confirmFake/simulateTransfer`, `bookingProvider(id)` (stream), `realPaymentsProvider`, `externalLauncherProvider`, `clockProvider`, `CountdownText`, `SignatureLoader`, `BookingCard`, `EmptyState`.
- Produces: `PaymentScreen`, `openPayment`, `VietQrCard`, `FakeTransferSheet`, `FakeWalletSheet`, routes.

**Backend wiring:** booking subject: `bookingProvider(id)` listener decides (`status != draft` → `context.go('/b/$id?paid=1')`; `null` after a known draft → the existing expired `EmptyState` with "Đặt lại"); instructions from the route `extra`, else `checkPayment` on open; `checkPayment` again on `AppLifecycleState.resumed`; "Tạo QR mới" → `createPayment(method: bankQr, renew: true)`; "Đổi phương thức" → sheet with `PayMethodList` → `createPayment(method)` → `openPayment(replace: true)`. Ticket subject: the registration stream (`paid` → `context.go('/bookings?tab=events&highlight={regId}')`, as `register_sheet.dart` does today, so #138's ticket primer runs; `cancelled` → hold expired state with "Đăng ký lại" back to `/e/:eventId`), instructions from `extra`, else `checkTicketPayment` + `register(...)` without method ("Thanh toán tiếp"). Fake mode only: "Mở app ngân hàng" → `FakeTransferSheet` → `simulateFakeTransfer`; wallets → `FakeWalletSheet` → `confirmFakePayment`. No new Firestore query.

**Mock parity:**
- `#S04.04` (live QR): AppBar back + "Chuyển khoản QR"; centered QR (`QrImageView` of `qr.payload`, white tile, semantics `payQrImageLabel`), big amount (display font, tabular), row "Minh Trí · Chân dung 2 giờ" (ticket: event title · "{n} vé") + badge "Chờ thanh toán", live countdown chip "Còn 14:32" (`role=timer` semantics `payQrTimeLeftLabel`, ticks per second under 1 hour via `CountdownText`); key-value list: "Ngân hàng" BIDV + tertiary "Tài khoản thu hộ của trung gian thanh toán", "Số tài khoản" `9624 •••• 3812`, "Nội dung" `PB 7F3K2Q` + "Sao chép" (Clipboard + SnackBar `payCopied`); rule line `payQrRule`; footer: outline "Tạo QR mới" (≈ 38% width) + primary "Mở app ngân hàng" (52dp, same height).
- `#S04.04-expired` (new frame, Step 1): same layout, QR at 25% opacity and excluded from semantics, badge "Hết hạn", chip "QR đã hết hạn" (`st dis`), body `payQrExpiredBody`; footer outline "Đổi phương thức" + primary "Tạo QR mới". Tickets in this state: no "Tạo QR mới"; primary "Đăng ký lại" (`payRegisterAgain`).
- `#S04.04-wait` (new frame, Step 1): AppBar back + "Thanh toán"; `SignatureLoader(size: LoaderSize.screen, wave: LoaderWave.vibration)` (static when `disableAnimations`), title "Đang chờ xác nhận", body `payWaitBody` ("MoMo chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ tới 10:12."), compact `BookingCard` with badge "Chờ thanh toán"; footer outline "Đổi phương thức" + primary "Mở lại MoMo".

- [ ] **Step 1: Mock frames.** Add `S04.04-expired` and `S04.04-wait` right after `#S04.04` in `docs/design/ui-mock.html`, following the existing `.step` + `.phone` + `.cap` pattern and classes (`vqr`, `qrb`, `amt`, `badge b-pen|b-bad`, `st live|dis`, `kv`, `cpy`, `foot`, `btn out|pri`, `sig` with the `vib` SVG copied from `#S13.03`, `card`). Exact copy:
  - `S04.04-expired`: bar "Chuyển khoản QR"; amount "1.500.000₫"; "Minh Trí · Chân dung 2 giờ" + badge "Hết hạn"; chip "QR đã hết hạn"; meta x "Tạo QR mới để thanh toán. Tiền đã chuyển vào QR cũ sẽ được hoàn tự động."; footer "Đổi phương thức" / "Tạo QR mới". Caption: `<span class="n new">Mới</span><span class="n">S04.04 · QR hết hạn</span><b>Hết 15 phút thì tạo QR mới</b><span>QR mờ đi, nhãn "Hết hạn"; nút chính thành "Tạo QR mới" (nội dung chuyển khoản mới), nút viền "Đổi phương thức" mở lại Chuyển khoản QR / MoMo / ZaloPay. Ngày của thợ giữ "Chờ" tối đa 60 phút từ lúc gửi yêu cầu; quá hạn thì yêu cầu hết hạn và về "Đặt lại". Vé sự kiện: QR hết hạn cùng lúc chỗ giữ 10 phút, nút chính là "Đăng ký lại".</span>`
  - `S04.04-wait`: bar "Thanh toán"; vibration `sig`; "Đang chờ xác nhận"; "MoMo chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ tới 10:12."; card "Minh Trí · Chân dung 2 giờ" / "T7 12/10 · 15:30–17:30" + badge "Chờ thanh toán"; footer "Đổi phương thức" / "Mở lại MoMo". Caption: `<span class="n new">Mới</span><span class="n">S04.04 · Chờ ví</span><b>Quay lại từ MoMo, ZaloPay hay app ngân hàng</b><span>Loading đặc trưng sóng rung như S13.03 khi đang chờ bên kia báo về; có tiền thì tự sang S05.02 (vé: tab Vé sự kiện). Mở lại app là hỏi lại máy chủ một lần. "Mở lại MoMo" mở lại ví; "Đổi phương thức" chọn cách khác.</span>`
- [ ] **Step 2: Failing tests** (fake repositories, injected `clockProvider`, bounded pumps):
  - `viet_qr_card_test.dart`: `renders the QR, amount, bank BIDV, masked account and content PB 7F3K2Q`; `Sao chép copies the content and shows "Đã sao chép nội dung chuyển khoản"`; `expired dims the QR and hides it from semantics`; `light and dark`.
  - `payment_screen_test.dart`: `booking bank_qr shows the countdown "Còn 14:32" from expiresAt`; `the countdown reaching zero shows the expired variant with primary "Tạo QR mới"` (pump past expiry, no timer left); `Tạo QR mới calls createPayment(renew: true) and shows the new code`; `Tạo QR mới refused with deadline_passed shows the expired-request state with Đặt lại`; `a booking that becomes requested navigates to /b/:id?paid=1`; `a deleted draft shows "Yêu cầu đã hết hạn" with Đặt lại`; `opened without extra calls checkPayment and shows its instructions`; `app resume calls checkPayment once`; `fake mode: Mở app ngân hàng opens the fake transfer sheet`; `wallet instructions show the wait variant "Đang chờ xác nhận" with "Mở lại MoMo"`; `Đổi phương thức to ZaloPay calls createPayment(zalopay)`; `ticket subject shows "{title} · 2 vé", no Tạo QR mới when expired, and opens /bookings?tab=events&highlight={regId} when paid`; `fits 320dp at 1.3x text`; `reduced motion: the vibration loader is static`.
  - `fake_transfer_sheet_test.dart`: `Chuyển đúng sends the exact amount`; `Chuyển thiếu sends half the amount (rounded down to 1.000₫)`; `Chuyển thừa sends amount + 100.000₫`; `Chuyển sau khi QR hết hạn sends late: true`; `fake_payments_disabled shows ticketPayFakeDisabled`.
  - `open_payment_test.dart`: `bank_qr pushes the pay route with extra`; `wallet in fake mode shows FakeWalletSheet then the pay route`; `wallet in real mode launches payUrl then the pay route`; `replace: true replaces instead of pushing`.
  - `register_sheet_test.dart`/`tickets_tab_test.dart` (update): `paid event with Chuyển khoản QR opens /e/:eventId/pay/:regId`; `Thanh toán tiếp reuses the hold's method and opens S04.04`; `register sends method code`.
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/payment` → fail.
- [ ] **Step 4: Implement.** `PaymentController` (`AsyncNotifier` per subject) holds `PaymentInstructions?`, `phase` (`live | expired | waiting | gone`), and exposes `renew()`, `changeMethod(PayMethod)`, `check()`. Countdown: `CountdownText(deadline: instructions.expiresAt, now: ref.read(clockProvider), onExpired: controller.markExpired, builder: …)` formatting `mm:ss`. Strings via arb; `flutter gen-l10n`. Remove the deleted files' imports.
- [ ] **Step 5: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/features/payment`; `… test/features/booking`; `… test/features/events` → pass.
- [ ] **Step 6: Commit** `feat(payment): S04.04 VietQR with countdown, new QR and wallet wait, shared by bookings and tickets [#129]`.

### Task 7: "Cọc" out of S05, S06, S07 and the profile (100% copy)

**Files:**
- Modify: `app_flutter/lib/l10n/app_vi.arb` (changed values and the three replaced keys in Contract), `lib/features/booking/booking_detail_screen.dart` (`detailPaidToast(amount)`, `escrowNoticeHeld*`, `b.amount`, timeline `timelineNoMorePay` on "Hoàn thành"), `lib/features/booking/booking_view_rules.dart` (amounts from `amount`/`refundedAmount`; the "Trả {amount} tại chỗ" hint replaced by `timelineNoMorePay`), `lib/features/booking/cancel_sheet.dart` (`cancelYouGetBackPct(pct)`, amount from `amount`), `lib/features/booking/decline_sheet.dart` (`declineRefundNote(name, amount)`), `lib/features/work/work_screen.dart` (`workPaid`), `lib/features/notifications/notification_primer.dart` (if it says "cọc"), `docs/superpowers/specs/screens/booking.md` (S05.02, S05.03 strings), `docs/superpowers/specs/screens/photographer.md` (S06.01, S06.03 strings, if they quote "cọc")
- Test: `test/features/booking/booking_detail_screen_test.dart`, `booking_view_rules_test.dart`, `cancel_sheet_test.dart`, `decline_sheet_test.dart`, `my_bookings_screen_test.dart`, `test/features/work/` (work screen test), `test/features/settings/settings_test.dart` / edit-profile test (phone hint), `test/l10n/` or a new `test/l10n/no_deposit_copy_test.dart`

**Interfaces:**
- Consumes: `Booking.amount`, `refundedAmount`, `paidAt`, `BookingRules.refundAmountAt`.
- Produces: no new API.

**Backend wiring:** unchanged (`bookingProvider`, `transitionBooking`); only copy and amounts.

**Mock parity:** `#S05.02`: toast "Đã thanh toán 1.500.000₫, tiền được giữ an toàn."; timeline first step "Đã gửi & thanh toán" / "Hôm nay 9:41 · 1.500.000₫"; "Hoàn thành" hint "Không trả thêm tại buổi chụp"; red text "Huỷ yêu cầu · hoàn 100%". `#S05.03`: "Bạn sẽ nhận lại (100% số đã trả)" + amount = 100% of the full price. `#S06.01`: "đã thanh toán 1,5M". `#S06.03`: "Lan Anh được hoàn 100% (1.500.000₫) và nhận lý do này." `#S04.05`: "Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán."

- [ ] **Step 1: Failing tests:**
  - `no_deposit_copy_test.dart`: `no value in app_vi.arb contains "cọc" or "Cọc"` (reads the arb file as JSON).
  - `booking_detail_screen_test.dart`: `paid toast reads "Đã thanh toán 1.500.000₫, tiền được giữ an toàn."`; `customer cancel label reads "Huỷ yêu cầu · hoàn 100%" 3 days before`; `Hoàn thành step hint reads "Không trả thêm tại buổi chụp"`; `photographer escrow notice "1.500.000₫ đang được giữ, chuyển cho bạn theo 2 mốc"`.
  - `cancel_sheet_test.dart`: `24–48 h before: "Bạn sẽ nhận lại (50% số đã trả)" and 750.000₫ of a 1.500.000₫ booking`.
  - `decline_sheet_test.dart`: `note reads "Lan Anh được hoàn 100% (1.500.000₫) và nhận lý do này."`.
  - work screen test: `a request row shows "đã thanh toán 1,5M"`.
  - `booking_view_rules_test.dart`: `refund amount uses the full amount`; `held total sums amount − refundedAmount`.
- [ ] **Step 2: Run** the folders → fail.
- [ ] **Step 3: Implement**; `flutter gen-l10n`; remove the keys listed as removed once unused (`flutter analyze` finds stragglers).
- [ ] **Step 4: Run** `flutter analyze`; `flutter test --no-pub --timeout 60s test/features/booking`; `… test/features/work`; `… test/features/settings`; `… test/l10n` → pass.
- [ ] **Step 5: Commit** `fix(booking): 100% payment copy on S05, S06 and S07, no more "cọc" [#129]`.

### Task 8: Specs, data model, docs and handover ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2: S04.03 status "✅ đã làm (4b) · 100%, Chuyển khoản QR/MoMo/ZaloPay (#129) · bước địa điểm chưa có bản đồ"; S04.04 "✅ VietQR, đếm ngược, QR mới, chờ ví (#129) · về S05.02 (4c)"; §3g.6 escrow notice copy → 100%; §3g.5 ledger type list), `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` (§3.3: Decision 5 cumulative top-up; §5: `awaiting_account`, `kind`; §9: the port signatures as built and "fake only, real adapter deferred"; one line per Decision 10, 12, 13), `docs/superpowers/specs/data-model/domain-model.md` (`Booking` fields, `Payment` fields, `Refund` fields, enums `PaymentMethod`, `PaymentProvider`, `PaymentStatus`, `RefundStatus`, `RefundKind`, `LedgerEntryType`, invariant 2 replaced by "`Booking.amount = serviceSnapshot.price`", invariant 11 as implemented), `docs/superpowers/specs/data-model/relational-schema.md` (target DDL: `bookings.amount`, `payment_method`, `paid_at`, `refunded_amount`, `refunded_at`, `draft_expires_at`; `payments.method/provider/code/expires_at/received_amount/refunded_amount/payer_*`; `refunds.kind/method/destination_*/attempts/last_attempt_at`; `payment_events`; mapping table rows), `docs/superpowers/specs/data-model/README.md` (money: "Khách trả 100%"; ports table `create_payment`, `check_payment`, `settle_transfer`, `reconcile_payments` replace `create_booking_deposit`/`refundDeposit`), `docs/legal/terms-and-help-notes.md` (P10: cumulative top-up within 15 minutes if the owner keeps Decision 5), `app_flutter/firebase/functions/seed/README.md` (done in Task 3; re-check)
- Create: `docs/superpowers/handover/ledger-s04-booking-payment.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names), matching the code as built; every string quoted in `screens/booking.md` matches `app_vi.arb` and the mock.
- [ ] **Step 2:** Write the ledger: what shipped per task; rulings (Decisions 1–21 as built, any contract differences found in Step 1 of each task); skipped emulator suites (`rules.test.mjs` payment_events/fake_gateway_transfers cases, `test/integration/payment.test.ts`, the updated `booking.test.ts` and `event_paid.test.ts`); deploy-order notes: (1) indexes `payments (status, createdAt)`, `(status, expiresAt)`, `(code, createdAt desc)`, `bookings (status, draftExpiresAt)`, `refunds (status, lastAttemptAt)` must finish building before the functions (the payment clock and the draft sweep error until then); (2) functions: new `paymentWebhook` (HTTP) and callables, removed `createDeposit`, `checkDeposit`, `confirmFakeTicketPayment`; `eventClock` now binds `PAYOUT_ACCOUNT_KEY`; (3) app build last; (4) **production stays blocked**: `paymentsMode()` is `off` outside the emulator/dev, so production refuses payments until the real intermediary adapter (#129 Deferred) and the milestone split (#130) land; `REAL_PAYMENTS` must stay false; the dev project is Spark, so test on the emulators. Carry to #141 (S22.04 confirmation window, alternate account, history rows), #130 (milestones; `releaseAfter` per milestone), #134 (payout ledger types, `refundedTotal` stays policy-only), #140 (subject `instant_request` through the Decision 22 extension point: `newSubjectPayment`, `issuePaymentInstructions`, a `SubjectSettler`, `InstantPay` on S04.04), #135 (subject `verification_fee`, same path), #139/#136/#151 (bookings through `buildBookingDraft` + `assertOrderAllowed`, Decision 23), #144 (adds `BlockGate` to `orderBlocker`), phase 1.5 #83 (S23.02 needs_review / unmatched transfers, failed refunds).
- [ ] **Step 3: Commit** `docs(spec): 100% payment, VietQR and the payment model in specs and data model; S04 ledger [#129]`.

## Deferred

- **Real licensed intermediary** (payments spec §10–11): its `PaymentGateway` adapter (createPayment, queryPayment, refund with `refundId` as idempotency key, verifyWebhook with its signature scheme and secret in Secret Manager), the provider list, sandbox tests, and turning `REAL_PAYMENTS` on. Needs the legal work of §11 first.
- Real-mode "Mở app ngân hàng" bank-app chooser (VietQR deeplink list from the intermediary).
- Cards (`domestic_card`, `intl_card`): designed in the enum, disabled.
- Two-milestone release (shoot / delivery + 48 h): #152 (delivery approval). Until then the full amount minus policy refunds is released at `completed` + 24 h.
- S22.04 confirmation window for policy bank refunds, "Dùng tài khoản khác", payment history S22.01: #141.
- Payout ledger types (`platform_fee`, `tax_withheld`, `gateway_fee`, `payout_fee`, `revenue_received`), daily payouts, first-payout approval: #134.
- Staff screens: unmatched/ambiguous transfers (`needs_review`), failed refunds, daily statement reconciliation, tax report (S23.02, S23.03, phase 1.5 #83).
- Instant booking payments (#140) and the verification fee (#135): their subjects plug into the Decision 22 extension point in their own plans. Job-post quotes (#139), studio (#136) and collaborator (#151) bookings are ordinary `booking` payments built through Decision 23.
- Self-hosted SQL migration of the payment fields (`services/api`, phase 2 #90).
- Replacing the 1-minute `releaseEventHolds` schedule with per-hold Cloud Tasks (cost spec §13.4): unrelated to this plan.
- Electronic invoices for platform revenue (payments spec §8).
