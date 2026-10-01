import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

void main() {
  test('only phone and the two permissions are written by the client', () {
    const c = UserContact(phone: '+84903123456');
    expect(contactToFirestore(c), {
      'phone': '+84903123456',
      'allowZalo': true,
      'allowWhatsApp': false,
    });
  });

  test('defaults: not verified, Zalo on, WhatsApp off', () {
    const c = UserContact(phone: '+84903123456');
    expect(c.phoneVerified, isFalse);
    expect(c.allowZalo, isTrue);
    expect(c.allowWhatsApp, isFalse);
  });

  test('fake saves, streams updates and keeps users separate', () async {
    final repo = FakeUserContactRepository();
    expect(await repo.watch('u1').first, isNull);
    final updates = repo.watch('u1').skip(1).take(2).toList();
    await Future.delayed(Duration.zero);
    await repo.save(
      'u1',
      phone: '+84903123456',
      allowZalo: true,
      allowWhatsApp: false,
    );
    await repo.save(
      'u1',
      phone: '+84903123456',
      allowZalo: false,
      allowWhatsApp: true,
    );
    final seen = await updates;
    expect(
      seen.last,
      const UserContact(
        phone: '+84903123456',
        allowZalo: false,
        allowWhatsApp: true,
      ),
    );
    expect(repo.stored('u2'), isNull);
  });

  test(
    'changing the number resets verification; changing only a toggle keeps it',
    () async {
      final repo = FakeUserContactRepository()
        ..seed(
          'u1',
          const UserContact(phone: '+84903123456', phoneVerified: true),
        );
      await repo.save(
        'u1',
        phone: '+84903123456',
        allowZalo: false,
        allowWhatsApp: false,
      );
      expect(repo.stored('u1')!.phoneVerified, isTrue);
      await repo.save(
        'u1',
        phone: '+84912345678',
        allowZalo: false,
        allowWhatsApp: false,
      );
      expect(repo.stored('u1')!.phoneVerified, isFalse);
    },
  );

  test('a failing save throws and stores nothing', () async {
    final repo = FakeUserContactRepository(failSave: true);
    await expectLater(
      repo.save(
        'u1',
        phone: '+84903123456',
        allowZalo: true,
        allowWhatsApp: false,
      ),
      throwsStateError,
    );
    expect(repo.stored('u1'), isNull);
  });
}
