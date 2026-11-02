// lib/features/organizer/widgets/access_editor.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';

/// One reference price line being edited.
class AccessFeeRow {
  AccessFeeRow({String label = '', int? amount})
    : label = TextEditingController(text: label),
      amount = TextEditingController(
        text: amount == null ? '' : groupVnd(amount),
      );

  final TextEditingController label;
  final TextEditingController amount;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

/// The `spots.access` block of S30.03 "Thông tin": ticketed or not, up to six
/// reference prices (label and VND) and a note of at most 120 characters
/// (the domain's `validateAccess`).
class AccessEditorController extends ChangeNotifier {
  AccessEditorController(SpotAccess? access)
    : ticketed = access?.type == SpotAccessType.ticket,
      note = TextEditingController(text: access?.note ?? '') {
    for (final f in access?.fees ?? const <AccessFee>[]) {
      rows.add(AccessFeeRow(label: f.label, amount: f.amountVnd));
    }
    if (rows.isEmpty) rows.add(AccessFeeRow());
  }

  bool ticketed;
  final List<AccessFeeRow> rows = [];
  final TextEditingController note;

  /// Shown after a failed [build].
  bool feeError = false;
  bool noteError = false;

  bool get canAdd => rows.length < accessFeesMax;

  void setTicketed(bool v) {
    ticketed = v;
    notifyListeners();
  }

  void add() {
    if (!canAdd) return;
    rows.add(AccessFeeRow());
    notifyListeners();
  }

  void removeAt(int i) {
    rows.removeAt(i).dispose();
    if (rows.isEmpty) rows.add(AccessFeeRow());
    notifyListeners();
  }

  /// The block to send, or null (with the error flags set) when a line has
  /// a label without a price (or the reverse) or the note is too long. Empty
  /// lines are dropped.
  SpotAccess? build() {
    feeError = false;
    noteError = note.text.trim().length > accessNoteMax;
    final fees = <AccessFee>[];
    for (final r in rows) {
      final label = r.label.text.trim();
      final amount = parseVnd(r.amount.text);
      if (label.isEmpty && r.amount.text.trim().isEmpty) continue;
      if (label.isEmpty || amount == null || amount <= 0) {
        feeError = true;
        continue;
      }
      fees.add(AccessFee(label: label, amountVnd: amount));
    }
    notifyListeners();
    if (feeError || noteError) return null;
    return SpotAccess(
      type: ticketed ? SpotAccessType.ticket : SpotAccessType.open,
      fees: ticketed ? fees : const [],
      note: note.text.trim(),
    );
  }

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    note.dispose();
    super.dispose();
  }
}

class AccessEditor extends StatelessWidget {
  const AccessEditor({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final AccessEditorController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('access-ticketed'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.s3003_ticketed),
              value: c.ticketed,
              onChanged: enabled ? c.setTicketed : null,
            ),
            if (c.ticketed) ...[
              for (final (i, r) in c.rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: Key('access-label-$i'),
                          controller: r.label,
                          enabled: enabled,
                          maxLength: 40,
                          decoration: InputDecoration(
                            labelText: l.s3003_feeLabel,
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: Key('access-amount-$i'),
                          controller: r.amount,
                          enabled: enabled,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [VndInputFormatter()],
                          decoration: InputDecoration(
                            labelText: l.s3003_feeAmount,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('access-remove-$i'),
                        tooltip: l.s3003_removeFee,
                        icon: const AppIcon(AppIcons.close),
                        onPressed: enabled ? () => c.removeAt(i) : null,
                      ),
                    ],
                  ),
                ),
              if (c.feeError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Text(
                    l.s3003_feeInvalid,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.text(
                  l.s3003_addFee,
                  key: const Key('access-add'),
                  onPressed: enabled && c.canAdd ? c.add : null,
                ),
              ),
              if (!c.canAdd)
                Text(
                  l.s3003_feesMax,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mutedForeground,
                  ),
                ),
            ],
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('access-note'),
              controller: c.note,
              enabled: enabled,
              maxLength: accessNoteMax,
              decoration: InputDecoration(
                labelText: l.s3003_feeNote,
                errorText: c.noteError ? l.s3003_noteLength : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
