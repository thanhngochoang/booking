import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/studio/invite_member_sheet.dart';

import '../../support/collab_world.dart';
import '../../support/meta_finders.dart';
import '../../support/recruit_world.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

void _usePhone(WidgetTester tester, {double width = 390, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _rows = [
  InviteCandidate(
    uid: 'phuong',
    name: 'Lan Phương',
    verified: true,
    tomatoPct: 95,
    areaLabel: 'Quận 3',
    state: InviteState.invitable,
  ),
  InviteCandidate(
    uid: 'duc',
    name: 'Đức Anh',
    state: InviteState.inStudio,
    studioName: 'Studio Nắng',
  ),
];

final _cooldownRow = InviteCandidate(
  uid: 'ngoc',
  name: 'Bảo Ngọc',
  state: InviteState.cooldown,
  // 14/10 in Vietnam.
  availableFrom: DateTime.utc(2026, 10, 14, 3),
);

/// Opens S26.01 and its "Mời thợ" sheet.
Future<StudioWorld> _open(
  WidgetTester tester, {
  void Function(StudioWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  _usePhone(tester, width: width);
  final w = StudioWorld();
  w.studios.searchRows = [..._rows, _cooldownRow];
  seed?.call(w);
  await tester.pumpWidget(w.app(textScale: textScale, brightness: brightness));
  await _settle(tester);
  await tester.tap(_key('studio-invite'));
  await _settle(tester);
  expect(find.byType(InviteMemberSheet), findsOneWidget);
  return w;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_key('invite-search'), text);
  // Past the typing pause.
  await _settle(tester);
}

Iterable<(String, Map<String, Object?>)> _searches(StudioWorld w) =>
    w.studios.calls.where((c) => c.$1 == 'searchPhotographersToInvite');

AppButton _invite(WidgetTester tester, String uid) =>
    tester.widget<AppButton>(_key('invite-$uid'));

/// The last studio call was [name] with [payload].
void _expectLast(StudioWorld w, String name, Map<String, Object?> payload) {
  final c = w.studios.calls.last;
  expect([c.$1, c.$2], [name, payload]);
}

void main() {
  testWidgets('typing 2+ characters searches; 1 character does not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final w = await _open(tester);
    await _type(tester, 'L');
    expect(_searches(w), isEmpty);
    expect(find.text('Lan Phương'), findsNothing);
    await _type(tester, 'La');
    expect(_searches(w).single.$2, {'query': 'La'});
    expect(find.text('Lan Phương'), findsOneWidget);
    expect(findMeta('95% · Quận 3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Lan Phương, Đã xác minh')), findsOne);
    expect(
      find.text('Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ'),
      findsOneWidget,
    );
    // No gradient button in the sheet.
    expect(
      find.descendant(
        of: find.byType(InviteMemberSheet),
        matching: find.byType(CtaSurface),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('rows show Đang ở {studio} and Mời được từ {date} dimmed', (
    tester,
  ) async {
    await _open(tester);
    await _type(tester, 'an');
    expect(findMeta('Đang ở Studio Nắng'), findsOneWidget);
    expect(findMeta('Mời được từ 14/10'), findsOneWidget);
    MemberRow row(String name) => tester.widget<MemberRow>(
      find.ancestor(of: find.text(name), matching: find.byType(MemberRow)),
    );
    expect(row('Đức Anh').enabled, isFalse);
    expect(row('Bảo Ngọc').enabled, isFalse);
    expect(row('Lan Phương').enabled, isTrue);
    expect(_key('invite-duc'), findsNothing);
    expect(_key('invite-ngoc'), findsNothing);
  });

  testWidgets('Mời invites and the row becomes Đã mời with a SnackBar', (
    tester,
  ) async {
    final w = await _open(tester);
    await _type(tester, 'Lan');
    await tester.tap(_key('invite-phuong'));
    await _settle(tester);
    _expectLast(w, 'inviteMember', {'memberId': 'phuong'});
    expect(find.text('Đã mời'), findsOneWidget);
    expect(_key('invite-phuong'), findsNothing);
    expect(find.text('Đã gửi lời mời tới Lan Phương'), findsOneWidget);
  });

  testWidgets('a refused invite shows studioErrorText', (tester) async {
    final w = await _open(tester);
    await _type(tester, 'Lan');
    w.studios.nextError = 'membership_conflict';
    await tester.tap(_key('invite-phuong'));
    await _settle(tester);
    expect(find.text('Thợ này đang ở một studio khác.'), findsOneWidget);
    expect(_key('invite-phuong'), findsOneWidget);
  });

  testWidgets('five open invites disable every Mời with the reason line', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) {
        for (var i = 0; i < 5; i++) {
          w.studios.seedRelation(
            makeRelation(
              id: 'inv$i',
              memberId: 'x$i',
              memberName: 'Thợ $i',
              status: RelationStatus.invited,
            ),
          );
        }
      },
    );
    await _type(tester, 'Lan');
    expect(_invite(tester, 'phuong').onPressed, isNull);
    expect(find.text('Đã có 5 lời mời chờ'), findsOneWidget);
  });

  testWidgets('no quota or a full studio disables Mời with its reason', (
    tester,
  ) async {
    final w = await _open(tester);
    await _type(tester, 'Lan');
    // The quota runs out while the sheet is open.
    w.studios.setQuota('cuc', const StudioQuota(left: 0, max: 5));
    await _settle(tester);
    expect(_invite(tester, 'phuong').onPressed, isNull);
    expect(
      find.descendant(
        of: find.byType(InviteMemberSheet),
        matching: find.text('Hết thao tác hôm nay. Thử lại ngày mai.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no results text', (tester) async {
    await _open(tester, seed: (w) => w.studios.searchRows = const []);
    await _type(tester, 'Zz');
    expect(find.text('Không tìm thấy thợ tên này'), findsOneWidget);
  });

  testWidgets('the close button closes the sheet', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Đóng'));
    await _settle(tester);
    expect(find.byType(InviteMemberSheet), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text ($brightness)', (tester) async {
      await _open(tester, width: 320, textScale: 1.3, brightness: brightness);
      await _type(tester, 'an');
      expect(tester.takeException(), isNull);
      expect(_key('invite-phuong'), findsOneWidget);
    });
  }

  group('S26.02-collab (from S27.06)', () {
    const rows = [
      InviteCandidate(
        uid: 'yen',
        name: 'Hoàng Yến',
        verified: true,
        tomatoPct: 93,
        areaLabel: 'Quận 10',
        state: InviteState.invitable,
      ),
      InviteCandidate(
        uid: 'nhung',
        name: 'Hồng Nhung',
        verified: true,
        state: InviteState.member,
      ),
      InviteCandidate(
        uid: 'ngoc',
        name: 'Bảo Ngọc',
        verified: true,
        state: InviteState.invitable,
      ),
      InviteCandidate(
        uid: 'lan',
        name: 'Lan Phương',
        verified: true,
        state: InviteState.invitable,
      ),
      InviteCandidate(
        uid: 'toan',
        name: 'Văn Toàn',
        state: InviteState.invitable,
      ),
      // In another studio: still invitable as a collaborator (R6).
      InviteCandidate(
        uid: 'duc',
        name: 'Đức Anh',
        verified: true,
        state: InviteState.inStudio,
        studioName: 'Studio Nắng',
      ),
    ];

    Future<CollabWorld> openCollab(
      WidgetTester tester, {
      RecruitCounters? counters,
    }) async {
      final c = CollabWorld();
      c.studios.searchRows = rows;
      c.world.collabs
        ..seedCollaboration(
          makeCollaboration(collaboratorId: 'lan', collaboratorName: 'Lan'),
        )
        // Ended yesterday: invitable again 3 days after, on 23/10.
        ..seedCollaboration(
          makeCollaboration(
            collaboratorId: 'ngoc',
            collaboratorName: 'Bảo Ngọc',
          ).copyWith(
            status: CollabStatus.ended,
            endedAt: recruitNow.subtract(const Duration(days: 1)),
          ),
        );
      if (counters != null) c.world.recruits.setCounters(c.uid, counters);
      await c.pump(tester);
      await tester.tap(_key('collab-invite'));
      await _settle(tester);
      expect(find.byType(InviteMemberSheet), findsOneWidget);
      await tester.enterText(_key('invite-search'), 'an');
      await _settle(tester);
      return c;
    }

    testWidgets('title "Mời cộng tác viên"; dimmed rows with "Thành viên của '
        'studio bạn", "Đang cộng tác", "Mời lại được từ {date}", "Chưa xác '
        'minh"; "Mời" calls invite', (tester) async {
      final c = await openCollab(tester);
      expect(
        find.descendant(
          of: find.byType(InviteMemberSheet),
          matching: find.text('Mời cộng tác viên'),
        ),
        findsOneWidget,
      );
      expect(findMeta('Thành viên của studio bạn'), findsOneWidget);
      expect(findMeta('Đang cộng tác'), findsOneWidget);
      expect(findMeta('Mời lại được từ 23/10'), findsOneWidget);
      expect(findMeta('Chưa xác minh'), findsOneWidget);
      expect(findMeta('93% · Quận 10'), findsOneWidget);
      MemberRow row(String name) => tester.widget<MemberRow>(
        find.ancestor(of: find.text(name), matching: find.byType(MemberRow)),
      );
      for (final name in ['Hồng Nhung', 'Lan Phương', 'Bảo Ngọc', 'Văn Toàn']) {
        expect(row(name).enabled, isFalse, reason: name);
      }
      expect(row('Hoàng Yến').enabled, isTrue);
      expect(row('Đức Anh').enabled, isTrue);
      for (final uid in ['nhung', 'lan', 'ngoc', 'toan']) {
        expect(_key('invite-$uid'), findsNothing, reason: uid);
      }
      expect(
        find.text('Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ'),
        findsOneWidget,
      );

      await tester.tap(_key('invite-yen'));
      await _settle(tester);
      expectCall(c.world.collabs.calls.last, 'inviteCollaborator', {
        'collaboratorId': 'yen',
      });
      // The S26 member invite is never called from this mode.
      expect(c.studios.calls.where((x) => x.$1 == 'inviteMember'), isEmpty);
      expect(find.text('Đã mời'), findsOneWidget);
    });

    for (final (label, counters, reason) in [
      (
        '5 pending',
        const RecruitCounters(activeCollabCount: 1, pendingInviteCount: 5),
        'Đã có 5 lời mời chờ',
      ),
      (
        'no actions left',
        const RecruitCounters(
          activeCollabCount: 1,
          collabActions: RecruitDaily(day: '2026-10-21', count: 10),
        ),
        'Hết thao tác hôm nay. Thử lại ngày mai.',
      ),
    ]) {
      testWidgets('$label disables every "Mời" with the reason line', (
        tester,
      ) async {
        await openCollab(tester, counters: counters);
        expect(tester.widget<AppButton>(_key('invite-yen')).onPressed, isNull);
        expect(tester.widget<AppButton>(_key('invite-duc')).onPressed, isNull);
        expect(tester.widget<Text>(_key('invite-blocked')).data, reason);
      });
    }
  });
}
