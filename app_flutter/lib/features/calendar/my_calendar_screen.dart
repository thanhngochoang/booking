import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/calendar/my_calendar_controller.dart';

/// S20 "Lịch của tôi": the photographer marks days off; booked and pending
/// days come from bookings and events and are read-only here.
///
/// Layout follows mock S20: three month tabs, the calendar without its own
/// month header (tabs and swipe change the month), the legend, the selected
/// day's section with an accent text action, and the hint at the bottom.
class MyCalendarScreen extends ConsumerStatefulWidget {
  const MyCalendarScreen({super.key});

  @override
  ConsumerState<MyCalendarScreen> createState() => _MyCalendarScreenState();
}

class _MyCalendarScreenState extends ConsumerState<MyCalendarScreen> {
  late final DateTime _today = ref.read(calendarTodayProvider);
  late final DateTime _first = monthOf(_today);
  late final DateTime _last = addMonths(_first, 12);
  late DateTime _month = _first;
  late DateTime? _selected = _today;
  DateTime? _rangeStart;

  void _setMonth(DateTime m) {
    final target = monthOf(m);
    final clamped = target.isBefore(_first)
        ? _first
        : (target.isAfter(_last) ? _last : target);
    if (clamped == _month) {
      return;
    }
    setState(() {
      _month = clamped;
      _rangeStart = null;
      _selected = null;
    });
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String text, {
    String? action,
    VoidCallback? onAction,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action == null || onAction == null
              ? null
              : SnackBarAction(label: action, onPressed: onAction),
        ),
      );
  }

  /// A write is in flight: day taps wait, so writes never overlap.
  bool get _busy => ref.read(calendarEditControllerProvider).isLoading;

  Future<void> _mark(List<DateTime> days, {required bool off}) async {
    if (_busy) {
      return;
    }
    // Captured before the await: the undo action lives on the app-level
    // ScaffoldMessenger and may run after this screen is gone.
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(availabilityRepositoryProvider);
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final edit = ref.read(calendarEditControllerProvider.notifier);
    final ok = off ? await edit.markOff(days) : await edit.clearOff(days);
    if (!ok || uid == null) {
      _show(messenger, l.calendarSaveError);
      return;
    }
    final text = !off
        ? l.calendarClearedOff
        : days.length == 1
        ? l.calendarMarkedOff
        : l.calendarMarkedOffMany(days.length);
    _show(
      messenger,
      text,
      action: l.calendarUndo,
      onAction: () async {
        final undone = await writeDaysOff(repo, uid, days, off: !off);
        messenger.hideCurrentSnackBar();
        if (!undone) {
          _show(messenger, l.calendarSaveError);
        }
      },
    );
  }

  void _onDay(DateTime day, Map<DateTime, AvailabilityDay> known) {
    if (_busy) {
      return;
    }
    final start = _rangeStart;
    setState(() {
      _selected = day;
      _rangeStart = null;
    });
    if (start != null) {
      final days = freeDaysBetween(start, day, known, from: _today);
      if (days.isNotEmpty) {
        _mark(days, off: true);
      }
      return;
    }
    if (day.isBefore(_today)) {
      return;
    }
    final record = known[day];
    if (record?.eventId != null) {
      // The day section offers "Quản lý sự kiện".
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }
    switch (record?.state ?? DayState.free) {
      case DayState.free:
        _mark([day], off: true);
      case DayState.off:
        _mark([day], off: false);
      case DayState.booked || DayState.pending:
        // The day section says "Ngày này đã có lịch" and links to the
        // booking; a snackbar would cover that link.
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  void _onLongPress(DateTime day, Map<DateTime, AvailabilityDay> known) {
    if (_busy || day.isBefore(_today) || known.containsKey(day)) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _rangeStart = day;
      _selected = day;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the edit controller alive across awaits without rebuilding.
    ref.listen(calendarEditControllerProvider, (_, _) {});
    final l = context.l10n;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    return ScreenCode(
      ScreenCodes.myCalendar,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.myCalendarTitle)),
          body: SafeArea(
            top: false,
            child: uid == null ? const SizedBox.shrink() : _body(context, uid),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String uid) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final key = (uid: uid, month: _month);
    final days = ref.watch(availabilityMonthProvider(key));
    final known = days.value ?? const <DateTime, AvailabilityDay>{};
    final states = {for (final e in known.entries) e.key: e.value.state};
    final events = {
      for (final e in known.entries)
        if (e.value.eventId != null) e.key,
    };
    final window = monthWindow(_month, first: _first, last: _last);
    final tertiary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;

    Widget calendar = AvailabilityCalendar(
      month: _month,
      states: states,
      selected: _selected,
      editable: true,
      showHeader: false,
      minDate: _today,
      maxDate: lastDayOfMonth(_last),
      today: _today,
      eventDays: events,
      rangeStart: _rangeStart,
      onSelect: (d) => _onDay(d, known),
      onLongPress: (d) => _onLongPress(d, known),
      onMonthChanged: _setMonth,
    );
    if (!days.hasValue) {
      calendar = IgnorePointer(child: Opacity(opacity: 0.5, child: calendar));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        SegmentedTabs<DateTime>(
          key: const Key('month-tabs'),
          options: [
            for (final m in window)
              SegmentOption(
                value: m,
                label: l.calendarMonthShort('${m.month}'),
              ),
          ],
          value: _month,
          onChanged: _setMonth,
        ),
        const SizedBox(height: AppSpace.s3),
        calendar,
        if (days.hasError) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            l.calendarLoadError,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.retry,
            key: const Key('calendar-retry'),
            size: AppButtonSize.small,
            onPressed: () => ref.invalidate(availabilityMonthProvider(key)),
          ),
        ],
        const SizedBox(height: AppSpace.s3),
        const AvailabilityLegend(),
        _DaySection(
          day: _selected,
          record: _selected == null ? null : known[_selected],
          today: _today,
          onMark: (day, off) => _mark([day], off: off),
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          _rangeStart == null ? l.calendarHint : l.calendarRangeHint,
          style: theme.textTheme.bodySmall?.copyWith(color: tertiary),
        ),
      ],
    );
  }
}

/// Mock `.sec` row for the selected day (serif 17 title, accent action),
/// then what is planned on it.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.record,
    required this.today,
    required this.onMark,
  });

  final DateTime? day;
  final AvailabilityDay? record;
  final DateTime today;
  final void Function(DateTime day, bool off) onMark;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final d = day;
    if (d == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpace.s5),
        child: Text(l.calendarPickDay, style: theme.textTheme.bodyMedium),
      );
    }
    final state = record?.state ?? DayState.free;
    final past = d.isBefore(today);
    final bookingId = record?.bookingId;
    final eventId = record?.eventId;
    final planned = state == DayState.booked || state == DayState.pending;
    final Widget? action = past || planned || eventId != null
        ? null
        : state == DayState.off
        ? AppButton.text(
            l.calendarClearOff,
            key: const Key('clear-off'),
            size: AppButtonSize.small,
            onPressed: () => onMark(d, false),
          )
        : AppButton.text(
            l.calendarMarkOff,
            key: const Key('mark-off'),
            size: AppButtonSize.small,
            onPressed: () => onMark(d, true),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: ConstrainedBox(
            // Same row height with or without the 48dp action.
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.calendarDayTitle(
                        l.calendarWeekdayLong(weekdayCode(d.weekday)),
                        '${d.day}',
                        '${d.month}',
                      ),
                      style: theme.appBarTheme.titleTextStyle,
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: AppSpace.s2),
                  Flexible(child: action),
                ],
              ],
            ),
          ),
        ),
        if (planned) ...[
          const SizedBox(height: AppSpace.s1),
          Text(l.calendarHasPlan, style: theme.textTheme.bodyMedium),
        ],
        if (eventId != null) ...[
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.calendarOpenEvent,
            key: const Key('open-event'),
            icon: const Icon(Icons.event_outlined),
            onPressed: () => context.push('/events/$eventId/manage'),
          ),
        ],
        if (bookingId != null && planned) ...[
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.calendarOpenBooking,
            key: const Key('open-booking'),
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/b/$bookingId'),
          ),
        ],
      ],
    );
  }
}
