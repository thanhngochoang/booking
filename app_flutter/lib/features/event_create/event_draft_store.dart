// lib/features/event_create/event_draft_store.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_summary.dart';

const _keep = Object();

/// One hour offset of Việt Nam time; events are one day in that zone.
const _vnOffset = Duration(hours: 7);

/// Everything S12.01 and S12.02 collect, as the person typed it. Unlike
/// [EventDraft] it can hold a half-filled schedule (a day without a time) or a
/// place name without a point, so the form survives a restart exactly as it
/// was. [toDraft] builds what the server takes.
@immutable
class EventForm {
  const EventForm({
    this.eventId,
    this.title = '',
    this.type,
    this.description = '',
    this.coverUrl,
    this.coverPath,
    this.day,
    this.startMinute,
    this.endMinute,
    this.capacity,
    this.priceVnd,
    this.placeName = '',
    this.meetingPoint = '',
    this.areaId,
    this.lat,
    this.lng,
    this.deadlineDay,
    this.hashtag,
    this.faq,
  });

  /// Resume a server draft in the form.
  factory EventForm.fromDraft(EventDraft d) {
    final start = d.startsAt == null ? null : _vnParts(d.startsAt!);
    final end = d.endsAt == null ? null : _vnParts(d.endsAt!);
    final deadline = d.registrationDeadline == null
        ? null
        : _vnParts(d.registrationDeadline!);
    return EventForm(
      eventId: d.eventId,
      title: d.title ?? '',
      type: d.type,
      description: d.description ?? '',
      coverUrl: d.coverUrl,
      coverPath: d.coverPath,
      day: (start ?? end)?.day,
      startMinute: start?.minute,
      endMinute: end?.minute,
      capacity: d.capacity,
      priceVnd: d.priceVnd,
      placeName: d.place?.name ?? '',
      meetingPoint: d.place?.meetingPoint ?? '',
      areaId: d.place?.areaId,
      lat: d.place?.lat,
      lng: d.place?.lng,
      deadlineDay: deadline?.day,
      hashtag: d.hashtag,
      faq: d.faq,
    );
  }

  /// Server draft id once the first save happened.
  final String? eventId;
  final String title;
  final EventType? type;
  final String description;
  final String? coverUrl;
  final String? coverPath;

  /// A calendar date in Việt Nam, as UTC midnight.
  final DateTime? day;

  /// Minutes since midnight in Việt Nam.
  final int? startMinute;
  final int? endMinute;
  final int? capacity;
  final int? priceVnd;
  final String placeName;
  final String meetingPoint;
  final String? areaId;
  final double? lat;
  final double? lng;

  /// The last day to register (a calendar date in Việt Nam).
  final DateTime? deadlineDay;

  /// Without the `#`; null until the server made one.
  final String? hashtag;

  /// Staff only, platform events (owner decision O2): the questions and
  /// answers as typed, half-filled rows included. Null while the FAQ was
  /// never touched (nothing is sent); an empty list clears it on the server.
  final List<EventFaq>? faq;

  /// The rows with both a question and an answer, trimmed: what is sent.
  List<EventFaq>? get completeFaq => faq == null
      ? null
      : [
          for (final f in faq!)
            if (f.question.trim().isNotEmpty && f.answer.trim().isNotEmpty)
              EventFaq(question: f.question.trim(), answer: f.answer.trim()),
        ];

  /// Some row has a question without an answer, or the other way round.
  bool get hasIncompleteFaq => (faq ?? const <EventFaq>[]).any(
    (f) => f.question.trim().isEmpty != f.answer.trim().isEmpty,
  );

  /// Nothing typed yet: the back button leaves without asking.
  bool get isBlank =>
      title.trim().isEmpty &&
      type == null &&
      description.trim().isEmpty &&
      coverUrl == null &&
      day == null &&
      startMinute == null &&
      endMinute == null &&
      capacity == null &&
      priceVnd == null &&
      placeName.trim().isEmpty &&
      meetingPoint.trim().isEmpty &&
      areaId == null &&
      deadlineDay == null &&
      (faq ?? const <EventFaq>[]).every(
        (f) => f.question.trim().isEmpty && f.answer.trim().isEmpty,
      );

  EventForm copyWith({
    Object? eventId = _keep,
    String? title,
    Object? type = _keep,
    String? description,
    Object? coverUrl = _keep,
    Object? coverPath = _keep,
    Object? day = _keep,
    Object? startMinute = _keep,
    Object? endMinute = _keep,
    Object? capacity = _keep,
    Object? priceVnd = _keep,
    String? placeName,
    String? meetingPoint,
    Object? areaId = _keep,
    Object? lat = _keep,
    Object? lng = _keep,
    Object? deadlineDay = _keep,
    Object? hashtag = _keep,
    List<EventFaq>? faq,
  }) => EventForm(
    eventId: identical(eventId, _keep) ? this.eventId : eventId as String?,
    title: title ?? this.title,
    type: identical(type, _keep) ? this.type : type as EventType?,
    description: description ?? this.description,
    coverUrl: identical(coverUrl, _keep) ? this.coverUrl : coverUrl as String?,
    coverPath: identical(coverPath, _keep)
        ? this.coverPath
        : coverPath as String?,
    day: identical(day, _keep) ? this.day : day as DateTime?,
    startMinute: identical(startMinute, _keep)
        ? this.startMinute
        : startMinute as int?,
    endMinute: identical(endMinute, _keep) ? this.endMinute : endMinute as int?,
    capacity: identical(capacity, _keep) ? this.capacity : capacity as int?,
    priceVnd: identical(priceVnd, _keep) ? this.priceVnd : priceVnd as int?,
    placeName: placeName ?? this.placeName,
    meetingPoint: meetingPoint ?? this.meetingPoint,
    areaId: identical(areaId, _keep) ? this.areaId : areaId as String?,
    lat: identical(lat, _keep) ? this.lat : lat as double?,
    lng: identical(lng, _keep) ? this.lng : lng as double?,
    deadlineDay: identical(deadlineDay, _keep)
        ? this.deadlineDay
        : deadlineDay as DateTime?,
    hashtag: identical(hashtag, _keep) ? this.hashtag : hashtag as String?,
    faq: faq ?? this.faq,
  );

  DateTime? _at(int? minute) => day == null || minute == null
      ? null
      : day!.add(Duration(minutes: minute)).subtract(_vnOffset);

  /// Start and end as UTC instants; null until the day and the time are set.
  DateTime? get startsAt => _at(startMinute);
  DateTime? get endsAt => _at(endMinute);

  /// The registration deadline as an instant: the end of that day, or the
  /// start itself when it is the event day (so "the day of" is allowed).
  DateTime? get registrationDeadline {
    final d = deadlineDay;
    if (d == null) {
      return null;
    }
    final start = startsAt;
    if (start != null && day != null && d == day) {
      return start;
    }
    return d.add(const Duration(hours: 23, minutes: 59)).subtract(_vnOffset);
  }

  /// The `saveEventDraft` payload source. A part the person emptied on a draft
  /// that already exists is sent as an explicit null ([EventDraft.cleared]).
  /// The schedule goes out only when day, start and end are all set.
  EventDraft toDraft({bool withCover = true}) {
    final start = startsAt;
    final end = endsAt;
    final both = start != null && end != null;
    final place = placeName.trim().isNotEmpty && lat != null && lng != null
        ? EventPlace(
            name: placeName.trim(),
            lat: lat!,
            lng: lng!,
            meetingPoint: meetingPoint.trim().isEmpty
                ? null
                : meetingPoint.trim(),
            areaId: areaId,
          )
        : null;
    final deadline = registrationDeadline;
    final cover = withCover ? coverUrl : null;
    final existing = eventId != null;
    return EventDraft(
      eventId: eventId,
      title: title.trim().isEmpty ? null : title.trim(),
      type: type,
      description: description.trim(),
      coverUrl: cover,
      coverPath: withCover ? coverPath : null,
      startsAt: both ? start : null,
      endsAt: both ? end : null,
      place: place,
      capacity: capacity,
      priceVnd: priceVnd,
      registrationDeadline: deadline,
      hashtag: hashtag,
      faq: completeFaq,
      cleared: {
        if (existing && cover == null) 'cover',
        if (existing && place == null) 'place',
        if (existing && deadline == null) 'deadline',
        if (existing && !both) 'schedule',
      },
    );
  }

  Map<String, Object?> toJson() => {
    'eventId': ?eventId,
    'title': title,
    'type': ?type?.code,
    'description': description,
    'coverUrl': ?coverUrl,
    'coverPath': ?coverPath,
    'day': ?day?.toIso8601String(),
    'startMinute': ?startMinute,
    'endMinute': ?endMinute,
    'capacity': ?capacity,
    'priceVnd': ?priceVnd,
    'placeName': placeName,
    'meetingPoint': meetingPoint,
    'areaId': ?areaId,
    'lat': ?lat,
    'lng': ?lng,
    'deadlineDay': ?deadlineDay?.toIso8601String(),
    'hashtag': ?hashtag,
    'faq': ?faq?.map((f) => f.toJson()).toList(),
  };

  /// Reads what [toJson] wrote; anything unreadable is left empty.
  factory EventForm.fromJson(Map<String, Object?> j) {
    String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
    int? integer(Object? v) => v is num ? v.toInt() : null;
    double? real(Object? v) => v is num ? v.toDouble() : null;
    DateTime? date(Object? v) {
      final d = v is String ? DateTime.tryParse(v) : null;
      return d == null ? null : DateTime.utc(d.year, d.month, d.day);
    }

    final rawType = j['type'];
    final rawFaq = j['faq'];
    return EventForm(
      eventId: text(j['eventId']),
      title: j['title'] is String ? j['title']! as String : '',
      type: rawType is String ? EventType.fromCode(rawType) : null,
      description: j['description'] is String
          ? j['description']! as String
          : '',
      coverUrl: text(j['coverUrl']),
      coverPath: text(j['coverPath']),
      day: date(j['day']),
      startMinute: integer(j['startMinute']),
      endMinute: integer(j['endMinute']),
      capacity: integer(j['capacity']),
      priceVnd: integer(j['priceVnd']),
      placeName: j['placeName'] is String ? j['placeName']! as String : '',
      meetingPoint: j['meetingPoint'] is String
          ? j['meetingPoint']! as String
          : '',
      areaId: text(j['areaId']),
      lat: real(j['lat']),
      lng: real(j['lng']),
      deadlineDay: date(j['deadlineDay']),
      hashtag: text(j['hashtag']),
      faq: rawFaq is List
          ? [
              for (final f in rawFaq)
                if (f is Map) EventFaq.fromJson(f.cast<String, Object?>()),
            ]
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventForm && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

({DateTime day, int minute}) _vnParts(DateTime instant) {
  final vn = instant.toUtc().add(_vnOffset);
  return (
    day: DateTime.utc(vn.year, vn.month, vn.day),
    minute: vn.hour * 60 + vn.minute,
  );
}

/// The form kept on the device while it is open, per signed-in user
/// (`eventDraft:<uid>`), so leaving or a restart loses nothing.
class EventDraftStore {
  const EventDraftStore(this._prefs);

  final SharedPreferences _prefs;

  static String key(String uid) => 'eventDraft:$uid';

  EventForm? load(String uid) {
    final raw = _prefs.getString(key(uid));
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      return json is Map
          ? EventForm.fromJson(json.cast<String, Object?>())
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String uid, EventForm form) => form.isBlank
      ? _prefs.remove(key(uid))
      : _prefs.setString(key(uid), jsonEncode(form.toJson()));

  Future<void> clear(String uid) => _prefs.remove(key(uid));
}

/// The stored text of a form (what [EventDraftStore] writes).
@visibleForTesting
abstract final class EventDraftStoreJson {
  static String encode(EventForm form) => jsonEncode(form.toJson());
}

/// Builds the form for a server draft opened from the list.
EventForm eventFormOfDetail(EventDetail d) =>
    EventForm.fromDraft(EventDraft.fromDetail(d));
