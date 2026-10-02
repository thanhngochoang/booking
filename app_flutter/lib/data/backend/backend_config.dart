import 'package:flutter/foundation.dart';

/// Region of every callable Cloud Function: Singapore, the closest region to
/// Vietnam. Same value as `REGION` in firebase/functions/src/config.ts.
const functionsRegion = 'asia-southeast1';

/// Where the local Firebase Emulator Suite listens (ports of
/// firebase/firebase.json).
class EmulatorConfig {
  const EmulatorConfig(this.host);

  final String host;

  int get authPort => 9099;
  int get firestorePort => 8080;
  int get functionsPort => 5001;
  int get storagePort => 9199;
}

final _host = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9.\-]*[A-Za-z0-9])?$');

/// The emulators are used only by debug builds started with
/// `--dart-define=USE_EMULATORS=true`; otherwise null (cloud backend).
/// Default host: `10.0.2.2` on Android (the emulator's alias for this Mac),
/// `127.0.0.1` elsewhere (iOS Simulator). `--dart-define=EMULATOR_HOST=…`
/// overrides it: `10.0.3.2` for Genymotion, the Mac's LAN IP for a real
/// device, `127.0.0.1` with `adb reverse`.
EmulatorConfig? resolveEmulatorConfig({
  required bool debugBuild,
  required bool useEmulators,
  required String hostOverride,
  required TargetPlatform platform,
}) {
  if (!debugBuild || !useEmulators) return null;
  final override = hostOverride.trim();
  if (override.isNotEmpty) {
    if (!_host.hasMatch(override)) {
      throw ArgumentError.value(
        override,
        'EMULATOR_HOST',
        'expected a host name or IPv4 address, without scheme, port or path',
      );
    }
    return EmulatorConfig(override);
  }
  return EmulatorConfig(
    platform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1',
  );
}

/// [resolveEmulatorConfig] for this build and device.
EmulatorConfig? emulatorConfigFromEnvironment() => resolveEmulatorConfig(
  debugBuild: kDebugMode,
  useEmulators: const bool.fromEnvironment('USE_EMULATORS'),
  hostOverride: const String.fromEnvironment('EMULATOR_HOST'),
  platform: defaultTargetPlatform,
);
