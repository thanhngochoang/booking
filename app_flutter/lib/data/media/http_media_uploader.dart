import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/media/upload_flow.dart';

Duration _defaultPollDelay(int attempt) => attempt == 0
    ? const Duration(milliseconds: 500)
    : attempt == 1
    ? const Duration(seconds: 1)
    : const Duration(seconds: 2);

class HttpMediaUploader implements MediaUploader {
  HttpMediaUploader({
    required this.api,
    required this.compressor,
    this.uploadClient,
    Duration Function(int attempt)? pollDelay,
    this.timeout = const Duration(seconds: 30),
  }) : pollDelay = pollDelay ?? _defaultPollDelay;

  final ApiClient api;
  final ImageCompressor compressor;
  final http.Client? uploadClient;
  final Duration Function(int attempt) pollDelay;
  final Duration timeout;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  }) {
    var uploadCancelled = false;

    return uploadCompressed(
      compressor: compressor,
      image: image,
      purpose: purpose,
      storagePath: storagePath,
      put: (localPath, meta, onProgress) async {
        final file = File(localPath);
        final fileLength = await file.length();

        final createRes = await api.post(
          ApiPaths.files,
          {
            'purpose': purpose.code,
            'contentType': 'image/jpeg',
            'size': fileLength,
          },
          idempotencyKey: newUlid(),
        );

        final createMap = (createRes as Map).cast<String, dynamic>();
        final fileId = createMap['fileId'] as String;
        final upload = (createMap['upload'] as Map).cast<String, dynamic>();
        final uploadUrl = upload['url'] as String;
        final uploadFields = (upload['fields'] as Map).cast<String, dynamic>();

        final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        for (final entry in uploadFields.entries) {
          request.fields[entry.key] = entry.value.toString();
        }

        var sent = 0;
        var last = 0.0;
        final countedStream = file.openRead().map((chunk) {
          sent += chunk.length;
          if (fileLength > 0) {
            final fraction = sent / fileLength;
            if (fraction - last >= 0.05 && fraction < 1) {
              last = fraction;
              onProgress(fraction);
            }
          }
          return chunk;
        });

        request.files.add(
          http.MultipartFile(
            'file',
            countedStream,
            fileLength,
            filename: 'image.jpg',
          ),
        );

        final client = uploadClient ?? http.Client();
        final http.StreamedResponse streamed;
        try {
          streamed = await client.send(request);
        } finally {
          if (uploadClient == null) {
            client.close();
          }
        }

        final statusCode = streamed.statusCode;
        if (statusCode != 200 && statusCode != 201 && statusCode != 204) {
          throw StateError('upload rejected by store: $statusCode');
        }

        if (uploadCancelled) {
          throw StateError('upload cancelled');
        }

        await api.post(ApiPaths.fileComplete(fileId), const {});

        final stopwatch = Stopwatch()..start();
        var attempt = 0;
        while (stopwatch.elapsed < timeout) {
          if (uploadCancelled) {
            throw StateError('upload cancelled');
          }

          final res = await api.get(ApiPaths.file(fileId));
          final resMap = (res as Map).cast<String, dynamic>();
          final status = resMap['status'] as String;
          if (status == 'ready') {
            return UploadPutResult(
              url: resMap['url'] as String,
              storagePath: fileId,
              fileId: fileId,
            );
          }
          if (status == 'failed') {
            throw StateError('upload failed: ${resMap['failure']}');
          }

          final delay = pollDelay(attempt++);
          if (stopwatch.elapsed + delay >= timeout) {
            throw TimeoutException(
              'upload processing timed out after $timeout',
            );
          }
          await Future<void>.delayed(delay);
        }

        throw TimeoutException('upload processing timed out after $timeout');
      },
      deleteLocal: (path) async {
        final f = File(path);
        if (f.existsSync()) {
          await f.delete();
        }
      },
      onCancelUpload: () {
        uploadCancelled = true;
      },
    );
  }

  @override
  Future<void> delete(String storagePath) async {
    try {
      await api.delete(ApiPaths.file(storagePath));
    } on ApiException catch (e) {
      if (e.code == 'not_found' || e.statusCode == 404) return;
      rethrow;
    }
  }
}
