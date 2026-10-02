import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:photobooking/core/calendar_days.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// State of one day on a photographer's calendar. A day with no stored
/// record is [free]; `off` is set by the photographer, `pending` and `booked`
/// only by the server (bookings and events).
enum DayState { free, pending, booked, off }

extension DayStateLabel on DayState {
  String label(AppLocalizations l) => switch (this) {
    DayState.free => l.dayStateFree,
    DayState.pending => l.dayStatePending,
    DayState.booked => l.dayStateBooked,
    DayState.off => l.dayStateOff,
  };
}

/// `mon` … `sun`, the keys of the weekday select messages in the ARB file.
String weekdayCode(int weekday) =>
    const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][weekday - 1];

bool _dark(ThemeData t) => t.brightness == Brightness.dark;

/// Mock `--ink-3`.
Color _tertiary(ThemeData t) =>
    _dark(t) ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted;

/// Mock `--field`.
Color _field(ThemeData t) =>
    _dark(t) ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;

/// Mock `.cal` (S20): rounded cells; free plain, pending dashed accent
/// outline and accent text, booked struck through in tertiary, off on the
/// field fill, selected on the CTA gradient. The pending outline uses the
/// accent (`primary`) colour, the closest token to the mock's `--pending`.
///
/// Used read-only on S03, for picking a day on S06 (`editable: false`: only
/// free days answer), and for marking days off on S20 (`editable: true`:
/// every day in bounds answers and the screen decides). Times are not part
/// of the grid. All dates are calendar days (UTC midnight, see
/// `calendar_days.dart`).
class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.states,
    this.selected,
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
  });

  /// Any day of the month to show.
  final DateTime month;

  /// Non-free days; missing days are free.
  final Map<DateTime, DayState> states;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;

  /// Starts a range on S20 (the alternative to dragging: press and hold the
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

  static const cellHeight = 44.0;
  static const _gap = 3.0;

  bool _inBounds(DateTime d) =>
      (minDate == null || !d.isBefore(calendarDay(minDate!))) &&
      (maxDate == null || !d.isAfter(calendarDay(maxDate!)));

  bool _canPrev(DateTime m) =>
      minDate == null || !addMonths(m, -1).isBefore(monthOf(minDate!));

  bool _canNext(DateTime m) =>
      maxDate == null || !addMonths(m, 1).isAfter(monthOf(maxDate!));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final m = monthOf(month);
    final days = monthGrid(m);
    final sel = selected == null ? null : calendarDay(selected!);
    final now = today == null ? null : calendarDay(today!);
    final range = rangeStart == null ? null : calendarDay(rangeStart!);

    VoidCallback? answer(ValueChanged<DateTime>? cb, DateTime d, DayState s) {
      if (cb == null || d.month != m.month || !_inBounds(d)) {
        return null;
      }
      if (!editable && s != DayState.free) {
        return null;
      }
      return () => cb(d);
    }

    final weekdays = Row(
      children: [
        for (var i = DateTime.monday; i <= DateTime.sunday; i++)
          Expanded(
            child: Center(
              child: Text(
                l.calendarWeekdayShort(weekdayCode(i)),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppText.xs,
                  color: _tertiary(theme),
                ),
              ),
            ),
          ),
      ],
    );

    Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < 6; w++)
          Padding(
            padding: EdgeInsets.only(top: w == 0 ? 0 : _gap),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: c == 0 ? 0 : _gap / 2,
                        right: c == 6 ? 0 : _gap / 2,
                      ),
                      child: _DayCell(
                        day: days[w * 7 + c],
                        state: states[days[w * 7 + c]] ?? DayState.free,
                        inMonth: days[w * 7 + c].month == m.month,
                        inBounds: _inBounds(days[w * 7 + c]),
                        selected: days[w * 7 + c] == sel,
                        today: days[w * 7 + c] == now,
                        hasEvent: eventDays.contains(days[w * 7 + c]),
                        rangeStart: days[w * 7 + c] == range,
                        onTap: answer(
                          onSelect,
                          days[w * 7 + c],
                          states[days[w * 7 + c]] ?? DayState.free,
                        ),
                        onLongPress: answer(
                          onLongPress,
                          days[w * 7 + c],
                          states[days[w * 7 + c]] ?? DayState.free,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    final change = onMonthChanged;
    if (change != null) {
      grid = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (e) {
          final v = e.primaryVelocity ?? 0;
          if (v < -150 && _canNext(m)) {
            change(addMonths(m, 1));
          } else if (v > 150 && _canPrev(m)) {
            change(addMonths(m, -1));
          }
        },
        child: grid,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Row(
            children: [
              IconButton(
                tooltip: l.calendarPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: change != null && _canPrev(m)
                    ? () => change(addMonths(m, -1))
                    : null,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.calendarMonthTitle('${m.month}', '${m.year}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.display,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.calendarNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: change != null && _canNext(m)
                    ? () => change(addMonths(m, 1))
                    : null,
              ),
            ],
          ),
        weekdays,
        const SizedBox(height: AppSpace.s1),
        grid,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.state,
    required this.inMonth,
    required this.inBounds,
    required this.selected,
    required this.today,
    required this.hasEvent,
    required this.rangeStart,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime day;
  final DayState state;
  final bool inMonth;
  final bool inBounds;
  final bool selected;
  final bool today;
  final bool hasEvent;
  final bool rangeStart;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tertiary = _tertiary(theme);
    // Mock: border-radius 10px; AppRadius.lg (12) is the closest token.
    final radius = BorderRadius.circular(AppRadius.lg);
    var fg = scheme.onSurface;
    Color? fillColor;
    Gradient? gradient;
    TextDecoration? line;
    switch (state) {
      case DayState.free:
        break;
      case DayState.pending:
        fg = scheme.primary;
      case DayState.off:
        fillColor = _field(theme);
        fg = tertiary;
      case DayState.booked:
        line = TextDecoration.lineThrough;
        fg = tertiary;
    }
    if (selected) {
      fillColor = null;
      gradient = ctaGradientFor(theme.brightness);
      fg = Colors.white;
    }
    final bold = today || selected;
    Widget face = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fillColor,
        gradient: gradient,
        borderRadius: radius,
        border: rangeStart
            ? Border.all(color: scheme.primary, width: 2)
            : today && !selected
            ? Border.all(color: tertiary)
            : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: AppText.base,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: fg,
          decoration: line,
          decorationColor: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (state == DayState.pending && !selected) {
      face = CustomPaint(
        foregroundPainter: _DashedOutline(scheme.primary, radius),
        child: face,
      );
    }
    Widget cell = SizedBox(
      height: AvailabilityCalendar.cellHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: face),
          if (hasEvent)
            Positioned(
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
    if (!inMonth) {
      return ExcludeSemantics(child: Opacity(opacity: 0.3, child: cell));
    }
    if (!inBounds) {
      cell = Opacity(opacity: 0.45, child: cell);
    }
    final said = [
      state.label(l).toLowerCase(),
      if (hasEvent) l.calendarHasEvent,
      if (today) l.calendarToday,
    ].join(', ');
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: selected,
      label: l.calendarDaySemantics('${day.day}', '${day.month}', said),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: cell,
      ),
    );
  }
}

/// 1px dashed outline drawn inside the rounded rect (mock `outline-offset:-1px`).
class _DashedOutline extends CustomPainter {
  const _DashedOutline(this.color, this.radius);
  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(radius.toRRect((Offset.zero & size).deflate(0.5)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final PathMetric metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + 3), paint);
        at += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.radius != radius;
}

/// The four day states named in one wrapping row, each styled like its state
/// in the calendar (mock S20 legend).
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
