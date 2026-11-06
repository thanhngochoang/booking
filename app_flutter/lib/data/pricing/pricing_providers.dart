import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/firestore_special_days_repository.dart';
import 'package:photobooking/data/pricing/special_days.dart';

final holidayRepositoryProvider = Provider<HolidayRepository>(
  (ref) => FirestoreHolidayRepository(),
);

final specialDayRepositoryProvider = Provider<SpecialDayRepository>(
  (ref) => FirestoreSpecialDayRepository(),
);

/// The public holidays of one year.
final holidaysProvider = FutureProvider.autoDispose.family<List<Holiday>, int>(
  (ref, year) => ref.watch(holidayRepositoryProvider).forYear(year),
);

/// A provider's own special ranges; live.
final specialDaysProvider = StreamProvider.autoDispose
    .family<List<SpecialDayRange>, String>(
      (ref, uid) => ref.watch(specialDayRepositoryProvider).watch(uid),
    );

/// Holidays of `year` plus the provider's own ranges: what pricing a booking
/// day in that year needs.
final specialDaysForBookingProvider = FutureProvider.autoDispose
    .family<SpecialDays, ({String providerId, int year})>((ref, key) async {
      final holidays = await ref.watch(holidaysProvider(key.year).future);
      final ranges = await ref.watch(
        specialDaysProvider(key.providerId).future,
      );
      return specialDaysOf(holidays, ranges);
    });
