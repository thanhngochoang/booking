import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';
import 'package:photobooking/features/packages/packages_actions.dart';
import 'package:photobooking/features/packages/widgets/package_price_line.dart';

/// S08.08, `/me/packages`: the way into "Giá theo ngày", every package with
/// its base price and the series that change it, a switch, and the sticky
/// "Thêm gói". "Sắp xếp" (two packages or more) turns the list into the sort
/// mode of mock `#S08.08-sort`. Layout follows mock `#S08.08`.
///
/// Tapping a package opens `/me/packages/:id` and "Thêm gói" opens
/// `/me/packages/new` (S08.09).
class MyPackagesScreen extends ConsumerStatefulWidget {
  const MyPackagesScreen({super.key});

  @override
  ConsumerState<MyPackagesScreen> createState() => _MyPackagesScreenState();
}

class _MyPackagesScreenState extends ConsumerState<MyPackagesScreen> {
  /// The order just saved, shown until the stored list catches up.
  List<String>? _pendingOrder;

  /// The order being arranged in sort mode; null outside it.
  List<String>? _arranging;

  /// The package moved last in sort mode (it gets the accent border).
  String? _movedId;
  bool _savingOrder = false;

  bool get _sorting => _arranging != null;

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(
    ServicePackage p,
    bool on,
    List<ServicePackage> all,
  ) async {
    final l = context.l10n;
    if (!on && p.active && all.where((x) => x.active).length == 1) {
      final ok = await showConfirmSheet(
        context,
        title: l.s0808_lastOffTitle,
        body: l.s0808_lastOff,
        confirmLabel: l.s0808_lastOffConfirm,
        keepLabel: l.s0808_lastOffKeep,
      );
      if (!ok || !mounted) {
        return;
      }
    }
    final ok = await ref.read(packagesActionsProvider).setActive(p.id, on);
    if (!ok && mounted) {
      _say(context.l10n.s0808_saveFailed);
    }
  }

  void _startSorting(List<ServicePackage> shown) => setState(() {
    _arranging = [for (final p in shown) p.id];
    _movedId = null;
  });

  /// Moves the package at [from] to [to] in the order being arranged.
  void _move(int from, int to) {
    final order = _arranging;
    if (order == null || to < 0 || to >= order.length || from == to) {
      return;
    }
    final next = [...order];
    final id = next.removeAt(from);
    next.insert(to, id);
    setState(() {
      _arranging = next;
      _movedId = id;
    });
    final view = View.of(context);
    final dir = Directionality.of(context);
    SemanticsService.sendAnnouncement(
      view,
      context.l10n.reorderPosition(to + 1, next.length),
      dir,
    );
  }

  /// "Xong": writes `order` in one batch when it changed, then leaves sort
  /// mode. A failed write keeps the order as arranged.
  Future<void> _done(List<ServicePackage> stored) async {
    final order = _arranging;
    if (order == null || _savingOrder) {
      return;
    }
    final same =
        order.length == stored.length &&
        [for (var i = 0; i < order.length; i++) stored[i].id == order[i]]
            .every((x) => x);
    if (same) {
      setState(() => _arranging = null);
      return;
    }
    setState(() => _savingOrder = true);
    final ok = await ref.read(packagesActionsProvider).reorder(order);
    if (!mounted) {
      return;
    }
    setState(() {
      _savingOrder = false;
      if (ok) {
        _pendingOrder = order;
        _arranging = null;
        _movedId = null;
      }
    });
    if (!ok) {
      _say(context.l10n.s0808_saveFailed);
    }
  }

  List<ServicePackage> _inOrder(
    List<ServicePackage> stored,
    List<String>? order,
  ) {
    if (order == null) {
      return stored;
    }
    final byId = {for (final p in stored) p.id: p};
    return [
      for (final id in order) ?byId[id],
      for (final p in stored)
        if (!order.contains(p.id)) p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final packages = ref.watch(myPackagesProvider);
    ref.listen(myPackagesProvider, (_, next) {
      if (next.hasValue && _pendingOrder != null) {
        setState(() => _pendingOrder = null);
      }
    });
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final rulesAsync = uid == null
        ? null
        : ref.watch(providerPriceRulesProvider(uid));
    final rules = rulesAsync?.value ?? const <PriceRule>[];
    // False while the series load or when they failed to: the row must not
    // claim there are none.
    final rulesKnown = rulesAsync == null || rulesAsync.hasValue;
    final today = ref.watch(calendarTodayProvider);
    final stored = packages.value;
    final sorting = _sorting && stored != null;
    return ScreenCode(
      ScreenCodes.myPackages,
      child: AuroraBackground(
        child: PopScope(
          // Back leaves sort mode as "Xong" does (mock #S08.08-sort).
          canPop: !sorting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && stored != null) {
              _done(_inOrder(stored, _pendingOrder));
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              automaticallyImplyLeading: !sorting,
              title: Text(sorting ? l.s0808_sortTitle : l.s0808_title),
              actions: [
                if (sorting)
                  TextButton(
                    key: const Key('packages-sort-done'),
                    onPressed: _savingOrder
                        ? null
                        : () => _done(_inOrder(stored, _pendingOrder)),
                    child: Text(
                      l.s0808_done,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else if (stored != null && stored.length >= 2)
                  TextButton(
                    key: const Key('packages-sort'),
                    onPressed: () =>
                        _startSorting(_inOrder(stored, _pendingOrder)),
                    child: Text(l.s0808_sort),
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
                    child: AsyncView<List<ServicePackage>>(
                      value: packages,
                      onRetry: () => ref.invalidate(myPackagesProvider),
                      skeleton: (_) => const _Skeleton(),
                      error: (context, _, _) => Center(
                        child: ErrorState(
                          message: l.s0808_loadError,
                          onRetry: () => ref.invalidate(myPackagesProvider),
                        ),
                      ),
                      isEmpty: (list) => list.isEmpty,
                      empty: (_) => ListView(
                        padding: const EdgeInsets.all(AppSpace.s4),
                        children: [
                          SizedBox(
                            height: 240,
                            child: EmptyState(title: l.s0808_empty),
                          ),
                          _DayPricingRow(
                            rules: rules,
                            known: rulesKnown,
                            today: today,
                          ),
                        ],
                      ),
                      data: (context, list) {
                        final shown = _inOrder(list, _pendingOrder);
                        if (_sorting) {
                          return _SortList(
                            packages: _inOrder(shown, _arranging),
                            movedId: _movedId,
                            onMove: _move,
                          );
                        }
                        return _PackageList(
                          packages: shown,
                          rules: rules,
                          rulesKnown: rulesKnown,
                          today: today,
                          onToggle: (p, on) => _toggle(p, on, shown),
                        );
                      },
                    ),
                  ),
                  if (!sorting)
                    AppFooterBar(
                      child: AppButton.primary(
                        l.s0808_add,
                        key: const Key('packages-add'),
                        onPressed: () => context.push('/me/packages/new'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _mutedOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColorsDark.foregroundMuted
    : AppColors.foregroundMuted;

class _PackageList extends StatelessWidget {
  const _PackageList({
    required this.packages,
    required this.rules,
    required this.rulesKnown,
    required this.today,
    required this.onToggle,
  });

  final List<ServicePackage> packages;
  final List<PriceRule> rules;
  final bool rulesKnown;
  final DateTime today;
  final void Function(ServicePackage p, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final active = packages.where((p) => p.active).length;
    return ListView(
      key: const Key('packages-list'),
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        _DayPricingRow(rules: rules, known: rulesKnown, today: today),
        const SizedBox(height: AppSpace.s2),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2),
          child: Text(
            l.s0808_activeHint(active),
            key: const Key('packages-count'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _mutedOf(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        for (final p in packages)
          _PackageTile(
            key: ValueKey(p.id),
            package: p,
            rules: [
              for (final r in rules)
                if (r.serviceId == p.id) r,
            ],
            today: today,
            onToggle: (on) => onToggle(p, on),
          ),
      ],
    );
  }
}

/// The card shell of S08.08 (normal and sort mode): filled, bordered, dimmed
/// for a hidden package, with an accent border for [highlight].
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.dimmed,
    required this.child,
    this.highlight = false,
  });

  final bool dimmed;
  final bool highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              width: highlight ? 2 : 1,
              color: highlight
                  ? (dark ? AppColorsDark.primary : AppColors.primary)
                  : (dark ? AppColorsDark.border : AppColors.border),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// "Đang ẩn" next to the name of a hidden package.
class _HiddenChip extends StatelessWidget {
  const _HiddenChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.border : AppColors.border,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          context.l10n.s0808_hiddenChip,
          style: theme.textTheme.labelSmall?.copyWith(color: _mutedOf(context)),
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.package});

  final ServicePackage package;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s1,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        package.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (!package.active)
        _HiddenChip(key: Key('package-hidden-${package.id}')),
    ],
  );
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    super.key,
    required this.package,
    required this.rules,
    required this.today,
    required this.onToggle,
  });

  final ServicePackage package;
  final List<PriceRule> rules;
  final DateTime today;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = package;
    return _CardShell(
      dimmed: !p.active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('package-${p.id}'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/me/packages/${p.id}'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s3,
                    AppSpace.s3,
                    0,
                    AppSpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NameRow(package: p),
                      Text(
                        packageMeta(
                          l,
                          durationMinutes: p.durationMinutes,
                          editedCount: p.editedCount,
                          deliveryDays: p.deliveryDays,
                          editedWords: true,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _mutedOf(context),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      // A hidden package shows its base price alone.
                      PackagePriceLine(
                        p,
                        rules: p.active ? rules : const [],
                        today: today,
                      ),
                    ],
                  ),
                ),
              ),
              Semantics(
                label: l.s0808_toggle(p.name),
                child: Switch(
                  key: Key('package-switch-${p.id}'),
                  value: p.active,
                  onChanged: onToggle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort mode (`#S08.08-sort`): the hint, then one card per package with a
/// drag handle (long press, so scrolling never drags), "Chuyển lên" and
/// "Chuyển xuống" (dimmed at the ends); no switch.
class _SortList extends StatelessWidget {
  const _SortList({
    required this.packages,
    required this.movedId,
    required this.onMove,
  });

  final List<ServicePackage> packages;
  final String? movedId;
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReorderableListView.builder(
      key: const Key('packages-sort-list'),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(AppSpace.s4),
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s2),
        child: Text(
          context.l10n.s0808_sortHint,
          key: const Key('packages-sort-hint'),
          style: theme.textTheme.bodySmall?.copyWith(color: _mutedOf(context)),
        ),
      ),
      itemCount: packages.length,
      onReorderItem: onMove,
      itemBuilder: (context, i) => _SortTile(
        key: ValueKey(packages[i].id),
        index: i,
        count: packages.length,
        package: packages[i],
        moved: packages[i].id == movedId,
        onMove: (to) => onMove(i, to),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  const _SortTile({
    super.key,
    required this.index,
    required this.count,
    required this.package,
    required this.moved,
    required this.onMove,
  });

  final int index;
  final int count;
  final ServicePackage package;
  final bool moved;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final p = package;
    final muted = _mutedOf(context);
    return _CardShell(
      dimmed: !p.active,
      highlight: moved,
      child: Row(
        children: [
          ReorderableDelayedDragStartListener(
            index: index,
            child: Semantics(
              label: l.s0808_dragHandle,
              child: SizedBox(
                key: Key('package-handle-${p.id}'),
                width: AppSpace.s12,
                height: AppSpace.s12,
                child: AppIcon(
                  AppIcons.dragHandle,
                  color: moved
                      ? (dark ? AppColorsDark.primary : AppColors.primary)
                      : muted,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NameRow(package: p),
                  Text(
                    formatMoney(p.priceVnd),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            key: Key('package-up-${p.id}'),
            tooltip: l.s0808_moveUp,
            onPressed: index == 0 ? null : () => onMove(index - 1),
            icon: const AppIcon(AppIcons.moveUp),
          ),
          IconButton(
            key: Key('package-down-${p.id}'),
            tooltip: l.s0808_moveDown,
            onPressed: index == count - 1 ? null : () => onMove(index + 1),
            icon: const AppIcon(AppIcons.moveDown),
          ),
        ],
      ),
    );
  }
}

/// "Giá theo ngày" with the names of the live series of every package and
/// their number ("Cuối tuần, Mùa cưới, Tết · 6 chuỗi"), or the empty text and
/// "Đặt giá" → S08.10. While the series are not known (loading, or failed to
/// load) it shows the title only, never "no series".
class _DayPricingRow extends StatelessWidget {
  const _DayPricingRow({
    required this.rules,
    required this.known,
    required this.today,
  });

  final List<PriceRule> rules;
  final bool known;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = _mutedOf(context);
    final dark = theme.brightness == Brightness.dark;
    final live = listedRules(rules, today);
    final names = <String>[];
    for (final r in live) {
      final name = ruleTitle(l, r);
      if (!names.contains(name)) {
        names.add(name);
      }
    }
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: muted);
    final Widget sub = !known
        ? const SizedBox.shrink()
        : live.isEmpty
        ? Text.rich(
            TextSpan(
              style: metaStyle,
              children: [
                TextSpan(text: '${l.s0810_noneSummary} · '),
                TextSpan(
                  text: l.s0810_add,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            key: const Key('packages-day-pricing-sub'),
          )
        : Text(
            l.s0808_dayPricingSummary(names.take(3).join(', '), live.length),
            key: const Key('packages-day-pricing-sub'),
            style: metaStyle?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('packages-day-pricing'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/me/day-pricing'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2,
              ),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: AppIcon(AppIcons.tune)),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.s0808_dayPricing,
                          style: theme.textTheme.titleSmall,
                        ),
                        sub,
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.chevron, size: 18, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.group(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        for (var i = 0; i < 3; i++) ...[
          AppSkeleton.card(height: 88),
          const SizedBox(height: AppSpace.s2),
        ],
      ],
    ),
  );
}
