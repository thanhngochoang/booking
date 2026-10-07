// lib/features/event_manage/my_events_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/features/event_manage/manage_event_screen.dart';

/// Where a row of "Sự kiện của tôi" leads: a draft resumes in S12.01, the
/// rest open S12.03.
String myEventPath(EventSummary e) => e.status == EventStatus.draft
    ? '/events/new?draft=${e.id}'
    : '/events/${e.id}/manage';

/// Upcoming events first (soonest first; a dated draft counts), then drafts
/// with no date yet, then what is over or cancelled (latest first).
List<EventSummary> orderMyEvents(List<EventSummary> events, DateTime now) {
  bool upcoming(EventSummary e) =>
      e.hasSchedule &&
      (e.endsAt ?? e.startsAt).isAfter(now) &&
      e.status != EventStatus.cancelled &&
      e.status != EventStatus.completed;
  final soon = events.where(upcoming).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final undated =
      events
          .where((e) => !e.hasSchedule && e.status != EventStatus.cancelled)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final rest =
      events
          .where(
            (e) =>
                !upcoming(e) &&
                (e.hasSchedule || e.status == EventStatus.cancelled),
          )
          .toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return [...soon, ...undated, ...rest];
}

/// One event of mine as a card, tagged when it is a draft or cancelled.
class MyEventTile extends StatelessWidget {
  const MyEventTile({super.key, required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tag = switch (event.status) {
      EventStatus.draft => l.myEventsDraft,
      EventStatus.cancelled => l.eventStatusCancelled,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tag != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s1),
            child: EventStatusBadge(
              event.status,
              key: Key('my-event-tag-${event.id}'),
            ),
          ),
        EventCard(
          key: Key('my-event-${event.id}'),
          data: eventCardDataOf(event, l),
          onTap: () => context.push(myEventPath(event)),
        ),
      ],
    );
  }
}

/// S06.01 "Sự kiện của tôi": the photographer's next events, drafts tagged
/// "Nháp", with "Xem tất cả" to the full list. Shows nothing while the
/// photographer has no events.
class MyEventsSection extends ConsumerWidget {
  const MyEventsSection({super.key, this.limit = 3});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final events = ref.watch(myEventsProvider);
    final now = ref.watch(clockProvider)();
    return AsyncView<List<EventSummary>>(
      value: events,
      skeleton: (_) => Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: EventCard.skeleton(),
      ),
      loaderSize: LoaderSize.inline,
      onRetry: () => ref.invalidate(myEventsProvider),
      isEmpty: (list) => list.isEmpty,
      empty: (_) => const SizedBox.shrink(),
      data: (context, list) {
        final shown = orderMyEvents(list, now).take(limit).toList();
        return Column(
          key: const Key('my-events-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: l.myEventsTitle,
              actionLabel: list.length > limit ? l.myEventsSeeAll : null,
              onAction: list.length > limit
                  ? () => context.push('/events/mine')
                  : null,
            ),
            for (final e in shown)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  0,
                  AppSpace.s4,
                  AppSpace.s3,
                ),
                child: MyEventTile(event: e),
              ),
          ],
        );
      },
    );
  }
}
