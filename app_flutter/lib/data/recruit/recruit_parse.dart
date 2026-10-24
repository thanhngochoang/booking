// Field readers shared by the recruit and collaboration Firestore adapters
// (`firestore_recruit_repository.dart`, `firestore_collab_repository.dart`).
// Adapter-internal: features never import this file.

/// A string, else ''.
String textOf(Object? v) => v is String ? v : '';

/// A non-empty string, else null.
String? nonEmptyOf(Object? v) => v is String && v.isNotEmpty ? v : null;

/// A number as int, else 0.
int intOf(Object? v) => v is num ? v.toInt() : 0;

/// The strings of a list (other items skipped), else empty.
List<String> stringsOf(Object? v) => [
  if (v is List)
    for (final x in v)
      if (x is String) x,
];

/// A map, else an empty one.
Map<String, dynamic> mapOf(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};
