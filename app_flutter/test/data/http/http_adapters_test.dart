// test/data/http/http_adapters_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';
import 'package:photobooking/data/user/http_user_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

import 'mock_api.dart';

const _contactJson = {
  'phone': '+84903123456',
  'phoneVerified': false,
  'allowZalo': true,
  'allowWhatsApp': false,
  'updatedAt': '2026-10-01T00:00:00.000Z',
};

Map<String, Object?> _profile(String name, {String? role}) => {
  'id': 'u1',
  'displayName': name,
  'role': role,
  'avatarUrl': null,
};

void main() {
  test(
    'user contact: 404 reads as "none yet", a stored contact maps',
    () async {
      final api = MockApi();
      final repo = HttpUserContactRepository(api: api.api());
      expect(await repo.watch('u1').first, isNull);
      api.routes['GET /v1/users/u1/contact'] = (_) => (200, _contactJson);
      expect(
        await repo.watch('u1').first,
        const UserContact(phone: '+84903123456'),
      );
    },
  );

  test(
    'user contact: save sends exactly the contract body; a live watch sees it',
    () async {
      final api = MockApi({
        'PUT /v1/users/u1/contact': (r) {
          expect(jsonDecode(r.body), {
            'phone': '+84903123456',
            'allowZalo': true,
            'allowWhatsApp': false,
          });
          return (200, _contactJson);
        },
      });
      final repo = HttpUserContactRepository(api: api.api());
      final live = expectLater(
        repo.watch('u1'),
        emitsInOrder([isNull, const UserContact(phone: '+84903123456')]),
      );
      await pumpEventQueue();
      await repo.save(
        'u1',
        phone: '+84903123456',
        allowZalo: true,
        allowWhatsApp: false,
      );
      await live;
    },
  );

  test(
    'profile: ensureProfile posts name and avatar, setRole puts the code',
    () async {
      final api = MockApi({
        'POST /v1/me': (r) {
          expect(jsonDecode(r.body), {
            'displayName': 'Lan',
            'avatarUrl': 'https://lh3.googleusercontent.com/a.jpg',
          });
          return (201, _profile('Lan'));
        },
        'PUT /v1/users/u1/role': (r) {
          expect(jsonDecode(r.body), {'role': 'photographer'});
          return (200, _profile('Lan', role: 'photographer'));
        },
      });
      final repo = HttpUserRepository(api: api.api());
      final p = await repo.ensureProfile(
        const AuthUser(
          uid: 'u1',
          email: 'lan@example.com',
          displayName: 'Lan',
          photoUrl: 'https://lh3.googleusercontent.com/a.jpg',
        ),
      );
      expect(p.needsRole, isTrue);
      expect(p.email, 'lan@example.com');
      await repo.setRole('u1', UserRole.photographer);
      expect(api.calls, ['POST /v1/me', 'PUT /v1/users/u1/role']);
    },
  );

  test('setDisplayName before the profile exists creates it', () async {
    var created = false;
    final api = MockApi({
      'PATCH /v1/users/u1': (_) =>
          created ? (200, _profile('Minh')) : (404, apiError('not_found')),
      'POST /v1/me': (_) {
        created = true;
        return (201, _profile('Minh'));
      },
    });
    await HttpUserRepository(api: api.api()).setDisplayName('u1', 'Minh');
    expect(api.calls, [
      'PATCH /v1/users/u1',
      'POST /v1/me',
      'PATCH /v1/users/u1',
    ]);
  });

  test('photographer contact: one PUT for the setup, 404 reads as null, a 403 is an error', () async {
    final api = MockApi({
      'PUT /v1/photographers/p1/contact-setup': (r) {
        expect(jsonDecode(r.body), {
          'area': {'city': 'Hà Nội', 'radiusKm': 20},
          'channels': {
            'call': true,
            'zalo': false,
            'whatsapp': false,
            'acceptInquiries': true,
          },
          'numbers': {'phone': '+84903123456'},
        });
        return (204, null);
      },
      'GET /v1/photographers/p2/contact-numbers': (_) =>
          (403, apiError('permission_denied')),
    });
    final repo = HttpPhotographerContactRepository(api: api.api());
    expect(await repo.watchChannels('p1').first, isNull);
    await repo.completeContactSetup(
      'p1',
      area: const ServiceArea(city: 'Hà Nội', radiusKm: 20),
      channels: const ContactChannels(call: true),
      numbers: const ContactNumbers(phone: '+84903123456'),
    );
    await expectLater(
      repo.watchNumbers('p2').first,
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'permission_denied'),
      ),
    );
  });

  test('contact link: URL on success, contact_locked → locked, anything else → unavailable, in-app sends nothing', () async {
    final api = MockApi({
      'POST /v1/contact-links': (r) {
        final body = jsonDecode(r.body) as Map<String, Object?>;
        return switch (body['bookingId']) {
          'b_ok' => (200, {'url': 'https://zalo.me/84912345678'}),
          'b_locked' => (403, apiError('contact_locked')),
          _ => (404, apiError('not_found')),
        };
      },
    });
    final repo = HttpContactLinkRepository(api: api.api());
    expect(
      await repo.link(
        subject: const ContactSubject.booking('b_ok'),
        channel: ContactChannel.zalo,
      ),
      Uri.parse('https://zalo.me/84912345678'),
    );
    Matcher error(ContactLinkError e) =>
        throwsA(isA<ContactLinkException>().having((x) => x.error, 'error', e));
    await expectLater(
      repo.link(
        subject: const ContactSubject.booking('b_locked'),
        channel: ContactChannel.call,
      ),
      error(ContactLinkError.locked),
    );
    await expectLater(
      repo.link(
        subject: const ContactSubject.booking('nope'),
        channel: ContactChannel.call,
      ),
      error(ContactLinkError.unavailable),
    );
    final before = api.requests.length;
    await expectLater(
      repo.link(
        subject: const ContactSubject.booking('b_ok'),
        channel: ContactChannel.inApp,
      ),
      error(ContactLinkError.unavailable),
    );
    expect(api.requests.length, before);
  });

  test('a body that is not the contract shape is "malformed"', () async {
    final api = MockApi({
      'GET /v1/users/u1': (_) => (200, {'name': 'x'}),
    });
    await expectLater(
      HttpUserRepository(api: api.api()).watch('u1').first,
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiException.malformed,
        ),
      ),
    );
  });
}
