// lib/features/events/my_events_placeholder.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/app/tabs.dart';

/// `/events/mine` until the manage screens (S12.03, plan 10c Task 6) replace
/// it.
class MyEventsPlaceholder extends StatelessWidget {
  const MyEventsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.manageEvent,
      label: 'mine',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              tooltip: l.back,
              icon: const AppIcon(AppIcons.back),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppTab.home.path),
            ),
            title: Text(l.eventsManage),
          ),
          body: EmptyState(title: l.eventsMinePlaceholder, body: ''),
        ),
      ),
    );
  }
}
