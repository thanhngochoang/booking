import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

// 1x1 transparent PNG, so the avatar needs no network.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _host(ThemeData theme, {ImageProvider? avatar}) => MaterialApp(
  theme: theme,
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: CtaAvatarScope(
    avatar: avatar,
    child: Scaffold(
      body: Center(child: AppButton.primary('Đặt lịch', onPressed: () {})),
    ),
  ),
);

LinearGradient _gradientOf(WidgetTester tester) {
  final surface = find.descendant(
    of: find.byType(CtaSurface),
    matching: find.byType(DecoratedBox),
  );
  final d = tester.widget<DecoratedBox>(surface.first).decoration;
  return (d as BoxDecoration).gradient! as LinearGradient;
}

void main() {
  test('gradient follows the theme brightness', () {
    expect(ctaGradientFor(Brightness.dark).colors, hasLength(2));
    expect(ctaGradientFor(Brightness.light).colors, [
      AppColors.ctaLightStart,
      AppColors.ctaLightEnd,
    ]);
  });

  test('dark CTA is a violet two-stop gradient', () {
    expect(ctaGradientFor(Brightness.dark).colors, [
      const Color(0xFF8A3FFC),
      const Color(0xFF6E2FD6),
    ]);
    expect(AppColors.ctaStart, const Color(0xFF8A3FFC));
    expect(AppColors.ctaEnd, const Color(0xFF6E2FD6));
  });

  testWidgets('light theme: tonal gradient, no avatar layers', (tester) async {
    await tester.pumpWidget(_host(buildLightTheme()));
    expect(_gradientOf(tester).colors, hasLength(2));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('Đặt lịch'), findsOneWidget);
  });

  testWidgets('dark theme: violet two-stop gradient', (tester) async {
    await tester.pumpWidget(_host(buildDarkTheme()));
    expect(_gradientOf(tester).colors, hasLength(2));
  });

  testWidgets('avatar style blurs the photo and tints it with the gradient', (
    tester,
  ) async {
    await tester.pumpWidget(_host(buildDarkTheme(), avatar: MemoryImage(_png)));
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    // Gradient stays underneath as the loading/failed fallback.
    expect(_gradientOf(tester).colors, hasLength(2));
    expect(find.text('Đặt lịch'), findsOneWidget);
  });
}
