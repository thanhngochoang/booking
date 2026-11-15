import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';

/// `FieldValue.delete()` for every field of [kLegacyPackagePriceFields]: the
/// rules' `validService` checks the whole document after an update, so a
/// package that still holds one of them is refused unless the write removes it.
final _dropLegacyPriceFields = {
  for (final f in kLegacyPackagePriceFields) f: FieldValue.delete(),
};

class FirestoreServicePackageRepository implements ServicePackageRepository {
  FirestoreServicePackageRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('photographers').doc(uid).collection('services');

  @override
  Stream<List<ServicePackage>> watchMine(String uid) => _col(uid)
      // ULID ids sort by creation time.
      .orderBy(FieldPath.documentId)
      .snapshots()
      .map(
        (s) => sortedPackages([
          for (final d in s.docs) ?packageFromFirestore(d.id, d.data()),
        ]),
      );

  @override
  Future<ServicePackage> add(String uid, ServicePackageInput input) async {
    final id = newUlid();
    await _col(uid).doc(id).set({
      ...packageToFirestore(input),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ServicePackage.from(id, input);
  }

  @override
  Future<void> update(String uid, String id, ServicePackageInput input) =>
      _col(uid).doc(id).update({
        ..._dropLegacyPriceFields,
        ...packageToFirestore(input),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> hide(String uid, String id) => setActive(uid, id, false);

  @override
  Future<void> setActive(String uid, String id, bool active) => _col(uid)
      .doc(id)
      .update({
        ..._dropLegacyPriceFields,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> reorder(String uid, List<String> idsInOrder) {
    final batch = _db.batch();
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.update(_col(uid).doc(idsInOrder[i]), {
        ..._dropLegacyPriceFields,
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }
}
