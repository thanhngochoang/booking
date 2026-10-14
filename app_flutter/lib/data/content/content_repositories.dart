// lib/data/content/content_repositories.dart
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

/// Page sizes are clamped to this by every implementation.
const kMaxPageSize = 50;

/// [limit] forced into `1..max` (an `int`, unlike `num.clamp`).
int clampPageSize(int limit, [int max = kMaxPageSize]) =>
    limit < 1 ? 1 : (limit > max ? max : limit);

/// Every method throws on transport failure; callers must not depend on the
/// exception type. Ids that are empty or contain '/' cannot name a document:
/// lookups return null and a cursor of that shape gives an empty last page.
abstract class PostRepository {
  /// Newest first: `createdAt` descending, then `id` descending (a total
  /// order, so paging through ties is stable). [limit] is clamped to
  /// 1..[kMaxPageSize]. `nextCursor` is non-null exactly when more posts
  /// follow. An unknown or stale [cursor] yields an empty page with no cursor.
  Future<PostPage> feed({
    PostKind? kind,
    String? specialtyId,
    String? cursor,
    int limit = 20,
  });

  /// Same ordering, clamping and cursor rules as [feed].
  Future<PostPage> byPhotographer(
    String photographerId, {
    String? cursor,
    int limit = 20,
  });

  /// Posts whose `authorId` is [uid], newest first (`createdAt` desc, then id
  /// desc); [kind] narrows to one kind. Same clamping and cursor rules as
  /// [feed]. An id that cannot name a document gives an empty page.
  Future<PostPage> byAuthor(
    String uid, {
    PostKind? kind,
    String? cursor,
    int limit = 20,
  });

  /// How many posts [uid] authored (all kinds, or one [kind]), counted by the
  /// server (`count()` aggregation, about one read per 1000 posts). 0 for an id
  /// that cannot name a document. Throws on transport failure.
  Future<int> countByAuthor(String uid, {PostKind? kind});

  /// The posts of one album in `albumPosition` order, [limit] clamped to
  /// 1..[kMaxPageSize]. Same cursor rules as [feed].
  Future<PostPage> byAlbum(String albumId, {String? cursor, int limit = 24});

  /// Null when the post does not exist or was removed.
  Future<PostSummary?> byId(String postId);

  /// Posts by id; unknown or deleted ids are absent from the map.
  /// Adapters chunk `whereIn` queries by 30.
  Future<Map<String, PostSummary>> byIds(Iterable<String> ids);
}

class PostEngagement {
  const PostEngagement({this.liked = false, this.saved = false});
  final bool liked;
  final bool saved;
}

/// The viewer's own likes, saves and follows. Counters on posts are written
/// by the server; the client only writes these marker documents. Each setter
/// writes only the viewer's own marker, never a counter. Setters are
/// idempotent.
abstract class PostEngagementRepository {
  Future<PostEngagement> engagementFor(String uid, String postId);
  Future<Set<String>> savedAmong(String uid, Iterable<String> postIds);
  Future<void> setLiked(String uid, String postId, bool liked);
  Future<void> setSaved(String uid, String postId, bool saved);
  Future<bool> isFollowing(String uid, String photographerId);
  Future<void> setFollowing(String uid, String photographerId, bool following);
}

abstract class PhotographerPoolCache {
  void invalidate();
}

abstract class PhotographerRepository {
  /// Photographers by id; unknown ids are absent from the result. [ids] may
  /// have any length; adapters chunk `whereIn` queries by 30.
  Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids);

  /// Photographers whose next free day lies in `[today, today + 7 days)`
  /// (Vietnam calendar days), `acceptingOrders == true`, soonest first, then
  /// best score, then `id` ascending. [limit] is clamped to 1..[kMaxPageSize].
  /// Server invariant: `stats.score` is always written (0 when no reviews)
  /// whenever `stats.nextFreeDate` is written; a photographer without
  /// `stats.score` is not returned.
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  });

  /// The recommender candidate pool, for ranking on the device when the
  /// recommender service is not available. Returns bookable providers only
  /// (`acceptingOrders == true`). The one list whose [limit] is clamped to
  /// 1..200 instead of 1..[kMaxPageSize].
  Future<List<PhotographerSummary>> candidates({int limit = 200});
}

abstract class ServiceRepository {
  Future<ServiceSummary?> byId(String photographerId, String serviceId);

  /// Active services only; [limit] is clamped to 1..[kMaxPageSize].
  Future<List<ServiceSummary>> activeFor(
    String photographerId, {
    int limit = 50,
  });
}
