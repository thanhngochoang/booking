import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// How the booking flow words a package's price by day (S04.01-S04.03, #316).
/// Every number comes from `price_rules.dart`, the same pure functions the
/// server runs, so the price on screen is the price the server charges.

String _short(int v) => formatMoney(v, short: true);

/// A note under a day of S04.02 holds this many characters ("Tết 2,5M"):
/// longer than that, the rule name falls back to its first word.
const _kNoteChars = 12;

/// Lowest and highest price of [p] from [today] on: its base price and the
/// price of every series that still has a next occurrence (R9). One price
/// while the series have not loaded.
({int min, int max}) packageBounds(
  ServiceSummary p,
  List<PriceRule>? rules,
  DateTime today,
) => rules == null
    ? (min: p.priceVnd, max: p.priceVnd)
    : priceBounds(p.priceVnd, p.id, rules, today);

/// S04.01 right-hand price: one price in full, else the range "1,5M–2,5M".
String packageTilePrice(AppLocalizations l, ({int min, int max}) bounds) =>
    bounds.min == bounds.max
    ? formatMoney(bounds.min)
    : l.s0401_priceRange(_short(bounds.min), _short(bounds.max));

/// S04.01 sub-line of a package: "cuối tuần 1,8M" when a weekly series holds
/// only Saturday and Sunday, "giá theo ngày" for any other series, null when
/// the price is the same every day.
String? packageTileSub(
  AppLocalizations l,
  ServiceSummary p,
  List<PriceRule>? rules,
  DateTime today,
) {
  final b = packageBounds(p, rules, today);
  if (b.min == b.max) return null;
  int? weekend;
  for (final r in rules ?? const <PriceRule>[]) {
    if (r.serviceId != p.id ||
        r.repeat != PriceRepeat.weekly ||
        r.weekdays.isEmpty ||
        !r.weekdays.every((w) => w.isWeekend) ||
        nextOccurrence(r, today) == null) {
      continue;
    }
    if (weekend == null || r.price > weekend) weekend = r.price;
  }
  return weekend == null
      ? l.s0401_perDaySub
      : l.s0401_weekendSub(_short(weekend));
}

/// "Tiếp tục · {price}" of S04.01 and S04.02; "Tiếp tục · từ {price}" while
/// the package's price still depends on a day.
String continueLabel(AppLocalizations l, BookingFlowState s) {
  final total = formatMoney(s.totalVnd ?? 0);
  return s.priceIsFrom
      ? l.s0401_continueFrom(total)
      : l.bookContinuePrice(total);
}

/// The name of [rule] on a calendar cell next to [price]: the whole name when
/// both fit the cell, else its first word ("Tết Nguyên đán" -> "Tết"). A rule
/// without a name reads "Giá riêng" like everywhere else.
String ruleCellName(AppLocalizations l, PriceRule rule, String price) {
  final name = ruleTitle(l, rule);
  if (name.runes.length + 1 + price.runes.length <= _kNoteChars) {
    return name;
  }
  return name.split(RegExp(r'\s+')).first;
}

/// The calendar notes of [month] on S04.02: the short price, in accent, under
/// every day whose price differs from [base]; the first day of a series also
/// carries its abbreviated name ("Tết 2,5M"). A day the series dropped, or
/// priced like the base, has none.
Map<DateTime, CalendarNote> dayPriceNotes(
  AppLocalizations l, {
  required int base,
  required String serviceId,
  required List<PriceRule> rules,
  required DateTime month,
}) {
  if (!rules.any((r) => r.serviceId == serviceId)) {
    return const {};
  }
  final notes = <DateTime, CalendarNote>{};
  final last = DateTime.utc(month.year, month.month + 1, 0).day;
  // The day before the 1st (DateTime.utc rolls day 0 back one month).
  var before = priceForDay(
    base,
    serviceId,
    rules,
    DateTime.utc(month.year, month.month, 0),
  ).rule;
  for (var d = 1; d <= last; d++) {
    final day = DateTime.utc(month.year, month.month, d);
    final priced = priceForDay(base, serviceId, rules, day);
    final rule = priced.rule;
    if (priced.amount != base) {
      final price = _short(priced.amount);
      final named = rule != null && rule.id != before?.id;
      notes[day] = (
        text: named
            ? l.s0402_rulePrice(ruleCellName(l, rule, price), price)
            : price,
        accent: true,
      );
    }
    before = rule;
  }
  return notes;
}

/// "T7 21/11 · Mùa cưới · 2.000.000₫": the chosen day on S04.02 when a series
/// sets its price; null for a base-price day.
String? ruleDayLine(AppLocalizations l, BookingFlowState s) {
  final priced = s.dayPrice;
  final rule = priced?.rule;
  final date = s.day == null ? null : parseDayKey(s.day!);
  if (priced == null || rule == null || date == null) return null;
  return l.s0402_dayLine(
    weekdayDayText(date),
    ruleTitle(l, rule),
    formatMoney(priced.amount),
  );
}

/// Why a booking costs what it does: "(Tết)", "(giá theo ngày)" for a series
/// without a name; null for the base price. [ruleName] is the series name.
String? priceReason(
  AppLocalizations l, {
  required bool isRule,
  String? ruleName,
}) {
  if (!isRule) return null;
  final name = ruleName?.trim();
  return name == null || name.isEmpty
      ? l.s0403_dayReasonUnnamed
      : l.s0403_dayReasonRule(name);
}

/// [priceReason] of a booking, from what the server wrote into
/// `serviceSnapshot` (S05.02 and anything else that words a booking's price).
String? snapshotPriceReason(AppLocalizations l, BookingServiceSnapshot s) =>
    priceReason(l, isRule: s.priceKind == PriceKind.rule, ruleName: s.ruleName);

/// The package line of S04.03: "Gói {name} · T7 14/11 (Mùa cưới)". A package
/// whose price does not depend on the day keeps "Gói {name}"; a base-price day
/// of one that does carries no reason.
String packageLine(AppLocalizations l, BookingFlowState s) {
  final name = s.serviceName ?? '';
  final priced = s.dayPrice;
  final date = s.day == null ? null : parseDayKey(s.day!);
  final rule = priced?.rule;
  if (date == null || (rule == null && !s.pricesVary)) {
    return l.bookPackageLine(name);
  }
  final line = l.s0403_packageDay(name, formatDay(date));
  final reason = priceReason(l, isRule: rule != null, ruleName: rule?.name);
  return reason == null ? line : '$line $reason';
}
