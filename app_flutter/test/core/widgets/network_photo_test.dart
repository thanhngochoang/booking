import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/photo_scope.dart';
import 'widget_host.dart';

void main() {
  testWidgets(
    'asks the scope for the url, fit and a display-size decode width',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final log = <PhotoRequest>[];
      await tester.pumpWidget(
        hostWidget(
          testPhotoScope(
            log: log,
            child: const SizedBox(
              height: 100,
              child: NetworkPhoto(
                url: 'https://img.test/a.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          width: 150,
        ),
      );
      expect(
        find.byKey(const ValueKey('photo:https://img.test/a.jpg')),
        findsOneWidget,
      );
      expect(log.last.url, 'https://img.test/a.jpg');
      expect(log.last.fit, BoxFit.contain);
      expect(log.last.cacheWidth, 300, reason: '150 dp x 2 = 300 px');
      expect(log.last.retry, isTrue);
    },
  );

  testWidgets('the decode width is rounded up to 50 px', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const SizedBox(height: 100, child: NetworkPhoto(url: 'u')),
        ),
        width: 120,
      ),
    );
    expect(
      log.last.cacheWidth,
      400,
      reason: '120 dp x 3 = 360 px, rounded up to 400',
    );
  });

  testWidgets('an unbounded width gives no decode width', (tester) async {
    final log = <PhotoRequest>[];
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          log: log,
          child: const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(height: 50, child: NetworkPhoto(url: 'u')),
          ),
        ),
      ),
    );
    expect(log.last.cacheWidth, isNull);
  });

  testWidgets(
    'retry: false is passed through (avatars show initials instead)',
    (tester) async {
      final log = <PhotoRequest>[];
      await tester.pumpWidget(
        hostWidget(
          testPhotoScope(
            log: log,
            child: const SizedBox(
              height: 50,
              child: NetworkPhoto(url: 'u', retry: false),
            ),
          ),
        ),
      );
      expect(log.last.retry, isFalse);
    },
  );

  testWidgets('with a label it is an image node, without one it is silent', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          child: const SizedBox(
            height: 50,
            child: NetworkPhoto(url: 'u', semanticLabel: 'Ảnh chân dung'),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Ảnh chân dung'), findsOneWidget);
    await tester.pumpWidget(
      hostWidget(
        testPhotoScope(
          child: const SizedBox(height: 50, child: NetworkPhoto(url: 'u')),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Ảnh chân dung'), findsNothing);
    handle.dispose();
  });

  testWidgets('without a scope the production builder is used', (tester) async {
    PhotoImageBuilder? found;
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            found = PhotoImageScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, cachedPhotoBuilder);
  });
}
