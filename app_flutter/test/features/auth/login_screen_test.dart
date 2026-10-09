import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child, AuthRepository repo) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

class _PendingGoogle extends FakeAuthRepository {
  final pending = Completer<AuthUser>();
  @override
  Future<AuthUser> signInWithGoogle() => pending.future;
}

void main() {
  testWidgets('wrong password shows the specific Vietnamese message', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    await repo.signOut();
    await tester.pumpWidget(_wrap(const LoginScreen(), repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'a@b.vn');
    await tester.enterText(find.byKey(const Key('password')), 'wrongpass');
    await tester.ensureVisible(find.byKey(const Key('login')));
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
  });
  testWidgets(
    'cancelled Google sign-in shows no error and re-enables buttons',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const LoginScreen(), FakeAuthRepository(cancelSocial: true)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('google')));
      await tester.tap(find.byKey(const Key('google')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      final btn = tester.widget<AppButton>(find.byKey(const Key('login')));
      expect(btn.loading, isFalse);
      expect(btn.onPressed, isNotNull);
    },
  );
  testWidgets('only the tapped button spins; the rest are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen(), _PendingGoogle()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('google')));
    await tester.tap(find.byKey(const Key('google')));
    await tester.pump();
    AppButton btn(String k) => tester.widget<AppButton>(find.byKey(Key(k)));
    expect(btn('google').loading, isTrue);
    expect(btn('login').loading, isFalse);
    expect(btn('login').onPressed, isNull);
    expect(btn('facebook').onPressed, isNull);
    final email = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('email')),
        matching: find.byType(TextField),
      ),
    );
    expect(email.enabled, isFalse);
  });
  testWidgets(
    'the sign-up row reads "Chưa có tài khoản? Đăng ký" and opens /register',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
          GoRoute(
            path: '/register',
            builder: (_, _) => const Scaffold(body: Text('register-stub')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có tài khoản?'), findsOneWidget);
      final link = find.byKey(const Key('register'));
      expect(
        find.descendant(of: link, matching: find.text('Đăng ký')),
        findsOneWidget,
      );
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('register-stub'), findsOneWidget);
    },
  );
  testWidgets('sign-up link is disabled while signing in', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen(), _PendingGoogle()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('google')));
    await tester.tap(find.byKey(const Key('google')));
    await tester.pump();
    expect(
      tester.widget<TextButton>(find.byKey(const Key('register'))).onPressed,
      isNull,
    );
  });
}
