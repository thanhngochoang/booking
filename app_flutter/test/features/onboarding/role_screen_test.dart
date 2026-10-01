import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';
import 'package:nhiep_anh_gia/features/onboarding/role_screen.dart';
import 'package:nhiep_anh_gia/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'choosing photographer sets the role and creates photographer doc',
    (tester) async {
      final auth = FakeAuthRepository();
      final users = FakeUserRepository();
      final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
      await users.ensureProfile(u);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userRepositoryProvider.overrideWithValue(users),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RoleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-photographer')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('role-continue')));
      await tester.pumpAndSettle();
      final p = await users.watch(u.uid).first;
      expect(p!.role, UserRole.photographer);
      expect(users.photographerDocs, contains(u.uid));
    },
  );
}
