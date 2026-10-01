import 'dart:math' as math;

import 'package:photobooking/core/geo.dart';

/// `1,2 km`: one decimal, a decimal comma, never `0,0 km`.
String formatDistance(double km) {
  final rounded = math.max(0.1, roundKm(km));
  return '${rounded.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// `1.500.000₫`; with [short] `1,5M` / `250K` for small cards. Callers show
/// the FreeTag for 0, never `0₫`.
String formatMoney(int vnd, {bool short = false}) {
  String grouped(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        out.write('.');
      }
      out.write(s[i]);
    }
    return out.toString();
  }

  String compact(double v, String unit) {
    final rounded = (v * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
    return '$text$unit';
  }

  if (!short || vnd < 1000) {
    return '${grouped(vnd)}₫';
  }
  if (vnd >= 1000000) {
    return compact(vnd / 1000000, 'M');
  }
  // 999.950 rounds to 1000K: switch to M instead.
  if ((vnd / 1000 * 10).round() >= 10000) {
    return compact(vnd / 1000000, 'M');
  }
  return compact(vnd / 1000, 'K');
}

/// `T2`..`T7`, `CN` for [DateTime.monday]..[DateTime.sunday].
String weekdayLabel(int weekday) =>
    weekday == DateTime.sunday ? 'CN' : 'T${weekday + 1}';

String _two(int n) => n.toString().padLeft(2, '0');

/// `12/10`.
String formatDayMonth(DateTime day) => '${_two(day.day)}/${_two(day.month)}';

/// `T7 12/10`. [day] is a Vietnamese calendar date; only its calendar fields
/// are read, so no time zone conversion happens here.
String formatDay(DateTime day) =>
    '${weekdayLabel(day.weekday)} ${formatDayMonth(day)}';

/// `4,9`.
String formatRating(double rating) =>
    ((rating * 10).round() / 10).toStringAsFixed(1).replaceAll('.', ',');
