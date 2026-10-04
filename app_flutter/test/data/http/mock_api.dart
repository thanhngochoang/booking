// test/data/http/mock_api.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/http/api_client.dart';

typedef MockHandler = (int, Object?) Function(http.Request request);

http.Response jsonResponse(int status, Object? body) => body == null
    ? http.Response('', status)
    : http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

Map<String, Object?> apiError(String code) => {
  'code': code,
  'message': code,
  'requestId': 'req-1',
};

/// A tiny in-memory API: handlers keyed by "METHOD /path"; anything else is
/// the server's not_found envelope. Records every request.
class MockApi {
  MockApi([Map<String, MockHandler>? routes]) : routes = routes ?? {};
  final Map<String, MockHandler> routes;
  final requests = <http.Request>[];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final handler = routes['${request.method} ${request.url.path}'];
    if (handler == null) return jsonResponse(404, apiError('not_found'));
    final (status, body) = handler(request);
    return jsonResponse(status, body);
  });

  ApiClient api({IdTokenSource tokens = const StaticIdTokenSource('t0')}) =>
      ApiClient(
        baseUrl: Uri.parse('http://api.test'),
        tokens: tokens,
        client: client,
      );

  List<String> get calls => [
    for (final r in requests) '${r.method} ${r.url.path}',
  ];
}
