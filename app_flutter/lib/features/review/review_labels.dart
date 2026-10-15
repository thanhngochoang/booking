import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Data side → core widget side (core cannot import `lib/data`).
extension VerdictKindOf on Verdict {
  VerdictKind get kind => switch (this) {
    Verdict.tomato => VerdictKind.tomato,
    Verdict.brick => VerdictKind.brick,
  };
}

extension VerdictOfKind on VerdictKind {
  Verdict get verdict => switch (this) {
    VerdictKind.tomato => Verdict.tomato,
    VerdictKind.brick => Verdict.brick,
  };
}

/// The chip text of a brick reason.
String reviewReasonLabel(AppLocalizations l, ReviewReason reason) =>
    switch (reason) {
      ReviewReason.late => l.reviewReasonLate,
      ReviewReason.notAsPortfolio => l.reviewReasonNotAsPortfolio,
      ReviewReason.slowDelivery => l.reviewReasonSlowDelivery,
      ReviewReason.attitude => l.reviewReasonAttitude,
      ReviewReason.priceChanged => l.reviewReasonPriceChanged,
      ReviewReason.other => l.reviewReasonOther,
    };
