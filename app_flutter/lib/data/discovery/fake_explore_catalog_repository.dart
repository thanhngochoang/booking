// lib/data/discovery/fake_explore_catalog_repository.dart
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/discovery/explore_catalog_repository.dart';

class FakeExploreCatalogRepository implements ExploreCatalogRepository {
  FakeExploreCatalogRepository([ExploreCatalog catalog = ExploreCatalog.empty])
      : _catalog = catalog;

  ExploreCatalog _catalog;
  Object? failWith;

  void setCatalog(ExploreCatalog catalog) => _catalog = catalog;

  @override
  Future<ExploreCatalog> load() async {
    if (failWith != null) {
      throw failWith!;
    }
    return _catalog;
  }
}
