import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/day_pricing/day_pricing_controller.dart';
import 'package:photobooking/features/day_pricing/rule_draft.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S08.10-new and S08.10-repeat (mock `#S08.10-new`, `#S08.10-repeat`; spec
/// §5.4): the "Đặt giá" sheet that creates a series, or edits the whole of
/// [rule]. [from]/[to] are the days the calendar picked (a tapped day, a
/// dragged range, today); [templates] shows the template chips (the button
/// opened it with no selection). A save or delete closes the sheet and says
/// so in a SnackBar of the screen below; the answer is whether something was
/// saved or deleted.
Future<bool> showPriceRuleSheet(
  BuildContext context, {
  required String serviceId,
  PriceRule? rule,
  DateTime? from,
  DateTime? to,
  bool templates = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showAppSheet<String>(
    context,
    builder: (_) => PriceRuleSheet(
      serviceId: serviceId,
      rule: rule,
      from: from,
      to: to,
      templates: templates,
    ),
  );
  if (message == null) {
    return false;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return true;
}

/// Where the dates of a series can be picked: not before today (nor before the
/// series itself when editing), up to the longest one-off range that can
/// start two years ahead. The sheet says what is wrong with a day outside.
const _kPickDaysAhead = kMaxAheadDays + kMaxSpanDays;

class PriceRuleSheet extends ConsumerStatefulWidget {
  const PriceRuleSheet({
    super.key,
    required this.serviceId,
    this.rule,
    this.from,
    this.to,
    this.templates = false,
  });

  final String serviceId;
  final PriceRule? rule;
  final DateTime? from;
  final DateTime? to;
  final bool templates;

  @override
  ConsumerState<PriceRuleSheet> createState() => _PriceRuleSheetState();
}

class _PriceRuleSheetState extends ConsumerState<PriceRuleSheet> {
  final _price = TextEditingController();
  final _name = TextEditingController();
  late bool _repeats;
  PriceRepeat _cycle = PriceRepeat.yearly;
  bool _lunar = false;
  late DateTime _from;
  late DateTime _to;
  Set<Weekday> _weekdays = {};
  bool _weekdaysTouched = false;
  String? _template;
  String? _keepFrom;
  String? _keepTo;
  bool _applyAll = false;
  bool _saving = false;
  bool _failed = false;
  RuleFormError? _serverError;

  PriceRule? get _rule => widget.rule;
  bool get _editing => _rule != null;
  DateTime get _today => ref.read(calendarTodayProvider);

  @override
  void initState() {
    super.initState();
    final today = ref.read(calendarTodayProvider);
    final rule = widget.rule;
    if (rule == null) {
      _from = widget.from ?? today;
      _to = widget.to ?? _from;
      _repeats = false;
      _weekdays = weekdaysBetween(_from, _to);
      return;
    }
    _price.text = groupVnd(rule.price);
    _name.text = rule.name ?? '';
    _template = rule.template;
    _from = today;
    _to = today;
    switch (rule.repeat) {
      case PriceRepeat.none:
        _repeats = false;
        _from = parseDayKey(rule.from ?? '') ?? today;
        _to = parseDayKey(rule.to ?? '') ?? _from;
        _weekdays = weekdaysBetween(_from, _to);
      case PriceRepeat.yearly:
        _repeats = true;
        _cycle = PriceRepeat.yearly;
        _lunar = rule.lunar;
        final from = rule.from;
        final to = rule.to;
        if (from != null && to != null) {
          final next = nextYearlyOccurrence(
            from: from,
            to: to,
            lunar: rule.lunar,
            today: today,
          );
          if (next != null) {
            _from = next.from;
            _to = next.to;
          }
          _keepFrom = from;
          _keepTo = to;
        }
        _weekdays = weekdaysBetween(_from, _to);
      case PriceRepeat.weekly:
        _repeats = true;
        _cycle = PriceRepeat.weekly;
        _weekdays = {...rule.weekdays};
        _weekdaysTouched = true;
    }
  }

  @override
  void dispose() {
    _price.dispose();
    _name.dispose();
    super.dispose();
  }

  /// A change of any field: the error the server gave no longer applies.
  void _edit(VoidCallback change) {
    setState(() {
      change();
      _serverError = null;
      _failed = false;
    });
  }

  void _setDates(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    _keepFrom = null;
    _keepTo = null;
    if (!_weekdaysTouched) {
      _weekdays = weekdaysBetween(from, to);
    }
  }

  Future<void> _pickDay({required bool isFrom}) async {
    final l = context.l10n;
    final today = _today;
    final earliest = [
      today,
      _from,
      _to,
    ].reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = DateTime.utc(
      today.year,
      today.month,
      today.day + _kPickDaysAhead,
    );
    final picked = await showAppDatePicker(
      context,
      initial: isFrom ? _from : _to,
      first: isFrom ? earliest : _from,
      last: latest.isBefore(_from) ? _from : latest,
      title: isFrom ? l.s0810_from : l.s0810_to,
      today: today,
    );
    if (picked == null || !mounted) {
      return;
    }
    final day = calendarDay(picked);
    _edit(() {
      if (isFrom) {
        _setDates(day, _to.isBefore(day) ? day : _to);
      } else {
        _setDates(_from, day.isBefore(_from) ? _from : day);
      }
    });
  }

  void _useTemplate(PriceRuleTemplate t) {
    final next = nextYearlyOccurrence(
      from: t.from,
      to: t.to,
      lunar: t.lunar,
      today: _today,
    );
    _edit(() {
      _name.text = t.name;
      _repeats = true;
      _cycle = PriceRepeat.yearly;
      _lunar = t.lunar;
      _template = t.code;
      if (next != null) {
        _setDates(next.from, next.to);
      }
      _keepFrom = t.from;
      _keepTo = t.to;
    });
  }

  RuleFormValues get _values => RuleFormValues(
    serviceId: widget.serviceId,
    price: parseVnd(_price.text),
    name: _name.text,
    repeats: _repeats,
    cycle: _cycle,
    lunar: _lunar,
    from: _from,
    to: _to,
    weekdays: _weekdays,
    template: _template,
    keepFrom: _keepFrom,
    keepTo: _keepTo,
  );

  /// The lunar month (R14) a picked day falls in when it is a leap one, for
  /// the note; the stored series (dates not picked) has none.
  int? get _leapMonth {
    if (!_lunar || _keepFrom != null) {
      return null;
    }
    final a = lunarPickOf(_from);
    final b = lunarPickOf(_to);
    return a.leap ? a.month : (b.leap ? b.month : null);
  }

  RuleFormError? _localError(
    List<ServicePackage> packages,
    List<PriceRule> rules,
  ) {
    int countOf(String serviceId) =>
        rules.where((r) => r.serviceId == serviceId).length;
    return ruleFormError(
      _values,
      today: _today,
      creating: !_editing,
      serviceIds: [for (final p in packages) p.id],
      ruleCount: countOf(widget.serviceId),
      applyToAll: _applyAll,
      otherCounts: [
        for (final p in packages)
          if (p.id != widget.serviceId) countOf(p.id),
      ],
    );
  }

  Future<void> _save() async {
    final input = _values.toInput();
    if (_saving || input == null) {
      return;
    }
    final l = context.l10n;
    setState(() {
      _saving = true;
      _failed = false;
      _serverError = null;
    });
    final result = await ref
        .read(dayPricingActionsProvider)
        .saveRule(input, ruleId: _rule?.id, applyToAll: _applyAll && !_editing);
    if (!mounted) {
      return;
    }
    if (result.ok) {
      Navigator.of(context).pop(l.s0810_saved);
      return;
    }
    final error = result.error!;
    setState(() {
      _saving = false;
      _serverError = ruleFormErrorOfServer(error);
      _failed = _serverError == null;
    });
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final rule = _rule;
    if (rule == null) {
      return;
    }
    final confirmed = await showConfirmSheet(
      context,
      title: l.s0810_deleteTitle,
      body: l.s0810_deleteBody,
      confirmLabel: l.s0810_deleteConfirm,
      keepLabel: l.s0810_deleteKeep,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    final result = await ref
        .read(dayPricingActionsProvider)
        .deleteRule(rule.id);
    if (!mounted) {
      return;
    }
    if (result.ok) {
      Navigator.of(context).pop(l.s0810_deleted);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  String _errorText(AppLocalizations l, RuleFormError e) => switch (e) {
    RuleFormError.price => l.s0810_errorPrice,
    RuleFormError.priceHigh => l.s0810_errorPriceHigh,
    RuleFormError.weekdays => l.s0810_errorWeekdays,
    RuleFormError.leapDay => l.s0810_errorLeapDay,
    RuleFormError.past => l.s0810_errorPast,
    RuleFormError.tooLong => l.s0810_errorTooLong,
    RuleFormError.tooFar => l.s0810_errorTooFar,
    RuleFormError.limit => l.s0810_errorLimit,
    RuleFormError.exceptionLimit => l.s0810_errorExceptionLimit,
    RuleFormError.nameContact => l.s0810_errorNameContact,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final packages = ref.watch(myPackagesProvider).value ?? const [];
    final rules = uid == null
        ? const <PriceRule>[]
        : ref.watch(providerPriceRulesProvider(uid)).value ?? const [];
    final package = packages.where((p) => p.id == widget.serviceId).firstOrNull;
    final packageName = package?.name ?? '';
    final used = {
      for (final r in rules)
        if (r.serviceId == widget.serviceId && r.template != null) r.template,
    };
    final error = _localError(packages, rules);
    final shown = error ?? _serverError;
    final priceError =
        shown?.spot == RuleFormErrorSpot.price && _price.text.isNotEmpty
        ? _errorText(l, shown!)
        : null;
    String? at(RuleFormErrorSpot spot) =>
        shown?.spot == spot ? _errorText(l, shown!) : null;
    final showDates = !_repeats || _cycle == PriceRepeat.yearly;
    final canApplyToAll = !_editing && packages.length > 1;

    Widget errorLine(String text, Key key) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Text(
        text,
        key: key,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );

    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.s0810_sheetTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('price-rule-close'),
                  tooltip: l.s0810_close,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (widget.templates && !_editing) ...[
              const SizedBox(height: AppSpace.s1),
              SingleChildScrollView(
                key: const Key('price-rule-templates'),
                scrollDirection: Axis.horizontal,
                child: Semantics(
                  container: true,
                  label: l.s0810_templates,
                  child: Row(
                    children: [
                      for (final t in priceRuleTemplates) ...[
                        AppChip(
                          key: Key('price-rule-template-${t.code}'),
                          label: t.name,
                          kind: AppChipKind.context,
                          selected: _template == t.code,
                          enabled: !used.contains(t.code),
                          onChanged: (_) => _useTemplate(t),
                        ),
                        const SizedBox(width: AppSpace.s2),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('price-rule-price'),
              controller: _price,
              enabled: !_saving,
              autofocus: !_editing,
              keyboardType: TextInputType.number,
              inputFormatters: const [VndInputFormatter()],
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: l.s0810_priceFor(packageName),
                suffixText: '₫',
                errorText: priceError,
                errorMaxLines: 2,
              ),
              onChanged: (_) => _edit(() {}),
            ),
            if (showDates) ...[
              const SizedBox(height: AppSpace.s2),
              Row(
                children: [
                  Expanded(
                    child: _DayField(
                      key: const Key('price-rule-from'),
                      label: l.s0810_from,
                      day: _from,
                      onTap: _saving ? null : () => _pickDay(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: _DayField(
                      key: const Key('price-rule-to'),
                      label: l.s0810_to,
                      day: _to,
                      onTap: _saving ? null : () => _pickDay(isFrom: false),
                    ),
                  ),
                ],
              ),
              if (at(RuleFormErrorSpot.dates) case final text?)
                errorLine(text, const Key('price-rule-error-dates')),
            ],
            _SwitchRow(
              key: const Key('price-rule-repeat'),
              icon: AppIcons.repeat,
              title: l.s0810_repeat,
              value: _repeats,
              onChanged: _saving ? null : (on) => _edit(() => _repeats = on),
            ),
            if (_repeats)
              Padding(
                key: const Key('price-rule-repeat-section'),
                padding: const EdgeInsets.only(left: AppSpace.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PopupMenuButton<PriceRepeat>(
                      key: const Key('price-rule-cycle'),
                      enabled: !_saving,
                      position: PopupMenuPosition.under,
                      onSelected: (c) => _edit(() => _cycle = c),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: PriceRepeat.weekly,
                          child: Text(l.s0810_weekly),
                        ),
                        PopupMenuItem(
                          value: PriceRepeat.yearly,
                          child: Text(l.s0810_yearly),
                        ),
                      ],
                      child: _DropdownField(
                        label: l.s0810_cycle,
                        value: _cycle == PriceRepeat.weekly
                            ? l.s0810_weekly
                            : l.s0810_yearly,
                      ),
                    ),
                    if (_cycle == PriceRepeat.yearly) ...[
                      _SwitchRow(
                        key: const Key('price-rule-lunar'),
                        title: l.s0810_lunar,
                        subtitle: _YearlyHelper(
                          values: _values,
                          leapMonth: _leapMonth,
                        ),
                        value: _lunar,
                        onChanged: _saving
                            ? null
                            : (on) => _edit(() {
                                _lunar = on;
                                _keepFrom = null;
                                _keepTo = null;
                              }),
                      ),
                      if (at(RuleFormErrorSpot.repeat) case final text?)
                        errorLine(text, const Key('price-rule-error-repeat')),
                    ] else ...[
                      const SizedBox(height: AppSpace.s2),
                      _WeekdayToggles(
                        selected: _weekdays,
                        enabled: !_saving,
                        onToggle: (w) => _edit(() {
                          _weekdaysTouched = true;
                          _weekdays = _weekdays.contains(w)
                              ? ({..._weekdays}..remove(w))
                              : {..._weekdays, w};
                        }),
                      ),
                      if (at(RuleFormErrorSpot.weekdays) case final text?)
                        errorLine(text, const Key('price-rule-error-weekdays')),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('price-rule-name'),
              controller: _name,
              enabled: !_saving,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.s0810_name,
                counterText: '',
                errorText: at(RuleFormErrorSpot.name),
                errorMaxLines: 2,
              ),
              onChanged: (_) => _edit(() {}),
            ),
            if (canApplyToAll) ...[
              const SizedBox(height: AppSpace.s2),
              PopupMenuButton<bool>(
                key: const Key('price-rule-apply'),
                enabled: !_saving,
                position: PopupMenuPosition.under,
                onSelected: (all) => _edit(() => _applyAll = all),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: false,
                    child: Text(l.s0810_applyOne(packageName)),
                  ),
                  PopupMenuItem(value: true, child: Text(l.s0810_applyAll)),
                ],
                child: _DropdownField(
                  label: l.s0810_applyTo,
                  value: _applyAll
                      ? l.s0810_applyAll
                      : l.s0810_applyOne(packageName),
                  icon: AppIcons.inventory,
                ),
              ),
            ],
            if (at(RuleFormErrorSpot.form) case final text?)
              errorLine(text, const Key('price-rule-error-form'))
            else if (_failed)
              errorLine(l.s0808_saveFailed, const Key('price-rule-error-form')),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.s0810_save,
              key: const Key('price-rule-save'),
              loading: _saving,
              onPressed: _saving || error != null ? null : _save,
            ),
            if (_editing)
              AppButton.text(
                l.s0810_delete,
                key: const Key('price-rule-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _saving ? null : _delete,
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled switch (mock `.irow2` with `.sw2`): the row toggles it. Not a
/// `SwitchListTile`: a ListTile refuses to sit under the sheet's coloured box.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData? icon;
  final String title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final toggle = onChanged == null ? null : () => onChanged!(!value);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: title,
      excludeSemantics: true,
      onTap: toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
            child: Row(
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, color: muted),
                  const SizedBox(width: AppSpace.s3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.bodyLarge),
                      ?subtitle,
                    ],
                  ),
                ),
                IgnorePointer(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A "Từ" / "Tới" box: opens the date picker.
class _DayField extends StatelessWidget {
  const _DayField({
    super.key,
    required this.label,
    required this.day,
    required this.onTap,
  });

  final String label;
  final DateTime day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          weekdayDayText(day, year: true),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A dropdown's closed face (the popup menu around it opens the choices).
class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : AppIcon(icon!, color: muted),
        suffixIcon: AppIcon(AppIcons.unfoldMore, color: muted),
      ),
      child: Text(value, style: theme.textTheme.bodyMedium),
    );
  }
}

/// The line under "Theo âm lịch": the days the series repeats on, and for a
/// lunar one when it falls next year and the leap-month note (R14).
class _YearlyHelper extends StatelessWidget {
  const _YearlyHelper({required this.values, required this.leapMonth});

  final RuleFormValues values;

  /// The leap month a picked day falls in, or null.
  final int? leapMonth;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final from = values.yearlyFrom;
    final to = values.yearlyTo;
    final a = monthDayText(l, from, lunar: false);
    final b = monthDayText(l, to, lunar: false);
    final same = from == to;
    String line;
    if (!values.lunar) {
      line = same ? l.s0810_solarLineOne(a) : l.s0810_solarLine(a, b);
    } else {
      final next = yearlyOccurrenceOf(
        from: from,
        to: to,
        lunar: true,
        year: solarToLunar(values.from).year + 1,
      );
      final nextText = next == null ? '' : dayRangeText(next.from, next.to);
      line = same
          ? l.s0810_lunarLineOne(a, nextText)
          : l.s0810_lunarLine(a, b, nextText);
    }
    final style = theme.textTheme.bodySmall?.copyWith(
      color: muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line, key: const Key('price-rule-helper'), style: style),
        if (leapMonth case final m?)
          Text(
            l.s0810_leapNote('$m'),
            key: const Key('price-rule-leap-note'),
            style: style,
          ),
      ],
    );
  }
}

/// Seven round toggles T2 … CN for a weekly series.
class _WeekdayToggles extends StatelessWidget {
  const _WeekdayToggles({
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final Set<Weekday> selected;
  final bool enabled;
  final ValueChanged<Weekday> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final field = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    return Row(
      key: const Key('price-rule-weekdays'),
      children: [
        for (final w in Weekday.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected.contains(w),
              enabled: enabled,
              label: l.calendarWeekdayLong(w.name),
              excludeSemantics: true,
              onTap: enabled ? () => onToggle(w) : null,
              child: GestureDetector(
                key: Key('price-rule-weekday-${w.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? () => onToggle(w) : null,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected.contains(w) ? scheme.primary : field,
                        border: Border.all(
                          color: selected.contains(w)
                              ? scheme.primary
                              : scheme.outline,
                        ),
                      ),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: Text(
                            l.calendarWeekdayShort(w.name),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: AppText.xs,
                              fontWeight: FontWeight.w600,
                              color: selected.contains(w)
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
