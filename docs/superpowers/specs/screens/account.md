# Tài khoản, hồ sơ cá nhân, đánh giá, huy hiệu

Màn: S12, S28, S29, S30, S31, S37, S41, S42. Quy ước chung ở [README.md](README.md). S28–S31 và S41–S42 đã có trong code, mục này ghi hành vi hiện tại và thay đổi cần làm.

---

## S12 · Đánh giá và chia sẻ

- **Thông tin**: `/b/:id/review` · khách · sub‑project 6 · Chưa có.
- **Mục đích**: khép vòng: đánh giá và chia sẻ ảnh thành "Buổi chụp thật".
- **Điểm vào → ra**: push "Buổi chụp thế nào?" (sau `endTime` + 24 giờ hoặc khi NAG bấm "Đã giao ảnh"), S09, S14. Gửi xong → S09 (`reviewed`).
- **Bố cục**: Back + "Buổi chụp thế nào?"; `BookingCard` thu gọn; 5 sao lớn (chạm chọn, giữ trượt chọn); ô nhận xét (bắt buộc, 10–1000 ký tự); section "Chia sẻ ảnh bạn thích" (tuỳ chọn, ≤ 10) với lưới ảnh chọn từ thư viện; nhắc "Ảnh hiện trong 'Buổi chụp thật' trên Trang chủ và hồ sơ {tên}, có tag nhiếp ảnh gia"; thanh dưới "Chỉ đánh giá" + "Gửi & chia sẻ {n} ảnh".
- **Dữ liệu**: ghi `reviews/{bookingId}` (một đánh giá/booking) và, nếu có ảnh, bài `posts` `kind=real_shoot` (`bookingId`, `serviceId`). Function `onReviewWrite` cập nhật `stats` và huy hiệu.
- **Trạng thái**: chưa chọn sao hoặc nhận xét ngắn → nút vô hiệu; đang tải ảnh → tiến độ từng ảnh; booking chưa `completed` → chặn; đã đánh giá → chuyển sang xem lại, không sửa.
- **Chuỗi**: `s12_title` "Buổi chụp thế nào?", `s12_text` "Nhận xét", `s12_share` "Chia sẻ ảnh bạn thích", `s12_optional` "Tuỳ chọn", `s12_onlyReview` "Chỉ đánh giá", `s12_submitShare` "Gửi & chia sẻ {n} ảnh".
- **Phân tích**: `review_submit{rating, shared}`.
- **Chấp nhận**: đánh giá lên hồ sơ NAG; bài chia sẻ mang nhãn "Buổi chụp thật" và link tới gói; một booking chỉ một đánh giá; toast huy hiệu nếu vừa đạt.

---

## S28 · Đăng nhập (đã có)

- **Thông tin**: `/login` · không cần đăng nhập · sub‑project 1 · **Đã có** (`LoginScreen`).
- **Mục đích**: đăng nhập bằng email, Google, Facebook.
- **Bố cục**: `AuroraBackground`, logo, `AuroraHero` ("Bắt trọn / mọi khoảnh khắc", tagline "Tìm thợ ảnh hợp gu, đặt lịch chỉ vài chạm."), `GlassCard` viền spectrum chứa tiêu đề, ô email, ô mật khẩu (nút hiện/ẩn), nút chính "Đăng nhập", chia "hoặc", hai nút Google (trắng) và Facebook (xanh) cạnh nhau khi đủ rộng, xếp dọc khi hẹp; liên kết "Đăng ký".
- **Chuỗi (đã có)**: `loginHeadlineLead` "Bắt trọn", `loginHeadlineAccent` "mọi khoảnh khắc", `loginTagline`, `loginWelcome` "Chào bạn!", `loginWelcomeBody` "Đăng nhập để tiếp tục", `emailLabel`, `passwordLabel`, `loginButton` "Đăng nhập", `loginOrDivider` "hoặc", `socialGoogle`, `socialFacebook`, `noAccountPrompt` "Chưa có tài khoản?", `registerLink` "Đăng ký", `showPassword`/`hidePassword`.
- **Hành vi hiện tại**: kiểm tra email và mật khẩu; một nút chạy thì nút khác vô hiệu; lỗi hiện qua SnackBar theo `AuthError`.
- **Thay đổi cần làm**: dòng gradient của `AuroraHero` đã sửa để không cắt dấu tiếng Việt; thêm `ScreenCode`; cho phép trình quản lý mật khẩu và dán (đã có `autofillHints`).
- **Chấp nhận**: không cắt dấu ở ổ, ụ, ặ; nút chính theo kiểu nút đã chọn (mặc định gradient).

---

## S29 · Chọn vai trò (đã có)

- **Thông tin**: `/onboarding/role` · sau lần đăng nhập đầu · sub‑project 1 · **Đã có** (`RoleScreen`).
- **Mục đích**: chọn khách hay nhiếp ảnh gia, lưu vào `users`.
- **Chuỗi (đã có)**: `roleTitle` "Bạn muốn làm gì?", `roleCustomerTitle` "Thuê nhiếp ảnh gia" / `roleCustomerBody`, `rolePhotographerTitle` "Nhận chụp" / `rolePhotographerBody`, `roleContinue` "Tiếp tục", `signOut` "Đăng xuất", `roleSaveError`.
- **Hành vi hiện tại**: hai thẻ chọn đơn (có viền và nền tím khi chọn), nút "Tiếp tục" (loading), nút chữ "Đăng xuất"; lỗi lưu → SnackBar.
- **Thay đổi cần làm**: chọn "Nhiếp ảnh gia" thì sau khi lưu dẫn tới S24 (thiết lập hồ sơ) thay vì thẳng vào tab; thêm `ScreenCode`.
- **Chấp nhận**: chưa có vai trò thì mọi route khác chuyển về màn này.

---

## S30 · Hồ sơ cá nhân (đã có, mở rộng)

- **Thông tin**: `/profile` · cả hai · sub‑project 1 (mở rộng ở 2, 3, 6) · **Đã có** dạng cơ bản (`ProfileTab`).
- **Mục đích**: xem hồ sơ của mình, đổi chế độ khách ⇄ nhiếp ảnh gia, vào Cài đặt, đăng xuất.
- **Chuỗi**: `profileRoleCustomer` "Khách hàng", `profileRolePhotographer` "Nhiếp ảnh gia", `profileOfferPhotographerTitle`/`Body`, `profileOfferCustomerTitle`/`Body`, `profileSwitchToPhotographer`, `profileSwitchToCustomer`, `profileSwitchedTo*`, `profileSwitchError`, `signOut`.
- **Hành vi hiện tại**: avatar, tên, nhãn vai trò; thẻ chuyển vai trò (khách ⇄ nhiếp ảnh gia) có loading và SnackBar. Thẻ nói việc người dùng làm ở chế độ kia: khách thấy tiêu đề **"Tôi là nhiếp ảnh gia"**, nút **"Chuyển qua chế độ nhiếp ảnh"**; nhiếp ảnh gia thấy **"Tôi cần đặt lịch"**, nút **"Chuyển qua chế độ đặt lịch"** (khóa `profileOffer*`, `profileSwitchTo*`, `profileSwitchedTo*`; **đã làm trong code**); nút đăng xuất ở đáy; biểu tượng Cài đặt.
- **Bố cục bổ sung**: hàng **huy hiệu** (`BadgeChip` ≤ 3 + "Xem tất cả" → S37); hàng "Số điện thoại" (→ S33); với NAG thêm hàng "Kỹ năng" (→ S38, kèm `CompletenessMeter` nhỏ) và "Xem hồ sơ công khai" (→ S03 của chính mình); với khách thêm "Đã lưu", "Đang theo dõi", "Bài đã chia sẻ" (sub‑project 3 và 6).
- **Trạng thái**: chuyển sang NAG khi hồ sơ chưa xong → mở S24 thay vì đổi ngay; avatar lỗi tải → biểu tượng người; offline cho xem, vô hiệu đổi vai trò.
- **Chấp nhận**: chuyển vai trò không mất dữ liệu; huy hiệu và độ khớp hồ sơ đúng người dùng.

---

## S31 · Cài đặt (đã có, thêm mục)

- **Thông tin**: `/settings` · cả hai · sub‑project 1 · **Đã có** (`SettingsScreen`).
- **Mục đích**: đổi thông tin tài khoản, giao diện và kiểu nút chính.
- **Chuỗi (đã có)**: `settingsTitle` "Cài đặt", `settingsAccount`, `settingsEditProfile`, `settingsEditProfileBody`, `settingsAppearance`, `themeDark`/`themeLight`/`themeSystem`, `settingsButtonStyle`, `buttonStyleGradient`, `buttonStyleAvatar`, `buttonStyleAvatarNeedsPhoto`, `settingsButtonPreview`.
- **Hành vi hiện tại**: nhóm Tài khoản (Chỉnh sửa hồ sơ → S42); nhóm Giao diện (Tối / Sáng / Theo hệ thống, lưu `themeMode`); nhóm **Kiểu nút chính** (Gradient theo giao diện / Ảnh đại diện làm mờ, khóa kèm lời nhắc khi chưa có avatar, lưu `buttonStyle`) và nút xem trước.
- **Thay đổi cần làm**: thêm công tắc "Hiện mã màn hình" (chỉ khi `kDebugMode`); thêm nhóm Quyền riêng tư (vị trí đã lưu, xoá khu vực), Thông báo, Trợ giúp & điều khoản (sub‑project sau).
- **Chuỗi (đã có)**: `settingsTitle`, `settingsAppearance`, `themeDark`/`themeLight`/`themeSystem`, `settingsButtonStyle`, `buttonStyleGradient`, `buttonStyleAvatar`, `buttonStyleAvatarNeedsPhoto`, `settingsButtonPreview`.
- **Chấp nhận**: đổi theme và kiểu nút có hiệu lực ngay, giữ sau khi mở lại app; nút xem trước đúng kiểu đã chọn; thanh tab dưới cao 64dp.

---

## S37 · Huy hiệu

- **Thông tin**: `/u/:uid/badges` · cả hai · sub‑project 6 · Chưa có.
- **Mục đích**: ghi nhận người dùng qua huy hiệu từ đánh giá và từ hệ thống.
- **Điểm vào → ra**: hàng huy hiệu ở S03 và S30. Chạm một ô → sheet nhỏ nêu điều kiện và ngày đạt.
- **Bố cục**: Back + "Huy hiệu" + "5 / 12"; section "Từ đánh giá" (đếm đạt/tổng) và "Từ hệ thống"; lưới 2 cột `BadgeTile` (biểu tượng tròn tô `CtaSurface`, tên, điều kiện); huy hiệu chưa đạt (chỉ của chính mình) có biểu tượng xám và `CapacityBar` "3 / 5".
- **Dữ liệu**: `users/{uid}/badges` (đã đạt, công khai); `users/{uid}/private/badgeProgress` (tiến độ, chỉ chủ); danh mục `badges/{id}`.
- **Trạng thái**: người khác chỉ thấy huy hiệu đã đạt, ẩn tiến độ; chưa có huy hiệu → empty nêu huy hiệu gần nhất có thể đạt; huy hiệu mới đạt có chấm "Mới" đến lần mở kế tiếp.
- **Chuỗi**: `s37_title` "Huy hiệu", `s37_fromReviews` "Từ đánh giá", `s37_fromSystem` "Từ hệ thống", `s37_new` "Mới", `s37_progress` "{cur} / {target}".
- **Phân tích**: `badges_open{own}`, `badge_detail{badgeId}`.
- **Chấp nhận**: tiến độ khớp `badgeProgress`; client không ghi huy hiệu; tích xanh Verified không xuất hiện ở đây (khác khái niệm).

---

## S41 · Đăng ký (đã có)

- **Thông tin**: `/register` · không cần đăng nhập · sub‑project 1 · **Đã có** (`RegisterScreen`).
- **Mục đích**: tạo tài khoản bằng email và mật khẩu.
- **Chuỗi (đã có)**: `registerHeadlineLead` "Tham gia", `registerHeadlineAccent` "cộng đồng ảnh", `registerTagline`, `registerTitle` "Tạo tài khoản", `registerWelcomeBody`, `displayNameLabel`, `emailLabel`, `passwordLabel`, `passwordConfirmLabel`, `registerButton` "Đăng ký", `haveAccountPrompt` "Đã có tài khoản?", `loginButton`.
- **Hành vi hiện tại**: tạo tài khoản email, kiểm tra hợp lệ (`auth_form_validators`), lỗi theo `AuthError`.
- **Thay đổi cần làm**: thêm `ScreenCode`; sau đăng ký chuyển S29. Số điện thoại **không** hỏi ở đây (chỉ hỏi khi đặt lịch, S33).
- **Chấp nhận**: mật khẩu theo quy tắc hiện có; trình quản lý mật khẩu hoạt động.

---

## S42 · Sửa hồ sơ (đã có, thêm mục)

- **Thông tin**: `/settings/profile` · cả hai · sub‑project 1 · **Đã có** (`EditProfileScreen`).
- **Mục đích**: sửa thông tin hồ sơ của mình.
- **Chuỗi (đã có)**: `editProfileTitle` "Chỉnh sửa hồ sơ", `displayNameLabel`, `editProfileSave` "Lưu", `editProfileSaved`, `editProfileError`. **Cần thêm**: `s42_phone` "Số điện thoại", `s42_allowZalo` "Cho phép liên hệ qua Zalo", `s42_allowWhatsApp` "Cho phép liên hệ qua WhatsApp", `s42_phoneHint` "Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.", `s42_changeAvatar` "Đổi ảnh đại diện".
- **Hành vi hiện tại**: sửa tên hiển thị, lưu có SnackBar thành công/lỗi.
- **Thay đổi cần làm**: thêm ô số điện thoại (`PhoneField`, ghi `users/{uid}/private/contact`) với hai công tắc cho phép Zalo/WhatsApp; đổi avatar; với NAG liên kết "Kỹ năng" (S38) và "Kênh liên hệ" (S34 phần công tắc). Ô số điện thoại để trống = giữ nguyên số đã lưu (không xoá số từ màn này). Đổi ảnh đại diện làm ở kế hoạch 2d.
- **Chấp nhận**: số hợp lệ mới lưu; số không bao giờ ghi vào `users/{uid}` (public); đổi avatar cập nhật nút kiểu avatar ngay.
