// S13.03 (`#S13.03`): who was invited and what each of them did, the
// countdown to the latest pending expiry, the waiting loader, "Huỷ yêu cầu".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/waiting_view.dart';

import '../../support/instant_customer_world.dart';

/// Mock rows: Minh Trí and Hồng Nhung looking, Quốc Bảo busy.
InstantOfferRow _row(
  String id,
  String name,
  OfferOutcome outcome, {
  int tomatoPct = 97,
  int reviewCount = 58,
  int etaMinutes = 9,
  Duration? expiresIn = const Duration(seconds: 42),
}) => InstantOfferRow(
  photographerId: id,
  name: name,
  tomatoPct: tomatoPct,
  reviewCount: reviewCount,
  etaMinutes: etaMinutes,
  outcome: outcome,
  expiresAt: expiresIn == null ? null : instantNow.add(expiresIn),
);

final _mockRows = [
  _row('p1', 'Minh Trí', OfferOutcome.pending),
  _row(
    'p2',
    'Hồng Nhung',
    OfferOutcome.pending,
    tomatoPct: 91,
    etaMinutes: 14,
    expiresIn: const Duration(seconds: 30),
  ),
  _row('p3', 'Quốc Bảo', OfferOutcome.unavailable, expiresIn: null),
];

/// The round of [offers] (the mock's by default); [paid] as from #202 on
/// (#140 requests are never paid).
InstantRequest _waiting([List<InstantOfferRow>? offers, bool paid = true]) =>
    customerRequestOf(
      status: InstantStatus.searching,
      committed: true,
    ).copyWith(
      paid: paid,
      offers: offers ?? _mockRows,
      invitedTotal: 2,
      roundsWithInvites: 1,
      searchDeadlineAt: instantNow.add(const Duration(minutes: 10)),
    );

/// The chip text in the row of photographer [id].
Finder _chipOf(String id, String chip) => find.descendant(
  of: find.byKey(ValueKey('waiting-row-$id')),
  matching: find.text(chip),
);

Future<void> _end(WidgetTester tester, InstantCustomerWorld w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await w.repo.dispose();
}

void main() {
  testWidgets(
    'rows show Đang xem / Đã từ chối / Hết hạn / Không tính from the offers '
    'data',
    (tester) async {
      final w = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        w,
        request: _waiting([
          _row('p1', 'Minh Trí', OfferOutcome.pending),
          _row('p2', 'Hồng Nhung', OfferOutcome.declined),
          _row('p4', 'Thu Hà', OfferOutcome.expired),
          _row('p3', 'Quốc Bảo', OfferOutcome.unavailable, expiresIn: null),
        ]),
      );
      expect(find.byType(WaitingView), findsOneWidget);
      final code = tester.widget<ScreenCode>(
        find
            .descendant(
              of: find.byType(WaitingView),
              matching: find.byType(ScreenCode),
            )
            .first,
      );
      expect(code.code, ScreenCodes.instantSearching);
      expect(find.text('Đang chờ trả lời'), findsOneWidget);
      // Three were invited; Quốc Bảo was busy when the invite went out.
      expect(find.text('Đã gửi lời mời cho 3 người'), findsOneWidget);
      expect(_chipOf('p1', 'Đang xem'), findsOneWidget);
      expect(_chipOf('p2', 'Đã từ chối'), findsOneWidget);
      expect(_chipOf('p4', 'Hết hạn'), findsOneWidget);
      expect(_chipOf('p3', 'Không tính'), findsOneWidget);
      // Meta: tomato percent and ETA ("97% · khoảng 9 phút").
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('waiting-row-p1')),
          matching: find.byWidgetPredicate(
            (wd) =>
                wd is MetaLine &&
                metaPartsText(wd.parts) == '97% · khoảng 9 phút',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Chưa ai nhận thì bạn chọn tiếp trong 5 người khác, không trả thêm. '
          'Tiền vẫn được giữ cho tới khi có người nhận hoặc bạn huỷ.',
        ),
        findsOneWidget,
      );
      await _end(tester, w);
    },
  );

  testWidgets('fewer than five reviews: only the ETA', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _waiting([
        _row('p4', 'Thu Hà', OfferOutcome.pending, reviewCount: 3),
      ]),
    );
    expect(
      find.byWidgetPredicate(
        (wd) => wd is MetaLine && metaPartsText(wd.parts) == 'khoảng 9 phút',
      ),
      findsOneWidget,
    );
    await _end(tester, w);
  });

  testWidgets('unavailable row reads "Quốc Bảo vừa nhận việc khác"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _waiting());
    // Mock: the bold name, then "vừa nhận việc khác" (the name once).
    final row = find.byKey(const ValueKey('waiting-row-p3'));
    expect(
      find.descendant(of: row, matching: find.text('vừa nhận việc khác')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('Quốc Bảo')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Quốc Bảo vừa nhận việc khác, Không tính'),
      findsOneWidget,
    );
    await _end(tester, w);
    handle.dispose();
  });

  testWidgets('unpaid (#140): the note leaves out the held money', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _waiting(null, false));
    expect(
      find.text('Chưa ai nhận thì bạn chọn tiếp trong 5 người khác.'),
      findsOneWidget,
    );
    expect(find.textContaining('Tiền vẫn được giữ'), findsNothing);
    await _end(tester, w);
  });

  testWidgets('a row is announced only when its state changes', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _waiting([
        _row('p1', 'Minh Trí', OfferOutcome.pending),
        _row('p2', 'Hồng Nhung', OfferOutcome.declined),
        _row('p3', 'Quốc Bảo', OfferOutcome.unavailable, expiresIn: null),
      ]),
    );
    bool live(String id) =>
        tester
            .widget<Semantics>(find.byKey(ValueKey('waiting-row-$id')))
            .properties
            .liveRegion ??
        false;
    // As first shown: nothing to announce.
    expect([live('p1'), live('p2'), live('p3')], [false, false, false]);
    w.repo.emitRequest(
      'req1',
      _waiting([
        _row('p1', 'Minh Trí', OfferOutcome.declined),
        _row('p2', 'Hồng Nhung', OfferOutcome.declined),
        _row('p3', 'Quốc Bảo', OfferOutcome.unavailable, expiresIn: null),
      ]),
    );
    await settleInstant(tester);
    expect([live('p1'), live('p2'), live('p3')], [true, false, false]);
    await _end(tester, w);
  });

  testWidgets('the countdown reads the time to the latest pending expiry', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _waiting());
    // Minh Trí's invite ends at +42 s, Hồng Nhung's at +30 s.
    expect(
      find.text('Ai nhận trước sẽ tới chỗ bạn. Mỗi lời mời còn 0:42.'),
      findsOneWidget,
    );
    await w.base.wait(tester, const Duration(seconds: 10));
    expect(
      find.text('Ai nhận trước sẽ tới chỗ bạn. Mỗi lời mời còn 0:32.'),
      findsOneWidget,
    );
    await _end(tester, w);
  });

  testWidgets('rows have semantics "{name} đang xem lời mời" while pending', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _waiting([
        _row('p1', 'Minh Trí', OfferOutcome.pending),
        _row('p2', 'Hồng Nhung', OfferOutcome.declined),
      ]),
    );
    expect(find.bySemanticsLabel('Minh Trí đang xem lời mời'), findsOneWidget);
    expect(find.bySemanticsLabel('Hồng Nhung đang xem lời mời'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Hồng Nhung.*Đã từ chối')),
      findsOneWidget,
    );
    await _end(tester, w);
    handle.dispose();
  });

  testWidgets('loader is static under reduced motion', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _waiting());
    final loader = find.descendant(
      of: find.byType(WaitingView),
      matching: find.byType(SignatureLoader),
    );
    expect(loader, findsOneWidget);
    expect(tester.widget<SignatureLoader>(loader).wave, LoaderWave.vibration);
    double closure() => tester
        .widget<ApertureMark>(
          find.descendant(of: loader, matching: find.byType(ApertureMark)),
        )
        .closure;
    expect(closure(), 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(closure(), 0);
    expect(tester.hasRunningAnimations, isFalse);
    await _end(tester, w);
  });

  testWidgets('the loader waits only while someone is still looking', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _waiting(),
      disableAnimations: false,
    );
    final loader = find.descendant(
      of: find.byType(WaitingView),
      matching: find.byType(SignatureLoader),
    );
    expect(tester.widget<SignatureLoader>(loader).active, isTrue);
    w.repo.emitRequest(
      'req1',
      _waiting([
        _row('p1', 'Minh Trí', OfferOutcome.declined),
        _row('p2', 'Hồng Nhung', OfferOutcome.expired),
      ]),
    );
    await settleInstant(tester);
    expect(tester.widget<SignatureLoader>(loader).active, isFalse);
    await _end(tester, w);
  });

  testWidgets('"Huỷ yêu cầu" opens the cancel sheet', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(tester, w, request: _waiting());
    await tester.tap(find.byKey(const Key('waiting-cancel')));
    await settleInstant(tester);
    expect(find.text('Huỷ chụp ngay?'), findsOneWidget);
    expect(w.repo.callsOf('cancel').single.args, {
      'requestId': 'req1',
      'dryRun': true,
    });
    await _end(tester, w);
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    for (final brightness in Brightness.values) {
      final w = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        w,
        request: _waiting([
          for (final r in _mockRows)
            r.copyWith(name: '${r.name} Nguyễn Hoàng Phương'),
          _row('p4', 'Thu Hà Trần Ngọc', OfferOutcome.declined),
          _row('p5', 'Gia Huy Lê Minh', OfferOutcome.expired),
        ]),
        viewSize: const Size(320, 640),
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _end(tester, w);
    }
  });
}
