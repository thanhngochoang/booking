import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/special_days.dart';

/// `photographers/{uid}/special_days/{id}`:
/// `{name, from, to, createdAt, updatedAt}`, days as `yyyy-MM-dd` strings.
class FirestoreSpecialDayRepository implements SpecialDayRepository {
  FirestoreSpecialDayRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('photographers').doc(uid).collection('special_days');

  @override
  Stream<List<SpecialDayRange>> watch(String uid) =>
      _col(uid).snapshots().map((s) {
        final out = [
          for (final d in s.docs) ?specialDayFromFirestore(d.id, d.data()),
        ]..sort((a, b) => a.from.compareTo(b.from));
        return out;
      });

  @override
  Future<void> save(String uid, SpecialDayRange r) {
    final fields = {'name': r.name, 'from': r.from, 'to': r.to};
    if (r.isNew) {
      return _col(uid).doc(newUlid()).set({
        ...fields,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return _col(uid)
        .doc(r.id)
        .update({...fields, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();
}

SpecialDayRange? specialDayFromFirestore(String id, Map<String, dynamic> d) {
  final name = d['name'];
  final from = d['from'];
  final to = d['to'];
  if (name is! String ||
      from is! String ||
      to is! String ||
      parseDayKey(from) == null ||
      parseDayKey(to) == null) {
    return null;
  }
  return SpecialDayRange(id: id, name: name, from: from, to: to);
}

/// `holidays/{year}`: `{days: [{day, name}], updatedAt}`. A missing document
/// means no holidays.
class FirestoreHolidayRepository implements HolidayRepository {
  FirestoreHolidayRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Future<List<Holiday>> forYear(int year) async {
    final snap = await _db.collection('holidays').doc('$year').get();
    final days = snap.data()?['days'];
    return [
      if (days is List)
        for (final d in days)
          if (d is Map &&
              d['day'] is String &&
              parseDayKey(d['day'] as String) != null)
            Holiday(
              day: d['day'] as String,
              name: d['name'] is String ? d['name'] as String : '',
            ),
    ];
  }
}
