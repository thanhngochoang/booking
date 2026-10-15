import 'dart:async';

import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_repository.dart';
import 'fake_booking_repository.dart';

class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository({
    this.currentUserId = 'cust1',
  });

  String currentUserId;
  String defaultPhotographerId = 'photog1';
  final Map<String, String> bookingPhotographerIds = {};
  FakeBookingRepository? bookingRepository;
  ReviewErrorCode? nextError;
  ReviewException? nextException;

  final Map<String, Review> reviews = {};
  final Map<String, StreamController<Review?>> _reviewControllers = {};

  final List<Map<String, dynamic>> submitCalls = [];

  void seedReview(Review review) {
    reviews[review.bookingId] = review;
    _notifyReview(review.bookingId);
  }

  void _notifyReview(String bookingId) {
    _reviewControllers[bookingId]?.add(reviews[bookingId]);
  }

  @override
  Stream<Review?> watchReview(String bookingId) {
    _reviewControllers.putIfAbsent(
      bookingId,
      () => StreamController<Review?>.broadcast(
        onListen: () {
          _reviewControllers[bookingId]?.add(reviews[bookingId]);
        },
      ),
    );
    return _reviewControllers[bookingId]!.stream;
  }

  @override
  Future<ReviewPage> forPhotographer(
    String photographerId, {
    Object? after,
    int limit = 10,
  }) async {
    if (nextException != null) {
      final ex = nextException!;
      nextException = null;
      throw ex;
    }
    if (nextError != null) {
      final code = nextError!;
      nextError = null;
      throw ReviewException(code, 'Simulated failure: $code');
    }

    final matching = reviews.values
        .where((r) => r.photographerId == photographerId)
        .toList();
    matching.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int startIndex = 0;
    if (after != null) {
      if (after is Review) {
        final idx = matching.indexWhere((r) => r.bookingId == after.bookingId);
        if (idx != -1) startIndex = idx + 1;
      } else if (after is String) {
        final idx = matching.indexWhere((r) => r.bookingId == after);
        if (idx != -1) startIndex = idx + 1;
      }
    }

    final paged = matching.skip(startIndex).take(limit).toList();
    final hasMore = (startIndex + limit) < matching.length;
    final cursor = paged.isNotEmpty ? paged.last.bookingId : null;

    return ReviewPage(
      items: paged,
      cursor: cursor,
      hasMore: hasMore,
    );
  }

  @override
  Future<String?> submit({
    required String bookingId,
    required Verdict verdict,
    required int hits,
    required List<ReviewReason> reasons,
    required String text,
    String? postId,
    List<ReviewPhoto> photos = const [],
  }) async {
    if (nextException != null) {
      final ex = nextException!;
      nextException = null;
      throw ex;
    }
    if (nextError != null) {
      final code = nextError!;
      nextError = null;
      throw ReviewException(code, 'Simulated failure: $code');
    }

    if (reviews.containsKey(bookingId)) {
      throw const ReviewException(
        ReviewErrorCode.conflict,
        'Review already submitted for this booking',
      );
    }

    submitCalls.add({
      'bookingId': bookingId,
      'verdict': verdict,
      'hits': hits,
      'reasons': reasons,
      'text': text,
      'postId': postId,
      'photos': photos,
    });

    final photogId =
        bookingPhotographerIds[bookingId] ?? defaultPhotographerId;
    final review = Review(
      bookingId: bookingId,
      customerId: currentUserId,
      photographerId: photogId,
      serviceId: 'srv1',
      verdict: verdict,
      hits: hits,
      reasons: reasons,
      text: text,
      photoPostId: postId,
      createdAt: DateTime.now(),
    );

    seedReview(review);

    if (bookingRepository != null &&
        bookingRepository!.bookings.containsKey(bookingId)) {
      final old = bookingRepository!.bookings[bookingId]!;
      // Like the server: the booking keeps its status, `reviewedAt` is set.
      final updated = old.copyWith(reviewedAt: DateTime.now());
      bookingRepository!.seedBooking(updated);
      bookingRepository!.addEvent(
        BookingEventRecord(
          id: 'event-reviewed-$bookingId',
          bookingId: bookingId,
          status: BookingStatus.reviewed,
          at: DateTime.now(),
          actorId: currentUserId,
        ),
      );
    }

    return postId;
  }
}
