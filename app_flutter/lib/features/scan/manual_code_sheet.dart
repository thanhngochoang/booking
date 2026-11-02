// S30.07 "Nhập mã 8 ký tự": the code typed when the camera cannot read it.
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/scan/scan_controller.dart';

/// Opens the sheet; returns the code to send (8 characters, or a legacy
/// `VE-XXXX-MMDD` ticket code, in capitals), or null when closed.
Future<String?> showManualCodeSheet(BuildContext context) =>
    showAppSheet<String>(
      context,
      builder: (sheet) => const ScreenCode(
        ScreenCodes.scanPass,
        label: 'manual',
        child: ManualCodeSheet(),
      ),
    );

class ManualCodeSheet extends StatefulWidget {
  const ManualCodeSheet({super.key});

  @override
  State<ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<ManualCodeSheet> {
  final _controller = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = scanCodeOf(_controller.text);
    if (code == null) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final empty = _controller.text.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l.s3007_manual, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('scan-manual-code'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _tried = false),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l.s3007_manual,
              hintText: l.s3007_manualHint,
              errorText: _tried ? l.s3007_manualInvalid : null,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          // S30.07 has no gradient button (spec §10).
          AppButton.outline(
            l.s3007_manualSubmit,
            key: const Key('scan-manual-submit'),
            onPressed: empty ? null : _submit,
          ),
        ],
      ),
    );
  }
}
