import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Review {
  const Review({
    required this.bookingId,
    required this.customerId,
    required this.photographerId,
    required this.serviceId,
    required this.rating,
    required this.text,
    this.photoPostId,
    required this.createdAt,
  });

  final String bookingId;
  final String customerId;
  final String photographerId;
  final String serviceId;
  final int rating;
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

    return Review(
      bookingId: doc.id,
      customerId: data['customerId'] as String? ?? '',
      photographerId: data['photographerId'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 5,
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
          customerId == other.customerId &&
          photographerId == other.photographerId &&
          serviceId == other.serviceId &&
          rating == other.rating &&
          text == other.text &&
          photoPostId == other.photoPostId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        bookingId,
        customerId,
        photographerId,
        serviceId,
        rating,
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
