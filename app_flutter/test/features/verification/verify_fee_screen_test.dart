// test/features/verification/verify_fee_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/features/payment/qr_checkout_view.dart';
import 'package:photobooking/features/payment/wallet_waiting_view.dart';

import '../../support/verification_world.dart';

/// Today 9:12 in Vietnam.
final _at = DateTime.utc(2026, 10, 15, 2, 12);

/// An `in_progress` record with the phone done and the fee open.
Map<String, dynamic> _doc() => {
  'uid': 'u',
  'status': 'in_progress',
  'kind': 'individual',
  'feeAttempt': 1,
  'steps': {
    'phone': {'doneAt': _at},
  },
  'freeResubmitsLeft': 1,
};

Future<VerificationWorld> _world(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  ProviderType type = ProviderType.individual,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = VerificationWorld(startScreen: true, feeRequired: true);
  await w.init();
  w.seedIntro(PhotographerIntro(providerType: type));
  w.seedDoc(_doc());
  return w;
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester tester,
  VerificationWorld w, {
  String location = '/verify/start/fee',
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(w.app(location: location, textScale: textScale));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

/// Labels of the primary (gradient) buttons on screen.
List<String> _primaryLabels(WidgetTester tester) => [
  for (final b in tester.widgetList<AppButton>(
    find.ancestor(
      of: find.byType(CtaSurface),
      matching: find.byType(AppButton),
    ),
  ))
    b.label,
];

PayMethod _selected(WidgetTester tester) =>
    tester.widget<PayMethodSelector>(find.byType(PayMethodSelector)).value;

List<String> _callNames(VerificationWorld w) => [
  for (final c in w.repo.calls) c.name,
];

const _pay = 'Thanh toán 99.000₫';

void main() {
  testWidgets('matches the mock: benefits, amount, kind line, no-refund note; '
      'Chuyển khoản QR is selected by default', (tester) async {
    final w = await _world(tester);
    await _open(tester, w);

    expect(find.text('Phí xác minh'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Bạn nhận được'), findsOneWidget);
    expect(find.text('Tích xanh cạnh tên trên hồ sơ'), findsOneWidget);
    expect(find.text('Nhận đơn đặt lịch và gửi báo giá'), findsOneWidget);
    expect(find.text('Staff duyệt trong 24 giờ'), findsOneWidget);
    expect(find.text('99.000₫'), findsOneWidget);
    expect(find.text('Thợ ảnh cá nhân · studio 299.000₫'), findsOneWidget);
    expect(
      find.text(
        'Phí không hoàn vì chi phí kiểm tra đã phát sinh; bị từ chối được gửi '
        'lại miễn phí 1 lần.',
      ),
      findsOneWidget,
    );
    expect(find.text('Chuyển khoản QR'), findsOneWidget);
    expect(find.text('Miễn phí · xác nhận ngay'), findsOneWidget);
    expect(find.text('MoMo'), findsOneWidget);
    expect(find.text('ZaloPay'), findsOneWidget);
    expect(_selected(tester), PayMethod.bankQr);
    expect(_primaryLabels(tester), [_pay]);
    // Mock order: benefits, amount, note, methods.
    final ys = [
      for (final t in [
        'Bạn nhận được',
        '99.000₫',
        'Thợ ảnh cá nhân · studio 299.000₫',
        'Chuyển khoản QR',
      ])
        tester.getTopLeft(find.text(t)).dy,
    ];
    expect([...ys]..sort(), ys);
  });

  testWidgets('a studio pays 299.000₫ with the individual alternative', (
    tester,
  ) async {
    final w = await _world(tester, type: ProviderType.studio);
    await _open(tester, w);

    expect(find.text('299.000₫'), findsOneWidget);
    expect(find.text('Studio · thợ ảnh cá nhân 99.000₫'), findsOneWidget);
    expect(_primaryLabels(tester), ['Thanh toán 299.000₫']);
  });

  testWidgets('Thanh toán 99.000₫ starts the fee with bank_qr, momo or '
      'zalopay as chosen', (tester) async {
    for (final method in PayMethod.values) {
      final w = await _world(tester);
      await _open(tester, w);
      if (method != PayMethod.bankQr) {
        await _tap(tester, find.byKey(Key('pay-method-${method.code}')));
        expect(_selected(tester), method);
      }
      await _tap(tester, find.text(_pay));
      expect(_callNames(w), ['startVerificationFee'], reason: method.code);
      expect(w.repo.calls.single.data, {'method': method.code});
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('bank_qr opens /verify/start/fee/pay with the VietQR '
      'instructions', (tester) async {
    final w = await _world(tester);
    await _open(tester, w);
    await _tap(tester, find.text(_pay));

    expect(w.router.state.uri.path, '/verify/start/fee/pay');
    expect(find.byType(QrCheckoutView), findsOneWidget);
    final issued = w.repo.lastFeeInstructions!;
    expect(issued.method, PayMethod.bankQr);
    expect(find.text(issued.transferCode), findsWidgets);
    expect(find.text('99.000₫'), findsWidgets);
    expect(find.text('Phí xác minh'), findsWidgets);
  });

  testWidgets('Tạo QR mới on the fee S04.04 starts the fee again with renew', (
    tester,
  ) async {
    final w = await _world(tester);
    await _open(tester, w);
    await _tap(tester, find.text(_pay));
    final first = w.repo.lastFeeInstructions!;

    await _tap(tester, find.text('Tạo QR mới'));
    expect(w.repo.calls.last.name, 'startVerificationFee');
    expect(w.repo.calls.last.data, {'method': 'bank_qr', 'renew': true});
    final renewed = w.repo.lastFeeInstructions!;
    expect(renewed.paymentId, isNot(first.paymentId));
    expect(find.text(renewed.transferCode), findsWidgets);
    expect(find.text(first.transferCode), findsNothing);
  });

  testWidgets('S04.04 for the fee goes back to /verify/start when the fee '
      'step becomes done', (tester) async {
    final w = await _world(tester);
    await _open(tester, w, location: '/profile');
    w.router.push('/verify/start');
    await _settle(tester);
    await _tap(tester, find.byKey(const Key('verify-next')));
    expect(w.router.state.uri.path, '/verify/start/fee');
    await _tap(tester, find.text(_pay));
    expect(w.router.state.uri.path, '/verify/start/fee/pay');

    // The server settles the transfer: the record gains steps.fee.
    w.repo.settleFee(w.repo.lastFeeInstructions!.paymentId);
    await _settle(tester);

    expect(w.router.state.uri.path, '/verify/start');
    expect(find.text('Đã nhận phí xác minh'), findsOneWidget);
    expect(find.text('Đã trả 99.000₫'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
    // S21.02 kept its own back stack.
    expect(w.router.canPop(), isTrue);
    w.router.pop();
    await _settle(tester);
    expect(w.router.state.uri.path, '/profile');
  });

  testWidgets("a wallet in fake mode goes to S04.04's waiting view and "
      'confirmFake pays it', (tester) async {
    final w = await _world(tester);
    w.payments.onConfirm = (paymentId, _) async => w.repo.settleFee(paymentId);
    await _open(tester, w, location: '/verify/start');
    await _tap(tester, find.byKey(const Key('verify-next')));
    await _tap(tester, find.byKey(const Key('pay-method-momo')));
    await _tap(tester, find.text(_pay));

    expect(w.router.state.uri.path, '/verify/start/fee/pay');
    expect(find.byType(WalletWaitingView), findsOneWidget);
    expect(find.text('Đang chờ xác nhận'), findsOneWidget);
    // Fake payments: no wallet app is launched.
    expect(w.launcher.opened, isEmpty);

    await _tap(tester, find.text('Giả lập chuyển khoản'));
    await _tap(tester, find.text('Chuyển đúng'));
    final paymentId = w.repo.lastFeeInstructions!.paymentId;
    expect(w.payments.confirms, [(paymentId, FakeTransferKind.exact)]);
    expect(w.router.state.uri.path, '/verify/start');
    expect(find.text('Đã trả 99.000₫'), findsOneWidget);
  });

  testWidgets('a failure shows verifyFeeFailed and keeps the method', (
    tester,
  ) async {
    final w = await _world(tester);
    await _open(tester, w);
    await _tap(tester, find.byKey(const Key('pay-method-zalopay')));
    w.repo.failWith = 'not_eligible';
    await _tap(tester, find.text(_pay));

    expect(find.text('Chưa thanh toán được. Thử lại.'), findsOneWidget);
    expect(_selected(tester), PayMethod.zaloPay);
    expect(w.router.state.uri.path, '/verify/start/fee');
    expect(_primaryLabels(tester), [_pay]);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    final w = await _world(
      tester,
      width: 320,
      height: 640,
      type: ProviderType.studio,
    );
    await _open(tester, w, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(_primaryLabels(tester), ['Thanh toán 299.000₫']);
  });
}
