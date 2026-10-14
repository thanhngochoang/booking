// lib/data/discovery/explore_catalog_repository.dart
import 'package:photobooking/data/discovery/explore_catalog.dart';

abstract class ExploreCatalogRepository {
  Future<ExploreCatalog> load();
}
