import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

const _chosen = 'Khách đã chọn bạn trong 3 người. Ai nhận trước sẽ được việc.';

/// Three offers from three customers; the routed one is not the soonest.
List<InstantOfferFixture> _three() => [
  (id: 'o1', area: 'Phường Bến Thành, Quận 1', expiresIn: 47),
  (id: 'o2', area: 'Phường 6, Quận 3', expiresIn: 40),
  (id: 'o3', area: 'Phường Thảo Điền, TP Thủ Đức', expiresIn: 55),
];

typedef InstantOfferFixture = ({String id, String area, int expiresIn});

FakeInstantRepository _repo(List<InstantOfferFixture> fs) =>
    FakeInstantRepository(
      presence: presenceOf(online: true),
      offers: [
        for (final f in fs)
          offerOf(
            f.id,
            requestId: 'req_${f.id}',
            areaLabel: f.area,
            expiresIn: Duration(seconds: f.expiresIn),
          ),
      ],
    );

Future<(InstantWorld, GoRouter)> _open(
  WidgetTester tester,
  FakeInstantRepository repo, {
  String offerId = 'o1',
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  final world = InstantWorld(repo: repo);
  final router = await pumpOfferScreen(
    tester,
    world,
    offerId: offerId,
    textScale: textScale,
    viewSize: viewSize,
  );
  return (world, router);
}

Future<void> _end(WidgetTester tester, FakeInstantRepository repo) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await repo.dispose();
}

Finder get _accept => find.text('Nhận việc');
Finder get _decline => find.text('Từ chối');

void main() {
  testWidgets(
    'top card is the routed offer; count line reads "3 lời mời đang chờ"',
    (tester) async {
      final repo = _repo(_three());
      await _open(tester, repo);

      expect(find.text('Lời mời chụp ngay'), findsOneWidget);
      expect(find.text('3 lời mời đang chờ'), findsOneWidget);
      expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
      // The others are edges of the stack only.
      expect(find.text('Phường 6, Quận 3'), findsNothing);
      expect(find.byKey(const Key('offer-edge-1')), findsOneWidget);
      expect(find.byKey(const Key('offer-edge-2')), findsOneWidget);
      await _end(tester, repo);
    },
  );

  testWidgets(
    'countdown shows seconds from expiresAt with the injected clock',
    (tester) async {
      final repo = _repo([
        (id: 'o1', area: 'Phường Bến Thành, Quận 1', expiresIn: 47),
      ]);
      final (world, _) = await _open(tester, repo);

      // The screen opened 0,8 s after instantNow (bounded settle); the
      // countdown reads the injected clock, not a local 60 s from receipt.
      expect(find.text('47'), findsOneWidget);
      expect(find.text('giây'), findsOneWidget);
      await world.wait(tester, const Duration(seconds: 10));
      expect(find.text('37'), findsOneWidget);
      await _end(tester, repo);
    },
  );

  testWidgets(
    'card shows area, "2,1 km · khoảng 8 phút · địa chỉ hiện khi bạn nhận" and never an exact address',
    (tester) async {
      final repo = _repo([
        (id: 'o1', area: 'Phường Bến Thành, Quận 1', expiresIn: 47),
      ]);
      await _open(tester, repo);

      expect(find.text('552.000₫'), findsOneWidget);
      expect(find.text('Bạn nhận · Chân dung 1 giờ · 30 ảnh'), findsOneWidget);
      expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
      expect(
        find.text('2,1 km · khoảng 8 phút · địa chỉ hiện khi bạn nhận'),
        findsOneWidget,
      );
      expect(find.text(_chosen, findRichText: true), findsOneWidget);
      expect(
        find.text('"Chụp chân dung ở hồ, mình mặc áo dài trắng."'),
        findsOneWidget,
      );
      // An offer never reads the request (meet point, customer): only the
      // offer's own fields are on screen.
      expect(find.textContaining('Tao Đàn'), findsNothing);
      expect(find.textContaining('Lan Anh'), findsNothing);
      expect(find.text('1 lời mời đang chờ'), findsOneWidget);
      // One offer: no edges.
      expect(find.byKey(const Key('offer-edge-1')), findsNothing);
      await _end(tester, repo);
    },
  );

  testWidgets('accept → overlay → /work/instant/{requestId}', (tester) async {
    final repo = _repo(_three());
    repo.emitRequest('req_o1', assignedRequestOf('req_o1'));
    final (_, router) = await _open(tester, repo);

    await tester.tap(_accept);
    await settleInstant(tester);

    expect(repo.callsOf('answerOffer').single.args, {
      'offerId': 'o1',
      'accept': true,
    });
    expect(
      find.text('Đã match với Lan Anh', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(
        'Lan Anh đang chờ ở Công viên Tao Đàn. Tiếp tục để xem đường đi.',
      ),
      findsOneWidget,
    );
    // The offers that the server withdraws next do not close the screen.
    repo.emitOffers(const []);
    await settleInstant(tester);
    expect(router.state.uri.path, '/work/instant/offer/o1');

    await tester.tap(find.text('Tiếp tục'));
    await settleInstant(tester);
    expect(find.text('stub /work/instant/req_o1'), findsOneWidget);
    // S14.03 replaces S14.02: back goes to Live Shutter, not to the offer.
    router.pop();
    await settleInstant(tester);
    expect(find.text('stub /work/instant'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets('accept goes on by itself after about 3 s', (tester) async {
    final repo = _repo(_three());
    repo.emitRequest('req_o1', assignedRequestOf('req_o1'));
    await _open(tester, repo);

    await tester.tap(_accept);
    await settleInstant(tester);
    await tester.pump(const Duration(seconds: 3));
    await settleInstant(tester);

    expect(find.text('stub /work/instant/req_o1'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets(
    'already_assigned shows "Khách đã chọn được người khác" and drops the card',
    (tester) async {
      final repo = _repo(_three())..failNext('answerOffer', 'already_assigned');
      await _open(tester, repo);

      await tester.tap(_accept);
      await settleInstant(tester);

      expect(find.text('Khách đã chọn được người khác'), findsOneWidget);
      expect(find.text('Phường Bến Thành, Quận 1'), findsNothing);
      // The next card is the soonest of the others.
      expect(find.text('Phường 6, Quận 3'), findsOneWidget);
      expect(find.text('2 lời mời đang chờ'), findsOneWidget);
      await _end(tester, repo);
    },
  );

  testWidgets('offer_expired shows "Lời mời đã hết hạn" and drops the card', (
    tester,
  ) async {
    final repo = _repo(_three())..failNext('answerOffer', 'offer_expired');
    await _open(tester, repo);

    await tester.tap(_accept);
    await settleInstant(tester);

    expect(find.text('Lời mời đã hết hạn'), findsOneWidget);
    expect(find.text('Phường Bến Thành, Quận 1'), findsNothing);
    expect(find.text('2 lời mời đang chờ'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets('not_accepting_orders shows "Bạn chưa nhận đơn được lúc này"', (
    tester,
  ) async {
    final repo = _repo(_three())
      ..failNext('answerOffer', 'not_accepting_orders');
    await _open(tester, repo);

    await tester.tap(_accept);
    await settleInstant(tester);

    expect(find.text('Bạn chưa nhận đơn được lúc này'), findsOneWidget);
    // The card stays; it can still be declined.
    expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
    expect(find.text('3 lời mời đang chờ'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets('a network failure keeps the card and says so', (tester) async {
    final repo = _repo(_three())..failNext('answerOffer', 'network');
    await _open(tester, repo);

    await tester.tap(_accept);
    await settleInstant(tester);

    expect(find.text('Mất kết nối. Thử lại nhé.'), findsOneWidget);
    expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets(
    'decline calls answerOffer(accept: false) and shows the next card',
    (tester) async {
      final repo = _repo(_three());
      await _open(tester, repo);

      await tester.tap(_decline);
      await settleInstant(tester);

      expect(repo.callsOf('answerOffer').single.args, {
        'offerId': 'o1',
        'accept': false,
      });
      expect(find.text('Phường Bến Thành, Quận 1'), findsNothing);
      expect(find.text('Phường 6, Quận 3'), findsOneWidget);
      expect(find.text('2 lời mời đang chờ'), findsOneWidget);
      // Declining asks nothing first (Decision 25) and is not a red button.
      expect(find.byType(BottomSheet), findsNothing);
      await _end(tester, repo);
    },
  );

  testWidgets('last card gone pops to /work/instant', (tester) async {
    final repo = _repo([
      (id: 'o1', area: 'Phường Bến Thành, Quận 1', expiresIn: 47),
    ]);
    await _open(tester, repo);

    await tester.tap(_decline);
    await settleInstant(tester);

    expect(find.text('stub /work/instant'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets('a card whose countdown reaches 0 disappears', (tester) async {
    final repo = _repo([
      (id: 'o1', area: 'Phường Bến Thành, Quận 1', expiresIn: 5),
      (id: 'o2', area: 'Phường 6, Quận 3', expiresIn: 50),
    ]);
    final (world, _) = await _open(tester, repo);
    expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);

    await world.wait(tester, const Duration(seconds: 5));
    await settleInstant(tester);

    expect(find.text('Phường Bến Thành, Quận 1'), findsNothing);
    expect(find.text('Phường 6, Quận 3'), findsOneWidget);
    expect(find.text('1 lời mời đang chờ'), findsOneWidget);
    // Nothing was sent: the server settles the expiry itself.
    expect(repo.callsOf('answerOffer'), isEmpty);
    await _end(tester, repo);
  });

  testWidgets('an offer the server stops listing leaves the stack', (
    tester,
  ) async {
    final repo = _repo(_three());
    await _open(tester, repo);

    // Withdrawn because another photographer won that request.
    repo.emitOffers([
      for (final o in repo.offers)
        if (o.id != 'o1') o,
    ]);
    await settleInstant(tester);

    expect(find.text('Phường 6, Quận 3'), findsOneWidget);
    expect(find.text('2 lời mời đang chờ'), findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets('Nhận việc is at least 56dp tall', (tester) async {
    final repo = _repo(_three());
    await _open(tester, repo);

    final button = find.ancestor(of: _accept, matching: find.byType(AppButton));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
    // The one primary action of the screen; Từ chối is an outline button.
    expect(
      find.ancestor(of: _decline, matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: _accept, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    await _end(tester, repo);
  });

  testWidgets('fits 320dp at 1.3× text', (tester) async {
    final repo = _repo(_three());
    await _open(tester, repo, textScale: 1.3, viewSize: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(_accept, findsOneWidget);
    expect(_decline, findsOneWidget);
    await _end(tester, repo);
  });

  testWidgets(
    'offers withdrawn before answerOffer completes: the card and the "Nhận việc" loader stay, then the overlay',
    (tester) async {
      final gate = Completer<void>();
      final repo = _repo(_three())
        ..withdrawOnAccept = true
        ..gate = gate;
      repo.emitRequest('req_o1', assignedRequestOf('req_o1'));
      final (_, router) = await _open(tester, repo);

      await tester.tap(_accept);
      await settleInstant(tester);

      // The listener already says "no pending offers"; the answer is out.
      expect(repo.offers, isEmpty);
      expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
      expect(find.text('3 lời mời đang chờ'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('offer-accept')),
          matching: find.byType(DotRingLoader),
        ),
        findsOneWidget,
      );
      expect(router.state.uri.path, '/work/instant/offer/o1');

      repo.gate = null;
      gate.complete();
      await settleInstant(tester);

      expect(
        find.text('Đã match với Lan Anh', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Lời mời đã hết hạn'), findsNothing);
      await _end(tester, repo);
    },
  );

  testWidgets(
    'cold open: an empty cached list then the offer shows the card, no toast, no pop',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf(online: true));
      final (world, router) = await _open(tester, repo);

      repo.emitOffers([offerOf('o1')]);
      await settleInstant(tester);
      await world.wait(tester, const Duration(seconds: 3));

      expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
      expect(find.text('Lời mời đã hết hạn'), findsNothing);
      expect(router.state.uri.path, '/work/instant/offer/o1');
      await _end(tester, repo);
    },
  );

  testWidgets(
    'cold open with nothing after the grace says "Lời mời đã hết hạn" and leaves',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf(online: true));
      await _open(tester, repo);
      expect(find.text('stub /work/instant'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await settleInstant(tester);

      expect(find.text('Lời mời đã hết hạn'), findsOneWidget);
      expect(find.text('stub /work/instant'), findsOneWidget);
      await _end(tester, repo);
    },
  );

  testWidgets('two S14.02 screens keep their own answers', (tester) async {
    final repo = _repo(_three());
    final (_, router) = await _open(tester, repo);
    router.push('/work/instant/offer/o2');
    await settleInstant(tester);
    expect(find.text('Phường 6, Quận 3'), findsOneWidget);

    await tester.tap(_decline);
    await settleInstant(tester);
    expect(find.text('2 lời mời đang chờ'), findsOneWidget);

    // The screen below did not answer anything: the server still lists all
    // three, and so does it.
    router.pop();
    await settleInstant(tester);
    expect(find.text('Phường Bến Thành, Quận 1'), findsOneWidget);
    expect(find.text('3 lời mời đang chờ'), findsOneWidget);
    await _end(tester, repo);
  });
}
