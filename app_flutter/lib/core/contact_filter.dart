/// What [findContactLeak] found.
enum ContactLeak { phone, email, link, zalo }

// Port of packages/domain/src/contact_filter.ts (job posts plan Decision 15),
// kept identical so the client blocks exactly what the server refuses: money
// like "1.000.000.000₫" is removed first so prices never read as phone
// numbers; digits may be split by spaces, dots, dashes or brackets.
final _money = RegExp(
  r'\d{1,3}(?:[.,]\d{3})+\s*(?:₫|đ|vnđ|vnd)',
  caseSensitive: false,
);
final _phone = RegExp(r'(?:\+?84|0)(?:[\s.\-()]*\d){8,10}(?!\d)');
final _longDigits = RegExp(r'(?:\d[\s.\-()]*){9,}');
final _email = RegExp(r'[^\s@]+@[^\s@]+\.[a-z]{2,}', caseSensitive: false);
final _link = RegExp(
  r'(https?:\/\/|www\.|\b(?:zalo\.me|fb\.com|facebook\.com|m\.me|t\.me)\b|\b[a-z0-9-]+\.(?:vn|com|me|net|org|io|link|ly)\b)',
  caseSensitive: false,
);
final _zalo = RegExp(r'\bzalo\b', caseSensitive: false);

/// The first contact detail in [text] (phone, e-mail, link or Zalo), or null.
/// The server's `findContactLeak` stays the authority; the shared table in
/// test/core/contact_filter_test.dart keeps the two in step.
ContactLeak? findContactLeak(String text) {
  final t = text.replaceAll(_money, ' ');
  if (_email.hasMatch(t)) return ContactLeak.email;
  if (_link.hasMatch(t)) return ContactLeak.link;
  if (_phone.hasMatch(t) || _longDigits.hasMatch(t)) return ContactLeak.phone;
  if (_zalo.hasMatch(t)) return ContactLeak.zalo;
  return null;
}
