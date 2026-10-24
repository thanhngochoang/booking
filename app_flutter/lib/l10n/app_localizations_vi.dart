// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'Cộng đồng nhiếp ảnh gia';

  @override
  String get loadingLabel => 'Đang tải';

  @override
  String tabBadgeCount(int count) {
    return '$count mục mới';
  }

  @override
  String get tabHome => 'Trang chủ';

  @override
  String get tabExplore => 'Khám phá';

  @override
  String get tabFind => 'Tìm thợ ảnh';

  @override
  String get tabCreate => 'Đăng bài';

  @override
  String get tabBookings => 'Đặt lịch';

  @override
  String get tabWork => 'Công việc';

  @override
  String get tabProfile => 'Hồ sơ';

  @override
  String get loginTitle => 'Đăng nhập';

  @override
  String get registerTitle => 'Tạo tài khoản';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Mật khẩu';

  @override
  String get passwordConfirmLabel => 'Nhập lại mật khẩu';

  @override
  String get displayNameLabel => 'Tên hiển thị';

  @override
  String get loginButton => 'Đăng nhập';

  @override
  String get loginHeadlineLead => 'Bắt trọn';

  @override
  String get loginHeadlineAccent => 'mọi khoảnh khắc';

  @override
  String get loginTagline => 'Tìm thợ ảnh hợp gu, đặt lịch chỉ vài chạm.';

  @override
  String get loginWelcome => 'Chào bạn!';

  @override
  String get loginWelcomeBody => 'Đăng nhập để tiếp tục';

  @override
  String get socialGoogle => 'Google';

  @override
  String get socialFacebook => 'Facebook';

  @override
  String get loginOrDivider => 'hoặc';

  @override
  String get noAccountPrompt => 'Chưa có tài khoản?';

  @override
  String get registerLink => 'Đăng ký';

  @override
  String get showPassword => 'Hiện mật khẩu';

  @override
  String get hidePassword => 'Ẩn mật khẩu';

  @override
  String get registerButton => 'Đăng ký';

  @override
  String get continueWithGoogle => 'Tiếp tục với Google';

  @override
  String get continueWithFacebook => 'Tiếp tục với Facebook';

  @override
  String get haveAccountPrompt => 'Đã có tài khoản?';

  @override
  String get registerHeadlineLead => 'Tham gia';

  @override
  String get registerHeadlineAccent => 'cộng đồng ảnh';

  @override
  String get registerTagline => 'Kết nối thợ ảnh, lưu giữ khoảnh khắc.';

  @override
  String get registerWelcomeBody => 'Điền vài thông tin để bắt đầu';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get errorEmailInvalid => 'Email không hợp lệ.';

  @override
  String get errorPasswordShort => 'Mật khẩu cần ít nhất 8 ký tự.';

  @override
  String get errorPasswordMismatch => 'Mật khẩu nhập lại không khớp.';

  @override
  String get errorNameEmpty => 'Vui lòng nhập tên hiển thị.';

  @override
  String get authErrorWrongPassword => 'Email hoặc mật khẩu không đúng.';

  @override
  String get authErrorUserNotFound => 'Không tìm thấy tài khoản với email này.';

  @override
  String get authErrorEmailInUse => 'Email này đã được dùng. Hãy đăng nhập.';

  @override
  String get authErrorWeakPassword => 'Mật khẩu quá yếu. Dùng ít nhất 8 ký tự.';

  @override
  String get authErrorNetwork => 'Không có kết nối. Kiểm tra mạng rồi thử lại.';

  @override
  String get authErrorUnknown => 'Đăng nhập không thành công. Thử lại sau.';

  @override
  String get roleTitle => 'Bạn muốn làm gì?';

  @override
  String get roleCustomerTitle => 'Thuê nhiếp ảnh gia';

  @override
  String get roleCustomerBody =>
      'Khám phá ảnh đẹp, đặt lịch chụp trong vài chạm.';

  @override
  String get rolePhotographerTitle => 'Nhận chụp';

  @override
  String get rolePhotographerBody =>
      'Đăng ảnh, nhận yêu cầu, quản lý lịch và doanh thu.';

  @override
  String get roleContinue => 'Tiếp tục';

  @override
  String get emptyExploreTitle => 'Khám phá theo dịch vụ và địa điểm';

  @override
  String get emptyExploreBody =>
      'Chân dung, cưới, gia đình, kỷ yếu và hơn thế.';

  @override
  String get emptyBookingsTitle => 'Buổi chụp tiếp theo bắt đầu từ đây';

  @override
  String get emptyBookingsBody => 'Yêu cầu và lịch chụp của bạn sẽ hiện ở đây.';

  @override
  String get emptyWorkTitle => 'Chưa có yêu cầu nào';

  @override
  String get emptyWorkBody => 'Hoàn thiện hồ sơ và đăng ảnh để được tìm thấy.';

  @override
  String get profileRoleCustomer => 'Khách hàng';

  @override
  String get profileRolePhotographer => 'Nhiếp ảnh gia';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsAccount => 'Tài khoản';

  @override
  String get settingsEditProfile => 'Chỉnh sửa hồ sơ';

  @override
  String get settingsEditProfileBody => 'Tên hiển thị';

  @override
  String get settingsPhone => 'Số điện thoại';

  @override
  String get settingsPhoneEmpty => 'Chưa thêm';

  @override
  String get settingsPhoneAdded => 'Đã thêm';

  @override
  String settingsPhoneMasked(String last4) {
    return '•••• $last4';
  }

  @override
  String get settingsSkills => 'Kỹ năng';

  @override
  String get settingsSkillsBody => 'Thể loại, mức độ và phong cách';

  @override
  String get settingsPublicProfile => 'Xem hồ sơ công khai';

  @override
  String get settingsPublicProfileBody => 'Hồ sơ như khách nhìn thấy';

  @override
  String get settingsAppearance => 'Giao diện';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeSystem => 'Theo hệ thống';

  @override
  String get settingsButtonStyle => 'Kiểu nút chính';

  @override
  String get buttonStyleGradient => 'Gradient theo giao diện';

  @override
  String get buttonStyleAvatar => 'Ảnh đại diện làm mờ';

  @override
  String get buttonStyleAvatarNeedsPhoto =>
      'Thêm ảnh đại diện trong hồ sơ để dùng kiểu này.';

  @override
  String get settingsButtonPreview => 'Xem trước nút';

  @override
  String get settingsMode => 'Chế độ';

  @override
  String get settingsButtonGradientShort => 'Gradient';

  @override
  String get settingsStudioAddress => 'Địa chỉ studio';

  @override
  String get settingsStudioAddressEmpty => 'Chưa có địa chỉ';

  @override
  String get settingsVerify => 'Xác minh & nhận đơn';

  @override
  String get settingsVerifyBody => 'Xác minh danh tính để bắt đầu nhận đơn';

  @override
  String get settingsMyStudio => 'Studio của tôi';

  @override
  String get settingsMyStudioBody => 'Studio đang ở, việc được giao, lời mời';

  @override
  String get settingsStudioMembers => 'Thành viên studio';

  @override
  String get settingsStudioMembersBody => 'Mời thợ, giao việc cho thành viên';

  @override
  String get settingsDeveloper => 'Dành cho nhà phát triển';

  @override
  String get settingsShowScreenCodes => 'Hiện mã màn hình';

  @override
  String get settingsShowScreenCodesBody =>
      'Nhãn Sxx ở góc trên trái mỗi màn, để gọi tên màn khi cần chỉnh sửa.';

  @override
  String get editProfileTitle => 'Chỉnh sửa hồ sơ';

  @override
  String get editProfileSave => 'Lưu';

  @override
  String get editProfileSaved => 'Đã lưu hồ sơ.';

  @override
  String get editProfileError =>
      'Không lưu được hồ sơ. Kiểm tra mạng rồi thử lại.';

  @override
  String get editProfileChangeAvatar => 'Đổi ảnh đại diện';

  @override
  String get editProfileAvatarSaved => 'Đã đổi ảnh đại diện.';

  @override
  String get editProfileAvatarError => 'Không đổi được ảnh. Thử lại nhé.';

  @override
  String get profileOfferPhotographerTitle => 'Tôi là nhiếp ảnh gia';

  @override
  String get profileOfferPhotographerBody =>
      'Đăng ảnh, nhận booking và quản lý lịch. Bạn vẫn đổi lại được bất cứ lúc nào.';

  @override
  String get profileOfferCustomerTitle => 'Tôi cần đặt lịch';

  @override
  String get profileOfferCustomerBody =>
      'Tìm nhiếp ảnh gia, đặt lịch và nhắn tin. Bạn vẫn đổi lại được bất cứ lúc nào.';

  @override
  String get profileSwitchToCustomer => 'Chuyển qua chế độ đặt lịch';

  @override
  String get profileSwitchToPhotographer => 'Chuyển qua chế độ nhiếp ảnh';

  @override
  String get profileSwitchedToCustomer => 'Đã chuyển qua chế độ đặt lịch.';

  @override
  String get profileSwitchedToPhotographer => 'Đã chuyển qua chế độ nhiếp ảnh.';

  @override
  String get profileSetupTitle => 'Hoàn thiện hồ sơ nhiếp ảnh gia';

  @override
  String get profileSetupBody =>
      'Còn vài bước nữa để khách tìm thấy và đặt lịch với bạn.';

  @override
  String get profileSetupContinue => 'Tiếp tục thiết lập';

  @override
  String get profileSwitchError =>
      'Không đổi được chế độ. Kiểm tra mạng rồi thử lại.';

  @override
  String get profilePostsCount => 'bài đăng';

  @override
  String get profileFollowingCount => 'đang theo dõi';

  @override
  String get profileSavedCount => 'đã lưu';

  @override
  String profileFilterAll(int n) {
    return 'Tất cả · $n';
  }

  @override
  String profileFilterWork(int n) {
    return 'Tác phẩm · $n';
  }

  @override
  String profileFilterRealShoot(int n) {
    return 'Buổi chụp · $n';
  }

  @override
  String profileFilterEventShare(int n) {
    return 'Sự kiện · $n';
  }

  @override
  String get profileTagRealShoot => 'Buổi chụp';

  @override
  String get profileTagEventShare => 'Sự kiện';

  @override
  String get profileEmptyPhotographerTitle => 'Chưa có bài đăng';

  @override
  String get profileEmptyPhotographerAction => 'Đăng bài đầu tiên';

  @override
  String get profileEmptyCustomerTitle => 'Chưa có ảnh nào';

  @override
  String get profileEmptyCustomerBody =>
      'Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây';

  @override
  String get profilePostsError => 'Không tải được bài đăng.';

  @override
  String get profilePostsMoreError => 'Không tải thêm được. Thử lại';

  @override
  String profilePostTile(int n) {
    return 'Bài đăng $n';
  }

  @override
  String get statusRequested => 'Đã gửi';

  @override
  String get statusAccepted => 'Đã nhận';

  @override
  String get statusDeclined => 'Từ chối';

  @override
  String get statusExpired => 'Hết hạn';

  @override
  String get statusCancelled => 'Đã huỷ';

  @override
  String get statusUpcoming => 'Sắp tới';

  @override
  String get statusShot => 'Chờ bàn giao';

  @override
  String get statusDelivered => 'Chờ duyệt ảnh';

  @override
  String get statusRevisionRequested => 'Cần chỉnh sửa';

  @override
  String get statusApproved => 'Đã đồng ý ảnh';

  @override
  String get statusCompleted => 'Hoàn thành';

  @override
  String get statusReviewed => 'Đã đánh giá';

  @override
  String get sessionErrorTitle => 'Không tải được tài khoản';

  @override
  String get sessionErrorBody =>
      'Kiểm tra kết nối mạng rồi thử lại. Nếu vẫn lỗi, hãy đăng xuất và đăng nhập lại.';

  @override
  String get retry => 'Thử lại';

  @override
  String get roleSaveError =>
      'Không lưu được lựa chọn. Kiểm tra mạng rồi thử lại.';

  @override
  String get verifiedLabel => 'Đã xác minh';

  @override
  String get freeTag => 'Không thu phí';

  @override
  String get freeBannerBody => 'Đăng ký để giữ chỗ, không cần thanh toán';

  @override
  String capacityUsed(int used, int total) {
    return '$used / $total đã đăng ký';
  }

  @override
  String stepProgressCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String stepProgressSemantics(int current, int total) {
    return 'Bước $current trên $total';
  }

  @override
  String get phoneLabel => 'Số điện thoại';

  @override
  String get phoneCodeLabel => 'Mã';

  @override
  String get phoneCodeSemantics => 'Mã +84';

  @override
  String get phoneRequired => 'Nhập số điện thoại';

  @override
  String get phoneInvalid => 'Số điện thoại chưa đúng. Ví dụ: 903 123 456';

  @override
  String get phoneInvalidInternational =>
      'Nhập số có mã quốc gia, ví dụ: +1 415 555 2671';

  @override
  String get addPhoneTitle => 'Thêm số điện thoại để đặt lịch';

  @override
  String get addPhoneBody =>
      'Nhiếp ảnh gia sẽ gọi hoặc nhắn Zalo/WhatsApp cho bạn để chốt chi tiết.';

  @override
  String get addPhoneExample =>
      'Ví dụ: 0903 123 456. Chưa cần mã xác minh; bước xác minh sẽ bổ sung sau.';

  @override
  String get allowZaloLabel => 'Cho phép liên hệ qua Zalo';

  @override
  String get allowWhatsAppLabel => 'Cho phép liên hệ qua WhatsApp';

  @override
  String get phonePrivacy =>
      'Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán.';

  @override
  String get editProfilePhoneHint =>
      'Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán.';

  @override
  String get addPhoneSave => 'Lưu và tiếp tục';

  @override
  String get phoneSaveError => 'Không lưu được số điện thoại. Thử lại nhé.';

  @override
  String get contactLabel => 'Liên hệ';

  @override
  String get contactCall => 'Gọi điện';

  @override
  String get contactCallShort => 'Gọi';

  @override
  String get contactZalo => 'Zalo';

  @override
  String get contactWhatsApp => 'WhatsApp';

  @override
  String get contactInquiry => 'Nhắn tin hỏi trước';

  @override
  String get contactOpening => 'Đang mở liên hệ';

  @override
  String get contactLockedHint =>
      'Liên hệ qua điện thoại mở sau khi bạn đặt lịch';

  @override
  String get contactOpenError => 'Không mở được liên hệ. Thử lại nhé.';

  @override
  String get setupFlowTitle => 'Hồ sơ nhiếp ảnh gia';

  @override
  String get setupContactTitle => 'Khu vực và liên hệ';

  @override
  String get setupContactArea => 'Khu vực phục vụ';

  @override
  String get setupContactCity => 'Thành phố';

  @override
  String get setupContactRadius => 'Bán kính phục vụ';

  @override
  String setupRadiusValue(int km) {
    return '$km km';
  }

  @override
  String get setupContactPhone => 'Số điện thoại · bắt buộc';

  @override
  String get setupContactChannels =>
      'Chọn kênh khách được dùng để liên hệ bạn.';

  @override
  String get setupChannelCall => 'Gọi điện';

  @override
  String get setupChannelCallHint => 'Dùng số trên';

  @override
  String get setupChannelZalo => 'Zalo';

  @override
  String get setupChannelZaloHint => 'Dùng số trên';

  @override
  String get setupZaloOwn => 'Số Zalo riêng (để trống nếu dùng số trên)';

  @override
  String get setupChannelWhatsApp => 'WhatsApp';

  @override
  String get setupChannelWhatsAppHint => 'Nhập số riêng nếu khác';

  @override
  String get setupWhatsAppOwn =>
      'Số WhatsApp có mã quốc gia (để trống nếu dùng số trên)';

  @override
  String get setupInAppOnly => 'Chỉ nhận tin nhắn trong app';

  @override
  String get setupInAppOnlyHint =>
      'Khách chỉ nhắn được trong ứng dụng. Bạn có thể bật gọi, Zalo hay WhatsApp sau.';

  @override
  String get setupContactPrivacy =>
      'Số của bạn không hiện công khai. Khách chỉ dùng được các kênh này sau khi đã đặt lịch.';

  @override
  String get setupContactBack => 'Quay lại';

  @override
  String get setupContactFinish => 'Hoàn tất';

  @override
  String get setupCityRequired => 'Nhập thành phố bạn nhận việc';

  @override
  String get setupNoChannel =>
      'Bật ít nhất một kênh, hoặc chọn \"Chỉ nhận tin nhắn trong app\".';

  @override
  String get setupWhatsAppNeedsNumber =>
      'Nhập số WhatsApp có mã quốc gia, ví dụ +1 415 555 2671';

  @override
  String get setupSaveError =>
      'Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.';

  @override
  String get setupBioLabel => 'Giới thiệu';

  @override
  String get setupBioHint =>
      'Ánh sáng tự nhiên, ít dàn dựng. Chuyên chân dung ngoài trời ở Sài Gòn.';

  @override
  String get setupEquipmentLabel => 'Thiết bị (không bắt buộc)';

  @override
  String get setupEquipmentHint => 'Ví dụ: Sony A7 IV';

  @override
  String get setupEquipmentAdd => 'Thêm thiết bị';

  @override
  String setupEquipmentRemove(String item) {
    return 'Xoá $item';
  }

  @override
  String get setupEquipmentFull => 'Tối đa 8 thiết bị.';

  @override
  String get setupNext => 'Tiếp tục';

  @override
  String get introBioRequired => 'Viết vài dòng giới thiệu';

  @override
  String get introBioTooLong => 'Tối đa 300 ký tự';

  @override
  String get setupServicesHeading => 'Gói dịch vụ';

  @override
  String get setupServiceHint =>
      'Khách đặt theo gói. Cần ít nhất một gói để hồ sơ hiện trong Tìm thợ ảnh.';

  @override
  String get setupNoPackages => 'Chưa có gói nào. Thêm gói đầu tiên bên dưới.';

  @override
  String get setupNeedPackage => 'Thêm ít nhất một gói để tiếp tục.';

  @override
  String get setupPackagesLoadError => 'Không tải được danh sách gói.';

  @override
  String get packageEditHeading => 'Sửa gói';

  @override
  String get packageNameLabel => 'Tên gói';

  @override
  String get packageNameHint => 'Ví dụ: Chân dung 2 giờ';

  @override
  String get packagePriceLabel => 'Giá (₫)';

  @override
  String get packageDurationLabel => 'Thời lượng';

  @override
  String get packageDurationHint => 'Chọn';

  @override
  String durationHours(String hours) {
    return '$hours giờ';
  }

  @override
  String get packageEditedLabel => 'Số ảnh hậu kỳ';

  @override
  String get packageDeliveryLabel => 'Giao sau';

  @override
  String get packageDeliverySuffix => 'ngày';

  @override
  String packagePhotos(int count) {
    return '$count ảnh';
  }

  @override
  String packageDelivery(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'giao $days ngày',
      zero: 'giao trong ngày',
    );
    return '$_temp0';
  }

  @override
  String get packageAdd => 'Thêm gói này';

  @override
  String get packageSave => 'Lưu gói';

  @override
  String get packageCancelEdit => 'Huỷ sửa';

  @override
  String packageHideTooltip(String name) {
    return 'Ẩn gói $name';
  }

  @override
  String get packageHideTitle => 'Ẩn gói này?';

  @override
  String get packageHideBody =>
      'Khách sẽ không thấy và không đặt được gói này nữa. Bài đăng cũ vẫn giữ nguyên.';

  @override
  String get packageHideConfirm => 'Ẩn gói';

  @override
  String get packageKeep => 'Giữ lại';

  @override
  String get packageAdded => 'Đã thêm gói.';

  @override
  String get packageSaved => 'Đã lưu gói.';

  @override
  String get packageHidden => 'Đã ẩn gói.';

  @override
  String get packageNameLength => 'Nhập tên gói từ 2 đến 60 ký tự';

  @override
  String get packagePriceRequired => 'Nhập giá lớn hơn 0';

  @override
  String get packagePriceTooHigh => 'Giá tối đa 1.000.000.000₫';

  @override
  String get packageDurationRequired => 'Chọn thời lượng';

  @override
  String get packageCountInvalid => 'Nhập số từ 0 đến 2000';

  @override
  String get packageDaysInvalid => 'Nhập số ngày từ 0 đến 90';

  @override
  String get locationPromptTitle => 'Sự kiện gần bạn';

  @override
  String get locationPromptBody =>
      'Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.';

  @override
  String get locationAllow => 'Cho phép';

  @override
  String get locationLater => 'Để sau';

  @override
  String get locationChooseArea => 'Chọn khu vực';

  @override
  String get eventTypePhotoWalk => 'Photo walk';

  @override
  String get eventTypeMiniSession => 'Mini session';

  @override
  String get eventTypeWorkshop => 'Workshop';

  @override
  String get eventTypeCosplay => 'Cosplay';

  @override
  String get eventTypeOther => 'Khác';

  @override
  String eventSeatsLeft(int n) {
    return 'Còn $n chỗ';
  }

  @override
  String get eventSoldOut => 'Hết chỗ';

  @override
  String eventMonthShort(int month) {
    return 'T$month';
  }

  @override
  String get areaPickerTitle => 'Chọn khu vực của bạn';

  @override
  String get areaPickerBody =>
      'Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.';

  @override
  String get areaPickerBodyOn => 'Chọn khu vực để xem sự kiện quanh đó.';

  @override
  String get areaPickerOpenSettings => 'Mở Cài đặt để bật vị trí';

  @override
  String get areaPickerUse => 'Dùng khu vực này';

  @override
  String get areaPickerUseDevice => 'Dùng vị trí của tôi';

  @override
  String get areaPickerSearch => 'Tìm quận, thành phố';

  @override
  String get areaPickerNoMatch => 'Không tìm thấy khu vực';

  @override
  String get areaDeviceFailed =>
      'Không lấy được vị trí. Chọn một khu vực hoặc thử lại.';

  @override
  String exploreAround(String area) {
    return 'Quanh $area · vị trí gần đúng';
  }

  @override
  String get exploreAroundMe => 'Quanh bạn · vị trí gần đúng';

  @override
  String get exploreChange => 'Đổi';

  @override
  String exploreRadius(int km) {
    return '$km km';
  }

  @override
  String get exploreThisWeek => 'Tuần này';

  @override
  String get exploreWeekend => 'Cuối tuần';

  @override
  String get exploreNearbyTitle => 'Sự kiện gần bạn';

  @override
  String get exploreEventsTitle => 'Sự kiện chụp ảnh';

  @override
  String get exploreSeeAll => 'Xem tất cả';

  @override
  String get exploreNoneNearby => 'Chưa có sự kiện gần bạn';

  @override
  String get exploreWiden => 'Tăng bán kính';

  @override
  String get exploreTabServices => 'Dịch vụ';

  @override
  String get exploreTabPlaces => 'Địa điểm';

  @override
  String get exploreTabStyles => 'Phong cách';

  @override
  String get exploreTabPhotographers => 'Thợ ảnh';

  @override
  String get explorePhotographersAll => 'Xem tất cả nhiếp ảnh gia';

  @override
  String get exploreSearchHint => 'Tìm dịch vụ, địa điểm, tên thợ ảnh';

  @override
  String get exploreSearchIdle => 'Gõ tên dịch vụ, khu vực hoặc tên thợ ảnh.';

  @override
  String exploreSearchEmptyTitle(String query) {
    return 'Không tìm thấy “$query”';
  }

  @override
  String get exploreSearchEmptyBody => 'Thử từ ngắn hơn, hoặc gõ không dấu.';

  @override
  String get exploreSearchSeeAll => 'Xem tất cả thợ ảnh';

  @override
  String get exploreSearchClear => 'Xoá';

  @override
  String exploreCategoryPackages(int count) {
    return '$count gói';
  }

  @override
  String get exploreLoadError =>
      'Không tải được sự kiện. Kiểm tra mạng rồi thử lại.';

  @override
  String eventDateSpoken(String weekday, int day, int month) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Thứ hai',
      '2': 'Thứ ba',
      '3': 'Thứ tư',
      '4': 'Thứ năm',
      '5': 'Thứ sáu',
      '6': 'Thứ bảy',
      'other': 'Chủ nhật',
    });
    return '$_temp0, ngày $day tháng $month';
  }

  @override
  String reasonsSemantics(String reasons) {
    return 'Gợi ý vì: $reasons';
  }

  @override
  String photographerSessions(int n) {
    return '$n buổi';
  }

  @override
  String get priceFrom => 'từ';

  @override
  String priceFromValue(String price) {
    return 'từ $price';
  }

  @override
  String get photographerCardProfile => 'Hồ sơ';

  @override
  String get photographerCardBook => 'Đặt lịch';

  @override
  String get skillChipFull => 'Đã đủ số lượng';

  @override
  String get completenessTitle => 'Độ khớp hồ sơ';

  @override
  String get completenessNone => 'Chưa có điểm';

  @override
  String completenessPercent(int percent) {
    return '$percent%';
  }

  @override
  String get skillsLevelBasic => 'Cơ bản';

  @override
  String get skillsLevelGood => 'Thành thạo';

  @override
  String get skillsLevelExpert => 'Chuyên sâu';

  @override
  String skillsLevelSemantics(String name, String level) {
    return '$name, mức $level';
  }

  @override
  String get skillsExpertFull => 'Đã đủ 3 mức Chuyên sâu';

  @override
  String skillEvidencePhoto(int index) {
    return 'Ảnh $index';
  }

  @override
  String skillsCount(int n, int max) {
    return '$n / $max';
  }

  @override
  String skillEvidenceTitle(String name) {
    return 'Minh chứng · $name';
  }

  @override
  String get skillEvidenceBody =>
      'Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.';

  @override
  String get skillEvidenceDone => 'Xong';

  @override
  String get skillEvidenceEmpty => 'Đăng bài trước';

  @override
  String get skillEvidenceEmptyBody =>
      'Bạn chưa có bài đăng nào. Đăng ảnh vào portfolio rồi quay lại chọn ảnh minh chứng.';

  @override
  String get skillEvidenceEmptyAction => 'Đăng bài';

  @override
  String get skillEvidenceMax =>
      'Tối đa 3 ảnh. Bỏ chọn một ảnh để chọn ảnh khác.';

  @override
  String get skillEvidenceNeedOne => 'Mức Chuyên sâu cần ít nhất 1 ảnh';

  @override
  String get skillEvidenceLoadError => 'Không tải được bài đăng của bạn.';

  @override
  String get skillEvidenceLoadMore => 'Tải thêm';

  @override
  String get skillEvidenceLoadMoreRetry => 'Không tải thêm được. Thử lại';

  @override
  String get skillsTitle => 'Kỹ năng';

  @override
  String get skillsIntro =>
      'Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.';

  @override
  String get skillsTypes => 'Thể loại chụp';

  @override
  String get skillsLevels => 'Mức độ';

  @override
  String get skillsMaxExpert => 'Chuyên sâu tối đa 3';

  @override
  String skillsEvidenceRow(String name, int n) {
    return '$name: $n / 3 ảnh minh chứng';
  }

  @override
  String get skillsEvidenceEdit => 'Chỉnh';

  @override
  String get skillsEvidenceNeeded =>
      'Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng';

  @override
  String get skillsTooMany => 'Tối đa 6 thể loại';

  @override
  String get skillsTooManyExpert => 'Chỉ chọn tối đa 3 thể loại mức Chuyên sâu';

  @override
  String get skillsTooManyStyles => 'Tối đa 4 phong cách';

  @override
  String get skillsTooManyExtras => 'Tối đa 8 kỹ năng thêm';

  @override
  String get skillsTooManyAudiences => 'Tối đa 4 nhóm khách phù hợp';

  @override
  String get skillsStyles => 'Phong cách';

  @override
  String get skillsExtras => 'Kỹ năng thêm';

  @override
  String get skillsLanguages => 'Ngôn ngữ';

  @override
  String get skillsAudiences => 'Khách phù hợp';

  @override
  String get skillsYears => 'Kinh nghiệm';

  @override
  String get skillsYearsSuffix => 'năm';

  @override
  String get skillsYearsRange => 'Từ 0 đến 50 năm';

  @override
  String get skillsNeedLang => 'Chọn ít nhất 1 ngôn ngữ';

  @override
  String get skillsBack => 'Quay lại';

  @override
  String get skillsContinue => 'Tiếp tục';

  @override
  String get skillsSave => 'Lưu thay đổi';

  @override
  String get skillsSaveError => 'Không lưu được kỹ năng. Thử lại nhé.';

  @override
  String get skillsLoadError => 'Không tải được kỹ năng.';

  @override
  String get skillsFixIssues => 'Kiểm tra lại các mục được đánh dấu';

  @override
  String get skillsDraftRestored => 'Đã mở lại bản nháp chưa lưu';

  @override
  String get skillsHintSpecialty => 'Chọn ít nhất 1 thể loại';

  @override
  String skillsHintEvidence(String name) {
    return 'Thêm ảnh minh chứng cho $name';
  }

  @override
  String get skillsHintEvidenceAny =>
      'Thêm ảnh minh chứng cho thể loại Chuyên sâu';

  @override
  String get skillsHintStyles => 'Chọn phong cách';

  @override
  String get skillsHintLanguages => 'Chọn ngôn ngữ';

  @override
  String get skillsHintAudiences => 'Chọn khách phù hợp';

  @override
  String get skillsHintExtras => 'Chọn kỹ năng thêm';

  @override
  String get skillsHintDone => 'Hồ sơ kỹ năng đã đầy đủ';

  @override
  String get skillsFitSaveToScore => 'Lưu để tính độ khớp';

  @override
  String get skillsFitSaveToUpdate => 'Lưu để cập nhật độ khớp';

  @override
  String skillsHintTarget(String hint, int percent) {
    return '$hint để lên $percent%';
  }

  @override
  String get skillsEvidenceRemoved =>
      'Một số minh chứng không hợp lệ đã được gỡ';

  @override
  String get skillsLeaveTitle => 'Lưu bản nháp?';

  @override
  String get skillsLeaveBody =>
      'Thay đổi chưa được lưu vào hồ sơ. Giữ bản nháp trên máy để làm tiếp lần sau nhé.';

  @override
  String get skillsLeaveKeep => 'Giữ bản nháp';

  @override
  String get skillsLeaveDiscard => 'Bỏ thay đổi';

  @override
  String skillsRemoveTitle(String name) {
    return 'Bỏ thể loại $name?';
  }

  @override
  String get skillsRemoveBody =>
      'Ảnh minh chứng đã gắn cho thể loại này cũng sẽ bị gỡ.';

  @override
  String get skillsRemoveKeep => 'Giữ lại';

  @override
  String get skillsRemoveConfirm => 'Bỏ thể loại';

  @override
  String calendarMonthTitle(String month, String year) {
    return 'Tháng $month, $year';
  }

  @override
  String calendarMonthShort(String month) {
    return 'Tháng $month';
  }

  @override
  String get calendarPrevMonth => 'Tháng trước';

  @override
  String get calendarNextMonth => 'Tháng sau';

  @override
  String calendarWeekdayShort(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': 'T2',
      'tue': 'T3',
      'wed': 'T4',
      'thu': 'T5',
      'fri': 'T6',
      'sat': 'T7',
      'other': 'CN',
    });
    return '$_temp0';
  }

  @override
  String calendarWeekdayLong(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      'mon': 'Thứ 2',
      'tue': 'Thứ 3',
      'wed': 'Thứ 4',
      'thu': 'Thứ 5',
      'fri': 'Thứ 6',
      'sat': 'Thứ 7',
      'other': 'Chủ nhật',
    });
    return '$_temp0';
  }

  @override
  String calendarDayTitle(String weekday, String day, String month) {
    return '$weekday, $day/$month';
  }

  @override
  String get dayStateFree => 'Rảnh';

  @override
  String get dayStatePending => 'Chờ nhận';

  @override
  String get dayStateBooked => 'Đã đặt';

  @override
  String get dayStateOff => 'Nghỉ';

  @override
  String get calendarDayFull => 'Hết chỗ';

  @override
  String calendarDaySemantics(String day, String month, String state) {
    return '$day tháng $month, $state';
  }

  @override
  String get calendarHasEvent => 'có sự kiện';

  @override
  String get calendarToday => 'hôm nay';

  @override
  String get myCalendarTitle => 'Lịch của tôi';

  @override
  String get calendarMarkOff => 'Đánh dấu nghỉ';

  @override
  String get calendarClearOff => 'Bỏ nghỉ';

  @override
  String get calendarUndo => 'Hoàn tác';

  @override
  String get calendarHint =>
      'Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.';

  @override
  String get calendarRangeHint => 'Chạm ngày cuối để đánh dấu nghỉ cả khoảng.';

  @override
  String get calendarHasPlan => 'Ngày này đã có lịch';

  @override
  String get calendarMarkedOff => 'Đã đánh dấu nghỉ';

  @override
  String calendarMarkedOffMany(int count) {
    return 'Đã đánh dấu nghỉ $count ngày';
  }

  @override
  String get calendarClearedOff => 'Đã bỏ nghỉ';

  @override
  String get calendarOpenBooking => 'Xem lịch hẹn';

  @override
  String get calendarOpenEvent => 'Quản lý sự kiện';

  @override
  String get calendarSaveError => 'Không lưu được lịch. Thử lại nhé.';

  @override
  String get calendarLoadError => 'Không tải được lịch.';

  @override
  String get calendarPickDay => 'Chọn một ngày để xem chi tiết.';

  @override
  String get createAddPhotos => 'Thêm ảnh';

  @override
  String createPhotosCount(int n, int max) {
    return '$n / $max ảnh';
  }

  @override
  String get createCaptionLabel => 'Mô tả';

  @override
  String get createCaptionHint => 'Chiều muộn ở bến Bạch Đằng…';

  @override
  String get createServiceLabel => 'Gói dịch vụ · bắt buộc';

  @override
  String get createServicePick => 'Chọn gói';

  @override
  String get createServiceTitle => 'Chọn gói dịch vụ';

  @override
  String get createServiceRequired => 'Chọn gói dịch vụ cho bài đăng';

  @override
  String get createPhotosRequired => 'Thêm ít nhất một ảnh';

  @override
  String get createNoServices =>
      'Bạn chưa có gói dịch vụ nào. Thêm gói để đăng bài.';

  @override
  String get createAddService => 'Thêm gói';

  @override
  String get createServicesError => 'Không tải được gói dịch vụ.';

  @override
  String get createLocationLabel => 'Địa điểm';

  @override
  String get createStyleLabel => 'Phong cách';

  @override
  String get createStyleNone => 'Không chọn';

  @override
  String get createStyleTitle => 'Phong cách';

  @override
  String get createPublish => 'Đăng';

  @override
  String get createRemove => 'Gỡ ảnh';

  @override
  String get createMoveUp => 'Đưa lên';

  @override
  String get createMoveDown => 'Đưa xuống';

  @override
  String get createRetryPhoto => 'Tải lại ảnh';

  @override
  String createUploading(int percent) {
    return 'Đang tải $percent%';
  }

  @override
  String get createUploadFailed => 'Không tải được ảnh. Thử lại nhé.';

  @override
  String get createPublishFailed =>
      'Không đăng được bài. Kiểm tra mạng rồi thử lại.';

  @override
  String get createPublished => 'Đã đăng bài';

  @override
  String reasonFreeOnDate(String day) {
    return 'Rảnh $day';
  }

  @override
  String reasonSkillMatch(String specialty) {
    return 'Chuyên $specialty';
  }

  @override
  String reasonNear(String distance) {
    return 'Cách $distance';
  }

  @override
  String reasonTopRated(int pct, int count) {
    return '$pct% cà chua từ $count đánh giá';
  }

  @override
  String get reasonFastReply => 'Phản hồi nhanh';

  @override
  String get reasonNewTalent => 'Mới tham gia';

  @override
  String homePillFree(String day) {
    return 'Rảnh $day này';
  }

  @override
  String get engagementError => 'Chưa thực hiện được. Thử lại nhé.';

  @override
  String get back => 'Quay lại';

  @override
  String homeGreeting(String name) {
    return 'Chào $name';
  }

  @override
  String get homeTitle => 'Hôm nay chụp gì?';

  @override
  String get homeForYou => 'Dành cho bạn';

  @override
  String get homeFreeThisWeek => 'Rảnh tuần này';

  @override
  String get homeRealShoots => 'Buổi chụp thật';

  @override
  String get homeFromCustomers => 'Từ khách hàng';

  @override
  String homeRealShootBy(String name) {
    return 'Chụp bởi $name';
  }

  @override
  String get homeEmptyTitle => 'Chưa có ảnh nào quanh bạn';

  @override
  String get homeEmptyBody => 'Khám phá nhiếp ảnh gia để thấy ảnh đẹp ở đây.';

  @override
  String get homeEmptyAction => 'Khám phá nhiếp ảnh gia';

  @override
  String get homeLoadError => 'Không tải được ảnh. Kiểm tra mạng rồi thử lại.';

  @override
  String get photoSave => 'Lưu ảnh';

  @override
  String get photoUnsave => 'Bỏ lưu';

  @override
  String get photoBook => 'Đặt gói này';

  @override
  String get photoViewProfile => 'Xem hồ sơ';

  @override
  String get photoFollow => 'Theo dõi';

  @override
  String get photoFollowing => 'Đang theo dõi';

  @override
  String photoRealShootBy(String name, String service) {
    return 'Chụp bởi $name · gói $service';
  }

  @override
  String photoRealShootByName(String name) {
    return 'Chụp bởi $name';
  }

  @override
  String get photoRemovedTitle => 'Bài đăng không còn';

  @override
  String get photoRemovedBody => 'Bài đăng này đã bị gỡ hoặc không tồn tại.';

  @override
  String get photoBackHome => 'Về trang chủ';

  @override
  String photoMoreOf(String name) {
    return 'Thêm của $name';
  }

  @override
  String get photoMoreProfile => 'Hồ sơ';

  @override
  String photoItemLabel(int i) {
    return 'Ảnh $i';
  }

  @override
  String get photoOtherPackages => 'Xem các gói khác';

  @override
  String get photoServiceInactive => 'Gói này đã ngừng';

  @override
  String get photoLike => 'Thích';

  @override
  String get photoUnlike => 'Bỏ thích';

  @override
  String photoPageOf(int n, int total) {
    return 'Ảnh $n trên $total';
  }

  @override
  String get photoLoadError =>
      'Không tải được bài đăng. Kiểm tra mạng rồi thử lại.';

  @override
  String get photoSharePost => 'Chia sẻ bài viết';

  @override
  String get photoShareCopied => 'Đã sao chép liên kết bài viết';

  @override
  String get photoMoreOptions => 'Thêm tuỳ chọn';

  @override
  String servicePhotos(int n) {
    return '$n ảnh';
  }

  @override
  String serviceDelivery(int days) {
    return 'giao sau $days ngày';
  }

  @override
  String serviceDurationMinutes(int m) {
    return '$m phút';
  }

  @override
  String serviceDurationHours(int h) {
    return '$h giờ';
  }

  @override
  String serviceDurationHoursMinutes(int h, int m) {
    return '$h giờ $m phút';
  }

  @override
  String get findDate => 'Ngày';

  @override
  String get findService => 'Dịch vụ';

  @override
  String get findPrice => 'Giá';

  @override
  String get findRating => 'Đánh giá';

  @override
  String get findNearMe => 'Quanh bạn';

  @override
  String findCount(String count) {
    return '$count nhiếp ảnh gia';
  }

  @override
  String findCountOnDay(String count, String day) {
    return '$count nhiếp ảnh gia rảnh $day';
  }

  @override
  String get findSortBest => 'Phù hợp nhất';

  @override
  String get findSortNear => 'Gần tôi';

  @override
  String get findSortPrice => 'Giá';

  @override
  String get findSortRating => 'Đánh giá';

  @override
  String get findNoResult => 'Chưa có ai khớp bộ lọc';

  @override
  String get findNoResultBody => 'Thử bỏ bớt bộ lọc hoặc chọn ngày khác.';

  @override
  String get findClear => 'Xoá bộ lọc';

  @override
  String get findFallbackNote => 'Đang xếp theo điểm cà chua và khoảng cách';

  @override
  String get findLoadError =>
      'Không tải được danh sách. Kiểm tra mạng rồi thử lại.';

  @override
  String findBookDay(String day) {
    return 'Đặt $day';
  }

  @override
  String get findDateTitle => 'Chọn ngày';

  @override
  String get findDateClear => 'Xoá ngày';

  @override
  String get findDateDone => 'Xong';

  @override
  String get findServiceTitle => 'Dịch vụ';

  @override
  String get findServiceAll => 'Tất cả dịch vụ';

  @override
  String get findPriceTitle => 'Ngân sách';

  @override
  String get findPriceAny => 'Mọi mức giá';

  @override
  String findPriceUnder(String price) {
    return 'Dưới $price';
  }

  @override
  String get findTomatoTitle => 'Tỷ lệ hài lòng';

  @override
  String get findRatingAny => 'Mọi đánh giá';

  @override
  String findTomatoMin(int pct) {
    return '$pct%+';
  }

  @override
  String findTomatoChipA11y(int pct) {
    return 'Từ $pct% cà chua';
  }

  @override
  String profileResponseMinutes(int minutes) {
    return '~$minutes phút';
  }

  @override
  String profileResponseHours(int hours) {
    return '~$hours giờ';
  }

  @override
  String get profileTabPortfolio => 'Portfolio';

  @override
  String get profileTabServices => 'Gói';

  @override
  String get profileTabCalendar => 'Lịch';

  @override
  String get profileTabReviews => 'Đánh giá';

  @override
  String get profileBook => 'Đặt lịch';

  @override
  String profileBookFrom(String price) {
    return 'Đặt lịch · từ $price';
  }

  @override
  String get profileNoServices => 'Nhiếp ảnh gia chưa đăng gói';

  @override
  String get profileOrdersClosedTag => 'Chưa nhận đơn';

  @override
  String profileOrdersClosedNote(String name) {
    return '$name chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. Bạn vẫn nhắn hỏi được.';
  }

  @override
  String get profileOrdersClosedButton => 'Chưa nhận đặt lịch';

  @override
  String get profileFollow => 'Theo dõi';

  @override
  String get profileFollowing => 'Đang theo dõi';

  @override
  String profileStatReviews(int count) {
    return '$count đánh giá';
  }

  @override
  String get profileStatNew => 'Mới';

  @override
  String photographerReviewsNew(int count) {
    return 'Mới · $count đánh giá';
  }

  @override
  String get profileStatShoots => 'buổi chụp';

  @override
  String get profileStatResponse => 'phản hồi';

  @override
  String get profileStatYears => 'kinh nghiệm';

  @override
  String profileYearsValue(int years) {
    return '$years năm';
  }

  @override
  String profileEquipment(String list) {
    return 'Thiết bị: $list';
  }

  @override
  String get profileNoPortfolio => 'Chưa có ảnh nào';

  @override
  String get profileMorePhotos => 'Xem thêm ảnh';

  @override
  String get profileSimilar => 'Thợ ảnh tương tự';

  @override
  String get profilePhoto => 'Ảnh portfolio';

  @override
  String get profileEvidenceBadge => 'Ảnh minh chứng kỹ năng';

  @override
  String get profileNoReviewsTitle => 'Chưa có đánh giá';

  @override
  String get profileNoReviewsBody =>
      'Đánh giá hiện ở đây sau những buổi chụp đầu tiên.';

  @override
  String get profileNotFound => 'Không tìm thấy hồ sơ.';

  @override
  String get profileNotReadyTitle => 'Hồ sơ này chưa sẵn sàng';

  @override
  String get profileNotReadyBody =>
      'Nhiếp ảnh gia đang hoàn thiện hồ sơ. Quay lại sau nhé.';

  @override
  String get profileLoadError => 'Không tải được hồ sơ.';

  @override
  String get profileEdit => 'Chỉnh sửa hồ sơ';

  @override
  String get profileEditIntro => 'Giới thiệu';

  @override
  String get profileEditPackages => 'Gói dịch vụ';

  @override
  String get profileEditSkills => 'Kỹ năng';

  @override
  String get profileEditPhoto => 'Ảnh đại diện và tên';

  @override
  String get profileEditContact => 'Khu vực và liên hệ';

  @override
  String get profileSavePhotographer => 'Lưu nhiếp ảnh gia';

  @override
  String get profileSharePhotographer => 'Chia sẻ hồ sơ';

  @override
  String get profileShareCopied => 'Đã sao chép liên kết hồ sơ';

  @override
  String get profileMoreOptions => 'Thêm tuỳ chọn';

  @override
  String get offlineBanner => 'Đang xem dữ liệu đã lưu';

  @override
  String get settingsSignOutConfirmBody =>
      'Bạn có chắc chắn muốn đăng xuất không?';

  @override
  String get settingsSignOutKeep => 'Ở lại';

  @override
  String get ticketUpcoming => 'Đã đăng ký';

  @override
  String get ticketPendingPayment => 'Chờ thanh toán';

  @override
  String get ticketPast => 'Đã qua';

  @override
  String get ticketCancelled => 'Đã huỷ';

  @override
  String ticketCount(int count) {
    return '$count vé';
  }

  @override
  String ticketCodeSemantics(String code) {
    return 'Mã vé $code';
  }

  @override
  String get ticketDirections => 'Chỉ đường';

  @override
  String get ticketAddToCalendar => 'Thêm vào lịch';

  @override
  String get ticketCancel => 'Huỷ vé';

  @override
  String get ticketPay => 'Thanh toán';

  @override
  String badgeChipSemantics(String name) {
    return 'Huy hiệu $name';
  }

  @override
  String get badgeSeeAll => 'Tất cả';

  @override
  String get badgeNotEarned => 'Chưa đạt';

  @override
  String get badgeEarned => 'Đã đạt';

  @override
  String get badgeNew => 'Mới';

  @override
  String get notificationTitle => 'Thông báo';

  @override
  String notificationUnreadCount(int count) {
    return '$count thông báo chưa đọc';
  }

  @override
  String get notificationMarkRead => 'Đánh dấu đã đọc';

  @override
  String get notificationMuteKind => 'Tắt loại thông báo này';

  @override
  String get notificationUnreadPrefix => 'Chưa đọc';

  @override
  String get primerEnableNotification => 'Bật thông báo';

  @override
  String get primerLater => 'Để sau';

  @override
  String get bookChoosePackage => 'Chọn gói';

  @override
  String bookWith(String name) {
    return 'Đặt với $name';
  }

  @override
  String bookContinuePrice(String price) {
    return 'Tiếp tục · $price';
  }

  @override
  String get bookNoPackages => 'Nhiếp ảnh gia chưa đăng gói';

  @override
  String get bookPriceChanged => 'Giá gói đã đổi';

  @override
  String get bookDiscardTitle => 'Bỏ yêu cầu đặt lịch?';

  @override
  String get bookDiscard => 'Bỏ';

  @override
  String get bookKeepGoing => 'Tiếp tục đặt';

  @override
  String get bookClose => 'Đóng';

  @override
  String get bookLegendFree => 'Rảnh';

  @override
  String get bookLegendBooked => 'Đã đặt';

  @override
  String get bookLegendPending => 'Chờ';

  @override
  String bookWaiting(int n) {
    return '$n người đang chờ';
  }

  @override
  String bookEndsAt(String start, String end) {
    return '$start–$end';
  }

  @override
  String get bookDayTaken => 'Hôm đó vừa có người đặt';

  @override
  String get bookDayNoSlots => 'Hôm đó đã hết giờ';

  @override
  String get bookPlaceTitle => 'Địa điểm chụp';

  @override
  String get bookPlaceHint => 'Tên địa điểm hoặc khu vực (tối thiểu 3 ký tự)';

  @override
  String get bookReview => 'Xem lại';

  @override
  String get bookNote => 'Ghi chú';

  @override
  String get bookNoteHint => 'Thêm ghi chú cho nhiếp ảnh gia (tuỳ chọn)';

  @override
  String get bookYourPhone => 'SĐT của bạn';

  @override
  String get bookDepositToday => 'Thanh toán 100%';

  @override
  String get bookPolicy =>
      'Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả.';

  @override
  String bookPay(String amount) {
    return 'Thanh toán $amount';
  }

  @override
  String get payTitle => 'Thanh toán';

  @override
  String get payQrTitle => 'Chuyển khoản QR';

  @override
  String payQrCountdown(String time) {
    return 'Còn $time';
  }

  @override
  String payQrCountdownSemantics(int minutes, int seconds) {
    return 'QR còn hiệu lực $minutes phút $seconds giây';
  }

  @override
  String get payQrExpiredPill => 'Hết hạn';

  @override
  String get payQrExpired => 'QR đã hết hạn';

  @override
  String get payQrBank => 'Ngân hàng';

  @override
  String get payQrBankNote => 'Tài khoản thu hộ của trung gian thanh toán';

  @override
  String get payQrAccount => 'Số tài khoản';

  @override
  String get payQrContent => 'Nội dung';

  @override
  String get payQrCopy => 'Sao chép';

  @override
  String get payQrCopied => 'Đã sao chép nội dung chuyển khoản';

  @override
  String get payQrHint =>
      'Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động.';

  @override
  String get payQrNew => 'Tạo QR mới';

  @override
  String get payQrOpenBank => 'Mở app ngân hàng';

  @override
  String payQrSemantics(String amount, String code) {
    return 'Mã VietQR $amount, nội dung $code';
  }

  @override
  String payQrWho(String name, String service) {
    return '$name · $service';
  }

  @override
  String get payWalletWaiting => 'Đang chờ xác nhận';

  @override
  String payWalletReopen(String name) {
    return 'Mở lại $name';
  }

  @override
  String get fakeTransferTitle => 'Giả lập chuyển khoản (thử nghiệm)';

  @override
  String get fakeTransferExact => 'Chuyển đúng';

  @override
  String get fakeTransferUnder => 'Chuyển thiếu';

  @override
  String get fakeTransferOver => 'Chuyển thừa';

  @override
  String get fakeTransferWrong => 'Sai nội dung';

  @override
  String get fakeTransferOpen => 'Giả lập chuyển khoản';

  @override
  String get payAwaitingDeposit => 'Chờ thanh toán';

  @override
  String get payCheckAgain => 'Kiểm tra lại';

  @override
  String get payNotYet => 'Chưa nhận được xác nhận, thử lại sau ít phút';

  @override
  String get fakePaymentTitle => 'Cổng thanh toán giả (chỉ để thử)';

  @override
  String get fakePaymentSuccess => 'Thanh toán thành công';

  @override
  String get fakePaymentCancel => 'Huỷ';

  @override
  String get payRequestSent => 'Đã gửi yêu cầu';

  @override
  String payReplyIn24h(String name) {
    return '$name sẽ trả lời trong 24 giờ';
  }

  @override
  String escrowNoticeHeld(String amount) {
    return 'Đã thanh toán $amount, tiền được giữ an toàn';
  }

  @override
  String get paySuccessTitle => 'Đã gửi yêu cầu';

  @override
  String paySuccessBody(String name) {
    return '$name sẽ trả lời trong 24 giờ';
  }

  @override
  String get payViewBookings => 'Xem lịch đặt';

  @override
  String get payExpired => 'Yêu cầu đã hết hạn';

  @override
  String get payExpiredTitle => 'Yêu cầu đã hết hạn';

  @override
  String get payExpiredBody =>
      'Chưa nhận được thanh toán nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.';

  @override
  String get payTicketExpiredBody =>
      'Chưa nhận được thanh toán nên chỗ giữ đã nhả. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.';

  @override
  String get payBackToEvent => 'Về sự kiện';

  @override
  String get payRetry => 'Đặt lại';

  @override
  String get payBookAgain => 'Đặt lại';

  @override
  String get payGoHome => 'Về trang chủ';

  @override
  String bookMonth(int m) {
    return 'Tháng $m';
  }

  @override
  String bookDayLine(String day, String duration) {
    return '$day · khung $duration';
  }

  @override
  String get bookNoSlots => 'Hôm đó đã hết giờ';

  @override
  String get bookDayGone => 'Hôm đó vừa có người đặt, chọn ngày khác';

  @override
  String get bookPlaceTooShort => 'Nhập ít nhất 3 ký tự';

  @override
  String bookPackageLine(String name) {
    return 'Gói $name';
  }

  @override
  String get bookTryAgain => 'Yêu cầu đã hết hạn, thử lại nhé.';

  @override
  String get bookPaymentsOff => 'Thanh toán chưa mở trên máy chủ này.';

  @override
  String get bookNetworkError => 'Không gửi được. Kiểm tra mạng rồi thử lại.';

  @override
  String get fakePayBody => 'Bản dùng thử: không có tiền thật nào được trừ.';

  @override
  String get actionCancel => 'Huỷ';

  @override
  String get actionRetry => 'Thử lại';

  @override
  String get timelineSent => 'Đã gửi & thanh toán';

  @override
  String timelineSentDetail(String when, String amount) {
    return '$when · $amount';
  }

  @override
  String timelineToday(String time) {
    return 'Hôm nay $time';
  }

  @override
  String timelineWaiting(String name) {
    return 'Chờ $name nhận';
  }

  @override
  String get timelineWaitingHint => 'Thường trong 1 giờ';

  @override
  String get timelineConfirmed => 'Đã xác nhận';

  @override
  String get timelineConfirmedHint => 'Nhắn tin để chốt chi tiết';

  @override
  String timelineUpcoming(String day) {
    return 'Sắp tới · $day';
  }

  @override
  String get timelineUpcomingHint => 'Nhắc trước 24 giờ';

  @override
  String get timelineShoot => 'Buổi chụp';

  @override
  String get timelineDelivery => 'Bàn giao & duyệt ảnh';

  @override
  String timelineDeliveryWaitCustomer(String name) {
    return 'Chờ $name gửi ảnh mẫu';
  }

  @override
  String get timelineDeliveryWaitProvider =>
      'Chờ bạn nộp ảnh mẫu và link ảnh gốc';

  @override
  String timelineDeliveryReviewCustomer(int round) {
    return 'Vòng $round · chờ bạn duyệt';
  }

  @override
  String timelineDeliveryReviewProvider(int round) {
    return 'Vòng $round · chờ khách duyệt';
  }

  @override
  String timelineDeliveryRevisingCustomer(String name, int round) {
    return '$name đang chỉnh sửa vòng $round';
  }

  @override
  String timelineDeliveryRevisingProvider(int round) {
    return 'Khách muốn chỉnh sửa vòng $round';
  }

  @override
  String timelineDeliveryApproved(String when) {
    return 'Đã đồng ý ảnh · $when';
  }

  @override
  String get timelineCheck => 'Kiểm tra bộ ảnh gốc trong 48 giờ';

  @override
  String get timelineDone => 'Hoàn thành';

  @override
  String timelinePayAtShoot(String amount) {
    return 'Trả $amount tại chỗ';
  }

  @override
  String get timelineReview => 'Đánh giá & chia sẻ ảnh';

  @override
  String get timelineDeclined => 'Đã từ chối';

  @override
  String get timelineExpired => 'Hết hạn, đã hoàn tiền';

  @override
  String timelineCancelled(String amount) {
    return 'Đã huỷ · hoàn $amount';
  }

  @override
  String countdownHours(int n) {
    return '$n giờ';
  }

  @override
  String countdownMinutes(int n) {
    return '$n phút';
  }

  @override
  String countdownSeconds(int n) {
    return '$n giây';
  }

  @override
  String detailTitle(String code) {
    return 'Buổi chụp #$code';
  }

  @override
  String detailPaidToast(String amount) {
    return 'Đã thanh toán $amount, tiền được giữ an toàn.';
  }

  @override
  String escrowNoticeHeldPhotographer(String amount) {
    return '$amount đang được giữ, chuyển cho bạn theo 2 mốc';
  }

  @override
  String get detailMessage => 'Nhắn tin';

  @override
  String get detailMore => 'Thêm thao tác';

  @override
  String get detailReschedule => 'Đổi lịch';

  @override
  String get detailDirections => 'Chỉ đường';

  @override
  String detailCancelCustomer(int pct) {
    return 'Huỷ yêu cầu · hoàn $pct%';
  }

  @override
  String get detailCancelPhotographer => 'Huỷ buổi chụp';

  @override
  String detailAccept(String time) {
    return 'Nhận · còn $time';
  }

  @override
  String get detailAcceptNow => 'Nhận';

  @override
  String get detailDecline => 'Từ chối';

  @override
  String get detailComplete => 'Hoàn thành';

  @override
  String get detailMarkShot => 'Đã chụp xong';

  @override
  String get detailDeliver => 'Nộp bàn giao';

  @override
  String detailDeliverRound(int round) {
    return 'Nộp vòng $round';
  }

  @override
  String get detailViewDelivery => 'Xem bàn giao';

  @override
  String detailRevisionCard(int round) {
    return 'Khách muốn chỉnh sửa vòng $round';
  }

  @override
  String detailWaitingApproval(int round) {
    return 'Đã gửi vòng $round · chờ khách duyệt';
  }

  @override
  String get detailApprovedProvider =>
      'Khách đã đồng ý ảnh; tiền chuyển sau 48 giờ kiểm tra';

  @override
  String detailExtraRoundTitle(String name) {
    return '$name xin thêm 1 vòng sửa';
  }

  @override
  String detailExtraRoundUsed(int total) {
    return 'Đã dùng hết $total lượt sửa miễn phí của gói.';
  }

  @override
  String get detailExtraGrant => 'Cho thêm 1 vòng';

  @override
  String get detailExtraDecline => 'Không thêm';

  @override
  String get detailExtraDeclineTitle => 'Không thêm vòng sửa?';

  @override
  String detailExtraDeclineBody(String name) {
    return '$name vẫn đồng ý ảnh được, hoặc mở khiếu nại.';
  }

  @override
  String get detailExtraGranted => 'Đã cho thêm 1 vòng sửa';

  @override
  String get detailExtraDeclined => 'Đã báo khách là không thêm vòng';

  @override
  String get detailBookAgain => 'Đặt lại';

  @override
  String get detailReview => 'Đánh giá';

  @override
  String get detailViewReview => 'Xem đánh giá';

  @override
  String get detailNotFound => 'Không tìm thấy buổi chụp';

  @override
  String get detailNotFoundBody =>
      'Buổi chụp này không còn hoặc không thuộc tài khoản của bạn.';

  @override
  String get detailGoHome => 'Về trang chủ';

  @override
  String get detailYou => 'bạn';

  @override
  String get detailErrorExpired => 'Yêu cầu đã hết hạn';

  @override
  String get detailErrorNotEligible => 'Không còn thực hiện được thao tác này';

  @override
  String get detailErrorConflict => 'Buổi chụp vừa thay đổi, đã tải lại';

  @override
  String get detailErrorNetwork => 'Không gửi được. Thử lại nhé.';

  @override
  String get cancelTitle => 'Huỷ buổi chụp?';

  @override
  String cancelTitlePhotographer(String name) {
    return 'Huỷ buổi chụp với $name?';
  }

  @override
  String get cancelKeep => 'Giữ lịch';

  @override
  String get cancelConfirm => 'Huỷ buổi chụp';

  @override
  String declineTitle(String name) {
    return 'Từ chối yêu cầu của $name?';
  }

  @override
  String get declineBack => 'Quay lại';

  @override
  String get declineConfirm => 'Từ chối';

  @override
  String cancelRow100(String when) {
    return 'Trước $when hơn 48 giờ';
  }

  @override
  String get cancelRow50 => 'Trong 24–48 giờ';

  @override
  String get cancelRow0 => 'Dưới 24 giờ';

  @override
  String get cancelRefund100 => 'Hoàn 100%';

  @override
  String get cancelRefund50 => 'Hoàn 50%';

  @override
  String get cancelRefund0 => 'Không hoàn';

  @override
  String get cancelYouGetBack => 'Bạn sẽ nhận lại';

  @override
  String get cancelReasonPlans => 'Đổi kế hoạch';

  @override
  String get cancelReasonFound => 'Tìm được thợ khác';

  @override
  String get cancelReasonOther => 'Lý do khác';

  @override
  String cancelRefundPhotographer(String name) {
    return '$name được hoàn 100%';
  }

  @override
  String get cancelReasonSick => 'Ốm/việc gấp';

  @override
  String get cancelReasonGear => 'Thiết bị gặp sự cố';

  @override
  String cancelDoneToast(String amount) {
    return 'Đã huỷ. Hoàn $amount trong 3–5 ngày';
  }

  @override
  String get cancelDoneNoRefund => 'Đã huỷ buổi chụp';

  @override
  String cancelDonePhotographer(String name) {
    return 'Đã huỷ. $name được hoàn 100%';
  }

  @override
  String get bookingsTitle => 'Đặt lịch';

  @override
  String get bookingsUpcoming => 'Sắp tới';

  @override
  String get bookingsPending => 'Đang chờ';

  @override
  String get bookingsDone => 'Đã xong';

  @override
  String get bookingsReview => 'Đánh giá';

  @override
  String get bookingsDirections => 'Chỉ đường';

  @override
  String get bookingsMessage => 'Nhắn tin';

  @override
  String get bookingsChats => 'Tin nhắn';

  @override
  String get bookingsEmptyUpcoming => 'Chưa có buổi chụp sắp tới';

  @override
  String get bookingsEmptyUpcomingBody =>
      'Buổi chụp đã được nhận sẽ hiện ở đây.';

  @override
  String get bookingsFindPhotographer => 'Tìm nhiếp ảnh gia';

  @override
  String get bookingsEmptyPending => 'Chưa có yêu cầu chờ';

  @override
  String get bookingsEmptyPendingBody =>
      'Yêu cầu đã thanh toán, đang chờ nhiếp ảnh gia nhận sẽ hiện ở đây.';

  @override
  String get bookingsEmptyDone => 'Chưa có buổi nào xong';

  @override
  String get bookingsEmptyDoneBody =>
      'Buổi chụp đã hoàn thành, đã huỷ hoặc bị từ chối sẽ hiện ở đây.';

  @override
  String get workTitle => 'Công việc';

  @override
  String workDateTitle(int weekday, String date) {
    return 'Thứ $weekday, $date';
  }

  @override
  String workDateTitleSunday(String date) {
    return 'Chủ nhật, $date';
  }

  @override
  String get workToday => 'Hôm nay';

  @override
  String get workRequests => 'Yêu cầu mới';

  @override
  String get workAccept => 'Nhận';

  @override
  String workAcceptIn(String time) {
    return 'Nhận · còn $time';
  }

  @override
  String get workDecline => 'Từ chối';

  @override
  String get workMessage => 'Nhắn tin';

  @override
  String get workDirections => 'Chỉ đường';

  @override
  String get workMonth => 'Tháng này';

  @override
  String get workHeld => 'Đang giữ';

  @override
  String get workUpcoming => 'Buổi sắp tới';

  @override
  String get workToDeliver => 'Chờ bàn giao';

  @override
  String workToDeliverShot(String day) {
    return '$day · đã chụp';
  }

  @override
  String workToDeliverRevision(int round) {
    return 'Vòng $round · khách muốn chỉnh sửa';
  }

  @override
  String get workToDeliverExtra => 'Khách xin thêm 1 vòng';

  @override
  String get workNoRequests => 'Không có yêu cầu mới';

  @override
  String workRequestMeta(String service, String when, String place) {
    return '$service · $when · $place';
  }

  @override
  String workDepositPaid(String amount) {
    return 'đã trả $amount';
  }

  @override
  String workRequestNote(String note, String deposit) {
    return '“$note” · $deposit';
  }

  @override
  String workRequestExpired(String name) {
    return 'Yêu cầu $name đã hết hạn, đã hoàn tiền';
  }

  @override
  String get workEmptyTitle => 'Buổi chụp tiếp theo bắt đầu từ đây';

  @override
  String workEmptyBodyPortfolio(int n) {
    return 'Hồ sơ có 6 ảnh và 1 gói được đặt nhiều gấp 3 lần. Bạn đang có $n ảnh.';
  }

  @override
  String get workEmptyAddPhotos => 'Thêm ảnh vào portfolio';

  @override
  String get workEmptyBodyPackage =>
      'Khách đặt lịch theo gói. Thêm một gói để nhận yêu cầu đầu tiên.';

  @override
  String get workEmptyAddPackage => 'Thêm gói';

  @override
  String get workEmptyBodySkills =>
      'Kỹ năng càng đầy đủ, hồ sơ càng được gợi ý cho đúng khách.';

  @override
  String get workEmptySkills => 'Hoàn thiện kỹ năng';

  @override
  String get workEmptyBodyShare =>
      'Hồ sơ đã sẵn sàng. Chia sẻ để khách quen tìm và đặt bạn.';

  @override
  String get workEmptyShare => 'Chia sẻ hồ sơ';

  @override
  String workAssignedBy(String studio) {
    return 'Giao bởi $studio';
  }

  @override
  String get workClosedTitle => 'Mở nhận đơn để khách đặt được bạn';

  @override
  String get workClosedBody =>
      'Bạn vẫn đăng portfolio, tạo gói và trò chuyện. Khách chỉ đặt lịch và xin báo giá sau khi bạn xác minh: số điện thoại, phí xác minh, danh tính và quy định nhận việc.';

  @override
  String get workClosedNote => 'Staff duyệt trong 24 giờ sau khi bạn gửi';

  @override
  String get workClosedStart => 'Bắt đầu nhận đơn';

  @override
  String get declineReasonBusy => 'Kín lịch hôm đó';

  @override
  String get declineReasonArea => 'Ngoài khu vực phục vụ';

  @override
  String get declineReasonService => 'Gói không phù hợp nhu cầu';

  @override
  String get declineReasonOther => 'Lý do khác';

  @override
  String declineRefundNote(String name, String amount) {
    return '$name được hoàn 100% ($amount) và nhận lý do này.';
  }

  @override
  String declineDoneToast(String name) {
    return 'Đã từ chối. $name được hoàn 100%.';
  }

  @override
  String get chatInput => 'Nhập tin nhắn…';

  @override
  String get chatSendLocation => 'Gửi vị trí';

  @override
  String get chatSendRef => 'Gửi ảnh tham khảo';

  @override
  String get chatReschedule => 'Đổi lịch';

  @override
  String get chatConfirmPlace => 'Xác nhận địa điểm';

  @override
  String chatConfirmPlaceText(String place) {
    return 'Chốt địa điểm: $place';
  }

  @override
  String get chatSendFailed => 'Gửi lại';

  @override
  String chatInquiryCap(String name) {
    return 'Bạn đã gửi 3 tin. Chờ $name trả lời để nhắn tiếp.';
  }

  @override
  String get chatReadOnly => 'Cuộc trò chuyện chỉ còn để đọc.';

  @override
  String get chatClosed => 'Cuộc trò chuyện đã đóng. Gửi tin để mở lại.';

  @override
  String get chatNotFound => 'Không tìm thấy cuộc trò chuyện';

  @override
  String get chatMe => 'Tôi';

  @override
  String get chatViewProfile => 'Xem hồ sơ';

  @override
  String get chatInquiriesOff =>
      'Nhiếp ảnh gia đang tạm tắt nhận tin hỏi trước.';

  @override
  String get chatOffline => 'Không có kết nối. Bạn vẫn xem được tin cũ.';

  @override
  String chatLocationOf(String name) {
    return 'Vị trí của $name';
  }

  @override
  String get chatLocationDenied =>
      'Không thể lấy vị trí. Vui lòng cấp quyền vị trí.';

  @override
  String get chatSysRequested =>
      'Đã thanh toán. Chờ nhiếp ảnh gia nhận trong 24 giờ.';

  @override
  String get chatSysAccepted => 'Nhiếp ảnh gia đã nhận buổi chụp.';

  @override
  String get chatSysDeclined => 'Nhiếp ảnh gia đã từ chối yêu cầu.';

  @override
  String get chatSysExpired => 'Yêu cầu đã hết hạn.';

  @override
  String get chatSysCancelled => 'Buổi chụp đã huỷ.';

  @override
  String get chatSysCompleted => 'Buổi chụp đã hoàn thành.';

  @override
  String chatRescheduleProposal(String day, String start, String end) {
    return 'Đề nghị đổi sang $day $start–$end';
  }

  @override
  String get chatRescheduleAccept => 'Chấp nhận';

  @override
  String get chatRescheduleDecline => 'Từ chối';

  @override
  String get chatRescheduleDeclineTitle => 'Từ chối đề nghị đổi lịch?';

  @override
  String get chatRescheduleAccepted => 'Đã đổi lịch thành công';

  @override
  String get chatRescheduleDeclined => 'Đã từ chối đổi lịch';

  @override
  String get chatRescheduleExpired => 'Đề nghị đổi lịch đã hết hạn';

  @override
  String get chatDayTaken => 'Ngày này đã kín';

  @override
  String get chatViewBooking => 'Xem buổi chụp';

  @override
  String get chatPhoto => 'Ảnh';

  @override
  String get chatLocation => 'Vị trí';

  @override
  String get chatsTitle => 'Tin nhắn';

  @override
  String get chatsEmptyTitle => 'Chưa có cuộc trò chuyện nào';

  @override
  String get chatsEmptyAction => 'Tìm nhiếp ảnh gia';

  @override
  String chatsYouPrefix(String text) {
    return 'Bạn: $text';
  }

  @override
  String inquiryNotEligible(String name) {
    return '$name chưa nhận tin hỏi trước';
  }

  @override
  String get providerArtist => 'Nhiếp ảnh gia';

  @override
  String get providerStudio => 'Studio';

  @override
  String get providerArtistMark => 'Nhiếp ảnh gia đã duyệt';

  @override
  String get providerStudioMark => 'Studio đã xác minh';

  @override
  String providerArtistAwards(int n) {
    return 'Nhiếp ảnh gia · $n giải';
  }

  @override
  String providerAwardsCount(int n) {
    return '$n giải';
  }

  @override
  String providerStudioDistrict(String district) {
    return 'Studio · $district';
  }

  @override
  String get albumEmptyNote => 'Trống · chưa hiện công khai';

  @override
  String get portfolioViewAlbums => 'Album';

  @override
  String get portfolioViewTimeline => 'Dòng thời gian';

  @override
  String reorderPosition(int index, int count) {
    return '$index trên $count';
  }

  @override
  String get reorderMoveUp => 'Chuyển lên';

  @override
  String get reorderMoveDown => 'Chuyển xuống';

  @override
  String get reorderMoveTop => 'Lên đầu';

  @override
  String get reorderMoveBottom => 'Xuống cuối';

  @override
  String get reorderMenu => 'Thao tác với mục này';

  @override
  String get reorderHandle => 'Giữ để kéo sắp xếp';

  @override
  String postPickSelectedOrder(int n) {
    return 'Đã chọn, thứ $n';
  }

  @override
  String postPickPosition(int index, int count) {
    return 'Bài $index trên $count';
  }

  @override
  String albumPhotoCount(int n) {
    return '$n ảnh';
  }

  @override
  String postPickInAlbum(String album) {
    return 'Đang ở album $album';
  }

  @override
  String get awardResultGold => 'Huy chương Vàng';

  @override
  String get awardResultSilver => 'Huy chương Bạc';

  @override
  String get awardResultBronze => 'Huy chương Đồng';

  @override
  String get awardResultHonorable => 'Giải Khuyến khích';

  @override
  String get awardResultFinalist => 'Top / Chung kết';

  @override
  String get awardResultExhibited => 'Chọn triển lãm';

  @override
  String get awardShortGold => 'Vàng / Nhất';

  @override
  String get awardShortSilver => 'Bạc / Nhì';

  @override
  String get awardShortBronze => 'Đồng / Ba';

  @override
  String get awardShortHonorable => 'Khuyến khích';

  @override
  String get awardShortFinalist => 'Top / Chung kết';

  @override
  String get awardShortExhibited => 'Chọn triển lãm';

  @override
  String get awardPending => 'Chờ duyệt';

  @override
  String get awardApproved => 'Đã duyệt';

  @override
  String get awardNeedsInfo => 'Bổ sung';

  @override
  String get awardRejected => 'Từ chối';

  @override
  String get awardRevoked => 'Đã thu hồi';

  @override
  String awardChipSemantics(String title, String subtitle) {
    return 'Giải thưởng: $title, $subtitle';
  }

  @override
  String awardRowSemantics(String title, String subtitle, String status) {
    return 'Giải thưởng: $title, $subtitle, trạng thái $status';
  }

  @override
  String get reviewTitle => 'Buổi chụp thế nào?';

  @override
  String get reviewText => 'Nhận xét';

  @override
  String get reviewTomato => 'Hài lòng';

  @override
  String get reviewBrick => 'Chưa hài lòng';

  @override
  String get reviewBrickShort => 'Chưa ưng';

  @override
  String reviewHits(int n) {
    return '×$n';
  }

  @override
  String get reviewTomatoLevel1 => 'Ổn';

  @override
  String get reviewTomatoLevel2 => 'Hài lòng';

  @override
  String get reviewTomatoLevel3 => 'Rất hài lòng';

  @override
  String get reviewTomatoLevel4 => 'Tuyệt vời!';

  @override
  String get reviewBrickLevel1 => 'Hơi tiếc';

  @override
  String get reviewBrickLevel2 => 'Chưa ưng';

  @override
  String get reviewBrickLevel3 => 'Thất vọng';

  @override
  String get reviewBrickLevel4 => 'Rất thất vọng';

  @override
  String get reviewReset => 'Làm lại';

  @override
  String get reviewTapMore => 'Chạm tiếp để tăng mức độ, tối đa 10';

  @override
  String get reviewPadLabel => 'Đánh giá buổi chụp';

  @override
  String reviewA11yTomato(int n) {
    return 'Ném cà chua, $n trên 10';
  }

  @override
  String reviewA11yBrick(int n) {
    return 'Ném gạch, $n trên 10';
  }

  @override
  String reviewsRatioCounts(int tomato, int brick, int count) {
    return '$tomato cà chua · $brick gạch · $count đánh giá';
  }

  @override
  String reviewsRatioSemantics(int tomato, int brick) {
    return '$tomato cà chua, $brick gạch';
  }

  @override
  String tomatoPctA11y(int pct) {
    return '$pct% cà chua';
  }

  @override
  String tomatoPctCountA11y(int pct, int count) {
    return '$pct% cà chua, $count đánh giá';
  }

  @override
  String verdictBadgeTomato(int n) {
    return 'Cà chua, $n trên 10';
  }

  @override
  String verdictBadgeBrick(int n) {
    return 'Gạch, $n trên 10';
  }

  @override
  String get reviewTextHintTomato => 'Điều bạn thích nhất ở buổi chụp';

  @override
  String get reviewTextHintBrick => 'Kể rõ điều chưa ổn để thợ cải thiện';

  @override
  String get reviewReasonsTitle => 'Điều gì chưa ổn?';

  @override
  String get reviewReasonsMin => 'Chọn ít nhất 1';

  @override
  String get reviewReasonLate => 'Đến trễ';

  @override
  String get reviewReasonNotAsPortfolio => 'Ảnh không như mẫu';

  @override
  String get reviewReasonSlowDelivery => 'Giao ảnh chậm';

  @override
  String get reviewReasonAttitude => 'Thái độ';

  @override
  String get reviewReasonPriceChanged => 'Đổi giá';

  @override
  String get reviewReasonOther => 'Khác';

  @override
  String get reviewNeedVerdict => 'Chọn cà chua hoặc gạch';

  @override
  String get reviewNeedReason => 'Chọn ít nhất một lý do';

  @override
  String get reviewTextTooShort => 'Viết ít nhất 10 ký tự';

  @override
  String get reviewShare => 'Chia sẻ ảnh bạn thích';

  @override
  String get reviewOptional => 'Tuỳ chọn';

  @override
  String reviewShareHint(String name) {
    return 'Ảnh hiện trong \'Buổi chụp thật\' trên Trang chủ và hồ sơ $name, có tag nhiếp ảnh gia';
  }

  @override
  String get reviewOnly => 'Chỉ đánh giá';

  @override
  String reviewSubmitShare(int count) {
    return 'Gửi & chia sẻ $count ảnh';
  }

  @override
  String get reviewSubmit => 'Gửi đánh giá';

  @override
  String get reviewNotYet =>
      'Buổi chụp chưa hoàn thành nên chưa đánh giá được.';

  @override
  String get reviewThanks => 'Cảm ơn bạn đã đánh giá!';

  @override
  String get reviewUploadFailed => 'Tải ảnh lỗi. Thử lại';

  @override
  String get reviewsMore => 'Xem thêm';

  @override
  String get reviewSharedLink => 'Xem ảnh đã chia sẻ';

  @override
  String get reviewAlreadyDone => 'Bạn đã đánh giá buổi chụp này.';

  @override
  String get reviewsAnonymousName => 'Khách hàng';

  @override
  String get reviewThumbLabel => 'Ảnh buổi chụp';

  @override
  String get reviewErrorForbidden => 'Bạn không thể đánh giá buổi chụp này.';

  @override
  String reviewPhotoUploading(int index, int percent) {
    return 'Ảnh $index đang tải lên, $percent%';
  }

  @override
  String get setupTypeHeading => 'Bạn nhận việc với tư cách';

  @override
  String get setupTypeIndividual => 'Cá nhân';

  @override
  String get setupTypeIndividualBody =>
      'Bạn tự chụp và nhận booking. Có giải thưởng? Thêm sau để lên hạng Nhiếp ảnh gia (NAG).';

  @override
  String get setupTypeStudio => 'Studio';

  @override
  String get setupTypeStudioBody =>
      'Cơ sở kinh doanh chụp ảnh, có địa chỉ. Thêm thành viên: sắp có.';

  @override
  String get setupTypeNote =>
      'Đổi Cá nhân ↔ Studio được trong Cài đặt khi không còn booking đang chạy.';

  @override
  String get setupStudioName => 'Tên studio';

  @override
  String get setupStudioAddress => 'Địa chỉ cơ sở';

  @override
  String get setupStudioLine => 'Số nhà, đường';

  @override
  String get setupStudioWard => 'Phường / xã';

  @override
  String get setupStudioDistrict => 'Quận / huyện';

  @override
  String get setupStudioCity => 'Tỉnh / thành phố';

  @override
  String get setupStudioLineError => 'Nhập số nhà, đường (ít nhất 5 ký tự).';

  @override
  String get setupStudioWardError => 'Phường / xã tối đa 60 ký tự.';

  @override
  String get setupStudioDistrictError => 'Nhập quận / huyện.';

  @override
  String get setupStudioCityError => 'Nhập tỉnh / thành phố.';

  @override
  String get setupStudioAddressNote =>
      'Khách chỉ thấy tới quận; địa chỉ đầy đủ hiện sau khi đã đặt.';

  @override
  String get providerNotEligible =>
      'Còn booking chưa xong hoặc tiền đang giữ. Hoàn tất chúng trước khi đổi.';

  @override
  String get settingsProviderType => 'Hình thức nhận việc';

  @override
  String get settingsProviderArtist => 'Cá nhân · Nhiếp ảnh gia';

  @override
  String get providerTypeSave => 'Lưu';

  @override
  String get providerTypeKeep => 'Giữ nguyên';

  @override
  String get providerLoseArtistBody =>
      'Đổi sang Studio sẽ bỏ hạng Nhiếp ảnh gia. Giải thưởng vẫn giữ.';

  @override
  String get providerLoseArtistConfirm => 'Đổi sang Studio';

  @override
  String get createAlbumLabel => 'Album · tuỳ chọn';

  @override
  String get albumPickTitle => 'Xếp vào album';

  @override
  String get albumPickNone => 'Không xếp album';

  @override
  String get albumPickNoneSub => 'Chỉ hiện ở Dòng thời gian';

  @override
  String albumPickCount(int n) {
    return '$n bài';
  }

  @override
  String get albumPickRecent => 'dùng gần nhất';

  @override
  String get albumPickNew => 'Album mới';

  @override
  String get albumPickCreate => 'Tạo';

  @override
  String get albumPickDup => 'Bạn đã có album tên này';

  @override
  String get albumPickLimit => 'Bạn đã có đủ 30 album.';

  @override
  String get albumPickCreateError => 'Không tạo được album. Thử lại sau.';

  @override
  String get albumPickLoadError => 'Không tải được danh sách album.';

  @override
  String portfolioAlbumCount(int n) {
    return '$n album';
  }

  @override
  String get portfolioArrange => 'Sắp xếp';

  @override
  String albumDetailCounts(int posts, int photos) {
    return '$posts bài · $photos ảnh';
  }

  @override
  String get albumDetailEmptyOwner => 'Album chưa có bài';

  @override
  String get albumDetailEmptyOwnerBody =>
      'Thêm bài để album hiện trên hồ sơ của bạn.';

  @override
  String get albumDetailAddPosts => 'Thêm bài';

  @override
  String get albumDetailGone => 'Album này không còn';

  @override
  String get albumDetailGoneBody =>
      'Album có thể đã bị xoá hoặc chưa có bài nào.';

  @override
  String get albumDetailShare => 'Chia sẻ album';

  @override
  String get albumDetailLinkCopied => 'Đã sao chép liên kết album';

  @override
  String get albumDetailMenu => 'Tuỳ chọn album';

  @override
  String get albumDetailArrange => 'Sắp xếp bài';

  @override
  String get albumDetailArrangeDone => 'Xong';

  @override
  String get albumDetailRemove => 'Bỏ khỏi album';

  @override
  String get albumDetailRemoveFailed => 'Chưa bỏ được bài khỏi album.';

  @override
  String get albumDetailDelete => 'Xoá album';

  @override
  String get albumDetailDeleteTitle => 'Xoá album này?';

  @override
  String get albumDetailDeleteBody =>
      'Bài trong album không bị xoá, chuyển về Chưa xếp album.';

  @override
  String get albumDetailDeleteError => 'Không xoá được album. Thử lại sau.';

  @override
  String get albumDetailReordered => 'Đã đổi thứ tự';

  @override
  String get albumDetailReorderFailed => 'Chưa lưu được thứ tự';

  @override
  String get albumDetailUndo => 'Hoàn tác';

  @override
  String get albumDetailArrangeLoadFailed =>
      'Chưa tải hết bài để sắp xếp. Thử lại sau.';

  @override
  String get profileMyAlbums => 'Album của tôi';

  @override
  String get profileMyAlbumsSub =>
      'Gom bài thành album, sắp xếp thứ tự trên hồ sơ';

  @override
  String get myAlbumsTitle => 'Album của tôi';

  @override
  String get myAlbumsHint =>
      'Thứ tự dưới đây là thứ tự trên hồ sơ. Giữ ≡ rồi kéo, hoặc chạm … → Chuyển lên / xuống.';

  @override
  String get myAlbumsFeatured => 'hiện rộng';

  @override
  String get myAlbumsUnsorted => 'Chưa xếp album';

  @override
  String myAlbumsUnsortedSub(String n) {
    return '$n bài · chỉ ở Dòng thời gian';
  }

  @override
  String get myAlbumsEmptyTitle => 'Gom bài thành album để khách xem theo bộ';

  @override
  String get myAlbumsEmptyBody =>
      'Bài chưa xếp album vẫn hiện ở Dòng thời gian.';

  @override
  String get myAlbumsOpen => 'Xem album';

  @override
  String get myAlbumsEdit => 'Sửa';

  @override
  String get albumEditNew => 'Album mới';

  @override
  String get albumEditTitle => 'Sửa album';

  @override
  String get albumEditClose => 'Đóng';

  @override
  String get albumEditName => 'Tên album · bắt buộc';

  @override
  String albumEditNameCount(int n, int max) {
    return '$n / $max';
  }

  @override
  String get albumEditNameRequired => 'Nhập tên album';

  @override
  String get albumEditDesc => 'Mô tả · tuỳ chọn';

  @override
  String get albumEditCover => 'Ảnh bìa';

  @override
  String get albumEditCoverAuto => 'Tự động: ảnh đầu tiên của album';

  @override
  String get albumEditCoverChosen => 'Đã chọn một ảnh làm bìa';

  @override
  String get albumEditCoverPick => 'Chọn ảnh';

  @override
  String get albumEditCoverTitle => 'Chọn ảnh bìa';

  @override
  String get albumEditCoverReset => 'Dùng ảnh tự động';

  @override
  String get albumEditCoverLoadError => 'Không tải được ảnh của album.';

  @override
  String albumEditCoverTile(int index, int count) {
    return 'Ảnh $index trên $count';
  }

  @override
  String get albumEditNote =>
      'Album trống chưa hiện trên hồ sơ. Thêm bài ngay sau khi tạo.';

  @override
  String get albumEditCreate => 'Tạo và thêm bài';

  @override
  String get albumEditSave => 'Lưu';

  @override
  String get albumEditSaveError => 'Chưa lưu được album. Thử lại sau.';

  @override
  String get albumEditDiscardTitle => 'Bỏ thay đổi?';

  @override
  String get albumEditDiscardBody => 'Những gì bạn vừa nhập sẽ mất.';

  @override
  String get albumEditDiscard => 'Bỏ';

  @override
  String get albumEditKeep => 'Tiếp tục sửa';

  @override
  String get addPostsTitle => 'Thêm bài vào album';

  @override
  String addPostsSelected(int n) {
    return '$n đã chọn';
  }

  @override
  String addPostsTabUnsorted(String n) {
    return 'Chưa xếp · $n';
  }

  @override
  String addPostsTabAll(String n) {
    return 'Tất cả bài · $n';
  }

  @override
  String addPostsMoveWarn(int n, String album) {
    return '$n bài đang ở \"$album\" sẽ chuyển sang album này.';
  }

  @override
  String addPostsMoveWarnMany(int n) {
    return '$n bài đang ở album khác sẽ chuyển sang album này.';
  }

  @override
  String addPostsAdd(int n) {
    return 'Thêm $n bài';
  }

  @override
  String get addPostsPick => 'Chọn bài để thêm';

  @override
  String get addPostsFull => 'Album đã đủ 200 bài';

  @override
  String get addPostsNoneTitle => 'Đăng bài trước';

  @override
  String get addPostsNoneBody => 'Bài bạn đăng sẽ hiện ở đây để xếp vào album.';

  @override
  String get addPostsNoneAction => 'Đăng bài';

  @override
  String get addPostsUnsortedEmpty => 'Mọi bài của bạn đã nằm trong album.';

  @override
  String get addPostsLoadError => 'Không tải được bài. Thử lại sau.';

  @override
  String get addPostsError => 'Chưa thêm được bài. Thử lại sau.';

  @override
  String addPostsPartial(int done, int left) {
    return 'Đã thêm $done bài, còn $left bài chưa thêm được.';
  }

  @override
  String get addPostsMore => 'Xem thêm bài';

  @override
  String get myAlbumsUnsortedSubUnknown =>
      'Bài chưa xếp · chỉ ở Dòng thời gian';

  @override
  String get s2501Title => 'Giải thưởng';

  @override
  String get s2501Info => 'Về hạng Nhiếp ảnh gia';

  @override
  String get s2501InfoBody =>
      'Khi có ít nhất 3 giải đã được duyệt, hồ sơ Cá nhân của bạn tự lên hạng Nhiếp ảnh gia và có tích vàng. Hồ sơ Studio vẫn khai giải được nhưng không tính hạng. Nếu số giải đã duyệt xuống dưới 3, hạng quay về Cá nhân. Chỉ giải đã duyệt hiện trên hồ sơ công khai.';

  @override
  String get s2501InfoClose => 'Đã hiểu';

  @override
  String get s2501Tier => 'Hạng Nhiếp ảnh gia (NAG)';

  @override
  String s2501Remaining(int n) {
    return 'Còn $n giải đã duyệt nữa để nhận tích vàng';
  }

  @override
  String s2501IsArtist(String date) {
    return 'Bạn là Nhiếp ảnh gia · từ $date';
  }

  @override
  String get s2501IsArtistNoDate => 'Bạn là Nhiếp ảnh gia';

  @override
  String s2501Progress(int a, int n) {
    return '$a / $n giải đã duyệt';
  }

  @override
  String get s2501ListedTitle => 'Đã khai';

  @override
  String s2501ListedCount(int n) {
    return '$n giải';
  }

  @override
  String get s2501Add => 'Thêm giải thưởng';

  @override
  String get s2501EmptyTitle => 'Giải thưởng giúp khách tin tác phẩm của bạn';

  @override
  String get s2501EmptyBody =>
      'Khai giải kèm minh chứng. Giải được duyệt sẽ hiện trên hồ sơ của bạn.';

  @override
  String get s2501LoadError => 'Không tải được giải thưởng. Thử lại sau.';

  @override
  String s2501RowTitle(String result, String competition, int year) {
    return '$result · $competition $year';
  }

  @override
  String s2501Sent(String date) {
    return 'gửi $date';
  }

  @override
  String get s2501DeleteTitle => 'Xoá giải thưởng?';

  @override
  String get s2501DeleteBody => 'Giải và minh chứng đã tải lên sẽ bị xoá.';

  @override
  String get s2501Delete => 'Xoá';

  @override
  String get s2501DeleteError => 'Chưa xoá được giải. Thử lại sau.';

  @override
  String get s2501EditApprovedTitle => 'Sửa giải đã duyệt?';

  @override
  String get s2501EditApprovedBody =>
      'Giải sẽ được duyệt lại. Trong lúc chờ, giải ẩn khỏi hồ sơ công khai và không tính vào hạng.';

  @override
  String get s2501EditApprovedGo => 'Tiếp tục sửa';

  @override
  String get s2502Add => 'Thêm giải thưởng';

  @override
  String get s2502Edit => 'Sửa giải thưởng';

  @override
  String get s2502Competition => 'Cuộc thi / triển lãm · bắt buộc';

  @override
  String get s2502CompetitionRequired => 'Nhập tên cuộc thi hoặc triển lãm';

  @override
  String get s2502Year => 'Năm';

  @override
  String s2502YearInvalid(int max) {
    return 'Năm từ 1950 đến $max';
  }

  @override
  String get s2502Category => 'Hạng mục';

  @override
  String get s2502Result => 'Kết quả · bắt buộc';

  @override
  String get s2502Work => 'Tác phẩm · tuỳ chọn';

  @override
  String get s2502WorkNone => 'Không gắn tác phẩm';

  @override
  String get s2502WorkChosen => 'Đã chọn một tác phẩm';

  @override
  String get s2502WorkTitle => 'Chọn tác phẩm';

  @override
  String get s2502WorkClear => 'Bỏ chọn tác phẩm';

  @override
  String get s2502WorkEmpty => 'Bạn chưa có bài nào để gắn.';

  @override
  String get s2502WorkLoadError => 'Không tải được bài của bạn. Thử lại sau.';

  @override
  String get s2502Proof => 'Minh chứng · bắt buộc';

  @override
  String get s2502ProofNone =>
      'Thêm ảnh giấy chứng nhận hoặc link trang công bố';

  @override
  String s2502ProofSummary(int images, int links) {
    return '$images ảnh · $links link';
  }

  @override
  String get s2502ProofTitle => 'Minh chứng';

  @override
  String s2502ProofImages(int n, int max) {
    return 'Ảnh giấy chứng nhận · $n / $max';
  }

  @override
  String get s2502ProofAddImage => 'Thêm ảnh';

  @override
  String s2502ProofLinks(int max) {
    return 'Link trang công bố · tối đa $max';
  }

  @override
  String get s2502ProofAddLink => 'Thêm link';

  @override
  String get s2502LinkLabel => 'Link';

  @override
  String get s2502LinkHttps => 'Link phải bắt đầu bằng https://';

  @override
  String get s2502LinkRemove => 'Xoá link';

  @override
  String get s2502ProofDone => 'Xong';

  @override
  String s2502TileUploading(int n) {
    return 'Đang tải ảnh $n';
  }

  @override
  String s2502TileFailed(int n) {
    return 'Chưa tải được ảnh $n. Chạm để thử lại';
  }

  @override
  String s2502TileDone(int n) {
    return 'Ảnh $n đã tải';
  }

  @override
  String s2502TileSaved(int n) {
    return 'Ảnh $n đã gửi trước đó';
  }

  @override
  String s2502TileRemove(int n) {
    return 'Xoá ảnh $n';
  }

  @override
  String get s2502Privacy =>
      'Minh chứng chỉ đội duyệt xem và được xoá 30 ngày sau khi duyệt xong. Duyệt trong 3 ngày làm việc.';

  @override
  String get s2502Submit => 'Gửi duyệt';

  @override
  String get s2502SubmitWait =>
      'Đợi ảnh tải xong hoặc xoá ảnh lỗi trước khi gửi.';

  @override
  String get s2502LoadError => 'Không mở được giải này. Thử lại sau.';

  @override
  String get s2502SubmitError => 'Chưa gửi được. Thử lại sau.';

  @override
  String get s2502SubmitLimit => 'Bạn đã khai tối đa 50 giải.';

  @override
  String get s2502SubmitRejected =>
      'Thông tin chưa hợp lệ. Kiểm tra lại các ô.';

  @override
  String get settingsAwards => 'Giải thưởng';

  @override
  String get settingsAwardsBody => 'Khai giải để lên hạng Nhiếp ảnh gia';

  @override
  String get profileAwardNudge => 'Có giải thưởng? Lên hạng Nhiếp ảnh gia';

  @override
  String get profileAwardNudgeLater => 'Để sau';

  @override
  String get profileStatAwards => 'giải thưởng';

  @override
  String profileAwardSub(String competition, int year) {
    return '$competition $year';
  }

  @override
  String profileAwardSubCategory(
    String competition,
    int year,
    String category,
  ) {
    return '$competition $year · $category';
  }

  @override
  String profileAwardsMore(int n) {
    return 'Xem cả $n giải';
  }

  @override
  String get notifSettingsTooltip => 'Cài đặt thông báo';

  @override
  String get notifTabAll => 'Tất cả';

  @override
  String get notifTabBooking => 'Đặt lịch';

  @override
  String get notifTabWork => 'Công việc';

  @override
  String get notifTabEvents => 'Sự kiện';

  @override
  String get notifTabSystem => 'Hệ thống';

  @override
  String notifUnreadHeader(int n) {
    return '$n chưa đọc';
  }

  @override
  String get notifMarkAllRead => 'Đánh dấu tất cả đã đọc';

  @override
  String get notifSectionToday => 'Hôm nay';

  @override
  String get notifSectionWeek => '7 ngày qua';

  @override
  String get notifSectionEarlier => 'Trước đó';

  @override
  String get notifEmptyTitle => 'Chưa có thông báo nào';

  @override
  String get notifEmptyBody =>
      'Lịch hẹn, tin nhắn và huy hiệu của bạn sẽ hiện ở đây.';

  @override
  String get notifEmptyCtaCustomer => 'Khám phá nhiếp ảnh gia';

  @override
  String get notifEmptyCtaPhotographer => 'Mở Công việc';

  @override
  String notifEmptyFiltered(String tab) {
    return 'Chưa có thông báo nào trong mục $tab';
  }

  @override
  String get notifEmptyFilteredBody => 'Chọn mục khác để xem thêm.';

  @override
  String get notifTargetGone => 'Nội dung này không còn';

  @override
  String get notifMuted => 'Đã tắt loại thông báo này';

  @override
  String get notifUndo => 'Hoàn tác';

  @override
  String get notifTimeNow => 'Vừa xong';

  @override
  String notifTimeMinutes(int n) {
    return '$n phút';
  }

  @override
  String notifTimeHours(int n) {
    return '$n giờ';
  }

  @override
  String get notifTimeYesterday => 'Hôm qua';

  @override
  String notifTimeDays(int n) {
    return '$n ngày';
  }

  @override
  String notifRowSemantics(int n, String title) {
    return 'Thông báo, $n thông báo chưa đọc, $title';
  }

  @override
  String notifRowSemanticsRead(String title) {
    return 'Thông báo, $title';
  }

  @override
  String get notifLoadMoreError => 'Chưa tải thêm được. Kéo xuống để thử lại.';

  @override
  String get settingsNotificationsBody => 'Push, giờ yên lặng, nhắc buổi chụp';

  @override
  String get notifSettingsOsOffTitle => 'Thông báo đang tắt trên máy';

  @override
  String get notifSettingsOsOffBody =>
      'Bạn sẽ không nhận push cho tới khi bật lại.';

  @override
  String get notifSettingsOpenSettings => 'Mở Cài đặt';

  @override
  String get notifSettingsColType => 'Loại';

  @override
  String get notifSettingsColPush => 'Push';

  @override
  String get notifSettingsColInApp => 'Trong app';

  @override
  String get notifSettingsPushOffOs => 'Đang tắt trên máy';

  @override
  String get notifSettingsCatBooking => 'Đặt lịch và thanh toán';

  @override
  String get notifSettingsCatJobs => 'Việc đăng tuyển';

  @override
  String get notifSettingsCatInstant => 'Chụp ngay';

  @override
  String get notifSettingsCatEvents => 'Sự kiện';

  @override
  String get notifSettingsCatChat => 'Tin nhắn';

  @override
  String get notifSettingsCatBadges => 'Huy hiệu và đánh giá';

  @override
  String get notifSettingsCatPromo => 'Khuyến mãi';

  @override
  String notifSwitchOn(String group, String channel) {
    return '$group, $channel, bật';
  }

  @override
  String notifSwitchOff(String group, String channel) {
    return '$group, $channel, tắt';
  }

  @override
  String notifSwitchLocked(String group, String channel) {
    return '$group, $channel, luôn bật';
  }

  @override
  String get notifSettingsQuietTitle => 'Giờ yên lặng';

  @override
  String notifSettingsQuietLine(String from, String to) {
    return '$from–$to · chỉ thông báo quan trọng vẫn có âm';
  }

  @override
  String get notifSettingsQuietSwitchOn => 'Giờ yên lặng, bật';

  @override
  String get notifSettingsQuietSwitchOff => 'Giờ yên lặng, tắt';

  @override
  String get notifSettingsPickFrom => 'Yên lặng từ';

  @override
  String get notifSettingsPickTo => 'Yên lặng đến';

  @override
  String get notifSettingsRemindersTitle => 'Nhắc buổi chụp';

  @override
  String get notifSettingsReminder24 => '24 giờ';

  @override
  String get notifSettingsReminder2 => '2 giờ';

  @override
  String get notifSettingsSaveError => 'Không lưu được, thử lại';

  @override
  String primerTitleCustomerBooking(String name) {
    return 'Bật thông báo để biết khi $name nhận lịch';
  }

  @override
  String primerTitleCustomerTicket(String event) {
    return 'Bật thông báo để được nhắc trước khi $event bắt đầu';
  }

  @override
  String get primerTicketBenefit1 =>
      'Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung';

  @override
  String get primerTitleCustomerInstant =>
      'Bật thông báo để biết khi có người nhận chụp ngay';

  @override
  String get primerTitlePhotographer =>
      'Bật thông báo để không bỏ lỡ lời mời việc';

  @override
  String get primerBenefit1 => 'Biết ngay khi lịch được nhận hoặc thay đổi';

  @override
  String get primerBenefit2 => 'Nhắc trước giờ chụp, không lỡ hẹn';

  @override
  String get primerBenefit3 => 'Tin nhắn mới khi app đang ở nền';

  @override
  String get primerNote => 'Chọn \"Để sau\", chúng tôi sẽ hỏi lại sau 7 ngày.';

  @override
  String get primerEnabled => 'Đã bật thông báo';

  @override
  String get badgesTitle => 'Huy hiệu';

  @override
  String get badgesFromReviews => 'Từ đánh giá';

  @override
  String get badgesFromSystem => 'Từ hệ thống';

  @override
  String badgesFraction(int a, int b) {
    return '$a / $b';
  }

  @override
  String badgesSectionSemantics(String title, int a, int b) {
    return '$title, đạt $a trên $b';
  }

  @override
  String get badgesEmptyTitle => 'Chưa có huy hiệu nào';

  @override
  String get badgesEmptyBody =>
      'Huy hiệu sẽ hiện ở đây khi người này đạt được.';

  @override
  String get badgesLoadError => 'Không tải được huy hiệu';

  @override
  String badgesNearest(String name, int cur, int target) {
    return 'Gần đạt nhất: $name · $cur / $target';
  }

  @override
  String badgesAwardedOn(String date) {
    return 'Đạt ngày $date';
  }

  @override
  String badgesSheetProgress(int cur, int target) {
    return '$cur / $target';
  }

  @override
  String get earningsTitle => 'Thu nhập';

  @override
  String get earningsNotice =>
      'Chi tự động mỗi ngày · lần chi đầu do staff duyệt · phí chuyển do nền tảng trả';

  @override
  String get earningsHeld => 'Đang giữ';

  @override
  String get earningsSoon => 'Chờ chi trả';

  @override
  String get earningsReceived => 'Đã nhận';

  @override
  String get earningsStateHeld => 'Đang giữ';

  @override
  String get earningsStateReleased => 'Chờ chi trả';

  @override
  String get earningsStatePaid => 'Đã chuyển';

  @override
  String get earningsStateDispute => 'Đang khiếu nại';

  @override
  String get earningsAddAccount => 'Thêm tài khoản để nhận tiền';

  @override
  String get earningsAddAccountSub => 'Cần có trước khi chuyển khoản';

  @override
  String get earningsItems => 'Các khoản';

  @override
  String earningsMonth(int month) {
    return 'Tháng $month';
  }

  @override
  String earningsMonthYear(int month, int year) {
    return 'Tháng $month/$year';
  }

  @override
  String get earningsPayoutFailed => 'Chuyển khoản lỗi, kiểm tra tài khoản';

  @override
  String earningsHoldReason(String reason) {
    return 'Lý do: $reason';
  }

  @override
  String get earningsHoldDispute => 'Khách đã báo vấn đề, đang chờ xử lý';

  @override
  String get earningsHoldPayoutOnHold => 'Lô chi trả đang tạm giữ';

  @override
  String get earningsCustomerFallback => 'Khách';

  @override
  String get earningsEmptyTitle => 'Chưa có khoản thu nào';

  @override
  String get earningsEmptyBody =>
      'Khoản đầu tiên hiện ở đây khi khách đặt lịch và thanh toán.';

  @override
  String get earningsMore => 'Xem thêm';

  @override
  String get earningsLoadError => 'Không tải được thu nhập';

  @override
  String get earningsBreakdownReleased => 'Đã chuyển theo mốc';

  @override
  String get earningsBreakdownPaidOn => 'Ngày chuyển';

  @override
  String get earningsBreakdownAmount => 'Số tiền';

  @override
  String earningsBreakdownFee(String percent) {
    return 'Hoa hồng ($percent)';
  }

  @override
  String earningsBreakdownTax(String percent) {
    return 'Thuế khấu trừ ($percent)';
  }

  @override
  String get earningsBreakdownNet => 'Thực nhận';

  @override
  String get earningsBreakdownNetEstimated => 'Thực nhận dự kiến';

  @override
  String earningsMilestones(int done, int total) {
    return 'mốc $done/$total';
  }

  @override
  String earningsMilestonesAll(int total) {
    return 'đủ $total mốc';
  }

  @override
  String get payoutAccountTitle => 'Tài khoản nhận tiền';

  @override
  String get profileEarnings => 'Thu nhập';

  @override
  String get profileEarningsSub => 'Tiền đang giữ, sắp nhận và đã nhận';

  @override
  String get payoutAccountIntro =>
      'Nhập tài khoản đứng tên bạn, tiền sẽ chi tự động vào đây.';

  @override
  String get payoutAccountBank => 'Ngân hàng';

  @override
  String get payoutAccountBankPick => 'Chọn ngân hàng';

  @override
  String get payoutAccountBankSearch => 'Tìm ngân hàng';

  @override
  String get payoutAccountBankNone => 'Không tìm thấy ngân hàng';

  @override
  String get payoutAccountNumber => 'Số tài khoản';

  @override
  String get payoutAccountSave => 'Lưu tài khoản';

  @override
  String get payoutAccountHint =>
      'Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài khoản được mã hoá, chỉ hiện 4 số cuối.';

  @override
  String payoutAccountMasked(String last4) {
    return '•••• $last4';
  }

  @override
  String get payoutAccountChange => 'Đổi tài khoản';

  @override
  String get payoutAccountNumberError => 'Số tài khoản gồm 6–20 chữ số';

  @override
  String get payoutAccountSaved => 'Đã lưu tài khoản nhận tiền';

  @override
  String get payoutAccountSaveError => 'Không lưu được. Thử lại';

  @override
  String get payoutAccountBusy =>
      'Đang chuyển một lô tiền, thử lại sau ít phút';

  @override
  String payoutAccountIntroChange(String bank, String last4) {
    return 'Đang dùng $bank •••• $last4. Nhập tài khoản mới đứng tên bạn, tiền sẽ chi tự động vào đây.';
  }

  @override
  String get payoutAccountChangeNote =>
      'Đổi tài khoản cần OTP và có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi. Tài khoản cũ sẽ nhận thông báo.';

  @override
  String get payoutAccountSameAccount => 'Đây đã là tài khoản đang dùng';

  @override
  String get payoutLookupLoading => 'Đang tra tên chủ tài khoản…';

  @override
  String get payoutLookupMatched => 'Khớp tên đã xác minh';

  @override
  String get payoutLookupMismatch => 'Không khớp';

  @override
  String payoutLookupMismatchTitle(String name) {
    return 'Tên chủ tài khoản không khớp tên đã xác minh ($name)';
  }

  @override
  String get payoutLookupMismatchBody =>
      'Chỉ chi tiền vào tài khoản đứng tên bạn. Kiểm tra lại ngân hàng và số tài khoản.';

  @override
  String get payoutLookupReview => 'Ngân hàng chưa hỗ trợ tra tên';

  @override
  String get payoutLookupReviewSub => 'Staff đối chiếu tên trước lần chi đầu';

  @override
  String get payoutLookupNotFound =>
      'Không tìm thấy tài khoản. Kiểm tra lại số tài khoản.';

  @override
  String get payoutLookupUnverifiable =>
      'Cần xác minh danh tính trước khi thêm tài khoản ở ngân hàng này';

  @override
  String get payoutLookupLimit =>
      'Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.';

  @override
  String get payoutLookupError => 'Không tra được tên. Thử lại';

  @override
  String get payoutOtpTitle => 'Nhập mã xác nhận';

  @override
  String payoutOtpBody(String last4) {
    return 'Mã 6 số đã gửi tới số điện thoại •••• $last4. Mã có hiệu lực 5 phút.';
  }

  @override
  String get payoutOtpField => 'Mã OTP';

  @override
  String get payoutOtpConfirm => 'Xác nhận đổi tài khoản';

  @override
  String get payoutOtpResend => 'Gửi lại mã';

  @override
  String payoutOtpResendIn(int seconds) {
    return 'Gửi lại sau $seconds giây';
  }

  @override
  String get payoutOtpNote =>
      'Tài khoản mới có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi.';

  @override
  String get payoutOtpWrong => 'Mã chưa đúng. Kiểm tra lại tin nhắn';

  @override
  String get payoutOtpExpired => 'Mã đã hết hạn. Gửi lại mã mới';

  @override
  String get payoutOtpTooMany =>
      'Bạn đã nhập sai quá nhiều lần. Gửi lại mã mới';

  @override
  String get payoutOtpLimit =>
      'Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.';

  @override
  String get payoutPhoneRequired => 'Cần số điện thoại trong hồ sơ để nhận mã';

  @override
  String get payoutOtpUnavailable =>
      'Chưa đổi được tài khoản lúc này. Liên hệ hỗ trợ';

  @override
  String payoutAccountPendingTitle(String time) {
    return 'Tài khoản mới có hiệu lực lúc $time';
  }

  @override
  String get payoutAccountPendingBody =>
      'Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do staff duyệt.';

  @override
  String get payoutAccountPendingBadge => 'Chờ hiệu lực';

  @override
  String get payoutAccountReviewNote =>
      'Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu.';

  @override
  String get payoutAccountChangeSaved =>
      'Đã đổi tài khoản. Có hiệu lực sau 72 giờ';

  @override
  String get reauthTitle => 'Xác nhận lại để tiếp tục';

  @override
  String get reauthBody => 'Vì an toàn, hãy đăng nhập lại trước khi tiếp tục.';

  @override
  String get reauthPassword => 'Mật khẩu';

  @override
  String get reauthGo => 'Xác nhận';

  @override
  String get reauthWrong => 'Mật khẩu chưa đúng';

  @override
  String get eventHostPlatform => 'Do ứng dụng tổ chức';

  @override
  String get eventsTitle => 'Sự kiện';

  @override
  String get eventsAll => 'Tất cả';

  @override
  String get eventsSortSoonest => 'Sớm nhất';

  @override
  String get eventsSortNear => 'Gần tôi';

  @override
  String get eventsEmpty => 'Chưa có sự kiện';

  @override
  String get eventsEmptyBody => 'Sự kiện chụp ảnh mới sẽ hiện ở đây.';

  @override
  String get eventsCreate => 'Tạo sự kiện';

  @override
  String get eventsNeedArea => 'Chọn khu vực để xem sự kiện gần bạn';

  @override
  String get eventsMyTickets => 'Vé của tôi';

  @override
  String get eventJoin => 'Đăng ký tham gia';

  @override
  String get eventPerPerson => 'mỗi người';

  @override
  String get eventViewTicket => 'Xem vé';

  @override
  String get eventManage => 'Quản lý';

  @override
  String get eventCancelled => 'Sự kiện đã huỷ';

  @override
  String get eventEnded => 'Sự kiện đã kết thúc';

  @override
  String get eventClosed => 'Đã đóng đăng ký';

  @override
  String get eventPaymentsSoon => 'Sắp mở thanh toán';

  @override
  String get eventTabInfo => 'Thông tin';

  @override
  String get eventTabTimeline => 'Timeline';

  @override
  String get eventTabChat => 'Nhóm chat';

  @override
  String get eventHostRole => 'Chủ sự kiện';

  @override
  String get eventProfile => 'Hồ sơ';

  @override
  String eventMeetingPoint(String place) {
    return 'Điểm hẹn: $place';
  }

  @override
  String eventCapacityLeft(int n) {
    return 'Còn $n chỗ';
  }

  @override
  String get eventGone => 'Sự kiện không còn';

  @override
  String get eventGoneBody => 'Sự kiện này đã bị xoá hoặc chưa được đăng.';

  @override
  String get eventLinkCopied => 'Đã sao chép liên kết';

  @override
  String get eventShareTooltip => 'Chia sẻ sự kiện';

  @override
  String eventWeekdayLong(String weekday) {
    String _temp0 = intl.Intl.selectLogic(weekday, {
      '1': 'Thứ hai',
      '2': 'Thứ ba',
      '3': 'Thứ tư',
      '4': 'Thứ năm',
      '5': 'Thứ sáu',
      '6': 'Thứ bảy',
      'other': 'Chủ nhật',
    });
    return '$_temp0';
  }

  @override
  String get eventFaqTitle => 'Câu hỏi thường gặp';

  @override
  String eventSupportLine(String email) {
    return 'Cần hỏi thêm? Gửi email tới $email';
  }

  @override
  String get eventChatLocked => 'Đăng ký để vào nhóm';

  @override
  String get eventChatLockedBody =>
      'Chỉ người đã đăng ký mới vào được nhóm chat của sự kiện.';

  @override
  String get eventChatSoon => 'Nhóm chat sắp mở';

  @override
  String get eventTimelineSoon => 'Timeline sắp mở';

  @override
  String get eventsManage => 'Sự kiện của tôi';

  @override
  String get eventRegisterTitle => 'Đăng ký tham gia';

  @override
  String get registerTickets => 'Số vé';

  @override
  String registerTicketsHint(int n) {
    return 'Tối đa 4 vé, còn $n chỗ';
  }

  @override
  String get registerName => 'Họ tên người tham gia';

  @override
  String get registerNameError => 'Nhập họ tên, tối đa 60 ký tự';

  @override
  String get registerPhone => 'Số điện thoại';

  @override
  String get registerChangePhone => 'Đổi';

  @override
  String get registerFree => 'Xác nhận đăng ký';

  @override
  String get registerSoldOut => 'Hết chỗ';

  @override
  String get registerDone => 'Đã đăng ký';

  @override
  String get registerOpenChat => 'Vào nhóm chat';

  @override
  String get registerError => 'Chưa đăng ký được. Kiểm tra mạng rồi thử lại.';

  @override
  String get registerLess => 'Bớt một vé';

  @override
  String get registerMore => 'Thêm một vé';

  @override
  String get ticketsTab => 'Vé sự kiện';

  @override
  String get bookingsTabShoots => 'Buổi chụp';

  @override
  String get ticketCode => 'Mã vé';

  @override
  String ticketCancelRefund(int pct) {
    return 'Huỷ vé · hoàn $pct%';
  }

  @override
  String get ticketCancelNoRefund => 'Huỷ vé · không hoàn tiền';

  @override
  String get ticketAttended => 'Đã tham gia';

  @override
  String get ticketRefunded => 'Đã hoàn tiền';

  @override
  String get ticketRefunding => 'Đang hoàn';

  @override
  String get ticketShowHint => 'Đưa mã này cho chủ sự kiện khi đến điểm hẹn.';

  @override
  String get ticketsEmpty => 'Chưa có vé sự kiện';

  @override
  String get ticketsBrowse => 'Xem sự kiện';

  @override
  String ticketCancelConfirmTitle(String event) {
    return 'Huỷ vé $event?';
  }

  @override
  String get ticketCancelFreeBody => 'Chỗ của bạn sẽ được nhả cho người khác.';

  @override
  String ticketCancelRefundBody(int pct) {
    return 'Bạn được hoàn $pct% tiền vé.';
  }

  @override
  String get ticketCancelNoRefundBody =>
      'Còn dưới 48 giờ nên không được hoàn tiền vé. Tiền vé được giữ tới khi sự kiện kết thúc.';

  @override
  String get ticketKeep => 'Giữ vé';

  @override
  String get ticketCancelDone => 'Đã huỷ vé';

  @override
  String get ticketCancelUsed => 'Vé đã dùng, không huỷ được';

  @override
  String get ticketQrClose => 'Đóng';

  @override
  String get createEventTitle => 'Tạo sự kiện';

  @override
  String get createEventInfo => 'Thông tin sự kiện';

  @override
  String get createEventCover => 'Thêm ảnh bìa 16:10';

  @override
  String get createEventCoverChange => 'Đổi ảnh bìa';

  @override
  String get createEventName => 'Tên sự kiện';

  @override
  String get createEventNameRequired => 'Tên sự kiện · bắt buộc';

  @override
  String get createEventType => 'Loại sự kiện';

  @override
  String get createEventDesc => 'Mô tả';

  @override
  String get createEventHost => 'Tổ chức bởi';

  @override
  String get createEventHostPlatform => 'Nền tảng';

  @override
  String get createEventHostLater => 'Tổ chức hộ một nhiếp ảnh gia sẽ có sau.';

  @override
  String get createEventContinue => 'Tiếp tục';

  @override
  String get createEventSaveDraftAsk => 'Lưu nháp?';

  @override
  String get createEventDraftKeep => 'Lưu';

  @override
  String get createEventDraftDiscard => 'Bỏ';

  @override
  String get createEventSchedule => 'Lịch và vé';

  @override
  String get createEventDay => 'Ngày';

  @override
  String get createEventStart => 'Giờ bắt đầu';

  @override
  String get createEventEnd => 'Kết thúc';

  @override
  String get createEventCapacity => 'Sức chứa';

  @override
  String get createEventCapacityUnit => 'người';

  @override
  String get createEventPlace => 'Địa điểm';

  @override
  String get createEventMeeting => 'Điểm hẹn';

  @override
  String get createEventArea => 'Khu vực';

  @override
  String get createEventAreaPick => 'Chọn khu vực';

  @override
  String get createEventUseLocation => 'Dùng vị trí hiện tại';

  @override
  String get createEventLocationUsed => 'Đã lấy vị trí hiện tại';

  @override
  String get createEventHashtag => 'Hashtag sự kiện';

  @override
  String get createEventHashtagTaken => 'Hashtag này đã có sự kiện khác dùng';

  @override
  String get createEventPrice => 'Giá mỗi người (₫)';

  @override
  String get createEventDeadline => 'Hạn đăng ký';

  @override
  String get createEventDeadlineAuto => 'Tự động';

  @override
  String get createEventFreeHint => 'Để giá bằng 0 nếu không thu phí.';

  @override
  String get createEventEscrowHint =>
      'Tiền vé được giữ trên ứng dụng và chuyển cho bạn sau khi sự kiện kết thúc.';

  @override
  String get createEventPreview => 'Xem trước';

  @override
  String get createEventSaveDraft => 'Lưu nháp';

  @override
  String get createEventPublish => 'Đăng sự kiện';

  @override
  String get createEventPublished => 'Đã đăng sự kiện';

  @override
  String get createEventDraftSaved => 'Đã lưu nháp';

  @override
  String get createEventDayTaken => 'Bạn đã có lịch hôm đó';

  @override
  String createEventErrorSummary(int n) {
    return 'Cần sửa $n mục trước khi đăng';
  }

  @override
  String get createEventPickDay => 'Chọn ngày';

  @override
  String get createEventPickTime => 'Chọn giờ';

  @override
  String get createEventErrCover => 'Thêm ảnh bìa cho sự kiện';

  @override
  String get createEventErrTitle => 'Nhập tên sự kiện';

  @override
  String get createEventErrTitleLong => 'Tên sự kiện tối đa 80 ký tự';

  @override
  String get createEventErrType => 'Chọn loại sự kiện';

  @override
  String get createEventErrDescLong => 'Mô tả tối đa 1000 ký tự';

  @override
  String get createEventErrDay => 'Chọn ngày diễn ra';

  @override
  String get createEventErrStart => 'Chọn giờ bắt đầu';

  @override
  String get createEventErrEnd => 'Chọn giờ kết thúc';

  @override
  String get createEventErrEndBeforeStart =>
      'Giờ kết thúc phải sau giờ bắt đầu';

  @override
  String get createEventErrSameDay => 'Sự kiện diễn ra trong một ngày';

  @override
  String get createEventErrStartSoon =>
      'Giờ bắt đầu phải sau bây giờ ít nhất 2 giờ';

  @override
  String get createEventErrCapacity => 'Sức chứa từ 1 đến 500 người';

  @override
  String get createEventErrPlace => 'Nhập tên địa điểm';

  @override
  String get createEventErrPlacePoint =>
      'Chọn khu vực hoặc dùng vị trí hiện tại';

  @override
  String get createEventErrPrice =>
      'Giá tiền là bội số của 1.000₫, tối đa 100.000.000₫';

  @override
  String get createEventErrPriceRequired => 'Nhập giá, để 0 nếu không thu phí';

  @override
  String get createEventErrDeadline => 'Hạn đăng ký phải trước giờ bắt đầu';

  @override
  String get createEventErrHashtag => 'Hashtag gồm 3–40 chữ không dấu hoặc số';

  @override
  String get createEventFailed =>
      'Không đăng được sự kiện. Kiểm tra mạng rồi thử lại.';

  @override
  String get createEventSaveFailed =>
      'Không lưu được nháp. Kiểm tra mạng rồi thử lại.';

  @override
  String get createEventCoverFailed => 'Không tải được ảnh bìa. Thử lại nhé.';

  @override
  String get createEventSetupTitle => 'Hoàn thiện hồ sơ để tạo sự kiện';

  @override
  String get createEventSetupBody =>
      'Bạn cần hoàn tất hồ sơ nhiếp ảnh gia trước khi tổ chức sự kiện.';

  @override
  String get createEventSetupCta => 'Hoàn thiện hồ sơ';

  @override
  String get createEventNotAllowed =>
      'Chỉ nhiếp ảnh gia và nhân viên mới tạo được sự kiện.';

  @override
  String get eventStatusDraft => 'Nháp';

  @override
  String get eventStatusOpen => 'Đang mở';

  @override
  String get eventStatusFull => 'Hết chỗ';

  @override
  String get eventStatusClosed => 'Đã đóng';

  @override
  String get eventStatusCancelled => 'Đã huỷ';

  @override
  String get eventStatusCompleted => 'Đã kết thúc';

  @override
  String get manageTitle => 'Quản lý sự kiện';

  @override
  String get manageRegistered => 'Đã đăng ký';

  @override
  String get manageRevenue => 'Doanh thu';

  @override
  String get manageDaysLeft => 'Ngày còn lại';

  @override
  String get manageParticipants => 'Người tham gia';

  @override
  String get manageEmpty => 'Chưa có người đăng ký';

  @override
  String get manageShare => 'Chia sẻ sự kiện';

  @override
  String get manageViewPage => 'Xem trang sự kiện';

  @override
  String get manageBroadcast => 'Nhắn nhóm';

  @override
  String get manageBroadcastSoon => 'Nhắn nhóm sắp mở';

  @override
  String get manageScan => 'Quét mã check‑in';

  @override
  String get manageCancel => 'Huỷ sự kiện · hoàn tiền mọi vé';

  @override
  String get manageCancelTitle => 'Huỷ sự kiện này?';

  @override
  String manageCancelBody(int n, String amount) {
    return '$n vé · hoàn $amount';
  }

  @override
  String get manageNoRefund => 'Không có khoản hoàn';

  @override
  String get manageCancelConfirm => 'Huỷ sự kiện';

  @override
  String get manageCancelKeep => 'Giữ sự kiện';

  @override
  String get manageCancelDone => 'Đã huỷ sự kiện';

  @override
  String get manageCancelFailed => 'Không huỷ được sự kiện. Thử lại nhé.';

  @override
  String get manageGone => 'Không tìm thấy sự kiện';

  @override
  String get managePaid => 'Đã trả';

  @override
  String get manageUnpaid => 'Chờ trả';

  @override
  String get manageCheckedIn => 'Đã vào';

  @override
  String manageTicketQty(int n) {
    return '$n vé';
  }

  @override
  String manageTicketCode(int n, String code) {
    return '$n vé · $code';
  }

  @override
  String get manageNoMoney => '—';

  @override
  String get manageScanClosed => 'Đã hết giờ check‑in';

  @override
  String get manageInviteTitle => 'Lời mời tổ chức sự kiện';

  @override
  String manageInviteBody(String time) {
    return 'Nhân viên đã tạo sự kiện này cho bạn. Hãy trả lời trước $time, quá hạn sự kiện sẽ bị huỷ.';
  }

  @override
  String get manageInviteAccept => 'Chấp nhận';

  @override
  String get manageInviteDecline => 'Từ chối';

  @override
  String get manageInviteAccepted => 'Đã chấp nhận, nhân viên sẽ đăng sự kiện';

  @override
  String get manageInviteDeclined => 'Đã từ chối lời mời';

  @override
  String get manageInviteFailed => 'Không gửi được câu trả lời. Thử lại nhé.';

  @override
  String checkinOk(String name, int count) {
    return 'Đã vào · $name · $count vé';
  }

  @override
  String get checkinInvalid => 'Vé không hợp lệ';

  @override
  String get checkinUsed => 'Vé đã dùng';

  @override
  String get checkinManual => 'Nhập mã vé';

  @override
  String get checkinManualHint => 'Mã vé, ví dụ VE-7K2Q-0420';

  @override
  String get checkinManualSubmit => 'Kiểm tra';

  @override
  String get checkinNext => 'Quét tiếp';

  @override
  String get checkinScanTitle => 'Quét mã vé';

  @override
  String get checkinCameraOff =>
      'Không mở được camera. Nhập mã vé để check‑in.';

  @override
  String get checkinFailed => 'Không check‑in được. Thử lại nhé.';

  @override
  String get myEventsTitle => 'Sự kiện của tôi';

  @override
  String get myEventsDraft => 'Nháp';

  @override
  String get myEventsEmpty => 'Bạn chưa tổ chức sự kiện nào';

  @override
  String get myEventsEmptyBody => 'Sự kiện bạn tạo sẽ hiện ở đây.';

  @override
  String get myEventsSeeAll => 'Xem tất cả';

  @override
  String get settingsManageEvents => 'Quản lý sự kiện';

  @override
  String get createPostTabPost => 'Bài đăng';

  @override
  String get createPostTabEvent => 'Sự kiện';

  @override
  String get createEventLocationFailed =>
      'Không lấy được vị trí. Hãy chọn khu vực nhé.';

  @override
  String get createEventDeadlineReset => 'Dùng hạn tự động';

  @override
  String get checkinNotYet =>
      'Chưa tới ngày diễn ra. Check‑in mở từ 00:00 hôm đó.';

  @override
  String get eventDateUnset => 'Chưa chọn ngày';

  @override
  String timelineCount(int n) {
    return '$n bài';
  }

  @override
  String timelinePost(String tag) {
    return 'Đăng ảnh với $tag';
  }

  @override
  String get timelineEmpty => 'Chưa có ảnh nào. Hãy là người đầu tiên chia sẻ!';

  @override
  String get timelinePending => 'Chờ duyệt';

  @override
  String get timelineVisibleTab => 'Đã đăng';

  @override
  String get timelinePendingEmpty => 'Không có bài nào chờ duyệt.';

  @override
  String get timelineClosed => 'Timeline đã đóng đăng mới';

  @override
  String get timelineHide => 'Ẩn khỏi timeline';

  @override
  String get timelineApprove => 'Duyệt';

  @override
  String get timelineReport => 'Báo cáo';

  @override
  String get timelineHostSuffix => 'chủ sự kiện';

  @override
  String get timelineModerateFailed => 'Không thực hiện được. Thử lại nhé.';

  @override
  String timelineItemLabel(String name) {
    return 'Ảnh của $name';
  }

  @override
  String get timelineMenuHint => 'Nhấn giữ để mở menu';

  @override
  String get shareTitle => 'Chia sẻ ảnh sự kiện';

  @override
  String get shareSend => 'Đăng';

  @override
  String get shareCaptionHint => 'Viết chú thích…';

  @override
  String get shareFailed => 'Không đăng được ảnh. Kiểm tra mạng rồi thử lại.';

  @override
  String get shareClosed => 'Timeline đã đóng đăng mới.';

  @override
  String get shareDone => 'Đã đăng lên timeline';

  @override
  String get shareDiscardTitle => 'Bỏ bài đang soạn?';

  @override
  String get shareKeepEditing => 'Tiếp tục soạn';

  @override
  String chatMembers(int n) {
    return '$n thành viên';
  }

  @override
  String get chatPinned => 'Ghim';

  @override
  String get eventChatInput => 'Nhắn cho nhóm…';

  @override
  String get eventChatClosed => 'Nhóm đã đóng';

  @override
  String get chatMutedNote => 'Bạn đang bị tắt tiếng trong nhóm';

  @override
  String get chatModOnly => 'Chỉ điều hành được nhắn';

  @override
  String chatJoined(String name) {
    return '$name đã vào nhóm';
  }

  @override
  String get chatPin => 'Ghim';

  @override
  String get chatUnpin => 'Bỏ ghim';

  @override
  String get chatDelete => 'Xoá';

  @override
  String get chatDeleted => 'Tin nhắn đã bị xoá';

  @override
  String get chatMute24h => 'Tắt tiếng 24 giờ';

  @override
  String get chatUnmute => 'Bật tiếng';

  @override
  String get chatRemove => 'Gỡ khỏi nhóm';

  @override
  String chatRemoveTitle(String name) {
    return 'Gỡ $name khỏi nhóm?';
  }

  @override
  String get chatMemberList => 'Thành viên';

  @override
  String get chatMemberModerator => 'Điều hành';

  @override
  String get chatMemberMuted => 'Đang bị tắt tiếng';

  @override
  String get chatMuteGroup => 'Tắt tiếng nhóm';

  @override
  String get chatUnmuteGroup => 'Bật tiếng nhóm';

  @override
  String get chatRateLimited => 'Bạn nhắn quá nhanh. Thử lại sau ít giây nhé.';

  @override
  String get chatActionFailed => 'Không thực hiện được. Thử lại nhé.';

  @override
  String get chatLockedAction => 'Xem sự kiện';

  @override
  String chatMessageOf(String name, String text) {
    return '$name: $text';
  }

  @override
  String get manageAnnounceTitle => 'Ghim thông báo vào nhóm';

  @override
  String get manageAnnounceHint => 'Viết thông báo cho cả nhóm';

  @override
  String get manageAnnounceSend => 'Ghim';

  @override
  String get manageAnnounceDone => 'Đã ghim thông báo vào nhóm';

  @override
  String get manageAnnounceFailed => 'Không ghim được thông báo. Thử lại nhé.';

  @override
  String get managePending => 'Bài chờ duyệt';

  @override
  String postEventChip(String title) {
    return 'Sự kiện: $title';
  }

  @override
  String get chatRemovedSection => 'Đã mời ra';

  @override
  String get chatRestore => 'Cho vào lại';

  @override
  String get chatRestoreHint =>
      'Vào lại ngay nếu còn vé; nếu không, khi mua vé mới.';

  @override
  String get manageCheckinLink => 'Check‑in';

  @override
  String get registerTotal => 'Tổng thanh toán';

  @override
  String registerLine(int n, String price) {
    return '$n vé × $price';
  }

  @override
  String registerPay(String amount) {
    return 'Thanh toán $amount';
  }

  @override
  String get registerHoldExpired => 'Chỗ giữ đã hết hạn';

  @override
  String get registerPolicy =>
      'Huỷ trước 48 giờ hoàn 100%. Vé được giữ 10 phút trong lúc thanh toán.';

  @override
  String get escrowNoticeTicket =>
      'Tiền vé được giữ an toàn trên ứng dụng cho tới khi sự kiện kết thúc.';

  @override
  String get ticketPayContinue => 'Thanh toán tiếp';

  @override
  String get ticketHoldExpired => 'Hết hạn';

  @override
  String ticketRefundAmount(String amount) {
    return 'Bạn nhận lại $amount';
  }

  @override
  String get ticketNoRefund =>
      'Vé không được hoàn tiền khi huỷ trong vòng 48 giờ.';

  @override
  String get payMethodBankQr => 'Chuyển khoản QR';

  @override
  String get payMethodMomo => 'MoMo';

  @override
  String get payMethodZaloPay => 'ZaloPay';

  @override
  String get payMethodBankQrNote => 'Miễn phí · xác nhận ngay';

  @override
  String get payAttemptsExceeded => 'Đã tạo QR 3 lần. Hãy đặt lại từ đầu.';

  @override
  String get payMethodLabel => 'Phương thức thanh toán';

  @override
  String get ticketCancelledRefunded => 'Đã huỷ · đã hoàn tiền';

  @override
  String get ticketCancelledRefunding => 'Đã huỷ · đang hoàn tiền';

  @override
  String eventRegisteredOf(int registered, int capacity) {
    return '$registered/$capacity đã đăng ký';
  }

  @override
  String createEventFaqHint(int max) {
    return 'Hiện ở trang sự kiện để khách đọc trước khi đăng ký. Tối đa $max câu.';
  }

  @override
  String createEventFaqQuestion(int n) {
    return 'Câu hỏi $n';
  }

  @override
  String get createEventFaqAnswer => 'Trả lời';

  @override
  String get createEventFaqAdd => 'Thêm câu hỏi';

  @override
  String createEventFaqRemove(int n) {
    return 'Xoá câu hỏi $n';
  }

  @override
  String get createEventErrFaq => 'Nhập đủ cả câu hỏi và câu trả lời.';

  @override
  String get eventSpotLabel => 'Điểm chụp · bắt buộc';

  @override
  String get eventSpotPlaceholder => 'Chọn điểm chụp';

  @override
  String get eventSpotSheetTitle => 'Điểm chụp';

  @override
  String get eventSpotSheetHint =>
      'Sự kiện gắn điểm hiện ở trang điểm chụp và được tính vào độ hot.';

  @override
  String get eventSpotSearch => 'Tìm điểm chụp';

  @override
  String get eventSpotClose => 'Đóng';

  @override
  String get eventSpotNone => 'Không thuộc điểm chụp nào';

  @override
  String get eventSpotNoneHint => 'Sự kiện không hiện ở trang điểm nào';

  @override
  String eventSpotPick(String name) {
    return 'Chọn $name';
  }

  @override
  String get eventSpotPickNone => 'Không gắn điểm';

  @override
  String get eventSpotNoMatch => 'Không có điểm chụp nào khớp.';

  @override
  String get eventSpotRequired =>
      'Chọn một điểm chụp, hoặc “Không thuộc điểm chụp nào”';

  @override
  String get eventSpotFar =>
      'Địa điểm nằm ngoài điểm chụp đã chọn. Sửa địa điểm hoặc chọn điểm khác.';

  @override
  String get eventSpotArchived =>
      'Điểm chụp này không còn nhận lịch mới. Chọn điểm khác.';

  @override
  String get eventSpotGone => 'Không tìm thấy điểm chụp này. Chọn điểm khác.';

  @override
  String postSpotChip(String name) {
    return 'Gắn với $name';
  }

  @override
  String postSpotChipRemove(String name) {
    return 'Bỏ gắn $name';
  }

  @override
  String get bookNotAcceptingOrders => 'Nhiếp ảnh gia này chưa nhận đặt lịch.';

  @override
  String get bookingErrBlocked => 'Không đặt lịch được với người này.';

  @override
  String get savedTitle => 'Đã lưu';

  @override
  String savedTabPosts(int count) {
    return 'Bài · $count';
  }

  @override
  String savedTabPhotographers(int count) {
    return 'Nhiếp ảnh gia · $count';
  }

  @override
  String get savedPostsEmptyTitle => 'Chưa lưu bài nào';

  @override
  String get savedPostsEmptyBody =>
      'Bấm biểu tượng lưu trên ảnh để xem lại ở đây.';

  @override
  String get savedPhotographersEmptyTitle => 'Chưa lưu nhiếp ảnh gia nào';

  @override
  String get savedPhotographersEmptyBody =>
      'Bấm biểu tượng lưu trên hồ sơ nhiếp ảnh gia để so sánh và đặt lịch sau.';

  @override
  String savedUnsaved(String name) {
    return 'Đã bỏ lưu $name';
  }

  @override
  String get savedUndo => 'Hoàn tác';

  @override
  String get savedBook => 'Đặt lịch';

  @override
  String savedToggleOn(String name) {
    return 'Lưu $name';
  }

  @override
  String savedToggleOff(String name) {
    return 'Bỏ lưu $name';
  }

  @override
  String get followingTitle => 'Đang theo dõi';

  @override
  String followingCount(int count) {
    return '$count nhiếp ảnh gia';
  }

  @override
  String get followingButton => 'Đang theo dõi';

  @override
  String get followButton => 'Theo dõi';

  @override
  String followingUnfollowed(String name) {
    return 'Đã bỏ theo dõi $name';
  }

  @override
  String get followingEmptyTitle => 'Bạn chưa theo dõi ai';

  @override
  String get followingEmptyBody =>
      'Theo dõi nhiếp ảnh gia để thấy bài mới của họ trước.';

  @override
  String get followingEmptyAction => 'Khám phá';

  @override
  String get followersTitle => 'Người theo dõi';

  @override
  String followersCount(int count) {
    return '$count người theo dõi · chỉ bạn xem được danh sách này';
  }

  @override
  String followersSince(String date) {
    return 'Theo dõi từ $date';
  }

  @override
  String get followersEmptyTitle => 'Chưa có người theo dõi';

  @override
  String get followersEmptyBody =>
      'Đăng bài thường xuyên để có thêm người theo dõi.';

  @override
  String get profileCountFollowers => 'người theo dõi';

  @override
  String get profileUnsavePhotographer => 'Bỏ lưu nhiếp ảnh gia';

  @override
  String get reasonFollowing => 'Bạn đang theo dõi';

  @override
  String get socialToggleFailed => 'Chưa lưu được. Thử lại.';

  @override
  String get verifyPhoneTitle => 'Xác minh số điện thoại';

  @override
  String get verifyPhoneHeading => 'Nhập số điện thoại của bạn';

  @override
  String get verifyPhoneBody =>
      'Chúng tôi gửi mã 6 số qua SMS. Số này dùng để liên hệ khi có đơn, không hiện công khai.';

  @override
  String get verifyPhoneExample => 'Ví dụ: 0912 345 678.';

  @override
  String get verifyPhoneSend => 'Gửi mã';

  @override
  String get verifyCodeHeading => 'Nhập mã 6 số';

  @override
  String verifyCodeSentTo(String last4) {
    return 'Đã gửi tới •••• $last4';
  }

  @override
  String verifyCodeResendIn(String time) {
    return 'Gửi lại mã sau $time';
  }

  @override
  String get verifyCodeResend => 'Gửi lại mã';

  @override
  String get verifyCodeChangePhone => 'Đổi số điện thoại';

  @override
  String get verifyCodeConfirm => 'Xác nhận';

  @override
  String get verifyCodeWrong => 'Mã không đúng. Kiểm tra lại tin nhắn.';

  @override
  String get verifyCodeExpired => 'Mã đã hết hạn. Bấm Gửi lại mã.';

  @override
  String get verifyPhoneTooMany =>
      'Bạn đã thử quá nhiều lần. Thử lại sau ít phút.';

  @override
  String get verifyPhoneInUse => 'Số này đã gắn với một tài khoản khác.';

  @override
  String get verifyPhoneInvalid =>
      'Số điện thoại chưa đúng. Ví dụ: 0912 345 678.';

  @override
  String get verifyPhoneDone => 'Đã xác minh số điện thoại';

  @override
  String get verifyStartTitle => 'Bắt đầu nhận đơn';

  @override
  String verifyStepCounter(int n, int total) {
    return '$n / $total';
  }

  @override
  String get verifyStartIntro =>
      'Làm từng bước, lưu lại tiến độ. Thoát giữa chừng thì lần sau làm tiếp từ bước đang dở.';

  @override
  String get verifyStepPhone => 'Số điện thoại';

  @override
  String get verifyStepPhoneTodo => 'Nhận mã 6 số qua SMS';

  @override
  String verifyStepPhoneDone(String last4) {
    return 'Đã xác minh · •••• $last4';
  }

  @override
  String verifyStepFee(String amount) {
    return 'Phí xác minh $amount';
  }

  @override
  String get verifyStepFeeTodoIndividual =>
      'Studio 299.000₫ · trả bằng QR hoặc ví';

  @override
  String get verifyStepFeeTodoStudio =>
      'Thợ ảnh cá nhân 99.000₫ · trả bằng QR hoặc ví';

  @override
  String verifyStepFeeDone(String amount) {
    return 'Đã trả $amount';
  }

  @override
  String get verifyFeeTitle => 'Phí xác minh';

  @override
  String get verifyFeeYouGet => 'Bạn nhận được';

  @override
  String get verifyFeeBenefitTick => 'Tích xanh cạnh tên trên hồ sơ';

  @override
  String get verifyFeeBenefitOrders => 'Nhận đơn đặt lịch và gửi báo giá';

  @override
  String get verifyFeeBenefitReview => 'Staff duyệt trong 24 giờ';

  @override
  String get verifyFeeKindIndividual => 'Thợ ảnh cá nhân · studio 299.000₫';

  @override
  String get verifyFeeKindStudio => 'Studio · thợ ảnh cá nhân 99.000₫';

  @override
  String get verifyFeeNoRefund =>
      'Phí không hoàn vì chi phí kiểm tra đã phát sinh; bị từ chối được gửi lại miễn phí 1 lần.';

  @override
  String verifyFeePay(String amount) {
    return 'Thanh toán $amount';
  }

  @override
  String get verifyFeePaid => 'Đã nhận phí xác minh';

  @override
  String get verifyFeeFailed => 'Chưa thanh toán được. Thử lại.';

  @override
  String get verifyStepIdentity => 'Xác minh danh tính';

  @override
  String get verifyStepIdentityTodo => 'VNeID hoặc quét chip CCCD';

  @override
  String get verifyStepIdentityDoneVneid => 'Đã khớp qua VNeID';

  @override
  String get verifyStepIdentityDoneNfc => 'Đã khớp qua chip CCCD';

  @override
  String get verifyStepRules => 'Đồng ý quy định nhận việc';

  @override
  String get verifyStepRulesTodo => '5 điều chính và một dấu tích';

  @override
  String get verifyStepRulesDone => 'Đã đồng ý';

  @override
  String get verifyStateDone => 'Xong';

  @override
  String get verifyStateNow => 'Đang làm';

  @override
  String get verifyStateTodo => 'Chưa làm';

  @override
  String get verifyStateFix => 'Cần sửa';

  @override
  String verifyStartNote(int total) {
    return 'Xong $total bước thì bấm \"Gửi duyệt\". Staff duyệt trong 24 giờ; được duyệt là có tích xanh và nhận đơn ngay.';
  }

  @override
  String get verifyContinue => 'Tiếp tục';

  @override
  String get verifySubmit => 'Gửi duyệt';

  @override
  String verifyAtToday(String time) {
    return '$time hôm nay';
  }

  @override
  String verifyAtTomorrow(String time) {
    return '$time ngày mai';
  }

  @override
  String verifyAtDate(String time, String date) {
    return '$time ngày $date';
  }

  @override
  String get verifyRulesTitle => 'Quy định nhận việc';

  @override
  String get verifyRulesIntro => 'Đọc 5 điều chính trước khi gửi duyệt.';

  @override
  String get verifyRule1 =>
      'Khách trả 100% khi đặt; tiền được giữ và chuyển cho bạn theo 2 mốc: sau buổi chụp, và sau khi khách đồng ý ảnh + 48 giờ.';

  @override
  String get verifyRule2 =>
      'Bàn giao hai lớp: gửi ảnh mẫu có watermark trước; link ảnh gốc chỉ mở khi khách đồng ý.';

  @override
  String get verifyRule3 =>
      'Khách huỷ trước 48 giờ được hoàn 100%, 24–48 giờ hoàn 50%, dưới 24 giờ không hoàn; bạn huỷ thì khách được hoàn 100%.';

  @override
  String get verifyRule4 =>
      'Thợ cá nhân: nền tảng khấu trừ và nộp thay thuế trên phần chi trả cho bạn.';

  @override
  String get verifyRule5 =>
      'Họ tên, ngày sinh, số định danh được mã hoá; không lưu ảnh selfie; chỉ dùng để xác minh, chống trùng tài khoản và khấu trừ thuế.';

  @override
  String get verifyRulesAgree => 'Tôi đã đọc và đồng ý quy định nhận việc';

  @override
  String get verifyPendingHeading => 'Đang chờ duyệt · trong 24 giờ';

  @override
  String verifyPendingSent(String time, String deadline) {
    return 'Gửi lúc $time · có kết quả trước $deadline';
  }

  @override
  String get verifyTlFee => 'Đã trả phí xác minh';

  @override
  String verifyTlFeeBody(String when, String amount) {
    return '$when · $amount';
  }

  @override
  String get verifyTlIdentity => 'Đã xác minh danh tính';

  @override
  String verifyTlIdentityBody(String method, String name) {
    return '$method · $name';
  }

  @override
  String get verifyMethodVneid => 'VNeID';

  @override
  String get verifyMethodNfc => 'Chip CCCD';

  @override
  String get verifyTlSubmitted => 'Đã gửi duyệt';

  @override
  String verifyTlSubmittedBody(String when) {
    return '$when · đã đồng ý quy định nhận việc';
  }

  @override
  String get verifyTlReview => 'Staff duyệt';

  @override
  String get verifyTlReviewBody => 'Duyệt xong là có tích xanh và nhận đơn';

  @override
  String get verifyPendingNote =>
      'Trong lúc chờ, bạn vẫn sửa portfolio, tạo gói và trò chuyện với khách.';

  @override
  String get verifyViewProfile => 'Xem hồ sơ';

  @override
  String get verifyRejectedTitle => 'Hồ sơ chưa được duyệt';

  @override
  String verifyRejectedReason(String reason) {
    return 'Lý do: $reason';
  }

  @override
  String get verifyReject_fake_avatar =>
      'Ảnh đại diện không phải ảnh người thật. Đổi sang ảnh chân dung rõ mặt của bạn rồi gửi lại.';

  @override
  String get verifyReject_stolen_portfolio =>
      'Portfolio có ảnh không phải của bạn. Gỡ những ảnh đó rồi gửi lại.';

  @override
  String get verifyReject_identity_mismatch =>
      'Danh tính không khớp với tên trên hồ sơ. Xác minh lại danh tính rồi gửi lại.';

  @override
  String get verifyReject_duplicate_account =>
      'Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn.';

  @override
  String get verifyReject_underage => 'Bạn cần đủ 18 tuổi để nhận đơn.';

  @override
  String verifyFreeResubmitsLeft(int n) {
    return 'Còn $n lần gửi lại miễn phí';
  }

  @override
  String get verifyNoFreeResubmit =>
      'Hết lượt gửi lại miễn phí · gửi lại cần trả phí xác minh mới';

  @override
  String get verifyFixAvatar => 'Ảnh đại diện';

  @override
  String get verifyFixAvatarBody => 'Cần ảnh chân dung thật, rõ mặt';

  @override
  String get verifyFixPortfolio => 'Portfolio';

  @override
  String get verifyFixPortfolioBody => 'Gỡ ảnh không phải của bạn';

  @override
  String get verifyFixIdentity => 'Danh tính';

  @override
  String get verifyRejectedNote =>
      'Chỉ sửa mục bị từ chối; các bước đã xong được giữ nguyên. Gửi lại thì staff duyệt trong 24 giờ.';

  @override
  String get verifyResubmit => 'Sửa và gửi lại';

  @override
  String get verifyApprovedHeading => 'Bạn đã có thể nhận đơn';

  @override
  String verifyApprovedBody(String when) {
    return 'Duyệt lúc $when. Tích xanh đã hiện cạnh tên bạn.';
  }

  @override
  String get verifyRevokedHeading => 'Xác minh đã bị thu hồi';

  @override
  String get verifyRevokedBody =>
      'Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm.';

  @override
  String verifySupportLine(String email) {
    return 'Hỗ trợ: $email';
  }

  @override
  String get verifyIdTitle => 'Xác minh danh tính';

  @override
  String get verifyIdHeading => 'Xác minh bằng căn cước điện tử';

  @override
  String get verifyIdBody =>
      'Không cần gõ hay chụp giấy tờ: mở app VNeID, đồng ý chia sẻ rồi nhập mã PIN VNeID.';

  @override
  String get verifyIdWeOnlyGet => 'Chúng tôi chỉ nhận';

  @override
  String get verifyIdFieldName => 'Họ tên';

  @override
  String get verifyIdFieldDob => 'Ngày sinh';

  @override
  String get verifyIdFieldNumber => 'Số định danh';

  @override
  String get verifyIdPrivacy =>
      'Không lưu ảnh selfie. Dùng để khớp tên tài khoản nhận tiền và chống giả mạo; số định danh được mã hoá.';

  @override
  String get verifyIdConsent =>
      'Bấm \"Xác minh bằng VNeID\" là bạn đồng ý chia sẻ ba thông tin trên.';

  @override
  String get verifyIdNfcLink => 'Không dùng được VNeID? Quét chip CCCD';

  @override
  String get verifyIdVneid => 'Xác minh bằng VNeID';

  @override
  String get verifyNfcTitle => 'Quét chip CCCD';

  @override
  String get verifyNfcStep1 => 'Bước 1/2 · Đọc chip';

  @override
  String get verifyNfcStep2 => 'Bước 2/2 · Selfie';

  @override
  String get verifyNfcHeading => 'Áp CCCD vào mặt sau điện thoại';

  @override
  String get verifyNfcBody =>
      'Giữ yên thẻ ở giữa lưng máy tới khi máy rung. Tháo ốp lưng dày nếu đọc chậm.';

  @override
  String get verifyNfcNextTitle => 'Tiếp theo';

  @override
  String get verifyNfcNextBody => 'Chụp selfie để kiểm tra người thật';

  @override
  String get verifyNfcNote =>
      'Máy cần có NFC. Ảnh selfie chỉ dùng để so với ảnh trong chip, không lưu.';

  @override
  String get verifyNfcStart => 'Bắt đầu quét';

  @override
  String get verifySelfieHeading => 'Chụp selfie 3–5 giây';

  @override
  String get verifySelfieBody =>
      'Nhìn thẳng vào camera, quay đầu chậm sang trái rồi sang phải.';

  @override
  String get verifySelfieNote =>
      'Ảnh selfie chỉ dùng để so với ảnh trong chip, không lưu.';

  @override
  String get verifySelfieStart => 'Bắt đầu chụp';

  @override
  String verifyIdPassed(String name) {
    return 'Đã xác minh: $name';
  }

  @override
  String get verifyIdUnderage => 'Bạn cần đủ 18 tuổi để nhận đơn.';

  @override
  String get verifyIdInUse =>
      'Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn.';

  @override
  String get verifyIdRateLimited =>
      'Bạn đã thử 3 lần hôm nay. Thử lại vào ngày mai.';

  @override
  String get verifyIdFailed =>
      'Chưa xác minh được. Thử lại hoặc dùng cách khác.';

  @override
  String get verifyIdFakeTitle => 'VNeID (giả lập)';

  @override
  String get verifyIdFakeBody =>
      'Môi trường thử: không mở app VNeID thật. Bấm Đồng ý để nhận một danh tính thử.';

  @override
  String get verifyIdFakeAgree => 'Đồng ý chia sẻ';

  @override
  String get verifyBizTitle => 'Xác minh doanh nghiệp';

  @override
  String get verifyBizIntro =>
      'Cần cho con dấu Studio, hơn 3 thành viên và tài khoản nhận tiền đứng tên công ty. Không cần để nhận đơn.';

  @override
  String get verifyBizTaxCode => 'Mã số thuế';

  @override
  String get verifyBizLookup => 'Tra cứu';

  @override
  String get verifyBizName => 'Tên';

  @override
  String get verifyBizAddress => 'Địa chỉ';

  @override
  String get verifyBizStatus => 'Tình trạng';

  @override
  String get verifyBizActive => 'Đang hoạt động';

  @override
  String get verifyBizInactive => 'Ngừng hoạt động';

  @override
  String get verifyBizDocTitle =>
      'Người đại diện: cần ảnh giấy đăng ký kinh doanh';

  @override
  String get verifyBizDocBody =>
      'Staff đối chiếu người đại diện với chủ studio đã xác minh';

  @override
  String get verifyBizHouseholdNote =>
      'Hộ kinh doanh: mã số thuế là số định danh của chủ, tự khớp, không cần tải giấy.';

  @override
  String get verifyBizSubmit => 'Gửi duyệt';

  @override
  String get verifyBizPending => 'Đang chờ duyệt · trong 24 giờ';

  @override
  String get verifyBizApproved => 'Đã xác minh doanh nghiệp';

  @override
  String verifyBizRejected(String reason) {
    return 'Chưa được duyệt: $reason';
  }

  @override
  String get verifyBizReject_inactive =>
      'Doanh nghiệp không ở tình trạng đang hoạt động.';

  @override
  String get verifyBizReject_representative_mismatch =>
      'Mã số thuế không khớp với danh tính chủ studio.';

  @override
  String get verifyBizReject_doc_unreadable =>
      'Ảnh giấy đăng ký không đọc được. Chụp lại rõ nét.';

  @override
  String get verifyBizNotFound => 'Không tìm thấy mã số thuế này.';

  @override
  String get verifyBizNeedsIdentity => 'Xác minh danh tính chủ studio trước.';

  @override
  String get verifyBizInvalid => 'Mã số thuế gồm 10 hoặc 12 chữ số.';

  @override
  String settingsVerifyStepsLeft(int n) {
    return 'Còn $n bước';
  }

  @override
  String get settingsVerifyPending => 'Đang chờ duyệt';

  @override
  String get settingsVerifyApproved => 'Đã xác minh';

  @override
  String get settingsVerifyRejected => 'Chưa được duyệt';

  @override
  String get settingsVerifyRevoked => 'Đã thu hồi';

  @override
  String get settingsBusiness => 'Xác minh doanh nghiệp';

  @override
  String get settingsBusinessTodo => 'Con dấu Studio, tới 30 thợ';

  @override
  String profileOwnerStepsLeft(int n) {
    return 'Còn $n bước để nhận đơn';
  }

  @override
  String get profileOwnerStepsBody =>
      'Khách chưa đặt được bạn cho tới khi xác minh xong.';

  @override
  String get profileOwnerPending => 'Đang chờ duyệt · trong 24 giờ';

  @override
  String get profileOwnerPendingBody =>
      'Hồ sơ vẫn hiện \"Chưa nhận đơn\" với khách tới khi được duyệt.';

  @override
  String get profileOwnerRejected => 'Hồ sơ chưa được duyệt';

  @override
  String get profileOwnerRejectedBody => 'Xem lý do và gửi lại.';

  @override
  String get profileOwnerContinue => 'Tiếp tục';

  @override
  String get profileOwnerView => 'Xem';

  @override
  String get settingsSupportSection => 'Hỗ trợ';

  @override
  String get settingsHelp => 'Trợ giúp';

  @override
  String get settingsHelpBody => 'Câu hỏi thường gặp, liên hệ hỗ trợ';

  @override
  String get helpTitle => 'Trợ giúp';

  @override
  String get helpMyDisputes => 'Khiếu nại của bạn';

  @override
  String helpDisputeRow(String code, String name) {
    return 'Khiếu nại #$code · $name';
  }

  @override
  String helpDisputeRowMeta(String status, String date) {
    return '$status · $date';
  }

  @override
  String get helpFaqTitle => 'Câu hỏi thường gặp';

  @override
  String get helpContactSupport => 'Liên hệ hỗ trợ';

  @override
  String helpEmailLine(String email) {
    return 'Email hỗ trợ: $email';
  }

  @override
  String get supportChatTitle => 'Hỗ trợ';

  @override
  String get supportChatNote =>
      'Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP.';

  @override
  String get supportChatHint => 'Nhắn cho hỗ trợ…';

  @override
  String get supportChatEmpty =>
      'Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới.';

  @override
  String get supportSendFailed => 'Chưa gửi được tin nhắn. Thử lại.';

  @override
  String get supportRateLimited =>
      'Bạn gửi hơi nhanh. Đợi vài phút rồi gửi tiếp.';

  @override
  String get helpTopicPayments => 'Thanh toán';

  @override
  String get helpTopicCancel => 'Huỷ & hoàn tiền';

  @override
  String get helpTopicDelivery => 'Bàn giao ảnh';

  @override
  String get helpTopicDisputes => 'Khiếu nại';

  @override
  String get helpTopicContact => 'Liên hệ';

  @override
  String get helpTopicReviews => 'Đánh giá';

  @override
  String get helpTopicProviders => 'Dành cho thợ ảnh';

  @override
  String get helpPayFullQ => 'Vì sao phải trả trước 100%?';

  @override
  String get helpPayFullA =>
      'Tiền không đến tay thợ ngay. Ứng dụng giữ tiền và chỉ chuyển cho thợ theo 2 đợt: sau buổi chụp, và sau khi bạn đồng ý ảnh rồi kiểm tra bộ ảnh gốc trong 48 giờ. Có lỗi thì bạn được hoàn qua ứng dụng.';

  @override
  String get helpPayHeldQ => 'Tiền của tôi được giữ ở đâu?';

  @override
  String get helpPayHeldA =>
      'Tiền do một tổ chức trung gian thanh toán được cấp phép giữ, không nằm trong tài khoản của ứng dụng, và chưa chuyển cho thợ cho tới khi đủ điều kiện.';

  @override
  String get helpPayQrQ => 'Chuyển khoản QR sai số tiền thì sao?';

  @override
  String get helpPayQrA =>
      'Hãy chuyển đúng số tiền và nội dung trong 15 phút. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động về tài khoản đã chuyển.';

  @override
  String get helpCancelRefundQ => 'Huỷ buổi chụp được hoàn bao nhiêu?';

  @override
  String get helpCancelRefundA =>
      'Huỷ trước giờ chụp từ 48 giờ trở lên: hoàn 100%. Từ 24 đến 48 giờ: hoàn 50%. Dưới 24 giờ: không hoàn. Tính trên toàn bộ số đã trả. Thợ huỷ thì bạn được hoàn 100%.';

  @override
  String get helpCancelWhereQ => 'Tiền hoàn về đâu?';

  @override
  String get helpCancelWhereA =>
      'Trả bằng ví MoMo hoặc ZaloPay thì hoàn về ví. Chuyển khoản thì hoàn về tài khoản đã chuyển, hoặc tài khoản khác bạn khai.';

  @override
  String get helpCancelLateQ => 'Thợ giao ảnh trễ thì sao?';

  @override
  String get helpCancelLateA =>
      'Quá số ngày đã hẹn, bạn được huỷ phần bàn giao và hoàn 100% đợt thanh toán thứ hai; thợ giữ đợt đầu.';

  @override
  String get helpDeliverySampleQ => 'Ảnh mẫu có watermark là gì?';

  @override
  String get helpDeliverySampleA =>
      'Thợ gửi ảnh mẫu có watermark trước. Link bộ ảnh gốc bị che và chỉ mở khi bạn bấm \"Đồng ý ảnh\". Không phản hồi trong 3 ngày thì hệ thống tự đồng ý.';

  @override
  String get helpDeliveryEditQ => 'Muốn sửa ảnh thì làm sao?';

  @override
  String get helpDeliveryEditA =>
      'Trao đổi màu sắc, chỉnh sửa ngay trên ảnh mẫu. Số vòng sửa miễn phí theo gói. Hết lượt thì bạn đồng ý, xin thêm một vòng, hoặc mở khiếu nại.';

  @override
  String get helpDisputeWhenQ => 'Khi nào tôi mở khiếu nại được?';

  @override
  String get helpDisputeWhenA =>
      'Trong 24 giờ sau khi buổi chụp hoàn thành, hoặc trong 24 giờ sau khi sự kiện có vé trả tiền kết thúc. Với bộ ảnh gốc, bạn có 48 giờ kể từ khi đồng ý ảnh. Quá thời hạn thì nút \"Báo vấn đề\" không còn. Vé không thu phí không có khiếu nại vì không có tiền được giữ.';

  @override
  String get helpDisputeMoneyQ => 'Trong lúc khiếu nại, tiền ở đâu?';

  @override
  String get helpDisputeMoneyA =>
      'Tiền tiếp tục được giữ, không chuyển cho thợ. Đội hỗ trợ xem bằng chứng của hai bên rồi quyết định: chuyển cho thợ, hoàn cho bạn, hoặc chia.';

  @override
  String get helpDisputeEvidenceQ => 'Ai xem được ảnh bằng chứng?';

  @override
  String get helpDisputeEvidenceA =>
      'Chỉ bạn, người bị khiếu nại và đội hỗ trợ.';

  @override
  String get helpContactQ => 'Khi nào tôi gọi được cho thợ?';

  @override
  String get helpContactA =>
      'Gọi, Zalo, WhatsApp chỉ mở sau khi bạn đã thanh toán. Trước đó bạn nhắn tin hỏi trong ứng dụng. Số điện thoại không hiện công khai.';

  @override
  String get helpReviewQ => 'Cà chua và gạch là gì?';

  @override
  String get helpReviewA =>
      'Cà chua là hài lòng, gạch là chưa hài lòng; bấm 1 đến 10 lần để nói mức độ. Hồ sơ thợ hiện tỉ lệ cà chua. Mỗi buổi chụp đánh giá một lần, gửi rồi không sửa.';

  @override
  String get helpProviderStartQ => 'Làm sao để bắt đầu nhận đơn?';

  @override
  String get helpProviderStartA =>
      'Xác minh số điện thoại, đóng phí xác minh (thợ ảnh 99.000₫, studio 299.000₫, không hoàn), xác minh danh tính bằng VNeID hoặc chip CCCD và đồng ý quy định nhận việc. Nhân viên duyệt trong 24 giờ.';

  @override
  String get helpProviderPaidQ => 'Khi nào tôi nhận được tiền?';

  @override
  String get helpProviderPaidA =>
      'Tiền về theo 2 đợt: sau buổi chụp, và sau khi khách đồng ý ảnh và hết 48 giờ kiểm tra. Chi tự động mỗi ngày vào tài khoản đã xác minh; lần chi đầu do nhân viên duyệt.';

  @override
  String get addonKindMakeup => 'Trang điểm';

  @override
  String get addonKindRetouch => 'Chỉnh ảnh';

  @override
  String get addonKindTransport => 'Đưa đón';

  @override
  String get addonKindOutfit => 'Trang phục';

  @override
  String get addonKindOther => 'Khác';

  @override
  String get addonOnce => 'Một lần';

  @override
  String get addonUnitPerPerson => 'Theo người';

  @override
  String get addonUnitPerItem => 'Theo số lượng';

  @override
  String get addonNounPerson => 'người';

  @override
  String get addonNounPhoto => 'ảnh';

  @override
  String get addonNounSet => 'bộ';

  @override
  String get addonNounTime => 'lần';

  @override
  String addonPriceOnce(String price) {
    return '$price · một lần';
  }

  @override
  String addonPricePer(String price, String noun) {
    return '$price / $noun';
  }

  @override
  String addonLineQty(String name, int qty, String noun) {
    return '$name · $qty $noun';
  }

  @override
  String addonSummaryItem(String name, int qty) {
    return '$name ×$qty';
  }

  @override
  String addonBlockMeta(int qty, String noun, String price) {
    return '$qty $noun × $price';
  }

  @override
  String addonsSummary(String list) {
    return '+ $list';
  }

  @override
  String get addonsTitle => 'Dịch vụ đi kèm';

  @override
  String addonsActiveCount(int n) {
    return '$n/10 dịch vụ đang bật';
  }

  @override
  String get addonsAppliesAll => 'Áp dụng: mọi gói';

  @override
  String addonsAppliesTo(String names) {
    return 'Áp dụng: $names';
  }

  @override
  String addonsToggle(String name) {
    return 'Bật $name';
  }

  @override
  String get addonsAdd => 'Thêm dịch vụ';

  @override
  String get addonsEmptyTitle => 'Chưa có dịch vụ đi kèm';

  @override
  String get addonsEmptyBody =>
      'Thêm trang điểm, chỉnh ảnh hay xe đưa đón để khách chọn khi đặt lịch.';

  @override
  String get addonsLoadError => 'Không tải được dịch vụ đi kèm. Thử lại.';

  @override
  String get addonsLimitReached =>
      'Bạn đã bật đủ 10 dịch vụ. Tắt bớt một dịch vụ để bật dịch vụ này.';

  @override
  String get addonsSaveFailed => 'Không lưu được. Thử lại';

  @override
  String get addonEditAddTitle => 'Thêm dịch vụ đi kèm';

  @override
  String get addonEditEditTitle => 'Sửa dịch vụ đi kèm';

  @override
  String get addonEditClose => 'Đóng';

  @override
  String get addonFieldKind => 'Loại';

  @override
  String get addonFieldName => 'Tên dịch vụ';

  @override
  String get addonFieldDescription => 'Mô tả · không bắt buộc';

  @override
  String get addonFieldUnit => 'Cách tính';

  @override
  String get addonFieldPriceOnce => 'Giá (₫)';

  @override
  String addonFieldPricePer(String noun) {
    return 'Giá / $noun (₫)';
  }

  @override
  String get addonFieldMax => 'Tối đa';

  @override
  String get addonFieldApplies => 'Áp dụng cho';

  @override
  String get addonAppliesAllChip => 'Mọi gói';

  @override
  String get addonAppliesPickChip => 'Chọn gói';

  @override
  String get addonPickPackagesTitle => 'Chọn gói áp dụng';

  @override
  String get addonPickPackagesDone => 'Xong';

  @override
  String get addonResponsibility =>
      'Bạn chịu trách nhiệm với khách về dịch vụ này, kể cả khi thuê người ngoài.';

  @override
  String get addonSave => 'Lưu';

  @override
  String get addonDelete => 'Xoá dịch vụ';

  @override
  String get addonDeleteTitle => 'Xoá dịch vụ này?';

  @override
  String get addonDeleteBody => 'Booking đã đặt vẫn giữ dịch vụ này.';

  @override
  String get addonDeleteConfirm => 'Xoá';

  @override
  String get addonDeleteKeep => 'Giữ lại';

  @override
  String get addonSaved => 'Đã lưu dịch vụ';

  @override
  String get addonDeleted => 'Đã xoá dịch vụ';

  @override
  String get addonErrName => 'Tên 2–60 ký tự';

  @override
  String get addonErrDescription => 'Mô tả tối đa 200 ký tự';

  @override
  String get addonErrPrice => 'Giá từ 10.000₫ tới 50.000.000₫';

  @override
  String get addonErrMaxQty => 'Tối đa từ 1 tới 10';

  @override
  String get addonErrContact =>
      'Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung';

  @override
  String get addonErrPackages => 'Chọn ít nhất một gói';

  @override
  String get settingsAddons => 'Dịch vụ đi kèm';

  @override
  String get profileEditAddons => 'Dịch vụ đi kèm';

  @override
  String get setupAddAddon => 'Thêm dịch vụ đi kèm';

  @override
  String get bookAddonsTitle => 'Thêm dịch vụ';

  @override
  String get bookAddonsOptional => 'Không bắt buộc';

  @override
  String bookAddonLess(String unit) {
    return 'Bớt một $unit';
  }

  @override
  String bookAddonMore(String unit) {
    return 'Thêm một $unit';
  }

  @override
  String bookAddonQty(String name, int qty, String unit) {
    return '$name: $qty $unit';
  }

  @override
  String bookAddonDropped(String names) {
    return 'Đã bỏ $names vì không áp dụng cho gói này';
  }

  @override
  String get bookAddonsChanged =>
      'Dịch vụ đi kèm vừa thay đổi, kiểm tra lại trước khi thanh toán';

  @override
  String get bookPickupTitle => 'Điểm đón';

  @override
  String get bookPickupHint => 'Tên điểm đón (tối thiểu 3 ký tự)';

  @override
  String get bookPickupPrivate => 'Chỉ thợ chụp cho bạn thấy điểm đón.';

  @override
  String get bookPickupRequired => 'Nhập điểm đón cho xe đưa đón';

  @override
  String bookPickupLine(String name) {
    return 'Điểm đón: $name';
  }

  @override
  String get safetyMore => 'Thêm tuỳ chọn';

  @override
  String get safetyShareProfile => 'Chia sẻ hồ sơ';

  @override
  String get safetyLinkCopied => 'Đã sao chép liên kết hồ sơ';

  @override
  String get safetyReport => 'Báo cáo';

  @override
  String get safetyReportPost => 'Báo cáo bài viết';

  @override
  String get safetyReportMessage => 'Báo cáo tin nhắn';

  @override
  String get safetyReportEvent => 'Báo cáo sự kiện';

  @override
  String safetyReportUser(String name) {
    return 'Báo cáo $name';
  }

  @override
  String safetyBlock(String name) {
    return 'Chặn $name';
  }

  @override
  String safetyUnblock(String name) {
    return 'Bỏ chặn $name';
  }

  @override
  String reportTitleUser(String name) {
    return 'Báo cáo $name';
  }

  @override
  String get reportTitlePost => 'Báo cáo bài viết';

  @override
  String get reportTitleMessage => 'Báo cáo tin nhắn';

  @override
  String get reportTitleEvent => 'Báo cáo sự kiện';

  @override
  String get reportAnonymous => 'Người bị báo cáo không biết ai đã báo cáo.';

  @override
  String get reportReasonTitle => 'Vì sao bạn báo cáo?';

  @override
  String get reportReasonSpam => 'Spam hoặc quảng cáo';

  @override
  String get reportReasonScam => 'Lừa đảo, đòi chuyển tiền ngoài ứng dụng';

  @override
  String get reportReasonHarassment => 'Quấy rối hoặc xúc phạm';

  @override
  String get reportReasonInappropriate => 'Nội dung nhạy cảm, không phù hợp';

  @override
  String get reportReasonStolen => 'Ảnh lấy cắp, vi phạm bản quyền';

  @override
  String get reportReasonImpersonation => 'Giả mạo người khác';

  @override
  String get reportReasonOther => 'Lý do khác';

  @override
  String get reportTextLabel => 'Mô tả thêm (tuỳ chọn)';

  @override
  String get reportTextRequired => 'Lý do khác cần mô tả ít nhất 10 ký tự';

  @override
  String reportBlockAlso(String name) {
    return 'Chặn $name';
  }

  @override
  String get reportBlockAlsoBody =>
      'Hai bên không thấy bài của nhau, không nhắn tin hay đặt lịch với nhau.';

  @override
  String get reportSubmit => 'Gửi báo cáo';

  @override
  String get reportSent => 'Đã gửi báo cáo. Cảm ơn bạn.';

  @override
  String reportSentBlocked(String name) {
    return 'Đã gửi báo cáo và chặn $name.';
  }

  @override
  String get reportDuplicate => 'Bạn đã báo cáo nội dung này rồi.';

  @override
  String get reportLimit =>
      'Bạn đã gửi nhiều báo cáo hôm nay. Thử lại ngày mai.';

  @override
  String get reportFailed => 'Chưa gửi được. Thử lại.';

  @override
  String blockConfirmTitle(String name) {
    return 'Chặn $name?';
  }

  @override
  String blockConfirmBody(String name) {
    return 'Hai bên sẽ không thấy bài của nhau, không nhắn tin hay đặt lịch với nhau. Buổi chụp đã đặt vẫn giữ; cần trao đổi thì liên hệ hỗ trợ. $name không nhận thông báo.';
  }

  @override
  String get blockConfirm => 'Chặn';

  @override
  String get blockKeep => 'Không chặn';

  @override
  String blockDone(String name) {
    return 'Đã chặn $name';
  }

  @override
  String get blockFailed => 'Chưa chặn được. Thử lại.';

  @override
  String get blockLimit =>
      'Bạn đã chặn quá nhiều người. Bỏ chặn bớt rồi thử lại.';

  @override
  String unblockConfirmTitle(String name) {
    return 'Bỏ chặn $name?';
  }

  @override
  String get unblockConfirmBody =>
      'Hai bên lại thấy bài của nhau, nhắn tin và đặt lịch được.';

  @override
  String get unblockConfirm => 'Bỏ chặn';

  @override
  String get unblockKeep => 'Giữ chặn';

  @override
  String unblockDone(String name) {
    return 'Đã bỏ chặn $name';
  }

  @override
  String get blockedTitle => 'Người đã chặn';

  @override
  String get blockedNote =>
      'Người bạn chặn không thấy bài của bạn, không nhắn tin hay đặt lịch với bạn. Họ không nhận thông báo.';

  @override
  String blockedSince(String date) {
    return 'Chặn $date';
  }

  @override
  String get blockedUnblock => 'Bỏ chặn';

  @override
  String get blockedEmptyTitle => 'Bạn chưa chặn ai';

  @override
  String get blockedEmptyBody =>
      'Chặn từ menu … trên hồ sơ, bài viết hoặc tin nhắn.';

  @override
  String get settingsBlocked => 'Người đã chặn';

  @override
  String get settingsBlockedBody => 'Xem và bỏ chặn';

  @override
  String profileBlockedByMeTitle(String name) {
    return 'Bạn đã chặn $name';
  }

  @override
  String get profileBlockedByMeBody =>
      'Bỏ chặn để xem hồ sơ, nhắn tin và đặt lịch.';

  @override
  String get profileBlockedByThemTitle => 'Không xem được hồ sơ này';

  @override
  String get profileBlockedByThemBody => 'Hồ sơ này không hiển thị với bạn.';

  @override
  String get postHiddenTitle => 'Không xem được bài này';

  @override
  String get postHiddenBody => 'Bài này không hiển thị với bạn.';

  @override
  String chatBlockedByMe(String name) {
    return 'Bạn đã chặn $name. Bỏ chặn để nhắn tin.';
  }

  @override
  String get chatBlocked =>
      'Không gửi được tin nhắn trong cuộc trò chuyện này.';

  @override
  String get chatMessageRemoved => 'Tin nhắn đã bị gỡ';

  @override
  String get bookingBlockedNote =>
      'Hai bên đã chặn nhau. Cần trao đổi về buổi chụp, hãy liên hệ hỗ trợ.';

  @override
  String get eventErrBlocked => 'Bạn không đăng ký được sự kiện này.';

  @override
  String get chatErrBlocked => 'Không gửi được: hai bên đã chặn nhau.';

  @override
  String deliverySubmitTitle(int round) {
    return 'Nộp bàn giao · vòng $round';
  }

  @override
  String get deliverySamplesHint =>
      '3–20 ảnh mẫu · tự đóng watermark khi tải lên';

  @override
  String get deliveryAddSample => 'Thêm ảnh mẫu';

  @override
  String get deliverySampleProcessing => 'Đang đóng watermark...';

  @override
  String get deliverySampleFailed => 'Lỗi';

  @override
  String get deliverySampleRetry => 'Thử lại';

  @override
  String get deliverySampleRemove => 'Bỏ ảnh này';

  @override
  String get deliveryLinkLabel => 'Link bộ ảnh gốc';

  @override
  String get deliveryLinkInvalid => 'Dán link http(s) hợp lệ';

  @override
  String get deliveryCountLabel => 'Số ảnh gốc';

  @override
  String get deliveryCountInvalid => 'Nhập số ảnh gốc';

  @override
  String get deliveryNoteLabel => 'Ghi chú · tuỳ chọn';

  @override
  String get deliveryLockNote => 'Khách chỉ thấy link sau khi đồng ý ảnh mẫu';

  @override
  String get deliverySubmit => 'Nộp bàn giao';

  @override
  String get deliveryNeedSamples => 'Cần ít nhất 3 ảnh mẫu';

  @override
  String get deliveryTooManySamples => 'Tối đa 20 ảnh mẫu';

  @override
  String get deliveryWaitProcessing => 'Đợi ảnh mẫu đóng watermark xong';

  @override
  String get deliveryCustomerNotes => 'Khách muốn chỉnh sửa';

  @override
  String deliveryCustomerNotesRound(int round) {
    return 'Khách muốn chỉnh sửa vòng $round';
  }

  @override
  String deliveryPhotoNoteCaption(int index, String note) {
    return 'Ảnh $index: $note';
  }

  @override
  String deliverySubmitted(int round) {
    return 'Đã nộp vòng $round';
  }

  @override
  String get deliveryNotReady =>
      'Ảnh mẫu đang xử lý, đợi một chút rồi nộp lại.';

  @override
  String deliveryReviewTitle(int round) {
    return 'Bàn giao · vòng $round';
  }

  @override
  String get deliveryReviewApprovedTitle => 'Bàn giao · đã đồng ý';

  @override
  String get deliveryWaitingApprovalBadge => 'Chờ bạn duyệt';

  @override
  String deliverySenderInfo(String name, int count, String date) {
    return '$name gửi $count ảnh mẫu · $date';
  }

  @override
  String deliveryOriginalsCardTitle(int count) {
    return 'Bộ ảnh gốc · $count ảnh';
  }

  @override
  String get deliveryOriginalsLocked => 'Mở khi bạn đồng ý ảnh';

  @override
  String get deliveryOriginalsOpen => 'Mở bộ ảnh gốc';

  @override
  String deliveryOriginalsSubApproved(String name, String date) {
    return '$name gửi $date';
  }

  @override
  String deliveryRevisionsLeft(int used, int total) {
    return 'Còn $used/$total lượt sửa miễn phí';
  }

  @override
  String deliveryRevisionsExhausted(int total) {
    return 'Hết lượt sửa miễn phí ($total/$total)';
  }

  @override
  String deliveryAutoApproveHint(String time) {
    return 'Tự đồng ý sau $time nếu bạn không phản hồi';
  }

  @override
  String get deliveryRequestRevision => 'Yêu cầu chỉnh sửa';

  @override
  String get deliveryApprove => 'Đồng ý ảnh';

  @override
  String get deliveryAskExtraRound => 'Xin thêm 1 vòng';

  @override
  String deliveryExtraRoundPending(String name) {
    return 'Đã xin thêm 1 vòng · chờ $name trả lời';
  }

  @override
  String get deliveryApproveConfirmTitle => 'Đồng ý ảnh?';

  @override
  String get deliveryApproveConfirmBody =>
      'Đồng ý thì link ảnh gốc mở ra; bạn có 48 giờ để kiểm tra.';

  @override
  String get deliveryApproveConfirmReview => 'Xem lại';

  @override
  String deliveryApprovedToast(String time) {
    return 'Bạn đã đồng ý ảnh lúc $time. Link bộ ảnh gốc đã mở.';
  }

  @override
  String get deliveryCheckCardTitle => 'Kiểm tra bộ ảnh gốc trong 48 giờ';

  @override
  String deliveryCheckCardHoursLeft(int hours) {
    return 'còn $hours giờ';
  }

  @override
  String get deliveryCheckCardHint =>
      'Tải và kiểm tra chất lượng file gốc. Sau 48 giờ hệ thống tự động hoàn tất đơn.';

  @override
  String get deliveryCheckExpired => 'Đã hết thời gian kiểm tra';

  @override
  String get deliveryReportOriginals => 'Báo vấn đề với ảnh gốc';

  @override
  String get deliveryRateShoot => 'Đánh giá buổi chụp';

  @override
  String get deliveryViewReview => 'Xem đánh giá';

  @override
  String get deliverySamplesPurged => 'Ảnh mẫu đã xoá sau 90 ngày';

  @override
  String get deliveryNotFound => 'Không tìm thấy bàn giao';

  @override
  String get deliveryRevisionSheetTitle => 'Yêu cầu chỉnh sửa';

  @override
  String deliveryRevisionSheetSelectedCount(int count) {
    return '$count ảnh';
  }

  @override
  String get deliveryRevisionSheetHint =>
      'Chạm ảnh để sửa ghi chú riêng của ảnh đó.';

  @override
  String get deliveryRevisionGeneralNote => 'Ghi chú chung';

  @override
  String deliveryRevisionRoundFree(int round, int total) {
    return 'Vòng sửa $round/$total (miễn phí)';
  }

  @override
  String get deliveryRevisionSend => 'Gửi yêu cầu';

  @override
  String get deliveryRevisionSendDisabled =>
      'Chọn ảnh hoặc ghi chú điều cần sửa';

  @override
  String deliveryRevisionNoteForPhoto(int index) {
    return 'Ghi chú cho ảnh $index';
  }

  @override
  String get deliveryRevisionChipBrighter => 'Da sáng hơn';

  @override
  String get deliveryRevisionChipLessYellow => 'Bớt vàng';

  @override
  String get deliveryRevisionChipRemoveObject => 'Xoá vật thể';

  @override
  String get deliveryRevisionChipStraighten => 'Cân lại nghiêng';

  @override
  String get deliveryExtraRoundTitle => 'Xin thêm 1 vòng';

  @override
  String deliveryExtraRoundHint(String name) {
    return 'Hết lượt sửa miễn phí. $name có thể cho thêm hoặc không.';
  }

  @override
  String get deliveryExtraRoundSend => 'Gửi đề nghị';

  @override
  String get deliveryReportSheetTitle => 'Báo vấn đề với ảnh gốc';

  @override
  String get deliveryReportReasonBrokenLink =>
      'Link hỏng hoặc không truy cập được';

  @override
  String get deliveryReportReasonMissingFiles => 'Thiếu ảnh so với cam kết';

  @override
  String get deliveryReportReasonWrongFiles => 'Ảnh không đúng buổi chụp';

  @override
  String get deliveryReportReasonOther => 'Lý do khác';

  @override
  String get deliveryReportButton => 'Báo vấn đề';

  @override
  String get deliveryReportSuccess => 'Đã báo vấn đề. Hỗ trợ sẽ liên hệ bạn.';

  @override
  String get settingsPaymentsData => 'Thanh toán và dữ liệu';

  @override
  String get settingsPaymentHistory => 'Lịch sử thanh toán';

  @override
  String get settingsPaymentHistoryBody => 'Khoản đã trả, đang giữ, đang hoàn';

  @override
  String get settingsPrivacy => 'Quyền riêng tư & dữ liệu';

  @override
  String get settingsPrivacyBody =>
      'Ẩn hồ sơ, tải bản sao dữ liệu, xoá tài khoản';

  @override
  String get settingsPrivacyBodyCustomer =>
      'Tải bản sao dữ liệu, xoá tài khoản';

  @override
  String get deleteAccountTitle => 'Xoá tài khoản';

  @override
  String get deleteBlockedTitle => 'Chưa xoá được tài khoản';

  @override
  String get deleteBlockedBody => 'Xong các việc dưới đây rồi quay lại.';

  @override
  String deleteBlockBooking(int count) {
    return '$count buổi chụp chưa xong';
  }

  @override
  String deleteBlockJob(int count) {
    return '$count buổi chụp khách đã đặt';
  }

  @override
  String deleteBlockJobPost(int count) {
    return '$count tin tìm thợ đang mở';
  }

  @override
  String get deleteBlockJobPostBody => 'Đóng tin hoặc chọn thợ trước.';

  @override
  String deleteBlockQuote(int count) {
    return '$count báo giá đang chờ khách';
  }

  @override
  String get deleteBlockQuoteBody => 'Rút báo giá hoặc đợi khách chọn.';

  @override
  String deleteBlockInstant(int count) {
    return '$count yêu cầu Chụp ngay chưa xong';
  }

  @override
  String deleteBlockStudio(int count) {
    return '$count quan hệ studio đang hoạt động';
  }

  @override
  String get deleteBlockStudioBody => 'Rời studio hoặc gỡ thành viên trước.';

  @override
  String deleteBlockCollab(int count) {
    return '$count cộng tác đang mở';
  }

  @override
  String get deleteBlockCollabBody =>
      'Kết thúc cộng tác và xong các việc được giao.';

  @override
  String deleteBlockTicket(int count) {
    return '$count vé sự kiện chưa diễn ra';
  }

  @override
  String deleteBlockEvent(int count) {
    return '$count sự kiện bạn tổ chức còn mở';
  }

  @override
  String deleteBlockDispute(int count) {
    return '$count khiếu nại đang mở';
  }

  @override
  String deleteBlockHeld(String amount) {
    return '$amount đang được giữ';
  }

  @override
  String get deleteBlockHeldBody => 'Đợi tiền được chuyển xong rồi xoá.';

  @override
  String deleteBlockRefund(String amount) {
    return '$amount đang hoàn';
  }

  @override
  String get deleteBlockRefundBody => 'Đợi tiền hoàn về tài khoản của bạn.';

  @override
  String deleteBlockEarnings(String amount) {
    return '$amount chờ chi trả';
  }

  @override
  String get deleteBlockEarningsBody =>
      'Thêm tài khoản nhận tiền hoặc đợi lần chi tới.';

  @override
  String get deleteConsequencesTitle => 'Khi xoá tài khoản';

  @override
  String get deleteConsequence1 =>
      'Tài khoản bị khoá ngay; hồ sơ không còn hiện với người khác.';

  @override
  String get deleteConsequence2 =>
      'Tin nhắn bạn đã gửi vẫn còn ở phía người nhận, tên hiện là \"Người dùng đã xoá\".';

  @override
  String get deleteConsequence3 =>
      'Đánh giá bạn đã viết được giữ, không kèm tên.';

  @override
  String get deleteConsequence4 =>
      'Lịch sử giao dịch được giữ ẩn danh theo quy định kế toán.';

  @override
  String get deleteConsequence5 =>
      'Trong 30 ngày, đăng nhập lại để khôi phục. Sau 30 ngày, hồ sơ, ảnh đại diện, số điện thoại và bài đăng bị xoá hẳn, không khôi phục được.';

  @override
  String get deleteExportHint => 'Muốn giữ dữ liệu? Tải bản sao trước khi xoá.';

  @override
  String get deleteExportHintLink => 'Tải bản sao dữ liệu';

  @override
  String get deleteAction => 'Xoá tài khoản';

  @override
  String get deleteConfirmTitle => 'Xoá tài khoản?';

  @override
  String get deleteConfirmBody =>
      'Tài khoản bị khoá ngay và xoá hẳn sau 30 ngày. Trong 30 ngày, đăng nhập lại để khôi phục. Bạn có thể cần đăng nhập lại để xác nhận.';

  @override
  String get deleteConfirmKeep => 'Giữ tài khoản';

  @override
  String deleteAccountDone(String date) {
    return 'Tài khoản đã khoá, sẽ xoá hẳn vào $date.';
  }

  @override
  String get deleteAccountFailed => 'Chưa xoá được, thử lại sau.';

  @override
  String get privacyTitle => 'Quyền riêng tư & dữ liệu';

  @override
  String get privacyProfile => 'Hồ sơ';

  @override
  String get privacyHide => 'Ẩn hồ sơ khỏi gợi ý và tìm kiếm';

  @override
  String get privacyHideBody =>
      'Hồ sơ không hiện trong Tìm thợ và gợi ý. Khách cũ vẫn mở được hồ sơ và đặt lại; bài đăng vẫn hiện như thường.';

  @override
  String get privacyData => 'Dữ liệu của bạn';

  @override
  String get privacyExport => 'Tải bản sao dữ liệu';

  @override
  String get privacyExportBody =>
      'Hồ sơ, đặt lịch, vé, thanh toán, bài đăng, đánh giá và tin nhắn bạn đã gửi, trong một tệp JSON.';

  @override
  String get privacyExportCreate => 'Tạo bản sao';

  @override
  String get privacyExportCreating => 'Đang tạo bản sao…';

  @override
  String privacyExportReady(String time, String date) {
    return 'Bản sao tạo lúc $time · tải được tới $date';
  }

  @override
  String get privacyExportDownload => 'Tải xuống';

  @override
  String get privacyExportCooldown => 'Mỗi 24 giờ tạo được một bản sao.';

  @override
  String get privacyExportLimit => 'Bạn vừa tạo bản sao, thử lại sau 24 giờ.';

  @override
  String get privacyExportFailed => 'Chưa tạo được bản sao, thử lại sau.';

  @override
  String get privacyDelete => 'Xoá tài khoản';

  @override
  String get restoreAccountTitle => 'Tài khoản đang chờ xoá';

  @override
  String restoreAccountBody(String date) {
    return 'Tài khoản của bạn sẽ bị xoá hẳn vào $date. Khôi phục để dùng tiếp như cũ: hồ sơ, lịch sử và tin nhắn vẫn còn nguyên.';
  }

  @override
  String get restoreAccountAction => 'Khôi phục tài khoản';

  @override
  String get restoreAccountContinue => 'Tiếp tục xoá';

  @override
  String restoreAccountContinueNote(String date) {
    return 'Bạn sẽ được đăng xuất; tài khoản vẫn bị xoá vào $date.';
  }

  @override
  String get restoreAccountExport => 'Tải bản sao dữ liệu';

  @override
  String get restoreAccountDone => 'Đã khôi phục tài khoản.';

  @override
  String get restoreAccountExpired =>
      'Đã quá 30 ngày, tài khoản không khôi phục được nữa.';

  @override
  String get restoreAccountFailed => 'Chưa khôi phục được, thử lại sau.';

  @override
  String get privacyExportPending =>
      'Tài khoản đang chờ xoá, không tạo bản sao mới được.';

  @override
  String get studioMembersTitle => 'Thành viên';

  @override
  String get studioMembersRulesA11y => 'Quy định thành viên';

  @override
  String studioMembersQuota(int n, int max, int k) {
    return '$n/$max thợ · còn $k thao tác hôm nay';
  }

  @override
  String studioMemberAssigned(int m) {
    return '$m việc đang giao';
  }

  @override
  String get studioMemberNoWork => 'chưa có việc';

  @override
  String studioMemberOptions(String name) {
    return 'Tuỳ chọn cho $name';
  }

  @override
  String get studioPendingTitle => 'Đang chờ';

  @override
  String studioPendingCount(int n) {
    return '$n · tối đa 5 lời mời';
  }

  @override
  String studioInviteSentDays(int n) {
    return 'Lời mời đã gửi · Hết hạn sau $n ngày';
  }

  @override
  String get studioInviteSentToday => 'Lời mời đã gửi · Hết hạn trong hôm nay';

  @override
  String studioJoinRequestedAgo(String ago) {
    return 'Xin gia nhập · $ago';
  }

  @override
  String get studioAgoNow => 'vừa xong';

  @override
  String studioAgoMinutes(int n) {
    return '$n phút trước';
  }

  @override
  String studioAgoHours(int n) {
    return '$n giờ trước';
  }

  @override
  String studioAgoDays(int n) {
    return '$n ngày trước';
  }

  @override
  String get studioCancelInvite => 'Huỷ';

  @override
  String get studioDecline => 'Từ chối';

  @override
  String get studioApprove => 'Duyệt';

  @override
  String get studioInviteAction => 'Mời thợ';

  @override
  String get studioMembersEmpty => 'Chưa có thành viên';

  @override
  String get studioMembersEmptyBody =>
      'Mời thợ ảnh bạn tin tưởng; họ nhận lời là vào studio.';

  @override
  String get studioRemoveMember => 'Bỏ khỏi studio';

  @override
  String studioRemoveTitle(String name) {
    return 'Bỏ $name khỏi studio?';
  }

  @override
  String studioRemoveBody(String name) {
    return '$name sẽ không nhận việc của studio nữa và 7 ngày sau mới vào được studio khác.';
  }

  @override
  String get studioRemoveKeep => 'Giữ lại';

  @override
  String studioBusyTitle(int n) {
    return 'Còn $n buổi chụp được giao';
  }

  @override
  String get studioRemoveBusyBody =>
      'Giao các buổi này cho người khác hoặc chờ chụp xong rồi bỏ.';

  @override
  String get studioSheetClose => 'Đóng';

  @override
  String get studioFullUnverified =>
      'Đã đủ 3 thợ. Xác minh doanh nghiệp để nhận tới 30 thợ.';

  @override
  String get studioFullVerifyAction => 'Xác minh doanh nghiệp';

  @override
  String get studioQuotaOut => 'Hết thao tác hôm nay. Thử lại ngày mai.';

  @override
  String get studioRulesTitle => 'Quy định thành viên';

  @override
  String get studioRule1 =>
      'Vào studio cần hai bên đồng ý: studio mời và thợ nhận, hoặc thợ xin và studio duyệt.';

  @override
  String get studioRule2 => 'Lời mời hết hạn sau 7 ngày, tối đa 5 lời mời chờ.';

  @override
  String get studioRule3 =>
      'Mỗi thợ ở tối đa một studio. Rời hoặc bị bỏ thì 7 ngày sau mới vào được studio khác.';

  @override
  String get studioRule4 =>
      'Tối đa 3 thợ khi studio chưa xác minh doanh nghiệp, 30 khi đã xác minh; tối đa 5 thao tác thành viên mỗi ngày.';

  @override
  String get studioRule5 =>
      'Không bỏ được thành viên còn buổi chụp được giao chưa xong.';

  @override
  String get studioInviteTitle => 'Mời thợ';

  @override
  String get studioInviteSearch => 'Tìm thợ theo tên';

  @override
  String get studioInviteRowAction => 'Mời';

  @override
  String studioInviteInStudio(String studio) {
    return 'Đang ở $studio';
  }

  @override
  String studioInviteCooldown(String date) {
    return 'Mời được từ $date';
  }

  @override
  String get studioInviteInvited => 'Đã mời';

  @override
  String get studioInviteMember => 'Đã là thành viên';

  @override
  String get studioInviteFootnote =>
      'Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ';

  @override
  String get studioInviteFullPending => 'Đã có 5 lời mời chờ';

  @override
  String studioInviteFullMembers(int max) {
    return 'Studio đã đủ $max thợ';
  }

  @override
  String get studioInviteNoResults => 'Không tìm thấy thợ tên này';

  @override
  String studioInviteDone(String name) {
    return 'Đã gửi lời mời tới $name';
  }

  @override
  String get myStudioTitle => 'Studio của tôi';

  @override
  String myStudioSince(String month, int m) {
    return 'Thành viên từ $month · $m việc được giao';
  }

  @override
  String myStudioSinceOnly(String month) {
    return 'Thành viên từ $month';
  }

  @override
  String get myStudioView => 'Xem studio';

  @override
  String get myStudioJobs => 'Việc studio giao';

  @override
  String get myStudioAssignedBadge => 'Đã giao';

  @override
  String get myStudioLeave => 'Rời studio';

  @override
  String get myStudioInvites => 'Lời mời';

  @override
  String get myStudioAccept => 'Nhận';

  @override
  String get myStudioDecline => 'Từ chối';

  @override
  String myStudioInviteBlocked(String studio) {
    return 'Bạn đang ở $studio';
  }

  @override
  String myStudioInviteExpires(int n) {
    return 'Hết hạn sau $n ngày';
  }

  @override
  String get myStudioInviteExpiresToday => 'Hết hạn trong hôm nay';

  @override
  String get myStudioCooldownNote =>
      'Rời hoặc bị bỏ khỏi studio thì 7 ngày sau mới vào được studio khác.';

  @override
  String get myStudioNone => 'Bạn chưa ở studio nào';

  @override
  String get myStudioNoneBody =>
      'Studio mời bạn, hoặc bạn xin gia nhập từ hồ sơ studio.';

  @override
  String myStudioRequestPending(String studio) {
    return 'Đã xin gia nhập $studio · chờ duyệt';
  }

  @override
  String myStudioRequestSent(String ago, int n) {
    return 'Gửi $ago · hết hạn sau $n ngày';
  }

  @override
  String myStudioRequestSentToday(String ago) {
    return 'Gửi $ago · hết hạn trong hôm nay';
  }

  @override
  String get myStudioRequestCancel => 'Huỷ';

  @override
  String myStudioLeaveTitle(String studio) {
    return 'Rời $studio?';
  }

  @override
  String myStudioLeaveBody(String studio) {
    return '7 ngày sau bạn mới vào được studio khác, kể cả $studio.';
  }

  @override
  String get myStudioLeaveKeep => 'Ở lại';

  @override
  String get myStudioLeaveBusyBody =>
      'Chụp xong hoặc nhờ studio giao người khác rồi rời.';

  @override
  String settingsStudioMembersQuota(int n, int max) {
    return '$n/$max thợ';
  }

  @override
  String get settingsMyStudioNone => 'Chưa ở studio nào';

  @override
  String get studioErr_membership_conflict => 'Thợ này đang ở một studio khác.';

  @override
  String get studioErr_cooldown => 'Chưa đủ 7 ngày kể từ lần rời studio.';

  @override
  String get studioErr_member_busy => 'Còn buổi chụp được giao chưa xong.';

  @override
  String get studioErr_studio_full =>
      'Studio đã đủ số thợ hoặc đủ 5 lời mời chờ.';

  @override
  String get studioErr_rate_limited =>
      'Hết thao tác hôm nay. Thử lại ngày mai.';

  @override
  String get studioErr_not_accepting_orders =>
      'Thợ này chưa xác minh nên chưa giao việc được.';

  @override
  String get studioErr_day_taken => 'Thợ này đã bận ngày này.';

  @override
  String get studioErr_conflict => 'Yêu cầu đã được xử lý trước đó.';

  @override
  String get studioErr_generic => 'Chưa thực hiện được. Thử lại.';

  @override
  String get profileMembersTile => 'thành viên';

  @override
  String get profileYearsTile => 'hoạt động';

  @override
  String get profileMembersTitle => 'Thành viên';

  @override
  String profileMembersA11y(String studio) {
    return 'Thành viên $studio';
  }

  @override
  String profileMoreMembersA11y(int n) {
    return 'và $n thành viên khác';
  }

  @override
  String get profileJoinStudio => 'Xin gia nhập';

  @override
  String get profileJoinRequested => 'Đã xin gia nhập';

  @override
  String profileJoinSent(String studio) {
    return 'Đã gửi yêu cầu tới $studio';
  }

  @override
  String profileJoinCooldown(String date) {
    return 'Bạn vào được studio từ $date';
  }

  @override
  String profileMemberOf(String studio) {
    return 'Thành viên của $studio';
  }

  @override
  String get workAssignAction => 'Giao thợ';

  @override
  String workAssignedTo(String name) {
    return 'Thợ: $name';
  }

  @override
  String get workAssignOverdue => 'Quá hạn giao thợ';

  @override
  String workAssignDeadline(String deadline) {
    return 'Hạn giao thợ: $deadline';
  }

  @override
  String workChangeRequested(String time) {
    return 'Khách xin đổi thợ · trả lời trước $time';
  }

  @override
  String get workChangeDecline => 'Từ chối đổi';

  @override
  String get changeDeclineTitle => 'Từ chối đổi thợ?';

  @override
  String get changeDeclineReason => 'Lý do (bắt buộc)';

  @override
  String get changeDeclineBody =>
      'Khách sẽ thấy lý do và được huỷ, hoàn 100% nếu không muốn giữ thợ hiện tại.';

  @override
  String get changeDeclineConfirm => 'Từ chối đổi';

  @override
  String get changeDeclineKeep => 'Quay lại';

  @override
  String get workReturnJob => 'Trả việc';

  @override
  String get returnJobTitle => 'Trả lại buổi chụp này?';

  @override
  String returnJobBody(String studio) {
    return '$studio được báo để giao người khác. Bạn vẫn là thợ của buổi này tới khi studio giao lại.';
  }

  @override
  String get returnJobReason => 'Lý do (tuỳ chọn)';

  @override
  String get returnJobConfirm => 'Trả việc';

  @override
  String get returnJobKeep => 'Giữ việc';

  @override
  String get workReturned => 'Đã trả việc · chờ studio giao lại';

  @override
  String workAssigneeReturned(String name) {
    return '$name đã trả việc';
  }

  @override
  String get workAssigneeReturnedNoName => 'Thợ đã trả việc';

  @override
  String get assignTitle => 'Giao thợ';

  @override
  String assignSummary(String service, String day, String start, String end) {
    return '$service · $day · $start–$end';
  }

  @override
  String assignDeadline(String deadline, String left) {
    return 'Hạn giao thợ: $deadline (còn $left)';
  }

  @override
  String assignDeadlinePassed(String deadline) {
    return 'Đã quá hạn giao thợ ($deadline)';
  }

  @override
  String assignLeftDays(int n) {
    return '$n ngày';
  }

  @override
  String assignLeftHours(int n) {
    return '$n giờ';
  }

  @override
  String get assignFree => 'Rảnh';

  @override
  String assignBusy(String start, String end) {
    return 'Bận $start–$end';
  }

  @override
  String get assignBusyAllDay => 'Bận cả ngày';

  @override
  String get assignUnverified => 'Chưa xác minh';

  @override
  String get assignCurrent => 'Đang giao';

  @override
  String assignNote(String name) {
    return 'Khách được báo ngay; $name vào nhóm chat của buổi chụp.';
  }

  @override
  String get assignLateWarning =>
      'Còn dưới 24 giờ: đổi thợ lúc này thì khách được huỷ và hoàn 100%.';

  @override
  String assignAction(String name) {
    return 'Giao cho $name';
  }

  @override
  String get assignNoMembers => 'Studio chưa có thành viên nào để giao.';

  @override
  String get assignPickerA11y => 'Chọn thợ chụp';

  @override
  String get changeTitle => 'Xin đổi thợ chụp';

  @override
  String get changeCurrent => 'Thợ hiện tại';

  @override
  String get changeReasonLabel => 'Lý do (tuỳ chọn)';

  @override
  String get changeNoteRespond => 'Studio trả lời trong 6 giờ.';

  @override
  String get changeNoteRefund =>
      'Nếu studio từ chối hoặc không trả lời, bạn được huỷ và hoàn 100%.';

  @override
  String get changeOnce => 'Bạn chỉ xin đổi được 1 lần.';

  @override
  String get changeSend => 'Gửi yêu cầu đổi';

  @override
  String get changeSent => 'Đã gửi yêu cầu đổi thợ';

  @override
  String get assigneeSection => 'Thợ chụp cho bạn';

  @override
  String assigneeAssignedOn(String date) {
    return 'Giao $date';
  }

  @override
  String assigneeWaiting(String deadline) {
    return 'Studio sẽ báo thợ chụp trước $deadline';
  }

  @override
  String assigneeMeta(int shoots, String studio) {
    return '$shoots buổi · thợ của $studio';
  }

  @override
  String get assigneeViewProfile => 'Xem hồ sơ';

  @override
  String get assigneeChange => 'Xin đổi thợ (1 lần)';

  @override
  String get assigneeChangePending => 'Đã xin đổi · chờ studio';

  @override
  String get assigneeOverdueLabel => 'Quá hạn';

  @override
  String assigneeOverdueTitle(String deadline) {
    return 'Studio chưa báo thợ chụp đúng hạn (trước $deadline)';
  }

  @override
  String get assigneeOverdueBody =>
      'Bạn có thể chờ thêm hoặc huỷ và được hoàn 100%.';

  @override
  String get assigneeCancelFull => 'Huỷ và hoàn 100%';

  @override
  String assigneeReminded(String studio, String first, String second) {
    return 'Đã nhắc $studio lúc $first và $second.';
  }

  @override
  String get assigneeChangeDeclinedTitle => 'Studio không đổi thợ chụp';

  @override
  String assigneeChangeDeclinedBody(String reason) {
    return 'Lý do: $reason. Bạn giữ thợ hiện tại hoặc huỷ và được hoàn 100%.';
  }

  @override
  String get assigneeChangeExpiredTitle =>
      'Studio chưa trả lời yêu cầu đổi thợ';

  @override
  String get assigneeChangeExpiredBody =>
      'Bạn giữ thợ hiện tại hoặc huỷ và được hoàn 100%.';

  @override
  String get assigneeLateReassignTitle =>
      'Studio đã đổi thợ khi còn dưới 24 giờ';

  @override
  String get assigneeLateReassignBody => 'Bạn có thể huỷ và được hoàn 100%.';

  @override
  String get timelineAssigned => 'Đã giao thợ chụp';

  @override
  String timelineAssignedBody(String name) {
    return '$name đã vào nhóm chat của buổi chụp';
  }

  @override
  String get timelineAwaitAssign => 'Chờ studio giao thợ chụp';

  @override
  String timelineAwaitAssignBody(String deadline) {
    return 'Quá hạn từ $deadline';
  }

  @override
  String get detailMessageStudio => 'Nhắn studio';

  @override
  String get cancelStudioFaultTitle => 'Huỷ và hoàn 100%?';

  @override
  String get cancelStudioFaultLine => 'Hoàn 100% số đã trả';

  @override
  String get cancelStudioFaultBody =>
      'Studio chưa giữ đúng cam kết về thợ chụp nên bạn được hoàn toàn bộ số đã trả.';

  @override
  String get cancelStudioFaultConfirm => 'Huỷ và hoàn 100%';

  @override
  String get cancelStudioFaultKeep => 'Giữ lịch';

  @override
  String reviewCardAssignee(String day, String name) {
    return '$day · thợ $name';
  }

  @override
  String reviewBlockAssignee(String name) {
    return 'Thợ $name';
  }

  @override
  String get reviewBlockAssigneeNote => 'Tính cho hồ sơ thợ';

  @override
  String get reviewBlockStudioNote => 'Tính cho studio';

  @override
  String get reviewNoteForAssignee => 'Nhận xét cho thợ';

  @override
  String get reviewNoteForStudio => 'Nhận xét cho studio';

  @override
  String get reviewSubmitTwo => 'Gửi 2 đánh giá';

  @override
  String get reviewMissingAssignee => 'Còn thiếu đánh giá cho thợ';

  @override
  String get reviewMissingStudio => 'Còn thiếu đánh giá cho studio';

  @override
  String get reviewStudioReason_late_assignment => 'Báo thợ trễ';

  @override
  String get reviewStudioReason_slow_response => 'Tư vấn chậm';

  @override
  String get reviewStudioReason_price_changed => 'Đổi giá';

  @override
  String get reviewStudioReason_poor_assignment => 'Giao thợ không hợp';

  @override
  String get reviewStudioReason_other => 'Khác';

  @override
  String reviewA11yTomatoFor(String who, int n) {
    return 'Ném cà chua cho $who, $n trên 10';
  }

  @override
  String reviewA11yBrickFor(String who, int n) {
    return 'Ném gạch cho $who, $n trên 10';
  }

  @override
  String reviewShotBy(String name) {
    return 'Chụp bởi $name';
  }

  @override
  String reviewViaStudio(String studio) {
    return 'Qua $studio';
  }

  @override
  String get reviewWhoAssignee => 'thợ';

  @override
  String get reviewWhoStudio => 'studio';

  @override
  String reviewGroupAssigneeA11y(String name) {
    return 'Đánh giá thợ $name';
  }

  @override
  String reviewGroupStudioA11y(String studio) {
    return 'Đánh giá $studio';
  }

  @override
  String get reviewNoAssigneeTitle => 'Chưa đánh giá được';

  @override
  String get reviewNoAssigneeBody => 'Studio chưa giao thợ chụp cho buổi này.';

  @override
  String get homeHotSpotsTitle => 'Điểm chụp đang hot';

  @override
  String get homeHotSpots => 'Điểm chụp đang hot';

  @override
  String get homeHotSpotsSeeAll => 'Xem tất cả';

  @override
  String homeSpotProvidersWeek(int count) {
    return '$count thợ nhận chụp tuần này';
  }

  @override
  String spotProvidersThisWeek(int count) {
    return '$count thợ nhận chụp tuần này';
  }

  @override
  String get exploreNearbySpotsTitle => 'Điểm chụp gần bạn';

  @override
  String get exploreSpotsNearby => 'Điểm chụp gần bạn';

  @override
  String get exploreSpotSectionTitle => 'Điểm chụp';

  @override
  String get spotsTitle => 'Điểm chụp';

  @override
  String get spotsFilterArea => 'Khu vực';

  @override
  String get spotsFilterAllAreas => 'Mọi khu vực';

  @override
  String get spotsFilterInSeason => 'Đang vào mùa';

  @override
  String get spotsFilterWeekend => 'Cuối tuần này có thợ';

  @override
  String spotsInSeasonCount(int count) {
    return '$count điểm đang vào mùa';
  }

  @override
  String get spotsEmpty => 'Chưa có điểm chụp nào ở khu vực này';

  @override
  String get spotsLoadError => 'Không tải được điểm chụp.';

  @override
  String get spotInSeason => 'Đang vào mùa';

  @override
  String spotInSeasonUntil(int month) {
    return 'Đang vào mùa · tới cuối tháng $month';
  }

  @override
  String spotSeasonEnding(int month) {
    return 'Đang vào mùa · tới cuối tháng $month';
  }

  @override
  String spotSeasonRange(int from, int to) {
    return 'Mùa đẹp: tháng $from–$to';
  }

  @override
  String spotSeasonList(String months) {
    return 'Mùa đẹp: tháng $months';
  }

  @override
  String spotSeasonBest(String range) {
    return 'Mùa đẹp: $range';
  }

  @override
  String get spotSeasonAllYear => 'Đẹp quanh năm';

  @override
  String spotPhotoAlt(String name) {
    return 'Ảnh chụp tại $name';
  }

  @override
  String get spotArchivedBand => 'Điểm này không còn nhận lịch mới';

  @override
  String get spotArchivedNotice => 'Điểm này không còn nhận lịch mới';

  @override
  String spotsCardStats(int providers, int events) {
    return '$providers thợ · $events sự kiện sắp tới';
  }

  @override
  String spotCardStats(int providers, int events) {
    return '$providers thợ · $events sự kiện sắp tới';
  }

  @override
  String spotAvailableLabel(String day, String start, String end) {
    return 'Có mặt $day · $start–$end';
  }

  @override
  String spotProviderAvailable(String day, String start, String end) {
    return 'Có mặt $day · $start–$end';
  }

  @override
  String get spotShare => 'Chia sẻ';

  @override
  String get spotLinkCopied => 'Đã sao chép liên kết điểm chụp';

  @override
  String get spotCopiedLink => 'Đã sao chép liên kết điểm chụp';

  @override
  String get spotTipsTitle => 'Mẹo chụp';

  @override
  String get spotDirections => 'Chỉ đường';

  @override
  String get spotProvidersTitle => 'Thợ nhận chụp ở đây';

  @override
  String get spotToday => 'Hôm nay';

  @override
  String get spotDayToday => 'Hôm nay';

  @override
  String get spotPickDate => 'Chọn ngày';

  @override
  String get spotDayPick => 'Chọn ngày';

  @override
  String get spotBook => 'Đặt';

  @override
  String get spotProfile => 'Hồ sơ';

  @override
  String get spotOffersTitle => 'Gói chụp tại điểm';

  @override
  String spotOfferLine(String name, String price, int count, String day) {
    return '$name · $price · còn $count suất $day';
  }

  @override
  String spotOfferFull(String name, String price, String day) {
    return '$name · $price · hết suất $day';
  }

  @override
  String get spotPickSlot => 'Chọn suất';

  @override
  String get spotEventsTitle => 'Sự kiện ở đây';

  @override
  String get spotPhotosTitle => 'Ảnh chụp ở đây';

  @override
  String spotPhotosCount(int count) {
    return '$count bài';
  }

  @override
  String get spotNoProviderDay =>
      'Chưa có thợ nhận chụp ngày này · Xem ngày khác';

  @override
  String get spotEmptyDayTitle => 'Chưa có thợ nhận chụp ngày này';

  @override
  String get spotEmptyDayAction => 'Xem ngày khác';

  @override
  String get spotProviderHint =>
      'Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc.';

  @override
  String get spotNotFound => 'Không tìm thấy điểm chụp.';

  @override
  String spotPriceFrom(String price) {
    return 'từ $price';
  }

  @override
  String spotFreeSlotsCount(int count, String day) {
    return 'Còn $count suất $day';
  }

  @override
  String get spotSlotsFull => 'Hết suất';

  @override
  String get spotSeeMore => 'Xem thêm';

  @override
  String get slotPickTitle => 'Chọn suất';

  @override
  String get slotTaken => 'Đã kín';

  @override
  String slotContinue(String price) {
    return 'Tiếp tục · $price';
  }

  @override
  String get slotTakenError => 'Suất này vừa có người đặt. Chọn suất khác.';

  @override
  String slotPickDayLine(String day, int free, int total) {
    return '$day · còn $free / $total suất';
  }

  @override
  String slotPickOfferMeta(String spot, int edited, int days) {
    return 'Tại $spot · $edited ảnh chỉnh · giao trong $days ngày. Gói chia suất không kèm dịch vụ đi kèm.';
  }

  @override
  String get slotPickDays => 'Ngày chụp';

  @override
  String get slotPickTimes => 'Giờ bắt đầu';

  @override
  String bookAtSpot(String spot) {
    return 'Tại $spot';
  }

  @override
  String get bookSpotPlaceLocked => 'Địa điểm là điểm chụp, không đổi được.';

  @override
  String bookSpotScheduleLine(String days, String start, String end) {
    return 'Lịch tại điểm · $days · $start–$end';
  }

  @override
  String bookSpotEndsAt(
    String start,
    String end,
    String from,
    String to,
    String name,
  ) {
    return '$start–$end · chỉ giờ còn trống trong khung $from–$to của $name';
  }

  @override
  String get bookSpotDaysOnly => 'Chỉ ngày có lịch tại điểm';

  @override
  String get bookOutsideSchedule =>
      'Lịch tại điểm vừa thay đổi. Chọn lại ngày giờ.';

  @override
  String get bookSlotTaken => 'Giờ này vừa có người đặt. Chọn giờ khác.';

  @override
  String get bookSpotArchived => 'Điểm này không còn nhận lịch mới.';

  @override
  String get spotSchedulesTitle => 'Lịch tại điểm';

  @override
  String spotSchedulesOpenCount(int count) {
    return '$count / 8 lịch đang mở';
  }

  @override
  String get spotSchedulesAdd => 'Thêm lịch tại điểm';

  @override
  String get spotSchedulesVerify => 'Xác minh để mở lịch';

  @override
  String get spotSchedulesEmptyTitle => 'Chưa có lịch tại điểm';

  @override
  String get spotSchedulesEmptyBody =>
      'Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt.';

  @override
  String get spotSchedulesRule =>
      'Ngày tại điểm chỉ nhận booking ở điểm đó, nhiều booking không chồng giờ. Ngày đó bạn không nhận booking ở nơi khác.';

  @override
  String spotScheduleDaysRange(String weekdays, String from, String to) {
    return '$weekdays · $from–$to';
  }

  @override
  String spotScheduleDays(int count, String start, String end) {
    return '$count ngày · $start–$end';
  }

  @override
  String spotScheduleSummary(String days, String packages) {
    return '$days · $packages';
  }

  @override
  String spotSchedulePackagesCount(int count) {
    return '$count gói';
  }

  @override
  String get spotSchedulePackagesAll => 'mọi gói';

  @override
  String spotScheduleDayCount(String day, int count) {
    return '$day · $count booking';
  }

  @override
  String spotScheduleMoreDays(int count) {
    return '+$count ngày';
  }

  @override
  String get spotScheduleDayCountsLabel => 'Booking theo ngày';

  @override
  String get spotScheduleNoBookings => 'Chưa có booking';

  @override
  String get spotScheduleNoOffers => 'Chưa có gói chia suất';

  @override
  String get spotScheduleNoBookingsNoOffers =>
      'Chưa có booking · chưa có gói chia suất';

  @override
  String spotScheduleOfferMeta(String price, int count) {
    return '$price · $count suất/ngày';
  }

  @override
  String get spotScheduleEdit => 'Sửa';

  @override
  String get spotScheduleOffersAction => 'Gói chia suất';

  @override
  String get spotScheduleCancel => 'Huỷ lịch';

  @override
  String spotScheduleCancelTitle(String spot) {
    return 'Huỷ lịch tại $spot?';
  }

  @override
  String get spotScheduleCancelBody =>
      'Khách sẽ không đặt được các ngày còn lại của lịch này.';

  @override
  String get spotScheduleCancelConfirm => 'Huỷ lịch';

  @override
  String get spotScheduleCancelKeep => 'Giữ lại';

  @override
  String spotScheduleHasBookings(int count, String day) {
    return 'Còn $count booking ngày $day. Liên hệ khách hoặc huỷ từng booking (khách được hoàn 100%).';
  }

  @override
  String get spotScheduleCancelled => 'Đã huỷ lịch tại điểm';

  @override
  String get spotScheduleCancelFailed => 'Không huỷ được lịch. Thử lại.';

  @override
  String get spotScheduleNewTitle => 'Thêm lịch tại điểm';

  @override
  String get spotScheduleEditTitle => 'Sửa lịch tại điểm';

  @override
  String spotScheduleLimitCount(int count) {
    return '$count / 8';
  }

  @override
  String get spotScheduleSpot => 'Điểm chụp';

  @override
  String get spotScheduleSpotPick => 'Chọn điểm chụp';

  @override
  String get spotScheduleSearch => 'Tìm theo tên điểm';

  @override
  String get spotScheduleSpotNone => 'Không có điểm nào khớp';

  @override
  String get spotScheduleSpotRequired => 'Chọn một điểm chụp';

  @override
  String get spotScheduleMember => 'Thợ chụp';

  @override
  String get spotScheduleMemberRequired => 'Chọn thợ chụp ở điểm này';

  @override
  String get spotScheduleNoMembers => 'Studio chưa có thợ để giao lịch.';

  @override
  String get spotScheduleMemberNotAccepting =>
      'Thợ này chưa được duyệt nhận đơn. Chọn thợ khác.';

  @override
  String get spotScheduleDaysLabel => 'Ngày';

  @override
  String get spotScheduleRepeat => 'Lặp lại';

  @override
  String get spotSchedulePickDays => 'Chọn ngày';

  @override
  String get spotScheduleWeekdays => 'Thứ trong tuần';

  @override
  String get spotScheduleFrom => 'Từ ngày';

  @override
  String get spotScheduleTo => 'Tới ngày';

  @override
  String get spotScheduleStart => 'Bắt đầu';

  @override
  String get spotScheduleEnd => 'Kết thúc';

  @override
  String get spotSchedulePackages => 'Gói đặt được';

  @override
  String get spotScheduleAllPackages => 'Mọi gói đang bật';

  @override
  String spotScheduleConflictBooked(String day) {
    return '$day đã có booking ở nơi khác.';
  }

  @override
  String spotScheduleConflictPending(String day) {
    return '$day đang có booking chờ nhận.';
  }

  @override
  String spotScheduleConflictOff(String day) {
    return '$day bạn đã đánh dấu nghỉ.';
  }

  @override
  String spotScheduleConflictSpot(String day) {
    return '$day đã có lịch tại điểm khác.';
  }

  @override
  String spotScheduleConflictFull(String day) {
    return '$day studio hết chỗ.';
  }

  @override
  String get spotScheduleConflictHint => 'Bỏ ngày này để mở lịch.';

  @override
  String spotScheduleRemoveDay(String day) {
    return '$day trùng lịch, chạm để bỏ';
  }

  @override
  String spotScheduleOffSeason(String months) {
    return 'Điểm này đẹp nhất tháng $months';
  }

  @override
  String get spotScheduleOpen => 'Mở lịch';

  @override
  String get spotScheduleSave => 'Lưu thay đổi';

  @override
  String get spotScheduleSaved => 'Đã mở lịch tại điểm';

  @override
  String get spotScheduleUpdated => 'Đã lưu lịch tại điểm';

  @override
  String get spotScheduleLimit =>
      'Bạn đã có 8 lịch tại điểm đang mở. Huỷ bớt một lịch để mở lịch mới.';

  @override
  String get spotScheduleNoDays => 'Chọn ít nhất một ngày';

  @override
  String get spotScheduleTooMany =>
      'Tối đa 40 ngày mỗi lịch, trong 60 ngày tới';

  @override
  String get spotScheduleWindowInvalid =>
      'Khung giờ từ 05:00 tới 21:00, dài 1–12 giờ';

  @override
  String get spotScheduleNotAccepting =>
      'Bạn cần được duyệt nhận đơn trước khi mở lịch tại điểm.';

  @override
  String get spotScheduleError => 'Không lưu được. Thử lại.';

  @override
  String get spotScheduleNoPackages =>
      'Bật ít nhất một gói chụp trước khi mở lịch tại điểm.';

  @override
  String get slotOfferTitle => 'Gói chia suất';

  @override
  String get slotOfferDismiss => 'Đóng';

  @override
  String slotOfferScheduleLine(
    String spot,
    String weekdays,
    String start,
    String end,
  ) {
    return '$spot · $weekdays · $start–$end';
  }

  @override
  String get slotOfferName => 'Tên gói';

  @override
  String get slotOfferPrice => 'Giá mỗi suất';

  @override
  String get slotOfferDelivery => 'Giao ảnh trong';

  @override
  String get slotOfferDeliveryUnit => 'ngày';

  @override
  String get slotOfferPhotos => 'Số ảnh';

  @override
  String get slotOfferEdited => 'Số ảnh chỉnh';

  @override
  String get slotOfferMinutes => 'Thời lượng suất';

  @override
  String get slotOfferMinutesRange => '15–90 phút';

  @override
  String get slotOfferGap => 'Nghỉ giữa suất';

  @override
  String get slotOfferGapRange => '0–30 phút';

  @override
  String slotOfferMinutesValue(int count) {
    return '$count phút';
  }

  @override
  String get slotOfferLess => 'Bớt';

  @override
  String get slotOfferMore => 'Thêm';

  @override
  String slotOfferPreview(int count, String times) {
    return '$count suất/ngày: $times';
  }

  @override
  String get slotOfferNote =>
      'Gói chia suất không kèm dịch vụ đi kèm. Tối đa 2 gói mỗi lịch.';

  @override
  String get slotOfferSave => 'Lưu';

  @override
  String get slotOfferClose => 'Đóng gói';

  @override
  String slotOfferCloseTitle(String name) {
    return 'Đóng gói $name?';
  }

  @override
  String get slotOfferCloseBody => 'Khách đã đặt vẫn giữ suất của mình.';

  @override
  String get slotOfferKeep => 'Giữ lại';

  @override
  String get slotOfferLimit => 'Mỗi lịch tối đa 2 gói chia suất';

  @override
  String get slotOfferErrorName => 'Tên 3–60 ký tự';

  @override
  String get slotOfferErrorPrice => 'Giá từ 10.000₫ tới 100.000.000₫';

  @override
  String get slotOfferErrorFit => 'Khung giờ không đủ cho một suất';

  @override
  String get slotOfferErrorContact =>
      'Bỏ số điện thoại, Zalo hoặc link ra khỏi tên gói';

  @override
  String get slotOfferErrorPhotos => 'Số ảnh từ 1 tới 500';

  @override
  String get slotOfferErrorEdited => 'Số ảnh chỉnh không quá số ảnh';

  @override
  String get slotOfferErrorDelivery => 'Giao ảnh trong 1–30 ngày';

  @override
  String get slotOfferSaved => 'Đã lưu gói chia suất';

  @override
  String get slotOfferClosed => 'Đã đóng gói chia suất';

  @override
  String get workSpotSchedules => 'Lịch tại điểm';

  @override
  String get workSpotSchedulesSub => 'Nhận chụp ở điểm đang hot';

  @override
  String get spotSchedulePackagesInvalid =>
      'Có gói không dùng được trong khung giờ này. Chọn lại gói.';

  @override
  String get spotScheduleAddOffer => 'Thêm gói chia suất';

  @override
  String spotNameCity(String name, String city) {
    return '$name · $city';
  }

  @override
  String spotCitySeason(String city, String season) {
    return '$city · $season';
  }

  @override
  String spotScheduleConflictDay(String day) {
    return '$day ×';
  }

  @override
  String workSpotSchedulesOpen(int count) {
    return 'Lịch tại điểm · $count đang mở';
  }

  @override
  String get instantTitle => 'Chụp ngay';

  @override
  String get instantGenrePortrait => 'Chân dung';

  @override
  String get instantGenreCouple => 'Cặp đôi';

  @override
  String get instantGenreFamily => 'Gia đình';

  @override
  String get instantGenreEvent => 'Sự kiện nhỏ';

  @override
  String get instantGenreProduct => 'Sản phẩm';

  @override
  String instantDurationMinutes(int n) {
    return '$n phút';
  }

  @override
  String instantDurationHours(int n) {
    return '$n giờ';
  }

  @override
  String instantPackageLabel(String duration, int photos) {
    return '$duration · $photos ảnh';
  }

  @override
  String get instantStatusAssigned => 'Đã nhận';

  @override
  String get instantStatusEnRoute => 'Đang đến';

  @override
  String get instantStatusArrived => 'Đã đến';

  @override
  String get instantStatusInProgress => 'Đang chụp';

  @override
  String get instantStatusFinished => 'Chờ khách xác nhận';

  @override
  String get instantErrorGeneric => 'Chưa thực hiện được. Thử lại nhé.';

  @override
  String get instantErrorNetwork => 'Mất kết nối. Thử lại nhé.';

  @override
  String get instantSubtitle => 'Nhiếp ảnh gia tới trong 30–90 phút';

  @override
  String get instantCardBody =>
      'Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút';

  @override
  String get instantCardResumeTitle => 'Yêu cầu chụp ngay đang mở';

  @override
  String get instantCardResumeBody => 'Chạm để xem tiếp';

  @override
  String get instantFindButton => 'Chụp ngay · tới trong 30–90 phút';

  @override
  String instantMeetPointPin(String name) {
    return 'Điểm hẹn · $name';
  }

  @override
  String get instantMeetPointSelf => 'Vị trí của bạn';

  @override
  String get instantMeetPointLabel => 'Tên điểm hẹn';

  @override
  String get instantMeetPointHint =>
      'Ví dụ: Cổng Trương Định, Công viên Tao Đàn';

  @override
  String get instantMeetPointRequired =>
      'Nhập tên điểm hẹn để nhiếp ảnh gia dễ tìm.';

  @override
  String instantPhotosCount(int n) {
    return '$n ảnh';
  }

  @override
  String get instantNoteLabel => 'Ghi chú cho nhiếp ảnh gia';

  @override
  String get instantNoteHint => 'Mình mặc áo dài trắng, chụp ở hồ…';

  @override
  String get instantEscrowNote =>
      'Xem 5 người phù hợp miễn phí. Chỉ trả khi gửi lời mời; tiền được giữ an toàn và hoàn 100% nếu bạn huỷ khi chưa có người nhận.';

  @override
  String get instantSeeMatches => 'Xem nhiếp ảnh gia phù hợp';

  @override
  String get instantLocationTitle => 'Bật vị trí để Chụp ngay';

  @override
  String get instantLocationBody =>
      'Nhiếp ảnh gia cần biết bạn đang ở đâu để tới đúng chỗ.';

  @override
  String get instantLocationAllow => 'Cho phép vị trí';

  @override
  String get instantBookNormally => 'Đặt lịch thường';

  @override
  String get instantOutsideArea =>
      'Chụp ngay chưa có ở khu vực này. Bạn có thể đặt lịch thường.';

  @override
  String get instantDisabled => 'Chụp ngay đang tạm dừng.';

  @override
  String get instantHasActive => 'Bạn đang có một yêu cầu chụp ngay.';

  @override
  String get chooseTitle => 'Chọn người bạn thích';

  @override
  String chooseSubtitle(String genre, String duration, String amount) {
    return '$genre · $duration · $amount';
  }

  @override
  String chooseCounter(int index, int total) {
    return '$index / $total';
  }

  @override
  String get chooseStamp => 'CHỌN';

  @override
  String chooseEta(int minutes) {
    return 'đến khoảng $minutes phút';
  }

  @override
  String get chooseLike => 'Chọn người này';

  @override
  String get chooseSkip => 'Bỏ qua';

  @override
  String get chooseUndo => 'Hoàn tác';

  @override
  String choosePicked(int n) {
    return 'Đã chọn $n người';
  }

  @override
  String get chooseDone => 'Xong';

  @override
  String get chooseSummaryTitle => 'Những người bạn đã chọn';

  @override
  String get chooseUnpick => 'Bỏ chọn';

  @override
  String chooseUnpickA11y(String name) {
    return 'Bỏ chọn $name';
  }

  @override
  String chooseUnavailable(String name) {
    return '$name vừa nhận việc khác';
  }

  @override
  String get chooseInvite => 'Gửi lời mời';

  @override
  String get chooseMore => 'Xem 5 người khác';

  @override
  String get chooseEscrow =>
      'Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.';

  @override
  String get chooseRoundEnded => 'Chưa ai nhận. Chọn thêm người nhé.';

  @override
  String get chooseEmptyTitle => 'Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn';

  @override
  String get chooseEmptyBody =>
      'Bạn chưa phải trả gì. Thử lại sau ít phút hoặc đặt lịch thường.';

  @override
  String get chooseEmptyRetry => 'Thử lại';

  @override
  String choosePriceChanged(String amount) {
    return 'Giá vừa đổi thành $amount. Kiểm tra lại trước khi thanh toán.';
  }

  @override
  String get doneHome => 'Về trang chủ';

  @override
  String get instantNotFoundTitle => 'Không tìm thấy yêu cầu';

  @override
  String get instantNotFoundBody =>
      'Yêu cầu này không còn hoặc không thuộc tài khoản của bạn.';

  @override
  String get trackingCancel => 'Huỷ';

  @override
  String get trackingSelf => 'Bạn';

  @override
  String trackingPin(String name, int minutes) {
    return '$name · $minutes phút';
  }

  @override
  String trackingEta(int minutes) {
    return 'đến trong khoảng $minutes phút';
  }

  @override
  String trackingEtaBold(int minutes) {
    return '$minutes phút';
  }

  @override
  String trackingNote(String name) {
    return 'Đối chiếu ảnh đại diện khi gặp. Vị trí của $name chỉ hiện trong lúc đang đến.';
  }

  @override
  String get trackingMessage => 'Nhắn tin';

  @override
  String trackingCancelFree(String time) {
    return 'Huỷ (miễn phí thêm $time)';
  }

  @override
  String get trackingCancelLate => 'Huỷ (hoàn 100%)';

  @override
  String get trackingStale => 'Đang chờ cập nhật vị trí';

  @override
  String trackingLate(String name) {
    return '$name đến trễ. Bạn có thể huỷ và được hoàn 100%.';
  }

  @override
  String trackingLateUnpaid(String name) {
    return '$name đến trễ. Bạn có thể huỷ yêu cầu.';
  }

  @override
  String get trackingArrived => 'Đã đến điểm hẹn';

  @override
  String trackingArrivedBody(String name, String place) {
    return '$name đang chờ bạn ở $place.';
  }

  @override
  String get shootingTitle => 'Đang chụp';

  @override
  String shootingCard(String name, String genre, String duration) {
    return '$name · $genre $duration';
  }

  @override
  String shootingMeta(String time, String place) {
    return 'Bắt đầu $time · $place';
  }

  @override
  String shootingStepDeliver(int photos) {
    return 'Hoàn thành và giao $photos ảnh trong 48 giờ';
  }

  @override
  String shootingNote(String name) {
    return 'Khi $name bấm Hoàn thành, bạn xác nhận ở đây. Không xác nhận thì tự hoàn thành sau 2 giờ; có vấn đề thì báo trong 24 giờ.';
  }

  @override
  String get shootingConfirm => 'Xác nhận hoàn thành';

  @override
  String get shootingFinishedTitle => 'Chờ bạn xác nhận';

  @override
  String shootingFinishedBody(String name, String time) {
    return '$name đã hoàn thành buổi chụp. Tự hoàn thành sau $time nếu bạn không xác nhận.';
  }

  @override
  String get doneTitle => 'Buổi chụp đã hoàn thành';

  @override
  String doneBody(String name, int photos) {
    return '$name sẽ giao $photos ảnh trong 48 giờ.';
  }

  @override
  String get cancelInstantTitle => 'Huỷ chụp ngay?';

  @override
  String get cancelRowFree =>
      'Đang chọn, đang chờ trả lời, chưa tìm được, hoặc 2 phút đầu sau khi có người nhận';

  @override
  String get cancelRowEnRoute => 'Nhiếp ảnh gia đang đến';

  @override
  String get cancelRowArrived => 'Đã đến, bạn không có mặt sau 15 phút';

  @override
  String cancelRowNow(String row) {
    return '$row (bây giờ)';
  }

  @override
  String cancelOutcome(int percent) {
    return 'Hoàn $percent%';
  }

  @override
  String cancelInstantRefundFee(String refund, String fee, String name) {
    return 'Bạn sẽ được hoàn $refund; $fee là phí đi lại trả cho $name.';
  }

  @override
  String cancelInstantRefundAll(String refund) {
    return 'Bạn sẽ được hoàn $refund.';
  }

  @override
  String cancelInstantLate(String name) {
    return '$name đến trễ hơn 15 phút nên bạn được hoàn đủ.';
  }

  @override
  String get cancelInstantUnpaid =>
      'Bạn chưa thanh toán nên không có khoản tiền nào.';

  @override
  String cancelInstantConfirm(String refund) {
    return 'Huỷ và hoàn $refund';
  }

  @override
  String get cancelInstantConfirmUnpaid => 'Huỷ yêu cầu';

  @override
  String get cancelInstantKeep => 'Giữ yêu cầu';

  @override
  String get cancelledTitle => 'Đã huỷ yêu cầu';

  @override
  String cancelledRefund(String amount, String method) {
    return 'Hoàn $amount về $method. Tiền thường về trong vài phút.';
  }

  @override
  String get cancelledNoMoney => 'Không có khoản tiền nào.';

  @override
  String get abandonedTitle => 'Yêu cầu đã hết hạn';

  @override
  String get abandonedBody =>
      'Bạn chưa gửi lời mời trong 30 phút nên yêu cầu đã đóng.';

  @override
  String get noShowTitle => 'Nhiếp ảnh gia báo bạn không có mặt';

  @override
  String noShowBody(String amount, int percent) {
    return 'Bạn được hoàn $amount ($percent%).';
  }

  @override
  String get closedNewRequest => 'Tạo yêu cầu mới';

  @override
  String get refundToBankQr => 'tài khoản đã chuyển';

  @override
  String get refundToMomo => 'MoMo';

  @override
  String get refundToZaloPay => 'ZaloPay';

  @override
  String get waitingTitle => 'Đang chờ trả lời';

  @override
  String waitingSent(int n) {
    return 'Đã gửi lời mời cho $n người';
  }

  @override
  String waitingBody(String time) {
    return 'Ai nhận trước sẽ tới chỗ bạn. Mỗi lời mời còn $time.';
  }

  @override
  String waitingRowEta(int minutes) {
    return 'khoảng $minutes phút';
  }

  @override
  String get waitingViewing => 'Đang xem';

  @override
  String get waitingDeclined => 'Đã từ chối';

  @override
  String get waitingExpired => 'Hết hạn';

  @override
  String get waitingNotCounted => 'Không tính';

  @override
  String get waitingRowUnavailable => 'vừa nhận việc khác';

  @override
  String waitingRowSemantics(String name) {
    return '$name đang xem lời mời';
  }

  @override
  String get waitingNote =>
      'Chưa ai nhận thì bạn chọn tiếp trong 5 người khác, không trả thêm. Tiền vẫn được giữ cho tới khi có người nhận hoặc bạn huỷ.';

  @override
  String get waitingNoteUnpaid =>
      'Chưa ai nhận thì bạn chọn tiếp trong 5 người khác.';

  @override
  String get waitingCancel => 'Huỷ yêu cầu';

  @override
  String get noMatchTitle => 'Chưa tìm được nhiếp ảnh gia';

  @override
  String noMatchBody(int invited, int rounds) {
    return 'Bạn đã mời $invited người trong $rounds lượt; gần bạn lúc này ít người đang sẵn sàng.';
  }

  @override
  String noMatchHeld(String amount, String method) {
    return '$amount vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ về $method.';
  }

  @override
  String get noMatchBookNormally => 'Đặt lịch thường với người bạn chọn';

  @override
  String noMatchCancel(String amount) {
    return 'Huỷ yêu cầu và hoàn $amount';
  }

  @override
  String get noMatchMore => 'Chọn thêm người';

  @override
  String get liveShutterTitle => 'Live Shutter';

  @override
  String get liveShutterBody =>
      'Nhận lời mời ở gần bạn. Vị trí được dùng khi bật.';

  @override
  String get liveShutterCardOn => 'Đang bật · nhận lời mời ở gần bạn';

  @override
  String get liveShutterCardOff => 'Đang tắt · bật để nhận việc chụp ngay';

  @override
  String liveShutterJobTitle(String name) {
    return 'Việc chụp ngay · $name';
  }

  @override
  String liveShutterJobMeta(String service, String place) {
    return '$service · $place';
  }

  @override
  String get helpReadyTitle => 'Sẵn sàng hỗ trợ';

  @override
  String get helpReadyBody => 'Được ưu tiên mời cả việc gấp, xa hơn một chút.';

  @override
  String get priceListTitle => 'Bảng giá gói';

  @override
  String priceListAccepted(int version) {
    return 'Bản $version · đã đồng ý';
  }

  @override
  String priceListNotAccepted(int version) {
    return 'Bản $version · chưa đồng ý';
  }

  @override
  String get priceListCustomerPays => 'Khách trả';

  @override
  String get priceListYouGet => 'Bạn nhận';

  @override
  String get priceListTermsNote =>
      'Giá do nền tảng đặt, giống nhau cho mọi nhiếp ảnh gia trong một lượt gợi ý. Đồng ý để bật Live Shutter.';

  @override
  String get priceListAccept => 'Đồng ý bảng giá';

  @override
  String get liveShutterNote =>
      'Không mở app trong 30 phút thì tạm ngừng nhận lời mời; mở lại app là nhận tiếp. Huỷ sau khi nhận làm giảm điểm tin cậy.';

  @override
  String get liveShutterOffToday => 'Tắt khi xong việc hôm nay';

  @override
  String get liveShutterLockedTitle => 'Chưa bật được Live Shutter';

  @override
  String get liveShutterReasonNotAccepting =>
      'Hoàn tất xác minh và hồ sơ để nhận đơn';

  @override
  String get liveShutterReasonPhone => 'Thêm số điện thoại';

  @override
  String get liveShutterReasonPriceList => 'Đồng ý bảng giá gói';

  @override
  String get liveShutterReasonOutside =>
      'Bạn đang ở ngoài khu vực có Chụp ngay';

  @override
  String get liveShutterReasonLocation =>
      'Cho phép dùng vị trí để nhận lời mời ở gần';

  @override
  String get liveShutterAddPhone => 'Thêm số';

  @override
  String get liveShutterOpenSettings => 'Mở cài đặt';

  @override
  String get offerTitle => 'Lời mời chụp ngay';

  @override
  String offerPendingCount(int n) {
    return '$n lời mời đang chờ';
  }

  @override
  String offerYouGet(String genre, String duration, int photos) {
    return 'Bạn nhận · $genre $duration · $photos ảnh';
  }

  @override
  String offerDistance(String distance, int minutes) {
    return '$distance · khoảng $minutes phút · địa chỉ hiện khi bạn nhận';
  }

  @override
  String offerChosenAmong(String n) {
    return 'Khách đã chọn bạn trong $n người. Ai nhận trước sẽ được việc.';
  }

  @override
  String offerNote(String note) {
    return '\"$note\"';
  }

  @override
  String get offerDecline => 'Từ chối';

  @override
  String get offerAccept => 'Nhận việc';

  @override
  String get offerAlreadyAssigned => 'Khách đã chọn được người khác';

  @override
  String get offerExpired => 'Lời mời đã hết hạn';

  @override
  String get offerNotAccepting => 'Bạn chưa nhận đơn được lúc này';

  @override
  String matchTitle(String name) {
    return 'Đã match với $name';
  }

  @override
  String matchBodyPhotographer(String name, String place) {
    return '$name đang chờ ở $place. Tiếp tục để xem đường đi.';
  }

  @override
  String matchBodyCustomer(String name, String place, int minutes) {
    return '$name đã nhận lời mời của bạn và đang chuẩn bị tới $place, khoảng $minutes phút.';
  }

  @override
  String matchBodyCustomerNoEta(String name, String place) {
    return '$name đã nhận lời mời của bạn và đang chuẩn bị tới $place.';
  }

  @override
  String get matchContinue => 'Tiếp tục';

  @override
  String get jobTitleEnRoute => 'Đang đến';

  @override
  String get jobTitleArrived => 'Đã đến';

  @override
  String get jobTitleShooting => 'Đang chụp';

  @override
  String get jobTitleFinished => 'Chờ khách xác nhận';

  @override
  String get jobTitleCompleted => 'Đã hoàn thành';

  @override
  String jobSubtitle(String name, String genre, String duration) {
    return '$name · $genre $duration';
  }

  @override
  String get jobDirections => 'Chỉ đường';

  @override
  String jobDistanceLine(String area, String km) {
    return '$area · $km km';
  }

  @override
  String jobMeetPointLine(String area) {
    return '$area · điểm hẹn';
  }

  @override
  String jobStepAccepted(String time) {
    return 'Đã nhận · $time';
  }

  @override
  String get jobStepArriveHint => 'Đã đến (bật khi còn cách 200 m)';

  @override
  String jobStepArrived(String time) {
    return 'Đã đến · $time';
  }

  @override
  String get jobStepShoot => 'Bắt đầu chụp · Hoàn thành';

  @override
  String get jobLocationNote =>
      'Vị trí của bạn chỉ chia sẻ với khách trong lúc đang đến. Tới nơi là dừng.';

  @override
  String get jobLocationNeeded =>
      'Cho phép dùng vị trí để chia sẻ đường đi với khách.';

  @override
  String get jobLocationAllow => 'Cho phép';

  @override
  String get jobArrive => 'Đã đến';

  @override
  String jobArriveFar(String distance) {
    return 'Còn cách $distance. Tới gần hơn để bấm Đã đến.';
  }

  @override
  String instantDistanceMetres(int metres) {
    return '$metres m';
  }

  @override
  String get jobArriveForceTitle => 'GPS chưa chính xác';

  @override
  String jobArriveForceBody(int meters) {
    return 'Vị trí đang lệch khoảng $meters m. Xác nhận bạn đã tới điểm hẹn?';
  }

  @override
  String get jobArriveForceConfirm => 'Xác nhận đã đến';

  @override
  String get jobArriveForceKeep => 'Chờ GPS';

  @override
  String get jobStart => 'Bắt đầu chụp';

  @override
  String get jobFinish => 'Hoàn thành';

  @override
  String get jobShootLeft => 'còn lại';

  @override
  String get jobShootNote =>
      'Hết giờ gói hoặc bấm Hoàn thành, khách sẽ xác nhận.';

  @override
  String jobStartedLine(String time, String place) {
    return 'Bắt đầu $time · $place';
  }

  @override
  String jobFinishedLine(String time, String place) {
    return 'Hoàn thành $time · $place';
  }

  @override
  String get jobWaitingBadge => 'Chờ khách';

  @override
  String get jobFinishedNote =>
      'Khách xác nhận hoặc tự hoàn thành sau 2 giờ. Tiền chuyển cho bạn 24 giờ sau khi hoàn thành.';

  @override
  String get jobBackToWork => 'Về Công việc';

  @override
  String get jobNoShow => 'Khách không có mặt';

  @override
  String jobNoShowIn(String time) {
    return 'Khách không có mặt (sau $time)';
  }

  @override
  String get jobNoShowTitle => 'Báo khách không có mặt?';

  @override
  String jobNoShowBody(String amount) {
    return 'Khách được hoàn 50%, bạn nhận $amount.';
  }

  @override
  String get jobNoShowConfirm => 'Báo khách không có mặt';

  @override
  String get jobNoShowKeep => 'Chờ thêm';

  @override
  String get jobCancel => 'Huỷ việc';

  @override
  String get jobCancelledTitle => 'Khách đã huỷ yêu cầu';

  @override
  String jobCancelledFee(String amount) {
    return 'Bạn nhận $amount phí đi lại.';
  }

  @override
  String get jobCancelledNoFee => 'Không cần tới điểm hẹn nữa.';

  @override
  String get providerCancelTitle => 'Huỷ việc chụp ngay?';

  @override
  String get providerCancelBody =>
      'Khách được hoàn 100%. Huỷ sau khi nhận làm giảm điểm tin cậy của bạn.';

  @override
  String get providerCancelConfirm => 'Huỷ việc';

  @override
  String get providerCancelKeep => 'Giữ việc';

  @override
  String get mapRecenter => 'Về vị trí của tôi';

  @override
  String get mapPinYou => 'Bạn';

  @override
  String mapSemantics(String pins) {
    return 'Bản đồ: $pins';
  }

  @override
  String get chatKindCollab => 'Cộng tác';

  @override
  String get recruitErrorGeneric => 'Chưa thực hiện được. Thử lại sau.';

  @override
  String get recruitErrorRateLimited =>
      'Bạn đã dùng hết lượt hôm nay. Thử lại ngày mai.';

  @override
  String get recruitErrorApplyLimit =>
      'Bạn đang có 10 ứng tuyển chờ trả lời. Chờ studio trả lời hoặc rút bớt.';

  @override
  String get recruitErrorPostLimit => 'Studio đã có 3 tin mở.';

  @override
  String get recruitErrorClosed => 'Tin đã đóng hoặc hết hạn.';

  @override
  String get recruitErrorDuplicate => 'Bạn đã ứng tuyển tin này.';

  @override
  String get collabErrorFull => 'Đã đủ số cộng tác cho phép.';

  @override
  String get collabErrorCooldown => 'Chưa mời lại được, chờ đủ 3 ngày.';

  @override
  String get collabErrorBusy => 'Còn việc được giao chưa xong.';

  @override
  String get collabErrorConflict =>
      'Thợ này đang là thành viên của studio bạn.';

  @override
  String get collabErrorDayTaken => 'Bạn đã có lịch trong ngày này.';

  @override
  String get collabPayDue => 'Cần trả';

  @override
  String get collabPayDisputed => 'Chưa nhận';

  @override
  String get collabPayReported => 'Đã báo trả';

  @override
  String get collabPayReceived => 'Đã nhận';

  @override
  String get collabMethodBank => 'Chuyển khoản';

  @override
  String get collabMethodCash => 'Tiền mặt';

  @override
  String get collabMethodOther => 'Khác';

  @override
  String get collabCsvHeader =>
      'Ngày chụp,Dịch vụ,Cộng tác viên,Thù lao,Trạng thái,Ngày trả,Cách trả';

  @override
  String get recruitTab => 'Tuyển thợ';

  @override
  String get recruitTitle => 'Tuyển thợ';

  @override
  String get recruitStudioPostsTooltip => 'Tin tuyển của studio';

  @override
  String get recruitFilterArea => 'Khu vực';

  @override
  String get recruitFilterSpecialty => 'Thể loại';

  @override
  String get recruitFilterAll => 'Tất cả';

  @override
  String get recruitKindCollaborator => 'Cộng tác theo việc';

  @override
  String get recruitKindMember => 'Vào studio';

  @override
  String get recruitMatch => 'Hợp với bạn';

  @override
  String recruitFeePerShoot(String amount) {
    return '$amount/buổi';
  }

  @override
  String get recruitFeeNegotiable => 'Thoả thuận';

  @override
  String get recruitFrequencyOccasional => 'Vài buổi/tháng';

  @override
  String get recruitFrequencyWeekly => 'Hằng tuần';

  @override
  String get recruitFrequencySeasonal => 'Theo mùa';

  @override
  String get recruitFrequencyOccasionalLong => 'Vài buổi mỗi tháng';

  @override
  String get recruitFrequencyWeeklyLong => 'Hằng tuần';

  @override
  String get recruitFrequencySeasonalLong => 'Theo mùa (cưới, Tết…)';

  @override
  String recruitCardFooter(String frequency, String ago) {
    return '$frequency · $ago';
  }

  @override
  String get recruitAgoYesterday => 'hôm qua';

  @override
  String recruitAgoWeeks(int n) {
    return '$n tuần trước';
  }

  @override
  String get recruitOnlyProvidersNote => 'Chỉ thợ ảnh và studio thấy mục này.';

  @override
  String get recruitEmpty => 'Chưa có tin tuyển nào hợp bộ lọc.';

  @override
  String get recruitLoadMore => 'Xem thêm';

  @override
  String get recruitSpecialtiesLabel => 'Thể loại';

  @override
  String get recruitAreasLabel => 'Khu vực làm việc';

  @override
  String get recruitFrequencyLabel => 'Tần suất';

  @override
  String get recruitFeeLabel =>
      'Thù lao tham khảo · studio trả trực tiếp cho bạn, ngoài ứng dụng';

  @override
  String get recruitRequirements => 'Yêu cầu';

  @override
  String recruitStats(int count, int days) {
    return '$count người đã ứng tuyển · còn $days ngày';
  }

  @override
  String recruitStudioShoots(int n) {
    return '$n buổi chụp';
  }

  @override
  String get recruitViewStudio => 'Xem studio';

  @override
  String get recruitApply => 'Ứng tuyển';

  @override
  String get recruitVerifyToApply => 'Xác minh để ứng tuyển';

  @override
  String get recruitVerifyNote =>
      'Bạn cần xác minh danh tính trước khi ứng tuyển.';

  @override
  String get recruitApplied => 'Đã ứng tuyển · chờ studio';

  @override
  String get recruitWithdraw => 'Rút ứng tuyển';

  @override
  String get recruitWithdrawConfirmTitle => 'Rút ứng tuyển?';

  @override
  String get recruitWithdrawConfirmBody =>
      'Mỗi tin chỉ ứng tuyển một lần, rút rồi không gửi lại được.';

  @override
  String get recruitWithdrawKeep => 'Giữ lại';

  @override
  String recruitAlreadyMember(String studio) {
    return 'Bạn đang là thành viên của $studio.';
  }

  @override
  String get recruitStudioViewerNote =>
      'Studio xem được tin nhưng không ứng tuyển.';

  @override
  String get recruitClosedNote => 'Tin đã đóng hoặc hết hạn.';

  @override
  String get recruitResultAccepted => 'Studio đã nhận bạn';

  @override
  String get recruitResultDeclined => 'Studio chưa nhận ứng tuyển này';

  @override
  String get recruitApplyTitle => 'Ứng tuyển';

  @override
  String recruitApplySubtitle(String title, String studio) {
    return '$title · $studio';
  }

  @override
  String get recruitSheetClose => 'Đóng';

  @override
  String get recruitMessageLabel => 'Lời nhắn cho studio';

  @override
  String get recruitMessageHint =>
      'Giới thiệu ngắn về kinh nghiệm và thiết bị của bạn';

  @override
  String get recruitSamplesLabel => 'Ảnh tiêu biểu';

  @override
  String get recruitSamplesHint => 'Chọn tối đa 3 bài từ portfolio';

  @override
  String recruitSamplesCount(int n) {
    return '$n/3';
  }

  @override
  String get recruitSamplesEmpty => 'Chưa có bài nào trong portfolio.';

  @override
  String get collabTermsTitle => 'Điều khoản cộng tác';

  @override
  String get collabTerm1 =>
      'Hợp đồng dịch vụ theo từng buổi chụp: bạn tự quyết cách làm, không có giờ làm cố định, không độc quyền.';

  @override
  String get collabTerm2 =>
      'Thù lao do hai bên thoả thuận từng việc. Studio trả trực tiếp cho bạn ngoài ứng dụng; ứng dụng không bảo lãnh khoản này.';

  @override
  String get collabTerm3 =>
      'Bạn không chào trực tiếp khách mà studio giao cho bạn trong 6 tháng.';

  @override
  String get collabTermsAgree => 'Tôi đồng ý điều khoản cộng tác';

  @override
  String get recruitNoContactNote =>
      'Không ghi số điện thoại, Zalo hay link trong lời nhắn.';

  @override
  String recruitMemberNote(String studio) {
    return 'Được nhận thì bạn vào $studio như thành viên (mỗi thợ ở một studio).';
  }

  @override
  String get recruitSend => 'Gửi ứng tuyển';

  @override
  String get recruitSentToast => 'Đã gửi ứng tuyển';

  @override
  String get recruitContactError =>
      'Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung';

  @override
  String get recruitMessageInvalid => 'Lời nhắn tối đa 400 ký tự.';

  @override
  String get recruitSamplesInvalid =>
      'Chỉ chọn tối đa 3 bài trong portfolio của bạn.';

  @override
  String get recruitNewTitle => 'Đăng tin tuyển';

  @override
  String get recruitEditTitle => 'Sửa tin tuyển';

  @override
  String recruitOpenSlots(int left) {
    return 'Còn $left/3 tin mở';
  }

  @override
  String get recruitKindLabel => 'Loại tin';

  @override
  String get recruitKindCollaboratorHint =>
      'Thợ làm từng buổi, không vào studio';

  @override
  String get recruitKindMemberLabel => 'Thành viên studio';

  @override
  String get recruitKindMemberHint => 'Thợ vào studio của bạn';

  @override
  String get recruitTitleLabel => 'Tiêu đề';

  @override
  String get recruitSpecialtiesPick => 'Thể loại (tối đa 4)';

  @override
  String get recruitAreasPick => 'Khu vực (tối đa 5)';

  @override
  String get recruitFeePick => 'Thù lao tham khảo';

  @override
  String get recruitFeeKindPerShoot => 'Theo buổi';

  @override
  String get recruitFeeKindNegotiable => 'Thoả thuận';

  @override
  String get recruitFeeAmountHint => 'Số tiền mỗi buổi';

  @override
  String get recruitFeeAmountSuffix => '₫ / buổi';

  @override
  String get recruitRequirementsHint => 'Thiết bị, kinh nghiệm, cách làm việc';

  @override
  String get recruitFormNote =>
      'Không ghi số điện thoại, Zalo hay link. Tin hiện 30 ngày, chỉ thợ ảnh và studio thấy.';

  @override
  String get recruitPublish => 'Đăng tin';

  @override
  String get recruitSave => 'Lưu thay đổi';

  @override
  String get recruitPostedToast => 'Đã đăng tin';

  @override
  String get recruitSavedToast => 'Đã lưu thay đổi';

  @override
  String get recruitTitleError => 'Tiêu đề 8–80 ký tự';

  @override
  String get recruitSpecialtiesError => 'Chọn 1–4 thể loại';

  @override
  String get recruitAreasError => 'Chọn 1–5 khu vực';

  @override
  String get recruitFeeError => 'Nhập số tiền mỗi buổi';

  @override
  String get recruitRequirementsError => 'Yêu cầu tối đa 600 ký tự';

  @override
  String get recruitVerifyToPostNote =>
      'Studio cần xác minh trước khi đăng tin.';

  @override
  String get recruitStudioTitle => 'Tin tuyển của studio';

  @override
  String recruitStudioMeta(int open, int left) {
    return '$open/3 tin mở · còn $left lượt đăng/đóng hôm nay';
  }

  @override
  String get recruitStatusOpen => 'Đang mở';

  @override
  String get recruitStatusClosed => 'Đã đóng';

  @override
  String get recruitStatusExpired => 'Hết hạn';

  @override
  String recruitPostMeta(int count, int days) {
    return '$count ứng viên · còn $days ngày';
  }

  @override
  String recruitPostMetaEnded(int count) {
    return '$count ứng viên';
  }

  @override
  String get recruitEdit => 'Sửa';

  @override
  String get recruitRenew => 'Gia hạn 30 ngày';

  @override
  String recruitRenewedToast(String date) {
    return 'Đã gia hạn tới $date';
  }

  @override
  String get recruitClose => 'Đóng tin';

  @override
  String get recruitCloseConfirmTitle => 'Đóng tin này?';

  @override
  String get recruitCloseConfirmBody =>
      'Ứng viên đang chờ được báo là chưa được nhận.';

  @override
  String get recruitCloseKeep => 'Giữ tin';

  @override
  String recruitApplicantsHeader(String title) {
    return 'Ứng viên · $title';
  }

  @override
  String recruitApplicantsPending(int n) {
    return '$n chờ trả lời';
  }

  @override
  String get recruitAccept => 'Nhận';

  @override
  String get recruitDecline => 'Từ chối';

  @override
  String recruitAcceptedToast(String name) {
    return 'Đã nhận $name';
  }

  @override
  String recruitDeclineConfirmTitle(String name) {
    return 'Từ chối $name?';
  }

  @override
  String recruitDeclineConfirmBody(String name) {
    return '$name được báo là studio chưa nhận ứng tuyển này.';
  }

  @override
  String get recruitDeclineKeep => 'Quay lại';

  @override
  String get recruitNewPost => 'Đăng tin mới';

  @override
  String get recruitFull => 'Đã đủ 3 tin mở';

  @override
  String get recruitVerifyToPost => 'Xác minh để đăng tin';

  @override
  String recruitBlocked(String date) {
    return 'Bạn tạm không đăng tin và mời cộng tác viên tới $date vì chưa trả thù lao cho cộng tác viên.';
  }

  @override
  String get recruitNoApplicants => 'Chưa có ai ứng tuyển.';

  @override
  String get recruitNoPosts =>
      'Chưa có tin tuyển. Đăng tin để thợ ảnh khu vực của bạn thấy.';

  @override
  String recruitAcceptConflict(String name) {
    return '$name đang ở studio khác hoặc đang cộng tác với studio bạn.';
  }

  @override
  String recruitAcceptCooldown(String name) {
    return '$name mới rời studio, chưa vào được studio mới.';
  }

  @override
  String get recruitAcceptStudioFull => 'Studio đã đủ thành viên.';

  @override
  String get recruitAcceptCollabFull => 'Đã đủ số cộng tác viên.';

  @override
  String recruitAcceptNotAccepting(String name) {
    return '$name hiện chưa nhận đơn được.';
  }

  @override
  String profileRecruiting(int n) {
    return 'Đang tuyển · $n tin';
  }

  @override
  String get collabTitle => 'Cộng tác';

  @override
  String collabStudioMeta(int active, int max, int left) {
    return '$active/$max cộng tác viên · còn $left thao tác hôm nay';
  }

  @override
  String collabRowMeta(int jobs, String fee) {
    return '$jobs việc đang giao · gợi ý $fee/buổi';
  }

  @override
  String collabRowMetaNoFee(int jobs) {
    return '$jobs việc đang giao';
  }

  @override
  String collabRowOptions(String name) {
    return 'Tuỳ chọn cho $name';
  }

  @override
  String get collabMenuMessage => 'Nhắn tin';

  @override
  String get collabMenuFee => 'Sửa thù lao gợi ý';

  @override
  String get collabMenuEnd => 'Kết thúc cộng tác';

  @override
  String collabEndConfirmTitle(String name) {
    return 'Kết thúc cộng tác với $name?';
  }

  @override
  String get collabEndConfirmBody => 'Mời lại được sau 3 ngày.';

  @override
  String collabEndBusy(int n) {
    return 'Còn $n việc được giao chưa xong.';
  }

  @override
  String get collabKeep => 'Quay lại';

  @override
  String get collabPayDueHeader => 'Thù lao cần trả';

  @override
  String get collabMarkPaid => 'Đã trả';

  @override
  String get collabPendingHeader => 'Đang chờ';

  @override
  String collabInviteSent(int days) {
    return 'Lời mời đã gửi · hết hạn sau $days ngày';
  }

  @override
  String get collabCancelInvite => 'Huỷ';

  @override
  String get collabTaxNote =>
      'Khoản từ 5.000.000đ/lần có thể phải khấu trừ thuế TNCN 10%; hãy hỏi kế toán.';

  @override
  String get collabTaxDismiss => 'Ẩn lưu ý thuế';

  @override
  String collabExportCsv(int month) {
    return 'Sao chép bảng kê tháng $month (CSV)';
  }

  @override
  String collabExportDone(int month) {
    return 'Đã sao chép bảng kê tháng $month. Dán vào bảng tính để xem.';
  }

  @override
  String collabExportEmpty(int month) {
    return 'Tháng $month chưa có khoản thù lao nào.';
  }

  @override
  String get collabInvite => 'Mời cộng tác viên';

  @override
  String get collabStudioEmpty =>
      'Chưa có cộng tác viên. Mời thợ hoặc đăng tin tuyển ở Tin tuyển.';

  @override
  String get collabPaidSheetTitle => 'Đã trả thù lao';

  @override
  String get collabPaidDate => 'Ngày trả';

  @override
  String get collabPaidToday => 'Hôm nay';

  @override
  String get collabPaidYesterday => 'Hôm qua';

  @override
  String get collabPaidOtherDay => 'Ngày khác';

  @override
  String get collabPaidMethod => 'Cách trả';

  @override
  String get collabPaidConfirm => 'Xác nhận đã trả';

  @override
  String get collabFeeSheetTitle => 'Thù lao gợi ý';

  @override
  String collabFeeHint(String name) {
    return 'Gợi ý sẵn khi giao việc cho $name';
  }

  @override
  String get collabFeeInvalid =>
      'Từ 1.000₫ tới 100.000.000₫, bội số của 1.000₫';

  @override
  String get collabFeeSave => 'Lưu';

  @override
  String get collabFeeSaved => 'Đã lưu thù lao gợi ý';

  @override
  String get collabInviteSearch => 'Tìm thợ theo tên';

  @override
  String get collabInviteRowMember => 'Thành viên của studio bạn';

  @override
  String get collabInviteRowActive => 'Đang cộng tác';

  @override
  String get collabInviteRowUnverified => 'Chưa xác minh';

  @override
  String collabInviteRowCooldown(String date) {
    return 'Mời lại được từ $date';
  }

  @override
  String get collabInviteFooter =>
      'Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ';

  @override
  String get collabInviteAction => 'Mời';

  @override
  String get collabOffersHeader => 'Việc chờ nhận';

  @override
  String collabOfferLeft(String time) {
    return 'Còn $time';
  }

  @override
  String collabLeftHoursMinutes(int h, int m) {
    return '$h giờ $m phút';
  }

  @override
  String get collabStudiosHeader => 'Studio cộng tác';

  @override
  String collabStudiosCount(int n) {
    return '$n / tối đa 5';
  }

  @override
  String collabStudioRowMeta(String month, int jobs) {
    return 'Từ $month · $jobs việc đang giao';
  }

  @override
  String get collabInvitesHeader => 'Lời mời';

  @override
  String collabInviteRowMeta(int days) {
    return 'Mời cộng tác · hết hạn sau $days ngày';
  }

  @override
  String get collabAcceptInvite => 'Xem & nhận';

  @override
  String get collabDeclineInvite => 'Từ chối';

  @override
  String collabAcceptSheetTitle(String studio) {
    return 'Cộng tác với $studio';
  }

  @override
  String get collabAcceptSheetConfirm => 'Nhận lời cộng tác';

  @override
  String collabAcceptedToast(String studio) {
    return 'Đã nhận lời cộng tác với $studio';
  }

  @override
  String collabInviteDeclinedToast(String studio) {
    return 'Đã từ chối lời mời của $studio';
  }

  @override
  String get collabPayHeader => 'Thù lao';

  @override
  String collabPayReportedMeta(String date, String method) {
    return 'Studio báo đã trả $date ($method)';
  }

  @override
  String get collabConfirmReceived => 'Đã nhận';

  @override
  String get collabReportNotReceived => 'Chưa nhận';

  @override
  String get collabNotReceivedConfirmTitle => 'Báo chưa nhận thù lao?';

  @override
  String get collabNotReceivedConfirmBody =>
      'Studio và bộ phận hỗ trợ được báo. Ứng dụng không bảo lãnh khoản này.';

  @override
  String get collabEmpty =>
      'Chưa có studio cộng tác. Xem tin ở Công việc → Tuyển thợ.';

  @override
  String get collabOfferTitle => 'Nhận việc cộng tác';

  @override
  String get collabOfferStudioNote =>
      'Studio chịu trách nhiệm với khách và lo bàn giao ảnh';

  @override
  String get collabOfferFeeNote =>
      'Thù lao · studio trả trực tiếp cho bạn sau buổi chụp';

  @override
  String collabOfferDeadline(String time, String left) {
    return 'Trả lời trước $time (còn $left)';
  }

  @override
  String collabOfferTimeToday(String time) {
    return '$time hôm nay';
  }

  @override
  String get collabOfferDeadlineNote => 'Không trả lời coi như từ chối';

  @override
  String get collabOfferLockNote =>
      'Nhận việc thì khung giờ này bị khoá trên lịch của bạn và bạn vào hội thoại với khách.';

  @override
  String get collabOfferAccept => 'Nhận việc';

  @override
  String get collabOfferDecline => 'Từ chối';

  @override
  String get collabOfferAcceptedToast => 'Đã nhận việc';

  @override
  String get collabOfferDeclinedToast => 'Đã từ chối, studio được báo';

  @override
  String get collabOfferExpired => 'Việc này đã hết hạn trả lời';

  @override
  String get collabOfferGone => 'Việc này không còn chờ bạn nhận.';

  @override
  String get assignGroupMembers => 'Thành viên';

  @override
  String get assignGroupCollaborators => 'Cộng tác viên';

  @override
  String get assignFeeLabel => 'Thù lao';

  @override
  String get assignFeeRequired => 'Nhập thù lao cho cộng tác viên';

  @override
  String assignCollabNote(String name) {
    return '$name có 6 giờ để nhận việc; khách chỉ thấy thợ khi $name đã nhận.';
  }

  @override
  String assignSendTo(String name) {
    return 'Gửi việc cho $name';
  }

  @override
  String assignOfferPending(String name, String left) {
    return 'Chờ $name nhận · còn $left';
  }

  @override
  String assignOfferDeclined(String name, String deadline) {
    return '$name đã từ chối. Giao người khác trước $deadline.';
  }

  @override
  String assigneeCollabLabel(String studio) {
    return 'Cộng tác với $studio';
  }

  @override
  String workCollabLabel(String studio) {
    return 'Cộng tác · $studio';
  }

  @override
  String get settingsCollab => 'Cộng tác';

  @override
  String settingsCollabProviderMeta(int studios, int offers) {
    return '$studios studio · $offers việc chờ nhận';
  }

  @override
  String settingsCollabStudioMeta(int n) {
    return '$n cộng tác viên';
  }

  @override
  String get settingsRecruit => 'Tin tuyển';

  @override
  String settingsRecruitMeta(int n) {
    return '$n/3 tin mở';
  }
}
