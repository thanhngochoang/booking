import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/media/jpeg_tools.dart';

import '../../support/jpeg_fixtures.dart';

void main() {
  group('stripJpegMetadata', () {
    test('strips Exif/XMP but keeps JFIF and ICC', () {
      final src = jpegWith(exif: true, xmp: true, icc: true);
      final out = stripJpegMetadata(src);
      expect(containsAscii(out, 'GPSLatitude'), isFalse);
      expect(containsAscii(out, 'http://ns.adobe.com/xap/'), isFalse);
      expect(containsAscii(out, 'ICC_PROFILE'), isTrue);
      expect(containsAscii(out, 'JFIF'), isTrue);
      expect(out.length, lessThan(src.length));
    });

    test('drops COM, APP13 and a non-ICC APP2', () {
      final out = stripJpegMetadata(
        jpegWith(comment: true, app13: true, flashPixApp2: true, icc: true),
      );
      expect(containsAscii(out, 'made by a test'), isFalse);
      expect(containsAscii(out, 'Photoshop'), isFalse);
      expect(containsAscii(out, 'FPXR'), isFalse);
      expect(containsAscii(out, 'ICC_PROFILE'), isTrue);
    });

    test('keeps the scan data byte for byte', () {
      final src = jpegWith(exif: true, xmp: true, comment: true);
      final out = stripJpegMetadata(src);
      expect(
        out.sublist(sosOffset(out)),
        orderedEquals(src.sublist(sosOffset(src))),
      );
      expect(jpegSize(out), (width: 1600, height: 1200));
    });

    test('returns the same instance when there is nothing to strip', () {
      final src = jpegWith(icc: true);
      expect(identical(stripJpegMetadata(src), src), isTrue);
    });

    test('throws FormatException for a PNG or truncated data', () {
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
      ]);
      expect(() => stripJpegMetadata(png), throwsFormatException);
      final src = jpegWith(exif: true);
      expect(
        () => stripJpegMetadata(Uint8List.sublistView(src, 0, 20)),
        throwsFormatException,
      );
      expect(() => stripJpegMetadata(Uint8List(0)), throwsFormatException);
    });
  });

  test('jpegHasMetadata is true before and false after stripping', () {
    final src = jpegWith(exif: true, icc: true);
    expect(jpegHasMetadata(src), isTrue);
    expect(jpegHasMetadata(stripJpegMetadata(src)), isFalse);
    expect(jpegHasMetadata(jpegWith()), isFalse);
  });

  group('jpegSize', () {
    test('reads SOF0 and SOF2, skips DHT', () {
      expect(jpegSize(jpegWith(width: 4032, height: 3024)), (
        width: 4032,
        height: 3024,
      ));
      expect(jpegSize(jpegWith(width: 640, height: 480, progressive: true)), (
        width: 640,
        height: 480,
      ));
    });

    test('is null without a frame header', () {
      final src = jpegWith();
      final sof = src.indexOfSof();
      // Cut the file right before the SOF segment: SOS comes first, no frame.
      final cut = Uint8List.fromList([
        ...src.sublist(0, sof),
        0xFF,
        0xDA,
        0,
        2,
      ]);
      expect(jpegSize(cut), isNull);
      expect(jpegSize(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });
  });

  test('encoderBound', () {
    expect(encoderBound(width: 4000, height: 3000, longSide: 2048), 1536);
    expect(encoderBound(width: 3000, height: 4000, longSide: 2048), 1536);
    expect(encoderBound(width: 1200, height: 900, longSide: 2048), 900);
    expect(encoderBound(width: 3000, height: 3000, longSide: 2048), 2048);
  });
}

extension on Uint8List {
  int indexOfSof() {
    for (var i = 2; i + 1 < length;) {
      if (this[i + 1] == 0xC0 || this[i + 1] == 0xC2) return i;
      i += 2 + ((this[i + 2] << 8) | this[i + 3]);
    }
    throw StateError('no SOF');
  }
}
