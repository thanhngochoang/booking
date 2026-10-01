import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

class _StubLinks implements ContactLinkRepository {
  _StubLinks(this.uri);
  final Uri uri;
  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async => uri;
}

class _ThrowingLinks implements ContactLinkRepository {
  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async => throw StateError('boom');
}

void main() {
  const subject = ContactSubject.booking('b1');
  const numbers = ContactNumbers(
    phone: '+84903123456',
    whatsappPhone: '+14155552671',
  );
  const channels = ContactChannels(call: true, zalo: true, whatsapp: true);

  ({
    ContactLauncher launcher,
    FakeContactLinkRepository links,
    FakeExternalLauncher external,
  })
  build({
    bool unlocked = true,
    Set<String> unsupported = const {},
    bool failOpen = false,
  }) {
    final links = FakeContactLinkRepository()
      ..add(subject, numbers: numbers, channels: channels, unlocked: unlocked);
    final external = FakeExternalLauncher(
      unsupportedSchemes: unsupported,
      failOpen: failOpen,
    );
    return (
      launcher: ContactLauncher(links: links, launcher: external),
      links: links,
      external: external,
    );
  }

  test(
    'opens the dialer, Zalo and WhatsApp with the server-built URLs',
    () async {
      final t = build();
      expect(
        await t.launcher.open(ContactChannel.call, subject: subject),
        ContactOpenResult.opened,
      );
      expect(
        await t.launcher.open(ContactChannel.zalo, subject: subject),
        ContactOpenResult.opened,
      );
      expect(
        await t.launcher.open(ContactChannel.whatsapp, subject: subject),
        ContactOpenResult.opened,
      );
      expect(t.external.opened.map((u) => u.toString()), [
        'tel:+84903123456',
        'https://zalo.me/84903123456',
        'https://wa.me/14155552671',
      ]);
    },
  );

  test('maps contact_locked and opens nothing', () async {
    final t = build(unlocked: false);
    expect(
      await t.launcher.open(ContactChannel.zalo, subject: subject),
      ContactOpenResult.locked,
    );
    expect(t.external.opened, isEmpty);
  });

  test('other server failures are "unavailable"', () async {
    final t = build();
    expect(
      await t.launcher.open(
        ContactChannel.zalo,
        subject: const ContactSubject.booking('missing'),
      ),
      ContactOpenResult.unavailable,
    );
    expect(t.external.opened, isEmpty);
  });

  test(
    'any non-contact exception from the repository is "unavailable"',
    () async {
      final external = FakeExternalLauncher();
      final launcher = ContactLauncher(
        links: _ThrowingLinks(),
        launcher: external,
      );
      expect(
        await launcher.open(ContactChannel.zalo, subject: subject),
        ContactOpenResult.unavailable,
      );
      expect(external.opened, isEmpty);
    },
  );

  test('a URL the server should not send is refused, not opened', () async {
    for (final url in [
      'https://evil.com/84903123456',
      'https://zalo.me/84903123456?text=x',
      'http://zalo.me/84903123456',
      'tel:0903123456',
    ]) {
      final external = FakeExternalLauncher();
      final launcher = ContactLauncher(
        links: _StubLinks(Uri.parse(url)),
        launcher: external,
      );
      final channel = url.startsWith('tel')
          ? ContactChannel.call
          : ContactChannel.zalo;
      expect(
        await launcher.open(channel, subject: subject),
        ContactOpenResult.unavailable,
        reason: url,
      );
      expect(external.opened, isEmpty, reason: url);
    }
  });

  test('the OS refusing to open is "cannotLaunch"', () async {
    final t = build(failOpen: true);
    expect(
      await t.launcher.open(ContactChannel.zalo, subject: subject),
      ContactOpenResult.cannotLaunch,
    );
  });

  test(
    'canOpen hides the dialer on a device without a phone, keeps the web links',
    () async {
      final t = build(unsupported: {'tel'});
      expect(await t.launcher.canOpen(ContactChannel.call), isFalse);
      expect(await t.launcher.canOpen(ContactChannel.zalo), isTrue);
      expect(await t.launcher.canOpen(ContactChannel.whatsapp), isTrue);
      expect(await t.launcher.canOpen(ContactChannel.inApp), isFalse);
    },
  );

  test('the in-app channel is not opened here', () async {
    final t = build();
    expect(
      () => t.launcher.open(ContactChannel.inApp, subject: subject),
      throwsArgumentError,
    );
  });

  test('canOpen probes with a placeholder, never a real number', () async {
    final t = build();
    await t.launcher.canOpen(ContactChannel.call);
    expect(t.links.requests, isEmpty);
    expect(t.external.opened, isEmpty);
  });
}
