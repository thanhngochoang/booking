import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_repository.dart';

/// `photographers/{uid}.skills` on Firestore. The merge write keeps the
/// server's `skills.completeness` and every other field of the document.
class FirestoreSkillsRepository implements SkillsRepository {
  FirestoreSkillsRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  @override
  Future<PhotographerSkills> load(String uid) async {
    final snap = await _doc(uid).get();
    return skillsFromMap(snap.data()?['skills']);
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) => _doc(uid).set({
    'skills': skillsToMap(skills),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
