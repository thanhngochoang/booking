import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('featured tile is full width 16:7 with the count pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        AlbumTile(
          title: 'Cưới Đà Lạt',
          photoCount: 24,
          featured: true,
          onTap: () {},
        ),
        width: 320,
      ),
    );
    final cover = tester.getSize(find.byKey(AlbumTile.coverKey));
    expect(cover.width, 320);
    expect(cover.width / cover.height, closeTo(16 / 7, 0.02));
    // The count is a pill on the cover, not a caption under the title.
    expect(
      find.descendant(
        of: find.byKey(AlbumTile.coverKey),
        matching: find.text('24 ảnh'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('regular tile has a square cover and a caption count', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        AlbumTile(title: 'Chân dung', photoCount: 8, onTap: () {}),
        width: 160,
      ),
    );
    final cover = tester.getSize(find.byKey(AlbumTile.coverKey));
    expect(cover.width, cover.height);
    expect(find.text('8 ảnh'), findsOneWidget);
  });

  testWidgets('empty album tile is dimmed with its note', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AlbumTile(
          title: 'Mới tạo',
          photoCount: 0,
          dimmedNote: 'Trống · chưa hiện công khai',
          onTap: () {},
        ),
        width: 160,
      ),
    );
    expect(find.text('Trống · chưa hiện công khai'), findsOneWidget);
    expect(find.text('0 ảnh'), findsNothing);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Mới tạo'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.7);
  });

  testWidgets('tap fires and the tile reads as one button', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(
        AlbumTile(title: 'Chân dung', photoCount: 8, onTap: () => taps++),
        width: 160,
      ),
    );
    await tester.tap(find.text('Chân dung'));
    expect(taps, 1);
    final node = tester.getSemantics(find.byType(AlbumTile));
    expect(node.label, 'Chân dung, 8 ảnh');
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('skeleton has the tile\'s shape', (tester) async {
    await tester.pumpWidget(
      hostWidget(const AlbumTile.skeleton(), width: 160),
    );
    final cover = tester.getSize(find.byKey(AlbumTile.coverKey));
    expect(cover.width, cover.height);
    expect(find.byType(AlbumTile), findsOneWidget);
    await tester.pumpWidget(
      hostWidget(const AlbumTile.skeleton(featured: true), width: 320),
    );
    final wide = tester.getSize(find.byKey(AlbumTile.coverKey));
    expect(wide.width / wide.height, closeTo(16 / 7, 0.02));
  });
}
