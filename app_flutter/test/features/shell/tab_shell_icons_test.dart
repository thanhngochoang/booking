import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/shell/tab_shell.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  testWidgets('TabShell: active tab icon is filled + accent, others outline', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, UserRole.customer);
    final router = GoRouter(
      initialLocation: AppTab.home.path,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => TabShell(shell),
          branches: [
            for (final t in AppTab.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(path: t.path, builder: (_, _) => Text(t.name)),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildDarkTheme(),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final destinations = find.byType(NavigationDestination);
    Icon iconAt(int i) => tester.widget<Icon>(
      find
          .descendant(of: destinations.at(i), matching: find.byType(Icon))
          .first,
    );
    // Tab 0 (Home) is selected; the middle tab is the gradient disc, skip it.
    final on = iconAt(0);
    expect(on.fill, 1);
    final onColor = IconTheme.of(
      tester.element(
        find
            .descendant(of: destinations.at(0), matching: find.byType(Icon))
            .first,
      ),
    ).color;
    expect(onColor, AppColorsDark.primary);
    final off = iconAt(1);
    expect(off.fill, 0);
    final offColor = IconTheme.of(
      tester.element(
        find
            .descendant(of: destinations.at(1), matching: find.byType(Icon))
            .first,
      ),
    ).color;
    expect(offColor, AppColorsDark.foregroundMuted);
  });
}
