import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

SvgPicture _svg(WidgetTester tester) =>
    tester.widget<SvgPicture>(find.byType(SvgPicture));

ColorFilter _mode(Color c) => ColorFilter.mode(c, BlendMode.srcIn);

void main() {
  testWidgets('draws the tomato asset in the tomato token, size 16', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const VerdictIcon(VerdictKind.tomato),
        brightness: Brightness.light,
      ),
    );
    final svg = _svg(tester);
    expect(svg.width, 16);
    expect(svg.height, 16);
    expect(svg.colorFilter, _mode(AppColors.tomato));
  });

  testWidgets('draws the brick mascot in its own colours, no tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const VerdictIcon(VerdictKind.brick, size: 24, color: Colors.grey),
        brightness: Brightness.light,
      ),
    );
    expect(_svg(tester).width, 24);
    expect(_svg(tester).colorFilter, isNull);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('a muted brick is faded', (tester) async {
    await tester.pumpWidget(
      hostWidget(const VerdictIcon(VerdictKind.brick, muted: true)),
    );
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
  });

  testWidgets('uses the dark tokens on the dark theme', (tester) async {
    await tester.pumpWidget(hostWidget(const VerdictIcon(VerdictKind.tomato)));
    expect(_svg(tester).colorFilter, _mode(AppColorsDark.tomato));
  });

  testWidgets('an explicit colour wins', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const VerdictIcon(VerdictKind.tomato, color: Color(0xFF123456)),
      ),
    );
    expect(_svg(tester).colorFilter, _mode(const Color(0xFF123456)));
  });

  testWidgets('is decorative: no semantics node of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const VerdictIcon(VerdictKind.tomato)));
    expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });
}
