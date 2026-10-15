// test/core/widgets/free_tag_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('tag says "Không thu phí" and never "0₫"', (tester) async {
    await tester.pumpWidget(hostWidget(const FreeTag()));
    expect(find.text('Không thu phí'), findsOneWidget);
    expect(find.textContaining('0₫'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('tag text keeps 4.5:1 contrast on ${b.name}', (tester) async {
      await tester.pumpWidget(hostWidget(const FreeTag(), brightness: b));
      final fill =
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(FreeTag),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final page = b == Brightness.dark
          ? AppColorsDark.background
          : AppColors.background;
      final text = tester
          .widget<Text>(find.text('Không thu phí'))
          .style!
          .color!;
      expect(
        _contrast(text, Color.alphaBlend(fill, page)),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('tag is a pill with 10px tracked text', (tester) async {
    await tester.pumpWidget(hostWidget(const FreeTag()));
    final deco =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(FreeTag),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(deco.borderRadius, BorderRadius.circular(AppRadius.full));
    final style = tester.widget<Text>(find.text('Không thu phí')).style!;
    expect(style.fontSize, AppText.xs);
    expect(style.letterSpacing, closeTo(0.4, 1e-9));
  });

  testWidgets('banner shows title and the default hint', (tester) async {
    await tester.pumpWidget(
      hostWidget(const FreeBanner(), width: 320, textScale: 1.3),
    );
    expect(find.text('Không thu phí'), findsOneWidget);
    expect(
      find.text('Đăng ký để giữ chỗ, không cần thanh toán'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner accepts a custom hint', (tester) async {
    await tester.pumpWidget(
      hostWidget(const FreeBanner(body: 'Vào cửa tự do')),
    );
    expect(find.text('Vào cửa tự do'), findsOneWidget);
  });
}
