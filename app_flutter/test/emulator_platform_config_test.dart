import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'debug builds may use cleartext to reach the emulators; release may not',
    () {
      final debug = File('android/app/src/debug/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        debug,
        contains(
          'android:networkSecurityConfig="@xml/network_security_config"',
        ),
      );
      final config = File(
        'android/app/src/debug/res/xml/network_security_config.xml',
      ).readAsStringSync();
      expect(config, contains('cleartextTrafficPermitted="true"'));

      final main = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(main, isNot(contains('usesCleartextTraffic')));
      expect(main, isNot(contains('networkSecurityConfig')));
      expect(
        File('android/app/src/main/res/xml/network_security_config.xml')
            .existsSync(),
        isFalse,
      );
    },
  );

  test('iOS allows plain HTTP to the local network only', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(
        r'<key>NSAppTransportSecurity</key>\s*<dict>\s*<key>NSAllowsLocalNetworking</key>\s*<true/>\s*</dict>',
      ).hasMatch(plist),
      isTrue,
    );
    expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
  });

  test('the emulator plugins are dependencies', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('cloud_functions:'));
    expect(pubspec, contains('firebase_storage:'));
  });
}
