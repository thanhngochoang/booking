/// Vietnam has no daylight saving, so wall-clock time is UTC+7 all year.
const _vnOffset = Duration(hours: 7);

/// A UTC-labelled `DateTime` whose fields read as Vietnam wall-clock time.
/// Use its `year/month/day/hour/weekday`; do not compare it with real instants.
DateTime toVn(DateTime instant) => instant.toUtc().add(_vnOffset);

bool isVnWeekend(DateTime instant) {
  final d = toVn(instant).weekday;
  return d == DateTime.saturday || d == DateTime.sunday;
}

/// The instant at which the Vietnamese week containing [instant] ends:
/// the next Monday 00:00 in Vietnam, returned as a UTC instant.
DateTime endOfVnWeek(DateTime instant) {
  final vn = toVn(instant);
  final startOfDay = DateTime.utc(vn.year, vn.month, vn.day);
  final daysToMonday = 8 - vn.weekday; // Mon -> 7, Sun -> 1
  return startOfDay.add(Duration(days: daysToMonday)).subtract(_vnOffset);
}

/// `yyyy-MM-dd` of the Vietnamese calendar day containing [instant].
String vnDateKey(DateTime instant) {
  final v = toVn(instant);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${v.year.toString().padLeft(4, '0')}-${two(v.month)}-${two(v.day)}';
}

/// Parses `yyyy-MM-dd` into a UTC midnight, or null if it is not a real date.
DateTime? parseDayKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) {
    return null;
  }
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime.utc(y, mo, d);
  return (date.year == y && date.month == mo && date.day == d) ? date : null;
}
