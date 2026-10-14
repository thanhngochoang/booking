// lib/features/explore/search/explore_search.dart
import 'package:photobooking/core/text_fold.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/location/area.dart';

enum ExploreHitKind { service, style, place, photographer }

class ExploreHit {
  const ExploreHit({
    required this.kind,
    required this.id,
    required this.label,
    this.serviceCount,
    this.photographer,
  });

  final ExploreHitKind kind;
  final String id;
  final String label;
  final int? serviceCount;
  final PhotographerSummary? photographer;
}

class ExploreSearchResults {
  const ExploreSearchResults({
    this.services = const [],
    this.styles = const [],
    this.places = const [],
    this.photographers = const [],
  });

  final List<ExploreHit> services;
  final List<ExploreHit> styles;
  final List<ExploreHit> places;
  final List<ExploreHit> photographers;

  static const empty = ExploreSearchResults();

  bool get isEmpty =>
      services.isEmpty &&
      styles.isEmpty &&
      places.isEmpty &&
      photographers.isEmpty;
}

/// Pure search over specialties, styles, areas, and photographers.
///
/// Rules:
/// - Empty/whitespace trimmed query -> [ExploreSearchResults.empty].
/// - Accents folded on both query and candidates.
/// - Matches substring anywhere; prefix matches appear before non-prefix matches,
///   then alphabetical by label/name.
/// - Limits: 5 services, 5 styles, 5 places, 10 photographers.
/// - Photographers searched only when folded query length >= 2.
ExploreSearchResults searchExplore(
  String query, {
  required List<({String id, String label})> specialties,
  required List<({String id, String label})> styles,
  required List<AreaOption> areas,
  required List<PhotographerSummary> photographers,
  required ExploreCatalog catalog,
}) {
  final q = foldVietnamese(query.trim());
  if (q.isEmpty) {
    return ExploreSearchResults.empty;
  }

  int compareHits(String nameA, String nameB) {
    final foldA = foldVietnamese(nameA);
    final foldB = foldVietnamese(nameB);
    final prefixA = foldA.startsWith(q);
    final prefixB = foldB.startsWith(q);
    if (prefixA && !prefixB) return -1;
    if (!prefixA && prefixB) return 1;
    return nameA.compareTo(nameB);
  }

  // 1. Services (limit 5)
  final matchedServices = specialties
      .where((s) => foldVietnamese(s.label).contains(q))
      .toList()
    ..sort((a, b) => compareHits(a.label, b.label));

  final serviceHits = matchedServices.take(5).map((s) {
    final count = catalog.specialties[s.id]?.serviceCount;
    return ExploreHit(
      kind: ExploreHitKind.service,
      id: s.id,
      label: s.label,
      serviceCount: count,
    );
  }).toList();

  // 2. Styles (limit 5)
  final matchedStyles = styles
      .where((s) => foldVietnamese(s.label).contains(q))
      .toList()
    ..sort((a, b) => compareHits(a.label, b.label));

  final styleHits = matchedStyles.take(5).map((s) {
    return ExploreHit(
      kind: ExploreHitKind.style,
      id: s.id,
      label: s.label,
    );
  }).toList();

  // 3. Places (limit 5)
  final matchedPlaces = areas
      .where((a) => foldVietnamese(a.name).contains(q))
      .toList()
    ..sort((a, b) => compareHits(a.name, b.name));

  final placeHits = matchedPlaces.take(5).map((a) {
    return ExploreHit(
      kind: ExploreHitKind.place,
      id: a.id,
      label: a.name,
    );
  }).toList();

  // 4. Photographers (limit 10, only if q.length >= 2)
  List<ExploreHit> photographerHits = const [];
  if (q.length >= 2) {
    final matchedPhotographers = photographers
        .where((p) => foldVietnamese(p.displayName).contains(q))
        .toList()
      ..sort((a, b) => compareHits(a.displayName, b.displayName));

    photographerHits = matchedPhotographers.take(10).map((p) {
      return ExploreHit(
        kind: ExploreHitKind.photographer,
        id: p.id,
        label: p.displayName,
        photographer: p,
      );
    }).toList();
  }

  return ExploreSearchResults(
    services: serviceHits,
    styles: styleHits,
    places: placeHits,
    photographers: photographerHits,
  );
}
