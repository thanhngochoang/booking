import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/media/http_media_uploader.dart';
import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import '../http/mock_api.dart';

const _picked = PickedImage(
  path: '/picked/a.jpg',
  name: 'a.jpg',
  sizeBytes: 4000000,
);

class _FakeCompressor implements ImageCompressor {
  ImageCompressError? failWith;
  final List<(String, ImagePurpose)> calls = [];
  File? tempFile;
  int tempFileBytes = 1000;

  @override
  Future<CompressedImage> compress(
    PickedImage source,
    ImagePurpose purpose,
  ) async {
    calls.add((source.path, purpose));
    final error = failWith;
    if (error != null) throw ImageCompressException(error);
    final dir = await Directory.systemTemp.createTemp('upload_test_');
    final f = File('${dir.path}/upload.jpg');
    await f.writeAsBytes(List.generate(tempFileBytes, (i) => i % 256));
    tempFile = f;
    return CompressedImage(
      path: f.path,
      width: 1600,
      height: 1067,
      sizeBytes: tempFileBytes,
    );
  }
}

class _UploadClientRecorder {
  int statusCode = 200;
  http.Request? capturedRequest;
  String? capturedBodyText;

  late final client = MockClient((request) async {
    capturedRequest = request;
    capturedBodyText = utf8.decode(request.bodyBytes, allowMalformed: true);
    return http.Response('', statusCode);
  });
}

void main() {
  late _FakeCompressor compressor;
  late _UploadClientRecorder uploadRecorder;
  late MockApi mockApi;

  setUp(() {
    compressor = _FakeCompressor();
    uploadRecorder = _UploadClientRecorder();
    mockApi = MockApi({
      'POST /v1/files': (req) => (
        201,
        {
          'fileId': 'file_123',
          'upload': {
            'url': 'http://store.test/upload',
            'fields': {'key': 'uploads/file_123.jpg', 'policy': 'test-policy'},
          },
        },
      ),
      'POST /v1/files/file_123/complete': (req) => (200, <String, Object?>{}),
      'GET /v1/files/file_123': (req) => (
        200,
        {
          'fileId': 'file_123',
          'status': 'ready',
          'url': 'https://cdn.test/ready.jpg',
        },
      ),
    });
  });

  HttpMediaUploader makeUploader({
    Duration Function(int attempt)? pollDelay,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpMediaUploader(
      api: mockApi.api(),
      compressor: compressor,
      uploadClient: uploadRecorder.client,
      pollDelay: pollDelay ?? (_) => Duration.zero,
      timeout: timeout,
    );
  }

  test(
    'upload creates the file, posts fields first and the file last, completes, polls and returns a ready UploadedMedia carrying the file id',
    () async {
      final uploader = makeUploader();
      final events = await uploader
          .upload(
            _picked,
            storagePath: 'ignored/path.jpg',
            purpose: ImagePurpose.portfolio,
          )
          .toList();

      expect(mockApi.calls, [
        'POST /v1/files',
        'POST /v1/files/file_123/complete',
        'GET /v1/files/file_123',
      ]);

      // Verify POST /v1/files request body and idempotency key
      final createReq = mockApi.requests.first;
      final createBody = jsonDecode(createReq.body) as Map<String, dynamic>;
      expect(createBody['purpose'], ImagePurpose.portfolio.code);
      expect(createBody['contentType'], 'image/jpeg');
      expect(createBody['size'], 1000);
      expect(createReq.headers['idempotency-key'], isNotNull);

      // Verify upload request: fields first, file part last
      final uploadBody = uploadRecorder.capturedBodyText!;
      final keyIdx = uploadBody.indexOf('name="key"');
      final policyIdx = uploadBody.indexOf('name="policy"');
      final fileIdx = uploadBody.indexOf('name="file"');
      expect(keyIdx, greaterThan(-1));
      expect(policyIdx, greaterThan(-1));
      expect(fileIdx, greaterThan(-1));
      expect(keyIdx, lessThan(fileIdx));
      expect(policyIdx, lessThan(fileIdx));

      // Verify done event
      final done = events.last.media!;
      expect(done.url, 'https://cdn.test/ready.jpg');
      expect(done.storagePath, 'file_123');
      expect(done.fileId, 'file_123');
      expect(done.width, 1600);
      expect(done.height, 1067);
      expect(done.sizeBytes, 1000);
    },
  );

  test(
    'storagePath argument is ignored and storagePath of the result is the file id',
    () async {
      final uploader = makeUploader();
      final events = await uploader
          .upload(
            _picked,
            storagePath: 'custom/ignored/path.jpg',
            purpose: ImagePurpose.portfolio,
          )
          .toList();

      final done = events.last.media!;
      expect(done.storagePath, 'file_123');
      expect(done.fileId, 'file_123');
      expect(done.storagePath, isNot(contains('custom/ignored/path.jpg')));
    },
  );

  test('progress events are emitted at most once per 5 percent', () async {
    // 20,000 bytes temp file
    compressor.tempFileBytes = 20000;
    final uploader = makeUploader();
    final events = await uploader
        .upload(
          _picked,
          storagePath: 'ignored.jpg',
          purpose: ImagePurpose.portfolio,
        )
        .toList();

    final progressFractions = events
        .where((e) => !e.isDone)
        .map((e) => e.fraction)
        .toList();

    for (var i = 1; i < progressFractions.length; i++) {
      expect(
        progressFractions[i] - progressFractions[i - 1],
        greaterThanOrEqualTo(0.049), // allow slight float rounding
      );
    }
    for (final f in progressFractions) {
      expect(f, lessThan(1.0));
    }
    expect(events.last.isDone, isTrue);
  });

  test('compress error surfaces and nothing is requested', () async {
    compressor.failWith = ImageCompressError.unreadable;
    final uploader = makeUploader();

    await expectLater(
      uploader.upload(
        _picked,
        storagePath: 'ignored.jpg',
        purpose: ImagePurpose.portfolio,
      ),
      emitsError(
        isA<ImageCompressException>().having(
          (e) => e.code,
          'code',
          ImageCompressError.unreadable,
        ),
      ),
    );

    expect(mockApi.calls, isEmpty);
    expect(uploadRecorder.capturedRequest, isNull);
  });

  test(
    'a store rejection (403) surfaces as a stream error and complete is not called',
    () async {
      uploadRecorder.statusCode = 403;
      final uploader = makeUploader();

      await expectLater(
        uploader.upload(
          _picked,
          storagePath: 'ignored.jpg',
          purpose: ImagePurpose.portfolio,
        ),
        emitsError(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('403'),
          ),
        ),
      );

      expect(mockApi.calls, ['POST /v1/files']);
      expect(mockApi.calls.where((c) => c.contains('complete')), isEmpty);
    },
  );

  test('failed status surfaces the failure code', () async {
    mockApi.routes['GET /v1/files/file_123'] = (req) => (
      200,
      {
        'fileId': 'file_123',
        'status': 'failed',
        'failure': 'corrupt_jpeg',
      },
    );
    final uploader = makeUploader();

    await expectLater(
      uploader.upload(
        _picked,
        storagePath: 'ignored.jpg',
        purpose: ImagePurpose.portfolio,
      ),
      emitsError(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('upload failed: corrupt_jpeg'),
        ),
      ),
    );
  });

  test('polling gives up after the timeout (inject pollDelay)', () async {
    mockApi.routes['GET /v1/files/file_123'] = (req) => (
      200,
      {
        'fileId': 'file_123',
        'status': 'pending',
      },
    );
    final uploader = makeUploader(
      pollDelay: (_) => const Duration(milliseconds: 10),
      timeout: const Duration(milliseconds: 30),
    );

    await expectLater(
      uploader.upload(
        _picked,
        storagePath: 'ignored.jpg',
        purpose: ImagePurpose.portfolio,
      ),
      emitsError(isA<TimeoutException>()),
    );
  });

  group('the temporary file is deleted on success, failure and cancel', () {
    test('deleted on success', () async {
      final uploader = makeUploader();
      await uploader
          .upload(
            _picked,
            storagePath: 'ignored.jpg',
            purpose: ImagePurpose.portfolio,
          )
          .drain<void>();

      expect(compressor.tempFile, isNotNull);
      expect(compressor.tempFile!.existsSync(), isFalse);
    });

    test('deleted on failure', () async {
      uploadRecorder.statusCode = 403;
      final uploader = makeUploader();

      await expectLater(
        uploader
            .upload(
              _picked,
              storagePath: 'ignored.jpg',
              purpose: ImagePurpose.portfolio,
            )
            .drain<void>(),
        throwsA(isA<StateError>()),
      );

      expect(compressor.tempFile, isNotNull);
      expect(compressor.tempFile!.existsSync(), isFalse);
    });

    test('deleted on cancel', () async {
      mockApi.routes['POST /v1/files/file_123/complete'] = (req) {
        return (200, <String, Object?>{});
      };
      // Let GET be pending forever
      mockApi.routes['GET /v1/files/file_123'] = (req) {
        return (200, {'fileId': 'file_123', 'status': 'pending'});
      };

      final uploader = makeUploader(
        pollDelay: (_) => const Duration(seconds: 10),
      );
      final sub = uploader
          .upload(
            _picked,
            storagePath: 'ignored.jpg',
            purpose: ImagePurpose.portfolio,
          )
          .listen((_) {});

      // Wait until upload is in flight and temp file exists
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(compressor.tempFile, isNotNull);

      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(compressor.tempFile!.existsSync(), isFalse);
    });
  });

  test('delete sends DELETE and ignores not_found, rethrows conflict', () async {
    mockApi.routes['DELETE /v1/files/file_404'] = (req) =>
        (404, apiError('not_found'));
    mockApi.routes['DELETE /v1/files/file_409'] = (req) =>
        (409, apiError('conflict'));

    final uploader = makeUploader();

    // 404 is ignored
    await uploader.delete('file_404');
    expect(mockApi.calls, contains('DELETE /v1/files/file_404'));

    // 409 conflict is rethrown
    await expectLater(
      uploader.delete('file_409'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'conflict'),
      ),
    );
    expect(mockApi.calls, contains('DELETE /v1/files/file_409'));
  });

  test('UploadedMedia without fileId still constructs', () {
    const media = UploadedMedia(
      url: 'https://storage.test/photo.jpg',
      storagePath: 'posts/p1.jpg',
      width: 800,
      height: 600,
      sizeBytes: 50000,
    );
    expect(media.fileId, isNull);
    expect(media.url, 'https://storage.test/photo.jpg');
    expect(media.storagePath, 'posts/p1.jpg');
    expect(media.width, 800);
    expect(media.height, 600);
    expect(media.sizeBytes, 50000);
  });
}
