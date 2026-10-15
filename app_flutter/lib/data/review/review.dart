import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/core/core.dart';

export 'package:photobooking/core/format.dart' show kTomatoPctMinReviews;

/// The two sides of a review: tomato = satisfied, brick = not satisfied.
enum Verdict {
  tomato,
  brick;

  String get code => name;

  static Verdict? fromCode(Object? c) {
    for (final v in values) {
      if (v.code == c) return v;
    }
    return null;
  }
}

/// Why a brick was thrown (a tomato carries none).
enum ReviewReason {
  late('late'),
  notAsPortfolio('not_as_portfolio'),
  slowDelivery('slow_delivery'),
  attitude('attitude'),
  priceChanged('price_changed'),
  other('other');

  const ReviewReason(this.code);
  final String code;

  static ReviewReason? fromCode(Object? c) {
    for (final r in values) {
      if (r.code == c) return r;
    }
    return null;
  }
}

/// Most taps on one side of the pad.
const int kReviewHitsMax = kVerdictHitsMax;

/// Display mirror of the server rule `round2(0.4 + 0.6 * log10(hits))`; the
/// server computes the stored value.
double intensityOf(int hits) => verdictIntensity(hits);

/// The legacy star rating a doc without `verdict` had maps to a verdict
/// (display only): 4 and 5 stars read as one tomato, anything lower (or no
/// rating) as one brick.
const int _legacyTomatoMinStars = 4;

@immutable
class Review {
  Review({
    required this.bookingId,
    this.subjectType = 'photographer',
    String? subjectId,
    required this.customerId,
    required this.photographerId,
    required this.serviceId,
    this.serviceName,
    this.bookingDay,
    required this.verdict,
    this.hits = 1,
    double? intensity,
    this.reasons = const [],
    required this.text,
    this.photoPostId,
    required this.createdAt,
  })  : subjectId = subjectId ?? photographerId,
        intensity = intensity ?? intensityOf(hits);

  /// The booking this review is about (not always the document id: a studio
  /// review lives in `{bookingId}_studio`).
  final String bookingId;

  /// `photographer` or `studio`: whose stats this review counts into.
  final String subjectType;
  final String subjectId;
  final String customerId;
  final String photographerId;
  final String serviceId;

  /// Snapshots taken from the booking, for the reviews tab.
  final String? serviceName;

  /// `yyyy-MM-dd`.
  final String? bookingDay;
  final Verdict verdict;
  final int hits;
  final double intensity;
  final List<ReviewReason> reasons;
  final String text;
  final String? photoPostId;
  final DateTime createdAt;

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    // Same rules as the server reader (functions `reviewFromFirestore`).
    final known = Verdict.fromCode(data['verdict']);
    // A star doc left in an emulator export: read it, never count it. No
    // rating (or a non-number) reads as a brick, like the server.
    final rating = data['rating'];
    final verdict = known ??
        (rating is num && rating >= _legacyTomatoMinStars
            ? Verdict.tomato
            : Verdict.brick);
    final rawHits = data['hits'];
    // Out of range, fractional or not a number: one hit (no clamping).
    final hits = known != null &&
            rawHits is num &&
            rawHits == rawHits.truncateToDouble() &&
            rawHits >= 1 &&
            rawHits <= kReviewHitsMax
        ? rawHits.toInt()
        : 1;
    final rawIntensity = data['intensity'];
    final intensity = known != null && rawIntensity is num &&
            rawIntensity.isFinite
        ? rawIntensity.toDouble()
        : intensityOf(hits);
    // Reasons only on a brick, known codes once each.
    final reasons = <ReviewReason>[];
    if (known == Verdict.brick && data['reasons'] is List) {
      for (final c in data['reasons'] as List) {
        final reason = ReviewReason.fromCode(c);
        if (reason != null && !reasons.contains(reason)) reasons.add(reason);
      }
    }
    final photographerId = data['photographerId'] as String? ?? '';
    final rawBookingId = data['bookingId'];
    return Review(
      bookingId: rawBookingId is String && rawBookingId.isNotEmpty
          ? rawBookingId
          : doc.id,
      subjectType: data['subjectType'] == 'studio' ? 'studio' : 'photographer',
      subjectId: data['subjectId'] as String? ?? photographerId,
      customerId: data['customerId'] as String? ?? '',
      photographerId: photographerId,
      serviceId: data['serviceId'] as String? ?? '',
      serviceName: data['serviceName'] as String?,
      bookingDay: data['bookingDay'] as String?,
      verdict: verdict,
      hits: hits,
      intensity: intensity,
      reasons: reasons,
      text: data['text'] as String? ?? '',
      photoPostId: data['photoPostId'] as String?,
      createdAt: toDate(data['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Review &&
          bookingId == other.bookingId &&
          subjectType == other.subjectType &&
          subjectId == other.subjectId &&
          customerId == other.customerId &&
          photographerId == other.photographerId &&
          serviceId == other.serviceId &&
          serviceName == other.serviceName &&
          bookingDay == other.bookingDay &&
          verdict == other.verdict &&
          hits == other.hits &&
          intensity == other.intensity &&
          listEquals(reasons, other.reasons) &&
          text == other.text &&
          photoPostId == other.photoPostId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        bookingId,
        subjectType,
        subjectId,
        customerId,
        photographerId,
        serviceId,
        serviceName,
        bookingDay,
        verdict,
        hits,
        intensity,
        Object.hashAll(reasons),
        text,
        photoPostId,
        createdAt,
      );
}

@immutable
class ReviewPhoto {
  const ReviewPhoto({
    required this.url,
    required this.storagePath,
    this.blurHash,
    this.width,
    this.height,
  });

  final String url;
  final String storagePath;
  final String? blurHash;
  final int? width;
  final int? height;

  Map<String, dynamic> toMap() => {
        'url': url,
        'storagePath': storagePath,
        if (blurHash != null) 'blurHash': blurHash,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewPhoto &&
          url == other.url &&
          storagePath == other.storagePath &&
          blurHash == other.blurHash &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode =>
      Object.hash(url, storagePath, blurHash, width, height);
}

@immutable
class ReviewPage {
  const ReviewPage({
    required this.items,
    this.cursor,
    this.hasMore = false,
  });

  final List<Review> items;
  final Object? cursor;
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewPage &&
          listEquals(items, other.items) &&
          cursor == other.cursor &&
          hasMore == other.hasMore;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), cursor, hasMore);
}
