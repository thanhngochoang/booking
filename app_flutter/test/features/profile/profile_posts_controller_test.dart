import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/profile/profile_posts_controller.dart';

import '../../support/content_fixtures.dart';

/// [n] posts by [uid] of [kind], newest first by id order (`<prefix>0` is
/// the newest).
List<PostSummary> _posts(
  String uid,
  int n, {
  String prefix = 'm',
  PostKind kind = PostKind.work,
  int minutesOffset = 0,
}) => [
  for (var i = 0; i < n; i++)
    fixturePost(
      '$prefix$i',
      kind: kind,
      photographerId: kind == PostKind.work ? uid : 'p9',
      authorId: uid,
      age: Duration(minutes: minutesOffset + i + 1),
    ),
];

Future<(ProviderContainer, FakePostRepository, String)> _open(
  List<PostSummary> Function(String uid) seed,
) async {
  final auth = FakeAuthRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Lan Anh');
  final repo = FakePostRepository(seed(u.uid));
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      postRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return (c, repo, u.uid);
}

void main() {
  test('first build loads one page of 20 for the filter', () async {
    final (c, repo, _) = await _open(
      (uid) => [
        ..._posts(uid, 25),
        ..._posts(uid, 3, prefix: 'e', kind: PostKind.eventShare),
        fixturePost('other', authorId: 'someone-else'),
      ],
    );
    c.listen(profilePostsProvider(null), (_, _) {});
    final all = await c.read(profilePostsProvider(null).future);
    expect(all.posts, hasLength(20));
    expect(all.posts.first.id, 'm0');
    expect(all.nextCursor, isNotNull);
    expect(all.loadingMore, isFalse);
    expect(all.moreError, isFalse);

    c.listen(profilePostsProvider(PostKind.eventShare), (_, _) {});
    final events = await c.read(
      profilePostsProvider(PostKind.eventShare).future,
    );
    expect(events.posts.map((p) => p.id), ['e0', 'e1', 'e2']);
    expect(events.nextCursor, isNull);
    expect(repo.byAuthorCursors, [null, null]);
  });

  test(
    'loadMore appends the next page and clears the cursor at the end',
    () async {
      final (c, _, _) = await _open((uid) => _posts(uid, 25));
      c.listen(profilePostsProvider(null), (_, _) {});
      await c.read(profilePostsProvider(null).future);
      await c.read(profilePostsProvider(null).notifier).loadMore();
      final s = c.read(profilePostsProvider(null)).requireValue;
      expect(s.posts.map((p) => p.id), [for (var i = 0; i < 25; i++) 'm$i']);
      expect(s.nextCursor, isNull);
      expect(s.loadingMore, isFalse);
    },
  );

  test('load more runs once per page', () async {
    final (c, repo, _) = await _open((uid) => _posts(uid, 45));
    c.listen(profilePostsProvider(null), (_, _) {});
    await c.read(profilePostsProvider(null).future);
    final gate = Completer<void>();
    repo.holdByAuthor = gate.future;
    final notifier = c.read(profilePostsProvider(null).notifier);
    final first = notifier.loadMore();
    final second = notifier.loadMore();
    expect(c.read(profilePostsProvider(null)).requireValue.loadingMore, isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(repo.byAuthorCursors, [null, 'm19']);
    expect(
      c.read(profilePostsProvider(null)).requireValue.posts,
      hasLength(40),
    );
  });

  test('a failed next page keeps the posts and sets moreError', () async {
    final (c, repo, _) = await _open((uid) => _posts(uid, 25));
    c.listen(profilePostsProvider(null), (_, _) {});
    await c.read(profilePostsProvider(null).future);
    repo.failByAuthorNextPagesWith = Exception('offline');
    await c.read(profilePostsProvider(null).notifier).loadMore();
    var s = c.read(profilePostsProvider(null)).requireValue;
    expect(s.posts, hasLength(20));
    expect(s.moreError, isTrue);
    expect(s.loadingMore, isFalse);
    expect(s.nextCursor, 'm19', reason: 'the failed page can be asked again');

    repo.failByAuthorNextPagesWith = null;
    await c.read(profilePostsProvider(null).notifier).loadMore();
    s = c.read(profilePostsProvider(null)).requireValue;
    expect(s.posts, hasLength(25));
    expect(s.moreError, isFalse);
  });

  test('refresh reloads from the first page', () async {
    final (c, repo, uid) = await _open((uid) => _posts(uid, 25));
    c.listen(profilePostsProvider(null), (_, _) {});
    await c.read(profilePostsProvider(null).future);
    await c.read(profilePostsProvider(null).notifier).loadMore();
    expect(
      c.read(profilePostsProvider(null)).requireValue.posts,
      hasLength(25),
    );

    repo.add(
      fixturePost('fresh', authorId: uid, age: const Duration(seconds: 1)),
    );
    expect(await c.read(profilePostsProvider(null).notifier).refresh(), isTrue);
    final s = c.read(profilePostsProvider(null)).requireValue;
    expect(s.posts, hasLength(20));
    expect(s.posts.first.id, 'fresh');
    expect(s.nextCursor, isNotNull);
    expect(repo.byAuthorCursors.last, isNull);
  });

  test('a failed refresh keeps the posts shown and reports false', () async {
    final (c, repo, _) = await _open((uid) => _posts(uid, 5));
    c.listen(profilePostsProvider(null), (_, _) {});
    await c.read(profilePostsProvider(null).future);
    repo.failWith = Exception('offline');
    expect(
      await c.read(profilePostsProvider(null).notifier).refresh(),
      isFalse,
    );
    final s = c.read(profilePostsProvider(null));
    expect(s.hasError, isFalse);
    expect(s.requireValue.posts, hasLength(5));
  });

  test('a failed refresh during a next page stops its spinner and offers '
      'the retry row', () async {
    final (c, repo, _) = await _open((uid) => _posts(uid, 25));
    c.listen(profilePostsProvider(null), (_, _) {});
    await c.read(profilePostsProvider(null).future);
    final gate = Completer<void>();
    repo.holdByAuthor = gate.future;
    final notifier = c.read(profilePostsProvider(null).notifier);
    final more = notifier.loadMore();
    expect(c.read(profilePostsProvider(null)).requireValue.loadingMore, isTrue);
    repo.failWith = Exception('offline');
    final refreshed = notifier.refresh();
    gate.complete();
    expect(await refreshed, isFalse);
    await more;
    var s = c.read(profilePostsProvider(null)).requireValue;
    expect(s.posts, hasLength(20));
    expect(s.loadingMore, isFalse);
    expect(s.moreError, isTrue);
    expect(s.nextCursor, 'm19');

    repo
      ..holdByAuthor = null
      ..failWith = null;
    await notifier.loadMore();
    s = c.read(profilePostsProvider(null)).requireValue;
    expect(s.posts, hasLength(25));
    expect(s.moreError, isFalse);
  });

  test('a failed retry with nothing shown stays an error', () async {
    final (c, repo, _) = await _open((uid) => _posts(uid, 5));
    repo.failWith = Exception('offline');
    c.listen(profilePostsProvider(null), (_, _) {});
    await expectLater(
      c.read(profilePostsProvider(null).future),
      throwsA(isA<Exception>()),
    );
    expect(
      await c.read(profilePostsProvider(null).notifier).refresh(),
      isFalse,
    );
    expect(c.read(profilePostsProvider(null)).hasError, isTrue);
    repo.failWith = null;
    expect(await c.read(profilePostsProvider(null).notifier).refresh(), isTrue);
    expect(c.read(profilePostsProvider(null)).requireValue.posts, hasLength(5));
  });

  test('counts run per kind with the total', () async {
    final (c, _, _) = await _open(
      (uid) => [
        ..._posts(uid, 3),
        ..._posts(uid, 1, prefix: 'r', kind: PostKind.realShoot),
        ..._posts(uid, 2, prefix: 'e', kind: PostKind.eventShare),
      ],
    );
    c.listen(profilePostCountsProvider, (_, _) {});
    final counts = await c.read(profilePostCountsProvider.future);
    expect(counts.total, 6);
    expect(counts.byKind, {
      PostKind.work: 3,
      PostKind.realShoot: 1,
      PostKind.eventShare: 2,
    });
  });

  test('a new post of the user reloads the grid and the counts', () async {
    final (c, repo, uid) = await _open((uid) => _posts(uid, 3));
    c.listen(profilePostsProvider(null), (_, _) {});
    c.listen(profilePostCountsProvider, (_, _) {});
    expect(
      (await c.read(profilePostsProvider(null).future)).posts,
      hasLength(3),
    );
    expect((await c.read(profilePostCountsProvider.future)).total, 3);
    expect(repo.byAuthorCursors, [null]);

    // What a publish does: the post exists, then the signal is bumped.
    repo.add(
      fixturePost(
        'fresh',
        kind: PostKind.eventShare,
        photographerId: 'p9',
        authorId: uid,
        age: const Duration(seconds: 1),
      ),
    );
    c.read(ownPostsChangedProvider.notifier).bump();

    final grid = await c.read(profilePostsProvider(null).future);
    expect(grid.posts.first.id, 'fresh');
    expect(grid.posts, hasLength(4));
    expect(repo.byAuthorCursors, [null, null], reason: 'first page again');
    final counts = await c.read(profilePostCountsProvider.future);
    expect(counts.total, 4);
    expect(counts.of(PostKind.eventShare), 1);
  });
}
