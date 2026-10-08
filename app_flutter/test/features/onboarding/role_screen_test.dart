import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/onboarding/role_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

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

  Future<void> pumpRole(
    WidgetTester tester,
    Brightness b, {
    double textScale = 1.0,
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
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
        child: MaterialApp(
          theme: b == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: c!,
          ),
          home: const RoleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tileOf(String key) => find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byKey(const ValueKey('role-icon-tile')),
      );
  Color? tileColor(WidgetTester tester, String key) =>
      (tester.widget<Container>(tileOf(key)).decoration! as BoxDecoration)
          .color;
  Color? iconColor(WidgetTester tester, String key) => tester
      .widget<AppIcon>(
        find.descendant(of: tileOf(key), matching: find.byType(AppIcon)),
      )
      .color;

  for (final b in Brightness.values) {
    final dark = b == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;

    testWidgets(
        'the selected role shows its icon in a primarySubtle circle with a '
        'primary icon (${b.name})', (tester) async {
      await pumpRole(tester, b);
      final scheme =
          Theme.of(tester.element(find.byType(RoleScreen))).colorScheme;
      final box = tester.widget<Container>(tileOf('role-customer'));
      expect((box.decoration! as BoxDecoration).shape, BoxShape.circle);
      expect(tester.getSize(tileOf('role-customer')), const Size(36, 36));
      expect(tileColor(tester, 'role-customer'), subtle);
      expect(iconColor(tester, 'role-customer'), scheme.primary);
    });

    testWidgets('the other role uses the field colour (${b.name})',
        (tester) async {
      await pumpRole(tester, b);
      final scheme =
          Theme.of(tester.element(find.byType(RoleScreen))).colorScheme;
      expect(tileColor(tester, 'role-photographer'), scheme.secondary);
      expect(iconColor(tester, 'role-photographer'), scheme.onSurface);
    });

    testWidgets('the unselected card is on the glass fill and the tile shows '
        'against it (${b.name})', (tester) async {
      await pumpRole(tester, b);
      final scheme =
          Theme.of(tester.element(find.byType(RoleScreen))).colorScheme;
      final card = tester.widget<Container>(find.descendant(
        of: find.byKey(const Key('role-photographer')),
        matching: find.byType(Container),
      ).first);
      final cardFill = (card.decoration! as BoxDecoration).color;
      expect(cardFill, dark ? AppColorsDark.glass : AppColors.glass);
      expect(tileColor(tester, 'role-photographer'), scheme.secondary);
      // Dark: both are the same translucent white and the tile stacks on
      // the card; light: the opaque field colour differs from the glass.
      if (!dark) {
        expect(tileColor(tester, 'role-photographer'), isNot(cardFill));
      }
    });

    testWidgets('tapping the other card moves the highlight (${b.name})',
        (tester) async {
      await pumpRole(tester, b);
      final scheme =
          Theme.of(tester.element(find.byType(RoleScreen))).colorScheme;
      await tester.tap(find.byKey(const Key('role-photographer')));
      await tester.pump();
      expect(tileColor(tester, 'role-photographer'), subtle);
      expect(iconColor(tester, 'role-photographer'), scheme.primary);
      expect(tileColor(tester, 'role-customer'), scheme.secondary);
      expect(iconColor(tester, 'role-customer'), scheme.onSurface);
    });
  }

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await pumpRole(tester, Brightness.dark,
        textScale: 1.3, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
