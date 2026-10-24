import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/instant_work/provider_cancel_sheet.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';
import '../../support/screen_host.dart';

const _title = 'Huỷ việc chụp ngay?';
const _body =
    'Khách được hoàn 100%. Huỷ sau khi nhận làm giảm điểm tin cậy của bạn.';

/// A page with one button that opens S13.08; the result lands in [results].
Future<List<bool>> _open(WidgetTester tester, InstantWorld w) async {
  final results = <bool>[];
  await tester.pumpWidget(
    screenApp(
      overrides: w.overrides,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showProviderCancelSheet(context, requestId: 'req1'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settleInstant(tester);
  return results;
}

Future<void> _end(WidgetTester tester, FakeInstantRepository repo) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await repo.dispose();
}

Finder get _confirm => find.byKey(const Key('provider-cancel-confirm'));

void main() {
  testWidgets(
    'shows "Huỷ việc chụp ngay?" and the 100% line; red "Huỷ việc" calls '
    'cancel(dryRun: false); "Giữ việc" closes',
    (tester) async {
      final w = InstantWorld();
      final results = await _open(tester, w);

      // The dry run comes first: the outcome is known before the button.
      expect(w.repo.callsOf('cancel').single.args, {
        'requestId': 'req1',
        'dryRun': true,
      });
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_body), findsOneWidget);
      final code = tester.widget<ScreenCode>(
        find.ancestor(of: find.text(_title), matching: find.byType(ScreenCode)),
      );
      expect(code.code, ScreenCodes.instantCancel);
      expect(code.label, 'provider');
      // Red confirmation, never the gradient button.
      expect(
        find.descendant(of: _confirm, matching: find.text('Huỷ việc')),
        findsOneWidget,
      );
      expect(find.byType(CtaSurface), findsNothing);

      // "Giữ việc" closes without cancelling.
      await tester.tap(find.text('Giữ việc'));
      await settleInstant(tester);
      expect(find.text(_title), findsNothing);
      expect(results, [false]);
      expect(w.repo.callsOf('cancel'), hasLength(1));

      // Again, and cancel.
      await tester.tap(find.text('open'));
      await settleInstant(tester);
      await tester.tap(_confirm);
      await settleInstant(tester);
      // The outcome shown goes with the cancel (#202: `conflict` if it changed).
      expect(w.repo.callsOf('cancel').last.args, {
        'requestId': 'req1',
        'dryRun': false,
        'expected': w.repo.cancelQuote,
      });
      expect(find.text(_title), findsNothing);
      expect(results, [false, true]);
      await _end(tester, w.repo);
    },
  );

  testWidgets('server conflict keeps the sheet open with instantErrorGeneric', (
    tester,
  ) async {
    final w = InstantWorld();
    final results = await _open(tester, w);

    w.repo.failNext('cancel', 'conflict');
    await tester.tap(_confirm);
    await settleInstant(tester);

    expect(find.text(_title), findsOneWidget);
    expect(find.text('Chưa thực hiện được. Thử lại nhé.'), findsOneWidget);
    expect(results, isEmpty);
    expect(tester.widget<AppButton>(_confirm).onPressed, isNotNull);
    await _end(tester, w.repo);
  });

  testWidgets('no red button until the quote has loaded', (tester) async {
    final w = InstantWorld();
    final gate = w.repo.gate = Completer<void>();
    await _open(tester, w);
    expect(find.text(_title), findsOneWidget);
    expect(_confirm, findsNothing);
    gate.complete();
    w.repo.gate = null;
    await settleInstant(tester);
    expect(_confirm, findsOneWidget);
    await tester.tap(_confirm);
    await settleInstant(tester);
    expect(w.repo.callsOf('cancel').last.args['expected'], w.repo.cancelQuote);
    await _end(tester, w.repo);
  });

  testWidgets('a refused dry run shows the error with retry, no red button', (
    tester,
  ) async {
    final w = InstantWorld();
    w.repo.failNext('cancel', 'conflict');
    await _open(tester, w);

    expect(find.text(_title), findsOneWidget);
    expect(_confirm, findsNothing);
    await _end(tester, w.repo);
  });
}
