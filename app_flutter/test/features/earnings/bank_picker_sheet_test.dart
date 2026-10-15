import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/widgets/bank_picker_sheet.dart';

import '../../support/screen_host.dart';

final _results = <VnBank?>[];

Future<void> _open(WidgetTester tester, {String? selected}) async {
  _results.clear();
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async => _results.add(
                await showBankPicker(context, selected: selected),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('bank-search')), q);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search finds Vietcombank by vietcom and by VCB', (tester) async {
    await _open(tester);
    await _search(tester, 'vietcom');
    expect(find.byKey(const Key('bank-VCB')), findsOneWidget);
    expect(find.byKey(const Key('bank-ICB')), findsNothing);
    await _search(tester, 'VCB');
    expect(find.byKey(const Key('bank-VCB')), findsOneWidget);
    expect(find.byKey(const Key('bank-BIDV')), findsNothing);
  });

  testWidgets('search ignores diacritics', (tester) async {
    await _open(tester);
    await _search(tester, 'ngoai thuong viet');
    expect(find.byKey(const Key('bank-VCB')), findsOneWidget);
    await _search(tester, 'Đầu tư và Phát triển');
    expect(find.byKey(const Key('bank-BIDV')), findsOneWidget);
    expect(find.byKey(const Key('bank-VCB')), findsNothing);
  });

  testWidgets('rows read "shortName · name"', (tester) async {
    await _open(tester);
    expect(
      find.text('Vietcombank · Ngân hàng TMCP Ngoại thương Việt Nam'),
      findsOneWidget,
    );
  });

  testWidgets('no match says so', (tester) async {
    await _open(tester);
    await _search(tester, 'zzzz');
    expect(find.text('Không tìm thấy ngân hàng'), findsOneWidget);
  });

  testWidgets('picking closes the sheet with the bank', (tester) async {
    await _open(tester);
    await _search(tester, 'techcom');
    await tester.tap(find.byKey(const Key('bank-TCB')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bank-search')), findsNothing);
    expect(_results.single?.code, 'TCB');
  });

  testWidgets('the sheet cannot be dragged down (it has a search field)', (
    tester,
  ) async {
    await _open(tester);
    await tester.drag(find.text('Chọn ngân hàng'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bank-search')), findsOneWidget);
  });

  testWidgets('Back closes it with null', (tester) async {
    await _open(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(_results, [null]);
  });
}
