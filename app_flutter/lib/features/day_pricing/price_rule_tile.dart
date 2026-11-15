import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

/// One series as a row (mock `.irow2`): the repeat icon (or the event icon for
/// a one-off range), the name over its rule, the short price and a chevron.
/// S08.10's card, S08.10-list and S08.09's read-only card use it.
class PriceRuleTile extends StatelessWidget {
  const PriceRuleTile({
    super.key,
    required this.rule,
    required this.today,
    this.detail = false,
    this.withNext = false,
    this.onTap,
  });

  final PriceRule rule;
  final DateTime today;

  /// Spell out up to two exceptions ("CN 15/11: 1,5M"), as the list does.
  final bool detail;

  /// Add when a lunar series comes next, as the list does.
  final bool withNext;

  /// Null makes the row read-only (no chevron).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2h),
      child: Row(
        children: [
          ExcludeSemantics(
            child: AppIcon(
              rule.repeat == PriceRepeat.none
                  ? AppIcons.event
                  : AppIcons.repeat,
              size: 18,
              color: muted,
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ruleTitle(l, rule),
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ruleSummary(
                    l,
                    rule,
                    today: today,
                    detail: detail,
                    withNext: withNext,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          Text(
            ruleShortPrice(rule.price),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpace.s1),
            ExcludeSemantics(
              child: AppIcon(AppIcons.chevron, size: 18, color: muted),
            ),
          ],
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: onTap == null
          ? row
          : InkWell(
              key: Key('price-rule-${rule.id}'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: row,
              ),
            ),
    );
  }
}

/// The glass card that holds [PriceRuleTile]s with hairlines between them.
class PriceRuleCard extends StatelessWidget {
  const PriceRuleCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? AppColorsDark.border : AppColors.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: border),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
