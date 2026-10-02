import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// A sheet's answer. `null` returned by the sheet means "dismissed, change
/// nothing"; `Picked(null)` means "clear this filter".
class Picked<T> {
  const Picked(this.value);
  final T? value;
}

const _budgets = [1000000, 2000000, 5000000, 10000000];
const _ratings = [4.0, 4.5, 4.8];

/// How far ahead a day can be picked.
const _dateHorizon = Duration(days: 365);

Widget _title(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.fromLTRB(AppSpace.s5, 0, AppSpace.s5, AppSpace.s2),
  child: Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  ),
);

Widget _sheet(BuildContext context, String title, List<Widget> rows) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(context, title),
      Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            0,
            AppSpace.s4,
            AppSpace.s5,
          ),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
          itemBuilder: (_, i) => rows[i],
        ),
      ),
    ],
  );
}

Future<Picked<String>?> pickSpecialty(BuildContext context, {String? current}) {
  final l = context.l10n;
  return showAppSheet<Picked<String>>(
    context,
    builder: (sheet) => _sheet(sheet, l.findServiceTitle, [
      AppOptionTile(
        label: l.findServiceAll,
        selected: current == null,
        onTap: () => Navigator.of(sheet).pop(const Picked<String>(null)),
      ),
      for (final o in kSpecialties)
        AppOptionTile(
          label: o.labelVi,
          selected: current == o.id,
          onTap: () => Navigator.of(sheet).pop(Picked<String>(o.id)),
        ),
    ]),
  );
}

Future<Picked<int>?> pickBudget(BuildContext context, {int? current}) {
  final l = context.l10n;
  return showAppSheet<Picked<int>>(
    context,
    builder: (sheet) => _sheet(sheet, l.findPriceTitle, [
      AppOptionTile(
        label: l.findPriceAny,
        selected: current == null,
        onTap: () => Navigator.of(sheet).pop(const Picked<int>(null)),
      ),
      for (final b in _budgets)
        AppOptionTile(
          label: l.findPriceUnder(formatMoney(b, short: true)),
          selected: current == b,
          onTap: () => Navigator.of(sheet).pop(Picked<int>(b)),
        ),
    ]),
  );
}

Future<Picked<double>?> pickMinRating(BuildContext context, {double? current}) {
  final l = context.l10n;
  return showAppSheet<Picked<double>>(
    context,
    builder: (sheet) => _sheet(sheet, l.findRatingTitle, [
      AppOptionTile(
        label: l.findRatingAny,
        selected: current == null,
        onTap: () => Navigator.of(sheet).pop(const Picked<double>(null)),
      ),
      for (final r in _ratings)
        AppOptionTile(
          label: l.findRatingMin(formatRating(r)),
          selected: current == r,
          onTap: () => Navigator.of(sheet).pop(Picked<double>(r)),
        ),
    ]),
  );
}

/// A month calendar from [today] for a year, with "Xoá ngày" and "Xong".
Future<Picked<DateTime>?> pickDate(
  BuildContext context, {
  DateTime? current,
  required DateTime today,
}) => showAppSheet<Picked<DateTime>>(
  context,
  builder: (sheet) => _DateSheet(current: current, today: today),
);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.current, required this.today});
  final DateTime? current;
  final DateTime today;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _picked = calendarDay(widget.current ?? widget.today);
  late DateTime _month = monthOf(_picked);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = calendarDay(widget.today);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(context, l.findDateTitle),
          AvailabilityCalendar(
            month: _month,
            states: const {},
            selected: _picked,
            today: today,
            minDate: today,
            maxDate: today.add(_dateHorizon),
            onSelect: (d) => setState(() => _picked = d),
            onMonthChanged: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: AppSpace.s3),
          AppButton.outline(
            l.findDateClear,
            key: const Key('date-clear'),
            onPressed: widget.current == null
                ? null
                : () => Navigator.of(context).pop(const Picked<DateTime>(null)),
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.primary(
            l.findDateDone,
            key: const Key('date-done'),
            onPressed: () => Navigator.of(context).pop(
              Picked<DateTime>(
                DateTime(_picked.year, _picked.month, _picked.day),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
