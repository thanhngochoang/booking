/// Where a tapped notification or push may go. The server writes the target,
/// but the app opens only paths it knows (plan 10a Decision 3); anything else
/// is "Nội dung này không còn".
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
  final query = uri.queryParameters;
  bool id(String s) => _id.hasMatch(s);

  switch (segments) {
    case ['bookings'] || ['notifications'] || ['me', 'awards']:
      return query.isEmpty ? uri.path : null;
    case ['b', final bookingId]:
      return id(bookingId) && query.isEmpty ? uri.path : null;
    case ['chat', final chatId]:
      return id(chatId) && query.isEmpty ? uri.path : null;
    case ['u', final uid, 'badges']:
      return id(uid) && query.isEmpty ? uri.path : null;
    case ['u', final uid]:
      if (!id(uid)) {
        return null;
      }
      if (query.isEmpty) {
        return uri.path;
      }
      return query.length == 1 && query['tab'] == 'reviews'
          ? '${uri.path}?tab=reviews'
          : null;
  }
  return null;
}

final _id = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// The `/b/` and `/chat/` targets cost one read to check they still exist.
bool targetNeedsExistenceCheck(String path) =>
    path.startsWith('/b/') || path.startsWith('/chat/');
