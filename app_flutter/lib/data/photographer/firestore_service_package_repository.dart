import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';

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
        (s) => [for (final d in s.docs) ?packageFromFirestore(d.id, d.data())],
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
        ...packageToFirestore(input),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> hide(String uid, String id) =>
      _col(uid)
          .doc(id)
          .update({'active': false, 'updatedAt': FieldValue.serverTimestamp()});
}
