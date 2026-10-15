import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/recommendation/availability_lookup.dart';

class FirestoreAvailabilityLookup implements AvailabilityLookup {
  FirestoreAvailabilityLookup({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DayAvailability _state(Object? raw) => switch (raw) {
    'pending' => DayAvailability.pending,
    'off' => DayAvailability.off,
    'booked' => DayAvailability.booked,
    // A state we do not know is treated as unavailable rather than offering a
    // day that may be taken.
    _ => DayAvailability.booked,
  };

  @override
  Future<Map<String, DayAvailability>> on(
    String dayKey,
    Iterable<String> photographerIds,
  ) async {
    final ids = photographerIds.toSet().toList();
    final snaps = await Future.wait([
      for (final id in ids)
        _db
            .collection('availability')
            .doc(id)
            .collection('days')
            .doc(dayKey)
            .get(),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        if (snaps[i].exists) ids[i]: _state(snaps[i].data()?['state']),
    };
  }
}
