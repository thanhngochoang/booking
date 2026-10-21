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
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
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

  Future<void> _pickDate(DateTime initialDate, List<String> availableDays) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
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
    final todayStr = dayKeyOf(now);
    final currentMonth = now.month;

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

            final schedules =
                ref.watch(spotSchedulesAtProvider(widget.spotId)).value ??
                    const [];
            final offers =
                ref.watch(spotOffersAtProvider(widget.spotId)).value ??
                    const [];
            final events =
                ref.watch(spotEventsProvider(widget.spotId)).value ??
                    const [];
            final posts =
                ref.watch(spotPostsProvider(widget.spotId)).value ??
                    const [];
            final profile = ref.watch(currentProfileProvider).value;
            final isPhotographer = profile?.role == UserRole.photographer;

            // Collect schedule days within next 14 days
            final cutoffDate = now.add(const Duration(days: 14));
            final cutoffStr = dayKeyOf(cutoffDate);
            final upcomingScheduleDays = <String>{};
            for (final s in schedules) {
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

            // Load summaries for providers at this spot
            final providerIds = (schedules.map((s) => s.providerId).toSet().toList()..sort()).join(',');
            final summaries = ref
                    .watch(spotPhotographerSummariesProvider(providerIds))
                    .value ??
                const <String, PhotographerSummary>{};

            // Filter schedules for effective day and visible providers
            final daySchedules = schedules
                .where((s) => s.days.contains(effectiveDay))
                .where((s) {
                  final summary = summaries[s.providerId];
                  // If photographer is known and acceptingOrders is explicitly false, hide them
                  if (summary != null && !summary.acceptingOrders) {
                    return false;
                  }
                  return true;
                })
                .toList();

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
                                color: const Color(0xFF2C3E50),
                                child: const Center(
                                  child: AppIcon(
                                    AppIcons.landscape,
                                    size: 48,
                                    color: Colors.white38,
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
                                color: Colors.white,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0x66000000),
                                ),
                                onPressed: _back,
                              ),
                              IconButton(
                                icon: const AppIcon(AppIcons.share),
                                color: Colors.white,
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0x66000000),
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
                                  l.spotSeasonBest(
                                    'tháng ${formatSeasonRange(spot.seasonMonths)}',
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

                // 6. Providers Block ("Thợ nhận chụp ở đây")
                if (!spot.archived) ...[
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
                  // Date selection chips
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
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
                              sortedDays,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Providers list for effectiveDay
                  if (daySchedules.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.s4,
                          AppSpace.s2,
                          AppSpace.s4,
                          0,
                        ),
                        child: Material(
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
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4,
                        AppSpace.s2,
                        AppSpace.s4,
                        0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final schedule = daySchedules[index];
                            final summary = summaries[schedule.providerId] ??
                                PhotographerSummary(
                                  id: schedule.providerId,
                                  displayName: 'Nhiếp ảnh gia',
                                );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpace.s2),
                              child: SpotProviderCard(
                                key: Key('spot-provider-${schedule.id}'),
                                summary: summary,
                                schedule: schedule,
                                day: effectiveDay,
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
                            );
                          },
                          childCount: daySchedules.length,
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
                  if (offers.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.s4,
                          AppSpace.s5,
                          AppSpace.s4,
                          AppSpace.s2,
                        ),
                        child: Text(
                          l.spotOffersTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s4,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final offer = offers[index];
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
                              final slots = freeSlots(
                                schedule.window,
                                offer,
                                taken,
                              );
                              freeCount = slots.where((s) => s.free).length;
                            }

                            final dayDate = parseDayKey(effectiveDay);
                            final dayFmt = dayDate != null
                                ? formatDay(dayDate)
                                : effectiveDay;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpace.s2),
                              child: SpotOfferCard(
                                key: Key('spot-offer-${offer.id}'),
                                offer: offer,
                                providerName:
                                    summaries[offer.providerId]?.displayName,
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
                                        providerName: summaries[
                                                offer.providerId]
                                            ?.displayName,
                                      ),
                              ),
                            );
                          },
                          childCount: offers.length,
                        ),
                      ),
                    ),
                  ],
                ],

                // 8. Events Block ("Sự kiện ở đây")
                if (events.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4,
                        AppSpace.s5,
                        AppSpace.s4,
                        AppSpace.s2,
                      ),
                      child: Text(
                        l.spotEventsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final e = events[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.s2),
                            child: EventCard(
                              key: Key('spot-event-${e.id}'),
                              data: eventCardDataOf(e, l),
                              onTap: () => context.push(eventPath(e.id)),
                              size: EventCardSize.row,
                            ),
                          );
                        },
                        childCount: events.length,
                      ),
                    ),
                  ),
                ],

                // 9. Photos Block ("Ảnh chụp ở đây")
                if (posts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
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
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: AppSpace.s2,
                        mainAxisSpacing: AppSpace.s2,
                        childAspectRatio: 3 / 4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = posts[index];
                          final cover = post.images.firstOrNull;
                          return Semantics(
                            link: true,
                            label: post.caption.isNotEmpty
                                ? post.caption
                                : 'Ảnh chụp tại ${spot.name}',
                            child: Material(
                              color: dark
                                  ? AppColorsDark.glass
                                  : AppColors.glass,
                              clipBehavior: Clip.antiAlias,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              child: InkWell(
                                key: Key('spot-photo-${post.id}'),
                                onTap: () => context.push('/p/${post.id}'),
                                child: cover != null
                                    ? NetworkPhoto(
                                        url: cover.url,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: AppIcon(
                                          AppIcons.image,
                                          size: 28,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                        childCount: _expandedPhotos
                            ? posts.length
                            : (posts.length > 9 ? 9 : posts.length),
                      ),
                    ),
                  ),
                  if (posts.length > 9 && !_expandedPhotos)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s3,
                          ),
                          child: TextButton(
                            onPressed: () {
                              setState(() => _expandedPhotos = true);
                              ref
                                  .read(
                                    spotPostsProvider(widget.spotId).notifier,
                                  )
                                  .loadMore();
                            },
                            child: Text(l.spotSeeMore),
                          ),
                        ),
                      ),
                    ),
                ],

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
}
