import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';

/// ProviderRepository over the callables `setProviderType` and
/// `setStudioAddress`; the saved address is read from the owner-only
/// `photographers/{uid}/private/studioAddress` document.
class CallableProviderRepository implements ProviderRepository {
  CallableProviderRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? db,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion),
       _override = db;

  final FirebaseFunctions _functions;
  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  Future<Object?> _call(String name, Map<String, Object> data) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : (e.message ?? e.code);
      throw ProviderError(code);
    }
  }

  @override
  Future<ProviderType> setType(ProviderChoice choice) async {
    final data = await _call('setProviderType', {'type': choice.name});
    return ProviderType.fromCode(data is Map ? data['providerType'] : null);
  }

  @override
  Future<void> setStudioAddress(StudioAddressInput address) async {
    await _call('setStudioAddress', address.toJson());
  }

  @override
  Future<StudioAddressInput?> myStudioAddress(String uid) async {
    final d = (await _db.doc('photographers/$uid/private/studioAddress').get())
        .data();
    if (d == null) {
      return null;
    }
    final line = d['line'];
    final district = d['district'];
    final city = d['city'];
    if (line is! String || district is! String || city is! String) {
      return null;
    }
    final ward = d['ward'];
    final lat = d['lat'];
    final lng = d['lng'];
    return StudioAddressInput(
      line: line,
      ward: ward is String ? ward : null,
      district: district,
      city: city,
      lat: lat is num ? lat.toDouble() : null,
      lng: lng is num ? lng.toDouble() : null,
    );
  }
}
