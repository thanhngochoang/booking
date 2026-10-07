import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/device_registry.dart';
import 'package:photobooking/data/push/firebase_push_messaging.dart';
import 'package:photobooking/data/push/firestore_device_registry.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/permission_handler_notification_permission.dart';
import 'package:photobooking/data/push/prefs_primer_store.dart';
import 'package:photobooking/data/push/push_messaging.dart';
import 'package:photobooking/data/push/push_registration.dart';

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging(),
);

final notificationPermissionProvider = Provider<NotificationPermissionPort>(
  (ref) => const PermissionHandlerNotificationPermission(),
);

final deviceRegistryProvider = Provider<DeviceRegistry>(
  (ref) => FirestoreDeviceRegistry(prefs: ref.watch(sharedPreferencesProvider)),
);

/// S17.03 policy: never at app start, 7 days after "Để sau".
final primerPolicyProvider = Provider<PermissionPrimerPolicy>(
  (ref) => PermissionPrimerPolicy(
    store: PrefsPrimerStore(ref.watch(sharedPreferencesProvider)),
    now: ref.watch(clockProvider),
  ),
);

/// Watched by the app root: registers the token while signed in and the OS
/// permission is granted, and again on refresh. Call `.refresh()` after a
/// grant; `.signOut()` unregisters, then signs out.
final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  final reg = PushRegistration(
    messaging: ref.watch(pushMessagingProvider),
    permission: ref.watch(notificationPermissionProvider),
    devices: ref.watch(deviceRegistryProvider),
    uid: () => uid,
    signOutFromAuth: () => ref.read(authRepositoryProvider).signOut(),
  );
  if (uid != null) {
    reg.start();
  }
  ref.onDispose(reg.dispose);
  return reg;
});
