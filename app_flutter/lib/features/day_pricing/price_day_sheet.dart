import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/day_pricing.dart'
    show kMaxPriceVnd, weekdayOf;
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/features/day_pricing/day_pricing_controller.dart';
import 'package:photobooking/features/day_pricing/rule_draft.dart';
import 'package:photobooking/features/day_pricing/rule_text.dart';

/// A series that covers the day but lost to a higher one (R3), with the price
/// it would have given.
typedef BeatenRule = ({PriceRule rule, int price});

/// S08.10-day (mock `#S08.10-day`; spec §5.5, R4): the sheet for one day of a
/// series. [rule] is the series whose price the day has, [dayPrice] that
/// price (an exception's price when the day has one), [beaten] the series
/// that cover the day but were replaced by [rule]. A save or delete closes
/// the sheet and says so in a SnackBar of the screen below; the answer is
/// whether something was saved or deleted.
Future<bool> showPriceDaySheet(
  BuildContext context, {
  required ServicePackage package,
  required DateTime day,
  required PriceRule rule,
  required int dayPrice,
  List<BeatenRule> beaten = const [],
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showAppSheet<String>(
    context,
    builder: (_) => PriceDaySheet(
      package: package,
      day: day,
      rule: rule,
      dayPrice: dayPrice,
      beaten: beaten,
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

/// How far an edit of a day reaches (R4).
enum PriceDayScope { day, following, all }

class PriceDaySheet extends ConsumerStatefulWidget {
  const PriceDaySheet({
    super.key,
    required this.package,
    required this.day,
    required this.rule,
    required this.dayPrice,
    this.beaten = const [],
  });

  final ServicePackage package;
  final DateTime day;
  final PriceRule rule;
  final int dayPrice;
  final List<BeatenRule> beaten;

  @override
  ConsumerState<PriceDaySheet> createState() => _PriceDaySheetState();
}

class _PriceDaySheetState extends ConsumerState<PriceDaySheet> {
  late final _price = TextEditingController(text: groupVnd(widget.dayPrice));
  PriceDayScope _scope = PriceDayScope.day;
  bool _saving = false;
  PriceRuleError? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  int? get _priceValue => parseVnd(_price.text);

  RuleFormError? get _priceError {
    final p = _priceValue;
    if (p == null || p < 1) {
      return RuleFormError.price;
    }
    return p > kMaxPriceVnd ? RuleFormError.priceHigh : null;
  }

  PriceRuleInput _wholeSeries(int price) {
    final r = widget.rule;
    return PriceRuleInput(
      serviceId: r.serviceId,
      price: price,
      repeat: r.repeat,
      name: r.name,
      lunar: r.lunar,
      from: r.from,
      to: r.to,
      weekdays: r.weekdays,
      template: r.template,
    );
  }

  Future<void> _finish(
    Future<PriceRuleResult> Function() job,
    String Function() message,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await job();
    if (!mounted) {
      return;
    }
    if (result.ok) {
      Navigator.of(context).pop(message());
    } else {
      setState(() {
        _saving = false;
        _error = result.error;
      });
    }
  }

  Future<void> _save() {
    final price = _priceValue;
    final actions = ref.read(dayPricingActionsProvider);
    final rule = widget.rule;
    final l = context.l10n;
    if (_saving || price == null || _priceError != null) {
      return Future.value();
    }
    return _finish(
      () => switch (_scope) {
        PriceDayScope.day => actions.setException(
          rule.id,
          widget.day,
          PriceException.custom(price),
        ),
        PriceDayScope.following => actions.splitRule(
          rule.id,
          widget.day,
          price: price,
        ),
        PriceDayScope.all => actions.saveRule(
          _wholeSeries(price),
          ruleId: rule.id,
        ),
      },
      () => l.s0810_saved,
    );
  }

  /// The red action under "Lưu": drops the day, ends the series from the day,
  /// or (after a confirmation) deletes it, by the radio picked.
  Future<void> _remove() async {
    if (_saving) {
      return;
    }
    final l = context.l10n;
    final actions = ref.read(dayPricingActionsProvider);
    final rule = widget.rule;
    switch (_scope) {
      case PriceDayScope.day:
        return _finish(
          () => actions.setException(
            rule.id,
            widget.day,
            const PriceException.skip(),
          ),
          () => l.s0810_saved,
        );
      case PriceDayScope.following:
        return _finish(
          () => actions.splitRule(rule.id, widget.day),
          () => l.s0810_saved,
        );
      case PriceDayScope.all:
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
        return _finish(
          () => actions.deleteRule(rule.id),
          () => l.s0810_deleted,
        );
    }
  }

  String? _errorLine() {
    final l = context.l10n;
    final e = _error;
    if (e == null) {
      return null;
    }
    return switch (e.code) {
      PriceRuleErrorCode.exceptionLimit => l.s0810_errorExceptionLimit,
      PriceRuleErrorCode.ruleLimit => l.s0810_errorLimit,
      PriceRuleErrorCode.invalidArgument when e.field == 'price' =>
        l.s0810_errorPrice,
      _ => l.s0808_saveFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final field = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final border = dark ? AppColorsDark.border : AppColors.border;
    final rule = widget.rule;
    final title = ruleTitle(l, rule);
    final priceError = _price.text.isEmpty || _priceError == null
        ? null
        : (_priceError == RuleFormError.priceHigh
              ? l.s0810_errorPriceHigh
              : l.s0810_errorPrice);
    final removeLabel = switch (_scope) {
      PriceDayScope.day => l.s0810_removeDay,
      PriceDayScope.following => l.s0810_endFrom,
      PriceDayScope.all => l.s0810_delete,
    };
    final errorLine = _errorLine();

    Widget scopeRow(PriceDayScope scope, String label) {
      final on = _scope == scope;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        label: label,
        excludeSemantics: true,
        onTap: _saving ? null : () => setState(() => _scope = scope),
        child: InkWell(
          key: Key('price-day-scope-${scope.name}'),
          onTap: _saving ? null : () => setState(() => _scope = scope),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                AppIcon(
                  on ? AppIcons.radioOn : AppIcons.radioOff,
                  color: on ? theme.colorScheme.primary : muted,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      );
    }

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
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.s0810_dayTitle(
                        l.calendarWeekdayLong(weekdayOf(widget.day).name),
                        '${widget.day.day}',
                        '${widget.day.month}',
                      ),
                      key: const Key('price-day-title'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Flexible(
                  child: Text(
                    widget.package.name,
                    key: const Key('price-day-package'),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
                IconButton(
                  key: const Key('price-day-close'),
                  tooltip: l.s0810_close,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: field,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2h,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: AppIcon(
                        rule.repeat == PriceRepeat.none
                            ? AppIcons.event
                            : AppIcons.repeat,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title · ${formatMoney(rule.price)}',
                            key: const Key('price-day-rule'),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            rulePattern(l, rule),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final b in widget.beaten)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s1),
                child: Text(
                  l.s0810_overridden(
                    ruleTitle(l, b.rule),
                    ruleShortPrice(b.price),
                    title,
                  ),
                  key: Key('price-day-beaten-${b.rule.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('price-day-price'),
              controller: _price,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: const [VndInputFormatter()],
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: l.s0810_dayPrice,
                suffixText: '₫',
                errorText: priceError,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpace.s3),
            Semantics(
              header: true,
              child: Text(
                l.s0810_applyScope,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppText.xs2,
                  color: muted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            DecoratedBox(
              decoration: BoxDecoration(
                color: field,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
                child: Column(
                  children: [
                    scopeRow(PriceDayScope.day, l.s0810_scopeDay),
                    Divider(height: 1, color: border),
                    scopeRow(PriceDayScope.following, l.s0810_scopeFollowing),
                    Divider(height: 1, color: border),
                    scopeRow(PriceDayScope.all, l.s0810_scopeAll(title)),
                  ],
                ),
              ),
            ),
            if (errorLine != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s2),
                child: Text(
                  errorLine,
                  key: const Key('price-day-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.s0810_save,
              key: const Key('price-day-save'),
              loading: _saving,
              onPressed: _saving || _priceError != null ? null : _save,
            ),
            AppButton.text(
              removeLabel,
              key: const Key('price-day-remove'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _saving ? null : _remove,
            ),
          ],
        ),
      ),
    );
  }
}
