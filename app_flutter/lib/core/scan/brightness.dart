// lib/core/scan/brightness.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart' as plugin;

/// Full brightness while a pass QR is on screen (S05.02-pass, S11.04-entry
/// full screen; Decision 19). The only `screen_brightness` import.
abstract class ScreenBrightness {
  /// Sets this app's brightness to the maximum.
  Future<void> raise();

  /// Gives the brightness back to the system.
  Future<void> restore();
}

/// The `screen_brightness` adapter. A platform without the plugin (tests,
/// desktop) or a refused call is ignored: the QR still shows.
class PluginScreenBrightness implements ScreenBrightness {
  const PluginScreenBrightness();

  @override
  Future<void> raise() async {
    try {
      await plugin.ScreenBrightness.instance.setApplicationScreenBrightness(1);
    } catch (_) {}
  }

  @override
  Future<void> restore() async {
    try {
      await plugin.ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}

/// Does nothing (previews).
class NoopScreenBrightness implements ScreenBrightness {
  const NoopScreenBrightness();

  @override
  Future<void> raise() async {}

  @override
  Future<void> restore() async {}
}

final screenBrightnessProvider = Provider<ScreenBrightness>(
  (ref) => const PluginScreenBrightness(),
);
