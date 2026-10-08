import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

String _plain(WidgetTester tester) => tester
    .widget<RichText>(
      find.descendant(
        of: find.byType(MetaLine),
        matching: find.byType(RichText),
      ),
    )
    .text
    .toPlainText(includePlaceholders: false);

void main() {
  testWidgets('joins text parts with " · "', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('Chân dung'),
          MetaPart.text('Quận 3'),
          MetaPart.text('112 buổi'),
        ]),
      ),
    );
    expect(_plain(tester), 'Chân dung · Quận 3 · 112 buổi');
    expect(find.byType(VerdictIcon), findsNothing);
  });

  testWidgets('a tomato part shows the icon and "97%"', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('Quận 3'),
          MetaPart.tomato(97),
          MetaPart.text('112 buổi'),
        ]),
      ),
    );
    expect(_plain(tester), 'Quận 3 · 97% · 112 buổi');
    expect(find.byType(VerdictIcon), findsOneWidget);
    final icon = tester.widget<VerdictIcon>(find.byType(VerdictIcon));
    expect(icon.kind, VerdictKind.tomato);
    expect(icon.size, 12);
  });

  testWidgets('ellipsises at maxLines', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('Chân dung · Cưới · Gia đình · Phong cảnh · Sự kiện'),
          MetaPart.tomato(97),
          MetaPart.text('1.234 buổi chụp'),
        ]),
        width: 200,
      ),
    );
    final rich = tester.widget<RichText>(
      find.descendant(
        of: find.byType(MetaLine),
        matching: find.byType(RichText),
      ),
    );
    expect(rich.maxLines, 1);
    expect(rich.overflow, TextOverflow.ellipsis);
    final box = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(MetaLine),
        matching: find.byType(RichText),
      ),
    );
    expect(box.didExceedMaxLines, isTrue);
    expect(tester.getSize(find.byType(MetaLine)).width, lessThanOrEqualTo(200));
  });

  testWidgets('an explicit style wins', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('x'),
        ], style: TextStyle(fontSize: 20, color: Color(0xFF010203))),
      ),
    );
    final style = tester
        .widget<RichText>(
          find.descendant(
            of: find.byType(MetaLine),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style;
    expect(style?.fontSize, 20);
    expect(style?.color, const Color(0xFF010203));
  });
}
