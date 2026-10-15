import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_repository.dart';

/// [VerificationRepository] over the owner listener on `verifications/{uid}`
/// and the verification callables (region [functionsRegion]). A refusal's
/// `details.code` becomes [VerificationError]; an unreachable backend becomes
/// `VerificationError('network')`.
class FirestoreVerificationRepository implements VerificationRepository {
  FirestoreVerificationRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _dbOverride = db,
       _functionsOverride = functions;

  final FirebaseFirestore? _dbOverride;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  @override
  Stream<Map<String, dynamic>?> watchRaw(String uid) =>
      _db.collection('verifications').doc(uid).snapshots().map((s) => s.data());

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Object?>(data);
      final out = r.data;
      return out is Map ? out.cast<String, dynamic>() : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        throw VerificationError(details['code'] as String);
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const VerificationError('network');
      }
      throw VerificationError(e.code);
    }
  }

  String _string(Map<String, dynamic> d, String key) {
    final v = d[key];
    if (v is! String) {
      throw VerificationError('bad_response:$key');
    }
    return v;
  }

  @override
  Future<void> confirmPhoneVerified() async {
    await _call('confirmPhoneVerified');
  }

  @override
  Future<IdentitySession> startIdentity(IdentityMethod method) async {
    final d = await _call('startIdentityVerification', {'method': method.code});
    final redirect = d['redirectUrl'];
    return IdentitySession(
      sessionId: _string(d, 'sessionId'),
      redirectUrl: redirect is String ? redirect : null,
    );
  }

  @override
  Future<String> completeIdentity(String sessionId) async {
    final d = await _call('completeIdentityVerification', {
      'sessionId': sessionId,
    });
    return _string(d, 'maskedName');
  }

  @override
  Future<void> acceptRules(String version) async {
    await _call('acceptVerificationRules', {'version': version});
  }

  @override
  Future<void> submit() async {
    await _call('submitVerification');
  }

  @override
  Future<void> resubmit() async {
    await _call('resubmitVerification');
  }

  @override
  Future<TaxCodeInfo> lookupTaxCode(String taxCode) async {
    final d = await _call('lookupTaxCode', {'taxCode': taxCode});
    return TaxCodeInfo(
      name: _string(d, 'name'),
      address: d['address'] is String ? d['address'] as String : '',
      active: d['status'] == 'active',
      kind: d['kind'] is String ? d['kind'] as String : 'company',
    );
  }

  @override
  Future<BusinessStatus> submitBusiness({
    required String taxCode,
    String? docPath,
  }) async {
    final d = await _call('submitBusinessVerification', {
      'taxCode': taxCode,
      'docPath': ?docPath,
    });
    final status = BusinessStatus.fromCode(d['status']);
    if (status == null) {
      throw const VerificationError('bad_response:status');
    }
    return status;
  }
}
