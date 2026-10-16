# Chi phí Google Cloud / Firebase cho app đặt thợ ảnh (nghiên cứu ngày 2026-10-07)

Quy ước: "đọc 2026-10-07" = ngày tôi lấy số. Nhãn nguồn:
- **[T]** trang chính thức đọc trực tiếp (WebFetch trả về nội dung có số).
- **[S]** số lấy từ đoạn trích kết quả tìm kiếm của trang chính thức `cloud.google.com/...` (trang giá Google Cloud bị cắt khi tải, không đọc được bảng đầy đủ; sandbox chặn curl tới cloud.google.com). Nên kiểm lại trước khi chốt ngân sách.
- **chưa xác nhận** = không lấy được từ nguồn chính thức; số kèm theo chỉ là giả định để ước tính.
Tỷ giá dùng trong file: **1 USD = 26.000 VND** (giả định, chưa xác nhận).

## 0. Hình dạng sử dụng của repo (đọc từ code)

- `app_flutter/firebase/functions/src/index.ts`: **41 callable**, **18 trigger Firestore** (`onDocumentCreated`/`onDocumentWritten`, thêm các trigger cập nhật chỉ số S02 ở #132), **7 hàm lập lịch**. Runtime nodejs22, region `asia-southeast1`, mặc định 256 MiB, `minInstances: 0` (`config.ts`).
- 7 lịch (= 7 job Cloud Scheduler):
  | Hàm | Lịch | Lần chạy/tháng |
  |---|---|---|
  | `releaseEventHolds` | every 1 minutes | ~43.200 |
  | `eventClock` | every 5 minutes | ~8.640 |
  | `bookingClock` | every 15 minutes (từ `SCHEDULE_OPTIONS`) | ~2.880 |
  | `rollNextFreeDates` | every day 00:10, Asia/Ho_Chi_Minh (#132) | 30 |
  | `purgeAwardProofs` | every day 03:00 | 30 |
  | `reconcileBadges` | 03:30 hằng ngày, Asia/Ho_Chi_Minh | 30 |
  | `pruneNotifications` | 03:45 hằng ngày, Asia/Ho_Chi_Minh | 30 |
- Secret: `PAYOUT_ACCOUNT_KEY` (Secret Manager); spec định danh nhắc mã hoá CCCD bằng KMS (Cloud KMS).
- 52 composite index trong `firestore.indexes.json`.
- Firestore và Storage: `docs/FIREBASE-SETUP.md` ghi location **asia-southeast1 (Singapore)**, không đổi được sau khi tạo.
- Bản đồ: spec `2026-10-01-remaining-screens.md` §vị trí dùng `geolocator` + geohash + haversine ở client, "không phụ thuộc bản đồ"; toạ độ chính xác không lên server. Chỉ S13.05 (đang đến, bản đồ + ETA) cần bản đồ thật.
- Watermark ảnh mẫu: Cloud Function (ứng viên `sharp`), cạnh dài 1600 px, chạy khi ảnh mẫu lên Storage tạm (`2026-10-06-delivery-preview-unlock-design.md`).
- Thanh toán qua tổ chức trung gian (VietQR/ví) và xác minh VNeID/NFC là dịch vụ ngoài Google, không tính ở đây.

## 1. Spark và Blaze

- Spark không dùng được Cloud Functions ("No invocations allowed"), không dùng App Hosting/IaaS; Cloud Storage trả 402/403 trên Spark, kể cả bucket mặc định (Blaze bắt buộc, hạn chót nâng cấp dự án cũ 2026-02-03). Nguồn **[T]**: https://firebase.google.com/pricing và https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024 (đọc 2026-10-07).
- Secret Manager và gọi mạng ra ngoài từ Function (webhook VietQR/ví, VNeID) cần Blaze, vì Functions đã cần Blaze: kết luận suy ra, trang Firebase không liệt kê riêng từng mục.
- Blaze có cùng hạn mức miễn phí: Firestore 1 GiB, 50K đọc/20K ghi/20K xoá mỗi ngày, 10 GiB egress/tháng; Functions miễn phí 2M lần gọi/tháng rồi $0.40/triệu, 400K GB-giây; Auth 50K MAU; FCM miễn phí; Hosting 10 GB lưu, 360 MB/ngày, sau đó $0.026/GB lưu và $0.15/GB truyền **[T]** https://firebase.google.com/pricing (2026-10-07). Firestore cho phép đúng một database miễn phí mỗi dự án **[T]** https://firebase.google.com/docs/firestore/pricing.
- Ngân sách: budget alert (Cloud Billing > Budgets) chỉ **báo, không dừng** chi tiêu. Giới hạn cứng: gắn budget vào topic Pub/Sub, một Cloud Function nghe topic rồi gỡ billing account khỏi dự án (Cloud Billing API `updateBillingInfo`), hậu quả là dịch vụ ngừng (Functions, Storage) và có thể mất dữ liệu; hướng dẫn "Disable billing with notifications" của Google. **chưa xác nhận** (không đọc được tài liệu này trong phiên). Khuyến nghị: alert ở 50/90/100% + quota cap trên API (Maps, Functions maxInstances) thay vì cắt billing ở production.

## 2. Cloud Firestore (Singapore)

- Hạn mức miễn phí/ngày: 50.000 đọc, 20.000 ghi, 20.000 xoá, 1 GiB lưu, 10 GiB egress/tháng **[T]** https://firebase.google.com/docs/firestore/pricing (2026-10-07). TTL delete không có hạn mức miễn phí.
- Listener: tính 1 lần đọc mỗi lần một doc trong kết quả được thêm hoặc đổi; mở lại listener sau khi ngắt quá 30 phút tính lại cả tập kết quả **[T]** cùng trang. Truy vấn rỗng tính tối thiểu 1 lần đọc.
- **Đơn giá asia-southeast1: chưa xác nhận.** Bảng giá theo location nằm ở https://cloud.google.com/firestore/pricing (không tải được). Tìm kiếm chỉ trả đoạn trích thứ cấp cho nam5: $0.06/100K đọc, $0.18/100K ghi, $0.02/100K xoá, $0.18/GiB-tháng; vùng đơn thường rẻ hơn khoảng một nửa. **Ước tính trong file này dùng cận trên nam5.**
- Egress Firestore vượt 10 GiB: theo biểu giá mạng chung, chưa xác nhận.

## 3. Cloud Functions 2nd gen (= Cloud Run)

- Request-based billing, Tier 1: $0.000024/vCPU-giây, $0.0000025/GiB-giây. Tier 2: **$0.0000336/vCPU-giây, $0.0000035/GiB-giây**; Singapore (asia-southeast1) và Jakarta thuộc Tier 2 **[S]** https://cloud.google.com/run/pricing (đọc 2026-10-07 qua tìm kiếm). Miễn phí: 180.000 vCPU-giây, 360.000 GiB-giây/tháng; $0.40/triệu request (miễn phí 2M) **[S]**; Firebase ghi miễn phí 2M lần gọi + 400K GB-giây **[T]**.
- Instance rảnh (minInstances > 0): tính theo giá "idle" thấp hơn, đơn giá chưa xác nhận. App dùng `minInstances: 0`, đánh đổi bằng cold start vài trăm ms.
- Cloud Build: có hạn mức miễn phí; số phút và giá/phút chưa xác nhận. Artifact Registry: 500 MB đầu miễn phí, trên đó tính theo GB-tháng (đơn giá chưa xác nhận, thường ~$0.10/GB) **[S]** tìm kiếm 2026-10-07. Firebase CLI >= 14: `firebase functions:artifacts:setpolicy` đặt cleanup policy (mặc định xoá image cũ hơn 1 ngày, `--days`, `--none`) **[S]** https://firebase.google.com/docs/functions/manage-functions. Với 61 hàm, mỗi hàm một image, không dọn thì Registry phình theo số lần deploy.

## 4. Cloud Scheduler, Pub/Sub, Eventarc

- Cloud Scheduler: **$0.10/job/31 ngày, 3 job miễn phí mỗi billing account** (không phải mỗi dự án) **[S]** https://cloud.google.com/scheduler/pricing (2026-10-07). 6 job của repo = 3 job tính tiền = **$0.30/tháng**; thêm cùng billing account khác (prod + dev) thì dùng chung 3 job free. Số lần chạy không tính tiền Scheduler, chỉ tính Function.
- Pub/Sub và Eventarc cho hàm lập lịch/trigger Firestore: phụ phí cho gen2 chưa xác nhận (Eventarc với nguồn sự kiện Google thường không tính riêng). Kết luận tạm: coi như không đáng kể, ghi "chưa xác nhận".

## 5. Cloud Storage for Firebase, Hosting

- Bucket mặc định mới `*.firebasestorage.app`: Blaze bắt buộc. Trang giá Firebase ghi miễn phí 5 GB lưu và 100 GB tải/tháng cho bucket mới **[T]** https://firebase.google.com/pricing, nhưng FAQ ghi bucket mới theo "Always Free" của Cloud Storage chỉ ở vùng Mỹ (us-central1/east1/west1) **[T]** https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024. **Hai nguồn mâu thuẫn; bucket Singapore giả định KHÔNG có hạn mức miễn phí.**
- Lưu Standard Singapore: **$0.020/GB-tháng** **[S]** https://cloud.google.com/storage/pricing (2026-10-07). Egress ra internet/Asia: chưa xác nhận; ước tính dùng **$0.12/GB** (giả định). Operation class A/B: chưa xác nhận, nhỏ.
- Firebase Hosting (nếu làm web dashboard Phase 1.5): $0.026/GB lưu, $0.15/GB truyền sau hạn mức **[T]** https://firebase.google.com/pricing.

## 6. Firebase Authentication / Identity Platform

- Đăng nhập Google/Facebook/ẩn danh/điện thoại: miễn phí tới 50.000 MAU; từ 50.000 đến 99.999 MAU $0.0055/MAU; OIDC/SAML $0.015/MAU từ MAU thứ 50 **[S]** https://cloud.google.com/identity-platform/pricing (2026-10-07). Chưa cần nâng lên Identity Platform ở quy mô 10.000 MAU.
- SMS xác thực: 10 SMS đầu mỗi ngày miễn phí; **Việt Nam $0.15/SMS** **[S]** (cùng trang; chưa xác nhận trực tiếp bảng giá theo nước, nên xem lại). Giới hạn Firebase Auth: 3.000 SMS/ngày, 900/phút, 50/phút và 500/giờ mỗi IP **[T]** https://firebase.google.com/docs/auth/limits. Số điện thoại test (cấu hình trong console) không tốn SMS thật.
- **Lượng SMS của S21.01 (#135)**: mỗi thợ xác minh số một lần khi bấm "Bắt đầu nhận đơn" (kèm gửi lại sau 60 giây nếu cần, và đổi số nếu nhập sai). Khách **không** nhập OTP khi đặt lịch (plan S21 Decision 21; S04.05 chưa thêm bước OTP), nên dòng "SMS" của bảng ước tính ở mục 12 (giả định 40-50% người dùng mới cần xác minh) là cận trên: chỉ người chọn làm thợ mới tốn SMS. App liên kết số bằng `linkWithCredential` (một SMS mỗi lần gửi mã); dev và emulator dùng số test, không tốn SMS thật. Chưa chạy trên điện thoại thật nên chưa có số liệu thực.
- Firebase Phone Number Verification (sản phẩm riêng): bảng giá công khai chỉ liệt kê Đức, Indonesia, Malaysia; Việt Nam chưa xác nhận.
- Phương án rẻ hơn: SMS brand name/ZNS Zalo qua nhà mạng nội địa, quanh 200-500 VND/tin (theo nguồn thứ cấp, chưa xác nhận), gắn qua Cloud Function tự xác minh.

## 7. FCM, App Check, Crashlytics, Analytics

- FCM: miễn phí cả hai gói **[T]** https://firebase.google.com/pricing. App Check: miễn phí, hạn mức theo nhà cung cấp chứng thực **[T]** cùng trang; số cụ thể của Play Integrity/App Attest chưa xác nhận. Crashlytics và Analytics: miễn phí (kiến thức chung, chưa đọc lại trang trong phiên).

## 8. Secret Manager

- **$0.06/phiên bản secret đang hoạt động/vị trí/tháng; $0.03/10.000 lần truy cập**; miễn phí 6 phiên bản hoạt động và 10.000 lần truy cập/tháng; phiên bản đã huỷ và thao tác quản lý miễn phí **[S]** https://cloud.google.com/secret-manager/pricing (2026-10-07). Vài secret nằm gọn trong hạn mức miễn phí. Cloud KMS (khoá mã hoá CCCD): đơn giá chưa xác nhận, dự kiến vài cent/tháng.

## 9. Google Maps Platform

- Từ 2025-03-01: không còn credit $200, mỗi SKU Essentials có 10.000 lượt miễn phí/tháng **[T]** https://developers.google.com/maps/billing-and-pricing/pricing (đọc 2026-10-07). Giá sau hạn mức (bậc 10.001-100.000): Dynamic Maps $7.00/1000, Geocoding $5.00/1000, Places Autocomplete Requests $2.83/1000, Place Details Essentials $5.00/1000, Static Maps $2.00/1000. Ghi chú: trang liệt kê chung một "Dynamic Maps" ở bậc này; mục "Maps SDK mobile" miễn phí không giới hạn chưa xác nhận.
- Dự án hiện **không cần** Maps cho khu vực/khoảng cách (geohash + haversine tại máy, chọn quận/thành phố thủ công). Chỉ S13.05 cần bản đồ: nằm trong 10.000 lượt/tháng ở quy mô ra mắt. Thay thế: OpenStreetMap + `flutter_map` (tile server công cộng cấm dùng tải lớn, cần nhà cung cấp tile trả phí hoặc tự host), hoặc mở app bản đồ ngoài bằng deeplink (0 đồng). Tránh Geocoding/Places từ client; nếu cần, gọi qua Function có cache.

## 10. Dịch vụ khác theo spec

- Watermark ảnh mẫu: **dùng `sharp` trong Function** (không cần Cloud Vision/ML). Chi phí chỉ là CPU/RAM; ảnh 1600 px nên cấp 512 MiB-1 GiB, khoảng 1-2 giây CPU mỗi ảnh. 3.000 booking × 10 mẫu = 30.000 ảnh/tháng ≈ 45.000 vCPU-giây ≈ $1.5 nếu hết hạn mức miễn phí.
- Cloud Vision (kiểm duyệt ảnh nếu muốn): chưa xác nhận giá (nhớ ~$1.5/1000 ảnh sau 1000 ảnh miễn phí). Cloud Tasks (hàng đợi xử lý ảnh/giao tiền trễ): chưa xác nhận (nhớ 1M thao tác đầu miễn phí). BigQuery export (Firestore/Analytics): chưa xác nhận; chỉ bật khi thật cần.

## 11. Giả định theo hành động

| Hành động | Giả định |
|---|---|
| Mở một màn danh sách/chi tiết | 20-40 lượt đọc (phân trang 20 doc, `get` thay vì listener ở màn không cần real-time) |
| Phiên dùng | 20 phiên/MAU/tháng × ~60 lượt đọc = ~1.200 lượt đọc/MAU/tháng, cộng chat/listener = 1.500 |
| Ghi mỗi booking | ~25 lượt ghi (booking, payment, trạng thái, thông báo, huy hiệu, trigger phụ) |
| Chat | 30 tin/booking × 3 lượt ghi (tin, phòng, thông báo) |
| Ghi khác | 20 lượt/MAU/tháng |
| Mỗi lần gọi Function | 0.4 giây, 0.5 vCPU, 256 MiB → 0.2 vCPU-giây, 0.1 GiB-giây |
| Ảnh (sau nén) | avatar 512 q80 ≈ 60 KB; chat 1280 q75 ≈ 150 KB; portfolio 2048 q82 ≈ 500 KB; mẫu 1600 q75 ≈ 250 KB (watermark) |
| Ảnh trước #147 | Ảnh hiện tại trước #147: 2048 px q85 ≈ 650 KB cho mọi mục đích (avatar, chat, ảnh chia sẻ, minh chứng đều như nhau); sau #147 theo bảng mục đích ở dòng "Ảnh (sau nén)" (trung bình theo tỉ lệ xem giả định ≈ 172 MB/MAU/tháng thay vì 390 MB); thumbnail chưa có (xem lưới/feed vẫn tải ảnh 2048 px; thumbnail ~400 px ~35 KB lúc tải lên là đòn bẩy egress lớn nhất còn lại, đơn vị riêng) |
| Kho ảnh | 60 ảnh portfolio/thợ; 10 mẫu/booking; 5 ảnh chat/booking |
| Xem ảnh | 600 ảnh/MAU/tháng. **Sau #147 (hiện tại): ≈ 172 MB/MAU/tháng** (mix theo mục đích, dòng "Ảnh trước #147"); trước #147 = 390 MB. **Sau thumbnail (chưa làm, đơn vị riêng): 150 KB/ảnh trung bình = 90 MB/MAU/tháng** |
| SMS | người dùng mới/tháng = 50% MAU ra mắt, 30% MAU tăng trưởng; 40-50% cần xác minh SĐT |

Đơn giá dùng: Firestore cận trên nam5 (chưa xác nhận Singapore); Functions Tier 2; Storage $0.02/GB; egress $0.12/GB (giả định); SMS VN $0.15.

## 12. Ba kịch bản hằng tháng

Hai cột: "xấu nhất" = giả định ở trên, không dọn gì; "thiết kế" = áp dụng các biện pháp §13.

### (a) Dev/staging, ~20 tester
| Hạng mục | USD |
|---|---|
| Firestore, Functions, Storage, Auth | ~0 (trong hạn mức) |
| Scheduler (nếu cùng billing account với prod thì dùng chung 3 job free) | 0-0.30 |
| Artifact Registry/Build (không dọn dẹp) | 0.5-2 |
| SMS thật | 0 (dùng số test) |
| **Tổng** | **~$1-3 ≈ 26.000-78.000 VND** |

### (b) Ra mắt: 1.000 MAU, 100 thợ, ~300 booking/tháng
| Hạng mục | Xấu nhất | Thiết kế |
|---|---|---|
| Firestore (≈1.5M đọc + lịch ≈ 2M; 100K ghi; <1 GiB) | $0.3 | $0.3 |
| Functions (~250K lần, ~50K vCPU-giây, trong hạn mức) | 0 | 0 |
| Scheduler (3 job tính tiền) | 0.3 | 0.3 |
| Secret Manager, KMS | 0.1 | 0.1 |
| Build + Artifact Registry | 2 | 0.2 |
| Storage lưu (~5 GB) + thao tác | 0.6 | 0.6 |
| Egress ảnh (xấu nhất: 172 GB sau #147, 0.12; không có hạn mức miễn phí ở Singapore) | 20.6 | 0-3 (với thumbnail, 90 GB, có thể trong 100 GB free nếu đúng trang Firebase) |
| SMS (500 người dùng mới, 300 miễn phí qua 10/ngày) | 30 | 15 |
| Maps | 0 | 0 |
| **Tổng** | **~$54 ≈ 1,4 triệu VND** | **~$20 ≈ 0,5 triệu VND** (cột này giả định thumbnail, chưa có) |

### (c) Tăng trưởng: 10.000 MAU, 1.000 thợ, ~3.000 booking/tháng
| Hạng mục | Xấu nhất | Thiết kế |
|---|---|---|
| Firestore (15M đọc, 1M ghi) | 9 | 5 (phân trang, `get`) |
| Functions (2.5M lần, ~500K vCPU-giây) | 11 | 8 |
| Scheduler + Secret + KMS | 1 | 1 |
| Build + Artifact Registry | 2 | 0.3 |
| Storage lưu (~40 GB) + thao tác | 2 | 2 |
| Egress ảnh (xấu nhất: 1.720 GB sau #147, 0.12) | 206 | 20-30 (thumbnail 25-40 KB + cache + CDN, chưa có) |
| SMS (3.000 người dùng mới; chỉ xác minh khi cần ~1.200; 300 miễn phí) | 405 | 135 (hoặc ~25 nếu SMS nội địa) |
| Watermark (sharp) | 1.5 | 1.5 |
| Maps | 0 | 0 |
| **Tổng** | **~$638 ≈ 16,6 triệu VND** | **~$175-190 ≈ 4,6-4,9 triệu VND (≈ $65-80 nếu SMS nội địa)** |

Ước tính thô, sai số cao: Firestore/egress/SMS là ba số chưa xác nhận ở nguồn chính thức. Chi phí ngoài Google (tổ chức trung gian thanh toán, VNeID/NFC, hoá đơn điện tử) không tính.

## 13. Năm động lực chi phí lớn nhất và cách thiết kế hãm lại

1. **SMS OTP** ($0.15/SMS ở VN): chỉ xác minh SĐT khi khách đặt lịch hoặc thợ nhận đơn (S21.01), không bắt lúc đăng ký; rate limit/IP; số test cho dev; cân nhắc SMS brand name nội địa hoặc Zalo.
2. **Egress ảnh Storage**: lưới và danh sách chỉ tải thumbnail (~300 px, 25-40 KB) tạo ở bước tải lên; ảnh 2048 chỉ ở màn chi tiết; ảnh chat 1280 q75; header `Cache-Control` dài (tên file chứa hash); `cached_network_image` ở client; có thể đặt CDN (Cloudflare/Hosting rewrite) phía trước.
3. **Đọc Firestore**: `get` có phân trang (cursor 20 doc) cho danh sách; listener chỉ cho chat, thông báo/huy hiệu (một doc), trạng thái booking đang mở; `limit()` mọi truy vấn; không đếm bằng đọc (dùng bộ đếm denormalized `reconcileBadges`); tắt listener khi màn không hiển thị; dùng persistence cache.
4. **Lịch chạy**: `releaseEventHolds` mỗi phút = 43.200 lần/tháng, mỗi lần ít nhất 1 lần đọc (~1.440 đọc/ngày, nuốt 3% hạn mức miễn phí) và 43.200 lần gọi Function. Nên đổi sang Cloud Tasks hẹn giờ theo từng hold, hoặc nới thành 5 phút khi quy mô còn nhỏ; thêm lịch mới ở tần suất phút phải có lý do.
5. **Function CPU**: `minInstances: 0`, `maxInstances` có trần, 256 MiB cho callable thường, chỉ hàm watermark dùng 512 MiB-1 GiB; gộp trigger `onDocumentWritten` trùng tài liệu, tránh trigger ghi lại chính doc (vòng lặp), timeout ngắn; dọn Artifact Registry sau deploy.

## 14. Quy tắc cho người viết plan

Mỗi plan phải có mục "Chi phí Google" gồm:
1. **Đọc/ghi Firestore cho từng hành động người dùng** (mở màn, gửi, duyệt): số lượt đọc/ghi, dùng `get` hay listener và vì sao, có phân trang không, có index mới không.
2. **Hàm mới và job lập lịch mới**: số callable/trigger thêm vào (số lần gọi dự kiến/tháng ở 1.000 và 10.000 MAU), bộ nhớ/timeout; mỗi lịch mới ghi **tần suất, số lần chạy/tháng, số lượt đọc mỗi lần**; từ job thứ 4 trở đi cộng $0.10/tháng; lịch dưới 5 phút cần lý do.
3. **Đường dẫn Storage mới**: kích thước ảnh sau nén, số ảnh/tháng, dung lượng lưu cộng dồn, ảnh nào có thumbnail, lượt xem/tháng nhân kích thước = egress GB, chính sách xoá/hết hạn.
4. **API trả phí mới**: Maps (SKU nào, lượt/tháng so với 10.000 miễn phí), SMS (số tin/tháng × $0.15), Vision/Cloud Tasks/KMS/Secret mới (số secret, truy cập/tháng), dịch vụ ngoài Google (ghi riêng).
5. **Kết luận**: số đô/tháng chênh thêm ở (b) và (c), đối chiếu bảng §12; nếu vượt $5/tháng ở (c) thì nêu biện pháp giảm.
6. Mọi đơn giá lấy từ file này, ghi rõ khi dùng số "chưa xác nhận"; cập nhật file này khi xác nhận được (ưu tiên: bảng Firestore Singapore, egress Storage, SMS Việt Nam, Cloud Build/Artifact Registry).
