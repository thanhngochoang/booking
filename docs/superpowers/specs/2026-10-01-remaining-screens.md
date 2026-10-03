# Spec — Các màn hình còn lại, Sự kiện, liên hệ, vị trí và huy hiệu (Flutter)

Ngày: 2026-10-01 · Branch: `flutter-rewrite` · Trạng thái: chờ review

Bổ sung cho `2026-09-30-photography-marketplace-design.md` (gọi tắt "spec gốc"). Spec này làm các việc:

1. Chốt giao diện theo theme **dark aurora** đang chạy trong app, kèm hai kiểu nút chính (gradient theo theme, hoặc ảnh avatar làm mờ).
2. Đánh **mã màn hình** `S01–S23` để tham chiếu nhanh giữa mock, spec, code và báo lỗi.
3. Đặc tả mọi màn còn lại, kèm danh mục **Sự kiện** và luồng **tạo sự kiện chụp ảnh** (mới).
4. Thêm **kênh liên hệ** (gọi điện, Zalo, WhatsApp) và điều kiện **khách phải có số điện thoại** để đặt lịch (xác minh số làm sau).
5. Thêm **GPS ở Khám phá** để gợi ý sự kiện gần bạn.
6. Đổi **Verified** thành dấu tích xanh nhỏ, và thêm **huy hiệu** cho người dùng (từ đánh giá hoặc từ hệ thống).
7. Thêm màn **thu thập kỹ năng** của nhiếp ảnh gia (S08.02–S08.04) và một **dịch vụ gợi ý chạy riêng** (`services/recommender`) để thuật toán nâng cấp độc lập với ứng dụng.
10. **Sự kiện có timeline gom bài theo hashtag và một nhóm chat riêng** cho người tham gia (mục 3.7, màn S11.05, S11.06).
9. **Tiền treo (escrow)**: mọi khoản cọc và vé nằm ở nền tảng, chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp / sự kiện hoàn thành để hoàn tiền dễ (mục 3g, màn S06.05, S06.06).
8. Đặc tả chi tiết **từng màn hình** (S01.03–S01.05, S02, S03, S04, S05, S06, S07.01, S08, S09, S10, S11, S12) trong `docs/superpowers/specs/screens/` và **shared component** trong `docs/superpowers/specs/components/shared-components.md`.

Mock hi‑fi: https://claude.ai/artifact/LptNpoqnt5KjQ5tUaPjYDM (bật nút "Debug" để thấy mã ở góc trên trái mỗi màn; thêm `#S05.05` vào link để nhảy tới màn; có công tắc Tối/Sáng và Nút gradient/avatar).

---

## 1. Theme

Nguồn: `design-system/tokens.json` → `lib/core/theme/tokens.g.dart` (sinh bằng `dart run tool/gen_tokens.dart`) → `app_theme.dart`. Mock dùng đúng các giá trị này.

| Mục | Quy tắc |
|-----|---------|
| Nền | Mọi màn bọc trong `AuroraBackground`, `Scaffold` trong suốt. Tối là mặc định (`ThemeModeController`). |
| Màu | Canvas `0B0B10`, surface `17151F`, primary `B08AFF` (tối) / `8338F5` (sáng), focus cyan `14E0F5` (tối). |
| Nút chính | `AppButton.primary`, **một nút mỗi màn**, tô bằng `CtaSurface` (hai kiểu bên dưới). Phụ: `AppButton.outline` hoặc nút kính. Huỷ/từ chối: nút đỏ trong sheet xác nhận, hoặc `AppButton.text` đỏ. |
| Thẻ | `GlassCard` (radius 28, blur 24). Viền spectrum (`highlight: true`) chỉ cho **một thẻ chính mỗi màn**. Thẻ list thường dùng `highlight: false`. |
| Chữ | Fraunces 600 cho tiêu đề màn, tên section, số lớn; Be Vietnam Pro cho phần còn lại. Số tiền, ngày giờ dùng `FontFeature.tabularFigures()`. Cả hai font đã kiểm tra đủ glyph tiếng Việt (kể cả `ẳ ữ ệ ₫`). |
| Hình khối | Radius 8 (ảnh nhỏ) · 16 (nút, input; `controlRadius`) · 20 (card) · 28 (kính, sheet). Lưới 4dp. |
| Tab giữa | Vòng tròn 36dp tô bằng `CtaSurface` (cùng kiểu nút chính). |
| Mờ ảnh cho modal và trang giới thiệu | Xem mục 1.2: nền sau sheet/dialog là **ảnh nền đã làm mờ**; trang có ảnh chủ đạo (hồ sơ, sự kiện, đăng nhập) có lớp mờ ảnh lan xuống nền phía sau nội dung. |
| Thanh tab dưới | `NavigationBar` cao **64dp** (Material 3 mặc định 80dp), nhãn luôn hiện, chấm số qua `TabBadge`. Đã làm trong `app_theme.dart`. |

Hai điểm khác bản mock đầu: (a) chip đã chọn trong *bộ lọc* là nền primary đặc, chip *lựa chọn đơn / ngữ cảnh* là nền `primarySubtle` + viền primary; (b) badge "Sắp tới" (vàng) dùng chữ tối (`BookingStatusX.onColor`).

### 1.1 Hai kiểu nút chính

`ButtonStyleMode` lưu `SharedPreferences` khóa `buttonStyle`, chọn ở Cài đặt (S09.02), mặc định `gradient`.

| Kiểu | Cách vẽ | Ghi chú |
|------|---------|---------|
| `gradient` | Tối: `ctaStart → ctaMid → ctaEnd` (xanh, tím, hồng). Sáng: gradient **cùng tông tím** `8338F5 → 702BDB` (135°), bóng `0 4px 12px` tím 25% | Lý do chế độ sáng: dải đủ màu cạnh tranh với vầng sáng pastel của nền và làm rối mắt. Token `cta-light-start/end`. |
| `avatar` | Ảnh avatar → nâng sáng về 55–100% → blur σ12 → **nhân** (`BlendMode.modulate`) với gradient của theme | Cần `avatarUrl`. Chưa có thì tự dùng `gradient`, dòng chọn ở S09.02 bị khóa kèm lời nhắc "Thêm ảnh đại diện trong hồ sơ để dùng kiểu này." |

Vì phép nhân chỉ làm tối, nút avatar không bao giờ sáng hơn gradient; chữ trắng giữ tương phản của gradient (≥ 4,7:1 dải tối, ≥ 5,5:1 dải sáng) với mọi ảnh. Trong lúc ảnh tải hoặc lỗi, gradient nằm bên dưới nên nút không bao giờ trống. Áp dụng cho `AppButton.primary` và đĩa tab giữa; không áp dụng cho chi tiết nhỏ (ngày chọn, bong bóng chat, thanh tiến độ).

**Đã làm trong code** (`flutter analyze` sạch, 92 test qua): `CtaSurface`, `CtaAvatarScope` (đặt trên `MaterialApp.builder`, nhận avatar từ `main.dart`), `ctaGradientFor`, token `cta-light-*`, `ButtonStyleController`, mục "Kiểu nút chính" ở Cài đặt, `AppButton` và `TabShell` dùng `CtaSurface`, test `cta_surface_test.dart`. Cùng đợt, `AuroraHero` thêm đệm quanh dòng chữ gradient và `height 1.2`, vì mask chỉ cao bằng dòng chữ nên dấu thanh xếp chồng của tiếng Việt (ổ, ụ, ặ) dễ bị cắt.

### 1.2 Mờ ảnh cho modal và trang giới thiệu

Để phân biệt lớp và tạo chiều sâu, dùng **mờ ảnh** (không dùng để người dùng chọn ảnh nền riêng; xem câu hỏi mở 9 đã chốt).

| Dùng ở | Cách làm | Quy tắc |
|--------|----------|---------|
| **Modal** (mọi `AppBottomSheet` và dialog: S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05, S08.04, sheet xác nhận) | `BlurScrim`: `BackdropFilter` blur σ12–16 trên **chính màn phía sau**, phủ tối nhẹ (tối 35%, sáng đen 25%) thay cho lớp tối phẳng; sheet là mặt kính `surface` ~92% mờ đục + blur 24 | Chữ trong sheet luôn nằm trên mặt gần đặc nên tương phản đo trên mặt sheet, không đo trên ảnh mờ |
| **Trang giới thiệu có ảnh chủ đạo** (S03.01 ảnh bìa, S11.02 ảnh bìa sự kiện, S01.03 đăng nhập, về sau S02.02) | `ImageBackdrop`: chính ảnh chủ đạo, phóng 1,3×, blur σ24, tăng bão hoà 130%, độ mờ đục 50%, nhuộm lên `aurora`, tan dần xuống nền (mặt nạ gradient) và nằm **sau** nội dung | Ảnh mờ chỉ ở nền; mọi chữ nằm trên `GlassCard`/nền tối ưu hoặc có lớp phủ đạt ≥ 4,5:1 |
| Trang không có ảnh (S01.05 và đa số màn khác) | Giữ `AuroraBackground` | Không thêm ảnh ngẫu nhiên |

- **Hiệu năng**: `BackdropFilter` đắt. Mỗi màn tối đa **một** lớp mờ sống động; `ImageBackdrop` được lưu thành ảnh đã mờ trước (`RepaintBoundary` + cache) thay vì mờ mỗi khung hình; máy yếu (RAM thấp/`isLowRamDevice`) dùng lớp tối phẳng.
- **Truy cập**: bật "tương phản cao" (`AccessibilityFeatures.highContrast`) hoặc giảm chuyển động nặng → thay bằng lớp tối đặc, không mờ. Ảnh nền là trang trí, `ExcludeSemantics`.
- **Chuyển động**: scrim mờ dần vào cùng lúc sheet trượt lên (240ms), thoát nhanh hơn (140ms); không hoạt ảnh liên tục.

## 2. Mã màn hình

Mỗi `Sxx` là một **use case** (một luồng việc trọn vẹn của người dùng); mỗi màn trong use case có mã `Sxx.yy` (ví dụ `S04.02` là bước Ngày & giờ của use case Đặt lịch). Sheet, trạng thái riêng của một route và popover cũng có mã riêng khi người dùng nhìn thấy như một màn. Màn mới lấy số `.yy` kế tiếp trong use case của nó; use case mới lấy `Sxx` kế tiếp. Không đánh lại số trong một use case; màn bị bỏ để lại chỗ trống. Cột "Mã cũ" là mã phẳng `S01`–`S67` dùng trước ngày 2026-10-02 (commit, ledger và plan đã chạy vẫn ghi mã cũ); công cụ đổi mã ở `scripts/tools/screen_code_map.py`.

| Mã | Màn hình | Route | Vai trò | Sub‑project | Trạng thái (2026-10-02) | Mã cũ |
|----|----------|-------|---------|-------------|------------|-------|
| **S01** | **Vào app & tài khoản** | | | | | |
| S01.01 | Splash (khôi phục phiên, tải hồ sơ) | `/splash` | — | 1 · **đã có** | ✅ đã làm | S66 |
| S01.02 | Lỗi phiên (không tải được hồ sơ) | `/session-error` | — | 1 · **đã có** | ✅ đã làm | S67 |
| S01.03 | Đăng nhập | `/login` | — | 1 · **đã có** | ✅ đã làm | S28 |
| S01.04 | Đăng ký | `/register` | — | 1 · **đã có** | ✅ đã làm | S41 |
| S01.05 | Chọn vai trò | `/onboarding/role` | — | 1 · **đã có** | ✅ đã làm | S29 |
| **S02** | **Khám phá & tìm thợ** | | | | | |
| S02.01 | Trang chủ | `/home` | cả hai | 3 | ✅ đã làm (3b4) | S01 |
| S02.02 | Chi tiết ảnh | `/p/:postId` | cả hai | 3 | ✅ đã làm (3b4) | S02 |
| S02.03 | Khám phá (chưa hỏi vị trí) | `/explore` | cả hai | 3 | ✅ đã làm · khớp mock (mock-parity-1) | S13 |
| S02.04 | Khám phá, đã bật vị trí | `/explore` | cả hai | 3 | ✅ đã làm · khớp mock (mock-parity-1) | S35 |
| S02.05 | Chọn khu vực thủ công (sheet) | `/explore/area` | cả hai | 3 | ✅ đã làm · khớp mock (mock-parity-1) | S36 |
| S02.06 | Tìm thợ ảnh | `/action` (khách) | khách | 3 | ✅ đã làm (3b4) · mock thiếu hàng sắp xếp và ghi chú fallback | S04 |
| **S03** | **Xem hồ sơ nhiếp ảnh gia** | | | | | |
| S03.01 | Hồ sơ nhiếp ảnh gia | `/u/:uid` | cả hai | 2 | ✅ đã làm (2d2) · lệch mock: không nút chia sẻ, lưới vuông thay masonry | S03 |
| S03.02 | Huy hiệu | `/u/:uid/badges` | cả hai | 6 | ⬜ chưa có plan (huy hiệu) | S37 |
| **S04** | **Đặt lịch** | | | | | |
| S04.01 | Đặt lịch 1/4 · Gói | `/u/:uid/book` (bước `service`) | khách | 4 | ✅ đã làm (4b) · bước địa điểm chưa có bản đồ | S05 |
| S04.02 | Đặt lịch 2/4 · Ngày & giờ | bước `datetime` | khách | 4 | ✅ đã làm (4b) · bước địa điểm chưa có bản đồ | S06 |
| S04.03 | Đặt lịch 4/4 · Xem lại & cọc | bước `review` (bước 3 Địa điểm dùng chung layout S04.01) | khách | 4 | ✅ đã làm (4b) · bước địa điểm chưa có bản đồ | S07 |
| S04.04 | Chờ thanh toán | `/b/:id/pay` | khách | 4 | ✅ đã làm (4b) · về S05.02 (4c) | S08 |
| S04.05 | Thêm số điện thoại (sheet) | `/profile/phone?returnTo=…` | khách | 2 | ✅ đã làm · khớp mock (mock-parity-1) | S33 |
| **S05** | **Theo dõi buổi chụp (khách)** | | | | | |
| S05.01 | Danh sách đặt lịch | `/bookings` (khách) | khách | 4 | ✅ đã làm (4c) · ẩn tab Vé sự kiện tới khi có S11.04 | S14 |
| S05.02 | Chi tiết booking | `/b/:id` | cả hai | 4 | ✅ đã làm (4c) · Nhắn tin/Đổi lịch/Đánh giá chờ 4d–4e | S09 |
| S05.03 | Huỷ booking (sheet) | `/b/:id/cancel` | khách | 4 | ✅ đã làm (4c) | S10 |
| S05.04 | Liên hệ **sau khi đã đặt** (nút nhỏ bung gọi/Zalo/WhatsApp, không phải sheet) | — (popover, không có route) | cả hai | 2 | ✅ đã làm (`ContactDial`, plan 2b) | S32 |
| S05.05 | Đánh giá & chia sẻ | `/b/:id/review` | khách | 6 | ⬜ chưa có plan (đặt lịch / công việc) | S12 |
| **S06** | **Nhận việc (nhiếp ảnh gia)** | | | | | |
| S06.01 | Công việc | `/bookings` (nhiếp ảnh gia) | NAG | 5 | ✅ đã làm (4c) · ẩn Sự kiện của tôi | S19 |
| S06.02 | Empty state Công việc | `/bookings` khi trống | NAG | 1 (đã có dạng chung) | ✅ đã làm (4c) | S22 |
| S06.03 | Từ chối yêu cầu (sheet) | `/b/:id/decline` | NAG | 5 | ✅ đã làm (4c) | S23 |
| S06.04 | Lịch của tôi | `/work/calendar` | NAG | 2 | ✅ đã làm (2d1) | S20 |
| S06.05 | Thu nhập (đang giữ, sắp nhận, đã nhận) | `/work/earnings` | NAG | 5 | ⬜ chưa có plan (đặt lịch / công việc) | S43 |
| S06.06 | Tài khoản nhận tiền | `/work/earnings/account` | NAG | 5 | ⬜ chưa có plan (đặt lịch / công việc) | S44 |
| **S07** | **Hội thoại** | | | | | |
| S07.01 | Hội thoại | `/chat/:chatId` | cả hai | 4 | ⬜ chưa có plan (đặt lịch / công việc) | S11 |
| S07.02 | Danh sách hội thoại | `/chats` | cả hai | 4d | ⬜ plan 4d | — (mới) |
| **S08** | **Thiết lập hồ sơ nhiếp ảnh gia** | | | | | |
| S08.01 | Thiết lập hồ sơ, bước 1–2 (giới thiệu, gói) | `/setup/:step` | NAG | 2 | ✅ đã làm (2d1) | S24 |
| S08.02 | Kỹ năng, phần 1 (thể loại, mức độ) · bước 3/4 | `/setup/3`, `/profile/skills` | NAG | 2 | ✅ đã làm (2c) | S38 |
| S08.03 | Kỹ năng, phần 2 (phong cách, kỹ năng thêm, ngôn ngữ, khách phù hợp) | cùng màn S08.02, cuộn xuống | NAG | 2 | ✅ đã làm (2c) | S39 |
| S08.04 | Minh chứng kỹ năng (sheet) | `/profile/skills/evidence?skill=…` | NAG | 2 | ✅ đã làm (2c) | S40 |
| S08.05 | Thiết lập hồ sơ, bước 4/4 (khu vực, liên hệ) | `/setup/4` | NAG | 2 | ✅ đã làm · khớp mock (mock-parity-1) | S34 |
| **S09** | **Hồ sơ cá nhân & cài đặt** | | | | | |
| S09.01 | Hồ sơ cá nhân (bài đăng của mình) | `/profile` | cả hai | 1 · **đã có**, làm lại ở 3 | 🟡 code cũ (thẻ hồ sơ + đổi vai trò) · **lệch mock**: mock mới là lưới bài đăng, đổi vai trò và đăng xuất đã sang S09.02 | S30 |
| S09.02 | Cài đặt | `/settings` | cả hai | 1 · **đã có**, thêm kiểu nút, chế độ, đăng xuất | 🟡 **lệch mock**: thiếu nhóm Chế độ, Số điện thoại, Đăng xuất; giao diện và kiểu nút đổi sang `SegmentedTabs` | S31 |
| S09.03 | Sửa hồ sơ | `/settings/profile` | cả hai | 1 · **đã có**, thêm ảnh đại diện, số điện thoại và công tắc liên hệ | ✅ đã làm · khớp mock (mock-parity-1) | S42 |
| **S10** | **Đăng bài** | | | | | |
| S10.01 | Đăng bài | `/action` (NAG) | NAG | 3 | ✅ đã làm (3c) | S21 |
| **S11** | **Tham gia sự kiện** | | | | | |
| S11.01 | Danh sách sự kiện | `/events` | cả hai | 3b | ⬜ chưa có plan (sự kiện) | S15 |
| S11.02 | Chi tiết sự kiện | `/e/:eventId` | cả hai | 3b | ⬜ chưa có plan (sự kiện) | S16 |
| S11.03 | Đăng ký sự kiện (sheet) | `/e/:eventId/join` | khách | 3b | ⬜ chưa có plan (sự kiện) | S17 |
| S11.04 | Vé sự kiện | `/bookings?tab=events` | khách | 3b | ⬜ chưa có plan (sự kiện) | S18 |
| S11.05 | Timeline sự kiện (bài theo hashtag) | `/e/:eventId/timeline` (cũng là tab ở S11.02) | cả hai | 3b | ⬜ chưa có plan (sự kiện) | S45 |
| S11.06 | Nhóm chat sự kiện | `/e/:eventId/chat` | thành viên (người đăng ký, chủ sự kiện, staff) | 3b | ⬜ chưa có plan (sự kiện) | S46 |
| **S12** | **Tổ chức sự kiện** | | | | | |
| S12.01 | Tạo sự kiện 1/2 | `/events/new` (bước `info`) | NAG · admin · sales | 3b | ⬜ chưa có plan (sự kiện) | S25 |
| S12.02 | Tạo sự kiện 2/2 | bước `schedule` | NAG · admin · sales | 3b | ⬜ chưa có plan (sự kiện) | S26 |
| S12.03 | Quản lý sự kiện | `/events/:eventId/manage` | NAG chủ · admin · sales (người tạo) | 3b | ⬜ chưa có plan (sự kiện) | S27 |
| **S13** | **Chụp ngay (khách)** | | | | | |
| S13.01 | Chụp ngay: gói, kiểu chụp, điểm hẹn, giá; "Xem nhiếp ảnh gia phù hợp" | `/instant` | khách | I5 | ⬜ plan I5 | S47 |
| S13.02 | Chụp ngay: vuốt chọn nhiếp ảnh gia (5 thẻ) | `/instant/:id` (`choosing`) | khách | I5 | ⬜ plan I5 (viết lại) | — (mới) |
| S13.03 | Đang chờ trả lời (người đã mời, trạng thái từng người) | `/instant/:id` (`searching`) | khách | I5 | ⬜ plan I5 | S48 |
| S13.04 | Đã match (chuyển tiếp, cả hai bên) | — (lớp phủ trên S13.05/S14.03) | cả hai | I4 · I5 | ⬜ plan I4 · I5 (viết lại) | — (mới) |
| S13.05 | Đã có người nhận / đang đến (bản đồ, ETA) | `/instant/:id` (`assigned`…`arrived`) | khách | I5 | ⬜ plan I5 | S49 |
| S13.06 | Đang chụp / chờ xác nhận hoàn thành | `/instant/:id` (`in_progress`) | khách | I5 | ⬜ plan I5 | S50 |
| S13.07 | Không tìm được người | `/instant/:id` (`no_match`) | khách | I5 | ⬜ plan I5 | S51 |
| S13.08 | Huỷ chụp ngay (sheet) | `/instant/:id/cancel` | cả hai | I4 · I5 | ⬜ plan I4 · I5 | S55 |
| **S14** | **Chụp ngay (nhiếp ảnh gia)** | | | | | |
| S14.01 | Live Shutter (công tắc, bảng giá) | `/work/instant` | NAG | I4 | ⬜ plan I4 | S52 |
| S14.02 | Lời mời việc (chồng tới 3 lời mời, đếm ngược 60 giây) | `/work/instant/offer/:offerId` | NAG | I4 | ⬜ plan I4 | S53 |
| S14.03 | Đang đến / đã đến / đang chụp | `/work/instant/:id` | NAG | I4 | ⬜ plan I4 | S54 |
| **S15** | **Đăng việc (khách)** | | | | | |
| S15.01 | Đăng việc | — | khách | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S56 |
| S15.02 | Việc của tôi / chi tiết việc | — | khách | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S57 |
| S15.03 | Danh sách ứng tuyển | — | khách | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S58 |
| S15.04 | Chi tiết đơn ứng tuyển | — | khách | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S59 |
| **S16** | **Nhận việc đăng (nhiếp ảnh gia)** | | | | | |
| S16.01 | Chi tiết việc (nhiếp ảnh gia) | — | NAG | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S60 |
| S16.02 | Việc đang tuyển | — | NAG | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S61 |
| S16.03 | Gửi báo giá (sheet) | — | NAG | J (đang thiết kế) | ⬜ đang thiết kế (Đăng việc) | S62 |
| **S17** | **Thông báo** | | | | | |
| S17.01 | Thông báo (hộp thư trong app) | `/notifications` | cả hai | N | ⬜ chưa có plan (thông báo) | S63 |
| S17.02 | Cài đặt thông báo | `/settings/notifications` | cả hai | N | ⬜ chưa có plan (thông báo) | S64 |
| S17.03 | Xin quyền thông báo (sheet) | `/notifications/permission` | cả hai | N | ⬜ chưa có plan (thông báo) | S65 |
| **S18** | **Khiếu nại & hỗ trợ** | | | | | |
| S18.01 | Mở khiếu nại (sheet): chọn buổi chụp/vé còn trong cửa sổ khiếu nại, lý do, mô tả, ảnh bằng chứng ≤ 5 | `/b/:id/dispute`, `/tickets/:id/dispute` | khách | mới | ⬜ đang thiết kế · chưa có mock | — |
| S18.02 | Chi tiết khiếu nại: trạng thái, tiền đang tạm giữ, trao đổi với hỗ trợ, kết quả (thả / hoàn / chia) | `/disputes/:id` | khách · NAG | mới | ⬜ đang thiết kế · chưa có mock | — |
| S18.03 | Trợ giúp: câu hỏi thường gặp theo chủ đề, "Liên hệ hỗ trợ" (chat với hộp thư hỗ trợ) | `/help` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| **S19** | **Lưu & theo dõi** | | | | | |
| S19.01 | Đã lưu: SegmentedTabs Bài · Nhiếp ảnh gia, lưới bài đã lưu, danh sách PhotographerCard đã lưu | `/me/saved` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| S19.02 | Đang theo dõi: danh sách nhiếp ảnh gia đang theo dõi, bỏ theo dõi | `/me/following` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| S19.03 | Người theo dõi (của nhiếp ảnh gia) | `/me/followers` | NAG | mới | ⬜ đang thiết kế · chưa có mock | — |
| **S20** | **Báo cáo & chặn** | | | | | |
| S20.01 | Báo cáo (sheet dùng chung cho người dùng, bài, tin nhắn, sự kiện): lý do, mô tả tuỳ chọn, tuỳ chọn chặn luôn | `/report` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| S20.02 | Người đã chặn: danh sách, bỏ chặn | `/settings/blocked` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| **S21** | **Xác minh** | | | | | |
| S21.01 | Xác minh số điện thoại (OTP) | `/verify/phone` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| S21.02 | Xin dấu tích xanh: điều kiện, giấy tờ/portfolio gửi duyệt, trạng thái (chờ / đã duyệt / cần bổ sung) | `/verify/photographer` | NAG | mới | ⬜ đang thiết kế · chưa có mock | — |
| **S22** | **Thanh toán & tài khoản** | | | | | |
| S22.01 | Lịch sử thanh toán: cọc, vé, hoàn tiền, khoản đang giữ (kể cả Chụp ngay chưa tìm được người), trạng thái từng khoản | `/me/payments` | khách | mới | ⬜ đang thiết kế · chưa có mock | — |
| S22.02 | Xoá tài khoản: điều kiện (không còn buổi chụp, vé hay tiền đang giữ), hậu quả, xác nhận | `/settings/delete-account` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| S22.03 | Quyền riêng tư & dữ liệu: ẩn hồ sơ khỏi gợi ý, tải bản sao dữ liệu | `/settings/privacy` | cả hai | mới | ⬜ đang thiết kế · chưa có mock | — |
| **S23** | **Vận hành nội bộ (staff)** | | | | | |
| S23.01 | Hàng đợi khiếu nại: xem bằng chứng hai bên, quyết định thả / hoàn / chia | nội bộ | admin | mới | ⬜ đang thiết kế · chưa có mock | — |
| S23.02 | Duyệt lô chi trả và đối soát cổng | nội bộ | admin · finance | mới | ⬜ đang thiết kế · chưa có mock | — |
| S23.03 | Hoàn tiền thủ công (cổng không hoàn tự động) | nội bộ | admin · finance | mới | ⬜ đang thiết kế · chưa có mock | — |
| S23.04 | Duyệt xác minh nhiếp ảnh gia (dấu tích xanh) | nội bộ | admin | mới | ⬜ đang thiết kế · chưa có mock | — |
| S23.05 | Kiểm duyệt báo cáo (người dùng, bài, tin nhắn, sự kiện) | nội bộ | admin | mới | ⬜ đang thiết kế · chưa có mock | — |
| S23.06 | Hộp thư hỗ trợ: chat hỗ trợ và hỏi trước của sự kiện do nền tảng tổ chức | nội bộ | admin · sales | mới | ⬜ đang thiết kế · chưa có mock | — |

Use case S15, S16 (**Đăng việc**) đang thiết kế, chưa có mock; S18–S23 bổ sung ngày 2026-10-02 (mục 3i), chưa có mock; S17 thuộc Thông báo (mục 3h). S13 và S14 là Chụp ngay, đặc tả ở [`2026-10-01-instant-booking-design.md`](2026-10-01-instant-booking-design.md) (sub‑project I1–I6).

### 2.1 Hiển thị mã trong app (chế độ debug)

- Mỗi màn bọc bằng `ScreenCode(ScreenCodes.home, child: …)` ở `lib/core/widgets/screen_code.dart`. Hằng số nằm ở `lib/core/screen_codes.dart` (`static const home = 'S02.01'`, …), một nguồn duy nhất, khớp bảng trên.
- Widget vẽ một nhãn nhỏ (nền `#FF2D95`, chữ trắng, font monospace 11, radius 6) ở **góc trên trái của màn**, dưới status bar (`SafeArea`), bọc `IgnorePointer` để không chặn chạm. Với sheet, nhãn nằm ở góc trên trái của sheet.
- Chỉ hiện khi `kDebugMode && showScreenCodesProvider`. Trong release, `ScreenCode` trả thẳng `child`, không thêm node nào.
- Bật/tắt: công tắc "Hiện mã màn hình" trong Cài đặt (S09.02), chỉ render khi `kDebugMode`; lưu `SharedPreferences` cùng chỗ với `themeMode`.
- Component con quan trọng có thể gắn mã phụ dạng `S05.02:timeline` bằng `ScreenCode(…, label: 'timeline')`.
- Test: widget test kiểm tra (1) nhãn hiện khi bật, (2) không hiện khi tắt, (3) không làm đổi layout của `child`.

Quy ước khi nhờ chỉnh sửa: nêu mã, ví dụ "S04.03: đổi nút MoMo/VNPay thành radio".

## 3. Danh mục Sự kiện (mới)

### 3.1 Khái niệm

Sự kiện chụp ảnh là buổi **nhóm** do nhiếp ảnh gia tổ chức, nhiều khách cùng đăng ký và trả vé: photo walk, mini session theo suất, workshop, cosplay/nhóm sở thích. Khác với booking 1‑1:

| | Booking (spec gốc) | Sự kiện |
|---|---|---|
| Bên cung | 1 nhiếp ảnh gia | 1 chủ sự kiện (nhiếp ảnh gia) |
| Bên cầu | 1 khách | Nhiều khách, có sức chứa |
| Thanh toán | Cọc 30%, phần còn lại tại chỗ | Trả đủ giá vé khi đăng ký (hoặc không thu phí khi giá bằng 0) |
| Xác nhận | Nhiếp ảnh gia nhận trong 24 giờ | Tự động khi thanh toán xong (còn chỗ) |
| Chứng từ | Timeline | Vé có mã QR để check‑in |

**Đã chốt**: người tạo sự kiện là **nhiếp ảnh gia**, hoặc **tài khoản quản trị (`admin`) / kinh doanh (`sales`)** của ứng dụng (mục 3.6). Khách chỉ đăng ký. Khách tạo "dự án mở" vẫn ngoài phạm vi v1.

### 3.2 Điểm vào

Không thêm tab thứ sáu (tối đa 5 tab).

| Vai trò | Điểm vào | Dẫn tới |
|---------|----------|---------|
| Cả hai | Khám phá (S02.03/S02.04): section "Sự kiện chụp ảnh" hoặc "Sự kiện gần bạn" + "Xem tất cả" | S11.01 |
| Cả hai | Link `/e/{eventId}` (chia sẻ, push) | S11.02 |
| Khách | Tab Đặt lịch → nhóm "Vé sự kiện" | S11.04 |
| NAG | Tab giữa Đăng bài → nhóm "Sự kiện" | S12.01 |
| NAG | Công việc → section "Sự kiện của tôi" | S12.03 |

### 3.3 Dữ liệu (Firestore)

```
events/{eventId}
  host: {type: "photographer", id: uid} | {type: "platform"}   # ai tổ chức, hiển thị ở S11.01/S11.02
  createdBy, createdByRole       # uid người tạo; "photographer" | "admin" | "sales"
  title, description, coverUrl
  hashtag                        # duy nhất, chữ không dấu + số; tự sinh, khoá sau khi có đăng ký/bài
  chatId                         # nhóm chat sự kiện (Chat.kind = event_group)
  type: "photo_walk" | "mini_session" | "workshop" | "cosplay" | "other"
  startAt, endAt                 # timestamp; hiển thị theo múi giờ Asia/Ho_Chi_Minh
  location: {name, meetingPoint?, geo, geohash}
  capacity: int                  # >= 1
  price: int                     # VNĐ mỗi người; 0 = không thu phí (hiện tag/banner “Không thu phí”)
  registrationDeadline           # mặc định = startAt - 12h
  status: "draft" | "open" | "full" | "closed" | "cancelled" | "completed"
  registeredCount, heldCount     # do Functions tính, client chỉ đọc
  createdAt, updatedAt

events/{eventId}/registrations/{regId}
  userId, name, phone, quantity (1–4)
  amount                         # quantity * price tại thời điểm đăng ký
  status: "held" | "paid" | "cancelled" | "refunded"
  holdExpiresAt                  # now + 10 phút khi status = held
  ticketCode                     # dạng VE-7K2Q-0420, duy nhất
  paymentId?, checkedInAt?, cancelledAt?, refundPercent?
```

Chỉ mục: `events (status, startAt)`, `events (type, startAt)`, `events (location.geohash, startAt)`, `events (hostId, startAt)`, collection group `registrations (userId, status)`.

Tương tác với availability: tạo sự kiện đánh dấu ngày đó của chủ là `booked` (`availability/{uid}/days/{date}` có `eventId`) và bị từ chối nếu ngày đã `booked`/`pending`. Huỷ sự kiện nhả lại ngày.

### 3.4 Trạng thái

```
draft ──"Đăng sự kiện"──▶ open ──registeredCount+heldCount = capacity──▶ full
open/full ──quá registrationDeadline──▶ closed ──sau endAt──▶ completed
draft/open/full/closed ──chủ huỷ──▶ cancelled (hoàn 100% mọi vé đã trả)
```

Đăng ký: `held` (giữ chỗ 10 phút) → thanh toán `paid` → vé hiệu lực. Hết hạn giữ chỗ mà chưa `paid` thì Function nhả chỗ. Sự kiện không thu phí (`price = 0`) đi thẳng `held → paid`.

**Sự kiện không thu phí (`price = 0`)**: mọi nơi hiện giá thay “0₫” bằng tag xanh **“Không thu phí”** (`FreeTag`); trang chi tiết S11.02 có thêm **banner** “Không thu phí · Đăng ký để giữ chỗ, không cần thanh toán”; có chip lọc “Không thu phí” ở S11.01 và S02.04; S11.03 bỏ cổng thanh toán và nút là “Xác nhận đăng ký”; không có hoàn tiền; ô doanh thu ở S12.03 hiện “—”. Chỉ áp cho sự kiện; gói dịch vụ luôn có giá > 0 (S08.01).

Hoàn vé khi khách huỷ (**đã chốt**): trước `startAt` ≥ 48 giờ hoàn 100%, sau đó không hoàn. Chủ huỷ: hoàn 100%. Tiền vé nằm ở trạng thái treo cho tới khi sự kiện `completed` rồi mới chuyển cho chủ sự kiện (mục 3g).

### 3.5 Cloud Functions

| Function | Việc |
|----------|------|
| `registerEvent` (callable) | Transaction kiểm tra `capacity - registeredCount - heldCount ≥ quantity` và khách **có số điện thoại hợp lệ** (mục 3b), tạo registration `held`, trả `payUrl` qua cùng cổng `createDeposit` (amount = vé). Lỗi `sold_out`, `deadline_passed`, `limit_exceeded`, `phone_required`. |
| `paymentWebhook` (dùng lại) | Nhận IPN; nếu `payments` gắn registration thì set `paid`, tăng `registeredCount`, giảm `heldCount`, sinh `ticketCode`, gửi push. |
| `releaseExpiredHolds` (cron 1 phút) | Registration `held` quá `holdExpiresAt` → `cancelled`, giảm `heldCount`. |
| `cancelRegistration` (callable) | Tính hoàn theo 3.4, hoàn từ số tiền treo (mục 3g.3). |
| `releaseEscrow` (cron + trigger) | Khi booking/sự kiện `completed` và hết cửa sổ khiếu nại: `held → released`, ghi bút toán, tạo `Payout` cho người nhận (mục 3g.2). |
| `executePayout` (callable, admin) | Duyệt và đánh dấu chi trả; sau này gọi API chi hộ. |
| `openDispute` / `resolveDispute` | Khách khiếu nại trong cửa sổ; admin xử lý (thả, hoàn hoặc chia). |
| `createEvent` / `updateEvent` (callable) | Chỉ nhiếp ảnh gia (đã `onboardingComplete`) hoặc tài khoản có `staffRole` ∈ {`admin`, `sales`} gọi được; ghi `createdBy`, `createdByRole`; kiểm tra lược đồ và ngày (mục 3.6). Client không ghi `events` trực tiếp. |
| `linkEventPosts` (trigger bài đăng) | Đọc hashtag trong chú thích, ghi `post_hashtags` và `event_posts` (visible/pending) cho sự kiện khớp. |
| `joinEventChat` / `leaveEventChat` (trigger đăng ký) | Thêm vào nhóm chat khi vé `paid`, gỡ khi `refunded`/`cancelled`; mở/đóng nhóm theo thời gian sự kiện. |
| `moderateEventContent` (callable, điều hành) | Ẩn bài khỏi timeline, duyệt bài `pending`, ghim/xoá tin, tắt tiếng hoặc gỡ thành viên. |
| `cancelEvent` (callable, người quản lý) | Đặt `cancelled`, hoàn mọi vé `paid`, push cho người tham gia, nhả availability. |
| `checkInRegistration` (callable, chủ) | Nhận `ticketCode`, set `checkedInAt`; lỗi nếu đã check‑in hoặc sai sự kiện. |
| `closeEvents` (cron giờ) | `open/full → closed` quá hạn đăng ký; `closed → completed` sau `endAt`. |

Rules: client không ghi `status`, `registeredCount`, `heldCount`, `ticketCode`, `checkedInAt`; tạo/sửa `events` chỉ qua `createEvent`/`updateEvent` (người quản lý: nhiếp ảnh gia là host, hoặc `staffRole` admin; sales chỉ sự kiện do mình tạo) khi `draft`/`open` (sau khi có người đăng ký chỉ sửa mô tả, ảnh bìa, địa điểm; không giảm `capacity` dưới số đã bán). Khách đọc `events` có `status != draft`, đọc registration của chính mình.

### 3.6 Quyền tạo và quản lý sự kiện

| Vai trò | Tạo | Quản lý (sửa, huỷ, check‑in, nhắn nhóm) |
|---------|-----|------------------------------------------|
| Khách | Không | Chỉ xem và đăng ký |
| Nhiếp ảnh gia | Có, host luôn là chính mình | Sự kiện của mình |
| `sales` | Có, host là "Nền tảng" hoặc một nhiếp ảnh gia (tạo hộ) | Sự kiện do mình tạo |
| `admin` | Có, như `sales` | Mọi sự kiện |

- `admin` và `sales` **không** nằm trong `users.role` và không chọn được ở S01.05. Chúng là custom claim `staffRole` do hàm `setStaffRole` đặt, chỉ `admin` gọi được và có nhật ký. Rules và Functions kiểm claim; client chỉ dùng claim để ẩn/hiện nút.
- Màn tạo (S12.01, S12.02) và quản lý (S12.03) dùng chung cho cả ba vai trò. Chỉ staff thấy thêm ô **"Tổ chức bởi"** (Nền tảng hoặc chọn một nhiếp ảnh gia) ở S12.01. Nút "Tạo sự kiện" nằm ở S11.01 và, với staff, ở S09.02 (hàng "Quản lý sự kiện"); staff không có tab Đăng bài.
- Sự kiện `host.type = "platform"`: S11.01/S11.02 hiện "Do ứng dụng tổ chức" thay hàng nhiếp ảnh gia; không có `availability` để đánh dấu; doanh thu thuộc nền tảng; liên hệ trước khi đăng ký đi vào chat hỏi trước của hộp thư hỗ trợ (câu hỏi mở 16).
- Sự kiện tạo hộ cho nhiếp ảnh gia: chỉ đánh dấu `availability` ngày đó của nhiếp ảnh gia khi họ đồng ý (`hostConsent`); nhiếp ảnh gia nhận thông báo để chấp nhận hoặc từ chối trong 24 giờ, quá hạn thì sự kiện không đăng (câu hỏi mở 17).

### 3.7 Timeline và nhóm chat của sự kiện

Mỗi sự kiện có hai không gian chia sẻ: **timeline** công khai gom bài theo hashtag và **nhóm chat** riêng cho người tham gia.

**Hashtag sự kiện.** `Event.hashtag`: duy nhất toàn hệ thống, 3–40 ký tự, chỉ chữ không dấu và số, không khoảng trắng, không phân biệt hoa thường. Tự sinh từ tên và ngày (ví dụ `PhotoWalkPhoCo1020`), chủ sự kiện sửa được ở S12.02 cho tới khi có người đăng ký hoặc có bài; sau đó khoá. Hiển thị `#PhotoWalkPhoCo1020`.

**Timeline.**
- Bất kỳ bài đăng nào có `#hashtag` của sự kiện trong chú thích (không phân biệt hoa thường) tự lên timeline của sự kiện, sắp mới nhất trước. Trigger `linkEventPosts` đọc hashtag trong chú thích vào `post_hashtags`, khớp `events.hashtag` và ghi `event_posts` (nguồn `hashtag`). Bài đăng từ nút "Đăng ảnh" trong S11.05 được chèn sẵn hashtag và ghi nguồn `explicit`.
- **Ai đăng:** người tham gia (vé `paid`/đã check‑in) đăng bài loại mới **`event_share`** (1–10 ảnh + chú thích) từ S11.05; nhiếp ảnh gia, chủ sự kiện và staff đăng bài `work` thường (S10.01) có hashtag. Bài `event_share` hiện ở timeline và hồ sơ người đăng; chỉ vào feed Trang chủ khi chủ sự kiện hoặc staff "đề cử".
- **Kiểm duyệt:** bài của tác giả là người tham gia, nhiếp ảnh gia, chủ sự kiện hoặc staff hiện ngay (`visible`). Bài có hashtag của người khác ở trạng thái `pending` cho tới khi chủ sự kiện hoặc staff duyệt; chủ sự kiện/staff có thể `hidden` bất kỳ bài nào khỏi timeline (bài vẫn còn trên hồ sơ tác giả). Có nút báo cáo.
- **Xem:** mọi người xem được timeline (không cần vé) khi sự kiện không phải `draft`; mở bằng tab "Timeline" ở S11.02 hoặc thẳng S11.05. Đăng mới được tới 30 ngày sau `completed`, sau đó chỉ xem.

**Nhóm chat (`Chat.kind = event_group`).**
- Thành viên: người có đăng ký `paid` (mỗi tài khoản một lần dù mua nhiều vé; sự kiện không thu phí tính khi đăng ký xong), chủ sự kiện và staff tạo. Tự thêm khi vé `paid`, tự gỡ khi vé `refunded`/`cancelled`. Giới hạn bằng sức chứa (tối đa 500).
- Thời gian: mở từ lúc có thành viên đầu tiên đến 7 ngày sau `completed`, sau đó chỉ đọc 30 ngày rồi lưu trữ.
- Quyền: thành viên gửi chữ, ảnh, vị trí. Chủ sự kiện và staff là **điều hành** (`moderator`): ghim tin, xoá tin, tắt tiếng hoặc gỡ thành viên, bật chế độ "chỉ điều hành nhắn". "Nhắn nhóm" ở S12.03 là **ghim thông báo** trong nhóm kèm push (thay cho thông báo một chiều trước đây).
- Riêng tư: thành viên chỉ thấy tên hiển thị và avatar của nhau, không thấy số điện thoại hay email. Có báo cáo tin nhắn, giới hạn 20 tin/phút/người, bộ lọc spam; tắt tiếng nhóm được, mặc định chỉ thông báo tin ghim và khi được nhắc tên.

**Câu hỏi trước khi đăng ký.**
- Sự kiện do nhiếp ảnh gia tổ chức: nút "Nhắn tin hỏi trước" mở chat `inquiry` với nhiếp ảnh gia (mục 3b.1).
- Sự kiện do nền tảng tổ chức (`host.type = platform`): chat `inquiry` đi vào **hộp thư hỗ trợ** của staff. Đề xuất: mặc định giao cho người tạo sự kiện (`createdBy`), mọi `sales`/`admin` thấy hàng đợi chung và có thể nhận hoặc giao lại; quy tắc 3 tin / 14 ngày như chat hỏi trước. Cần xác nhận (câu hỏi mở 16).
- Sau khi đăng ký, trao đổi chung chuyển sang nhóm chat.

## 3b. Liên hệ và số điện thoại

### 3b.1 Quy tắc sản phẩm

- **Khách muốn đặt lịch (booking hoặc vé sự kiện) phải có số điện thoại** trong hồ sơ. Chưa có thì mọi điểm vào đặt lịch (S02.02 "Đặt gói này", S03.01 "Đặt lịch", S02.06 "Đặt T7", S11.02 "Đăng ký") mở S04.05 trước, lưu xong quay lại đúng bước đang làm (`returnTo`). Không chặn xem, lướt, lưu, nhắn trong app.
- **Xác minh số điện thoại làm sau.** Bản này chỉ kiểm tra định dạng. Dữ liệu có sẵn cờ `phoneVerified: false`; UI chưa hiện dấu xác minh cho số. Khi làm xác minh (Firebase Phone Auth, OTP) chỉ cần bật cờ và thêm bước vào S04.05.
- **Kênh ngoài chỉ mở sau khi đã đặt.** Nhiếp ảnh gia chọn bật kênh nào (Gọi điện, Zalo, WhatsApp) ở S08.05, cần ít nhất một số điện thoại. Nhưng khách **chỉ thấy và dùng** các kênh đó sau khi "mở khoá liên hệ":
  - Booking ở `requested` (đã cọc), `accepted`, `upcoming`, hoặc `completed` (trong 30 ngày sau); hoặc vé sự kiện `paid` (cho tới 7 ngày sau sự kiện). `declined`, `expired`, `cancelled`, `refunded` thì khoá lại.
  - **Trước khi đặt** (S03.01, S11.02) chỉ có nút **Nhắn tin hỏi trước** trong app. Đó là chat `inquiry` với quy tắc: (1) khách gửi **tối đa 3 tin** khi nhiếp ảnh gia chưa trả lời; (2) **ngay khi nhiếp ảnh gia trả lời tin đầu tiên, giới hạn được gỡ vĩnh viễn và hai bên nhắn tin tự do với nhau** (văn bản, ảnh, vị trí), không còn đếm tin; (3) cuộc trò chuyện tự đóng sau 14 ngày không có tin nào từ cả hai phía (mỗi tin mới đặt lại bộ đếm 14 ngày), và mở lại được khi một bên nhắn tiếp; khi khách đặt lịch, cùng cuộc trò chuyện gắn `bookingId` và thành chat booking (S07.01). Nhiếp ảnh gia có thể tắt nhận tin hỏi trước (`acceptInquiries`).
  - Mục đích: giữ giao dịch trong nền tảng (không chốt giá ngoài rồi bỏ cọc) nhưng vẫn cho khách hỏi trước khi quyết định.
- Số của khách **chỉ hiện với nhiếp ảnh gia sau khi khách đặt cọc** (booking ở `requested` trở đi, hoặc vé sự kiện `paid` với chủ sự kiện). Trước đó nhiếp ảnh gia không thấy số.

### 3b.2 Dữ liệu

`users/{uid}` đọc được bởi mọi người đã đăng nhập (test rules hiện có khẳng định không lưu email/uid ở đây), nên **số điện thoại không đặt ở đó**.

```
users/{uid}/private/contact            # chỉ chủ đọc/ghi
  phone: "+84903123456"                # E.164
  phoneVerified: false                 # dành cho bước xác minh sau
  allowZalo: bool, allowWhatsApp: bool # cho phép nhiếp ảnh gia dùng kênh nào
  updatedAt

photographers/{uid}.contactChannels    # công khai, CHỈ là cờ, không có số
  call: bool, zalo: bool, whatsapp: bool, acceptInquiries: bool

photographers/{uid}/private/contact    # chỉ chủ đọc/ghi
  phone                                # E.164
  zaloPhone?                           # mặc định dùng phone
  whatsappPhone?                       # số riêng nếu khác, định dạng quốc tế

chats/{chatId}.kind: "inquiry" | "booking"   # inquiry: chưa có bookingId

bookings/{id}/private/contact          # chụp lại lúc tạo draft, khách luôn đọc được, thợ chỉ đọc khi contact_unlocked
  name, phone, allowZalo, allowWhatsApp
```

- `createBookingDraft` và `registerEvent` đọc `users/{uid}/private/contact`, từ chối với `phone_required` nếu thiếu hoặc sai định dạng (ép ở server, không chỉ ở UI), rồi sao chụp vào `bookings/{id}/private/contact` / `registrations.phone`.
- Function xoá tài liệu snapshot `bookings/{id}/private/contact` ngay khi `declined`/`expired`/`cancelled`, và 30 ngày sau `completed` (câu hỏi mở 4).
- **Số của nhiếp ảnh gia không bao giờ nằm trong tài liệu đọc được công khai.** Ứng dụng nhận đường dẫn gọi qua hàm callable `getContactLink({bookingId | registrationId, channel})`: Function kiểm tra điều kiện "mở khoá liên hệ" (mục 3b.1) rồi trả đúng một URL (`tel:`, `https://zalo.me/…`, `https://wa.me/…`); chưa đủ điều kiện thì trả lỗi `contact_locked`. Client không lưu số.
- Rules: `users/{uid}/private/contact` và `photographers/{uid}/private/contact` chỉ chủ đọc/ghi; `photographers/{uid}.contactChannels` chỉ chủ ghi; `bookings/{id}/private/contact` chỉ ghi qua Function, khách đọc luôn được, thợ đọc chỉ khi mở khoá liên hệ; client không tạo được `chats` kind `booking`.

### 3b.3 Định dạng và chuẩn hoá

- Bỏ khoảng trắng, dấu chấm, gạch ngang. Số Việt Nam hợp lệ: `^(?:\+84|0)(3|5|7|8|9)\d{8}$`; chuẩn hoá về `+84` + 9 chữ số. Số WhatsApp riêng nhận `^\+\d{8,15}$`.
- `PhoneField`: tiền tố `+84` cố định, bàn phím số (`TextInputType.phone`), dán được, tự định dạng `903 123 456`, lỗi cụ thể dưới ô ("Số cần 10 chữ số, bắt đầu bằng 0").

### 3b.4 Mở ứng dụng ngoài

Dùng `url_launcher` để mở URL do `getContactLink` trả về (mục 3b.2). Mọi liên kết là `https`/`tel` nên không cần khai báo scheme riêng của Zalo/WhatsApp.

| Kênh | URL | Ghi chú |
|------|-----|---------|
| Gọi điện | `tel:+84903123456` | Ẩn nếu `canLaunchUrl` sai (máy tính bảng không có điện thoại) |
| Zalo | `https://zalo.me/84903123456` | Mở app Zalo nếu có, không thì trang web; kiểm tra định dạng số trên máy thật |
| WhatsApp | `https://wa.me/84903123456` (không có `+`) | Tương tự |

- Android 11+: thêm `<queries>` cho `tel` và `https` `VIEW` vào `AndroidManifest.xml`.
- Giao diện không hiển thị số điện thoại; số chỉ đi vào ứng dụng ngoài (quay số, Zalo, WhatsApp), giảm bị thu thập hàng loạt.
- Nhãn "Zalo", "WhatsApp" chỉ là chữ. Dùng logo chính thức từ bộ nhận diện của hãng khi có giấy phép; không tự vẽ lại.
### 3b.6 Biểu tượng Zalo và WhatsApp

- Dùng **đúng biểu tượng của hãng**, không tự vẽ lại. Bản dev dùng glyph đơn sắc từ bộ Simple Icons (CC0) đặt ở `app_flutter/assets/social/zalo.svg`, `whatsapp.svg` (kèm `SIMPLE-ICONS-LICENSE-CC0.md`); khai báo sẵn vì `pubspec.yaml` đã liệt kê cả thư mục `assets/social/`. Hiển thị bằng `flutter_svg` (`SvgPicture.asset(…, colorFilter: ColorFilter.mode(color, BlendMode.srcIn))`).
- **Trước khi phát hành**: thay bằng tài nguyên chính thức từ trang thương hiệu của Zalo và WhatsApp và làm theo hướng dẫn sử dụng (khoảng trống quanh logo, không đổi tỉ lệ). Biểu tượng chỉ là dấu hiệu chức năng "Mở Zalo" / "Mở WhatsApp", không ngụ ý hai hãng bảo trợ ứng dụng. Cần xác nhận pháp lý (câu hỏi mở 15).
- **Màu**: glyph đơn sắc theo màu chữ chính (`onSurface`) trong vòng tròn nền `surfaceMuted`, để đạt tương phản ≥ 3:1 ở cả hai theme. Không dùng xanh lá WhatsApp hoặc xanh Zalo làm nền vì chữ/biểu tượng trắng trên xanh lá WhatsApp chỉ đạt khoảng 2:1.
- Mỗi biểu tượng luôn kèm nhãn chữ bên dưới và `Semantics(label: 'Zalo')`/`'WhatsApp'`, vì không phải ai cũng nhận ra biểu tượng.

### 3b.5 Nút liên hệ gọn (`ContactDial`)

Các kênh liên hệ **không bày sẵn**. Mặc định chỉ có một nút nhỏ (biểu tượng điện thoại 48dp, hoặc nút "Liên hệ" thấp 38dp khi nằm trong hàng nút). Các lựa chọn chỉ xuất hiện, kèm animation, lúc người dùng bấm nút đó.

| Hành vi | Quy tắc |
|---------|---------|
| Bung | Bấm nút → **một khay** (nền surface, radius 28, bóng) trồi lên phía trên nút, căn phải theo nút, chứa **tối đa ba biểu tượng tròn 44dp** xếp ngang: Gọi, Zalo, WhatsApp, mỗi biểu tượng có nhãn chữ 10,5 bên dưới. Khay dịch 10dp + phóng 0,92 → 1, mờ → rõ, 240ms, đường cong ra có nảy nhẹ; ba biểu tượng vào so le 40ms từ phải sang. Nút đổi viền và biểu tượng sang primary khi đang mở. |
| Đóng | Bấm ra ngoài, bấm lại nút, nút Back hệ thống, hoặc chọn một lựa chọn. Đóng nhanh hơn mở (140ms, không so le). Animation ngắt được: bấm khi đang chạy thì đảo chiều ngay. |
| Mở khoá | **Trước khi đặt** (`ContactAccess.locked`): nút chỉ là biểu tượng chat "Nhắn tin hỏi trước", bấm mở thẳng chat `inquiry`, không bung. **Sau khi đặt** (`unlocked`): bung khay các kênh ngoài mà nhiếp ảnh gia đã bật (Gọi, Zalo, WhatsApp). "Nhắn tin trong app" **không** nằm trong khay vì đã có nút "Nhắn tin" riêng cạnh nút Liên hệ. |
| Một kênh | Nếu chỉ còn một kênh khả dụng (ví dụ chỉ nhắn tin trong app) thì bấm nút mở thẳng kênh đó, không bung. |
| Vị trí | Neo vào nút bằng `OverlayPortal` + `CompositedTransformFollower`; mở lên trên, đổi hướng xuống nếu thiếu chỗ; không che nút chính ("Đặt lịch") và không làm đổi layout. |
| Giảm chuyển động | Khi `MediaQuery.disableAnimations` hoặc hệ thống bật giảm chuyển động: hiện/ẩn tức thì, không dịch và không phóng. |
| Truy cập | Nút là `Semantics(button, label: 'Liên hệ', expanded)`. Khi mở, tiêu điểm chuyển vào lựa chọn đầu, Tab/mũi tên đi theo thứ tự hiển thị, Esc đóng và trả tiêu điểm về nút. Mỗi lựa chọn có nhãn chữ nên không dựa vào biểu tượng. Vùng chạm ≥ 44dp, cách nhau 8dp. |
| Phản hồi | Chạm nhẹ (`HapticFeedback.selectionClick`) khi mở; không có hiệu ứng chuyển động nào khác khi nút ở trạng thái nghỉ. |

- Ghi sự kiện phân tích `contact_tapped{channel, source: S03.01|S05.02|S11.02}`; không ghi số.

## 3c. Vị trí và gợi ý "gần bạn"

### 3c.1 Hành vi

- Khám phá hỏi quyền **đúng lúc người dùng muốn**: thẻ "Sự kiện gần bạn" (S02.03) có nút "Cho phép" và "Để sau". Chỉ bấm "Cho phép" mới gọi hộp thoại quyền của hệ điều hành. Không hỏi lúc mở app.
- Đã cho phép (S02.04): lấy vị trí **gần đúng** (Android `ACCESS_COARSE_LOCATION`, iOS `NSLocationWhenInUseUsageDescription`, `LocationAccuracy.low`), sắp xếp sự kiện theo khoảng cách rồi `startAt`, mỗi thẻ có khoảng cách làm tròn 0,1 km. Chip bán kính 10/25/50 km (mặc định 25), chip "Tuần này", "Cuối tuần", "Không thu phí".
- Chọn "Để sau", từ chối, từ chối vĩnh viễn, hoặc dịch vụ vị trí tắt: thẻ thu thành chip "Chọn khu vực", mở S02.05 để chọn quận/thành phố thủ công. Từ chối vĩnh viễn có thêm nút "Mở Cài đặt để bật vị trí" (`Geolocator.openAppSettings`).
- Khu vực chọn thủ công dùng thay vị trí và cũng áp cho S02.06 (Tìm thợ ảnh) và sắp xếp "Gần tôi" ở S11.01.

### 3c.2 Quyền riêng tư và kỹ thuật

- Toạ độ chính xác **ở lại trên máy**; không ghi lên Firestore. Truy vấn dùng tiền tố geohash cùng 8 ô lân cận; độ dài tiền tố chọn theo bán kính (5 ký tự cho ≤ 4 km, 4 ký tự cho ≤ 17 km, 3 ký tự cho ≤ 140 km) để chín ô luôn phủ hết bán kính trên chỉ mục `events (location.geohash, startAt)`, rồi lọc và sắp theo khoảng cách (haversine) ở client.
- Khu vực chọn thủ công lưu `SharedPreferences` (`area`: tên + geohash 5), không lưu server trừ khi người dùng tự điền "Thành phố" trong hồ sơ.
- Vị trí cũ hơn 30 phút thì làm mới khi vào màn, dùng bản cũ trong lúc chờ; quá 8 giây không có vị trí thì chuyển sang khu vực đã lưu hoặc S02.05.
- Sự kiện không có `geo` bị loại khỏi mục "gần bạn" nhưng vẫn ở "Xem tất cả".
- Lời giải thích quyền (tiếng Việt): "Chúng tôi dùng vị trí gần đúng của bạn để gợi ý sự kiện quanh đây. Vị trí không được lưu lên máy chủ."
- Không phụ thuộc bản đồ; khoảng cách luôn có chữ để đọc được bằng trình đọc màn hình.

Gói: `geolocator` (đã có trong kế hoạch spec gốc) và bộ tính geohash nhỏ tự viết (hoặc `geoflutterfire_plus`). `LocationRepository` có bản giả để test.

## 3d. Dấu tích xanh và huy hiệu

### 3d.1 Dấu tích xanh (Verified)

- Thay nhãn chữ "Verified" bằng **một dấu tích xanh nhỏ** (vòng tròn 14dp, dấu ✓ trắng, nền xanh `ctaStart` `3D63FF`) đặt ngay sau tên và nâng cao hơn tên một chút (khoảng 3dp, kiểu chỉ số trên). Không có chữ, không có viền; widget `VerifiedMark`.
- Nghĩa vẫn là `photographers.verified` do admin duyệt (spec gốc). Dấu tích **không** thay cho huy hiệu và không có cấp độ.
- Truy cập: `Semantics(label: 'Đã xác minh')`, tooltip khi nhấn giữ. Xuất hiện cạnh tên nhiếp ảnh gia ở S02.02, S03.01, S02.06, S11.02, S12.03 và danh sách người theo dõi. Không hiện cho khách.
- Màu xanh này chỉ dành cho dấu tích; huy hiệu dùng màu khác (mục 3d.2) để không bị nhầm.

### 3d.2 Huy hiệu (badges)

Huy hiệu ghi nhận người dùng (cả khách và nhiếp ảnh gia) và đến từ hai nguồn:

| Nguồn | Ý nghĩa | Ví dụ (danh mục khởi đầu) |
|-------|---------|---------------------------|
| `review` | Suy ra từ đánh giá | "Được đánh giá cao" (NAG: ≥ 4,8 sao và ≥ 20 đánh giá), "Khen nhiều về đúng giờ" (≥ 5 đánh giá nhắc từ khoá "đúng giờ"), "Nhận xét chi tiết" (khách: ≥ 5 nhận xét ≥ 50 ký tự) |
| `system` | Hệ thống trao theo hoạt động | "Thành viên mới" (30 ngày đầu), "Hồ sơ đầy đủ" (≥ 6 ảnh và ≥ 1 gói), "Phản hồi nhanh" (trung vị ≤ 60 phút trong 10 yêu cầu gần nhất), "10 / 50 / 100 buổi chụp", "Chủ sự kiện" (≥ 1 sự kiện hoàn thành), "Khách thân thiết" (≥ 3 buổi hoàn thành), "Người chia sẻ" (≥ 5 bài "Buổi chụp thật") |

Dữ liệu:

```
badges/{badgeId}                         # danh mục, chỉ admin ghi
  name, description, icon, order
  source: "review" | "system"
  audience: "photographer" | "customer" | "both"
  rule: {metric, op, threshold, minSample?}

users/{uid}/badges/{badgeId}             # đã đạt; chỉ Functions ghi; mọi người đã đăng nhập đọc
  awardedAt, snapshot?                   # ví dụ giá trị đạt được

users/{uid}/private/badgeProgress        # chỉ chủ đọc; Functions ghi
  {badgeId: {current, target}}           # hiển thị tiến độ ở S03.02 của chính mình
```

- Trao qua Functions: `onReviewWrite`, `onBookingComplete`, `onEventComplete`, `onPostWrite`, và cron đêm `reconcileBadges` (tính lại huy hiệu dựa trên chỉ số, ví dụ điểm tụt dưới ngưỡng thì gỡ). Client không tự ghi.
- Chống thổi phồng: mỗi huy hiệu từ đánh giá có `minSample`; đánh giá chỉ tính từ booking `completed`.
- Hiển thị: tối đa 3 huy hiệu trên thẻ và hàng tên (ưu tiên theo `order`); hồ sơ (S03.01, S09.01) hiện một hàng chip + "Xem tất cả" → S03.02. S03.02 chia nhóm "Từ đánh giá" và "Từ hệ thống"; của chính mình hiện cả huy hiệu chưa đạt (mờ) kèm thanh tiến độ "2 / 3 buổi", của người khác chỉ hiện huy hiệu đã đạt.
- Phân biệt với tích xanh: tích xanh là **một dấu nhỏ cạnh tên**; huy hiệu là **chip có biểu tượng + tên** (hoặc ô lớn trong S03.02), nền kính và biểu tượng tô `CtaSurface`.
- Widget: `VerifiedMark`, `BadgeChip`, `BadgeTile`.

### 3d.3 Chấm số trên thanh tab

Thanh tab dưới dùng `TabBadge` (bong bóng đỏ, chữ trắng, "9+" từ mười trở lên, ẩn khi 0), cho phép **bất kỳ tab nào** có chấm số; hai tab dùng ngay:

| Tab | Ý nghĩa số | Khi nào xoá |
|-----|-----------|-------------|
| Công việc (nhiếp ảnh gia) | Số yêu cầu đang chờ nhận | Khi không còn yêu cầu chờ (không xoá khi chỉ mở tab) |
| **Khám phá** | Số sự kiện mới trong khu vực của bạn kể từ lần mở Khám phá gần nhất (nếu chưa có vị trí/khu vực thì tính toàn bộ sự kiện mới) | Khi mở tab Khám phá; đếm lại từ 0 |

- Số lấy từ `tabBadgesProvider` (`Map<AppTab, int>`), mỗi feature ghi đè khi có dữ liệu; **đã có trong code** (`TabBadge`, `tabBadgesProvider`, `TabShell`, test `tab_badge_test.dart`), giá trị mặc định rỗng nên chưa có chấm nào hiện.
- Trình đọc màn hình đọc "Khám phá, 3 mục mới" (`Semantics.value`). Chấm không phụ thuộc màu: luôn có số.
- Mốc "lần mở gần nhất" lưu `SharedPreferences` (`exploreSeenAt`); đếm bằng truy vấn `events` có `createdAt > exploreSeenAt` trong geohash của khu vực, tối đa 10 (đủ để hiển thị "9+").

## 3e. Kỹ năng nhiếp ảnh gia và dịch vụ gợi ý

### 3e.1 Nguyên tắc

- **Dữ liệu có cấu trúc, không gõ tự do.** Nhiếp ảnh gia chọn từ danh mục chuẩn (id ổn định, nhãn tiếng Việt) để thuật toán so khớp được và đổi nhãn không làm hỏng dữ liệu.
- **Thuật toán nằm ngoài ứng dụng.** Ứng dụng chỉ biết một giao diện (`RecommendationRepository`); mọi cách xếp hạng nằm trong dịch vụ riêng `services/recommender`, nâng cấp hoặc thay mới mà không phát hành lại ứng dụng.
- **Giải thích được.** Mỗi gợi ý trả kèm lý do ngắn bằng tiếng Việt ("Chuyên sâu chân dung · 1,2 km · rảnh T7"), hiển thị ở S02.01, S02.06.
- **Luôn có đường lui.** Dịch vụ lỗi hoặc chậm thì ứng dụng tự xếp theo sao và khoảng cách.

### 3e.2 Thu thập kỹ năng (S08.02–S08.04)

| Nhóm | Nội dung | Giới hạn |
|------|----------|----------|
| Thể loại chụp (`specialties`) | Chân dung, Cưới, Cặp đôi, Gia đình, Kỷ yếu, Sự kiện, Sản phẩm, Du lịch, Thời trang, Ẩm thực, Bất động sản, Em bé… kèm **mức độ** 1 Cơ bản · 2 Thành thạo · 3 Chuyên sâu | Tối đa 6 thể loại; tối đa 3 thể loại mức 3; mức 3 cần ≥ 1 ảnh minh chứng |
| Phong cách (`styles`) | Ánh sáng tự nhiên, Film, Tối giản, Editorial, Tư liệu… | Tối đa 4 |
| Kỹ năng thêm (`extras`) | Hậu kỳ, Chỉ đạo tạo dáng, Quay video, Flycam, Studio, Chụp trẻ em, Thú cưng, Thiếu sáng, Ngoài trời | Tối đa 8 |
| Ngôn ngữ (`languages`) | vi, en, zh, ko, ja | Phải có ít nhất 1 |
| Khách phù hợp (`audiences`) | Cặp đôi, Gia đình có bé nhỏ, Doanh nghiệp, Khách nước ngoài, Người ngại ống kính | Tối đa 4 |
| Kinh nghiệm | Số năm (0–50) | Một số |
| Minh chứng (`evidencePostIds`) | 1–3 bài đăng của chính họ cho mỗi thể loại | Chỉ chọn trong bài đã đăng |

- **Độ khớp hồ sơ** (`skills.completeness`, 0–100): 25 điểm thể loại (≥ 1) + 20 mức độ đã đặt cho mọi thể loại + 20 minh chứng cho mọi thể loại mức 3 + 10 phong cách + 10 ngôn ngữ + 10 khách phù hợp + 5 kỹ năng thêm. Do Function `onPhotographerWrite` tính (app không tính), lưu cùng `completenessNext` (mã bước còn thiếu đầu tiên: `specialties | levels | evidence | styles | languages | audiences | extras`, `null` khi đủ 100) và `completenessNextAfter` (điểm sau khi làm bước đó); chỉ để nhắc nhiếp ảnh gia; không hiện cho khách.
- Danh mục lấy từ `taxonomy/skills` (Firestore, bản sao Remote Config), thêm kỹ năng mới không cần phát hành lại ứng dụng. Mỗi mục có `id`, `group`, `labels.vi`, `order`, `active`. Mục bị gỡ (`active: false`) vẫn hiện ở hồ sơ cũ nhưng không chọn mới được. Id chỉ duy nhất **trong một nhóm**: `couple` vừa là thể loại vừa là khách phù hợp, nên mọi tra cứu dùng cặp (`group`, `id`).
- Vào từ bước 3/4 của thiết lập hồ sơ (S08.02) hoặc từ Hồ sơ → "Kỹ năng" (sửa lúc nào cũng được). Lưu mỗi lần đổi bước hoặc thoát; thoát giữa chừng hỏi lưu nháp.

### 3e.3 Dữ liệu

```
photographers/{uid}.skills
  schemaVersion: 1
  specialties: [{id: "portrait", level: 3, years?: 6, evidencePostIds: [postId]}]
  styles: ["natural_light", "film"]
  extras: ["retouch", "posing"]
  languages: ["vi", "en"]
  audiences: ["couple", "shy_subjects"]
  yearsExperience: 6
  completeness: 72            # Function tính
  completenessNext: "audiences"  # Function ghi; null khi đủ 100
  completenessNextAfter: 85   # Function ghi: điểm sau khi làm bước kế tiếp
  evidenceRemovedAt           # Function ghi khi gỡ minh chứng không hợp lệ
  updatedAt

taxonomy/skills/items/{id}
  group: "specialty" | "style" | "extra" | "language" | "audience"
  labels: {vi}, order, active
```

- Công khai (đọc bởi mọi người đã đăng nhập), chỉ chủ ghi `skills` (trừ `completeness`, `completenessNext`, `completenessNextAfter`, `updatedAt`, `evidenceRemovedAt` do Function ghi). Rules hiện kiểm: id nằm trong danh sách cố định của từng nhóm, đúng giới hạn số lượng, mức 3 cần ≥ 1 minh chứng, client không ghi các trường do server sở hữu (`completeness`, `completenessNext`, `completenessNextAfter`, `skills.updatedAt`, `evidenceRemovedAt`).
- Cách kiểm hiện tại: rules so id với danh sách cố định trong `firestore.rules` (sao từ danh mục tích hợp; test `rules_catalogue_sync_test.dart` giữ hai bên trùng nhau, nên thêm mục danh mục cần deploy rules), kiểm giới hạn, mức 3 cần ≥ 1 minh chứng, không cho client đổi `completeness`/`skills.updatedAt`. Việc `evidencePostIds` thuộc bài của chính họ **không** kiểm trong rules (cần một lần đọc cho mỗi bài, vượt giới hạn 10 lần đọc); hiện chỉ sheet S08.04 giới hạn việc chọn trong bài của mình. Function `onPhotographerWrite` kiểm quyền sở hữu minh chứng (gỡ id không phải bài còn sống của chính họ, hạ "Chuyên sâu" không còn minh chứng xuống "Thành thạo", ghi `evidenceRemovedAt`) và tính `completeness`; app không tính điểm (spec `2026-10-02-photographer-write-function-design.md`).
- Function `onPhotographerWrite` (Firestore trigger `photographers/{uid}`, `asia-southeast1`; backend phase 1, Task 10–14) đọc lược đồ bằng `parseSkills` (`packages/domain`), kiểm `evidencePostIds` bằng một lần `getAll`, tính `completeness`/`completenessNext`/`completenessNextAfter`, ghi một lần với precondition `lastUpdateTime`; bỏ qua lần ghi chỉ đổi trường server. Báo dịch vụ gợi ý cập nhật chỉ mục (3e.4) để plan recommender.

### 3e.4 Dịch vụ gợi ý chạy riêng

```
Ứng dụng ──callable `recommend` (Firebase Auth + App Check, giới hạn tần suất)──▶ Cloud Run `recommender-service` (riêng tư, IAM)
                                                                                          │ đọc: photographers, availability, events, stats
                                                                                          └ ghi: recommendation_logs (chỉ tín hiệu, không dữ liệu nghiệp vụ)
```

- Thư mục `services/recommender/` trong repo, build và triển khai độc lập (Cloud Run). Hợp đồng API là tệp **`services/recommender/api/openapi.yaml`** (có phiên bản `/v1`); ứng dụng và Functions sinh kiểu dữ liệu từ đó, nên đổi thuật toán không đổi hợp đồng.
- **Triển khai theo giai đoạn (không cần hệ thống riêng ngay)**: *Giai đoạn 1 (ra mắt)*: logic xếp hạng là gói TypeScript thuần `packages/recommender-core` (không phụ thuộc Firebase), chạy **trong hàm `recommend`** và có `LocalRecommender` dự phòng ở ứng dụng; chưa dựng Cloud Run. *Giai đoạn 2*: bọc cùng gói đó thành dịch vụ Cloud Run khi chạm ngưỡng: ≥ 5.000 nhiếp ảnh gia hoạt động, p95 > 400 ms, cần đặc trưng hoặc mô hình tính ngoại tuyến (nhúng ảnh, học xếp hạng), hoặc có client thứ hai (web, quản trị). Hợp đồng `openapi.yaml` và `RecommendationRepository` **không đổi** giữa hai giai đoạn.
- **Xếp hạng khác ghép cặp**: v1 chỉ *xếp hạng* gợi ý cho khách tự chọn. *Ghép cặp tự động* (nhận yêu cầu của khách, chọn và mời nhiếp ảnh gia phù hợp, xử lý nhiều khách tranh một nhiếp ảnh gia) là sản phẩm khác và cần dịch vụ điều phối riêng. **Đã chốt 2026-10-01**: làm dạng "Chụp ngay" kiểu Uber, xem [`2026-10-01-instant-booking-design.md`](2026-10-01-instant-booking-design.md); module chấm điểm dùng chung với `recommender-core`.
- Ứng dụng **không gọi thẳng** dịch vụ: gọi hàm callable `recommend` (xác thực, App Check, giới hạn tần suất, rút gọn dữ liệu), hàm này gọi dịch vụ bằng danh tính dịch vụ. Dịch vụ không mở công khai.
- **Bộ xếp hạng cắm được**: mỗi thuật toán là một `Scorer` đăng ký tên (`rules-v1`, sau này `ltr-v2`…). Tham số `algorithm` chọn bản; không truyền thì dùng bản mặc định trong cấu hình. Trọng số và ngưỡng nằm trong cấu hình (Remote Config / tài liệu `config/recommender`), đổi không cần phát hành.
- **Thử nghiệm A/B**: `experiment` + hash `userId` chọn bản; mỗi phản hồi trả `algorithm`, `algorithmVersion`, `requestId` để gắn vào nhật ký.
- **Hiệu năng**: mục tiêu p95 < 400 ms; ứng dụng đặt thời hạn 800 ms. Có bộ nhớ đệm theo (bộ lọc, ô geohash, ngày) 60 giây.
- **Dự phòng ở ứng dụng**: `RecommendationRepository` có hai cài đặt, `RemoteRecommendationRepository` (gọi `recommend`) và `LocalRecommender` (xếp theo sao đã làm mượt và khoảng cách, dùng khi lỗi, quá hạn, offline và trong test). Giao diện không đổi khi nâng cấp.
- **Chỉ mục**: v1 đọc thẳng Firestore có đệm; khi số nhiếp ảnh gia lớn thì dựng chỉ mục riêng (bảng đặc trưng) mà không đổi API.

### 3e.5 API tóm tắt

| Phương thức | Việc |
|-------------|------|
| `POST /v1/recommend/photographers` | Xếp hạng nhiếp ảnh gia theo ngữ cảnh: `specialty`, `date`, `geohash6`, `budgetMax`, `limit`, `cursor`, `excludeIds` |
| `GET /v1/recommend/photographers/{id}/similar` | Thợ ảnh tương tự (S03.01) |
| `POST /v1/feedback` | Nhận lô tín hiệu `impression`, `click`, `inquiry`, `booking` kèm `requestId` |
| `GET /v1/health` | Kiểm tra sống, trả phiên bản thuật toán đang chạy |

Phản hồi: `requestId`, `algorithm`, `algorithmVersion`, `items[{photographerId, rank, score, reasons[{code, text}]}]`, `nextCursor`. Đặc tả đầy đủ ở `openapi.yaml`. Vị trí gửi lên chỉ là **geohash độ dài 6** (ô ≈ 1,2 km), không phải toạ độ.

### 3e.6 Thuật toán v1 (`rules-v1`, giải thích được)

`score = 0,30·skill + 0,12·style + 0,15·geo + 0,15·availability + 0,12·quality + 0,06·price + 0,05·response + 0,05·fresh`, mỗi thành phần chuẩn hoá về [0, 1].

| Thành phần | Cách tính |
|------------|-----------|
| `skill` | Với thể loại truy vấn: trọng số mức 0,4 / 0,7 / 1,0; nhân 0,85 nếu thể loại mức 3 thiếu minh chứng. Cộng tối đa 0,15 theo trùng `audiences` và `extras` liên quan. Không có thể loại → trung bình thể loại mạnh nhất. |
| `style` | Jaccard giữa phong cách của khách (từ tín hiệu, mục 3e.7) và `styles`; không có tín hiệu → 0,5 trung tính. |
| `geo` | `exp(−d / 8 km)`; trong `serviceArea` thì ≥ 0,7. Khoảng cách tính từ tâm ô geohash. |
| `availability` | Rảnh đúng ngày = 1; chờ = 0,5; kín/nghỉ = 0 (loại khỏi kết quả nếu khách đã chọn ngày). Không chọn ngày: theo `nextFreeDate` trong 7 ngày. |
| `quality` | Điểm trung bình làm mượt kiểu Bayes `(v·R + m·C)/(v+m)` với `m = 10`, `C = 4,3`, rồi `(x − 3)/2`; cộng nhẹ theo `log(số buổi hoàn thành)`. |
| `price` | 1 nếu `startingPrice ≤ budgetMax`, giảm tuyến tính tới 0 ở 1,5 × ngân sách; thiếu dữ liệu → 0,5. |
| `response` | 1 nếu thời gian phản hồi trung vị ≤ 60 phút, giảm dần tới 0 ở 24 giờ. |
| `fresh` | Tăng tối đa 0,05 trong 30 ngày đầu của hồ sơ đủ thông tin (cho nhiếp ảnh gia mới có cơ hội, tránh vòng lặp "người nổi tiếng thắng"). |

- **Đa dạng**: sau khi chấm, chọn lại bằng MMR (λ = 0,8) theo thể loại mạnh nhất và khu vực để top 10 không đồng nhất.
- **Lý do**: mỗi thành phần cao nhất (tối đa 3) sinh một mã lý do (`skill_match`, `near`, `free_on_date`, `top_rated`, `fast_reply`, `new_talent`) và câu tiếng Việt.
- **Không dùng** huy hiệu hay tích xanh làm điểm trong v1 (tránh tự củng cố); xem xét ở bản sau.

### 3e.7 Tín hiệu và nhật ký

- Ứng dụng gửi lô tín hiệu qua hàm `recommendFeedback`: `impression` (thẻ hiện ≥ 50% trong ≥ 1 giây), `click` (mở S03.01), `inquiry` (mở S05.04 hoặc gửi tin nhắn), `booking` (cọc thành công). Mỗi tín hiệu mang `requestId`, `photographerId`, `rank`, `algorithmVersion`.
- Chỉ lưu mã người dùng đã băm, không lưu SĐT, vị trí chính xác hay nội dung tin nhắn. Giữ nhật ký 180 ngày.
- Sở thích rõ ràng của khách (chọn "Bạn cần chụp gì?") là câu hỏi mở số 12; v1 dùng tín hiệu ngầm (thể loại đã xem, đã lưu, đã tìm).

### 3e.8 Đánh giá và nâng cấp

| Việc | Cách làm |
|------|----------|
| Đo | Offline: NDCG@10, tỉ lệ nhiếp ảnh gia xuất hiện (độ phủ). Online: tỉ lệ bấm, tỉ lệ liên hệ, tỉ lệ đặt lịch trên lượt xem. |
| Nâng bản | Triển khai `Scorer` mới cạnh bản cũ, chạy **shadow** (tính nhưng không hiển thị, so sánh kết quả), rồi A/B 10% → 50% → 100%. Quay về bản cũ bằng cấu hình. |
| Hướng v2 | Nhúng ảnh portfolio, học xếp hạng từ nhật ký (`ltr-v2`), lọc cộng tác theo hành vi, gợi ý sự kiện (cùng API). |
| Công bằng | Giám sát độ phủ theo thể loại/khu vực; cảnh báo nếu top 10 bị chiếm bởi một nhóm nhỏ. |

### 3e.9 Điểm gắn trong ứng dụng

| Màn | Dùng gợi ý |
|-----|-----------|
| S02.01 | Thứ tự "Dành cho bạn", "Rảnh tuần này" |
| S03.01 | Mục "Thợ ảnh tương tự" |
| S02.06 | Sắp xếp mặc định "Phù hợp nhất" (cùng "Gần tôi", "Giá", "Đánh giá"); chip lý do trên thẻ |
| S02.04 | Giai đoạn sau: gợi ý sự kiện cùng API |

## 3g. Tiền treo (escrow) và chi trả

Thay thế phần "cọc chuyển thẳng tới tài khoản nền tảng và trả hàng tuần" ở mục 8 của spec gốc.

### 3g.1 Nguyên tắc (đã chốt)

- Mọi khoản khách trả qua ứng dụng (tiền cọc booking, tiền vé sự kiện) vào **tài khoản của nền tảng** và ở trạng thái **treo (`held`)**. Nhiếp ảnh gia hoặc chủ sự kiện **chỉ nhận tiền sau khi buổi chụp / sự kiện hoàn thành** (`completed`). Nhờ đó hoàn tiền chỉ là trả lại số đang treo, không phải đòi lại từ nhiếp ảnh gia.
- Phần còn lại sau cọc (70%) khách trả tại buổi chụp, không đi qua nền tảng.
- Mỗi khoản thanh toán có `escrowStatus`:

```
held ──(booking/sự kiện completed + hết cửa sổ khiếu nại)──▶ released ──(đưa vào lô chi trả, chuyển khoản xong)──▶ paid_out
 │ ├──(hoàn một phần)──▶ partially_refunded            released: số dư chờ chi trả của người nhận
 │ └──(hoàn toàn bộ)───▶ refunded
 └──(khách khiếu nại)──▶ disputed ──(admin xử lý)──▶ released | refunded | partially_refunded
```

### 3g.2 Khi nào thả tiền

| Khoản | Điều kiện thả (`held → released`) | Người nhận |
|-------|-----------------------------------|------------|
| Cọc booking | `Booking.status = completed` (nhiếp ảnh gia bấm hoàn thành, hoặc hệ thống sau `end + 24 giờ`) và hết cửa sổ khiếu nại `dispute_window_hours` (đề xuất 24 giờ) | Nhiếp ảnh gia của booking |
| Phần không hoàn khi huỷ muộn | Sau thời điểm `start` của buổi lẽ ra diễn ra + cửa sổ khiếu nại | Nhiếp ảnh gia (bồi thường huỷ muộn) |
| Vé sự kiện (host nhiếp ảnh gia) | `Event.status = completed` (sau `endAt`), chỉ vé còn hiệu lực; hết cửa sổ khiếu nại | Nhiếp ảnh gia host |
| Vé sự kiện (host `platform`) | Sau `completed` | Giữ ở nền tảng (doanh thu), không chi trả |

Khách khiếu nại trong cửa sổ khiếu nại → khoản thành `disputed`, khoản chi trả liên quan `on_hold` cho tới khi `admin` xử lý.

### 3g.3 Hoàn tiền

- Hoàn tiền **chỉ lấy từ số đang treo**, theo chính sách đã chốt: booking huỷ ≥ 48 giờ hoàn 100%, 24–48 giờ hoàn 50%, < 24 giờ không hoàn; nhiếp ảnh gia huỷ, từ chối hoặc hết hạn nhận → hoàn 100%; vé sự kiện huỷ ≥ 48 giờ hoàn 100%, sau đó không hoàn; chủ huỷ sự kiện hoàn 100%.
- Hoàn qua cổng gốc (MoMo/VNPay) về đúng phương thức khách đã trả; cổng không hỗ trợ hoàn tự động → đánh dấu `manual` và tạo việc cho `admin`.
- Sau khi tiền đã `released`/`paid_out` mà phát sinh hoàn (khiếu nại muộn): trừ vào lần chi trả kế tiếp (bút toán `adjustment`), không đòi trực tiếp.

### 3g.4 Chi trả cho nhiếp ảnh gia

- Nhiếp ảnh gia khai **tài khoản nhận tiền** (ngân hàng) ở S06.06 trước khi nhận được tiền; thiếu thì khoản vẫn tích luỹ ở `released` và ứng dụng nhắc thêm tài khoản.
- Giai đoạn đầu `admin` duyệt từng lô và chuyển khoản thủ công (xuất tệp đối soát); sau đó tự động qua API chi hộ của ngân hàng/cổng. Mỗi lô `Payout` gồm nhiều khoản `released`, trạng thái `pending → processing → paid` (hoặc `failed`, `on_hold`).
- v1 không thu hoa hồng, nhưng sổ cái có sẵn bút toán `fee` để bật sau.

### 3g.5 Sổ cái (ledger)

Mọi biến động tiền là một **bút toán bất biến** (append‑only) trong `ledger_entries`: `deposit_received`, `ticket_received`, `refund_issued`, `escrow_released`, `payout_paid`, `fee_charged`, `adjustment`. Số dư treo của một khoản = tổng bút toán; không sửa/xoá bút toán, chỉ thêm bút toán đảo. Đối soát hằng ngày: tổng `*_received` − `refund_issued` phải khớp báo cáo của cổng. Dữ liệu và bảng ở [data-model](data-model/).

### 3g.6 Hiển thị trong ứng dụng

- Khách: dòng thông báo "Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành" (`EscrowNotice`) ở S04.03, S05.02, S11.03, S11.04.
- Nhiếp ảnh gia: S05.02 ghi rõ "Cọc {số tiền} đang được giữ, chuyển cho bạn sau khi hoàn thành"; S06.01 ô số liệu "Đang giữ"; **S06.05 Thu nhập** (đang giữ, sắp nhận, đã nhận, lịch sử, từng khoản) và **S06.06 Tài khoản nhận tiền**.
- Staff `admin`: màn duyệt lô chi trả và khiếu nại nằm ở bảng điều khiển quản trị (ngoài phạm vi ứng dụng khách; câu hỏi mở 18).

### 3g.7 Pháp lý

Việc nền tảng nhận và giữ tiền hộ bên thứ ba có thể thuộc **dịch vụ trung gian thanh toán** cần giấy phép của Ngân hàng Nhà nước, hoặc phải đi qua cổng/ngân hàng cung cấp dịch vụ ký quỹ hợp pháp. Cần tham vấn pháp lý trước khi ra mắt (câu hỏi mở 19).

## 3h. Thông báo (S17)

Hộp thư thông báo trong app (S17.01), cài đặt thông báo (S17.02) và sheet xin quyền (S17.03). Push dùng FCM; token lưu ở `devices/{uid}_{installId}` theo kế hoạch [`2026-10-01-instant-i4-photographer-app.md`](../plans/2026-10-01-instant-i4-photographer-app.md). Mock: mục "Thông báo" trong `docs/design/ui-mock.html`.

### 3h.1 Hành vi

- **Điểm vào**: biểu tượng chuông ở S02.01, S02.03, S06.01 kèm chấm số `NotificationBell`; Cài đặt (S09.02) → "Thông báo" → S17.02; biểu tượng bánh răng ở S17.01 → S17.02.
- **Chấm số**: đọc từ `users/{uid}.unreadCount`, "9+" từ mười trở lên, ẩn khi 0. Trình đọc màn hình đọc "3 thông báo chưa đọc", không đọc số trần.
- **Danh sách (S17.01)**: chia mục Hôm nay / 7 ngày qua / Trước đó; lọc bằng `SegmentedTabs` (khách: Tất cả · Đặt lịch · Sự kiện · Hệ thống; NAG: Tất cả · Công việc · Sự kiện · Hệ thống). Mỗi dòng: biểu tượng loại trong vòng tròn tô nhạt, tiêu đề đậm, nội dung tối đa 2 dòng, thời gian tương đối ("5 phút"), chưa đọc = chấm tím bên trái **và** nhãn ngữ nghĩa "Chưa đọc" (không chỉ dựa vào màu), thumbnail 40dp tuỳ chọn (booking, sự kiện).
- **Gom nhóm**: các thông báo cùng `groupKey` gộp thành một dòng, ví dụ "3 nhiếp ảnh gia đã báo giá cho việc 'Chụp kỷ yếu'" → mở S15.03. Phía server cập nhật dòng gộp (tăng `actorIds`, đẩy `createdAt`, xoá `readAt`) thay vì tạo dòng mới.
- **Chạm** = đánh dấu đã đọc + đi tới `target` (deep link). **Nhấn giữ** mở menu "Đánh dấu đã đọc / Tắt loại thông báo này" (không có thao tác chỉ vuốt). Hành động đầu trang: "Đánh dấu tất cả đã đọc".
- **Phân trang**: 30 mục mỗi trang, skeleton khi tải. Empty state có một hành động ("Khám phá nhiếp ảnh gia" cho khách, "Mở Công việc" cho NAG).
- **Lời mời Chụp ngay không là thông báo trong hộp thư**: chúng mở thẳng màn toàn hình S14.02 (giữ nguyên spec Chụp ngay). Hộp thư chỉ ghi một dòng "Bạn đã bỏ lỡ một lời mời" sau khi hết hạn.

### 3h.2 Các loại thông báo

| `type` | Vai trò | Biểu tượng (sprite mock) | Mục lọc | `target` | Ghi chú |
|--------|---------|--------------------------|---------|----------|---------|
| `booking_accepted` | khách | `i-cal`, tông xanh | Đặt lịch | `/bookings/:id` (S05.02) | |
| `booking_declined` | khách | `i-cal`, tông đỏ | Đặt lịch | `/bookings/:id` | Nêu hoàn cọc |
| `shoot_reminder` | khách (và NAG) | `i-cam` | Đặt lịch / Công việc | `/bookings/:id` | Trước 24 giờ và/hoặc 2 giờ theo S17.02 |
| `quote_new` | khách | `i-brief` | Đặt lịch | `/jobs/:id/applications` (S15.03) | Gom theo `groupKey = job:<id>:quotes` |
| `instant_assigned` | khách | `i-bolt` | Đặt lịch | `/instant/:id` (S13.05) | |
| `refund_done` | khách | `i-card` | Đặt lịch | `/bookings/:id` | |
| `event_soon` | khách | `i-ticket` | Sự kiện | `/events/:id` (S11.02) hoặc vé S11.04 | |
| `booking_request` | NAG | `i-cal`, tông vàng | Công việc | `/work` (S06.01) | Còn 24 giờ để nhận |
| `job_match` | NAG | `i-brief` | Công việc | `/jobs/:id` (S16.01) | |
| `job_invited` | NAG | `i-brief` | Công việc | `/jobs/:id` (S16.01) | |
| `job_selected` | NAG | `i-check` | Công việc | `/work` | Bạn được chọn |
| `payout_released` | NAG | `i-card` | Hệ thống | `/earnings` (S06.05) | |
| `badge_new` | cả hai | `i-award` | Hệ thống | `/u/:uid/badges` (S03.02) | |
| `review_new` | cả hai | `i-star` | Hệ thống | hồ sơ của mình (S09.01) | |
| `chat_message` | cả hai | `i-chat` | Hệ thống | `/chat/:roomId` (S07.01) | Chỉ khi app ở nền; gom theo phòng |
| `instant_missed` | NAG | `i-bolt`, tông xám | Công việc | `/work/instant` (S14.01) | Bản ghi "bỏ lỡ lời mời" |
| `promo` | cả hai | `i-info` | Hệ thống | theo `target` | Tắt mặc định (S17.02) |

Mỗi loại đúng một biểu tượng; tông màu theo ngữ nghĩa (xanh = thành công, vàng = cần hành động, đỏ = bị từ chối, tím = mặc định).

### 3h.3 Dữ liệu

```
users/{uid}/notifications/{id}
  type, title, body
  target            # đường dẫn deep link, ví dụ "/bookings/01J…"
  groupKey?         # gom dòng (xem 3h.1)
  actorIds?         # tối đa 3 id để vẽ avatar; tổng số nằm trong `count`
  thumbUrl?, count?
  createdAt, readAt?   # readAt null = chưa đọc

users/{uid}.unreadCount                      # số nguyên, Functions tăng/giảm
users/{uid}/private/notification_prefs       # S17.02, chỉ chủ đọc/ghi
  channels: {booking, jobs, instant, events, chat, badges, promo}: {push: bool, inApp: bool}
  quietHours: {enabled, from: "22:00", to: "07:00"}
  reminders: {h24: bool, h2: bool}
devices/{uid}_{installId}                    # token FCM (kế hoạch I4)
```

- **Chỉ server ghi** thông báo và `unreadCount`. Client chỉ được đặt `readAt` (rule Firestore giới hạn đúng trường này); "Đánh dấu tất cả đã đọc" gọi callable `markAllNotificationsRead`.
- Mặc định `prefs`: mọi loại bật Push và Trong app, riêng `promo` tắt cả hai; giờ yên lặng 22:00–07:00 bật; nhắc 24 giờ và 2 giờ bật.
- Tôn trọng `prefs` ở server: kênh Trong app tắt thì không tạo dòng; kênh Push tắt thì không gửi FCM.

### 3h.4 Pin và dữ liệu mạng

- Không polling. Chỉ lắng nghe 30 mục mới nhất **khi S17.01 đang mở**; ở nơi khác chỉ lắng nghe trường `unreadCount` của `users/{uid}`.
- Đánh dấu đã đọc được gom lô (debounce ~1 giây hoặc khi rời màn) thành một `WriteBatch`; cập nhật lạc quan ở UI.
- Push chỉ mang `type`, `target` và tiêu đề/nội dung ngắn; chi tiết đọc lại từ Firestore khi mở.

### 3h.5 Giờ yên lặng

Mặc định 22:00–07:00 (múi giờ Asia/Ho_Chi_Minh): push đến im lặng (không âm, không rung), vẫn vào hộp thư. Ngoại lệ, vẫn phát âm: **giao dịch quan trọng** là lời mời Chụp ngay khi NAG đang bật "Live Shutter", thanh toán, và huỷ lịch. Nhắc buổi chụp trước 24 giờ và 2 giờ bật/tắt riêng.

### 3h.6 Thời điểm xin quyền (S17.03)

- Chỉ hỏi **sau một hành động có ý nghĩa**, không bao giờ khi mở app lần đầu. Khách: sau khi đặt lịch, mua vé hoặc gửi yêu cầu Chụp ngay ("Bật thông báo để biết khi Minh Trí nhận lịch"). NAG: khi bật "Live Shutter" hoặc khi nhận booking đầu tiên.
- Sheet nêu lợi ích, nút chính "Bật thông báo" (gọi hộp thoại quyền của hệ điều hành), nút phụ "Để sau". "Để sau" lưu thời điểm và hỏi lại sau **7 ngày**, tại một hành động có ý nghĩa kế tiếp. Nếu OS đã từ chối vĩnh viễn thì không hỏi lại mà dùng banner của S17.02 ("Mở Cài đặt").
- Android 13+ cần `POST_NOTIFICATIONS`; iOS xin `UNAuthorizationOptions`.

### 3h.7 Cloud Functions

`notify(uid, type, payload)` dùng chung: kiểm tra `prefs`, ghi `notifications/{id}`, tăng `unreadCount`, gửi FCM tới mọi `devices/{uid}_*`. Được gọi từ các trigger booking, báo giá, sự kiện, huy hiệu, chi trả, và cron nhắc lịch. `markAllNotificationsRead` (callable) đặt `readAt` hàng loạt và đưa `unreadCount` về 0.

## 3i. Use case bổ sung (2026-10-02)

Rà lại toàn bộ spec, mô hình dữ liệu và backend đã thiết kế thì thấy sáu luồng có thật nhưng chưa có màn: backend hoặc quy tắc đã nhắc tới (`openDispute`, `photographers.verified` "do admin duyệt", "Đã lưu, đang theo dõi" ở S09.01, nút báo cáo ở nhóm chat, hoàn tiền `manual` "tạo việc cho admin") nhưng người dùng chưa có chỗ để làm. Mã theo quy tắc mục 2 (use case mới lấy `Sxx` kế tiếp). Mỗi use case cần mock và đặc tả màn trước khi viết plan.

### 3i.1 S18 · Khiếu nại & hỗ trợ
- **Vì sao cần**: tiền treo (mục 3g) có trạng thái `disputed` và cửa sổ khiếu nại, S06.05 có "Đang khiếu nại", nhưng khách chưa có màn để mở khiếu nại hay xem kết quả.
- **Luồng**: S05.02 / S11.04 hiện "Báo vấn đề" khi booking `completed` hoặc vé đã dùng và còn trong `dispute_window_hours` → S18.01 → `openDispute` (khoản tiền `held → disputed`, khoản chi trả `on_hold`) → S18.02 theo dõi; nhiếp ảnh gia nhận thông báo, xem S18.02 và gửi giải trình; staff xử lý ở S23.01 (`resolveDispute`: thả / hoàn / chia), hai bên nhận thông báo và tiền đi theo kết quả.
- **Quy tắc**: một khiếu nại mở cho mỗi booking hoặc vé; quá cửa sổ thì nút ẩn và S18.03 giải thích; ảnh bằng chứng lưu riêng tư (chỉ hai bên và staff đọc); không có kênh liên hệ ngoài app mới nào được mở vì khiếu nại.
- **S18.03 Trợ giúp**: câu hỏi thường gặp tĩnh (tiền treo, huỷ, hoàn, Chụp ngay) và "Liên hệ hỗ trợ" mở chat với hộp thư hỗ trợ (S23.06, câu hỏi mở 16).

### 3i.2 S19 · Lưu & theo dõi
- **Vì sao cần**: S09.01 có hàng số "đang theo dõi · đã lưu" đang ẩn vì chưa có danh sách; nút lưu ở S02.02 và tín hiệu "đã lưu" của gợi ý (mục 3e.7) cần nơi xem lại.
- **Quy tắc**: lưu bài và lưu nhiếp ảnh gia là hai danh sách riêng; theo dõi chỉ áp dụng cho nhiếp ảnh gia; bài mới của người mình theo dõi ưu tiên trong feed "Dành cho bạn"; danh sách người theo dõi chỉ chủ hồ sơ xem; số đếm công khai.

### 3i.3 S20 · Báo cáo & chặn
- **Vì sao cần**: có chat 1‑1, nhóm chat sự kiện, timeline hashtag và bài công khai; spec đã nhắc "báo cáo tin nhắn" (mục 3.7) và câu hỏi mở 21, nhưng chưa có luồng chung. Cửa hàng ứng dụng cũng yêu cầu báo cáo và chặn cho nội dung do người dùng tạo.
- **Luồng**: menu "…" trên hồ sơ, bài, tin nhắn (nhấn giữ), sự kiện → S20.01 (lý do cố định + mô tả, tuỳ chọn "Chặn người này") → hàng đợi S23.05.
- **Chặn**: hai bên không thấy bài của nhau trong feed, không nhắn được, không đặt lịch được với nhau (booking đang có vẫn giữ để không mất tiền; liên hệ đi qua hỗ trợ); bỏ chặn ở S20.02.

### 3i.4 S21 · Xác minh
- **S21.01 SĐT** (câu hỏi mở 6): bật cờ `phoneVerified` sau OTP; khi bật thì S04.05 thêm bước OTP. Chọn nhà cung cấp OTP trước khi làm.
- **S21.02 Dấu tích xanh**: nhiếp ảnh gia đủ điều kiện (đề xuất: hồ sơ hoàn thiện ≥ 80%, ≥ 3 buổi `completed`, không khiếu nại thua trong 90 ngày) gửi yêu cầu kèm giấy tờ tuỳ thân và link portfolio; staff duyệt ở S23.04; kết quả ghi `photographers.verified` (chỉ server ghi). Giấy tờ lưu riêng tư, xoá sau khi duyệt xong 30 ngày.

### 3i.5 S22 · Thanh toán & tài khoản
- **S22.01**: khách xem mọi khoản đã trả và đang được giữ, kể cả tiền Chụp ngay đang treo khi chưa tìm được người (spec Chụp ngay), hoàn tiền đang xử lý và đã xong; mỗi dòng mở chi tiết booking/vé/yêu cầu. Nhiếp ảnh gia đã có S06.05 cho tiền nhận.
- **S22.02 Xoá tài khoản** (bắt buộc với Google Play và App Store khi có đăng ký tài khoản): chặn khi còn booking chưa xong, vé chưa diễn ra, tiền đang giữ hoặc khiếu nại mở (liệt kê từng thứ kèm lối đi); xoá dữ liệu cá nhân, giữ bút toán sổ cái ẩn danh theo yêu cầu kế toán; bài công khai gỡ xuống.
- **S22.03**: ẩn hồ sơ khỏi gợi ý và tìm kiếm (nhiếp ảnh gia vẫn nhận khách cũ), tải bản sao dữ liệu (gửi link qua email trong 48 giờ).

### 3i.6 S23 · Vận hành nội bộ (staff)
- **Vì sao cần**: `resolveDispute`, `executePayout`, hoàn tiền `manual`, duyệt dấu tích xanh, kiểm duyệt báo cáo và hộp thư hỗ trợ đều cần người của nền tảng thao tác (vai trò `admin`, `sales`, có thể `finance`, câu hỏi mở 18).
- **Nền tảng chưa chốt** (câu hỏi mở 22): web nội bộ riêng hay chế độ staff trong app. Mã S23 vẫn đặt để mọi spec tham chiếu chung; route là "nội bộ" cho tới khi chốt.
- **Quy tắc**: mọi quyết định của staff ghi nhật ký kiểm toán (ai, lúc nào, lý do); tiền chỉ di chuyển qua callable phía server, không sửa tay dữ liệu.

## 4. Thành phần dùng chung cần viết trước

Đặc tả từng widget (API, biến thể, trạng thái, truy cập, test) ở [`components/shared-components.md`](components/shared-components.md); bảng dưới là danh sách tóm tắt.

Đưa vào `lib/core/widgets/` và export qua `core.dart` (theo quy ước `package:photobooking/...`, không dùng import tương đối).

| Widget | Dùng ở | Ghi chú |
|--------|--------|---------|
| `CtaSurface` | `AppButton`, tab giữa | **Đã có** (mục 1.1) |
| `ScreenCode` | mọi màn | mục 2.1 |
| `VerifiedMark` | S02.02, S03.01, S02.06, S11.02, S12.03 | mục 3d.1 |
| `BadgeChip`, `BadgeTile` | S03.01, S09.01, S03.02, thẻ nhiếp ảnh gia | mục 3d.2; chip tối đa 3 trên thẻ |
| `PhotoCard` | S02.01, S02.03, S10.01 | ảnh 4:5/3:4, pill trái/phải, lớp phủ đáy |
| `PhotographerCard` | S02.01, S02.06 | hero 16:9 + hàng meta + 2 nút |
| `BookingCard` | S05.02, S05.01, S06.01, S07.01 | thumb, tên + gói, ngày giờ, badge; slot hành động dưới |
| `EventCard` | S02.03, S11.01, S12, S02.04 | khối ngày (`DateBlock`), tên, chủ, tag loại, giá, số chỗ, khoảng cách; biến thể "nổi bật" ảnh lớn |
| `BlurScrim`, `ImageBackdrop` | mọi sheet/dialog; S03.01, S11.02, S01.03 | Lớp mờ ảnh (mục 1.2) |
| `AppBottomSheet` | S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05 | radius 28, tối đa 88% cao, nút chính ở đáy, xác nhận khi đóng với dữ liệu đã nhập |
| `StepProgress` | S04.01–S04.03, S08.01, S12.01, S12.02, S08.05, S08.02 | chỉ báo "n / N" + thanh tiến độ gradient |
| `SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter` | S08.02–S08.04 | Chip chọn từ danh mục, chọn mức 3 nấc, chọn ảnh minh chứng, thanh độ khớp hồ sơ |
| `ReasonChips` | S02.01, S02.06 | Lý do gợi ý (tối đa 2 chip), từ `reasons[].text` |
| `AvailabilityCalendar` | S04.02, S06.04, tab Lịch ở S03.01 | 4 trạng thái ngày, ngày chọn tô gradient |
| `StatusTimeline` | S05.02 | 7 bước, bước hiện tại nổi |
| `StatTile` | S06.01, S12.03 | Số lớn (Fraunces, tabular) + nhãn một dòng bên dưới. Ba ô cùng một hàng bằng `IntrinsicHeight` + `Expanded`; nhãn dùng `FittedBox(scaleDown)` để không xuống dòng khi chữ hệ thống phóng 1,3×; nhãn màu `foregroundSecondary` (≥ 4,5:1) |
| `CapacityBar` | S11.02, S12.03 | thanh + chữ "14 / 20 đã đăng ký"; không chỉ dựa vào màu |
| `TicketCard` | S11.04 | thẻ `highlight`, QR (`qr_flutter`), mã vé chọn‑copy được |
| `ContactDial` | S05.02, S11.02 (sau khi có vé), S06.01, S12.03 (bung thành S05.04); S03.01, S11.02 trước khi đặt chỉ là nút chat | Nút gọn; chỉ bung các kênh khi bấm (mục 3b.5). Kênh lấy từ `photographers.contact` (hoặc `customerContact` ở S06.01/S12.03); ẩn kênh không dùng được |
| `PhoneField` | S04.05, S08.05, S09.03, S11.03 | mục 3b.3 |
| `LocationPromptCard` | S02.03 | trạng thái: chưa hỏi, đang hỏi, từ chối |
| `SegmentedTabs` | S03.01, S05.01, S11.04, S06.01, S10.01 | thay cho `seg` của mock |
| `FilterChip` biến thể | S02.01, S02.06, S04.02, S11.01, S02.04 | hai kiểu như mục 1 |

## 5. Đặc tả từng màn

Bảng dưới là bản tóm tắt. **Đặc tả đầy đủ từng màn (mục đích, điểm vào, bố cục, dữ liệu, trạng thái, tương tác, chuỗi hiển thị, sự kiện phân tích, tiêu chí chấp nhận)** nằm trong `docs/superpowers/specs/screens/`; xem `README.md` ở đó để tra theo mã.

Mọi màn dùng chung: loading = skeleton (không spinner chặn > 1 giây); lỗi = thông điệp tiếng Việt + nút thử lại; offline đọc cache, nút ghi bị vô hiệu kèm giải thích; vùng chạm ≥ 48dp, khoảng cách giữa hai vùng chạm ≥ 8dp; chữ hệ thống tới 1,3× không cắt (xuống dòng, không `ellipsis` cho nội dung chính); layout kiểm tra ở 320/360/390/430dp và ≥ 600dp (2 cột cho S02.01, S02.06, S02.03, S11.01, S02.04). Controller là `AsyncNotifier` theo spec gốc; UI không gọi repository trực tiếp.

### Khách

| Mã | Nội dung chính | Trạng thái & ràng buộc | Chấp nhận |
|----|----------------|------------------------|-----------|
| S02.01 | Header chào + chuông + chat; chip danh mục; thẻ ảnh lớn; "Rảnh tuần này" ngang; "Buổi chụp thật" | Empty: `EmptyState` có nút "Khám phá nhiếp ảnh gia". Feed phân trang 20/lần. Chấm lịch lấy từ `stats.nextFreeDate`. | Chạm ảnh → S02.02; chạm tên → S03.01; pill "Rảnh T7" hiện đúng ngày thật. |
| S02.02 | Ảnh lớn, tác giả + `VerifiedMark`, mô tả, like/save/vị trí/chia sẻ, gói gắn bài, "Thêm của …" | Like/save lạc quan, hoàn tác khi lỗi. Bài `real_shoot` hiện "Chụp bởi … · gói …". | "Đặt gói này" mở S04.01 đã chọn gói (bỏ bước 1); thiếu SĐT → S04.05 trước. |
| S03.01 | Hero, avatar, tên + `VerifiedMark`, thống kê, bio, **hàng huy hiệu** (+ "Xem tất cả" → S03.02), tab Portfolio/Gói/Lịch/Đánh giá; nút cố định gồm nút **Nhắn tin hỏi trước** (biểu tượng chat, mở chat `inquiry`) + **Đặt lịch** | Tab Lịch dùng `AvailabilityCalendar` chỉ đọc. Chưa có đánh giá → empty có chữ rõ. Chưa có huy hiệu → ẩn hàng. | Nút chat mở chat hỏi trước (không có gọi/Zalo/WhatsApp trước khi đặt); "Đặt lịch" mở S04.01 (qua S04.05 nếu thiếu SĐT). |
| S02.06 | Chip lọc đã điền (khu vực, ngày, dịch vụ, giá, sao), đếm kết quả, danh sách `PhotographerCard` (tên + `VerifiedMark`, tối đa 2 huy hiệu) | Khu vực mặc định lấy từ vị trí hoặc khu vực đã chọn (mục 3c). Không kết quả: gợi ý nới bộ lọc, nút "Xoá bộ lọc". | "Đặt T7" mở S04.02 với ngày và dịch vụ sẵn (qua S04.05 nếu thiếu SĐT). |
| S04.01 | Chọn gói (thumb, mô tả, giá); tổng tiền trên nút | Bước 3 Địa điểm: bản đồ nhỏ + ô địa chỉ, mặc định từ lọc. Đóng sheet khi đã chọn → hỏi xác nhận. | Chuyển bước giữ lựa chọn khi quay lại. |
| S04.02 | Lưới tháng 4 trạng thái; chip giờ theo `durationMinutes`; gợi ý giờ của nhiếp ảnh gia | Ngày "Chờ" xem được, không chọn được. Kiểm tra lại availability khi vào bước 4. | Ngày bị chiếm → lỗi `day_taken`, quay S04.02 với ngày gạch. |
| S04.03 | Tóm tắt booking, hàng **Ghi chú + SĐT của bạn** (lấy từ hồ sơ, sửa được), bảng tiền, chính sách huỷ, MoMo/VNPay | Nút "Đặt cọc" loading + vô hiệu khi đang gọi `createDeposit`. SĐT sai/thiếu → lỗi dưới ô, không gọi cổng. | Thành công mở cổng; client không tin redirect, chờ `bookings.status`. |
| S04.04 | Vòng chờ, giải thích, `BookingCard`, "Kiểm tra lại", "Đổi cổng" | Hiện sau 5 phút chưa `paid`. 30 phút → booking `draft` bị dọn, báo cho người dùng. | "Kiểm tra lại" gọi Function hỏi cổng; `paid` → tự chuyển S05.02. |
| S05.02 | Toast cọc, `BookingCard`, `StatusTimeline`, hàng hai nút "Nhắn tin" + `ContactDial` "Liên hệ", nút chữ Huỷ; "Đổi lịch" nằm trong menu `…` ở thanh trên | Một màn cho mọi trạng thái; hành động hiện theo trạng thái. Hôm diễn ra: nút "Chỉ đường". | "Liên hệ" bung S05.04; huỷ mở S05.03 kèm số tiền hoàn. |
| S05.03 | Bảng hoàn cọc, dòng áp dụng nổi bật, số tiền nhận lại, lý do, Giữ lịch / Huỷ | Lý do mặc định "Đổi kế hoạch". Nút đỏ chỉ trong sheet này. | Sau huỷ: `cancelled`, toast, availability được nhả. |
| S07.01 | Thanh ngữ cảnh booking, hành động nhanh, bong bóng, ô nhập + gửi + ảnh | Realtime qua snapshot; gửi lỗi → thử lại tại chỗ. Tin `system` cho đổi lịch. | Gửi ảnh nén ≤ 2048px. |
| S05.05 | Sao, nhận xét (bắt buộc), lưới chọn ảnh chia sẻ (≤ 10) | "Chỉ đánh giá" hoặc "Gửi & chia sẻ n ảnh". Chỉ mở khi booking `completed`. | Tạo `reviews/{bookingId}` + post `real_shoot`; có thể kích hoạt huy hiệu (toast "Bạn nhận huy hiệu …"). |
| S02.03 | Ô tìm kiếm; nhóm Dịch vụ/Địa điểm/Phong cách/Thợ ảnh; **thẻ "Sự kiện gần bạn"** xin vị trí; section Sự kiện chụp ảnh | Trạng thái vị trí: chưa hỏi (thẻ), cho phép → S02.04, từ chối/để sau → chip "Chọn khu vực" → S02.05. Section sự kiện ẩn nếu không có sự kiện sắp tới. | Chỉ bấm "Cho phép" mới hiện hộp thoại quyền; "Xem tất cả" → S11.01. |
| S05.01 | `SegmentedTabs` Sắp tới / Đang chờ / Đã xong; `BookingCard` có hành động | Empty mỗi nhóm có hành động riêng. Đã xong chưa review: nút "Đánh giá". | Chạm card → S05.02. |
| S02.04 | Dòng "Quanh Quận 1 · vị trí gần đúng" + Đổi, chip bán kính/thời gian, thẻ sự kiện nổi bật, danh sách sắp theo khoảng cách | Không có sự kiện trong bán kính → gợi ý tăng bán kính hoặc tạo sự kiện (NAG). Khoảng cách làm tròn 0,1 km. | Đổi khu vực → S02.05; chạm thẻ → S11.02. |
| S02.05 | Sheet chọn quận/thành phố (radio), "Mở Cài đặt để bật vị trí" (chỉ khi từ chối vĩnh viễn), "Dùng khu vực này" | Nhớ khu vực lần trước. Đóng không chọn = giữ trạng thái cũ. | Lưu khu vực ở máy; S02.06, S11.01 dùng chung. |
| S05.04 | `ContactDial` đã bung **sau khi đã đặt**: khay phía trên nút với ba biểu tượng tròn xếp ngang (Gọi, Zalo, WhatsApp), mỗi biểu tượng có nhãn chữ; Zalo và WhatsApp dùng đúng biểu tượng của hãng (mục 3b.6) | Chỉ có khi booking/vé đã mở khoá liên hệ (mục 3b.1); trước đó S03.01/S11.02 chỉ có nút chat hỏi trước. Mặc định chỉ thấy nút nhỏ. Chỉ kênh nhiếp ảnh gia bật và máy mở được; còn một kênh thì bấm nút mở thẳng. Mỗi lựa chọn gọi `getContactLink` rồi mở ứng dụng ngoài. | Gọi mở trình quay số với số đúng; Zalo/WhatsApp mở đúng cuộc trò chuyện; chưa mở khoá thì không có kênh nào ngoài chat. |
| S04.05 | `PhoneField` (+84), hai công tắc cho phép Zalo/WhatsApp, ghi chú riêng tư, "Lưu và tiếp tục" | Lưu vào `users/{uid}/private/contact`. Hợp lệ mới bật nút. Đóng sheet = huỷ đặt lịch, quay lại màn trước. | Lưu xong quay lại đúng bước qua `returnTo`; hồ sơ có số thì sheet không hiện nữa. |
| S03.02 | Tiêu đề "Huy hiệu" + đếm đã đạt; nhóm "Từ đánh giá" và "Từ hệ thống"; `BadgeTile` (biểu tượng, tên, điều kiện); của mình có huy hiệu chưa đạt (mờ) + tiến độ | Của người khác: chỉ huy hiệu đã đạt, ẩn tiến độ. Chưa có huy hiệu: empty nêu huy hiệu gần nhất có thể đạt. Chạm ô → sheet nhỏ nêu điều kiện, ngày đạt. | Tiến độ khớp `badgeProgress`; huy hiệu mới đạt có chấm "Mới" đến lần mở kế tiếp. |

### Sự kiện

| Mã | Nội dung chính | Trạng thái & ràng buộc | Chấp nhận |
|----|----------------|------------------------|-----------|
| S11.01 | AppBar + biểu tượng lịch; chip loại; thẻ nổi bật; danh sách `EventCard`; sắp xếp "Sớm nhất / Gần tôi" | Chỉ `open/full`. Hết chỗ vẫn hiện, ghi "Hết chỗ" bằng chữ. Empty: "Chưa có sự kiện" + (NAG) nút "Tạo sự kiện". | Lọc theo loại giữ khi quay lại; tablet 2 cột. |
| S11.02 | Ảnh bìa, tag loại, tên (Fraunces), `SegmentedTabs` **Thông tin / Timeline / Nhóm chat** (tab Nhóm chat chỉ mở cho thành viên; người khác thấy khoá và lý do), chủ sự kiện + `VerifiedMark` + nút **Nhắn tin hỏi trước** (sau khi có vé: `ContactDial`), ngày giờ (thêm vào lịch), địa điểm + điểm hẹn, `CapacityBar`, mô tả; thanh dưới giá + "Đăng ký tham gia" | `full`/`closed`/`cancelled`: nút thành trạng thái chữ. Đã đăng ký: nút thành "Xem vé" → S11.04. Chủ xem: nút "Quản lý" → S12.03. | Deep link `/e/:id` mở được sau khi qua login (giữ `from`). |
| S11.03 | Stepper số vé (1–4), họ tên, SĐT, bảng tiền, chính sách huỷ, MoMo/VNPay, nút thanh toán | Giữ chỗ 10 phút có đếm ngược. Không thu phí: bỏ cổng, nút thành “Xác nhận đăng ký”. `sold_out` → quay S11.02. Họ tên, SĐT lấy sẵn từ hồ sơ; thiếu SĐT → S04.05. | Thanh toán xong → S11.04 với vé mới. |
| S11.04 | `SegmentedTabs` Buổi chụp / Vé sự kiện; `TicketCard` (QR, mã vé, Chỉ đường, Thêm vào lịch); Huỷ vé; vé chờ thanh toán | Vé sắp diễn ra là thẻ `highlight`. Huỷ vé cần xác nhận, hiện số tiền hoàn. Vé đã qua mờ, không QR. | QR chứa `ticketCode`; mã chọn‑copy được. |

### Nhiếp ảnh gia

| Mã | Nội dung chính | Trạng thái & ràng buộc | Chấp nhận |
|----|----------------|------------------------|-----------|
| S06.01 | Buổi hôm nay (thẻ `highlight`), Yêu cầu mới (Nhận · đếm ngược / Từ chối), hàng KPI (`StatTile` ×3: Tháng này · **Đang giữ** · Buổi sắp tới; số lớn ở trên, nhãn một dòng bên dưới, cùng một hàng và cao bằng nhau; chạm ô "Đang giữ" → S06.05), section **Sự kiện của tôi**; thẻ yêu cầu có `ContactDial` liên hệ khách khi đã cọc | Đếm ngược theo `acceptDeadline`; hết hạn → thẻ biến mất, toast. Số khách chỉ hiện sau cọc (mục 3b.1). | Nhận → `accepted` + mở chat; Từ chối → S06.03. |
| S06.04 | Chọn tháng, lưới 4 trạng thái, chú giải, danh sách buổi trong ngày, "Đánh dấu nghỉ" | Chạm ngày trống → `off` (hoàn tác bằng snackbar). Ngày có sự kiện hiện chấm riêng và mở S12.03. | Khách thấy cùng trạng thái ở S04.02. |
| S10.01 | `SegmentedTabs` **Bài đăng / Sự kiện**; Bài đăng: lưới ảnh (≤ 10), mô tả, gói (bắt buộc), địa điểm, phong cách, "Thêm vào portfolio". Sự kiện: chuyển sang S12.01 | Thiếu gói → nút Đăng vô hiệu và lỗi dưới trường. Nháp tự lưu cục bộ. | Đăng xong về S02.01 với bài mới ở đầu. |
| S06.02 | Empty "Buổi chụp tiếp theo bắt đầu từ đây" + một hành động nuôi vòng lặp | Chọn câu và hành động theo số ảnh portfolio hiện có. | Nút dẫn tới S10.01. |
| S06.03 | Lý do (radio, bắt buộc), thông báo hoàn cọc, Quay lại / Từ chối | Nút đỏ chỉ sáng sau khi chọn lý do. | `declined` + hoàn cọc 100%; khách nhận push kèm lý do. |
| S08.01 | `StepProgress` bước 1 (giới thiệu) và 2 (gói: danh sách gói, form thêm gói) | Cần ≥ 1 gói mới sang bước 3 (kỹ năng). Chưa xong thì không đổi được vai trò (chặn ở nút "Chuyển qua chế độ nhiếp ảnh" của S09.02). | Sang S08.02. |
| S08.02 | `StepProgress` 3/4; thể loại (chip, tối đa 6), mức độ từng thể loại (`LevelSelector`), thanh độ khớp, dòng minh chứng | Mức "Chuyên sâu" tối đa 3 và cần ≥ 1 ảnh minh chứng (S08.04). Lưu nháp tự động. Thoát giữa chừng hỏi lưu nháp. | Ít nhất 1 thể loại mới sang S08.05; `skills.completeness` do Function tính sau khi lưu; S08.02 hiện số đó ở lần mở sau. |
| S08.03 | Cùng màn S08.02, phần cuộn: phong cách, kỹ năng thêm, ngôn ngữ, khách phù hợp, số năm kinh nghiệm | Giới hạn theo mục 3e.2; ít nhất 1 ngôn ngữ. | Giá trị lưu đúng id trong `taxonomy`. |
| S08.04 | Sheet chọn 1–3 ảnh portfolio làm minh chứng cho một thể loại, bộ đếm "n / 3" | Chỉ hiện bài của chính mình; chưa có bài nào → empty nêu "Đăng bài trước" kèm nút tới S10.01. | Lưu `evidencePostIds`; ảnh minh chứng hiện huy hiệu nhỏ trên thẻ ở S03.01. |
| S08.05 | `StepProgress` 4/4; khu vực phục vụ, SĐT bắt buộc, ba công tắc kênh (Gọi, Zalo, WhatsApp kèm số riêng) | Cần ≥ 1 SĐT hợp lệ; WhatsApp bật mà để trống thì dùng SĐT chính nếu hợp lệ quốc tế, không thì báo lỗi. | Hoàn tất → `onboardingComplete = true`, ghi `photographers/{uid}.contact`. |
| S12.01 | `StepProgress` 1/2; ảnh bìa 16:10, tên (bắt buộc), loại (chip đơn), mô tả | Nháp tự lưu mỗi lần đổi bước; "Quay lại" khi có dữ liệu → hỏi lưu nháp. | Sang S12.02 giữ dữ liệu. |
| S12.02 | Ngày, giờ bắt đầu/kết thúc, sức chứa, địa điểm, giá, hạn đăng ký, thẻ **xem trước** (`EventCard`), Lưu nháp / Đăng sự kiện | Kiểm tra: `endAt > startAt`, `startAt` ở tương lai, `capacity ≥ 1`, `price ≥ 0` (0 = không thu phí), hạn đăng ký ≤ `startAt`, ngày chưa bị `booked`. Lỗi dưới từng trường, có tóm tắt lỗi khi submit thất bại. | Đăng xong: toast, mở S12.03. Sự kiện hiện ở S11.01/S02.03 ngay. |
| S12.03 | `EventCard`, KPI (đăng ký/sức chứa, doanh thu, ngày còn lại), danh sách người tham gia kèm trạng thái và `ContactDial` từng người, "Nhắn nhóm", "Quét mã check‑in", "Huỷ sự kiện" | Quét QR (`mobile_scanner`) gọi `checkInRegistration`; đã check‑in → báo rõ. Huỷ mở sheet xác nhận nêu số vé và tổng tiền sẽ hoàn. | Check‑in cập nhật dòng tương ứng trong < 2 giây. |

| S06.05 | Ba ô `StatTile` (Đang giữ · Sắp nhận · Đã nhận), danh sách khoản thu theo booking/sự kiện kèm trạng thái tiền (Đang giữ, Chờ chi trả, Đã chuyển, Đang khiếu nại), nút "Tài khoản nhận tiền" | Thiếu tài khoản nhận tiền → dải nhắc "Thêm tài khoản để nhận tiền" (→ S06.06). Chỉ khoản của chính mình. | Số khớp sổ cái (mục 3g.5); khoản đang khiếu nại hiện lý do tạm giữ. |
| S06.06 | Chọn ngân hàng, số tài khoản, tên chủ tài khoản (tự điền theo tra cứu nếu có), xác nhận | Số tài khoản chỉ lưu mã hoá và hiện che ("•••• 3456"); đổi tài khoản cần xác nhận lại mật khẩu/OTP khi có. | Tài khoản hợp lệ mới bật nút; chi trả dùng tài khoản đang bật. |

| S11.05 | Tên sự kiện + `SegmentedTabs` Thông tin / **Timeline** / Nhóm chat; chip hashtag `#PhotoWalkPhoCo1020` + số bài; lưới masonry 2 cột bài viết (tác giả phủ chữ); thanh dưới "Đăng ảnh với #hashtag" | Mọi người xem; nút đăng chỉ cho người tham gia/chủ/staff; bài `pending` chỉ chủ/staff thấy ở tab "Chờ duyệt"; empty "Chưa có ảnh, hãy là người đầu tiên"; tải theo trang 20. | Bài có hashtag trong chú thích tự xuất hiện trong vài giây; chủ sự kiện ẩn được bài; chạm bài → S02.02 kèm chip sự kiện. |
| S11.06 | Tên sự kiện + "n thành viên"; tin ghim ở đầu; danh sách tin (tên người gửi hiện trên tin của người khác); ô nhập (ảnh, vị trí) | Chỉ thành viên vào; hết hạn → chỉ đọc kèm dải "Nhóm đã đóng"; điều hành có menu (ghim, xoá, tắt tiếng, gỡ); tin mới theo thời gian thực. | Vé `paid` tự vào nhóm; vé hoàn thì bị gỡ; không thấy số điện thoại của nhau; "Nhắn nhóm" ở S12.03 hiện ở đây dạng tin ghim. |

### Đã có (S01.03, S01.05, S09.01, S09.02)

Thay đổi: **S09.01 thành danh sách bài đăng của chính người dùng** (cả khách lẫn nhiếp ảnh gia: lưới 3 cột, chip lọc theo loại `work` / `real_shoot` / `event_share`, hàng số bài đăng · đang theo dõi · đã lưu, **hàng huy hiệu** → S03.02). **Đổi chế độ và đăng xuất chuyển sang S09.02**, cùng các hàng "Số điện thoại" (→ S04.05), "Kỹ năng" (→ S08.02) và "Xem hồ sơ công khai"; S09.02 có thêm "Kiểu nút chính" (**đã làm**), công tắc debug "Hiện mã màn hình" (mục 2.1), giao diện và kiểu nút dạng `SegmentedTabs`. S09.03 Sửa hồ sơ thêm `PhoneField`; hồ sơ nhiếp ảnh gia có hàng "Kỹ năng" mở S08.02.

## 6. Thứ tự triển khai

Giữ khung sub‑project của spec gốc, thêm **3b**. Mỗi bước: kế hoạch ngắn → code → test → review.

| Bước | Nội dung | Màn |
|------|----------|-----|
| 0 | `ScreenCode` + `screen_codes.dart` + công tắc debug; áp mã lên màn hiện có | — |
| 1 | Widget dùng chung ở mục 4 (kèm golden sáng/tối, chữ 1,3×), gồm `VerifiedMark` | — |
| 2 | Hồ sơ nhiếp ảnh gia, thiết lập, lịch, **liên hệ và SĐT**, **kỹ năng** | S03.01, S06.04, S08.01, S05.04, S04.05, S08.05, S08.02–S08.04, S09.03 |
| 3 | Nội dung và khám phá, **vị trí** | S02.01, S02.02, S02.06, S02.03, S10.01, S02.04, S02.05 |
| 3r | **Dịch vụ gợi ý** v1: `services/recommender`, hàm `recommend`/`recommendFeedback`, `RecommendationRepository` (+ `LocalRecommender`) | dùng ở S02.01, S03.01, S02.06 |
| 3b | **Sự kiện**: model, repo, rules, Functions, màn khách, màn NAG | S11.01–S11.04, S12 |
| 4 | Đặt lịch, thanh toán, chat (có chặn `phone_required`) | S04.01–S04.04, S05.02, S05.03, S07.01, S05.01 |
| 5 | Công việc | S06.01, S06.02, S06.03 |
| 6 | Hậu buổi chụp và **huy hiệu** (cần đánh giá để tính) | S05.05, S03.02 |

Lý do đặt 3b sau 3: sự kiện dùng lại hồ sơ nhiếp ảnh gia, `EventCard` cùng họ với `PhotoCard`, vị trí ở bước 3, và luồng thanh toán MoMo/VNPay của bước 4. Để không chặn nhau, 3b dùng cổng thanh toán giả (Function mock trả `paid`); bật cổng thật khi bước 4 xong.

## 7. Kiểm thử bổ sung

- **Unit**: tính hoàn vé theo thời điểm; `registerEvent` không bán quá `capacity` khi nhiều yêu cầu đồng thời (emulator, chạy song song); `releaseExpiredHolds`; sinh `ticketCode` không trùng; validate form S12.02; **chuẩn hoá và kiểm tra số điện thoại** (ví dụ hợp lệ/không hợp lệ: `0903123456`, `+84 903 123 456`, `090312345`, `0123456789`); dựng URL `tel`/`zalo.me`/`wa.me`; máy trạng thái quyền vị trí (chưa hỏi, cho phép, từ chối, từ chối vĩnh viễn, dịch vụ tắt), geohash lân cận và khoảng cách; **luật huy hiệu** (đạt ngưỡng, dưới `minSample`, bị gỡ khi chỉ số tụt, trao không trùng).
- **Gợi ý**: `LocalRecommender` và `RemoteRecommendationRepository` cùng qua bộ test hợp đồng; test `rules-v1` với tập nhiếp ảnh gia mẫu (thể loại, ngày, ngân sách) kiểm thứ tự và lý do; lọc ngày kín; MMR giữ đa dạng; dịch vụ chậm quá 800 ms thì ứng dụng dùng dự phòng; validate lược đồ `skills` (giới hạn số lượng, id lạ, mức 3 thiếu minh chứng).
- **Rules**: client không ghi `registeredCount/heldCount/status/ticketCode/checkedInAt`; khách khác không đọc registration người khác; chỉ chủ sửa sự kiện của mình; **`users/{uid}/private/contact` và `badgeProgress` chỉ chủ đọc/ghi**; `users/{uid}/badges` client không ghi; `customerContact` chỉ ghi bởi Function và chỉ hai bên đọc; `transitionBooking` từ chối `phone_required`.
- **Widget/golden**: `StatTile` (ba ô 320dp, chữ 1,3×: không tràn, nhãn một dòng), `EventCard`, `TicketCard`, `CapacityBar`, `StepProgress`, `ScreenCode`, `ContactDial` (bung/đóng, một kênh, giảm chuyển động), `PhoneField`, `LocationPromptCard`, `VerifiedMark`, `BadgeChip`, `BadgeTile` (sáng/tối, chữ 1,3×, 320dp). **Đã có**: `CtaSurface` (gradient sáng/tối, kiểu avatar) và `ButtonStyleController`.
- **Integration (emulator)**: tạo sự kiện → khách đăng ký → thanh toán giả → vé → check‑in; hết chỗ; hết hạn giữ chỗ; chủ huỷ hoàn mọi vé; khách chưa có SĐT bị chặn rồi đặt được sau khi thêm; hoàn thành booking và review kích hoạt huy hiệu.
- **Thủ công**: checklist ui‑ux‑pro‑max — tương phản ≥ 4,5:1 cả hai theme và với mọi ảnh avatar (thử ảnh trắng, đen, nhiều màu), tích xanh và huy hiệu không chỉ dựa vào màu (có nhãn đọc màn hình), `reduced motion`, focus rõ, vùng chạm ≥ 48dp; thử mở Zalo/WhatsApp trên máy có và không có app; thử từ chối quyền vị trí hai lần.

## 8. Câu hỏi mở

1. **Ai tạo sự kiện?** (đã chốt): nhiếp ảnh gia, hoặc tài khoản `admin`/`sales` của ứng dụng (mục 3.6). Khách và tổ chức bên ngoài (CLB, trường) không tạo trong v1.
2. **Hoàn vé** (đã chốt): huỷ trước 48 giờ hoàn 100%, sau đó không hoàn; chủ huỷ hoàn 100%.
3. **Tiền vé và cọc** (đã chốt): treo ở nền tảng, chỉ chuyển cho nhiếp ảnh gia / chủ sự kiện sau khi hoàn thành (mục 3g). Còn mở: độ dài cửa sổ khiếu nại (đề xuất 24 giờ) và số ngày tối đa từ lúc hoàn thành tới lúc chi trả.
4. **Quyền riêng tư số của khách**: đề xuất chỉ hiện sau cọc và xoá khỏi `customerContact` 30 ngày sau hoàn thành. Có cần giữ lâu hơn (bảo hành ảnh, tranh chấp)?
5. **Liên hệ ngoài app** (đã chốt): gọi/Zalo/WhatsApp chỉ mở sau khi đã đặt; trước đó chỉ có chat hỏi trước trong app (mục 3b.1). Còn mở: sau `completed` giữ kênh mở bao lâu (đề xuất 30 ngày).
6. **Xác minh SĐT** (làm sau): dùng Firebase Phone Auth (OTP SMS, có chi phí SMS ở VN) hay xác minh qua Zalo? Quyết định trước khi mở rộng để tránh đổi cấu trúc dữ liệu.
\1 (đã được xác nhận) Còn mở: có cần lọc từ khoá (số điện thoại, "chuyển khoản") trong tin hỏi trước để chống lách nền tảng không?
8. **Nhắn nhóm** ở S12.03: thông báo một chiều (đề xuất) hay phòng chat nhóm?
9. **Ảnh avatar làm nút** (đã chốt): chỉ dùng avatar, không cho chọn ảnh khác. Hiệu ứng mờ ảnh dùng cho modal và trang giới thiệu (mục 1.2).
10. **Huy hiệu**: danh mục khởi đầu ở mục 3d.2 có đủ không, ai duyệt thêm/bớt (admin trong console hay màn riêng)? Huy hiệu của khách có công khai không (đề xuất: công khai trên hồ sơ, chỉ khi khách bật)? Có cấp bậc (đồng, bạc, vàng) cho huy hiệu số lượng không?
15. **Biểu tượng Zalo/WhatsApp**: bản Simple Icons dùng tạm cho dev. Cần lấy tài nguyên chính thức của hai hãng và xác nhận điều khoản dùng thương hiệu trước khi phát hành.
16. **Hộp thư hỗ trợ** (đề xuất ở mục 3.7, cần xác nhận): chat hỏi trước của sự kiện do nền tảng tổ chức đi vào hộp thư chung của staff, mặc định giao cho `createdBy`, `sales`/`admin` nhận hoặc giao lại. Cần quyết định có hạn phản hồi (SLA) và thông báo cho ai khi quá hạn không.
21. **Kiểm duyệt timeline và nhóm chat**: ai chịu trách nhiệm nội dung (chủ sự kiện, staff), có cần bộ lọc ảnh nhạy cảm tự động và nút báo cáo gửi về đâu? Bài của người ngoài chờ duyệt có làm chủ sự kiện quá tải không (đề xuất: bật tự duyệt theo người theo dõi)?
17. **Tạo hộ nhiếp ảnh gia**: có bắt buộc nhiếp ảnh gia đồng ý (`hostConsent`) như đề xuất, hay sales được tạo thẳng khi đã thoả thuận ngoài ứng dụng?
18. **Quản trị chi trả**: bảng điều khiển duyệt lô chi trả, khiếu nại và đối soát cổng nằm ở đâu (web nội bộ riêng, Firebase console + callable tạm thời)? Có cần vai trò `finance` ngoài `admin`/`sales`?
19. **Pháp lý giữ tiền hộ**: tham vấn xem mô hình treo tiền có cần giấy phép trung gian thanh toán hay đi qua cổng có sản phẩm ký quỹ; quyết định trước khi bật cổng thật.
20. **Phần không hoàn khi huỷ muộn** (50% hoặc 100% giữ lại): giả định chuyển cho nhiếp ảnh gia như bồi thường; xác nhận hoặc cho nền tảng giữ một phần.
11. **Kỹ năng và gợi ý**: danh mục khởi đầu (3e.2) có đủ cho thị trường Việt Nam không, ai duy trì `taxonomy`? Có cho nhiếp ảnh gia tự đề xuất kỹ năng mới không (qua duyệt)?
12. **Sở thích của khách**: có thêm câu hỏi khởi đầu "Bạn cần chụp gì?" (và ngân sách, phong cách) để bớt phụ thuộc tín hiệu ngầm không?
13. **Hạ tầng gợi ý** (đề xuất, cần xác nhận): làm theo hai giai đoạn ở mục 3e.4, bắt đầu bằng `recommender-core` trong hàm `recommend`, tách Cloud Run khi chạm ngưỡng.
22. **Công cụ vận hành (S23)**: web nội bộ riêng hay chế độ staff trong app? Ai được thấy giấy tờ xác minh và bằng chứng khiếu nại?
23. **Điều kiện dấu tích xanh (S21.02)**: ngưỡng đề xuất ở mục 3i.4 có hợp lý không? Có thu phí xác minh không?
24. **Chặn khi đang có booking (S20)**: đề xuất giữ booking và liên hệ qua hỗ trợ; hay cho huỷ không mất cọc?
25. **Xoá tài khoản (S22.02)**: thời gian lưu sổ cái ẩn danh và bài công khai (gỡ ngay hay sau 30 ngày cho phép khôi phục)?
14. Giữ nguyên các câu hỏi mở 1–4 của spec gốc (cổng thanh toán, admin, tỉ lệ cọc, tên/applicationId).
