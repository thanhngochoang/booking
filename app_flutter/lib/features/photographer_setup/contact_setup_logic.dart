import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

const radiusOptionsKm = [5, 10, 20, 30, 50, 100];
const defaultRadiusKm = 20;

enum ContactSetupField { city, phone, zalo, whatsapp, channels }

enum ContactSetupError {
  cityRequired,
  phoneRequired,
  phoneInvalid,
  zaloInvalid,
  whatsappInvalid,
  whatsappNeedsNumber,
  noChannel,
}

/// The raw state of the S08.05 form.
class ContactSetupInput {
  const ContactSetupInput({
    this.city = '',
    this.radiusKm = defaultRadiusKm,
    this.phone = '',
    this.call = false,
    this.zalo = false,
    this.zaloOwn = '',
    this.whatsapp = false,
    this.whatsappOwn = '',
    this.inAppOnly = false,
    this.acceptInquiries = true,
  });

  final String city;
  final int radiusKm;

  /// Text of the main `PhoneField` (national form).
  final String phone;
  final bool call;
  final bool zalo;

  /// Text of the optional own-Zalo `PhoneField` (national form).
  final String zaloOwn;
  final bool whatsapp;

  /// Text of the optional own-WhatsApp `PhoneField` (international form).
  final String whatsappOwn;

  /// "Chỉ nhận tin nhắn trong app": no outside channel, on purpose.
  final bool inAppOnly;

  /// Kept from the existing profile; S08.05 does not change it.
  final bool acceptInquiries;
}

class ContactSetupResult {
  const ContactSetupResult.invalid(this.errors)
    : area = null,
      channels = null,
      numbers = null;

  const ContactSetupResult.valid({
    required ServiceArea this.area,
    required ContactChannels this.channels,
    required ContactNumbers this.numbers,
  }) : errors = const {};

  final Map<ContactSetupField, ContactSetupError> errors;
  final ServiceArea? area;
  final ContactChannels? channels;
  final ContactNumbers? numbers;

  bool get ok => errors.isEmpty;
}

/// Validates S08.05 and builds what gets saved. Pure, so every rule is tested
/// without a widget.
ContactSetupResult validateContactSetup(ContactSetupInput i) {
  final errors = <ContactSetupField, ContactSetupError>{};

  final city = i.city.trim();
  if (city.length < 2) {
    errors[ContactSetupField.city] = ContactSetupError.cityRequired;
  }

  final phoneText = i.phone.trim();
  final phone = phoneFromField(phoneText);
  if (phoneText.isEmpty) {
    errors[ContactSetupField.phone] = ContactSetupError.phoneRequired;
  } else if (phone == null) {
    errors[ContactSetupField.phone] = ContactSetupError.phoneInvalid;
  }

  // "Only in-app" wins over any outside toggle left on.
  final call = !i.inAppOnly && i.call;
  final zalo = !i.inAppOnly && i.zalo;
  final whatsapp = !i.inAppOnly && i.whatsapp;

  String? zaloPhone;
  if (zalo) {
    final t = i.zaloOwn.trim();
    if (t.isNotEmpty) {
      final own = phoneFromField(t);
      if (own == null) {
        errors[ContactSetupField.zalo] = ContactSetupError.zaloInvalid;
      } else if (own != phone) {
        zaloPhone = own;
      }
    }
  }

  String? whatsappPhone;
  if (whatsapp) {
    final t = i.whatsappOwn.trim();
    if (t.isEmpty) {
      // Falls back to the main number. A valid Vietnamese number is always a
      // valid international one (+84…), so only a missing main number is a problem.
      if (phone == null) {
        errors[ContactSetupField.whatsapp] =
            ContactSetupError.whatsappNeedsNumber;
      }
    } else {
      final own = phoneFromField(t, international: true);
      if (own == null) {
        errors[ContactSetupField.whatsapp] = ContactSetupError.whatsappInvalid;
      } else if (own != phone) {
        whatsappPhone = own;
      }
    }
  }

  if (!i.inAppOnly && !call && !zalo && !whatsapp) {
    errors[ContactSetupField.channels] = ContactSetupError.noChannel;
  }

  if (errors.isNotEmpty || phone == null) {
    return ContactSetupResult.invalid(errors);
  }
  return ContactSetupResult.valid(
    area: ServiceArea(city: city, radiusKm: i.radiusKm),
    channels: ContactChannels(
      call: call,
      zalo: zalo,
      whatsapp: whatsapp,
      acceptInquiries: i.acceptInquiries,
    ),
    numbers: ContactNumbers(
      phone: phone,
      zaloPhone: zaloPhone,
      whatsappPhone: whatsappPhone,
    ),
  );
}
