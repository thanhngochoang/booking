
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/jpeg_tools.dart';

/// A temporary JPEG made for one upload purpose; the caller deletes [path].
@immutable
class CompressedImage {
  const CompressedImage({
    required this.path,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final String path;
  final int width;
  final int height;
  final int sizeBytes;
}

enum ImageCompressError {
  /// The file is not an image the decoder can read.
  unreadable,

  /// Still above the purpose's byte limit after the last quality step.
  tooLarge,
}

class ImageCompressException implements Exception {
  const ImageCompressException(this.code);

  final ImageCompressError code;

  @override
  String toString() => 'ImageCompressException($code)';
}

abstract class ImageCompressor {
  /// Resizes and re-encodes [source] for [purpose] into a new temporary JPEG
  /// without metadata. The caller deletes [CompressedImage.path] when done.
  Future<CompressedImage> compress(PickedImage source, ImagePurpose purpose);
}

/// Encoder seam: [bound] is passed as both minWidth and minHeight.
typedef JpegEncoder = Future<Uint8List> Function(
  String path, {
  required int bound,
  required int quality,
});

const _maxEncodes = 4;
const _minQuality = 60;
const _qualityStep = 8;

/// Encodes [path] (of [width] x [height]) for [purpose]: encode, strip the
/// metadata, read the size back. If the long side is more than 2% over
/// [ImagePurpose.longSide] the bound shrinks proportionally and it retries; if
/// the bytes exceed [ImagePurpose.maxBytes] the quality drops by 8 (floor 60)
/// and it retries. At most 4 encodes, then `tooLarge`. Unreadable output is
/// `unreadable`.
Future<({Uint8List bytes, int width, int height})> encodeForPurpose(
  String path, {
  required int width,
  required int height,
  required ImagePurpose purpose,
  required JpegEncoder encode,
}) async {
  var bound = encoderBound(
    width: width,
    height: height,
    longSide: purpose.longSide,
  );
  var quality = purpose.quality;
  for (var attempt = 0; attempt < _maxEncodes; attempt++) {
    final raw = await encode(path, bound: bound, quality: quality);
    final Uint8List bytes;
    try {
      bytes = stripJpegMetadata(raw);
    } on FormatException {
      throw const ImageCompressException(ImageCompressError.unreadable);
    }
    final size = jpegSize(bytes);
    if (size == null) {
      throw const ImageCompressException(ImageCompressError.unreadable);
    }
    final long = size.width > size.height ? size.width : size.height;
    if (long * 100 > purpose.longSide * 102) {
      bound = (bound * purpose.longSide / long).floor();
      continue;
    }
    if (bytes.length > purpose.maxBytes) {
      quality = quality - _qualityStep < _minQuality
          ? _minQuality
          : quality - _qualityStep;
      continue;
    }
    return (bytes: bytes, width: size.width, height: size.height);
  }
  throw const ImageCompressException(ImageCompressError.tooLarge);
}

/// For tests: records its calls and answers with the source file at a fixed
/// size, or fails with [failWith].
class FakeImageCompressor implements ImageCompressor {
  final List<(String, ImagePurpose)> calls = [];
  ImageCompressError? failWith;

  @override
  Future<CompressedImage> compress(
    PickedImage source,
    ImagePurpose purpose,
  ) async {
    calls.add((source.path, purpose));
    final error = failWith;
    if (error != null) throw ImageCompressException(error);
    return CompressedImage(
      path: source.path,
      width: 1000,
      height: 750,
      sizeBytes: source.sizeBytes ?? 0,
    );
  }
}
