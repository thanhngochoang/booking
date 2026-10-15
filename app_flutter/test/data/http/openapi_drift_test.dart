// test/data/http/openapi_drift_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:yaml/yaml.dart';

/// The hand-written client against services/api/api/openapi.yaml: if the
/// contract changes, this fails until the app follows.
void main() {
  final doc = loadYaml(
    File('../services/api/api/openapi.yaml').readAsStringSync(),
  ) as YamlMap;
  final paths = doc['paths'] as YamlMap;
  final schemas = (doc['components'] as YamlMap)['schemas'] as YamlMap;

  YamlMap resolve(Object? node) {
    var n = node! as YamlMap;
    while (n.containsKey(r'$ref')) {
      n = schemas[(n[r'$ref'] as String).split('/').last] as YamlMap;
    }
    return n;
  }

  test('every call the app makes exists in the contract', () {
    for (final (method, path) in apiOperations) {
      final item = paths[path] as YamlMap?;
      expect(item, isNotNull, reason: path);
      expect(item![method.toLowerCase()], isNotNull, reason: '$method $path');
    }
  });

  test('ApiPaths builds exactly those paths', () {
    String fill(String template) =>
        template.replaceAll(RegExp(r'\{\w+\}'), 'id1');
    expect(
      {
        ApiPaths.me,
        ApiPaths.user('id1'),
        ApiPaths.userRole('id1'),
        ApiPaths.userContact('id1'),
        ApiPaths.contactChannels('id1'),
        ApiPaths.contactNumbers('id1'),
        ApiPaths.serviceArea('id1'),
        ApiPaths.contactSetup('id1'),
        ApiPaths.contactLinks,
      },
      {for (final (_, p) in apiOperations) fill(p)},
    );
  });

  test(
    'request bodies use only contract properties, and all required ones',
    () {
      void check(String name, Map<String, Object?> body) {
        final s = resolve(schemas[name]);
        final props = s['properties'] as YamlMap;
        final required =
            (s['required'] as YamlList?)?.cast<String>() ?? const <String>[];
        expect(
          props.keys.toSet().containsAll(body.keys),
          isTrue,
          reason: '$name: ${body.keys}',
        );
        for (final r in required) {
          expect(body.containsKey(r), isTrue, reason: '$name needs $r');
        }
        for (final MapEntry(:key, :value) in body.entries) {
          final ref = (props[key] as YamlMap)[r'$ref'] as String?;
          if (value is Map<String, Object?> && ref != null) {
            check(ref.split('/').last, value);
          }
        }
      }

      check(
        'EnsureProfileRequest',
        ensureProfileBody(
          const AuthUser(
            uid: 'u1',
            displayName: 'Lan',
            photoUrl: 'https://x.test/a.jpg',
          ),
        ),
      );
      check('UpdateUserRequest', updateUserBody('Lan'));
      check('SetRoleRequest', setRoleBody(UserRole.photographer));
      check(
        'SaveUserContactRequest',
        saveContactBody(
          phone: '+84903123456',
          allowZalo: true,
          allowWhatsApp: false,
        ),
      );
      check(
        'ContactSetupRequest',
        contactSetupBody(
          area: const ServiceArea(city: 'Hà Nội', radiusKm: 20),
          channels: const ContactChannels(call: true),
          numbers: const ContactNumbers(
            phone: '+84903123456',
            zaloPhone: '+84912345678',
            whatsappPhone: '+14155552671',
          ),
        ),
      );
      check(
        'ContactLinkRequest',
        callableData(const ContactSubject.booking('b1'), ContactChannel.zalo),
      );
    },
  );

  test(
    'response mappers accept a contract-shaped sample of every response schema',
    () {
      Object? sample(Object? node) {
        final s = resolve(node);
        final values = s['enum'] as YamlList?;
        if (values != null) return values.firstWhere((v) => v != null);
        return switch (s['type']) {
          'object' => {
            for (final key in (s['required'] as YamlList).cast<String>())
              key: sample((s['properties'] as YamlMap)[key]),
          },
          'boolean' => true,
          'integer' => 20,
          _ when s['format'] == 'date-time' => '2026-10-01T00:00:00Z',
          _ when (s['pattern'] as String?)?.contains('84') ?? false =>
            '+84903123456',
          _ => 'id1',
        };
      }

      expect(
        () => profileFromJson(sample(schemas['UserProfile'])),
        returnsNormally,
      );
      expect(
        () => userContactFromJson(sample(schemas['UserContact'])),
        returnsNormally,
      );
      expect(
        () => channelsFromJson(sample(schemas['ContactChannels'])),
        returnsNormally,
      );
      expect(
        () => numbersFromJson(sample(schemas['ContactNumbers'])),
        returnsNormally,
      );
      expect(
        () => areaFromJson(sample(schemas['ServiceArea'])),
        returnsNormally,
      );
      expect(
        () => parseLinkResponse(sample(schemas['ContactLinkResponse'])),
        returnsNormally,
      );
    },
  );
}
