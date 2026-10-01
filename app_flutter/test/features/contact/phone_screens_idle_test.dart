import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/contact/add_phone_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/idle.dart';

void main() {
  testWidgets('S33 is idle at rest and after typing a number', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    final router = GoRouter(
      initialLocation: '/profile/phone',
      routes: [
        GoRoute(
          path: '/profile/phone',
          builder: (_, _) => const AddPhoneScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          userContactRepositoryProvider.overrideWithValue(
            FakeUserContactRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    // The field autofocuses; a blinking caret is the only allowed motion, so
    // drop focus before checking.
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
  });

  test('the fake counts open listeners', () async {
    final repo = FakeUserContactRepository();
    final sub = repo.watch('u1').listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(repo.watchers, 1);
    await sub.cancel();
    expect(repo.watchers, 0);
  });
}
