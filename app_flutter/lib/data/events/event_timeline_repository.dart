// lib/data/events/event_timeline_repository.dart
import 'dart:async';

import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

abstract class EventTimelineRepository {
  /// Rows of the timeline with [status], newest first. Visitors can read
  /// `visible` only; managers read `pending` (and `hidden`) too.
  Future<TimelinePage> page(
    String eventId, {
    TimelineStatus status = TimelineStatus.visible,
    String? cursor,
    int limit = 20,
  });

  /// How many posts wait for approval (managers).
  Stream<int> watchPendingCount(String eventId);

  /// Uploads [images] under `posts/{uid}/{postId}/` and shares them to the
  /// event (`shareEventPost`). Returns the new post id. Files the call left
  /// behind are deleted when it was refused.
  Future<String> share(
    String eventId, {
    required List<PickedImage> images,
    required String caption,
  });

  Future<void> moderate(String eventId, String postId, TimelineAction action);
}

/// In-memory timeline for tests and previews. Mirrors the server: a manager
/// moderates, a share by an attendee is `visible` at once.
class FakeEventTimelineRepository implements EventTimelineRepository {
  FakeEventTimelineRepository({
    Map<String, List<TimelineItem>> items = const {},
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()) {
    items.forEach((id, list) => _items[id] = [...list]);
  }

  final DateTime Function() _clock;
  final Map<String, List<TimelineItem>> _items = {};
  final _changes = StreamController<void>.broadcast();

  /// The author name shared posts carry.
  String authorName = 'Lan Anh';
  String authorId = 'u1';

  /// Set while calls should fail; `failOnce` clears it after one throw.
  Object? failWith;
  bool failOnce = false;

  final List<({String eventId, List<PickedImage> images, String caption})>
  shares = [];
  final List<({String eventId, String postId, TimelineAction action})>
  moderated = [];
  final List<({String eventId, TimelineStatus status, String? cursor})> pages =
      [];

  /// Storage paths a refused share would clean up (the fake only counts).
  int cleanedUp = 0;

  void put(String eventId, List<TimelineItem> items) {
    _items[eventId] = [...items];
    _changes.add(null);
  }

  List<TimelineItem> itemsOf(String eventId) =>
      List.unmodifiable(_items[eventId] ?? const []);

  void _maybeFail() {
    final e = failWith;
    if (e != null) {
      if (failOnce) {
        failWith = null;
      }
      throw e;
    }
  }

  @override
  Future<TimelinePage> page(
    String eventId, {
    TimelineStatus status = TimelineStatus.visible,
    String? cursor,
    int limit = 20,
  }) async {
    pages.add((eventId: eventId, status: status, cursor: cursor));
    _maybeFail();
    final all = [
      for (final i in _items[eventId] ?? const <TimelineItem>[])
        if (i.status == status) i,
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final start = cursor == null
        ? 0
        : all.indexWhere((i) => i.postId == cursor) + 1;
    final slice = all.skip(start).take(limit).toList();
    final more = start + slice.length < all.length;
    return TimelinePage(
      items: slice,
      cursor: more && slice.isNotEmpty ? slice.last.postId : null,
    );
  }

  @override
  Stream<int> watchPendingCount(String eventId) {
    int read() => [
      for (final i in _items[eventId] ?? const <TimelineItem>[])
        if (i.status == TimelineStatus.pending) i,
    ].length;
    late final StreamController<int> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<int>(
      onListen: () {
        controller.add(read());
        sub = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<String> share(
    String eventId, {
    required List<PickedImage> images,
    required String caption,
  }) async {
    shares.add((eventId: eventId, images: images, caption: caption));
    try {
      _maybeFail();
    } catch (_) {
      cleanedUp += images.length;
      rethrow;
    }
    final id = newUlid(now: _clock());
    _items[eventId] = [
      TimelineItem(
        postId: id,
        authorId: authorId,
        authorName: authorName,
        imageUrl: 'https://storage.test/posts/$authorId/$id/0.jpg',
        imageCount: images.length,
        addedAt: _clock(),
      ),
      ...?_items[eventId],
    ];
    _changes.add(null);
    return id;
  }

  @override
  Future<void> moderate(
    String eventId,
    String postId,
    TimelineAction action,
  ) async {
    _maybeFail();
    moderated.add((eventId: eventId, postId: postId, action: action));
    final next = switch (action) {
      TimelineAction.hide => TimelineStatus.hidden,
      TimelineAction.show || TimelineAction.approve => TimelineStatus.visible,
    };
    final list = _items[eventId];
    if (list == null) {
      throw const EventError('not_found');
    }
    _items[eventId] = [
      for (final i in list)
        if (i.postId == postId) i.copyWith(status: next) else i,
    ];
    _changes.add(null);
  }
}
