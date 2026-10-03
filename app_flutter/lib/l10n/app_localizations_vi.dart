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
      'Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.';

  @override
  String get editProfilePhoneHint =>
      'Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.';

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
  String get createPortfolio => 'Thêm vào portfolio';

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
  String reasonTopRated(String rating, int count) {
    return '★ $rating · $count đánh giá';
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
  String get findRatingTitle => 'Đánh giá tối thiểu';

  @override
  String get findRatingAny => 'Mọi đánh giá';

  @override
  String findRatingMin(String rating) {
    return '★ $rating+';
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
  String get escrowNoticeDeposit =>
      'Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành.';

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
  String get bookDepositToday => 'Đặt cọc hôm nay (30%)';

  @override
  String get bookRemaining => 'Còn lại trả tại buổi chụp';

  @override
  String get bookPolicy =>
      'Huỷ trước 48 giờ hoàn cọc 100%. Nhiếp ảnh gia phải nhận trong 24 giờ, nếu không tự hoàn cọc.';

  @override
  String bookPay(String amount) {
    return 'Đặt cọc $amount';
  }

  @override
  String get payTitle => 'Thanh toán';

  @override
  String get payPendingTitle => 'Đang chờ xác nhận thanh toán';

  @override
  String payPendingBody(String provider) {
    return '$provider chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ.';
  }

  @override
  String get payProviderFake => 'Cổng thử nghiệm';

  @override
  String payProviderNamed(String name) {
    return 'Cổng $name';
  }

  @override
  String get payProviderGeneric => 'Cổng thanh toán';

  @override
  String get payAwaitingDeposit => 'Chờ cọc';

  @override
  String get payCheckAgain => 'Kiểm tra lại';

  @override
  String get payNotYet => 'Chưa nhận được xác nhận, thử lại sau ít phút';

  @override
  String get payChangeProvider => 'Đổi cổng thanh toán';

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
    return 'Cọc $amount đang được giữ an toàn';
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
      'Chưa nhận được tiền cọc trong 30 phút nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.';

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
  String get fakePayTitle => 'Cổng thanh toán giả (chỉ để thử)';

  @override
  String get fakePayBody => 'Bản dùng thử: không có tiền thật nào được trừ.';

  @override
  String get fakePayConfirm => 'Thanh toán thành công';

  @override
  String get actionCancel => 'Huỷ';

  @override
  String get actionRetry => 'Thử lại';

  @override
  String get timelineSent => 'Đã gửi & đặt cọc';

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
  String get timelineExpired => 'Hết hạn, đã hoàn cọc';

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
  String detailPaidToast(String amount, String name) {
    return 'Cọc $amount đang được giữ an toàn. $name sẽ trả lời trong 24 giờ.';
  }

  @override
  String escrowNoticeHeldPhotographer(String amount) {
    return 'Cọc $amount đang được giữ, chuyển cho bạn sau khi hoàn thành';
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
    return 'Huỷ yêu cầu · hoàn cọc $pct%';
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
    return '$name được hoàn cọc 100%';
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
    return 'Đã huỷ. $name được hoàn cọc 100%';
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
      'Yêu cầu đã đặt cọc, đang chờ nhiếp ảnh gia nhận sẽ hiện ở đây.';

  @override
  String get bookingsEmptyDone => 'Chưa có buổi nào xong';

  @override
  String get bookingsEmptyDoneBody =>
      'Buổi chụp đã hoàn thành, đã huỷ hoặc bị từ chối sẽ hiện ở đây.';
}
