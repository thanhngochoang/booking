# Sổ cái thực hiện: Issue #132 (S02 · Khám phá & tìm thợ)

Ngày thực hiện: 2026-10-12
Nhánh: `feat/s02-discover`
Issue: #132

---

## 1. Hạng mục đã hoàn thành theo từng Task

### Task 1: Domain pure logic (`packages/domain`)
- Triển khai `packages/domain/src/discovery_stats.ts`:
  - `computeNextFreeDate`: tính ngày rảnh đầu tiên trong [today, today + 60 ngày) không nằm trong `blocked` days.
  - `computeStartingPrice`: tìm giá dịch vụ nhỏ nhất (> 0).
  - `statsPatch`: tính patch khác biệt cho `PhotographerStats` và đảm bảo `score: 0` khi chưa có điểm.
  - `isCatalogSpecialty`: kiểm tra định dạng mã chuyên môn hợp lệ.
  - `ENGAGEMENT_FIELD`: ánh xạ `like` → `likeCount`, `save` → `saveCount`.
- Export đầy đủ từ `packages/domain/src/index.ts`.
- Tests `packages/domain/test/discovery_stats.test.ts` (14 unit tests, 100% pass, kiểm tra tính thuần khiết của domain).

### Task 2: Firestore triggers, daily rollover & backfill CLI
- Port và use cases:
  - `functions/src/domain/discovery_ports.ts`
  - `functions/src/domain/discovery_use_cases.ts`
  - `functions/src/infra/discovery_stats_firestore.ts`
- Triggers tự động (recounts & event-driven):
  - `onAvailabilityWrite`: cập nhật `stats.nextFreeDate`.
  - `onPhotographerWrite`: cập nhật `stats.nextFreeDate` khi trạng thái nhận đơn / hoàn tất hồ sơ thay đổi.
  - `onServiceWrite`: cập nhật `startingPrice` của thợ và `catalog/explore` cho chuyên môn tương ứng.
  - `onBookingWrite`: cập nhật `stats.completedCount` khi booking hoàn tất.
  - `onLikeWrite` & `onSaveWrite`: đếm lại `likeCount` và `saveCount` của bài viết `posts/{postId}`.
- Daily rollover:
  - `rollNextFreeDates`: Cloud Scheduler chạy lúc 00:10 hằng ngày (Asia/Ho_Chi_Minh) để làm mới thợ có `nextFreeDate` trước ngày hôm nay.
- CLI công cụ:
  - `functions/tools/stats.ts` (`npm run stats -- recompute`) để tính lại toàn bộ `stats`, `startingPrice`, `catalog/explore`.
- Unit tests `functions/test/unit/discovery_stats.test.ts` (11 unit tests, 100% pass).

### Task 3: Device pool cache & bookable-only query
- `CachedPhotographerRepository`:
  - Cung cấp bộ đệm trong bộ nhớ 10 phút cho pool thợ ảnh nhận đơn (`acceptingOrders == true`).
  - Single-flight asynchronous loading, xử lý lỗi không lưu cache.
  - Hàm `clearCache()` để vô hiệu hóa cache khi cần (ví dụ khi bị từ chối đặt lịch do đóng nhận đơn).
- Tích hợp `CachedPhotographerRepository` vào `photographerRepositoryProvider`.
- Unit tests: `cached_photographer_repository_test.dart` (6 unit tests, 100% pass).

### Task 4: UI Design System Mock & Screen Codes
- Bổ sung màn hình và mockup HTML vào `docs/design/ui-mock.html`:
  - `#S02.03`: Ô tìm kiếm, SegmentedTabs, lưới ô ảnh tỉ lệ 21:9 có số gói ("{n} gói"), thẻ vị trí và sự kiện.
  - `#S02.07`: Màn hình tìm kiếm khám phá phân nhóm Dịch vụ, Phong cách, Địa điểm, Thợ ảnh.
  - `#S02.07-empty`: Trạng thái không tìm thấy kết quả kèm nút "Xem tất cả thợ ảnh".
- Bổ sung `ScreenCodes.exploreSearch = 'S02.07'` vào `app_flutter/lib/core/screen_codes.dart`.
- Tests: `screen_codes_applied_test.dart` và `screen_codes_test.dart` (pass).

### Task 5: S02.03 search bar, category tiles & S02.07 search screen
- Widget:
  - `ExploreCategoryTile`: tỉ lệ 21:9, hiển thị ảnh nền, gradient phủ đáy, tiêu đề và số gói ("{n} gói" cho tab Dịch vụ).
  - `ExploreSearchScreen`: ô tìm kiếm trực tiếp với debounce 250ms, nút xoá, `AsyncView` render kết quả phân nhóm Dịch vụ, Phong cách, Địa điểm, Thợ ảnh.
  - Tích hợp pure search function `searchExplore(...)` hỗ trợ tìm kiếm không dấu (`foldVietnamese`).
- Routing:
  - Route `/explore/search` trong `app_flutter/lib/app/router.dart`.
  - Ô tìm kiếm ở đầu `ExploreScreen` mở `/explore/search`.
- Chuỗi bản địa hoá tiếng Việt `app_vi.arb`:
  - `exploreSearchHint`, `exploreSearchClear`, `exploreSearchEmptyTitle`, `exploreSearchEmptyBody`, `exploreSearchSeeAll`, `exploreSearchIdle`, `exploreCategoryPackages`.
- Tuân thủ quy chuẩn:
  - Dùng `AppIcons` và `AppIcon` (không dùng `Icons.*` trực tiếp).
  - Dùng `AsyncView` thay vì hand-written `AsyncValue.when(loading: ...)`.
- Tests: Toàn bộ test suite `test/features/explore/` (136 tests) đều pass.

### Task 6: Parity check & ghim test S02.01 / S02.02 / S02.06 với live stats
- Kiểm tra dữ liệu thật:
  - `startingPriceVnd` hiển thị "từ 1,5M" trên thẻ bài viết và thẻ thợ ảnh.
  - `completedCount` hiển thị "{n} buổi".
  - `likeCount` / `saveCount` đọc từ dữ liệu thật, cập nhật lạc quan tức thì.
  - `nextFreeDate`: hiển thị pill "Rảnh T7 này", kệ "Rảnh tuần này" ẩn khi không có thợ rảnh trong tuần.
- Ghim test trong `home_screen_test.dart` (test kệ ẩn khi `nextFreeDate: null`).

### Task 7: S02 Tomato display ("Mới · n đánh giá" & "🍅 90%+")
- Đã được sát nhập từ PR #156 (#130).
- Kiểm tra toàn bộ test suite (`test/features/discovery/`, `test/features/find/`, `test/features/photo/`, `test/core/widgets/photographer_card_test.dart`): 126 tests đều pass hoàn toàn.

### Task 8: Cập nhật tài liệu, đặc tả & sổ cái
- Cập nhật đặc tả màn hình `discovery.md`, mô hình miền `domain-model.md`, lược đồ cơ sở dữ liệu `relational-schema.md`, chi phí cloud `2026-10-07-google-cloud-costs.md`, bảng trạng thái `2026-10-01-remaining-screens.md`, thiết kế `2026-09-30-photography-marketplace-design.md`, tài liệu `services/recommender/README.md`.
- Lập sổ cái này (`ledger-s02-discover.md`).

---

## 2. Các quyết định kỹ thuật (Decisions 1–13)

1. **Recommender**: Giữ `LocalRecommender` chạy trên thiết bị cho giai đoạn 1; hoãn Cloud Run riêng và callable `recommend` cho tới khi vượt một trong các ngưỡng (≥ 5.000 thợ, p95 > 400ms, cần mô hình offline, hoặc có client web).
2. **Find pool**: Chỉ lấy thợ ảnh nhận đơn (`acceptingOrders == true`).
3. **Device cache**: Cache pool thợ ảnh trên máy trong 10 phút (`CachedPhotographerRepository`), dùng chung cho Find, Home `similar` và Search S02.07.
4. **`nextFreeDate`**: Tính toán hướng sự kiện (`onAvailabilityWrite`, `onPhotographerWrite`) kết hợp một cron rollover hằng ngày lúc 00:10 (Asia/Ho_Chi_Minh).
5. **Ngày rảnh**: Là ngày trong khoảng [hôm nay, hôm nay + 60 ngày) không có document trong `availability/{uid}/days/{day}`.
6. **"Rảnh tuần này"**: Lọc theo `acceptingOrders == true` và sắp xếp theo `stats.nextFreeDate`, `stats.score desc` (cà chua/gạch), rồi đến `uid`. Khi ghi `nextFreeDate`, nếu thiếu `score` thì tự bù `score: 0`.
7. **Recounts**: Mọi bộ đếm (`likeCount`, `saveCount`, `completedCount`, `serviceCount`, `startingPrice`) đều thực hiện đếm lại trong transaction (`query.count()`), bảo đảm tính lũy đẳng (idempotent).
8. **Bổ sung `startingPrice` & `completedCount`**: Cùng họ trigger với `nextFreeDate` nên được triển khai đồng thời trong plan này.
9. **Explore catalog**: Dùng document duy nhất `catalog/explore` được cập nhật qua trigger `onServiceWrite`. Tab Dịch vụ hiển thị số gói thật.
10. **Tìm kiếm (S02.07)**: Tìm kiếm phía máy khách bằng cách gấp âm tiếng Việt (`foldVietnamese`). Thợ ảnh tìm kiếm theo tên từ pool ≤ 200 thợ đang nhận đơn.
11. **Hiển thị quả cà chua**: Sử dụng dữ liệu từ PR #156 (#130), không làm trùng lặp.
12. **Giữ các điểm khác biệt so với mock đã được duyệt**: Huy hiệu lý do gợi ý trên feed card, số thông báo chưa đọc trên biểu tượng chat.
13. **Lịch rollover**: Job thứ 7 `rollNextFreeDates` chạy 00:10 hằng ngày, chi phí ~$0.10/tháng.

---

## 3. Thứ tự triển khai (Deployment Order)

1. **Firestore Rules & Composite Indexes**:
   - Deploy `firestore.rules` và `firestore.indexes.json` (đặc biệt composite index cho `photographers` với `acceptingOrders`, `stats.nextFreeDate`, `stats.score`).
2. **Cloud Functions**:
   - Deploy code functions bao gồm các triggers mới (`onAvailabilityWrite`, `onPhotographerWrite`, `onServiceWrite`, `onBookingWrite`, `onLikeWrite`, `onSaveWrite`) và cron `rollNextFreeDates`.
3. **Data Recomputation**:
   - Chạy script đối soát/tính toán ban đầu trên môi trường:
     `npm run stats -- recompute`
     để tính sẵn `startingPrice`, `nextFreeDate`, `completedCount` và `catalog/explore` cho dữ liệu cũ.
4. **Mobile App Release**:
   - Phát hành bản build Flutter có tính năng S02.03, S02.07 và pool cache.
