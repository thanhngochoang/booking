import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const Scaffold(body: Text('login-stub')),
    ),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
  ],
);

Widget _wrap(GoRouter router, {MediaQueryData? media}) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
  child: MaterialApp.router(
    routerConfig: router,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: media == null
        ? null
        : (context, child) => MediaQuery(data: media, child: child!),
  ),
);

void main() {
  testWidgets('has no app bar (mock S01.04)', (tester) async {
    await tester.pumpWidget(_wrap(_router('/register')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('content starts below the top inset', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _router('/register'),
        media: const MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.only(top: 44),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Tham gia')).dy,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('login link pops back to login when opened from it', (
    tester,
  ) async {
    final router = _router('/login');
    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    router.push('/register');
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('register-login-link')));
    await tester.tap(find.byKey(const Key('register-login-link')));
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);
  });

  testWidgets('login link goes to /login when there is nothing to pop', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_router('/register')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('register-login-link')));
    await tester.tap(find.byKey(const Key('register-login-link')));
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back returns to login', (tester) async {
    final router = _router('/login');
    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    router.push('/register');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);
  });

  testWidgets('the "Đăng ký" button has no icon', (tester) async {
    await tester.pumpWidget(_wrap(_router('/register')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppButton>(find.byKey(const Key('register'))).icon,
      isNull,
    );
  });

  testWidgets('fits 320x568 at 1.3x with the keyboard up', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        _router('/register'),
        media: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.3),
          viewInsets: EdgeInsets.only(bottom: 260),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('register')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
