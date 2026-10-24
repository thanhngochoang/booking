import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/collab/collaboration.dart';
import 'package:photobooking/data/collab/firestore_collab_repository.dart';

final _t0 = DateTime.utc(2026, 10, 10, 3);

/// `studio_collaborations/{studioId}_{uid}` as Task 5's `collaborationToDoc`
/// writes it.
Map<String, dynamic> collaborationDoc({Object? status = 'active'}) => {
  'studioId': 'cuc',
  'collaboratorId': 'dung',
  'studio': {'name': 'Studio Cúc', 'avatarUrl': 'https://x.test/c.jpg'},
  'collaborator': {'name': 'Dũng', 'avatarUrl': null},
  'status': status,
  'initiatedBy': 'studio',
  'applicationId': null,
  'defaultFee': 600000,
  'termsAcceptedAt': Timestamp.fromDate(_t0),
  'createdAt': Timestamp.fromDate(_t0.subtract(const Duration(days: 1))),
  'expiresAt': Timestamp.fromDate(_t0.add(const Duration(days: 6))),
  'activeAt': Timestamp.fromDate(_t0),
  'endedAt': null,
  'endedBy': null,
  'updatedAt': Timestamp.fromDate(_t0),
};

/// `collab_jobs/{bookingId}_{uid}` as `collabJobToDoc` writes it.
Map<String, dynamic> collabJobDoc({
  Object? offerStatus = 'accepted',
  Object? payStatus = 'paid_reported',
  String bookingId = 'b1',
  Object? dueAt,
}) => {
  'bookingId': bookingId,
  'studioId': 'cuc',
  'collaboratorId': 'dung',
  'customerId': 'lan',
  'studioName': 'Studio Cúc',
  'collaboratorName': 'Dũng',
  'shoot': {
    'day': '2026-10-24',
    'start': '15:00',
    'end': '17:00',
    'serviceName': 'Gói gia đình',
    'placeName': 'Công viên Tao Đàn',
  },
  'shootEndsAt': Timestamp.fromDate(DateTime.utc(2026, 10, 24, 10)),
  'agreedFee': 600000,
  'offerStatus': offerStatus,
  'offerAt': Timestamp.fromDate(_t0),
  'offerExpiresAt': Timestamp.fromDate(_t0.add(const Duration(hours: 6))),
  'acceptedAt': Timestamp.fromDate(_t0.add(const Duration(hours: 1))),
  'declinedAt': null,
  'closedAt': null,
  'payStatus': payStatus,
  'pay': {
    'amount': 600000,
    'dueAt': dueAt ?? Timestamp.fromDate(DateTime.utc(2026, 10, 25)),
    'paidOn': '2026-10-26',
    'method': 'bank',
    'reportedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 26, 4)),
    'receivedAt': null,
    'disputedAt': null,
    'overdueFlaggedAt': null,
    'disputeFlaggedAt': null,
    'checkAfter': null,
  },
  'createdAt': Timestamp.fromDate(_t0),
  'updatedAt': Timestamp.fromDate(_t0),
};

void main() {
  group('collaborationFrom', () {
    test('collaborationFrom parses every field', () {
      final c = collaborationFrom('cuc_dung', collaborationDoc())!;
      expect(c.id, 'cuc_dung');
      expect(c.studioId, 'cuc');
      expect(c.collaboratorId, 'dung');
      expect(c.studioName, 'Studio Cúc');
      expect(c.studioAvatarUrl, 'https://x.test/c.jpg');
      expect(c.collaboratorName, 'Dũng');
      expect(c.collaboratorAvatarUrl, isNull);
      expect(c.status, CollabStatus.active);
      expect(c.defaultFee, 600000);
      expect(c.activeAt, _t0);
      expect(c.expiresAt, _t0.add(const Duration(days: 6)));
      expect(c.endedAt, isNull);
    });

    test('an unknown status or a missing party drops the row', () {
      expect(collaborationFrom('x', collaborationDoc(status: 'x')), isNull);
      expect(
        collaborationFrom('x', {...collaborationDoc(), 'studioId': null}),
        isNull,
      );
      for (final s in CollabStatus.values) {
        expect(
          collaborationFrom('x', collaborationDoc(status: s.code))!.status,
          s,
        );
      }
      expect(
        collaborationFrom('x', {
          ...collaborationDoc(),
          'defaultFee': null,
        })!.defaultFee,
        isNull,
      );
    });
  });

  group('collabJobFrom', () {
    test(
      'collabJobFrom: pay nested, paid_reported → PayStatus.paidReported',
      () {
        final j = collabJobFrom('b1_dung', collabJobDoc())!;
        expect(j.id, 'b1_dung');
        expect(j.bookingId, 'b1');
        expect(j.studioId, 'cuc');
        expect(j.collaboratorId, 'dung');
        expect(j.studioName, 'Studio Cúc');
        expect(j.collaboratorName, 'Dũng');
        expect(j.day, '2026-10-24');
        expect(j.start, '15:00');
        expect(j.end, '17:00');
        expect(j.serviceName, 'Gói gia đình');
        expect(j.placeName, 'Công viên Tao Đàn');
        expect(j.agreedFee, 600000);
        expect(j.offerStatus, OfferStatus.accepted);
        expect(j.offerExpiresAt, _t0.add(const Duration(hours: 6)));
        expect(j.acceptedAt, _t0.add(const Duration(hours: 1)));
        expect(j.payStatus, PayStatus.paidReported);
        expect(j.payDueAt, DateTime.utc(2026, 10, 25));
        expect(j.paidOn, '2026-10-26');
        expect(j.payMethod, CollabPayMethod.bank);
        expect(j.reportedAt, DateTime.utc(2026, 10, 26, 4));
      },
    );

    test(
      'codes round-trip; unknown pay status is none; unknown offer drops',
      () {
        for (final s in PayStatus.values) {
          expect(
            collabJobFrom('x', collabJobDoc(payStatus: s.code))!.payStatus,
            s,
          );
        }
        expect(PayStatus.paidReported.code, 'paid_reported');
        expect(
          collabJobFrom('x', collabJobDoc(payStatus: 'weird'))!.payStatus,
          PayStatus.none,
        );
        for (final s in OfferStatus.values) {
          expect(
            collabJobFrom('x', collabJobDoc(offerStatus: s.code))!.offerStatus,
            s,
          );
        }
        expect(collabJobFrom('x', collabJobDoc(offerStatus: 'weird')), isNull);
        final noPay = collabJobFrom('x', {...collabJobDoc(), 'pay': null})!;
        expect(noPay.payDueAt, isNull);
        expect(noPay.payMethod, isNull);
        expect(noPay.paidOn, isNull);
      },
    );
  });
}
