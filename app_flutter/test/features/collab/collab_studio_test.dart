// S27.06 studio view (#151 Task 9).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';
import 'package:photobooking/features/collab/collab_studio_view.dart';
import 'package:photobooking/features/studio/invite_member_sheet.dart';

import '../../support/collab_world.dart';
import '../../support/meta_finders.dart';
import '../../support/recruit_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Finder _code(String code) =>
    find.byWidgetPredicate((w) => w is ScreenCode && w.code == code);

/// Studio Cúc with three active collaborators (Dũng 600.000₫, Hòa without a
/// fee, Lan Phương 800.000₫), a pending invite to Hoàng Yến (5 days left)
/// and jobs: Dũng has one accepted and one pending offer; Hòa's job is due
/// (500.000₫), Lan's are disputed and reported, an old one of Dũng received.
CollabWorld _studio({bool businessVerified = false, int dueFee = 500000}) {
  final c = CollabWorld(businessVerified: businessVerified);
  final w = c.world;
  w.collabs
    ..seedCollaboration(makeCollaboration())
    ..seedCollaboration(
      makeCollaboration(
        collaboratorId: 'hoa',
        collaboratorName: 'Hòa',
        defaultFee: null,
      ),
    )
    ..seedCollaboration(
      makeCollaboration(
        collaboratorId: 'lan',
        collaboratorName: 'Lan Phương',
        defaultFee: 800000,
      ),
    )
    ..seedCollaboration(
      makeCollaboration(
        collaboratorId: 'yen',
        collaboratorName: 'Hoàng Yến',
        status: CollabStatus.invited,
        activeAt: recruitNow.subtract(const Duration(days: 2)),
      ),
    )
    ..seedJob(makeCollabJob(bookingId: 'b1'))
    ..seedJob(
      makeCollabJob(
        bookingId: 'b2',
        offerStatus: OfferStatus.pending,
        offerExpiresAt: recruitNow.add(const Duration(hours: 4)),
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b3',
        collaboratorId: 'hoa',
        collaboratorName: 'Hòa',
        serviceName: 'Cưới 4 giờ',
        day: '2026-10-12',
        agreedFee: dueFee,
        payStatus: PayStatus.due,
        payDueAt: recruitNow.subtract(const Duration(days: 1)),
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b4',
        collaboratorId: 'lan',
        collaboratorName: 'Lan Phương',
        payStatus: PayStatus.disputed,
        payDueAt: recruitNow.subtract(const Duration(days: 3)),
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b5',
        collaboratorId: 'lan',
        collaboratorName: 'Lan Phương',
        payStatus: PayStatus.paidReported,
        payDueAt: recruitNow.subtract(const Duration(days: 2)),
      ),
    )
    ..seedJob(
      makeCollabJob(
        bookingId: 'b6',
        payStatus: PayStatus.received,
        payDueAt: recruitNow.subtract(const Duration(days: 5)),
      ),
    );
  w.seedApplicant(id: 'dung', name: 'Dũng', tomatoPct: 95);
  w.seedApplicant(id: 'hoa', name: 'Hòa', tomatoPct: 88);
  w.seedApplicant(id: 'lan', name: 'Lan Phương', tomatoPct: 92);
  return c;
}

Future<void> _menu(WidgetTester tester, String uid, String item) async {
  await tester.ensureVisible(_key('collab-menu-$uid'));
  await tester.tap(_key('collab-menu-$uid'));
  await CollabWorld.settle(tester);
  await tester.tap(find.text(item).last);
  await CollabWorld.settle(tester);
}

void main() {
  testWidgets('meta shows 3/5 and actions left; 50 when businessVerified', (
    tester,
  ) async {
    final c = _studio();
    await c.pump(tester);
    expect(_code('S27.06'), findsOneWidget);
    expect(find.byType(CollabStudioView), findsOneWidget);
    expect(
      find.text('3/5 cộng tác viên · còn 8 thao tác hôm nay'),
      findsOneWidget,
    );

    final v = _studio(businessVerified: true);
    await v.pump(tester);
    expect(
      find.text('3/50 cộng tác viên · còn 8 thao tác hôm nay'),
      findsOneWidget,
    );
  });

  testWidgets('rows show "{jobs} việc đang giao · gợi ý {fee}/buổi"', (
    tester,
  ) async {
    await _studio().pump(tester);
    expect(
      findMeta('95% · 2 việc đang giao · gợi ý 600.000₫/buổi'),
      findsOneWidget,
    );
    expect(findMeta('88% · 0 việc đang giao'), findsOneWidget);
    expect(
      findMeta('92% · 0 việc đang giao · gợi ý 800.000₫/buổi'),
      findsOneWidget,
    );
  });

  testWidgets(
    'menu "Kết thúc cộng tác" opens a confirm sheet with a red button; '
    'member_busy shows "Còn việc được giao chưa xong."',
    (tester) async {
      final c = _studio();
      await c.pump(tester);
      await _menu(tester, 'hoa', 'Kết thúc cộng tác');
      expect(find.text('Kết thúc cộng tác với Hòa?'), findsOneWidget);
      expect(find.text('Mời lại được sau 3 ngày.'), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'Kết thúc cộng tác');
      expect(confirm, findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(confirm)
            .style
            ?.backgroundColor
            ?.resolve(const {}),
        AppColors.error,
      );

      c.world.collabs.failWith = const RecruitError(
        RecruitErrorCode.memberBusy,
      );
      await tester.tap(confirm.last);
      await CollabWorld.settle(tester);
      expect(find.text('Còn việc được giao chưa xong.'), findsOneWidget);

      c.world.collabs.failWith = null;
      await tester.tap(confirm.last);
      await CollabWorld.settle(tester);
      expectCall(c.world.collabs.calls.last, 'endCollaboration', {
        'collaboratorId': 'hoa',
      });
    },
  );

  testWidgets('member_busy for a collaborator with open jobs says how many', (
    tester,
  ) async {
    final c = _studio();
    await c.pump(tester);
    await _menu(tester, 'dung', 'Kết thúc cộng tác');
    c.world.collabs.failWith = const RecruitError(RecruitErrorCode.memberBusy);
    await tester.tap(find.widgetWithText(FilledButton, 'Kết thúc cộng tác'));
    await CollabWorld.settle(tester);
    expect(find.text('Còn 2 việc được giao chưa xong.'), findsOneWidget);
  });

  testWidgets('menu "Sửa thù lao gợi ý" saves through setDefaultFee', (
    tester,
  ) async {
    final c = _studio();
    await c.pump(tester);
    await _menu(tester, 'dung', 'Sửa thù lao gợi ý');
    expect(find.text('Thù lao gợi ý'), findsOneWidget);
    expect(find.text('Gợi ý sẵn khi giao việc cho Dũng'), findsOneWidget);
    await tester.enterText(_key('collab-fee-field'), '750000');
    await tester.pump();
    await tester.tap(_key('collab-fee-save'));
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'setCollabDefaultFee', {
      'collaboratorId': 'dung',
      'defaultFee': 750000,
    });
    expect(
      findMeta('95% · 2 việc đang giao · gợi ý 750.000₫/buổi'),
      findsOneWidget,
    );
  });

  testWidgets('menu "Nhắn tin" calls openChat and pushes /chat/<id>', (
    tester,
  ) async {
    final c = _studio();
    await c.pump(tester);
    await _menu(tester, 'dung', 'Nhắn tin');
    expectCall(c.world.collabs.calls.last, 'openCollabChat', {
      'collaboratorId': 'dung',
    });
    expect(find.text('stub /chat/collab_cuc_dung'), findsOneWidget);
  });

  testWidgets('"Đã trả" opens the paid sheet; confirm sends the chosen VN '
      'date and method', (tester) async {
    final c = _studio();
    await c.pump(tester);
    await tester.ensureVisible(_key('collab-paid-b3_hoa'));
    await tester.tap(_key('collab-paid-b3_hoa'));
    await CollabWorld.settle(tester);
    expect(find.text('Đã trả thù lao'), findsOneWidget);
    await tester.tap(_key('collab-paid-yesterday'));
    await tester.tap(_key('collab-method-cash'));
    await tester.pump();
    await tester.tap(_key('collab-paid-confirm'));
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'reportCollabPaid', {
      'bookingId': 'b3',
      'collaboratorId': 'hoa',
      // 21/10 10:00 in Vietnam: yesterday is the 20th.
      'paidOn': '2026-10-20',
      'method': 'cash',
    });
    expect(find.text('Đã trả thù lao'), findsNothing);
  });

  testWidgets('due/disputed/reported/received badges', (tester) async {
    // Mock `.badge` is uppercase.
    await _studio().pump(tester);
    Finder inRow(String job, String text) =>
        find.descendant(of: _key('collab-pay-$job'), matching: find.text(text));
    expect(find.text('Thù lao cần trả'), findsOneWidget);
    expect(inRow('b3_hoa', 'CẦN TRẢ'), findsOneWidget);
    expect(inRow('b4_lan', 'CHƯA NHẬN'), findsOneWidget);
    expect(inRow('b5_lan', 'ĐÃ BÁO TRẢ'), findsOneWidget);
    expect(inRow('b6_dung', 'ĐÃ NHẬN'), findsOneWidget);
    // "Đã trả" only where the studio still owes the record.
    expect(_key('collab-paid-b3_hoa'), findsOneWidget);
    expect(_key('collab-paid-b4_lan'), findsOneWidget);
    expect(_key('collab-paid-b5_lan'), findsNothing);
    expect(_key('collab-paid-b6_dung'), findsNothing);
  });

  testWidgets('tax note shows for a due job of 5.000.000₫ and hides after '
      'dismiss (prefs)', (tester) async {
    final small = _studio();
    await small.pump(tester);
    expect(_key('collab-tax-note'), findsNothing);

    final c = _studio(dueFee: 5000000);
    await c.pump(tester);
    expect(
      find.text(
        'Khoản từ 5.000.000đ/lần có thể phải khấu trừ thuế TNCN 10%; '
        'hãy hỏi kế toán.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(_key('collab-tax-dismiss'));
    await tester.tap(_key('collab-tax-dismiss'));
    await CollabWorld.settle(tester);
    expect(_key('collab-tax-note'), findsNothing);
    expect(c.prefs.getBool('collabTaxNoticeSeen:cuc'), isTrue);

    final again = _studio(dueFee: 5000000);
    await again.pump(
      tester,
      prefsValues: const {'collabTaxNoticeSeen:cuc': true},
    );
    expect(_key('collab-tax-note'), findsNothing);
  });

  testWidgets('"Sao chép bảng kê tháng 10 (CSV)" copies collabCsv of that '
      'month and shows the SnackBar', (tester) async {
    final c = _studio();
    await c.pump(tester);
    await tester.ensureVisible(find.text('Sao chép bảng kê tháng 10 (CSV)'));
    await tester.tap(find.text('Sao chép bảng kê tháng 10 (CSV)'));
    await CollabWorld.settle(tester);
    final csv = c.clipboard.single;
    final lines = csv.split('\r\n');
    expect(
      lines.first,
      'Ngày chụp,Dịch vụ,Cộng tác viên,Thù lao,Trạng thái,Ngày trả,Cách trả',
    );
    // The four jobs whose pay fell due in October, oldest due first.
    expect(lines, hasLength(5));
    expect(lines[1], startsWith('24/10/2026,Gói gia đình,Dũng,600000,Đã nhận'));
    expect(lines[4], startsWith('12/10/2026,Cưới 4 giờ,Hòa,500000,Cần trả'));
    expect(
      find.text('Đã sao chép bảng kê tháng 10. Dán vào bảng tính để xem.'),
      findsOneWidget,
    );
  });

  testWidgets('"Mời cộng tác viên" opens the S26.02 sheet in collaborator '
      'mode', (tester) async {
    await _studio().pump(tester);
    await tester.tap(_key('collab-invite'));
    await CollabWorld.settle(tester);
    expect(_code('S26.02'), findsOneWidget);
    final sheet = tester.widget<InviteMemberSheet>(
      find.byType(InviteMemberSheet),
    );
    expect(sheet.collaborator, isTrue);
    expect(
      find.descendant(
        of: find.byType(InviteMemberSheet),
        matching: find.text('Mời cộng tác viên'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pending invite shows its days left and "Huỷ" cancels it', (
    tester,
  ) async {
    final c = _studio();
    await c.pump(tester);
    expect(find.text('Đang chờ'), findsOneWidget);
    expect(findMeta('Lời mời đã gửi · hết hạn sau 5 ngày'), findsOneWidget);
    await tester.ensureVisible(_key('collab-cancel-yen'));
    await tester.tap(_key('collab-cancel-yen'));
    await CollabWorld.settle(tester);
    expectCall(c.world.collabs.calls.last, 'cancelCollabInvite', {
      'collaboratorId': 'yen',
    });
  });

  testWidgets('exactly one primary', (tester) async {
    await _studio().pump(tester);
    expect(find.byType(CtaSurface), findsOneWidget);
    expect(
      find.descendant(
        of: _key('collab-invite'),
        matching: find.byType(CtaSurface),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<AppButton>(_key('collab-invite')).label,
      'Mời cộng tác viên',
    );
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _studio(dueFee: 5000000)
        .pump(tester, size: const Size(320, 1600), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
