// test/core/widgets/provider_mark_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';

import 'widget_host.dart';

Widget _row(
  ProviderType type, {
  bool verified = true,
  int awards = 0,
  String? district,
}) => hostWidget(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ProviderName(
        'Lê Hoàng Vũ',
        mark: providerMarkOf(type: type, verified: verified),
      ),
      ProviderTag(type: type, awards: awards, district: district),
    ],
  ),
);

void main() {
  testWidgets('individual verified shows the blue tick only', (tester) async {
    await tester.pumpWidget(_row(ProviderType.individual));
    expect(find.byType(VerifiedMark), findsOneWidget);
    expect(find.byType(ProviderMark), findsOneWidget);
    expect(find.byType(ProviderTag), findsOneWidget);
    expect(find.text('Nhiếp ảnh gia'), findsNothing);
    expect(find.text('Studio'), findsNothing);
  });

  testWidgets('individual not verified shows no mark', (tester) async {
    await tester.pumpWidget(_row(ProviderType.individual, verified: false));
    expect(find.byType(ProviderMark), findsNothing);
    expect(
      tester.getSize(find.byType(ProviderTag)),
      Size.zero,
      reason: 'no tag for an individual',
    );
  });

  testWidgets('artist shows the gold mark and the tag with awards', (
    tester,
  ) async {
    await tester.pumpWidget(_row(ProviderType.artist, awards: 7));
    final mark = tester.widget<ProviderMark>(find.byType(ProviderMark));
    expect(mark.kind, ProviderMarkKind.artist);
    expect(find.text('Nhiếp ảnh gia · 7 giải'), findsOneWidget);
  });

  testWidgets('artist with no award count shows the tag without a count', (
    tester,
  ) async {
    await tester.pumpWidget(_row(ProviderType.artist));
    expect(find.text('Nhiếp ảnh gia'), findsOneWidget);
    expect(find.textContaining('giải'), findsNothing);
  });

  testWidgets(
    'verified studio shows the seal and the Studio tag with district',
    (tester) async {
      await tester.pumpWidget(_row(ProviderType.studio, district: 'Hoàn Kiếm'));
      final mark = tester.widget<ProviderMark>(find.byType(ProviderMark));
      expect(mark.kind, ProviderMarkKind.studio);
      expect(find.text('Studio · Hoàn Kiếm'), findsOneWidget);
    },
  );

  testWidgets('unverified studio shows only the tag', (tester) async {
    await tester.pumpWidget(
      _row(ProviderType.studio, verified: false, district: 'Quận 3'),
    );
    expect(find.byType(ProviderMark), findsNothing);
    expect(find.text('Studio · Quận 3'), findsOneWidget);
  });

  test('providerMarkOf follows decision 5', () {
    ProviderMarkKind? of(ProviderType t, bool v) =>
        providerMarkOf(type: t, verified: v);
    expect(of(ProviderType.artist, false), ProviderMarkKind.artist);
    expect(of(ProviderType.artist, true), ProviderMarkKind.artist);
    expect(of(ProviderType.studio, true), ProviderMarkKind.studio);
    expect(of(ProviderType.studio, false), isNull);
    expect(of(ProviderType.individual, true), ProviderMarkKind.verified);
    expect(of(ProviderType.individual, false), isNull);
  });

  testWidgets('marks announce their labels', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        const Column(
          children: [
            ProviderMark(ProviderMarkKind.verified),
            ProviderMark(ProviderMarkKind.artist),
            ProviderMark(ProviderMarkKind.studio),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Đã xác minh'), findsOneWidget);
    expect(find.bySemanticsLabel('Nhiếp ảnh gia đã duyệt'), findsOneWidget);
    expect(find.bySemanticsLabel('Studio đã xác minh'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('mark kinds differ in shape', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const Column(
          children: [
            ProviderMark(ProviderMarkKind.verified),
            ProviderMark(ProviderMarkKind.artist),
            ProviderMark(ProviderMarkKind.studio),
          ],
        ),
      ),
    );
    Finder painters(ProviderMarkKind k) => find.descendant(
      of: find.byWidgetPredicate((w) => w is ProviderMark && w.kind == k),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ProviderSealPainter,
      ),
    );
    expect(painters(ProviderMarkKind.studio), findsOneWidget);
    expect(painters(ProviderMarkKind.artist), findsNothing);
    expect(painters(ProviderMarkKind.verified), findsNothing);
    expect(
      tester.getSize(
        find.byWidgetPredicate(
          (w) => w is ProviderMark && w.kind == ProviderMarkKind.studio,
        ),
      ),
      const Size(16, 16),
    );
    expect(
      tester.getSize(
        find.byWidgetPredicate(
          (w) => w is ProviderMark && w.kind == ProviderMarkKind.artist,
        ),
      ),
      const Size(14, 14),
    );
    final disc = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is ProviderMark && w.kind == ProviderMarkKind.artist,
        ),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((disc.decoration as BoxDecoration).shape, BoxShape.circle);
  });

  testWidgets('VerifiedName still renders the blue tick', (tester) async {
    await tester.pumpWidget(hostWidget(const VerifiedName('Minh Thư')));
    expect(find.byType(VerifiedMark), findsOneWidget);
  });

  testWidgets('name with mark wraps without overflow at 120dp, 1.3x', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const ProviderName(
          'Nguyễn Thị Phương Anh Nhiếp Ảnh Gia Chân Dung',
          mark: ProviderMarkKind.studio,
        ),
        width: 120,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
