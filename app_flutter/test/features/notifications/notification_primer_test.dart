import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:photobooking/features/notifications/notifications_analytics.dart';

import '../../support/fake_push.dart';
import '../../support/notifications_world.dart';
import '../../support/screen_host.dart';

/// The OS dialog stays up until the test answers it.
class _HeldPermission extends FakeNotificationPermission {
  _HeldPermission(super.current);

  final answer = Completer<NotificationPermissionStatus>();

  @override
  Future<NotificationPermissionStatus> request() async {
    requests++;
    current = await answer.future;
    return current;
  }
}

class _BrokenPermission extends FakeNotificationPermission {
  @override
  Future<NotificationPermissionStatus> status() async =>
      throw StateError('no plugin');
}

/// A button that asks for notifications (twice when [twice]).
class _Host extends ConsumerWidget {
  const _Host(this.context, {this.twice = false, this.keepRegistration = true});

  final PrimerContext context;
  final bool twice;
  final bool keepRegistration;

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    // The app root keeps the registration alive; so does the host.
    if (keepRegistration) {
      ref.watch(pushRegistrationProvider);
    }
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('ask'),
          onPressed: () {
            maybeAskForNotifications(buildContext, ref, context);
            if (twice) {
              maybeAskForNotifications(buildContext, ref, context);
            }
          },
          child: const Text('hỏi'),
        ),
      ),
    );
  }
}

Future<NotificationsWorld> _mount(
  WidgetTester tester, {
  PrimerContext context = const PhotographerPrimer(),
  bool twice = false,
  bool keepRegistration = true,
  NotificationPermissionStatus os = NotificationPermissionStatus.notDetermined,
  FakeNotificationPermission? permission,
  Map<String, Object> prefsValues = const {},
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 390,
  List<Override> extra = const [],
}) async {
  useNotificationsPhone(tester, width: width);
  final world = NotificationsWorld(permissionPort: permission);
  world.permission.current = os;
  await world.init(prefsValues: prefsValues);
  await tester.pumpWidget(
    screenApp(
      home: _Host(context, twice: twice, keepRegistration: keepRegistration),
      overrides: [...world.overrides, ...extra],
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  return world;
}

Future<void> _ask(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ask')));
  await tester.pumpAndSettle();
}

int? _laterAt(NotificationsWorld w) =>
    w.sharedPrefs.getInt('notifPrimerLaterAt');

void main() {
  setUp(resetNotificationPrimerState);
  tearDown(resetNotificationPrimerState);

  testWidgets('never asked when already granted', (tester) async {
    final world = await _mount(
      tester,
      os: NotificationPermissionStatus.granted,
    );
    await _ask(tester);
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(world.permission.requests, 0);
  });

  testWidgets('never asked when permanently denied', (tester) async {
    await _mount(tester, os: NotificationPermissionStatus.permanentlyDenied);
    await _ask(tester);
    expect(find.byType(PermissionPrimer), findsNothing);
  });

  testWidgets('not asked within 7 days of Để sau, asked after', (tester) async {
    final threeDays = notificationsNow
        .subtract(const Duration(days: 3))
        .millisecondsSinceEpoch;
    await _mount(tester, prefsValues: {'notifPrimerLaterAt': threeDays});
    await _ask(tester);
    expect(find.byType(PermissionPrimer), findsNothing);

    final eightDays = notificationsNow
        .subtract(const Duration(days: 8))
        .millisecondsSinceEpoch;
    await _mount(tester, prefsValues: {'notifPrimerLaterAt': eightDays});
    await _ask(tester);
    expect(find.byType(PermissionPrimer), findsOneWidget);
  });

  testWidgets('shows the three benefits, the note and the S17.03 code', (
    tester,
  ) async {
    await _mount(tester, context: const CustomerBookingPrimer('Minh Trí'));
    await _ask(tester);
    expect(
      find.text('Bật thông báo để biết khi Minh Trí nhận lịch'),
      findsOneWidget,
    );
    expect(
      find.text('Biết ngay khi lịch được nhận hoặc thay đổi'),
      findsOneWidget,
    );
    expect(find.text('Nhắc trước giờ chụp, không lỡ hẹn'), findsOneWidget);
    expect(find.text('Tin nhắn mới khi app đang ở nền'), findsOneWidget);
    expect(
      find.text('Chọn "Để sau", chúng tôi sẽ hỏi lại sau 7 ngày.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is ScreenCode && w.code == ScreenCodes.notificationPermission,
      ),
      findsOneWidget,
    );
  });

  testWidgets('CustomerTicketPrimer shows "Bật thông báo để được nhắc trước '
      'khi Chụp phố đêm bắt đầu" and the two ticket benefits', (tester) async {
    await _mount(tester, context: const CustomerTicketPrimer('Chụp phố đêm'));
    await _ask(tester);
    expect(
      find.text('Bật thông báo để được nhắc trước khi Chụp phố đêm bắt đầu'),
      findsOneWidget,
    );
    expect(
      find.text('Nhắc trước khi sự kiện bắt đầu, kèm giờ và điểm tập trung'),
      findsOneWidget,
    );
    expect(find.text('Tin nhắn mới khi app đang ở nền'), findsOneWidget);
    // Only the two ticket benefits: not the booking ones.
    expect(
      find.text('Biết ngay khi lịch được nhận hoặc thay đổi'),
      findsNothing,
    );
    expect(find.text('Nhắc trước giờ chụp, không lỡ hẹn'), findsNothing);
    expect(
      tester.widget<PermissionPrimer>(find.byType(PermissionPrimer)).benefits,
      hasLength(2),
    );
    expect(
      find.text('Chọn "Để sau", chúng tôi sẽ hỏi lại sau 7 ngày.'),
      findsOneWidget,
    );
    expect(find.text('Bật thông báo'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
  });

  testWidgets('analytics context is customer_ticket', (tester) async {
    final events = <(String, Map<String, Object>)>[];
    await _mount(
      tester,
      context: const CustomerTicketPrimer('Chụp phố đêm'),
      extra: [
        notificationsAnalyticsProvider.overrideWithValue(
          (name, params) => events.add((name, params)),
        ),
      ],
    );
    await _ask(tester);
    expect(events.map((e) => e.$1), ['notification_primer_shown']);
    expect(events.single.$2, {'context': 'customer_ticket'});
  });

  testWidgets('the photographer title', (tester) async {
    await _mount(tester, context: const PhotographerPrimer());
    await _ask(tester);
    expect(
      find.text('Bật thông báo để không bỏ lỡ lời mời việc'),
      findsOneWidget,
    );
  });

  testWidgets('the instant title', (tester) async {
    await _mount(tester, context: const CustomerInstantPrimer());
    await _ask(tester);
    expect(
      find.text('Bật thông báo để biết khi có người nhận chụp ngay'),
      findsOneWidget,
    );
  });

  testWidgets('Để sau snoozes and asks nothing of the OS', (tester) async {
    final world = await _mount(tester);
    await _ask(tester);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(_laterAt(world), notificationsNow.millisecondsSinceEpoch);
    expect(world.permission.requests, 0);
  });

  testWidgets('dismissing by a tap outside snoozes too', (tester) async {
    final world = await _mount(tester);
    await _ask(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(_laterAt(world), notificationsNow.millisecondsSinceEpoch);
  });

  testWidgets('Back closes it like Để sau', (tester) async {
    final world = await _mount(tester);
    await _ask(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(_laterAt(world), notificationsNow.millisecondsSinceEpoch);
  });

  testWidgets("enable shows loading, then 'Đã bật thông báo' and registers the "
      'token', (tester) async {
    final held = _HeldPermission(NotificationPermissionStatus.notDetermined);
    final world = await _mount(tester, permission: held);
    await _ask(tester);
    await tester.tap(find.text('Bật thông báo'));
    await tester.pump();
    expect(
      tester.widget<PermissionPrimer>(find.byType(PermissionPrimer)).enabling,
      isTrue,
    );
    expect(
      world.devices.registered,
      isEmpty,
      reason: 'no token before the grant',
    );
    held.answer.complete(NotificationPermissionStatus.granted);
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(find.text('Đã bật thông báo'), findsOneWidget);
    expect(world.devices.registered.toSet(), {'${world.uid}:tok-1'});
  });

  testWidgets('denied closes without a message', (tester) async {
    final world = await _mount(tester);
    world.permission.onRequest = NotificationPermissionStatus.denied;
    await _ask(tester);
    await tester.tap(find.text('Bật thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(world.devices.registered, isEmpty);
    // Not asked again straight away.
    expect(_laterAt(world), notificationsNow.millisecondsSinceEpoch);
  });

  testWidgets('only one sheet at a time', (tester) async {
    await _mount(tester, twice: true);
    await _ask(tester);
    expect(find.byType(PermissionPrimer), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('waits for the caller\'s own sheet to close first', (
    tester,
  ) async {
    useNotificationsPhone(tester);
    final world = NotificationsWorld();
    world.permission.current = NotificationPermissionStatus.notDetermined;
    await world.init();
    await tester.pumpWidget(
      screenApp(
        overrides: world.overrides,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              key: const Key('ask'),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('xác nhận')),
                  ),
                );
                maybeAskForNotifications(
                  context,
                  ref,
                  const PhotographerPrimer(),
                );
              },
              child: const Text('hỏi'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.text('xác nhận'), findsOneWidget);
    expect(find.byType(PermissionPrimer), findsNothing);
    // Close the confirmation: the primer follows.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('xác nhận'), findsNothing);
    expect(find.byType(PermissionPrimer), findsOneWidget);
  });

  testWidgets('never throws when the permission plugin is missing', (
    tester,
  ) async {
    await _mount(
      tester,
      permission: _BrokenPermission(),
      keepRegistration: false,
    );
    await _ask(tester);
    expect(find.byType(PermissionPrimer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp and 1.3× text (${brightness.name})', (tester) async {
      await _mount(
        tester,
        context: const CustomerBookingPrimer('Minh Trí Nguyễn Hoàng'),
        brightness: brightness,
        textScale: 1.3,
        width: 320,
      );
      await _ask(tester);
      expect(find.byType(PermissionPrimer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
