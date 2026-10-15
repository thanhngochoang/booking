import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';

DateTime _d(int day) => DateTime.utc(2026, 10, day);

void main() {
  group('mapping', () {
    test(
      'documents become days; unknown or missing states count as booked',
      () {
        expect(
          availabilityDayFromFirestore('2026-10-12', {'state': 'off'}),
          AvailabilityDay(day: _d(12), state: DayState.off),
        );
        final pending = availabilityDayFromFirestore('2026-10-13', {
          'state': 'pending',
          'bookingId': 'b1',
        })!;
        expect((pending.state, pending.bookingId), (DayState.pending, 'b1'));
        expect(
          availabilityDayFromFirestore('2026-10-15', {
            'state': 'booked',
            'eventId': 'e1',
          })!.eventId,
          'e1',
        );
        expect(
          availabilityDayFromFirestore('2026-10-14', {'state': 'weird'})!.state,
          DayState.booked,
        );
        expect(
          availabilityDayFromFirestore('2026-10-14', {})!.state,
          DayState.booked,
        );
        expect(
          availabilityDayFromFirestore('2026-13-01', {'state': 'off'}),
          isNull,
        );
        expect(availabilityDayFromFirestore('x', {'state': 'off'}), isNull);
      },
    );

    test('the client writes nothing but the off state', () {
      expect(offDayToFirestore(), {'state': 'off'});
    });
  });

  group('FakeAvailabilityRepository', () {
    test('watchRange emits the slice now and after each change', () async {
      final repo = FakeAvailabilityRepository()
        ..seed(
          'p1',
          AvailabilityDay(day: _d(10), state: DayState.booked, bookingId: 'b1'),
        )
        ..seed(
          'p1',
          AvailabilityDay(day: DateTime.utc(2026, 11, 2), state: DayState.off),
        );
      final seen = <Map<DateTime, AvailabilityDay>>[];
      final sub = repo
          .watchRange('p1', from: _d(1), to: _d(31))
          .listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen.single.keys, [_d(10)]);
      await repo.markOff('p1', [_d(12)]);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.keys.toSet(), {_d(10), _d(12)});
      await sub.cancel();
    });

    test(
      'markOff never overwrites a booked day; clearOff keeps it too',
      () async {
        final repo = FakeAvailabilityRepository()
          ..seed('p1', AvailabilityDay(day: _d(10), state: DayState.booked));
        await repo.markOff('p1', [_d(10), _d(11)]);
        expect(repo.stored('p1')[_d(10)]!.state, DayState.booked);
        expect(repo.stored('p1')[_d(11)]!.state, DayState.off);
        await repo.clearOff('p1', [_d(10), _d(11)]);
        expect(repo.stored('p1').keys, [_d(10)]);
      },
    );

    test(
      'days are normalised to calendar days and users stay separate',
      () async {
        final repo = FakeAvailabilityRepository();
        await repo.markOff('p1', [DateTime.utc(2026, 10, 12, 9, 30)]);
        expect(repo.stored('p1').keys, [_d(12)]);
        expect(repo.stored('p2'), isEmpty);
      },
    );

    test('counts open listeners and fails writes on request', () async {
      final repo = FakeAvailabilityRepository(failWrites: true);
      final sub = repo.watchRange('p1', from: _d(1), to: _d(31)).listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(repo.watchers, 1);
      await expectLater(repo.markOff('p1', [_d(3)]), throwsStateError);
      expect(repo.stored('p1'), isEmpty);
      await sub.cancel();
      expect(repo.watchers, 0);
    });

    test('fails new watches on request', () async {
      final repo = FakeAvailabilityRepository(failWatch: true);
      await expectLater(
        repo.watchRange('p1', from: _d(1), to: _d(31)),
        emitsError(isStateError),
      );
      repo.failWatch = false;
      await expectLater(
        repo.watchRange('p1', from: _d(1), to: _d(31)),
        emits(isEmpty),
      );
    });
  });
}
