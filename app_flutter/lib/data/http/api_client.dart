// lib/data/http/api_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:photobooking/data/auth/id_token_source.dart';

/// A failed call to the self-hosted API. [code] is the server's stable error
/// code (`contact_locked`, `not_found`, …) or one of the client-side codes
/// below. Never carries the response body, so nothing private reaches logs.
class ApiException implements Exception {
  const ApiException(this.status, this.code);
  final int status;
  final String code;

  static const network = 'network';
  static const malformed = 'malformed';
  static const unauthenticated = 'unauthenticated';

  @override
  String toString() => 'ApiException($status, $code)';
}

/// Reads `code` from the error envelope `{code, message, requestId}`.
String errorCodeOf(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map && json['code'] is String) return json['code'] as String;
    return 'unknown';
  } on FormatException {
    return 'unknown';
  }
}

/// One instance per app: a single `http.Client` keeps connections alive and
/// (on mobile, through `dart:io`) asks for and inflates gzip by itself.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _http = client ?? http.Client();

  final Uri baseUrl;
  final IdTokenSource tokens;
  final http.Client _http;
  final Duration timeout;

  Future<Object?> get(String path) => _send('GET', path);
  Future<Object?> post(String path, Map<String, Object?> body) =>
      _send('POST', path, body);
  Future<Object?> put(String path, Map<String, Object?> body) =>
      _send('PUT', path, body);
  Future<Object?> patch(String path, Map<String, Object?> body) =>
      _send('PATCH', path, body);

  void close() => _http.close();

  Uri uriFor(String path) {
    final prefix = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$prefix$path');
  }

  Future<Object?> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    var res = await _once(method, path, body, forceRefresh: false);
    if (res.statusCode == 401) {
      res = await _once(method, path, body, forceRefresh: true);
    }
    final status = res.statusCode;
    final text = utf8.decode(res.bodyBytes);
    if (status >= 200 && status < 300) {
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } on FormatException {
        throw const ApiException(200, ApiException.malformed);
      }
    }
    throw ApiException(status, errorCodeOf(text));
  }

  Future<http.Response> _once(
    String method,
    String path,
    Map<String, Object?>? body, {
    required bool forceRefresh,
  }) async {
    final token = await tokens.token(forceRefresh: forceRefresh);
    if (token == null) {
      throw const ApiException(401, ApiException.unauthenticated);
    }
    final req = http.Request(method, uriFor(path))
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'application/json';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, ApiException.network);
    } on http.ClientException {
      throw const ApiException(0, ApiException.network);
    }
  }
}
