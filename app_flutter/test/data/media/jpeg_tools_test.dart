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

  group('stripJpegMetadata across scans and trailers', () {
    test('drops an Exif APP1 between the scans of a two-scan JPEG', () {
      final src = jpegWith(
        progressive: true,
        secondScan: true,
        exifBetweenScans: true,
        icc: true,
      );
      expect(containsAscii(src, 'GPSLatitude'), isTrue);
      final out = stripJpegMetadata(src);
      expect(containsAscii(out, 'GPSLatitude'), isFalse);
      expect(containsAscii(out, 'ICC_PROFILE'), isTrue);
      expect(jpegHasMetadata(out), isFalse);
      // Both scans survive byte for byte.
      final clean = jpegWith(progressive: true, secondScan: true, icc: true);
      expect(out, orderedEquals(clean));
    });

    test('output ends at EOI when bytes follow it', () {
      final src = jpegWith(
        icc: true,
        trailer: [0xFF, 0xD8, ...exifSegment(), 0x00, 0x01],
      );
      expect(jpegHasMetadata(src), isTrue);
      final out = stripJpegMetadata(src);
      expect(out.sublist(out.length - 2), [0xFF, 0xD9]);
      expect(containsAscii(out, 'GPSLatitude'), isFalse);
      expect(out, orderedEquals(jpegWith(icc: true)));
    });

    test('trailing zero padding after EOI is dropped too', () {
      final out = stripJpegMetadata(jpegWith(trailer: [0, 0, 0]));
      expect(out, orderedEquals(jpegWith()));
    });

    test('single-scan and two-scan output is unchanged when nothing drops', () {
      final one = jpegWith(icc: true);
      final two = jpegWith(secondScan: true, progressive: true);
      expect(identical(stripJpegMetadata(one), one), isTrue);
      expect(identical(stripJpegMetadata(two), two), isTrue);
    });

    test(
      'FF00 stuffing, restart markers and FF fill bytes stay in the data',
      () {
        final src = jpegWith(exif: true);
        // Insert fill bytes (FF FF FF) before EOI.
        final eoi = src.length - 2;
        final padded = Uint8List.fromList([
          ...src.sublist(0, eoi),
          0xFF,
          0xFF,
          0xFF,
          0xD9,
        ]);
        final out = stripJpegMetadata(padded);
        expect(
          out.sublist(sosOffset(out)),
          orderedEquals(padded.sublist(sosOffset(padded))),
        );
      },
    );
  });

  group('malformed input', () {
    Uint8List soi(List<int> rest) => Uint8List.fromList([0xFF, 0xD8, ...rest]);

    test('segment length below 2', () {
      expect(
        () => stripJpegMetadata(soi([0xFF, 0xE1, 0x00, 0x01, 0xFF, 0xD9])),
        throwsFormatException,
      );
    });

    test('segment length past the end', () {
      expect(
        () => stripJpegMetadata(soi([0xFF, 0xE1, 0x7F, 0xFF, 1, 2, 3, 4])),
        throwsFormatException,
      );
    });

    test('a byte other than FF where a marker should be', () {
      expect(
        () => stripJpegMetadata(soi([0x12, 0x34, 0x56, 0x78, 0x9A])),
        throwsFormatException,
      );
    });

    test('a run of FF fill bytes is skipped and a long run terminates', () {
      final out = stripJpegMetadata(
        soi([
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xE0,
          0x00,
          0x02,
          0xFF,
          0xDA,
          0x00,
          0x02,
          1,
          2,
          0xFF,
          0xD9,
        ]),
      );
      expect(out.last, 0xD9);
      expect(
        () => stripJpegMetadata(soi(List<int>.filled(500, 0xFF))),
        throwsFormatException,
      );
    });

    test('truncated mid-segment, mid-scan and without EOI', () {
      final src = jpegWith(exif: true);
      for (final cut in [5, 7, 12, src.length - 10, src.length - 1]) {
        expect(
          () => stripJpegMetadata(Uint8List.sublistView(src, 0, cut)),
          throwsFormatException,
          reason: 'cut at $cut',
        );
      }
      expect(
        () => stripJpegMetadata(soi([0xFF, 0xDA, 0x00, 0x02, 1, 2, 0xFF])),
        throwsFormatException,
      );
    });

    test('jpegHasMetadata throws on non-JPEG input', () {
      expect(
        () => jpegHasMetadata(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsFormatException,
      );
    });

    test('jpegSize is null for a truncated SOF and for a bad length', () {
      final src = jpegWith();
      final sof = src.indexOfSof();
      expect(jpegSize(Uint8List.sublistView(src, 0, sof + 6)), isNull);
      expect(jpegSize(soi([0xFF, 0xE1, 0x00, 0x00, 1, 2, 3])), isNull);
      expect(jpegSize(soi(List<int>.filled(500, 0xFF))), isNull);
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
    expect(encoderBound(width: 10000, height: 1, longSide: 100), 1);
    expect(encoderBound(width: 0, height: 0, longSide: 100), 1);
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
