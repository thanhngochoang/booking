import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/day_pricing_controller.dart';
import 'package:photobooking/features/day_pricing/price_day_sheet.dart';
import 'package:photobooking/features/day_pricing/price_rule_sheet.dart';
import 'package:photobooking/features/day_pricing/price_rule_tile.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

/// S08.10, `/me/day-pricing?service=:id` (mock `#S08.10`; spec §5.3): the
/// month calendar of one package with the price under every day, the series
/// of the package, and the sticky "Đặt giá".
///
/// A tap on a day opens the day sheet (a day in a series) or the "Đặt giá"
/// sheet for that day. Press, hold and drag selects a range, which "Đặt giá"
/// then uses; the range stays until it is saved, another package is picked or
/// a day is tapped.
class DayPricingScreen extends ConsumerStatefulWidget {
  const DayPricingScreen({super.key, this.serviceId});

  /// The package to show first (`?service=`); null shows the first one that
  /// is on.
  final String? serviceId;

  @override
  ConsumerState<DayPricingScreen> createState() => _DayPricingScreenState();
}

class _DayPricingScreenState extends ConsumerState<DayPricingScreen> {
  String? _serviceId;
  late DateTime _month = monthOf(ref.read(calendarTodayProvider));
  DateTimeRange? _range;

  /// True while the calendar reports a plain tap: it follows the tap with a
  /// one-day "range" (and a range on the second tap) that this screen ignores,
  /// because a tap opens a sheet and only a drag selects a range.
  bool _inTap = false;

  ServicePackage _selected(List<ServicePackage> ordered) {
    final id = _serviceId ?? widget.serviceId;
    return ordered.firstWhere((p) => p.id == id, orElse: () => ordered.first);
  }

  void _onTap(DateTime day, ServicePackage package, List<PriceRule> rules) {
    _inTap = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _inTap = false);
    setState(() => _range = null);
    final price = priceForDay(package.priceVnd, package.id, rules, day);
    final winner = price.rule;
    // A day an exception was written for opens that series, so the exception
    // can be changed or taken back, even when the day is no longer its own
    // (a dropped day) or another series wins it.
    bool hasException(PriceRule r) =>
        r.serviceId == package.id && ruleExceptions(r).any((e) => e.day == day);
    final PriceRule? excepted = winner != null && hasException(winner)
        ? winner
        : rules.where(hasException).firstOrNull;
    final shown = excepted ?? winner;
    if (shown == null) {
      showPriceRuleSheet(context, serviceId: package.id, from: day, to: day);
      return;
    }
    final lunar = solarToLunar(day);
    final beaten = <BeatenRule>[];
    for (final r in rules) {
      if (shown != winner || r.serviceId != package.id || r.id == winner?.id) {
        continue;
      }
      final c = ruleCoversDay(r, day, lunar: lunar);
      final p = c.price;
      if (c.covers && p != null) {
        beaten.add((rule: r, price: p));
      }
    }
    beaten.sort((a, b) {
      final byTier = b.rule.repeat.tier.compareTo(a.rule.repeat.tier);
      return byTier != 0 ? byTier : b.price.compareTo(a.price);
    });
    showPriceDaySheet(
      context,
      package: package,
      day: day,
      rule: shown,
      dayPrice: price.amount,
      beaten: beaten,
    );
  }

  Future<void> _add(ServicePackage package, DateTime today) async {
    final range = _range;
    final saved = await showPriceRuleSheet(
      context,
      serviceId: package.id,
      from: range?.start ?? today,
      to: range?.end ?? today,
      templates: range == null,
    );
    if (saved && mounted) {
      setState(() => _range = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(calendarTodayProvider);
    final data = ref.watch(dayPricingDataProvider);
    final ordered = packagesByChipOrder(data.value?.packages ?? const []);
    final package = ordered.isEmpty ? null : _selected(ordered);

    return ScreenCode(
      ScreenCodes.dayPricing,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.s0810_title),
            actions: [
              IconButton(
                key: const Key('day-pricing-list'),
                tooltip: l.s0810_listTooltip,
                icon: const AppIcon(AppIcons.list),
                onPressed: () =>
                    context.push('/me/day-pricing/rules?from=calendar'),
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
                        child: AppSkeleton.card(height: 320),
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
                      final selected = package ?? _selected(ordered);
                      final own = [
                        for (final r in v.rules)
                          if (r.serviceId == selected.id) r,
                      ];
                      return _Body(
                        packages: ordered,
                        selected: selected,
                        rules: own,
                        month: _month,
                        range: _range,
                        today: today,
                        onPackage: (p) => setState(() {
                          _serviceId = p.id;
                          _range = null;
                        }),
                        onMonth: (m) => setState(() => _month = m),
                        onDayTap: (d) => _onTap(d, selected, own),
                        onRange: (r) {
                          if (!_inTap) {
                            setState(() => _range = r);
                          }
                        },
                        onEdit: (r) => showPriceRuleSheet(
                          context,
                          serviceId: selected.id,
                          rule: r,
                        ),
                      );
                    },
                  ),
                ),
                if (package != null)
                  AppFooterBar(
                    child: AppButton.primary(
                      l.s0810_add,
                      key: const Key('day-pricing-add'),
                      icon: const AppIcon(AppIcons.add, size: 18),
                      onPressed: () => _add(package, today),
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

class _Body extends StatelessWidget {
  const _Body({
    required this.packages,
    required this.selected,
    required this.rules,
    required this.month,
    required this.range,
    required this.today,
    required this.onPackage,
    required this.onMonth,
    required this.onDayTap,
    required this.onRange,
    required this.onEdit,
  });

  final List<ServicePackage> packages;
  final ServicePackage selected;

  /// The series of [selected] only.
  final List<PriceRule> rules;
  final DateTime month;
  final DateTimeRange? range;
  final DateTime today;
  final ValueChanged<ServicePackage> onPackage;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTimeRange> onRange;
  final ValueChanged<PriceRule> onEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final prices = monthPrices(
      selected.priceVnd,
      selected.id,
      rules,
      month.year,
      month.month,
    );
    final exceptionDays = {
      for (final r in rules)
        for (final e in ruleExceptions(r)) e.day,
    };
    final picked = range;
    bool inRange(DateTime d) =>
        picked != null &&
        !d.isBefore(calendarDay(picked.start)) &&
        !d.isAfter(calendarDay(picked.end));
    final listed = listedRules(rules, today);

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        SingleChildScrollView(
          key: const Key('day-pricing-packages'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final p in packages) ...[
                Opacity(
                  opacity: p.active ? 1 : 0.6,
                  child: AppChip(
                    key: Key('day-pricing-package-${p.id}'),
                    label: l.s0810_packageChip(
                      p.name,
                      formatMoney(p.priceVnd, short: true),
                    ),
                    kind: AppChipKind.context,
                    selected: p.id == selected.id,
                    onChanged: (_) => onPackage(p),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        AppCalendar(
          key: const Key('day-pricing-calendar'),
          month: month,
          onMonthChanged: onMonth,
          selection: AppCalendarSelection.range,
          range: picked,
          today: today,
          onDayTap: onDayTap,
          onRangeChanged: onRange,
          onRangeCompleted: onRange,
          emphasized: (d) => prices[d]?.isRule ?? false,
          dayOutline: (d) =>
              exceptionDays.contains(d) ? AppColors.warning : null,
          dayBuilder: (context, d) {
            final p = prices[d];
            if (p == null) {
              return null;
            }
            return Text(
              ruleShortPrice(p.amount),
              key: Key('day-pricing-price-${dayKeyOf(d)}'),
              style: TextStyle(
                fontSize: 8,
                color: inRange(d) ? null : (p.isRule ? secondary : muted),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpace.s2),
        _Legend(muted: muted),
        const SizedBox(height: AppSpace.s3),
        if (listed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Text(
              l.s0810_noRules(formatMoney(selected.priceVnd, short: true)),
              key: const Key('day-pricing-no-rules'),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          )
        else
          Semantics(
            container: true,
            label: l.s0810_seriesCard,
            child: PriceRuleCard(
              key: const Key('day-pricing-rules'),
              children: [
                for (final r in listed)
                  PriceRuleTile(rule: r, today: today, onTap: () => onEdit(r)),
              ],
            ),
          ),
      ],
    );
  }
}

/// One line under the calendar: what the accent, the outline and the dim mean.
class _Legend extends StatelessWidget {
  const _Legend({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: muted);
    Widget swatch({Color? fill, Color? border}) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(2),
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
    );
    return Wrap(
      key: const Key('day-pricing-legend'),
      spacing: AppSpace.s3,
      runSpacing: AppSpace.s1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(fill: theme.colorScheme.primary),
            const SizedBox(width: AppSpace.s1),
            Text(l.s0810_legendRule, style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(border: AppColors.warning),
            const SizedBox(width: AppSpace.s1),
            Text(l.s0810_legendException, style: style),
          ],
        ),
        Text(l.s0810_legendBase, style: style),
      ],
    );
  }
}
