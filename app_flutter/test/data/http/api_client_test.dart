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
}
