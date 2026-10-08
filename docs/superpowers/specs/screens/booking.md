# Đặt lịch, thanh toán, hội thoại, liên hệ

Màn: S04.01, S04.02, S04.03, S04.04, S05.02, S05.03, S07.01, S05.01, S05.04, S04.05. Quy ước chung ở [README.md](README.md). Máy trạng thái booking ở spec gốc mục 6–8; thanh toán 100% và chuyển sai ở [spec thanh toán](../2026-10-06-payments-payouts-design.md) mục 3.

---

## S04.01–S04.03 · Đặt lịch (sheet 4 bước)

Ba màn mock của một luồng `BookingSheetController` (`/u/:uid/book`), bước `service` → `datetime` → `place` → `review`. Dùng chung `AppBottomSheet` và `StepProgress` "n / 4".

### Quy tắc chung của luồng

- **Thông tin**: khách · sub‑project 4 · Đã làm (S04.03: thanh toán 100%, #129).
- **Điều kiện vào**: khách đăng nhập và **có số điện thoại hợp lệ**. Thiếu thì mở S04.05 trước, lưu xong quay lại đúng bước (`returnTo`). Vào từ S02.02 ("Đặt gói này") thì bỏ bước 1; vào từ S02.06 ("Đặt T7") thì có sẵn ngày và dịch vụ.
- **Trạng thái luồng** giữ trong controller: `serviceId`, `date`, `start`, `end`, `place`, `note`, `phone`, `method` (mặc định `bank_qr`). Quay lại không mất lựa chọn. Đóng sheet khi đã chọn gì đó hỏi xác nhận "Bỏ yêu cầu đặt lịch?". Không lưu nháp lên server cho tới khi tạo `draft` ở bước 4.
- **Tiền**: tổng giá gói luôn nằm trên nút chính; khách trả 100% khi đặt, tiền được giữ và chuyển cho thợ theo 2 mốc.

### S04.01 · Bước 1 · Chọn gói

- **Mục đích**: chọn gói dịch vụ bằng hình, không phải dòng chữ.
- **Bố cục**: hàng nhiếp ảnh gia (avatar nhỏ, "Đặt với {tên}", "1 / 4"); tiêu đề "Chọn gói"; danh sách thẻ gói chọn đơn (thumb 48, tên, mô tả ngắn, giá); nút "Tiếp tục · {giá}".
- **Dữ liệu**: `servicesProvider(uid)` (chỉ `active`), sắp theo giá.
- **Trạng thái**: một gói duy nhất → chọn sẵn; không có gói → "Nhiếp ảnh gia chưa đăng gói" và đóng sheet; gói đổi giá trong lúc đặt → báo "Giá gói đã đổi" và cập nhật tổng.
- **Chuỗi**: `s05_title` "Chọn gói", `s05_with` "Đặt với {name}", `s05_continue` "Tiếp tục · {price}".
- **Chấp nhận**: chọn gói bật nút; tổng khớp giá gói.

### S04.02 · Bước 2 · Ngày và giờ

- **Bố cục**: dòng gói + "2 / 4"; tiêu đề tháng + chú giải (Rảnh · Đã đặt gạch · Chờ viền đứt); `AvailabilityCalendar` (ngày chọn tô gradient, không chọn được ngày đã đặt/nghỉ/quá khứ, ngày "Chờ" xem được nhưng không chọn, kèm "1 người đang chờ"); dòng "T7, 12/10 · khung 2 giờ"; hàng chip giờ (mốc 30 phút từ 06:00 đến 20:00 trừ `durationMinutes`; giờ gợi ý của nhiếp ảnh gia xếp đầu và gắn "gợi ý"); dòng kết thúc "15:30–17:30"; nút "Tiếp tục".
- **Dữ liệu**: `availabilityProvider(uid, month)`; chuyển tháng tải tháng mới; giờ sinh cục bộ từ gói.
- **Trạng thái**: chưa chọn ngày → nút vô hiệu; hết giờ trống trong ngày → "Hôm đó đã hết giờ", chọn ngày khác; lỗi tải lịch → thử lại.
- **Chuỗi**: `s06_legendFree` "Rảnh", `s06_legendBooked` "Đã đặt", `s06_legendPending` "Chờ", `s06_waiting` "{n} người đang chờ", `s06_endsAt` "{start}–{end}".
- **Chấp nhận**: ngày và giờ chọn không đổi khi quay lại; ngày chọn từ S02.06 được chọn sẵn.

### Bước 3 · Địa điểm (cùng layout S04.01)

- Bản đồ nhỏ + ô địa chỉ + chip gợi ý của nhiếp ảnh gia và địa điểm trong bộ lọc; mặc định theo bộ lọc hoặc gợi ý. Địa điểm tuỳ chọn tự do cần tên (≥ 3 ký tự). Nút "Tiếp tục".

### S04.03 · Bước 4 · Xem lại và thanh toán

- **Mục đích**: ai · gì · khi nào · ở đâu · bao nhiêu trên một màn, rồi trả **100%** giá gói (không còn cọc).
- **Bố cục** (theo mock): `BookingCard` tóm tắt (thumb, gói, ngày giờ, địa điểm); hàng **Ghi chú** + **SĐT của bạn** cùng chiều cao (SĐT lấy từ hồ sơ, sửa được, `PhoneField`); `MoneyBreakdown` đúng **hai hàng**: "Gói {tên}" (giá gói) và "Thanh toán 100%" (đậm, bằng giá gói); **một** dòng chữ phụ "Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả." (không còn `EscrowNotice` riêng và không còn khối chính sách huỷ 3 dòng); `PayMethodSelector` (radio, nhãn nhóm "Phương thức thanh toán"): hàng đầy chiều rộng "Chuyển khoản QR" (biểu tượng `qr_code_2`, phụ đề "Miễn phí · xác nhận ngay", **chọn sẵn**), hàng dưới chia đôi "MoMo" và "ZaloPay"; nút chính "Thanh toán {số tiền}".
- **Dữ liệu**: tạo booking `draft` rồi gọi `createPayment({bookingId, method})` (`method` ∈ `bank_qr`, `momo`, `zalopay`; trả về `checkout`, bản sao nằm ở `bookings/{id}.checkout`); trước khi gọi kiểm tra lại `availability`. Số tiền thanh toán = `Booking.deposit` (giữ tên trường, nay là toàn bộ giá; `remaining` luôn 0, xem `domain-model.md` mục 3.2).
- **Trạng thái**: đang gọi → nút loading và vô hiệu mọi điều khiển (kể cả radio); lỗi `day_taken` → quay S04.02 với ngày đó gạch và báo "Hôm đó vừa có người đặt"; lỗi `phone_required` → S04.05; lỗi `payment_attempts_exceeded` (khoản thứ 4 của một booking) → "Đã tạo QR 3 lần. Hãy đặt lại từ đầu."; lỗi mạng → giữ nguyên, "Không gửi được. Kiểm tra mạng rồi thử lại."; thanh toán chưa mở trên máy chủ → "Thanh toán chưa mở trên máy chủ này."; thành công → sang S04.04 (không mở cổng ngoài ở bước này).
- **Tương tác**: ghi chú tối đa 300 ký tự có đếm; SĐT kiểm tra định dạng khi rời ô; chọn phương thức không gọi máy chủ, chỉ đổi `method` gửi đi.
- **Chuỗi** (khoá `app_vi.arb`): `bookReview` "Xem lại", `bookNote` "Ghi chú", `bookYourPhone` "SĐT của bạn", `bookPackageLine` "Gói {name}", `bookDepositToday` "Thanh toán 100%", `bookPolicy` "Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả.", `payMethodLabel` "Phương thức thanh toán", `payMethodBankQr` "Chuyển khoản QR", `payMethodBankQrNote` "Miễn phí · xác nhận ngay", `payMethodMomo` "MoMo", `payMethodZaloPay` "ZaloPay", `bookPay` "Thanh toán {amount}", `payAttemptsExceeded` "Đã tạo QR 3 lần. Hãy đặt lại từ đầu.", `bookPaymentsOff` "Thanh toán chưa mở trên máy chủ này.", `bookNetworkError` "Không gửi được. Kiểm tra mạng rồi thử lại.". Tên khoá `bookDepositToday` giữ lại cho đỡ đổi hàng loạt, giá trị đã bỏ chữ "cọc".
- **Phân tích**: `book_step{n}`, `book_submit{method}`, `book_error{code}`.
- **Chấp nhận**: không gọi `createPayment` khi SĐT sai hoặc thiếu; client không tin kết quả redirect, chỉ tin `bookings.status`; hai hàng tiền cộng đúng giá gói (số đồng, không làm tròn); không còn chữ "cọc" trên màn.

---

## S04.04 · Chờ thanh toán (VietQR / ví)

- **Thông tin**: `/b/:id/pay` · khách · sub‑project 4 · Đã làm (#129).
- **Mục đích**: trả một khoản đang `created` của booking `draft`: chuyển khoản VietQR có đếm ngược, hoặc chờ ví (MoMo, ZaloPay) báo về. Màn không bao giờ tin redirect; chỉ `bookings.status` (và `checkout`) làm màn chuyển.
- **Điểm vào → ra**: từ S04.03 sau `createPayment`; link `/b/{id}/pay` (booking `draft` cũ chưa có `checkout` thì màn gọi `createPayment` một lần với `bank_qr`). Booking rời `draft` (đã `requested`) → tự chuyển S05.02 (`?paid=1` hiện toast); booking biến mất (`draft` bị dọn) → trạng thái trống "Yêu cầu đã hết hạn" với "Đặt lại" (về S04.01 của đúng nhiếp ảnh gia và gói) hoặc "Về trang chủ".
- **Bố cục, chuyển khoản QR** (`QrCheckoutView`, toàn màn, thanh trên "Chuyển khoản QR"): khối QR (thẻ trắng bo góc, giữ nền sáng ở chế độ tối để máy quét đọc được); số tiền lớn; dòng "{tên} · {gói}" kèm badge "Chờ thanh toán"; `CountdownPill` "Còn mm:ss"; khung 3 hàng khoá/giá trị: "Ngân hàng" → tên ngân hàng (chú thích "Tài khoản thu hộ của trung gian thanh toán"), "Số tài khoản" → số đã che, "Nội dung" → `PB XXXXXX` kèm chip "Sao chép" (nút sao chép duy nhất); dòng chữ phụ "Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động."; chân: viền "Tạo QR mới" (≈38% chiều rộng) và chính "Mở app ngân hàng" (≈62%; mở `checkout.bankAppsUrl` qua `externalLauncherProvider`, **ẩn** khi `bankAppsUrl` rỗng, lúc đó "Tạo QR mới" chiếm cả hàng).
- **Bố cục, ví** (`WalletWaitingView`, thanh trên "Thanh toán"): `SignatureLoader` sóng rung ("vibration", đang chờ bên khác), "Đang chờ xác nhận", số tiền, dòng "{tên} · {gói}" kèm badge "Chờ thanh toán"; chân: viền "Kiểm tra lại" (gọi `checkPayment`) và chính "Mở lại {MoMo|ZaloPay}" (mở `checkout.payUrl`, ẩn khi rỗng). Không có "Đổi cổng thanh toán".
- **Dữ liệu**: lắng nghe `bookings/{id}` (có `checkout`: `paymentId`, `method`, `amount`, `expiresAt`, `transferCode`, `attempt`, `qrPayload?`, `bankName?`, `accountMasked?`, `payUrl?`, `bankAppsUrl?`); đếm ngược theo đồng hồ chèn vào (`clockProvider`) nên chạm 0 ngay cả khi chưa job nào chạy. "Tạo QR mới" gọi lại `createPayment` cùng phương thức: khoản cũ thành `expired` (đã nhận gì thì hoàn), khoản mới có 15 phút; luồng booking mang về `checkout` mới.
- **Trạng thái**:
  - Hết giờ (đếm ngược 0): QR mờ kèm "QR đã hết hạn", pill đổi "Hết hạn", chip "Sao chép" ẩn, chân chỉ còn **một** nút chính "Tạo QR mới".
  - "Tạo QR mới" đang chạy → loading và vô hiệu; quá 3 khoản → "Đã tạo QR 3 lần. Hãy đặt lại từ đầu."; lỗi khác → "Yêu cầu đã hết hạn, thử lại nhé.".
  - "Kiểm tra lại" mà chưa có tiền → "Chưa nhận được xác nhận, thử lại sau ít phút"; lỗi mạng → "Không gửi được. Kiểm tra mạng rồi thử lại.".
  - Bản thử (`REAL_PAYMENTS` tắt): nút chữ nhỏ "Giả lập chuyển khoản" mở sheet "Giả lập chuyển khoản (thử nghiệm)" với bốn nút "Chuyển đúng", "Chuyển thiếu", "Chuyển thừa", "Sai nội dung" (mỗi nút gọi `confirmFakePayment({paymentId, kind})`); bản thật không vẽ gì.
  - Thiếu/thừa/sai nội dung xử lý ở máy chủ theo spec thanh toán mục 3.3; màn chỉ nhìn `bookings`.
- **Chuỗi** (khoá `app_vi.arb`): `payQrTitle` "Chuyển khoản QR", `payTitle` "Thanh toán", `payQrCountdown` "Còn {time}", `payQrCountdownSemantics` "QR còn hiệu lực {minutes} phút {seconds} giây", `payQrExpiredPill` "Hết hạn", `payQrExpired` "QR đã hết hạn", `payQrBank` "Ngân hàng", `payQrBankNote` "Tài khoản thu hộ của trung gian thanh toán", `payQrAccount` "Số tài khoản", `payQrContent` "Nội dung", `payQrCopy` "Sao chép", `payQrCopied` "Đã sao chép nội dung chuyển khoản", `payQrHint` "Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động.", `payQrNew` "Tạo QR mới", `payQrOpenBank` "Mở app ngân hàng", `payQrSemantics` "Mã VietQR {amount}, nội dung {code}", `payQrWho` "{name} · {service}", `payAwaitingDeposit` "Chờ thanh toán", `payWalletWaiting` "Đang chờ xác nhận", `payWalletReopen` "Mở lại {name}", `payCheckAgain` "Kiểm tra lại", `payNotYet` "Chưa nhận được xác nhận, thử lại sau ít phút", `payExpiredTitle` "Yêu cầu đã hết hạn", `payExpiredBody` "Chưa nhận được thanh toán nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.", `payBookAgain` "Đặt lại", `payGoHome` "Về trang chủ", `fakeTransferOpen` "Giả lập chuyển khoản", `fakeTransferTitle` "Giả lập chuyển khoản (thử nghiệm)", `fakeTransferExact` "Chuyển đúng", `fakeTransferUnder` "Chuyển thiếu", `fakeTransferOver` "Chuyển thừa", `fakeTransferWrong` "Sai nội dung". Tên khoá `payAwaitingDeposit` giữ lại, giá trị đã đổi.
- **Truy cập**: `CountdownPill` đổi nhãn mỗi giây nhưng chỉ là vùng live ở các mốc 5:00, 1:00, 0:10 và 0 (đọc "QR còn hiệu lực 5 phút 0 giây"), để trình đọc màn hình không bị ngắt mỗi giây; thẻ QR đọc "Mã VietQR {số tiền}, nội dung {mã}" (hoặc "QR đã hết hạn"); nút "Sao chép" cao tối thiểu 48dp.
- **Chấp nhận**: chỉ có một nút chính mỗi trạng thái; chuyển đúng số tiền và nội dung → booking `requested` và màn tự sang S05.02; "Kiểm tra lại" không tạo khoản thứ hai; "Tạo QR mới" làm QR cũ hết hiệu lực, tiền chuyển vào QR cũ được hoàn tự động; đếm ngược chạm 0 thì màn hiện trạng thái hết hạn dù chưa có job nào chạy.

---

## S05.02 · Chi tiết booking

- **Thông tin**: `/b/:id` · cả hai · sub‑project 4 · Chưa có.
- **Mục đích**: một màn cho mọi trạng thái của booking, kèm hành động đúng lúc.
- **Điểm vào → ra**: S05.01, S06.01, push, link `/b/{id}`, sau S04.03/S04.04. "Liên hệ" bung khay S05.04; "Nhắn tin" → S07.01; "Huỷ" → S05.03; "Đổi lịch" (menu `…`) → tin hệ thống trong S07.01; "Đánh giá" → S05.05.
- **Bố cục**: toast kết quả (sau thanh toán: "Đã thanh toán {số tiền}, tiền được giữ an toàn."); `EscrowNotice` (khách: "Đã thanh toán {số tiền}, tiền được giữ an toàn"; NAG: "{số tiền} đang được giữ, chuyển cho bạn theo 2 mốc"); `BookingCard` (thumb, gói, ngày giờ, địa điểm, badge); `StatusTimeline` 7 bước, bước hiện tại nổi; hàng hai nút: "Nhắn tin" (viền) + `ContactDial` "Liên hệ"; "Đổi lịch" nằm trong menu `…` ở thanh trên; nút chữ đỏ "Huỷ yêu cầu · hoàn {x}%".
- **Dữ liệu**: `bookingProvider(id)` lắng nghe thời gian thực; chat lấy `chatId`. Phía NAG hiển thị số khách chỉ sau khi khách thanh toán (qua `ContactDial`).
- **Trạng thái**: theo `status` (xem bảng): hành động hiện khác nhau; hôm diễn ra → nút "Chỉ đường"; sau `endTime` NAG có "Hoàn thành".

| Trạng thái | Hành động khách | Hành động NAG |
|-----------|-----------------|---------------|
| `requested` | Liên hệ, Huỷ | Nhận, Từ chối (S06.03) |
| `accepted`/`upcoming` | Liên hệ, Đổi lịch, Chỉ đường, Huỷ | Liên hệ, Đổi lịch, Hoàn thành (sau giờ), Huỷ |
| `declined`/`expired`/`cancelled` | Đặt lại | — |
| `completed` | Đánh giá (S05.05) | — |
| `reviewed` | Xem đánh giá | — |

- **Chuỗi**: `s09_title` "Buổi chụp #{code}", `s09_contact` "Liên hệ", `s09_reschedule` "Đổi lịch", `s09_cancel` "Huỷ yêu cầu · hoàn {pct}%", `s09_directions` "Chỉ đường".
- **Phân tích**: `booking_open{status}`, `contact_tapped{channel, source:"S05.02"}`, `booking_action{action}`.
- **Chấp nhận**: timeline đúng thứ tự và thời điểm; số hoàn trên nút huỷ khớp bảng chính sách theo giờ hiện tại; trạng thái đổi theo thời gian thực không cần tải lại.

---

## S05.03 · Huỷ booking

- **Thông tin**: `/b/:id/cancel` (sheet) · khách · sub‑project 4 · Chưa có.
- **Mục đích**: huỷ có hiểu rõ hệ quả tiền.
- **Bố cục**: tiêu đề "Huỷ buổi chụp?"; bảng hoàn tiền 3 dòng tính trên số đã trả (≥ 48 giờ 100% · 24–48 giờ 50% · < 24 giờ 0%) với **dòng đang áp dụng được tô**; "Bạn sẽ nhận lại {số tiền}"; chip lý do (Đổi kế hoạch, Tìm được thợ khác, Lý do khác); hai nút: "Giữ lịch" (viền, bên trái) và "Huỷ buổi chụp" (đỏ, bên phải).
- **Dữ liệu**: tính hoàn từ `start` và giờ máy chủ; gọi `transitionBooking(cancelled)`.
- **Trạng thái**: đang gọi → nút loading; lỗi → SnackBar, giữ sheet; huỷ thành công → đóng, S05.02 hiện `cancelled`, toast "Đã huỷ. Hoàn {số tiền} trong 3–5 ngày".
- **Chuỗi**: `s10_title` "Huỷ buổi chụp?", `s10_refund` "Bạn sẽ nhận lại {amount}", `s10_keep` "Giữ lịch", `s10_confirm` "Huỷ buổi chụp".
- **Chấp nhận**: nút đỏ chỉ có trong sheet này; hoàn đúng theo thời điểm; chạm ngoài sheet không huỷ.

---

## S07.01 · Hội thoại

- **Thông tin**: `/chat/:chatId` · cả hai · sub‑project 4 · ✅ Đã làm (ảnh hiện và gửi lại ảnh: #131).
- **Mục đích**: chốt chi tiết buổi chụp, kèm ngữ cảnh booking. Cùng màn dùng cho chat **hỏi trước** (`kind: inquiry`, chưa có booking): thẻ ngữ cảnh thay bằng thẻ nhiếp ảnh gia + gói đang xem, không có hành động nhanh về lịch; khách gửi tối đa 3 tin khi nhiếp ảnh gia chưa trả lời, **sau khi nhiếp ảnh gia trả lời thì hai bên nhắn tự do** (không còn giới hạn, ô nhập và hành động bình thường); tự đóng sau 14 ngày không có tin từ cả hai phía (mỗi tin đặt lại bộ đếm; chat chưa có tin nào tính từ lúc tạo); gửi tin vào chat đã đóng là mở lại, trừ khi nhiếp ảnh gia đã tắt nhận tin hỏi trước thì khách bị từ chối (nhiếp ảnh gia luôn trả lời và mở lại được; chat còn mở vẫn nhắn tiếp được sau khi tắt); chat booking đã chuyển chỉ đọc mà khách bấm "Nhắn tin hỏi trước" thì thành chat hỏi trước lại, giữ lịch sử và không bị giới hạn 3 tin vì hai bên đã nói chuyện (cũng trừ khi đã tắt nhận tin hỏi trước); khi khách đặt, cuộc trò chuyện gắn `bookingId` và chuyển thành chat booking.
- **Bố cục**: thanh trên (Back, avatar + tên, `…` chỉ hiện khi có mục: chat booking → "Xem buổi chụp", khách trong chat hỏi trước → "Xem hồ sơ", nhiếp ảnh gia trong chat hỏi trước chưa có mục nào cho tới khi có "Báo cáo" ở S20); thẻ ngữ cảnh ghim (thumb, gói, ngày giờ, địa điểm, giá, badge trạng thái, chạm → S05.02); hàng chip hành động nhanh theo trạng thái (Gửi vị trí, Gửi ảnh tham khảo, Đổi lịch, Xác nhận địa điểm); danh sách tin (bong bóng: mình gradient bên phải, người kia kính bên trái, ảnh, vị trí, tin hệ thống ở giữa); ô nhập (nút ảnh, ô tin, nút gửi).
- **Dữ liệu**: `messagesProvider(chatId)` từ `chats/{id}/messages`, sắp theo `createdAt`, phân trang ngược; đánh dấu đã đọc khi hiện; ảnh nén 1280px q75, bỏ EXIF (`ImagePurpose.chat`, #147) rồi tải lên Storage `chats/{chatId}/{uid}/{clientId}.jpg`; tin chỉ lưu đường dẫn, ảnh hiện bằng download URL (`chatImageUrlProvider`, phân giải một lần mỗi lần chạy app; ảnh người kia gửi luôn hiện bằng URL này; ảnh mình vừa gửi giữ file trên máy trong lúc màn còn mở, không nháy trống khi tin về).
- **Trạng thái**: tin đang gửi mờ + đồng hồ; gửi lỗi → "Gửi lại" ngay trên tin; gửi lại ảnh không tải lên lại nếu ảnh đã lên Storage (Storage không cho ghi đè, chỉ gọi lại bước đăng tin với cùng `clientId`), chỉ tải lên lại khi lần tải đầu hỏng (nhớ trong phiên màn hình, tắt app thì tin lỗi mất); lỗi khi gửi hiện SnackBar (tin chữ gửi lỗi cũng hiện câu chung "Không thực hiện được. Thử lại nhé." cạnh "Gửi lại"): khách bị từ chối mở lại chat hỏi trước → "Nhiếp ảnh gia đang tạm tắt nhận tin hỏi trước.", quá 3 tin → câu giới hạn, lỗi khác → "Không thực hiện được. Thử lại nhé."; chat hỏi trước đã đóng → dòng "Cuộc trò chuyện đã đóng. Gửi tin để mở lại." trên ô nhập, ô nhập vẫn mở; không tìm thấy chat → "Không tìm thấy cuộc trò chuyện"; offline cho xem, vô hiệu gửi kèm giải thích; booking đã đóng → ô nhập vẫn mở 7 ngày rồi chuyển chỉ đọc.
- **Tương tác**: "Đổi lịch" tạo tin `system` đề nghị; bên kia chấp nhận ngay trong tin; "Gửi vị trí" chia sẻ một lần (xin quyền khi bấm).
- **Chuỗi**: `s11_input` "Nhập tin nhắn…", `s11_sendLocation` "Gửi vị trí", `s11_sendRef` "Gửi ảnh tham khảo", `s11_reschedule` "Đổi lịch", `s11_confirmPlace` "Xác nhận địa điểm", `s11_sendFailed` "Gửi lại"; khoá l10n mới của #131: `chatNotFound` "Không tìm thấy cuộc trò chuyện", `chatMe` "Tôi", `chatViewProfile` "Xem hồ sơ", `chatInquiriesOff` "Nhiếp ảnh gia đang tạm tắt nhận tin hỏi trước."; tên đối tác thiếu thì dùng `profileRolePhotographer` "Nhiếp ảnh gia" / `profileRoleCustomer` "Khách hàng".
- **Phân tích**: `chat_send{type}`, `chat_quick{action}`.
- **Chấp nhận**: tin đến theo thời gian thực; không gửi được tin rỗng; thẻ ngữ cảnh luôn khớp trạng thái booking hiện tại.

---

## S07.02 · Danh sách hội thoại

- **Thông tin**: `/chats` · cả hai · sub‑project 4d · ✅ Đã làm.
- **Mục đích**: xem mọi cuộc trò chuyện ở một chỗ (hỏi trước và booking).
- **Bố cục**: AppBar tiêu đề "Tin nhắn"; danh sách `ConversationRow` mới nhất lên đầu (`AsyncView` với skeleton 6 hàng); mỗi hàng gồm avatar, tên đối tác, tin nhắn xem trước, thời gian tương đối, số tin chưa đọc, và badge cho cuộc trò chuyện gắn booking: badge là nhãn trạng thái booking hiện tại ("Đã nhận", "Sắp tới", "Hoàn thành"…, dùng `StatusBadge`), đọc từ `bookingStatus` trên chat nên theo kịp mọi lần đổi trạng thái; chat hỏi trước hoặc chat cũ chưa có trường này thì không có badge. Tin xem trước: tin cuối của mình có tiền tố "Bạn: "; chat hỏi trước đã đóng (14 ngày không có tin) hiện "Cuộc trò chuyện đã đóng. Gửi tin để mở lại." (ưu tiên hơn "Bạn: "); chat booking mà tin cuối là tin hệ thống (xem trước rỗng) hiện câu của trạng thái booking (`upcoming` dùng câu "đã nhận", `reviewed` dùng câu "hoàn thành", vì đó là tin hệ thống cuối cùng đã đăng). Chat chưa có tin nào không hiện. Chạm dòng → `/chat/:id`.
- **Dữ liệu**: `myChatsProvider` (stream danh sách `ChatListItem`): một listener truy vấn `chats` + một listener cho từng `chats/{id}/members/{uid}` (tối đa 50), không còn `get` từng chat mỗi lần có tin; đọc chat cập nhật số chưa đọc ở danh sách; danh sách đầu tiên chờ đủ số chưa đọc của các chat đang hiện. `totalUnreadProvider` (biểu tượng chat ở Trang chủ) cộng từ cùng stream này. Profile đối tác qua `partyProfileProvider(counterpartId)` (hiện skeleton ở vị trí hàng khi đang tải).
- **Trạng thái**: trống → `EmptyState` "Chưa có cuộc trò chuyện nào" + nút "Tìm nhiếp ảnh gia" (`/action`) cho khách, không có nút cho nhiếp ảnh gia; lỗi → `ErrorState` kèm nút thử lại.
- **Chuỗi**: `chatsTitle` "Tin nhắn", `chatsEmptyTitle` "Chưa có cuộc trò chuyện nào", `chatsEmptyAction` "Tìm nhiếp ảnh gia"; mới: `chatsYouPrefix` "Bạn: {text}", `chatClosed` "Cuộc trò chuyện đã đóng. Gửi tin để mở lại.".
- **Lệch mock có chủ ý**: mock vẽ thanh tab ở dưới màn này; `/chats` mở từ S02.01 và S05.01 (hai tab) và từ link đẩy nên nằm ngoài khung tab, không có thanh tab (đặt vào một nhánh sẽ chuyển tab).
- **Chấp nhận**: danh sách sắp xếp mới nhất lên đầu; tin mới đến tự cập nhật thứ tự thời gian thực; badge số tin chưa đọc hiện đúng; chạm dòng mở đúng cuộc trò chuyện; chuyển đổi trạng thái rỗng đúng theo vai trò khách/nhiếp ảnh gia.

---

## S05.01 · Danh sách đặt lịch

> **Đổi 2026-10-05**: `SegmentedTabs` Buổi chụp / Vé sự kiện / Việc đăng (tab thứ ba ở S15.02, [jobs.md](jobs.md)). Nếu chốt hợp đồng 100% theo mốc (spec 10-05 mục 4), S04.03, S05.02 và chính sách huỷ đổi theo mục 4.4 của spec đó.

- **Thông tin**: `/bookings` (khách) · khách · sub‑project 4 · Chưa có (hiện empty trong `BookingsTab`).
- **Mục đích**: xem mọi buổi chụp của mình và làm việc cần làm ngay.
- **Bố cục**: tiêu đề + biểu tượng chat; `SegmentedTabs` Sắp tới / Đang chờ / Đã xong **và** cấp trên cùng "Buổi chụp | Vé sự kiện" (vé: S11.04); danh sách `BookingCard` có hàng hành động dưới thẻ gần nhất (Chỉ đường, Nhắn tin) hoặc "Đánh giá" cho buổi chưa review.
- **Dữ liệu**: `myBookingsProvider(group)` theo `status`, mới nhất lên đầu; phân trang.
- **Trạng thái**: mỗi nhóm trống có hành động riêng ("Tìm nhiếp ảnh gia" / "Chưa có yêu cầu chờ" / "Chưa có buổi nào xong"); offline đọc cache.
- **Chuỗi**: `s14_title` "Đặt lịch", `s14_upcoming` "Sắp tới", `s14_pending` "Đang chờ", `s14_done` "Đã xong", `s14_review` "Đánh giá".
- **Chấp nhận**: chạm thẻ → S05.02; nhóm theo đúng `status`; badge đúng màu và chữ.

---

## S05.04 · Liên hệ sau khi đã đặt (`ContactDial` đã bung)

- **Thông tin**: không có route (popover) · cả hai · sub‑project 2 · Chưa có.
- **Mục đích**: gọi hoặc nhắn qua kênh ngoài, **chỉ sau khi đã đặt**, và chỉ lộ lựa chọn khi cần.
- **Điều kiện hiện**: booking `requested` (đã thanh toán)/`accepted`/`upcoming`/`completed` (30 ngày), hoặc vé sự kiện `paid` (tới 7 ngày sau sự kiện). Chưa đủ điều kiện thì S03.01, S11.02 chỉ có nút "Nhắn tin hỏi trước" (mở chat `inquiry`, không bung); `declined/expired/cancelled/refunded` khoá lại.
- **Điểm vào**: nút "Liên hệ" ở S05.02 (và S11.02 khi đã có vé), `ContactDial` trên thẻ ở S06.01, S12.03.
- **Bố cục**: nút nhỏ lúc nghỉ; khi bấm, **một khay** (radius 28, căn phải theo nút) trồi lên phía trên với ba biểu tượng tròn 44dp xếp ngang: Gọi, Zalo, WhatsApp, mỗi biểu tượng có nhãn chữ bên dưới. Zalo và WhatsApp dùng đúng biểu tượng của hãng, đơn sắc (spec chính 3b.6). "Nhắn tin trong app" không nằm trong khay, đã có nút "Nhắn tin" riêng bên cạnh nút Liên hệ.
- **Dữ liệu**: kênh bật từ `photographers/{uid}.contactChannels` (hoặc `customerContact` ở S06.01/S12.03); URL lấy lúc chạm bằng `getContactLink({bookingId | registrationId, channel})`, lỗi `contact_locked` nếu chưa đủ điều kiện. Không hiển thị số, ứng dụng không lưu số.
- **Trạng thái**: một kênh khả dụng → bấm nút mở thẳng kênh đó, không bung; không kênh ngoài nào → ẩn nút Liên hệ (còn nút "Nhắn tin"); đang lấy liên kết → nút Liên hệ hiện vòng chờ (khay đã đóng); giảm chuyển động → hiện/ẩn tức thì.
- **Tương tác**: khay mở 240ms, ba biểu tượng vào so le 40ms từ phải sang; đóng 140ms; bấm ra ngoài, bấm lại nút, Back, hoặc chọn một viên đều đóng; chọn viên → mở ứng dụng ngoài (`tel:`, `https://zalo.me/…`, `https://wa.me/…`) hoặc vào S07.01.
- **Chuỗi**: `s32_label` "Liên hệ", `s32_call` "Gọi điện", `s32_zalo` "Zalo", `s32_whatsapp` "WhatsApp", `s32_locked` "Liên hệ qua điện thoại mở sau khi bạn đặt lịch", `s32_inquiry` "Nhắn tin hỏi trước", `s32_openError` "Không mở được liên hệ. Thử lại nhé.".
- **Phân tích**: `contact_tapped{channel, source}` (không ghi số); `contact_locked{source}` khi bị từ chối.
- **Chấp nhận**: không có đường nào lấy được số trước khi đặt (kể cả đọc Firestore trực tiếp: rules chặn `private/contact`); số đầy đủ chỉ đi vào ứng dụng ngoài; tiêu điểm vào viên đầu khi mở, Esc đóng và trả tiêu điểm; không che nút chính.

---

## S04.05 · Thêm số điện thoại

- **Thông tin**: `/profile/phone?returnTo=…` (sheet; bản đầu là trang đầy đủ, chuyển vào `AppBottomSheet` khi widget đó có) · khách · sub‑project 2 · Chưa có.
- **Mục đích**: có số điện thoại để đặt lịch (xác minh làm sau).
- **Điểm vào → ra**: tự mở khi khách bấm đặt lịch/đăng ký mà hồ sơ thiếu số (S02.02, S03.01, S02.06, S11.02); hàng "Số điện thoại" ở S09.02 cũng mở. Lưu xong → quay lại `returnTo`.
- **Bố cục**: tiêu đề "Thêm số điện thoại để đặt lịch", giải thích vì sao; `PhoneField` (tiền tố +84, định dạng `903 123 456`); ví dụ; hai công tắc "Cho phép liên hệ qua Zalo" (bật sẵn) và "WhatsApp" (tắt sẵn); ghi chú riêng tư "Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán."; nút "Lưu và tiếp tục".
- **Dữ liệu**: ghi `users/{uid}/private/contact` (`phone` E.164, `allowZalo`, `allowWhatsApp`, `phoneVerified:false`).
- **Trạng thái**: sai định dạng → lỗi dưới ô ("Số cần 10 chữ số, bắt đầu bằng 0"); lưu lỗi → SnackBar, giữ sheet; đóng không lưu → huỷ luồng đặt, trở lại màn trước.
- **Chuỗi**: `s33_title` "Thêm số điện thoại để đặt lịch", `s33_body` "Nhiếp ảnh gia sẽ gọi hoặc nhắn Zalo/WhatsApp cho bạn để chốt chi tiết.", `s33_phone` "Số điện thoại", `s33_example` "Ví dụ: 0903 123 456. Chưa cần mã xác minh; bước xác minh sẽ bổ sung sau.", `s33_allowZalo` "Cho phép liên hệ qua Zalo", `s33_allowWhatsApp` "Cho phép liên hệ qua WhatsApp", `s33_privacy` "Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán.", `s33_save` "Lưu và tiếp tục", `s33_errorFormat` "Số điện thoại chưa đúng. Ví dụ: 903 123 456".
- **Chấp nhận**: hợp lệ mới bật nút; chấp nhận `0903123456`, `+84 903 123 456`, từ chối `090312345`, `0123456789`; hồ sơ có số thì sheet không hiện nữa; mọi nhánh server vẫn chặn khi thiếu số.
