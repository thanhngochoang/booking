import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/media/http_media_url_resolver.dart';

import '../http/mock_api.dart';

void main() {
  test('returns the url of a ready file', () async {
    final mockApi = MockApi({
      'GET /v1/files/f1': (_) => (
        200,
        {
          'id': 'f1',
          'status': 'ready',
          'url': 'https://cdn.test/f1.jpg',
          'urlExpiresAt': '2026-11-21T15:00:00Z',
        },
      ),
    });
    final resolver = HttpMediaUrlResolver(api: mockApi.api());

    final url = await resolver.downloadUrl('f1');
    expect(url, 'https://cdn.test/f1.jpg');
    expect(mockApi.calls, ['GET /v1/files/f1']);
  });

  test('caches until shortly before expiry and refetches after', () async {
    var currentTime = DateTime.parse('2026-11-21T14:00:00Z');
    var fetchCount = 0;

    final mockApi = MockApi({
      'GET /v1/files/f1': (_) {
        fetchCount++;
        return (
          200,
          {
            'id': 'f1',
            'status': 'ready',
            'url': 'https://cdn.test/f1.jpg?v=$fetchCount',
            // 10 minutes later = 14:10:00Z. Cache threshold is 14:09:00Z (60s before).
            'urlExpiresAt': '2026-11-21T14:10:00Z',
          },
        );
      },
    });

    final resolver = HttpMediaUrlResolver(
      api: mockApi.api(),
      now: () => currentTime,
    );

    // Initial fetch
    final url1 = await resolver.downloadUrl('f1');
    expect(url1, 'https://cdn.test/f1.jpg?v=1');
    expect(fetchCount, 1);

    // 8 minutes later (14:08:00Z < 14:09:00Z) -> cache hit
    currentTime = DateTime.parse('2026-11-21T14:08:00Z');
    final urlCached = await resolver.downloadUrl('f1');
    expect(urlCached, 'https://cdn.test/f1.jpg?v=1');
    expect(fetchCount, 1);

    // 9 minutes 30 seconds later (14:09:30Z >= 14:09:00Z) -> refetches
    currentTime = DateTime.parse('2026-11-21T14:09:30Z');
    final urlRefetched = await resolver.downloadUrl('f1');
    expect(urlRefetched, 'https://cdn.test/f1.jpg?v=2');
    expect(fetchCount, 2);
  });

  test('public file without expiry is cached', () async {
    var fetchCount = 0;
    final mockApi = MockApi({
      'GET /v1/files/pub1': (_) {
        fetchCount++;
        return (
          200,
          {
            'id': 'pub1',
            'status': 'ready',
            'url': 'https://cdn.test/avatar.jpg',
          },
        );
      },
    });

    var currentTime = DateTime.parse('2026-11-21T14:00:00Z');
    final resolver = HttpMediaUrlResolver(
      api: mockApi.api(),
      now: () => currentTime,
    );

    final url1 = await resolver.downloadUrl('pub1');
    expect(url1, 'https://cdn.test/avatar.jpg');
    expect(fetchCount, 1);

    // Much later in time, still cached
    currentTime = DateTime.parse('2027-11-21T14:00:00Z');
    final url2 = await resolver.downloadUrl('pub1');
    expect(url2, 'https://cdn.test/avatar.jpg');
    expect(fetchCount, 1);
  });

  test('not ready file throws StateError', () async {
    final mockApi = MockApi({
      'GET /v1/files/pending1': (_) => (
        200,
        {
          'id': 'pending1',
          'status': 'pending',
        },
      ),
      'GET /v1/files/failed1': (_) => (
        200,
        {
          'id': 'failed1',
          'status': 'failed',
        },
      ),
    });
    final resolver = HttpMediaUrlResolver(api: mockApi.api());

    expect(
      () => resolver.downloadUrl('pending1'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'file not ready',
        ),
      ),
    );
    expect(
      () => resolver.downloadUrl('failed1'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'file not ready',
        ),
      ),
    );
  });

  test('error codes map to ApiException (e.g. 404)', () async {
    final mockApi = MockApi(); // default handler returns 404 not_found
    final resolver = HttpMediaUrlResolver(api: mockApi.api());

    expect(
      () => resolver.downloadUrl('missing'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.code, 'code', 'not_found'),
      ),
    );
  });

  test('external url (http://... or https://...) returns directly', () async {
    final mockApi = MockApi();
    final resolver = HttpMediaUrlResolver(api: mockApi.api());

    final httpUrl = await resolver.downloadUrl('http://example.com/photo.jpg');
    expect(httpUrl, 'http://example.com/photo.jpg');

    final httpsUrl = await resolver.downloadUrl(
      'https://example.com/photo.jpg',
    );
    expect(httpsUrl, 'https://example.com/photo.jpg');

    expect(mockApi.calls, isEmpty);
  });
}
