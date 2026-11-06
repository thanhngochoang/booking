import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/pricing/special_days.dart';
import 'package:photobooking/features/packages/packages_actions.dart';
import 'package:photobooking/features/packages/special_day_rules.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S08.10's add/edit sheet (mock `#S08.10-edit`). Pass [range] to edit it,
/// which adds the red "Xoá khoảng ngày". [existingCount] is how many ranges
/// the provider has. A save or delete closes the sheet and says so in a
/// SnackBar of the screen below.
Future<void> showSpecialDaySheet(
  BuildContext context, {
  SpecialDayRange? range,
  required int existingCount,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showAppSheet<String>(
    context,
    builder: (_) => SpecialDaySheet(range: range, existingCount: existingCount),
  );
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class SpecialDaySheet extends ConsumerStatefulWidget {
  const SpecialDaySheet({super.key, this.range, required this.existingCount});

  final SpecialDayRange? range;
  final int existingCount;

  @override
  ConsumerState<SpecialDaySheet> createState() => _SpecialDaySheetState();
}

class _SpecialDaySheetState extends ConsumerState<SpecialDaySheet> {
  late final _name = TextEditingController(text: widget.range?.name);
  late DateTime? _from = widget.range == null
      ? null
      : parseDayKey(widget.range!.from);
  late DateTime? _to = widget.range == null
      ? null
      : parseDayKey(widget.range!.to);
  late DateTime _month = monthOf(_from ?? ref.read(calendarTodayProvider));
  bool _saving = false;
  bool _failed = false;

  bool get _editing => widget.range != null;

  DateTime get _today => ref.read(calendarTodayProvider);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pick(DateTime day) {
    setState(() {
      final from = _from;
      if (from == null || _to != null || day.isBefore(from)) {
        _from = day;
        _to = null;
      } else {
        _to = day;
      }
    });
  }

  SpecialDayError? get _error => specialDayError(
    name: _name.text,
    from: _from,
    to: _to ?? _from,
    today: _today,
    existingCount: widget.existingCount,
    isNew: !_editing,
    keepFrom: widget.range == null ? null : parseDayKey(widget.range!.from),
  );

  String? _errorText(AppLocalizations l, SpecialDayError e) => switch (e) {
    // Shown under the name field, and only once a name was typed.
    SpecialDayError.name => null,
    SpecialDayError.past => l.s0810_errorPast,
    SpecialDayError.tooLong => l.s0810Old_errorTooLong,
    SpecialDayError.tooFar => l.s0810Old_errorTooFar,
    SpecialDayError.limit => l.s0810Old_errorLimit,
  };

  Future<void> _save() async {
    final from = _from;
    if (_saving || from == null || _error != null) {
      return;
    }
    final l = context.l10n;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await ref
        .read(packagesActionsProvider)
        .saveRange(
          SpecialDayRange(
            id: widget.range?.id ?? '',
            name: _name.text.trim(),
            from: dayKeyOf(from),
            to: dayKeyOf(_to ?? from),
          ),
        );
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop(l.s0810Old_saved);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final id = widget.range!.id;
    final confirmed = await showConfirmSheet(
      context,
      title: l.s0810Old_deleteTitle,
      body: l.s0810_deleteBody,
      confirmLabel: l.s0810_deleteConfirm,
      keepLabel: l.s0810_deleteKeep,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final ok = await ref.read(packagesActionsProvider).deleteRange(id);
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop(l.s0810Old_deleted);
    } else {
      setState(() => _failed = true);
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
    final today = _today;
    final keep = widget.range == null ? null : parseDayKey(widget.range!.from);
    final earliest = keep != null && keep.isBefore(today) ? keep : today;
    final from = _from;
    final to = _to;
    final picked = from == null
        ? const <DateTime>[]
        : daysBetween(from, to ?? from);
    final error = _error;
    final rangeError = error == null ? null : _errorText(l, error);
    final nameLen = _name.text.trim().length;
    final nameError = _name.text.isNotEmpty && nameLen < kSpecialNameMin
        ? l.s0810_errorName
        : null;
    final withSpecial = [
      for (final p in ref.watch(myPackagesProvider).value ?? const [])
        if (p.active && p.specialPrice != null) p,
    ].length;

    Widget dateBox(String label, DateTime? d, Key key) => Expanded(
      child: InputDecorator(
        key: key,
        decoration: InputDecoration(labelText: label),
        child: Text(
          d == null ? l.s0810_pickDay : formatDay(d),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: d == null ? muted : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
                      _editing ? l.s0810_editTitle : l.s0810_addTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('special-day-close'),
                  tooltip: l.s0810_close,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('special-day-name'),
              controller: _name,
              enabled: !_saving,
              maxLength: kSpecialNameMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.s0810_fieldName,
                errorText: nameError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              children: [
                dateBox(l.s0810_fieldFrom, from, const Key('special-day-from')),
                const SizedBox(width: AppSpace.s2),
                dateBox(l.s0810_fieldTo, to, const Key('special-day-to')),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            AvailabilityCalendar(
              key: const Key('special-day-calendar'),
              month: _month,
              states: const {},
              selectedDays: picked.toSet(),
              today: today,
              minDate: earliest,
              // Past the 365-day limit stays pickable so the rule can say so.
              maxDate: today.add(const Duration(days: 2 * 365)),
              onSelect: _saving ? null : _pick,
              onMonthChanged: (m) => setState(() => _month = m),
            ),
            if (picked.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s2),
              Text(
                withSpecial == 0
                    ? l.s0810_affectsNone(picked.length)
                    : l.s0810_affects(picked.length, withSpecial),
                key: const Key('special-day-affects'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            if (rangeError != null || _failed)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s2),
                child: Text(
                  rangeError ?? l.s0808_saveFailed,
                  key: const Key('special-day-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.s0810_save,
              key: const Key('special-day-save'),
              loading: _saving,
              onPressed: _saving || from == null || error != null
                  ? null
                  : _save,
            ),
            if (_editing)
              AppButton.text(
                l.s0810Old_delete,
                key: const Key('special-day-delete'),
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
