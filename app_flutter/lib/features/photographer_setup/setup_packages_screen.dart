import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/packages/widgets/package_price_line.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

/// S08.01, setup step 2/4: the packages customers book. At least one active
/// package is needed to go on. Packages are added and edited in S08.09
/// (`?from=setup`, which returns here). Layout follows mock `#S08.01-packages`:
/// short package cards (name, meta line, price line, chevron), a small outline
/// "Thêm gói", a note, sticky footer "Quay lại" + "Tiếp tục".
class SetupPackagesScreen extends ConsumerStatefulWidget {
  const SetupPackagesScreen({super.key});

  @override
  ConsumerState<SetupPackagesScreen> createState() =>
      _SetupPackagesScreenState();
}

class _SetupPackagesScreenState extends ConsumerState<SetupPackagesScreen> {
  String? _uid;

  /// "Tiếp tục" is being handled (until step 3 is popped): a second tap
  /// does nothing, so `/setup/3` is pushed once.
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUser?.uid;
  }

  Future<void> _next() async {
    final uid = _uid;
    if (uid == null || _going) {
      return;
    }
    setState(() => _going = true);
    final store = ref.read(setupDraftStoreProvider);
    if (store.step(uid) < 3) {
      await store.setStep(uid, 3);
    }
    if (!mounted) {
      return;
    }
    await context.push('/setup/3');
    if (mounted) {
      setState(() => _going = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/setup/1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final packages = ref.watch(myPackagesProvider);
    final active = [
      for (final p in packages.value ?? const <ServicePackage>[])
        if (p.active) p,
    ];

    final list = AsyncView<List<ServicePackage>>(
      value: packages,
      onRetry: () => ref.invalidate(myPackagesProvider),
      skeleton: (_) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PackageSkeleton(),
          SizedBox(height: AppSpace.s2),
          _PackageSkeleton(),
          SizedBox(height: AppSpace.s2),
          _PackageSkeleton(),
        ],
      ),
      error: (context, _, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.setupPackagesLoadError),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.text(
              l.retry,
              size: AppButtonSize.small,
              onPressed: () => ref.invalidate(myPackagesProvider),
            ),
          ),
        ],
      ),
      data: (context, _) => active.isEmpty
          ? Text(
              l.setupNoPackages,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s2),
                  _PackageCard(
                    package: active[i],
                    onTap: () =>
                        context.push('/me/packages/${active[i].id}?from=setup'),
                  ),
                ],
              ],
            ),
    );

    return ScreenCode(
      ScreenCodes.setupProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Mock S08.01 `.bar`: back · "Hồ sơ nhiếp ảnh gia" · "2 / 4".
          appBar: AppBar(
            title: Text(l.setupFlowTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.s4),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      l.stepProgressCount(2, 4),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // The bottom inset belongs to the sticky AppFooterBar.
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpace.s5),
                  child: StepProgress(current: 2, total: 4, showCount: false),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l.setupServicesHeading,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          l.setupServiceHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        list,
                        const SizedBox(height: AppSpace.s3),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton.outline(
                            l.s0808_add,
                            key: const Key('setup-add-package'),
                            size: AppButtonSize.small,
                            icon: const AppIcon(AppIcons.add, size: 16),
                            onPressed: () =>
                                context.push('/me/packages/new?from=setup'),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          l.s0809_setupNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                        if (active.isNotEmpty)
                          AppButton.text(
                            l.setupAddAddon,
                            key: const Key('setup-addons'),
                            size: AppButtonSize.small,
                            onPressed: () => context.push('/me/addons'),
                          ),
                        if (active.isEmpty && packages.hasValue) ...[
                          const SizedBox(height: AppSpace.s2),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l.setupNeedPackage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                AppFooterBar(
                  child: LayoutBuilder(
                    builder: (context, box) => Row(
                      children: [
                        SizedBox(
                          width: box.maxWidth * 0.36,
                          child: AppButton.outline(
                            l.setupContactBack,
                            key: const Key('setup-back'),
                            onPressed: _back,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: AppButton.primary(
                            l.setupNext,
                            key: const Key('setup-next'),
                            onPressed: active.isEmpty || _going ? null : _next,
                          ),
                        ),
                      ],
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

/// Mock S08.01 `.card`: name, meta line, the price line and a chevron; tap
/// opens S08.09.
class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.onTap});

  final ServicePackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final p = package;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(color: scheme.outlineVariant),
    );
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: ShapeDecoration(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          shape: shape,
        ),
        child: InkWell(
          key: Key('package-${p.id}'),
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s3,
              AppSpace.s2h,
              AppSpace.s2,
              AppSpace.s2h,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      Text(
                        packageMeta(
                          l,
                          durationMinutes: p.durationMinutes,
                          editedCount: p.editedCount,
                          deliveryDays: p.deliveryDays,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      PackagePriceLine(p),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                AppIcon(AppIcons.chevron, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageSkeleton extends StatelessWidget {
  const _PackageSkeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.card(height: 64);
}
