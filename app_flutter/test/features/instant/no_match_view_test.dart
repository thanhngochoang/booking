// S13.07 (`#S13.07`): nobody accepted. The request is not over (spec
// §2.1.9): any money stays held, nothing is refunded by itself; choose again,
// book normally, or cancel through S13.08.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/no_match_view.dart';

import '../../support/instant_customer_world.dart';

/// Mock: 7 people in 3 rounds, 690.000₫ held, paid with [method].
InstantRequest _noMatch({bool paid = true, PayMethod? method}) =>
    customerRequestOf(
      status: InstantStatus.noMatch,
      committed: true,
      candidates: const [],
      round: 3,
    ).copyWith(
      paid: paid,
      payMethod: method,
      invitedTotal: 7,
      roundsWithInvites: 3,
    );

Finder get _more => find.byKey(const Key('no-match-more'));
Finder get _bookNormally => find.byKey(const Key('no-match-book-normally'));
Finder get _cancel => find.byKey(const Key('no-match-cancel'));

Future<void> _end(WidgetTester tester, InstantCustomerWorld w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await w.repo.dispose();
}

void main() {
  testWidgets('copy uses invitedTotal, roundsWithInvites, amountVnd and the '
      'method ("MoMo", "tài khoản đã chuyển")', (tester) async {
    for (final (method, to) in [
      (PayMethod.momo, 'MoMo'),
      (PayMethod.bankQr, 'tài khoản đã chuyển'),
    ]) {
      final w = InstantCustomerWorld();
      await pumpInstantFlow(tester, w, request: _noMatch(method: method));
      expect(find.byType(NoMatchView), findsOneWidget);
      final code = tester.widget<ScreenCode>(
        find
            .descendant(
              of: find.byType(NoMatchView),
              matching: find.byType(ScreenCode),
            )
            .first,
      );
      expect(code.code, ScreenCodes.instantNoMatch);
      expect(find.text('Chưa tìm được nhiếp ảnh gia'), findsOneWidget);
      expect(
        find.text(
          'Bạn đã mời 7 người trong 3 lượt; gần bạn lúc này ít người đang '
          'sẵn sàng.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(EscrowNotice),
          matching: find.text(
            '690.000₫ vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì '
            'hoàn đủ về $to.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _cancel,
          matching: find.text('Huỷ yêu cầu và hoàn 690.000₫'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _more, matching: find.text('Chọn thêm người')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _bookNormally,
          matching: find.text('Đặt lịch thường với người bạn chọn'),
        ),
        findsOneWidget,
      );
      // One gradient button: "Chọn thêm người".
      expect(find.byType(CtaSurface), findsOneWidget);
      expect(
        find.descendant(of: _more, matching: find.byType(CtaSurface)),
        findsOneWidget,
      );
      await _end(tester, w);
    }
  });

  testWidgets('an unpaid no_match (every #140 backend run) shows no held line '
      'and "Huỷ yêu cầu" without an amount', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _noMatch(paid: false));
    expect(find.byType(EscrowNotice), findsNothing);
    expect(find.textContaining('690.000₫'), findsNothing);
    expect(
      find.descendant(of: _cancel, matching: find.text('Huỷ yêu cầu')),
      findsOneWidget,
    );
    await _end(tester, w);
  });

  testWidgets('"Chọn thêm người" calls nextCandidates', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _noMatch(method: PayMethod.momo));
    await tester.tap(_more);
    await settleInstant(tester);
    expect(w.repo.callsOf('nextCandidates').single.args, {
      'requestId': 'req1',
      'skipped': <String>[],
    });
    await _end(tester, w);
  });

  testWidgets('a failed "Chọn thêm người" says so', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('nextCandidates', 'network');
    await pumpInstantFlow(tester, w, request: _noMatch(method: PayMethod.momo));
    await tester.tap(_more);
    await settleInstant(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(NoMatchView), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('"Đặt lịch thường với người bạn chọn" opens /action', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    final router = await pumpInstantFlow(
      tester,
      w,
      request: _noMatch(method: PayMethod.momo),
    );
    await tester.tap(_bookNormally);
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/action');
    // The request stays open (Decision 13): nothing was cancelled.
    expect(w.repo.callsOf('cancel'), isEmpty);
    await _end(tester, w);
  });

  testWidgets('"Huỷ yêu cầu và hoàn 690.000₫" opens the cancel sheet', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _noMatch(method: PayMethod.momo));
    await tester.tap(_cancel);
    await settleInstant(tester);
    expect(find.text('Huỷ chụp ngay?'), findsOneWidget);
    expect(w.repo.callsOf('cancel').single.args, {
      'requestId': 'req1',
      'dryRun': true,
    });
    await _end(tester, w);
  });

  testWidgets('no_match never shows a refund as done', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _noMatch(method: PayMethod.momo));
    // Time passes: still held, still no_match, no refund line.
    await w.base.wait(tester, const Duration(minutes: 30));
    expect(find.byType(NoMatchView), findsOneWidget);
    expect(find.text('Đã huỷ yêu cầu'), findsNothing);
    expect(find.textContaining('Tiền thường về'), findsNothing);
    expect(find.textContaining('Đã hoàn'), findsNothing);
    expect(w.repo.callsOf('cancel'), isEmpty);
    await _end(tester, w);
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    for (final brightness in Brightness.values) {
      final w = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        w,
        request: _noMatch(method: PayMethod.bankQr),
        viewSize: const Size(320, 640),
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _end(tester, w);
    }
  });
}
