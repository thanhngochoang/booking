# Nhiếp ảnh gia: công việc, lịch, đăng bài, thiết lập, kỹ năng

Màn: S19, S20, S21, S22, S23, S24, S34, S38, S39, S40. Quy ước chung ở [README.md](README.md). Mọi màn ở đây chỉ vào được với vai trò `photographer`.

---

## S19 · Công việc

- **Thông tin**: `/bookings` (NAG) · sub‑project 5 · Chưa có (hiện là empty trong `BookingsTab`).
- **Mục đích**: biết hôm nay làm gì, trả lời yêu cầu mới, thấy doanh thu.
- **Điểm vào → ra**: tab Công việc (chấm số = số yêu cầu chờ). Thẻ hôm nay → S09; "Nhận"/"Từ chối" (→ S23); biểu tượng lịch → S20; "Sự kiện của tôi" → S27; `ContactDial` liên hệ khách.
- **Bố cục**: tiêu đề "Thứ 5, 10/10" + biểu tượng lịch; **thẻ buổi hôm nay** (`BookingCard` lớn, viền spectrum, ảnh phủ chữ, nút "Nhắn tin" và "Chỉ đường"); section "Yêu cầu mới" kèm số; thẻ yêu cầu (avatar khách, gói, ngày giờ, địa điểm, giá, ghi chú trích, "đã cọc 450K", `ContactDial`, nút "Từ chối" và "Nhận · còn 22 giờ"); hàng `StatTile` ×3 (Tháng này · **Đang giữ** · Buổi sắp tới) trên một hàng, nhãn một dòng; "Đang giữ" là tiền cọc đang treo, chạm → S43; section "Sự kiện của tôi".
- **Dữ liệu**: `workDashboardProvider` gộp booking `requested/accepted/upcoming` của NAG, doanh thu tháng từ `payments`, sự kiện của chủ; thời gian thực. Số khách chỉ hiện sau cọc.
- **Trạng thái**: không có buổi hôm nay → ẩn thẻ; không yêu cầu → "Không có yêu cầu mới"; toàn bộ trống → S22; yêu cầu quá `acceptDeadline` → thẻ biến mất và toast "Yêu cầu {tên} đã hết hạn, đã hoàn cọc"; offline đọc cache, nút Nhận/Từ chối vô hiệu.
- **Tương tác**: "Nhận" gọi `transitionBooking(accepted)` rồi mở chat; đếm ngược cập nhật mỗi phút (mỗi giây khi còn < 1 giờ).
- **Chuỗi**: `s19_today` "Hôm nay", `s19_requests` "Yêu cầu mới", `s19_accept` "Nhận · còn {time}", `s19_decline` "Từ chối", `s19_month` "Tháng này", `s19_held` "Đang giữ", `s19_upcoming` "Buổi sắp tới", `s19_myEvents` "Sự kiện của tôi".
- **Phân tích**: `request_accept`, `request_decline_open`, `work_calendar_open`.
- **Chấp nhận**: ba ô số liệu cùng một hàng, cùng chiều cao, nhãn không xuống dòng ở 320dp và chữ 1,3×; chấm số tab khớp số yêu cầu; hết hạn xử lý đúng giờ máy chủ.

---

## S20 · Lịch của tôi

- **Thông tin**: `/work/calendar` · sub‑project 2 · Chưa có.
- **Mục đích**: đánh dấu ngày nghỉ; thấy ngày đã đặt/chờ.
- **Bố cục**: Back + "Lịch của tôi"; chọn tháng (3 tab); `AvailabilityCalendar` có thể chỉnh (ngày chọn tô gradient); chú giải; tiêu đề ngày chọn + "Đánh dấu nghỉ"; danh sách booking/sự kiện trong ngày (`BookingCard`/`EventCard`); ghi chú hướng dẫn.
- **Dữ liệu**: `availability/{uid}/days`; ngày `booked`/`pending` sinh tự động từ booking/sự kiện, không sửa được.
- **Trạng thái**: ngày đã đặt/chờ → không đánh dấu nghỉ được (nhắn "Ngày này đã có lịch"); ngày quá khứ chỉ đọc.
- **Tương tác**: chạm ngày trống → đặt `off` ngay (snackbar "Đã đánh dấu nghỉ" + Hoàn tác); chạm ngày `off` → bỏ nghỉ; chọn dải ngày bằng kéo hoặc nhấn giữ; chạm ngày có sự kiện → S27.
- **Chuỗi**: `s20_title` "Lịch của tôi", `s20_markOff` "Đánh dấu nghỉ", `s20_undo` "Hoàn tác", `s20_hint` "Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.", `s20_hasPlan` "Ngày này đã có lịch".
- **Phân tích**: `calendar_off{count}`.
- **Chấp nhận**: khách thấy cùng trạng thái ở S06 ngay sau khi lưu; có cách thay thế cho thao tác kéo (nhấn chọn từng ngày).

---

## S21 · Đăng bài

- **Thông tin**: `/action` (NAG) · sub‑project 3 · Chưa có (hiện empty trong `ActionTab`).
- **Mục đích**: đăng một lần cho cả portfolio và feed, luôn gắn gói.
- **Bố cục**: Back + "Đăng bài"; `SegmentedTabs` **Bài đăng / Sự kiện** (Sự kiện → S25); lưới ảnh 2 cột (≤ 10, ô cuối là dấu +); ô mô tả; ô **Gói dịch vụ (bắt buộc)** viền nhấn; hàng Địa điểm + Phong cách; công tắc "Thêm vào portfolio"; nút "Đăng".
- **Dữ liệu**: tải ảnh (nén ≤ 2048px WebP) lên Storage; tạo `posts` (`kind=work`, `serviceId`, `location`, `style`).
- **Trạng thái**: thiếu gói/ảnh → nút vô hiệu và lỗi dưới ô; chưa có gói nào → nút "Thêm gói" (→ S24 bước gói); tải lên có thanh tiến độ từng ảnh, lỗi một ảnh → thử lại riêng; nháp tự lưu cục bộ.
- **Tương tác**: kéo đổi thứ tự ảnh (có nút lên/xuống thay thế); gỡ ảnh; đăng xong về S01 với bài mới ở đầu.
- **Chuỗi**: `s21_title` "Đăng bài", `s21_tabPost` "Bài đăng", `s21_tabEvent` "Sự kiện", `s21_service` "Gói dịch vụ · bắt buộc", `s21_portfolio` "Thêm vào portfolio", `s21_publish` "Đăng".
- **Phân tích**: `post_publish{photos, portfolio}`.
- **Chấp nhận**: không đăng được khi thiếu gói; bài hiện cả feed và portfolio; huỷ giữa chừng không để ảnh mồ côi trong Storage.

---

## S22 · Empty state Công việc

- **Thông tin**: `/bookings` khi chưa có gì · sub‑project 1 (dạng chung đã có) · Đã có dạng chung.
- **Mục đích**: biến trạng thái trống thành một hành động nuôi vòng lặp.
- **Bố cục**: tiêu đề tab + `SegmentedTabs` Yêu cầu / Sắp tới / Đã xong; `EmptyState`: minh hoạ tròn, "Buổi chụp tiếp theo bắt đầu từ đây", một câu dựa vào số ảnh hiện có, một nút.
- **Dữ liệu**: số ảnh portfolio, số gói, `skills.completeness` để chọn câu và nút.
- **Quy tắc chọn hành động**: chưa đủ 6 ảnh → "Thêm ảnh vào portfolio" (→ S21); chưa có gói → "Thêm gói" (→ S24); `completeness` < 70 → "Hoàn thiện kỹ năng" (→ S38); còn lại → "Chia sẻ hồ sơ".
- **Chuỗi**: `s22_title` "Buổi chụp tiếp theo bắt đầu từ đây", `s22_bodyPortfolio` "Hồ sơ có 6 ảnh và 1 gói được đặt nhiều gấp 3 lần. Bạn đang có {n} ảnh.", `s22_addPhotos` "Thêm ảnh vào portfolio".
- **Chấp nhận**: đúng một nút chính; câu và nút đổi theo điều kiện trên.

---

## S23 · Từ chối yêu cầu

- **Thông tin**: `/b/:id/decline` (sheet) · sub‑project 5 · Chưa có.
- **Mục đích**: từ chối có lý do, khách được hoàn cọc.
- **Bố cục**: tiêu đề "Từ chối yêu cầu của {tên}?"; lý do chọn đơn (Kín lịch hôm đó, Ngoài khu vực phục vụ, Gói không phù hợp nhu cầu, Lý do khác → ô nhập ngắn); dòng "{tên} được hoàn cọc {số tiền} và nhận lý do này."; "Quay lại" (viền) + "Từ chối" (đỏ).
- **Trạng thái**: chưa chọn lý do → nút đỏ vô hiệu; "Lý do khác" cần ≥ 5 ký tự; đang gọi → loading; thành công → toast và thẻ biến khỏi S19.
- **Chuỗi**: `s23_title` "Từ chối yêu cầu của {name}?", `s23_reasonBusy` "Kín lịch hôm đó", `s23_reasonArea` "Ngoài khu vực phục vụ", `s23_reasonService` "Gói không phù hợp nhu cầu", `s23_reasonOther` "Lý do khác", `s23_refundNote` "{name} được hoàn cọc {amount} và nhận lý do này.", `s23_confirm` "Từ chối".
- **Phân tích**: `request_decline{reason}`.
- **Chấp nhận**: `declined` + hoàn cọc 100%; khách nhận push kèm lý do; lý do tự do được lọc/giới hạn độ dài.

---

## S24 · Thiết lập hồ sơ, bước 1–2

- **Thông tin**: `/setup/:step` (1: giới thiệu, 2: gói) · sub‑project 2 · Chưa có.
- **Mục đích**: NAG hoàn thiện hồ sơ đủ để được đặt.
- **Điểm vào → ra**: nút "Chuyển qua chế độ nhiếp ảnh" ở S31 (Cài đặt → Chế độ), hoặc nhắc từ S22. Xong bước 2 → S38. Bốn bước tổng cộng: 1 Giới thiệu → 2 Gói → 3 Kỹ năng (S38) → 4 Khu vực & liên hệ (S34).
- **Bố cục bước 1**: avatar, ảnh bìa, tên hiển thị, bio (≤ 300 ký tự). **Bước 2**: danh sách gói đã thêm (thumb, tên, mô tả ngắn, giá), form thêm gói (tên, giá ₫, thời lượng, số ảnh hậu kỳ, giao sau mấy ngày), nút "Thêm gói này"; thanh dưới "Quay lại" + "Tiếp tục". `StepProgress` n/4.
- **Dữ liệu**: ghi `photographers/{uid}` và `services`; lưu nháp mỗi bước.
- **Trạng thái**: cần ≥ 1 gói mới sang bước 3; giá phải > 0 và nguyên; thời lượng chọn từ danh sách (1, 2, 3, 4, 6, 8 giờ); thoát giữa chừng hỏi lưu nháp; chưa xong thì hồ sơ không công khai và không đổi được vai trò.
- **Chuỗi**: `s24_title` "Hồ sơ nhiếp ảnh gia", `s24_bio` "Giới thiệu ngắn", `s24_services` "Gói dịch vụ", `s24_serviceHint` "Khách đặt theo gói. Cần ít nhất một gói để hồ sơ hiện trong Tìm thợ ảnh.", `s24_addService` "Thêm gói này".
- **Chấp nhận**: gói thêm xong hiện ngay ở danh sách; `startingPrice` cập nhật bởi Function; thoát và quay lại tiếp tục đúng bước.

---

## S34 · Thiết lập hồ sơ, bước 4/4 (khu vực và liên hệ)

- **Thông tin**: `/setup/4` · sub‑project 2 · Chưa có.
- **Mục đích**: nơi phục vụ và kênh khách được liên hệ.
- **Bố cục**: `StepProgress` 4/4; ô khu vực phục vụ (thành phố + bán kính km); ô SĐT (bắt buộc, `PhoneField`); ba thẻ công tắc: Gọi điện (dùng số trên), Zalo (dùng số trên hoặc nhập riêng), WhatsApp (nhập số quốc tế riêng); "Quay lại" + "Hoàn tất".
- **Dữ liệu**: một batch ghi `photographers/{uid}.serviceArea` (`city`, `radiusKm`) và `.contactChannels` (cờ công khai `call/zalo/whatsapp/acceptInquiries`, không có số), `photographers/{uid}/private/contact` (số, chỉ chủ đọc), và đặt `onboardingComplete = true`. Kênh chỉ bật được khi đã có số (rules kiểm bằng `existsAfter`).
- **Trạng thái**: cần ≥ 1 số hợp lệ và ≥ 1 kênh bật hoặc xác nhận "Chỉ nhận tin nhắn trong app"; WhatsApp bật mà trống → dùng số chính nếu hợp lệ quốc tế, không thì báo lỗi dưới ô. Công tắc "Chỉ nhận tin nhắn trong app" thay cho việc bật kênh ngoài: bật nó thì ba công tắc kia tắt, bật một kênh ngoài thì nó tắt. Lỗi hiện sau lần bấm "Hoàn tất" đầu tiên rồi cập nhật theo từng thay đổi.
- **Chuỗi**: `s34_title` "Khu vực và liên hệ", `s34_area` "Khu vực phục vụ", `s34_phone` "Số điện thoại · bắt buộc", `s34_channels` "Chọn kênh khách được dùng để liên hệ bạn.", `s34_finish` "Hoàn tất". Khoá arb: `setupContact*`, `setupChannel*`, `setupInAppOnly*` (camelCase, `lib/l10n/app_vi.arb`).
- **Phân tích**: `setup_complete{channels}`.
- **Chấp nhận**: sau "Hoàn tất", hồ sơ hiện công khai và vào được S19; chỉ các kênh bật xuất hiện ở S32.

---

## S38 · Kỹ năng, phần 1 (thể loại và mức độ)

- **Thông tin**: `/setup/3`, `/profile/skills` · sub‑project 2 · Chưa có.
- **Mục đích**: thu thập dữ liệu có cấu trúc cho dịch vụ gợi ý (spec chính 3e).
- **Điểm vào → ra**: bước 3/4 thiết lập hoặc Hồ sơ → "Kỹ năng"; "Ảnh minh chứng" → S40; "Tiếp tục" → S34 (hoặc lưu và quay lại nếu sửa).
- **Bố cục**: `StepProgress` 3/4; mô tả ngắn "Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó."; `CompletenessMeter` "Độ khớp hồ sơ 72%" + gợi ý việc kế tiếp; "Thể loại chụp" (chip nhiều chọn, "n / 6"); "Mức độ": một hàng `LevelSelector` (Cơ bản / Thành thạo / Chuyên sâu) cho mỗi thể loại đã chọn, nhãn "Chuyên sâu tối đa 3"; dòng "Chân dung: 2 / 3 ảnh minh chứng" + "Chỉnh"; thanh dưới "Quay lại" + "Tiếp tục".
- **Dữ liệu**: `skillsControllerProvider` giữ nháp; nháp tự lưu **trên máy** (`SharedPreferences`, khoá `skillsDraft.<uid>`) sau mỗi thay đổi, nên nháp được phép chưa hợp lệ; Firestore chỉ nhận kỹ năng hợp lệ khi bấm "Tiếp tục"/"Lưu thay đổi" (một lần ghi `photographers/{uid}.skills`, gộp với dữ liệu sẵn có). Danh mục là bản tích hợp (`builtInSkillCatalog`, khoá theo nhóm + id); đọc `taxonomy/skills` từ xa để sau. Độ khớp hồ sơ và bước kế tiếp do Function `onPhotographerWrite` tính (`skills.completeness`, `skills.completenessNext`, `skills.completenessNextAfter`); app chỉ hiện số đã lưu: chưa có số → "Chưa có điểm" + "Lưu để tính độ khớp"; nháp khác bản đã lưu → giữ số, gợi ý "Lưu để cập nhật độ khớp"; còn lại gợi ý theo `completenessNext`, kèm "để lên N%" lấy từ `completenessNextAfter`. Khi Function gỡ minh chứng không hợp lệ (`skills.evidenceRemovedAt` mới hơn mốc `skillsEvidenceSeen.<uid>` trên máy), lần mở S38 kế tiếp báo "Một số minh chứng không hợp lệ đã được gỡ" một lần. Không dùng snapshot.
- **Trạng thái**: chọn thể loại thứ 7 → báo "Tối đa 6 thể loại"; mức "Chuyên sâu" thứ 4 → báo, giữ mức cũ; mức 3 thiếu minh chứng → cảnh báo vàng ở dòng đó và chặn "Tiếp tục"; không chọn thể loại nào → nút vô hiệu; lỗi tải danh mục → dùng bản tích hợp sẵn.
- **Tương tác**: chọn thể loại tự thêm một hàng mức mặc định "Thành thạo"; bỏ chọn xoá hàng mức và minh chứng (hỏi xác nhận nếu đã có minh chứng); lưu nháp mỗi lần đổi. Thoát khi có thay đổi: sheet "Lưu bản nháp?" với "Giữ bản nháp" (giữ nháp trên máy) và nút đỏ "Bỏ thay đổi". Chế độ sửa: nút chính "Lưu thay đổi" chỉ bật khi khác bản đã lưu.
- **Chuỗi**: `s38_title` "Kỹ năng", `s38_intro` "Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.", `s38_fit` "Độ khớp hồ sơ", `s38_types` "Thể loại chụp", `s38_levels` "Mức độ", `s38_levelBasic` "Cơ bản", `s38_levelGood` "Thành thạo", `s38_levelExpert` "Chuyên sâu", `s38_maxExpert` "Chuyên sâu tối đa 3", `s38_evidence` "{name}: {n} / 3 ảnh minh chứng", `s38_tooMany` "Tối đa 6 thể loại". Khoá arb dạng camelCase: `skills*`, `completeness*` (`lib/l10n/app_vi.arb`).
- **Phân tích**: `skills_save{specialties, expert}`, `skills_step{n}`.
- **Chấp nhận**: không lưu quá giới hạn (kiểm cả client lẫn rules); `LevelSelector` truy cập được bằng bàn phím và đọc to "Chân dung, mức Chuyên sâu"; id lưu đúng theo `taxonomy`.

---

## S39 · Kỹ năng, phần 2 (cuộn xuống)

- **Thông tin**: cùng màn S38 · sub‑project 2 · Chưa có.
- **Mục đích**: phong cách, kỹ năng thêm, ngôn ngữ, loại khách phù hợp, kinh nghiệm.
- **Bố cục** (các section tiếp theo của S38): "Phong cách" (chip, ≤ 4); "Kỹ năng thêm" (chip, ≤ 8); "Ngôn ngữ" (chip, ≥ 1); "Khách phù hợp" (chip, ≤ 4, gồm "Khách nước ngoài", "Người ngại ống kính", "Gia đình có bé nhỏ"); ô "Kinh nghiệm" (số năm 0–50).
- **Trạng thái**: ngôn ngữ trống → lỗi "Chọn ít nhất 1 ngôn ngữ" khi bấm Tiếp tục và cuộn tới mục đó; vượt giới hạn → báo như S38.
- **Chuỗi**: `s39_styles` "Phong cách", `s39_extras` "Kỹ năng thêm", `s39_languages` "Ngôn ngữ", `s39_audiences` "Khách phù hợp", `s39_years` "Kinh nghiệm", `s39_needLang` "Chọn ít nhất 1 ngôn ngữ".
- **Chấp nhận**: mọi giá trị lưu thành id; "Khách nước ngoài" hay "Người ngại ống kính" là tín hiệu ghép khách, không phải kỹ thuật; số năm lưu ở `yearsExperience`.

---

## S40 · Minh chứng kỹ năng

- **Thông tin**: `/profile/skills/evidence?skill=…` (sheet mở từ dòng "Chỉnh" ở S38; link này mở S38 ở chế độ sửa rồi mở sheet cho thể loại `skill`) · sub‑project 2 · Chưa có.
- **Mục đích**: gắn 1–3 ảnh thật của mình vào một thể loại để thuật toán tin cậy hơn.
- **Bố cục**: tiêu đề "Minh chứng · {thể loại}" + "n / 3"; giải thích; lưới 3 cột ảnh portfolio (ô chọn có viền và dấu); nút "Xong".
- **Dữ liệu**: `posts (photographerId)` của chính mình; ghi `evidencePostIds` của thể loại. Chỉ bài có `authorId` là chính nhiếp ảnh gia (không gồm bài `real_shoot` của khách gắn vào trang), 30 bài mỗi trang. Vì lọc trên máy, một trang có thể ngắn hoặc rỗng dù còn bài: mỗi lần tải đọc tối đa 5 trang tới khi đủ 30 bài của mình hoặc hết; lưới ngắn không cuộn được thì tự tải trang tiếp.
- **Trạng thái**: chưa có bài nào (đã đọc hết) → empty "Đăng bài trước" + nút tới S21; trang tiếp lỗi → giữ ảnh đã hiện, dòng "Không tải thêm được. Thử lại" dưới lưới (chạm để tải lại trang đó; cuộn không tự thử lại); chọn quá 3 → âm báo và dòng báo ngay trong sheet (SnackBar sẽ bị modal che), bỏ chọn một ảnh để chọn thêm; mức "Chuyên sâu" cần ≥ 1 ảnh mới đóng sheet bằng "Xong".
- **Chuỗi**: `s40_title` "Minh chứng · {name}", `s40_body` "Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.", `s40_done` "Xong", `s40_empty` "Đăng bài trước".
- **Phân tích**: `skill_evidence_set{skillId, count}`.
- **Chấp nhận**: chỉ chọn được bài của chính mình; bài bị xoá thì gỡ khỏi minh chứng và hạ nhắc nhở ở S38.

---

## S43 · Thu nhập

- **Thông tin**: `/work/earnings` · NAG · sub‑project 5 · Chưa có.
- **Mục đích**: thấy tiền đang được giữ, sắp nhận và đã nhận; hiểu vì sao chưa nhận (tiền treo tới khi hoàn thành).
- **Điểm vào → ra**: ô "Đang giữ" ở S19, Hồ sơ → "Thu nhập". "Tài khoản nhận tiền" → S44; chạm một khoản → S09 hoặc S27.
- **Bố cục**: Back + "Thu nhập"; dải `EscrowNotice` "Tiền khách trả được giữ an toàn trên ứng dụng và chuyển cho bạn sau khi buổi chụp hoàn thành."; hàng `StatTile` ×3 **Đang giữ · Sắp nhận · Đã nhận** (cùng một hàng, nhãn một dòng); dải nhắc thêm tài khoản (khi chưa có); danh sách khoản theo thời gian: dòng gồm tên khách/sự kiện, ngày, số tiền, nhãn trạng thái tiền (`Đang giữ` · `Chờ chi trả` · `Đã chuyển 12/10` · `Đang khiếu nại`), nút chữ "Tài khoản nhận tiền".
- **Dữ liệu**: `earningsProvider` từ `payments` (escrow) và `payouts` của chính nhiếp ảnh gia: Đang giữ = tổng khoản `held`; Sắp nhận = `released` chưa vào lô đã trả và lô `pending/processing`; Đã nhận = tổng lô `paid`. Phân trang theo tháng.
- **Trạng thái**: chưa có khoản nào → empty "Chưa có khoản thu nào" nêu cách có khoản đầu; khoản `disputed` hiện biểu tượng và lý do tạm giữ; lô `failed` → dải "Chuyển khoản lỗi, kiểm tra tài khoản" (→ S44); offline đọc cache.
- **Chuỗi**: `s43_title` "Thu nhập", `s43_notice` "Tiền khách trả được giữ an toàn trên ứng dụng và chuyển cho bạn sau khi buổi chụp hoàn thành.", `s43_held` "Đang giữ", `s43_soon` "Sắp nhận", `s43_received` "Đã nhận", `s43_stateHeld` "Đang giữ", `s43_stateReleased` "Chờ chi trả", `s43_statePaid` "Đã chuyển {date}", `s43_stateDispute` "Đang khiếu nại", `s43_addAccount` "Thêm tài khoản để nhận tiền".
- **Phân tích**: `earnings_open`, `earnings_item_open{state}`.
- **Chấp nhận**: các số khớp sổ cái; không bao giờ hiện số tài khoản đầy đủ; ba ô cùng một hàng ở 320dp và chữ 1,3×.

---

## S44 · Tài khoản nhận tiền

- **Thông tin**: `/work/earnings/account` · NAG · sub‑project 5 · Chưa có.
- **Mục đích**: khai tài khoản ngân hàng để nhận chi trả.
- **Bố cục**: Back + "Tài khoản nhận tiền"; chọn ngân hàng (tìm theo tên, danh mục ngân hàng VN có mã); ô số tài khoản (số, 6–20 chữ số); ô tên chủ tài khoản (viết hoa không dấu theo ngân hàng, tự điền nếu có tra cứu); ghi chú "Tên chủ tài khoản phải trùng tên bạn đã xác minh"; nút "Lưu tài khoản".
- **Dữ liệu**: ghi `payout_accounts` (số tài khoản mã hoá, chỉ hiện 4 số cuối); mỗi nhiếp ảnh gia một tài khoản đang bật.
- **Trạng thái**: tài khoản đã có → hiện che (`•••• 3456`) và "Đổi tài khoản"; đổi cần xác nhận lại (mật khẩu hoặc OTP khi có); lỗi định dạng dưới ô; lưu lỗi → SnackBar, giữ dữ liệu.
- **Chuỗi**: `s44_title` "Tài khoản nhận tiền", `s44_bank` "Ngân hàng", `s44_number` "Số tài khoản", `s44_holder` "Tên chủ tài khoản", `s44_save` "Lưu tài khoản", `s44_hint` "Tên chủ tài khoản phải trùng tên bạn đã xác minh".
- **Phân tích**: `payout_account_save`.
- **Chấp nhận**: số tài khoản không có trong log và phân tích; chỉ chủ đọc/ghi; thay tài khoản không ảnh hưởng khoản đã chuyển.
