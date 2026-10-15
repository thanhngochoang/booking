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

/// Who runs an event: a photographer, or the app itself (staff-created,
/// platform-hosted events have no host id).
enum HostType {
  photographer,
  platform;

  String get code => name;

  static HostType fromCode(String? code) =>
      code == 'photographer' ? HostType.photographer : HostType.platform;
}

/// What a list or card needs to know about an event. The full entity
/// (hashtag, chat, FAQ) is `EventDetail`.
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
    this.hostType = HostType.photographer,
    this.hostId,
    this.endsAt,
    this.createdBy = '',
    this.hasSchedule = true,
    this.locationName,
    this.geohash,
    this.lat,
    this.lng,
    this.coverUrl,
  });

  final String id;
  final String title;

  /// Empty for a platform-hosted event: show the localized platform name.
  final String hostName;
  final bool hostVerified;
  final HostType hostType;

  /// The hosting photographer; null for a platform-hosted event.
  final String? hostId;

  /// Who created it (the host, or the staff member who created it for them).
  final String createdBy;
  final EventType type;

  /// UTC instant. A draft saved before its date was chosen has none: this is
  /// then its creation time and [hasSchedule] is false.
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool hasSchedule;
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
  bool get isPlatformHosted => hostType == HostType.platform;
  int get seatsLeft => math.max(0, capacity - registeredCount - heldCount);
  bool get hasGeo => lat != null && lng != null;
}
