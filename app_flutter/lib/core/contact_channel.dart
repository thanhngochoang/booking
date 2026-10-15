/// A way to reach someone. `inApp` is the in-app chat; the other three leave
/// the app (phone dialer, Zalo, WhatsApp) and only open after booking.
enum ContactChannel {
  inApp('in_app'),
  call('call'),
  zalo('zalo'),
  whatsapp('whatsapp');

  const ContactChannel(this.code);

  /// Stable code used in the data model, callable payloads and analytics.
  final String code;

  bool get isExternal => this != inApp;

  static ContactChannel? fromCode(String? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Whether the outside channels may be used yet: `locked` before the customer
/// has booked (only the in-app inquiry chat), `unlocked` after.
enum ContactAccess { locked, unlocked }
