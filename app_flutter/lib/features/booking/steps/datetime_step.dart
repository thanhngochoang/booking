// lib/features/booking/steps/datetime_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class DateTimeStep extends ConsumerStatefulWidget {
  const DateTimeStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  ConsumerState<DateTimeStep> createState() => _DateTimeStepState();
}

/// The calendar of a spot booking: the schedule's [days] free (the step
/// greys out every other day).
Map<DateTime, AvailabilityDay> _spotMonth(List<String> days) {
  final map = <DateTime, AvailabilityDay>{};
  for (final key in days) {
    final d = parseDayKey(key);
    if (d != null) map[d] = AvailabilityDay(day: d, state: DayState.free);
  }
  return map;
}

/// "T7, CN": the weekdays of [days] (`yyyy-MM-dd`), Monday first.
String _weekdays(List<String> days, AppLocalizations l10n) {
  final weekdays = {
    for (final d in days)
      if (parseDayKey(d) case final date?) date.weekday,
  }.toList()..sort();
  return [
    for (final w in weekdays) l10n.calendarWeekdayShort(weekdayCode(w)),
  ].join(', ');
}

class _DateTimeStepState extends ConsumerState<DateTimeStep> {
  late DateTime _month;
  bool _tappedPending = false;

  /// A post-frame clear of a chosen day is scheduled (no-member studio).
  bool _clearScheduled = false;

  @override
  void initState() {
    super.initState();
    final initialDay = ref.read(bookingFlowControllerProvider(widget.args)).day;
    if (initialDay != null) {
      _month = monthOf(parseDayKey(initialDay)!);
    } else {
      _month = monthOf(ref.read(calendarTodayProvider));
    }
  }

  void _changeMonth(DateTime nextMonth) {
    setState(() {
      _month = nextMonth;
      _tappedPending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(calendarTodayProvider);
    final maxDate = addMonths(monthOf(today), 12);

    final state = ref.watch(bookingFlowControllerProvider(widget.args));
    final controller = ref.read(
      bookingFlowControllerProvider(widget.args).notifier,
    );

    // From a spot (#S04.02-spot) only the schedule's days can be chosen; the
    // photographer's own calendar marks those days `spot`, so it is not read.
    final spot = state.spot;
    final availabilityAsync = spot != null
        ? AsyncData(_spotMonth(spot.daysFrom(dayKeyOf(today))))
        : ref.watch(
            availabilityMonthProvider((
              uid: widget.args.photographerId,
              month: _month,
            )),
          );
    // A studio nobody can shoot for has no bookable day (#136 Decision 26).
    // The sheet loads the profile from its first frame; until it answers
    // (or if it fails) the days stay as the server keeps them, and the
    // server still refuses such a day with day_taken (crossed below). A spot
    // booking only offers the schedule's days, held by a named member (#194).
    final noMembers =
        spot == null &&
        (ref
                .watch(photographerProfileProvider(widget.args.photographerId))
                .value
                ?.summary
                .hasNoAssignableMembers ??
            false);

    // Every day is full: a day preset by the flow (or chosen before the
    // profile answered) cannot be booked, so it is cleared once the profile
    // says so. After the frame: a provider is not changed while building.
    final chosen = state.day;
    if (noMembers && chosen != null && !_clearScheduled) {
      _clearScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _clearScheduled = false;
        if (!mounted) return;
        if (ref.read(bookingFlowControllerProvider(widget.args)).day ==
            chosen) {
          controller.clearDay(chosen, taken: false);
        }
      });
    }

    // Live calendar updates: if the chosen day became non-free, unselect with SnackBar
    if (spot == null) {
      ref.listen<AsyncValue<Map<DateTime, AvailabilityDay>>>(
        availabilityMonthProvider((
          uid: widget.args.photographerId,
          month: _month,
        )),
        (prev, next) {
          if (next.hasValue) {
            final chosenDayStr = ref
                .read(bookingFlowControllerProvider(widget.args))
                .day;
            if (chosenDayStr != null) {
              final chosenDate = parseDayKey(chosenDayStr)!;
              final map = next.value!;
              final record = map[chosenDate];
              if (record != null && record.state != DayState.free) {
                controller.clearDay(chosenDayStr, taken: false);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.bookDayGone)));
              }
            }
          }
        },
      );
    }

    final canPrev = !addMonths(_month, -1).isBefore(monthOf(today));
    final canNext = !addMonths(_month, 1).isAfter(monthOf(maxDate));

    final selectedDate = state.day != null ? parseDayKey(state.day!) : null;
    final duration = state.durationMinutes ?? 0;
    final day = state.day;
    final providerName = spot == null
        ? null
        : ref
              .watch(photographerProfileProvider(widget.args.photographerId))
              .value
              ?.summary
              .displayName;
    // At a spot: the free starts of the chosen day, once its `spot_days` is read.
    final AsyncValue<List<String>> startsAsync;
    if (spot == null || day == null) {
      startsAsync = AsyncData(daySlots(duration));
    } else if (spot.failedDays.contains(day)) {
      startsAsync = AsyncError(StateError('spot_days $day'), StackTrace.empty);
    } else {
      final starts = state.availableStarts(ref.watch(clockProvider)());
      startsAsync = starts == null ? const AsyncLoading() : AsyncData(starts);
    }

    Widget times(List<String> slots) {
      if (slots.isEmpty) {
        return Text(
          l10n.bookNoSlots,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );
      }
      return Wrap(
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s2,
        children: [
          for (final slot in slots)
            AppChip(
              label: slot,
              selected: state.start == slot,
              onChanged: (_) => controller.selectStart(slot),
            ),
        ],
      );
    }

    return ScreenCode(
      ScreenCodes.bookDateTime,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spot != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s2,
                AppSpace.s4,
                0,
              ),
              child: Row(
                key: const Key('book-spot-line'),
                children: [
                  AppIcon(AppIcons.place, size: 20, color: scheme.primary),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spot.spotName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.bookSpotScheduleLine(
                            _weekdays(spot.daysFrom(dayKeyOf(today)), l10n),
                            spot.schedule.window.start,
                            spot.schedule.window.end,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s2,
            ),
            // Month and legend share one line (mock S04.02); on a narrow or
            // large-text screen the legend moves under the month instead of
            // being squeezed into a sliver of width.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.bookMonth(_month.month),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s1),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.calendarPrevMonth,
                      icon: const AppIcon(AppIcons.chevronLeft, size: 20),
                      onPressed: canPrev
                          ? () => _changeMonth(addMonths(_month, -1))
                          : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.calendarNextMonth,
                      icon: const AppIcon(AppIcons.chevron, size: 20),
                      onPressed: canNext
                          ? () => _changeMonth(addMonths(_month, 1))
                          : null,
                    ),
                  ],
                ),
                if (spot == null)
                  const AvailabilityLegend()
                else
                  Text(
                    l10n.bookSpotDaysOnly,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AsyncView<Map<DateTime, AvailabilityDay>>(
                    value: availabilityAsync,
                    skeleton: (_) =>
                        AvailabilityCalendar.skeleton(showHeader: false),
                    onRetry: () => ref.invalidate(
                      availabilityMonthProvider((
                        uid: widget.args.photographerId,
                        month: _month,
                      )),
                    ),
                    data: (context, knownDays) {
                      final dayStates = <DateTime, DayState>{
                        // At a spot every other day is greyed out.
                        if (spot != null)
                          for (final d in monthGrid(_month)) d: DayState.off,
                      };
                      for (final e in knownDays.entries) {
                        dayStates[e.key] = e.value.state;
                      }
                      for (final dayStr in state.takenDays) {
                        final d = parseDayKey(dayStr);
                        if (d != null) dayStates[d] = DayState.booked;
                      }
                      if (noMembers) {
                        // From today on: a past day stays a past day.
                        for (
                          var d = _month.isBefore(today) ? today : _month;
                          !d.isAfter(lastDayOfMonth(_month));
                          d = DateTime.utc(d.year, d.month, d.day + 1)
                        ) {
                          dayStates[d] = DayState.full;
                        }
                      }

                      return AvailabilityCalendar(
                        showHeader: false,
                        month: _month,
                        states: dayStates,
                        selected: selectedDate,
                        onSelect: (d) {
                          final s = dayStates[d] ?? DayState.free;
                          if (s == DayState.free) {
                            setState(() => _tappedPending = false);
                            controller.selectDay(dayKeyOf(d));
                          } else if (s == DayState.pending) {
                            setState(() => _tappedPending = true);
                          } else {
                            setState(() => _tappedPending = false);
                          }
                        },
                        onMonthChanged: _changeMonth,
                        minDate: today,
                        maxDate: maxDate,
                        today: today,
                        editable: true,
                      );
                    },
                  ),
                  if (_tappedPending)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s2,
                      ),
                      child: Text(
                        l10n.bookWaiting(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (selectedDate != null) ...[
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      l10n.bookDayLine(
                        '${l10n.calendarWeekdayLong(weekdayCode(selectedDate.weekday))}, ${formatDayMonth(selectedDate)}',
                        formatDuration(duration, l10n),
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    AsyncView<List<String>>(
                      value: startsAsync,
                      skeleton: (_) => Wrap(
                        spacing: AppSpace.s2,
                        runSpacing: AppSpace.s2,
                        children: [
                          for (var i = 0; i < 4; i++)
                            AppSkeleton.box(
                              width: AppSpace.s16,
                              height: AppSpace.s8,
                              radius: AppRadius.full,
                            ),
                        ],
                      ),
                      onRetry: day == null
                          ? null
                          : () => controller.refreshSpotDay(day),
                      data: (_, slots) => times(slots),
                    ),
                    if (state.start != null && state.end != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        spot != null && providerName != null
                            // Mock #S04.02-spot: whose window the times are in.
                            ? l10n.bookSpotEndsAt(
                                state.start!,
                                state.end!,
                                spot.schedule.window.start,
                                spot.schedule.window.end,
                                providerName,
                              )
                            : l10n.bookEndsAt(state.start!, state.end!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpace.s4),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l10n.bookContinuePrice(formatMoney(state.totalVnd ?? 0)),
              onPressed: state.canContinue ? controller.next : null,
            ),
          ),
        ],
      ),
    );
  }
}
