import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_parties.dart';

import '../../support/booking_world.dart';
import '../../support/studio_world.dart';

const _copy = BookingContactSnapshot(
  name: 'Thanh Hà',
  phone: '+84903123456',
  allowZalo: false,
  allowWhatsApp: false,
);

const _mayStudio = AuthUser(uid: 'cuc', displayName: 'Studio Mây');
const _minh = AuthUser(uid: 'minh', displayName: 'Minh Trí');

/// S06.01 has no looping loader: pump a bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byKey(const Key('app-sheet')), matching: f);

/// The sheet's red confirm button labelled [label].
Finder _redButton(String label) => find.descendant(
  of: find.byKey(const Key('app-sheet')),
  matching: find.byWidgetPredicate((w) => w is AppButton && w.label == label),
);

bool _isRed(WidgetTester tester, Finder button) =>
    tester
        .widget<FilledButton>(
          find.descendant(of: button, matching: find.byType(FilledButton)),
        )
        .style
        ?.backgroundColor
        ?.resolve({}) ==
    AppColors.error;

Future<RecordingBookingRepository> _studio(
  WidgetTester tester,
  List<Booking> list, {
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  final repo = RecordingBookingRepository(clock: () => studioNow);
  for (final b in list) {
    repo
      ..seedBooking(b)
      ..seedContact(b.id, _copy);
  }
  await pumpBookingsTab(
    tester,
    uid: 'cuc',
    role: UserRole.photographer,
    bookings: repo,
    clock: TestClock(studioNow),
    otherUsers: const [_minh],
    textScale: textScale,
    viewSize: viewSize,
  );
  await _settle(tester);
  return repo;
}

void main() {
  group('studio owner (S06.01-studio)', () {
    testWidgets('an accepted unassigned studio booking shows Giao thợ and the '
        'deadline', (tester) async {
      await _studio(tester, [makeStudioBooking()]);

      expect(find.text('Thanh Hà · Gói chụp ngoại cảnh'), findsOneWidget);
      expect(find.text('T7 24/10 · 15:00–17:00'), findsOneWidget);
      expect(find.text('Hạn giao thợ: 15:00 T6 23/10'), findsOneWidget);
      expect(find.byKey(const Key('work-assign-sb1')), findsOneWidget);
      expect(find.text('Giao thợ'), findsOneWidget);
      expect(find.byKey(const Key('work-assign-overdue')), findsNothing);
    });

    testWidgets('an overdue one shows Quá hạn giao thợ', (tester) async {
      final b = makeStudioBooking();
      await _studio(tester, [
        b.copyWith(
          studio: b.studio!.copyWith(
            assignDeadline: DateTime.utc(2026, 10, 21),
          ),
        ),
      ]);

      final overdue = find.byKey(const Key('work-assign-overdue'));
      expect(overdue, findsOneWidget);
      expect(find.text('Quá hạn giao thợ'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Quá hạn giao thợ')).style?.color,
        AppColorsDark.destructive,
      );
      expect(find.textContaining('Hạn giao thợ:'), findsNothing);
    });

    testWidgets('an assigned one shows Thợ: Minh Trí', (tester) async {
      await _studio(tester, [makeStudioBooking(assigneeId: 'minh')]);

      expect(find.text('Thợ: Minh Trí'), findsOneWidget);
      expect(find.textContaining('Hạn giao thợ'), findsNothing);
      // "Giao thợ" also changes who shoots.
      expect(find.byKey(const Key('work-assign-sb1')), findsOneWidget);
    });

    testWidgets('a returned job shows {name} đã trả việc in red so the studio '
        'reassigns', (tester) async {
      final b = makeStudioBooking(assigneeId: 'minh');
      await _studio(tester, [
        b.copyWith(studio: b.studio!.copyWith(returnedAt: studioNow)),
      ]);

      final line = find.byKey(const Key('work-assignee-returned'));
      expect(line, findsOneWidget);
      expect(find.text('Minh Trí đã trả việc'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Minh Trí đã trả việc')).style?.color,
        AppColorsDark.destructive,
      );
      expect(find.text('Thợ: Minh Trí'), findsNothing);
      expect(find.byKey(const Key('work-assign-sb1')), findsOneWidget);
    });

    testWidgets('a returned job without a known name reads Thợ đã trả việc', (
      tester,
    ) async {
      final b = makeStudioBooking(assigneeId: 'ghost');
      await _studio(tester, [
        b.copyWith(studio: b.studio!.copyWith(returnedAt: studioNow)),
      ]);

      expect(find.text('Thợ đã trả việc'), findsOneWidget);
    });

    testWidgets('a pending change shows the request row; Từ chối đổi needs a '
        'reason in a red sheet', (tester) async {
      final b = makeStudioBooking(assigneeId: 'minh');
      final repo = await _studio(tester, [
        b.copyWith(
          studio: b.studio!.copyWith(
            changeRequest: StudioChangeRequest(
              at: studioNow,
              // 14:00 in Vietnam.
              respondBy: DateTime.utc(2026, 10, 21, 7),
            ),
          ),
        ),
      ]);

      expect(
        find.text('Khách xin đổi thợ · trả lời trước 14:00'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('work-change-decline-sb1')));
      await _settle(tester);

      expect(_inSheet(find.text('Từ chối đổi thợ?')), findsOneWidget);
      expect(_inSheet(find.text('Lý do (bắt buộc)')), findsOneWidget);
      final confirm = _redButton('Từ chối đổi');
      expect(_isRed(tester, confirm), isTrue);
      expect(tester.widget<AppButton>(confirm).onPressed, isNull);

      await tester.enterText(
        _inSheet(find.byKey(const Key('studio-reason'))),
        '  Minh Trí đã chụp buổi thử  ',
      );
      await tester.pump();
      expect(tester.widget<AppButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await _settle(tester);

      expect(find.byKey(const Key('app-sheet')), findsNothing);
      final (call, payload) = repo.studioCalls.single;
      expect(call, 'declineAssigneeChange');
      expect(payload, {
        'bookingId': 'sb1',
        'reason': 'Minh Trí đã chụp buổi thử',
      });
      // Answered: the request row is gone.
      expect(find.byKey(const Key('work-change-request')), findsNothing);
    });

    testWidgets('Giao thợ opens S26.04', (tester) async {
      await _studio(tester, [makeStudioBooking()]);
      await tester.tap(find.byKey(const Key('work-assign-sb1')));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is ScreenCode && w.code == ScreenCodes.assignPhotographer,
        ),
        findsOneWidget,
      );
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      final b = makeStudioBooking(assigneeId: 'minh');
      await _studio(
        tester,
        [
          makeStudioBooking(id: 'sb2'),
          b.copyWith(
            studio: b.studio!.copyWith(
              changeRequest: StudioChangeRequest(
                at: studioNow,
                respondBy: DateTime.utc(2026, 10, 21, 7),
              ),
            ),
          ),
        ],
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('assigned member (S06.01-member)', () {
    Booking job() => makeStudioBooking(assigneeId: 'minh');

    Future<RecordingBookingRepository> member(
      WidgetTester tester, {
      Booking? assigned,
    }) async {
      final repo = RecordingBookingRepository(clock: () => studioNow);
      // A personal request of the member, beside the studio's job.
      final own =
          makeStudioBooking(
            id: 'own1',
            photographerId: 'minh',
            status: BookingStatus.requested,
          ).copyWith(
            studio: null,
            acceptDeadline: studioNow.add(const Duration(hours: 20)),
          );
      repo
        ..seedBooking(own)
        ..seedContact(own.id, _copy)
        ..seedContact('sb1', _copy)
        ..emitAssigned([assigned ?? job()]);
      await pumpBookingsTab(
        tester,
        uid: 'minh',
        role: UserRole.photographer,
        bookings: repo,
        clock: TestClock(studioNow),
        otherUsers: const [_mayStudio],
      );
      await _settle(tester);
      return repo;
    }

    testWidgets('a member sees studio jobs tagged Giao bởi Studio Mây beside '
        'personal jobs', (tester) async {
      await member(tester);

      expect(find.byKey(const Key('work-job-sb1')), findsOneWidget);
      expect(find.text('Giao bởi Studio Mây'), findsOneWidget);
      expect(find.text('ĐÃ GIAO'), findsOneWidget);
      expect(find.byKey(const Key('work-return-sb1')), findsOneWidget);
      // The personal request stays a request; the studio's job is not one.
      expect(find.text('Yêu cầu mới'), findsOneWidget);
      expect(find.byKey(const ValueKey('own1')), findsOneWidget);
      expect(find.byKey(const ValueKey('sb1')), findsNothing);
      // Only the studio staffs it.
      expect(find.byKey(const Key('work-assign-sb1')), findsNothing);
    });

    testWidgets('Trả việc confirms in a red sheet and shows Đã trả việc · chờ '
        'studio giao lại', (tester) async {
      final repo = await member(tester);

      await tester.tap(find.byKey(const Key('work-return-sb1')));
      await _settle(tester);
      expect(_inSheet(find.text('Trả lại buổi chụp này?')), findsOneWidget);
      expect(
        _inSheet(
          find.text(
            'Studio Mây được báo để giao người khác. Bạn vẫn là thợ của buổi '
            'này tới khi studio giao lại.',
          ),
        ),
        findsOneWidget,
      );
      expect(_inSheet(find.text('Lý do (tuỳ chọn)')), findsOneWidget);
      final confirm = _redButton('Trả việc');
      expect(_isRed(tester, confirm), isTrue);
      await tester.tap(confirm);
      await _settle(tester);

      final (call, payload) = repo.studioCalls.single;
      expect(call, 'returnAssignment');
      expect(payload, {'bookingId': 'sb1'});
      expect(find.text('Đã trả việc · chờ studio giao lại'), findsOneWidget);
      expect(find.byKey(const Key('work-return-sb1')), findsNothing);
      expect(find.text('Giao bởi Studio Mây'), findsOneWidget);
    });

    testWidgets('a returned job shows no button from the start', (
      tester,
    ) async {
      final b = job();
      await member(
        tester,
        assigned: b.copyWith(studio: b.studio!.copyWith(returnedAt: studioNow)),
      );

      expect(find.text('Đã trả việc · chờ studio giao lại'), findsOneWidget);
      expect(find.byKey(const Key('work-return-sb1')), findsNothing);
      expect(find.text('ĐÃ GIAO'), findsNothing);
    });
  });

  testWidgets('the assignee\'s booking detail has no delivery entry', (
    tester,
  ) async {
    final repo = RecordingBookingRepository(clock: () => studioNow)
      ..seedBooking(
        makeStudioBooking(
          id: 'b1',
          assigneeId: 'minh',
          status: BookingStatus.shot,
        ),
      );
    await pumpBookingDetail(
      tester,
      uid: 'minh',
      bookings: repo,
      clock: TestClock(studioNow),
    );
    await _settle(tester);

    // The assignee sees the booking (not "not found")...
    expect(find.textContaining('Gói chụp ngoại cảnh'), findsWidgets);
    // ...but delivering, cancelling and assigning are the studio's.
    expect(find.text('Nộp bàn giao'), findsNothing);
    expect(find.byKey(const Key('detail-assign')), findsNothing);
    expect(find.textContaining('Huỷ'), findsNothing);
  });

  testWidgets('the studio\'s booking detail has Giao thợ', (tester) async {
    final repo = RecordingBookingRepository(clock: () => studioNow)
      ..seedBooking(makeStudioBooking(id: 'b1'));
    await pumpBookingDetail(
      tester,
      uid: 'cuc',
      bookings: repo,
      clock: TestClock(studioNow),
    );
    await _settle(tester);

    expect(find.byKey(const Key('detail-assign')), findsOneWidget);
  });

  group('Trả việc on S05.02 (assignee)', () {
    Future<RecordingBookingRepository> detail(
      WidgetTester tester,
      Booking b, {
      String uid = 'minh',
      DateTime? now,
    }) async {
      final repo = RecordingBookingRepository(clock: () => now ?? studioNow)
        ..seedBooking(b);
      await pumpBookingDetail(
        tester,
        uid: uid,
        bookings: repo,
        clock: TestClock(now ?? studioNow),
        extraOverrides: [
          partyProfileProvider.overrideWith((ref, id) async* {
            yield UserProfile(
              uid: id,
              displayName: id == 'cuc' ? 'Studio Mây' : 'Thanh Hà',
              avatarUrl: null,
              role: UserRole.photographer,
            );
          }),
        ],
      );
      await _settle(tester);
      return repo;
    }

    final returnJob = find.byKey(const Key('detail-return-job'));

    testWidgets('before the start: the red text opens the sheet and hands the '
        'job back', (tester) async {
      final repo = await detail(
        tester,
        makeStudioBooking(id: 'b1', assigneeId: 'minh'),
      );

      expect(returnJob, findsOneWidget);
      await tester.ensureVisible(returnJob);
      await tester.tap(returnJob);
      await _settle(tester);
      expect(_inSheet(find.text('Trả lại buổi chụp này?')), findsOneWidget);
      expect(
        _inSheet(find.textContaining('Studio Mây được báo')),
        findsOneWidget,
      );
      await tester.tap(_redButton('Trả việc'));
      await _settle(tester);

      final (call, payload) = repo.studioCalls.single;
      expect(call, 'returnAssignment');
      expect(payload, {'bookingId': 'b1'});
      expect(returnJob, findsNothing);
    });

    testWidgets('hidden once returned', (tester) async {
      final b = makeStudioBooking(id: 'b1', assigneeId: 'minh');
      await detail(
        tester,
        b.copyWith(studio: b.studio!.copyWith(returnedAt: studioNow)),
      );
      expect(returnJob, findsNothing);
    });

    testWidgets('hidden from the start on', (tester) async {
      final b = makeStudioBooking(id: 'b1', assigneeId: 'minh');
      await detail(tester, b, now: startsAtOf(b));
      expect(returnJob, findsNothing);
    });

    testWidgets('never for the studio itself', (tester) async {
      final b = makeStudioBooking(id: 'b1', assigneeId: 'minh');
      await detail(tester, b, uid: 'cuc');
      expect(returnJob, findsNothing);
      expect(find.byKey(const Key('detail-assign')), findsOneWidget);
    });
  });
}
