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
  String get emptyHomeTitle => 'Ảnh đẹp sẽ xuất hiện ở đây';

  @override
  String get emptyHomeBody => 'Theo dõi nhiếp ảnh gia bạn thích để bắt đầu.';

  @override
  String get emptyExploreTitle => 'Khám phá theo dịch vụ và địa điểm';

  @override
  String get emptyExploreBody =>
      'Chân dung, cưới, gia đình, kỷ yếu và hơn thế.';

  @override
  String get emptyFindTitle => 'Tìm nhiếp ảnh gia rảnh đúng ngày bạn cần';

  @override
  String get emptyFindBody => 'Chọn địa điểm, ngày và dịch vụ để so sánh.';

  @override
  String get emptyCreateTitle => 'Cho mọi người thấy bạn chụp gì';

  @override
  String get emptyCreateBody =>
      'Mỗi bài đăng gắn một gói dịch vụ để khách đặt ngay.';

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
  String get phoneRequired => 'Nhập số điện thoại';

  @override
  String get phoneCodeSemantics => 'Mã +84';

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
  String get addPhoneSave => 'Lưu và tiếp tục';

  @override
  String get phoneSaveError => 'Không lưu được số điện thoại. Thử lại nhé.';

  @override
  String get contactLabel => 'Liên hệ';

  @override
  String get contactCall => 'Gọi điện';

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
  String get setupChannelCallHint => 'Dùng số điện thoại ở trên';

  @override
  String get setupChannelZalo => 'Zalo';

  @override
  String get setupChannelZaloHint => 'Dùng số ở trên hoặc nhập số riêng';

  @override
  String get setupZaloOwn => 'Số Zalo riêng (để trống nếu dùng số trên)';

  @override
  String get setupChannelWhatsApp => 'WhatsApp';

  @override
  String get setupChannelWhatsAppHint =>
      'Nhập số quốc tế riêng, hoặc dùng số ở trên';

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
}
