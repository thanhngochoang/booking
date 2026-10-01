import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';
import 'package:nhiep_anh_gia/features/auth/login_screen.dart';
import 'package:nhiep_anh_gia/features/auth/register_screen.dart';
import 'package:nhiep_anh_gia/features/onboarding/role_screen.dart';
import 'package:nhiep_anh_gia/features/onboarding/session_error_screen.dart';
import 'package:nhiep_anh_gia/features/shell/placeholder_tabs.dart';
import 'package:nhiep_anh_gia/l10n/app_localizations.dart';

const _sizes = [Size(320, 568), Size(320, 640), Size(430, 932), Size(640, 360)];

final _screens = <String, Widget Function()>{
  'login': () => const LoginScreen(),
  'register': () => const RegisterScreen(),
  'role': () => const RoleScreen(),
  'session-error': () => const SessionErrorScreen(),
  'profile': () => const ProfileTab(),
  'home': () => const HomeTab(),
  'action': () => const ActionTab(),
};

void main() {
  for (final entry in _screens.entries) {
    for (final size in _sizes) {
      testWidgets('${entry.key} fits $size at text scale 1.3', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final auth = FakeAuthRepository();
        final users = FakeUserRepository();
        final u = await auth.registerWithEmail(
          'a@b.vn',
          'password1',
          'Nguyễn Thị Minh Thư',
        );
        await users.ensureProfile(u);
        await users.setRole(u.uid, UserRole.photographer);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(auth),
                userRepositoryProvider.overrideWithValue(users),
              ],
              child: MaterialApp(
                locale: const Locale('vi'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: entry.value(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
