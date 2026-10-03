import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

EventCardData _sampleEvent({
  String id = 'ev_1',
  String title = 'Mini session mùa thu',
  String hostName = 'Minh Trí',
  bool hostVerified = true,
  String typeTag = '#minisession',
  String typeLabel = 'Mini session',
  DateTime? startsAt,
  String? placeName = 'Công viên Bạch Đằng',
  int priceVnd = 600000,
  int seatsLeft = 3,
  bool soldOut = false,
  String? coverUrl,
}) {
  return EventCardData(
    id: id,
    title: title,
    hostName: hostName,
    hostVerified: hostVerified,
    typeTag: typeTag,
    typeLabel: typeLabel,
    startsAt: startsAt ?? DateTime.utc(2026, 10, 26, 10, 0),
    placeName: placeName,
    priceVnd: priceVnd,
    seatsLeft: seatsLeft,
    soldOut: soldOut,
    coverUrl: coverUrl,
  );
}

void main() {
  testWidgets('row shows date block, title, host · place, tag, price and seats', (
    tester,
  ) async {
    final event = _sampleEvent(
      startsAt: DateTime.utc(2026, 10, 26, 10, 0),
    );

    await tester.pumpWidget(
      hostWidget(EventCard(data: event, size: EventCardSize.row)),
    );

    // DateBlock shows day 26 and month T10
    expect(find.text('26'), findsOneWidget);
    expect(find.text('T10'), findsOneWidget);

    expect(find.text('Mini session mùa thu'), findsOneWidget);
    expect(find.text('Minh Trí · Công viên Bạch Đằng'), findsOneWidget);
    expect(find.text('#minisession'), findsOneWidget);
    expect(find.text('600K'), findsOneWidget);
    expect(find.text('Còn 3 chỗ'), findsOneWidget);
  });

  testWidgets('free event shows FreeTag in row, featured and compact, never 0₫', (
    tester,
  ) async {
    final freeEvent = _sampleEvent(priceVnd: 0);

    for (final size in EventCardSize.values) {
      await tester.pumpWidget(
        hostWidget(EventCard(data: freeEvent, size: size)),
      );

      expect(find.byType(FreeTag), findsOneWidget, reason: 'size: $size');
      expect(find.textContaining('0₫'), findsNothing, reason: 'size: $size');
    }
  });

  testWidgets("sold out reads 'Hết chỗ'", (tester) async {
    final soldOutEvent = _sampleEvent(soldOut: true, seatsLeft: 0);

    await tester.pumpWidget(
      hostWidget(EventCard(data: soldOutEvent, size: EventCardSize.row)),
    );

    expect(find.text('Hết chỗ'), findsOneWidget);
    expect(find.textContaining('Còn'), findsNothing);
  });

  testWidgets('distance label comes first in the place line', (tester) async {
    final event = _sampleEvent();

    await tester.pumpWidget(
      hostWidget(
        EventCard(
          data: event,
          distanceLabel: '1,2 km',
          size: EventCardSize.row,
        ),
      ),
    );

    expect(find.text('1,2 km · Minh Trí · Công viên Bạch Đằng'), findsOneWidget);
  });

  testWidgets(
    'long title at 320 dp and 1.3x wraps without overflow, price column keeps its width',
    (tester) async {
      final longEvent = _sampleEvent(
        title: 'Workshop chụp ảnh ngoại cảnh phong cảnh mùa thu kết hợp chân dung nghệ thuật',
      );

      await tester.pumpWidget(
        hostWidget(
          EventCard(data: longEvent, size: EventCardSize.row),
          width: 320,
          textScale: 1.3,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('600K'), findsOneWidget);
      expect(find.text('Còn 3 chỗ'), findsOneWidget);
    },
  );

  testWidgets('featured shows cover and pill', (tester) async {
    final event = _sampleEvent(
      coverUrl: 'https://example.com/cover.jpg',
      seatsLeft: 5,
    );

    await tester.pumpWidget(
      hostWidget(
        EventCard(
          data: event,
          size: EventCardSize.featured,
          distanceLabel: '2,5 km',
        ),
      ),
    );

    expect(find.text('2,5 km · Còn 5 chỗ'), findsOneWidget);
    expect(find.text('Mini session mùa thu'), findsOneWidget);
    expect(find.text('600.000₫'), findsOneWidget);
  });

  testWidgets('compact is 176 dp wide', (tester) async {
    final event = _sampleEvent();

    await tester.pumpWidget(
      hostWidget(EventCard(data: event, size: EventCardSize.compact)),
    );

    final size = tester.getSize(find.byType(EventCard));
    expect(size.width, 176.0);
  });

  testWidgets('one merged semantics node with the full sentence', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final event = _sampleEvent(
      title: 'Workshop chân dung',
      startsAt: DateTime.utc(2026, 10, 12, 10, 0), // Thứ hai 12/10
      placeName: 'Bến Bạch Đằng',
      priceVnd: 500000,
      seatsLeft: 4,
    );

    await tester.pumpWidget(
      hostWidget(
        EventCard(
          data: event,
          size: EventCardSize.row,
          distanceLabel: '800 m',
        ),
      ),
    );

    // Expected full sentence:
    // "Workshop chân dung, Thứ hai, ngày 12 tháng 10, 800 m, Minh Trí, Bến Bạch Đằng, 500.000₫, Còn 4 chỗ"
    expect(
      find.bySemanticsLabel(
        'Workshop chân dung, Thứ hai, ngày 12 tháng 10, 800 m, Minh Trí, Bến Bạch Đằng, 500.000₫, Còn 4 chỗ',
      ),
      findsOneWidget,
    );

    handle.dispose();
  });

  testWidgets('tap calls onTap', (tester) async {
    var tapped = false;
    final event = _sampleEvent();

    await tester.pumpWidget(
      hostWidget(
        EventCard(
          data: event,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(EventCard));
    expect(tapped, isTrue);
  });

  testWidgets('skeleton size equal for each size at 390 and 320 dp', (
    tester,
  ) async {
    final event = _sampleEvent(title: 'Workshop', hostName: 'Trí', placeName: 'Quận 1');

    for (final width in [390.0, 320.0]) {
      for (final size in EventCardSize.values) {
        await tester.pumpWidget(
          hostWidget(
            EventCard(data: event, size: size),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byType(EventCard));

        await tester.pumpWidget(
          hostWidget(
            AppSkeletonScope(child: EventCard.skeleton(size: size)),
            width: width,
          ),
        );
        final skeletonSize = tester.getSize(find.byType(EventCard.skeleton(size: size).runtimeType));

        expect(skeletonSize.width, realSize.width, reason: 'width for $size at $width');
        expect(skeletonSize.height, closeTo(realSize.height, 2.0), reason: 'height for $size at $width');
      }
    }
  });
}
