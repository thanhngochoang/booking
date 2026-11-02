import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/widgets/late_delivery_card.dart';

import '../../support/booking_fixtures.dart';
import '../../support/screen_host.dart';

Booking _lateBooking() =>
    makeTestBooking(id: 'b1', status: BookingStatus.shot).copyWith(
      // 12/10 17:30 VN -> due 17/10 17:30 VN (deliveryDays 5).
      shotAt: DateTime.utc(2026, 10, 12, 10, 30),
      deliveryDays: 5,
    );

void main() {
  testWidgets(
    'shows lateDeliveryTitle with the provider name and the due date, lateDeliveryBody, and the red text button',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        screenApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: LateDeliveryCard(
                booking: _lateBooking(),
                providerName: 'Lan Anh',
                onCancel: () => tapped++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bàn giao ảnh'), findsOneWidget);
      expect(find.text('Quá hạn'), findsOneWidget);
      expect(
        find.text('Lan Anh chưa bàn giao đúng hạn (trước 17/10)'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Bạn có thể chờ thêm hoặc huỷ phần bàn giao và nhận lại mốc 2.',
        ),
        findsOneWidget,
      );

      final btn = find.byKey(const Key('late-delivery-cancel'));
      expect(btn, findsOneWidget);
      final appBtn = tester.widget<AppButton>(btn);
      expect(appBtn.label, 'Huỷ phần bàn giao');
      expect(
        appBtn.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColorsDark.error,
      );

      await tester.tap(btn);
      await tester.pump();
      expect(tapped, 1);
    },
  );

  testWidgets('fits 320 dp at 1.3× text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        screenApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: LateDeliveryCard(
                booking: _lateBooking(),
                providerName: 'Nguyễn Thị Minh Khoa',
                onCancel: () {},
              ),
            ),
          ),
          brightness: brightness,
          textScale: 1.3,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$brightness');
    }
  });
}
