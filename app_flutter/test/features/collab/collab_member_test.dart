// S27.06 photographer view ("S27.06-me", #151 Task 9).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/features/collab/collab_member_view.dart';

import '../../support/collab_world.dart';
import '../../support/meta_finders.dart';
import '../../support/recruit_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Finder _code(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

Finder _inKey(String k, Finder f) => find.descendant(of: _key(k), matching: f);

/// Dũng collaborates with Studio Cúc and Studio Gió, has an invite from
/// Studio Nắng (6 days left), a pending offer of Cúc (4 hours left), a pay
/// Cúc reported on 07/10 by transfer and one Gió's pay he received.
CollabWorld _me({bool empty = false}) {
  final c = CollabWorld(studio: false);
  if (empty) return c;
  c.world.collabs
    ..seedCollaboration(makeCollaboration())
    ..seedCollaboration(
      makeCollaboration(studioId: 'gio', studioName: 'Studio Gió'),
    )
    ..seedCollaboration(
      makeCollaboration(
        studioId: 'nang',
        studioName: 'Studio Nắng',
        status: CollabStatus.invited,
        activeAt: recruitNow.subtract(const Duration(days: 1)),
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b2',
        offerStatus: OfferStatus.pending,
        offerExpiresAt: recruitNow.add(const Duration(hours: 4)),
        agreedFee: 800000,
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b7',
        day: '2026-10-05',
        payStatus: PayStatus.paidReported,
        payDueAt: recruitNow.subtract(const Duration(days: 15)),
        paidOn: '2026-10-07',
        payMethod: CollabPayMethod.bank,
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b8',
        studioId: 'gio',
        studioName: 'Studio Gió',
        day: '2026-10-02',
        payStatus: PayStatus.received,
        payDueAt: recruitNow.subtract(const Duration(days: 18)),
      ),
    );
  return c;
}

void main() {
  testWidgets('sections: offers, studios "{n} / tối đa 5", invites and pay', (
    tester,
  ) async {
    await _me().pump(tester);
    expect(_code('S27.06'), findsOneWidget);
    expect(find.byType(CollabMemberView), findsOneWidget);
    expect(find.text('Việc chờ nhận'), findsOneWidget);
    expect(find.text('Studio cộng tác'), findsOneWidget);
    expect(find.text('2 / tối đa 5'), findsOneWidget);
    expect(findMeta('Từ 10/2026 · 1 việc đang giao'), findsOneWidget);
    expect(findMeta('Từ 10/2026 · 0 việc đang giao'), findsOneWidget);
    expect(find.text('Lời mời'), findsOneWidget);
    expect(findMeta('Mời cộng tác · hết hạn sau 6 ngày'), findsOneWidget);
    expect(find.text('Thù lao'), findsOneWidget);
  });

  testWidgets('pending offer card shows "Còn {time}" and opens S27.07', (
    tester,
  ) async {
    await _me().pump(tester);
    expect(_inKey('collab-offer-b2', find.text('CÒN 4 GIỜ')), findsOneWidget);
    expect(_inKey('collab-offer-b2', find.text('800.000₫')), findsOneWidget);
    await tester.tap(_key('collab-offer-b2'));
    await CollabWorld.settle(tester);
    expect(_code('S27.07'), findsOneWidget);
    expect(find.text('Nhận việc cộng tác'), findsOneWidget);
  });

  testWidgets('query offer=<id> opens S27.07 on load', (tester) async {
    await _me().pump(tester, location: '/collab?offer=b2');
    expect(_code('S27.07'), findsOneWidget);
  });

  testWidgets('"Xem & nhận" opens the accept sheet with the terms; confirm '
      'disabled until agreed; confirm calls respondInvite(accept: true, '
      'acceptTerms: true)', (tester) async {
    final c = _me();
    await c.pump(tester);
    await tester.ensureVisible(_key('collab-accept-nang'));
    await tester.tap(_key('collab-accept-nang'));
    await CollabWorld.settle(tester);
    expect(find.text('Cộng tác với Studio Nắng'), findsOneWidget);
    expect(find.text('Điều khoản cộng tác'), findsOneWidget);
    AppButton confirm() =>
        tester.widget<AppButton>(_key('collab-accept-confirm'));
    expect(confirm().label, 'Nhận lời cộng tác');
    expect(confirm().onPressed, isNull);
    await tester.tap(_key('collab-terms-agree'));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);
    await tester.tap(_key('collab-accept-confirm'));
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'respondCollabInvite', {
      'studioId': 'nang',
      'accept': true,
      'acceptTerms': true,
    });
    expect(_key('collab-accept-sheet'), findsNothing);
  });

  testWidgets('"Từ chối" calls respondInvite(accept: false)', (tester) async {
    final c = _me();
    await c.pump(tester);
    await tester.ensureVisible(_key('collab-decline-nang'));
    await tester.tap(_key('collab-decline-nang'));
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'respondCollabInvite', {
      'studioId': 'nang',
      'accept': false,
      'acceptTerms': false,
    });
  });

  testWidgets('reported pay shows "Studio báo đã trả {date} ({method})" with '
      '"Chưa nhận" (confirm sheet) and "Đã nhận"', (tester) async {
    final c = _me();
    await c.pump(tester);
    expect(
      _inKey(
        'collab-mypay-b7_dung',
        find.textContaining('Studio báo đã trả 07/10 (Chuyển khoản)'),
      ),
      findsOneWidget,
    );
    expect(
      _inKey('collab-mypay-b8_dung', find.text('ĐÃ NHẬN')),
      findsOneWidget,
    );

    await tester.ensureVisible(_key('collab-not-received-b7_dung'));
    await tester.tap(_key('collab-not-received-b7_dung'));
    await CollabWorld.settle(tester);
    expect(find.text('Báo chưa nhận thù lao?'), findsOneWidget);
    expect(
      find.text(
        'Studio và bộ phận hỗ trợ được báo. Ứng dụng không bảo lãnh khoản này.',
      ),
      findsOneWidget,
    );
    final red = find.widgetWithText(FilledButton, 'Chưa nhận');
    expect(
      tester
          .widget<FilledButton>(red)
          .style
          ?.backgroundColor
          ?.resolve(const {}),
      AppColors.error,
    );
    await tester.tap(red);
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'confirmCollabPay', {
      'bookingId': 'b7',
      'received': false,
    });
  });

  testWidgets('"Đã nhận" confirms the pay', (tester) async {
    final c = _me();
    await c.pump(tester);
    await tester.ensureVisible(_key('collab-received-b7_dung'));
    await tester.tap(_key('collab-received-b7_dung'));
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'confirmCollabPay', {
      'bookingId': 'b7',
      'received': true,
    });
  });

  testWidgets('empty state text', (tester) async {
    await _me(empty: true).pump(tester);
    expect(
      find.text('Chưa có studio cộng tác. Xem tin ở Công việc → Tuyển thợ.'),
      findsOneWidget,
    );
  });

  testWidgets('no primary button', (tester) async {
    await _me().pump(tester);
    expect(find.byType(CtaSurface), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _me().pump(tester, size: const Size(320, 1600), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
