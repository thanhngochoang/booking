// test/data/http/provider_selection_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

ProviderContainer _container(BackendConfig config) {
  final c = ProviderContainer(
    overrides: [
      backendConfigProvider.overrideWithValue(config),
      idTokenSourceProvider.overrideWithValue(const StaticIdTokenSource('t')),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'BACKEND=selfhosted puts the four slice repositories on one ApiClient',
    () {
      final c = _container(
        BackendConfig.parse(
          backend: 'selfhosted',
          baseUrl: 'http://localhost:8787',
        ),
      );
      expect(c.read(userRepositoryProvider), isA<HttpUserRepository>());
      expect(
        c.read(userContactRepositoryProvider),
        isA<HttpUserContactRepository>(),
      );
      expect(
        c.read(photographerContactRepositoryProvider),
        isA<HttpPhotographerContactRepository>(),
      );
      expect(
        c.read(contactLinkRepositoryProvider),
        isA<HttpContactLinkRepository>(),
      );
      expect(
        identical(c.read(apiClientProvider), c.read(apiClientProvider)),
        isTrue,
      );
    },
  );

  test('SELFHOSTED_REPOS=userContact moves only that repository', () {
    final config = BackendConfig.parse(
      backend: 'selfhosted',
      baseUrl: 'http://localhost:8787',
      repos: 'userContact',
    );
    final c = _container(config);
    expect(
      c.read(userContactRepositoryProvider),
      isA<HttpUserContactRepository>(),
    );
    expect(config.uses(SelfhostedRepo.users), isFalse);
  });
}
