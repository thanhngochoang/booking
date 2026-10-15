# Mô hình dữ liệu độc lập nền tảng (không phụ thuộc Firebase)

Mục tiêu: sau này có thể chuyển toàn bộ dữ liệu và logic ra hệ thống riêng (máy chủ API + cơ sở dữ liệu quan hệ) mà **không đổi tên miền nghiệp vụ, không đổi id, không đổi hành vi ứng dụng**. Firebase chỉ là một *bộ chuyển đổi* (adapter) cắm vào, không phải nơi định nghĩa mô hình.

Tài liệu gồm ba phần:

| Tệp | Nội dung |
|-----|----------|
| `README.md` (tệp này) | Nguyên tắc, quy chuẩn đặt tên và kiểu dữ liệu, ranh giới dịch vụ, ma trận phân quyền, kế hoạch di trú, tiêu chí chấp nhận |
| [domain-model.md](domain-model.md) | Thực thể, đối tượng giá trị, quan hệ (ERD), danh mục enum, máy trạng thái |
| [relational-schema.md](relational-schema.md) | Bảng, cột, khoá, ràng buộc, chỉ mục; ánh xạ từ Firestore sang bảng |

Liên quan: spec chính `../2026-10-01-remaining-screens.md` (mục 3f tóm tắt yêu cầu), spec gốc `../2026-09-30-photography-marketplace-design.md` mục 5 (mô hình Firestore hiện hành).

---

## 1. Nguyên tắc

1. **Miền nghiệp vụ không biết Firebase.** Thực thể, giá trị và quy tắc nằm trong mã Dart/TypeScript thuần, không `import` gì của Firebase. Không dùng `Timestamp`, `DocumentReference`, `GeoPoint`, `FieldValue` ngoài lớp adapter.
2. **Một nguồn sự thật cho lược đồ: mô hình quan hệ.** Firestore là cách lưu *hiện tại*; mô hình quan hệ ở [relational-schema.md](relational-schema.md) là *chuẩn đích*. Mỗi tập hợp (collection) Firestore có bảng tương ứng và bảng ánh xạ cột ↔ trường.
3. **Cổng và bộ chuyển đổi (ports & adapters).** Mọi thứ ngoài miền (đăng nhập, lưu trữ, đẩy thông báo, thời gian thực, thanh toán, địa lý, gợi ý, tìm kiếm) là một *cổng* (interface). Firebase là một cài đặt; hệ thống riêng là cài đặt khác. Ứng dụng chỉ phụ thuộc cổng.
4. **Logic nghiệp vụ nằm ngoài nơi chạy.** Cloud Functions chỉ là "máy chủ chạy tạm" cho các *use case* (mục 5). Mã use case viết dạng module thuần, mỏng ở phần kích hoạt (trigger/HTTP), để chuyển sang Node/Go/… mà không viết lại quy tắc.
5. **Id ổn định, không đổi khi di trú.** Mọi thực thể có id dạng chuỗi bất biến. Di trú giữ nguyên id nên link sâu `/p/{id}`, `/u/{id}`, `/b/{id}`, `/e/{id}`, mã vé và lịch sử không hỏng.
6. **Quyền truy cập là chính sách có tài liệu, không chỉ là Firestore Rules.** Ma trận phân quyền (mục 4) mô tả ai đọc/ghi gì; Rules chỉ là một cách thực thi.
7. **Dữ liệu nhạy cảm tách bảng riêng** (số điện thoại, email, token thiết bị, dữ liệu thanh toán thô) để áp dụng quyền và xoá/ẩn danh dễ dàng theo Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân.
8. **Có thể xuất và nhập đầy đủ.** Từng bảng xuất được ra NDJSON/CSV có lược đồ, kiểm tra được bằng checksum; nhập lại vào hệ thống mới cho cùng kết quả.

## 2. Quy chuẩn kiểu dữ liệu và đặt tên

### 2.1 Định danh

| Mục | Quy chuẩn |
|-----|-----------|
| Kiểu | Chuỗi bất biến, `text`, tối đa 64 ký tự, ký tự `[A-Za-z0-9_-]`. Trong miền là kiểu `Id<T>` bọc chuỗi (tránh nhầm id giữa thực thể) |
| Sinh | Id mới dùng **ULID** (26 ký tự, sắp theo thời gian, sinh được ở máy khách hoặc máy chủ). Id có sẵn của Firestore (20 ký tự) và `uid` Firebase **giữ nguyên**, không đổi |
| Khoá tự nhiên | `ticket_code` (vé), `request_id` (gợi ý) là mã nghiệp vụ, tách khỏi khoá chính |
| Người dùng | `users.id` = `uid` Firebase hiện tại. Bảng `auth_identities` ánh xạ `(provider, subject) → user_id` để đổi nhà cung cấp đăng nhập mà không đổi `users.id` |
| Khoá ghép | Thực thể liên kết dùng khoá ghép thay id sinh ra (ví dụ `likes(user_id, post_id)`), tương ứng id `uid_postId` của Firestore |

### 2.2 Thời gian

| Loại | Lưu | Ghi chú |
|------|-----|---------|
| Thời điểm | `timestamptz` (UTC); miền dùng `Instant` | Dây (JSON): ISO‑8601 UTC `2026-10-12T08:30:00Z` |
| Ngày trong lịch | `date` (không múi giờ), theo ngày địa phương Asia/Ho_Chi_Minh | `2026-10-12`; miền `LocalDate` |
| Giờ trong ngày | `time` | `15:30`; miền `LocalTime`; kèm `date` để thành thời điểm bằng múi giờ `Asia/Ho_Chi_Minh` |
| Dấu vết | Mọi bảng có `created_at`, `updated_at`, bảng cần xoá mềm có `deleted_at` | Máy chủ đặt, không tin đồng hồ máy khách |
| Cấm | Không lưu thời điểm dạng chuỗi tự do hay mili‑giây số nguyên không rõ đơn vị | |

### 2.3 Tiền tệ

`bigint` đơn vị nhỏ nhất của tiền (VNĐ không có phần thập phân nên là số đồng), kèm `currency char(3)` mặc định `'VND'`. Miền dùng `Money(amount, currency)`. Không dùng số thực. Khách trả **100% khi đặt** (`UPFRONT_PERCENT = 100`, từ #129): số tiền thanh toán là đúng giá gói, nên không còn phép chia và không còn phần dư. Phép chia theo phần trăm nếu có (hoa hồng, hoàn tiền theo chính sách huỷ) làm tròn xuống đến đồng. Cách tính cọc cũ (`deposit = floor(price × 0,30)`, `remaining = price − deposit`) chỉ còn trong dữ liệu dev cũ; trường `deposit` nay giữ **toàn bộ giá** và `remaining` luôn bằng 0 (tên trường đổi thành `terms.price` cùng việc làm hai mốc chuyển tiền, #130 và #134).

### 2.4 Enum

Lưu **mã chuỗi ổn định** `snake_case` thường (`requested`, `photo_walk`), có ràng buộc `CHECK` hoặc bảng tra. Nhãn tiếng Việt nằm ở i18n, không ở dữ liệu. Không lưu số thứ tự (app Java cũ dùng `BookStatus` 0–4 là nợ cũ, di trú sang mã). Thêm giá trị mới là thay đổi tương thích; **không đổi nghĩa hay xoá** mã đang dùng (đánh dấu `deprecated`). Danh mục đầy đủ ở [domain-model.md](domain-model.md) mục 4.

### 2.5 Địa lý

Miền dùng `GeoPoint(lat, lng)` (độ thập phân, WGS84). Lưu `lat double precision`, `lng double precision` và `geohash text` (độ dài 9) để truy vấn gần đúng trên cả Firestore và cơ sở dữ liệu thường; có thể thêm cột `geography` (PostGIS) khi di trú. Không dùng kiểu `GeoPoint` của Firestore ngoài adapter.

### 2.6 Tệp và ảnh

Chỉ lưu **khoá lưu trữ** (`storage_key`) và siêu dữ liệu, không lưu URL có token tải của Firebase. URL được dựng lúc chạy bởi cổng `MediaUrlResolver`. Mỗi tệp có bản ghi trong `files` (mime, kích thước, chiều rộng/cao, blurhash, chủ sở hữu). Thực thể tham chiếu bằng `file_id`.

### 2.7 Cấu trúc và mảng

Thực thể phẳng, quan hệ qua khoá ngoại. Mảng của Firestore (`specialties`, `imageUrls`, `members`, `fcmTokens`, …) trở thành **bảng liên kết** (có thứ tự nếu cần). JSON (`jsonb`) chỉ cho dữ liệu thật sự không có lược đồ (phản hồi thô của cổng thanh toán, quy tắc huy hiệu, trọng số cấu hình) và luôn có cột `schema_version` hoặc nằm trong bảng cấu hình.

### 2.8 Đặt tên

| Lớp | Quy ước |
|-----|---------|
| Bảng | `snake_case` số nhiều (`bookings`, `event_registrations`) |
| Cột | `snake_case` (`customer_id`, `starts_at`); khoá ngoại `<thực thể>_id`; thời điểm kết thúc `_at`; ngày `_on`/`day`; cờ boolean bắt đầu bằng `is_`/`has_` hoặc tính từ (`active`, `verified`) |
| Trường Firestore | `camelCase` (giữ nguyên); ánh xạ tự động `camelCase ↔ snake_case`, ngoại lệ liệt kê ở relational-schema.md mục 3 |
| Dây (API/JSON) | `camelCase`, thời gian ISO‑8601, tiền là số nguyên + `currency`, enum là mã chuỗi. Khớp với hợp đồng gợi ý (`services/recommender/api/openapi.yaml`) |
| Miền Dart | lớp `PascalCase` bất biến (freezed), trường `camelCase` |
| Mã lỗi | `snake_case` ổn định (`day_taken`, `phone_required`, `contact_locked`), không dùng thông điệp làm mã |

### 2.9 Phiên bản và đồng thời

- Tài liệu/bản ghi có `schema_version` khi cấu trúc có thể đổi (ví dụ `photographers.skills`).
- Bản ghi hay bị cập nhật đồng thời (`bookings`, `events`, `event_registrations`) có `version int` (khoá lạc quan); mọi chuyển trạng thái đi qua use case kiểm `version`.
- Thao tác có tiền hoặc tạo bản ghi mang `idempotency_key` để thử lại an toàn.

### 2.10 Xoá và lưu giữ

Xoá mềm (`deleted_at`) cho nội dung người dùng (bài đăng, đánh giá, tin nhắn); xoá cứng/ẩn danh cho dữ liệu cá nhân theo yêu cầu (quy trình `erase_user`). Số điện thoại trong `booking_contacts` bị xoá sau 30 ngày kể từ `completed` (spec chính mục 3b). `audit_log` không xoá.

## 3. Cổng và bộ chuyển đổi

Mỗi cổng là một interface ở lớp miền/ứng dụng; hiện thực Firebase nằm trong `lib/data/firebase/` (ứng dụng) và `functions/` (máy chủ). Thay thế cho hệ thống riêng chỉ cần viết cài đặt mới.

| Cổng (port) | Việc | Hiện tại (Firebase) | Hệ thống riêng (dự kiến) |
|-------------|------|---------------------|---------------------------|
| `IdentityProvider` | Đăng nhập, phát/xác minh token, claim `role`/`staffRole` | Firebase Auth (email, Google, Facebook) | OIDC/JWT tự quản (Keycloak, Auth0, tự viết); xác minh bằng JWKS |
| `Repository<T>` mỗi thực thể | Đọc/ghi, `watch` thời gian thực | `cloud_firestore` | REST/GraphQL + PostgreSQL |
| `RealtimeChannel` | Đẩy thay đổi (chat, trạng thái booking, số chỗ) | Snapshot listeners | WebSocket/SSE; Postgres `LISTEN/NOTIFY`, Redis pub/sub |
| `FileStorage` + `MediaUrlResolver` | Tải lên, URL hiển thị | Firebase Storage | S3/GCS/MinIO + CDN, URL ký sẵn |
| `PushGateway` | Đẩy thông báo | FCM | FCM/APNs trực tiếp, hoặc dịch vụ trung gian |
| `PaymentGateway` | Tạo giao dịch, IPN, hoàn tiền (MoMo, VNPay) | Cloud Functions | Dịch vụ thanh toán riêng; hợp đồng không đổi |
| `GeoIndex` | Tìm theo vùng, khoảng cách | Geohash trên Firestore | PostGIS/H3 |
| `Recommender` | Gợi ý | `services/recommender` (đã tách) | Giữ nguyên |
| `Scheduler` | Việc định kỳ (hết hạn, nhắc lịch, huy hiệu) | Cloud Scheduler + Functions | Cron/queue (BullMQ, Cloud Tasks, Temporal) |
| `Clock`, `IdGenerator` | Thời gian, id | Hệ thống | Hệ thống |

### Ảnh tải lên (`FileStorage`, #147)

Mọi ảnh người dùng tải lên đi qua `MediaUploader.upload(image, storagePath:, purpose:)`; chỗ gọi chọn một `ImagePurpose` (bắt buộc, không có giá trị mặc định). Nén, xoá EXIF và đặt kiểu nội dung JPEG xảy ra bên trong uploader, nên nơi gọi không tự nén. Bảng dưới là hợp đồng mà **mọi hiện thực `FileStorage`** phải giữ (cả Firebase Storage lẫn S3/GCS/MinIO sau này):

| Mục đích (`ImagePurpose`) | `customMetadata.purpose` | Cạnh dài | JPEG q | Dự kiến | Giới hạn (`maxBytes`) | `Cache-Control` | Đường dẫn hiện có |
|---|---|---|---|---|---|---|---|
| `avatar` | `avatar` | 512 px | 80 | ~60 KB | 512 KiB | `public, max-age=31536000` | `avatars/{uid}/{ulid}.jpg` |
| `chat` | `chat` | 1280 px | 75 | ~150 KB | 1,5 MiB | `private, max-age=31536000` | `chats/{chatId}/{uid}/{clientId}.jpg` |
| `share` | `share` | 1600 px | 80 | ~300 KB | 2 MiB | `public, max-age=31536000` | `posts/…` (ảnh thực tế, ảnh sự kiện), `eventCovers/{uid}/{eventId}/{ulid}.jpg` |
| `deliverySample` | `delivery_sample` | 1600 px | 75 | ~250 KB | 2 MiB | `private, max-age=31536000` | do #152 đặt |
| `portfolio` | `portfolio` | 2048 px | 82 | ~500 KB | 3 MiB | `public, max-age=31536000` | `posts/{uid}/{postId}/{key}.jpg` |
| `document` | `document` | 2048 px | 85 | ~600 KB | 3 MiB | `private, max-age=31536000` | `awardProofs/{uid}/{awardId}/{ulid}.jpg`; giấy tờ định danh do #135 đặt |

Quy tắc:

- **Chỉ JPEG.** Một kiểu nội dung duy nhất (`image/jpeg`) cho mọi mục đích: giải mã được ở Android, iOS, web và `sharp` của Function đóng dấu mờ; rules chỉ cần một điều kiện. Tệp tải lên mới luôn kết thúc `.jpg` và đổi tên mỗi lần tải (nên cache một năm an toàn); các tệp ảnh chat cũ đuôi `.webp` (nội dung vẫn là JPEG) vẫn đọc được. WebP chưa dùng (câu hỏi chủ sở hữu 1, mặc định JPEG). **Giới hạn đã biết:** nguồn PNG có kênh trong suốt sẽ thành nền đen khi mã hoá JPEG trên Android; trải lên nền trắng trước khi mã hoá là cải tiến sau.
- **Không còn dữ liệu cá nhân trong tệp.** Ứng dụng gọi bộ mã hoá với `keepExif: false` và `autoCorrectionAngle: true` (hướng ảnh được ghi vào điểm ảnh), rồi `stripJpegMetadata` trong Dart bỏ APP1 (EXIF, XMP, gồm GPS), APP3–APP15, COM và APP2 không phải ICC, ở mọi lần quét và mọi dữ liệu sau EOI. Giữ APP0 (JFIF) và **hồ sơ màu ICC** (ảnh Display P3 vẫn đúng màu; không phải dữ liệu cá nhân). Hệ thống riêng không được nhận ảnh có EXIF từ máy khách mà không xoá lại.
- **Siêu dữ liệu đối tượng.** `contentType: image/jpeg`, `cacheControl` theo bảng, `customMetadata: {purpose: <mã>}`. `purpose` chỉ để vận hành và kiểm toán; giới hạn thực thi dựa trên đường dẫn, không dựa trên giá trị do máy khách khai.
- **Giới hạn phía máy chủ theo đường dẫn.** Mỗi đường dẫn nhận một giới hạn bằng `maxBytes` của mục đích của nó (`jpegUpTo(n)` trong `app_flutter/firebase/storage.rules`: `request.resource.contentType == 'image/jpeg' && request.resource.size <= n`). `posts/` chứa cả portfolio (2048) lẫn ảnh chia sẻ (1600) nên lấy giới hạn lớn hơn (3 MiB). Một `FileStorage` tự vận hành (presigned URL của S3/GCS/MinIO) phải ép đúng bảng này: kiểu nội dung `image/jpeg` và kích thước tối đa theo tiền tố khoá (điều kiện `content-length-range` và `Content-Type` trong chính sách POST đã ký, hoặc kiểm tra ở cổng tải lên). Đường dẫn mới dùng `jpegUpTo(<maxBytes của mục đích>)`, không bao giờ `image/.*`. Không có đường dẫn ghi nào dưới `users/{uid}/**` (đã đóng).
- **Kích thước đi cùng lần tải.** `UploadedMedia` mang `width`, `height`, `sizeBytes` do bộ nén đo; S10.01 ghi `imageMeta.w/h`, dòng thời gian sự kiện dùng lại thay vì đo lại.
- **Đồng bộ.** `test/data/media/storage_rules_limits_sync_test.dart` so từng khối `match` của `storage.rules` với `ImagePurpose.maxBytes`; sửa bảng thì sửa cả hai. Cùng test đòi mọi dòng `allow create|update|write` không phải `if false` đều dùng `jpegUpTo(`, để đường dẫn Storage mới không bỏ qua giới hạn kiểu và kích thước; ảnh chat và minh chứng thêm `resource == null` (không ghi đè).

**Luật phụ thuộc** (kiểm bằng test, mục 7): `lib/domain/**` và `lib/features/**` không được `import` `cloud_firestore`, `firebase_*`; chỉ `lib/data/firebase/**`, `lib/firebase_options.dart` và `lib/main.dart` được phép.

## 4. Ma trận phân quyền (chính sách, không phụ thuộc cách thực thi)

`S` = chính chủ (subject), `P` = bên liên quan trong giao dịch, `A` = admin, `X` = nhân viên bán hàng (`sales`), `U` = mọi người đã đăng nhập, `Svc` = chỉ dịch vụ/use case (không ghi trực tiếp từ máy khách).

| Thực thể | Đọc | Ghi |
|----------|-----|-----|
| `users` (hồ sơ công khai) | U | S (tên, avatar, thành phố); vai trò `role` qua use case `set_role`; `staff_role` chỉ A qua `set_staff_role` |
| `user_contacts` | S | S |
| `auth_identities`, `devices` | S | Svc/S |
| `photographers` (công khai) | U (nếu đã `onboarding_complete`), S luôn | S (nội dung); thống kê và `verified` chỉ Svc/A |
| `photographer_contact_channels` | U | S |
| `photographer_contact_numbers` | S; người khác chỉ qua use case `get_contact_link` | S |
| `services`, kỹ năng, minh chứng | U | S |
| `availability_days` | U | S (`off`); `booked`/`pending` chỉ Svc |
| `posts`, `post_images` | U (chưa xoá mềm) | S (tác giả); `real_shoot` chỉ qua `submit_review` |
| `likes`, `saves`, `follows` | S | S |
| `bookings` | P, A | Svc (mọi chuyển trạng thái qua `transition_booking`) |
| `booking_contacts` | P (sau khi đủ điều kiện mở khoá), A | Svc |
| `payments`, `refunds` | P (số tiền và trạng thái), A | Svc |
| `ledger_entries` | A; người nhận xem bút toán của chính mình | Svc (chỉ thêm) |
| `payout_accounts` | S (số che), A | S (qua use case có xác nhận) |
| `payouts`, `payout_items` | người nhận, A | Svc / A (duyệt) |
| `reviews` | U | Svc (qua `submit_review`), S không sửa sau khi gửi |
| `chats`, `chat_members`, `messages` | thành viên (nhóm sự kiện: người đăng ký, chủ, staff) | thành viên (gửi tin); `kind`, hạn mức, vai điều hành do Svc |
| `notifications` | S | Svc; S đánh dấu đã đọc |
| `event_posts`, `post_hashtags` | U (bài `visible`); `pending/hidden` chỉ điều hành | Svc (`linkEventPosts`, `moderateEventContent`) |
| `events` | U (không phải `draft`), người quản lý luôn | Svc (`create_event`/`update_event`): NAG host, A, X (sự kiện mình tạo) |
| `event_registrations` | S, người quản lý sự kiện, A | Svc |
| `badge_definitions` | U | A |
| `user_badges` | U | Svc |
| `badge_progress` | S | Svc |
| `taxonomy_items` | U | A |
| `recommendation_logs`, `audit_log`, `contact_access_log` | A | Svc |

Quy tắc: mọi ghi vào cột/bảng "Svc" đi qua use case có kiểm điều kiện; máy khách không bao giờ ghi trạng thái, bộ đếm, tiền, mã vé, huy hiệu, hay quyền nhân viên.

## 5. Danh mục use case (hợp đồng nghiệp vụ độc lập nơi chạy)

Mỗi use case có tên, đầu vào/ra, điều kiện, phụ thuộc cổng. Hiện chạy ở Cloud Functions, về sau chạy ở máy chủ riêng, **cùng hợp đồng**. Tên dùng `snake_case`; ánh xạ tên Functions hiện tại ở cột phải.

| Use case | Việc | Tên Functions |
|----------|------|----------------|
| `set_role`, `set_staff_role` | Chọn vai trò; đặt quyền nhân viên (chỉ admin) | `setRole`, `setStaffRole` |
| `complete_photographer_profile` | Hoàn tất thiết lập, tính `completeness`, `starting_price` | `onPhotographerWrite` |
| `create_booking_draft`, `create_payment` | Tạo booking `draft` và giữ ngày; mỗi lần chọn/đổi phương thức tạo một `Payment` `created` (hạn 15 phút, tối đa 3 khoản mỗi booking), sinh mã chuyển khoản, ghi bản sao `checkout` vào booking | `createBooking`, `createPayment` |
| `handle_transfer_notification`, `check_payment`, `run_payment_sweeps` | Nhận webhook của tổ chức trung gian (đã kiểm chữ ký ở Functions), khớp khoản theo mã chuyển khoản, ghi `payment_received`, chuyển `draft → requested`, hoàn phần thừa/thiếu/muộn; hỏi lại cổng; đối soát 5 phút một lần và hết hạn khoản | `paymentWebhook`, `checkPayment`, `paymentClock` |
| `transition_booking` | Mọi chuyển trạng thái (nhận, từ chối, huỷ, hoàn thành) | `transitionBooking` |
| `refund_payment` | Hoàn tiền theo chính sách, chỉ từ số tiền treo, ghi sổ cái | `refundDeposit` |
| `release_escrow`, `create_payout`, `execute_payout` | Thả tiền treo sau khi hoàn thành, tạo và thực hiện lô chi trả | `releaseEscrow`, `executePayout` |
| `save_payout_account` | Nhiếp ảnh gia khai/đổi tài khoản nhận tiền (đổi cần đăng nhập lại ≤ 5 phút) | `savePayoutAccount` |
| `refresh_earnings` | Tính lại các dòng Thu nhập và ba tổng của một người nhận | `onPaymentWritten`, `onPayoutWritten` |
| `hold_payout`, `resume_payout` | Nhân viên giữ/tiếp tục một lô chưa chạy; CLI `payouts` gọi `create`/`execute`/`hold`/`resume` | CLI `payouts` |
| `open_dispute`, `resolve_dispute` | Khiếu nại trong cửa sổ, admin xử lý | `openDispute`, `resolveDispute` |
| `link_event_posts`, `moderate_event_content`, `join_event_chat` | Timeline theo hashtag, kiểm duyệt, nhóm chat sự kiện | `linkEventPosts`, `moderateEventContent`, `joinEventChat` |
| `expire_requests`, `schedule_reminders` | Hết hạn 24 giờ, nhắc lịch | cron |
| `submit_review` | Ghi đánh giá, tạo bài `real_shoot`, cập nhật thống kê, huy hiệu | `onReviewWrite` |
| `create_event`, `update_event`, `cancel_event` | Quản lý sự kiện (kiểm quyền mục 3.6 spec chính) | `createEvent`, `updateEvent`, `cancelEvent` |
| `register_event`, `cancel_registration`, `check_in_registration`, `release_expired_holds`, `close_events` | Đăng ký, vé, check‑in, dọn giữ chỗ | `registerEvent`, `cancelRegistration`, `checkInRegistration`, `releaseExpiredHolds`, `closeEvents` |
| `get_contact_link` | Trả URL gọi/Zalo/WhatsApp nếu đã mở khoá | `getContactLink` |
| `send_message_guard` | Áp hạn mức chat hỏi trước (3 tin tới khi nhiếp ảnh gia trả lời), đóng sau 14 ngày | trigger `messages` |
| `award_badges`, `reconcile_badges` | Trao/thu hồi huy hiệu | `onReviewWrite`, cron |
| `recommend`, `record_recommendation_feedback` | Gợi ý và nhật ký | `recommend`, `recommendFeedback` |
| `erase_user`, `export_user_data` | Xoá/ẩn danh, xuất dữ liệu cá nhân | mới |

## 6. Kế hoạch di trú sang hệ thống riêng

Làm theo bậc thang, mỗi bậc triển khai độc lập và quay lui được.

| Bậc | Việc | Kết quả kiểm được |
|-----|------|--------------------|
| 0 | Hoàn thiện lớp miền thuần và cổng; tách `lib/data/firebase/`; thêm kiểm tra luật phụ thuộc | Không còn `import` Firebase ngoài adapter |
| 1 | Viết lược đồ quan hệ (tệp này), bộ ánh xạ hai chiều Firestore ↔ bảng cho từng thực thể, **kiểm thử hợp đồng** chạy với `Fake`, Firestore và (về sau) SQL | Cả ba cài đặt qua cùng bộ test |
| 2 | Xuất toàn bộ Firestore ra NDJSON theo bảng (công cụ `tools/export`), nhập vào PostgreSQL thử nghiệm, so khớp số bản ghi và checksum | Bản sao đúng, id giữ nguyên |
| 3 | Chạy song song: thay đổi Firestore được chép sang PostgreSQL (trigger/Change Streams); chỉ đọc từ PostgreSQL ở môi trường thử | Độ trễ và sai khác đo được |
| 4 | Dựng máy chủ API cho các use case (mục 5) và `RealtimeChannel`; ứng dụng chọn adapter bằng cấu hình (cờ từ xa) theo từng thực thể | Chuyển từng cụm (nội dung → hồ sơ → booking → sự kiện → chat) |
| 5 | Chuyển ghi sang hệ thống riêng; Firestore chuyển thành chỉ đọc rồi tắt; đổi `IdentityProvider` bằng cách nhập `auth_identities` và cấp token mới (người dùng không phải đăng ký lại) | Không còn phụ thuộc Firebase ở môi trường thật |

Rủi ro cần chuẩn bị từ đầu: (a) mật khẩu Firebase Auth không xuất được dạng rõ nên cần luồng đặt lại hoặc liên kết nhà cung cấp xã hội; (b) quy tắc Firestore phải dịch sang chính sách ở lớp API/Row‑Level Security; (c) thời gian thực và ngoại tuyến của Firestore cần thay bằng bộ nhớ đệm cục bộ + đồng bộ; (d) truy vấn địa lý geohash chuyển sang chỉ mục không gian; (e) FCM giữ được nếu vẫn dùng FCM làm kênh đẩy.

## 7. Tiêu chí chấp nhận

1. **Luật phụ thuộc**: một test (hoặc lint tuỳ biến) quét `lib/` và thất bại nếu `lib/domain/**`, `lib/features/**`, `lib/core/**` import `package:cloud_firestore`, `package:firebase_*`.
2. **Mỗi thực thể có đủ bộ ba**: lớp miền, bảng trong relational-schema.md, và bộ ánh xạ hai chiều có test vòng (miền → Firestore → miền, miền → hàng SQL → miền).
3. **Kiểm thử hợp đồng repository** chạy chung cho `Fake` và `Firestore` (emulator); cài đặt SQL tương lai phải qua đúng bộ này.
4. **Quy chuẩn kiểu**: test xác nhận id là chuỗi bất biến ≤ 64 ký tự, thời điểm UTC, tiền là số nguyên, enum là mã chuỗi thuộc danh mục.
5. **Xuất/nhập**: công cụ xuất sinh NDJSON đúng lược đồ cho mọi bảng; nhập vào PostgreSQL thử nghiệm cho cùng số bản ghi và checksum; giữ nguyên id.
6. **Phân quyền**: mỗi dòng ma trận mục 4 có test (cả Firestore Rules emulator lẫn bản kiểm ở lớp use case).
7. **Không có khoá nghiệp vụ nằm trong URL Firebase**: không lưu URL tải Storage, đường dẫn Firestore hay `DocumentReference` trong dữ liệu.

## 8. Câu hỏi mở

1. **Hệ quản trị đích**: PostgreSQL (đề xuất, có PostGIS) hay khác? Có dùng ORM/Query builder cụ thể (Drizzle, Prisma, jOOQ…) hay không.
2. **Ngôn ngữ máy chủ riêng**: TypeScript (dùng chung kiểu với Functions và recommender, đề xuất) hay Go/Kotlin?
3. **Id mới**: ULID (đề xuất) hay UUIDv7? Hai loại đều sắp theo thời gian; chọn một và giữ.
4. **Thời gian thực**: WebSocket tự quản hay dịch vụ ngoài (Ably, Pusher, Supabase Realtime) ở máy chủ riêng?
5. **Đăng nhập**: giữ Firebase Auth riêng làm IdP (dễ nhất, vẫn "phụ thuộc Firebase" một phần) hay chuyển hẳn sang OIDC khác? Quyết định ảnh hưởng bậc 5.
6. **Thời hạn lưu**: thời hạn giữ `messages`, `recommendation_logs`, `audit_log` (đề xuất 12/6/60 tháng).
7. **Dữ liệu từ app Java cũ** (`booking`, `albums`, `users`): có đưa vào bảng mới không (đề xuất chỉ `users` và `albums → posts`, theo spec gốc mục 5 phần Migration).
8. Mã danh mục trùng giữa hai nhóm: `couple` là thể loại và cũng là khách phù hợp (seed ở relational-schema.md §6), trong khi `taxonomy_items.id` là khoá chính và `taxonomy/skills/items/{id}` là id tài liệu. Ứng dụng đã tra theo (`group`, `id`). Trước khi di trú cần chọn: khoá chính (`grp`, `id`) và khoá ngoại hai cột, hoặc đổi mã khách thành `couples` (cần di trú dữ liệu `audiences`).
