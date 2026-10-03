import 'package:photobooking/data/review/review.dart';

enum ReviewErrorCode {
  conflict,
  notEligible,
  permissionDenied,
  notFound,
  invalidArgument,
  network,
  unknown,
}

class ReviewException implements Exception {
  const ReviewException(this.code, [this.message]);
  final ReviewErrorCode code;
  final String? message;

  @override
  String toString() => 'ReviewException($code, $message)';
}

abstract class ReviewRepository {
  Stream<Review?> watchReview(String bookingId);

  Future<ReviewPage> forPhotographer(
    String photographerId, {
    Object? after,
    int limit = 10,
  });

  Future<String?> submit({
    required String bookingId,
    required int rating,
    required String text,
    String? postId,
    List<ReviewPhoto> photos = const [],
  });
}
