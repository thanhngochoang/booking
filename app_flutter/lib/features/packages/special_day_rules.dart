import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/special_days.dart';

/// Most days one range may cover.
const kSpecialRangeMaxDays = 60;

/// How far ahead a range may end.
const kSpecialRangeMaxDaysAhead = 365;

/// Most ranges one provider may have (the app enforces it).
const kSpecialRangesMax = 20;

/// Name length bounds.
const kSpecialNameMin = 2;
const kSpecialNameMax = 40;

enum SpecialDayError { name, past, tooLong, tooFar, limit }

/// The first rule a range breaks, or null. [from] and [to] are calendar days
/// (UTC midnight), [today] is today on the Vietnamese calendar.
/// [existingCount] counts the provider's other ranges; it only matters for a
/// new range ([isNew]). A range being edited may keep its [keepFrom] even
/// when that day has passed.
SpecialDayError? specialDayError({
  required String name,
  required DateTime? from,
  required DateTime? to,
  required DateTime today,
  required int existingCount,
  required bool isNew,
  DateTime? keepFrom,
}) {
  if (isNew && existingCount >= kSpecialRangesMax) {
    return SpecialDayError.limit;
  }
  final len = name.trim().length;
  if (len < kSpecialNameMin || len > kSpecialNameMax) {
    return SpecialDayError.name;
  }
  if (from == null || to == null) {
    return null;
  }
  if (to.isBefore(from)) {
    return null;
  }
  if (from.isBefore(today) && from != keepFrom) {
    return SpecialDayError.past;
  }
  if (daysBetween(from, to).length > kSpecialRangeMaxDays) {
    return SpecialDayError.tooLong;
  }
  if (vnDaysBetween(today, to) > kSpecialRangeMaxDaysAhead) {
    return SpecialDayError.tooFar;
  }
  return null;
}

/// Consecutive holiday days with the same name, as one line of S08.10.
typedef HolidayRun = ({String name, DateTime from, DateTime to});

List<HolidayRun> holidayRuns(List<Holiday> holidays) {
  final days = <({String name, DateTime day})>[
    for (final h in holidays)
      if (parseDayKey(h.day) case final d?) (name: h.name, day: d),
  ]..sort((a, b) => a.day.compareTo(b.day));
  final runs = <HolidayRun>[];
  for (final h in days) {
    final last = runs.isEmpty ? null : runs.last;
    if (last != null &&
        last.name == h.name &&
        vnDaysBetween(last.to, h.day) <= 1) {
      runs[runs.length - 1] = (name: last.name, from: last.from, to: h.day);
    } else {
      runs.add((name: h.name, from: h.day, to: h.day));
    }
  }
  return runs;
}
