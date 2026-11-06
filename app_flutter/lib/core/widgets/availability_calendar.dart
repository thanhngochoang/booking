import 'package:flutter/material.dart';

import 'package:photobooking/core/calendar_days.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_calendar.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// State of one day on a photographer's calendar. A day with no stored
/// record is [free]; `off` is set by the photographer, `pending` and `booked`
/// only by the server (bookings and events). `full` is a studio day whose
/// bookings already use every free member (server-written, #136 Decision 26):
/// drawn like `booked`, labelled "Hết chỗ", never selectable.
enum DayState { free, pending, booked, off, full }

extension DayStateLabel on DayState {
  String label(AppLocalizations l) => switch (this) {
    DayState.free => l.dayStateFree,
    DayState.pending => l.dayStatePending,
    DayState.booked => l.dayStateBooked,
    DayState.off => l.dayStateOff,
    DayState.full => l.calendarDayFull,
  };
}

/// A small line under a day number (S04.02 price of the day). [accent] draws
/// it in the accent colour (a special day's price).
typedef CalendarNote = ({String text, bool accent});

/// `mon` … `sun`, the keys of the weekday select messages in the ARB file.
String weekdayCode(int weekday) =>
    const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][weekday - 1];

bool _dark(ThemeData t) => t.brightness == Brightness.dark;

/// Mock `--ink-3`.
Color _tertiary(ThemeData t) =>
    _dark(t) ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted;

/// Mock `--ink-2`.
Color _secondary(ThemeData t) => _dark(t)
    ? AppColorsDark.foregroundSecondary
    : AppColors.foregroundSecondary;

/// Mock `--field`.
Color _field(ThemeData t) =>
    _dark(t) ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;

/// Mock `.cal` (S06.04): rounded cells; free plain, pending dashed accent
/// outline and accent text, booked struck through in tertiary, off on the
/// field fill, selected on the CTA gradient. The pending outline uses the
/// accent (`primary`) colour, the closest token to the mock's `--pending`.
///
/// Drawn by [AppCalendar], so every cell also shows the lunar day (spec §5.7,
/// R6); this widget only maps its day states, notes and selection onto
/// `dayStyle`, `dayBuilder`, `markers` and `dayOutline`.
///
/// Used read-only on S03.01, for picking a day on S04.02 (`editable: false`: only
/// free days answer), and for marking days off on S06.04 (`editable: true`:
/// every day in bounds answers and the screen decides). Times are not part
/// of the grid. All dates are calendar days (UTC midnight, see
/// `calendar_days.dart`).
class AvailabilityCalendar extends StatelessWidget {
  static Widget skeleton({Key? key, bool showHeader = true}) =>
      _AvailabilityCalendarSkeleton(key: key, showHeader: showHeader);

  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.states,
    this.selected,
    this.selectedDays = const {},
    this.onSelect,
    this.onLongPress,
    this.editable = false,
    this.onMonthChanged,
    this.minDate,
    this.maxDate,
    this.today,
    this.eventDays = const {},
    this.rangeStart,
    this.showHeader = true,
    this.notes = const {},
  });

  /// Any day of the month to show.
  final DateTime month;

  /// Non-free days; missing days are free.
  final Map<DateTime, DayState> states;
  final DateTime? selected;

  /// More selected days, drawn like [selected] (S29.04 "Chọn ngày" picks
  /// several); calendar days.
  final Set<DateTime> selectedDays;
  final ValueChanged<DateTime>? onSelect;

  /// Starts a range on S06.04 (the alternative to dragging: press and hold the
  /// first day, then tap the last).
  final ValueChanged<DateTime>? onLongPress;
  final bool editable;
  final ValueChanged<DateTime>? onMonthChanged;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? today;

  /// Days with an event of the photographer: a dot under the number.
  final Set<DateTime> eventDays;
  final DateTime? rangeStart;
  final bool showHeader;

  /// A small line under the number of a day of the shown month.
  final Map<DateTime, CalendarNote> notes;

  static const cellHeight = AppCalendar.cellHeight;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final range = rangeStart == null ? null : calendarDay(rangeStart!);
    final events = {for (final d in eventDays) calendarDay(d)};
    final picked = {for (final d in selectedDays) calendarDay(d)};
    final noteDays = {
      for (final e in notes.entries) calendarDay(e.key): e.value,
    };
    final stateOf = {
      for (final e in states.entries) calendarDay(e.key): e.value,
    };
    DayState stateAt(DateTime d) => stateOf[d] ?? DayState.free;
    // A day that answers no tap: not free in booking mode.
    bool locked(DateTime d) => !editable && stateAt(d) != DayState.free;

    return AppCalendar(
      month: month,
      onMonthChanged: onMonthChanged,
      selection: AppCalendarSelection.single,
      selected: selected,
      onDayTap: onSelect,
      onDayLongPress: onLongPress,
      disabledDay: locked,
      dayStyle: (d) {
        final state = stateAt(d);
        final said = [
          state.label(l).toLowerCase(),
          if (events.contains(d)) l.calendarHasEvent,
        ].join(', ');
        return AppCalendarDayStyle(
          fill: state == DayState.off ? _field(theme) : null,
          foreground: switch (state) {
            DayState.free => null,
            DayState.pending => theme.colorScheme.primary,
            DayState.off ||
            DayState.booked ||
            DayState.full => _tertiary(theme),
          },
          strike: state == DayState.booked || state == DayState.full,
          dashedOutline: state == DayState.pending
              ? theme.colorScheme.primary
              : null,
          selected: picked.contains(d),
          // A booked day is not "off": only days out of bounds are dimmed.
          dim: locked(d) ? false : null,
          spoken: said,
        );
      },
      dayBuilder: (context, d) {
        final note = noteDays[d];
        if (note == null) {
          return null;
        }
        final isSelected =
            picked.contains(d) ||
            (selected != null && calendarDay(selected!) == d);
        return Text(
          note.text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 8.5,
            height: 1.1,
            color: isSelected
                ? Colors.white
                : note.accent
                ? theme.colorScheme.primary
                : _secondary(theme),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
      markers: eventDays,
      dayOutline: (d) => d == range ? theme.colorScheme.primary : null,
      today: today,
      showHeader: showHeader,
      first: minDate,
      last: maxDate,
    );
  }
}

/// The four day states named in one wrapping row, each styled like its state
/// in the calendar (mock S06.04 legend).
class AvailabilityLegend extends StatelessWidget {
  const AvailabilityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: _dark(theme)
          ? AppColorsDark.foregroundSecondary
          : AppColors.foregroundSecondary,
    );
    return Wrap(
      spacing: AppSpace.s3,
      runSpacing: AppSpace.s1,
      children: [
        Text(DayState.free.label(l), style: base),
        Text(
          DayState.booked.label(l),
          style: base?.copyWith(decoration: TextDecoration.lineThrough),
        ),
        Text(
          DayState.pending.label(l),
          style: base?.copyWith(color: theme.colorScheme.primary),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _field(theme),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Text(DayState.off.label(l), style: base),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityCalendarSkeleton extends StatelessWidget {
  const _AvailabilityCalendarSkeleton({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    const gap = AvailabilityCalendar._gap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Center(
                    child: AppSkeleton.line(width: 120, height: 16),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        SizedBox(
          height: 14,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(child: AppSkeleton.line(width: 20, height: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s1),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var w = 0; w < 6; w++)
              Padding(
                padding: EdgeInsets.only(top: w == 0 ? 0 : gap),
                child: Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: c == 0 ? 0 : gap / 2,
                            right: c == 6 ? 0 : gap / 2,
                          ),
                          child: AppSkeleton.box(
                            height: AvailabilityCalendar.cellHeight,
                            radius: AppRadius.sm,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
