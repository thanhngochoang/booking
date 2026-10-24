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
import 'package:photobooking/features/payment/payment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_push.dart';
import '../../support/instant_customer_world.dart';

/// Decision 4: the view (screen code and label) of each status.
const _views = <InstantStatus, (String, String?)>{
  InstantStatus.choosing: (ScreenCodes.instantChoose, null),
  InstantStatus.pendingPayment: (ScreenCodes.instantChoose, 'summary'),
  InstantStatus.searching: (ScreenCodes.instantSearching, null),
  InstantStatus.assigned: (ScreenCodes.instantTracking, null),
  InstantStatus.enRoute: (ScreenCodes.instantTracking, null),
  InstantStatus.arrived: (ScreenCodes.instantTracking, 'arrived'),
  InstantStatus.inProgress: (ScreenCodes.instantInProgress, null),
  InstantStatus.finished: (ScreenCodes.instantInProgress, 'confirm'),
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
    // The failure goes to the debug log only; keep it out of the test output.
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    try {
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
      expect(logged, ['instant tick failed: network']);
    } finally {
      debugPrint = print;
    }
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

  testWidgets(
    'an invite asks no primer; S04.04 coming back paid asks it once',
    (tester) async {
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
      // A later round (paid): the invite goes out at once, no primer (it moved
      // to after the payment, Decision 10).
      world.repo.inviteResult = const InstantInvited(
        invited: ['p1'],
        unavailable: [],
      );
      await pumpInstantFlow(
        tester,
        world,
        request: customerRequestOf(committed: true, paid: true, round: 2),
      );
      await tester.tap(find.byKey(const Key('swipe-like')));
      await settleInstant(tester);
      await tester.tap(find.byKey(const Key('choose-done')));
      await settleInstant(tester);
      await tester.tap(find.byKey(const Key('choose-invite')));
      await settleInstant(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PermissionPrimer), findsNothing);
    },
  );

  testWidgets(
    'pending_payment turning paid on this screen (bank-app return, no '
    'S04.04) asks the primer once',
    (tester) async {
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
      final router = await pumpInstantFlow(
        tester,
        world,
        request: customerRequestOf(
          status: InstantStatus.pendingPayment,
          pendingInviteIds: ['p1'],
          payMethod: PayMethod.momo,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PermissionPrimer), findsNothing);

      final paid = customerRequestOf(
        status: InstantStatus.searching,
        committed: true,
        paid: true,
      );
      world.repo.emitRequest('req1', paid);
      await settleInstant(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PermissionPrimer), findsOneWidget);
      expect(router.state.uri.toString(), '/instant/req1');

      await tester.tap(find.text('Để sau'));
      await settleInstant(tester);
      // More snapshots of the paid request ask nothing again.
      world.repo.emitRequest('req1', paid.copyWith(invitedTotal: 2));
      await settleInstant(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PermissionPrimer), findsNothing);
    },
  );

  testWidgets(
    'pending_payment resumes with Thanh toán tiếp and reuses the payment',
    (tester) async {
      final world = InstantCustomerWorld();
      // The server answers with the payment already open (same id).
      world.repo.inviteResult = InstantPaymentNeeded(
        instructions: instantInstructionsOf(paymentId: 'pay1'),
        amountVnd: 690000,
      );
      final router = await pumpInstantFlow(
        tester,
        world,
        request:
            customerRequestOf(
              status: InstantStatus.pendingPayment,
              pendingInviteIds: ['p1', 'p3'],
              payMethod: PayMethod.bankQr,
            ).copyWith(
              paymentDeadlineAt: instantNow.add(const Duration(minutes: 9)),
            ),
      );
      expect(_code(tester).code, ScreenCodes.instantChoose);
      expect(_code(tester).label, 'summary');
      final resume = find.byKey(const Key('choose-invite'));
      expect(
        find.descendant(of: resume, matching: find.text('Thanh toán tiếp')),
        findsOneWidget,
      );
      await tester.ensureVisible(resume);
      await tester.tap(resume);
      await settleInstant(tester);

      final call = world.repo.callsOf('invite').single;
      expect(call.args['photographerIds'], ['p1', 'p3']);
      expect(call.args['payMethod'], PayMethod.bankQr);
      expect(router.state.uri.toString(), '/instant/req1/pay');
      expect(find.text('PB 7K2M9Q'), findsOneWidget);
      expect(
        tester
            .widget<PaymentScreen>(find.byType(PaymentScreen))
            .initial
            ?.paymentId,
        'pay1',
      );
    },
  );

  testWidgets('app resume while pending_payment calls checkPayment once', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      world,
      request: customerRequestOf(
        status: InstantStatus.pendingPayment,
        pendingInviteIds: ['p1'],
        payMethod: PayMethod.momo,
      ),
    );
    expect(world.repo.callsOf('checkPayment'), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleInstant(tester);
    expect(world.repo.callsOf('checkPayment').single.args, {
      'requestId': 'req1',
    });
    // Not while choosing (nothing to check).
    world.repo.emitRequest('req1', customerRequestOf());
    await settleInstant(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleInstant(tester);
    expect(world.repo.callsOf('checkPayment'), hasLength(1));
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
