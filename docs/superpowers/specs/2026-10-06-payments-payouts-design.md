# Thanh toán, chi trả và doanh thu nền tảng

Ngày: 2026-10-06 · Trạng thái: chờ duyệt · Thay: §3g (tiền treo và chi trả) của spec chính `2026-10-01-remaining-screens.md` ở các điểm nêu dưới; bổ sung spec 2026-10-05 §4.1 (trả 100%, hai mốc). Nghiên cứu nền: [`docs/research/2026-10-06-payments-vietnam.md`](../../research/2026-10-06-payments-vietnam.md). Ghi chú điều khoản: `docs/legal/terms-and-help-notes.md`.

## 1. Quyết định đã chốt

| # | Quyết định |
|---|---|
| M1 | **Mô hình A1**: app là sàn; tiền booking do một **tổ chức trung gian thanh toán có phép** (dịch vụ thu hộ / chi hộ) giữ; app chỉ ra lệnh thu, hoàn, chi. Nền tảng không nhận tiền booking vào tài khoản của mình. |
| M2 | Khách trả **100%** khi đặt; hai mốc chuyển như spec 2026-10-05 và spec bàn giao hai lớp (mốc 1 sau buổi chụp + 24 giờ; mốc 2 sau khi đồng ý ảnh + 48 giờ). Không còn "cọc". |
| M3 | Phương thức lúc ra mắt: **chuyển khoản VietQR** (mặc định) và **ví MoMo, ZaloPay**. Thẻ nội địa và thẻ quốc tế thiết kế sẵn chỗ, bật sau. |
| M4 | **Nền tảng chịu phí cổng và phí chi** giai đoạn đầu; ghi vào sổ cái. |
| M5 | Chi **tự động mỗi ngày**, không ngưỡng tối thiểu; **lần chi đầu của mỗi tài khoản nhận tiền do staff duyệt**. |
| M6 | Tài khoản nhận tiền chỉ hỏi ở lần chi đầu; tên chủ tài khoản phải khớp tên đã xác minh; đổi tài khoản cần OTP và có hiệu lực sau 72 giờ. |
| M7 | Doanh thu nền tảng chỉ đến từ **dịch vụ của chính nền tảng**: hoa hồng sàn (mặc định **0%**, cấu hình), phí xác minh (đang chạy), gói Pro/Studio và đẩy tin (giữ chỗ). |
| M8 | Thợ cá nhân: nền tảng khấu trừ thuế theo Nghị định 117/2025 (đề xuất 5% GTGT + 2% TNCN, chờ kế toán xác nhận, là cấu hình). |

## 2. Hai luồng tiền

| Luồng | Tiền nằm ở đâu | Ai là bên nhận | Hoá đơn |
|---|---|---|---|
| **Tiền booking, vé** (của khách trả cho thợ/studio/chủ sự kiện) | Tài khoản thu hộ/chi hộ của tổ chức trung gian | Thợ/studio (theo mốc); khách (khi hoàn) | Thợ/studio chịu trách nhiệm với khách; nền tảng khấu trừ thuế thay thợ cá nhân |
| **Doanh thu nền tảng** (hoa hồng, phí xác minh, gói, đẩy tin; vé sự kiện do nền tảng tổ chức) | Tài khoản doanh nghiệp của nền tảng | Nền tảng | Nền tảng xuất **hoá đơn điện tử** |

Hoa hồng sàn được tổ chức trung gian **tách khi chi** và chuyển về tài khoản nền tảng (điều kiện chọn đối tác, §10). Phí xác minh, gói, đẩy tin thu thẳng vào tài khoản nền tảng (VietQR/ví), không qua phần giữ hộ.

## 3. Thu tiền

### 3.1 Phương thức

`PaymentProvider` (tổ chức trung gian: `ninepay`, `zalopay`, `vnpay`, `nganluong`, …, chọn ở §10) tách khỏi `PaymentMethod`: `bank_qr` (mặc định), `momo`, `zalopay`; để sẵn `domestic_card`, `intl_card` (tắt bằng cờ cấu hình).

### 3.2 Luồng

1. **S04.03** (bước 4/4 đặt lịch, đổi tên "Xem lại & thanh toán"): bảng tiền "Thanh toán 100% · {giá}", dòng `EscrowNotice` "Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc", chọn phương thức (VietQR chọn sẵn, "Miễn phí · xác nhận ngay"; MoMo; ZaloPay), chính sách huỷ tính trên số đã trả, nút chính **"Thanh toán {giá}"** → callable `createPayment`.
2. `createPayment` tạo `Payment` (`status = created`, `expiresAt` = +15 phút) và yêu cầu thanh toán ở tổ chức trung gian: VietQR động (số tiền + nội dung = mã thanh toán ngắn) hoặc link/deeplink ví.
3. **S04.04** (VietQR): QR lớn, số tiền, nội dung chuyển khoản, đếm ngược, viền "Tạo QR mới" (khoản cũ `expired`, tạo khoản mới), chính "Mở app ngân hàng" (deeplink danh sách app ngân hàng); dòng "Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động." Ví: mở app ví, quay lại thì về S04.04 chờ kết quả.
4. Tổ chức trung gian gọi **webhook** → `handlePaymentNotification` (HTTP function, kiểm chữ ký, idempotent theo mã giao dịch của họ, lưu bản gốc) → `Payment.status = paid`, bút toán `payment_received`, booking `draft → requested/accepted`.
5. Job **đối soát** mỗi 5 phút hỏi trạng thái các khoản `created` quá 3 phút; job ngày đối chiếu sao kê của tổ chức trung gian với sổ cái (S23.02).

### 3.3 Chuyển sai (VietQR)

| Trường hợp | Xử lý tự động |
|---|---|
| Đúng số tiền, đúng nội dung, còn hạn | `paid` |
| Thừa tiền | `paid`; phần thừa hoàn về tài khoản đã chuyển (§5) |
| Thiếu tiền | giữ `created` tới hết hạn; hết hạn → hoàn toàn bộ số đã nhận |
| Chuyển sau khi hết hạn | hoàn toàn bộ số đã nhận; booking không tạo |
| Không khớp được khoản nào (sai nội dung) | `needs_review`, staff xử lý ở S23.02 |

`PaymentStatus`: `created`, `paid`, `expired`, `needs_review`, `refunded`, `partially_refunded`.

## 4. Giữ tiền và chuyển mốc

Sổ cái của app quản lý (giữ nguyên nguyên tắc §3g.1, §3g.5, thay "cọc" bằng toàn bộ tiền đã trả). Mỗi `Payment` có các `Milestone` (spec 2026-10-05 §4.2). Job `releaseMilestones` (mỗi 15 phút, chung job với spec bàn giao và Studio) ghi `escrow_released` khi đủ điều kiện:

| Mốc | Điều kiện |
|---|---|
| `shoot` | `shot` + 24 giờ khiếu nại không có khiếu nại |
| `delivery` | `approved` + 48 giờ kiểm tra không có "Báo vấn đề" (`completed`) |

Khiếu nại → mốc liên quan `disputed`, chi trả `on_hold` (§3g.2 giữ nguyên). Tổ chức trung gian phải cho giữ tiền tới khi lệnh chi được gửi (có thể 30–60 ngày, §10).

## 5. Hoàn tiền

| Phương thức gốc | Cách hoàn |
|---|---|
| Ví MoMo / ZaloPay | API hoàn của ví (toàn bộ hoặc một phần) |
| VietQR | **Chi một khoản** về tài khoản đã chuyển (số tài khoản, tên, ngân hàng lấy từ webhook). Khách xác nhận ở **S22.04 Tài khoản nhận hoàn** (sheet): "Hoàn về Vietcombank •••• 6789 · NGUYEN THANH HA"; nút chính "Hoàn về tài khoản này", liên kết "Dùng tài khoản khác" (form như S06.06, có tra tên). Thiếu thông tin người chuyển → bắt buộc khai tài khoản. |
| Thẻ (khi bật) | API hoàn của cổng; quá thời hạn hoàn của cổng → chi về tài khoản khách khai |

`Refund` thêm `method` (`gateway` \| `bank_transfer`), `destinationAccount?` (che, mã hoá), `providerRef`, `failureReason?`. Hoàn sau khi đã chi cho thợ: bút toán `adjustment` trừ vào lần chi sau (§3g.3 giữ nguyên). Chính sách hoàn giữ nguyên, tính trên toàn bộ số đã trả; lỗi của thợ/studio hoàn 100%.

## 6. Chi trả

### 6.1 Lịch và số tiền

- Job `createPayouts` chạy **mỗi ngày** (đề xuất 10:00 giờ Việt Nam): gom các khoản `released` chưa chi theo người nhận thành một `Payout`, gọi API chi hộ kèm `idempotencyKey`; webhook hoặc truy vấn trạng thái → `paid` / `failed` (thử lại tối đa 3 lần, rồi `on_hold` cho staff).
- Số tiền chi = Σ `escrow_released` − `platform_fee` (hoa hồng, mặc định 0%) − `tax_withheld` (thợ cá nhân) ± `adjustment`. Phí cổng và phí chi do nền tảng chịu: bút toán `gateway_fee`, `payout_fee` ghi vào doanh thu âm của nền tảng, không trừ vào thợ.
- **Lần chi đầu của mỗi tài khoản nhận tiền** vào hàng chờ staff (S23.02); staff duyệt rồi mới gửi. Từ lần sau tự động.
- Chưa có tài khoản nhận tiền: khoản giữ ở `released`, thông báo "Thêm tài khoản để nhận {số tiền}" (một lần, kèm banner ở S06.05).

`Payout` thêm `provider`, `providerPayoutId`, `idempotencyKey`, `amountGross`, `platformFee`, `taxWithheld`, `amountNet`, `attempts`, `firstPayout: bool`, `approvedBy?`.

### 6.2 Tài khoản nhận tiền (S06.06)

- Hỏi khi có khoản `released` đầu tiên (không hỏi trong S21.02).
- **Ngân hàng**: chọn từ danh sách VietQR (tên, tên viết tắt, logo, tìm kiếm). **Số tài khoản**: một ô nhập. **Tên chủ tài khoản**: app tự tra qua API của tổ chức trung gian, người dùng không gõ.
- Tên tra được phải **khớp họ tên đã xác minh** (bỏ dấu, không phân biệt hoa thường, chuẩn hoá khoảng trắng). Studio đã xác minh doanh nghiệp: khớp tên doanh nghiệp hoặc tên chủ. Không khớp → không lưu, báo "Tên chủ tài khoản không khớp tên đã xác minh"; ngân hàng không hỗ trợ tra tên → lưu ở `pending_review`, staff đối chiếu.
- Lưu: `bankBin`, `bankName`, `accountNumberEnc` (mã hoá), `accountLast4`, `holderName`, `nameMatched`, `verifiedAt`, `activeFrom`.
- **Đổi tài khoản**: OTP qua số điện thoại đã xác minh; tài khoản mới `activeFrom` = +72 giờ; trong 72 giờ đó tạm dừng chi; gửi thông báo và email (nếu có) về việc đổi; tài khoản mới chi lần đầu cũng qua staff duyệt.

### 6.3 Thu nhập (S06.05)

Ba ô: Đang giữ · Chờ chi trả · Đã nhận. Danh sách theo booking/sự kiện, trạng thái từng khoản (Đang giữ, Chờ chi trả, Đã chuyển, Đang khiếu nại); mở một khoản thấy: đã chuyển theo mốc, hoa hồng (khi > 0), thuế khấu trừ, thực nhận. Dòng "Chi tự động mỗi ngày · lần chi đầu do staff duyệt"; dòng "Tài khoản nhận tiền · {ngân hàng} •••• {4 số}" → S06.06.

## 7. Thuế

- Thợ cá nhân: khấu trừ trên phần chi theo Nghị định 117/2025; đề xuất 5% GTGT + 2% TNCN, tỉ lệ và ngưỡng miễn là **cấu hình** (`tax.individual`). Số định danh lấy từ xác minh (spec xác minh §3) dùng làm mã số thuế.
- Studio là doanh nghiệp/hộ kinh doanh đã xác minh: theo hướng dẫn của kế toán (mặc định không khấu trừ).
- Bút toán `tax_withheld`; báo cáo khấu trừ theo kỳ cho kế toán (xuất tệp, S23.02).

## 8. Doanh thu nền tảng

| Loại (`RevenueKind`) | Trạng thái | Thu thế nào |
|---|---|---|
| `platform_fee` (hoa hồng sàn) | có sẵn, **0%** | tỉ lệ cấu hình theo loại nhà cung cấp (`individual`, `artist`, `studio`), trừ khi chi; đổi tỉ lệ phải báo trước cho thợ (đề xuất 30 ngày) và chỉ áp cho booking tạo sau ngày hiệu lực |
| `verification_fee` | chạy ngay | 99.000đ thợ / 299.000đ studio (cấu hình), thu thẳng VietQR/ví (spec xác minh §4) |
| `subscription` | giữ chỗ | gói Pro/Studio theo tháng; chưa thiết kế |
| `promotion` | giữ chỗ | đẩy tin/nổi bật, nhãn "Được tài trợ"; chưa thiết kế |
| `event_ticket` | có (spec chính) | vé sự kiện do nền tảng tổ chức |

Mỗi khoản doanh thu xuất **hoá đơn điện tử** (nhà cung cấp hoá đơn chọn trong plan). `LedgerEntryType` sau thay đổi: `payment_received`, `ticket_received`, `refund_issued`, `escrow_released`, `payout_paid`, `platform_fee`, `tax_withheld`, `gateway_fee`, `payout_fee`, `revenue_received`, `adjustment` (thay `deposit_received`, `fee_charged`).

## 9. Cổng kỹ thuật

`packages/domain`:
- `PaymentGateway { createPayment, queryPayment, refund, verifyWebhook }`
- `PayoutGateway { lookupAccountName, createPayout, queryPayout }`
- Luật: trạng thái `Payment`, khớp tên, lịch chi, tính số tiền chi, chuyển sai.

Bản cài đặt: `Fake*Gateway` (emulator, dev, test; mô phỏng webhook và chuyển sai) và bản thật của tổ chức trung gian được chọn. Webhook là HTTP function (`onRequest`) có kiểm chữ ký; mọi lệnh gọi ra ngoài có `idempotencyKey`. Cờ `REAL_PAYMENTS` chỉ bật sau khi xong §11.

## 10. Chọn tổ chức trung gian

Ứng viên (nghiên cứu §B): 9Pay, ZaloPay, VNPay, Ngân Lượng, Bảo Kim, MoMo. Điều kiện bắt buộc khi hỏi:
1. Có dịch vụ thu hộ/chi hộ cho sàn và **giữ tiền tới khi có lệnh chi**, tối đa bao lâu (cần ≥ 60 ngày), có tính phí giữ không.
2. VietQR động + webhook có thông tin tài khoản người chuyển; MoMo và ZaloPay qua cùng đối tác hoặc tích hợp riêng.
3. API chi hộ tới mọi ngân hàng NAPAS 247, có `idempotency`, có **tra tên chủ tài khoản**.
4. **Tách phần phí của nền tảng** khi chi (cho `platform_fee`).
5. Hoàn về ví; giới hạn số ngày hoàn.
6. Sandbox, phí từng dịch vụ, thời gian ký hợp đồng.

## 11. Việc pháp lý trước khi bật tiền thật

1. Luật sư: xác nhận mô hình A1 (Nghị định 52/2024), hợp đồng ba bên (khách – thợ/studio – nền tảng), điều khoản sử dụng.
2. **Đăng ký sàn giao dịch thương mại điện tử** với Bộ Công Thương (online.gov.vn) trước khi mở cho người dùng thật.
3. Hợp đồng với tổ chức trung gian (§10).
4. Kế toán: khấu trừ thuế (Nghị định 117/2025), hoá đơn điện tử cho doanh thu nền tảng, xử lý phí cổng.
5. Hồ sơ đánh giá tác động dữ liệu cá nhân (spec xác minh §9).
6. Nếu gọi vốn nước ngoài: cấu trúc công ty và giới hạn sở hữu nước ngoài với dịch vụ sàn.

## 12. Màn hình

| Mã | Thay đổi |
|---|---|
| S04.03 | đổi tên "Đặt lịch 4/4 · Xem lại & thanh toán"; bảng tiền 100%, chọn phương thức, nút "Thanh toán {giá}" |
| S04.04 | màn VietQR / chờ ví (§3.2) |
| S06.05, S06.06 | §6.2, §6.3 |
| S22.01 | lịch sử thanh toán: bỏ chữ "cọc", thêm phương thức, hoàn tiền đang xử lý |
| **S22.04** | **Tài khoản nhận hoàn** (sheet, mới) |
| S23.02 | duyệt lần chi đầu, khoản `needs_review`, đối soát ngày, xuất báo cáo thuế |
| S23.03 | hoàn tiền thủ công (giữ) |

Mock đổi mọi chữ "cọc" sang mô hình 100%.

## 13. Kiểm thử

- Domain: máy trạng thái `Payment`; bảng chuyển sai §3.3; tính số tiền chi (hoa hồng 0% và > 0%, thuế, điều chỉnh); khớp tên (dấu, hoa thường, khoảng trắng); 72 giờ đổi tài khoản; lần chi đầu chờ duyệt; idempotency.
- Functions: webhook sai chữ ký bị từ chối; webhook lặp chỉ ghi một lần; job đối soát; `createPayouts` với `FakePayoutGateway` (thành công, thất bại, thử lại).
- Rules: client không ghi `Payment`, `Payout`, `ledger_entries`, tài khoản nhận tiền; số tài khoản chỉ đọc dạng che.
- App: S04.03, S04.04 (đếm ngược, tạo QR mới), S06.05, S06.06 (khớp, không khớp, chờ 72 giờ), S22.04.

## 14. Chia việc

1. Domain + cổng giả + Functions: `createPayment`, webhook, đối soát, chuyển sai, hoàn tiền.
2. Mốc và chi trả: `releaseMilestones`, `createPayouts`, duyệt lần chi đầu, thuế, hoa hồng cấu hình.
3. Tài khoản nhận tiền và S22.04.
4. App: S04.03, S04.04, S06.05, S06.06, S22.01; sửa chữ "cọc" toàn app.
5. Bản cài đặt thật sau khi chọn tổ chức trung gian (§10) và xong §11.
