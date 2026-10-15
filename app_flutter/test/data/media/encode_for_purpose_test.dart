import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/jpeg_tools.dart';

import '../../support/jpeg_fixtures.dart';

typedef _Call = ({int bound, int quality});

/// A fake encoder: [answer] picks the bytes for each call (1-based index).
class _Encoder {
  _Encoder(this.answer);
  final Uint8List Function(int n, int bound, int quality) answer;
  final List<_Call> calls = [];

  Future<Uint8List> call(
    String path, {
    required int bound,
    required int quality,
  }) async {
    calls.add((bound: bound, quality: quality));
    return answer(calls.length, bound, quality);
  }
}

/// A fixture padded to [size] bytes (a COM-free padding inside the scan data).
Uint8List _sized(
  int size, {
  int width = 2048,
  int height = 1536,
  bool exif = false,
}) {
  final base = jpegWith(width: width, height: height, exif: exif);
  if (base.length >= size) return base;
  final padded = BytesBuilder()
    ..add(base.sublist(0, base.length - 2))
    ..add(Uint8List(size - base.length))
    ..add(const [0xFF, 0xD9]);
  return padded.toBytes();
}

Future<({Uint8List bytes, int width, int height})> _run(
  _Encoder e, {
  int width = 4000,
  int height = 3000,
  ImagePurpose purpose = ImagePurpose.portfolio,
}) => encodeForPurpose(
  '/p.jpg',
  width: width,
  height: height,
  purpose: purpose,
  encode: e.call,
);

void main() {
  const max = 3 * 1024 * 1024;

  test('one encode when size and bytes fit', () async {
    final e = _Encoder((n, b, q) => _sized(100 * 1024));
    final r = await _run(e);
    expect(e.calls, [(bound: 1536, quality: 82)]);
    expect((r.width, r.height), (2048, 1536));
  });

  test(
    'the result never carries Exif even when the encoder keeps it',
    () async {
      final e = _Encoder((n, b, q) => _sized(100 * 1024, exif: true));
      final r = await _run(e);
      expect(containsAscii(r.bytes, 'GPSLatitude'), isFalse);
      expect(jpegHasMetadata(r.bytes), isFalse);
    },
  );

  test('lowers quality until the bytes fit', () async {
    final e = _Encoder((n, b, q) => _sized(n <= 2 ? max + 1000 : 200 * 1024));
    await _run(e);
    expect(e.calls.map((c) => c.quality), [82, 74, 66]);
  });

  test(
    'quality never goes below 60 and gives up with tooLarge after 4 encodes',
    () async {
      final e = _Encoder((n, b, q) => _sized(max + 1000));
      await expectLater(
        _run(e),
        throwsA(
          isA<ImageCompressException>().having(
            (x) => x.code,
            'code',
            ImageCompressError.tooLarge,
          ),
        ),
      );
      expect(e.calls.map((c) => c.quality), [82, 74, 66, 60]);
    },
  );

  test('quality floors at 60 for a low-quality purpose', () async {
    final e = _Encoder(
      (n, b, q) => _sized(2 * 1024 * 1024 + 1000, width: 1600, height: 1200),
    );
    await expectLater(
      _run(e, purpose: ImagePurpose.deliverySample),
      throwsA(isA<ImageCompressException>()),
    );
    expect(e.calls.map((c) => c.quality), [75, 67, 60, 60]);
  });

  test('retries with a smaller bound when the encoder overshoots', () async {
    final e = _Encoder(
      (n, b, q) => n == 1
          ? _sized(100 * 1024, width: 2400, height: 1800)
          : _sized(100 * 1024),
    );
    final r = await _run(e);
    expect(e.calls.length, 2);
    expect(e.calls[1].bound, (1536 * 2048 / 2400).floor());
    expect(e.calls[1].quality, 82);
    expect(r.width, 2048);
  });

  test('a long side within 2% over is accepted', () async {
    final e = _Encoder(
      (n, b, q) => _sized(100 * 1024, width: 2080, height: 1560),
    );
    await _run(e);
    expect(e.calls.length, 1);
  });

  test(
    'encoderBound is symmetric, so rotation does not change the long side',
    () async {
      final portrait = _Encoder(
        (n, b, q) => _sized(1000, width: 1536, height: 2048),
      );
      final landscape = _Encoder((n, b, q) => _sized(1000));
      await _run(portrait, width: 3000, height: 4000);
      await _run(landscape, width: 4000, height: 3000);
      expect(portrait.calls.single.bound, landscape.calls.single.bound);
    },
  );

  test('unreadable output is reported as unreadable', () async {
    final e = _Encoder((n, b, q) => Uint8List.fromList([1, 2, 3, 4, 5]));
    await expectLater(
      _run(e),
      throwsA(
        isA<ImageCompressException>().having(
          (x) => x.code,
          'code',
          ImageCompressError.unreadable,
        ),
      ),
    );
  });

  test('purposes match the issue table', () {
    String row(ImagePurpose p) =>
        '${p.code} ${p.longSide} ${p.quality} ${p.maxBytes} ${p.cacheControl}';
    expect(ImagePurpose.values.map(row), [
      'avatar 512 80 524288 public, max-age=31536000',
      'chat 1280 75 1572864 private, max-age=31536000',
      'share 1600 80 2097152 public, max-age=31536000',
      'delivery_sample 1600 75 2097152 private, max-age=31536000',
      'portfolio 2048 82 3145728 public, max-age=31536000',
      'document 2048 85 3145728 private, max-age=31536000',
    ]);
  });

  test(
    'FakeImageCompressor records calls and can fail with unreadable',
    () async {
      final fake = FakeImageCompressor();
      const img = PickedImage(path: '/a.jpg', name: 'a.jpg', sizeBytes: 10);
      final c = await fake.compress(img, ImagePurpose.chat);
      expect(fake.calls, [('/a.jpg', ImagePurpose.chat)]);
      expect((c.path, c.width, c.height), ('/a.jpg', 1000, 750));
      fake.failWith = ImageCompressError.unreadable;
      await expectLater(
        fake.compress(img, ImagePurpose.chat),
        throwsA(
          isA<ImageCompressException>().having(
            (x) => x.code,
            'code',
            ImageCompressError.unreadable,
          ),
        ),
      );
    },
  );
}
