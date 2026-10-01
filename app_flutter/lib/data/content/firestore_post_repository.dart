// lib/data/content/firestore_post_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';

int _int(Object? v) => v is num ? v.toInt() : 0;

String? _str(Object? v) => v is String ? v : null;

/// Maps a `posts/{id}` document. Returns null for documents that cannot be
/// shown: soft-deleted, missing or wrong-typed photographer, service, image
/// list or `createdAt` (a stored value that is not a Timestamp, including
/// null, is malformed: a pending server timestamp cannot be told apart from
/// an explicit null in the map, so it is skipped too; feeds read committed
/// documents, where the server has filled it in). Never throws.
PostSummary? postFromFirestore(String id, Map<String, dynamic> d) {
  if (d['deletedAt'] != null) {
    return null;
  }
  final photographerId = d['photographerId'];
  final serviceId = d['serviceId'];
  final urls = d['imageUrls'];
  final createdAt = d['createdAt'];
  if (photographerId is! String ||
      serviceId is! String ||
      urls is! List ||
      urls.isEmpty ||
      urls.any((u) => u is! String) ||
      createdAt is! Timestamp) {
    return null;
  }
  final meta = d['imageMeta'] is List ? d['imageMeta'] as List : const [];
  final images = <PostImage>[];
  for (var i = 0; i < urls.length; i++) {
    final m = i < meta.length && meta[i] is Map ? meta[i] as Map : null;
    images.add(
      PostImage(
        url: urls[i] as String,
        blurHash: _str(m?['blurHash']),
        width: (m?['w'] is num) ? (m!['w'] as num).toInt() : null,
        height: (m?['h'] is num) ? (m!['h'] as num).toInt() : null,
      ),
    );
  }
  final location = d['location'];
  return PostSummary(
    id: id,
    kind: PostKind.fromCode(_str(d['kind'])),
    authorId: _str(d['authorId']) ?? photographerId,
    photographerId: photographerId,
    serviceId: serviceId,
    bookingId: _str(d['bookingId']),
    images: images,
    caption: _str(d['caption']) ?? '',
    locationName: location is Map ? _str(location['name']) : null,
    styleId: _str(d['style']),
    specialtyId: _str(d['specialty']),
    hashtags: [
      if (d['hashtags'] is List) ...(d['hashtags'] as List).whereType<String>(),
    ],
    inPortfolio: d['inPortfolio'] == true,
    likeCount: _int(d['likeCount']),
    saveCount: _int(d['saveCount']),
    createdAt: createdAt.toDate().toUtc(),
  );
}

const _maxExtraRounds = 3;

class FirestorePostRepository implements PostRepository {
  FirestorePostRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// Pages by (createdAt desc, id desc). Documents that cannot be mapped
  /// (soft-deleted, malformed) are skipped and topped up from the following
  /// documents, with one post of look-ahead so `nextCursor` is non-null exactly
  /// when another showable post follows. The cursor is the id of the raw
  /// document of the last post on the page.
  ///
  /// Known edge: the top-up is bounded to [_maxExtraRounds] extra queries. If
  /// that many consecutive documents are unshowable, the page may be short and
  /// carries a cursor (of the last document examined) although the rest may
  /// turn out to be empty.
  Future<PostPage> _page(
    Query<Map<String, dynamic>> base,
    String? cursor,
    int limit,
  ) async {
    final n = clampPageSize(limit);
    var q = base
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (cursor != null) {
      final at = await _posts.doc(cursor).get();
      if (!at.exists) {
        return const PostPage(posts: [], nextCursor: null);
      }
      q = q.startAfterDocument(at);
    }
    final posts = <PostSummary>[];
    final rawIds = <String>[]; // raw document id of each collected post
    QueryDocumentSnapshot<Map<String, dynamic>>? last;
    for (var round = 0; round <= _maxExtraRounds; round++) {
      final want = n + 1 - posts.length;
      final snap = await (last == null ? q : q.startAfterDocument(last))
          .limit(want)
          .get();
      for (final d in snap.docs) {
        final p = postFromFirestore(d.id, d.data());
        if (p != null) {
          posts.add(p);
          rawIds.add(d.id);
        }
      }
      if (snap.docs.length < want) {
        return _result(posts, rawIds, n);
      }
      last = snap.docs.last;
      if (posts.length > n) {
        break;
      }
    }
    if (posts.length > n) {
      return _result(posts, rawIds, n);
    }
    return PostPage(posts: posts, nextCursor: last?.id);
  }

  PostPage _result(List<PostSummary> posts, List<String> rawIds, int n) {
    if (posts.length <= n) {
      return PostPage(posts: posts, nextCursor: null);
    }
    return PostPage(posts: posts.take(n).toList(), nextCursor: rawIds[n - 1]);
  }

  @override
  Future<PostPage> feed({
    PostKind? kind,
    String? specialtyId,
    String? cursor,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> q = _posts;
    if (kind != null) {
      q = q.where('kind', isEqualTo: kind.code);
    }
    if (specialtyId != null) {
      q = q.where('specialty', isEqualTo: specialtyId);
    }
    return _page(q, cursor, limit);
  }

  @override
  Future<PostPage> byPhotographer(
    String photographerId, {
    String? cursor,
    int limit = 20,
  }) => _page(
    _posts.where('photographerId', isEqualTo: photographerId),
    cursor,
    limit,
  );

  @override
  Future<PostSummary?> byId(String postId) async {
    final snap = await _posts.doc(postId).get();
    final data = snap.data();
    return data == null ? null : postFromFirestore(snap.id, data);
  }
}

class FirestoreEngagementRepository implements PostEngagementRepository {
  FirestoreEngagementRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(
    String collection,
    String uid,
    String id,
  ) => _db.collection(collection).doc('${uid}_$id');

  Future<void> _set(
    DocumentReference<Map<String, dynamic>> ref,
    bool on,
    Map<String, dynamic> data,
  ) async {
    if (on) {
      await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  @override
  Future<PostEngagement> engagementFor(String uid, String postId) async {
    final results = await Future.wait([
      _doc('likes', uid, postId).get(),
      _doc('saves', uid, postId).get(),
    ]);
    return PostEngagement(liked: results[0].exists, saved: results[1].exists);
  }

  @override
  Future<Set<String>> savedAmong(String uid, Iterable<String> postIds) async {
    final ids = postIds.toSet().toList();
    final snaps = await Future.wait([
      for (final id in ids) _doc('saves', uid, id).get(),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        if (snaps[i].exists) ids[i],
    };
  }

  @override
  Future<void> setLiked(String uid, String postId, bool liked) => _set(
    _doc('likes', uid, postId),
    liked,
    {'userId': uid, 'postId': postId},
  );

  @override
  Future<void> setSaved(String uid, String postId, bool saved) => _set(
    _doc('saves', uid, postId),
    saved,
    {'userId': uid, 'postId': postId},
  );

  @override
  Future<bool> isFollowing(String uid, String photographerId) async =>
      (await _doc('follows', uid, photographerId).get()).exists;

  @override
  Future<void> setFollowing(
    String uid,
    String photographerId,
    bool following,
  ) => _set(_doc('follows', uid, photographerId), following, {
    'userId': uid,
    'photographerId': photographerId,
  });
}
