import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/chat/firestore_chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

/// Counts reads of `chats/{id}/members/{uid}` documents: one-off `get`s,
/// listeners started, and listeners still open. Everything else goes to the
/// wrapped [FakeFirebaseFirestore].
class _CountingFirestore implements FirebaseFirestore {
  _CountingFirestore(this.inner);

  final FakeFirebaseFirestore inner;
  int memberGets = 0;
  int memberListens = 0;
  final Map<String, int> openMemberListeners = {};

  /// Open listeners on chats queries (where/orderBy/limit → snapshots).
  int openQueryListeners = 0;

  /// Chat ids whose member doc stream fails instead of emitting.
  final Set<String> failingMembers = {};

  int get openListeners => openMemberListeners.values.fold(0, (a, b) => a + b);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Col(inner.collection(path), this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Col implements CollectionReference<Map<String, dynamic>> {
  _Col(this.inner, this.counter);

  final CollectionReference<Map<String, dynamic>> inner;
  final _CountingFirestore counter;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc(inner.doc(path), counter);

  @override
  dynamic noSuchMethod(Invocation i) => _Query(inner, counter).noSuchMethod(i);
}

/// Wraps `snapshots()` so a test can tell whether a listener is still open.
Stream<T> _tracked<T>(
  Stream<T> upstream, {
  required void Function() onListen,
  required void Function() onCancel,
}) {
  StreamSubscription<T>? sub;
  late final StreamController<T> c;
  c = StreamController<T>(
    onListen: () {
      onListen();
      sub = upstream.listen(c.add, onError: c.addError, onDone: c.close);
    },
    onCancel: () {
      onCancel();
      return sub?.cancel();
    },
  );
  return c.stream;
}

// ignore: subtype_of_sealed_class
class _Query implements Query<Map<String, dynamic>> {
  _Query(this.inner, this.counter);

  final Query<Map<String, dynamic>> inner;
  final _CountingFirestore counter;

  @override
  dynamic noSuchMethod(Invocation i) {
    Object? call(Function f) =>
        Function.apply(f, i.positionalArguments, i.namedArguments);
    return switch (i.memberName) {
      #where => _Query(
        call(inner.where)! as Query<Map<String, dynamic>>,
        counter,
      ),
      #orderBy => _Query(
        call(inner.orderBy)! as Query<Map<String, dynamic>>,
        counter,
      ),
      #limit => _Query(
        call(inner.limit)! as Query<Map<String, dynamic>>,
        counter,
      ),
      #snapshots => _tracked(
        call(inner.snapshots)! as Stream<QuerySnapshot<Map<String, dynamic>>>,
        onListen: () => counter.openQueryListeners++,
        onCancel: () => counter.openQueryListeners--,
      ),
      #get => call(inner.get),
      _ => throw UnimplementedError('${i.memberName}'),
    };
  }
}

// ignore: subtype_of_sealed_class
class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.inner, this.counter);

  final DocumentReference<Map<String, dynamic>> inner;
  final _CountingFirestore counter;

  bool get _isMember => inner.parent.id == 'members';

  @override
  String get id => inner.id;

  @override
  String get path => inner.path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Col(inner.collection(path), counter);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) {
    if (_isMember) counter.memberGets++;
    return inner.get(options);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    if (!_isMember) {
      return inner.snapshots(includeMetadataChanges: includeMetadataChanges);
    }
    final chatId = inner.parent.parent!.id;
    final upstream = counter.failingMembers.contains(chatId)
        ? Stream<DocumentSnapshot<Map<String, dynamic>>>.error(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          )
        : inner.snapshots(includeMetadataChanges: includeMetadataChanges);
    return _tracked(
      upstream,
      onListen: () {
        counter.memberListens++;
        counter.openMemberListeners.update(
          chatId,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      },
      onCancel: () => counter.openMemberListeners.update(chatId, (n) => n - 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => Function.apply(
    switch (i.memberName) {
      #update => inner.update,
      #set => inner.set,
      _ => throw UnimplementedError('${i.memberName}'),
    },
    i.positionalArguments,
    i.namedArguments,
  );
}

/// An uploader whose upload fails with [error].
class _FailingUploader extends FakeMediaUploader {
  _FailingUploader(this.error);

  final Object error;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  }) async* {
    yield const UploadEvent.progress(0.1);
    throw error;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late _CountingFirestore counting;
  late FakeMediaUploader uploader;
  late _MockFunctions functions;
  late _MockCallable callable;

  final t0 = DateTime.utc(2026, 10, 5, 9);

  setUp(() {
    db = FakeFirebaseFirestore();
    counting = _CountingFirestore(db);
    uploader = FakeMediaUploader();
    functions = _MockFunctions();
    callable = _MockCallable();
    final result = _MockResult();
    when(() => result.data).thenReturn(<String, dynamic>{'id': 'm1'});
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
  });

  FirestoreChatRepository repo({MediaUploader? mediaUploader}) =>
      FirestoreChatRepository(
        firestore: counting,
        functions: functions,
        currentUid: () => 'u1',
        mediaUploader: mediaUploader ?? uploader,
      );

  Future<void> seedChat(
    String id, {
    String kind = 'inquiry',
    DateTime? lastMessageAt,
    int? unread,
    List<String> members = const ['u1', 'p1'],
  }) async {
    await db.doc('chats/$id').set({
      'kind': kind,
      'members': members,
      'customerId': 'u1',
      'photographerId': 'p1',
      'lastMessageAt': lastMessageAt == null
          ? null
          : Timestamp.fromDate(lastMessageAt),
    });
    if (unread != null) {
      await db.doc('chats/$id/members/u1').set({'unreadCount': unread});
    }
  }

  Map<String, int> unreadOf(List<ChatListItem> items) => {
    for (final i in items) i.thread.id: i.unreadCount,
  };

  group('watchMyChats', () {
    test('lists 1-1 chats newest first with unread from member docs', () async {
      await seedChat('a', lastMessageAt: t0, unread: 2);
      await seedChat(
        'b',
        kind: 'booking',
        lastMessageAt: t0.add(const Duration(hours: 1)),
        unread: 0,
      );
      await seedChat('c', lastMessageAt: t0.subtract(const Duration(hours: 1)));
      await seedChat(
        'other',
        lastMessageAt: t0,
        unread: 5,
        members: const ['u2', 'p1'],
      );

      final items = await repo().watchMyChats().first;

      expect(items.map((i) => i.thread.id), ['b', 'a', 'c']);
      expect(unreadOf(items), {'b': 0, 'a': 2, 'c': 0});
    });

    test('markRead updates unread without a chat change', () async {
      await seedChat('a', lastMessageAt: t0, unread: 2);
      final r = repo();
      final emissions = <List<ChatListItem>>[];
      final sub = r.watchMyChats().listen(emissions.add);
      await pumpEventQueue();
      expect(unreadOf(emissions.last), {'a': 2});

      await r.markRead('a');
      await pumpEventQueue();

      expect(unreadOf(emissions.last), {'a': 0});
      expect(
        (await db.doc('chats/a/members/u1').get()).data()!['lastReadAt'],
        isNotNull,
      );
      await sub.cancel();
    });

    test(
      'one listener per member doc, none re-read on a new message',
      () async {
        await seedChat('a', lastMessageAt: t0, unread: 1);
        await seedChat(
          'b',
          lastMessageAt: t0.add(const Duration(minutes: 1)),
          unread: 0,
        );
        final emissions = <List<ChatListItem>>[];
        final sub = repo().watchMyChats().listen(emissions.add);
        await pumpEventQueue();
        expect(counting.memberListens, 2);

        // A new message: the server bumps the chat doc and the member doc.
        await db.doc('chats/a').update({
          'lastMessageAt': Timestamp.fromDate(t0.add(const Duration(hours: 2))),
          'lastMessagePreview': 'Chào',
        });
        await db.doc('chats/a/members/u1').update({'unreadCount': 2});
        await pumpEventQueue();

        expect(emissions.last.map((i) => i.thread.id), ['a', 'b']);
        expect(unreadOf(emissions.last), {'a': 2, 'b': 0});
        expect(counting.memberListens, 2);
        expect(counting.memberGets, 0);
        await sub.cancel();
      },
    );

    test('a chat leaving the page cancels its member listener', () async {
      await seedChat('a', lastMessageAt: t0, unread: 1);
      await seedChat(
        'b',
        lastMessageAt: t0.add(const Duration(minutes: 1)),
        unread: 0,
      );
      final emissions = <List<ChatListItem>>[];
      final sub = repo().watchMyChats(limit: 1).listen(emissions.add);
      await pumpEventQueue();
      expect(emissions.last.map((i) => i.thread.id), ['b']);
      expect(counting.openMemberListeners, {'b': 1});

      // 'a' gets a newer message and pushes 'b' off the one-row page.
      await db.doc('chats/a').update({
        'lastMessageAt': Timestamp.fromDate(t0.add(const Duration(hours: 1))),
      });
      await pumpEventQueue();

      expect(emissions.last.map((i) => i.thread.id), ['a']);
      expect(unreadOf(emissions.last), {'a': 1});
      expect(counting.openMemberListeners, {'a': 1, 'b': 0});
      await sub.cancel();
    });

    test('chats without lastMessageAt are hidden', () async {
      await seedChat('a', lastMessageAt: t0, unread: 0);
      await seedChat('empty', unread: 0);

      final items = await repo().watchMyChats().first;

      expect(items.map((i) => i.thread.id), ['a']);
      expect(counting.openMemberListeners.containsKey('empty'), isFalse);
    });

    test('event group chats are not listed', () async {
      await seedChat('a', lastMessageAt: t0, unread: 0);
      await seedChat(
        'event_ev1',
        kind: 'event_group',
        lastMessageAt: t0.add(const Duration(hours: 1)),
        unread: 4,
      );

      final items = await repo().watchMyChats().first;

      expect(items.map((i) => i.thread.id), ['a']);
    });

    test('cancelling the stream cancels every listener', () async {
      await seedChat('a', lastMessageAt: t0, unread: 1);
      await seedChat('b', lastMessageAt: t0, unread: 1);
      final sub = repo().watchMyChats().listen((_) {});
      await pumpEventQueue();
      expect(counting.openListeners, 2);
      expect(counting.openQueryListeners, 1);

      await sub.cancel();

      expect(counting.openListeners, 0);
      expect(counting.openQueryListeners, 0);
    });

    test(
      'a member doc that fails still lets the list emit with unread 0',
      () async {
        await seedChat('a', lastMessageAt: t0, unread: 3);
        await seedChat(
          'b',
          lastMessageAt: t0.add(const Duration(minutes: 1)),
          unread: 2,
        );
        counting.failingMembers.add('a');

        final items = await repo().watchMyChats().first;

        expect(items.map((i) => i.thread.id), ['b', 'a']);
        expect(unreadOf(items), {'b': 2, 'a': 0});
      },
    );

    test('no signed-in user lists nothing', () async {
      await seedChat('a', lastMessageAt: t0, unread: 1);
      final r = FirestoreChatRepository(
        firestore: counting,
        functions: functions,
        currentUid: () => null,
        mediaUploader: uploader,
      );
      expect(await r.watchMyChats().first, isEmpty);
    });
  });

  group('images', () {
    const image = PickedImage(path: '/tmp/a.heic', name: 'a.heic');

    test('uploadChatImage stores chats/{chatId}/{uid}/{clientId}.jpg and returns the path', () async {
      final path = await repo().uploadChatImage('chat1', image, clientId: 'c1');

      expect(path, 'chats/chat1/u1/c1.jpg');
      expect(uploader.uploaded, ['chats/chat1/u1/c1.jpg']);
      expect(uploader.purposes, {'chats/chat1/u1/c1.jpg': ImagePurpose.chat});
      verifyNever(() => callable.call<dynamic>(any()));
    });

    test(
      'sendImagePath calls sendMessage with type image and the path',
      () async {
        await repo().sendImagePath(
          'chat1',
          'chats/chat1/u1/c1.jpg',
          clientId: 'c1',
        );

        verify(() => functions.httpsCallable('sendMessage')).called(1);
        final sent =
            verify(() => callable.call<dynamic>(captureAny())).captured.single
                as Map;
        expect(sent, {
          'chatId': 'chat1',
          'message': {
            'type': 'image',
            'imagePath': 'chats/chat1/u1/c1.jpg',
            'clientId': 'c1',
          },
        });
        expect(uploader.uploadCalls, 0);
      },
    );

    test(
      'a refused sendImagePath is a ChatException with the mapped code',
      () async {
        when(() => callable.call<dynamic>(any())).thenThrow(
          FirebaseFunctionsException(
            message: 'x',
            code: 'failed-precondition',
            details: {'code': 'not_eligible'},
          ),
        );
        await expectLater(
          repo().sendImagePath(
            'chat1',
            'chats/chat1/u1/c1.jpg',
            clientId: 'c1',
          ),
          throwsA(
            isA<ChatException>().having(
              (e) => e.code,
              'code',
              ChatErrorCode.notEligible,
            ),
          ),
        );
      },
    );

    test(
      'an upload failure is a ChatException network/permissionDenied',
      () async {
        Future<ChatErrorCode> codeOf(Object error) async {
          try {
            await repo(mediaUploader: _FailingUploader(error))
                .uploadChatImage('chat1', image, clientId: 'c1');
          } on ChatException catch (e) {
            return e.code;
          }
          fail('no ChatException for $error');
        }

        expect(
          await codeOf(
            FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
          ),
          ChatErrorCode.permissionDenied,
        );
        expect(
          await codeOf(
            FirebaseException(
              plugin: 'firebase_storage',
              code: 'retry-limit-exceeded',
            ),
          ),
          ChatErrorCode.network,
        );
        expect(await codeOf(StateError('boom')), ChatErrorCode.unknown);
        verifyNever(() => callable.call<dynamic>(any()));
      },
    );

    test('uploading without a signed-in user is permissionDenied', () async {
      final r = FirestoreChatRepository(
        firestore: counting,
        functions: functions,
        currentUid: () => null,
        mediaUploader: uploader,
      );
      await expectLater(
        r.uploadChatImage('chat1', image, clientId: 'c1'),
        throwsA(
          isA<ChatException>().having(
            (e) => e.code,
            'code',
            ChatErrorCode.permissionDenied,
          ),
        ),
      );
      expect(uploader.uploadCalls, 0);
    });
  });
}
