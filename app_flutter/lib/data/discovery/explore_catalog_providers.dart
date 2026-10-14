// lib/data/discovery/explore_catalog_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/discovery/explore_catalog_repository.dart';
import 'package:photobooking/data/discovery/firestore_explore_catalog_repository.dart';

final exploreCatalogRepositoryProvider = Provider<ExploreCatalogRepository>(
  (ref) => FirestoreExploreCatalogRepository(),
);

final exploreCatalogProvider = FutureProvider.autoDispose<ExploreCatalog>(
  (ref) => ref.watch(exploreCatalogRepositoryProvider).load(),
);
