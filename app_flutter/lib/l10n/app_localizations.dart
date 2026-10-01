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

  /// No description provided for @noAccountRegister.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký'**
  String get noAccountRegister;

  /// No description provided for @haveAccountLogin.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? Đăng nhập'**
  String get haveAccountLogin;

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
