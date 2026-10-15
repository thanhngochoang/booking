import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

void main() {
  test('supportEmail is null when SUPPORT_EMAIL is empty; '
      'supportEmailUri builds mailto', () {
    // Tests run without --dart-define=SUPPORT_EMAIL (owner question).
    expect(supportEmail, isNull);
    expect(supportEmailUri(), isNull);
    expect(supportEmailUri(null), isNull);
    expect(supportEmailUri('a@b.vn'), Uri(scheme: 'mailto', path: 'a@b.vn'));
    expect(supportEmailUri('a@b.vn').toString(), 'mailto:a@b.vn');
  });
}
