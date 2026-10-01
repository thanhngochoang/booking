import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

void main() {
  group('ContactChannels', () {
    test('public flags only, with the documented defaults', () {
      const c = ContactChannels(zalo: true);
      expect(c.toMap(), {
        'call': false,
        'zalo': true,
        'whatsapp': false,
        'acceptInquiries': true,
      });
      expect(c.toMap().keys, isNot(contains('phone')));
    });

    test('fromMap reads flags, tolerates junk and missing maps', () {
      expect(
        ContactChannels.fromMap({
          'call': true,
          'whatsapp': true,
          'acceptInquiries': false,
        }),
        const ContactChannels(
          call: true,
          whatsapp: true,
          acceptInquiries: false,
        ),
      );
      expect(ContactChannels.fromMap(null), isNull);
      expect(ContactChannels.fromMap('x'), isNull);
      expect(
        ContactChannels.fromMap(<String, dynamic>{}),
        const ContactChannels(),
      );
    });

    test('external lists switched-on channels in dial order', () {
      expect(
        const ContactChannels(call: true, zalo: true, whatsapp: true).external,
        [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp],
      );
      expect(const ContactChannels(whatsapp: true, call: true).external, [
        ContactChannel.call,
        ContactChannel.whatsapp,
      ]);
      expect(const ContactChannels().hasExternal, isFalse);
    });
  });

  group('ContactNumbers', () {
    test('numberFor falls back to the main number', () {
      const n = ContactNumbers(phone: '+84903123456');
      expect(n.numberFor(ContactChannel.call), '+84903123456');
      expect(n.numberFor(ContactChannel.zalo), '+84903123456');
      expect(n.numberFor(ContactChannel.whatsapp), '+84903123456');
      expect(n.numberFor(ContactChannel.inApp), isNull);
    });

    test('own numbers win for Zalo and WhatsApp', () {
      const n = ContactNumbers(
        phone: '+84903123456',
        zaloPhone: '+84912345678',
        whatsappPhone: '+14155552671',
      );
      expect(n.numberFor(ContactChannel.call), '+84903123456');
      expect(n.numberFor(ContactChannel.zalo), '+84912345678');
      expect(n.numberFor(ContactChannel.whatsapp), '+14155552671');
    });

    test('toMap omits unset numbers and never carries flags', () {
      expect(const ContactNumbers(phone: '+84903123456').toMap(), {
        'phone': '+84903123456',
      });
      expect(
        const ContactNumbers(
          phone: '+84903123456',
          whatsappPhone: '+14155552671',
        ).toMap(),
        {'phone': '+84903123456', 'whatsappPhone': '+14155552671'},
      );
    });

    test('fromMap needs a phone', () {
      expect(ContactNumbers.fromMap(null), isNull);
      expect(ContactNumbers.fromMap({'zaloPhone': '+84912345678'}), isNull);
      expect(
        ContactNumbers.fromMap({
          'phone': '+84903123456',
          'zaloPhone': '+84912345678',
        }),
        const ContactNumbers(phone: '+84903123456', zaloPhone: '+84912345678'),
      );
    });
  });

  test('ServiceArea round-trips and refuses junk', () {
    const a = ServiceArea(city: 'Hà Nội', radiusKm: 20);
    expect(a.toMap(), {'city': 'Hà Nội', 'radiusKm': 20});
    expect(ServiceArea.fromMap(a.toMap()), a);
    expect(ServiceArea.fromMap({'city': 'Hà Nội'}), isNull);
    expect(ServiceArea.fromMap(null), isNull);
  });

  group('FakePhotographerContactRepository', () {
    const area = ServiceArea(city: 'Hà Nội', radiusKm: 30);
    const channels = ContactChannels(call: true, zalo: true);
    const numbers = ContactNumbers(phone: '+84903123456');

    test(
      'completeContactSetup stores all three parts and marks onboarding done',
      () async {
        final repo = FakePhotographerContactRepository();
        await repo.completeContactSetup(
          'p1',
          area: area,
          channels: channels,
          numbers: numbers,
        );
        expect(repo.areaOf('p1'), area);
        expect(repo.channelsOf('p1'), channels);
        expect(repo.numbersOf('p1'), numbers);
        expect(repo.completed, {'p1'});
        expect(repo.channelsOf('p2'), isNull);
      },
    );

    test(
      'watchers emit the current value, then every change for that user only',
      () async {
        final repo = FakePhotographerContactRepository();
        expect(await repo.watchChannels('p1').first, isNull);
        final seen = repo.watchChannels('p1').skip(1).take(1).toList();
        await repo.completeContactSetup(
          'p2',
          area: area,
          channels: const ContactChannels(),
          numbers: numbers,
        );
        await repo.completeContactSetup(
          'p1',
          area: area,
          channels: channels,
          numbers: numbers,
        );
        expect(await seen, [channels]);
        expect(await repo.watchNumbers('p1').first, numbers);
        expect(await repo.watchServiceArea('p1').first, area);
        expect(repo.watchers, 0);
      },
    );

    test('a failing save throws and stores nothing', () async {
      final repo = FakePhotographerContactRepository(failSave: true);
      await expectLater(
        repo.completeContactSetup(
          'p1',
          area: area,
          channels: channels,
          numbers: numbers,
        ),
        throwsStateError,
      );
      expect(repo.numbersOf('p1'), isNull);
      expect(repo.completed, isEmpty);
    });
  });
}
