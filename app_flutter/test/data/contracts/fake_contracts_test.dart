// test/data/contracts/fake_contracts_test.dart
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';

import 'contact_link_contract.dart';
import 'photographer_contact_contract.dart';
import 'user_contact_contract.dart';
import 'user_repository_contract.dart';

void main() {
  userRepositoryContract(
    'Fake',
    () async => (repo: FakeUserRepository(), uid: 'u1'),
  );
  userContactRepositoryContract(
    'Fake',
    () async => (repo: FakeUserContactRepository(), uid: 'u1'),
  );
  photographerContactRepositoryContract(
    'Fake',
    () async => (repo: FakePhotographerContactRepository(), uid: 'p1'),
  );
  contactLinkRepositoryContract('Fake', (world) async {
    final fake = FakeContactLinkRepository();
    for (final b in world.bookings) {
      final p = world.photographers[b.photographerId]!;
      fake.add(
        ContactSubject.booking(b.id),
        numbers: p.numbers,
        channels: p.channels,
        unlocked: b.unlocked,
      );
    }
    return fake;
  });
}
