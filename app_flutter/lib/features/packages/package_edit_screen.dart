import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/day_pricing/price_rule_tile.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';
import 'package:photobooking/features/packages/package_edit_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S08.09, `/me/packages/new` and `/me/packages/:id`: name, duration, the
/// details and one "Giá ngày thường". Prices for other days are series, set on
/// S08.10: an existing package shows its series read-only with a link there.
/// Layout follows mock `#S08.09`.
///
/// [fromSetup] (`?from=setup`) is S08.01 step 2 adding or editing a package:
/// it has no series card, and saving returns to `/setup/2`.
class PackageEditScreen extends ConsumerStatefulWidget {
  const PackageEditScreen({super.key, this.packageId, this.fromSetup = false});

  /// Null for a new package.
  final String? packageId;
  final bool fromSetup;

  @override
  ConsumerState<PackageEditScreen> createState() => _PackageEditScreenState();
}

class _PackageEditScreenState extends ConsumerState<PackageEditScreen> {
  final _name = TextEditingController();
  final _edited = TextEditingController();
  final _delivery = TextEditingController();
  bool _seeded = false;

  PackageEditArgs get _args =>
      (id: widget.packageId, fromSetup: widget.fromSetup);

  PackageEditController get _c =>
      ref.read(packageEditControllerProvider(_args).notifier);

  @override
  void dispose() {
    _name.dispose();
    _edited.dispose();
    _delivery.dispose();
    super.dispose();
  }

  void _seed(PackageEditState s) {
    _seeded = true;
    _name.text = s.name;
    _edited.text = s.editedCount?.toString() ?? '';
    _delivery.text = s.deliveryDays?.toString() ?? '';
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.fromSetup ? '/setup/2' : '/me/packages');
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    final outcome = await _c.save();
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case SaveOutcome.saved:
        _say(widget.packageId == null ? l.packageAdded : l.packageSaved);
        _leave();
      case SaveOutcome.failed:
        _say(l.s0809_saveFailed);
      case SaveOutcome.invalid:
        break;
    }
  }

  /// Leaving with unsaved changes asks "Bỏ thay đổi?" first.
  Future<void> _askDiscard() async {
    final l = context.l10n;
    final discard = await showConfirmSheet(
      context,
      title: l.s0809_discardTitle,
      body: l.s0809_discardBody,
      confirmLabel: l.s0809_discardConfirm,
      keepLabel: l.s0809_discardKeep,
    );
    if (discard && mounted) {
      _leave();
    }
  }

  Future<void> _confirmHide() async {
    final l = context.l10n;
    var hidden = false;
    await showConfirmSheet(
      context,
      title: l.packageHideTitle,
      body: l.packageHideBody,
      confirmLabel: l.packageHideConfirm,
      keepLabel: l.packageKeep,
      danger: true,
      onConfirm: () async {
        hidden = await _c.hide();
      },
    );
    if (!mounted) {
      return;
    }
    if (hidden) {
      _say(l.packageHidden);
      _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(packageEditControllerProvider(_args));
    final s = async.value;
    if (s != null && !_seeded) {
      _seed(s);
    }
    final isNew = widget.packageId == null;
    return ScreenCode(
      ScreenCodes.editPackage,
      child: AuroraBackground(
        child: PopScope(
          canPop: s == null || !s.dirty || s.saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _askDiscard();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(isNew ? l.s0809_titleNew : l.s0809_titleEdit),
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AsyncView<PackageEditState>(
                      value: async,
                      onRetry: () =>
                          ref.invalidate(packageEditControllerProvider(_args)),
                      skeleton: (_) => const _Skeleton(),
                      error: (context, _, _) => Center(
                        child: ErrorState(
                          message: l.s0809_loadError,
                          onRetry: () => ref.invalidate(
                            packageEditControllerProvider(_args),
                          ),
                        ),
                      ),
                      data: (context, s) => _Form(
                        state: s,
                        packageId: widget.packageId,
                        showSeries: !widget.fromSetup,
                        name: _name,
                        edited: _edited,
                        delivery: _delivery,
                        controller: _c,
                      ),
                    ),
                  ),
                  if (s != null)
                    AppFooterBar(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton.primary(
                            l.s0809_save,
                            key: const Key('package-save'),
                            loading: s.saving,
                            onPressed: _save,
                          ),
                          if (!isNew && s.active)
                            AppButton.text(
                              l.s0809_hide,
                              key: const Key('package-hide'),
                              onPressed: s.saving ? null : _confirmHide,
                            ),
                        ],
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

String _errorText(PackageError e, AppLocalizations l) => switch (e) {
  PackageError.nameLength => l.s0809_nameLength,
  PackageError.priceRequired => l.s0809_priceRequired,
  PackageError.priceTooHigh => l.s0809_priceTooHigh,
  PackageError.durationRequired => l.packageDurationRequired,
  PackageError.countInvalid => l.packageCountInvalid,
  PackageError.daysInvalid => l.packageDaysInvalid,
};

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.packageId,
    required this.showSeries,
    required this.name,
    required this.edited,
    required this.delivery,
    required this.controller,
  });

  final PackageEditState state;
  final String? packageId;
  final bool showSeries;
  final TextEditingController name;
  final TextEditingController edited;
  final TextEditingController delivery;
  final PackageEditController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = state;
    final busy = s.saving;
    String? err(PackageEditField f) {
      final e = s.errors[f];
      return e == null ? null : _errorText(e, l);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('package-name'),
            controller: name,
            enabled: !busy,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.packageNameLabel,
              hintText: l.packageNameHint,
              errorText: err(PackageEditField.name),
            ),
            onChanged: controller.setName,
          ),
          const SizedBox(height: AppSpace.s3),
          Semantics(
            header: true,
            child: Text(
              l.packageDurationLabel,
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (final m in kPackageDurationsMinutes)
                AppChip(
                  key: Key('duration-$m'),
                  label: durationLabel(m, l),
                  selected: s.durationMinutes == m,
                  kind: AppChipKind.context,
                  enabled: !busy,
                  onChanged: (_) => controller.setDuration(m),
                ),
            ],
          ),
          if (err(PackageEditField.duration) case final e?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: Text(
                e,
                key: const Key('package-duration-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('package-edited'),
                  controller: edited,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: l.s0809_edited,
                    errorText: err(PackageEditField.edited),
                    errorMaxLines: 2,
                  ),
                  onChanged: (t) => controller.setEdited(int.tryParse(t)),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: TextField(
                  key: const Key('package-delivery'),
                  controller: delivery,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: InputDecoration(
                    labelText: l.packageDeliveryLabel,
                    suffixText: l.packageDeliverySuffix,
                    errorText: err(PackageEditField.delivery),
                    errorMaxLines: 2,
                  ),
                  onChanged: (t) => controller.setDelivery(int.tryParse(t)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          _PriceField(
            key: const Key('package-price'),
            label: l.s0809_price,
            value: s.price,
            error: err(PackageEditField.price),
            enabled: !busy,
            onChanged: controller.setPrice,
          ),
          if (showSeries) ...[
            const SizedBox(height: AppSpace.s3),
            _SeriesSection(packageId: packageId),
          ],
          const SizedBox(height: AppSpace.s3),
          Text(
            l.s0809_keepsOld,
            key: const Key('package-keeps-old'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? AppColorsDark.foregroundMuted
                  : AppColors.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The package's price series, read-only, with the way to S08.10 for this
/// package; a new package, or one without series, gets the single line that
/// says where to set them.
class _SeriesSection extends ConsumerWidget {
  const _SeriesSection({required this.packageId});

  final String? packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final id = packageId;
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final noRules = Text(
      l.s0809_noRules,
      key: const Key('package-no-rules'),
      style: theme.textTheme.bodySmall?.copyWith(color: muted),
    );
    if (id == null || uid == null) {
      return noRules;
    }
    final today = ref.watch(calendarTodayProvider);
    final rules = ref.watch(servicePriceRulesProvider((uid, id))).value;
    if (rules == null) {
      return const SizedBox.shrink();
    }
    final live = listedRules(rules, today);
    if (live.isEmpty) {
      return noRules;
    }
    return PriceRuleCard(
      key: const Key('package-rules'),
      children: [
        for (final r in live) PriceRuleTile(rule: r, today: today),
        InkWell(
          key: const Key('package-rules-link'),
          onTap: () => context.push('/me/day-pricing?service=$id'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l.s0809_rulesLink,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpace.s1),
                ExcludeSemantics(
                  child: AppIcon(
                    AppIcons.chevron,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A money field of whole đồng that follows [value]: typing reports the
/// number, and a value changed from outside shows at once.
class _PriceField extends StatefulWidget {
  const _PriceField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.enabled = true,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? error;
  final bool enabled;

  @override
  State<_PriceField> createState() => _PriceFieldState();
}

class _PriceFieldState extends State<_PriceField> {
  late final TextEditingController _c = TextEditingController(
    text: _text(widget.value),
  );

  static String _text(int? v) => v == null ? '' : groupVnd(v);

  @override
  void didUpdateWidget(_PriceField old) {
    super.didUpdateWidget(old);
    if (parseVnd(_c.text) != widget.value) {
      final t = _text(widget.value);
      _c.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    enabled: widget.enabled,
    keyboardType: TextInputType.number,
    inputFormatters: const [VndInputFormatter()],
    style: const TextStyle(
      fontFeatures: [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    ),
    decoration: InputDecoration(
      labelText: widget.label,
      suffixText: '₫',
      errorText: widget.error,
      errorMaxLines: 2,
    ),
    onChanged: (t) => widget.onChanged(parseVnd(t)),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.group(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        AppSkeleton.card(height: 56),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.card(height: 40),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.card(height: 120),
      ],
    ),
  );
}
