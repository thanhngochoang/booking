import 'package:flutter/widgets.dart';
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
  int? capacity,
  int? registeredCount,
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
    capacity: capacity,
    registeredCount: registeredCount,
  );
}

void main() {
  testWidgets(
    'row shows date block, title, host · place, tag, price and seats',
    (tester) async {
      final event = _sampleEvent(startsAt: DateTime.utc(2026, 10, 26, 10, 0));

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
    },
  );

  testWidgets('free event shows FreeTag in row and compact, never 0₫', (
    tester,
  ) async {
    final freeEvent = _sampleEvent(priceVnd: 0);

    for (final size in EventCardSize.values) {
      await tester.pumpWidget(
        hostWidget(EventCard(data: freeEvent, size: size)),
      );

      // The featured card shows no price at all (mock S11.01).
      expect(
        find.byType(FreeTag),
        size == EventCardSize.featured ? findsNothing : findsOneWidget,
        reason: 'size: $size',
      );
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

    expect(
      find.text('1,2 km · Minh Trí · Công viên Bạch Đằng'),
      findsOneWidget,
    );
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

  testWidgets(
    'featured matches mock S11.01: overlay lines, light pill top-left with a dot, 16:10',
    (tester) async {
      final event = _sampleEvent(
        title: 'Photo walk phố cổ buổi sớm',
        hostName: 'Quốc Bảo',
        placeName: 'Phố cổ Hà Nội',
        // CN 18/10 06:00 in Việt Nam.
        startsAt: DateTime.utc(2026, 10, 17, 23, 0),
        coverUrl: 'https://example.com/cover.jpg',
        seatsLeft: 6,
        capacity: 20,
        registeredCount: 14,
      );

      await tester.pumpWidget(
        hostWidget(EventCard(data: event, size: EventCardSize.featured)),
      );

      expect(find.text('CN 18/10 · 06:00 · Phố cổ Hà Nội'), findsOneWidget);
      expect(find.text('Photo walk phố cổ buổi sớm'), findsOneWidget);
      expect(find.text('Quốc Bảo · 14/20 đã đăng ký'), findsOneWidget);
      // Price stays on the row cards.
      expect(find.text('600.000₫'), findsNothing);
      final pill = find.byKey(const Key('event-featured-pill'));
      final photoPill = tester.widget<PhotoPill>(pill);
      expect(photoPill.label, 'Còn 6 chỗ');
      expect(photoPill.dot, PhotoPillDot.warn);
      final card = tester.getRect(find.byType(EventCard));
      final pillRect = tester.getRect(pill);
      expect(pillRect.left - card.left, lessThan(card.width / 2));
      expect(card.width / card.height, closeTo(16 / 10, 0.01));
      // Title order: when/where, title, host · registered.
      final when = tester.getRect(find.byKey(const Key('event-featured-when')));
      final title = tester.getRect(find.text('Photo walk phố cổ buổi sớm'));
      final who = tester.getRect(find.byKey(const Key('event-featured-who')));
      expect(when.bottom, lessThanOrEqualTo(title.top));
      expect(title.bottom, lessThanOrEqualTo(who.top));
    },
  );

  testWidgets(
    'featured: distance follows the place; dot green when roomy, red when full',
    (tester) async {
      await tester.pumpWidget(
        hostWidget(
          EventCard(
            data: _sampleEvent(seatsLeft: 15, capacity: 20, registeredCount: 5),
            size: EventCardSize.featured,
            distanceLabel: '2,5 km',
          ),
        ),
      );
      expect(
        find.textContaining('Công viên Bạch Đằng · 2,5 km'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PhotoPill>(find.byKey(const Key('event-featured-pill')))
            .dot,
        PhotoPillDot.ok,
      );

      await tester.pumpWidget(
        hostWidget(
          EventCard(
            data: _sampleEvent(seatsLeft: 0, soldOut: true, capacity: 20),
            size: EventCardSize.featured,
          ),
        ),
      );
      final full = tester.widget<PhotoPill>(
        find.byKey(const Key('event-featured-pill')),
      );
      expect([full.label, full.dot], ['Hết chỗ', PhotoPillDot.bad]);
    },
  );

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
        EventCard(data: event, size: EventCardSize.row, distanceLabel: '800 m'),
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
      hostWidget(EventCard(data: event, onTap: () => tapped = true)),
    );

    await tester.tap(find.byType(EventCard));
    expect(tapped, isTrue);
  });

  testWidgets('skeleton size equal for each size at 390 and 320 dp', (
    tester,
  ) async {
    final event = _sampleEvent(
      title: 'Workshop',
      hostName: 'Trí',
      placeName: 'Quận 1',
    );

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
        final skeletonSize = tester.getSize(
          find.byType(EventCard.skeleton(size: size).runtimeType),
        );

        expect(
          skeletonSize.width,
          realSize.width,
          reason: 'width for $size at $width',
        );
        expect(
          skeletonSize.height,
          closeTo(realSize.height, 2.0),
          reason: 'height for $size at $width',
        );
      }
    }
  });
}
