# Tài khoản, hồ sơ cá nhân, đánh giá, huy hiệu

Màn: S05.05, S01.03, S01.05, S09.01, S09.02, S03.02, S01.04, S09.03. Quy ước chung ở [README.md](README.md). S01.03, S01.05, S09.01, S09.02 và S01.04, S09.03 đã có trong code, mục này ghi hành vi hiện tại và thay đổi cần làm.

---

## S05.05 · Đánh giá và chia sẻ

- **Thông tin**: `/b/:id/review` · khách · sub‑project 6 · ✅ đã làm (4e); cà chua/gạch ✅ (#130).
- **Mục đích**: khép vòng: đánh giá và chia sẻ ảnh thành "Buổi chụp thật".
- **Điểm vào → ra**: push "Buổi chụp thế nào?" (sau `endTime` + 24 giờ hoặc khi NAG bấm "Đã giao ảnh"), S05.02, S05.01. Gửi xong → S05.02 (`reviewed`).
- **Bố cục**: Back + "Buổi chụp thế nào?"; `BookingCard` thu gọn; `VerdictPad` cà chua/gạch (chạm liên tục 1–10 hit, gạch kèm chip lý do; chi tiết spec `2026-10-06-tomato-brick-reviews-design.md` §5); ô nhận xét (nhãn "Nhận xét", bắt buộc, 10–1000 ký tự, gợi ý theo phe làm placeholder); section "Chia sẻ ảnh bạn thích" (tuỳ chọn, ≤ 10) với lưới ảnh chọn từ thư viện, có ở cả hai phe; nhắc "Ảnh hiện trong 'Buổi chụp thật' trên Trang chủ và hồ sơ {tên}, có tag nhiếp ảnh gia"; thanh dưới: chưa chọn ảnh thì một nút chính "Gửi đánh giá", có ảnh thì "Chỉ đánh giá" + "Gửi & chia sẻ {n} ảnh". Dòng gợi ý "Chạm tiếp để tăng mức độ, tối đa 10" chỉ hiện ở phe cà chua.
- **Dữ liệu**: callable `submitReview` ghi `reviews/{reviewId}` (`reviewId = reviewDocId(bookingId, 'photographer')` = `bookingId`; một đánh giá cho mỗi đối tượng trong một booking; có `subjectType`, `subjectId`, `serviceName`, `bookingDay`) và `bookings/{id}.reviewedAt` (không đổi `status`) và, nếu có ảnh, bài `posts` `kind=real_shoot` (`bookingId`, `serviceId`). Function `onReviewWrite` cập nhật `stats`, gửi thông báo qua `notifyReviewVerdict` và chấm huy hiệu. App không gửi `rating` hay `intensity`.
- **Trạng thái**: chưa chọn phe, gạch chưa có lý do hoặc nhận xét ngắn → nút vô hiệu, một dòng nhỏ nói thiếu gì; đang tải ảnh → tiến độ từng ảnh; booking chưa đủ điều kiện (`isReviewable`, hiện `completed`; plan bàn giao mở thêm `approved`) → chặn; đã đánh giá (`reviewedAt`) → chuyển sang xem lại, không sửa.
- **Chuỗi** (khoá thật trong `app_vi.arb`; file không có khoá `s12_*`): `reviewTitle` "Buổi chụp thế nào?", `reviewText` "Nhận xét", `reviewShare` "Chia sẻ ảnh bạn thích", `reviewOptional` "Tuỳ chọn", `reviewOnly` "Chỉ đánh giá", `reviewSubmit` "Gửi đánh giá", `reviewSubmitShare` "Gửi & chia sẻ {count} ảnh", `reviewTomato` "Hài lòng", `reviewBrick` "Chưa hài lòng", `reviewBrickShort` "Chưa ưng", `reviewHits` "×{n}", `reviewTomatoLevel1..4` ("Ổn", "Hài lòng", "Rất hài lòng", "Tuyệt vời!"), `reviewBrickLevel1..4` ("Hơi tiếc", "Chưa ưng", "Thất vọng", "Rất thất vọng"), `reviewReset` "Làm lại", `reviewTapMore` "Chạm tiếp để tăng mức độ, tối đa 10", `reviewPadLabel` "Đánh giá buổi chụp", `reviewA11yTomato` "Ném cà chua, {n} trên 10", `reviewA11yBrick` "Ném gạch, {n} trên 10", `reviewReasonsTitle` "Điều gì chưa ổn?", `reviewReasonsMin` "Chọn ít nhất 1", `reviewReasonLate` "Đến trễ", `reviewReasonNotAsPortfolio` "Ảnh không như mẫu", `reviewReasonSlowDelivery` "Giao ảnh chậm", `reviewReasonAttitude` "Thái độ", `reviewReasonPriceChanged` "Đổi giá", `reviewReasonOther` "Khác", `reviewTextHintTomato` "Điều bạn thích nhất ở buổi chụp", `reviewTextHintBrick` "Kể rõ điều chưa ổn để thợ cải thiện", `reviewNeedVerdict` "Chọn cà chua hoặc gạch", `reviewNeedReason` "Chọn ít nhất một lý do", `reviewTextTooShort` "Viết ít nhất 10 ký tự", `reviewShareHint`, `reviewNotYet`, `reviewAlreadyDone`, `reviewThanks`, `reviewUploadFailed`.
- **Phân tích**: `review_submit{verdict, hits, reasons, shared}` (chưa phát: app chưa có cổng phân tích).
- **Chấp nhận**: đánh giá lên hồ sơ thợ ảnh (tab Đánh giá, % cà chua); bài chia sẻ mang nhãn "Buổi chụp thật" và link tới gói; một booking chỉ một đánh giá cho mỗi đối tượng; toast huy hiệu nếu vừa đạt.

---

## S01.03 · Đăng nhập (đã có)

- **Thông tin**: `/login` · không cần đăng nhập · sub‑project 1 · **Đã có** (`LoginScreen`).
- **Mục đích**: đăng nhập bằng email, Google, Facebook.
- **Bố cục**: `AuroraBackground`, logo, `AuroraHero` ("Bắt trọn / mọi khoảnh khắc", tagline "Tìm thợ ảnh hợp gu, đặt lịch chỉ vài chạm."), `GlassCard` viền nổi bật (trung tính) chứa tiêu đề, ô email, ô mật khẩu (nút hiện/ẩn), nút chính "Đăng nhập", chia "hoặc", hai nút Google (trắng) và Facebook (xanh) cạnh nhau khi đủ rộng, xếp dọc khi hẹp; liên kết "Đăng ký".
- **Chuỗi (đã có)**: `loginHeadlineLead` "Bắt trọn", `loginHeadlineAccent` "mọi khoảnh khắc", `loginTagline`, `loginWelcome` "Chào bạn!", `loginWelcomeBody` "Đăng nhập để tiếp tục", `emailLabel`, `passwordLabel`, `loginButton` "Đăng nhập", `loginOrDivider` "hoặc", `socialGoogle`, `socialFacebook`, `noAccountPrompt` "Chưa có tài khoản?", `registerLink` "Đăng ký", `showPassword`/`hidePassword`.
- **Hành vi hiện tại**: kiểm tra email và mật khẩu; một nút chạy thì nút khác vô hiệu; lỗi hiện qua SnackBar theo `AuthError`.
- **Thay đổi cần làm**: dòng gradient của `AuroraHero` đã sửa để không cắt dấu tiếng Việt; thêm `ScreenCode`; cho phép trình quản lý mật khẩu và dán (đã có `autofillHints`).
- **Chấp nhận**: không cắt dấu ở ổ, ụ, ặ; nút chính theo kiểu nút đã chọn (mặc định gradient).

---

## S01.05 · Chọn vai trò (đã có)

- **Thông tin**: `/onboarding/role` · sau lần đăng nhập đầu · sub‑project 1 · **Đã có** (`RoleScreen`).
- **Mục đích**: chọn khách hay nhiếp ảnh gia, lưu vào `users`.
- **Chuỗi (đã có)**: `roleTitle` "Bạn muốn làm gì?", `roleCustomerTitle` "Thuê nhiếp ảnh gia" / `roleCustomerBody`, `rolePhotographerTitle` "Nhận chụp" / `rolePhotographerBody`, `roleContinue` "Tiếp tục", `signOut` "Đăng xuất", `roleSaveError`.
- **Hành vi hiện tại**: hai thẻ chọn đơn (có viền và nền tím khi chọn), nút "Tiếp tục" (loading), nút chữ "Đăng xuất"; lỗi lưu → SnackBar.
- **Thay đổi cần làm**: chọn "Nhiếp ảnh gia" thì sau khi lưu dẫn tới S08.01 (thiết lập hồ sơ) thay vì thẳng vào tab; thêm `ScreenCode`.
- **Chấp nhận**: chưa có vai trò thì mọi route khác chuyển về màn này.

---

## S09.01 · Hồ sơ cá nhân (đã có, làm lại thành danh sách bài đăng)

> **Đổi 2026-10-05**: dòng "Thông báo" dưới tên mở S17.01, số chưa đọc nằm trên tab Hồ sơ; thợ ảnh Cá nhân có dòng nhắc lên hạng NAG → S25.01 ([portfolio-awards.md](portfolio-awards.md)).

- **Thông tin**: `/profile` · cả hai · sub‑project 1 (bài đăng ở 3, đã lưu và đang theo dõi ở 3 và 6) · **Đã có** dạng cơ bản (`ProfileTab`), cần làm lại theo mock.
- **Mục đích**: xem các bài do chính mình đăng, dù đang ở chế độ khách hay nhiếp ảnh gia. Đổi chế độ và đăng xuất **không còn ở đây**, đã chuyển sang S09.02.
- **Bố cục** (theo mock): thanh tiêu đề "Hồ sơ" + bánh răng (→ S09.02); hàng avatar, tên, nhãn vai trò và khu vực; hàng số **bài đăng · đang theo dõi · đã lưu** (hai số sau mở danh sách khi sub‑project 3 và 6 xong, trước đó ẩn); hàng huy hiệu (`BadgeChip` ≤ 3 + "Xem tất cả" → S03.02); hàng `AppChip` lọc theo loại bài; lưới 3 cột ảnh bìa bài đăng.
- **Dữ liệu**: các `Post` có `authorId` = người dùng hiện tại, chưa xoá (`deletedAt` rỗng), mới nhất trước, phân trang theo con trỏ (20 bài/trang, cuộn tới cuối thì tải tiếp). Không lọc theo chế độ đang dùng: người vừa là khách vừa là nhiếp ảnh gia thấy mọi bài của mình.
- **Chip lọc**: "Tất cả" và một chip cho mỗi loại người dùng có ít nhất một bài, kèm số: **Tác phẩm** (`work`), **Buổi chụp** (`real_shoot`, chia sẻ từ S05.05), **Sự kiện** (`event_share`). Chỉ có một loại thì ẩn hàng chip. Ô lưới có nhãn nhỏ "Sự kiện" hoặc "Buổi chụp" khi đang ở "Tất cả"; bài `work` không nhãn.
- **Hành động**: chạm ô → S02.02 của bài đó. Không có nút chính trên màn này.
- **Chuỗi**: giữ `profileRoleCustomer`, `profileRolePhotographer`; thêm `profilePostsCount`, `profileFollowingCount`, `profileSavedCount`, `profileFilterAll`, `profileFilterWork`, `profileFilterRealShoot`, `profileFilterEventShare`, `profileEmptyPhotographerTitle` "Chưa có bài đăng", `profileEmptyPhotographerAction` "Đăng bài đầu tiên", `profileEmptyCustomerTitle` "Chưa có ảnh nào", `profileEmptyCustomerBody` "Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây". Các khoá `profileOffer*`, `profileSwitch*`, `signOut` chuyển sang dùng ở S09.02.
- **Trạng thái**: đang tải → lưới ô xương; trống → nhiếp ảnh gia thấy nút "Đăng bài đầu tiên" (→ S10.01), khách chỉ thấy dòng giải thích; lỗi tải → hàng "Thử lại" dưới lưới; avatar lỗi tải → biểu tượng người; offline → hiện bài đã có trong bộ nhớ đệm.
- **Chấp nhận**: chỉ hiện bài của chính người dùng; đổi chế độ ở S09.02 rồi quay lại vẫn thấy cùng danh sách; xoá một bài ở S02.02 thì bài biến khỏi lưới; số trên chip khớp số ô khi chọn chip đó.

---

## S09.02 · Cài đặt (đã có, thêm mục)

- **Thông tin**: `/settings` · cả hai · sub‑project 1 · **Đã có** (`SettingsScreen`).
- **Mục đích**: đổi thông tin tài khoản, **đổi chế độ khách ⇄ nhiếp ảnh gia**, giao diện, kiểu nút chính và **đăng xuất**.
- **Bố cục** (theo mock, từ trên xuống):
  - **Tài khoản**: Chỉnh sửa hồ sơ (→ S09.03), Số điện thoại (→ S04.05, hiện 4 số cuối hoặc "Chưa thêm"); nhiếp ảnh gia thêm "Kỹ năng" (→ S08.02, kèm `CompletenessMeter` nhỏ) và "Xem hồ sơ công khai" (→ S03.01 của chính mình). Staff thêm "Quản lý sự kiện" (→ S12.03).
  - **Chế độ**: thẻ đổi vai trò chuyển từ S09.01 sang, giữ nguyên chữ và hành vi: khách thấy **"Tôi là nhiếp ảnh gia"**, nút **"Chuyển qua chế độ nhiếp ảnh"**; nhiếp ảnh gia thấy **"Tôi cần đặt lịch"**, nút **"Chuyển qua chế độ đặt lịch"**. Nút là `AppButton.outline` (nút chính của màn là "Xem trước nút"), có loading và SnackBar `profileSwitchedTo*`. Chuyển sang nhiếp ảnh gia khi hồ sơ chưa xong → mở S08.01 thay vì đổi ngay. Đổi xong về S09.01 ở chế độ mới.
  - **Giao diện**: `SegmentedTabs` Tối / Sáng / Theo hệ thống (trước là ba hàng), lưu `themeMode`.
  - **Kiểu nút chính**: `SegmentedTabs` Gradient / Ảnh đại diện làm mờ (trước là hai hàng), khoá kèm lời nhắc khi chưa có avatar, lưu `buttonStyle`; nút xem trước.
  - **Đăng xuất**: nút chữ đỏ ở đáy. Chạm → sheet xác nhận "Đăng xuất khỏi thiết bị này?" với nút đỏ "Đăng xuất" và nút "Huỷ"; xác nhận → S01.03.
- **Thay đổi cần làm**: các mục trên; công tắc "Hiện mã màn hình" (chỉ khi `kDebugMode`); nhóm Quyền riêng tư (vị trí đã lưu, xoá khu vực), Thông báo (→ S17.02), Trợ giúp & điều khoản (sub‑project sau), đặt giữa Kiểu nút chính và Đăng xuất.
- **Chuỗi (đã có)**: `settingsTitle`, `settingsAccount`, `settingsEditProfile`, `settingsEditProfileBody`, `settingsAppearance`, `themeDark`/`themeLight`/`themeSystem`, `settingsButtonStyle`, `buttonStyleGradient`, `buttonStyleAvatar`, `buttonStyleAvatarNeedsPhoto`, `settingsButtonPreview`; chuyển từ S09.01: `profileOfferPhotographerTitle`/`Body`, `profileOfferCustomerTitle`/`Body`, `profileSwitchToPhotographer`, `profileSwitchToCustomer`, `profileSwitchedTo*`, `profileSwitchError`, `signOut`. **Thêm**: `settingsMode` "Chế độ", `settingsPhone`, `settingsPhoneEmpty` "Chưa thêm", `signOutConfirmTitle`, `signOutConfirmAction`, `cancel`.
- **Trạng thái**: offline → vô hiệu nút đổi chế độ; đang đổi chế độ → vô hiệu cả màn tới khi xong.
- **Chấp nhận**: đổi theme và kiểu nút có hiệu lực ngay, giữ sau khi mở lại app; nút xem trước đúng kiểu đã chọn; đổi chế độ không mất dữ liệu; đăng xuất chỉ sau khi xác nhận; thanh tab dưới cao 64dp.

---

## S03.02 · Huy hiệu

- **Thông tin**: `/u/:uid/badges` · cả hai · sub‑project 6 · **Đã có** (10a, `BadgesScreen`).
- **Mục đích**: ghi nhận người dùng qua huy hiệu từ đánh giá và từ hệ thống.
- **Điểm vào → ra**: hàng huy hiệu ở S03.01 và S09.01. Chạm một ô → sheet nhỏ nêu điều kiện và ngày đạt.
- **Bố cục**: Back + "Huy hiệu" + "5 / 12"; section "Từ đánh giá" (đếm đạt/tổng) và "Từ hệ thống"; lưới 2 cột `BadgeTile` (biểu tượng tròn tô `CtaSurface`, tên, điều kiện); huy hiệu chưa đạt (chỉ của chính mình) có biểu tượng xám và `CapacityBar` "3 / 5".
- **Dữ liệu**: `users/{uid}/badges` (đã đạt, công khai); `users/{uid}/private/badgeProgress` (tiến độ, chỉ chủ); danh mục `badges/{id}`.
- **Trạng thái**: người khác chỉ thấy huy hiệu đã đạt, ẩn tiến độ và các số đếm; chưa có huy hiệu → người khác thấy empty "Chưa có huy hiệu nào"; hồ sơ của mình chưa đạt cái nào thì hiện thẻ **"Gần đạt nhất: {tên} · {cur} / {target}"** (huy hiệu có `current/target` cao nhất) phía trên lưới, rồi toàn bộ huy hiệu chưa đạt kèm tiến độ; huy hiệu mới đạt (sau lần xem gần nhất, lưu cục bộ `badgesSeenAt:<uid>`) có chấm "Mới" suốt lần mở này và biến mất ở lần mở kế tiếp, không bao giờ hiện trên hồ sơ người khác. Huy hiệu `hiddenWhenLocked` (Thành viên mới) ẩn khi chưa có. Chạm một ô mở sheet: tên, điều kiện, "Đạt ngày {d/M/yyyy}" hoặc "{cur} / {target}".
- **Chuỗi**: `s37_title` "Huy hiệu", `s37_fromReviews` "Từ đánh giá", `s37_fromSystem` "Từ hệ thống", `s37_new` "Mới", `s37_progress` "{cur} / {target}".
- **Phân tích**: `badges_open{own}`, `badge_detail{badgeId}`.
- **Chấp nhận**: tiến độ khớp `badgeProgress`; client không ghi huy hiệu; tích xanh Verified không xuất hiện ở đây (khác khái niệm).

---

## S01.04 · Đăng ký (đã có)

- **Thông tin**: `/register` · không cần đăng nhập · sub‑project 1 · **Đã có** (`RegisterScreen`).
- **Mục đích**: tạo tài khoản bằng email và mật khẩu.
- **Chuỗi (đã có)**: `registerHeadlineLead` "Tham gia", `registerHeadlineAccent` "cộng đồng ảnh", `registerTagline`, `registerTitle` "Tạo tài khoản", `registerWelcomeBody`, `displayNameLabel`, `emailLabel`, `passwordLabel`, `passwordConfirmLabel`, `registerButton` "Đăng ký", `haveAccountPrompt` "Đã có tài khoản?", `loginButton`.
- **Hành vi hiện tại**: tạo tài khoản email, kiểm tra hợp lệ (`auth_form_validators`), lỗi theo `AuthError`.
- **Thay đổi cần làm**: thêm `ScreenCode`; sau đăng ký chuyển S01.05. Số điện thoại **không** hỏi ở đây (chỉ hỏi khi đặt lịch, S04.05).
- **Chấp nhận**: mật khẩu theo quy tắc hiện có; trình quản lý mật khẩu hoạt động.

---

## S09.03 · Sửa hồ sơ (đã có, thêm mục)

- **Thông tin**: `/settings/profile` · cả hai · sub‑project 1 · **Đã có** (`EditProfileScreen`).
- **Mục đích**: sửa thông tin hồ sơ của mình.
- **Chuỗi (đã có)**: `editProfileTitle` "Chỉnh sửa hồ sơ", `displayNameLabel`, `editProfileSave` "Lưu", `editProfileSaved`, `editProfileError`. **Cần thêm**: `s42_phone` "Số điện thoại", `s42_allowZalo` "Cho phép liên hệ qua Zalo", `s42_allowWhatsApp` "Cho phép liên hệ qua WhatsApp", `s42_phoneHint` "Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán.", `s42_changeAvatar` "Đổi ảnh đại diện".
- **Hành vi hiện tại**: sửa tên hiển thị, lưu có SnackBar thành công/lỗi.
- **Thay đổi cần làm**: thêm ô số điện thoại (`PhoneField`, ghi `users/{uid}/private/contact`) với hai công tắc cho phép Zalo/WhatsApp; đổi avatar; với NAG liên kết "Kỹ năng" (S08.02) và "Kênh liên hệ" (S08.05 phần công tắc). Ô số điện thoại để trống = giữ nguyên số đã lưu (không xoá số từ màn này). Đổi ảnh đại diện làm ở kế hoạch 2d.
- **Chấp nhận**: số hợp lệ mới lưu; số không bao giờ ghi vào `users/{uid}` (public); đổi avatar cập nhật nút kiểu avatar ngay.

---

## S17.01 · Thông báo

> **Đổi 2026-10-05**: không còn chuông ở đầu trang; mở từ dòng "Thông báo" ở S09.01 hoặc từ push; số chưa đọc là `TabBadge` của tab Hồ sơ (spec chính 3d.3, 3h.1).

- **Thông tin**: `/notifications` · cả hai · sub‑project N · **Đã có** (10a). Mock: S17.01 trong mục "Thông báo". Đặc tả chung: spec chính mục 3h.
- **Mục đích**: xem lại mọi thứ cần biết (lịch, báo giá, sự kiện, hệ thống) và đi thẳng tới việc cần làm.
- **Điểm vào → ra**: dòng "Thông báo" ở S09.01 và chạm vào push (không còn chuông; `NotificationBell` đã gỡ). Chạm một dòng → đánh dấu đã đọc + deep link `target`; app chỉ mở `target` khớp danh sách cho phép (`/b/:id` S05.02, `/b/:id/delivery`, `/chat/:id`, `/u/:uid`, `/u/:uid?tab=reviews`, `/u/:uid/badges` S03.02, `/me/awards` S25.01, `/bookings`, `/notifications`, `/e/:id` S11.02, `/events/:id/manage` S12.03, `/work/earnings`, `/work/earnings/account`, `/jobs/:id`, `/jobs/:id/applications` S15.03, `/instant/:id`, `/work/instant`, `/work/instant/:id`, `/work/instant/offer/:id`, `/studio/members`, `/me/studio`, `/verify/start`, `/verify/business`, `/disputes/:id`, `/help/chat`, `/me/payments`, `/recruit/:id`, `/collab`; chỉ `/studio/recruit?post=<id>` và `/collab?offer=<id>` được mang query, đúng một khoá, một lần), mọi đường dẫn khác hiện "Nội dung này không còn". Một dòng chỉ có `target` của màn chưa làm khi use case chủ của màn đó gọi hook, cùng lúc đăng ký route. `booking_request` → `/bookings` (S06.01); `review_tomato` / `review_brick` → `/u/{uid}?tab=reviews` (`review_new` cũ cùng đích). Bánh răng → S17.02.
- **Bố cục**: Back + "Thông báo" + bánh răng; hành động "Đánh dấu tất cả đã đọc"; `SegmentedTabs` (khách: Tất cả · Đặt lịch · Sự kiện · Hệ thống; NAG: Tất cả · Công việc · Sự kiện · Hệ thống); danh sách chia mục Hôm nay / 7 ngày qua / Trước đó bằng `SectionHeader`; mỗi dòng là `NotificationRow`. **Loại thông báo (#138)**: S17.01 hiển thị đủ danh mục ở mục 3h.2 của spec chính (booking, nhắc lịch, báo giá và việc đăng, Chụp ngay, sự kiện, đánh giá, bàn giao, studio và giao thợ, chi trả, xác minh, khiếu nại và hỗ trợ, tài khoản nhận hoàn, tuyển thợ và cộng tác viên, huy hiệu, giải thưởng, tin nhắn); mỗi loại một biểu tượng và tông (`notification_visuals.dart`), nội dung do server dựng. Dòng gom có nhiều người gửi vẽ chồng avatar (≤ 3) và nêu tên trong nội dung. Ví dụ nội dung: "Chụp phố đêm bắt đầu sau 2 ngày" / "Tập trung 19:00 tại Nhà hát Thành phố. Mang vé trong mục Vé."; "Đã hoàn 450.000₫" / "Tiền buổi chụp #A0C2 đã về tài khoản của bạn."; "Lan Chi không nhận được lịch" / "Đã hoàn 100% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.".
- **Dữ liệu**: `notificationsControllerProvider` (`AsyncNotifier`), nguồn `users/{uid}/notifications` qua `NotificationRepository` (cổng, không lộ kiểu Firebase). Lắng nghe 30 mục mới nhất **chỉ khi màn mở**; kéo xuống cuối tải thêm trang 30. `unreadCount` ở `users/{uid}/private/inbox` (riêng chủ). Client chỉ ghi `readAt`, gom lô (debounce ~1 giây hoặc khi rời màn); "tất cả đã đọc" gọi callable `markAllNotificationsRead`. Lọc theo mục là lọc theo trường `tab` lưu trên mỗi dòng (`activity` · `events` · `system`), không theo `type`.
- **Trạng thái**: loading = skeleton dòng thông báo; empty = biểu tượng chuông + "Chưa có thông báo nào" + một hành động ("Khám phá nhiếp ảnh gia" / "Mở Công việc"); empty theo mục lọc nêu rõ mục; lỗi = `ErrorState` + "Thử lại"; offline = dải "Đang xem dữ liệu đã lưu", nút đánh dấu bị vô hiệu; `target` không còn tồn tại (booking bị xoá) → SnackBar "Nội dung này không còn".
- **Tương tác**: chạm = đọc + đi; nhấn giữ = menu "Đánh dấu đã đọc / Tắt loại thông báo này" (thao tác thứ hai ghi `notification_prefs`, hiện SnackBar có "Hoàn tác"); không có thao tác chỉ vuốt; kéo để làm mới. Lời mời Chụp ngay không nằm ở đây (mở S14.02), chỉ có dòng "bỏ lỡ lời mời".
- **Chuỗi (ARB)**: `notificationTitle` "Thông báo", `notifSettingsTooltip` "Cài đặt thông báo", `notifMarkAllRead` "Đánh dấu tất cả đã đọc", `notifTabAll` "Tất cả", `notifTabBooking` "Đặt lịch", `notifTabWork` "Công việc", `notifTabEvents` "Sự kiện", `notifTabSystem` "Hệ thống", `notifSectionToday` "Hôm nay", `notifSectionWeek` "7 ngày qua", `notifSectionEarlier` "Trước đó", `notifUnreadHeader` "{n} chưa đọc", `notificationUnreadPrefix` "Chưa đọc", `notificationUnreadCount` "{count} thông báo chưa đọc", `notifRowSemantics` / `notifRowSemanticsRead`, `notificationMarkRead` "Đánh dấu đã đọc", `notificationMuteKind` "Tắt loại thông báo này", `notifMuted` "Đã tắt loại thông báo này", `notifUndo` "Hoàn tác", `notifEmptyTitle` "Chưa có thông báo nào", `notifEmptyBody`, `notifEmptyCtaCustomer` "Khám phá nhiếp ảnh gia", `notifEmptyCtaPhotographer` "Mở Công việc", `notifEmptyFiltered` "Chưa có thông báo nào trong mục {tab}", `notifEmptyFilteredBody`, `notifTargetGone` "Nội dung này không còn", `notifTimeNow` "Vừa xong", `notifTimeMinutes` "{n} phút", `notifTimeHours` "{n} giờ", `notifTimeYesterday` "Hôm qua", `notifTimeDays` "{n} ngày", `notifLoadMoreError`. Tiêu đề và nội dung của từng `type` (kể cả dòng gom báo giá "{n} nhiếp ảnh gia đã báo giá cho việc “{job}”") **không** nằm trong ARB: server dựng, nguồn duy nhất là bảng copy trong `packages/domain/src/notification_render.ts`.
- **Phân tích**: `notifications_open{unread}`, `notification_tap{type}`, `notification_mark_all`, `notification_mute_type{type}`, `notifications_filter{tab}`. Không ghi nội dung thông báo.
- **Chấp nhận**: chấm số trên tab Hồ sơ khớp `unreadCount` và được đọc là "{n} thông báo chưa đọc"; chưa đọc luôn có nhãn ngữ nghĩa ngoài chấm tím; dòng gom mở đúng S15.03; không có polling, chỉ một listener (30 mục) khi màn mở và hủy khi rời; đánh dấu đọc được gom lô; client không ghi trường nào khác `readAt`; ở 1,3× chữ không bị cắt (nội dung tối đa 2 dòng nhưng tiêu đề xuống dòng); hai theme.

---

## S17.02 · Cài đặt thông báo

- **Thông tin**: `/settings/notifications` · cả hai · sub‑project N · **Đã có** (10a).
- **Mục đích**: chọn loại thông báo nào được đẩy ra máy, loại nào chỉ hiện trong app, và giờ yên lặng.
- **Điểm vào → ra**: S09.02 Cài đặt → "Thông báo"; bánh răng ở S17.01. Back về màn trước; "Mở Cài đặt" mở cài đặt hệ điều hành.
- **Bố cục**: Back + "Thông báo"; banner khi quyền OS đang tắt ("Thông báo đang tắt trên máy" + "Mở Cài đặt"); bảng công tắc hai cột Push / Trong app cho: Đặt lịch và thanh toán, Việc đăng tuyển, Chụp ngay, Sự kiện, Tin nhắn, Huy hiệu và đánh giá, Khuyến mãi (tắt mặc định); mục Giờ yên lặng (công tắc + khoảng giờ mặc định 22:00–07:00, ghi chú giao dịch quan trọng vẫn có âm); mục Nhắc buổi chụp (24 giờ, 2 giờ). Các hàng **"Việc đăng tuyển" và "Chụp ngay" bị ẩn** (cờ tính năng) cho tới khi hai tính năng đó ra mắt, khác với mock; khi bật, "Chụp ngay" của khách chỉ có Push. Hàng Đặt lịch luôn giữ Trong app bật.
- **Dữ liệu**: `notificationPrefsProvider`, nguồn `users/{uid}/private/notification_prefs`; trạng thái quyền OS qua `NotificationPermissionPort`, kiểm tra lại khi app quay lại foreground. Ghi ngay khi gạt (lạc quan, hoàn lại khi lỗi).
- **Trạng thái**: loading = skeleton; quyền OS tắt → banner, cột Push vẫn chỉnh được nhưng có chữ "Đang tắt trên máy"; lỗi ghi → SnackBar + trả công tắc về cũ; offline → công tắc vô hiệu kèm lý do.
- **Tương tác**: công tắc Push/Trong app độc lập; tắt cả hai của một nhóm là tắt nhóm; giờ yên lặng chọn bằng `showTimePicker`; mỗi công tắc có `Semantics` "Đặt lịch và thanh toán, Push, bật". Dòng quan trọng (tập ở spec chính mục 3h.5) luôn vào hộp thư dù kênh tắt; hàng "Đặt lịch và thanh toán" giữ Trong app luôn bật.
- **Chuỗi (ARB)**: `notificationTitle` "Thông báo", `settingsNotificationsBody` "Push, giờ yên lặng, nhắc buổi chụp", `notifSettingsOsOffTitle` "Thông báo đang tắt trên máy", `notifSettingsOsOffBody`, `notifSettingsOpenSettings` "Mở Cài đặt", `notifSettingsColType` "Loại", `notifSettingsColPush` "Push", `notifSettingsColInApp` "Trong app", `notifSettingsPushOffOs` "Đang tắt trên máy", `notifSettingsCatBooking` "Đặt lịch và thanh toán", `notifSettingsCatJobs` "Việc đăng tuyển", `notifSettingsCatInstant` "Chụp ngay", `notifSettingsCatEvents` "Sự kiện", `notifSettingsCatChat` "Tin nhắn", `notifSettingsCatBadges` "Huy hiệu và đánh giá", `notifSettingsCatPromo` "Khuyến mãi", `notifSwitchOn` / `notifSwitchOff` / `notifSwitchLocked` ("{group}, {channel}, bật / tắt / luôn bật"), `notifSettingsQuietTitle` "Giờ yên lặng", `notifSettingsQuietLine` "{from}–{to} · chỉ thông báo quan trọng vẫn có âm", `notifSettingsQuietSwitchOn` / `notifSettingsQuietSwitchOff`, `notifSettingsPickFrom` "Yên lặng từ", `notifSettingsPickTo` "Yên lặng đến", `notifSettingsRemindersTitle` "Nhắc buổi chụp", `notifSettingsReminder24` "24 giờ", `notifSettingsReminder2` "2 giờ", `notifSettingsSaveError` "Không lưu được, thử lại". Thông báo "quan trọng" vẫn có âm là tập ở spec chính mục 3h.5 (các dòng "Quan trọng" của 3h.2), không liệt kê lại ở đây.
- **Phân tích**: `notification_pref_change{category, channel, enabled}`, `notification_quiet_hours_change{enabled}`, `notification_os_settings_open`.
- **Chấp nhận**: mặc định đúng (mọi nhóm bật, Khuyến mãi tắt, yên lặng 22:00–07:00, nhắc 24 giờ và 2 giờ bật); server tôn trọng prefs (nhóm tắt không tạo dòng/không gửi push); banner xuất hiện đúng khi OS tắt và biến mất sau khi bật rồi quay lại app; giờ yên lặng im push thường nhưng các thông báo quan trọng (mục 3h.5 của spec chính) vẫn có âm; không dùng màu làm tín hiệu duy nhất cho công tắc.

---

## S17.03 · Xin quyền thông báo (sheet)

- **Thông tin**: `/notifications/permission` (sheet) · cả hai · sub‑project N · **Đã có** (10a).
- **Mục đích**: giải thích lợi ích rồi xin quyền thông báo của hệ điều hành đúng lúc có lý do.
- **Điểm vào → ra**: chỉ hiện sau một hành động có ý nghĩa: khách sau khi đặt lịch, mua vé hoặc gửi yêu cầu Chụp ngay ("Bật thông báo để biết khi Minh Trí nhận lịch"); sau khi mua vé: hỏi **một lần** khi tab Vé sự kiện hiện vé vừa mua (`/bookings?tab=events&highlight={regId}`, cả vé miễn phí lẫn vé đã thanh toán), không hỏi khi mở tab bình thường, vé đã qua, vé đang giữ chỗ hay vé không có trong danh sách (mock `#S17.03-ticket`); thợ ảnh mua vé về tab công việc, không bị hỏi; NAG khi bật "Live Shutter" (S14.01) hoặc khi nhận booking đầu tiên. **Không bao giờ ở lúc mở app.** "Bật thông báo" → hộp thoại quyền OS → đóng sheet; "Để sau" → đóng, hỏi lại sau 7 ngày.
- **Bố cục**: `AppBottomSheet` trên nền S05.02‑like làm mờ (`BlurScrim`); biểu tượng chuông, tiêu đề theo ngữ cảnh, 2–3 dòng lợi ích (biết khi lịch được nhận, nhắc trước giờ chụp, tin nhắn mới), nút chính `AppButton.primary` "Bật thông báo", nút phụ "Để sau" (`AppButton.text`, không phải gradient). `PermissionPrimer`.
- **Dữ liệu**: `NotificationPermissionPort` (trạng thái, yêu cầu); cục bộ `SharedPreferences` `notifPrimerLaterAt`; token FCM đăng ký vào `devices/{uid}_{installId}` sau khi được cấp quyền.
- **Trạng thái**: đã được cấp quyền hoặc bị từ chối vĩnh viễn → không mở sheet (từ chối vĩnh viễn: để banner ở S17.02); đã bấm "Để sau" dưới 7 ngày → không mở; sau khi OS từ chối (không phải từ chối vĩnh viễn) cũng tạm hoãn 7 ngày như "Để sau" (`notifPrimerLaterAt`); đang chờ hộp thoại OS → nút chính ở trạng thái đang tải, cờ đang chờ lưu cục bộ và tự hết hạn sau 10 phút (app bị đóng giữa hộp thoại không khoá primer mãi).
- **Tương tác**: vuốt xuống/chạm ngoài = "Để sau"; sau khi OS trả kết quả hiện SnackBar "Đã bật thông báo" hoặc không hiện gì nếu từ chối; chỉ một sheet mỗi lần, không chồng lên sheet xác nhận khác.
- **Chuỗi (ARB)**: `primerTitleCustomerBooking` "Bật thông báo để biết khi {name} nhận lịch", `primerTitleCustomerTicket` "Bật thông báo để được nhắc trước khi {event} bắt đầu", `primerTitleCustomerInstant` "Bật thông báo để biết khi có người nhận chụp ngay", `primerTitlePhotographer` "Bật thông báo để không bỏ lỡ lời mời việc", `primerBenefit1` "Biết ngay khi lịch được nhận hoặc thay đổi", `primerBenefit2` "Nhắc trước giờ chụp, không lỡ hẹn", `primerBenefit3` "Tin nhắn mới khi app đang ở nền", `primerTicketBenefit1` "Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung", `primerEnableNotification` "Bật thông báo", `primerLater` "Để sau", `primerNote` "Chọn \"Để sau\", chúng tôi sẽ hỏi lại sau 7 ngày.", `primerEnabled` "Đã bật thông báo". Ngữ cảnh vé (`CustomerTicketPrimer`, analytics `customer_ticket`) dùng hai lợi ích: `primerTicketBenefit1` và `primerBenefit3`.
- **Phân tích**: `notification_primer_shown{context}`, `notification_primer_enable{context}`, `notification_primer_later{context}`, `notification_os_result{granted}`.
- **Chấp nhận**: không bao giờ xuất hiện trước hành động có ý nghĩa; "Để sau" không hỏi lại trước 7 ngày; nút chính là nút duy nhất dùng gradient; đóng bằng bàn phím/Back tương đương "Để sau"; token FCM chỉ đăng ký sau khi cấp quyền; hai theme.
