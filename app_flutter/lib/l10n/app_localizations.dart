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

  /// No description provided for @loadingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải'**
  String get loadingLabel;

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

  /// No description provided for @settingsPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get settingsPhone;

  /// No description provided for @settingsPhoneEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thêm'**
  String get settingsPhoneEmpty;

  /// No description provided for @settingsPhoneAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm'**
  String get settingsPhoneAdded;

  /// No description provided for @settingsPhoneMasked.
  ///
  /// In vi, this message translates to:
  /// **'•••• {last4}'**
  String settingsPhoneMasked(String last4);

  /// No description provided for @settingsSkills.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ năng'**
  String get settingsSkills;

  /// No description provided for @settingsSkillsBody.
  ///
  /// In vi, this message translates to:
  /// **'Thể loại, mức độ và phong cách'**
  String get settingsSkillsBody;

  /// No description provided for @settingsPublicProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ công khai'**
  String get settingsPublicProfile;

  /// No description provided for @settingsPublicProfileBody.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ như khách nhìn thấy'**
  String get settingsPublicProfileBody;

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

  /// No description provided for @editProfileChangeAvatar.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ảnh đại diện'**
  String get editProfileChangeAvatar;

  /// No description provided for @editProfileAvatarSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi ảnh đại diện.'**
  String get editProfileAvatarSaved;

  /// No description provided for @editProfileAvatarError.
  ///
  /// In vi, this message translates to:
  /// **'Không đổi được ảnh. Thử lại nhé.'**
  String get editProfileAvatarError;

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

  /// No description provided for @profileSetupTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thiện hồ sơ nhiếp ảnh gia'**
  String get profileSetupTitle;

  /// No description provided for @profileSetupBody.
  ///
  /// In vi, this message translates to:
  /// **'Còn vài bước nữa để khách tìm thấy và đặt lịch với bạn.'**
  String get profileSetupBody;

  /// No description provided for @profileSetupContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục thiết lập'**
  String get profileSetupContinue;

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

  /// No description provided for @phoneCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã'**
  String get phoneCodeLabel;

  /// No description provided for @phoneCodeSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Mã +84'**
  String get phoneCodeSemantics;

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

  /// No description provided for @editProfilePhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.'**
  String get editProfilePhoneHint;

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

  /// No description provided for @contactCallShort.
  ///
  /// In vi, this message translates to:
  /// **'Gọi'**
  String get contactCallShort;

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

  /// No description provided for @setupFlowTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ nhiếp ảnh gia'**
  String get setupFlowTitle;

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
  /// **'Dùng số trên'**
  String get setupChannelCallHint;

  /// No description provided for @setupChannelZalo.
  ///
  /// In vi, this message translates to:
  /// **'Zalo'**
  String get setupChannelZalo;

  /// No description provided for @setupChannelZaloHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng số trên'**
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
  /// **'Nhập số riêng nếu khác'**
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

  /// No description provided for @setupIntroHeading.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu bản thân'**
  String get setupIntroHeading;

  /// No description provided for @setupIntroHint.
  ///
  /// In vi, this message translates to:
  /// **'Khách đọc phần này trước khi đặt lịch. Viết ngắn, nói rõ bạn chụp kiểu gì.'**
  String get setupIntroHint;

  /// No description provided for @setupBioLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu ngắn'**
  String get setupBioLabel;

  /// No description provided for @setupBioHint.
  ///
  /// In vi, this message translates to:
  /// **'Ánh sáng tự nhiên, ít dàn dựng. Chuyên chân dung ngoài trời ở Sài Gòn.'**
  String get setupBioHint;

  /// No description provided for @setupEquipmentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị (không bắt buộc)'**
  String get setupEquipmentLabel;

  /// No description provided for @setupEquipmentHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Sony A7 IV'**
  String get setupEquipmentHint;

  /// No description provided for @setupEquipmentAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm thiết bị'**
  String get setupEquipmentAdd;

  /// No description provided for @setupEquipmentRemove.
  ///
  /// In vi, this message translates to:
  /// **'Xoá {item}'**
  String setupEquipmentRemove(String item);

  /// No description provided for @setupEquipmentFull.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 8 thiết bị.'**
  String get setupEquipmentFull;

  /// No description provided for @setupNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get setupNext;

  /// No description provided for @introBioRequired.
  ///
  /// In vi, this message translates to:
  /// **'Viết vài dòng giới thiệu'**
  String get introBioRequired;

  /// No description provided for @introBioTooLong.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 300 ký tự'**
  String get introBioTooLong;

  /// No description provided for @setupServicesHeading.
  ///
  /// In vi, this message translates to:
  /// **'Gói dịch vụ'**
  String get setupServicesHeading;

  /// No description provided for @setupServiceHint.
  ///
  /// In vi, this message translates to:
  /// **'Khách đặt theo gói. Cần ít nhất một gói để hồ sơ hiện trong Tìm thợ ảnh.'**
  String get setupServiceHint;

  /// No description provided for @setupNoPackages.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có gói nào. Thêm gói đầu tiên bên dưới.'**
  String get setupNoPackages;

  /// No description provided for @setupNeedPackage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ít nhất một gói để tiếp tục.'**
  String get setupNeedPackage;

  /// No description provided for @setupPackagesLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được danh sách gói.'**
  String get setupPackagesLoadError;

  /// No description provided for @packageEditHeading.
  ///
  /// In vi, this message translates to:
  /// **'Sửa gói'**
  String get packageEditHeading;

  /// No description provided for @packageNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên gói'**
  String get packageNameLabel;

  /// No description provided for @packageNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Chân dung 2 giờ'**
  String get packageNameHint;

  /// No description provided for @packagePriceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giá (₫)'**
  String get packagePriceLabel;

  /// No description provided for @packageDurationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng'**
  String get packageDurationLabel;

  /// No description provided for @packageDurationHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn'**
  String get packageDurationHint;

  /// No description provided for @durationHours.
  ///
  /// In vi, this message translates to:
  /// **'{hours} giờ'**
  String durationHours(String hours);

  /// No description provided for @packageEditedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số ảnh hậu kỳ'**
  String get packageEditedLabel;

  /// No description provided for @packageDeliveryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giao sau (ngày)'**
  String get packageDeliveryLabel;

  /// No description provided for @packagePhotos.
  ///
  /// In vi, this message translates to:
  /// **'{count} ảnh'**
  String packagePhotos(int count);

  /// No description provided for @packageDelivery.
  ///
  /// In vi, this message translates to:
  /// **'{days, plural, =0{giao trong ngày} other{giao {days} ngày}}'**
  String packageDelivery(int days);

  /// No description provided for @packageAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm gói này'**
  String get packageAdd;

  /// No description provided for @packageSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu gói'**
  String get packageSave;

  /// No description provided for @packageCancelEdit.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ sửa'**
  String get packageCancelEdit;

  /// No description provided for @packageHideTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn gói {name}'**
  String packageHideTooltip(String name);

  /// No description provided for @packageHideTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn gói này?'**
  String get packageHideTitle;

  /// No description provided for @packageHideBody.
  ///
  /// In vi, this message translates to:
  /// **'Khách sẽ không thấy và không đặt được gói này nữa. Bài đăng cũ vẫn giữ nguyên.'**
  String get packageHideBody;

  /// No description provided for @packageHideConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn gói'**
  String get packageHideConfirm;

  /// No description provided for @packageKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lại'**
  String get packageKeep;

  /// No description provided for @packageAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm gói.'**
  String get packageAdded;

  /// No description provided for @packageSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu gói.'**
  String get packageSaved;

  /// No description provided for @packageHidden.
  ///
  /// In vi, this message translates to:
  /// **'Đã ẩn gói.'**
  String get packageHidden;

  /// No description provided for @packageNameLength.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên gói từ 2 đến 60 ký tự'**
  String get packageNameLength;

  /// No description provided for @packagePriceRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập giá lớn hơn 0'**
  String get packagePriceRequired;

  /// No description provided for @packagePriceTooHigh.
  ///
  /// In vi, this message translates to:
  /// **'Giá tối đa 1.000.000.000₫'**
  String get packagePriceTooHigh;

  /// No description provided for @packageDurationRequired.
  ///
  /// In vi, this message translates to:
  /// **'Chọn thời lượng'**
  String get packageDurationRequired;

  /// No description provided for @packageCountInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số từ 0 đến 2000'**
  String get packageCountInvalid;

  /// No description provided for @packageDaysInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số ngày từ 0 đến 90'**
  String get packageDaysInvalid;

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

  /// No description provided for @eventTypePhotoWalk.
  ///
  /// In vi, this message translates to:
  /// **'Photo walk'**
  String get eventTypePhotoWalk;

  /// No description provided for @eventTypeMiniSession.
  ///
  /// In vi, this message translates to:
  /// **'Mini session'**
  String get eventTypeMiniSession;

  /// No description provided for @eventTypeWorkshop.
  ///
  /// In vi, this message translates to:
  /// **'Workshop'**
  String get eventTypeWorkshop;

  /// No description provided for @eventTypeCosplay.
  ///
  /// In vi, this message translates to:
  /// **'Cosplay'**
  String get eventTypeCosplay;

  /// No description provided for @eventTypeOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get eventTypeOther;

  /// No description provided for @eventSeatsLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {n} chỗ'**
  String eventSeatsLeft(int n);

  /// No description provided for @eventSoldOut.
  ///
  /// In vi, this message translates to:
  /// **'Hết chỗ'**
  String get eventSoldOut;

  /// No description provided for @eventMonthShort.
  ///
  /// In vi, this message translates to:
  /// **'T{month}'**
  String eventMonthShort(int month);

  /// No description provided for @areaPickerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khu vực của bạn'**
  String get areaPickerTitle;

  /// No description provided for @areaPickerBody.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.'**
  String get areaPickerBody;

  /// No description provided for @areaPickerBodyOn.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khu vực để xem sự kiện quanh đó.'**
  String get areaPickerBodyOn;

  /// No description provided for @areaPickerOpenSettings.
  ///
  /// In vi, this message translates to:
  /// **'Mở Cài đặt để bật vị trí'**
  String get areaPickerOpenSettings;

  /// No description provided for @areaPickerUse.
  ///
  /// In vi, this message translates to:
  /// **'Dùng khu vực này'**
  String get areaPickerUse;

  /// No description provided for @areaPickerUseDevice.
  ///
  /// In vi, this message translates to:
  /// **'Dùng vị trí của tôi'**
  String get areaPickerUseDevice;

  /// No description provided for @areaPickerSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm quận, thành phố'**
  String get areaPickerSearch;

  /// No description provided for @areaPickerNoMatch.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy khu vực'**
  String get areaPickerNoMatch;

  /// No description provided for @areaDeviceFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được vị trí. Chọn một khu vực hoặc thử lại.'**
  String get areaDeviceFailed;

  /// No description provided for @exploreAround.
  ///
  /// In vi, this message translates to:
  /// **'Quanh {area} · vị trí gần đúng'**
  String exploreAround(String area);

  /// No description provided for @exploreAroundMe.
  ///
  /// In vi, this message translates to:
  /// **'Quanh bạn · vị trí gần đúng'**
  String get exploreAroundMe;

  /// No description provided for @exploreChange.
  ///
  /// In vi, this message translates to:
  /// **'Đổi'**
  String get exploreChange;

  /// No description provided for @exploreRadius.
  ///
  /// In vi, this message translates to:
  /// **'{km} km'**
  String exploreRadius(int km);

  /// No description provided for @exploreThisWeek.
  ///
  /// In vi, this message translates to:
  /// **'Tuần này'**
  String get exploreThisWeek;

  /// No description provided for @exploreWeekend.
  ///
  /// In vi, this message translates to:
  /// **'Cuối tuần'**
  String get exploreWeekend;

  /// No description provided for @exploreNearbyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện gần bạn'**
  String get exploreNearbyTitle;

  /// No description provided for @exploreEventsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện chụp ảnh'**
  String get exploreEventsTitle;

  /// No description provided for @exploreSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get exploreSeeAll;

  /// No description provided for @exploreNoneNearby.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có sự kiện gần bạn'**
  String get exploreNoneNearby;

  /// No description provided for @exploreWiden.
  ///
  /// In vi, this message translates to:
  /// **'Tăng bán kính'**
  String get exploreWiden;

  /// No description provided for @exploreTabServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get exploreTabServices;

  /// No description provided for @exploreTabPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get exploreTabPlaces;

  /// No description provided for @exploreTabStyles.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get exploreTabStyles;

  /// No description provided for @exploreTabPhotographers.
  ///
  /// In vi, this message translates to:
  /// **'Thợ ảnh'**
  String get exploreTabPhotographers;

  /// No description provided for @explorePhotographersAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả nhiếp ảnh gia'**
  String get explorePhotographersAll;

  /// No description provided for @exploreLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được sự kiện. Kiểm tra mạng rồi thử lại.'**
  String get exploreLoadError;

  /// No description provided for @eventDateSpoken.
  ///
  /// In vi, this message translates to:
  /// **'{weekday, select, 1{Thứ hai} 2{Thứ ba} 3{Thứ tư} 4{Thứ năm} 5{Thứ sáu} 6{Thứ bảy} other{Chủ nhật}}, ngày {day} tháng {month}'**
  String eventDateSpoken(String weekday, int day, int month);

  /// No description provided for @reasonsSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý vì: {reasons}'**
  String reasonsSemantics(String reasons);

  /// No description provided for @photographerSessions.
  ///
  /// In vi, this message translates to:
  /// **'{n} buổi'**
  String photographerSessions(int n);

  /// No description provided for @priceFrom.
  ///
  /// In vi, this message translates to:
  /// **'từ'**
  String get priceFrom;

  /// No description provided for @priceFromValue.
  ///
  /// In vi, this message translates to:
  /// **'từ {price}'**
  String priceFromValue(String price);

  /// No description provided for @photographerCardProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get photographerCardProfile;

  /// No description provided for @photographerCardBook.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get photographerCardBook;

  /// No description provided for @skillChipFull.
  ///
  /// In vi, this message translates to:
  /// **'Đã đủ số lượng'**
  String get skillChipFull;

  /// No description provided for @completenessTitle.
  ///
  /// In vi, this message translates to:
  /// **'Độ khớp hồ sơ'**
  String get completenessTitle;

  /// No description provided for @completenessNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có điểm'**
  String get completenessNone;

  /// No description provided for @completenessPercent.
  ///
  /// In vi, this message translates to:
  /// **'{percent}%'**
  String completenessPercent(int percent);

  /// No description provided for @skillsLevelBasic.
  ///
  /// In vi, this message translates to:
  /// **'Cơ bản'**
  String get skillsLevelBasic;

  /// No description provided for @skillsLevelGood.
  ///
  /// In vi, this message translates to:
  /// **'Thành thạo'**
  String get skillsLevelGood;

  /// No description provided for @skillsLevelExpert.
  ///
  /// In vi, this message translates to:
  /// **'Chuyên sâu'**
  String get skillsLevelExpert;

  /// No description provided for @skillsLevelSemantics.
  ///
  /// In vi, this message translates to:
  /// **'{name}, mức {level}'**
  String skillsLevelSemantics(String name, String level);

  /// No description provided for @skillsExpertFull.
  ///
  /// In vi, this message translates to:
  /// **'Đã đủ 3 mức Chuyên sâu'**
  String get skillsExpertFull;

  /// No description provided for @skillEvidencePhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {index}'**
  String skillEvidencePhoto(int index);

  /// No description provided for @skillsCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} / {max}'**
  String skillsCount(int n, int max);

  /// No description provided for @skillEvidenceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Minh chứng · {name}'**
  String skillEvidenceTitle(String name);

  /// No description provided for @skillEvidenceBody.
  ///
  /// In vi, this message translates to:
  /// **'Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.'**
  String get skillEvidenceBody;

  /// No description provided for @skillEvidenceDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get skillEvidenceDone;

  /// No description provided for @skillEvidenceEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài trước'**
  String get skillEvidenceEmpty;

  /// No description provided for @skillEvidenceEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có bài đăng nào. Đăng ảnh vào portfolio rồi quay lại chọn ảnh minh chứng.'**
  String get skillEvidenceEmptyBody;

  /// No description provided for @skillEvidenceEmptyAction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài'**
  String get skillEvidenceEmptyAction;

  /// No description provided for @skillEvidenceMax.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 3 ảnh. Bỏ chọn một ảnh để chọn ảnh khác.'**
  String get skillEvidenceMax;

  /// No description provided for @skillEvidenceNeedOne.
  ///
  /// In vi, this message translates to:
  /// **'Mức Chuyên sâu cần ít nhất 1 ảnh'**
  String get skillEvidenceNeedOne;

  /// No description provided for @skillEvidenceLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bài đăng của bạn.'**
  String get skillEvidenceLoadError;

  /// No description provided for @skillEvidenceLoadMore.
  ///
  /// In vi, this message translates to:
  /// **'Tải thêm'**
  String get skillEvidenceLoadMore;

  /// No description provided for @skillEvidenceLoadMoreRetry.
  ///
  /// In vi, this message translates to:
  /// **'Không tải thêm được. Thử lại'**
  String get skillEvidenceLoadMoreRetry;

  /// No description provided for @skillsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ năng'**
  String get skillsTitle;

  /// No description provided for @skillsIntro.
  ///
  /// In vi, this message translates to:
  /// **'Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.'**
  String get skillsIntro;

  /// No description provided for @skillsTypes.
  ///
  /// In vi, this message translates to:
  /// **'Thể loại chụp'**
  String get skillsTypes;

  /// No description provided for @skillsLevels.
  ///
  /// In vi, this message translates to:
  /// **'Mức độ'**
  String get skillsLevels;

  /// No description provided for @skillsMaxExpert.
  ///
  /// In vi, this message translates to:
  /// **'Chuyên sâu tối đa 3'**
  String get skillsMaxExpert;

  /// No description provided for @skillsEvidenceRow.
  ///
  /// In vi, this message translates to:
  /// **'{name}: {n} / 3 ảnh minh chứng'**
  String skillsEvidenceRow(String name, int n);

  /// No description provided for @skillsEvidenceEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh'**
  String get skillsEvidenceEdit;

  /// No description provided for @skillsEvidenceNeeded.
  ///
  /// In vi, this message translates to:
  /// **'Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng'**
  String get skillsEvidenceNeeded;

  /// No description provided for @skillsTooMany.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 6 thể loại'**
  String get skillsTooMany;

  /// No description provided for @skillsTooManyExpert.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ chọn tối đa 3 thể loại mức Chuyên sâu'**
  String get skillsTooManyExpert;

  /// No description provided for @skillsTooManyStyles.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 4 phong cách'**
  String get skillsTooManyStyles;

  /// No description provided for @skillsTooManyExtras.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 8 kỹ năng thêm'**
  String get skillsTooManyExtras;

  /// No description provided for @skillsTooManyAudiences.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 4 nhóm khách phù hợp'**
  String get skillsTooManyAudiences;

  /// No description provided for @skillsStyles.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get skillsStyles;

  /// No description provided for @skillsExtras.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ năng thêm'**
  String get skillsExtras;

  /// No description provided for @skillsLanguages.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get skillsLanguages;

  /// No description provided for @skillsAudiences.
  ///
  /// In vi, this message translates to:
  /// **'Khách phù hợp'**
  String get skillsAudiences;

  /// No description provided for @skillsYears.
  ///
  /// In vi, this message translates to:
  /// **'Kinh nghiệm'**
  String get skillsYears;

  /// No description provided for @skillsYearsSuffix.
  ///
  /// In vi, this message translates to:
  /// **'năm'**
  String get skillsYearsSuffix;

  /// No description provided for @skillsYearsRange.
  ///
  /// In vi, this message translates to:
  /// **'Từ 0 đến 50 năm'**
  String get skillsYearsRange;

  /// No description provided for @skillsNeedLang.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ít nhất 1 ngôn ngữ'**
  String get skillsNeedLang;

  /// No description provided for @skillsBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get skillsBack;

  /// No description provided for @skillsContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get skillsContinue;

  /// No description provided for @skillsSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get skillsSave;

  /// No description provided for @skillsSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được kỹ năng. Thử lại nhé.'**
  String get skillsSaveError;

  /// No description provided for @skillsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được kỹ năng.'**
  String get skillsLoadError;

  /// No description provided for @skillsFixIssues.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra lại các mục được đánh dấu'**
  String get skillsFixIssues;

  /// No description provided for @skillsDraftRestored.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở lại bản nháp chưa lưu'**
  String get skillsDraftRestored;

  /// No description provided for @skillsHintSpecialty.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ít nhất 1 thể loại'**
  String get skillsHintSpecialty;

  /// No description provided for @skillsHintEvidence.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh minh chứng cho {name}'**
  String skillsHintEvidence(String name);

  /// No description provided for @skillsHintEvidenceAny.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh minh chứng cho thể loại Chuyên sâu'**
  String get skillsHintEvidenceAny;

  /// No description provided for @skillsHintStyles.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phong cách'**
  String get skillsHintStyles;

  /// No description provided for @skillsHintLanguages.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get skillsHintLanguages;

  /// No description provided for @skillsHintAudiences.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khách phù hợp'**
  String get skillsHintAudiences;

  /// No description provided for @skillsHintExtras.
  ///
  /// In vi, this message translates to:
  /// **'Chọn kỹ năng thêm'**
  String get skillsHintExtras;

  /// No description provided for @skillsHintDone.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ kỹ năng đã đầy đủ'**
  String get skillsHintDone;

  /// No description provided for @skillsFitSaveToScore.
  ///
  /// In vi, this message translates to:
  /// **'Lưu để tính độ khớp'**
  String get skillsFitSaveToScore;

  /// No description provided for @skillsFitSaveToUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Lưu để cập nhật độ khớp'**
  String get skillsFitSaveToUpdate;

  /// No description provided for @skillsHintTarget.
  ///
  /// In vi, this message translates to:
  /// **'{hint} để lên {percent}%'**
  String skillsHintTarget(String hint, int percent);

  /// No description provided for @skillsEvidenceRemoved.
  ///
  /// In vi, this message translates to:
  /// **'Một số minh chứng không hợp lệ đã được gỡ'**
  String get skillsEvidenceRemoved;

  /// No description provided for @skillsLeaveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu bản nháp?'**
  String get skillsLeaveTitle;

  /// No description provided for @skillsLeaveBody.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi chưa được lưu vào hồ sơ. Giữ bản nháp trên máy để làm tiếp lần sau nhé.'**
  String get skillsLeaveBody;

  /// No description provided for @skillsLeaveKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ bản nháp'**
  String get skillsLeaveKeep;

  /// No description provided for @skillsLeaveDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi'**
  String get skillsLeaveDiscard;

  /// No description provided for @skillsRemoveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thể loại {name}?'**
  String skillsRemoveTitle(String name);

  /// No description provided for @skillsRemoveBody.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh minh chứng đã gắn cho thể loại này cũng sẽ bị gỡ.'**
  String get skillsRemoveBody;

  /// No description provided for @skillsRemoveKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lại'**
  String get skillsRemoveKeep;

  /// No description provided for @skillsRemoveConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thể loại'**
  String get skillsRemoveConfirm;

  /// No description provided for @calendarMonthTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}, {year}'**
  String calendarMonthTitle(String month, String year);

  /// No description provided for @calendarMonthShort.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}'**
  String calendarMonthShort(String month);

  /// No description provided for @calendarPrevMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng trước'**
  String get calendarPrevMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng sau'**
  String get calendarNextMonth;

  /// No description provided for @calendarWeekdayShort.
  ///
  /// In vi, this message translates to:
  /// **'{weekday, select, mon{T2} tue{T3} wed{T4} thu{T5} fri{T6} sat{T7} other{CN}}'**
  String calendarWeekdayShort(String weekday);

  /// No description provided for @calendarWeekdayLong.
  ///
  /// In vi, this message translates to:
  /// **'{weekday, select, mon{Thứ 2} tue{Thứ 3} wed{Thứ 4} thu{Thứ 5} fri{Thứ 6} sat{Thứ 7} other{Chủ nhật}}'**
  String calendarWeekdayLong(String weekday);

  /// No description provided for @calendarDayTitle.
  ///
  /// In vi, this message translates to:
  /// **'{weekday}, {day}/{month}'**
  String calendarDayTitle(String weekday, String day, String month);

  /// No description provided for @dayStateFree.
  ///
  /// In vi, this message translates to:
  /// **'Rảnh'**
  String get dayStateFree;

  /// No description provided for @dayStatePending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ nhận'**
  String get dayStatePending;

  /// No description provided for @dayStateBooked.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt'**
  String get dayStateBooked;

  /// No description provided for @dayStateOff.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ'**
  String get dayStateOff;

  /// No description provided for @calendarDaySemantics.
  ///
  /// In vi, this message translates to:
  /// **'{day} tháng {month}, {state}'**
  String calendarDaySemantics(String day, String month, String state);

  /// No description provided for @calendarHasEvent.
  ///
  /// In vi, this message translates to:
  /// **'có sự kiện'**
  String get calendarHasEvent;

  /// No description provided for @calendarToday.
  ///
  /// In vi, this message translates to:
  /// **'hôm nay'**
  String get calendarToday;

  /// No description provided for @myCalendarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch của tôi'**
  String get myCalendarTitle;

  /// No description provided for @calendarMarkOff.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu nghỉ'**
  String get calendarMarkOff;

  /// No description provided for @calendarClearOff.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ nghỉ'**
  String get calendarClearOff;

  /// No description provided for @calendarUndo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get calendarUndo;

  /// No description provided for @calendarHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.'**
  String get calendarHint;

  /// No description provided for @calendarRangeHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm ngày cuối để đánh dấu nghỉ cả khoảng.'**
  String get calendarRangeHint;

  /// No description provided for @calendarHasPlan.
  ///
  /// In vi, this message translates to:
  /// **'Ngày này đã có lịch'**
  String get calendarHasPlan;

  /// No description provided for @calendarMarkedOff.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh dấu nghỉ'**
  String get calendarMarkedOff;

  /// No description provided for @calendarMarkedOffMany.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh dấu nghỉ {count} ngày'**
  String calendarMarkedOffMany(int count);

  /// No description provided for @calendarClearedOff.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ nghỉ'**
  String get calendarClearedOff;

  /// No description provided for @calendarOpenBooking.
  ///
  /// In vi, this message translates to:
  /// **'Xem lịch hẹn'**
  String get calendarOpenBooking;

  /// No description provided for @calendarOpenEvent.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý sự kiện'**
  String get calendarOpenEvent;

  /// No description provided for @calendarSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được lịch. Thử lại nhé.'**
  String get calendarSaveError;

  /// No description provided for @calendarLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được lịch.'**
  String get calendarLoadError;

  /// No description provided for @calendarPickDay.
  ///
  /// In vi, this message translates to:
  /// **'Chọn một ngày để xem chi tiết.'**
  String get calendarPickDay;

  /// No description provided for @createAddPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh'**
  String get createAddPhotos;

  /// No description provided for @createPhotosCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} / {max} ảnh'**
  String createPhotosCount(int n, int max);

  /// No description provided for @createCaptionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get createCaptionLabel;

  /// No description provided for @createCaptionHint.
  ///
  /// In vi, this message translates to:
  /// **'Chiều muộn ở bến Bạch Đằng…'**
  String get createCaptionHint;

  /// No description provided for @createServiceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Gói dịch vụ · bắt buộc'**
  String get createServiceLabel;

  /// No description provided for @createServicePick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn gói'**
  String get createServicePick;

  /// No description provided for @createServiceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn gói dịch vụ'**
  String get createServiceTitle;

  /// No description provided for @createServiceRequired.
  ///
  /// In vi, this message translates to:
  /// **'Chọn gói dịch vụ cho bài đăng'**
  String get createServiceRequired;

  /// No description provided for @createPhotosRequired.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ít nhất một ảnh'**
  String get createPhotosRequired;

  /// No description provided for @createNoServices.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có gói dịch vụ nào. Thêm gói để đăng bài.'**
  String get createNoServices;

  /// No description provided for @createAddService.
  ///
  /// In vi, this message translates to:
  /// **'Thêm gói'**
  String get createAddService;

  /// No description provided for @createServicesError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được gói dịch vụ.'**
  String get createServicesError;

  /// No description provided for @createLocationLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get createLocationLabel;

  /// No description provided for @createStyleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get createStyleLabel;

  /// No description provided for @createStyleNone.
  ///
  /// In vi, this message translates to:
  /// **'Không chọn'**
  String get createStyleNone;

  /// No description provided for @createStyleTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get createStyleTitle;

  /// No description provided for @createPublish.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get createPublish;

  /// No description provided for @createRemove.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ ảnh'**
  String get createRemove;

  /// No description provided for @createMoveUp.
  ///
  /// In vi, this message translates to:
  /// **'Đưa lên'**
  String get createMoveUp;

  /// No description provided for @createMoveDown.
  ///
  /// In vi, this message translates to:
  /// **'Đưa xuống'**
  String get createMoveDown;

  /// No description provided for @createRetryPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại ảnh'**
  String get createRetryPhoto;

  /// No description provided for @createUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải {percent}%'**
  String createUploading(int percent);

  /// No description provided for @createUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh. Thử lại nhé.'**
  String get createUploadFailed;

  /// No description provided for @createPublishFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đăng được bài. Kiểm tra mạng rồi thử lại.'**
  String get createPublishFailed;

  /// No description provided for @createPublished.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng bài'**
  String get createPublished;

  /// No description provided for @reasonFreeOnDate.
  ///
  /// In vi, this message translates to:
  /// **'Rảnh {day}'**
  String reasonFreeOnDate(String day);

  /// No description provided for @reasonSkillMatch.
  ///
  /// In vi, this message translates to:
  /// **'Chuyên {specialty}'**
  String reasonSkillMatch(String specialty);

  /// No description provided for @reasonNear.
  ///
  /// In vi, this message translates to:
  /// **'Cách {distance}'**
  String reasonNear(String distance);

  /// No description provided for @reasonTopRated.
  ///
  /// In vi, this message translates to:
  /// **'★ {rating} · {count} đánh giá'**
  String reasonTopRated(String rating, int count);

  /// No description provided for @reasonFastReply.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi nhanh'**
  String get reasonFastReply;

  /// No description provided for @reasonNewTalent.
  ///
  /// In vi, this message translates to:
  /// **'Mới tham gia'**
  String get reasonNewTalent;

  /// No description provided for @homePillFree.
  ///
  /// In vi, this message translates to:
  /// **'Rảnh {day} này'**
  String homePillFree(String day);

  /// No description provided for @engagementError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thực hiện được. Thử lại nhé.'**
  String get engagementError;

  /// No description provided for @back.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get back;

  /// No description provided for @homeGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Chào {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay chụp gì?'**
  String get homeTitle;

  /// No description provided for @homeForYou.
  ///
  /// In vi, this message translates to:
  /// **'Dành cho bạn'**
  String get homeForYou;

  /// No description provided for @homeFreeThisWeek.
  ///
  /// In vi, this message translates to:
  /// **'Rảnh tuần này'**
  String get homeFreeThisWeek;

  /// No description provided for @homeRealShoots.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp thật'**
  String get homeRealShoots;

  /// No description provided for @homeFromCustomers.
  ///
  /// In vi, this message translates to:
  /// **'Từ khách hàng'**
  String get homeFromCustomers;

  /// No description provided for @homeRealShootBy.
  ///
  /// In vi, this message translates to:
  /// **'Chụp bởi {name}'**
  String homeRealShootBy(String name);

  /// No description provided for @homeEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh nào quanh bạn'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá nhiếp ảnh gia để thấy ảnh đẹp ở đây.'**
  String get homeEmptyBody;

  /// No description provided for @homeEmptyAction.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá nhiếp ảnh gia'**
  String get homeEmptyAction;

  /// No description provided for @homeLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh. Kiểm tra mạng rồi thử lại.'**
  String get homeLoadError;

  /// No description provided for @photoSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ảnh'**
  String get photoSave;

  /// No description provided for @photoUnsave.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ lưu'**
  String get photoUnsave;

  /// No description provided for @photoBook.
  ///
  /// In vi, this message translates to:
  /// **'Đặt gói này'**
  String get photoBook;

  /// No description provided for @photoViewProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ'**
  String get photoViewProfile;

  /// No description provided for @photoFollow.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi'**
  String get photoFollow;

  /// No description provided for @photoFollowing.
  ///
  /// In vi, this message translates to:
  /// **'Đang theo dõi'**
  String get photoFollowing;

  /// No description provided for @photoRealShootBy.
  ///
  /// In vi, this message translates to:
  /// **'Chụp bởi {name} · gói {service}'**
  String photoRealShootBy(String name, String service);

  /// No description provided for @photoRealShootByName.
  ///
  /// In vi, this message translates to:
  /// **'Chụp bởi {name}'**
  String photoRealShootByName(String name);

  /// No description provided for @photoRemovedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bài đăng không còn'**
  String get photoRemovedTitle;

  /// No description provided for @photoRemovedBody.
  ///
  /// In vi, this message translates to:
  /// **'Bài đăng này đã bị gỡ hoặc không tồn tại.'**
  String get photoRemovedBody;

  /// No description provided for @photoBackHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get photoBackHome;

  /// No description provided for @photoMoreOf.
  ///
  /// In vi, this message translates to:
  /// **'Thêm của {name}'**
  String photoMoreOf(String name);

  /// No description provided for @photoMoreProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get photoMoreProfile;

  /// No description provided for @photoItemLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {i}'**
  String photoItemLabel(int i);

  /// No description provided for @photoOtherPackages.
  ///
  /// In vi, this message translates to:
  /// **'Xem các gói khác'**
  String get photoOtherPackages;

  /// No description provided for @photoServiceInactive.
  ///
  /// In vi, this message translates to:
  /// **'Gói này đã ngừng'**
  String get photoServiceInactive;

  /// No description provided for @photoLike.
  ///
  /// In vi, this message translates to:
  /// **'Thích'**
  String get photoLike;

  /// No description provided for @photoUnlike.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thích'**
  String get photoUnlike;

  /// No description provided for @photoPageOf.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {n} trên {total}'**
  String photoPageOf(int n, int total);

  /// No description provided for @photoLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bài đăng. Kiểm tra mạng rồi thử lại.'**
  String get photoLoadError;

  /// No description provided for @servicePhotos.
  ///
  /// In vi, this message translates to:
  /// **'{n} ảnh'**
  String servicePhotos(int n);

  /// No description provided for @serviceDelivery.
  ///
  /// In vi, this message translates to:
  /// **'giao sau {days} ngày'**
  String serviceDelivery(int days);

  /// No description provided for @serviceDurationMinutes.
  ///
  /// In vi, this message translates to:
  /// **'{m} phút'**
  String serviceDurationMinutes(int m);

  /// No description provided for @serviceDurationHours.
  ///
  /// In vi, this message translates to:
  /// **'{h} giờ'**
  String serviceDurationHours(int h);

  /// No description provided for @serviceDurationHoursMinutes.
  ///
  /// In vi, this message translates to:
  /// **'{h} giờ {m} phút'**
  String serviceDurationHoursMinutes(int h, int m);

  /// No description provided for @findDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get findDate;

  /// No description provided for @findService.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get findService;

  /// No description provided for @findPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá'**
  String get findPrice;

  /// No description provided for @findRating.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get findRating;

  /// No description provided for @findNearMe.
  ///
  /// In vi, this message translates to:
  /// **'Quanh bạn'**
  String get findNearMe;

  /// No description provided for @findCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} nhiếp ảnh gia'**
  String findCount(String count);

  /// No description provided for @findCountOnDay.
  ///
  /// In vi, this message translates to:
  /// **'{count} nhiếp ảnh gia rảnh {day}'**
  String findCountOnDay(String count, String day);

  /// No description provided for @findSortBest.
  ///
  /// In vi, this message translates to:
  /// **'Phù hợp nhất'**
  String get findSortBest;

  /// No description provided for @findSortNear.
  ///
  /// In vi, this message translates to:
  /// **'Gần tôi'**
  String get findSortNear;

  /// No description provided for @findSortPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá'**
  String get findSortPrice;

  /// No description provided for @findSortRating.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get findSortRating;

  /// No description provided for @findNoResult.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ai khớp bộ lọc'**
  String get findNoResult;

  /// No description provided for @findNoResultBody.
  ///
  /// In vi, this message translates to:
  /// **'Thử bỏ bớt bộ lọc hoặc chọn ngày khác.'**
  String get findNoResultBody;

  /// No description provided for @findClear.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bộ lọc'**
  String get findClear;

  /// No description provided for @findFallbackNote.
  ///
  /// In vi, this message translates to:
  /// **'Đang xếp theo sao và khoảng cách'**
  String get findFallbackNote;

  /// No description provided for @findLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được danh sách. Kiểm tra mạng rồi thử lại.'**
  String get findLoadError;

  /// No description provided for @findBookDay.
  ///
  /// In vi, this message translates to:
  /// **'Đặt {day}'**
  String findBookDay(String day);

  /// No description provided for @findDateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày'**
  String get findDateTitle;

  /// No description provided for @findDateClear.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ngày'**
  String get findDateClear;

  /// No description provided for @findDateDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get findDateDone;

  /// No description provided for @findServiceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get findServiceTitle;

  /// No description provided for @findServiceAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả dịch vụ'**
  String get findServiceAll;

  /// No description provided for @findPriceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách'**
  String get findPriceTitle;

  /// No description provided for @findPriceAny.
  ///
  /// In vi, this message translates to:
  /// **'Mọi mức giá'**
  String get findPriceAny;

  /// No description provided for @findPriceUnder.
  ///
  /// In vi, this message translates to:
  /// **'Dưới {price}'**
  String findPriceUnder(String price);

  /// No description provided for @findRatingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá tối thiểu'**
  String get findRatingTitle;

  /// No description provided for @findRatingAny.
  ///
  /// In vi, this message translates to:
  /// **'Mọi đánh giá'**
  String get findRatingAny;

  /// No description provided for @findRatingMin.
  ///
  /// In vi, this message translates to:
  /// **'★ {rating}+'**
  String findRatingMin(String rating);

  /// No description provided for @profileResponseMinutes.
  ///
  /// In vi, this message translates to:
  /// **'~{minutes} phút'**
  String profileResponseMinutes(int minutes);

  /// No description provided for @profileResponseHours.
  ///
  /// In vi, this message translates to:
  /// **'~{hours} giờ'**
  String profileResponseHours(int hours);

  /// No description provided for @profileTabPortfolio.
  ///
  /// In vi, this message translates to:
  /// **'Portfolio'**
  String get profileTabPortfolio;

  /// No description provided for @profileTabServices.
  ///
  /// In vi, this message translates to:
  /// **'Gói'**
  String get profileTabServices;

  /// No description provided for @profileTabCalendar.
  ///
  /// In vi, this message translates to:
  /// **'Lịch'**
  String get profileTabCalendar;

  /// No description provided for @profileTabReviews.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get profileTabReviews;

  /// No description provided for @profileBook.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get profileBook;

  /// No description provided for @profileBookFrom.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch · từ {price}'**
  String profileBookFrom(String price);

  /// No description provided for @profileNoServices.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia chưa đăng gói'**
  String get profileNoServices;

  /// No description provided for @profileFollow.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi'**
  String get profileFollow;

  /// No description provided for @profileFollowing.
  ///
  /// In vi, this message translates to:
  /// **'Đang theo dõi'**
  String get profileFollowing;

  /// No description provided for @profileStatReviews.
  ///
  /// In vi, this message translates to:
  /// **'{count} đánh giá'**
  String profileStatReviews(int count);

  /// No description provided for @profileStatNoReviews.
  ///
  /// In vi, this message translates to:
  /// **'đánh giá'**
  String get profileStatNoReviews;

  /// No description provided for @profileStatShoots.
  ///
  /// In vi, this message translates to:
  /// **'buổi chụp'**
  String get profileStatShoots;

  /// No description provided for @profileStatResponse.
  ///
  /// In vi, this message translates to:
  /// **'phản hồi'**
  String get profileStatResponse;

  /// No description provided for @profileStatYears.
  ///
  /// In vi, this message translates to:
  /// **'kinh nghiệm'**
  String get profileStatYears;

  /// No description provided for @profileYearsValue.
  ///
  /// In vi, this message translates to:
  /// **'{years} năm'**
  String profileYearsValue(int years);

  /// No description provided for @profileEquipment.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị: {list}'**
  String profileEquipment(String list);

  /// No description provided for @profileNoPortfolio.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh nào'**
  String get profileNoPortfolio;

  /// No description provided for @profileMorePhotos.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm ảnh'**
  String get profileMorePhotos;

  /// No description provided for @profileSimilar.
  ///
  /// In vi, this message translates to:
  /// **'Thợ ảnh tương tự'**
  String get profileSimilar;

  /// No description provided for @profilePhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh portfolio'**
  String get profilePhoto;

  /// No description provided for @profileEvidenceBadge.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh minh chứng kỹ năng'**
  String get profileEvidenceBadge;

  /// No description provided for @profileNoReviewsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá'**
  String get profileNoReviewsTitle;

  /// No description provided for @profileNoReviewsBody.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá hiện ở đây sau những buổi chụp đầu tiên.'**
  String get profileNoReviewsBody;

  /// No description provided for @profileNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy hồ sơ.'**
  String get profileNotFound;

  /// No description provided for @profileNotReadyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ này chưa sẵn sàng'**
  String get profileNotReadyTitle;

  /// No description provided for @profileNotReadyBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia đang hoàn thiện hồ sơ. Quay lại sau nhé.'**
  String get profileNotReadyBody;

  /// No description provided for @profileLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được hồ sơ.'**
  String get profileLoadError;

  /// No description provided for @profileEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get profileEdit;

  /// No description provided for @profileEditIntro.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
  String get profileEditIntro;

  /// No description provided for @profileEditPackages.
  ///
  /// In vi, this message translates to:
  /// **'Gói dịch vụ'**
  String get profileEditPackages;

  /// No description provided for @profileEditSkills.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ năng'**
  String get profileEditSkills;

  /// No description provided for @profileEditPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện và tên'**
  String get profileEditPhoto;

  /// No description provided for @profileEditContact.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực và liên hệ'**
  String get profileEditContact;

  /// No description provided for @offlineBanner.
  ///
  /// In vi, this message translates to:
  /// **'Đang xem dữ liệu đã lưu'**
  String get offlineBanner;

  /// No description provided for @escrowNoticeDeposit.
  ///
  /// In vi, this message translates to:
  /// **'Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành.'**
  String get escrowNoticeDeposit;

  /// No description provided for @settingsSignOutConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc chắn muốn đăng xuất không?'**
  String get settingsSignOutConfirmBody;

  /// No description provided for @settingsSignOutKeep.
  ///
  /// In vi, this message translates to:
  /// **'Ở lại'**
  String get settingsSignOutKeep;

  /// No description provided for @ticketUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng ký'**
  String get ticketUpcoming;

  /// No description provided for @ticketPendingPayment.
  ///
  /// In vi, this message translates to:
  /// **'Chờ thanh toán'**
  String get ticketPendingPayment;

  /// No description provided for @ticketPast.
  ///
  /// In vi, this message translates to:
  /// **'Đã qua'**
  String get ticketPast;

  /// No description provided for @ticketCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get ticketCancelled;

  /// No description provided for @ticketCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} vé'**
  String ticketCount(int count);

  /// No description provided for @ticketCodeSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Mã vé {code}'**
  String ticketCodeSemantics(String code);

  /// No description provided for @ticketDirections.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ đường'**
  String get ticketDirections;

  /// No description provided for @ticketAddToCalendar.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vào lịch'**
  String get ticketAddToCalendar;

  /// No description provided for @ticketCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ vé'**
  String get ticketCancel;

  /// No description provided for @ticketPay.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get ticketPay;

  /// No description provided for @badgeChipSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Huy hiệu {name}'**
  String badgeChipSemantics(String name);

  /// No description provided for @badgeSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get badgeSeeAll;

  /// No description provided for @badgeNotEarned.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đạt'**
  String get badgeNotEarned;

  /// No description provided for @badgeEarned.
  ///
  /// In vi, this message translates to:
  /// **'Đã đạt'**
  String get badgeEarned;

  /// No description provided for @badgeNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get badgeNew;

  /// No description provided for @notificationTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get notificationTitle;

  /// No description provided for @notificationUnreadCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} thông báo chưa đọc'**
  String notificationUnreadCount(int count);

  /// No description provided for @notificationMarkRead.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu đã đọc'**
  String get notificationMarkRead;

  /// No description provided for @notificationMuteKind.
  ///
  /// In vi, this message translates to:
  /// **'Tắt loại thông báo này'**
  String get notificationMuteKind;

  /// No description provided for @notificationUnreadPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đọc'**
  String get notificationUnreadPrefix;

  /// No description provided for @primerEnableNotification.
  ///
  /// In vi, this message translates to:
  /// **'Bật thông báo'**
  String get primerEnableNotification;

  /// No description provided for @primerLater.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get primerLater;

  /// No description provided for @bookChoosePackage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn gói'**
  String get bookChoosePackage;

  /// No description provided for @bookWith.
  ///
  /// In vi, this message translates to:
  /// **'Đặt với {name}'**
  String bookWith(String name);

  /// No description provided for @bookContinuePrice.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục · {price}'**
  String bookContinuePrice(String price);

  /// No description provided for @bookNoPackages.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia chưa đăng gói'**
  String get bookNoPackages;

  /// No description provided for @bookPriceChanged.
  ///
  /// In vi, this message translates to:
  /// **'Giá gói đã đổi'**
  String get bookPriceChanged;

  /// No description provided for @bookDiscardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ yêu cầu đặt lịch?'**
  String get bookDiscardTitle;

  /// No description provided for @bookDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ'**
  String get bookDiscard;

  /// No description provided for @bookKeepGoing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục đặt'**
  String get bookKeepGoing;

  /// No description provided for @bookClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get bookClose;

  /// No description provided for @bookLegendFree.
  ///
  /// In vi, this message translates to:
  /// **'Rảnh'**
  String get bookLegendFree;

  /// No description provided for @bookLegendBooked.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt'**
  String get bookLegendBooked;

  /// No description provided for @bookLegendPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ'**
  String get bookLegendPending;

  /// No description provided for @bookWaiting.
  ///
  /// In vi, this message translates to:
  /// **'{n} người đang chờ'**
  String bookWaiting(int n);

  /// No description provided for @bookEndsAt.
  ///
  /// In vi, this message translates to:
  /// **'{start}–{end}'**
  String bookEndsAt(String start, String end);

  /// No description provided for @bookDayTaken.
  ///
  /// In vi, this message translates to:
  /// **'Hôm đó vừa có người đặt'**
  String get bookDayTaken;

  /// No description provided for @bookDayNoSlots.
  ///
  /// In vi, this message translates to:
  /// **'Hôm đó đã hết giờ'**
  String get bookDayNoSlots;

  /// No description provided for @bookPlaceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm chụp'**
  String get bookPlaceTitle;

  /// No description provided for @bookPlaceHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên địa điểm hoặc khu vực (tối thiểu 3 ký tự)'**
  String get bookPlaceHint;

  /// No description provided for @bookReview.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại'**
  String get bookReview;

  /// No description provided for @bookNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get bookNote;

  /// No description provided for @bookNoteHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ghi chú cho nhiếp ảnh gia (tuỳ chọn)'**
  String get bookNoteHint;

  /// No description provided for @bookYourPhone.
  ///
  /// In vi, this message translates to:
  /// **'SĐT của bạn'**
  String get bookYourPhone;

  /// No description provided for @bookDepositToday.
  ///
  /// In vi, this message translates to:
  /// **'Đặt cọc hôm nay (30%)'**
  String get bookDepositToday;

  /// No description provided for @bookRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn lại trả tại buổi chụp'**
  String get bookRemaining;

  /// No description provided for @bookPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ trước 48 giờ hoàn cọc 100%. Nhiếp ảnh gia phải nhận trong 24 giờ, nếu không tự hoàn cọc.'**
  String get bookPolicy;

  /// No description provided for @bookPay.
  ///
  /// In vi, this message translates to:
  /// **'Đặt cọc {amount}'**
  String bookPay(String amount);

  /// No description provided for @payTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get payTitle;

  /// No description provided for @payPendingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ xác nhận thanh toán'**
  String get payPendingTitle;

  /// No description provided for @payPendingBody.
  ///
  /// In vi, this message translates to:
  /// **'{provider} chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ.'**
  String payPendingBody(String provider);

  /// No description provided for @payProviderFake.
  ///
  /// In vi, this message translates to:
  /// **'Cổng thử nghiệm'**
  String get payProviderFake;

  /// No description provided for @payProviderNamed.
  ///
  /// In vi, this message translates to:
  /// **'Cổng {name}'**
  String payProviderNamed(String name);

  /// No description provided for @payProviderGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Cổng thanh toán'**
  String get payProviderGeneric;

  /// No description provided for @payAwaitingDeposit.
  ///
  /// In vi, this message translates to:
  /// **'Chờ cọc'**
  String get payAwaitingDeposit;

  /// No description provided for @payCheckAgain.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra lại'**
  String get payCheckAgain;

  /// No description provided for @payNotYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nhận được xác nhận, thử lại sau ít phút'**
  String get payNotYet;

  /// No description provided for @payChangeProvider.
  ///
  /// In vi, this message translates to:
  /// **'Đổi cổng thanh toán'**
  String get payChangeProvider;

  /// No description provided for @fakePaymentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cổng thanh toán giả (chỉ để thử)'**
  String get fakePaymentTitle;

  /// No description provided for @fakePaymentSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thành công'**
  String get fakePaymentSuccess;

  /// No description provided for @fakePaymentCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get fakePaymentCancel;

  /// No description provided for @payRequestSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu'**
  String get payRequestSent;

  /// No description provided for @payReplyIn24h.
  ///
  /// In vi, this message translates to:
  /// **'{name} sẽ trả lời trong 24 giờ'**
  String payReplyIn24h(String name);

  /// No description provided for @escrowNoticeHeld.
  ///
  /// In vi, this message translates to:
  /// **'Cọc {amount} đang được giữ an toàn'**
  String escrowNoticeHeld(String amount);

  /// No description provided for @paySuccessTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu'**
  String get paySuccessTitle;

  /// No description provided for @paySuccessBody.
  ///
  /// In vi, this message translates to:
  /// **'{name} sẽ trả lời trong 24 giờ'**
  String paySuccessBody(String name);

  /// No description provided for @payViewBookings.
  ///
  /// In vi, this message translates to:
  /// **'Xem lịch đặt'**
  String get payViewBookings;

  /// No description provided for @payExpired.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã hết hạn'**
  String get payExpired;

  /// No description provided for @payExpiredTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã hết hạn'**
  String get payExpiredTitle;

  /// No description provided for @payExpiredBody.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nhận được tiền cọc trong 30 phút nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.'**
  String get payExpiredBody;

  /// No description provided for @payRetry.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get payRetry;

  /// No description provided for @payBookAgain.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get payBookAgain;

  /// No description provided for @payGoHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get payGoHome;

  /// No description provided for @bookMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {m}'**
  String bookMonth(int m);

  /// No description provided for @bookDayLine.
  ///
  /// In vi, this message translates to:
  /// **'{day} · khung {duration}'**
  String bookDayLine(String day, String duration);

  /// No description provided for @bookNoSlots.
  ///
  /// In vi, this message translates to:
  /// **'Hôm đó đã hết giờ'**
  String get bookNoSlots;

  /// No description provided for @bookDayGone.
  ///
  /// In vi, this message translates to:
  /// **'Hôm đó vừa có người đặt, chọn ngày khác'**
  String get bookDayGone;

  /// No description provided for @bookPlaceTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ít nhất 3 ký tự'**
  String get bookPlaceTooShort;

  /// No description provided for @bookPackageLine.
  ///
  /// In vi, this message translates to:
  /// **'Gói {name}'**
  String bookPackageLine(String name);

  /// No description provided for @bookTryAgain.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã hết hạn, thử lại nhé.'**
  String get bookTryAgain;

  /// No description provided for @bookPaymentsOff.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán chưa mở trên máy chủ này.'**
  String get bookPaymentsOff;

  /// No description provided for @bookNetworkError.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được. Kiểm tra mạng rồi thử lại.'**
  String get bookNetworkError;

  /// No description provided for @fakePayTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cổng thanh toán giả (chỉ để thử)'**
  String get fakePayTitle;

  /// No description provided for @fakePayBody.
  ///
  /// In vi, this message translates to:
  /// **'Bản dùng thử: không có tiền thật nào được trừ.'**
  String get fakePayBody;

  /// No description provided for @fakePayConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thành công'**
  String get fakePayConfirm;

  /// No description provided for @actionCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get actionCancel;

  /// No description provided for @actionRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get actionRetry;

  /// No description provided for @timelineSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi & đặt cọc'**
  String get timelineSent;

  /// No description provided for @timelineSentDetail.
  ///
  /// In vi, this message translates to:
  /// **'{when} · {amount}'**
  String timelineSentDetail(String when, String amount);

  /// No description provided for @timelineToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay {time}'**
  String timelineToday(String time);

  /// No description provided for @timelineWaiting.
  ///
  /// In vi, this message translates to:
  /// **'Chờ {name} nhận'**
  String timelineWaiting(String name);

  /// No description provided for @timelineWaitingHint.
  ///
  /// In vi, this message translates to:
  /// **'Thường trong 1 giờ'**
  String get timelineWaitingHint;

  /// No description provided for @timelineConfirmed.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác nhận'**
  String get timelineConfirmed;

  /// No description provided for @timelineConfirmedHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin để chốt chi tiết'**
  String get timelineConfirmedHint;

  /// No description provided for @timelineUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Sắp tới · {day}'**
  String timelineUpcoming(String day);

  /// No description provided for @timelineUpcomingHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc trước 24 giờ'**
  String get timelineUpcomingHint;

  /// No description provided for @timelineShoot.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp'**
  String get timelineShoot;

  /// No description provided for @timelineDone.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get timelineDone;

  /// No description provided for @timelinePayAtShoot.
  ///
  /// In vi, this message translates to:
  /// **'Trả {amount} tại chỗ'**
  String timelinePayAtShoot(String amount);

  /// No description provided for @timelineReview.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá & chia sẻ ảnh'**
  String get timelineReview;

  /// No description provided for @timelineDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get timelineDeclined;

  /// No description provided for @timelineExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn, đã hoàn cọc'**
  String get timelineExpired;

  /// No description provided for @timelineCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ · hoàn {amount}'**
  String timelineCancelled(String amount);

  /// No description provided for @countdownHours.
  ///
  /// In vi, this message translates to:
  /// **'{n} giờ'**
  String countdownHours(int n);

  /// No description provided for @countdownMinutes.
  ///
  /// In vi, this message translates to:
  /// **'{n} phút'**
  String countdownMinutes(int n);

  /// No description provided for @countdownSeconds.
  ///
  /// In vi, this message translates to:
  /// **'{n} giây'**
  String countdownSeconds(int n);

  /// No description provided for @detailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp #{code}'**
  String detailTitle(String code);

  /// No description provided for @detailPaidToast.
  ///
  /// In vi, this message translates to:
  /// **'Cọc {amount} đang được giữ an toàn. {name} sẽ trả lời trong 24 giờ.'**
  String detailPaidToast(String amount, String name);

  /// No description provided for @escrowNoticeHeldPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Cọc {amount} đang được giữ, chuyển cho bạn sau khi hoàn thành'**
  String escrowNoticeHeldPhotographer(String amount);

  /// No description provided for @detailMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get detailMessage;

  /// No description provided for @detailMore.
  ///
  /// In vi, this message translates to:
  /// **'Thêm thao tác'**
  String get detailMore;

  /// No description provided for @detailReschedule.
  ///
  /// In vi, this message translates to:
  /// **'Đổi lịch'**
  String get detailReschedule;

  /// No description provided for @detailDirections.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ đường'**
  String get detailDirections;

  /// No description provided for @detailCancelCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ yêu cầu · hoàn cọc {pct}%'**
  String detailCancelCustomer(int pct);

  /// No description provided for @detailCancelPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ buổi chụp'**
  String get detailCancelPhotographer;

  /// No description provided for @detailAccept.
  ///
  /// In vi, this message translates to:
  /// **'Nhận · còn {time}'**
  String detailAccept(String time);

  /// No description provided for @detailAcceptNow.
  ///
  /// In vi, this message translates to:
  /// **'Nhận'**
  String get detailAcceptNow;

  /// No description provided for @detailDecline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get detailDecline;

  /// No description provided for @detailComplete.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get detailComplete;

  /// No description provided for @detailBookAgain.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get detailBookAgain;

  /// No description provided for @detailReview.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get detailReview;

  /// No description provided for @detailViewReview.
  ///
  /// In vi, this message translates to:
  /// **'Xem đánh giá'**
  String get detailViewReview;

  /// No description provided for @detailNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy buổi chụp'**
  String get detailNotFound;

  /// No description provided for @detailNotFoundBody.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp này không còn hoặc không thuộc tài khoản của bạn.'**
  String get detailNotFoundBody;

  /// No description provided for @detailGoHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get detailGoHome;

  /// No description provided for @detailYou.
  ///
  /// In vi, this message translates to:
  /// **'bạn'**
  String get detailYou;

  /// No description provided for @detailErrorExpired.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã hết hạn'**
  String get detailErrorExpired;

  /// No description provided for @detailErrorNotEligible.
  ///
  /// In vi, this message translates to:
  /// **'Không còn thực hiện được thao tác này'**
  String get detailErrorNotEligible;

  /// No description provided for @detailErrorConflict.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp vừa thay đổi, đã tải lại'**
  String get detailErrorConflict;

  /// No description provided for @detailErrorNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được. Thử lại nhé.'**
  String get detailErrorNetwork;

  /// No description provided for @cancelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ buổi chụp?'**
  String get cancelTitle;

  /// No description provided for @cancelTitlePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ buổi chụp với {name}?'**
  String cancelTitlePhotographer(String name);

  /// No description provided for @cancelKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lịch'**
  String get cancelKeep;

  /// No description provided for @cancelConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ buổi chụp'**
  String get cancelConfirm;

  /// No description provided for @declineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối yêu cầu của {name}?'**
  String declineTitle(String name);

  /// No description provided for @declineBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get declineBack;

  /// No description provided for @declineConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get declineConfirm;

  /// No description provided for @cancelRow100.
  ///
  /// In vi, this message translates to:
  /// **'Trước {when} hơn 48 giờ'**
  String cancelRow100(String when);

  /// No description provided for @cancelRow50.
  ///
  /// In vi, this message translates to:
  /// **'Trong 24–48 giờ'**
  String get cancelRow50;

  /// No description provided for @cancelRow0.
  ///
  /// In vi, this message translates to:
  /// **'Dưới 24 giờ'**
  String get cancelRow0;

  /// No description provided for @cancelRefund100.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn 100%'**
  String get cancelRefund100;

  /// No description provided for @cancelRefund50.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn 50%'**
  String get cancelRefund50;

  /// No description provided for @cancelRefund0.
  ///
  /// In vi, this message translates to:
  /// **'Không hoàn'**
  String get cancelRefund0;

  /// No description provided for @cancelYouGetBack.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ nhận lại'**
  String get cancelYouGetBack;

  /// No description provided for @cancelReasonPlans.
  ///
  /// In vi, this message translates to:
  /// **'Đổi kế hoạch'**
  String get cancelReasonPlans;

  /// No description provided for @cancelReasonFound.
  ///
  /// In vi, this message translates to:
  /// **'Tìm được thợ khác'**
  String get cancelReasonFound;

  /// No description provided for @cancelReasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khác'**
  String get cancelReasonOther;

  /// No description provided for @cancelRefundPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'{name} được hoàn cọc 100%'**
  String cancelRefundPhotographer(String name);

  /// No description provided for @cancelReasonSick.
  ///
  /// In vi, this message translates to:
  /// **'Ốm/việc gấp'**
  String get cancelReasonSick;

  /// No description provided for @cancelReasonGear.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị gặp sự cố'**
  String get cancelReasonGear;

  /// No description provided for @cancelDoneToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ. Hoàn {amount} trong 3–5 ngày'**
  String cancelDoneToast(String amount);

  /// No description provided for @cancelDoneNoRefund.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ buổi chụp'**
  String get cancelDoneNoRefund;

  /// No description provided for @cancelDonePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ. {name} được hoàn cọc 100%'**
  String cancelDonePhotographer(String name);

  /// No description provided for @bookingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get bookingsTitle;

  /// No description provided for @bookingsUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Sắp tới'**
  String get bookingsUpcoming;

  /// No description provided for @bookingsPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ'**
  String get bookingsPending;

  /// No description provided for @bookingsDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã xong'**
  String get bookingsDone;

  /// No description provided for @bookingsReview.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get bookingsReview;

  /// No description provided for @bookingsDirections.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ đường'**
  String get bookingsDirections;

  /// No description provided for @bookingsMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get bookingsMessage;

  /// No description provided for @bookingsChats.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get bookingsChats;

  /// No description provided for @bookingsEmptyUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có buổi chụp sắp tới'**
  String get bookingsEmptyUpcoming;

  /// No description provided for @bookingsEmptyUpcomingBody.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp đã được nhận sẽ hiện ở đây.'**
  String get bookingsEmptyUpcomingBody;

  /// No description provided for @bookingsFindPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhiếp ảnh gia'**
  String get bookingsFindPhotographer;

  /// No description provided for @bookingsEmptyPending.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu chờ'**
  String get bookingsEmptyPending;

  /// No description provided for @bookingsEmptyPendingBody.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã đặt cọc, đang chờ nhiếp ảnh gia nhận sẽ hiện ở đây.'**
  String get bookingsEmptyPendingBody;

  /// No description provided for @bookingsEmptyDone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có buổi nào xong'**
  String get bookingsEmptyDone;

  /// No description provided for @bookingsEmptyDoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp đã hoàn thành, đã huỷ hoặc bị từ chối sẽ hiện ở đây.'**
  String get bookingsEmptyDoneBody;

  /// No description provided for @workTitle.
  ///
  /// In vi, this message translates to:
  /// **'Công việc'**
  String get workTitle;

  /// No description provided for @workDateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thứ {weekday}, {date}'**
  String workDateTitle(int weekday, String date);

  /// No description provided for @workDateTitleSunday.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhật, {date}'**
  String workDateTitleSunday(String date);

  /// No description provided for @workToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get workToday;

  /// No description provided for @workRequests.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu mới'**
  String get workRequests;

  /// No description provided for @workAccept.
  ///
  /// In vi, this message translates to:
  /// **'Nhận'**
  String get workAccept;

  /// No description provided for @workAcceptIn.
  ///
  /// In vi, this message translates to:
  /// **'Nhận · còn {time}'**
  String workAcceptIn(String time);

  /// No description provided for @workDecline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get workDecline;

  /// No description provided for @workMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get workMessage;

  /// No description provided for @workDirections.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ đường'**
  String get workDirections;

  /// No description provided for @workMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng này'**
  String get workMonth;

  /// No description provided for @workHeld.
  ///
  /// In vi, this message translates to:
  /// **'Đang giữ'**
  String get workHeld;

  /// No description provided for @workUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Buổi sắp tới'**
  String get workUpcoming;

  /// No description provided for @workNoRequests.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu mới'**
  String get workNoRequests;

  /// No description provided for @workRequestMeta.
  ///
  /// In vi, this message translates to:
  /// **'{service} · {when} · {place}'**
  String workRequestMeta(String service, String when, String place);

  /// No description provided for @workDepositPaid.
  ///
  /// In vi, this message translates to:
  /// **'đã cọc {amount}'**
  String workDepositPaid(String amount);

  /// No description provided for @workRequestNote.
  ///
  /// In vi, this message translates to:
  /// **'“{note}” · {deposit}'**
  String workRequestNote(String note, String deposit);

  /// No description provided for @workRequestExpired.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu {name} đã hết hạn, đã hoàn cọc'**
  String workRequestExpired(String name);

  /// No description provided for @workEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp tiếp theo bắt đầu từ đây'**
  String get workEmptyTitle;

  /// No description provided for @workEmptyBodyPortfolio.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ có 6 ảnh và 1 gói được đặt nhiều gấp 3 lần. Bạn đang có {n} ảnh.'**
  String workEmptyBodyPortfolio(int n);

  /// No description provided for @workEmptyAddPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh vào portfolio'**
  String get workEmptyAddPhotos;

  /// No description provided for @workEmptyBodyPackage.
  ///
  /// In vi, this message translates to:
  /// **'Khách đặt lịch theo gói. Thêm một gói để nhận yêu cầu đầu tiên.'**
  String get workEmptyBodyPackage;

  /// No description provided for @workEmptyAddPackage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm gói'**
  String get workEmptyAddPackage;

  /// No description provided for @workEmptyBodySkills.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ năng càng đầy đủ, hồ sơ càng được gợi ý cho đúng khách.'**
  String get workEmptyBodySkills;

  /// No description provided for @workEmptySkills.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thiện kỹ năng'**
  String get workEmptySkills;

  /// No description provided for @workEmptyBodyShare.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ đã sẵn sàng. Chia sẻ để khách quen tìm và đặt bạn.'**
  String get workEmptyBodyShare;

  /// No description provided for @workEmptyShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ hồ sơ'**
  String get workEmptyShare;

  /// No description provided for @declineReasonBusy.
  ///
  /// In vi, this message translates to:
  /// **'Kín lịch hôm đó'**
  String get declineReasonBusy;

  /// No description provided for @declineReasonArea.
  ///
  /// In vi, this message translates to:
  /// **'Ngoài khu vực phục vụ'**
  String get declineReasonArea;

  /// No description provided for @declineReasonService.
  ///
  /// In vi, this message translates to:
  /// **'Gói không phù hợp nhu cầu'**
  String get declineReasonService;

  /// No description provided for @declineReasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khác'**
  String get declineReasonOther;

  /// No description provided for @declineRefundNote.
  ///
  /// In vi, this message translates to:
  /// **'{name} được hoàn cọc {amount} và nhận lý do này.'**
  String declineRefundNote(String name, String amount);

  /// No description provided for @declineDoneToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối. {name} được hoàn cọc.'**
  String declineDoneToast(String name);

  /// No description provided for @chatInput.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tin nhắn…'**
  String get chatInput;

  /// No description provided for @chatSendLocation.
  ///
  /// In vi, this message translates to:
  /// **'Gửi vị trí'**
  String get chatSendLocation;

  /// No description provided for @chatSendRef.
  ///
  /// In vi, this message translates to:
  /// **'Gửi ảnh tham khảo'**
  String get chatSendRef;

  /// No description provided for @chatReschedule.
  ///
  /// In vi, this message translates to:
  /// **'Đổi lịch'**
  String get chatReschedule;

  /// No description provided for @chatConfirmPlace.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận địa điểm'**
  String get chatConfirmPlace;

  /// No description provided for @chatConfirmPlaceText.
  ///
  /// In vi, this message translates to:
  /// **'Chốt địa điểm: {place}'**
  String chatConfirmPlaceText(String place);

  /// No description provided for @chatSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại'**
  String get chatSendFailed;

  /// No description provided for @chatInquiryCap.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã gửi 3 tin. Chờ {name} trả lời để nhắn tiếp.'**
  String chatInquiryCap(String name);

  /// No description provided for @chatReadOnly.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc trò chuyện chỉ còn để đọc.'**
  String get chatReadOnly;

  /// No description provided for @chatClosed.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc trò chuyện đã đóng. Gửi tin để mở lại.'**
  String get chatClosed;

  /// No description provided for @chatOffline.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết nối. Bạn vẫn xem được tin cũ.'**
  String get chatOffline;

  /// No description provided for @chatLocationOf.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí của {name}'**
  String chatLocationOf(String name);

  /// No description provided for @chatLocationDenied.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lấy vị trí. Vui lòng cấp quyền vị trí.'**
  String get chatLocationDenied;

  /// No description provided for @chatSysRequested.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt cọc. Chờ nhiếp ảnh gia nhận trong 24 giờ.'**
  String get chatSysRequested;

  /// No description provided for @chatSysAccepted.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia đã nhận buổi chụp.'**
  String get chatSysAccepted;

  /// No description provided for @chatSysDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia đã từ chối yêu cầu.'**
  String get chatSysDeclined;

  /// No description provided for @chatSysExpired.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã hết hạn.'**
  String get chatSysExpired;

  /// No description provided for @chatSysCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp đã huỷ.'**
  String get chatSysCancelled;

  /// No description provided for @chatSysCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp đã hoàn thành.'**
  String get chatSysCompleted;

  /// No description provided for @chatRescheduleProposal.
  ///
  /// In vi, this message translates to:
  /// **'Đề nghị đổi sang {day} {start}–{end}'**
  String chatRescheduleProposal(String day, String start, String end);

  /// No description provided for @chatRescheduleAccept.
  ///
  /// In vi, this message translates to:
  /// **'Chấp nhận'**
  String get chatRescheduleAccept;

  /// No description provided for @chatRescheduleDecline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get chatRescheduleDecline;

  /// No description provided for @chatRescheduleDeclineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối đề nghị đổi lịch?'**
  String get chatRescheduleDeclineTitle;

  /// No description provided for @chatRescheduleAccepted.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi lịch thành công'**
  String get chatRescheduleAccepted;

  /// No description provided for @chatRescheduleDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối đổi lịch'**
  String get chatRescheduleDeclined;

  /// No description provided for @chatRescheduleExpired.
  ///
  /// In vi, this message translates to:
  /// **'Đề nghị đổi lịch đã hết hạn'**
  String get chatRescheduleExpired;

  /// No description provided for @chatDayTaken.
  ///
  /// In vi, this message translates to:
  /// **'Ngày này đã kín'**
  String get chatDayTaken;

  /// No description provided for @chatViewBooking.
  ///
  /// In vi, this message translates to:
  /// **'Xem buổi chụp'**
  String get chatViewBooking;

  /// No description provided for @chatPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh'**
  String get chatPhoto;

  /// No description provided for @chatLocation.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí'**
  String get chatLocation;

  /// No description provided for @chatsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get chatsTitle;

  /// No description provided for @chatsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có cuộc trò chuyện nào'**
  String get chatsEmptyTitle;

  /// No description provided for @chatsEmptyAction.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhiếp ảnh gia'**
  String get chatsEmptyAction;

  /// No description provided for @inquiryNotEligible.
  ///
  /// In vi, this message translates to:
  /// **'{name} chưa nhận tin hỏi trước'**
  String inquiryNotEligible(String name);

  /// No description provided for @providerArtist.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia'**
  String get providerArtist;

  /// No description provided for @providerStudio.
  ///
  /// In vi, this message translates to:
  /// **'Studio'**
  String get providerStudio;

  /// No description provided for @providerArtistMark.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia đã duyệt'**
  String get providerArtistMark;

  /// No description provided for @providerStudioMark.
  ///
  /// In vi, this message translates to:
  /// **'Studio đã xác minh'**
  String get providerStudioMark;

  /// No description provided for @providerArtistAwards.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia · {n} giải'**
  String providerArtistAwards(int n);

  /// No description provided for @providerAwardsCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} giải'**
  String providerAwardsCount(int n);

  /// No description provided for @providerStudioDistrict.
  ///
  /// In vi, this message translates to:
  /// **'Studio · {district}'**
  String providerStudioDistrict(String district);

  /// No description provided for @albumEmptyNote.
  ///
  /// In vi, this message translates to:
  /// **'Trống · chưa hiện công khai'**
  String get albumEmptyNote;

  /// No description provided for @portfolioViewAlbums.
  ///
  /// In vi, this message translates to:
  /// **'Album'**
  String get portfolioViewAlbums;

  /// No description provided for @portfolioViewTimeline.
  ///
  /// In vi, this message translates to:
  /// **'Dòng thời gian'**
  String get portfolioViewTimeline;

  /// No description provided for @reorderPosition.
  ///
  /// In vi, this message translates to:
  /// **'{index} trên {count}'**
  String reorderPosition(int index, int count);

  /// No description provided for @reorderMoveUp.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển lên'**
  String get reorderMoveUp;

  /// No description provided for @reorderMoveDown.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển xuống'**
  String get reorderMoveDown;

  /// No description provided for @reorderMoveTop.
  ///
  /// In vi, this message translates to:
  /// **'Lên đầu'**
  String get reorderMoveTop;

  /// No description provided for @reorderMoveBottom.
  ///
  /// In vi, this message translates to:
  /// **'Xuống cuối'**
  String get reorderMoveBottom;

  /// No description provided for @reorderMenu.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác với mục này'**
  String get reorderMenu;

  /// No description provided for @reorderHandle.
  ///
  /// In vi, this message translates to:
  /// **'Giữ để kéo sắp xếp'**
  String get reorderHandle;

  /// No description provided for @postPickSelectedOrder.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn, thứ {n}'**
  String postPickSelectedOrder(int n);

  /// No description provided for @postPickPosition.
  ///
  /// In vi, this message translates to:
  /// **'Bài {index} trên {count}'**
  String postPickPosition(int index, int count);

  /// No description provided for @albumPhotoCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} ảnh'**
  String albumPhotoCount(int n);

  /// No description provided for @postPickInAlbum.
  ///
  /// In vi, this message translates to:
  /// **'Đang ở album {album}'**
  String postPickInAlbum(String album);

  /// No description provided for @awardResultGold.
  ///
  /// In vi, this message translates to:
  /// **'Huy chương Vàng'**
  String get awardResultGold;

  /// No description provided for @awardResultSilver.
  ///
  /// In vi, this message translates to:
  /// **'Huy chương Bạc'**
  String get awardResultSilver;

  /// No description provided for @awardResultBronze.
  ///
  /// In vi, this message translates to:
  /// **'Huy chương Đồng'**
  String get awardResultBronze;

  /// No description provided for @awardResultHonorable.
  ///
  /// In vi, this message translates to:
  /// **'Giải Khuyến khích'**
  String get awardResultHonorable;

  /// No description provided for @awardResultFinalist.
  ///
  /// In vi, this message translates to:
  /// **'Top / Chung kết'**
  String get awardResultFinalist;

  /// No description provided for @awardResultExhibited.
  ///
  /// In vi, this message translates to:
  /// **'Chọn triển lãm'**
  String get awardResultExhibited;

  /// No description provided for @awardShortGold.
  ///
  /// In vi, this message translates to:
  /// **'Vàng / Nhất'**
  String get awardShortGold;

  /// No description provided for @awardShortSilver.
  ///
  /// In vi, this message translates to:
  /// **'Bạc / Nhì'**
  String get awardShortSilver;

  /// No description provided for @awardShortBronze.
  ///
  /// In vi, this message translates to:
  /// **'Đồng / Ba'**
  String get awardShortBronze;

  /// No description provided for @awardShortHonorable.
  ///
  /// In vi, this message translates to:
  /// **'Khuyến khích'**
  String get awardShortHonorable;

  /// No description provided for @awardShortFinalist.
  ///
  /// In vi, this message translates to:
  /// **'Top / Chung kết'**
  String get awardShortFinalist;

  /// No description provided for @awardShortExhibited.
  ///
  /// In vi, this message translates to:
  /// **'Chọn triển lãm'**
  String get awardShortExhibited;

  /// No description provided for @awardPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get awardPending;

  /// No description provided for @awardApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get awardApproved;

  /// No description provided for @awardNeedsInfo.
  ///
  /// In vi, this message translates to:
  /// **'Bổ sung'**
  String get awardNeedsInfo;

  /// No description provided for @awardRejected.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get awardRejected;

  /// No description provided for @awardRevoked.
  ///
  /// In vi, this message translates to:
  /// **'Đã thu hồi'**
  String get awardRevoked;

  /// No description provided for @awardChipSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Giải thưởng: {title}, {subtitle}'**
  String awardChipSemantics(String title, String subtitle);

  /// No description provided for @awardRowSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Giải thưởng: {title}, {subtitle}, trạng thái {status}'**
  String awardRowSemantics(String title, String subtitle, String status);

  /// No description provided for @reviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp thế nào?'**
  String get reviewTitle;

  /// No description provided for @reviewText.
  ///
  /// In vi, this message translates to:
  /// **'Nhận xét'**
  String get reviewText;

  /// No description provided for @reviewTextHint.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ cảm nhận của bạn về buổi chụp...'**
  String get reviewTextHint;

  /// No description provided for @reviewTextTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Viết ít nhất 10 ký tự'**
  String get reviewTextTooShort;

  /// No description provided for @reviewShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ ảnh bạn thích'**
  String get reviewShare;

  /// No description provided for @reviewOptional.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chọn'**
  String get reviewOptional;

  /// No description provided for @reviewShareHint.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh hiện trong \'Buổi chụp thật\' trên Trang chủ và hồ sơ {name}, có tag nhiếp ảnh gia'**
  String reviewShareHint(String name);

  /// No description provided for @reviewOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ đánh giá'**
  String get reviewOnly;

  /// No description provided for @reviewSubmitShare.
  ///
  /// In vi, this message translates to:
  /// **'Gửi & chia sẻ {count} ảnh'**
  String reviewSubmitShare(int count);

  /// No description provided for @reviewSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi đánh giá'**
  String get reviewSubmit;

  /// No description provided for @reviewNotYet.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp chưa hoàn thành nên chưa đánh giá được.'**
  String get reviewNotYet;

  /// No description provided for @reviewThanks.
  ///
  /// In vi, this message translates to:
  /// **'Cảm ơn bạn đã đánh giá!'**
  String get reviewThanks;

  /// No description provided for @reviewStarsSemantics.
  ///
  /// In vi, this message translates to:
  /// **'{rating} trên 5 sao'**
  String reviewStarsSemantics(int rating);

  /// No description provided for @reviewUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh lỗi. Thử lại'**
  String get reviewUploadFailed;

  /// No description provided for @reviewsHeader.
  ///
  /// In vi, this message translates to:
  /// **'{rating} · {count} đánh giá'**
  String reviewsHeader(String rating, int count);

  /// No description provided for @reviewsMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm'**
  String get reviewsMore;

  /// No description provided for @reviewSharedLink.
  ///
  /// In vi, this message translates to:
  /// **'Xem ảnh đã chia sẻ'**
  String get reviewSharedLink;

  /// No description provided for @reviewAlreadyDone.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đánh giá buổi chụp này.'**
  String get reviewAlreadyDone;

  /// No description provided for @reviewsAnonymousName.
  ///
  /// In vi, this message translates to:
  /// **'Khách hàng'**
  String get reviewsAnonymousName;

  /// No description provided for @reviewThumbLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh buổi chụp'**
  String get reviewThumbLabel;

  /// No description provided for @reviewErrorForbidden.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không thể đánh giá buổi chụp này.'**
  String get reviewErrorForbidden;

  /// No description provided for @reviewPhotoUploading.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {index} đang tải lên, {percent}%'**
  String reviewPhotoUploading(int index, int percent);

  /// No description provided for @setupTypeHeading.
  ///
  /// In vi, this message translates to:
  /// **'Bạn nhận việc với tư cách'**
  String get setupTypeHeading;

  /// No description provided for @setupTypeIndividual.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get setupTypeIndividual;

  /// No description provided for @setupTypeIndividualBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn tự chụp và nhận booking. Có giải thưởng? Thêm sau để lên hạng Nhiếp ảnh gia (NAG).'**
  String get setupTypeIndividualBody;

  /// No description provided for @setupTypeStudio.
  ///
  /// In vi, this message translates to:
  /// **'Studio'**
  String get setupTypeStudio;

  /// No description provided for @setupTypeStudioBody.
  ///
  /// In vi, this message translates to:
  /// **'Cơ sở kinh doanh chụp ảnh, có địa chỉ. Thêm thành viên: sắp có.'**
  String get setupTypeStudioBody;

  /// No description provided for @setupTypeNote.
  ///
  /// In vi, this message translates to:
  /// **'Đổi Cá nhân ↔ Studio được trong Cài đặt khi không còn booking đang chạy.'**
  String get setupTypeNote;

  /// No description provided for @setupStudioName.
  ///
  /// In vi, this message translates to:
  /// **'Tên studio'**
  String get setupStudioName;

  /// No description provided for @setupStudioAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ cơ sở'**
  String get setupStudioAddress;

  /// No description provided for @setupStudioLine.
  ///
  /// In vi, this message translates to:
  /// **'Số nhà, đường'**
  String get setupStudioLine;

  /// No description provided for @setupStudioWard.
  ///
  /// In vi, this message translates to:
  /// **'Phường / xã'**
  String get setupStudioWard;

  /// No description provided for @setupStudioDistrict.
  ///
  /// In vi, this message translates to:
  /// **'Quận / huyện'**
  String get setupStudioDistrict;

  /// No description provided for @setupStudioCity.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh / thành phố'**
  String get setupStudioCity;

  /// No description provided for @setupStudioLineError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số nhà, đường (ít nhất 5 ký tự).'**
  String get setupStudioLineError;

  /// No description provided for @setupStudioWardError.
  ///
  /// In vi, this message translates to:
  /// **'Phường / xã tối đa 60 ký tự.'**
  String get setupStudioWardError;

  /// No description provided for @setupStudioDistrictError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập quận / huyện.'**
  String get setupStudioDistrictError;

  /// No description provided for @setupStudioCityError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tỉnh / thành phố.'**
  String get setupStudioCityError;

  /// No description provided for @setupStudioAddressNote.
  ///
  /// In vi, this message translates to:
  /// **'Khách chỉ thấy tới quận; địa chỉ đầy đủ hiện sau khi đã đặt.'**
  String get setupStudioAddressNote;

  /// No description provided for @providerNotEligible.
  ///
  /// In vi, this message translates to:
  /// **'Còn booking chưa xong hoặc tiền đang giữ. Hoàn tất chúng trước khi đổi.'**
  String get providerNotEligible;

  /// No description provided for @settingsProviderType.
  ///
  /// In vi, this message translates to:
  /// **'Hình thức nhận việc'**
  String get settingsProviderType;

  /// No description provided for @settingsProviderArtist.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân · Nhiếp ảnh gia'**
  String get settingsProviderArtist;

  /// No description provided for @providerTypeSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get providerTypeSave;

  /// No description provided for @providerTypeKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ nguyên'**
  String get providerTypeKeep;

  /// No description provided for @providerLoseArtistBody.
  ///
  /// In vi, this message translates to:
  /// **'Đổi sang Studio sẽ bỏ hạng Nhiếp ảnh gia. Giải thưởng vẫn giữ.'**
  String get providerLoseArtistBody;

  /// No description provided for @providerLoseArtistConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Đổi sang Studio'**
  String get providerLoseArtistConfirm;

  /// No description provided for @createAlbumLabel.
  ///
  /// In vi, this message translates to:
  /// **'Album · tuỳ chọn'**
  String get createAlbumLabel;

  /// No description provided for @albumPickTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xếp vào album'**
  String get albumPickTitle;

  /// No description provided for @albumPickNone.
  ///
  /// In vi, this message translates to:
  /// **'Không xếp album'**
  String get albumPickNone;

  /// No description provided for @albumPickNoneSub.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ hiện ở Dòng thời gian'**
  String get albumPickNoneSub;

  /// No description provided for @albumPickCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} bài'**
  String albumPickCount(int n);

  /// No description provided for @albumPickRecent.
  ///
  /// In vi, this message translates to:
  /// **'dùng gần nhất'**
  String get albumPickRecent;

  /// No description provided for @albumPickNew.
  ///
  /// In vi, this message translates to:
  /// **'Album mới'**
  String get albumPickNew;

  /// No description provided for @albumPickCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo'**
  String get albumPickCreate;

  /// No description provided for @albumPickDup.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã có album tên này'**
  String get albumPickDup;

  /// No description provided for @albumPickLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã có đủ 30 album.'**
  String get albumPickLimit;

  /// No description provided for @albumPickCreateError.
  ///
  /// In vi, this message translates to:
  /// **'Không tạo được album. Thử lại sau.'**
  String get albumPickCreateError;

  /// No description provided for @albumPickLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được danh sách album.'**
  String get albumPickLoadError;

  /// No description provided for @portfolioAlbumCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} album'**
  String portfolioAlbumCount(int n);

  /// No description provided for @portfolioArrange.
  ///
  /// In vi, this message translates to:
  /// **'Sắp xếp'**
  String get portfolioArrange;

  /// No description provided for @albumDetailCounts.
  ///
  /// In vi, this message translates to:
  /// **'{posts} bài · {photos} ảnh'**
  String albumDetailCounts(int posts, int photos);

  /// No description provided for @albumDetailEmptyOwner.
  ///
  /// In vi, this message translates to:
  /// **'Album chưa có bài'**
  String get albumDetailEmptyOwner;

  /// No description provided for @albumDetailEmptyOwnerBody.
  ///
  /// In vi, this message translates to:
  /// **'Thêm bài để album hiện trên hồ sơ của bạn.'**
  String get albumDetailEmptyOwnerBody;

  /// No description provided for @albumDetailAddPosts.
  ///
  /// In vi, this message translates to:
  /// **'Thêm bài'**
  String get albumDetailAddPosts;

  /// No description provided for @albumDetailGone.
  ///
  /// In vi, this message translates to:
  /// **'Album này không còn'**
  String get albumDetailGone;

  /// No description provided for @albumDetailGoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Album có thể đã bị xoá hoặc chưa có bài nào.'**
  String get albumDetailGoneBody;

  /// No description provided for @albumDetailShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ album'**
  String get albumDetailShare;

  /// No description provided for @albumDetailLinkCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết album'**
  String get albumDetailLinkCopied;

  /// No description provided for @albumDetailMenu.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chọn album'**
  String get albumDetailMenu;

  /// No description provided for @albumDetailArrange.
  ///
  /// In vi, this message translates to:
  /// **'Sắp xếp bài'**
  String get albumDetailArrange;

  /// No description provided for @albumDetailArrangeDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get albumDetailArrangeDone;

  /// No description provided for @albumDetailRemove.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ khỏi album'**
  String get albumDetailRemove;

  /// No description provided for @albumDetailRemoveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa bỏ được bài khỏi album.'**
  String get albumDetailRemoveFailed;

  /// No description provided for @albumDetailDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá album'**
  String get albumDetailDelete;

  /// No description provided for @albumDetailDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá album này?'**
  String get albumDetailDeleteTitle;

  /// No description provided for @albumDetailDeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Bài trong album không bị xoá, chuyển về Chưa xếp album.'**
  String get albumDetailDeleteBody;

  /// No description provided for @albumDetailDeleteError.
  ///
  /// In vi, this message translates to:
  /// **'Không xoá được album. Thử lại sau.'**
  String get albumDetailDeleteError;

  /// No description provided for @albumDetailReordered.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi thứ tự'**
  String get albumDetailReordered;

  /// No description provided for @albumDetailReorderFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa lưu được thứ tự'**
  String get albumDetailReorderFailed;

  /// No description provided for @albumDetailUndo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get albumDetailUndo;

  /// No description provided for @albumDetailArrangeLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải hết bài để sắp xếp. Thử lại sau.'**
  String get albumDetailArrangeLoadFailed;

  /// No description provided for @profileMyAlbums.
  ///
  /// In vi, this message translates to:
  /// **'Album của tôi'**
  String get profileMyAlbums;

  /// No description provided for @profileMyAlbumsSub.
  ///
  /// In vi, this message translates to:
  /// **'Gom bài thành album, sắp xếp thứ tự trên hồ sơ'**
  String get profileMyAlbumsSub;

  /// No description provided for @myAlbumsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Album của tôi'**
  String get myAlbumsTitle;

  /// No description provided for @myAlbumsHint.
  ///
  /// In vi, this message translates to:
  /// **'Thứ tự dưới đây là thứ tự trên hồ sơ. Giữ ≡ rồi kéo, hoặc chạm … → Chuyển lên / xuống.'**
  String get myAlbumsHint;

  /// No description provided for @myAlbumsFeatured.
  ///
  /// In vi, this message translates to:
  /// **'hiện rộng'**
  String get myAlbumsFeatured;

  /// No description provided for @myAlbumsUnsorted.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xếp album'**
  String get myAlbumsUnsorted;

  /// No description provided for @myAlbumsUnsortedSub.
  ///
  /// In vi, this message translates to:
  /// **'{n} bài · chỉ ở Dòng thời gian'**
  String myAlbumsUnsortedSub(String n);

  /// No description provided for @myAlbumsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gom bài thành album để khách xem theo bộ'**
  String get myAlbumsEmptyTitle;

  /// No description provided for @myAlbumsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Bài chưa xếp album vẫn hiện ở Dòng thời gian.'**
  String get myAlbumsEmptyBody;

  /// No description provided for @myAlbumsOpen.
  ///
  /// In vi, this message translates to:
  /// **'Xem album'**
  String get myAlbumsOpen;

  /// No description provided for @myAlbumsEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa'**
  String get myAlbumsEdit;

  /// No description provided for @albumEditNew.
  ///
  /// In vi, this message translates to:
  /// **'Album mới'**
  String get albumEditNew;

  /// No description provided for @albumEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa album'**
  String get albumEditTitle;

  /// No description provided for @albumEditClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get albumEditClose;

  /// No description provided for @albumEditName.
  ///
  /// In vi, this message translates to:
  /// **'Tên album · bắt buộc'**
  String get albumEditName;

  /// No description provided for @albumEditNameCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} / {max}'**
  String albumEditNameCount(int n, int max);

  /// No description provided for @albumEditNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên album'**
  String get albumEditNameRequired;

  /// No description provided for @albumEditDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả · tuỳ chọn'**
  String get albumEditDesc;

  /// No description provided for @albumEditCover.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh bìa'**
  String get albumEditCover;

  /// No description provided for @albumEditCoverAuto.
  ///
  /// In vi, this message translates to:
  /// **'Tự động: ảnh đầu tiên của album'**
  String get albumEditCoverAuto;

  /// No description provided for @albumEditCoverChosen.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn một ảnh làm bìa'**
  String get albumEditCoverChosen;

  /// No description provided for @albumEditCoverPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh'**
  String get albumEditCoverPick;

  /// No description provided for @albumEditCoverTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh bìa'**
  String get albumEditCoverTitle;

  /// No description provided for @albumEditCoverReset.
  ///
  /// In vi, this message translates to:
  /// **'Dùng ảnh tự động'**
  String get albumEditCoverReset;

  /// No description provided for @albumEditCoverLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh của album.'**
  String get albumEditCoverLoadError;

  /// No description provided for @albumEditCoverTile.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {index} trên {count}'**
  String albumEditCoverTile(int index, int count);

  /// No description provided for @albumEditNote.
  ///
  /// In vi, this message translates to:
  /// **'Album trống chưa hiện trên hồ sơ. Thêm bài ngay sau khi tạo.'**
  String get albumEditNote;

  /// No description provided for @albumEditCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo và thêm bài'**
  String get albumEditCreate;

  /// No description provided for @albumEditSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get albumEditSave;

  /// No description provided for @albumEditSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa lưu được album. Thử lại sau.'**
  String get albumEditSaveError;

  /// No description provided for @albumEditDiscardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi?'**
  String get albumEditDiscardTitle;

  /// No description provided for @albumEditDiscardBody.
  ///
  /// In vi, this message translates to:
  /// **'Những gì bạn vừa nhập sẽ mất.'**
  String get albumEditDiscardBody;

  /// No description provided for @albumEditDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ'**
  String get albumEditDiscard;

  /// No description provided for @albumEditKeep.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục sửa'**
  String get albumEditKeep;

  /// No description provided for @addPostsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm bài vào album'**
  String get addPostsTitle;

  /// No description provided for @addPostsSelected.
  ///
  /// In vi, this message translates to:
  /// **'{n} đã chọn'**
  String addPostsSelected(int n);

  /// No description provided for @addPostsTabUnsorted.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xếp · {n}'**
  String addPostsTabUnsorted(String n);

  /// No description provided for @addPostsTabAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả bài · {n}'**
  String addPostsTabAll(String n);

  /// No description provided for @addPostsMoveWarn.
  ///
  /// In vi, this message translates to:
  /// **'{n} bài đang ở \"{album}\" sẽ chuyển sang album này.'**
  String addPostsMoveWarn(int n, String album);

  /// No description provided for @addPostsMoveWarnMany.
  ///
  /// In vi, this message translates to:
  /// **'{n} bài đang ở album khác sẽ chuyển sang album này.'**
  String addPostsMoveWarnMany(int n);

  /// No description provided for @addPostsAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm {n} bài'**
  String addPostsAdd(int n);

  /// No description provided for @addPostsPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn bài để thêm'**
  String get addPostsPick;

  /// No description provided for @addPostsFull.
  ///
  /// In vi, this message translates to:
  /// **'Album đã đủ 200 bài'**
  String get addPostsFull;

  /// No description provided for @addPostsNoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài trước'**
  String get addPostsNoneTitle;

  /// No description provided for @addPostsNoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Bài bạn đăng sẽ hiện ở đây để xếp vào album.'**
  String get addPostsNoneBody;

  /// No description provided for @addPostsNoneAction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài'**
  String get addPostsNoneAction;

  /// No description provided for @addPostsUnsortedEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Mọi bài của bạn đã nằm trong album.'**
  String get addPostsUnsortedEmpty;

  /// No description provided for @addPostsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bài. Thử lại sau.'**
  String get addPostsLoadError;

  /// No description provided for @addPostsError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thêm được bài. Thử lại sau.'**
  String get addPostsError;

  /// No description provided for @addPostsPartial.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm {done} bài, còn {left} bài chưa thêm được.'**
  String addPostsPartial(int done, int left);

  /// No description provided for @addPostsMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm bài'**
  String get addPostsMore;

  /// No description provided for @myAlbumsUnsortedSubUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Bài chưa xếp · chỉ ở Dòng thời gian'**
  String get myAlbumsUnsortedSubUnknown;

  /// No description provided for @s2501Title.
  ///
  /// In vi, this message translates to:
  /// **'Giải thưởng'**
  String get s2501Title;

  /// No description provided for @s2501Info.
  ///
  /// In vi, this message translates to:
  /// **'Về hạng Nhiếp ảnh gia'**
  String get s2501Info;

  /// No description provided for @s2501InfoBody.
  ///
  /// In vi, this message translates to:
  /// **'Khi có ít nhất 3 giải đã được duyệt, hồ sơ Cá nhân của bạn tự lên hạng Nhiếp ảnh gia và có tích vàng. Hồ sơ Studio vẫn khai giải được nhưng không tính hạng. Nếu số giải đã duyệt xuống dưới 3, hạng quay về Cá nhân. Chỉ giải đã duyệt hiện trên hồ sơ công khai.'**
  String get s2501InfoBody;

  /// No description provided for @s2501InfoClose.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get s2501InfoClose;

  /// No description provided for @s2501Tier.
  ///
  /// In vi, this message translates to:
  /// **'Hạng Nhiếp ảnh gia (NAG)'**
  String get s2501Tier;

  /// No description provided for @s2501Remaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn {n} giải đã duyệt nữa để nhận tích vàng'**
  String s2501Remaining(int n);

  /// No description provided for @s2501IsArtist.
  ///
  /// In vi, this message translates to:
  /// **'Bạn là Nhiếp ảnh gia · từ {date}'**
  String s2501IsArtist(String date);

  /// No description provided for @s2501IsArtistNoDate.
  ///
  /// In vi, this message translates to:
  /// **'Bạn là Nhiếp ảnh gia'**
  String get s2501IsArtistNoDate;

  /// No description provided for @s2501Progress.
  ///
  /// In vi, this message translates to:
  /// **'{a} / {n} giải đã duyệt'**
  String s2501Progress(int a, int n);

  /// No description provided for @s2501Listed.
  ///
  /// In vi, this message translates to:
  /// **'Đã khai · {n} giải'**
  String s2501Listed(int n);

  /// No description provided for @s2501Add.
  ///
  /// In vi, this message translates to:
  /// **'Thêm giải thưởng'**
  String get s2501Add;

  /// No description provided for @s2501EmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giải thưởng giúp khách tin tác phẩm của bạn'**
  String get s2501EmptyTitle;

  /// No description provided for @s2501EmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Khai giải kèm minh chứng. Giải được duyệt sẽ hiện trên hồ sơ của bạn.'**
  String get s2501EmptyBody;

  /// No description provided for @s2501LoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được giải thưởng. Thử lại sau.'**
  String get s2501LoadError;

  /// No description provided for @s2501RowTitle.
  ///
  /// In vi, this message translates to:
  /// **'{result} · {competition} {year}'**
  String s2501RowTitle(String result, String competition, int year);

  /// No description provided for @s2501Sent.
  ///
  /// In vi, this message translates to:
  /// **'gửi {date}'**
  String s2501Sent(String date);

  /// No description provided for @s2501DeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá giải thưởng?'**
  String get s2501DeleteTitle;

  /// No description provided for @s2501DeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Giải và minh chứng đã tải lên sẽ bị xoá.'**
  String get s2501DeleteBody;

  /// No description provided for @s2501Delete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get s2501Delete;

  /// No description provided for @s2501DeleteError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xoá được giải. Thử lại sau.'**
  String get s2501DeleteError;

  /// No description provided for @s2501EditApprovedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa giải đã duyệt?'**
  String get s2501EditApprovedTitle;

  /// No description provided for @s2501EditApprovedBody.
  ///
  /// In vi, this message translates to:
  /// **'Giải sẽ được duyệt lại. Trong lúc chờ, giải ẩn khỏi hồ sơ công khai và không tính vào hạng.'**
  String get s2501EditApprovedBody;

  /// No description provided for @s2501EditApprovedGo.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục sửa'**
  String get s2501EditApprovedGo;

  /// No description provided for @s2502Add.
  ///
  /// In vi, this message translates to:
  /// **'Thêm giải thưởng'**
  String get s2502Add;

  /// No description provided for @s2502Edit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa giải thưởng'**
  String get s2502Edit;

  /// No description provided for @s2502Competition.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc thi / triển lãm · bắt buộc'**
  String get s2502Competition;

  /// No description provided for @s2502CompetitionRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên cuộc thi hoặc triển lãm'**
  String get s2502CompetitionRequired;

  /// No description provided for @s2502Year.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get s2502Year;

  /// No description provided for @s2502YearInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Năm từ 1950 đến {max}'**
  String s2502YearInvalid(int max);

  /// No description provided for @s2502Category.
  ///
  /// In vi, this message translates to:
  /// **'Hạng mục'**
  String get s2502Category;

  /// No description provided for @s2502Result.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả · bắt buộc'**
  String get s2502Result;

  /// No description provided for @s2502Work.
  ///
  /// In vi, this message translates to:
  /// **'Tác phẩm · tuỳ chọn'**
  String get s2502Work;

  /// No description provided for @s2502WorkNone.
  ///
  /// In vi, this message translates to:
  /// **'Không gắn tác phẩm'**
  String get s2502WorkNone;

  /// No description provided for @s2502WorkChosen.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn một tác phẩm'**
  String get s2502WorkChosen;

  /// No description provided for @s2502WorkTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tác phẩm'**
  String get s2502WorkTitle;

  /// No description provided for @s2502WorkClear.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chọn tác phẩm'**
  String get s2502WorkClear;

  /// No description provided for @s2502WorkEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có bài nào để gắn.'**
  String get s2502WorkEmpty;

  /// No description provided for @s2502WorkLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bài của bạn. Thử lại sau.'**
  String get s2502WorkLoadError;

  /// No description provided for @s2502Proof.
  ///
  /// In vi, this message translates to:
  /// **'Minh chứng · bắt buộc'**
  String get s2502Proof;

  /// No description provided for @s2502ProofNone.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh giấy chứng nhận hoặc link trang công bố'**
  String get s2502ProofNone;

  /// No description provided for @s2502ProofSummary.
  ///
  /// In vi, this message translates to:
  /// **'{images} ảnh · {links} link'**
  String s2502ProofSummary(int images, int links);

  /// No description provided for @s2502ProofTitle.
  ///
  /// In vi, this message translates to:
  /// **'Minh chứng'**
  String get s2502ProofTitle;

  /// No description provided for @s2502ProofImages.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh giấy chứng nhận · {n} / {max}'**
  String s2502ProofImages(int n, int max);

  /// No description provided for @s2502ProofAddImage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh'**
  String get s2502ProofAddImage;

  /// No description provided for @s2502ProofLinks.
  ///
  /// In vi, this message translates to:
  /// **'Link trang công bố · tối đa {max}'**
  String s2502ProofLinks(int max);

  /// No description provided for @s2502ProofAddLink.
  ///
  /// In vi, this message translates to:
  /// **'Thêm link'**
  String get s2502ProofAddLink;

  /// No description provided for @s2502LinkLabel.
  ///
  /// In vi, this message translates to:
  /// **'Link'**
  String get s2502LinkLabel;

  /// No description provided for @s2502LinkHttps.
  ///
  /// In vi, this message translates to:
  /// **'Link phải bắt đầu bằng https://'**
  String get s2502LinkHttps;

  /// No description provided for @s2502LinkRemove.
  ///
  /// In vi, this message translates to:
  /// **'Xoá link'**
  String get s2502LinkRemove;

  /// No description provided for @s2502ProofDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get s2502ProofDone;

  /// No description provided for @s2502TileUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải ảnh {n}'**
  String s2502TileUploading(int n);

  /// No description provided for @s2502TileFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải được ảnh {n}. Chạm để thử lại'**
  String s2502TileFailed(int n);

  /// No description provided for @s2502TileDone.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {n} đã tải'**
  String s2502TileDone(int n);

  /// No description provided for @s2502TileSaved.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {n} đã gửi trước đó'**
  String s2502TileSaved(int n);

  /// No description provided for @s2502TileRemove.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ảnh {n}'**
  String s2502TileRemove(int n);

  /// No description provided for @s2502Privacy.
  ///
  /// In vi, this message translates to:
  /// **'Minh chứng chỉ đội duyệt xem và được xoá 30 ngày sau khi duyệt xong. Duyệt trong 3 ngày làm việc.'**
  String get s2502Privacy;

  /// No description provided for @s2502Submit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi duyệt'**
  String get s2502Submit;

  /// No description provided for @s2502SubmitWait.
  ///
  /// In vi, this message translates to:
  /// **'Đợi ảnh tải xong hoặc xoá ảnh lỗi trước khi gửi.'**
  String get s2502SubmitWait;

  /// No description provided for @s2502LoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được giải này. Thử lại sau.'**
  String get s2502LoadError;

  /// No description provided for @s2502SubmitError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa gửi được. Thử lại sau.'**
  String get s2502SubmitError;

  /// No description provided for @s2502SubmitLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã khai tối đa 50 giải.'**
  String get s2502SubmitLimit;

  /// No description provided for @s2502SubmitRejected.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin chưa hợp lệ. Kiểm tra lại các ô.'**
  String get s2502SubmitRejected;

  /// No description provided for @settingsAwards.
  ///
  /// In vi, this message translates to:
  /// **'Giải thưởng'**
  String get settingsAwards;

  /// No description provided for @settingsAwardsBody.
  ///
  /// In vi, this message translates to:
  /// **'Khai giải để lên hạng Nhiếp ảnh gia'**
  String get settingsAwardsBody;

  /// No description provided for @profileAwardNudge.
  ///
  /// In vi, this message translates to:
  /// **'Có giải thưởng? Lên hạng Nhiếp ảnh gia'**
  String get profileAwardNudge;

  /// No description provided for @profileAwardNudgeLater.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get profileAwardNudgeLater;

  /// No description provided for @profileStatAwards.
  ///
  /// In vi, this message translates to:
  /// **'giải thưởng'**
  String get profileStatAwards;

  /// No description provided for @profileAwardSub.
  ///
  /// In vi, this message translates to:
  /// **'{competition} {year}'**
  String profileAwardSub(String competition, int year);

  /// No description provided for @profileAwardSubCategory.
  ///
  /// In vi, this message translates to:
  /// **'{competition} {year} · {category}'**
  String profileAwardSubCategory(String competition, int year, String category);

  /// No description provided for @profileAwardsMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem cả {n} giải'**
  String profileAwardsMore(int n);
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
