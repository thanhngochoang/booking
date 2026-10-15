import 'package:photobooking/l10n/app_localizations.dart';

/// `2 giờ`, or `1,5 giờ` for a duration that is not whole hours.
String durationLabel(int minutes, AppLocalizations l) => minutes % 60 == 0
    ? l.durationHours('${minutes ~/ 60}')
    : l.durationHours((minutes / 60).toStringAsFixed(1).replaceAll('.', ','));

/// The line under a package name: `2 giờ · 40 ảnh · giao 3 ngày`, with only
/// the parts that are known.
String packageMeta(
  AppLocalizations l, {
  required int durationMinutes,
  int? editedCount,
  int? deliveryDays,
}) => [
  durationLabel(durationMinutes, l),
  if (editedCount != null && editedCount > 0) l.packagePhotos(editedCount),
  if (deliveryDays != null) l.packageDelivery(deliveryDays),
].join(' · ');
