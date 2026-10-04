// lib/data/http/api_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/http/api_client.dart';

final backendConfigProvider = Provider<BackendConfig>(
  (ref) => BackendConfig.fromEnvironment(),
);

final idTokenSourceProvider = Provider<IdTokenSource>(
  (ref) => FirebaseIdTokenSource(),
);

/// Built only when some repository uses the self-hosted backend.
final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(backendConfigProvider).baseUrl;
  if (base == null) {
    throw StateError('BASE_URL is required when BACKEND=selfhosted');
  }
  final client = ApiClient(
    baseUrl: base,
    tokens: ref.watch(idTokenSourceProvider),
  );
  ref.onDispose(client.close);
  return client;
});
