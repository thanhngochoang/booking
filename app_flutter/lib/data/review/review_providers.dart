import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/review/firestore_review_repository.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return FirestoreReviewRepository();
});

final bookingReviewProvider =
    StreamProvider.autoDispose.family<Review?, String>((ref, bookingId) {
  return ref.watch(reviewRepositoryProvider).watchReview(bookingId);
});
