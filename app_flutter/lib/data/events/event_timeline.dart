// lib/data/events/event_timeline.dart
import 'package:flutter/foundation.dart';

/// Where a post stands on an event timeline (domain `TimelineStatus`).
enum TimelineStatus {
  visible,
  pending,
  hidden;

  String get code => name;

  static TimelineStatus fromCode(String? code) => values.firstWhere(
    (s) => s.name == code,
    orElse: () => TimelineStatus.pending,
  );
}

/// What a manager does to a row: hide it, show a hidden one, approve a pending one.
enum TimelineAction {
  hide,
  show,
  approve;

  String get code => name;
}

/// One tile of the timeline (S11.05): the first image of a post and who posted it.
@immutable
class TimelineItem {
  const TimelineItem({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.imageUrl,
    this.imageW,
    this.imageH,
    this.imageCount = 1,
    this.isHost = false,
    this.status = TimelineStatus.visible,
    required this.addedAt,
  });

  final String postId;
  final String authorId;
  final String authorName;
  final String imageUrl;
  final int? imageW;
  final int? imageH;
  final int imageCount;

  /// The host or a manager of the event posted it ("· chủ sự kiện").
  final bool isHost;
  final TimelineStatus status;
  final DateTime addedAt;

  /// Height over width, 4:3 portrait when the post did not record its size.
  double get aspect {
    final w = imageW;
    final h = imageH;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return 4 / 3;
    }
    return (h / w).clamp(0.6, 1.8);
  }

  TimelineItem copyWith({TimelineStatus? status}) => TimelineItem(
    postId: postId,
    authorId: authorId,
    authorName: authorName,
    imageUrl: imageUrl,
    imageW: imageW,
    imageH: imageH,
    imageCount: imageCount,
    isHost: isHost,
    status: status ?? this.status,
    addedAt: addedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is TimelineItem &&
      other.postId == postId &&
      other.authorId == authorId &&
      other.authorName == authorName &&
      other.imageUrl == imageUrl &&
      other.imageW == imageW &&
      other.imageH == imageH &&
      other.imageCount == imageCount &&
      other.isHost == isHost &&
      other.status == status &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(
    postId,
    authorId,
    authorName,
    imageUrl,
    imageW,
    imageH,
    imageCount,
    isHost,
    status,
    addedAt,
  );
}

/// One page of the timeline, newest first.
@immutable
class TimelinePage {
  const TimelinePage({this.items = const [], this.cursor});

  final List<TimelineItem> items;

  /// Pass back to the next `page` call; null on the last page.
  final String? cursor;
}
