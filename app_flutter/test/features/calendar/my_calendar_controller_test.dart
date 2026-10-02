import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/calendar/my_calendar_controller.dart';

import '../../support/photographer_world.dart';

DateTime _d(int day) => DateTime.utc(2026, 10, day);

void main() {
  test(
    'freeDaysBetween keeps only free days from today on, in either order',
    () {
      final known = {
        _d(11): AvailabilityDay(day: _d(11), state: DayState.booked),
      };
      expect(freeDaysBetween(_d(12), _d(9), known, from: _d(10)), [
        _d(10),
        _d(12),
      ]);
    },
  );

  test('monthWindow is three months, clamped to the bounds', () {
    final first = DateTime.utc(2026, 10);
    final last = DateTime.utc(2027, 10);
    expect(monthWindow(DateTime.utc(2026, 10), first: first, last: last), [
      DateTime.utc(2026, 10),
      DateTime.utc(2026, 11),
      DateTime.utc(2026, 12),
    ]);
    expect(monthWindow(DateTime.utc(2027, 2), first: first, last: last), [
      DateTime.utc(2027, 1),
      DateTime.utc(2027, 2),
      DateTime.utc(2027, 3),
    ]);
    expect(monthWindow(DateTime.utc(2027, 10), first: first, last: last), [
      DateTime.utc(2027, 8),
      DateTime.utc(2027, 9),
      DateTime.utc(2027, 10),
    ]);
  });

  test(
    'the controller writes for the signed-in photographer and reports failures',
    () async {
      final w = PhotographerWorld();
      await w.init();
      final c = ProviderContainer(
        overrides: w.overrides,
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      final sub = c.listen(calendarEditControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final edit = c.read(calendarEditControllerProvider.notifier);
      expect(await edit.markOff([_d(12), _d(13)]), isTrue);
      expect(w.availability.stored(w.uid).keys.toSet(), {_d(12), _d(13)});
      expect(await edit.clearOff([_d(12)]), isTrue);
      expect(w.availability.stored(w.uid).keys, [_d(13)]);
      w.availability.failWrites = true;
      expect(await edit.markOff([_d(20)]), isFalse);
    },
  );
}
