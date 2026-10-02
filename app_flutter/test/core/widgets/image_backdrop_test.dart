// test/core/widgets/image_backdrop_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

/// A valid 1×1 transparent PNG.
final _png = MemoryImage(
  Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
);

Widget _backdrop({bool highContrast = false}) => SizedBox(
  height: 600,
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: ImageBackdrop(
        image: _png,
        child: const Center(child: Text('nội dung')),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'blurs one small decode in its own layer, never with a BackdropFilter',
    (tester) async {
      await tester.pumpWidget(hostWidget(_backdrop()));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsOneWidget);
      final layer = find.byKey(const Key('image-backdrop-layer'));
      expect(tester.widget(layer), isA<RepaintBoundary>());
      expect(
        find.descendant(of: layer, matching: find.byType(ImageFiltered)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: layer, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(find.text('nội dung'), findsOneWidget);
      expect(find.byType(AuroraBackground), findsOneWidget);
    },
  );

  testWidgets('decodes at a quarter of the width in device pixels', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(_backdrop()));
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(ImageBackdrop),
        matching: find.byType(Image),
      ),
    );
    final dpr = tester.view.devicePixelRatio;
    expect(
      (image.image as ResizeImage).width,
      (390 * dpr / 4).ceil().clamp(32, 512),
    );
  });

  testWidgets('high contrast shows only the aurora', (tester) async {
    await tester.pumpWidget(hostWidget(_backdrop(highContrast: true)));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(AuroraBackground), findsOneWidget);
    expect(find.text('nội dung'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      await tester.pumpWidget(
        hostWidget(_backdrop(), brightness: b, width: 320, textScale: 1.3),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
