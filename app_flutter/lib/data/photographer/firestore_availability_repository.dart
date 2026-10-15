import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';

/// `availability/{uid}/days/{yyyy-MM-dd}`; no document means free.
class FirestoreAvailabilityRepository implements AvailabilityRepository {
  FirestoreAvailabilityRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _days(String uid) =>
      _db.collection('availability').doc(uid).collection('days');

  @override
  Stream<Map<DateTime, AvailabilityDay>> watchRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) => _days(uid)
      // Day keys sort like dates, so a document-id range is a date range.
      .orderBy(FieldPath.documentId)
      .startAt([vnDateKey(calendarDay(from))])
      .endAt([vnDateKey(calendarDay(to))])
      .snapshots()
      .map(
        (s) => {
          for (final d in [
            for (final doc in s.docs)
              ?availabilityDayFromFirestore(doc.id, doc.data()),
          ])
            d.day: d,
        },
      );

  @override
  Future<void> markOff(String uid, Iterable<DateTime> days) async {
    final batch = _db.batch();
    for (final d in days) {
      batch.set(_days(uid).doc(vnDateKey(calendarDay(d))), {
        ...offDayToFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> clearOff(String uid, Iterable<DateTime> days) async {
    final batch = _db.batch();
    for (final d in days) {
      batch.delete(_days(uid).doc(vnDateKey(calendarDay(d))));
    }
    await batch.commit();
  }
}
