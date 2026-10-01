import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/shell/tab_badges.dart';

class TabShell extends ConsumerWidget {
  const TabShell(this.shell, {super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(currentProfileProvider).value?.role ?? UserRole.customer;
    final specs = tabsFor(role);
    final badges = ref.watch(tabBadgesProvider);
    final l = context.l10n;
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            for (final s in specs)
              NavigationDestination(
                icon: s.emphasized
                    ? SizedBox(
                        width: 36,
                        height: 36,
                        child: CtaSurface(
                          borderRadius: BorderRadius.circular(18),
                          child: Center(
                            child: Icon(s.icon, color: Colors.white),
                          ),
                        ),
                      )
                    : TabBadge(count: badges[s.tab] ?? 0, child: Icon(s.icon)),
                label: s.label(l),
              ),
          ],
        ),
      ),
    );
  }
}
