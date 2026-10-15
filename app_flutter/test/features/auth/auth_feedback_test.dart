import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _app(AuthRepository repo, Widget home) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Future<void> _dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a stale error does not reappear after a cancelled Google sign-in',
    (tester) async {
      final repo = FakeAuthRepository(cancelSocial: true);
      await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
      await repo.signOut();
      await tester.pumpWidget(_app(repo, const LoginScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email')), 'a@b.vn');
      await tester.enterText(find.byKey(const Key('password')), 'wrongpass');
      await tester.tap(find.byKey(const Key('login')));
      await tester.pumpAndSettle();
      expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
      await _dismissSnackBars(tester);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.byKey(const Key('google')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('register error is shown once even with login below it', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    await repo.signOut();
    await tester.pumpWidget(_app(repo, const LoginScreen()));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Lan');
    await tester.enterText(find.byKey(const Key('email')), 'a@b.vn');
    await tester.enterText(find.byKey(const Key('password')), 'password1');
    await tester.enterText(find.byKey(const Key('confirm')), 'password1');
    await tester.ensureVisible(find.byKey(const Key('register')));
    await tester.tap(find.byKey(const Key('register')));
    await tester.pumpAndSettle();
    expect(find.text('Email này đã được dùng. Hãy đăng nhập.'), findsOneWidget);
    await _dismissSnackBars(tester);
    expect(find.byType(SnackBar), findsNothing, reason: 'no queued duplicate');
  });
}
