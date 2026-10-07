import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_push.dart';

Booking _booking({
  BookingStatus status = BookingStatus.requested,
  DateTime? acceptDeadline,
}) => makeTestBooking(
  id: 'b1',
  status: status,
  day: '2026-10-12',
  start: '15:30',
  end: '17:30',
  deposit: 450000,
  remaining: 1050000,
  serviceSnapshot: const BookingServiceSnapshot(
    name: 'Chân dung 2 giờ',
    price: 1500000,
    durationMinutes: 120,
  ),
  place: const BookingPlace(name: 'Bến Bạch Đằng'),
  escrowStatus: EscrowStatus.held,
).copyWith(acceptDeadline: acceptDeadline);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FakeNotificationPermission> _open(
  WidgetTester tester, {
  required String uid,
  String path = '/b/b1',
  Booking? booking,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final permission = FakeNotificationPermission(
    NotificationPermissionStatus.notDetermined,
  );
  await pumpBookingDetail(
    tester,
    uid: uid,
    path: path,
    bookings: RecordingBookingRepository()..seedBooking(booking ?? _booking()),
    extraOverrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationPermissionProvider.overrideWithValue(permission),
    ],
  );
  await _settle(tester);
  return permission;
}

void main() {
  setUp(resetNotificationPrimerState);

  testWidgets("S05.02 with paid=1 asks with the photographer's name after the "
      'toast', (tester) async {
    await _open(tester, uid: detailCustomerUid, path: '/b/b1?paid=1');
    expect(
      find.text(
        'Đã thanh toán 450.000₫, tiền được giữ an toàn.',
      ),
      findsOneWidget,
    );
    expect(find.byType(PermissionPrimer), findsOneWidget);
    expect(
      find.text('Bật thông báo để biết khi Minh Trí nhận lịch'),
      findsOneWidget,
    );
  });

  testWidgets('S05.02 without paid=1 never asks', (tester) async {
    await _open(tester, uid: detailCustomerUid);
    expect(find.byType(PermissionPrimer), findsNothing);
  });

  testWidgets('S05.02 asks once per visit, not on every rebuild', (
    tester,
  ) async {
    final permission = await _open(
      tester,
      uid: detailCustomerUid,
      path: '/b/b1?paid=1',
    );
    await tester.tap(find.text('Để sau'));
    await _settle(tester);
    expect(find.byType(PermissionPrimer), findsNothing);
    await tester.pump(const Duration(seconds: 61)); // the minute tick rebuilds
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(permission.requests, 0);
  });

  testWidgets('a photographer who accepts on S05.02 is asked', (tester) async {
    await _open(
      tester,
      uid: detailPhotographerUid,
      booking: _booking(
        acceptDeadline: worldBookingToday.add(const Duration(hours: 22)),
      ),
    );
    expect(find.byType(PermissionPrimer), findsNothing);
    await tester.tap(find.widgetWithText(AppButton, 'Nhận · còn 22 giờ'));
    await _settle(tester);
    expect(find.byType(PermissionPrimer), findsOneWidget);
    expect(
      find.text('Bật thông báo để không bỏ lỡ lời mời việc'),
      findsOneWidget,
    );
  });
}
