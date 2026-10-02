// lib/data/content/firestore_post_publisher.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';

class FirestorePostPublisher implements PostPublisher {
  FirestorePostPublisher({
    FirebaseFirestore? db,
    @visibleForTesting Future<void> Function(WriteBatch batch)? commit,
  }) : _db = db ?? FirebaseFirestore.instance,
       _commit =
           commit ?? ((b) => b.commit().timeout(const Duration(seconds: 20)));
  final FirebaseFirestore _db;
  final Future<void> Function(WriteBatch batch) _commit;

  @override
  Future<PostSummary> publish(PostDraft d) async {
    final hashtags = extractHashtags(d.caption);
    final batch = _db.batch();
    batch.set(_db.collection('posts').doc(d.id), {
      'kind': PostKind.work.code,
      'authorId': d.photographerId,
      'photographerId': d.photographerId,
      'serviceId': d.serviceId,
      if (d.specialtyId != null) 'specialty': d.specialtyId,
      'imageUrls': [for (final i in d.images) i.url],
      'imageMeta': [
        for (final i in d.images)
          {'blurHash': i.blurHash, 'w': i.width, 'h': i.height},
      ],
      'caption': d.caption,
      if (d.locationName != null) 'location': {'name': d.locationName},
      if (d.styleId != null) 'style': d.styleId,
      'hashtags': hashtags,
      'inPortfolio': d.inPortfolio,
      'likeCount': 0,
      'saveCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (d.inPortfolio) {
      batch.set(_db.collection('photographers').doc(d.photographerId), {
        'portfolio': FieldValue.arrayUnion([d.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    // Offline, a Firestore commit never completes until the server answers;
    // the 20 second deadline (see the default commit) turns that into an
    // error the user can retry. The rules allow only create on posts, so a
    // retry cannot overwrite: it is idempotent because a post that already
    // landed is detected below and reported as success.
    try {
      await _commit(batch);
    } catch (_) {
      if (!await _alreadyLanded(d)) {
        rethrow;
      }
    }
    return PostSummary(
      id: d.id,
      kind: PostKind.work,
      authorId: d.photographerId,
      photographerId: d.photographerId,
      serviceId: d.serviceId,
      images: d.images,
      caption: d.caption,
      locationName: d.locationName,
      styleId: d.styleId,
      specialtyId: d.specialtyId,
      hashtags: hashtags,
      inPortfolio: d.inPortfolio,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<bool> _alreadyLanded(PostDraft d) async {
    try {
      final snap = await _db
          .collection('posts')
          .doc(d.id)
          .get(const GetOptions(source: Source.server));
      return snap.exists && snap.data()?['authorId'] == d.photographerId;
    } catch (_) {
      return false;
    }
  }
}
