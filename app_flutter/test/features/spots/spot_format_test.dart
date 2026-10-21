// test/features/spots/spot_format_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/features/spots/spot_format.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  group('spot_format', () {
    test('seasonLabel: [10,11,12] in November → "Đang vào mùa · tới cuối tháng 12"; in March → "Mùa đẹp: tháng 10–12"; [12,1] in May → "Mùa đẹp: tháng 12–1"; [] → "Đẹp quanh năm"', () {
      expect(
        seasonLabel(l, [10, 11, 12], 11),
        'Đang vào mùa · tới cuối tháng 12',
      );
      expect(
        seasonLabel(l, [10, 11, 12], 3),
        'Mùa đẹp: tháng 10–12',
      );
      expect(
        seasonLabel(l, [12, 1], 5),
        'Mùa đẹp: tháng 12–1',
      );
      expect(
        seasonLabel(l, [], 5),
        'Đẹp quanh năm',
      );
    });

    test('spotCardStats → "3 thợ · 1 sự kiện sắp tới"', () {
      const entry = SpotEntry(
        spotId: 's1',
        name: 'Hồ Tây',
        city: 'Hà Nội',
        areaCode: 'hn',
        cardUrl: null,
        lat: 21.05,
        lng: 105.82,
        radiusM: 1000,
        seasonMonths: [10],
        inSeason: true,
        pinned: false,
        hidden: false,
        hotScore: 10,
        openSchedules: 3,
        providersWeek: 3,
        providersWeekend: 3,
        upcomingEvents: 1,
      );

      expect(spotCardStats(l, entry), '3 thợ · 1 sự kiện sắp tới');
    });

    test('spotAvailableLabel → "Có mặt CN 18/10 · 06:00–11:00"', () {
      const window = SpotWindow(start: '06:00', end: '11:00');
      // 2026-10-18 was Sunday (CN)
      expect(
        spotAvailableLabel(l, '2026-10-18', window),
        'Có mặt CN 18/10 · 06:00–11:00',
      );
    });

    test('spotLink produces /spots/:spotId', () {
      expect(spotLink('seed-spot-ho-tay'), '/spots/seed-spot-ho-tay');
    });
  });

  group('schedule labels (S29.03, S29.05)', () {
    test('scheduleWeekdays lists the weekdays Monday first', () {
      expect(
        scheduleWeekdays(['2026-10-11', '2026-10-10', '2026-10-17']),
        'T7, CN',
      );
    });

    test('scheduleDaysLabel: up to three days one by one, else a range', () {
      expect(
        scheduleDaysLabel(l, ['2026-11-01', '2026-10-31']),
        'T7 31/10, CN 01/11',
      );
      expect(
        scheduleDaysLabel(l, [
          '2026-10-10',
          '2026-10-11',
          '2026-10-17',
          '2026-11-15',
        ]),
        'T7, CN · 10/10–15/11',
      );
    });

    test('slotPreviewTimes keeps five, else four and the last', () {
      ({String start, String end}) s(String t) => (start: t, end: t);
      expect(
        slotPreviewTimes([s('06:00'), s('06:40'), s('07:20')]),
        '06:00, 06:40, 07:20',
      );
      expect(
        slotPreviewTimes([
          for (final t in ['06:00', '06:40', '07:20', '08:00', '08:40', '10:00'])
            s(t),
        ]),
        '06:00, 06:40, 07:20, 08:00 … 10:00',
      );
    });
  });
}
