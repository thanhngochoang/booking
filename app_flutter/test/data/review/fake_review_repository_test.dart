import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_repository.dart';

import '../../support/fake_review_repository.dart';

void main() {
  group('FakeReviewRepository', () {
    late FakeReviewRepository repo;

    setUp(() {
      repo = FakeReviewRepository(currentUserId: 'cust_abc');
    });

    test('seedReview and watchReview emits review updates', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      final r = Review(
        bookingId: 'book_1',
        customerId: 'cust_abc',
        photographerId: 'photog_1',
        serviceId: 'srv_1',
        rating: 5,
        text: 'Rất tuyệt vời!',
        createdAt: now,
      );

      final emissions = <Review?>[];
      final sub = repo.watchReview('book_1').listen(emissions.add);

      repo.seedReview(r);
      await pumpEventQueue();

      expect(emissions.first, isNull);
      expect(emissions.last?.bookingId, 'book_1');
      expect(emissions.last?.rating, 5);

      await sub.cancel();
    });

    test('forPhotographer sorts descending and supports pagination with cursor', () async {
      final now = DateTime(2026, 10, 3, 10, 0, 0);
      for (int i = 0; i < 5; i++) {
        repo.seedReview(
          Review(
            bookingId: 'book_$i',
            customerId: 'cust_$i',
            photographerId: 'photog_target',
            serviceId: 'srv_1',
            rating: i + 1,
            text: 'Review $i',
            createdAt: now.add(Duration(minutes: i)),
          ),
        );
      }

      // First page limit 3
      final page1 = await repo.forPhotographer('photog_target', limit: 3);
      expect(page1.items.length, 3);
      expect(page1.hasMore, isTrue);
      expect(page1.items[0].bookingId, 'book_4'); // newest first
      expect(page1.items[1].bookingId, 'book_3');
      expect(page1.items[2].bookingId, 'book_2');
      expect(page1.cursor, 'book_2');

      // Second page with cursor
      final page2 = await repo.forPhotographer(
        'photog_target',
        after: page1.cursor,
        limit: 3,
      );
      expect(page2.items.length, 2);
      expect(page2.hasMore, isFalse);
      expect(page2.items[0].bookingId, 'book_1');
      expect(page2.items[1].bookingId, 'book_0');
    });

    test('submit records call and saves review to memory', () async {
      const photos = [
        ReviewPhoto(url: 'https://example.com/p1.jpg', storagePath: 'rev/p1.jpg'),
      ];

      final postId = await repo.submit(
        bookingId: 'book_new',
        rating: 5,
        text: 'Nhiếp ảnh gia rất có tâm',
        postId: 'post_new',
        photos: photos,
      );

      expect(postId, 'post_new');
      expect(repo.submitCalls.length, 1);
      expect(repo.submitCalls.first['bookingId'], 'book_new');
      expect(repo.submitCalls.first['rating'], 5);
      expect(repo.submitCalls.first['text'], 'Nhiếp ảnh gia rất có tâm');
      expect(repo.submitCalls.first['postId'], 'post_new');
      expect(repo.submitCalls.first['photos'], photos);

      final saved = repo.reviews['book_new'];
      expect(saved, isNotNull);
      expect(saved?.customerId, 'cust_abc');
      expect(saved?.rating, 5);
      expect(saved?.photoPostId, 'post_new');
    });

    test('submit throws conflict if booking was already reviewed', () async {
      await repo.submit(
        bookingId: 'book_once',
        rating: 5,
        text: 'First time',
      );

      expect(
        () => repo.submit(
          bookingId: 'book_once',
          rating: 4,
          text: 'Second time',
        ),
        throwsA(
          isA<ReviewException>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.conflict,
          ),
        ),
      );
    });

    test('nextError causes next submit to fail and is then cleared', () async {
      repo.nextError = ReviewErrorCode.notEligible;

      expect(
        () => repo.submit(
          bookingId: 'book_fail',
          rating: 5,
          text: 'Test fail',
        ),
        throwsA(
          isA<ReviewException>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.notEligible,
          ),
        ),
      );

      // Subsequent call should succeed since nextError was consumed
      final postId = await repo.submit(
        bookingId: 'book_fail',
        rating: 5,
        text: 'Test succeed now',
      );
      expect(postId, isNull);
    });

    test('nextException causes forPhotographer to throw custom exception', () async {
      repo.nextException = const ReviewException(
        ReviewErrorCode.network,
        'Simulated network timeout',
      );

      expect(
        () => repo.forPhotographer('photog_1'),
        throwsA(
          isA<ReviewException>().having(
            (e) => e.code,
            'code',
            ReviewErrorCode.network,
          ),
        ),
      );

      // Next call works
      final page = await repo.forPhotographer('photog_1');
      expect(page.items, isEmpty);
    });
  });
}
