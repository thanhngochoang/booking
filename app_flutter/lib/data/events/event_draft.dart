// lib/data/events/event_draft.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// Where the event happens: a named place with a point (from an area or the
/// device position). The server derives the geohash.
@immutable
class EventPlace {
  const EventPlace({
    required this.name,
    required this.lat,
    required this.lng,
    this.meetingPoint,
    this.areaId,
  });

  final String name;
  final double lat;
  final double lng;
  final String? meetingPoint;
  final String? areaId;

  Map<String, Object?> toJson() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'meetingPoint': ?meetingPoint,
    'areaId': ?areaId,
  };

  static EventPlace? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final name = raw['name'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (name is! String || lat is! num || lng is! num) {
      return null;
    }
    return EventPlace(
      name: name,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      meetingPoint: raw['meetingPoint'] as String?,
      areaId: raw['areaId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventPlace &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng &&
      other.meetingPoint == meetingPoint &&
      other.areaId == areaId;

  @override
  int get hashCode => Object.hash(name, lat, lng, meetingPoint, areaId);
}

/// Everything S12.01 and S12.02 collect. Every field is optional because a
/// draft is saved step by step; the server checks completeness at publish.
/// Kept on the device (SharedPreferences, via [toJson] / [fromJson]) while the
/// form is open.
@immutable
class EventDraft {
  const EventDraft({
    this.eventId,
    this.title,
    this.type,
    this.description,
    this.coverUrl,
    this.coverPath,
    this.startsAt,
    this.endsAt,
    this.place,
    this.capacity,
    this.priceVnd,
    this.registrationDeadline,
    this.hashtag,
    this.faq,
    this.hostPhotographerId,
  });

  /// Resume a saved draft in the form.
  factory EventDraft.fromDetail(EventDetail d) {
    final s = d.summary;
    return EventDraft(
      eventId: d.id,
      title: s.title,
      type: s.type,
      description: d.description,
      coverUrl: s.coverUrl,
      coverPath: d.coverPath,
      startsAt: s.hasSchedule ? s.startsAt : null,
      endsAt: s.hasSchedule ? d.endsAt : null,
      place: s.hasGeo && s.locationName != null
          ? EventPlace(
              name: s.locationName!,
              lat: s.lat!,
              lng: s.lng!,
              meetingPoint: d.meetingPoint,
              areaId: d.areaId,
            )
          : null,
      capacity: d.capacitySet ? s.capacity : null,
      priceVnd: d.priceSet ? s.priceVnd : null,
      registrationDeadline: s.hasSchedule ? d.registrationDeadline : null,
      hashtag: d.hashtag,
      faq: d.faq.isEmpty ? null : d.faq,
      hostPhotographerId: s.hostType == HostType.photographer ? s.hostId : null,
    );
  }

  /// The server draft id. The cover is uploaded under it before the first
  /// save, so a new form picks a ULID up front; null lets the server choose.
  final String? eventId;
  final String? title;
  final EventType? type;
  final String? description;
  final String? coverUrl;

  /// Storage path of the cover (`eventCovers/{uid}/{eventId}/{ulid}.jpg`).
  final String? coverPath;

  /// UTC instants.
  final DateTime? startsAt;
  final DateTime? endsAt;
  final EventPlace? place;
  final int? capacity;

  /// Integer VND, a multiple of 1.000; 0 is free.
  final int? priceVnd;
  final DateTime? registrationDeadline;

  /// Without the `#`; null keeps the generated one.
  final String? hashtag;

  /// Staff only, platform-hosted events only.
  final List<EventFaq>? faq;

  /// Staff only: the photographer the draft is created for (owner decision O1).
  final String? hostPhotographerId;

  EventDraft copyWith({
    String? eventId,
    String? title,
    EventType? type,
    String? description,
    String? coverUrl,
    String? coverPath,
    bool clearCover = false,
    DateTime? startsAt,
    DateTime? endsAt,
    EventPlace? place,
    bool clearPlace = false,
    int? capacity,
    int? priceVnd,
    DateTime? registrationDeadline,
    bool clearDeadline = false,
    String? hashtag,
    List<EventFaq>? faq,
    String? hostPhotographerId,
  }) => EventDraft(
    eventId: eventId ?? this.eventId,
    title: title ?? this.title,
    type: type ?? this.type,
    description: description ?? this.description,
    coverUrl: clearCover ? null : (coverUrl ?? this.coverUrl),
    coverPath: clearCover ? null : (coverPath ?? this.coverPath),
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    place: clearPlace ? null : (place ?? this.place),
    capacity: capacity ?? this.capacity,
    priceVnd: priceVnd ?? this.priceVnd,
    registrationDeadline: clearDeadline
        ? null
        : (registrationDeadline ?? this.registrationDeadline),
    hashtag: hashtag ?? this.hashtag,
    faq: faq ?? this.faq,
    hostPhotographerId: hostPhotographerId ?? this.hostPhotographerId,
  );

  /// The `saveEventDraft` payload: only the fields that are filled.
  Map<String, Object?> toCallable() => {
    'eventId': ?eventId,
    'title': ?title,
    'type': ?type?.code,
    'description': ?description,
    'coverUrl': ?coverUrl,
    'coverPath': ?coverPath,
    'startAt': ?startsAt?.toUtc().toIso8601String(),
    'endAt': ?endsAt?.toUtc().toIso8601String(),
    'location': ?place?.toJson(),
    'capacity': ?capacity,
    'price': ?priceVnd,
    'registrationDeadline': ?registrationDeadline?.toUtc().toIso8601String(),
    'hashtag': ?hashtag,
    'faq': ?faq?.map((f) => f.toJson()).toList(),
    'hostPhotographerId': ?hostPhotographerId,
  };

  Map<String, Object?> toJson() => {
    'eventId': ?eventId,
    'title': ?title,
    'type': ?type?.code,
    'description': ?description,
    'coverUrl': ?coverUrl,
    'coverPath': ?coverPath,
    'startsAt': ?startsAt?.toUtc().toIso8601String(),
    'endsAt': ?endsAt?.toUtc().toIso8601String(),
    'place': ?place?.toJson(),
    'capacity': ?capacity,
    'priceVnd': ?priceVnd,
    'registrationDeadline': ?registrationDeadline?.toUtc().toIso8601String(),
    'hashtag': ?hashtag,
    'faq': ?faq?.map((f) => f.toJson()).toList(),
    'hostPhotographerId': ?hostPhotographerId,
  };

  /// Reads what [toJson] wrote; anything unreadable is left empty.
  factory EventDraft.fromJson(Map<String, Object?> json) {
    DateTime? date(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toUtc() : null;
    String? text(Object? v) => v is String ? v : null;
    final rawType = json['type'];
    final rawFaq = json['faq'];
    return EventDraft(
      eventId: text(json['eventId']),
      title: text(json['title']),
      type: rawType is String ? EventType.fromCode(rawType) : null,
      description: text(json['description']),
      coverUrl: text(json['coverUrl']),
      coverPath: text(json['coverPath']),
      startsAt: date(json['startsAt']),
      endsAt: date(json['endsAt']),
      place: EventPlace.fromJson(json['place']),
      capacity: json['capacity'] is num
          ? (json['capacity']! as num).toInt()
          : null,
      priceVnd: json['priceVnd'] is num
          ? (json['priceVnd']! as num).toInt()
          : null,
      registrationDeadline: date(json['registrationDeadline']),
      hashtag: text(json['hashtag']),
      faq: rawFaq is List
          ? [
              for (final f in rawFaq)
                if (f is Map) EventFaq.fromJson(f.cast<String, Object?>()),
            ]
          : null,
      hostPhotographerId: text(json['hostPhotographerId']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventDraft && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}
