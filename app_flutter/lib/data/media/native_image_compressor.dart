import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';

/// The phone's own encoder (`flutter_image_compress`: Android bitmap, iOS
/// UIKit). The only file that imports the plugin. It needs a platform, so it is
/// not unit tested: the fit loop is `encodeForPurpose`, the metadata removal is
/// `stripJpegMetadata` (both pure and tested).
class NativeImageCompressor implements ImageCompressor {
  @override
  Future<CompressedImage> compress(
    PickedImage source,
    ImagePurpose purpose,
  ) async {
    final (width, height) = await _readSize(source.path);
    final encoded = await encodeForPurpose(
      source.path,
      width: width,
      height: height,
      purpose: purpose,
      encode: _encode,
    );
    final file = File('${Directory.systemTemp.path}/upload_${newUlid()}.jpg');
    try {
      await file.writeAsBytes(encoded.bytes, flush: true);
    } on Object {
      if (file.existsSync()) {
        await file.delete();
      }
      rethrow;
    }
    return CompressedImage(
      path: file.path,
      width: encoded.width,
      height: encoded.height,
      sizeBytes: encoded.bytes.length,
    );
  }

  /// Header-only size read; the pixels are not decoded.
  Future<(int, int)> _readSize(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } on Object {
      throw const ImageCompressException(ImageCompressError.unreadable);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// `bound` is both minWidth and minHeight: the plugin scales by
  /// `max(1, min(w / minWidth, h / minHeight))` (Android `calcScale`; iOS
  /// `scaleWithMinWidth`), which puts the short side at `bound` and never
  /// upscales. EXIF is not kept and the orientation is baked into the pixels.
  Future<Uint8List> _encode(
    String path, {
    required int bound,
    required int quality,
  }) async {
    final Uint8List? bytes;
    try {
      bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: bound,
        minHeight: bound,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
    } on Object {
      throw const ImageCompressException(ImageCompressError.unreadable);
    }
    if (bytes == null) {
      throw const ImageCompressException(ImageCompressError.unreadable);
    }
    return bytes;
  }
}
