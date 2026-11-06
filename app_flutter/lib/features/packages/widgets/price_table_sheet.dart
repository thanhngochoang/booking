import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/day_pricing/price_rule_tile.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

/// S03.01 "Bảng giá · {gói}" (mock `#S03.01-prices`): "Giá thường", then one
/// row per series of the package (name, rule, price), read-only. Series that
/// ended and exceptions are not listed. "Đặt gói này" is the one primary
/// action; [onBook] is null when the photographer takes no orders.
Future<void> showPriceTableSheet(
  BuildContext context, {
  required String photographerId,
  required String serviceId,
  required String name,
  required int basePrice,
  VoidCallback? onBook,
}) => showAppSheet<void>(
  context,
  builder: (_) => PriceTableSheet(
    photographerId: photographerId,
    serviceId: serviceId,
    name: name,
    basePrice: basePrice,
    onBook: onBook,
  ),
);

class PriceTableSheet extends ConsumerWidget {
  const PriceTableSheet({
    super.key,
    required this.photographerId,
    required this.serviceId,
    required this.name,
    required this.basePrice,
    this.onBook,
  });

  final String photographerId;
  final String serviceId;
  final String name;
  final int basePrice;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = ref.watch(calendarTodayProvider);
    final rules = listedRules(
      ref.watch(servicePriceRulesProvider((photographerId, serviceId))).value ??
          const <PriceRule>[],
      today,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.s0301_priceSheetTitle(name),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.bookClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          PriceRuleCard(
            children: [
              _PriceRow(
                key: const Key('price-sheet-base'),
                title: l.s0301_baseRow,
                price: basePrice,
              ),
              for (final r in rules)
                _PriceRow(
                  key: Key('price-sheet-rule-${r.id}'),
                  title: ruleTitle(l, r),
                  subtitle: [
                    rulePattern(l, r),
                    ?ruleNextText(l, r, today),
                  ].join(' · '),
                  price: r.price,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.s0301_priceSheetNote,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.photoBook,
            key: const Key('price-sheet-book'),
            onPressed: onBook == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    onBook!();
                  },
          ),
        ],
      ),
    );
  }
}

/// One line of the table: the name over its rule, the full price at the end.
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.price,
  });

  final String title;
  final String? subtitle;
  final int price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Text(
            formatMoney(price),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
