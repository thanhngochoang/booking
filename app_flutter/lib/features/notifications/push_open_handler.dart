import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/push/push_messaging.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/notifications/notification_targets.dart';
import 'package:photobooking/features/notifications/notifications_screen.dart'
    show openNotificationTarget;

/// Watched by the app root. A tap on a push (app in the background, or the
/// one that started the app) marks its inbox row read and opens its target,
/// once a signed-in profile exists. Targets outside the allowlist are ignored.
final pushOpenHandlerProvider = Provider<void>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  PushOpen? waiting;
  var cancelled = false;

  void tryOpen() {
    final open = waiting;
    final profile = ref.read(currentProfileProvider).value;
    final uid = ref.read(authStateProvider).value?.uid;
    if (open == null || profile == null || profile.needsRole || uid == null) {
      return;
    }
    waiting = null;
    final id = open.notificationId;
    if (id != null) {
      unawaited(
        ref
            .read(notificationRepositoryProvider)
            .markRead(uid, [id])
            .catchError((Object _) {}),
      );
    }
    final target = safeTarget(open.target);
    if (target != null) {
      openNotificationTarget(ref.read(routerProvider), target);
    }
  }

  void receive(PushOpen open) {
    waiting = open;
    tryOpen();
  }

  final sub = messaging.opened.listen(receive);
  unawaited(
    messaging.initialOpen().then((open) {
      if (!cancelled && open != null) {
        receive(open);
      }
    }),
  );
  // A push opened before sign-in waits for the profile.
  ref.listen(currentProfileProvider, (_, _) => tryOpen());
  ref.onDispose(() {
    cancelled = true;
    unawaited(sub.cancel());
  });
});
