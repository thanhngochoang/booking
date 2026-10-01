import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/core/widgets/app_button.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/features/auth/login_screen.dart';
import 'package:nhiep_anh_gia/l10n/app_localizations.dart';

Widget _wrap(Widget child, AuthRepository repo) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  testWidgets('wrong password shows the specific Vietnamese message',
      (tester) async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    await repo.signOut();
    await tester.pumpWidget(_wrap(const LoginScreen(), repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'a@b.vn');
    await tester.enterText(find.byKey(const Key('password')), 'wrongpass');
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
  });
  testWidgets('cancelled Google sign-in shows no error and re-enables buttons',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const LoginScreen(), FakeAuthRepository(cancelSocial: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    final btn = tester.widget<AppButton>(find.byKey(const Key('login')));
    expect(btn.loading, isFalse);
    expect(btn.onPressed, isNotNull);
  });
}
