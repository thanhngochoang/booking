// lib/data/backend_config.dart
import 'package:flutter/foundation.dart';

enum Backend { firebase, selfhosted }

/// Repositories of the first self-hosted slice that can move to the HTTP API
/// one by one (data-model README §6 step 4: "theo từng thực thể").
enum SelfhostedRepo {
  users('users'),
  userContact('userContact'),
  photographerContact('photographerContact'),
  contactLink('contactLink');

  const SelfhostedRepo(this.code);
  final String code;
}

/// Which adapter each port uses. Set at build time:
/// `--dart-define=BACKEND=selfhosted --dart-define=BASE_URL=http://10.0.2.2:8787`
/// and optionally `--dart-define=SELFHOSTED_REPOS=userContact,contactLink`.
class BackendConfig {
  const BackendConfig._(this.backend, this.baseUrl, this.repos);
  const BackendConfig.firebase()
    : this._(Backend.firebase, null, const <SelfhostedRepo>{});

  factory BackendConfig.parse({
    required String backend,
    String baseUrl = '',
    String repos = '',
  }) {
    switch (backend) {
      case 'firebase':
        return const BackendConfig.firebase();
      case 'selfhosted':
        final uri = Uri.tryParse(baseUrl);
        final ok =
            uri != null &&
            (uri.isScheme('http') || uri.isScheme('https')) &&
            uri.host.isNotEmpty;
        if (!ok) {
          throw ArgumentError.value(
            baseUrl,
            'BASE_URL',
            'must be an http(s) URL when BACKEND=selfhosted',
          );
        }
        if (kReleaseMode && !uri.isScheme('https')) {
          throw ArgumentError.value(
            baseUrl,
            'BASE_URL',
            'release builds need https',
          );
        }
        final codes = repos
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        final selected = codes.isEmpty
            ? SelfhostedRepo.values.toSet()
            : {
                for (final code in codes)
                  SelfhostedRepo.values.firstWhere(
                    (r) => r.code == code,
                    orElse: () => throw ArgumentError.value(
                      code,
                      'SELFHOSTED_REPOS',
                      'unknown repository',
                    ),
                  ),
              };
        return BackendConfig._(Backend.selfhosted, uri, selected);
      default:
        throw ArgumentError.value(
          backend,
          'BACKEND',
          'must be firebase or selfhosted',
        );
    }
  }

  factory BackendConfig.fromEnvironment() => BackendConfig.parse(
    backend: const String.fromEnvironment('BACKEND', defaultValue: 'firebase'),
    baseUrl: const String.fromEnvironment('BASE_URL'),
    repos: const String.fromEnvironment('SELFHOSTED_REPOS'),
  );

  final Backend backend;
  final Uri? baseUrl;
  final Set<SelfhostedRepo> repos;

  bool uses(SelfhostedRepo repo) =>
      backend == Backend.selfhosted && repos.contains(repo);
}
