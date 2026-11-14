import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';

import '../../support/fake_price_rule_repository.dart';

PriceRule _rule(String id, String serviceId) => PriceRule(
  id: id,
  serviceId: serviceId,
  price: 2000000,
  repeat: PriceRepeat.none,
  from: '2026-12-20',
  to: '2026-12-31',
);

void main() {
  late FakePriceRuleRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakePriceRuleRepository()
      ..seed(_rule('a', 's1'))
      ..seed(_rule('b', 's2'));
    container = ProviderContainer(
      overrides: [priceRuleRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('providerPriceRulesProvider streams the provider\'s rules', () async {
    container.listen(providerPriceRulesProvider('p1'), (_, _) {});
    final rules = await container.read(providerPriceRulesProvider('p1').future);

    expect(rules.map((r) => r.id), ['a', 'b']);
  });

  test(
    'servicePriceRulesProvider keeps one package and follows writes',
    () async {
      final sub = container.listen(
        servicePriceRulesProvider(('p1', 's1')),
        (_, _) {},
      );
      await container.read(providerPriceRulesProvider('p1').future);

      expect(sub.read().value!.map((r) => r.id), ['a']);

      repo.seed(_rule('c', 's1'));
      await Future<void>.delayed(Duration.zero);

      expect(sub.read().value!.map((r) => r.id), ['a', 'c']);
    },
  );
}
