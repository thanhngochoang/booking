// lib/features/event_manage/ticket_scanner.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/event_manage/checkin_sheet.dart';

/// Reads a ticket code: a QR scan, or typed in. Returns null when the person
/// closes it. A port, so tests drive check-in without a camera.
abstract class TicketScanner {
  Future<String?> scan(BuildContext context);
}

/// The scanner of the app: the camera through the `PassScanner` port
/// (`core/scan`; S30.07 replaces this sheet in Task 9), with "Nhập mã
/// vé" always offered (a denied camera, or a code that will not scan).
final ticketScannerProvider = Provider<TicketScanner>(
  (ref) => const MobileScannerTicketScanner(),
);

class MobileScannerTicketScanner implements TicketScanner {
  const MobileScannerTicketScanner();

  @override
  Future<String?> scan(BuildContext context) => showAppSheet<String>(
    context,
    enableDrag: false,
    builder: (sheet) => _ScanSheet(sheet: sheet),
  );
}

class _ScanSheet extends ConsumerStatefulWidget {
  const _ScanSheet({required this.sheet});
  final BuildContext sheet;

  @override
  ConsumerState<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends ConsumerState<_ScanSheet> {
  late final PassScanner _scanner = ref.read(passScannerFactoryProvider)();
  StreamSubscription<String>? _codes;
  bool _manual = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _codes = _scanner.codes().listen(
      (raw) => _finish(normalizeTicketCode(raw)),
    );
  }

  @override
  void dispose() {
    unawaited(_codes?.cancel());
    _scanner.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done) {
      return;
    }
    _done = true;
    Navigator.of(widget.sheet).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ScreenCode(
      ScreenCodes.manageEvent,
      label: 'scan',
      child: SingleChildScrollView(
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
                l.checkinScanTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            if (!_manual)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _scanner.preview(
                    errorBuilder: (context, _) => ColoredBox(
                      color: theme.colorScheme.secondary,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s4),
                          child: Text(
                            l.checkinCameraOff,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s3),
            if (_manual)
              ManualTicketCodeEntry(onSubmit: _finish)
            else
              AppButton.outline(
                l.checkinManual,
                key: const Key('checkin-manual'),
                onPressed: () => setState(() => _manual = true),
              ),
          ],
        ),
      ),
    );
  }
}
