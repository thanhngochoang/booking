// test/core/widgets/pay_method_selector_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  Widget selector({
    PayMethod value = PayMethod.bankQr,
    ValueChanged<PayMethod>? onChanged,
    bool enabled = true,
  }) => PayMethodSelector(
    value: value,
    onChanged: onChanged ?? (_) {},
    enabled: enabled,
  );

  testWidgets('QR is a full-width row with "Miễn phí · xác nhận ngay"', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(selector()));

    expect(find.text('Chuyển khoản QR'), findsOneWidget);
    expect(find.text('Miễn phí · xác nhận ngay'), findsOneWidget);
    expect(find.byIcon(AppIcons.qrCode), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('pay-method-bank_qr'))).width, 390);
  });

  testWidgets('MoMo and ZaloPay share a row', (tester) async {
    await tester.pumpWidget(hostWidget(selector()));

    final qr = tester.getRect(find.byKey(const Key('pay-method-bank_qr')));
    final momo = tester.getRect(find.byKey(const Key('pay-method-momo')));
    final zalo = tester.getRect(find.byKey(const Key('pay-method-zalopay')));

    expect(momo.top, zalo.top);
    expect(momo.top, greaterThan(qr.bottom));
    expect(momo.width, closeTo(zalo.width, 0.5));
    expect(momo.width, lessThan(390 / 2));
    expect(zalo.left, greaterThan(momo.right));
    expect(zalo.right, 390);
    expect(find.byIcon(AppIcons.wallet), findsNWidgets(2));
    expect(find.text('MoMo'), findsOneWidget);
    expect(find.text('ZaloPay'), findsOneWidget);
  });

  testWidgets('tapping ZaloPay reports PayMethod.zaloPay', (tester) async {
    PayMethod? picked;
    await tester.pumpWidget(hostWidget(selector(onChanged: (m) => picked = m)));

    await tester.tap(find.text('ZaloPay'));
    await tester.pump();

    expect(picked, PayMethod.zaloPay);
  });

  testWidgets('disabled ignores taps', (tester) async {
    PayMethod? picked;
    await tester.pumpWidget(
      hostWidget(selector(enabled: false, onChanged: (m) => picked = m)),
    );

    await tester.tap(find.text('MoMo'));
    await tester.tap(find.text('Chuyển khoản QR'));
    await tester.pump();

    expect(picked, isNull);
  });

  testWidgets('semantics: one checked radio in the group "Phương thức thanh toán"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(selector(value: PayMethod.momo)));

    expect(find.bySemanticsLabel('Phương thức thanh toán'), findsOneWidget);

    for (final (key, checked) in [
      ('pay-method-bank_qr', false),
      ('pay-method-momo', true),
      ('pay-method-zalopay', false),
    ]) {
      expect(
        tester.getSemantics(find.byKey(Key(key))),
        matchesSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: checked,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          isFocusable: true,
          label: key == 'pay-method-bank_qr'
              ? 'Chuyển khoản QR\nMiễn phí · xác nhận ngay'
              : (key == 'pay-method-momo' ? 'MoMo' : 'ZaloPay'),
        ),
        reason: key,
      );
    }
    handle.dispose();
  });

  testWidgets('renders in light and dark, at 320dp and 1.3x text', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final method in PayMethod.values) {
        await tester.pumpWidget(
          hostWidget(
            selector(value: method),
            width: 320,
            textScale: 1.3,
            brightness: brightness,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
