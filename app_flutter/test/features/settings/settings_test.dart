import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/edit_profile_screen.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<Widget> _app({
  required FakeAuthRepository auth,
  required FakeUserRepository users,
  required SharedPreferences prefs,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, _) => const EditProfileScreen(),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
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

Future<(FakeAuthRepository, FakeUserRepository)> _signedIn() async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  return (auth, users);
}

void main() {
  test(
    'button style defaults to gradient and restores the saved choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(buttonStyleProvider), ButtonStyleMode.gradient);
      await c.read(buttonStyleProvider.notifier).set(ButtonStyleMode.avatar);
      expect(prefs.getString('buttonStyle'), 'avatar');
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(buttonStyleProvider), ButtonStyleMode.avatar);
    },
  );

  test('theme mode defaults to dark and restores the saved choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(themeModeProvider), ThemeMode.dark);
    await c.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(prefs.getString('themeMode'), 'light');

    final again = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('choosing a theme marks it selected and saves it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    ListTile tile(String k) => tester.widget<ListTile>(find.byKey(Key(k)));
    expect(tile('theme-dark').selected, isTrue);

    await tester.tap(find.byKey(const Key('theme-system')));
    await tester.pumpAndSettle();
    expect(tile('theme-system').selected, isTrue);
    expect(tile('theme-dark').selected, isFalse);
    expect(prefs.getString('themeMode'), 'system');
  });

  testWidgets('editing the display name saves it and returns to settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Minh'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('edit-name')), '  Minh Thư ');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    final uid = auth.currentUser!.uid;
    expect((await users.watch(uid).first)?.displayName, 'Minh Thư');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Minh Thư'), findsOneWidget);
    expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
  });

  testWidgets('an empty name is rejected before saving', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-name')), '   ');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên hiển thị.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      (await users.watch(auth.currentUser!.uid).first)?.displayName,
      'Minh',
    );
  });
}
