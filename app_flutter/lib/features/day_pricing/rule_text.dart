import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show kMaxPriceVnd;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_draft.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The words of a price series, shared by S08.10 (card and list), the day
/// sheet and S08.09's read-only card (spec §5.3, §5.6; mock `#S08.10`,
/// `#S08.10-list`). Days are written the short way the mock does: `14/11`,
/// `T7 14/11`, no leading zeros.

/// `14/11`.
String dayMonthText(DateTime d) => '${d.day}/${d.month}';

/// `T7 14/11`, or `T7 14/11/2026` with [year].
String weekdayDayText(DateTime d, {bool year = false}) =>
    '${weekdayLabel(d.weekday)} ${dayMonthText(d)}${year ? '/${d.year}' : ''}';

/// `T4 3/11 – T5 11/11/2027`: the year closes the range, and opens it too
/// when the two days are in different years. One day is `T4 3/11/2027`.
String dayRangeText(DateTime from, DateTime to) {
  if (from == to) {
    return weekdayDayText(from, year: true);
  }
  return '${weekdayDayText(from, year: from.year != to.year)} – '
      '${weekdayDayText(to, year: true)}';
}

/// An `MM-dd` of a yearly rule as `14/11`; on the lunar calendar the 12th
/// month is "Chạp" and the 1st "Giêng" (`23 Chạp`, `5 Giêng`).
String monthDayText(AppLocalizations l, String key, {required bool lunar}) {
  final md = monthDayOf(key);
  if (lunar && md.month == 12) {
    return l.s0810_lunarMonthTwelve('${md.day}');
  }
  if (lunar && md.month == 1) {
    return l.s0810_lunarMonthOne('${md.day}');
  }
  return '${md.day}/${md.month}';
}

/// The exceptions of [rule] that count (a price from 1 to 1e9, or null for a
/// dropped day), oldest day first. Other values are ignored, as in pricing.
List<({DateTime day, int? price})> ruleExceptions(PriceRule rule) {
  final out = <({DateTime day, int? price})>[];
  for (final e in rule.exceptions.entries) {
    final day = parseDayKey(e.key);
    if (day == null) {
      continue;
    }
    final v = e.value;
    if (v == null) {
      out.add((day: day, price: null));
    } else if (v is num && v == v.toInt() && v >= 1 && v <= kMaxPriceVnd) {
      out.add((day: day, price: v.toInt()));
    }
  }
  out.sort((a, b) => a.day.compareTo(b.day));
  return out;
}

/// The name of the series, "Giá riêng" when it has none.
String ruleTitle(AppLocalizations l, PriceRule rule) {
  final name = rule.name?.trim();
  return name == null || name.isEmpty ? l.s0810_unnamed : name;
}

/// "Hằng tuần · T7, CN", "Hằng năm · 14/11 – 22/11", "Hằng năm · 23 Chạp –
/// 5 Giêng (âm lịch)" or "Một lần · T7 14/3 – CN 15/3/2027".
String rulePattern(AppLocalizations l, PriceRule rule) {
  switch (rule.repeat) {
    case PriceRepeat.weekly:
      final days = [
        for (final w
            in rule.weekdays.toList()
              ..sort((a, b) => a.index.compareTo(b.index)))
          l.calendarWeekdayShort(w.name),
      ];
      return l.s0810_ruleWeekly(days.join(', '));
    case PriceRepeat.yearly:
      final from = rule.from;
      final to = rule.to;
      if (from == null || to == null) {
        return l.s0810_yearly;
      }
      final a = monthDayText(l, from, lunar: rule.lunar);
      final b = monthDayText(l, to, lunar: rule.lunar);
      if (from == to) {
        return rule.lunar
            ? l.s0810_ruleYearlyLunarDay(a)
            : l.s0810_ruleYearlyDay(a);
      }
      return rule.lunar
          ? l.s0810_ruleYearlyLunar(a, b)
          : l.s0810_ruleYearly(a, b);
    case PriceRepeat.none:
      final from = rule.from == null ? null : parseDayKey(rule.from!);
      final to = rule.to == null ? null : parseDayKey(rule.to!);
      if (from == null || to == null) {
        return l.s0810_ruleOnceDay('–');
      }
      if (from == to) {
        return l.s0810_ruleOnceDay(weekdayDayText(from, year: true));
      }
      return l.s0810_ruleOnce(
        weekdayDayText(from, year: from.year != to.year),
        weekdayDayText(to, year: true),
      );
  }
}

/// The count of exceptions, with them spelled out ("CN 15/11: 1,5M") when
/// [detail] and there are at most two; null when there are none.
String? ruleExceptionsText(
  AppLocalizations l,
  PriceRule rule, {
  bool detail = false,
}) {
  final list = ruleExceptions(rule);
  if (list.isEmpty) {
    return null;
  }
  if (!detail || list.length > 2) {
    return l.s0810_exceptions(list.length);
  }
  final parts = [
    for (final e in list)
      e.price == null
          ? l.s0810_exceptionSkip(weekdayDayText(e.day))
          : l.s0810_exceptionPrice(
              weekdayDayText(e.day),
              formatMoney(e.price!, short: true),
            ),
  ];
  return l.s0810_exceptionsDetail(list.length, parts.join('; '));
}

/// "lần tới T7 30/1 – T4 10/2/2027" for a yearly series on the lunar
/// calendar (the solar days move every year), else null.
String? ruleNextText(AppLocalizations l, PriceRule rule, DateTime today) {
  final from = rule.from;
  final to = rule.to;
  if (rule.repeat != PriceRepeat.yearly ||
      !rule.lunar ||
      from == null ||
      to == null) {
    return null;
  }
  final next = nextYearlyOccurrence(
    from: from,
    to: to,
    lunar: true,
    today: today,
  );
  return next == null
      ? null
      : l.s0810_nextOccurrence(dayRangeText(next.from, next.to));
}

/// The second line of a series row: the pattern, the exceptions and, in the
/// list ([withNext]), when a lunar series comes next.
///
/// A5 uses this for S08.09's card: `ruleTitle` over `ruleSummary`.
String ruleSummary(
  AppLocalizations l,
  PriceRule rule, {
  DateTime? today,
  bool detail = false,
  bool withNext = false,
}) {
  final parts = [
    rulePattern(l, rule),
    ?ruleExceptionsText(l, rule, detail: detail),
    if (withNext && today != null) ?ruleNextText(l, rule, today),
  ];
  return parts.join(' · ');
}

/// `1,8M`, the price on a calendar cell and at the end of a row.
String ruleShortPrice(int price) => formatMoney(price, short: true);

/// The series of a package a screen lists: those that still have a next
/// occurrence from [today] (a `none` series that ended and a series past its
/// `until` are left out), weekly first, then soonest first.
List<PriceRule> listedRules(Iterable<PriceRule> rules, DateTime today) {
  final withNext = <(PriceRule, DateTime)>[];
  for (final r in rules) {
    final next = nextOccurrence(r, today);
    if (next != null) {
      withNext.add((r, next.from));
    }
  }
  withNext.sort((a, b) {
    final aw = a.$1.repeat == PriceRepeat.weekly ? 0 : 1;
    final bw = b.$1.repeat == PriceRepeat.weekly ? 0 : 1;
    if (aw != bw) {
      return aw.compareTo(bw);
    }
    final byDay = a.$2.compareTo(b.$2);
    return byDay != 0 ? byDay : a.$1.id.compareTo(b.$1.id);
  });
  return [for (final e in withNext) e.$1];
}

/// The series of a package with no next occurrence from [today] (a `none`
/// series that ended, a series past its `until`): what [listedRules] leaves
/// out, the one that ended last first. They still count toward the limit of
/// 30 and can be deleted.
List<PriceRule> endedRules(Iterable<PriceRule> rules, DateTime today) {
  final ended = [
    for (final r in rules)
      if (nextOccurrence(r, today) == null) r,
  ];
  String lastDay(PriceRule r) => r.until ?? r.to ?? '';
  ended.sort((a, b) {
    final byDay = lastDay(b).compareTo(lastDay(a));
    return byDay != 0 ? byDay : a.id.compareTo(b.id);
  });
  return ended;
}
