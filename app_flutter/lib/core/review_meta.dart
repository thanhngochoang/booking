// lib/core/review_meta.dart
import 'package:photobooking/core/widgets/meta_line.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The review part of a meta line: the tomato part from five
/// reviews (`hasTomatoPct`), "Mới · 3 đánh giá" below that, and nothing
/// without reviews. [withCount] adds the count after the percent (`97% (58)`,
/// the S02.01 photo cards).
MetaPart? reviewMetaPart(
  PhotographerSummary p,
  AppLocalizations l, {
  bool withCount = false,
}) {
  if (p.hasTomatoPct) {
    return MetaPart.tomato(
      p.tomatoPct,
      count: withCount ? p.reviewCount : null,
    );
  }
  if (p.hasReviews) {
    return MetaPart.text(l.photographerReviewsNew(p.reviewCount));
  }
  return null;
}
