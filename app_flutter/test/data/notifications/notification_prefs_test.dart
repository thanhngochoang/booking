import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';

void main() {
  test('prefs fromMap fills defaults and forces booking inApp', () {
    expect(NotificationPrefs.fromMap(null), NotificationPrefs.defaults);
    expect(NotificationPrefs.fromMap({}), NotificationPrefs.defaults);

    final p = NotificationPrefs.fromMap({
      'channels': {
        'booking': {'push': false, 'inApp': false},
        'chat': {'push': false},
        'promo': 'junk',
        'unknown': {'push': true, 'inApp': true},
      },
      'quietHours': {'enabled': false, 'from': '25:00', 'to': '06:30'},
      'reminders': {'h24': false},
    });
    expect(
      p.channels[NotificationCategory.booking],
      const ChannelPrefs(push: false, inApp: true),
    );
    expect(
      p.channels[NotificationCategory.chat],
      const ChannelPrefs(push: false, inApp: true),
    );
    expect(
      p.channels[NotificationCategory.promo],
      const ChannelPrefs(push: false, inApp: false),
    );
    expect(p.quietEnabled, isFalse);
    expect(p.quietFrom, '22:00');
    expect(p.quietTo, '06:30');
    expect(p.reminder24, isFalse);
    expect(p.reminder2, isTrue);
  });

  test('withChannel cannot turn booking inApp off', () {
    final p = NotificationPrefs.defaults.withChannel(
      NotificationCategory.booking,
      push: false,
      inApp: false,
    );
    expect(
      p.channels[NotificationCategory.booking],
      const ChannelPrefs(push: false, inApp: true),
    );
    final q = p.withChannel(NotificationCategory.chat, inApp: false);
    expect(
      q.channels[NotificationCategory.chat],
      const ChannelPrefs(push: true, inApp: false),
    );
    final r = q.withChannel(NotificationCategory.promo, push: true);
    expect(
      r.channels[NotificationCategory.promo],
      const ChannelPrefs(push: true, inApp: false),
    );
  });

  test('withQuiet and withReminders change only their part', () {
    final p = NotificationPrefs.defaults
        .withQuiet(enabled: false, to: '08:00')
        .withReminders(h2: false);
    expect(p.quietEnabled, isFalse);
    expect(p.quietFrom, '22:00');
    expect(p.quietTo, '08:00');
    expect(p.reminder24, isTrue);
    expect(p.reminder2, isFalse);
  });

  test('toMap round-trips', () {
    final p = NotificationPrefs.defaults
        .withChannel(NotificationCategory.badges, push: false)
        .withQuiet(from: '23:00')
        .withReminders(h24: false);
    final m = p.toMap();
    expect(m.containsKey('updatedAt'), isFalse);
    expect(
      ((m['channels']! as Map).keys).toSet(),
      NotificationCategory.values.map((c) => c.name).toSet(),
    );
    expect(NotificationPrefs.fromMap(m), p);
  });
}
