import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/day_pricing.dart'
    show Weekday, kMaxPriceVnd, weekdayOf;
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

/// Pure logic of the "Đặt giá" sheet (S08.10-new, spec §5.4): how the picked
/// solar days become a rule's `from`/`to`, the helper lines of the repeat
/// section, and the inline errors. No widgets and no l10n here.

String _two(int n) => n.toString().padLeft(2, '0');

/// `MM-dd`, the form of a yearly rule's `from`/`to`.
String monthDayKey(int month, int day) => '${_two(month)}-${_two(day)}';

/// The month and day of an `MM-dd` key.
({int month, int day}) monthDayOf(String key) => (
  month: int.parse(key.substring(0, 2)),
  day: int.parse(key.substring(3, 5)),
);

/// The lunar day-month a solar [day] stands for in a yearly lunar rule (R14):
/// the leap month counts as its main month, [leap] tells it was one.
({String key, int month, int day, int year, bool leap}) lunarPickOf(
  DateTime day,
) {
  final l = solarToLunar(day);
  return (
    key: monthDayKey(l.month, l.day),
    month: l.month,
    day: l.day,
    year: l.year,
    leap: l.leap,
  );
}

DateTime? _lunarMainDay(int day, int month, int year) {
  final len = lunarMonthLength(month, year);
  return lunarToSolar(day < len ? day : len, month, year);
}

/// One occurrence of a yearly rule that starts in [year] (the solar year, or
/// the lunar year of the first day when [lunar]) as whole solar days. The end
/// is in the next year when the rule crosses the year. Null when a lunar date
/// does not exist.
DayRange? yearlyOccurrenceOf({
  required String from,
  required String to,
  required bool lunar,
  required int year,
}) {
  final f = monthDayOf(from);
  final t = monthDayOf(to);
  final wraps = t.month * 100 + t.day < f.month * 100 + f.day;
  final endYear = wraps ? year + 1 : year;
  if (!lunar) {
    return (
      from: DateTime.utc(year, f.month, f.day),
      to: DateTime.utc(endYear, t.month, t.day),
    );
  }
  final start = _lunarMainDay(f.day, f.month, year);
  final end = _lunarMainDay(t.day, t.month, endYear);
  return start == null || end == null ? null : (from: start, to: end);
}

/// The whole occurrence of a yearly rule that is running on [today] or comes
/// next, as solar days (a range crossing 31/12 is one range here, unlike
/// `ruleRanges`). Null when no date can be found.
DayRange? nextYearlyOccurrence({
  required String from,
  required String to,
  required bool lunar,
  required DateTime today,
}) {
  final base = lunar ? solarToLunar(today).year : today.year;
  for (var year = base - 1; year <= base + 2; year++) {
    final r = yearlyOccurrenceOf(from: from, to: to, lunar: lunar, year: year);
    if (r != null && !r.to.isBefore(today)) {
      return r;
    }
  }
  return null;
}

/// The weekdays that fall in [from]..[to] (all seven from a week on): what
/// "Hằng tuần" starts with.
Set<Weekday> weekdaysBetween(DateTime from, DateTime to) {
  final out = <Weekday>{};
  for (var i = 0; i < 7; i++) {
    final d = DateTime.utc(from.year, from.month, from.day + i);
    if (d.isAfter(to)) {
      break;
    }
    out.add(weekdayOf(d));
  }
  return out;
}

/// What an inline error of the sheet is about, and where it is shown.
enum RuleFormError {
  /// Empty, zero or not a number.
  price(RuleFormErrorSpot.price),

  /// Above 1.000.000.000₫.
  priceHigh(RuleFormErrorSpot.price),
  weekdays(RuleFormErrorSpot.weekdays),

  /// Yearly on the solar calendar with 29/2.
  leapDay(RuleFormErrorSpot.repeat),

  /// A one-off range that ended before today (create only).
  past(RuleFormErrorSpot.dates),
  tooLong(RuleFormErrorSpot.dates),
  tooFar(RuleFormErrorSpot.dates),

  /// The package already has 30 series (`rule_limit`).
  limit(RuleFormErrorSpot.form),

  /// The rule has 50 exceptions already (`exception_limit`).
  exceptionLimit(RuleFormErrorSpot.form);

  const RuleFormError(this.spot);
  final RuleFormErrorSpot spot;
}

enum RuleFormErrorSpot { price, dates, repeat, weekdays, form }

/// What the photographer has filled in on the "Đặt giá" sheet.
class RuleFormValues {
  const RuleFormValues({
    required this.serviceId,
    required this.price,
    required this.name,
    required this.repeats,
    required this.cycle,
    required this.lunar,
    required this.from,
    required this.to,
    required this.weekdays,
    this.template,
    this.keepFrom,
    this.keepTo,
  });

  final String serviceId;

  /// Null when the field is empty or not a number.
  final int? price;
  final String name;

  /// The "Lặp lại" switch.
  final bool repeats;

  /// The "Chu kỳ" choice: `weekly` or `yearly`; used when [repeats].
  final PriceRepeat cycle;

  /// The "Theo âm lịch" switch; used for yearly.
  final bool lunar;
  final DateTime from;
  final DateTime to;
  final Set<Weekday> weekdays;
  final String? template;

  /// Editing a yearly series whose dates were not touched: its stored
  /// `from`/`to` are sent as they are, because the dates shown are only the
  /// next occurrence (a lunar one may be cut by a leap month).
  final String? keepFrom;
  final String? keepTo;

  PriceRepeat get kind => repeats ? cycle : PriceRepeat.none;

  /// The `from` of the rule: `MM-dd` of the picked day (lunar: its lunar
  /// day-month, main month), or the stored one when kept.
  String get yearlyFrom =>
      keepFrom ??
      (lunar ? lunarPickOf(from).key : monthDayKey(from.month, from.day));

  String get yearlyTo =>
      keepTo ?? (lunar ? lunarPickOf(to).key : monthDayKey(to.month, to.day));

  /// The rule to send, or null while [price] is unusable.
  PriceRuleInput? toInput() {
    final p = price;
    if (p == null) {
      return null;
    }
    final trimmed = name.trim();
    return switch (kind) {
      PriceRepeat.none => PriceRuleInput(
        serviceId: serviceId,
        price: p,
        repeat: PriceRepeat.none,
        name: trimmed,
        from: dayKeyOf(from),
        to: dayKeyOf(to),
      ),
      PriceRepeat.yearly => PriceRuleInput(
        serviceId: serviceId,
        price: p,
        repeat: PriceRepeat.yearly,
        name: trimmed,
        lunar: lunar,
        from: yearlyFrom,
        to: yearlyTo,
        template: template,
      ),
      PriceRepeat.weekly => PriceRuleInput(
        serviceId: serviceId,
        price: p,
        repeat: PriceRepeat.weekly,
        name: trimmed,
        weekdays: weekdays,
      ),
    };
  }
}

bool _isFeb29(DateTime d) => d.month == 2 && d.day == 29;

/// The first inline error of [v], or null. [serviceIds] are the owner's
/// packages, [ruleCount] the series the package has, [otherCounts] those of
/// the other packages (checked when [applyToAll]).
RuleFormError? ruleFormError(
  RuleFormValues v, {
  required DateTime today,
  required bool creating,
  required List<String> serviceIds,
  required int ruleCount,
  bool applyToAll = false,
  List<int> otherCounts = const [],
}) {
  final price = v.price;
  if (price == null || price < 1) {
    return RuleFormError.price;
  }
  if (price > kMaxPriceVnd) {
    return RuleFormError.priceHigh;
  }
  switch (v.kind) {
    case PriceRepeat.weekly:
      if (v.weekdays.isEmpty) {
        return RuleFormError.weekdays;
      }
    case PriceRepeat.none:
      if (creating && v.to.isBefore(today)) {
        return RuleFormError.past;
      }
      if (v.from.isAfter(
        DateTime.utc(today.year, today.month, today.day + 730),
      )) {
        return RuleFormError.tooFar;
      }
      if (v.to.difference(v.from).inDays + 1 > kMaxSpanDays) {
        return RuleFormError.tooLong;
      }
    case PriceRepeat.yearly:
      if (!v.lunar && (_isFeb29(v.from) || _isFeb29(v.to))) {
        return RuleFormError.leapDay;
      }
      if (v.to.difference(v.from).inDays + 1 > kMaxSpanDays) {
        return RuleFormError.tooLong;
      }
  }
  final input = v.toInput();
  final field = input?.validate(
    today: today,
    serviceIds: serviceIds,
    creating: creating,
  );
  switch (field) {
    case null:
      break;
    case 'price':
      return RuleFormError.price;
    case 'weekdays':
      return RuleFormError.weekdays;
    case 'from':
      return RuleFormError.tooFar;
    case 'to':
      return RuleFormError.tooLong;
    default:
      // A field the form cannot get wrong (name length is capped by the
      // input); the server stays the authority.
      break;
  }
  if (creating &&
      (ruleCount >= kMaxRulesPerService ||
          (applyToAll && otherCounts.any((c) => c >= kMaxRulesPerService)))) {
    return RuleFormError.limit;
  }
  return null;
}

/// The error a failed save blames: the field the server named, else null
/// (the generic failure line).
RuleFormError? ruleFormErrorOfServer(PriceRuleError error) {
  switch (error.code) {
    case PriceRuleErrorCode.ruleLimit:
      return RuleFormError.limit;
    case PriceRuleErrorCode.exceptionLimit:
      return RuleFormError.exceptionLimit;
    case PriceRuleErrorCode.invalidArgument:
      return switch (error.field) {
        'price' => RuleFormError.price,
        'weekdays' => RuleFormError.weekdays,
        'from' => RuleFormError.tooFar,
        'to' => RuleFormError.tooLong,
        _ => null,
      };
    default:
      return null;
  }
}
