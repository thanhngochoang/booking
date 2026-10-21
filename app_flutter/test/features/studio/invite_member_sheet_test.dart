import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
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
}
