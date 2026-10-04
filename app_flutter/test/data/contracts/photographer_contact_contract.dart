// test/data/contracts/photographer_contact_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

import 'user_repository_contract.dart';

const _area = ServiceArea(city: 'Hà Nội', radiusKm: 20);
const _channels = ContactChannels(call: true, zalo: true);
const _numbers = ContactNumbers(
  phone: '+84903123456',
  zaloPhone: '+84912345678',
);

void photographerContactRepositoryContract(
  String label,
  Create<PhotographerContactRepository> create,
) {
  group('$label PhotographerContactRepository contract', () {
    test('before setup there are no channels, numbers or area', () async {
      final h = await create();
      expect(await h.repo.watchChannels(h.uid).first, isNull);
      expect(await h.repo.watchNumbers(h.uid).first, isNull);
      expect(await h.repo.watchServiceArea(h.uid).first, isNull);
    });

    test('completeContactSetup stores the three parts', () async {
      final h = await create();
      await h.repo.completeContactSetup(
        h.uid,
        area: _area,
        channels: _channels,
        numbers: _numbers,
      );
      expect(await h.repo.watchChannels(h.uid).first, _channels);
      expect(await h.repo.watchNumbers(h.uid).first, _numbers);
      expect(await h.repo.watchServiceArea(h.uid).first, _area);
    });

    test('saving again without an own Zalo number clears it', () async {
      final h = await create();
      await h.repo.completeContactSetup(
        h.uid,
        area: _area,
        channels: _channels,
        numbers: _numbers,
      );
      await h.repo.completeContactSetup(
        h.uid,
        area: _area,
        channels: _channels,
        numbers: const ContactNumbers(phone: '+84903123456'),
      );
      expect((await h.repo.watchNumbers(h.uid).first)?.zaloPhone, isNull);
    });

    test('a live channels watch sees the setup', () async {
      final h = await create();
      final seen = expectLater(
        h.repo.watchChannels(h.uid),
        emitsThrough(_channels),
      );
      await h.repo.completeContactSetup(
        h.uid,
        area: _area,
        channels: _channels,
        numbers: _numbers,
      );
      await seen;
    });
  });
}
