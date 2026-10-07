// lib/features/earnings/widgets/bank_picker_sheet.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';

/// Whether [bank] matches [query] by short name, full name or code, ignoring
/// case and Vietnamese diacritics.
bool bankMatches(VnBank bank, String query) {
  final q = foldVietnamese(query.trim());
  if (q.isEmpty) return true;
  return foldVietnamese(bank.shortName).contains(q) ||
      foldVietnamese(bank.name).contains(q) ||
      foldVietnamese(bank.code).contains(q);
}

/// Opens the searchable bank list; returns the chosen bank or null. The sheet
/// has a text field, so dragging it down is off (it would fight scrolling and
/// typing); the barrier tap and Back still close it.
Future<VnBank?> showBankPicker(BuildContext context, {String? selected}) {
  return showAppSheet<VnBank>(
    context,
    enableDrag: false,
    builder: (_) => _BankPicker(selected: selected),
  );
}

class _BankPicker extends StatefulWidget {
  const _BankPicker({this.selected});

  final String? selected;

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final banks = [
      for (final b in vnBanks)
        if (bankMatches(b, _query)) b,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.payoutAccountBankPick,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('bank-search'),
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l.payoutAccountBankSearch,
              prefixIcon: const AppIcon(AppIcons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpace.s2),
          Flexible(
            child: banks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpace.s6),
                    child: Text(
                      l.payoutAccountBankNone,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: banks.length,
                    itemBuilder: (context, i) {
                      final b = banks[i];
                      final picked = b.code == widget.selected;
                      return Semantics(
                        button: true,
                        selected: picked,
                        label: '${b.shortName}, ${b.name}',
                        excludeSemantics: true,
                        child: InkWell(
                          key: Key('bank-${b.code}'),
                          onTap: () => Navigator.of(context).pop(b),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.s2,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${b.shortName} · ${b.name}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  if (picked) const AppIcon(AppIcons.check),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
