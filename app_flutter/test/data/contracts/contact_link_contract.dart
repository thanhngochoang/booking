// test/data/contracts/contact_link_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';

import 'contract_world.dart';

Matcher _fails(ContactLinkError e) =>
    throwsA(isA<ContactLinkException>().having((x) => x.error, 'error', e));

/// Runs every booking of the shared world × every outside channel. The URL
/// must equal plan 2b's reference `contactUriFor`, so the server's phase 1
/// `contactUrl` and the app's function are checked against each other.
void contactLinkRepositoryContract(
  String label,
  Future<ContactLinkRepository> Function(ContactWorld world) create,
) {
  final world = ContactWorld.load();
  const outside = [
    ContactChannel.call,
    ContactChannel.zalo,
    ContactChannel.whatsapp,
  ];

  group('$label ContactLinkRepository contract', () {
    for (final b in world.bookings) {
      for (final channel in outside) {
        test('${b.id} ${channel.code}', () async {
          final repo = await create(world);
          final p = world.photographers[b.photographerId]!;
          final future = repo.link(
            subject: ContactSubject.booking(b.id),
            channel: channel,
          );
          if (!b.unlocked) {
            await expectLater(future, _fails(ContactLinkError.locked));
          } else if (p.channels.external.contains(channel)) {
            expect(await future, contactUriFor(channel, p.numbers));
          } else {
            await expectLater(future, _fails(ContactLinkError.unavailable));
          }
        });
      }
    }

    test('an unknown booking is unavailable', () async {
      final repo = await create(world);
      await expectLater(
        repo.link(
          subject: const ContactSubject.booking('ctr_b_missing'),
          channel: ContactChannel.call,
        ),
        _fails(ContactLinkError.unavailable),
      );
    });

    test('the in-app channel never has a link', () async {
      final repo = await create(world);
      await expectLater(
        repo.link(
          subject: ContactSubject.booking(world.bookings.first.id),
          channel: ContactChannel.inApp,
        ),
        _fails(ContactLinkError.unavailable),
      );
    });
  });
}
