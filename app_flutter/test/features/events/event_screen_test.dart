import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/features/events/event_join_bar.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/event_world.dart';
import '../../support/meta_finders.dart';

const _sw = Size(390, 1200);

EventDetail _free(String id, {HostType hostType = HostType.photographer}) =>
    detailOf(id, priceVnd: 0, hostType: hostType);

Finder _byKey(String k) => find.byKey(Key(k));

EventJoinState _state(
  EventDetail e, {
  EventRegistration? reg,
  String uid = 'u1',
  StaffRole? role,
  DateTime? now,
  bool paymentsReady = true,
}) => eventJoinState(
  e,
  reg,
  uid: uid,
  role: role,
  now: now ?? eventNow,
  paymentsReady: paymentsReady,
);

void main() {
  group('eventJoinState', () {
    final open = detailOf('e1');
    test('open event with seats → join', () {
      expect(_state(open), EventJoinState.join);
    });
    test('full → Hết chỗ', () {
      expect(
        _state(detailOf('e1', registered: 20, status: EventStatus.full)),
        EventJoinState.soldOut,
      );
    });
    test('past deadline → Đã đóng đăng ký', () {
      expect(
        _state(
          open,
          now: open.registrationDeadline.add(const Duration(minutes: 1)),
        ),
        EventJoinState.closed,
      );
      expect(
        _state(detailOf('e1', status: EventStatus.closed)),
        EventJoinState.closed,
      );
    });
    test('cancelled → no join, even for a manager', () {
      final c = detailOf('e1', status: EventStatus.cancelled);
      expect(_state(c), EventJoinState.cancelled);
      expect(_state(c, uid: 'p1'), EventJoinState.cancelled);
    });
    test('registered → Xem vé; a held seat counts too', () {
      expect(
        _state(open, reg: registrationOf('r1', 'e1')),
        EventJoinState.viewTicket,
      );
      expect(
        _state(
          open,
          reg: registrationOf('r1', 'e1', status: RegistrationStatus.held),
        ),
        EventJoinState.viewTicket,
      );
      expect(
        _state(
          open,
          reg: registrationOf('r1', 'e1', status: RegistrationStatus.cancelled),
        ),
        EventJoinState.join,
      );
    });
    test('manager → Quản lý (host, admin, own sales)', () {
      expect(_state(open, uid: 'p1'), EventJoinState.manage);
      expect(_state(open, role: StaffRole.admin), EventJoinState.manage);
      final salesEvent = detailOf(
        'e2',
        hostType: HostType.platform,
        createdBy: 'u1',
      );
      expect(_state(salesEvent, role: StaffRole.sales), EventJoinState.manage);
      expect(_state(open, role: StaffRole.sales), EventJoinState.join);
    });
    test('ended → Sự kiện đã kết thúc', () {
      expect(
        _state(open, now: open.endsAt.add(const Duration(minutes: 1))),
        EventJoinState.ended,
      );
      expect(
        _state(detailOf('e1', status: EventStatus.completed)),
        EventJoinState.ended,
      );
    });
    test('a lapsed hold lets the viewer register again', () {
      final lapsed = EventRegistration(
        id: 'r1',
        eventId: 'e1',
        userId: 'u1',
        userName: 'Lan',
        ticketCode: '',
        quantity: 1,
        amount: 250000,
        status: RegistrationStatus.held,
        holdExpiresAt: eventNow.subtract(const Duration(minutes: 1)),
        event: EventTicketSnapshot(
          title: 'Photo walk',
          type: EventType.photoWalk,
          startsAt: open.summary.startsAt,
          endsAt: open.endsAt,
        ),
        createdAt: eventNow,
      );
      expect(
        eventJoinState(
          open,
          lapsed,
          uid: 'u1',
          now: eventNow,
          paymentsReady: true,
        ),
        EventJoinState.join,
      );
    });
    test(
      'paid event before payments → Sắp mở thanh toán; free is not held back',
      () {
        expect(_state(open, paymentsReady: false), EventJoinState.paymentsSoon);
        expect(_state(_free('f'), paymentsReady: false), EventJoinState.join);
      },
    );
  });

  group('S11.02', () {
    testWidgets('shows date, place and capacity before the price', (
      tester,
    ) async {
      final w = EventsWorld(events: [detailOf('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      final when = tester.getTopLeft(_byKey('event-when')).dy;
      final where = tester.getTopLeft(_byKey('event-where')).dy;
      final capacity = tester.getTopLeft(_byKey('event-capacity')).dy;
      final price = tester.getTopLeft(_byKey('event-price')).dy;
      expect(when, lessThan(where));
      expect(where, lessThan(capacity));
      expect(capacity, lessThan(price));
      expect(find.text('5 / 20 đã đăng ký · Còn 15 chỗ'), findsOneWidget);
      expect(
        find.text('Điểm hẹn: Cổng chính'),
        findsNothing,
        reason: 'detailOf has no meeting point',
      );
      expect(find.text('Đăng ký tham gia'), findsOneWidget);
      expect(find.text('250.000₫'), findsOneWidget);
      expect(find.text('mỗi người'), findsOneWidget);
    });

    testWidgets('free event shows the banner and the free tag in the bar', (
      tester,
    ) async {
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.byType(FreeBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(EventJoinBar),
          matching: find.byType(FreeTag),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('0₫'), findsNothing);
      expect(find.text('mỗi người'), findsNothing);
    });

    testWidgets(
      'the price bar shows mỗi người and the join button for paid events',
      (tester) async {
        final w = EventsWorld(events: [detailOf('ev1')]);
        await w.pump(tester, path: '/e/ev1', size: _sw);
        final b = tester.widget<AppButton>(_byKey('event-join'));
        expect(b.label, 'Đăng ký tham gia');
        expect(b.onPressed, isNotNull);
        expect(find.text('Sắp mở thanh toán'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(EventJoinBar),
            matching: find.text('mỗi người'),
          ),
          findsOneWidget,
        );
        await tester.tap(_byKey('event-join'));
        await settle(tester);
        expect(find.text('Thanh toán 250.000₫'), findsOneWidget);
      },
    );

    testWidgets('a build without payments shows a disabled button', (
      tester,
    ) async {
      final w = EventsWorld(events: [detailOf('ev1')]);
      await w.pump(
        tester,
        path: '/e/ev1',
        size: _sw,
        extra: [eventPaymentsReadyProvider.overrideWithValue(false)],
      );
      final b = tester.widget<AppButton>(_byKey('event-join'));
      expect(b.label, 'Sắp mở thanh toán');
      expect(b.onPressed, isNull);
    });

    testWidgets('sold out, closed and ended are text, not buttons', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [detailOf('ev1', registered: 20, status: EventStatus.full)],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(_byKey('event-status-text'), findsOneWidget);
      expect(find.text('Hết chỗ'), findsWidgets);
      expect(_byKey('event-join'), findsNothing);
    });

    testWidgets('cancelled shows the red strip and no join button', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [detailOf('ev1', status: EventStatus.cancelled)],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(_byKey('event-cancelled-strip'), findsOneWidget);
      expect(find.text('Sự kiện đã huỷ'), findsOneWidget);
      expect(_byKey('event-join'), findsNothing);
      expect(find.byType(EventJoinBar), findsNothing);
    });

    testWidgets('registered shows Xem vé and opens the tickets tab', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [_free('ev1')],
        registrations: [registrationOf('r1', 'ev1')],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(_byKey('event-view-ticket'));
      await settle(tester);
      expect(w.location, '/bookings?tab=events&highlight=r1');
    });

    testWidgets('a manager sees Quản lý', (tester) async {
      final w = EventsWorld(events: [detailOf('ev1')], uid: 'p1');
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(_byKey('event-manage'));
      await settle(tester);
      expect(w.location, '/events/ev1/manage');
    });

    testWidgets('no phone sends the user to S04.05 with returnTo', (
      tester,
    ) async {
      final w = EventsWorld(events: [_free('ev1')], contact: null);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(_byKey('event-join'));
      await settle(tester);
      expect(
        w.location,
        '/profile/phone?returnTo=${Uri.encodeComponent('/e/ev1/join')}',
      );
    });

    testWidgets('a photographer-hosted event offers the inquiry chat', (
      tester,
    ) async {
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.text('Quốc Bảo'), findsOneWidget);
      final host = findMeta('Chủ sự kiện · 92%');
      expect(host, findsOneWidget);
      expect(tomatoIconIn(host), findsOneWidget);
      expect(find.byType(VerifiedMark), findsOneWidget);
      await tester.tap(_byKey('event-inquiry'));
      await settle(tester);
      expect(w.location, '/u/p1/ask');
    });

    testWidgets('"Hồ sơ" opens the host profile', (tester) async {
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(_byKey('event-host-profile'));
      await settle(tester);
      expect(w.location, '/u/p1');
    });

    testWidgets('platform event shows Do ứng dụng tổ chức and no inquiry', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [
          detailOf(
            'ev1',
            priceVnd: 0,
            hostType: HostType.platform,
            createdBy: 'staff1',
            faq: const [
              EventFaq(question: 'Mang máy gì?', answer: 'Máy bất kỳ.'),
            ],
          ),
        ],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.text('Do ứng dụng tổ chức'), findsOneWidget);
      expect(find.text('Nhắn tin hỏi trước'), findsNothing);
      expect(_byKey('event-host-profile'), findsNothing);
      expect(find.text('Câu hỏi thường gặp'), findsOneWidget);
      expect(find.text('Mang máy gì?'), findsOneWidget);
      // No support address the project owns yet: the line stays hidden.
      expect(find.textContaining('Gửi email tới'), findsNothing);
    });

    testWidgets('a paid registration turns the inquiry into ContactDial', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [detailOf('ev1')],
        registrations: [
          registrationOf('r1', 'ev1', amount: 250000, contactEligible: true),
        ],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.byType(ContactDial), findsOneWidget);
      expect(_byKey('event-inquiry'), findsNothing);
    });

    testWidgets('a free ticket never unlocks the host contact', (tester) async {
      final w = EventsWorld(
        events: [_free('ev1')],
        registrations: [registrationOf('r1', 'ev1')],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.byType(ContactDial), findsNothing);
      expect(_byKey('event-inquiry'), findsOneWidget);
    });

    testWidgets('chat tab is locked for non-members', (tester) async {
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(find.text('Nhóm chat'));
      await settle(tester);
      expect(find.text('Đăng ký để vào nhóm'), findsOneWidget);
    });

    testWidgets('chat tab opens the group chat for a ticket holder', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [_free('ev1')],
        registrations: [registrationOf('r1', 'ev1')],
      );
      w.chat
        ..setChat(
          const GroupChatThread(
            id: 'event_ev1',
            eventId: 'ev1',
            title: 'Photo walk',
            memberCount: 6,
          ),
        )
        ..setMe(const GroupMemberState(role: GroupRole.member));
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(find.text('Nhóm chat'));
      await settle(tester);
      expect(w.location, '/e/ev1/chat');
      expect(find.text('6 thành viên'), findsOneWidget);
      expect(find.text('Đăng ký để vào nhóm'), findsNothing);
    });

    testWidgets('a manager opens the group chat from the chat tab', (
      tester,
    ) async {
      final w = EventsWorld(events: [_free('ev1')], uid: 'p1');
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(find.text('Nhóm chat'));
      await settle(tester);
      expect(w.location, '/e/ev1/chat');
    });

    testWidgets('an admin who is not in the chat sees the inline panel (M10)', (
      tester,
    ) async {
      final w = EventsWorld(
        events: [_free('ev1')],
        uid: 'ad1',
        staff: StaffRole.admin,
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(find.text('Nhóm chat'));
      await settle(tester);
      expect(w.location, '/e/ev1');
      expect(find.text('Đăng ký để vào nhóm'), findsOneWidget);
    });

    testWidgets('/timeline opens the Timeline tab with its own code', (
      tester,
    ) async {
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(
        find.byWidgetPredicate(
          (x) => x is ScreenCode && x.code == ScreenCodes.eventTimeline,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Chưa có ảnh nào. Hãy là người đầu tiên chia sẻ!'),
        findsOneWidget,
      );
    });

    testWidgets('a draft link shows Sự kiện không còn', (tester) async {
      final w = EventsWorld(
        events: [detailOf('ev1', status: EventStatus.draft)],
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.text('Sự kiện không còn'), findsOneWidget);
      expect(_byKey('event-join'), findsNothing);
    });

    testWidgets('a missing event shows Sự kiện không còn', (tester) async {
      final w = EventsWorld();
      await w.pump(tester, path: '/e/none', size: _sw);
      expect(find.text('Sự kiện không còn'), findsOneWidget);
    });

    testWidgets('a manager still sees their draft', (tester) async {
      final w = EventsWorld(
        events: [detailOf('ev1', status: EventStatus.draft)],
        uid: 'p1',
      );
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(find.text('Sự kiện không còn'), findsNothing);
    });

    testWidgets('Thêm vào lịch and Chỉ đường open the external apps', (
      tester,
    ) async {
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      await tester.tap(find.text('Thêm vào lịch'));
      await settle(tester);
      expect(w.launcher.opened.single.host, 'calendar.google.com');
      await tester.tap(_byKey('event-directions'));
      await settle(tester);
      expect(
        w.launcher.opened.last.queryParameters['destination'],
        '10.78,106.7',
      );
    });

    testWidgets('share copies the link', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final w = EventsWorld(events: [_free('ev1')]);
      await w.pump(tester, path: '/e/ev1', size: _sw);
      expect(_byKey('event-more'), findsOneWidget);
      await tester.tap(_byKey('event-share'));
      await settle(tester);
      expect(copied, '/e/ev1');
      expect(find.text('Đã sao chép liên kết'), findsOneWidget);
    });

    testWidgets('fits 320dp at 1.3 text scale', (tester) async {
      final w = EventsWorld(
        events: [detailOf('ev1', priceVnd: 1500000)],
        registrations: [
          registrationOf('r1', 'ev1', amount: 1500000, contactEligible: true),
        ],
      );
      await w.pump(
        tester,
        path: '/e/ev1',
        size: const Size(320, 700),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('l10n sanity: Không thu phí is the free tag', () {
    expect(AppLocalizationsVi().freeTag, 'Không thu phí');
  });
}
