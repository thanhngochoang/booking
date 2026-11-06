import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/pricing/day_pricing.dart';
import 'package:photobooking/data/pricing/firestore_price_rule_repository.dart';
import 'package:photobooking/data/pricing/firestore_special_days_repository.dart';
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
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

final priceRuleRepositoryProvider = Provider<PriceRuleRepository>(
  (ref) => FirestorePriceRuleRepository(),
);

/// The price series of a photographer, live and ordered by package, tier, first
/// day (S08.10, S08.08/09 and the booking flow read it).
final providerPriceRulesProvider = StreamProvider.autoDispose
    .family<List<PriceRule>, String>(
      (ref, providerId) =>
          ref.watch(priceRuleRepositoryProvider).watchProviderRules(providerId),
    );

/// The series of one package, `(providerId, serviceId)`: a view of
/// [providerPriceRulesProvider], so screens share one Firestore listener.
final servicePriceRulesProvider = Provider.autoDispose
    .family<AsyncValue<List<PriceRule>>, (String, String)>((ref, key) {
      final (providerId, serviceId) = key;
      return ref
          .watch(providerPriceRulesProvider(providerId))
          .whenData(
            (all) => [
              for (final r in all)
                if (r.serviceId == serviceId) r,
            ],
          );
    });
