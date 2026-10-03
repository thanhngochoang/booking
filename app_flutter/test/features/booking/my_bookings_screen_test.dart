import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/my_bookings_screen.dart';
import 'package:photobooking/features/work/work_screen.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_booking_repository.dart';

/// 11/10 10:00 in Vietnam: the day before the nearest shoot.
final _now = DateTime.utc(2026, 10, 11, 3);

Booking _b(
  String id,
  BookingStatus status, {
  String day = '2026-10-20',
  String start = '09:00',
  int updatedDay = 1,
  String? chatId,
}) => makeTestBooking(
  id: id,
  status: status,
  day: day,
  start: start,
  end: '11:00',
  serviceSnapshot: BookingServiceSnapshot(
    name: 'Gói $id',
    price: 1000000,
    durationMinutes: 120,
  ),
  updatedAt: DateTime.utc(2026, 10, updatedDay, 8),
).copyWith(chatId: chatId);

/// One booking per status (the fake drops drafts itself; see the drafts
/// test for the screen's own filtering).
List<Booking> _mixed({String? nearestChatId}) => [
  _b('a1', BookingStatus.accepted, day: '2026-10-20'),
  _b('u1', BookingStatus.upcoming, day: '2026-10-12', chatId: nearestChatId),
  _b('r1', BookingStatus.requested, day: '2026-10-19'),
  _b('r2', BookingStatus.requested, day: '2026-10-18'),
  _b('c', BookingStatus.completed, updatedDay: 5),
  _b('rv', BookingStatus.reviewed, updatedDay: 4),
  _b('dc', BookingStatus.declined, updatedDay: 6),
  _b('ex', BookingStatus.expired, updatedDay: 3),
  _b('cn', BookingStatus.cancelled, updatedDay: 7),
];

FakeBookingRepository _repo(List<Booking> list) {
  final repo = FakeBookingRepository();
  for (final b in list) {
    repo.seedBooking(b);
  }
  return repo;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedTabs<BookingTab>),
      matching: find.text(label),
    ),
  );
  await _settle(tester);
}

Finder _card(String id) => find.ancestor(
  of: find.text('Minh Trí · Gói $id'),
  matching: find.byType(BookingCard),
);

Finder _codeFinder(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

/// Ids of the cards on screen, top to bottom.
List<String> _ids(WidgetTester tester) {
  final cards = find.byType(BookingCard).evaluate().toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.byWidget(a.widget))
          .dy
          .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
    );
  return [
    for (final c in cards)
      (c.widget as BookingCard).data.serviceName.replaceFirst('Gói ', ''),
  ];
}

List<BookingStatus?> _statuses(WidgetTester tester) => [
  for (final c in tester.widgetList<BookingCard>(find.byType(BookingCard)))
    c.data.status,
];

void main() {
  testWidgets('first load shows BookingCard.skeleton three times', (
    tester,
  ) async {
    final never = StreamController<List<Booking>>();
    addTearDown(never.close);
    await pumpBookingsTab(
      tester,
      now: _now,
      extraOverrides: [
        myBookingsProvider(BookingRole.customer)
            .overrideWith((_) => never.stream),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(_codeFinder(ScreenCodes.bookings), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking_card_skeleton')),
      findsNWidgets(3),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('groups bookings into the three tabs with the right badges', (
    tester,
  ) async {
    await pumpBookingsTab(tester, now: _now, bookings: _repo(_mixed()));
    await _settle(tester);

    expect(_ids(tester), ['u1', 'a1']);
    expect(
      _statuses(tester),
      unorderedEquals([BookingStatus.upcoming, BookingStatus.accepted]),
    );

    await _openTab(tester, 'Đang chờ');
    expect(_ids(tester), ['r2', 'r1']);
    expect(_statuses(tester), everyElement(BookingStatus.requested));

    await _openTab(tester, 'Đã xong');
    expect(_ids(tester), ['cn', 'dc', 'c', 'rv', 'ex']);
    expect(
      find.descendant(
        of: _card('dc'),
        matching: find.byWidgetPredicate(
          (w) => w is StatusBadge && w.status == BookingStatus.declined,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('drafts never appear', (tester) async {
    await pumpBookingsTab(
      tester,
      now: _now,
      extraOverrides: [
        myBookingsProvider(BookingRole.customer).overrideWith(
          (_) => Stream.value([
            _b('d', BookingStatus.draft, day: '2026-10-12'),
            ..._mixed(),
          ]),
        ),
      ],
    );
    await _settle(tester);

    for (final tab in ['Sắp tới', 'Đang chờ', 'Đã xong']) {
      await _openTab(tester, tab);
      expect(_ids(tester), isNot(contains('d')), reason: tab);
      expect(_statuses(tester), isNot(contains(BookingStatus.draft)));
    }
  });

  testWidgets('the nearest upcoming card has Chỉ đường; Nhắn tin only with '
      'the chat flag', (tester) async {
    final handles = await pumpBookingsTab(
      tester,
      now: _now,
      bookings: _repo(_mixed(nearestChatId: 'chat1')),
    );
    await _settle(tester);

    final directions = find.descendant(
      of: _card('u1'),
      matching: find.widgetWithText(AppButton, 'Chỉ đường'),
    );
    expect(directions, findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Chỉ đường'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Nhắn tin'), findsNothing);
    expect(find.byKey(const Key('bookings-chats')), findsNothing);

    await tester.tap(directions);
    await _settle(tester);
    expect(handles.launcher.opened.single.host, 'www.google.com');
    expect(handles.location, '/bookings', reason: 'the card did not open');

    await pumpBookingsTab(
      tester,
      now: _now,
      bookings: _repo(_mixed(nearestChatId: 'chat1')),
      features: const BookingFeatures(
        chat: true,
        reschedule: false,
        review: false,
      ),
    );
    await _settle(tester);
    final message = find.descendant(
      of: _card('u1'),
      matching: find.widgetWithText(AppButton, 'Nhắn tin'),
    );
    expect(message, findsOneWidget);
    expect(find.byKey(const Key('bookings-chats')), findsOneWidget);
  });

  testWidgets('completed cards get Đánh giá only with the review flag', (
    tester,
  ) async {
    await pumpBookingsTab(tester, now: _now, bookings: _repo(_mixed()));
    await _settle(tester);
    await _openTab(tester, 'Đã xong');
    expect(find.widgetWithText(AppButton, 'Đánh giá'), findsNothing);

    final handles = await pumpBookingsTab(
      tester,
      now: _now,
      bookings: _repo(_mixed()),
      features: const BookingFeatures(
        chat: false,
        reschedule: false,
        review: true,
      ),
    );
    await _settle(tester);
    await _openTab(tester, 'Đã xong');
    final review = find.descendant(
      of: _card('c'),
      matching: find.widgetWithText(AppButton, 'Đánh giá'),
    );
    expect(review, findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Đánh giá'), findsOneWidget);

    await tester.tap(review);
    await _settle(tester);
    expect(handles.location, '/b/c/review');
  });

  testWidgets('tapping a card opens /b/:id', (tester) async {
    final handles = await pumpBookingsTab(
      tester,
      now: _now,
      bookings: _repo(_mixed()),
    );
    await _settle(tester);

    await tester.tap(find.text('Minh Trí · Gói a1'));
    await _settle(tester);
    expect(handles.location, '/b/a1');
  });

  testWidgets('each empty tab shows its own message; Sắp tới offers Tìm '
      'nhiếp ảnh gia', (tester) async {
    final handles = await pumpBookingsTab(tester, now: _now);
    await _settle(tester);

    expect(find.text('Chưa có buổi chụp sắp tới'), findsOneWidget);
    await _openTab(tester, 'Đang chờ');
    expect(find.text('Chưa có yêu cầu chờ'), findsOneWidget);
    expect(find.text('Tìm nhiếp ảnh gia'), findsNothing);
    await _openTab(tester, 'Đã xong');
    expect(find.text('Chưa có buổi nào xong'), findsOneWidget);

    await _openTab(tester, 'Sắp tới');
    await tester.tap(find.widgetWithText(AppButton, 'Tìm nhiếp ảnh gia'));
    await _settle(tester);
    expect(handles.location, '/action');
  });

  testWidgets('a new booking arriving on the stream appears without reload', (
    tester,
  ) async {
    final repo = _repo([_b('r1', BookingStatus.requested)]);
    await pumpBookingsTab(tester, now: _now, bookings: repo);
    await _settle(tester);
    await _openTab(tester, 'Đang chờ');
    expect(_ids(tester), ['r1']);

    repo.seedBooking(_b('r3', BookingStatus.requested, day: '2026-10-15'));
    await _settle(tester);
    expect(_ids(tester), ['r3', 'r1']);
  });

  testWidgets('photographers see the work tab (S06.01), not S05.01', (
    tester,
  ) async {
    await pumpBookingsTab(
      tester,
      uid: detailPhotographerUid,
      role: UserRole.photographer,
      now: _now,
      bookings: _repo(_mixed()),
    );
    await _settle(tester);

    expect(_codeFinder(ScreenCodes.bookings), findsNothing);
    expect(find.byType(MyBookingsScreen), findsNothing);
    expect(find.byType(WorkScreen), findsOneWidget);
  });

  testWidgets('320 dp, 1.3×: segmented control and cards fit', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await pumpBookingsTab(
        tester,
        now: _now,
        bookings: _repo(_mixed(nearestChatId: 'chat1')),
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 640),
        features: const BookingFeatures(
          chat: true,
          reschedule: true,
          review: true,
        ),
      );
      await _settle(tester);
      for (final tab in ['Đang chờ', 'Đã xong', 'Sắp tới']) {
        await _openTab(tester, tab);
        expect(tester.takeException(), isNull, reason: '$brightness $tab');
      }
      await _openTab(tester, 'Đang chờ');
      await pumpBookingsTab(
        tester,
        now: _now,
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: '$brightness empty');
    }
  });
}
