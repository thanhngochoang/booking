// test/data/contracts/user_contact_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

import 'user_repository_contract.dart';

void userContactRepositoryContract(
  String label,
  Create<UserContactRepository> create,
) {
  group('$label UserContactRepository contract', () {
    test('no contact yet emits null', () async {
      final h = await create();
      expect(await h.repo.watch(h.uid).first, isNull);
    });

    test(
      'a saved contact reads back unverified with its permissions',
      () async {
        final h = await create();
        await h.repo.save(
          h.uid,
          phone: '+84903123456',
          allowZalo: false,
          allowWhatsApp: true,
        );
        expect(
          await h.repo.watch(h.uid).first,
          const UserContact(
            phone: '+84903123456',
            allowZalo: false,
            allowWhatsApp: true,
          ),
        );
      },
    );

    test('a live watch sees saves', () async {
      final h = await create();
      final seen = expectLater(
        h.repo.watch(h.uid),
        emitsThrough(const UserContact(phone: '+84912345678')),
      );
      await h.repo.save(
        h.uid,
        phone: '+84912345678',
        allowZalo: true,
        allowWhatsApp: false,
      );
      await seen;
    });

    test('a toggle keeps the number; a new number replaces it', () async {
      final h = await create();
      await h.repo.save(
        h.uid,
        phone: '+84903123456',
        allowZalo: true,
        allowWhatsApp: false,
      );
      await h.repo.save(
        h.uid,
        phone: '+84903123456',
        allowZalo: false,
        allowWhatsApp: false,
      );
      expect((await h.repo.watch(h.uid).first)?.phone, '+84903123456');
      await h.repo.save(
        h.uid,
        phone: '+84987654321',
        allowZalo: false,
        allowWhatsApp: false,
      );
      final now = await h.repo.watch(h.uid).first;
      expect((now?.phone, now?.phoneVerified), ('+84987654321', false));
    });
  });
}
