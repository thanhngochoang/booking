// lib/data/events/firestore_nearby_events_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/firestore_event_mapping.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';

/// Explore's reads over `events`. Only public events (`open`, `full`) are
/// asked for, as the security rules require; entry-ticket events are left out. Geohash cells are prefix ranges on
/// `location.geohash` (index `status, location.geohash, startAt`).
class FirestoreNearbyEventsRepository implements NearbyEventsRepository {
  FirestoreNearbyEventsRepository({FirebaseFirestore? db, this.pageSize = 100})
    : _override = db;

  final FirebaseFirestore? _override;

  /// Rows per read inside one cell.
  final int pageSize;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;
  static const _public = ['open', 'full'];

  /// Decision 11: entry-ticket events are not events to explore; dropped
  /// after the read (a `type != entry` filter would need new indexes).
  static bool _isEntry(Map<String, dynamic> d) => d['type'] == 'entry';

  Query<Map<String, dynamic>> _base() =>
      _db.collection('events').where('status', whereIn: _public);

  /// All documents of [cell] from [q], page by page, never cut short.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _readAll(
    Query<Map<String, dynamic>> q,
  ) async {
    final out = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      final snap = await (last == null ? q : q.startAfterDocument(last))
          .limit(pageSize)
          .get();
      out.addAll(snap.docs);
      if (snap.docs.length < pageSize) {
        return out;
      }
      last = snap.docs.last;
    }
  }

  Query<Map<String, dynamic>> _cell(
    Query<Map<String, dynamic>> q,
    String cell,
  ) => q
      .where('location.geohash', isGreaterThanOrEqualTo: cell)
      .where('location.geohash', isLessThan: '$cell');

  @override
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  }) async {
    final byId = <String, EventSummary>{};
    final fromTs = Timestamp.fromDate(from);
    final reads = await Future.wait([
      for (final cell in cells.toSet())
        _readAll(
          _cell(_base(), cell)
              .where('startAt', isGreaterThanOrEqualTo: fromTs)
              .orderBy('location.geohash')
              .orderBy('startAt'),
        ),
    ]);
    for (final docs in reads) {
      for (final d in docs) {
        if (_isEntry(d.data())) continue;
        final e = eventSummaryFromFirestore(d.id, d.data());
        if (e != null) {
          byId[e.id] = e;
        }
      }
    }
    // [limit] is a hint for fakes: a cell is returned whole so the caller can
    // filter by distance without losing events inside it.
    return byId.values.toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<List<EventSummary>> upcoming({
    required DateTime from,
    int limit = 20,
  }) async {
    final snap = await _base()
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('startAt')
        .limit(limit)
        .get();
    return [
      for (final d in snap.docs)
        if (!_isEntry(d.data())) ?eventSummaryFromFirestore(d.id, d.data()),
    ];
  }

  @override
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  }) async {
    // With cells the query is a geohash range and always carries a createdAt
    // bound (epoch when [since] is null), so it is served by the existing
    // (status, location.geohash, createdAt) index; a bare geohash range with
    // no createdAt would need a (status, location.geohash) index instead.
    final bound = Timestamp.fromDate(
      since ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

    var total = 0;
    final targets = cells == null ? <String?>[null] : cells.toSet().toList();
    for (final cell in targets) {
      var q = _base();
      if (cell != null) {
        q = _cell(q, cell)
            .where('createdAt', isGreaterThan: bound)
            .orderBy('location.geohash')
            .orderBy('createdAt');
      } else if (since != null) {
        q = q.where('createdAt', isGreaterThan: bound);
      }
      // The capped number is all Explore shows, so read at most [cap] rows.
      final snap = await q.limit(cap - total).get();
      total += snap.docs.where((d) => !_isEntry(d.data())).length;
      if (total >= cap) {
        return cap;
      }
    }
    return total;
  }
}
