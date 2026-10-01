// lib/features/explore/explore_links.dart

/// Link from an Explore tile to the Find screen (S04). The Find screen reads
/// `specialty`, `style` and `area` from the query string (plan 3b4).
String findPhotographersPath({String? specialty, String? style, String? area}) {
  final query = {'specialty': ?specialty, 'style': ?style, 'area': ?area};
  return Uri(
    path: '/action',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
