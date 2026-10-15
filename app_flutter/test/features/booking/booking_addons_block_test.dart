// S05.02: the add-on block under the booking card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/features/booking/widgets/booking_addons_block.dart';

import '../../support/booking_fixtures.dart';
import '../../support/screen_host.dart';

Future<void> _pump(
  WidgetTester tester,
  Booking booking, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookingAddonsBlock(booking: booking),
        ),
      ),
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pump();
}

Booking _withAddons({bool pickup = true}) => makeTestBooking().copyWith(
  addons: const [testMakeupLine, testTransportLine],
  pickup: pickup ? testPickup : null,
);

void main() {
  testWidgets('rows show "2 người × 800.000₫" and 1.600.000₫', (tester) async {
    await _pump(tester, _withAddons());

    expect(find.text('Dịch vụ đi kèm'), findsOneWidget);
    expect(find.text('Trang điểm'), findsOneWidget);
    expect(find.text('2 người × 800.000₫'), findsOneWidget);
    expect(find.text('1.600.000₫'), findsOneWidget);
    expect(find.text('Xe đón trong nội thành'), findsOneWidget);
    expect(find.text('300.000₫'), findsOneWidget);
  });

  testWidgets('per_booking shows "Một lần"', (tester) async {
    await _pump(tester, _withAddons());

    expect(find.text('Một lần'), findsOneWidget);
  });

  testWidgets('pickup row only when pickup exists', (tester) async {
    await _pump(tester, _withAddons());
    expect(find.text('Điểm đón'), findsOneWidget);
    expect(find.text('Ga Sài Gòn, Quận 3'), findsOneWidget);

    await _pump(tester, _withAddons(pickup: false));
    expect(find.text('Điểm đón'), findsNothing);
    expect(find.text('Ga Sài Gòn, Quận 3'), findsNothing);
  });

  testWidgets('nothing rendered for a booking without add-ons', (tester) async {
    await _pump(tester, makeTestBooking());

    expect(find.text('Dịch vụ đi kèm'), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp, text scale 1.3, ${brightness.name}: no overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        _withAddons(),
        brightness: brightness,
        textScale: 1.3,
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1.600.000₫'), findsOneWidget);
      expect(find.text('Ga Sài Gòn, Quận 3'), findsOneWidget);
    });
  }
}
