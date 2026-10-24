import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/features/booking/booking_features.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';

/// Shoot on Monday 12/10 15:30–19:30 Vietnam (08:30 UTC); the studio must
/// name the photographer by Sunday 11/10 15:30 (08:30 UTC).
final _deadline = DateTime.utc(2026, 10, 11, 8, 30);

/// Saturday 03/10 17:00 Vietnam: a week ahead.
final _weekBefore = DateTime.utc(2026, 10, 3, 10);

/// Sunday 11/10 16:00 Vietnam: past the deadline, before the shoot.
final _afterDeadline = DateTime.utc(2026, 10, 11, 9);

/// Monday 12/10 16:00 Vietnam: the shoot has started.
final _afterStart = DateTime.utc(2026, 10, 12, 9);

const _studio = PhotographerProfile(
  summary: PhotographerSummary(
    id: 'cuc',
    displayName: 'Studio Mây',
    verified: true,
    businessVerified: true,
    acceptingOrders: true,
    providerType: ProviderType.studio,
    memberCount: 3,
  ),
  intro: PhotographerIntro(onboardingComplete: true),
);

const _member = PhotographerProfile(
  summary: PhotographerSummary(
    id: 'minh',
    displayName: 'Minh Trí',
    verified: true,
    acceptingOrders: true,
    reviewCount: 30,
    tomatoCount: 29,
    brickCount: 1,
    tomatoPct: 97,
    completedCount: 112,
  ),
  intro: PhotographerIntro(onboardingComplete: true),
);

const _profiles = {'cuc': _studio, 'minh': _member};

const _chatOn = BookingFeatures(chat: true, reschedule: false, review: false);

Booking _booking({
  BookingStatus status = BookingStatus.accepted,
  String? assignee,
  StudioChangeRequest? change,
  StudioFault? fault,
  List<String> reminders = const [],
  DateTime? createdAt,
}) =>
    makeTestBooking(
      id: 'b1',
      photographerId: 'cuc',
      status: status,
      day: '2026-10-12',
      start: '15:30',
      end: '19:30',
      deposit: 8000000,
      serviceSnapshot: const BookingServiceSnapshot(
        name: 'Cưới 4 giờ',
        price: 8000000,
        durationMinutes: 240,
      ),
      place: const BookingPlace(name: 'Nhà hàng Riverside, Quận 7'),
      createdAt: createdAt,
    ).copyWith(
      chatId: 'chat1',
      studio: StudioBookingInfo(
        assigneeId: assignee,
        assigneeKind: assignee == null ? null : 'member',
        assignStatus: assignee == null
            ? StudioAssignStatus.unassigned
            : StudioAssignStatus.assigned,
        assignDeadline: _deadline,
        // 08/10 10:00 Vietnam.
        assignedAt: assignee == null ? null : DateTime.utc(2026, 10, 8, 3),
        changeRequest: change,
        studioFault: fault,
        remindersSent: reminders,
      ),
    );

StudioChangeRequest _change(
  ChangeRequestStatus status, {
  String? declineReason,
}) => StudioChangeRequest(
  at: DateTime.utc(2026, 10, 9, 3),
  respondBy: DateTime.utc(2026, 10, 9, 9),
  status: status,
  declineReason: declineReason,
);

Future<BookingDetailHandles> _pump(
  WidgetTester tester,
  Booking b, {
  DateTime? now,
  BookingFeatures features = _chatOn,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  final repo = RecordingBookingRepository()..seedBooking(b);
  final h = await pumpBookingDetail(
    tester,
    uid: detailCustomerUid,
    bookings: repo,
    now: now ?? _weekBefore,
    features: features,
    profiles: _profiles,
    textScale: textScale,
    viewSize: viewSize,
  );
  await _settle(tester);
  return h;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _cancelFull => find.byKey(const Key('assignee-cancel-full'));

AppButton _button(WidgetTester tester, Key key) =>
    tester.widget<AppButton>(find.byKey(key));

void main() {
  testWidgets('an unassigned studio booking shows Studio sẽ báo thợ chụp '
      'trước {deadline}', (tester) async {
    await _pump(tester, _booking());

    expect(find.text('Thợ chụp cho bạn'), findsOneWidget);
    expect(
      find.text('Studio sẽ báo thợ chụp trước 15:30 CN 11/10'),
      findsOneWidget,
    );
    expect(find.byType(AssigneeCard), findsNothing);
    expect(_cancelFull, findsNothing);
    // The timeline waits for the assignment.
    expect(find.text('Chờ studio giao thợ chụp'), findsOneWidget);
  });

  testWidgets('an assigned one shows the member card with %, shoots and '
      'studio, Xem hồ sơ opens /u/{assignee}', (tester) async {
    final h = await _pump(tester, _booking(assignee: 'minh'));

    expect(find.text('Giao 08/10'), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.textContaining('97%'), findsOneWidget);
    expect(
      find.textContaining('112 buổi · thợ của Studio Mây'),
      findsOneWidget,
    );
    expect(find.text('Xin đổi thợ (1 lần)'), findsOneWidget);
    expect(find.text('Đã giao thợ chụp'), findsOneWidget);
    expect(
      find.text('Minh Trí đã vào nhóm chat của buổi chụp'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('assignee-view-profile')));
    await _settle(tester);
    expect(h.location, '/u/minh');
  });

  testWidgets('Xin đổi thợ (1 lần) opens S26.05; after sending it reads Đã '
      'xin đổi · chờ studio and is disabled', (tester) async {
    final h = await _pump(tester, _booking(assignee: 'minh'));

    await tester.tap(find.byKey(const Key('assignee-change')));
    await _settle(tester);
    expect(find.text('Xin đổi thợ chụp'), findsOneWidget);

    await tester.tap(find.byKey(const Key('change-send')));
    await _settle(tester);

    expect(h.bookings.studioCalls.single.$1, 'requestAssigneeChange');
    expect(find.text('Đã gửi yêu cầu đổi thợ'), findsOneWidget);
    expect(find.text('Đã xin đổi · chờ studio'), findsOneWidget);
    expect(_button(tester, const Key('assignee-change')).onPressed, isNull);
  });

  testWidgets('overdue (deadline passed, even before the sweep) shows Quá '
      'hạn, the warning, the reminded line and Huỷ và hoàn 100%', (
    tester,
  ) async {
    await _pump(
      tester,
      _booking(reminders: const ['h48', 'h26']),
      now: _afterDeadline,
    );

    expect(find.text('Quá hạn'), findsOneWidget);
    expect(
      find.text('Studio chưa báo thợ chụp đúng hạn (trước 15:30 CN 11/10)'),
      findsOneWidget,
    );
    expect(
      find.text('Bạn có thể chờ thêm hoặc huỷ và được hoàn 100%.'),
      findsOneWidget,
    );
    expect(_cancelFull, findsOneWidget);
    expect(
      find.text('Đã nhắc Studio Mây lúc 15:30 T7 10/10 và 13:30 CN 11/10.'),
      findsOneWidget,
    );
    expect(find.text('Quá hạn từ 15:30 CN 11/10'), findsOneWidget);
    // The usual cancel (with its own refund) gives way to the 100% one.
    expect(find.textContaining('Huỷ yêu cầu'), findsNothing);
  });

  testWidgets('declined shows the studio\'s reason and the cancel link', (
    tester,
  ) async {
    await _pump(
      tester,
      _booking(
        assignee: 'minh',
        change: _change(
          ChangeRequestStatus.declined,
          declineReason: 'Thợ nữ đã kín lịch ngày này',
        ),
        fault: StudioFault(
          kind: StudioFaultKind.changeDeclined,
          at: DateTime.utc(2026, 10, 9, 5),
        ),
      ),
    );

    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Studio không đổi thợ chụp'), findsOneWidget);
    expect(
      find.text(
        'Lý do: Thợ nữ đã kín lịch ngày này. Bạn giữ thợ hiện tại hoặc huỷ '
        'và được hoàn 100%.',
      ),
      findsOneWidget,
    );
    expect(_cancelFull, findsOneWidget);
    // The one change is used.
    expect(find.byKey(const Key('assignee-change')), findsNothing);
  });

  testWidgets('expired and late reassign show their texts and the cancel '
      'link', (tester) async {
    await _pump(
      tester,
      _booking(
        assignee: 'minh',
        change: _change(ChangeRequestStatus.expired),
        fault: StudioFault(
          kind: StudioFaultKind.changeExpired,
          at: DateTime.utc(2026, 10, 9, 9),
        ),
      ),
    );
    expect(find.text('Studio chưa trả lời yêu cầu đổi thợ'), findsOneWidget);
    expect(
      find.text('Bạn giữ thợ hiện tại hoặc huỷ và được hoàn 100%.'),
      findsOneWidget,
    );
    expect(_cancelFull, findsOneWidget);

    await _pump(
      tester,
      _booking(
        assignee: 'minh',
        fault: StudioFault(
          kind: StudioFaultKind.lateReassign,
          at: DateTime.utc(2026, 10, 11, 9),
        ),
      ),
      now: _afterDeadline,
    );
    expect(find.text('Studio đã đổi thợ khi còn dưới 24 giờ'), findsOneWidget);
    expect(find.text('Bạn có thể huỷ và được hoàn 100%.'), findsOneWidget);
    expect(_cancelFull, findsOneWidget);
  });

  testWidgets('Huỷ và hoàn 100% confirms in the 100% sheet and sends '
      'cancel_studio_fault', (tester) async {
    final h = await _pump(tester, _booking(), now: _afterDeadline);

    await tester.tap(_cancelFull);
    await _settle(tester);

    expect(find.text('Huỷ và hoàn 100%?'), findsOneWidget);
    expect(find.text('Hoàn 100% số đã trả'), findsOneWidget);
    expect(find.text('Giữ lịch'), findsOneWidget);
    expect(find.text('8.000.000₫'), findsWidgets);

    // "Giữ lịch" closes without a call.
    await tester.tap(find.text('Giữ lịch'));
    await _settle(tester);
    expect(h.bookings.transitions, isEmpty);

    await tester.tap(_cancelFull);
    await _settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(AppButton, 'Huỷ và hoàn 100%'),
      ),
    );
    await _settle(tester);

    expect(h.bookings.transitions.single.action, 'cancel_studio_fault');
    expect(h.bookings.bookings['b1']!.status, BookingStatus.cancelled);
    expect(find.text('Đã huỷ. Hoàn 8.000.000₫ trong 3–5 ngày'), findsOneWidget);
  });

  testWidgets('unassigned past the start: Quá hạn and the title stay, the '
      '100% line and the cancel are gone', (tester) async {
    await _pump(
      tester,
      _booking(reminders: const ['h48', 'h26']),
      now: _afterStart,
    );

    expect(find.text('Quá hạn'), findsOneWidget);
    expect(
      find.text('Studio chưa báo thợ chụp đúng hạn (trước 15:30 CN 11/10)'),
      findsOneWidget,
    );
    expect(
      find.text('Bạn có thể chờ thêm hoặc huỷ và được hoàn 100%.'),
      findsNothing,
    );
    expect(_cancelFull, findsNothing);
  });

  testWidgets('a booking made after the first reminder time shows no '
      'reminded line', (tester) async {
    // Made Saturday 10/10 22:00 Vietnam, after 15:30 that day: both
    // reminders went out together.
    await _pump(
      tester,
      _booking(
        reminders: const ['h48', 'h26'],
        createdAt: DateTime.utc(2026, 10, 10, 15),
      ),
      now: _afterDeadline,
    );

    expect(find.text('Quá hạn'), findsOneWidget);
    expect(find.byKey(const Key('assignee-reminded')), findsNothing);
  });

  testWidgets('Nhắn studio turns outline when another primary is on screen; '
      'an unassigned studio booking offers no review', (tester) async {
    const withReview = BookingFeatures(
      chat: true,
      reschedule: false,
      review: true,
    );
    await _pump(
      tester,
      _booking(status: BookingStatus.completed, assignee: 'minh'),
      features: withReview,
    );
    final primaries = [
      for (final b in tester.widgetList<AppButton>(
        find.ancestor(
          of: find.byType(CtaSurface),
          matching: find.byType(AppButton),
        ),
      ))
        b.label,
    ];
    expect(primaries, ['Đánh giá']);
    expect(find.text('Nhắn studio'), findsOneWidget);

    await _pump(
      tester,
      _booking(status: BookingStatus.completed),
      features: withReview,
    );
    expect(find.text('Đánh giá'), findsNothing);
  });

  testWidgets('the footer reads Nhắn studio for studio bookings', (
    tester,
  ) async {
    await _pump(tester, _booking(assignee: 'minh'));

    expect(find.text('Nhắn studio'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsNothing);
    // It is the screen's one primary.
    final primaries = tester.widgetList<AppButton>(
      find.ancestor(
        of: find.byType(CtaSurface),
        matching: find.byType(AppButton),
      ),
    );
    expect([for (final b in primaries) b.label], ['Nhắn studio']);
  });

  testWidgets('individual bookings are unchanged', (tester) async {
    final repo = RecordingBookingRepository()
      ..seedBooking(
        makeTestBooking(
          id: 'b1',
          status: BookingStatus.accepted,
          day: '2026-10-12',
          start: '15:30',
          end: '17:30',
        ).copyWith(chatId: 'chat1'),
      );
    await pumpBookingDetail(
      tester,
      uid: detailCustomerUid,
      bookings: repo,
      features: _chatOn,
    );
    await _settle(tester);

    expect(find.byKey(const Key('studio-assignee-block')), findsNothing);
    expect(find.text('Nhắn tin'), findsOneWidget);
    expect(find.text('Nhắn studio'), findsNothing);
    expect(find.text('Chờ studio giao thợ chụp'), findsNothing);
    expect(find.textContaining('Huỷ yêu cầu'), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _pump(
      tester,
      _booking(
        assignee: 'minh',
        change: _change(
          ChangeRequestStatus.declined,
          declineReason: 'Thợ nữ đã kín lịch ngày này',
        ),
        fault: StudioFault(
          kind: StudioFaultKind.changeDeclined,
          at: DateTime.utc(2026, 10, 9, 5),
        ),
      ),
      textScale: 1.3,
      viewSize: const Size(320, 700),
    );
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      _booking(reminders: const ['h48', 'h26']),
      now: _afterDeadline,
      textScale: 1.3,
      viewSize: const Size(320, 700),
    );
    expect(tester.takeException(), isNull);
  });

  group('S27 collaborator (S05.02-studio-collab)', () {
    const lan = PhotographerProfile(
      summary: PhotographerSummary(
        id: 'lan',
        displayName: 'Lan Phương',
        verified: true,
        acceptingOrders: true,
        reviewCount: 20,
        tomatoCount: 19,
        brickCount: 1,
        tomatoPct: 95,
        completedCount: 42,
      ),
      intro: PhotographerIntro(onboardingComplete: true),
    );
    const profiles = {'cuc': _studio, 'minh': _member, 'lan': lan};

    /// An offer to Lan Phương made at [_weekBefore] (6 h to answer), then
    /// accepted ([accepted]) or declined ([declined]).
    Booking collab({bool accepted = false, bool declined = false}) {
      final b = _booking();
      final offerAt = _weekBefore.subtract(const Duration(minutes: 1));
      return b.copyWith(
        studio: b.studio!.copyWith(
          assigneeId: declined ? null : 'lan',
          assigneeKind: declined ? null : 'collaborator',
          assigneeAccepted: accepted,
          assignStatus: accepted
              ? StudioAssignStatus.assigned
              : StudioAssignStatus.unassigned,
          assignedAt: accepted ? DateTime.utc(2026, 10, 8, 3) : null,
          assignments: [
            StudioAssignment(
              assigneeId: 'lan',
              assigneeKind: 'collaborator',
              at: offerAt,
              by: 'cuc',
              offerExpiresAt: offerAt.add(const Duration(hours: 6)),
              acceptedAt: accepted ? _weekBefore : null,
              declinedAt: declined ? _weekBefore : null,
            ),
          ],
        ),
      );
    }

    Future<void> pumpAs(
      WidgetTester tester,
      Booking b, {
      required String uid,
    }) async {
      final repo = RecordingBookingRepository()..seedBooking(b);
      await pumpBookingDetail(
        tester,
        uid: uid,
        bookings: repo,
        now: _weekBefore,
        features: _chatOn,
        profiles: profiles,
      );
      await _settle(tester);
    }

    testWidgets('pending collaborator offer still shows the S26 "chưa giao" '
        'state, not the collaborator', (tester) async {
      await pumpAs(tester, collab(), uid: detailCustomerUid);
      expect(find.byKey(const Key('assignee-waiting')), findsOneWidget);
      expect(find.byType(AssigneeCard), findsNothing);
      expect(find.textContaining('Lan Phương'), findsNothing);
      expect(find.byKey(const Key('studio-offer-line')), findsNothing);
    });

    testWidgets('accepted collaborator shows the block with "Cộng tác với '
        '{Studio}"', (tester) async {
      await pumpAs(tester, collab(accepted: true), uid: detailCustomerUid);
      expect(find.byType(AssigneeCard), findsOneWidget);
      expect(find.text('Lan Phương'), findsOneWidget);
      expect(find.text('Cộng tác với Studio Mây'), findsOneWidget);
      expect(find.textContaining('thợ của Studio Mây'), findsNothing);
      // The fee is never on the customer's screen.
      expect(find.textContaining('800.000'), findsNothing);
    });

    testWidgets('studio side: pending shows "Chờ {name} nhận · còn {left}"', (
      tester,
    ) async {
      await pumpAs(tester, collab(), uid: 'cuc');
      expect(
        find.text('Chờ Lan Phương nhận · còn 5 giờ 59 phút'),
        findsOneWidget,
      );
    });

    testWidgets('studio side: declined shows "{name} đã từ chối. Giao người '
        'khác trước {deadline}."', (tester) async {
      await pumpAs(tester, collab(declined: true), uid: 'cuc');
      expect(
        find.text(
          'Lan Phương đã từ chối. Giao người khác trước 15:30 CN 11/10.',
        ),
        findsOneWidget,
      );
    });
  });
}
