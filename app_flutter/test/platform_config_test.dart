import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 11+ can see a dialer and a browser (url_launcher canLaunchUrl)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final queries =
        RegExp(r'<queries>[\s\S]*?</queries>').firstMatch(manifest)?.group(0) ??
        '';
    for (final scheme in ['tel', 'https']) {
      expect(
        RegExp(
          '<action android:name="android.intent.action.VIEW"\\s*/>\\s*<data android:scheme="$scheme"\\s*/>',
        ).hasMatch(queries),
        isTrue,
        reason: '<queries> needs a VIEW intent for $scheme',
      );
    }
  });

  test('iOS lists tel so canLaunchUrl can tell a phone from a tablet', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    // The array is shared with other schemes (Facebook login on iOS adds
    // fbapi…), so only check that tel is in it.
    final array = RegExp(
      r'<key>LSApplicationQueriesSchemes</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(plist)?.group(1);
    expect(array, isNotNull);
    expect(array, contains('<string>tel</string>'));
  });

  test('url_launcher is a dependency', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('url_launcher:'));
  });
}
