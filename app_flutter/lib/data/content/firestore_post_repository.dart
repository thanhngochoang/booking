// lib/data/content/firestore_post_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';

int _int(Object? v) => v is num ? v.toInt() : 0;

DateTime _instant(Object? v) =>
    v is Timestamp ? v.toDate().toUtc() : DateTime.now().toUtc();

/// Maps a `posts/{id}` document. Returns null for documents that cannot be
/// shown: soft-deleted, or missing the photographer, the service or any image.
PostSummary? postFromFirestore(String id, Map<String, dynamic> d) {
  if (d['deletedAt'] != null) {
    return null;
  }
  final photographerId = d['photographerId'];
  final serviceId = d['serviceId'];
  final urls = d['imageUrls'];
  if (photographerId is! String ||
      serviceId is! String ||
      urls is! List ||
      urls.isEmpty) {
    return null;
  }
  final meta = d['imageMeta'] is List ? d['imageMeta'] as List : const [];
  final images = <PostImage>[
    for (var i = 0; i < urls.length; i++)
      PostImage(
        url: urls[i] as String,
        blurHash: i < meta.length && meta[i] is Map
            ? (meta[i] as Map)['blurHash'] as String?
            : null,
        width: i < meta.length && meta[i] is Map
            ? ((meta[i] as Map)['w'] as num?)?.toInt()
            : null,
        height: i < meta.length && meta[i] is Map
            ? ((meta[i] as Map)['h'] as num?)?.toInt()
            : null,
      ),
  ];
  final location = d['location'];
  return PostSummary(
    id: id,
    kind: PostKind.fromCode(d['kind'] as String?),
    authorId: (d['authorId'] as String?) ?? photographerId,
    photographerId: photographerId,
    serviceId: serviceId,
    bookingId: d['bookingId'] as String?,
    images: images,
    caption: (d['caption'] as String?) ?? '',
    locationName: location is Map ? location['name'] as String? : null,
    styleId: d['style'] as String?,
    specialtyId: d['specialty'] as String?,
    hashtags: [
      if (d['hashtags'] is List) ...(d['hashtags'] as List).whereType<String>(),
    ],
    inPortfolio: d['inPortfolio'] == true,
    likeCount: _int(d['likeCount']),
    saveCount: _int(d['saveCount']),
    createdAt: _instant(d['createdAt']),
  );
}

class FirestorePostRepository implements PostRepository {
  FirestorePostRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  Future<PostPage> _page(
    Query<Map<String, dynamic>> base,
    String? cursor,
    int limit,
  ) async {
    final n = clampPageSize(limit);
    // Total order: createdAt desc, then document id desc. The cursor is the id
    // of the last document of the page; startAfterDocument encodes both keys.
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
    final snap = await q.limit(n + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > n;
    final pageDocs = hasMore ? docs.take(n).toList() : docs;
    final posts = <PostSummary>[
      for (final d in pageDocs)
        if (postFromFirestore(d.id, d.data()) case final p?) p,
    ];
    return PostPage(
      posts: posts,
      nextCursor: hasMore ? pageDocs.last.id : null,
    );
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
