# Nghiên cứu thanh toán, giữ tiền và chi trả (Việt Nam, 2025–2026)

Ngày nghiên cứu: 2026-10-06. Không phải tư vấn pháp lý hay thuế. Mục có **[chưa kiểm chứng]** là số liệu lấy từ nguồn thứ cấp, hoặc là suy luận chưa có văn bản/nhà cung cấp xác nhận.

Đang có trong repo: `PaymentGateway` (port) chỉ có `FakePaymentGateway`; `PAYMENT_PROVIDERS = momo | vnpay | fake`; `createDeposit` (30%) cùng `confirmFakePayment` (callable); app có `REAL_PAYMENTS=false` và `fake_payment_sheet.dart`. Chưa có webhook HTTP, chưa có code payout hay tài khoản ngân hàng; `PayoutAccount`/`Payout`/`ledger_entries` mới có trong data-model. Spec 3g.7 và câu hỏi mở 19 (pháp lý giữ tiền hộ) chưa chốt.

---

## (A) Tóm tắt khuyến nghị

**1. Chốt mô hình pháp lý trước khi chọn cổng.** Đây là điều kiện cho mọi thứ khác. Có hai hướng hợp lệ:

| | **A1. Sàn trung gian + tổ chức trung gian thanh toán (TGTT) có phép** (khuyến nghị) | **A2. Nền tảng là bên bán dịch vụ (merchant of record)** |
|---|---|---|
| Hợp đồng | Khách ký với thợ/studio; app là sàn | Khách mua dịch vụ của nền tảng; nền tảng thuê lại thợ/studio |
| Tiền nằm ở đâu khi "treo" | Trong hệ thống của tổ chức TGTT có dịch vụ **hỗ trợ thu hộ, chi hộ** (tài khoản đảm bảo thanh toán của họ); app chỉ ra lệnh chi | Trong tài khoản doanh nghiệp của nền tảng (đây là doanh thu của nền tảng) |
| Thu | Cổng của chính tổ chức đó (VietQR/thẻ/ví) | payOS/SePay/tài khoản định danh của ngân hàng (VietQR) + cổng thẻ |
| Chi trả | API chi hộ của tổ chức TGTT | API chi của payOS hoặc open API của ngân hàng |
| Thuế | Nền tảng khấu trừ và nộp thay theo NĐ 117/2025 (dịch vụ: GTGT 5%, TNCN 2%) | Nền tảng xuất hoá đơn **toàn bộ giá** và chịu GTGT; khi trả cho cá nhân phải khấu trừ TNCN theo quy định về thu nhập vãng lai **[chưa kiểm chứng: 10% với khoản ≥ 2 triệu, TT 111/2013]**; studio xuất hoá đơn cho nền tảng |
| Rủi ro | Phụ thuộc hợp đồng "giữ tiền chậm" của tổ chức TGTT | Nền tảng chịu trách nhiệm dịch vụ trước khách; gánh thuế nặng hơn |

**Không nên** để tiền khách về tài khoản doanh nghiệp của nền tảng rồi chuyển cho thợ trong khi vẫn tự nhận là "sàn giữ tiền hộ". Cách làm này rất có thể bị coi là cung ứng dịch vụ TGTT không phép (NĐ 52/2024, Điều 8 khoản 7). Luật sư phải xác nhận điểm này.

**2. Thu tiền.** Khách trả 100% giá trước, mỗi đơn khoảng 1–10 triệu đ. Ở mức này phí 1–3% của thẻ là đáng kể, nên **VietQR động (NAPAS 247) đặt làm mặc định**: phí cố định hoặc rất thấp, tiền về tức thì, đối soát qua webhook. Thẻ nội địa và thẻ quốc tế là lựa chọn thứ hai (khách nước ngoài, khách muốn trả bằng thẻ tín dụng). Ví MoMo/ZaloPay là tuỳ chọn. Theo A1, chọn một tổ chức TGTT có cả cổng (VietQR, thẻ) lẫn chi hộ, ví dụ 9Pay, ZaloPay, VNPay, Ngân Lượng, Bảo Kim hoặc MoMo, và hỏi rõ có giữ tiền chậm được không. Theo A2: payOS để thu VietQR và chi, VNPay hoặc OnePay để thu thẻ.

**3. Escrow và các mốc nằm trong sổ cái của app, không nằm ở cổng.** Không cổng nào trong số đã xem có sản phẩm "escrow theo mốc" công khai; cổng chỉ làm thu (pay-in), hoàn (refund) và chi (payout). Các trạng thái `held → released → paid_out`, mốc `shoot`/`delivery` và cửa sổ khiếu nại vẫn do `packages/domain` cùng `ledger_entries` quản lý như spec 3g. Cổng chỉ cần thực hiện:
- `createPayment` tạo yêu cầu thanh toán (QR hoặc link) có hạn dùng, mã đơn duy nhất (`orderCode`/`vnp_TxnRef` = `payment.id`).
- Webhook/IPN báo đã trả → `handlePaymentNotification`, xử lý idempotent theo mã giao dịch của cổng.
- Cron `releaseMilestones` chỉ ghi bút toán `escrow_released`. Cron `createPayouts` gom các khoản `released` theo người nhận (mỗi ngày, hoặc khi đạt ngưỡng) rồi gọi API chi hộ có `idempotency-key`, chờ webhook hoặc truy vấn trạng thái → `payout_paid`.

**4. Hoàn tiền.**
- Thẻ/ví: gọi API refund của cổng. VNPay có hoàn một phần (loại 03) và hoàn toàn bộ (loại 02); ZaloPay nhận `amount` và xử lý bất đồng bộ. Cổng thường giới hạn số ngày được hoàn kể từ giao dịch gốc **[chưa kiểm chứng; phải hỏi]**. Thời gian giữ tiền có thể dài (bàn giao, chỉnh sửa, khiếu nại), nên cần biết giới hạn này; quá hạn thì hoàn bằng chuyển khoản.
- VietQR/chuyển khoản: **không có "đảo giao dịch"**. Hoàn tiền là một lệnh chi hộ về tài khoản của khách. Lấy `counterAccountNumber/Name/BankId` từ webhook (payOS có trả các trường này), hiển thị che bớt để khách xác nhận; thiếu thông tin thì khách khai tài khoản nhận hoàn (dùng lại form của S06.06, tra tên bắt buộc).
- Hoàn sau khi đã chi cho thợ: giữ quy tắc bút toán `adjustment` trừ vào lần chi sau (spec 3g.3).

**5. Những gì phải sửa trong spec, data-model và code**
- `PaymentProvider` tách làm hai: `provider` (`payos`, `vnpay`, `zalopay`, `ninepay`…) và `PaymentMethod` (`bank_qr`, `domestic_card`, `intl_card`, `ewallet`). Bỏ giả định "MoMo/VNPay" ở S04.03; mặc định là "Chuyển khoản QR".
- `PaymentStatus` thêm `expired` (QR hết hạn) và `needs_review` (chuyển thiếu, thừa, sai nội dung, chuyển sau khi hết hạn). Spec phải ghi cách xử lý tiền khách tự chuyển sai số tiền: hoàn qua chi hộ hoặc nhân viên xử lý.
- Webhook là **HTTP function** (`onRequest`), không phải callable. Phải kiểm chữ ký (payOS HMAC‑SHA256 với checksum key; VNPay HMAC‑SHA512 `vnp_SecureHash`), trả đúng mã ACK (VNPay `RspCode 00/02` để dừng gửi lại), lưu `raw`. Thêm cron đối soát truy vấn trạng thái các khoản `created` quá X phút.
- `Refund` thêm `method` (`gateway` | `bank_transfer`), `destinationAccount?` (che, mã hoá), `providerRef`, `failureReason`.
- `LedgerEntryType` thêm `gateway_fee`, `payout_fee`, `tax_withheld` (NĐ 117, nếu theo A1). Số tiền chi = đã thả − thuế khấu trừ − phí; S06.05 phải hiện được cả ba con số.
- `Payout` thêm `provider`, `providerPayoutId`, `idempotencyKey`, `fee`, `taxWithheld`, `attempts`. `PayoutAccount` mở rộng theo mục D.
- `releaseEscrow`/`executePayout` (spec 3g, bảng callable) đổi thành `releaseMilestones` + `createPayouts` (cron) + `approvePayoutBatch` (staff, giai đoạn đầu).
- Ghi chú điều khoản (P1–P9): thêm "tiền được giữ bởi {tổ chức TGTT}" nếu theo A1, thời gian hoàn tiền theo từng phương thức, và việc khấu trừ thuế.

---

## (B) Bảng so sánh nhà cung cấp

| Nhà cung cấp | Loại / giấy phép | Thu | Phí (tham khảo) | Tiền về | Hoàn tiền | Chi hộ / payout | Tra tên TK | Webhook | Sandbox | Onboarding |
|---|---|---|---|---|---|---|---|---|---|---|
| **payOS** (Casso) | Hạ tầng kết nối open banking, tiền về thẳng TK của merchant; **không thấy nêu giấy phép TGTT** | VietQR động | Trang chủ: gói BIDV‑1K miễn phí 1.000 GD/năm; "tiết kiệm 99%"; bảng giá đầy đủ **[chưa kiểm chứng, trang 404]** | Tức thì, vào TK ngân hàng liên kết (MB, OCB, KienlongBank, ACB, BIDV; DN thêm Shinhan) | Không thấy API refund; hoàn = chi | `POST /v1/payouts`, `/v1/payouts/batch`, `x-idempotency-key`, ước tính phí `/estimate-credit`, số dư TK chi | `validateDestination` khi chi theo lô | Có; HMAC‑SHA256; trả `counterAccount*` | Có | Cá nhân: CCCD + eKYC; DN: ĐKKD |
| **SePay** | Đọc biến động số dư TK của merchant (không giữ tiền) | VietQR; QR NAPAS; thẻ quốc tế | Gói Free 50 GD/tháng, Startup 120.000đ/180 GD; blog SePay (3/2026): VietQR 200–500đ/GD, QR NAPAS 0,3%, thẻ QT 2.200đ + 1,6–2,2% | Tức thì (11 ngân hàng) | Không (tự chuyển) | Không thấy | Không thấy | HMAC/API key/OAuth2, thử lại 7 lần (~33 phút) | Có | Đơn giản |
| **Open API ngân hàng** (BIDV, VietinBank, OCB, MB…) | Ngân hàng | Tài khoản định danh (VA) + VietQR, đối soát tự động | Theo hợp đồng **[chưa kiểm chứng]** | Tức thì | Chuyển khoản | Chuyển nội bộ/liên ngân hàng (OCB: CITAD, chuyển nhanh) | OCB "Get recipient name Napas" | Có (VA) | Có (dev portal) | Doanh nghiệp, ký hợp đồng |
| **VNPay** | TGTT có phép | VNPAYQR, ATM nội địa (`VNBANK`), thẻ QT (`INTCARD`); có tài liệu token | Thứ cấp: nội địa 1–1,8%, QT cao hơn **[chưa kiểm chứng]** | T+1 tới T+3 (thứ cấp) | API refund: 02 toàn bộ, 03 một phần | Không thấy sản phẩm chi hộ công khai | — | IPN, HMAC‑SHA512, gửi lại tối đa 10 lần, mỗi 5 phút | Có | DN, hợp đồng |
| **OnePay** | TGTT có phép | Thẻ nội địa/QT; Apple Pay/Google Pay **[chưa kiểm chứng]** | Thứ cấp: 1,8–3,5% **[chưa kiểm chứng]** | **[chưa kiểm chứng]** | Có **[chưa kiểm chứng]** | **[chưa kiểm chứng]** | — | Có | Có | DN |
| **MoMo Business** | TGTT có phép (ví) | Ví, thẻ, QR | Thứ cấp: 0,5–2%; MoMo báo bỏ phí thu từ 20/9/2023 với đối tác **[chưa rõ phạm vi]** | T+1 tới T+7 (thứ cấp) | Có; nguồn tiền thay thế thì hoàn về ví | **[chưa kiểm chứng]** | — | IPN | Có | DN |
| **ZaloPay** | TGTT có phép (ví) | Ví, thẻ, QR | Thứ cấp: 1–1,5% | T+1 tới T+3 (thứ cấp) | Refund API bất đồng bộ, có `amount` | **All‑in‑One Disbursement**: từ Business Wallet tới TK ngân hàng, thẻ ATM, ví | **Verify Account API** (trả tên chủ TK) | Có | Có | DN, `app_id`/khoá |
| **9Pay** | TGTT có phép số 60/GP‑NHNN (ví, cổng, thu chi hộ) | Chuyển khoản, VietQR, thẻ | MDR theo phương thức; phí settlement ghi bằng USD (có vẻ cho khách nước ngoài) **[chưa kiểm chứng]** | Theo hợp đồng | **[chưa kiểm chứng]** | Thu hộ, chi hộ qua API hoặc lô Excel, 24/7; nêu sàn TMĐT là khách hàng mục tiêu | **[chưa kiểm chứng]** | Có | **[chưa kiểm chứng]** | DN |
| **Stripe** | — | — | — | **Không hỗ trợ pháp nhân Việt Nam** | — | — | — | — | — | — |

Phí của các cổng truyền thống hầu như không công bố, phải xin báo giá. Các con số "thứ cấp" lấy từ blog so sánh (SePay 3/2026, JAYbranding 2026), không phải biểu phí chính thức.

---

## (C) Pháp lý

- **NĐ 52/2024/NĐ‑CP** (thanh toán không dùng tiền mặt, hiệu lực 1/7/2024; thay NĐ 101/2012). Điều 3 khoản 17 định nghĩa *dịch vụ hỗ trợ thu hộ, chi hộ* là tiếp nhận, xử lý dữ liệu điện tử, tính kết quả thu hộ, chi hộ "…và thực hiện thanh toán cho các bên có liên quan". Khoản 18 định nghĩa *cổng thanh toán điện tử*. Điều 8 khoản 7 cấm "cung ứng dịch vụ trung gian thanh toán khi chưa được Ngân hàng Nhà nước cấp Giấy phép". Tổ chức ví điện tử phải giữ tổng số dư trên **tài khoản đảm bảo thanh toán** không thấp hơn tổng số dư ví (Điều 6 khoản 3). Vốn tối thiểu 50 tỷ đ cho ví, cổng và thu hộ chi hộ; 300 tỷ đ cho chuyển mạch và bù trừ. Kèm **TT 40/2024/TT‑NHNN** về hoạt động TGTT.
- **Hệ quả**: một startup không thể tự xin phép (50 tỷ đ). Hoặc dùng mô hình A1 (tổ chức có phép giữ tiền và chi theo lệnh), hoặc dùng A2 (nền tảng tự bán dịch vụ, tiền là doanh thu của mình). Phải hỏi luật sư liệu A2 có còn bị coi là "chi hộ" khi chi tiết từng khoản trùng khớp với từng thợ hay không.
- **Luật Thương mại điện tử 122/2025/QH15** (hiệu lực **1/7/2026**). Điều 14.2.b: người bán trên nền tảng trung gian "chỉ sử dụng tài khoản thanh toán của mình". Vì vậy tài khoản nhận tiền phải đứng tên chính thợ/studio. Luật cũng yêu cầu xác thực danh tính người bán, công khai quy chế và giải quyết khiếu nại. Tác động chi tiết lên việc nền tảng giữ tiền: **[chưa kiểm chứng, cần đọc văn bản và nghị định hướng dẫn]**.
- **TT 17/2024/TT‑NHNN**: từ 1/1/2025, tài khoản chỉ giao dịch điện tử được khi đã đối chiếu sinh trắc học với CCCD gắn chip (tài khoản tổ chức: người đại diện hợp pháp). Như vậy tài khoản nhận tiền đang hoạt động đã gắn danh tính thật, và tên chủ tài khoản là căn cứ tốt để so với CCCD.
- **Thuế (NĐ 117/2025/NĐ‑CP**, hiệu lực 1/7/2025). Sàn TMĐT hoặc nền tảng số **có chức năng thanh toán** phải khấu trừ và nộp thay cho hộ, cá nhân bán hàng ngay khi giao dịch thành công. Với dịch vụ: GTGT 5%, TNCN 2% (người cư trú). Từ 2026 ngưỡng doanh thu không chịu thuế của hộ, cá nhân là **500 triệu đ/năm**; theo báo chí, sàn vẫn khấu trừ và người dưới ngưỡng được hoàn **[cần kế toán xác nhận cơ chế hoàn và cách xử lý giao dịch bị huỷ/hoàn]**. Studio là doanh nghiệp thì không khấu trừ; studio tự xuất hoá đơn điện tử. Nền tảng phải xuất hoá đơn điện tử cho phí/hoa hồng của mình (NĐ 123/2020, sửa bởi NĐ 70/2025) **[chưa kiểm chứng chi tiết]**.

---

## (D) Tài khoản nhận tiền (S06.06)

**Trường dữ liệu** (`PayoutAccount` 🔒):
`id`, `userId`, `ownerKind` (`individual` | `business`), `bankBin` (6 số NAPAS, ví dụ 970436), `bankCode` (VCB), `bankShortName` (snapshot), `accountNumberEnc`, `accountLast4`, `holderName` (IN HOA, không dấu, đúng như ngân hàng trả về), `holderNameSource` (`lookup` | `manual`), `nameMatch` (`exact` | `fuzzy` | `mismatch` | `unchecked`), `verifiedAt?`, `businessTaxCode?`, `status` (`pending_verification`, `cooling_down`, `active`, `disabled`), `activeFrom` (hết thời gian chờ), `createdAt`, `deactivatedAt?`. Không cần chi nhánh vì NAPAS 247 không dùng; chỉ CITAD mới cần.

**Danh sách ngân hàng**: `GET https://api.vietqr.io/v2/banks` (65 ngân hàng, đã kiểm). Mỗi mục có `bin`, `code`, `shortName`, `logo`, `transferSupported`, `lookupSupported`, `swift_code`. Lưu bản sao trong app hoặc trên server, cập nhật định kỳ; chỉ cho chọn ngân hàng có `transferSupported = 1`.

**Kiểm tra**
1. Số tài khoản chỉ gồm chữ số, dài 6–19 **[độ dài chưa kiểm chứng; tuỳ ngân hàng]**.
2. Tra tên qua NAPAS: API chi hộ của nhà cung cấp (ZaloPay Verify Account, payOS `validateDestination`, OCB "Get recipient name Napas"; VietQR.io có API tra cứu trả phí **[chưa kiểm chứng endpoint]**). Tra được thì tự điền `holderName` và khoá ô.
3. So tên: chuẩn hoá tên trên CCCD (S21 xác minh) thành IN HOA, bỏ dấu, gộp khoảng trắng, rồi so với tên trả về. Khớp thì cho kích hoạt. Lệch (ví dụ đảo thứ tự tên, tên đệm) thì staff duyệt. Studio: tên công ty hoặc hộ kinh doanh phải khớp ĐKKD/MST; tài khoản cá nhân của chủ studio chỉ được nhận nếu studio đăng ký là cá nhân hay hộ kinh doanh.
4. Tuỳ chọn: chuyển thử 1.000đ có mã để xác minh khi không tra được tên.

**Đổi tài khoản an toàn**
- Đăng nhập lại hoặc OTP SĐT trước khi thêm hay đổi.
- Thời gian chờ đề xuất **72 giờ** (`cooling_down`): các lô chi trả trong thời gian này vẫn dùng tài khoản cũ hoặc tạm giữ.
- Báo qua push, email và hộp thư tới kênh cũ, kèm nút "Không phải tôi", bấm vào thì khoá chi trả và mở ticket.
- Một tài khoản `active` mỗi người (index hiện có). Ghi nhật ký `audit_log` mọi thay đổi.
- Chi trả thất bại (tài khoản đóng hoặc sai) → `Payout.failed`, tiền trở lại `released`, nhắc khai lại.

---

## (E) Rủi ro và câu hỏi mở cho chủ sản phẩm

1. **Chọn A1 hay A2** (câu hỏi mở 19): phải có ý kiến luật sư trước khi bật `REAL_PAYMENTS`.
2. Theo A1, tổ chức TGTT có cho **giữ tiền tới N ngày** không (thời gian chờ chụp + `deliveryDays` + sửa + 3 ngày tự duyệt + 48 giờ có thể quá 30–60 ngày)? Có trần thời gian giữ không? Có tính phí giữ không?
3. **Giới hạn hoàn tiền thẻ** theo số ngày và chargeback (Visa/Mastercard thường cho tới khoảng 120 ngày **[chưa kiểm chứng]**): ai chịu khi tiền đã chi cho thợ?
4. Phí cổng (1–3% với thẻ) do ai chịu: khách (phụ phí), thợ, hay nền tảng? Ảnh hưởng tới câu hỏi mở 6 về hoa hồng.
5. Khách chuyển khoản sai số tiền hay sai nội dung, hoặc chuyển sau khi QR hết hạn: hoàn tự động hay để staff xử lý?
6. Ngưỡng và lịch chi trả (mỗi ngày? tối thiểu bao nhiêu?), phí chi hộ do ai chịu.
7. Theo NĐ 117: hiện khấu trừ thuế cho thợ cá nhân thế nào trên S06.05; app có thành "nền tảng có chức năng thanh toán" ngay cả khi theo A2 không?
8. Studio chưa có pháp nhân (nhóm cá nhân): có cho nhận vào tài khoản cá nhân của trưởng nhóm không?
9. Rủi ro gian lận: thợ tự đặt lịch rồi tự chi trả để rửa tiền hoặc lấy khuyến mãi. Cần hạn mức theo KYC, giữ khoản đầu tiên lâu hơn và theo dõi các cặp khách–thợ lặp lại.
10. Sự kiện có vé (`platform` host là doanh thu): theo A1 phải tách dòng tiền doanh thu riêng của nền tảng.

---

## (F) Nguồn (truy cập 2026-10-06)

- payOS trang chủ: https://payos.vn/
- payOS "3 phút hiểu rõ": https://payos.vn/3-phut-hieu-ro-ve-payos/
- payOS API (payment-requests, payouts, webhook): https://payos.vn/docs/api/
- payOS kênh chi: https://payos.vn/chi-ho/
- SePay webhooks: https://developer.sepay.vn/en/sepay-webhooks
- SePay bảng giá: https://sepay.vn/bang-gia.html
- SePay blog so sánh cổng (11/3/2026): https://sepay.vn/blog/cong-thanh-toan-la-gi/
- JAYbranding so sánh cổng 2026: https://jaybranding.com/so-sanh-cac-cong-thanh-toan-2026-momo-vnpay-zalopay-vietqr-ai-la-vua/
- VNPay tạo thanh toán / IPN: https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html
- VNPay truy vấn và hoàn tiền: https://sandbox.vnpayment.vn/apis/docs/truy-van-hoan-tien/querydr&refund.html
- ZaloPay disbursement: https://docs.zalopay.vn/docs/guides/business-operation/disbursement-all-in-one/intro/
- ZaloPay refund: https://docs.zalopay.vn/docs/specs/order-refund
- MoMo chính sách phí đối tác: https://www.momo.vn/tin-tuc/thong-bao/quan-trong-cap-nhat-cac-chinh-sach-phi-va-quyen-4904
- 9Pay thu hộ – chi hộ: https://9pay.vn/en/collection-disbursement
- VietQR danh sách ngân hàng: https://api.vietqr.io/v2/banks ; tạo QR: https://github.com/vietqr-io/vietqr-api
- OCB open API (tra tên NAPAS): https://developer.api.ocb.com.vn/corporate/en/product/5053
- BIDV tài khoản định danh: https://openapi.bidv.com.vn/devportal/en/product/5952
- NAPAS FastFund 247: https://en.napas.com.vn/napas-fastfund-247-service
- NĐ 52/2024 (văn bản): https://caselaw.vn/van-ban-phap-luat/411601-nghi-dinh-so-52-2024-nd-cp-ngay-15-05-2024-cua-chinh-phu-quy-dinh-ve-thanh-toan-khong-dung-tien-mat
- Tilleke & Gibbins về NĐ 52: https://www.tilleke.com/insights/vietnams-new-decree-on-non-cash-payments/15/
- Vốn tối thiểu TGTT: https://ketoananpha.vn/thu-tuc-xin-cap-giay-phep-trung-gian-thanh-toan.html
- TT 17/2024 sinh trắc học: https://vietnamfinance.vn/tu-2025-tai-khoan-chua-xac-thuc-se-khong-duoc-chuyen-tien-online-d115474.html
- Luật TMĐT 122/2025 (Điều 14): https://dblegal.vn/vi/q-a/doanh-nghiep-j84xzrb2fg/diem-moi-luat-thuong-mai-dien-tu-2025-nen-tang-thuong-mai-dien-tu-1484.html
- NĐ 117/2025 (thuế TMĐT): https://www.meinvoice.vn/tin-tuc/35149/nghi-dinh-117-2025-nd-cp-ve-thue-thuong-mai-dien-tu/
- Thuế hộ, cá nhân kinh doanh 2026: https://dantri.com.vn/kinh-doanh/huong-dan-ke-khai-va-nop-thue-cho-ho-ca-nhan-kinh-doanh-tu-nam-2026-20260221122045043.htm
- Stripe không hỗ trợ Việt Nam: https://support.stripe.com/questions/stripe-feature-availability-by-country

Không truy cập được (404/403): bảng giá payOS, toàn văn NĐ 52 trên thuvienphapluat, trang tra cứu API của vietqr.io. Chưa đọc trực tiếp biểu phí chính thức của VNPay, OnePay, MoMo, ZaloPay hay 9Pay.
