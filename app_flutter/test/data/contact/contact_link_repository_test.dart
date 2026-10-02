// test/data/contact/contact_link_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

void main() {
  const vn = ContactNumbers(phone: '+84903123456');
  const own = ContactNumbers(
    phone: '+84903123456',
    zaloPhone: '+84912345678',
    whatsappPhone: '+14155552671',
  );

  group('contactUriFor: the exact URL formats', () {
    test('call is tel: with the plus', () {
      expect(
        contactUriFor(ContactChannel.call, vn).toString(),
        'tel:+84903123456',
      );
    });
    test('zalo is https://zalo.me/ with digits only', () {
      expect(
        contactUriFor(ContactChannel.zalo, vn).toString(),
        'https://zalo.me/84903123456',
      );
    });
    test('whatsapp is https://wa.me/ without the plus', () {
      expect(
        contactUriFor(ContactChannel.whatsapp, vn).toString(),
        'https://wa.me/84903123456',
      );
    });
    test('own Zalo and WhatsApp numbers are used, call keeps the main one', () {
      expect(
        contactUriFor(ContactChannel.call, own).toString(),
        'tel:+84903123456',
      );
      expect(
        contactUriFor(ContactChannel.zalo, own).toString(),
        'https://zalo.me/84912345678',
      );
      expect(
        contactUriFor(ContactChannel.whatsapp, own).toString(),
        'https://wa.me/14155552671',
      );
    });
    test('the in-app chat has no URL', () {
      expect(
        () => contactUriFor(ContactChannel.inApp, vn),
        throwsArgumentError,
      );
    });
    test('every URL it builds passes the allow-list for its own channel', () {
      for (final c in [
        ContactChannel.call,
        ContactChannel.zalo,
        ContactChannel.whatsapp,
      ]) {
        expect(
          isAllowedContactUri(contactUriFor(c, own), c),
          isTrue,
          reason: c.code,
        );
      }
    });
  });

  group('isAllowedContactUri', () {
    bool ok(String url, ContactChannel c) =>
        isAllowedContactUri(Uri.parse(url), c);

    test('accepts only the three shapes', () {
      expect(ok('tel:+84903123456', ContactChannel.call), isTrue);
      expect(ok('https://zalo.me/84903123456', ContactChannel.zalo), isTrue);
      expect(ok('https://wa.me/14155552671', ContactChannel.whatsapp), isTrue);
    });

    test('refuses other schemes, hosts, queries and look-alikes', () {
      expect(ok('tel:0903123456', ContactChannel.call), isFalse); // not E.164
      expect(ok('sms:+84903123456', ContactChannel.call), isFalse);
      expect(ok('http://zalo.me/84903123456', ContactChannel.zalo), isFalse);
      expect(
        ok('https://zalo.me.evil.com/84903123456', ContactChannel.zalo),
        isFalse,
      );
      expect(ok('https://evil.com/84903123456', ContactChannel.zalo), isFalse);
      expect(
        ok('https://zalo.me/84903123456?text=hi', ContactChannel.zalo),
        isFalse,
      );
      expect(ok('https://zalo.me/84903123456#x', ContactChannel.zalo), isFalse);
      expect(
        ok('https://user@zalo.me/84903123456', ContactChannel.zalo),
        isFalse,
      );
      expect(
        ok('https://zalo.me:444/84903123456', ContactChannel.zalo),
        isFalse,
      );
      expect(
        ok('https://wa.me/84903123456', ContactChannel.zalo),
        isFalse,
      ); // wrong channel
      expect(
        ok('https://zalo.me/84903123456', ContactChannel.whatsapp),
        isFalse,
      );
      expect(ok('https://wa.me/abc', ContactChannel.whatsapp), isFalse);
      expect(ok('https://wa.me/84903123456', ContactChannel.inApp), isFalse);
    });
  });

  group('callable payload and response', () {
    test(
      'booking and registration use different keys, channel is its code',
      () {
        expect(
          callableData(const ContactSubject.booking('b1'), ContactChannel.zalo),
          {'bookingId': 'b1', 'channel': 'zalo'},
        );
        expect(
          callableData(
            const ContactSubject.registration('r9'),
            ContactChannel.whatsapp,
          ),
          {'registrationId': 'r9', 'channel': 'whatsapp'},
        );
      },
    );

    test('parseLinkResponse reads {url} and refuses anything else', () {
      expect(
        parseLinkResponse({'url': 'tel:+84903123456'}),
        Uri.parse('tel:+84903123456'),
      );
      for (final bad in [
        null,
        'x',
        {'url': 5},
        <String, dynamic>{},
        {'link': 'tel:+84903123456'},
      ]) {
        expect(
          () => parseLinkResponse(bad),
          throwsA(
            isA<ContactLinkException>().having(
              (e) => e.error,
              'error',
              ContactLinkError.unavailable,
            ),
          ),
          reason: '$bad',
        );
      }
    });

    test(
      'only contact_locked is "locked"; every other code is "unavailable"',
      () {
        expect(linkErrorFromCode('contact_locked'), ContactLinkError.locked);
        expect(
          linkErrorFromCode('permission_denied'),
          ContactLinkError.unavailable,
        );
        expect(linkErrorFromCode('not_found'), ContactLinkError.unavailable);
        expect(linkErrorFromCode(null), ContactLinkError.unavailable);
      },
    );

    test('an exception never prints a number', () {
      expect(
        const ContactLinkException(ContactLinkError.locked).toString(),
        isNot(contains('+84')),
      );
    });
  });

  group('FakeContactLinkRepository mirrors the server rules', () {
    const booking = ContactSubject.booking('b1');
    const channels = ContactChannels(call: true, zalo: true, whatsapp: true);

    FakeContactLinkRepository fake({
      bool unlocked = true,
      ContactChannels c = channels,
    }) =>
        FakeContactLinkRepository()
          ..add(booking, numbers: own, channels: c, unlocked: unlocked);

    test(
      'unlocked subject gets the URL for each switched-on channel',
      () async {
        final repo = fake();
        expect(
          (await repo.link(
            subject: booking,
            channel: ContactChannel.zalo,
          )).toString(),
          'https://zalo.me/84912345678',
        );
        expect(
          (await repo.link(
            subject: booking,
            channel: ContactChannel.call,
          )).toString(),
          'tel:+84903123456',
        );
        expect(repo.requests.length, 2);
        expect(repo.requests.first.channel, ContactChannel.zalo);
      },
    );

    test(
      'locked subject is refused with contact_locked and nothing is built',
      () async {
        final repo = fake(unlocked: false);
        await expectLater(
          repo.link(subject: booking, channel: ContactChannel.call),
          throwsA(
            isA<ContactLinkException>().having(
              (e) => e.error,
              'error',
              ContactLinkError.locked,
            ),
          ),
        );
      },
    );

    test('setUnlocked flips the answer', () async {
      final repo = fake(unlocked: false)..setUnlocked(booking, true);
      expect(
        await repo.link(subject: booking, channel: ContactChannel.call),
        isA<Uri>(),
      );
    });

    test('a channel the photographer switched off is unavailable', () async {
      final repo = fake(c: const ContactChannels(zalo: true));
      await expectLater(
        repo.link(subject: booking, channel: ContactChannel.call),
        throwsA(
          isA<ContactLinkException>().having(
            (e) => e.error,
            'error',
            ContactLinkError.unavailable,
          ),
        ),
      );
    });

    test('unknown subject and the in-app channel are unavailable', () async {
      final repo = fake();
      await expectLater(
        repo.link(
          subject: const ContactSubject.booking('nope'),
          channel: ContactChannel.call,
        ),
        throwsA(isA<ContactLinkException>()),
      );
      await expectLater(
        repo.link(subject: booking, channel: ContactChannel.inApp),
        throwsA(isA<ContactLinkException>()),
      );
    });
  });
}
