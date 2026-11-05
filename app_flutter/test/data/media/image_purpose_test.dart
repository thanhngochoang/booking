import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_purpose.dart';

void main() {
  test('share fits under the posts limit', () {
    // posts/ holds both portfolio and share images; its limit is the larger.
    expect(
      ImagePurpose.share.maxBytes,
      lessThanOrEqualTo(ImagePurpose.portfolio.maxBytes),
    );
  });
}
