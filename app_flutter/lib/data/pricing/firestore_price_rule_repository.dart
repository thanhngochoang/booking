import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

/// Reads `photographers/{uid}/price_rules` live; every write goes through a
/// callable (the rules deny client writes).
class FirestorePriceRuleRepository implements PriceRuleRepository {
  FirestorePriceRuleRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _customFunctions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions? _customFunctions;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('photographers').doc(uid).collection('price_rules');

  List<PriceRule> _parse(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = <PriceRule>[
      for (final d in snap.docs) ?PriceRule.tryParse(d.id, d.data()),
    ];
    list.sort(comparePriceRules);
    return list;
  }

  @override
  Stream<List<PriceRule>> watchProviderRules(String providerId) =>
      _col(providerId).snapshots().map(_parse);

  @override
  Future<List<PriceRule>> rulesForService(
    String providerId,
    String serviceId,
  ) async {
    final snap = await _col(providerId)
        .where('serviceId', isEqualTo: serviceId)
        .get();
    return _parse(snap);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      final raw = res.data;
      return raw is Map ? raw.cast<String, dynamic>() : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : e.code;
      final field = details is Map && details['field'] is String
          ? details['field'] as String
          : null;
      throw PriceRuleException(code, field: field);
    }
  }

  List<String> _ids(Map<String, dynamic> out) {
    final ids = out['ruleIds'];
    if (ids is! List || !ids.every((i) => i is String)) {
      throw const PriceRuleException('invalid_response');
    }
    return ids.cast<String>();
  }

  @override
  Future<List<String>> saveRule(
    PriceRuleInput input, {
    String? ruleId,
    bool applyToAll = false,
  }) async => _ids(
    await _call(
      'savePriceRule',
      input.toPayload(ruleId: ruleId, applyToAll: applyToAll),
    ),
  );

  @override
  Future<List<String>> splitRule(
    String ruleId,
    DateTime day, {
    int? price,
  }) async => _ids(
    await _call('splitPriceRule', {
      'ruleId': ruleId,
      'day': priceRuleDayKey(day),
      'price': ?price,
    }),
  );

  @override
  Future<void> setException(
    String ruleId,
    DateTime day,
    PriceException value,
  ) async {
    await _call('setPriceRuleException', {
      'ruleId': ruleId,
      'day': priceRuleDayKey(day),
      'price': value.payload,
    });
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await _call('deletePriceRule', {'ruleId': ruleId});
  }
}
