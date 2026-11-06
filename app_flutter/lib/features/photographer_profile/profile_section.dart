// lib/features/photographer_profile/profile_section.dart
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The four tabs of S03.01.
enum ProfileSection { portfolio, services, calendar, reviews }

/// `?tab=` of `/u/:uid` (plan 3b4 links `?tab=services`).
ProfileSection profileSectionFromQuery(String? value) => switch (value) {
  'services' => ProfileSection.services,
  'calendar' => ProfileSection.calendar,
  'reviews' => ProfileSection.reviews,
  _ => ProfileSection.portfolio,
};

/// "Nhắn tin hỏi trước": step 4 opens (or creates) the `inquiry` chat with
/// this photographer at this path and replaces it with `/chat/:chatId`.
String inquiryPath(String photographerId) => '/u/$photographerId/ask';

/// "Đặt lịch · từ …": the lowest price of the cheapest active package or of
/// one of its price series that still has a next occurrence from [today] (R9,
/// the same number as the server's `startingPrice`). Without [rules] it is the
/// cheapest base price.
int? startingPriceOf(
  Iterable<ServiceSummary> services, {
  required DateTime today,
  List<PriceRule> rules = const [],
}) => startingPrice(
  [
    for (final s in services)
      PricedPackage(id: s.id, price: s.priceVnd, active: s.active),
  ],
  rules,
  today,
);

/// Median first-reply time in words: `~45 phút`, `~2 giờ`.
String responseLabel(int minutes, AppLocalizations l) => minutes < 60
    ? l.profileResponseMinutes(minutes)
    : l.profileResponseHours((minutes / 60).round());

String skillLevelLabel(int level, AppLocalizations l) => switch (level) {
  1 => l.skillsLevelBasic,
  2 => l.skillsLevelGood,
  _ => l.skillsLevelExpert,
};
