import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/clock/clock.dart';

@immutable
class BookingFeatures {
  const BookingFeatures({
    required this.chat,
    required this.reschedule,
    required this.review,
  });

  final bool chat;
  final bool reschedule;
  final bool review;
}

final bookingFeaturesProvider = Provider<BookingFeatures>(
  (ref) => const BookingFeatures(chat: false, reschedule: false, review: false),
);

/// "Now" that re-emits every [period]; widgets showing time-dependent text watch it.
final nowTickerProvider =
    StreamProvider.autoDispose.family<DateTime, Duration>((ref, period) async* {
      final now = ref.watch(clockProvider);
      yield now();
      yield* Stream.periodic(period, (_) => now());
    });
