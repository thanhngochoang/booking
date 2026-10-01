# Đặt lịch, thanh toán, hội thoại, liên hệ

Màn: S05, S06, S07, S08, S09, S10, S11, S14, S32, S33. Quy ước chung ở [README.md](README.md). Máy trạng thái booking và chính sách cọc ở spec gốc mục 6–8.

---

## S05–S07 · Đặt lịch (sheet 4 bước)

Ba màn mock của một luồng `BookingSheetController` (`/u/:uid/book`), bước `service` → `datetime` → `place` → `review`. Dùng chung `AppBottomSheet` và `StepProgress` "n / 4".

### Quy tắc chung của luồng

- **Thông tin**: khách · sub‑project 4 · Chưa có.
- **Điều kiện vào**: khách đăng nhập và **có số điện thoại hợp lệ**. Thiếu thì mở S33 trước, lưu xong quay lại đúng bước (`returnTo`). Vào từ S02 ("Đặt gói này") thì bỏ bước 1; vào từ S04 ("Đặt T7") thì có sẵn ngày và dịch vụ.
- **Trạng thái luồng** giữ trong controller: `serviceId`, `date`, `start`, `end`, `place`, `note`, `phone`, `provider`. Quay lại không mất lựa chọn. Đóng sheet khi đã chọn gì đó hỏi xác nhận "Bỏ yêu cầu đặt lịch?". Không lưu nháp lên server cho tới khi tạo `draft` ở bước 4.
- **Tiền**: tổng giá gói luôn nằm trên nút chính; cọc 30%, phần còn lại trả tại buổi chụp.

### S05 · Bước 1 · Chọn gói

- **Mục đích**: chọn gói dịch vụ bằng hình, không phải dòng chữ.
- **Bố cục**: hàng nhiếp ảnh gia (avatar nhỏ, "Đặt với {tên}", "1 / 4"); tiêu đề "Chọn gói"; danh sách thẻ gói chọn đơn (thumb 48, tên, mô tả ngắn, giá); nút "Tiếp tục · {giá}".
- **Dữ liệu**: `servicesProvider(uid)` (chỉ `active`), sắp theo giá.
- **Trạng thái**: một gói duy nhất → chọn sẵn; không có gói → "Nhiếp ảnh gia chưa đăng gói" và đóng sheet; gói đổi giá trong lúc đặt → báo "Giá gói đã đổi" và cập nhật tổng.
- **Chuỗi**: `s05_title` "Chọn gói", `s05_with` "Đặt với {name}", `s05_continue` "Tiếp tục · {price}".
- **Chấp nhận**: chọn gói bật nút; tổng khớp giá gói.

### S06 · Bước 2 · Ngày và giờ

- **Bố cục**: dòng gói + "2 / 4"; tiêu đề tháng + chú giải (Rảnh · Đã đặt gạch · Chờ viền đứt); `AvailabilityCalendar` (ngày chọn tô gradient, không chọn được ngày đã đặt/nghỉ/quá khứ, ngày "Chờ" xem được nhưng không chọn, kèm "1 người đang chờ"); dòng "T7, 12/10 · khung 2 giờ"; hàng chip giờ (mốc 30 phút từ 06:00 đến 20:00 trừ `durationMinutes`; giờ gợi ý của nhiếp ảnh gia xếp đầu và gắn "gợi ý"); dòng kết thúc "15:30–17:30"; nút "Tiếp tục".
- **Dữ liệu**: `availabilityProvider(uid, month)`; chuyển tháng tải tháng mới; giờ sinh cục bộ từ gói.
- **Trạng thái**: chưa chọn ngày → nút vô hiệu; hết giờ trống trong ngày → "Hôm đó đã hết giờ", chọn ngày khác; lỗi tải lịch → thử lại.
- **Chuỗi**: `s06_legendFree` "Rảnh", `s06_legendBooked` "Đã đặt", `s06_legendPending` "Chờ", `s06_waiting` "{n} người đang chờ", `s06_endsAt` "{start}–{end}".
- **Chấp nhận**: ngày và giờ chọn không đổi khi quay lại; ngày chọn từ S04 được chọn sẵn.

### Bước 3 · Địa điểm (cùng layout S05)

- Bản đồ nhỏ + ô địa chỉ + chip gợi ý của nhiếp ảnh gia và địa điểm trong bộ lọc; mặc định theo bộ lọc hoặc gợi ý. Địa điểm tuỳ chọn tự do cần tên (≥ 3 ký tự). Nút "Tiếp tục".

### S07 · Bước 4 · Xem lại và đặt cọc

- **Mục đích**: ai · gì · khi nào · ở đâu · bao nhiêu trên một màn, rồi trả cọc.
- **Bố cục**: `BookingCard` tóm tắt (thumb, gói, ngày giờ, địa điểm); hàng **Ghi chú** + **SĐT của bạn** cùng chiều cao (SĐT lấy từ hồ sơ, sửa được, `PhoneField`); bảng tiền (giá gói, "Đặt cọc hôm nay (30%)" in đậm, "Còn lại trả tại buổi chụp"); `EscrowNotice` "Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành."; chính sách huỷ (3 dòng rút gọn); chọn cổng MoMo / VNPay (radio); nút "Đặt cọc {số tiền}".
- **Dữ liệu**: tạo booking `draft` rồi gọi `createDeposit({bookingId, provider})`; trước khi gọi kiểm tra lại `availability`.
- **Trạng thái**: đang gọi cổng → nút loading và vô hiệu mọi điều khiển; lỗi `day_taken` → quay S06 với ngày đó gạch và báo; lỗi `phone_required` → S33; lỗi mạng → giữ nguyên, "Thử lại"; cổng trả về → mở trang thanh toán (WebView/deeplink).
- **Tương tác**: ghi chú tối đa 300 ký tự có đếm; SĐT kiểm tra định dạng khi rời ô.
- **Chuỗi**: `s07_title` "Xem lại", `s07_note` "Ghi chú", `s07_phone` "SĐT của bạn", `s07_deposit` "Đặt cọc hôm nay (30%)", `s07_remaining` "Còn lại trả tại buổi chụp", `s07_policy` "Huỷ trước 48 giờ hoàn cọc 100%. Nhiếp ảnh gia phải nhận trong 24 giờ, nếu không tự hoàn cọc.", `s07_escrow` "Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành.", `s07_pay` "Đặt cọc {amount}".
- **Phân tích**: `book_step{n}`, `book_submit{provider}`, `book_error{code}`.
- **Chấp nhận**: không gọi cổng khi SĐT sai hoặc thiếu; client không tin kết quả redirect, chỉ tin `bookings.status`; số tiền cọc làm tròn đến đồng, `cọc + còn lại = giá`.

---

## S08 · Chờ thanh toán

- **Thông tin**: `/b/:id/pay` · khách · sub‑project 4 · Chưa có.
- **Mục đích**: xử lý trường hợp cổng chưa báo `paid` sau 5 phút.
- **Điểm vào → ra**: từ S07 sau khi quay lại từ cổng mà chưa `paid`. `paid` → tự chuyển S09; "Về chi tiết" → S09.
- **Bố cục**: vòng chờ (gradient), tiêu đề "Đang chờ xác nhận thanh toán", giải thích, `BookingCard` thu gọn kèm badge "Chờ cọc", nút chính "Kiểm tra lại", nút phụ "Đổi cổng thanh toán".
- **Dữ liệu**: lắng nghe `bookings/{id}`; "Kiểm tra lại" gọi Function hỏi cổng.
- **Trạng thái**: `paid` → chuyển; sau 30 phút `draft` bị dọn → báo "Yêu cầu đã hết hạn" và về S05; lỗi mạng → vẫn lắng nghe khi có mạng lại.
- **Chuỗi**: `s08_title` "Đang chờ xác nhận thanh toán", `s08_body` "Cổng thanh toán chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ.", `s08_check` "Kiểm tra lại", `s08_changeProvider` "Đổi cổng thanh toán".
- **Chấp nhận**: không tạo thanh toán thứ hai khi "Kiểm tra lại"; vòng chờ dừng khi giảm chuyển động bật (thay bằng biểu tượng tĩnh).

---

## S09 · Chi tiết booking

- **Thông tin**: `/b/:id` · cả hai · sub‑project 4 · Chưa có.
- **Mục đích**: một màn cho mọi trạng thái của booking, kèm hành động đúng lúc.
- **Điểm vào → ra**: S14, S19, push, link `/b/{id}`, sau S07/S08. "Liên hệ" bung khay S32; "Nhắn tin" → S11; "Huỷ" → S10; "Đổi lịch" (menu `…`) → tin hệ thống trong S11; "Đánh giá" → S12.
- **Bố cục**: toast kết quả (sau cọc); `EscrowNotice` (khách: "Cọc {số tiền} đang được giữ an toàn"; NAG: "Cọc {số tiền} đang được giữ, chuyển cho bạn sau khi hoàn thành"); `BookingCard` (thumb, gói, ngày giờ, địa điểm, badge); `StatusTimeline` 7 bước, bước hiện tại nổi; hàng hai nút: "Nhắn tin" (viền) + `ContactDial` "Liên hệ"; "Đổi lịch" nằm trong menu `…` ở thanh trên; nút chữ đỏ "Huỷ yêu cầu · hoàn cọc {x}%".
- **Dữ liệu**: `bookingProvider(id)` lắng nghe thời gian thực; chat lấy `chatId`. Phía NAG hiển thị số khách chỉ sau cọc (qua `ContactDial`).
- **Trạng thái**: theo `status` (xem bảng): hành động hiện khác nhau; hôm diễn ra → nút "Chỉ đường"; sau `endTime` NAG có "Hoàn thành".

| Trạng thái | Hành động khách | Hành động NAG |
|-----------|-----------------|---------------|
| `requested` | Liên hệ, Huỷ | Nhận, Từ chối (S23) |
| `accepted`/`upcoming` | Liên hệ, Đổi lịch, Chỉ đường, Huỷ | Liên hệ, Đổi lịch, Hoàn thành (sau giờ), Huỷ |
| `declined`/`expired`/`cancelled` | Đặt lại | — |
| `completed` | Đánh giá (S12) | — |
| `reviewed` | Xem đánh giá | — |

- **Chuỗi**: `s09_title` "Buổi chụp #{code}", `s09_contact` "Liên hệ", `s09_reschedule` "Đổi lịch", `s09_cancel` "Huỷ yêu cầu · hoàn cọc {pct}%", `s09_directions` "Chỉ đường".
- **Phân tích**: `booking_open{status}`, `contact_tapped{channel, source:"S09"}`, `booking_action{action}`.
- **Chấp nhận**: timeline đúng thứ tự và thời điểm; số hoàn trên nút huỷ khớp bảng chính sách theo giờ hiện tại; trạng thái đổi theo thời gian thực không cần tải lại.

---

## S10 · Huỷ booking

- **Thông tin**: `/b/:id/cancel` (sheet) · khách · sub‑project 4 · Chưa có.
- **Mục đích**: huỷ có hiểu rõ hệ quả tiền.
- **Bố cục**: tiêu đề "Huỷ buổi chụp?"; bảng hoàn cọc 3 dòng (≥ 48 giờ 100% · 24–48 giờ 50% · < 24 giờ 0%) với **dòng đang áp dụng được tô**; "Bạn sẽ nhận lại {số tiền}"; chip lý do (Đổi kế hoạch, Tìm được thợ khác, Lý do khác); hai nút: "Giữ lịch" (viền, bên trái) và "Huỷ buổi chụp" (đỏ, bên phải).
- **Dữ liệu**: tính hoàn từ `start` và giờ máy chủ; gọi `transitionBooking(cancelled)`.
- **Trạng thái**: đang gọi → nút loading; lỗi → SnackBar, giữ sheet; huỷ thành công → đóng, S09 hiện `cancelled`, toast "Đã huỷ. Hoàn {số tiền} trong 3–5 ngày".
- **Chuỗi**: `s10_title` "Huỷ buổi chụp?", `s10_refund` "Bạn sẽ nhận lại {amount}", `s10_keep` "Giữ lịch", `s10_confirm` "Huỷ buổi chụp".
- **Chấp nhận**: nút đỏ chỉ có trong sheet này; hoàn đúng theo thời điểm; chạm ngoài sheet không huỷ.

---

## S11 · Hội thoại

- **Thông tin**: `/chat/:chatId` · cả hai · sub‑project 4 · Chưa có (cần danh sách hội thoại làm điểm vào từ S01).
- **Mục đích**: chốt chi tiết buổi chụp, kèm ngữ cảnh booking. Cùng màn dùng cho chat **hỏi trước** (`kind: inquiry`, chưa có booking): thẻ ngữ cảnh thay bằng thẻ nhiếp ảnh gia + gói đang xem, không có hành động nhanh về lịch; khách gửi tối đa 3 tin khi nhiếp ảnh gia chưa trả lời, **sau khi nhiếp ảnh gia trả lời thì hai bên nhắn tự do** (không còn giới hạn, ô nhập và hành động bình thường); tự đóng sau 14 ngày không có tin từ cả hai phía (mỗi tin đặt lại bộ đếm); khi khách đặt, cuộc trò chuyện gắn `bookingId` và chuyển thành chat booking.
- **Bố cục**: thanh trên (Back, avatar + tên, `…`); thẻ ngữ cảnh ghim (thumb, gói, ngày giờ, địa điểm, giá, badge trạng thái, chạm → S09); hàng chip hành động nhanh theo trạng thái (Gửi vị trí, Gửi ảnh tham khảo, Đổi lịch, Xác nhận địa điểm); danh sách tin (bong bóng: mình gradient bên phải, người kia kính bên trái, ảnh, vị trí, tin hệ thống ở giữa); ô nhập (nút ảnh, ô tin, nút gửi).
- **Dữ liệu**: `messagesProvider(chatId)` từ `chats/{id}/messages`, sắp theo `createdAt`, phân trang ngược; đánh dấu đã đọc khi hiện; ảnh nén ≤ 2048px (WebP) rồi tải lên Storage.
- **Trạng thái**: tin đang gửi mờ + đồng hồ; gửi lỗi → "Gửi lại" ngay trên tin; offline cho xem, vô hiệu gửi kèm giải thích; booking đã đóng → ô nhập vẫn mở 7 ngày rồi chuyển chỉ đọc.
- **Tương tác**: "Đổi lịch" tạo tin `system` đề nghị; bên kia chấp nhận ngay trong tin; "Gửi vị trí" chia sẻ một lần (xin quyền khi bấm).
- **Chuỗi**: `s11_input` "Nhập tin nhắn…", `s11_sendLocation` "Gửi vị trí", `s11_sendRef` "Gửi ảnh tham khảo", `s11_reschedule` "Đổi lịch", `s11_confirmPlace` "Xác nhận địa điểm", `s11_sendFailed` "Gửi lại".
- **Phân tích**: `chat_send{type}`, `chat_quick{action}`.
- **Chấp nhận**: tin đến theo thời gian thực; không gửi được tin rỗng; thẻ ngữ cảnh luôn khớp trạng thái booking hiện tại.

---

## S14 · Danh sách đặt lịch

- **Thông tin**: `/bookings` (khách) · khách · sub‑project 4 · Chưa có (hiện empty trong `BookingsTab`).
- **Mục đích**: xem mọi buổi chụp của mình và làm việc cần làm ngay.
- **Bố cục**: tiêu đề + biểu tượng chat; `SegmentedTabs` Sắp tới / Đang chờ / Đã xong **và** cấp trên cùng "Buổi chụp | Vé sự kiện" (vé: S18); danh sách `BookingCard` có hàng hành động dưới thẻ gần nhất (Chỉ đường, Nhắn tin) hoặc "Đánh giá" cho buổi chưa review.
- **Dữ liệu**: `myBookingsProvider(group)` theo `status`, mới nhất lên đầu; phân trang.
- **Trạng thái**: mỗi nhóm trống có hành động riêng ("Tìm nhiếp ảnh gia" / "Chưa có yêu cầu chờ" / "Chưa có buổi nào xong"); offline đọc cache.
- **Chuỗi**: `s14_title` "Đặt lịch", `s14_upcoming` "Sắp tới", `s14_pending` "Đang chờ", `s14_done` "Đã xong", `s14_review` "Đánh giá".
- **Chấp nhận**: chạm thẻ → S09; nhóm theo đúng `status`; badge đúng màu và chữ.

---

## S32 · Liên hệ sau khi đã đặt (`ContactDial` đã bung)

- **Thông tin**: không có route (popover) · cả hai · sub‑project 2 · Chưa có.
- **Mục đích**: gọi hoặc nhắn qua kênh ngoài, **chỉ sau khi đã đặt**, và chỉ lộ lựa chọn khi cần.
- **Điều kiện hiện**: booking `requested` (đã cọc)/`accepted`/`upcoming`/`completed` (30 ngày), hoặc vé sự kiện `paid` (tới 7 ngày sau sự kiện). Chưa đủ điều kiện thì S03, S16 chỉ có nút "Nhắn tin hỏi trước" (mở chat `inquiry`, không bung); `declined/expired/cancelled/refunded` khoá lại.
- **Điểm vào**: nút "Liên hệ" ở S09 (và S16 khi đã có vé), `ContactDial` trên thẻ ở S19, S27.
- **Bố cục**: nút nhỏ lúc nghỉ; khi bấm, **một khay** (radius 28, căn phải theo nút) trồi lên phía trên với ba biểu tượng tròn 44dp xếp ngang: Gọi, Zalo, WhatsApp, mỗi biểu tượng có nhãn chữ bên dưới. Zalo và WhatsApp dùng đúng biểu tượng của hãng, đơn sắc (spec chính 3b.6). "Nhắn tin trong app" không nằm trong khay, đã có nút "Nhắn tin" riêng bên cạnh nút Liên hệ.
- **Dữ liệu**: kênh bật từ `photographers/{uid}.contactChannels` (hoặc `customerContact` ở S19/S27); URL lấy lúc chạm bằng `getContactLink({bookingId | registrationId, channel})`, lỗi `contact_locked` nếu chưa đủ điều kiện. Không hiển thị số, ứng dụng không lưu số.
- **Trạng thái**: một kênh khả dụng → bấm nút mở thẳng kênh đó, không bung; không kênh ngoài nào → ẩn nút Liên hệ (còn nút "Nhắn tin"); đang lấy liên kết → viên được chọn hiện vòng chờ; giảm chuyển động → hiện/ẩn tức thì.
- **Tương tác**: khay mở 240ms, ba biểu tượng vào so le 40ms từ phải sang; đóng 140ms; bấm ra ngoài, bấm lại nút, Back, hoặc chọn một viên đều đóng; chọn viên → mở ứng dụng ngoài (`tel:`, `https://zalo.me/…`, `https://wa.me/…`) hoặc vào S11.
- **Chuỗi**: `s32_label` "Liên hệ", `s32_call` "Gọi điện", `s32_zalo` "Zalo", `s32_whatsapp` "WhatsApp", `s32_locked` "Liên hệ qua điện thoại mở sau khi bạn đặt lịch".
- **Phân tích**: `contact_tapped{channel, source}` (không ghi số); `contact_locked{source}` khi bị từ chối.
- **Chấp nhận**: không có đường nào lấy được số trước khi đặt (kể cả đọc Firestore trực tiếp: rules chặn `private/contact`); số đầy đủ chỉ đi vào ứng dụng ngoài; tiêu điểm vào viên đầu khi mở, Esc đóng và trả tiêu điểm; không che nút chính.

---

## S33 · Thêm số điện thoại

- **Thông tin**: `/profile/phone?returnTo=…` (sheet) · khách · sub‑project 2 · Chưa có.
- **Mục đích**: có số điện thoại để đặt lịch (xác minh làm sau).
- **Điểm vào → ra**: tự mở khi khách bấm đặt lịch/đăng ký mà hồ sơ thiếu số (S02, S03, S04, S16); S31/S30 cũng mở. Lưu xong → quay lại `returnTo`.
- **Bố cục**: tiêu đề "Thêm số điện thoại để đặt lịch", giải thích vì sao; `PhoneField` (tiền tố +84, định dạng `903 123 456`); ví dụ; hai công tắc "Cho phép liên hệ qua Zalo" (bật sẵn) và "WhatsApp" (tắt sẵn); ghi chú riêng tư "Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc."; nút "Lưu và tiếp tục".
- **Dữ liệu**: ghi `users/{uid}/private/contact` (`phone` E.164, `allowZalo`, `allowWhatsApp`, `phoneVerified:false`).
- **Trạng thái**: sai định dạng → lỗi dưới ô ("Số cần 10 chữ số, bắt đầu bằng 0"); lưu lỗi → SnackBar, giữ sheet; đóng không lưu → huỷ luồng đặt, trở lại màn trước.
- **Chấp nhận**: hợp lệ mới bật nút; chấp nhận `0903123456`, `+84 903 123 456`, từ chối `090312345`, `0123456789`; hồ sơ có số thì sheet không hiện nữa; mọi nhánh server vẫn chặn khi thiếu số.
