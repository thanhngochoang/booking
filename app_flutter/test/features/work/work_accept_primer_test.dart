import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_push.dart';

/// Thursday 08/10 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);

Booking _request() => makeTestBooking(
  id: 'r1',
  status: BookingStatus.requested,
  day: '2026-10-10',
  start: '15:30',
  end: '17:30',
  deposit: 450000,
  remaining: 1050000,
  escrowStatus: EscrowStatus.held,
).copyWith(acceptDeadline: _now.add(const Duration(hours: 22)), chatId: 'c_r1');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(resetNotificationPrimerState);

  testWidgets('accept on S06.01 asks before opening the chat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final permission = FakeNotificationPermission(
      NotificationPermissionStatus.notDetermined,
    );
    final repo = RecordingBookingRepository()
      ..seedBooking(_request())
      ..seedContact(
        'r1',
        const BookingContactSnapshot(
          name: 'Lan Anh',
          phone: '+84903123456',
          allowZalo: true,
          allowWhatsApp: false,
        ),
      );
    final handles = await pumpBookingsTab(
      tester,
      uid: detailPhotographerUid,
      role: UserRole.photographer,
      bookings: repo,
      clock: TestClock(_now),
      portfolioPhotos: 8,
      packages: const [workPackage],
      completeness: 90,
      extraOverrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationPermissionProvider.overrideWithValue(permission),
      ],
    );
    await _settle(tester);

    await tester.tap(
      find.ancestor(
        of: find.text('Nhận · còn 22 giờ'),
        matching: find.byType(AppButton),
      ),
    );
    await _settle(tester);

    expect(repo.transitions, [
      (bookingId: 'r1', action: 'accept', reason: null),
    ]);
    expect(find.byType(PermissionPrimer), findsOneWidget);
    expect(handles.location, isNot('/chat/c_r1'), reason: 'asks first');

    await tester.tap(find.text('Để sau'));
    await _settle(tester);
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(handles.location, '/chat/c_r1');
  });
}
