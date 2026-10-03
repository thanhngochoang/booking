import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/work/work_screen.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';

/// Thursday 08/10 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);

const _copy = BookingContactSnapshot(
  name: 'Lan Anh',
  phone: '+84903123456',
  allowZalo: true,
  allowWhatsApp: false,
);

Booking _b(
  String id,
  BookingStatus status, {
  String day = '2026-10-10',
  String start = '15:30',
  String end = '17:30',
  int deposit = 450000,
  int price = 1500000,
  String service = 'Chân dung 2h',
  String place = 'Bến Bạch Đằng',
  String? note = 'Chụp gia đình 4 người, có bé 2 tuổi.',
  Duration? deadlineIn,
  EscrowStatus? escrow = EscrowStatus.held,
  DateTime? completedAt,
  String? chatId,
}) =>
    makeTestBooking(
      id: id,
      status: status,
      day: day,
      start: start,
      end: end,
      deposit: deposit,
      remaining: price - deposit,
      serviceSnapshot: BookingServiceSnapshot(
        name: service,
        price: price,
        durationMinutes: 120,
      ),
      place: BookingPlace(name: place),
      note: note,
      escrowStatus: escrow,
      completedAt: completedAt,
    ).copyWith(
      acceptDeadline: deadlineIn == null ? null : _now.add(deadlineIn),
      chatId: chatId,
    );

/// Today's shoot, one upcoming, two requests and one done this month.
List<Booking> _busy() => [
  _b(
    't1',
    BookingStatus.accepted,
    day: '2026-10-08',
    start: '14:00',
    end: '18:00',
    deposit: 900000,
    price: 3000000,
    service: 'Kỷ yếu nửa ngày',
    place: 'THPT Lê Quý Đôn',
  ),
  _b('u1', BookingStatus.upcoming, day: '2026-10-15', deposit: 1550000),
  _b('r1', BookingStatus.requested, deadlineIn: const Duration(hours: 22)),
  _b(
    'r2',
    BookingStatus.requested,
    deposit: 300000,
    service: 'Gia đình',
    deadlineIn: const Duration(hours: 5),
  ),
  _b(
    'done',
    BookingStatus.completed,
    day: '2026-10-05',
    price: 12400000,
    escrow: EscrowStatus.released,
    completedAt: DateTime.utc(2026, 10, 5, 12),
  ),
];

RecordingBookingRepository _repo(List<Booking> list) {
  final repo = RecordingBookingRepository();
  for (final b in list) {
    repo.seedBooking(b);
    repo.seedContact(b.id, _copy);
  }
  return repo;
}

Future<BookingsTabHandles> _pump(
  WidgetTester tester,
  FakeRepo repo, {
  TestClock? clock,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) => pumpBookingsTab(
  tester,
  uid: detailPhotographerUid,
  role: UserRole.photographer,
  bookings: repo,
  clock: clock ?? TestClock(_now),
  textScale: textScale,
  viewSize: viewSize,
  portfolioPhotos: 8,
  packages: const [workPackage],
  completeness: 90,
);

typedef FakeRepo = RecordingBookingRepository;

/// S06.01 has no looping loader: pump a bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _codeFinder(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

Finder _acceptButton(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(AppButton));

void main() {
  testWidgets('first load shows BookingCard.skeleton and three '
      'StatTile.skeleton', (tester) async {
    final never = StreamController<List<Booking>>();
    addTearDown(never.close);
    await pumpBookingsTab(
      tester,
      uid: detailPhotographerUid,
      role: UserRole.photographer,
      now: _now,
      extraOverrides: [
        myBookingsProvider(BookingRole.photographer)
            .overrideWith((_) => never.stream),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(WorkScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking_card_skeleton')),
      findsNWidgets(2),
    );
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('stat_tile_skeleton_$i')), findsOneWidget);
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows today\'s shoot card, the requests section with its '
      'count, and the three tiles', (tester) async {
    final handles = await _pump(tester, _repo(_busy()));
    await _settle(tester);

    expect(_codeFinder(ScreenCodes.work), findsOneWidget);
    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Thứ 5, 08/10'), findsOneWidget);
    expect(find.byKey(const Key('open-calendar')), findsOneWidget);

    // Today's shoot: the only highlighted card.
    expect(find.text('Hôm nay'), findsOneWidget);
    final today = tester.widget<BookingCard>(
      find.ancestor(
        of: find.text('Lan Anh · Kỷ yếu nửa ngày'),
        matching: find.byType(BookingCard),
      ),
    );
    expect(today.highlight, isTrue);
    expect(
      tester
          .widgetList<BookingCard>(find.byType(BookingCard))
          .where((c) => c.highlight),
      hasLength(1),
    );
    // Nhắn tin waits for the chat flag; Chỉ đường opens Maps.
    expect(find.text('Nhắn tin'), findsNothing);
    await tester.tap(find.text('Chỉ đường'));
    await _settle(tester);
    expect(handles.launcher.opened.single.host, 'www.google.com');
    expect(
      handles.launcher.opened.single.queryParameters['query'],
      'THPT Lê Quý Đôn',
    );

    // Requests, soonest deadline first, with the count.
    expect(find.text('Yêu cầu mới'), findsOneWidget);
    expect(find.byKey(const Key('work-requests-count')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('work-requests-count'))).data,
      '2',
    );
    expect(find.text('Nhận · còn 5 giờ'), findsOneWidget);
    expect(find.text('Nhận · còn 22 giờ'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Nhận · còn 5 giờ')).dy,
      lessThan(tester.getTopLeft(find.text('Nhận · còn 22 giờ')).dy),
    );
    expect(
      find.text('Chân dung 2h · T7 10/10 15:30 · Bến Bạch Đằng'),
      findsOneWidget,
    );
    expect(find.text('1,5M'), findsNWidgets(2));
    expect(
      find.text('“Chụp gia đình 4 người, có bé 2 tuổi.” · đã cọc 450K'),
      findsOneWidget,
    );
    expect(find.text('Từ chối'), findsNWidgets(2));

    // Tiles: done this month, held deposits, upcoming shoots.
    await tester.scrollUntilVisible(find.text('Tháng này'), 200);
    expect(find.text('12,4M'), findsOneWidget);
    expect(find.text('3,2M'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Đang giữ'), findsOneWidget);
    expect(find.text('Buổi sắp tới'), findsOneWidget);
    expect(find.text('Không có yêu cầu mới'), findsNothing);
  });

  testWidgets('accept calls transitionBooking(accept) and opens S05.02', (
    tester,
  ) async {
    final repo = _repo(_busy());
    final handles = await _pump(tester, repo);
    await _settle(tester);

    await tester.tap(_acceptButton('Nhận · còn 22 giờ'));
    await _settle(tester);

    expect(repo.transitions, [
      (bookingId: 'r1', action: 'accept', reason: null),
    ]);
    expect(handles.location, '/b/r1');
  });

  testWidgets('the countdown shows 22 giờ and switches to seconds in the '
      'last hour', (tester) async {
    final clock = TestClock(_now);
    await _pump(tester, _repo([_busy()[2]]), clock: clock);
    await _settle(tester);
    expect(find.text('Nhận · còn 22 giờ'), findsOneWidget);

    clock.advance(const Duration(hours: 21, minutes: 15));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Nhận · còn 45 phút'), findsOneWidget);

    clock.advance(const Duration(minutes: 44, seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nhận · còn 30 giây'), findsOneWidget);
  });

  testWidgets('accept refused with deadline_passed shows the expired message '
      'and the card leaves', (tester) async {
    final repo = _repo([_busy()[2]]);
    await _pump(tester, repo);
    await _settle(tester);

    repo.nextError = BookingErrorCode.deadlinePassed;
    await tester.tap(_acceptButton('Nhận · còn 22 giờ'));
    await _settle(tester);
    expect(find.text('Yêu cầu đã hết hạn'), findsOneWidget);

    // The server's sweep reaches the stream.
    repo.seedBooking(
      repo.bookings['r1']!.copyWith(status: BookingStatus.expired),
    );
    await _settle(tester);
    expect(find.textContaining('Nhận · còn'), findsNothing);
    expect(
      find.text('Yêu cầu Lan Anh đã hết hạn, đã hoàn cọc'),
      findsOneWidget,
    );
  });

  testWidgets('an expired request disappears with Yêu cầu {tên} đã hết hạn, '
      'đã hoàn cọc', (tester) async {
    final repo = _repo(_busy());
    await _pump(tester, repo);
    await _settle(tester);
    expect(find.textContaining('Nhận · còn'), findsNWidgets(2));

    repo.seedBooking(
      repo.bookings['r2']!.copyWith(status: BookingStatus.expired),
    );
    await _settle(tester);

    expect(find.text('Nhận · còn 5 giờ'), findsNothing);
    expect(find.text('Nhận · còn 22 giờ'), findsOneWidget);
    expect(
      find.text('Yêu cầu Lan Anh đã hết hạn, đã hoàn cọc'),
      findsOneWidget,
    );
  });

  testWidgets('Từ chối opens S06.03; declining shows the toast and the card '
      'leaves', (tester) async {
    final repo = _repo([_busy()[2]]);
    await _pump(tester, repo);
    await _settle(tester);

    await tester.tap(find.text('Từ chối'));
    await _settle(tester);
    expect(find.text('Từ chối yêu cầu của Lan Anh?'), findsOneWidget);
    await tester.tap(find.text('Kín lịch hôm đó'));
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.widgetWithText(AppButton, 'Từ chối'),
      ),
    );
    await _settle(tester);

    expect(repo.transitions, [
      (bookingId: 'r1', action: 'decline', reason: 'Kín lịch hôm đó'),
    ]);
    expect(find.text('Đã từ chối. Lan Anh được hoàn cọc.'), findsOneWidget);
    expect(find.textContaining('Nhận · còn'), findsNothing);
  });

  testWidgets('no requests shows Không có yêu cầu mới', (tester) async {
    await _pump(tester, _repo([_busy()[0]]));
    await _settle(tester);

    expect(find.text('Yêu cầu mới'), findsOneWidget);
    expect(find.text('Không có yêu cầu mới'), findsOneWidget);
    expect(find.textContaining('Nhận · còn'), findsNothing);
  });

  testWidgets('no shoot today hides the today card', (tester) async {
    await _pump(tester, _repo([_busy()[1], _busy()[2]]));
    await _settle(tester);

    expect(find.text('Hôm nay'), findsNothing);
    expect(
      tester
          .widgetList<BookingCard>(find.byType(BookingCard))
          .where((c) => c.highlight),
      isEmpty,
    );
  });

  testWidgets('everything empty shows S06.02', (tester) async {
    // An old completed shoot is not "something happening".
    await _pump(tester, _repo([_busy()[4]]));
    await _settle(tester);

    expect(_codeFinder(ScreenCodes.workEmpty), findsOneWidget);
    expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
    expect(find.text('Yêu cầu mới'), findsNothing);
    expect(find.byType(StatTile), findsNothing);
  });

  testWidgets('320 dp 1.3×: tiles one row, equal height, labels on one line', (
    tester,
  ) async {
    await _pump(
      tester,
      _repo(_busy()),
      textScale: 1.3,
      viewSize: const Size(320, 640),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Buổi sắp tới'), 200);
    await _settle(tester);
    final tiles = find.byType(StatTile);
    expect(tiles, findsNWidgets(3));
    final rects = [for (var i = 0; i < 3; i++) tester.getRect(tiles.at(i))];
    expect(rects.map((r) => r.top).toSet(), hasLength(1));
    expect(rects.map((r) => r.height).toSet(), hasLength(1));
    for (final label in ['Tháng này', 'Đang giữ', 'Buổi sắp tới']) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.didExceedMaxLines, isFalse, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('request contact uses the copy channels', (tester) async {
    final handles = await _pump(tester, _repo([_busy()[2]]));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('contact-dial-button')));
    await _settle(tester);
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('Zalo'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);

    await tester.tap(find.text('Gọi'));
    await _settle(tester);
    expect(handles.launcher.opened, [Uri.parse('tel:+84903123456')]);
  });
}
