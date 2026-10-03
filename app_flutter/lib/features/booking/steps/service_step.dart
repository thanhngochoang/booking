// lib/features/booking/steps/service_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

class ServiceStep extends ConsumerStatefulWidget {
  const ServiceStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  ConsumerState<ServiceStep> createState() => _ServiceStepState();
}

class _ServiceStepState extends ConsumerState<ServiceStep> {
  @override
  void initState() {
    super.initState();
    final current = ref.read(profilePackagesProvider(widget.args.photographerId));
    if (current.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(bookingFlowControllerProvider(widget.args).notifier)
            .applyPackages(current.value!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ServiceSummary>>>(
      profilePackagesProvider(widget.args.photographerId),
      (prev, next) {
        if (next.hasValue) {
          ref.read(bookingFlowControllerProvider(widget.args).notifier)
              .applyPackages(next.value!);
        }
      },
    );

    final l10n = context.l10n;
    final state = ref.watch(bookingFlowControllerProvider(widget.args));
    final controller = ref.read(bookingFlowControllerProvider(widget.args).notifier);
    final packagesAsync = ref.watch(profilePackagesProvider(widget.args.photographerId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ScreenCode(
      ScreenCodes.bookService,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s2,
            ),
            child: Text(
              l10n.bookChoosePackage,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (state.priceChanged)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s1,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: scheme.error),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: scheme.error),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(
                        child: Text(
                          l10n.bookPriceChanged,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: AsyncView<List<ServiceSummary>>(
                value: packagesAsync,
                skeleton: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      AppOptionTile.skeleton(withThumb: true),
                      if (i < 2) const SizedBox(height: AppSpace.s2),
                    ],
                  ],
                ),
                onRetry: () => ref.invalidate(
                  profilePackagesProvider(widget.args.photographerId),
                ),
                isEmpty: (list) => list.isEmpty,
                empty: (emptyContext) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
                  child: EmptyState(
                    title: l10n.bookNoPackages,
                    body: '',
                    actionLabel: l10n.bookClose,
                    onAction: () => Navigator.of(context).maybePop(),
                  ),
                ),
                data: (context, packages) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final pkg in packages) ...[
                        _PackageTile(
                          package: pkg,
                          selected: state.serviceId == pkg.id,
                          onTap: () => controller.selectService(pkg),
                        ),
                        const SizedBox(height: AppSpace.s2),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l10n.bookContinuePrice(formatMoney(state.priceVnd ?? 0)),
              onPressed: state.canContinue ? controller.next : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final ServiceSummary package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = selected
        ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final edge = selected ? scheme.primary : scheme.outline;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: edge),
    );

    final details = <String>[
      if (package.durationMinutes > 0) '${package.durationMinutes} phút',
      if (package.photoCount != null) '${package.photoCount} ảnh',
      if (package.editedCount != null) '${package.editedCount} ảnh sửa',
      if (package.deliveryDays != null) 'trả trong ${package.deliveryDays} ngày',
    ].join(' · ');

    return Semantics(
      enabled: true,
      checked: selected,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${package.name}, ${formatMoney(package.priceVnd)}',
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: ShapeDecoration(color: fill, shape: shape),
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2h,
              ),
              child: Row(
                children: [
                  _OptionRadio(selected: selected, edge: edge),
                  const SizedBox(width: AppSpace.s2h),
                  if (package.coverUrl != null && package.coverUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: NetworkPhoto(
                          url: package.coverUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2h),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          package.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            details,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Text(
                    formatMoney(package.priceVnd),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selected ? scheme.primary : null,
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

class _OptionRadio extends StatelessWidget {
  const _OptionRadio({required this.selected, required this.edge});
  final bool selected;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: edge, width: 2),
      ),
      child: selected
          ? Container(
              key: const Key('option-radio-dot'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
