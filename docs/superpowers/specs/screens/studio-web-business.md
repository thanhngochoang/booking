# S28 · Studio trên web: kinh doanh (#169)

- **Issue:** #169, epic #83. **Ngày:** 2026-10-09. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` ("spec dashboard"), `./studio-web-operations.md` (#167, W1–W5, `StudioShell`), spec 10-05 §5 và plan `../../plans/2026-10-07-s15-s16-job-posts.md` (#139; việc đăng, báo giá), plan `../../plans/2026-10-07-s06-work-earnings.md` (#134, đã merge; thu nhập, chi trả), spec cà chua/gạch 10-06 và spec studio §6 (đánh giá hai bên), plan `../../plans/2026-10-07-s07-chat.md` (#131, đã merge; hội thoại).
- **Mock:** `docs/design/dashboard-mock.html#S28.06` … `#S28.10`.
- **Ai dùng:** chủ studio (`requireStudioOwner`). Không cần TOTP.

## 0. Quyết định

| # | Quyết định | Lý do |
|---|---|---|
| B1 | Như #167 W1: web gọi đúng callable của app, không có luật riêng. Chỗ nào app đang **ghi Firestore trực tiếp** (gói dịch vụ: `photographers/{uid}/services`) thì thêm callable mỏng dùng chung luật kiểm của rules và domain (`saveServicePackage`, `hideServicePackage`), vì trình duyệt không ghi Firestore (spec dashboard D2). | D2 |
| B2 | **Đổi tài khoản nhận tiền vẫn làm trong app** (cần OTP và tra tên, plan S06 Decision 8–12); web chỉ hiện tài khoản (•••• 4 số) và link "Đổi trong app". | an toàn tài khoản tiền |
| B3 | **Trả lời đánh giá chưa có** (app cũng chưa có); web chỉ xem. Ghi là câu hỏi mở. | chưa có trong spec nào |
| B4 | Tin nhắn trên web: chữ và ảnh. Ảnh tải bằng URL ký từ callable mới `createChatImageUploadUrl` vào đúng đường dẫn app dùng (`chats/{chatId}/{uid}/{clientId}.jpg`), nén trong trình duyệt theo quy định ảnh chat của #147; luật hỏi trước, chặn và đóng hội thoại giữ nguyên (`sendMessage`). | D2, #131 |
| B5 | Thu nhập có nút **"Tải CSV theo tháng"** (route handler của BFF dựng tệp từ lớp đọc); không có số tài khoản trong tệp. | studio cần cho kế toán |

## 1. Màn và mã

| Mã | Màn | Route |
|---|---|---|
| S28.06 | Gói dịch vụ: danh sách, thêm, sửa, ẩn | `/studio/packages` |
| S28.07 | Báo giá: việc đang tuyển phù hợp, báo giá của tôi, gửi báo giá | `/studio/quotes` |
| S28.08 | Thu nhập và chi trả | `/studio/earnings` |
| S28.09 | Đánh giá của studio | `/studio/reviews` |
| S28.10 | Tin nhắn | `/studio/messages`, `/studio/messages/:chatId` |

Thanh bên `StudioShell` nhóm "Kinh doanh": Gói dịch vụ · Báo giá · Thu nhập · Đánh giá · Tin nhắn (số tin chưa đọc).

## 2. S28.06 · Gói dịch vụ

- **Bố cục:** bảng gói (tên, giá, thời lượng, số ảnh chỉnh, ngày giao, số vòng sửa (#146), trạng thái Đang bán / Đã ẩn, số booking 90 ngày); nút chính "Thêm gói". Bấm dòng mở hộp sửa.
- **Hộp thêm / sửa:** các trường như S08.01 (thời lượng chọn 1, 2, 3, 4, 6, 8 giờ; giá nguyên VND; số ảnh chỉnh, ngày giao, số vòng sửa tuỳ chọn). "Ẩn gói" là nút phụ trong hộp (không xoá; booking cũ giữ bản chụp điều khoản).
- **Callable mới:** `saveServicePackage({serviceId?, input})`, `hideServicePackage({serviceId})`: chủ hồ sơ, kiểm như `firestore.rules` hiện tại cho `services` (đưa luật kiểm vào domain `validateServicePackage`, rules giữ nguyên cho app).
- **Chấp nhận:** gói sửa trên web hiện đúng trên hồ sơ studio trong app; booking đã tạo không đổi điều khoản.

## 3. S28.07 · Báo giá

Luật của #139: ai thấy việc, một báo giá mỗi (việc, thợ), giới hạn số báo giá, lọc liên hệ trong nội dung, việc "linh hoạt" thì thợ đề xuất ngày.

- Tab **Việc đang tuyển** (bản web của S16.01–S16.02): việc phù hợp với studio (khu vực, thể loại, ngân sách), sắp theo độ phù hợp; mỗi dòng: tiêu đề, khu vực, ngày (hoặc khoảng ngày), ngân sách, số báo giá đã có, hạn nhận báo giá. Bấm mở chi tiết việc và **hộp gửi báo giá** (bản web của S16.03): giá, gói tham chiếu (tuỳ chọn), ngày giờ đề xuất khi việc linh hoạt, số ảnh, ngày giao, lời nhắn (bộ lọc liên hệ báo lỗi ngay dưới ô, `details.field`) → `submitQuote`.
- Tab **Báo giá của tôi:** trạng thái (`submitted`, `withdrawn`, `accepted`, `not_selected`, `declined`), "Rút báo giá…" khi còn `submitted`. Báo giá được chọn mở booking ở S28.03.
- **Chấp nhận:** lỗi `day_taken`, `limit_exceeded`, `contact_blocked` (tên mã theo #139) hiện đúng chỗ; báo giá gửi từ web khách thấy như từ app.

## 4. S28.08 · Thu nhập và chi trả

- **Bố cục:** ba ô như S06.05: Đang giữ · Chờ chi trả · Đã nhận (theo tháng chọn). Bảng khoản theo booking (ngày, khách, gói, số tiền gộp, mốc đã chuyển "1/2", trạng thái: Đang giữ / Chờ chi trả / Đã chuyển / Đang khiếu nại); bung một dòng thấy chi tiết mốc và thực nhận (studio không bị khấu trừ thuế, #134 Decision 1). Bảng **lần chi trả** (ngày, số tiền, trạng thái, mã tham chiếu).
- Dòng "Tài khoản nhận tiền · {ngân hàng} •••• {4 số}" và link "Đổi trong app" (B2); chưa có tài khoản thì banner "Thêm tài khoản trong app để nhận {số tiền}".
- Nút phụ **"Tải CSV tháng này"** (B5): cột ngày chụp, mã booking, khách, gói, gộp, phí, thực nhận, trạng thái, ngày chi.
- **Dữ liệu:** `earnings/{uid}/items`, `payouts` theo `payeeId`, `payoutAccounts/{uid}` (trường đã che).
- **Chấp nhận:** tổng ba ô bằng tổng bảng; CSV mở đúng dấu trong Excel (UTF-8 có BOM); không có số tài khoản ở bất kỳ đâu.

## 5. S28.09 · Đánh giá

- **Bố cục:** đầu trang: % cà chua của studio, số lượt, phân bố lý do gạch (`slow_response`, `price_changed`, `late_assignment`, `poor_assignment`, `other`). Danh sách đánh giá studio (`reviews` `subjectType = studio`, `subjectId = studioId`): cà chua / gạch, lý do, nhận xét, khách, ngày, tag "Chụp bởi {thợ}". Lọc: chỉ gạch, theo thợ.
- Bên phải: % cà chua cá nhân của từng thành viên từ booking studio (đánh giá thợ có `viaStudioId`), để studio biết ai được khen hay bị chê.
- Không có nút trả lời (B3).

## 6. S28.10 · Tin nhắn

- **Bố cục:** như S23.06 nhưng cho studio: danh sách hội thoại (khách hỏi trước, hội thoại booking; chưa đọc lên đầu, chip "Hỏi trước" / booking), hội thoại đang mở (tin, ảnh, thẻ ngữ cảnh booking như S07.01), ô trả lời (Enter gửi), nút đính ảnh.
- Luật giữ nguyên #131: hỏi trước tối đa 3 tin chưa được trả lời, đóng sau 14 ngày, booking xong 7 ngày thì chỉ đọc, bị chặn thì đóng; liên hệ ngoài app chỉ hiện sau khi thanh toán (spec chính §3b).
- **Làm mới:** như S23.06 (danh sách 30 giây, hội thoại đang mở 10 giây chỉ lấy tin mới). Đánh dấu đã đọc qua callable có sẵn của #131 (nếu app ghi trực tiếp thì thêm `markChatRead` mỏng, B1).
- **Chấp nhận:** tin gửi từ web hiện ngay trên app của khách; ảnh qua URL ký không lớn hơn giới hạn ảnh chat của #147; hội thoại đã đóng không gửi được.

## 7. Backend

- Callable mới: `saveServicePackage`, `hideServicePackage` (B1), `createChatImageUploadUrl({chatId, clientId, size})` (B4; thành viên hội thoại, hội thoại còn mở, `size` ≤ giới hạn ảnh chat, URL `PUT` 15 phút), có thể `markChatRead` (B1). Callable khác dùng nguyên: `submitQuote`, `withdrawQuote` (#139), `sendMessage` (#131).
- Lớp đọc studio lọc theo uid trong phiên (như #167 §7).
- Route handler `GET /studio/earnings/export?month=YYYY-MM` (BFF, chỉ chủ studio) trả CSV; không ghi gì.
- Index: `reviews (subjectType, subjectId, createdAt)`, `reviews (viaStudioId, createdAt)`, `earnings items (dueAt)` theo nhu cầu bảng; `jobs` dùng truy vấn của #139.

## 8. Chi phí

Mỗi studio mở các màn kinh doanh vài lần mỗi ngày: thu nhập (≤ 100 doc/tháng), đánh giá (trang 50), báo giá (truy vấn việc của #139), tin nhắn (như S23.06). Khoảng 100–300 lượt đọc mỗi studio mỗi ngày; cộng thêm **< $0,3/tháng** ở mức 10.000 người dùng, **~$0** ở mức 1.000. Chạy trên emulator cho tới khi bật Blaze.

## 9. Kiểm thử

- **Domain:** `validateServicePackage` cho đúng các trường hợp rules đang chặn (thời lượng ngoài danh sách, giá ≤ 0, tên rỗng).
- **Functions:** `saveServicePackage` từ người khác → `permission_denied`; `createChatImageUploadUrl` với hội thoại đã đóng → `not_eligible`, `size` quá giới hạn → `invalid_argument`.
- **Dashboard:** CSV đúng cột, có BOM, không có số tài khoản; ba ô thu nhập bằng tổng bảng; báo giá bị lọc liên hệ hiện lỗi dưới ô lời nhắn.
- **Playwright:** chủ studio sửa giá một gói → hồ sơ (dữ liệu) có giá mới; gửi một tin trả lời hỏi trước → khách (dữ liệu) có tin mới.

## 10. Phụ thuộc

- Cứng: #162, #167 (`StudioShell`, lớp đọc studio). Thu nhập, đánh giá, tin nhắn, gói dịch vụ làm được ngay (#134, #130, #131 đã merge). Báo giá cần #139. Tag "Chụp bởi" và % theo thành viên cần #136.

## 11. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Studio trả lời công khai một đánh giá? | Chưa có (cả app); cần spec riêng |
| Q2 | Đổi tài khoản nhận tiền trên web? | Không; làm trong app (OTP) |
| Q3 | Studio chia thu nhập cho thành viên trong app? | Không (spec studio T11) |
