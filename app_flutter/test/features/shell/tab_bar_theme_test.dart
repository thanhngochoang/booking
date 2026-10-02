import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/shell/tab_shell.dart';

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

  for (final sel in [0, 1]) {
    testWidgets(
      'middle tab label: ink when active, muted otherwise (sel $sel)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDarkTheme(),
            home: Scaffold(
              bottomNavigationBar: NavigationBar(
                selectedIndex: sel,
                destinations: const [
                  MiddleTabDestination(icon: Icons.add, label: 'M'),
                  NavigationDestination(icon: Icon(Icons.search), label: 'B'),
                ],
              ),
            ),
          ),
        );
        expect(
          _label(tester, 'M'),
          sel == 0 ? AppColorsDark.foreground : AppColorsDark.foregroundMuted,
        );
        // Lifted 3dp, hit area still at least 48dp tall.
        final box = tester.getRect(find.byType(NavigationDestination).first);
        final other = tester.getRect(find.byType(NavigationDestination).last);
        expect(box.top, closeTo(other.top - 3, 0.5));
        expect(box.height, greaterThanOrEqualTo(48));
      },
    );
  }
}
