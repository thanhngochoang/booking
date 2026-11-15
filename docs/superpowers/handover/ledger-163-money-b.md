# Handover ledger — #342 phần B: chuyển khoản chưa khớp (S23.12) và Hoàn tiền (S23.03)

Plan: `docs/superpowers/plans/2026-11-15-163-staff-money.md` (phần B, task B1–B6). Spec: `docs/superpowers/specs/screens/staff-money.md` (§4, §5, §5.1). Dashboard: `docs/superpowers/specs/2026-10-08-dashboard-web-design.md` (§5.4). Mock: `docs/design/dashboard-mock.html#S23.12`, `#S23.03`. Ledger trước: `ledger-163-money-a.md` (tên thật của phần A thắng tên cũ trong plan).

Phần B (#342) cùng tên nhánh `plan/342-transfers-refunds` ở hai repo, dựng trên phần A đã merge.

- **booking-be** (code: `packages/domain`, `firebase/functions`, `firebase/firestore.indexes.json`, `apps/dashboard`), merge trước. Tên trong file này lấy từ code ở đó.
- **booking**: PR này, chỉ tài liệu (data model, trạng thái màn, file này).

## Hiện có gì

- **Dữ liệu** (`packages/domain`): `TransferRecord` có `amount`, `content`, `payer` (tên ngân hàng, tối đa 4 số cuối, tên), `review {status, resolution, paymentId, refundId, decidedBy, decidedAt, note}`; `TransferNotification.assignment?`; `maskTransferPayer`, `reopensReview`, `notificationOfRecord` (`payment_settlement.ts`); `suggestPaymentsForTransfer` (`transfer_review.ts`, cùng số tiền, ±48 giờ, mã sai một ký tự xếp đầu). `Refund.transferRecordId`, `manualBy`, `manualPaidAt`, `manualNote`; lý do `unmatched_transfer`; `isUnmatchedTransferRefund`; `INSTANT_LONG_HOLD_DAYS = 7`.
- **Use case**: `assignUnmatchedTransfer`, `refundUnmatchedTransfer`, `dismissUnmatchedTransfer` (`transfer_review.ts`), `retryRefund`, `markRefundManual` (`staff_refunds.ts`), `staffCancelInstantRequest` (`instant_requests.ts`, tách `applyCustomerCancel`). Năm kind trong `APPROVAL_KINDS`: `transfer_assign`, `transfer_refund`, `transfer_dismiss`, `refund_manual`, `instant_staff_cancel`, đều `execute`, đăng ký qua `approvalKindsFor` (`infra/live_money.ts`).
- **Callable** (`callables/money.ts`): `assignUnmatchedTransfer`, `refundUnmatchedTransfer`, `dismissUnmatchedTransfer` (cổng `transfer.*`), `retryRefund` (trả `{status: 'done', refund}`), `markRefundManual`, `staffCancelInstantRequest` (trả `MoneyResult`). Adapter Firestore `transfer_review_firestore.ts`, `refund_ops_firestore.ts`, `FirestoreAuditLog`; ánh xạ mới trong `booking_firestore.ts` (ghi `null`, không bao giờ `undefined`).
- **Firestore**: chỉ mục `payment_notifications (review.status, receivedAt)` và `(review.status, review.decidedAt DESC)`; `payments (amount, createdAt)`; `refunds (status, createdAt)` và `(status, manual, updatedAt DESC)` (`(status, lastAttemptAt)` đã có); `instant_requests (status, searchDeadlineAt)`. Bản quan hệ ở `specs/data-model/relational-schema.md` (§ refunds, payment_notifications, instant_requests, staff_approvals).
- **Seed** (`firebase/functions/seed/README.md`): `payment_notifications/fake_seed-transfer-unmatched` (2.350.000₫, mở), `payments/seed-payment-expired-7k2mq8` (mã `PB 7K2MQ8`, hết hạn), `refunds/seed-refund-failed` (1.500.000₫), `seed-refund-failed-big` (12.000.000₫), `instant_requests/seed-instant-no-match` (Lan, 690.000₫, `no_match` 8 ngày).
- **Dashboard** (`apps/dashboard`):
  - S23.12 `/staff/transfers?tab=open|resolved&id=…`: reader `server/read/transfers.ts` và `firestore/transfers.ts`, `lib/transfer-tabs.ts`, thư mục `app/(staff)/staff/transfers/`; mục menu `transfers` ("Chưa khớp"), thẻ `transfers_open`.
  - S23.03 `/staff/refunds?tab=failed|stale|awaiting_account|long_hold|manual&id=…`: reader `server/read/refunds.ts` và `firestore/refunds.ts` (`RefundsReader.page/counts/detail`), DTO `RefundRowDto`, `RefundDetailDto`, `InstantHoldRowDto`, `RefundsPageDto` (`kind: 'refund' | 'hold'`) ở `lib/dto.ts`, `lib/refund-tabs.ts`, thư mục `app/(staff)/staff/refunds/` (page, `RefundsScreen.client`, actions `retryRefundAction`, `markRefundManualAction`, `staffCancelInstantAction`, `loadRefundsPage`, `loadRefundDetail`); mục menu `refunds` ("Hoàn tiền", icon `currency_exchange`, `refund.view`), thẻ `refunds_failed` (quá hạn sau 24 giờ kể từ lần gửi cuối), ánh xạ trong `NAV_ID_OF_CARD`.
  - `entityHref('refund', id)` → `/staff/refunds?id=<id>`; `entityHref('instant_request', id)` → `/staff/refunds?tab=long_hold&id=<id>`; nhãn `approval.kind.refund_manual` 'Ghi nhận hoàn thủ công', `approval.kind.instant_staff_cancel` 'Hoàn tiền Chụp ngay'.
  - `DecisionDialog` có `minLength` (đóng chuyển khoản cần 20 ký tự); hộp "Đã hoàn thủ công…" thêm hai trường qua `children`.
- **Playwright**: đã chạy trên emulator 2026-11-15, 20 passed, 1 skipped (mfa.spec). `apps/dashboard/e2e/refunds.spec.ts` (serial, không retry; dùng hết dữ liệu seed, chạy lại cần seed lại emulator): finance đề xuất hoàn thủ công 12.000.000₫ → admin duyệt ở `/staff/approvals`, khoản hoàn `done`, audit có `approval.request`, `approval.decide`, `refund.mark_manual` → finance gán chuyển khoản vào `PB 7K2MQ8` → finance hoàn tiền Chụp ngay giữ lâu. `roles.spec.ts` cập nhật menu (finance và admin có thêm Chưa khớp, Hoàn tiền; B5 quên bước này).

## Rulings (mỗi dòng một quyết định)

Quyết định của plan:

1. **D7 · Hoàn của chuyển khoản chưa khớp** giữ `Refund.paymentId` là chuỗi bắt buộc: `''` kèm `transferRecordId`, thay vì tuỳ chọn ở khoảng 37 chỗ gọi; `isUnmatchedTransferRefund(r)` là phép thử duy nhất. Dùng `gateway`, `providerRef = txnId`, không `destination` (spec §4 "khi chưa có V2"), không bút toán (tiền chưa từng vào sổ); gửi lại qua bộ xử lý `unmatched_transfer`.
2. **D8 · Gán chuyển khoản dùng lại bộ khớp của chủ thể.** `TransferNotification.assignment?: {decidedBy, note, at}`; mọi `SubjectSettler.settle` coi bản ghi đã có là `duplicate` trừ khi `reopensReview(seen, transfer)` (chỉ khi có `assignment` trên bản ghi `needs_review` mở). Gán chạy đúng luật §3.3 tự động và ghi đè bản ghi bằng kết quả cùng `review.resolution = 'assigned'`, nguyên tử trong giao dịch của chủ thể.
3. **D9 · Hoàn thủ công giữ `manual: true`.** `mergeRefundOutcome` lấy `next.manual` khi `done` và mang `manualBy`, `manualPaidAt`, `manualNote`; mọi nơi gọi cũ đã gửi `manual: false` cùng `done`. Bút toán `refund_issued` ghi lúc tạo lệnh hoàn (`transferRefund`, `applyRefundToPayment`) nên đánh dấu thủ công không ghi thêm.

Dòng `Ruling` trong ledger SDD:

4. **Ruling 1 (pre-flight):** Phần B chạy đúng B1–B6 của plan trên phần A đã merge; tên thật của phần A thắng tên cũ trong plan (plan có trước dạng cuối của phần A); nếu sai thì đổi tên.
5. **Ruling 2 (pre-flight):** kind đăng ký qua `approvalKindsFor` trong `infra/live_money.ts` (nuôi `liveApprovalDeps().kinds`), thẻ dùng `QueueCardSpec.count(db, now, role, uid)` và thêm id vào `NAV_ID_OF_CARD`, hộp thoại dùng `children`/`maxLength` của `DecisionDialog`; nếu sai thì đổi chỗ nối dây.
6. **Ruling 3 (pre-flight):** mọi kind duyệt mới gắn với giá trị người đề xuất đã xem, như ruling 16 của phần A: `transfer_assign` `{recordId, paymentId, amount}`, `transfer_refund`/`transfer_dismiss` `{recordId, amount}`, `refund_manual` `{refundId, amount, bankRef, paidAt}`, `instant_staff_cancel` `{requestId, refundVnd}`; callable và dashboard gửi số tiền người dùng đã thấy; `stillValid`/`execute` coi lệch là stale (`conflict`); nếu sai thì thêm trường đầu vào.
7. **Ruling 4 (pre-flight):** hợp đồng D2 áp dụng: chỉ kiểm tra trạng thái đối tượng trước mọi lần ghi mới ném mã `STALE_CODES`; gửi qua cổng/hoàn sau commit không bao giờ ném (`sendRefundOnce` vốn không ném); tránh đóng nhầm `stale` khi thao tác chạy dở.
8. **Ruling 5 (pre-flight):** mỗi người làm cũng chạy `npm run typecheck` ở root và grep `test/` gốc, `api/openapi.yaml` tìm danh sách cố định của thứ mình đổi (lý do hoàn, trường `Refund`, mã lỗi), chạy test root không cần Docker bằng cấu hình vitest tạm không `globalSetup` (xoá sau); #163 từng hỏng CI vì một danh sách như vậy.
9. **Ruling 6 (pre-flight):** `error.already_paid` giữ chữ phần A trừ khi khác chữ B5 của plan, khi đó B5 đặt 'Khoản này đã được trả. Chọn khoản khác hoặc hoàn cho người chuyển.' (plan là nguồn chữ mới hơn; mock không có).
10. **Ruling (B1, tên ngân hàng):** `maskTransferPayer.bankName` dùng `shortName` của `vn_banks` (vd `MBBank`), rơi về mã thô nếu không có; brief ghi "bankName per vn_banks"; nhân viên đọc tên ngân hàng, không đọc mã; nếu sai thì một dòng.
11. **Ruling (B3, huỷ bởi staff):** staff huỷ yêu cầu Chụp ngay giữ lâu ghi `cancelledBy`/trạng thái như đường của khách (`cancelled_by_customer`); actor staff nằm ở dòng audit `instant.staff_cancel`; spec §5.1 nói "chạy đúng luật huỷ của khách … với actor là staff" và mô hình không có giá trị `staff`; nếu sai thì thêm giá trị `staff` cho `cancelledBy` và chữ của app.
12. **Ruling (B5, dòng gợi ý):** dòng gợi ý của S23.12 hiện mã, người trả, loại chủ thể và mã ngắn thay vì tiêu đề booking của mock; tránh đọc theo từng gợi ý (ngân sách §9: tối đa 2 truy vấn mỗi lần mở chi tiết); nếu sai thì thêm một lần đọc gộp để lấy tiêu đề.

Quyết định của B6 (báo cáo B6):

13. **Ruling (B6, audit của duyệt):** dòng `approval.request` và `approval.decide` thuộc thực thể `staff_approval` (id yêu cầu), không thuộc khoản hoàn, nên lọc audit theo khoản hoàn chỉ ra `refund.mark_manual`; Playwright tìm hai dòng kia theo thao tác và theo lý do đã gõ; nếu muốn lọc theo khoản hoàn thì ghi thêm dòng audit với `entityType: refund`.
14. **Ruling (B6, Giữ lâu):** tab chỉ liệt kê yêu cầu `no_match` đã trả tiền (`paidAt` có giá trị), bỏ yêu cầu chưa trả (không có tiền để hoàn); huy hiệu của tab là `count()` nên có thể lớn hơn số hàng hiện.
15. **Ruling (B6, thời gian của "Thất bại"):** tab Thất bại sắp theo `createdAt` (chỉ mục `(status, createdAt)`) nhưng tuổi và thẻ S23.09 `refunds_failed` tính từ `lastAttemptAt` (chỉ mục có sẵn `(status, lastAttemptAt)`); lệnh hoàn chưa từng gửi không có lần gửi cuối nên chỉ vào số "mở" của thẻ.
16. **Ruling (B6, "Gửi lại")** hỏi lý do 5–500 ký tự trong hộp xác nhận vì `retryRefund` nhận `reason`; hai lần bấm liền chỉ gọi một lần nhờ khoá của `DecisionDialog`.
17. **Ruling (B6, khách của một hàng)** lấy từ người trả của payment gốc (một lần đọc `payments/{id}` mỗi payment của trang, tối đa 50, cộng một lần tra tên Auth); khoản hoàn của chuyển khoản chưa khớp không có khách.
18. **Ruling (B6, số hoàn của Giữ lâu)** tính bằng `quoteInstantCancel` của domain trên `{status, amountVnd, paidAt}` đọc được, không dựng đủ `InstantRequest`; hộp gửi lại đúng `refundVnd` đã hiện (ruling 3).

Quyết định của review cuối (fix wave, 2026-11-15):

19. **Ruling (review cuối 1, đánh dấu thủ công và gửi lại):** `mergeRefundOutcome` chỉ nhận `done` do tay (`manual: true`) khi khoản hoàn đang `failed` tại lúc ghi; nếu một người khác vừa bấm "Gửi lại" (`pending`, cuộc gọi cổng có thể đang chạy) thì đánh dấu bị từ chối (`conflict`) để khoản trả qua cổng không bị che; tránh trả hai lần mà chỉ ghi một lần.
20. **Ruling (review cuối 2, người duyệt thứ hai):** DTO của S23.15 có `details` theo từng kind, dựng ở server từ `params` đã lưu cộng các lần đọc theo id (xoá trùng, tối đa vài lần mỗi hàng); `params` thô không bao giờ ra ngoài, số chỉ hiện tối đa 4 số cuối (M5); lỗi đọc làm hỏng trang thay vì để người duyệt duyệt mù.
21. **Ruling (review cuối 3, gán vào `bank_qr` hết hạn):** `notificationOfRecord` mang `maskedPayer` (dạng đã che) để bản ghi ghi lại vẫn hiện người chuyển ở tab Đã xử lý, không dựng lại số đầy đủ. Hoàn muộn khi gán vẫn theo luật chuyển muộn: về tài khoản của người trả khoản đó hoặc chờ khách chọn tài khoản; trả đúng người chuyển cần tài khoản mã hoá của V2 nên ngoài phạm vi, và chữ `s23_12.expired_note` nói đúng điều này (nhân viên muốn trả đúng người chuyển dùng "Hoàn cho người chuyển…").
22. **Ruling (review cuối 4, "Gửi lại"):** `retryRefund` trả thêm `failureReason` khi lần gửi lại kết thúc `failed`; màn hiện toast lỗi 'Cổng vẫn từ chối khoản hoàn ({reason})' (mã qua bảng nhãn nhỏ, rơi về mã thô) và chỉ báo thành công khi trạng thái là `done` hoặc `pending`. Fix direction chỉ nói `refund` nên thêm `failureReason` ở domain là phần mở rộng nhỏ nhất để có lý do.
23. **Ruling (review cuối 5, huỷ Chụp ngay):** `performStaffCancel` gọi `onPostCommitError` khi gửi hoàn lỗi sau commit (như B2/B3); Functions nối vào `logMoneyError('instant.refund_send')`.
24. **Ruling (review cuối 6, ngày hoàn thủ công):** ô ngày có `min` là ngày tạo khoản hoàn và `max` là hôm nay theo giờ Việt Nam (`formatVnDate`), nên chú thích trong e2e đúng; DTO `RefundRowDto` thêm `createdAt`.

## Phần C cần biết

- **Nhóm tiền trên menu** đã có Chi trả, Chưa khớp, Hoàn tiền; **Phần C thêm** Thuế (`tax`, `tax.view`) vào `STAFF_NAV` (`components/nav.ts`) và `roles.spec.ts` (menu finance và admin); Thuế chưa có trong `STAFF_NAV` hiện nay. Mục "Chờ duyệt" vẫn là mục duyệt duy nhất (D11).
- **Thẻ S23.09**: `QUEUE_CARDS` nay có `payouts_waiting`, `transfers_open`, `refunds_failed`, `money_approvals`; spec không có thẻ cho thuế. Mẫu thẻ mới: `count()` kèm `orderBy` trên trường khoảng để có chỉ mục ghép (xem `refundsFailed` ở `server/read/firestore/overview.ts`).
- **Mẫu màn có tab và trang tải thêm**: `refunds/RefundsScreen.client.tsx` (hook `usePaged`, hai `QueueLayout`) và `server/read/firestore/refunds.ts` (hàm `scan` quét tối đa 5 lô); `entityHref` còn thiếu `tax` nếu cần.
- **Mã nhãn audit**: `audit.action.*` mới có cho nhóm `staff.*` và `approval.*`; dòng `refund.*`, `transfer.*`, `instant.staff_cancel`, `payout.*` hiện mã thô ở S23.11 (hàm `actionLabel` rơi về mã). Phần C có thể thêm nhãn cùng đợt thêm `tax.export`.
- **`payments (amount, createdAt)`** và các chỉ mục của #342 đã khai báo; test chỉ mục của dashboard (`test/read/indexes.ts`) kiểm từng truy vấn đọc với `firestore.indexes.json`.
- **Seed của B** nằm sau lịch sử người trả ở `seed/fixtures.ts` (`moneyBDocuments`) để tổng của Lan không đổi; payment của hai khoản hoàn thất bại gắn vào booking có sẵn (`seed-booking-cancelled`, `seed-booking-requested-binh`), trạng thái booking không nhất quán tuyệt đối nhưng đủ cho màn.
- **D10 (thuế)** vẫn như plan: `exportTaxReport` trả `not_eligible` ở nơi kho dev không được phép; `idLast4` trên bản ghi định danh.

## Còn mở (hoãn đến review cuối hoặc ticket sau)

Từ review của B2:

- Stale khi lệch số tiền chỉ có test cho `assign` (hoàn và đóng dùng chung `openRecord`).

Từ review của B3:

- `staffCancelInstantRequest` có kiểm `r === null` hai lần (để thu hẹp kiểu).
- Yêu cầu `no_match` chưa trả tiền vẫn huỷ được bằng staff với `refundVnd` 0 (không có tiền đi; audit vẫn ghi).
- (đã sửa ở review cuối, ruling 23) `sendInstantRefunds` nuốt lỗi sau commit mà không gọi `onPostCommitError`.

Từ review của B4:

- Seed: tên ngân hàng người chuyển là `MB` còn mask thật cho `MBBank` (`fixtures.ts:288`, `seed_fixtures.test.ts:1376`).
- Test từ chối chưa chứng minh từng callable kiểm đúng hành động của nó (thiếu test dương theo từng hành động).
- `liveApprovalDeps` dựng bộ `liveMoneyBDeps` lần thứ hai (nhiễu).
- Test đơn vị của B4 viết cùng lúc với code, không thấy đỏ trước.

Từ review của B5:

- Ép kiểu `as unknown as Payment` ở reader chuyển khoản; `transferCode` xuất hiện hai lần.
- Dấu ` · ` và `shortId` dựng trong code thay vì mẫu ở `vi.ts` hoặc hàm dùng chung.

Từ B6:

- Test nhãn thẻ, menu và `entityHref` của B6 viết sau code (reader và màn thì viết test trước, thấy đỏ vì thiếu module).
- Dòng audit của hoàn thủ công và huỷ Chụp ngay chưa có nhãn tiếng Việt (S23.11 hiện mã thô).
- `shortId` và cách dựng ` · ` ở `RefundsScreen` lặp với màn chuyển khoản; gom về một hàm dùng chung khi có màn thứ ba.
- Trang `?id=` của khoản hoàn ở tab `long_hold` bỏ qua (id lúc đó là yêu cầu Chụp ngay); yêu cầu ngoài trang đầu không tự mở được.
- Chi phí đọc tab hoàn tiền: tối đa 50 lần đọc `payments/{id}` mỗi trang (một lần mỗi payment).

Từ review cuối (hoãn, không sửa):

- Bản ghi `needs_review` cũ viết trước #342 thiếu `review`/`amount`/`content` nên không bao giờ hiện ở S23.12 (không backfill; vô hại khi Blaze còn tắt).
- Việc tiếp theo: thêm giá trị `staff` cho `InstantRequest.cancelledBy` hoặc một thông báo cho khách (hiện staff huỷ ghi `cancelled_by_customer`, ruling 11).
- Cửa sổ gợi ý `limit(100)` của S23.12 đếm cả các khoản đã trả (lọc trạng thái xảy ra sau khi đọc), nên có thể bỏ sót ứng viên hợp lệ khi có nhiều khoản cùng số tiền.
- Chữ lệch mock: `detail_sub` bỏ "(không tồn tại)"; nhãn phương thức hiện "qua cổng/chuyển khoản" thay vì "VietQR/MoMo"; `failureReason` hiện mã thô ở danh sách và chi tiết (chỉ toast "Gửi lại" có bảng nhãn).
- Chữ mới của S23.15 (`s23_15.details`, `s23_15.d.*`, `s23_15.payment_status.*`) và của toast "Gửi lại" (`s23_03.retry_failed`, `s23_03.failure.*`) ở bảng bên dưới.

## Chữ tiếng Việt mới không có chữ trong mock (chủ sản phẩm xem lại)

Ở booking-be `apps/dashboard/src/messages/vi.ts`. Từ báo cáo B5 (khoá `s23_12.*`, ngoài những chữ có trong mock hoặc brief):

| Nhóm | Chữ |
|---|---|
| Tab, lỗi, trạng thái trống S23.12 | Trạng thái chuyển khoản · Không tải được danh sách chuyển khoản · Không có chuyển khoản nào chưa khớp · Chưa xử lý chuyển khoản nào trong 30 ngày qua |
| Nhãn kết quả | Đã gán · Đã hoàn · Đã đóng · Xử lý bởi |
| Chi tiết | Đang tải chi tiết… · Không tải được chi tiết chuyển khoản · Không có khoản nào cùng số tiền trong 48 giờ quanh lúc nhận · nhãn chủ thể (booking, vé, phí xác minh, chụp ngay, nhóm) |
| Tiêu đề và tóm tắt hộp | Gán {amount} cho khoản {code}? · Hoàn {amount} cho người chuyển? · Đóng chuyển khoản {amount} mà không hoàn? · ba câu tóm tắt · Từ {threshold} cần một người khác (admin hoặc finance) duyệt trong 24 giờ. |
| Thông báo | Đã gán chuyển khoản · Đã hoàn cho người chuyển · Đã đóng chuyển khoản · Đã gửi duyệt lần hai |
| Thẻ, menu | Chuyển khoản chưa khớp (`queue.transfers_open`) · Chưa khớp (`nav.transfers`) |
| Lỗi mã | Khoản này đã được trả. Chọn khoản khác hoặc hoàn cho người chuyển. |

Từ B6 (khoá `s23_03.*`, ngoài những chữ có trong mock hoặc brief):

| Nhóm | Chữ |
|---|---|
| Tab, lỗi | Trạng thái hoàn tiền (tên danh sách tab) · Không tải được danh sách hoàn tiền · Không tải được chi tiết khoản hoàn · Đang tải chi tiết… |
| Trạng thái trống | Không có khoản hoàn nào thất bại · Không có khoản hoàn nào chờ quá 2 giờ · Không có khoản hoàn nào đang chờ khách chọn tài khoản quá 24 giờ · Không có yêu cầu Chụp ngay nào giữ tiền quá 7 ngày · Chưa ghi nhận khoản hoàn thủ công nào trong 30 ngày qua |
| Cột | Khách · Số tiền · Lý do · Lỗi · Hết tìm từ |
| Chủ thể, phương thức | booking · vé · Chụp ngay · chuyển khoản chưa khớp · phí xác minh · qua cổng · chuyển khoản |
| Lý do hoàn (nhãn của `PAYMENT_REFUND_REASONS`) | Khách chuyển thừa · Khách chuyển thiếu, khoản đã hết hạn · Chuyển khoản đến muộn · Chuyển khoản trùng · Đã trả nhưng đơn đã hết hạn · Nhiếp ảnh gia không nhận đơn · Chuyển khoản chưa khớp |
| Chip lỗi | Cổng từ chối · {n} giờ (có trong mock) · Chưa có kết quả · {n} giờ · Chờ khách · {n} giờ |
| Chi tiết | Hoàn {amount} ({percent}%) (mock) · refund {id} · {subject} {subjectId} · Đã trả · đã hoàn {amount} · Người chuyển · Lần gửi · {n} lần · {time} · "{reason}" · Ghi nhận bởi · {name} · chuyển ngày {date} · mã {ref} · Ghi chú |
| Hộp "Gửi lại" | Gửi lại khoản hoàn {amount}? · Gửi lại cùng mã hoàn qua cổng: bấm hai lần cũng chỉ chuyển một lần. |
| Hộp "Đã hoàn thủ công…" | Ghi nhận đã hoàn tay {amount}? · Dùng khi bạn đã chuyển tiền cho khách ngoài hệ thống. Khoản hoàn chuyển sang đã hoàn và không gửi lại nữa. · Ghi nhận đã hoàn (nhãn xác nhận dưới ngưỡng) · 3 đến 64 ký tự, không có khoảng trắng · Mã giao dịch ngân hàng và Ngày chuyển (mock) |
| Giữ lâu | Hoàn cho khách… và Hoàn cho khách · Hoàn {amount} cho khách? · Huỷ yêu cầu Chụp ngay của {customer} và hoàn toàn bộ số tiền đã giữ, đúng luật huỷ của khách. · Chụp ngay · {amount} · yêu cầu {id} · Không tìm được nhiếp ảnh gia từ · {n} ngày · Hoàn khi huỷ |
| Thông báo | Đã gửi lại khoản hoàn · Đã ghi nhận hoàn thủ công · Đã hoàn cho khách · Đã gửi duyệt lần hai |
| Thẻ | Hoàn tiền thất bại (`queue.refunds_failed`) |

Từ review cuối (khoá `s23_15.*`, `s23_03.*`, `s23_12.expired_note`):

| Nhóm | Chữ |
|---|---|
| Chi tiết duyệt S23.15 | Nội dung sẽ chạy · Số tiền chuyển · Nội dung chuyển khoản · Người chuyển · Mã chuyển khoản của khoản thanh toán · Trạng thái khoản thanh toán · Người trả khoản thanh toán · Số tiền hoàn · Mã giao dịch ngân hàng · Ngày chuyển · Thuộc về · Khách · Tài khoản nhận · Chủ tài khoản · Đang chờ thanh toán · Đã hết hạn |
| Toast "Gửi lại" | Cổng vẫn từ chối khoản hoàn ({reason}) · chưa có tài khoản nhận · cổng không phản hồi · cổng từ chối |
| Ghi chú gán vào khoản hết hạn (thay chữ cũ) | Khoản này đã hết hạn: gán sẽ hoàn toàn bộ theo luật chuyển muộn, về tài khoản của người trả khoản này hoặc chờ khách chọn tài khoản. Muốn trả lại đúng người chuyển, dùng "Hoàn cho người chuyển…". |
