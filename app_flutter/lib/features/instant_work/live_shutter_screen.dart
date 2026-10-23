// S14.01: Live Shutter, "Sẵn sàng hỗ trợ" and the platform price list, with
// the terms (`#S14.01-terms`) and locked (`#S14.01-locked`) states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/features/instant_work/live_shutter_controller.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';

/// Where "Thêm số" comes back to.
const _here = '/work/instant';

class LiveShutterScreen extends ConsumerStatefulWidget {
  const LiveShutterScreen({super.key});

  @override
  ConsumerState<LiveShutterScreen> createState() => _LiveShutterScreenState();
}

class _LiveShutterScreenState extends ConsumerState<LiveShutterScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the Settings app: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(liveShutterControllerProvider.notifier).refreshLocation();
    }
  }

  LiveShutterController get _controller =>
      ref.read(liveShutterControllerProvider.notifier);

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() call) async {
    final l = context.l10n;
    try {
      await call();
    } on Object catch (e) {
      if (!mounted) return;
      _say(
        e is LiveShutterNoLocation
            ? l.liveShutterReasonLocation
            : instantErrorText(l, e),
      );
    }
  }

  Future<void> _switch(bool on) => _run(
    () => _controller.setOnline(
      on,
      // Switching on is the reason to ask (S17.03).
      askPrimer: () async {
        if (!mounted) return;
        await maybeAskForNotifications(
          context,
          ref,
          const PhotographerPrimer(),
        );
      },
    ),
  );

  void _addPhone() =>
      context.push('/profile/phone?returnTo=${Uri.encodeComponent(_here)}');

  void _openSettings() => ref.read(locationRepositoryProvider).openSettings();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = ref.watch(liveShutterControllerProvider);
    final v = value.value;
    return ScreenCode(
      ScreenCodes.instantAvailability,
      label: v == null
          ? null
          : v.locked
          ? 'locked'
          : v.needsTerms
          ? 'terms'
          : null,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const AppIcon(AppIcons.back),
                    onPressed: () => context.go('/bookings'),
                  ),
            title: Text(l.instantTitle),
          ),
          body: AsyncView<LiveShutterView>(
            value: value,
            skeleton: (_) => const _Skeleton(),
            onRetry: () {
              ref.invalidate(instantConfigProvider);
              ref.invalidate(liveShutterControllerProvider);
            },
            data: (context, v) => _content(context, v),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, LiveShutterView v) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final rows = v.reasonRows;
    // Mock `#S14.01-locked`: no note and no footer button; the price list
    // is then a reason row with its own small "Đồng ý bảng giá".
    final note = v.locked
        ? null
        : v.needsTerms
        ? l.priceListTermsNote
        : l.liveShutterNote;
    final Widget? footer = v.locked
        ? null
        : v.needsTerms
        ? AppButton.primary(
            l.priceListAccept,
            key: const Key('accept-price-list'),
            loading: v.busy,
            onPressed: v.busy ? null : () => _run(_controller.acceptPriceList),
          )
        : v.online
        ? AppButton.outline(
            l.liveShutterOffToday,
            key: const Key('live-shutter-off-today'),
            loading: v.busy,
            onPressed: v.busy ? null : () => _switch(false),
          )
        : null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              _SwitchCard(
                highlight: true,
                switchKey: const Key('live-shutter-switch'),
                title: l.liveShutterTitle,
                body: l.liveShutterBody,
                value: v.online,
                onChanged: v.canSwitch ? _switch : null,
              ),
              const SizedBox(height: AppSpace.s3),
              if (rows.isNotEmpty) ...[
                _ReasonsCard(
                  reasons: rows,
                  onAddPhone: _addPhone,
                  onOpenSettings: _openSettings,
                  onAcceptPriceList: v.busy
                      ? null
                      : () => _run(_controller.acceptPriceList),
                ),
                const SizedBox(height: AppSpace.s3),
              ],
              if (!v.locked && v.priceListAccepted) ...[
                _SwitchCard(
                  switchKey: const Key('help-ready-switch'),
                  title: l.helpReadyTitle,
                  body: l.helpReadyBody,
                  value: v.presence?.helpReady ?? false,
                  onChanged: v.busy
                      ? null
                      : (on) => _run(() => _controller.setHelpReady(on)),
                ),
                const SizedBox(height: AppSpace.s3),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        l.priceListTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Flexible(
                      child: Text(
                        v.priceListAccepted
                            ? l.priceListAccepted(v.config.priceListVersion)
                            : l.priceListNotAccepted(v.config.priceListVersion),
                        key: const Key('price-list-version'),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final p in v.config.packages) ...[
                _PriceRow(
                  package: p,
                  earningVnd: v.config.earningOf(p.priceVnd),
                ),
                const SizedBox(height: AppSpace.s2),
              ],
              if (note != null) ...[
                const SizedBox(height: AppSpace.s2),
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
        if (footer != null) AppFooterBar(child: footer),
      ],
    );
  }
}

/// Mock `.card` / `.card.hi` with a title, a line and a switch.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.switchKey,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
    this.highlight = false,
  });

  final Key switchKey;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final change = onChanged;
    return _Panel(
      highlight: highlight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      (highlight
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          // Mock `aria-label`: the switch reads as its card's title.
          Semantics(
            container: true,
            label: title,
            toggled: value,
            enabled: change != null,
            onTap: change == null ? null : () => change(!value),
            excludeSemantics: true,
            child: Switch(key: switchKey, value: value, onChanged: change),
          ),
        ],
      ),
    );
  }
}

/// Mock `.card` (glass, hairline) and `.card.hi` (surface, stronger edge,
/// larger radius).
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = highlight
        ? (dark ? AppColorsDark.surface : AppColors.surface)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final edge = highlight
        ? (dark ? AppColorsDark.borderStrong : AppColors.borderStrong)
        : Theme.of(context).colorScheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(
          highlight ? AppRadius.card : AppRadius.xl,
        ),
        border: Border.all(color: edge),
      ),
      child: Padding(padding: const EdgeInsets.all(AppSpace.s3), child: child),
    );
  }
}

/// "Chưa bật được Live Shutter": one row per missing condition, with a small
/// action where the app can help (phone, location).
class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({
    required this.reasons,
    required this.onAddPhone,
    required this.onOpenSettings,
    required this.onAcceptPriceList,
  });

  final List<LiveShutterReason> reasons;
  final VoidCallback onAddPhone;
  final VoidCallback onOpenSettings;
  final VoidCallback? onAcceptPriceList;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return _Panel(
      child: Column(
        key: const Key('live-shutter-reasons'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.liveShutterLockedTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final r in reasons) ...[
            const SizedBox(height: AppSpace.s2h),
            _ReasonRow(
              key: Key('reason-${r.code}'),
              icon: switch (r) {
                LiveShutterReason.notAcceptingOrders => AppIcons.verifiedUser,
                LiveShutterReason.phoneRequired => AppIcons.phone,
                LiveShutterReason.priceListNotAccepted => AppIcons.receipt,
                LiveShutterReason.outsideServiceArea => AppIcons.placeOff,
                LiveShutterReason.locationRequired => AppIcons.place,
              },
              text: switch (r) {
                LiveShutterReason.notAcceptingOrders =>
                  l.liveShutterReasonNotAccepting,
                LiveShutterReason.phoneRequired => l.liveShutterReasonPhone,
                LiveShutterReason.priceListNotAccepted =>
                  l.liveShutterReasonPriceList,
                LiveShutterReason.outsideServiceArea =>
                  l.liveShutterReasonOutside,
                LiveShutterReason.locationRequired =>
                  l.liveShutterReasonLocation,
              },
              action: switch (r) {
                LiveShutterReason.phoneRequired => (
                  l.liveShutterAddPhone,
                  onAddPhone,
                ),
                LiveShutterReason.locationRequired => (
                  l.liveShutterOpenSettings,
                  onOpenSettings,
                ),
                LiveShutterReason.priceListNotAccepted => (
                  l.priceListAccept,
                  onAcceptPriceList,
                ),
                _ => null,
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final (String, VoidCallback?)? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final a = action;
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: AppIcon(
                icon,
                size: 18,
                color: dark
                    ? AppColorsDark.foregroundSecondary
                    : AppColors.foregroundSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        if (a != null) ...[
          const SizedBox(width: AppSpace.s2),
          AppButton.outline(a.$1, size: AppButtonSize.xsmall, onPressed: a.$2),
        ],
      ],
    );
  }
}

/// One package of the price list (mock `.opt` without a radio): what the
/// customer pays and what the photographer gets.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.package, required this.earningVnd});

  final InstantPackage package;
  final int earningVnd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    const tabular = [FontFeature.tabularFigures()];
    final label = instantPackageText(l, package.durationMin, package.photos);
    final pays = instantShortMoney(package.priceVnd);
    final gets = instantShortMoney(earningVnd);
    return Semantics(
      container: true,
      label:
          '$label. ${l.priceListCustomerPays} $pays. ${l.priceListYouGet} $gets',
      excludeSemantics: true,
      child: DecoratedBox(
        key: Key('price-row-${package.code}'),
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: '${l.priceListCustomerPays} ',
                        children: [
                          TextSpan(
                            text: pays,
                            style: const TextStyle(fontFeatures: tabular),
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l.priceListYouGet,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  Text(
                    gets,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        AppSkeleton.card(height: 76),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.card(height: 68),
        const SizedBox(height: AppSpace.s4),
        AppSkeleton.line(width: 120),
        const SizedBox(height: AppSpace.s3),
        for (var i = 0; i < 3; i++) ...[
          AppSkeleton.card(height: 56),
          const SizedBox(height: AppSpace.s2),
        ],
      ],
    ),
  );
}
