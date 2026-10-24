import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/booking_fixtures.dart';

const _off = BookingFeatures(chat: false, reschedule: false, review: false);
const _on = BookingFeatures(chat: true, reschedule: true, review: true);

/// Shoot on Monday 12/10 15:30–17:30 Vietnam = 08:30–10:30 UTC.
Booking _b(
  BookingStatus status, {
  String id = 'b1',
  String photographerId = 'p1',
  String day = '2026-10-12',
  String start = '15:30',
  String end = '17:30',
  int deposit = 450000,
  int remaining = 1050000,
  int price = 1500000,
  EscrowStatus? escrow = EscrowStatus.held,
  int? refunded,
  DateTime? acceptDeadline,
  DateTime? completedAt,
  DateTime? updatedAt,
  String? chatId,
  BookingCancel? cancel,
}) {
  return makeTestBooking(
    id: id,
    photographerId: photographerId,
    status: status,
    day: day,
    start: start,
    end: end,
    deposit: deposit,
    remaining: remaining,
    serviceSnapshot: BookingServiceSnapshot(
      name: 'Chân dung 2 giờ',
      price: price,
      durationMinutes: 120,
    ),
    escrowStatus: escrow,
    completedAt: completedAt,
    cancel: cancel,
    updatedAt: updatedAt,
  ).copyWith(
    acceptDeadline: acceptDeadline,
    depositRefunded: refunded,
    chatId: chatId,
  );
}

BookingEventRecord _ev(BookingStatus s, DateTime at) =>
    BookingEventRecord(id: 'e_${s.name}', bookingId: 'b1', status: s, at: at);

void main() {
  final l = AppLocalizationsVi();
  // 12/10 15:30 VN.
  final startsAt = DateTime.utc(2026, 10, 12, 8, 30);
  final endsAt = DateTime.utc(2026, 10, 12, 10, 30);
  // 11/10 10:00 VN: the day before the shoot.
  final dayBefore = DateTime.utc(2026, 10, 11, 3, 0);
  // 05/10 10:00 VN: a week before.
  final weekBefore = DateTime.utc(2026, 10, 5, 3, 0);

  test('booking code is the last 4 id characters upper-cased', () {
    expect(bookingCode('01J9ZK3Q8W6Ra1f3'), 'A1F3');
    expect(bookingCode('b1'), 'B1');
  });

  group('detailActions', () {
    test('requested, customer → contact, cancel', () {
      final b = _b(BookingStatus.requested);
      expect(detailActions(b, BookingRole.customer, weekBefore, _off), [
        DetailAction.contact,
        DetailAction.cancel,
      ]);
    });

    test('requested, photographer → accept, decline', () {
      final b = _b(
        BookingStatus.requested,
        acceptDeadline: weekBefore.add(const Duration(hours: 22)),
      );
      expect(detailActions(b, BookingRole.photographer, weekBefore, _off), [
        DetailAction.accept,
        DetailAction.decline,
      ]);
    });

    test('requested, photographer after the deadline → nothing to do', () {
      final b = _b(
        BookingStatus.requested,
        acceptDeadline: weekBefore.subtract(const Duration(minutes: 1)),
      );
      expect(detailActions(b, BookingRole.photographer, weekBefore, _off), []);
    });

    test('accepted, customer the day before → contact, directions, cancel; '
        'reschedule only with its flag', () {
      final b = _b(BookingStatus.accepted);
      expect(detailActions(b, BookingRole.customer, dayBefore, _off), [
        DetailAction.contact,
        DetailAction.directions,
        DetailAction.cancel,
      ]);
      expect(
        detailActions(
          b,
          BookingRole.customer,
          dayBefore,
          const BookingFeatures(chat: false, reschedule: true, review: false),
        ),
        [
          DetailAction.contact,
          DetailAction.reschedule,
          DetailAction.directions,
          DetailAction.cancel,
        ],
      );
    });

    test('accepted, customer a week before → no directions yet', () {
      final b = _b(BookingStatus.upcoming);
      expect(detailActions(b, BookingRole.customer, weekBefore, _off), [
        DetailAction.contact,
        DetailAction.cancel,
      ]);
    });

    test('customer cancel is absent at or after startsAt', () {
      final b = _b(BookingStatus.upcoming);
      expect(
        detailActions(b, BookingRole.customer, startsAt, _off),
        isNot(contains(DetailAction.cancel)),
      );
      expect(
        detailActions(
          _b(BookingStatus.requested),
          BookingRole.customer,
          startsAt.add(const Duration(minutes: 5)),
          _off,
        ),
        isNot(contains(DetailAction.cancel)),
      );
    });

    test('accepted, photographer before the shoot → contact, cancel', () {
      final b = _b(BookingStatus.accepted);
      expect(detailActions(b, BookingRole.photographer, dayBefore, _off), [
        DetailAction.contact,
        DetailAction.cancel,
      ]);
    });

    test('accepted, photographer during the shoot → contact only', () {
      final b = _b(BookingStatus.upcoming);
      expect(
        detailActions(
          b,
          BookingRole.photographer,
          startsAt.add(const Duration(minutes: 30)),
          _off,
        ),
        [DetailAction.contact],
      );
    });

    test('accepted, photographer after endsAt → contact, markShot', () {
      final b = _b(BookingStatus.upcoming);
      expect(detailActions(b, BookingRole.photographer, endsAt, _off), [
        DetailAction.contact,
        DetailAction.markShot,
      ]);
    });

    test('declined, expired, cancelled → book again for the customer, '
        'nothing for the photographer', () {
      for (final s in [
        BookingStatus.declined,
        BookingStatus.expired,
        BookingStatus.cancelled,
      ]) {
        final b = _b(s);
        expect(detailActions(b, BookingRole.customer, weekBefore, _on), [
          DetailAction.bookAgain,
        ], reason: s.name);
        expect(
          detailActions(b, BookingRole.photographer, weekBefore, _on),
          isEmpty,
          reason: s.name,
        );
      }
    });

    test('completed customer → review only with the review flag', () {
      final b = _b(BookingStatus.completed);
      final after = endsAt.add(const Duration(hours: 2));
      expect(detailActions(b, BookingRole.customer, after, _off), isEmpty);
      expect(
        detailActions(
          b,
          BookingRole.customer,
          after,
          const BookingFeatures(chat: false, reschedule: false, review: true),
        ),
        [DetailAction.review],
      );
      expect(detailActions(b, BookingRole.photographer, after, _on), isEmpty);
    });

    test('reviewed customer → view review only with the review flag', () {
      final b = _b(BookingStatus.reviewed);
      final after = endsAt.add(const Duration(days: 2));
      expect(detailActions(b, BookingRole.customer, after, _off), isEmpty);
      expect(
        detailActions(
          b,
          BookingRole.customer,
          after,
          const BookingFeatures(chat: false, reschedule: false, review: true),
        ),
        [DetailAction.viewReview],
      );
    });

    test('customer gets review on completed without reviewedAt, viewReview '
        'once reviewedAt is set', () {
      final after = endsAt.add(const Duration(days: 2));
      const on = BookingFeatures(chat: false, reschedule: false, review: true);
      final open = _b(BookingStatus.completed);
      expect(detailActions(open, BookingRole.customer, after, on), [
        DetailAction.review,
      ]);
      final done = open.copyWith(reviewedAt: after);
      expect(detailActions(done, BookingRole.customer, after, on), [
        DetailAction.viewReview,
      ]);
    });

    test('message only when chat is on and the booking has a chat', () {
      final withChat = _b(BookingStatus.accepted, chatId: 'chat1');
      final noChat = _b(BookingStatus.accepted);
      const chatOnly = BookingFeatures(
        chat: true,
        reschedule: false,
        review: false,
      );
      expect(
        detailActions(withChat, BookingRole.customer, weekBefore, _off),
        isNot(contains(DetailAction.message)),
      );
      expect(
        detailActions(noChat, BookingRole.customer, weekBefore, chatOnly),
        isNot(contains(DetailAction.message)),
      );
      expect(
        detailActions(withChat, BookingRole.customer, weekBefore, chatOnly),
        [DetailAction.message, DetailAction.contact, DetailAction.cancel],
      );
      expect(
        detailActions(withChat, BookingRole.photographer, weekBefore, chatOnly),
        [DetailAction.message, DetailAction.contact, DetailAction.cancel],
      );
    });
  });

  group('timelineSteps', () {
    final sentAt = DateTime.utc(2026, 10, 5, 2, 41); // 05/10 09:41 VN
    final acceptedAt = DateTime.utc(2026, 10, 5, 3, 10); // 05/10 10:10 VN

    List<TimelineStepState> states(List<TimelineStep> s) => [
      for (final x in s) x.state,
    ];

    test('requested: step 1 done with time and deposit, step 2 current', () {
      final steps = timelineSteps(
        _b(BookingStatus.requested),
        [_ev(BookingStatus.requested, sentAt)],
        weekBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(steps, hasLength(8));
      expect(steps[0].title, 'Đã gửi & thanh toán');
      expect(steps[0].subtitle, 'Hôm nay 09:41 · 450.000₫');
      expect(steps[1].title, 'Chờ Minh Trí nhận');
      expect(steps[1].subtitle, 'Thường trong 1 giờ');
      expect(steps[3].title, 'Sắp tới · T2 12/10');
      expect(steps[6].subtitle, 'Trả 1.050.000₫ tại chỗ');
      expect(steps[7].title, 'Đánh giá & chia sẻ ảnh');
      expect(states(steps), [
        TimelineStepState.done,
        TimelineStepState.current,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
      ]);
    });

    test('step 1 shows the date when it was not today', () {
      final steps = timelineSteps(
        _b(BookingStatus.requested),
        [_ev(BookingStatus.requested, sentAt)],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(steps[0].subtitle, '05/10 09:41 · 450.000₫');
    });

    test('accepted: steps 1–3 done, 4 upcoming with the date', () {
      final steps = timelineSteps(
        _b(BookingStatus.accepted),
        [
          _ev(BookingStatus.requested, sentAt),
          _ev(BookingStatus.accepted, acceptedAt),
        ],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(steps, hasLength(8));
      expect(states(steps).take(4), [
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.upcoming,
      ]);
      expect(steps[2].subtitle, '05/10 10:10');
      expect(steps[3].title, 'Sắp tới · T2 12/10');
      expect(steps[3].subtitle, 'Nhắc trước 24 giờ');
    });

    test('upcoming before the shoot: step 4 current', () {
      final steps = timelineSteps(
        _b(BookingStatus.upcoming),
        const [],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(steps[3].state, TimelineStepState.current);
      expect(steps[4].state, TimelineStepState.upcoming);
    });

    test('upcoming during the shoot: step 5 current', () {
      final steps = timelineSteps(
        _b(BookingStatus.upcoming),
        const [],
        startsAt.add(const Duration(minutes: 20)),
        l,
        photographerName: 'Minh Trí',
      );
      expect(states(steps), [
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.current,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
      ]);
    });

    test('completed: 1–7 done with completion time, 8 upcoming', () {
      final completedAt = DateTime.utc(2026, 10, 12, 11, 0); // 18:00 VN
      final steps = timelineSteps(
        _b(BookingStatus.completed, completedAt: completedAt),
        const [],
        DateTime.utc(2026, 10, 13, 3, 0),
        l,
        photographerName: 'Minh Trí',
      );
      expect(states(steps), [
        for (var i = 0; i < 7; i++) TimelineStepState.done,
        TimelineStepState.upcoming,
      ]);
      expect(steps[6].subtitle, '12/10 18:00');
    });

    test('reviewed: all done', () {
      final steps = timelineSteps(
        _b(BookingStatus.reviewed, completedAt: endsAt),
        const [],
        DateTime.utc(2026, 10, 14, 3, 0),
        l,
        photographerName: 'Minh Trí',
      );
      expect(steps, hasLength(8));
      expect(states(steps), everyElement(TimelineStepState.done));
    });

    test('completed with reviewedAt set: step 7 done; without: upcoming', () {
      final now = DateTime.utc(2026, 10, 14, 3, 0);
      final open = _b(BookingStatus.completed, completedAt: endsAt);
      List<TimelineStep> steps(Booking b) =>
          timelineSteps(b, const [], now, l, photographerName: 'Minh Trí');
      expect(steps(open).last.state, TimelineStepState.upcoming);
      expect(
        steps(open.copyWith(reviewedAt: now)).last.state,
        TimelineStepState.done,
      );
    });

    test("cancelled after acceptance: steps 1–3 done then a stopped "
        "'Đã huỷ · hoàn 225.000₫'", () {
      final steps = timelineSteps(
        _b(
          BookingStatus.cancelled,
          escrow: EscrowStatus.partiallyRefunded,
          cancel: BookingCancel(by: 'c1', at: dayBefore, refundPercent: 50),
        ),
        [
          _ev(BookingStatus.requested, sentAt),
          _ev(BookingStatus.accepted, acceptedAt),
          _ev(BookingStatus.cancelled, dayBefore),
        ],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(states(steps), [
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.stopped,
      ]);
      expect(steps.last.title, 'Đã huỷ · hoàn 225.000₫');
    });

    test('cancelled uses depositRefunded when the server has set it', () {
      final steps = timelineSteps(
        _b(BookingStatus.cancelled, refunded: 450000),
        [_ev(BookingStatus.requested, sentAt)],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(states(steps), [
        TimelineStepState.done,
        TimelineStepState.stopped,
      ]);
      expect(steps.last.title, 'Đã huỷ · hoàn 450.000₫');
    });

    test("expired: stopped 'Hết hạn, đã hoàn tiền'", () {
      final steps = timelineSteps(
        _b(BookingStatus.expired),
        [_ev(BookingStatus.requested, sentAt)],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(states(steps), [
        TimelineStepState.done,
        TimelineStepState.stopped,
      ]);
      expect(steps.last.title, 'Hết hạn, đã hoàn tiền');
    });

    test("declined: stopped 'Đã từ chối'", () {
      final steps = timelineSteps(
        _b(BookingStatus.declined),
        const [],
        dayBefore,
        l,
        photographerName: 'Minh Trí',
      );
      expect(steps.last.title, 'Đã từ chối');
      expect(steps.last.state, TimelineStepState.stopped);
    });
  });

  test('bucket: buckets and ordering', () {
    final all = [
      _b(BookingStatus.draft, id: 'draft'),
      _b(BookingStatus.requested, id: 'req_late', day: '2026-10-20'),
      _b(BookingStatus.requested, id: 'req_soon', day: '2026-10-15'),
      _b(BookingStatus.accepted, id: 'acc', day: '2026-10-18'),
      _b(BookingStatus.upcoming, id: 'up', day: '2026-10-12'),
      _b(
        BookingStatus.completed,
        id: 'done',
        updatedAt: DateTime.utc(2026, 10, 2),
      ),
      _b(
        BookingStatus.reviewed,
        id: 'rev',
        updatedAt: DateTime.utc(2026, 9, 20),
      ),
      _b(
        BookingStatus.declined,
        id: 'dec',
        updatedAt: DateTime.utc(2026, 10, 4),
      ),
      _b(BookingStatus.expired, id: 'exp', updatedAt: DateTime.utc(2026, 9, 1)),
      _b(
        BookingStatus.cancelled,
        id: 'can',
        updatedAt: DateTime.utc(2026, 10, 3),
      ),
    ];
    List<String> ids(BookingTab t) => [for (final b in bucket(all, t)) b.id];

    expect(ids(BookingTab.upcoming), ['up', 'acc']);
    expect(ids(BookingTab.pending), ['req_soon', 'req_late']);
    expect(ids(BookingTab.history), ['dec', 'can', 'done', 'rev', 'exp']);
    for (final t in BookingTab.values) {
      expect(ids(t), isNot(contains('draft')));
    }
  });

  group('workDashboard', () {
    // Monday 12/10 09:00 VN.
    final now = DateTime.utc(2026, 10, 12, 2, 0);

    test("today is the earliest accepted/upcoming booking on today's date", () {
      final d = workDashboard(
        [
          _b(BookingStatus.accepted, id: 'late', start: '15:30', end: '17:30'),
          _b(BookingStatus.upcoming, id: 'early', start: '10:00', end: '11:00'),
          _b(BookingStatus.accepted, id: 'tomorrow', day: '2026-10-13'),
          _b(BookingStatus.completed, id: 'old', day: '2026-10-12'),
        ],
        now,
        uid: 'p1',
      );
      expect(d.today?.id, 'early');
      expect(d.upcomingCount, 3);
    });

    test('requests sorted by deadline, expired ones excluded', () {
      final d = workDashboard(
        [
          _b(
            BookingStatus.requested,
            id: 'r_late',
            acceptDeadline: now.add(const Duration(hours: 20)),
          ),
          _b(
            BookingStatus.requested,
            id: 'r_soon',
            acceptDeadline: now.add(const Duration(hours: 2)),
          ),
          _b(
            BookingStatus.requested,
            id: 'r_past',
            acceptDeadline: now.subtract(const Duration(minutes: 1)),
          ),
          _b(BookingStatus.expired, id: 'expired'),
        ],
        now,
        uid: 'p1',
      );
      expect([for (final b in d.requests) b.id], ['r_soon', 'r_late']);
    });

    test('month revenue counts completed this Vietnamese month only '
        '(boundary 00:00 +07:00)', () {
      final d = workDashboard(
        [
          // 01/10 00:00 VN = 30/09 17:00 UTC → this month.
          _b(
            BookingStatus.completed,
            id: 'in1',
            price: 1000000,
            escrow: EscrowStatus.released,
            completedAt: DateTime.utc(2026, 9, 30, 17, 0),
          ),
          // 30/09 23:59 VN → last month.
          _b(
            BookingStatus.completed,
            id: 'out',
            price: 5000000,
            escrow: EscrowStatus.released,
            completedAt: DateTime.utc(2026, 9, 30, 16, 59),
          ),
          _b(
            BookingStatus.reviewed,
            id: 'in2',
            price: 2000000,
            escrow: EscrowStatus.released,
            completedAt: DateTime.utc(2026, 10, 5),
          ),
          _b(BookingStatus.upcoming, id: 'not_done', price: 9000000),
        ],
        now,
        uid: 'p1',
      );
      expect(d.monthRevenueVnd, 3000000);
    });

    test('the month sum counts the total of completed bookings with '
        'add-ons', () {
      final d = workDashboard(
        [
          _b(
            BookingStatus.completed,
            id: 'with_addons',
            price: 1500000,
            escrow: EscrowStatus.released,
            completedAt: DateTime.utc(2026, 10, 5),
          ).copyWith(addons: const [testMakeupLine, testTransportLine]),
          _b(
            BookingStatus.completed,
            id: 'plain',
            price: 1000000,
            escrow: EscrowStatus.released,
            completedAt: DateTime.utc(2026, 10, 6),
          ),
        ],
        now,
        uid: 'p1',
      );
      expect(d.monthRevenueVnd, 3400000 + 1000000);
    });

    test('held sums deposit minus refunded for held, partially refunded and '
        'disputed', () {
      final d = workDashboard(
        [
          _b(BookingStatus.accepted, id: 'h', deposit: 450000),
          _b(
            BookingStatus.cancelled,
            id: 'p',
            deposit: 300000,
            escrow: EscrowStatus.partiallyRefunded,
            refunded: 150000,
          ),
          _b(
            BookingStatus.completed,
            id: 'd',
            deposit: 200000,
            escrow: EscrowStatus.disputed,
          ),
          _b(
            BookingStatus.completed,
            id: 'r',
            deposit: 999000,
            escrow: EscrowStatus.released,
          ),
          _b(
            BookingStatus.declined,
            id: 'f',
            deposit: 999000,
            escrow: EscrowStatus.refunded,
            refunded: 999000,
          ),
        ],
        now,
        uid: 'p1',
      );
      expect(d.heldVnd, 450000 + 150000 + 200000);
    });

    test('isEmpty when nothing is happening even if old completed bookings '
        'exist', () {
      final d = workDashboard(
        [
          _b(
            BookingStatus.completed,
            day: '2026-09-01',
            escrow: EscrowStatus.released,
            completedAt: DateTime.utc(2026, 9, 1, 12),
          ),
          _b(BookingStatus.cancelled, escrow: EscrowStatus.refunded),
        ],
        now,
        uid: 'p1',
      );
      expect(d.isEmpty, isTrue);
      expect(workDashboard(const [], now, uid: 'p1').isEmpty, isTrue);
      expect(
        workDashboard(
          [_b(BookingStatus.accepted, day: '2026-10-20')],
          now,
          uid: 'p1',
        ).isEmpty,
        isFalse,
      );
    });
    group('assigned by a studio (Decision 18)', () {
      // photographerId is the studio; the viewer is p1.
      Booking assigned(
        BookingStatus status, {
        String id = 'a1',
        String day = '2026-10-12',
        String start = '09:00',
        String end = '10:00',
        DateTime? acceptDeadline,
        DateTime? completedAt,
        EscrowStatus? escrow = EscrowStatus.held,
      }) => _b(
        status,
        id: id,
        photographerId: 'studio1',
        day: day,
        start: start,
        end: end,
        price: 7000000,
        deposit: 2100000,
        acceptDeadline: acceptDeadline,
        completedAt: completedAt,
        escrow: escrow,
      );

      test('an assigned booking today becomes the today card', () {
        final d = workDashboard(
          [
            _b(BookingStatus.accepted, id: 'own', start: '15:30', end: '17:30'),
            assigned(BookingStatus.accepted, id: 'a1', start: '09:00'),
          ],
          now,
          uid: 'p1',
        );
        expect(d.today?.id, 'a1');
        expect(d.isEmpty, isFalse);
      });

      test('assigned bookings count in Buổi sắp tới', () {
        final d = workDashboard(
          [
            _b(BookingStatus.upcoming, id: 'own', day: '2026-10-15'),
            assigned(BookingStatus.accepted, id: 'a1', day: '2026-10-14'),
            assigned(BookingStatus.upcoming, id: 'a2', day: '2026-10-16'),
          ],
          now,
          uid: 'p1',
        );
        expect(d.upcomingCount, 3);
      });

      test('assigned bookings never count in requests, Tháng này or Đang '
          'giữ', () {
        final d = workDashboard(
          [
            assigned(
              BookingStatus.requested,
              id: 'a_req',
              acceptDeadline: now.add(const Duration(hours: 5)),
            ),
            assigned(
              BookingStatus.completed,
              id: 'a_done',
              escrow: EscrowStatus.released,
              completedAt: DateTime.utc(2026, 10, 5),
            ),
            assigned(BookingStatus.accepted, id: 'a_held', day: '2026-10-20'),
          ],
          now,
          uid: 'p1',
        );
        expect(d.requests, isEmpty);
        expect(d.monthRevenueVnd, 0);
        expect(d.heldVnd, 0);
        expect(d.upcomingCount, 1);
      });
    });
  });

  test('countdownLabel: 22 giờ, 45 phút, 59 giây, then null', () {
    expect(countdownLabel(const Duration(hours: 22, minutes: 30), l), '22 giờ');
    expect(
      countdownLabel(const Duration(minutes: 45, seconds: 10), l),
      '45 phút',
    );
    expect(countdownLabel(const Duration(seconds: 59), l), '59 giây');
    expect(countdownLabel(Duration.zero, l), isNull);
    expect(countdownLabel(const Duration(seconds: -3), l), isNull);
  });

  group('studio bookings (#136)', () {
    final weekBefore = DateTime.utc(2026, 10, 5, 3);
    Booking studio(BookingStatus status, {String? assignee}) =>
        _b(status, photographerId: 'cuc', chatId: 'ch1').copyWith(
          studio: StudioBookingInfo(
            assigneeId: assignee,
            assignStatus: assignee == null
                ? StudioAssignStatus.unassigned
                : StudioAssignStatus.assigned,
            assignDeadline: DateTime.utc(2026, 10, 11, 8, 30),
          ),
        );

    test('the assignee is on the studio side, the studio itself too', () {
      final b = studio(BookingStatus.accepted, assignee: 'minh');
      expect(roleIn(b, 'minh'), BookingRole.photographer);
      expect(isAssigneeOf(b, 'minh'), isTrue);
      expect(isAssigneeOf(b, 'cuc'), isFalse);
      expect(roleIn(b, 'cuc'), BookingRole.photographer);
      expect(roleIn(b, 'other'), isNull);
    });

    test('the studio can assign before the start and never reschedule', () {
      final b = studio(BookingStatus.accepted);
      expect(detailActions(b, BookingRole.photographer, weekBefore, _on), [
        DetailAction.message,
        DetailAction.contact,
        DetailAction.assign,
        DetailAction.cancel,
      ]);
      expect(
        detailActions(b, BookingRole.customer, weekBefore, _on),
        isNot(contains(DetailAction.reschedule)),
      );
    });

    test('the assignee messages, reaches the customer and marks the shoot; '
        'no cancel, assign or delivery', () {
      final b = studio(BookingStatus.accepted, assignee: 'minh');
      expect(
        detailActions(
          b,
          BookingRole.photographer,
          weekBefore,
          _on,
          assignee: true,
        ),
        [DetailAction.message, DetailAction.contact, DetailAction.returnJob],
      );
      final shot = studio(BookingStatus.shot, assignee: 'minh');
      expect(
        detailActions(
          shot,
          BookingRole.photographer,
          weekBefore,
          _on,
          assignee: true,
        ),
        [DetailAction.message, DetailAction.contact],
      );
      expect(
        detailActions(shot, BookingRole.photographer, weekBefore, _on),
        contains(DetailAction.deliver),
      );
    });

    test('a studio spot booking keeps the schedule member: no assign, no '
        '"Trả việc", no change request, no reschedule (#194 Decision 7)', () {
      final b = studio(
        BookingStatus.accepted,
        assignee: 'minh',
      ).copyWith(spotId: 'spot-ho-tay', spotScheduleId: 'sched-1');
      expect(
        detailActions(b, BookingRole.photographer, weekBefore, _on),
        isNot(contains(DetailAction.assign)),
      );
      expect(
        detailActions(
          b,
          BookingRole.photographer,
          weekBefore,
          _on,
          assignee: true,
        ),
        [DetailAction.message, DetailAction.contact],
      );
      expect(canRequestAssigneeChange(b, weekBefore), isFalse);
      expect(
        detailActions(b, BookingRole.customer, weekBefore, _on),
        isNot(contains(DetailAction.reschedule)),
      );
    });

    test(
      'an individual spot booking cannot be rescheduled (#194 Decision 16)',
      () {
        final b = _b(BookingStatus.accepted)
            .copyWith(spotId: 'spot-ho-tay', spotScheduleId: 'sched-1');
        expect(
          detailActions(b, BookingRole.customer, weekBefore, _on),
          isNot(contains(DetailAction.reschedule)),
        );
        expect(
          detailActions(
            _b(BookingStatus.accepted),
            BookingRole.customer,
            weekBefore,
            _on,
          ),
          contains(DetailAction.reschedule),
        );
      },
    );

    test('"Trả việc" for the assignee while active, before the start and '
        'not returned; never for the studio or the customer', () {
      final b = studio(BookingStatus.upcoming, assignee: 'minh');
      List<DetailAction> forAssignee(Booking x, DateTime at) =>
          detailActions(x, BookingRole.photographer, at, _on, assignee: true);
      expect(forAssignee(b, weekBefore), contains(DetailAction.returnJob));
      expect(
        forAssignee(b, startsAt.subtract(const Duration(minutes: 1))),
        contains(DetailAction.returnJob),
      );
      expect(forAssignee(b, startsAt), isNot(contains(DetailAction.returnJob)));
      final returned = b.copyWith(
        studio: b.studio!.copyWith(returnedAt: weekBefore),
      );
      expect(
        forAssignee(returned, weekBefore),
        isNot(contains(DetailAction.returnJob)),
      );
      expect(
        forAssignee(studio(BookingStatus.shot, assignee: 'minh'), weekBefore),
        isNot(contains(DetailAction.returnJob)),
      );
      expect(
        detailActions(b, BookingRole.photographer, weekBefore, _on),
        isNot(contains(DetailAction.returnJob)),
      );
      expect(
        detailActions(b, BookingRole.customer, weekBefore, _on),
        isNot(contains(DetailAction.returnJob)),
      );
    });

    test('no "Đã chụp" for the studio while nobody is assigned (#136: no '
        'payout without an assignee)', () {
      final unassigned = studio(BookingStatus.accepted);
      expect(
        detailActions(unassigned, BookingRole.photographer, endsAt, _on),
        isNot(contains(DetailAction.markShot)),
      );
      expect(BookingRules.canPhotographerComplete(unassigned, endsAt), isFalse);
      final assigned = studio(BookingStatus.upcoming, assignee: 'minh');
      expect(
        detailActions(assigned, BookingRole.photographer, endsAt, _on),
        contains(DetailAction.markShot),
      );
      expect(
        detailActions(
          assigned,
          BookingRole.photographer,
          endsAt,
          _on,
          assignee: true,
        ),
        contains(DetailAction.markShot),
      );
    });

    test('workDashboard lists the studio\'s jobs and the assigned ones', () {
      final now = DateTime.utc(2026, 10, 5, 3);
      final own = studio(BookingStatus.accepted);
      final mine = studio(
        BookingStatus.upcoming,
        assignee: 'minh',
      ).copyWith(id: 'b2');
      final started = studio(BookingStatus.accepted)
          .copyWith(id: 'b3', day: '2026-10-01');
      final forStudio = workDashboard([own, started], now, uid: 'cuc');
      expect(forStudio.studioJobs.map((b) => b.id), ['b1']);
      expect(forStudio.assignedJobs, isEmpty);
      final forMember = workDashboard([mine], now, uid: 'minh');
      expect(forMember.assignedJobs.map((b) => b.id), ['b2']);
      expect(forMember.studioJobs, isEmpty);
      expect(forMember.requests, isEmpty);
      expect(forMember.isEmpty, isFalse);
    });

    group('customer block (Task 9)', () {
      // Deadline Sunday 11/10 15:30 Vietnam; shoot Monday 12/10 15:30.
      final afterDeadline = DateTime.utc(2026, 10, 11, 9);
      final afterStart = DateTime.utc(2026, 10, 12, 9);
      Booking withFault(StudioFaultKind kind, {String? assignee = 'minh'}) {
        final b = studio(BookingStatus.accepted, assignee: assignee);
        return b.copyWith(
          studio: b.studio!.copyWith(
            studioFault: StudioFault(kind: kind, at: weekBefore),
          ),
        );
      }

      test('studioFaultOf: overdue unassigned even before the sweep, the '
          'stored fault, nothing after the start', () {
        final open = studio(BookingStatus.accepted);
        expect(studioFaultOf(open, weekBefore), isNull);
        expect(
          studioFaultOf(open, afterDeadline),
          StudioFaultKind.assignOverdue,
        );
        expect(studioFaultOf(open, afterStart), isNull);
        expect(
          studioFaultOf(withFault(StudioFaultKind.changeDeclined), weekBefore),
          StudioFaultKind.changeDeclined,
        );
        expect(
          studioFaultOf(
            studio(BookingStatus.accepted, assignee: 'minh'),
            afterDeadline,
          ),
          isNull,
        );
        expect(
          studioFaultOf(_b(BookingStatus.accepted), afterDeadline),
          isNull,
        );
      });

      test('studioBlockStateOf covers the seven states', () {
        expect(
          studioBlockStateOf(_b(BookingStatus.accepted), weekBefore),
          isNull,
        );
        expect(
          studioBlockStateOf(studio(BookingStatus.accepted), weekBefore),
          StudioBlockState.waiting,
        );
        expect(
          studioBlockStateOf(studio(BookingStatus.accepted), afterDeadline),
          StudioBlockState.overdue,
        );
        final assigned = studio(BookingStatus.accepted, assignee: 'minh');
        expect(
          studioBlockStateOf(assigned, weekBefore),
          StudioBlockState.assigned,
        );
        final pending = assigned.copyWith(
          studio: assigned.studio!.copyWith(
            changeRequest: StudioChangeRequest(
              at: weekBefore,
              respondBy: weekBefore.add(const Duration(hours: 6)),
            ),
          ),
        );
        expect(
          studioBlockStateOf(pending, weekBefore),
          StudioBlockState.changePending,
        );
        expect(
          studioBlockStateOf(
            withFault(StudioFaultKind.changeDeclined),
            weekBefore,
          ),
          StudioBlockState.changeDeclined,
        );
        expect(
          studioBlockStateOf(
            withFault(StudioFaultKind.changeExpired),
            weekBefore,
          ),
          StudioBlockState.changeExpired,
        );
        expect(
          studioBlockStateOf(
            withFault(StudioFaultKind.lateReassign),
            weekBefore,
          ),
          StudioBlockState.lateReassign,
        );
        // The right ends at the start: the card stays.
        expect(
          studioBlockStateOf(
            withFault(StudioFaultKind.lateReassign),
            afterStart,
          ),
          StudioBlockState.assigned,
        );
      });

      test('the customer gets Huỷ và hoàn 100% instead of the usual cancel '
          'while a fault lasts', () {
        final open = studio(BookingStatus.accepted);
        expect(
          detailActions(open, BookingRole.customer, weekBefore, _on),
          allOf(
            contains(DetailAction.cancel),
            isNot(contains(DetailAction.cancelStudioFault)),
          ),
        );
        expect(
          detailActions(open, BookingRole.customer, afterDeadline, _on),
          allOf(
            contains(DetailAction.cancelStudioFault),
            isNot(contains(DetailAction.cancel)),
          ),
        );
        // The studio's own cancel is unchanged.
        expect(
          detailActions(open, BookingRole.photographer, afterDeadline, _on),
          contains(DetailAction.cancel),
        );
      });

      test('an unassigned studio booking is not offered a review', () {
        final unassigned = studio(BookingStatus.completed);
        final assigned = studio(BookingStatus.completed, assignee: 'minh');
        expect(
          detailActions(unassigned, BookingRole.customer, afterStart, _on),
          isNot(contains(DetailAction.review)),
        );
        expect(
          detailActions(assigned, BookingRole.customer, afterStart, _on),
          contains(DetailAction.review),
        );
      });

      test('primaryActions: view delivery gives way to a review, message '
          'is never primary here', () {
        final b = studio(BookingStatus.approved, assignee: 'minh');
        expect(
          primaryActions(b, const [
            DetailAction.message,
            DetailAction.viewDelivery,
            DetailAction.review,
          ]),
          {DetailAction.review},
        );
        final delivered = studio(BookingStatus.delivered, assignee: 'minh');
        expect(
          primaryActions(delivered, const [
            DetailAction.message,
            DetailAction.viewDelivery,
          ]),
          {DetailAction.viewDelivery},
        );
        expect(
          primaryActions(b, const [DetailAction.message, DetailAction.contact]),
          isEmpty,
        );
      });

      test('a change can be asked once, while assigned and before the '
          'start', () {
        final assigned = studio(BookingStatus.accepted, assignee: 'minh');
        expect(canRequestAssigneeChange(assigned, weekBefore), isTrue);
        expect(canRequestAssigneeChange(assigned, afterStart), isFalse);
        expect(
          canRequestAssigneeChange(studio(BookingStatus.accepted), weekBefore),
          isFalse,
        );
        expect(
          canRequestAssigneeChange(
            withFault(StudioFaultKind.changeDeclined).copyWith(
              studio: withFault(StudioFaultKind.changeDeclined).studio!
                  .copyWith(
                    changeRequest: StudioChangeRequest(
                      at: weekBefore,
                      respondBy: weekBefore,
                      status: ChangeRequestStatus.declined,
                    ),
                  ),
            ),
            weekBefore,
          ),
          isFalse,
        );
      });
    });
  });

  group('studioOfferOf (S27)', () {
    final deadline = DateTime.utc(2026, 10, 23, 8);
    final now = DateTime.utc(2026, 10, 21, 3);

    Booking offer({required BookingStatus status, bool declined = false}) =>
        makeTestBooking(
          id: 'sb1',
          photographerId: 'cuc',
          status: status,
          day: '2026-10-24',
          start: '15:00',
          end: '17:00',
        ).copyWith(
          studio: StudioBookingInfo(
            assigneeId: declined ? null : 'lan',
            assigneeKind: declined ? null : 'collaborator',
            assignDeadline: deadline,
            assignments: [
              StudioAssignment(
                assigneeId: 'lan',
                assigneeKind: 'collaborator',
                at: now,
                by: 'cuc',
                offerExpiresAt: now.add(const Duration(hours: 6)),
                declinedAt: declined ? now : null,
              ),
            ],
          ),
        );

    test('pending and declined offers of an open booking', () {
      expect(
        studioOfferOf(offer(status: BookingStatus.accepted), now)?.state,
        StudioOfferState.pending,
      );
      expect(
        studioOfferOf(
          offer(status: BookingStatus.accepted, declined: true),
          now,
        )?.state,
        StudioOfferState.declined,
      );
    });

    test('a cancelled or completed booking has no offer line', () {
      for (final status in [
        BookingStatus.cancelled,
        BookingStatus.completed,
        BookingStatus.reviewed,
        BookingStatus.declined,
        BookingStatus.expired,
      ]) {
        expect(
          studioOfferOf(offer(status: status), now),
          isNull,
          reason: '$status',
        );
        expect(
          studioOfferOf(offer(status: status, declined: true), now),
          isNull,
          reason: '$status declined',
        );
      }
    });
  });
}
