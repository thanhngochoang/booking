// lib/features/spots/spot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
import 'package:photobooking/features/organizer/organizer_routes.dart';
import 'package:photobooking/features/explore/event_routes.dart';
import 'package:photobooking/features/spots/slot_pick_sheet.dart';
import 'package:photobooking/features/spots/spot_format.dart';
import 'package:photobooking/features/spots/spot_posts_controller.dart';
import 'package:photobooking/features/spots/widgets/spot_offer_card.dart';
import 'package:photobooking/features/spots/widgets/spot_provider_card.dart';

/// S29.02: Detailed photo spot screen with hero cover, season tag, tips,
/// map directions, providers for chosen date, slot offers, events, and photos.
class SpotScreen extends ConsumerStatefulWidget {
  const SpotScreen({
    super.key,
    required this.spotId,
    this.date,
  });

  final String spotId;
  final String? date;

  @override
  ConsumerState<SpotScreen> createState() => _SpotScreenState();
}

class _SpotScreenState extends ConsumerState<SpotScreen> {
  String? _selectedDay;
  bool _expandedPhotos = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.date;
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.home.path);
    }
  }

  Future<void> _share(Spot spot) async {
    final l = context.l10n;
    await copySpotLink(spot.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.spotLinkCopied)));
    }
  }

  Future<void> _openDirections(Spot spot) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${spot.lat},${spot.lng}',
    );
    await ref.read(externalLauncherProvider).open(uri);
  }

  Future<void> _pickDate(DateTime initialDate, DateTime now) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDay = dayKeyOf(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final now = ref.watch(clockProvider)();
    // Days are Vietnamese calendar days, not UTC ones.
    final todayStr = vnDateKey(now);
    final currentMonth = toVn(now).month;

    final spotAsync = ref.watch(spotProvider(widget.spotId));

    return ScreenCode(
      ScreenCodes.spotDetail,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AsyncView<Spot?>(
          value: spotAsync,
          error: (context, err, _) => Center(
            child: ErrorState(
              message: l.spotNotFound,
              onRetry: () => ref.invalidate(spotProvider(widget.spotId)),
            ),
          ),
          data: (context, spot) {
            if (spot == null) {
              return Center(
                child: ErrorState(
                  message: l.spotNotFound,
                  onRetry: () => ref.invalidate(spotProvider(widget.spotId)),
                ),
              );
            }

            final schedulesAsync =
                ref.watch(spotSchedulesAtProvider(widget.spotId));
            // The day chips and the default day follow the loaded schedules;
            // the sections below wait on their own reads (AsyncView).
            final loadedSchedules =
                schedulesAsync.value ?? const <SpotSchedule>[];
            final profile = ref.watch(currentProfileProvider).value;
            final isPhotographer = profile?.role == UserRole.photographer;

            // Collect schedule days within next 14 days
            final cutoffStr = vnDateKey(now.add(const Duration(days: 14)));
            final upcomingScheduleDays = <String>{};
            for (final s in loadedSchedules) {
              for (final d in s.days) {
                if (d.compareTo(todayStr) >= 0 && d.compareTo(cutoffStr) <= 0) {
                  upcomingScheduleDays.add(d);
                }
              }
            }
            final sortedDays = upcomingScheduleDays.toList()..sort();

            // Default selected day if not explicitly set
            final effectiveDay = _selectedDay ??
                (sortedDays.contains(todayStr)
                    ? todayStr
                    : (sortedDays.isNotEmpty ? sortedDays.first : todayStr));

            // Providers need their public summaries (name, acceptingOrders)
            // before the block draws: schedules and summaries load together.
            final providerIds = (loadedSchedules
                    .map((s) => s.providerId)
                    .toSet()
                    .toList()
                  ..sort())
                .join(',');
            final providersView = _both(
              schedulesAsync,
              ref.watch(spotPhotographerSummariesProvider(providerIds)),
            );
            void retryProviders() {
              ref.invalidate(spotSchedulesAtProvider(widget.spotId));
              ref.invalidate(spotPhotographerSummariesProvider(providerIds));
            }

            final offersView = _both(
              ref.watch(spotOffersAtProvider(widget.spotId)),
              providersView,
            );
            void retryOffers() {
              ref.invalidate(spotOffersAtProvider(widget.spotId));
              if (providersView.hasError) retryProviders();
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Hero & Cover Image
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: spot.cover?.url != null &&
                                spot.cover!.url.isNotEmpty
                            ? NetworkPhoto(
                                url: spot.cover!.url,
                                fit: BoxFit.cover,
                                semanticLabel: spot.name,
                              )
                            : Container(
                                color: dark
                                    ? AppColorsDark.surfaceMuted
                                    : AppColors.surfaceMuted,
                                child: Center(
                                  child: AppIcon(
                                    AppIcons.landscape,
                                    size: 48,
                                    color: dark
                                        ? AppColorsDark.foregroundMuted
                                        : AppColors.foregroundMuted,
                                  ),
                                ),
                              ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: AppSpace.s1,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const AppIcon(AppIcons.back),
                                color: AppColors.onScrim,
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.overlay,
                                ),
                                onPressed: _back,
                              ),
                              IconButton(
                                icon: const AppIcon(AppIcons.share),
                                color: AppColors.onScrim,
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.overlay,
                                ),
                                onPressed: () => _share(spot),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Archived Notice Band
                if (spot.archived)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s4,
                        vertical: 10,
                      ),
                      color: scheme.errorContainer,
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.info,
                            size: 16,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: AppSpace.s2),
                          Expanded(
                            child: Text(
                              l.spotArchivedBand,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 2. Header & Info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4,
                      AppSpace.s4,
                      AppSpace.s4,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          spot.city,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: dark
                                ? AppColorsDark.foregroundSecondary
                                : AppColors.foregroundSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (spot.seasonMonths.isNotEmpty) ...[
                          if (inSeason(spot.seasonMonths, currentMonth))
                            SeasonTag(
                              label: l.spotInSeasonUntil(
                                seasonRunEnd(spot.seasonMonths, currentMonth) ??
                                    currentMonth,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  AppIcons.eco,
                                  size: 15,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l.spotSeasonList(
                                    formatSeasonRange(spot.seasonMonths),
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ] else
                          Text(
                            l.spotSeasonAllYear,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: AppSpace.s3),
                        // 3. Description
                        Text(
                          spot.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        // 4. Tips List
                        if (spot.tips.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpace.s3),
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColorsDark.glass
                                  : AppColors.glass,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AppIcon(
                                      AppIcons.lightbulb,
                                      size: 16,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l.spotTipsTitle,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                for (final tip in spot.tips.take(5))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ',
                                            style: TextStyle(fontSize: 13)),
                                        Expanded(
                                          child: Text(
                                            tip,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpace.s3),
                        ],
                        // 5. Map & Directions
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: dark
                                      ? AppColorsDark.surfaceMuted
                                      : AppColors.backgroundSubtle,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border:
                                      Border.all(color: scheme.outlineVariant),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppIcon(
                                        AppIcons.place,
                                        size: 16,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          spot.name,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            OutlinedButton.icon(
                              onPressed: () => _openDirections(spot),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                              ),
                              icon: const AppIcon(AppIcons.directions, size: 16),
                              label: Text(l.spotDirections),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Providers Block ("Thợ nhận chụp ở đây"), under the
                // S29.02-entry block of a ticketed spot.
                if (!spot.archived) ...[
                  if (spot.ticketedWith(
                    ref.watch(entryEventProvider(spot.id)).value,
                  ))
                    SliverToBoxAdapter(child: _EntryBlock(spot: spot)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4,
                        AppSpace.s5,
                        AppSpace.s4,
                        AppSpace.s2,
                      ),
                      child: Text(
                        l.spotProvidersTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Date chips and the providers of the chosen day
                  SliverToBoxAdapter(
                    child: AsyncView<
                        (List<SpotSchedule>, Map<String, PhotographerSummary>)>(
                      value: providersView,
                      skeleton: (_) => const _CardsSkeleton(
                        key: Key('spot-providers-skeleton'),
                        card: _SkeletonCard.provider,
                      ),
                      onRetry: retryProviders,
                      error: (context, err, _) => ErrorState(
                        key: const Key('spot-providers-error'),
                        message: errorMessage(err, l),
                        onRetry: retryProviders,
                      ),
                      data: (context, v) => _providersBlock(
                        context,
                        spot: spot,
                        schedules: v.$1,
                        summaries: v.$2,
                        todayStr: todayStr,
                        sortedDays: sortedDays,
                        effectiveDay: effectiveDay,
                        now: now,
                      ),
                    ),
                  ),

                  // Provider hint for photographers
                  if (isPhotographer)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.s4,
                          AppSpace.s3,
                          AppSpace.s4,
                          0,
                        ),
                        child: InkWell(
                          onTap: () => context.push(
                            '/me/spot-schedules/new?spotId=${spot.id}',
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpace.s3),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                AppIcon(
                                  AppIcons.work,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: AppSpace.s2),
                                Expanded(
                                  child: Text(
                                    l.spotProviderHint,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 7. Slot Offers Block ("Gói chụp tại điểm")
                  SliverToBoxAdapter(
                    child: AsyncView<
                        (
                          List<SlotOffer>,
                          (
                            List<SpotSchedule>,
                            Map<String, PhotographerSummary>
                          )
                        )>(
                      value: offersView,
                      skeleton: (_) => _Section(
                        title: l.spotOffersTitle,
                        child: const _CardsSkeleton(
                          key: Key('spot-offers-skeleton'),
                          card: _SkeletonCard.offer,
                          count: 1,
                        ),
                      ),
                      onRetry: retryOffers,
                      error: (context, err, _) => _Section(
                        title: l.spotOffersTitle,
                        child: ErrorState(
                          key: const Key('spot-offers-error'),
                          message: errorMessage(err, l),
                          onRetry: retryOffers,
                        ),
                      ),
                      isEmpty: (v) => v.$1.isEmpty,
                      empty: (_) => const SizedBox.shrink(),
                      data: (context, v) => _Section(
                        title: l.spotOffersTitle,
                        child: _offersBlock(
                          context,
                          spot: spot,
                          offers: v.$1,
                          schedules: v.$2.$1,
                          summaries: v.$2.$2,
                          effectiveDay: effectiveDay,
                        ),
                      ),
                    ),
                  ),
                ],

                // 8. Events Block ("Sự kiện ở đây")
                SliverToBoxAdapter(
                  child: AsyncView<List<EventSummary>>(
                    value: ref.watch(spotEventsProvider(widget.spotId)),
                    skeleton: (_) => _Section(
                      title: l.spotEventsTitle,
                      child: AppSkeleton.group(
                        child: EventCard.skeleton(
                          key: const Key('spot-events-skeleton'),
                        ),
                      ),
                    ),
                    onRetry: () =>
                        ref.invalidate(spotEventsProvider(widget.spotId)),
                    error: (context, err, _) => _Section(
                      title: l.spotEventsTitle,
                      child: ErrorState(
                        key: const Key('spot-events-error'),
                        message: errorMessage(err, l),
                        onRetry: () =>
                            ref.invalidate(spotEventsProvider(widget.spotId)),
                      ),
                    ),
                    isEmpty: (events) => events.isEmpty,
                    empty: (_) => const SizedBox.shrink(),
                    data: (context, events) => _Section(
                      title: l.spotEventsTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final e in events)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpace.s2),
                              child: EventCard(
                                key: Key('spot-event-${e.id}'),
                                data: eventCardDataOf(e, l),
                                onTap: () => context.push(eventPath(e.id)),
                                size: EventCardSize.row,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 9. Photos Block ("Ảnh chụp ở đây")
                SliverToBoxAdapter(
                  child: AsyncView<List<PostSummary>>(
                    value: ref.watch(spotPostsProvider(widget.spotId)),
                    skeleton: (_) => _Section(
                      title: l.spotPhotosTitle,
                      child: const _PhotosSkeleton(
                        key: Key('spot-photos-skeleton'),
                      ),
                    ),
                    onRetry: () =>
                        ref.invalidate(spotPostsProvider(widget.spotId)),
                    error: (context, err, _) => _Section(
                      title: l.spotPhotosTitle,
                      child: ErrorState(
                        key: const Key('spot-photos-error'),
                        message: errorMessage(err, l),
                        onRetry: () =>
                            ref.invalidate(spotPostsProvider(widget.spotId)),
                      ),
                    ),
                    isEmpty: (posts) => posts.isEmpty,
                    empty: (_) => const SizedBox.shrink(),
                    data: (context, posts) =>
                        _photosBlock(context, spot: spot, posts: posts),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpace.s8),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Day chips, then the providers of [effectiveDay] (or the empty card).
  Widget _providersBlock(
    BuildContext context, {
    required Spot spot,
    required List<SpotSchedule> schedules,
    required Map<String, PhotographerSummary> summaries,
    required String todayStr,
    required List<String> sortedDays,
    required String effectiveDay,
    required DateTime now,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    // S29.02-entry: at a ticketed spot, residents (waiver valid on the day)
    // first with their tag; the others say what the tickets cost.
    final onSale = ref.watch(entryEventProvider(spot.id)).value;
    final ticketed = spot.ticketedWith(onSale);
    final residents = {
      if (ticketed)
        for (final r
            in ref.watch(spotResidentsProvider(spot.id)).value ??
                const <Resident>[])
          r.providerId: r.waiverFor(effectiveDay),
    };
    bool resident(String id) {
      final w = residents[id];
      return w != null && (w.provider || w.guests);
    }

    final unit = ticketed ? entryUnitPrice(onSale, spot.access) : null;

    // Schedules of the day whose provider still takes orders (spec §12).
    final daySchedules = schedules
        .where((s) => s.days.contains(effectiveDay))
        .where((s) => summaries[s.providerId]?.acceptingOrders != false)
        .toList();
    if (ticketed) {
      final first = [
        for (final s in daySchedules)
          if (resident(s.providerId)) s,
      ];
      daySchedules
        ..removeWhere((s) => resident(s.providerId))
        ..insertAll(0, first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s1,
          ),
          child: Row(
            children: [
              AppChip(
                key: const Key('chip-day-today'),
                label: l.spotDayToday,
                selected: effectiveDay == todayStr,
                onChanged: (_) {
                  setState(() => _selectedDay = todayStr);
                },
              ),
              const SizedBox(width: AppSpace.s2),
              for (final day in sortedDays)
                if (day != todayStr) ...[
                  AppChip(
                    key: Key('chip-day-$day'),
                    label: formatDay(parseDayKey(day)!),
                    selected: effectiveDay == day,
                    onChanged: (_) {
                      setState(() => _selectedDay = day);
                    },
                  ),
                  const SizedBox(width: AppSpace.s2),
                ],
              AppChip(
                key: const Key('chip-day-pick'),
                label: l.spotDayPick,
                selected: false,
                leading: const AppIcon(AppIcons.calendar, size: 14),
                onChanged: (_) => _pickDate(
                  parseDayKey(effectiveDay) ?? now,
                  now,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            0,
          ),
          child: daySchedules.isEmpty
              ? Material(
                  color: dark ? AppColorsDark.glass : AppColors.glass,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s3,
                      vertical: AppSpace.s4,
                    ),
                    child: Column(
                      children: [
                        AppIcon(
                          AppIcons.eventBusy,
                          size: 28,
                          color: dark
                              ? AppColorsDark.foregroundMuted
                              : AppColors.foregroundMuted,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.spotNoProviderDay,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (sortedDays.isNotEmpty &&
                            sortedDays.first != effectiveDay) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDay = sortedDays.first;
                              });
                            },
                            child: Text(l.spotEmptyDayAction),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final schedule in daySchedules)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s2),
                        child: SpotProviderCard(
                          key: Key('spot-provider-${schedule.id}'),
                          summary: summaries[schedule.providerId] ??
                              PhotographerSummary(
                                id: schedule.providerId,
                                displayName: l.profileRolePhotographer,
                              ),
                          schedule: schedule,
                          day: effectiveDay,
                          residentTag: !resident(schedule.providerId)
                              ? null
                              : residents[schedule.providerId]!.guests
                              ? l.s2902_resident
                              : l.s2902_residentProvider,
                          entryLine:
                              ticketed &&
                                  !resident(schedule.providerId) &&
                                  unit != null
                              ? l.s2902_needTickets(formatMoney(unit * 2))
                              : null,
                          onProfile: () =>
                              context.push('/u/${schedule.providerId}'),
                          onBook: () => startBooking(
                            context,
                            ref,
                            photographerId: schedule.providerId,
                            scheduleId: schedule.id,
                            date: parseDayKey(effectiveDay),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// The open slot offers with their free slots on [effectiveDay].
  Widget _offersBlock(
    BuildContext context, {
    required Spot spot,
    required List<SlotOffer> offers,
    required List<SpotSchedule> schedules,
    required Map<String, PhotographerSummary> summaries,
    required String effectiveDay,
  }) {
    final dayDate = parseDayKey(effectiveDay);
    final dayFmt = dayDate != null ? formatDay(dayDate) : effectiveDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final offer in offers)
          Builder(
            builder: (context) {
              final schedule = schedules
                  .where((s) => s.id == offer.scheduleId)
                  .firstOrNull;

              var freeCount = 0;
              if (schedule != null) {
                final spotDay = ref
                    .watch(spotDayProvider((
                      scheduleId: schedule.id,
                      day: effectiveDay,
                    )))
                    .value;
                final taken = spotDay?.taken ?? const [];
                freeCount = freeSlots(schedule.window, offer, taken)
                    .where((s) => s.free)
                    .length;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: SpotOfferCard(
                  key: Key('spot-offer-${offer.id}'),
                  offer: offer,
                  providerName: summaries[offer.providerId]?.displayName,
                  freeSlotsCount: freeCount,
                  dayFormatted: dayFmt,
                  onPickSlot: schedule == null
                      ? null
                      : () => showSlotPickSheet(
                            context,
                            ref,
                            offer: offer,
                            schedule: schedule,
                            spotName: spot.name,
                            day: effectiveDay,
                            providerName:
                                summaries[offer.providerId]?.displayName,
                          ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// Photos tagged at the spot: 9 tiles, then all after "Xem thêm".
  Widget _photosBlock(
    BuildContext context, {
    required Spot spot,
    required List<PostSummary> posts,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final shown = _expandedPhotos ? posts : posts.take(9).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s5,
            AppSpace.s4,
            AppSpace.s2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.spotPhotosTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                l.spotPhotosCount(posts.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: dark
                      ? AppColorsDark.foregroundMuted
                      : AppColors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpace.s2,
          mainAxisSpacing: AppSpace.s2,
          childAspectRatio: 3 / 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          children: [
            for (final post in shown)
              Semantics(
                link: true,
                label: post.caption.isNotEmpty
                    ? post.caption
                    : l.spotPhotoAlt(spot.name),
                child: Material(
                  color: dark ? AppColorsDark.glass : AppColors.glass,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: InkWell(
                    key: Key('spot-photo-${post.id}'),
                    onTap: () => context.push('/p/${post.id}'),
                    child: post.images.firstOrNull != null
                        ? NetworkPhoto(
                            url: post.images.first.url,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: AppIcon(AppIcons.image, size: 28),
                          ),
                  ),
                ),
              ),
          ],
        ),
        if (posts.length > 9 && !_expandedPhotos)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
              child: TextButton(
                onPressed: () {
                  setState(() => _expandedPhotos = true);
                  ref
                      .read(spotPostsProvider(widget.spotId).notifier)
                      .loadMore();
                },
                child: Text(l.spotSeeMore),
              ),
            ),
          ),
      ],
    );
  }
}

/// Both values once both have loaded; otherwise the first error, else loading.
AsyncValue<(A, B)> _both<A, B>(AsyncValue<A> a, AsyncValue<B> b) {
  if (a.hasValue && b.hasValue) {
    return AsyncData((a.requireValue, b.requireValue));
  }
  if (a.hasError) return AsyncError(a.error!, a.stackTrace ?? StackTrace.empty);
  if (b.hasError) return AsyncError(b.error!, b.stackTrace ?? StackTrace.empty);
  return const AsyncLoading();
}

/// A titled S29.02 block (title row above [child]).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s5,
            AppSpace.s4,
            AppSpace.s2,
          ),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: child,
        ),
      ],
    );
  }
}

enum _SkeletonCard { provider, offer }

/// Stand-ins for provider or offer cards while their block loads.
class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton({super.key, required this.card, this.count = 2});

  final _SkeletonCard card;
  final int count;

  @override
  Widget build(BuildContext context) {
    final one = switch (card) {
      _SkeletonCard.provider => SpotProviderCard.skeleton(),
      _SkeletonCard.offer => SpotOfferCard.skeleton(),
    };
    return AppSkeleton.group(
      child: Padding(
        padding: card == _SkeletonCard.provider
            ? const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s2,
                AppSpace.s4,
                0,
              )
            : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: one,
              ),
          ],
        ),
      ),
    );
  }
}

/// Two photo tiles while the photos block loads.
class _PhotosSkeleton extends StatelessWidget {
  const _PhotosSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton.group(
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s2),
            Expanded(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: AppSkeleton.box(height: 1, radius: AppRadius.card),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// S29.02-entry: the spot's entry fee above "Thợ nhận chụp ở đây". With
/// tickets on sale: the prices per type, the opening hours, "Bán bởi {chủ}"
/// and a small "Mua vé" (→ S30.05); else the reference prices with their
/// date and no button.
class _EntryBlock extends ConsumerWidget {
  const _EntryBlock({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final event = ref.watch(entryEventProvider(spot.id)).value;
    final types = event?.visibleTicketTypes ?? const <EntryTicketType>[];
    final onSale = types.isNotEmpty;
    final hours = event?.openHours ?? spot.openHours;
    final access = spot.access;
    final rows = onSale
        ? [
            for (final t in types)
              l.s2902_typePrice(t.name, formatMoney(t.price)),
          ]
        : [
            for (final f in access?.fees ?? const <AccessFee>[])
              l.s2902_typePrice(f.label, formatMoney(f.amountVnd)),
          ];
    final updated = access?.updatedAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s5,
        AppSpace.s4,
        0,
      ),
      child: GlassCard(
        key: const Key('spot-entry'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(AppIcons.ticket, size: 18, color: secondary),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      l.s2902_entry,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hours != null)
                    Text(
                      '${hours.start}–${hours.end}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s2),
                Wrap(
                  spacing: AppSpace.s3,
                  runSpacing: AppSpace.s1,
                  children: [
                    for (final r in rows)
                      Text(r, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s2),
              if (onSale)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.s2902_soldBy(event!.organizerName),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    AppButton.primary(
                      l.s2902_buy,
                      key: const Key('spot-entry-buy'),
                      size: AppButtonSize.xsmall,
                      onPressed: () => context.push(spotTicketsPath(spot.id)),
                    ),
                  ],
                )
              else if (updated != null)
                Text(
                  l.s2902_refPrice(formatDayMonth(toVn(updated))),
                  key: const Key('spot-entry-ref'),
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
