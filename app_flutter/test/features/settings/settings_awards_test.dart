import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(UserRole role) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await users.setRole(u.uid, role);
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/me/awards', builder: (_, _) => const Text('stub awards')),
    ],
  );
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('S09.02: photographers see Giải thưởng and it opens S25.01', (
    tester,
  ) async {
    await tester.pumpWidget(await _app(UserRole.photographer));
    await tester.pumpAndSettle();
    expect(find.text('Giải thưởng'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('profile-awards')));
    await tester.tap(find.byKey(const Key('profile-awards')));
    await tester.pumpAndSettle();
    expect(find.text('stub awards'), findsOneWidget);
  });

  testWidgets('S09.02: customers do not see Giải thưởng', (tester) async {
    await tester.pumpWidget(await _app(UserRole.customer));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-awards')), findsNothing);
  });
}
