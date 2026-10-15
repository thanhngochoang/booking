import 'dart:typed_data';

/// Drops APP1 (Exif, XMP), APP3–APP15, COM, and APP2 unless it starts with
/// "ICC_PROFILE\0", in every part of the file: before the first scan, between
/// the scans of a progressive/multi-scan JPEG, and everything after EOI
/// (secondary images, vendor trailers). Entropy-coded data is copied untouched.
/// Returns [bytes] itself when nothing was dropped. Throws [FormatException]
/// if the data is not a complete, well-formed JPEG (SOI to EOI).
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    throw const FormatException('not a JPEG');
  }
  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var i = 2;
  var dropped = false;
  while (i + 2 <= bytes.length) {
    if (bytes[i] != 0xFF) throw const FormatException('bad marker');
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    if (marker == 0xD9) {
      // EOI: the file ends here, whatever follows is dropped.
      if (i + 2 < bytes.length) dropped = true;
      if (!dropped) return bytes;
      out.add(const [0xFF, 0xD9]);
      return out.toBytes();
    }
    if (marker == 0x00 || marker == 0xD8) {
      throw const FormatException('bad marker');
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      // Standalone markers (TEM, RSTn) carry no length.
      out.add(Uint8List.sublistView(bytes, i, i + 2));
      i += 2;
      continue;
    }
    if (i + 4 > bytes.length) throw const FormatException('truncated');
    final len = (bytes[i + 2] << 8) | bytes[i + 3];
    final end = i + 2 + len;
    if (len < 2 || end > bytes.length) {
      throw const FormatException('bad length');
    }
    if (marker == 0xDA) {
      // SOS: keep the header, then the entropy-coded data up to the next real
      // marker (FF00 stuffing, RSTn and FF fill bytes belong to the data).
      var j = end;
      while (j < bytes.length) {
        if (bytes[j] != 0xFF) {
          j++;
          continue;
        }
        if (j + 1 >= bytes.length) throw const FormatException('truncated');
        final next = bytes[j + 1];
        if (next == 0x00 || (next >= 0xD0 && next <= 0xD7)) {
          j += 2;
        } else if (next == 0xFF) {
          j++;
        } else {
          break;
        }
      }
      if (j >= bytes.length) throw const FormatException('no EOI');
      out.add(Uint8List.sublistView(bytes, i, j));
      i = j;
      continue;
    }
    final isIcc = marker == 0xE2 && _ascii(bytes, i + 4, 'ICC_PROFILE\u0000');
    final drop =
        marker == 0xE1 ||
        (marker >= 0xE3 && marker <= 0xEF) ||
        marker == 0xFE ||
        (marker == 0xE2 && !isIcc);
    if (drop) {
      dropped = true;
    } else {
      out.add(Uint8List.sublistView(bytes, i, end));
    }
    i = end;
  }
  throw const FormatException('no EOI');
}

/// True if any segment [stripJpegMetadata] would drop is present (including
/// data after EOI). Throws [FormatException] on input that is not a complete
/// JPEG, like [stripJpegMetadata].
bool jpegHasMetadata(Uint8List bytes) =>
    !identical(stripJpegMetadata(bytes), bytes);

/// Width/height from the first SOFn marker (C0–CF except C4, C8, CC); null if
/// there is none before the scan data (or the data is not a JPEG).
({int width, int height})? jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xFF) return null;
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xDA || marker == 0xD9) return null;
    final len = (bytes[i + 2] << 8) | bytes[i + 3];
    if (len < 2) return null;
    final isSof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      // length(2) precision(1) height(2) width(2)
      if (i + 9 > bytes.length) return null;
      final height = (bytes[i + 5] << 8) | bytes[i + 6];
      final width = (bytes[i + 7] << 8) | bytes[i + 8];
      return (width: width, height: height);
    }
    i += 2 + len;
  }
  return null;
}

/// The value passed to the encoder as both minWidth and minHeight so the long
/// side comes out as [longSide] whatever the rotation: the short side scaled by
/// the same ratio. Never upscales (a photo already within [longSide] keeps its
/// short side, which makes the encoder's scale 1).
int encoderBound({
  required int width,
  required int height,
  required int longSide,
}) {
  final long = width > height ? width : height;
  final short = width > height ? height : width;
  if (long <= longSide) return short < 1 ? 1 : short;
  final bound = (short * longSide / long).round();
  return bound < 1 ? 1 : bound;
}

bool _ascii(Uint8List bytes, int at, String text) {
  if (at + text.length > bytes.length) return false;
  for (var k = 0; k < text.length; k++) {
    if (bytes[at + k] != text.codeUnitAt(k)) return false;
  }
  return true;
}
