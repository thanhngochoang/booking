// test/features/organizer/organizer_apply_screen_test.dart
//
// S30.01 "Tổ chức sự kiện" (mock #S30.01).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

import '../../support/organizer_world.dart';

Finder _key(String k) => find.byKey(Key(k));

AppButton _primary(WidgetTester tester) =>
    tester.widget<AppButton>(_key('org-apply-submit'));

OrganizerWorld _world({bool verified = true}) {
  final w = OrganizerWorld(uid: 'u1');
  w.contact = UserContact(phone: '+84912345678', phoneVerified: verified);
  w.organizers.phoneVerified = verified;
  return w;
}

void main() {
  testWidgets('shows the mock copy and the verified phone', (tester) async {
    final w = _world();
    await w.pump(tester, location: '/organizer/apply');

    expect(find.text('Tổ chức sự kiện'), findsOneWidget);
    expect(find.text('Bán vé và quản lý địa điểm'), findsOneWidget);
    expect(find.text('Số điện thoại đã xác minh'), findsOneWidget);
    expect(find.text('0912 ••• 678'), findsOneWidget);
    expect(
      find.text('Bán vé có thu phí: cần xác minh doanh nghiệp'),
      findsOneWidget,
    );
    expect(_primary(tester).label, 'Gửi yêu cầu');
  });

  testWidgets(
    'unverified phone → primary "Xác minh số điện thoại" routes to S21.01',
    (tester) async {
      final w = _world(verified: false);
      await w.pump(tester, location: '/organizer/apply');

      expect(_primary(tester).label, 'Xác minh số điện thoại');
      expect(find.text('Chưa xác minh số điện thoại'), findsOneWidget);
      await tapOrganizer(tester, _key('org-apply-submit'));
      expect(w.location, '/verify/phone?returnTo=%2Forganizer%2Fapply');
      expect(w.organizers.calls, isEmpty);
    },
  );

  testWidgets('name counter 60; a short name shows "Tên 3–60 ký tự"', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: '/organizer/apply');

    await tester.enterText(_key('org-apply-name'), 'Vườn hoa Bãi đá sông Hồng');
    await tester.pump();
    expect(find.text('25/60'), findsOneWidget);

    await tester.enterText(_key('org-apply-name'), 'AB');
    await tapOrganizer(tester, _key('org-apply-submit'));
    expect(find.text('Tên 3–60 ký tự'), findsOneWidget);
    expect(w.organizers.calls, isEmpty);
  });

  testWidgets('submit calls becomeOrganizer and routes to S30.02', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: '/organizer/apply');

    await tester.enterText(_key('org-apply-name'), 'Vườn hoa Bãi đá');
    await tester.enterText(_key('org-apply-bio'), 'Mở cửa 6:00–22:00');
    await tapOrganizer(tester, _key('org-apply-submit'));

    expectOnlyCall(w, (
      'becomeOrganizer',
      {'name': 'Vườn hoa Bãi đá', 'bio': 'Mở cửa 6:00–22:00'},
    ));
    expect(w.location, '/organizer/spots/claim');
  });

  testWidgets('a server refusal stays on the screen with its message', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: '/organizer/apply');
    w.organizers.nextError = const OrganizerError(
      'invalid_argument',
      field: 'name',
    );
    await tester.enterText(_key('org-apply-name'), 'Vườn hoa Bãi đá');
    await tapOrganizer(tester, _key('org-apply-submit'));

    expect(find.text('Tên 3–60 ký tự'), findsOneWidget);
    expect(w.location, '/organizer/apply');
  });

  testWidgets('suspended band and no primary action', (tester) async {
    final w = _world();
    w.organizers.putOrganizer(
      makeOrganizer(id: 'u1', status: OrganizerStatus.suspended),
    );
    await w.pump(tester, location: '/organizer/apply');

    expect(
      find.text('Tài khoản tổ chức đang bị tạm khoá · Liên hệ hỗ trợ'),
      findsOneWidget,
    );
    expect(_primary(tester).onPressed, isNull);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      final w = _world(verified: false);
      await w.pump(
        tester,
        location: '/organizer/apply',
        width: 320,
        height: 700,
        textScale: 1.3,
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      expect(_key('org-apply-submit'), findsOneWidget);
    });
  }
}
