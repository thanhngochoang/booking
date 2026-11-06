import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/features/packages/package_edit_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S08.09, `/me/packages/new` and `/me/packages/:id`: name, duration, the
/// price table ("Hai mức giá" or "Từng ngày"), the special-day price and a
/// preview of the next 7 days. Layout follows mocks `#S08.09` and
/// `#S08.09-perday`.
///
/// [fromSetup] (`?from=setup`) is S08.01 step 2 adding or editing a package:
/// saving returns to `/setup/2`.
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

  Future<void> _setMode(PriceMode mode) async {
    final l = context.l10n;
    if (_c.setMode(mode) != ModeChange.needsCollapseConfirm) {
      return;
    }
    final collapse = await showConfirmSheet(
      context,
      title: l.s0809_toTwoLevels,
      confirmLabel: l.s0809_toTwoLevelsConfirm,
      keepLabel: l.s0809_toTwoLevelsKeep,
      danger: false,
    );
    if (collapse && mounted) {
      _c.collapseToTwoLevels();
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
                      name: _name,
                      edited: _edited,
                      delivery: _delivery,
                      controller: _c,
                      onMode: _setMode,
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

String _dayName(Weekday w, AppLocalizations l) => switch (w) {
  Weekday.mon => l.s0809_dayMon,
  Weekday.tue => l.s0809_dayTue,
  Weekday.wed => l.s0809_dayWed,
  Weekday.thu => l.s0809_dayThu,
  Weekday.fri => l.s0809_dayFri,
  Weekday.sat => l.s0809_daySat,
  Weekday.sun => l.s0809_daySun,
};

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.name,
    required this.edited,
    required this.delivery,
    required this.controller,
    required this.onMode,
  });

  final PackageEditState state;
  final TextEditingController name;
  final TextEditingController edited;
  final TextEditingController delivery;
  final PackageEditController controller;
  final ValueChanged<PriceMode> onMode;

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
          const SizedBox(height: AppSpace.s5),
          Semantics(
            header: true,
            child: Text(l.s0809_prices, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpace.s2),
          Semantics(
            label: l.s0809_modeLabel,
            container: true,
            child: SegmentedTabs<PriceMode>(
              options: [
                SegmentOption(
                  value: PriceMode.twoLevels,
                  label: l.s0809_modeTwo,
                  enabled: !busy,
                ),
                SegmentOption(
                  value: PriceMode.perDay,
                  label: l.s0809_modePerDay,
                  enabled: !busy,
                ),
              ],
              value: s.mode,
              onChanged: onMode,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          if (s.mode == PriceMode.twoLevels)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PriceField(
                    key: const Key('price-weekday'),
                    label: l.s0809_weekday,
                    value: s.weekday,
                    error: err(PackageEditField.weekday),
                    enabled: !busy,
                    onChanged: controller.setWeekday,
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: _PriceField(
                    key: const Key('price-weekend'),
                    label: l.s0809_weekend,
                    value: s.weekend,
                    error: err(PackageEditField.weekend),
                    enabled: !busy,
                    onChanged: controller.setWeekend,
                  ),
                ),
              ],
            )
          else
            _PerDayTable(state: s, controller: controller),
          const SizedBox(height: AppSpace.s3),
          _SpecialSection(
            state: s,
            controller: controller,
            error: err(PackageEditField.special),
          ),
          const SizedBox(height: AppSpace.s3),
          _Preview(state: s),
        ],
      ),
    );
  }
}

/// A money field of whole đồng that follows [value]: typing reports the
/// number, and a value changed from outside (the weekend following the
/// weekday price) shows at once.
class _PriceField extends StatefulWidget {
  const _PriceField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.error,
    this.enabled = true,
    this.compact = false,
    this.emphasis = false,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final String? label;
  final String? semanticLabel;
  final String? error;
  final bool enabled;
  final bool compact;

  /// Shown in the accent colour (a day priced unlike Monday).
  final bool emphasis;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = TextField(
      controller: _c,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: const [VndInputFormatter()],
      textAlign: widget.compact ? TextAlign.end : TextAlign.start,
      style: TextStyle(
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: widget.emphasis ? FontWeight.w700 : null,
        color: widget.emphasis ? theme.colorScheme.primary : null,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: '₫',
        errorText: widget.error,
        errorMaxLines: 2,
        isDense: widget.compact,
      ),
      onChanged: (t) => widget.onChanged(parseVnd(t)),
    );
    final label = widget.semanticLabel;
    return label == null ? field : Semantics(label: label, child: field);
  }
}

/// "Từng ngày": Thứ 2 to Chủ nhật, one price each; a price unlike Monday's
/// takes the accent colour.
class _PerDayTable extends StatelessWidget {
  const _PerDayTable({required this.state, required this.controller});

  final PackageEditState state;
  final PackageEditController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final monday = state.perDay[Weekday.mon];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: dark ? AppColorsDark.border : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s1,
        ),
        child: Column(
          children: [
            for (final w in Weekday.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpace.s2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _dayName(w, l),
                            style: theme.textTheme.titleSmall,
                          ),
                          if (w.isWeekend)
                            Text(
                              l.s0809_weekendTag,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: dark
                                    ? AppColorsDark.foregroundMuted
                                    : AppColors.foregroundMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 148,
                      child: _PriceField(
                        key: Key('price-day-${w.name}'),
                        semanticLabel: _dayName(w, l),
                        value: state.perDay[w],
                        compact: true,
                        enabled: !state.saving,
                        emphasis:
                            w != Weekday.mon &&
                            state.perDay[w] != null &&
                            state.perDay[w] != monday,
                        error: state.errors[dayField(w)] == null
                            ? null
                            : _errorText(state.errors[dayField(w)]!, l),
                        onChanged: (v) => controller.setDay(w, v),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Giá riêng ngày đặc biệt" switch, its price and "Áp cho … · Xem".
class _SpecialSection extends ConsumerWidget {
  const _SpecialSection({
    required this.state,
    required this.controller,
    required this.error,
  });

  final PackageEditState state;
  final PackageEditController controller;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final on = state.specialOn;
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final year = ref.watch(calendarTodayProvider).year;
    final holidays = ref.watch(holidaysProvider(year)).value?.length ?? 0;
    final ranges = uid == null
        ? 0
        : ref.watch(specialDaysProvider(uid)).value?.length ?? 0;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.s0809_special, style: theme.textTheme.titleSmall),
                  if (on)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${l.s0809_specialApplies(holidays, ranges)} · ',
                          key: const Key('special-applies'),
                          style: metaStyle,
                        ),
                        InkWell(
                          key: const Key('special-see'),
                          onTap: () => context.push('/me/special-days'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 32),
                            child: Align(
                              widthFactor: 1,
                              child: Text(
                                l.s0809_see,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(l.s0809_specialOff, style: metaStyle),
                ],
              ),
            ),
            Semantics(
              label: l.s0809_special,
              child: Switch(
                key: const Key('special-switch'),
                value: on,
                onChanged: state.saving ? null : controller.setSpecial,
              ),
            ),
          ],
        ),
        if (on) ...[
          const SizedBox(height: AppSpace.s2),
          _PriceField(
            key: const Key('price-special'),
            label: l.s0809_specialField,
            value: state.specialPrice,
            error: error,
            enabled: !state.saving,
            onChanged: controller.setSpecialPrice,
          ),
        ],
      ],
    );
  }
}

/// The next 7 days at the typed prices, and what a customer pays on the
/// dearest of them.
class _Preview extends ConsumerWidget {
  const _Preview({required this.state});

  final PackageEditState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = state.previewService;
    if (service == null) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final today = ref.watch(calendarTodayProvider);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime.utc(today.year, today.month, today.day + i),
    ];
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final holidays = <Holiday>[
      for (final y in {days.first.year, days.last.year})
        ...?ref.watch(holidaysProvider(y)).value,
    ];
    final ranges = uid == null
        ? const <SpecialDayRange>[]
        : ref.watch(specialDaysProvider(uid)).value ??
              const <SpecialDayRange>[];
    final special = specialDaysOf(holidays, ranges);
    final priced = <({DateTime day, int amount, DayPriceKind kind})>[
      for (final d in days)
        (
          day: d,
          amount: priceForDay(service, d, special).amount,
          kind: priceForDay(service, d, special).kind,
        ),
    ];
    var best = priced.first;
    for (final p in priced) {
      if (p.amount > best.amount) {
        best = p;
      }
    }
    final range = priceRange(service);
    final weekendFill = dark
        ? AppColorsDark.primarySubtle
        : AppColors.primarySubtle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l.s0809_previewLabel,
          container: true,
          child: Wrap(
            spacing: AppSpace.s1,
            runSpacing: AppSpace.s1,
            children: [
              for (final p in priced)
                _PreviewChip(
                  key: Key('preview-${dayKeyOf(p.day)}'),
                  text: _chipText(l, p.day, p.amount, p.kind),
                  fill: p.kind == DayPriceKind.weekday ? null : weekendFill,
                  outlined: p.kind == DayPriceKind.special,
                  bold: p.kind != DayPriceKind.weekday,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(
          l.s0809_preview(formatDay(best.day), formatMoney(best.amount)),
          key: const Key('preview-note'),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (state.mode == PriceMode.perDay && range.min != range.max)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Text(
              l.s0809_perDayNote(
                '${formatMoney(range.min, short: true)}–'
                '${formatMoney(range.max, short: true)}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }

  static String _chipText(
    AppLocalizations l,
    DateTime day,
    int amount,
    DayPriceKind kind,
  ) {
    final label = '${weekdayLabel(day.weekday)} ${day.day}';
    final price = formatMoney(amount, short: true);
    return kind == DayPriceKind.special
        ? l.s0809_previewSpecial(label, price)
        : l.s0809_previewDay(label, price);
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    super.key,
    required this.text,
    required this.fill,
    required this.outlined,
    required this.bold,
  });

  final String text;
  final Color? fill;
  final bool outlined;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: outlined
            ? Border.all(color: theme.colorScheme.primary)
            : Border.all(color: Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: bold ? FontWeight.w600 : null,
            fontFeatures: const [FontFeature.tabularFigures()],
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
