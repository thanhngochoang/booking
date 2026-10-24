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
- **Bố cục**: `AuroraBackground`, logo, `AuroraHero` ("Bắt trọn / mọi khoảnh khắc", tagline "Tìm thợ ảnh hợp gu, đặt lịch chỉ vài chạm."), `GlassCard` viền nổi bật (trung tính) chứa tiêu đề, ô email, ô mật khẩu (nút hiện/ẩn), nút chính "Đăng nhập", chia "hoặc", hai nút Google (trắng) và Facebook (xanh) cạnh nhau khi đủ rộng, xếp dọc khi hẹp; liên kết "Đăng ký". Khớp mock (#149).
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

- **Thông tin**: `/profile` · cả hai · sub‑project 1 (bài đăng ở 3, đã lưu và đang theo dõi ở 3 và 6) · **Đã có**, làm lại theo mock (#148): `ProfileTab` trong `lib/features/profile/profile_tab.dart`, lưới và số đếm ở `profile_posts_controller.dart`.
- **Mục đích**: xem các bài do chính mình đăng, dù đang ở chế độ khách hay nhiếp ảnh gia. Đổi chế độ và đăng xuất **không còn ở đây**, đã chuyển sang S09.02.
- **Bố cục** (theo mock): thanh tiêu đề "Hồ sơ" + bánh răng (→ S09.02); hàng avatar (`AppAvatarSize.lg`) bên trái, tên (font display) và vai trò bên phải (chỉ vai trò, không có khu vực: `LocationController.build` xin quyền và lấy GPS, nên không đọc khu vực đã lưu qua nó; đọc thẳng `SharedPreferences` là việc làm sau); dòng "Thông báo" (→ S17.01); hàng số **bài đăng · đang theo dõi · đã lưu** (hai số sau chỉ hiện khi S19 xong, trước đó ẩn; số bài đăng là tổng đếm bằng `count()` phía server, không đọc từng bài); hàng huy hiệu (`BadgeChip` ≤ 3 + "Xem tất cả" → S03.02); **chỉ nhiếp ảnh gia**: các lối vào việc của thợ nằm giữa hàng huy hiệu và hàng chip, theo thứ tự: thẻ "Hoàn thiện hồ sơ nhiếp ảnh gia" khi thiết lập chưa xong (→ S08.01), "Album của tôi" (→ S24.02), "Thu nhập" (→ S06.05), dòng nhắc "Có giải thưởng? Lên hạng Nhiếp ảnh gia" khi hồ sơ là Cá nhân (→ S25.01, ẩn sau "Để sau"); hàng `AppChip` lọc theo loại bài; lưới 3 cột ảnh bìa bài đăng.
- **Dữ liệu**: các `Post` có `authorId` = người dùng hiện tại, chưa xoá (`deletedAt` rỗng), mới nhất trước, phân trang theo con trỏ (20 bài/trang, cuộn tới cuối thì tải tiếp). Không lọc theo chế độ đang dùng: người vừa là khách vừa là nhiếp ảnh gia thấy mọi bài của mình. Bài `event_share` (không có `photographerId`, `serviceId`) vẫn hiện, kể cả khi còn chờ duyệt ở Dòng thời gian sự kiện: đó là bài của chính họ. Tab Hồ sơ được giữ trong ngăn tab nên quay lại tab không tự đọc lại; khi người dùng vừa tạo bài (đăng ở S10.01, chia sẻ ảnh sự kiện ở S11.05, đánh giá kèm ảnh ở S05.05) thì lưới và số đếm đọc lại từ đầu (`ownPostsChangedProvider`).
- **Chip lọc** (số đếm bằng `count()` phía server: một cho tất cả, một cho mỗi loại, lấy cùng lúc khi mở màn và sau khi kéo làm mới): "Tất cả" và một chip cho mỗi loại người dùng có ít nhất một bài, kèm số; chip đang chọn mà loại đó hết bài sau khi làm mới thì quay về "Tất cả": **Tác phẩm** (`work`), **Buổi chụp** (`real_shoot`, chia sẻ từ S05.05), **Sự kiện** (`event_share`). Chỉ có một loại thì ẩn hàng chip. Ô lưới có nhãn nhỏ "Sự kiện" hoặc "Buổi chụp" khi đang ở "Tất cả"; bài `work` không nhãn.
- **Hành động**: chạm ô → S02.02 của bài đó. Không có nút chính trên màn này (riêng trạng thái trống của nhiếp ảnh gia có "Đăng bài đầu tiên" → S10.01). Mẫu nhiếp ảnh gia: khung `#S09.01-photographer` trong mock.
- **Chuỗi**: giữ `profileRoleCustomer`, `profileRolePhotographer`; thêm `profilePostsCount` "bài đăng", `profileFollowingCount` "đang theo dõi", `profileSavedCount` "đã lưu", `profileFilterAll` "Tất cả · {n}", `profileFilterWork` "Tác phẩm · {n}", `profileFilterRealShoot` "Buổi chụp · {n}", `profileFilterEventShare` "Sự kiện · {n}", `profileTagRealShoot` "Buổi chụp", `profileTagEventShare` "Sự kiện", `profilePostsError` "Không tải được bài đăng.", `profilePostsMoreError` "Không tải thêm được. Thử lại", `profilePostTile` "Bài đăng {n}" (nhãn đọc của ô không có chú thích), `profileEmptyPhotographerTitle` "Chưa có bài đăng", `profileEmptyPhotographerAction` "Đăng bài đầu tiên", `profileEmptyCustomerTitle` "Chưa có ảnh nào", `profileEmptyCustomerBody` "Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây". Các khoá `profileOffer*`, `profileSwitch*`, `signOut` chuyển sang dùng ở S09.02. Không có `profileRoleWithArea` (tiêu đề chỉ hiện vai trò).
- **Trạng thái**: đang tải → lưới ô xương; trống → nhiếp ảnh gia thấy nút "Đăng bài đầu tiên" (→ S10.01), khách chỉ thấy dòng giải thích; lỗi tải lần đầu → `ErrorState` đầy đủ ("Không tải được bài đăng.") kèm "Thử lại"; tải trang kế tiếp lỗi → lưới giữ nguyên, hàng "Không tải thêm được. Thử lại" dưới lưới; kéo làm mới lỗi → lưới giữ nguyên và hiện SnackBar "Không tải được bài đăng."; avatar lỗi tải → biểu tượng người; offline → hiện bài đã có trong bộ nhớ đệm.
- **Chấp nhận**: chỉ hiện bài của chính người dùng; đổi chế độ ở S09.02 rồi quay lại vẫn thấy cùng danh sách; xoá một bài ở S02.02 thì bài biến khỏi lưới (chờ luồng xoá bài); số trên chip khớp số ô khi chọn chip đó.

---

## S09.02 · Cài đặt (đã có, thêm mục)

- **Thông tin**: `/settings` · cả hai · sub‑project 1 · **Đã có** (`SettingsScreen`).
- **Mục đích**: đổi thông tin tài khoản, **đổi chế độ khách ⇄ nhiếp ảnh gia**, giao diện, kiểu nút chính và **đăng xuất**.
- **Bố cục** (theo mock, từ trên xuống):
  - **Tài khoản**: Chỉnh sửa hồ sơ (→ S09.03), Số điện thoại (→ S04.05, hiện 4 số cuối hoặc "Chưa thêm"); nhiếp ảnh gia thêm, theo thứ tự (khung `#S09.02-photographer`): "Kỹ năng" (→ S08.02, kèm `CompletenessMeter` nhỏ), "Hình thức nhận việc", "Địa chỉ studio" (chỉ Studio, → S08.05 với `from=settings`, phụ đề là quận công khai hoặc "Chưa có địa chỉ"), "Giải thưởng" (→ S25.01), "Xác minh & nhận đơn" (→ S21.02), "Xác minh doanh nghiệp" (Studio, → S21.04), "Studio của tôi" (Cá nhân, → S26.03) hoặc "Thành viên studio" (Studio, → S26.01), "Cộng tác" (thợ) và "Tin tuyển" (studio) (S27), "Xem hồ sơ công khai" (→ S03.01 của chính mình), "Người đã chặn" (mọi người, → S20). Staff thêm "Quản lý sự kiện" (→ S12.03, chỉ staff; nhiếp ảnh gia quản lý sự kiện của mình ở Công việc → "Sự kiện của tôi"). Dòng nào có màn chưa làm (S21, S26 và các màn sau) thì ẩn cho tới khi màn đó có, không để link chết.
  - **Chế độ**: thẻ đổi vai trò chuyển từ S09.01 sang, giữ nguyên chữ và hành vi: khách thấy **"Tôi là nhiếp ảnh gia"**, nút **"Chuyển qua chế độ nhiếp ảnh"**; nhiếp ảnh gia thấy **"Tôi cần đặt lịch"**, nút **"Chuyển qua chế độ đặt lịch"**. Nút là `AppButton.outline` (nút chính của màn là "Xem trước nút"), có loading và SnackBar `profileSwitchedTo*`. Chuyển sang nhiếp ảnh gia: đặt vai trò trước (luật Firestore cần quyền nhiếp ảnh gia để ghi hồ sơ thợ), rồi về S09.01 ở chế độ mới, và nếu thiết lập chưa xong thì S08.01 mở chồng lên trên (Back về Hồ sơ), không chặn việc đổi. Mọi lần đổi khác xong thì về S09.01 ở chế độ mới. Khi đang đổi, cả màn bị vô hiệu.
  - **Giao diện**: `SegmentedTabs` Tối / Sáng / Theo hệ thống (trước là ba hàng), lưu `themeMode`.
  - **Kiểu nút chính**: `SegmentedTabs` Gradient / Ảnh đại diện làm mờ (trước là hai hàng; nhãn ngắn "Gradient", khoá `settingsButtonGradientShort`), phân đoạn "Ảnh đại diện làm mờ" bị vô hiệu (xám, không chạm được, đọc là "vô hiệu") kèm dòng nhắc `buttonStyleAvatarNeedsPhoto` dưới thanh khi chưa có avatar (`SegmentOption.enabled`), lưu `buttonStyle`; nút xem trước.
  - **Thông báo**: một dòng "Thông báo" ("Push, giờ yên lặng, nhắc buổi chụp", → S17.02), nhóm riêng nằm sau Kiểu nút chính. Sau đó là nhóm "Thanh toán và dữ liệu" (S22: "Lịch sử thanh toán" → `/me/payments` (#141, khoá `settings-payment-history`, phụ đề "Khoản đã trả, đang giữ, đang hoàn") rồi "Quyền riêng tư & dữ liệu" → `/settings/privacy` (#205)), nhóm "Hỗ trợ" (S18), nhóm gỡ lỗi (chỉ `kDebugMode`), rồi Đăng xuất; nhóm nào chưa có màn thì vắng mặt.
  - **Đăng xuất**: nút chữ đỏ ở đáy. Chạm → sheet xác nhận tiêu đề "Đăng xuất", nội dung "Bạn có chắc chắn muốn đăng xuất không?", nút đỏ "Đăng xuất" và nút "Ở lại"; xác nhận → S01.03.
- **Thay đổi cần làm**: các mục trên; công tắc "Hiện mã màn hình" (chỉ khi `kDebugMode`); các nhóm "Thanh toán và dữ liệu" (S22: lịch sử thanh toán, quyền riêng tư và dữ liệu gồm vị trí đã lưu, xoá khu vực) và "Hỗ trợ" (S18: trợ giúp, điều khoản) do các use case đó thêm vào đúng chỗ, sau Thông báo và trước nhóm gỡ lỗi và Đăng xuất.
- **Chuỗi (đã có)**: `settingsTitle`, `settingsAccount`, `settingsEditProfile`, `settingsEditProfileBody`, `settingsAppearance`, `themeDark`/`themeLight`/`themeSystem`, `settingsButtonStyle`, `buttonStyleGradient`, `buttonStyleAvatar`, `buttonStyleAvatarNeedsPhoto`, `settingsButtonPreview`; chuyển từ S09.01: `profileOfferPhotographerTitle`/`Body`, `profileOfferCustomerTitle`/`Body`, `profileSwitchToPhotographer`, `profileSwitchToCustomer`, `profileSwitchedTo*`, `profileSwitchError`, `signOut`. **Thêm**: `settingsMode` "Chế độ", `settingsButtonGradientShort` "Gradient", `settingsStudioAddress` "Địa chỉ studio", `settingsStudioAddressEmpty` "Chưa có địa chỉ", `settingsVerify` "Xác minh & nhận đơn", `settingsVerifyBody` "Xác minh danh tính để bắt đầu nhận đơn", `settingsMyStudio` "Studio của tôi", `settingsMyStudioBody` "Studio đang ở, việc được giao, lời mời", `settingsStudioMembers` "Thành viên studio", `settingsStudioMembersBody` "Mời thợ, giao việc cho thành viên", `settingsPhone`, `settingsPhoneEmpty` "Chưa thêm". Sheet đăng xuất dùng khoá có sẵn: `signOut` "Đăng xuất" (tiêu đề và nút đỏ), `settingsSignOutConfirmBody` "Bạn có chắc chắn muốn đăng xuất không?", `settingsSignOutKeep` "Ở lại".
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
- **Bố cục**: không có thanh tiêu đề; nút Đăng ký không có biểu tượng.
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

---

## S22.01 · Lịch sử thanh toán

- **Thông tin**: `/me/payments` (`PaymentHistoryScreen`, `ScreenCodes.paymentHistory`) · khách · sub‑project 6 · Đã làm ([#141](https://github.com/thanhngochoang/booking/issues/141)). Mock `#S22.01`.
- **Mục đích**: xem mọi khoản đã trả và đang giữ (kể cả Chụp ngay đang tìm thợ), hoàn tiền đang xử lý và đã xong; mỗi dòng mở chi tiết booking/vé/yêu cầu.
- **Điểm vào → ra**: Cài đặt (S09.02) → "Lịch sử thanh toán" (nhóm "Thanh toán và dữ liệu", dòng đầu); thông báo `refund_account_needed` (mục tiêu `/me/payments`). Back (mở thẳng thì về `/settings`). Ra: "Xem buổi chụp" → `push('/b/:id')`; "Xem vé" → `go('/bookings?tab=events&highlight={registrationId}')` (tab là shell); "Xem yêu cầu Chụp ngay" → `push('/instant/:id')`; "Chọn tài khoản nhận hoàn" mở sheet S22.04.
- **Bố cục** (theo mock, từ trên xuống):
  - AppBar "Lịch sử thanh toán".
  - `StatTileRow` hai ô "Đang giữ" · "Đang hoàn" (số rút gọn 2 chữ số thập phân; trình đọc màn hình đọc đủ số tiền).
  - Dòng giải thích `paymentsHeldNote`.
  - Danh sách `EarningRow` nhóm theo tháng của `createdAt` (thứ tự truy vấn, nên nhóm không bị tách): tiêu đề nhóm đầu "Các khoản" với tháng bên phải, các nhóm sau "Tháng N" (khác năm: "Tháng N/YYYY").
  - Mỗi dòng: tiêu đề do app ghép từ các phần máy chủ lưu (booking `payTitleBooking` "{thợ} · {gói}", chỉ một phần thì phần đó, thiếu cả hai thì "Thanh toán"; vé `payTitleTicket` "{tên sự kiện} · {n} vé"; Chụp ngay `payTitleInstant` "Chụp ngay · {khu}", không có khu thì "Chụp ngay"; phí S21 `verifyFeeTitle`; chủ thể lạ "Thanh toán"); dòng phụ: ngày chụp/sự kiện (`formatDay`, "T7 12/10"), không có thì ngày trả ("Hôm nay HH:mm" hoặc `formatDay`), rồi phương thức ("Chuyển khoản QR", "MoMo", "ZaloPay"), rồi "đang tìm thợ" / "đã huỷ"; số tiền rút gọn; nhãn trạng thái dạng pill chữ thường của mock (`.st`), không phải `StatusBadge`.
  - Nhãn theo mã: `held` "Đang giữ", `disputed` "Đang khiếu nại", `released` "Đã chuyển cho thợ" (booking, Chụp ngay) / "Đã chuyển cho chủ sự kiện" (vé) / "Đã thanh toán" (`toPlatform`, phí S21, chủ thể lạ), `refund_account_needed` "Cần tài khoản", `refunding` "Đang hoàn", `refunded` "Đã hoàn", `partially_refunded` "Đã hoàn một phần". Mã lạ (bản app cũ gặp mã mới): dòng chung tông trung tính, "Đang giữ" nếu `open`, ngược lại "Đã thanh toán"; chủ thể lạ: chỉ số tiền và ngày, không có liên kết.
  - Chạm dòng bung chi tiết (các dòng chi tiết của `EarningRow`): "Đã trả" `amount`; mỗi lệnh hoàn một dòng "Hoàn về {Vietcombank •••• 6789}" / "Hoàn về ví MoMo|ZaloPay" / "Hoàn tiền" (chưa có đích: chờ tài khoản) kèm " · đang xử lý" hoặc " · đã về"; "Sẽ nhận lại" `refundingAmount` (đậm) khi > 0; dưới cùng liên kết mở chủ thể (không có cho phí S21 và chủ thể lạ).
  - Dòng `refund_account_needed` của booking hoặc vé có nút viền nhỏ "Chọn tài khoản nhận hoàn" dưới dòng phụ (mở S22.04 với `BookingRefund(id)` / `TicketRefund(eventId, registrationId)`). Lệnh hoàn chờ của Chụp ngay và phí S21 đọc "Đang hoàn", không có nút (S22.04 không xử lý hai chủ thể này).
  - "Xem thêm" (viền nhỏ) khi số dòng ≥ giới hạn: tăng giới hạn thêm 20, giữ các dòng cũ trong lúc tải trang lớn hơn (không hiện loader).
  - Không có `AppButton.primary`.
- **Dữ liệu**: `paymentHistoryProvider(limit)` lắng nghe `users/{uid}/payments` (`orderBy createdAt desc`, `limit`, mặc định 20); `paymentTotalsProvider` lắng nghe `users/{uid}/private/paymentTotals` (thiếu = 0). Hai tài liệu do máy chủ ghi (trigger `onPaymentWritten`, `onRefundWritten`, đổi trạng thái/ngày/thợ của booking); chỉ chủ tài khoản đọc. Mọi số tiền là số máy chủ lưu, app không cộng trừ. Dòng không bao giờ có số tài khoản (chỉ "ngân hàng •••• 4 số cuối").
- **Trạng thái**: đang tải → `StatTile.skeleton` ×2 và `EarningRow.skeleton` ×4 (`AsyncView`); trống → `EmptyState` (`paymentsEmptyTitle`, `paymentsEmptyBody`); lỗi → `ErrorState` "Không tải được lịch sử thanh toán" kèm thử lại; cập nhật thời gian thực khi lệnh hoàn đổi trạng thái.
- **Chuỗi**: `paymentsTitle` "Lịch sử thanh toán", `paymentsHeld` "Đang giữ", `paymentsRefunding` "Đang hoàn", `paymentsHeldNote` "Tiền bạn trả được trung gian thanh toán giữ, chỉ chuyển cho thợ theo 2 mốc.", `paymentsItems` "Các khoản", `paymentsMore` "Xem thêm", `paymentsEmptyTitle` "Chưa có khoản thanh toán nào", `paymentsEmptyBody` "Khi bạn đặt lịch hay mua vé, các khoản sẽ hiện ở đây.", `paymentsLoadError` "Không tải được lịch sử thanh toán", `payStatusHeld`, `payStatusDisputed`, `payStatusReleasedBooking`, `payStatusReleasedTicket`, `payStatusReleasedPlatform`, `payStatusRefunding`, `payStatusNeedsAccount` "Cần tài khoản", `payStatusRefunded`, `payStatusPartlyRefunded`, `payMetaToday` "Hôm nay {time}", `payMetaSearching` "đang tìm thợ", `payMetaCancelled` "đã huỷ", `payTitleBooking` "{photographer} · {service}", `payTitleTicket` "{title} · {n} vé", `payTitleInstant` "Chụp ngay · {area}", `payDetailPaid` "Đã trả", `payDetailRefundTo` "Hoàn về {destination}", `payDetailRefund` "Hoàn tiền", `payDetailWallet` "ví {wallet}", `payDetailRefundPending` "đang xử lý", `payDetailRefundDone` "đã về", `payDetailWillGetBack` "Sẽ nhận lại", `payDetailOpenBooking` "Xem buổi chụp", `payDetailOpenTicket` "Xem vé", `payDetailOpenInstant` "Xem yêu cầu Chụp ngay", `payChooseRefundAccount` "Chọn tài khoản nhận hoàn"; dùng lại `payTitle`, `instantTitle`, `verifyFeeTitle`, `payMethodBankQr`/`Momo`/`ZaloPay`.
- **Chấp nhận**: không có chữ "cọc"; chuyển thừa/trễ hiện khoản đã trả kèm dòng "Đã hoàn"; QR hết hạn có tiền hoàn hiện "Đã hoàn"; huỷ 50% rồi thả hiện "Đã hoàn một phần" và không còn giữ; trạng thái đổi thời gian thực; "Xem thêm" giữ các dòng cũ; vừa 320dp ở chữ 1,3× (`test/features/payments/payment_history_screen_test.dart`).
- **Ghi chú (lệch mock, đã ghi ledger)**: nhãn trạng thái là pill chữ của mock, khác badge chữ in hoa của S06.05 (cùng lớp mock `.st`); ngày ở dòng phụ luôn theo `formatDay` (mock lẫn "28/9" và "03/09"); nhóm tháng theo ngày trả (`createdAt`), không theo ngày chụp.

---

## S22.02 · Xoá tài khoản

- **Thông tin**: `/settings/delete-account` · cả hai · sub‑project 6 · mới (kế hoạch S22, #205)
- **Mục đích**: kiểm tra điều kiện chặn và yêu cầu khoá/xoá tài khoản với thời hạn khôi phục 30 ngày.
- **Điểm vào → ra**: Quyền riêng tư & dữ liệu (S22.03) → "Xoá tài khoản".
- **Bố cục**: Back + "Xoá tài khoản"; khi có blocker: thẻ cảnh báo `warnc` "Chưa xoá được tài khoản" và danh sách từng điều kiện cần giải quyết kèm lối đi; khi không có blocker: danh sách 5 hậu quả khi xoá, gợi ý tải bản sao dữ liệu; nút viền "Xoá tài khoản" (bị mờ khi có blocker) mở sheet xác nhận S22.02-confirm với nút đỏ "Xoá tài khoản".
- **Dữ liệu**: `getAccountDeletionBlockers`, `requestAccountDeletion`.
- **Trạng thái**: chặn khi còn booking chưa xong, việc đã nhận, tin đăng, báo giá, yêu cầu Chụp ngay, quan hệ studio/cộng tác, vé chưa dùng, sự kiện tổ chức, khiếu nại, tiền đang giữ, tiền đang hoàn, tiền chờ chi trả.
- **Chuỗi**: `deleteAccountTitle`, `deleteBlockedTitle`, `deleteBlockedBody`, `deleteBlockBooking`, `deleteBlockJob`, `deleteBlockJobPost`, `deleteBlockJobPostBody`, `deleteBlockQuote`, `deleteBlockQuoteBody`, `deleteBlockInstant`, `deleteBlockStudio`, `deleteBlockStudioBody`, `deleteBlockCollab`, `deleteBlockCollabBody`, `deleteBlockTicket`, `deleteBlockEvent`, `deleteBlockDispute`, `deleteBlockHeld`, `deleteBlockHeldBody`, `deleteBlockRefund`, `deleteBlockRefundBody`, `deleteBlockEarnings`, `deleteBlockEarningsBody`, `deleteConsequencesTitle`, `deleteConsequence1`..`5`, `deleteExportHint`, `deleteExportHintLink`, `deleteAction`, `deleteConfirmTitle`, `deleteConfirmBody`, `deleteConfirmKeep`, `deleteAccountDone`, `deleteAccountFailed`.
- **Chấp nhận**: re-check blocker phía server; yêu cầu re-auth nếu đăng nhập quá 5 phút; xác nhận xong khoá tài khoản ngay và đăng xuất.

---

## S22.03 · Quyền riêng tư & dữ liệu

- **Thông tin**: `/settings/privacy` · cả hai · sub‑project 6 · mới (kế hoạch S22, #205)
- **Mục đích**: tuỳ chọn ẩn hồ sơ khỏi tìm kiếm/gợi ý (chỉ thợ), tải bản sao dữ liệu cá nhân, và lối vào xoá tài khoản.
- **Điểm vào → ra**: Cài đặt (S09.02) → "Quyền riêng tư & dữ liệu".
- **Bố cục**: Back + "Quyền riêng tư & dữ liệu"; mục "Hồ sơ" (chỉ thợ ảnh): công tắc ẩn hồ sơ; mục "Dữ liệu của bạn": tạo và tải bản sao JSON (lưu 7 ngày, cooldown 24h); nút chữ đỏ "Xoá tài khoản" ở đáy dẫn tới S22.02.
- **Dữ liệu**: `photographers/{uid}.hiddenFromDiscovery`, `requestDataExport`, `users/{uid}/private/dataExport`.
- **Trạng thái**: đang tạo bản sao → "Đang tạo bản sao…"; đã có bản sao → nút "Tải xuống" kèm hạn dùng.
- **Chuỗi**: `privacyTitle`, `privacyProfile`, `privacyHide`, `privacyHideBody`, `privacyData`, `privacyExport`, `privacyExportBody`, `privacyExportCreate`, `privacyExportCreating`, `privacyExportReady`, `privacyExportDownload`, `privacyExportCooldown`, `privacyExportLimit`, `privacyExportFailed`, `privacyDelete`.
- **Chấp nhận**: thợ ẩn hồ sơ vẫn nhận đặt lịch qua link cũ; tải dữ liệu giới hạn 1 lần / 24 giờ.

---

## S22.04 · Tài khoản nhận hoàn (sheet)

- **Thông tin**: sheet (`showRefundAccountSheet(context, ref, subject)`, `ScreenCodes.refundAccount`) · khách · sub‑project 6 · Đã làm ([#141](https://github.com/thanhngochoang/booking/issues/141)). Mock `#S22.04`, `#S22.04-other`, `#S05.02-refund`.
- **Mục đích**: khách xác nhận tài khoản nhận tiền hoàn của khoản trả bằng chuyển khoản QR: tài khoản đã chuyển, hoặc một tài khoản khác đã tra tên. Hoàn về ví không mở sheet này.
- **Điểm vào → ra**: `subject` là `BookingRefund(bookingId)`, `TicketRefund(eventId, registrationId)` hoặc `DisputeRefund(disputeId)`.
  - S05.03: sau toast huỷ thành công (khách huỷ có hoàn > 0, hoặc huỷ do lỗi studio), chỉ khi `booking.checkout?.method == bankQr`.
  - S05.02: thẻ "Bạn được hoàn {số tiền}" khi `booking.refundAccountNeeded` (chỉ khách) → "Chọn tài khoản nhận hoàn".
  - S11.04: sau khi huỷ vé có hoàn (`pct > 0`), mở từ state của tab (dòng vé đã huỷ có thể đổi chỗ); vé trả bằng ví thì máy chủ trả null và không mở gì.
  - S18.02: khách của khiếu nại đã có kết quả với `refundAmount > 0`, khi `pendingRefund({disputeId})` còn lệnh chờ → nút viền "Chọn tài khoản nhận hoàn".
  - S22.01: nút trên dòng `refund_account_needed` (booking, vé); thông báo `refund_account_needed` mở S22.01.
  - Sheet gọi `pendingRefund(subject)` trước: null → không mở; lỗi → SnackBar "Chưa mở được tài khoản nhận hoàn, thử lại sau.". Ra: chọn xong → đóng với toast "Đã gửi yêu cầu hoàn tiền"; nút đóng (biểu tượng, "Đóng") → đóng, không chọn gì.
- **Bố cục**:
  - Tiêu đề "Tài khoản nhận hoàn" + nút đóng; hàng "Bạn được hoàn" và số tiền (16sp, số đều).
  - **Có tài khoản người chuyển**: "Tiền hoàn về tài khoản đã chuyển:"; thẻ `BankBadge` + "Vietcombank •••• 6789", tên chủ tài khoản, dấu tích; `AppButton.primary` "Hoàn về tài khoản này"; nút chữ "Dùng tài khoản khác"; khi có `confirmBy`: "Không chọn thì sau 24 giờ tiền tự hoàn về tài khoản đã chuyển."; "Ví MoMo/ZaloPay: hoàn về ví, không cần chọn.".
  - **Tài khoản khác** (`#S22.04-other`; mở thẳng khi không có tài khoản người chuyển, kèm dòng "Chưa có thông tin tài khoản đã chuyển. Nhập tài khoản để nhận tiền hoàn." và không có lối quay lại): `BankField` "Ngân hàng" (→ `showBankPicker`); ô "Số tài khoản" (`AccountNumberFormatter`, số đều); nút viền nhỏ "Tra tên chủ tài khoản"; kết quả: thẻ tên chủ tài khoản + "Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ.", hoặc dòng đỏ (`not_found` → `refundAccountNotFound`, `not_eligible` → `refundAccountUnsupported`, `limit_exceeded` → `refundAccountLookupLimit`, khác → `refundAccountLookupError`); `AppButton.primary` "Hoàn về tài khoản này" chỉ bật sau khi tra thành công đúng ngân hàng và số đang nhập; "Số tài khoản được mã hoá, chỉ hiện 4 số cuối."; khi có tài khoản người chuyển, nút chữ "Hoàn về tài khoản đã chuyển" quay lại thẻ trên.
  - Một nút chính mỗi bước.
- **Dữ liệu**: `pendingRefund(subject)` → `PendingRefund {refundId, amount, payer?: {bankName, accountLast4, holderName}, confirmBy?}`; `lookupRefundAccount(refundId, bankCode, accountNumber)` → `{holderName, bankName, accountLast4}` (máy chủ lưu tài khoản mã hoá vào `Refund.candidate`); `chooseRefundAccount(refundId, use: payer | candidate, shown: {bankCode, accountLast4})` → `{status}`. Số tài khoản chỉ nằm trong ô nhập và trong lời gọi tra tên; sheet chỉ hiện ngân hàng, 4 số cuối và tên. Lỗi đọc từ `BookingException.code` (`not_found`, `not_eligible`, `limit_exceeded`, `conflict`, `network`).
- **Trạng thái**:
  - Đang tra tên: ô ngân hàng, ô số, phím gửi của bàn phím và nút tra đều khoá (đổi ngân hàng/số trong lúc tra không được); đổi ngân hàng hoặc số sau khi tra thì phải tra lại.
  - Tra quá 20 lần trong một ngày (mỗi lệnh hoàn, tính cả lần không tìm thấy): "Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.".
  - Chọn `candidate` gửi kèm ngân hàng và 4 số cuối của tài khoản đang hiện; máy chủ trả `conflict` khi `candidate` đã đổi (vẫn chờ) → tra lại, dòng "Tài khoản vừa thay đổi. Tra tên lại rồi xác nhận.", không gửi gì.
  - Lệnh hoàn đã rời trạng thái chờ (chọn sau khi mặc định 24 giờ đã gửi, `conflict`/`not_found`): sheet đọc lại `pendingRefund`, tìm lệnh hoàn trong 50 dòng mới nhất của S22.01 và đóng với "Tiền hoàn đã được gửi về {Vietcombank •••• 6789} trước khi bạn chọn."; chưa có dòng thì "Tiền hoàn đã được gửi đi trước khi bạn chọn. Xem nơi nhận ở Lịch sử thanh toán.". Không bao giờ báo tài khoản vừa chọn là nơi nhận khi máy chủ không xác nhận.
  - Chọn lỗi khác: sheet giữ nguyên, dòng đỏ "Chưa gửi được, thử lại sau.".
- **Chuỗi**: `refundAccountTitle` "Tài khoản nhận hoàn", `refundAccountYouGet` "Bạn được hoàn", `refundAccountToPayer` "Tiền hoàn về tài khoản đã chuyển:", `refundAccountConfirm` "Hoàn về tài khoản này", `refundAccountOther` "Dùng tài khoản khác", `refundAccountWalletNote`, `refundAccountAutoNote`, `refundAccountNoPayer`, `refundAccountBank` "Ngân hàng", `refundAccountNumber` "Số tài khoản", `refundAccountLookup` "Tra tên chủ tài khoản", `refundAccountLookupNote`, `refundAccountEncrypted`, `refundAccountNotFound`, `refundAccountUnsupported`, `refundAccountLookupLimit`, `refundAccountLookupError` "Không tra được tên. Thử lại.", `refundAccountLookupStale`, `refundAccountBackToPayer` "Hoàn về tài khoản đã chuyển", `refundAccountWentTo`, `refundAccountSent` "Đã gửi yêu cầu hoàn tiền", `refundAccountAlreadySent`, `refundAccountFailed`, `refundAccountLoadError`, `refundAccountClose` "Đóng"; S05.02: `detailRefundAccountTitle` "Bạn được hoàn {amount}", `detailRefundAccountBody` "Chọn tài khoản để nhận tiền hoàn.", `payChooseRefundAccount` "Chọn tài khoản nhận hoàn".
- **Quy tắc máy chủ** ([spec thanh toán §5](../2026-10-06-payments-payouts-design.md#5-hoàn-tiền)): hoàn theo chính sách của khoản `bank_qr` (huỷ, từ chối, hết hạn, huỷ vé/sự kiện, kết quả khiếu nại) chờ ở `awaiting_account`; có tài khoản người chuyển thì sau 24 giờ không chọn tự hoàn về đó (bước của `paymentClock`), không có thì chờ khách; chọn và mặc định chỉ gửi một lần. Chụp ngay và phí S21 không mở sheet (`not_eligible`).
- **Chấp nhận**: số tiền và "Vietcombank •••• 6789 · NGUYEN THANH HA" đúng như máy chủ trả; một lần gửi duy nhất khi khách chọn cùng lúc mặc định 24 giờ chạy; không lộ số tài khoản; vừa 320dp ở chữ 1,3× (`test/features/payments/refund_account_sheet_test.dart`).
- **Ghi chú (lệch mock, đã ghi ledger)**: mock tra tên tự động khi nhập đủ số (như S06.06); app có nút "Tra tên chủ tài khoản" riêng vì mỗi lần tra (kể cả không tìm thấy) tính vào hạn mức 20 lần mỗi lệnh hoàn mỗi ngày giờ Việt Nam, nên chỉ tra khi khách bấm; trong lúc tra app khoá ô nhập trong lúc tra để tài khoản được chọn luôn là tài khoản đang hiện. Mock không có dòng "Hoàn về tài khoản đã chuyển" trong form tài khoản khác.

---

## S22.05 · Khôi phục tài khoản

- **Thông tin**: `/account/restore` · cả hai · sub‑project 6 · mới (kế hoạch S22, #205)
- **Mục đích**: màn hình chặn router khi tài khoản đang ở trạng thái `deletion_pending` trong thời hạn 30 ngày.
- **Điểm vào → ra**: tự động chuyển hướng khi đăng nhập tài khoản đang chờ xoá.
- **Bố cục**: biểu tượng khôi phục, tiêu đề "Tài khoản đang chờ xoá", thông báo ngày xoá hẳn, thẻ tải bản sao dữ liệu (nếu còn hạn), nút chính "Khôi phục tài khoản", nút phụ "Tiếp tục xoá" (đăng xuất).
- **Dữ liệu**: `restoreAccount`, `users/{uid}.accountStatus`, `account_deletions/{uid}`.
- **Chuỗi**: `restoreAccountTitle`, `restoreAccountBody`, `restoreAccountAction`, `restoreAccountContinue`, `restoreAccountContinueNote`, `restoreAccountExport`, `restoreAccountDone`, `restoreAccountExpired`, `restoreAccountFailed`, `privacyExportPending`.
- **Chấp nhận**: chỉ người trong hạn 30 ngày mới khôi phục được; khôi phục xong tài khoản và dữ liệu trở lại bình thường.
