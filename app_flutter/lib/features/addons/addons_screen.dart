import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/addons/addon_edit_sheet.dart';
import 'package:photobooking/features/addons/addon_format.dart';
import 'package:photobooking/features/addons/addons_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S08.06, `/me/addons`: the provider's add-on services, grouped by kind,
/// each with a switch; at most 10 can be on. Tapping a row edits it (S08.07),
/// the sticky primary adds one. Layout follows mock `#S08.06`.
class AddonsScreen extends ConsumerWidget {
  const AddonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final addons = ref.watch(myAddonsProvider);
    final shown = ref.watch(addonsControllerProvider);
    final packages = ref.watch(myPackagesProvider).value;
    ref.listen(myAddonsProvider, (_, next) {
      final stored = next.value;
      if (stored != null) {
        ref.read(addonsControllerProvider.notifier).sync(stored);
      }
    });

    Future<void> toggle(ServiceAddon a, bool on) async {
      final messenger = ScaffoldMessenger.of(context);
      final result = await ref
          .read(addonsControllerProvider.notifier)
          .toggle(a, on);
      final text = switch (result) {
        AddonToggleResult.saved => null,
        AddonToggleResult.limit => l.addonsLimitReached,
        AddonToggleResult.failed => l.addonsSaveFailed,
      };
      if (text != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      }
    }

    return ScreenCode(
      ScreenCodes.myAddons,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.addonsTitle)),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AsyncView<List<ServiceAddon>>(
                    value: addons,
                    onRetry: () => ref.invalidate(myAddonsProvider),
                    skeleton: (_) => const _Skeleton(),
                    error: (context, _, _) => Center(
                      child: ErrorState(
                        message: l.addonsLoadError,
                        onRetry: () => ref.invalidate(myAddonsProvider),
                      ),
                    ),
                    isEmpty: (list) => list.isEmpty,
                    empty: (_) => EmptyState(
                      title: l.addonsEmptyTitle,
                      body: l.addonsEmptyBody,
                    ),
                    data: (context, list) => _AddonList(
                      addons: list,
                      shown: shown,
                      packages: packages ?? const [],
                      onToggle: toggle,
                    ),
                  ),
                ),
                AppFooterBar(
                  child: AppButton.primary(
                    l.addonsAdd,
                    key: const Key('addons-add'),
                    onPressed: () => showAddonEditSheet(context),
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

class _AddonList extends StatelessWidget {
  const _AddonList({
    required this.addons,
    required this.shown,
    required this.packages,
    required this.onToggle,
  });

  final List<ServiceAddon> addons;
  final Map<String, bool> shown;
  final List<ServicePackage> packages;
  final Future<void> Function(ServiceAddon, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    bool on(ServiceAddon a) => shown[a.id] ?? a.active;
    final count = addons.where(on).length;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        Text(
          l.addonsActiveCount(count),
          key: const Key('addons-count'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        for (final kind in AddonKind.values)
          if (addons.any((a) => a.kind == kind)) ...[
            const SizedBox(height: AppSpace.s3),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpace.s1,
                bottom: AppSpace.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  addonKindLabel(l, kind),
                  key: Key('addons-group-${kind.name}'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppText.xs2,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
            ),
            for (final a in addons.where((a) => a.kind == kind)) ...[
              _AddonRow(
                addon: a,
                active: on(a),
                appliesTo: _appliesText(l, a, packages),
                onToggle: (v) => onToggle(a, v),
              ),
              const SizedBox(height: AppSpace.s2),
            ],
          ],
      ],
    );
  }
}

String _appliesText(
  AppLocalizations l,
  ServiceAddon a,
  List<ServicePackage> packages,
) {
  if (a.serviceIds.isEmpty) return l.addonsAppliesAll;
  final names = [
    for (final p in packages)
      if (a.serviceIds.contains(p.id)) p.name,
  ];
  return names.isEmpty
      ? l.addonsAppliesAll
      : l.addonsAppliesTo(names.join(', '));
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({
    required this.addon,
    required this.active,
    required this.appliesTo,
    required this.onToggle,
  });

  final ServiceAddon addon;
  final bool active;
  final String appliesTo;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final a = addon;
    return GlassCard(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('addon-${a.id}'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => showAddonEditSheet(context, addon: a),
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
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: AppIcon(addonKindIcon(a.kind))),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        addonPriceLabel(
                          l,
                          kind: a.kind,
                          unit: a.unit,
                          price: a.price,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        appliesTo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Semantics(
                  label: l.addonsToggle(a.name),
                  child: Switch(
                    key: Key('addon-switch-${a.id}'),
                    value: active,
                    onChanged: onToggle,
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.group(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        for (var i = 0; i < 3; i++) ...[
          AppSkeleton.card(height: 76),
          const SizedBox(height: AppSpace.s2),
        ],
      ],
    ),
  );
}
