import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/earnings/payout_account_screen.dart';

import '../../support/earnings_world.dart';
import '../../support/photographer_world.dart' show PhotographerWorld;

/// The Lưu button's ring spins while a save waits, and the lookup waits
/// 800 ms after typing, so pumpAndSettle would never return: pump a bounded
/// 1.2 seconds instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(Key(k));

/// 10/10/2026 10:15 in Vietnam: a change made now is active 13/10 10:15.
final _changeNow = DateTime.utc(2026, 10, 10, 3, 15);

Future<EarningsWorld> _open(
  WidgetTester tester, {
  EarningsWorld? world,
  PayoutAccountView? Function(EarningsWorld w)? account,
  double width = 390,
  double textScale = 1.0,
}) async {
  usePhone(tester, width: width, height: 900);
  final w = world ?? EarningsWorld();
  await w.init();
  w.repo.setAccount(account?.call(w));
  await tester.pumpWidget(
    w.app(
      location: '/work/earnings/account',
      textScale: textScale,
      account: () => const PayoutAccountScreen(),
    ),
  );
  await _settle(tester);
  return w;
}

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<AppButton>(_key('payout-save')).onPressed != null;

Future<void> _pickBank(WidgetTester tester, String code) async {
  await tester.tap(_key('payout-bank'));
  await _settle(tester);
  await tester.tap(_key('bank-$code'));
  await _settle(tester);
}

/// Types the number and waits past the 800 ms lookup delay.
Future<void> _type(WidgetTester tester, String number) async {
  await tester.enterText(_key('payout-number'), number);
  await _settle(tester);
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).controller!.text;

Future<void> _startChange(WidgetTester tester) async {
  await tester.tap(_key('payout-change'));
  await _settle(tester);
}

/// No full account number on screen (only masked text is asserted).
void _expectNoFullNumber(List<String> numbers) {
  for (final n in numbers) {
    final shown = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data ?? w.textSpan?.toPlainText() ?? '')
              .replaceAll(' ', '')
              .contains(n),
    );
    expect(
      shown.evaluate().isEmpty,
      isTrue,
      reason: 'a full account number is visible (masked)',
    );
  }
}

void main() {
  group('first account', () {
    testWidgets('matched lookup shows the name and "Khớp tên đã xác minh"', (
      tester,
    ) async {
      final w = await _open(tester);
      expect(
        find.text('Nhập tài khoản đứng tên bạn, tiền sẽ chi tự động vào đây.'),
        findsOneWidget,
      );
      expect(_saveEnabled(tester), isFalse);
      await _pickBank(tester, 'VCB');
      expect(find.text('Vietcombank'), findsOneWidget);
      expect(find.text('Ngân hàng TMCP Ngoại thương Việt Nam'), findsOneWidget);
      await _type(tester, '01234567890');
      expect(_fieldText(tester, 'payout-number'), '0123 4567 890');
      expect(w.repo.lookupCalls, ['VCB:7890']);
      expect(find.text('NGUYEN MINH TRI'), findsOneWidget);
      expect(find.text('Khớp tên đã xác minh'), findsOneWidget);
      expect(
        find.text(
          'Tên chủ tài khoản do ngân hàng trả về, bạn không cần gõ. Số tài '
          'khoản được mã hoá, chỉ hiện 4 số cuối.',
        ),
        findsOneWidget,
      );
      expect(_saveEnabled(tester), isTrue);
      final style = tester.widget<TextField>(_key('payout-number')).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('no holder name field exists', (tester) async {
      await _open(tester);
      expect(_key('payout-holder'), findsNothing);
      expect(find.byType(TextField), findsOneWidget, reason: 'number only');
      expect(find.text('Tên chủ tài khoản'), findsNothing);
    });

    testWidgets('mismatch shows the two names, the warning text and a '
        'disabled "Lưu tài khoản"', (tester) async {
      final w = EarningsWorld();
      w.repo.nextLookup['VCB:0987654321'] = const PayoutNameLookup(
        decision: PayoutNameDecision.mismatch,
        holderName: 'TRAN VAN B',
        verifiedName: 'NGUYEN MINH TRI',
      );
      await _open(tester, world: w);
      await _pickBank(tester, 'VCB');
      await _type(tester, '0987654321');
      expect(find.text('TRAN VAN B'), findsOneWidget);
      expect(find.text('Không khớp'), findsOneWidget);
      expect(
        find.text(
          'Tên chủ tài khoản không khớp tên đã xác minh (NGUYEN MINH TRI)',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Chỉ chi tiền vào tài khoản đứng tên bạn. Kiểm tra lại ngân hàng và '
          'số tài khoản.',
        ),
        findsOneWidget,
      );
      expect(find.text('Lưu tài khoản'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
      final field = tester.widget<TextField>(_key('payout-number'));
      expect(field.decoration?.error, isNotNull, reason: 'red border');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(w.repo.saves, isEmpty);
    });

    testWidgets('review shows "Ngân hàng chưa hỗ trợ tra tên" and enables '
        'save', (tester) async {
      final w = EarningsWorld();
      w.repo.nextLookup['TCB:190355669999'] = const PayoutNameLookup(
        decision: PayoutNameDecision.review,
        verifiedName: 'NGUYEN MINH TRI',
      );
      await _open(tester, world: w);
      await _pickBank(tester, 'TCB');
      await _type(tester, '190355669999');
      expect(find.text('Ngân hàng chưa hỗ trợ tra tên'), findsOneWidget);
      expect(
        find.text('Staff đối chiếu tên trước lần chi đầu'),
        findsOneWidget,
      );
      expect(_saveEnabled(tester), isTrue);
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(w.repo.saves, ['TCB:9999']);
      expect(
        find.text('Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu.'),
        findsOneWidget,
      );
    });

    for (final (name, setUp, text)
        in <(String, void Function(EarningsWorld), String)>[
          (
            'not_found',
            (w) => w.repo.defaultLookup = const PayoutNameLookup(
              decision: PayoutNameDecision.notFound,
            ),
            'Không tìm thấy tài khoản. Kiểm tra lại số tài khoản.',
          ),
          (
            'unverifiable',
            (w) => w.repo.defaultLookup = const PayoutNameLookup(
              decision: PayoutNameDecision.unverifiable,
            ),
            'Cần xác minh danh tính trước khi thêm tài khoản ở ngân hàng này',
          ),
          (
            'limit',
            (w) => w.repo.failNextLookup('limit_exceeded'),
            'Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.',
          ),
          (
            'network',
            (w) => w.repo.failNextLookup('network'),
            'Không tra được tên. Thử lại',
          ),
        ]) {
      testWidgets('$name shows its text and disables save', (tester) async {
        final w = EarningsWorld();
        setUp(w);
        await _open(tester, world: w);
        await _pickBank(tester, 'VCB');
        await _type(tester, '01234567890');
        expect(find.text(text), findsOneWidget);
        expect(_saveEnabled(tester), isFalse);
      });
    }

    testWidgets('a failed lookup retries on tap', (tester) async {
      final w = EarningsWorld();
      w.repo.failNextLookup('network');
      await _open(tester, world: w);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      await tester.tap(find.text('Không tra được tên. Thử lại'));
      await _settle(tester);
      expect(find.text('Khớp tên đã xác minh'), findsOneWidget);
      expect(w.repo.lookupCalls, hasLength(2));
    });

    testWidgets('a short number shows the error after leaving the field', (
      tester,
    ) async {
      await _open(tester);
      await _type(tester, '123');
      expect(find.text('Số tài khoản gồm 6–20 chữ số'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(find.text('Số tài khoản gồm 6–20 chữ số'), findsOneWidget);
    });

    testWidgets('first save asks no OTP and shows the masked view', (
      tester,
    ) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(w.repo.otpCalls, isEmpty);
      expect(find.text('Nhập mã xác nhận'), findsNothing);
      expect(w.repo.saves, ['VCB:7890']);
      expect(find.text('Đã lưu tài khoản nhận tiền'), findsOneWidget);
      expect(find.text('Vietcombank •••• 7890'), findsOneWidget);
      expect(find.text('CHỜ HIỆU LỰC'), findsNothing);
      expect(_key('payout-save'), findsNothing);
      _expectNoFullNumber(['01234567890']);
    });

    testWidgets('name_mismatch on save replaces the match with the mismatch '
        'state and keeps the input', (tester) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      expect(find.text('Khớp tên đã xác minh'), findsOneWidget);
      w.repo.failNextSave('name_mismatch');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(find.text('Khớp tên đã xác minh'), findsNothing);
      expect(find.text('Không khớp'), findsOneWidget);
      expect(
        find.text(
          'Tên chủ tài khoản không khớp tên đã xác minh (Nguyễn Minh Trí)',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Chỉ chi tiền vào tài khoản đứng tên bạn. Kiểm tra lại ngân hàng và '
          'số tài khoản.',
        ),
        findsWidgets,
      );
      expect(_saveEnabled(tester), isFalse);
      expect(_fieldText(tester, 'payout-number'), '0123 4567 890');
    });

    testWidgets('not_found on save shows the not-found state', (tester) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      w.repo.failNextSave('not_found');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(find.text('Khớp tên đã xác minh'), findsNothing);
      expect(
        find.text('Không tìm thấy tài khoản. Kiểm tra lại số tài khoản.'),
        findsWidgets,
      );
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('conflict shows the busy SnackBar and keeps the input', (
      tester,
    ) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      w.repo.failNextSave('conflict');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(
        find.text('Đang chuyển một lô tiền, thử lại sau ít phút'),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'payout-number'), '0123 4567 890');
      expect(_saveEnabled(tester), isTrue);
      expect(w.repo.saves, isEmpty);
    });

    testWidgets('limit_exceeded on save shows the lookup limit', (
      tester,
    ) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      w.repo.failNextSave('limit_exceeded');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(
        find.text('Bạn đã tra quá nhiều lần hôm nay. Thử lại vào ngày mai.'),
        findsOneWidget,
      );
    });

    testWidgets('another error shows the generic SnackBar', (tester) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      w.repo.failNextSave('network');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(find.text('Không lưu được. Thử lại'), findsOneWidget);
    });

    testWidgets('analytics gets no account data', (tester) async {
      final w = await _open(tester);
      await _pickBank(tester, 'VCB');
      await _type(tester, '01234567890');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      final saves = w.events
          .where((e) => e.$1 == 'payout_account_save')
          .toList();
      expect(saves, hasLength(1));
      expect(saves.single.$2, {'change': false});
      for (final e in w.events) {
        expect('${e.$2}'.contains('7890'), isFalse);
        expect('${e.$2}'.contains('NGUYEN'), isFalse);
      }
    });
  });

  group('existing account', () {
    testWidgets('shows the masked account and Đổi tài khoản, never the full '
        'number', (tester) async {
      await _open(tester, account: (w) => w.account());
      expect(find.text('Vietcombank •••• 3456'), findsOneWidget);
      expect(find.text('NGUYEN MINH TRI'), findsOneWidget);
      expect(find.text('Đổi tài khoản'), findsOneWidget);
      expect(find.text('CHỜ HIỆU LỰC'), findsNothing);
      expect(_key('payout-save'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(AppButton), findsOneWidget, reason: 'one button only');
    });

    testWidgets('a pending_review account shows the staff note', (
      tester,
    ) async {
      await _open(
        tester,
        account: (w) => w.account(nameStatus: PayoutNameStatus.pendingReview),
      );
      expect(
        find.text('Staff sẽ đối chiếu tên chủ tài khoản trước lần chi đầu.'),
        findsOneWidget,
      );
    });

    testWidgets('change form shows the intro with the current bank and last 4 '
        'and the lock note', (tester) async {
      await _open(tester, account: (w) => w.account(bank: 'MB'));
      await _startChange(tester);
      expect(
        find.text(
          'Đang dùng MB •••• 3456. Nhập tài khoản mới đứng tên bạn, tiền '
          'sẽ chi tự động vào đây.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Đổi tài khoản cần OTP và có hiệu lực sau 72 giờ; trong lúc đó tạm '
          'dừng chi. Tài khoản cũ sẽ nhận thông báo.',
        ),
        findsOneWidget,
      );
      expect(find.text('MBBank'), findsOneWidget, reason: 'bank kept');
      expect(_fieldText(tester, 'payout-number'), isEmpty);
      expect(_saveEnabled(tester), isFalse);
      await tester.tap(_key('payout-cancel-change'));
      await _settle(tester);
      expect(find.text('MBBank •••• 3456'), findsOneWidget);
    });

    testWidgets('after a change the read view shows "Chờ hiệu lực" and '
        '"Tài khoản mới có hiệu lực lúc 10:15, 13/10"', (tester) async {
      final w = await _open(
        tester,
        world: EarningsWorld(now: _changeNow),
        account: (w) => w.account(bank: 'MB'),
      );
      await _startChange(tester);
      await _pickBank(tester, 'TCB');
      await _type(tester, '190355667788');
      expect(w.repo.saves, isEmpty);
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(w.repo.otpCalls, ['TCB:7788']);
      expect(find.text('Nhập mã xác nhận'), findsOneWidget);
      expect(
        find.text(
          'Mã 6 số đã gửi tới số điện thoại •••• 0001. Mã có hiệu lực 5 phút.',
        ),
        findsOneWidget,
      );
      expect(w.repo.saves, isEmpty, reason: 'nothing saved before the code');
      await tester.enterText(
        find.descendant(
          of: _key('app-sheet'),
          matching: find.byType(TextField),
        ),
        '482913',
      );
      await _settle(tester);
      expect(w.repo.saves, ['TCB:7788:482913']);
      expect(find.text('Nhập mã xác nhận'), findsNothing);
      expect(
        find.text('Đã đổi tài khoản. Có hiệu lực sau 72 giờ'),
        findsOneWidget,
      );
      expect(find.text('Techcombank •••• 7788'), findsOneWidget);
      expect(find.text('CHỜ HIỆU LỰC'), findsOneWidget);
      expect(
        find.text('Tài khoản mới có hiệu lực lúc 10:15, 13/10'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Trong lúc chờ, tạm dừng chi. Lần chi đầu vào tài khoản mới do '
          'staff duyệt.',
        ),
        findsOneWidget,
      );
      expect(find.text('Đổi tài khoản'), findsOneWidget);
      _expectNoFullNumber(['190355667788']);
    });

    testWidgets('a wrong code keeps the OTP sheet open', (tester) async {
      final w = await _open(tester, account: (w) => w.account());
      await _startChange(tester);
      await _type(tester, '190355667788');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      w.repo.failNextSave('otp_invalid');
      final otp = find.descendant(
        of: _key('app-sheet'),
        matching: find.byType(TextField),
      );
      await tester.enterText(otp, '111111');
      await _settle(tester);
      expect(find.text('Mã chưa đúng. Kiểm tra lại tin nhắn'), findsOneWidget);
      expect(find.text('Nhập mã xác nhận'), findsOneWidget);
      expect(w.repo.saves, isEmpty);
      // Closing the sheet keeps the input and sends nothing more.
      await tester.tapAt(const Offset(195, 20));
      await _settle(tester);
      expect(find.text('Nhập mã xác nhận'), findsNothing);
      expect(_fieldText(tester, 'payout-number'), '1903 5566 7788');
      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('OTP sheet: resend is disabled for 60 s then enabled', (
      tester,
    ) async {
      final w = await _open(tester, account: (w) => w.account());
      await _startChange(tester);
      await _type(tester, '190355667788');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(find.text('Gửi lại sau 60 giây'), findsOneWidget);
      expect(find.text('Gửi lại mã'), findsNothing);
      w.now = w.now.add(const Duration(seconds: 59));
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Gửi lại sau 1 giây'), findsOneWidget);
      w.now = w.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Gửi lại mã'), findsOneWidget);
      await tester.tap(find.text('Gửi lại mã'));
      await _settle(tester);
      expect(w.repo.otpCalls, ['VCB:7788', 'VCB:7788']);
      // Let the new countdown end so no timer is left running.
      w.now = w.now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('a typo fixed within 60 s waits instead of showing the daily '
        'limit', (tester) async {
      final w = await _open(tester, account: (w) => w.account());
      await _startChange(tester);
      await _type(tester, '190355667788');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(find.text('Nhập mã xác nhận'), findsOneWidget);
      // Closes the sheet, fixes the number and saves again 20 s later.
      await tester.tapAt(const Offset(195, 20));
      await _settle(tester);
      await _type(tester, '190355667789');
      w.now = w.now.add(const Duration(seconds: 20));
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(w.repo.otpCalls, ['VCB:7788'], reason: 'nothing sent for B');
      expect(find.text('Nhập mã xác nhận'), findsNothing);
      expect(
        find.text('Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.'),
        findsNothing,
      );
      expect(find.text('Gửi lại sau 40 giây'), findsOneWidget);
      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('a resend that fails on the network shows the generic error', (
      tester,
    ) async {
      final w = await _open(tester, account: (w) => w.account());
      await _startChange(tester);
      await _type(tester, '190355667788');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      w.now = w.now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 60));
      w.repo.failNextOtp('network');
      await tester.tap(find.text('Gửi lại mã'));
      await _settle(tester);
      expect(find.text('Không lưu được. Thử lại'), findsOneWidget);
      expect(
        find.text('Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.'),
        findsNothing,
      );
      w.repo.failNextOtp('limit_exceeded');
      await tester.tap(find.text('Gửi lại mã'));
      await _settle(tester);
      expect(
        find.text('Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.'),
        findsOneWidget,
      );
    });

    for (final (code, text) in [
      ('phone_required', 'Cần số điện thoại trong hồ sơ để nhận mã'),
      ('not_eligible', 'Chưa đổi được tài khoản lúc này. Liên hệ hỗ trợ'),
      ('limit_exceeded', 'Đã gửi quá nhiều mã hôm nay. Thử lại vào ngày mai.'),
      ('conflict', 'Đây đã là tài khoản đang dùng'),
    ]) {
      testWidgets('$code when asking for the code shows "$text"', (
        tester,
      ) async {
        final w = await _open(tester, account: (w) => w.account());
        await _startChange(tester);
        await _type(tester, '190355667788');
        w.repo.failNextOtp(code);
        await tester.tap(_key('payout-save'));
        await _settle(tester);
        expect(find.text(text), findsOneWidget);
        expect(find.text('Nhập mã xác nhận'), findsNothing);
        expect(_fieldText(tester, 'payout-number'), '1903 5566 7788');
      });
    }
  });

  group('fits 320 dp at 1.3× text', () {
    testWidgets('form', (tester) async {
      await _open(
        tester,
        width: 320,
        textScale: 1.3,
        account: (w) => w.account(),
      );
      await _startChange(tester);
      await _type(tester, '01234567890');
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(_key('payout-save')).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('mismatch', (tester) async {
      final w = EarningsWorld();
      w.repo.defaultLookup = const PayoutNameLookup(
        decision: PayoutNameDecision.mismatch,
        holderName: 'TRAN VAN BINH MINH KHOA',
        verifiedName: 'NGUYEN THI MINH KHOA',
      );
      await _open(tester, world: w, width: 320, textScale: 1.3);
      await _pickBank(tester, 'BIDV');
      await _type(tester, '01234567890');
      expect(tester.takeException(), isNull);
    });

    testWidgets('OTP sheet', (tester) async {
      final w = await _open(
        tester,
        width: 320,
        textScale: 1.3,
        account: (w) => w.account(),
      );
      await _startChange(tester);
      await _type(tester, '190355667788');
      await tester.tap(_key('payout-save'));
      await _settle(tester);
      expect(find.text('Nhập mã xác nhận'), findsOneWidget);
      expect(tester.takeException(), isNull);
      w.now = w.now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 60));
    });

    testWidgets('pending view', (tester) async {
      await _open(
        tester,
        width: 320,
        textScale: 1.3,
        account: (w) => w.account(
          bank: 'BIDV',
          activeFrom: w.now.add(const Duration(hours: 72)),
        ),
      );
      expect(find.text('CHỜ HIỆU LỰC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('photographers only', () {
    Future<String> land(
      WidgetTester tester,
      UserRole role,
      String location,
    ) async {
      final w = PhotographerWorld(role: role);
      await w.init();
      final container = ProviderContainer(
        overrides: w.overrides,
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      container.listen(currentProfileProvider, (_, _) {});
      await container.read(authStateProvider.future);
      await container.read(currentProfileProvider.future);
      final config = container.read(routerProvider).configuration;
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      final matches = await config.redirect(
        context,
        config.findMatch(Uri.parse(location)),
        redirectHistory: [],
      );
      return matches.uri.toString();
    }

    for (final path in ['/work/earnings', '/work/earnings/account']) {
      testWidgets('$path sends a customer home', (tester) async {
        expect(await land(tester, UserRole.customer, path), '/home');
      });
      testWidgets('$path stays for a photographer', (tester) async {
        expect(await land(tester, UserRole.photographer, path), path);
      });
    }
  });
}
