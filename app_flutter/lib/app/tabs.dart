import 'package:flutter/material.dart';

import '../data/user/user_profile.dart';
import '../l10n/app_localizations.dart';

enum AppTab {
  home('/home'),
  explore('/explore'),
  action('/action'),
  bookings('/bookings'),
  profile('/profile');

  const AppTab(this.path);
  final String path;
}

class TabSpec {
  const TabSpec({
    required this.tab,
    required this.labelKey,
    required this.icon,
    this.emphasized = false,
  });
  final AppTab tab;

  /// Key in app_vi.arb; resolved with [label].
  final String labelKey;
  final IconData icon;
  final bool emphasized;

  String label(AppLocalizations l) => switch (labelKey) {
    'tabHome' => l.tabHome,
    'tabExplore' => l.tabExplore,
    'tabFind' => l.tabFind,
    'tabCreate' => l.tabCreate,
    'tabBookings' => l.tabBookings,
    'tabWork' => l.tabWork,
    'tabProfile' => l.tabProfile,
    _ => labelKey,
  };
}

List<TabSpec> tabsFor(UserRole role) {
  final isPhotographer = role == UserRole.photographer;
  return [
    const TabSpec(
      tab: AppTab.home,
      labelKey: 'tabHome',
      icon: Icons.home_outlined,
    ),
    const TabSpec(
      tab: AppTab.explore,
      labelKey: 'tabExplore',
      icon: Icons.explore_outlined,
    ),
    TabSpec(
      tab: AppTab.action,
      labelKey: isPhotographer ? 'tabCreate' : 'tabFind',
      icon: isPhotographer ? Icons.add : Icons.search,
      emphasized: true,
    ),
    TabSpec(
      tab: AppTab.bookings,
      labelKey: isPhotographer ? 'tabWork' : 'tabBookings',
      icon: Icons.calendar_today_outlined,
    ),
    const TabSpec(
      tab: AppTab.profile,
      labelKey: 'tabProfile',
      icon: Icons.person_outline,
    ),
  ];
}
