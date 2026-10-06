// test/support/notifications_world.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs_repository.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/notifications/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_push.dart';
import 'screen_host.dart';

/// 12:00 in Vietnam on Monday 12 October 2026.
final notificationsNow = DateTime.utc(2026, 10, 12, 5);

/// A repository whose first page never arrives (loading state).
class HangingNotificationRepository extends FakeNotificationRepository {
  @override
  Stream<NotificationPage> watchFirstPage(
    String uid, {
    NotificationTab? tab,
    int limit = 30,
  }) => StreamController<NotificationPage>().stream;
}

/// A signed-in user with an in-memory inbox, prefs and push ports, and the
/// routes S17.01 can open as stubs.
class NotificationsWorld {
  NotificationsWorld({
    this.role = UserRole.customer,
    List<AppNotification> rows = const [],
    NotificationRepository? repository,
  }) : repo = repository ?? FakeNotificationRepository(rows);

  final UserRole role;
  final NotificationRepository repo;
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final prefs = FakeNotificationPrefsRepository();
  final push = FakePushMessaging();
  final permission = FakeNotificationPermission(
    NotificationPermissionStatus.granted,
  );
  final devices = FakeDeviceRegistry();
  late SharedPreferences sharedPrefs;
  late String uid;
  late GoRouter router;

  FakeNotificationRepository get fake => repo as FakeNotificationRepository;

  Future<void> init({Map<String, Object> prefsValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    sharedPrefs = await SharedPreferences.getInstance();
    final u = await auth.registerWithEmail('lan@b.vn', 'password1', 'Lan Anh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
  }

  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    notificationRepositoryProvider.overrideWithValue(repo),
    notificationPrefsRepositoryProvider.overrideWithValue(prefs),
    clockProvider.overrideWithValue(() => notificationsNow),
    pushMessagingProvider.overrideWithValue(push),
    notificationPermissionProvider.overrideWithValue(permission),
    deviceRegistryProvider.overrideWithValue(devices),
  ];

  Widget app({
    String location = '/notifications',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        for (final p in [
          '/home',
          '/settings/notifications',
          '/b/:id',
          '/chat/:id',
          '/me/awards',
          '/u/:uid',
          '/u/:uid/badges',
          '/bookings',
          '/action',
        ])
          GoRoute(path: p, builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }

  /// A row of the signed-in user; `minutesAgo` counts back from
  /// [notificationsNow].
  AppNotification note(
    String id, {
    String type = 'booking_accepted',
    String? title,
    String body = 'T7 12/10 · 15:30, Bến Bạch Đằng.',
    int minutesAgo = 5,
    DateTime? createdAt,
    bool read = false,
    NotificationTab tab = NotificationTab.activity,
    NotificationCategory category = NotificationCategory.booking,
    String? target,
    List<NotificationActor> actors = const [],
    int count = 1,
  }) {
    final at =
        createdAt ?? notificationsNow.subtract(Duration(minutes: minutesAgo));
    return AppNotification(
      id: id,
      type: type,
      tab: tab,
      category: category,
      title: title ?? 'Tiêu đề $id',
      body: body,
      target: target ?? '/b/$id',
      createdAt: at,
      readAt: read ? at : null,
      actors: actors,
      count: count,
    );
  }
}

/// A tall phone so sheets and lists lay out fully.
void useNotificationsPhone(
  WidgetTester tester, {
  double width = 390,
  double height = 900,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
