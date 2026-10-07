// lib/features/event_manage/checkin_sheet.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// `ve-7k2q-0420 ` → `VE-7K2Q-0420`.
String normalizeTicketCode(String raw) => raw.trim().toUpperCase();

/// What checking a ticket in came to.
enum CheckinOutcome { ok, invalid, used, failed }

class CheckinResult {
  const CheckinResult(this.outcome, {this.name = '', this.quantity = 0});

  final CheckinOutcome outcome;
  final String name;
  final int quantity;
}

/// "Nhập mã vé": a code field and "Kiểm tra". [onSubmit] gets the code
/// trimmed and in capitals. Used inside the scan sheet and on its own.
class ManualTicketCodeEntry extends StatefulWidget {
  const ManualTicketCodeEntry({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<ManualTicketCodeEntry> createState() => _ManualTicketCodeEntryState();
}

class _ManualTicketCodeEntryState extends State<ManualTicketCodeEntry> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = normalizeTicketCode(_controller.text);
    if (code.isNotEmpty) {
      widget.onSubmit(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('checkin-code'),
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l.checkinManual,
            hintText: l.checkinManualHint,
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        AppButton.primary(
          l.checkinManualSubmit,
          key: const Key('checkin-submit'),
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

/// The answer after a scan: "Đã vào · {name} · {count} vé", "Vé không hợp lệ"
/// or "Vé đã dùng". Returns true when the host chose "Quét tiếp".
Future<bool> showCheckinResultSheet(
  BuildContext context,
  CheckinResult result,
) async {
  final again = await showAppSheet<bool>(
    context,
    builder: (sheet) => _CheckinResultBody(result: result, sheet: sheet),
  );
  return again ?? false;
}

class _CheckinResultBody extends StatelessWidget {
  const _CheckinResultBody({required this.result, required this.sheet});

  final CheckinResult result;
  final BuildContext sheet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ok = result.outcome == CheckinOutcome.ok;
    final text = switch (result.outcome) {
      CheckinOutcome.ok => l.checkinOk(result.name, result.quantity),
      CheckinOutcome.invalid => l.checkinInvalid,
      CheckinOutcome.used => l.checkinUsed,
      CheckinOutcome.failed => l.checkinFailed,
    };
    final color = ok ? AppColors.success : theme.colorScheme.error;
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
            liveRegion: true,
            child: Row(
              children: [
                AppIcon(
                  ok ? AppIcons.checkCircle : AppIcons.error,
                  color: color,
                  selected: true,
                  size: AppIconSize.lg,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Text(
                    text,
                    key: const Key('checkin-result'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.checkinNext,
            key: const Key('checkin-next'),
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    );
  }
}
