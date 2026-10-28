// The review part of a Chụp ngay person's meta line (S13.02 cards and
// summary, S13.03 rows, S13.05 row): the tomato percent from five reviews
// (`kTomatoPctMinReviews`), "Mới · {n} đánh giá" below when [newLabel],
// nothing without reviews.
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/l10n/app_localizations.dart';

List<MetaPart> instantReviewMeta(
  AppLocalizations l, {
  required int tomatoPct,
  required int reviewCount,
  bool newLabel = true,
}) => [
  if (reviewCount >= kTomatoPctMinReviews)
    MetaPart.tomato(tomatoPct)
  else if (newLabel && reviewCount > 0)
    MetaPart.text(l.photographerReviewsNew(reviewCount)),
];

/// Reviews and "112 buổi" of the assigned photographer (S13.05).
List<MetaPart> instantPartyMeta(AppLocalizations l, InstantParty p) => [
  ...instantReviewMeta(l, tomatoPct: p.tomatoPct, reviewCount: p.reviewCount),
  MetaPart.text(l.photographerSessions(p.completedCount)),
];
