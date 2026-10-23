// test/data/spots/spot_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/availability_calendar.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_rules.dart';

import '../../support/spot_entry_fixture.dart';

void main() {
  group('regionOfArea & regionForLocation', () {
    test('regionOfArea mirrors the server (hcm-q1 → hcm, hue → hue, null → all)', () {
      expect(regionOfArea('hcm-q1'), 'hcm');
      expect(regionOfArea('hcm-binh-thanh'), 'hcm');
      expect(regionOfArea('hn-hoan-kiem'), 'hn');
      expect(regionOfArea('dn-hai-chau'), 'dn');
      expect(regionOfArea('hue'), 'hue');
      expect(regionOfArea('da-lat'), 'da-lat');
      expect(regionOfArea('nha-trang'), 'nha-trang');
      expect(regionOfArea(null), 'all');
      expect(regionOfArea(''), 'all');
    });

    test('regionForLocation picks the nearest built-in area (21.07, 105.82 → hn)', () {
      expect(regionForLocation(lat: 21.07, lng: 105.82), 'hn');
      expect(regionForLocation(lat: 10.78, lng: 106.69), 'hcm');
      expect(regionForLocation(areaId: 'da-lat'), 'da-lat');
      expect(regionForLocation(), 'all');
    });
  });

  group('seasonRunEnd', () {
    test('seasonRunEnd wraps 12 → 1', () {
      expect(seasonRunEnd([10, 11, 12, 1, 2], 10), 2);
      expect(seasonRunEnd([10, 11, 12, 1, 2], 12), 2);
      expect(seasonRunEnd([10, 11, 12, 1, 2], 1), 2);
      expect(seasonRunEnd([10, 11, 12, 1, 2], 2), 2);
      expect(seasonRunEnd([10, 11, 12, 1, 2], 5), isNull);
      expect(seasonRunEnd([9, 10], 9), 10);
      expect(seasonRunEnd([9, 10], 10), 10);
      expect(seasonRunEnd([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], 5), 4);
    });
  });

  group('slotsFor & freeStartTimes & freeSlots', () {
    const window = SpotWindow(start: '06:00', end: '11:00');

    test('slotsFor matches domain cases (06:00–11:00, 30/10 → 7 slots)', () {
      final slots = slotsFor(window, 30, 10);
      expect(slots.length, 7);
      expect(slots[0], (start: '06:00', end: '06:30'));
      expect(slots[1], (start: '06:40', end: '07:10'));
      expect(slots[2], (start: '07:20', end: '07:50'));
      expect(slots[3], (start: '08:00', end: '08:30'));
      expect(slots[4], (start: '08:40', end: '09:10'));
      expect(slots[5], (start: '09:20', end: '09:50'));
      expect(slots[6], (start: '10:00', end: '10:30'));
    });

    test('freeStartTimes avoids clashes with 15 min gap', () {
      const taken = [
        SpotInterval(start: '07:00', end: '08:00'),
      ];
      // Candidate duration 60m, step 30m
      // 06:00-07:00: ends at 07:00, gap to 07:00 is 0 < 15 => clash!
      // 08:00-09:00: starts at 08:00, gap from 08:00 is 0 < 15 => clash!
      // 08:30-09:30: starts 08:30, gap from 08:00 is 30 >= 15 => free!
      final times = freeStartTimes(window, 60, taken, step: 30);
      expect(times.contains('06:00'), isFalse);
      expect(times.contains('06:30'), isFalse);
      expect(times.contains('07:00'), isFalse);
      expect(times.contains('07:30'), isFalse);
      expect(times.contains('08:00'), isFalse);
      expect(times.contains('08:30'), isTrue);
      expect(times.contains('09:00'), isTrue);
      expect(times.contains('09:30'), isTrue);
      expect(times.contains('10:00'), isTrue);
    });

    test('freeSlots marks taken', () {
      const offer = SlotOffer(
        id: 'off_1',
        providerId: 'p1',
        scheduleId: 'sch_1',
        spotId: 's1',
        name: 'Gói 30 phút',
        price: 490000,
        slotMinutes: 30,
        gapMinutes: 10,
        photoCount: 30,
        editedCount: 10,
        deliveryDays: 3,
        open: true,
      );

      const taken = [
        SpotInterval(start: '06:40', end: '07:10', offerId: 'off_1'),
      ];

      final result = freeSlots(window, offer, taken);
      expect(result.length, 7);
      // 06:00-06:30: same offer, gap is 0, ends 06:30 <= 06:40 diff 10 => free!
      expect(result[0].free, isTrue);
      // 06:40-07:10: exact match => not free
      expect(result[1].free, isFalse);
      // 07:20-07:50: same offer, gap is 0, starts 07:20 >= 07:10 diff 10 => free!
      expect(result[2].free, isTrue);
    });
  });

  group('orderSpots', () {
    SpotEntry makeEntry({
      required String id,
      required String name,
      bool pinned = false,
      bool hidden = false,
      int hotScore = 0,
      List<int> seasonMonths = const [],
      double lat = 21.0,
      double lng = 105.8,
    }) {
      return SpotEntry(
        spotId: id,
        name: name,
        city: 'HN',
        areaCode: 'hn',
        cardUrl: null,
        lat: lat,
        lng: lng,
        radiusM: 1000,
        seasonMonths: seasonMonths,
        inSeason: seasonMonths.isEmpty || seasonMonths.contains(10),
        pinned: pinned,
        hidden: hidden,
        hotScore: hotScore,
        openSchedules: 0,
        providersWeek: 0,
        providersWeekend: 0,
        upcomingEvents: 0,
      );
    }

    test('pinned, then hot in season by score, then the rest by distance from origin; hidden only in the rest', () {
      final sPinned = makeEntry(id: 'pinned', name: 'Z Pinned', pinned: true, hotScore: 5);
      final sHotHigh = makeEntry(id: 'hot_high', name: 'A Hot High', hotScore: 50, seasonMonths: [10]);
      final sHotLow = makeEntry(id: 'hot_low', name: 'B Hot Low', hotScore: 10, seasonMonths: [10]);
      final sOutOfSeason = makeEntry(id: 'out_season', name: 'C Out', hotScore: 40, seasonMonths: [5, 6], lat: 21.05, lng: 105.85);
      final sHidden = makeEntry(id: 'hidden', name: 'D Hidden', hidden: true, hotScore: 99, lat: 21.10, lng: 105.90);
      final sRestNear = makeEntry(id: 'rest_near', name: 'E Near', hotScore: 0, lat: 21.01, lng: 105.81);
      final sRestFar = makeEntry(id: 'rest_far', name: 'F Far', hotScore: 0, lat: 21.50, lng: 106.00);

      final list = [sRestFar, sHidden, sHotLow, sPinned, sOutOfSeason, sHotHigh, sRestNear];
      final ordered = orderSpots(list, month: 10, lat: 21.0, lng: 105.8);

      expect(ordered[0].spotId, 'pinned');
      expect(ordered[1].spotId, 'hot_high');
      expect(ordered[2].spotId, 'hot_low');
      // rest begins: sRestNear is closest to (21.0, 105.8), then sOutOfSeason, sHidden, sRestFar
      expect(ordered[3].spotId, 'rest_near');
      expect(ordered.map((s) => s.spotId).toList(), containsAll(['pinned', 'hot_high', 'hot_low', 'rest_near', 'out_season', 'hidden', 'rest_far']));
      expect(ordered.sublist(0, 3).map((s) => s.spotId).toList(), ['pinned', 'hot_high', 'hot_low']);
    });
  });

  group('expandWeekly', () {
    test('expandWeekly expands weekends within date range', () {
      final days = expandWeekly({6, 7}, '2026-10-08', '2026-10-31');
      // Oct 10, 11, 17, 18, 24, 25, 31 (7 days in Oct)
      expect(days.length, 7);
      expect(days, [
        '2026-10-10',
        '2026-10-11',
        '2026-10-17',
        '2026-10-18',
        '2026-10-24',
        '2026-10-25',
        '2026-10-31',
      ]);

      // If up to Nov 1, it has 8 days
      final eightDays = expandWeekly({6, 7}, '2026-10-08', '2026-11-01');
      expect(eightDays.length, 8);
      expect(eightDays.last, '2026-11-01');
    });
  });

  group('scheduleConflicts', () {
    test('reports booked/pending/off/spot of another schedule; days of the same schedule are free', () {
      final mine = <DateTime, AvailabilityDay>{
        DateTime.utc(2026, 10, 10): AvailabilityDay(
          day: DateTime.utc(2026, 10, 10),
          state: DayState.booked,
        ),
        DateTime.utc(2026, 10, 11): AvailabilityDay(
          day: DateTime.utc(2026, 10, 11),
          state: DayState.pending,
        ),
        DateTime.utc(2026, 10, 12): AvailabilityDay(
          day: DateTime.utc(2026, 10, 12),
          state: DayState.off,
        ),
        DateTime.utc(2026, 10, 13): AvailabilityDay(
          day: DateTime.utc(2026, 10, 13),
          state: DayState.booked,
          scheduleId: 'sch_other',
        ),
        DateTime.utc(2026, 10, 14): AvailabilityDay(
          day: DateTime.utc(2026, 10, 14),
          state: DayState.booked,
          scheduleId: 'sch_mine',
        ),
      };

      final conflicts = scheduleConflicts(
        ['2026-10-10', '2026-10-11', '2026-10-12', '2026-10-13', '2026-10-14', '2026-10-15'],
        mine,
        scheduleId: 'sch_mine',
      );

      expect(conflicts['2026-10-10'], SpotDayConflictReason.booked);
      expect(conflicts['2026-10-11'], SpotDayConflictReason.pending);
      expect(conflicts['2026-10-12'], SpotDayConflictReason.off);
      expect(conflicts['2026-10-13'], SpotDayConflictReason.spot);
      // 2026-10-14 is same schedule => free!
      expect(conflicts.containsKey('2026-10-14'), isFalse);
      // 2026-10-15 has no record => free!
      expect(conflicts.containsKey('2026-10-15'), isFalse);
    });
  });

  group('suggestSpotForPost (S10.01)', () {
    final spots = [
      spotEntryFixture(
        id: 'cau-dat',
        name: 'Đồi chè Cầu Đất',
        lat: 11.85,
        lng: 108.55,
      ),
      spotEntryFixture(id: 'ho-tay', name: 'Hồ Tây'),
      spotEntryFixture(id: 'ho-tay-tay', name: 'Hồ Tây Tây', lat: 10, lng: 106),
    ];

    String? id(String text, {double? lat, double? lng}) => suggestSpotForPost(
      locationText: text,
      lat: lat,
      lng: lng,
      spots: spots,
    )?.spotId;

    test('the spot name inside the text wins, with or without accents', () {
      expect(id('Đồi chè Cầu Đất buổi sáng'), 'cau-dat');
      expect(id('doi che cau dat'), 'cau-dat');
      expect(id('ho tay'), 'ho-tay');
    });

    test('the longest name inside the text wins', () {
      expect(id('Hồ Tây Tây lúc hoàng hôn'), 'ho-tay-tay');
    });

    test('a text inside one name suggests the shortest such name', () {
      expect(id('cau dat'), 'cau-dat');
    });

    test('too short a text or no match suggests nothing', () {
      expect(id(''), isNull);
      expect(id('ho'), isNull);
      expect(id('Quán cà phê'), isNull);
    });

    test(
      'the device position inside a radius is the fallback, nearest first',
      () {
        expect(id('Gần nhà', lat: 21.0502, lng: 105.8203), 'ho-tay');
        expect(id('Gần nhà', lat: 15, lng: 100), isNull);
        // Text still wins over the position.
        expect(id('Cầu Đất', lat: 21.05, lng: 105.82), 'cau-dat');
      },
    );

    test('without a location text there is no suggestion even at the spot', () {
      expect(id('', lat: 21.05, lng: 105.82), isNull);
    });
  });
}
