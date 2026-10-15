// test/data/backend_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/backend_config.dart';

void main() {
  test('the default is Firebase for everything', () {
    final c = BackendConfig.parse(backend: 'firebase');
    expect(c.backend, Backend.firebase);
    for (final r in SelfhostedRepo.values) {
      expect(c.uses(r), isFalse);
    }
  });

  test('selfhosted with a base URL moves the whole slice', () {
    final c = BackendConfig.parse(
      backend: 'selfhosted',
      baseUrl: 'http://10.0.2.2:8787',
    );
    expect(c.baseUrl, Uri.parse('http://10.0.2.2:8787'));
    for (final r in SelfhostedRepo.values) {
      expect(c.uses(r), isTrue);
    }
  });

  test('SELFHOSTED_REPOS moves only the listed repositories', () {
    final c = BackendConfig.parse(
      backend: 'selfhosted',
      baseUrl: 'https://api.example.vn',
      repos: 'userContact, contactLink',
    );
    expect(c.uses(SelfhostedRepo.userContact), isTrue);
    expect(c.uses(SelfhostedRepo.contactLink), isTrue);
    expect(c.uses(SelfhostedRepo.users), isFalse);
    expect(c.uses(SelfhostedRepo.photographerContact), isFalse);
  });

  test('bad values fail loudly at startup', () {
    expect(() => BackendConfig.parse(backend: 'supabase'), throwsArgumentError);
    expect(
      () => BackendConfig.parse(backend: 'selfhosted'),
      throwsArgumentError,
    );
    expect(
      () => BackendConfig.parse(backend: 'selfhosted', baseUrl: 'ftp://x'),
      throwsArgumentError,
    );
    expect(
      () => BackendConfig.parse(
        backend: 'selfhosted',
        baseUrl: 'http://x',
        repos: 'chat',
      ),
      throwsArgumentError,
    );
  });
}
