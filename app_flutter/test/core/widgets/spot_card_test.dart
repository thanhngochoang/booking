// test/core/widgets/spot_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';

import '../../support/screen_host.dart';

void main() {
  const inSeasonEntry = SpotEntry(
    spotId: 's1',
    name: 'Đồi chè Cầu Đất',
    city: 'Đà Lạt',
    areaCode: 'da-lat',
    cardUrl: 'https://test/caudat.jpg',
    lat: 11.9,
    lng: 108.5,
    radiusM: 1500,
    seasonMonths: [10, 11, 12],
    inSeason: true,
    pinned: false,
    hidden: false,
    hotScore: 50,
    openSchedules: 6,
    providersWeek: 6,
    providersWeekend: 6,
    upcomingEvents: 2,
  );

  const outOfSeasonEntry = SpotEntry(
    spotId: 's2',
    name: 'Đồi hoa mận',
    city: 'Mộc Châu',
    areaCode: 'moc-chau',
    cardUrl: null,
    lat: 20.8,
    lng: 104.6,
    radiusM: 2000,
    seasonMonths: [2, 3],
    inSeason: false,
    pinned: false,
    hidden: false,
    hotScore: 10,
    openSchedules: 0,
    providersWeek: 0,
    providersWeekend: 0,
    upcomingEvents: 0,
  );

  group('SpotCard', () {
    testWidgets('shows name, city, season tag only in season, providers line', (tester) async {
      await tester.pumpWidget(
        screenApp(
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SpotCard(entry: inSeasonEntry, variant: SpotCardVariant.large),
                  SpotCard(entry: outOfSeasonEntry, variant: SpotCardVariant.large),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đồi chè Cầu Đất'), findsOneWidget);
      expect(find.text('Đồi hoa mận'), findsOneWidget);
      expect(find.textContaining('Đà Lạt'), findsOneWidget);
      expect(find.textContaining('Mộc Châu'), findsOneWidget);

      // SeasonTag only appears for inSeasonEntry
      expect(find.byType(SeasonTag), findsOneWidget);

      // Providers line / stats
      expect(find.textContaining('6 thợ'), findsOneWidget);
    });

    testWidgets('320 dp and text scale 1.3 without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        screenApp(
          textScale: 1.3,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SpotCard(entry: inSeasonEntry, variant: SpotCardVariant.large),
                  SpotCard(entry: inSeasonEntry, variant: SpotCardVariant.horizontal),
                  SpotCard(entry: inSeasonEntry, variant: SpotCardVariant.tile),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark and light mode without error', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          screenApp(
            brightness: brightness,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SpotCard(entry: inSeasonEntry),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Đồi chè Cầu Đất'), findsOneWidget);
      }
    });
  });
}
