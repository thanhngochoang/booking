// lib/data/events/firestore_event_mapping.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';

DateTime? _date(Object? v) {
  if (v is Timestamp) {
    return v.toDate().toUtc();
  }
  if (v is DateTime) {
    return v.toUtc();
  }
  if (v is String) {
    return DateTime.tryParse(v)?.toUtc();
  }
  return null;
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
int _int(Object? v) => v is num ? v.toInt() : 0;
double? _dbl(Object? v) => v is num ? v.toDouble() : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// `events/{id}` → list row. Null when the document is not an event.
EventSummary? eventSummaryFromFirestore(String id, Map<String, dynamic>? d) {
  if (d == null) {
    return null;
  }
  final title = d['title'];
  if (title is! String) {
    return null;
  }
  final host = _map(d['host']);
  final loc = _map(d['location']);
  final createdAt = _date(d['createdAt']) ?? _epoch;
  final startAt = _date(d['startAt']);
  final hostType = HostType.fromCode(_str(host['type']));
  final lat = _dbl(loc['lat']);
  final lng = _dbl(loc['lng']);
  return EventSummary(
    id: id,
    title: title,
    hostName: hostType == HostType.platform ? '' : _str(host['name']) ?? '',
    hostVerified: host['verified'] == true,
    hostType: hostType,
    hostId: hostType == HostType.platform ? null : _str(host['id']),
    createdBy: _str(d['createdBy']) ?? '',
    type: EventType.fromCode(_str(d['type'])),
    startsAt: startAt ?? createdAt,
    endsAt: _date(d['endAt']),
    hasSchedule: startAt != null,
    locationName: _str(loc['name']),
    geohash: _str(loc['geohash']),
    lat: lat,
    lng: lng,
    priceVnd: _int(d['price']),
    capacity: _int(d['capacity']),
    registeredCount: _int(d['registeredCount']),
    heldCount: _int(d['heldCount']),
    status: EventStatus.fromCode(_str(d['status'])),
    createdAt: createdAt,
    coverUrl: _str(d['coverUrl']),
  );
}

/// `events/{id}` → full event.
EventDetail? eventDetailFromFirestore(String id, Map<String, dynamic>? d) {
  final summary = eventSummaryFromFirestore(id, d);
  if (summary == null || d == null) {
    return null;
  }
  final host = _map(d['host']);
  final loc = _map(d['location']);
  final rawFaq = d['faq'];
  return EventDetail(
    summary: summary,
    description: d['description'] is String ? d['description'] as String : '',
    hashtag: d['hashtag'] is String ? d['hashtag'] as String : '',
    endsAt: _date(d['endAt']) ?? summary.startsAt,
    registrationDeadline: _date(d['registrationDeadline']) ?? summary.startsAt,
    createdBy: summary.createdBy,
    meetingPoint: _str(loc['meetingPoint']),
    hostAvatarUrl: _str(host['avatarUrl']),
    chatId: _str(d['chatId']),
    postCount: _int(d['postCount']),
    completedAt: _date(d['completedAt']),
    faq: rawFaq is List
        ? [
            for (final f in rawFaq)
              if (f is Map) EventFaq.fromJson(f.cast<String, Object?>()),
          ]
        : const [],
    hostConsent: HostConsent.fromCode(_str(d['hostConsent'])),
    hostConsentExpiresAt: _date(d['hostConsentExpiresAt']),
    hashtagLocked: d['hashtagLocked'] == true,
    areaId: _str(loc['areaId']),
    coverPath: _str(d['coverPath']),
    priceSet: d['price'] is num,
    capacitySet: d['capacity'] is num,
    spotId: _str(d['spotId']),
    // The server writes `spotId: null` on every save; a draft only counts as
    // decided once a spot is chosen, a published event once it carries the key.
    spotDecided:
        _str(d['spotId']) != null ||
        (d.containsKey('spotId') && summary.status != EventStatus.draft),
  );
}

/// `events/{id}/registrations/{regId}` → registration. Null when it lacks an
/// event or user.
EventRegistration? registrationFromFirestore(
  String id,
  Map<String, dynamic>? d,
) {
  if (d == null) {
    return null;
  }
  final eventId = _str(d['eventId']);
  final userId = _str(d['userId']);
  final ev = _map(d['event']);
  final createdAt = _date(d['createdAt']);
  if (eventId == null || userId == null || createdAt == null) {
    return null;
  }
  final startsAt = _date(ev['startAt']) ?? createdAt;
  return EventRegistration(
    id: id,
    eventId: eventId,
    userId: userId,
    userName: _str(d['userName']) ?? '',
    ticketCode: _str(d['ticketCode']) ?? '',
    userAvatarUrl: _str(d['userAvatarUrl']),
    paymentId: _str(d['paymentId']),
    quantity: _int(d['quantity']),
    amount: _int(d['amount']),
    status: RegistrationStatus.fromCode(_str(d['status'])),
    holdExpiresAt: _date(d['holdExpiresAt']),
    checkedInAt: _date(d['checkedInAt']),
    cancelledAt: _date(d['cancelledAt']),
    refundPercent: d['refundPercent'] is num
        ? (d['refundPercent'] as num).toInt()
        : null,
    contactEligible: d['contactEligible'] == true,
    refundDue: d['refundDue'] == true,
    refundStatus: TicketRefundStatus.fromCode(_str(d['refundStatus'])),
    event: EventTicketSnapshot(
      title: _str(ev['title']) ?? '',
      type: EventType.fromCode(_str(ev['type'])),
      startsAt: startsAt,
      endsAt: _date(ev['endAt']) ?? startsAt,
      locationName: _str(ev['locationName']),
      lat: _dbl(ev['lat']),
      lng: _dbl(ev['lng']),
      coverUrl: _str(ev['coverUrl']),
    ),
    createdAt: createdAt,
  );
}
