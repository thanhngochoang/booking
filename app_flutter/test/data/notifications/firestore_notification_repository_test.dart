import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/firestore_notification_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

final _t0 = DateTime.utc(2026, 10, 6, 9);

Map<String, Object?> row(
  int minutesAgo, {
  String tab = 'activity',
  Object? readAt,
  List<Map<String, Object?>>? actors,
  Object? count,
  String title = 'Minh Trí đã nhận lịch',
}) => {
  'type': 'booking_accepted',
  'tab': tab,
  'category': 'booking',
  'title': title,
  'body': 'T7 12/10 · 15:30',
  'target': '/b/b1',
  'actors': actors ?? <Map<String, Object?>>[],
  'count': ?count,
  'createdAt': Timestamp.fromDate(_t0.subtract(Duration(minutes: minutesAgo))),
  'readAt': readAt,
};

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreNotificationRepository repo;

  CollectionReference<Map<String, dynamic>> rows() =>
      db.collection('users').doc('u1').collection('notifications');

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreNotificationRepository(db: db);
  });

  test(
    'a notification doc parses with actors, count and readAt null as unread',
    () async {
      await rows()
          .doc('n1')
          .set(
            row(
              5,
              count: 3,
              actors: [
                {'id': 'a1', 'name': 'Lan', 'avatarUrl': 'https://x/a.jpg'},
                {'id': 'a2', 'name': 'Minh', 'avatarUrl': null},
              ],
            ),
          );
      final page = await repo.watchFirstPage('u1').first;
      final n = page.items.single;
      expect(n.id, 'n1');
      expect(n.unread, isTrue);
      expect(n.readAt, isNull);
      expect(n.count, 3);
      expect(n.category, NotificationCategory.booking);
      expect(n.tab, NotificationTab.activity);
      expect(n.createdAt, _t0.subtract(const Duration(minutes: 5)));
      expect(n.actors.map((a) => a.name), ['Lan', 'Minh']);
      expect(n.actors.first.avatarUrl, 'https://x/a.jpg');
      expect(n.actors.last.avatarUrl, isNull);
    },
  );

  test('a read row has readAt', () async {
    await rows().doc('n1').set(row(5, readAt: Timestamp.fromDate(_t0)));
    final n = (await repo.watchFirstPage('u1').first).items.single;
    expect(n.unread, isFalse);
    expect(n.readAt, _t0);
  });

  test('unknown tab code reads as system', () async {
    await rows().doc('n1').set(row(5, tab: 'mystery'));
    final n = (await repo.watchFirstPage('u1').first).items.single;
    expect(n.tab, NotificationTab.system);
  });

  test('first page listens with tab filter and limit 30, next cursor only on a full page', () async {
    for (var i = 0; i < 35; i++) {
      await rows().doc('a$i').set(row(i + 1));
    }
    await rows().doc('s1').set(row(1, tab: 'system'));

    final all = await repo.watchFirstPage('u1').first;
    expect(all.items, hasLength(30));
    expect(all.next, isNotNull);
    expect(all.items.first.id, 's1', reason: 'newest first');
    expect(all.next!.id, all.items.last.id);

    final sys = await repo
        .watchFirstPage('u1', tab: NotificationTab.system)
        .first;
    expect(sys.items.map((n) => n.id), ['s1']);
    expect(sys.next, isNull);

    final small = await repo
        .watchFirstPage('u1', tab: NotificationTab.activity, limit: 40)
        .first;
    expect(small.items, hasLength(35));
    expect(small.next, isNull);
  });

  test('older page starts after the cursor', () async {
    for (var i = 0; i < 7; i++) {
      await rows().doc('a$i').set(row(i + 1));
    }
    final first = await repo.watchFirstPage('u1', limit: 3).first;
    expect(first.items.map((n) => n.id), ['a0', 'a1', 'a2']);
    final second = await repo.page('u1', after: first.next!, limit: 3);
    expect(second.items.map((n) => n.id), ['a3', 'a4', 'a5']);
    expect(second.next, isNotNull);
    final third = await repo.page('u1', after: second.next!, limit: 3);
    expect(third.items.map((n) => n.id), ['a6']);
    expect(third.next, isNull);
  });

  test('rows sharing a createdAt are returned once across pages', () async {
    for (final (n, size) in [(3, 2), (5, 2), (5, 5), (4, 3)]) {
      final d = FakeFirebaseFirestore();
      final r = FirestoreNotificationRepository(db: d);
      final col = d.collection('users').doc('u1').collection('notifications');
      for (var i = 0; i < n; i++) {
        await col.doc('t$i').set(row(10));
      }
      await col.doc('newer').set(row(1));
      await col.doc('older').set(row(20));

      final seen = <String>[];
      // fake_cloud_firestore leaves ties unordered, so the first page also goes
      // through page(), which sorts (createdAt, id) descending itself.
      var page = await r.page(
        'u1',
        after: NotificationCursor(createdAt: _t0, id: '\uffff'),
        limit: size,
      );
      seen.addAll(page.items.map((x) => x.id));
      while (page.next != null) {
        page = await r.page('u1', after: page.next!, limit: size);
        seen.addAll(page.items.map((x) => x.id));
      }
      expect(seen.toSet(), hasLength(n + 2), reason: 'n=$n limit=$size');
      expect(seen, hasLength(n + 2), reason: 'no duplicates n=$n limit=$size');
      expect(seen.first, 'newer');
      expect(seen.last, 'older');
    }
  });

  test('markRead writes one batch with readAt only', () async {
    await rows().doc('n1').set(row(3));
    await rows().doc('n2').set(row(2));
    await rows().doc('n3').set(row(1));
    await repo.markRead('u1', ['n1', 'n2', 'n1']);

    final n1 = (await rows().doc('n1').get()).data()!;
    expect(n1['readAt'], isA<Timestamp>());
    expect(n1['title'], 'Minh Trí đã nhận lịch');
    expect((await rows().doc('n2').get()).data()!['readAt'], isA<Timestamp>());
    expect((await rows().doc('n3').get()).data()!['readAt'], isNull);

    await repo.markRead('u1', const []);
  });

  test('unread count reads 0 when the field is missing', () async {
    final inbox = db
        .collection('users')
        .doc('u1')
        .collection('private')
        .doc('inbox');
    expect(await repo.watchUnreadCount('u1').first, 0);
    await inbox.set({'lastReadAt': Timestamp.fromDate(_t0)});
    expect(await repo.watchUnreadCount('u1').first, 0);
    await inbox.set({'unreadCount': 4});
    expect(await repo.watchUnreadCount('u1').first, 4);
  });

  test('the unread count is not read from the public user doc', () async {
    await db.collection('users').doc('u1').set({'unreadCount': 9});
    expect(await repo.watchUnreadCount('u1').first, 0);
  });

  test('latest returns the newest row or null', () async {
    expect(await repo.latest('u1'), isNull);
    await rows().doc('old').set(row(30, title: 'Cũ'));
    await rows().doc('new').set(row(1, title: 'Mới'));
    expect((await repo.latest('u1'))!.title, 'Mới');
  });

  test('targetExists is false for a missing booking', () async {
    expect(await repo.targetExists('/b/b1'), isFalse);
    await db.collection('bookings').doc('b1').set({'status': 'upcoming'});
    expect(await repo.targetExists('/b/b1'), isTrue);
    expect(await repo.targetExists('/b/b1?paid=1'), isTrue);
    expect(await repo.targetExists('/b/b2'), isFalse);

    expect(await repo.targetExists('/chat/c1'), isFalse);
    await db.collection('chats').doc('c1').set({
      'members': ['u1'],
    });
    expect(await repo.targetExists('/chat/c1'), isTrue);

    expect(await repo.targetExists('/me/awards'), isTrue);
    expect(await repo.targetExists('/u/x/badges'), isTrue);
    expect(await repo.targetExists('/bookings'), isTrue);
  });

  test('markAllRead calls the callable', () async {
    final functions = _MockFunctions();
    final callable = _MockCallable();
    registerFallbackValue(HttpsCallableOptions());
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    when(() => callable.call<Object?>(any()))
        .thenAnswer((_) async => _Result());
    await FirestoreNotificationRepository(
      db: db,
      functions: functions,
    ).markAllRead();
    verify(
      () => functions.httpsCallable(
        'markAllNotificationsRead',
        options: any(named: 'options'),
      ),
    ).called(1);
  });
}

class _Result extends Mock implements HttpsCallableResult<Object?> {}
