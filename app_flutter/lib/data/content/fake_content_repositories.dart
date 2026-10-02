// lib/data/content/fake_content_repositories.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

class FakePostRepository implements PostRepository {
  FakePostRepository([List<PostSummary> posts = const []])
    : _posts = List.of(posts);

  final List<PostSummary> _posts;

  /// When set, every call throws it.
  Object? failWith;

  /// The cursor of every [byPhotographer] call, in order (null = first page).
  final byPhotographerCursors = <String?>[];

  void add(PostSummary post) => _posts.add(post);

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
        .where((p) => kind == null || p.kind == kind)
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
    if (failWith != null) {
      throw failWith!;
    }
    final filtered = _newestFirst
        .where((p) => p.photographerId == photographerId)
        .toList();
    return _page(filtered, cursor, limit);
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
          final byRating = b.ratingAvg.compareTo(a.ratingAvg);
          return byRating != 0 ? byRating : a.id.compareTo(b.id);
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
