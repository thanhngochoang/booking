// lib/features/contact/contact_action.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';

/// Hook for analytics. There is no analytics layer yet, so screens pass
/// their own; params never contain a phone number.
typedef ContactEventLogger = void Function(
  String name,
  Map<String, Object?> params,
);

/// S32 behaviour around [ContactDial]: hides channels the device cannot open,
/// asks [ContactLauncher] for the link and opens it, shows a spinner while
/// waiting and a message when it fails.
class ContactAction extends ConsumerStatefulWidget {
  const ContactAction({
    super.key,
    required this.access,
    required this.channels,
    required this.source,
    this.subject,
    this.style = ContactDialStyle.icon,
    this.onInquiry,
    this.onEvent,
  }) : assert(
         access == ContactAccess.locked || subject != null,
         'an unlocked dial needs the booking or registration it belongs to',
       );

  final ContactAccess access;
  final List<ContactChannel> channels;

  /// Screen code that hosts the button (`S03`, `S09`, `S16`, ...), for analytics.
  final String source;

  /// The booking or registration that unlocked contact.
  final ContactSubject? subject;
  final ContactDialStyle style;

  /// Opens the in-app inquiry chat (locked mode).
  final VoidCallback? onInquiry;
  final ContactEventLogger? onEvent;

  @override
  ConsumerState<ContactAction> createState() => _ContactActionState();
}

class _ContactActionState extends ConsumerState<ContactAction> {
  Set<ContactChannel> _blocked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void didUpdateWidget(ContactAction old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.channels, widget.channels)) _probe();
  }

  Future<void> _probe() async {
    final launcher = ref.read(contactLauncherProvider);
    final blocked = <ContactChannel>{};
    for (final c in widget.channels.where((c) => c.isExternal)) {
      if (!await launcher.canOpen(c)) blocked.add(c);
    }
    if (mounted) setState(() => _blocked = blocked);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _select(ContactChannel channel) async {
    widget.onEvent?.call('contact_tapped', {
      'channel': channel.code,
      'source': widget.source,
    });
    if (channel == ContactChannel.inApp) {
      widget.onInquiry?.call();
      return;
    }
    final subject = widget.subject;
    if (subject == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(contactLauncherProvider)
        .open(channel, subject: subject);
    if (!mounted) return;
    setState(() => _busy = false);
    final l = context.l10n;
    switch (result) {
      case ContactOpenResult.opened:
        break;
      case ContactOpenResult.locked:
        widget.onEvent?.call('contact_locked', {'source': widget.source});
        _say(l.contactLockedHint);
      case ContactOpenResult.unavailable:
      case ContactOpenResult.cannotLaunch:
        _say(l.contactOpenError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContactDial(
      access: widget.access,
      channels: [
        for (final c in widget.channels)
          if (!_blocked.contains(c)) c,
      ],
      busy: _busy,
      style: widget.style,
      onSelected: _select,
    );
  }
}

/// [ContactAction] fed from a photographer's public contact flags.
class PhotographerContactAction extends ConsumerWidget {
  const PhotographerContactAction({
    super.key,
    required this.photographerId,
    required this.access,
    required this.source,
    this.subject,
    this.style = ContactDialStyle.icon,
    this.onInquiry,
    this.onEvent,
  });

  final String photographerId;
  final ContactAccess access;
  final String source;
  final ContactSubject? subject;
  final ContactDialStyle style;
  final VoidCallback? onInquiry;
  final ContactEventLogger? onEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(photographerChannelsProvider(photographerId)).value;
    final List<ContactChannel> channels;
    if (access == ContactAccess.unlocked) {
      channels = flags?.external ?? const [];
    } else {
      channels = (flags?.acceptInquiries ?? true)
          ? const [ContactChannel.inApp]
          : const [];
    }
    if (channels.isEmpty) return const SizedBox.shrink();
    return ContactAction(
      access: access,
      channels: channels,
      subject: subject,
      source: source,
      style: style,
      onInquiry: onInquiry,
      onEvent: onEvent,
    );
  }
}
