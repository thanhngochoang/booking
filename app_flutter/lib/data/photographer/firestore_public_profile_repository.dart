import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';

PhotographerProfile photographerProfileFrom({
  required String id,
  Map<String, dynamic>? user,
  required Map<String, dynamic> photographer,
}) => PhotographerProfile(
  summary: photographerSummaryFrom(
    id: id,
    user: user,
    photographer: photographer,
  ),
  intro: introFromFirestore(photographer),
);

class FirestorePublicProfileRepository implements PublicProfileRepository {
  FirestorePublicProfileRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Future<PhotographerProfile?> load(String uid) async {
    final (user, photographer) = await (
      _db.collection('users').doc(uid).get(),
      _db.collection('photographers').doc(uid).get(),
    ).wait;
    final data = photographer.data();
    if (data == null) {
      return null;
    }
    return photographerProfileFrom(
      id: uid,
      user: user.data(),
      photographer: data,
    );
  }
}
