import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

/// Same rows as packages/domain/test/contact_filter.test.ts: the client and
/// the server filter must agree on every one.
const _table = <(String, ContactLeak?)>[
  ('0903 123 456', ContactLeak.phone),
  ('+84 903.123.456', ContactLeak.phone),
  ('84912345678', ContactLeak.phone),
  ('0 9 0 3 1 2 3 4 5 6', ContactLeak.phone),
  ('liên hệ a@b.vn', ContactLeak.email),
  ('xem www.abc.com', ContactLeak.link),
  ('fb.com/abc', ContactLeak.link),
  ('studio.vn', ContactLeak.link),
  ('zalo.me/0912345678', ContactLeak.link),
  ('nhắn Zalo nhé', ContactLeak.zalo),
  ('42 bạn, 12A1, 2025', null),
  ('giá 3.000.000đ', null),
  ('ngân sách 1.000.000.000₫', null),
  ('từ 7:00 đến 11:00', null),
  ('70-200mm f2.8', null),
  ('Kỷ yếu lớp 12A1, 42 bạn', null),
];

void main() {
  group('findContactLeak matches the server table', () {
    for (final (text, want) in _table) {
      test('"$text" -> $want', () => expect(findContactLeak(text), want));
    }
  });

  test('words the server allows pass', () {
    expect(findContactLeak('Chỉnh ảnh chuẩn đăng Facebook'), isNull);
    expect(findContactLeak('Gửi ảnh qua WhatsApp hoặc Telegram'), isNull);
    expect(findContactLeak('Phối đồ kiểu Zalora'), isNull);
    expect(findContactLeak('Gói @ studio'), isNull);
  });
}
