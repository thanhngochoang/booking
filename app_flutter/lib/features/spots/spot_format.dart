import 'package:flutter/services.dart';
import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Formats the contiguous season range, e.g. "10–12", "12–1", "5".
String formatSeasonRange(List<int> months) {
  if (months.isEmpty) return '';
  if (months.length == 1) return '${months.first}';

  final set = months.toSet();
  int start = months.first;
  for (final m in months) {
    final prev = (m == 1) ? 12 : m - 1;
    if (!set.contains(prev)) {
      start = m;
      break;
    }
  }

  final end = seasonRunEnd(months, start) ?? months.last;
  return '$start–$end';
}

/// Returns the season label:
/// - "Đang vào mùa · tới cuối tháng 12" when in season
/// - "Mùa đẹp: tháng 10–12" when out of season
/// - "Đẹp quanh năm" when seasonMonths is empty
String seasonLabel(
  AppLocalizations l,
  List<int> seasonMonths,
  int currentMonth,
) {
  if (seasonMonths.isEmpty) {
    return l.spotSeasonAllYear;
  }
  if (inSeason(seasonMonths, currentMonth)) {
    final end = seasonRunEnd(seasonMonths, currentMonth);
    return l.spotSeasonEnding(end ?? currentMonth);
  }
  final range = formatSeasonRange(seasonMonths);
  return l.spotSeasonBest('tháng $range');
}

/// e.g. "3 thợ · 1 sự kiện sắp tới"
String spotCardStats(AppLocalizations l, SpotEntry entry) {
  return l.spotCardStats(entry.openSchedules, entry.upcomingEvents);
}

/// e.g. "Có mặt CN 18/10 · 06:00–11:00"
String spotAvailableLabel(
  AppLocalizations l,
  String dayKey,
  SpotWindow window,
) {
  final date = parseDayKey(dayKey);
  final dayStr = date != null ? formatDay(date) : dayKey;
  return l.spotAvailableLabel(dayStr, window.start, window.end);
}

/// Public share link for a spot.
String spotLink(String spotId) => '/spots/$spotId';

Future<void> copySpotLink(String spotId) =>
    Clipboard.setData(ClipboardData(text: spotLink(spotId)));

