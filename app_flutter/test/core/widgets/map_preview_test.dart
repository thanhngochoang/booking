// test/core/widgets/map_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

/// Tao Đàn park and Bến Thành market, about 0,7 km apart.
const _lanAnh = MapPin(lat: 10.7745, lng: 106.6918, label: 'Lan Anh');
const _me = MapPin(lat: 10.7725, lng: 106.6980, label: 'Bạn', self: true);

Future<void> _pump(
  WidgetTester tester,
  List<MapPin> pins, {
  bool route = false,
  VoidCallback? onRecenter,
  Brightness brightness = Brightness.dark,
}) => tester.pumpWidget(
  hostWidget(
    MapPreview(pins: pins, route: route, onRecenter: onRecenter, height: 250),
    brightness: brightness,
  ),
);

Offset _dot(WidgetTester tester, int i) =>
    tester.getCenter(find.byKey(Key('map-pin-dot-$i')));

Color? _dotColor(WidgetTester tester, int i) {
  final box = tester.widget<DecoratedBox>(find.byKey(Key('map-pin-dot-$i')));
  return (box.decoration as BoxDecoration).color;
}

void main() {
  testWidgets(
    'two pins are placed inside the box with 20% padding and the self pin is '
    'blue (mapSelf)',
    (tester) async {
      await _pump(tester, const [_lanAnh, _me], route: true);

      final box = tester.getRect(find.byKey(const Key('map-preview')));
      expect(box.size, const Size(390, 250));
      final a = _dot(tester, 0);
      final b = _dot(tester, 1);
      for (final p in [a, b]) {
        expect(box.contains(p), isTrue);
      }
      // The bounds are padded by 20% of the span on each side: in the
      // limiting axis (height here: the pins are mostly east-west of each
      // other but the box is wide) the pins sit 1/7 of the side from the edge
      // at most, never on it.
      final minGapX = [
        a.dx - box.left,
        box.right - a.dx,
        b.dx - box.left,
        box.right - b.dx,
      ].reduce((x, y) => x < y ? x : y);
      final minGapY = [
        a.dy - box.top,
        box.bottom - a.dy,
        b.dy - box.top,
        box.bottom - b.dy,
      ].reduce((x, y) => x < y ? x : y);
      expect(minGapX, greaterThanOrEqualTo(box.width / 7 - 0.5));
      expect(minGapY, greaterThanOrEqualTo(box.height / 7 - 0.5));
      // One axis is the limiting one: the pins touch its padded edge.
      expect(
        (minGapX - box.width / 7).abs() < 1 ||
            (minGapY - box.height / 7).abs() < 1,
        isTrue,
      );
      // North is up, east is right.
      expect(a.dy, lessThan(b.dy));
      expect(a.dx, lessThan(b.dx));
      expect(find.text('Lan Anh'), findsOneWidget);
      expect(find.text('Bạn'), findsOneWidget);
      expect(_dotColor(tester, 1), AppColorsDark.mapSelf);
      expect(_dotColor(tester, 0), isNot(AppColorsDark.mapSelf));
    },
  );

  testWidgets('one pin is centred', (tester) async {
    await _pump(tester, const [_lanAnh]);

    final box = tester.getRect(find.byKey(const Key('map-preview')));
    final p = _dot(tester, 0);
    expect((p.dx - box.center.dx).abs(), lessThan(0.5));
    expect((p.dy - box.center.dy).abs(), lessThan(0.5));
  });

  testWidgets('pins 5 m apart do not overlap the box edges (minimum span)', (
    tester,
  ) async {
    // 5 m east of Lan Anh.
    const near = MapPin(lat: 10.7745, lng: 106.69185, label: 'Bạn', self: true);
    await _pump(tester, const [_lanAnh, near], route: true);

    final box = tester.getRect(find.byKey(const Key('map-preview')));
    final a = _dot(tester, 0);
    final b = _dot(tester, 1);
    // ~400 m minimum span: 5 m is a few pixels, both pins near the centre.
    expect((a - b).distance, lessThan(10));
    for (final p in [a, b]) {
      expect((p.dx - box.center.dx).abs(), lessThan(box.width / 4));
      expect((p.dy - box.center.dy).abs(), lessThan(box.height / 4));
    }
  });

  testWidgets('recenter button appears only with onRecenter and calls it', (
    tester,
  ) async {
    await _pump(tester, const [_lanAnh, _me]);
    expect(find.byTooltip('Về vị trí của tôi'), findsNothing);

    var calls = 0;
    await _pump(tester, const [_lanAnh, _me], onRecenter: () => calls++);
    expect(find.byTooltip('Về vị trí của tôi'), findsOneWidget);
    await tester.tap(find.byTooltip('Về vị trí của tôi'));
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('semantics reads "Bản đồ: Lan Anh, Bạn"', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const [_lanAnh, _me], route: true);

    expect(find.bySemanticsLabel('Bản đồ: Lan Anh, Bạn'), findsOneWidget);
    // The pin labels are not read twice.
    expect(find.bySemanticsLabel('Lan Anh'), findsNothing);
    handle.dispose();
  });

  testWidgets('light and dark use the map tokens', (tester) async {
    Color background() => tester
        .widget<ColoredBox>(find.byKey(const Key('map-preview-bg')))
        .color;

    await _pump(tester, const [_lanAnh, _me]);
    expect(background(), AppColorsDark.mapBg);
    expect(_dotColor(tester, 1), AppColorsDark.mapSelf);
    final dark = tester.widget<CustomPaint>(
      find.byKey(const Key('map-preview-base')),
    );
    expect(
      (dark.painter! as MapBasePainter).palette,
      MapPalette.of(Brightness.dark),
    );

    // A fresh tree: no theme cross-fade between the two.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, const [_lanAnh, _me], brightness: Brightness.light);
    expect(background(), AppColors.mapBg);
    expect(_dotColor(tester, 1), AppColors.mapSelf);
    final light = tester.widget<CustomPaint>(
      find.byKey(const Key('map-preview-base')),
    );
    final palette = (light.painter! as MapBasePainter).palette;
    expect(palette, MapPalette.of(Brightness.light));
    expect(palette.block, AppColors.mapBlock);
    expect(palette.road, AppColors.mapRoad);
    expect(palette.water, AppColors.mapWater);
    expect(palette.park, AppColors.mapPark);
    expect(MapPalette.of(Brightness.dark).water, AppColorsDark.mapWater);
  });

  testWidgets('center keeps that point in the middle with every pin inside', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        MapPreview(
          pins: const [_lanAnh, _me],
          center: (lat: _lanAnh.lat, lng: _lanAnh.lng),
        ),
      ),
    );
    final box = tester.getRect(find.byKey(const Key('map-preview')));
    expect((_dot(tester, 0) - box.center).distance, lessThan(0.5));
    expect(box.contains(_dot(tester, 1)), isTrue);
  });
}
