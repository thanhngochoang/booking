import 'package:flutter/foundation.dart';

import 'package:photobooking/data/notifications/app_notification.dart';

@immutable
class ChannelPrefs {
  const ChannelPrefs({required this.push, required this.inApp});

  final bool push;
  final bool inApp;

  @override
  bool operator ==(Object other) =>
      other is ChannelPrefs && other.push == push && other.inApp == inApp;

  @override
  int get hashCode => Object.hash(push, inApp);
}

final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// S17.02 settings, stored at `users/{uid}/private/notification_prefs`.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    required this.channels,
    required this.quietEnabled,
    required this.quietFrom,
    required this.quietTo,
    required this.reminder24,
    required this.reminder2,
  });

  /// Everything on, except promo (both off); quiet 22:00-07:00; both reminders.
  static const defaults = NotificationPrefs(
    channels: {
      NotificationCategory.booking: ChannelPrefs(push: true, inApp: true),
      NotificationCategory.jobs: ChannelPrefs(push: true, inApp: true),
      NotificationCategory.instant: ChannelPrefs(push: true, inApp: true),
      NotificationCategory.events: ChannelPrefs(push: true, inApp: true),
      NotificationCategory.chat: ChannelPrefs(push: true, inApp: true),
      NotificationCategory.badges: ChannelPrefs(push: true, inApp: true),
      NotificationCategory.promo: ChannelPrefs(push: false, inApp: false),
    },
    quietEnabled: true,
    quietFrom: '22:00',
    quietTo: '07:00',
    reminder24: true,
    reminder2: true,
  );

  final Map<NotificationCategory, ChannelPrefs> channels;
  final bool quietEnabled;
  final String quietFrom;
  final String quietTo;
  final bool reminder24;
  final bool reminder2;

  /// Lenient like the server: missing or invalid parts fall back to the
  /// defaults, and `booking.inApp` is always on.
  factory NotificationPrefs.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return defaults;
    }
    bool flag(Object? v, bool fallback) => v is bool ? v : fallback;
    final rawChannels = m['channels'] is Map
        ? m['channels'] as Map
        : const <Object?, Object?>{};
    final channels = <NotificationCategory, ChannelPrefs>{};
    for (final c in NotificationCategory.values) {
      final fallback = defaults.channels[c]!;
      final r = rawChannels[c.name];
      channels[c] = r is Map
          ? ChannelPrefs(
              push: flag(r['push'], fallback.push),
              inApp: flag(r['inApp'], fallback.inApp),
            )
          : fallback;
    }
    channels[NotificationCategory.booking] = ChannelPrefs(
      push: channels[NotificationCategory.booking]!.push,
      inApp: true,
    );
    final q = m['quietHours'] is Map
        ? m['quietHours'] as Map
        : const <Object?, Object?>{};
    final r = m['reminders'] is Map
        ? m['reminders'] as Map
        : const <Object?, Object?>{};
    String hm(Object? v, String fallback) =>
        v is String && _hhmm.hasMatch(v) ? v : fallback;
    return NotificationPrefs(
      channels: channels,
      quietEnabled: flag(q['enabled'], defaults.quietEnabled),
      quietFrom: hm(q['from'], defaults.quietFrom),
      quietTo: hm(q['to'], defaults.quietTo),
      reminder24: flag(r['h24'], defaults.reminder24),
      reminder2: flag(r['h2'], defaults.reminder2),
    );
  }

  /// All seven categories, without `updatedAt` (the repository adds it).
  Map<String, Object?> toMap() => {
    'channels': {
      for (final c in NotificationCategory.values)
        c.name: {'push': channels[c]!.push, 'inApp': channels[c]!.inApp},
    },
    'quietHours': {'enabled': quietEnabled, 'from': quietFrom, 'to': quietTo},
    'reminders': {'h24': reminder24, 'h2': reminder2},
  };

  /// Booking `inApp` stays on whatever is asked.
  NotificationPrefs withChannel(
    NotificationCategory c, {
    bool? push,
    bool? inApp,
  }) {
    final old = channels[c]!;
    final next = ChannelPrefs(
      push: push ?? old.push,
      inApp: c == NotificationCategory.booking ? true : (inApp ?? old.inApp),
    );
    return NotificationPrefs(
      channels: {...channels, c: next},
      quietEnabled: quietEnabled,
      quietFrom: quietFrom,
      quietTo: quietTo,
      reminder24: reminder24,
      reminder2: reminder2,
    );
  }

  NotificationPrefs withQuiet({bool? enabled, String? from, String? to}) =>
      NotificationPrefs(
        channels: channels,
        quietEnabled: enabled ?? quietEnabled,
        quietFrom: from ?? quietFrom,
        quietTo: to ?? quietTo,
        reminder24: reminder24,
        reminder2: reminder2,
      );

  NotificationPrefs withReminders({bool? h24, bool? h2}) => NotificationPrefs(
    channels: channels,
    quietEnabled: quietEnabled,
    quietFrom: quietFrom,
    quietTo: quietTo,
    reminder24: h24 ?? reminder24,
    reminder2: h2 ?? reminder2,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      mapEquals(other.channels, channels) &&
      other.quietEnabled == quietEnabled &&
      other.quietFrom == quietFrom &&
      other.quietTo == quietTo &&
      other.reminder24 == reminder24 &&
      other.reminder2 == reminder2;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(channels.entries.map((e) => Object.hash(e.key, e.value))),
    quietEnabled,
    quietFrom,
    quietTo,
    reminder24,
    reminder2,
  );
}

@immutable
class PrefsSnapshot {
  const PrefsSnapshot(this.prefs, {this.fromCache = false});

  final NotificationPrefs prefs;
  final bool fromCache;
}
