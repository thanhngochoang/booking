import 'dart:io' show SocketException;

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rules.dart';

/// A failed price rule callable: server `details.code` and, for form errors,
/// `details.field`.
class PriceRuleException implements Exception {
  const PriceRuleException(this.code, {this.field});
  final String code;
  final String? field;

  @override
  String toString() => 'PriceRuleException($code, $field)';
}

enum PriceRuleErrorCode {
  invalidArgument,

  /// 30 rules of a package are already saved (`rule_limit`).
  ruleLimit,

  /// 50 exceptions of a rule are already saved (`exception_limit`).
  exceptionLimit,
  permissionDenied,
  notFound,
  network,
  unknown,
}

class PriceRuleError {
  const PriceRuleError(this.code, [this.field]);
  final PriceRuleErrorCode code;

  /// The form field the server blamed (`price`, `from`, `weekdays`, `day`...).
  final String? field;
}

/// Maps a thrown error to a code and field.
PriceRuleError priceRuleErrorOf(Object error) {
  if (error is SocketException) {
    return const PriceRuleError(PriceRuleErrorCode.network);
  }
  if (error is! PriceRuleException) {
    return const PriceRuleError(PriceRuleErrorCode.unknown);
  }
  return switch (error.code) {
    'invalid_argument' || 'invalid-argument' => PriceRuleError(
      PriceRuleErrorCode.invalidArgument,
      error.field,
    ),
    'rule_limit' => const PriceRuleError(PriceRuleErrorCode.ruleLimit),
    'exception_limit' => const PriceRuleError(
      PriceRuleErrorCode.exceptionLimit,
    ),
    'permission_denied' || 'permission-denied' => const PriceRuleError(
      PriceRuleErrorCode.permissionDenied,
    ),
    'not_found' ||
    'not-found' => const PriceRuleError(PriceRuleErrorCode.notFound),
    'unavailable' ||
    'deadline-exceeded' ||
    'network' => const PriceRuleError(PriceRuleErrorCode.network),
    _ => const PriceRuleError(PriceRuleErrorCode.unknown),
  };
}

/// A rule as the form sends it to `savePriceRule`. `start`, `until` and the
/// exceptions are not part of it: the server keeps them when a rule is edited.
final class PriceRuleInput {
  const PriceRuleInput({
    required this.serviceId,
    required this.price,
    required this.repeat,
    this.name,
    this.lunar = false,
    this.from,
    this.to,
    this.weekdays = const {},
    this.template,
  });

  /// The form values of an existing rule, to edit it.
  factory PriceRuleInput.fromRule(PriceRule rule) => PriceRuleInput(
    serviceId: rule.serviceId,
    price: rule.price,
    repeat: rule.repeat,
    name: rule.name,
    lunar: rule.lunar,
    from: rule.from,
    to: rule.to,
    weekdays: rule.weekdays,
    template: rule.template,
  );

  final String serviceId;
  final int price;
  final PriceRepeat repeat;
  final String? name;
  final bool lunar;

  /// `none`: `yyyy-MM-dd`; `yearly`: `MM-dd`; `weekly`: null.
  final String? from;
  final String? to;
  final Set<Weekday> weekdays;
  final String? template;

  String? get _cleanName {
    final n = name?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  /// The document fields of this rule (what [validatePriceRuleField] reads).
  Map<String, Object?> toMap() => {
    'serviceId': serviceId,
    'price': price,
    'repeat': repeat.name,
    'name': ?_cleanName,
    if (lunar) 'lunar': true,
    'from': ?from,
    'to': ?to,
    if (weekdays.isNotEmpty) 'weekdays': [for (final w in weekdays) w.name],
    'template': ?template,
  };

  /// The `savePriceRule` payload; absent fields are left out.
  Map<String, dynamic> toPayload({String? ruleId, bool applyToAll = false}) => {
    'ruleId': ?ruleId,
    ...toMap(),
    if (applyToAll) 'applyToAll': true,
  };

  /// The first field that is unusable, null when valid (inline form errors).
  /// The server stays the authority and also checks the counts.
  String? validate({
    required DateTime today,
    required List<String> serviceIds,
    required bool creating,
  }) => validatePriceRuleField(
    toMap(),
    today: today,
    serviceIds: serviceIds,
    creating: creating,
  );
}

/// What "only this day" does to one day of a series.
sealed class PriceException {
  const PriceException();

  /// The day gets its own [price].
  const factory PriceException.custom(int price) = CustomDayPrice;

  /// The day is dropped from the series (payload `null`).
  const factory PriceException.skip() = SkipDay;

  /// The exception of the day is removed (payload `"clear"`).
  const factory PriceException.clear() = ClearDayException;

  /// The `price` of the `setPriceRuleException` payload: int, null or `"clear"`.
  Object? get payload;
}

final class CustomDayPrice extends PriceException {
  const CustomDayPrice(this.price);
  final int price;

  @override
  Object? get payload => price;

  @override
  bool operator ==(Object other) =>
      other is CustomDayPrice && other.price == price;

  @override
  int get hashCode => price.hashCode;
}

final class SkipDay extends PriceException {
  const SkipDay();

  @override
  Object? get payload => null;

  @override
  bool operator ==(Object other) => other is SkipDay;

  @override
  int get hashCode => 1;
}

final class ClearDayException extends PriceException {
  const ClearDayException();

  @override
  Object? get payload => 'clear';

  @override
  bool operator ==(Object other) => other is ClearDayException;

  @override
  int get hashCode => 2;
}

/// Price series of a photographer. Reads are live from Firestore; writes go
/// only through the four callables (`savePriceRule`, `splitPriceRule`,
/// `setPriceRuleException`, `deletePriceRule`). Days are UTC-midnight dates.
abstract class PriceRuleRepository {
  /// The rules of [providerId], live, ordered by package, then tier (`none`,
  /// `yearly`, `weekly`), then first day, then id. Unusable documents are
  /// skipped.
  Stream<List<PriceRule>> watchProviderRules(String providerId);

  /// One-shot read of the rules of one package, same order.
  Future<List<PriceRule>> rulesForService(String providerId, String serviceId);

  /// Creates (no [ruleId]) or edits a rule (`savePriceRule`). [applyToAll]
  /// (create only) also adds a scaled copy to every other package (R8).
  /// Returns the ids written: the saved rule first.
  Future<List<String>> saveRule(
    PriceRuleInput input, {
    String? ruleId,
    bool applyToAll = false,
  });

  /// "This and the following days" (`splitPriceRule`): from [day] on the series
  /// has [price], or ends the day before when [price] is null. Returns the ids
  /// written; empty when the whole series was deleted.
  Future<List<String>> splitRule(String ruleId, DateTime day, {int? price});

  /// "Only this day" (`setPriceRuleException`).
  Future<void> setException(String ruleId, DateTime day, PriceException value);

  /// Deletes the series (`deletePriceRule`); bookings keep their snapshot.
  Future<void> deleteRule(String ruleId);
}

/// The order of [PriceRuleRepository.watchProviderRules].
int comparePriceRules(PriceRule a, PriceRule b) {
  final byService = a.serviceId.compareTo(b.serviceId);
  if (byService != 0) {
    return byService;
  }
  final byTier = b.repeat.tier.compareTo(a.repeat.tier);
  if (byTier != 0) {
    return byTier;
  }
  final aFrom = a.from ?? a.start ?? '';
  final bFrom = b.from ?? b.start ?? '';
  final byFrom = aFrom.compareTo(bFrom);
  return byFrom != 0 ? byFrom : a.id.compareTo(b.id);
}

/// The `yyyy-MM-dd` key sent for [day] (only its calendar fields count).
String priceRuleDayKey(DateTime day) => dayKeyOf(calendarDay(day));
