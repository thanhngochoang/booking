// lib/features/discovery/photographer_meta.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Quận 3 · ★ 4,9 (58) · 112 buổi": only the parts that exist.
String areaRatingMeta(PhotographerSummary p, AppLocalizations l) => [
  if (p.areaLabel != null && p.areaLabel!.isNotEmpty) p.areaLabel!,
  if (p.hasRating) '★ ${formatRating(p.ratingAvg)} (${p.reviewCount})',
  if (p.completedCount > 0) l.photographerSessions(p.completedCount),
].join(' · ');

/// "Rảnh T7 này" when the next free day is within the next 7 Vietnamese days.
String? freeThisWeekLabel(
  PhotographerSummary p,
  DateTime now,
  AppLocalizations l,
) {
  final key = p.nextFreeDate;
  final day = p.nextFreeDay;
  if (key == null || day == null) {
    return null;
  }
  final inWindow =
      key.compareTo(vnDateKey(now)) >= 0 &&
      key.compareTo(vnDateKey(now.add(const Duration(days: 7)))) < 0;
  return inWindow ? l.homePillFree(weekdayLabel(day.weekday)) : null;
}
