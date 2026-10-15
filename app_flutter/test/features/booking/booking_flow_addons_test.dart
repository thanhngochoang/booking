// test/features/booking/booking_flow_addons_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/booking_world.dart';
import '../../support/fake_addon_repository.dart';
import '../../support/fake_booking_repository.dart';

void main() {
  final today = DateTime.utc(2026, 10, 3, 10, 0);
  const couple = ServiceSummary(
    id: 's2',
    photographerId: 'p1',
    name: 'Cặp đôi nửa ngày',
    priceVnd: 3200000,
    durationMinutes: 240,
    active: true,
  );

  late FakeAddonRepository addonRepo;
  late FakeBookingRepository bookings;
  late FakeUserContactRepository contacts;

  /// [liveContact]: the real `currentContactProvider` over a fake contact
  /// repository, so a test can push a new contact value with `contacts.save`.
  ProviderContainer makeContainer({
    List<ServiceAddon>? addons,
    Future<List<ServiceAddon>>? addonsFuture,
    bool liveContact = false,
  }) {
    contacts = FakeUserContactRepository()
      ..seed('c1', const UserContact(phone: '+84912345678'));
    addonRepo = FakeAddonRepository();
    for (final a in addons ?? [addonMakeup, addonRetouch, addonTransport]) {
      addonRepo.seed(a);
    }
    bookings = FakeBookingRepository();
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => today),
        calendarTodayProvider.overrideWithValue(today),
        profilePackagesProvider('p1')
            .overrideWithValue(const AsyncData([bookingPortrait2h, couple])),
        if (liveContact) ...[
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initialUser: const AuthUser(uid: 'c1')),
          ),
          userContactRepositoryProvider.overrideWithValue(contacts),
        ] else
          currentContactProvider.overrideWithValue(
            const AsyncData(UserContact(phone: '+84912345678')),
          ),
        bookingRepositoryProvider.overrideWithValue(bookings),
        photographerPoolCacheProvider.overrideWithValue(
          FakePhotographerRepository(),
        ),
        addonRepositoryProvider.overrideWithValue(addonRepo),
        if (addonsFuture != null)
          activeAddonsProvider('p1').overrideWith((ref) => addonsFuture),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<BookingFlowController> open(
    ProviderContainer container,
    BookingFlowArgs args,
  ) async {
    final sub = container.listen(
      bookingFlowControllerProvider(args),
      (_, _) {},
    );
    addTearDown(sub.close);
    await settle();
    return container.read(bookingFlowControllerProvider(args).notifier);
  }

  const args = BookingFlowArgs(photographerId: 'p1');
  BookingFlowState read(ProviderContainer c, [BookingFlowArgs a = args]) =>
      c.read(bookingFlowControllerProvider(a));

  test(
    'total = package + Σ unitPrice × qty and the continue label shows it',
    () async {
      final c = makeContainer();
      final ctrl = await open(c, args);
      ctrl.selectService(bookingPortrait2h);
      ctrl.setAddonQty('a_makeup', 2);
      ctrl.toggleAddon('a_car');

      final s = read(c);
      expect(s.addonsVnd, 1900000);
      expect(s.totalVnd, 3400000);
      expect(s.payVnd, 3400000);
    },
  );

  test('switching package keeps applicable picks, drops the others and reports their names once', () async {
    final c = makeContainer();
    final ctrl = await open(c, args);
    ctrl.selectService(bookingPortrait2h);
    ctrl.setAddonQty('a_makeup', 2);
    ctrl.toggleAddon('a_car');

    ctrl.selectService(couple);
    expect(read(c).picks, {'a_makeup': 2});
    expect(read(c).droppedAddonNames, ['Xe đón trong nội thành']);

    ctrl.consumeDropped();
    expect(read(c).droppedAddonNames, isEmpty);
  });

  test('dropping the transport pick clears pickupName', () async {
    final c = makeContainer();
    final ctrl = await open(c, args);
    ctrl.selectService(bookingPortrait2h);
    ctrl.toggleAddon('a_car');
    ctrl.setPickup('Ga Sài Gòn');
    expect(read(c).needsPickup, isTrue);

    ctrl.toggleAddon('a_car');
    expect(read(c).needsPickup, isFalse);
    expect(read(c).pickupName, '');
  });

  test('applyAddons removes picks whose add-on disappeared and clamps qty to the new maxQty', () async {
    final c = makeContainer();
    final ctrl = await open(c, args);
    ctrl.selectService(bookingPortrait2h);
    ctrl.setAddonQty('a_makeup', 4);
    ctrl.setAddonQty('a_retouch', 5);

    final smaller = bookingAddon(
      'a_makeup',
      kind: AddonKind.makeup,
      name: 'Trang điểm',
      unit: AddonUnit.perPerson,
      price: 800000,
      maxQty: 2,
    );
    ctrl.applyAddons([smaller, addonTransport]);
    expect(read(c).picks, {'a_makeup': 2});
  });

  test('stepper quantities stay within 0…maxQty', () async {
    final c = makeContainer();
    final ctrl = await open(c, args);
    ctrl.selectService(bookingPortrait2h);
    ctrl.setAddonQty('a_makeup', 9);
    expect(read(c).picks['a_makeup'], 4);
    ctrl.setAddonQty('a_makeup', 0);
    expect(read(c).picks.containsKey('a_makeup'), isFalse);
  });

  group('entry with a preselected package (Decision 11)', () {
    const preselected = BookingFlowArgs(photographerId: 'p1', serviceId: 's1');

    test(
      'entering with a preselected package that has add-ons opens on S04.01',
      () async {
        final c = makeContainer();
        await open(c, preselected);
        expect(read(c, preselected).step, BookingStep.service);
        expect(read(c, preselected).serviceId, 's1');
      },
    );

    test('without add-ons opens on S04.02', () async {
      final c = makeContainer(addons: const []);
      await open(c, preselected);
      expect(read(c, preselected).step, BookingStep.datetime);
    });

    test('a package no add-on applies to opens on S04.02', () async {
      final c = makeContainer(addons: [addonTransport]);
      const other = BookingFlowArgs(photographerId: 'p1', serviceId: 's2');
      await open(c, other);
      expect(read(c, other).step, BookingStep.datetime);
    });

    test('the entry decision is not retaken after the user acted', () async {
      final pending = Completer<List<ServiceAddon>>();
      final c = makeContainer(addonsFuture: pending.future);
      final ctrl = await open(c, preselected);
      expect(read(c, preselected).step, BookingStep.datetime);

      ctrl.selectDay('2026-10-12');
      pending.complete([addonMakeup, addonTransport]);
      await settle();

      expect(read(c, preselected).step, BookingStep.datetime);
      expect(read(c, preselected).addons, hasLength(2));
    });
  });

  Future<BookingFlowController> readyToPay(ProviderContainer c) async {
    final ctrl = await open(c, args);
    ctrl.selectService(bookingPortrait2h);
    ctrl.setAddonQty('a_makeup', 2);
    ctrl.setAddonQty('a_retouch', 1);
    ctrl.setAddonQty('a_retouch', 0);
    ctrl.toggleAddon('a_car');
    ctrl.next();
    ctrl.selectDay('2026-10-12');
    ctrl.selectStart('15:30');
    ctrl.next();
    ctrl.setPlace('Bến Bạch Đằng, Quận 1');
    ctrl.setPickup('Ga Sài Gòn, Quận 3');
    ctrl.next();
    expect(read(c).step, BookingStep.review);
    return ctrl;
  }

  test(
    'place step cannot continue without a pickup when transport is picked',
    () async {
      final c = makeContainer();
      final ctrl = await open(c, args);
      ctrl.selectService(bookingPortrait2h);
      ctrl.toggleAddon('a_car');
      ctrl.next();
      ctrl.selectDay('2026-10-12');
      ctrl.selectStart('15:30');
      ctrl.next();
      ctrl.setPlace('Bến Bạch Đằng');
      expect(read(c).canContinue, isFalse);
      ctrl.setPickup('Ga');
      expect(read(c).canContinue, isFalse);
      ctrl.setPickup('Ga Sài Gòn');
      expect(read(c).canContinue, isTrue);
    },
  );

  test('can continue without pickup when no transport', () async {
    final c = makeContainer();
    final ctrl = await open(c, args);
    ctrl.selectService(bookingPortrait2h);
    ctrl.setAddonQty('a_makeup', 1);
    ctrl.next();
    ctrl.selectDay('2026-10-12');
    ctrl.selectStart('15:30');
    ctrl.next();
    ctrl.setPlace('Bến Bạch Đằng');
    expect(read(c).canContinue, isTrue);
  });

  test('submit sends addons with qty > 0 only, pickup only with transport, expectedPrice = package and expectedTotal = total', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    await ctrl.submit();

    final call = bookings.createCalls.single;
    expect(call.addons, const [
      AddonPick('a_makeup', 2),
      AddonPick('a_car', 1),
    ]);
    expect(call.pickup?.name, 'Ga Sài Gòn, Quận 3');
    expect(call.expectedPrice, 1500000);
    expect(call.expectedTotal, 3400000);
  });

  test(
    'without transport no pickup is sent, and without add-ons no expectedTotal',
    () async {
      final c = makeContainer();
      final ctrl = await open(c, args);
      ctrl.selectService(bookingPortrait2h);
      ctrl.next();
      ctrl.selectDay('2026-10-12');
      ctrl.selectStart('15:30');
      ctrl.next();
      ctrl.setPlace('Bến Bạch Đằng');
      ctrl.setPickup('stray');
      ctrl.next();
      await ctrl.submit();

      final call = bookings.createCalls.single;
      expect(call.addons, isEmpty);
      expect(call.pickup, isNull);
      expect(call.expectedTotal, isNull);
    },
  );

  test('changing picks after a draft clears bookingId and the next submit creates a new draft with the new picks', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    bookings.nextPaymentError = BookingErrorCode.network;
    await ctrl.submit();
    expect(read(c).bookingId, 'booking_1');

    ctrl.setAddonQty('a_makeup', 3);
    expect(read(c).bookingId, isNull);

    await ctrl.submit();
    expect(bookings.createCalls, hasLength(2));
    expect(bookings.createCalls.last.addons, const [
      AddonPick('a_makeup', 3),
      AddonPick('a_car', 1),
    ]);
    expect(bookings.createCalls.last.expectedTotal, 4200000);
  });

  test('a new pickup or package also clears bookingId', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    bookings.nextPaymentError = BookingErrorCode.network;
    await ctrl.submit();
    expect(read(c).bookingId, isNotNull);
    ctrl.setPickup('Nhà hát Thành phố');
    expect(read(c).bookingId, isNull);
  });

  test('a package change clears bookingId (Decision 12)', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    bookings.nextPaymentError = BookingErrorCode.network;
    await ctrl.submit();
    expect(read(c).bookingId, 'booking_1');

    ctrl.selectService(couple);
    expect(read(c).bookingId, isNull);
  });

  group('contact updates keep the flow', () {
    const preselected = BookingFlowArgs(photographerId: 'p1', serviceId: 's1');

    test(
      'a new contact value after the add-ons load keeps S04.01 and the picks',
      () async {
        final c = makeContainer(liveContact: true);
        final ctrl = await open(c, preselected);
        expect(read(c, preselected).step, BookingStep.service);
        expect(read(c, preselected).phone, '+84912345678');

        ctrl.setAddonQty('a_makeup', 2);
        await contacts.save(
          'c1',
          phone: '+84987654321',
          allowZalo: true,
          allowWhatsApp: false,
        );
        await settle();

        final s = read(c, preselected);
        expect(s.step, BookingStep.service);
        expect(s.picks, {'a_makeup': 2});
        expect(s.phone, '+84987654321');
      },
    );

    test(
      'a phone saved during submit does not reset the step or the picks',
      () async {
        final c = makeContainer(liveContact: true);
        final ctrl = await readyToPay(c);
        ctrl.setPhone('+84987654321');
        bookings.nextPaymentError = BookingErrorCode.network;

        await ctrl.submit();
        await settle();

        expect(contacts.stored('c1')?.phone, '+84987654321');
        final s = read(c);
        expect(s.step, BookingStep.review);
        expect(s.picks, {'a_makeup': 2, 'a_car': 1});
        expect(s.pickupName, 'Ga Sài Gòn, Quận 3');
        expect(s.bookingId, 'booking_1');
        expect(s.phone, '+84987654321');
        expect(s.error, BookingErrorCode.network);
      },
    );
  });

  test('addon_changed returns to S04.01, invalidates the add-on list and shows bookAddonsChanged', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    bookings.nextError = BookingErrorCode.addonChanged;
    // The photographer turned the car off meanwhile.
    addonRepo.addons.remove('a_car');

    await ctrl.submit();
    expect(read(c).step, BookingStep.service);
    expect(read(c).error, BookingErrorCode.addonChanged);
    expect(read(c).phase, SubmitPhase.idle);

    await settle();
    expect(read(c).addons.map((a) => a.id), isNot(contains('a_car')));
    expect(read(c).picks, {'a_makeup': 2});
    expect(read(c).pickupName, '');
  });

  test('addon_not_applicable also returns to S04.01', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    bookings.nextError = BookingErrorCode.addonNotApplicable;
    await ctrl.submit();
    expect(read(c).step, BookingStep.service);
    expect(read(c).error, BookingErrorCode.addonNotApplicable);
  });

  test('pickup_required returns to the place step', () async {
    final c = makeContainer();
    final ctrl = await readyToPay(c);
    bookings.nextError = BookingErrorCode.pickupRequired;
    await ctrl.submit();
    expect(read(c).step, BookingStep.place);
    expect(read(c).error, BookingErrorCode.pickupRequired);
    expect(read(c).phase, SubmitPhase.idle);
  });
}
