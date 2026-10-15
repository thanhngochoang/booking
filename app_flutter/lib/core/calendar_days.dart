import 'package:photobooking/core/vn_time.dart';

/// Calendar days are plain dates on the Vietnamese wall calendar
/// (`LocalDate` in the data model). In Dart they are UTC-midnight
/// `DateTime`s, so two days compare and hash by date alone; `vnDateKey(day)`
/// gives their `yyyy-MM-dd` key.
DateTime calendarDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// The first day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime.utc(d.year, d.month);

/// [month] moved by [n] months (negative goes back); always the 1st.
DateTime addMonths(DateTime month, int n) =>
    DateTime.utc(month.year, month.month + n);

DateTime lastDayOfMonth(DateTime month) =>
    DateTime.utc(month.year, month.month + 1, 0);

/// Today on the Vietnamese calendar for the instant [nowUtc].
DateTime vnToday(DateTime nowUtc) => calendarDay(toVn(nowUtc));

/// The 42 days (six weeks, Monday first) a month grid shows for [month].
List<DateTime> monthGrid(DateTime month) {
  final first = monthOf(month);
  final lead = first.weekday - DateTime.monday;
  return [
    for (var i = 0; i < 42; i++)
      DateTime.utc(first.year, first.month, 1 - lead + i),
  ];
}

/// Every day from [a] to [b], both included, oldest first.
List<DateTime> daysBetween(DateTime a, DateTime b) {
  final start = calendarDay(a.isBefore(b) ? a : b);
  final end = calendarDay(a.isBefore(b) ? b : a);
  return [
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime.utc(d.year, d.month, d.day + 1)
    )
      d,
  ];
}
