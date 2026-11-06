import 'dart:math' as math;

/// Vietnamese lunar calendar, Hồ Ngọc Đức's algorithm, time zone UTC+7.
///
/// Port of `packages/domain/src/lunar.ts` (booking-be). Only the year, month
/// and day fields of a `DateTime` are read, so the time of day and the time
/// zone of the value never change the result. Every input is positive, so
/// `~/` and `.floor()` agree with the reference's integer truncation.
class LunarDate {
  const LunarDate({
    required this.day,
    required this.month,
    required this.year,
    required this.leap,
  });

  final int day;
  final int month;
  final int year;
  final bool leap;

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.day == day &&
      other.month == month &&
      other.year == year &&
      other.leap == leap;

  @override
  int get hashCode => Object.hash(day, month, year, leap);

  @override
  String toString() => 'LunarDate($day/$month${leap ? ' leap' : ''}/$year)';
}

const int _tz = 7;
const double _synodic = 29.530588853;
const double _epoch = 2415021.076998695;

int _jdFromDate(int dd, int mm, int yy) {
  final a = (14 - mm) ~/ 12;
  final y = yy + 4800 - a;
  final m = mm + 12 * a - 3;
  var jd =
      dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  if (jd < 2299161) {
    jd = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - 32083;
  }
  return jd;
}

({int day, int month, int year}) _jdToDate(int jd) {
  final int b;
  final int c;
  if (jd > 2299160) {
    final a = jd + 32044;
    b = (4 * a + 3) ~/ 146097;
    c = a - (b * 146097) ~/ 4;
  } else {
    b = 0;
    c = jd + 32082;
  }
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  return (
    day: e - (153 * m + 2) ~/ 5 + 1,
    month: m + 3 - 12 * (m ~/ 10),
    year: b * 100 + d - 4800 + m ~/ 10,
  );
}

double _newMoon(int k) {
  final t = k / 1236.85;
  final t2 = t * t;
  final t3 = t2 * t;
  const dr = math.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  var c1 =
      (0.1734 - 0.000393 * t) * math.sin(m * dr) +
      0.0021 * math.sin(2 * dr * m);
  c1 += -0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
  c1 += -0.0004 * math.sin(dr * 3 * mpr);
  c1 += 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
  c1 +=
      -0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
  c1 +=
      -0.0004 * math.sin(dr * (2 * f - m)) -
      0.0006 * math.sin(dr * (2 * f + mpr));
  c1 +=
      0.001 * math.sin(dr * (2 * f - mpr)) +
      0.0005 * math.sin(dr * (2 * mpr + m));
  final deltat = t < -11
      ? 0.001 +
            0.000839 * t +
            0.0002261 * t2 -
            0.00000845 * t3 -
            0.000000081 * t * t3
      : -0.000278 + 0.000265 * t + 0.000262 * t2;
  return jd1 + c1 - deltat;
}

double _sunLongitude(double jdn) {
  final t = (jdn - 2451545.0) / 36525;
  final t2 = t * t;
  const dr = math.pi / 180;
  final m = 357.5291 + 35999.0503 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.9146 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl +=
      (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) +
      0.00029 * math.sin(dr * 3 * m);
  var l = (l0 + dl) * dr;
  l -= math.pi * 2 * (l / (math.pi * 2)).floor();
  return l;
}

int _getSunLongitude(int dayNumber) =>
    ((_sunLongitude(dayNumber - 0.5 - _tz / 24) / math.pi) * 6).floor();

int _getNewMoonDay(int k) => (_newMoon(k) + 0.5 + _tz / 24).floor();

int _getLunarMonth11(int yy) {
  final off = _jdFromDate(31, 12, yy) - 2415021;
  final k = (off / _synodic).floor();
  var nm = _getNewMoonDay(k);
  if (_getSunLongitude(nm) >= 9) {
    nm = _getNewMoonDay(k - 1);
  }
  return nm;
}

int _getLeapMonthOffset(int a11) {
  final k = ((a11 - _epoch) / _synodic + 0.5).floor();
  var i = 1;
  var arc = _getSunLongitude(_getNewMoonDay(k + i));
  int last;
  do {
    last = arc;
    i += 1;
    arc = _getSunLongitude(_getNewMoonDay(k + i));
  } while (arc != last && i < 14);
  return i - 1;
}

LunarDate _lunarOfJd(int dayNumber, int yy) {
  final k = ((dayNumber - _epoch) / _synodic).floor();
  var monthStart = _getNewMoonDay(k + 1);
  if (monthStart > dayNumber) {
    monthStart = _getNewMoonDay(k);
  }
  var a11 = _getLunarMonth11(yy);
  var b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = yy;
    a11 = _getLunarMonth11(yy - 1);
  } else {
    lunarYear = yy + 1;
    b11 = _getLunarMonth11(yy + 1);
  }
  final lunarDay = dayNumber - monthStart + 1;
  final diff = (monthStart - a11) ~/ 29;
  var leap = false;
  var lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    final leapMonthDiff = _getLeapMonthOffset(a11);
    if (diff >= leapMonthDiff) {
      lunarMonth = diff + 10;
      if (diff == leapMonthDiff) {
        leap = true;
      }
    }
  }
  if (lunarMonth > 12) {
    lunarMonth -= 12;
  }
  if (lunarMonth >= 11 && diff < 4) {
    lunarYear -= 1;
  }
  return LunarDate(
    day: lunarDay,
    month: lunarMonth,
    year: lunarYear,
    leap: leap,
  );
}

/// Solar jd of lunar day 1 of the month, or null when the leap month does not exist.
int? _lunarMonthStartJd(int lm, int ly, bool leap) {
  final int a11;
  final int b11;
  if (lm < 11) {
    a11 = _getLunarMonth11(ly - 1);
    b11 = _getLunarMonth11(ly);
  } else {
    a11 = _getLunarMonth11(ly);
    b11 = _getLunarMonth11(ly + 1);
  }
  final k = (0.5 + (a11 - _epoch) / _synodic).floor();
  var off = lm - 11;
  if (off < 0) {
    off += 12;
  }
  if (b11 - a11 > 365) {
    final leapOff = _getLeapMonthOffset(a11);
    var leapMonth = leapOff - 2;
    if (leapMonth < 0) {
      leapMonth += 12;
    }
    if (leap && lm != leapMonth) {
      return null;
    }
    if (leap || off >= leapOff) {
      off += 1;
    }
  } else if (leap) {
    return null;
  }
  return _getNewMoonDay(k + off);
}

/// Lunar date of the Gregorian [day] (date part only, no time zone math).
LunarDate solarToLunar(DateTime day) =>
    _lunarOfJd(_jdFromDate(day.day, day.month, day.year), day.year);

/// Gregorian day (UTC midnight, like the rest of `core` calendar days) of a
/// lunar date; null when the requested leap month does not exist.
DateTime? lunarToSolar(int day, int month, int year, {bool leap = false}) {
  final start = _lunarMonthStartJd(month, year, leap);
  if (start == null) {
    return null;
  }
  final g = _jdToDate(start + day - 1);
  return DateTime.utc(g.year, g.month, g.day);
}

/// "6" for the 6th lunar day, "1/10" on the 1st of a lunar month.
String lunarLabel(DateTime day) {
  final l = solarToLunar(day);
  return l.day == 1 ? '1/${l.month}' : '${l.day}';
}

/// The leap month number of a lunar year (2025 → 6, 2028 → 5, 2031 → 3), or null.
int? leapMonthOf(int lunarYear) {
  int? leapIn(int a11, int b11) {
    if (b11 - a11 <= 365) {
      return null;
    }
    final m = _getLeapMonthOffset(a11) - 2;
    return m < 0 ? m + 12 : m;
  }

  // Months 1..10 of the year sit between month 11 of the previous year and
  // month 11 of this one; a leap month 11 or 12 belongs to the span that
  // starts at month 11 of this year.
  final early = leapIn(
    _getLunarMonth11(lunarYear - 1),
    _getLunarMonth11(lunarYear),
  );
  if (early != null && early <= 10) {
    return early;
  }
  final late = leapIn(
    _getLunarMonth11(lunarYear),
    _getLunarMonth11(lunarYear + 1),
  );
  if (late != null && late >= 11) {
    return late;
  }
  return null;
}

/// Number of days (29 or 30) of a lunar month. Throws [ArgumentError] if the
/// month does not exist.
int lunarMonthLength(int month, int year, {bool leap = false}) {
  final start = _lunarMonthStartJd(month, year, leap);
  if (start == null) {
    throw ArgumentError.value(month, 'month', 'no such lunar month');
  }
  final g = _jdToDate(start + 29);
  return _lunarOfJd(start + 29, g.year).day == 30 ? 30 : 29;
}
