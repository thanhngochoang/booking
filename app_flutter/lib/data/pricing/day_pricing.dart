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

/// Every price is whole VND from 1 to this. The pricing itself lives in
/// `price_rules.dart`.
const kMaxPriceVnd = 1000000000;

/// The weekday of a calendar date: only year, month and day of [day] count,
/// never its time zone or time of day.
Weekday weekdayOf(DateTime day) =>
    Weekday.values[DateTime.utc(day.year, day.month, day.day).weekday - 1];
