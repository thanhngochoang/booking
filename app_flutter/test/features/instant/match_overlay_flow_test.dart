// S13.04 on the customer side (Decision 5): the match moment shows when the
// flow screen sees `searching → assigned`, or opens on an assignment less
// than 60 s old (a push tap); otherwise S13.05 at once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';

import '../../support/instant_customer_world.dart';

InstantRequest _searching() =>
    customerRequestOf(
      status: InstantStatus.searching,
      committed: true,
    ).copyWith(
      offers: const [
        InstantOfferRow(
          photographerId: 'p1',
          name: 'Minh Trí',
          outcome: OfferOutcome.pending,
        ),
      ],
      searchDeadlineAt: instantNow.add(const Duration(minutes: 10)),
    );

/// Minh Trí accepted [ago] before [instantNow], 9 minutes away.
InstantRequest _assigned({Duration ago = Duration.zero}) =>
    customerRequestOf(status: InstantStatus.assigned, committed: true).copyWith(
      photographerId: 'p1',
      photographer: const InstantParty(
        id: 'p1',
        name: 'Minh Trí',
        avatarUrl: 'https://img/p1',
      ),
      customerAvatarUrl: 'https://img/cus1',
      etaMinutes: 9,
      assignedAt: instantNow.subtract(ago),
    );

String? _code(WidgetTester tester) => tester
    .widget<ScreenCode>(
      find
          .descendant(
            of: find.byType(InstantFlowScreen),
            matching: find.byType(ScreenCode),
          )
          .first,
    )
    .code;

Future<void> _end(WidgetTester tester, InstantCustomerWorld w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await w.repo.dispose();
}

void main() {
  testWidgets('overlay only on transition or fresh assignment', (tester) async {
    // searching → assigned while open: the overlay.
    var w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _searching());
    expect(_code(tester), ScreenCodes.instantSearching);
    w.repo.emitRequest('req1', _assigned());
    await settleInstant(tester);
    expect(find.byType(MatchOverlay), findsOneWidget);
    expect(_code(tester), ScreenCodes.instantMatched);
    final overlay = tester.widget<MatchOverlay>(find.byType(MatchOverlay));
    expect(overlay.name, 'Minh Trí');
    expect(
      overlay.body,
      'Minh Trí đã nhận lời mời của bạn và đang chuẩn bị tới Cổng Trương '
      'Định, khoảng 9 phút.',
    );
    expect(overlay.theirAvatarUrl, 'https://img/p1');
    expect(overlay.myAvatarUrl, 'https://img/cus1');
    await _end(tester, w);

    // Opened (push tap) on an assignment 20 s old: the overlay.
    w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _assigned(ago: const Duration(seconds: 20)),
    );
    expect(find.byType(MatchOverlay), findsOneWidget);
    await _end(tester, w);

    // Opened on an assignment 2 minutes old: S13.05 directly.
    w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _assigned(ago: const Duration(minutes: 2)),
    );
    expect(find.byType(MatchOverlay), findsNothing);
    expect(_code(tester), ScreenCodes.instantTracking);
    await _end(tester, w);

    // en_route after the overlay was dismissed: no second overlay.
    w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _searching());
    w.repo.emitRequest('req1', _assigned());
    await settleInstant(tester);
    await tester.tap(find.byKey(const Key('match-continue')));
    await settleInstant(tester);
    w.repo.emitRequest(
      'req1',
      _assigned().copyWith(status: InstantStatus.enRoute),
    );
    await settleInstant(tester);
    expect(find.byType(MatchOverlay), findsNothing);
    await _end(tester, w);
  });

  testWidgets('"Tiếp tục" reveals S13.05', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _searching());
    w.repo.emitRequest('req1', _assigned());
    await settleInstant(tester);
    await tester.tap(find.byKey(const Key('match-continue')));
    await settleInstant(tester);
    expect(find.byType(MatchOverlay), findsNothing);
    expect(_code(tester), ScreenCodes.instantTracking);
    await _end(tester, w);
  });

  testWidgets('auto-continue after 3 s', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _searching());
    w.repo.emitRequest('req1', _assigned());
    await settleInstant(tester);
    expect(find.byType(MatchOverlay), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MatchOverlay), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await settleInstant(tester);
    expect(find.byType(MatchOverlay), findsNothing);
    expect(_code(tester), ScreenCodes.instantTracking);
    await _end(tester, w);
  });

  testWidgets('a request that ends under the overlay drops it', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _searching());
    w.repo.emitRequest('req1', _assigned());
    await settleInstant(tester);
    w.repo.emitRequest(
      'req1',
      _assigned().copyWith(status: InstantStatus.cancelledByCustomer),
    );
    await settleInstant(tester);
    expect(find.byType(MatchOverlay), findsNothing);
    expect(_code(tester), ScreenCodes.instantCancel);
    await _end(tester, w);
  });
}
