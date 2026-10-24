// S13.05 (`#S13.05`, `-arrived`, `-stale`): the photographer is on the way.
// Schematic map with the meet point ("Bạn") and, only while en route, the
// photographer's last point; the ETA from each point (Decision 7); the stale
// and late lines; contact; the cancel text with the free-cancel countdown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';
import 'package:photobooking/features/instant/tracking_view.dart';

import '../../support/instant_customer_world.dart';
import '../../support/meta_finders.dart';

const _minhTri = InstantParty(
  id: 'p1',
  name: 'Minh Trí',
  verified: true,
  tomatoPct: 97,
  reviewCount: 58,
  completedCount: 112,
);

/// About 1,2 km south of the meet point (ETA 6 minutes).
final _km12 = (lat: taoDan.lat - 0.0108, lng: taoDan.lng);

/// About 600 m south of the meet point (ETA 3 minutes).
final _m600 = (lat: taoDan.lat - 0.0054, lng: taoDan.lng);

/// The customer's request with Minh Trí assigned 70 s ago (past the match
/// moment, S13.04; free cancel for 50 s more); [paid] as from #202 on.
InstantRequest _tracking(
  InstantStatus status, {
  bool paid = true,
  InstantParty? photographer = _minhTri,
  Duration freeCancelLeft = const Duration(seconds: 50),
  Duration lateIn = const Duration(minutes: 24),
}) => customerRequestOf(status: status, committed: true).copyWith(
  paid: paid,
  photographerId: photographer?.id,
  photographer: photographer,
  chatId: photographer == null ? null : 'chat_cus1_p1',
  etaMinutes: 9,
  assignedAt: instantNow.subtract(const Duration(seconds: 70)),
  freeCancelUntil: instantNow.add(freeCancelLeft),
  lateDeadlineAt: instantNow.add(lateIn),
  startedRouteAt: status == InstantStatus.assigned
      ? null
      : instantNow.subtract(const Duration(seconds: 10)),
  arrivedAt: status == InstantStatus.arrived ? instantNow : null,
);

InstantTrack _point(({double lat, double lng}) p, DateTime at) =>
    InstantTrack(lat: p.lat, lng: p.lng, accuracyM: 12, at: at);

MapPreview _map(WidgetTester tester) =>
    tester.widget<MapPreview>(find.byType(MapPreview));

ScreenCode _code(WidgetTester tester) => tester.widget<ScreenCode>(
  find
      .descendant(
        of: find.byType(InstantFlowScreen),
        matching: find.byType(ScreenCode),
      )
      .first,
);

Future<void> _end(WidgetTester tester, InstantCustomerWorld w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await w.repo.dispose();
}

void main() {
  testWidgets('en_route: two labelled pins, ETA from the track '
      '("đến trong khoảng 6 phút" at 1,2 km)', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.emitTrack('req1', _point(_km12, instantNow));
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    expect(find.byType(TrackingView), findsOneWidget);
    expect(_code(tester).code, ScreenCodes.instantTracking);
    expect(_code(tester).label, isNull);

    final map = _map(tester);
    expect(map.pins, hasLength(2));
    // "Bạn" is the meet point (the customer's own position never leaves
    // the device); the photographer's pin is the track point.
    expect(map.pins[0].label, 'Bạn');
    expect(map.pins[0].self, isTrue);
    expect(map.pins[0].lat, taoDan.lat);
    expect(map.pins[1].label, 'Minh Trí · 6 phút');
    expect(map.pins[1].lat, _km12.lat);
    expect(map.route, isTrue);
    expect(map.onRecenter, isNotNull);
    expect(find.text('Minh Trí · 6 phút'), findsOneWidget);

    final meta = findMeta('97% · 112 buổi · đến trong khoảng 6 phút');
    expect(meta, findsOneWidget);
    expect(tomatoIconIn(meta), findsOneWidget);
    expect(find.text('ĐANG ĐẾN'), findsOneWidget);
    expect(
      find.text(
        'Đối chiếu ảnh đại diện khi gặp. Vị trí của Minh Trí chỉ hiện trong '
        'lúc đang đến.',
      ),
      findsOneWidget,
    );
    await _end(tester, w);
  });

  testWidgets('assigned: no photographer pin, ETA from the request', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _tracking(InstantStatus.assigned),
    );
    final map = _map(tester);
    expect(map.pins.map((p) => p.label), ['Bạn']);
    expect(map.route, isFalse);
    expect(findMeta('97% · 112 buổi · đến trong khoảng 9 phút'), findsOne);
    expect(find.text('ĐÃ NHẬN'), findsOneWidget);
    expect(w.repo.isTrackWatched('req1'), isFalse);
    await _end(tester, w);
  });

  testWidgets('a new track point updates the ETA and the pin', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.emitTrack('req1', _point(_km12, instantNow));
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    expect(find.text('Minh Trí · 6 phút'), findsOneWidget);

    await w.base.wait(tester, const Duration(seconds: 20));
    w.repo.emitTrack('req1', _point(_m600, w.base.clock.now));
    await settleInstant(tester);
    expect(find.text('Minh Trí · 3 phút'), findsOneWidget);
    expect(find.text('Minh Trí · 6 phút'), findsNothing);
    expect(_map(tester).pins[1].lat, _m600.lat);
    expect(findMeta('97% · 112 buổi · đến trong khoảng 3 phút'), findsOne);
    await _end(tester, w);
  });

  testWidgets('no point for 3 minutes shows "Đang chờ cập nhật vị trí"', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    w.repo.emitTrack('req1', _point(_km12, instantNow));
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    await w.base.wait(tester, const Duration(minutes: 2, seconds: 50));
    expect(findMeta('97% · 112 buổi · đến trong khoảng 6 phút'), findsOne);
    expect(_code(tester).label, isNull);

    await w.base.wait(tester, const Duration(seconds: 10));
    expect(findMeta('97% · 112 buổi · Đang chờ cập nhật vị trí'), findsOne);
    expect(_code(tester).label, 'stale');
    // The pin stays at the last point.
    expect(find.text('Minh Trí · 6 phút'), findsOneWidget);

    // A new point: the ETA is computed again.
    w.repo.emitTrack('req1', _point(_m600, w.base.clock.now));
    await settleInstant(tester);
    expect(findMeta('97% · 112 buổi · đến trong khoảng 3 phút'), findsOne);
    expect(_code(tester).label, isNull);
    await _end(tester, w);
  });

  testWidgets('free-cancel countdown switches the label at 2:00', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _tracking(InstantStatus.assigned),
    );
    expect(find.text('Huỷ (miễn phí thêm 0:50)'), findsOneWidget);
    await w.base.wait(tester, const Duration(seconds: 30));
    expect(find.text('Huỷ (miễn phí thêm 0:20)'), findsOneWidget);
    await w.base.wait(tester, const Duration(seconds: 20));
    expect(find.textContaining('miễn phí'), findsNothing);
    expect(find.text('Huỷ'), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets(
    'after lateDeadlineAt shows the late line and "Huỷ (hoàn 100%)"',
    (tester) async {
      final w = InstantCustomerWorld();
      w.repo.emitTrack('req1', _point(_km12, instantNow));
      await pumpInstantFlow(
        tester,
        w,
        request: _tracking(
          InstantStatus.enRoute,
          freeCancelLeft: const Duration(seconds: -1),
          lateIn: const Duration(seconds: 30),
        ),
      );
      const late = 'Minh Trí đến trễ. Bạn có thể huỷ và được hoàn 100%.';
      expect(find.text(late), findsNothing);
      expect(find.text('Huỷ'), findsOneWidget);

      await w.base.wait(tester, const Duration(seconds: 40));
      expect(find.text(late), findsOneWidget);
      expect(find.text('Huỷ (hoàn 100%)'), findsOneWidget);

      // Every cancel text opens S13.08 (the server's quote).
      await tester.tap(find.text('Huỷ (hoàn 100%)'));
      await settleInstant(tester);
      expect(w.repo.callsOf('cancel').map((c) => c.args['dryRun']), [isTrue]);
      expect(find.text('Huỷ chụp ngay?'), findsOneWidget);
      await _end(tester, w);
    },
  );

  testWidgets('unpaid (#140): no money in the cancel text or the late line', (
    tester,
  ) async {
    final w = InstantCustomerWorld();
    await pumpInstantFlow(
      tester,
      w,
      request: _tracking(
        InstantStatus.assigned,
        paid: false,
        lateIn: const Duration(seconds: 30),
      ),
    );
    expect(find.text('Huỷ'), findsOneWidget);
    expect(find.textContaining('miễn phí'), findsNothing);
    await w.base.wait(tester, const Duration(seconds: 40));
    expect(
      find.text('Minh Trí đến trễ. Bạn có thể huỷ yêu cầu.'),
      findsOneWidget,
    );
    expect(find.textContaining('hoàn 100%'), findsNothing);
    expect(find.text('Huỷ'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await settleInstant(tester);
    expect(w.repo.callsOf('cancel'), hasLength(1));
    await _end(tester, w);
  });

  testWidgets('arrived hides the photographer pin', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.emitTrack('req1', _point(_km12, instantNow));
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    expect(_map(tester).pins, hasLength(2));

    w.repo.emitRequest('req1', _tracking(InstantStatus.arrived));
    await settleInstant(tester);
    final map = _map(tester);
    expect(map.pins.map((p) => p.label), ['Bạn']);
    expect(map.route, isFalse);
    expect(find.text('Minh Trí · 6 phút'), findsNothing);
    expect(_code(tester).label, 'arrived');
    expect(find.text('Đã đến điểm hẹn'), findsOneWidget);
    expect(
      find.text('Minh Trí đang chờ bạn ở Cổng Trương Định.'),
      findsOneWidget,
    );
    expect(findMeta('97% · 112 buổi'), findsOneWidget);
    expect(find.text('ĐÃ ĐẾN'), findsOneWidget);
    // "Huỷ": the sheet shows the server's split.
    expect(find.text('Huỷ'), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('arrived stops listening to the track', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.emitTrack('req1', _point(_km12, instantNow));
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    expect(w.repo.isTrackWatched('req1'), isTrue);

    w.repo.emitRequest('req1', _tracking(InstantStatus.arrived));
    await settleInstant(tester);
    expect(w.repo.isTrackWatched('req1'), isFalse);
    await _end(tester, w);
  });

  testWidgets('a failed track listen is logged and tried again', (
    tester,
  ) async {
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    try {
      final w = InstantCustomerWorld();
      w.repo.failTrack('req1', const InstantError('network'));
      await pumpInstantFlow(
        tester,
        w,
        request: _tracking(InstantStatus.enRoute),
      );
      expect(logged, ['instant track failed: network']);
      // Without a point: the meet point only, the ETA from the request.
      expect(_map(tester).pins, hasLength(1));
      expect(findMeta('97% · 112 buổi · đến trong khoảng 9 phút'), findsOne);

      // The track is readable again; the retry listens and shows it.
      w.repo.emitTrack('req1', _point(_km12, w.base.clock.now));
      await w.base.wait(tester, kInstantTrackRetry);
      await settleInstant(tester);
      expect(find.text('Minh Trí · 6 phút'), findsOneWidget);
      expect(w.repo.isTrackWatched('req1'), isTrue);
      await _end(tester, w);
    } finally {
      debugPrint = print;
    }
  });

  testWidgets('retries stop after a few failures', (tester) async {
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    try {
      final w = InstantCustomerWorld();
      w.repo.failTrack('req1', const InstantError('network'));
      await pumpInstantFlow(
        tester,
        w,
        request: _tracking(InstantStatus.enRoute),
      );
      await w.base.wait(tester, kInstantTrackRetry * 6);
      // The first failure and one per retry, then no more.
      expect(logged, hasLength(kInstantTrackRetries + 1));
      expect(tester.takeException(), isNull);
      await _end(tester, w);
    } finally {
      debugPrint = print;
    }
  });

  testWidgets('"Nhắn tin" opens /chat/{chatId}', (tester) async {
    final w = InstantCustomerWorld();
    final router = await pumpInstantFlow(
      tester,
      w,
      request: _tracking(InstantStatus.assigned),
    );
    await tester.tap(find.text('Nhắn tin'));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/chat/chat_cus1_p1');
    await _end(tester, w);
  });

  testWidgets('"Liên hệ" requests a link with the instant subject', (
    tester,
  ) async {
    const subject = ContactSubject.instantRequest('req1');
    final links = FakeContactLinkRepository()
      ..add(
        subject,
        numbers: const ContactNumbers(phone: '+84903111222'),
        channels: const ContactChannels(call: true, zalo: true),
      );
    final contacts = FakePhotographerContactRepository()
      ..seed('p1', channels: const ContactChannels(call: true, zalo: true));
    final w = InstantCustomerWorld(
      extra: [
        contactLinkRepositoryProvider.overrideWithValue(links),
        photographerContactRepositoryProvider.overrideWithValue(contacts),
      ],
    );
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    await tester.tap(find.text('Liên hệ'));
    await settleInstant(tester);
    await tester.tap(find.text('Gọi'));
    await settleInstant(tester);
    expect(links.requests.single.subject, subject);
    expect(links.requests.single.channel, ContactChannel.call);
    expect(w.base.launcher.opened.single.toString(), 'tel:+84903111222');
    await _end(tester, w);
  });

  testWidgets('unpaid (#140): no "Liên hệ", "Nhắn tin" stays', (tester) async {
    final contacts = FakePhotographerContactRepository()
      ..seed('p1', channels: const ContactChannels(call: true));
    final w = InstantCustomerWorld(
      extra: [
        photographerContactRepositoryProvider.overrideWithValue(contacts),
      ],
    );
    await pumpInstantFlow(
      tester,
      w,
      request: _tracking(InstantStatus.enRoute, paid: false),
    );
    expect(find.text('Nhắn tin'), findsOneWidget);
    expect(find.text('Liên hệ'), findsNothing);
    expect(find.byType(ContactDial), findsNothing);
    await _end(tester, w);
  });

  testWidgets('no contact before assignment', (tester) async {
    final w = InstantCustomerWorld();
    // `searching` never renders this view.
    await pumpInstantFlow(
      tester,
      w,
      request: customerRequestOf(status: InstantStatus.searching),
    );
    expect(find.byType(TrackingView), findsNothing);
    expect(find.text('Nhắn tin'), findsNothing);

    // No photographer on the request: no contact either.
    w.repo.emitRequest(
      'req1',
      _tracking(InstantStatus.assigned, photographer: null),
    );
    await settleInstant(tester);
    // searching → assigned shows the match moment first (S13.04).
    await tester.tap(find.text('Tiếp tục'));
    await settleInstant(tester);
    expect(find.byType(TrackingView), findsOneWidget);
    expect(find.text('Nhắn tin'), findsNothing);
    expect(find.text('Liên hệ'), findsNothing);
    expect(find.byType(ContactDial), findsNothing);
    await _end(tester, w);
  });

  testWidgets('recenter centres the map on the meet point', (tester) async {
    final w = InstantCustomerWorld();
    w.repo.emitTrack('req1', _point(_km12, instantNow));
    await pumpInstantFlow(tester, w, request: _tracking(InstantStatus.enRoute));
    Offset meet() => tester.getCenter(find.byKey(const Key('map-pin-dot-0')));
    final centre = tester.getCenter(find.byKey(const Key('map-preview')));
    // Fitted to both pins, the meet point is off centre.
    expect((meet() - centre).distance, greaterThan(20));

    await tester.tap(find.byTooltip('Về vị trí của tôi'));
    await settleInstant(tester);
    expect((meet() - centre).distance, lessThan(1));
    // Both pins are still on the map.
    expect(_map(tester).pins, hasLength(2));
    await _end(tester, w);
  });

  testWidgets('fits 320dp at 1.3× text, light and dark', (tester) async {
    for (final brightness in Brightness.values) {
      for (final status in [InstantStatus.enRoute, InstantStatus.arrived]) {
        final w = InstantCustomerWorld();
        w.repo.emitTrack('req1', _point(_km12, instantNow));
        await pumpInstantFlow(
          tester,
          w,
          request: _tracking(
            status,
            lateIn: const Duration(seconds: -1),
            freeCancelLeft: const Duration(seconds: -1),
          ),
          viewSize: const Size(320, 640),
          textScale: 1.3,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull, reason: '$brightness $status');
        await _end(tester, w);
      }
    }
  });
}
