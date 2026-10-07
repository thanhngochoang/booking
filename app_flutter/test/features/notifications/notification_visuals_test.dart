import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/notifications/notification_visuals.dart';

void main() {
  test('event_host_invited needs an answer: ticket icon, action tone (O1)', () {
    final v = notificationVisualOf('event_host_invited');
    expect(v.icon, AppIcons.ticket);
    expect(v.tone, NotificationTone.action);
  });

  test('an unknown type stays an info row in the default tone', () {
    final v = notificationVisualOf('something_new');
    expect(v.icon, AppIcons.info);
    expect(v.tone, NotificationTone.neutral);
  });
}
