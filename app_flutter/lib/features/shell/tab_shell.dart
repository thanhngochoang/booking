import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tabs.dart';
import '../../core/l10n_ext.dart';
import '../../data/auth/auth_providers.dart';
import '../../data/user/user_profile.dart';

class TabShell extends ConsumerWidget {
  const TabShell(this.shell, {super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(currentProfileProvider).value?.role ?? UserRole.customer;
    final specs = tabsFor(role);
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final s in specs)
            NavigationDestination(
              icon: s.emphasized
                  ? CircleAvatar(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: Icon(s.icon),
                    )
                  : Icon(s.icon),
              label: s.label(l),
            ),
        ],
      ),
    );
  }
}
