// lib/features/booking/widgets/addon_pick_block.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/features/addons/addon_format.dart';

/// S04.01 "Thêm dịch vụ" (mock `#S04.01-addons`): the add-ons that apply to
/// the chosen package, in kind order. A one-off add-on has a checkbox; the
/// others a −/+ stepper from 0 to their maximum. Draws nothing when [addons]
/// is empty.
class AddonPickBlock extends StatelessWidget {
  const AddonPickBlock({
    super.key,
    required this.addons,
    required this.picks,
    required this.onQty,
  });

  final List<ServiceAddon> addons;

  /// addonId → quantity; absent = 0.
  final Map<String, int> picks;

  /// Called with the add-on and its new quantity (0 removes it).
  final void Function(String addonId, int qty) onQty;

  @override
  Widget build(BuildContext context) {
    if (addons.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ordered = [
      for (final kind in AddonKind.values)
        ...addons.where((a) => a.kind == kind),
    ];
    return Column(
      key: const Key('addon-pick-block'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.bookAddonsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Text(
                l10n.bookAddonsOptional,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final a in ordered)
          _AddonRow(
            addon: a,
            qty: picks[a.id] ?? 0,
            onQty: (q) => onQty(a.id, q),
          ),
      ],
    );
  }
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({
    required this.addon,
    required this.qty,
    required this.onQty,
  });

  final ServiceAddon addon;
  final int qty;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final noun = addonUnitNoun(l10n, addon.kind, addon.unit);
    final once = addon.unit == AddonUnit.perBooking;

    final trailing = once
        ? Checkbox(
            key: Key('addon-${addon.id}-check'),
            value: qty > 0,
            semanticLabel: addon.name,
            onChanged: (v) => onQty(v == true ? 1 : 0),
          )
        : QtyStepper(
            keyPrefix: 'addon-${addon.id}',
            value: qty,
            min: 0,
            max: addon.maxQty,
            valueLabel: l10n.bookAddonQty(addon.name, qty, noun),
            decrementLabel: l10n.bookAddonLess(noun),
            incrementLabel: l10n.bookAddonMore(noun),
            onChanged: onQty,
          );

    return Padding(
      key: Key('addon-row-${addon.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: AppIcon(addonKindIcon(addon.kind), size: 17),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s2h),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addon.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (addon.description case final d?)
                  Text(
                    d,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  addonPriceLabel(
                    l10n,
                    kind: addon.kind,
                    unit: addon.unit,
                    price: addon.price,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s1),
          trailing,
        ],
      ),
    );
  }
}
