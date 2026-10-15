import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/backend/backend_config.dart';

EmulatorConfig? _resolve({
  bool debug = true,
  bool use = true,
  String host = '',
  TargetPlatform platform = TargetPlatform.android,
}) => resolveEmulatorConfig(
  debugBuild: debug,
  useEmulators: use,
  hostOverride: host,
  platform: platform,
);

void main() {
  test('off unless a debug build asks for it', () {
    expect(_resolve(use: false), isNull);
    expect(_resolve(debug: false), isNull);
    expect(_resolve(debug: false, host: '192.168.1.20'), isNull);
  });

  test('default host: 10.0.2.2 on Android, 127.0.0.1 on the iOS Simulator', () {
    expect(_resolve()!.host, '10.0.2.2');
    expect(_resolve(platform: TargetPlatform.iOS)!.host, '127.0.0.1');
    expect(_resolve(platform: TargetPlatform.macOS)!.host, '127.0.0.1');
  });

  test('EMULATOR_HOST wins: Genymotion, real device, adb reverse', () {
    expect(_resolve(host: '10.0.3.2')!.host, '10.0.3.2');
    expect(
      _resolve(host: ' 192.168.1.20 ', platform: TargetPlatform.iOS)!.host,
      '192.168.1.20',
    );
    expect(_resolve(host: 'my-mac.local')!.host, 'my-mac.local');
    expect(_resolve(host: '127.0.0.1')!.host, '127.0.0.1');
  });

  test('a host with a scheme, port, path or space is refused', () {
    for (final bad in [
      'http://10.0.2.2',
      '10.0.2.2:8080',
      '10.0.2.2/x',
      'a b',
    ]) {
      expect(() => _resolve(host: bad), throwsArgumentError, reason: bad);
    }
  });

  test('ports match firebase/firebase.json', () {
    final config = jsonDecode(
      File('firebase/firebase.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final emulators = config['emulators'] as Map<String, dynamic>;
    int port(String name) =>
        (emulators[name] as Map<String, dynamic>)['port'] as int;
    final c = _resolve()!;
    expect(c.authPort, port('auth'));
    expect(c.firestorePort, port('firestore'));
    expect(c.functionsPort, port('functions'));
    expect(c.storagePort, port('storage'));
  });

  test('the client calls the region the server deploys to', () {
    final server = File('firebase/functions/src/config.ts').readAsStringSync();
    expect(server, contains("REGION = '$functionsRegion'"));
  });

  test('no adapter uses the default (us-central1) Functions instance', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              RegExp(r'FirebaseFunctions\.instance\b')
                  .hasMatch(f.readAsStringSync()),
        )
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
