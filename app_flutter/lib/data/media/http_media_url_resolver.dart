import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class HttpMediaUrlResolver implements MediaUrlResolver {
  HttpMediaUrlResolver({required this.api, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient api;
  final DateTime Function() _now;
  final Map<String, ({String url, DateTime? expiresAt})> _cache = {};

  @override
  Future<String> downloadUrl(String storagePath) async {
    if (storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return storagePath;
    }
    final cached = _cache[storagePath];
    if (cached != null) {
      if (cached.expiresAt == null ||
          _now().isBefore(
            cached.expiresAt!.subtract(const Duration(seconds: 60)),
          )) {
        return cached.url;
      }
    }
    final res = await api.get(ApiPaths.file(storagePath));
    if (res is! Map) {
      throw const ApiException(200, ApiException.malformed);
    }
    final status = res['status'] as String?;
    if (status != 'ready') {
      throw StateError('file not ready');
    }
    final url = res['url'] as String;
    final rawExpires = res['urlExpiresAt'] as String?;
    final expiresAt = rawExpires != null ? DateTime.parse(rawExpires) : null;
    _cache[storagePath] = (url: url, expiresAt: expiresAt);
    return url;
  }
}
