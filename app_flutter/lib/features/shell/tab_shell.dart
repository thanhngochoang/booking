import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/explore/explore_badge.dart';
import 'package:photobooking/features/explore/location_controller.dart';
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
        bottomNavigationBar: DecoratedBox(
          // Mock `.tabs`: 1px hairline above the bar.
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) {
              if (specs[i].tab == AppTab.explore) {
                ref.read(exploreSeenAtProvider.notifier).markSeen();
                // A fix older than 30 minutes is refreshed on entering.
                ref.read(locationControllerProvider.notifier).refresh();
              }
              shell.goBranch(i, initialLocation: i == shell.currentIndex);
            },
            destinations: [
              for (final s in specs)
                if (s.emphasized)
                  MiddleTabDestination(icon: s.icon, label: s.label(l))
                else
                  NavigationDestination(
                    icon: TabBadge(
                      count: badges[s.tab] ?? 0,
                      child: Icon(s.icon),
                    ),
                    label: s.label(l),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mock `.tab.mid`: a 36dp gradient disc with a purple glow, the whole
/// destination lifted 3dp, and an ink (not accent) label when active. The
/// hit area is the unchanged destination box, only painted 3dp higher.
class MiddleTabDestination extends StatelessWidget {
  const MiddleTabDestination({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.navigationBarTheme;
    return Theme(
      data: theme.copyWith(
        navigationBarTheme: base.copyWith(
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => base.labelTextStyle
                ?.resolve(states)
                ?.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? theme.colorScheme.onSurface
                      : null,
                ),
          ),
        ),
      ),
      child: Transform.translate(
        offset: const Offset(0, -3),
        child: NavigationDestination(
          icon: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ctaMid.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              width: 36,
              height: 36,
              child: CtaSurface(
                borderRadius: BorderRadius.circular(18),
                child: Center(child: Icon(icon, color: Colors.white)),
              ),
            ),
          ),
          label: label,
        ),
      ),
    );
  }
}
