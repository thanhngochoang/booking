import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

/// `photographers/{uid}.skills` on Firestore. The merge write keeps the
/// server's fields (`completeness`, `completenessNext`,
/// `completenessNextAfter`, `updatedAt`, `evidenceRemovedAt`, written by `onPhotographerWrite`) and every other
/// field of the document.
class FirestoreSkillsRepository implements SkillsRepository {
  FirestoreSkillsRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  @override
  Future<SkillsSnapshot> load(String uid) async {
    final raw = (await _doc(uid).get()).data()?['skills'];
    return SkillsSnapshot(
      skillsFromMap(raw),
      skillsServerInfoFromMap(raw, _instant),
    );
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) => _doc(uid).set({
    'skills': skillsToMap(skills),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

DateTime? _instant(Object? v) => v is Timestamp ? v.toDate().toUtc() : null;
