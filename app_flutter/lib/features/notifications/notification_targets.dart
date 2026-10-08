/// Where a tapped notification or push may go. The server writes the target,
/// but the app opens only paths it knows (plan 10a Decision 3); anything else
/// is "Nội dung này không còn".
///
/// The accepted set mirrors `CLIENT_TARGET_PATTERNS` in
/// packages/domain/test/client_targets.ts (S17 Decision 8): keep both in step.
/// Only `/u/:uid?tab=reviews`, `/studio/recruit?post=<id>` and
/// `/collab?offer=<id>` may carry a query, exactly that one key once.
///
/// Returns the path to push, or null when [raw] is not allowlisted.
String? safeTarget(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.length > 200 || !value.startsWith('/')) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasFragment || uri.hasAuthority) {
    return null;
  }
  final segments = uri.pathSegments;
  // `queryParameters` keeps one value of a repeated key; `All` shows them all.
  final query = uri.queryParametersAll;
  bool id(String s) => _id.hasMatch(s);
  // The path as is, when the target carries no query.
  String? plain() => query.isEmpty ? uri.path : null;
  // The path with exactly one `key=<id>` query, written back normalised.
  String? withQuery(String key) {
    final values = query[key];
    return query.length == 1 &&
            values != null &&
            values.length == 1 &&
            id(values.single)
        ? '${uri.path}?$key=${values.single}'
        : null;
  }

  switch (segments) {
    case ['bookings'] ||
        ['notifications'] ||
        ['me', 'awards'] ||
        ['work', 'earnings'] ||
        ['work', 'earnings', 'account'] ||
        ['work', 'instant'] ||
        ['studio', 'members'] ||
        ['me', 'studio'] ||
        ['verify', 'start'] ||
        ['verify', 'business'] ||
        ['help', 'chat'] ||
        ['me', 'payments']:
      return plain();
    case ['b', final seg] ||
        ['chat', final seg] ||
        ['e', final seg] ||
        ['events', final seg, 'manage'] ||
        ['jobs', final seg] ||
        ['jobs', final seg, 'applications'] ||
        ['instant', final seg] ||
        ['work', 'instant', final seg] ||
        ['work', 'instant', 'offer', final seg] ||
        ['b', final seg, 'delivery'] ||
        ['disputes', final seg] ||
        ['recruit', final seg] ||
        ['u', final seg, 'badges']:
      return id(seg) ? plain() : null;
    case ['u', final uid]:
      if (!id(uid)) {
        return null;
      }
      if (query.isEmpty) {
        return uri.path;
      }
      final tab = query['tab'];
      return query.length == 1 &&
              tab != null &&
              tab.length == 1 &&
              tab.single == 'reviews'
          ? '${uri.path}?tab=reviews'
          : null;
    case ['studio', 'recruit']:
      return withQuery('post');
    case ['collab']:
      return query.isEmpty ? uri.path : withQuery('offer');
  }
  return null;
}

final _id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// The `/b/` and `/chat/` targets cost one read to check they still exist.
bool targetNeedsExistenceCheck(String path) =>
    path.startsWith('/b/') || path.startsWith('/chat/');
