// test/support/event_world.dart
//
// Fixtures for the events data layer: Firestore documents in the shape the
// Functions write, and the matching app models.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// "Now" for event tests: 10 Oct 2026, 03:00 UTC (10:00 in Việt Nam).
final eventNow = DateTime.utc(2026, 10, 10, 3);

Timestamp ts(DateTime d) => Timestamp.fromDate(d);

/// `events/{id}` as the server writes it. Defaults: an open, paid,
/// photographer-hosted photo walk three days ahead.
Map<String, dynamic> eventDoc({
  String title = 'Photo walk phố cổ',
  String status = 'open',
  String type = 'photo_walk',
  int? price = 250000,
  int? capacity = 20,
  int registered = 5,
  int held = 0,
  String hostType = 'photographer',
  String? hostId = 'p1',
  String hostName = 'Quốc Bảo',
  String createdBy = 'p1',
  String? createdByRole,
  DateTime? startAt,
  DateTime? endAt,
  DateTime? createdAt,
  bool schedule = true,
  double lat = 10.78,
  double lng = 106.70,
  String hashtag = 'PhotoWalkPhoCo1013',
  String hostConsent = 'not_required',
  DateTime? hostConsentExpiresAt,
  List<Map<String, String>> faq = const [],
  DateTime? publishedAt,
}) {
  final start = startAt ?? eventNow.add(const Duration(days: 3));
  return {
    'host': {
      'type': hostType,
      'id': hostType == 'platform' ? null : hostId,
      'name': hostType == 'platform' ? null : hostName,
      'avatarUrl': null,
      'verified': hostType != 'platform',
    },
    'hostId': hostType == 'platform' ? null : hostId,
    'createdBy': createdBy,
    'createdByRole': createdByRole ?? 'photographer',
    'hostConsent': hostConsent,
    'hostConsentExpiresAt': hostConsentExpiresAt == null
        ? null
        : ts(hostConsentExpiresAt),
    'title': title,
    'description': 'Đi bộ chụp ảnh khu phố cổ',
    'type': type,
    'coverUrl': 'https://img.test/cover.jpg',
    'coverPath': 'eventCovers/p1/e/cover.jpg',
    'startAt': schedule ? ts(start) : null,
    'endAt': schedule ? ts(endAt ?? start.add(const Duration(hours: 2))) : null,
    'dayKey': '2026-10-13',
    'location': {
      'name': 'Công viên Bạch Đằng',
      'meetingPoint': 'Cổng chính',
      'lat': lat,
      'lng': lng,
      'geohash': encodeGeohash(lat, lng),
      'areaId': null,
    },
    'capacity': capacity,
    'price': price,
    'registrationDeadline': schedule
        ? ts(start.subtract(const Duration(hours: 12)))
        : null,
    'faq': faq,
    'hashtag': hashtag,
    'hashtagKey': hashtag.toLowerCase(),
    'hashtagLocked': false,
    'status': status,
    'registeredCount': registered,
    'heldCount': held,
    'chatId': status == 'draft' ? null : 'event_x',
    'postCount': 2,
    'publishedAt': publishedAt == null ? null : ts(publishedAt),
    'completedAt': null,
    'createdAt': ts(createdAt ?? eventNow.subtract(const Duration(days: 1))),
    'updatedAt': ts(eventNow),
  };
}

/// `events/{id}/registrations/{id}`.
Map<String, dynamic> registrationDoc({
  String eventId = 'ev1',
  String userId = 'u1',
  String userName = 'Lan',
  int quantity = 1,
  int amount = 0,
  String status = 'paid',
  bool contactEligible = false,
  String ticketCode = 'VE-AB2C-1013',
  DateTime? createdAt,
  DateTime? checkedInAt,
}) => {
  'id': 'r-$userId',
  'eventId': eventId,
  'userId': userId,
  'userName': userName,
  'userAvatarUrl': null,
  'quantity': quantity,
  'amount': amount,
  'status': status,
  'holdExpiresAt': null,
  'ticketCode': ticketCode,
  'paymentId': amount > 0 ? 'pay1' : null,
  'contactEligible': contactEligible,
  'checkedInAt': checkedInAt == null ? null : ts(checkedInAt),
  'cancelledAt': null,
  'refundPercent': null,
  'event': {
    'title': 'Photo walk phố cổ',
    'type': 'photo_walk',
    'startAt': ts(eventNow.add(const Duration(days: 3))),
    'endAt': ts(eventNow.add(const Duration(days: 3, hours: 2))),
    'locationName': 'Công viên Bạch Đằng',
    'lat': 10.78,
    'lng': 106.70,
    'coverUrl': 'https://img.test/cover.jpg',
  },
  'createdAt': ts(createdAt ?? eventNow),
  'updatedAt': ts(eventNow),
};

EventSummary summaryOf(
  String id, {
  String title = 'Photo walk',
  HostType hostType = HostType.photographer,
  String? hostId = 'p1',
  String createdBy = 'p1',
  int priceVnd = 250000,
  int capacity = 20,
  int registered = 5,
  int held = 0,
  EventStatus status = EventStatus.open,
  EventType type = EventType.photoWalk,
  Duration startsIn = const Duration(days: 3),
}) => EventSummary(
  id: id,
  title: title,
  hostName: hostType == HostType.platform ? '' : 'Quốc Bảo',
  hostVerified: hostType == HostType.photographer,
  hostType: hostType,
  hostId: hostType == HostType.platform ? null : hostId,
  createdBy: createdBy,
  type: type,
  startsAt: eventNow.add(startsIn),
  endsAt: eventNow.add(startsIn + const Duration(hours: 2)),
  locationName: 'Công viên Bạch Đằng',
  geohash: encodeGeohash(10.78, 106.70),
  lat: 10.78,
  lng: 106.70,
  priceVnd: priceVnd,
  capacity: capacity,
  registeredCount: registered,
  heldCount: held,
  status: status,
  createdAt: eventNow.subtract(const Duration(days: 1)),
  coverUrl: 'https://img.test/cover.jpg',
);

EventDetail detailOf(
  String id, {
  HostType hostType = HostType.photographer,
  String? hostId = 'p1',
  String createdBy = 'p1',
  int priceVnd = 250000,
  int capacity = 20,
  int registered = 5,
  EventStatus status = EventStatus.open,
  HostConsent hostConsent = HostConsent.notRequired,
  DateTime? hostConsentExpiresAt,
  List<EventFaq> faq = const [],
  Duration startsIn = const Duration(days: 3),
}) {
  final s = summaryOf(
    id,
    hostType: hostType,
    hostId: hostId,
    createdBy: createdBy,
    priceVnd: priceVnd,
    capacity: capacity,
    registered: registered,
    status: status,
    startsIn: startsIn,
  );
  return EventDetail(
    summary: s,
    description: 'Đi bộ chụp ảnh',
    hashtag: 'PhotoWalk$id',
    endsAt: s.endsAt!,
    registrationDeadline: s.startsAt.subtract(const Duration(hours: 12)),
    createdBy: createdBy,
    chatId: 'event_$id',
    faq: faq,
    hostConsent: hostConsent,
    hostConsentExpiresAt: hostConsentExpiresAt,
  );
}

EventRegistration registrationOf(
  String id,
  String eventId, {
  String userId = 'u1',
  RegistrationStatus status = RegistrationStatus.paid,
  int quantity = 1,
  int amount = 0,
  bool contactEligible = false,
  DateTime? createdAt,
}) => EventRegistration(
  id: id,
  eventId: eventId,
  userId: userId,
  userName: 'Lan',
  ticketCode: status == RegistrationStatus.paid ? 'VE-AB2C-1013' : '',
  quantity: quantity,
  amount: amount,
  status: status,
  contactEligible: contactEligible,
  event: EventTicketSnapshot(
    title: 'Photo walk',
    type: EventType.photoWalk,
    startsAt: eventNow.add(const Duration(days: 3)),
    endsAt: eventNow.add(const Duration(days: 3, hours: 2)),
  ),
  createdAt: createdAt ?? eventNow,
);
