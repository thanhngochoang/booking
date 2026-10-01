# Đặc tả từng màn hình

Chi tiết cho mọi màn `S01–S46` của spec `../2026-10-01-remaining-screens.md` (gọi là "spec chính"). Mock hi‑fi: https://claude.ai/artifact/LptNpoqnt5KjQ5tUaPjYDM (bật "Debug" để thấy mã; thêm `#S12` vào link để nhảy tới màn). Widget dùng chung có tài liệu riêng ở `../components/shared-components.md`.

## Mục lục

| Tệp | Màn |
|-----|-----|
| [discovery.md](discovery.md) | S01 Trang chủ · S02 Chi tiết ảnh · S03 Hồ sơ nhiếp ảnh gia · S04 Tìm thợ ảnh · S13 Khám phá · S35 Khám phá đã bật vị trí · S36 Chọn khu vực |
| [booking.md](booking.md) | S05–S07 Đặt lịch · S08 Chờ thanh toán · S09 Chi tiết booking · S10 Huỷ booking · S11 Hội thoại · S14 Danh sách đặt lịch · S32 Liên hệ · S33 Thêm số điện thoại |
| [events.md](events.md) | S15 Danh sách sự kiện · S16 Chi tiết · S17 Đăng ký · S18 Vé · S25–S26 Tạo sự kiện · S27 Quản lý sự kiện |
| [photographer.md](photographer.md) | S19 Công việc · S20 Lịch · S21 Đăng bài · S22 Empty Công việc · S23 Từ chối · S24 Thiết lập hồ sơ · S34 Khu vực & liên hệ · S38–S40 Kỹ năng |
| [account.md](account.md) | S12 Đánh giá & chia sẻ · S28 Đăng nhập · S29 Chọn vai trò · S30 Hồ sơ cá nhân · S31 Cài đặt · S37 Huy hiệu · S41 Đăng ký · S42 Sửa hồ sơ |

## Mẫu cho mỗi màn

Mỗi màn có đúng các mục sau (bỏ mục không áp dụng và ghi "—").

- **Thông tin**: mã, route, vai trò, sub‑project (theo bảng mục 2 của spec chính), trạng thái hiện thực (Đã có / Chưa có).
- **Mục đích**: một câu, việc người dùng làm xong màn này.
- **Điểm vào → điểm ra**: từ đâu vào, đi tiếp đâu.
- **Bố cục**: các khối từ trên xuống, tên widget dùng chung.
- **Dữ liệu**: provider/controller, nguồn (Firestore, Function, cục bộ), phân trang, làm mới.
- **Trạng thái**: loading, empty, lỗi, offline và các trạng thái riêng của màn.
- **Tương tác**: hành động, kiểm tra hợp lệ, phản hồi.
- **Chuỗi tiếng Việt**: các chuỗi chính (khóa ARB `sNN_…`).
- **Phân tích**: sự kiện ghi lại.
- **Chấp nhận**: điều kiện kiểm được để coi là xong.
- **Ghi chú truy cập/responsive**: chỉ khi khác quy ước chung.

## Quy ước chung (áp dụng cho mọi màn, không nhắc lại)

**Cấu trúc code.** Mỗi màn là một thư mục `lib/features/<tên>/` gồm `<tên>_screen.dart`, `<tên>_controller.dart` (Riverpod `AsyncNotifier`), `widgets/` riêng. Màn không gọi repository trực tiếp. Import dạng `package:photobooking/...` và dùng barrel `core/core.dart`. Mỗi màn bọc `ScreenCode(ScreenCodes.sNN, …)`.

**Nền và khung.** `AuroraBackground` + `Scaffold` trong suốt. Màn trong tab nằm dưới `TabShell`; màn ngoài tab là route đẩy lên, có nút Back; sheet dùng `AppBottomSheet`.

**Loading.** Skeleton (`AppSkeleton`) đúng hình khối nội dung, không spinner chặn quá 1 giây. Nút gửi dùng `loading` của `AppButton` và vô hiệu trong lúc chạy.

**Lỗi.** `ErrorState` với thông điệp tiếng Việt suy từ mã lỗi, có "Thử lại". Lỗi thao tác (gửi, huỷ) dùng SnackBar nổi, giữ nguyên dữ liệu đã nhập. Lỗi mạng hiện "Không có kết nối" và vô hiệu nút ghi, không xếp hàng ghi.

**Offline.** Màn đọc dữ liệu từ cache Firestore, hiện dải "Đang xem dữ liệu đã lưu". Màn chỉ ghi (thanh toán, huỷ) hiện lý do không thể.

**Truy cập.** Vùng chạm ≥ 48dp, khoảng cách giữa hai vùng chạm ≥ 8dp. Mọi biểu tượng đứng một mình có `Semantics.label`. Trạng thái không chỉ dựa vào màu (luôn có chữ hoặc biểu tượng). Tiêu điểm bàn phím thấy rõ, thứ tự Tab theo thứ tự thị giác. Tôn trọng `MediaQuery.disableAnimations`.

**Responsive.** Kiểm ở 320, 360, 390, 430dp và ≥ 600dp. Chữ hệ thống tới 1,3× không cắt (xuống dòng; không `ellipsis` cho nội dung chính). Hộp cùng cấp trong một hàng dùng `IntrinsicHeight` + `Expanded`. Màn có danh sách chuyển 2 cột từ 600dp (S01, S04, S13, S15, S35). Tôn trọng safe area; thanh dưới cố định có đệm cuối để nội dung không bị che.

**Nút dưới cùng.** Nút chính ở đáy màn hoặc đáy sheet cao đúng 52dp và cùng chiều cao trên mọi màn (S05–S07 cũng vậy); không co giãn theo nội dung sheet. Nút phụ cùng hàng (Quay lại, Lưu nháp) cùng chiều cao với nút chính.

**Số tiền, ngày giờ.** `1.500.000₫` (dấu chấm ngăn nghìn, `₫` sau); rút gọn `1,5M` chỉ trên thẻ nhỏ. Ngày `T7 12/10`, giờ `15:30`, múi giờ Asia/Ho_Chi_Minh. Giá 0 của sự kiện hiển thị tag “Không thu phí”, không bao giờ “0₫”. Số dùng chữ số đều (`tabularFigures`).

**Phân tích.** Mỗi màn gửi `screen_view{code}` khi hiện. Tên sự kiện `snake_case`, tham số không chứa số điện thoại, vị trí chính xác hay nội dung tin nhắn.

**Vai trò.** Màn nói "khách" hay "NAG" là vai trò được vào; vai trò khác vào route thì chuyển về `/home`. Ngoài hai vai trò chọn ở S29 còn có quyền nhân viên `admin` và `sales` (custom claim `staffRole`, không tự chọn được); hiện chỉ dùng để tạo và quản lý sự kiện (spec chính mục 3.6).

**Chuỗi.** Mọi chuỗi trong `lib/l10n/app_vi.arb`, khóa `sNN_…` cho chuỗi riêng màn, khóa chung cho chuỗi dùng lại (`commonRetry`, `commonCancel`…). Không hard‑code.

## Kết quả mong đợi khi hoàn tất một màn

1. Khớp mock ở cả hai theme (tối/sáng) và cả hai kiểu nút chính.
2. Qua các kiểm tra responsive ở bảng trên.
3. Có widget test cho trạng thái chính (có dữ liệu, trống, lỗi) và test controller bằng repository giả.
4. Mã màn hiển thị ở chế độ debug, khớp bảng mã.
