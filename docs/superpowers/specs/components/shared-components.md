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
Nền tối/sáng có ba vầng sáng (cyan, hồng, tím); sáng giảm còn 50%. `AuroraBackground({Widget? child})`. Mọi màn bọc trong nó với `Scaffold(backgroundColor: transparent)`. Test: hiển thị `child` trên cả hai theme.

### GlassCard · Đã có
Thẻ kính mờ (blur 24, radius 28, bóng mềm). `GlassCard({required Widget child, bool highlight = true})`. `highlight: true` vẽ viền spectrum (`SpectrumBorder`); **chỉ một thẻ chính mỗi màn** dùng. Thẻ list dùng `highlight: false` (viền mảnh). Dùng ở S01.03, S06.01 (thẻ hôm nay), S09.02, S11.04 (thẻ vé).

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
`AppButton.primary / .outline / .text(label, {onPressed, loading, icon, style})`. Cao 52, radius 16. `primary` là nút chính duy nhất của màn (qua `CtaSurface`, bóng theo theme). `loading` thay nhãn bằng vòng quay và vô hiệu nút; `onPressed: null` làm mờ 50%. Nút huỷ/từ chối không dùng `primary`.

**Chiều cao cố định**: nút chính luôn cao đúng `controlHeight` (52dp) ở mọi vị trí (thanh dưới, sheet, thẻ). Không đặt nút trong `Expanded`/`Flexible` theo trục dọc và không để nút co theo nội dung; trong `Column` của sheet bọc `SizedBox(height: controlHeight)` hoặc dùng `BottomActionBar`. Nút "thấp" (38dp) chỉ dùng trong hàng nút phụ của thẻ. Mọi `AppBottomSheet` và màn có thanh dưới (S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05, S08.04…) phải qua golden test kiểm chiều cao nút bằng nhau.

### AppChip (FilterChip) · Mới
`AppChip({required String label, required bool selected, required ValueChanged<bool> onChanged, AppChipKind kind = filter, Widget? leading})`. `kind: filter` đã chọn = nền primary đặc, chữ trên primary (bộ lọc: S02.06, S02.04; S11.01 lọc loại bằng hàng tag chữ `#workshop`, xem `screens/events.md`, chỉ chip “Không thu phí” dùng `AppChip`); `kind: context` đã chọn = nền `primarySubtle`, viền + chữ primary (danh mục ngữ cảnh/lựa chọn đơn: S02.01, S04.02, S12.01, S08.04). Cao 32 (vùng chạm 48), radius tròn, `Semantics(selected)`. Hàng chip dùng `Wrap` khi cần xuống dòng, cuộn ngang khi là bộ lọc.

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

### LocationPromptCard · Mới
Thẻ xin vị trí đúng lúc. `LocationPromptCard({required LocationPromptState state, required VoidCallback onAllow, required VoidCallback onLater, VoidCallback? onChooseArea})`. Trạng thái `ask` (biểu tượng ghim, "Sự kiện gần bạn", mô tả, nút "Cho phép" + "Để sau"), `requesting` (nút loading), `denied` (thu thành chip "Chọn khu vực"). Viền spectrum chỉ khi `ask`. Dùng ở S02.03. Widget không gọi hộp thoại quyền; màn xử lý trong `onAllow`.

---

## 3. Thẻ và danh sách

### AppAvatar · Mới
`AppAvatar({String? url, required String name, AppAvatarSize size = md, Widget? badge})`. Kích thước xs 32 · sm 40 · md 48 · lg 64 · xl 96; viền 2dp màu nền khi đè lên ảnh; ảnh lỗi/trống → chữ cái đầu tên trên nền gradient nhẹ. Đã có `CircleAvatar` thô ở `ProfileTab`; thay bằng widget này.

### VerifiedMark · Mới
Dấu tích xanh Verified. `VerifiedMark({double size = 14})`: vòng tròn nền `ctaStart` (`3D63FF`), dấu ✓ trắng, không chữ, không viền. `Semantics(label: 'Đã xác minh')` + tooltip khi nhấn giữ. Đặt ngay sau tên và **nâng cao hơn tên một chút** (khoảng 3dp trên đường cơ sở, ngang chiều cao chữ hoa), cách tên 2dp; trong `Text.rich` dùng `WidgetSpan(alignment: PlaceholderAlignment.aboveBaseline)` kèm `Transform.translate(Offset(0, -2))`, trong `Row` bọc `Padding(bottom: 3)` hoặc `Align(alignment: Alignment.topCenter)` để không nằm giữa dòng. Chỉ cho `photographers.verified`. Dùng ở S02.02, S03.01, S02.06, S11.02, S12.03.

### BadgeChip · Mới
Huy hiệu dạng chip. `BadgeChip({required BadgeInfo badge, VoidCallback? onTap})`. Biểu tượng tròn 16dp tô `CtaSurface` + tên, nền kính, viền mảnh; một dòng, rộng theo nội dung. Hàng huy hiệu: tối đa 3 chip + "Tất cả" (`Wrap`, cuộn không cần). `Semantics(label: 'Huy hiệu {tên}')`. Khác `VerifiedMark` về màu (tím/gradient, không xanh dương). Dùng ở S03.01, S09.01, thẻ nhiếp ảnh gia (≤ 2).

### BadgeTile · Mới
Ô huy hiệu lớn. `BadgeTile({required BadgeInfo badge, BadgeProgress? progress, bool isNew = false, VoidCallback? onTap})`. Biểu tượng 36dp tô `CtaSurface` (đã đạt) hoặc xám (chưa đạt), tên (12 semibold), điều kiện (10,5), `CapacityBar` + "3 / 5" khi chưa đạt và là của mình; chấm "Mới" khi `isNew`. Lưới 2 cột. Dùng ở S03.02.

### StatusBadge · Đã có
Nhãn trạng thái booking (chữ hoa 10, radius 4, màu theo `BookingStatus`). Trạng thái vàng "Sắp tới" dùng chữ tối (`onColor`). Luôn kèm chữ. Dùng ở mọi `BookingCard`, timeline.

### PhotoCard · Mới
Ảnh nhiếp ảnh gia kèm lớp phủ. `PhotoCard({required String imageUrl, String? blurHash, required double aspect, String? title, String? subtitle, Widget? leadingPill, Widget? trailingPill, Widget? action, VoidCallback? onTap})`. Ảnh 4:5 hoặc 3:4, lớp phủ gradient đen chỉ ở đáy chứa chữ; pill trái = lịch rảnh ("Rảnh T7 này"), pill phải = gói + giá từ; không viền, không bóng. Ảnh dùng `cached_network_image` với blurhash và nút thử lại khi lỗi. Dùng ở S02.01, S02.03, S10.01, S03.01 (masonry).

### PhotographerCard · Mới
Thẻ so sánh. `PhotographerCard({required PhotographerSummary data, List<Reason> reasons = const [], required VoidCallback onProfile, VoidCallback? onBook, String? bookLabel})`. Ảnh hero 16:9 + pill rảnh; hàng avatar, tên + `VerifiedMark`, thể loại · khoảng cách · sao · số buổi, giá từ (cột phải); `ReasonChips` (≤ 2); hàng nút "Hồ sơ" (viền, cỡ nhỏ 38dp) + "Đặt {ngày}" (primary gradient, cỡ nhỏ 38dp, theo mock; ngoại lệ của quy tắc một nút chính mỗi màn). Hộp cùng cấp bằng chiều cao. Dùng ở S02.01, S02.06.

### ReasonChips · Mới
Lý do gợi ý. `ReasonChips({required List<Reason> reasons, int max = 2})`. Chip nhỏ nền kính, chữ 10,5, một dòng; dư thì bỏ bớt, không cuộn. `Semantics` đọc "Gợi ý vì: …". Mã lý do `skill_match`, `near`, `free_on_date`, `top_rated`, `fast_reply`, `new_talent`.

### BookingCard · Đã có
`BookingCard({required BookingSummary data, BookingCardSize size = normal, Widget? actions, bool highlight = false, VoidCallback? onTap})`. Thumb 56–64 (radius 12), tên + gói, ngày giờ (`tabularFigures`), địa điểm, `StatusBadge` bên phải. `size: compact` cho thanh ngữ cảnh chat và S04.04; `highlight` dùng `GlassCard(highlight: true)` cho buổi hôm nay. Khe `actions` đặt hàng nút dưới thẻ (Chỉ đường, Nhắn tin, Nhận…). Dùng ở S04.03, S05.02, S07.01, S05.01, S06.01, S04.04.

### EventCard và DateBlock · Mới
`EventCard({required EventSummary data, EventCardSize size = row, String? distanceLabel, VoidCallback? onTap})`. `size: row`: `DateBlock` bên trái, tên, "chủ · địa điểm", tag loại dạng chữ `#workshop` (màu primary, cỡ nhỏ, không nền/viền; cùng nhãn với hàng lọc S11.01), cột phải giá (hoặc `FreeTag` khi giá 0) + số chỗ ("Còn 3 chỗ" / "Hết chỗ" bằng chữ). `size: featured`: ảnh bìa 16:9 với pill ("1,2 km · Còn 6 chỗ") và lớp phủ chữ. `size: compact` (hàng ngang S02.03) rộng 176dp. `DateBlock({required DateTime day})` ô 46dp nền `primarySubtle`, số ngày Fraunces 20, tháng "T10" chữ hoa 9,5. Dùng ở S02.03, S11.01, S12.02 (xem trước), S12.03, S02.04.

### TicketCard · Mới
`TicketCard({required TicketData ticket, VoidCallback? onCancel, VoidCallback? onDirections, VoidCallback? onAddToCalendar})`. `GlassCard(highlight)` cho vé sắp diễn ra: tag loại, tên, ngày giờ · số vé, badge, **mã QR** 112dp trên nền trắng (`qr_flutter`, mã hoá `ticketCode`, sửa lỗi mức M), mã vé chọn‑copy, hàng nút; vé đã qua mờ và không QR. `Semantics` của QR: "Mã vé {code}". Dùng ở S11.04.

### StatusTimeline · Đã có
Dòng thời gian 7 bước của booking. `StatusTimeline({required List<TimelineStep> steps})`. Bước đã xong chấm xanh, bước hiện tại viền primary + quầng, bước tới chấm trống; đường nối dọc; mỗi bước có tên + dòng phụ (thời điểm, hướng dẫn). `Semantics`: "Bước 2 trong 7, đang diễn ra". Dùng ở S05.02.

### StatTile · Mới
Ô số liệu. `StatTile({required String value, required String label})`. Số Fraunces 22 `tabularFigures` ở trên, nhãn 10,5 một dòng bên dưới (`FittedBox(scaleDown)`), nền trong mờ `surfaceMuted`, viền mảnh, không mờ nền (ô nằm trong thẻ đã mờ). Hàng ô dùng `IntrinsicHeight` + `Expanded` để cùng một hàng và cùng chiều cao. Dùng ở S03.01 (thống kê), S06.01, S12.03. Nhãn màu `foregroundSecondary` (≥ 4,5:1).

### FreeTag và FreeBanner · Mới
Dùng khi sự kiện có `price == 0`. `FreeTag()` là tag nhỏ nền xanh nhạt (`successSubtle` ở sáng, xanh 20% ở tối), chữ xanh đậm (≥ 4,5:1), nhãn “Không thu phí”, đặt ở chỗ giá của `EventCard` (thay “0₫”). `FreeBanner({String? body})` là dải đầy chiều rộng dưới ảnh bìa ở S11.02: biểu tượng tích + “Không thu phí” (đậm) + dòng phụ “Đăng ký để giữ chỗ, không cần thanh toán”. Không chỉ dựa vào màu (luôn có chữ). Dùng ở S02.03, S11.01, S11.02, S12.02 (xem trước), S02.04; S11.03 và S12.03 xử lý riêng (bỏ cổng, doanh thu “—”).

### CapacityBar · Mới
`CapacityBar({required int used, required int total, String? label})`. Thanh gradient 6dp trên nền ô nhập; chữ "{used} / {total} đã đăng ký" luôn kèm; `Semantics(value)` theo chữ. Dùng ở S11.02, S12.03 và tiến độ huy hiệu (S03.02).

### CompletenessMeter · Mới
`CompletenessMeter({required int? percent, String? nextHint})`. Hàng tiêu đề + phần trăm, thanh gradient, dòng gợi ý việc kế tiếp. `percent` là số server ghi (`skills.completeness`); `null` (chưa tính) hiện "Chưa có điểm" và thanh rỗng. Dùng ở S08.02, S09.02, S06.02.

### AvailabilityCalendar · Mới
Lưới tháng 7 cột (T2…CN). `AvailabilityCalendar({required DateTime month, required Map<DateTime, DayState> states, DateTime? selected, ValueChanged<DateTime>? onSelect, ValueChanged<DateTime>? onLongPress, bool editable = false, ValueChanged<DateTime>? onMonthChanged, DateTime? minDate, DateTime? maxDate, DateTime? today, Set<DateTime> eventDays = const {}, DateTime? rangeStart, bool showHeader = true})`. `DayState`: `free` (mặc định), `pending` (viền đứt primary), `booked` (gạch ngang), `off` (nền mờ). Ngày chọn tô gradient; `pending/booked/off` không chọn được ở chế độ đặt (`editable: false`), `editable: true` cho NAG đổi `free ⇄ off`. Mỗi ô ≥ 44dp; ô có `Semantics` "12 tháng 10, rảnh". Điều hướng tháng bằng nút và vuốt; chọn dải: nhấn giữ ngày đầu (`onLongPress`, vòng `rangeStart`) rồi chạm ngày cuối. Giờ không nằm trong lưới. Dùng ở S02.06 (chọn ngày), S04.02, S06.04, S03.01 (tab Lịch). Ngày là ngày lịch (UTC 00:00, khoá `yyyy-MM-dd`). Ô cao 44dp, rộng bằng 1/7 hàng (≈ 41dp ở 320dp). Ô là hình chữ nhật bo góc theo mock (chọn = gradient, nghỉ = nền mờ, đã đặt = gạch ngang, chờ = viền đứt màu nhấn). `AvailabilityLegend` hiện bốn trạng thái kèm chữ, mỗi tên tô kiểu như trạng thái của nó. Đã có trong code (kế hoạch 2d1).

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
- API: `SignatureLoader({LoaderSize size = LoaderSize.screen, LoaderWave wave = LoaderWave.ripple, bool active = true, String? semanticsLabel})`; `enum LoaderSize { screen /*150*/, block /*96*/, inline /*56, không sóng; trong nút và hàng nhỏ*/ }`; `enum LoaderWave { ripple, vibration }`. `ApertureMark({double size, double closure, Color? color})` giữ nguyên là phần vẽ lá khẩu tĩnh.
- Lá khẩu: như cũ (logo đơn sắc `design-system/brand/logo-mono.svg`, 8 lá xoay quanh điểm neo trên vành, chu kỳ 2,4 s mở → khép, giữ khép 45–55%, `Curves.easeInOutCubic`). **Không nền màu** (sửa 2026-10-02, người dùng): không đĩa `CtaSurface`, không gradient, không bóng; lá khẩu và vòng viền mảnh **cùng màu với sóng** (sóng tròn: `primary`; sóng rung: cyan `focus`), trên nền trong suốt. Hình học hộp 100: vòng tròn bán kính 42; lá k, `t = k·45° − 90°`: điểm đầu = tâm + 10·hướng(t), điểm điều khiển = tâm + 33·hướng(t + 32°), điểm cuối = tâm + 42·hướng(t + 118°).
- Một `AnimationController` 2,4 s điều khiển lá khẩu và loại sóng đã chọn (một `CustomPainter`, `RepaintBoundary`, không blur). Chỉ chạy khi `active` và màn hiển thị (`TickerMode`); `active: false` dừng hẳn ticker.
- Sóng rung (chờ một bên khác) luôn đi kèm một dòng chữ nói đang chờ ai/cái gì và một lối thoát ("Kiểm tra lại", "Đổi cổng", "Huỷ"); không để màn chờ dài không giải thích (rà UX 2026-10-02).
- Giảm chuyển động (`MediaQuery.disableAnimations`): lá khẩu mở, một vòng tròn tĩnh mờ, không sóng; đọc `semanticsLabel` ("Đang tải", "Đang tìm", "Đang chờ thanh toán").
- Dùng: mọi trạng thái loading qua `AsyncView` (dưới); chờ cấp màn (splash, S04.04, S13.03, đăng bài, tạo sự kiện) dùng cỡ `screen`; khối/thẻ đang tải trong một màn đã có nội dung dùng `block`; nút đang gửi (`AppButton.loading`) và hàng nhỏ dùng `inline`. Danh sách và thẻ đang tải dùng skeleton của component (xem AppSkeleton); không dùng `CircularProgressIndicator` ở bất kỳ màn nào.
- Test: idle khi `active: false` và khi giảm chuyển động; đang chạy có đúng 1 ticker; mỗi loại sóng chỉ vẽ đúng loại của nó (ripple không có vòng gợn, vibration không có vòng tròn đều); golden 3 khung (đầu, giữa, cuối chu kỳ) ở sáng và tối cho hai loại sóng và ba cỡ; cỡ `inline` không vẽ sóng.

### AsyncView · Đã có (quyết định 2026-10-02)
Khung bắt buộc để màn hiển thị một `AsyncValue` (mọi fetch; luôn dùng sóng tròn). `AsyncView<T>({required AsyncValue<T> value, required Widget Function(BuildContext, T) data, LoaderSize loaderSize = LoaderSize.screen, String? loadingLabel, bool Function(T)? isEmpty, Widget Function(BuildContext)? empty, VoidCallback? onRetry, Widget Function(BuildContext, Object)? error, Widget Function(BuildContext)? skeleton})`.
- Lần tải đầu: nếu có `skeleton` (`Widget Function(BuildContext)? skeleton`, thường là skeleton của component sẽ hiện), dựng nó; nếu không, `SignatureLoader(size: loaderSize)` căn giữa vùng của nó. Tải lại khi đã có dữ liệu (`isRefreshing`/`isReloading`): giữ dữ liệu cũ, thêm `SignatureLoader(size: inline)` nhỏ ở góc trên (không che nội dung, không làm nhảy bố cục).
- Không nền riêng (sửa 2026-10-02, người dùng): AsyncView **dùng lại chính `SignatureLoader`** cho trạng thái tải khi không có skeleton; vùng loader đúng bằng vòng sóng ngoài cùng (150 hoặc 96, theo `loaderSize`), căn giữa, không bọc thêm hộp, thẻ, viền hay gradient. Lỗi và rỗng cũng nằm thẳng trên nền màn.
- Không nháy (rà UX 2026-10-02): lần tải đầu chờ 150 ms mới hiện skeleton/loader (dữ liệu từ cache về nhanh hơn thì hiện thẳng dữ liệu, vùng giữ nguyên kích thước); đã hiện thì giữ tối thiểu 400 ms rồi mới đổi sang dữ liệu, để không chớp.
- Lỗi: `ErrorState(message: errorMessage(e, l10n), onRetry: onRetry)`; có dữ liệu cũ thì giữ dữ liệu và hiện SnackBar lỗi một lần.
- Rỗng (`isEmpty` trả true): `empty` (thường là `EmptyState` có một hành động nuôi vòng lặp).
- Lint của repo (test kiểm mã nguồn `lib/features/**`): không có `CircularProgressIndicator` hay `.when(loading:` tự viết; màn dùng `AsyncView` (skeleton của component hoặc `SignatureLoader`).
- Test: bốn trạng thái; tải lại giữ dữ liệu; lỗi có dữ liệu cũ hiện SnackBar; `loaderSize` truyền đúng.

### StepProgress · Mới
`StepProgress({required int current, required int total, String? label, bool showCount = true})`. Thanh `total` đoạn, các đoạn tới `current` tô gradient; chữ "n / N" bên cạnh; `Semantics(value: 'Bước n trên N')`. Dùng ở S04.01–S04.03, S08.01, S12.01, S12.02, S08.05, S08.02. Theo mock (thành phần "Bước nhiều trang"), màn nhiều bước đặt "n / N" ở góc phải thanh tiêu đề và thanh tiến độ ngay dưới thanh tiêu đề, ngoài vùng cuộn: khi đó dùng `showCount: false` (S08.05).

### AppOptionTile · Mới
`AppOptionTile({required String label, required bool selected, required VoidCallback onTap, Widget? leading})`. Một lựa chọn trong danh sách chọn một (mock `.opt`): viền 1px `outline`, radius 16, nền kính không blur (dùng được trong danh sách dài), radio 18dp viền 2px; đã chọn = viền + chấm radio primary, nền `primarySubtle`. Cao ≥ 48dp; `Semantics(checked, inMutuallyExclusiveGroup, selected)`. Dùng ở S02.05 và S02.06 (các sheet dịch vụ, giá, đánh giá); sau này S04.02, S13.01.

### AppFooterBar · Mới
`AppFooterBar({required Widget child})`. Hàng nút dính đáy của màn biểu mẫu (mock `.foot`): nền `surface`, viền mảnh phía trên, đệm 10/16/12, có `SafeArea` dưới; đặt ngoài vùng cuộn. Màn nhiều bước: "Quay lại" `outline` rộng 36% + nút chính. Dùng ở S08.05, S09.03.

### SectionHeader · Đã có
`SectionHeader({required String title, String? actionLabel, VoidCallback? onAction, String? trailing})`. Tiêu đề Fraunces 17 + hành động chữ primary 12 bên phải (≥ 48dp vùng chạm). `Semantics(header)`. Dùng khắp nơi cho "Xem tất cả", "Tất cả".

### EmptyState · Đã có
Minh hoạ tròn, tiêu đề, mô tả, một nút `AppButton.primary` (tuỳ chọn). Mọi trạng thái trống có đúng một hành động nuôi vòng lặp (xem S06.02, S02.03…).

### ErrorState và OfflineBanner · Đã có
`ErrorState({required String message, VoidCallback? onRetry})` tiêu đề ngắn + "Thử lại". `OfflineBanner()` dải mảnh "Đang xem dữ liệu đã lưu" trên đầu danh sách khi offline. Thông điệp lấy từ ánh xạ mã lỗi → tiếng Việt (`errorMessage(Object, AppLocalizations)`). Dùng ở mọi màn có dữ liệu mạng.

### AppSkeleton và skeleton của từng component · Đã có (quyết định 2026-10-02)
Mỗi component hiển thị dữ liệu có **biến thể skeleton riêng** đúng hình khối của nó: `PhotoCard.skeleton()`, `PhotographerCard.skeleton()`, `BookingCard.skeleton({BookingCardSize size})`, `EventCard.skeleton()`, `TicketCard.skeleton()`, `ConversationRow.skeleton()`, `NotificationRow.skeleton()`, `StatTile.skeleton()`, `StatusTimeline.skeleton()`, `MoneyBreakdown.skeleton({int lines})`, `AvailabilityCalendar.skeleton()`, `AppAvatar.skeleton()`, `ReasonChips.skeleton()`, `BadgeChip.skeleton()`, `ChatBubble.skeleton({bool mine})`, `CapacityBar.skeleton()`, `CompletenessMeter.skeleton()`… Các khối dựng từ primitive `AppSkeleton.box({w, h, radius})`, `.line({w})`, `.circle({size})`, cùng radius, khoảng cách và chiều cao với component thật nên bố cục không nhảy khi dữ liệu về.
- Nhận diện (sửa 2026-10-02, người dùng): **chỉ màu trắng, không nhiều màu, kể cả theme tối**. Khối trắng độ mờ thấp ở theme tối (trắng 8%); ở theme sáng khối **xám nhạt trung tính** `#E6E3DE` (không pha màu); dải sáng trắng (tối: trắng 14%; sáng: trắng 85%) quét chéo 1,6 s; không gradient aurora, không cyan/tím/hồng; chung một `AnimationController` cho cả màn (`SkeletonScope`); giảm chuyển động thì đứng yên, không quét.
- Đọc màn hình: một nhãn "Đang tải" cho cả nhóm skeleton (`Semantics(liveRegion)`), từng khối `ExcludeSemantics`.
- Quy tắc: danh sách, lưới và thẻ đang tải dùng skeleton của chính component đó (số khối bằng số mục thường thấy trên một màn, ví dụ 3 `BookingCard`); chờ cấp màn không có hình khối biết trước (splash, mở thanh toán, chờ nhiếp ảnh gia trả lời) dùng `SignatureLoader`. Không dùng `CircularProgressIndicator`.
- Test mỗi skeleton: cùng kích thước với component thật ở 390dp và 320dp (so `tester.getSize`), golden sáng/tối, không ticker khi giảm chuyển động.

### NotificationRow · Mới
Dòng trong hộp thư S17.01. `NotificationRow({required NotificationItem item, required VoidCallback onTap, required VoidCallback onMore})`. Bố cục: chấm tím chưa đọc (bên trái) · biểu tượng loại trong vòng tròn tô nhạt (một biểu tượng cho mỗi `type`, tông theo ngữ nghĩa) · tiêu đề đậm + nội dung tối đa 2 dòng · thời gian tương đối ("5 phút") · thumbnail 40dp tuỳ chọn. Dòng gom (`groupKey`) hiện tiêu đề đã gộp ("3 nhiếp ảnh gia đã báo giá…") và tối đa 3 avatar nhỏ. `Semantics`: nhãn gộp "Chưa đọc. {tiêu đề}. {nội dung}. {thời gian}" (chưa đọc không chỉ là màu); nhấn giữ hoặc hành động ngữ nghĩa `customActions` mở menu "Đánh dấu đã đọc / Tắt loại thông báo này", nên không có thao tác chỉ vuốt. Vùng chạm cả dòng ≥ 48dp. Dùng ở S17.01.

### NotificationBell · Mới
Biểu tượng chuông có chấm số cho thanh đầu trang S02.01, S02.03, S06.01. `NotificationBell({required int unread, required VoidCallback onTap})`: chuông 36dp (vùng chạm 48dp), chấm số đỏ, "9+" từ mười trở lên, ẩn khi 0. `Semantics.label` theo ngữ cảnh: 0 → "Thông báo", n → "{n} thông báo chưa đọc" (đọc cả cụm, không đọc số trần). `unread` đọc từ `users/{uid}.unreadCount` qua `unreadCountProvider` (không lắng nghe danh sách). Khác `TabBadge` ở chỗ nhãn ngữ nghĩa mang nội dung "thông báo".

### PermissionPrimer · Mới
Nội dung sheet S17.03, bọc trong `AppBottomSheet`. `PermissionPrimer({required String title, required String benefit, required VoidCallback onEnable, required VoidCallback onLater})`. Biểu tượng chuông, tiêu đề theo ngữ cảnh ("Bật thông báo để biết khi Minh Trí nhận lịch"), một dòng lợi ích, nút chính `AppButton.primary` "Bật thông báo" (gọi hộp thoại quyền của hệ điều hành), nút phụ "Để sau". "Để sau" ghi thời điểm; `PermissionPrimerPolicy` chặn hỏi lại trong 7 ngày và không bao giờ hỏi khi mở app. Không chứa logic quyền (controller của S17.03 gọi `NotificationPermissionPort`).

### TabBadge · Đã có
Chấm số trên icon thanh tab. `TabBadge({required int count, required Widget child})`: ẩn khi 0, "9+" từ mười trở lên, nền `error`, `Semantics.value` "{n} mục mới". Số lấy từ `tabBadgesProvider`. Dùng cho Công việc (yêu cầu chờ) và Khám phá (sự kiện mới).

---

### Component rút ra từ mock (phân tích UI 2026-10-02)

Các mẫu dưới đây lặp lại ở nhiều màn trong mock nhưng chưa có đặc tả. Viết thành widget dùng chung trước khi làm màn (thứ tự ở mục 7).

#### EscrowNotice · Đã có
`EscrowNotice({required String text})`: biểu tượng khoá + chữ trên nền `primarySubtle` (lớp `.esc` của mock), `Semantics(container)`. Chữ theo spec chính 3g.6: khách "Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành."; nhiếp ảnh gia "Cọc {số tiền} đang được giữ, chuyển cho bạn sau khi hoàn thành". Dùng ở S04.03, S05.02, S11.03, S11.04, S06.05, S13.01, S13.07.

#### MoneyBreakdown · Đã có
`MoneyBreakdown({required List<MoneyLine> lines})`, `MoneyLine({required String label, required int vnd, MoneyLineStyle style = normal /*normal | strong | muted*/})`. Các hàng nhãn trái, số phải `tabularFigures`, định dạng `formatMoney`; hàng `strong` đậm (cọc hôm nay, tổng thanh toán), `muted` chữ phụ (còn lại trả tại buổi chụp). Dùng ở S04.03 (giá gói, cọc 30%, còn lại), S11.03 (số vé × giá, tổng), S06.05 (các khoản), S13.08 (hoàn, phí).

#### PolicyTable · Đã có
`PolicyTable({required List<PolicyRow> rows, required int activeIndex})`, `PolicyRow({required String when, required String outcome})`. Các hàng chọn đơn không bấm được, hàng đang áp dụng tô `AppOptionTile` đã chọn; đọc màn hình "Đang áp dụng: …". Dùng ở S05.03 (huỷ ≥ 48 giờ 100% · 24–48 giờ 50% · < 24 giờ 0%), S13.08 (mốc huỷ chụp ngay).

#### ReasonPicker · Đã có
`ReasonPicker({required List<String> reasons, required int? selected, required ValueChanged<int> onSelected, ReasonPickerStyle style = chips /*chips | radio*/, String? otherLabel, ValueChanged<String>? onOtherText, int otherMinLength = 0, int otherMaxLength = 200})`. Kiểu `chips` (S05.03 huỷ, S13.08) hoặc `radio` (S06.03 từ chối) dùng `AppOptionTile`; chọn "Lý do khác" hiện ô nhập ngắn có đếm, kiểm độ dài tối thiểu.

#### ProviderPicker · Đã có
`ProviderPicker({required PaymentProviderCode value, required ValueChanged<PaymentProviderCode> onChanged})`: hai nút viền nhỏ MoMo / VNPay chọn đơn (mock S04.03, S11.03). Một chỗ duy nhất đổi khi thêm cổng.

#### ConfirmSheet · Đã có
`Future<bool> showConfirmSheet(BuildContext, {required String title, String? body, Widget? content, required String confirmLabel, required String keepLabel, bool danger = true, Future<void> Function()? onConfirm})`: sheet xác nhận chuẩn, nút an toàn (viền) bên trái, nút xác nhận (đỏ khi `danger`) bên phải, đang chạy `onConfirm` thì nút xác nhận hiện `SignatureLoader(inline)` và khoá sheet; lỗi hiện SnackBar trong sheet. Quy tắc CLAUDE.md "huỷ/từ chối là nút đỏ trong sheet xác nhận" đi qua widget này. Dùng ở S05.03, S06.03, S12.03 (huỷ sự kiện), S13.08, S09.02 (đăng xuất), S04.01 (bỏ yêu cầu đặt lịch).

#### CountdownRing và CountdownText · Đã có
`CountdownRing({required DateTime deadline, required Duration total, double size = 96})`: vòng tiến độ + số lớn ở giữa và đơn vị nhỏ (mock `.cd`), cập nhật mỗi giây khi còn < 1 giờ, mỗi phút khi dài hơn; `Semantics(role: timer)` đọc "Còn {n} giây"; giảm chuyển động: vòng nhảy theo giây, không nội suy. `CountdownText` cùng logic cho chữ trong nút ("Nhận · còn 22 giờ"). Dùng ở S14.02 (60 giây), S13.03, S13.06 (thời gian buổi chụp), S06.01 (hạn nhận yêu cầu).

#### ChatBubble, ChatComposer, ConversationRow · Đã có
`ChatBubble({required ChatBubbleContent content, required bool mine, BubbleSendState state = sent, String? senderName, VoidCallback? onRetry})`: của mình gradient bên phải, người kia kính bên trái, ảnh, vị trí, tin hệ thống ở giữa; `sending` mờ + đồng hồ, `failed` có "Gửi lại". `ChatComposer({required ValueChanged<String> onSend, VoidCallback? onPickImage, bool enabled = true, String? disabledReason})`: nút ảnh, ô tin bo tròn, nút gửi gradient; không gửi tin rỗng. `ConversationRow({required String name, String? avatarUrl, required String preview, required String timeLabel, int unread = 0, Widget? badge, VoidCallback? onTap})` (mock S07.02). Dùng ở S07.01, S07.02, S11.06.

#### SwipeDeck và MatchOverlay · Mới
`SwipeDeck<T>({required List<T> items, required Widget Function(BuildContext, T) cardBuilder, required ValueChanged<T> onLike, required ValueChanged<T> onSkip, VoidCallback? onUndo, VoidCallback? onEmpty})`: chồng thẻ (3 thẻ hiện, thẻ sau thu nhỏ và mờ), vuốt phải/trái có dấu "CHỌN", nút Hoàn tác / ✕ / ♥ luôn có (≥ 48dp, nhãn đọc màn hình), giảm chuyển động thì thẻ đổi tức thì. `MatchOverlay({required String name, String? myAvatar, String? theirAvatar, required VoidCallback onContinue})`: **một nét liền vẽ chiếc máy ảnh** (continuous line art, theo hình người dùng đưa 2026-10-02; không trái tim, không icon tròn): `CustomPainter` vẽ path thân máy + ống kính xoáy vào tâm bằng `PathMetric.extractPath` theo tiến độ (0–1,8 s, `Curves.easeInOutCubic`), nét `onSurface` dày 4 (theo hộp 420×250), đầu/khớp tròn; hai nút chụp vẽ tiếp (1,5–1,95 s); vệt màu `primary` 16% sau ống kính hiện dần (1,2–2,1 s); ống kính "chớp" một vòng sáng `primary` nở 0,55→1,35 và mờ (1,75–2,45 s, kèm `HapticFeedback.lightImpact`); hai avatar 40dp **đáp vào giữa ống kính** (phóng 0,6→1, lò xo nhẹ, lệch 100 ms): hai người cùng lọt khung. Rồi "Đã match với {tên}" và dòng phụ hiện lên (2,1 s). Rộng `min(240dp, 78%)`, tỉ lệ 420:250. Tự sang màn kế sau khoảng 3 giây; nút "Tiếp tục" luôn có; chạm bất kỳ đâu bỏ qua hiệu ứng (nhảy tới khung cuối). Giảm chuyển động: hiện ngay khung cuối, không chớp, không rung. `Semantics(label: 'Đã match với {tên}', liveRegion)`. Path gốc ở `docs/design/ui-mock.html` (`.mcam`). Dùng ở S13.02, S13.04 (và S14.03 phía nhiếp ảnh gia).

#### OfferStack · Mới
`OfferStack({required List<Widget> offers})`: chồng tối đa 3 thẻ lời mời, thẻ trên đầy đủ, hai mép thẻ sau lộ ra phía trên (mock S14.02).

#### MapPreview · Mới (làm cùng kế hoạch I5)
Bản đồ nhỏ có ghim nhãn chữ và nút "Về vị trí của tôi" (mock S13.01, S13.05, S14.03). Đặc tả chi tiết đi theo spec Chụp ngay mục 9; ở đây chỉ giữ chỗ để màn dùng chung một widget.


## 5. Công cụ không phải widget

### Định dạng · Mới
`formatMoney(int vnd, {bool short = false})` → `1.500.000₫` hoặc `1,5M`; `eventPriceLabel(int vnd)` → `250.000₫` hoặc, khi 0, **“Không thu phí”** (không bao giờ “0₫”); `formatDay(DateTime)` → `T7 12/10`; `formatTimeRange(start, end)` → `15:30–17:30`; `formatDistance(double km)` → `1,2 km`. Có test đơn vị với múi giờ Asia/Ho_Chi_Minh.

### ContactLauncher · Mới
`ContactLauncher.open(ContactChannel, {required ContactSubject subject})` (trả `ContactOpenResult`: `opened | locked | unavailable | cannotLaunch`) xin URL từ `ContactLinkRepository.link(...)` (gọi hàm callable `getContactLink`, lỗi `contact_locked` nếu chưa mở khoá) rồi mở bằng `url_launcher` (`LaunchMode.externalApplication`); `canOpen(channel)` kiểm `canLaunchUrl` để ẩn kênh không dùng được. Số không bao giờ nằm trong ứng dụng ngoài khoảnh khắc mở URL; không ghi vào log hay phân tích. Có bản giả trong test. Chỉ mở URL đúng dạng `tel:+…`, `https://zalo.me/<số>`, `https://wa.me/<số>` (không query, cổng, user info); URL khác bị từ chối.

### RecommendationRepository · Mới
Giao diện gợi ý (spec chính 3e): `recommendPhotographers(RecommendationQuery) → RecommendationPage`, `similar(photographerId)`, `recommendPosts(...)`, `sendFeedback(List<RecommendationSignal>)`. Cài đặt `RemoteRecommendationRepository` (gọi hàm callable `recommend`, hạn 800 ms) và `LocalRecommender` (sao đã làm mượt + khoảng cách; dự phòng và test). Hai bản qua cùng bộ test hợp đồng.

### LocationRepository · Mới
`currentApproxLocation()` (độ chính xác thấp, hạn 8 giây), `permissionStatus()`, `request()`, `openSettings()`. Trả `geohash` thay vì toạ độ cho phần gửi mạng. Bản giả cho test.

---

## 6. Bảng tra: widget ↔ màn

| Widget | Màn |
|--------|-----|
| `CtaSurface`/`AppButton` | mọi màn có nút chính, đĩa tab giữa |
| `AppChip`, `SegmentedTabs` | S02.01, S03.01, S02.06, S04.02, S05.01, S11.01, S11.04, S06.01, S10.01, S12.01, S09.01, S09.02, S02.04 |
| `PhotoCard` | S02.01, S03.01, S02.03, S10.01 |
| `PhotographerCard`, `ReasonChips` | S02.01, S02.06 |
| `BookingCard` | S04.03, S04.04, S05.02, S07.01, S05.01, S06.01 |
| `EventCard`, `DateBlock` | S02.03, S11.01, S12.02, S12.03, S02.04 |
| `TicketCard` | S11.04 |
| `AppBottomSheet` | S04.01–S04.03, S05.03, S11.03, S06.03, S04.05, S02.05, S08.04 |
| `StepProgress` | S04.01–S04.03, S08.01, S12.01, S12.02, S08.05, S08.02 |
| `AppFooterBar` | S08.05, S09.03 |
| `AppOptionTile` | S02.05, S02.06 (sau: S04.02, S13.01) |
| `AvailabilityCalendar` | S03.01, S02.06, S04.02, S06.04 |
| `StatusTimeline` | S05.02 |
| `CapacityBar`, `StatTile` | S03.01, S11.02, S06.01, S12.03, S03.02 |
| `ContactDial`, `ContactLauncher` | S03.01, S05.02, S11.02, S06.01, S12.03 (S05.04) |
| `PhoneField` | S04.03, S11.03, S04.05, S08.05, S09.03 |
| `LocationPromptCard`, `LocationRepository` | S02.03, S02.04, S02.05 |
| `VerifiedMark`, `BadgeChip`, `BadgeTile` | S02.02, S03.01, S02.06, S11.02, S12.03, S09.01, S03.02 |
| `SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter` | S06.02, S09.02, S08.02, S08.03, S08.04 |
| `TabBadge` | thanh tab dưới |
| `NotificationRow` | S17.01 |
| `NotificationBell` | S02.01, S02.03, S06.01 |
| `PermissionPrimer` | S17.03 |
| `SignatureLoader`, `AsyncView` | mọi màn có tải dữ liệu |
| `EscrowNotice` | S04.03, S05.02, S11.03, S11.04, S06.05, S13.01, S13.07 |
| `MoneyBreakdown` | S04.03, S11.03, S06.05, S13.08 |
| `PolicyTable` | S05.03, S13.08 |
| `ReasonPicker` | S05.03, S06.03, S13.08 |
| `ProviderPicker` | S04.03, S04.04, S11.03 |
| `ConfirmSheet` | S04.01, S05.03, S06.03, S09.02, S12.03, S13.08 |
| `CountdownRing`, `CountdownText` | S06.01, S13.03, S13.06, S14.02 |
| `ChatBubble`, `ChatComposer`, `ConversationRow` | S07.01, S07.02, S11.06 |
| `SwipeDeck`, `MatchOverlay` | S13.02, S13.04, S14.03 |
| `OfferStack` | S14.02 |
| `MapPreview` | S13.01, S13.05, S13.08, S14.03 |
| `ScreenCode` | mọi màn |

## 7. Thứ tự viết (đổi ngày 2026-10-02: component trước, màn sau)

Người dùng quyết định: phân tích UI, thiết kế và viết các shared component **trước** khi làm tiếp các màn, để các kế hoạch màn chỉ ghép component. Đã có trong code: mục 1–4 có nhãn "Đã có" và các widget trong `lib/core/widgets/`.

1. **Nhóm A** (kế hoạch `2026-10-02-shared-components-a.md`, **đã xong**): `SignatureLoader` + `AsyncView` (và chuyển mọi màn hiện có sang dùng chúng, bỏ spinner), skeleton cho từng component đã có (`AppSkeleton` + `SkeletonScope` + `.skeleton()` của mỗi component), `SectionHeader`, `OfflineBanner`, `EscrowNotice`, `MoneyBreakdown`, `PolicyTable`, `ReasonPicker`, `ProviderPicker`, `ConfirmSheet`, `CountdownRing`/`CountdownText`, `BookingCard`, `StatusTimeline`, `ChatBubble`, `ChatComposer`, `ConversationRow`.
2. **Nhóm B** (trước sự kiện, Chụp ngay, thông báo; kế hoạch riêng khi tới lượt): `EventCard`/`DateBlock`, `TicketCard` (QR), `BadgeChip`/`BadgeTile`, `NotificationRow`, `NotificationBell`, `PermissionPrimer`, `SwipeDeck`, `MatchOverlay`, `OfferStack`, `MapPreview`.
