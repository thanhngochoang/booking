import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

void main() {
  const a = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg', sizeBytes: 1200);
  const b = PickedImage(path: '/tmp/b.jpg', name: 'b.jpg');

  test(
    'the fake answers in order and records how many were asked for',
    () async {
      final picker = FakeImagePicker([
        [a, b],
        [],
      ]);
      expect(await picker.pickImages(max: 10), [a, b]);
      expect(await picker.pickImages(max: 8), isEmpty, reason: 'cancelled');
      expect(
        await picker.pickImages(max: 3),
        isEmpty,
        reason: 'nothing queued',
      );
      expect(picker.calls, 3);
      expect(picker.requestedMax, [10, 8, 3]);
    },
  );

  test('the fake never returns more than were asked for', () async {
    final picker = FakeImagePicker([
      [a, b, a],
    ]);
    expect(await picker.pickImages(max: 2), hasLength(2));
  });
}
