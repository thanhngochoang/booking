const _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

// Decomposed (NFD) input carries accents as separate combining marks.
final RegExp _combiningMarks = RegExp('[\u0300-\u036F]');

final Map<String, String> _fold = {
  for (final e in _groups.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// Lower-case, with Vietnamese accents removed: "Thủ Đức" -> "thu duc". Use
/// it on both sides of a search so "quan 1" finds "Quận 1".
String foldVietnamese(String s) => s
    .toLowerCase()
    .replaceAll(_combiningMarks, '')
    .split('')
    .map((c) => _fold[c] ?? c)
    .join();
