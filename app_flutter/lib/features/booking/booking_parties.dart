// The other party of a booking: the customer's public profile (for the
// photographer) and the photographer's way to reach the customer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// Public `users/{uid}` profile of a booking party (name, avatar).
final partyProfileProvider = StreamProvider.autoDispose
    .family<UserProfile?, String>(
      (ref, uid) => ref.watch(userRepositoryProvider).watch(uid),
    );

/// Channels the photographer may use to reach the customer, from the
/// booking's contact copy (Decision 4): none once the copy is gone, has no
/// number or was redacted.
List<ContactChannel> copyChannels(BookingContactSnapshot? copy) {
  if (copy == null || copy.phone == null || copy.redactedAt != null) {
    return const [];
  }
  return [
    ContactChannel.call,
    if (copy.allowZalo) ContactChannel.zalo,
    if (copy.allowWhatsApp) ContactChannel.whatsapp,
  ];
}

/// Photographer → customer [ContactDial]. The rules let only this booking's
/// photographer read the copy while contact is unlocked, so the URL is built
/// here with [contactUriFor] instead of asking the server.
class CustomerContactDial extends ConsumerWidget {
  const CustomerContactDial({
    super.key,
    required this.copy,
    this.style = ContactDialStyle.labeled,
  });

  final BookingContactSnapshot? copy;
  final ContactDialStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = copyChannels(copy);
    if (channels.isEmpty) return const SizedBox.shrink();
    return ContactDial(
      access: ContactAccess.unlocked,
      channels: channels,
      style: style,
      onSelected: (channel) async {
        final phone = copy?.phone;
        if (phone == null || !channel.isExternal) return;
        final messenger = ScaffoldMessenger.of(context);
        final message = context.l10n.contactOpenError;
        var opened = false;
        try {
          final uri = contactUriFor(channel, ContactNumbers(phone: phone));
          opened = await ref.read(externalLauncherProvider).open(uri);
        } on Object {
          opened = false;
        }
        if (!opened) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
  }
}
