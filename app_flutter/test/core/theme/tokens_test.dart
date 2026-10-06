import 'dart:math' as math;

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
  test('light CTA gradient stays in the brand hue', () {
    expect(AppColors.ctaLightStart, AppColors.primary);
    expect(AppColors.ctaLightEnd, const Color(0xFF702BDB));
  });
  test('accent aliases primary in both themes', () {
    expect(AppColors.accent, AppColors.primary);
    expect(AppColorsDark.accent, AppColorsDark.primary);
    expect(AppColorsDark.accent, const Color(0xFFB08AFF));
    expect(AppColorsDark.accentForeground, const Color(0xFF0B0B10));
    expect(AppColorsDark.accentSoft, const Color(0xFF2C0F5C));
    expect(AppColors.accent, const Color(0xFF8338F5));
    expect(AppColors.accentForeground, const Color(0xFFFFFFFF));
    expect(AppColors.accentSoft, const Color(0xFFF4EEFF));
  });
  test('accent meets 4.5:1 on surface in both themes', () {
    double lum(Color c) {
      double ch(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double ratio(Color a, Color b) {
      final l1 = lum(a), l2 = lum(b);
      return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
    }

    expect(
      ratio(AppColorsDark.accent, AppColorsDark.surface),
      greaterThan(4.5),
    );
    expect(ratio(AppColors.accent, AppColors.surface), greaterThan(4.5));
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
