import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

void main() {
  test('light theme uses token colors and fonts', () {
    final t = buildLightTheme();
    expect(t.colorScheme.primary, AppColors.primary);
    expect(t.scaffoldBackgroundColor, AppColors.background);
    expect(t.textTheme.bodyMedium!.fontFamily, AppFonts.body);
    expect(t.textTheme.headlineMedium!.fontFamily, AppFonts.display);
    expect(t.useMaterial3, isTrue);
  });
  test('dark theme is dark and keeps the accent readable', () {
    final t = buildDarkTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, AppColorsDark.primary);
    expect(t.scaffoldBackgroundColor, AppColorsDark.background);
  });
}
