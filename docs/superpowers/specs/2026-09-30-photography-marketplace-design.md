# Spec — Cộng đồng nhiếp ảnh gia v1 (Flutter)

Ngày: 2026-09-30 · Branch: `flutter-rewrite` · Trạng thái: chờ review

Bản thiết kế cho phiên bản viết lại bằng Flutter của app "Cộng đồng nhiếp ảnh gia". Sản phẩm là **marketplace nhiếp ảnh vận hành bởi cộng đồng**: ảnh đẹp tạo khám phá, khám phá tạo tin cậy, tin cậy chuyển thành buổi chụp thật, buổi chụp tạo review và ảnh mới.

Tài liệu liên quan:
- UI hi‑fi 14 màn hình: https://claude.ai/artifact/LptNpoqnt5KjQ5tUaPjYDM
- Audit UX app cũ: `docs/UX-REDESIGN.md`
- Design tokens: `design-system/`
- Đánh giá codebase cũ: `docs/MODERNIZATION-REVIEW.md`

---

## 1. Mục tiêu và ranh giới

### Mục tiêu v1
1. Khách tìm được nhiếp ảnh gia phù hợp qua ảnh, kiểm tra được lịch rảnh và giá, đặt cọc trong dưới 7 chạm.
2. Nhiếp ảnh gia đăng bài một lần, bài vừa là portfolio vừa là quảng cáo gói dịch vụ, và nhận yêu cầu ở một nơi.
3. Mỗi buổi chụp hoàn thành sinh ra review và ảnh chia sẻ, quay lại feed.

### Quyết định đã chốt
| Quyết định | Lựa chọn |
|-----------|----------|
| Nền tảng | Flutter (Android + iOS), một codebase |
| Backend | Firebase: Auth, Firestore, Cloud Functions (TypeScript), Storage, FCM. Không server riêng |
| Thanh toán | Đặt cọc 30% qua VNPay hoặc MoMo, phần còn lại trả tại buổi chụp |
| Phía cung | Tự đăng ký, được đặt ngay; huy hiệu Verified do admin duyệt sau |
| Phạm vi | Cách A: marketplace đầy đủ, social tối thiểu (follow, like, save) |
| Thị trường | Việt Nam, tiếng Việt, VNĐ |
| Vị trí code | Thư mục `app_flutter/` trong repo này; app Java cũ giữ nguyên cho tham chiếu |

### Không làm trong v1
Comment, collections, challenges, behind‑the‑scenes, analytics hiệu suất, dự án mở (khách đăng, nhiếp ảnh gia ứng tuyển), thanh toán toàn phần/escrow, chat ngoài ngữ cảnh booking, nhiều nhiếp ảnh gia trong một booking, web.

---

## 2. Kiến trúc sản phẩm

Sáu hệ thống, mỗi hệ thống có một "cửa ra" sang hệ thống kế tiếp. Không hệ thống nào đứng riêng.

```
CONTENT ──bài đăng gắn gói──▶ DISCOVERY ──"Đặt lịch"──▶ PROFILE ──gói + ngày rảnh──▶ BOOKING
   ▲                                                                                   │ cọc thành công
   │ khách chia sẻ ảnh có tag                                                          ▼
POST‑SHOOT ◀──"Đánh giá" sau endTime+24h── SHOOT (timeline, chat ngữ cảnh) ◀───────────┘
DASHBOARD nhiếp ảnh gia đứng ngang: Yêu cầu → Lịch → Doanh thu → Portfolio
```

| Từ → đến | Cơ chế UI | Dữ liệu |
|----------|-----------|---------|
| Content → Discovery | Bài đăng bắt buộc gắn 1 gói + địa điểm; feed ưu tiên người còn lịch trong 14 ngày | `posts.serviceId`, `availability` |
| Discovery → Profile | Chạm ảnh → chi tiết ảnh (gói dưới ảnh); chạm tên → hồ sơ | `posts.photographerId` |
| Profile → Booking | CTA cố định đáy; chọn gói trên hồ sơ mở sheet với gói sẵn | `services`, `availability` |
| Booking → Shoot | Cọc thành công → `booking.status = requested` + phòng chat với card ngữ cảnh | `bookings`, `payments` |
| Shoot → Post‑shoot | Function lịch sau `endTime + 24h` hoặc nhiếp ảnh gia bấm "Đã giao ảnh" → push | `bookings.status = completed` |
| Post‑shoot → Content | Review lên hồ sơ; ảnh chia sẻ thành `post` nhãn "Buổi chụp thật" link gói | `reviews`, `posts.bookingId` |

---

## 3. Vai trò và điều hướng

Một tài khoản có `role: customer | photographer`, đổi được trong Hồ sơ (chuyển sang photographer yêu cầu hoàn thiện hồ sơ 3 bước).

Năm tab, tab giữa đổi theo vai trò:

| Tab | Khách | Nhiếp ảnh gia |
|-----|-------|---------------|
| Trang chủ | Feed section: Dành cho bạn · Gần bạn · Rảnh tuần này · Buổi chụp thật · Đang lên | Cùng feed (để học và theo dõi đồng nghiệp) |
| Khám phá | Tìm kiếm + lối vào hình: Dịch vụ · Địa điểm · Phong cách · Nhiếp ảnh gia | Như khách |
| Giữa | **Tìm thợ ảnh**: lọc Địa điểm/Ngày/Dịch vụ/Giá/Sao, card so sánh | **Đăng bài**: ảnh + gói (bắt buộc) + địa điểm + phong cách |
| Đặt lịch / Công việc | Sắp tới · Đang chờ · Đã xong; chi tiết = timeline | Dashboard: Hôm nay · Yêu cầu mới · Lịch · Doanh thu |
| Hồ sơ | Đã lưu, đang theo dõi, bài đã chia sẻ, cài đặt, trở thành nhiếp ảnh gia | Hồ sơ như khách thấy, chỉnh gói/giá/thiết bị/bio/khu vực, xác minh |

Màn ngoài tab: Chi tiết ảnh, Hồ sơ nhiếp ảnh gia, Sheet đặt lịch (4 bước), Thanh toán cọc, Chi tiết booking, Hội thoại, Đánh giá & chia sẻ, Lịch của tôi, Onboarding. Tin nhắn không có tab; vào từ icon Trang chủ (badge) hoặc chi tiết booking.

---

## 4. Bảy hành trình

1. **Khách khám phá nhiếp ảnh gia**: mở app → Trang chủ hiện ảnh theo vị trí và sở thích (dịch vụ đã xem, người đã theo dõi) → chạm ảnh → chi tiết ảnh (gói + giá) → "Xem hồ sơ" → portfolio, sao, số buổi, phản hồi, lịch, giá. 3 chạm.
2. **Khách đặt lịch**: từ hồ sơ hoặc card "Đặt T7" → sheet: Gói → Ngày & giờ (4 trạng thái ngày, chip giờ) → Địa điểm (mặc định từ lọc/gợi ý) → Xem lại (ai/gì/khi/đâu/bao nhiêu, cọc 30%, chính sách huỷ) → MoMo/VNPay → về màn chi tiết booking, trạng thái Đã gửi. 6–7 chạm, 0 lần rời app ngoài cổng thanh toán.
3. **Nhiếp ảnh gia nhận booking**: push "Yêu cầu mới, đã cọc" → tab Công việc mở ở Yêu cầu → card có ghi chú khách, Nhận (đếm ngược 24h) / Từ chối (chọn lý do) → Nhận: trạng thái Đã xác nhận, phòng chat mở, lịch ngày đó thành Đã đặt.
4. **Nhiếp ảnh gia quản lý lịch**: Công việc → icon lịch → lịch tháng → chạm ngày trống → Nghỉ (hoặc chọn dải ngày) → khách không đặt được. Đã đặt và Chờ tự sinh từ booking.
5. **Khách hoàn thành buổi chụp**: nhắc trước 24h (push + card Sắp tới) → ngày chụp: chi tiết booking hiện "Hôm nay", nút Chỉ đường, Nhắn tin → sau `endTime` nhiếp ảnh gia bấm "Hoàn thành" (hoặc hệ thống sau 24h) → trạng thái Hoàn thành, khách trả phần còn lại tại chỗ.
6. **Khách đánh giá và chia sẻ**: push "Buổi chụp thế nào?" → màn Đánh giá: sao + nhận xét (bắt buộc), chọn ảnh chia sẻ (tuỳ chọn, tối đa 10) → review lên hồ sơ, ảnh thành bài "Buổi chụp thật" có tag nhiếp ảnh gia và link gói.
7. **Người mới khám phá qua ảnh chia sẻ**: bài "Buổi chụp thật" trong feed → chi tiết ảnh hiện "Chụp bởi Minh Trí · gói Chân dung 2 giờ" → hồ sơ → đặt lịch. Cũng là nội dung share ra ngoài app (deep link `/p/{postId}`).

---

## 5. Mô hình dữ liệu (Firestore)

Tất cả `createdAt/updatedAt` là server timestamp. Tiền là số nguyên VNĐ.

```
users/{uid}
  role: "customer" | "photographer"
  displayName, avatarUrl, phone, city, geo: {lat, lng, geohash}
  fcmTokens: string[]
  followingCount, followerCount, savedCount
  createdAt

photographers/{uid}                       # chỉ tồn tại khi role = photographer
  bio, specialties: string[]              # "portrait" | "wedding" | "family" | "event" | "product" | "graduation" | "couple" | "travel" | "street" | "commercial" | "fashion"
  styles: string[], equipment: string[], yearsExperience
  serviceArea: {city, geo, radiusKm}
  verified: bool, verifiedAt
  stats: {rating, reviewCount, completedCount, responseMinutes, repeatCustomerCount}   # do Functions tính
  startingPrice                           # min(services.price), do Functions tính
  portfolio: string[]                     # postIds được ghim, tối đa 30
  onboardingComplete: bool

photographers/{uid}/services/{serviceId}
  name, specialty, durationMinutes, price, deliverables: {photoCount, editedCount, deliveryDays}, coverUrl, active

availability/{uid}/days/{yyyy-mm-dd}
  state: "off" | "booked" | "pending"     # không có doc = rảnh
  bookingId?                              # với booked/pending
  slots?: [{start:"15:30", end:"17:30", bookingId}]   # v1 khoá cả ngày theo gói; slots dành cho v1.1

posts/{postId}
  photographerId, serviceId (bắt buộc), imageUrls: string[] (1–10), caption
  location: {name, geo, geohash}, style
  kind: "work" | "real_shoot"             # real_shoot = khách chia sẻ sau buổi chụp
  authorId                                # = photographerId với work, = customerId với real_shoot
  bookingId?                              # với real_shoot
  likeCount, saveCount, inPortfolio: bool
  createdAt

likes/{uid}_{postId}, saves/{uid}_{postId}, follows/{uid}_{photographerId}   # doc rỗng, đếm bằng Functions

bookings/{bookingId}
  customerId, photographerId, serviceId
  service: {name, price, durationMinutes}  # snapshot lúc đặt
  date: "yyyy-mm-dd", start: "15:30", end: "17:30"
  location: {name, geo}, note
  status: "draft" | "requested" | "accepted" | "declined" | "expired" | "cancelled" | "upcoming" | "completed" | "reviewed"
  deposit: {amount, provider: "momo"|"vnpay", paymentId, paidAt, refundedAt?}
  remaining                               # price - deposit.amount
  acceptDeadline                          # requestedAt + 24h
  cancel?: {by, reason, at, refundPercent}
  chatId
  timeline: [{status, at}]
  createdAt, updatedAt

payments/{paymentId}
  bookingId, provider, amount, status: "created" | "paid" | "failed" | "refunded", providerRef, raw

reviews/{bookingId}                        # 1 review / booking
  customerId, photographerId, rating (1–5), text, photoPostId?, createdAt

chats/{chatId}
  bookingId, members: [customerId, photographerId], lastMessage: {text, senderId, at}, unread: {uid: count}
chats/{chatId}/messages/{messageId}
  senderId, type: "text" | "image" | "location" | "system", text?, imageUrl?, geo?, createdAt

notifications/{uid}/items/{id}
  type, title, body, bookingId?, postId?, read, createdAt
```

Chỉ mục cần: `posts (kind, createdAt desc)`, `posts (photographerId, createdAt desc)`, `posts (location.geohash)`, `bookings (customerId, status)`, `bookings (photographerId, status)`, `photographers (serviceArea.geo.geohash, startingPrice)`.

Migration từ app cũ: `users.is_photographer` → `role`; `users.price/camera_*/style` → `photographers.services[0]`, `equipment`, `styles`; `albums` → `posts kind=work` (mỗi album 1 post, `serviceId` gán thủ công hoặc gói mặc định); `booking` cũ không migrate. Script một lần trong Functions.

---

## 6. Máy trạng thái booking

```
draft ──cọc paid──▶ requested ──nhiếp ảnh gia Nhận──▶ accepted ──T‑24h──▶ upcoming ──endTime, "Hoàn thành"──▶ completed ──review──▶ reviewed
                      │ Từ chối ──▶ declined (hoàn cọc 100%)
                      │ quá acceptDeadline ──▶ expired (hoàn cọc 100%, Function)
   requested/accepted/upcoming ──khách huỷ──▶ cancelled (hoàn theo chính sách)
   accepted/upcoming ──nhiếp ảnh gia huỷ──▶ cancelled (hoàn 100%, trừ điểm uy tín)
```

Chính sách cọc v1 (hiển thị ở bước Xem lại):
| Thời điểm huỷ (khách) | Hoàn cọc |
|----------------------|----------|
| ≥ 48h trước `start` | 100% |
| 24–48h | 50% |
| < 24h | 0% |

Đổi lịch = khách đề nghị ngày/giờ mới trong chat (message `system`), nhiếp ảnh gia chấp nhận → cập nhật `date/start/end` và availability, không thay đổi cọc. Chỉ 1 lần đổi miễn phí.

Mọi chuyển trạng thái đi qua **Cloud Function `transitionBooking`** (callable), không cho client ghi `status` trực tiếp (Firestore rules). Function cũng ghi `timeline`, cập nhật `availability`, gửi FCM, tạo `notifications`.

---

## 7. Lịch rảnh

- Đơn vị v1 là **ngày**. Một booking khoá cả ngày cho nhiếp ảnh gia (đơn giản, tránh xung đột đi lại). `slots` để dành cho v1.1.
- Bốn trạng thái hiển thị: Rảnh (không doc), Chờ (`pending`, booking requested), Đã đặt (`booked`), Nghỉ (`off`).
- Khách chỉ đặt được ngày Rảnh; ngày Chờ hiển thị nhưng không chọn được, kèm "1 người đang chờ".
- "Rảnh tuần này" trên Trang chủ = nhiếp ảnh gia có ≥ 1 ngày Rảnh trong 7 ngày tới, do Function tính mỗi giờ vào `photographers.stats.nextFreeDate`.
- Chip giờ trong sheet = các mốc cách nhau 30 phút từ 06:00 đến 20:00 trừ `durationMinutes`; nhiếp ảnh gia có thể đặt "giờ gợi ý" trong gói.

---

## 8. Thanh toán cọc

- Client gọi `createDeposit({bookingId, provider})` → Function tạo `payments` doc, gọi API MoMo/VNPay tạo giao dịch, trả `payUrl` → client mở WebView/deeplink.
- Webhook (IPN) từ cổng → Function xác thực chữ ký → `payments.status = paid` → `transitionBooking(requested)`.
- Client không tin kết quả redirect; chờ `bookings.status` đổi qua snapshot listener; quá 5 phút chưa `paid` hiển thị "Đang chờ xác nhận thanh toán" và nút "Kiểm tra lại" (Function query cổng).
- Hoàn cọc: Function `refundDeposit` gọi API hoàn tiền của cổng; nếu cổng không hỗ trợ hoàn tự động (MoMo một số loại), ghi `refund.manual = true` và tạo việc cho admin.
- Phí cổng và hoa hồng nền tảng: v1 **không thu hoa hồng**; cọc chuyển thẳng tới tài khoản nền tảng và trả cho nhiếp ảnh gia hàng tuần (thủ công, ngoài app). Ghi rõ trong điều khoản.
- Secrets (MoMo partner code, VNPay TMN, hash secret) chỉ nằm trong Functions config, không bao giờ trong app.

---

## 9. Kiến trúc app Flutter

```
app_flutter/
  lib/
    app/            main.dart, router (go_router), theme, bootstrap (Firebase init, Riverpod ProviderScope)
    core/           design tokens (colors, typography, spacing từ design-system/tokens.json), widgets dùng chung
                    (PhotoCard, PhotographerCard, BookingCard, StatusBadge, AvailabilityCalendar, AppBottomSheet, EmptyState)
                    utils (money, date, geohash), errors, analytics
    data/           một thư mục mỗi aggregate: auth, user, photographer, service, availability, post, booking,
                    payment, review, chat, notification. Mỗi thư mục: model (freezed + json), repository (Firestore/Functions), fake repository cho test
    features/       một thư mục mỗi màn hình/luồng: onboarding, home, explore, find, post_detail, photographer_profile,
                    booking_sheet, booking_detail, chat, review_share, create_post, work_dashboard, my_calendar, profile
                    Mỗi feature: controller (Riverpod AsyncNotifier) + screen + widgets riêng
  functions/        TypeScript: transitionBooking, createDeposit, paymentWebhook, refundDeposit, onReviewWrite (stats),
                    onPostWrite (counts), scheduleReminders (cron), expireRequests (cron), computeNextFreeDate (cron), migrateLegacy
  firestore.rules, firestore.indexes.json, storage.rules
  test/             unit (models, controllers với fake repo), widget (core widgets), golden (PhotoCard, BookingCard)
  integration_test/ luồng đặt lịch với Firebase Emulator
```

Quy ước:
- **State**: Riverpod 2 (`AsyncNotifier`), không BLoC. Mỗi màn hình một controller, UI không gọi repository trực tiếp.
- **Điều hướng**: go_router với `ShellRoute` cho 5 tab; deep link `/p/{postId}`, `/u/{uid}`, `/b/{bookingId}`.
- **Model**: freezed + json_serializable; enum trạng thái là `enum` Dart có `label` tiếng Việt và màu token.
- **Firebase**: `cloud_firestore` với offline persistence bật; Functions qua `cloud_functions`; ảnh upload `firebase_storage` với resize client (≤ 2048px, WebP) trước khi tải.
- **Ảnh**: `cached_network_image`, placeholder blurhash lưu trong `posts.imageMeta`.
- **Vị trí**: `geolocator` + `geoflutterfire_plus` cho truy vấn bán kính.
- **Thanh toán**: `webview_flutter` cho VNPay; MoMo qua deeplink app hoặc WebView fallback.
- **Push**: `firebase_messaging`, token lưu vào `users.fcmTokens` khi đăng nhập.
- **Theme**: sinh `ThemeData` từ tokens; sáng và tối; font Be Vietnam Pro (body) và Fraunces (display) bundle trong assets.
- **i18n**: `flutter_localizations` + ARB tiếng Việt; không hard‑code chuỗi.
- **Toolchain**: Flutter stable mới nhất tại thời điểm tạo project; Android build bằng JDK mới nhất mà AGP của Flutter hỗ trợ (hiện 17–21), ghi trong `scripts/env.sh`.

---

## 10. Xử lý lỗi và trạng thái

| Tình huống | Hành vi |
|-----------|---------|
| Mất mạng | Đọc từ cache Firestore; thanh Snackbar "Không có kết nối"; nút ghi (đặt cọc, nhận) bị vô hiệu, không xếp hàng ghi |
| Function lỗi | Snackbar với thông điệp tiếng Việt từ `code`; nút quay lại trạng thái bình thường; ghi Crashlytics |
| Thanh toán treo | Màn "Đang chờ xác nhận" với "Kiểm tra lại"; sau 30 phút booking `draft` bị Function dọn |
| Ngày vừa bị người khác đặt | Bước Xem lại kiểm tra lại availability trước khi gọi `createDeposit`; lỗi `day_taken` → quay về bước Ngày với ngày đó gạch |
| Ảnh tải lỗi | Placeholder blurhash + nút thử lại; đăng bài giữ bản nháp cục bộ |
| Không có dữ liệu | Empty state có một hành động nuôi vòng lặp (xem UI màn 14) |

---

## 11. Kiểm thử

- **Unit**: máy trạng thái booking (mọi chuyển hợp lệ và không hợp lệ), tính hoàn cọc theo thời điểm, sinh chip giờ theo gói, tính `startingPrice`/`stats`. Functions test bằng `firebase-functions-test` + Emulator.
- **Widget/golden**: PhotoCard, PhotographerCard, BookingCard, StatusBadge, AvailabilityCalendar ở sáng/tối và cỡ chữ lớn.
- **Integration** (Emulator): đặt lịch end‑to‑end với cổng thanh toán giả (Function mock trả `paid`); nhiếp ảnh gia nhận; hết hạn 24h; review tạo bài real_shoot.
- **Rules**: test Firestore rules: client không ghi được `bookings.status`, chỉ chủ mới sửa `photographers/{uid}`.
- **Thủ công trước phát hành**: checklist ui-ux-pro-max (touch ≥ 48dp, tương phản, reduced motion, dynamic type) trên 375px và máy tablet.

---

## 12. Phân rã thành các spec con và thứ tự

| # | Sub‑project | Bao gồm | Kết quả có thể chạy |
|---|-------------|---------|---------------------|
| 1 | Nền tảng | Tạo project Flutter, theme từ tokens, router 5 tab, Firebase init, Auth (email, Google, Facebook), onboarding chọn vai trò, Firestore rules cơ bản, CI build | Đăng nhập, thấy 5 tab trống có empty state |
| 2 | Hồ sơ nhiếp ảnh gia | `photographers`, `services`, hoàn thiện hồ sơ 3 bước, màn hồ sơ (khách xem), Lịch của tôi + `availability`, Verified (admin) | Nhiếp ảnh gia có hồ sơ đặt được |
| 3 | Nội dung và khám phá | Đăng bài gắn gói, `posts`, Trang chủ theo section, Khám phá, chi tiết ảnh, like/save/follow, Tìm thợ ảnh với lọc | Khách khám phá và so sánh được |
| 4 | Đặt lịch | Sheet 4 bước, `createDeposit` + webhook MoMo/VNPay, `transitionBooking`, chi tiết booking timeline, chat ngữ cảnh, push | Đặt cọc và nhận booking end‑to‑end |
| 5 | Công việc | Dashboard nhiếp ảnh gia, nhận/từ chối, đếm ngược, doanh thu, nhắc lịch, hoàn thành | Nhiếp ảnh gia vận hành trong app |
| 6 | Hậu buổi chụp | Review, chia sẻ ảnh `real_shoot`, stats, section "Buổi chụp thật", deep link | Vòng lặp khép kín |
| 7 | Migration & ra mắt | Script migrate users/albums, Crashlytics, App Check, store listing | Dữ liệu cũ sang app mới |

Mỗi sub‑project đi qua: spec con ngắn (nếu cần) → kế hoạch → triển khai → review. Sub‑project 1 lập kế hoạch ngay sau khi spec này được duyệt.

---

## 13. Câu hỏi mở (không chặn sub‑project 1)

1. Cổng thanh toán: có sẵn tài khoản merchant MoMo/VNPay chưa? Nếu chưa, sub‑project 4 dùng cổng giả và bật thật sau.
2. Ai là admin duyệt Verified và hoàn cọc thủ công? Cần một trang admin tối thiểu (Firebase console + Function callable) hay app riêng?
3. Tỉ lệ cọc 30% và bảng hoàn cọc là giả định; cần xác nhận với nhiếp ảnh gia thật trước khi ra mắt.
4. Có giữ tên "Cộng đồng nhiếp ảnh gia" và applicationId cũ để cập nhật đè lên app đang phát hành, hay ra app mới?
