// lib/features/event_manage/my_events_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/features/event_manage/my_events_section.dart';

/// `/events/mine`: every event I created, drafts included (S06.01 "Xem tất
/// cả", S09.02 "Quản lý sự kiện" for staff, S11.01's calendar button).
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final events = ref.watch(myEventsProvider);
    final now = ref.watch(clockProvider)();
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
            title: Text(l.myEventsTitle),
            actions: [
              IconButton(
                key: const Key('my-events-create'),
                tooltip: l.eventsCreate,
                icon: const AppIcon(AppIcons.add),
                onPressed: () => context.push('/events/new'),
              ),
            ],
          ),
          body: AsyncView<List<EventSummary>>(
            value: events,
            onRetry: () => ref.invalidate(myEventsProvider),
            skeleton: (_) => ListView(
              padding: const EdgeInsets.all(AppSpace.s4),
              children: [
                for (var i = 0; i < 4; i++) ...[
                  EventCard.skeleton(),
                  const SizedBox(height: AppSpace.s3),
                ],
              ],
            ),
            isEmpty: (list) => list.isEmpty,
            empty: (_) => EmptyState(
              title: l.myEventsEmpty,
              body: l.myEventsEmptyBody,
              actionLabel: l.eventsCreate,
              onAction: () => context.push('/events/new'),
            ),
            data: (context, list) => ListView(
              padding: const EdgeInsets.all(AppSpace.s4),
              children: [
                for (final e in orderMyEvents(list, now)) ...[
                  MyEventTile(event: e),
                  const SizedBox(height: AppSpace.s3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
