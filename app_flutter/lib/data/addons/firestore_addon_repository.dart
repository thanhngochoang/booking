import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/backend/backend_config.dart';

class FirestoreAddonRepository implements AddonRepository {
  FirestoreAddonRepository({
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
      _db.collection('photographers').doc(uid).collection('addons');

  List<ServiceAddon> _parse(
    String uid,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final list = snap.docs
        .map((d) => serviceAddonFromFirestore(uid, d.id, d.data()))
        .whereType<ServiceAddon>()
        .toList();
    list.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      return byKind != 0 ? byKind : a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  Future<List<ServiceAddon>> activeFor(String providerId) async {
    final snap = await _col(providerId).where('active', isEqualTo: true).get();
    return _parse(providerId, snap);
  }

  @override
  Stream<List<ServiceAddon>> watchMine(String uid) =>
      _col(uid).snapshots().map((snap) => _parse(uid, snap));

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
      throw AddonException(code, field: field);
    }
  }

  @override
  Future<String> save(AddonInput input, {String? addonId}) async {
    final out = await _call('saveAddon', input.toPayload(addonId: addonId));
    final id = out['addonId'];
    if (id is! String) throw const AddonException('invalid_response');
    return id;
  }

  @override
  Future<void> delete(String addonId) async {
    await _call('deleteAddon', {'addonId': addonId});
  }
}
