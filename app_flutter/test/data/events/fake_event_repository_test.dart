import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

import '../../support/event_world.dart';

void main() {
  late FakeEventRepository repo;

  FakeEventRepository withEvent({
    int priceVnd = 0,
    int capacity = 3,
    int registered = 0,
  }) => FakeEventRepository(
    uid: 'u1',
    clock: () => eventNow,
    events: [
      detailOf(
        'ev1',
        priceVnd: priceVnd,
        capacity: capacity,
        registered: registered,
      ),
    ],
  );

  setUp(() => repo = withEvent());

  test('fake register enforces seats and one active registration', () async {
    final first = await repo.register('ev1', quantity: 2, name: 'Lan');
    expect(first.status, RegistrationStatus.paid);
    expect(repo.event('ev1')!.summary.registeredCount, 2);

    // A second tap returns the same registration and takes no more seats.
    final again = await repo.register('ev1', quantity: 1, name: 'Lan');
    expect(again.registrationId, first.registrationId);
    expect(repo.event('ev1')!.summary.registeredCount, 2);

    // Another user wants two of the one seat left.
    repo.uid = 'u2';
    await expectLater(
      repo.register('ev1', quantity: 2, name: 'Mai'),
      throwsA(isA<EventError>().having((e) => e.code, 'code', 'sold_out')),
    );
    await repo.register('ev1', quantity: 1, name: 'Mai');
    expect(repo.event('ev1')!.summary.status, EventStatus.full);
    repo.uid = 'u3';
    await expectLater(
      repo.register('ev1', quantity: 1, name: 'Cúc'),
      throwsA(isA<EventError>().having((e) => e.code, 'code', 'sold_out')),
    );
  });

  test('fake register checks quantity, phone, deadline and the host', () async {
    Matcher code(String c) =>
        throwsA(isA<EventError>().having((e) => e.code, 'code', c));
    await expectLater(
      repo.register('ev1', quantity: 0, name: 'x'),
      code('invalid_argument'),
    );
    await expectLater(
      repo.register('ev1', quantity: 5, name: 'x'),
      code('limit_exceeded'),
    );
    await expectLater(
      repo.register('nope', quantity: 1, name: 'x'),
      code('not_found'),
    );
    repo.hasPhone = false;
    await expectLater(
      repo.register('ev1', quantity: 1, name: 'x'),
      code('phone_required'),
    );
    repo.hasPhone = true;
    repo.uid = 'p1'; // the host
    await expectLater(
      repo.register('ev1', quantity: 1, name: 'x'),
      code('permission_denied'),
    );
    final late = FakeEventRepository(
      uid: 'u1',
      clock: () => eventNow.add(const Duration(days: 3)),
      events: [detailOf('ev1')],
    );
    await expectLater(
      late.register('ev1', quantity: 1, name: 'x'),
      code('deadline_passed'),
    );
  });

  test(
    'a paid event is held for ten minutes and a free ticket unlocks no contact',
    () async {
      final paid = withEvent(priceVnd: 200000);
      final out = await paid.register('ev1', quantity: 2, name: 'Lan');
      expect(out.status, RegistrationStatus.held);
      expect(out.holdExpiresAt, eventNow.add(const Duration(minutes: 10)));
      expect(out.payUrl, isNotNull);
      expect(paid.event('ev1')!.summary.heldCount, 2);

      final reg = (await repo.register('ev1', quantity: 1, name: 'Lan'));
      final mine = (await repo.watchMyRegistration('ev1').first)!;
      expect(mine.id, reg.registrationId);
      expect(mine.contactEligible, isFalse);
      expect(await repo.watchRegistrationContact('ev1', mine.id).first, isNull);
    },
  );

  test(
    'cancelling frees the seat and a cancelled ticket is no longer active',
    () async {
      final out = await repo.register('ev1', quantity: 2, name: 'Lan');
      final result = await repo.cancelRegistration('ev1', out.registrationId);
      expect(result.status, RegistrationStatus.cancelled);
      expect(result.refundPercent, isNull);
      expect(repo.event('ev1')!.summary.registeredCount, 0);
      final mine = (await repo.watchMyRegistration('ev1').first)!;
      expect(mine.status, RegistrationStatus.cancelled);
      // Registering again is possible.
      final again = await repo.register('ev1', quantity: 1, name: 'Lan');
      expect(again.registrationId, isNot(out.registrationId));
    },
  );

  test('check-in accepts a paid ticket once', () async {
    final out = await repo.register('ev1', quantity: 2, name: 'Lan');
    final code = repo.registrations.single.ticketCode;
    expect(out.status, RegistrationStatus.paid);
    final r = await repo.checkIn('ev1', code);
    expect((r.name, r.quantity), ('Lan', 2));
    await expectLater(
      repo.checkIn('ev1', code),
      throwsA(isA<EventError>().having((e) => e.code, 'code', 'conflict')),
    );
    await expectLater(
      repo.checkIn('ev1', 'VE-NOPE-0000'),
      throwsA(isA<EventError>().having((e) => e.code, 'code', 'not_found')),
    );
  });

  test(
    'the list filters by status, type and price and pages by cursor',
    () async {
      final r = FakeEventRepository(
        events: [
          detailOf('a', startsIn: const Duration(days: 1)),
          detailOf('b', priceVnd: 0, startsIn: const Duration(days: 2)),
          detailOf('c', startsIn: const Duration(days: 3)),
          detailOf('d', status: EventStatus.draft),
        ],
      );
      final p1 = await r.list(from: eventNow, limit: 2);
      expect(p1.events.map((e) => e.id), ['a', 'b']);
      final p2 = await r.list(from: eventNow, limit: 2, cursor: p1.nextCursor);
      expect(p2.events.map((e) => e.id), ['c']);
      expect(p2.nextCursor, isNull);
      expect(
        (await r.list(from: eventNow, freeOnly: true)).events.map((e) => e.id),
        ['b'],
      );
    },
  );

  test('streams follow changes and an injected failure surfaces', () async {
    final seen = <int>[];
    final sub = repo
        .watchEvent('ev1')
        .listen((e) => seen.add(e!.summary.registeredCount));
    await Future<void>.delayed(Duration.zero);
    await repo.register('ev1', quantity: 1, name: 'Lan');
    await Future<void>.delayed(Duration.zero);
    expect(seen, [0, 1]);
    await sub.cancel();
    repo.failWith = const EventError('network');
    await expectLater(repo.publish('ev1'), throwsA(isA<EventError>()));
  });

  test('uploadCover remembers the path of the url it returns', () async {
    final url = await repo.uploadCover(
      'e' * 24,
      const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'),
    );
    expect(repo.coverPaths[url], startsWith('eventCovers/u1/${'e' * 24}/'));
  });
}
