import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/day_pricing_controller.dart';
import 'package:photobooking/features/day_pricing/price_rule_sheet.dart';
import 'package:photobooking/features/day_pricing/price_rule_tile.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

/// S08.10-list, `/me/day-pricing/rules` (mock `#S08.10-list`; spec §5.6):
/// every series of every package, grouped by package. The calendar icon goes
/// back to S08.10 and the sticky "Đặt giá" opens the "Đặt giá" sheet with the
/// template chips, for the first package that is on.
class PriceRulesScreen extends ConsumerWidget {
  const PriceRulesScreen({super.key, this.fromCalendar = false});

  /// Opened from S08.10: the calendar icon just goes back there.
  final bool fromCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(calendarTodayProvider);
    final data = ref.watch(dayPricingDataProvider);
    final ordered = packagesByChipOrder(data.value?.packages ?? const []);

    void toCalendar() {
      if (fromCalendar && context.canPop()) {
        context.pop();
      } else {
        context.pushReplacement('/me/day-pricing');
      }
    }

    return ScreenCode(
      ScreenCodes.dayPricing,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.s0810_listTitle),
            actions: [
              IconButton(
                key: const Key('price-rules-calendar'),
                tooltip: l.s0810_calendarTooltip,
                icon: const AppIcon(AppIcons.calendarMonth),
                onPressed: toCalendar,
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AsyncView<DayPricingData>(
                    value: data,
                    onRetry: () => retryDayPricing(ref),
                    skeleton: (_) => Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: AppSkeleton.group(
                        child: AppSkeleton.card(height: 200),
                      ),
                    ),
                    error: (context, _, _) => Center(
                      child: ErrorState(
                        message: l.s0810_loadError,
                        onRetry: () => retryDayPricing(ref),
                      ),
                    ),
                    isEmpty: (v) => v.packages.isEmpty,
                    empty: (_) => EmptyState(
                      title: l.s0810_noPackages,
                      actionLabel: l.s0810_noPackagesAction,
                      onAction: () => context.push('/me/packages/new'),
                    ),
                    data: (context, v) {
                      List<PriceRule> own(ServicePackage p) => [
                        for (final r in v.rules)
                          if (r.serviceId == p.id) r,
                      ];
                      return ListView(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        children: [
                          for (final p in ordered)
                            _Group(
                              package: p,
                              rules: listedRules(own(p), today),
                              ended: endedRules(own(p), today),
                              today: today,
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (ordered.isNotEmpty)
                  AppFooterBar(
                    child: AppButton.primary(
                      l.s0810_add,
                      key: const Key('price-rules-add'),
                      icon: const AppIcon(AppIcons.add, size: 18),
                      onPressed: () => showPriceRuleSheet(
                        context,
                        serviceId: ordered.first.id,
                        from: today,
                        to: today,
                        templates: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One package: its heading with the base price, then its series or the
/// "Chưa có chuỗi" line, then the ended ones in a collapsed "Đã kết thúc"
/// group (dimmed; they are still there to open and delete).
class _Group extends StatefulWidget {
  const _Group({
    required this.package,
    required this.rules,
    required this.ended,
    required this.today,
  });

  final ServicePackage package;
  final List<PriceRule> rules;
  final List<PriceRule> ended;
  final DateTime today;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  bool _showEnded = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final package = widget.package;
    final base = formatMoney(package.priceVnd, short: true);
    Widget tile(PriceRule r) => PriceRuleTile(
      rule: r,
      today: widget.today,
      detail: true,
      withNext: true,
      onTap: () => showPriceRuleSheet(context, serviceId: package.id, rule: r),
    );
    return Opacity(
      key: Key('price-rules-group-${package.id}'),
      opacity: package.active ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Semantics(
                header: true,
                child: Text(
                  l.s0810_groupTitle(package.name, base),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppText.xs2,
                    color: muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            if (widget.rules.isEmpty)
              Text(
                l.s0810_noRules(base),
                key: Key('price-rules-empty-${package.id}'),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              )
            else
              PriceRuleCard(children: [for (final r in widget.rules) tile(r)]),
            if (widget.ended.isNotEmpty) ...[
              InkWell(
                key: Key('price-rules-ended-${package.id}'),
                onTap: () => setState(() => _showEnded = !_showEnded),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.s0810_endedCount(widget.ended.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _showEnded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: AppIcon(AppIcons.expandMore, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showEnded)
                Opacity(
                  key: Key('price-rules-ended-list-${package.id}'),
                  opacity: 0.6,
                  child: PriceRuleCard(
                    children: [for (final r in widget.ended) tile(r)],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
