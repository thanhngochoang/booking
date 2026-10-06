// test/core/theme/app_bar_theme_test.dart
import 'package:flutter/material.dart';
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

  for (final theme in [buildDarkTheme(), buildLightTheme()]) {
    testWidgets('BackButton and CloseButton use Symbols icons '
        '(${theme.brightness.name})', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Row(children: [BackButton(), CloseButton()]),
        ),
      );
      final icons = tester
          .widgetList<AppIcon>(find.byType(AppIcon))
          .map((i) => i.icon)
          .toList();
      expect(icons, [AppIcons.back, AppIcons.close]);
    });
  }
}

void mutedForegroundTests() {
  for (final (theme, expected) in [
    (buildDarkTheme(), AppColorsDark.foregroundMuted),
    (buildLightTheme(), AppColors.foregroundMuted),
  ]) {
    testWidgets('mutedForeground (${theme.brightness.name})', (tester) async {
      late Color c;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              c = context.mutedForeground;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(c, expected);
      expect(theme.colorScheme.onSurfaceVariant, isNot(expected));
    });
  }
}
