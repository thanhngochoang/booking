// lib/data/spots/firestore_spot_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/firestore_event_mapping.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_repository.dart';

class FirestoreSpotRepository implements SpotRepository {
  FirestoreSpotRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<List<SpotEntry>> hot(String key) async {
    final doc = await _db.collection('spot_rankings').doc(key).get();
    final data = doc.exists
        ? doc.data()
        : (await _db.collection('spot_rankings').doc('all').get()).data();
    final entries = data?['entries'] as List?;
    if (entries == null) return const [];
    return entries
        .whereType<Map>()
        .map((e) => spotEntryFromMap(e.cast<String, dynamic>()))
        .whereType<SpotEntry>()
        .toList();
  }

  @override
  Future<List<SpotEntry>> directory() async {
    final doc = await _db.collection('spot_directory').doc('all').get();
    final entries = doc.data()?['entries'] as List?;
    if (entries == null) return const [];
    return entries
        .whereType<Map>()
        .map((e) => spotEntryFromMap(e.cast<String, dynamic>()))
        .whereType<SpotEntry>()
        .toList();
  }

  @override
  Future<Spot?> spot(String spotId) async {
    final doc = await _db.collection('spots').doc(spotId).get();
    return spotFromMap(spotId, doc.data());
  }

  @override
  Future<List<SpotSchedule>> openSchedulesAt(String spotId) async {
    final snap = await _db
        .collection('spot_schedules')
        .where('spotId', isEqualTo: spotId)
        .where('status', isEqualTo: 'open')
        .get();
    return snap.docs
        .map((d) => spotScheduleFromMap(d.id, d.data()))
        .whereType<SpotSchedule>()
        .toList();
  }

  @override
  Future<List<SlotOffer>> openOffersAt(String spotId) async {
    final snap = await _db
        .collection('spot_slot_offers')
        .where('spotId', isEqualTo: spotId)
        .where('status', isEqualTo: 'open')
        .get();
    return snap.docs
        .map((d) => slotOfferFromMap(d.id, d.data()))
        .whereType<SlotOffer>()
        .toList();
  }

  @override
  Future<SpotDay?> spotDay(String scheduleId, String day) async {
    final doc =
        await _db.collection('spot_days').doc('${scheduleId}_$day').get();
    return spotDayFromMap(doc.data());
  }

  @override
  Future<SpotSchedule?> schedule(String scheduleId) async {
    final doc = await _db.collection('spot_schedules').doc(scheduleId).get();
    return spotScheduleFromMap(scheduleId, doc.data());
  }

  @override
  Future<SlotOffer?> offer(String offerId) async {
    final doc = await _db.collection('spot_slot_offers').doc(offerId).get();
    return slotOfferFromMap(offerId, doc.data());
  }

  @override
  Future<List<PostSummary>> postsAt(
    String spotId, {
    DateTime? before,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('posts')
        .where('spotId', isEqualTo: spotId);

    if (before != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(before));
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    final snap = await query.get();
    return snap.docs
        .map((d) => postFromFirestore(d.id, d.data()))
        .whereType<PostSummary>()
        .toList();
  }

  @override
  Future<List<EventSummary>> eventsAt(String spotId, {int limit = 10}) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db
        .collection('events')
        .where('spotId', isEqualTo: spotId)
        .where('status', whereIn: ['open', 'full'])
        .where('startAt', isGreaterThanOrEqualTo: now)
        .orderBy('startAt')
        .limit(limit)
        .get();

    return snap.docs
        .map((d) => eventSummaryFromFirestore(d.id, d.data()))
        .whereType<EventSummary>()
        .toList();
  }

  @override
  Stream<List<SpotSchedule>> watchMine(String uid) {
    return _db
        .collection('spot_schedules')
        .where('providerId', isEqualTo: uid)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => spotScheduleFromMap(d.id, d.data()))
              .whereType<SpotSchedule>()
              .toList(),
        );
  }

  @override
  Stream<List<SlotOffer>> watchMyOffers(String uid) {
    return _db
        .collection('spot_slot_offers')
        .where('providerId', isEqualTo: uid)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => slotOfferFromMap(d.id, d.data()))
              .whereType<SlotOffer>()
              .toList(),
        );
  }

  @override
  Future<({String scheduleId, List<String> addedDays})> saveSchedule(
    SpotScheduleInput input,
  ) async {
    try {
      final res = await _functions
          .httpsCallable('saveSpotSchedule')
          .call<dynamic>(input.toCallable());
      final data = (res.data as Map).cast<String, dynamic>();
      final scheduleId = data['scheduleId'] as String;
      final addedDays = (data['addedDays'] as List).cast<String>();
      return (scheduleId: scheduleId, addedDays: addedDays);
    } catch (e) {
      throw spotErrorOf(e);
    }
  }

  @override
  Future<void> cancelSchedule(String scheduleId) async {
    try {
      await _functions
          .httpsCallable('cancelSpotSchedule')
          .call<dynamic>({'scheduleId': scheduleId});
    } catch (e) {
      throw spotErrorOf(e);
    }
  }

  @override
  Future<String> saveOffer(SlotOfferInput input) async {
    try {
      final res = await _functions
          .httpsCallable('saveSlotOffer')
          .call<dynamic>(input.toCallable());
      final data = (res.data as Map).cast<String, dynamic>();
      return data['offerId'] as String;
    } catch (e) {
      throw spotErrorOf(e);
    }
  }

  @override
  Future<void> closeOffer(String offerId) async {
    try {
      await _functions
          .httpsCallable('closeSlotOffer')
          .call<dynamic>({'offerId': offerId});
    } catch (e) {
      throw spotErrorOf(e);
    }
  }
}
