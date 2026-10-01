# Khám phá và hồ sơ nhiếp ảnh gia

Màn: S01, S02, S03, S04, S13, S35, S36. Quy ước chung ở [README.md](README.md). Widget ở [../components/shared-components.md](../components/shared-components.md).

---

## S01 · Trang chủ

- **Thông tin**: `/home` · cả hai vai trò · sub‑project 3 · Chưa có (hiện là `EmptyState` trong `HomeTab`).
- **Mục đích**: cho thấy ảnh đẹp theo gu và vị trí, dẫn tới nhiếp ảnh gia còn lịch.
- **Điểm vào → ra**: tab Trang chủ. Chạm ảnh → S02; chạm tên/avatar → S03; "Xem tất cả" ở "Rảnh tuần này" → S04; biểu tượng chuông → danh sách thông báo; biểu tượng chat → danh sách hội thoại (qua S09 → S11).
- **Bố cục**: tiêu đề "Chào {tên}" + "Hôm nay chụp gì?" (Fraunces), chuông và chat (có chấm khi có chưa đọc); hàng chip danh mục (`FilterChip` kiểu ngữ cảnh: Dành cho bạn, Chân dung, Cưới, Gia đình, Kỷ yếu); một `PhotoCard` lớn 4:5; section "Rảnh tuần này" (hàng ngang `PhotoCard` 3:4 rộng 120); section "Buổi chụp thật" (lưới 2 cột ảnh khách chia sẻ). Chip lý do `ReasonChips` tối đa 2 trên thẻ lớn.
- **Dữ liệu**: `homeFeedProvider(category)` gọi `RecommendationRepository.recommendPosts` cho thứ tự "Dành cho bạn" (đến khi có, dùng `posts` theo `createdAt` và `nextFreeDate`); "Rảnh tuần này" từ `photographers` có `stats.nextFreeDate` trong 7 ngày; "Buổi chụp thật" từ `posts (kind=real_shoot)`. Phân trang 20/lần, làm mới bằng kéo xuống.
- **Trạng thái**: loading skeleton thẻ lớn + hàng ngang; empty "Chưa có ảnh nào quanh bạn" + nút "Khám phá nhiếp ảnh gia" (→ S13); lỗi `ErrorState`; offline đọc cache; chưa có vị trí vẫn hiển thị theo thành phố trong hồ sơ.
- **Tương tác**: đổi chip lọc nạp lại feed, giữ vị trí cuộn của từng chip; lưu ảnh (biểu tượng dấu trang) lạc quan, hoàn tác khi lỗi; cuộn cuối tải trang kế.
- **Chuỗi**: `s01_greeting` "Chào {name}", `s01_title` "Hôm nay chụp gì?", `s01_freeThisWeek` "Rảnh tuần này", `s01_realShoots` "Buổi chụp thật", `s01_fromCustomers` "Từ khách hàng", `s01_pillFree` "Rảnh {day} này".
- **Phân tích**: `home_chip_select{category}`, `post_open{postId, rank, source:"home"}`, `photographer_open{source:"home"}`, `post_save{postId}`.
- **Chấp nhận**: pill "Rảnh T7 này" chỉ hiện khi `nextFreeDate` đúng; 2 cột ≥ 600dp; kéo xuống làm mới; chip lọc không mất vị trí cuộn của chip khác.

---

## S02 · Chi tiết ảnh

- **Thông tin**: `/p/:postId` · cả hai · sub‑project 3 · Chưa có.
- **Mục đích**: từ một tấm ảnh tới đúng gói dịch vụ và quyết định đặt.
- **Điểm vào → ra**: S01, S03, S13, S35, link `/p/{postId}`. "Xem hồ sơ" → S03; "Đặt gói này" → S05 (đã chọn gói; qua S33 nếu thiếu số điện thoại); chia sẻ → trình chia sẻ hệ thống với link; nút `…` → báo cáo bài.
- **Bố cục**: ảnh toàn chiều rộng 3:4 (vuốt khi có nhiều ảnh, chấm trang, chạm đôi để thích); hàng tác giả (avatar, tên + `VerifiedMark`, thể loại · quận · sao, "Theo dõi"); mô tả; hàng thích/lưu/địa điểm/chia sẻ kèm số; thẻ gói (tên, mô tả ngắn, giá); "Thêm của {tên}" lưới 3 ảnh; thanh dưới cố định "Xem hồ sơ" + "Đặt gói này".
- **Dữ liệu**: `postDetailProvider(postId)`, `serviceProvider(serviceId)`; số thích/lưu từ `posts`; trạng thái thích/lưu của người xem từ `likes`, `saves`. Bài `real_shoot` đọc thêm `bookingId` để hiện "Chụp bởi {tên} · gói {gói}".
- **Trạng thái**: loading ảnh dùng blurhash; bài bị gỡ → màn "Bài đăng không còn" + nút về S01; gói đã ngừng (`active:false`) → thẻ gói mờ, nút đặt thành "Xem các gói khác" (→ S03 tab Gói); lỗi/offline theo quy ước.
- **Tương tác**: thích/lưu lạc quan; theo dõi đổi nhãn "Đang theo dõi"; "Đặt gói này" chuyển vào luồng đặt có `serviceId`, bỏ bước chọn gói.
- **Chuỗi**: `s02_book` "Đặt gói này", `s02_viewProfile` "Xem hồ sơ", `s02_follow` "Theo dõi", `s02_following` "Đang theo dõi", `s02_realShootBy` "Chụp bởi {name} · gói {service}", `s02_removed` "Bài đăng không còn".
- **Phân tích**: `post_like`, `post_save`, `post_share`, `book_start{source:"post", serviceId}`.
- **Chấp nhận**: link `/p/{id}` mở được sau đăng nhập, giữ `from`; thích/lưu hoàn tác khi lỗi; nút đặt luôn tới đúng gói của bài.

---

## S03 · Hồ sơ nhiếp ảnh gia

- **Thông tin**: `/u/:uid` · cả hai · sub‑project 2 · Chưa có.
- **Mục đích**: trả lời "người này chụp kiểu gì, đáng tin không, bao nhiêu, đặt thế nào".
- **Điểm vào → ra**: S01, S02, S04, S13, tìm kiếm, link `/u/{uid}`. "Đặt lịch" → S05 (qua S33 nếu thiếu số); nút "Nhắn tin hỏi trước" → S11 (chat `inquiry`); huy hiệu "Tất cả" → S37; "Chỉnh sửa" (chủ hồ sơ) → S24/S38/S42.
- **Bố cục**: ảnh bìa 4:3 với nút Back/chia sẻ phủ; hàng avatar lớn đè lên bìa, tên (Fraunces) + `VerifiedMark`, thể loại · quận, "Theo dõi"; hàng thống kê 4 ô (sao, buổi chụp, phản hồi, kinh nghiệm) dùng `StatTile`; bio; **hàng huy hiệu** (`BadgeChip` tối đa 3 + "Tất cả"); `SegmentedTabs` Portfolio / Gói / Lịch / Đánh giá; thanh dưới nút chat "Nhắn tin hỏi trước" + "Đặt lịch · từ {giá}" (chưa có gọi/Zalo/WhatsApp, các kênh đó chỉ mở sau khi đã đặt).
- **Dữ liệu**: `photographerProfileProvider(uid)` gộp `photographers/{uid}`, `services`, `stats`, huy hiệu; tab Portfolio từ `posts (photographerId)` masonry 2 cột; tab Gói từ `services (active)`; tab Lịch dùng `AvailabilityCalendar` chỉ đọc trên `availability/{uid}/days`; tab Đánh giá từ `reviews (photographerId)` phân trang. Mục "Thợ ảnh tương tự" ở cuối tab Portfolio lấy từ `RecommendationRepository.similar`.
- **Trạng thái**: chưa có portfolio → empty "Chưa có ảnh nào"; chưa có đánh giá → "Chưa có đánh giá"; chưa có gói → nút Đặt lịch vô hiệu kèm "Nhiếp ảnh gia chưa đăng gói"; hồ sơ chưa hoàn tất không hiển thị công khai; chủ hồ sơ xem thấy nút chỉnh sửa và độ khớp hồ sơ.
- **Tương tác**: chạm ảnh → S02; tab giữ trạng thái khi cuộn; chia sẻ link `/u/{uid}`; ngày "Chờ" xem được không chọn được.
- **Chuỗi**: `s03_book` "Đặt lịch · từ {price}", `s03_tabPortfolio` "Portfolio", `s03_tabServices` "Gói", `s03_tabCalendar` "Lịch", `s03_tabReviews` "Đánh giá", `s03_similar` "Thợ ảnh tương tự", `s03_noServices` "Nhiếp ảnh gia chưa đăng gói".
- **Phân tích**: `photographer_open{source}`, `inquiry_open{source:"S03"}`, `book_start{source:"profile"}`, `profile_tab{tab}`.
- **Chấp nhận**: không lộ số điện thoại; tích xanh chỉ khi `verified`; thanh dưới không che nội dung cuối; thống kê thiếu dữ liệu hiện "—".

---

## S04 · Tìm thợ ảnh

- **Thông tin**: `/action` (khách) · khách · sub‑project 3 · Chưa có (hiện là empty trong `ActionTab`).
- **Mục đích**: so sánh nhiếp ảnh gia theo khu vực, ngày, dịch vụ, giá, sao.
- **Điểm vào → ra**: tab giữa (khách), S13. Thẻ → S03; "Đặt T7" → S06 (ngày và dịch vụ sẵn; qua S33 nếu thiếu số); biểu tượng ghim → S36.
- **Bố cục**: tiêu đề + biểu tượng ghim; hàng chip lọc đã điền (`FilterChip` kiểu bộ lọc: khu vực·bán kính, ngày, dịch vụ, giá, ★); dòng đếm "12 nhiếp ảnh gia rảnh thứ 7"; sắp xếp mặc định **Phù hợp nhất** (chip đổi: Gần tôi, Giá, Đánh giá); danh sách `PhotographerCard` (ảnh hero 16:9, pill rảnh, hàng avatar/tên/meta/giá từ, nút Hồ sơ + Đặt) kèm `ReasonChips`.
- **Dữ liệu**: `searchPhotographersProvider(filters)` gọi `RecommendationRepository.recommendPhotographers` với `specialty`, `date`, `geohash6`, `budgetMax`; sắp xếp khác "Phù hợp nhất" xử lý ở dịch vụ truy vấn thường. Phân trang bằng `cursor`. Khu vực mặc định từ vị trí đã cho phép hoặc khu vực đã chọn ở S36.
- **Trạng thái**: loading skeleton thẻ; không kết quả → "Chưa có ai khớp bộ lọc" + "Xoá bộ lọc" + gợi ý nới bán kính; dịch vụ gợi ý lỗi → tự dùng `LocalRecommender` và hiện dải nhỏ "Đang xếp theo sao và khoảng cách"; offline đọc kết quả cuối.
- **Tương tác**: chạm chip mở sheet chọn giá trị (khu vực, ngày dùng `AvailabilityCalendar`, dịch vụ, khoảng giá, sao); thay đổi lọc nạp lại và giữ lựa chọn khi quay về; thẻ có ngày kín bị loại khi đã chọn ngày.
- **Chuỗi**: `s04_title` "Tìm thợ ảnh", `s04_count` "{n} nhiếp ảnh gia rảnh {day}", `s04_sortBest` "Phù hợp nhất", `s04_sortNear` "Gần tôi", `s04_noResult` "Chưa có ai khớp bộ lọc", `s04_clear` "Xoá bộ lọc", `s04_bookDay` "Đặt {day}", `s04_fallbackNote` "Đang xếp theo sao và khoảng cách".
- **Phân tích**: `search_filter_change{key}`, `search_sort{value}`, `reco_impression{requestId, rank}` (qua `recommendFeedback`), `photographer_open{source:"find", rank}`.
- **Chấp nhận**: nhiều chip lọc áp dụng đồng thời; số đếm khớp số thẻ; mỗi thẻ có lý do ≤ 2 chip; 2 cột ≥ 600dp; dự phòng hoạt động khi dịch vụ lỗi.

---

## S13 · Khám phá (chưa hỏi vị trí)

- **Thông tin**: `/explore` · cả hai · sub‑project 3 · Chưa có.
- **Mục đích**: bốn lối vào bằng hình (dịch vụ, địa điểm, phong cách, nhiếp ảnh gia) và sự kiện.
- **Điểm vào → ra**: tab Khám phá (có chấm số sự kiện mới, xoá khi mở). Ô tìm kiếm → màn kết quả; ô ảnh → danh sách đã lọc (S04 với bộ lọc); "Xem tất cả" sự kiện → S15; "Cho phép" → hộp thoại quyền vị trí.
- **Bố cục**: tiêu đề + chuông; ô tìm kiếm; `SegmentedTabs` Dịch vụ / Địa điểm / Phong cách / Thợ ảnh; lưới ô ảnh (21:9) có tên và số gói; `LocationPromptCard` "Sự kiện gần bạn" (Cho phép / Để sau); section "Sự kiện chụp ảnh" (hàng ngang `EventCard` nhỏ).
- **Dữ liệu**: `exploreCategoriesProvider(tab)` từ `taxonomy` kèm số gói; `upcomingEventsProvider`; trạng thái quyền từ `locationControllerProvider`; số chấm tab từ `tabBadgesProvider` (sự kiện mới từ lần mở gần nhất, `exploreSeenAt`).
- **Trạng thái**: trạng thái vị trí: `chưa hỏi` (thẻ) → `đã cho phép` (chuyển sang bố cục S35) → `từ chối/để sau` (thu thẻ thành chip "Chọn khu vực" → S36); không có sự kiện sắp tới → ẩn section; tìm kiếm không kết quả → empty có gợi ý; lỗi/offline theo quy ước.
- **Tương tác**: **chỉ** nút "Cho phép" gọi hộp thoại quyền, không hỏi lúc mở app; "Để sau" ghi nhớ 7 ngày rồi mới hiện lại thẻ; mở tab xoá chấm số và ghi `exploreSeenAt`.
- **Chuỗi**: `s13_title` "Khám phá", `s13_search` "Tìm dịch vụ, địa điểm, tên thợ ảnh", `s13_nearTitle` "Sự kiện gần bạn", `s13_nearBody` "Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.", `s13_allow` "Cho phép", `s13_later` "Để sau", `s13_events` "Sự kiện chụp ảnh".
- **Phân tích**: `explore_tab{tab}`, `location_prompt{action:"allow"|"later"}`, `location_result{status}`, `event_open{source:"explore"}`.
- **Chấp nhận**: không có hộp thoại quyền khi chưa bấm "Cho phép"; chấm số tab xoá khi mở; thẻ vị trí không hiện lại ngay sau "Để sau".

---

## S35 · Khám phá, đã bật vị trí

- **Thông tin**: `/explore` (cùng route S13) · cả hai · sub‑project 3 · Chưa có.
- **Mục đích**: gợi ý sự kiện quanh người dùng, sắp theo khoảng cách.
- **Điểm vào → ra**: S13 sau khi cho phép vị trí; hoặc khi đã có khu vực lưu. "Đổi" → S36; "Xem tất cả" → S15; thẻ → S16.
- **Bố cục**: dòng "Quanh {khu vực} · vị trí gần đúng" + "Đổi"; chip bán kính 10/25/50 km (mặc định 25), "Tuần này", "Cuối tuần", "Không thu phí"; section "Sự kiện gần bạn" với `EventCard` nổi bật rồi danh sách; các khối Khám phá còn lại cuộn bên dưới.
- **Dữ liệu**: `nearbyEventsProvider(area, radius, filters)`; lấy geohash 5 và 8 ô lân cận từ vị trí gần đúng, lọc và sắp theo khoảng cách ở client; khoảng cách làm tròn 0,1 km; làm mới vị trí nếu cũ hơn 30 phút (dùng bản cũ trong lúc chờ); quá 8 giây không có vị trí → khu vực đã lưu hoặc S36.
- **Trạng thái**: không có sự kiện trong bán kính → "Chưa có sự kiện gần bạn" + "Tăng bán kính" (+ NAG: "Tạo sự kiện"); dịch vụ vị trí tắt giữa chừng → chuyển trạng thái từ chối; offline đọc cache.
- **Tương tác**: đổi chip lọc nạp lại; "Đổi" mở S36; kéo xuống làm mới vị trí.
- **Chuỗi**: `s35_around` "Quanh {area} · vị trí gần đúng", `s35_change` "Đổi", `s35_radius` "{km} km", `s35_none` "Chưa có sự kiện gần bạn", `s35_widen` "Tăng bán kính".
- **Phân tích**: `events_nearby_load{radius, count}`, `event_open{source:"nearby", rank}`.
- **Chấp nhận**: toạ độ chính xác không rời máy (kiểm tra bằng test không gọi mạng với toạ độ); thứ tự đúng theo khoảng cách; khoảng cách khớp tính tay ±0,1 km.

---

## S36 · Chọn khu vực thủ công

- **Thông tin**: `/explore/area` (sheet) · cả hai · sub‑project 3 · Chưa có.
- **Mục đích**: dùng được "gần bạn" khi không bật vị trí.
- **Điểm vào → ra**: từ S13 ("Để sau"/chip "Chọn khu vực"), S35 ("Đổi"), S04 (biểu tượng ghim). Xong → trở lại màn gọi.
- **Bố cục**: `AppBottomSheet`: tiêu đề "Chọn khu vực của bạn", giải thích, danh sách radio quận/thành (từ `taxonomy/areas`), ô tìm kiếm khi > 8 mục, nút phụ "Mở Cài đặt để bật vị trí" (chỉ khi từ chối vĩnh viễn), nút chính "Dùng khu vực này".
- **Dữ liệu**: `areasProvider`; lưu `SharedPreferences` `area` (tên + geohash 5), không gửi server.
- **Trạng thái**: chưa chọn → nút chính vô hiệu; đã có khu vực → chọn sẵn; lỗi tải danh sách → dùng danh sách tích hợp sẵn.
- **Tương tác**: chọn xong đóng sheet và nạp lại màn gọi; "Mở Cài đặt" gọi `Geolocator.openAppSettings`; vuốt xuống đóng không đổi gì.
- **Chuỗi**: `s36_title` "Chọn khu vực của bạn", `s36_body` "Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.", `s36_openSettings` "Mở Cài đặt để bật vị trí", `s36_use` "Dùng khu vực này".
- **Phân tích**: `area_select{areaId}`, `location_settings_open`.
- **Chấp nhận**: khu vực nhớ giữa các lần mở app; S04 và S15 dùng cùng khu vực; không yêu cầu quyền nào.
