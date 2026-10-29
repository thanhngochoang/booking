// test/support/fake_pass_scanner.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:photobooking/core/core.dart';

/// A camera-less [PassScanner]: a test [emit]s codes and can make the preview
/// fail with [failure].
class FakePassScanner implements PassScanner {
  final _codes = StreamController<String>.broadcast();

  /// Set before the preview builds to draw the error state instead.
  PassScannerFailure? failure;
  int torchToggles = 0;
  int settingsOpened = 0;
  bool disposed = false;

  void emit(String code) => _codes.add(code);

  @override
  Stream<String> codes() => _codes.stream;

  @override
  Future<void> toggleTorch() async => torchToggles++;

  @override
  Widget preview({
    Widget Function(BuildContext context, PassScannerFailure failure)?
    errorBuilder,
  }) {
    final f = failure;
    if (f != null && errorBuilder != null) {
      return Builder(builder: (context) => errorBuilder(context, f));
    }
    return const SizedBox.expand(key: Key('fake-pass-scanner-preview'));
  }

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  void dispose() {
    disposed = true;
    unawaited(_codes.close());
  }
}

/// Records brightness calls instead of touching the screen.
class FakeScreenBrightness implements ScreenBrightness {
  final List<String> calls = [];

  bool get raised => calls.isNotEmpty && calls.last == 'raise';

  @override
  Future<void> raise() async => calls.add('raise');

  @override
  Future<void> restore() async => calls.add('restore');
}
