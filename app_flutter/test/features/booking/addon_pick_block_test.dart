// test/features/booking/addon_pick_block_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/features/booking/widgets/addon_pick_block.dart';

import '../../support/booking_world.dart';
import '../../support/screen_host.dart';

/// Hosts the block with its own picks, like the S04.01 controller would.
class _Host extends StatefulWidget {
  const _Host({required this.addons});
  final List<ServiceAddon> addons;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final picks = <String, int>{};

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AddonPickBlock(
        addons: widget.addons,
        picks: picks,
        onQty: (id, qty) => setState(() {
          if (qty == 0) {
            picks.remove(id);
          } else {
            picks[id] = qty;
          }
        }),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<ServiceAddon> addons, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      home: _Host(addons: addons),
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pump();
}

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  final all = [addonMakeup, addonRetouch, addonTransport];

  testWidgets(
    'shows the header, each row\'s name, one-line description and price',
    (tester) async {
      await _pump(tester, all);
      expect(find.text('Thêm dịch vụ'), findsOneWidget);
      expect(find.text('Không bắt buộc'), findsOneWidget);
      expect(find.text('Trang điểm'), findsOneWidget);
      expect(find.text('Trang điểm tự nhiên, làm tóc cơ bản'), findsOneWidget);
      expect(find.text('800.000₫ / người'), findsOneWidget);
      expect(find.text('20.000₫ / ảnh'), findsOneWidget);
      expect(find.text('300.000₫ · một lần'), findsOneWidget);
      final desc = tester.widget<Text>(find.text('Đón đi và đưa về, xe 4 chỗ'));
      expect(desc.maxLines, 1);
      expect(desc.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('per_booking row toggles with the checkbox', (tester) async {
    await _pump(tester, all);
    final box = find.byKey(const Key('addon-a_car-check'));
    expect(tester.widget<Checkbox>(box).value, isFalse);
    expect(find.bySemanticsLabel('Xe đón trong nội thành'), findsWidgets);

    await tester.tap(box);
    await tester.pump();
    expect(tester.widget<Checkbox>(box).value, isTrue);

    await tester.tap(box);
    await tester.pump();
    expect(tester.widget<Checkbox>(box).value, isFalse);
  });

  testWidgets('stepper goes 0 → maxQty and stops; minus disabled at 0', (
    tester,
  ) async {
    await _pump(tester, all);
    expect(_enabled(tester, 'addon-a_makeup-minus'), isFalse);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('addon-a_makeup-minus')))
          .tooltip,
      'Bớt một người',
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('addon-a_makeup-plus')))
          .tooltip,
      'Thêm một người',
    );

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('addon-a_makeup-plus')));
      await tester.pump();
    }
    expect(
      tester
          .widget<Text>(find.byKey(const Key('addon-a_makeup-quantity')))
          .data,
      '4',
    );
    expect(_enabled(tester, 'addon-a_makeup-plus'), isFalse);
    expect(_enabled(tester, 'addon-a_makeup-minus'), isTrue);
  });

  testWidgets('block is absent when no add-on applies', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Thêm dịch vụ'), findsNothing);
    expect(find.byKey(const Key('addon-pick-block')), findsNothing);
  });

  testWidgets('rows are grouped in kind order', (tester) async {
    final outfit = bookingAddon(
      'a_dress',
      kind: AddonKind.outfit,
      name: 'Áo dài',
      unit: AddonUnit.perItem,
      price: 200000,
      maxQty: 3,
    );
    await _pump(tester, [addonTransport, outfit, addonRetouch, addonMakeup]);
    double top(String id) =>
        tester.getTopLeft(find.byKey(Key('addon-row-$id'))).dy;
    expect(top('a_makeup'), lessThan(top('a_retouch')));
    expect(top('a_retouch'), lessThan(top('a_car')));
    expect(top('a_car'), lessThan(top('a_dress')));
  });

  testWidgets('320 dp and text scale 1.3 without overflow', (tester) async {
    await _pump(tester, all, textScale: 1.3, size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('addon-row-a_makeup')), findsOneWidget);
  });

  testWidgets('dark and light theme', (tester) async {
    for (final b in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, all, brightness: b);
      expect(tester.takeException(), isNull);
      expect(find.text('Thêm dịch vụ'), findsOneWidget);
    }
  });
}
