// test/core/widgets/provider_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/widgets/provider_picker.dart';

import 'widget_host.dart';

void main() {
  testWidgets('renders MoMo and VNPay buttons and highlights selected', (
    tester,
  ) async {
    PaymentProviderCode selected = PaymentProviderCode.momo;

    await tester.pumpWidget(
      hostWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return ProviderPicker(
              value: selected,
              onChanged: (val) => setState(() => selected = val),
            );
          },
        ),
      ),
    );

    expect(find.text('MoMo'), findsOneWidget);
    expect(find.text('VNPay'), findsOneWidget);

    // Tap VNPay
    await tester.tap(find.text('VNPay'));
    await tester.pumpAndSettle();

    expect(selected, PaymentProviderCode.vnpay);
  });

  testWidgets('semantics reports button role and selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        ProviderPicker(value: PaymentProviderCode.momo, onChanged: (_) {}),
      ),
    );

    expect(
      tester.getSemantics(find.text('MoMo')),
      matchesSemantics(
        label: 'MoMo',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    expect(
      tester.getSemantics(find.text('VNPay')),
      matchesSemantics(
        label: 'VNPay',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          ProviderPicker(value: PaymentProviderCode.momo, onChanged: (_) {}),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
