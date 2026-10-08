# Đối chiếu S04 (#129): plan cũ và code đã merge

**Ngày:** 2026-10-08. **Kiểm trên:** `develop` 87d8187 (merge vào nhánh `plan/plans-2026-10-07` ở c1aa3d3).

#129 (S04 · Đặt lịch & thanh toán) **không** làm theo `2026-10-07-s04-booking-payment.md` (plan của PR #153, đợt 1). Nó làm theo một plan khác, `2026-10-07-s04-payments.md`, và đã merge ở PR #154 (commit 87d8187). Những gì đã làm, các ruling 1–11 và việc để sau nằm trong `docs/superpowers/handover/ledger-s04-payments.md`.

Plan cũ `2026-10-07-s04-booking-payment.md` "làm chủ" nhiều thứ mà các plan khác của đợt sau dùng lại (mô hình thanh toán chung, điểm mở rộng chủ thể thanh toán, bộ dựng booking nháp, cổng nhận đơn, hoàn tiền về tài khoản…). **Bảng dưới thay cho phần Contract của S04 mà các plan khác trích.** Plan nào cần một tên của S04 thì tra ở đây: tên đã có, tên thật nếu khác, hoặc plan nào giờ tạo nó.

Cách đọc cột "Trạng thái":

- **(a) có, cùng tên**: dùng như plan cũ viết (có thể khác chút về dạng, ghi ở cột cuối).
- **(b) có, tên khác**: dùng tên ở cột "Tên thật".
- **(c) chưa có**: #129 không làm. Cột cuối nói ai làm: một task của plan khác (việc nhỏ, đã thêm bước vào plan đó) hoặc một mục "Việc mới cần plan" (V1–V3, cuối file).

## Bảng đối chiếu

### Domain (`packages/domain/src`)

| Tên trong plan cũ | Trạng thái | Tên thật trên develop 87d8187 | Ghi chú / ai làm |
|---|---|---|---|
| `PAYMENT_METHODS`, `PaymentMethod` | (a) | `escrow.ts`: `bank_qr`, `momo`, `zalopay` | Thẻ để riêng ở `RESERVED_PAYMENT_METHODS` (`domestic_card`, `intl_card`). |
| `ENABLED_PAYMENT_METHODS` | (b) | `PAYMENT_METHODS` | `PAYMENT_METHODS` chỉ gồm các phương thức đang bật. |
| `parsePaymentMethod(v)` | (b) | `isPaymentMethod(v)` (`escrow.ts`) | Type guard; nơi gọi tự ném `DomainError('invalid_argument')`. |
| `PAYMENT_PROVIDERS`, `PaymentProvider` (chuyển sang `payments.ts`, thêm `ninepay`…) | (a) | vẫn ở `booking.ts`, giá trị `momo`, `vnpay`, `fake` | Không có file `payments.ts`. |
| `legacyMethodOf` | (c) | — | Không cần: tên trường cũ được giữ (Decision 1 của plan đã làm). |
| `PAYMENT_EXPIRY_MINUTES` | (a) | `booking_policy.ts` = 15 | |
| `DRAFT_HOLD_MINUTES` | (b) | `DRAFT_EXPIRY_MINUTES` = 30 (`booking_policy.ts`) | |
| `DRAFT_MAX_MINUTES` = 60 | (c) | — | Thay bằng `MAX_PAYMENT_ATTEMPTS` = 3, lỗi `payment_attempts_exceeded`. Xem "Câu hỏi cho chủ dự án". |
| `LATE_TRANSFER_GRACE_MINUTES` | (b) | `DRAFT_PAYMENT_GRACE_MINUTES` = 5 | Là phần cộng thêm vào `payableUntil` sau hạn QR. |
| `RECONCILE_AFTER_MINUTES` | (b) | `PAYMENT_RECONCILE_AFTER_MINUTES` = 3 | |
| `REFUND_RESEND_AFTER_MINUTES` | (c) | — | Chỉ vé có `TICKET_REFUND_RESEND_AFTER_MINUTES` (`event_payments.ts`). Gửi lại hoàn tiền booking: V2. |
| `paymentCodeOf`, `displayPaymentCode` | (b) | `transferCodeFor(paymentId)` (`payment_code.ts`) | Trả sẵn dạng hiển thị `PB XXXXXX` (có dấu cách); băm FNV-1a, bảng chữ `TRANSFER_CODE_ALPHABET`; không trùng mã giữa mọi payment (Ruling 6). |
| `paymentCodeIn(content)` | (b) | `transferCodesIn(content)` | Trả danh sách mã đọc được, theo thứ tự. |
| `crc16Ccitt`, `buildVietQrPayload` | (a) | `vietqr.ts` | Tham số `{bin, accountNumber, amount, content}` (không phải `bankBin`). |
| `VietQrInstructions` | (c) | — | Câu trả lời của cổng là `PaymentInstructions` (dòng dưới). |
| `PaymentInstructions` (kiểu chung cho mọi chủ thể, app đọc) | (b) | Hai thứ: `PaymentInstructions` (`booking_ports.ts`, câu trả lời của cổng: `providerRef?`, `qrPayload?`, `bankName?`, `accountMasked?`, `payUrl?`, `bankAppsUrl?`); và thứ `createPayment` trả: `CreatePaymentResult {paymentId, checkout: BookingCheckout}` (`create_payment.ts`, `booking.ts`), chép vào `bookings/{id}.checkout` | Kiểu chung cho chủ thể khác (vé, Chụp ngay, phí xác minh): V1. |
| `TransferEvent` | (b) | `TransferNotification {provider, txnId, amount, content, receivedAt, raw?, payer?}` (`booking_ports.ts`) | `payer` chỉ có `bankCode?`, `accountMasked?`, `name?`, không lưu riêng. |
| `PayerBankAccount`, `StoredBankAccount`, `Payment.payer` | (c) | — | V2. |
| `RefundEvent`, `GatewayEvent`, `applyRefundEvent` | (c) | — | Không có webhook hoàn tiền. V2. |
| `PaymentGateway {createPayment, queryPayment, refund, verifyWebhook}` | (b) | `PaymentGateway {provider, createPayment, queryTransfers, issueRefund, createDepositIntent, checkPaymentStatus}` (`booking_ports.ts`) | Kiểm chữ ký nằm ở Functions (`verifyFakeWebhook`), không ở port. `createDepositIntent`, `checkPaymentStatus` còn cho vé. |
| `PAYMENT_STATUSES` có `expired`, `needs_review` | (a) | `escrow.ts` | Bỏ `failed`. Chưa code nào ghi `needs_review` lên `Payment`; chuyển khoản không khớp chỉ có bản ghi `payment_notifications` với `outcome: 'needs_review'`. |
| `Payment.code` | (b) | `Payment.transferCode` | |
| `Payment.method`, `expiresAt`, `receivedAmount` | (a) | `escrow.ts` | Tuỳ chọn (payment cũ và vé không có). |
| `Payment.refundedAmount`, `appliedTransferIds`, `instructions` | (c) | — | Idempotent theo `TransferRecord` (`payment_notifications/{provider}_{txnId}`, `transferRecordId`); cách trả lưu ở `bookings/{id}.checkout`. `refundedAmount`: V2. |
| `REFUND_STATUSES` có `awaiting_account` | (c) | `pending`, `done`, `failed` | V2. |
| `RefundKind` (`policy` \| `excess`), `Refund.kind` | (b) | `Refund.fromEscrow: boolean` (`true` = hoàn từ tiền đang giữ: huỷ, từ chối, hết hạn, khiếu nại; `false` = trả lại ngay khi tiền tới); `isEscrowRefund(r)` | Dòng cũ không có trường đọc là `true`. |
| `ExcessReason` | (b) | `PaymentRefundReason` (`refunds.ts`): `overpaid_excess`, `underpaid_expired`, `late_transfer`, `extra_transfer`, `late_payment_draft_expired` | |
| `RefundMethod`, `refundMethodOf`, `Refund.method`, `Refund.destination` | (c) | — | V2. |
| `LEDGER_ENTRY_TYPES` có `payment_received` | (a) | `escrow.ts` | `deposit_received` cũ vẫn được đọc (`LEGACY_PAYMENT_RECEIVED_TYPE`). |
| `policyRefundTotal(refunds)` | (b) | `escrowRefundedTotal(refunds)` (`escrow.ts`); Functions `escrowRefundedOfDocs(docs)` (`infra/booking_firestore.ts`) | Giải ngân, chi trả và thu nhập đã dùng nó (Ruling 10). |
| `excessRefund(...)` | (b) | `transferRefund({payment, refundId, ledgerEntryId, amount, reason, providerRef?, now})` (`refunds.ts`) | |
| `verifyPaymentLedgerInvariant` | (a) | `escrow.ts` | Đúng cho `paid` và `expired`; không gọi trên `created`. |
| `TransferDecision`, `decideTransfer` | (a) | `transfer_rules.ts` | Dạng khác: `{kind: 'paid', excess} \| {kind: 'partial', received} \| {kind: 'refund', amount, reason}`. |
| `applyTransfer` (hàm thuần, export) | (b) | hàm nội bộ `applyTransfer` trong `handle_transfer.ts` (không export, chạy trong `BookingTx`) | Bản thuần dùng chung: V1. |
| `SettlementOutcome` | (b) | `TransferOutcome`: `paid`, `paid_with_refund`, `partial`, `refunded`, `needs_review`, `duplicate` | |
| `PaymentLookup` | (b) | các truy vấn trên `BookingStore`: `findPaymentsByTransferCode`, `findPaymentsToReconcile`, `findOverduePayments`, `getTransferRecord` | `pendingRefunds`, `recordEvent` không có (V2). |
| `settleBookingTransfer` | (b) | `handleTransferNotification(deps: BookingDeps, n)` (`handle_transfer.ts`) → `TransferResult {outcome, paymentId?}`; booking nháp đã trả đi qua `moveDraftToRequested` (`booking_payment_paths.ts`) | Chỉ khớp payment có `subjectType === 'booking'`. |
| `handlePaymentWebhook` (domain) | (b) | Functions: `handlePaymentWebhook(req, deps, env)` và `servePaymentWebhook` (`http/payment_webhook.ts`) | Domain chỉ nhận `TransferNotification` đã kiểm chữ ký. |
| `reconcilePayments` | (b) | `runPaymentSweeps(deps)` (`payment_sweeps.ts`) → `PaymentSweepResults` | Chỉ đối soát + cho hết hạn payment booking; **không** gửi lại hoàn tiền (V2). |
| `createPayment` | (a) | `createPayment(deps, {bookingId, customerId, method})` → `CreatePaymentResult` | Không có `renew`/`returnUrl`: mỗi lần gọi là một QR mới (QR đang mở hết hạn, tiền đã nhận được hoàn), tối đa 3 lần. **Không** kiểm lại cổng nhận đơn (xem #144 bên dưới). |
| `checkPayment` | (a) | `checkPayment(deps, {bookingId, customerId})` → `{paid, booking}` | Không trả instructions. |
| `dispatchRefund` | (a) | `dispatchRefund(deps, refund, provider)` (lỗi cổng ném ra ngoài); `dispatchRefunds(deps, items)` (lỗi cổng → `failed` + `manual`, Ruling 7) | Không gửi lại tự động. |
| `confirmFakePayment` (domain, mọi chủ thể) | (b) | Chỉ có callable Functions `confirmFakePayment {paymentId, kind?}` (`handleConfirmFakePayment`, `callables/payment.ts`); chỉ nhận payment booking có `transferCode` | Không có hàm domain. Bản chung: V1. |
| `simulateFakeTransfer` | (b) | cùng callable `confirmFakePayment`, `kind` ∈ `exact`, `under`, `over`, `wrong_content` (`FAKE_TRANSFER_KINDS`) | Không có kiểu "chuyển sau khi hết hạn". |
| `SubjectSettler`, `SettlementDeps` (+ `subjects`), `settleTransfer` | (c) | — | V1. |
| `newSubjectPayment`, `issuePaymentInstructions`, `instructionsOf`, `checkSubjectPayments` | (c) | — | V1. |
| `expireUnpaid` | (b) nội bộ | `expireOpenPayment(tx, deps, payment, now)` (`booking_payment_paths.ts`, không export từ `index.ts`) | Bản export dùng chung: V1. |
| `sendRefundOnce`, `mergeRefundOutcome` | (c) | — | V2. |
| `BookingDraftInput`, `buildBookingDraft` | (c) | `createBookingDraft` dựng booking ngay trong hàm | **#152 (S05 bàn giao), Task 2** tạo (việc nhỏ). |
| `OrderGateDeps`, `orderBlocker`, `assertOrderAllowed` | (c) | `createBookingDraft` gọi thẳng `deps.providers.acceptsOrders` | **#198 (N1, `2026-10-08-n1-order-gate.md`)** tạo. |
| Decision 9 (1): `createPayment` kiểm lại cổng nhận đơn | (c) | — | **#198 (N1)**: `createPayment` gọi `assertOrderAllowed`. |
| Decision 9 (2): tiền tới cho bản nháp của thợ đã ngừng nhận đơn → hoàn 100% (`provider_not_accepting`) | (c) | — | **#135 (S21), Task 2** (việc nhỏ trong `handle_transfer.ts`). |
| `BookingDeps.cipher` | (c) | — | V2. |
| `BookingStore.findExpiredDrafts(now, limit?)` | (a) | `booking_ports.ts` | Trả bản nháp có `payableUntil <= now`; bản nháp không có trường thì không bao giờ bị dọn. |
| `upfrontAmount(price)` | (b) | `computeDeposit(price)` → `{deposit: price, remaining: 0}` (`UPFRONT_PERCENT` = 100) | |
| `computeRefund(amount, percent)` | (a) | `booking_policy.ts` | Tham số vẫn tên `deposit`. |
| Trường booking `amount`, `paymentMethod`, `paidAt`, `refundedAmount`, `refundedAt`, `draftExpiresAt` | (b) | `deposit` (= toàn bộ giá), `remaining` (luôn 0), `depositProvider` (là provider `fake`…, không phải phương thức; phương thức ở `checkout.method`), `depositPaidAt`, `depositRefunded`, `depositRefundedAt`, `payableUntil`; thêm `checkout?: BookingCheckout` | Đổi tên trường (`deposit` → `terms.price`/`amount`) để sau, chưa có plan (Decision 1 của plan đã làm). |
| Decision 21: `refund_done` cho booking (đặt mốc đã hoàn khi refund `done`) | (c) | `booking_notifications.ts` bắn khi `depositRefundedAt` được đặt; chưa code nào đặt nó | **#138 (S17), Task 2** (việc nhỏ). |
| Vé: `settleTicketTransfer`, export `dispatchTicketRefund`, `registerEvent` nhận `method` và trả `instructions`; bỏ `handleTicketPayment`, `resendTicketRefund`, `confirmFakeTicketPayment` | (c) | Vé vẫn như trước #129: `createDepositIntent`, `checkPaymentStatus`, callable `confirmFakeTicketPayment`; gửi lại hoàn tiền vé là bước `refund_resend` của `runEventSweeps` | V1 (ledger #129 ghi "để #137", nhưng #137 đã đóng). |
| `FakePaymentGateway` | (a) | `fake_payment_gateway.ts`: `FAKE_COLLECTION_ACCOUNT`, `pushTransfer(paymentId, n)`, `markPaid(paymentId)` | Test đẩy chuyển khoản giả bằng `pushTransfer`. |
| `FakeTransferLedger`, `MemoryFakeTransferLedger`, `MessageSigner`, `FAKE_PAYER`, `webhookFor`, `recordTransfer` | (c) | — | Không cần cho cách đã làm. |
| Đối soát chạy trong `eventClock` (không thêm job) | (b) | Job riêng `paymentClock` (mỗi 5 phút, `PAYMENT_CLOCK_OPTIONS`) → `handlePaymentClock` (`scheduled/payment_clock.ts`) | Repo giờ có 7 job định kỳ. |

### Functions (`app_flutter/firebase/functions/src`)

| Tên trong plan cũ | Trạng thái | Tên thật | Ghi chú / ai làm |
|---|---|---|---|
| callable `createPayment`, `checkPayment` | (a) | `callables/payment.ts` (`handleCreatePayment`, `handleCheckPayment`), `PAYMENT_CALLABLE_OPTIONS` | `createPayment {bookingId, method}` → `{paymentId, checkout}`; `checkPayment {bookingId}` → `{paid, booking}`. |
| callable `confirmFakePayment {paymentId}` | (a) | `{paymentId, kind?}` → `{outcome}` | Chặn ngoài emulator/dev bằng `assertFakePaymentsAllowed`; chỉ payment booking. |
| callable `simulateFakeTransfer` | (b) | `confirmFakePayment` với `kind` | |
| HTTP `paymentWebhook` | (a) | `index.ts`, `WEBHOOK_OPTIONS`, `?provider=fake`, header `x-pb-signature` (`FAKE_SIGNATURE_HEADER`) | |
| `HmacSigner`, `FAKE_WEBHOOK_KEY`, header `x-fake-signature` | (b) | `signFakeWebhook`, `verifyFakeWebhook`, `fakeWebhookSecret(env)` (env `FAKE_PAYMENT_WEBHOOK_SECRET`), `parseFakeTransfer` (`infra/fake_webhook.ts`) | |
| `paymentsMode()` | (b) | `checkoutGatewayAvailable(env)` (`infra/fake_payments.ts`; hôm nay = `fakePaymentsAllowed`) | Ruling 11: tắt thì `createPayment` trả `not_eligible`. |
| `liveSettlementDeps()`, `infra/live_payments.ts`, `infra/fake_gateway.ts`, `OffPaymentGateway` | (c) | `liveBookingDeps()`, `getSharedFakeGateway()` (`infra/live_booking.ts`) | V1. |
| `payment_events/{provider}_{eventId}` | (b) | `payment_notifications/{provider}_{txnId}` | Rules chặn client. |
| `fake_gateway_transfers`, `FirestoreFakeTransferLedger` | (c) | — | Không cần. |
| `registerEvent` nhận `method`, trả `instructions`; bỏ `confirmFakeTicketPayment` | (c) | — | V1. |
| Test dùng chung `booking round-trips every field` | (b) | `round-trips Booking through Firestore conversion` (`test/unit/booking_firestore.test.ts`) | Plan nào thêm trường booking thì mở rộng test này (luật cũ, finding 41). |

### App (`app_flutter/lib`)

| Tên trong plan cũ | Trạng thái | Tên thật | Ghi chú / ai làm |
|---|---|---|---|
| `PayMethod` (`bankQr`, `momo`, `zaloPay`, `code`, `fromCode`) | (a) | `lib/core/payments.dart` | Vẫn còn `.provider` (vé dùng); không có `isWallet`. |
| Bỏ `PaymentProviderCode` | (c) | `PaymentProviderCode` vẫn còn (`lib/core/payments.dart`) | Vé còn dùng; bỏ cùng V1. |
| `PaymentInstructions`, `VietQr`, `paymentInstructionsFrom` (Dart) | (b) cho booking | `BookingCheckout`, `bookingCheckoutFrom` (`lib/data/booking/booking_checkout.dart`) | Bản chung cho chủ thể khác: V1. |
| `PaymentsRepository`, `FunctionsPaymentsRepository`, `paymentsRepositoryProvider`, `confirmFake`, `simulateTransfer` | (b) cho booking | `BookingRepository.confirmFakePayment({paymentId, kind})` | Bản chung: V1. |
| `FakeTransferKind {exact, short, over, late}` | (b) | `FakeTransferKind {exact, under, over, wrongContent}` (`lib/data/booking/booking_repository.dart`) | |
| `PaymentCheck` | (b) | `CheckPaymentResponse {paid, booking}` | |
| `BookingRepository.createPayment({bookingId, method, renew})` | (a) | `createPayment({bookingId, method})` → `BookingCheckout` | Không có `renew`. |
| `PayMethodList` (`lib/core/widgets/pay_method_picker.dart`) | (b) | `PayMethodSelector({value, onChanged, enabled})` (`lib/core/widgets/pay_method_selector.dart`) | |
| `PayMethodPicker` (file `pay_method_picker.dart`) | (a) | `PayMethodPicker` vẫn ở `lib/core/widgets/provider_picker.dart` | Chỉ cho S11.03. |
| Bỏ `ProviderPicker` | (a) | đã bỏ | `provider_picker.dart` chỉ còn `PayMethodPicker`. |
| `features/payment/` (`PaySubject`, `BookingPay`, `TicketPay`, `payPathOf`, `PaymentScreen`, `PaymentController`, `openPayment`, `VietQrCard`, `FakeTransferSheet`, `FakeWalletSheet`) | (b) cho booking, (c) cho chủ thể khác | S04.04 của booking: route `/b/:id/pay` → `PaymentPendingScreen(bookingId)` (`lib/features/booking/payment_pending_screen.dart`) với `QrCheckoutView`, `WalletWaitingView`, `FakeTransferButton` + `FakePaymentSheet` (chế độ giả). Mở như `_handleOutcome` của `booking_sheet_page.dart`: ví ở chế độ thật thì mở `checkout.payUrl` qua `externalLauncherProvider`, rồi `context.replace('/b/$bookingId/pay')` | Chủ thể khác: V1. |
| Route `/e/:eventId/pay/:regId` | (c) | — | V1. Vé vẫn trả qua `openTicketPayment` (`ticket_payment_sheet.dart`). |
| `AppIcons.qrCode` | (a) | `lib/core/theme/app_icons.dart` | |
| `AppIcons.copy`, `AppIcons.bank` | (c) | — | Plan nào cần thì thêm. |
| (mới, plan cũ không có) | — | `CountdownPill` (`lib/core/widgets/countdown_pill.dart`) | Đồng hồ QR, live region ở 5:00, 1:00, 0:10, 0 (Ruling 8). |
| Khoá chuỗi mới (`bookPayFull`, `payAwaiting`, `workPaid`, …) | (b) | giữ khoá cũ, đổi giá trị (`bookDepositToday`, `payAwaitingDeposit`, `workDepositPaid`, …) | Không còn chữ "cọc" trong `app_vi.arb`. |
| Khung mock `#S04.04-expired`, `#S04.04-wait` | (c) | — | Mock chưa có hai khung này. |

## Việc chuyển sang plan khác (việc nhỏ, đã thêm bước)

| Việc | Plan nhận | Chỗ thêm |
|---|---|---|
| `BookingDraftInput`, `buildBookingDraft` (hàm thuần; `createBookingDraft` dựng booking bằng nó) | #152 S05 bàn giao (đợt 3) | Task 2: Files, Interfaces, Step 2 |
| `OrderGateDeps`, `orderBlocker`, `assertOrderAllowed`; `createBookingDraft` và `createPayment` gọi `assertOrderAllowed` | #198 N1 | `2026-10-08-n1-order-gate.md` |
| Tiền tới cho bản nháp của thợ đã ngừng nhận đơn → hoàn 100%, lý do `provider_not_accepting` | #135 S21 (đợt 3) | Task 2 |
| `refund_done` của booking: đặt `depositRefundedAt` khi một refund booking thành `done` | #138 S17 (đợt 1) | Task 2 |

Mỗi chỗ thêm có ghi chú "trước đây do S04 làm; #129 không làm (xem 2026-10-08-s04-reconciliation.md)".

## Việc mới cần plan

Ba việc dưới đây lớn hơn một task nhỏ. Cập nhật 2026-10-08: V1 và V2 đã có issue và plan (xem dòng "Issue và plan" ở mỗi mục); plan dùng chúng ghi "Blocked by" trỏ tới issue đó. V3 vẫn chưa có issue và plan.

### V1. Thanh toán dùng chung cho mọi chủ thể (vé, Chụp ngay, phí xác minh) và S04.04 dùng chung

Hôm nay chỉ booking có `createPayment`, VietQR, webhook và đối soát; `handleTransferNotification` chỉ khớp payment `subjectType === 'booking'`; S04.04 là `PaymentPendingScreen` đọc `bookings/{id}.checkout`. Cần:

- Domain: điểm mở rộng chủ thể thanh toán (`PaymentSubject` thêm mã mới, `SubjectSettler`, `SettlementDeps` + `subjects`, `settleTransfer` chia theo `subjectType`), các hàm dùng chung `newSubjectPayment`, `issuePaymentInstructions`, `instructionsOf`, `checkSubjectPayments`, bản export của `applyTransfer` và `expireUnpaid`, kiểu `PaymentInstructions` không gắn với booking; `confirmFakePayment` cho mọi chủ thể.
- Functions: `liveSettlementDeps()`; webhook và `paymentClock` đi qua dispatch theo chủ thể.
- App: `features/payment/` (`PaySubject`, `PaymentScreen`, `PaymentController`, `openPayment`, `FakeWalletSheet`), `PaymentsRepository.confirmFake`, `PaymentInstructions` (Dart).
- Vé S11.03 chuyển sang mô hình này (`TicketPay`, route `/e/:eventId/pay/:regId`, `registerEvent` nhận `method`); bỏ `PaymentProviderCode`, `createDepositIntent`, `checkPaymentStatus`, `confirmFakeTicketPayment`.

**Issue và plan:** #200, `docs/superpowers/plans/2026-10-08-v1-subject-payments.md` (Blocked by: nothing; tên thật và bảng Deviations trong plan đó thắng tên ở mục này, ví dụ không có `FakeWalletSheet`).

Plan bị chặn: #203 S21 phí xác minh (tách khỏi #135 ngày 2026-10-08; chủ thể `verification_fee`), #140 S13–S14 (chủ thể `instant_request`) và #140 S13 khách (trả tiền ở S04.04). #138 S17 chỉ bị ảnh hưởng nhẹ (vé trả tiền vẫn về `/bookings?tab=events&highlight=…`).

### V2. Hoàn tiền về tài khoản người chuyển, gửi lại hoàn tiền và webhook hoàn tiền

Hôm nay: không lưu tài khoản người chuyển (chỉ nằm trong `raw` của `payment_notifications`), `Refund` không có `method`/`destination`, không có trạng thái `awaiting_account`; lỗi cổng khi hoàn ở các đường thanh toán thành `failed` + `manual` (Ruling 7), không gửi lại. Cần:

- Lưu tài khoản người chuyển đã mã hoá (`StoredBankAccount`, `Payment.payer`, `BookingDeps.cipher` dùng `AccountCipher`/`PAYOUT_ACCOUNT_KEY`).
- `Refund.method` (`RefundMethod`, `refundMethodOf`), `Refund.destination`, trạng thái `awaiting_account`, `Payment.refundedAmount`.
- Gửi lại refund `pending` dưới cùng id (`sendRefundOnce`, `mergeRefundOutcome`, `REFUND_RESEND_AFTER_MINUTES`) trong `paymentClock`, cho cả booking và vé (thay bước `refund_resend` của `runEventSweeps`).
- Webhook hoàn tiền (`RefundEvent`, `applyRefundEvent`).

**Issue và plan:** #201, `docs/superpowers/plans/2026-10-08-v2-refund-destination.md` (Blocked by: nothing).

Plan bị chặn: #141 S22 (cứng: S22.04 và cửa sổ 24 giờ dựng trên nó; phần xoá tài khoản tách sang #205, không bị chặn). Dùng được khi có: #142 S18 (bỏ qua refund `awaiting_account`), #140 S13–S14.

### V3. Bút toán doanh thu nền tảng (`gateway_fee`, `payout_fee`, `revenue_received`)

Plan S06 (#134) chuyển các loại bút toán này cho #129; plan cũ của #129 lại chuyển cho #134. Không ai làm. **Chưa có issue và plan** (2026-10-08). Cần phí thật của tổ chức trung gian nên có thể để sau, nhưng cần một chủ.

### Việc nhỏ chưa có chủ (không chặn plan nào)

- `serviceSnapshot.coverUrl` cho ảnh bìa gói trên thẻ ngữ cảnh S07.01: plan S07 (#131) để cho "S04, #129", #129 không làm.
- `AppIcons.copy`, `AppIcons.bank`, khung mock `#S04.04-expired` / `#S04.04-wait`: plan cũ hứa, #129 không làm; plan nào cần thì thêm.

## Quy ước chung giữ lại từ plan cũ

Các plan khác trích hai quy ước này từ plan cũ; chúng vẫn áp dụng:

1. **Bước của job định kỳ (clock rule):** thêm bước như một mục có tên ở cuối danh sách bước của handler, mỗi bước trong try/catch riêng, ghi log rồi chạy tiếp; không đổi tham số đang có; phụ thuộc mới đi vào object tuỳ chọn cuối cùng `extras` (`EventClockExtras` / `BookingClockExtras` trong cùng file scheduled; tạo interface nếu chưa có, mỗi plan một trường tuỳ chọn, mặc định là `live*Deps()` của nó). Kiểm 2026-10-08: chưa có `EventClockExtras`/`BookingClockExtras`; `handleBookingClock`, `handleEventClock`, `handlePaymentClock` là ba handler hiện có.
2. **Một test round-trip booking dùng chung:** plan nào thêm trường vào booking thì mở rộng `round-trips Booking through Firestore conversion` (`test/unit/booking_firestore.test.ts`), vì `bookingToFirestore` ghi cả document.

## Câu hỏi cho chủ dự án

1. **Chuyển thiếu rồi bù trước khi QR hết hạn:** chủ dự án chọn "tính đã trả". Bản đã làm **khớp**: các lần chuyển cộng dồn vào `receivedAmount`, đủ thì `paid`, phần thừa được hoàn (`overpaid_excess`).
2. **Bản nháp giữ ngày của thợ bao lâu:** chủ dự án chọn "60 phút". Bản đã làm giữ tới `payableUntil = max(createdAt + 30 phút, hạn QR mới nhất + 5 phút)`, tối đa 3 QR: dùng hết từng QR thì khoảng 50 phút; tạo QR mới sát hạn thì tới khoảng 70 phút. Job dọn (`bookingClock`) chạy 15 phút một lần và `createPayment` không tự kiểm `payableUntil`, nên ngày có thể còn "Chờ" lâu hơn một chút. **Cần chủ dự án xác nhận:** giữ cách đang chạy, hay đổi thành đúng 60 phút (đổi `DRAFT_EXPIRY_MINUTES` / cách tính `payableUntil`, và cho `createPayment` từ chối khi quá hạn).

## Plan đã sửa theo bảng này

`2026-10-07-INDEX.md`, `2026-10-07-s04-booking-payment.md` (chỉ thêm dòng "Đã thay thế"), `s02-discover` (chỉ số thứ tự job định kỳ), `s05-delivery-two-layer`, `s06-work-earnings`, `s07-chat`, `s13-instant-customer`, `s13-s14-dispatch-provider`, `s15-s16-job-posts`, `s17-notifications`, `s18-disputes-help`, `s20-report-block`, `s21-verification`, `s22-payments-account`, `s26-studio-members`, `s27-studio-recruiting`. `2026-10-07-cross-plan-review.md` là biên bản rà chéo và `RUN-ORDER.md` chỉ còn luật chung và lịch sử trước 2026-10-06 (một chỗ nhắc `ProviderPicker` nằm trong phần lịch sử); cả hai giữ nguyên.
