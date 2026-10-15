import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/firestore_album_repository.dart';

import '../../support/content_fixtures.dart';
import 'firestore_post_seed.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> albumDoc(AlbumSummary a, {Map<String, Object?>? cover}) =>
    {
      'photographerId': a.photographerId,
      'title': a.title,
      'titleKey': a.title.toLowerCase(),
      'description': a.description,
      'cover': ?cover,
      'position': a.position,
      'postCount': a.postCount,
      'mediaCount': a.mediaCount,
      'visible': a.visible,
      'createdAt': Timestamp.fromDate(fixtureNow),
      'updatedAt': Timestamp.fromDate(fixtureNow),
    };

/// A database whose `posts` reads fail, like an offline or rules error.
class _PostsFailDb extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      path == 'posts'
      ? throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')
      : super.collection(path);
}

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreAlbumRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreAlbumRepository(db: db, functions: functions);
  });

  test('an album doc parses with counts and cover', () async {
    await seedPost(db, fixturePost('a', albumId: 'al1', albumPosition: 1));
    await seedPost(
      db,
      fixturePost('b', albumId: 'al1', albumPosition: 2, images: 3),
    );
    await db
        .collection('albums')
        .doc('al1')
        .set(
          albumDoc(
            fixtureAlbum(
              'al1',
              title: 'Cưới 2026',
              postCount: 2,
              mediaCount: 4,
            ),
            cover: {'postId': 'b', 'imageIndex': 2},
          ),
        );
    final a = (await repo.album('al1'))!;
    expect(a.title, 'Cưới 2026');
    expect((a.postCount, a.mediaCount, a.position), (2, 4, 1));
    expect(a.visible, isTrue);
    expect((a.coverPostId, a.coverImageIndex), ('b', 2));
    expect(a.coverUrl, 'https://img.test/b-2.jpg');
  });

  test("a missing cover resolves to the first post's first image", () async {
    await seedPost(db, fixturePost('a', albumId: 'al1', albumPosition: 2));
    await seedPost(db, fixturePost('b', albumId: 'al1', albumPosition: 1));
    await db
        .collection('albums')
        .doc('al1')
        .set(albumDoc(fixtureAlbum('al1', postCount: 2, mediaCount: 2)));
    final a = (await repo.album('al1'))!;
    expect(a.coverPostId, isNull);
    expect(a.coverUrl, 'https://img.test/b-0.jpg');
  });

  test('a failing cover read leaves coverUrl null', () async {
    final bad = _PostsFailDb();
    final badRepo = FirestoreAlbumRepository(db: bad, functions: functions);
    await bad
        .collection('albums')
        .doc('al1')
        .set(
          albumDoc(
            fixtureAlbum('al1', postCount: 2, mediaCount: 2),
            cover: {'postId': 'a', 'imageIndex': 0},
          ),
        );
    final a = (await badRepo.album('al1'))!;
    expect(a.title, 'Album');
    expect(a.coverUrl, isNull);
    final list = await badRepo.watchAlbums('p1', includeEmpty: true).first;
    expect(list.map((x) => x.id), ['al1']);
    expect(list.single.coverUrl, isNull);
  });

  test('two summaries with the same fields are equal', () {
    final a = fixtureAlbum('x', coverUrl: 'u');
    expect(a, fixtureAlbum('x', coverUrl: 'u'));
    expect(a.hashCode, fixtureAlbum('x', coverUrl: 'u').hashCode);
    expect(a == fixtureAlbum('x', coverUrl: 'v'), isFalse);
    expect(a == fixtureAlbum('x', title: 'Khác', coverUrl: 'u'), isFalse);
  });

  test('album returns null for a missing or malformed id', () async {
    expect(await repo.album('nope'), isNull);
    expect(await repo.album('a/b'), isNull);
  });

  test(
    'watchAlbums for visitors asks only visible albums ordered by position',
    () async {
      await db
          .collection('albums')
          .doc('x2')
          .set(albumDoc(fixtureAlbum('x2', title: 'Hai', position: 2)));
      await db
          .collection('albums')
          .doc('x1')
          .set(albumDoc(fixtureAlbum('x1', title: 'Một', position: 1)));
      await db
          .collection('albums')
          .doc('empty')
          .set(
            albumDoc(
              fixtureAlbum('empty', position: 3, postCount: 0, visible: false),
            ),
          );
      await db
          .collection('albums')
          .doc('other')
          .set(albumDoc(fixtureAlbum('other', photographerId: 'p2')));
      final visitors = await repo.watchAlbums('p1', includeEmpty: false).first;
      expect(visitors.map((a) => a.id), ['x1', 'x2']);
      final owner = await repo.watchAlbums('p1', includeEmpty: true).first;
      expect(owner.map((a) => a.id), ['x1', 'x2', 'empty']);
    },
  );

  group('callables', () {
    void failWith(String code) => when(() => callable.call<Object?>(any()))
        .thenThrow(
          FirebaseFunctionsException(
            message: 'x',
            code: 'already-exists',
            details: {'code': code},
          ),
        );

    test("a duplicate title becomes AlbumError('conflict')", () async {
      failWith('conflict');
      await expectLater(
        repo.create(title: 'Cưới'),
        throwsA(isA<AlbumError>().having((e) => e.code, 'code', 'conflict')),
      );
    });

    test('create sends title and description and returns the id', () async {
      final result = _MockResult();
      when(() => result.data).thenReturn({'albumId': 'new1'});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
      final id = await repo.create(title: 'Cưới', description: 'Mô tả');
      expect(id, 'new1');
      final options =
          verify(
                () => functions.httpsCallable(
                  'createAlbum',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as HttpsCallableOptions;
      expect(options.timeout, const Duration(seconds: 15));
      verify(
        () => callable.call<Object?>({'title': 'Cưới', 'description': 'Mô tả'}),
      ).called(1);
    });

    test('update maps auto cover to null and a pick to postId/index', () async {
      final result = _MockResult();
      when(() => result.data).thenReturn({});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
      await repo.update('al1', cover: const AlbumCoverAuto());
      await repo.update(
        'al1',
        title: 'Mới',
        cover: const AlbumCoverPick('p', 1),
      );
      verify(() => callable.call<Object?>({'albumId': 'al1', 'cover': null}))
          .called(1);
      verify(
        () => callable.call<Object?>({
          'albumId': 'al1',
          'title': 'Mới',
          'cover': {'postId': 'p', 'imageIndex': 1},
        }),
      ).called(1);
    });

    test('movePosts sends a null album to remove from albums', () async {
      final result = _MockResult();
      when(() => result.data).thenReturn({});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
      await repo.movePosts(null, ['a', 'b']);
      verify(
        () => callable.call<Object?>({
          'albumId': null,
          'postIds': ['a', 'b'],
        }),
      ).called(1);
    });
  });
}
