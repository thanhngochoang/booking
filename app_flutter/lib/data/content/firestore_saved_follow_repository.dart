import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/saved_follow.dart';
import 'package:photobooking/data/content/saved_follow_repository.dart';

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

class FirestoreSavedFollowRepository implements SavedFollowRepository {
  FirestoreSavedFollowRepository({
    FirebaseFirestore? db,
    required this._posts,
    required this._photographers,
  })  : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final PostRepository _posts;
  final PhotographerRepository _photographers;

  DocumentReference<Map<String, dynamic>> _markerDoc(
    String collection,
    String uid,
    String targetId,
  ) =>
      _db.collection(collection).doc('${uid}_$targetId');

  Future<void> _setMarker(
    String collection,
    String uid,
    String field,
    String targetId,
    bool on,
  ) async {
    final ref = _markerDoc(collection, uid, targetId);
    if (on) {
      await ref.set({
        'userId': uid,
        field: targetId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Future<MarkerPage<PostSummary>> savedPosts(
    String uid, {
    String? cursor,
    int limit = 30,
  }) async {
    if (!_validId(uid)) return const MarkerPage(items: []);
    final n = clampPageSize(limit);

    var q = _db
        .collection('saves')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (cursor != null) {
      final parsed = parseMarkerCursor(cursor);
      if (parsed == null) return const MarkerPage(items: []);
      final (cursorTime, cursorDocId) = parsed;
      q = q.startAfter([Timestamp.fromDate(cursorTime), cursorDocId]);
    }

    final items = <PostSummary>[];
    String? nextCursor;
    const maxExtraRounds = 3;
    var rounds = 0;

    while (items.length < n && rounds <= maxExtraRounds) {
      rounds++;
      final needed = n - items.length;
      final snap = await q.limit(needed + 1).get();
      if (snap.docs.isEmpty) break;

      final chunkDocs = snap.docs.take(needed).toList();
      final ids = [
        for (final d in chunkDocs)
          if (d.data()['postId'] is String) d.data()['postId'] as String,
      ];

      final fetched = await _posts.byIds(ids);
      final ordered = keepOrder(ids, fetched);
      items.addAll(ordered);

      final lastDoc = chunkDocs.last;
      final lastCreatedAt = lastDoc.data()['createdAt'];
      if (lastCreatedAt is Timestamp) {
        nextCursor = markerCursor(lastCreatedAt.toDate().toUtc(), lastDoc.id);
      }

      if (snap.docs.length <= needed) {
        // No more documents in collection
        nextCursor = null;
        break;
      }

      // Prepare query for next top-up round if we still need items
      if (items.length < n && lastCreatedAt is Timestamp) {
        q = _db
            .collection('saves')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId, descending: true)
            .startAfter([lastCreatedAt, lastDoc.id]);
      } else {
        break;
      }
    }

    return MarkerPage(items: items.take(n).toList(), cursor: nextCursor);
  }

  @override
  Future<MarkerPage<PhotographerSummary>> savedPhotographers(
    String uid, {
    String? cursor,
    int limit = 20,
  }) async {
    if (!_validId(uid)) return const MarkerPage(items: []);
    final n = clampPageSize(limit);

    var q = _db
        .collection('savedPhotographers')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (cursor != null) {
      final parsed = parseMarkerCursor(cursor);
      if (parsed == null) return const MarkerPage(items: []);
      final (cursorTime, cursorDocId) = parsed;
      q = q.startAfter([Timestamp.fromDate(cursorTime), cursorDocId]);
    }

    final items = <PhotographerSummary>[];
    String? nextCursor;
    const maxExtraRounds = 3;
    var rounds = 0;

    while (items.length < n && rounds <= maxExtraRounds) {
      rounds++;
      final needed = n - items.length;
      final snap = await q.limit(needed + 1).get();
      if (snap.docs.isEmpty) break;

      final chunkDocs = snap.docs.take(needed).toList();
      final ids = [
        for (final d in chunkDocs)
          if (d.data()['photographerId'] is String)
            d.data()['photographerId'] as String,
      ];

      final fetched = await _photographers.summaries(ids);
      final published = <String, PhotographerSummary>{
        for (final entry in fetched.entries)
          if (entry.value.displayName.isNotEmpty) entry.key: entry.value,
      };
      final ordered = keepOrder(ids, published);
      items.addAll(ordered);

      final lastDoc = chunkDocs.last;
      final lastCreatedAt = lastDoc.data()['createdAt'];
      if (lastCreatedAt is Timestamp) {
        nextCursor = markerCursor(lastCreatedAt.toDate().toUtc(), lastDoc.id);
      }

      if (snap.docs.length <= needed) {
        nextCursor = null;
        break;
      }

      if (items.length < n && lastCreatedAt is Timestamp) {
        q = _db
            .collection('savedPhotographers')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId, descending: true)
            .startAfter([lastCreatedAt, lastDoc.id]);
      } else {
        break;
      }
    }

    return MarkerPage(items: items.take(n).toList(), cursor: nextCursor);
  }

  @override
  Future<MarkerPage<PhotographerSummary>> following(
    String uid, {
    String? cursor,
    int limit = 20,
  }) async {
    if (!_validId(uid)) return const MarkerPage(items: []);
    final n = clampPageSize(limit);

    var q = _db
        .collection('follows')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (cursor != null) {
      final parsed = parseMarkerCursor(cursor);
      if (parsed == null) return const MarkerPage(items: []);
      final (cursorTime, cursorDocId) = parsed;
      q = q.startAfter([Timestamp.fromDate(cursorTime), cursorDocId]);
    }

    final items = <PhotographerSummary>[];
    String? nextCursor;
    const maxExtraRounds = 3;
    var rounds = 0;

    while (items.length < n && rounds <= maxExtraRounds) {
      rounds++;
      final needed = n - items.length;
      final snap = await q.limit(needed + 1).get();
      if (snap.docs.isEmpty) break;

      final chunkDocs = snap.docs.take(needed).toList();
      final ids = [
        for (final d in chunkDocs)
          if (d.data()['photographerId'] is String)
            d.data()['photographerId'] as String,
      ];

      final fetched = await _photographers.summaries(ids);
      final published = <String, PhotographerSummary>{
        for (final entry in fetched.entries)
          if (entry.value.displayName.isNotEmpty) entry.key: entry.value,
      };
      final ordered = keepOrder(ids, published);
      items.addAll(ordered);

      final lastDoc = chunkDocs.last;
      final lastCreatedAt = lastDoc.data()['createdAt'];
      if (lastCreatedAt is Timestamp) {
        nextCursor = markerCursor(lastCreatedAt.toDate().toUtc(), lastDoc.id);
      }

      if (snap.docs.length <= needed) {
        nextCursor = null;
        break;
      }

      if (items.length < n && lastCreatedAt is Timestamp) {
        q = _db
            .collection('follows')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId, descending: true)
            .startAfter([lastCreatedAt, lastDoc.id]);
      } else {
        break;
      }
    }

    return MarkerPage(items: items.take(n).toList(), cursor: nextCursor);
  }

  @override
  Future<MarkerPage<Follower>> followers(
    String photographerId, {
    String? cursor,
    int limit = 30,
  }) async {
    if (!_validId(photographerId)) return const MarkerPage(items: []);
    final n = clampPageSize(limit);

    var q = _db
        .collection('follows')
        .where('photographerId', isEqualTo: photographerId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (cursor != null) {
      final parsed = parseMarkerCursor(cursor);
      if (parsed == null) return const MarkerPage(items: []);
      final (cursorTime, cursorDocId) = parsed;
      q = q.startAfter([Timestamp.fromDate(cursorTime), cursorDocId]);
    }

    final snap = await q.limit(n + 1).get();
    if (snap.docs.isEmpty) return const MarkerPage(items: []);

    final chunkDocs = snap.docs.take(n).toList();
    final userIds = [
      for (final d in chunkDocs)
        if (d.data()['userId'] is String) d.data()['userId'] as String,
    ];

    // Read user documents in chunks of 30 to get displayName and avatarUrl
    const chunkSize = 30;
    final userSnaps = await Future.wait([
      for (var i = 0; i < userIds.length; i += chunkSize)
        _db
            .collection('users')
            .where(
              FieldPath.documentId,
              whereIn: userIds.sublist(
                i,
                i + chunkSize > userIds.length ? userIds.length : i + chunkSize,
              ),
            )
            .get(),
    ]);

    final userMap = <String, ({String displayName, String? avatarUrl})>{};
    for (final s in userSnaps) {
      for (final doc in s.docs) {
        final d = doc.data();
        final name = d['name'] is String
            ? d['name'] as String
            : (d['displayName'] is String ? d['displayName'] as String : 'Người dùng');
        final avatar = d['avatarUrl'] is String ? d['avatarUrl'] as String : null;
        userMap[doc.id] = (displayName: name, avatarUrl: avatar);
      }
    }

    final items = <Follower>[];
    for (final doc in chunkDocs) {
      final d = doc.data();
      final uid = d['userId'] as String? ?? '';
      final createdAt = d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate().toUtc()
          : DateTime.now().toUtc();
      final u = userMap[uid];
      items.add(Follower(
        userId: uid,
        displayName: u?.displayName ?? 'Người dùng',
        avatarUrl: u?.avatarUrl,
        since: createdAt,
      ));
    }

    String? nextCursor;
    if (snap.docs.length > n) {
      final lastDoc = chunkDocs.last;
      final lastCreatedAt = lastDoc.data()['createdAt'];
      if (lastCreatedAt is Timestamp) {
        nextCursor = markerCursor(lastCreatedAt.toDate().toUtc(), lastDoc.id);
      }
    }

    return MarkerPage(items: items, cursor: nextCursor);
  }

  @override
  Future<bool> isPhotographerSaved(String uid, String photographerId) async {
    if (!_validId(uid) || !_validId(photographerId)) return false;
    final snap = await _markerDoc('savedPhotographers', uid, photographerId).get();
    return snap.exists;
  }

  @override
  Future<void> setPhotographerSaved(
    String uid,
    String photographerId,
    bool saved,
  ) async {
    if (!_validId(uid) || !_validId(photographerId)) return;
    await _setMarker(
      'savedPhotographers',
      uid,
      'photographerId',
      photographerId,
      saved,
    );
  }

  @override
  Future<Set<String>> followingIds(String uid, {int limit = 100}) async {
    if (!_validId(uid)) return const {};
    final snap = await _db
        .collection('follows')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return {
      for (final doc in snap.docs)
        if (doc.data()['photographerId'] is String)
          doc.data()['photographerId'] as String,
    };
  }

  @override
  Future<SocialCounts> counts(String uid) async {
    if (!_validId(uid)) return const SocialCounts();
    final followsSnap = await _db
        .collection('follows')
        .where('userId', isEqualTo: uid)
        .count()
        .get();
    final savesSnap = await _db
        .collection('saves')
        .where('userId', isEqualTo: uid)
        .count()
        .get();
    final savedPhotographersSnap = await _db
        .collection('savedPhotographers')
        .where('userId', isEqualTo: uid)
        .count()
        .get();

    return SocialCounts(
      following: followsSnap.count ?? 0,
      savedPosts: savesSnap.count ?? 0,
      savedPhotographers: savedPhotographersSnap.count ?? 0,
    );
  }

  @override
  Future<int?> followerCount(String photographerId) async {
    if (!_validId(photographerId)) return null;
    final doc = await _db.collection('photographers').doc(photographerId).get();
    if (!doc.exists) return null;
    final d = doc.data();
    if (d == null || !d.containsKey('followerCount')) return null;
    final count = d['followerCount'];
    return count is num ? count.toInt() : null;
  }
}
