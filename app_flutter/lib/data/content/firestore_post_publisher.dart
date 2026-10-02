// lib/data/content/firestore_post_publisher.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';

class FirestorePostPublisher implements PostPublisher {
  FirestorePostPublisher({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

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
    // Offline, a Firestore commit never completes until the server answers.
    // The deadline turns that into an error the user can retry; the retry
    // reuses the same post id, so the queued write is not duplicated.
    await batch.commit().timeout(const Duration(seconds: 20));
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
}
