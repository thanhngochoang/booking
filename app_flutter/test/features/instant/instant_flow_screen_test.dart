import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/choose_view.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_push.dart';
import '../../support/instant_customer_world.dart';

/// Decision 4: the view (screen code and label) of each status.
const _views = <InstantStatus, (String, String?)>{
  InstantStatus.choosing: (ScreenCodes.instantChoose, null),
  InstantStatus.pendingPayment: (ScreenCodes.instantChoose, null),
  InstantStatus.searching: (ScreenCodes.instantSearching, null),
  InstantStatus.assigned: (ScreenCodes.instantTracking, null),
  InstantStatus.enRoute: (ScreenCodes.instantTracking, null),
  InstantStatus.arrived: (ScreenCodes.instantTracking, null),
  InstantStatus.inProgress: (ScreenCodes.instantInProgress, null),
  InstantStatus.finished: (ScreenCodes.instantInProgress, null),
  InstantStatus.completed: (ScreenCodes.instantInProgress, 'done'),
  InstantStatus.noMatch: (ScreenCodes.instantNoMatch, null),
  InstantStatus.cancelledByCustomer: (ScreenCodes.instantCancel, 'done'),
  InstantStatus.abandoned: (ScreenCodes.instantCancel, 'done'),
  InstantStatus.noShowCustomer: (ScreenCodes.instantCancel, 'done'),
};

ScreenCode _code(WidgetTester tester) => tester.widget<ScreenCode>(
  find
      .descendant(
        of: find.byType(InstantFlowScreen),
        matching: find.byType(ScreenCode),
      )
      .first,
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(InstantFlowScreen)));

void main() {
  setUp(resetNotificationPrimerState);
  tearDown(resetNotificationPrimerState);

  test('every status has a view', () {
    expect(_views.keys.toSet(), InstantStatus.values.toSet());
  });

  for (final MapEntry(key: status, value: (code, label)) in _views.entries) {
    testWidgets('status switch shows the view of each status: ${status.code}', (
      tester,
    ) async {
      final world = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        world,
        request: customerRequestOf(status: status),
      );
      expect(_code(tester).code, code, reason: status.code);
      expect(_code(tester).label, label, reason: status.code);
      expect(
        find.byType(ChooseView),
        code == ScreenCodes.instantChoose ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('the view follows the listener (choosing → searching)', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    await pumpInstantFlow(tester, world);
    expect(_code(tester).code, ScreenCodes.instantChoose);
    world.repo.emitRequest(
      'req1',
      customerRequestOf(status: InstantStatus.searching, committed: true),
    );
    await settleInstant(tester);
    expect(_code(tester).code, ScreenCodes.instantSearching);
    expect(find.byType(ChooseView), findsNothing);
  });

  testWidgets(
    'null request (not mine / gone) shows EmptyState with "Về trang chủ"',
    (tester) async {
      final world = InstantCustomerWorld();
      final router = await pumpInstantFlow(tester, world);
      world.repo.emitRequest('req1', null);
      await settleInstant(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Không tìm thấy yêu cầu'), findsOneWidget);
      await tester.tap(find.text('Về trang chủ'));
      await settleInstant(tester);
      expect(router.state.uri.toString(), '/home');
    },
  );

  testWidgets('a listener error shows the error state with retry', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    world.repo.failRequest('req1', const InstantError('network'));
    await pumpInstantCustomer(tester, world, push: '/instant/req1');
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('a committed choice ticks once at searchDeadlineAt', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      world,
      request: customerRequestOf(
        committed: true,
        round: 2,
      ).copyWith(searchDeadlineAt: instantNow.add(const Duration(seconds: 30))),
    );
    await world.base.wait(tester, const Duration(seconds: 20));
    expect(world.repo.callsOf('tick'), isEmpty);
    await world.base.wait(tester, const Duration(seconds: 20));
    expect(world.repo.callsOf('tick'), hasLength(1));
    // Same request, same deadline: no second tick.
    await world.base.wait(tester, const Duration(minutes: 1));
    expect(world.repo.callsOf('tick'), hasLength(1));
  });

  testWidgets('a tick that fails is silent', (tester) async {
    final world = InstantCustomerWorld();
    world.repo.failNext('tick', 'network');
    await pumpInstantFlow(
      tester,
      world,
      request: customerRequestOf(status: InstantStatus.inProgress)
          .copyWith(shootEndsAt: instantNow.add(const Duration(seconds: 5))),
    );
    await world.base.wait(tester, const Duration(seconds: 10));
    expect(world.repo.callsOf('tick'), hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('back in the app ticks once', (tester) async {
    final world = InstantCustomerWorld();
    await pumpInstantFlow(tester, world);
    expect(world.repo.callsOf('tick'), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleInstant(tester);
    expect(world.repo.callsOf('tick'), hasLength(1));
  });

  testWidgets('no timer after dispose', (tester) async {
    final world = InstantCustomerWorld();
    final router = await pumpInstantFlow(
      tester,
      world,
      request: customerRequestOf(
        committed: true,
        round: 2,
      ).copyWith(searchDeadlineAt: instantNow.add(const Duration(seconds: 30))),
    );
    router.go('/home');
    await settleInstant(tester);
    await world.base.wait(tester, const Duration(minutes: 1));
    expect(world.repo.callsOf('tick'), isEmpty);
  });

  testWidgets('the primer shows after the first successful invite only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final world = InstantCustomerWorld(
      extra: [
        notificationPermissionProvider.overrideWithValue(
          FakeNotificationPermission(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    world.repo.inviteResult = const InstantInvited(
      invited: [],
      unavailable: ['p1'],
    );
    await pumpInstantFlow(tester, world);
    await tester.tap(find.byKey(const Key('swipe-like')));
    await settleInstant(tester);
    await tester.tap(find.byKey(const Key('choose-done')));
    await settleInstant(tester);
    await tester.tap(find.byKey(const Key('choose-invite')));
    await settleInstant(tester);
    expect(find.byType(PermissionPrimer), findsNothing);

    world.repo.inviteResult = const InstantInvited(
      invited: ['p1'],
      unavailable: [],
    );
    await tester.tap(find.byKey(const Key('choose-invite')));
    await settleInstant(tester);
    expect(find.byType(PermissionPrimer), findsOneWidget);
  });

  testWidgets('an ended request makes the Home card read again', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    await pumpInstantFlow(tester, world);
    final c = _container(tester);
    final sub = c.listen(instantActiveRequestIdProvider, (_, _) {});
    addTearDown(sub.close);
    await settleInstant(tester);
    expect(world.repo.callsOf('myActiveRequestId'), hasLength(1));

    world.repo.emitRequest(
      'req1',
      customerRequestOf(status: InstantStatus.cancelledByCustomer),
    );
    await settleInstant(tester);
    expect(world.repo.callsOf('myActiveRequestId'), hasLength(2));
  });
}
