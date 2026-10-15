import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  late FakeBookingRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeBookingRepository(customerId: 'c1');
    container = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'p1')),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<AsyncValue<List<Booking>>> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(myWorkBookingsProvider);
  }

  List<String> idsOf(AsyncValue<List<Booking>> v) => [
    for (final b in v.requireValue) b.id,
  ];

  test(
    'myWorkBookingsProvider merges own and assigned, own wins on the same id',
    () async {
      repo.seedBooking(
        makeTestBooking(id: 'own1', photographerId: 'p1', note: 'own'),
      );
      repo.seedBooking(
        makeTestBooking(id: 'both', photographerId: 'p1', note: 'own copy'),
      );
      final sub = container.listen(myWorkBookingsProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      repo.emitAssigned([
        makeTestBooking(
          id: 'both',
          photographerId: 'studio1',
          note: 'assigned',
        ),
        makeTestBooking(id: 'as1', photographerId: 'studio1'),
      ]);
      final v = await settle();
      expect(idsOf(v)..sort(), ['as1', 'both', 'own1']);
      final both = v.requireValue.singleWhere((b) => b.id == 'both');
      expect(both.note, 'own copy');
      expect(both.photographerId, 'p1');
    },
  );

  test(
    'an assigned stream error yields the own list (no AsyncError)',
    () async {
      repo.seedBooking(makeTestBooking(id: 'own1', photographerId: 'p1'));
      final sub = container.listen(myWorkBookingsProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      repo.emitAssigned([
        makeTestBooking(id: 'as1', photographerId: 'studio1'),
      ]);
      expect(idsOf(await settle())..sort(), ['as1', 'own1']);

      repo.failAssigned(StateError('permission-denied'));
      final v = await settle();
      expect(v.hasError, isFalse);
      expect(idsOf(v), ['own1']);
      expect(container.read(assignedBookingsProvider).hasError, isFalse);
    },
  );

  test(
    'an assigned stream that fails first still shows the own list',
    () async {
      repo.seedBooking(
        makeTestBooking(
          id: 'own1',
          photographerId: 'p1',
          status: BookingStatus.accepted,
        ),
      );
      repo.failAssigned(StateError('permission-denied'));
      final sub = container.listen(myWorkBookingsProvider, (_, _) {});
      addTearDown(sub.close);
      final v = await settle();
      expect(v.hasError, isFalse);
      expect(idsOf(v), ['own1']);
    },
  );
}
