import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/features/earnings/earnings_controller.dart';

import '../../support/earnings_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<EarningsWorld> _open(
  WidgetTester tester, {
  void Function(EarningsWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
}) async {
  usePhone(tester, width: width, height: 900);
  final w = EarningsWorld();
  await w.init();
  w.repo.setAccount(w.account());
  seed?.call(w);
  await tester.pumpWidget(w.app(textScale: textScale));
  await tester.pumpAndSettle();
  return w;
}

void main() {
  testWidgets('the three totals show in one row at 320 dp and text scale 1.3', (
    tester,
  ) async {
    await _open(
      tester,
      width: 320,
      textScale: 1.3,
      seed: (w) => w.repo.emitSummary(
        const EarningsSummary(
          heldVnd: 3950000,
          soonVnd: 900000,
          receivedVnd: 12400000,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3,95M'), findsOneWidget);
    expect(find.text('0,9M'), findsOneWidget);
    expect(find.text('12,4M'), findsOneWidget);
    final tops = {
      for (final l in ['Đang giữ', 'Sắp nhận', 'Đã nhận'])
        tester.getRect(find.widgetWithText(StatTile, l)).top,
    };
    expect(tops.length, 1, reason: 'same row');
  });

  testWidgets('each total tile reads the full amount', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(
      tester,
      seed: (w) => w.repo.emitSummary(
        const EarningsSummary(heldVnd: 3950000, soonVnd: 900000),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp(r'3\.950\.000₫,\s*Đang giữ')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'900\.000₫,\s*Sắp nhận')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('rows group by month newest first', (tester) async {
    await _open(
      tester,
      seed: (w) => w.repo.emitItems([
        w.item('a', day: '2026-10-12'),
        w.item('b', day: '2026-10-01'),
        w.item('c', day: '2026-09-20', name: 'Thu Hà'),
        w.item('d', day: '2025-12-02', name: 'Minh Khoa'),
      ]),
    );
    expect(find.text('Các khoản'), findsOneWidget);
    expect(find.text('Tháng 10'), findsOneWidget);
    expect(find.text('Tháng 9'), findsOneWidget);
    await tester.ensureVisible(find.text('Tháng 12/2025'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 12/2025'), findsOneWidget);
    final y = tester.getTopLeft(find.text('Tháng 9')).dy;
    expect(y, lessThan(tester.getTopLeft(find.text('Tháng 12/2025')).dy));
  });

  testWidgets('a held row shows Đang giữ', (tester) async {
    await _open(tester, seed: (w) => w.repo.emitItems([w.item('a')]));
    expect(find.text('Lan Anh · Chân dung 2h'), findsOneWidget);
    expect(find.text('T2 12/10'), findsOneWidget);
    expect(find.text('450K'), findsOneWidget);
    expect(find.text('ĐANG GIỮ'), findsOneWidget);
  });

  testWidgets('a released row shows Chờ chi trả', (tester) async {
    await _open(
      tester,
      seed: (w) =>
          w.repo.emitItems([w.item('a', state: EarningState.released)]),
    );
    expect(find.text('CHỜ CHI TRẢ'), findsOneWidget);
  });

  testWidgets('a paid row shows Đã chuyển with its date', (tester) async {
    await _open(
      tester,
      seed: (w) => w.repo.emitItems([
        w.item(
          'a',
          state: EarningState.paidOut,
          // 12/10 in Vietnam.
          paidOutAt: DateTime.utc(2026, 10, 12, 3),
        ),
      ]),
    );
    expect(find.text('ĐÃ CHUYỂN 12/10'), findsOneWidget);
  });

  testWidgets('a disputed row shows Đang khiếu nại and the reason', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) => w.repo.emitItems([
        w.item(
          'a',
          state: EarningState.disputed,
          holdReason: holdReasonDispute,
        ),
        w.item(
          'b',
          state: EarningState.released,
          holdReason: holdReasonPayoutOnHold,
        ),
      ]),
    );
    expect(find.text('ĐANG KHIẾU NẠI'), findsOneWidget);
    expect(
      find.text('Lý do: Khách đã báo vấn đề, đang chờ xử lý'),
      findsOneWidget,
    );
    expect(find.text('Lý do: Lô chi trả đang tạm giữ'), findsOneWidget);
  });

  testWidgets('an unknown hold reason code shows no free text', (tester) async {
    await _open(
      tester,
      seed: (w) => w.repo.emitItems([
        w.item('a', state: EarningState.released, holdReason: 'Khách chê xấu'),
      ]),
    );
    expect(find.textContaining('Lý do'), findsNothing);
    expect(find.textContaining('Khách chê'), findsNothing);
  });

  testWidgets('without an account the add-account card opens S06.06', (
    tester,
  ) async {
    final w = await _open(tester, seed: (w) => w.repo.setAccount(null));
    expect(find.text('Thêm tài khoản để nhận tiền'), findsOneWidget);
    await tester.tap(_key('earnings-add-account'));
    await tester.pumpAndSettle();
    expect(find.text('stub /work/earnings/account'), findsOneWidget);
    expect(w.router.state.uri.path, '/work/earnings/account');
  });

  testWidgets('with an account the card is hidden', (tester) async {
    await _open(tester);
    expect(find.text('Thêm tài khoản để nhận tiền'), findsNothing);
  });

  testWidgets('a failed last payout shows the banner', (tester) async {
    await _open(
      tester,
      seed: (w) =>
          w.repo.emitSummary(const EarningsSummary(lastPayoutFailed: true)),
    );
    expect(find.text('Chuyển khoản lỗi, kiểm tra tài khoản'), findsOneWidget);
    await tester.tap(_key('earnings-payout-failed'));
    await tester.pumpAndSettle();
    expect(find.text('stub /work/earnings/account'), findsOneWidget);
  });

  testWidgets('the banner goes once the account was saved after the failure', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) {
        w.repo.setAccount(
          w.account(updatedAt: earningsNow.add(const Duration(hours: 1))),
        );
        w.repo.emitSummary(
          EarningsSummary(lastPayoutFailed: true, lastPayoutAt: earningsNow),
        );
      },
    );
    expect(find.text('Chuyển khoản lỗi, kiểm tra tài khoản'), findsNothing);
  });

  testWidgets('the banner stays when the account is older than the failure', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) {
        w.repo.setAccount(
          w.account(updatedAt: earningsNow.subtract(const Duration(days: 1))),
        );
        w.repo.emitSummary(
          EarningsSummary(lastPayoutFailed: true, lastPayoutAt: earningsNow),
        );
      },
    );
    expect(find.text('Chuyển khoản lỗi, kiểm tra tài khoản'), findsOneWidget);
  });

  testWidgets('a row amount is truncated, never rounded up', (tester) async {
    await _open(
      tester,
      seed: (w) => w.repo.emitItems([w.item('a', amount: 1999999)]),
    );
    expect(find.text('1,99M'), findsOneWidget);
    expect(find.text('2M'), findsNothing);
  });

  testWidgets('no failed payout, no banner', (tester) async {
    await _open(tester);
    expect(find.text('Chuyển khoản lỗi, kiểm tra tài khoản'), findsNothing);
  });

  testWidgets('the settings icon opens S06.06', (tester) async {
    await _open(tester);
    expect(find.byTooltip('Tài khoản nhận tiền'), findsOneWidget);
    await tester.tap(find.byTooltip('Tài khoản nhận tiền'));
    await tester.pumpAndSettle();
    expect(find.text('stub /work/earnings/account'), findsOneWidget);
  });

  testWidgets('tapping a booking row opens its detail and logs '
      'earnings_item_open', (tester) async {
    final w = await _open(tester, seed: (w) => w.repo.emitItems([w.item('a')]));
    expect(w.events.first.$1, 'earnings_open');
    expect(w.events.where((e) => e.$1 == 'earnings_open'), hasLength(1));
    await tester.tap(find.text('Lan Anh · Chân dung 2h'));
    await tester.pumpAndSettle();
    expect(find.text('stub /b/b-a'), findsOneWidget);
    expect(w.events.last.$1, 'earnings_item_open');
    expect(w.events.last.$2, {'state': 'held'});
  });

  testWidgets('a row without a customer name says Khách', (tester) async {
    await _open(tester, seed: (w) => w.repo.emitItems([w.item('a', name: '')]));
    expect(find.text('Khách · Chân dung 2h'), findsOneWidget);
  });

  testWidgets('no rows shows the empty state and zero totals', (tester) async {
    await _open(tester);
    expect(find.text('Chưa có khoản thu nào'), findsOneWidget);
    expect(find.text('0₫'), findsNWidgets(3));
  });

  testWidgets('a cached summary shows the offline banner', (tester) async {
    await _open(
      tester,
      seed: (w) => w.repo.emitSummary(const EarningsSummary(fromCache: true)),
    );
    expect(find.byType(OfflineBanner), findsOneWidget);
  });

  testWidgets('a live summary shows no offline banner', (tester) async {
    await _open(tester);
    expect(find.byType(OfflineBanner), findsNothing);
  });

  testWidgets('Xem thêm raises the limit', (tester) async {
    final w = await _open(
      tester,
      seed: (w) => w.repo.emitItems([
        for (var i = 0; i < 40; i++)
          w.item(
            'r$i',
            day: '2026-10-${(28 - i % 28).toString().padLeft(2, '0')}',
          ),
      ]),
    );
    expect(find.byType(EarningRow, skipOffstage: false), findsNWidgets(30));
    await tester.ensureVisible(_key('earnings-more'));
    await tester.pumpAndSettle();
    await tester.tap(_key('earnings-more'));
    await tester.pumpAndSettle();
    expect(find.byType(EarningRow, skipOffstage: false), findsNWidgets(40));
    expect(_key('earnings-more'), findsNothing);
    expect(w.events.where((e) => e.$1 == 'earnings_open'), hasLength(1));
  });

  testWidgets('a short page has no Xem thêm', (tester) async {
    await _open(tester, seed: (w) => w.repo.emitItems([w.item('a')]));
    expect(_key('earnings-more'), findsNothing);
  });

  testWidgets('there is no primary button', (tester) async {
    await _open(tester, seed: (w) => w.repo.emitItems([w.item('a')]));
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('long rows fit at 320 dp and text scale 1.3', (tester) async {
    await _open(
      tester,
      width: 320,
      textScale: 1.3,
      seed: (w) => w.repo.emitItems([
        w.item(
          'a',
          state: EarningState.disputed,
          holdReason: holdReasonDispute,
          name: 'Nguyễn Thị Minh Khoa',
          label: 'Kỷ yếu nửa ngày trọn gói',
        ),
        w.item(
          'b',
          state: EarningState.paidOut,
          paidOutAt: DateTime.utc(2026, 10, 12),
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  group('groupByMonth', () {
    EarningItem it(String id, String day) => EarningItem(
      id: id,
      subjectType: 'booking',
      subjectId: id,
      counterpartName: '',
      subjectLabel: '',
      day: day,
      amountVnd: 1,
      state: EarningState.held,
    );

    test('keeps day order inside a month and month order as given', () {
      final g = groupByMonth([
        it('a', '2026-10-12'),
        it('b', '2026-10-01'),
        it('c', '2026-09-30'),
        it('d', '2025-12-02'),
      ]);
      expect(g.map((e) => e.monthKey), ['2026-10', '2026-09', '2025-12']);
      expect(g.first.items.map((e) => e.id), ['a', 'b']);
    });

    test('empty list gives no groups', () {
      expect(groupByMonth(const []), isEmpty);
    });
  });
}
