import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/photographer/photographer_intro.dart';

class FirestorePhotographerIntroRepository
    implements PhotographerIntroRepository {
  FirestorePhotographerIntroRepository({FirebaseFirestore? db})
    : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  @override
  Stream<PhotographerIntro?> watch(String uid) =>
      _doc(uid)
          .snapshots()
          .map((s) => s.data() == null ? null : introFromFirestore(s.data()!));

  @override
  Future<PhotographerIntro?> get(String uid) async {
    final s = await _doc(uid).get();
    return s.data() == null ? null : introFromFirestore(s.data()!);
  }

  @override
  Future<void> save(
    String uid, {
    required String bio,
    required List<String> equipment,
  }) => _doc(uid).set({
    ...introToFirestore(bio: bio, equipment: equipment),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
