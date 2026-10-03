// lib/features/booking/steps/datetime_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';

class DateTimeStep extends ConsumerStatefulWidget {
  const DateTimeStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  ConsumerState<DateTimeStep> createState() => _DateTimeStepState();
}

class _DateTimeStepState extends ConsumerState<DateTimeStep> {
  late DateTime _month;
  bool _tappedPending = false;

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

    final availabilityAsync = ref.watch(
      availabilityMonthProvider((
        uid: widget.args.photographerId,
        month: _month,
      )),
    );

    // Live calendar updates: if the chosen day became non-free, unselect with SnackBar
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

    final canPrev = !addMonths(_month, -1).isBefore(monthOf(today));
    final canNext = !addMonths(_month, 1).isAfter(monthOf(maxDate));

    final selectedDate = state.day != null ? parseDayKey(state.day!) : null;
    final duration = state.durationMinutes ?? 0;
    final slots = daySlots(duration);

    return ScreenCode(
      ScreenCodes.bookDateTime,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: canPrev
                          ? () => _changeMonth(addMonths(_month, -1))
                          : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.calendarNextMonth,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: canNext
                          ? () => _changeMonth(addMonths(_month, 1))
                          : null,
                    ),
                  ],
                ),
                const AvailabilityLegend(),
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
                      final dayStates = <DateTime, DayState>{};
                      for (final e in knownDays.entries) {
                        dayStates[e.key] = e.value.state;
                      }
                      for (final dayStr in state.takenDays) {
                        final d = parseDayKey(dayStr);
                        if (d != null) dayStates[d] = DayState.booked;
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
                    if (slots.isEmpty)
                      Text(
                        l10n.bookNoSlots,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
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
                      ),
                    if (state.start != null && state.end != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l10n.bookEndsAt(state.start!, state.end!),
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
              l10n.bookContinuePrice(formatMoney(state.priceVnd ?? 0)),
              onPressed: state.canContinue ? controller.next : null,
            ),
          ),
        ],
      ),
    );
  }
}
