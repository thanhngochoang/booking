// lib/data/contact/contact_link_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

enum ContactSubjectType { booking, registration }

/// What a contact link is for: a booking, or an event registration (ticket).
/// The server derives the photographer, number and unlock state from it.
class ContactSubject {
  const ContactSubject.booking(this.id) : type = ContactSubjectType.booking;
  const ContactSubject.registration(this.id)
    : type = ContactSubjectType.registration;

  final String id;
  final ContactSubjectType type;

  @override
  bool operator ==(Object other) =>
      other is ContactSubject && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);
}

enum ContactLinkError {
  /// Contact is not unlocked yet (server code `contact_locked`).
  locked,

  /// Anything else: no permission, not found, channel off, network.
  unavailable,
}

class ContactLinkException implements Exception {
  const ContactLinkException(this.error);
  final ContactLinkError error;

  // Deliberately says nothing but the kind: no number can leak through logs.
  @override
  String toString() => 'ContactLinkException(${error.name})';
}

/// Port: asks the server for the one URL that opens [channel] for [subject].
/// The client never receives or stores the photographer's number itself.
abstract class ContactLinkRepository {
  /// Throws [ContactLinkException].
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  });
}

/// Payload of the callable `getContactLink`.
Map<String, Object> callableData(
  ContactSubject subject,
  ContactChannel channel,
) => {
  switch (subject.type) {
    ContactSubjectType.booking => 'bookingId',
    ContactSubjectType.registration => 'registrationId',
  }: subject.id,
  'channel': channel.code,
};

/// The URL a channel opens, from the photographer's numbers. This is the
/// reference for the server function and what the fake returns:
/// `tel:+84…`, `https://zalo.me/84…`, `https://wa.me/84…` (no plus).
Uri contactUriFor(ContactChannel channel, ContactNumbers numbers) {
  final number = numbers.numberFor(channel);
  if (number == null) {
    throw ArgumentError.value(channel, 'channel', 'has no external URL');
  }
  final digits = number.startsWith('+') ? number.substring(1) : number;
  return switch (channel) {
    ContactChannel.call => Uri(scheme: 'tel', path: number),
    ContactChannel.zalo => Uri.https('zalo.me', '/$digits'),
    ContactChannel.whatsapp => Uri.https('wa.me', '/$digits'),
    ContactChannel.inApp => throw ArgumentError.value(channel, 'channel'),
  };
}

final _e164 = RegExp(r'^\+\d{8,15}$');
final _digitsPath = RegExp(r'^/\d{8,15}$');

bool _https(Uri uri, String host) =>
    uri.scheme == 'https' &&
    uri.host == host &&
    !uri.hasPort &&
    uri.userInfo.isEmpty &&
    _digitsPath.hasMatch(uri.path);

/// The app opens a server-provided URL only when it has exactly the shape
/// built by [contactUriFor] for that channel.
bool isAllowedContactUri(Uri uri, ContactChannel channel) {
  if (uri.hasQuery || uri.hasFragment) return false;
  return switch (channel) {
    ContactChannel.call => uri.scheme == 'tel' && _e164.hasMatch(uri.path),
    ContactChannel.zalo => _https(uri, 'zalo.me'),
    ContactChannel.whatsapp => _https(uri, 'wa.me'),
    ContactChannel.inApp => false,
  };
}

/// Reads the callable's `{url: "..."}` response.
Uri parseLinkResponse(Object? data) {
  final url = data is Map ? data['url'] : null;
  final uri = url is String ? Uri.tryParse(url) : null;
  if (uri == null) {
    throw const ContactLinkException(ContactLinkError.unavailable);
  }
  return uri;
}

/// Maps the server error code (`details.code`) to what the UI needs.
ContactLinkError linkErrorFromCode(String? code) => code == 'contact_locked'
    ? ContactLinkError.locked
    : ContactLinkError.unavailable;

typedef ContactLinkRequest = ({ContactSubject subject, ContactChannel channel});

/// In-memory stand-in with the server's rules: refuses locked subjects and
/// switched-off channels, otherwise returns [contactUriFor].
class FakeContactLinkRepository implements ContactLinkRepository {
  final _subjects =
      <
        ContactSubject,
        ({ContactNumbers numbers, ContactChannels channels, bool unlocked})
      >{};

  /// Every call made, in order (channel and subject only: never a number).
  final requests = <ContactLinkRequest>[];

  void add(
    ContactSubject subject, {
    required ContactNumbers numbers,
    required ContactChannels channels,
    bool unlocked = true,
  }) => _subjects[subject] = (
    numbers: numbers,
    channels: channels,
    unlocked: unlocked,
  );

  void setUnlocked(ContactSubject subject, bool unlocked) {
    final s = _subjects[subject]!;
    _subjects[subject] = (
      numbers: s.numbers,
      channels: s.channels,
      unlocked: unlocked,
    );
  }

  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async {
    requests.add((subject: subject, channel: channel));
    final s = _subjects[subject];
    if (s == null || !channel.isExternal) {
      throw const ContactLinkException(ContactLinkError.unavailable);
    }
    if (!s.unlocked) {
      throw const ContactLinkException(ContactLinkError.locked);
    }
    if (!s.channels.external.contains(channel)) {
      throw const ContactLinkException(ContactLinkError.unavailable);
    }
    return contactUriFor(channel, s.numbers);
  }
}
