import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';

void main() {
  group('Delivery mapping', () {
    test('Booking.fromFirestore reads delivery fields, statuses and extraRound', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {
          'name': 'Gói chụp',
          'price': 1500000,
          'durationMinutes': 120,
        },
        'day': '2026-10-20',
        'start': '08:00',
        'end': '10:00',
        'place': {'name': 'Hồ Gươm'},
        'status': 'delivered',
        'deposit': 1500000,
        'remaining': 0,
        'shotAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20, 10, 0)),
        'deliveredAt': Timestamp.fromDate(DateTime.utc(2026, 10, 21, 12, 0)),
        'approvedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 22, 14, 0)),
        'checkUntil': Timestamp.fromDate(DateTime.utc(2026, 10, 24, 14, 0)),
        'autoApproveAt': Timestamp.fromDate(DateTime.utc(2026, 10, 24, 12, 0)),
        'autoApproveNoticeAt':
            Timestamp.fromDate(DateTime.utc(2026, 10, 23, 12, 0)),
        'samplesPurgeAfter':
            Timestamp.fromDate(DateTime.utc(2026, 11, 24, 14, 0)),
        'deliveryRound': 2,
        'revisionsIncluded': 2,
        'revisionsUsed': 1,
        'revisionsGranted': 1,
        'samplesPurged': false,
        'extraRound': {
          'at':
              Timestamp.fromDate(DateTime.utc(2026, 10, 21, 15, 0)),
          'status': 'pending',
        },
      };

      final b = bookingFromFirestore('b1', docData);
      expect(b, isNotNull);
      expect(b!.status, BookingStatus.delivered);
      expect(b.deliveryRound, 2);
      expect(b.revisionsIncluded, 2);
      expect(b.revisionsUsed, 1);
      expect(b.revisionsGranted, 1);
      expect(b.shotAt, DateTime.utc(2026, 10, 20, 10, 0));
      expect(b.deliveredAt, DateTime.utc(2026, 10, 21, 12, 0));
      expect(b.approvedAt, DateTime.utc(2026, 10, 22, 14, 0));
      expect(b.checkUntil, DateTime.utc(2026, 10, 24, 14, 0));
      expect(b.autoApproveAt, DateTime.utc(2026, 10, 24, 12, 0));
      expect(b.autoApproveNoticeAt, DateTime.utc(2026, 10, 23, 12, 0));
      expect(b.samplesPurgeAfter, DateTime.utc(2026, 11, 24, 14, 0));
      expect(b.samplesPurged, isFalse);
      expect(b.extraRound, isNotNull);
      expect(b.extraRound!.status, 'pending');
      expect(b.extraRound!.at, DateTime.utc(2026, 10, 21, 15, 0));
    });

    test('Booking.fromFirestore without delivery fields defaults safely', () {
      final docData = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {
          'name': 'Gói chụp',
          'price': 1500000,
          'durationMinutes': 120,
        },
        'day': '2026-10-20',
        'start': '08:00',
        'end': '10:00',
        'place': {'name': 'Hồ Gươm'},
        'status': 'accepted',
        'deposit': 1500000,
        'remaining': 0,
      };

      final b = bookingFromFirestore('b1', docData);
      expect(b, isNotNull);
      expect(b!.deliveryRound, 0);
      expect(b.revisionsIncluded, 1);
      expect(b.revisionsUsed, 0);
      expect(b.revisionsGranted, 0);
      expect(b.extraRound, isNull);
    });

    test('deliveryRoundFromFirestore reads samples, linkHost, decision', () {
      final roundData = <String, dynamic>{
        'bookingId': 'b1',
        'round': 1,
        'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20, 10, 0)),
        'submittedBy': 'p1',
        'samples': [
          {
            'fileId': 'f1',
            'path': 'deliveries/b1/f1.jpg',
            'thumbPath': 'deliveries/b1/f1_t.jpg',
            'width': 1600,
            'height': 1200,
          },
          {
            'fileId': 'f2',
            'path': 'deliveries/b1/f2.jpg',
            'thumbPath': '',
            'width': 1200,
            'height': 1600,
          },
        ],
        'linkHost': 'drive.google.com',
        'photoCount': 50,
        'note': 'Ảnh đẹp',
        'decision': {
          'kind': 'request_revision',
          'at': Timestamp.fromDate(DateTime.utc(2026, 10, 21, 8, 0)),
          'note': 'Sửa màu da',
          'photoNotes': [
            {'sampleIndex': 0, 'note': 'Làm sáng hơn'},
          ],
        },
      };

      final r = deliveryRoundFromFirestore(roundData);
      expect(r, isNotNull);
      expect(r!.round, 1);
      expect(r.bookingId, 'b1');
      expect(r.linkHost, 'drive.google.com');
      expect(r.photoCount, 50);
      expect(r.note, 'Ảnh đẹp');
      expect(r.samples, hasLength(2));
      expect(r.samples[0].fileId, 'f1');
      expect(r.samples[0].thumbPath, 'deliveries/b1/f1_t.jpg');
      expect(r.decision, isNotNull);
      expect(r.decision!.kind, 'request_revision');
      expect(r.decision!.note, 'Sửa màu da');
      expect(r.decision!.photoNotes, hasLength(1));
      expect(r.decision!.photoNotes[0].sampleIndex, 0);
      expect(r.decision!.photoNotes[0].note, 'Làm sáng hơn');
    });

    test('deliveryLinkFromFirestore reads link, round, unlockedAt', () {
      final linkData = <String, dynamic>{
        'link': 'https://drive.google.com/test',
        'round': 1,
        'unlockedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 22, 14, 0)),
      };
      final link = deliveryLinkFromFirestore(linkData);
      expect(link, isNotNull);
      expect(link!.link, 'https://drive.google.com/test');
      expect(link.round, 1);
      expect(link.unlockedAt, DateTime.utc(2026, 10, 22, 14, 0));
    });

    test('stagedSampleFromFirestore reads ready and failed', () {
      final ready = stagedSampleFromFirestore('f_ready', {
        'status': 'ready',
        'path': 'deliveries/b1/f_ready.jpg',
        'thumbPath': 'deliveries/b1/f_ready_t.jpg',
      });
      expect(ready, isNotNull);
      expect(ready!.status, SampleStatus.ready);
      expect(ready.thumbPath, 'deliveries/b1/f_ready_t.jpg');

      final failed = stagedSampleFromFirestore('f_fail', {
        'status': 'failed',
        'failure': 'unsupported',
      });
      expect(failed, isNotNull);
      expect(failed!.status, SampleStatus.failed);
      expect(failed.failure, 'unsupported');
    });

    test('deliveryErrorOf maps errors correctly', () {
      expect(
        deliveryErrorOf(const DeliveryException('not_ready')),
        DeliveryErrorCode.notReady,
      );
      expect(
        deliveryErrorOf(const DeliveryException('not_eligible')),
        DeliveryErrorCode.notEligible,
      );
      expect(
        deliveryErrorOf(const DeliveryException('conflict')),
        DeliveryErrorCode.conflict,
      );
      expect(
        deliveryErrorOf(const DeliveryException('permission_denied')),
        DeliveryErrorCode.permissionDenied,
      );
      expect(
        deliveryErrorOf(const DeliveryException('unavailable')),
        DeliveryErrorCode.network,
      );
      expect(
        deliveryErrorOf(const DeliveryException('unknown_code')),
        DeliveryErrorCode.unknown,
      );
    });
  });
}
