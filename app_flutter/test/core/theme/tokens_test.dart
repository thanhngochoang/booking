import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

void main() {
  test('semantic colors resolve primitive references', () {
    expect(AppColors.primary, const Color(0xFF8338F5));
    expect(AppColors.background, const Color(0xFFF4F1EC));
    expect(AppColors.overlay, const Color(0x6A000000));
  });
  test('dark overrides differ from light and fall back when absent', () {
    expect(AppColorsDark.background, const Color(0xFF0B0B10));
    expect(AppColorsDark.destructive, AppColors.destructive);
  });
  test('spacing is a 4dp grid', () {
    expect(AppSpace.s1, 4);
    expect(AppSpace.s4, 16);
    expect(AppSpace.s16, 64);
  });
  test('fonts and radius', () {
    expect(AppFonts.display, 'Fraunces');
    expect(AppRadius.md, 8);
    expect(AppText.base, 14);
  });
}
