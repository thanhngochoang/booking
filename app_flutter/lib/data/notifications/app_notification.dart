import 'package:flutter/foundation.dart';

/// S17.01 filter bucket stored on each row; the code is the enum name.
enum NotificationTab {
  activity,
  events,
  system;

  /// Unknown or missing codes read as [system].
  static NotificationTab fromCode(Object? code) => NotificationTab.values
      .firstWhere((t) => t.name == code, orElse: () => NotificationTab.system);
}

/// S17.02 row; the code is the enum name.
enum NotificationCategory {
  booking,
  jobs,
  instant,
  events,
  chat,
  badges,
  promo;

  static NotificationCategory? tryParse(Object? code) {
    for (final c in NotificationCategory.values) {
      if (c.name == code) {
        return c;
      }
    }
    return null;
  }
}

@immutable
class NotificationActor {
  const NotificationActor({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.tab,
    required this.category,
    required this.title,
    required this.body,
    required this.target,
    required this.createdAt,
    this.readAt,
    this.actors = const [],
    this.count = 1,
    this.thumbUrl,
  });

  final String id;
  final String type;
  final NotificationTab tab;
  final NotificationCategory category;
  final String title;
  final String body;

  /// An app path (`/b/:id`, `/chat/:id`, ...); the screen checks it against its
  /// allowlist before navigating.
  final String target;
  final DateTime createdAt;
  final DateTime? readAt;
  final List<NotificationActor> actors;
  final int count;
  final String? thumbUrl;

  bool get unread => readAt == null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    tab: tab,
    category: category,
    title: title,
    body: body,
    target: target,
    createdAt: createdAt,
    readAt: readAt ?? at,
    actors: actors,
    count: count,
    thumbUrl: thumbUrl,
  );
}

/// Where the next page starts: the last row's time and id.
@immutable
class NotificationCursor {
  const NotificationCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is NotificationCursor &&
      other.createdAt == createdAt &&
      other.id == id;

  @override
  int get hashCode => Object.hash(createdAt, id);
}

@immutable
class NotificationPage {
  const NotificationPage({
    required this.items,
    this.next,
    this.fromCache = false,
  });

  final List<AppNotification> items;

  /// Null when this was the last page (fewer rows than the limit).
  final NotificationCursor? next;
  final bool fromCache;
}
