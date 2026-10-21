// test/features/spots/spot_schedule_edit_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/spots/spot_schedule_edit_controller.dart';

import '../../support/fake_spot_repository.dart';

/// Thursday 08/10/2026, 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);
const _uid = 'provider_1';

DateTime _d(String key) => parseDayKey(key)!;

class _H {
  _H(this.c, this.args);
  final ProviderContainer c;
  final SpotScheduleEditArgs args;
}

void main() {
  late FakeSpotRepository spots;
  late FakeAvailabilityRepository availability;

  setUp(() {
    spots = FakeSpotRepository()..ownerId = _uid;
    availability = FakeAvailabilityRepository();
  });

  Future<_H> open({
    bool studio = false,
    SpotSchedule? existing,
    String? spotId,
  }) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: const AuthUser(uid: _uid)),
        ),
        clockProvider.overrideWithValue(() => _now),
        availabilityRepositoryProvider.overrideWithValue(availability),
        spotRepositoryProvider.overrideWithValue(spots),
      ],
    );
    addTearDown(c.dispose);
    final args = SpotScheduleEditArgs(
      existing: existing,
      spotId: spotId,
      studio: studio,
    );
    // Keep the autoDispose controller alive for the whole test.
    c.listen(spotScheduleEditControllerProvider(args), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    return _H(c, args);
  }

  SpotScheduleEditController ctl(_H h) =>
      h.c.read(spotScheduleEditControllerProvider(h.args).notifier);

  SpotScheduleEditState st(_H h) =>
      h.c.read(spotScheduleEditControllerProvider(h.args));

  test('repeat mode expands Sat+Sun from 08/10 to 01/11 into 8 days', () async {
    final h = await open();
    ctl(h)
      ..setMode(SpotScheduleMode.repeat)
      ..setWeekdays({DateTime.saturday, DateTime.sunday})
      ..setRange(from: '2026-10-08', to: '2026-11-01');
    expect(st(h).days, [
      '2026-10-10',
      '2026-10-11',
      '2026-10-17',
      '2026-10-18',
      '2026-10-24',
      '2026-10-25',
      '2026-10-31',
      '2026-11-01',
    ]);
  });

  test('pick mode toggles days', () async {
    final h = await open();
    ctl(h)
      ..setMode(SpotScheduleMode.pick)
      ..toggleDay('2026-10-17')
      ..toggleDay('2026-10-10')
      ..toggleDay('2026-10-24')
      ..toggleDay('2026-10-17');
    expect(st(h).days, ['2026-10-10', '2026-10-24']);
  });

  test('a booked day and an off day are marked with their reasons and block '
      'submit', () async {
    availability
      ..seed(
        _uid,
        AvailabilityDay(
          day: _d('2026-10-10'),
          state: DayState.booked,
          bookingId: 'b1',
        ),
      )
      ..seed(_uid, AvailabilityDay(day: _d('2026-10-11'), state: DayState.off));
    final h = await open(spotId: 'spot_1');
    ctl(h).setRange(from: '2026-10-08', to: '2026-10-18');
    await Future<void>.delayed(Duration.zero);

    expect(st(h).conflicts, {
      '2026-10-10': SpotDayConflictReason.booked,
      '2026-10-11': SpotDayConflictReason.off,
    });
    expect(await ctl(h).submit(), isFalse);
    expect(spots.saveScheduleCalls, isEmpty);

    // Tapping both red days away lets it through.
    ctl(h)
      ..toggleDay('2026-10-10')
      ..toggleDay('2026-10-11');
    expect(st(h).conflicts, isEmpty);
    expect(await ctl(h).submit(), isTrue);
    expect(spots.saveScheduleCalls.single.days, ['2026-10-17', '2026-10-18']);
  });

  test(
    'more than 40 days or a day after +60 shows spotScheduleTooMany',
    () async {
      final h = await open(spotId: 'spot_1');
      ctl(h)
        ..setWeekdays({1, 2, 3, 4, 5, 6, 7})
        ..setRange(from: '2026-10-08', to: '2026-11-30');
      expect(st(h).days.length, greaterThan(40));
      expect(await ctl(h).submit(), isFalse);
      expect(st(h).failure, SpotScheduleFailure.tooMany);

      ctl(h)
        ..setMode(SpotScheduleMode.pick)
        ..toggleDay('2026-12-08'); // today + 61
      expect(await ctl(h).submit(), isFalse);
      expect(st(h).failure, SpotScheduleFailure.tooMany);
      expect(spots.saveScheduleCalls, isEmpty);
    },
  );

  test(
    'window 04:45 or shorter than 1 h shows spotScheduleWindowInvalid',
    () async {
      final h = await open(spotId: 'spot_1');
      ctl(h).setWindow(const SpotWindow(start: '04:45', end: '08:00'));
      expect(await ctl(h).submit(), isFalse);
      expect(st(h).failure, SpotScheduleFailure.windowInvalid);

      ctl(h).setWindow(const SpotWindow(start: '06:00', end: '06:45'));
      expect(await ctl(h).submit(), isFalse);
      expect(st(h).failure, SpotScheduleFailure.windowInvalid);
      expect(spots.saveScheduleCalls, isEmpty);
    },
  );

  test('submit sends spotId, days, window, serviceIds ([] for Mọi gói) and '
      'assigneeId for a studio', () async {
    final h = await open();
    ctl(h)
      ..pickSpot('spot_1')
      ..setRange(from: '2026-10-08', to: '2026-10-18')
      ..setWindow(const SpotWindow(start: '06:00', end: '11:00'));
    expect(await ctl(h).submit(), isTrue);
    final input = spots.saveScheduleCalls.single;
    expect(input.spotId, 'spot_1');
    expect(input.days, [
      '2026-10-10',
      '2026-10-11',
      '2026-10-17',
      '2026-10-18',
    ]);
    expect(input.window, const SpotWindow(start: '06:00', end: '11:00'));
    expect(input.serviceIds, isEmpty);
    expect(input.assigneeId, isNull);
    expect(input.toCallable().containsKey('assigneeId'), isFalse);
    expect(st(h).phase, SpotSchedulePhase.done);

    // A studio names the member, and the member's calendar decides.
    availability.seed(
      'm1',
      AvailabilityDay(
        day: _d('2026-10-17'),
        state: DayState.booked,
        bookingId: 'b9',
      ),
    );
    final s = await open(studio: true, spotId: 'spot_1');
    expect(await ctl(s).submit(), isFalse);
    expect(st(s).failure, SpotScheduleFailure.memberRequired);
    ctl(s)
      ..setRange(from: '2026-10-08', to: '2026-10-18')
      ..togglePackage('pkg2')
      ..togglePackage('pkg1')
      ..setAssignee('m1');
    await Future<void>.delayed(Duration.zero);
    expect(st(s).conflicts, {'2026-10-17': SpotDayConflictReason.booked});
    ctl(s).toggleDay('2026-10-17');
    expect(await ctl(s).submit(), isTrue);
    final studioInput = spots.saveScheduleCalls.last;
    expect(studioInput.assigneeId, 'm1');
    expect(studioInput.serviceIds, ['pkg1', 'pkg2']);
    expect(studioInput.days, ['2026-10-10', '2026-10-11', '2026-10-18']);
  });

  test(
    'editing keeps the spot and the future days, and sends the id',
    () async {
      final h = await open(
        existing: const SpotSchedule(
          id: 'sch1',
          providerId: _uid,
          spotId: 'spot_1',
          assigneeId: null,
          days: ['2026-10-03', '2026-10-10', '2026-10-11'],
          window: SpotWindow(start: '15:00', end: '19:00'),
          serviceIds: ['pkg1'],
          priceFrom: 900000,
          open: true,
        ),
      );
      // Its own spot record is not a conflict.
      availability.seed(
        _uid,
        AvailabilityDay(
          day: _d('2026-10-10'),
          state: DayState.booked,
          scheduleId: 'sch1',
          rawState: 'spot',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(st(h).mode, SpotScheduleMode.pick);
      expect(st(h).spotLocked, isTrue);
      expect(st(h).days, ['2026-10-10', '2026-10-11']);
      expect(st(h).conflicts, isEmpty);
      ctl(h).pickSpot('spot_2');
      expect(await ctl(h).submit(), isTrue);
      final input = spots.saveScheduleCalls.single;
      expect(input.scheduleId, 'sch1');
      expect(input.spotId, 'spot_1');
      expect(input.serviceIds, ['pkg1']);
    },
  );

  test('server day_conflict marks the returned days red', () async {
    spots.saveScheduleError = const SpotError(
      SpotErrorCode.dayConflict,
      field: 'days',
      conflicts: {'2026-10-17': SpotDayConflictReason.spot},
    );
    final h = await open(spotId: 'spot_1');
    ctl(h).setRange(from: '2026-10-08', to: '2026-10-18');
    expect(await ctl(h).submit(), isFalse);
    expect(st(h).conflicts, {'2026-10-17': SpotDayConflictReason.spot});
    expect(st(h).failure, isNull);
  });

  test('schedule_limit shows spotScheduleLimit', () async {
    spots.saveScheduleError = const SpotError(SpotErrorCode.scheduleLimit);
    final h = await open(spotId: 'spot_1');
    expect(await ctl(h).submit(), isFalse);
    expect(st(h).failure, SpotScheduleFailure.limit);
    expect(st(h).phase, SpotSchedulePhase.idle);
  });

  test('not_accepting_orders shows spotScheduleNotAccepting', () async {
    spots.saveScheduleError = const SpotError(SpotErrorCode.notAcceptingOrders);
    final h = await open(spotId: 'spot_1');
    expect(await ctl(h).submit(), isFalse);
    expect(st(h).failure, SpotScheduleFailure.notAccepting);

    spots.saveScheduleError = const SpotError(
      SpotErrorCode.notAcceptingOrders,
      field: 'assigneeId',
    );
    final s = await open(studio: true, spotId: 'spot_1');
    ctl(s).setAssignee('m1');
    expect(await ctl(s).submit(), isFalse);
    expect(st(s).failure, SpotScheduleFailure.memberNotAccepting);
  });

  test('schedule_has_bookings keeps the counts the server sent', () async {
    spots.saveScheduleError = const SpotError(
      SpotErrorCode.scheduleHasBookings,
      bookingCounts: {'2026-10-18': 2},
    );
    final h = await open(spotId: 'spot_1');
    expect(await ctl(h).submit(), isFalse);
    expect(st(h).failure, SpotScheduleFailure.hasBookings);
    expect(st(h).bookingCounts, {'2026-10-18': 2});
  });

  test('openScheduleCount counts open schedules with a day from today', () {
    SpotSchedule s(String id, List<String> days, {bool open = true}) =>
        SpotSchedule(
          id: id,
          providerId: _uid,
          spotId: 'spot_1',
          assigneeId: null,
          days: days,
          window: const SpotWindow(start: '06:00', end: '11:00'),
          serviceIds: const [],
          priceFrom: null,
          open: open,
        );
    expect(
      openScheduleCount([
        s('a', ['2026-10-01', '2026-10-08']),
        s('b', ['2026-10-01']),
        s('c', ['2026-10-20'], open: false),
        s('d', ['2026-11-01']),
      ], '2026-10-08'),
      2,
    );
  });
}
