import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

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

  testWidgets('a tomato part with a count reads "97% (58)"', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('Quận 3'),
          MetaPart.tomato(97, count: 58),
        ]),
      ),
    );
    expect(_plain(tester), 'Quận 3 · 97% (58)');
    expect(
      metaPartsText(const [MetaPart.tomato(97, count: 58), MetaPart.text('x')]),
      '97% (58) · x',
    );
  });

  testWidgets('a screen reader hears "97% cà chua", not a bare percent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('Quận 3'),
          MetaPart.tomato(97),
          MetaPart.text('112 buổi'),
        ]),
      ),
    );
    expect(
      find.bySemanticsLabel('Quận 3 · 97% cà chua · 112 buổi'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a counted tomato part reads "97% cà chua, 58 đánh giá"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const MetaLine([MetaPart.tomato(97, count: 58)])),
    );
    expect(find.bySemanticsLabel('97% cà chua, 58 đánh giá'), findsOneWidget);
    handle.dispose();
  });

  test('metaPartsSemantics names the tomato percent', () async {
    final l = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(
      metaPartsSemantics(const [
        MetaPart.text('Quận 3'),
        MetaPart.tomato(97),
        MetaPart.tomato(90, count: 12),
      ], l),
      'Quận 3 · 97% cà chua · 90% cà chua, 12 đánh giá',
    );
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

  testWidgets('a text part draws its bold part bold in tabular figures', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const MetaLine([
          MetaPart.text('112 buổi'),
          MetaPart.text('đến trong khoảng 9 phút', bold: '9 phút'),
        ]),
      ),
    );
    expect(_plain(tester), '112 buổi · đến trong khoảng 9 phút');
    expect(
      metaPartsText(const [MetaPart.text('đến 9 phút', bold: '9 phút')]),
      'đến 9 phút',
    );
    final spans = <TextSpan>[];
    tester
        .widget<RichText>(
          find.descendant(
            of: find.byType(MetaLine),
            matching: find.byType(RichText),
          ),
        )
        .text
        .visitChildren((span) {
          if (span is TextSpan && span.text == '9 phút') spans.add(span);
          return true;
        });
    expect(spans.single.style?.fontWeight, FontWeight.w700);
    expect(spans.single.style?.fontFeatures, const [
      FontFeature.tabularFigures(),
    ]);
  });
}
