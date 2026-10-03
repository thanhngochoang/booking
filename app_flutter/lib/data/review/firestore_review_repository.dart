import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_repository.dart';

class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _customFunctions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _customFunctions;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  @visibleForTesting
  static ReviewErrorCode mapFunctionsError(dynamic e) {
    if (e is FirebaseFunctionsException) {
      final detailsCode =
          e.details is Map ? (e.details as Map)['code'] as String? : null;
      for (final candidate in [detailsCode, e.code, e.message]) {
        if (candidate == null) continue;
        final mapped = switch (candidate) {
          'conflict' ||
          'aborted' ||
          'already-exists' =>
            ReviewErrorCode.conflict,
          'not_eligible' ||
          'failed-precondition' =>
            ReviewErrorCode.notEligible,
          'permission_denied' ||
          'permission-denied' ||
          'unauthenticated' =>
            ReviewErrorCode.permissionDenied,
          'not_found' || 'not-found' => ReviewErrorCode.notFound,
          'invalid_argument' ||
          'invalid-argument' =>
            ReviewErrorCode.invalidArgument,
          'unavailable' || 'deadline-exceeded' => ReviewErrorCode.network,
          _ => null,
        };
        if (mapped != null) return mapped;
      }
    }
    return ReviewErrorCode.unknown;
  }

  @override
  Stream<Review?> watchReview(String bookingId) {
    return _firestore
        .collection('reviews')
        .doc(bookingId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Review.fromFirestore(doc);
    });
  }

  @override
  Future<ReviewPage> forPhotographer(
    String photographerId, {
    Object? after,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('reviews')
        .where('photographerId', isEqualTo: photographerId)
        .orderBy('createdAt', descending: true);

    if (after is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(after);
    }

    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    final items = pageDocs.map((d) => Review.fromFirestore(d)).toList();
    final cursor = pageDocs.isNotEmpty ? pageDocs.last : null;

    return ReviewPage(
      items: items,
      cursor: cursor,
      hasMore: hasMore,
    );
  }

  @override
  Future<String?> submit({
    required String bookingId,
    required int rating,
    required String text,
    String? postId,
    List<ReviewPhoto> photos = const [],
  }) async {
    try {
      final res = await _functions
          .httpsCallable('submitReview')
          .call<Map<String, dynamic>>({
        'bookingId': bookingId,
        'rating': rating,
        'text': text,
        'postId': postId,
        'photos': photos.map((p) => p.toMap()).toList(),
      });
      return res.data['postId'] as String?;
    } catch (e) {
      throw ReviewException(mapFunctionsError(e), e.toString());
    }
  }
}
