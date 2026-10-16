import 'package:flutter/foundation.dart';

@immutable
class MarkerPage<T> {
  const MarkerPage({required this.items, this.cursor});

  final List<T> items;
  final String? cursor;
}

@immutable
class Follower {
  const Follower({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.since,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime since;
}

@immutable
class SocialCounts {
  const SocialCounts({
    this.following = 0,
    this.savedPosts = 0,
    this.savedPhotographers = 0,
  });

  final int following;
  final int savedPosts;
  final int savedPhotographers;

  int get saved => savedPosts + savedPhotographers;
}

/// Serializes a timestamp and docId into an opaque pagination cursor string:
/// `<millis>_<docId>`.
String markerCursor(DateTime createdAt, String docId) =>
    '${createdAt.millisecondsSinceEpoch}_$docId';

/// Parses a pagination cursor string into `(createdAt, docId)`.
/// Returns null if cursor is null, empty, or malformed.
(DateTime, String)? parseMarkerCursor(String? cursor) {
  if (cursor == null || cursor.isEmpty) return null;
  final idx = cursor.indexOf('_');
  if (idx <= 0 || idx >= cursor.length - 1) return null;
  final millis = int.tryParse(cursor.substring(0, idx));
  if (millis == null) return null;
  final docId = cursor.substring(idx + 1);
  return (DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true), docId);
}

/// Preserves the order of [ids] and filters to only those present in [found].
List<T> keepOrder<T>(List<String> ids, Map<String, T> found) {
  final result = <T>[];
  for (final id in ids) {
    final item = found[id];
    if (item != null) {
      result.add(item);
    }
  }
  return result;
}
