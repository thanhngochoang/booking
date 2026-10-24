import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/notifications/notification_prefs_repository.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/notifications/notification_settings_screen.dart';

import '../../support/notifications_world.dart';

/// Prefs served from the local cache (offline).
class _CachedPrefs extends FakeNotificationPrefsRepository {
  @override
  Stream<PrefsSnapshot> watch(String uid) =>
      super.watch(uid).map((s) => PrefsSnapshot(s.prefs, fromCache: true));
}

/// Never answers: the loading state.
class _HangingPrefs extends FakeNotificationPrefsRepository {
  @override
  Stream<PrefsSnapshot> watch(String uid) =>
      StreamController<PrefsSnapshot>().stream;
}

/// Answers the queued times, one per call.
class _Picker {
  final answers = <TimeOfDay?>[];
  final helps = <String>[];

  Future<TimeOfDay?> call(
    BuildContext _,
    TimeOfDay initial,
    String help,
  ) async {
    helps.add(help);
    return answers.isEmpty ? null : answers.removeAt(0);
  }
}

Future<NotificationsWorld> _open(
  WidgetTester tester, {
  UserRole role = UserRole.customer,
  NotificationPermissionStatus os = NotificationPermissionStatus.granted,
  FakeNotificationPrefsRepository? prefsRepo,
  _Picker? picker,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 390,
}) async {
  useNotificationsPhone(tester, width: width, height: 1100);
  final world = NotificationsWorld(role: role, prefsRepository: prefsRepo);
  world.permission.current = os;
  await world.init();
  await tester.pumpWidget(
    world.app(
      location: '/settings/notifications',
      brightness: brightness,
      textScale: textScale,
      extraOverrides: [
        if (picker != null) timePickerProvider.overrideWithValue(picker.call),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

Finder _switch(String category, String channel) => find.descendant(
  of: find.byKey(Key('switch-$category-$channel')),
  matching: find.byType(Switch),
);

Finder get _quietSwitch => find.descendant(
  of: find.byKey(const Key('switch-quiet')),
  matching: find.byType(Switch),
);

bool _on(WidgetTester tester, String category, String channel) =>
    tester.widget<Switch>(_switch(category, channel)).value;

ChannelPrefs _saved(NotificationsWorld w, NotificationCategory c) =>
    w.prefs.saved.last.channels[c]!;

void main() {
  testWidgets('defaults show every switch on except Khuyến mãi', (
    tester,
  ) async {
    await _open(tester);
    for (final c in ['booking', 'events', 'chat', 'badges']) {
      expect(_on(tester, c, 'push'), isTrue, reason: '$c push');
      expect(_on(tester, c, 'inApp'), isTrue, reason: '$c inApp');
    }
    expect(_on(tester, 'promo', 'push'), isFalse);
    expect(_on(tester, 'promo', 'inApp'), isFalse);
    expect(tester.widget<Switch>(_quietSwitch).value, isTrue);
    expect(
      find.text('22:00–07:00 · chỉ thông báo quan trọng vẫn có âm'),
      findsOneWidget,
    );
    // Both reminders are on.
    expect(find.text('24 giờ'), findsOneWidget);
    expect(find.text('2 giờ'), findsOneWidget);
    expect(find.text('Loại'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Trong app'), findsOneWidget);
  });

  testWidgets(
    'the jobs row is hidden while its flag is off; the Chụp ngay row is shown '
    '(#202 turned it on)',
    (tester) async {
      await _open(tester, role: UserRole.photographer);
      expect(kJobsEnabled, isFalse);
      expect(kInstantEnabled, isTrue);
      expect(find.text('Việc đăng tuyển'), findsNothing);
      expect(find.text('Chụp ngay'), findsOneWidget);
      // A photographer has both channels for Chụp ngay offers.
      expect(_switch('instant', 'push'), findsOneWidget);
      expect(_switch('instant', 'inApp'), findsOneWidget);
      for (final label in [
        'Đặt lịch và thanh toán',
        'Sự kiện',
        'Tin nhắn',
        'Huy hiệu và đánh giá',
        'Khuyến mãi',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    },
  );

  testWidgets('a customer gets only the Push switch for Chụp ngay', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Chụp ngay'), findsOneWidget);
    expect(_switch('instant', 'push'), findsOneWidget);
    expect(_switch('instant', 'inApp'), findsNothing);
  });

  testWidgets("booking Trong app is on, disabled and reads 'luôn bật'", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final world = await _open(tester);
    final sw = tester.widget<Switch>(_switch('booking', 'inApp'));
    expect(sw.value, isTrue);
    expect(sw.onChanged, isNull);
    expect(
      tester.getSemantics(find.byKey(const Key('switch-booking-inApp'))).label,
      'Đặt lịch và thanh toán, Trong app, luôn bật',
    );
    await tester.tap(_switch('booking', 'inApp'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(world.prefs.saved, isEmpty);
    handle.dispose();
  });

  testWidgets('switch semantics read "Sự kiện, Push, bật"', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('switch-events-push'))).label,
      'Sự kiện, Push, bật',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('switch-promo-inApp'))).label,
      'Khuyến mãi, Trong app, tắt',
    );
    handle.dispose();
  });

  testWidgets('a switch saves optimistically', (tester) async {
    final world = await _open(tester);
    await tester.tap(_switch('events', 'push'));
    await tester.pump();
    expect(_on(tester, 'events', 'push'), isFalse);
    await tester.pumpAndSettle();
    expect(world.prefs.saved, hasLength(1));
    final ch = _saved(world, NotificationCategory.events);
    expect((ch.push, ch.inApp), (false, true));
    expect(find.text('Không lưu được, thử lại'), findsNothing);
  });

  testWidgets("a failed save shows 'Không lưu được, thử lại' and restores the "
      'switch', (tester) async {
    final world = await _open(tester);
    world.prefs.failWith = Exception('offline');
    await tester.tap(_switch('chat', 'inApp'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được, thử lại'), findsOneWidget);
    expect(_on(tester, 'chat', 'inApp'), isTrue);
    expect(world.prefs.saved, isEmpty);
  });

  testWidgets('offline disables switches and shows the banner', (tester) async {
    await _open(tester, prefsRepo: _CachedPrefs());
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(tester.widget<Switch>(_switch('events', 'push')).onChanged, isNull);
    expect(tester.widget<Switch>(_quietSwitch).onChanged, isNull);
  });

  testWidgets('OS off shows the banner; permanently denied opens settings', (
    tester,
  ) async {
    final world = await _open(
      tester,
      os: NotificationPermissionStatus.permanentlyDenied,
    );
    expect(find.text('Thông báo đang tắt trên máy'), findsOneWidget);
    expect(
      find.text('Bạn sẽ không nhận push cho tới khi bật lại.'),
      findsOneWidget,
    );
    expect(find.text('Đang tắt trên máy'), findsOneWidget);
    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();
    expect(world.permission.settingsOpened, 1);
    expect(world.permission.requests, 0);
    // Push can still be edited while the OS is off.
    expect(
      tester.widget<Switch>(_switch('events', 'push')).onChanged,
      isNotNull,
    );
  });

  testWidgets('a denied OS asks again from the banner and registers on grant', (
    tester,
  ) async {
    final world = await _open(tester, os: NotificationPermissionStatus.denied);
    expect(find.text('Mở Cài đặt'), findsNothing);
    await tester.tap(find.text('Bật thông báo'));
    await tester.pumpAndSettle();
    expect(world.permission.requests, 1);
    expect(find.text('Thông báo đang tắt trên máy'), findsNothing);
    // The doc id is per install, so a repeated register is one record.
    expect(world.devices.registered.toSet(), {'${world.uid}:tok-1'});
  });

  testWidgets('the banner disappears after granting and resuming', (
    tester,
  ) async {
    final world = await _open(
      tester,
      os: NotificationPermissionStatus.permanentlyDenied,
    );
    expect(find.text('Thông báo đang tắt trên máy'), findsOneWidget);
    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();
    // The user turns it on in the system settings and comes back.
    world.permission.current = NotificationPermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Thông báo đang tắt trên máy'), findsNothing);
    expect(find.text('Đang tắt trên máy'), findsNothing);
  });

  testWidgets('quiet range picks from then to', (tester) async {
    final picker = _Picker()
      ..answers.addAll([
        const TimeOfDay(hour: 23, minute: 0),
        const TimeOfDay(hour: 6, minute: 30),
      ]);
    final world = await _open(tester, picker: picker);
    await tester.tap(find.byKey(const Key('quiet-range')));
    await tester.pumpAndSettle();
    expect(picker.helps, ['Yên lặng từ', 'Yên lặng đến']);
    expect(world.prefs.saved.last.quietFrom, '23:00');
    expect(world.prefs.saved.last.quietTo, '06:30');
    expect(
      find.text('23:00–06:30 · chỉ thông báo quan trọng vẫn có âm'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the second time picker saves nothing', (
    tester,
  ) async {
    final picker = _Picker()
      ..answers.addAll([const TimeOfDay(hour: 23, minute: 0), null]);
    final world = await _open(tester, picker: picker);
    await tester.tap(find.byKey(const Key('quiet-range')));
    await tester.pumpAndSettle();
    expect(world.prefs.saved, isEmpty);
  });

  testWidgets('the quiet switch turns quiet hours off', (tester) async {
    final world = await _open(tester);
    await tester.tap(_quietSwitch);
    await tester.pumpAndSettle();
    expect(world.prefs.saved.last.quietEnabled, isFalse);
  });

  testWidgets('reminder chips toggle h24 and h2', (tester) async {
    final world = await _open(tester);
    await tester.tap(find.byKey(const Key('reminder-24')));
    await tester.pumpAndSettle();
    expect(world.prefs.saved.last.reminder24, isFalse);
    expect(world.prefs.saved.last.reminder2, isTrue);
    await tester.tap(find.byKey(const Key('reminder-2')));
    await tester.pumpAndSettle();
    expect(world.prefs.saved.last.reminder24, isFalse);
    expect(world.prefs.saved.last.reminder2, isFalse);
    await tester.tap(find.byKey(const Key('reminder-24')));
    await tester.pumpAndSettle();
    expect(world.prefs.saved.last.reminder24, isTrue);
  });

  testWidgets('loading shows skeleton rows', (tester) async {
    useNotificationsPhone(tester);
    final world = NotificationsWorld(prefsRepository: _HangingPrefs());
    await world.init();
    await tester.pumpWidget(world.app(location: '/settings/notifications'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const Key('notification-settings-skeleton')),
      findsOneWidget,
    );
  });

  testWidgets('there is no primary button on this screen', (tester) async {
    await _open(tester, os: NotificationPermissionStatus.denied);
    expect(find.byType(CtaSurface), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp and 1.3× text (${brightness.name})', (tester) async {
      await _open(
        tester,
        os: NotificationPermissionStatus.denied,
        brightness: brightness,
        textScale: 1.3,
        width: 320,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Thông báo đang tắt trên máy'), findsOneWidget);
    });
  }
}
