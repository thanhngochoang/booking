import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/features/notifications/notifications_controller.dart';

import '../../support/notifications_world.dart';

Future<(NotificationsWorld, ProviderContainer)> _make(
  List<AppNotification> Function(NotificationsWorld w) rows,
) async {
  final w = NotificationsWorld();
  final world = NotificationsWorld(rows: rows(w));
  await world.init();
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: world.overrides,
  );
  addTearDown(c.dispose);
  return (world, c);
}

Future<NotificationsState> _ready(ProviderContainer c) async {
  c.listen(notificationsControllerProvider, (_, _) {});
  return c.read(notificationsControllerProvider.future);
}

List<String> _ids(ProviderContainer c) => [
  for (final n in c.read(notificationsControllerProvider).value!.items) n.id,
];

void main() {
  test('the first page is the newest 30 and carries a cursor', () async {
    final (_, c) = await _make(
      (w) => [for (var i = 0; i < 35; i++) w.note('n$i', minutesAgo: 5 + i)],
    );
    final s = await _ready(c);
    expect(s.items, hasLength(30));
    expect(s.items.first.id, 'n0');
    expect(s.next, isNotNull);
  });

  test('load more appends the next page without duplicates', () async {
    final (_, c) = await _make(
      (w) => [for (var i = 0; i < 35; i++) w.note('n$i', minutesAgo: 5 + i)],
    );
    await _ready(c);
    final ctrl = c.read(notificationsControllerProvider.notifier);
    await ctrl.loadMore();
    await ctrl.loadMore(); // already at the end: nothing happens
    final ids = _ids(c);
    expect(ids, hasLength(35));
    expect(ids.toSet(), hasLength(35));
    expect(c.read(notificationsControllerProvider).value!.next, isNull);
  });

  test('the live page replaces only the first rows and keeps older ones '
      'once', () async {
    final (world, c) = await _make(
      (w) => [for (var i = 0; i < 35; i++) w.note('n$i', minutesAgo: 10 + i)],
    );
    await _ready(c);
    final ctrl = c.read(notificationsControllerProvider.notifier);
    await ctrl.loadMore();
    expect(_ids(c), hasLength(35));
    // A new row arrives: the window slides, nothing is lost or doubled.
    world.fake.add(world.note('fresh', minutesAgo: 1));
    await pumpEventQueue();
    final ids = _ids(c);
    expect(ids.first, 'fresh');
    expect(ids, hasLength(36));
    expect(ids.toSet(), hasLength(36));
    expect(ids.indexOf('n29'), lessThan(ids.indexOf('n30')));
  });

  test('pending marks go out as one batch after a second', () async {
    final (world, c) = await _make(
      (w) => [
        w.note('a'),
        w.note('b', minutesAgo: 6),
        w.note('c', minutesAgo: 7),
      ],
    );
    await _ready(c);
    final ctrl = c.read(notificationsControllerProvider.notifier);
    ctrl.markRead('a');
    ctrl.markRead('b');
    ctrl.markRead('a'); // twice is still once
    // Read at once in the state, written later.
    expect(
      c
          .read(notificationsControllerProvider)
          .value!
          .items
          .where((n) => n.unread),
      hasLength(1),
    );
    expect(world.fake.calls.where((e) => e.startsWith('markRead')), isEmpty);
    await Future<void>.delayed(
      notificationReadDebounce + const Duration(milliseconds: 100),
    );
    expect(world.fake.calls.where((e) => e.startsWith('markRead')).toList(), [
      'markRead:a,b',
    ]);
  });

  test('disposing flushes marks still waiting', () async {
    final (world, c) = await _make((w) => [w.note('a')]);
    await _ready(c);
    c.read(notificationsControllerProvider.notifier).markRead('a');
    c.dispose();
    await pumpEventQueue();
    expect(world.fake.calls, contains('markRead:a'));
  });

  test('mark all marks every loaded row', () async {
    final (world, c) = await _make((w) => [w.note('a'), w.note('b')]);
    await _ready(c);
    await c.read(notificationsControllerProvider.notifier).markAllRead();
    expect(world.fake.calls, contains('markAllRead'));
    expect(
      c
          .read(notificationsControllerProvider)
          .value!
          .items
          .every((n) => !n.unread),
      isTrue,
    );
  });

  test('a failing mark all throws and leaves the rows unread', () async {
    final (world, c) = await _make((w) => [w.note('a')]);
    await _ready(c);
    world.fake.failWith = Exception('offline');
    await expectLater(
      c.read(notificationsControllerProvider.notifier).markAllRead(),
      throwsException,
    );
    expect(
      c.read(notificationsControllerProvider).value!.items.single.unread,
      isTrue,
    );
  });

  test('mute: booking rows do nothing, others switch the category off and '
      'undo restores', () async {
    final (world, c) = await _make(
      (w) => [
        w.note('bk'),
        w.note(
          'ev',
          type: 'event_soon',
          tab: NotificationTab.events,
          category: NotificationCategory.events,
        ),
      ],
    );
    final s = await _ready(c);
    final ctrl = c.read(notificationsControllerProvider.notifier);
    final booking = s.items.firstWhere((n) => n.id == 'bk');
    final event = s.items.firstWhere((n) => n.id == 'ev');
    expect(await ctrl.mute(booking), isNull);
    expect(world.prefs.saved, isEmpty);

    final undo = await ctrl.mute(event);
    expect(undo, isNotNull);
    final ch = world.prefs.current.channels[NotificationCategory.events]!;
    expect((ch.push, ch.inApp), (false, false));
    await undo!.undo();
    expect(world.prefs.current, NotificationPrefs.defaults);
  });

  test('refresh re-subscribes', () async {
    final (world, c) = await _make((w) => [w.note('a')]);
    await _ready(c);
    await c.read(notificationsControllerProvider.notifier).refresh();
    expect(
      world.fake.calls.where((e) => e.startsWith('watchFirstPage')),
      hasLength(2),
    );
    expect(world.fake.listeners, 1);
  });

  test('the tab filter re-queries and resets with the screen', () async {
    final (world, c) = await _make((w) => [w.note('a')]);
    await _ready(c);
    c.read(notificationTabFilterProvider.notifier).state =
        NotificationTab.system;
    await c.read(notificationsControllerProvider.future);
    await pumpEventQueue();
    expect(world.fake.calls, contains('watchFirstPage:system'));
    expect(_ids(c), isEmpty);
  });

  test('mute refuses when the prefs come from the cache', () async {
    final (world, c) = await _make(
      (w) => [
        w.note(
          'ev',
          type: 'event_soon',
          tab: NotificationTab.events,
          category: NotificationCategory.events,
        ),
      ],
    );
    world.prefs.fromCache = true;
    final s = await _ready(c);
    c.listen(notificationPrefsProvider, (_, _) {});
    await c.read(notificationPrefsProvider.future);
    expect(
      () =>
          c.read(notificationsControllerProvider.notifier).mute(s.items.first),
      throwsA(isA<MuteUnavailable>()),
    );
    expect(world.prefs.saved, isEmpty);
  });

  test('a failed batch is retried one id at a time', () async {
    final (world, c) = await _make((w) => [w.note('a'), w.note('b')]);
    await _ready(c);
    world.fake.failBatches = true;
    final ctrl = c.read(notificationsControllerProvider.notifier)
      ..markRead('a')
      ..markRead('b');
    await Future<void>.delayed(
      notificationReadDebounce + const Duration(milliseconds: 100),
    );
    await pumpEventQueue();
    expect(ctrl, isNotNull);
    expect(world.fake.calls.where((e) => e.startsWith('markRead')).toList(), [
      'markRead:a',
      'markRead:b',
    ]);
  });
}
