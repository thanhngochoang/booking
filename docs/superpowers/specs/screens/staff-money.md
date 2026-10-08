# S23 · Tiền: chi trả, chuyển khoản chưa khớp, hoàn tiền, thuế (#163)

- **Issue:** #163, epic #83. **Ngày:** 2026-10-08. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` (gọi là "spec dashboard": kiến trúc, quyền, `audit_log`, thành phần, mẫu hàng đợi; không nhắc lại ở đây), `../2026-10-06-payments-payouts-design.md` (gọi là "spec thanh toán"), `../../plans/2026-10-08-s04-reconciliation.md` (V1–V3).
- **Mock:** `docs/design/dashboard-mock.html#S23.02` và các màn bên dưới.
- **Vai trò:** mọi màn ở đây chỉ `admin` và `finance` (spec dashboard §4.2).

## 0. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| M1 | Làm đủ việc hằng ngày: chi trả chờ duyệt / tạm giữ / thất bại, chuyển khoản chưa khớp, hoàn tiền thất bại và hoàn thủ công, báo cáo thuế theo tháng. **Đối soát sao kê ngày** chỉ thiết kế (màn + port) ở §6, làm khi đã chọn tổ chức trung gian. | chủ dự án 2026-10-08 |
| M2 | **Duyệt hai người** cho thao tác tiền từ **10.000.000₫** trở lên: một người đề xuất, một người khác (admin hoặc finance) xác nhận. Ngưỡng là hằng số có phiên bản `DEFAULT_MONEY_CONTROLS.twoPersonThreshold` trong domain (như `DEFAULT_PAYOUT_POLICY`), đổi bằng một PR; chuyển thành cấu hình sửa được khi #168 có màn cấu hình. | chủ dự án 2026-10-08 |
| M3 | Thao tác cần hai người: duyệt lần chi đầu, gán chuyển khoản chưa khớp, hoàn chuyển khoản chưa khớp, đóng chuyển khoản chưa khớp không hoàn, ghi nhận hoàn thủ công. Thao tác **không** đưa tiền mới đi đâu thì một người là đủ: tạm giữ, tiếp tục, chạy lại khoản chi đã duyệt, gửi lại một khoản hoàn đã có. | — |
| M4 | Tiền chỉ đi qua callable (spec dashboard D2); mỗi quyết định một dòng `audit_log` với lý do 5–500 ký tự. Không có thao tác "sửa số tiền". | spec chính §3i.6 |
| M5 | Finance thấy họ tên đã xác minh của người nhận (để so tên tài khoản), 4 số cuối tài khoản, 4 số cuối giấy tờ. Số giấy tờ đầy đủ chỉ nằm trong **tệp thuế xuất ra** (bắt buộc cho kê khai), không hiện trên màn. | spec xác minh 10-06, M5 ở đây |

## 1. Màn và mã

| Mã | Màn | Route | Ghi chú |
|---|---|---|---|
| S23.02 | Chi trả: chờ duyệt, tạm giữ, thất bại, đang xử lý quá lâu | `/staff/payouts` | đổi mô tả: phần đối soát chuyển sang S23.14 |
| S23.03 | Hoàn tiền: thất bại, chờ quá lâu, ghi nhận hoàn thủ công | `/staff/refunds` | |
| S23.12 | Chuyển khoản chưa khớp (`needs_review`) | `/staff/transfers` | mới |
| S23.13 | Báo cáo thuế theo tháng | `/staff/tax` | mới |
| S23.14 | Đối soát sao kê ngày | `/staff/reconciliation` | mới, chỉ thiết kế (§6) |
| S23.15 | Chờ duyệt lần hai | `/staff/approvals` | mới; màn và cơ chế ở spec dashboard §5.4 |

Thanh bên nhóm "Tiền": Chi trả · Chưa khớp · Hoàn tiền · Duyệt lần hai · Thuế (· Đối soát khi làm §6). Thẻ trên S23.09: chi trả chờ duyệt, chuyển khoản chưa khớp, hoàn tiền thất bại, chờ duyệt lần hai.

## 2. Duyệt hai người

Cơ chế chung `staff_approvals` và màn S23.15 nằm ở spec dashboard §5.4 (nền tảng #162, dùng chung với #164). Phần của tiền:

- `kind`: `payout_approve`, `transfer_assign`, `transfer_refund`, `transfer_dismiss`, `refund_manual`, `instant_staff_cancel`; người duyệt cần `money_approval.decide` (admin, finance).
- Callable thao tác tiền (§3–§5, §5.1) tự quyết: `amount < DEFAULT_MONEY_CONTROLS.twoPersonThreshold` thì làm ngay; ngược lại tạo yêu cầu `pending` và trả `{status: 'awaiting_second_approval', approvalId}`.
- `amount` của yêu cầu là số tiền thao tác đưa đi (thực nhận của khoản chi, số tiền hoàn, số tiền chuyển khoản).

## 3. S23.02 · Chi trả

- **Thông tin:** `/staff/payouts` · admin, finance · chưa có. Cần #134 (trạng thái `needs_approval`, `approvePayout`, `DEFAULT_PAYOUT_POLICY`, `nameStatus`).
- **Mục đích:** cho khoản chi đầu tiên đi, xử lý khoản bị giữ hoặc lỗi.
- **Bố cục:** tab: **Chờ duyệt** (`needs_approval`) · **Tạm giữ** (`on_hold`) · **Thất bại** (`failed`) · **Đang xử lý lâu** (`processing` quá 2 giờ) · **Đã chi** (30 ngày gần nhất, chỉ xem).
  - Bảng: người nhận (tên, loại `individual` / `artist` / `studio`), thực nhận, số khoản, lý do (chip: "Lần chi đầu", "Tên chờ đối chiếu", "3 lần thất bại", "Khiếu nại", "Đổi tài khoản"), tạo lúc, tài khoản (ngân hàng •••• 4 số).
  - `DetailPane`:
    - **Tài khoản nhận:** ngân hàng, •••• 4 số, tên chủ tài khoản, `nameStatus` (Khớp / Chờ đối chiếu / Staff đã xác nhận), `activeFrom` (còn khoá 72 giờ thì ghi rõ), **họ tên đã xác minh** để so.
    - **Các khoản:** mỗi dòng booking hoặc vé: số tiền gộp, hoa hồng (khi > 0), thuế khấu trừ (`taxRateBp`), thực nhận; dòng tổng.
    - **Lịch sử chi** cho tài khoản này (5 lần gần nhất).
    - Lý do tạm giữ, lỗi lần chạy trước (`failureReason`).
  - Chân theo tab: Chờ duyệt → chính "Duyệt chi"; Tạm giữ → chính "Tiếp tục chi"; Thất bại / Đang xử lý lâu → chính "Chạy lại". Nút phụ "Tạm giữ…" ở mọi tab còn mở.
- **Dữ liệu:** `payouts` theo `(status, createdAt)`, trang 50; `payoutAccounts/{uid}/accounts/{id}` (chỉ trường đã che); `users/{uid}/private/identity.legalName`; `payouts` cùng `accountId` cho lịch sử. Không đọc `accountNumberEnc`.
- **Tương tác:**
  - "Duyệt chi" → `DecisionDialog` "Chi {thực nhận} cho {tên} về {ngân hàng} •••• {4 số}?" + lý do → `approvePayout`. Từ 10 triệu: hộp đổi chữ thành "Gửi duyệt lần hai", kết quả là yêu cầu S23.15. Duyệt cũng đặt tài khoản `pending_review` thành `staff_confirmed` (#134 Decision 5).
  - "Tạm giữ…" → lý do → `holdPayout`. "Tiếp tục chi" → `resumePayout` (quay về `needs_approval` khi tài khoản chưa có lần chi nào, #134 Decision 7). "Chạy lại" → `executePayout` (từ chối `not_eligible` khi tài khoản còn trong 72 giờ khoá).
- **Quá hạn:** Chờ duyệt quá 24 giờ, Tạm giữ quá 72 giờ, Đang xử lý quá 2 giờ.
- **Trạng thái:** trống theo từng tab; `not_eligible` ("Tài khoản mới đang trong 72 giờ khoá, chi được từ {giờ}"); `awaiting_second_approval` (toast + chip "Chờ duyệt lần hai" trên dòng).
- **Chấp nhận:** khoản chi đầu dưới 10 triệu được duyệt bởi một người và đi ở lần chạy `executePayout` kế tiếp; từ 10 triệu cần người thứ hai; finance không thấy số tài khoản đầy đủ ở bất kỳ đâu (DTO, log, lỗi).

## 4. S23.12 · Chuyển khoản chưa khớp

Hôm nay chuyển khoản không khớp được khoản nào chỉ được lưu ở `payment_notifications/{provider}_{txnId}` với `outcome: 'needs_review'` (`handle_transfer.ts`); không có `Payment` nào ở `needs_review` (bảng đối chiếu S04). Spec này giữ cách đó và thêm trạng thái xử lý cho bản ghi.

**Thay đổi dữ liệu:** `TransferRecord` thêm
- `review?: {status: 'open' | 'resolved', resolution?: 'assigned' | 'refunded' | 'dismissed', paymentId?, refundId?, decidedBy?, decidedAt?, note?}`. `handleTransferNotification` ghi `review.status = 'open'` khi `outcome = needs_review`.
- `payer?: {bankName?, accountLast4?, name?}`: tách từ `raw` ở server lúc ghi (che sẵn). V2 thêm bản mã hoá đầy đủ (`StoredBankAccount`); khi chưa có V2 thì hoàn cho người chuyển dựa vào thông tin cổng trả lại (`transferRefund` như các đường hoàn tự động hiện có).
- `Refund.paymentId` thành tuỳ chọn và thêm `transferRecordId?`: khoản hoàn của chuyển khoản không thuộc payment nào (lý do `unmatched_transfer`, `fromEscrow: false`). Cập nhật `domain-model.md` và `relational-schema.md`.

- **Thông tin:** `/staff/transfers` · admin, finance · chưa có. Không phụ thuộc issue Phase 1 nào ngoài #129 (đã merge).
- **Mục đích:** đưa mỗi khoản tiền vào đúng chỗ, hoặc trả lại người chuyển.
- **Bố cục:** tab **Cần xử lý** · **Đã xử lý** (30 ngày). Bảng: nhận lúc, số tiền, nội dung chuyển khoản (nguyên văn, chữ đều), người chuyển (ngân hàng, tên, •••• 4 số), tuổi. `DetailPane`:
  - Thông tin chuyển khoản như trên + mã giao dịch của cổng.
  - **Gợi ý khoản thanh toán:** tối đa 5 payment `created` hoặc `expired` cùng số tiền, tạo trong 48 giờ quanh lúc nhận; payment có mã chuyển khoản cách nội dung một ký tự (đọc nhầm `PB 7K2…`) đứng đầu. Mỗi gợi ý: mã, khách, booking/vé, số tiền, trạng thái, hạn. Hàm thuần `suggestPaymentsForTransfer` trong domain (BFF gọi để xếp hạng, không ghi).
  - Chân: chính "Gán cho khoản đã chọn" (bật khi chọn một gợi ý); phụ "Hoàn cho người chuyển…", "Đóng, không hoàn…".
- **Tương tác:**
  - "Gán" → `assignUnmatchedTransfer({recordId, paymentId, reason})`: chạy đúng luật `applyTransfer` của #129 như thể nội dung đã khớp (đủ → `paid`; thừa → hoàn phần thừa; payment đã hết hạn → hoàn toàn bộ theo bảng §3.3 spec thanh toán). `review.resolution = assigned`.
  - "Hoàn cho người chuyển…" → `refundUnmatchedTransfer({recordId, reason})`: tạo `Refund` (`unmatched_transfer`) toàn bộ số tiền, gửi cổng. `resolution = refunded`.
  - "Đóng, không hoàn…" → `dismissUnmatchedTransfer({recordId, reason})`, ví dụ tiền đã trả tay ngoài hệ thống; lý do bắt buộc ít nhất 20 ký tự. `resolution = dismissed`.
  - Cả ba theo M2 (từ 10 triệu cần người thứ hai).
- **Quá hạn:** quá 24 giờ.
- **Index:** `payment_notifications (review.status, receivedAt)`; `payments (amount, createdAt)` cho gợi ý.
- **Chấp nhận:** một bản ghi chỉ được xử lý một lần; gán vào payment đã `paid` bị từ chối (`already_paid`); các trường hợp của bảng §3.3 có test.

## 5. S23.03 · Hoàn tiền

Hôm nay lỗi cổng khi hoàn biến khoản hoàn thành `failed` + `manual: true` và không gửi lại (Ruling 7); trạng thái `awaiting_account` và gửi lại tự động là V2 (bảng đối chiếu S04, chưa có issue).

- **Thông tin:** `/staff/refunds` · admin, finance · chưa có. Cần #141 (S22) cho tab "Chờ khách chọn tài khoản".
- **Mục đích:** không để khoản hoàn nào nằm lại.
- **Bố cục:** tab **Thất bại** (`failed`) · **Chờ quá lâu** (`pending` quá 2 giờ) · **Chờ khách chọn tài khoản** (`awaiting_account` quá 24 giờ, chỉ xem; có khi V2 xong) · **Giữ lâu** (§5.1) · **Đã hoàn thủ công** (30 ngày). Bảng: khách, số tiền, phần trăm, lý do hoàn (nhãn từ `PAYMENT_REFUND_REASONS`), chủ thể (booking / vé / Chụp ngay / chuyển khoản chưa khớp), phương thức gốc, tuổi, lỗi cổng. `DetailPane`: payment gốc (số đã trả, đã hoàn), booking hoặc vé, lịch sử các lần gửi, người chuyển (che).
- **Tương tác:**
  - Chính "Gửi lại" → `retryRefund({refundId, reason})`: gửi lại **cùng id** qua cổng (khoá chống trùng là id khoản hoàn), một người là đủ (M3). Khi V2 có `sendRefundOnce` thì dùng nó; trước đó gọi `dispatchRefund` với cùng id.
  - Phụ "Đã hoàn thủ công…" → `DecisionDialog`: mã giao dịch ngân hàng, ngày chuyển, lý do → `markRefundManual({refundId, bankRef, paidAt, reason})`: `status = done`, `manual = true`, `providerRef = bankRef`. Theo M2. Plan kiểm bút toán `refund_issued` đã ghi lúc tạo khoản hoàn hay chưa; nếu chưa thì ghi lúc này.
- **Quá hạn:** Thất bại quá 24 giờ.
- **Chấp nhận:** "Gửi lại" hai lần liền chỉ tạo một lần chuyển ở cổng giả; khoản đã `done` không đổi được nữa.

### 5.1 Tiền giữ lâu (sau #140)

Yêu cầu Chụp ngay ở `no_match` giữ tiền tới khi khách huỷ (#140 câu hỏi 5). Tab "Giữ lâu" liệt kê yêu cầu `no_match` quá 7 ngày; "Hoàn cho khách…" gọi `staffCancelInstantRequest({requestId, reason})`, chạy đúng luật huỷ của khách (hoàn 100%) với actor là staff. Chỉ làm khi #140 đã merge; trước đó tab không hiện.

## 6. S23.14 · Đối soát sao kê ngày (chỉ thiết kế)

Làm khi đã chọn tổ chức trung gian (spec thanh toán §10), vì định dạng sao kê chưa biết.

- **Port** `StatementSource.fetchDay(day) → StatementLine[]` (`{providerRef, kind: 'in' | 'out' | 'fee', amount, at, content}`), adapter theo nhà cung cấp; cổng giả sinh sao kê từ chính các giao dịch của nó.
- **Job** `reconcileStatement` mỗi ngày 06:00 (giờ Việt Nam) cho ngày hôm trước: ghép dòng sao kê với `ledger_entries` theo `providerRef`, ghi `reconciliation_days/{day}` (số dòng khớp, tổng vào, tổng ra, phí) và `reconciliation_items/{id}` cho mỗi dòng lệch: `missing_in_ledger`, `missing_in_statement`, `amount_mismatch`.
- **Màn:** chọn ngày; bốn ô tổng (vào, ra, phí, số dòng lệch); bảng dòng lệch; mỗi dòng "Đánh dấu đã xử lý…" với ghi chú (`resolveReconciliationItem`). Không có thao tác sửa sổ cái từ màn này; tiền sai đi qua S23.12 hoặc S23.03.
- Bút toán phí (`gateway_fee`, `payout_fee`) là V3, cũng làm lúc này.

## 7. S23.13 · Báo cáo thuế

- **Thông tin:** `/staff/tax` · admin, finance · chưa có. Cần #134 (`taxWithheld`, `taxRateBp` trên khoản chi).
- **Mục đích:** đưa kế toán số thuế đã khấu trừ của từng người theo tháng.
- **Bố cục:** chọn tháng (mặc định tháng trước). Bốn ô: tổng đã chi gộp, thuế GTGT, thuế TNCN, số người. Bảng theo người nhận: tên đã xác minh, loại, giấy tờ •••• 4 số, số lần chi, gộp, GTGT, TNCN, thực nhận. Nút chính "Xuất tệp CSV". Dòng chú thích: "Tỉ lệ 5% GTGT + 2% TNCN cho cá nhân, 0% cho studio, chờ kế toán xác nhận".
- **Dữ liệu:** `payouts` `status = paid` có `paidAt` trong tháng (giờ Việt Nam), gom theo `payeeId`. Thuế lấy theo khoản chi (đã chụp tỉ lệ), không tính lại.
- **Xuất tệp:** `exportTaxReport({period: 'YYYY-MM', reason})` → server dựng CSV (UTF-8 có BOM để Excel đọc đúng dấu) gồm các cột trên **cộng số định danh đầy đủ** (giải mã ở server), ghi vào Storage `exports/tax/{period}/{ulid}.csv`, trả URL ký 5 phút; `audit_log` `tax.export`. Tệp tự xoá sau 7 ngày (bước của job hằng ngày). Không cần hai người (không chuyển tiền).
- **Chấp nhận:** tổng trên màn bằng tổng trong tệp; tháng không có khoản chi nào cho ra tệp chỉ có dòng tiêu đề; mỗi lần xuất một dòng audit.

## 8. Bảng quyền và callable

`StaffAction` thêm vào `staff_permissions.ts` (đều là `admin`, `finance`): `payout.view`, `payout.approve`, `payout.hold`, `payout.resume`, `payout.execute`, `transfer.view`, `transfer.assign`, `transfer.refund`, `transfer.dismiss`, `refund.view`, `refund.retry`, `refund.mark_manual`, `instant.staff_cancel`, `tax.view`, `tax.export`, `money_approval.decide`.

| Callable | Đầu vào | Hai người | Use case (domain) |
|---|---|---|---|
| `approvePayout` | `{payoutId, reason}` | từ 10 triệu | `approvePayout` (#134) |
| `holdPayout` | `{payoutId, reason}` | — | `holdPayout` (có) |
| `resumePayout` | `{payoutId, reason}` | — | `resumePayout` (có) |
| `executePayout` | `{payoutId, reason}` | — | `executePayout` (có) |
| `assignUnmatchedTransfer` | `{recordId, paymentId, reason}` | từ 10 triệu | mới, dùng `applyTransfer` |
| `refundUnmatchedTransfer` | `{recordId, reason}` | từ 10 triệu | mới |
| `dismissUnmatchedTransfer` | `{recordId, reason}` | từ 10 triệu | mới |
| `retryRefund` | `{refundId, reason}` | — | `dispatchRefund` / `sendRefundOnce` (V2) |
| `markRefundManual` | `{refundId, bankRef, paidAt, reason}` | từ 10 triệu | mới |
| `staffCancelInstantRequest` | `{requestId, reason}` | từ 10 triệu | luật huỷ của #140 |
| `exportTaxReport` | `{period, reason}` | — | mới (`buildTaxReport` thuần) |

- Mọi callable: `assertStaff(request, action)` (spec dashboard §4.3), `idempotencyKey` (ULID tạo khi mở hộp), trả `{status: 'done'}` hoặc `{status: 'awaiting_second_approval', approvalId}`.
- CLI `npm run payouts` giữ nguyên, đi qua cùng use case, nên cũng chịu M2 (CLI không có người thứ hai: thao tác từ 10 triệu bằng CLI tạo yêu cầu S23.15).
- `getSensitiveFileUrl` thêm `kind` `tax_export` (đường dẫn `exports/tax/…`, quyền `tax.export`).

## 9. Chi phí

Hàng đợi tiền nhỏ (vài chục dòng mở); mỗi lần làm mới là 1–2 `count()` + một trang 50 dòng. Với 2 người làm tiền, 8 giờ/ngày, làm mới 30 giây khi màn đang mở: khoảng 2 × 8 × 120 × 3 ≈ 5.800 lượt đọc/ngày, trong hạn mức miễn phí. Gợi ý khoản thanh toán: tối đa 2 truy vấn mỗi lần mở chi tiết. Tệp thuế: vài KB mỗi tháng trên Storage. Callable: vài trăm lần/tháng. Tổng cộng thêm **~$0** ở cả mức 1.000 và 10.000 người dùng.

## 10. Kiểm thử

- **Domain:** `requiresTwoPeople(amount)` ở biên 9.999.999 / 10.000.000; `decideStaffApproval` (`same_person`, `expired`, `stale`, chạy đúng một lần); `assignUnmatchedTransfer` cho từng hàng của bảng §3.3 spec thanh toán; `refundUnmatchedTransfer` (không có payment, `fromEscrow: false`); `markRefundManual` trên `failed` / `done`; `suggestPaymentsForTransfer` (cùng số tiền, khoảng 48 giờ, mã sai một ký tự đứng đầu); `buildTaxReport` (gom theo người, tháng theo giờ Việt Nam, studio 0%).
- **Functions:** mỗi callable × vai trò (support, sales bị từ chối); `exportTaxReport` ghi tệp và audit; CLI payouts từ 10 triệu tạo yêu cầu thay vì chạy.
- **Rules:** client không đọc `staff_approvals`, `exports/**`.
- **Dashboard:** DTO chi trả không có trường số tài khoản đầy đủ; hộp "Duyệt chi" đổi thành "Gửi duyệt lần hai" từ 10 triệu; người đề xuất thấy "Huỷ yêu cầu", không thấy "Duyệt".
- **Playwright:** finance A đề xuất hoàn thủ công 12.000.000₫ → finance B duyệt ở S23.15 → khoản hoàn `done`, ba dòng audit.

## 11. Phụ thuộc và việc chưa có chủ

- Cứng: #162 (nền tảng), #134 (chi trả), #141 (S22: `awaiting_account`).
- Mềm: V2 (gửi lại hoàn tiền, tài khoản người chuyển) chưa có issue; spec này chạy được không có V2 (§4, §5). #140 cho §5.1.
- Đối soát sao kê và V3 (§6) chờ chọn tổ chức trung gian.

## 12. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Thuế 7% cho cá nhân và NAG, 0% cho studio | Như #134, chờ kế toán xác nhận |
| Q2 | Yêu cầu duyệt lần hai hết hạn sau bao lâu? | 24 giờ |
| Q3 | Báo cho finance khác khi có yêu cầu chờ duyệt? | Chỉ số đếm trên thanh bên và thẻ S23.09; chưa có email |
| Q4 | Tệp thuế giữ bao lâu? | 7 ngày rồi xoá |
