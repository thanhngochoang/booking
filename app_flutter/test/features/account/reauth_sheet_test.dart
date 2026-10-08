import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/features/account/widgets/reauth_sheet.dart';

import '../../support/screen_host.dart';

/// The Xác nhận button's ring spins while signing in: bounded pumps only.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(FakeAuthRepository, List<bool>)> _open(WidgetTester tester) async {
  final auth = FakeAuthRepository();
  await auth.registerWithEmail('tri@b.vn', 'password1', 'Minh Trí');
  final results = <bool>[];
  await tester.pumpWidget(
    screenApp(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await showReauthSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return (auth, results);
}

void main() {
  testWidgets('showReauthSheet shows "Xác nhận lại để tiếp tục" and returns '
      'true after a successful reauthenticate', (tester) async {
    final (auth, results) = await _open(tester);
    expect(find.text('Xác nhận lại để tiếp tục'), findsOneWidget);
    expect(
      find.text('Vì an toàn, hãy đăng nhập lại trước khi tiếp tục.'),
      findsOneWidget,
    );
    expect(find.text('Mật khẩu'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reauth-password')), 'nope');
    await tester.tap(find.byKey(const Key('reauth-go')));
    await _settle(tester);
    expect(find.text('Mật khẩu chưa đúng'), findsOneWidget);
    expect(results, isEmpty);
    await tester.enterText(
      find.byKey(const Key('reauth-password')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('reauth-go')));
    await _settle(tester);
    expect(auth.reauthentications, 1);
    expect(results, [true]);
    expect(find.text('Xác nhận lại để tiếp tục'), findsNothing);
  });

  testWidgets('closing the sheet returns false', (tester) async {
    final (auth, results) = await _open(tester);
    await tester.tapAt(const Offset(200, 20));
    await _settle(tester);
    expect(results, [false]);
    expect(auth.reauthentications, 0);
  });
}
