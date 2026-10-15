import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/firestore_notification_prefs_repository.dart';
import 'package:photobooking/data/notifications/firestore_notification_repository.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/notifications/notification_prefs_repository.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => FirestoreNotificationRepository(),
);

final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>(
      (ref) => FirestoreNotificationPrefsRepository(),
    );

/// Unread notifications of the signed-in user, live (one document listener);
/// 0 when signed out.
final unreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return Stream.value(0);
  }
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});

/// The newest notification for the S09.01 summary row. A one-shot read that
/// re-runs when the unread count changes; it never listens (Decision 12).
final latestNotificationProvider = FutureProvider.autoDispose<AppNotification?>(
  (ref) async {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return null;
    }
    ref.watch(unreadCountProvider);
    return ref.watch(notificationRepositoryProvider).latest(uid);
  },
);

/// S17.02 settings of the signed-in user, live; defaults when signed out.
final notificationPrefsProvider = StreamProvider.autoDispose<PrefsSnapshot>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return Stream.value(const PrefsSnapshot(NotificationPrefs.defaults));
  }
  return ref.watch(notificationPrefsRepositoryProvider).watch(uid);
});
