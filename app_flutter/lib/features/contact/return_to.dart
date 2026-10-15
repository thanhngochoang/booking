// lib/features/contact/return_to.dart
/// A `returnTo` query value is only followed when it is an absolute in-app
/// path; anything that could leave the app (a scheme, `//host`, backslashes)
/// is dropped so the screen cannot be used as an open redirect.
String? safeReturnTo(String? value) {
  if (value == null || value.isEmpty) return null;
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  if (value.contains(r'\')) return null;
  return value;
}
