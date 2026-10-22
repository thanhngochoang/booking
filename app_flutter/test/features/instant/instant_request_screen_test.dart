import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_customer_world.dart';

const _required = 'Nhập tên điểm hẹn để nhiếp ảnh gia dễ tìm.';
const _seeMatches = 'Xem nhiếp ảnh gia phù hợp';
const _place = 'Cổng Trương Định, Công viên Tao Đàn';

final _name = find.byKey(const Key('instant-meet-point'));
final _note = find.byKey(const Key('instant-note'));
final _submit = find.byKey(const Key('instant-see-matches'));

String _fieldText(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).controller!.text;

bool _packageSelected(WidgetTester tester, String code) => tester
    .widget<Semantics>(find.byKey(Key('instant-package-$code')))
    .properties
    .selected!;

bool _genreSelected(WidgetTester tester, InstantGenre g) =>
    tester.widget<AppChip>(find.byKey(Key('instant-genre-${g.code}'))).selected;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settleInstant(tester);
}

Future<void> _type(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

/// The top page's location, pushed pages included.
String _location(GoRouter router) => router.state.uri.toString();

void main() {
  testWidgets(
    'shows the three packages with short prices and the 1 giờ package selected by default',
    (tester) async {
      await pumpInstantCustomer(tester, InstantCustomerWorld());
      expect(find.text('Chụp ngay'), findsOneWidget);
      expect(find.text('Nhiếp ảnh gia tới trong 30–90 phút'), findsOneWidget);
      for (final t in [
        '30 phút',
        '1 giờ',
        '2 giờ',
        '15 ảnh',
        '30 ảnh',
        '60 ảnh',
        '390K',
        '690K',
        '1,19M',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(_packageSelected(tester, 'p30'), isFalse);
      expect(_packageSelected(tester, 'p60'), isTrue);
      expect(_packageSelected(tester, 'p120'), isFalse);

      await _tap(tester, find.text('2 giờ'));
      expect(_packageSelected(tester, 'p60'), isFalse);
      expect(_packageSelected(tester, 'p120'), isTrue);
      expect(
        find.text(
          'Xem 5 người phù hợp miễn phí. Chỉ trả khi gửi lời mời; tiền được '
          'giữ an toàn và hoàn 100% nếu bạn huỷ khi chưa có người nhận.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, _seeMatches), findsOneWidget);
    },
  );

  testWidgets('five genre chips, Chân dung selected', (tester) async {
    await pumpInstantCustomer(tester, InstantCustomerWorld());
    for (final t in [
      'Chân dung',
      'Cặp đôi',
      'Gia đình',
      'Sự kiện nhỏ',
      'Sản phẩm',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // Mock order: "… Sản phẩm, Sự kiện nhỏ".
    final xs = [
      for (final t in [
        'Chân dung',
        'Cặp đôi',
        'Gia đình',
        'Sản phẩm',
        'Sự kiện nhỏ',
      ])
        tester.getTopLeft(find.text(t)).dx,
    ];
    expect(xs, [...xs]..sort());
    expect(_genreSelected(tester, InstantGenre.portrait), isTrue);
    for (final g in InstantGenre.values.skip(1)) {
      expect(_genreSelected(tester, g), isFalse, reason: g.code);
    }
    await _tap(tester, find.byKey(const Key('instant-genre-family')));
    expect(_genreSelected(tester, InstantGenre.family), isTrue);
    expect(_genreSelected(tester, InstantGenre.portrait), isFalse);
  });

  testWidgets(
    'map pin reads "Vị trí của bạn" until a name is typed, then "Điểm hẹn · {name}"',
    (tester) async {
      await pumpInstantCustomer(tester, InstantCustomerWorld());
      expect(find.byType(MapPreview), findsOneWidget);
      expect(tester.getSize(find.byType(MapPreview)).height, 170);
      expect(find.text('Vị trí của bạn'), findsOneWidget);
      await _type(tester, _name, _place);
      expect(find.text('Vị trí của bạn'), findsNothing);
      expect(find.text('Điểm hẹn · $_place'), findsOneWidget);
      await _type(tester, _name, '   ');
      expect(find.text('Vị trí của bạn'), findsOneWidget);
    },
  );

  testWidgets('recenter takes a new fix', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantCustomer(tester, w);
    final before = w.location.fixCalls;
    w.location.position = taoDanNorth;
    await _tap(tester, find.byTooltip('Về vị trí của tôi'));
    expect(w.location.fixCalls, before + 1);
    expect(w.location.highAccuracyFixCalls, 0);

    await _type(tester, _name, _place);
    await _tap(tester, _submit);
    final args = w.repo.callsOf('createRequest').single.args;
    expect(args['lat'], taoDanNorth.lat);
    expect(args['lng'], taoDanNorth.lng);
  });

  testWidgets(
    'empty name shows "Nhập tên điểm hẹn để nhiếp ảnh gia dễ tìm." and does not call createRequest',
    (tester) async {
      final w = InstantCustomerWorld();
      await pumpInstantCustomer(tester, w);
      await _tap(tester, _submit);
      expect(find.text(_required), findsOneWidget);
      expect(w.repo.callsOf('createRequest'), isEmpty);
      // Typing a name takes the line away.
      await _type(tester, _name, 'Hồ Con Rùa');
      expect(find.text(_required), findsNothing);
    },
  );

  testWidgets('note longer than 140 is cut by the field', (tester) async {
    await pumpInstantCustomer(tester, InstantCustomerWorld());
    await _type(tester, _note, 'a' * 150);
    expect(_fieldText(tester, _note).length, 140);
    expect(find.text('140/140'), findsOneWidget);
    await _type(tester, _name, 'b' * 90);
    expect(_fieldText(tester, _name).length, 80);
  });

  testWidgets(
    'submit calls createRequest with the exact payload and goes to /instant/{id}',
    (tester) async {
      final w = InstantCustomerWorld();
      final router = await pumpInstantCustomer(tester, w);
      await _tap(tester, find.text('2 giờ'));
      await _tap(tester, find.byKey(const Key('instant-genre-couple')));
      await _type(tester, _name, '  $_place ');
      await _type(tester, _note, ' Mình mặc áo dài trắng ');
      await _tap(tester, _submit);

      final call = w.repo.callsOf('createRequest').single;
      expect(call.args, {
        'packageCode': 'p120',
        'genre': InstantGenre.couple,
        'lat': taoDan.lat,
        'lng': taoDan.lng,
        'meetPointName': _place,
        'note': 'Mình mặc áo dài trắng',
      });
      expect(_location(router), '/instant/req_new');
      expect(find.byType(InstantFlowScreen), findsOneWidget);
    },
  );

  testWidgets('an empty note is sent as none', (tester) async {
    final w = InstantCustomerWorld();
    await pumpInstantCustomer(tester, w);
    await _type(tester, _name, _place);
    await _tap(tester, _submit);
    expect(w.repo.callsOf('createRequest').single.args['note'], isNull);
  });

  testWidgets(
    'no phone goes to /profile/phone?returnTo=/instant and the draft survives the round trip',
    (tester) async {
      final w = InstantCustomerWorld(contact: null);
      final router = await pumpInstantCustomer(tester, w);
      await _tap(tester, find.text('30 phút'));
      await _tap(tester, find.byKey(const Key('instant-genre-product')));
      await _type(tester, _name, _place);
      await _type(tester, _note, 'Chụp sản phẩm gốm');
      await _tap(tester, _submit);

      expect(w.repo.callsOf('createRequest'), isEmpty);
      expect(Uri.parse(_location(router)).path, '/profile/phone');
      expect(
        Uri.parse(_location(router)).queryParameters['returnTo'],
        '/instant',
      );

      await _tap(tester, find.byKey(const Key('save-phone')));
      expect(_location(router), '/instant');
      expect(_fieldText(tester, _name), _place);
      expect(_fieldText(tester, _note), 'Chụp sản phẩm gốm');
      expect(_packageSelected(tester, 'p30'), isTrue);
      expect(_genreSelected(tester, InstantGenre.product), isTrue);

      await _tap(tester, _submit);
      final args = w.repo.callsOf('createRequest').single.args;
      expect(args['packageCode'], 'p30');
      expect(args['genre'], InstantGenre.product);
      expect(args['meetPointName'], _place);
      expect(args['note'], 'Chụp sản phẩm gốm');
      expect(_location(router), '/instant/req_new');
    },
  );

  testWidgets('phone_required from the server takes the same detour', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('createRequest', 'phone_required');
    final router = await pumpInstantCustomer(tester, w);
    await _type(tester, _name, _place);
    await _tap(tester, _submit);
    expect(Uri.parse(_location(router)).path, '/profile/phone');
  });

  testWidgets(
    'outside_service_area shows the message and "Đặt lịch thường" opens /action',
    (tester) async {
      final w = InstantCustomerWorld();
      w.repo.failNext('createRequest', 'outside_service_area');
      final router = await pumpInstantCustomer(tester, w);
      await _type(tester, _name, _place);
      await _tap(tester, _submit);
      expect(
        find.text(
          'Chụp ngay chưa có ở khu vực này. Bạn có thể đặt lịch thường.',
        ),
        findsOneWidget,
      );
      await _tap(tester, find.text('Đặt lịch thường'));
      expect(_location(router), '/action');
    },
  );

  testWidgets('a refusal closes the keyboard and brings its note on screen', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('createRequest', 'outside_service_area');
    await pumpInstantCustomer(
      tester,
      w,
      textScale: 1.3,
      viewSize: const Size(320, 640),
    );
    await tester.tap(_name);
    await tester.pump();
    await _type(tester, _name, _place);
    await tester.tap(_submit);
    await settleInstant(tester);
    final focus = tester
        .widget<EditableText>(
          find.descendant(of: _name, matching: find.byType(EditableText)),
        )
        .focusNode;
    expect(focus.hasFocus, isFalse);
    final note = tester.getRect(find.byKey(const Key('instant-problem')));
    final footer = tester.getTopLeft(_submit).dy;
    expect(note.top, greaterThanOrEqualTo(0));
    expect(note.bottom, lessThanOrEqualTo(footer));
  });

  testWidgets('not_eligible says Chụp ngay is paused', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('createRequest', 'not_eligible');
    await pumpInstantCustomer(tester, w);
    await _type(tester, _name, _place);
    await _tap(tester, _submit);
    expect(find.text('Chụp ngay đang tạm dừng.'), findsOneWidget);
    expect(find.text('Đặt lịch thường'), findsNothing);
  });

  testWidgets('a network failure is a toast and the form stays', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.failNext('createRequest', 'network');
    final router = await pumpInstantCustomer(tester, w);
    await _type(tester, _name, _place);
    await _tap(tester, _submit);
    expect(find.text('Mất kết nối. Thử lại nhé.'), findsOneWidget);
    expect(_location(router), '/instant');
    expect(_fieldText(tester, _name), _place);
  });

  testWidgets('conflict opens the active request', (tester) async {
    final w = InstantCustomerWorld(
      repo: FakeInstantRepository(activeRequestId: 'req_open'),
    );
    w.repo.failNext('createRequest', 'conflict');
    final router = await pumpInstantCustomer(tester, w);
    await _type(tester, _name, _place);
    await _tap(tester, _submit);
    expect(w.repo.callsOf('myActiveRequestId'), hasLength(1));
    expect(_location(router), '/instant/req_open');
    expect(find.text('Bạn đang có một yêu cầu chụp ngay.'), findsOneWidget);
  });

  testWidgets(
    'location denied shows S13.01-noloc; "Cho phép vị trí" asks; deniedForever opens settings',
    (tester) async {
      final location = FakeLocationRepository(
        status: LocationPermissionStatus.denied,
        position: taoDan,
      );
      final w = InstantCustomerWorld(location: location);
      await pumpInstantCustomer(tester, w);
      expect(location.requestCalls, 0, reason: 'refused once: not re-asked');
      expect(find.text('Bật vị trí để Chụp ngay'), findsOneWidget);
      expect(
        find.text('Nhiếp ảnh gia cần biết bạn đang ở đâu để tới đúng chỗ.'),
        findsOneWidget,
      );
      expect(find.byType(MapPreview), findsNothing);
      expect(find.byKey(const Key('instant-see-matches')), findsNothing);
      expect(tester.widget<ScreenCode>(find.byType(ScreenCode)).label, 'noloc');
      expect(find.widgetWithText(AppButton, 'Cho phép vị trí'), findsOneWidget);

      await _tap(tester, find.text('Cho phép vị trí'));
      expect(location.requestCalls, 1);
      expect(find.byType(MapPreview), findsOneWidget);
      expect(tester.widget<ScreenCode>(find.byType(ScreenCode)).label, isNull);

      // Refused for good: the button opens the Settings app.
      location
        ..status = LocationPermissionStatus.deniedForever
        ..position = null;
      final w2 = InstantCustomerWorld(location: location);
      final r2 = await pumpInstantCustomer(tester, w2);
      expect(find.text('Bật vị trí để Chụp ngay'), findsOneWidget);
      await _tap(tester, find.text('Cho phép vị trí'));
      expect(location.openSettingsCalls, 1);
      expect(location.requestCalls, 1);
      expect(find.text('Bật vị trí để Chụp ngay'), findsOneWidget);

      await _tap(tester, find.text('Đặt lịch thường'));
      expect(_location(r2), '/action');
      expect(location.openLocationSettingsCalls, 0);
    },
  );

  testWidgets(
    'location off: "Cho phép vị trí" opens the system location settings',
    (tester) async {
      final location = FakeLocationRepository(
        status: LocationPermissionStatus.serviceOff,
      );
      await pumpInstantCustomer(
        tester,
        InstantCustomerWorld(location: location),
      );
      expect(find.text('Bật vị trí để Chụp ngay'), findsOneWidget);
      await _tap(tester, find.text('Cho phép vị trí'));
      expect(location.openLocationSettingsCalls, 1);
      expect(location.openSettingsCalls, 0);
      expect(location.requestCalls, 0);
    },
  );

  testWidgets('never asked: opening S13.01 asks once', (tester) async {
    final location = FakeLocationRepository(position: taoDan);
    await pumpInstantCustomer(tester, InstantCustomerWorld(location: location));
    expect(location.requestCalls, 1);
    expect(find.byType(MapPreview), findsOneWidget);
  });

  testWidgets(
    'the primary button shows a loader while creating and ignores a second tap',
    (tester) async {
      final w = InstantCustomerWorld();
      final router = await pumpInstantCustomer(tester, w);
      await _type(tester, _name, _place);
      final gate = Completer<void>();
      w.repo.gate = gate;
      await tester.ensureVisible(_submit);
      await tester.tap(_submit);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.descendant(of: _submit, matching: find.byType(DotRingLoader)),
        findsOneWidget,
      );
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(w.repo.callsOf('createRequest'), hasLength(1));

      gate.complete();
      w.repo.gate = null;
      await settleInstant(tester);
      expect(w.repo.callsOf('createRequest'), hasLength(1));
      expect(_location(router), '/instant/req_new');
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp at 1.3× text (${brightness.name})', (tester) async {
      final w = InstantCustomerWorld();
      w.repo.failNext('createRequest', 'outside_service_area');
      await pumpInstantCustomer(
        tester,
        w,
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await _type(tester, _name, 'x' * 80);
      await _tap(tester, _submit);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('instant-problem')), findsOneWidget);

      // The no-location view too.
      await pumpInstantCustomer(
        tester,
        InstantCustomerWorld(
          location: FakeLocationRepository(
            status: LocationPermissionStatus.serviceOff,
          ),
        ),
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      expect(find.text('Bật vị trí để Chụp ngay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
