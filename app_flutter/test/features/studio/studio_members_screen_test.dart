import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/studio/invite_member_sheet.dart';

import '../../support/meta_finders.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

void _usePhone(WidgetTester tester, {double width = 390, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Bounded pumps: the screen's loaders never settle on their own.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

StudioRelation _member(String id, String name, {int daysAgo = 30}) =>
    makeRelation(
      id: 'm_$id',
      memberId: id,
      memberName: name,
      createdAt: studioNow.subtract(Duration(days: daysAgo)),
    );

PhotographerSummary _summary(String id, String name, int pct) =>
    PhotographerSummary(
      id: id,
      displayName: name,
      studioId: 'cuc',
      reviewCount: 20,
      tomatoPct: pct,
    );

/// Minh Trí (2 open jobs), Hồng Nhung (1), Quốc Bảo (none); an invite to Thu
/// Hà sent 2 days ago and Quang Huy's request from 2 hours ago.
void _seedMock(StudioWorld w) {
  w.studios
    ..seedRelation(_member('tri', 'Minh Trí', daysAgo: 60))
    ..seedRelation(_member('nhung', 'Hồng Nhung', daysAgo: 50))
    ..seedRelation(_member('bao', 'Quốc Bảo', daysAgo: 40))
    ..seedRelation(
      makeRelation(
        id: 'inv_ha',
        memberId: 'ha',
        memberName: 'Thu Hà',
        status: RelationStatus.invited,
      ),
    )
    ..seedRelation(
      makeRelation(
        id: 'req_huy',
        memberId: 'huy',
        memberName: 'Quang Huy',
        status: RelationStatus.requested,
        initiatedBy: RelationInitiator.member,
        createdAt: studioNow.subtract(const Duration(hours: 2)),
      ),
    )
    ..setQuota('cuc', const StudioQuota(left: 4, max: 5));
  w.photographers
    ..add(_summary('tri', 'Minh Trí', 97))
    ..add(_summary('nhung', 'Hồng Nhung', 91))
    ..add(_summary('bao', 'Quốc Bảo', 89));
  w.bookings
    ..seedBooking(makeStudioBooking(id: 'b1', assigneeId: 'tri'))
    ..seedBooking(
      makeStudioBooking(
        id: 'b2',
        assigneeId: 'tri',
        status: BookingStatus.upcoming,
      ),
    )
    ..seedBooking(makeStudioBooking(id: 'b3', assigneeId: 'nhung'))
    // Closed shoots no longer count.
    ..seedBooking(
      makeStudioBooking(
        id: 'b4',
        assigneeId: 'bao',
        status: BookingStatus.completed,
      ),
    );
}

Future<StudioWorld> _open(
  WidgetTester tester, {
  void Function(StudioWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  _usePhone(tester, width: width, height: width < 390 ? 900 : 900);
  final w = StudioWorld();
  seed?.call(w);
  await tester.pumpWidget(w.app(textScale: textScale, brightness: brightness));
  await _settle(tester);
  return w;
}

Finder _memberRow(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(MemberRow));

/// The last studio call was [name] with [payload].
void _expectLast(StudioWorld w, String name, Map<String, Object?> payload) {
  final c = w.studios.calls.last;
  expect([c.$1, c.$2], [name, payload]);
}

void main() {
  testWidgets('shows the quota line 6/30 thợ · còn 4 thao tác hôm nay', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) {
        for (final (i, n) in ['A', 'B', 'C', 'D', 'E', 'F'].indexed) {
          w.studios.seedRelation(_member('u$i', 'Thợ $n', daysAgo: 10 + i));
        }
        w.studios.setQuota('cuc', const StudioQuota(left: 4, max: 5));
      },
    );
    expect(find.text('Thành viên'), findsOneWidget);
    expect(find.text('6/30 thợ · còn 4 thao tác hôm nay'), findsOneWidget);
    expect(find.byTooltip('Quy định thành viên'), findsOneWidget);
  });

  testWidgets('the info button opens the rules sheet', (tester) async {
    await _open(tester, seed: _seedMock);
    await tester.tap(find.byTooltip('Quy định thành viên'));
    await _settle(tester);
    expect(
      find.text('Lời mời hết hạn sau 7 ngày, tối đa 5 lời mời chờ.'),
      findsOneWidget,
    );
    expect(
      find.text('Không bỏ được thành viên còn buổi chụp được giao chưa xong.'),
      findsOneWidget,
    );
  });

  testWidgets('lists active members with % and assigned counts from the '
      "studio's bookings", (tester) async {
    await _open(tester, seed: _seedMock);
    expect(findMeta('97% · 2 việc đang giao'), findsOneWidget);
    expect(tomatoIconIn(findMeta('97% · 2 việc đang giao')), findsOneWidget);
    expect(findMeta('91% · 1 việc đang giao'), findsOneWidget);
    expect(findMeta('89% · chưa có việc'), findsOneWidget);
    expect(find.byTooltip('Tuỳ chọn cho Minh Trí'), findsOneWidget);
    // Join order, as the mock.
    expect(
      tester.getTopLeft(find.text('Minh Trí')).dy,
      lessThan(tester.getTopLeft(find.text('Quốc Bảo')).dy),
    );
    await tester.tap(find.text('Hồng Nhung'));
    await _settle(tester);
    expect(find.text('stub /u/nhung'), findsOneWidget);
  });

  testWidgets('pending invite shows days left and Huỷ cancels', (tester) async {
    final w = await _open(tester, seed: _seedMock);
    expect(find.text('Đang chờ'), findsOneWidget);
    expect(find.text('2 · tối đa 5 lời mời'), findsOneWidget);
    expect(findMeta('Lời mời đã gửi · Hết hạn sau 5 ngày'), findsOneWidget);
    await tester.tap(_key('studio-cancel-inv_ha'));
    await _settle(tester);
    _expectLast(w, 'cancelInvite', {'relationId': 'inv_ha'});
    expect(find.text('Thu Hà'), findsNothing);
  });

  testWidgets('a request shows Từ chối and Duyệt; Duyệt approves', (
    tester,
  ) async {
    final w = await _open(tester, seed: _seedMock);
    expect(findMeta('Xin gia nhập · 2 giờ trước'), findsOneWidget);
    expect(_key('studio-decline-req_huy'), findsOneWidget);
    await tester.tap(_key('studio-approve-req_huy'));
    await _settle(tester);
    _expectLast(w, 'respondJoinRequest', {
      'relationId': 'req_huy',
      'accept': true,
    });
    // Now a member with no work yet.
    expect(findMeta('chưa có việc'), findsOneWidget);
  });

  testWidgets('Từ chối declines a request', (tester) async {
    final w = await _open(tester, seed: _seedMock);
    await tester.tap(_key('studio-decline-req_huy'));
    await _settle(tester);
    _expectLast(w, 'respondJoinRequest', {
      'relationId': 'req_huy',
      'accept': false,
    });
  });

  testWidgets('Mời thợ opens S26.02', (tester) async {
    await _open(tester, seed: _seedMock);
    final primary = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Mời thợ',
    );
    expect(primary, findsOneWidget);
    await tester.tap(primary);
    await _settle(tester);
    expect(find.byType(InviteMemberSheet), findsOneWidget);
    expect(find.text('Tìm thợ theo tên'), findsWidgets);
  });

  testWidgets('remove opens a red confirmation sheet and removes', (
    tester,
  ) async {
    final w = await _open(tester, seed: _seedMock);
    await tester.tap(find.byTooltip('Tuỳ chọn cho Quốc Bảo'));
    await _settle(tester);
    await tester.tap(find.text('Bỏ khỏi studio'));
    await _settle(tester);
    expect(find.text('Bỏ Quốc Bảo khỏi studio?'), findsOneWidget);
    expect(
      find.text(
        'Quốc Bảo sẽ không nhận việc của studio nữa và 7 ngày sau mới vào '
        'được studio khác.',
      ),
      findsOneWidget,
    );
    final confirm = find.byWidgetPredicate(
      (w) => w is AppButton && w.label == 'Bỏ khỏi studio',
    );
    final filled = tester.widget<FilledButton>(
      find.descendant(of: confirm, matching: find.byType(FilledButton)),
    );
    expect(filled.style?.backgroundColor?.resolve({}), AppColors.error);
    await tester.tap(confirm);
    await _settle(tester);
    _expectLast(w, 'removeMember', {'memberId': 'bao'});
    expect(find.text('Quốc Bảo'), findsNothing);
  });

  testWidgets('remove of a member with 2 open jobs shows Còn 2 buổi chụp '
      'được giao and no remove button', (tester) async {
    final w = await _open(tester, seed: _seedMock);
    await tester.tap(find.byTooltip('Tuỳ chọn cho Minh Trí'));
    await _settle(tester);
    await tester.tap(find.text('Bỏ khỏi studio'));
    await _settle(tester);
    expect(find.text('Còn 2 buổi chụp được giao'), findsOneWidget);
    expect(
      find.text('Giao các buổi này cho người khác hoặc chờ chụp xong rồi bỏ.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is AppButton && w.label == 'Bỏ khỏi studio',
      ),
      findsNothing,
    );
    await tester.tap(_key('studio-blocked-close'));
    await _settle(tester);
    expect(w.studios.calls.where((c) => c.$1 == 'removeMember'), isEmpty);
  });

  testWidgets('at the cap without business verification shows the banner '
      '(link hidden when the route is absent)', (tester) async {
    void seed(StudioWorld w) {
      w.intro = const PhotographerIntro(
        verified: true,
        providerType: ProviderType.studio,
      );
      w.studios
        ..seedRelation(_member('a', 'An'))
        ..seedRelation(_member('b', 'Bình'))
        ..seedRelation(
          makeRelation(
            id: 'inv_c',
            memberId: 'c',
            memberName: 'Chi',
            status: RelationStatus.invited,
          ),
        );
    }

    await _open(tester, seed: seed);
    expect(find.text('2/3 thợ · còn 5 thao tác hôm nay'), findsOneWidget);
    expect(
      find.text('Đã đủ 3 thợ. Xác minh doanh nghiệp để nhận tới 30 thợ.'),
      findsOneWidget,
    );
    await tester.tap(_key('studio-verify-business'));
    await _settle(tester);
    expect(find.text('stub /verify/business'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await _open(
      tester,
      seed: (w) {
        seed(w);
        w.verifyRoutes = false;
      },
    );
    expect(
      find.text('Đã đủ 3 thợ. Xác minh doanh nghiệp để nhận tới 30 thợ.'),
      findsOneWidget,
    );
    expect(_key('studio-verify-business'), findsNothing);
  });

  testWidgets('no quota disables actions and shows studioQuotaOut', (
    tester,
  ) async {
    final w = await _open(
      tester,
      seed: (w) {
        _seedMock(w);
        w.studios.setQuota('cuc', const StudioQuota(left: 0, max: 5));
      },
    );
    expect(
      find.text('Hết thao tác hôm nay. Thử lại ngày mai.'),
      findsOneWidget,
    );
    AppButton button(String key) => tester.widget<AppButton>(_key(key));
    expect(button('studio-invite').onPressed, isNull);
    expect(button('studio-cancel-inv_ha').onPressed, isNull);
    expect(button('studio-approve-req_huy').onPressed, isNull);
    // Declining a request is free (Decision 4).
    expect(button('studio-decline-req_huy').onPressed, isNotNull);
    await tester.tap(find.byTooltip('Tuỳ chọn cho Quốc Bảo'));
    await _settle(tester);
    await tester.tap(find.text('Bỏ khỏi studio'));
    await _settle(tester);
    expect(find.text('Bỏ Quốc Bảo khỏi studio?'), findsNothing);
    expect(w.studios.calls, isEmpty);
  });

  testWidgets('empty studio shows the empty state', (tester) async {
    await _open(tester);
    expect(find.text('Chưa có thành viên'), findsOneWidget);
    expect(
      find.text('Mời thợ ảnh bạn tin tưởng; họ nhận lời là vào studio.'),
      findsOneWidget,
    );
    expect(find.text('Đang chờ'), findsNothing);
    expect(_key('studio-invite'), findsOneWidget);
  });

  testWidgets('server errors show studioErrorText', (tester) async {
    final w = await _open(tester, seed: _seedMock);
    w.studios.nextError = 'studio_full';
    await tester.tap(_key('studio-approve-req_huy'));
    await _settle(tester);
    expect(
      find.text('Studio đã đủ số thợ hoặc đủ 5 lời mời chờ.'),
      findsOneWidget,
    );
    w.studios.nextError = 'unavailable';
    await tester.tap(_key('studio-cancel-inv_ha'));
    await _settle(tester);
    expect(find.text('Chưa thực hiện được. Thử lại.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text ($brightness)', (tester) async {
      await _open(
        tester,
        seed: _seedMock,
        width: 320,
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(_memberRow('Minh Trí'), findsOneWidget);
      expect(_key('studio-approve-req_huy'), findsOneWidget);
    });
  }
}
