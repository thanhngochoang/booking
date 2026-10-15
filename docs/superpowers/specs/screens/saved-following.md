# S19 · Lưu & theo dõi

Màn: S19.01, S19.02, S19.03. Quy ước chung ở [README.md](README.md). Widget ở [../components/shared-components.md](../components/shared-components.md).

---

## S19.01 · Đã lưu

- **Thông tin**: `/me/saved` (`?tab=photographers` mở tab 2) · cả hai vai trò · sub‑project 3 và 6 · **Đã có** (#143)
- **Mục đích**: xem lại các bài đăng và nhiếp ảnh gia đã lưu / đánh dấu để tìm lại hoặc đặt lịch sau này.
- **Điểm vào → ra**: S09.01 (chạm ô số "đã lưu"), hoặc link trực tiếp `/me/saved`.
  - Tab Bài đăng: chạm ảnh mở chi tiết ảnh S02.02 (`/p/:id`).
  - Tab Nhiếp ảnh gia: chạm thẻ mở hồ sơ S03.01 (`/u/:uid`), chạm nút "Đặt lịch" mở luồng đặt S04.01 (`startBooking`).
- **Bố cục** (theo mock `#S19.01` và `#S19.01-photographers`):
  - Thanh tiêu đề: nút Back, tiêu đề "Đã lưu".
  - `SegmentedTabs`: "Bài · {n}" và "Nhiếp ảnh gia · {n}" (số đọc từ `socialCountsProvider`).
  - **Tab Bài**: lưới 3 cột ảnh vuông (`1:1`, `NetworkPhoto`, `AppRadius.sm`, nhãn semantics là caption hoặc "Bài đã lưu").
  - **Tab Nhiếp ảnh gia**: danh sách `PhotographerCard` dạng cuộn dọc. Mỗi thẻ có icon dấu trang `AppIcons.save` ở góc trên phải ảnh bìa, nút "Hồ sơ" và nút "Đặt lịch" (chỉ hiện khi thợ đang nhận đơn).
- **Dữ liệu**: `SavedPostsController` (`savedPostsProvider`), `SavedPhotographersController` (`savedPhotographersProvider`), `socialCountsProvider`.
  - Phân trang theo con trỏ `createdAtMicros_docId`, 30 bài / trang cho bài đăng, 20 thợ / trang cho nhiếp ảnh gia. Cuộn gần cuối (dưới 200dp) tự động tải trang tiếp. Look-ahead tối đa 3 trang nếu các mục bị xoá / ẩn.
- **Trạng thái**:
  - Loading: 9 ô vuông `AppSkeleton` cho tab Bài; danh sách skeleton cho tab Nhiếp ảnh gia.
  - Empty: "Chưa lưu bài nào" (kèm giải thích chạm biểu tượng dấu trang để lưu) hoặc "Chưa lưu nhiếp ảnh gia nào".
  - Lỗi: `AsyncView` / thông báo lỗi kèm "Thử lại". Cuộn trang kế lỗi hiện hàng "Không tải thêm được. Thử lại".
- **Tương tác**:
  - Chạm biểu tượng dấu trang trên `PhotographerCard`: bỏ lưu lạc quan, thẻ cập nhật trạng thái ngay; hiện SnackBar "Đã bỏ lưu {name}" kèm nút "Hoàn tác" để lưu lại.
  - Chuyển tab qua `SegmentedTabs` hoặc `tab` query param (`posts` | `photographers`).
- **Chuỗi tiếng Việt** (trong `app_vi.arb`):
  - `savedTitle` ("Đã lưu"), `savedTabPosts` ("Bài · {count}"), `savedTabPhotographers` ("Nhiếp ảnh gia · {count}"), `savedEmptyPostsTitle` ("Chưa lưu bài nào"), `savedEmptyPostsBody` ("Chạm biểu tượng dấu trang trên bài đăng để lưu lại xem sau."), `savedEmptyPhotographersTitle` ("Chưa lưu nhiếp ảnh gia nào"), `savedEmptyPhotographersBody` ("Lưu nhiếp ảnh gia từ trang cá nhân của họ để dễ tìm lại."), `savedUnsavePhotographerSnackbar` ("Đã bỏ lưu {name}"), `savedUndo` ("Hoàn tác").
- **Phân tích**: `screen_view{code: "s19_01"}`.
- **Chấp nhận**: bài mới lưu hiện ở đầu danh sách; bỏ lưu có hoàn tác; thợ không nhận đơn không có nút "Đặt lịch"; vừa vặn màn 320dp ở cỡ chữ 1.3x.

---

## S19.02 · Đang theo dõi

- **Thông tin**: `/me/following` · cả hai vai trò · sub‑project 6 · **Đã có** (#143)
- **Mục đích**: xem và quản lý danh sách các nhiếp ảnh gia mà mình đang theo dõi, có thể bỏ theo dõi hoặc theo dõi lại.
- **Điểm vào → ra**: S09.01 (chạm ô số "đang theo dõi"), hoặc link `/me/following`. Chạm dòng mở hồ sơ nhiếp ảnh gia S03.01 (`/u/:uid`).
- **Bố cục** (theo mock `#S19.02`):
  - Thanh tiêu đề: nút Back, tiêu đề "Đang theo dõi".
  - Dòng phụ: "{n} nhiếp ảnh gia" (đếm số đang theo dõi).
  - Danh sách dòng: Avatar tròn (`AppAvatar`), Tên hiển thị + nhãn loại nhà cung cấp / dấu xác minh, thể loại · khu vực, nút viền "Đang theo dõi" (hoặc "Theo dõi" khi đã bấm bỏ theo dõi).
- **Dữ liệu**: `FollowingController` (`followingListProvider`), `followProvider` (`FollowController.toggle`).
  - Phân trang theo con trỏ `createdAtMicros_docId`, 20 người / trang.
- **Trạng thái**:
  - Loading: skeleton danh sách.
  - Empty: "Bạn chưa theo dõi ai" kèm nút "Khám phá" chuyển hướng đến `/explore`.
  - Lỗi: thông báo lỗi kèm "Thử lại".
- **Tương tác**:
  - Bấm nút "Đang theo dõi": lập tức chuyển thành "Theo dõi", hiện SnackBar "Đã bỏ theo dõi {name}" kèm nút "Hoàn tác". Hàng vẫn giữ nguyên vị trí trên màn hình cho tới khi thoát ra và vào lại để tránh mất dấu.
  - Bấm "Hoàn tác": theo dõi lại ngay lập tức.
  - Có guard chống tap nhanh (`busy`), xử lý lỗi hoàn tác nếu ghi Firestore thất bại.
- **Chuỗi tiếng Việt** (trong `app_vi.arb`):
  - `followingTitle` ("Đang theo dõi"), `followingSubtitle` ("{count} nhiếp ảnh gia"), `followingButtonFollowing` ("Đang theo dõi"), `followingButtonFollow` ("Theo dõi"), `followingUnfollowSnackbar` ("Đã bỏ theo dõi {name}"), `followingEmptyTitle` ("Bạn chưa theo dõi ai"), `followingEmptyBody` ("Theo dõi nhiếp ảnh gia để cập nhật bài đăng mới nhất trên bảng tin."), `followingEmptyExplore` ("Khám phá").
- **Phân tích**: `screen_view{code: "s19_02"}`.
- **Chấp nhận**: danh sách sắp theo thứ tự mới theo dõi trước; bỏ theo dõi có SnackBar hoàn tác; chạm vào dòng mở đúng hồ sơ thợ; không overflow ở 320dp cỡ chữ 1.3x.

---

## S19.03 · Người theo dõi

- **Thông tin**: `/me/followers` · chỉ nhiếp ảnh gia (`photographer`, `artist`, `studio`) · sub‑project 6 · **Đã có** (#143)
- **Mục đích**: cho nhiếp ảnh gia xem danh sách khách và người dùng đang theo dõi mình (danh sách riêng tư chỉ chủ tài khoản xem được).
- **Điểm vào → ra**: S09.01 (chỉ hiện trên hồ sơ thợ ảnh: chạm ô số "người theo dõi"), hoặc link `/me/followers`. Khách hàng truy cập bị chuyển hướng về `/profile`.
- **Bố cục** (theo mock `#S19.03`):
  - Thanh tiêu đề: nút Back, tiêu đề "Người theo dõi".
  - Dòng phụ: "{n} người theo dõi · chỉ bạn xem được danh sách này".
  - Danh sách dòng: Avatar tròn, Tên hiển thị người theo dõi, phụ đề "Theo dõi từ {ngày/tháng}".
  - Các dòng không có nút hành động và không chạm mở trang cá nhân (khách hàng không có trang cá nhân công khai).
- **Dữ liệu**: `FollowersController` (`followersListProvider`), `myFollowerCountProvider` (đếm trực tiếp từ trigger / aggregation).
  - Phân trang 30 người / trang theo con trỏ `createdAtMicros_docId`.
- **Trạng thái**:
  - Loading: skeleton danh sách.
  - Empty: "Chưa có người theo dõi" kèm giải thích chia sẻ trang cá nhân hoặc đăng bài để có thêm người theo dõi.
  - Lỗi: thông báo lỗi kèm "Thử lại".
- **Tương tác**: cuộn tải thêm trang tiếp theo.
- **Chuỗi tiếng Việt** (trong `app_vi.arb`):
  - `followersTitle` ("Người theo dõi"), `followersSubtitle` ("{count} người theo dõi · chỉ bạn xem được danh sách này"), `followersSince` ("Theo dõi từ {date}"), `followersEmptyTitle` ("Chưa có người theo dõi"), `followersEmptyBody` ("Đăng bài và chia sẻ hồ sơ để kết nối với nhiều khách hàng hơn.").
- **Phân tích**: `screen_view{code: "s19_03"}`.
- **Chấp nhận**: chỉ chủ hồ sơ nhiếp ảnh gia xem được; khách truy cập bị chuyển hướng về `/profile`; định dạng ngày tháng tiếng Việt chuẩn; không có nút hành động bấm nhầm.
