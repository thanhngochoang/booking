// lib/data/events/firestore_event_timeline_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/events/event_callable.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/events/event_timeline_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// `events/{id}/timeline/{postId}` row → item; null when it cannot be shown.
TimelineItem? timelineItemFromFirestore(String id, Map<String, dynamic> d) {
  final url = d['imageUrl'];
  final author = d['authorId'];
  final added = d['addedAt'];
  if (url is! String ||
      url.isEmpty ||
      author is! String ||
      added is! Timestamp) {
    return null;
  }
  int? dim(Object? v) => v is num && v > 0 ? v.toInt() : null;
  return TimelineItem(
    postId: id,
    authorId: author,
    authorName: d['authorName'] is String ? d['authorName'] as String : '',
    imageUrl: url,
    imageW: dim(d['imageW']),
    imageH: dim(d['imageH']),
    imageCount: d['imageCount'] is num ? (d['imageCount'] as num).toInt() : 1,
    isHost: d['isHost'] == true,
    status: TimelineStatus.fromCode(d['status'] as String?),
    addedAt: added.toDate().toUtc(),
  );
}

/// Reads the timeline rows directly (the rules show visitors `visible` rows
/// only); every write is the callable `shareEventPost` / `moderateEventTimeline`.
class FirestoreEventTimelineRepository implements EventTimelineRepository {
  FirestoreEventTimelineRepository({
    required this.uid,
    required this.uploader,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final String? uid;
  final MediaUploader uploader;
  final FirebaseFirestore? _override;
  final FirebaseFunctions _functions;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _rows(String eventId) =>
      _db.collection('events').doc(eventId).collection('timeline');

  @override
  Future<TimelinePage> page(
    String eventId, {
    TimelineStatus status = TimelineStatus.visible,
    String? cursor,
    int limit = 20,
  }) async {
    if (!validEventPathId(eventId)) {
      return const TimelinePage();
    }
    var q = _rows(eventId)
        .where('status', isEqualTo: status.code)
        .orderBy('addedAt', descending: true);
    if (cursor != null) {
      final last = validEventPathId(cursor)
          ? await _rows(eventId).doc(cursor).get()
          : null;
      if (last == null || !last.exists) {
        return const TimelinePage();
      }
      q = q.startAfterDocument(last);
    }
    // One extra row says whether another page exists.
    final snap = await q.limit(limit + 1).get();
    final docs = snap.docs.take(limit).toList();
    return TimelinePage(
      items: [for (final d in docs) ?timelineItemFromFirestore(d.id, d.data())],
      cursor: snap.docs.length > limit && docs.isNotEmpty ? docs.last.id : null,
    );
  }

  @override
  Stream<int> watchPendingCount(String eventId) {
    if (!validEventPathId(eventId)) {
      return Stream.value(0);
    }
    return _rows(eventId)
        .where('status', isEqualTo: TimelineStatus.pending.code)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.length)
        .transform(
          StreamTransformer<int, int>.fromHandlers(
            // A visitor is refused this query; "nothing pending" is the answer.
            handleError: (error, stack, sink) {
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                sink.add(0);
              } else {
                sink.addError(error, stack);
              }
            },
          ),
        );
  }

  @override
  Future<String> share(
    String eventId, {
    required List<PickedImage> images,
    required String caption,
  }) async {
    final me = uid;
    if (me == null) {
      throw const EventError('permission_denied');
    }
    final postId = newUlid();
    final uploaded = <UploadedMedia>[];
    try {
      for (final image in images) {
        final path = 'posts/$me/$postId/${newUlid()}.jpg';
        final media = await uploader
            .upload(image, storagePath: path)
            .lastWhere((e) => e.isDone)
            .then((e) => e.media!);
        uploaded.add(media);
      }
      await callEventFunction(_functions, 'shareEventPost', {
        'eventId': eventId,
        'postId': postId,
        'images': [
          for (final m in uploaded) {'url': m.url, 'path': m.storagePath},
        ],
        'caption': caption,
      });
      return postId;
    } catch (e) {
      // A lost answer may still mean the post landed: its files stay then
      // (an orphan is cheaper than a post with broken photos).
      final code = eventErrorCodeOf(e);
      final ambiguous =
          code == 'network' || code == 'unknown' || code == 'internal';
      if (!ambiguous || uploaded.length < images.length) {
        for (final m in uploaded) {
          try {
            await uploader.delete(m.storagePath);
          } catch (_) {
            // Nothing else depends on a file we could not delete.
          }
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> moderate(
    String eventId,
    String postId,
    TimelineAction action,
  ) async {
    await callEventFunction(_functions, 'moderateEventTimeline', {
      'eventId': eventId,
      'postId': postId,
      'action': action.code,
    });
  }
}
