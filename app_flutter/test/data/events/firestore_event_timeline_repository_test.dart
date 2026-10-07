// test/data/events/firestore_event_timeline_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/events/firestore_event_timeline_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

final _t0 = DateTime.utc(2026, 10, 10, 3);

Map<String, dynamic> row(
  String id, {
  String status = 'visible',
  int minutesAgo = 0,
  String author = 'u1',
  String name = 'Lan Anh',
  bool host = false,
  int? w = 800,
  int? h = 1000,
}) => {
  'postId': id,
  'source': 'hashtag',
  'status': status,
  'authorId': author,
  'authorName': name,
  'isHost': host,
  'imageUrl': 'https://img.test/$id.jpg',
  'imageW': w,
  'imageH': h,
  'imageCount': 2,
  'addedAt': Timestamp.fromDate(_t0.subtract(Duration(minutes: minutesAgo))),
  'moderatedBy': null,
};

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FakeMediaUploader uploader;
  late FirestoreEventTimelineRepository repo;

  Future<void> seed(String eventId, String id, Map<String, dynamic> doc) =>
      db.doc('events/$eventId/timeline/$id').set(doc);

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    uploader = FakeMediaUploader();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreEventTimelineRepository(
      uid: 'u1',
      uploader: uploader,
      db: db,
      functions: functions,
    );
  });

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  group('page', () {
    test('timeline page asks visible rows newest first', () async {
      await seed('ev1', 'old', row('old', minutesAgo: 30));
      await seed('ev1', 'new', row('new', minutesAgo: 1, host: true));
      await seed('ev1', 'mid', row('mid', minutesAgo: 10));
      await seed('ev1', 'wait', row('wait', status: 'pending'));
      await seed('ev1', 'gone', row('gone', status: 'hidden'));
      await seed('ev2', 'other', row('other'));
      final page = await repo.page('ev1');
      expect(page.items.map((i) => i.postId), ['new', 'mid', 'old']);
      expect(page.cursor, isNull);
      final first = page.items.first;
      expect(first.isHost, isTrue);
      expect(first.authorName, 'Lan Anh');
      expect(first.imageUrl, 'https://img.test/new.jpg');
      expect((first.imageW, first.imageH, first.imageCount), (800, 1000, 2));
      expect(first.status, TimelineStatus.visible);
      expect(first.addedAt, _t0.subtract(const Duration(minutes: 1)));
    });

    test('managers can page pending rows', () async {
      await seed('ev1', 'a', row('a', status: 'pending', minutesAgo: 5));
      await seed('ev1', 'b', row('b', status: 'pending', minutesAgo: 2));
      await seed('ev1', 'c', row('c'));
      final page = await repo.page('ev1', status: TimelineStatus.pending);
      expect(page.items.map((i) => i.postId), ['b', 'a']);
      expect(
        page.items.every((i) => i.status == TimelineStatus.pending),
        isTrue,
      );
    });

    test('pages of 20 with a cursor, no row twice', () async {
      for (var i = 0; i < 25; i++) {
        await seed(
          'ev1',
          'p${i.toString().padLeft(2, '0')}',
          row('p$i', minutesAgo: i),
        );
      }
      final p1 = await repo.page('ev1', limit: 20);
      expect(p1.items, hasLength(20));
      expect(p1.cursor, p1.items.last.postId);
      final p2 = await repo.page('ev1', limit: 20, cursor: p1.cursor);
      expect(p2.items, hasLength(5));
      expect(p2.cursor, isNull);
      final ids = [...p1.items, ...p2.items].map((i) => i.postId).toSet();
      expect(ids, hasLength(25));
    });

    test('an unknown cursor or a bad id gives an empty page', () async {
      await seed('ev1', 'a', row('a'));
      expect((await repo.page('ev1', cursor: 'nope')).items, isEmpty);
      expect((await repo.page('ev1', cursor: 'a/b')).items, isEmpty);
      expect((await repo.page('a/b')).items, isEmpty);
    });

    test('a row without an image or a time is skipped', () {
      expect(timelineItemFromFirestore('x', {'authorId': 'u1'}), isNull);
      final item = timelineItemFromFirestore('x', row('x', w: null, h: null))!;
      expect(item.aspect, 4 / 3);
    });
  });

  test('pending count follows the pending rows', () async {
    await seed('ev1', 'a', row('a', status: 'pending'));
    await seed('ev1', 'b', row('b'));
    expect(await repo.watchPendingCount('ev1').first, 1);
    await seed('ev1', 'c', row('c', status: 'pending'));
    expect(await repo.watchPendingCount('ev1').first, 2);
  });

  group('share', () {
    final photo = const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg');

    test('uploads under posts/uid/postId and calls shareEventPost', () async {
      answer({'postId': 'whatever'});
      final id = await repo.share(
        'ev1',
        images: [photo, photo],
        caption: '#Tag Đẹp',
      );
      expect(uploader.uploaded, hasLength(2));
      for (final path in uploader.uploaded) {
        expect(path, startsWith('posts/u1/$id/'));
      }
      final sent =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map<String, Object?>;
      expect(sent['eventId'], 'ev1');
      expect(sent['postId'], id);
      expect(sent['caption'], '#Tag Đẹp');
      final images = sent['images'] as List;
      expect(images, hasLength(2));
      expect((images.first as Map)['path'], uploader.uploaded.first);
      expect(
        (images.first as Map)['url'],
        'https://storage.test/${uploader.uploaded.first}',
      );
      verify(
        () => functions.httpsCallable(
          'shareEventPost',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('a refused share deletes what it uploaded', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'x',
          code: 'failed-precondition',
          details: {'code': 'not_eligible'},
        ),
      );
      await expectLater(
        repo.share('ev1', images: [photo], caption: ''),
        throwsA(
          isA<EventError>().having((e) => e.code, 'code', 'not_eligible'),
        ),
      );
      expect(uploader.uploaded, isEmpty);
      expect(uploader.deleted, hasLength(1));
    });

    test('a lost answer keeps the files (the post may have landed)', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(message: 'x', code: 'unavailable'),
      );
      await expectLater(
        repo.share('ev1', images: [photo], caption: ''),
        throwsA(isA<EventError>().having((e) => e.code, 'code', 'network')),
      );
      expect(uploader.deleted, isEmpty);
    });

    test(
      'an upload that fails cleans up the earlier ones and never calls',
      () async {
        uploader.failNames.add('bad.jpg');
        await expectLater(
          repo.share(
            'ev1',
            images: [
              photo,
              const PickedImage(path: '/tmp/b.jpg', name: 'bad.jpg'),
            ],
            caption: '',
          ),
          throwsA(anything),
        );
        expect(uploader.uploaded, isEmpty);
        verifyNever(() => callable.call<Object?>(any()));
      },
    );

    test('signed out is permission_denied', () async {
      final out = FirestoreEventTimelineRepository(
        uid: null,
        uploader: uploader,
        db: db,
        functions: functions,
      );
      await expectLater(
        out.share('ev1', images: [photo], caption: ''),
        throwsA(
          isA<EventError>().having((e) => e.code, 'code', 'permission_denied'),
        ),
      );
    });
  });

  test('moderate calls moderateEventTimeline with the action', () async {
    answer(<String, Object?>{});
    await repo.moderate('ev1', 'p1', TimelineAction.approve);
    final sent =
        verify(() => callable.call<Object?>(captureAny())).captured.single
            as Map<String, Object?>;
    expect(sent, {'eventId': 'ev1', 'postId': 'p1', 'action': 'approve'});
    verify(
      () => functions.httpsCallable(
        'moderateEventTimeline',
        options: any(named: 'options'),
      ),
    ).called(1);
  });

  test('a refused moderation is an EventError with the domain code', () async {
    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'x',
        code: 'permission-denied',
        details: {'code': 'permission_denied'},
      ),
    );
    await expectLater(
      repo.moderate('ev1', 'p1', TimelineAction.hide),
      throwsA(
        isA<EventError>().having((e) => e.code, 'code', 'permission_denied'),
      ),
    );
  });
}
