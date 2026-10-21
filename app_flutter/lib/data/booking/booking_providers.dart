import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/firestore_booking_repository.dart';

/// Provides the active [BookingRepository] implementation.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return FirestoreBookingRepository();
});

/// Watches a single booking by [bookingId].
final bookingStreamProvider = StreamProvider.family<Booking?, String>((
  ref,
  bookingId,
) {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.watchBooking(bookingId);
});

/// Auto-disposed booking stream provider for screens.
final bookingProvider = StreamProvider.autoDispose.family<Booking?, String>(
  (ref, id) => ref.watch(bookingRepositoryProvider).watchBooking(id),
);

/// Watches all active bookings for a customer by [customerId].
final customerBookingsStreamProvider =
    StreamProvider.family<List<Booking>, String>((ref, customerId) {
      final repo = ref.watch(bookingRepositoryProvider);
      return repo.watchCustomerBookings(customerId);
    });

/// Watches all active bookings for a photographer by [photographerId].
final photographerBookingsStreamProvider =
    StreamProvider.family<List<Booking>, String>((ref, photographerId) {
      final repo = ref.watch(bookingRepositoryProvider);
      return repo.watchPhotographerBookings(photographerId);
    });

/// Watches the private contact snapshot for a booking by [bookingId].
final bookingContactStreamProvider =
    StreamProvider.family<BookingContactSnapshot?, String>((ref, bookingId) {
      final repo = ref.watch(bookingRepositoryProvider);
      return repo.watchBookingContact(bookingId);
    });

/// Groups customer bookings into S05.01 tabs (upcoming, pending, history).
final groupedCustomerBookingsProvider =
    Provider.family<AsyncValue<Map<BookingTab, List<Booking>>>, String>((
      ref,
      customerId,
    ) {
      final asyncList = ref.watch(customerBookingsStreamProvider(customerId));
      return asyncList.whenData(BookingRules.groupBookingsByTab);
    });

/// Auto-disposed user bookings stream provider for S05.01 / S06.01.
final myBookingsProvider =
    StreamProvider.autoDispose.family<List<Booking>, BookingRole>((ref, role) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return const Stream.empty();
      final repo = ref.watch(bookingRepositoryProvider);
      return role == BookingRole.customer
          ? repo.watchCustomerBookings(uid)
          : repo.watchPhotographerBookings(uid);
    });

/// Bookings a studio assigned to the signed-in photographer (S06.01). A
/// failing stream (rule not deployed, stale client) reads as an empty list and
/// is logged once, so the work tab never breaks for everyone.
final assignedBookingsProvider = StreamProvider.autoDispose<List<Booking>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  var logged = false;
  return ref
      .watch(bookingRepositoryProvider)
      .watchAssignedBookings(uid)
      .transform(
        StreamTransformer<List<Booking>, List<Booking>>.fromHandlers(
          handleError: (error, _, sink) {
            if (!logged) {
              logged = true;
              debugPrint('assignedBookings failed: ${error.runtimeType}');
            }
            sink.add(const <Booking>[]);
          },
        ),
      );
});

/// S06.01's bookings: the photographer's own merged with the assigned ones;
/// the own document wins on the same id. Errors are the own stream's (the
/// assigned one reads a failure as none); it loads until both streams have
/// answered once, so a studio shoot and its "Trả việc" never pop in late.
final myWorkBookingsProvider = Provider.autoDispose<AsyncValue<List<Booking>>>((
  ref,
) {
  final own = ref.watch(myBookingsProvider(BookingRole.photographer));
  final assignedAsync = ref.watch(assignedBookingsProvider);
  if (!assignedAsync.hasValue && !own.hasError) {
    return const AsyncLoading<List<Booking>>();
  }
  final assigned = assignedAsync.value ?? const <Booking>[];
  return own.whenData((list) {
    final ids = {for (final b in list) b.id};
    return [
      ...list,
      for (final b in assigned)
        if (!ids.contains(b.id)) b,
    ];
  });
});

/// Auto-disposed events stream provider for S05.02.
final bookingEventsProvider =
    StreamProvider.autoDispose.family<List<BookingEventRecord>, String>(
      (ref, id) => ref.watch(bookingRepositoryProvider).watchEvents(id),
    );

/// Auto-disposed contact stream provider for S05.02.
final bookingContactProvider =
    StreamProvider.autoDispose.family<BookingContactSnapshot?, String>(
      (ref, id) => ref.watch(bookingRepositoryProvider).watchBookingContact(id),
    );
