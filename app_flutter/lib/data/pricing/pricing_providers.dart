import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/pricing/firestore_price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

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
