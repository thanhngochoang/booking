// test/data/jobs/job_mapping_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/quote.dart';

void main() {
  group('Job mapping', () {
    test('a job document maps every field', () {
      final now = DateTime.utc(2026, 10, 20, 10, 0);
      final docData = <String, dynamic>{
        'customerId': 'cust_1',
        'customer': {
          'name': 'Nguyễn Văn A',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'hireCount': 3,
          'phoneVerified': true,
        },
        'specialtyId': 'portrait',
        'title': 'Chụp ảnh chân dung ngoại cảnh',
        'description': 'Cần tìm thợ chụp ảnh chân dung tại phố đi bộ',
        'references': [
          {'url': 'https://example.com/ref1.jpg', 'path': 'jobRefs/cust_1/draft1/1.jpg'},
        ],
        'schedule': {
          'kind': 'fixed',
          'day': '2026-10-25',
          'start': '08:00',
          'end': '10:00',
          'durationMinutes': 120,
        },
        'dayFrom': '2026-10-25',
        'dayTo': '2026-10-25',
        'area': {
          'areaId': 'hcm-q1',
          'name': 'Quận 1, TP.HCM',
          'city': 'TP.HCM',
          'cityKey': 'tphcm',
          'lat': 10.7769,
          'lng': 106.7009,
          'geohash5': 'w4rqp',
        },
        'budget': {
          'min': 1000000,
          'max': 2000000,
        },
        'wants': {
          'editedCount': 20,
          'deliveryDays': 5,
        },
        'allowedProviders': 'all',
        'quoteDeadline': Timestamp.fromDate(now.add(const Duration(days: 3))),
        'extended': false,
        'status': 'open',
        'quoteCount': 2,
        'newQuoteCount': 1,
        'viewCount': 10,
        'inviteCount': 1,
        'matchCount': 5,
        'recentQuoters': [
          {'photographerId': 'photo_1', 'avatarUrl': 'https://example.com/p1.jpg'},
        ],
        'awardedQuoteId': null,
        'bookingId': null,
        'awardedTo': null,
        'checkout': {
          'quoteId': 'photo_1',
          'bookingId': 'b_1',
          'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 30))),
        },
        'expiringNotifiedAt': null,
        'closedAt': null,
        'referencesPurgeAfter': null,
        'quotesSeenAt': null,
        'version': 1,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final job = Job.fromFirestore('job_123', docData);
      expect(job, isNotNull);
      expect(job!.id, 'job_123');
      expect(job.customerId, 'cust_1');
      expect(job.customer.name, 'Nguyễn Văn A');
      expect(job.customer.phoneVerified, true);
      expect(job.specialtyId, 'portrait');
      expect(job.title, 'Chụp ảnh chân dung ngoại cảnh');
      expect(job.references.length, 1);
      expect(job.references.first.path, 'jobRefs/cust_1/draft1/1.jpg');
      expect(job.schedule.kind, ScheduleKind.fixed);
      expect(job.schedule.durationMinutes, 120);
      expect(job.budget?.max, 2000000);
      expect(job.wants.editedCount, 20);
      expect(job.checkout?.bookingId, 'b_1');
      expect(job.status, JobStatus.open);

      // Flexible schedule & null budget roundtrip
      final flexData = Map<String, dynamic>.from(docData);
      flexData['schedule'] = {
        'kind': 'flexible',
        'from': '2026-10-25',
        'to': '2026-10-30',
        'durationMinutes': 60,
      };
      flexData['budget'] = null;
      final flexJob = Job.fromFirestore('job_flex', flexData);
      expect(flexJob, isNotNull);
      expect(flexJob!.schedule.kind, ScheduleKind.flexible);
      expect(flexJob.schedule.from, '2026-10-25');
      expect(flexJob.schedule.to, '2026-10-30');
      expect(flexJob.budget, isNull);
    });

    test('a quote document maps terms, proposal, album and snapshot', () {
      final now = DateTime.utc(2026, 10, 20, 10, 0);
      final docData = <String, dynamic>{
        'jobId': 'job_123',
        'photographerId': 'photo_1',
        'customerId': 'cust_1',
        'jobTitle': 'Chụp ảnh chân dung',
        'photographer': {
          'name': 'Studio Mây',
          'avatarUrl': 'https://example.com/may.jpg',
          'providerType': 'studio',
          'verified': true,
          'tomatoPct': 95,
          'score': 0.85,
          'reviewCount': 50,
          'completedCount': 100,
          'approvedAwardCount': 2,
          'studioDistrict': 'Quận 1',
        },
        'basedOnServiceId': 'svc_1',
        'terms': {
          'price': 1500000,
          'durationMinutes': 90,
          'photoCount': 50,
          'editedCount': 15,
          'deliveryDays': 3,
          'revisions': 2,
          'milestones': [
            {'kind': 'shoot', 'percent': 50},
            {'kind': 'delivery', 'percent': 50},
          ],
        },
        'milestoneAmounts': {
          'shoot': 750000,
          'delivery': 750000,
        },
        'proposal': {
          'day': '2026-10-26',
          'start': '09:00',
          'end': '10:30',
        },
        'message': 'Em gửi báo giá chụp gói cơ bản nhé!',
        'albumId': 'alb_1',
        'album': {
          'title': 'Album Chân Dung',
          'coverUrl': 'https://example.com/cover.jpg',
          'postCount': 12,
        },
        'invited': true,
        'fit': 92,
        'status': 'submitted',
        'notSelectedReason': null,
        'autoWithdrawn': false,
        'declineReason': null,
        'bookingId': null,
        'withdrawnAt': null,
        'version': 1,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final quote = Quote.fromFirestore('photo_1', docData);
      expect(quote, isNotNull);
      expect(quote!.photographer.providerType, ProviderType.studio);
      expect(quote.terms.price, 1500000);
      expect(quote.milestoneAmounts.shoot, 750000);
      expect(quote.proposal.day, '2026-10-26');
      expect(quote.album?.title, 'Album Chân Dung');
      expect(quote.fit, 92);
      expect(quote.invited, true);
      expect(quote.status, QuoteStatus.submitted);
    });

    test('unknown enum codes map to safe values (status -> closed, providerType -> individual)', () {
      final docData = <String, dynamic>{
        'status': 'unknown_future_status',
        'allowedProviders': 'unknown_provider_code',
      };
      final job = Job.fromFirestore('job_safe', docData);
      expect(job, isNotNull);
      expect(job!.status, JobStatus.closed);
      expect(job.allowedProviders, AllowedProviders.all);

      final qData = <String, dynamic>{
        'photographer': {
          'providerType': 'unknown_type',
        },
        'status': 'future_quote_status',
      };
      final quote = Quote.fromFirestore('photo_safe', qData);
      expect(quote, isNotNull);
      expect(quote!.photographer.providerType, ProviderType.individual);
      expect(quote.status, QuoteStatus.submitted);
    });

    test('a booking with source quote maps jobId and quoteId; without source it is package', () {
      final base = <String, dynamic>{
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'serviceSnapshot': {'name': 'Gói ảnh', 'price': 1000000, 'durationMinutes': 60},
        'day': '2026-10-20',
        'start': '08:00',
        'end': '09:00',
        'place': {'name': 'Quận 1'},
        'status': 'accepted',
        'deposit': 1000000,
        'remaining': 0,
      };

      final bookingNoSource = bookingFromFirestore('b1', base);
      expect(bookingNoSource, isNotNull);
      expect(bookingNoSource!.source, isNull);
      expect(bookingNoSource.jobId, isNull);
      expect(bookingNoSource.quoteId, isNull);

      final quoteBooking = bookingFromFirestore('b2', {
        ...base,
        'source': 'quote',
        'jobId': 'job_123',
        'quoteId': 'quote_456',
      });
      expect(quoteBooking, isNotNull);
      expect(quoteBooking!.source, 'quote');
      expect(quoteBooking.jobId, 'job_123');
      expect(quoteBooking.quoteId, 'quote_456');
    });
  });
}
