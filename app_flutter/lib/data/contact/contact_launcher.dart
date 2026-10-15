import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';

enum ContactOpenResult {
  opened,

  /// Contact is not unlocked (`contact_locked`).
  locked,

  /// Server refused or failed, or sent a URL the app does not accept.
  unavailable,

  /// The OS found nothing to open the link with.
  cannotLaunch,
}

/// Opens a contact channel: asks the server for the URL, checks its shape,
/// hands it to the OS. It does not log, keep or return the URL, so the number
/// exists in the app only for the instant of the call.
class ContactLauncher {
  const ContactLauncher({required this.links, required this.launcher});

  final ContactLinkRepository links;
  final ExternalLauncher launcher;

  // Probes only ask "is there an app for this kind of link"; they hold no real number.
  static final _probes = {
    ContactChannel.call: Uri(scheme: 'tel', path: '+84900000000'),
    ContactChannel.zalo: Uri.https('zalo.me', '/84900000000'),
    ContactChannel.whatsapp: Uri.https('wa.me', '/84900000000'),
  };

  /// False for the in-app chat and for channels this device cannot open
  /// (a tablet without a dialer): hide those.
  Future<bool> canOpen(ContactChannel channel) async {
    final probe = _probes[channel];
    if (probe == null) return false;
    try {
      return await launcher.canOpen(probe);
    } on Object {
      return false;
    }
  }

  Future<ContactOpenResult> open(
    ContactChannel channel, {
    required ContactSubject subject,
  }) async {
    if (!channel.isExternal) {
      throw ArgumentError.value(
        channel,
        'channel',
        'is not an external channel',
      );
    }
    final Uri uri;
    try {
      uri = await links.link(subject: subject, channel: channel);
    } on ContactLinkException catch (e) {
      return e.error == ContactLinkError.locked
          ? ContactOpenResult.locked
          : ContactOpenResult.unavailable;
    } on Object {
      // The callable adapter may throw anything; never leak it to the UI.
      return ContactOpenResult.unavailable;
    }
    if (!isAllowedContactUri(uri, channel)) {
      return ContactOpenResult.unavailable;
    }
    try {
      return await launcher.open(uri)
          ? ContactOpenResult.opened
          : ContactOpenResult.cannotLaunch;
    } on Object {
      return ContactOpenResult.cannotLaunch;
    }
  }
}
