// lib/core/scan/mobile_pass_scanner.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:photobooking/core/scan/pass_scanner.dart';

/// [PassScanner] over `mobile_scanner` 7: QR only, each code reported once.
class MobilePassScanner implements PassScanner {
  MobilePassScanner()
    : _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );

  final MobileScannerController _controller;
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
  void dispose() => unawaited(_controller.dispose());
}
