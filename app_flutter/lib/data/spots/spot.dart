// lib/data/spots/spot.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/organizer/organizer.dart';

@immutable
class SpotStats {
  const SpotStats({
    required this.posts14d,
    required this.events,
    required this.bookings14d,
    required this.openSchedules,
    required this.providersWeek,
    required this.providersWeekend,
  });

  final int posts14d;
  final int events;
  final int bookings14d;
  final int openSchedules;
  final int providersWeek;
  final int providersWeekend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotStats &&
          runtimeType == other.runtimeType &&
          posts14d == other.posts14d &&
          events == other.events &&
          bookings14d == other.bookings14d &&
          openSchedules == other.openSchedules &&
          providersWeek == other.providersWeek &&
          providersWeekend == other.providersWeekend;

  @override
  int get hashCode => Object.hash(
    posts14d,
    events,
    bookings14d,
    openSchedules,
    providersWeek,
    providersWeekend,
  );
}

@immutable
class SpotCover {
  const SpotCover({required this.url, required this.cardUrl});

  final String url;
  final String cardUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotCover &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          cardUrl == other.cardUrl;

  @override
  int get hashCode => Object.hash(url, cardUrl);
}

@immutable
class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.city,
    required this.areaCode,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.cover,
    required this.description,
    required this.tips,
    required this.seasonMonths,
    required this.pinned,
    required this.hidden,
    required this.archived,
    required this.stats,
    this.managedBy,
    this.access,
    this.openHours,
  });

  final String id;
  final String name;
  final String city;
  final String areaCode;
  final double lat;
  final double lng;
  final int radiusM;
  final SpotCover? cover;
  final String description;
  final List<String> tips;
  final List<int> seasonMonths;
  final bool pinned;
  final bool hidden;
  final bool archived;
  final SpotStats stats;

  /// The organizer that manages the spot (S30, staff-approved claim); null =
  /// nobody, the spot can be claimed.
  final String? managedBy;

  /// The entry fee block of S29.02 "Vào cửa"; null = not known.
  final SpotAccess? access;

  /// Opening hours (Vietnam `HH:mm`); null = not known.
  final OpenHours? openHours;

  bool get isManaged => managedBy != null;

  /// The spot sells or asks for tickets at the gate.
  bool get isTicketed => access?.type == SpotAccessType.ticket;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Spot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          city == other.city &&
          areaCode == other.areaCode &&
          lat == other.lat &&
          lng == other.lng &&
          radiusM == other.radiusM &&
          cover == other.cover &&
          description == other.description &&
          listEquals(tips, other.tips) &&
          listEquals(seasonMonths, other.seasonMonths) &&
          pinned == other.pinned &&
          hidden == other.hidden &&
          archived == other.archived &&
          stats == other.stats &&
          managedBy == other.managedBy &&
          access == other.access &&
          openHours == other.openHours;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    city,
    areaCode,
    lat,
    lng,
    radiusM,
    cover,
    description,
    Object.hashAll(tips),
    Object.hashAll(seasonMonths),
    pinned,
    hidden,
    archived,
    stats,
    managedBy,
    access,
    openHours,
  );
}

@immutable
class SpotEntry {
  const SpotEntry({
    required this.spotId,
    required this.name,
    required this.city,
    required this.areaCode,
    required this.cardUrl,
    required this.lat,
    required this.lng,
    required this.radiusM,
    required this.seasonMonths,
    required this.inSeason,
    required this.pinned,
    required this.hidden,
    required this.hotScore,
    required this.openSchedules,
    required this.providersWeek,
    required this.providersWeekend,
    required this.upcomingEvents,
  });

  final String spotId;
  final String name;
  final String city;
  final String areaCode;
  final String? cardUrl;
  final double lat;
  final double lng;
  final int radiusM;
  final List<int> seasonMonths;
  final bool inSeason;
  final bool pinned;
  final bool hidden;
  final int hotScore;
  final int openSchedules;
  final int providersWeek;
  final int providersWeekend;
  final int upcomingEvents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotEntry &&
          runtimeType == other.runtimeType &&
          spotId == other.spotId &&
          name == other.name &&
          city == other.city &&
          areaCode == other.areaCode &&
          cardUrl == other.cardUrl &&
          lat == other.lat &&
          lng == other.lng &&
          radiusM == other.radiusM &&
          listEquals(seasonMonths, other.seasonMonths) &&
          inSeason == other.inSeason &&
          pinned == other.pinned &&
          hidden == other.hidden &&
          hotScore == other.hotScore &&
          openSchedules == other.openSchedules &&
          providersWeek == other.providersWeek &&
          providersWeekend == other.providersWeekend &&
          upcomingEvents == other.upcomingEvents;

  @override
  int get hashCode => Object.hash(
    spotId,
    name,
    city,
    areaCode,
    cardUrl,
    lat,
    lng,
    radiusM,
    Object.hashAll(seasonMonths),
    inSeason,
    pinned,
    hidden,
    hotScore,
    openSchedules,
    providersWeek,
    providersWeekend,
    upcomingEvents,
  );
}

@immutable
class SpotWindow {
  const SpotWindow({required this.start, required this.end});

  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotWindow &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

@immutable
class SpotSchedule {
  const SpotSchedule({
    required this.id,
    required this.providerId,
    required this.spotId,
    required this.assigneeId,
    required this.days,
    required this.window,
    required this.serviceIds,
    required this.priceFrom,
    required this.open,
  });

  final String id;
  final String providerId;
  final String spotId;
  final String? assigneeId;
  final List<String> days;
  final SpotWindow window;
  final List<String> serviceIds;
  final int? priceFrom;
  final bool open;

  String get holderId => assigneeId ?? providerId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotSchedule &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          providerId == other.providerId &&
          spotId == other.spotId &&
          assigneeId == other.assigneeId &&
          listEquals(days, other.days) &&
          window == other.window &&
          listEquals(serviceIds, other.serviceIds) &&
          priceFrom == other.priceFrom &&
          open == other.open;

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    spotId,
    assigneeId,
    Object.hashAll(days),
    window,
    Object.hashAll(serviceIds),
    priceFrom,
    open,
  );
}

@immutable
class SlotOffer {
  const SlotOffer({
    required this.id,
    required this.providerId,
    required this.scheduleId,
    required this.spotId,
    required this.name,
    required this.price,
    required this.slotMinutes,
    required this.gapMinutes,
    required this.photoCount,
    required this.editedCount,
    required this.deliveryDays,
    required this.open,
  });

  final String id;
  final String providerId;
  final String scheduleId;
  final String spotId;
  final String name;
  final int price;
  final int slotMinutes;
  final int gapMinutes;
  final int photoCount;
  final int editedCount;
  final int deliveryDays;
  final bool open;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotOffer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          providerId == other.providerId &&
          scheduleId == other.scheduleId &&
          spotId == other.spotId &&
          name == other.name &&
          price == other.price &&
          slotMinutes == other.slotMinutes &&
          gapMinutes == other.gapMinutes &&
          photoCount == other.photoCount &&
          editedCount == other.editedCount &&
          deliveryDays == other.deliveryDays &&
          open == other.open;

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    scheduleId,
    spotId,
    name,
    price,
    slotMinutes,
    gapMinutes,
    photoCount,
    editedCount,
    deliveryDays,
    open,
  );
}

@immutable
class SpotInterval {
  const SpotInterval({required this.start, required this.end, this.offerId});

  final String start;
  final String end;
  final String? offerId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotInterval &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          offerId == other.offerId;

  @override
  int get hashCode => Object.hash(start, end, offerId);
}

@immutable
class SpotDay {
  const SpotDay({
    required this.scheduleId,
    required this.day,
    required this.taken,
  });

  final String scheduleId;
  final String day;
  final List<SpotInterval> taken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotDay &&
          runtimeType == other.runtimeType &&
          scheduleId == other.scheduleId &&
          day == other.day &&
          listEquals(taken, other.taken);

  @override
  int get hashCode => Object.hash(scheduleId, day, Object.hashAll(taken));
}

/// Converts Firestore document to [Spot]. Returns null if document is null or status is unknown.
Spot? spotFromMap(String id, Map<String, dynamic>? d) {
  if (d == null) return null;

  final status = d['status'] as String?;
  if (status != 'active' && status != 'archived') return null;

  final name = d['name'] as String?;
  if (name == null || name.isEmpty) return null;

  double lat = 0;
  double lng = 0;
  final point = d['point'];
  if (point is GeoPoint) {
    lat = point.latitude;
    lng = point.longitude;
  } else if (point is Map) {
    lat = (point['lat'] as num?)?.toDouble() ?? 0;
    lng = (point['lng'] as num?)?.toDouble() ?? 0;
  }

  SpotCover? cover;
  final c = d['cover'];
  if (c is Map) {
    cover = SpotCover(
      url: c['url'] as String? ?? '',
      cardUrl: c['cardUrl'] as String? ?? '',
    );
  }

  final tipsList = (d['tips'] as List?)?.whereType<String>().toList() ?? const [];
  final seasonList =
      (d['seasonMonths'] as List?)?.whereType<num>().map((n) => n.toInt()).toList() ??
      const [];

  final st = d['stats'];
  final stats = st is Map
      ? SpotStats(
          posts14d: (st['posts14d'] as num?)?.toInt() ?? 0,
          events: (st['events'] as num?)?.toInt() ?? 0,
          bookings14d: (st['bookings14d'] as num?)?.toInt() ?? 0,
          openSchedules: (st['openSchedules'] as num?)?.toInt() ?? 0,
          providersWeek: (st['providersWeek'] as num?)?.toInt() ?? 0,
          providersWeekend: (st['providersWeekend'] as num?)?.toInt() ?? 0,
        )
      : const SpotStats(
          posts14d: 0,
          events: 0,
          bookings14d: 0,
          openSchedules: 0,
          providersWeek: 0,
          providersWeekend: 0,
        );

  return Spot(
    id: id,
    name: name,
    city: d['city'] as String? ?? '',
    areaCode: d['areaCode'] as String? ?? '',
    lat: lat,
    lng: lng,
    radiusM: (d['radiusM'] as num?)?.toInt() ?? 1000,
    cover: cover,
    description: d['description'] as String? ?? '',
    tips: tipsList,
    seasonMonths: seasonList,
    pinned: d['pinned'] == true,
    hidden: d['hidden'] == true,
    archived: status == 'archived',
    stats: stats,
    managedBy: d['managedBy'] is String && (d['managedBy'] as String).isNotEmpty
        ? d['managedBy'] as String
        : null,
    access: spotAccessFromFirestore(d['access']),
    openHours: openHoursFromFirestore(d['openHours']),
  );
}

/// Converts a directory/ranking entry Map to [SpotEntry].
SpotEntry? spotEntryFromMap(Map<String, dynamic> d) {
  final spotId = d['spotId'] as String?;
  final name = d['name'] as String?;
  if (spotId == null || name == null) return null;

  final seasonList =
      (d['seasonMonths'] as List?)?.whereType<num>().map((n) => n.toInt()).toList() ??
      const [];

  return SpotEntry(
    spotId: spotId,
    name: name,
    city: d['city'] as String? ?? '',
    areaCode: d['areaCode'] as String? ?? '',
    cardUrl: d['cardUrl'] as String?,
    lat: (d['lat'] as num?)?.toDouble() ?? 0,
    lng: (d['lng'] as num?)?.toDouble() ?? 0,
    radiusM: (d['radiusM'] as num?)?.toInt() ?? 1000,
    seasonMonths: seasonList,
    inSeason: d['inSeason'] == true,
    pinned: d['pinned'] == true,
    hidden: d['hidden'] == true,
    hotScore: (d['hotScore'] as num?)?.toInt() ?? 0,
    openSchedules: (d['openSchedules'] as num?)?.toInt() ?? 0,
    providersWeek: (d['providersWeek'] as num?)?.toInt() ?? 0,
    providersWeekend: (d['providersWeekend'] as num?)?.toInt() ?? 0,
    upcomingEvents: (d['upcomingEvents'] as num?)?.toInt() ?? 0,
  );
}

/// Converts Firestore document to [SpotSchedule].
SpotSchedule? spotScheduleFromMap(String id, Map<String, dynamic>? d) {
  if (d == null) return null;

  final status = d['status'] as String?;
  if (status != 'open' && status != 'cancelled') return null;

  final providerId = d['providerId'] as String?;
  final spotId = d['spotId'] as String?;
  final w = d['window'];
  if (providerId == null || spotId == null || w is! Map) return null;

  final start = w['start'] as String?;
  final end = w['end'] as String?;
  if (start == null || end == null) return null;

  final days = (d['days'] as List?)?.whereType<String>().toList() ?? const [];
  final serviceIds =
      (d['serviceIds'] as List?)?.whereType<String>().toList() ?? const [];

  return SpotSchedule(
    id: id,
    providerId: providerId,
    spotId: spotId,
    assigneeId: d['assigneeId'] as String?,
    days: days,
    window: SpotWindow(start: start, end: end),
    serviceIds: serviceIds,
    priceFrom: (d['priceFrom'] as num?)?.toInt(),
    open: status == 'open',
  );
}

/// Converts Firestore document to [SlotOffer].
SlotOffer? slotOfferFromMap(String id, Map<String, dynamic>? d) {
  if (d == null) return null;

  final status = d['status'] as String?;
  if (status != 'open' && status != 'closed') return null;

  final providerId = d['providerId'] as String?;
  final scheduleId = d['scheduleId'] as String?;
  final spotId = d['spotId'] as String?;
  final name = d['name'] as String?;
  if (providerId == null || scheduleId == null || spotId == null || name == null) {
    return null;
  }

  return SlotOffer(
    id: id,
    providerId: providerId,
    scheduleId: scheduleId,
    spotId: spotId,
    name: name,
    price: (d['price'] as num?)?.toInt() ?? 0,
    slotMinutes: (d['slotMinutes'] as num?)?.toInt() ?? 30,
    gapMinutes: (d['gapMinutes'] as num?)?.toInt() ?? 0,
    photoCount: (d['photoCount'] as num?)?.toInt() ?? 0,
    editedCount: (d['editedCount'] as num?)?.toInt() ?? 0,
    deliveryDays: (d['deliveryDays'] as num?)?.toInt() ?? 1,
    open: status == 'open',
  );
}

/// Converts Firestore document to [SpotDay].
SpotDay? spotDayFromMap(Map<String, dynamic>? d) {
  if (d == null) return null;

  final scheduleId = d['scheduleId'] as String?;
  final day = d['day'] as String?;
  if (scheduleId == null || day == null) return null;

  final takenRaw = d['taken'] as List?;
  final taken = <SpotInterval>[];
  if (takenRaw != null) {
    for (final item in takenRaw) {
      if (item is Map) {
        final start = item['start'] as String?;
        final end = item['end'] as String?;
        if (start != null && end != null) {
          taken.add(
            SpotInterval(
              start: start,
              end: end,
              offerId: item['offerId'] as String?,
            ),
          );
        }
      }
    }
  }

  return SpotDay(
    scheduleId: scheduleId,
    day: day,
    taken: taken,
  );
}
