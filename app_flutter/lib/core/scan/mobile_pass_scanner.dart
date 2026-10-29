// lib/core/scan/mobile_pass_scanner.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

import 'package:photobooking/core/scan/pass_scanner.dart';

/// [PassScanner] over `mobile_scanner` 7: QR only, every read reported.
/// `noDuplicates` never reports a code again until the camera stops, so a
/// code read while a sheet was up was lost for good (final fix A-I1); the
/// scan screen ignores the code it just handled while it stays in view.
class MobilePassScanner implements PassScanner {
  MobilePassScanner()
    : _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.normal,
      );

  final MobileScannerController _controller;

  /// The detection speed reports a code on every read (tests).
  @visibleForTesting
  bool get reportsEveryRead =>
      _controller.detectionSpeed == DetectionSpeed.normal;
  late final Stream<String> _codes = _controller.barcodes
      .expand((capture) => capture.barcodes)
      .map((b) => b.rawValue?.trim() ?? '')
      .where((raw) => raw.isNotEmpty)
      .asBroadcastStream();

  @override
  Stream<String> codes() => _codes;

  @override
  Future<void> toggleTorch() => _controller.toggleTorch();

  @override
  Widget preview({
    Widget Function(BuildContext context, PassScannerFailure failure)?
    errorBuilder,
  }) => MobileScanner(
    controller: _controller,
    errorBuilder: errorBuilder == null
        ? null
        : (context, error) => errorBuilder(context, switch (error.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              PassScannerFailure.permissionDenied,
            MobileScannerErrorCode.unsupported =>
              PassScannerFailure.unsupported,
            _ => PassScannerFailure.unavailable,
          }),
  );

  @override
  Future<void> openSettings() async {
    try {
      await perm.openAppSettings();
    } catch (_) {}
  }

  @override
  void dispose() => unawaited(_controller.dispose());
}
