import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/features/earnings/widgets/account_inputs.dart';
import 'package:photobooking/features/payments/refund_account_sheet.dart';

import '../../support/fake_payments_repository.dart';
import '../../support/screen_host.dart';

const _subject = BookingRefund('b1');

/// 10:00 25/10 in Vietnam; the 24-hour default fires at 10:00 26/10.
final _now = DateTime.utc(2026, 10, 25, 3);
final _confirmBy = DateTime.utc(2026, 10, 26, 3);

const RefundPayerAccount _payer = (
  bankName: 'Vietcombank',
  accountLast4: '6789',
  holderName: 'NGUYEN THANH HA',
);

PendingRefund _pending({bool payer = true}) => PendingRefund(
  refundId: 'r1',
  amount: 1500000,
  payer: payer ? _payer : null,
  confirmBy: payer ? _confirmBy : null,
);

final _sheet = find.byKey(const Key('app-sheet'));

Finder _inSheet(Finder f) => find.descendant(of: _sheet, matching: f);

Finder get _confirm =>
    _inSheet(find.widgetWithText(AppButton, 'Hoàn về tài khoản này'));

bool _confirmEnabled(WidgetTester tester) =>
    tester.widget<AppButton>(_confirm).onPressed != null;

/// Sheets animate: pump a bounded second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Hosts a page whose button opens S22.04 for [_subject] and taps it.
Future<FakePaymentsRepository> _open(
  WidgetTester tester, {
  PendingRefund? pending,
  bool seed = true,
  double width = 390,
  double textScale = 1,
  DateTime? now,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final payments = FakePaymentsRepository();
  if (seed) payments.pendingBySubject[_subject] = pending ?? _pending();
  final clock = now ?? _now;
  await tester.pumpWidget(
    screenApp(
      textScale: textScale,
      overrides: [
        paymentsRepositoryProvider.overrideWithValue(payments),
        clockProvider.overrideWithValue(() => clock),
      ],
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showRefundAccountSheet(context, ref, _subject),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return payments;
}

Future<void> _useOther(WidgetTester tester) async {
  await tester.tap(_inSheet(find.text('Dùng tài khoản khác')));
  await _settle(tester);
}

/// Picks [code] in the bank list and types [number].
Future<void> _fill(WidgetTester tester, String code, String number) async {
  await tester.tap(_inSheet(find.byType(BankField)));
  await _settle(tester);
  await tester.tap(find.byKey(Key('bank-$code')));
  await _settle(tester);
  await tester.enterText(find.byKey(const Key('refund-number')), number);
  await tester.pump();
}

Future<void> _lookup(WidgetTester tester) async {
  final button = _inSheet(
    find.widgetWithText(AppButton, 'Tra tên chủ tài khoản'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester);
}

void main() {
  testWidgets('shows amount and the paying account "Vietcombank •••• 6789 · '
      'NGUYEN THANH HA"', (tester) async {
    final payments = await _open(tester);

    expect(payments.pendingCalls, [_subject]);
    expect(_sheet, findsOneWidget);
    expect(
      _inSheet(
        find.byWidgetPredicate(
          (w) => w is ScreenCode && w.code == ScreenCodes.refundAccount,
        ),
      ),
      findsOneWidget,
    );
    expect(_inSheet(find.text('Tài khoản nhận hoàn')), findsOneWidget);
    expect(_inSheet(find.byTooltip('Đóng')), findsOneWidget);
    expect(_inSheet(find.text('Bạn được hoàn')), findsOneWidget);
    expect(_inSheet(find.text('1.500.000₫')), findsOneWidget);
    expect(
      _inSheet(find.text('Tiền hoàn về tài khoản đã chuyển:')),
      findsOneWidget,
    );
    expect(_inSheet(find.text('Vietcombank •••• 6789')), findsOneWidget);
    expect(_inSheet(find.text('NGUYEN THANH HA')), findsOneWidget);
    // The bank's short code in the logo slot (`VnBank`).
    expect(_inSheet(find.text('VCB')), findsOneWidget);
    expect(_confirm, findsOneWidget);
    expect(_confirmEnabled(tester), isTrue);
    expect(_inSheet(find.text('Dùng tài khoản khác')), findsOneWidget);
    expect(
      _inSheet(
        find.text(
          'Không chọn thì sau 24 giờ tiền tự hoàn về tài khoản đã chuyển.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      _inSheet(find.text('Ví MoMo/ZaloPay: hoàn về ví, không cần chọn.')),
      findsOneWidget,
    );
  });

  testWidgets('Hoàn về tài khoản này calls chooseRefundAccount(payer), closes '
      'and shows "Đã gửi yêu cầu hoàn tiền"', (tester) async {
    final payments = await _open(tester);

    await tester.tap(_confirm);
    await _settle(tester);

    expect(payments.chooseCalls, ['r1:payer']);
    expect(_sheet, findsNothing);
    expect(find.text('Đã gửi yêu cầu hoàn tiền'), findsOneWidget);
  });

  testWidgets('the close icon closes without choosing', (tester) async {
    final payments = await _open(tester);

    await tester.tap(_inSheet(find.byTooltip('Đóng')));
    await _settle(tester);

    expect(_sheet, findsNothing);
    expect(payments.chooseCalls, isEmpty);
  });

  testWidgets('Dùng tài khoản khác shows the form; lookup shows the returned '
      'name; confirm calls choose(candidate)', (tester) async {
    final payments = await _open(tester);
    await _useOther(tester);

    expect(_inSheet(find.text('Vietcombank •••• 6789')), findsNothing);
    expect(_inSheet(find.byType(BankField)), findsOneWidget);
    expect(_inSheet(find.text('Số tài khoản')), findsOneWidget);
    expect(
      _inSheet(find.text('Số tài khoản được mã hoá, chỉ hiện 4 số cuối.')),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isFalse, reason: 'no lookup yet');

    await _fill(tester, 'TCB', '1903612344321');
    // Grouped by four as typed (AccountNumberFormatter).
    expect(find.text('1903 6123 4432 1'), findsOneWidget);
    await _lookup(tester);

    expect(payments.lookupCalls, ['r1:TCB:4321']);
    expect(_inSheet(find.text('TRAN VAN B')), findsOneWidget);
    expect(
      _inSheet(
        find.text('Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ.'),
      ),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isTrue);

    await tester.ensureVisible(_confirm);
    await tester.tap(_confirm);
    await _settle(tester);

    expect(payments.chooseCalls, ['r1:candidate']);
    expect(_sheet, findsNothing);
    expect(find.text('Đã gửi yêu cầu hoàn tiền'), findsOneWidget);
  });

  testWidgets('changing the number after a lookup asks again before confirm', (
    tester,
  ) async {
    await _open(tester);
    await _useOther(tester);
    await _fill(tester, 'TCB', '1903612344321');
    await _lookup(tester);
    expect(_confirmEnabled(tester), isTrue);

    await tester.enterText(
      find.byKey(const Key('refund-number')),
      '1903612340000',
    );
    await tester.pump();

    expect(_inSheet(find.text('TRAN VAN B')), findsNothing);
    expect(_confirmEnabled(tester), isFalse);
  });

  testWidgets('lookup not_found shows refundAccountNotFound; not_eligible '
      'shows refundAccountUnsupported; confirm stays disabled', (tester) async {
    final payments = await _open(tester);
    await _useOther(tester);
    await _fill(tester, 'TCB', '1903612340404');

    payments.nextError = 'not_found';
    await _lookup(tester);
    expect(
      _inSheet(
        find.text(
          'Không tìm thấy tài khoản này. Kiểm tra lại ngân hàng và số tài khoản.',
        ),
      ),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isFalse);

    payments.nextError = 'not_eligible';
    await _lookup(tester);
    expect(
      _inSheet(
        find.text(
          'Ngân hàng này chưa tra được tên chủ tài khoản. Chọn ngân hàng '
          'khác hoặc hoàn về tài khoản đã chuyển.',
        ),
      ),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isFalse);
    expect(payments.chooseCalls, isEmpty);
  });

  testWidgets('the 21st lookup of the day says to try tomorrow', (
    tester,
  ) async {
    final payments = await _open(tester);
    await _useOther(tester);
    await _fill(tester, 'TCB', '1903612344321');

    payments.nextError = 'limit_exceeded';
    await _lookup(tester);

    expect(
      _inSheet(
        find.text('Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.'),
      ),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isFalse);
  });

  testWidgets('no payer opens straight on the form with the no-payer line', (
    tester,
  ) async {
    await _open(tester, pending: _pending(payer: false));

    expect(
      _inSheet(
        find.text(
          'Chưa có thông tin tài khoản đã chuyển. Nhập tài khoản để nhận '
          'tiền hoàn.',
        ),
      ),
      findsOneWidget,
    );
    expect(_inSheet(find.byType(BankField)), findsOneWidget);
    expect(_inSheet(find.text('Dùng tài khoản khác')), findsNothing);
    expect(
      _inSheet(
        find.text(
          'Không chọn thì sau 24 giờ tiền tự hoàn về tài khoản đã chuyển.',
        ),
      ),
      findsNothing,
      reason: 'no paying account, no 24-hour default',
    );
    expect(_confirmEnabled(tester), isFalse);
  });

  testWidgets('nothing pending → no sheet', (tester) async {
    final payments = await _open(tester, seed: false);

    expect(payments.pendingCalls, [_subject]);
    expect(_sheet, findsNothing);
  });

  testWidgets('a choice after the 24-hour default re-reads the refund and '
      'never claims the chosen account was used', (tester) async {
    final payments = await _open(
      tester,
      now: _confirmBy.add(const Duration(minutes: 10)),
    );
    // The payment clock sent it to the paying account meanwhile.
    payments.pendingBySubject.remove(_subject);

    await _useOther(tester);
    await _fill(tester, 'TCB', '1903612344321');
    await _lookup(tester);
    await tester.ensureVisible(_confirm);
    await tester.tap(_confirm);
    await _settle(tester);

    expect(payments.pendingCalls, [_subject, _subject]);
    expect(payments.chooseCalls, isEmpty);
    expect(_sheet, findsNothing);
    expect(find.text('Đã gửi yêu cầu hoàn tiền'), findsNothing);
    expect(
      find.text(
        'Tiền hoàn đã được gửi đi trước khi bạn chọn. Xem nơi nhận ở Lịch sử '
        'thanh toán.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a refund that left while the sheet was open (conflict) closes '
      'it with the same line', (tester) async {
    final payments = await _open(tester);
    payments.nextError = 'conflict';

    await tester.tap(_confirm);
    await _settle(tester);

    expect(_sheet, findsNothing);
    expect(
      find.text(
        'Tiền hoàn đã được gửi đi trước khi bạn chọn. Xem nơi nhận ở Lịch sử '
        'thanh toán.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed choice keeps the sheet open with an error line', (
    tester,
  ) async {
    final payments = await _open(tester);
    payments.nextError = 'network';

    await tester.tap(_confirm);
    await _settle(tester);

    expect(_sheet, findsOneWidget);
    expect(payments.chooseCalls, isEmpty);
    expect(find.text('Chưa gửi được, thử lại sau.'), findsOneWidget);
    expect(_confirmEnabled(tester), isTrue);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(tester, width: 320, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(_confirm, findsOneWidget);

    await _useOther(tester);
    await _fill(tester, 'TCB', '1903612344321');
    await _lookup(tester);
    expect(tester.takeException(), isNull);
    expect(_inSheet(find.text('TRAN VAN B')), findsOneWidget);
  });
}
