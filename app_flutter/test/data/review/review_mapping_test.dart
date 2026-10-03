import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_repository.dart';
import 'package:photobooking/data/review/firestore_review_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> makeDoc(
    String path,
    Map<String, dynamic>? data,
  ) async {
    final ref = firestore.doc(path);
    if (data != null) {
      await ref.set(data);
    }
    return ref.get();
  }

  group('Review.fromFirestore', () {
    test('parses full review document with Timestamps', () async {
      final now = DateTime(2026, 10, 3, 12, 0, 0);
      final doc = await makeDoc('reviews/book_1', {
        'customerId': 'cust_1',
        'photographerId': 'photog_1',
        'serviceId': 'srv_1',
        'rating': 5,
        'text': 'Ảnh rất đẹp và chuyên nghiệp!',
        'photoPostId': 'post_1',
        'createdAt': Timestamp.fromDate(now),
      });

      final review = Review.fromFirestore(doc);
      expect(review.bookingId, 'book_1');
      expect(review.customerId, 'cust_1');
      expect(review.photographerId, 'photog_1');
      expect(review.serviceId, 'srv_1');
      expect(review.rating, 5);
      expect(review.text, 'Ảnh rất đẹp và chuyên nghiệp!');
      expect(review.photoPostId, 'post_1');
      expect(review.createdAt, now);
    });

    test('parses review with ISO string date and null photoPostId', () async {
      final doc = await makeDoc('reviews/book_2', {
        'customerId': 'cust_2',
        'photographerId': 'photog_2',
        'serviceId': 'srv_2',
        'rating': 4,
        'text': 'Tốt',
        'createdAt': '2026-10-02T15:30:00.000Z',
      });

      final review = Review.fromFirestore(doc);
      expect(review.bookingId, 'book_2');
      expect(review.customerId, 'cust_2');
      expect(review.photographerId, 'photog_2');
      expect(review.serviceId, 'srv_2');
      expect(review.rating, 4);
      expect(review.text, 'Tốt');
      expect(review.photoPostId, isNull);
      expect(review.createdAt, DateTime.parse('2026-10-02T15:30:00.000Z'));
    });

    test('handles empty or missing data with default values', () async {
      final doc = await makeDoc('reviews/empty_doc', null);
      final review = Review.fromFirestore(doc);
      expect(review.bookingId, 'empty_doc');
      expect(review.customerId, '');
      expect(review.photographerId, '');
      expect(review.serviceId, '');
      expect(review.rating, 5);
      expect(review.text, '');
      expect(review.photoPostId, isNull);
      expect(review.createdAt, isA<DateTime>());
    });

    test('equality and hashCode match for identical instances', () {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final r1 = Review(
        bookingId: 'b1',
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 's1',
        rating: 5,
        text: 'Tuyệt',
        photoPostId: 'post1',
        createdAt: now,
      );
      final r2 = Review(
        bookingId: 'b1',
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 's1',
        rating: 5,
        text: 'Tuyệt',
        photoPostId: 'post1',
        createdAt: now,
      );
      final r3 = Review(
        bookingId: 'b2',
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 's1',
        rating: 4,
        text: 'Tuyệt',
        photoPostId: null,
        createdAt: now,
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });
  });

  group('ReviewPhoto', () {
    test('toMap includes all properties when set', () {
      const photo = ReviewPhoto(
        url: 'https://storage.googleapis.com/test/photo1.jpg',
        storagePath: 'reviews/photo1.jpg',
        blurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        width: 1920,
        height: 1080,
      );

      final map = photo.toMap();
      expect(map['url'], 'https://storage.googleapis.com/test/photo1.jpg');
      expect(map['storagePath'], 'reviews/photo1.jpg');
      expect(map['blurHash'], 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
      expect(map['w'], 1920);
      expect(map['h'], 1080);
    });

    test('toMap omits optional blurHash, width, and height when null', () {
      const photo = ReviewPhoto(
        url: 'https://storage.googleapis.com/test/photo2.jpg',
        storagePath: 'reviews/photo2.jpg',
      );

      final map = photo.toMap();
      expect(map['url'], 'https://storage.googleapis.com/test/photo2.jpg');
      expect(map['storagePath'], 'reviews/photo2.jpg');
      expect(map.containsKey('blurHash'), isFalse);
      expect(map.containsKey('w'), isFalse);
      expect(map.containsKey('h'), isFalse);
    });

    test('equality and hashCode', () {
      const p1 = ReviewPhoto(url: 'u', storagePath: 's', width: 100);
      const p2 = ReviewPhoto(url: 'u', storagePath: 's', width: 100);
      const p3 = ReviewPhoto(url: 'u', storagePath: 's', width: 200);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
    });
  });

  group('ReviewPage', () {
    test('equality and hashCode compare items, cursor, and hasMore', () {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final r = Review(
        bookingId: 'b1',
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 's1',
        rating: 5,
        text: 'Tuyệt',
        createdAt: now,
      );

      final page1 = ReviewPage(items: [r], cursor: 'b1', hasMore: true);
      final page2 = ReviewPage(items: [r], cursor: 'b1', hasMore: true);
      final page3 = ReviewPage(items: [r], cursor: 'b1', hasMore: false);

      expect(page1, equals(page2));
      expect(page1.hashCode, equals(page2.hashCode));
      expect(page1, isNot(equals(page3)));
    });
  });

  group('FirestoreReviewRepository.mapFunctionsError', () {
    test('maps detail error code when present', () {
      final ex = FirebaseFunctionsException(
        message: 'Conflict occurred',
        code: 'aborted',
        details: {'code': 'conflict'},
      );
      expect(FirestoreReviewRepository.mapFunctionsError(ex), ReviewErrorCode.conflict);
    });

    test('maps Firebase function error codes', () {
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'already-exists'),
        ),
        ReviewErrorCode.conflict,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'aborted'),
        ),
        ReviewErrorCode.conflict,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'failed-precondition'),
        ),
        ReviewErrorCode.notEligible,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'permission-denied'),
        ),
        ReviewErrorCode.permissionDenied,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'unauthenticated'),
        ),
        ReviewErrorCode.permissionDenied,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'not-found'),
        ),
        ReviewErrorCode.notFound,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'invalid-argument'),
        ),
        ReviewErrorCode.invalidArgument,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'unavailable'),
        ),
        ReviewErrorCode.network,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'deadline-exceeded'),
        ),
        ReviewErrorCode.network,
      );
    });

    test('falls back to unknown for unmapped code or non-Functions exception', () {
      expect(
        FirestoreReviewRepository.mapFunctionsError(
          FirebaseFunctionsException(message: 'err', code: 'internal'),
        ),
        ReviewErrorCode.unknown,
      );
      expect(
        FirestoreReviewRepository.mapFunctionsError(Exception('Random error')),
        ReviewErrorCode.unknown,
      );
    });
  });

  group('FirestoreReviewRepository with FakeFirebaseFirestore', () {
    late FirestoreReviewRepository repo;

    setUp(() {
      repo = FirestoreReviewRepository(firestore: firestore);
    });

    test('watchReview emits doc updates', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final stream = repo.watchReview('b100');

      final emissions = <Review?>[];
      final sub = stream.listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last, isNull);

      await firestore.collection('reviews').doc('b100').set({
        'customerId': 'c1',
        'photographerId': 'p1',
        'serviceId': 's1',
        'rating': 5,
        'text': 'Good',
        'createdAt': Timestamp.fromDate(now),
      });
      await pumpEventQueue();

      expect(emissions.last?.bookingId, 'b100');
      expect(emissions.last?.rating, 5);

      await sub.cancel();
    });

    test('forPhotographer queries and paginates reviews', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      for (int i = 0; i < 5; i++) {
        await firestore.collection('reviews').doc('b_$i').set({
          'customerId': 'cust_$i',
          'photographerId': 'target_p',
          'serviceId': 's1',
          'rating': 5,
          'text': 'Review $i',
          'createdAt': Timestamp.fromDate(now.add(Duration(minutes: i))),
        });
      }

      final page = await repo.forPhotographer('target_p', limit: 3);
      expect(page.items.length, 3);
      expect(page.hasMore, isTrue);
      expect(page.items.first.bookingId, 'b_4'); // descending createdAt
      expect(page.cursor, isA<DocumentSnapshot>());

      final page2 = await repo.forPhotographer(
        'target_p',
        after: page.cursor,
        limit: 3,
      );
      expect(page2.items.length, 2);
      expect(page2.hasMore, isFalse);
      expect(page2.items.first.bookingId, 'b_1');
    });
  });
}
