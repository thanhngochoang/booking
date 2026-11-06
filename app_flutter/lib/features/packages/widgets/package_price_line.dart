import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// One series on a package's price line: its name and its short price.
typedef PackageExtra = ({String label, int price});

/// The series a package's card mentions after the base price (spec §5.1,
/// at most two): the weekly series if one is live, then the live series that
/// comes next (`nextOccurrence`; one running now counts as next). [rules] are
/// the package's own series; series that have ended are not live.
List<PackageExtra> packageExtras(
  AppLocalizations l,
  Iterable<PriceRule> rules,
  DateTime today,
) {
  final live = listedRules(rules, today);
  final weekly = live.where((r) => r.repeat == PriceRepeat.weekly).firstOrNull;
  final next = live.where((r) => r.repeat != PriceRepeat.weekly).firstOrNull;
  return [
    if (weekly != null)
      (label: _lowerFirst(ruleTitle(l, weekly)), price: weekly.price),
    if (next != null) (label: ruleTitle(l, next), price: next.price),
  ];
}

/// A weekly series reads as a kind of day ("cuối tuần 1,8M"), the other
/// series by their name ("Tết 2,5M"), as in mock `#S08.08`.
String _lowerFirst(String s) =>
    s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

/// ` · cuối tuần 1,8M · Tết 2,5M`, or empty with no live series.
String packageExtrasText(AppLocalizations l, List<PackageExtra> extras) => [
  for (final e in extras)
    ' · ${l.s0808_ruleLine(e.label, ruleShortPrice(e.price))}',
].join();

/// The text of a package's price line on the customer side (S03.01's package
/// list still reads `dayPrices`/`specialPrice` of the public summary until the
/// booking tasks of #316 move it to series): `1.500.000₫`,
/// `T2–T6 1,5M · T7–CN 1,8M`, `3,2M–4M · theo ngày`, each with ` · Lễ 2,2M`
/// when the package has a special price.
String packagePriceText(AppLocalizations l, PricedService p) {
  String short(int v) => formatMoney(v, short: true);
  final summary = priceSummary(p);
  final line = switch (summary) {
    SinglePrice(:final min) => formatMoney(min),
    TwoLevelPrice(:final weekday, :final weekend) => l.s0808_priceTwoLevels(
      short(weekday),
      short(weekend),
    ),
    PerDayPrice(:final min, :final max) => l.s0808_pricePerDay(
      short(min),
      short(max),
    ),
  };
  final special = summary.special;
  return special == null
      ? line
      : l.s0808_priceWithSpecial(line, short(special));
}

/// The owner's price line of a package: the base price in bold, then
/// " · cuối tuần 1,8M · Tết 2,5M" from [rules] (the package's own series).
/// S08.08's card and the setup step use it; without [rules] it is the base
/// price alone.
class PackagePriceLine extends StatelessWidget {
  const PackagePriceLine(
    this.package, {
    super.key,
    this.rules = const [],
    this.today,
  });

  final ServicePackage package;

  /// The series of [package]; they only count when [today] is given.
  final List<PriceRule> rules;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final day = today;
    final extras = day == null
        ? const <PackageExtra>[]
        : packageExtras(l, rules, day);
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: formatMoney(package.priceVnd),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (extras.isNotEmpty)
            TextSpan(
              text: packageExtrasText(l, extras),
              style: TextStyle(color: muted),
            ),
        ],
      ),
    );
  }
}
