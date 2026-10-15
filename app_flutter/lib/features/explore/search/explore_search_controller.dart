// lib/features/explore/search/explore_search_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/discovery/explore_catalog_providers.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/search/explore_search.dart';

class ExploreSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final exploreSearchQueryProvider =
    NotifierProvider<ExploreSearchQueryNotifier, String>(
  ExploreSearchQueryNotifier.new,
);

final exploreSearchProvider =
    FutureProvider.autoDispose<ExploreSearchResults>((ref) async {
  final query = ref.watch(exploreSearchQueryProvider);
  if (query.trim().isEmpty) {
    return ExploreSearchResults.empty;
  }

  final specialties = [
    for (final s in kSpecialties) (id: s.id, label: s.labelVi),
  ];
  final styles = [
    for (final s in kStyles) (id: s.id, label: s.labelVi),
  ];

  final areas = ref.watch(areasProvider).value ?? const <AreaOption>[];
  final catalog = ref.watch(exploreCatalogProvider).value ?? ExploreCatalog.empty;

  // Photographers pool is loaded if query >= 2 chars
  List<PhotographerSummary> photographers = const [];
  if (query.trim().length >= 2) {
    final repo = ref.watch(photographerRepositoryProvider);
    photographers = await repo.candidates();
  }

  return searchExplore(
    query,
    specialties: specialties,
    styles: styles,
    areas: areas,
    photographers: photographers,
    catalog: catalog,
  );
});
