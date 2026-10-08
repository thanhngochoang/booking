// lib/data/events/firestore_event_timeline_repository.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/events/event_callable.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/events/event_timeline_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Reads the pixel size of a picked image file; null when it cannot be read.
typedef ImageSizeReader = Future<({int w, int h})?> Function(String path);

/// Decodes only the image header (no pixels) to get its size.
Future<({int w, int h})?> readImageSize(String path) async {
  final bytes = await File(path).readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final d = await ui.ImageDescriptor.encoded(buffer);
    final size = (w: d.width, h: d.height);
    d.dispose();
    return size.w > 0 && size.h > 0 ? size : null;
  } finally {
    buffer.dispose();
  }
}

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
    ImageSizeReader? measure,
  }) : _override = db,
       _measure = measure ?? readImageSize,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final String? uid;
  final MediaUploader uploader;
  final ImageSizeReader _measure;
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

  /// Rows the live listener holds; above it the count comes from a `count()`
  /// aggregation (review M12).
  static const pendingWindow = 100;

  @override
  Stream<int> watchPendingCount(String eventId) {
    if (!validEventPathId(eventId)) {
      return Stream.value(0);
    }
    final pending = _rows(eventId)
        .where('status', isEqualTo: TimelineStatus.pending.code);
    // The newest rows are the wake-up (a new row or an approval of a recent
    // one changes them); a full window asks the server for the exact count.
    return pending
        .orderBy('addedAt', descending: true)
        .limit(pendingWindow)
        .snapshots()
        .asyncMap((s) async {
          if (s.docs.length < pendingWindow) {
            return s.docs.length;
          }
          final agg = await pending.count().get();
          return agg.count ?? s.docs.length;
        })
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
    // Width and height let the timeline lay the tile out at its real aspect
    // (review M11); no blur hash, the post publisher does not make one either.
    final sizes = <({int w, int h})?>[];
    try {
      for (final image in images) {
        final path = 'posts/$me/$postId/${newUlid()}.jpg';
        final media = await uploader
            .upload(image, storagePath: path, purpose: ImagePurpose.share)
            .lastWhere((e) => e.isDone)
            .then((e) => e.media!);
        uploaded.add(media);
        sizes.add(await _measureSafely(image));
      }
      await callEventFunction(_functions, 'shareEventPost', {
        'eventId': eventId,
        'postId': postId,
        'images': [
          for (var i = 0; i < uploaded.length; i++)
            {
              'url': uploaded[i].url,
              'path': uploaded[i].storagePath,
              if (sizes[i] != null) 'w': sizes[i]!.w,
              if (sizes[i] != null) 'h': sizes[i]!.h,
            },
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

  Future<({int w, int h})?> _measureSafely(PickedImage image) async {
    try {
      return await _measure(image.path);
    } catch (_) {
      return null; // the tile falls back to the default aspect
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
