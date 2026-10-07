import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/event_world.dart';

EventDetail _event(
  String id, {
  EventType type = EventType.photoWalk,
  int price = 250000,
  EventStatus status = EventStatus.open,
  int startsInDays = 3,
  int registered = 5,
}) {
  final base = detailOf(
    id,
    priceVnd: price,
    status: status,
    registered: registered,
    startsIn: Duration(days: startsInDays),
  );
  return EventDetail(
    summary: EventSummary(
      id: id,
      title: 'Sự kiện $id',
      hostName: 'Quốc Bảo',
      hostVerified: true,
      hostId: 'p1',
      createdBy: 'p1',
      type: type,
      startsAt: base.summary.startsAt,
      endsAt: base.endsAt,
      locationName: 'Công viên Bạch Đằng',
      priceVnd: price,
      capacity: 20,
      registeredCount: status == EventStatus.full ? 20 : registered,
      heldCount: 0,
      status: status,
      createdAt: eventNow,
    ),
    description: '',
    hashtag: 'Tag$id',
    endsAt: base.endsAt,
    registrationDeadline: base.registrationDeadline,
    createdBy: 'p1',
  );
}

List<EventSize> _sizes(WidgetTester t) => [
  for (final c in t.widgetList<EventCard>(find.byType(EventCard)))
    (id: c.data.id, size: c.size),
];

typedef EventSize = ({String id, EventCardSize size});

EventSummary _at(String id, double lat, double lng, int days) => EventSummary(
  id: id,
  title: 'Sự kiện $id',
  hostName: 'Quốc Bảo',
  hostVerified: true,
  hostId: 'p1',
  type: EventType.photoWalk,
  startsAt: eventNow.add(Duration(days: days)),
  endsAt: eventNow.add(Duration(days: days, hours: 2)),
  locationName: 'Công viên',
  geohash: encodeGeohash(lat, lng),
  lat: lat,
  lng: lng,
  priceVnd: 100000,
  capacity: 10,
  registeredCount: 1,
  heldCount: 0,
  status: EventStatus.open,
  createdAt: eventNow,
);

final _tagScroll = find.descendant(
  of: find.byKey(const Key('events-tags')),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets('tags filter by type and keep the choice after back', (
    tester,
  ) async {
    final w = EventsWorld(
      events: [
        _event('walk'),
        _event('shop', type: EventType.workshop, startsInDays: 4),
      ],
    );
    await w.pump(tester);
    expect(find.byType(EventCard), findsNWidgets(2));

    final tag = find.descendant(
      of: find.byKey(const Key('events-tags')),
      matching: find.text('#workshop'),
    );
    await tester.scrollUntilVisible(tag, 100, scrollable: _tagScroll);
    await tester.ensureVisible(tag);
    await tester.pump();
    await tester.tap(tag);
    await settle(tester);
    expect(_sizes(tester).map((e) => e.id), ['shop']);

    await tester.tap(find.byKey(const Key('event-card-shop')));
    await settle(tester);
    expect(w.location, '/e/shop');
    w.router.pop();
    await settle(tester);
    expect(_sizes(tester).map((e) => e.id), ['shop']);
    final shown = find.descendant(
      of: find.byKey(const Key('events-tags')),
      matching: find.text('#workshop'),
    );
    await tester.scrollUntilVisible(shown, 100, scrollable: _tagScroll);
    expect(tester.widget<Text>(shown).style?.fontWeight, FontWeight.w700);
  });

  testWidgets('Không thu phí chip shows only free events', (tester) async {
    final w = EventsWorld(
      events: [_event('paid'), _event('free', price: 0, startsInDays: 4)],
    );
    await w.pump(tester);
    expect(find.byType(EventCard), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('events-free-chip')));
    await settle(tester);
    expect(_sizes(tester).map((e) => e.id), ['free']);
  });

  testWidgets('the first event is featured, the rest are rows', (tester) async {
    final w = EventsWorld(
      events: [
        _event('a'),
        _event('b', startsInDays: 4),
        _event('c', startsInDays: 5),
      ],
    );
    await w.pump(tester);
    expect(_sizes(tester), [
      (id: 'a', size: EventCardSize.featured),
      (id: 'b', size: EventCardSize.row),
      (id: 'c', size: EventCardSize.row),
    ]);
    // Mock S11.01 overlay: host · registered/capacity on the featured card.
    final featured = find.byKey(const Key('event-card-a'));
    expect(
      find.descendant(
        of: featured,
        matching: find.text('Quốc Bảo · 5/20 đã đăng ký'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: featured,
        matching: find.textContaining('· Công viên Bạch Đằng'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a free event shows Không thu phí and no 0₫', (tester) async {
    final w = EventsWorld(
      events: [_event('a', price: 0), _event('b', price: 0, startsInDays: 4)],
    );
    await w.pump(tester);
    expect(find.text('Không thu phí'), findsWidgets);
    expect(find.textContaining('0₫'), findsNothing);
  });

  testWidgets('sold out says Hết chỗ in text and still opens the detail', (
    tester,
  ) async {
    final w = EventsWorld(
      events: [
        _event('a'),
        _event('full', status: EventStatus.full, startsInDays: 4),
      ],
    );
    await w.pump(tester);
    expect(find.text('Hết chỗ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-card-full')));
    await settle(tester);
    expect(w.location, '/e/full');
  });

  testWidgets('Gần tôi sorts by distance and shows the distance', (
    tester,
  ) async {
    final w = EventsWorld(
      events: [_event('far'), _event('near', startsInDays: 4)],
      nearbyEvents: [
        _at('far', 10.85, 106.70, 2),
        _at('near', 10.79, 106.70, 5),
      ],
      areaOrigin: (lat: 10.78, lng: 106.70),
    );
    await w.pump(tester);
    expect(_sizes(tester).map((e) => e.id), ['far', 'near']);
    await tester.tap(find.text('Gần tôi'));
    await settle(tester);
    expect(_sizes(tester).map((e) => e.id), ['near', 'far']);
    expect(find.textContaining('1,1 km'), findsWidgets);
  });

  testWidgets('Gần tôi without an area asks for one', (tester) async {
    final w = EventsWorld(events: [_event('a')]);
    await w.pump(tester);
    await tester.tap(find.text('Gần tôi'));
    await settle(tester);
    expect(find.text('Chọn khu vực để xem sự kiện gần bạn'), findsOneWidget);
  });

  group('empty state', () {
    Future<void> open(WidgetTester tester, EventsWorld w) async {
      await w.pump(tester);
      expect(find.text('Chưa có sự kiện'), findsOneWidget);
    }

    testWidgets('a customer sees no create button', (tester) async {
      await open(tester, EventsWorld());
      expect(find.text('Tạo sự kiện'), findsNothing);
    });

    testWidgets('a photographer with onboarding done sees it', (tester) async {
      await open(
        tester,
        EventsWorld(role: UserRole.photographer, onboardingComplete: true),
      );
      expect(find.text('Tạo sự kiện'), findsOneWidget);
      await tester.tap(find.text('Tạo sự kiện'));
      await settle(tester);
      expect(find.text('stub /events/new'), findsOneWidget);
    });

    testWidgets('a photographer still in setup does not', (tester) async {
      await open(tester, EventsWorld(role: UserRole.photographer));
      expect(find.text('Tạo sự kiện'), findsNothing);
    });

    testWidgets('staff see it', (tester) async {
      await open(tester, EventsWorld(staff: StaffRole.sales));
      expect(find.text('Tạo sự kiện'), findsOneWidget);
    });
  });

  testWidgets('the calendar icon opens tickets for a customer', (tester) async {
    final w = EventsWorld();
    await w.pump(tester);
    await tester.tap(find.byKey(const Key('events-mine')));
    await settle(tester);
    expect(w.location, '/bookings?tab=events');
  });

  testWidgets('the calendar icon opens my events for a manager', (
    tester,
  ) async {
    final w = EventsWorld(staff: StaffRole.admin);
    await w.pump(tester);
    await tester.tap(find.byKey(const Key('events-mine')));
    await settle(tester);
    expect(w.location, '/events/mine');
  });

  testWidgets('two columns from 600dp', (tester) async {
    final w = EventsWorld(
      events: [
        _event('a'),
        _event('b', startsInDays: 4),
        _event('c', startsInDays: 5),
      ],
    );
    await w.pump(tester, size: const Size(800, 900));
    final b = tester.getTopLeft(find.byKey(const Key('event-card-b')));
    final c = tester.getTopLeft(find.byKey(const Key('event-card-c')));
    expect(b.dy, c.dy);
    expect(c.dx, greaterThan(b.dx));
  });

  testWidgets('one column and no overflow at 320dp and 1.3 text scale', (
    tester,
  ) async {
    final w = EventsWorld(
      events: [_event('a'), _event('b', price: 0, startsInDays: 4)],
    );
    await w.pump(tester, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byType(EventCard), findsNWidgets(2));
  });
}
