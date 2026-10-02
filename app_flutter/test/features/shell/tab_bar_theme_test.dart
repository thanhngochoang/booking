import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

Widget _bar(ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home, key: Key('on')),
          label: 'A',
        ),
        NavigationDestination(
          icon: Icon(Icons.search, key: Key('off')),
          label: 'B',
        ),
      ],
    ),
  ),
);

Color? _icon(WidgetTester t, String key) =>
    IconTheme.of(t.element(find.byKey(Key(key)))).color;

Color? _label(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style?.color ??
    DefaultTextStyle.of(t.element(find.text(text))).style.color;

void main() {
  testWidgets('dark: selected is primary, unselected is the muted grey', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(buildDarkTheme()));
    expect(_icon(tester, 'on'), AppColorsDark.primary);
    expect(_icon(tester, 'off'), AppColorsDark.foregroundMuted);
    expect(_label(tester, 'A'), AppColorsDark.primary);
    expect(_label(tester, 'B'), AppColorsDark.foregroundMuted);
  });

  testWidgets('light: selected is primary, unselected is the muted grey', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(buildLightTheme()));
    expect(_icon(tester, 'on'), AppColors.primary);
    expect(_icon(tester, 'off'), AppColors.foregroundMuted);
    expect(_label(tester, 'A'), AppColors.primary);
    expect(_label(tester, 'B'), AppColors.foregroundMuted);
  });
}
