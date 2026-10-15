// test/features/photographer_setup/contact_setup_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_logic.dart';

ContactSetupInput _in({
  String city = 'Hà Nội',
  int radiusKm = 20,
  String phone = '903 123 456',
  bool call = false,
  bool zalo = false,
  String zaloOwn = '',
  bool whatsapp = false,
  String whatsappOwn = '',
  bool inAppOnly = false,
  bool acceptInquiries = true,
}) => ContactSetupInput(
  city: city,
  radiusKm: radiusKm,
  phone: phone,
  call: call,
  zalo: zalo,
  zaloOwn: zaloOwn,
  whatsapp: whatsapp,
  whatsappOwn: whatsappOwn,
  inAppOnly: inAppOnly,
  acceptInquiries: acceptInquiries,
);

void main() {
  test('an empty form needs city, number and a channel decision', () {
    final r = validateContactSetup(const ContactSetupInput());
    expect(r.ok, isFalse);
    expect(r.errors, {
      ContactSetupField.city: ContactSetupError.cityRequired,
      ContactSetupField.phone: ContactSetupError.phoneRequired,
      ContactSetupField.channels: ContactSetupError.noChannel,
    });
  });

  test('minimum valid form: number plus one channel', () {
    final r = validateContactSetup(_in(zalo: true));
    expect(r.ok, isTrue);
    expect(r.area, const ServiceArea(city: 'Hà Nội', radiusKm: 20));
    expect(r.channels, const ContactChannels(zalo: true));
    expect(r.numbers, const ContactNumbers(phone: '+84903123456'));
  });

  test('city is trimmed and needs two characters', () {
    expect(
      validateContactSetup(_in(city: '  Đà Nẵng  ', call: true)).area!.city,
      'Đà Nẵng',
    );
    expect(
      validateContactSetup(_in(city: ' Đ ', call: true))
          .errors[ContactSetupField.city],
      ContactSetupError.cityRequired,
    );
  });

  test('main number: empty and malformed are different errors', () {
    expect(
      validateContactSetup(_in(phone: '', call: true))
          .errors[ContactSetupField.phone],
      ContactSetupError.phoneRequired,
    );
    expect(
      validateContactSetup(_in(phone: '90312345', call: true))
          .errors[ContactSetupField.phone],
      ContactSetupError.phoneInvalid,
    );
  });

  group('Zalo', () {
    test('empty own number means the main number', () {
      final r = validateContactSetup(_in(zalo: true));
      expect(r.numbers!.zaloPhone, isNull);
    });
    test('a different own number is kept, the same one is dropped', () {
      expect(
        validateContactSetup(_in(zalo: true, zaloOwn: '0912345678'))
            .numbers!
            .zaloPhone,
        '+84912345678',
      );
      expect(
        validateContactSetup(_in(zalo: true, zaloOwn: '0903 123 456'))
            .numbers!
            .zaloPhone,
        isNull,
      );
    });
    test('an invalid own number is an error under the Zalo field', () {
      final r = validateContactSetup(_in(zalo: true, zaloOwn: '12345'));
      expect(r.errors, {ContactSetupField.zalo: ContactSetupError.zaloInvalid});
    });
    test('text left in a switched-off Zalo field is ignored', () {
      final r = validateContactSetup(
        _in(call: true, zalo: false, zaloOwn: 'garbage'),
      );
      expect(r.ok, isTrue);
      expect(r.numbers!.zaloPhone, isNull);
    });
  });

  group('WhatsApp', () {
    test('on and empty: use the main number, which is valid international', () {
      final r = validateContactSetup(_in(whatsapp: true));
      expect(r.ok, isTrue);
      expect(r.channels!.whatsapp, isTrue);
      expect(r.numbers!.whatsappPhone, isNull);
    });
    test('on, empty, and no usable main number: error under the WhatsApp field too', () {
      final r = validateContactSetup(_in(phone: '', whatsapp: true));
      expect(
        r.errors[ContactSetupField.whatsapp],
        ContactSetupError.whatsappNeedsNumber,
      );
      expect(
        r.errors[ContactSetupField.phone],
        ContactSetupError.phoneRequired,
      );
    });
    test('an international own number is kept', () {
      expect(
        validateContactSetup(
          _in(whatsapp: true, whatsappOwn: '+1 415 555 2671'),
        ).numbers!.whatsappPhone,
        '+14155552671',
      );
    });
    test('a number without a country code is refused', () {
      final r = validateContactSetup(
        _in(whatsapp: true, whatsappOwn: '4155552671'),
      );
      expect(r.errors, {
        ContactSetupField.whatsapp: ContactSetupError.whatsappInvalid,
      });
    });
    test(
      'a Vietnamese 0… number is read as +84…; the same as main is dropped',
      () {
        expect(
          validateContactSetup(_in(whatsapp: true, whatsappOwn: '0912345678'))
              .numbers!
              .whatsappPhone,
          '+84912345678',
        );
        expect(
          validateContactSetup(_in(whatsapp: true, whatsappOwn: '+84903123456'))
              .numbers!
              .whatsappPhone,
          isNull,
        );
      },
    );
  });

  group('in-app only', () {
    test('counts as a decision, switches the outside channels off', () {
      final r = validateContactSetup(
        _in(inAppOnly: true, call: true, zalo: true, whatsapp: true),
      );
      expect(r.ok, isTrue);
      expect(r.channels, const ContactChannels());
      expect(r.numbers, const ContactNumbers(phone: '+84903123456'));
    });
    test('still needs a valid number', () {
      final r = validateContactSetup(_in(inAppOnly: true, phone: ''));
      expect(r.errors, {
        ContactSetupField.phone: ContactSetupError.phoneRequired,
      });
    });
    test(
      'without it and without a channel there is an error on the channels',
      () {
        expect(validateContactSetup(_in()).errors, {
          ContactSetupField.channels: ContactSetupError.noChannel,
        });
      },
    );
  });

  test('acceptInquiries is carried through', () {
    expect(
      validateContactSetup(_in(call: true, acceptInquiries: false))
          .channels!
          .acceptInquiries,
      isFalse,
    );
  });
}
