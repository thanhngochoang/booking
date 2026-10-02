// lib/data/events/event_summary.dart
import 'dart:math' as math;

import 'package:photobooking/l10n/app_localizations.dart';

enum EventType {
  photoWalk('photo_walk'),
  miniSession('mini_session'),
  workshop('workshop'),
  cosplay('cosplay'),
  other('other');

  const EventType(this.code);
  final String code;

  static EventType fromCode(String? code) =>
      values.firstWhere((t) => t.code == code, orElse: () => EventType.other);
}

extension EventTypeX on EventType {
  /// Type tag as text, e.g. `#minisession`: `#` + the code in lower case
  /// without separators (spec events.md, S11.01 filter row and event rows).
  String get tag => '#${code.replaceAll('_', '')}';

  String label(AppLocalizations l) => switch (this) {
    EventType.photoWalk => l.eventTypePhotoWalk,
    EventType.miniSession => l.eventTypeMiniSession,
    EventType.workshop => l.eventTypeWorkshop,
    EventType.cosplay => l.eventTypeCosplay,
    EventType.other => l.eventTypeOther,
  };
}

enum EventStatus {
  draft,
  open,
  full,
  closed,
  cancelled,
  completed;

  String get code => name;

  static EventStatus fromCode(String? code) => values.firstWhere(
    (s) => s.name == code,
    orElse: () => EventStatus.closed,
  );
}

/// What a list or card needs to know about an event. The full `Event` entity
/// (registrations, hashtag, chat) arrives with the events plan.
class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.hostName,
    required this.hostVerified,
    required this.type,
    required this.startsAt,
    required this.priceVnd,
    required this.capacity,
    required this.registeredCount,
    required this.heldCount,
    required this.status,
    required this.createdAt,
    this.locationName,
    this.geohash,
    this.lat,
    this.lng,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String hostName;
  final bool hostVerified;
  final EventType type;

  /// UTC instant.
  final DateTime startsAt;
  final String? locationName;

  /// Venue geohash (9 characters in storage); null when the event has no geo.
  final String? geohash;
  final double? lat;
  final double? lng;

  /// Integer VND; 0 means free.
  final int priceVnd;
  final int capacity;
  final int registeredCount;
  final int heldCount;
  final EventStatus status;
  final DateTime createdAt;
  final String? coverUrl;

  bool get isFree => priceVnd == 0;
  int get seatsLeft => math.max(0, capacity - registeredCount - heldCount);
  bool get hasGeo => lat != null && lng != null;
}
