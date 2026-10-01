import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';
import 'package:nhiep_anh_gia/features/onboarding/role_screen.dart';
import 'package:nhiep_anh_gia/features/onboarding/session_error_screen.dart';
import 'package:nhiep_anh_gia/l10n/app_localizations.dart';

Widget _app(AuthRepository auth, UserRepository users, Widget home) =>
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  testWidgets('a failed role save is shown to the user', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository(failSetRole: true);
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await tester.pumpWidget(_app(auth, users, const RoleScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Không lưu được lựa chọn. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
  });
  testWidgets('role screen offers a way out', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await tester.pumpWidget(_app(auth, users, const RoleScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-sign-out')));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });
  testWidgets('session error screen retries and signs out', (tester) async {
    final auth = FakeAuthRepository();
    await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await tester.pumpWidget(
      _app(auth, FakeUserRepository(), const SessionErrorScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được tài khoản'), findsOneWidget);
    expect(find.byKey(const Key('session-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-sign-out')));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });
}
