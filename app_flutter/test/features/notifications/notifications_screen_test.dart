import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/notifications/notification_settings_screen.dart';

import '../../support/notifications_world.dart';

/// Pages come back as served from the local cache (offline).
class _CachedRepository extends FakeNotificationRepository {
  _CachedRepository(super.rows);

  @override
  Stream<NotificationPage> watchFirstPage(
    String uid, {
    NotificationTab? tab,
    int limit = 30,
  }) => super
      .watchFirstPage(uid, tab: tab, limit: limit)
      .map(
        (p) => NotificationPage(items: p.items, next: p.next, fromCache: true),
      );
}

Future<NotificationsWorld> _open(
  WidgetTester tester, {
  UserRole role = UserRole.customer,
  List<AppNotification> rows = const [],
  NotificationRepository? repository,
  String location = '/notifications',
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 390,
}) async {
  useNotificationsPhone(tester, width: width);
  final world = NotificationsWorld(
    role: role,
    rows: rows,
    repository: repository,
  );
  await world.init();
  await tester.pumpWidget(
    world.app(location: location, brightness: brightness, textScale: textScale),
  );
  await tester.pumpAndSettle();
  return world;
}

int _dots(WidgetTester tester) =>
    find.byKey(const ValueKey('notification_unread_dot')).evaluate().length;

void main() {
  testWidgets('groups rows into Hôm nay, 7 ngày qua and Trước đó in Vietnam '
      'time', (tester) async {
    final w = NotificationsWorld();
    await _open(
      tester,
      rows: [
        w.note('today'),
        // 00:01 on 12/10 in Vietnam: today, though 11 hours ago.
        w.note('midnight', createdAt: DateTime.utc(2026, 10, 11, 17, 1)),
        // 23:59 on 11/10 in Vietnam: yesterday.
        w.note('yesterday', createdAt: DateTime.utc(2026, 10, 11, 16, 59)),
        w.note('old', minutesAgo: 12 * 24 * 60),
      ],
    );
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('7 ngày qua'), findsOneWidget);
    expect(find.text('Trước đó'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Hôm nay'), lessThan(y('Tiêu đề today')));
    expect(y('Tiêu đề midnight'), lessThan(y('7 ngày qua')));
    expect(y('7 ngày qua'), lessThan(y('Tiêu đề yesterday')));
    expect(y('Tiêu đề yesterday'), lessThan(y('Trước đó')));
    expect(y('Trước đó'), lessThan(y('Tiêu đề old')));
  });

  testWidgets('time labels: 5 phút, 1 giờ, Hôm qua, 12 ngày', (tester) async {
    final w = NotificationsWorld();
    await _open(
      tester,
      rows: [
        w.note('a', minutesAgo: 5),
        w.note('b', minutesAgo: 60),
        w.note('c', minutesAgo: 24 * 60),
        w.note('d', minutesAgo: 12 * 24 * 60),
      ],
    );
    expect(find.text('5 phút'), findsOneWidget);
    expect(find.text('1 giờ'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('12 ngày'), findsOneWidget);
  });

  testWidgets('photographers see Công việc, customers Đặt lịch', (
    tester,
  ) async {
    await _open(tester, role: UserRole.photographer);
    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsNothing);
    expect(find.text('Sự kiện'), findsOneWidget);
    expect(find.text('Hệ thống'), findsOneWidget);
    await _open(tester);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(find.text('Công việc'), findsNothing);
  });

  testWidgets('switching tab re-queries with that tab', (tester) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [
        w.note('a'),
        w.note(
          'e',
          type: 'event_soon',
          tab: NotificationTab.events,
          category: NotificationCategory.events,
        ),
      ],
    );
    expect(find.text('Tiêu đề a'), findsOneWidget);
    expect(find.text('Tiêu đề e'), findsOneWidget);
    await tester.tap(find.text('Sự kiện'));
    await tester.pumpAndSettle();
    expect(world.fake.calls, contains('watchFirstPage:events'));
    expect(find.text('Tiêu đề a'), findsNothing);
    expect(find.text('Tiêu đề e'), findsOneWidget);
    expect(world.fake.listeners, 1, reason: 'the old tab listener is gone');
  });

  testWidgets('one listener while open, none after pop', (tester) async {
    final world = await _open(tester, location: '/home');
    expect(world.fake.listeners, 0);
    world.router.push('/notifications');
    await tester.pumpAndSettle();
    expect(world.fake.listeners, 1);
    world.router.pop();
    await tester.pumpAndSettle();
    expect(world.fake.listeners, 0);
  });

  testWidgets('tap marks read optimistically and opens the target', (
    tester,
  ) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [
        w.note('a'),
        w.note('b', target: '/zzz'),
      ],
    );
    expect(_dots(tester), 2);
    // A row whose target is refused stays on the screen: the dot goes at once.
    await tester.tap(find.text('Tiêu đề b'));
    await tester.pump();
    expect(_dots(tester), 1);
    expect(world.fake.calls.where((c) => c.startsWith('markRead')), isEmpty);
    await tester.tap(find.text('Tiêu đề a'));
    await tester.pumpAndSettle();
    expect(find.text('stub /b/a'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(world.fake.calls, contains('markRead:b,a'));
  });

  testWidgets('three taps in a second write one batch', (tester) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [
        w.note('a', target: '/zzz'),
        w.note('b', target: '/zzz'),
        w.note('c', target: '/zzz'),
      ],
    );
    for (final id in ['a', 'b', 'c']) {
      await tester.tap(find.text('Tiêu đề $id'));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(world.fake.calls.where((c) => c.startsWith('markRead')), isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(world.fake.calls.where((c) => c.startsWith('markRead')).toList(), [
      'markRead:a,b,c',
    ]);
  });

  testWidgets('leaving flushes pending marks', (tester) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      location: '/home',
      rows: [w.note('a', target: '/zzz')],
    );
    world.router.push('/notifications');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiêu đề a'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(world.fake.calls.where((c) => c.startsWith('markRead')), isEmpty);
    world.router.pop();
    await tester.pumpAndSettle();
    expect(world.fake.calls, contains('markRead:a'));
  });

  testWidgets('mark all calls the callable and dims every row', (tester) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [w.note('a'), w.note('b'), w.note('c', read: true)],
    );
    expect(find.text('2 chưa đọc'), findsOneWidget);
    expect(_dots(tester), 2);
    await tester.tap(find.text('Đánh dấu tất cả đã đọc'));
    await tester.pumpAndSettle();
    expect(world.fake.calls, contains('markAllRead'));
    expect(_dots(tester), 0);
    expect(find.text('Đánh dấu tất cả đã đọc'), findsNothing);
  });

  testWidgets('mark all is disabled offline and the offline banner shows', (
    tester,
  ) async {
    final w = NotificationsWorld();
    await _open(tester, repository: _CachedRepository([w.note('a')]));
    expect(find.byType(OfflineBanner), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.byKey(const Key('notifications-mark-all')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('unknown target is not opened', (tester) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [w.note('a', target: 'https://evil.example/x')],
    );
    await tester.tap(find.text('Tiêu đề a'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung này không còn'), findsOneWidget);
    expect(find.textContaining('stub'), findsNothing);
    expect(
      world.router.routeInformationProvider.value.uri.path,
      '/notifications',
    );
  });

  testWidgets('gone booking shows the snack bar', (tester) async {
    final w = NotificationsWorld();
    final world = NotificationsWorld(rows: [w.note('x')]);
    world.fake.goneTargets.add('/b/x');
    await world.init();
    useNotificationsPhone(tester);
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiêu đề x'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung này không còn'), findsOneWidget);
    expect(find.text('stub /b/x'), findsNothing);
  });

  testWidgets('long press mute saves prefs and undo restores them', (
    tester,
  ) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [
        w.note(
          'm',
          type: 'chat_message',
          tab: NotificationTab.system,
          category: NotificationCategory.chat,
          target: '/chat/m',
        ),
      ],
    );
    await tester.longPress(find.text('Tiêu đề m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tắt loại thông báo này'));
    await tester.pumpAndSettle();
    expect(world.prefs.saved, hasLength(1));
    final muted = world.prefs.saved.single.channels[NotificationCategory.chat]!;
    expect(muted.push, isFalse);
    expect(muted.inApp, isFalse);
    expect(find.text('Đã tắt loại thông báo này'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(world.prefs.saved, hasLength(2));
    expect(world.prefs.current, NotificationPrefs.defaults);
  });

  testWidgets('booking rows have no mute action', (tester) async {
    final w = NotificationsWorld();
    await _open(tester, rows: [w.note('a')]);
    await tester.longPress(find.text('Tiêu đề a'));
    await tester.pumpAndSettle();
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(find.text('Tắt loại thông báo này'), findsNothing);
  });

  testWidgets('grouped row shows at most 3 avatars', (tester) async {
    final w = NotificationsWorld();
    await _open(
      tester,
      rows: [
        w.note(
          'g',
          type: 'chat_message',
          tab: NotificationTab.system,
          category: NotificationCategory.chat,
          count: 5,
          actors: [
            for (var i = 0; i < 5; i++)
              NotificationActor(id: 'u$i', name: 'Người $i'),
          ],
        ),
      ],
    );
    expect(
      find.byKey(const ValueKey('notification_group_avatar_2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('notification_group_avatar_3')),
      findsNothing,
    );
  });

  testWidgets('a grouped quote_new row shows the three avatars and opens '
      '/jobs/j1/applications', (tester) async {
    final w = NotificationsWorld();
    await _open(
      tester,
      rows: [
        w.note(
          'q',
          type: 'quote_new',
          category: NotificationCategory.jobs,
          title: '3 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”',
          body: 'Minh Trí, Lan Chi và 1 người khác. Xem và so sánh báo giá.',
          target: '/jobs/j1/applications',
          count: 3,
          actors: const [
            NotificationActor(id: 'p1', name: 'Minh Trí'),
            NotificationActor(id: 'p2', name: 'Lan Chi'),
            NotificationActor(id: 'p3', name: 'Hải'),
          ],
        ),
      ],
    );
    for (final i in [0, 1, 2]) {
      expect(
        find.byKey(ValueKey('notification_group_avatar_$i')),
        findsOneWidget,
      );
    }
    expect(find.byIcon(AppIcons.work), findsOneWidget);
    await tester.tap(find.textContaining('3 nhiếp ảnh gia'));
    await tester.pumpAndSettle();
    expect(find.text('stub /jobs/j1/applications'), findsOneWidget);
  });

  testWidgets('an event_host_invited row opens /events/e1/manage', (
    tester,
  ) async {
    final w = NotificationsWorld();
    await _open(
      tester,
      role: UserRole.photographer,
      rows: [
        w.note(
          'h',
          type: 'event_host_invited',
          tab: NotificationTab.events,
          category: NotificationCategory.events,
          target: '/events/e1/manage',
        ),
      ],
    );
    await tester.tap(find.text('Tiêu đề h'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung này không còn'), findsNothing);
    expect(find.text('stub /events/e1/manage'), findsOneWidget);
  });

  testWidgets('an event_soon row shows the cover thumbnail', (tester) async {
    final w = NotificationsWorld();
    const cover = 'https://example.test/cover.jpg';
    await _open(
      tester,
      rows: [
        w.note(
          'e',
          type: 'event_soon',
          tab: NotificationTab.events,
          category: NotificationCategory.events,
          target: '/e/e1',
          thumbUrl: cover,
        ),
      ],
    );
    await tester.tap(find.text('Sự kiện'));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.ticket), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is NetworkImage &&
            (w.image as NetworkImage).url == cover,
      ),
      findsOneWidget,
    );
  });

  testWidgets('loading shows row skeletons', (tester) async {
    await _open(tester, repository: HangingNotificationRepository());
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('notification_row_skeleton')),
      findsNWidgets(6),
    );
  });

  testWidgets('empty state action differs by role', (tester) async {
    final world = await _open(tester);
    expect(find.text('Chưa có thông báo nào'), findsOneWidget);
    expect(find.text('Khám phá nhiếp ảnh gia'), findsOneWidget);
    expect(find.text('Mở Công việc'), findsNothing);
    await tester.tap(find.text('Khám phá nhiếp ảnh gia'));
    await tester.pumpAndSettle();
    expect(find.text('stub /action'), findsOneWidget);
    expect(world.router.routeInformationProvider.value.uri.path, '/action');

    final photographer = await _open(tester, role: UserRole.photographer);
    expect(find.text('Mở Công việc'), findsOneWidget);
    expect(find.text('Khám phá nhiếp ảnh gia'), findsNothing);
    await tester.tap(find.text('Mở Công việc'));
    await tester.pumpAndSettle();
    expect(find.text('stub /bookings'), findsOneWidget);
    expect(
      photographer.router.routeInformationProvider.value.uri.path,
      '/bookings',
    );
  });

  testWidgets('a tab with no rows says which tab is empty', (tester) async {
    final w = NotificationsWorld();
    await _open(tester, rows: [w.note('a')]);
    await tester.tap(find.text('Sự kiện'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa có thông báo nào trong mục Sự kiện'),
      findsOneWidget,
    );
    expect(find.text('Khám phá nhiếp ảnh gia'), findsNothing);
  });

  testWidgets('load more appends the next page without duplicates', (
    tester,
  ) async {
    final w = NotificationsWorld();
    final world = await _open(
      tester,
      rows: [for (var i = 0; i < 35; i++) w.note('n$i', minutesAgo: 5 + i)],
    );
    final list = find.byKey(const Key('notifications-list'));
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(find.text('Tiêu đề n34'), findsOneWidget);
    expect(find.text('Tiêu đề n30'), findsOneWidget);
    expect(
      world.fake.calls.where((c) => c.startsWith('watchFirstPage')),
      hasLength(1),
    );
  });

  testWidgets('the gear opens the notification settings', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Cài đặt thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp and 1.3× text: titles wrap, body stays 2 lines '
        '(${brightness.name})', (tester) async {
      final w = NotificationsWorld();
      const longTitle =
          'Minh Trí đã nhận lịch chụp chân dung ngoài trời của bạn ở Bến Bạch Đằng';
      const longBody =
          'T7 12/10 · 15:30, Bến Bạch Đằng. Nhắn tin để chốt chi tiết, địa điểm '
          'tập trung và trang phục cho buổi chụp sắp tới của hai bên.';
      await _open(
        tester,
        rows: [
          w.note('a', title: longTitle, body: longBody),
          w.note('b', title: longTitle, body: longBody, read: true),
        ],
        brightness: brightness,
        textScale: 1.3,
        width: 320,
      );
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.text(longTitle).first);
      expect(title.maxLines, 2);
      expect(
        tester.getSize(find.text(longTitle).first).height,
        greaterThan(30),
      );
      final body = tester.widget<Text>(
        find.byKey(const ValueKey('notification_body_text')).first,
      );
      expect(body.maxLines, 2);
    });
  }
}
