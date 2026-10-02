# Sự kiện chụp ảnh

Màn: S11.01, S11.02, S11.03, S11.04, S12.01, S12.02, S12.03. Quy ước chung ở [README.md](README.md). Mô hình dữ liệu, trạng thái và Functions ở spec chính mục 3.

---

## S11.01 · Danh sách sự kiện

- **Thông tin**: `/events` · cả hai · sub‑project 3b · Chưa có.
- **Mục đích**: duyệt các sự kiện sắp diễn ra và lọc theo loại.
- **Điểm vào → ra**: "Xem tất cả" ở S02.03/S02.04; link. Thẻ → S11.02; (NAG) nút "Tạo sự kiện" → S12.01.
- **Bố cục**: AppBar "Sự kiện" + biểu tượng lịch; hàng tag loại dạng chữ, cuộn ngang (“Tất cả”, `#photowalk`, `#minisession`, `#workshop`, `#cosplay`…; không viền, không nền; tag đang chọn = chữ primary đậm + gạch chân 2dp, còn lại `textSecondary`; vùng chạm ≥ 48dp, `Semantics(selected)`; nhãn = `#` + mã loại viết thường không dấu cách, đây là bộ lọc loại, không phải hashtag riêng của sự kiện ở S11.05) và chip lọc “Không thu phí”; sắp xếp "Sớm nhất / Gần tôi"; thẻ nổi bật `EventCard` ảnh lớn (pill số chỗ); danh sách `EventCard` hàng gọn (khối ngày, tên, chủ, tag loại dạng chữ `#workshop`, giá (giá 0 → tag xanh “Không thu phí” thay cho “0₫”), số chỗ còn).
- **Dữ liệu**: `eventsListProvider(type, sort, area)`; chỉ `open` và `full`; "Gần tôi" dùng vị trí/khu vực (spec chính 3c); phân trang 20.
- **Trạng thái**: hết chỗ vẫn hiện, ghi "Hết chỗ" bằng chữ; empty "Chưa có sự kiện" (+ NAG nút "Tạo sự kiện"); lỗi/offline theo quy ước.
- **Tương tác**: tag loại đang chọn giữ khi quay lại; kéo xuống làm mới.
- **Chuỗi**: `s15_title` "Sự kiện", `s15_all` "Tất cả", `s15_soldOut` "Hết chỗ", `s15_left` "Còn {n} chỗ", `s15_free` "Không thu phí", `s15_empty` "Chưa có sự kiện", `s15_create` "Tạo sự kiện".
- **Phân tích**: `event_list_filter{type}`, `event_open{source:"list", rank}`.
- **Chấp nhận**: 2 cột ≥ 600dp; thẻ hết chỗ không chạm vào đăng ký được nhưng xem chi tiết được; sắp "Gần tôi" khớp khoảng cách.

---

## S11.02 · Chi tiết sự kiện

- **Thông tin**: `/e/:eventId` · cả hai · sub‑project 3b · Chưa có.
- **Mục đích**: biết khi nào, ở đâu, còn chỗ không, bao nhiêu, rồi đăng ký.
- **Điểm vào → ra**: S11.01, S02.03/S02.04, link, push. "Đăng ký tham gia" → S11.03 (qua S04.05 nếu thiếu số); chủ → "Quản lý" → S12.03; "Xem vé" → S11.04; hồ sơ chủ → S03.01; nút "Nhắn tin hỏi trước" → S07.01; sau khi có vé, `ContactDial` → S05.04.
- **Bố cục**: ảnh bìa 16:10 với Back/chia sẻ; tag loại; tên (Fraunces 22); `SegmentedTabs` **Thông tin / Timeline (S11.05) / Nhóm chat (S11.06)**, tab Nhóm chat chỉ mở cho người đã đăng ký, người khác thấy khoá kèm "Đăng ký để vào nhóm"; hàng chủ sự kiện (avatar, tên + `VerifiedMark`, sao · số sự kiện, nút Hồ sơ, nút "Nhắn tin hỏi trước" — đổi thành `ContactDial` khi đã có vé `paid`); hàng ngày giờ (+ "Thêm vào lịch"); hàng địa điểm + điểm hẹn (+ "Chỉ đường"); `CapacityBar` "14 / 20 đã đăng ký · Còn 6 chỗ"; mô tả; thanh dưới cố định: giá "mỗi người" + nút "Đăng ký tham gia". Sự kiện giá 0: dưới ảnh bìa có **banner** (`FreeBanner`) “Không thu phí · Đăng ký để giữ chỗ, không cần thanh toán”, và thanh dưới hiện tag “Không thu phí” thay cho giá.
- **Dữ liệu**: `eventProvider(id)` thời gian thực (số chỗ đổi); đăng ký của người xem để đổi nút.
- **Trạng thái**: `full` → nút thành "Hết chỗ" (vô hiệu, chữ); `closed` quá hạn → "Đã đóng đăng ký"; `cancelled` → dải "Sự kiện đã huỷ" và không đăng ký; đã đăng ký → "Xem vé"; chủ → "Quản lý"; sự kiện đã qua → "Sự kiện đã kết thúc".
- **Tương tác**: "Thêm vào lịch" tạo sự kiện lịch hệ thống; chia sẻ link `/e/{id}`.
- **Chuỗi**: `s16_freeBanner` "Không thu phí", `s16_freeBannerBody` "Đăng ký để giữ chỗ, không cần thanh toán", `s16_join` "Đăng ký tham gia", `s16_perPerson` "mỗi người", `s16_capacity` "{n} / {max} đã đăng ký", `s16_viewTicket` "Xem vé", `s16_manage` "Quản lý", `s16_cancelled` "Sự kiện đã huỷ", `s16_ended` "Sự kiện đã kết thúc".
- **Phân tích**: `event_view{eventId}`, `event_join_tap`, `inquiry_open{source:"S11.02"}`, `contact_tapped{source:"S11.02"}` (chỉ sau khi có vé).
- **Chấp nhận**: deep link `/e/{id}` mở được sau khi qua đăng nhập (giữ `from`); số chỗ cập nhật thời gian thực; nút không bao giờ cho đăng ký khi `full/closed/cancelled`.

---

## S11.03 · Đăng ký sự kiện

- **Thông tin**: `/e/:eventId/join` (sheet) · khách · sub‑project 3b · Chưa có.
- **Mục đích**: giữ chỗ và thanh toán đủ giá vé.
- **Bố cục**: tiêu đề + tên sự kiện; hàng "Số vé" với bộ tăng giảm 1–4 (tối đa số chỗ còn); ô họ tên và SĐT (lấy từ hồ sơ; thiếu SĐT → S04.05); bảng tiền (`n` vé × giá, tổng); `EscrowNotice` "Tiền vé được giữ an toàn trên ứng dụng cho tới khi sự kiện kết thúc."; chính sách huỷ; đếm ngược giữ chỗ 10 phút (hiện sau khi bấm thanh toán); chọn MoMo/VNPay; nút "Thanh toán {số tiền}" (sự kiện không thu phí: "Đăng ký không thu phí", bỏ cổng).
- **Dữ liệu**: `registerEvent` (giữ chỗ, trả `payUrl`); lắng nghe `registrations/{id}`.
- **Trạng thái**: `sold_out` → báo, quay S11.02 cập nhật số chỗ; `deadline_passed`; `limit_exceeded`; `phone_required` → S04.05; hết 10 phút chưa trả → chỗ nhả, báo "Chỗ giữ đã hết hạn"; lỗi cổng → thử lại.
- **Chuỗi**: `s17_title` "Đăng ký tham gia", `s17_tickets` "Số vé", `s17_total` "Tổng thanh toán", `s17_hold` "Giữ chỗ còn {mm:ss}", `s17_pay` "Thanh toán {amount}", `s17_free` "Xác nhận đăng ký".
- **Phân tích**: `event_join_submit{qty, free}`, `event_join_error{code}`.
- **Chấp nhận**: không bán quá sức chứa khi nhiều người đăng ký cùng lúc; vé chỉ có hiệu lực khi `paid`; thanh toán xong mở S11.04 với vé mới.

---

## S11.04 · Vé sự kiện

- **Thông tin**: `/bookings?tab=events` · khách · sub‑project 3b · Chưa có.
- **Mục đích**: giữ vé và xuất trình khi check‑in.
- **Bố cục**: `SegmentedTabs` "Buổi chụp | Vé sự kiện"; `TicketCard` sắp diễn ra (viền spectrum): tag loại, tên, ngày giờ · số vé, badge "Đã đăng ký", mã QR 112dp trên nền trắng, mã vé chọn‑copy, "Chỉ đường", "Thêm vào lịch"; nút chữ đỏ "Huỷ vé · hoàn {x}%"; các vé khác (chờ thanh toán, đã qua) dạng thẻ gọn.
- **Dữ liệu**: collection group `registrations (userId)` + sự kiện tương ứng; QR mã hoá `ticketCode`.
- **Trạng thái**: vé chờ thanh toán có "Thanh toán tiếp" (còn thời gian giữ) hoặc "Hết hạn"; vé đã qua mờ, không hiện QR; sự kiện bị huỷ → "Đã hoàn tiền" hoặc "Đang hoàn".
- **Tương tác**: huỷ vé mở xác nhận nêu số tiền hoàn; chạm QR phóng to với độ sáng cao (nếu khả thi).
- **Chuỗi**: `s18_tab` "Vé sự kiện", `s18_code` "Mã vé", `s18_cancel` "Huỷ vé · hoàn {pct}%", `s18_registered` "Đã đăng ký".
- **Phân tích**: `ticket_view`, `ticket_cancel`.
- **Chấp nhận**: QR quét được bởi S12.03; mã vé duy nhất; vé đã check‑in hiện "Đã tham gia".

---

## S12.01 · Tạo sự kiện, bước 1/2

- **Thông tin**: `/events/new` (bước `info`) · NAG, admin hoặc sales · sub‑project 3b · Chưa có.
- **Mục đích**: nhập nội dung sự kiện.
- **Điểm vào → ra**: tab giữa → chuyển "Sự kiện" ở S10.01; hoặc nút "Tạo sự kiện" (S11.01, S06.01; staff: S09.02 → "Quản lý sự kiện" → S12.03). Chỉ `admin`/`sales` thấy thêm ô "Tổ chức bởi" (xem dưới). "Tiếp tục" → S12.02.
- **Bố cục**: `StepProgress` 1/2; ô ảnh bìa 16:10 (chọn từ thư viện, nén ≤ 2048px); ô "Tổ chức bởi" (chỉ staff: "Nền tảng" hoặc chọn một nhiếp ảnh gia, tìm theo tên); ô "Tên sự kiện" (bắt buộc, ≤ 80 ký tự); chip loại chọn đơn; ô mô tả (≤ 1000 ký tự); nút "Tiếp tục".
- **Dữ liệu**: nháp lưu cục bộ mỗi lần đổi, và lên `events` với `draft` khi sang bước 2.
- **Trạng thái**: thiếu tên/loại/bìa → nút vô hiệu và lỗi dưới ô; "Quay lại" có dữ liệu → hỏi "Lưu nháp?".
- **Chuỗi**: `s25_host` "Tổ chức bởi", `s25_hostPlatform` "Nền tảng", `s25_title` "Tạo sự kiện", `s25_cover` "Thêm ảnh bìa 16:10", `s25_name` "Tên sự kiện", `s25_type` "Loại sự kiện", `s25_desc` "Mô tả".
- **Chấp nhận**: nháp khôi phục khi mở lại; ảnh bìa được nén và hiện xem trước; hồ sơ NAG chưa hoàn tất không vào được màn này.

---

## S12.02 · Tạo sự kiện, bước 2/2

- **Thông tin**: bước `schedule` · NAG, admin hoặc sales · sub‑project 3b · Chưa có.
- **Mục đích**: ngày giờ, địa điểm, sức chứa, giá, rồi đăng.
- **Bố cục**: `StepProgress` 2/2; hàng Ngày + Giờ bắt đầu; hàng Giờ kết thúc + Sức chứa; Địa điểm (tên + điểm hẹn + ghim bản đồ); hàng Giá mỗi người (₫) + Hạn đăng ký; ghi chú "Để giá bằng 0 nếu không thu phí"; thẻ **xem trước** `EventCard` (hiện tag “Không thu phí” khi giá 0); thanh dưới "Lưu nháp" + "Đăng sự kiện".
- **Kiểm tra hợp lệ**: `endAt > startAt`; `startAt` ở tương lai (≥ 2 giờ nữa); `capacity ≥ 1` (≤ 500); `price ≥ 0` và nguyên; hạn đăng ký ≤ `startAt`; ngày chưa `booked`/`pending` trong `availability` của NAG. Lỗi đặt dưới từng ô; submit thất bại → tóm tắt lỗi ở đầu có liên kết tới từng ô và tiêu điểm vào tóm tắt.
- **Dữ liệu**: `createEvent` ghi `events` (`open`) và đánh dấu `availability` ngày đó `booked` kèm `eventId`.
- **Trạng thái**: ngày bị chiếm → lỗi "Bạn đã có lịch hôm đó"; lỗi mạng → giữ dữ liệu, thử lại; đăng thành công → toast "Đã đăng sự kiện" và mở S12.03.
- **Chuỗi**: `s26_title` "Lịch và vé", `s26_capacity` "Sức chứa", `s26_price` "Giá mỗi người (₫)", `s26_deadline` "Hạn đăng ký", `s26_saveDraft` "Lưu nháp", `s26_publish` "Đăng sự kiện", `s26_free` "Để giá bằng 0 nếu không thu phí".
- **Phân tích**: `event_create_step{n}`, `event_publish{free, capacity}`.
- **Chấp nhận**: thẻ xem trước giống hệt thẻ khách thấy; sự kiện hiện ở S11.01/S02.03 ngay sau khi đăng; không tạo được hai sự kiện/booking cùng ngày của một NAG.

---

## S12.03 · Quản lý sự kiện

- **Thông tin**: `/events/:eventId/manage` · người quản lý: NAG chủ, admin (mọi sự kiện), sales (sự kiện do mình tạo) · sub‑project 3b · Chưa có.
- **Mục đích**: theo dõi đăng ký, check‑in, liên hệ người tham gia, huỷ khi cần.
- **Điểm vào → ra**: S12.02 sau khi đăng, S06.01 "Sự kiện của tôi", S06.04 (chạm ngày có sự kiện), S11.02 ("Quản lý").
- **Bố cục**: `EventCard` + badge trạng thái; hàng `StatTile` ×3 (Đã đăng ký n/N · Doanh thu · Ngày còn lại) cùng một hàng; mục "Người tham gia" (avatar, tên, số vé · mã vé, badge Đã trả/Chờ trả/Đã vào, `ContactDial`); nút chữ đỏ "Huỷ sự kiện · hoàn tiền mọi vé"; thanh dưới "Nhắn nhóm" + "Quét mã check‑in".
- **Dữ liệu**: `eventManageProvider(id)` thời gian thực: sự kiện + `registrations`; doanh thu = tổng `amount` của `paid` (sự kiện không thu phí hiện “—”). Số khách chỉ hiện với đăng ký đã `paid`.
- **Trạng thái**: chưa ai đăng ký → empty "Chưa có người đăng ký" + "Chia sẻ sự kiện"; sự kiện đã diễn ra → nút check‑in vô hiệu sau `endAt` + 2 giờ; đã huỷ → chỉ đọc.
- **Tương tác**: "Quét mã" mở máy quét QR (`mobile_scanner`, xin quyền camera khi bấm) → `checkInRegistration`; kết quả "Đã vào" hoặc "Vé không hợp lệ/đã dùng"; "Nhắn nhóm" **ghim một thông báo vào nhóm chat (S11.06)** kèm push cho thành viên; mục "Bài chờ duyệt" mở S11.05 ở chế độ duyệt; "Huỷ sự kiện" mở sheet xác nhận nêu số vé và tổng tiền sẽ hoàn.
- **Chuỗi**: `s27_title` "Quản lý sự kiện", `s27_pinAnnouncement` "Ghim thông báo vào nhóm", `s27_pending` "Bài chờ duyệt", `s27_registered` "Đã đăng ký", `s27_revenue` "Doanh thu", `s27_daysLeft` "Ngày còn lại", `s27_scan` "Quét mã check‑in", `s27_broadcast` "Nhắn nhóm", `s27_cancel` "Huỷ sự kiện · hoàn tiền mọi vé".
- **Phân tích**: `checkin_result{ok|used|invalid}`, `event_cancel`, `event_broadcast`.
- **Chấp nhận**: check‑in cập nhật dòng tương ứng trong < 2 giây; quét lại vé đã dùng báo rõ, không đếm hai lần; huỷ hoàn mọi vé đã trả và gửi push.

---

## S11.05 · Timeline sự kiện

- **Thông tin**: `/e/:eventId/timeline` (cũng là tab ở S11.02) · cả hai · sub‑project 3b · Chưa có.
- **Mục đích**: xem mọi ảnh/bài viết về sự kiện ở một chỗ, theo hashtag.
- **Điểm vào → ra**: tab "Timeline" ở S11.02; link; push "Có ảnh mới". Chạm bài → S02.02 (kèm chip sự kiện); "Đăng ảnh" → trình đăng bài (chọn ảnh, chú thích đã chèn hashtag).
- **Bố cục**: AppBar tên sự kiện + chia sẻ; `SegmentedTabs` Thông tin / Timeline / Nhóm chat; chip `HashtagChip` `#PhotoWalkPhoCo1020` + "48 bài"; lưới masonry 2 cột các bài (ảnh đầu, tên tác giả phủ chữ ở đáy; nhãn nhỏ "Chủ sự kiện" cho bài của host); tab phụ "Chờ duyệt" cho chủ/staff; thanh dưới nút chính "Đăng ảnh với #hashtag" (ẩn với người không đủ quyền đăng).
- **Dữ liệu**: `eventTimelineProvider(eventId)` từ `event_posts` (`status = visible`) nối `posts`; phân trang 20, mới nhất trước; làm mới bằng kéo xuống. Bài đăng mới đi qua `post_event_share` (loại `event_share`) rồi `linkEventPosts` gắn vào sự kiện.
- **Trạng thái**: chưa có bài → empty "Chưa có ảnh nào. Hãy là người đầu tiên chia sẻ!" (nút đăng nếu đủ quyền); bài `pending` chỉ chủ/staff thấy; sự kiện `draft` → không mở; quá 30 ngày sau `completed` → chỉ xem, nút đăng thay bằng ghi chú; offline đọc cache.
- **Tương tác**: chạm giữ bài → menu (Báo cáo; với điều hành: Ẩn khỏi timeline, Duyệt); thích/lưu như S02.02; người đăng gỡ bài thì biến khỏi timeline.
- **Chuỗi**: `s45_timeline` "Timeline", `s45_count` "{n} bài", `s45_post` "Đăng ảnh với {tag}", `s45_empty` "Chưa có ảnh nào. Hãy là người đầu tiên chia sẻ!", `s45_pending` "Chờ duyệt", `s45_closed` "Timeline đã đóng đăng mới", `s45_hide` "Ẩn khỏi timeline".
- **Phân tích**: `event_timeline_view`, `event_share_post`, `event_post_hide`.
- **Chấp nhận**: bài có hashtag (không phân biệt hoa thường) xuất hiện trong timeline; bài của người ngoài ở trạng thái `pending` không hiện công khai; chủ sự kiện ẩn bài thì bài biến khỏi timeline nhưng còn ở hồ sơ tác giả.

---

## S11.06 · Nhóm chat sự kiện

- **Thông tin**: `/e/:eventId/chat` · thành viên (người đăng ký `paid`, chủ sự kiện, staff tạo) · sub‑project 3b · Chưa có.
- **Mục đích**: người tham gia và chủ sự kiện trao đổi, hẹn nhau, chia sẻ ảnh.
- **Điểm vào → ra**: tab "Nhóm chat" ở S11.02; nút "Vào nhóm chat" sau khi đăng ký thành công (S11.03) và trên thẻ vé (S11.04); push khi có thông báo ghim.
- **Bố cục**: AppBar tên sự kiện + "n thành viên" + menu `…` (thành viên, tắt tiếng, rời nhóm; điều hành: quản lý); **tin ghim** ở đầu (chạm mở rộng); danh sách tin (tên người gửi hiện phía trên bong bóng của người khác; ảnh, vị trí; tin hệ thống "X đã vào nhóm"); ô nhập (nút ảnh, ô tin "Nhắn cho nhóm…", nút gửi).
- **Dữ liệu**: `eventChatProvider(chatId)`; `Chat.kind = event_group`, `ChatMember.role ∈ {member, moderator}`; tin theo thời gian thực, phân trang ngược; tin ghim từ `chat_pins`.
- **Trạng thái**: người chưa đăng ký vào route → màn khoá "Đăng ký để vào nhóm" (→ S11.02); nhóm quá hạn (7 ngày sau `completed`) → chỉ đọc kèm dải "Nhóm đã đóng", 30 ngày sau lưu trữ; thành viên bị tắt tiếng thấy ô nhập vô hiệu kèm lý do; chế độ "chỉ điều hành nhắn" → ô nhập vô hiệu cho thành viên; gửi lỗi → thử lại ngay trên tin; offline xem được.
- **Tương tác**: điều hành giữ tin → ghim, xoá; menu thành viên → tắt tiếng hoặc gỡ; ai cũng báo cáo tin; mặc định chỉ thông báo tin ghim và khi được nhắc tên (`@`); giới hạn 20 tin/phút/người.
- **Chuỗi**: `s46_members` "{n} thành viên", `s46_pinned` "Ghim", `s46_input` "Nhắn cho nhóm…", `s46_locked` "Đăng ký để vào nhóm", `s46_closed` "Nhóm đã đóng", `s46_mutedNote` "Bạn đang bị tắt tiếng trong nhóm", `s46_modOnly` "Chỉ điều hành được nhắn", `s46_joined` "{name} đã vào nhóm".
- **Phân tích**: `event_chat_open`, `event_chat_send{type}`, `event_chat_report`, `event_chat_mod{action}`.
- **Chấp nhận**: vé `paid` tự vào nhóm trong vài giây; vé hoàn thì bị gỡ và mất quyền xem; thành viên không thấy số điện thoại/email của nhau; "Nhắn nhóm" ở S12.03 xuất hiện như tin ghim và có push.
