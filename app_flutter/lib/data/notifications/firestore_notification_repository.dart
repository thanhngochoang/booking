import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

DateTime? _time(Object? v) => v is Timestamp ? v.toDate().toUtc() : null;

/// Parses `users/{uid}/notifications/{id}`; null when it cannot be shown
/// (no time, or no title). Unknown tab codes read as `system`.
AppNotification? notificationFromFirestore(String id, Map<String, dynamic> d) {
  final createdAt = _time(d['createdAt']);
  final title = _str(d['title']);
  final category = NotificationCategory.tryParse(d['category']);
  if (createdAt == null || title == null || category == null) {
    return null;
  }
  final rawActors = d['actors'];
  final actors = <NotificationActor>[
    if (rawActors is List)
      for (final a in rawActors)
        if (a is Map && _str(a['name']) != null)
          NotificationActor(
            id: _str(a['id']) ?? '',
            name: a['name'] as String,
            avatarUrl: _str(a['avatarUrl']),
          ),
  ];
  final count = d['count'];
  return AppNotification(
    id: id,
    type: _str(d['type']) ?? '',
    tab: NotificationTab.fromCode(d['tab']),
    category: category,
    title: title,
    body: d['body'] is String ? d['body'] as String : '',
    target: d['target'] is String ? d['target'] as String : '',
    createdAt: createdAt,
    readAt: _time(d['readAt']),
    actors: actors,
    count: count is num && count >= 1 ? count.toInt() : 1,
    thumbUrl: _str(d['thumbUrl']),
  );
}

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

/// Reads the inbox directly; only `readAt` is written (rules), everything else
/// is server-side. "Mark all" goes through the callable.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functionsOverride = functions;

  final FirebaseFirestore? _override;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  CollectionReference<Map<String, dynamic>> _rows(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Query<Map<String, dynamic>> _query(
    String uid,
    NotificationTab? tab,
    int limit, {
    DateTime? upTo,
  }) {
    Query<Map<String, dynamic>> q = _rows(uid);
    if (tab != null) {
      q = q.where('tab', isEqualTo: tab.name);
    }
    if (upTo != null) {
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(upTo));
    }
    return q.orderBy('createdAt', descending: true).limit(limit);
  }

  NotificationPage _toPage(
    QuerySnapshot<Map<String, dynamic>> snap,
    int limit,
  ) {
    final items = <AppNotification>[
      for (final d in snap.docs) ?notificationFromFirestore(d.id, d.data()),
    ];
    // The cursor follows the raw rows so an unparsable last row cannot stall paging.
    final last = snap.docs.isEmpty ? null : snap.docs.last;
    final lastAt = last == null ? null : _time(last.data()['createdAt']);
    return NotificationPage(
      items: items,
      next: snap.docs.length >= limit && last != null && lastAt != null
          ? NotificationCursor(createdAt: lastAt, id: last.id)
          : null,
      fromCache: snap.metadata.isFromCache,
    );
  }

  @override
  Stream<NotificationPage> watchFirstPage(
    String uid, {
    NotificationTab? tab,
    int limit = 30,
  }) => _query(uid, tab, limit).snapshots().map((s) => _toPage(s, limit));

  @override
  Future<NotificationPage> page(
    String uid, {
    NotificationTab? tab,
    required NotificationCursor after,
    int limit = 30,
  }) async {
    // Rows are ordered by (createdAt, id) both descending, the order Firestore
    // gives ties. The query takes every row at or before the cursor time and
    // over-fetches; rows of the cursor's own time that sort at or before the
    // cursor id were already delivered. A window that may be cut inside its
    // oldest tie group drops that group (it may be incomplete) and widens.
    var fetch = limit * 2 + 2;
    while (true) {
      final snap = await _query(uid, tab, fetch, upTo: after.createdAt).get();
      final rows =
          [
            for (final d in snap.docs)
              if (_time(d.data()['createdAt']) case final t?) (t, d),
          ]..sort((a, b) {
            final c = b.$1.compareTo(a.$1);
            return c != 0 ? c : b.$2.id.compareTo(a.$2.id);
          });
      final truncated = snap.docs.length >= fetch;
      final oldest = rows.isEmpty ? null : rows.last.$1;
      final fresh = [
        for (final (t, d) in rows)
          if ((t.isBefore(after.createdAt) || d.id.compareTo(after.id) < 0) &&
              !(truncated && t == oldest))
            (t, d),
      ];
      if (fresh.length >= limit || !truncated) {
        final take = fresh.take(limit).toList();
        final items = <AppNotification>[
          for (final (_, d) in take) ?notificationFromFirestore(d.id, d.data()),
        ];
        return NotificationPage(
          items: items,
          next: take.length >= limit
              ? NotificationCursor(createdAt: take.last.$1, id: take.last.$2.id)
              : null,
          fromCache: snap.metadata.isFromCache,
        );
      }
      fetch *= 2;
    }
  }

  @override
  Stream<int> watchUnreadCount(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('inbox')
      .snapshots()
      .map((s) {
        final n = s.data()?['unreadCount'];
        return n is num && n > 0 ? n.toInt() : 0;
      });

  @override
  Future<AppNotification?> latest(String uid) async {
    final snap = await _query(uid, null, 1).get();
    for (final d in snap.docs) {
      return notificationFromFirestore(d.id, d.data());
    }
    return null;
  }

  @override
  Future<void> markRead(String uid, Iterable<String> ids) async {
    final unique = ids.where(_validId).toSet();
    if (unique.isEmpty) {
      return;
    }
    final batch = _db.batch();
    for (final id in unique) {
      batch.update(_rows(uid).doc(id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> markAllRead() async {
    await _functions
        .httpsCallable(
          'markAllNotificationsRead',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Object?>(<String, Object?>{});
  }

  @override
  Future<bool> targetExists(String target) async {
    final path = target.split('?').first;
    final parts = path.split('/');
    // ['', 'b', id] or ['', 'chat', id]
    if (parts.length != 3 || parts.first.isNotEmpty) {
      return true;
    }
    final collection = switch (parts[1]) {
      'b' => 'bookings',
      'chat' => 'chats',
      _ => null,
    };
    if (collection == null) {
      return true;
    }
    if (!_validId(parts[2])) {
      return false;
    }
    try {
      return (await _db.collection(collection).doc(parts[2]).get()).exists;
    } on FirebaseException catch (e) {
      // A document that is gone (or no longer readable) is "not available";
      // network trouble is not an answer.
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        return false;
      }
      rethrow;
    }
  }
}
