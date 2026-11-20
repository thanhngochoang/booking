// test/data/http/api_client_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/http/api_client.dart';

import 'mock_api.dart';

class _CountingTokens implements IdTokenSource {
  final refreshes = <bool>[];
  @override
  Future<String?> token({bool forceRefresh = false}) async {
    refreshes.add(forceRefresh);
    return forceRefresh ? 'fresh' : 'stale';
  }
}

void main() {
  test('sends the bearer token, JSON in and out', () async {
    final api = MockApi({
      'PUT /v1/x': (r) {
        expect(r.headers['authorization'], 'Bearer t0');
        expect(r.headers['accept'], 'application/json');
        expect(r.headers['content-type'], startsWith('application/json'));
        expect(jsonDecode(r.body), {'a': 1});
        return (200, {'ok': 'Thợ ảnh'});
      },
    });
    expect(await api.api().put('/v1/x', {'a': 1}), {'ok': 'Thợ ảnh'});
  });

  test('a 401 refreshes the token and retries once', () async {
    final tokens = _CountingTokens();
    final api = MockApi({
      'GET /v1/x': (r) => r.headers['authorization'] == 'Bearer fresh'
          ? (200, {'ok': true})
          : (401, apiError('unauthenticated')),
    });
    expect(await api.api(tokens: tokens).get('/v1/x'), {'ok': true});
    expect(tokens.refreshes, [false, true]);
    expect(api.requests, hasLength(2));
  });

  test(
    'errors carry the server code, or "unknown" for a foreign body',
    () async {
      final api = MockApi({
        'GET /v1/locked': (_) => (403, apiError('contact_locked')),
        'GET /v1/html': (_) => (502, null),
      });
      await expectLater(
        api.api().get('/v1/locked'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'contact_locked'),
        ),
      );
      await expectLater(
        api.api().get('/v1/html'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'unknown')
              .having((e) => e.status, 'status', 502),
        ),
      );
    },
  );

  test('a network failure is the client-side "network" code', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    final api = ApiClient(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('t'),
      client: client,
    );
    await expectLater(
      api.get('/v1/x'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', ApiException.network),
      ),
    );
  });

  test('signed out: no request at all', () async {
    final api = MockApi();
    await expectLater(
      api.api(tokens: const StaticIdTokenSource(null)).get('/v1/x'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'unauthenticated'),
      ),
    );
    expect(api.requests, isEmpty);
  });

  test('a base URL with a path prefix keeps it', () {
    final api = ApiClient(
      baseUrl: Uri.parse('https://h.example/api/'),
      tokens: const StaticIdTokenSource('t'),
    );
    expect(api.uriFor('/v1/me').toString(), 'https://h.example/api/v1/me');
    api.close();
  });

  test('delete sends DELETE with the bearer token and returns null for an empty 204', () async {
    final api = MockApi({
      'DELETE /v1/item': (r) {
        expect(r.method, 'DELETE');
        expect(r.headers['authorization'], 'Bearer t0');
        return (204, null);
      },
    });
    final res = await api.api().delete('/v1/item');
    expect(res, isNull);
  });

  test('query values are URL-encoded and appended', () async {
    final api = MockApi({
      'GET /v1/list': (r) {
        expect(r.url.queryParameters, {'after': 'a b', 'limit': '20'});
        return (200, {'items': []});
      },
    });
    final res = await api.api().get(
      '/v1/list',
      query: {'after': 'a b', 'limit': '20'},
    );
    expect(res, {'items': []});
    expect(api.requests.single.url.toString(), 'http://api.test/v1/list?after=a+b&limit=20');
  });

  test('idempotencyKey becomes the idempotency-key header, and the 401 retry sends the same key', () async {
    final tokens = _CountingTokens();
    final api = MockApi({
      'POST /v1/action': (r) {
        expect(r.headers['idempotency-key'], 'idem-123');
        return r.headers['authorization'] == 'Bearer fresh'
            ? (200, {'done': true})
            : (401, apiError('unauthenticated'));
      },
    });
    final res = await api.api(tokens: tokens).post(
      '/v1/action',
      {'x': 1},
      idempotencyKey: 'idem-123',
    );
    expect(res, {'done': true});
    expect(api.requests, hasLength(2));
    expect(api.requests[0].headers['idempotency-key'], 'idem-123');
    expect(api.requests[1].headers['idempotency-key'], 'idem-123');
  });

  test('a request without a key has no such header', () async {
    final api = MockApi({
      'POST /v1/action': (r) {
        expect(r.headers.containsKey('idempotency-key'), isFalse);
        return (200, {'done': true});
      },
    });
    await api.api().post('/v1/action', {'x': 1});
  });

  test('delete maps an error body to ApiException(code)', () async {
    final api = MockApi({
      'DELETE /v1/item': (_) => (404, apiError('not_found')),
    });
    await expectLater(
      api.api().delete('/v1/item'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'not_found')
            .having((e) => e.status, 'status', 404),
      ),
    );
  });
}
