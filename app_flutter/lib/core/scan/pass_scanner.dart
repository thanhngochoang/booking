// lib/core/scan/pass_scanner.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/scan/mobile_pass_scanner.dart';

/// Why the camera shows no preview (S30.07: a primer for [permissionDenied],
/// "Nhập mã 8 ký tự" for the rest).
enum PassScannerFailure { permissionDenied, unsupported, unavailable }

/// The camera port of S30.07 (Decision 18): QR codes as they are read, the
/// torch, and the preview to put on screen. `MobilePassScanner` is the only
/// adapter (and the only `mobile_scanner` import); tests use a fake.
abstract class PassScanner {
  /// Each code read once (trimmed, non-empty), as a broadcast stream.
  Stream<String> codes();

  /// S30.07 "Đèn pin".
  Future<void> toggleTorch();

  /// The live preview; [errorBuilder] draws a failed camera.
  Widget preview({
    Widget Function(BuildContext context, PassScannerFailure failure)?
    errorBuilder,
  });

  void dispose();
}

/// Makes the scanner a screen owns (one per open scan screen or sheet).
final passScannerFactoryProvider = Provider<PassScanner Function()>(
  (ref) => MobilePassScanner.new,
);
