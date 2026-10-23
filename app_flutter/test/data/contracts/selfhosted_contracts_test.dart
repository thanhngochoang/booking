// test/data/contracts/selfhosted_contracts_test.dart
@Tags(['selfhosted'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

import 'contact_link_contract.dart';
import 'emulator_token.dart';
import 'photographer_contact_contract.dart';
import 'user_contact_contract.dart';
import 'user_repository_contract.dart';

/// Needs the compose stack with AUTH_MODE=firebase-emulator and the contract
/// world seeded:
///   (booking-be checkout) docker compose up --build -d
///   docker compose run --rm api node dist/tools/seed-contract.js
///   (app_flutter) flutter test test/data/contracts/selfhosted_contracts_test.dart \
///     --tags selfhosted --dart-define=API_BASE_URL=http://localhost:8787
const _base = String.fromEnvironment('API_BASE_URL');
const _project = String.fromEnvironment(
  'API_PROJECT_ID',
  defaultValue: 'demo-nag',
);

var _n = 0;
String _freshUid() => 'ctr_${DateTime.now().microsecondsSinceEpoch}_${_n++}';

ApiClient _api(String uid) => ApiClient(
  baseUrl: Uri.parse(_base),
  tokens: StaticIdTokenSource(emulatorIdToken(uid, projectId: _project)),
);

void main() {
  // Real sockets: no widget-test HTTP override in this file.
  HttpOverrides.global = null;
  final skip = _base.isEmpty
      ? 'needs the compose stack: --dart-define=API_BASE_URL=http://localhost:8787'
      : null;

  group('selfhosted', skip: skip, () {
    userRepositoryContract('HTTP', () async {
      final uid = _freshUid();
      return (repo: HttpUserRepository(api: _api(uid)), uid: uid);
    });

    userContactRepositoryContract('HTTP', () async {
      final uid = _freshUid();
      final api = _api(uid);
      await HttpUserRepository(api: api)
          .ensureProfile(AuthUser(uid: uid, displayName: 'Hợp đồng'));
      return (repo: HttpUserContactRepository(api: api), uid: uid);
    });

    photographerContactRepositoryContract('HTTP', () async {
      final uid = _freshUid();
      final api = _api(uid);
      final users = HttpUserRepository(api: api);
      await users.ensureProfile(
        AuthUser(uid: uid, displayName: 'Thợ hợp đồng'),
      );
      await users.setRole(uid, UserRole.photographer);
      return (repo: HttpPhotographerContactRepository(api: api), uid: uid);
    });

    contactLinkRepositoryContract(
      'HTTP',
      (world) async => HttpContactLinkRepository(api: _api(world.customer)),
    );
  });
}
