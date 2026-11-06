import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/packages/packages_actions.dart';
import 'package:photobooking/features/packages/widgets/package_price_line.dart';

/// S08.08, `/me/packages`: every package with its price line, a switch and a
/// drag handle, the way into the special days, and the sticky "Thêm gói".
/// Layout follows mock `#S08.08`.
///
/// Tapping a package opens `/me/packages/:id` and "Thêm gói" opens
/// `/me/packages/new` (S08.09).
class MyPackagesScreen extends ConsumerStatefulWidget {
  const MyPackagesScreen({super.key});

  @override
  ConsumerState<MyPackagesScreen> createState() => _MyPackagesScreenState();
}

class _MyPackagesScreenState extends ConsumerState<MyPackagesScreen> {
  /// The order just dragged, shown until the stored list catches up.
  List<String>? _pendingOrder;

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

  Future<void> _reorder(List<ServicePackage> shown, int from, int to) async {
    final ids = [for (final p in shown) p.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    setState(() => _pendingOrder = ids);
    final ok = await ref.read(packagesActionsProvider).reorder(ids);
    if (!ok && mounted) {
      setState(() => _pendingOrder = null);
      _say(context.l10n.s0808_saveFailed);
    }
  }

  List<ServicePackage> _ordered(List<ServicePackage> stored) {
    final pending = _pendingOrder;
    if (pending == null) {
      return stored;
    }
    final byId = {for (final p in stored) p.id: p};
    return [
      for (final id in pending) ?byId[id],
      for (final p in stored)
        if (!pending.contains(p.id)) p,
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
    return ScreenCode(
      ScreenCodes.myPackages,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.s0808_title)),
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
                        const _SpecialDaysRow(),
                      ],
                    ),
                    data: (context, stored) {
                      final shown = _ordered(stored);
                      return _PackageList(
                        packages: shown,
                        onToggle: (p, on) => _toggle(p, on, shown),
                        onReorder: (from, to) => _reorder(shown, from, to),
                      );
                    },
                  ),
                ),
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
    );
  }
}

class _PackageList extends StatelessWidget {
  const _PackageList({
    required this.packages,
    required this.onToggle,
    required this.onReorder,
  });

  final List<ServicePackage> packages;
  final void Function(ServicePackage p, bool on) onToggle;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final active = packages.where((p) => p.active).length;
    return ReorderableListView.builder(
      key: const Key('packages-list'),
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(AppSpace.s4),
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s2),
        child: Text(
          l.s0808_activeCount(active),
          key: const Key('packages-count'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      footer: const Padding(
        padding: EdgeInsets.only(top: AppSpace.s2),
        child: _SpecialDaysRow(),
      ),
      itemCount: packages.length,
      onReorderItem: onReorder,
      itemBuilder: (context, i) {
        final p = packages[i];
        return _PackageTile(
          key: ValueKey(p.id),
          index: i,
          package: p,
          onToggle: (on) => onToggle(p, on),
        );
      },
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    super.key,
    required this.index,
    required this.package,
    required this.onToggle,
  });

  final int index;
  final ServicePackage package;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final p = package;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Opacity(
        opacity: p.active ? 1 : 0.6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: dark ? AppColorsDark.border : AppColors.border,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: Key('package-${p.id}'),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => context.push('/me/packages/${p.id}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDelayedDragStartListener(
                    index: index,
                    child: ExcludeSemantics(
                      child: SizedBox(
                        key: Key('package-handle-${p.id}'),
                        width: AppSpace.s12,
                        height: AppSpace.s12,
                        child: AppIcon(AppIcons.dragHandle, color: muted),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            packageMeta(
                              l,
                              durationMinutes: p.durationMinutes,
                              editedCount: p.editedCount,
                              deliveryDays: p.deliveryDays,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s1),
                          if (p.active)
                            PackagePriceLine(p)
                          else
                            Text(
                              l.s0808_hidden,
                              key: Key('package-hidden-${p.id}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
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
        ),
      ),
    );
  }
}

/// "Ngày đặc biệt · {n} ngày lễ chung · {m} khoảng ngày của bạn" → S08.10.
class _SpecialDaysRow extends ConsumerWidget {
  const _SpecialDaysRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final year = ref.watch(calendarTodayProvider).year;
    final holidays = ref.watch(holidaysProvider(year)).value;
    final ranges = uid == null
        ? null
        : ref.watch(specialDaysProvider(uid)).value;
    final sub = holidays == null || ranges == null
        ? null
        : l.s0808_specialDaysSub(holidays.length, ranges.length);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const Key('packages-special-days'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.push('/me/special-days'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
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
                  child: Center(child: AppIcon(AppIcons.calendarCheck)),
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.s0808_specialDays,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        key: const Key('packages-special-days-sub'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
              AppIcon(AppIcons.chevron, size: 18, color: muted),
            ],
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
