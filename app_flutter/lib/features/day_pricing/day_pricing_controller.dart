import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';
import 'package:photobooking/data/pricing/pricing_providers.dart';
import 'package:photobooking/features/day_pricing/day_pricing_analytics.dart';

/// The packages in the order S08.10 lists them: the ones that are on first,
/// hidden ones after (dimmed), each group in its stored order.
List<ServicePackage> packagesByChipOrder(List<ServicePackage> all) => [
  for (final p in all)
    if (p.active) p,
  for (final p in all)
    if (!p.active) p,
];

/// What S08.10 and its list show: every package and every series of the
/// signed-in photographer.
typedef DayPricingData = ({
  List<ServicePackage> packages,
  List<PriceRule> rules,
});

/// Both live lists as one value: data when both have arrived, an error when
/// one failed with nothing to show, else loading.
final dayPricingDataProvider = Provider.autoDispose<AsyncValue<DayPricingData>>(
  (ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final packages = ref.watch(myPackagesProvider);
    final rules = uid == null
        ? const AsyncData<List<PriceRule>>([])
        : ref.watch(providerPriceRulesProvider(uid));
    if (packages.hasValue && rules.hasValue) {
      return AsyncData((
        packages: packages.requireValue,
        rules: rules.requireValue,
      ));
    }
    if (packages.hasError && !packages.hasValue) {
      return AsyncError(
        packages.error!,
        packages.stackTrace ?? StackTrace.empty,
      );
    }
    if (rules.hasError && !rules.hasValue) {
      return AsyncError(rules.error!, rules.stackTrace ?? StackTrace.empty);
    }
    return const AsyncLoading();
  },
);

/// Reloads what [dayPricingDataProvider] reads (the retry of the error state).
void retryDayPricing(WidgetRef ref) {
  ref.invalidate(myPackagesProvider);
  final uid = ref.read(authRepositoryProvider).currentUser?.uid;
  if (uid != null) {
    ref.invalidate(providerPriceRulesProvider(uid));
  }
}

/// What a write came to: [error] is null when it went through.
class PriceRuleResult {
  const PriceRuleResult.ok() : error = null;
  const PriceRuleResult.failed(PriceRuleError this.error);

  final PriceRuleError? error;
  bool get ok => error == null;
}

/// The writes of S08.10 and its sheets: through the repository (the four
/// callables) and with the analytics events of the screen spec. A failed write
/// answers with the error; the screen decides which line to show.
class DayPricingActions {
  DayPricingActions(this._ref);

  final Ref _ref;

  PriceRuleRepository get _repo => _ref.read(priceRuleRepositoryProvider);
  DayPricingEventLogger get _log => _ref.read(dayPricingAnalyticsProvider);

  Future<PriceRuleResult> _run(Future<void> Function() job) async {
    try {
      await job();
      return const PriceRuleResult.ok();
    } on Object catch (e) {
      return PriceRuleResult.failed(priceRuleErrorOf(e));
    }
  }

  /// Creates a series, or edits the whole of [ruleId].
  Future<PriceRuleResult> saveRule(
    PriceRuleInput input, {
    String? ruleId,
    bool applyToAll = false,
  }) async {
    final result = await _run(
      () => _repo.saveRule(input, ruleId: ruleId, applyToAll: applyToAll),
    );
    if (result.ok) {
      _log('price_rule_save', {
        'repeat': input.repeat.name,
        'lunar': input.lunar,
        'scope': ruleId == null ? 'new' : 'all',
        'applyAll': applyToAll,
      });
    }
    return result;
  }

  /// "This and the following days": the series has [price] from [day] on, or
  /// ends the day before when [price] is null.
  Future<PriceRuleResult> splitRule(
    String ruleId,
    DateTime day, {
    int? price,
  }) async {
    final result = await _run(() => _repo.splitRule(ruleId, day, price: price));
    if (result.ok) {
      if (price != null) {
        _log('price_rule_save', {'scope': 'following'});
      } else {
        _log('price_rule_delete', {'scope': 'following'});
      }
    }
    return result;
  }

  /// "Only this day".
  Future<PriceRuleResult> setException(
    String ruleId,
    DateTime day,
    PriceException value,
  ) async {
    final result = await _run(() => _repo.setException(ruleId, day, value));
    if (result.ok) {
      _log('price_rule_exception', {
        'kind': switch (value) {
          SkipDay() => 'skip',
          ClearDayException() => 'clear',
          CustomDayPrice() => 'price',
        },
      });
    }
    return result;
  }

  Future<PriceRuleResult> deleteRule(String ruleId) async {
    final result = await _run(() => _repo.deleteRule(ruleId));
    if (result.ok) {
      _log('price_rule_delete', {'scope': 'all'});
    }
    return result;
  }
}

final dayPricingActionsProvider = Provider<DayPricingActions>(
  DayPricingActions.new,
);
