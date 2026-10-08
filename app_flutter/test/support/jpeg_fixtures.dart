import 'dart:convert';
import 'dart:typed_data';

/// Marker the scan data of [jpegWith] starts with (SOS) and ends before (EOI).
const _sos = 0xDA;

List<int> _segment(int marker, List<int> payload) {
  final len = payload.length + 2;
  return [0xFF, marker, len >> 8, len & 0xFF, ...payload];
}

/// A JPEG built segment by segment, no pixels: SOI, the chosen segments, DQT,
/// SOF0/SOF2 with the given size, DHT, SOS, a few entropy bytes (with `FF 00`
/// stuffing and an `FF D0` restart marker) and EOI. The Exif payload contains
/// the ASCII `GPSLatitude` so a test can search for it.
Uint8List jpegWith({
  bool app0 = true,
  bool exif = false,
  bool xmp = false,
  bool icc = false,
  bool flashPixApp2 = false,
  bool comment = false,
  bool app13 = false,
  int width = 1600,
  int height = 1200,
  bool progressive = false,
}) {
  final out = <int>[0xFF, 0xD8];
  if (app0) {
    out.addAll(
      _segment(0xE0, [...ascii.encode('JFIF'), 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]),
    );
  }
  if (exif) {
    out.addAll(
      _segment(0xE1, [
        ...ascii.encode('Exif'),
        0,
        0,
        ...ascii.encode('MM'),
        ...ascii.encode('GPSLatitude'),
        0x10,
        0x20,
      ]),
    );
  }
  if (xmp) {
    out.addAll(
      _segment(0xE1, [
        ...ascii.encode('http://ns.adobe.com/xap/1.0/'),
        0,
        ...ascii.encode('<x:xmpmeta/>'),
      ]),
    );
  }
  if (icc) {
    out.addAll(
      _segment(0xE2, [
        ...ascii.encode('ICC_PROFILE'),
        0,
        1,
        1,
        ...List<int>.generate(24, (i) => i),
      ]),
    );
  }
  if (flashPixApp2) {
    out.addAll(_segment(0xE2, [...ascii.encode('FPXR'), 0, 1, 2, 3]));
  }
  if (app13) {
    out.addAll(_segment(0xED, [...ascii.encode('Photoshop 3.0'), 0, 8, 9]));
  }
  if (comment) {
    out.addAll(_segment(0xFE, ascii.encode('made by a test')));
  }
  out.addAll(_segment(0xDB, [0, ...List<int>.filled(64, 16)]));
  out.addAll(
    _segment(progressive ? 0xC2 : 0xC0, [
      8,
      height >> 8,
      height & 0xFF,
      width >> 8,
      width & 0xFF,
      1,
      1,
      0x11,
      0,
    ]),
  );
  out.addAll(_segment(0xC4, [0, ...List<int>.filled(16, 0), 0]));
  out.addAll(_segment(_sos, [1, 1, 0, 0, 63, 0]));
  out.addAll([0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD0, 0x56, 0xFF, 0x00, 0x78]);
  out.addAll([0xFF, 0xD9]);
  return Uint8List.fromList(out);
}

/// Index of the SOS marker in [bytes] (for comparing scan data).
int sosOffset(Uint8List bytes) {
  for (var i = 2; i + 1 < bytes.length;) {
    if (bytes[i] != 0xFF) throw StateError('not at a marker');
    if (bytes[i + 1] == _sos) return i;
    i += 2 + ((bytes[i + 2] << 8) | bytes[i + 3]);
  }
  throw StateError('no SOS');
}

/// True if [bytes] contains the ASCII [text].
bool containsAscii(Uint8List bytes, String text) =>
    latin1.decode(bytes, allowInvalid: true).contains(text);
