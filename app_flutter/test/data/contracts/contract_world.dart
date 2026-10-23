// test/data/contracts/contract_world.dart
import 'dart:convert';
import 'dart:io';

import 'package:photobooking/data/photographer/photographer_contact.dart';

/// The fixture world shared with booking-be (seeded there by
/// `npm run seed:contract`; snapshot, see README.md next to it). Path is
/// relative to app_flutter/.
const contractWorldPath = 'test/data/contracts/contract-world.json';

typedef WorldBooking = ({
  String id,
  String photographerId,
  String status,
  bool unlocked,
});

class ContactWorld {
  ContactWorld._(
    this.customer,
    this.otherCustomer,
    this.photographers,
    this.bookings,
  );

  static ContactWorld load() {
    final j = jsonDecode(
      File(contractWorldPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final photographers = {
      for (final MapEntry(:key, :value)
          in (j['photographers'] as Map<String, dynamic>).entries)
        key: (
          numbers: ContactNumbers.fromMap(
            (value as Map<String, dynamic>)['numbers'] as Map<String, dynamic>,
          )!,
          channels: ContactChannels.fromMap(value['channels'])!,
        ),
    };
    final bookings = [
      for (final b in (j['bookings'] as List).cast<Map<String, dynamic>>())
        (
          id: b['id'] as String,
          photographerId: b['photographerId'] as String,
          status: b['status'] as String,
          unlocked: b['unlocked'] as bool,
        ),
    ];
    return ContactWorld._(
      j['customer'] as String,
      j['otherCustomer'] as String,
      photographers,
      bookings,
    );
  }

  final String customer;
  final String otherCustomer;
  final Map<String, ({ContactNumbers numbers, ContactChannels channels})>
  photographers;
  final List<WorldBooking> bookings;
}
