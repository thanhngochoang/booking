import 'package:flutter/widgets.dart' show IconData;
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Icon of an add-on kind (S04.01, S04.03, S05.02, S08.06).
IconData addonKindIcon(AddonKind kind) => switch (kind) {
  AddonKind.makeup => AppIcons.face,
  AddonKind.retouch => AppIcons.autoAwesome,
  AddonKind.transport => AppIcons.car,
  AddonKind.outfit => AppIcons.checkroom,
  AddonKind.other => AppIcons.addCircle,
};

/// Label of a kind chip.
String addonKindLabel(AppLocalizations l, AddonKind kind) => switch (kind) {
  AddonKind.makeup => l.addonKindMakeup,
  AddonKind.retouch => l.addonKindRetouch,
  AddonKind.transport => l.addonKindTransport,
  AddonKind.outfit => l.addonKindOutfit,
  AddonKind.other => l.addonKindOther,
};

/// Label of a unit chip ("Một lần", "Theo người", "Theo số lượng").
String addonUnitLabel(AppLocalizations l, AddonUnit unit) => switch (unit) {
  AddonUnit.perBooking => l.addonOnce,
  AddonUnit.perPerson => l.addonUnitPerPerson,
  AddonUnit.perItem => l.addonUnitPerItem,
};

/// The noun after a quantity (Decision 16): people, photos for retouching,
/// sets for outfits, "lần" for the rest.
String addonUnitNoun(AppLocalizations l, AddonKind kind, AddonUnit unit) =>
    switch (unit) {
      AddonUnit.perPerson => l.addonNounPerson,
      AddonUnit.perItem => switch (kind) {
        AddonKind.retouch => l.addonNounPhoto,
        AddonKind.outfit => l.addonNounSet,
        _ => l.addonNounTime,
      },
      AddonUnit.perBooking => l.addonNounTime,
    };

/// "800.000₫ / người", "300.000₫ · một lần".
String addonPriceLabel(
  AppLocalizations l, {
  required AddonKind kind,
  required AddonUnit unit,
  required int price,
}) => unit == AddonUnit.perBooking
    ? l.addonPriceOnce(formatMoney(price))
    : l.addonPricePer(formatMoney(price), addonUnitNoun(l, kind, unit));

/// One row of the S04.03 money table: "Trang điểm · 2 người"; a one-off
/// add-on shows its name only.
String addonLineLabel(AppLocalizations l, BookingAddonLine line) =>
    line.unit == AddonUnit.perBooking
    ? line.name
    : l.addonLineQty(
        line.name,
        line.qty,
        addonUnitNoun(l, line.kind, line.unit),
      );

/// One line for the request card (S06.01): "+ Trang điểm ×2 · Xe đón";
/// a quantity of 1 shows no "×". Empty when there are no lines.
String addonsSummary(AppLocalizations l, List<BookingAddonLine> lines) {
  if (lines.isEmpty) return '';
  final parts = [
    for (final line in lines)
      line.qty > 1 ? l.addonSummaryItem(line.name, line.qty) : line.name,
  ];
  return l.addonsSummary(parts.join(' · '));
}
