import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

/// The cell of a calendar day as a screen reader says it.
///
/// [label] is "13 tháng 10, rảnh": day, month, then the state ("rảnh", "đã
/// đặt", "chờ nhận", "nghỉ", "hết chỗ"), optionally ", có sự kiện" and a price
/// note ("rảnh, Cuối 1,8M"). Every cell of an `AppCalendar` reads "Thứ Ba 13
/// tháng 10, 4 tháng 9 âm lịch, rảnh[, hôm nay]" with the note on the next
/// line, so the weekday, the lunar date and "hôm nay" are matched loosely and
/// the rest exactly. Needs `tester.ensureSemantics()`.
Finder dayByLabel(String label) {
  final m = RegExp(
    r'^(\d+ tháng \d+), (rảnh|đã đặt|chờ nhận|nghỉ|hết chỗ)'
    r'(, có sự kiện)?(?:, (.*))?$',
  ).firstMatch(label);
  if (m == null) {
    throw ArgumentError.value(label, 'label', 'expected "D tháng M, state"');
  }
  final note = m[4] == null ? '' : '\n${RegExp.escape(m[4]!)}';
  return find.bySemanticsLabel(
    RegExp('^[^,]* ${m[1]}, [^,]*, ${m[2]}${m[3] ?? ''}(, hôm nay)?$note\$'),
  );
}

/// The cell of [day] (a calendar day), whatever it says; for taps and
/// geometry. No semantics needed.
Finder calendarCell(DateTime day) =>
    find.byKey(ValueKey('app-calendar-day-${vnDateKey(day)}'));

/// The small lunar number of [day] ("1/10" on the first of a lunar month).
Finder calendarLunar(DateTime day) =>
    find.byKey(ValueKey('app-calendar-lunar-${vnDateKey(day)}'));
