import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/notifications/notification_prefs_repository.dart';

/// `users/{uid}/private/notification_prefs` (owner read/write; rules force
/// `booking.inApp` on and `updatedAt == request.time`).
class FirestoreNotificationPrefsRepository
    implements NotificationPrefsRepository {
  FirestoreNotificationPrefsRepository({FirebaseFirestore? db})
    : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('notification_prefs');

  @override
  Stream<PrefsSnapshot> watch(String uid) => _doc(uid).snapshots().map(
    (s) => PrefsSnapshot(
      NotificationPrefs.fromMap(s.data()),
      fromCache: s.metadata.isFromCache,
    ),
  );

  @override
  Future<void> save(String uid, NotificationPrefs prefs) =>
      _doc(uid)
          .set({...prefs.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
}
