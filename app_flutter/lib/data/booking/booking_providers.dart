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
