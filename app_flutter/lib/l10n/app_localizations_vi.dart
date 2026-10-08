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
  String get setupIntroHeading => 'Giới thiệu bản thân';

  @override
  String get setupIntroHint =>
      'Khách đọc phần này trước khi đặt lịch. Viết ngắn, nói rõ bạn chụp kiểu gì.';

  @override
  String get setupBioLabel => 'Giới thiệu ngắn';

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
  String get packageDeliveryLabel => 'Giao sau (ngày)';

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
  String get findFallbackNote => 'Đang xếp theo sao và khoảng cách';

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
  String get profileStatNoReviews => 'đánh giá';

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
  String get fakePayConfirm => 'Thanh toán thành công';

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
  String reviewsHeader(String rating, int count) {
    return '$rating · $count đánh giá';
  }

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
  String s2501Listed(int n) {
    return 'Đã khai · $n giải';
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
      'Tiền khách trả được giữ an toàn trên ứng dụng và chuyển cho bạn sau khi buổi chụp hoàn thành.';

  @override
  String get earningsHeld => 'Đang giữ';

  @override
  String get earningsSoon => 'Sắp nhận';

  @override
  String get earningsReceived => 'Đã nhận';

  @override
  String get earningsStateHeld => 'Đang giữ';

  @override
  String get earningsStateReleased => 'Chờ chi trả';

  @override
  String earningsStatePaid(String date) {
    return 'Đã chuyển $date';
  }

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
  String get payoutAccountTitle => 'Tài khoản nhận tiền';

  @override
  String get profileEarnings => 'Thu nhập';

  @override
  String get profileEarningsSub => 'Tiền đang giữ, sắp nhận và đã nhận';

  @override
  String get payoutAccountIntro =>
      'Chúng tôi chuyển tiền sau mỗi buổi chụp hoàn thành vào tài khoản này.';

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
  String get payoutAccountHolder => 'Tên chủ tài khoản';

  @override
  String get payoutAccountSave => 'Lưu tài khoản';

  @override
  String get payoutAccountHint =>
      'Tên chủ tài khoản phải trùng tên bạn đã xác minh. Số tài khoản được mã hoá và chỉ hiện 4 số cuối.';

  @override
  String payoutAccountMasked(String last4) {
    return '•••• $last4';
  }

  @override
  String get payoutAccountChange => 'Đổi tài khoản';

  @override
  String get payoutAccountNumberError => 'Số tài khoản gồm 6–20 chữ số';

  @override
  String get payoutAccountHolderError =>
      'Nhập họ tên viết hoa không dấu, 2–50 chữ cái';

  @override
  String get payoutAccountChangeTitle => 'Đổi tài khoản nhận tiền?';

  @override
  String get payoutAccountChangeBody =>
      'Các khoản chưa chuyển sẽ chuyển vào tài khoản mới. Khoản đã chuyển không thay đổi.';

  @override
  String get payoutAccountChangeConfirm => 'Đổi tài khoản';

  @override
  String get payoutAccountReauthTitle => 'Xác nhận lại để đổi tài khoản';

  @override
  String get payoutAccountReauthBody =>
      'Vì an toàn, hãy đăng nhập lại trước khi đổi tài khoản nhận tiền.';

  @override
  String get payoutAccountReauthPassword => 'Mật khẩu';

  @override
  String get payoutAccountReauthGo => 'Xác nhận';

  @override
  String get payoutAccountReauthWrong => 'Mật khẩu chưa đúng';

  @override
  String get payoutAccountSaved => 'Đã lưu tài khoản nhận tiền';

  @override
  String get payoutAccountSaveError => 'Không lưu được. Thử lại';

  @override
  String get payoutAccountBusy =>
      'Đang chuyển một lô tiền, thử lại sau ít phút';

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
  String get timelineReportSoon => 'Sắp có';

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
  String registerHold(String time) {
    return 'Giữ chỗ còn $time';
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
  String get fakeTicketPayTitle => 'Thanh toán thử';

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
  String get ticketPayFailed =>
      'Chưa thanh toán được. Kiểm tra mạng rồi thử lại.';

  @override
  String get ticketPayFakeDisabled =>
      'Thanh toán thử chỉ dùng được trên bản thử nghiệm.';

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
  String get bookNotAcceptingOrders => 'Nhiếp ảnh gia này chưa nhận đặt lịch.';
}
