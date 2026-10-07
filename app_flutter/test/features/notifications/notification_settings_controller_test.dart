import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/notifications/notification_settings_controller.dart';

import '../../support/notifications_world.dart';

void main() {
  test('platform errors from the permission port do not escape', () async {
    final world = NotificationsWorld();
    await world.init();
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: world.overrides,
    );
    addTearDown(c.dispose);
    c.listen(notificationSettingsControllerProvider, (_, _) {});
    await c.read(notificationSettingsControllerProvider.future);
    world.permission.failWith = StateError('platform');
    final ctrl = c.read(notificationSettingsControllerProvider.notifier);
    await ctrl.requestPermission();
    await ctrl.refreshPermission();
    expect(c.read(notificationSettingsControllerProvider).hasError, isFalse);
  });
}
