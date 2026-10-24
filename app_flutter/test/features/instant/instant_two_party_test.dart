// Chụp ngay end to end (plan #140 Task 7): the customer's app (S13) and a
// photographer's app (S14) side by side on one in-memory backend
// ([InstantSimulator]), one clock for both. Each app has its own
// ProviderScope; an IndexedStack shows one at a time (finders and taps only
// see the visible one) while both keep listening.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/instant_work/instant_job_screen.dart';
import 'package:photobooking/features/instant_work/offer_screen.dart';

import '../../support/instant_customer_world.dart';
import '../../support/instant_simulator.dart';
import '../../support/instant_work_world.dart';
import '../../support/screen_host.dart';

enum _Side { customer, photographer }

class _Duo {
  _Duo({this.photographerId = 'p2', InstantConfig? config}) {
    sim = InstantSimulator(now: () => clock.now, config: config);
    customer = InstantCustomerWorld(
      clock: clock,
      repository: sim.customer,
      paymentsRepository: sim.payments,
    );
    photographer = InstantWorld(
      clock: clock,
      repository: sim.photographer(photographerId),
      extra: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(AuthUser(uid: photographerId)),
        ),
        currentProfileProvider.overrideWith(
          (ref) => Stream.value(
            UserProfile(
              uid: photographerId,
              role: UserRole.photographer,
              displayName: 'Thợ',
            ),
          ),
        ),
        currentContactProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
  }

  final String photographerId;
  final clock = InstantClock();
  late final InstantSimulator sim;
  late final InstantCustomerWorld customer;
  late final InstantWorld photographer;
  final side = ValueNotifier(_Side.customer);
  late final GoRouter customerRouter;
  late final GoRouter photographerRouter;

  String get requestId => 'req1';

  /// Moves the shared clock and both apps' timers.
  Future<void> wait(WidgetTester tester, Duration d) =>
      customer.base.wait(tester, d);
}

Widget _stub(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('stub ${s.uri}'));

/// The photographer's app: S14.02 and S14.03 over Công việc.
GoRouter _photographerRouter() => GoRouter(
  initialLocation: '/bookings',
  routes: [
    GoRoute(path: '/bookings', builder: _stub),
    GoRoute(path: '/work/instant', builder: _stub),
    GoRoute(
      path: '/work/instant/offer/:offerId',
      builder: (_, s) => OfferScreen(offerId: s.pathParameters['offerId']!),
    ),
    GoRoute(
      path: '/work/instant/:id',
      builder: (_, s) => InstantJobScreen(requestId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/chat/:chatId', builder: _stub),
  ],
);

/// Both apps on a 390×844 phone, the customer's in front at `/home`.
Future<_Duo> _pump(WidgetTester tester, _Duo d) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  d.customerRouter = instantCustomerRouter(d.customer);
  d.photographerRouter = _photographerRouter();
  final apps = [
    screenRouterApp(
      router: d.customerRouter,
      overrides: d.customer.overrides,
      disableAnimations: true,
    ),
    screenRouterApp(
      router: d.photographerRouter,
      overrides: d.photographer.overrides,
      disableAnimations: true,
    ),
  ];
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder(
        valueListenable: d.side,
        builder: (_, side, _) => IndexedStack(
          index: side.index,
          sizing: StackFit.expand,
          children: apps,
        ),
      ),
    ),
  );
  await settleInstant(tester);
  return d;
}

Future<void> _end(WidgetTester tester, _Duo d) async {
  await tester.pumpWidget(const SizedBox.shrink());
  d.sim.dispose();
}

Future<void> _show(WidgetTester tester, _Duo d, _Side side) async {
  d.side.value = side;
  await tester.pump();
}

/// The visible app's top screen code (`S13.02`, `S13.02/round`, …).
String _code(WidgetTester tester) {
  final c = tester.widget<ScreenCode>(find.byType(ScreenCode).last);
  return c.label == null ? c.code : '${c.code}/${c.label}';
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settleInstant(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(Key(key)));

Finder _text(String s) => find.text(s, findRichText: true);

/// The customer creates `req1` (Chân dung · 1 giờ at Tao Đàn) through the
/// backend and opens `/instant/req1`.
Future<void> _openRequest(WidgetTester tester, _Duo d) async {
  await d.sim.customer.createRequest(
    packageCode: 'p60',
    genre: InstantGenre.portrait,
    lat: taoDan.lat,
    lng: taoDan.lng,
    meetPointName: 'Cổng Trương Định',
  );
  d.customerRouter.push('/instant/${d.requestId}');
  await settleInstant(tester);
}

/// S13.02: ♥ (true) or ✕ (false) per card, then the summary's primary (the
/// last card opens it when someone was liked): in the first round
/// "Thanh toán 690.000₫ và gửi lời mời" opens S04.04, where the customer pays
/// with the fake bank unless [pay] is false; later rounds "Gửi lời mời".
Future<void> _choose(
  WidgetTester tester,
  List<bool> likes, {
  bool pay = true,
}) async {
  for (final like in likes) {
    await tester.tap(find.byKey(Key(like ? 'swipe-like' : 'swipe-skip')));
    await tester.pump();
  }
  await settleInstant(tester);
  if (_code(tester) != 'S13.02/summary') {
    await _tapKey(tester, 'choose-done');
  }
  expect(_code(tester), 'S13.02/summary');
  await _tapKey(tester, 'choose-invite');
  if (_code(tester) == 'S04.04/instant' && pay) await _payExact(tester);
}

/// S04.04: "Giả lập chuyển khoản" → "Chuyển đúng"; back on the request once
/// the server has the money.
Future<void> _payExact(WidgetTester tester) async {
  await _tap(tester, find.text('Giả lập chuyển khoản'));
  await _tap(tester, find.text('Chuyển đúng'));
  await tester.pump(const Duration(milliseconds: 300));
  await settleInstant(tester);
}

/// The photographer opens their offer (S14.02), takes it and goes on to
/// S14.03 past their own match moment.
Future<void> _accept(WidgetTester tester, _Duo d) async {
  await _show(tester, d, _Side.photographer);
  final offer = d.sim.offerOf(d.requestId, d.photographerId);
  d.photographerRouter.push('/work/instant/offer/${offer.id}');
  await settleInstant(tester);
  expect(_code(tester), 'S14.02');
  await _tapKey(tester, 'offer-accept');
  expect(_code(tester), 'S13.04/provider');
  await _tap(tester, find.text('Tiếp tục'));
  expect(_code(tester), 'S14.03');
}

/// Customer: "Tiếp tục" on S13.04 into S13.05.
Future<void> _pastMatch(WidgetTester tester, _Duo d) async {
  await _show(tester, d, _Side.customer);
  expect(_code(tester), 'S13.04');
  await _tap(tester, find.text('Tiếp tục'));
  expect(_code(tester), startsWith('S13.05'));
}

/// S13.08 from [openKey]: checks the active row and the summary line, then
/// confirms with [confirm].
Future<void> _cancel(
  WidgetTester tester, {
  required String openKey,
  required String row,
  required String outcome,
  required String line,
  required String confirm,
}) async {
  await _tapKey(tester, openKey);
  expect(_code(tester), 'S13.08');
  expect(find.text(row), findsOneWidget);
  expect(find.text(outcome), findsWidgets);
  expect(_text(line), findsOneWidget);
  expect(find.text(confirm), findsOneWidget);
  await _tapKey(tester, 'customer-cancel-confirm');
  expect(_code(tester), 'S13.08/done');
}

const _rowFree =
    'Đang chọn, đang chờ trả lời, chưa tìm được, hoặc 2 phút đầu sau khi có '
    'người nhận (bây giờ)';
const _roundEnded = 'Chưa ai nhận. Chọn thêm người nhé.';

void main() {
  testWidgets(
    'customer picks three, the second photographer accepts: customer sees '
    'the match then S13.05, photographer sees S14.03',
    (tester) async {
      final d = await _pump(tester, _Duo());
      d.customerRouter.push('/instant');
      await settleInstant(tester);
      expect(_code(tester), 'S13.01');
      await tester.enterText(
        find.byKey(const Key('instant-meet-point')),
        'Cổng Trương Định',
      );
      await tester.pump();
      await _tapKey(tester, 'instant-see-matches');
      expect(_code(tester), 'S13.02');
      expect(find.text('Minh Trí'), findsOneWidget);

      await _choose(tester, [true, true, true, false, false]);
      expect(_code(tester), 'S13.03');
      expect(_text('Đã gửi lời mời cho 3 người'), findsOneWidget);
      expect(
        d.sim.request(d.requestId)!.offers.map((o) => o.photographerId),
        ['p1', 'p2', 'p3'],
      );

      await _accept(tester, d);
      expect(find.text('Đang đến'), findsWidgets);

      await _pastMatch(tester, d);
      final r = d.sim.request(d.requestId)!;
      expect(r.status, InstantStatus.enRoute);
      expect(r.photographer?.name, 'Hồng Nhung');
      expect(find.textContaining('Hồng Nhung'), findsWidgets);
      // First accept wins: the other two invites are gone.
      for (final p in ['p1', 'p3']) {
        expect(
          d.sim.offerOf(d.requestId, p).outcome,
          OfferOutcome.withdrawn,
        );
      }
      await _end(tester, d);
    },
  );

  testWidgets(
    'the first invite pays once on S04.04 and only then are the offers sent',
    (tester) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      await _choose(tester, [true, true, false, false, false], pay: false);
      expect(_code(tester), 'S04.04/instant');
      var r = d.sim.request(d.requestId)!;
      expect(r.status, InstantStatus.pendingPayment);
      expect(r.pendingInviteIds, ['p1', 'p2']);
      expect(r.paid, isFalse);
      // No offer before the money is in.
      expect(r.offers, isEmpty);
      expect(d.sim.offersTo('p1'), isEmpty);

      // Back and "Thanh toán tiếp": the same payment, not a second one.
      await _tap(tester, find.byTooltip('Quay lại'));
      expect(_code(tester), 'S13.02/summary');
      await _tapKey(tester, 'choose-invite');
      expect(_code(tester), 'S04.04/instant');
      expect(d.sim.paymentsOf(d.requestId), hasLength(1));

      await _payExact(tester);
      expect(_code(tester), 'S13.03');
      expect(_text('Đã gửi lời mời cho 2 người'), findsOneWidget);
      r = d.sim.request(d.requestId)!;
      expect(r.paid, isTrue);
      expect(r.status, InstantStatus.searching);
      expect(r.offers.map((o) => o.photographerId), ['p1', 'p2']);
      expect(d.sim.offersTo('p1'), hasLength(1));
      expect(d.sim.paymentsOf(d.requestId), hasLength(1));
      await _end(tester, d);
    },
  );

  testWidgets(
    'nobody accepts in round 1 (all expire): customer sees "Chưa ai nhận …", '
    'picks again without paying, round 2 matches',
    (tester) async {
      final d = await _pump(tester, _Duo(photographerId: 'p6'));
      await _openRequest(tester, d);
      await _choose(tester, [true, true, true, false, false]);
      expect(_code(tester), 'S13.03');

      // The customer's screen ticks 1 s after the offers expire.
      await d.wait(tester, const Duration(seconds: 62));
      expect(_code(tester), 'S13.02/round');
      expect(find.text(_roundEnded), findsOneWidget);

      await _tapKey(tester, 'choose-more');
      expect(_code(tester), 'S13.02');
      // The three who let it expire and the two skipped are not suggested.
      expect(find.text('Anh Thư'), findsOneWidget);
      expect(d.sim.request(d.requestId)!.round, 2);
      expect(
        d.sim.request(d.requestId)!.candidates.map((c) => c.photographerId),
        ['p6', 'p7', 'p8'],
      );

      await _choose(tester, [true, false, false]);
      expect(_code(tester), 'S13.03');
      final r = d.sim.request(d.requestId)!;
      // Round 2 used the held money: one payment for the request.
      expect(r.paid, isTrue);
      expect(d.sim.paymentsOf(d.requestId), hasLength(1));
      expect(r.invitedTotal, 4);
      expect(r.roundsWithInvites, 2);

      await _accept(tester, d);
      await _pastMatch(tester, d);
      expect(d.sim.request(d.requestId)!.photographerId, 'p6');
      await _end(tester, d);
    },
  );

  testWidgets(
    'photographer cancels after accepting: customer is back on S13.02 with '
    'the round banner and money held',
    (tester) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      await _choose(tester, [false, true, false, false, false]);
      await _accept(tester, d);

      await _tapKey(tester, 'job-cancel');
      expect(_code(tester), 'S13.08/provider');
      await _tapKey(tester, 'provider-cancel-confirm');
      // The job is no longer theirs: back to Live Shutter.
      expect(d.photographerRouter.state.uri.toString(), '/work/instant');

      await _show(tester, d, _Side.customer);
      expect(_code(tester), 'S13.02/round');
      expect(find.text(_roundEnded), findsOneWidget);
      final r = d.sim.request(d.requestId)!;
      expect(r.status, InstantStatus.choosing);
      expect(r.photographerId, isNull);
      // The money stays held for the next round: cancelling now refunds all.
      expect(r.paid, isTrue);
      await _tapKey(tester, 'choose-cancel');
      expect(_text('Bạn sẽ được hoàn 690.000₫.'), findsOneWidget);
      await _tapKey(tester, 'customer-cancel-keep');
      expect(d.sim.request(d.requestId)!.status, InstantStatus.choosing);
      await _end(tester, d);
    },
  );

  group('customer cancels at each milestone', () {
    testWidgets('pending_payment, unpaid: no money', (tester) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      // S04.04 opens; the customer leaves without paying.
      await _choose(tester, [true, false, false, false, false], pay: false);
      expect(_code(tester), 'S04.04/instant');
      await _tap(tester, find.byTooltip('Quay lại'));
      expect(_code(tester), 'S13.02/summary');
      expect(find.text('Thanh toán tiếp'), findsOneWidget);

      await _tapKey(tester, 'choose-cancel');
      expect(_code(tester), 'S13.08');
      expect(
        find.text('Bạn chưa thanh toán nên không có khoản tiền nào.'),
        findsOneWidget,
      );
      await _tapKey(tester, 'customer-cancel-confirm');
      expect(_code(tester), 'S13.08/done');
      expect(find.text('Đã huỷ yêu cầu'), findsOneWidget);
      expect(find.text('Không có khoản tiền nào.'), findsOneWidget);
      expect(
        d.sim.request(d.requestId)!.cancelRule,
        InstantCancelRule.unpaid,
      );
      // Nobody was offered anything.
      expect(d.sim.request(d.requestId)!.offers, isEmpty);
      await _end(tester, d);
    });

    testWidgets('searching: 100%', (tester) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      await _choose(tester, [true, true, false, false, false]);
      expect(_code(tester), 'S13.03');

      await _cancel(
        tester,
        openKey: 'waiting-cancel',
        row: _rowFree,
        outcome: 'Hoàn 100%',
        line: 'Bạn sẽ được hoàn 690.000₫.',
        confirm: 'Huỷ và hoàn 690.000₫',
      );
      expect(
        _text(
          'Hoàn 690.000₫ về tài khoản đã chuyển. Tiền thường về trong vài '
          'phút.',
        ),
        findsOneWidget,
      );
      // The pending invites were withdrawn with it.
      expect(d.sim.offerOf(d.requestId, 'p2').outcome, OfferOutcome.withdrawn);
      await _end(tester, d);
    });

    testWidgets('en route after 2 minutes: 80/20 shown to both', (
      tester,
    ) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      await _choose(tester, [false, true, false, false, false]);
      await _accept(tester, d);
      await _pastMatch(tester, d);
      expect(d.sim.request(d.requestId)!.status, InstantStatus.enRoute);

      await d.wait(tester, const Duration(minutes: 2, seconds: 10));
      await _cancel(
        tester,
        openKey: 'tracking-cancel',
        row: 'Nhiếp ảnh gia đang đến (bây giờ)',
        outcome: 'Hoàn 80%',
        line:
            'Bạn sẽ được hoàn 552.000₫; 138.000₫ là phí đi lại trả cho Hồng '
            'Nhung.',
        confirm: 'Huỷ và hoàn 552.000₫',
      );
      expect(
        _text(
          'Hoàn 552.000₫ về tài khoản đã chuyển. Tiền thường về trong vài '
          'phút.',
        ),
        findsOneWidget,
      );

      await _show(tester, d, _Side.photographer);
      expect(find.text('Khách đã huỷ yêu cầu'), findsWidgets);
      expect(find.text('Bạn nhận 138.000₫ phí đi lại.'), findsOneWidget);
      await _end(tester, d);
    });

    for (final (percent, refund, fee, refundPct) in [
      (null, '345.000₫', '345.000₫', 50),
      (30, '483.000₫', '207.000₫', 70),
    ]) {
      testWidgets(
        'arrived: the configured split (${percent ?? 'seed 50'}% to the '
        'photographer)',
        (tester) async {
          final seed = InstantSimulator(now: () => instantNow).config;
          final d = await _pump(
            tester,
            _Duo(
              config: percent == null
                  ? null
                  : seed.copyWith(
                      instantArrivedCancelPhotographerPercent: percent,
                    ),
            ),
          );
          await _openRequest(tester, d);
              await _choose(tester, [false, true, false, false, false]);
          await _accept(tester, d);
          await _tapKey(tester, 'job-arrive');
          expect(d.sim.request(d.requestId)!.status, InstantStatus.arrived);
          await _pastMatch(tester, d);

          await _cancel(
            tester,
            openKey: 'tracking-cancel',
            row: 'Đã đến, bạn không có mặt sau 15 phút (bây giờ)',
            outcome: 'Hoàn $refundPct%',
            line:
                'Bạn sẽ được hoàn $refund; $fee là phí đi lại trả cho Hồng '
                'Nhung.',
            confirm: 'Huỷ và hoàn $refund',
          );
          await _show(tester, d, _Side.photographer);
          expect(find.text('Bạn nhận $fee phí đi lại.'), findsOneWidget);
          await _end(tester, d);
        },
      );
    }
  });

  testWidgets(
    'ten minutes without a match: S13.07 with the held amount; '
    '"Chọn thêm người" opens a new round',
    (tester) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      await _choose(tester, [true]);
      await d.wait(tester, const Duration(seconds: 62));
      expect(_code(tester), 'S13.02/round');

      // The search window (10 minutes from the invite) runs out.
      await d.wait(tester, const Duration(minutes: 9));
      expect(_code(tester), 'S13.07');
      expect(
        _text(
          '690.000₫ vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì '
          'hoàn đủ về tài khoản đã chuyển.',
        ),
        findsOneWidget,
      );
      expect(d.sim.request(d.requestId)!.paid, isTrue);

      await _tapKey(tester, 'no-match-more');
      expect(_code(tester), 'S13.02');
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('Hồng Nhung'), findsOneWidget);
      final r = d.sim.request(d.requestId)!;
      expect(r.status, InstantStatus.choosing);
      expect(r.round, 2);
      await _end(tester, d);
    },
  );

  testWidgets(
    'completion: photographer finishes, customer confirms, both see the done '
    'states',
    (tester) async {
      final d = await _pump(tester, _Duo());
      await _openRequest(tester, d);
      await _choose(tester, [false, true, false, false, false]);
      await _accept(tester, d);
      await _tapKey(tester, 'job-arrive');
      await _tapKey(tester, 'job-start');
      expect(d.sim.request(d.requestId)!.status, InstantStatus.inProgress);

      await _show(tester, d, _Side.customer);
      expect(_code(tester), 'S13.06');
      expect(find.text('Đang chụp'), findsWidgets);

      await d.wait(tester, const Duration(minutes: 30));
      await _show(tester, d, _Side.photographer);
      await _tapKey(tester, 'job-finish');
      expect(find.text('Chờ khách xác nhận'), findsWidgets);

      await _show(tester, d, _Side.customer);
      expect(find.text('Chờ bạn xác nhận'), findsWidgets);
      await _tapKey(tester, 'shooting-confirm');
      expect(_code(tester), 'S13.06/done');
      expect(find.text('Buổi chụp đã hoàn thành'), findsOneWidget);

      await _show(tester, d, _Side.photographer);
      expect(find.text('Đã hoàn thành'), findsWidgets);
      expect(d.sim.request(d.requestId)!.status, InstantStatus.completed);
      await _end(tester, d);
    },
  );
}
