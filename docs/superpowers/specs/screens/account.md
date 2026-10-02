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

## S30 · Hồ sơ cá nhân (đã có, làm lại thành danh sách bài đăng)

- **Thông tin**: `/profile` · cả hai · sub‑project 1 (bài đăng ở 3, đã lưu và đang theo dõi ở 3 và 6) · **Đã có** dạng cơ bản (`ProfileTab`), cần làm lại theo mock.
- **Mục đích**: xem các bài do chính mình đăng, dù đang ở chế độ khách hay nhiếp ảnh gia. Đổi chế độ và đăng xuất **không còn ở đây**, đã chuyển sang S31.
- **Bố cục** (theo mock): thanh tiêu đề "Hồ sơ" + bánh răng (→ S31); hàng avatar, tên, nhãn vai trò và khu vực; hàng số **bài đăng · đang theo dõi · đã lưu** (hai số sau mở danh sách khi sub‑project 3 và 6 xong, trước đó ẩn); hàng huy hiệu (`BadgeChip` ≤ 3 + "Xem tất cả" → S37); hàng `AppChip` lọc theo loại bài; lưới 3 cột ảnh bìa bài đăng.
- **Dữ liệu**: các `Post` có `authorId` = người dùng hiện tại, chưa xoá (`deletedAt` rỗng), mới nhất trước, phân trang theo con trỏ (20 bài/trang, cuộn tới cuối thì tải tiếp). Không lọc theo chế độ đang dùng: người vừa là khách vừa là nhiếp ảnh gia thấy mọi bài của mình.
- **Chip lọc**: "Tất cả" và một chip cho mỗi loại người dùng có ít nhất một bài, kèm số: **Tác phẩm** (`work`), **Buổi chụp** (`real_shoot`, chia sẻ từ S12), **Sự kiện** (`event_share`). Chỉ có một loại thì ẩn hàng chip. Ô lưới có nhãn nhỏ "Sự kiện" hoặc "Buổi chụp" khi đang ở "Tất cả"; bài `work` không nhãn.
- **Hành động**: chạm ô → S02 của bài đó. Không có nút chính trên màn này.
- **Chuỗi**: giữ `profileRoleCustomer`, `profileRolePhotographer`; thêm `profilePostsCount`, `profileFollowingCount`, `profileSavedCount`, `profileFilterAll`, `profileFilterWork`, `profileFilterRealShoot`, `profileFilterEventShare`, `profileEmptyPhotographerTitle` "Chưa có bài đăng", `profileEmptyPhotographerAction` "Đăng bài đầu tiên", `profileEmptyCustomerTitle` "Chưa có ảnh nào", `profileEmptyCustomerBody` "Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây". Các khoá `profileOffer*`, `profileSwitch*`, `signOut` chuyển sang dùng ở S31.
- **Trạng thái**: đang tải → lưới ô xương; trống → nhiếp ảnh gia thấy nút "Đăng bài đầu tiên" (→ S21), khách chỉ thấy dòng giải thích; lỗi tải → hàng "Thử lại" dưới lưới; avatar lỗi tải → biểu tượng người; offline → hiện bài đã có trong bộ nhớ đệm.
- **Chấp nhận**: chỉ hiện bài của chính người dùng; đổi chế độ ở S31 rồi quay lại vẫn thấy cùng danh sách; xoá một bài ở S02 thì bài biến khỏi lưới; số trên chip khớp số ô khi chọn chip đó.

---

## S31 · Cài đặt (đã có, thêm mục)

- **Thông tin**: `/settings` · cả hai · sub‑project 1 · **Đã có** (`SettingsScreen`).
- **Mục đích**: đổi thông tin tài khoản, **đổi chế độ khách ⇄ nhiếp ảnh gia**, giao diện, kiểu nút chính và **đăng xuất**.
- **Bố cục** (theo mock, từ trên xuống):
  - **Tài khoản**: Chỉnh sửa hồ sơ (→ S42), Số điện thoại (→ S33, hiện 4 số cuối hoặc "Chưa thêm"); nhiếp ảnh gia thêm "Kỹ năng" (→ S38, kèm `CompletenessMeter` nhỏ) và "Xem hồ sơ công khai" (→ S03 của chính mình). Staff thêm "Quản lý sự kiện" (→ S27).
  - **Chế độ**: thẻ đổi vai trò chuyển từ S30 sang, giữ nguyên chữ và hành vi: khách thấy **"Tôi là nhiếp ảnh gia"**, nút **"Chuyển qua chế độ nhiếp ảnh"**; nhiếp ảnh gia thấy **"Tôi cần đặt lịch"**, nút **"Chuyển qua chế độ đặt lịch"**. Nút là `AppButton.outline` (nút chính của màn là "Xem trước nút"), có loading và SnackBar `profileSwitchedTo*`. Chuyển sang nhiếp ảnh gia khi hồ sơ chưa xong → mở S24 thay vì đổi ngay. Đổi xong về S30 ở chế độ mới.
  - **Giao diện**: `SegmentedTabs` Tối / Sáng / Theo hệ thống (trước là ba hàng), lưu `themeMode`.
  - **Kiểu nút chính**: `SegmentedTabs` Gradient / Ảnh đại diện làm mờ (trước là hai hàng), khoá kèm lời nhắc khi chưa có avatar, lưu `buttonStyle`; nút xem trước.
  - **Đăng xuất**: nút chữ đỏ ở đáy. Chạm → sheet xác nhận "Đăng xuất khỏi thiết bị này?" với nút đỏ "Đăng xuất" và nút "Huỷ"; xác nhận → S28.
- **Thay đổi cần làm**: các mục trên; công tắc "Hiện mã màn hình" (chỉ khi `kDebugMode`); nhóm Quyền riêng tư (vị trí đã lưu, xoá khu vực), Thông báo (→ S64), Trợ giúp & điều khoản (sub‑project sau), đặt giữa Kiểu nút chính và Đăng xuất.
- **Chuỗi (đã có)**: `settingsTitle`, `settingsAccount`, `settingsEditProfile`, `settingsEditProfileBody`, `settingsAppearance`, `themeDark`/`themeLight`/`themeSystem`, `settingsButtonStyle`, `buttonStyleGradient`, `buttonStyleAvatar`, `buttonStyleAvatarNeedsPhoto`, `settingsButtonPreview`; chuyển từ S30: `profileOfferPhotographerTitle`/`Body`, `profileOfferCustomerTitle`/`Body`, `profileSwitchToPhotographer`, `profileSwitchToCustomer`, `profileSwitchedTo*`, `profileSwitchError`, `signOut`. **Thêm**: `settingsMode` "Chế độ", `settingsPhone`, `settingsPhoneEmpty` "Chưa thêm", `signOutConfirmTitle`, `signOutConfirmAction`, `cancel`.
- **Trạng thái**: offline → vô hiệu nút đổi chế độ; đang đổi chế độ → vô hiệu cả màn tới khi xong.
- **Chấp nhận**: đổi theme và kiểu nút có hiệu lực ngay, giữ sau khi mở lại app; nút xem trước đúng kiểu đã chọn; đổi chế độ không mất dữ liệu; đăng xuất chỉ sau khi xác nhận; thanh tab dưới cao 64dp.

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

---

## S63 · Thông báo

- **Thông tin**: `/notifications` · cả hai · sub‑project N · Chưa có. Mock: S63 trong mục "Thông báo". Đặc tả chung: spec chính mục 3h.
- **Mục đích**: xem lại mọi thứ cần biết (lịch, báo giá, sự kiện, hệ thống) và đi thẳng tới việc cần làm.
- **Điểm vào → ra**: biểu tượng chuông ở S01, S13, S19 (`NotificationBell`) và chạm vào push. Chạm một dòng → đánh dấu đã đọc + deep link `target` (S09, S58, S16, S43, S37, S11…); bánh răng → S64.
- **Bố cục**: Back + "Thông báo" + bánh răng; hành động "Đánh dấu tất cả đã đọc"; `SegmentedTabs` (khách: Tất cả · Đặt lịch · Sự kiện · Hệ thống; NAG: Tất cả · Công việc · Sự kiện · Hệ thống); danh sách chia mục Hôm nay / 7 ngày qua / Trước đó bằng `SectionHeader`; mỗi dòng là `NotificationRow`.
- **Dữ liệu**: `notificationsControllerProvider` (`AsyncNotifier`), nguồn `users/{uid}/notifications` qua `NotificationRepository` (cổng, không lộ kiểu Firebase). Lắng nghe 30 mục mới nhất **chỉ khi màn mở**; kéo xuống cuối tải thêm trang 30. `unreadCount` ở `users/{uid}`. Client chỉ ghi `readAt`, gom lô (debounce ~1 giây hoặc khi rời màn); "tất cả đã đọc" gọi callable `markAllNotificationsRead`. Lọc theo mục là lọc theo `type` ở truy vấn.
- **Trạng thái**: loading = skeleton dòng thông báo; empty = biểu tượng chuông + "Chưa có thông báo nào" + một hành động ("Khám phá nhiếp ảnh gia" / "Mở Công việc"); empty theo mục lọc nêu rõ mục; lỗi = `ErrorState` + "Thử lại"; offline = dải "Đang xem dữ liệu đã lưu", nút đánh dấu bị vô hiệu; `target` không còn tồn tại (booking bị xoá) → SnackBar "Nội dung này không còn".
- **Tương tác**: chạm = đọc + đi; nhấn giữ = menu "Đánh dấu đã đọc / Tắt loại thông báo này" (thao tác thứ hai ghi `notification_prefs`, hiện SnackBar có "Hoàn tác"); không có thao tác chỉ vuốt; kéo để làm mới. Lời mời Chụp ngay không nằm ở đây (mở S53), chỉ có dòng "bỏ lỡ lời mời".
- **Chuỗi (ARB)**: `s63_title` "Thông báo", `s63_markAllRead` "Đánh dấu tất cả đã đọc", `s63_tabAll` "Tất cả", `s63_tabBooking` "Đặt lịch", `s63_tabWork` "Công việc", `s63_tabEvents` "Sự kiện", `s63_tabSystem` "Hệ thống", `s63_sectionToday` "Hôm nay", `s63_sectionWeek` "7 ngày qua", `s63_sectionEarlier` "Trước đó", `s63_unread` "Chưa đọc", `s63_unreadCount` "{count} thông báo chưa đọc", `s63_menuMarkRead` "Đánh dấu đã đọc", `s63_menuMuteType` "Tắt loại thông báo này", `s63_muted` "Đã tắt loại thông báo này", `s63_undo` "Hoàn tác", `s63_emptyTitle` "Chưa có thông báo nào", `s63_emptyBody`, `s63_emptyCtaCustomer` "Khám phá nhiếp ảnh gia", `s63_emptyCtaPhotographer` "Mở Công việc", `s63_targetGone` "Nội dung này không còn", `s63_groupQuotes` "{n} nhiếp ảnh gia đã báo giá cho việc “{job}”", `s63_timeMinutes` "{n} phút", `s63_timeHours` "{n} giờ", `s63_timeDays` "{n} ngày", và các tiêu đề/nội dung theo `type` (bảng mục 3h.2).
- **Phân tích**: `notifications_open{unread}`, `notification_tap{type}`, `notification_mark_all`, `notification_mute_type{type}`, `notifications_filter{tab}`. Không ghi nội dung thông báo.
- **Chấp nhận**: chấm số trên chuông khớp `unreadCount` và được đọc là "{n} thông báo chưa đọc"; chưa đọc luôn có nhãn ngữ nghĩa ngoài chấm tím; dòng gom mở đúng S58; không có polling, chỉ một listener (30 mục) khi màn mở và hủy khi rời; đánh dấu đọc được gom lô; client không ghi trường nào khác `readAt`; ở 1,3× chữ không bị cắt (nội dung tối đa 2 dòng nhưng tiêu đề xuống dòng); hai theme.

---

## S64 · Cài đặt thông báo

- **Thông tin**: `/settings/notifications` · cả hai · sub‑project N · Chưa có.
- **Mục đích**: chọn loại thông báo nào được đẩy ra máy, loại nào chỉ hiện trong app, và giờ yên lặng.
- **Điểm vào → ra**: S31 Cài đặt → "Thông báo"; bánh răng ở S63. Back về màn trước; "Mở Cài đặt" mở cài đặt hệ điều hành.
- **Bố cục**: Back + "Thông báo"; banner khi quyền OS đang tắt ("Thông báo đang tắt trên máy" + "Mở Cài đặt"); bảng công tắc hai cột Push / Trong app cho: Đặt lịch và thanh toán, Việc đăng tuyển, Chụp ngay, Sự kiện, Tin nhắn, Huy hiệu và đánh giá, Khuyến mãi (tắt mặc định); mục Giờ yên lặng (công tắc + khoảng giờ mặc định 22:00–07:00, ghi chú giao dịch quan trọng vẫn có âm); mục Nhắc buổi chụp (24 giờ, 2 giờ). Nhóm "Việc đăng tuyển" chỉ hiện khi tính năng Đăng việc bật; "Chụp ngay" của khách chỉ có Push.
- **Dữ liệu**: `notificationPrefsProvider`, nguồn `users/{uid}/private/notification_prefs`; trạng thái quyền OS qua `NotificationPermissionPort`, kiểm tra lại khi app quay lại foreground. Ghi ngay khi gạt (lạc quan, hoàn lại khi lỗi).
- **Trạng thái**: loading = skeleton; quyền OS tắt → banner, cột Push vẫn chỉnh được nhưng có chữ "Đang tắt trên máy"; lỗi ghi → SnackBar + trả công tắc về cũ; offline → công tắc vô hiệu kèm lý do.
- **Tương tác**: công tắc Push/Trong app độc lập; tắt cả hai của một nhóm là tắt nhóm; giờ yên lặng chọn bằng `showTimePicker`; mỗi công tắc có `Semantics` "Đặt lịch và thanh toán, Push, bật". Nhóm giao dịch quan trọng (thanh toán, huỷ lịch) không tắt hoàn toàn được ở cột Trong app.
- **Chuỗi (ARB)**: `s64_title` "Thông báo", `s64_osOffTitle` "Thông báo đang tắt trên máy", `s64_osOffAction` "Mở Cài đặt", `s64_colPush` "Push", `s64_colInApp` "Trong app", `s64_catBooking` "Đặt lịch và thanh toán", `s64_catJobs` "Việc đăng tuyển", `s64_catInstant` "Chụp ngay", `s64_catEvents` "Sự kiện", `s64_catChat` "Tin nhắn", `s64_catBadges` "Huy hiệu và đánh giá", `s64_catPromo` "Khuyến mãi", `s64_quietTitle` "Giờ yên lặng", `s64_quietRange` "{from}–{to}", `s64_quietNote` "Chỉ các thông báo quan trọng vẫn có âm: lời mời Chụp ngay khi bạn đang sẵn sàng, thanh toán, huỷ lịch.", `s64_remindersTitle` "Nhắc buổi chụp", `s64_reminder24` "Trước 24 giờ", `s64_reminder2` "Trước 2 giờ", `s64_saveError` "Không lưu được, thử lại".
- **Phân tích**: `notification_pref_change{category, channel, enabled}`, `notification_quiet_hours_change{enabled}`, `notification_os_settings_open`.
- **Chấp nhận**: mặc định đúng (mọi nhóm bật, Khuyến mãi tắt, yên lặng 22:00–07:00, nhắc 24 giờ và 2 giờ bật); server tôn trọng prefs (nhóm tắt không tạo dòng/không gửi push); banner xuất hiện đúng khi OS tắt và biến mất sau khi bật rồi quay lại app; giờ yên lặng im push thường nhưng vẫn phát lời mời Chụp ngay khi NAG đang sẵn sàng; không dùng màu làm tín hiệu duy nhất cho công tắc.

---

## S65 · Xin quyền thông báo (sheet)

- **Thông tin**: `/notifications/permission` (sheet) · cả hai · sub‑project N · Chưa có.
- **Mục đích**: giải thích lợi ích rồi xin quyền thông báo của hệ điều hành đúng lúc có lý do.
- **Điểm vào → ra**: chỉ hiện sau một hành động có ý nghĩa: khách sau khi đặt lịch, mua vé hoặc gửi yêu cầu Chụp ngay ("Bật thông báo để biết khi Minh Trí nhận lịch"); NAG khi bật "Sẵn sàng chụp ngay" (S52) hoặc khi nhận booking đầu tiên. **Không bao giờ ở lúc mở app.** "Bật thông báo" → hộp thoại quyền OS → đóng sheet; "Để sau" → đóng, hỏi lại sau 7 ngày.
- **Bố cục**: `AppBottomSheet` trên nền S09‑like làm mờ (`BlurScrim`); biểu tượng chuông, tiêu đề theo ngữ cảnh, 2–3 dòng lợi ích (biết khi lịch được nhận, nhắc trước giờ chụp, tin nhắn mới), nút chính `AppButton.primary` "Bật thông báo", nút phụ "Để sau" (`AppButton.text`, không phải gradient). `PermissionPrimer`.
- **Dữ liệu**: `NotificationPermissionPort` (trạng thái, yêu cầu); cục bộ `SharedPreferences` `notifPrimerLaterAt`; token FCM đăng ký vào `devices/{uid}_{installId}` sau khi được cấp quyền.
- **Trạng thái**: đã được cấp quyền hoặc bị từ chối vĩnh viễn → không mở sheet (từ chối vĩnh viễn: để banner ở S64); đã bấm "Để sau" dưới 7 ngày → không mở; đang chờ hộp thoại OS → nút chính ở trạng thái đang tải.
- **Tương tác**: vuốt xuống/chạm ngoài = "Để sau"; sau khi OS trả kết quả hiện SnackBar "Đã bật thông báo" hoặc không hiện gì nếu từ chối; chỉ một sheet mỗi lần, không chồng lên sheet xác nhận khác.
- **Chuỗi (ARB)**: `s65_titleCustomerBooking` "Bật thông báo để biết khi {name} nhận lịch", `s65_titleCustomerInstant` "Bật thông báo để biết khi có người nhận chụp ngay", `s65_titlePhotographer` "Bật thông báo để không bỏ lỡ lời mời việc", `s65_benefit1` "Biết ngay khi lịch được nhận hoặc thay đổi", `s65_benefit2` "Nhắc trước giờ chụp", `s65_benefit3` "Tin nhắn mới khi app ở nền", `s65_enable` "Bật thông báo", `s65_later` "Để sau", `s65_enabled` "Đã bật thông báo".
- **Phân tích**: `notification_primer_shown{context}`, `notification_primer_enable{context}`, `notification_primer_later{context}`, `notification_os_result{granted}`.
- **Chấp nhận**: không bao giờ xuất hiện trước hành động có ý nghĩa; "Để sau" không hỏi lại trước 7 ngày; nút chính là nút duy nhất dùng gradient; đóng bằng bàn phím/Back tương đương "Để sau"; token FCM chỉ đăng ký sau khi cấp quyền; hai theme.
