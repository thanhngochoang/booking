import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/studio/assign_sheet.dart';

import '../../support/recruit_world.dart';
import '../../support/screen_host.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _options = [
  AssignmentOption(
    uid: 'minh',
    name: 'Minh Trí',
    tomatoPct: 97,
    reviewCount: 58,
    state: AssignState.free,
  ),
  AssignmentOption(
    uid: 'nhung',
    name: 'Hồng Nhung',
    tomatoPct: 91,
    reviewCount: 20,
    state: AssignState.free,
  ),
  AssignmentOption(
    uid: 'bao',
    name: 'Quốc Bảo',
    state: AssignState.busy,
    busyStart: '15:00',
    busyEnd: '18:00',
  ),
  AssignmentOption(uid: 'linh', name: 'Khánh Linh', state: AssignState.off),
  AssignmentOption(uid: 'an', name: 'An', state: AssignState.unverified),
];

class _Host {
  _Host(this.world);
  final StudioWorld world;
  bool? result;
}

/// Opens S26.04 for `sb1` from a bare page.
Future<_Host> _open(
  WidgetTester tester, {
  List<AssignmentOption> options = _options,
  List<Collaboration> collaborators = const [],
  Booking? booking,
  DateTime? now,
  double width = 390,
  double height = 900,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = StudioWorld(now: now);
  w.bookings.seedBooking(booking ?? makeStudioBooking());
  w.studios.options = options;
  for (final c in collaborators) {
    w.collabs.seedCollaboration(c);
  }
  final host = _Host(w);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  host.result = await showAssignSheet(context, 'sb1'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: w.screenOverrides,
      textScale: textScale,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await _settle(tester);
  return host;
}

/// Scrolls the sheet's list until [key] is built and on screen.
Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    80,
    scrollable: find
        .descendant(
          of: find.byType(AssignSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

AppButton _submit(WidgetTester tester) =>
    tester.widget<AppButton>(_key('assign-submit'));

void main() {
  testWidgets('shows the booking, its deadline and the time left', (
    tester,
  ) async {
    final h = await _open(tester);

    expect(find.text('Giao thợ'), findsOneWidget);
    expect(
      find.text('Gói chụp ngoại cảnh · T7 24/10 · 15:00–17:00'),
      findsOneWidget,
    );
    expect(
      find.text('Hạn giao thợ: 15:00 T6 23/10 (còn 2 ngày)'),
      findsOneWidget,
    );
    expect(h.world.studios.calls.single.$1, 'assignmentOptions');
    expect(h.world.studios.calls.single.$2, {'bookingId': 'sb1'});
  });

  testWidgets('lists members with Rảnh, Bận 15:00–18:00, Bận cả ngày, Chưa '
      'xác minh (disabled)', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester);

    expect(
      find.bySemanticsLabel('Minh Trí. Rảnh · 97% cà chua'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Hồng Nhung. Rảnh · 91% cà chua'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Quốc Bảo. Bận 15:00–18:00'), findsOneWidget);
    expect(find.bySemanticsLabel('Khánh Linh. Bận cả ngày'), findsOneWidget);
    expect(find.bySemanticsLabel('An. Chưa xác minh'), findsOneWidget);
    bool enabled(String uid) =>
        tester.widget<AppOptionTile>(_key('assign-option-$uid')).enabled;
    expect(enabled('minh'), isTrue);
    expect(enabled('nhung'), isTrue);
    expect(enabled('bao'), isFalse);
    expect(enabled('linh'), isFalse);
    expect(enabled('an'), isFalse);
    expect(
      tester.getSemantics(_key('assign-option-an')),
      matchesSemantics(
        label: 'An. Chưa xác minh',
        hasEnabledState: true,
        isEnabled: false,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        hasTapAction: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the primary label names the selected member', (tester) async {
    await _open(tester);

    expect(_submit(tester).label, 'Giao cho Minh Trí');
    expect(
      find.text('Khách được báo ngay; Minh Trí vào nhóm chat của buổi chụp.'),
      findsOneWidget,
    );
    await tester.tap(_key('assign-option-nhung'));
    await tester.pump();
    expect(_submit(tester).label, 'Giao cho Hồng Nhung');
    expect(
      find.text('Khách được báo ngay; Hồng Nhung vào nhóm chat của buổi chụp.'),
      findsOneWidget,
    );
    // A busy member cannot be picked.
    await tester.tap(_key('assign-option-bao'));
    await tester.pump();
    expect(_submit(tester).label, 'Giao cho Hồng Nhung');
    // The sheet's only gradient button.
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  testWidgets('assigning calls assignBooking and closes', (tester) async {
    final h = await _open(tester);
    await tester.tap(_key('assign-option-nhung'));
    await tester.pump();
    await tester.tap(_key('assign-submit'));
    await _settle(tester);

    final (call, payload) = h.world.bookings.studioCalls.single;
    expect(call, 'assignBooking');
    expect(payload, {'bookingId': 'sb1', 'assigneeId': 'nhung'});
    expect(find.byType(AssignSheet), findsNothing);
    expect(h.result, isTrue);
  });

  testWidgets('inside 24 h shows assignLateWarning', (tester) async {
    // Past the deadline (23/10 15:00 in Vietnam), changing who shoots.
    await _open(
      tester,
      now: DateTime.utc(2026, 10, 23, 10),
      booking: makeStudioBooking(assigneeId: 'nhung'),
      options: [_options[0], _options[1].copyWithState(AssignState.current)],
    );

    expect(_key('assign-late-warning'), findsOneWidget);
    expect(
      find.text(
        'Còn dưới 24 giờ: đổi thợ lúc này thì khách được huỷ và hoàn 100%.',
      ),
      findsOneWidget,
    );
    expect(find.text('Đã quá hạn giao thợ (15:00 T6 23/10)'), findsOneWidget);
    expect(
      find.textContaining('Đang giao', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a first assignment before the deadline has no late warning', (
    tester,
  ) async {
    await _open(tester);
    expect(_key('assign-late-warning'), findsNothing);
  });

  testWidgets('day_taken and not_accepting_orders show studioErrorText', (
    tester,
  ) async {
    final h = await _open(tester);
    h.world.bookings.nextError = BookingErrorCode.dayTaken;
    await tester.tap(_key('assign-submit'));
    await _settle(tester);
    expect(find.text('Thợ này đã bận ngày này.'), findsOneWidget);
    expect(find.byType(AssignSheet), findsOneWidget);

    h.world.bookings.nextError = BookingErrorCode.notAcceptingOrders;
    await tester.tap(_key('assign-submit'));
    await _settle(tester);
    expect(
      find.text('Thợ này chưa xác minh nên chưa giao việc được.'),
      findsOneWidget,
    );
    expect(find.byType(AssignSheet), findsOneWidget);
    expect(h.result, isNull);
  });

  testWidgets('no members shows assignNoMembers', (tester) async {
    await _open(tester, options: const []);

    expect(find.text('Studio chưa có thành viên nào để giao.'), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);
    expect(_submit(tester).label, 'Giao thợ');
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(tester, width: 320, height: 640, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(_key('assign-submit'), findsOneWidget);
  });

  group('S26.04-collab', () {
    final collaborators = [
      makeCollaboration(
        collaboratorId: 'lan',
        collaboratorName: 'Lan Phương',
        defaultFee: 800000,
      ),
      makeCollaboration(
        collaboratorId: 'hoa',
        collaboratorName: 'Hòa',
        defaultFee: null,
      ),
      // An invite is not a collaborator yet.
      makeCollaboration(
        collaboratorId: 'yen',
        collaboratorName: 'Hoàng Yến',
        status: CollabStatus.invited,
      ),
    ];

    testWidgets('members and collaborators in two groups', (tester) async {
      await _open(tester, collaborators: collaborators);
      expect(
        find.descendant(
          of: _key('assign-group-members'),
          matching: find.text('Thành viên'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('assign-group-collaborators'),
          matching: find.text('Cộng tác viên'),
        ),
        findsOneWidget,
      );
      expect(_key('assign-option-minh'), findsOneWidget);
      // Members come first.
      final memberY = tester.getTopLeft(_key('assign-option-minh')).dy;
      await _reveal(tester, 'assign-option-lan');
      expect(
        tester.getTopLeft(_key('assign-option-lan')).dy,
        greaterThan(memberY),
      );
      await _reveal(tester, 'assign-option-hoa');
      expect(_key('assign-option-yen'), findsNothing);
    });

    testWidgets('choosing a collaborator shows "Thù lao" prefilled with '
        'defaultFee and the note', (tester) async {
      await _open(tester, collaborators: collaborators);
      expect(_key('assign-fee'), findsNothing);
      await tester.tap(_key('assign-option-lan'));
      await tester.pump();
      expect(find.text('Thù lao'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('assign-fee')).controller!.text,
        '800.000',
      );
      expect(
        find.text(
          'Lan Phương có 6 giờ để nhận việc; khách chỉ thấy thợ khi Lan '
          'Phương đã nhận.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty fee shows "Nhập thù lao cho cộng tác viên"', (
      tester,
    ) async {
      final h = await _open(tester, collaborators: collaborators);
      await _reveal(tester, 'assign-option-hoa');
      await tester.tap(_key('assign-option-hoa'));
      await tester.pump();
      expect(tester.widget<TextField>(_key('assign-fee')).controller!.text, '');
      await tester.ensureVisible(_key('assign-submit'));
      await tester.tap(_key('assign-submit'));
      await _settle(tester);
      expect(find.text('Nhập thù lao cho cộng tác viên'), findsOneWidget);
      expect(h.world.bookings.studioCalls, isEmpty);
    });

    testWidgets('primary reads "Gửi việc cho {name}" and calls assignBooking '
        'with assigneeKind collaborator and the fee', (tester) async {
      final h = await _open(tester, collaborators: collaborators);
      await tester.tap(_key('assign-option-lan'));
      await tester.pump();
      expect(_submit(tester).label, 'Gửi việc cho Lan Phương');
      // The sheet's only gradient button.
      expect(find.byType(CtaSurface), findsOneWidget);
      await tester.enterText(_key('assign-fee'), '900000');
      await tester.pump();
      await tester.ensureVisible(_key('assign-submit'));
      await tester.tap(_key('assign-submit'));
      await _settle(tester);
      final (call, payload) = h.world.bookings.studioCalls.single;
      expect(call, 'assignBooking');
      expect(payload, {
        'bookingId': 'sb1',
        'assigneeId': 'lan',
        'assigneeKind': 'collaborator',
        'agreedFee': 900000,
      });
      expect(h.result, isTrue);
    });

    testWidgets('choosing a member keeps S26 behaviour ("Giao cho {name}", '
        'no fee)', (tester) async {
      final h = await _open(tester, collaborators: collaborators);
      await tester.tap(_key('assign-option-lan'));
      await tester.pump();
      await tester.tap(_key('assign-option-nhung'));
      await tester.pump();
      expect(_submit(tester).label, 'Giao cho Hồng Nhung');
      expect(_key('assign-fee'), findsNothing);
      await tester.ensureVisible(_key('assign-submit'));
      await tester.tap(_key('assign-submit'));
      await _settle(tester);
      expect(h.world.bookings.studioCalls.single.$2, {
        'bookingId': 'sb1',
        'assigneeId': 'nhung',
      });
    });

    testWidgets('fits 320dp at 1.3x text with a collaborator picked', (
      tester,
    ) async {
      await _open(
        tester,
        collaborators: collaborators,
        width: 320,
        height: 640,
        textScale: 1.3,
      );
      await _reveal(tester, 'assign-option-lan');
      await tester.tap(_key('assign-option-lan'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

extension on AssignmentOption {
  AssignmentOption copyWithState(AssignState state) => AssignmentOption(
    uid: uid,
    name: name,
    avatarUrl: avatarUrl,
    tomatoPct: tomatoPct,
    reviewCount: reviewCount,
    state: state,
    busyStart: busyStart,
    busyEnd: busyEnd,
  );
}
