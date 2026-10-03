// test/features/booking/booking_flow_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

void main() {
  const photographerId = 'p1';
  final today = DateTime.utc(2026, 10, 3, 10, 0);

  const package1 = ServiceSummary(
    id: 's1',
    photographerId: photographerId,
    name: 'Gói Chân Dung',
    priceVnd: 1500000,
    durationMinutes: 120,
    active: true,
  );

  const package2 = ServiceSummary(
    id: 's2',
    photographerId: photographerId,
    name: 'Gói Ngoại Cảnh',
    priceVnd: 2500000,
    durationMinutes: 240,
    active: true,
  );

  ProviderContainer makeContainer({
    List<ServiceSummary>? packages,
    UserContact? contact,
    DateTime? now,
  }) {
    final effectiveNow = now ?? today;
    return ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => effectiveNow),
        calendarTodayProvider.overrideWithValue(effectiveNow),
        profilePackagesProvider(photographerId).overrideWithValue(
          AsyncData(packages ?? [package1, package2]),
        ),
        currentContactProvider.overrideWithValue(
          AsyncData(contact ?? const UserContact(phone: '+84912345678')),
        ),
      ],
    );
  }

  test('starts on the package step without arguments', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final state = container.read(bookingFlowControllerProvider(args));

    expect(state.step, BookingStep.service);
    expect(state.serviceId, isNull);
    expect(state.phone, '+84912345678');
  });

  test('skips the package step when serviceId is an active package', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(
      photographerId: photographerId,
      serviceId: 's2',
    );
    final state = container.read(bookingFlowControllerProvider(args));

    expect(state.step, BookingStep.datetime);
    expect(state.serviceId, 's2');
    expect(state.priceVnd, 2500000);
    expect(state.durationMinutes, 240);
  });

  test('falls back to the package step when serviceId is unknown or hidden', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(
      photographerId: photographerId,
      serviceId: 's_unknown',
    );
    final state = container.read(bookingFlowControllerProvider(args));

    expect(state.step, BookingStep.service);
    expect(state.serviceId, isNull);
  });

  test('a single package is pre-selected but the step still shows', () async {
    final container = makeContainer(packages: [package1]);
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final state = container.read(bookingFlowControllerProvider(args));

    expect(state.step, BookingStep.service);
    expect(state.serviceId, 's1');
    expect(state.canContinue, isTrue);
  });

  test('preselects the day from S02.06 only when it is today or later', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Yesterday: not preselected
    const argsYesterday = BookingFlowArgs(
      photographerId: photographerId,
      day: '2026-10-02',
    );
    final stateYesterday =
        container.read(bookingFlowControllerProvider(argsYesterday));
    expect(stateYesterday.day, isNull);

    // Today: preselected
    const argsToday = BookingFlowArgs(
      photographerId: photographerId,
      day: '2026-10-03',
    );
    final stateToday = container.read(bookingFlowControllerProvider(argsToday));
    expect(stateToday.day, '2026-10-03');

    // Future day: preselected
    const argsFuture = BookingFlowArgs(
      photographerId: photographerId,
      day: '2026-10-15',
    );
    final stateFuture = container.read(bookingFlowControllerProvider(argsFuture));
    expect(stateFuture.day, '2026-10-15');
  });

  test('changing the package to another duration clears the start time', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    ctrl.selectService(package1); // 120 mins
    ctrl.selectDay('2026-10-05');
    ctrl.selectStart('15:30');
    expect(container.read(bookingFlowControllerProvider(args)).start, '15:30');

    // Select package2 with 240 mins -> start time cleared
    ctrl.selectService(package2);
    expect(container.read(bookingFlowControllerProvider(args)).start, isNull);
  });

  test('changing the day clears the start time', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    ctrl.selectDay('2026-10-05');
    ctrl.selectStart('10:00');
    expect(container.read(bookingFlowControllerProvider(args)).start, '10:00');

    ctrl.selectDay('2026-10-06');
    expect(container.read(bookingFlowControllerProvider(args)).start, isNull);
  });

  test('deposit and remaining always add up to the price', () {
    const testPrices = [1, 4, 1500000, 1234567];
    for (final price in testPrices) {
      final (:deposit, :remaining) = depositFor(price);
      expect(deposit + remaining, price);
      expect(deposit, (price * 0.3).floor());
    }
  });

  test('place needs at least 3 graphemes', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    ctrl.selectService(package1);
    ctrl.selectDay('2026-10-05');
    ctrl.selectStart('09:00');
    ctrl.next(); // datetime
    ctrl.next(); // place
    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.place);

    ctrl.setPlace('Hồ'); // 2 graphemes
    expect(container.read(bookingFlowControllerProvider(args)).canContinue, isFalse);

    ctrl.setPlace('Hồ T'); // 4 graphemes
    expect(container.read(bookingFlowControllerProvider(args)).canContinue, isTrue);

    ctrl.setPlace('👨‍👩‍👧 x'); // emoji (1 grapheme) + space + x = 3 graphemes
    expect(container.read(bookingFlowControllerProvider(args)).canContinue, isTrue);
  });

  test('note is cut at 300 graphemes', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    final longNote = 'a' * 350;
    ctrl.setNote(longNote);
    expect(container.read(bookingFlowControllerProvider(args)).note.length, 300);
  });

  test('back walks review → place → datetime → service and returns false on the first step; choices survive', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    ctrl.selectService(package1);
    ctrl.next();
    ctrl.selectDay('2026-10-05');
    ctrl.selectStart('09:00');
    ctrl.next();
    ctrl.setPlace('Công viên Gia Định');
    ctrl.next();

    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.review);

    // review -> place
    expect(ctrl.back(), isTrue);
    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.place);
    expect(container.read(bookingFlowControllerProvider(args)).placeName, 'Công viên Gia Định');

    // place -> datetime
    expect(ctrl.back(), isTrue);
    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.datetime);
    expect(container.read(bookingFlowControllerProvider(args)).day, '2026-10-05');
    expect(container.read(bookingFlowControllerProvider(args)).start, '09:00');

    // datetime -> service
    expect(ctrl.back(), isTrue);
    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.service);
    expect(container.read(bookingFlowControllerProvider(args)).serviceId, 's1');

    // service -> returns false
    expect(ctrl.back(), isFalse);
    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.service);
  });

  test('next does nothing while canContinue is false', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    expect(container.read(bookingFlowControllerProvider(args)).canContinue, isFalse);
    ctrl.next();
    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.service);
  });

  test("applyPackages marks priceChanged and updates the total when the chosen package's price moved", () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    ctrl.selectService(package1);
    expect(container.read(bookingFlowControllerProvider(args)).priceVnd, 1500000);
    expect(container.read(bookingFlowControllerProvider(args)).priceChanged, isFalse);

    // Packages updated with higher price for package1
    const updatedPackage1 = ServiceSummary(
      id: 's1',
      photographerId: photographerId,
      name: 'Gói Chân Dung',
      priceVnd: 1800000,
      durationMinutes: 120,
    );
    ctrl.applyPackages([updatedPackage1, package2]);

    final state = container.read(bookingFlowControllerProvider(args));
    expect(state.priceVnd, 1800000);
    expect(state.priceChanged, isTrue);
  });

  test('clearDay(taken: true) un-selects the day, remembers it in takenDays and goes back to datetime', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);
    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);

    ctrl.selectService(package1);
    ctrl.next();
    ctrl.selectDay('2026-10-05');
    ctrl.selectStart('09:00');
    ctrl.next();
    ctrl.setPlace('Studio A');
    ctrl.next();

    expect(container.read(bookingFlowControllerProvider(args)).step, BookingStep.review);

    ctrl.clearDay('2026-10-05', taken: true);

    final state = container.read(bookingFlowControllerProvider(args));
    expect(state.step, BookingStep.datetime);
    expect(state.day, isNull);
    expect(state.start, isNull);
    expect(state.takenDays.contains('2026-10-05'), isTrue);
  });

  test('restores the flow after the phone detour', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    const args = BookingFlowArgs(photographerId: photographerId);

    // Listen to keep provider alive
    final sub = container.listen(bookingFlowControllerProvider(args), (_, _) {});
    addTearDown(sub.close);

    final ctrl = container.read(bookingFlowControllerProvider(args).notifier);
    ctrl.selectService(package1);
    ctrl.next();
    ctrl.selectDay('2026-10-08');
    ctrl.selectStart('14:00');
    ctrl.next();
    ctrl.setPlace('Bảo tàng Mỹ thuật');

    // Detour happens, read again with same args
    final state = container.read(bookingFlowControllerProvider(args));
    expect(state.serviceId, 's1');
    expect(state.day, '2026-10-08');
    expect(state.start, '14:00');
    expect(state.placeName, 'Bảo tàng Mỹ thuật');
    expect(state.step, BookingStep.place);
  });
}
