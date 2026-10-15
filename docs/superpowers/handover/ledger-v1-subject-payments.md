# Handover ledger — V1 subject payments and shared S04.04 (issue #200)

Plan: `docs/superpowers/plans/2026-10-08-v1-subject-payments.md`, Tasks 1–8. Branch `plan/200-thanh-toan-v1-thanh-toan-dung-chung-moi`. Target merge: `develop`.

## Built

- **Domain (`packages/domain`)**:
  - `PaymentSubject`: extended to `'booking' | 'event_registration' | 'instant_request' | 'verification_fee'`.
  - Common payment subject types and extension point: `SubjectSettler<TSubject>`, `SettlementDeps`, `settleTransfer(deps, notification)`, `checkSubjectPayments(deps, subjectType, subjectId)`.
  - Common payment creation: `newSubjectPayment(...)`, `issuePaymentInstructions(...)`, `instructionsOf(...)`.
  - Pure payment settlement and sweeps: `applyTransfer`, `expireUnpaid`, `TransferOutcome`.
  - Registration settler: `eventRegistrationSettler` handling ticket hold confirmation, partial payments, overpayments (excess refund), and holds expired while late payments arrive.
  - Verification: all unit and domain test suites passed green.

- **Functions (`functions`)**:
  - `liveSettlementDeps()`: registers settlers for `booking` and `event_registration`.
  - Webhook (`paymentWebhook`): delegates transfer processing via `settleTransfer` to the appropriate subject settler.
  - Sweeps (`runPaymentSweeps` / `paymentClock`): sweeps created payments across every subject using `checkSubjectPayments`.
  - Deprecated and removed: `createDepositIntent`, `checkPaymentStatus`, `confirmFakeTicketPayment`.
  - New callable `getPaymentInstructions {paymentId}`.

- **App Flutter (`app_flutter`)**:
  - Core payments model: `PaySubject` (`BookingPay`, `TicketPay`), `payPathOf(subject)`, `PaymentInstructions`.
  - Generic `PaymentScreen` (S04.04) and `PaymentController`: serves both bookings (`/b/:id/pay`) and event ticket holds (`/e/:eventId/pay/:regId`).
  - View components: `QrCheckoutView`, `WalletWaitingView`, `FakeTransferSheet` (`FakeTransferButton`).
  - Event registration flow (S11.03): `showRegisterSheet` creates hold and transitions to shared `PaymentScreen` via `openPayment`. Removed `ticket_payment_sheet.dart`.
  - Tickets tab (S11.04): "Thanh toán tiếp" checks payment status via `checkTicketPayment`, then routes to `/e/:eventId/pay/:regId`.

## Decisions (1–16) Taken

1. **Subject settler boundary**: Each subject owns its state transitions and database mutations inside its own settler (`bookingSettler`, `eventRegistrationSettler`).
2. **Transfer code uniqueness**: Transfer codes `"PB " + 6 characters` remain globally unique across all payments regardless of subject.
3. **Common payment instructions**: `PaymentInstructions` is normalized across all subjects, decoupling client views from `BookingCheckout`.
4. **Shared S04.04 route structure**: `/b/:id/pay` and `/e/:eventId/pay/:regId` are handled by `PaymentScreen(subject)`.
5. **No renewal on ticket hold**: Unlike bookings which allow up to 3 QR renew attempts, ticket holds expire when timer runs out (`canRenew = false`). On QR expiry, footer shows "Về sự kiện" returning to event detail.
6. **Paid ticket navigation**: On successful payment, client shows toast `"Đã đăng ký"` with action `"Vào nhóm chat"` and redirects to `/bookings?tab=events&highlight={regId}`.
7. **Cancelled hold message**: Expired ticket hold displays `payTicketExpiredBody` ("Chưa nhận được thanh toán nên chỗ giữ đã nhả. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.").
8. **Fake transfer simulator**: Available in dev/test builds across all subjects through `PaymentsRepository.confirmFake`.
9. **Zero new untyped errors**: Errors map to domain `BookingErrorCode` / domain errors consistently.
10. **Removed unused event payment code**: Deleted `ticket_payment_sheet.dart`, `createDepositIntent`, `checkPaymentStatus`, `confirmFakeTicketPayment`.
11. **Client verification without server polling**: Real-time Firestore stream listeners update `PaymentController` reactively.
12. **Idempotency across subjects**: Each subject's transfer processing uses `payment_notifications/{provider}_{txnId}` to prevent duplicate execution.
13. **Tickets tab continuation**: "Thanh toán tiếp" runs server verification first before opening S04.04 to avoid unnecessary hold screens if payment was already received.
14. **Safe unmounting in navigation**: `PaymentScreen._navigate` captures `GoRouter.of(context)` before trigger to prevent defunct `BuildContext` issues on `SnackBarAction`.
15. **Unmigrated dev payments**: Dev ticket payments created before #200 without `method` are not reconciled by sweeps.
16. **Shared components**: `QrCheckoutView`, `WalletWaitingView`, `FakeTransferSheet` moved under `lib/features/payment/` to serve all payment subjects.

## Deviations from Plan

- **Fake payment sheet name**: Kept `FakeTransferSheet` and `FakeTransferButton` (from #129) rather than creating a separate `FakeWalletSheet`.
- **Primary button in expired state**: When ticket QR expires, `canRenew = false` causes `QrCheckoutView` to display a single primary button "Về sự kiện" instead of "Tạo QR mới".

## Removed Strings / Arb keys

- Unused keys removed from `app_vi.arb`:
  - `ticketPayCountdown`
  - `ticketPayExpired`
  - `ticketPayExpiredHint`
  - `ticketPaySuccess`

## Deploy Order

1. **Functions & Rules**: Deploy Firestore rules and Cloud Functions (`paymentWebhook`, `paymentClock`, `getPaymentInstructions`, `registerEvent`, `checkTicketPayment`).
   - Remove obsolete function `confirmFakeTicketPayment` (with `--force` if needed).
2. **App Flutter**: Deploy Flutter client updates.

## Deferred

- V2 Refund destination (#201): Refund to sender's bank account, `awaiting_account` state, automated refund re-send sweeps.
- New payment subjects: `instant_request` (#202), `verification_fee` (#203).
- Platform revenue ledger entries (`gateway_fee`, `payout_fee`, `revenue_received`): V3.
