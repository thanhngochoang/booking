// lib/data/discovery/firestore_explore_catalog_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/discovery/explore_catalog_repository.dart';

class FirestoreExploreCatalogRepository implements ExploreCatalogRepository {
  FirestoreExploreCatalogRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<ExploreCatalog> load() async {
    final snap = await _db.collection('catalog').doc('explore').get();
    if (!snap.exists) {
      return ExploreCatalog.empty;
    }

    final data = snap.data();
    if (data == null) {
      return ExploreCatalog.empty;
    }

    final specialtiesRaw = data['specialties'];
    if (specialtiesRaw is! Map) {
      return ExploreCatalog.empty;
    }

    final map = <String, ExploreCategoryStat>{};
    for (final entry in specialtiesRaw.entries) {
      final key = entry.key;
      if (key is! String || key.isEmpty) continue;

      final val = entry.value;
      if (val is! Map) continue;

      final count = val['serviceCount'];
      if (count is! num || count.toInt() < 0) continue;

      final cover = val['coverUrl'];
      final coverUrl = (cover is String && cover.isNotEmpty) ? cover : null;

      map[key] = ExploreCategoryStat(
        serviceCount: count.toInt(),
        coverUrl: coverUrl,
      );
    }

    return ExploreCatalog(map);
  }
}
