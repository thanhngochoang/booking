// lib/features/spots/my_spot_schedules_screen.dart
// S29.03 "Lịch tại điểm": the provider's open spot schedules with their days,
// window, packages, per-day bookings and slot offers. Per-day counts come
// from the provider's bookings the work tab already listens to (Decision 21),
// never from `spot_days`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/spots/slot_offer_sheet.dart';
import 'package:photobooking/features/spots/spot_format.dart';
import 'package:photobooking/features/spots/spot_schedule_edit_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Day chips shown on a card before "+{n} ngày".
const _shownDays = 4;

/// Statuses that no longer hold a time at the spot.
const _released = {
  BookingStatus.draft,
  BookingStatus.declined,
  BookingStatus.expired,
  BookingStatus.cancelled,
};

/// Everything S29.03 shows, read together.
@immutable
class MySpotSchedulesView {
  const MySpotSchedulesView({
    required this.today,
    required this.schedules,
    required this.offers,
    required this.counts,
    required this.spots,
  });

  /// `yyyy-MM-dd`, Vietnam.
  final String today;

  /// Open schedules, the soonest first.
  final List<SpotSchedule> schedules;

  /// Open offers by schedule id.
  final Map<String, List<SlotOffer>> offers;

  /// Bookings holding a time, by schedule id then day.
  final Map<String, Map<String, int>> counts;

  /// Directory entries by spot id (active spots only).
  final Map<String, SpotEntry> spots;

  int get openCount => openScheduleCount(schedules, today);
}

/// The first value of [values] that is an error without data, else loading
/// while any is still loading.
AsyncValue<T>? _pending<T>(List<AsyncValue<Object?>> values) {
  for (final v in values) {
    if (v.hasError && !v.hasValue) {
      return AsyncError<T>(v.error!, v.stackTrace ?? StackTrace.current);
    }
  }
  if (values.any((v) => !v.hasValue)) return AsyncLoading<T>();
  return null;
}

/// Booking counts per schedule and day from the provider's own bookings.
Map<String, Map<String, int>> spotBookingCounts(Iterable<Booking> bookings) {
  final out = <String, Map<String, int>>{};
  for (final b in bookings) {
    final id = b.spotScheduleId;
    if (id == null || _released.contains(b.status)) continue;
    final days = out[id] ??= {};
    days[b.day] = (days[b.day] ?? 0) + 1;
  }
  return out;
}

final mySpotSchedulesViewProvider =
    Provider.autoDispose<AsyncValue<MySpotSchedulesView>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const AsyncLoading();
      final schedules = ref.watch(mySpotSchedulesProvider(uid));
      final offers = ref.watch(mySlotOffersProvider(uid));
      final bookings = ref.watch(myBookingsProvider(BookingRole.photographer));
      final directory = ref.watch(spotDirectoryProvider);
      final pending = _pending<MySpotSchedulesView>([
        schedules,
        offers,
        bookings,
        directory,
      ]);
      if (pending != null) return pending;
      final today = vnDateKey(ref.watch(clockProvider)());
      String firstDay(SpotSchedule s) =>
          s.days.where((d) => d.compareTo(today) >= 0).firstOrNull ??
          '9999-12-31';
      final list = [
        for (final s in schedules.requireValue)
          if (s.open) s,
      ]..sort((a, b) => firstDay(a).compareTo(firstDay(b)));
      final byOffer = <String, List<SlotOffer>>{};
      for (final o in offers.requireValue) {
        if (o.open) (byOffer[o.scheduleId] ??= []).add(o);
      }
      return AsyncData(
        MySpotSchedulesView(
          today: today,
          schedules: list,
          offers: byOffer,
          counts: spotBookingCounts(bookings.requireValue),
          spots: {for (final e in directory.requireValue) e.spotId: e},
        ),
      );
    });

/// `/me/spot-schedules`.
class MySpotSchedulesScreen extends ConsumerWidget {
  const MySpotSchedulesScreen({super.key});

  void _say(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// "Còn {n} booking ngày {ngày}…" for the first day in [counts].
  String? _hasBookings(AppLocalizations l, Map<String, int> counts) {
    final days = [
      for (final e in counts.entries)
        if (e.value > 0) e.key,
    ]..sort();
    if (days.isEmpty) return null;
    final date = parseDayKey(days.first);
    return l.spotScheduleHasBookings(
      counts[days.first]!,
      date == null ? days.first : formatDay(date),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref, {
    required SpotSchedule schedule,
    required String spotName,
    required Map<String, int> upcoming,
  }) async {
    final l = context.l10n;
    // Bookings the provider can already see block the cancel outright.
    if (_hasBookings(l, upcoming) case final blocked?) {
      _say(context, blocked);
      return;
    }
    Object? failure;
    final confirmed = await showConfirmSheet(
      context,
      title: l.spotScheduleCancelTitle(spotName),
      body: l.spotScheduleCancelBody,
      confirmLabel: l.spotScheduleCancelConfirm,
      keepLabel: l.spotScheduleCancelKeep,
      onConfirm: () async {
        try {
          await ref.read(spotRepositoryProvider).cancelSchedule(schedule.id);
        } catch (e) {
          failure = e;
        }
      },
    );
    if (!confirmed || !context.mounted) return;
    final error = failure;
    if (error == null) {
      _say(context, l.spotScheduleCancelled);
      return;
    }
    final e = spotErrorOf(error);
    final text = e.code == SpotErrorCode.scheduleHasBookings
        ? _hasBookings(
            l,
            e.bookingCounts.isNotEmpty ? e.bookingCounts : upcoming,
          )
        : null;
    _say(context, text ?? l.spotScheduleCancelFailed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final view = ref.watch(mySpotSchedulesViewProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    return ScreenCode(
      ScreenCodes.mySpotSchedules,
      child: Scaffold(
        appBar: AppBar(title: Text(l.spotSchedulesTitle)),
        body: AsyncView<MySpotSchedulesView>(
          value: view,
          skeleton: (_) => const _Skeleton(),
          onRetry: () {
            if (uid != null) {
              ref
                ..invalidate(mySpotSchedulesProvider(uid))
                ..invalidate(mySlotOffersProvider(uid));
            }
            ref
              ..invalidate(myBookingsProvider(BookingRole.photographer))
              ..invalidate(spotDirectoryProvider);
          },
          isEmpty: (v) => v.schedules.isEmpty,
          empty: (context) => Column(
            children: [
              Expanded(
                child: EmptyState(
                  title: l.spotSchedulesEmptyTitle,
                  body: l.spotSchedulesEmptyBody,
                ),
              ),
              const _Footer(openCount: 0),
            ],
          ),
          data: (context, v) => Column(
            children: [
              Expanded(child: _list(context, ref, v)),
              _Footer(openCount: v.openCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, MySpotSchedulesView v) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s4,
      ),
      children: [
        Text(
          l.spotSchedulesOpenCount(v.openCount),
          key: const Key('spot-schedules-count'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        for (final s in v.schedules) ...[
          _ScheduleCard(
            key: Key('spot-schedule-${s.id}'),
            schedule: s,
            spot: v.spots[s.spotId],
            offers: v.offers[s.id] ?? const [],
            counts: v.counts[s.id] ?? const {},
            today: v.today,
            onEdit: () => context.push('/me/spot-schedules/${s.id}'),
            onOffer: (offer) =>
                showSlotOfferSheet(context, schedule: s, offer: offer),
            onCancel: (spotName, upcoming) => _cancel(
              context,
              ref,
              schedule: s,
              spotName: spotName,
              upcoming: upcoming,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(AppIcons.info, size: 18, color: muted),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text(
                l.spotSchedulesRule,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The one primary action: "Thêm lịch tại điểm" (off at 8 open schedules),
/// or "Xác minh để mở lịch" while the provider does not take orders.
class _Footer extends ConsumerWidget {
  const _Footer({required this.openCount});

  final int openCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final closed = ref.watch(myIntroProvider).value?.acceptingOrders == false;
    final verifyReady = ref.watch(verifyStartReadyProvider);
    return AppFooterBar(
      child: closed
          ? AppButton.primary(
              l.spotSchedulesVerify,
              key: const Key('spot-schedules-verify'),
              onPressed: verifyReady
                  ? () => context.push('/verify/start')
                  : null,
            )
          : AppButton.primary(
              l.spotSchedulesAdd,
              key: const Key('spot-schedules-add'),
              onPressed: openCount >= kSpotScheduleMaxOpen
                  ? null
                  : () => context.push('/me/spot-schedules/new'),
            ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({
    super.key,
    required this.schedule,
    required this.spot,
    required this.offers,
    required this.counts,
    required this.today,
    required this.onEdit,
    required this.onOffer,
    required this.onCancel,
  });

  final SpotSchedule schedule;
  final SpotEntry? spot;
  final List<SlotOffer> offers;
  final Map<String, int> counts;
  final String today;
  final VoidCallback onEdit;
  final ValueChanged<SlotOffer?> onOffer;
  final void Function(String spotName, Map<String, int> upcoming) onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final s = schedule;
    // An archived spot is out of the directory: one read of its document.
    final name =
        spot?.name ?? ref.watch(spotProvider(s.spotId)).value?.name ?? '';
    final upcomingDays = [
      for (final d in [...s.days]..sort())
        if (d.compareTo(today) >= 0) d,
    ];
    final upcoming = {for (final d in upcomingDays) d: counts[d] ?? 0};
    final booked = upcoming.values.fold<int>(0, (a, b) => a + b);
    final packages = s.serviceIds.isEmpty
        ? l.spotSchedulePackagesAll
        : l.spotSchedulePackagesCount(s.serviceIds.length);
    final meta = theme.textTheme.bodySmall?.copyWith(
      color: muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    String dayLabel(String d) {
      final date = parseDayKey(d);
      return date == null ? d : formatDay(date);
    }

    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(url: spot?.cardUrl),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(scheduleDaysLabel(l, s.days), style: meta),
                      Text(
                        l.spotScheduleSummary(
                          l.spotScheduleDays(
                            s.days.length,
                            s.window.start,
                            s.window.end,
                          ),
                          packages,
                        ),
                        style: meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            if (booked > 0)
              Semantics(
                label: l.spotScheduleDayCountsLabel,
                container: true,
                child: Wrap(
                  spacing: AppSpace.s1,
                  runSpacing: AppSpace.s1,
                  children: [
                    for (final d in upcomingDays.take(_shownDays))
                      _DayPill(
                        key: Key('spot-day-count-$d'),
                        text: l.spotScheduleDayCount(dayLabel(d), upcoming[d]!),
                      ),
                    if (upcomingDays.length > _shownDays)
                      _DayPill(
                        text: l.spotScheduleMoreDays(
                          upcomingDays.length - _shownDays,
                        ),
                      ),
                  ],
                ),
              )
            else
              Text(
                offers.isEmpty
                    ? l.spotScheduleNoBookingsNoOffers
                    : l.spotScheduleNoBookings,
                style: meta,
              ),
            for (final o in offers)
              _OfferRow(
                key: Key('spot-offer-${o.id}'),
                offer: o,
                window: s.window,
                onTap: () => onOffer(o),
              ),
            if (booked > 0 && offers.isEmpty) ...[
              const SizedBox(height: AppSpace.s1),
              Text(l.spotScheduleNoOffers, style: meta),
            ],
            const SizedBox(height: AppSpace.s1),
            Wrap(
              children: [
                AppButton.text(
                  l.spotScheduleEdit,
                  key: Key('spot-schedule-edit-${s.id}'),
                  size: AppButtonSize.small,
                  style: TextButton.styleFrom(foregroundColor: muted),
                  onPressed: onEdit,
                ),
                AppButton.text(
                  l.spotScheduleOffersAction,
                  key: Key('spot-schedule-offer-${s.id}'),
                  size: AppButtonSize.small,
                  style: TextButton.styleFrom(foregroundColor: muted),
                  onPressed: () => onOffer(null),
                ),
                AppButton.text(
                  l.spotScheduleCancel,
                  key: Key('spot-schedule-cancel-${s.id}'),
                  size: AppButtonSize.small,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () => onCancel(name, upcoming),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: 48,
        height: 48,
        child: u == null || u.isEmpty
            ? ColoredBox(
                color: scheme.secondary,
                child: Center(
                  child: AppIcon(
                    AppIcons.landscape,
                    size: 22,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            : NetworkPhoto(url: u),
      ),
    );
  }
}

/// One "T7 10/10 · 2 booking" pill (mock `.dl span`).
class _DayPill extends StatelessWidget {
  const _DayPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A slot offer of the schedule: name, "490.000₫ · 7 suất/ngày"; taps edit.
class _OfferRow extends StatelessWidget {
  const _OfferRow({
    super.key,
    required this.offer,
    required this.window,
    required this.onTap,
  });

  final SlotOffer offer;
  final SpotWindow window;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final perDay = slotsFor(window, offer.slotMinutes, offer.gapMinutes).length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
        child: Row(
          children: [
            AppIcon(AppIcons.timer, size: 18, color: muted),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l.spotScheduleOfferMeta(formatMoney(offer.price), perDay),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(AppIcons.chevron, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      AppSkeleton.line(width: 120),
      const SizedBox(height: AppSpace.s3),
      for (var i = 0; i < 2; i++) ...[
        AppSkeleton.box(height: 168, radius: AppRadius.card),
        const SizedBox(height: AppSpace.s3),
      ],
    ],
  );
}
