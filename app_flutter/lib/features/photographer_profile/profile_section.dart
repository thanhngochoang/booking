// lib/features/photographer_profile/profile_section.dart
import 'package:photobooking/data/content/service_summary.dart';
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

/// "Đặt lịch · từ …": the cheapest active package, until the server's
/// `startingPrice` is there for every photographer.
int? startingPriceOf(Iterable<ServiceSummary> services) {
  int? min;
  for (final s in services) {
    if (s.active && (min == null || s.priceVnd < min)) {
      min = s.priceVnd;
    }
  }
  return min;
}

/// Median first-reply time in words: `~45 phút`, `~2 giờ`.
String responseLabel(int minutes, AppLocalizations l) => minutes < 60
    ? l.profileResponseMinutes(minutes)
    : l.profileResponseHours((minutes / 60).round());

String skillLevelLabel(int level, AppLocalizations l) => switch (level) {
  1 => l.skillsLevelBasic,
  2 => l.skillsLevelGood,
  _ => l.skillsLevelExpert,
};
