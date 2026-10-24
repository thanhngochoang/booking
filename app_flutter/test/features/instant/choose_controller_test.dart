import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/instant/choose_controller.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:photobooking/features/payment/fake_transfer_sheet.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_screen.dart';
import 'package:photobooking/features/payment/qr_checkout_view.dart';
import 'package:photobooking/features/payment/wallet_waiting_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_push.dart';
import '../../support/instant_customer_world.dart';

/// A container with `req1` in the listener and the controller held alive.
Future<(ProviderContainer, ChooseController)> _setUp(
  InstantCustomerWorld w, {
  InstantRequest? request,
}) async {
  w.repo.emitRequest('req1', request ?? customerRequestOf());
  final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  c.listen(instantRequestProvider('req1'), (_, _) {});
  c.listen(chooseControllerProvider('req1'), (_, _) {});
  await c.read(instantRequestProvider('req1').future);
  // The fake's broadcast stream is subscribed once the first value is out.
  await pumpEventQueue();
  return (c, c.read(chooseControllerProvider('req1').notifier));
}

ChooseState _state(ProviderContainer c) =>
    c.read(chooseControllerProvider('req1'));

void main() {
  test('like, skip and undo keep the counts and the order', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..skip(instantCandidates[1])
      ..like(instantCandidates[2]);
    expect(_state(c).liked, ['p1', 'p3']);
    expect(_state(c).skipped, ['p2']);
    expect(_state(c).index, 3);

    controller.undo();
    expect(_state(c).liked, ['p1']);
    expect(_state(c).index, 2);
    controller.undo();
    expect(_state(c).skipped, isEmpty);
    expect(_state(c).index, 1);

    controller.done();
    expect(_state(c).summary, isTrue);
    controller.unpick('p1');
    expect(_state(c).liked, isEmpty);
  });

  test('double tap sends one invite', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..like(instantCandidates[1])
      ..done();
    w.repo.gate = Completer<void>();
    final first = controller.send();
    final second = await controller.send();
    expect(second, isNull);
    w.repo.gate!.complete();
    expect(await first, isA<InstantInvited>());
    expect(w.repo.callsOf('invite'), hasLength(1));
  });

  test('invite sends payMethod.code', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..skip(instantCandidates[1])
      ..like(instantCandidates[2])
      ..done();
    // Chuyển khoản QR is preselected.
    expect(_state(c).method, isNull);
    expect(controller.methodOf(customerRequestOf()), PayMethod.bankQr);
    await controller.send();
    expect(w.repo.callsOf('invite').single.args, {
      'requestId': 'req1',
      'photographerIds': ['p1', 'p3'],
      'skipped': ['p2'],
      'expectedAmountVnd': 690000,
      'payMethod': PayMethod.bankQr,
    });

    controller.setMethod(PayMethod.momo);
    expect(_state(c).method, PayMethod.momo);
    await controller.send();
    final momo = w.repo.callsOf('invite').last.args['payMethod']! as PayMethod;
    expect(momo, PayMethod.momo);
    expect(momo.code, 'momo');
  });

  test('a later round (paid, committed) sends no payMethod', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(
      w,
      request: customerRequestOf(committed: true, paid: true, round: 2),
    );
    controller
      ..like(instantCandidates[0])
      ..done();
    await controller.send();
    expect(w.repo.callsOf('invite').single.args['payMethod'], isNull);
  });

  test(
    'pending_payment: send invites the waiting choice with its method',
    () async {
      final w = InstantCustomerWorld();
      final (_, controller) = await _setUp(
        w,
        request: customerRequestOf(
          status: InstantStatus.pendingPayment,
          pendingInviteIds: ['p2', 'p4'],
          payMethod: PayMethod.zaloPay,
        ),
      );
      // Nothing liked on this device (the app was reopened).
      await controller.send();
      expect(w.repo.callsOf('invite').single.args, {
        'requestId': 'req1',
        'photographerIds': ['p2', 'p4'],
        'skipped': <String>[],
        'expectedAmountVnd': 690000,
        'payMethod': PayMethod.zaloPay,
      });
    },
  );

  test(
    'a payment result is not a send: no primer from the controller',
    () async {
      final w = InstantCustomerWorld();
      final (c, controller) = await _setUp(w);
      controller
        ..like(instantCandidates[0])
        ..done();
      w.repo.inviteResult = InstantPaymentNeeded(
        instructions: instantInstructionsOf(),
        amountVnd: 690000,
      );
      final result = await controller.send();
      expect(result, isA<InstantPaymentNeeded>());
      expect(_state(c).sending, isFalse);
      // The choice stays until the request moves on.
      expect(_state(c).liked, ['p1']);
    },
  );

  test('price changed: the new amount is kept and sent next', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..done();
    w.repo.inviteResult = const InstantPriceChanged(amountVnd: 720000);
    final result = await controller.send();
    expect(result, isA<InstantPriceChanged>());
    expect(_state(c).summary, isTrue);
    expect(_state(c).sending, isFalse);
    expect(_state(c).amountVnd, 720000);

    w.repo.inviteResult = const InstantInvited(
      invited: ['p1'],
      unavailable: [],
    );
    await controller.send();
    expect(w.repo.callsOf('invite').last.args['expectedAmountVnd'], 720000);
  });

  test('a failed invite keeps the choice and records the error', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..done();
    w.repo.failNext('invite', 'network');
    expect(await controller.send(), isNull);
    expect(_state(c).sending, isFalse);
    expect(_state(c).liked, ['p1']);
    expect(_state(c).error, const InstantError('network'));
  });

  test('more() asks for the next round without the skipped people', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..skip(instantCandidates[0])
      ..skip(instantCandidates[1]);
    await controller.more();
    expect(w.repo.callsOf('nextCandidates').single.args, {
      'requestId': 'req1',
      'skipped': ['p1', 'p2'],
    });
    expect(_state(c).fetching, isFalse);
  });

  test('a new round starts a fresh choice', () async {
    final w = InstantCustomerWorld();
    final (c, controller) = await _setUp(w);
    controller
      ..like(instantCandidates[0])
      ..skip(instantCandidates[1])
      ..done();
    w.repo.emitRequest('req1', customerRequestOf(round: 2));
    await pumpEventQueue();
    expect(_state(c).liked, isEmpty);
    expect(_state(c).skipped, isEmpty);
    expect(_state(c).index, 0);
    expect(_state(c).summary, isFalse);
  });

  test('nothing chosen sends nothing', () async {
    final w = InstantCustomerWorld();
    final (_, controller) = await _setUp(w);
    expect(await controller.send(), isNull);
    expect(w.repo.callsOf('invite'), isEmpty);
  });

  group('S04.04 for InstantPay (#202)', () {
    setUp(resetNotificationPrimerState);
    tearDown(resetNotificationPrimerState);

    final invite = find.byKey(const Key('choose-invite'));

    /// ♥ on Minh Trí, "Xong", then [method] on the summary.
    Future<void> choose(WidgetTester tester, {PayMethod? method}) async {
      await tester.tap(find.byKey(const Key('swipe-like')));
      await settleInstant(tester);
      await tester.tap(find.byKey(const Key('choose-done')));
      await settleInstant(tester);
      if (method != null) {
        final picker = find.byKey(Key('pay-method-${method.name}'));
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await settleInstant(tester);
      }
    }

    /// The server's request once `inviteInstant` opened the payment.
    InstantRequest pending({PayMethod method = PayMethod.bankQr}) =>
        customerRequestOf(
          status: InstantStatus.pendingPayment,
          pendingInviteIds: ['p1'],
          payMethod: method,
        );

    /// The payment arrived: offers out, money held.
    InstantRequest paid() => customerRequestOf(
      status: InstantStatus.searching,
      committed: true,
      paid: true,
      payMethod: PayMethod.bankQr,
    ).copyWith(invitedTotal: 1, roundsWithInvites: 1);

    InstantCustomerWorld primerWorld(SharedPreferences prefs) =>
        InstantCustomerWorld(
          extra: [
            notificationPermissionProvider.overrideWithValue(
              FakeNotificationPermission(),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );

    testWidgets(
      'a payment result opens /instant/{id}/pay (S04.04) with the instructions',
      (tester) async {
        final world = InstantCustomerWorld();
        world.repo.inviteResult = InstantPaymentNeeded(
          instructions: instantInstructionsOf(),
          amountVnd: 690000,
        );
        final router = await pumpInstantFlow(tester, world);
        await choose(tester);
        await tester.tap(invite);
        world.repo.emitRequest('req1', pending());
        await settleInstant(tester);

        expect(router.state.uri.toString(), '/instant/req1/pay');
        final screen = tester.widget<PaymentScreen>(find.byType(PaymentScreen));
        expect(screen.subject, const InstantPay('req1'));
        expect(screen.initial, instantInstructionsOf());
        final code = tester.widget<ScreenCode>(find.byType(ScreenCode).last);
        expect(code.code, ScreenCodes.awaitingPayment);
        expect(code.label, 'instant');
        expect(find.byType(QrCheckoutView), findsOneWidget);
        expect(find.text('PB 7K2M9Q'), findsOneWidget);
        expect(world.repo.callsOf('invite'), hasLength(1));
      },
    );

    testWidgets(
      'S04.04 for InstantPay returns to /instant/{id} when the request leaves '
      'pending_payment and asks the primer once',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final world = primerWorld(await SharedPreferences.getInstance());
        world.repo.inviteResult = InstantPaymentNeeded(
          instructions: instantInstructionsOf(),
          amountVnd: 690000,
        );
        final router = await pumpInstantFlow(tester, world);
        await choose(tester);
        await tester.tap(invite);
        await settleInstant(tester);
        // Before the request shows pending_payment: S04.04 waits on it.
        expect(router.state.uri.toString(), '/instant/req1/pay');
        // Sending the invite asks nothing: the payment is the meaningful step.
        expect(find.byType(PermissionPrimer), findsNothing);

        world.repo.emitRequest('req1', pending());
        await settleInstant(tester);
        expect(router.state.uri.toString(), '/instant/req1/pay');
        expect(find.byType(PermissionPrimer), findsNothing);

        world.repo.emitRequest('req1', paid());
        await settleInstant(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(PermissionPrimer), findsOneWidget);
        // Back on the request; `?paid=1` consumed once the primer is asked.
        expect(router.state.uri.toString(), '/instant/req1');
        expect(
          tester.widget<ScreenCode>(find.byType(ScreenCode).first).code,
          ScreenCodes.instantSearching,
        );

        await tester.tap(find.text('Để sau'));
        await settleInstant(tester);
        expect(find.byType(PermissionPrimer), findsNothing);
        // More snapshots of the same request ask nothing again.
        world.repo.emitRequest('req1', paid().copyWith(invitedTotal: 2));
        await settleInstant(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(PermissionPrimer), findsNothing);
      },
    );

    testWidgets(
      'opened with go (as S13.01 does), S04.04 coming back paid asks the '
      'primer without another request snapshot, and only once',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final world = primerWorld(await SharedPreferences.getInstance());
        world.repo.inviteResult = InstantPaymentNeeded(
          instructions: instantInstructionsOf(),
          amountVnd: 690000,
        );
        world.repo.emitRequest('req1', customerRequestOf());
        final router = await pumpInstantCustomer(tester, world, push: null);
        // S13.01's submit: `context.go('/instant/$id')`.
        router.go('/instant/req1');
        await settleInstant(tester);
        await choose(tester);
        await tester.tap(invite);
        world.repo.emitRequest('req1', pending());
        await settleInstant(tester);
        expect(router.state.uri.toString(), '/instant/req1/pay');

        // The money arrives: S04.04 sees it and goes back; this is the last
        // snapshot of the request.
        world.repo.emitRequest('req1', paid());
        await settleInstant(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(PermissionPrimer), findsOneWidget);
        // `?paid=1` is consumed once the primer is asked.
        expect(router.state.uri.toString(), '/instant/req1');

        await tester.tap(find.text('Để sau'));
        await settleInstant(tester);
        expect(find.byType(PermissionPrimer), findsNothing);
        // The same location with the flag again (a stale link) asks nothing.
        router.go('/instant/req1?paid=1');
        await settleInstant(tester);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(PermissionPrimer), findsNothing);
      },
    );

    testWidgets(
      "a wallet in fake mode confirms through S04.04's FakeTransferSheet → "
      'PaymentsRepository.confirmFake (outcome paid)',
      (tester) async {
        final world = InstantCustomerWorld();
        final inst = instantInstructionsOf(method: PayMethod.momo);
        world.repo.inviteResult = InstantPaymentNeeded(
          instructions: inst,
          amountVnd: 690000,
        );
        world.payments.onConfirm = (paymentId, kind) async {
          world.repo.emitRequest('req1', paid());
        };
        final router = await pumpInstantFlow(tester, world);
        await choose(tester, method: PayMethod.momo);
        await tester.tap(invite);
        world.repo.emitRequest('req1', pending(method: PayMethod.momo));
        await settleInstant(tester);

        expect(
          world.repo.callsOf('invite').single.args['payMethod'],
          PayMethod.momo,
        );
        expect(router.state.uri.toString(), '/instant/req1/pay');
        expect(find.byType(WalletWaitingView), findsOneWidget);
        // Fake mode: the wallet link is not launched.
        expect(world.base.launcher.opened, isEmpty);

        await tester.tap(find.text('Giả lập chuyển khoản'));
        await settleInstant(tester);
        expect(find.byType(FakeTransferSheet), findsOneWidget);
        await tester.tap(find.text('Chuyển đúng'));
        await settleInstant(tester);
        await tester.pump(const Duration(milliseconds: 300));

        // "Chuyển đúng" = an exact transfer: the fake bank answers `paid`.
        expect(world.payments.confirms, [('pay1', FakeTransferKind.exact)]);
        expect(router.state.uri.toString(), '/instant/req1');
        expect(
          tester.widget<ScreenCode>(find.byType(ScreenCode).last).code,
          ScreenCodes.instantSearching,
        );
      },
    );
  });
}
