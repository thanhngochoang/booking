// S13.06 (`#S13.06`, `-confirm`, `-done`): the shoot clock, the customer's
// "Xác nhận hoàn thành", the 2-hour auto-complete countdown once the
// photographer finished, and the done view.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/done_view.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';
import 'package:photobooking/features/instant/shooting_view.dart';

import '../../support/instant_customer_world.dart';

/// 15:21, 15:38 and 15:42 in Vietnam (UTC+7).
final _assignedAt = DateTime.utc(2026, 10, 8, 8, 21);
final _arrivedAt = DateTime.utc(2026, 10, 8, 8, 38);
final _startedAt = DateTime.utc(2026, 10, 8, 8, 42);

/// 38:12 before the shoot ends (mock `#S13.06`).
final _shootNow = _startedAt.add(const Duration(minutes: 21, seconds: 48));

const _minhTri = InstantParty(
  id: 'p1',
  name: 'Minh Trí',
  verified: true,
  tomatoPct: 97,
  reviewCount: 58,
  completedCount: 112,
);

InstantRequest _shoot(InstantStatus status, {DateTime? finishedAt}) =>
    customerRequestOf(status: status, committed: true).copyWith(
      photographerId: 'p1',
      photographer: _minhTri,
      chatId: 'chat_cus1_p1',
      etaMinutes: 9,
      assignedAt: _assignedAt,
      arrivedAt: _arrivedAt,
      startedAt: _startedAt,
      shootEndsAt: _startedAt.add(const Duration(minutes: 60)),
      finishedAt: finishedAt,
      completedAt: status == InstantStatus.completed ? finishedAt : null,
    );

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
  testWidgets('ring counts down to shootEndsAt and ticks at 0', (tester) async {
    final w = InstantCustomerWorld(now: _shootNow);
    await pumpInstantFlow(tester, w, request: _shoot(InstantStatus.inProgress));
    expect(find.byType(ShootingView), findsOneWidget);
    expect(_code(tester).code, ScreenCodes.instantInProgress);
    expect(_code(tester).label, isNull);
    final ring = tester.widget<CountdownRing>(find.byType(CountdownRing));
    expect(ring.deadline, _startedAt.add(const Duration(minutes: 60)));
    expect(ring.total, const Duration(minutes: 60));
    expect(find.text('38'), findsOneWidget);
    expect(find.text('còn lại'), findsOneWidget);
    expect(find.text('ĐANG CHỤP'), findsOneWidget);
    expect(find.text('Minh Trí · Chân dung 1 giờ'), findsOneWidget);
    expect(find.text('Bắt đầu 15:42 · Cổng Trương Định'), findsOneWidget);
    expect(
      find.text(
        'Khi Minh Trí bấm Hoàn thành, bạn xác nhận ở đây. Không xác nhận thì '
        'tự hoàn thành sau 2 giờ; có vấn đề thì báo trong 24 giờ.',
      ),
      findsOneWidget,
    );

    await w.base.wait(tester, const Duration(minutes: 38, seconds: 10));
    expect(w.repo.callsOf('tick'), isEmpty);
    await w.base.wait(tester, const Duration(seconds: 10));
    // One tick at shootEndsAt (the screen's scheduler; the ring adds none).
    expect(w.repo.callsOf('tick'), hasLength(1));
    await w.base.wait(tester, const Duration(minutes: 1));
    expect(w.repo.callsOf('tick'), hasLength(1));
    await _end(tester, w);
  });

  testWidgets('"Xác nhận hoàn thành" calls confirmComplete in in_progress and '
      'in finished', (tester) async {
    final w = InstantCustomerWorld(now: _shootNow);
    await pumpInstantFlow(tester, w, request: _shoot(InstantStatus.inProgress));
    // The one gradient button of the view.
    expect(find.byType(CtaSurface), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Xác nhận hoàn thành'),
        matching: find.byType(CtaSurface),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Xác nhận hoàn thành'));
    await settleInstant(tester);
    expect(w.repo.callsOf('confirmComplete').map((c) => c.args['requestId']), [
      'req1',
    ]);

    w.repo.emitRequest(
      'req1',
      _shoot(InstantStatus.finished, finishedAt: _shootNow),
    );
    await settleInstant(tester);
    expect(find.byType(CtaSurface), findsOneWidget);
    await tester.tap(find.text('Xác nhận hoàn thành'));
    await settleInstant(tester);
    expect(w.repo.callsOf('confirmComplete'), hasLength(2));
    await _end(tester, w);
  });

  testWidgets('finished shows "Chờ bạn xác nhận" and the 2-hour countdown', (
    tester,
  ) async {
    final w = InstantCustomerWorld(now: _shootNow);
    await pumpInstantFlow(
      tester,
      w,
      request: _shoot(
        InstantStatus.finished,
        finishedAt: _shootNow.subtract(const Duration(minutes: 7, seconds: 50)),
      ),
    );
    expect(_code(tester).label, 'confirm');
    expect(find.text('Chờ bạn xác nhận'), findsOneWidget);
    expect(find.byType(CountdownRing), findsNothing);
    expect(find.text('ĐANG CHỤP'), findsNothing);
    expect(
      find.text(
        'Minh Trí đã hoàn thành buổi chụp. Tự hoàn thành sau 1:52:10 nếu bạn '
        'không xác nhận.',
      ),
      findsOneWidget,
    );
    await w.base.wait(tester, const Duration(seconds: 1));
    expect(find.textContaining('1:52:09'), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('completed shows "Buổi chụp đã hoàn thành" and "{name} sẽ giao '
      '30 ảnh trong 48 giờ."', (tester) async {
    final w = InstantCustomerWorld(now: _shootNow);
    final router = await pumpInstantFlow(
      tester,
      w,
      request: _shoot(InstantStatus.completed, finishedAt: _shootNow),
    );
    expect(find.byType(DoneView), findsOneWidget);
    expect(_code(tester).label, 'done');
    expect(find.text('Buổi chụp đã hoàn thành'), findsOneWidget);
    expect(find.text('Minh Trí sẽ giao 30 ảnh trong 48 giờ.'), findsOneWidget);
    // No review entry, no dispute link (Decision 12); no gradient button.
    expect(find.byType(CtaSurface), findsNothing);
    await tester.tap(find.text('Về trang chủ'));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/home');
    await _end(tester, w);
  });

  testWidgets('conflict on confirm refreshes without an error', (tester) async {
    final w = InstantCustomerWorld(now: _shootNow);
    await pumpInstantFlow(
      tester,
      w,
      request: _shoot(InstantStatus.finished, finishedAt: _shootNow),
    );
    w.repo.failNext('confirmComplete', 'conflict');
    final watches = w.repo.requestWatches('req1');
    await tester.tap(find.text('Xác nhận hoàn thành'));
    await settleInstant(tester);
    expect(find.byType(SnackBar), findsNothing);
    // The request is read again (a new listen), not left as it was.
    expect(w.repo.requestWatches('req1'), watches + 1);
    // The clock completed it: the refreshed listener shows the done view.
    w.repo.emitRequest(
      'req1',
      _shoot(InstantStatus.completed, finishedAt: _shootNow),
    );
    await settleInstant(tester);
    expect(find.byType(DoneView), findsOneWidget);
    await _end(tester, w);
  });

  testWidgets('another failure on confirm says so and re-enables the button', (
    tester,
  ) async {
    final w = InstantCustomerWorld(now: _shootNow);
    await pumpInstantFlow(tester, w, request: _shoot(InstantStatus.inProgress));
    w.repo.failNext('confirmComplete', 'network');
    await tester.tap(find.text('Xác nhận hoàn thành'));
    await settleInstant(tester);
    expect(find.text('Mất kết nối. Thử lại nhé.'), findsOneWidget);
    await tester.tap(find.text('Xác nhận hoàn thành'));
    await settleInstant(tester);
    expect(w.repo.callsOf('confirmComplete'), hasLength(2));
    await _end(tester, w);
  });

  testWidgets('timeline shows Đã nhận · 15:21 and Đã đến · 15:38 in Vietnam '
      'time', (tester) async {
    final w = InstantCustomerWorld(now: _shootNow);
    await pumpInstantFlow(tester, w, request: _shoot(InstantStatus.inProgress));
    expect(find.text('Đã nhận · 15:21'), findsOneWidget);
    expect(find.text('Đã đến · 15:38'), findsOneWidget);
    expect(find.text('Hoàn thành và giao 30 ảnh trong 48 giờ'), findsOneWidget);
    final steps = tester.widget<StatusTimeline>(find.byType(StatusTimeline));
    expect(steps.steps.map((s) => s.state), [
      TimelineStepState.done,
      TimelineStepState.done,
      TimelineStepState.upcoming,
    ]);
    await _end(tester, w);
  });

  testWidgets('"Nhắn tin" in the bar opens /chat/{chatId}', (tester) async {
    final w = InstantCustomerWorld(now: _shootNow);
    final router = await pumpInstantFlow(
      tester,
      w,
      request: _shoot(InstantStatus.inProgress),
    );
    await tester.tap(find.byTooltip('Nhắn tin'));
    await settleInstant(tester);
    expect(router.state.uri.toString(), '/chat/chat_cus1_p1');
    await _end(tester, w);
  });

  testWidgets('fits 320dp at 1.3× text, light and dark', (tester) async {
    for (final brightness in Brightness.values) {
      for (final status in [
        InstantStatus.inProgress,
        InstantStatus.finished,
        InstantStatus.completed,
      ]) {
        final w = InstantCustomerWorld(now: _shootNow);
        await pumpInstantFlow(
          tester,
          w,
          request: _shoot(status, finishedAt: _shootNow),
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
