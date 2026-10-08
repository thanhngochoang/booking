# Nhiếp ảnh gia: công việc, lịch, đăng bài, thiết lập, kỹ năng

Màn: S06.01, S06.04, S10.01, S06.02, S06.03, S08.01, S08.05, S08.02, S08.03, S08.04. Quy ước chung ở [README.md](README.md). Mọi màn ở đây chỉ vào được với vai trò `photographer`.

---

## S06.01 · Công việc

> **Đổi 2026-10-05**: thêm `SegmentedTabs` Hôm nay / Việc tuyển / Báo giá (nội dung hiện tại là tab "Hôm nay"; hai tab sau ở S16.02, [jobs.md](jobs.md)); bỏ chuông ở đầu trang, số thông báo nằm trên tab Hồ sơ (spec chính 3h.1).

- **Thông tin**: `/bookings` (NAG) · sub‑project 5 · Chưa có (hiện là empty trong `BookingsTab`).
- **Mục đích**: biết hôm nay làm gì, trả lời yêu cầu mới, thấy doanh thu.
- **Điểm vào → ra**: tab Công việc (chấm số = số yêu cầu chờ). Thẻ hôm nay → S05.02; "Nhận"/"Từ chối" (→ S06.03); biểu tượng lịch → S06.04; "Sự kiện của tôi" → S12.03; `ContactDial` liên hệ khách.
- **Bố cục**: tiêu đề "Thứ 5, 10/10" + biểu tượng lịch; **thẻ buổi hôm nay** (`BookingCard` lớn, viền nổi bật (trung tính), ảnh phủ chữ, nút "Nhắn tin" và "Chỉ đường"); section "Yêu cầu mới" kèm số; thẻ yêu cầu (avatar khách, gói, ngày giờ, địa điểm, giá, ghi chú trích, "đã trả 450K", `ContactDial`, nút "Từ chối" và "Nhận · còn 22 giờ"); hàng `StatTile` ×3 (Tháng này · **Đang giữ** · Buổi sắp tới) trên một hàng, nhãn một dòng; "Đang giữ" là tiền khách đã trả đang được giữ, chạm → S06.05; section "Sự kiện của tôi".
- **Dữ liệu**: `workDashboardProvider` gộp booking `requested/accepted/upcoming` của NAG, doanh thu tháng từ `payments`, sự kiện của chủ; thời gian thực. Số khách chỉ hiện sau khi khách thanh toán.
- **Buổi studio giao (#134; dữ liệu do #136)**: thợ thuộc studio còn đọc thêm các booking `assigneeId == uid` bằng luồng thứ hai (chỉ mục đơn trường, không cần chỉ mục ghép), hợp với luồng của chính mình (trùng id thì bản của mình thắng). Booking có `photographerId != uid` là booking được giao: tính vào **Hôm nay** và **Buổi sắp tới**, không tính vào **Yêu cầu mới** (studio trả lời yêu cầu), **Tháng này** và **Đang giữ** (tiền về studio). Thẻ hôm nay của booking được giao có nhãn `BookingSummary.tag` "Giao bởi {studio}" (biểu tượng cửa hàng, tên studio từ `partyProfileProvider(photographerId)`; chưa tải xong thì chưa có nhãn). Luồng được giao bị từ chối (quy tắc chưa triển khai) hoặc lỗi thì coi như rỗng và ghi log một lần: S06.01 không bao giờ hỏng vì luồng này.
- **Trạng thái**: không có buổi hôm nay → ẩn thẻ; không yêu cầu → "Không có yêu cầu mới"; toàn bộ trống → S06.02; yêu cầu quá `acceptDeadline` → thẻ biến mất và toast "Yêu cầu {tên} đã hết hạn, đã hoàn tiền"; offline đọc cache, nút Nhận/Từ chối vô hiệu.
- **Tương tác**: "Nhận" gọi `transitionBooking(accepted)` rồi mở chat; đếm ngược cập nhật mỗi phút (mỗi giây khi còn < 1 giờ).
- **Chuỗi**: `s19_today` "Hôm nay", `s19_requests` "Yêu cầu mới", `s19_accept` "Nhận · còn {time}", `s19_decline` "Từ chối", `s19_month` "Tháng này", `s19_held` "Đang giữ", `s19_upcoming` "Buổi sắp tới", `s19_myEvents` "Sự kiện của tôi"; `workAssignedBy` "Giao bởi {studio}".
- **Phân tích**: `request_accept`, `request_decline_open`, `work_calendar_open`.
- **Chấp nhận**: ba ô số liệu cùng một hàng, cùng chiều cao, nhãn không xuống dòng ở 320dp và chữ 1,3×; chấm số tab khớp số yêu cầu; hết hạn xử lý đúng giờ máy chủ; buổi studio giao hiện ở Hôm nay với nhãn "Giao bởi {studio}" và không đổi ba ô số liệu ngoài Buổi sắp tới; luồng được giao lỗi vẫn hiện đủ S06.01.

---

## S06.04 · Lịch của tôi

- **Thông tin**: `/work/calendar` · sub‑project 2 · Chưa có.
- **Mục đích**: đánh dấu ngày nghỉ; thấy ngày đã đặt/chờ.
- **Bố cục**: Back + "Lịch của tôi"; chọn tháng (3 tab `SegmentedTabs`) phía trên lịch, lịch không có tiêu đề riêng; `AvailabilityCalendar` có thể chỉnh (ngày chọn tô gradient); chú giải (tên bốn trạng thái, mỗi tên tô kiểu như ô của nó); khung ngày đã chọn: tiêu đề ngày kèm nút chữ "Đánh dấu nghỉ"/"Bỏ nghỉ" (không dùng nút gradient), hoặc liên kết "Xem lịch hẹn" (`/b/{id}`) / "Quản lý sự kiện" (S12.03) và chữ "Ngày này đã có lịch" — danh sách `BookingCard` của ngày thêm ở bước 5 khi có dữ liệu booking; ghi chú hướng dẫn ở cuối.
- **Dữ liệu**: tài liệu `availability/{uid}/days/{yyyy-MM-dd}` (không có = rảnh); nhiếp ảnh gia chỉ tạo/xoá `off`; `booked`/`pending` do máy chủ ghi tự động từ booking/sự kiện kèm `bookingId`/`eventId`, nhiếp ảnh gia không sửa được.
- **Trạng thái**: ngày đã đặt/chờ → không đánh dấu nghỉ được (nhắn "Ngày này đã có lịch"); ngày quá khứ chỉ đọc.
- **Tương tác**: chạm ngày trống → đặt `off` ngay (snackbar "Đã đánh dấu nghỉ" + Hoàn tác); chạm ngày `off` → bỏ nghỉ; chọn dải ngày: nhấn giữ ngày đầu rồi chạm ngày cuối; chạm ngày có sự kiện → khung ngày có liên kết "Quản lý sự kiện" (S12.03); tháng xem được từ tháng này tới 12 tháng sau.
- **Chuỗi**: `s20_title` "Lịch của tôi", `s20_markOff` "Đánh dấu nghỉ", `s20_undo` "Hoàn tác", `s20_hint` "Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.", `s20_hasPlan` "Ngày này đã có lịch".
- **Phân tích**: `calendar_off{count}`.
- **Chấp nhận**: khách thấy cùng trạng thái ở S04.02 ngay sau khi lưu; chọn dải không cần kéo (nhấn giữ ngày đầu rồi chạm ngày cuối), và từng ngày chọn được bằng một lần chạm.

---

## S10.01 · Đăng bài

> **Đổi 2026-10-05**: công tắc "Thêm vào portfolio" thay bằng ô "Album · tuỳ chọn" mở S24.05 ([portfolio-awards.md](portfolio-awards.md)); `inPortfolio` thành giá trị dẫn xuất.

- **Thông tin**: `/action` (NAG) · sub‑project 3 · Chưa có (hiện empty trong `ActionTab`).
- **Mục đích**: đăng một lần cho cả portfolio và feed, luôn gắn gói.
- **Bố cục**: thanh tab‑gốc "Đăng bài" (tab giữa, không có nút quay lại); `SegmentedTabs` **Bài đăng / Sự kiện** (Sự kiện → S12.01); lưới ảnh 2 cột (≤ 10, ô cuối là dấu +; app dùng ô vuông) và dòng đếm "{n} / 10 ảnh"; ô mô tả; ô **Gói dịch vụ (bắt buộc)** viền nhấn; hàng Địa điểm + Phong cách; ô **Album · tuỳ chọn** (mặc định "Không xếp album", mở S24.05); nút "Đăng".
- **Dữ liệu**: tải ảnh lên Storage (nén trên máy theo mục đích portfolio: cạnh dài 2048 px, JPEG q82, xoá EXIF; `posts/{uid}/{postId}/{file}`, ≤ 3 MiB); tạo `posts` (`kind=work`, `serviceId`, `location`, `style`).
- **Trạng thái**: thiếu gói/ảnh → nút vô hiệu và lỗi dưới ô; chưa có gói nào → nút "Thêm gói" (→ S08.01 bước gói); tải lên có thanh tiến độ từng ảnh, lỗi một ảnh → thử lại riêng; nháp tự lưu cục bộ.
- **Tương tác**: kéo đổi thứ tự ảnh (có nút lên/xuống thay thế); gỡ ảnh; đăng xong về S02.01 với bài mới ở đầu.
- **Chuỗi** (`app_vi.arb`): `tabCreate` "Đăng bài", `createPostTabPost` "Bài đăng", `createPostTabEvent` "Sự kiện", `createPhotosCount` "{n} / {max} ảnh", `createServiceLabel` "Gói dịch vụ · bắt buộc", `createAlbumLabel` "Album · tuỳ chọn", `albumPickNone` "Không xếp album", `createPublish` "Đăng".
- **Phân tích**: `post_publish{photos, portfolio}`.
- **Chấp nhận**: không đăng được khi thiếu gói; bài hiện cả feed và portfolio; huỷ giữa chừng không để ảnh mồ côi trong Storage.

---

## S06.02 · Empty state Công việc

- **Thông tin**: `/bookings` khi chưa có gì · sub‑project 1 (dạng chung đã có) · Đã có dạng chung.
- **Mục đích**: biến trạng thái trống thành một hành động nuôi vòng lặp.
- **Bố cục**: tiêu đề tab + `SegmentedTabs` Yêu cầu / Sắp tới / Đã xong; `EmptyState`: minh hoạ tròn, "Buổi chụp tiếp theo bắt đầu từ đây", một câu dựa vào số ảnh hiện có, một nút.
- **Dữ liệu**: số ảnh portfolio, số gói, `skills.completeness` để chọn câu và nút.
- **Biến thể chưa nhận đơn (#134)**: khi hồ sơ của chính mình có `acceptingOrders == false` (thiếu trường thì lấy `verified && onboardingComplete`, như `photographerSummaryFrom`), `EmptyState` đổi thành: biểu tượng `verified_user` trong đĩa tròn, "Mở nhận đơn để khách đặt được bạn", câu giải thích, dòng chú thích ngay dưới ("Staff duyệt trong 24 giờ sau khi bạn gửi") và nút chính "Bắt đầu nhận đơn". Chờ `myIntroProvider` có dữ liệu mới chọn biến thể (đang tải hoặc lỗi giữ dạng cũ). Nút chỉ hiện và mở `/verify/start` (S21.02) khi `verifyStartReadyProvider` là `true`; #135 bật cờ khi có route, trước đó chữ vẫn hiện, không có nút (không có nút chính nào). Đã nhận đơn mà chưa có yêu cầu thì giữ empty state cũ. `SegmentedTabs` Yêu cầu / Sắp tới / Đã xong của mock không làm ở đây (S06.01 cũng không có).
- **Quy tắc chọn hành động**: chưa đủ 6 ảnh → "Thêm ảnh vào portfolio" (→ S10.01); chưa có gói → "Thêm gói" (→ S08.01); `completeness` < 70 → "Hoàn thiện kỹ năng" (→ S08.02); còn lại → "Chia sẻ hồ sơ".
- **Chuỗi**: `s22_title` "Buổi chụp tiếp theo bắt đầu từ đây", `s22_bodyPortfolio` "Hồ sơ có 6 ảnh và 1 gói được đặt nhiều gấp 3 lần. Bạn đang có {n} ảnh.", `s22_addPhotos` "Thêm ảnh vào portfolio"; biến thể chưa nhận đơn: `workClosedTitle` "Mở nhận đơn để khách đặt được bạn", `workClosedBody` "Bạn vẫn đăng portfolio, tạo gói và trò chuyện. Khách chỉ đặt lịch và xin báo giá sau khi bạn xác minh: số điện thoại, phí xác minh, danh tính và quy định nhận việc.", `workClosedNote` "Staff duyệt trong 24 giờ sau khi bạn gửi", `workClosedStart` "Bắt đầu nhận đơn".
- **Chấp nhận**: đúng một nút chính (biến thể chưa nhận đơn: tối đa một, và không có khi cờ `verifyStartReadyProvider` còn tắt); câu và nút đổi theo điều kiện trên.

---

## S06.03 · Từ chối yêu cầu

- **Thông tin**: `/b/:id/decline` (sheet) · sub‑project 5 · Chưa có.
- **Mục đích**: từ chối có lý do, khách được hoàn tiền.
- **Bố cục**: tiêu đề "Từ chối yêu cầu của {tên}?"; lý do chọn đơn (Kín lịch hôm đó, Ngoài khu vực phục vụ, Gói không phù hợp nhu cầu, Lý do khác → ô nhập ngắn); dòng "{tên} được hoàn 100% ({số tiền}) và nhận lý do này."; "Quay lại" (viền) + "Từ chối" (đỏ).
- **Trạng thái**: chưa chọn lý do → nút đỏ vô hiệu; "Lý do khác" cần ≥ 5 ký tự; đang gọi → loading; thành công → toast và thẻ biến khỏi S06.01.
- **Chuỗi**: `s23_title` "Từ chối yêu cầu của {name}?", `s23_reasonBusy` "Kín lịch hôm đó", `s23_reasonArea` "Ngoài khu vực phục vụ", `s23_reasonService` "Gói không phù hợp nhu cầu", `s23_reasonOther` "Lý do khác", `s23_refundNote` "{name} được hoàn 100% ({amount}) và nhận lý do này.", `s23_confirm` "Từ chối".
- **Phân tích**: `request_decline{reason}`.
- **Chấp nhận**: `declined` + hoàn 100% số đã trả; khách nhận push kèm lý do; lý do tự do được lọc/giới hạn độ dài.

---

## S08.01 · Thiết lập hồ sơ, bước 1–2

> **Đổi 2026-10-05**: bước 1 thêm "Bạn nhận việc với tư cách" Cá nhân / Studio ([portfolio-awards.md](portfolio-awards.md)); Studio thêm địa chỉ cơ sở ở S08.05.

- **Thông tin**: `/setup/:step` (1: giới thiệu, 2: gói) · sub‑project 2 · Chưa có.
- **Mục đích**: NAG hoàn thiện hồ sơ đủ để được đặt.
- **Điểm vào → ra**: nút "Chuyển qua chế độ nhiếp ảnh" ở S09.02 (Cài đặt → Chế độ), hoặc nhắc từ S06.02. Xong bước 2 → S08.02. Bốn bước tổng cộng: 1 Giới thiệu → 2 Gói → 3 Kỹ năng (S08.02) → 4 Khu vực & liên hệ (S08.05).
- **Bố cục bước 1**: thứ tự hình thức (Cá nhân / Studio) → ảnh đại diện → tên hiển thị → bio (≤ 300 ký tự) → thiết bị (≤ 8) → ghi chú; ảnh bìa không có ở bước này (bản đầu: tên hiển thị, giới thiệu ≤ 300 ký tự, thiết bị ≤ 8; ảnh đại diện thêm ở kế hoạch 2d2; ảnh bìa để kế hoạch media sau; thể loại và số năm kinh nghiệm chọn ở S08.02/S08.03, lưu trong `skills`). **Bước 2**: danh sách gói đã thêm (tên, thời lượng · số ảnh · giao n ngày, giá, nút ẩn biểu tượng mắt gạch chéo; chưa có ảnh bìa gói), form thêm gói (tên, giá ₫, thời lượng, số ảnh hậu kỳ, giao sau mấy ngày), nút "Thêm gói này"; thời lượng chọn từ một sheet (1/2/3/4/6/8 giờ); thanh dưới "Quay lại" + "Tiếp tục". `StepProgress` n/4. Các bước nối `/setup/1` → `/setup/2` → `/setup/3` (S08.02) → `/setup/4` (S08.05).
- **Dữ liệu**: ghi `photographers/{uid}` và `services`; lưu nháp mỗi bước. Gói không bị xoá mà ẩn (`active: false`) để bài đăng và booking cũ còn trỏ đúng gói; giá là số nguyên VND > 0, thời lượng 60/120/180/240/360/480 phút.
- **Trạng thái**: cần ≥ 1 gói mới sang bước 3; giá phải > 0 và nguyên; thời lượng chọn từ danh sách (1, 2, 3, 4, 6, 8 giờ); thoát giữa chừng không mất dữ liệu: mọi thứ đã gõ được lưu nháp trên máy theo từng người dùng, dữ liệu đã lưu nằm trên Firestore; vào lại `/setup` tiếp tục đúng bước; chưa xong thì hồ sơ không công khai và không đổi được vai trò.
- **Chuỗi**: `s24_title` "Hồ sơ nhiếp ảnh gia", `setupBioLabel` "Giới thiệu" (khoá cũ `s24_bio`), `packageDeliveryLabel` "Giao sau" (hậu tố ô: "ngày"), `s24_services` "Gói dịch vụ", `s24_serviceHint` "Khách đặt theo gói. Cần ít nhất một gói để hồ sơ hiện trong Tìm thợ ảnh.", `s24_addService` "Thêm gói này".
- **Chấp nhận**: gói thêm xong hiện ngay ở danh sách; `startingPrice` cập nhật bởi Function; thoát và quay lại tiếp tục đúng bước.

---

## S08.05 · Thiết lập hồ sơ, bước 4/4 (khu vực và liên hệ)

- **Thông tin**: `/setup/4` · sub‑project 2 · Chưa có.
- **Mục đích**: nơi phục vụ và kênh khách được liên hệ.
- **Bố cục**: `StepProgress` 4/4; Studio: khối Địa chỉ cơ sở đứng đầu (mock `#S08.05-studio`); ô khu vực phục vụ (thành phố + bán kính km); ô SĐT (bắt buộc, `PhoneField`); bốn thẻ công tắc: Gọi điện (dùng số trên), Zalo (dùng số trên hoặc nhập riêng), WhatsApp (nhập số quốc tế riêng), "Chỉ nhận tin nhắn trong app"; dòng riêng tư dưới các thẻ nói số chỉ hiện cho khách sau khi đã đặt; "Quay lại" + "Hoàn tất".
- **Dữ liệu**: một batch ghi `photographers/{uid}.serviceArea` (`city`, `radiusKm`) và `.contactChannels` (cờ công khai `call/zalo/whatsapp/acceptInquiries`, không có số), `photographers/{uid}/private/contact` (số, chỉ chủ đọc), và đặt `onboardingComplete = true`. Kênh chỉ bật được khi đã có số (rules kiểm bằng `existsAfter`).
- **Trạng thái**: cần ≥ 1 số hợp lệ và ≥ 1 kênh bật hoặc xác nhận "Chỉ nhận tin nhắn trong app"; WhatsApp bật mà trống → dùng số chính nếu hợp lệ quốc tế, không thì báo lỗi dưới ô. Công tắc "Chỉ nhận tin nhắn trong app" thay cho việc bật kênh ngoài: bật nó thì ba kênh kia tắt, bật một kênh ngoài thì nó tắt. Lỗi hiện sau lần bấm "Hoàn tất" đầu tiên rồi cập nhật theo từng thay đổi.
- **Chuỗi**: `s34_title` "Khu vực và liên hệ", `s34_area` "Khu vực phục vụ", `s34_phone` "Số điện thoại · bắt buộc", `s34_channels` "Chọn kênh khách được dùng để liên hệ bạn.", `s34_finish` "Hoàn tất". Khoá arb: `setupContact*`, `setupChannel*`, `setupInAppOnly*` (camelCase, `lib/l10n/app_vi.arb`).
- **Phân tích**: `setup_complete{channels}`.
- **Chấp nhận**: sau "Hoàn tất", hồ sơ hiện công khai và vào được S06.01; chỉ các kênh bật xuất hiện ở S05.04.

---

## S08.02 · Kỹ năng, phần 1 (thể loại và mức độ)

- **Thông tin**: `/setup/3`, `/profile/skills` · sub‑project 2 · Chưa có.
- **Mục đích**: thu thập dữ liệu có cấu trúc cho dịch vụ gợi ý (spec chính 3e).
- **Điểm vào → ra**: bước 3/4 thiết lập hoặc Hồ sơ → "Kỹ năng"; "Ảnh minh chứng" → S08.04; "Tiếp tục" → S08.05 (hoặc lưu và quay lại nếu sửa).
- **Bố cục**: `StepProgress` 3/4; mô tả ngắn "Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó."; `CompletenessMeter` "Độ khớp hồ sơ 72%" + gợi ý việc kế tiếp; "Thể loại chụp" (chip nhiều chọn, "n / 6"); "Mức độ": một hàng `LevelSelector` (Cơ bản / Thành thạo / Chuyên sâu) cho mỗi thể loại đã chọn, nhãn "Chuyên sâu tối đa 3"; dòng "Chân dung: 2 / 3 ảnh minh chứng" + "Chỉnh"; thanh dưới "Quay lại" + "Tiếp tục".
- **Dữ liệu**: `skillsControllerProvider` giữ nháp; nháp tự lưu **trên máy** (`SharedPreferences`, khoá `skillsDraft.<uid>`) sau mỗi thay đổi, nên nháp được phép chưa hợp lệ; Firestore chỉ nhận kỹ năng hợp lệ khi bấm "Tiếp tục"/"Lưu thay đổi" (một lần ghi `photographers/{uid}.skills`, gộp với dữ liệu sẵn có). Danh mục là bản tích hợp (`builtInSkillCatalog`, khoá theo nhóm + id); đọc `taxonomy/skills` từ xa để sau. Độ khớp hồ sơ và bước kế tiếp do Function `onPhotographerWrite` tính (`skills.completeness`, `skills.completenessNext`, `skills.completenessNextAfter`); app chỉ hiện số đã lưu: chưa có số → "Chưa có điểm" + "Lưu để tính độ khớp"; nháp khác bản đã lưu → giữ số, gợi ý "Lưu để cập nhật độ khớp"; còn lại gợi ý theo `completenessNext`, kèm "để lên N%" lấy từ `completenessNextAfter`. Khi Function gỡ minh chứng không hợp lệ (`skills.evidenceRemovedAt` mới hơn mốc `skillsEvidenceSeen.<uid>` trên máy), lần mở S08.02 kế tiếp báo "Một số minh chứng không hợp lệ đã được gỡ" một lần. Không dùng snapshot.
- **Trạng thái**: chọn thể loại thứ 7 → báo "Tối đa 6 thể loại"; mức "Chuyên sâu" thứ 4 → báo, giữ mức cũ; mức 3 thiếu minh chứng → cảnh báo vàng ở dòng đó và chặn "Tiếp tục"; không chọn thể loại nào → nút vô hiệu; lỗi tải danh mục → dùng bản tích hợp sẵn.
- **Tương tác**: chọn thể loại tự thêm một hàng mức mặc định "Thành thạo"; bỏ chọn xoá hàng mức và minh chứng (hỏi xác nhận nếu đã có minh chứng); lưu nháp mỗi lần đổi. Thoát khi có thay đổi: sheet "Lưu bản nháp?" với "Giữ bản nháp" (giữ nháp trên máy) và nút đỏ "Bỏ thay đổi". Chế độ sửa: nút chính "Lưu thay đổi" chỉ bật khi khác bản đã lưu.
- **Chuỗi**: `s38_title` "Kỹ năng", `s38_intro` "Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.", `s38_fit` "Độ khớp hồ sơ", `s38_types` "Thể loại chụp", `s38_levels` "Mức độ", `s38_levelBasic` "Cơ bản", `s38_levelGood` "Thành thạo", `s38_levelExpert` "Chuyên sâu", `s38_maxExpert` "Chuyên sâu tối đa 3", `s38_evidence` "{name}: {n} / 3 ảnh minh chứng", `s38_tooMany` "Tối đa 6 thể loại". Khoá arb dạng camelCase: `skills*`, `completeness*` (`lib/l10n/app_vi.arb`).
- **Phân tích**: `skills_save{specialties, expert}`, `skills_step{n}`.
- **Chấp nhận**: không lưu quá giới hạn (kiểm cả client lẫn rules); `LevelSelector` truy cập được bằng bàn phím và đọc to "Chân dung, mức Chuyên sâu"; id lưu đúng theo `taxonomy`.

---

## S08.03 · Kỹ năng, phần 2 (cuộn xuống)

- **Thông tin**: cùng màn S08.02 · sub‑project 2 · Chưa có.
- **Mục đích**: phong cách, kỹ năng thêm, ngôn ngữ, loại khách phù hợp, kinh nghiệm.
- **Bố cục** (các section tiếp theo của S08.02): "Phong cách" (chip, ≤ 4); "Kỹ năng thêm" (chip, ≤ 8); "Ngôn ngữ" (chip, ≥ 1); "Khách phù hợp" (chip, ≤ 4, gồm "Khách nước ngoài", "Người ngại ống kính", "Gia đình có bé nhỏ"); ô "Kinh nghiệm" (số năm 0–50).
- **Trạng thái**: ngôn ngữ trống → lỗi "Chọn ít nhất 1 ngôn ngữ" khi bấm Tiếp tục và cuộn tới mục đó; vượt giới hạn → báo như S08.02.
- **Chuỗi**: `s39_styles` "Phong cách", `s39_extras` "Kỹ năng thêm", `s39_languages` "Ngôn ngữ", `s39_audiences` "Khách phù hợp", `s39_years` "Kinh nghiệm", `s39_needLang` "Chọn ít nhất 1 ngôn ngữ".
- **Chấp nhận**: mọi giá trị lưu thành id; "Khách nước ngoài" hay "Người ngại ống kính" là tín hiệu ghép khách, không phải kỹ thuật; số năm lưu ở `yearsExperience`.

---

## S08.04 · Minh chứng kỹ năng

- **Thông tin**: `/profile/skills/evidence?skill=…` (sheet mở từ dòng "Chỉnh" ở S08.02; link này mở S08.02 ở chế độ sửa rồi mở sheet cho thể loại `skill`) · sub‑project 2 · Chưa có.
- **Mục đích**: gắn 1–3 ảnh thật của mình vào một thể loại để thuật toán tin cậy hơn.
- **Bố cục**: tiêu đề "Minh chứng · {thể loại}" + "n / 3"; giải thích; lưới 3 cột ảnh portfolio (ô chọn có viền và dấu); nút "Xong".
- **Dữ liệu**: `posts (photographerId)` của chính mình; ghi `evidencePostIds` của thể loại. Chỉ bài có `authorId` là chính nhiếp ảnh gia (không gồm bài `real_shoot` của khách gắn vào trang), 30 bài mỗi trang. Vì lọc trên máy, một trang có thể ngắn hoặc rỗng dù còn bài: mỗi lần tải đọc tối đa 5 trang tới khi đủ 30 bài của mình hoặc hết; lưới ngắn không cuộn được thì tự tải trang tiếp.
- **Trạng thái**: chưa có bài nào (đã đọc hết) → empty "Đăng bài trước" + nút tới S10.01; trang tiếp lỗi → giữ ảnh đã hiện, dòng "Không tải thêm được. Thử lại" dưới lưới (chạm để tải lại trang đó; cuộn không tự thử lại); chọn quá 3 → âm báo và dòng báo ngay trong sheet (SnackBar sẽ bị modal che), bỏ chọn một ảnh để chọn thêm; mức "Chuyên sâu" cần ≥ 1 ảnh mới đóng sheet bằng "Xong".
- **Chuỗi**: `s40_title` "Minh chứng · {name}", `s40_body` "Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.", `s40_done` "Xong", `s40_empty` "Đăng bài trước".
- **Phân tích**: `skill_evidence_set{skillId, count}`.
- **Chấp nhận**: chỉ chọn được bài của chính mình; bài bị xoá thì gỡ khỏi minh chứng và hạ nhắc nhở ở S08.02.

---

## S06.05 · Thu nhập

- **Thông tin**: `/work/earnings` · NAG · sub‑project 5 · Đã có (10b; thuế khấu trừ và chi tự động ở #134).
- **Mục đích**: thấy tiền đang được giữ, chờ chi trả và đã nhận; hiểu vì sao chưa nhận; thấy mỗi khoản về tay bao nhiêu sau thuế khấu trừ.
- **Điểm vào → ra**: ô "Đang giữ" ở S06.01, Hồ sơ → "Thu nhập". Thẻ "Tài khoản nhận tiền" → S06.06. Chạm một khoản để **bung chi tiết** tại chỗ (không mở booking nữa).
- **Bố cục**: Back + "Thu nhập"; hàng `StatTile` ×3 **Đang giữ · Chờ chi trả · Đã nhận** (cùng một hàng, nhãn một dòng); dải ghi chú "Chi tự động mỗi ngày · lần chi đầu do staff duyệt · phí chuyển do nền tảng trả"; thẻ tài khoản (huy hiệu ngân hàng, "Tài khoản nhận tiền", ngân hàng và `payoutAccountMasked` "•••• {last4}", mũi tên → S06.06) khi đã có tài khoản, còn chưa có thì dải nhắc "Thêm tài khoản để nhận tiền"; danh sách khoản theo tháng: dòng gồm tên khách/sự kiện, ngày và số mốc, số tiền, nhãn trạng thái (`Đang giữ` · `Chờ chi trả` · `Đã chuyển` · `Đang khiếu nại`). Thân màn cuộn (khung mock cao hơn điện thoại).
- **Chi tiết một khoản (bung ra, #134)**: khoản đã chuyển: "Đã chuyển theo mốc", "Hoa hồng ({tỉ lệ})" chỉ khi > 0, "Thuế khấu trừ ({tỉ lệ})", "Thực nhận" (số của lô đã chi). Khoản chưa chuyển: "Số tiền", "Thuế khấu trừ ({tỉ lệ})", "Thực nhận dự kiến" (ước tính theo chính sách). Studio không có dòng thuế. Tỉ lệ viết như "7%" hoặc "7,5%". Mỗi dòng tiền ở danh sách và các ô KPI vẫn là **tổng** (số tiền booking), chỉ phần chi tiết cho thấy thuế và thực nhận; "Đã nhận" là tổng gộp của các khoản đã chuyển.
- **Dữ liệu**: `earningsProvider` từ `payments` (escrow) và `payouts` của chính nhiếp ảnh gia: Đang giữ = tổng khoản `held`; Chờ chi trả = `released` chưa vào lô đã trả và lô `pending/needs_approval/processing`; Đã nhận = tổng lô `paid`. Mỗi dòng mang `platformFee`, `taxWithheld`, `netAmount`, `feeRateBp`, `taxRateBp`, `estimated` và (khi booking có) `milestonesDone`/`milestonesTotal` đọc từ `bookings/{id}/milestones`; dòng cũ đọc thuế 0, thực nhận = số tiền, `estimated = true`. Phân trang theo tháng.
- **Trạng thái**: chưa có khoản nào → empty "Chưa có khoản thu nào" nêu cách có khoản đầu; khoản `disputed` hiện biểu tượng và lý do tạm giữ; lô `failed` → dải "Chuyển khoản lỗi, kiểm tra tài khoản" (→ S06.06); offline đọc cache.
- **Chuỗi**: `earningsTitle` "Thu nhập", `earningsNotice` "Chi tự động mỗi ngày · lần chi đầu do staff duyệt · phí chuyển do nền tảng trả", `earningsHeld` "Đang giữ", `earningsSoon` "Chờ chi trả", `earningsReceived` "Đã nhận", `earningsStateHeld` "Đang giữ", `earningsStateReleased` "Chờ chi trả", `earningsStatePaid` "Đã chuyển {date}", `earningsStateDispute` "Đang khiếu nại", `earningsAddAccount` "Thêm tài khoản để nhận tiền", `earningsBreakdownReleased` "Đã chuyển theo mốc", `earningsBreakdownAmount` "Số tiền", `earningsBreakdownFee` "Hoa hồng ({percent})", `earningsBreakdownTax` "Thuế khấu trừ ({percent})", `earningsBreakdownNet` "Thực nhận", `earningsBreakdownNetEstimated` "Thực nhận dự kiến", `earningsMilestones` "mốc {done}/{total}", `earningsMilestonesAll` "đủ {total} mốc".
- **Theo mock (10b)**: biểu tượng cài đặt ở thanh trên (nhãn "Tài khoản nhận tiền") thay nút chữ; khoản nhóm theo tháng (tháng đầu nằm bên phải "Các khoản", tháng sau có tiêu đề riêng; năm khác ghi "Tháng 10/2025"); lý do tạm giữ là nhãn cố định theo mã (khiếu nại, lô chi trả tạm giữ), không bao giờ là lời của khách; "Xem thêm" khi trang đầy.
- **Khác mock, làm ở đợt sửa cuối của #134**: mock chỉ ghi chữ Đã chuyển ở nhãn (ngày chuyển nằm trong phần chi tiết) và vẽ thẻ tài khoản nhận tiền; bản làm hiện còn nhãn "Đã chuyển {date}" và biểu tượng cài đặt. Khi sửa, đổi `earningsStatePaid` và dòng này.
- **Phân tích**: `earnings_open`, `earnings_item_open{state}` (chỉ phát khi một khoản được bung).
- **Chấp nhận**: các số khớp sổ cái (mỗi khoản: `payout_paid` + `tax_withheld` + `platform_fee` bằng đúng số tiền của khoản); khoản đã chuyển có 1.500.000₫ · thuế 105.000₫ · thực nhận 1.395.000₫ khi thuế 7%; studio không có dòng thuế; không bao giờ hiện số tài khoản đầy đủ; ba ô cùng một hàng ở 320dp và chữ 1,3×.

---

## S06.06 · Tài khoản nhận tiền

- **Thông tin**: `/work/earnings/account` · NAG · sub‑project 5 · Đã có (10b; tra tên, OTP và 72 giờ ở #134).
- **Mục đích**: khai tài khoản ngân hàng đứng tên mình để nhận chi trả tự động mỗi ngày.
- **Bố cục** (form): Back + "Tài khoản nhận tiền"; khi đã có tài khoản thì dòng giới thiệu "Đang dùng {bank} •••• {last4}. Nhập tài khoản mới đứng tên bạn, tiền sẽ chi tự động vào đây." (`{bank}` là mã ngân hàng, ví dụ MB), còn lần đầu là "Nhập tài khoản đứng tên bạn, tiền sẽ chi tự động vào đây."; chọn ngân hàng (huy hiệu mã, tên ngắn, tên đầy đủ, tìm theo tên); ô số tài khoản (số, 6–20 chữ số; viền đỏ khi không khớp); **thẻ tra tên** (`NameLookupCard`); ghi chú "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài khoản được mã hoá, chỉ hiện 4 số cuối."; khi đổi: dòng khoá "Đổi tài khoản cần OTP và có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi. Tài khoản cũ sẽ nhận thông báo."; nút chính "Lưu tài khoản". **Không còn ô tên chủ tài khoản**: tên do ngân hàng trả về.
- **Tra tên và so khớp (Quyết định 11, 12, 16 của #134)**: chọn ngân hàng và số hợp lệ thì app tra sau 800 ms không gõ (và ngay khi bấm lưu), kết quả nhớ theo `bankCode:số` trong đời màn. So `normalizeHolderName` (bỏ dấu, `Đ`→`D`, viết hoa, chuẩn khoảng trắng) với tên đã xác minh (`users/{uid}/private/identity.legalName`, do #135 ghi): khớp → "Khớp tên đã xác minh"; khác → "Không khớp" kèm cả hai tên, ô số viền đỏ, nút lưu khoá (vẫn đọc được "Lưu tài khoản"), không có lối vẫn lưu; ngân hàng không tra được tên → "Ngân hàng chưa hỗ trợ tra tên" và vẫn lưu được ở `pending_review`, staff đối chiếu; không tìm thấy tài khoản → báo, khoá lưu; chưa có tên đã xác minh mà ngân hàng cũng không tra được → "Cần xác minh danh tính trước khi thêm tài khoản ở ngân hàng này", khoá lưu. Lưu chỉ bật khi `matched` hoặc `review`. Máy chủ vẫn tra lại và so lại khi lưu; nếu trả `name_mismatch` hay `not_found` thì app bỏ kết quả đã nhớ và hiện đúng trạng thái đó.
- **OTP khi đổi (Quyết định 8, 9)**: thêm tài khoản lần đầu không cần OTP. Đổi tài khoản: bấm lưu → gửi mã 6 số tới số điện thoại trong hồ sơ (`photographers/{uid}/private/contact.phone`), mở sheet "Nhập mã xác nhận": mã hiệu lực 5 phút, sai 5 lần phải gửi lại, gửi lại sau 60 giây, tối đa 5 lần mỗi ngày giờ Việt Nam, mã gắn với tài khoản đang lưu và chỉ dùng một lần. Chờ 60 giây tính theo người dùng: nhập nhầm số rồi sửa trong 60 giây thì app báo "Gửi lại sau {seconds} giây" thay vì gửi mã thứ hai; đóng sheet rồi lưu lại cùng tài khoản trong 5 phút thì dùng lại mã cũ. Chưa có số điện thoại → báo; ngoài emulator/dev (chưa có nhà cung cấp SMS) → "Chưa đổi được tài khoản lúc này. Liên hệ hỗ trợ". Mã thử nằm trong log của emulator (`fake otp`). Đổi sang đúng tài khoản đang dùng bị từ chối (`conflict`): "Đây đã là tài khoản đang dùng".
- **72 giờ (Quyết định 7)**: tài khoản đầu có hiệu lực ngay; đổi thì tài khoản cũ tắt ngay, tài khoản mới `activeFrom` = bây giờ + 72 giờ và không khoản nào được chi (cả hai tài khoản) trong lúc chờ; các lô đang mở được chuyển sang tài khoản mới và lô `pending` về `needs_approval` (lần chi đầu vào tài khoản mới do staff duyệt, mọi duyệt cũ mất). Màn hiện thẻ tài khoản mới kèm huy hiệu "Chờ hiệu lực", thẻ giờ "Tài khoản mới có hiệu lực lúc {time}" với dòng "Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do staff duyệt." và nút "Đổi tài khoản" dạng viền. Tài khoản chờ đối chiếu tên có thêm "Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu."
- **Dữ liệu**: ghi `payoutAccounts/{uid}/accounts/{id}` (số tài khoản mã hoá, chỉ hiện 4 số cuối; thêm `nameStatus` = `matched` / `pending_review` / `staff_confirmed` và `activeFrom`) và bản che `payoutAccounts/{uid}` (thêm `activeFrom`, `nameStatus`); mỗi nhiếp ảnh gia một tài khoản đang bật. Ba callable: `lookupPayoutAccountName` (tối đa 20 lần mỗi ngày giờ Việt Nam, tính cả lần tra bên trong lúc lưu; chỉ nhiếp ảnh gia; để không thành công cụ dò tên chủ tài khoản của người khác), `requestPayoutOtp`, `savePayoutAccount`. Tên tra cổng giả: lặp lại tên đã xác minh của người gọi, riêng số kết thúc `4321` ra `TRAN VAN B`, `9999` ra chưa hỗ trợ, `0404` ra không tìm thấy.
- **Trạng thái**: tài khoản đã có → hiện che (`•••• 3456`) và "Đổi tài khoản"; lỗi định dạng dưới ô; tra tên lỗi → "Không tra được tên. Thử lại" (chạm để tra lại), quá hạn mức → "Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai."; lưu lỗi → SnackBar, giữ dữ liệu; đang chuyển một lô tiền → "Đang chuyển một lô tiền, thử lại sau ít phút". Số vừa nhập bị xoá khỏi trạng thái màn ngay sau khi lưu thành công.
- **Chuỗi** (khoá `app_vi.arb`): `payoutAccountTitle` "Tài khoản nhận tiền", `payoutAccountIntro` "Nhập tài khoản đứng tên bạn, tiền sẽ chi tự động vào đây.", `payoutAccountIntroChange` "Đang dùng {bank} •••• {last4}. Nhập tài khoản mới đứng tên bạn, tiền sẽ chi tự động vào đây.", `payoutAccountBank` "Ngân hàng", `payoutAccountNumber` "Số tài khoản", `payoutAccountHint` "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài khoản được mã hoá, chỉ hiện 4 số cuối.", `payoutAccountChangeNote` "Đổi tài khoản cần OTP và có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi. Tài khoản cũ sẽ nhận thông báo.", `payoutAccountSave` "Lưu tài khoản", `payoutAccountChange` "Đổi tài khoản", `payoutAccountSameAccount` "Đây đã là tài khoản đang dùng", `payoutAccountPendingTitle` "Tài khoản mới có hiệu lực lúc {time}", `payoutAccountPendingBody` "Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do staff duyệt.", `payoutAccountPendingBadge` "Chờ hiệu lực", `payoutAccountReviewNote` "Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu.", `payoutAccountChangeSaved` "Đã đổi tài khoản. Có hiệu lực sau 72 giờ"; tra tên: `payoutLookupLoading` "Đang tra tên chủ tài khoản…", `payoutLookupMatched` "Khớp tên đã xác minh", `payoutLookupMismatch` "Không khớp", `payoutLookupMismatchTitle` "Tên chủ tài khoản không khớp tên đã xác minh ({name})", `payoutLookupMismatchBody` "Chỉ chi tiền vào tài khoản đứng tên bạn. Kiểm tra lại ngân hàng và số tài khoản.", `payoutLookupReview` "Ngân hàng chưa hỗ trợ tra tên", `payoutLookupReviewSub` "Staff đối chiếu tên trước lần chi đầu", `payoutLookupNotFound` "Không tìm thấy tài khoản. Kiểm tra lại số tài khoản.", `payoutLookupUnverifiable` "Cần xác minh danh tính trước khi thêm tài khoản ở ngân hàng này", `payoutLookupLimit` "Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.", `payoutLookupError` "Không tra được tên. Thử lại"; OTP: `payoutOtpTitle` "Nhập mã xác nhận", `payoutOtpBody` "Mã 6 số đã gửi tới số điện thoại •••• {last4}. Mã có hiệu lực 5 phút.", `payoutOtpField` "Mã OTP", `payoutOtpConfirm` "Xác nhận đổi tài khoản", `payoutOtpResend` "Gửi lại mã", `payoutOtpResendIn` "Gửi lại sau {seconds} giây", `payoutOtpNote` "Tài khoản mới có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi.", `payoutOtpWrong` "Mã chưa đúng. Kiểm tra lại tin nhắn", `payoutOtpExpired` "Mã đã hết hạn. Gửi lại mã mới", `payoutOtpTooMany` "Bạn đã nhập sai quá nhiều lần. Gửi lại mã mới", `payoutOtpLimit` "Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.", `payoutPhoneRequired` "Cần số điện thoại trong hồ sơ để nhận mã", `payoutOtpUnavailable` "Chưa đổi được tài khoản lúc này. Liên hệ hỗ trợ".
- **Xác nhận lại**: không còn bước đăng nhập lại ở màn này (OTP thay thế). `showReauthSheet` chuyển sang `lib/features/account/widgets/reauth_sheet.dart` cho S22.02 (xoá tài khoản), khoá `reauth*` ("Xác nhận lại để tiếp tục"), mã lỗi `reauth_required` vẫn còn trong `ERROR_CODES`.
- **Thông báo**: `payout_account_needed` và `payout_account_changed` (quan trọng) do #138 định nghĩa; #134 là nơi phát duy nhất (qua `livePayoutNotices`). Email về tài khoản cũ để sau.
- **Phân tích**: `payout_account_save{change}` (chỉ cho biết có phải đổi tài khoản, không có dữ liệu tài khoản).
- **Chấp nhận**: số tài khoản không có trong log, thông báo, phân tích, thông điệp lỗi và đầu ra test; chỉ chủ đọc, không ai ghi từ client; không khoản nào chuyển trong 72 giờ chờ; lô `pending` lúc đổi thành `needs_approval`; tra lần thứ 21 trong ngày bị từ chối; mã sai tính vào 5 lần dù lệnh báo lỗi; mã đã dùng hoặc mã của tài khoản khác không lưu được tài khoản thứ hai; thay tài khoản không ảnh hưởng khoản đã chuyển.
