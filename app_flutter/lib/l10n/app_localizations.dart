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

  /// No description provided for @settingsMode.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ'**
  String get settingsMode;

  /// No description provided for @settingsButtonGradientShort.
  ///
  /// In vi, this message translates to:
  /// **'Gradient'**
  String get settingsButtonGradientShort;

  /// No description provided for @settingsStudioAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ studio'**
  String get settingsStudioAddress;

  /// No description provided for @settingsStudioAddressEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có địa chỉ'**
  String get settingsStudioAddressEmpty;

  /// No description provided for @settingsVerify.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh & nhận đơn'**
  String get settingsVerify;

  /// No description provided for @settingsVerifyBody.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh danh tính để bắt đầu nhận đơn'**
  String get settingsVerifyBody;

  /// No description provided for @settingsMyStudio.
  ///
  /// In vi, this message translates to:
  /// **'Studio của tôi'**
  String get settingsMyStudio;

  /// No description provided for @settingsMyStudioBody.
  ///
  /// In vi, this message translates to:
  /// **'Studio đang ở, việc được giao, lời mời'**
  String get settingsMyStudioBody;

  /// No description provided for @settingsStudioMembers.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên studio'**
  String get settingsStudioMembers;

  /// No description provided for @settingsStudioMembersBody.
  ///
  /// In vi, this message translates to:
  /// **'Mời thợ, giao việc cho thành viên'**
  String get settingsStudioMembersBody;

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

  /// S09.01 counts row: label under the number of the user's own posts.
  ///
  /// In vi, this message translates to:
  /// **'bài đăng'**
  String get profilePostsCount;

  /// S09.01 counts row: shown only once S19 exists (savedListsReadyProvider).
  ///
  /// In vi, this message translates to:
  /// **'đang theo dõi'**
  String get profileFollowingCount;

  /// S09.01 counts row: shown only once S19 exists (savedListsReadyProvider).
  ///
  /// In vi, this message translates to:
  /// **'đã lưu'**
  String get profileSavedCount;

  /// S09.01 kind chip: all of the user's posts.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả · {n}'**
  String profileFilterAll(int n);

  /// S09.01 kind chip: work posts.
  ///
  /// In vi, this message translates to:
  /// **'Tác phẩm · {n}'**
  String profileFilterWork(int n);

  /// S09.01 kind chip: photos shared after a real shoot.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp · {n}'**
  String profileFilterRealShoot(int n);

  /// S09.01 kind chip: event shares.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện · {n}'**
  String profileFilterEventShare(int n);

  /// S09.01 corner tag on a real-shoot tile under "Tất cả".
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp'**
  String get profileTagRealShoot;

  /// S09.01 corner tag on an event-share tile under "Tất cả".
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get profileTagEventShare;

  /// No description provided for @profileEmptyPhotographerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài đăng'**
  String get profileEmptyPhotographerTitle;

  /// No description provided for @profileEmptyPhotographerAction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài đầu tiên'**
  String get profileEmptyPhotographerAction;

  /// No description provided for @profileEmptyCustomerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh nào'**
  String get profileEmptyCustomerTitle;

  /// No description provided for @profileEmptyCustomerBody.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây'**
  String get profileEmptyCustomerBody;

  /// No description provided for @profilePostsError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bài đăng.'**
  String get profilePostsError;

  /// S09.01 row under the grid when the next page failed; tapping it asks again.
  ///
  /// In vi, this message translates to:
  /// **'Không tải thêm được. Thử lại'**
  String get profilePostsMoreError;

  /// S09.01 spoken label of a grid tile whose post has no caption.
  ///
  /// In vi, this message translates to:
  /// **'Bài đăng {n}'**
  String profilePostTile(int n);

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
  /// **'Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán.'**
  String get phonePrivacy;

  /// No description provided for @editProfilePhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn thanh toán.'**
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

  /// No description provided for @setupBioLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
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
  /// **'Giao sau'**
  String get packageDeliveryLabel;

  /// No description provided for @packageDeliverySuffix.
  ///
  /// In vi, this message translates to:
  /// **'ngày'**
  String get packageDeliverySuffix;

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

  /// No description provided for @exploreSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm dịch vụ, địa điểm, tên thợ ảnh'**
  String get exploreSearchHint;

  /// No description provided for @exploreSearchIdle.
  ///
  /// In vi, this message translates to:
  /// **'Gõ tên dịch vụ, khu vực hoặc tên thợ ảnh.'**
  String get exploreSearchIdle;

  /// No description provided for @exploreSearchEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy “{query}”'**
  String exploreSearchEmptyTitle(String query);

  /// No description provided for @exploreSearchEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Thử từ ngắn hơn, hoặc gõ không dấu.'**
  String get exploreSearchEmptyBody;

  /// No description provided for @exploreSearchSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả thợ ảnh'**
  String get exploreSearchSeeAll;

  /// No description provided for @exploreSearchClear.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get exploreSearchClear;

  /// No description provided for @exploreCategoryPackages.
  ///
  /// In vi, this message translates to:
  /// **'{count} gói'**
  String exploreCategoryPackages(int count);

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
  /// **'{pct}% cà chua từ {count} đánh giá'**
  String reasonTopRated(int pct, int count);

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

  /// No description provided for @photoSharePost.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ bài viết'**
  String get photoSharePost;

  /// No description provided for @photoShareCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết bài viết'**
  String get photoShareCopied;

  /// No description provided for @photoMoreOptions.
  ///
  /// In vi, this message translates to:
  /// **'Thêm tuỳ chọn'**
  String get photoMoreOptions;

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
  /// **'Đang xếp theo điểm cà chua và khoảng cách'**
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

  /// No description provided for @findTomatoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ hài lòng'**
  String get findTomatoTitle;

  /// No description provided for @findRatingAny.
  ///
  /// In vi, this message translates to:
  /// **'Mọi đánh giá'**
  String get findRatingAny;

  /// No description provided for @findTomatoMin.
  ///
  /// In vi, this message translates to:
  /// **'{pct}%+'**
  String findTomatoMin(int pct);

  /// No description provided for @findTomatoChipA11y.
  ///
  /// In vi, this message translates to:
  /// **'Từ {pct}% cà chua'**
  String findTomatoChipA11y(int pct);

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

  /// No description provided for @profileOrdersClosedTag.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nhận đơn'**
  String get profileOrdersClosedTag;

  /// No description provided for @profileOrdersClosedNote.
  ///
  /// In vi, this message translates to:
  /// **'{name} chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. Bạn vẫn nhắn hỏi được.'**
  String profileOrdersClosedNote(String name);

  /// No description provided for @profileOrdersClosedButton.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nhận đặt lịch'**
  String get profileOrdersClosedButton;

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

  /// No description provided for @profileStatNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get profileStatNew;

  /// No description provided for @photographerReviewsNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới · {count} đánh giá'**
  String photographerReviewsNew(int count);

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

  /// No description provided for @profileSavePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Lưu nhiếp ảnh gia'**
  String get profileSavePhotographer;

  /// No description provided for @profileSharePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ hồ sơ'**
  String get profileSharePhotographer;

  /// No description provided for @profileShareCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết hồ sơ'**
  String get profileShareCopied;

  /// No description provided for @profileMoreOptions.
  ///
  /// In vi, this message translates to:
  /// **'Thêm tuỳ chọn'**
  String get profileMoreOptions;

  /// No description provided for @offlineBanner.
  ///
  /// In vi, this message translates to:
  /// **'Đang xem dữ liệu đã lưu'**
  String get offlineBanner;

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
  /// **'Thanh toán 100%'**
  String get bookDepositToday;

  /// No description provided for @bookPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả.'**
  String get bookPolicy;

  /// No description provided for @bookPay.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán {amount}'**
  String bookPay(String amount);

  /// No description provided for @payTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get payTitle;

  /// S04.04 (mock): app bar title of the VietQR checkout.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản QR'**
  String get payQrTitle;

  /// S04.04 (mock): countdown pill, time is mm:ss.
  ///
  /// In vi, this message translates to:
  /// **'Còn {time}'**
  String payQrCountdown(String time);

  /// No description provided for @payQrCountdownSemantics.
  ///
  /// In vi, this message translates to:
  /// **'QR còn hiệu lực {minutes} phút {seconds} giây'**
  String payQrCountdownSemantics(int minutes, int seconds);

  /// No description provided for @payQrExpiredPill.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get payQrExpiredPill;

  /// No description provided for @payQrExpired.
  ///
  /// In vi, this message translates to:
  /// **'QR đã hết hạn'**
  String get payQrExpired;

  /// No description provided for @payQrBank.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng'**
  String get payQrBank;

  /// No description provided for @payQrBankNote.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản thu hộ của trung gian thanh toán'**
  String get payQrBankNote;

  /// No description provided for @payQrAccount.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản'**
  String get payQrAccount;

  /// No description provided for @payQrContent.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung'**
  String get payQrContent;

  /// No description provided for @payQrCopy.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép'**
  String get payQrCopy;

  /// No description provided for @payQrCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép nội dung chuyển khoản'**
  String get payQrCopied;

  /// No description provided for @payQrHint.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển đúng số tiền và nội dung. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động.'**
  String get payQrHint;

  /// No description provided for @payQrNew.
  ///
  /// In vi, this message translates to:
  /// **'Tạo QR mới'**
  String get payQrNew;

  /// No description provided for @payQrOpenBank.
  ///
  /// In vi, this message translates to:
  /// **'Mở app ngân hàng'**
  String get payQrOpenBank;

  /// No description provided for @payQrSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Mã VietQR {amount}, nội dung {code}'**
  String payQrSemantics(String amount, String code);

  /// S04.04 (mock): photographer and package under the amount.
  ///
  /// In vi, this message translates to:
  /// **'{name} · {service}'**
  String payQrWho(String name, String service);

  /// No description provided for @payWalletWaiting.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ xác nhận'**
  String get payWalletWaiting;

  /// No description provided for @payWalletReopen.
  ///
  /// In vi, this message translates to:
  /// **'Mở lại {name}'**
  String payWalletReopen(String name);

  /// No description provided for @fakeTransferTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giả lập chuyển khoản (thử nghiệm)'**
  String get fakeTransferTitle;

  /// No description provided for @fakeTransferExact.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển đúng'**
  String get fakeTransferExact;

  /// No description provided for @fakeTransferUnder.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển thiếu'**
  String get fakeTransferUnder;

  /// No description provided for @fakeTransferOver.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển thừa'**
  String get fakeTransferOver;

  /// No description provided for @fakeTransferWrong.
  ///
  /// In vi, this message translates to:
  /// **'Sai nội dung'**
  String get fakeTransferWrong;

  /// No description provided for @fakeTransferOpen.
  ///
  /// In vi, this message translates to:
  /// **'Giả lập chuyển khoản'**
  String get fakeTransferOpen;

  /// No description provided for @payAwaitingDeposit.
  ///
  /// In vi, this message translates to:
  /// **'Chờ thanh toán'**
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
  /// **'Đã thanh toán {amount}, tiền được giữ an toàn'**
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
  /// **'Chưa nhận được thanh toán nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.'**
  String get payExpiredBody;

  /// No description provided for @payTicketExpiredBody.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nhận được thanh toán nên chỗ giữ đã nhả. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại.'**
  String get payTicketExpiredBody;

  /// No description provided for @payBackToEvent.
  ///
  /// In vi, this message translates to:
  /// **'Về sự kiện'**
  String get payBackToEvent;

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

  /// No description provided for @fakePayBody.
  ///
  /// In vi, this message translates to:
  /// **'Bản dùng thử: không có tiền thật nào được trừ.'**
  String get fakePayBody;

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
  /// **'Đã gửi & thanh toán'**
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
  /// **'Hết hạn, đã hoàn tiền'**
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
  /// **'Đã thanh toán {amount}, tiền được giữ an toàn.'**
  String detailPaidToast(String amount);

  /// No description provided for @escrowNoticeHeldPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'{amount} đang được giữ, chuyển cho bạn theo 2 mốc'**
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
  /// **'Huỷ yêu cầu · hoàn {pct}%'**
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
  /// **'{name} được hoàn 100%'**
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
  /// **'Đã huỷ. {name} được hoàn 100%'**
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
  /// **'Yêu cầu đã thanh toán, đang chờ nhiếp ảnh gia nhận sẽ hiện ở đây.'**
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
  /// **'đã trả {amount}'**
  String workDepositPaid(String amount);

  /// No description provided for @workRequestNote.
  ///
  /// In vi, this message translates to:
  /// **'“{note}” · {deposit}'**
  String workRequestNote(String note, String deposit);

  /// No description provided for @workRequestExpired.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu {name} đã hết hạn, đã hoàn tiền'**
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

  /// No description provided for @workAssignedBy.
  ///
  /// In vi, this message translates to:
  /// **'Giao bởi {studio}'**
  String workAssignedBy(String studio);

  /// No description provided for @workClosedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở nhận đơn để khách đặt được bạn'**
  String get workClosedTitle;

  /// No description provided for @workClosedBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn vẫn đăng portfolio, tạo gói và trò chuyện. Khách chỉ đặt lịch và xin báo giá sau khi bạn xác minh: số điện thoại, phí xác minh, danh tính và quy định nhận việc.'**
  String get workClosedBody;

  /// No description provided for @workClosedNote.
  ///
  /// In vi, this message translates to:
  /// **'Staff duyệt trong 24 giờ sau khi bạn gửi'**
  String get workClosedNote;

  /// No description provided for @workClosedStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu nhận đơn'**
  String get workClosedStart;

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
  /// **'{name} được hoàn 100% ({amount}) và nhận lý do này.'**
  String declineRefundNote(String name, String amount);

  /// No description provided for @declineDoneToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối. {name} được hoàn 100%.'**
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

  /// No description provided for @chatNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy cuộc trò chuyện'**
  String get chatNotFound;

  /// No description provided for @chatMe.
  ///
  /// In vi, this message translates to:
  /// **'Tôi'**
  String get chatMe;

  /// No description provided for @chatViewProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ'**
  String get chatViewProfile;

  /// No description provided for @chatInquiriesOff.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia đang tạm tắt nhận tin hỏi trước.'**
  String get chatInquiriesOff;

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
  /// **'Đã thanh toán. Chờ nhiếp ảnh gia nhận trong 24 giờ.'**
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

  /// No description provided for @chatsYouPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Bạn: {text}'**
  String chatsYouPrefix(String text);

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

  /// No description provided for @reviewTomato.
  ///
  /// In vi, this message translates to:
  /// **'Hài lòng'**
  String get reviewTomato;

  /// No description provided for @reviewBrick.
  ///
  /// In vi, this message translates to:
  /// **'Chưa hài lòng'**
  String get reviewBrick;

  /// No description provided for @reviewBrickShort.
  ///
  /// In vi, this message translates to:
  /// **'Chưa ưng'**
  String get reviewBrickShort;

  /// No description provided for @reviewHits.
  ///
  /// In vi, this message translates to:
  /// **'×{n}'**
  String reviewHits(int n);

  /// No description provided for @reviewTomatoLevel1.
  ///
  /// In vi, this message translates to:
  /// **'Ổn'**
  String get reviewTomatoLevel1;

  /// No description provided for @reviewTomatoLevel2.
  ///
  /// In vi, this message translates to:
  /// **'Hài lòng'**
  String get reviewTomatoLevel2;

  /// No description provided for @reviewTomatoLevel3.
  ///
  /// In vi, this message translates to:
  /// **'Rất hài lòng'**
  String get reviewTomatoLevel3;

  /// No description provided for @reviewTomatoLevel4.
  ///
  /// In vi, this message translates to:
  /// **'Tuyệt vời!'**
  String get reviewTomatoLevel4;

  /// No description provided for @reviewBrickLevel1.
  ///
  /// In vi, this message translates to:
  /// **'Hơi tiếc'**
  String get reviewBrickLevel1;

  /// No description provided for @reviewBrickLevel2.
  ///
  /// In vi, this message translates to:
  /// **'Chưa ưng'**
  String get reviewBrickLevel2;

  /// No description provided for @reviewBrickLevel3.
  ///
  /// In vi, this message translates to:
  /// **'Thất vọng'**
  String get reviewBrickLevel3;

  /// No description provided for @reviewBrickLevel4.
  ///
  /// In vi, this message translates to:
  /// **'Rất thất vọng'**
  String get reviewBrickLevel4;

  /// No description provided for @reviewReset.
  ///
  /// In vi, this message translates to:
  /// **'Làm lại'**
  String get reviewReset;

  /// No description provided for @reviewTapMore.
  ///
  /// In vi, this message translates to:
  /// **'Chạm tiếp để tăng mức độ, tối đa 10'**
  String get reviewTapMore;

  /// No description provided for @reviewPadLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá buổi chụp'**
  String get reviewPadLabel;

  /// No description provided for @reviewA11yTomato.
  ///
  /// In vi, this message translates to:
  /// **'Ném cà chua, {n} trên 10'**
  String reviewA11yTomato(int n);

  /// No description provided for @reviewA11yBrick.
  ///
  /// In vi, this message translates to:
  /// **'Ném gạch, {n} trên 10'**
  String reviewA11yBrick(int n);

  /// No description provided for @reviewsRatioCounts.
  ///
  /// In vi, this message translates to:
  /// **'{tomato} cà chua · {brick} gạch · {count} đánh giá'**
  String reviewsRatioCounts(int tomato, int brick, int count);

  /// No description provided for @reviewsRatioSemantics.
  ///
  /// In vi, this message translates to:
  /// **'{tomato} cà chua, {brick} gạch'**
  String reviewsRatioSemantics(int tomato, int brick);

  /// No description provided for @tomatoPctA11y.
  ///
  /// In vi, this message translates to:
  /// **'{pct}% cà chua'**
  String tomatoPctA11y(int pct);

  /// No description provided for @tomatoPctCountA11y.
  ///
  /// In vi, this message translates to:
  /// **'{pct}% cà chua, {count} đánh giá'**
  String tomatoPctCountA11y(int pct, int count);

  /// No description provided for @verdictBadgeTomato.
  ///
  /// In vi, this message translates to:
  /// **'Cà chua, {n} trên 10'**
  String verdictBadgeTomato(int n);

  /// No description provided for @verdictBadgeBrick.
  ///
  /// In vi, this message translates to:
  /// **'Gạch, {n} trên 10'**
  String verdictBadgeBrick(int n);

  /// No description provided for @reviewTextHintTomato.
  ///
  /// In vi, this message translates to:
  /// **'Điều bạn thích nhất ở buổi chụp'**
  String get reviewTextHintTomato;

  /// No description provided for @reviewTextHintBrick.
  ///
  /// In vi, this message translates to:
  /// **'Kể rõ điều chưa ổn để thợ cải thiện'**
  String get reviewTextHintBrick;

  /// No description provided for @reviewReasonsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điều gì chưa ổn?'**
  String get reviewReasonsTitle;

  /// No description provided for @reviewReasonsMin.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ít nhất 1'**
  String get reviewReasonsMin;

  /// No description provided for @reviewReasonLate.
  ///
  /// In vi, this message translates to:
  /// **'Đến trễ'**
  String get reviewReasonLate;

  /// No description provided for @reviewReasonNotAsPortfolio.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh không như mẫu'**
  String get reviewReasonNotAsPortfolio;

  /// No description provided for @reviewReasonSlowDelivery.
  ///
  /// In vi, this message translates to:
  /// **'Giao ảnh chậm'**
  String get reviewReasonSlowDelivery;

  /// No description provided for @reviewReasonAttitude.
  ///
  /// In vi, this message translates to:
  /// **'Thái độ'**
  String get reviewReasonAttitude;

  /// No description provided for @reviewReasonPriceChanged.
  ///
  /// In vi, this message translates to:
  /// **'Đổi giá'**
  String get reviewReasonPriceChanged;

  /// No description provided for @reviewReasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get reviewReasonOther;

  /// No description provided for @reviewNeedVerdict.
  ///
  /// In vi, this message translates to:
  /// **'Chọn cà chua hoặc gạch'**
  String get reviewNeedVerdict;

  /// No description provided for @reviewNeedReason.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ít nhất một lý do'**
  String get reviewNeedReason;

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

  /// No description provided for @reviewUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh lỗi. Thử lại'**
  String get reviewUploadFailed;

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

  /// No description provided for @s2501ListedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã khai'**
  String get s2501ListedTitle;

  /// No description provided for @s2501ListedCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} giải'**
  String s2501ListedCount(int n);

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

  /// No description provided for @notifSettingsTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt thông báo'**
  String get notifSettingsTooltip;

  /// No description provided for @notifTabAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get notifTabAll;

  /// No description provided for @notifTabBooking.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get notifTabBooking;

  /// No description provided for @notifTabWork.
  ///
  /// In vi, this message translates to:
  /// **'Công việc'**
  String get notifTabWork;

  /// No description provided for @notifTabEvents.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get notifTabEvents;

  /// No description provided for @notifTabSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống'**
  String get notifTabSystem;

  /// No description provided for @notifUnreadHeader.
  ///
  /// In vi, this message translates to:
  /// **'{n} chưa đọc'**
  String notifUnreadHeader(int n);

  /// No description provided for @notifMarkAllRead.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu tất cả đã đọc'**
  String get notifMarkAllRead;

  /// No description provided for @notifSectionToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get notifSectionToday;

  /// No description provided for @notifSectionWeek.
  ///
  /// In vi, this message translates to:
  /// **'7 ngày qua'**
  String get notifSectionWeek;

  /// No description provided for @notifSectionEarlier.
  ///
  /// In vi, this message translates to:
  /// **'Trước đó'**
  String get notifSectionEarlier;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thông báo nào'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Lịch hẹn, tin nhắn và huy hiệu của bạn sẽ hiện ở đây.'**
  String get notifEmptyBody;

  /// No description provided for @notifEmptyCtaCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá nhiếp ảnh gia'**
  String get notifEmptyCtaCustomer;

  /// No description provided for @notifEmptyCtaPhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Mở Công việc'**
  String get notifEmptyCtaPhotographer;

  /// No description provided for @notifEmptyFiltered.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thông báo nào trong mục {tab}'**
  String notifEmptyFiltered(String tab);

  /// No description provided for @notifEmptyFilteredBody.
  ///
  /// In vi, this message translates to:
  /// **'Chọn mục khác để xem thêm.'**
  String get notifEmptyFilteredBody;

  /// No description provided for @notifTargetGone.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung này không còn'**
  String get notifTargetGone;

  /// No description provided for @notifMuted.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt loại thông báo này'**
  String get notifMuted;

  /// No description provided for @notifUndo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get notifUndo;

  /// No description provided for @notifTimeNow.
  ///
  /// In vi, this message translates to:
  /// **'Vừa xong'**
  String get notifTimeNow;

  /// No description provided for @notifTimeMinutes.
  ///
  /// In vi, this message translates to:
  /// **'{n} phút'**
  String notifTimeMinutes(int n);

  /// No description provided for @notifTimeHours.
  ///
  /// In vi, this message translates to:
  /// **'{n} giờ'**
  String notifTimeHours(int n);

  /// No description provided for @notifTimeYesterday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm qua'**
  String get notifTimeYesterday;

  /// No description provided for @notifTimeDays.
  ///
  /// In vi, this message translates to:
  /// **'{n} ngày'**
  String notifTimeDays(int n);

  /// No description provided for @notifRowSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo, {n} thông báo chưa đọc, {title}'**
  String notifRowSemantics(int n, String title);

  /// No description provided for @notifRowSemanticsRead.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo, {title}'**
  String notifRowSemanticsRead(String title);

  /// No description provided for @notifLoadMoreError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải thêm được. Kéo xuống để thử lại.'**
  String get notifLoadMoreError;

  /// No description provided for @settingsNotificationsBody.
  ///
  /// In vi, this message translates to:
  /// **'Push, giờ yên lặng, nhắc buổi chụp'**
  String get settingsNotificationsBody;

  /// No description provided for @notifSettingsOsOffTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo đang tắt trên máy'**
  String get notifSettingsOsOffTitle;

  /// No description provided for @notifSettingsOsOffBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ không nhận push cho tới khi bật lại.'**
  String get notifSettingsOsOffBody;

  /// No description provided for @notifSettingsOpenSettings.
  ///
  /// In vi, this message translates to:
  /// **'Mở Cài đặt'**
  String get notifSettingsOpenSettings;

  /// No description provided for @notifSettingsColType.
  ///
  /// In vi, this message translates to:
  /// **'Loại'**
  String get notifSettingsColType;

  /// No description provided for @notifSettingsColPush.
  ///
  /// In vi, this message translates to:
  /// **'Push'**
  String get notifSettingsColPush;

  /// No description provided for @notifSettingsColInApp.
  ///
  /// In vi, this message translates to:
  /// **'Trong app'**
  String get notifSettingsColInApp;

  /// No description provided for @notifSettingsPushOffOs.
  ///
  /// In vi, this message translates to:
  /// **'Đang tắt trên máy'**
  String get notifSettingsPushOffOs;

  /// No description provided for @notifSettingsCatBooking.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch và thanh toán'**
  String get notifSettingsCatBooking;

  /// No description provided for @notifSettingsCatJobs.
  ///
  /// In vi, this message translates to:
  /// **'Việc đăng tuyển'**
  String get notifSettingsCatJobs;

  /// No description provided for @notifSettingsCatInstant.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ngay'**
  String get notifSettingsCatInstant;

  /// No description provided for @notifSettingsCatEvents.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get notifSettingsCatEvents;

  /// No description provided for @notifSettingsCatChat.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get notifSettingsCatChat;

  /// No description provided for @notifSettingsCatBadges.
  ///
  /// In vi, this message translates to:
  /// **'Huy hiệu và đánh giá'**
  String get notifSettingsCatBadges;

  /// No description provided for @notifSettingsCatPromo.
  ///
  /// In vi, this message translates to:
  /// **'Khuyến mãi'**
  String get notifSettingsCatPromo;

  /// No description provided for @notifSwitchOn.
  ///
  /// In vi, this message translates to:
  /// **'{group}, {channel}, bật'**
  String notifSwitchOn(String group, String channel);

  /// No description provided for @notifSwitchOff.
  ///
  /// In vi, this message translates to:
  /// **'{group}, {channel}, tắt'**
  String notifSwitchOff(String group, String channel);

  /// No description provided for @notifSwitchLocked.
  ///
  /// In vi, this message translates to:
  /// **'{group}, {channel}, luôn bật'**
  String notifSwitchLocked(String group, String channel);

  /// No description provided for @notifSettingsQuietTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giờ yên lặng'**
  String get notifSettingsQuietTitle;

  /// No description provided for @notifSettingsQuietLine.
  ///
  /// In vi, this message translates to:
  /// **'{from}–{to} · chỉ thông báo quan trọng vẫn có âm'**
  String notifSettingsQuietLine(String from, String to);

  /// No description provided for @notifSettingsQuietSwitchOn.
  ///
  /// In vi, this message translates to:
  /// **'Giờ yên lặng, bật'**
  String get notifSettingsQuietSwitchOn;

  /// No description provided for @notifSettingsQuietSwitchOff.
  ///
  /// In vi, this message translates to:
  /// **'Giờ yên lặng, tắt'**
  String get notifSettingsQuietSwitchOff;

  /// No description provided for @notifSettingsPickFrom.
  ///
  /// In vi, this message translates to:
  /// **'Yên lặng từ'**
  String get notifSettingsPickFrom;

  /// No description provided for @notifSettingsPickTo.
  ///
  /// In vi, this message translates to:
  /// **'Yên lặng đến'**
  String get notifSettingsPickTo;

  /// No description provided for @notifSettingsRemindersTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc buổi chụp'**
  String get notifSettingsRemindersTitle;

  /// No description provided for @notifSettingsReminder24.
  ///
  /// In vi, this message translates to:
  /// **'24 giờ'**
  String get notifSettingsReminder24;

  /// No description provided for @notifSettingsReminder2.
  ///
  /// In vi, this message translates to:
  /// **'2 giờ'**
  String get notifSettingsReminder2;

  /// No description provided for @notifSettingsSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được, thử lại'**
  String get notifSettingsSaveError;

  /// No description provided for @primerTitleCustomerBooking.
  ///
  /// In vi, this message translates to:
  /// **'Bật thông báo để biết khi {name} nhận lịch'**
  String primerTitleCustomerBooking(String name);

  /// No description provided for @primerTitleCustomerTicket.
  ///
  /// In vi, this message translates to:
  /// **'Bật thông báo để được nhắc trước khi {event} bắt đầu'**
  String primerTitleCustomerTicket(String event);

  /// No description provided for @primerTicketBenefit1.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung'**
  String get primerTicketBenefit1;

  /// No description provided for @primerTitleCustomerInstant.
  ///
  /// In vi, this message translates to:
  /// **'Bật thông báo để biết khi có người nhận chụp ngay'**
  String get primerTitleCustomerInstant;

  /// No description provided for @primerTitlePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Bật thông báo để không bỏ lỡ lời mời việc'**
  String get primerTitlePhotographer;

  /// No description provided for @primerBenefit1.
  ///
  /// In vi, this message translates to:
  /// **'Biết ngay khi lịch được nhận hoặc thay đổi'**
  String get primerBenefit1;

  /// No description provided for @primerBenefit2.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc trước giờ chụp, không lỡ hẹn'**
  String get primerBenefit2;

  /// No description provided for @primerBenefit3.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn mới khi app đang ở nền'**
  String get primerBenefit3;

  /// No description provided for @primerNote.
  ///
  /// In vi, this message translates to:
  /// **'Chọn \"Để sau\", chúng tôi sẽ hỏi lại sau 7 ngày.'**
  String get primerNote;

  /// No description provided for @primerEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã bật thông báo'**
  String get primerEnabled;

  /// No description provided for @badgesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huy hiệu'**
  String get badgesTitle;

  /// No description provided for @badgesFromReviews.
  ///
  /// In vi, this message translates to:
  /// **'Từ đánh giá'**
  String get badgesFromReviews;

  /// No description provided for @badgesFromSystem.
  ///
  /// In vi, this message translates to:
  /// **'Từ hệ thống'**
  String get badgesFromSystem;

  /// No description provided for @badgesFraction.
  ///
  /// In vi, this message translates to:
  /// **'{a} / {b}'**
  String badgesFraction(int a, int b);

  /// No description provided for @badgesSectionSemantics.
  ///
  /// In vi, this message translates to:
  /// **'{title}, đạt {a} trên {b}'**
  String badgesSectionSemantics(String title, int a, int b);

  /// No description provided for @badgesEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có huy hiệu nào'**
  String get badgesEmptyTitle;

  /// No description provided for @badgesEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Huy hiệu sẽ hiện ở đây khi người này đạt được.'**
  String get badgesEmptyBody;

  /// No description provided for @badgesLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được huy hiệu'**
  String get badgesLoadError;

  /// No description provided for @badgesNearest.
  ///
  /// In vi, this message translates to:
  /// **'Gần đạt nhất: {name} · {cur} / {target}'**
  String badgesNearest(String name, int cur, int target);

  /// No description provided for @badgesAwardedOn.
  ///
  /// In vi, this message translates to:
  /// **'Đạt ngày {date}'**
  String badgesAwardedOn(String date);

  /// No description provided for @badgesSheetProgress.
  ///
  /// In vi, this message translates to:
  /// **'{cur} / {target}'**
  String badgesSheetProgress(int cur, int target);

  /// No description provided for @earningsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập'**
  String get earningsTitle;

  /// No description provided for @earningsNotice.
  ///
  /// In vi, this message translates to:
  /// **'Chi tự động mỗi ngày · lần chi đầu do staff duyệt · phí chuyển do nền tảng trả'**
  String get earningsNotice;

  /// No description provided for @earningsHeld.
  ///
  /// In vi, this message translates to:
  /// **'Đang giữ'**
  String get earningsHeld;

  /// No description provided for @earningsSoon.
  ///
  /// In vi, this message translates to:
  /// **'Chờ chi trả'**
  String get earningsSoon;

  /// No description provided for @earningsReceived.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận'**
  String get earningsReceived;

  /// No description provided for @earningsStateHeld.
  ///
  /// In vi, this message translates to:
  /// **'Đang giữ'**
  String get earningsStateHeld;

  /// No description provided for @earningsStateReleased.
  ///
  /// In vi, this message translates to:
  /// **'Chờ chi trả'**
  String get earningsStateReleased;

  /// No description provided for @earningsStatePaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã chuyển'**
  String get earningsStatePaid;

  /// No description provided for @earningsStateDispute.
  ///
  /// In vi, this message translates to:
  /// **'Đang khiếu nại'**
  String get earningsStateDispute;

  /// No description provided for @earningsAddAccount.
  ///
  /// In vi, this message translates to:
  /// **'Thêm tài khoản để nhận tiền'**
  String get earningsAddAccount;

  /// No description provided for @earningsAddAccountSub.
  ///
  /// In vi, this message translates to:
  /// **'Cần có trước khi chuyển khoản'**
  String get earningsAddAccountSub;

  /// No description provided for @earningsItems.
  ///
  /// In vi, this message translates to:
  /// **'Các khoản'**
  String get earningsItems;

  /// No description provided for @earningsMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}'**
  String earningsMonth(int month);

  /// No description provided for @earningsMonthYear.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}/{year}'**
  String earningsMonthYear(int month, int year);

  /// No description provided for @earningsPayoutFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản lỗi, kiểm tra tài khoản'**
  String get earningsPayoutFailed;

  /// No description provided for @earningsHoldReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do: {reason}'**
  String earningsHoldReason(String reason);

  /// No description provided for @earningsHoldDispute.
  ///
  /// In vi, this message translates to:
  /// **'Khách đã báo vấn đề, đang chờ xử lý'**
  String get earningsHoldDispute;

  /// No description provided for @earningsHoldPayoutOnHold.
  ///
  /// In vi, this message translates to:
  /// **'Lô chi trả đang tạm giữ'**
  String get earningsHoldPayoutOnHold;

  /// No description provided for @earningsCustomerFallback.
  ///
  /// In vi, this message translates to:
  /// **'Khách'**
  String get earningsCustomerFallback;

  /// No description provided for @earningsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản thu nào'**
  String get earningsEmptyTitle;

  /// No description provided for @earningsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Khoản đầu tiên hiện ở đây khi khách đặt lịch và thanh toán.'**
  String get earningsEmptyBody;

  /// No description provided for @earningsMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm'**
  String get earningsMore;

  /// No description provided for @earningsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được thu nhập'**
  String get earningsLoadError;

  /// No description provided for @earningsBreakdownReleased.
  ///
  /// In vi, this message translates to:
  /// **'Đã chuyển theo mốc'**
  String get earningsBreakdownReleased;

  /// No description provided for @earningsBreakdownPaidOn.
  ///
  /// In vi, this message translates to:
  /// **'Ngày chuyển'**
  String get earningsBreakdownPaidOn;

  /// No description provided for @earningsBreakdownAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền'**
  String get earningsBreakdownAmount;

  /// No description provided for @earningsBreakdownFee.
  ///
  /// In vi, this message translates to:
  /// **'Hoa hồng ({percent})'**
  String earningsBreakdownFee(String percent);

  /// No description provided for @earningsBreakdownTax.
  ///
  /// In vi, this message translates to:
  /// **'Thuế khấu trừ ({percent})'**
  String earningsBreakdownTax(String percent);

  /// No description provided for @earningsBreakdownNet.
  ///
  /// In vi, this message translates to:
  /// **'Thực nhận'**
  String get earningsBreakdownNet;

  /// No description provided for @earningsBreakdownNetEstimated.
  ///
  /// In vi, this message translates to:
  /// **'Thực nhận dự kiến'**
  String get earningsBreakdownNetEstimated;

  /// No description provided for @earningsMilestones.
  ///
  /// In vi, this message translates to:
  /// **'mốc {done}/{total}'**
  String earningsMilestones(int done, int total);

  /// No description provided for @earningsMilestonesAll.
  ///
  /// In vi, this message translates to:
  /// **'đủ {total} mốc'**
  String earningsMilestonesAll(int total);

  /// No description provided for @payoutAccountTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản nhận tiền'**
  String get payoutAccountTitle;

  /// No description provided for @profileEarnings.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập'**
  String get profileEarnings;

  /// No description provided for @profileEarningsSub.
  ///
  /// In vi, this message translates to:
  /// **'Tiền đang giữ, sắp nhận và đã nhận'**
  String get profileEarningsSub;

  /// No description provided for @payoutAccountIntro.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tài khoản đứng tên bạn, tiền sẽ chi tự động vào đây.'**
  String get payoutAccountIntro;

  /// No description provided for @payoutAccountBank.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng'**
  String get payoutAccountBank;

  /// No description provided for @payoutAccountBankPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngân hàng'**
  String get payoutAccountBankPick;

  /// No description provided for @payoutAccountBankSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm ngân hàng'**
  String get payoutAccountBankSearch;

  /// No description provided for @payoutAccountBankNone.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy ngân hàng'**
  String get payoutAccountBankNone;

  /// No description provided for @payoutAccountNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản'**
  String get payoutAccountNumber;

  /// No description provided for @payoutAccountSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu tài khoản'**
  String get payoutAccountSave;

  /// No description provided for @payoutAccountHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài khoản được mã hoá, chỉ hiện 4 số cuối.'**
  String get payoutAccountHint;

  /// No description provided for @payoutAccountMasked.
  ///
  /// In vi, this message translates to:
  /// **'•••• {last4}'**
  String payoutAccountMasked(String last4);

  /// No description provided for @payoutAccountChange.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tài khoản'**
  String get payoutAccountChange;

  /// No description provided for @payoutAccountNumberError.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản gồm 6–20 chữ số'**
  String get payoutAccountNumberError;

  /// No description provided for @payoutAccountSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu tài khoản nhận tiền'**
  String get payoutAccountSaved;

  /// No description provided for @payoutAccountSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được. Thử lại'**
  String get payoutAccountSaveError;

  /// No description provided for @payoutAccountBusy.
  ///
  /// In vi, this message translates to:
  /// **'Đang chuyển một lô tiền, thử lại sau ít phút'**
  String get payoutAccountBusy;

  /// No description provided for @payoutAccountIntroChange.
  ///
  /// In vi, this message translates to:
  /// **'Đang dùng {bank} •••• {last4}. Nhập tài khoản mới đứng tên bạn, tiền sẽ chi tự động vào đây.'**
  String payoutAccountIntroChange(String bank, String last4);

  /// No description provided for @payoutAccountChangeNote.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tài khoản cần OTP và có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi. Tài khoản cũ sẽ nhận thông báo.'**
  String get payoutAccountChangeNote;

  /// No description provided for @payoutAccountSameAccount.
  ///
  /// In vi, this message translates to:
  /// **'Đây đã là tài khoản đang dùng'**
  String get payoutAccountSameAccount;

  /// No description provided for @payoutLookupLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tra tên chủ tài khoản…'**
  String get payoutLookupLoading;

  /// No description provided for @payoutLookupMatched.
  ///
  /// In vi, this message translates to:
  /// **'Khớp tên đã xác minh'**
  String get payoutLookupMatched;

  /// No description provided for @payoutLookupMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Không khớp'**
  String get payoutLookupMismatch;

  /// No description provided for @payoutLookupMismatchTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tên chủ tài khoản không khớp tên đã xác minh ({name})'**
  String payoutLookupMismatchTitle(String name);

  /// No description provided for @payoutLookupMismatchBody.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ chi tiền vào tài khoản đứng tên bạn. Kiểm tra lại ngân hàng và số tài khoản.'**
  String get payoutLookupMismatchBody;

  /// No description provided for @payoutLookupReview.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng chưa hỗ trợ tra tên'**
  String get payoutLookupReview;

  /// No description provided for @payoutLookupReviewSub.
  ///
  /// In vi, this message translates to:
  /// **'Staff đối chiếu tên trước lần chi đầu'**
  String get payoutLookupReviewSub;

  /// No description provided for @payoutLookupNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy tài khoản. Kiểm tra lại số tài khoản.'**
  String get payoutLookupNotFound;

  /// No description provided for @payoutLookupUnverifiable.
  ///
  /// In vi, this message translates to:
  /// **'Cần xác minh danh tính trước khi thêm tài khoản ở ngân hàng này'**
  String get payoutLookupUnverifiable;

  /// No description provided for @payoutLookupLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.'**
  String get payoutLookupLimit;

  /// No description provided for @payoutLookupError.
  ///
  /// In vi, this message translates to:
  /// **'Không tra được tên. Thử lại'**
  String get payoutLookupError;

  /// No description provided for @payoutOtpTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã xác nhận'**
  String get payoutOtpTitle;

  /// No description provided for @payoutOtpBody.
  ///
  /// In vi, this message translates to:
  /// **'Mã 6 số đã gửi tới số điện thoại •••• {last4}. Mã có hiệu lực 5 phút.'**
  String payoutOtpBody(String last4);

  /// No description provided for @payoutOtpField.
  ///
  /// In vi, this message translates to:
  /// **'Mã OTP'**
  String get payoutOtpField;

  /// No description provided for @payoutOtpConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đổi tài khoản'**
  String get payoutOtpConfirm;

  /// No description provided for @payoutOtpResend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại mã'**
  String get payoutOtpResend;

  /// No description provided for @payoutOtpResendIn.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại sau {seconds} giây'**
  String payoutOtpResendIn(int seconds);

  /// No description provided for @payoutOtpNote.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản mới có hiệu lực sau 72 giờ; trong lúc đó tạm dừng chi.'**
  String get payoutOtpNote;

  /// No description provided for @payoutOtpWrong.
  ///
  /// In vi, this message translates to:
  /// **'Mã chưa đúng. Kiểm tra lại tin nhắn'**
  String get payoutOtpWrong;

  /// No description provided for @payoutOtpExpired.
  ///
  /// In vi, this message translates to:
  /// **'Mã đã hết hạn. Gửi lại mã mới'**
  String get payoutOtpExpired;

  /// No description provided for @payoutOtpTooMany.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã nhập sai quá nhiều lần. Gửi lại mã mới'**
  String get payoutOtpTooMany;

  /// No description provided for @payoutOtpLimit.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.'**
  String get payoutOtpLimit;

  /// No description provided for @payoutPhoneRequired.
  ///
  /// In vi, this message translates to:
  /// **'Cần số điện thoại trong hồ sơ để nhận mã'**
  String get payoutPhoneRequired;

  /// No description provided for @payoutOtpUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đổi được tài khoản lúc này. Liên hệ hỗ trợ'**
  String get payoutOtpUnavailable;

  /// No description provided for @payoutAccountPendingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản mới có hiệu lực lúc {time}'**
  String payoutAccountPendingTitle(String time);

  /// No description provided for @payoutAccountPendingBody.
  ///
  /// In vi, this message translates to:
  /// **'Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do staff duyệt.'**
  String get payoutAccountPendingBody;

  /// No description provided for @payoutAccountPendingBadge.
  ///
  /// In vi, this message translates to:
  /// **'Chờ hiệu lực'**
  String get payoutAccountPendingBadge;

  /// No description provided for @payoutAccountReviewNote.
  ///
  /// In vi, this message translates to:
  /// **'Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu.'**
  String get payoutAccountReviewNote;

  /// No description provided for @payoutAccountChangeSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi tài khoản. Có hiệu lực sau 72 giờ'**
  String get payoutAccountChangeSaved;

  /// No description provided for @reauthTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận lại để tiếp tục'**
  String get reauthTitle;

  /// No description provided for @reauthBody.
  ///
  /// In vi, this message translates to:
  /// **'Vì an toàn, hãy đăng nhập lại trước khi tiếp tục.'**
  String get reauthBody;

  /// No description provided for @reauthPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get reauthPassword;

  /// No description provided for @reauthGo.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get reauthGo;

  /// No description provided for @reauthWrong.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu chưa đúng'**
  String get reauthWrong;

  /// No description provided for @eventHostPlatform.
  ///
  /// In vi, this message translates to:
  /// **'Do ứng dụng tổ chức'**
  String get eventHostPlatform;

  /// No description provided for @eventsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get eventsTitle;

  /// No description provided for @eventsAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get eventsAll;

  /// No description provided for @eventsSortSoonest.
  ///
  /// In vi, this message translates to:
  /// **'Sớm nhất'**
  String get eventsSortSoonest;

  /// No description provided for @eventsSortNear.
  ///
  /// In vi, this message translates to:
  /// **'Gần tôi'**
  String get eventsSortNear;

  /// No description provided for @eventsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có sự kiện'**
  String get eventsEmpty;

  /// No description provided for @eventsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện chụp ảnh mới sẽ hiện ở đây.'**
  String get eventsEmptyBody;

  /// No description provided for @eventsCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo sự kiện'**
  String get eventsCreate;

  /// No description provided for @eventsNeedArea.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khu vực để xem sự kiện gần bạn'**
  String get eventsNeedArea;

  /// No description provided for @eventsMyTickets.
  ///
  /// In vi, this message translates to:
  /// **'Vé của tôi'**
  String get eventsMyTickets;

  /// No description provided for @eventJoin.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký tham gia'**
  String get eventJoin;

  /// No description provided for @eventPerPerson.
  ///
  /// In vi, this message translates to:
  /// **'mỗi người'**
  String get eventPerPerson;

  /// No description provided for @eventViewTicket.
  ///
  /// In vi, this message translates to:
  /// **'Xem vé'**
  String get eventViewTicket;

  /// No description provided for @eventManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý'**
  String get eventManage;

  /// No description provided for @eventCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện đã huỷ'**
  String get eventCancelled;

  /// No description provided for @eventEnded.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện đã kết thúc'**
  String get eventEnded;

  /// No description provided for @eventClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng đăng ký'**
  String get eventClosed;

  /// No description provided for @eventPaymentsSoon.
  ///
  /// In vi, this message translates to:
  /// **'Sắp mở thanh toán'**
  String get eventPaymentsSoon;

  /// No description provided for @eventTabInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin'**
  String get eventTabInfo;

  /// No description provided for @eventTabTimeline.
  ///
  /// In vi, this message translates to:
  /// **'Timeline'**
  String get eventTabTimeline;

  /// No description provided for @eventTabChat.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm chat'**
  String get eventTabChat;

  /// No description provided for @eventHostRole.
  ///
  /// In vi, this message translates to:
  /// **'Chủ sự kiện'**
  String get eventHostRole;

  /// No description provided for @eventProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get eventProfile;

  /// No description provided for @eventMeetingPoint.
  ///
  /// In vi, this message translates to:
  /// **'Điểm hẹn: {place}'**
  String eventMeetingPoint(String place);

  /// No description provided for @eventCapacityLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {n} chỗ'**
  String eventCapacityLeft(int n);

  /// No description provided for @eventGone.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện không còn'**
  String get eventGone;

  /// No description provided for @eventGoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện này đã bị xoá hoặc chưa được đăng.'**
  String get eventGoneBody;

  /// No description provided for @eventLinkCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết'**
  String get eventLinkCopied;

  /// No description provided for @eventShareTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ sự kiện'**
  String get eventShareTooltip;

  /// No description provided for @eventWeekdayLong.
  ///
  /// In vi, this message translates to:
  /// **'{weekday, select, 1{Thứ hai} 2{Thứ ba} 3{Thứ tư} 4{Thứ năm} 5{Thứ sáu} 6{Thứ bảy} other{Chủ nhật}}'**
  String eventWeekdayLong(String weekday);

  /// No description provided for @eventFaqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp'**
  String get eventFaqTitle;

  /// No description provided for @eventSupportLine.
  ///
  /// In vi, this message translates to:
  /// **'Cần hỏi thêm? Gửi email tới {email}'**
  String eventSupportLine(String email);

  /// No description provided for @eventChatLocked.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký để vào nhóm'**
  String get eventChatLocked;

  /// No description provided for @eventChatLockedBody.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ người đã đăng ký mới vào được nhóm chat của sự kiện.'**
  String get eventChatLockedBody;

  /// No description provided for @eventChatSoon.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm chat sắp mở'**
  String get eventChatSoon;

  /// No description provided for @eventTimelineSoon.
  ///
  /// In vi, this message translates to:
  /// **'Timeline sắp mở'**
  String get eventTimelineSoon;

  /// No description provided for @eventsManage.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện của tôi'**
  String get eventsManage;

  /// No description provided for @eventRegisterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký tham gia'**
  String get eventRegisterTitle;

  /// No description provided for @registerTickets.
  ///
  /// In vi, this message translates to:
  /// **'Số vé'**
  String get registerTickets;

  /// No description provided for @registerTicketsHint.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 4 vé, còn {n} chỗ'**
  String registerTicketsHint(int n);

  /// No description provided for @registerName.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên người tham gia'**
  String get registerName;

  /// No description provided for @registerNameError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập họ tên, tối đa 60 ký tự'**
  String get registerNameError;

  /// No description provided for @registerPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get registerPhone;

  /// No description provided for @registerChangePhone.
  ///
  /// In vi, this message translates to:
  /// **'Đổi'**
  String get registerChangePhone;

  /// No description provided for @registerFree.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đăng ký'**
  String get registerFree;

  /// No description provided for @registerSoldOut.
  ///
  /// In vi, this message translates to:
  /// **'Hết chỗ'**
  String get registerSoldOut;

  /// No description provided for @registerDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng ký'**
  String get registerDone;

  /// No description provided for @registerOpenChat.
  ///
  /// In vi, this message translates to:
  /// **'Vào nhóm chat'**
  String get registerOpenChat;

  /// No description provided for @registerError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đăng ký được. Kiểm tra mạng rồi thử lại.'**
  String get registerError;

  /// No description provided for @registerLess.
  ///
  /// In vi, this message translates to:
  /// **'Bớt một vé'**
  String get registerLess;

  /// No description provided for @registerMore.
  ///
  /// In vi, this message translates to:
  /// **'Thêm một vé'**
  String get registerMore;

  /// No description provided for @ticketsTab.
  ///
  /// In vi, this message translates to:
  /// **'Vé sự kiện'**
  String get ticketsTab;

  /// No description provided for @bookingsTabShoots.
  ///
  /// In vi, this message translates to:
  /// **'Buổi chụp'**
  String get bookingsTabShoots;

  /// No description provided for @ticketCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã vé'**
  String get ticketCode;

  /// No description provided for @ticketCancelRefund.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ vé · hoàn {pct}%'**
  String ticketCancelRefund(int pct);

  /// No description provided for @ticketCancelNoRefund.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ vé · không hoàn tiền'**
  String get ticketCancelNoRefund;

  /// No description provided for @ticketAttended.
  ///
  /// In vi, this message translates to:
  /// **'Đã tham gia'**
  String get ticketAttended;

  /// No description provided for @ticketRefunded.
  ///
  /// In vi, this message translates to:
  /// **'Đã hoàn tiền'**
  String get ticketRefunded;

  /// No description provided for @ticketRefunding.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoàn'**
  String get ticketRefunding;

  /// No description provided for @ticketShowHint.
  ///
  /// In vi, this message translates to:
  /// **'Đưa mã này cho chủ sự kiện khi đến điểm hẹn.'**
  String get ticketShowHint;

  /// No description provided for @ticketsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có vé sự kiện'**
  String get ticketsEmpty;

  /// No description provided for @ticketsBrowse.
  ///
  /// In vi, this message translates to:
  /// **'Xem sự kiện'**
  String get ticketsBrowse;

  /// No description provided for @ticketCancelConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ vé {event}?'**
  String ticketCancelConfirmTitle(String event);

  /// No description provided for @ticketCancelFreeBody.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ của bạn sẽ được nhả cho người khác.'**
  String get ticketCancelFreeBody;

  /// No description provided for @ticketCancelRefundBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn được hoàn {pct}% tiền vé.'**
  String ticketCancelRefundBody(int pct);

  /// No description provided for @ticketCancelNoRefundBody.
  ///
  /// In vi, this message translates to:
  /// **'Còn dưới 48 giờ nên không được hoàn tiền vé. Tiền vé được giữ tới khi sự kiện kết thúc.'**
  String get ticketCancelNoRefundBody;

  /// No description provided for @ticketKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ vé'**
  String get ticketKeep;

  /// No description provided for @ticketCancelDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ vé'**
  String get ticketCancelDone;

  /// No description provided for @ticketCancelUsed.
  ///
  /// In vi, this message translates to:
  /// **'Vé đã dùng, không huỷ được'**
  String get ticketCancelUsed;

  /// No description provided for @ticketQrClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get ticketQrClose;

  /// No description provided for @createEventTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo sự kiện'**
  String get createEventTitle;

  /// No description provided for @createEventInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin sự kiện'**
  String get createEventInfo;

  /// No description provided for @createEventCover.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh bìa 16:10'**
  String get createEventCover;

  /// No description provided for @createEventCoverChange.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ảnh bìa'**
  String get createEventCoverChange;

  /// No description provided for @createEventName.
  ///
  /// In vi, this message translates to:
  /// **'Tên sự kiện'**
  String get createEventName;

  /// No description provided for @createEventNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Tên sự kiện · bắt buộc'**
  String get createEventNameRequired;

  /// No description provided for @createEventType.
  ///
  /// In vi, this message translates to:
  /// **'Loại sự kiện'**
  String get createEventType;

  /// No description provided for @createEventDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get createEventDesc;

  /// No description provided for @createEventHost.
  ///
  /// In vi, this message translates to:
  /// **'Tổ chức bởi'**
  String get createEventHost;

  /// No description provided for @createEventHostPlatform.
  ///
  /// In vi, this message translates to:
  /// **'Nền tảng'**
  String get createEventHostPlatform;

  /// No description provided for @createEventHostLater.
  ///
  /// In vi, this message translates to:
  /// **'Tổ chức hộ một nhiếp ảnh gia sẽ có sau.'**
  String get createEventHostLater;

  /// No description provided for @createEventContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get createEventContinue;

  /// No description provided for @createEventSaveDraftAsk.
  ///
  /// In vi, this message translates to:
  /// **'Lưu nháp?'**
  String get createEventSaveDraftAsk;

  /// No description provided for @createEventDraftKeep.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get createEventDraftKeep;

  /// No description provided for @createEventDraftDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ'**
  String get createEventDraftDiscard;

  /// No description provided for @createEventSchedule.
  ///
  /// In vi, this message translates to:
  /// **'Lịch và vé'**
  String get createEventSchedule;

  /// No description provided for @createEventDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get createEventDay;

  /// No description provided for @createEventStart.
  ///
  /// In vi, this message translates to:
  /// **'Giờ bắt đầu'**
  String get createEventStart;

  /// No description provided for @createEventEnd.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get createEventEnd;

  /// No description provided for @createEventCapacity.
  ///
  /// In vi, this message translates to:
  /// **'Sức chứa'**
  String get createEventCapacity;

  /// No description provided for @createEventCapacityUnit.
  ///
  /// In vi, this message translates to:
  /// **'người'**
  String get createEventCapacityUnit;

  /// No description provided for @createEventPlace.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get createEventPlace;

  /// No description provided for @createEventMeeting.
  ///
  /// In vi, this message translates to:
  /// **'Điểm hẹn'**
  String get createEventMeeting;

  /// No description provided for @createEventArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực'**
  String get createEventArea;

  /// No description provided for @createEventAreaPick.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khu vực'**
  String get createEventAreaPick;

  /// No description provided for @createEventUseLocation.
  ///
  /// In vi, this message translates to:
  /// **'Dùng vị trí hiện tại'**
  String get createEventUseLocation;

  /// No description provided for @createEventLocationUsed.
  ///
  /// In vi, this message translates to:
  /// **'Đã lấy vị trí hiện tại'**
  String get createEventLocationUsed;

  /// No description provided for @createEventHashtag.
  ///
  /// In vi, this message translates to:
  /// **'Hashtag sự kiện'**
  String get createEventHashtag;

  /// No description provided for @createEventHashtagTaken.
  ///
  /// In vi, this message translates to:
  /// **'Hashtag này đã có sự kiện khác dùng'**
  String get createEventHashtagTaken;

  /// No description provided for @createEventPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá mỗi người (₫)'**
  String get createEventPrice;

  /// No description provided for @createEventDeadline.
  ///
  /// In vi, this message translates to:
  /// **'Hạn đăng ký'**
  String get createEventDeadline;

  /// No description provided for @createEventDeadlineAuto.
  ///
  /// In vi, this message translates to:
  /// **'Tự động'**
  String get createEventDeadlineAuto;

  /// No description provided for @createEventFreeHint.
  ///
  /// In vi, this message translates to:
  /// **'Để giá bằng 0 nếu không thu phí.'**
  String get createEventFreeHint;

  /// No description provided for @createEventEscrowHint.
  ///
  /// In vi, this message translates to:
  /// **'Tiền vé được giữ trên ứng dụng và chuyển cho bạn sau khi sự kiện kết thúc.'**
  String get createEventEscrowHint;

  /// No description provided for @createEventPreview.
  ///
  /// In vi, this message translates to:
  /// **'Xem trước'**
  String get createEventPreview;

  /// No description provided for @createEventSaveDraft.
  ///
  /// In vi, this message translates to:
  /// **'Lưu nháp'**
  String get createEventSaveDraft;

  /// No description provided for @createEventPublish.
  ///
  /// In vi, this message translates to:
  /// **'Đăng sự kiện'**
  String get createEventPublish;

  /// No description provided for @createEventPublished.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng sự kiện'**
  String get createEventPublished;

  /// No description provided for @createEventDraftSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu nháp'**
  String get createEventDraftSaved;

  /// No description provided for @createEventDayTaken.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã có lịch hôm đó'**
  String get createEventDayTaken;

  /// No description provided for @createEventErrorSummary.
  ///
  /// In vi, this message translates to:
  /// **'Cần sửa {n} mục trước khi đăng'**
  String createEventErrorSummary(int n);

  /// No description provided for @createEventPickDay.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày'**
  String get createEventPickDay;

  /// No description provided for @createEventPickTime.
  ///
  /// In vi, this message translates to:
  /// **'Chọn giờ'**
  String get createEventPickTime;

  /// No description provided for @createEventErrCover.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh bìa cho sự kiện'**
  String get createEventErrCover;

  /// No description provided for @createEventErrTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên sự kiện'**
  String get createEventErrTitle;

  /// No description provided for @createEventErrTitleLong.
  ///
  /// In vi, this message translates to:
  /// **'Tên sự kiện tối đa 80 ký tự'**
  String get createEventErrTitleLong;

  /// No description provided for @createEventErrType.
  ///
  /// In vi, this message translates to:
  /// **'Chọn loại sự kiện'**
  String get createEventErrType;

  /// No description provided for @createEventErrDescLong.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả tối đa 1000 ký tự'**
  String get createEventErrDescLong;

  /// No description provided for @createEventErrDay.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày diễn ra'**
  String get createEventErrDay;

  /// No description provided for @createEventErrStart.
  ///
  /// In vi, this message translates to:
  /// **'Chọn giờ bắt đầu'**
  String get createEventErrStart;

  /// No description provided for @createEventErrEnd.
  ///
  /// In vi, this message translates to:
  /// **'Chọn giờ kết thúc'**
  String get createEventErrEnd;

  /// No description provided for @createEventErrEndBeforeStart.
  ///
  /// In vi, this message translates to:
  /// **'Giờ kết thúc phải sau giờ bắt đầu'**
  String get createEventErrEndBeforeStart;

  /// No description provided for @createEventErrSameDay.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện diễn ra trong một ngày'**
  String get createEventErrSameDay;

  /// No description provided for @createEventErrStartSoon.
  ///
  /// In vi, this message translates to:
  /// **'Giờ bắt đầu phải sau bây giờ ít nhất 2 giờ'**
  String get createEventErrStartSoon;

  /// No description provided for @createEventErrCapacity.
  ///
  /// In vi, this message translates to:
  /// **'Sức chứa từ 1 đến 500 người'**
  String get createEventErrCapacity;

  /// No description provided for @createEventErrPlace.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên địa điểm'**
  String get createEventErrPlace;

  /// No description provided for @createEventErrPlacePoint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khu vực hoặc dùng vị trí hiện tại'**
  String get createEventErrPlacePoint;

  /// No description provided for @createEventErrPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá tiền là bội số của 1.000₫, tối đa 100.000.000₫'**
  String get createEventErrPrice;

  /// No description provided for @createEventErrPriceRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập giá, để 0 nếu không thu phí'**
  String get createEventErrPriceRequired;

  /// No description provided for @createEventErrDeadline.
  ///
  /// In vi, this message translates to:
  /// **'Hạn đăng ký phải trước giờ bắt đầu'**
  String get createEventErrDeadline;

  /// No description provided for @createEventErrHashtag.
  ///
  /// In vi, this message translates to:
  /// **'Hashtag gồm 3–40 chữ không dấu hoặc số'**
  String get createEventErrHashtag;

  /// No description provided for @createEventFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đăng được sự kiện. Kiểm tra mạng rồi thử lại.'**
  String get createEventFailed;

  /// No description provided for @createEventSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được nháp. Kiểm tra mạng rồi thử lại.'**
  String get createEventSaveFailed;

  /// No description provided for @createEventCoverFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh bìa. Thử lại nhé.'**
  String get createEventCoverFailed;

  /// No description provided for @createEventSetupTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thiện hồ sơ để tạo sự kiện'**
  String get createEventSetupTitle;

  /// No description provided for @createEventSetupBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần hoàn tất hồ sơ nhiếp ảnh gia trước khi tổ chức sự kiện.'**
  String get createEventSetupBody;

  /// No description provided for @createEventSetupCta.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thiện hồ sơ'**
  String get createEventSetupCta;

  /// No description provided for @createEventNotAllowed.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ nhiếp ảnh gia và nhân viên mới tạo được sự kiện.'**
  String get createEventNotAllowed;

  /// No description provided for @eventStatusDraft.
  ///
  /// In vi, this message translates to:
  /// **'Nháp'**
  String get eventStatusDraft;

  /// No description provided for @eventStatusOpen.
  ///
  /// In vi, this message translates to:
  /// **'Đang mở'**
  String get eventStatusOpen;

  /// No description provided for @eventStatusFull.
  ///
  /// In vi, this message translates to:
  /// **'Hết chỗ'**
  String get eventStatusFull;

  /// No description provided for @eventStatusClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng'**
  String get eventStatusClosed;

  /// No description provided for @eventStatusCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get eventStatusCancelled;

  /// No description provided for @eventStatusCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã kết thúc'**
  String get eventStatusCompleted;

  /// No description provided for @manageTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý sự kiện'**
  String get manageTitle;

  /// No description provided for @manageRegistered.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng ký'**
  String get manageRegistered;

  /// No description provided for @manageRevenue.
  ///
  /// In vi, this message translates to:
  /// **'Doanh thu'**
  String get manageRevenue;

  /// No description provided for @manageDaysLeft.
  ///
  /// In vi, this message translates to:
  /// **'Ngày còn lại'**
  String get manageDaysLeft;

  /// No description provided for @manageParticipants.
  ///
  /// In vi, this message translates to:
  /// **'Người tham gia'**
  String get manageParticipants;

  /// No description provided for @manageEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có người đăng ký'**
  String get manageEmpty;

  /// No description provided for @manageShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ sự kiện'**
  String get manageShare;

  /// No description provided for @manageViewPage.
  ///
  /// In vi, this message translates to:
  /// **'Xem trang sự kiện'**
  String get manageViewPage;

  /// No description provided for @manageBroadcast.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn nhóm'**
  String get manageBroadcast;

  /// No description provided for @manageBroadcastSoon.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn nhóm sắp mở'**
  String get manageBroadcastSoon;

  /// No description provided for @manageScan.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã check‑in'**
  String get manageScan;

  /// No description provided for @manageCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ sự kiện · hoàn tiền mọi vé'**
  String get manageCancel;

  /// No description provided for @manageCancelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ sự kiện này?'**
  String get manageCancelTitle;

  /// No description provided for @manageCancelBody.
  ///
  /// In vi, this message translates to:
  /// **'{n} vé · hoàn {amount}'**
  String manageCancelBody(int n, String amount);

  /// No description provided for @manageNoRefund.
  ///
  /// In vi, this message translates to:
  /// **'Không có khoản hoàn'**
  String get manageNoRefund;

  /// No description provided for @manageCancelConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ sự kiện'**
  String get manageCancelConfirm;

  /// No description provided for @manageCancelKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ sự kiện'**
  String get manageCancelKeep;

  /// No description provided for @manageCancelDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ sự kiện'**
  String get manageCancelDone;

  /// No description provided for @manageCancelFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không huỷ được sự kiện. Thử lại nhé.'**
  String get manageCancelFailed;

  /// No description provided for @manageGone.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy sự kiện'**
  String get manageGone;

  /// No description provided for @managePaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã trả'**
  String get managePaid;

  /// No description provided for @manageUnpaid.
  ///
  /// In vi, this message translates to:
  /// **'Chờ trả'**
  String get manageUnpaid;

  /// No description provided for @manageCheckedIn.
  ///
  /// In vi, this message translates to:
  /// **'Đã vào'**
  String get manageCheckedIn;

  /// No description provided for @manageTicketQty.
  ///
  /// In vi, this message translates to:
  /// **'{n} vé'**
  String manageTicketQty(int n);

  /// No description provided for @manageTicketCode.
  ///
  /// In vi, this message translates to:
  /// **'{n} vé · {code}'**
  String manageTicketCode(int n, String code);

  /// No description provided for @manageNoMoney.
  ///
  /// In vi, this message translates to:
  /// **'—'**
  String get manageNoMoney;

  /// No description provided for @manageScanClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã hết giờ check‑in'**
  String get manageScanClosed;

  /// No description provided for @manageInviteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời tổ chức sự kiện'**
  String get manageInviteTitle;

  /// No description provided for @manageInviteBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên đã tạo sự kiện này cho bạn. Hãy trả lời trước {time}, quá hạn sự kiện sẽ bị huỷ.'**
  String manageInviteBody(String time);

  /// No description provided for @manageInviteAccept.
  ///
  /// In vi, this message translates to:
  /// **'Chấp nhận'**
  String get manageInviteAccept;

  /// No description provided for @manageInviteDecline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get manageInviteDecline;

  /// No description provided for @manageInviteAccepted.
  ///
  /// In vi, this message translates to:
  /// **'Đã chấp nhận, nhân viên sẽ đăng sự kiện'**
  String get manageInviteAccepted;

  /// No description provided for @manageInviteDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối lời mời'**
  String get manageInviteDeclined;

  /// No description provided for @manageInviteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được câu trả lời. Thử lại nhé.'**
  String get manageInviteFailed;

  /// No description provided for @checkinOk.
  ///
  /// In vi, this message translates to:
  /// **'Đã vào · {name} · {count} vé'**
  String checkinOk(String name, int count);

  /// No description provided for @checkinInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Vé không hợp lệ'**
  String get checkinInvalid;

  /// No description provided for @checkinUsed.
  ///
  /// In vi, this message translates to:
  /// **'Vé đã dùng'**
  String get checkinUsed;

  /// No description provided for @checkinManual.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã vé'**
  String get checkinManual;

  /// No description provided for @checkinManualHint.
  ///
  /// In vi, this message translates to:
  /// **'Mã vé, ví dụ VE-7K2Q-0420'**
  String get checkinManualHint;

  /// No description provided for @checkinManualSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra'**
  String get checkinManualSubmit;

  /// No description provided for @checkinNext.
  ///
  /// In vi, this message translates to:
  /// **'Quét tiếp'**
  String get checkinNext;

  /// No description provided for @checkinScanTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã vé'**
  String get checkinScanTitle;

  /// No description provided for @checkinCameraOff.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được camera. Nhập mã vé để check‑in.'**
  String get checkinCameraOff;

  /// No description provided for @checkinFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không check‑in được. Thử lại nhé.'**
  String get checkinFailed;

  /// No description provided for @myEventsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện của tôi'**
  String get myEventsTitle;

  /// No description provided for @myEventsDraft.
  ///
  /// In vi, this message translates to:
  /// **'Nháp'**
  String get myEventsDraft;

  /// No description provided for @myEventsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa tổ chức sự kiện nào'**
  String get myEventsEmpty;

  /// No description provided for @myEventsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện bạn tạo sẽ hiện ở đây.'**
  String get myEventsEmptyBody;

  /// No description provided for @myEventsSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get myEventsSeeAll;

  /// No description provided for @settingsManageEvents.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý sự kiện'**
  String get settingsManageEvents;

  /// No description provided for @createPostTabPost.
  ///
  /// In vi, this message translates to:
  /// **'Bài đăng'**
  String get createPostTabPost;

  /// No description provided for @createPostTabEvent.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện'**
  String get createPostTabEvent;

  /// No description provided for @createEventLocationFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được vị trí. Hãy chọn khu vực nhé.'**
  String get createEventLocationFailed;

  /// No description provided for @createEventDeadlineReset.
  ///
  /// In vi, this message translates to:
  /// **'Dùng hạn tự động'**
  String get createEventDeadlineReset;

  /// S12.03: a scan, or the disabled scan button, before 00:00 VN on the event day (the server takes check-ins from then).
  ///
  /// In vi, this message translates to:
  /// **'Chưa tới ngày diễn ra. Check‑in mở từ 00:00 hôm đó.'**
  String get checkinNotYet;

  /// EventCard/DateBlock: spoken in place of the date of a draft whose day is not chosen yet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chọn ngày'**
  String get eventDateUnset;

  /// S11.05: how many visible posts the event timeline holds, next to the hashtag chip.
  ///
  /// In vi, this message translates to:
  /// **'{n} bài'**
  String timelineCount(int n);

  /// S11.05 bottom button; {tag} is the event hashtag with its #.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ảnh với {tag}'**
  String timelinePost(String tag);

  /// No description provided for @timelineEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh nào. Hãy là người đầu tiên chia sẻ!'**
  String get timelineEmpty;

  /// No description provided for @timelinePending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get timelinePending;

  /// No description provided for @timelineVisibleTab.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng'**
  String get timelineVisibleTab;

  /// No description provided for @timelinePendingEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có bài nào chờ duyệt.'**
  String get timelinePendingEmpty;

  /// No description provided for @timelineClosed.
  ///
  /// In vi, this message translates to:
  /// **'Timeline đã đóng đăng mới'**
  String get timelineClosed;

  /// No description provided for @timelineHide.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn khỏi timeline'**
  String get timelineHide;

  /// No description provided for @timelineApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get timelineApprove;

  /// No description provided for @timelineReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get timelineReport;

  /// No description provided for @timelineReportSoon.
  ///
  /// In vi, this message translates to:
  /// **'Sắp có'**
  String get timelineReportSoon;

  /// No description provided for @timelineHostSuffix.
  ///
  /// In vi, this message translates to:
  /// **'chủ sự kiện'**
  String get timelineHostSuffix;

  /// No description provided for @timelineModerateFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thực hiện được. Thử lại nhé.'**
  String get timelineModerateFailed;

  /// No description provided for @timelineItemLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh của {name}'**
  String timelineItemLabel(String name);

  /// No description provided for @timelineMenuHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn giữ để mở menu'**
  String get timelineMenuHint;

  /// No description provided for @shareTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ ảnh sự kiện'**
  String get shareTitle;

  /// No description provided for @shareSend.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get shareSend;

  /// No description provided for @shareCaptionHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết chú thích…'**
  String get shareCaptionHint;

  /// No description provided for @shareFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đăng được ảnh. Kiểm tra mạng rồi thử lại.'**
  String get shareFailed;

  /// No description provided for @shareClosed.
  ///
  /// In vi, this message translates to:
  /// **'Timeline đã đóng đăng mới.'**
  String get shareClosed;

  /// No description provided for @shareDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng lên timeline'**
  String get shareDone;

  /// No description provided for @shareDiscardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ bài đang soạn?'**
  String get shareDiscardTitle;

  /// No description provided for @shareKeepEditing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục soạn'**
  String get shareKeepEditing;

  /// S11.06 app bar subtitle.
  ///
  /// In vi, this message translates to:
  /// **'{n} thành viên'**
  String chatMembers(int n);

  /// No description provided for @chatPinned.
  ///
  /// In vi, this message translates to:
  /// **'Ghim'**
  String get chatPinned;

  /// No description provided for @eventChatInput.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn cho nhóm…'**
  String get eventChatInput;

  /// No description provided for @eventChatClosed.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm đã đóng'**
  String get eventChatClosed;

  /// No description provided for @chatMutedNote.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang bị tắt tiếng trong nhóm'**
  String get chatMutedNote;

  /// No description provided for @chatModOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ điều hành được nhắn'**
  String get chatModOnly;

  /// No description provided for @chatJoined.
  ///
  /// In vi, this message translates to:
  /// **'{name} đã vào nhóm'**
  String chatJoined(String name);

  /// No description provided for @chatPin.
  ///
  /// In vi, this message translates to:
  /// **'Ghim'**
  String get chatPin;

  /// No description provided for @chatUnpin.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ ghim'**
  String get chatUnpin;

  /// No description provided for @chatDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get chatDelete;

  /// No description provided for @chatDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn đã bị xoá'**
  String get chatDeleted;

  /// No description provided for @chatMute24h.
  ///
  /// In vi, this message translates to:
  /// **'Tắt tiếng 24 giờ'**
  String get chatMute24h;

  /// No description provided for @chatUnmute.
  ///
  /// In vi, this message translates to:
  /// **'Bật tiếng'**
  String get chatUnmute;

  /// No description provided for @chatRemove.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ khỏi nhóm'**
  String get chatRemove;

  /// No description provided for @chatRemoveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ {name} khỏi nhóm?'**
  String chatRemoveTitle(String name);

  /// No description provided for @chatMemberList.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get chatMemberList;

  /// No description provided for @chatMemberModerator.
  ///
  /// In vi, this message translates to:
  /// **'Điều hành'**
  String get chatMemberModerator;

  /// No description provided for @chatMemberMuted.
  ///
  /// In vi, this message translates to:
  /// **'Đang bị tắt tiếng'**
  String get chatMemberMuted;

  /// No description provided for @chatMuteGroup.
  ///
  /// In vi, this message translates to:
  /// **'Tắt tiếng nhóm'**
  String get chatMuteGroup;

  /// No description provided for @chatUnmuteGroup.
  ///
  /// In vi, this message translates to:
  /// **'Bật tiếng nhóm'**
  String get chatUnmuteGroup;

  /// No description provided for @chatRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn nhắn quá nhanh. Thử lại sau ít giây nhé.'**
  String get chatRateLimited;

  /// No description provided for @chatActionFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thực hiện được. Thử lại nhé.'**
  String get chatActionFailed;

  /// No description provided for @chatLockedAction.
  ///
  /// In vi, this message translates to:
  /// **'Xem sự kiện'**
  String get chatLockedAction;

  /// No description provided for @chatMessageOf.
  ///
  /// In vi, this message translates to:
  /// **'{name}: {text}'**
  String chatMessageOf(String name, String text);

  /// No description provided for @manageAnnounceTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghim thông báo vào nhóm'**
  String get manageAnnounceTitle;

  /// No description provided for @manageAnnounceHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết thông báo cho cả nhóm'**
  String get manageAnnounceHint;

  /// No description provided for @manageAnnounceSend.
  ///
  /// In vi, this message translates to:
  /// **'Ghim'**
  String get manageAnnounceSend;

  /// No description provided for @manageAnnounceDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghim thông báo vào nhóm'**
  String get manageAnnounceDone;

  /// No description provided for @manageAnnounceFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không ghim được thông báo. Thử lại nhé.'**
  String get manageAnnounceFailed;

  /// No description provided for @managePending.
  ///
  /// In vi, this message translates to:
  /// **'Bài chờ duyệt'**
  String get managePending;

  /// S02.02: the chip under the caption of a photo shared to an event.
  ///
  /// In vi, this message translates to:
  /// **'Sự kiện: {title}'**
  String postEventChip(String title);

  /// S11.06 member list: section header of the members a moderator removed (moderators only).
  ///
  /// In vi, this message translates to:
  /// **'Đã mời ra'**
  String get chatRemovedSection;

  /// S11.06 member list: moderator action that lifts a removal.
  ///
  /// In vi, this message translates to:
  /// **'Cho vào lại'**
  String get chatRestore;

  /// S11.06 member list: note under the Đã mời ra section.
  ///
  /// In vi, this message translates to:
  /// **'Vào lại ngay nếu còn vé; nếu không, khi mua vé mới.'**
  String get chatRestoreHint;

  /// S12.03: link at the right of the Người tham gia header; opens the check-in scanner.
  ///
  /// In vi, this message translates to:
  /// **'Check‑in'**
  String get manageCheckinLink;

  /// S11.03 paid: the total line of the money table.
  ///
  /// In vi, this message translates to:
  /// **'Tổng thanh toán'**
  String get registerTotal;

  /// S11.03 paid: tickets times the ticket price.
  ///
  /// In vi, this message translates to:
  /// **'{n} vé × {price}'**
  String registerLine(int n, String price);

  /// S11.03 paid: the primary button.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán {amount}'**
  String registerPay(String amount);

  /// No description provided for @registerHoldExpired.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ giữ đã hết hạn'**
  String get registerHoldExpired;

  /// No description provided for @registerPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ trước 48 giờ hoàn 100%. Vé được giữ 10 phút trong lúc thanh toán.'**
  String get registerPolicy;

  /// No description provided for @escrowNoticeTicket.
  ///
  /// In vi, this message translates to:
  /// **'Tiền vé được giữ an toàn trên ứng dụng cho tới khi sự kiện kết thúc.'**
  String get escrowNoticeTicket;

  /// No description provided for @ticketPayContinue.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán tiếp'**
  String get ticketPayContinue;

  /// No description provided for @ticketHoldExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get ticketHoldExpired;

  /// No description provided for @ticketRefundAmount.
  ///
  /// In vi, this message translates to:
  /// **'Bạn nhận lại {amount}'**
  String ticketRefundAmount(String amount);

  /// No description provided for @ticketNoRefund.
  ///
  /// In vi, this message translates to:
  /// **'Vé không được hoàn tiền khi huỷ trong vòng 48 giờ.'**
  String get ticketNoRefund;

  /// S11.03 (mock): pay by bank transfer QR.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản QR'**
  String get payMethodBankQr;

  /// No description provided for @payMethodMomo.
  ///
  /// In vi, this message translates to:
  /// **'MoMo'**
  String get payMethodMomo;

  /// No description provided for @payMethodZaloPay.
  ///
  /// In vi, this message translates to:
  /// **'ZaloPay'**
  String get payMethodZaloPay;

  /// S04.03 (mock): sub-label of the bank QR option.
  ///
  /// In vi, this message translates to:
  /// **'Miễn phí · xác nhận ngay'**
  String get payMethodBankQrNote;

  /// S04.03: createPayment refused a 4th attempt for the booking (payment_attempts_exceeded).
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo QR 3 lần. Hãy đặt lại từ đầu.'**
  String get payAttemptsExceeded;

  /// Semantics label of the payment method group on S11.03.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức thanh toán'**
  String get payMethodLabel;

  /// S11.04: a cancelled ticket whose payment came after the hold and was refunded.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ · đã hoàn tiền'**
  String get ticketCancelledRefunded;

  /// S11.04: as above while the refund is still on its way.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ · đang hoàn tiền'**
  String get ticketCancelledRefunding;

  /// Featured S11.01 card overlay: seats taken of the capacity, no spaces (mock).
  ///
  /// In vi, this message translates to:
  /// **'{registered}/{capacity} đã đăng ký'**
  String eventRegisteredOf(int registered, int capacity);

  /// No description provided for @createEventFaqHint.
  ///
  /// In vi, this message translates to:
  /// **'Hiện ở trang sự kiện để khách đọc trước khi đăng ký. Tối đa {max} câu.'**
  String createEventFaqHint(int max);

  /// No description provided for @createEventFaqQuestion.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi {n}'**
  String createEventFaqQuestion(int n);

  /// No description provided for @createEventFaqAnswer.
  ///
  /// In vi, this message translates to:
  /// **'Trả lời'**
  String get createEventFaqAnswer;

  /// No description provided for @createEventFaqAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm câu hỏi'**
  String get createEventFaqAdd;

  /// No description provided for @createEventFaqRemove.
  ///
  /// In vi, this message translates to:
  /// **'Xoá câu hỏi {n}'**
  String createEventFaqRemove(int n);

  /// No description provided for @createEventErrFaq.
  ///
  /// In vi, this message translates to:
  /// **'Nhập đủ cả câu hỏi và câu trả lời.'**
  String get createEventErrFaq;

  /// No description provided for @bookNotAcceptingOrders.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia này chưa nhận đặt lịch.'**
  String get bookNotAcceptingOrders;

  /// S04: createBooking/createPayment refused because the customer and the photographer blocked each other (blocked).
  ///
  /// In vi, this message translates to:
  /// **'Không đặt lịch được với người này.'**
  String get bookingErrBlocked;

  /// No description provided for @savedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu'**
  String get savedTitle;

  /// No description provided for @savedTabPosts.
  ///
  /// In vi, this message translates to:
  /// **'Bài · {count}'**
  String savedTabPosts(int count);

  /// No description provided for @savedTabPhotographers.
  ///
  /// In vi, this message translates to:
  /// **'Nhiếp ảnh gia · {count}'**
  String savedTabPhotographers(int count);

  /// No description provided for @savedPostsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa lưu bài nào'**
  String get savedPostsEmptyTitle;

  /// No description provided for @savedPostsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Bấm biểu tượng lưu trên ảnh để xem lại ở đây.'**
  String get savedPostsEmptyBody;

  /// No description provided for @savedPhotographersEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa lưu nhiếp ảnh gia nào'**
  String get savedPhotographersEmptyTitle;

  /// No description provided for @savedPhotographersEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Bấm biểu tượng lưu trên hồ sơ nhiếp ảnh gia để so sánh và đặt lịch sau.'**
  String get savedPhotographersEmptyBody;

  /// No description provided for @savedUnsaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ lưu {name}'**
  String savedUnsaved(String name);

  /// No description provided for @savedUndo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get savedUndo;

  /// No description provided for @savedBook.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get savedBook;

  /// No description provided for @savedToggleOn.
  ///
  /// In vi, this message translates to:
  /// **'Lưu {name}'**
  String savedToggleOn(String name);

  /// No description provided for @savedToggleOff.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ lưu {name}'**
  String savedToggleOff(String name);

  /// No description provided for @followingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đang theo dõi'**
  String get followingTitle;

  /// No description provided for @followingCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} nhiếp ảnh gia'**
  String followingCount(int count);

  /// No description provided for @followingButton.
  ///
  /// In vi, this message translates to:
  /// **'Đang theo dõi'**
  String get followingButton;

  /// No description provided for @followButton.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi'**
  String get followButton;

  /// No description provided for @followingUnfollowed.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ theo dõi {name}'**
  String followingUnfollowed(String name);

  /// No description provided for @followingEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa theo dõi ai'**
  String get followingEmptyTitle;

  /// No description provided for @followingEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi nhiếp ảnh gia để thấy bài mới của họ trước.'**
  String get followingEmptyBody;

  /// No description provided for @followingEmptyAction.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get followingEmptyAction;

  /// No description provided for @followersTitle.
  ///
  /// In vi, this message translates to:
  /// **'Người theo dõi'**
  String get followersTitle;

  /// No description provided for @followersCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} người theo dõi · chỉ bạn xem được danh sách này'**
  String followersCount(int count);

  /// No description provided for @followersSince.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi từ {date}'**
  String followersSince(String date);

  /// No description provided for @followersEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có người theo dõi'**
  String get followersEmptyTitle;

  /// No description provided for @followersEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài thường xuyên để có thêm người theo dõi.'**
  String get followersEmptyBody;

  /// No description provided for @profileCountFollowers.
  ///
  /// In vi, this message translates to:
  /// **'người theo dõi'**
  String get profileCountFollowers;

  /// No description provided for @profileUnsavePhotographer.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ lưu nhiếp ảnh gia'**
  String get profileUnsavePhotographer;

  /// No description provided for @reasonFollowing.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang theo dõi'**
  String get reasonFollowing;

  /// No description provided for @socialToggleFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa lưu được. Thử lại.'**
  String get socialToggleFailed;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh số điện thoại'**
  String get verifyPhoneTitle;

  /// No description provided for @verifyPhoneHeading.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số điện thoại của bạn'**
  String get verifyPhoneHeading;

  /// No description provided for @verifyPhoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi gửi mã 6 số qua SMS. Số này dùng để liên hệ khi có đơn, không hiện công khai.'**
  String get verifyPhoneBody;

  /// No description provided for @verifyPhoneExample.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 0912 345 678.'**
  String get verifyPhoneExample;

  /// No description provided for @verifyPhoneSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi mã'**
  String get verifyPhoneSend;

  /// No description provided for @verifyCodeHeading.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã 6 số'**
  String get verifyCodeHeading;

  /// No description provided for @verifyCodeSentTo.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi tới •••• {last4}'**
  String verifyCodeSentTo(String last4);

  /// No description provided for @verifyCodeResendIn.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại mã sau {time}'**
  String verifyCodeResendIn(String time);

  /// No description provided for @verifyCodeResend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại mã'**
  String get verifyCodeResend;

  /// No description provided for @verifyCodeChangePhone.
  ///
  /// In vi, this message translates to:
  /// **'Đổi số điện thoại'**
  String get verifyCodeChangePhone;

  /// No description provided for @verifyCodeConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get verifyCodeConfirm;

  /// No description provided for @verifyCodeWrong.
  ///
  /// In vi, this message translates to:
  /// **'Mã không đúng. Kiểm tra lại tin nhắn.'**
  String get verifyCodeWrong;

  /// No description provided for @verifyCodeExpired.
  ///
  /// In vi, this message translates to:
  /// **'Mã đã hết hạn. Bấm Gửi lại mã.'**
  String get verifyCodeExpired;

  /// No description provided for @verifyPhoneTooMany.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã thử quá nhiều lần. Thử lại sau ít phút.'**
  String get verifyPhoneTooMany;

  /// No description provided for @verifyPhoneInUse.
  ///
  /// In vi, this message translates to:
  /// **'Số này đã gắn với một tài khoản khác.'**
  String get verifyPhoneInUse;

  /// No description provided for @verifyPhoneInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại chưa đúng. Ví dụ: 0912 345 678.'**
  String get verifyPhoneInvalid;

  /// No description provided for @verifyPhoneDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh số điện thoại'**
  String get verifyPhoneDone;

  /// No description provided for @verifyStartTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu nhận đơn'**
  String get verifyStartTitle;

  /// No description provided for @verifyStepCounter.
  ///
  /// In vi, this message translates to:
  /// **'{n} / {total}'**
  String verifyStepCounter(int n, int total);

  /// No description provided for @verifyStartIntro.
  ///
  /// In vi, this message translates to:
  /// **'Làm từng bước, lưu lại tiến độ. Thoát giữa chừng thì lần sau làm tiếp từ bước đang dở.'**
  String get verifyStartIntro;

  /// No description provided for @verifyStepPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get verifyStepPhone;

  /// No description provided for @verifyStepPhoneTodo.
  ///
  /// In vi, this message translates to:
  /// **'Nhận mã 6 số qua SMS'**
  String get verifyStepPhoneTodo;

  /// No description provided for @verifyStepPhoneDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh · •••• {last4}'**
  String verifyStepPhoneDone(String last4);

  /// S21.02 fee row title, amount already formatted (99.000₫).
  ///
  /// In vi, this message translates to:
  /// **'Phí xác minh {amount}'**
  String verifyStepFee(String amount);

  /// Subtitle of an individual's fee row: names the other kind's price, as the mock.
  ///
  /// In vi, this message translates to:
  /// **'Studio 299.000₫ · trả bằng QR hoặc ví'**
  String get verifyStepFeeTodoIndividual;

  /// Subtitle of a studio's fee row: names the other kind's price, as the mock.
  ///
  /// In vi, this message translates to:
  /// **'Thợ ảnh cá nhân 99.000₫ · trả bằng QR hoặc ví'**
  String get verifyStepFeeTodoStudio;

  /// No description provided for @verifyStepFeeDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã trả {amount}'**
  String verifyStepFeeDone(String amount);

  /// No description provided for @verifyFeeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phí xác minh'**
  String get verifyFeeTitle;

  /// No description provided for @verifyFeeYouGet.
  ///
  /// In vi, this message translates to:
  /// **'Bạn nhận được'**
  String get verifyFeeYouGet;

  /// No description provided for @verifyFeeBenefitTick.
  ///
  /// In vi, this message translates to:
  /// **'Tích xanh cạnh tên trên hồ sơ'**
  String get verifyFeeBenefitTick;

  /// No description provided for @verifyFeeBenefitOrders.
  ///
  /// In vi, this message translates to:
  /// **'Nhận đơn đặt lịch và gửi báo giá'**
  String get verifyFeeBenefitOrders;

  /// No description provided for @verifyFeeBenefitReview.
  ///
  /// In vi, this message translates to:
  /// **'Staff duyệt trong 24 giờ'**
  String get verifyFeeBenefitReview;

  /// No description provided for @verifyFeeKindIndividual.
  ///
  /// In vi, this message translates to:
  /// **'Thợ ảnh cá nhân · studio 299.000₫'**
  String get verifyFeeKindIndividual;

  /// No description provided for @verifyFeeKindStudio.
  ///
  /// In vi, this message translates to:
  /// **'Studio · thợ ảnh cá nhân 99.000₫'**
  String get verifyFeeKindStudio;

  /// No description provided for @verifyFeeNoRefund.
  ///
  /// In vi, this message translates to:
  /// **'Phí không hoàn vì chi phí kiểm tra đã phát sinh; bị từ chối được gửi lại miễn phí 1 lần.'**
  String get verifyFeeNoRefund;

  /// No description provided for @verifyFeePay.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán {amount}'**
  String verifyFeePay(String amount);

  /// No description provided for @verifyFeePaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận phí xác minh'**
  String get verifyFeePaid;

  /// No description provided for @verifyFeeFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thanh toán được. Thử lại.'**
  String get verifyFeeFailed;

  /// No description provided for @verifyStepIdentity.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh danh tính'**
  String get verifyStepIdentity;

  /// No description provided for @verifyStepIdentityTodo.
  ///
  /// In vi, this message translates to:
  /// **'VNeID hoặc quét chip CCCD'**
  String get verifyStepIdentityTodo;

  /// No description provided for @verifyStepIdentityDoneVneid.
  ///
  /// In vi, this message translates to:
  /// **'Đã khớp qua VNeID'**
  String get verifyStepIdentityDoneVneid;

  /// No description provided for @verifyStepIdentityDoneNfc.
  ///
  /// In vi, this message translates to:
  /// **'Đã khớp qua chip CCCD'**
  String get verifyStepIdentityDoneNfc;

  /// No description provided for @verifyStepRules.
  ///
  /// In vi, this message translates to:
  /// **'Đồng ý quy định nhận việc'**
  String get verifyStepRules;

  /// No description provided for @verifyStepRulesTodo.
  ///
  /// In vi, this message translates to:
  /// **'5 điều chính và một dấu tích'**
  String get verifyStepRulesTodo;

  /// No description provided for @verifyStepRulesDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã đồng ý'**
  String get verifyStepRulesDone;

  /// No description provided for @verifyStateDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get verifyStateDone;

  /// No description provided for @verifyStateNow.
  ///
  /// In vi, this message translates to:
  /// **'Đang làm'**
  String get verifyStateNow;

  /// No description provided for @verifyStateTodo.
  ///
  /// In vi, this message translates to:
  /// **'Chưa làm'**
  String get verifyStateTodo;

  /// No description provided for @verifyStateFix.
  ///
  /// In vi, this message translates to:
  /// **'Cần sửa'**
  String get verifyStateFix;

  /// No description provided for @verifyStartNote.
  ///
  /// In vi, this message translates to:
  /// **'Xong {total} bước thì bấm \"Gửi duyệt\". Staff duyệt trong 24 giờ; được duyệt là có tích xanh và nhận đơn ngay.'**
  String verifyStartNote(int total);

  /// No description provided for @verifyContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get verifyContinue;

  /// No description provided for @verifySubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi duyệt'**
  String get verifySubmit;

  /// An instant on today's Vietnamese date, e.g. 9:12 hôm nay (mock S21.02-pending).
  ///
  /// In vi, this message translates to:
  /// **'{time} hôm nay'**
  String verifyAtToday(String time);

  /// No description provided for @verifyAtTomorrow.
  ///
  /// In vi, this message translates to:
  /// **'{time} ngày mai'**
  String verifyAtTomorrow(String time);

  /// No description provided for @verifyAtDate.
  ///
  /// In vi, this message translates to:
  /// **'{time} ngày {date}'**
  String verifyAtDate(String time, String date);

  /// No description provided for @verifyRulesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quy định nhận việc'**
  String get verifyRulesTitle;

  /// No description provided for @verifyRulesIntro.
  ///
  /// In vi, this message translates to:
  /// **'Đọc 5 điều chính trước khi gửi duyệt.'**
  String get verifyRulesIntro;

  /// No description provided for @verifyRule1.
  ///
  /// In vi, this message translates to:
  /// **'Khách trả 100% khi đặt; tiền được giữ và chuyển cho bạn theo 2 mốc: sau buổi chụp, và sau khi khách đồng ý ảnh + 48 giờ.'**
  String get verifyRule1;

  /// No description provided for @verifyRule2.
  ///
  /// In vi, this message translates to:
  /// **'Bàn giao hai lớp: gửi ảnh mẫu có watermark trước; link ảnh gốc chỉ mở khi khách đồng ý.'**
  String get verifyRule2;

  /// No description provided for @verifyRule3.
  ///
  /// In vi, this message translates to:
  /// **'Khách huỷ trước 48 giờ được hoàn 100%, 24–48 giờ hoàn 50%, dưới 24 giờ không hoàn; bạn huỷ thì khách được hoàn 100%.'**
  String get verifyRule3;

  /// No description provided for @verifyRule4.
  ///
  /// In vi, this message translates to:
  /// **'Thợ cá nhân: nền tảng khấu trừ và nộp thay thuế trên phần chi trả cho bạn.'**
  String get verifyRule4;

  /// No description provided for @verifyRule5.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên, ngày sinh, số định danh được mã hoá; không lưu ảnh selfie; chỉ dùng để xác minh, chống trùng tài khoản và khấu trừ thuế.'**
  String get verifyRule5;

  /// No description provided for @verifyRulesAgree.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đã đọc và đồng ý quy định nhận việc'**
  String get verifyRulesAgree;

  /// No description provided for @verifyPendingHeading.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ duyệt · trong 24 giờ'**
  String get verifyPendingHeading;

  /// No description provided for @verifyPendingSent.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lúc {time} · có kết quả trước {deadline}'**
  String verifyPendingSent(String time, String deadline);

  /// No description provided for @verifyTlFee.
  ///
  /// In vi, this message translates to:
  /// **'Đã trả phí xác minh'**
  String get verifyTlFee;

  /// No description provided for @verifyTlFeeBody.
  ///
  /// In vi, this message translates to:
  /// **'{when} · {amount}'**
  String verifyTlFeeBody(String when, String amount);

  /// No description provided for @verifyTlIdentity.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh danh tính'**
  String get verifyTlIdentity;

  /// No description provided for @verifyTlIdentityBody.
  ///
  /// In vi, this message translates to:
  /// **'{method} · {name}'**
  String verifyTlIdentityBody(String method, String name);

  /// No description provided for @verifyMethodVneid.
  ///
  /// In vi, this message translates to:
  /// **'VNeID'**
  String get verifyMethodVneid;

  /// No description provided for @verifyMethodNfc.
  ///
  /// In vi, this message translates to:
  /// **'Chip CCCD'**
  String get verifyMethodNfc;

  /// No description provided for @verifyTlSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi duyệt'**
  String get verifyTlSubmitted;

  /// No description provided for @verifyTlSubmittedBody.
  ///
  /// In vi, this message translates to:
  /// **'{when} · đã đồng ý quy định nhận việc'**
  String verifyTlSubmittedBody(String when);

  /// No description provided for @verifyTlReview.
  ///
  /// In vi, this message translates to:
  /// **'Staff duyệt'**
  String get verifyTlReview;

  /// No description provided for @verifyTlReviewBody.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt xong là có tích xanh và nhận đơn'**
  String get verifyTlReviewBody;

  /// No description provided for @verifyPendingNote.
  ///
  /// In vi, this message translates to:
  /// **'Trong lúc chờ, bạn vẫn sửa portfolio, tạo gói và trò chuyện với khách.'**
  String get verifyPendingNote;

  /// No description provided for @verifyViewProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ'**
  String get verifyViewProfile;

  /// No description provided for @verifyRejectedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ chưa được duyệt'**
  String get verifyRejectedTitle;

  /// No description provided for @verifyRejectedReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do: {reason}'**
  String verifyRejectedReason(String reason);

  /// No description provided for @verifyReject_fake_avatar.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện không phải ảnh người thật. Đổi sang ảnh chân dung rõ mặt của bạn rồi gửi lại.'**
  String get verifyReject_fake_avatar;

  /// No description provided for @verifyReject_stolen_portfolio.
  ///
  /// In vi, this message translates to:
  /// **'Portfolio có ảnh không phải của bạn. Gỡ những ảnh đó rồi gửi lại.'**
  String get verifyReject_stolen_portfolio;

  /// No description provided for @verifyReject_identity_mismatch.
  ///
  /// In vi, this message translates to:
  /// **'Danh tính không khớp với tên trên hồ sơ. Xác minh lại danh tính rồi gửi lại.'**
  String get verifyReject_identity_mismatch;

  /// No description provided for @verifyReject_duplicate_account.
  ///
  /// In vi, this message translates to:
  /// **'Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn.'**
  String get verifyReject_duplicate_account;

  /// No description provided for @verifyReject_underage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần đủ 18 tuổi để nhận đơn.'**
  String get verifyReject_underage;

  /// No description provided for @verifyFreeResubmitsLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {n} lần gửi lại miễn phí'**
  String verifyFreeResubmitsLeft(int n);

  /// No description provided for @verifyNoFreeResubmit.
  ///
  /// In vi, this message translates to:
  /// **'Hết lượt gửi lại miễn phí · gửi lại cần trả phí xác minh mới'**
  String get verifyNoFreeResubmit;

  /// No description provided for @verifyFixAvatar.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện'**
  String get verifyFixAvatar;

  /// No description provided for @verifyFixAvatarBody.
  ///
  /// In vi, this message translates to:
  /// **'Cần ảnh chân dung thật, rõ mặt'**
  String get verifyFixAvatarBody;

  /// No description provided for @verifyFixPortfolio.
  ///
  /// In vi, this message translates to:
  /// **'Portfolio'**
  String get verifyFixPortfolio;

  /// No description provided for @verifyFixPortfolioBody.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ ảnh không phải của bạn'**
  String get verifyFixPortfolioBody;

  /// No description provided for @verifyFixIdentity.
  ///
  /// In vi, this message translates to:
  /// **'Danh tính'**
  String get verifyFixIdentity;

  /// No description provided for @verifyRejectedNote.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ sửa mục bị từ chối; các bước đã xong được giữ nguyên. Gửi lại thì staff duyệt trong 24 giờ.'**
  String get verifyRejectedNote;

  /// No description provided for @verifyResubmit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa và gửi lại'**
  String get verifyResubmit;

  /// No description provided for @verifyApprovedHeading.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã có thể nhận đơn'**
  String get verifyApprovedHeading;

  /// No description provided for @verifyApprovedBody.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt lúc {when}. Tích xanh đã hiện cạnh tên bạn.'**
  String verifyApprovedBody(String when);

  /// No description provided for @verifyRevokedHeading.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh đã bị thu hồi'**
  String get verifyRevokedHeading;

  /// No description provided for @verifyRevokedBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm.'**
  String get verifyRevokedBody;

  /// No description provided for @verifySupportLine.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ: {email}'**
  String verifySupportLine(String email);

  /// No description provided for @verifyIdTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh danh tính'**
  String get verifyIdTitle;

  /// No description provided for @verifyIdHeading.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh bằng căn cước điện tử'**
  String get verifyIdHeading;

  /// No description provided for @verifyIdBody.
  ///
  /// In vi, this message translates to:
  /// **'Không cần gõ hay chụp giấy tờ: mở app VNeID, đồng ý chia sẻ rồi nhập mã PIN VNeID.'**
  String get verifyIdBody;

  /// No description provided for @verifyIdWeOnlyGet.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi chỉ nhận'**
  String get verifyIdWeOnlyGet;

  /// No description provided for @verifyIdFieldName.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên'**
  String get verifyIdFieldName;

  /// No description provided for @verifyIdFieldDob.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get verifyIdFieldDob;

  /// No description provided for @verifyIdFieldNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số định danh'**
  String get verifyIdFieldNumber;

  /// No description provided for @verifyIdPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu ảnh selfie. Dùng để khớp tên tài khoản nhận tiền và chống giả mạo; số định danh được mã hoá.'**
  String get verifyIdPrivacy;

  /// No description provided for @verifyIdConsent.
  ///
  /// In vi, this message translates to:
  /// **'Bấm \"Xác minh bằng VNeID\" là bạn đồng ý chia sẻ ba thông tin trên.'**
  String get verifyIdConsent;

  /// No description provided for @verifyIdNfcLink.
  ///
  /// In vi, this message translates to:
  /// **'Không dùng được VNeID? Quét chip CCCD'**
  String get verifyIdNfcLink;

  /// No description provided for @verifyIdVneid.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh bằng VNeID'**
  String get verifyIdVneid;

  /// No description provided for @verifyNfcTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quét chip CCCD'**
  String get verifyNfcTitle;

  /// No description provided for @verifyNfcStep1.
  ///
  /// In vi, this message translates to:
  /// **'Bước 1/2 · Đọc chip'**
  String get verifyNfcStep1;

  /// No description provided for @verifyNfcStep2.
  ///
  /// In vi, this message translates to:
  /// **'Bước 2/2 · Selfie'**
  String get verifyNfcStep2;

  /// No description provided for @verifyNfcHeading.
  ///
  /// In vi, this message translates to:
  /// **'Áp CCCD vào mặt sau điện thoại'**
  String get verifyNfcHeading;

  /// No description provided for @verifyNfcBody.
  ///
  /// In vi, this message translates to:
  /// **'Giữ yên thẻ ở giữa lưng máy tới khi máy rung. Tháo ốp lưng dày nếu đọc chậm.'**
  String get verifyNfcBody;

  /// No description provided for @verifyNfcNextTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp theo'**
  String get verifyNfcNextTitle;

  /// No description provided for @verifyNfcNextBody.
  ///
  /// In vi, this message translates to:
  /// **'Chụp selfie để kiểm tra người thật'**
  String get verifyNfcNextBody;

  /// No description provided for @verifyNfcNote.
  ///
  /// In vi, this message translates to:
  /// **'Máy cần có NFC. Ảnh selfie chỉ dùng để so với ảnh trong chip, không lưu.'**
  String get verifyNfcNote;

  /// No description provided for @verifyNfcStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu quét'**
  String get verifyNfcStart;

  /// No description provided for @verifySelfieHeading.
  ///
  /// In vi, this message translates to:
  /// **'Chụp selfie 3–5 giây'**
  String get verifySelfieHeading;

  /// No description provided for @verifySelfieBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhìn thẳng vào camera, quay đầu chậm sang trái rồi sang phải.'**
  String get verifySelfieBody;

  /// No description provided for @verifySelfieNote.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh selfie chỉ dùng để so với ảnh trong chip, không lưu.'**
  String get verifySelfieNote;

  /// No description provided for @verifySelfieStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu chụp'**
  String get verifySelfieStart;

  /// No description provided for @verifyIdPassed.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh: {name}'**
  String verifyIdPassed(String name);

  /// No description provided for @verifyIdUnderage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần đủ 18 tuổi để nhận đơn.'**
  String get verifyIdUnderage;

  /// No description provided for @verifyIdInUse.
  ///
  /// In vi, this message translates to:
  /// **'Danh tính này đã gắn với một tài khoản nhận đơn khác. Liên hệ hỗ trợ nếu đây là nhầm lẫn.'**
  String get verifyIdInUse;

  /// No description provided for @verifyIdRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã thử 3 lần hôm nay. Thử lại vào ngày mai.'**
  String get verifyIdRateLimited;

  /// No description provided for @verifyIdFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác minh được. Thử lại hoặc dùng cách khác.'**
  String get verifyIdFailed;

  /// No description provided for @verifyIdFakeTitle.
  ///
  /// In vi, this message translates to:
  /// **'VNeID (giả lập)'**
  String get verifyIdFakeTitle;

  /// No description provided for @verifyIdFakeBody.
  ///
  /// In vi, this message translates to:
  /// **'Môi trường thử: không mở app VNeID thật. Bấm Đồng ý để nhận một danh tính thử.'**
  String get verifyIdFakeBody;

  /// No description provided for @verifyIdFakeAgree.
  ///
  /// In vi, this message translates to:
  /// **'Đồng ý chia sẻ'**
  String get verifyIdFakeAgree;

  /// No description provided for @verifyBizTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh doanh nghiệp'**
  String get verifyBizTitle;

  /// No description provided for @verifyBizIntro.
  ///
  /// In vi, this message translates to:
  /// **'Cần cho con dấu Studio, hơn 3 thành viên và tài khoản nhận tiền đứng tên công ty. Không cần để nhận đơn.'**
  String get verifyBizIntro;

  /// No description provided for @verifyBizTaxCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế'**
  String get verifyBizTaxCode;

  /// No description provided for @verifyBizLookup.
  ///
  /// In vi, this message translates to:
  /// **'Tra cứu'**
  String get verifyBizLookup;

  /// No description provided for @verifyBizName.
  ///
  /// In vi, this message translates to:
  /// **'Tên'**
  String get verifyBizName;

  /// No description provided for @verifyBizAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get verifyBizAddress;

  /// No description provided for @verifyBizStatus.
  ///
  /// In vi, this message translates to:
  /// **'Tình trạng'**
  String get verifyBizStatus;

  /// No description provided for @verifyBizActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoạt động'**
  String get verifyBizActive;

  /// No description provided for @verifyBizInactive.
  ///
  /// In vi, this message translates to:
  /// **'Ngừng hoạt động'**
  String get verifyBizInactive;

  /// No description provided for @verifyBizDocTitle.
  ///
  /// In vi, this message translates to:
  /// **'Người đại diện: cần ảnh giấy đăng ký kinh doanh'**
  String get verifyBizDocTitle;

  /// No description provided for @verifyBizDocBody.
  ///
  /// In vi, this message translates to:
  /// **'Staff đối chiếu người đại diện với chủ studio đã xác minh'**
  String get verifyBizDocBody;

  /// No description provided for @verifyBizHouseholdNote.
  ///
  /// In vi, this message translates to:
  /// **'Hộ kinh doanh: mã số thuế là số định danh của chủ, tự khớp, không cần tải giấy.'**
  String get verifyBizHouseholdNote;

  /// No description provided for @verifyBizSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi duyệt'**
  String get verifyBizSubmit;

  /// No description provided for @verifyBizPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ duyệt · trong 24 giờ'**
  String get verifyBizPending;

  /// No description provided for @verifyBizApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh doanh nghiệp'**
  String get verifyBizApproved;

  /// No description provided for @verifyBizRejected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa được duyệt: {reason}'**
  String verifyBizRejected(String reason);

  /// No description provided for @verifyBizReject_inactive.
  ///
  /// In vi, this message translates to:
  /// **'Doanh nghiệp không ở tình trạng đang hoạt động.'**
  String get verifyBizReject_inactive;

  /// No description provided for @verifyBizReject_representative_mismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế không khớp với danh tính chủ studio.'**
  String get verifyBizReject_representative_mismatch;

  /// No description provided for @verifyBizReject_doc_unreadable.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh giấy đăng ký không đọc được. Chụp lại rõ nét.'**
  String get verifyBizReject_doc_unreadable;

  /// No description provided for @verifyBizNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy mã số thuế này.'**
  String get verifyBizNotFound;

  /// No description provided for @verifyBizNeedsIdentity.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh danh tính chủ studio trước.'**
  String get verifyBizNeedsIdentity;

  /// No description provided for @verifyBizInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế gồm 10 hoặc 12 chữ số.'**
  String get verifyBizInvalid;

  /// No description provided for @settingsVerifyStepsLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {n} bước'**
  String settingsVerifyStepsLeft(int n);

  /// No description provided for @settingsVerifyPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ duyệt'**
  String get settingsVerifyPending;

  /// No description provided for @settingsVerifyApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh'**
  String get settingsVerifyApproved;

  /// No description provided for @settingsVerifyRejected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa được duyệt'**
  String get settingsVerifyRejected;

  /// No description provided for @settingsVerifyRevoked.
  ///
  /// In vi, this message translates to:
  /// **'Đã thu hồi'**
  String get settingsVerifyRevoked;

  /// No description provided for @settingsBusiness.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh doanh nghiệp'**
  String get settingsBusiness;

  /// No description provided for @settingsBusinessTodo.
  ///
  /// In vi, this message translates to:
  /// **'Con dấu Studio, tới 30 thợ'**
  String get settingsBusinessTodo;

  /// No description provided for @profileOwnerStepsLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {n} bước để nhận đơn'**
  String profileOwnerStepsLeft(int n);

  /// No description provided for @profileOwnerStepsBody.
  ///
  /// In vi, this message translates to:
  /// **'Khách chưa đặt được bạn cho tới khi xác minh xong.'**
  String get profileOwnerStepsBody;

  /// No description provided for @profileOwnerPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ duyệt · trong 24 giờ'**
  String get profileOwnerPending;

  /// No description provided for @profileOwnerPendingBody.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ vẫn hiện \"Chưa nhận đơn\" với khách tới khi được duyệt.'**
  String get profileOwnerPendingBody;

  /// No description provided for @profileOwnerRejected.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ chưa được duyệt'**
  String get profileOwnerRejected;

  /// No description provided for @profileOwnerRejectedBody.
  ///
  /// In vi, this message translates to:
  /// **'Xem lý do và gửi lại.'**
  String get profileOwnerRejectedBody;

  /// No description provided for @profileOwnerContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get profileOwnerContinue;

  /// No description provided for @profileOwnerView.
  ///
  /// In vi, this message translates to:
  /// **'Xem'**
  String get profileOwnerView;

  /// No description provided for @settingsSupportSection.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get settingsSupportSection;

  /// No description provided for @settingsHelp.
  ///
  /// In vi, this message translates to:
  /// **'Trợ giúp'**
  String get settingsHelp;

  /// No description provided for @settingsHelpBody.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp, liên hệ hỗ trợ'**
  String get settingsHelpBody;

  /// No description provided for @helpTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trợ giúp'**
  String get helpTitle;

  /// No description provided for @helpMyDisputes.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại của bạn'**
  String get helpMyDisputes;

  /// No description provided for @helpDisputeRow.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại #{code} · {name}'**
  String helpDisputeRow(String code, String name);

  /// No description provided for @helpDisputeRowMeta.
  ///
  /// In vi, this message translates to:
  /// **'{status} · {date}'**
  String helpDisputeRowMeta(String status, String date);

  /// No description provided for @helpFaqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp'**
  String get helpFaqTitle;

  /// No description provided for @helpContactSupport.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ hỗ trợ'**
  String get helpContactSupport;

  /// No description provided for @helpEmailLine.
  ///
  /// In vi, this message translates to:
  /// **'Email hỗ trợ: {email}'**
  String helpEmailLine(String email);

  /// No description provided for @supportChatTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get supportChatTitle;

  /// No description provided for @supportChatNote.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP.'**
  String get supportChatNote;

  /// No description provided for @supportChatHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn cho hỗ trợ…'**
  String get supportChatHint;

  /// No description provided for @supportChatEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới.'**
  String get supportChatEmpty;

  /// No description provided for @supportSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa gửi được tin nhắn. Thử lại.'**
  String get supportSendFailed;

  /// No description provided for @supportRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn gửi hơi nhanh. Đợi vài phút rồi gửi tiếp.'**
  String get supportRateLimited;

  /// No description provided for @helpTopicPayments.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get helpTopicPayments;

  /// No description provided for @helpTopicCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ & hoàn tiền'**
  String get helpTopicCancel;

  /// No description provided for @helpTopicDelivery.
  ///
  /// In vi, this message translates to:
  /// **'Bàn giao ảnh'**
  String get helpTopicDelivery;

  /// No description provided for @helpTopicDisputes.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại'**
  String get helpTopicDisputes;

  /// No description provided for @helpTopicContact.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get helpTopicContact;

  /// No description provided for @helpTopicReviews.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get helpTopicReviews;

  /// No description provided for @helpTopicProviders.
  ///
  /// In vi, this message translates to:
  /// **'Dành cho thợ ảnh'**
  String get helpTopicProviders;

  /// No description provided for @helpPayFullQ.
  ///
  /// In vi, this message translates to:
  /// **'Vì sao phải trả trước 100%?'**
  String get helpPayFullQ;

  /// No description provided for @helpPayFullA.
  ///
  /// In vi, this message translates to:
  /// **'Tiền không đến tay thợ ngay. Ứng dụng giữ tiền và chỉ chuyển cho thợ theo 2 đợt: sau buổi chụp, và sau khi bạn đồng ý ảnh rồi kiểm tra bộ ảnh gốc trong 48 giờ. Có lỗi thì bạn được hoàn qua ứng dụng.'**
  String get helpPayFullA;

  /// No description provided for @helpPayHeldQ.
  ///
  /// In vi, this message translates to:
  /// **'Tiền của tôi được giữ ở đâu?'**
  String get helpPayHeldQ;

  /// No description provided for @helpPayHeldA.
  ///
  /// In vi, this message translates to:
  /// **'Tiền do một tổ chức trung gian thanh toán được cấp phép giữ, không nằm trong tài khoản của ứng dụng, và chưa chuyển cho thợ cho tới khi đủ điều kiện.'**
  String get helpPayHeldA;

  /// No description provided for @helpPayQrQ.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản QR sai số tiền thì sao?'**
  String get helpPayQrQ;

  /// No description provided for @helpPayQrA.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chuyển đúng số tiền và nội dung trong 15 phút. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động về tài khoản đã chuyển.'**
  String get helpPayQrA;

  /// No description provided for @helpCancelRefundQ.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ buổi chụp được hoàn bao nhiêu?'**
  String get helpCancelRefundQ;

  /// No description provided for @helpCancelRefundA.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ trước giờ chụp từ 48 giờ trở lên: hoàn 100%. Từ 24 đến 48 giờ: hoàn 50%. Dưới 24 giờ: không hoàn. Tính trên toàn bộ số đã trả. Thợ huỷ thì bạn được hoàn 100%.'**
  String get helpCancelRefundA;

  /// No description provided for @helpCancelWhereQ.
  ///
  /// In vi, this message translates to:
  /// **'Tiền hoàn về đâu?'**
  String get helpCancelWhereQ;

  /// No description provided for @helpCancelWhereA.
  ///
  /// In vi, this message translates to:
  /// **'Trả bằng ví MoMo hoặc ZaloPay thì hoàn về ví. Chuyển khoản thì hoàn về tài khoản đã chuyển, hoặc tài khoản khác bạn khai.'**
  String get helpCancelWhereA;

  /// No description provided for @helpCancelLateQ.
  ///
  /// In vi, this message translates to:
  /// **'Thợ giao ảnh trễ thì sao?'**
  String get helpCancelLateQ;

  /// No description provided for @helpCancelLateA.
  ///
  /// In vi, this message translates to:
  /// **'Quá số ngày đã hẹn, bạn được huỷ phần bàn giao và hoàn 100% đợt thanh toán thứ hai; thợ giữ đợt đầu.'**
  String get helpCancelLateA;

  /// No description provided for @helpDeliverySampleQ.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh mẫu có watermark là gì?'**
  String get helpDeliverySampleQ;

  /// No description provided for @helpDeliverySampleA.
  ///
  /// In vi, this message translates to:
  /// **'Thợ gửi ảnh mẫu có watermark trước. Link bộ ảnh gốc bị che và chỉ mở khi bạn bấm \"Đồng ý ảnh\". Không phản hồi trong 3 ngày thì hệ thống tự đồng ý.'**
  String get helpDeliverySampleA;

  /// No description provided for @helpDeliveryEditQ.
  ///
  /// In vi, this message translates to:
  /// **'Muốn sửa ảnh thì làm sao?'**
  String get helpDeliveryEditQ;

  /// No description provided for @helpDeliveryEditA.
  ///
  /// In vi, this message translates to:
  /// **'Trao đổi màu sắc, chỉnh sửa ngay trên ảnh mẫu. Số vòng sửa miễn phí theo gói. Hết lượt thì bạn đồng ý, xin thêm một vòng, hoặc mở khiếu nại.'**
  String get helpDeliveryEditA;

  /// No description provided for @helpDisputeWhenQ.
  ///
  /// In vi, this message translates to:
  /// **'Khi nào tôi mở khiếu nại được?'**
  String get helpDisputeWhenQ;

  /// No description provided for @helpDisputeWhenA.
  ///
  /// In vi, this message translates to:
  /// **'Trong 24 giờ sau khi buổi chụp hoàn thành, hoặc trong 24 giờ sau khi sự kiện có vé trả tiền kết thúc. Với bộ ảnh gốc, bạn có 48 giờ kể từ khi đồng ý ảnh. Quá thời hạn thì nút \"Báo vấn đề\" không còn. Vé không thu phí không có khiếu nại vì không có tiền được giữ.'**
  String get helpDisputeWhenA;

  /// No description provided for @helpDisputeMoneyQ.
  ///
  /// In vi, this message translates to:
  /// **'Trong lúc khiếu nại, tiền ở đâu?'**
  String get helpDisputeMoneyQ;

  /// No description provided for @helpDisputeMoneyA.
  ///
  /// In vi, this message translates to:
  /// **'Tiền tiếp tục được giữ, không chuyển cho thợ. Đội hỗ trợ xem bằng chứng của hai bên rồi quyết định: chuyển cho thợ, hoàn cho bạn, hoặc chia.'**
  String get helpDisputeMoneyA;

  /// No description provided for @helpDisputeEvidenceQ.
  ///
  /// In vi, this message translates to:
  /// **'Ai xem được ảnh bằng chứng?'**
  String get helpDisputeEvidenceQ;

  /// No description provided for @helpDisputeEvidenceA.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ bạn, người bị khiếu nại và đội hỗ trợ.'**
  String get helpDisputeEvidenceA;

  /// No description provided for @helpContactQ.
  ///
  /// In vi, this message translates to:
  /// **'Khi nào tôi gọi được cho thợ?'**
  String get helpContactQ;

  /// No description provided for @helpContactA.
  ///
  /// In vi, this message translates to:
  /// **'Gọi, Zalo, WhatsApp chỉ mở sau khi bạn đã thanh toán. Trước đó bạn nhắn tin hỏi trong ứng dụng. Số điện thoại không hiện công khai.'**
  String get helpContactA;

  /// No description provided for @helpReviewQ.
  ///
  /// In vi, this message translates to:
  /// **'Cà chua và gạch là gì?'**
  String get helpReviewQ;

  /// No description provided for @helpReviewA.
  ///
  /// In vi, this message translates to:
  /// **'Cà chua là hài lòng, gạch là chưa hài lòng; bấm 1 đến 10 lần để nói mức độ. Hồ sơ thợ hiện tỉ lệ cà chua. Mỗi buổi chụp đánh giá một lần, gửi rồi không sửa.'**
  String get helpReviewA;

  /// No description provided for @helpProviderStartQ.
  ///
  /// In vi, this message translates to:
  /// **'Làm sao để bắt đầu nhận đơn?'**
  String get helpProviderStartQ;

  /// No description provided for @helpProviderStartA.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh số điện thoại, đóng phí xác minh (thợ ảnh 99.000₫, studio 299.000₫, không hoàn), xác minh danh tính bằng VNeID hoặc chip CCCD và đồng ý quy định nhận việc. Nhân viên duyệt trong 24 giờ.'**
  String get helpProviderStartA;

  /// No description provided for @helpProviderPaidQ.
  ///
  /// In vi, this message translates to:
  /// **'Khi nào tôi nhận được tiền?'**
  String get helpProviderPaidQ;

  /// No description provided for @helpProviderPaidA.
  ///
  /// In vi, this message translates to:
  /// **'Tiền về theo 2 đợt: sau buổi chụp, và sau khi khách đồng ý ảnh và hết 48 giờ kiểm tra. Chi tự động mỗi ngày vào tài khoản đã xác minh; lần chi đầu do nhân viên duyệt.'**
  String get helpProviderPaidA;

  /// No description provided for @addonKindMakeup.
  ///
  /// In vi, this message translates to:
  /// **'Trang điểm'**
  String get addonKindMakeup;

  /// No description provided for @addonKindRetouch.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh ảnh'**
  String get addonKindRetouch;

  /// No description provided for @addonKindTransport.
  ///
  /// In vi, this message translates to:
  /// **'Đưa đón'**
  String get addonKindTransport;

  /// No description provided for @addonKindOutfit.
  ///
  /// In vi, this message translates to:
  /// **'Trang phục'**
  String get addonKindOutfit;

  /// No description provided for @addonKindOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get addonKindOther;

  /// No description provided for @addonOnce.
  ///
  /// In vi, this message translates to:
  /// **'Một lần'**
  String get addonOnce;

  /// No description provided for @addonUnitPerPerson.
  ///
  /// In vi, this message translates to:
  /// **'Theo người'**
  String get addonUnitPerPerson;

  /// No description provided for @addonUnitPerItem.
  ///
  /// In vi, this message translates to:
  /// **'Theo số lượng'**
  String get addonUnitPerItem;

  /// No description provided for @addonNounPerson.
  ///
  /// In vi, this message translates to:
  /// **'người'**
  String get addonNounPerson;

  /// No description provided for @addonNounPhoto.
  ///
  /// In vi, this message translates to:
  /// **'ảnh'**
  String get addonNounPhoto;

  /// No description provided for @addonNounSet.
  ///
  /// In vi, this message translates to:
  /// **'bộ'**
  String get addonNounSet;

  /// No description provided for @addonNounTime.
  ///
  /// In vi, this message translates to:
  /// **'lần'**
  String get addonNounTime;

  /// No description provided for @addonPriceOnce.
  ///
  /// In vi, this message translates to:
  /// **'{price} · một lần'**
  String addonPriceOnce(String price);

  /// No description provided for @addonPricePer.
  ///
  /// In vi, this message translates to:
  /// **'{price} / {noun}'**
  String addonPricePer(String price, String noun);

  /// No description provided for @addonLineQty.
  ///
  /// In vi, this message translates to:
  /// **'{name} · {qty} {noun}'**
  String addonLineQty(String name, int qty, String noun);

  /// No description provided for @addonSummaryItem.
  ///
  /// In vi, this message translates to:
  /// **'{name} ×{qty}'**
  String addonSummaryItem(String name, int qty);

  /// No description provided for @addonBlockMeta.
  ///
  /// In vi, this message translates to:
  /// **'{qty} {noun} × {price}'**
  String addonBlockMeta(int qty, String noun, String price);

  /// No description provided for @addonsSummary.
  ///
  /// In vi, this message translates to:
  /// **'+ {list}'**
  String addonsSummary(String list);

  /// No description provided for @addonsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đi kèm'**
  String get addonsTitle;

  /// No description provided for @addonsActiveCount.
  ///
  /// In vi, this message translates to:
  /// **'{n}/10 dịch vụ đang bật'**
  String addonsActiveCount(int n);

  /// No description provided for @addonsAppliesAll.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng: mọi gói'**
  String get addonsAppliesAll;

  /// No description provided for @addonsAppliesTo.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng: {names}'**
  String addonsAppliesTo(String names);

  /// No description provided for @addonsToggle.
  ///
  /// In vi, this message translates to:
  /// **'Bật {name}'**
  String addonsToggle(String name);

  /// No description provided for @addonsAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm dịch vụ'**
  String get addonsAdd;

  /// No description provided for @addonsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dịch vụ đi kèm'**
  String get addonsEmptyTitle;

  /// No description provided for @addonsEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Thêm trang điểm, chỉnh ảnh hay xe đưa đón để khách chọn khi đặt lịch.'**
  String get addonsEmptyBody;

  /// No description provided for @addonsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được dịch vụ đi kèm. Thử lại.'**
  String get addonsLoadError;

  /// No description provided for @addonsLimitReached.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã bật đủ 10 dịch vụ. Tắt bớt một dịch vụ để bật dịch vụ này.'**
  String get addonsLimitReached;

  /// No description provided for @addonsSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được. Thử lại'**
  String get addonsSaveFailed;

  /// No description provided for @addonEditAddTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm dịch vụ đi kèm'**
  String get addonEditAddTitle;

  /// No description provided for @addonEditEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa dịch vụ đi kèm'**
  String get addonEditEditTitle;

  /// No description provided for @addonEditClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get addonEditClose;

  /// No description provided for @addonFieldKind.
  ///
  /// In vi, this message translates to:
  /// **'Loại'**
  String get addonFieldKind;

  /// No description provided for @addonFieldName.
  ///
  /// In vi, this message translates to:
  /// **'Tên dịch vụ'**
  String get addonFieldName;

  /// No description provided for @addonFieldDescription.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả · không bắt buộc'**
  String get addonFieldDescription;

  /// No description provided for @addonFieldUnit.
  ///
  /// In vi, this message translates to:
  /// **'Cách tính'**
  String get addonFieldUnit;

  /// No description provided for @addonFieldPriceOnce.
  ///
  /// In vi, this message translates to:
  /// **'Giá (₫)'**
  String get addonFieldPriceOnce;

  /// No description provided for @addonFieldPricePer.
  ///
  /// In vi, this message translates to:
  /// **'Giá / {noun} (₫)'**
  String addonFieldPricePer(String noun);

  /// No description provided for @addonFieldMax.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa'**
  String get addonFieldMax;

  /// No description provided for @addonFieldApplies.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng cho'**
  String get addonFieldApplies;

  /// No description provided for @addonAppliesAllChip.
  ///
  /// In vi, this message translates to:
  /// **'Mọi gói'**
  String get addonAppliesAllChip;

  /// No description provided for @addonAppliesPickChip.
  ///
  /// In vi, this message translates to:
  /// **'Chọn gói'**
  String get addonAppliesPickChip;

  /// No description provided for @addonPickPackagesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn gói áp dụng'**
  String get addonPickPackagesTitle;

  /// No description provided for @addonPickPackagesDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get addonPickPackagesDone;

  /// No description provided for @addonResponsibility.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chịu trách nhiệm với khách về dịch vụ này, kể cả khi thuê người ngoài.'**
  String get addonResponsibility;

  /// No description provided for @addonSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get addonSave;

  /// No description provided for @addonDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dịch vụ'**
  String get addonDelete;

  /// No description provided for @addonDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dịch vụ này?'**
  String get addonDeleteTitle;

  /// No description provided for @addonDeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Booking đã đặt vẫn giữ dịch vụ này.'**
  String get addonDeleteBody;

  /// No description provided for @addonDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get addonDeleteConfirm;

  /// No description provided for @addonDeleteKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lại'**
  String get addonDeleteKeep;

  /// No description provided for @addonSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu dịch vụ'**
  String get addonSaved;

  /// No description provided for @addonDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá dịch vụ'**
  String get addonDeleted;

  /// No description provided for @addonErrName.
  ///
  /// In vi, this message translates to:
  /// **'Tên 2–60 ký tự'**
  String get addonErrName;

  /// No description provided for @addonErrDescription.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả tối đa 200 ký tự'**
  String get addonErrDescription;

  /// No description provided for @addonErrPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá từ 10.000₫ tới 50.000.000₫'**
  String get addonErrPrice;

  /// No description provided for @addonErrMaxQty.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa từ 1 tới 10'**
  String get addonErrMaxQty;

  /// No description provided for @addonErrContact.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung'**
  String get addonErrContact;

  /// No description provided for @addonErrPackages.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ít nhất một gói'**
  String get addonErrPackages;

  /// No description provided for @settingsAddons.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đi kèm'**
  String get settingsAddons;

  /// No description provided for @profileEditAddons.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đi kèm'**
  String get profileEditAddons;

  /// No description provided for @setupAddAddon.
  ///
  /// In vi, this message translates to:
  /// **'Thêm dịch vụ đi kèm'**
  String get setupAddAddon;

  /// No description provided for @bookAddonsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm dịch vụ'**
  String get bookAddonsTitle;

  /// No description provided for @bookAddonsOptional.
  ///
  /// In vi, this message translates to:
  /// **'Không bắt buộc'**
  String get bookAddonsOptional;

  /// No description provided for @bookAddonLess.
  ///
  /// In vi, this message translates to:
  /// **'Bớt một {unit}'**
  String bookAddonLess(String unit);

  /// No description provided for @bookAddonMore.
  ///
  /// In vi, this message translates to:
  /// **'Thêm một {unit}'**
  String bookAddonMore(String unit);

  /// No description provided for @bookAddonQty.
  ///
  /// In vi, this message translates to:
  /// **'{name}: {qty} {unit}'**
  String bookAddonQty(String name, int qty, String unit);

  /// No description provided for @bookAddonDropped.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ {names} vì không áp dụng cho gói này'**
  String bookAddonDropped(String names);

  /// No description provided for @bookAddonsChanged.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ đi kèm vừa thay đổi, kiểm tra lại trước khi thanh toán'**
  String get bookAddonsChanged;

  /// No description provided for @bookPickupTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đón'**
  String get bookPickupTitle;

  /// No description provided for @bookPickupHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên điểm đón (tối thiểu 3 ký tự)'**
  String get bookPickupHint;

  /// No description provided for @bookPickupPrivate.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ thợ chụp cho bạn thấy điểm đón.'**
  String get bookPickupPrivate;

  /// No description provided for @bookPickupRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập điểm đón cho xe đưa đón'**
  String get bookPickupRequired;

  /// No description provided for @bookPickupLine.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đón: {name}'**
  String bookPickupLine(String name);
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
