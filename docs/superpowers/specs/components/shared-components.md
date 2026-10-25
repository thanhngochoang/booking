# Đặc tả shared component

Widget dùng chung cho mọi màn của app Flutter `photobooking`. Bản vẽ trực quan của từng component: trang gallery `docs/design/ui-components.html` (bản publish https://claude.ai/artifact/GYAQ1D23L6csWana88TvbA; sinh bởi `scripts/tools/build_ui_components.py`; mock màn hình `ui-mock.html` chỉ giữ màn). Nằm trong `app_flutter/lib/core/widgets/` và xuất qua `core/core.dart` (features import `package:photobooking/core/core.dart`; file trong `core/` import trực tiếp nhau để barrel không có vòng). Màn dùng chúng ở [../screens/README.md](../screens/README.md). Mã `Sxx` là mã màn hình ở spec chính mục 2.

## Quy tắc chung

- **Theme**: lấy màu từ `ColorScheme`/`AppColors`, cỡ từ `AppSpace`/`AppRadius`/`AppText`; không dùng hex hoặc số tuỳ ý. Chạy đúng ở cả sáng/tối. Màu "bình thường" của nút chính đến từ `CtaSurface` (kiểu gradient hoặc avatar).
- **Hình khối**: nút/ô nhập radius 16; thẻ list radius 20; thẻ kính và sheet radius 28; ảnh nhỏ radius 8; chip và avatar tròn.
- **API**: tham số bắt buộc đặt trước, có `key`; hàm gọi lại dạng `VoidCallback`/`ValueChanged<T>`; không giữ state nghiệp vụ (chỉ state giao diện). Widget không đọc Riverpod, trừ khi ghi rõ.
- **Truy cập**: vùng chạm ≥ 48dp (viền nhìn thấy có thể nhỏ hơn, mở rộng vùng chạm bằng `InkResponse`/`Padding`); `Semantics` đầy đủ (nhãn, trạng thái chọn/mở); tiêu điểm bàn phím thấy rõ (vòng focus cyan ở tối, tím ở sáng); không truyền thông tin chỉ bằng màu; tôn trọng `MediaQuery.disableAnimations`.
- **Chữ**: `Text` có thể xuống dòng; nhãn một dòng (KPI, nhãn tab) dùng `FittedBox(scaleDown)`; chữ hệ thống tới 1,3× không tràn.
- **Test mỗi widget**: widget test (hiển thị, từng trạng thái, `Semantics`), golden sáng/tối ở 320dp và chữ 1,3×, và test không tràn (`tester.takeException` rỗng). Widget có animation: test bật/tắt và `disableAnimations`.
- **Tài liệu hoá**: mỗi widget có doc comment ngắn nêu việc nó làm và khi nào dùng.

Ký hiệu: **Đã có** (đã trong code), **Mới**.

---

## 1. Nền tảng và khung

### AuroraBackground · Đã có
Nền tối/sáng có một vầng tím nhạt và hai vầng trung tính; sáng giảm còn 50%. `AuroraBackground({Widget? child})`. Mọi màn bọc trong nó với `Scaffold(backgroundColor: transparent)`. Test: hiển thị `child` trên cả hai theme.

### GlassCard · Đã có
Thẻ kính mờ (blur 24, radius 28, bóng mềm). `GlassCard({required Widget child, bool highlight = true})`. `highlight: true` vẽ viền nổi bật (trung tính) (`HighlightBorder`); **chỉ một thẻ chính mỗi màn** dùng. Thẻ list dùng `highlight: false` (viền mảnh). Dùng ở S01.03, S06.01 (thẻ hôm nay), S09.02, S11.04 (thẻ vé).

### AuroraHero · Đã có
Tiêu đề hai dòng, dòng hai tô gradient; có đệm dọc quanh dòng gradient để không cắt dấu tiếng Việt (`height 1.2`). `AuroraHero({lead, accent, tagline})`. Dùng ở S01.03.

### AppLogo · Đã có
Logo khẩu độ. Dùng ở S01.03, S01.05, splash.

### TabShell và thanh tab dưới · Đã có (cập nhật)
Năm tab theo vai trò (`tabsFor(role)`). Thanh `NavigationBar` **cao 64dp** (mặc định Material 3 là 80dp) để nội dung có thêm chỗ; nhãn luôn hiện. Đĩa tab giữa 36dp tô `CtaSurface`. Mỗi icon bọc `TabBadge` lấy số từ `tabBadgesProvider`. Thanh có `SafeArea` dưới. Tuỳ chọn sau (chưa làm): tự ẩn khi cuộn xuống ở màn dài và hiện lại khi cuộn lên; nếu làm, tắt khi bật giảm chuyển động.

### ScreenCode · Mới
Nhãn mã màn ở góc trên trái, chỉ ở chế độ debug. `ScreenCode(String code, {String? label, required Widget child})`. `kDebugMode && showScreenCodesProvider` mới vẽ; ngược lại trả `child`. Nhãn: nền `#FF2D95`, chữ trắng, monospace 11, radius 6, `IgnorePointer`, nằm dưới status bar trong `SafeArea`. Hằng số mã ở `core/screen_codes.dart`. Test: hiện khi bật, ẩn khi tắt, không đổi kích thước `child`.

---

## 2. Nút, chip, điều khiển

### CtaSurface và CtaAvatarScope · Đã có
`CtaSurface({required Widget child, required BorderRadius borderRadius})` tô nền nút chính: gradient theo theme (tối đủ dải, sáng cùng tông tím `8338F5 → 702BDB`) hoặc, khi `CtaAvatarScope.avatar != null`, ảnh avatar nâng sáng 55–100%, blur σ12, nhân với gradient (`BlendMode.modulate`) đặt trên nền gradient dự phòng. `CtaAvatarScope(avatar: ImageProvider?, child)` đặt một lần trên `MaterialApp.builder`. `ctaGradientFor(Brightness)`. Dùng bởi `AppButton.primary` và đĩa tab giữa. Test: gradient 2/3 màu theo theme, có `ShaderMask`+`ImageFiltered` khi có avatar, gradient nằm dưới.

### AppButton · Đã có
`AppButton.primary / .outline / .text(label, {onPressed, loading, icon, style})`. Cao 52, radius 16. `primary` là nút chính duy nhất của màn (qua `CtaSurface`, bóng theo theme). `loading` khoá nút (không mờ) và thay nhãn bằng **vòng chấm bi xoay tròn** (`DotRingLoader`, xem dưới; sửa 2026-10-04, người dùng: lá khẩu `inline` trong nút rối và quá nhỏ): nhãn vẫn dựng với độ mờ 0 để giữ bề rộng và tên đọc; vòng nằm giữa nút, cao bằng lòng nút (đường kính 36/28/22, chấm 5/4/3 theo cỡ regular/small/xsmall), màu = màu chữ của nút (trắng trên gradient và nút danger); `Semantics` đọc nhãn kèm trạng thái bận; `onPressed: null` làm mờ 50%. Nút huỷ/từ chối không dùng `primary`.

**Chiều cao cố định**: nút chính luôn cao đúng `controlHeight` (52dp) ở mọi vị trí (thanh dưới, sheet, thẻ). Không đặt nút trong `Expanded`/`Flexible` theo trục dọc và không để nút co theo nội dung; trong `Column` của sheet bọc `SizedBox(height: controlHeight)` hoặc dùng `BottomActionBar`. Nút "thấp" (38dp) chỉ dùng trong hàng nút phụ của thẻ. Mọi `AppBottomSheet` và màn có thanh dưới (S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05, S08.04…) phải qua golden test kiểm chiều cao nút bằng nhau.

### AppChip (FilterChip) · Mới
`AppChip({required String label, required bool selected, required ValueChanged<bool> onChanged, AppChipKind kind = filter, Widget? leading, Widget? trailing, String? semanticsLabel, bool enabled = true})`. `kind: filter` đã chọn = nền primary đặc, chữ trên primary (bộ lọc: S02.06, S02.04; S11.01 lọc loại bằng hàng tag chữ `#workshop`, xem `screens/events.md`, chỉ chip “Không thu phí” dùng `AppChip`); `kind: context` đã chọn = nền `primarySubtle`, viền + chữ primary (danh mục ngữ cảnh/lựa chọn đơn: S02.01, S04.02, S12.01, S08.04). Cao 32 (vùng chạm 48), radius tròn, `Semantics(selected)`. Hàng chip dùng `Wrap` khi cần xuống dòng, cuộn ngang khi là bộ lọc. `trailing` (S27, #151): biểu tượng sau nhãn, cỡ 16 cùng màu chữ, cho chip mở bộ chọn ("Khu vực ▾" ở S27.01 với `AppIcons.expandMore`). `enabled: false` (S27, #151): lựa chọn chưa chọn được lúc này (thể loại thứ 5, khu vực thứ 6 ở S27.04) mờ 50% như `AppOptionTile`, không nhận chạm, trình đọc màn hình đọc là bị tắt; chip bật giữ nguyên nút ngữ nghĩa cũ.

### SegmentedTabs · Mới
`SegmentedTabs<T>({required List<SegmentOption<T>> options, required T value, required ValueChanged<T> onChanged})`. Nền ô nhập, ô chọn nền `primarySubtle` + viền primary; chia đều chiều ngang, cao 40; nhãn một dòng thu nhỏ khi hẹp. `Semantics` kiểu tab. Dùng ở S03.01 (4), S05.01 (3 + 2), S11.04, S06.01, S10.01, S09.02 (3 + 2).

### SkillChip · Mới
Chọn nhiều từ danh mục. `SkillChip({required String label, required bool selected, required VoidCallback onTap, bool disabled = false})`; thực chất `AppChip(kind: context)` với trạng thái vô hiệu khi đạt giới hạn (kèm `Semantics.hint` "Đã đủ số lượng"). `disabled` chỉ làm mờ chip chưa chọn và đọc "Đã đủ số lượng"; chạm vẫn báo lên để màn nêu giới hạn. Dùng ở S08.02, S08.03.

### LevelSelector · Mới
Chọn mức 3 nấc (Cơ bản · Thành thạo · Chuyên sâu) cho một thể loại. `LevelSelector({required String title, required int level, required ValueChanged<int> onChanged, bool expertDisabled = false})`. Bố cục một hàng: tiêu đề cố định rộng 74dp + `SegmentedTabs` nhỏ; `expertDisabled` làm mờ mức 3 và đọc "Đã đủ 3 mức Chuyên sâu". `Semantics`: "Chân dung, mức Chuyên sâu". Bàn phím: mũi tên trái/phải đổi mức. Vẽ ba ô riêng (cùng kiểu `SegmentedTabs`) vì `SegmentedTabs` không có ô bị làm mờ. Một điểm dừng Tab; trình đọc màn hình thấy một nút điều chỉnh được (tăng/giảm). Dùng ở S08.02.

### EvidencePicker · Mới
Lưới 3 cột chọn tối đa 3 ảnh. `EvidencePicker({required List<PostThumb> posts, required Set<String> selected, required ValueChanged<Set<String>> onChanged, int max = 3, VoidCallback? onMaxReached, VoidCallback? onEndReached})` (`PostThumb(id, imageUrl)`). Ô chọn có viền primary và dấu; vượt `max` phát âm báo và gọi `onMaxReached` (sheet S08.04 hiện dòng báo); lưới lười (`GridView.builder`), ảnh giải mã đúng cỡ ô qua `NetworkPhoto`; `onEndReached` khi cuộn gần cuối để tải trang sau. Dùng ở S08.04.

### PhoneField · Mới
Ô số điện thoại Việt Nam. `PhoneField({required TextEditingController controller, String? errorText, bool enabled = true, ValueChanged<String>? onChanged, FormFieldValidator<String>? validator, bool autofocus = false})`. Hai ô như mock: ô "Mã" cố định `+84` (72dp, chỉ đọc) và ô "Số điện thoại", `TextInputType.phone`, bộ lọc chữ số và định dạng `903 123 456`, chấp nhận dán `0903…` hoặc `+84…`. Hàm thuần `normalizePhone(String) → String?` (E.164 `+84…`), `validatePhone(String, AppLocalizations) → String?` (quy tắc `^(?:\+84|0)(3|5|7|8|9)\d{8}$`); tuỳ chọn quốc tế nằm ở `normalizePhone(…, international: true)` (nhận `^\+\d{8,15}$` cho số WhatsApp) và ô có `PhoneField(international: true, label: …)`: nhận `^\+\d{8,15}$` cho WhatsApp, số Việt Nam ở chế độ này vẫn được chuẩn hoá về `+84…`. Lỗi cụ thể dưới ô. Văn bản trong ô luôn ở dạng quốc nội `903 123 456`; dán `0903…` hoặc `+84…` được chuẩn hoá; gõ từng ký tự `+` không được coi là mã nước. Dán đúng 11 chữ số bắt đầu bằng `84` (không có `+`, dạng liên kết wa.me hoặc file xuất) thì bỏ `84` đầu: `84903123456` → `903 123 456`; chuỗi `84…` 9 chữ số giữ nguyên (số quốc nội 084). Đọc số bằng `phoneFromField`. Test bảng hợp lệ/không hợp lệ.

### OtpCodeField · Đã có (#134)
Ô nhập mã xác nhận 6 số (`lib/core/widgets/otp_code_field.dart`). `OtpCodeField({required TextEditingController controller, String? errorText, ValueChanged<String>? onCompleted, String? labelText, bool enabled = true, bool autofocus = true})`; hằng `otpCodeLength = 6`. Một ô (không phải sáu ô riêng): chỉ nhận chữ số, tối đa 6, bàn phím số, `AutofillHints.oneTimeCode` (tự điền mã từ SMS), tắt gợi ý và tự sửa, chữ căn giữa cỡ `titleLarge` giãn cách `AppSpace.s2` với chữ số đều (`tabularFigures`); nhãn luôn nổi (`labelText`, ví dụ `payoutOtpField` "Mã OTP"). `onCompleted` gọi khi chữ số thứ 6 được gõ hoặc dán; `errorText` hiện dưới ô (tối đa 3 dòng, ví dụ `payoutOtpWrong` "Mã chưa đúng. Kiểm tra lại tin nhắn"). Dùng ở sheet OTP của S06.06 (`showPayoutOtpSheet`); S21.01 (xác minh số điện thoại) dùng lại. Test: chỉ nhận chữ số và cắt ở 6, `onCompleted` ở chữ số thứ 6, lỗi hiện dưới ô, có gợi ý tự điền và bàn phím số, vừa khung 320dp với chữ 1,3×.

### ContactDial · Mới
Nút liên hệ gọn, bung kênh khi bấm. `ContactDial({required ContactAccess access, required List<ContactChannel> channels, required ValueChanged<ContactChannel> onSelected, ContactDialStyle style = icon, bool busy = false})`. `ContactAccess.locked` (chưa đặt): vẽ nút chat "Nhắn tin hỏi trước" và gọi `onSelected(ContactChannel.inApp)`, không bung. `ContactAccess.unlocked` (đã đặt/có vé): hành vi bung bên dưới. `ContactChannel` gồm `inApp` (chỉ dùng ở chế độ `locked`), `call`, `zalo`, `whatsapp` kèm `label`, `icon` (`IconData` hoặc `SvgPicture` từ `assets/social/zalo.svg`, `whatsapp.svg`), `enabled`. `style: icon` = nút vuông 48dp có biểu tượng điện thoại; `style: labeled` = nút thấp 38dp "Liên hệ" trong hàng nút.
- Bung: **một khay** nền `surface`, radius 28, bóng `elevation` của sheet, căn phải theo nút, phía trên nút (đổi xuống dưới nếu thiếu chỗ), `OverlayPortal` + `CompositedTransformFollower`. Khay chứa tối đa **ba** mục xếp ngang (`ContactChannel.call/zalo/whatsapp`): vòng tròn 44dp nền `surfaceMuted` viền mảnh, glyph 22dp đơn sắc `onSurface`, nhãn 10,5 bên dưới, rộng 62dp mỗi mục. Mở 240ms (khay dịch 10dp + phóng 0,92→1, mờ→rõ, đường cong ra nảy nhẹ), mục vào so le 40ms từ phải sang; đóng 140ms không so le; ngắt được. `inApp` không nằm trong khay (màn có nút "Nhắn tin" riêng).
- Một kênh: bấm nút gọi thẳng `onSelected`, không bung. Không có kênh ngoài: chỉ `inApp`.
- Đóng khi bấm ngoài, bấm lại nút, Back, Esc, hoặc chọn.
- Truy cập: `Semantics(button, label: 'Liên hệ', expanded)`; mở thì tiêu điểm vào mục đầu (Gọi), mũi tên/Tab di chuyển, Esc đóng và trả tiêu điểm; nhãn chữ luôn có.
- `HapticFeedback.selectionClick` khi mở; `disableAnimations` → hiện/ẩn tức thì.
- Widget **không** mở URL; màn gọi `ContactLauncher.open` trong `onSelected`.
- `busy`: đang lấy liên kết thì nút hiện vòng chờ và bỏ qua chạm. Sự kiện `contact_tapped{channel, source}` do `ContactAction` (lớp màn) ghi; widget không biết `source`. Khi mở khoá, `inApp` trong `channels` bị bỏ qua và không có kênh ngoài thì không vẽ gì.
- Test: bung/đóng, một kênh, giảm chuyển động, thứ tự tiêu điểm.

### QtyStepper · Mới
Bộ đếm trừ / số / cộng, đã tách khỏi `_Stepper` của sheet đăng ký vé (S11.03). `QtyStepper({required int value, required ValueChanged<int> onChanged, required String valueLabel, required String decrementLabel, required String incrementLabel, int min = 1, required int max, bool enabled = true, String keyPrefix = 'qty'})`. Nút trừ tắt khi `value <= min`, nút cộng tắt khi `value >= max`, cả hai tắt khi `enabled == false` (form đang khoá hoặc đang gửi); chạm gọi `onChanged(value ∓ 1)`, không bao giờ ra ngoài `[min, max]`.
- Khoá: `<keyPrefix>-minus`, `<keyPrefix>-quantity`, `<keyPrefix>-plus`. S11.03 truyền `keyPrefix: 'register'` nên test sự kiện giữ nguyên khoá `register-*`.
- Truy cập: số là vùng cập nhật trực tiếp (`liveRegion`) đọc bằng `valueLabel` ("2 vé", "2 người"), màn quyết định danh từ; nút có `tooltip` là `decrementLabel` / `incrementLabel`.
- Dùng ở S04.01 (số người, số ảnh của dịch vụ đi kèm) và S11.03 (số vé). Test: tắt ở min và max, chạm gọi `onChanged`, khoá theo `keyPrefix`, `valueLabel` được đọc.

### LocationPromptCard · Mới
Thẻ xin vị trí đúng lúc. `LocationPromptCard({required LocationPromptState state, required VoidCallback onAllow, required VoidCallback onLater, VoidCallback? onChooseArea})`. Trạng thái `ask` (biểu tượng ghim, "Sự kiện gần bạn", mô tả, nút "Cho phép" + "Để sau"), `requesting` (nút loading), `denied` (thu thành chip "Chọn khu vực"). Viền nổi bật (trung tính) chỉ khi `ask`. Dùng ở S02.03. Widget không gọi hộp thoại quyền; màn xử lý trong `onAllow`.

---

## 3. Thẻ và danh sách

### AppAvatar · Mới
`AppAvatar({String? url, required String name, AppAvatarSize size = md, Widget? badge})`. Kích thước xs 32 · sm 40 · md 48 · lg 64 · xl 96; viền 2dp màu nền khi đè lên ảnh; ảnh lỗi/trống → chữ cái đầu tên trên nền gradient nhẹ. Đã có `CircleAvatar` thô ở `ProfileTab`; thay bằng widget này.

### VerifiedMark · Mới
Dấu tích xanh Verified. `VerifiedMark({double size = 14})`: vòng tròn nền `ctaStart` (`3D63FF`), dấu ✓ trắng, không chữ, không viền. `Semantics(label: 'Đã xác minh')` + tooltip khi nhấn giữ. Đặt ngay sau tên và **nâng cao hơn tên một chút** (khoảng 3dp trên đường cơ sở, ngang chiều cao chữ hoa), cách tên 2dp; trong `Text.rich` dùng `WidgetSpan(alignment: PlaceholderAlignment.aboveBaseline)` kèm `Transform.translate(Offset(0, -2))`, trong `Row` bọc `Padding(bottom: 3)` hoặc `Align(alignment: Alignment.topCenter)` để không nằm giữa dòng. Chỉ cho `photographers.verified`. Dùng ở S02.02, S03.01, S02.06, S11.02, S12.03.

### BadgeChip · Đã có
Huy hiệu dạng chip. `BadgeChip({required BadgeView badge, VoidCallback? onTap})`. Biểu tượng tròn 16dp tô `CtaSurface` (hoặc vòng tròn xám khi chưa đạt) + tên, nền kính, viền mảnh; một dòng, rộng theo nội dung. Có biến thể `BadgeChip.skeleton()`. Hàng huy hiệu dùng `BadgeRow({required List<BadgeView> badges, int max = 3, VoidCallback? onSeeAll})` và `BadgeRow.skeleton({int count = 3})`: tối đa `max` chip (thường là 3) + "Tất cả" (`Wrap`, cuộn không cần). `Semantics(label: 'Huy hiệu {tên}')`. Khác `VerifiedMark` về màu (tím/gradient, không xanh dương). Dùng ở S03.01, S09.01, thẻ nhiếp ảnh gia (≤ 2).  
Lớp view-data: `BadgeView(code, name, condition, earned)`.

### BadgeTile · Đã có
Ô huy hiệu lớn. `BadgeTile({required BadgeView badge, BadgeProgress? progress, bool isNew = false, VoidCallback? onTap})`. Biểu tượng 36dp tô `CtaSurface` (đã đạt) hoặc xám (chưa đạt), tên (12 semibold), điều kiện (10,5), `CapacityBar` + "3 / 5" khi chưa đạt và là của mình; chấm "Mới" khi `isNew`. Có biến thể `BadgeTile.skeleton()`. Lưới 2 cột. Dùng ở S03.02.  
Lớp view-data: `BadgeView`, `BadgeProgress(current, total)`.

### StatusBadge · Đã có
Nhãn trạng thái booking (chữ hoa 10, radius 4, màu theo `BookingStatus`). Trạng thái vàng "Sắp tới" dùng chữ tối (`onColor`). Luôn kèm chữ. Dùng ở mọi `BookingCard`, timeline.

### PhotoCard · Mới
Ảnh nhiếp ảnh gia kèm lớp phủ. `PhotoCard({required String imageUrl, String? blurHash, required double aspect, String? title, String? subtitle, Widget? leadingPill, Widget? trailingPill, Widget? action, VoidCallback? onTap})`. Ảnh 4:5 hoặc 3:4, lớp phủ gradient đen chỉ ở đáy chứa chữ; pill trái = lịch rảnh ("Rảnh T7 này"), pill phải = gói + giá từ; không viền, không bóng. Ảnh dùng `cached_network_image` với blurhash và nút thử lại khi lỗi. Dùng ở S02.01, S02.03, S10.01, S03.01 (masonry).

### PhotographerCard · Mới
Thẻ so sánh. `PhotographerCard({required PhotographerSummary data, List<Reason> reasons = const [], required VoidCallback onProfile, VoidCallback? onBook, String? bookLabel})`. Ảnh hero 16:9 + pill rảnh; hàng avatar, tên + `VerifiedMark`, thể loại · khoảng cách · % cà chua ("Mới" khi < 5 đánh giá, spec 2026-10-06) · số buổi, giá từ (cột phải); `ReasonChips` (≤ 2); hàng nút "Hồ sơ" (viền, cỡ nhỏ 38dp) + "Đặt {ngày}" (primary gradient, cỡ nhỏ 38dp, theo mock; ngoại lệ của quy tắc một nút chính mỗi màn). Hộp cùng cấp bằng chiều cao. Dùng ở S02.01, S02.06.

### ReasonChips · Mới
Lý do gợi ý. `ReasonChips({required List<Reason> reasons, int max = 2})`. Chip nhỏ nền kính, chữ 10,5, một dòng; dư thì bỏ bớt, không cuộn. `Semantics` đọc "Gợi ý vì: …". Mã lý do `skill_match`, `near`, `free_on_date`, `top_rated`, `fast_reply`, `new_talent`.

### BookingCard · Đã có
`BookingCard({required BookingSummary data, BookingCardSize size = normal, Widget? actions, bool highlight = false, VoidCallback? onTap})`. Thumb 56–64 (radius 12), tên + gói, ngày giờ (`tabularFigures`), địa điểm, `StatusBadge` bên phải. `size: compact` cho thanh ngữ cảnh chat và S04.04; `highlight` dùng `GlassCard(highlight: true)` cho buổi hôm nay. `BookingSummary.tag` (String?, mặc định null) vẽ một viên thuốc viền nhỏ với `AppIcons.store` dưới dòng tên, ví dụ "Giao bởi Studio Ánh Dương" ở S06.01 (buổi studio giao); không có thì không vẽ gì. `BookingSummary.extraLine` (String?, mặc định null) thêm một dòng phụ dưới địa điểm ở cỡ `normal`, ví dụ "Điểm đón: Ga Sài Gòn, Quận 3" ở S04.03. Khe `actions` đặt hàng nút dưới thẻ (Chỉ đường, Nhắn tin, Nhận…). Dùng ở S04.03, S05.02, S07.01, S05.01, S06.01, S04.04.

### EventCard và DateBlock · Đã có
`EventCard({required EventCardData data, EventCardSize size = row, String? distanceLabel, VoidCallback? onTap})`. `size: row`: `DateBlock` bên trái, tên, "chủ · địa điểm", tag loại dạng chữ `#workshop` (màu primary, cỡ nhỏ, không nền/viền; cùng nhãn với hàng lọc S11.01), cột phải giá (hoặc `FreeTag` khi giá 0) + số chỗ ("Còn 3 chỗ" / "Hết chỗ" bằng chữ). `size: featured` (mock S11.01, 2026-10-07): ảnh bìa 16:10; `PhotoPill` sáng góc trên trái với chấm trạng thái (xanh còn nhiều chỗ, vàng từ một nửa, đỏ "Hết chỗ"); lớp phủ đáy ba dòng: "thứ dd/MM · HH:mm · địa điểm[ · khoảng cách]", tên đậm, "chủ · n/sức chứa đã đăng ký"; không có giá (giá nằm ở thẻ hàng). `EventTypeTag(label)`: tag loại dạng pill kính có viền (mock `.tag`), dùng ở S11.02 và `TicketCard`. `size: compact` (hàng ngang S02.03) rộng 176dp. Có biến thể `EventCard.skeleton({EventCardSize size = row})`.  
`DateBlock({required DateTime day, DateBlockSize size = regular, DateBlockFormat format = regular, VoidCallback? onTap})` ô nền `primarySubtle`, số ngày Fraunces, tháng "T10" chữ hoa; biến thể `DateBlock.skeleton()`. Dùng ở S02.03, S11.01, S12.02 (xem trước), S12.03, S02.04.  
Lớp view-data: `EventCardData(id, title, hostName, placeName, category, day, priceVnd, spotsLeft, coverUrl, distanceKm)` và hàm chuyển đổi `eventCardDataOf(Event e, AppLocalizations l)`.

### TicketCard · Đã có
`TicketCard({required TicketCardData ticket, VoidCallback? onCancel, VoidCallback? onDirections, VoidCallback? onAddToCalendar, VoidCallback? onOpenChat, VoidCallback? onPay, VoidCallback? onQrTap, …})`. `GlassCard(highlight)` cho vé sắp diễn ra (mock S11.04, 2026-10-07): `EventTypeTag` loại, tên, một dòng "thứ dd/MM · HH:mm · n vé", badge; hàng **mã QR** 112dp trên nền trắng (`qr_flutter`, mã hoá `ticketCode`, sửa lỗi mức M) bên trái, bên phải lời nhắc "Đưa mã này cho chủ sự kiện khi đến điểm hẹn." và mã vé chọn‑copy; hàng "Chỉ đường" (viền) + "Thêm vào lịch" (phụ, nền kính có viền); "Vào nhóm chat" (viền, nhỏ, cả chiều rộng) khi có `onOpenChat`; nút chữ đỏ "Huỷ vé · hoàn {x}%" **dưới thẻ**; vé đã qua mờ và không QR. Có biến thể `TicketCard.skeleton()`. `compact: true` là hàng gọn của mock S11.04 cho mọi vé trừ vé sắp diễn ra (chờ thanh toán, hết hạn, đã qua, đã huỷ, đã hoàn): `DateBlock`, tên, "n vé · địa điểm", badge; vé chờ thanh toán có nút nhỏ "Thanh toán tiếp" dưới chữ. `Semantics` của QR: "Mã vé {code}". `onReportProblem` (+ `reportProblemLabel`, mặc định "Báo vấn đề", #142): nút chữ đỏ nhỏ dưới hàng gọn (không mờ theo vé đã qua), chỉ khi vé có phí còn trong cửa sổ khiếu nại → S18.01. Dùng ở S11.04.

Lớp view-data: `TicketCardData(ticketCode, eventTitle, typeLabel, startsAt, quantity, state, placeName?)`, `TicketState` (upcoming | pendingPayment | past | attended | cancelled).

### StatusTimeline · Đã có
Dòng thời gian 7 bước của booking. `StatusTimeline({required List<TimelineStep> steps})`. Bước đã xong chấm xanh, bước hiện tại viền primary + quầng, bước tới chấm trống; đường nối dọc; mỗi bước có tên + dòng phụ (thời điểm, hướng dẫn). `Semantics`: "Bước 2 trong 7, đang diễn ra". Dùng ở S05.02.

### StatTile · Mới
Ô số liệu. `StatTile({required String value, required String label, VoidCallback? onTap})`. Có `onTap` thì ô là nút (`Semantics(button)`, `InkWell` theo radius ô, cao ≥ 48dp, đọc "giá trị, nhãn"); không có thì tĩnh. S06.01 "Đang giữ" mở S06.05. Số Fraunces 22 `tabularFigures` ở trên, nhãn 10,5 một dòng bên dưới (`FittedBox(scaleDown)`), nền trong mờ `surfaceMuted`, viền mảnh, không mờ nền (ô nằm trong thẻ đã mờ). Hàng ô dùng `IntrinsicHeight` + `Expanded` để cùng một hàng và cùng chiều cao. Dùng ở S03.01 (thống kê), S06.01, S12.03. Nhãn màu `foregroundSecondary` (≥ 4,5:1).

### FreeTag và FreeBanner · Mới
Dùng khi sự kiện có `price == 0`. `FreeTag()` là tag nhỏ nền xanh nhạt (`successSubtle` ở sáng, xanh 20% ở tối), chữ xanh đậm (≥ 4,5:1), nhãn “Không thu phí”, đặt ở chỗ giá của `EventCard` (thay “0₫”). `FreeBanner({String? body})` là dải đầy chiều rộng dưới ảnh bìa ở S11.02: biểu tượng tích + “Không thu phí” (đậm) + dòng phụ “Đăng ký để giữ chỗ, không cần thanh toán”. Không chỉ dựa vào màu (luôn có chữ). Dùng ở S02.03, S11.01, S11.02, S12.02 (xem trước), S02.04; S11.03 và S12.03 xử lý riêng (bỏ cổng, doanh thu “—”).

### HashtagChip · Mới
`HashtagChip({required String tag, int? count, VoidCallback? onTap})`. Viên thuốc `#Tag` (chữ primary trên nền `primarySubtle`, viền primary, Be Vietnam Pro 600) và "{n} bài" bên cạnh bằng chữ phụ; `tag` có hoặc không có `#` đều hiện đúng một `#`. Có `onTap` thì là nút cao ≥ 48dp (`Semantics(button)`), không có thì là nhãn tĩnh. Đọc "#Tag, {n} bài". Tag dài bị cắt bằng dấu chấm lửng một dòng. Dùng ở S11.05 (hashtag của sự kiện). Không có skeleton riêng (dùng hai khối `AppSkeleton`).  

### CapacityBar · Mới
`CapacityBar({required int used, required int total, String? label})`. Thanh gradient 6dp trên nền ô nhập; chữ "{used} / {total} đã đăng ký" luôn kèm; `Semantics(value)` theo chữ. Dùng ở S11.02, S12.03 và tiến độ huy hiệu (S03.02).

### CompletenessMeter · Mới
`CompletenessMeter({required int? percent, String? nextHint})`. Hàng tiêu đề + phần trăm, thanh gradient, dòng gợi ý việc kế tiếp. `percent` là số server ghi (`skills.completeness`); `null` (chưa tính) hiện "Chưa có điểm" và thanh rỗng. Dùng ở S08.02, S09.02, S06.02.

### AvailabilityCalendar · Mới
Lưới tháng 7 cột (T2…CN). `AvailabilityCalendar({required DateTime month, required Map<DateTime, DayState> states, DateTime? selected, Set<DateTime> selectedDays = const {}, ValueChanged<DateTime>? onSelect, ValueChanged<DateTime>? onLongPress, bool editable = false, ValueChanged<DateTime>? onMonthChanged, DateTime? minDate, DateTime? maxDate, DateTime? today, Set<DateTime> eventDays = const {}, DateTime? rangeStart, bool showHeader = true})`. `DayState`: `free` (mặc định), `pending` (viền đứt primary), `booked` (gạch ngang), `off` (nền mờ). Ngày chọn tô gradient; `pending/booked/off` không chọn được ở chế độ đặt (`editable: false`), `editable: true` cho NAG đổi `free ⇄ off`. Mỗi ô ≥ 44dp; ô có `Semantics` "12 tháng 10, rảnh". Điều hướng tháng bằng nút và vuốt; chọn dải: nhấn giữ ngày đầu (`onLongPress`, vòng `rangeStart`) rồi chạm ngày cuối. Giờ không nằm trong lưới. Chọn nhiều ngày: `selectedDays` tô gradient như `selected`, màn tự bật/tắt ngày trong `onSelect` (S29.04 "Chọn ngày"). Dùng ở S02.06 (chọn ngày), S04.02, S06.04, S03.01 (tab Lịch), S29.04. Ngày là ngày lịch (UTC 00:00, khoá `yyyy-MM-dd`). Ô cao 44dp, rộng bằng 1/7 hàng (≈ 41dp ở 320dp). Ô là hình chữ nhật bo góc theo mock (chọn = gradient, nghỉ = nền mờ, đã đặt = gạch ngang, chờ = viền đứt màu nhấn). `AvailabilityLegend` hiện bốn trạng thái kèm chữ, mỗi tên tô kiểu như trạng thái của nó. Đã có trong code (kế hoạch 2d1).

---

## 4. Sheet, tiến độ, trạng thái

### BlurScrim và ImageBackdrop · Mới
Hai lớp mờ ảnh của mục 1.2 spec chính.
- `BlurScrim({double sigma = 14, double dim = 0.35, Widget? child})`: phủ phía sau modal bằng `BackdropFilter(ImageFilter.blur)` rồi một lớp tối nhẹ (tối 35%, sáng 25% đen). `AppBottomSheet` và `showAppDialog` dùng nó thay cho `barrierColor` phẳng. Khi `highContrast` bật hoặc máy yếu (`isLowRamDevice`) → lớp tối đặc 55%, không mờ.
- `ImageBackdrop({required ImageProvider image, double height = 0.62, double sigma = 24, double opacity = 0.5, Widget? child})`: ảnh chủ đạo của màn, phóng 1,3×, mờ σ24, tăng bão hoà 130%, nhuộm `aurora`, tan dần xuống nền bằng mặt nạ gradient, nằm **sau** nội dung. Ảnh mờ được tạo một lần và lưu đệm (`RepaintBoundary`), không mờ lại mỗi khung hình; tải ảnh trễ thì hiện `AuroraBackground`. `ExcludeSemantics`. Dùng ở S03.01 (ảnh bìa), S11.02 (ảnh bìa sự kiện), S01.03 (ảnh nổi bật), về sau S02.02.
- Test: có/không có ảnh, `highContrast`, máy yếu; golden sáng/tối; chữ trên nền đạt ≥ 4,5:1.

### AppBottomSheet · Mới
`showAppSheet<T>(context, {required WidgetBuilder builder, bool confirmDismiss = false, String? confirmTitle})`. Mặt kính `surface` ~92% đục + blur 24, nền sau là `BlurScrim` (không phải lớp tối phẳng), radius 28 trên, thanh kéo, cao tối đa 88%, cuộn bên trong khi dài, nút chính cố định ở đáy kèm tổng tiền, `SafeArea`. `confirmDismiss: true` hỏi "Bỏ dữ liệu đã nhập?" khi vuốt xuống/chạm ngoài mà có thay đổi. Nền sau là `BlurScrim` (đo độ tương phản trên mặt sheet). Mở từ nút nguồn (trượt lên + mờ), Back đóng. Dùng ở S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05, S08.04.

### SignatureLoader (loading đặc trưng) · Đã có, thay ApertureLoader và AppSkeleton (quyết định 2026-10-02)
Hiệu ứng chờ đặc trưng của app, dùng cho **chờ cấp màn và chờ một bên khác** (khi không có hình khối biết trước; danh sách và thẻ dùng skeleton của component, xem AppSkeleton): lá khẩu của logo đóng mở ở giữa, quanh đó **một** loại sóng lăn ra, chọn bằng tham số (không bao giờ hiện cả hai cùng lúc):
- **Sóng tròn** (`LoaderWave.ripple`): 3 vòng đồng tâm nở từ 38% tới 100% kích thước rồi mờ dần, lệch nhịp 0,8 s, màu `primary`. Mặc định; dùng khi **tải dữ liệu** (mở màn, tải danh sách, tải lại).
- **Sóng rung** (`LoaderWave.vibration`): 2 vòng gợn hình sin, `r(θ) = R + a·sin(nθ)` (`n = 12, a = 2,4%` và `n = 9, a = 3,2%`), vừa nở ra vừa xoay qua lại ±4–6° như dây rung, màu cyan `focus` và hồng `#FF45D0`, lệch 1,2 s. Dùng khi **chờ một bên khác**: cổng thanh toán (S04.04), nhiếp ảnh gia trả lời (S13.03), chờ xác nhận.

Trang gallery component: `docs/design/ui-components.html` (cả hai loại sóng, ba cỡ).
- API: `SignatureLoader({LoaderSize size = LoaderSize.screen, LoaderWave wave = LoaderWave.ripple, bool active = true, String? semanticsLabel})`; `enum LoaderSize { screen /*150*/, block /*96*/, inline /*56, không sóng; hàng nhỏ*/ }`; `enum LoaderWave { ripple, vibration }`. `ApertureMark({double size, double closure, Color? color})` giữ nguyên là phần vẽ lá khẩu tĩnh.
- Lá khẩu: như cũ (logo đơn sắc `design-system/brand/logo-mono.svg`, 8 lá xoay quanh điểm neo trên vành, chu kỳ 2,4 s mở → khép, giữ khép 45–55%, `Curves.easeInOutCubic`). **Không nền màu** (sửa 2026-10-02, người dùng): không đĩa `CtaSurface`, không gradient, không bóng; lá khẩu và vòng viền mảnh **cùng màu với sóng** (sóng tròn: `primary`; sóng rung: cyan `focus`), trên nền trong suốt. Hình học hộp 100: vòng tròn bán kính 42; lá k, `t = k·45° − 90°`: điểm đầu = tâm + 10·hướng(t), điểm điều khiển = tâm + 33·hướng(t + 32°), điểm cuối = tâm + 42·hướng(t + 118°).
- Một `AnimationController` 2,4 s điều khiển lá khẩu và loại sóng đã chọn (một `CustomPainter`, `RepaintBoundary`, không blur). Chỉ chạy khi `active` và màn hiển thị (`TickerMode`); `active: false` dừng hẳn ticker.
- Sóng rung (chờ một bên khác) luôn đi kèm một dòng chữ nói đang chờ ai/cái gì và một lối thoát ("Kiểm tra lại", "Đổi cổng", "Huỷ"); không để màn chờ dài không giải thích (rà UX 2026-10-02).
- Giảm chuyển động (`MediaQuery.disableAnimations`): lá khẩu mở, một vòng tròn tĩnh mờ, không sóng; đọc `semanticsLabel` ("Đang tải", "Đang tìm", "Đang chờ thanh toán").
- Dùng (sửa 2026-10-04: trạng thái tải của `AsyncView` và nút đang gửi chuyển sang `DotRingLoader`): chờ cấp màn (splash, S04.04, S13.03, đăng bài, tạo sự kiện) dùng cỡ `screen`; khối/thẻ đang tải trong một màn đã có nội dung dùng `block`; hàng nhỏ dùng `inline`; nút đang gửi (`AppButton.loading`) dùng `DotRingLoader`. Danh sách và thẻ đang tải dùng skeleton của component (xem AppSkeleton); không dùng `CircularProgressIndicator` ở bất kỳ màn nào.
- Test: idle khi `active: false` và khi giảm chuyển động; đang chạy có đúng 1 ticker; mỗi loại sóng chỉ vẽ đúng loại của nó (ripple không có vòng gợn, vibration không có vòng tròn đều); golden 3 khung (đầu, giữa, cuối chu kỳ) ở sáng và tối cho hai loại sóng và ba cỡ; cỡ `inline` không vẽ sóng.

### DotRingLoader (vòng chấm bi) · Mới (quyết định 2026-10-04, người dùng)
Loader của `AsyncView` (khi không có skeleton) và của `AppButton.loading`. `DotRingLoader({LoaderSize size = LoaderSize.screen, Color? color, String? semanticsLabel})`: `screen` đường kính 96, chấm 11; `block` 64, chấm 8; `inline` 24, chấm 4 (tải lại ở góc); trong nút, AppButton tự đặt cỡ theo chiều cao nút (36/28/22).
- Hình: 12 chấm tròn trên một vòng, chấm k (0–11) lùi k·30° sau chấm đầu, cỡ ×(1 − 0,06k), độ mờ 1 − 0,075k (đuôi nhỏ và mờ dần). Cả vòng quay theo chiều kim đồng hồ, chu kỳ 2 s: một vòng trong 1,5 s đầu (`Curves.easeInOutCubic`), rồi đứng yên 0,5 s (sửa 2026-10-04, người dùng: quay đều 1,1 s nhanh quá, cần nghỉ sau mỗi lượt). Xoay tròn, không xoắn hay cuộn ngang.
- Màu: mặc định `primary` (accent); trong nút là màu chữ của nút. Không nền, không viền.
- Một `AnimationController` + một `CustomPainter` (`RepaintBoundary`); dừng khi màn ẩn (`TickerMode`). Giảm chuyển động: vòng đứng yên, giữ nguyên đuôi. Đọc `semanticsLabel` ("Đang tải").
- Test: giảm chuyển động không có ticker; golden ở ba cỡ, sáng và tối.

### AsyncView · Đã có (quyết định 2026-10-02)
Khung bắt buộc để màn hiển thị một `AsyncValue` (mọi fetch). `AsyncView<T>({required AsyncValue<T> value, required Widget Function(BuildContext, T) data, LoaderSize loaderSize = LoaderSize.screen, String? loadingLabel, bool Function(T)? isEmpty, Widget Function(BuildContext)? empty, VoidCallback? onRetry, Widget Function(BuildContext, Object)? error, Widget Function(BuildContext)? skeleton})`.
- Lần tải đầu: nếu có `skeleton` (`Widget Function(BuildContext)? skeleton`, thường là skeleton của component sẽ hiện), dựng nó; nếu không, `DotRingLoader(size: loaderSize)` căn giữa vùng của nó. Tải lại khi đã có dữ liệu (`isRefreshing`/`isReloading`): giữ dữ liệu cũ, thêm `DotRingLoader(size: inline)` nhỏ ở góc trên (không che nội dung, không làm nhảy bố cục).
- Không nền riêng (sửa 2026-10-02, người dùng; loader đổi 2026-10-04, người dùng: vòng chấm bi xoay tròn thay lá khẩu + sóng): AsyncView dùng `DotRingLoader` cho trạng thái tải khi không có skeleton; vùng loader đúng bằng vòng chấm (96 hoặc 64, theo `loaderSize`), căn giữa, không bọc thêm hộp, thẻ, viền hay gradient. Lỗi và rỗng cũng nằm thẳng trên nền màn.
- Không nháy (rà UX 2026-10-02): lần tải đầu chờ 150 ms mới hiện skeleton/loader (dữ liệu từ cache về nhanh hơn thì hiện thẳng dữ liệu, vùng giữ nguyên kích thước); đã hiện thì giữ tối thiểu 400 ms rồi mới đổi sang dữ liệu, để không chớp.
- Lỗi: `ErrorState(message: errorMessage(e, l10n), onRetry: onRetry)`; có dữ liệu cũ thì giữ dữ liệu và hiện SnackBar lỗi một lần.
- Rỗng (`isEmpty` trả true): `empty` (thường là `EmptyState` có một hành động nuôi vòng lặp).
- Lint của repo (test kiểm mã nguồn `lib/features/**`): không có `CircularProgressIndicator` hay `.when(loading:` tự viết; màn dùng `AsyncView` (skeleton của component hoặc `DotRingLoader`).
- Test: bốn trạng thái; tải lại giữ dữ liệu; lỗi có dữ liệu cũ hiện SnackBar; `loaderSize` truyền đúng.

### StepProgress · Mới
`StepProgress({required int current, required int total, String? label, bool showCount = true})`. Thanh `total` đoạn, các đoạn tới `current` tô gradient; chữ "n / N" bên cạnh; `Semantics(value: 'Bước n trên N')`. Dùng ở S04.01–S04.03, S08.01, S12.01, S12.02, S08.05, S08.02. Theo mock (thành phần "Bước nhiều trang"), màn nhiều bước đặt "n / N" ở góc phải thanh tiêu đề và thanh tiến độ ngay dưới thanh tiêu đề, ngoài vùng cuộn: khi đó dùng `showCount: false` (S08.05).

### AppOptionTile · Mới
`AppOptionTile({required String label, required bool selected, required VoidCallback onTap, Widget? leading, IconData? icon, String? description, List<MetaPart>? meta, bool enabled = true})`. Một lựa chọn trong danh sách chọn một (mock `.opt`): viền 1px `outline`, radius 16, nền kính không blur (dùng được trong danh sách dài), radio 18dp viền 2px; đã chọn = viền + chấm radio primary, nền `primarySubtle`. Cao ≥ 48dp; `Semantics(checked, inMutuallyExclusiveGroup, selected)`. `icon` (mock `.opt .oi`): ô 40dp bo góc bên trái chứa biểu tượng (nền field; đã chọn thì nền primary, biểu tượng onPrimary) và radio chuyển sang bên phải; không dùng cùng `leading`. `meta` thay `description` bằng một `MetaLine` (dòng có cà chua, S26.04 "Rảnh · 🍅 97%"); `enabled: false` (mock `.opt.dis`): mờ 50%, không nhận chạm, đọc là bị tắt, dòng thứ hai nói lý do. Dùng ở S02.05 và S02.06 (các sheet dịch vụ, giá, đánh giá), `icon` ở S08.01 (Hình thức) và sheet chọn hình thức trong Cài đặt; sau này S04.02, S13.01.

### AppFooterBar · Mới
`AppFooterBar({required Widget child})`. Hàng nút dính đáy của màn biểu mẫu (mock `.foot`): nền `surface`, viền mảnh phía trên, đệm 10/16/12, có `SafeArea` dưới; đặt ngoài vùng cuộn. Màn nhiều bước: "Quay lại" `outline` rộng 36% + nút chính. Dùng ở S08.05, S09.03.

### SectionHeader · Đã có
`SectionHeader({required String title, String? actionLabel, VoidCallback? onAction, String? trailing})`. Tiêu đề Fraunces 17 + hành động chữ primary 12 bên phải (≥ 48dp vùng chạm). `Semantics(header)`. Dùng khắp nơi cho "Xem tất cả", "Tất cả".

### EmptyState · Đã có
Minh hoạ tròn, tiêu đề, mô tả (`body`, tuỳ chọn), dòng ghi chú nhỏ dưới mô tả (`note`, tuỳ chọn, ví dụ "Staff duyệt trong 24 giờ sau khi bạn gửi" ở S06.02), một nút `AppButton.primary` (tuỳ chọn). Mọi trạng thái trống có đúng một hành động nuôi vòng lặp (xem S06.02, S02.03…).

### ErrorState và OfflineBanner · Đã có
`ErrorState({required String message, VoidCallback? onRetry})` tiêu đề ngắn + "Thử lại". `OfflineBanner()` dải mảnh "Đang xem dữ liệu đã lưu" trên đầu danh sách khi offline. Thông điệp lấy từ ánh xạ mã lỗi → tiếng Việt (`errorMessage(Object, AppLocalizations)`). Dùng ở mọi màn có dữ liệu mạng.

### AppSkeleton và skeleton của từng component · Đã có (quyết định 2026-10-02)
Mỗi component hiển thị dữ liệu có **biến thể skeleton riêng** đúng hình khối của nó: `PhotoCard.skeleton()`, `PhotographerCard.skeleton()`, `BookingCard.skeleton({BookingCardSize size})`, `EventCard.skeleton()`, `TicketCard.skeleton()`, `ConversationRow.skeleton()`, `NotificationRow.skeleton()`, `StatTile.skeleton()`, `StatusTimeline.skeleton()`, `MoneyBreakdown.skeleton({int lines})`, `AvailabilityCalendar.skeleton()`, `AppAvatar.skeleton()`, `ReasonChips.skeleton()`, `BadgeChip.skeleton()`, `ChatBubble.skeleton({bool mine})`, `CapacityBar.skeleton()`, `CompletenessMeter.skeleton()`… Các khối dựng từ primitive `AppSkeleton.box({w, h, radius})`, `.line({w})`, `.circle({size})`, cùng radius, khoảng cách và chiều cao với component thật nên bố cục không nhảy khi dữ liệu về.
- Nhận diện (sửa 2026-10-02, người dùng): **chỉ màu trắng, không nhiều màu, kể cả theme tối**. Khối trắng độ mờ thấp ở theme tối (trắng 8%); ở theme sáng khối **xám nhạt trung tính** `#E6E3DE` (không pha màu); dải sáng trắng (tối: trắng 14%; sáng: trắng 85%) quét chéo 1,6 s; không gradient aurora, không cyan/tím/hồng; chung một `AnimationController` cho cả màn (`SkeletonScope`); giảm chuyển động thì đứng yên, không quét.
- Đọc màn hình: một nhãn "Đang tải" cho cả nhóm skeleton (`Semantics(liveRegion)`), từng khối `ExcludeSemantics`.
- Quy tắc: danh sách, lưới và thẻ đang tải dùng skeleton của chính component đó (số khối bằng số mục thường thấy trên một màn, ví dụ 3 `BookingCard`); chờ cấp màn không có hình khối biết trước (splash, mở thanh toán, chờ nhiếp ảnh gia trả lời) dùng `SignatureLoader`. Không dùng `CircularProgressIndicator`.
- Test mỗi skeleton: cùng kích thước với component thật ở 390dp và 320dp (so `tester.getSize`), golden sáng/tối, không ticker khi giảm chuyển động.

### NotificationRow · Đã có
Dòng trong hộp thư S17.01. `NotificationRow({required NotificationRowData item, required VoidCallback onTap, required VoidCallback onMarkRead, VoidCallback? onMuteKind})`; `onMuteKind` null (loại quan trọng không tắt được) ẩn mục "Tắt loại thông báo này" và hành động ngữ nghĩa tương ứng. Bố cục: chấm tím chưa đọc (bên trái) · biểu tượng loại trong vòng tròn tô nhạt (một biểu tượng cho mỗi `kind`, tông theo ngữ nghĩa) · tiêu đề đậm + nội dung tối đa 2 dòng · thời gian tương đối ("5 phút") · thumbnail 40dp tuỳ chọn. Dòng gom hiện tiêu đề đã gộp ("3 nhiếp ảnh gia đã báo giá…") và tối đa 3 avatar nhỏ. Có biến thể `NotificationRow.skeleton()`. `Semantics`: nhãn gộp "Chưa đọc. {tiêu đề}. {nội dung}. {thời gian}" (chưa đọc không chỉ là màu); nhấn giữ hoặc hành động ngữ nghĩa `customActions` mở menu "Đánh dấu đã đọc / Tắt loại thông báo này", nên không có thao tác chỉ vuốt. Vùng chạm cả dòng ≥ 48dp. Dùng ở S17.01.  
Lớp view-data: `NotificationRowData(id, icon, tone, title, body, timeLabel, unread, thumbUrl, groupAvatars)`: `icon` là `IconData` của `AppIcons` (một biểu tượng cho mỗi `type`), `tone` là `NotificationTone` (neutral tím · success xanh · action vàng, glyph mực đậm cố định ở cả hai theme · danger đỏ · muted xám). `NotificationKind` đã bỏ.

### NotificationBell · Đã gỡ (10a, 2026-10-06)
Widget đã xoá khỏi code; phần dưới giữ để tra cứu quyết định cũ. Biểu tượng chuông có chấm số cho thanh đầu trang S02.01, S02.03, S06.01. `NotificationBell({required int unread, required VoidCallback onTap})`: chuông 36dp (vùng chạm 48dp), chấm số đỏ, "9+" từ mười trở lên, ẩn khi 0. `Semantics.label` theo ngữ cảnh: 0 → "Thông báo", n → "{n} thông báo chưa đọc" (đọc cả cụm, không đọc số trần). `unread` đọc từ `users/{uid}.unreadCount` qua `unreadCountProvider` (không lắng nghe danh sách). Khác `TabBadge` ở chỗ nhãn ngữ nghĩa mang nội dung "thông báo".

### PermissionPrimer · Đã có
Nội dung sheet S17.03, bọc trong `AppBottomSheet`. `PermissionPrimer({required String title, required List<PrimerBenefit> benefits, String? note, required VoidCallback onEnable, required VoidCallback onLater, bool enabling = false})`; `PrimerBenefit(icon, text)` cho từng dòng lợi ích (3 dòng: lịch được nhận, nhắc giờ chụp, tin nhắn khi app ở nền), `note` là dòng nhỏ "Chọn \"Để sau\", chúng tôi sẽ hỏi lại sau 7 ngày.", `enabling` đặt nút chính ở trạng thái đang tải khi hộp thoại OS mở. Biểu tượng chuông, tiêu đề theo ngữ cảnh ("Bật thông báo để biết khi Minh Trí nhận lịch"), một dòng lợi ích, nút chính `AppButton.primary` "Bật thông báo" (gọi hộp thoại quyền của hệ điều hành), nút phụ "Để sau". "Để sau" ghi thời điểm; `PermissionPrimerPolicy(store, now, snoozeFor)` chặn hỏi lại trong 7 ngày và không bao giờ hỏi khi mở app qua `PrimerStore`. Không chứa logic quyền (controller của S17.03 gọi `NotificationPermissionPort`).  
Chính sách lưu hoãn: `PermissionPrimerPolicy`, `PrimerStore` (`lib/core/permission_primer_policy.dart`).

### TabBadge · Đã có
Chấm số trên icon thanh tab. `TabBadge({required int count, required Widget child})`: ẩn khi 0, "9+" từ mười trở lên, nền `error`, `Semantics.value` mặc định "{n} mục mới", đổi được bằng `semanticsValue` (tab Hồ sơ đọc "{n} thông báo chưa đọc"). Số lấy từ `tabBadgesProvider`. Dùng cho Công việc (yêu cầu chờ) và Khám phá (sự kiện mới).

---

### Component rút ra từ mock (phân tích UI 2026-10-02)

Các mẫu dưới đây lặp lại ở nhiều màn trong mock nhưng chưa có đặc tả. Viết thành widget dùng chung trước khi làm màn (thứ tự ở mục 7).

#### EscrowNotice · Đã có
`EscrowNotice({required String text, int? maxLines = 2, IconData icon = AppIcons.lock, String? title, Widget? trailing, VoidCallback? onTap})`: biểu tượng khoá + chữ trên nền `primarySubtle` (lớp `.esc` của mock), `Semantics(container)`. Từ #142: `icon` đổi biểu tượng đầu (đồng hồ `AppIcons.schedule` cho cửa sổ khiếu nại ở S18.01, cờ `AppIcons.flag` cho dải khiếu nại ở S05.02, `info` cho ghi chú của hỗ trợ ở S18.02); `title` là dòng đậm trên `text`; `trailing` nằm cuối hàng (liên kết "Xem khiếu nại"); `onTap` làm cả khối bấm được (gợn mực trên chính nền của khối). Không truyền bốn tham số mới thì hiển thị như cũ. Chữ (không còn "cọc" từ #129, khách trả 100%): khách "Đã thanh toán {số tiền}, tiền được giữ an toàn" (S05.02); nhiếp ảnh gia "{số tiền} đang được giữ, chuyển cho bạn theo 2 mốc"; vé "Tiền vé được giữ an toàn trên ứng dụng cho tới khi sự kiện kết thúc." (S11.03). S04.03 không dùng `EscrowNotice`: câu giữ tiền nằm trong dòng chữ phụ dưới bảng tiền. `maxLines: null` cho câu dài xuống dòng hết (ghi chú ba vế của S13.01). Dùng ở S05.02 (cả dải "Đang khiếu nại" / "Khiếu nại đã có kết quả", `DisputeBanner`), S11.03, S11.04, S06.05, S13.01, S13.07, S18.01, S18.02.

#### MoneyBreakdown · Đã có
`MoneyBreakdown({required List<MoneyLine> lines})`, `MoneyLine({required String label, required int vnd, MoneyLineStyle style = normal /*normal | strong | muted*/})`. Các hàng nhãn trái, số phải `tabularFigures`, định dạng `formatMoney`; hàng `strong` đậm ("Thanh toán 100%", tổng thanh toán), `muted` chữ phụ. Không còn hàng cọc hay "còn lại trả tại buổi chụp": S04.03 chỉ có hai hàng, "Gói {tên}" và "Thanh toán 100%". Dùng ở S04.03 (giá gói, thanh toán 100%), S11.03 (số vé × giá, tổng), S06.05 (các khoản), S13.08 (hoàn, phí).

#### PolicyTable · Đã có
`PolicyTable({required List<PolicyRow> rows, required int activeIndex, int whenMaxLines = 1})`, `PolicyRow({required String when, required String outcome})`. Các hàng chọn đơn không bấm được, hàng đang áp dụng tô `AppOptionTile` đã chọn; đọc màn hình "Đang áp dụng: …". `activeIndex` ngoài khoảng (ví dụ -1) thì không tô hàng nào (S13.08 khi chưa thanh toán). `whenMaxLines` cho điều kiện dài xuống dòng (S13.08 dùng 3; S05.03 giữ 1). Dùng ở S05.03 (huỷ ≥ 48 giờ 100% · 24–48 giờ 50% · < 24 giờ 0%), S13.08 (mốc huỷ chụp ngay).

#### ReasonPicker · Đã có
`ReasonPicker({required List<String> reasons, required int? selected, required ValueChanged<int> onSelected, ReasonPickerStyle style = chips /*chips | radio*/, String? otherLabel, ValueChanged<String>? onOtherText, int otherMinLength = 0, int otherMaxLength = 200, bool otherField = true})`. Kiểu `chips` (S05.03 huỷ, S13.08, S18.01) hoặc `radio` (S06.03 từ chối) dùng `AppOptionTile`; chọn "Lý do khác" hiện ô nhập ngắn có đếm, kiểm độ dài tối thiểu. `otherField: false` (#142, S18.01) giữ chip "Lý do khác" nhưng không mở ô nhập riêng, vì màn đã có ô Mô tả bắt buộc.

#### KeyValueBox và KeyValueRow · Đã có (#142)
`KeyValueBox({required List<KeyValueRow> rows})`, `KeyValueRow({required String label, required String value, String? note, Widget? trailing})` (`lib/core/widgets/key_value_box.dart`, lớp `.kv` của mock): hộp có viền, mỗi hàng nhãn mờ bên trái, giá trị đậm (số đều) bên phải, `note` nhỏ dưới giá trị, `trailing` cuối hàng (ví dụ chip sao chép). Chuyển từ `_KeyValueBox` riêng của S04.04 vào core khi S18.02 cần cùng hình. Dùng ở S04.04 (thông tin chuyển khoản), S18.02 ("Tiền đang giữ", "Gửi lúc"; khối "Kết quả" của `DisputeOutcomeCard`).

#### InlineToast · Đã có (#142)
`InlineToast(String text)` (`lib/core/widgets/inline_toast.dart`, lớp `.toast` của mock): một dòng kết quả có dấu tích xanh trên nền `surface` viền mảnh, `Semantics(liveRegion)`. Chuyển từ `_PaidToast` riêng của S05.02. Dùng ở S05.02 ("đã thanh toán") và S18.02 ("Đã có kết quả · {HH:mm dd/MM}").

#### PayMethodSelector và PayMethodPicker · Đã có
`PayMethodSelector({required PayMethod value, required ValueChanged<PayMethod> onChanged, bool enabled = true})` (S04.03, #129): danh sách radio chọn đơn, nhóm `Semantics` "Phương thức thanh toán". Hàng đầy chiều rộng "Chuyển khoản QR" (biểu tượng `qr_code_2`, phụ đề "Miễn phí · xác nhận ngay"), dưới là hai ô nửa chiều rộng "MoMo" và "ZaloPay" (biểu tượng ví, không phụ đề); luôn có một lựa chọn (mặc định `bank_qr`); `enabled = false` khi đang tạo thanh toán thì chạm không có tác dụng. Khoá phím `pay-method-{code}`. `PayMethod` (`bankQr`, `momo`, `zaloPay`) có `code` khớp `PaymentMethod` ở miền (`bank_qr`, `momo`, `zalopay`). Thẻ `domestic_card`, `intl_card` chưa hiện (cờ cấu hình tắt).
`PayMethodPicker` (S11.03, vé sự kiện) giữ nguyên, mỗi lựa chọn ánh xạ sang một mã cổng qua `PayMethod.provider`; chuyển vé sang `createPayment` thuộc #137.

#### ConfirmSheet · Đã có
`Future<bool> showConfirmSheet(BuildContext, {required String title, String? body, Widget? content, required String confirmLabel, required String keepLabel, bool danger = true, Future<void> Function()? onConfirm})`: sheet xác nhận chuẩn, nút an toàn (viền) bên trái, nút xác nhận (đỏ khi `danger`) bên phải, đang chạy `onConfirm` thì nút xác nhận hiện `SignatureLoader(inline)` và khoá sheet; lỗi hiện SnackBar trong sheet. Quy tắc CLAUDE.md "huỷ/từ chối là nút đỏ trong sheet xác nhận" đi qua widget này. Dùng ở S05.03, S06.03, S12.03 (huỷ sự kiện), S13.08, S09.02 (đăng xuất), S04.01 (bỏ yêu cầu đặt lịch).

#### CountdownPill · Đã có
`CountdownPill({required Duration remaining})` (S04.04, #129): viên thuốc nhỏ (mock `.st.live`) "Còn mm:ss", về 0 thì đổi thành "Hết hạn" chữ màu lỗi. Không tự đếm: chủ màn giữ đồng hồ và truyền `remaining`. `Semantics.label` đổi mỗi giây ("QR còn hiệu lực {m} phút {s} giây") nhưng `liveRegion` chỉ bật ở các mốc 5:00, 1:00, 0:10 và 0 (`isCountdownAnnounceSecond`, dùng chung với `CountdownRing`), để trình đọc màn hình không bị ngắt mỗi giây (WCAG 4.1.3).

#### CountdownRing và CountdownText · Đã có
`CountdownRing({required DateTime deadline, required Duration total, double size = 96, VoidCallback? onExpired, DateTime Function()? now})`: vòng tiến độ + số lớn ở giữa và đơn vị nhỏ (mock `.cd`), cập nhật mỗi giây khi còn < 1 giờ, mỗi phút khi dài hơn; `Semantics(role: timer)` đọc "Còn {n} giây"; giảm chuyển động: vòng nhảy theo giây, không nội suy. `CountdownText` cùng logic cho chữ trong nút ("Nhận · còn 22 giờ"); `interval` buộc nhịp cập nhật cố định cho chữ có giây (S13.06-confirm "1:52:10"). `onExpired` gọi đúng một lần khi về 0 (S14.03 dùng để gọi `tickInstantRequest`); `now` cho test và đồng hồ chung (`clockProvider`). Số là giờ khi còn ≥ 1 giờ, phút khi còn ≥ 1 phút ("38" + "phút"), giây khi dưới 1 phút; chưa có dạng `mm:ss` như mock S14.03-shooting ("38:12"; hoãn, #140). Dùng ở S14.02 (60 giây), S14.03 (thời gian buổi chụp, 132dp), S13.03, S13.06, S06.01 (hạn nhận yêu cầu).

#### ChatBubble, ChatComposer, ConversationRow · Đã có
`ChatBubble({required ChatBubbleContent content, required bool mine, BubbleSendState state = sent, String? senderName, VoidCallback? onRetry})`: của mình gradient bên phải, người kia kính bên trái, ảnh, vị trí, tin hệ thống ở giữa; `sending` mờ + đồng hồ, `failed` có "Gửi lại". `ChatComposer({required ValueChanged<String> onSend, VoidCallback? onPickImage, bool enabled = true, String? disabledReason})`: nút ảnh, ô tin bo tròn, nút gửi gradient; không gửi tin rỗng. `ConversationRow({required String name, String? avatarUrl, required String preview, required String timeLabel, int unread = 0, Widget? badge, VoidCallback? onTap})` (mock S07.02). Dùng ở S07.01, S07.02, S11.06, S18.02 và chat hỗ trợ S18.03 (qua `SupportThreadView`).

#### SupportThreadView · Đã có (#204, mở rộng #142; riêng hỗ trợ)
`SupportThreadView({required String threadId, required bool enabled, String? disabledReason, required String hint, required String Function(SupportMessage) senderLabel, Widget? emptyPlaceholder, Widget? header, bool scrollHeader = false})` (`lib/features/help/support_thread_view.dart`, không ở `core/`): danh sách tin của một `support_threads/{id}` (`limit(30)`) bằng `ChatBubble` + `ChatComposer`, gửi qua `sendSupportMessage`, lỗi gửi là SnackBar "Chưa gửi được tin nhắn. Thử lại." / "Bạn gửi hơi nhanh. Đợi vài phút rồi gửi tiếp.". `senderLabel` trả nhãn của từng tin (trả `''` cho tin của mình). Từ #142: tin `senderRole = system` hiện là tin hệ thống ở giữa (`SystemContent`; luồng help không có tin này); `scrollHeader: true` cho `header` cuộn cùng tin nhắn và mở ở đầu trang, chỉ cuộn xuống cuối sau khi người dùng gửi (S18.02: chi tiết khiếu nại ở trên, Trao đổi ở dưới); mặc định `false` giữ `header` cố định và luôn theo tin mới nhất (chat hỗ trợ S18.03). `enabled: false` bỏ ô nhắn, hiện `disabledReason` ở chỗ đó nếu có (khiếu nại đã có kết quả).

#### SwipeDeck · Đã có
`SwipeDeck<T>({required List<T> items, required Widget Function(BuildContext, T) cardBuilder, required ValueChanged<T> onLike, required ValueChanged<T> onSkip, VoidCallback? onUndo, VoidCallback? onEmpty, required String likeStampLabel, required String likeLabel, required String skipLabel, required String undoLabel, int initialIndex = 0, int initialUndoDepth = 0, Widget? belowCards})` (`lib/core/widgets/swipe_deck.dart`, #140 PR 2): chồng thẻ (3 thẻ hiện; thẻ 2: dịch 12, thu 0,94, mờ 0,55; thẻ 3: 24, 0,88, 0,3), kéo phải quá 30% chiều rộng hoặc ♥ là chọn, kéo trái hoặc ✕ là bỏ qua, dấu `likeStampLabel` ("CHỌN") hiện dần khi kéo; Hoàn tác trả lại thẻ vừa trả lời. Nút ♥ / ✕ 56dp, Hoàn tác 44dp + đệm (vùng chạm ≥ 48dp), luôn có, nhãn đọc màn hình `likeLabel` / `skipLabel` / `undoLabel` (S13.02: "Chọn người này", "Bỏ qua", "Hoàn tác", theo mock). Giảm chuyển động thì thẻ đổi tức thì, không bay. `initialIndex` là vị trí bắt đầu (các thẻ trước đã trả lời) và `initialUndoDepth` là số thẻ trước đó Hoàn tác còn trả lại được: dùng khi bộ thẻ dựng lại (S13.02 quay về từ tóm tắt). `belowCards` nằm giữa thẻ và hàng nút (S13.02: người đã chọn và "Xong"). `onEmpty` gọi sau thẻ cuối. Ảnh trong thẻ đổi bằng chạm nửa trái/phải (vuốt ngang là chọn/bỏ qua) — phần của thẻ S13.02, không của `SwipeDeck`.

#### MatchOverlay · Đã có
`MatchOverlay({required String name, required String body, String? myAvatarUrl, String? theirAvatarUrl, required VoidCallback onContinue, Duration autoContinueAfter = 3 s})` (`lib/core/widgets/match_overlay.dart`, #140; `body` là dòng phụ của từng phía, màn tự viết): **một nét liền vẽ chiếc máy ảnh** (continuous line art, theo hình người dùng đưa 2026-10-02; không trái tim, không icon tròn): `CustomPainter` vẽ path thân máy + ống kính xoáy vào tâm bằng `PathMetric.extractPath` theo tiến độ (0–1,8 s, `Curves.easeInOutCubic`), nét `onSurface` dày 4 (theo hộp 420×250), đầu/khớp tròn; hai nút chụp vẽ tiếp (1,5–1,95 s); vệt màu `primary` 16% sau ống kính hiện dần (1,2–2,1 s); ống kính "chớp" một vòng sáng `primary` nở 0,55→1,35 và mờ (1,75–2,45 s, kèm `HapticFeedback.lightImpact`); hai avatar 40dp **đáp vào giữa ống kính** (phóng 0,6→1, lò xo nhẹ, lệch 100 ms): hai người cùng lọt khung. Rồi "Đã match với {tên}" và dòng phụ hiện lên (2,1 s). Rộng `min(240dp, 78%)`, tỉ lệ 420:250. Tự sang màn kế sau khoảng 3 giây; nút "Tiếp tục" luôn có; chạm bất kỳ đâu bỏ qua hiệu ứng (nhảy tới khung cuối). Giảm chuyển động: hiện ngay khung cuối, không chớp, không rung. `Semantics(label: 'Đã match với {tên}', liveRegion)`. Path gốc ở `docs/design/ui-mock.html` (`.mcam`). Dùng ở S13.04: phía khách (S13.05, kế hoạch khách) và phía nhiếp ảnh gia trên S14.02 sau khi nhận (khung `#S13.04-provider`), rồi sang S14.03.

#### OfferStack · Đã có
`OfferStack({required List<Widget> offers})` (`lib/core/widgets/offer_stack.dart`, #140): chồng tối đa 3 thẻ lời mời, thẻ trên đầy đủ, hai mép thẻ sau lộ ra phía trên (mock S14.02 `.ostk`: lùi vào 12/24, nhô lên 8/15, mép thứ hai mờ 60%). Chỉ thẻ đầu được dựng; các mép không đọc màn hình (số lời mời nằm ở dòng phụ của thanh tiêu đề).

#### MapPreview · Đã có
`MapPreview({required List<MapPin> pins, double height = 250, bool route = false, VoidCallback? onRecenter, BorderRadius? borderRadius, MapCenter? center})`, `MapPin({required double lat, required double lng, required String label, bool self = false})` (`lib/core/widgets/map_preview.dart`, #140, plan Decision 30): bản đồ **sơ đồ**, không tile, không SDK bản đồ, không API trả phí. Nền vẽ lại `svg.base` của mock `.map` (khối nhà, đường, nước, công viên; hộp 260×200 phủ kín như `xMidYMid slice`) bằng các token `map-bg`, `map-block`, `map-road`, `map-water`, `map-park` (sáng/tối); đường phố chỉ để trang trí, chỉ vị trí tương đối của các ghim là thật. Ghim đặt bằng phép chiếu equirectangular (kinh độ nhân cos vĩ độ, bắc ở trên, khung vừa khít và căn giữa): khung là hộp bao các ghim, nới cho mỗi chiều ít nhất 0,0036° (~400 m, hai ghim cách vài mét không bị kéo ra mép), rồi chừa thêm 20% mỗi bên; một ghim nằm giữa. Ghim (mock `.mpin`): chấm 14 px viền trắng 3 px, `self` màu `map-self` (xanh), còn lại màu chữ phụ; nhãn chữ trong thẻ nhỏ dưới chấm. `route`: đường chấm (nét 1, cách 7, dày 4, màu `accent`) cong nhẹ giữa hai ghim đầu. `onRecenter`: nút tròn 34 px góc dưới phải (vùng chạm 48dp), tooltip "Về vị trí của tôi". `center` (`({lat, lng})`): khung được lấy đối xứng quanh điểm đó nên điểm nằm giữa bản đồ mà mọi ghim vẫn trong khung (S13.05: sau "Về vị trí của tôi" điểm hẹn về giữa). Đọc màn hình: một nút "Bản đồ: {nhãn các ghim}" (`mapSemantics`), nhãn ghim không đọc lại. Bo góc mặc định 16 (`--r2`); `BorderRadius.zero` cho bản đồ tràn viền (S13.05). Không có skeleton riêng (màn dùng skeleton thẻ 150/250). Dùng ở S14.03 (ghim khách tại điểm hẹn + "Bạn" từ vị trí mới nhất, có đường), S13.05 và S13.01 (kế hoạch khách), nền mờ của S13.08.

#### InstantIconDisc và InstantBoldPart · Đã có (riêng Chụp ngay)
`InstantIconDisc(IconData icon)` (`lib/features/instant/instant_icon_disc.dart`, #140 PR 2): đĩa 96dp nền `secondary` với một biểu tượng 40 màu chữ phụ (mock `.empty .idill`), trang trí (`ExcludeSemantics`), đặt trên tiêu đề của các màn trống/kết thúc của Chụp ngay: S13.02 trống, S13.07, S13.06 xong, S13.08 đã đóng. `InstantBoldPart(String text, {required String part, TextStyle? style, TextAlign? textAlign})` (`instant_bold_part.dart`): một câu có đúng một phần in đậm số đều (mock `<b class="tn">`), cho thời gian và số tiền trong chữ của Chụp ngay (S13.03 "Mỗi lời mời còn **0:42**", S13.06 "Tự hoàn thành sau **1:52:10**"); không thấy `part` thì in thường. Hai widget ở thư mục tính năng, không ở `core/`: chưa màn nào khác dùng.

### Component của spec 10-05 (loại nhà cung cấp, album, giải thưởng, Đăng việc) · Mới

Đặc tả hành vi ở [`../2026-10-05-provider-types-portfolio-jobs-design.md`](../2026-10-05-provider-types-portfolio-jobs-design.md); hình ở mock (mục "Loại nhà cung cấp", S24, S25, S15, S16).

#### ProviderMark · Mới (thay `VerifiedMark` khi viết)
`ProviderMark({required ProviderMarkKind kind, double size = 14})`, `kind`: `verified` (tích xanh tròn, như `VerifiedMark`), `artist` (tích vàng tròn, nền gradient vàng `F7D774 → C9962B`, dấu ✓ tối), `studio` (con dấu viền răng cưa 12 múi tô gradient vàng, ✓ tối, cỡ 16). `providerMarkOf(photographer)` chọn: `artist` → artist; `studio` + đã xác minh → studio; `verified` → verified; còn lại không vẽ gì. Nâng cao như `VerifiedMark`. `Semantics.label`: "Đã xác minh" / "Nhiếp ảnh gia đã duyệt" / "Studio đã xác minh". Token vàng mới: `gold`, `goldInk`, `goldSoft`, `goldLine` (tối và sáng) thêm vào `design-system/tokens.json`.

#### ProviderTag · Mới
Nhãn chữ dạng viên thuốc nhỏ: `artist` "Nhiếp ảnh gia" (chữ, viền và nền vàng nhạt, biểu tượng giải), `studio` "Studio" (viền mảnh, biểu tượng cặp). Hậu tố tuỳ chọn ("· 7 giải", "· Hoàn Kiếm"). Không vẽ cho `individual`.

#### OrdersClosedTag · Mới
Nhãn "Chưa nhận đơn" (`profileOrdersClosedTag`) ở S03.01 cho thợ có `acceptingOrders == false` (#133): viên thuốc nhỏ viền nét đứt (`colorScheme.outline`), biểu tượng khoá `AppIcons.lock`, chữ phụ; đặt dưới tên như `ProviderTag`, không có tích xanh. Đi kèm `ordersClosedButtonStyle` (chữ 60% `ink-2`, viền 60% `line-2`) cho nút viền vô hiệu "Chưa nhận đặt lịch". Không vẽ cho chủ hồ sơ.

#### AwardChip và AwardRow · Mới
`AwardChip` (S03.01): thẻ 178dp, viền và nền vàng nhạt, đĩa biểu tượng giải vàng, kết quả (đậm) + "cuộc thi năm · hạng mục" một dòng. `AwardRow` (S25.01): đĩa biểu tượng (vàng khi `approved`, xám khi khác), tiêu đề "kết quả · cuộc thi năm", `StatusBadge` + dòng phụ (hạng mục hoặc lý do).

#### EarningRow · Mới
Hàng khoản thu của S06.05 và lịch sử thanh toán S22.01 (mock `.card`): trái là tiêu đề đậm "Tên khách · gói" (tối đa 2 dòng) và ngày `T7 12/10`; phải là số tiền ngắn (`450K`, `tabularFigures`, màu chữ thường, không dùng màu nhấn cho tiền) và `StatusBadge` trạng thái; dòng ghi chú tuỳ chọn bên dưới với biểu tượng (lý do tạm giữ, chữ cố định theo mã, không phải lời khách). `Semantics`: "tiêu đề, ngày, số tiền đầy đủ, ghi chú" (nút khi có `onTap`); ≥ 48dp. `EarningRow.skeleton()` cùng hình khối. Dùng ở S06.05 và S22.01. S22.01 (#141) dùng thêm ba chỗ tuỳ chọn: `statusLabel` (chữ của nhãn trạng thái, đọc cùng hàng), `action` (nút viền nhỏ dưới dòng ngày, "Chọn tài khoản nhận hoàn") và `footer` (liên kết chữ dưới phần bung, "Xem buổi chụp"); khi có `action`/`footer` chúng vẫn là nút riêng cho trình đọc màn hình. Nhãn trạng thái của S22.01 là viên `.st` của mock (chữ thường), không phải `StatusBadge`.

#### MonthHeader và groupByVnMonth · Đã có (#141)
Trong `core` (xuất qua `core.dart`), dùng ở S06.05 và S22.01. `MonthHeader.first(title, trailing)`: dòng `.sec` của mock, tiêu đề ("Các khoản") và tháng ở bên phải. `MonthHeader.month(month)`: nhãn `.nsec` của các tháng sau, viết hoa, chữ nhỏ, màu mờ, giãn chữ 0,08em. `monthLabel(l, monthKey, thisYear)` cho "Tháng 10" / "Tháng 10/2025" (dùng khoá `earningsMonth*`). `groupByVnMonth(items, dayKey)` nhóm liên tiếp theo tháng của ngày giờ Việt Nam (khoá `YYYY-MM`), giữ thứ tự truy vấn.

#### PortfolioViewToggle · Mới
Nút gạt hai lựa chọn dạng viên thuốc (Album / Dòng thời gian), biểu tượng + chữ, `Semantics` vai trò tab có trạng thái chọn.

#### AlbumTile · Mới
Ảnh bìa vuông với hai lớp viền giả chồng phía trên (gợi xấp ảnh), tên 1–2 dòng, số ảnh; biến thể `featured` rộng hết hàng 16:7 có số ảnh phủ góc. Skeleton riêng.

#### ReorderableRow · Mới
Hàng có tay nắm ≡ (vùng chạm 48dp, nhấn giữ để kéo), ảnh, tên, phụ đề, menu "…" có Chuyển lên / Chuyển xuống / Lên đầu / Xuống cuối (đường thay thế không cần kéo). Đọc vị trí "n trên m"; trạng thái đang kéo: viền primary, nền accent nhạt, bóng.

#### PostPickerGrid · Mới
Lưới 3 cột chọn nhiều, ô chọn có số thứ tự (thứ tự chọn), nhãn góc dưới ("4 ảnh", tên album hiện tại). Giới hạn số ô chọn; ô vượt giới hạn vô hiệu. Tham số `crossAxisCount` (mặc định `PostPickerGrid.columns` = 3; S27.03 dùng 5 ô nhỏ mỗi hàng như mock, #151).

#### JobCard · Mới
Biến thể `customer` (S15.02: tag thể loại, `StatusBadge`, tiêu đề, ngày · quận · ngân sách, hàng avatar người báo giá + "{n} báo giá · {m} mới", thời gian còn) và `photographer` (S16.02: tag + "Bạn được mời", `FitPill`, tiêu đề, ngày · giờ · quận · khoảng cách, ngân sách, "{n} báo giá · còn {m} ngày"; biến thể khoá mờ với dòng lý do). Không bao giờ hiện số điện thoại hay địa chỉ cụ thể.

#### QuoteCard, DeliverableChips, FitPill · Mới
`QuoteCard` (S15.03): người báo giá + `ProviderMark` (+ tag "Được mời"), dòng tin cậy, giá + so với ngân sách bằng chữ ("trong ngân sách" / "vượt {x}"), `DeliverableChips` (ảnh chỉnh, ngày giao, lần sửa, "Rảnh {ngày}" tô xanh), câu đầu lời nhắn một dòng, `FitPill` "Hợp {n}%", nút lưu, nút "Xem". `DeliverableChips` có biến thể `grid` 4 ô (S15.04: số lớn serif + nhãn).

#### MilestoneTable · Mới
Bảng mốc tiền: mỗi dòng đĩa số thứ tự, tên mốc + dòng phụ, số tiền tabular; dùng ở S15.04, S16.03 (dạng một dòng chữ) và S04.03 / S05.02 khi hợp đồng 100% được chốt. Mốc cuối nhận phần dư làm tròn.

### `ImagePurpose` / `MediaUploader.upload(purpose:)` · Đã có (#147)
Mọi màn tải ảnh lên (S10.01, S05.05, S11.05, S12.01, S25 minh chứng, S07.01, S11.06, ảnh đại diện S09.03) gọi `MediaUploader.upload(image, storagePath:, purpose: ImagePurpose.<x>)`; `purpose` bắt buộc. Nén trên máy, xoá EXIF và JPEG nằm trong uploader (bảng mục đích, giới hạn và quy tắc: `data-model/README.md` mục "Ảnh tải lên"). Màn không tự gọi bộ nén và không import `firebase_storage` hay `flutter_image_compress`; tiến độ và kết quả (`UploadedMedia` có `width`, `height`, `sizeBytes`) đọc qua `UploadEvent`. Bản giả trong test: `FakeMediaUploader.purposes` (đường dẫn → mục đích) và `FakeImageCompressor`.

## 5. Công cụ không phải widget

### Định dạng · Mới
`formatMoney(int vnd, {bool short = false})` → `1.500.000₫` hoặc `1,5M`; `eventPriceLabel(int vnd)` → `250.000₫` hoặc, khi 0, **“Không thu phí”** (không bao giờ “0₫”); `formatDay(DateTime)` → `T7 12/10`; `formatTimeRange(start, end)` → `15:30–17:30`; `formatHm(DateTime)` → `07:05` (#142; đọc nguyên trường giờ/phút, nên truyền giờ VN `toVn(...)`; S11.04 và S18.02 dùng chung thay cho hàm riêng); `formatDistance(double km)` → `1,2 km`. Có test đơn vị với múi giờ Asia/Ho_Chi_Minh.

### ContactLauncher · Mới
`ContactLauncher.open(ContactChannel, {required ContactSubject subject})` (trả `ContactOpenResult`: `opened | locked | unavailable | cannotLaunch`) xin URL từ `ContactLinkRepository.link(...)` (gọi hàm callable `getContactLink`, lỗi `contact_locked` nếu chưa mở khoá) rồi mở bằng `url_launcher` (`LaunchMode.externalApplication`); `canOpen(channel)` kiểm `canLaunchUrl` để ẩn kênh không dùng được. Số không bao giờ nằm trong ứng dụng ngoài khoảnh khắc mở URL; không ghi vào log hay phân tích. Có bản giả trong test. Chỉ mở URL đúng dạng `tel:+…`, `https://zalo.me/<số>`, `https://wa.me/<số>` (không query, cổng, user info); URL khác bị từ chối.

### RecommendationRepository · Mới
Giao diện gợi ý (spec chính 3e): `recommendPhotographers(RecommendationQuery) → RecommendationPage`, `similar(photographerId)`, `recommendPosts(...)`, `sendFeedback(List<RecommendationSignal>)`. Cài đặt `RemoteRecommendationRepository` (gọi hàm callable `recommend`, hạn 800 ms) và `LocalRecommender` (sao đã làm mượt + khoảng cách; dự phòng và test). Hai bản qua cùng bộ test hợp đồng.

### LocationRepository · Đã có
`currentApproxLocation()` (độ chính xác thấp, hạn 8 giây), `currentPosition()`, `currentFix({highAccuracy})` (vị trí kèm sai số thật, #140), `permissionStatus()`, `request()`, `openSettings()` (cài đặt của app), `openLocationSettings()` (cài đặt vị trí của máy khi công tắc vị trí tắt, `serviceOff`; S13.01 "Cho phép vị trí", #140 PR 2). Trả `geohash` thay vì toạ độ cho phần gửi mạng. Bản giả cho test.

---

### Component của spec 10-06 (đánh giá cà chua / gạch) · Mới

Thay 5 sao bằng một phe: cà chua (hài lòng) hoặc gạch (chưa hài lòng), tối đa 10 lần chạm. Hình ở mock (`#S05.05`, `#S05.05-brick`, `#S05.05-studio`, `#S03.01-reviews`). Hai màu token mới `tomato`, `brick` (sáng `D93A2B` / `A65A35`, tối `FF5A47` / `D2875E`) chỉ dùng cho hai biểu tượng, thanh mức, `VerdictBadge` và thanh tỷ lệ; phần còn lại giữ 60-30-10. Lõi (`core/`) không import `lib/data`, nên dùng enum `VerdictKind { tomato, brick }`; tính năng ánh xạ `Verdict` sang nó.

#### VerdictIcon · Mới
`VerdictIcon(VerdictKind kind, {double size = 16, Color? color})`. Hai biểu tượng nét (`assets/icons/tomato.svg`, `brick.svg`, `viewBox 24`, nét `currentColor` dày 1,8) vẽ bằng `SvgPicture.asset` với `ColorFilter.mode(color, srcIn)`; màu mặc định là token của phe theo giao diện (`verdictColor(context, kind)`). Chỉ trang trí (`ExcludeSemantics`): chữ đọc nằm ở widget bao quanh. Mock `.tm svg`.

#### VerdictPad · Mới
`VerdictPad({required VerdictKind? kind, required int hits, required void Function(VerdictKind?, int) onChanged, bool compact = false, bool enabled = true, String? subject})`; `kind == null` khi `hits == 0`. Hai nút cạnh nhau (mock `.vpad`, `.vbtn`): biểu tượng 40 trên nhãn ("Hài lòng" / "Chưa hài lòng"), nút đang chọn có viền và nền 14–16% màu phe, "×n" góc trên phải cùng màu; nút còn lại nền `glass`. Chạm: phe chưa chọn thì chọn với ×1 (kể cả đổi phe, không hỏi lại); chạm tiếp trên phe đang chọn thì +1; chạm lần thứ 11 không làm gì. Rung nhẹ mỗi lần (`HapticFeedback.lightImpact`), rung mạnh khi chạm 10 (`heavyImpact`). Hiệu ứng chỉ là một cú nảy của biểu tượng mỗi lần đổi (220 ms, không `repeat()`, tắt khi hệ thống giảm chuyển động). `Semantics`: mỗi phe là thanh trượt, nhãn "Ném cà chua, {n} trên 10" / "Ném gạch, {n} trên 10", có hành động tăng, giảm, chạm; giảm ở 1 thì bỏ chọn; vùng chạm ≥ 48dp. `compact` (mock `.vpad.cp`, khối "Đánh giá thợ / studio" của S05.05-studio): biểu tượng 22, nhãn và "×n" trên một hàng. `subject` ("thợ", "studio"; màn có hai bảng như S05.05-studio): nhãn mỗi phe thành "Ném cà chua cho {subject}, {n} trên 10" / "Ném gạch cho {subject}, {n} trên 10" (`reviewA11yTomatoFor` / `reviewA11yBrickFor`); `null` giữ nhãn không có đối tượng. Vô hiệu thì không nhận chạm và không có hành động.

#### VerdictLevel · Mới
`VerdictLevel({required VerdictKind kind, required int hits, required String label, required VoidCallback onReset, bool showHint = true})`. Dưới pad khi đã chọn phe (mock `.vlvl`): nhãn mức đậm (`verdictLevelLabel(l10n, kind, hits)`: cà chua 1–2 "Ổn", 3–5 "Hài lòng", 6–9 "Rất hài lòng", 10 "Tuyệt vời!"; gạch 1–2 "Hơi tiếc", 3–5 "Chưa ưng", 6–9 "Thất vọng", 10 "Rất thất vọng"), nút chữ "Làm lại" (gọi `onReset`), thanh 6dp có phần tô rộng bằng `verdictIntensity(hits)` (bản hiển thị của công thức máy chủ `0,4 + 0,6·log10(hits)`; 7 lần chạm = 91%) màu của phe, dòng gợi ý "Chạm tiếp để tăng mức độ, tối đa 10" (`showHint`; S05.05 tắt ở phe gạch vì khung `#S05.05-brick` không vẽ dòng này).

#### VerdictBadge · Mới
`VerdictBadge({required VerdictKind kind, required int hits})`. Viên thuốc ở dòng đánh giá (mock `.vbdg`): biểu tượng 14 và "×n" 11,5 đậm màu phe, nền 14% (cà chua) / 16% (gạch) màu đó. `Semantics.label`: "Cà chua, {n} trên 10" / "Gạch, {n} trên 10". Dùng ở S03.01 tab Đánh giá.

#### TomatoRatioBar · Mới
`TomatoRatioBar({required int tomatoCount, required int brickCount})`. Thanh 8dp bo tròn (mock `.vratio`), đoạn cà chua trước, cách 2dp, rộng tỷ lệ với số lượng (56 : 2 thì đoạn gạch rất hẹp); một phe bằng 0 thì phe kia chiếm cả thanh; không có đánh giá thì vẽ nền trống. `Semantics.label`: "{t} cà chua, {b} gạch". Dùng ở đầu tab Đánh giá của S03.01, kèm "% cà chua" lớn và dòng "56 cà chua · 2 gạch · 58 đánh giá".

#### MetaLine · Mới
`MetaLine(List<MetaPart> parts, {TextStyle? style, int maxLines = 1})`; `MetaPart.text(String, {String? bold})` (phần `bold` trong chữ in đậm, số đều nhau như mock `<b class="tn">`, S13.05 "đến trong khoảng **9 phút**") và `MetaPart.tomato(int pct, {int? count})` (có `count` thì "97% (58)", dùng ở thẻ ảnh S02.01). Nối các phần bằng " · " thành một `Text.rich`, phần cà chua là `VerdictIcon(12)` + "97%" (`formatTomatoPct`) nằm giữa dòng chữ; cắt bằng dấu "…" khi quá `maxLines`. Mặc định cỡ 12 màu `foregroundSecondary`. Thay các chuỗi ghép sẵn có số sao (thẻ thợ, hàng kết quả tìm, dòng chủ sự kiện, dòng tin cậy của báo giá). Ẩn phần cà chua khi chưa đủ 5 đánh giá (`hasTomatoPct`); `MetaPart` của phần đánh giá do helper dùng chung của lõi `reviewMetaPart(summary, l10n, {withCount})` (`lib/core/review_meta.dart`) dựng, các phần chữ khác do tính năng tạo: từ 5 đánh giá là phần cà chua, 1–4 là chữ "Mới · {count} đánh giá" (`photographerReviewsNew`), 0 thì không có gì. Đọc cho trình đọc màn hình chỉ là "97%" (biểu tượng không có nhãn).

---

### Component của S26 (studio và thành viên) · Đã có (#136)

#### MemberRow · Đã có
`MemberRow({String? avatarUrl, required String name, ProviderMarkKind? mark, List<MetaPart> meta = const [], Widget? trailing, bool enabled = true, VoidCallback? onTap})` · `MemberRow.skeleton()`. Một người trong danh sách studio (mock `.irow2`): `AppAvatar` 40 (trang trí), tên đậm kèm `ProviderMark` khi có (tích xanh ở S26.02, con dấu studio ở S26.03), một `MetaLine` bên dưới (cà chua %, "2 việc đang giao", "Lời mời đã gửi · Hết hạn sau 5 ngày"), nút ở cuối (`trailing`: viền "Mời", chữ "Huỷ", menu "…"; nhiều nút thì truyền `Wrap` căn phải để xuống hàng khi hẹp). Phần nút rộng tối đa nửa hàng nên tên luôn còn chỗ (320dp, chữ 1,3). `enabled: false` (đang ở studio khác, đang nghỉ 7 ngày, đang ở studio thì lời mời khác mờ): mờ 50%, không nhận chạm, đọc là bị tắt; dòng meta nói lý do. Trình đọc màn hình đọc một nhãn "tên, dấu, meta" (cà chua đọc "97% cà chua"); nút ở cuối giữ nhãn riêng. Skeleton: vòng avatar và hai dòng. Dùng ở S26.01, S26.02, S26.03.

#### MemberStrip · Đã có
`MemberStrip({required List<MemberStripItem> members, required int total, required String label, ValueChanged<String>? onTap})` · `MemberStripItem({required String id, required String name, String? avatarUrl, int? tomatoPct})` · `MemberStrip.skeleton()`. Hàng thành viên của hồ sơ studio (mock `.mems`, S03.01-studio): tối đa 4 người, mỗi ô rộng tối đa 54dp gồm `AppAvatar` 40 (trang trí), tên (một dòng, cắt "…") và `MetaLine` cà chua (bỏ khi `tomatoPct` null, tức chưa đủ 5 đánh giá); còn lại của `total` (`memberCount`) là vòng "+n" nền field. Các ô co lại cùng nhau khi hẹp (320dp, chữ 1,3). Trình đọc màn hình: một danh sách (`SemanticsRole.list`) tên `label` ("Thành viên Studio Mây"), mỗi người là một mục đọc "tên, 97% cà chua" và bấm được (mở hồ sơ thợ qua `onTap(id)`), mục "+n" đọc "và {n} thành viên khác". Skeleton: bốn vòng avatar và một dòng. Dùng ở S03.01 (studio).

#### AssigneeCard · Đã có
`AssigneeCard({required AssigneeSummary summary, required String studioName, required VoidCallback onViewProfile, String? changeLabel, VoidCallback? onChange, bool collaborator = false})` · `AssigneeSummary({required String id, required String name, String? avatarUrl, bool verified = false, int? tomatoPct, int shoots = 0})` · `AssigneeCard.skeleton()`. Thẻ "Thợ chụp cho bạn" của booking studio phía khách (mock `#S05.02-studio`): `AppAvatar` 48 (trang trí), tên đậm kèm tích xanh khi `verified`, `MetaLine` "🍅 97% · 112 buổi · thợ của Studio Mây" (bỏ phần cà chua khi `tomatoPct` null, tức chưa đủ 5 đánh giá; `studioName` rỗng thì chỉ "112 buổi"), nút viền xsmall "Xem hồ sơ" bên phải (rộng tối đa nửa hàng), và dưới cùng nút viền small `changeLabel` ("Xin đổi thợ (1 lần)"; `onChange` null thì tắt, ví dụ "Đã xin đổi · chờ studio"; `changeLabel` null thì không có nút). Nhãn "Giao {ngày}" và tiêu đề khối nằm ở màn hình (`StudioAssigneeBlock` của S05.02), không trong thẻ. Trình đọc màn hình đọc người là một nhãn "tên, Đã xác minh, 97% cà chua · 112 buổi · thợ của Studio Mây"; mỗi nút giữ nhãn riêng và vùng chạm 48dp. Skeleton: vòng avatar và hai dòng trong khung thẻ (khi hồ sơ thợ đang tải). Dùng ở S05.02 (booking studio, phía khách). `collaborator: true` (S27, #151, mock `#S05.02-studio-collab`): meta chỉ "{n} buổi" và thêm dòng "Cộng tác với {Studio}" dưới meta (khoá `assignee-collab-label`, cũng nằm trong nhãn đọc); `StudioAssigneeBlock` bật cờ khi thợ đã nhận là cộng tác viên.

---

### Component của S27 (tuyển thợ, cộng tác viên) · Đã có (#151)

Không có widget mới trong `lib/core/`: lõi chỉ thêm tham số (`AppChip.trailing`, `AppChip.enabled`, `PostPickerGrid.crossAxisCount`, `AssigneeCard.collaborator`), hai biểu tượng (`AppIcons.handshake`, `AppIcons.campaign`) và hàm `vnDaysBetween(from, to)` (`lib/core/vn_time.dart`: số ngày lịch Việt Nam giữa hai thời điểm, có dấu; dùng cho "hôm qua", "{n} tuần trước", "còn {n} ngày"). Các widget dưới đây nằm trong feature (không dùng ở use case khác nên chưa rút vào lõi; rút khi có màn thứ hai cần).

#### CollabTermsCard · Đã có (feature)
`CollabTermsCard({required bool agreed, required ValueChanged<bool>? onChanged})` (`lib/features/recruit/collab_terms_card.dart`). Khối "Điều khoản cộng tác" (mock S27.03): tiêu đề, ba gạch đầu dòng `collabTerm1–3` (mẫu tối thiểu, chờ luật sư duyệt), ô "Tôi đồng ý điều khoản cộng tác" (khoá `collab-terms-agree`). `onChanged` null thì ô tắt (đang gửi). Màn giữ nút chính tắt cho tới khi `agreed`. Dùng ở S27.03 (tin cộng tác) và sheet "Cộng tác với {Studio}" của S27.06 (thợ).

#### RecruitCard, RecruitKindTag, RecruitMatchTag, RecruitNote · Đã có (feature)
`RecruitCard({required RecruitPost post, required bool match, required DateTime now, required VoidCallback onTap})` · `RecruitCard.skeleton()` (`lib/features/recruit/recruit_card.dart`, mock `.jcard`): tag loại (`RecruitKindTag`, mock `.tag`) + "Hợp với bạn" (`RecruitMatchTag`, mock `.fit`) khi điểm khớp 2, tiêu đề đậm, dòng "Studio · khu vực · thể loại" kèm con dấu studio, hàng thù lao ("800.000₫/buổi" / "Thoả thuận") + "{tần suất} · {bao lâu trước}". `RecruitNote(text, {icon = AppIcons.lock})` là dòng ghi chú mock `.lockn` (khoá hoặc info). Dùng ở S27.01, S27.02, S27.05.

#### CollabPayBadge, CollabTitleMeta · Đã có (feature)
`CollabPayBadge(PayStatus status)` (`lib/features/collab/collab_controller.dart`): `StatusBadge.custom` chữ in hoa như mock `.badge`, "Cần trả" (vàng), "Chưa nhận" (đỏ), "Đã báo trả" (tím), "Đã nhận" (xanh); màu lấy cặp subtle/ink của theme tối hoặc sáng. `CollabTitleMeta({required String title, required String meta})`: hai dòng tiêu đề + meta của thẻ việc (mock `.irow2`). Dùng ở S27.06 (studio và thợ).

#### StudioOfferLine · Đã có (feature)
`StudioOfferLine({required Booking booking})` (`lib/features/booking/widgets/studio_offer_line.dart`): phía studio của booking có offer CTV, dựa trên `studioOfferOf(booking, now)`: "Chờ {tên} nhận · còn {thời gian}" (đếm lùi bằng đồng hồ tiêm vào) hoặc dòng đỏ "{tên} đã từ chối. Giao người khác trước {hạn}."; không hiện khi booking đã huỷ, xong hoặc offer không còn liên quan. Dùng ở S05.02 (studio) và trong `StudioJobCard` của S06.01.

---

### Component của spec 10-08 (điểm chụp đang hot) · Mới

#### SpotCard · Mới
Thẻ điểm chụp ảnh dạng ngang (ở Home và S02.04, `compact: true`, rộng 200dp) hoặc dạng lớn/dọc (ở S29.01, `compact: false`). Hiển thị ảnh cover `cardUrl`, tên điểm `name`, thành phố `city`, nhãn mùa `SeasonTag` khi `inSeason`, và dòng trạng thái (`spotCardStats(l, entry)`: `{n} thợ · {m} sự kiện sắp tới`). `SpotCard({required SpotEntry entry, VoidCallback? onTap, bool compact = false})`.

#### SeasonTag · Mới
Tag chỉ báo thời điểm vào mùa của điểm chụp. `SeasonTag({String? label, int? monthTo})`. Nền subtle, viền mảnh, biểu tượng lá `AppIcons.eco`. Khi `monthTo != null` hiển thị "Đang vào mùa · tới cuối tháng {m}", hoặc nhãn tuỳ biến `label` ("Đang vào mùa"). Dùng ở `SpotCard` và đầu trang `SpotScreen` (S29.02).

#### SlotGrid · Mới
Lưới suất chụp theo giờ bắt đầu (mock `.pkg`, S29.06). `SlotGrid({required List<({String start, String end, bool free})> slots, String? selected, required ValueChanged<String> onPick, String? semanticsLabel})`. Bốn cột (ba cột khi rộng dưới 300dp), ô bo 14dp nền kính viền mảnh: giờ bắt đầu đậm 13,5 và "–{giờ kết thúc}" 11 bên dưới; ô đang chọn viền màu nhấn, nền nhấn nhạt; suất kín mờ 50% kèm chữ "Đã kín", không chạm được. Mỗi ô là một radio (`inMutuallyExclusiveGroup`, `checked`), đọc "06:00–06:30" hoặc "06:40, Đã kín". Danh sách suất do `freeSlots(window, offer, taken)` của `spot_rules.dart` dựng; skeleton là các ô `AppSkeleton.box` cùng cỡ do màn tự vẽ.

## 6. Bảng tra: widget ↔ màn

| Widget | Màn |
|--------|-----|
| `CtaSurface`/`AppButton` | mọi màn có nút chính, đĩa tab giữa |
| `AppChip`, `SegmentedTabs` | S02.01, S03.01, S02.06, S04.02, S05.01, S11.01, S11.04, S06.01, S10.01, S12.01, S09.01, S09.02, S02.04, S27.01, S27.04, S27.06 (sheet đã trả) |
| `PhotoCard` | S02.01, S03.01, S02.03, S10.01 |
| `PhotographerCard`, `ReasonChips` | S02.01, S02.06 |
| `BookingCard` | S04.03, S04.04, S05.02, S07.01, S05.01, S06.01 |
| `EventCard`, `DateBlock` | S02.03, S11.01, S12.02, S12.03, S02.04 |
| `TicketCard` | S11.04 (cả nút "Báo vấn đề" → S18.01) |
| `AppBottomSheet` | S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05, S08.04 |
| `StepProgress` | S04.01–S04.03, S08.01, S12.01, S12.02, S08.05, S08.02 |
| `AppFooterBar` | S08.05, S09.03 |
| `AppOptionTile` | S02.05, S02.06, S08.01 và sheet hình thức ở Cài đặt (`icon`), S26.04 (`meta`, `enabled`) (sau: S04.02, S13.01) |
| `AvailabilityCalendar` | S03.01, S02.06, S04.02, S06.04, S29.04 |
| `StatusTimeline` | S05.02, S18.02 |
| `CapacityBar`, `StatTile` | S03.01, S11.02, S06.01, S12.03, S03.02, S06.05 (`StatTile`) |
| `EarningRow` | S06.05, S22.01 |
| `ContactDial`, `ContactLauncher` | S03.01, S05.02, S11.02, S06.01, S12.03 (S05.04) |
| `PhoneField` | S04.03, S11.03, S04.05, S08.05, S09.03 |
| `OtpCodeField` | S06.06 (sheet OTP), S21.01 |
| `LocationPromptCard`, `LocationRepository` | S02.03, S02.04, S02.05 |
| `VerifiedMark`, `BadgeChip`, `BadgeRow`, `BadgeTile` | S02.02, S03.01, S02.06, S11.02, S12.03, S09.01, S03.02 |
| `SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter` | S06.02, S09.02, S08.02, S08.03, S08.04 |
| `TabBadge` | thanh tab dưới (Công việc, Khám phá, Hồ sơ = thông báo chưa đọc) |
| `NotificationRow` | S17.01 |
| `NotificationBell` | đã gỡ (10a, 2026-10-06; số chưa đọc là `TabBadge` của tab Hồ sơ) |
| `PermissionPrimer` | S17.03 |
| `BadgeChip`, `BadgeRow` (`alwaysShowSeeAll`), `BadgeTile` | S03.01 và S09.01 (hàng tối đa 3 chip + "Tất cả" → S03.02), S03.02 |
| `SignatureLoader`, `AsyncView`, `DotRingLoader` | mọi màn có tải dữ liệu |
| `EscrowNotice` | S05.02 (cả dải khiếu nại), S11.03, S11.04, S06.05, S13.01, S13.07, S18.01, S18.02 |
| `KeyValueBox`, `KeyValueRow` | S04.04, S18.02 |
| `InlineToast` | S05.02, S18.02 |
| `MoneyBreakdown` | S04.03, S11.03, S06.05, S13.08 |
| `PolicyTable` | S05.03, S13.08 |
| `ReasonPicker` | S05.03, S06.03, S13.08, S18.01 (`otherField: false`) |
| `PayMethodSelector` | S04.03 |
| `PayMethodPicker` | S11.03 |
| `CountdownPill` | S04.04 |
| `PaymentScreen`, `QrCheckoutView`, `WalletWaitingView`, `FakeTransferSheet` (`features/payment/`) | S04.04 (mọi chủ thể thanh toán: booking, vé sự kiện, Chụp ngay, phí xác minh) |
| `ConfirmSheet` | S04.01, S05.03, S06.03, S09.02, S12.03, S13.08, S14.03 (GPS chưa chính xác, khách không có mặt) |
| `CountdownRing`, `CountdownText` | S06.01, S13.03, S13.06, S14.02, S14.03, S27.07 (`CountdownText`: hạn trả lời offer) |
| `ChatBubble`, `ChatComposer`, `ConversationRow` | S07.01, S07.02, S11.06; `ChatBubble`/`ChatComposer` cả S18.02, S18.03 (chat) |
| `SupportThreadView` | S18.02 (`scrollHeader`), S18.03 chat |
| `SwipeDeck` | S13.02 |
| `MatchOverlay` | S13.04 (khách; nhiếp ảnh gia trên S14.02) |
| `OfferStack` | S14.02 |
| `MapPreview` | S13.01, S13.05, S13.08, S14.03 |
| `ProviderMark`, `ProviderTag` | S02.02, S02.06, S03.01, S15.02, S15.03, S15.04, S24.01 |
| `AwardChip`, `AwardRow` | S03.01, S25.01 |
| `ImagePurpose`, `MediaUploader.upload(purpose:)` | mọi màn tải ảnh: S10.01, S05.05, S11.05, S12.01, S25 (minh chứng), S07.01, S11.06, S09.03 |
| `PortfolioViewToggle`, `AlbumTile` | S03.01, S24.02 |
| `ReorderableRow`, `PostPickerGrid` | S24.02, S24.04, S24.01 (chế độ sắp xếp); `PostPickerGrid` cả S27.03 (5 cột) |
| `JobCard` | S15.02, S16.02 |
| `QuoteCard`, `DeliverableChips`, `FitPill`, `MilestoneTable` | S15.02, S15.03, S15.04, S16.01, S16.03 |
| `VerdictIcon`, `MetaLine` | S02.01, S02.02, S02.06, S03.01, S12.02, S15.03, S26 |
| `VerdictPad`, `VerdictLevel` | S05.05 (khối thợ và khối studio dùng `compact`) |
| `VerdictBadge`, `TomatoRatioBar` | S03.01 (tab Đánh giá) |
| `MemberRow` | S26.01, S26.02 (cả S26.02-collab), S26.03, S27.06 (hàng CTV, studio cộng tác, lời mời) |
| `MemberStrip` | S03.01 (studio) |
| `AssigneeCard` | S05.02 (booking studio, phía khách; `collaborator` khi thợ là CTV) |
| `CollabTermsCard` | S27.03, S27.06 (sheet nhận lời cộng tác) |
| `RecruitCard`, `RecruitKindTag`, `RecruitMatchTag`, `RecruitNote` | S27.01, S27.02, S27.05 |
| `CollabPayBadge`, `CollabTitleMeta` | S27.06 |
| `StudioOfferLine` | S05.02 (studio), S06.01 (`StudioJobCard`) |
| `SpotCard`, `SeasonTag` | S02.01, S02.03, S02.04, S29.01, S29.02 |
| `SlotGrid` | S29.06 |
| `ScreenCode` | mọi màn |

## 7. Thứ tự viết (đổi ngày 2026-10-02: component trước, màn sau)

Người dùng quyết định: phân tích UI, thiết kế và viết các shared component **trước** khi làm tiếp các màn, để các kế hoạch màn chỉ ghép component. Đã có trong code: mục 1–4 có nhãn "Đã có" và các widget trong `lib/core/widgets/`.

1. **Nhóm A** (kế hoạch `2026-10-02-shared-components-a.md`, **đã xong**): `SignatureLoader` + `AsyncView` (và chuyển mọi màn hiện có sang dùng chúng, bỏ spinner), skeleton cho từng component đã có (`AppSkeleton` + `SkeletonScope` + `.skeleton()` của mỗi component), `SectionHeader`, `OfflineBanner`, `EscrowNotice`, `MoneyBreakdown`, `PolicyTable`, `ReasonPicker`, `ProviderPicker`, `ConfirmSheet`, `CountdownRing`/`CountdownText`, `BookingCard`, `StatusTimeline`, `ChatBubble`, `ChatComposer`, `ConversationRow`.
2. **Nhóm B1** (kế hoạch `2026-10-02-shared-components-b1.md`, **đã xong**): `DateBlock`, `EventCard` (row, featured, compact) + `eventCardDataOf`, `TicketCard` (với mã QR `qr_flutter`), `BadgeChip` + `BadgeRow` + `BadgeTile`, `NotificationRow` + `NotificationBell`, `PermissionPrimer` + `PermissionPrimerPolicy`. Chuyển màn Khám phá sang dùng `EventCard` và xoá `NearbyEventTile`.
3. **Nhóm B2** (Chụp ngay & bản đồ): `MatchOverlay`, `OfferStack`, `MapPreview` **đã có** (#140, plan `2026-10-07-s13-s14-dispatch-provider.md` Tasks 8–9); `SwipeDeck` **đã có** (app khách, plan `2026-10-07-s13-instant-customer.md`, #140 PR 2).


## Icons (Material Symbols Rounded)

Quyết định 2026-10-06: một bộ icon duy nhất là **Material Symbols Rounded** (weight 400, optical size 24) trong mock, thư viện component và app. Ngoại lệ (giữ SVG/painter tuỳ biến): logo Zalo, WhatsApp, logo ứng dụng (`i-logo`), con dấu `i-seal` và dấu tick của `ProviderMark`.

- **Gói**: `material_symbols_icons` (Flutter), chỉ `lib/core/theme/app_icons.dart` được import `Symbols.*`. Mock dùng font Google "Material Symbols Rounded" (`<span class="ms">tên</span>`, `.ms.on` = FILL 1).
- **Danh mục**: `AppIcons.<ý nghĩa>` (xuất qua `core/core.dart`); feature không dùng `Icons.*`/`Symbols.*` (test `test/lint/features_use_app_icons_test.dart`).
- **Widget**: `AppIcon(icon, {selected, size, color, semanticLabel})`: viền (FILL 0) mặc định, đặc (FILL 1) khi `selected` (tab đang chọn, đã lưu/đã thích, ô tuỳ chọn đang chọn). Cỡ: `AppIconSize.sm/md/lg` = 20/24/28.
- **Bảng ánh xạ** (ý nghĩa, tên Material Symbols, symbol trong mock, `Icons.*` cũ). Đây là danh sách duy nhất mock và app cùng theo; cột "mock" để task cập nhật mock dùng.

| AppIcons | Material Symbols | sprite cũ (đã bỏ) | Icons.* cũ |
|---|---|---|---|
| `AppIcons.home` | `home` | `i-home` | `Icons.home_outlined` |
| `AppIcons.explore` | `explore` | `i-explore` | `Icons.explore_outlined` |
| `AppIcons.search` | `search` | `i-search` | `Icons.search` |
| `AppIcons.add` | `add` | `i-plus` | `Icons.add_rounded`, `Icons.add` |
| `AppIcons.calendar` | `calendar_today` | `i-cal` | `Icons.event_outlined`, `Icons.calendar_today_outlined`, `Icons.calendar_today` |
| `AppIcons.calendarCheck` | `event_available` | (mới, chưa có trong mock) | `Icons.event_available_outlined` |
| `AppIcons.calendarRepeat` | `event_repeat` | (mới, chưa có trong mock) | `Icons.event_repeat_outlined` |
| `AppIcons.profile` | `person` | `i-user` | `Icons.person_outline_rounded`, `Icons.person_outline`, `Icons.account_circle_outlined` |
| `AppIcons.chat` | `chat_bubble` | `i-chat` | `Icons.chat_bubble_outline_rounded`, `Icons.chat_bubble_outline` |
| `AppIcons.notifications` | `notifications` | `i-bell` | `Icons.notifications_none` |
| `AppIcons.notificationsActive` | `notifications_active` | (mới, chưa có trong mock) | `Icons.notifications_active_outlined` |
| `AppIcons.notificationsOff` | `notifications_off` | (mới, chưa có trong mock) | `Icons.notifications_off_outlined` |
| `AppIcons.settings` | `settings` | `i-gear` | `Icons.settings_outlined` |
| `AppIcons.favorite` | `favorite` | `i-heart` | `Icons.favorite_border`, `Icons.favorite` |
| `AppIcons.save` | `bookmark` | `i-save` | `Icons.bookmark_border`, `Icons.bookmark` |
| `AppIcons.share` | `ios_share` | `i-share` | `Icons.ios_share_rounded` |
| `AppIcons.back` | `arrow_back` | `i-back` | `Icons.arrow_back_rounded`, `Icons.arrow_back` |
| `AppIcons.forward` | `arrow_forward` | `i-arrow` | `Icons.arrow_forward_rounded` |
| `AppIcons.arrowUp` | `arrow_upward` | (mới, chưa có trong mock) | `Icons.arrow_upward_rounded` |
| `AppIcons.arrowDown` | `arrow_downward` | (mới, chưa có trong mock) | `Icons.arrow_downward_rounded` |
| `AppIcons.check` | `check` | `i-check` | `Icons.check_rounded` |
| `AppIcons.checkCircle` | `check_circle` | (mới, chưa có trong mock) | `Icons.check_circle_rounded` |
| `AppIcons.doneAll` | `done_all` | (mới, chưa có trong mock) | `Icons.done_all` |
| `AppIcons.close` | `close` | `i-x` | `Icons.close_rounded` |
| `AppIcons.undo` | `undo` | `i-undo` | — |
| `AppIcons.refresh` | `refresh` | (mới, chưa có trong mock) | `Icons.refresh_rounded` |
| `AppIcons.more` | `more_horiz` | `i-more` | `Icons.more_horiz_rounded`, `Icons.more_horiz` |
| `AppIcons.edit` | `edit` | (mới, chưa có trong mock) | `Icons.edit_outlined` |
| `AppIcons.swap` | `swap_horiz` | `i-swap` | `Icons.swap_horiz_rounded` |
| `AppIcons.dragHandle` | `drag_handle` | `i-grip` | `Icons.drag_handle_rounded` |
| `AppIcons.chevron` | `chevron_right` | `i-chev` | `Icons.chevron_right_rounded`, `Icons.chevron_right` |
| `AppIcons.chevronLeft` | `chevron_left` | (mới, chưa có trong mock) | `Icons.chevron_left_rounded` |
| `AppIcons.expandMore` | `expand_more` | (mới, chưa có trong mock) | `Icons.expand_more_rounded` |
| `AppIcons.visibility` | `visibility` | (mới, chưa có trong mock) | `Icons.visibility_outlined` |
| `AppIcons.visibilityOff` | `visibility_off` | (mới, chưa có trong mock) | `Icons.visibility_off_outlined` |
| `AppIcons.place` | `location_on` | `i-pin` | `Icons.place_outlined`, `Icons.location_on_outlined`, `Icons.location_on` |
| `AppIcons.nearMe` | `near_me` | (mới, chưa có trong mock) | `Icons.near_me_outlined` |
| `AppIcons.myLocation` | `my_location` | (mới, chưa có trong mock) | `Icons.my_location_outlined` |
| `AppIcons.city` | `location_city` | (mới, chưa có trong mock) | `Icons.location_city_outlined` |
| `AppIcons.camera` | `photo_camera` | `i-cam` | `Icons.camera_alt`, `Icons.camera_alt_outlined` |
| `AppIcons.addPhoto` | `add_a_photo` | (mới, chưa có trong mock) | `Icons.add_a_photo_outlined` |
| `AppIcons.image` | `image` | `i-img` | `Icons.photo_outlined` |
| `AppIcons.album` | `photo_library` | `i-album` | `Icons.photo_library_outlined`, `Icons.collections_outlined` |
| `AppIcons.grid` | `grid_view` | (mới, chưa có trong mock) | `Icons.grid_view_rounded` |
| `AppIcons.list` | `format_list_bulleted` | `i-list` | — |
| `AppIcons.description` | `description` | (mới, chưa có trong mock) | `Icons.description_outlined` |
| `AppIcons.schedule` | `schedule` | (mới, chưa có trong mock) | `Icons.schedule_rounded`, `Icons.schedule`, `Icons.access_time` |
| `AppIcons.mail` | `mail` | `i-mail` | — |
| `AppIcons.alternateEmail` | `alternate_email` | (mới, chưa có trong mock) | `Icons.alternate_email_rounded` |
| `AppIcons.lock` | `lock` | `i-lock` | `Icons.lock_outline_rounded`, `Icons.lock_outline` |
| `AppIcons.lockReset` | `lock_reset` | (mới, chưa có trong mock) | `Icons.lock_reset_rounded` |
| `AppIcons.phone` | `call` | `i-phone` | `Icons.phone_outlined`, `Icons.call_outlined` |
| `AppIcons.payment` | `credit_card` | `i-card` | — |
| `AppIcons.wallet` | `account_balance_wallet` | (mới, chưa có trong mock) | `Icons.account_balance_wallet` |
| `AppIcons.receipt` | `receipt_long` | (mới, chưa có trong mock) | `Icons.receipt_long_outlined` |
| `AppIcons.pin` | `pin` | (mới, chưa có trong mock) | `Icons.pin_outlined` |
| `AppIcons.darkMode` | `dark_mode` | `i-moon` | `Icons.dark_mode_outlined` |
| `AppIcons.lightMode` | `light_mode` | (mới, chưa có trong mock) | `Icons.light_mode_outlined` |
| `AppIcons.autoMode` | `brightness_auto` | (mới, chưa có trong mock) | `Icons.brightness_auto_outlined` |
| `AppIcons.badge` | `badge` | (mới, chưa có trong mock) | `Icons.badge_outlined` |
| `AppIcons.tag` | `sell` | (mới, chưa có trong mock) | `Icons.sell_outlined` |
| `AppIcons.star` | `star` | `i-star` | `Icons.star_rounded`, `Icons.star_outline_rounded`, `Icons.star` |
| `AppIcons.instant` | `bolt` | `i-bolt` | `Icons.bolt` |
| `AppIcons.ticket` | `confirmation_number` | `i-ticket` | — |
| `AppIcons.award` | `workspace_premium` | `i-award` | `Icons.workspace_premium_outlined`, `Icons.workspace_premium` |
| `AppIcons.medal` | `military_tech` | (mới, chưa có trong mock) | `Icons.military_tech` |
| `AppIcons.verified` | `verified` | (mới, chưa có trong mock) | `Icons.verified` |
| `AppIcons.work` | `work` | `i-brief` | `Icons.work_outline` |
| `AppIcons.store` | `storefront` | (mới, chưa có trong mock) | `Icons.storefront_outlined` |
| `AppIcons.handshake` | `handshake` | (chỉ nêu trong chú thích S09.02 của mock) | — |
| `AppIcons.campaign` | `campaign` | `campaign` (có trong mock, S03.01-studio) | — |
| `AppIcons.verifiedUser` | `verified_user` | (mới, chưa có trong mock) | `Icons.verified_user` |
| `AppIcons.people` | `group` | (mới, chưa có trong mock) | `Icons.people` |
| `AppIcons.celebration` | `celebration` | (mới, chưa có trong mock) | `Icons.celebration` |
| `AppIcons.trendingUp` | `trending_up` | (mới, chưa có trong mock) | `Icons.trending_up` |
| `AppIcons.autoAwesome` | `auto_awesome` | (mới, chưa có trong mock) | `Icons.auto_awesome_outlined` |
| `AppIcons.gradient` | `gradient` | (mới, chưa có trong mock) | `Icons.gradient_rounded` |
| `AppIcons.face` | `face_retouching_natural` | (mới, chưa có trong mock) | `Icons.face_retouching_natural` |
| `AppIcons.info` | `info` | `i-info` | `Icons.info_outline_rounded`, `Icons.info_outline` |
| `AppIcons.error` | `error` | (mới, chưa có trong mock) | `Icons.error_outline` |
| `AppIcons.warning` | `warning` | (mới, chưa có trong mock) | `Icons.warning_amber_rounded` |
| `AppIcons.cloudOff` | `cloud_off` | (mới, chưa có trong mock) | `Icons.cloud_off_rounded`, `Icons.cloud_off_outlined` |
| `AppIcons.pushPin` | `push_pin` | (mới, chưa có trong mock) | — |
| `AppIcons.volumeOff` | `volume_off` | (mới, chưa có trong mock) | — |
| `AppIcons.delete` | `delete` | (mới, chưa có trong mock) | `Icons.delete_outline` |
| `AppIcons.personRemove` | `person_remove` | (mới, chưa có trong mock) | — |
| `AppIcons.flag` | `flag` | (mới, chưa có trong mock) | `Icons.flag_outlined` |
| `AppIcons.car` | `directions_car` | `directions_car` (có trong mock) | — |
| `AppIcons.checkroom` | `checkroom` | `checkroom` (có trong mock) | — |
| `AppIcons.addCircle` | `add_circle` | (mới, chưa có trong mock) | — |
| `AppIcons.directions` | `directions` | (mới, chưa có trong mock) | `Icons.directions_rounded` |
| `AppIcons.landscape` | `landscape` | (mới, chưa có trong mock) | `Icons.landscape_rounded` |
| `AppIcons.eco` | `eco` | (mới, chưa có trong mock) | `Icons.eco_rounded` |
| `AppIcons.lightbulb` | `lightbulb` | (mới, chưa có trong mock) | `Icons.lightbulb_rounded` |
| `AppIcons.eventBusy` | `event_busy` | (mới, chưa có trong mock) | `Icons.event_busy_rounded` |
| `AppIcons.timer` | `timer` | (mới, chưa có trong mock) | `Icons.timer_rounded` |
