import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _base() => {
  'customerId': 'c1',
  'photographerId': 'studio1',
  'serviceId': 's1',
  'serviceSnapshot': {'name': 'Gói', 'price': 2500000, 'durationMinutes': 120},
  'day': '2026-10-24',
  'start': '15:00',
  'end': '17:00',
  'place': {'name': 'Hà Nội'},
  'status': 'accepted',
  'deposit': 2500000,
  'remaining': 0,
  'createdAt': '2026-10-20T03:00:00.000Z',
  'updatedAt': '2026-10-20T03:00:00.000Z',
};

DateTime _utc(int d, int h, [int m = 0]) => DateTime.utc(2026, 10, d, h, m);
Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

void main() {
  group('bookingFromFirestore studio fields', () {
    test(
      'studio booking info maps assignee, deadline, change request, fault, returned',
      () {
        final b = bookingFromFirestore('b1', {
          ..._base(),
          'isStudio': true,
          'assigneeId': 'an',
          'assigneeKind': 'member',
          'assignStatus': 'assigned',
          'assignDeadline': _ts(_utc(23, 8)),
          'assignOverdue': true,
          'assignedAt': _ts(_utc(21, 2)),
          'assignments': [
            {
              'assigneeId': 'an',
              'assigneeKind': 'member',
              'at': _ts(_utc(21, 2)),
              'by': 'studio1',
              'reason': null,
              'late': false,
            },
            {'assigneeId': 'broken'},
          ],
          'assignRemindersSent': ['h48', 'h26', 'weird'],
          'changeRequest': {
            'at': _ts(_utc(22, 1)),
            'note': 'Muốn thợ nữ',
            'respondBy': _ts(_utc(22, 7)),
            'status': 'declined',
            'declineReason': 'Hết thợ nữ',
            'answeredAt': _ts(_utc(22, 3)),
          },
          'studioFault': {'kind': 'change_declined', 'at': _ts(_utc(22, 3))},
          'assignmentReturned': {'at': _ts(_utc(22, 5)), 'reason': 'Ốm'},
        })!;

        final s = b.studio!;
        expect(s.assigneeId, 'an');
        expect(s.assigneeKind, 'member');
        expect(s.assignStatus, StudioAssignStatus.assigned);
        expect(s.assignDeadline, _utc(23, 8));
        expect(s.assignOverdue, isTrue);
        expect(s.assignedAt, _utc(21, 2));
        expect(s.assignments, [
          StudioAssignment(assigneeId: 'an', at: _utc(21, 2), by: 'studio1'),
        ]);
        expect(s.remindersSent, ['h48', 'h26']);
        expect(
          s.changeRequest,
          StudioChangeRequest(
            at: _utc(22, 1),
            note: 'Muốn thợ nữ',
            respondBy: _utc(22, 7),
            status: ChangeRequestStatus.declined,
            declineReason: 'Hết thợ nữ',
            answeredAt: _utc(22, 3),
          ),
        );
        expect(
          s.studioFault,
          StudioFault(kind: StudioFaultKind.changeDeclined, at: _utc(22, 3)),
        );
        expect(s.returnedAt, _utc(22, 5));
        expect(s.returnReason, 'Ốm');
        expect(s.isAssigned, isTrue);
        expect(s.isReturned, isTrue);
      },
    );

    test('an unassigned studio booking has nulls and defaults', () {
      final b = bookingFromFirestore('b2', {
        ..._base(),
        'isStudio': true,
        'assigneeId': null,
        'assigneeKind': null,
        'assignStatus': 'unassigned',
        'assignDeadline': _ts(_utc(23, 8)),
        'assignOverdue': false,
        'assignedAt': null,
        'assignments': [],
        'changeRequest': null,
        'studioFault': null,
        'assignmentReturned': null,
      })!;
      final s = b.studio!;
      expect(s.assigneeId, isNull);
      expect(s.assignStatus, StudioAssignStatus.unassigned);
      expect(s.assignments, isEmpty);
      expect(s.changeRequest, isNull);
      expect(s.studioFault, isNull);
      expect(s.isReturned, isFalse);
    });

    test('a callable answer with ISO dates maps the same way', () {
      final b = bookingFromFirestore('b3', {
        ..._base(),
        'isStudio': true,
        'assigneeId': 'an',
        'assignStatus': 'assigned',
        'assignDeadline': '2026-10-23T08:00:00.000Z',
        'studioFault': {'kind': 'late_reassign', 'at': '2026-10-23T09:00:00.000Z'},
      })!;
      expect(b.studio!.assignDeadline, _utc(23, 8));
      expect(b.studio!.studioFault!.kind, StudioFaultKind.lateReassign);
    });

    test('a missing deadline reads as the start of the booking', () {
      final b = bookingFromFirestore('b4', {..._base(), 'isStudio': true})!;
      // 15:00 in Vietnam (UTC+7) on 2026-10-24.
      expect(b.studio!.assignDeadline, _utc(24, 8));
    });

    test('malformed fields are skipped, never drop the booking', () {
      final b = bookingFromFirestore('b7', {
        ..._base(),
        'isStudio': true,
        'assignDeadline': _ts(_utc(23, 8)),
        'assignments': [
          {'assigneeId': 'an', 'at': _ts(_utc(21, 2)), 'by': 42},
        ],
      });
      expect(b, isNotNull);
      expect(b!.studio!.assignments.single.by, '');
      // Without a deadline, non-string day/start give no studio info rather
      // than a type error.
      expect(
        studioBookingInfoFrom({'isStudio': true, 'day': 20261024, 'start': 9}),
        isNull,
      );
    });

    test('an individual booking has studio == null', () {
      expect(bookingFromFirestore('b5', _base())!.studio, isNull);
      expect(
        bookingFromFirestore('b6', {
          ..._base(),
          'isStudio': false,
          'assigneeId': 'an',
        })!.studio,
        isNull,
      );
    });
  });

  group('FirestoreBookingRepository studio callables', () {
    late _MockFunctions functions;
    late _MockCallable callable;
    late FirestoreBookingRepository repo;
    Object? sent;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      functions = _MockFunctions();
      callable = _MockCallable();
      sent = null;
      when(
        () => functions.httpsCallable(any(), options: any(named: 'options')),
      ).thenReturn(callable);
      final result = _MockResult();
      when(() => result.data).thenReturn({
        'id': 'b1',
        ..._base(),
        'isStudio': true,
        'assigneeId': 'an',
        'assignStatus': 'assigned',
        'assignDeadline': '2026-10-23T08:00:00.000Z',
      });
      when(() => callable.call<Object?>(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.single;
        return result;
      });
      repo = FirestoreBookingRepository(
        firestore: FakeFirebaseFirestore(),
        functions: functions,
      );
    });

    String calledName() =>
        verify(
              () => functions.httpsCallable(
                captureAny(),
                options: any(named: 'options'),
              ),
            ).captured.single
            as String;

    test('cancelStudioFault sends cancel_studio_fault', () async {
      expect(BookingAction.cancelStudioFault.code, 'cancel_studio_fault');
      await repo.transitionBooking(
        bookingId: 'b1',
        action: BookingAction.cancelStudioFault.code,
      );
      expect(calledName(), 'transitionBooking');
      expect(sent, {'bookingId': 'b1', 'action': 'cancel_studio_fault'});
    });

    test('assign sends {bookingId, assigneeId} and returns the booking', () async {
      final b = await repo.assign('b1', 'an');
      expect(calledName(), 'assignBooking');
      expect(sent, {'bookingId': 'b1', 'assigneeId': 'an'});
      expect(b.studio!.assigneeId, 'an');
    });

    test('requestChange sends the note only when given', () async {
      await repo.requestChange('b1', note: 'Muốn thợ nữ');
      expect(calledName(), 'requestAssigneeChange');
      expect(sent, {'bookingId': 'b1', 'note': 'Muốn thợ nữ'});
      clearInteractions(functions);
      await repo.requestChange('b1');
      expect(sent, {'bookingId': 'b1'});
    });

    test('declineChange sends {bookingId, reason}', () async {
      await repo.declineChange('b1', 'Hết thợ nữ');
      expect(calledName(), 'declineAssigneeChange');
      expect(sent, {'bookingId': 'b1', 'reason': 'Hết thợ nữ'});
    });

    test('returnAssignment sends the reason only when given', () async {
      await repo.returnAssignment('b1', reason: 'Ốm');
      expect(calledName(), 'returnAssignment');
      expect(sent, {'bookingId': 'b1', 'reason': 'Ốm'});
      clearInteractions(functions);
      await repo.returnAssignment('b1');
      expect(sent, {'bookingId': 'b1'});
    });

    test('a refusal surfaces the server code', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'day_taken',
          details: {'code': 'day_taken'},
        ),
      );
      await expectLater(
        repo.assign('b1', 'an'),
        throwsA(
          isA<BookingException>().having((e) => e.code, 'code', 'day_taken'),
        ),
      );
    });
  });
}
