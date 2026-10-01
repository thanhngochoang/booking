import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('vi')];

  /// No description provided for @appName.
  ///
  /// In vi, this message translates to:
  /// **'Cộng đồng nhiếp ảnh gia'**
  String get appName;

  /// No description provided for @tabBadgeCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} mục mới'**
  String tabBadgeCount(int count);

  /// No description provided for @tabHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get tabHome;

  /// No description provided for @tabExplore.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get tabExplore;

  /// No description provided for @tabFind.
  ///
  /// In vi, this message translates to:
  /// **'Tìm thợ ảnh'**
  String get tabFind;

  /// No description provided for @tabCreate.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài'**
  String get tabCreate;

  /// No description provided for @tabBookings.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get tabBookings;

  /// No description provided for @tabWork.
  ///
  /// In vi, this message translates to:
  /// **'Công việc'**
  String get tabWork;

  /// No description provided for @tabProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get tabProfile;

  /// No description provided for @loginTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get registerTitle;

  /// No description provided for @emailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get passwordLabel;

  /// No description provided for @passwordConfirmLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhập lại mật khẩu'**
  String get passwordConfirmLabel;

  /// No description provided for @displayNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get displayNameLabel;

  /// No description provided for @loginButton.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get loginButton;

  /// No description provided for @loginHeadlineLead.
  ///
  /// In vi, this message translates to:
  /// **'Bắt trọn'**
  String get loginHeadlineLead;

  /// No description provided for @loginHeadlineAccent.
  ///
  /// In vi, this message translates to:
  /// **'mọi khoảnh khắc'**
  String get loginHeadlineAccent;

  /// No description provided for @loginTagline.
  ///
  /// In vi, this message translates to:
  /// **'Tìm thợ ảnh hợp gu, đặt lịch chỉ vài chạm.'**
  String get loginTagline;

  /// No description provided for @loginWelcome.
  ///
  /// In vi, this message translates to:
  /// **'Chào bạn!'**
  String get loginWelcome;

  /// No description provided for @loginWelcomeBody.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tiếp tục'**
  String get loginWelcomeBody;

  /// No description provided for @socialGoogle.
  ///
  /// In vi, this message translates to:
  /// **'Google'**
  String get socialGoogle;

  /// No description provided for @socialFacebook.
  ///
  /// In vi, this message translates to:
  /// **'Facebook'**
  String get socialFacebook;

  /// No description provided for @loginOrDivider.
  ///
  /// In vi, this message translates to:
  /// **'hoặc'**
  String get loginOrDivider;

  /// No description provided for @noAccountPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản?'**
  String get noAccountPrompt;

  /// No description provided for @registerLink.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get registerLink;

  /// No description provided for @showPassword.
  ///
  /// In vi, this message translates to:
  /// **'Hiện mật khẩu'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn mật khẩu'**
  String get hidePassword;

  /// No description provided for @registerButton.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get registerButton;

  /// No description provided for @continueWithGoogle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục với Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithFacebook.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục với Facebook'**
  String get continueWithFacebook;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản?'**
  String get haveAccountPrompt;

  /// No description provided for @registerHeadlineLead.
  ///
  /// In vi, this message translates to:
  /// **'Tham gia'**
  String get registerHeadlineLead;

  /// No description provided for @registerHeadlineAccent.
  ///
  /// In vi, this message translates to:
  /// **'cộng đồng ảnh'**
  String get registerHeadlineAccent;

  /// No description provided for @registerTagline.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối thợ ảnh, lưu giữ khoảnh khắc.'**
  String get registerTagline;

  /// No description provided for @registerWelcomeBody.
  ///
  /// In vi, this message translates to:
  /// **'Điền vài thông tin để bắt đầu'**
  String get registerWelcomeBody;

  /// No description provided for @signOut.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get signOut;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ.'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordShort.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu cần ít nhất 8 ký tự.'**
  String get errorPasswordShort;

  /// No description provided for @errorPasswordMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu nhập lại không khớp.'**
  String get errorPasswordMismatch;

  /// No description provided for @errorNameEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên hiển thị.'**
  String get errorNameEmpty;

  /// No description provided for @authErrorWrongPassword.
  ///
  /// In vi, this message translates to:
  /// **'Email hoặc mật khẩu không đúng.'**
  String get authErrorWrongPassword;

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy tài khoản với email này.'**
  String get authErrorUserNotFound;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In vi, this message translates to:
  /// **'Email này đã được dùng. Hãy đăng nhập.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu quá yếu. Dùng ít nhất 8 ký tự.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối. Kiểm tra mạng rồi thử lại.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập không thành công. Thử lại sau.'**
  String get authErrorUnknown;

  /// No description provided for @roleTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn làm gì?'**
  String get roleTitle;

  /// No description provided for @roleCustomerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thuê nhiếp ảnh gia'**
  String get roleCustomerTitle;

  /// No description provided for @roleCustomerBody.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá ảnh đẹp, đặt lịch chụp trong vài chạm.'**
  String get roleCustomerBody;

  /// No description provided for @rolePhotographerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhận chụp'**
  String get rolePhotographerTitle;

  /// No description provided for @rolePhotographerBody.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ảnh, nhận yêu cầu, quản lý lịch và doanh thu.'**
  String get rolePhotographerBody;

  /// No description provided for @roleContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get roleContinue;

  /// No description provided for @emptyHomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đẹp sẽ xuất hiện ở đây'**
  String get emptyHomeTitle;

  /// No description provided for @emptyHomeBody.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi nhiếp ảnh gia bạn thích để bắt đầu.'**
  String get emptyHomeBody;

  /// No description provided for @emptyExploreTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá theo dịch vụ và địa điểm'**
  String get emptyExploreTitle;

  /// No description provided for @emptyExploreBody.
  ///
  /// In vi, this message translates to:
  /// **'Chân dung, cưới, gia đình, kỷ yếu và hơn thế.'**
  String get emptyExploreBody;

  /// No description provided for @emptyFindTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhiếp ảnh gia rảnh đúng ngày bạn cần'**
  String get emptyFindTitle;

  /// No description provided for @emptyFindBody.
  ///
  /// In vi, this message translates to:
  /// **'Chọn địa điểm, ngày và dịch vụ để so sánh.'**
  String get emptyFindBody;

  /// No description provided for @emptyCreateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cho mọi người thấy bạn chụp gì'**
  String get emptyCreateTitle;

  /// No description provided for @emptyCreateBody.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi bài đăng gắn một gói dịch vụ để khách đặt ngay.'**
  String get emptyCreateBody;

  /// No description provided for @emptyBookingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp tiếp theo bắt đầu từ đây'**
  String get emptyBookingsTitle;

  /// No description provided for @emptyBookingsBody.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu và lịch chụp của bạn sẽ hiện ở đây.'**
  String get emptyBookingsBody;

  /// No description provided for @emptyWorkTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu nào'**
  String get emptyWorkTitle;

  /// No description provided for @emptyWorkBody.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thiện hồ sơ và đăng ảnh để được tìm thấy.'**
  String get emptyWorkBody;

  /// No description provided for @profileRoleCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Khách hàng'**
  String get profileRoleCustomer;

  /// No description provided for @profileRolePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia'**
  String get profileRolePhotographer;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get settingsAccount;

  /// No description provided for @settingsEditProfile.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get settingsEditProfile;

  /// No description provided for @settingsEditProfileBody.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get settingsEditProfileBody;

  /// No description provided for @settingsAppearance.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsAppearance;

  /// No description provided for @themeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In vi, this message translates to:
  /// **'Theo hệ thống'**
  String get themeSystem;

  /// No description provided for @settingsButtonStyle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểu nút chính'**
  String get settingsButtonStyle;

  /// No description provided for @buttonStyleGradient.
  ///
  /// In vi, this message translates to:
  /// **'Gradient theo giao diện'**
  String get buttonStyleGradient;

  /// No description provided for @buttonStyleAvatar.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện làm mờ'**
  String get buttonStyleAvatar;

  /// No description provided for @buttonStyleAvatarNeedsPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh đại diện trong hồ sơ để dùng kiểu này.'**
  String get buttonStyleAvatarNeedsPhoto;

  /// No description provided for @settingsButtonPreview.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước nút'**
  String get settingsButtonPreview;

  /// No description provided for @settingsDeveloper.
  ///
  /// In vi, this message translates to:
  /// **'Dành cho nhà phát triển'**
  String get settingsDeveloper;

  /// No description provided for @settingsShowScreenCodes.
  ///
  /// In vi, this message translates to:
  /// **'Hiện mã màn hình'**
  String get settingsShowScreenCodes;

  /// No description provided for @settingsShowScreenCodesBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhãn Sxx ở góc trên trái mỗi màn, để gọi tên màn khi cần chỉnh sửa.'**
  String get settingsShowScreenCodesBody;

  /// No description provided for @editProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get editProfileTitle;

  /// No description provided for @editProfileSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get editProfileSave;

  /// No description provided for @editProfileSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu hồ sơ.'**
  String get editProfileSaved;

  /// No description provided for @editProfileError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được hồ sơ. Kiểm tra mạng rồi thử lại.'**
  String get editProfileError;

  /// No description provided for @profileOfferPhotographerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi là nhiếp ảnh gia'**
  String get profileOfferPhotographerTitle;

  /// No description provided for @profileOfferPhotographerBody.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ảnh, nhận booking và quản lý lịch. Bạn vẫn đổi lại được bất cứ lúc nào.'**
  String get profileOfferPhotographerBody;

  /// No description provided for @profileOfferCustomerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi cần đặt lịch'**
  String get profileOfferCustomerTitle;

  /// No description provided for @profileOfferCustomerBody.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhiếp ảnh gia, đặt lịch và nhắn tin. Bạn vẫn đổi lại được bất cứ lúc nào.'**
  String get profileOfferCustomerBody;

  /// No description provided for @profileSwitchToCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển qua chế độ đặt lịch'**
  String get profileSwitchToCustomer;

  /// No description provided for @profileSwitchToPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển qua chế độ nhiếp ảnh'**
  String get profileSwitchToPhotographer;

  /// No description provided for @profileSwitchedToCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Đã chuyển qua chế độ đặt lịch.'**
  String get profileSwitchedToCustomer;

  /// No description provided for @profileSwitchedToPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Đã chuyển qua chế độ nhiếp ảnh.'**
  String get profileSwitchedToPhotographer;

  /// No description provided for @profileSwitchError.
  ///
  /// In vi, this message translates to:
  /// **'Không đổi được chế độ. Kiểm tra mạng rồi thử lại.'**
  String get profileSwitchError;

  /// No description provided for @statusRequested.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get statusRequested;

  /// No description provided for @statusAccepted.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận'**
  String get statusAccepted;

  /// No description provided for @statusDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get statusDeclined;

  /// No description provided for @statusExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get statusExpired;

  /// No description provided for @statusCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get statusCancelled;

  /// No description provided for @statusUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Sắp tới'**
  String get statusUpcoming;

  /// No description provided for @statusCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get statusCompleted;

  /// No description provided for @statusReviewed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh giá'**
  String get statusReviewed;

  /// No description provided for @sessionErrorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được tài khoản'**
  String get sessionErrorTitle;

  /// No description provided for @sessionErrorBody.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối mạng rồi thử lại. Nếu vẫn lỗi, hãy đăng xuất và đăng nhập lại.'**
  String get sessionErrorBody;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @roleSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được lựa chọn. Kiểm tra mạng rồi thử lại.'**
  String get roleSaveError;

  /// No description provided for @verifiedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh'**
  String get verifiedLabel;

  /// No description provided for @freeTag.
  ///
  /// In vi, this message translates to:
  /// **'Không thu phí'**
  String get freeTag;

  /// No description provided for @freeBannerBody.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký để giữ chỗ, không cần thanh toán'**
  String get freeBannerBody;

  /// No description provided for @capacityUsed.
  ///
  /// In vi, this message translates to:
  /// **'{used} / {total} đã đăng ký'**
  String capacityUsed(int used, int total);

  /// No description provided for @stepProgressCount.
  ///
  /// In vi, this message translates to:
  /// **'{current} / {total}'**
  String stepProgressCount(int current, int total);

  /// No description provided for @stepProgressSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Bước {current} trên {total}'**
  String stepProgressSemantics(int current, int total);

  /// No description provided for @phoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get phoneLabel;

  /// No description provided for @phoneRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số điện thoại'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại chưa đúng. Ví dụ: 903 123 456'**
  String get phoneInvalid;

  /// No description provided for @phoneInvalidInternational.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số có mã quốc gia, ví dụ: +1 415 555 2671'**
  String get phoneInvalidInternational;

  /// No description provided for @addPhoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm số điện thoại để đặt lịch'**
  String get addPhoneTitle;

  /// No description provided for @addPhoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia sẽ gọi hoặc nhắn Zalo/WhatsApp cho bạn để chốt chi tiết.'**
  String get addPhoneBody;

  /// No description provided for @addPhoneExample.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 0903 123 456. Chưa cần mã xác minh; bước xác minh sẽ bổ sung sau.'**
  String get addPhoneExample;

  /// No description provided for @allowZaloLabel.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép liên hệ qua Zalo'**
  String get allowZaloLabel;

  /// No description provided for @allowWhatsAppLabel.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép liên hệ qua WhatsApp'**
  String get allowWhatsAppLabel;

  /// No description provided for @phonePrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.'**
  String get phonePrivacy;

  /// No description provided for @addPhoneSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu và tiếp tục'**
  String get addPhoneSave;

  /// No description provided for @phoneSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được số điện thoại. Thử lại nhé.'**
  String get phoneSaveError;

  /// No description provided for @contactLabel.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get contactLabel;

  /// No description provided for @contactCall.
  ///
  /// In vi, this message translates to:
  /// **'Gọi điện'**
  String get contactCall;

  /// No description provided for @contactZalo.
  ///
  /// In vi, this message translates to:
  /// **'Zalo'**
  String get contactZalo;

  /// No description provided for @contactWhatsApp.
  ///
  /// In vi, this message translates to:
  /// **'WhatsApp'**
  String get contactWhatsApp;

  /// No description provided for @contactInquiry.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin hỏi trước'**
  String get contactInquiry;

  /// No description provided for @contactOpening.
  ///
  /// In vi, this message translates to:
  /// **'Đang mở liên hệ'**
  String get contactOpening;

  /// No description provided for @contactLockedHint.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ qua điện thoại mở sau khi bạn đặt lịch'**
  String get contactLockedHint;

  /// No description provided for @contactOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được liên hệ. Thử lại nhé.'**
  String get contactOpenError;

  /// No description provided for @setupContactTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực và liên hệ'**
  String get setupContactTitle;

  /// No description provided for @setupContactArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực phục vụ'**
  String get setupContactArea;

  /// No description provided for @setupContactCity.
  ///
  /// In vi, this message translates to:
  /// **'Thành phố'**
  String get setupContactCity;

  /// No description provided for @setupContactRadius.
  ///
  /// In vi, this message translates to:
  /// **'Bán kính phục vụ'**
  String get setupContactRadius;

  /// No description provided for @setupRadiusValue.
  ///
  /// In vi, this message translates to:
  /// **'{km} km'**
  String setupRadiusValue(int km);

  /// No description provided for @setupContactPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại · bắt buộc'**
  String get setupContactPhone;

  /// No description provided for @setupContactChannels.
  ///
  /// In vi, this message translates to:
  /// **'Chọn kênh khách được dùng để liên hệ bạn.'**
  String get setupContactChannels;

  /// No description provided for @setupChannelCall.
  ///
  /// In vi, this message translates to:
  /// **'Gọi điện'**
  String get setupChannelCall;

  /// No description provided for @setupChannelCallHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số điện thoại ở trên'**
  String get setupChannelCallHint;

  /// No description provided for @setupChannelZalo.
  ///
  /// In vi, this message translates to:
  /// **'Zalo'**
  String get setupChannelZalo;

  /// No description provided for @setupChannelZaloHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số ở trên hoặc nhập số riêng'**
  String get setupChannelZaloHint;

  /// No description provided for @setupZaloOwn.
  ///
  /// In vi, this message translates to:
  /// **'Số Zalo riêng (để trống nếu dùng số trên)'**
  String get setupZaloOwn;

  /// No description provided for @setupChannelWhatsApp.
  ///
  /// In vi, this message translates to:
  /// **'WhatsApp'**
  String get setupChannelWhatsApp;

  /// No description provided for @setupChannelWhatsAppHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số quốc tế riêng, hoặc dùng số ở trên'**
  String get setupChannelWhatsAppHint;

  /// No description provided for @setupWhatsAppOwn.
  ///
  /// In vi, this message translates to:
  /// **'Số WhatsApp có mã quốc gia (để trống nếu dùng số trên)'**
  String get setupWhatsAppOwn;

  /// No description provided for @setupInAppOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ nhận tin nhắn trong app'**
  String get setupInAppOnly;

  /// No description provided for @setupInAppOnlyHint.
  ///
  /// In vi, this message translates to:
  /// **'Khách chỉ nhắn được trong ứng dụng. Bạn có thể bật gọi, Zalo hay WhatsApp sau.'**
  String get setupInAppOnlyHint;

  /// No description provided for @setupContactPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Số của bạn không hiện công khai. Khách chỉ dùng được các kênh này sau khi đã đặt lịch.'**
  String get setupContactPrivacy;

  /// No description provided for @setupContactBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get setupContactBack;

  /// No description provided for @setupContactFinish.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất'**
  String get setupContactFinish;

  /// No description provided for @setupCityRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập thành phố bạn nhận việc'**
  String get setupCityRequired;

  /// No description provided for @setupNoChannel.
  ///
  /// In vi, this message translates to:
  /// **'Bật ít nhất một kênh, hoặc chọn \"Chỉ nhận tin nhắn trong app\".'**
  String get setupNoChannel;

  /// No description provided for @setupWhatsAppNeedsNumber.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số WhatsApp có mã quốc gia, ví dụ +1 415 555 2671'**
  String get setupWhatsAppNeedsNumber;

  /// No description provided for @setupSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.'**
  String get setupSaveError;

  /// No description provided for @locationPromptTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện gần bạn'**
  String get locationPromptTitle;

  /// No description provided for @locationPromptBody.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.'**
  String get locationPromptBody;

  /// No description provided for @locationAllow.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép'**
  String get locationAllow;

  /// No description provided for @locationLater.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get locationLater;

  /// No description provided for @locationChooseArea.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khu vực'**
  String get locationChooseArea;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
