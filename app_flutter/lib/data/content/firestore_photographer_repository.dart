// lib/data/content/firestore_photographer_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

double _double(Object? v) => v is num ? v.toDouble() : 0;
int _int(Object? v) => v is num ? v.toInt() : 0;
int? _intOrNull(Object? v) => v is num ? v.toInt() : null;
String? _str(Object? v) => v is String ? v : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<String> _strings(Object? v) => [if (v is List) ...v.whereType<String>()];

/// Maps a `photographers/{id}` document (plus the public `users/{id}` one for
/// name and avatar). Never throws; reads nothing from the private contact
/// subcollection.
PhotographerSummary photographerSummaryFrom({
  required String id,
  Map<String, dynamic>? user,
  required Map<String, dynamic> photographer,
}) {
  final skills = _map(photographer['skills']);
  final skillIds = [
    if (skills['specialties'] is List)
      for (final s in skills['specialties'] as List)
        if (s is Map && s['id'] is String) s['id'] as String,
  ];
  final flat = _strings(photographer['specialties']);
  final skillStyles = _strings(skills['styles']);
  final flatStyles = _strings(photographer['styles']);
  final area = _map(photographer['serviceArea']);
  final geo = area['geo'];
  final stats = _map(photographer['stats']);
  final created = photographer['createdAt'];
  return PhotographerSummary(
    id: id,
    displayName: _str(user?['displayName']) ?? '',
    avatarUrl: _str(user?['avatarUrl']),
    coverUrl: _str(photographer['coverUrl']),
    verified: photographer['verified'] == true,
    specialtyIds: skillIds.isNotEmpty ? skillIds : flat,
    styleIds: skillStyles.isNotEmpty ? skillStyles : flatStyles,
    areaLabel: _str(area['city']),
    lat: geo is GeoPoint ? geo.latitude : null,
    lng: geo is GeoPoint ? geo.longitude : null,
    ratingAvg: _double(stats['rating']),
    reviewCount: _int(stats['reviewCount']),
    completedCount: _int(stats['completedCount']),
    responseMinutes: _intOrNull(stats['responseMinutes']),
    startingPriceVnd: _intOrNull(photographer['startingPrice']),
    nextFreeDate: _str(stats['nextFreeDate']),
    createdAt: created is Timestamp ? created.toDate().toUtc() : null,
  );
}

ServiceSummary? serviceFromFirestore(
  String id,
  String photographerId,
  Map<String, dynamic> d,
) {
  final name = d['name'];
  final price = _intOrNull(d['price']);
  if (name is! String || price == null || price <= 0) {
    return null;
  }
  final deliverables = _map(d['deliverables']);
  return ServiceSummary(
    id: id,
    photographerId: photographerId,
    name: name,
    specialtyId: _str(d['specialty']),
    priceVnd: price,
    durationMinutes: _int(d['durationMinutes']),
    photoCount: _intOrNull(deliverables['photoCount']),
    editedCount: _intOrNull(deliverables['editedCount']),
    deliveryDays: _intOrNull(deliverables['deliveryDays']),
    coverUrl: _str(d['coverUrl']),
    active: d['active'] != false,
  );
}

class FirestorePhotographerRepository implements PhotographerRepository {
  FirestorePhotographerRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static const _whereInMax = 30;

  /// Documents of [collection] by id, chunked by [_whereInMax]. Ids that are
  /// empty or contain '/' cannot be document ids and are simply absent.
  Future<Map<String, Map<String, dynamic>>> _byIds(
    String collection,
    List<String> ids,
  ) async {
    final valid = [
      for (final id in ids)
        if (id.isNotEmpty && !id.contains('/')) id,
    ];
    final snaps = await Future.wait([
      for (var i = 0; i < valid.length; i += _whereInMax)
        _db
            .collection(collection)
            .where(
              FieldPath.documentId,
              whereIn: valid.sublist(
                i,
                i + _whereInMax > valid.length ? valid.length : i + _whereInMax,
              ),
            )
            .get(),
    ]);
    return {
      for (final s in snaps)
        for (final d in s.docs) d.id: d.data(),
    };
  }

  Future<List<PhotographerSummary>> _join(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final users = await _byIds('users', [for (final d in docs) d.id]);
    return [
      for (final d in docs)
        photographerSummaryFrom(
          id: d.id,
          user: users[d.id],
          photographer: d.data(),
        ),
    ];
  }

  @override
  Future<Map<String, PhotographerSummary>> summaries(
    Iterable<String> ids,
  ) async {
    final unique = ids.toSet().toList();
    final (photographers, users) = await (
      _byIds('photographers', unique),
      _byIds('users', unique),
    ).wait;
    return {
      for (final e in photographers.entries)
        e.key: photographerSummaryFrom(
          id: e.key,
          user: users[e.key],
          photographer: e.value,
        ),
    };
  }

  /// Invariant (server): `stats.rating` is always written (0 when there are
  /// no reviews) whenever `stats.nextFreeDate` is written; a photographer
  /// without `stats.rating` is not returned by this query.
  @override
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  }) async {
    final from = vnDateKey(now);
    final to = vnDateKey(now.add(const Duration(days: 7)));
    final snap = await _db
        .collection('photographers')
        .where('onboardingComplete', isEqualTo: true)
        .where('stats.nextFreeDate', isGreaterThanOrEqualTo: from)
        .where('stats.nextFreeDate', isLessThan: to)
        .orderBy('stats.nextFreeDate')
        .orderBy('stats.rating', descending: true)
        .orderBy(FieldPath.documentId)
        .limit(clampPageSize(limit))
        .get();
    final list = await _join(snap.docs);
    // Defensive: the query already orders this way; re-sort so a malformed
    // document can never break the contract order.
    list.sort((a, b) {
      final byDay = (a.nextFreeDate ?? '').compareTo(b.nextFreeDate ?? '');
      if (byDay != 0) {
        return byDay;
      }
      final byRating = b.ratingAvg.compareTo(a.ratingAvg);
      return byRating != 0 ? byRating : a.id.compareTo(b.id);
    });
    return list;
  }

  /// Unordered pool (`__name__` order); callers cache it. Revisit the
  /// ordering once there are more than 200 photographers.
  @override
  Future<List<PhotographerSummary>> candidates({int limit = 200}) async {
    final snap = await _db
        .collection('photographers')
        .where('onboardingComplete', isEqualTo: true)
        .limit(clampPageSize(limit, 200))
        .get();
    return _join(snap.docs);
  }
}

class FirestoreServiceRepository implements ServiceRepository {
  FirestoreServiceRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _services(String photographerId) =>
      _db
          .collection('photographers')
          .doc(photographerId)
          .collection('services');

  @override
  Future<ServiceSummary?> byId(String photographerId, String serviceId) async {
    final snap = await _services(photographerId).doc(serviceId).get();
    final data = snap.data();
    return data == null
        ? null
        : serviceFromFirestore(snap.id, photographerId, data);
  }

  @override
  Future<List<ServiceSummary>> activeFor(
    String photographerId, {
    int limit = 50,
  }) async {
    final snap = await _services(photographerId)
        .where('active', isEqualTo: true)
        .limit(clampPageSize(limit))
        .get();
    return [
      for (final d in snap.docs)
        ?serviceFromFirestore(d.id, photographerId, d.data()),
    ];
  }
}
