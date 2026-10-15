// test/data/events/firestore_event_chat_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/firestore_event_chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

class _Urls implements MediaUrlResolver {
  @override
  Future<String> downloadUrl(String storagePath) async =>
      'https://dl.test/$storagePath';
}

final _t0 = DateTime.utc(2026, 10, 10, 3);
Timestamp _ts(int minutesAgo) =>
    Timestamp.fromDate(_t0.subtract(Duration(minutes: minutesAgo)));

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FakeMediaUploader uploader;
  late FirestoreEventChatRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() async {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    uploader = FakeMediaUploader();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreEventChatRepository(
      uid: 'u1',
      uploader: uploader,
      db: db,
      functions: functions,
      urls: _Urls(),
    );
    await db.doc('chats/event_ev1').set({
      'kind': 'event_group',
      'eventId': 'ev1',
      'title': 'Photo walk phố cổ',
      'members': ['p1', 'u1', 'u2'],
      'moderators': ['p1'],
      'memberCount': 3,
      'moderatorsOnly': true,
      'readOnlyAt': Timestamp.fromDate(_t0.add(const Duration(days: 7))),
    });
  });

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  Map<String, Object?> lastCall() =>
      verify(() => callable.call<Object?>(captureAny())).captured.last
          as Map<String, Object?>;

  test(
    'the thread carries the title, count, moderators and close time',
    () async {
      final t = (await repo.watchChat('ev1').first)!;
      expect(t.id, 'event_ev1');
      expect(t.title, 'Photo walk phố cổ');
      expect(t.memberCount, 3);
      expect(t.moderators, ['p1']);
      expect(t.moderatorsOnly, isTrue);
      expect(t.readOnlyAt, _t0.add(const Duration(days: 7)));
      expect(t.isReadOnlyAt(_t0), isFalse);
      expect(t.isReadOnlyAt(_t0.add(const Duration(days: 7))), isTrue);
    },
  );

  test('a missing chat, a 1-1 chat or a bad id is null', () async {
    expect(await repo.watchChat('nope').first, isNull);
    await db.doc('chats/event_x').set({'kind': 'inquiry'});
    expect(await repo.watchChat('x').first, isNull);
    expect(await repo.watchChat('a/b').first, isNull);
  });

  test('my member doc gives the role, the mute and the removal', () async {
    expect(await repo.watchMe('ev1').first, isNull);
    await db.doc('chats/event_ev1/members/u1').set({
      'role': 'member',
      'name': 'Lan',
      'mutedUntil': Timestamp.fromDate(_t0.add(const Duration(hours: 1))),
      'removedAt': null,
    });
    final me = (await repo.watchMe('ev1').first)!;
    expect(me.role, GroupRole.member);
    expect(me.isMutedAt(_t0), isTrue);
    expect(me.isMutedAt(_t0.add(const Duration(hours: 2))), isFalse);
    expect(me.removed, isFalse);
    await db.doc('chats/event_ev1/members/u1').update({'removedAt': _ts(0)});
    expect((await repo.watchMe('ev1').first)!.removed, isTrue);
  });

  test(
    'the member list has names and avatars, moderators first, no removed',
    () async {
      await db.doc('chats/event_ev1/members/u2').set({
        'role': 'member',
        'name': 'Minh Khoa',
        'avatarUrl': null,
      });
      await db.doc('chats/event_ev1/members/u1').set({
        'role': 'member',
        'name': 'An',
        'avatarUrl': 'https://a.test/u1.jpg',
      });
      await db.doc('chats/event_ev1/members/p1').set({
        'role': 'moderator',
        'name': 'Quốc Bảo',
      });
      await db.doc('chats/event_ev1/members/u3').set({
        'role': 'member',
        'name': 'Đã gỡ',
        'removedAt': _ts(5),
      });
      await db.doc('chats/event_ev1/members/u4').set({'unreadCount': 0});
      await db.doc('chats/event_ev1/members/u5').set({
        'role': 'member',
        'name': 'Bị mời ra',
        'removedAt': _ts(3),
        'removedBy': 'p1',
      });
      final list = await repo.watchMembers('ev1').first;
      // u3 left by cancelling: not listed; u5 a moderator removed: flagged.
      expect(list.map((m) => m.name), [
        'Quốc Bảo',
        'An',
        'Bị mời ra',
        'Minh Khoa',
      ]);
      expect(list.first.role, GroupRole.moderator);
      expect(list[1].avatarUrl, 'https://a.test/u1.jpg');
      expect(
        [
          for (final m in list)
            if (m.removedByModerator) m.uid,
        ],
        ['u5'],
      );
    },
  );

  test('group messages parse the sender name', () async {
    await db.doc('chats/event_ev1/messages/m1').set({
      'senderId': 'u2',
      'senderName': 'Minh Khoa',
      'type': 'text',
      'body': 'Hẹn gặp ở cổng',
      'createdAt': _ts(2),
    });
    await db.doc('chats/event_ev1/messages/m0').set({
      'senderId': 'p1',
      'senderName': 'Quốc Bảo',
      'type': 'text',
      'body': 'Chào cả nhóm',
      'createdAt': _ts(9),
    });
    final msgs = await repo.watchMessages('ev1').first;
    expect(msgs.map((m) => m.id), ['m0', 'm1']);
    expect(msgs.last.senderName, 'Minh Khoa');
    final older = await repo.olderMessages(
      'ev1',
      before: _t0.subtract(const Duration(minutes: 5)),
    );
    expect(older.map((m) => m.id), ['m0']);
  });

  test('the newest pin is the pinned message', () async {
    expect(await repo.watchLatestPin('ev1').first, isNull);
    await db.doc('chats/event_ev1/pins/old').set({
      'body': 'Cũ',
      'senderName': 'An',
      'pinnedBy': 'p1',
      'pinnedAt': _ts(60),
    });
    await db.doc('chats/event_ev1/pins/new').set({
      'body': 'Điểm hẹn 06:00',
      'senderName': 'Quốc Bảo',
      'pinnedBy': 'p1',
      'pinnedAt': _ts(1),
    });
    final pin = (await repo.watchLatestPin('ev1').first)!;
    expect(
      (pin.messageId, pin.body, pin.senderName),
      ('new', 'Điểm hẹn 06:00', 'Quốc Bảo'),
    );
  });

  group('sending', () {
    test('sendText calls sendEventMessage with the client id', () async {
      answer({'id': 'c1'});
      await repo.sendText('ev1', 'Xin chào', clientId: 'c1');
      expect(lastCall(), {
        'eventId': 'ev1',
        'message': {'type': 'text', 'body': 'Xin chào', 'clientId': 'c1'},
      });
      verify(
        () => functions.httpsCallable(
          'sendEventMessage',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test(
      'sendImage uploads under chats/event_id/uid then sends the path',
      () async {
        answer({'id': 'c2'});
        await repo.sendImage(
          'ev1',
          const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'),
          clientId: 'c2',
        );
        expect(uploader.uploaded, ['chats/event_ev1/u1/c2.jpg']);
        expect(lastCall()['message'], {
          'type': 'image',
          'imagePath': 'chats/event_ev1/u1/c2.jpg',
          'clientId': 'c2',
        });
      },
    );

    test('event chat images use the chat purpose', () async {
      answer({'id': 'c2'});
      await repo.sendImage(
        'ev1',
        const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'),
        clientId: 'c2',
      );
      expect(uploader.purposes, {
        'chats/event_ev1/u1/c2.jpg': ImagePurpose.chat,
      });
    });

    test('sendLocation sends the point', () async {
      answer({'id': 'c3'});
      await repo.sendLocation('ev1', (
        lat: 21.0285,
        lng: 105.8542,
      ), clientId: 'c3');
      expect(lastCall()['message'], {
        'type': 'location',
        'point': {'lat': 21.0285, 'lng': 105.8542},
        'clientId': 'c3',
      });
    });

    for (final (domain, code) in [
      ('limit_exceeded', ChatErrorCode.limitExceeded),
      ('not_eligible', ChatErrorCode.notEligible),
      ('permission_denied', ChatErrorCode.permissionDenied),
    ]) {
      test('a refusal $domain is ChatException($code)', () async {
        when(() => callable.call<Object?>(any())).thenThrow(
          FirebaseFunctionsException(
            message: 'x',
            code: 'aborted',
            details: {'code': domain},
          ),
        );
        await expectLater(
          repo.sendText('ev1', 'hi', clientId: 'c9'),
          throwsA(isA<ChatException>().having((e) => e.code, 'code', code)),
        );
      });
    }

    test('an unreachable backend is a network ChatException', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(message: 'x', code: 'unavailable'),
      );
      await expectLater(
        repo.sendText('ev1', 'hi', clientId: 'c9'),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.network,
          ),
        ),
      );
    });
  });

  group('moderation', () {
    test('every action reaches moderateEventChat with its fields', () async {
      answer(<String, Object?>{});
      final cases = <(ChatModeration, Map<String, Object?>)>[
        (const PinMessage('m1'), {'action': 'pin', 'messageId': 'm1'}),
        (const UnpinMessage('m1'), {'action': 'unpin', 'messageId': 'm1'}),
        (const DeleteMessage('m1'), {'action': 'delete', 'messageId': 'm1'}),
        (
          const MuteMember('u2'),
          {'action': 'mute', 'userId': 'u2', 'minutes': 1440},
        ),
        (const UnmuteMember('u2'), {'action': 'unmute', 'userId': 'u2'}),
        (const RemoveMember('u2'), {'action': 'remove', 'userId': 'u2'}),
        (const RestoreMember('u2'), {'action': 'restore', 'userId': 'u2'}),
        (
          const SetModeratorsOnly(on: true),
          {'action': 'moderatorsOnly', 'on': true},
        ),
      ];
      for (final (action, fields) in cases) {
        await repo.moderate('ev1', action);
        expect(lastCall(), {'eventId': 'ev1', ...fields});
      }
    });

    test('announce calls postEventAnnouncement', () async {
      answer({'messageId': 'a1'});
      await repo.announce('ev1', 'Tập trung 7h45', clientId: 'c1');
      expect(lastCall(), {
        'eventId': 'ev1',
        'text': 'Tập trung 7h45',
        'clientId': 'c1',
      });
      verify(
        () => functions.httpsCallable(
          'postEventAnnouncement',
          options: any(named: 'options'),
        ),
      ).called(1);
    });
  });

  group('healingStream (M1)', () {
    FirebaseException refused() =>
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

    test('refused twice, then the value: fallback, fallback, value', () async {
      var listens = 0;
      Stream<int> make() {
        listens++;
        return listens <= 2 ? Stream<int>.error(refused()) : Stream.value(7);
      }

      final got = await healingStream<int>(
        make,
        0,
        attempts: 10,
        every: Duration.zero,
      ).toList();
      expect(got, [0, 0, 7]);
      expect(listens, 3);
    });

    test('stops after the attempts with the fallback', () async {
      var listens = 0;
      final got = await healingStream<int>(
        () {
          listens++;
          return Stream<int>.error(refused());
        },
        -1,
        attempts: 3,
        every: Duration.zero,
      ).toList();
      expect(got, [-1, -1, -1]);
      expect(listens, 3);
    });

    test('a cancel during the wait starts no new listen', () async {
      var listens = 0;
      final sub = healingStream<int>(
        () {
          listens++;
          return Stream<int>.error(refused());
        },
        0,
        attempts: 10,
        every: const Duration(milliseconds: 50),
      ).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(listens, 1);
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(listens, 1);
    });

    test('another error ends the stream with it', () async {
      final got = healingStream<int>(
        () => Stream<int>.error(StateError('boom')),
        0,
        attempts: 10,
        every: Duration.zero,
      );
      await expectLater(
        got,
        emitsInOrder([emitsError(isStateError), emitsDone]),
      );
    });
  });

  test('markRead zeroes my unread marker and never throws', () async {
    await db.doc('chats/event_ev1/members/u1').set({
      'role': 'member',
      'unreadCount': 4,
    });
    await repo.markRead('ev1');
    final d = (await db.doc('chats/event_ev1/members/u1').get()).data()!;
    expect(d['unreadCount'], 0);
    expect(d['lastReadAt'], isNotNull);
    await repo.markRead('nope'); // no member doc: ignored
  });

  test('imageUrl resolves a storage path', () async {
    expect(
      await repo.imageUrl('chats/event_ev1/u2/a.jpg'),
      'https://dl.test/chats/event_ev1/u2/a.jpg',
    );
  });
}
