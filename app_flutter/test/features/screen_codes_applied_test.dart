// test/features/screen_codes_applied_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/features/calendar/my_calendar_screen.dart';
import 'package:photobooking/features/onboarding/role_screen.dart';
import 'package:photobooking/features/onboarding/session_error_screen.dart';
import 'package:photobooking/features/onboarding/splash_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';
import 'package:photobooking/features/settings/edit_profile_screen.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<void> _show(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(
          FakePhotographerIntroRepository(),
        ),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        servicePackageRepositoryProvider.overrideWithValue(
          FakeServicePackageRepository(),
        ),
        userContactRepositoryProvider.overrideWithValue(
          FakeUserContactRepository(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: ScreenCodeScope(
        visible: true,
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const cases = <(String, Widget)>[
    (ScreenCodes.login, LoginScreen()),
    (ScreenCodes.role, RoleScreen()),
    (ScreenCodes.profile, ProfileTab()),
    (ScreenCodes.settings, SettingsScreen()),
    (ScreenCodes.register, RegisterScreen()),
    (ScreenCodes.editProfile, EditProfileScreen()),
    (ScreenCodes.splash, SplashScreen()),
    (ScreenCodes.setupProfile, SetupIntroScreen()),
    (ScreenCodes.setupProfile, SetupPackagesScreen()),
    (ScreenCodes.myCalendar, MyCalendarScreen()),
    (ScreenCodes.sessionError, SessionErrorScreen()),
  ];
  for (final (code, screen) in cases) {
    testWidgets('$code is shown on ${screen.runtimeType}', (tester) async {
      await _show(tester, screen);
      expect(find.text(code), findsOneWidget);
    });
  }
}
