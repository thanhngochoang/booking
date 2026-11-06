import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:photobooking/core/calendar_days.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/lunar.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// What a tap on a day of an [AppCalendar] selects.
///
/// `none`: nothing is drawn as selected; the screen reacts to `onDayTap`
/// (S08.10 opens a day sheet). `single`: the screen passes `selected`.
/// `range`: the screen passes `range`; a range comes from two taps or from a
/// long press followed by a drag.
enum AppCalendarSelection { none, single, range }

const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

bool _isDark(ThemeData t) => t.brightness == Brightness.dark;

/// Mock `--ink-3`.
Color _tertiary(ThemeData t) =>
    _isDark(t) ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted;

/// How one day of an [AppCalendar] differs from a plain day, for screens that
/// show a state per day (`AvailabilityCalendar`: free, pending, booked, off).
/// Every field is optional; a null style is a plain day.
@immutable
class AppCalendarDayStyle {
  const AppCalendarDayStyle({
    this.fill,
    this.foreground,
    this.strike = false,
    this.dashedOutline,
    this.selected = false,
    this.dim,
    this.spoken,
  });

  /// Background of the cell (not drawn on a selected day).
  final Color? fill;

  /// Colour of the solar number (not used on a selected day, which is white).
  /// The lunar number keeps its own colour: only "1/M" is accent.
  final Color? foreground;

  /// Strikes the solar number through.
  final bool strike;

  /// A 1 px dashed outline in this colour (not drawn on a selected day).
  final Color? dashedOutline;

  /// Draws the day like the `selected` day, for screens that mark several
  /// days (the calendar's own `selected` stays a single day).
  final bool selected;

  /// Whether a disabled day is dimmed: null dims it (the default), false keeps
  /// it at full strength (a booked day cannot be picked but is not "off").
  final bool? dim;

  /// Words read by screen readers after the date ("đã đặt").
  final String? spoken;
}

/// Mock `.cal` grid with the lunar day on every cell (spec §5.7, R6).
///
/// Seven columns, Monday first, cells at least 44 dp. Each cell shows the
/// solar number with the lunar number small on the same row, right next to
/// its foot; the first of a lunar month reads "1/M" in the accent colour.
/// [dayBuilder] adds a line under the numbers (a price, a busy dot, "Lễ").
/// The lunar day is always shown: there is no flag to turn it off.
///
/// Days are calendar days: UTC midnight (see `calendar_days.dart`); time of
/// day is ignored. The widget is controlled: the screen owns `month`,
/// `selected` and `range` and answers the callbacks.
///
/// [dayBuilder] must return a widget of intrinsic size (a `Text`, a dot): the
/// cell scales its content down rather than overflowing at large text sizes.
class AppCalendar extends StatefulWidget {
  const AppCalendar({
    super.key,
    required this.month,
    this.onMonthChanged,
    this.selection = AppCalendarSelection.none,
    this.selected,
    this.range,
    this.onDayTap,
    this.onDayLongPress,
    this.onRangeChanged,
    this.onRangeCompleted,
    this.disabledDay,
    this.dayBuilder,
    this.dayStyle,
    this.markers = const {},
    this.dayOutline,
    this.emphasized,
    this.today,
    this.showHeader = true,
    this.first,
    this.last,
  });

  /// Any day of the month to show.
  final DateTime month;

  /// The header's ‹ › and a horizontal swipe ask for another month (always
  /// the 1st). Without it the month cannot be changed.
  final ValueChanged<DateTime>? onMonthChanged;
  final AppCalendarSelection selection;

  /// The chosen day when [selection] is `single`.
  final DateTime? selected;

  /// The chosen days when [selection] is `range`, both ends included.
  final DateTimeRange? range;

  /// A tap on a day of the shown month that is not disabled, in every
  /// [selection] mode.
  final ValueChanged<DateTime>? onDayTap;

  /// A long press on a day of the shown month that is not disabled. Ignored
  /// in `range` mode, where a long press starts a drag.
  final ValueChanged<DateTime>? onDayLongPress;

  /// With `range` selection, live feedback: the first tap gives a one-day
  /// range (the day the range starts on), the second tap gives the whole
  /// range, a tap before the start starts over, and a long press then a drag
  /// reports the range on every cell the finger enters. The caller stores
  /// the value and passes it back as [range]. A one-day range from here may
  /// be only a start still waiting for its end: use [onRangeCompleted] to
  /// know that a range is final.
  final ValueChanged<DateTimeRange>? onRangeChanged;

  /// With `range` selection: the range is final. Fired on the second tap
  /// (tapping the same day twice gives a one-day range) and when a
  /// long-press drag is released. It follows the last [onRangeChanged] of
  /// that gesture with the same value, so a caller that only needs finished
  /// ranges can ignore [onRangeChanged].
  ///
  /// A range never contains a disabled day: when the second tap or the drag
  /// lies beyond one, the range ends at the day before the first disabled
  /// day after the start (toward the start when going backwards).
  final ValueChanged<DateTimeRange>? onRangeCompleted;

  /// Days that answer no tap, drawn dimmed. Days outside [first]/[last] are
  /// disabled too.
  final bool Function(DateTime day)? disabledDay;

  /// A widget under the numbers of a day of the shown month. Its text is
  /// read by screen readers after the date.
  final Widget? Function(BuildContext context, DateTime day)? dayBuilder;

  /// A per-day look (state colours, strike-through, dashed outline, extra
  /// selected days), or null for a plain day.
  final AppCalendarDayStyle? Function(DateTime day)? dayStyle;

  /// Days with a small dot at the foot of the cell.
  final Set<DateTime> markers;

  /// A colour for an outline round the cell (S08.10: a day with an
  /// exception), or null for none.
  final Color? Function(DateTime day)? dayOutline;

  /// Days whose solar number is drawn bold.
  final bool Function(DateTime day)? emphasized;

  /// Today, given by the screen (the app clock); drawn with a thin border.
  final DateTime? today;
  final bool showHeader;

  /// The earliest and latest day that can be picked; month buttons stop at
  /// their months.
  final DateTime? first;
  final DateTime? last;

  static const cellHeight = 44.0;
  static const _gap = 3.0;

  @override
  State<AppCalendar> createState() => _AppCalendarState();
}

class _AppCalendarState extends State<AppCalendar> {
  final _gridKey = GlobalKey();

  /// Lunar dates of the shown month, converted once per month.
  late Map<DateTime, LunarDate> _lunar = _lunarOf(widget.month);

  /// First tap of a range that waits for its end.
  DateTime? _pending;

  /// The range while a long-press drag is in progress.
  DateTime? _dragAnchor;
  DateTimeRange? _drag;

  static Map<DateTime, LunarDate> _lunarOf(DateTime month) {
    final m = monthOf(month);
    return {
      for (var d = 1; d <= lastDayOfMonth(m).day; d++)
        DateTime.utc(m.year, m.month, d): solarToLunar(
          DateTime.utc(m.year, m.month, d),
        ),
    };
  }

  @override
  void didUpdateWidget(AppCalendar old) {
    super.didUpdateWidget(old);
    if (monthOf(old.month) != monthOf(widget.month)) {
      _lunar = _lunarOf(widget.month);
    }
    // A rebuild with the same range keeps the pending start; a real change of
    // selection mode or range (other than the one-day range the first tap
    // itself produced) drops it.
    final p = _pending;
    if (p != null) {
      final r = widget.range;
      final isStart =
          r != null && calendarDay(r.start) == p && calendarDay(r.end) == p;
      if (widget.selection != AppCalendarSelection.range ||
          (!_sameRange(old.range, r) && !isStart)) {
        _pending = null;
      }
    }
  }

  static bool _sameRange(DateTimeRange? a, DateTimeRange? b) =>
      a == null || b == null
      ? a == b
      : calendarDay(a.start) == calendarDay(b.start) &&
            calendarDay(a.end) == calendarDay(b.end);

  bool _disabled(DateTime d) =>
      !_inBounds(d) || (widget.disabledDay?.call(d) ?? false);

  /// [to] moved toward [from] until no disabled day lies between them.
  /// [from] itself is a day the user could pick.
  DateTime _clip(DateTime from, DateTime to) {
    final step = to.isBefore(from) ? -1 : 1;
    var at = from;
    while (at != to) {
      final next = DateTime.utc(at.year, at.month, at.day + step);
      if (_disabled(next)) {
        break;
      }
      at = next;
    }
    return at;
  }

  static DateTimeRange _ordered(DateTime a, DateTime b) => b.isBefore(a)
      ? DateTimeRange(start: b, end: a)
      : DateTimeRange(start: a, end: b);

  bool _inBounds(DateTime d) =>
      (widget.first == null || !d.isBefore(calendarDay(widget.first!))) &&
      (widget.last == null || !d.isAfter(calendarDay(widget.last!)));

  bool _canPick(DateTime d, DateTime m) =>
      d.year == m.year &&
      d.month == m.month &&
      _inBounds(d) &&
      !(widget.disabledDay?.call(d) ?? false);

  bool _canPrev(DateTime m) =>
      widget.first == null ||
      !addMonths(m, -1).isBefore(monthOf(widget.first!));

  bool _canNext(DateTime m) =>
      widget.last == null || !addMonths(m, 1).isAfter(monthOf(widget.last!));

  bool get _rangeMode =>
      widget.selection == AppCalendarSelection.range &&
      (widget.onRangeChanged != null || widget.onRangeCompleted != null);

  void _tap(DateTime d) {
    widget.onDayTap?.call(d);
    if (!_rangeMode) {
      return;
    }
    final start = _pending;
    if (start == null || d.isBefore(start)) {
      _pending = d;
      widget.onRangeChanged?.call(DateTimeRange(start: d, end: d));
    } else {
      _pending = null;
      final r = DateTimeRange(start: start, end: _clip(start, d));
      widget.onRangeChanged?.call(r);
      widget.onRangeCompleted?.call(r);
    }
  }

  /// The pickable day under [local] (a point of the grid), or null.
  DateTime? _dayAt(Offset local) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return null;
    }
    final m = monthOf(widget.month);
    final days = monthGrid(m);
    final col = (local.dx / (box.size.width / 7)).floor().clamp(0, 6);
    final row = (local.dy / (AppCalendar.cellHeight + AppCalendar._gap))
        .floor()
        .clamp(0, 5);
    final d = days[row * 7 + col];
    return _canPick(d, m) ? d : null;
  }

  void _dragTo(DateTime d) {
    final a = _dragAnchor!;
    final r = _ordered(a, _clip(a, d));
    if (_drag == r) {
      return;
    }
    setState(() => _drag = r);
    widget.onRangeChanged?.call(r);
  }

  void _dragStart(LongPressStartDetails e) {
    final d = _dayAt(e.localPosition);
    if (d == null) {
      return;
    }
    _pending = null;
    _dragAnchor = d;
    _drag = null;
    _dragTo(d);
  }

  void _dragMove(LongPressMoveUpdateDetails e) {
    if (_dragAnchor == null) {
      return;
    }
    final d = _dayAt(e.localPosition);
    if (d != null) {
      _dragTo(d);
    }
  }

  void _dragEnd({required bool completed}) {
    if (_dragAnchor == null) {
      return;
    }
    final r = _drag;
    if (completed && r != null) {
      widget.onRangeCompleted?.call(r);
    }
    setState(() {
      _dragAnchor = null;
      _drag = null;
    });
  }

  bool _isSelected(DateTime d) {
    switch (widget.selection) {
      case AppCalendarSelection.none:
        return false;
      case AppCalendarSelection.single:
        return widget.selected != null && calendarDay(widget.selected!) == d;
      case AppCalendarSelection.range:
        final r =
            _drag ??
            (widget.range == null
                ? null
                : DateTimeRange(
                    start: calendarDay(widget.range!.start),
                    end: calendarDay(widget.range!.end),
                  ));
        return r != null && !d.isBefore(r.start) && !d.isAfter(r.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final m = monthOf(widget.month);
    final days = monthGrid(m);
    final now = widget.today == null ? null : calendarDay(widget.today!);
    final change = widget.onMonthChanged;
    final markers = {for (final d in widget.markers) calendarDay(d)};
    final tappable = widget.onDayTap != null || _rangeMode;

    final weekdays = Row(
      children: [
        for (final key in _weekdayKeys)
          Expanded(
            child: Center(
              child: Text(
                l.calendarWeekdayShort(key),
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
      key: _gridKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < 6; w++)
          Padding(
            padding: EdgeInsets.only(top: w == 0 ? 0 : AppCalendar._gap),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: c == 0 ? 0 : AppCalendar._gap / 2,
                        right: c == 6 ? 0 : AppCalendar._gap / 2,
                      ),
                      child: _buildCell(
                        context,
                        days[w * 7 + c],
                        m,
                        now,
                        markers,
                        tappable,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    grid = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: _rangeMode ? _dragStart : null,
      onLongPressMoveUpdate: _rangeMode ? _dragMove : null,
      onLongPressEnd: _rangeMode ? (_) => _dragEnd(completed: true) : null,
      onLongPressCancel: _rangeMode ? () => _dragEnd(completed: false) : null,
      onHorizontalDragEnd: change == null
          ? null
          : (e) {
              final v = e.primaryVelocity ?? 0;
              if (v < -150 && _canNext(m)) {
                change(addMonths(m, 1));
              } else if (v > 150 && _canPrev(m)) {
                change(addMonths(m, -1));
              }
            },
      child: grid,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Row(
            children: [
              IconButton(
                tooltip: l.calendarPrevMonth,
                icon: const AppIcon(AppIcons.chevronLeft),
                onPressed: change != null && _canPrev(m)
                    ? () => change(addMonths(m, -1))
                    : null,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.appCalendar_monthTitle('${m.month}', '${m.year}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.display,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.calendarNextMonth,
                icon: const AppIcon(AppIcons.chevron),
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

  Widget _buildCell(
    BuildContext context,
    DateTime day,
    DateTime month,
    DateTime? now,
    Set<DateTime> markers,
    bool tappable,
  ) {
    final key = vnDateKey(day);
    if (day.month != month.month) {
      return ExcludeSemantics(
        child: Opacity(
          opacity: 0.3,
          child: SizedBox(
            key: ValueKey('app-calendar-day-$key'),
            height: AppCalendar.cellHeight,
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: AppText.base,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final enabled = _canPick(day, month);
    final extra = widget.dayBuilder?.call(context, day);
    final style = widget.dayStyle?.call(day);
    return _DayCell(
      key: ValueKey('app-calendar-day-$key'),
      dayKey: key,
      day: day,
      lunar: _lunar[day]!,
      enabled: enabled,
      selected: _isSelected(day) || (style?.selected ?? false),
      style: style,
      today: day == now,
      emphasized: widget.emphasized?.call(day) ?? false,
      marker: markers.contains(day),
      outline: widget.dayOutline?.call(day),
      extra: extra,
      onTap: enabled && tappable ? () => _tap(day) : null,
      onLongPress: enabled && !_rangeMode && widget.onDayLongPress != null
          ? () => widget.onDayLongPress!(day)
          : null,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.dayKey,
    required this.day,
    required this.lunar,
    required this.enabled,
    required this.selected,
    required this.today,
    required this.emphasized,
    required this.marker,
    required this.outline,
    required this.extra,
    required this.style,
    required this.onTap,
    required this.onLongPress,
  });

  final String dayKey;
  final DateTime day;
  final LunarDate lunar;
  final bool enabled;
  final bool selected;
  final bool today;
  final bool emphasized;
  final bool marker;
  final Color? outline;
  final Widget? extra;
  final AppCalendarDayStyle? style;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String _spoken(AppLocalizations l) {
    final lunarDay = lunar.day <= 10
        ? l.appCalendar_lunarEarly('${lunar.day}')
        : '${lunar.day}';
    final lunarMonth = lunar.leap
        ? l.appCalendar_lunarLeapMonth('${lunar.month}')
        : '${lunar.month}';
    return [
      l.appCalendar_dayLabel(
        _weekdayKeys[day.weekday - 1],
        '${day.day}',
        '${day.month}',
      ),
      l.appCalendar_lunarDay(lunarDay, lunarMonth),
      ?style?.spoken,
      if (today) l.calendarToday,
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tertiary = _tertiary(theme);
    // Mock: border-radius 10px; AppRadius.lg (12) is the closest token.
    final radius = BorderRadius.circular(AppRadius.lg);
    final fg = selected
        ? Colors.white
        : (style?.foreground ?? scheme.onSurface);
    final firstOfMonth = lunar.day == 1;
    final lunarColor = selected
        ? (firstOfMonth ? Colors.white : Colors.white.withValues(alpha: 0.8))
        : (firstOfMonth ? scheme.primary : tertiary);
    final bold = today || selected || emphasized;

    final numbers = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '${day.day}',
            key: ValueKey('app-calendar-solar-$dayKey'),
            style: TextStyle(
              fontSize: AppText.base,
              height: 1.1,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: fg,
              decoration: style?.strike ?? false
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 1),
          // Mock `small` 6.5px, rounded up to stay legible.
          Text(
            firstOfMonth ? '1/${lunar.month}' : '${lunar.day}',
            key: ValueKey('app-calendar-lunar-$dayKey'),
            style: TextStyle(
              fontSize: 7,
              height: 1.1,
              fontWeight: firstOfMonth ? FontWeight.w600 : FontWeight.w400,
              color: lunarColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    final dashed = selected ? null : style?.dashedOutline;
    Widget face = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? null : style?.fill,
        gradient: selected ? ctaGradientFor(theme.brightness) : null,
        borderRadius: radius,
        border: outline != null
            ? Border.all(color: outline!, width: 2)
            : today && !selected
            ? Border.all(color: tertiary)
            : null,
      ),
      // Scaled down rather than overflowing at a large text size.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 8.5,
            height: 1.1,
            color: selected ? Colors.white : scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              numbers,
              if (extra != null)
                Padding(padding: const EdgeInsets.only(top: 1), child: extra),
            ],
          ),
        ),
      ),
    );

    if (dashed != null) {
      face = CustomPaint(
        foregroundPainter: _DashedOutline(dashed, radius),
        child: face,
      );
    }

    Widget cell = SizedBox(
      height: AppCalendar.cellHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: face),
          if (marker)
            Positioned(
              bottom: 2,
              child: ExcludeSemantics(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!enabled && (style?.dim ?? true)) {
      cell = Opacity(opacity: 0.45, child: cell);
    }
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        enabled: enabled,
        selected: selected,
        label: _spoken(l),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          child: cell,
        ),
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

/// Bottom sheet with an [AppCalendar] and the primary "Chọn" button; returns
/// the chosen day, or null when dismissed. [initial] is shown selected and
/// its month opens first. [today] marks today when the caller has a clock.
/// [disabledDay] dims days inside first..last that cannot be picked.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? title,
  DateTime? today,
  bool Function(DateTime day)? disabledDay,
}) => showAppSheet<DateTime>(
  context,
  builder: (_) => _PickerSheet(
    title: title,
    first: first,
    last: last,
    today: today,
    initial: initial,
    range: null,
    rangeMode: false,
    disabledDay: disabledDay,
  ),
);

/// Like [showAppDatePicker] for a range: tap two days, or press and hold and
/// drag. "Chọn" is off until a range is complete (a first tap alone is not).
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
  required DateTime first,
  required DateTime last,
  String? title,
  DateTime? today,
}) => showAppSheet<DateTimeRange>(
  context,
  builder: (_) => _PickerSheet(
    title: title,
    first: first,
    last: last,
    today: today,
    initial: initial?.start,
    range: initial,
    rangeMode: true,
  ),
);

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.first,
    required this.last,
    required this.today,
    required this.initial,
    required this.range,
    required this.rangeMode,
    this.disabledDay,
  });

  final String? title;
  final DateTime first;
  final DateTime last;
  final DateTime? today;
  final DateTime? initial;
  final DateTimeRange? range;
  final bool rangeMode;
  final bool Function(DateTime day)? disabledDay;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late DateTime _month = _openMonth();
  late DateTime? _selected = widget.initial == null
      ? null
      : calendarDay(widget.initial!);
  late DateTimeRange? _range = widget.range;

  /// The range is final (not just a first tap waiting for its end).
  late bool _rangeDone = widget.range != null;

  DateTime _openMonth() {
    final at = widget.initial ?? widget.today ?? widget.first;
    final day = calendarDay(at);
    final lo = calendarDay(widget.first);
    final hi = calendarDay(widget.last);
    return monthOf(day.isBefore(lo) ? lo : (day.isAfter(hi) ? hi : day));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final canChoose = widget.rangeMode
        ? _range != null && _rangeDone
        : _selected != null;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            AppCalendar(
              month: _month,
              onMonthChanged: (m) => setState(() => _month = m),
              selection: widget.rangeMode
                  ? AppCalendarSelection.range
                  : AppCalendarSelection.single,
              selected: _selected,
              range: _range,
              onDayTap: widget.rangeMode
                  ? null
                  : (d) => setState(() => _selected = d),
              onRangeChanged: widget.rangeMode
                  ? (r) => setState(() {
                      _range = r;
                      _rangeDone = false;
                    })
                  : null,
              onRangeCompleted: widget.rangeMode
                  ? (r) => setState(() {
                      _range = r;
                      _rangeDone = true;
                    })
                  : null,
              today: widget.today,
              first: widget.first,
              last: widget.last,
              disabledDay: widget.disabledDay,
            ),
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              l.appCalendar_choose,
              onPressed: canChoose
                  ? () =>
                        Navigator.of(context)
                            .pop(widget.rangeMode ? _range : _selected)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
