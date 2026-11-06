import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The text of a package's price line, by [priceSummary]:
/// `1.500.000₫`, `T2–T6 1,5M · T7–CN 1,8M`, `3,2M–4M · theo ngày`, each with
/// ` · Lễ 2,2M` when the package has a special price.
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

/// Renders [packagePriceText]. Used by S08.08, the package editor (S08.09)
/// and the setup step.
class PackagePriceLine extends StatelessWidget {
  const PackagePriceLine(this.package, {super.key});

  final ServicePackage package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      packagePriceText(context.l10n, package),
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
