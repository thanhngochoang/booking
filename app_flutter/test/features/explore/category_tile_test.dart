// test/features/explore/category_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/explore/category_tile.dart';

import '../../support/screen_host.dart';

void main() {
  group('ExploreCategoryTile', () {
    testWidgets('shows the photo, the name and the caption', (tester) async {
      await tester.pumpWidget(
        screenApp(
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                height: 90,
                child: ExploreCategoryTile(
                  title: 'Chân dung',
                  caption: '128 gói',
                  imageUrl: 'https://images.unsplash.com/photo-1',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chân dung'), findsOneWidget);
      expect(find.text('128 gói'), findsOneWidget);
    });

    testWidgets('no image shows the gradient placeholder', (tester) async {
      await tester.pumpWidget(
        screenApp(
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                height: 90,
                child: ExploreCategoryTile(
                  title: 'Chân dung',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chân dung'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('no caption when null', (tester) async {
      await tester.pumpWidget(
        screenApp(
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                height: 90,
                child: ExploreCategoryTile(
                  title: 'Chân dung',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chân dung'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(ExploreCategoryTile));
      expect(semantics.label, 'Chân dung');
    });

    testWidgets('semantics label is "{name}, {n} gói" and it is a button only with onTap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var tapped = false;
      await tester.pumpWidget(
        screenApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                height: 90,
                child: ExploreCategoryTile(
                  title: 'Chân dung',
                  caption: '128 gói',
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );

      var semantics = tester.getSemantics(find.byType(ExploreCategoryTile));
      expect(semantics.label, 'Chân dung, 128 gói');
      expect(semantics.flagsCollection.isButton, isTrue);

      await tester.tap(find.byType(ExploreCategoryTile));
      expect(tapped, isTrue);

      await tester.pumpWidget(
        screenApp(
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                height: 90,
                child: ExploreCategoryTile(
                  title: 'Chân dung',
                  caption: '128 gói',
                ),
              ),
            ),
          ),
        ),
      );
      semantics = tester.getSemantics(find.byType(ExploreCategoryTile));
      expect(semantics.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        screenApp(
          textScale: 1.3,
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 100,
                      child: ExploreCategoryTile(
                        title: 'Chân dung nghệ thuật',
                        caption: '128 gói',
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 100,
                      child: ExploreCategoryTile(
                        title: 'Gia đình & sự kiện',
                        caption: '52 gói',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
