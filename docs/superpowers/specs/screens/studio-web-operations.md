# S28 · Studio trên web: vận hành (#167)

- **Issue:** #167, epic #83. **Ngày:** 2026-10-08. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` ("spec dashboard": BFF, phiên, `StudioShell`, thành phần), `../2026-10-06-studio-members-design.md` ("spec studio"), plan `../../plans/2026-10-07-s26-studio-members.md` (#136, chưa merge; "plan S26"), `../2026-10-06-delivery-preview-unlock-design.md` và plan `../../plans/2026-10-07-s05-delivery-two-layer.md` (#152; "plan bàn giao"), plan `../../plans/2026-10-07-s27-studio-recruiting.md` (#151; cộng tác viên).
- **Mock:** `docs/design/dashboard-mock.html#S28.01` … `#S28.05`.
- **Ai dùng:** chủ studio (`providerType = studio`), qua `requireStudioOwner()` (spec dashboard §2.2). Không cần TOTP.

## 0. Quyết định

| # | Quyết định | Lý do |
|---|---|---|
| W1 | Web **dùng lại đúng callable của app** (`assignBooking`, `assignmentOptions`, `declineAssigneeChange`, `markShot`, `submitDelivery`, `inviteMember`, `respondJoinRequest`, `removeMember`, `cancelInvite`, `searchPhotographersToInvite`…). Không có luật nào riêng cho web; callable tự kiểm người gọi là chủ studio. | spec dashboard D2 |
| W2 | Thao tác của studio **không ghi `audit_log`** (đó là nhật ký của staff); lịch sử nằm ở dữ liệu sẵn có (`assignments[]`, `studio_members`, vòng bàn giao). | |
| W3 | **Lịch** là lưới tuần: mỗi hàng là một thành viên (và cộng tác viên đang cộng tác), thêm hàng "Chưa giao thợ" ở trên cùng. Giao thợ bằng cách bấm booking rồi chọn người; **chưa có kéo thả** ở đợt này. | đơn giản, đủ dùng |
| W4 | **Nộp bàn giao từ máy tính:** kéo thả nhiều ảnh, trình duyệt nén từng ảnh đúng quy định `deliverySample` của #147 (cạnh dài 1600 px, JPEG q75, bỏ EXIF, ≤ 2 MiB) trước khi tải; tải lên bằng URL ký do callable cấp (BFF không có quyền Storage); trigger watermark của plan bàn giao chạy như khi tải từ app. Ảnh gốc vẫn là **link** (Google Drive…), không tải ảnh gốc lên nền tảng. | spec bàn giao, chi phí Storage |
| W5 | **Tuyển thợ (S27) chưa có trên web** ở đợt này; tab Cộng tác viên ở S28.05 chỉ đọc, kèm link "Mở trong app". Tin nhắn với khách thuộc #169. | thu hẹp phạm vi |

## 1. Màn và mã (use case mới S28)

| Mã | Màn | Route |
|---|---|---|
| S28.01 | Tổng quan studio: việc cần làm hôm nay | `/studio` |
| S28.02 | Lịch tuần theo thành viên | `/studio/calendar` |
| S28.03 | Booking: danh sách và chi tiết (giao thợ, đổi thợ, yêu cầu đổi của khách, đã chụp xong) | `/studio/bookings`, `/studio/bookings/:id` |
| S28.04 | Nộp bàn giao | `/studio/bookings/:id/delivery` |
| S28.05 | Thành viên: thành viên, lời mời, yêu cầu gia nhập, mời thợ, cộng tác viên | `/studio/members` |

Thanh bên `StudioShell` nhóm "Vận hành": Tổng quan · Lịch · Booking · Bàn giao (lọc booking cần bàn giao) · Thành viên. Số đỏ: booking quá hạn giao thợ, yêu cầu đổi sắp hết 6 giờ, bàn giao trễ hạn.

## 2. S28.01 · Tổng quan studio

- **Mục đích:** biết việc phải làm ngay trong ngày.
- **Bố cục:** bốn thẻ việc cần làm (mỗi thẻ là link sang danh sách đã lọc):
  - **Chờ giao thợ:** số booking `assignStatus = unassigned`, cái gần hạn nhất ("hạn 14:00 mai"); đỏ khi có cái quá `assignDeadline`.
  - **Khách xin đổi thợ:** `changeRequest.status = pending`, thời gian còn lại tới `respondBy`; đỏ khi còn dưới 1 giờ.
  - **Cần bàn giao:** booking `shot` hoặc `revision_requested`, hạn giao ảnh (`shotAt + deliveryDays`); đỏ khi trễ.
  - **Lời mời / yêu cầu gia nhập** đang chờ.
- Bên dưới: **Buổi chụp hôm nay** (giờ, khách, gói, thợ được giao, địa điểm; booking chưa giao thợ tô đỏ) và **7 ngày tới** (số buổi theo ngày, so với số thành viên rảnh: "4/5 thợ").
- **Dữ liệu:** booking của studio (`photographerId = studioId`) theo `(status, startAt)` trong 7 ngày; `studio_members` đang chờ; `studio_day_load` 7 ngày.
- **Chấp nhận:** booking quá hạn giao thợ hiện đỏ ở cả thẻ và danh sách hôm nay; bấm thẻ mở S28.03 đúng bộ lọc.

## 3. S28.02 · Lịch

- **Bố cục:** thanh chọn tuần (← tuần này →, "Hôm nay"). Lưới: cột là 7 ngày, hàng là "Chưa giao thợ", từng thành viên (avatar, tên), từng cộng tác viên đang cộng tác (nhãn "CTV"). Ô chứa khối booking (giờ, tên khách, gói), khối booking cá nhân của thành viên (xám, chỉ ghi "Bận · việc riêng", không lộ khách của thợ), ngày nghỉ (`off`, sọc). Đầu mỗi cột: "{n} booking · {k} thợ rảnh"; ngày `full` có chip "Đủ chỗ".
- **Tương tác:** bấm khối booking studio mở `DetailPane` của S28.03 ngay trên lịch. Bấm ô trống không làm gì (studio không tạo booking hộ khách).
- **Dữ liệu:** booking của studio trong tuần; `availability/{memberId}/days/{day}` của thành viên trong tuần (`state`, không đọc booking cá nhân của thợ); `studio_day_load` của tuần. Mỗi lần đổi tuần: 1 truy vấn booking + 7 × số thành viên doc ngày (studio 10 thợ: 70 lượt đọc).
- **Chấp nhận:** booking cá nhân của thành viên không lộ tên khách hay giá; booking chưa giao thợ nằm ở hàng trên cùng.

## 4. S28.03 · Booking

- **Danh sách:** tab **Chờ giao thợ** · **Sắp tới** · **Đã chụp, chờ bàn giao** · **Đang sửa** · **Đã xong** · **Đã huỷ**. Bảng: ngày giờ, khách, gói, giá, thợ được giao (hoặc chip "Chưa giao · hạn …"), trạng thái, cờ (yêu cầu đổi thợ, trả việc, giao trễ).
- **Chi tiết** (`DetailPane` rộng 440 px, hoặc trang riêng khi mở bằng link):
  - Booking: mã, khách (tên, số booking trước với studio), gói và điều khoản (`terms`: số ảnh, ngày giao, vòng sửa), địa điểm, giá và hai mốc tiền (đang giữ / đã chuyển).
  - **Thợ chụp:** người được giao, lịch sử giao (`assignments[]`), "Trả việc" của thợ nếu có (lý do).
  - **Yêu cầu đổi thợ** của khách (nếu `pending`): ghi chú của khách, còn {x} giờ; nút chính "Giao người khác" (mở hộp giao thợ) và nút đỏ "Từ chối…" (lý do 1–300 → `declineAssigneeChange`). Hộp từ chối nói rõ: "Khách được huỷ và hoàn 100%".
  - Liên hệ khách: hiện như app (mở sau khi thanh toán, spec chính §3b); không có trên web khi chưa thanh toán.
- **Hộp giao thợ** (bản web của S26.04): hạn giao ("còn 20 giờ"); danh sách từ `assignmentOptions` (thành viên và cộng tác viên: % cà chua, "Rảnh" / "Bận 15:00–18:00" / "Chưa xác minh", mờ khi không chọn được); chọn cộng tác viên thì thêm ô thù lao (`agreedFee`, plan S27); nút chính "Giao cho {tên}". Đổi thợ khi còn dưới 24 giờ: hộp cảnh báo "Khách được huỷ và hoàn 100%" trước khi xác nhận.
- **Nút theo trạng thái** (một nút chính mỗi lúc): chưa giao → "Giao thợ"; đã qua giờ kết thúc buổi chụp → "Đã chụp xong" (`markShot`, plan bàn giao); `shot` / `revision_requested` → "Nộp bàn giao" (sang S28.04); `delivered` có yêu cầu thêm vòng → "Trả lời yêu cầu thêm vòng" (`answerExtraRound`).
- **Chấp nhận:** mọi thao tác chạy đúng callable của app và cho cùng kết quả; lỗi `not_eligible`, `member_busy`, `not_accepting_orders` hiện câu tiếng Việt trong hộp.

## 5. S28.04 · Nộp bàn giao

- **Bố cục:** tiêu đề "Bàn giao · {khách} · {ngày chụp}", vòng hiện tại ("Vòng 1" hoặc "Vòng sửa 2/3"), hạn giao.
  1. **Ảnh mẫu (3–20):** vùng kéo thả + nút "Chọn ảnh". Mỗi ảnh một ô: ảnh thu nhỏ, tiến trình nén → tải → đóng dấu (trạng thái lấy từ `bookings/{id}/deliverySamples/{fileId}`: `ready` / `failed`), nút xoá. Kéo để đổi thứ tự.
  2. **Link ảnh gốc:** ô URL (kiểm như app: https, độ dài), dòng "Khách chỉ mở được link sau khi duyệt bàn giao".
  3. **Số ảnh bàn giao** (`photoCount`), **ghi chú cho khách** (tuỳ chọn).
  4. Nút chính **"Gửi bàn giao"** (bật khi đủ 3 ảnh `ready` và có link) → `submitDelivery({bookingId, sampleIds, link, photoCount, note})`.
- **Tải lên (W4):**
  - Nén trong trình duyệt: `createImageBitmap` → canvas cạnh dài 1600 px → `toBlob('image/jpeg', 0.75)`; ảnh vẫn trên 2 MiB thì giảm chất lượng từng bước 0,05 tới 0,5, vẫn quá thì báo lỗi ảnh đó. Re-encode bỏ EXIF. Chạy trong Web Worker để trang không đứng.
  - Callable mới `createDeliveryUploadUrls({bookingId, files: [{fileId, size}]})` (chủ studio của booking, trạng thái `shot` / `revision_requested`, tối đa 20 tệp mỗi lần, `size ≤ 2 MiB`) trả URL ký V4 `PUT` sống 15 phút cho `deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`, ràng `Content-Type: image/jpeg` và `x-goog-content-length-range: 0,2097152`. URL ký bỏ qua Storage rules, nên ràng buộc nằm ở chữ ký; trigger watermark vẫn đọc lại và mã hoá lại ảnh (plan bàn giao Decision 16: không tin ảnh từ client).
  - Tải song song tối đa 4 ảnh; mất mạng thì ảnh đó báo "Thử lại".
- **Trạng thái:** ảnh `failed` ("Ảnh không đọc được, chọn ảnh khác"); hết hạn URL (tự xin URL mới một lần); `not_ready` khi gửi (còn ảnh chưa đóng dấu xong).
- **Chấp nhận:** 20 ảnh 8 MB từ máy ảnh được nén và tải xong không treo trang; khách nhận bàn giao giống hệt khi studio nộp từ app; không tệp nào lên Storage quá 2 MiB.

## 6. S28.05 · Thành viên

- **Bố cục:** dòng "{n}/{max} thợ · còn {k} thao tác hôm nay" (luật spec studio §3.3); nút chính **"Mời thợ"**.
  - Tab **Thành viên:** bảng tên, % cà chua cá nhân, việc đang giao, thành viên từ; menu "…" → "Bỏ khỏi studio…" (nút đỏ trong hộp; bị khoá thì hộp nói lý do, ví dụ "Còn 2 buổi chụp được giao").
  - Tab **Đang chờ:** lời mời đã gửi (hạn còn lại, "Huỷ lời mời") và yêu cầu gia nhập ("Duyệt", "Từ chối").
  - Tab **Cộng tác viên** (W5): đang cộng tác, số job, job chưa trả công; chỉ đọc, link "Mở trong app".
- **Hộp "Mời thợ"** (bản web của S26.02): ô tìm tên (≥ 2 ký tự, `searchPhotographersToInvite`), mỗi kết quả: avatar, tên, %, khu vực, nút viền "Mời"; mờ "Đang ở {Studio}" hoặc "Mời được từ {ngày}"; dòng "Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ".
- **Lỗi:** `studio_full`, `rate_limited`, `membership_conflict`, `cooldown`, `member_busy` → câu tiếng Việt như app.
- **Chấp nhận:** số thao tác còn lại giảm sau mỗi lần mời / huỷ / duyệt / bỏ; studio chưa xác minh không mời quá 3.

## 7. Backend

- Không có callable mới ngoài `createDeliveryUploadUrls` (W4). Callable của #136, #152, #151 dùng nguyên.
- Lớp đọc studio (`server/read/studio/*`): mọi truy vấn lọc theo `photographerId = studioId` (hoặc `studioId`) lấy từ phiên, không nhận id studio từ trình duyệt.
- Service account của App Hosting vẫn chỉ đọc Firestore (spec dashboard §9); URL ký do Functions cấp.
- Index: `bookings (photographerId, status, startAt)`, `bookings (photographerId, assignStatus, assignDeadline)`, `bookings (photographerId, changeRequest.status, changeRequest.respondBy)`.

## 8. Chi phí

- Studio mở tổng quan và lịch vài lần mỗi ngày: khoảng 100–200 lượt đọc mỗi studio mỗi ngày; 50 studio ≈ 10.000 lượt/ngày, trong hạn mức.
- Ảnh mẫu: tối đa 20 × 2 MiB mỗi vòng, như từ app (đã tính trong plan bàn giao). URL ký: một callable mỗi lần chọn ảnh.
- Cộng thêm **~$0** ở mức 1.000 người dùng; ở mức 10.000 (khoảng 300 studio dùng web): khoảng 60.000 lượt đọc/ngày, vượt hạn mức chừng 10.000 → **< $0,2/tháng**.

## 9. Kiểm thử

- **Dashboard (Vitest):** lớp đọc studio không nhận `studioId` từ request; lịch che booking cá nhân của thành viên; nén ảnh (ảnh 6000×4000 → cạnh dài 1600, JPEG, không có EXIF, ≤ 2 MiB); thứ tự nút chính theo trạng thái booking.
- **Functions:** `createDeliveryUploadUrls` từ chối người không phải chủ studio, booking sai trạng thái, `size > 2 MiB`, quá 20 tệp; URL ký có giới hạn độ dài.
- **Playwright trên emulator:** chủ studio seed đăng nhập → giao thợ cho booking chờ giao → booking có `assigneeId` của thợ đó; nộp bàn giao 3 ảnh → booking `delivered`.

## 10. Phụ thuộc

- Cứng: #162 (nền tảng, `StudioShell`), #136 (S26), #152 (bàn giao).
- Mềm: #151 (cộng tác viên trong lịch và hộp giao thợ; chưa có thì chỉ thành viên), #147 (quy định nén `deliverySample`).

## 11. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Kéo thả để giao thợ trên lịch? | Chưa; bấm rồi chọn |
| Q2 | Tải ảnh gốc lên nền tảng thay cho link? | Không; vẫn là link (spec bàn giao) |
| Q3 | Tuyển thợ (S27) trên web? | Chưa; dùng app |
| Q4 | Studio có nhiều người quản lý? | Không (spec studio T12) |
