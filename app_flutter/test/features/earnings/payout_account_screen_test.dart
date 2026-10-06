import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/earnings/payout_account_screen.dart';

import '../../support/earnings_world.dart';
import '../../support/photographer_world.dart' show PhotographerWorld;

/// The Lưu button's ring spins while a save waits (re-authentication), so
/// pumpAndSettle would never return: pump a bounded second instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _key(String k) => find.byKey(Key(k));

Future<EarningsWorld> _open(
  WidgetTester tester, {
  EarningsWorld? world,
  bool account = false,
  double width = 390,
  double textScale = 1.0,
}) async {
  usePhone(tester, width: width, height: 900);
  final w = world ?? EarningsWorld();
  await w.init();
  w.repo.setAccount(account ? w.account() : null);
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

Future<void> _fill(
  WidgetTester tester, {
  String number = '01234567890',
  String holder = 'nguyễn minh trí',
}) async {
  await tester.enterText(_key('payout-number'), number);
  await tester.enterText(_key('payout-holder'), holder);
  await _settle(tester);
}

Future<void> _confirmChange(WidgetTester tester) async {
  expect(find.text('Đổi tài khoản nhận tiền?'), findsOneWidget);
  await tester.tap(
    find.descendant(
      of: _key('app-sheet'),
      matching: find.widgetWithText(AppButton, 'Đổi tài khoản'),
    ),
  );
  await _settle(tester);
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).controller!.text;

void main() {
  testWidgets('save stays disabled until bank, number and holder are valid', (
    tester,
  ) async {
    await _open(tester);
    expect(
      find.text(
        'Chúng tôi chuyển tiền sau mỗi buổi chụp hoàn thành vào tài khoản này.',
      ),
      findsOneWidget,
    );
    expect(_saveEnabled(tester), isFalse);
    await _pickBank(tester, 'VCB');
    expect(find.text('Vietcombank'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
    await tester.enterText(_key('payout-number'), '12345');
    await tester.enterText(_key('payout-holder'), 'tri');
    await _settle(tester);
    expect(_saveEnabled(tester), isFalse, reason: 'number too short');
    await tester.enterText(_key('payout-number'), '123456');
    await _settle(tester);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('the number groups by four and the holder is upper-case', (
    tester,
  ) async {
    await _open(tester);
    await _fill(tester);
    expect(_fieldText(tester, 'payout-number'), '0123 4567 890');
    expect(_fieldText(tester, 'payout-holder'), 'NGUYEN MINH TRI');
    final style = tester.widget<TextField>(_key('payout-number')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('a short number shows the error under its field', (tester) async {
    await _open(tester);
    await tester.enterText(_key('payout-number'), '123');
    await _settle(tester);
    expect(find.text('Số tài khoản gồm 6–20 chữ số'), findsNothing);
    // Leaving the field.
    await tester.tap(_key('payout-holder'));
    await _settle(tester);
    expect(find.text('Số tài khoản gồm 6–20 chữ số'), findsOneWidget);
    await tester.enterText(_key('payout-holder'), 'a');
    await tester.tap(_key('payout-number'));
    await _settle(tester);
    expect(
      find.text('Nhập họ tên viết hoa không dấu, 2–50 chữ cái'),
      findsOneWidget,
    );
  });

  testWidgets('first save sends normalised values and shows the masked view', (
    tester,
  ) async {
    final w = await _open(tester);
    await _pickBank(tester, 'VCB');
    await _fill(tester);
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    expect(w.repo.saves, ['VCB:7890']);
    expect(find.text('Đã lưu tài khoản nhận tiền'), findsOneWidget);
    expect(_key('payout-masked'), findsOneWidget);
    expect(find.text('•••• 7890'), findsOneWidget);
    expect(find.text('Đổi tài khoản'), findsOneWidget);
    expect(find.textContaining('0123'), findsNothing);
    expect(find.textContaining('1234567'), findsNothing);
    expect(_key('payout-save'), findsNothing);
  });

  testWidgets('an existing account shows •••• and Đổi tài khoản, never the '
      'full number', (tester) async {
    await _open(tester, account: true);
    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('•••• 3456'), findsOneWidget);
    expect(find.text('NGUYEN MINH TRI'), findsOneWidget);
    expect(find.text('Đổi tài khoản'), findsOneWidget);
    expect(_key('payout-save'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AppButton), findsOneWidget, reason: 'one button only');
  });

  testWidgets('Đổi tài khoản opens the empty form with the bank kept', (
    tester,
  ) async {
    await _open(tester, account: true);
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    expect(_fieldText(tester, 'payout-bank'), 'Vietcombank');
    expect(_fieldText(tester, 'payout-number'), isEmpty);
    expect(_fieldText(tester, 'payout-holder'), isEmpty);
    expect(_saveEnabled(tester), isFalse);
    await tester.tap(_key('payout-cancel-change'));
    await _settle(tester);
    expect(find.text('•••• 3456'), findsOneWidget);
  });

  testWidgets('a change asks to confirm first', (tester) async {
    final w = await _open(tester, account: true);
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    expect(find.text('Đổi tài khoản nhận tiền?'), findsOneWidget);
    expect(
      find.text(
        'Các khoản chưa chuyển sẽ chuyển vào tài khoản mới. Khoản đã chuyển không thay đổi.',
      ),
      findsOneWidget,
    );
    expect(w.repo.saves, isEmpty, reason: 'nothing sent before confirming');
    await _confirmChange(tester);
    expect(w.repo.saves, ['VCB:3210']);
    expect(find.text('•••• 3210'), findsOneWidget);
  });

  testWidgets('keeping the old account sends nothing', (tester) async {
    final w = await _open(tester, account: true);
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Huỷ').last);
    await _settle(tester);
    expect(w.repo.saves, isEmpty);
    expect(_fieldText(tester, 'payout-number'), '9876 5432 10');
  });

  testWidgets('reauth_required re-authenticates and retries once', (
    tester,
  ) async {
    final w = await _open(tester, account: true);
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    w.repo.failNextSave('reauth_required');
    await _confirmChange(tester);
    expect(find.text('Xác nhận lại để đổi tài khoản'), findsOneWidget);
    expect(w.repo.saves, isEmpty);
    await tester.enterText(_key('reauth-password'), EarningsWorld.password);
    await tester.tap(_key('reauth-go'));
    await _settle(tester);
    expect(w.auth.reauthentications, 1);
    expect(w.repo.saves, ['VCB:3210']);
    expect(find.text('Đã lưu tài khoản nhận tiền'), findsOneWidget);
  });

  testWidgets('a Google user re-authenticates with the button only', (
    tester,
  ) async {
    final w = await _open(
      tester,
      world: EarningsWorld(reauthMethod: ReauthMethod.google),
      account: true,
    );
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    w.repo.failNextSave('reauth_required');
    await _confirmChange(tester);
    expect(_key('reauth-password'), findsNothing);
    await tester.tap(_key('reauth-go'));
    await _settle(tester);
    expect(w.auth.reauthentications, 1);
    expect(w.repo.saves, ['VCB:3210']);
  });

  testWidgets('a cancelled re-authentication keeps the input', (tester) async {
    final w = await _open(tester, account: true);
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    w.repo.failNextSave('reauth_required');
    await _confirmChange(tester);
    // Close the re-authentication sheet by tapping the barrier.
    await tester.tapAt(const Offset(195, 20));
    await _settle(tester);
    expect(find.text('Xác nhận lại để đổi tài khoản'), findsNothing);
    expect(w.repo.saves, isEmpty);
    expect(_fieldText(tester, 'payout-number'), '9876 5432 10');
    expect(_fieldText(tester, 'payout-holder'), 'LE VAN A');
    expect(find.text('Đã lưu tài khoản nhận tiền'), findsNothing);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('the re-authentication sheet stays while it is signing in', (
    tester,
  ) async {
    final w = await _open(
      tester,
      world: EarningsWorld(reauthMethod: ReauthMethod.google),
      account: true,
    );
    final gate = Completer<void>();
    w.auth.reauthGate = gate.future;
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    w.repo.failNextSave('reauth_required');
    await _confirmChange(tester);
    await tester.tap(_key('reauth-go'));
    await _settle(tester);
    // Barrier tap and Back do nothing while busy.
    await tester.tapAt(const Offset(195, 20));
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Xác nhận lại để đổi tài khoản'), findsOneWidget);
    gate.complete();
    await _settle(tester);
    expect(find.text('Xác nhận lại để đổi tài khoản'), findsNothing);
    expect(w.repo.saves, ['VCB:3210']);
  });

  testWidgets('a cancelled provider sign-in keeps the sheet open', (
    tester,
  ) async {
    final w = await _open(
      tester,
      world: EarningsWorld(
        reauthMethod: ReauthMethod.facebook,
        cancelSocial: true,
      ),
      account: true,
    );
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    w.repo.failNextSave('reauth_required');
    await _confirmChange(tester);
    await tester.tap(_key('reauth-go'));
    await _settle(tester);
    expect(find.text('Xác nhận lại để đổi tài khoản'), findsOneWidget);
    expect(w.auth.reauthentications, 0);
    expect(w.repo.saves, isEmpty);
  });

  testWidgets('a wrong password shows the error in the sheet', (tester) async {
    final w = await _open(tester, account: true);
    await tester.tap(_key('payout-change'));
    await _settle(tester);
    await _fill(tester, number: '9876543210', holder: 'le van a');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    w.repo.failNextSave('reauth_required');
    await _confirmChange(tester);
    await tester.enterText(_key('reauth-password'), 'wrong');
    await tester.tap(_key('reauth-go'));
    await _settle(tester);
    expect(find.text('Mật khẩu chưa đúng'), findsOneWidget);
    expect(find.text('Xác nhận lại để đổi tài khoản'), findsOneWidget);
    expect(w.repo.saves, isEmpty);
    // Retrying with the right one works.
    await tester.enterText(_key('reauth-password'), EarningsWorld.password);
    await tester.tap(_key('reauth-go'));
    await _settle(tester);
    expect(w.repo.saves, ['VCB:3210']);
  });

  testWidgets('conflict shows the busy SnackBar and keeps the input', (
    tester,
  ) async {
    final w = await _open(tester);
    await _pickBank(tester, 'VCB');
    await _fill(tester);
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

  testWidgets('another error shows the generic SnackBar and keeps the input', (
    tester,
  ) async {
    final w = await _open(tester);
    await _pickBank(tester, 'VCB');
    await _fill(tester);
    w.repo.failNextSave('network');
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    expect(find.text('Không lưu được. Thử lại'), findsOneWidget);
    expect(_fieldText(tester, 'payout-holder'), 'NGUYEN MINH TRI');
  });

  testWidgets('analytics gets no account data', (tester) async {
    final w = await _open(tester);
    await _pickBank(tester, 'VCB');
    await _fill(tester);
    await tester.tap(_key('payout-save'));
    await _settle(tester);
    final saves = w.events.where((e) => e.$1 == 'payout_account_save').toList();
    expect(saves, hasLength(1));
    expect(saves.single.$2.keys.toSet().difference({'change'}), isEmpty);
    expect(saves.single.$2['change'], false);
    for (final e in w.events) {
      expect('${e.$2}', isNot(contains('7890')));
      expect('${e.$2}', isNot(contains('NGUYEN')));
    }
  });

  testWidgets('fits 320 dp at text scale 1.3 with the keyboard up', (
    tester,
  ) async {
    await _open(tester, width: 320, textScale: 1.3);
    await _pickBank(tester, 'VCB');
    await _fill(tester, holder: 'nguyễn thị minh khoa');
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(_key('payout-save')).height,
      greaterThanOrEqualTo(48),
    );
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
