// lib/features/events/events_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/events/events_list_controller.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/event_routes.dart';

/// S11.01: the public list of events, filtered by type, free or near me.
class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
      ref.read(eventsListProvider.notifier).loadMore();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.home.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = ref.watch(eventsFilterProvider);
    final list = ref.watch(eventsListProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final staff = ref.watch(staffRoleProvider).value;
    final isManager = staff != null || profile?.role == UserRole.photographer;
    final canCreate =
        staff != null ||
        (profile?.role == UserRole.photographer &&
            (ref.watch(myIntroProvider).value?.onboardingComplete ?? false));

    return ScreenCode(
      ScreenCodes.events,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          leading: IconButton(
            tooltip: l.back,
            icon: const AppIcon(AppIcons.back),
            onPressed: _back,
          ),
          title: Text(l.eventsTitle),
          actions: [
            IconButton(
              key: const Key('events-mine'),
              tooltip: isManager ? l.eventsManage : l.eventsMyTickets,
              icon: const AppIcon(AppIcons.calendar),
              onPressed: () => context.push(
                isManager ? '/events/mine' : '/bookings?tab=events',
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TagRow(
              selected: filter.type,
              onSelected: ref.read(eventsFilterProvider.notifier).setType,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.s2,
                children: [
                  AppChip(
                    key: const Key('events-free-chip'),
                    label: l.freeTag,
                    selected: filter.freeOnly,
                    onChanged: (_) =>
                        ref.read(eventsFilterProvider.notifier).toggleFree(),
                  ),
                  SizedBox(
                    width: 210,
                    child: SegmentedTabs<EventsSort>(
                      options: [
                        SegmentOption(
                          value: EventsSort.soonest,
                          label: l.eventsSortSoonest,
                        ),
                        SegmentOption(
                          value: EventsSort.near,
                          label: l.eventsSortNear,
                        ),
                      ],
                      value: filter.sort,
                      onChanged: ref
                          .read(eventsFilterProvider.notifier)
                          .setSort,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: ref.read(eventsListProvider.notifier).refresh,
                child: AsyncView<EventsListState>(
                  value: list,
                  skeleton: (_) => _skeleton(),
                  onRetry: () => ref.invalidate(eventsListProvider),
                  isEmpty: (s) => s.events.isEmpty,
                  empty: (_) => _empty(
                    context,
                    needsArea: list.value?.needsArea ?? false,
                    canCreate: canCreate,
                  ),
                  data: (_, s) => _list(context, s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeleton() => AppSkeletonScope(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        EventCard.skeleton(size: EventCardSize.featured),
        for (var i = 0; i < 3; i++) ...[
          const SizedBox(height: AppSpace.s3),
          EventCard.skeleton(size: EventCardSize.row),
        ],
      ],
    ),
  );

  /// Scrollable even when short, so pull to refresh also works on an empty
  /// list.
  Widget _empty(
    BuildContext context, {
    required bool needsArea,
    required bool canCreate,
  }) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: needsArea
              ? EmptyState(
                  title: l.eventsNeedArea,
                  body: '',
                  actionLabel: l.locationChooseArea,
                  onAction: () => showAreaPicker(context),
                )
              : EmptyState(
                  title: l.eventsEmpty,
                  body: l.eventsEmptyBody,
                  actionLabel: canCreate ? l.eventsCreate : null,
                  onAction: canCreate
                      ? () => context.push('/events/new')
                      : null,
                ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, EventsListState s) {
    final l = context.l10n;
    EventCard card(EventSummary e, EventCardSize size) {
      final km = s.distances[e.id];
      return EventCard(
        key: Key('event-card-${e.id}'),
        data: eventCardDataOf(e, l),
        size: size,
        distanceLabel: km == null ? null : formatDistance(km),
        onTap: () => context.push(eventPath(e.id)),
      );
    }

    final rest = s.events.skip(1).toList();
    return CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s3,
            AppSpace.s4,
            AppSpace.s3,
          ),
          sliver: SliverToBoxAdapter(
            child: card(s.events.first, EventCardSize.featured),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          sliver: SliverAdaptiveRows(
            itemCount: rest.length,
            itemBuilder: (_, i) => card(rest[i], EventCardSize.row),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: s.loadingMore
                ? EventCard.skeleton(size: EventCardSize.row)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// The text tag row (mock `.htags`): "Tất cả" then one tag per type. The
/// selected tag is primary, bold and underlined 2dp; the others are
/// secondary text.
class _TagRow extends StatelessWidget {
  const _TagRow({required this.selected, required this.onSelected});

  final EventType? selected;
  final ValueChanged<EventType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = <(EventType?, String)>[
      (null, l.eventsAll),
      for (final t in EventType.listed) (t, t.tag),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key('events-tags'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        children: [
          for (final (type, label) in entries)
            _Tag(
              label: label,
              selected: type == selected,
              onTap: () => onSelected(type),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final color = selected ? theme.colorScheme.primary : secondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppText.base,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
