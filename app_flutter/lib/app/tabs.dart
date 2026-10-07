import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/l10n/app_localizations.dart';

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
    const TabSpec(tab: AppTab.home, labelKey: 'tabHome', icon: AppIcons.home),
    const TabSpec(
      tab: AppTab.explore,
      labelKey: 'tabExplore',
      icon: AppIcons.explore,
    ),
    TabSpec(
      tab: AppTab.action,
      labelKey: isPhotographer ? 'tabCreate' : 'tabFind',
      icon: isPhotographer ? AppIcons.add : AppIcons.search,
      emphasized: true,
    ),
    TabSpec(
      tab: AppTab.bookings,
      labelKey: isPhotographer ? 'tabWork' : 'tabBookings',
      icon: AppIcons.calendar,
    ),
    const TabSpec(
      tab: AppTab.profile,
      labelKey: 'tabProfile',
      icon: AppIcons.profile,
    ),
  ];
}
