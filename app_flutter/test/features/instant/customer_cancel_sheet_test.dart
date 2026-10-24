import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/customer_cancel_sheet.dart';

import '../../support/instant_customer_world.dart';
import '../../support/screen_host.dart';

const _title = 'Huỷ chụp ngay?';
const _rowFree =
    'Đang chọn, đang chờ trả lời, chưa tìm được, hoặc 2 phút đầu sau khi có '
    'người nhận';
const _rowEnRoute = 'Nhiếp ảnh gia đang đến';
const _rowArrived = 'Đã đến, bạn không có mặt sau 15 phút';
const _generic = 'Chưa thực hiện được. Thử lại nhé.';

Finder get _confirm => find.byKey(const Key('customer-cancel-confirm'));
Finder get _keep => find.byKey(const Key('customer-cancel-keep'));

/// The request with Minh Trí assigned and paid by MoMo (mock S13.08).
InstantRequest _request({
  InstantStatus status = InstantStatus.enRoute,
  int arrivedSplit = 50,
  bool paid = true,
  DateTime? freeCancelUntil,
}) => customerRequestOf(status: status).copyWith(
  paid: paid,
  payMethod: PayMethod.momo,
  photographerId: 'p1',
  photographer: const InstantParty(id: 'p1', name: 'Minh Trí'),
  arrivedCancelPhotographerPercent: arrivedSplit,
  freeCancelUntil: freeCancelUntil,
);

/// A page with one button that opens S13.08 for [request].
Future<void> _open(
  WidgetTester tester,
  InstantCustomerWorld w,
  InstantRequest request, {
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  w.repo.emitRequest(request.id, request);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    screenApp(
      overrides: w.overrides,
      textScale: textScale,
      brightness: brightness,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                showCustomerCancelSheet(context, ref, request: request),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settleInstant(tester);
}

Future<void> _end(WidgetTester tester, InstantCustomerWorld w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await w.repo.dispose();
}

int _active(WidgetTester tester) =>
    tester.widget<PolicyTable>(find.byType(PolicyTable)).activeIndex;

void main() {
  testWidgets('sheet shows the dry-run amounts, not a client computation', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    // Odd numbers no client formula gives from 690.000₫ and 80%.
    w.repo.cancelQuote = const InstantCancelQuote(
      rule: InstantCancelRule.enRoute,
      refundPercent: 80,
      refundVnd: 552001,
      feeVnd: 137999,
      amountVnd: 690000,
    );
    await _open(tester, w, _request());

    expect(w.repo.callsOf('cancel').single.args, {
      'requestId': 'req1',
      'dryRun': true,
    });
    expect(find.text(_title), findsOneWidget);
    expect(
      find.text(
        'Bạn sẽ được hoàn 552.001₫; 137.999₫ là phí đi lại trả cho Minh Trí.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _confirm,
        matching: find.text('Huỷ và hoàn 552.001₫'),
      ),
      findsOneWidget,
    );
    final code = tester.widget<ScreenCode>(
      find.ancestor(of: find.text(_title), matching: find.byType(ScreenCode)),
    );
    expect(code.code, ScreenCodes.instantCancel);
    expect(code.label, isNull);
    await _end(tester, w);
  });

  testWidgets('summary: the refund bold, the fee tabular but not bold', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.cancelQuote = const InstantCancelQuote(
      rule: InstantCancelRule.enRoute,
      refundPercent: 80,
      refundVnd: 552000,
      feeVnd: 138000,
      amountVnd: 690000,
    );
    await _open(tester, w, _request());
    final line = tester.widget<Text>(
      find.text(
        'Bạn sẽ được hoàn 552.000₫; 138.000₫ là phí đi lại trả cho Minh Trí.',
      ),
    );
    final spans = {
      for (final s in (line.textSpan! as TextSpan).children!.cast<TextSpan>())
        s.text!: s.style,
    };
    const tabular = FontFeature.tabularFigures();
    expect(spans['552.000₫']?.fontWeight, FontWeight.w700);
    expect(spans['552.000₫']?.fontFeatures, contains(tabular));
    expect(spans['138.000₫']?.fontWeight, isNot(FontWeight.w700));
    expect(spans['138.000₫']?.fontFeatures, contains(tabular));
    await _end(tester, w);
  });

  for (final (rule, index, text) in [
    (InstantCancelRule.freeWindow, 0, _rowFree),
    (InstantCancelRule.fullRefund, 0, _rowFree),
    (InstantCancelRule.photographerLate, 0, _rowFree),
    (InstantCancelRule.enRoute, 1, _rowEnRoute),
    (InstantCancelRule.arrived, 2, _rowArrived),
  ]) {
    testWidgets(
      'active row follows the rule: ${rule.code} → row ${index + 1}',
      (tester) async {
        final w = InstantCustomerWorld();
        w.repo.cancelQuote = InstantCancelQuote(
          rule: rule,
          refundPercent: 100,
          refundVnd: 690000,
          amountVnd: 690000,
        );
        await _open(tester, w, _request());

        expect(_active(tester), index);
        expect(find.text('$text (bây giờ)'), findsOneWidget);
        expect(find.textContaining('(bây giờ)'), findsOneWidget);
        await _end(tester, w);
      },
    );
  }

  testWidgets(
    'row 3 reads the request split (arrivedCancelPhotographerPercent 30 → '
    '"Hoàn 70%") and the amounts come from the dry run',
    (tester) async {
      final w = InstantCustomerWorld();
      w.repo.cancelQuote = const InstantCancelQuote(
        rule: InstantCancelRule.freeWindow,
        refundPercent: 100,
        refundVnd: 690000,
        amountVnd: 690000,
      );
      await _open(tester, w, _request(arrivedSplit: 30));
      expect(
        tester
            .widget<PolicyTable>(find.byType(PolicyTable))
            .rows
            .map((r) => r.outcome),
        ['Hoàn 100%', 'Hoàn 80%', 'Hoàn 70%'],
      );
      expect(find.text('Bạn sẽ được hoàn 690.000₫.'), findsOneWidget);
      await _end(tester, w);

      // On the arrived row the percent and the amounts are the server's.
      final w2 = InstantCustomerWorld();
      w2.repo.cancelQuote = const InstantCancelQuote(
        rule: InstantCancelRule.arrived,
        refundPercent: 70,
        refundVnd: 483001,
        feeVnd: 206999,
        amountVnd: 690000,
      );
      await _open(
        tester,
        w2,
        _request(status: InstantStatus.arrived, arrivedSplit: 30),
      );
      expect(_active(tester), 2);
      expect(find.text('Hoàn 70%'), findsOneWidget);
      expect(
        find.text(
          'Bạn sẽ được hoàn 483.001₫; 206.999₫ là phí đi lại trả cho Minh Trí.',
        ),
        findsOneWidget,
      );
      expect(find.text('Huỷ và hoàn 483.001₫'), findsOneWidget);
      await _end(tester, w2);
    },
  );

  testWidgets(
    'unpaid shows "Bạn chưa thanh toán nên không có khoản tiền nào." and '
    '"Huỷ yêu cầu"',
    (tester) async {
      final w = InstantCustomerWorld();
      // The fake's default quote: `unpaid`, every #140 request.
      await _open(
        tester,
        w,
        _request(status: InstantStatus.choosing, paid: false),
      );
      expect(
        find.text('Bạn chưa thanh toán nên không có khoản tiền nào.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _confirm, matching: find.text('Huỷ yêu cầu')),
        findsOneWidget,
      );
      // No money moves: no row is "now", no refund line.
      expect(find.textContaining('(bây giờ)'), findsNothing);
      expect(find.textContaining('Bạn sẽ được hoàn'), findsNothing);
      await _end(tester, w);
    },
  );

  testWidgets('photographer_late shows the late line', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.cancelQuote = const InstantCancelQuote(
      rule: InstantCancelRule.photographerLate,
      refundPercent: 100,
      refundVnd: 690000,
      amountVnd: 690000,
    );
    await _open(tester, w, _request());
    expect(
      find.text('Minh Trí đến trễ hơn 15 phút nên bạn được hoàn đủ.'),
      findsOneWidget,
    );
    expect(find.text('Bạn sẽ được hoàn 690.000₫.'), findsOneWidget);
    expect(find.text('Huỷ và hoàn 690.000₫'), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('confirm is a red button, never the gradient', (tester) async {
    final w = InstantCustomerWorld();
    await _open(tester, w, _request(paid: false));
    expect(_confirm, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-sheet')),
        matching: find.byType(CtaSurface),
      ),
      findsNothing,
    );
    final button = tester.widget<FilledButton>(
      find.descendant(of: _confirm, matching: find.byType(FilledButton)),
    );
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      AppColors.error,
    );
    await _end(tester, w);
  });

  testWidgets('confirm calls cancel(dryRun: false) once and closes', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await _open(tester, w, _request(paid: false));
    final gate = w.repo.gate = Completer<void>();
    await tester.tap(_confirm);
    await tester.pump();
    // In flight: a second tap sends nothing more.
    await tester.tap(_confirm, warnIfMissed: false);
    await tester.pump();
    gate.complete();
    w.repo.gate = null;
    await settleInstant(tester);

    final real = w.repo
        .callsOf('cancel')
        .where((c) => c.args['dryRun'] == false);
    expect(real.single.args, {'requestId': 'req1', 'dryRun': false});
    expect(find.text(_title), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await _end(tester, w);
  });

  testWidgets('"Giữ yêu cầu" closes without a call', (tester) async {
    final w = InstantCustomerWorld();
    await _open(tester, w, _request(paid: false));
    await tester.tap(_keep);
    await settleInstant(tester);
    expect(find.text(_title), findsNothing);
    expect(w.repo.callsOf('cancel'), hasLength(1)); // the dry run only
    await _end(tester, w);
  });

  testWidgets('conflict closes with the generic error', (tester) async {
    final w = InstantCustomerWorld();
    await _open(tester, w, _request(paid: false));
    w.repo.failNext('cancel', 'conflict');
    await tester.tap(_confirm);
    await settleInstant(tester);
    expect(find.text(_title), findsNothing);
    expect(find.text(_generic), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('a dry run refused with conflict closes with the generic error', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('cancel', 'conflict');
    await _open(tester, w, _request(paid: false));
    expect(find.text(_title), findsNothing);
    expect(find.text(_generic), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('another failure keeps the sheet with the error line', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await _open(tester, w, _request(paid: false));
    w.repo.failNext('cancel', 'network');
    await tester.tap(_confirm);
    await settleInstant(tester);
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Mất kết nối. Thử lại nhé.'), findsOneWidget);
    expect(tester.widget<AppButton>(_confirm).onPressed, isNotNull);
    await _end(tester, w);
  });

  testWidgets('the quote is asked again when the free window ends', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.cancelQuote = const InstantCancelQuote(
      rule: InstantCancelRule.freeWindow,
      refundPercent: 100,
      refundVnd: 690000,
      amountVnd: 690000,
    );
    await _open(
      tester,
      w,
      _request(
        status: InstantStatus.assigned,
        freeCancelUntil: instantNow.add(const Duration(seconds: 30)),
      ),
    );
    expect(_active(tester), 0);
    w.repo.cancelQuote = const InstantCancelQuote(
      rule: InstantCancelRule.enRoute,
      refundPercent: 80,
      refundVnd: 552000,
      feeVnd: 138000,
      amountVnd: 690000,
    );
    await w.base.wait(tester, const Duration(seconds: 40));
    await settleInstant(tester);
    expect(w.repo.callsOf('cancel'), hasLength(2));
    expect(_active(tester), 1);
    expect(find.text('Huỷ và hoàn 552.000₫'), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('a status change while open asks for the quote again', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    final r = _request(paid: false);
    await _open(tester, w, r);
    // The shoot started meanwhile: the server refuses the cancel.
    w.repo.failNext('cancel', 'conflict');
    w.repo.emitRequest('req1', r.copyWith(status: InstantStatus.inProgress));
    await settleInstant(tester);
    expect(w.repo.callsOf('cancel'), hasLength(2));
    expect(find.text(_title), findsNothing);
    expect(find.text(_generic), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    for (final brightness in Brightness.values) {
      final w = InstantCustomerWorld();
      w.repo.cancelQuote = const InstantCancelQuote(
        rule: InstantCancelRule.enRoute,
        refundPercent: 80,
        refundVnd: 552000,
        feeVnd: 138000,
        amountVnd: 690000,
      );
      await _open(
        tester,
        w,
        _request(),
        width: 320,
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      // Row 1 is long: it wraps instead of being cut.
      final row1 = tester.widget<Text>(find.text(_rowFree));
      expect(row1.maxLines, isNot(1));
      expect(find.text('$_rowEnRoute (bây giờ)'), findsOneWidget);
      await _end(tester, w);
    }
  });
}
