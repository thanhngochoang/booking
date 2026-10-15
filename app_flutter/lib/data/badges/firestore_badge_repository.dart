import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/data/badges/badge_repository.dart';

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

BadgeDefinition? badgeDefinitionFromFirestore(
  String id,
  Map<String, dynamic> d,
) {
  final name = _str(d['name']);
  if (name == null) {
    return null;
  }
  final order = d['order'];
  return BadgeDefinition(
    id: id,
    name: name,
    shortName: _str(d['shortName']),
    description: d['description'] is String ? d['description'] as String : '',
    icon: _str(d['icon']) ?? 'medal',
    source: BadgeSource.fromCode(d['source']),
    audience: _str(d['audience']) ?? 'both',
    order: order is num ? order.toInt() : 0,
    hiddenWhenLocked: d['hiddenWhenLocked'] == true,
    // The catalogue stores 'none' | 'metric' | 'minSample'.
    hasProgress: d['progress'] is String && d['progress'] != 'none',
  );
}

/// Reads the catalogue, the earned badges and the owner's progress. Nothing is
/// written by the client.
class FirestoreBadgeRepository implements BadgeRepository {
  FirestoreBadgeRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Future<List<BadgeDefinition>> catalog() async {
    final snap = await _db.collection('badges').orderBy('order').get();
    return [
      for (final d in snap.docs) ?badgeDefinitionFromFirestore(d.id, d.data()),
    ];
  }

  @override
  Stream<List<EarnedBadge>> watchEarned(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('badges')
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs)
            if (d.data()['awardedAt'] is Timestamp)
              EarnedBadge(
                badgeId: d.id,
                awardedAt: (d.data()['awardedAt'] as Timestamp)
                    .toDate()
                    .toUtc(),
                snapshotText: switch (d.data()['snapshot']) {
                  {'text': final String t} when t.isNotEmpty => t,
                  _ => null,
                },
              ),
        ],
      );

  @override
  Stream<Map<String, BadgeProgressEntry>> watchProgress(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('badgeProgress')
      .snapshots()
      .map((snap) {
        final entries = snap.data()?['entries'];
        if (entries is! Map) {
          return const <String, BadgeProgressEntry>{};
        }
        return {
          for (final e in entries.entries)
            if (e.key is String &&
                e.value is Map &&
                (e.value as Map)['current'] is num &&
                (e.value as Map)['target'] is num)
              e.key as String: BadgeProgressEntry(
                current: ((e.value as Map)['current'] as num).toInt(),
                target: ((e.value as Map)['target'] as num).toInt(),
              ),
        };
      });
}
