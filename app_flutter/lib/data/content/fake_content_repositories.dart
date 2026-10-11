// lib/data/content/fake_content_repositories.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/saved_follow.dart';
import 'package:photobooking/data/content/saved_follow_repository.dart';
import 'package:photobooking/data/content/service_summary.dart';

class FakePostRepository implements PostRepository {
  FakePostRepository([List<PostSummary> posts = const []])
    : _posts = List.of(posts);

  final List<PostSummary> _posts;

  /// When set, every call throws it.
  Object? failWith;

  /// The cursor of every [byPhotographer] call, in order (null = first page).
  final byPhotographerCursors = <String?>[];

  /// When set, [byPhotographer] waits for it (keeps a read in flight).
  Future<void>? holdByPhotographer;

  /// The cursor of every [byAuthor] call, in order (null = first page).
  final byAuthorCursors = <String?>[];

  /// When set, [byAuthor] waits for it (keeps a read in flight).
  Future<void>? holdByAuthor;

  /// When set, [byAuthor] calls for a next page (with a cursor) throw it.
  Object? failByAuthorNextPagesWith;

  void add(PostSummary post) => _posts.add(post);

  /// Removes a post if present; used when a draft id is published again.
  void removeById(String id) => _posts.removeWhere((p) => p.id == id);

  List<PostSummary> get _newestFirst {
    final list = List.of(_posts)
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return list;
  }

  PostPage _page(List<PostSummary> sorted, String? cursor, int limit) {
    final n = clampPageSize(limit);
    var start = 0;
    if (cursor != null) {
      if (cursor.isEmpty || cursor.contains('/')) {
        return const PostPage();
      }
      final i = sorted.indexWhere((p) => p.id == cursor);
      start = i < 0 ? sorted.length : i + 1;
    }
    final rest = sorted.skip(start).toList();
    final page = rest.take(n).toList();
    return PostPage(
      posts: page,
      nextCursor: rest.length > n ? page.last.id : null,
    );
  }

  @override
  Future<PostPage> feed({
    PostKind? kind,
    String? specialtyId,
    String? cursor,
    int limit = 20,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final filtered = _newestFirst
        .where(
          (p) => kind == null
              ? p.kind != PostKind.eventShare
              : p.kind == kind,
        )
        .where((p) => specialtyId == null || p.specialtyId == specialtyId)
        .toList();
    return _page(filtered, cursor, limit);
  }

  @override
  Future<PostPage> byPhotographer(
    String photographerId, {
    String? cursor,
    int limit = 20,
  }) async {
    byPhotographerCursors.add(cursor);
    await holdByPhotographer;
    if (failWith != null) {
      throw failWith!;
    }
    final filtered = _newestFirst
        .where((p) => p.photographerId == photographerId)
        .toList();
    return _page(filtered, cursor, limit);
  }

  @override
  Future<PostPage> byAuthor(
    String uid, {
    PostKind? kind,
    String? cursor,
    int limit = 20,
  }) async {
    byAuthorCursors.add(cursor);
    await holdByAuthor;
    if (failWith != null) {
      throw failWith!;
    }
    if (cursor != null && failByAuthorNextPagesWith != null) {
      throw failByAuthorNextPagesWith!;
    }
    if (uid.isEmpty || uid.contains('/')) {
      return const PostPage();
    }
    final filtered = _newestFirst
        .where((p) => p.authorId == uid && (kind == null || p.kind == kind))
        .toList();
    return _page(filtered, cursor, limit);
  }

  @override
  Future<int> countByAuthor(String uid, {PostKind? kind}) async {
    if (failWith != null) {
      throw failWith!;
    }
    if (uid.isEmpty || uid.contains('/')) {
      return 0;
    }
    return _posts
        .where((p) => p.authorId == uid && (kind == null || p.kind == kind))
        .length;
  }

  @override
  Future<PostPage> byAlbum(
    String albumId, {
    String? cursor,
    int limit = 24,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final sorted = _posts.where((p) => p.albumId == albumId).toList()
      ..sort((a, b) => (a.albumPosition ?? 0).compareTo(b.albumPosition ?? 0));
    return _page(sorted, cursor, limit);
  }

  @override
  Future<PostSummary?> byId(String postId) async {
    if (failWith != null) {
      throw failWith!;
    }
    if (postId.isEmpty || postId.contains('/')) {
      return null;
    }
    for (final p in _posts) {
      if (p.id == postId) {
        return p;
      }
    }
    return null;
  }

  @override
  Future<Map<String, PostSummary>> byIds(Iterable<String> ids) async {
    if (failWith != null) {
      throw failWith!;
    }
    final result = <String, PostSummary>{};
    for (final id in ids) {
      if (id.isEmpty || id.contains('/')) continue;
      for (final p in _posts) {
        if (p.id == id) {
          result[id] = p;
          break;
        }
      }
    }
    return result;
  }
}

class FakePostEngagementRepository implements PostEngagementRepository {
  final _liked = <(String, String)>{};
  final _saved = <(String, String)>{};
  final _following = <(String, String)>{};

  Object? failWith;

  /// Number of successful writes, for asserting optimistic behaviour.
  int writeCalls = 0;

  /// Number of reads (`engagementFor`, `savedAmong`, `isFollowing`), for
  /// asserting how much a screen reads.
  int readCalls = 0;

  (String, String) _k(String uid, String id) => (uid, id);

  void _check() {
    if (failWith != null) {
      throw failWith!;
    }
  }

  @override
  Future<PostEngagement> engagementFor(String uid, String postId) async {
    _check();
    readCalls++;
    return PostEngagement(
      liked: _liked.contains(_k(uid, postId)),
      saved: _saved.contains(_k(uid, postId)),
    );
  }

  @override
  Future<Set<String>> savedAmong(String uid, Iterable<String> postIds) async {
    _check();
    readCalls++;
    return {
      for (final id in postIds)
        if (_saved.contains(_k(uid, id))) id,
    };
  }

  @override
  Future<void> setLiked(String uid, String postId, bool liked) async {
    _check();
    writeCalls++;
    liked ? _liked.add(_k(uid, postId)) : _liked.remove(_k(uid, postId));
  }

  @override
  Future<void> setSaved(String uid, String postId, bool saved) async {
    _check();
    writeCalls++;
    saved ? _saved.add(_k(uid, postId)) : _saved.remove(_k(uid, postId));
  }

  @override
  Future<bool> isFollowing(String uid, String photographerId) async {
    _check();
    readCalls++;
    return _following.contains(_k(uid, photographerId));
  }

  @override
  Future<void> setFollowing(
    String uid,
    String photographerId,
    bool following,
  ) async {
    _check();
    writeCalls++;
    following
        ? _following.add(_k(uid, photographerId))
        : _following.remove(_k(uid, photographerId));
  }
}

class FakePhotographerRepository implements PhotographerRepository {
  FakePhotographerRepository([
    List<PhotographerSummary> photographers = const [],
  ]) : _all = List.of(photographers);

  final List<PhotographerSummary> _all;
  Object? failWith;

  void add(PhotographerSummary p) => _all.add(p);

  @override
  Future<Map<String, PhotographerSummary>> summaries(
    Iterable<String> ids,
  ) async {
    if (failWith != null) {
      throw failWith!;
    }
    final wanted = ids.toSet();
    return {
      for (final p in _all)
        if (wanted.contains(p.id)) p.id: p,
    };
  }

  @override
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final from = vnDateKey(now);
    final to = vnDateKey(now.add(const Duration(days: 7)));
    final list =
        _all.where((p) {
          final d = p.nextFreeDate;
          return d != null && d.compareTo(from) >= 0 && d.compareTo(to) < 0;
        }).toList()..sort((a, b) {
          final byDay = a.nextFreeDate!.compareTo(b.nextFreeDate!);
          if (byDay != 0) {
            return byDay;
          }
          final byScore = b.score.compareTo(a.score);
          return byScore != 0 ? byScore : a.id.compareTo(b.id);
        });
    return list.take(clampPageSize(limit)).toList();
  }

  @override
  Future<List<PhotographerSummary>> candidates({int limit = 200}) async {
    if (failWith != null) {
      throw failWith!;
    }
    return _all.take(clampPageSize(limit, 200)).toList();
  }
}

class FakeServiceRepository implements ServiceRepository {
  FakeServiceRepository([List<ServiceSummary> services = const []])
    : _all = List.of(services);

  final List<ServiceSummary> _all;
  Object? failWith;

  void add(ServiceSummary s) => _all.add(s);

  @override
  Future<ServiceSummary?> byId(String photographerId, String serviceId) async {
    if (failWith != null) {
      throw failWith!;
    }
    if (photographerId.isEmpty ||
        photographerId.contains('/') ||
        serviceId.isEmpty ||
        serviceId.contains('/')) {
      return null;
    }
    for (final s in _all) {
      if (s.photographerId == photographerId && s.id == serviceId) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<List<ServiceSummary>> activeFor(
    String photographerId, {
    int limit = 50,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    return _all
        .where((s) => s.photographerId == photographerId && s.active)
        .take(clampPageSize(limit))
        .toList();
  }
}

class FakeSavedFollowRepository implements SavedFollowRepository {
  FakeSavedFollowRepository({
    this.postRepo,
    this.photographerRepo,
    Map<String, ({String displayName, String? avatarUrl})>? userDirectory,
  }) : userDirectory = userDirectory != null
            ? Map.of(userDirectory)
            : <String, ({String displayName, String? avatarUrl})>{};

  PostRepository? postRepo;
  PhotographerRepository? photographerRepo;
  Map<String, ({String displayName, String? avatarUrl})> userDirectory;

  /// (userId, postId, createdAt, docId)
  final savedPostEntries = <({String userId, String postId, DateTime createdAt, String docId})>[];

  /// (userId, photographerId, createdAt, docId)
  final savedPhotographerEntries =
      <({String userId, String photographerId, DateTime createdAt, String docId})>[];

  /// (userId, photographerId, createdAt, docId)
  final followEntries =
      <({String userId, String photographerId, DateTime createdAt, String docId})>[];

  /// Overrides for follower count per photographerId
  final followerCounts = <String, int>{};

  Object? failWith;
  int writeCalls = 0;
  int readCalls = 0;

  void _check() {
    if (failWith != null) throw failWith!;
  }

  void addSavedPost(String uid, String postId, DateTime createdAt) {
    savedPostEntries.add((
      userId: uid,
      postId: postId,
      createdAt: createdAt,
      docId: '${uid}_$postId',
    ));
  }

  void addSavedPhotographer(String uid, String photographerId, DateTime createdAt) {
    savedPhotographerEntries.add((
      userId: uid,
      photographerId: photographerId,
      createdAt: createdAt,
      docId: '${uid}_$photographerId',
    ));
  }

  void addFollow(String uid, String photographerId, DateTime createdAt) {
    followEntries.add((
      userId: uid,
      photographerId: photographerId,
      createdAt: createdAt,
      docId: '${uid}_$photographerId',
    ));
  }

  @override
  Future<MarkerPage<PostSummary>> savedPosts(
    String uid, {
    String? cursor,
    int limit = 30,
  }) async {
    _check();
    readCalls++;
    final n = clampPageSize(limit);
    final userSaves = savedPostEntries.where((e) => e.userId == uid).toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.docId.compareTo(a.docId);
      });

    final parsedCursor = parseMarkerCursor(cursor);
    var startIdx = 0;
    if (parsedCursor != null) {
      final (cursorTime, cursorDocId) = parsedCursor;
      final idx = userSaves.indexWhere((e) =>
          e.createdAt == cursorTime && e.docId == cursorDocId);
      if (idx >= 0) {
        startIdx = idx + 1;
      } else {
        // Unknown or stale cursor
        return const MarkerPage(items: []);
      }
    }

    final remaining = userSaves.skip(startIdx).toList();
    final items = <PostSummary>[];
    String? nextCursor;
    var examined = 0;
    const maxExtraRounds = 3;
    var rounds = 0;

    for (var i = 0; i < remaining.length; i += n) {
      rounds++;
      final chunk = remaining.skip(i).take(n).toList();
      examined += chunk.length;
      final ids = chunk.map((c) => c.postId).toList();
      final fetched = postRepo != null ? await postRepo!.byIds(ids) : <String, PostSummary>{};
      final ordered = keepOrder(ids, fetched);
      items.addAll(ordered);

      if (items.length >= n || rounds > maxExtraRounds || chunk.length < n) {
        if (examined < remaining.length) {
          final lastMarker = chunk.last;
          nextCursor = markerCursor(lastMarker.createdAt, lastMarker.docId);
        }
        break;
      }
    }

    final pageItems = items.take(n).toList();
    return MarkerPage(items: pageItems, cursor: nextCursor);
  }

  @override
  Future<MarkerPage<PhotographerSummary>> savedPhotographers(
    String uid, {
    String? cursor,
    int limit = 20,
  }) async {
    _check();
    readCalls++;
    final n = clampPageSize(limit);
    final userSaves = savedPhotographerEntries.where((e) => e.userId == uid).toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.docId.compareTo(a.docId);
      });

    final parsedCursor = parseMarkerCursor(cursor);
    var startIdx = 0;
    if (parsedCursor != null) {
      final (cursorTime, cursorDocId) = parsedCursor;
      final idx = userSaves.indexWhere((e) =>
          e.createdAt == cursorTime && e.docId == cursorDocId);
      if (idx >= 0) {
        startIdx = idx + 1;
      } else {
        return const MarkerPage(items: []);
      }
    }

    final remaining = userSaves.skip(startIdx).toList();
    final items = <PhotographerSummary>[];
    String? nextCursor;
    var examined = 0;
    const maxExtraRounds = 3;
    var rounds = 0;

    for (var i = 0; i < remaining.length; i += n) {
      rounds++;
      final chunk = remaining.skip(i).take(n).toList();
      examined += chunk.length;
      final ids = chunk.map((c) => c.photographerId).toList();
      final fetched = photographerRepo != null
          ? await photographerRepo!.summaries(ids)
          : <String, PhotographerSummary>{};
      // Only keep published profiles (where displayName is not empty)
      final published = <String, PhotographerSummary>{
        for (final entry in fetched.entries)
          if (entry.value.displayName.isNotEmpty) entry.key: entry.value,
      };
      final ordered = keepOrder(ids, published);
      items.addAll(ordered);

      if (items.length >= n || rounds > maxExtraRounds || chunk.length < n) {
        if (examined < remaining.length) {
          final lastMarker = chunk.last;
          nextCursor = markerCursor(lastMarker.createdAt, lastMarker.docId);
        }
        break;
      }
    }

    final pageItems = items.take(n).toList();
    return MarkerPage(items: pageItems, cursor: nextCursor);
  }

  @override
  Future<MarkerPage<PhotographerSummary>> following(
    String uid, {
    String? cursor,
    int limit = 20,
  }) async {
    _check();
    readCalls++;
    final n = clampPageSize(limit);
    final userFollows = followEntries.where((e) => e.userId == uid).toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.docId.compareTo(a.docId);
      });

    final parsedCursor = parseMarkerCursor(cursor);
    var startIdx = 0;
    if (parsedCursor != null) {
      final (cursorTime, cursorDocId) = parsedCursor;
      final idx = userFollows.indexWhere((e) =>
          e.createdAt == cursorTime && e.docId == cursorDocId);
      if (idx >= 0) {
        startIdx = idx + 1;
      } else {
        return const MarkerPage(items: []);
      }
    }

    final remaining = userFollows.skip(startIdx).toList();
    final items = <PhotographerSummary>[];
    String? nextCursor;
    var examined = 0;
    const maxExtraRounds = 3;
    var rounds = 0;

    for (var i = 0; i < remaining.length; i += n) {
      rounds++;
      final chunk = remaining.skip(i).take(n).toList();
      examined += chunk.length;
      final ids = chunk.map((c) => c.photographerId).toList();
      final fetched = photographerRepo != null
          ? await photographerRepo!.summaries(ids)
          : <String, PhotographerSummary>{};
      // Only keep published profiles (where displayName is not empty, representing existing valid profiles)
      final published = <String, PhotographerSummary>{
        for (final entry in fetched.entries)
          if (entry.value.displayName.isNotEmpty) entry.key: entry.value,
      };
      final ordered = keepOrder(ids, published);
      items.addAll(ordered);

      if (items.length >= n || rounds > maxExtraRounds || chunk.length < n) {
        if (examined < remaining.length) {
          final lastMarker = chunk.last;
          nextCursor = markerCursor(lastMarker.createdAt, lastMarker.docId);
        }
        break;
      }
    }

    final pageItems = items.take(n).toList();
    return MarkerPage(items: pageItems, cursor: nextCursor);
  }

  @override
  Future<MarkerPage<Follower>> followers(
    String photographerId, {
    String? cursor,
    int limit = 30,
  }) async {
    _check();
    readCalls++;
    final n = clampPageSize(limit);
    final targetFollows = followEntries.where((e) => e.photographerId == photographerId).toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.docId.compareTo(a.docId);
      });

    final parsedCursor = parseMarkerCursor(cursor);
    var startIdx = 0;
    if (parsedCursor != null) {
      final (cursorTime, cursorDocId) = parsedCursor;
      final idx = targetFollows.indexWhere((e) =>
          e.createdAt == cursorTime && e.docId == cursorDocId);
      if (idx >= 0) {
        startIdx = idx + 1;
      } else {
        return const MarkerPage(items: []);
      }
    }

    final rest = targetFollows.skip(startIdx).toList();
    final chunk = rest.take(n).toList();
    final items = <Follower>[];
    for (final m in chunk) {
      final user = userDirectory[m.userId];
      items.add(Follower(
        userId: m.userId,
        displayName: user?.displayName ?? 'Người dùng',
        avatarUrl: user?.avatarUrl,
        since: m.createdAt,
      ));
    }

    final nextCursor = rest.length > n
        ? markerCursor(chunk.last.createdAt, chunk.last.docId)
        : null;
    return MarkerPage(items: items, cursor: nextCursor);
  }

  @override
  Future<bool> isPhotographerSaved(String uid, String photographerId) async {
    _check();
    readCalls++;
    return savedPhotographerEntries
        .any((e) => e.userId == uid && e.photographerId == photographerId);
  }

  @override
  Future<void> setPhotographerSaved(
    String uid,
    String photographerId,
    bool saved,
  ) async {
    _check();
    writeCalls++;
    if (saved) {
      if (!savedPhotographerEntries.any((e) => e.userId == uid && e.photographerId == photographerId)) {
        addSavedPhotographer(uid, photographerId, DateTime.now().toUtc());
      }
    } else {
      savedPhotographerEntries.removeWhere(
        (e) => e.userId == uid && e.photographerId == photographerId,
      );
    }
  }

  @override
  Future<Set<String>> followingIds(String uid, {int limit = 100}) async {
    _check();
    readCalls++;
    final userFollows = followEntries.where((e) => e.userId == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return userFollows.take(limit).map((e) => e.photographerId).toSet();
  }

  @override
  Future<SocialCounts> counts(String uid) async {
    _check();
    readCalls++;
    final followingCount = followEntries.where((e) => e.userId == uid).length;
    final savedPostsCount = savedPostEntries.where((e) => e.userId == uid).length;
    final savedPhotographersCount =
        savedPhotographerEntries.where((e) => e.userId == uid).length;
    return SocialCounts(
      following: followingCount,
      savedPosts: savedPostsCount,
      savedPhotographers: savedPhotographersCount,
    );
  }

  @override
  Future<int?> followerCount(String photographerId) async {
    _check();
    readCalls++;
    if (followerCounts.containsKey(photographerId)) {
      return followerCounts[photographerId];
    }
    return followEntries.where((e) => e.photographerId == photographerId).length;
  }
}

