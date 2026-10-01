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
}
