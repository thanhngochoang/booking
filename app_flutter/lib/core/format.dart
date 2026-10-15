import 'dart:math' as math;

import 'package:photobooking/core/geo.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// `1,2 km`: one decimal, a decimal comma, never `0,0 km`.
String formatDistance(double km) {
  final rounded = math.max(0.1, roundKm(km));
  return '${rounded.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// `1.500.000₫`; with [short] `1,5M` / `250K` for small cards. Callers show
/// the FreeTag for 0, never `0₫`.
///
/// With [short] and [decimals] 2, amounts from 100.000₫ up show in millions
/// with up to two decimals, trailing zeros trimmed (`3,95M`, `0,9M`), for
/// totals where `4M` for 3.950.000₫ would misread money.
String formatMoney(int vnd, {bool short = false, int decimals = 1}) {
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

  String compact(double v, String unit, [int places = 1]) {
    final f = places == 2 ? 100 : 10;
    final rounded = (v * f).round() / f;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded
              .toStringAsFixed(places)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll('.', ',');
    return '$text$unit';
  }

  if (!short || vnd < 1000) {
    return '${grouped(vnd)}₫';
  }
  if (decimals >= 2 && vnd >= 100000) {
    // Truncate (never round up) so a total is not overstated.
    final hundredths = vnd ~/ 10000;
    final whole = hundredths ~/ 100;
    final frac = (hundredths % 100).toString().padLeft(2, '0');
    final trimmed = frac.replaceAll(RegExp(r'0+$'), '');
    return '$whole${trimmed.isEmpty ? '' : ',$trimmed'}M';
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
String weekdayLabel(int weekday) {
  assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
  return weekday == DateTime.sunday ? 'CN' : 'T${weekday + 1}';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `12/10`.
String formatDayMonth(DateTime day) => '${_two(day.day)}/${_two(day.month)}';

/// `T7 12/10`. [day] is a Vietnamese calendar date; only its calendar fields
/// are read, so no time zone conversion happens here.
String formatDay(DateTime day) =>
    '${weekdayLabel(day.weekday)} ${formatDayMonth(day)}';

/// `97%`. Callers show it only when the provider has enough reviews
/// (`PhotographerSummary.hasTomatoPct`); [pct] is the stored integer 0..100.
String formatTomatoPct(int pct) => '${pct.clamp(0, 100)}%';

/// Most hits on one side of the review pad.
const int kVerdictHitsMax = 10;

/// Providers with fewer reviews show "Mới" instead of a percentage.
const int kTomatoPctMinReviews = 5;

/// Display mirror of the server rule `round2(0.4 + 0.6 * log10(hits))`, hits
/// 1..10 (the track width of the pad). The server computes the stored value.
double verdictIntensity(int hits) {
  final h = hits.clamp(1, kVerdictHitsMax);
  return (((0.4 + 0.6 * (math.log(h) / math.ln10)) * 100).round()) / 100;
}

/// `từ 1,5M`, or null when the price is unknown or not positive (callers then
/// leave the price out instead of showing `từ 0₫`).
String? priceFromLabel(int? vnd, AppLocalizations l) => vnd == null || vnd <= 0
    ? null
    : l.priceFromValue(formatMoney(vnd, short: true));

/// `45 phút`, `2 giờ`, `1 giờ 30 phút`.
String formatDuration(int minutes, AppLocalizations l) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) {
    return l.serviceDurationMinutes(m);
  }
  return m == 0
      ? l.serviceDurationHours(h)
      : l.serviceDurationHoursMinutes(h, m);
}
