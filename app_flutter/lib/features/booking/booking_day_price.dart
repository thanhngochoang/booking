import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// How the booking flow words a package's price by day (S04.01-S04.03, #316).

String _short(int v) => formatMoney(v, short: true);

/// S04.01 right-hand price: one price in full, else the weekday range
/// "1,5M–1,8M" (the special price is not part of it, P6).
String packageTilePrice(AppLocalizations l, PricedService p) {
  final (:min, :max) = priceRange(p);
  return min == max
      ? formatMoney(min)
      : l.s0401_priceRange(_short(min), _short(max));
}

/// S04.01 sub-line of a package: "T7–CN 1,8M", "giá theo ngày", or null when
/// the weekday prices are the same.
String? packageTileSub(AppLocalizations l, PricedService p) =>
    switch (priceSummary(p)) {
      SinglePrice() => null,
      TwoLevelPrice(:final weekend) => l.s0401_weekendSub(_short(weekend)),
      PerDayPrice() => l.s0401_perDaySub,
    };

/// "Tiếp tục · {price}" of S04.01 and S04.02; "Tiếp tục · từ {price}" while
/// the package's price still depends on a day.
String continueLabel(AppLocalizations l, BookingFlowState s) {
  final total = formatMoney(s.totalVnd ?? 0);
  return s.priceIsFrom
      ? l.s0401_continueFrom(total)
      : l.bookContinuePrice(total);
}

/// The calendar notes of [month]: the short price under every day whose price
/// differs from [PricedService.price] (the weekday price), and "Lễ {price}"
/// under a special day. Nothing for a package with one price.
Map<DateTime, ({String text, bool accent})> dayPriceNotes(
  AppLocalizations l,
  PricedService p,
  DateTime month,
  SpecialDays special,
) {
  if (!pricesVaryByDay(p)) {
    return const {};
  }
  final notes = <DateTime, ({String text, bool accent})>{};
  final last = DateTime.utc(month.year, month.month + 1, 0).day;
  for (var d = 1; d <= last; d++) {
    final day = DateTime.utc(month.year, month.month, d);
    final priced = priceForDay(p, day, special);
    if (priced.kind == DayPriceKind.special) {
      notes[day] = (
        text: l.s0402_holidayPrice(_short(priced.amount)),
        accent: true,
      );
    } else if (priced.amount != p.price) {
      notes[day] = (text: _short(priced.amount), accent: false);
    }
  }
  return notes;
}

/// "cuối tuần" or "ngày lễ: {name}" after the day on S04.02; null for a
/// weekday or a package with one price.
String? dayTag(AppLocalizations l, BookingFlowState s) {
  final p = s.pricing;
  final priced = s.dayPrice;
  if (p == null || priced == null || !pricesVaryByDay(p)) {
    return null;
  }
  return switch (priced.kind) {
    DayPriceKind.weekday => null,
    DayPriceKind.weekend => l.s0402_weekendTag,
    DayPriceKind.special => l.s0402_holidayTag(priced.specialName ?? ''),
  };
}

/// The package line of S04.03: "Gói {name} · T7 14/11 (cuối tuần)". A package
/// with one price keeps "Gói {name}".
String packageLine(AppLocalizations l, BookingFlowState s) {
  final name = s.serviceName ?? '';
  final p = s.pricing;
  final priced = s.dayPrice;
  final key = s.day;
  final date = key == null ? null : parseDayKey(key);
  if (p == null || priced == null || date == null || !pricesVaryByDay(p)) {
    return l.bookPackageLine(name);
  }
  final day = formatDay(date);
  final reason = switch (priced.kind) {
    DayPriceKind.weekday => '',
    DayPriceKind.weekend => ' ${l.s0403_dayReasonWeekend}',
    DayPriceKind.special =>
      ' ${l.s0403_dayReasonSpecial(priced.specialName ?? '')}',
  };
  return '${l.s0403_packageDay(name, day)}$reason';
}
