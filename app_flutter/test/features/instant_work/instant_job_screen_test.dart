import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/location/location_repository.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

/// Degrees of latitude per metre (about).
const _degPerM = 1 / 111195.0;

({double lat, double lng}) _north(double metres) =>
    (lat: taoDan.lat + metres * _degPerM, lng: taoDan.lng);

InstantWorld _world({
  InstantRequest? request,
  ({double lat, double lng}) position = taoDan,
  double accuracyM = 35,
  LocationPermissionStatus permission = LocationPermissionStatus.granted,
}) {
  final w = InstantWorld(
    location: FakeLocationRepository(status: permission, position: position)
      ..accuracyM = accuracyM,
  );
  w.repo.emitRequest('req1', request ?? jobRequestOf('req1'));
  return w;
}

Future<void> _end(WidgetTester tester, FakeInstantRepository repo) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await repo.dispose();
}

AppButton _button(WidgetTester tester, String key) =>
    tester.widget<AppButton>(find.byKey(Key(key)));

String _path(GoRouter router) => router.state.uri.toString();

void main() {
  testWidgets('assigned: the first fix calls updateJob(startRoute, location)', (
    tester,
  ) async {
    final w = _world(
      request: jobRequestOf('req1', status: InstantStatus.assigned),
    );
    await pumpJobScreen(tester, w);

    final call = w.repo.callsOf('updateJob').single;
    expect(call.args['requestId'], 'req1');
    expect(call.args['action'], InstantJobAction.startRoute);
    expect(call.args['location'], (
      lat: taoDan.lat,
      lng: taoDan.lng,
      accuracyM: 35.0,
    ));
    expect(w.location.highAccuracyFixCalls, 0);
    expect(find.text('Đang đến'), findsOneWidget);
    expect(find.text('Lan Anh · Chân dung 1 giờ'), findsOneWidget);

    // The server moved it on and wrote that point as the track: no second
    // write at once, the next one after a move.
    w.repo.emitRequest('req1', jobRequestOf('req1'));
    await settleInstant(tester);
    expect(w.repo.callsOf('shareTrack'), isEmpty);
    w.location.position = _north(30);
    await w.wait(tester, const Duration(seconds: 20));
    expect(w.repo.callsOf('shareTrack'), hasLength(1));
    expect(w.repo.callsOf('updateJob'), hasLength(1));
    await _end(tester, w.repo);
  });

  testWidgets(
    'a failed start_route is tried again within the cadence with a fresh fix '
    'and the job reaches en route',
    (tester) async {
      final logged = <String?>[];
      final print = debugPrint;
      debugPrint = (m, {wrapWidth}) => logged.add(m);
      // Restored at the end: the binding checks it before tear-downs.

      final w = _world(
        request: jobRequestOf('req1', status: InstantStatus.assigned),
      );
      w.repo.failNext('updateJob', 'network');
      await pumpJobScreen(tester, w);
      expect(w.repo.callsOf('updateJob'), hasLength(1)); // refused
      expect(logged, ['instant start_route failed: network']);

      w.location.position = _north(40);
      await w.wait(tester, const Duration(seconds: 10));
      expect(w.repo.callsOf('updateJob'), hasLength(1));
      await w.wait(tester, const Duration(seconds: 10)); // past 16 s
      final retry = w.repo.callsOf('updateJob').last;
      expect(w.repo.callsOf('updateJob'), hasLength(2));
      expect(retry.args['action'], InstantJobAction.startRoute);
      expect(
        (retry.args['location']! as InstantLocationArgs).lat,
        _north(40).lat,
      );
      // The fresh fix is what the screen measures from (40 m: "0,1 km").
      expect(find.text('Phường Bến Thành, Quận 1 · 0,1 km'), findsOneWidget);

      w.repo.emitRequest('req1', jobRequestOf('req1'));
      await settleInstant(tester);
      expect(find.text('Đang đến'), findsOneWidget);
      // Past the 60 s silence, on the 64 s tick.
      await w.wait(tester, const Duration(seconds: 70));
      // En route now: no more start_route, the track goes on instead.
      expect(w.repo.callsOf('updateJob'), hasLength(2));
      expect(w.repo.callsOf('shareTrack'), isNotEmpty);
      await _end(tester, w.repo);
      debugPrint = print;
    },
  );

  testWidgets('"Đã đến" while still assigned sends start_route first', (
    tester,
  ) async {
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logged.add(m);
    // Restored at the end: the binding checks it before tear-downs.

    final w = _world(
      request: jobRequestOf('req1', status: InstantStatus.assigned),
      position: _north(150),
    );
    w.repo.failNext('updateJob', 'network');
    await pumpJobScreen(tester, w);
    expect(w.repo.callsOf('updateJob'), hasLength(1)); // refused

    await tester.tap(find.byKey(const Key('job-arrive')));
    await settleInstant(tester);
    final calls = w.repo.callsOf('updateJob').toList();
    expect(calls.map((c) => c.args['action']), [
      InstantJobAction.startRoute,
      InstantJobAction.startRoute,
      InstantJobAction.arrive,
    ]);
    // Both with the arrival's GPS fix.
    expect(w.location.highAccuracyFixCalls, 1);
    expect(calls[1].args['location'], calls[2].args['location']);

    // The pending retry is gone: nothing more.
    await w.wait(tester, const Duration(minutes: 1));
    expect(w.repo.callsOf('updateJob'), hasLength(3));
    await _end(tester, w.repo);
    debugPrint = print;
  });

  testWidgets('en route: map pins, area line, "Chỉ đường" opens the maps URL', (
    tester,
  ) async {
    final w = _world(position: taoDanNorth);
    await pumpJobScreen(tester, w);

    // Map: the customer at the meet point and "Bạn" from the latest fix.
    final map = find.byKey(const Key('job-map'));
    expect(
      find.descendant(of: map, matching: find.text('Lan Anh')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: map, matching: find.text('Bạn')),
      findsOneWidget,
    );
    expect(find.text('Công viên Tao Đàn'), findsOneWidget);
    expect(find.text('Phường Bến Thành, Quận 1 · 0,4 km'), findsOneWidget);
    expect(find.text('Đã nhận · 09:00'), findsOneWidget);
    expect(find.text('Đã đến (bật khi còn cách 200 m)'), findsOneWidget);
    expect(find.text('Bắt đầu chụp · Hoàn thành'), findsOneWidget);
    expect(
      find.text(
        'Vị trí của bạn chỉ chia sẻ với khách trong lúc đang đến. Tới nơi là dừng.',
      ),
      findsOneWidget,
    );
    expect(find.text('Huỷ việc'), findsOneWidget);
    // Opened while en route: the first fix is shared at once.
    final track = w.repo.callsOf('shareTrack').single;
    expect(track.args['lat'], taoDanNorth.lat);
    expect(track.args['accuracyM'], 35.0);

    await tester.tap(find.text('Chỉ đường'));
    await tester.pump();
    expect(
      w.launcher.opened.single.toString(),
      'https://www.google.com/maps/dir/?api=1&destination=10.7745,106.6918',
    );
    await _end(tester, w.repo);
  });

  testWidgets('chat icon opens the request chat', (tester) async {
    final w = _world();
    final router = await pumpJobScreen(tester, w);

    await tester.tap(find.byKey(const Key('job-chat')));
    await settleInstant(tester);
    expect(_path(router), '/chat/chat_cus1_me');
    await _end(tester, w.repo);
  });

  testWidgets(
    'Đã đến disabled at 350 m with "Còn cách 350 m. Tới gần hơn để bấm Đã đến."',
    (tester) async {
      final w = _world(position: taoDanNorth);
      await pumpJobScreen(tester, w);

      expect(_button(tester, 'job-arrive').onPressed, isNull);
      expect(
        find.text('Còn cách 350 m. Tới gần hơn để bấm Đã đến.'),
        findsOneWidget,
      );
      expect(w.repo.callsOf('updateJob'), isEmpty);
      await _end(tester, w.repo);
    },
  );

  testWidgets('Đã đến at 150 m calls arrive', (tester) async {
    final w = _world(position: _north(150));
    await pumpJobScreen(tester, w);
    expect(find.byKey(const Key('job-arrive-far')), findsNothing);

    await tester.tap(find.byKey(const Key('job-arrive')));
    await settleInstant(tester);

    final call = w.repo.callsOf('updateJob').single;
    expect(call.args['action'], InstantJobAction.arrive);
    expect(call.args['force'], isFalse);
    expect((call.args['location']! as InstantLocationArgs).accuracyM, 35.0);
    // The arrival takes the one GPS-grade fix.
    expect(w.location.highAccuracyFixCalls, 1);
    await _end(tester, w.repo);
  });

  testWidgets(
    'poor accuracy opens "GPS chưa chính xác" and confirms with force',
    (tester) async {
      final w = _world(position: taoDanNorth, accuracyM: 150);
      await pumpJobScreen(tester, w);
      // Far, but the fix is too rough to say so: the button stays on.
      expect(_button(tester, 'job-arrive').onPressed, isNotNull);
      expect(find.byKey(const Key('job-arrive-far')), findsNothing);

      await tester.tap(find.byKey(const Key('job-arrive')));
      await settleInstant(tester);
      expect(find.text('GPS chưa chính xác'), findsOneWidget);
      expect(
        find.text(
          'Vị trí đang lệch khoảng 150 m. Xác nhận bạn đã tới điểm hẹn?',
        ),
        findsOneWidget,
      );
      expect(w.repo.callsOf('updateJob'), isEmpty);

      await tester.tap(find.text('Xác nhận đã đến'));
      await settleInstant(tester);
      final call = w.repo.callsOf('updateJob').single;
      expect(call.args['action'], InstantJobAction.arrive);
      expect(call.args['force'], isTrue);
      // The real accuracy, never a constant.
      expect((call.args['location']! as InstantLocationArgs).accuracyM, 150.0);
      await _end(tester, w.repo);
    },
  );

  testWidgets(
    'a good fix far away after the tap says how far and does not arrive',
    (tester) async {
      // The route fix was rough (button on); the GPS fix is good and far.
      final w = _world(position: taoDanNorth, accuracyM: 150);
      await pumpJobScreen(tester, w);
      w.location.accuracyM = 20;

      await tester.tap(find.byKey(const Key('job-arrive')));
      await settleInstant(tester);
      expect(find.text('GPS chưa chính xác'), findsNothing);
      expect(w.repo.callsOf('updateJob'), isEmpty);
      expect(_button(tester, 'job-arrive').onPressed, isNull);
      expect(find.byKey(const Key('job-arrive-far')), findsOneWidget);
      await _end(tester, w.repo);
    },
  );

  testWidgets(
    'arrived: "Bắt đầu chụp" calls start; "Khách không có mặt (sau 12:40)" '
    'disabled until 15 minutes, then confirm sheet "Khách được hoàn 50%, bạn '
    'nhận 345.000₫." calls noShow',
    (tester) async {
      final w = _world(
        request: jobRequestOf(
          'req1',
          status: InstantStatus.arrived,
          arrivedAt: instantNow.subtract(
            const Duration(minutes: 2, seconds: 20),
          ),
        ),
      );
      await pumpJobScreen(tester, w);

      expect(find.text('Đã đến'), findsOneWidget); // bar title
      expect(find.text('Phường Bến Thành, Quận 1 · điểm hẹn'), findsOneWidget);
      expect(find.text('Đã đến · 08:57'), findsOneWidget);
      // No map, no track once arrived.
      expect(find.byKey(const Key('job-map')), findsNothing);
      expect(w.repo.callsOf('shareTrack'), isEmpty);

      await tester.tap(find.text('Bắt đầu chụp').last);
      await settleInstant(tester);
      expect(
        w.repo.callsOf('updateJob').single.args['action'],
        InstantJobAction.start,
      );

      final noShow = find.byKey(const Key('job-no-show'));
      AppButton noShowButton() => tester.widget<AppButton>(
        find.descendant(of: noShow, matching: find.byType(AppButton)),
      );
      expect(find.text('Khách không có mặt (sau 12:40)'), findsOneWidget);
      expect(noShowButton().onPressed, isNull);
      await w.wait(tester, const Duration(minutes: 12, seconds: 30));
      expect(find.text('Khách không có mặt (sau 00:10)'), findsOneWidget);
      await w.wait(tester, const Duration(seconds: 10));
      expect(find.text('Khách không có mặt'), findsOneWidget);
      expect(noShowButton().onPressed, isNotNull);

      await tester.tap(noShow);
      await settleInstant(tester);
      expect(find.text('Báo khách không có mặt?'), findsOneWidget);
      expect(
        find.text('Khách được hoàn 50%, bạn nhận 345.000₫.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Báo khách không có mặt'));
      await settleInstant(tester);
      expect(
        w.repo.callsOf('updateJob').last.args['action'],
        InstantJobAction.noShow,
      );
      await _end(tester, w.repo);
    },
  );

  testWidgets(
    'shooting: ring counts to shootEndsAt and "Hoàn thành" calls finish; '
    'reaching 0 calls tick',
    (tester) async {
      final w = _world(
        request: jobRequestOf(
          'req1',
          status: InstantStatus.inProgress,
          arrivedAt: instantNow.subtract(const Duration(minutes: 30)),
          // 38:12 left of the hour.
          startedAt: instantNow.subtract(
            const Duration(minutes: 21, seconds: 48),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      await pumpJobScreen(tester, w);

      expect(find.text('Đang chụp'), findsWidgets); // title and badge
      expect(find.bySemanticsLabel(RegExp('^Còn 38 phút')), findsOneWidget);
      expect(find.text('còn lại'), findsOneWidget);
      expect(find.text('Bắt đầu 08:38 · Công viên Tao Đàn'), findsOneWidget);
      expect(
        find.text('Hết giờ gói hoặc bấm Hoàn thành, khách sẽ xác nhận.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('job-finish')));
      await settleInstant(tester);
      expect(
        w.repo.callsOf('updateJob').single.args['action'],
        InstantJobAction.finish,
      );
      expect(w.repo.callsOf('tick'), isEmpty);

      await w.wait(tester, const Duration(minutes: 38, seconds: 20));
      expect(w.repo.callsOf('tick').single.args['requestId'], 'req1');
      await _end(tester, w.repo);
      semantics.dispose();
    },
  );

  testWidgets('finished: note and "Về Công việc"', (tester) async {
    final w = _world(
      request: jobRequestOf(
        'req1',
        status: InstantStatus.finished,
        startedAt: instantNow.subtract(const Duration(hours: 1)),
        finishedAt: instantNow,
      ),
    );
    final router = await pumpJobScreen(tester, w);

    expect(find.text('Chờ khách xác nhận'), findsOneWidget);
    expect(find.text('Hoàn thành 09:00 · Công viên Tao Đàn'), findsOneWidget);
    expect(find.text('CHỜ KHÁCH'), findsOneWidget);
    expect(
      find.text(
        'Khách xác nhận hoặc tự hoàn thành sau 2 giờ. Tiền chuyển cho bạn 24 giờ sau khi hoàn thành.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AppButton), findsOneWidget); // no primary action
    await tester.tap(find.text('Về Công việc'));
    await settleInstant(tester);
    expect(_path(router), '/bookings');
    await _end(tester, w.repo);
  });

  testWidgets('completed: "Đã hoàn thành" and "Về Công việc"', (tester) async {
    final w = _world(
      request: jobRequestOf(
        'req1',
        status: InstantStatus.completed,
        finishedAt: instantNow,
      ),
    );
    await pumpJobScreen(tester, w);

    expect(find.text('Đã hoàn thành'), findsOneWidget);
    expect(find.text('Về Công việc'), findsOneWidget);
    await _end(tester, w.repo);
  });

  testWidgets(
    'customer cancelled: "Khách đã huỷ yêu cầu" and "Bạn nhận 138.000₫ phí đi lại."',
    (tester) async {
      final w = _world(
        request: jobRequestOf(
          'req1',
          status: InstantStatus.cancelledByCustomer,
          feeVnd: 138000,
        ),
      );
      await pumpJobScreen(tester, w);

      expect(find.text('Khách đã huỷ yêu cầu'), findsOneWidget);
      expect(find.text('Bạn nhận 138.000₫ phí đi lại.'), findsOneWidget);
      expect(find.text('Về Công việc'), findsOneWidget);

      // #140: nothing was paid, so no fee.
      w.repo.emitRequest(
        'req1',
        jobRequestOf(
          'req1',
          status: InstantStatus.cancelledByCustomer,
          feeVnd: 0,
        ),
      );
      await settleInstant(tester);
      expect(find.text('Không cần tới điểm hẹn nữa.'), findsOneWidget);
      await _end(tester, w.repo);
    },
  );

  testWidgets("contact dial shows the customer's channels from the copy", (
    tester,
  ) async {
    final w = _world();
    await pumpJobScreen(tester, w);
    // #140: unpaid, no copy: no dial (the chat in the bar stays).
    expect(find.text('Liên hệ'), findsNothing);

    w.repo.emitContact(
      'req1',
      const BookingContactSnapshot(
        name: 'Lan Anh',
        phone: '+84901234567',
        allowZalo: true,
      ),
    );
    await settleInstant(tester);
    expect(find.text('Liên hệ'), findsOneWidget);
    await tester.tap(find.text('Liên hệ'));
    await settleInstant(tester);
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('Zalo'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNothing);
    await _end(tester, w.repo);
  });

  testWidgets('location denied shows jobLocationNeeded and no tracker', (
    tester,
  ) async {
    final w = _world(
      request: jobRequestOf('req1', status: InstantStatus.assigned),
      permission: LocationPermissionStatus.denied,
    );
    await pumpJobScreen(tester, w);

    expect(
      find.text('Cho phép dùng vị trí để chia sẻ đường đi với khách.'),
      findsOneWidget,
    );
    expect(w.repo.callsOf('updateJob'), isEmpty);
    expect(w.repo.callsOf('shareTrack'), isEmpty);
    expect(w.location.fixCalls, 0);
    await w.wait(tester, const Duration(seconds: 60));
    expect(w.location.fixCalls, 0);

    // "Cho phép" asks again; granted, the route starts.
    await tester.tap(find.text('Cho phép'));
    await settleInstant(tester);
    expect(w.location.requestCalls, 1);
    expect(
      w.repo.callsOf('updateJob').single.args['action'],
      InstantJobAction.startRoute,
    );
    expect(
      find.text('Cho phép dùng vị trí để chia sẻ đường đi với khách.'),
      findsNothing,
    );
    await _end(tester, w.repo);
  });

  testWidgets('no route sharing after arrival (tracker stopped)', (
    tester,
  ) async {
    final w = _world(position: _north(150));
    await pumpJobScreen(tester, w);
    expect(w.repo.callsOf('shareTrack'), hasLength(1));

    await tester.tap(find.byKey(const Key('job-arrive')));
    await settleInstant(tester);
    w.repo.emitRequest(
      'req1',
      jobRequestOf(
        'req1',
        status: InstantStatus.arrived,
        arrivedAt: instantNow,
      ),
    );
    await settleInstant(tester);
    final fixes = w.location.fixCalls;

    w.location.position = _north(80);
    await w.wait(tester, const Duration(minutes: 2));
    expect(w.repo.callsOf('shareTrack'), hasLength(1));
    expect(w.location.fixCalls, fixes);
    await _end(tester, w.repo);
  });

  testWidgets(
    'permission revoked en route shows jobLocationNeeded, not a stale fix',
    (tester) async {
      final w = _world(position: taoDanNorth);
      await pumpJobScreen(tester, w);
      final map = find.byKey(const Key('job-map'));
      expect(
        find.descendant(of: map, matching: find.text('Bạn')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('job-arrive-far')), findsOneWidget);

      // The next sample gets no fix: the permission is checked again.
      w.location.status = LocationPermissionStatus.denied;
      await w.wait(tester, const Duration(seconds: 20));
      expect(
        find.text('Cho phép dùng vị trí để chia sẻ đường đi với khách.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: map, matching: find.text('Bạn')),
        findsNothing,
      );
      expect(find.byKey(const Key('job-arrive-far')), findsNothing);
      await _end(tester, w.repo);
    },
  );

  testWidgets('permission revoked while in the background shows on resume', (
    tester,
  ) async {
    final w = _world(position: taoDanNorth);
    await pumpJobScreen(tester, w);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    w.location.status = LocationPermissionStatus.deniedForever;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleInstant(tester);
    expect(
      find.text('Cho phép dùng vị trí để chia sẻ đường đi với khách.'),
      findsOneWidget,
    );
    expect(find.text('Mở cài đặt'), findsOneWidget);
    expect(find.byKey(const Key('job-arrive-far')), findsNothing);
    await _end(tester, w.repo);
  });

  testWidgets('the app in the background takes no fix and shares nothing', (
    tester,
  ) async {
    final w = _world();
    await pumpJobScreen(tester, w);
    expect(w.repo.callsOf('shareTrack'), hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final fixes = w.location.fixCalls;
    w.location.position = _north(100);
    await w.wait(tester, const Duration(minutes: 2));
    expect(w.location.fixCalls, fixes);
    expect(w.repo.callsOf('shareTrack'), hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleInstant(tester);
    expect(w.repo.callsOf('shareTrack'), hasLength(2));
    await _end(tester, w.repo);
  });

  testWidgets('"Huỷ việc" opens S13.08; a cancel goes back to Live Shutter', (
    tester,
  ) async {
    final w = _world();
    final router = await pumpJobScreen(tester, w);

    await tester.tap(find.byKey(const Key('job-cancel')));
    await settleInstant(tester);
    expect(find.text('Huỷ việc chụp ngay?'), findsOneWidget);
    expect(w.repo.callsOf('cancel').single.args['dryRun'], isTrue);

    await tester.tap(find.byKey(const Key('provider-cancel-confirm')));
    await settleInstant(tester);
    expect(w.repo.callsOf('cancel').last.args['dryRun'], isFalse);
    expect(_path(router), '/work/instant');
    await _end(tester, w.repo);
  });

  testWidgets('a request no longer theirs goes back to Live Shutter', (
    tester,
  ) async {
    final w = _world();
    final router = await pumpJobScreen(tester, w);
    expect(_path(router), '/work/instant/req1');

    // The photographer cancelled elsewhere: the request is choosing again
    // and no longer readable.
    w.repo.emitRequest('req1', null);
    await settleInstant(tester);
    expect(_path(router), '/work/instant');
    await _end(tester, w.repo);
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    for (final request in [
      jobRequestOf('req1'),
      jobRequestOf(
        'req1',
        status: InstantStatus.arrived,
        arrivedAt: instantNow,
      ),
      jobRequestOf(
        'req1',
        status: InstantStatus.inProgress,
        startedAt: instantNow,
      ),
      jobRequestOf(
        'req1',
        status: InstantStatus.finished,
        finishedAt: instantNow,
      ),
    ]) {
      final w = _world(request: request, position: taoDanNorth);
      w.repo.emitContact(
        'req1',
        const BookingContactSnapshot(name: 'Lan Anh', phone: '+84901234567'),
      );
      await pumpJobScreen(
        tester,
        w,
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      expect(tester.takeException(), isNull, reason: request.status.code);
      await _end(tester, w.repo);
    }
  });
}

/// `updateJob`'s recorded location.
typedef InstantLocationArgs = ({double lat, double lng, double accuracyM});
