import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

void main() {
  test('codes match the data model', () {
    expect(
      {for (final c in ContactChannel.values) c.code},
      {'in_app', 'call', 'zalo', 'whatsapp'},
    );
    expect(ContactChannel.fromCode('zalo'), ContactChannel.zalo);
    expect(ContactChannel.fromCode('sms'), isNull);
    expect(ContactChannel.fromCode(null), isNull);
  });

  test('only the in-app channel is not external', () {
    expect(ContactChannel.inApp.isExternal, isFalse);
    for (final c in [
      ContactChannel.call,
      ContactChannel.zalo,
      ContactChannel.whatsapp,
    ]) {
      expect(c.isExternal, isTrue);
    }
  });
}
