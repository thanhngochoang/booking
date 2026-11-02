// test/features/organizer/gate_staff_screen_test.dart
//
// S30.06 "Nhân viên soát vé" (mock #S30.06) and the invitee's sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';

import '../../support/organizer_world.dart';

Finder _key(String k) => find.byKey(Key(k));

const _path = '/organizer/gate-staff';

GateStaff _staff(
  String uid, {
  GateStaffStatus status = GateStaffStatus.active,
  Duration invitedAgo = const Duration(hours: 1),
  int scans = 0,
  String organizerId = 'org1',
}) => GateStaff(
  organizerId: organizerId,
  staffUid: uid,
  status: status,
  invitedAt: organizerNow.subtract(invitedAgo),
  scansDay: organizerToday,
  scansCount: scans,
);

OrganizerWorld _world() {
  final w = OrganizerWorld();
  w.organizers.putOrganizer(makeOrganizer());
  w.names.addAll({'bao': 'Quốc Bảo', 'trang': 'Thu Trang', 'anh': 'Đức Anh'});
  w.organizers
    ..putGateStaff(_staff('bao', scans: 64))
    ..putGateStaff(_staff('trang', scans: 32))
    ..putGateStaff(_staff('anh', status: GateStaffStatus.invited));
  return w;
}

void main() {
  testWidgets('list with "Đang làm"/"Đã mời" and scans today', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);

    expect(find.text('Nhân viên soát vé'), findsOneWidget);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.text('Quốc Bảo'), findsOneWidget);
    expect(find.text('64 mã hôm nay'), findsOneWidget);
    expect(find.text('32 mã hôm nay'), findsOneWidget);
    expect(find.text('ĐANG LÀM'), findsNWidgets(2));
    expect(find.text('Đức Anh'), findsOneWidget);
    expect(find.text('mời 1 giờ trước'), findsOneWidget);
    expect(find.text('ĐÃ MỜI'), findsOneWidget);
    expect(
      find.textContaining('Nhân viên chỉ mở được màn quét mã'),
      findsOneWidget,
    );
    expect(
      tester.widget<AppButton>(_key('gate-invite')).label,
      'Mời nhân viên',
    );
  });

  testWidgets('invite sheet by phone sends the E.164 number', (tester) async {
    final w = _world();
    w.organizers.accounts['+84987654210'] = 'minh';
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('gate-invite'));

    expect(find.text('Số điện thoại hoặc @username'), findsOneWidget);
    await tester.enterText(_key('invite-target'), '0987 654 210');
    await tapOrganizer(tester, _key('invite-send'));
    expectOnlyCall(w, ('inviteGateStaff', {'target': '+84987654210'}));
    expect(find.text('Đã gửi lời mời'), findsOneWidget);
  });

  testWidgets('an @username answers not_found (phone only for now)', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('gate-invite'));
    await tester.enterText(_key('invite-target'), '@quocbao');
    await tapOrganizer(tester, _key('invite-send'));

    expectOnlyCall(w, ('inviteGateStaff', {'target': '@quocbao'}));
    expect(find.text('Không tìm thấy tài khoản'), findsOneWidget);
  });

  testWidgets('11th → s3006_limit', (tester) async {
    final w = _world();
    for (var i = 0; i < 7; i++) {
      w.organizers.putGateStaff(_staff('s$i'));
    }
    await w.pump(tester, location: _path);
    expect(find.text('10 / 10'), findsOneWidget);
    await tapOrganizer(tester, _key('gate-invite'));

    expect(find.text('Tối đa 10 nhân viên'), findsOneWidget);
    expect(_key('invite-target'), findsNothing);
    expect(w.organizers.calls, isEmpty);
  });

  testWidgets(
    'expired invites free their seat: 9 active + 2 expired → invite',
    (tester) async {
      final w = OrganizerWorld();
      w.organizers.putOrganizer(makeOrganizer());
      for (var i = 0; i < 9; i++) {
        w.organizers.putGateStaff(_staff('s$i'));
      }
      for (final uid in ['x1', 'x2']) {
        w.organizers.putGateStaff(
          _staff(
            uid,
            status: GateStaffStatus.invited,
            invitedAgo: const Duration(hours: 80),
          ),
        );
      }
      w.organizers.accounts['+84987654210'] = 'minh';
      await w.pump(tester, location: _path, height: 1800);

      expect(find.text('9 / 10'), findsOneWidget);
      expect(find.text('Lời mời đã hết hạn'), findsNWidgets(2));
      await tapOrganizer(tester, _key('gate-invite'));
      expect(find.text('Tối đa 10 nhân viên'), findsNothing);
      await tester.enterText(_key('invite-target'), '0987654210');
      await tapOrganizer(tester, _key('invite-send'));
      expectOnlyCall(w, ('inviteGateStaff', {'target': '+84987654210'}));
      expect(find.text('Đã gửi lời mời'), findsOneWidget);
    },
  );

  testWidgets('remove via the red ConfirmSheet', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('gate-bao'));
    await tapOrganizer(tester, _key('gate-remove'));

    expect(find.text('Gỡ Quốc Bảo khỏi nhân viên soát vé?'), findsOneWidget);
    expectRedButton(tester, 'Gỡ');
    await tapOrganizer(tester, find.widgetWithText(AppButton, 'Gỡ'));
    expectOnlyCall(w, ('removeGateStaff', {'staffUid': 'bao'}));
    expect(find.text('Quốc Bảo'), findsNothing);
  });

  group('the invitee', () {
    OrganizerWorld invitee({Duration ago = const Duration(hours: 2)}) {
      final w = OrganizerWorld(uid: 'bao');
      w.organizers.putOrganizer(makeOrganizer(name: 'Vườn hoa Bãi đá'));
      w.organizers.putGateStaff(
        _staff('bao', status: GateStaffStatus.invited, invitedAgo: ago),
      );
      return w;
    }

    testWidgets('accepts from the sheet the notification opens', (
      tester,
    ) async {
      final w = invitee();
      await w.pump(tester, location: _path);

      expect(find.text('Vườn hoa Bãi đá mời bạn soát vé'), findsOneWidget);
      await tapOrganizer(tester, _key('gate-invite-accept'));
      expectOnlyCall(w, (
        'respondGateStaff',
        {'organizerId': 'org1', 'accept': true},
      ));
      expect(find.text('Bạn đã nhận soát vé'), findsOneWidget);
    });

    testWidgets('declines', (tester) async {
      final w = invitee();
      await w.pump(tester, location: _path);
      await tapOrganizer(tester, _key('gate-invite-decline'));
      expectOnlyCall(w, (
        'respondGateStaff',
        {'organizerId': 'org1', 'accept': false},
      ));
    });

    testWidgets('expired state after 72 hours', (tester) async {
      final w = invitee(ago: const Duration(hours: 73));
      await w.pump(tester, location: _path);

      expect(find.text('Lời mời đã hết hạn'), findsOneWidget);
      expect(_key('gate-invite-accept'), findsNothing);
      // Not an organizer: no invite button of their own.
      expect(_key('gate-invite'), findsNothing);
    });
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      final w = _world();
      await w.pump(
        tester,
        location: _path,
        width: 320,
        height: 700,
        textScale: 1.3,
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      await tapOrganizer(tester, _key('gate-invite'));
      expect(tester.takeException(), isNull);
      expect(_key('invite-send'), findsOneWidget);
    });
  }
}
