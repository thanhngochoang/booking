import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/explore_badge.dart';
import 'package:photobooking/features/shell/tab_badges.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';

final _now = DateTime.utc(2026, 10, 8, 2);

Booking _request(String id, {required Duration deadlineIn}) => makeTestBooking(
  id: id,
  status: BookingStatus.requested,
).copyWith(acceptDeadline: _now.add(deadlineIn));

Future<(ProviderContainer, FakeBookingRepository)> _make(
  String uid,
  UserRole role,
) async {
  final users = FakeUserRepository();
  await users.ensureProfile(AuthUser(uid: uid, displayName: 'Minh'));
  await users.setRole(uid, role);
  final bookings = FakeBookingRepository()
    ..seedBooking(_request('r1', deadlineIn: const Duration(hours: 22)))
    ..seedBooking(_request('r2', deadlineIn: const Duration(hours: 3)))
    // Past its deadline: the server has not swept it yet.
    ..seedBooking(_request('r3', deadlineIn: const Duration(minutes: -5)))
    ..seedBooking(makeTestBooking(id: 'a1', status: BookingStatus.accepted));
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
      userRepositoryProvider.overrideWithValue(users),
      bookingRepositoryProvider.overrideWithValue(bookings),
      clockProvider.overrideWithValue(() => _now),
      exploreBadgeCountProvider.overrideWith((ref) async => 0),
    ],
  );
  addTearDown(c.dispose);
  c.listen(tabBadgesProvider, (_, _) {});
  await pumpEventQueue();
  return (c, bookings);
}

void main() {
  test('the work tab shows the number of requests for photographers', () async {
    final (c, bookings) = await _make('p1', UserRole.photographer);
    expect(c.read(tabBadgesProvider), {AppTab.bookings: 2});

    // Accepting one takes it off the badge.
    await bookings.transitionBooking(bookingId: 'r1', action: 'accept');
    await pumpEventQueue();
    expect(c.read(tabBadgesProvider), {AppTab.bookings: 1});
  });

  test('customers get no bookings badge', () async {
    final (c, _) = await _make('c1', UserRole.customer);
    expect(c.read(tabBadgesProvider), isEmpty);
  });
}
