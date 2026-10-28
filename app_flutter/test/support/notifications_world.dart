// test/support/notifications_world.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/badges/badge_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs_repository.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/notifications/notification_settings_screen.dart';
import 'package:photobooking/features/notifications/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'badges_world.dart';
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
    FakeNotificationPrefsRepository? prefsRepository,
    FakeNotificationPermission? permissionPort,
  }) : repo = repository ?? FakeNotificationRepository(rows),
       prefs = prefsRepository ?? FakeNotificationPrefsRepository(),
       permission =
           permissionPort ??
           FakeNotificationPermission(NotificationPermissionStatus.granted);

  final UserRole role;
  final NotificationRepository repo;
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final FakeNotificationPrefsRepository prefs;
  final push = FakePushMessaging();
  final FakeNotificationPermission permission;
  final devices = FakeDeviceRegistry();

  /// S09.01 also reads the badge chips; nobody holds a badge by default.
  final badges = FakeBadgeRepository(catalog: badgeCatalogue());

  /// S09.01's own-posts grid; empty unless a test adds posts.
  final posts = FakePostRepository();
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
    badgeRepositoryProvider.overrideWithValue(badges),
    postRepositoryProvider.overrideWithValue(posts),
  ];

  Widget app({
    String location = '/notifications',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    List<Override> extraOverrides = const [],
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
        GoRoute(
          path: '/settings/notifications',
          builder: (_, _) => const NotificationSettingsScreen(),
        ),
        for (final p in [
          '/home',
          '/b/:id',
          '/e/:id',
          '/events/:id/manage',
          '/jobs/:id',
          '/jobs/:id/applications',
          '/chat/:id',
          '/me/awards',
          '/u/:uid',
          '/u/:uid/badges',
          '/bookings',
          '/action',
          '/instant/:id',
        ])
          GoRoute(path: p, builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: [...overrides, ...extraOverrides],
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
    String? thumbUrl,
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
      thumbUrl: thumbUrl,
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
