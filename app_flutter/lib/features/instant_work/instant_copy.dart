// Shared Chụp ngay copy for the photographer screens (S14.01–S14.03, S06.01 card).
import 'dart:math' as math;

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "30 phút", "1 giờ", "2 giờ"; minutes when not whole hours.
String instantDurationText(AppLocalizations l, int minutes) =>
    minutes >= 60 && minutes % 60 == 0
    ? l.instantDurationHours(minutes ~/ 60)
    : l.instantDurationMinutes(minutes);

/// "30 phút · 15 ảnh".
String instantPackageText(AppLocalizations l, int minutes, int photos) =>
    l.instantPackageLabel(instantDurationText(l, minutes), photos);

String instantGenreText(AppLocalizations l, InstantGenre g) => switch (g) {
  InstantGenre.portrait => l.instantGenrePortrait,
  InstantGenre.couple => l.instantGenreCouple,
  InstantGenre.family => l.instantGenreFamily,
  InstantGenre.event => l.instantGenreEvent,
  InstantGenre.product => l.instantGenreProduct,
};

/// The badge of an active job; null for a status a job card never shows.
String? instantStatusText(AppLocalizations l, InstantStatus s) => switch (s) {
  InstantStatus.assigned => l.instantStatusAssigned,
  InstantStatus.enRoute => l.instantStatusEnRoute,
  InstantStatus.arrived => l.instantStatusArrived,
  InstantStatus.inProgress => l.instantStatusInProgress,
  InstantStatus.finished => l.instantStatusFinished,
  _ => null,
};

/// A failed Chụp ngay call as one toast line: `network` has its own text,
/// everything else the generic one.
String instantErrorText(AppLocalizations l, Object e) =>
    InstantError(instantErrorCodeOf(e)).kind == InstantErrorKind.network
    ? l.instantErrorNetwork
    : l.instantErrorGeneric;

/// Short money as on S06.05 ("390K", "1,19M"): two decimals from a million so
/// a price list row is not rounded up.
String instantShortMoney(int vnd) => vnd >= 1000000
    ? formatMoney(vnd, short: true, decimals: 2)
    : formatMoney(vnd, short: true);

/// "15:21": an instant as Vietnam wall-clock time.
String instantClock(DateTime instant) {
  final vn = toVn(instant);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(vn.hour)}:${two(vn.minute)}';
}

/// "350 m" under a kilometre (to 10 m), else "1,4 km".
String instantDistanceText(AppLocalizations l, double metres) => metres < 995
    ? l.instantDistanceMetres(math.max(10, (metres / 10).round() * 10))
    : formatDistance(metres / 1000);

/// "1,4": kilometres to 0,1 for a line that writes the unit itself.
String instantKmNumber(double km) =>
    math.max(0.1, roundKm(km)).toStringAsFixed(1).replaceAll('.', ',');
