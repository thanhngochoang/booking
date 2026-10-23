// test/data/spots/spot_mapping_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/spots/spot.dart';

void main() {
  group('spotFromMap', () {
    test('spotFromMap reads every field (GeoPoint converted by the adapter into lat/lng before the mapper)', () {
      final map = {
        'name': 'Hồ Tây',
        'city': 'Hà Nội',
        'areaCode': 'hn',
        'point': const GeoPoint(21.05, 105.82),
        'radiusM': 1500,
        'cover': {
          'url': 'https://seed.test/spots/s1/cover.jpg',
          'cardUrl': 'https://seed.test/spots/s1/card.jpg',
        },
        'description': 'Hồ đẹp',
        'tips': ['Mẹo 1', 'Mẹo 2'],
        'seasonMonths': [10, 11, 12],
        'pinned': true,
        'hidden': false,
        'status': 'active',
        'stats': {
          'posts14d': 4,
          'events': 1,
          'bookings14d': 2,
          'openSchedules': 3,
          'providersWeek': 5,
          'providersWeekend': 2,
        },
      };

      final spot = spotFromMap('s1', map);
      expect(spot, isNotNull);
      expect(spot?.id, 's1');
      expect(spot?.name, 'Hồ Tây');
      expect(spot?.city, 'Hà Nội');
      expect(spot?.areaCode, 'hn');
      expect(spot?.lat, 21.05);
      expect(spot?.lng, 105.82);
      expect(spot?.radiusM, 1500);
      expect(spot?.cover?.url, 'https://seed.test/spots/s1/cover.jpg');
      expect(spot?.cover?.cardUrl, 'https://seed.test/spots/s1/card.jpg');
      expect(spot?.description, 'Hồ đẹp');
      expect(spot?.tips, ['Mẹo 1', 'Mẹo 2']);
      expect(spot?.seasonMonths, [10, 11, 12]);
      expect(spot?.pinned, isTrue);
      expect(spot?.hidden, isFalse);
      expect(spot?.archived, isFalse);
      expect(spot?.stats.posts14d, 4);
      expect(spot?.stats.events, 1);
      expect(spot?.stats.bookings14d, 2);
      expect(spot?.stats.openSchedules, 3);
      expect(spot?.stats.providersWeek, 5);
      expect(spot?.stats.providersWeekend, 2);
    });

    test('archived status → archived true', () {
      final map = {
        'name': 'Spot Cũ',
        'status': 'archived',
        'point': const GeoPoint(10.0, 106.0),
      };

      final spot = spotFromMap('s_archived', map);
      expect(spot, isNotNull);
      expect(spot?.archived, isTrue);
    });

    test('unknown status → null', () {
      final map = {
        'name': 'Spot Lạ',
        'status': 'deleted',
      };
      expect(spotFromMap('s_unknown', map), isNull);
    });
  });

  group('spotEntryFromMap', () {
    test('spotEntryFromMap reads a directory entry', () {
      final map = {
        'spotId': 's1',
        'name': 'Đồi chè Cầu Đất',
        'city': 'Đà Lạt',
        'areaCode': 'da-lat',
        'cardUrl': 'https://seed.test/spots/s1/card.jpg',
        'lat': 11.9012,
        'lng': 108.5123,
        'radiusM': 1500,
        'seasonMonths': [10, 11, 12],
        'inSeason': true,
        'pinned': false,
        'hidden': false,
        'hotScore': 25,
        'openSchedules': 2,
        'providersWeek': 3,
        'providersWeekend': 2,
        'upcomingEvents': 1,
      };

      final entry = spotEntryFromMap(map);
      expect(entry, isNotNull);
      expect(entry?.spotId, 's1');
      expect(entry?.name, 'Đồi chè Cầu Đất');
      expect(entry?.city, 'Đà Lạt');
      expect(entry?.areaCode, 'da-lat');
      expect(entry?.cardUrl, 'https://seed.test/spots/s1/card.jpg');
      expect(entry?.lat, 11.9012);
      expect(entry?.lng, 108.5123);
      expect(entry?.radiusM, 1500);
      expect(entry?.seasonMonths, [10, 11, 12]);
      expect(entry?.inSeason, isTrue);
      expect(entry?.pinned, isFalse);
      expect(entry?.hidden, isFalse);
      expect(entry?.hotScore, 25);
      expect(entry?.openSchedules, 2);
      expect(entry?.providersWeek, 3);
      expect(entry?.providersWeekend, 2);
      expect(entry?.upcomingEvents, 1);
    });

    test('spotEntryFromMap returns null when missing required fields', () {
      expect(spotEntryFromMap({}), isNull);
      expect(spotEntryFromMap({'spotId': 's1'}), isNull);
    });
  });

  group('spotScheduleFromMap', () {
    test('spotScheduleFromMap with assigneeId and holderId', () {
      final map = {
        'providerId': 'studio_1',
        'spotId': 's1',
        'assigneeId': 'member_1',
        'days': ['2026-10-10', '2026-10-11'],
        'window': {'start': '06:00', 'end': '11:00'},
        'serviceIds': ['srv_1'],
        'priceFrom': 500000,
        'status': 'open',
      };

      final sched = spotScheduleFromMap('sch_1', map);
      expect(sched, isNotNull);
      expect(sched?.id, 'sch_1');
      expect(sched?.providerId, 'studio_1');
      expect(sched?.assigneeId, 'member_1');
      expect(sched?.holderId, 'member_1');
      expect(sched?.spotId, 's1');
      expect(sched?.days, ['2026-10-10', '2026-10-11']);
      expect(sched?.window.start, '06:00');
      expect(sched?.window.end, '11:00');
      expect(sched?.serviceIds, ['srv_1']);
      expect(sched?.priceFrom, 500000);
      expect(sched?.open, isTrue);

      final individual = spotScheduleFromMap('sch_2', {
        ...map,
        'assigneeId': null,
      });
      expect(individual?.holderId, 'studio_1');
    });

    test('unknown status → null', () {
      final map = {
        'providerId': 'p1',
        'spotId': 's1',
        'window': {'start': '06:00', 'end': '11:00'},
        'status': 'pending',
      };
      expect(spotScheduleFromMap('sch_bad', map), isNull);
    });
  });

  group('slotOfferFromMap', () {
    test('slotOfferFromMap reads open offer', () {
      final map = {
        'providerId': 'p1',
        'scheduleId': 'sch_1',
        'spotId': 's1',
        'name': 'Bình minh Hồ Tây',
        'price': 490000,
        'slotMinutes': 30,
        'gapMinutes': 10,
        'photoCount': 30,
        'editedCount': 10,
        'deliveryDays': 3,
        'status': 'open',
      };

      final offer = slotOfferFromMap('off_1', map);
      expect(offer, isNotNull);
      expect(offer?.id, 'off_1');
      expect(offer?.providerId, 'p1');
      expect(offer?.scheduleId, 'sch_1');
      expect(offer?.spotId, 's1');
      expect(offer?.name, 'Bình minh Hồ Tây');
      expect(offer?.price, 490000);
      expect(offer?.slotMinutes, 30);
      expect(offer?.gapMinutes, 10);
      expect(offer?.photoCount, 30);
      expect(offer?.editedCount, 10);
      expect(offer?.deliveryDays, 3);
      expect(offer?.open, isTrue);
    });

    test('unknown status → null', () {
      final map = {
        'providerId': 'p1',
        'scheduleId': 'sch_1',
        'spotId': 's1',
        'name': 'Gói',
        'status': 'archived',
      };
      expect(slotOfferFromMap('off_bad', map), isNull);
    });
  });

  group('spotDayFromMap', () {
    test('spotDayFromMap with offerId on some intervals', () {
      final map = {
        'scheduleId': 'sch_1',
        'day': '2026-10-10',
        'taken': [
          {'start': '06:00', 'end': '06:30', 'offerId': 'off_1'},
          {'start': '07:00', 'end': '08:00'},
        ],
      };

      final day = spotDayFromMap(map);
      expect(day, isNotNull);
      expect(day?.scheduleId, 'sch_1');
      expect(day?.day, '2026-10-10');
      expect(day?.taken.length, 2);
      expect(day?.taken[0].start, '06:00');
      expect(day?.taken[0].end, '06:30');
      expect(day?.taken[0].offerId, 'off_1');
      expect(day?.taken[1].start, '07:00');
      expect(day?.taken[1].end, '08:00');
      expect(day?.taken[1].offerId, isNull);
    });

    test('spotDayFromMap returns null when missing required fields', () {
      expect(spotDayFromMap(null), isNull);
      expect(spotDayFromMap({'scheduleId': 'sch_1'}), isNull);
    });
  });
}
