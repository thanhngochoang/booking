import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';

/// Price per weekday, special days and the price shown for a package
/// (S08.08-S08.10, #316). Dart port of the backend's `day_pricing.ts`; both
/// run the same case table (`test/data/contracts/day_pricing_cases.json`).

/// Weekdays in ISO order, Monday first.
enum Weekday {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  bool get isWeekend => this == sat || this == sun;

  static Weekday? fromCode(Object? code) {
    for (final w in values) {
      if (w.name == code) {
        return w;
      }
    }
    return null;
  }
}

/// Every price is whole VND from 1 to this.
const kMaxPriceVnd = 1000000000;

/// The weekday of a calendar date: only year, month and day of [day] count,
/// never its time zone or time of day.
Weekday weekdayOf(DateTime day) =>
    Weekday.values[DateTime.utc(day.year, day.month, day.day).weekday - 1];

/// The weekday of a `yyyy-MM-dd` day; null when it is not a real date.
Weekday? weekdayOfKey(String key) {
  final d = parseDayKey(key);
  return d == null ? null : weekdayOf(d);
}

/// What the price of a day depends on. `ServicePackage` implements it.
@immutable
class PricedService {
  const PricedService({required this.price, this.dayPrices, this.specialPrice});

  /// The weekday price, and the price of all 7 days without [dayPrices].
  final int price;
  final Map<Weekday, int>? dayPrices;
  final int? specialPrice;
}

/// Public holidays and the provider's own ranges, all `yyyy-MM-dd`.
@immutable
class SpecialDays {
  const SpecialDays({this.holidays = const [], this.ranges = const []});

  final List<String> holidays;

  /// Inclusive `(from, to)` ranges.
  final List<({String from, String to})> ranges;

  bool contains(String day) =>
      holidays.contains(day) ||
      ranges.any((r) => r.from.compareTo(day) <= 0 && day.compareTo(r.to) <= 0);
}

const noSpecialDays = SpecialDays();

enum DayPriceKind { weekday, weekend, special }

/// The price of each weekday: `dayPrices`, or `price` for all 7 days.
Map<Weekday, int> weekPrices(PricedService s) => {
  for (final w in Weekday.values) w: s.dayPrices?[w] ?? s.price,
};

/// The price of [day] (a calendar date) and why. A package's `specialPrice`
/// wins on special days; otherwise the weekday's price.
({int amount, DayPriceKind kind}) priceForDay(
  PricedService s,
  DateTime day,
  SpecialDays special,
) {
  if (s.specialPrice != null && special.contains(dayKeyOf(day))) {
    return (amount: s.specialPrice!, kind: DayPriceKind.special);
  }
  final w = weekdayOf(day);
  return (
    amount: weekPrices(s)[w]!,
    kind: w.isWeekend ? DayPriceKind.weekend : DayPriceKind.weekday,
  );
}

/// [priceForDay] for a `yyyy-MM-dd` day.
({int amount, DayPriceKind kind}) priceForDayKey(
  PricedService s,
  String day,
  SpecialDays special,
) {
  final d = parseDayKey(day);
  if (d == null) {
    throw ArgumentError.value(day, 'day', 'not a yyyy-MM-dd date');
  }
  return priceForDay(s, d, special);
}

/// Lowest and highest weekday price; `specialPrice` is never part of it.
({int min, int max}) priceRange(PricedService s) {
  final all = weekPrices(s).values;
  return (
    min: all.reduce((a, b) => a < b ? a : b),
    max: all.reduce((a, b) => a > b ? a : b),
  );
}

/// How a package's price reads on a card or a line.
sealed class PriceSummary {
  const PriceSummary({required this.min, required this.max, this.special});

  final int min;
  final int max;
  final int? special;
}

/// All 7 days cost the same.
class SinglePrice extends PriceSummary {
  const SinglePrice({required super.min, required super.max, super.special});
}

/// Monday to Friday cost [weekday]; Saturday and Sunday cost [weekend].
class TwoLevelPrice extends PriceSummary {
  const TwoLevelPrice({
    required this.weekday,
    required this.weekend,
    required super.min,
    required super.max,
    super.special,
  });

  final int weekday;
  final int weekend;
}

class PerDayPrice extends PriceSummary {
  const PerDayPrice({required super.min, required super.max, super.special});
}

PriceSummary priceSummary(PricedService s) {
  final w = weekPrices(s);
  final (:min, :max) = priceRange(s);
  final special = s.specialPrice;
  if (min == max) {
    return SinglePrice(min: min, max: max, special: special);
  }
  final weekdaysEqual = [
    Weekday.tue,
    Weekday.wed,
    Weekday.thu,
    Weekday.fri,
  ].every((d) => w[d] == w[Weekday.mon]);
  if (weekdaysEqual && w[Weekday.sat] == w[Weekday.sun]) {
    return TwoLevelPrice(
      weekday: w[Weekday.mon]!,
      weekend: w[Weekday.sat]!,
      min: min,
      max: max,
      special: special,
    );
  }
  return PerDayPrice(min: min, max: max, special: special);
}

/// `price` = Monday; `dayPrices` is null when all 7 are equal (one price).
({int price, Map<Weekday, int>? dayPrices}) normalizeDayPrices(
  Map<Weekday, int> p,
) {
  final mon = p[Weekday.mon]!;
  final allEqual = Weekday.values.every((w) => p[w] == mon);
  return (price: mon, dayPrices: allEqual ? null : Map.of(p));
}

/// Reads a Firestore `dayPrices` map: exactly the 7 weekday keys with whole
/// VND values, else null.
Map<Weekday, int>? dayPricesFromMap(Object? raw) {
  if (raw is! Map || raw.length != Weekday.values.length) {
    return null;
  }
  final out = <Weekday, int>{};
  for (final w in Weekday.values) {
    final v = raw[w.name];
    if (v is! num || v != v.toInt() || v < 1 || v > kMaxPriceVnd) {
      return null;
    }
    out[w] = v.toInt();
  }
  return out;
}

Map<String, int> dayPricesToMap(Map<Weekday, int> p) => {
  for (final w in Weekday.values) w.name: p[w]!,
};
