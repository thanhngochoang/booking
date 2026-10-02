// test/features/explore/widgets/event_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

import '../../../core/widgets/widget_host.dart';
import '../../../data/events/nearby_events_repository_test.dart' show event;

void main() {
  testWidgets('shows date block, title, distance and place, price and seats', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        NearbyEventTile(
          event: event(
            'a',
            title: 'Photo walk phố cổ',
            priceVnd: 250000,
            capacity: 20,
            registered: 17,
          ),
          distanceLabel: '1,2 km',
        ),
      ),
    );
    expect(
      find.text('04'),
      findsOneWidget,
      reason: 'Sunday 4 Oct in Vietnam time',
    );
    expect(find.text('T10'), findsOneWidget);
    expect(find.text('Photo walk phố cổ'), findsOneWidget);
    expect(find.text('1,2 km · Công viên Bạch Đằng'), findsOneWidget);
    expect(find.text('250K'), findsOneWidget);
    expect(find.text('Còn 3 chỗ'), findsOneWidget);
    expect(find.text('#photowalk'), findsOneWidget, reason: 'type tag');
  });

  testWidgets('a free event shows the tag and never 0₫', (tester) async {
    await tester.pumpWidget(
      hostWidget(NearbyEventTile(event: event('a', priceVnd: 0))),
    );
    expect(find.text('Không thu phí'), findsOneWidget);
    expect(find.textContaining('0₫'), findsNothing);
  });

  testWidgets('sold out says so in words', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        NearbyEventTile(event: event('a', capacity: 5, registered: 5)),
      ),
    );
    expect(find.text('Hết chỗ'), findsOneWidget);
  });

  testWidgets('tapping calls onTap only when given', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(NearbyEventTile(event: event('a'), onTap: () => taps++)),
    );
    await tester.tap(find.byType(NearbyEventTile));
    expect(taps, 1);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x on ${b.name}', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          NearbyEventTile(
            event: event(
              'a',
              title: 'Workshop ánh sáng tự nhiên buổi sáng sớm',
              priceVnd: 0,
            ),
            distanceLabel: '12,4 km',
          ),
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the row uses the glass card fill', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        NearbyEventTile(event: event('a')),
        brightness: Brightness.light,
      ),
    );
    final m = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(NearbyEventTile),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(m.color, AppColors.glass);
  });
}
