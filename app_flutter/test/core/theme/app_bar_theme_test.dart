// test/core/theme/app_bar_theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

void main() {
  for (final theme in [buildDarkTheme(), buildLightTheme()]) {
    test('sub-screen bars: centred serif 17 (${theme.brightness.name})', () {
      expect(theme.appBarTheme.centerTitle, isTrue);
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 17);
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, AppFonts.display);
    });
  }
}
