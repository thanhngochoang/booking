import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/closed_view.dart';

import '../../support/instant_customer_world.dart';

InstantRequest _closed(
  InstantStatus status, {
  bool paid = false,
  PayMethod? method,
  int? feeVnd,
  int? refundPercent,
}) => customerRequestOf(status: status).copyWith(
  paid: paid,
  payMethod: method,
  feeVnd: feeVnd,
  refundPercent: refundPercent,
);

Future<void> _end(WidgetTester tester, InstantCustomerWorld w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await w.repo.dispose();
}

void main() {
  testWidgets(
    'cancelled paid: "Hoàn 690.000₫ về MoMo. Tiền thường về trong vài phút."',
    (tester) async {
      final w = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        w,
        request: _closed(
          InstantStatus.cancelledByCustomer,
          paid: true,
          method: PayMethod.momo,
          feeVnd: 0,
        ),
      );
      expect(find.byType(ClosedView), findsOneWidget);
      expect(find.text('Đã huỷ yêu cầu'), findsOneWidget);
      expect(
        find.text('Hoàn 690.000₫ về MoMo. Tiền thường về trong vài phút.'),
        findsOneWidget,
      );
      // The mock's bar: "Chụp ngay", nothing to go back to.
      expect(find.text('Chụp ngay'), findsOneWidget);
      expect(find.byTooltip('Quay lại'), findsNothing);
      await _end(tester, w);
    },
  );

  testWidgets('cancelled paid: the refund is amountVnd − feeVnd, both the '
      "server's", (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _closed(
        InstantStatus.cancelledByCustomer,
        paid: true,
        method: PayMethod.bankQr,
        feeVnd: 137999,
      ),
    );
    expect(
      find.text(
        'Hoàn 552.001₫ về tài khoản đã chuyển. Tiền thường về trong vài phút.',
      ),
      findsOneWidget,
    );
    await _end(tester, w);
  });

  testWidgets('cancelled unpaid: "Không có khoản tiền nào."', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _closed(InstantStatus.cancelledByCustomer),
    );
    expect(find.text('Đã huỷ yêu cầu'), findsOneWidget);
    expect(find.text('Không có khoản tiền nào.'), findsOneWidget);
    expect(find.textContaining('Hoàn '), findsNothing);
    await _end(tester, w);
  });

  testWidgets('abandoned and no-show texts', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _closed(InstantStatus.abandoned));
    expect(find.text('Yêu cầu đã hết hạn'), findsOneWidget);
    expect(
      find.text('Bạn chưa gửi lời mời trong 30 phút nên yêu cầu đã đóng.'),
      findsOneWidget,
    );

    w.repo.emitRequest(
      'req1',
      _closed(
        InstantStatus.noShowCustomer,
        paid: true,
        method: PayMethod.momo,
        feeVnd: 345001,
        refundPercent: 50,
      ),
    );
    await settleInstant(tester);
    expect(find.text('Nhiếp ảnh gia báo bạn không có mặt'), findsOneWidget);
    expect(find.text('Bạn được hoàn 344.999₫ (50%).'), findsOneWidget);

    // Unpaid (every #140 request): no money line with 0₫.
    w.repo.emitRequest('req1', _closed(InstantStatus.noShowCustomer));
    await settleInstant(tester);
    expect(find.text('Nhiếp ảnh gia báo bạn không có mặt'), findsOneWidget);
    expect(find.text('Không có khoản tiền nào.'), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('"Tạo yêu cầu mới" opens /instant', (tester) async {
    final w = InstantCustomerWorld();
    final router = await pumpInstantFlow(
      tester,
      w,
      request: _closed(InstantStatus.abandoned),
    );
    // One gradient button: "Tạo yêu cầu mới"; "Về trang chủ" is outlined.
    expect(find.byType(CtaSurface), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Tạo yêu cầu mới'),
        matching: find.byType(CtaSurface),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tạo yêu cầu mới'));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/instant');
    await _end(tester, w);
  });

  testWidgets('"Về trang chủ" opens /home', (tester) async {
    final w = InstantCustomerWorld();
    final router = await pumpInstantFlow(
      tester,
      w,
      request: _closed(InstantStatus.cancelledByCustomer),
    );
    await tester.tap(find.text('Về trang chủ'));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/home');
    await _end(tester, w);
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    for (final brightness in Brightness.values) {
      final w = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        w,
        request: _closed(
          InstantStatus.noShowCustomer,
          paid: true,
          method: PayMethod.zaloPay,
          feeVnd: 345000,
          refundPercent: 50,
        ),
        viewSize: const Size(320, 640),
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _end(tester, w);
    }
  });
}
