// lib/features/spots/slot_pick_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/discovery/book_entry.dart';

/// S29.06 "Chọn suất": picks a day of [schedule] and a free slot of [offer],
/// then opens the booking sheet directly on S04.03 (slot path, no add-ons).
Future<void> showSlotPickSheet(
  BuildContext context,
  WidgetRef ref, {
  required SlotOffer offer,
  required SpotSchedule schedule,
  required String spotName,
  String? day,
  String? providerName,
}) async {
  final picked = await showAppSheet<({String day, String start})>(
    context,
    builder: (_) => SlotPickSheet(
      offer: offer,
      schedule: schedule,
      spotName: spotName,
      day: day,
      providerName: providerName,
    ),
  );
  if (picked == null || !context.mounted) return;
  await startBooking(
    context,
    ref,
    photographerId: schedule.providerId,
    scheduleId: schedule.id,
    slotOfferId: offer.id,
    date: parseDayKey(picked.day),
    start: picked.start,
  );
}

/// The S29.06 sheet body; pops `(day, start)` on "Tiếp tục".
class SlotPickSheet extends ConsumerStatefulWidget {
  const SlotPickSheet({
    super.key,
    required this.offer,
    required this.schedule,
    required this.spotName,
    this.day,
    this.providerName,
  });

  final SlotOffer offer;
  final SpotSchedule schedule;
  final String spotName;

  /// The day viewed on S29.02; the first schedule day when it is not one.
  final String? day;
  final String? providerName;

  @override
  ConsumerState<SlotPickSheet> createState() => _SlotPickSheetState();
}

class _SlotPickSheetState extends ConsumerState<SlotPickSheet> {
  String? _day;

  /// The picked slot, with its day: a start picked on one day never carries
  /// over to another.
  ({String day, String start})? _picked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final offer = widget.offer;
    final schedule = widget.schedule;

    final now = ref.watch(clockProvider)();
    final today = vnDateKey(now);

    // A slot that has started is as good as taken.
    List<({String start, String end, bool free})> slotsOf(
      String day,
      SpotDay? spotDay,
    ) => [
      for (final s in freeSlots(schedule.window, offer, spotDay?.taken ?? []))
        (
          start: s.start,
          end: s.end,
          free:
              s.free &&
              BookingRules.parseBookingDateTime(day, s.start).isAfter(now),
        ),
    ];

    // Chips: the schedule's days from today that still have a free slot
    // (mock caption); a day shows until its read says it is full.
    final reads = {
      for (final d in [...schedule.days]..sort())
        if (d.compareTo(today) >= 0)
          d: ref.watch(spotDayProvider((scheduleId: schedule.id, day: d))),
    };
    final days = [
      for (final MapEntry(key: d, value: read) in reads.entries)
        if (!read.hasValue ||
            read.isLoading ||
            slotsOf(d, read.value).any((s) => s.free))
          d,
    ];
    final day = days.contains(_day)
        ? _day
        : (days.contains(widget.day) ? widget.day : days.firstOrNull);

    final dayKey = day == null ? null : (scheduleId: schedule.id, day: day);
    final spotDayAsync = day == null
        ? const AsyncData<SpotDay?>(null)
        : reads[day]!;

    final picked = _picked;
    final canContinue =
        day != null &&
        picked != null &&
        picked.day == day &&
        spotDayAsync.hasValue &&
        !spotDayAsync.isLoading &&
        slotsOf(
          day,
          spotDayAsync.value,
        ).any((s) => s.free && s.start == picked.start);

    final header = [
      offer.name,
      if (widget.providerName case final name? when name.isNotEmpty) name,
    ].join(' · ');

    return ScreenCode(
      ScreenCodes.spotSlotPick,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.s4, right: AppSpace.s2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    header,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.bookClose,
                  icon: const AppIcon(AppIcons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            child: Semantics(
              header: true,
              child: Text(
                l.slotPickTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s3,
                AppSpace.s4,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: l.slotPickDays,
                    container: true,
                    child: SingleChildScrollView(
                      key: const Key('slot-pick-days'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final d in days)
                            if (parseDayKey(d) case final date?)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpace.s2,
                                ),
                                child: AppChip(
                                  label: formatDay(date),
                                  selected: d == day,
                                  onChanged: (_) => setState(() {
                                    _day = d;
                                    _picked = null;
                                  }),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  if (days.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s2),
                      child: Text(
                        l.spotSlotsFull,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpace.s3),
                  if (dayKey != null)
                    AsyncView<SpotDay?>(
                      value: spotDayAsync,
                      skeleton: (_) => Wrap(
                        spacing: AppSpace.s2,
                        runSpacing: AppSpace.s2,
                        children: [
                          for (var i = 0; i < 8; i++)
                            AppSkeleton.box(
                              width: AppSpace.s16,
                              height: AppSpace.s12,
                              radius: AppRadius.control,
                            ),
                        ],
                      ),
                      onRetry: () => ref.invalidate(spotDayProvider(dayKey)),
                      data: (context, spotDay) {
                        final slots = slotsOf(dayKey.day, spotDay);
                        final date = parseDayKey(dayKey.day)!;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.slotPickDayLine(
                                '${l.calendarWeekdayLong(weekdayCode(date.weekday))}, ${formatDayMonth(date)}',
                                slots.where((s) => s.free).length,
                                slots.length,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpace.s2),
                            SlotGrid(
                              slots: slots,
                              selected: picked?.day == dayKey.day
                                  ? picked?.start
                                  : null,
                              semanticsLabel: l.slotPickTimes,
                              onPick: (start) => setState(
                                () => _picked = (day: dayKey.day, start: start),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: AppSpace.s3),
                  Text(
                    l.slotPickOfferMeta(
                      widget.spotName,
                      offer.editedCount,
                      offer.deliveryDays,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l.slotContinue(formatMoney(offer.price)),
              onPressed: canContinue
                  ? () => Navigator.of(context).pop(picked)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
