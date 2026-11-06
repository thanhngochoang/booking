import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/day_pricing.dart'
    show Weekday, kMaxPriceVnd, weekdayOf;

/// Price series (#316, spec 2026-11-06-day-pricing-redesign R3/R5/R8/R9/R14).
/// Dart port of the backend's `packages/domain/src/day_pricing.ts` (pure
/// functions over plain rule objects named like the Firestore fields). Both run
/// the same case table (`test/data/contracts/day_pricing_cases.json`), so every
/// screen shows the price the server charges.
///
/// Days are UTC-midnight `DateTime`s (`calendarDay`, `parseDayKey`): only year,
/// month and day count, never a time zone. Rule fields keep the document's
/// strings (`yyyy-MM-dd`, `MM-dd`) and compare as strings, like the server.

enum PriceRepeat {
  none(3),
  yearly(2),
  weekly(1);

  const PriceRepeat(this.tier);

  /// R3: `none` beats `yearly` beats `weekly`.
  final int tier;

  static PriceRepeat? fromCode(Object? code) {
    for (final r in values) {
      if (r.name == code) {
        return r;
      }
    }
    return null;
  }
}

/// A closed range of calendar days.
typedef DayRange = ({DateTime from, DateTime to});

const kMaxRulesPerService = 30;
const kMaxExceptions = 50;
const kMaxSpanDays = 92;
const kMaxAheadDays = 730;
const _kMaxNameLength = 40;

/// One price series of a package (`photographers/{uid}/price_rules/{id}`).
final class PriceRule {
  const PriceRule({
    required this.id,
    required this.serviceId,
    required this.price,
    required this.repeat,
    this.name,
    this.lunar = false,
    this.from,
    this.to,
    this.weekdays = const {},
    this.start,
    this.until,
    this.exceptions = const {},
    this.template,
  });

  final String id;
  final String serviceId;
  final int price;
  final String? name;
  final PriceRepeat repeat;

  /// Only `yearly`: [from] and [to] are lunar month-days (main month).
  final bool lunar;

  /// `none`: `yyyy-MM-dd`. `yearly`: `MM-dd`, [to] before [from] crosses the
  /// year. `weekly`: null.
  final String? from;
  final String? to;
  final Set<Weekday> weekdays;
  final String? start;
  final String? until;

  /// `yyyy-MM-dd` to a price, or null to drop the day from the series. Other
  /// values are ignored when reading.
  final Map<String, Object?> exceptions;
  final String? template;

  /// Tolerant read of a stored document: unknown and server-only fields are
  /// dropped, null when the document is unusable.
  static PriceRule? tryParse(String id, Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final serviceId = raw['serviceId'];
    if (serviceId is! String || serviceId.isEmpty) {
      return null;
    }
    final price = _priceOf(raw['price']);
    final repeat = PriceRepeat.fromCode(raw['repeat']);
    if (price == null || repeat == null) {
      return null;
    }
    final name = raw['name'];
    var lunar = false;
    String? from;
    String? to;
    var weekdays = <Weekday>{};
    switch (repeat) {
      case PriceRepeat.weekly:
        final codes = raw['weekdays'];
        weekdays = {
          if (codes is List)
            for (final c in codes) ?Weekday.fromCode(c),
        };
        if (weekdays.isEmpty) {
          return null;
        }
      case PriceRepeat.none:
        final f = raw['from'];
        final t = raw['to'];
        if (f is! String || t is! String || !_isDay(f) || !_isDay(t)) {
          return null;
        }
        if (t.compareTo(f) < 0) {
          return null;
        }
        from = f;
        to = t;
      case PriceRepeat.yearly:
        lunar = raw['lunar'] == true;
        final f = raw['from'];
        final t = raw['to'];
        if (!_isMonthDay(f, lunar: lunar) || !_isMonthDay(t, lunar: lunar)) {
          return null;
        }
        from = f as String;
        to = t as String;
    }
    final start = raw['start'];
    final until = raw['until'];
    final exceptions = raw['exceptions'];
    final template = raw['template'];
    return PriceRule(
      id: id,
      serviceId: serviceId,
      price: price,
      repeat: repeat,
      name: name is String ? name : null,
      lunar: lunar,
      from: from,
      to: to,
      weekdays: weekdays,
      start: _isDay(start) ? start as String : null,
      until: _isDay(until) ? until as String : null,
      exceptions: exceptions is Map
          ? {for (final e in exceptions.entries) '${e.key}': e.value}
          : const {},
      template: template is String ? template : null,
    );
  }

  /// The document fields (not [id]); fields that are absent are left out.
  Map<String, Object?> toMap() => {
    'serviceId': serviceId,
    'price': price,
    'repeat': repeat.name,
    'name': ?name,
    if (lunar) 'lunar': true,
    'from': ?from,
    'to': ?to,
    if (weekdays.isNotEmpty) 'weekdays': [for (final w in weekdays) w.name],
    'start': ?start,
    'until': ?until,
    if (exceptions.isNotEmpty) 'exceptions': {...exceptions},
    'template': ?template,
  };
}

/// A package as the price functions see it.
final class PricedPackage {
  const PricedPackage({
    required this.id,
    required this.price,
    this.active = true,
  });

  final String id;
  final int price;
  final bool active;
}

/// The price of one day: the package price or the price of the winning rule.
final class DayPrice {
  const DayPrice(this.amount, {this.rule});

  final int amount;

  /// The rule that set [amount]; null for the package price.
  final PriceRule? rule;

  bool get isRule => rule != null;
}

// ---------------------------------------------------------------------------- helpers

final _monthDayRe = RegExp(r'^(\d{2})-(\d{2})$');
const _daysInMonthNonLeap = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/// Day of the year of the 1st of each month in a leap year (the longest span
/// any year can have).
const _leapYearMonthStart = [
  0,
  31,
  60,
  91,
  121,
  152,
  182,
  213,
  244,
  274,
  305,
  335,
];

DateTime _addDays(DateTime d, int n) =>
    DateTime.utc(d.year, d.month, d.day + n);

bool _isDay(Object? v) => v is String && parseDayKey(v) != null;

bool _isInt(Object? v) =>
    v is int || (v is double && v.isFinite && v == v.truncateToDouble());

/// An integer price from 1 to [kMaxPriceVnd], else null.
int? _priceOf(Object? v) {
  if (!_isInt(v)) {
    return null;
  }
  final n = (v! as num).toInt();
  return n >= 1 && n <= kMaxPriceVnd ? n : null;
}

/// `MM-dd` where the day exists in a non-leap year (solar) or is 1-30 (lunar).
bool _isMonthDay(Object? v, {required bool lunar}) {
  if (v is! String) {
    return false;
  }
  final m = _monthDayRe.firstMatch(v);
  if (m == null) {
    return false;
  }
  final month = int.parse(m.group(1)!);
  final d = int.parse(m.group(2)!);
  if (month < 1 || month > 12 || d < 1) {
    return false;
  }
  return d <= (lunar ? 30 : _daysInMonthNonLeap[month - 1]);
}

int _monthDayKey(String v) =>
    int.parse(v.substring(0, 2)) * 100 + int.parse(v.substring(3, 5));

/// The later of [a] and [b] (a day key), where [b] may be absent.
String _maxDay(String a, String? b) => b != null && b.compareTo(a) > 0 ? b : a;

// ---------------------------------------------------------------------------- ranges

/// Solar day of a lunar month-day of main month [month]; day 30 in a 29-day
/// month is the last day.
DateTime _lunarMainDayToSolar(int day, int month, int year) {
  final len = lunarMonthLength(month, year);
  final solar = lunarToSolar(day < len ? day : len, month, year);
  if (solar == null) {
    throw ArgumentError.value(month, 'month', 'no such lunar month');
  }
  return solar;
}

/// Solar span of the leap month of a lunar year, or null when it has none.
DayRange? _leapSpan(int lunarYear) {
  final leap = leapMonthOf(lunarYear);
  if (leap == null) {
    return null;
  }
  final from = lunarToSolar(1, leap, lunarYear, leap: true);
  if (from == null) {
    return null;
  }
  return (
    from: from,
    to: _addDays(from, lunarMonthLength(leap, lunarYear, leap: true) - 1),
  );
}

List<DayRange> _minus(List<DayRange> ranges, DayRange cut) {
  final out = <DayRange>[];
  for (final r in ranges) {
    if (r.to.isBefore(cut.from) || r.from.isAfter(cut.to)) {
      out.add(r);
      continue;
    }
    if (r.from.isBefore(cut.from)) {
      out.add((from: r.from, to: _addDays(cut.from, -1)));
    }
    if (r.to.isAfter(cut.to)) {
      out.add((from: _addDays(cut.to, 1), to: r.to));
    }
  }
  return out;
}

DateTime _monthDayIn(int year, String monthDay) => DateTime.utc(
  year,
  int.parse(monthDay.substring(0, 2)),
  int.parse(monthDay.substring(3, 5)),
);

/// Solar ranges of a rule in a Gregorian [year]. `yearly`: 1-2 ranges (solar
/// crossing 31/12 gives two; lunar is converted from the lunar years that
/// overlap [year], leap-month days cut out, clipped to the year). `none`: the
/// whole range when it touches the year. `weekly`: none (not range based).
List<DayRange> ruleRanges(PriceRule rule, int year) {
  final from = rule.from;
  final to = rule.to;
  if (rule.repeat == PriceRepeat.weekly || from == null || to == null) {
    return [];
  }
  final first = DateTime.utc(year);
  final last = DateTime.utc(year, 12, 31);
  if (rule.repeat == PriceRepeat.none) {
    final f = parseDayKey(from);
    final t = parseDayKey(to);
    if (f == null || t == null) {
      return [];
    }
    return !f.isAfter(last) && !t.isBefore(first) ? [(from: f, to: t)] : [];
  }
  if (!rule.lunar) {
    if (_monthDayKey(to) < _monthDayKey(from)) {
      return [
        (from: first, to: _monthDayIn(year, to)),
        (from: _monthDayIn(year, from), to: last),
      ];
    }
    return [(from: _monthDayIn(year, from), to: _monthDayIn(year, to))];
  }
  final fm = int.parse(from.substring(0, 2));
  final fd = int.parse(from.substring(3, 5));
  final tm = int.parse(to.substring(0, 2));
  final td = int.parse(to.substring(3, 5));
  final wraps = _monthDayKey(to) < _monthDayKey(from);
  final out = <DayRange>[];
  for (final ly in [year - 1, year]) {
    final endYear = wraps ? ly + 1 : ly;
    var pieces = [
      (
        from: _lunarMainDayToSolar(fd, fm, ly),
        to: _lunarMainDayToSolar(td, tm, endYear),
      ),
    ];
    for (final y in endYear == ly ? [ly] : [ly, endYear]) {
      final cut = _leapSpan(y);
      if (cut != null) {
        pieces = _minus(pieces, cut);
      }
    }
    for (final p in pieces) {
      final clipped = (
        from: p.from.isBefore(first) ? first : p.from,
        to: p.to.isAfter(last) ? last : p.to,
      );
      if (!clipped.from.isAfter(clipped.to)) {
        out.add(clipped);
      }
    }
  }
  out.sort((a, b) => a.from.compareTo(b.from));
  return out;
}

// ---------------------------------------------------------------------------- one day

bool _within(int key, int from, int to) =>
    from <= to ? key >= from && key <= to : key >= from || key <= to;

bool _patternCovers(
  PriceRule rule,
  DateTime day,
  String key,
  LunarDate? lunar,
) {
  switch (rule.repeat) {
    case PriceRepeat.weekly:
      return rule.weekdays.contains(weekdayOf(day));
    case PriceRepeat.none:
      final from = rule.from;
      final to = rule.to;
      return from != null &&
          to != null &&
          from.compareTo(key) <= 0 &&
          key.compareTo(to) <= 0;
    case PriceRepeat.yearly:
      final from = rule.from;
      final to = rule.to;
      if (from == null || to == null) {
        return false;
      }
      if (!rule.lunar) {
        return _within(
          day.month * 100 + day.day,
          _monthDayKey(from),
          _monthDayKey(to),
        );
      }
      final l = lunar ?? solarToLunar(day);
      if (l.leap) {
        return false;
      }
      var fromKey = _monthDayKey(from);
      // A from-day 30 in a 29-day month means the last day of that month.
      if (l.day == 29 &&
          l.month == int.parse(from.substring(0, 2)) &&
          int.parse(from.substring(3, 5)) == 30 &&
          lunarMonthLength(l.month, l.year) == 29) {
        fromKey = l.month * 100 + 29;
      }
      return _within(l.month * 100 + l.day, fromKey, _monthDayKey(to));
  }
}

/// Whether [rule] covers [day] after `start`/`until` and exceptions, and at
/// which price. Pass the day's [lunar] date (from `solarToLunar`) when checking
/// many rules so it is converted once.
({bool covers, int? price}) ruleCoversDay(
  PriceRule rule,
  DateTime day, {
  LunarDate? lunar,
}) {
  const no = (covers: false, price: null);
  final key = dayKeyOf(day);
  final start = rule.start;
  final until = rule.until;
  if (start != null && key.compareTo(start) < 0) {
    return no;
  }
  if (until != null && key.compareTo(until) > 0) {
    return no;
  }
  if (rule.exceptions.containsKey(key)) {
    final v = rule.exceptions[key];
    if (v == null) {
      return no;
    }
    final price = _priceOf(v);
    if (price != null) {
      return (covers: true, price: price);
    }
  }
  return _patternCovers(rule, day, key, lunar)
      ? (covers: true, price: rule.price)
      : no;
}

/// R3: of the package's rules covering [day], the highest tier (`none` >
/// `yearly` > `weekly`) wins, then the highest price, then the earlier rule in
/// [rules]; no rule means [basePrice].
DayPrice priceForDay(
  int basePrice,
  String serviceId,
  List<PriceRule> rules,
  DateTime day,
) {
  LunarDate? lunar;
  PriceRule? best;
  var bestTier = 0;
  var bestPrice = 0;
  for (final rule in rules) {
    if (rule.serviceId != serviceId) {
      continue;
    }
    if (rule.repeat == PriceRepeat.yearly && rule.lunar) {
      lunar ??= solarToLunar(day);
    }
    final c = ruleCoversDay(rule, day, lunar: lunar);
    final price = c.price;
    if (!c.covers || price == null) {
      continue;
    }
    final tier = rule.repeat.tier;
    if (best == null ||
        tier > bestTier ||
        (tier == bestTier && price > bestPrice)) {
      best = rule;
      bestTier = tier;
      bestPrice = price;
    }
  }
  return best == null ? DayPrice(basePrice) : DayPrice(bestPrice, rule: best);
}

/// Every day of a month with its price, for the calendar cells (oldest first).
Map<DateTime, DayPrice> monthPrices(
  int basePrice,
  String serviceId,
  List<PriceRule> rules,
  int year,
  int month,
) {
  final days = DateTime.utc(year, month + 1, 0).day;
  return {
    for (var d = 1; d <= days; d++)
      DateTime.utc(year, month, d): priceForDay(
        basePrice,
        serviceId,
        rules,
        DateTime.utc(year, month, d),
      ),
  };
}

// ---------------------------------------------------------------------------- what is still ahead

/// The range the rule is running in or will run in next (not clipped,
/// exceptions ignored), null once it has ended: a `none` rule whose `to`
/// passed, an `until` that passed, or no matching day left before `until`.
/// `weekly` returns the next matching day as a one-day range.
DayRange? nextOccurrence(PriceRule rule, DateTime today) {
  final todayKey = dayKeyOf(today);
  final until = rule.until;
  if (until != null && until.compareTo(todayKey) < 0) {
    return null;
  }
  final loKey = _maxDay(todayKey, rule.start);
  final lo = parseDayKey(loKey);
  if (lo == null) {
    return null;
  }
  switch (rule.repeat) {
    case PriceRepeat.weekly:
      for (var i = 0; i < 7; i++) {
        final d = _addDays(lo, i);
        if (until != null && dayKeyOf(d).compareTo(until) > 0) {
          return null;
        }
        if (rule.weekdays.contains(weekdayOf(d))) {
          return (from: d, to: d);
        }
      }
      return null;
    case PriceRepeat.none:
      final from = rule.from;
      final to = rule.to;
      if (from == null || to == null || to.compareTo(loKey) < 0) {
        return null;
      }
      if (until != null && from.compareTo(until) > 0) {
        return null;
      }
      final f = parseDayKey(from);
      final t = parseDayKey(to);
      return f == null || t == null ? null : (from: f, to: t);
    case PriceRepeat.yearly:
      for (final year in [lo.year, lo.year + 1]) {
        for (final r in ruleRanges(rule, year)) {
          if (r.to.isBefore(lo)) {
            continue;
          }
          if (until != null && dayKeyOf(r.from).compareTo(until) > 0) {
            return null;
          }
          return r;
        }
      }
      return null;
  }
}

/// Lowest and highest price a package can have from [today] on: its
/// [basePrice] and the price of every rule that still has an occurrence, with
/// the exception prices that are still ahead (R9).
({int min, int max}) priceBounds(
  int basePrice,
  String serviceId,
  List<PriceRule> rules,
  DateTime today,
) {
  final todayKey = dayKeyOf(today);
  var min = basePrice;
  var max = basePrice;
  void take(int price) {
    if (price < min) {
      min = price;
    }
    if (price > max) {
      max = price;
    }
  }

  for (final rule in rules) {
    if (rule.serviceId != serviceId || nextOccurrence(rule, today) == null) {
      continue;
    }
    take(rule.price);
    final start = rule.start;
    final until = rule.until;
    for (final e in rule.exceptions.entries) {
      final v = _priceOf(e.value);
      if (v == null || !_isDay(e.key) || e.key.compareTo(todayKey) < 0) {
        continue;
      }
      if ((start != null && e.key.compareTo(start) < 0) ||
          (until != null && e.key.compareTo(until) > 0)) {
        continue;
      }
      take(v);
    }
  }
  return (min: min, max: max);
}

/// R9: the lowest price over the active packages (`price` and every rule still
/// ahead), null with none active.
int? startingPrice(
  List<PricedPackage> services,
  List<PriceRule> rules,
  DateTime today,
) {
  int? best;
  for (final s in services) {
    if (!s.active) {
      continue;
    }
    final min = priceBounds(s.price, s.id, rules, today).min;
    if (best == null || min < best) {
      best = min;
    }
  }
  return best;
}

// ---------------------------------------------------------------------------- editing

PriceRule _copyOf(
  PriceRule r, {
  String? id,
  String? serviceId,
  int? price,
  String? start,
  String? until,
  required Map<String, Object?> exceptions,
}) => PriceRule(
  id: id ?? r.id,
  serviceId: serviceId ?? r.serviceId,
  price: price ?? r.price,
  repeat: r.repeat,
  name: r.name,
  lunar: r.lunar,
  from: r.from,
  to: r.to,
  weekdays: r.weekdays,
  start: start ?? r.start,
  until: until ?? r.until,
  exceptions: exceptions,
  template: r.template,
);

/// "This and the following days" (R4): `before` is the old series ending the
/// day before [day] (it never ends later than it did), `after` the same series
/// from [day] at [newPrice] (null = the series just ends). Exceptions on or
/// after [day] move to `after`. When [day] is on or before the series' first
/// day the caller deletes `before` instead of saving an empty series.
({PriceRule before, PriceRule? after}) splitRule(
  PriceRule rule,
  DateTime day,
  int? newPrice,
  String newId,
) {
  final dayKey = dayKeyOf(day);
  final before = <String, Object?>{};
  final after = <String, Object?>{};
  for (final e in rule.exceptions.entries) {
    (e.key.compareTo(dayKey) < 0 ? before : after)[e.key] = e.value;
  }
  final lastDay = dayKeyOf(_addDays(day, -1));
  final until = rule.until;
  final old = _copyOf(
    rule,
    until: until != null && until.compareTo(lastDay) < 0 ? until : lastDay,
    exceptions: before,
  );
  if (newPrice == null) {
    return (before: old, after: null);
  }
  return (
    before: old,
    after: _copyOf(
      rule,
      id: newId,
      price: newPrice,
      start: _maxDay(dayKey, rule.start),
      exceptions: after,
    ),
  );
}

/// Sets [price] on [day] of the series; null removes the day from the series.
/// The cap ([kMaxExceptions]) is the caller's.
PriceRule withException(PriceRule rule, DateTime day, int? price) =>
    _copyOf(rule, exceptions: {...rule.exceptions, dayKeyOf(day): price});

/// Removes the exception of [day] so the series covers it as usual.
PriceRule clearException(PriceRule rule, DateTime day) {
  final key = dayKeyOf(day);
  return _copyOf(
    rule,
    exceptions: {
      for (final e in rule.exceptions.entries)
        if (e.key != key) e.key: e.value,
    },
  );
}

// ---------------------------------------------------------------------------- R8

/// R8 "all packages, same ratio": `ceil(toPrice x input / fromPrice / 10.000)
/// x 10.000`, capped at 1.000.000.000. BigInt keeps the product exact where
/// `int` is a double (web).
int scaledPrice(int input, int fromPrice, int toPrice) {
  if (_priceOf(input) == null ||
      _priceOf(fromPrice) == null ||
      _priceOf(toPrice) == null) {
    throw ArgumentError.value(
      (input, fromPrice, toPrice),
      'price',
      'must be 1..$kMaxPriceVnd',
    );
  }
  final numerator = BigInt.from(toPrice) * BigInt.from(input);
  final denominator = BigInt.from(fromPrice) * BigInt.from(10000);
  final scaled =
      ((numerator + denominator - BigInt.one) ~/ denominator) *
      BigInt.from(10000);
  return scaled > BigInt.from(kMaxPriceVnd) ? kMaxPriceVnd : scaled.toInt();
}

/// The same series for another package; the price is scaled and exceptions are
/// not copied.
PriceRule scaledRule(
  PriceRule rule,
  PricedPackage from,
  PricedPackage to,
  String newId,
) => _copyOf(
  rule,
  id: newId,
  serviceId: to.id,
  price: scaledPrice(rule.price, from.price, to.price),
  exceptions: const {},
);

// ---------------------------------------------------------------------------- writing

/// Month-day span in days, counting Feb as 29 so it never under-counts; lunar
/// months count as 30 days.
int _yearlySpanDays(String from, String to, {required bool lunar}) {
  int key(String v) {
    final m = int.parse(v.substring(0, 2));
    final d = int.parse(v.substring(3, 5));
    return lunar ? m * 30 + d : _leapYearMonthStart[m - 1] + d;
  }

  final year = lunar ? 360 : 366;
  return (((key(to) - key(from)) % year) + year) % year + 1;
}

bool _isWeekdayCode(Object? v) => Weekday.fromCode(v) != null;

/// The first field of a rule draft that is unusable, null when it is valid, for
/// inline errors. [rule] is the document map (`PriceRule.toMap()`, or whatever a
/// form collected: values of the wrong type name their field). The counts
/// ([kMaxRulesPerService], [kMaxExceptions]) are checked by the caller, which
/// knows the other rules.
String? validatePriceRuleField(
  Map<String, Object?> rule, {
  required DateTime today,
  required List<String> serviceIds,
  required bool creating,
}) {
  final price = rule['price'];
  if (_priceOf(price) == null) {
    return 'price';
  }
  if (rule.containsKey('name')) {
    final name = rule['name'];
    if (name is! String || name.length > _kMaxNameLength) {
      return 'name';
    }
  }
  final repeat = PriceRepeat.fromCode(rule['repeat']);
  if (repeat == null) {
    return 'repeat';
  }
  final serviceId = rule['serviceId'];
  if (serviceId is! String || !serviceIds.contains(serviceId)) {
    return 'serviceId';
  }
  final lunarValue = rule['lunar'];
  if (rule.containsKey('lunar') &&
      (lunarValue is! bool || (lunarValue && repeat != PriceRepeat.yearly))) {
    return 'lunar';
  }
  final from = rule['from'];
  final to = rule['to'];
  if (repeat == PriceRepeat.weekly) {
    final w = rule['weekdays'];
    if (w is! List ||
        w.isEmpty ||
        w.length > 7 ||
        !w.every(_isWeekdayCode) ||
        w.toSet().length != w.length) {
      return 'weekdays';
    }
    if (rule.containsKey('from')) {
      return 'from';
    }
    if (rule.containsKey('to')) {
      return 'to';
    }
  } else {
    if (rule.containsKey('weekdays')) {
      return 'weekdays';
    }
    if (repeat == PriceRepeat.none) {
      final fromDay = from is String ? parseDayKey(from) : null;
      if (fromDay == null) {
        return 'from';
      }
      final toDay = to is String ? parseDayKey(to) : null;
      if (toDay == null || toDay.isBefore(fromDay)) {
        return 'to';
      }
      if (creating && toDay.isBefore(calendarDay(today))) {
        return 'to';
      }
      if (fromDay.isAfter(_addDays(today, kMaxAheadDays))) {
        return 'from';
      }
      if (toDay.difference(fromDay).inDays + 1 > kMaxSpanDays) {
        return 'to';
      }
    } else {
      final lunar = lunarValue == true;
      if (!_isMonthDay(from, lunar: lunar)) {
        return 'from';
      }
      if (!_isMonthDay(to, lunar: lunar)) {
        return 'to';
      }
      if (_yearlySpanDays(from! as String, to! as String, lunar: lunar) >
          kMaxSpanDays) {
        return 'to';
      }
    }
  }
  final start = rule['start'];
  final until = rule['until'];
  if (rule.containsKey('start') && !_isDay(start)) {
    return 'start';
  }
  if (rule.containsKey('until') && !_isDay(until)) {
    return 'until';
  }
  if (rule.containsKey('start') &&
      rule.containsKey('until') &&
      (until! as String).compareTo(start! as String) < 0) {
    return 'until';
  }
  if (rule.containsKey('exceptions')) {
    final ex = rule['exceptions'];
    if (ex is! Map) {
      return 'exceptions';
    }
    for (final e in ex.entries) {
      if (!_isDay(e.key) || (e.value != null && _priceOf(e.value) == null)) {
        return 'exceptions';
      }
    }
  }
  if (rule.containsKey('template') && rule['template'] is! String) {
    return 'template';
  }
  return null;
}

// ---------------------------------------------------------------------------- templates (spec §4.3, R11)

enum PriceRuleGroup { holiday, occasion }

/// A ready-made yearly rule offered when adding a series.
final class PriceRuleTemplate {
  const PriceRuleTemplate(
    this.code,
    this.name, {
    required this.lunar,
    required this.from,
    required this.to,
    required this.group,
  });

  final String code;
  final String name;
  final bool lunar;
  final String from;
  final String to;
  final PriceRuleGroup group;
}

/// The same 11 entries, in the same order, as the backend's
/// `PRICE_RULE_TEMPLATES`.
const priceRuleTemplates = <PriceRuleTemplate>[
  PriceRuleTemplate(
    'tet',
    'Tết Nguyên đán',
    lunar: true,
    from: '12-23',
    to: '01-05',
    group: PriceRuleGroup.holiday,
  ),
  PriceRuleTemplate(
    'hung_kings',
    'Giỗ Tổ Hùng Vương',
    lunar: true,
    from: '03-10',
    to: '03-10',
    group: PriceRuleGroup.holiday,
  ),
  PriceRuleTemplate(
    'new_year',
    'Tết Dương lịch',
    lunar: false,
    from: '01-01',
    to: '01-01',
    group: PriceRuleGroup.holiday,
  ),
  PriceRuleTemplate(
    'reunification',
    '30/4 – 1/5',
    lunar: false,
    from: '04-30',
    to: '05-01',
    group: PriceRuleGroup.holiday,
  ),
  PriceRuleTemplate(
    'national_day',
    'Quốc khánh',
    lunar: false,
    from: '09-02',
    to: '09-02',
    group: PriceRuleGroup.holiday,
  ),
  PriceRuleTemplate(
    'valentine',
    'Valentine',
    lunar: false,
    from: '02-14',
    to: '02-14',
    group: PriceRuleGroup.occasion,
  ),
  PriceRuleTemplate(
    'womens_day',
    '8/3',
    lunar: false,
    from: '03-08',
    to: '03-08',
    group: PriceRuleGroup.occasion,
  ),
  PriceRuleTemplate(
    'mid_autumn',
    'Trung thu',
    lunar: true,
    from: '08-15',
    to: '08-15',
    group: PriceRuleGroup.occasion,
  ),
  PriceRuleTemplate(
    'vn_womens_day',
    '20/10',
    lunar: false,
    from: '10-20',
    to: '10-20',
    group: PriceRuleGroup.occasion,
  ),
  PriceRuleTemplate(
    'christmas',
    'Noel',
    lunar: false,
    from: '12-24',
    to: '12-25',
    group: PriceRuleGroup.occasion,
  ),
  PriceRuleTemplate(
    'wedding_season',
    'Mùa cưới',
    lunar: false,
    from: '10-15',
    to: '12-31',
    group: PriceRuleGroup.occasion,
  ),
];
