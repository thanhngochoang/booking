// #202: the Chụp ngay glue on V1's S04.04 (`InstantPay`): paths, inviting
// again with the waiting choice, S04.04 opened without instructions, "Tạo QR
// mới" and a payment window that closed.
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_payment.dart';
import 'package:photobooking/features/payment/qr_checkout_view.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_customer_world.dart';

InstantRequest _pending({PayMethod method = PayMethod.bankQr}) =>
    customerRequestOf(
      status: InstantStatus.pendingPayment,
      pendingInviteIds: ['p1', 'p3'],
      payMethod: method,
    );

void main() {
  test('instantRequestPath adds ?paid=1 only after a payment', () {
    expect(instantRequestPath('req1'), '/instant/req1');
    expect(instantRequestPath('req1', justPaid: true), '/instant/req1?paid=1');
  });

  test(
    'instantPayMethodOf: picked, else the waiting one, else Chuyển khoản QR',
    () {
      expect(instantPayMethodOf(customerRequestOf(), null), PayMethod.bankQr);
      expect(
        instantPayMethodOf(_pending(method: PayMethod.momo), null),
        PayMethod.momo,
      );
      expect(
        instantPayMethodOf(_pending(method: PayMethod.momo), PayMethod.zaloPay),
        PayMethod.zaloPay,
      );
    },
  );

  test(
    'inviteInstantAgain sends the waiting choice, its amount and method',
    () async {
      final repo = FakeInstantRepository();
      await inviteInstantAgain(repo, _pending(method: PayMethod.momo));
      expect(repo.callsOf('invite').single.args, {
        'requestId': 'req1',
        'photographerIds': ['p1', 'p3'],
        'skipped': <String>[],
        'expectedAmountVnd': 690000,
        'payMethod': PayMethod.momo,
      });
    },
  );

  testWidgets(
    'S04.04 opened without instructions (app reopened) invites again and '
    'shows the open payment',
    (tester) async {
      final world = InstantCustomerWorld();
      world.repo.inviteResult = InstantPaymentNeeded(
        instructions: instantInstructionsOf(),
        amountVnd: 690000,
      );
      world.repo.emitRequest('req1', _pending());
      final router = await pumpInstantCustomer(
        tester,
        world,
        push: '/instant/req1/pay',
      );
      expect(router.state.uri.toString(), '/instant/req1/pay');
      expect(world.repo.callsOf('invite').single.args['photographerIds'], [
        'p1',
        'p3',
      ]);
      expect(find.byType(QrCheckoutView), findsOneWidget);
      expect(find.text('PB 7K2M9Q'), findsOneWidget);
    },
  );

  testWidgets(
    'S04.04 opened on a request that waits on nothing goes back to it',
    (tester) async {
      final world = InstantCustomerWorld();
      world.repo.emitRequest('req1', customerRequestOf());
      final router = await pumpInstantCustomer(
        tester,
        world,
        push: '/instant/req1/pay',
      );
      expect(router.state.uri.toString(), '/instant/req1');
      expect(world.repo.callsOf('invite'), isEmpty);
    },
  );

  testWidgets('"Tạo QR mới" invites again with the same people and method', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    world.repo.emitRequest('req1', _pending());
    world.repo.inviteResult = InstantPaymentNeeded(
      instructions: instantInstructionsOf(),
      amountVnd: 690000,
    );
    final router = await pumpInstantCustomer(
      tester,
      world,
      push: '/instant/req1/pay',
    );
    expect(world.repo.callsOf('invite'), hasLength(1));

    // The QR runs out on the screen's clock.
    await world.base.wait(tester, const Duration(minutes: 16));
    world.repo.inviteResult = InstantPaymentNeeded(
      instructions: instantInstructionsOf(
        paymentId: 'pay2',
        transferCode: 'PB 9X4T2B',
      ),
      amountVnd: 690000,
    );
    final renew = find.widgetWithText(AppButton, 'Tạo QR mới');
    await tester.ensureVisible(renew);
    await tester.tap(renew);
    await settleInstant(tester);

    final again = world.repo.callsOf('invite').last.args;
    expect(again['photographerIds'], ['p1', 'p3']);
    expect(again['payMethod'], PayMethod.bankQr);
    expect(find.text('PB 9X4T2B'), findsOneWidget);
    expect(router.state.uri.toString(), '/instant/req1/pay');
  });

  testWidgets(
    'the payment window closed (back to choosing, unpaid): S04.04 returns '
    'without the paid flag',
    (tester) async {
      final world = InstantCustomerWorld();
      world.repo.emitRequest('req1', _pending());
      world.repo.inviteResult = InstantPaymentNeeded(
        instructions: instantInstructionsOf(),
        amountVnd: 690000,
      );
      final router = await pumpInstantCustomer(
        tester,
        world,
        push: '/instant/req1/pay',
      );
      expect(find.byType(QrCheckoutView), findsOneWidget);

      world.repo.emitRequest('req1', customerRequestOf());
      await settleInstant(tester);
      expect(router.state.uri.toString(), '/instant/req1');
      expect(
        tester.widget<ScreenCode>(find.byType(ScreenCode).last).code,
        ScreenCodes.instantChoose,
      );
    },
  );
}
