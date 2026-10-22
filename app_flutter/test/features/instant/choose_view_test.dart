import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/choose_view.dart';

import '../../support/instant_customer_world.dart';
import '../../support/meta_finders.dart';

const _like = Key('swipe-like');
const _skip = Key('swipe-skip');
const _undo = Key('swipe-undo');
final _done = find.byKey(const Key('choose-done'));
final _invite = find.byKey(const Key('choose-invite'));
final _more = find.byKey(const Key('choose-more'));

const _summaryTitle = 'Những người bạn đã chọn';
const _roundEnded = 'Chưa ai nhận. Chọn thêm người nhé.';
const _emptyTitle = 'Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn';

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settleInstant(tester);
}

/// Taps ♥ (true) or ✕ (false) once per entry.
Future<void> _swipe(WidgetTester tester, List<bool> likes) async {
  for (final like in likes) {
    await tester.tap(find.byKey(like ? _like : _skip));
    await tester.pump();
  }
  await settleInstant(tester);
}

ScreenCode _code(WidgetTester tester) =>
    tester.widget<ScreenCode>(find.byType(ScreenCode).last);

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<AppButton>(button).onPressed != null;

void main() {
  testWidgets('shows up to 5 cards with name, meta and reasons', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    final six = [
      ...instantCandidates,
      instantCandidates.last.copyWith(photographerId: 'p6', name: 'Anh Thư'),
    ];
    await pumpInstantFlow(
      tester,
      world,
      request: customerRequestOf(candidates: six),
    );
    expect(find.byType(ChooseView), findsOneWidget);
    expect(_code(tester).code, ScreenCodes.instantChoose);
    expect(_code(tester).label, isNull);
    expect(find.text('Chọn người bạn thích'), findsOneWidget);
    expect(find.text('Chân dung · 1 giờ · 690.000₫'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);

    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.byType(VerifiedMark), findsWidgets);
    expect(findMeta('97% · 112 buổi · đến khoảng 9 phút'), findsOneWidget);
    expect(find.text('Chuyên chân dung'), findsOneWidget);
    expect(find.text('Cách 1,2 km'), findsOneWidget);

    await _swipe(tester, [false, false, false, false]);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Gia Huy'), findsOneWidget);
    await _swipe(tester, [false]);
    // The sixth person never shows in this round.
    expect(find.text('Anh Thư'), findsNothing);
  });

  testWidgets('the card pages through up to 3 portfolio photos', (
    tester,
  ) async {
    await pumpInstantFlow(tester, InstantCustomerWorld());
    final first = find.byKey(const ValueKey('photo:https://img/p1a'));
    expect(first, findsOneWidget);
    final card = tester.getRect(first);
    await tester.tapAt(Offset(card.right - 40, card.top + 80));
    await tester.pump();
    expect(find.byKey(const ValueKey('photo:https://img/p1b')), findsOneWidget);
    await tester.tapAt(Offset(card.left + 40, card.top + 80));
    await tester.pump();
    expect(first, findsOneWidget);
    // A tap is not a choice.
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('"Xong" opens the summary with the liked people', (tester) async {
    final world = InstantCustomerWorld();
    await pumpInstantFlow(tester, world);
    expect(_done, findsNothing);
    await _swipe(tester, [true, true]);
    expect(find.text('Đã chọn 2 người'), findsOneWidget);
    expect(find.text('3 / 5'), findsOneWidget);

    await _tap(tester, _done);
    expect(find.text(_summaryTitle), findsOneWidget);
    expect(_code(tester).label, 'summary');
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Hồng Nhung'), findsOneWidget);
    expect(findMeta('97% · đến khoảng 9 phút'), findsOneWidget);
    expect(findMeta('91% · đến khoảng 14 phút'), findsOneWidget);
    expect(
      find.text('Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.'),
      findsOneWidget,
    );
  });

  testWidgets('the last card opens the summary when someone was liked', (
    tester,
  ) async {
    await pumpInstantFlow(tester, InstantCustomerWorld());
    await _swipe(tester, [false, true, false, false, false]);
    expect(find.text(_summaryTitle), findsOneWidget);
    expect(find.text('Hồng Nhung'), findsOneWidget);
  });

  testWidgets(
    'deck end with nobody liked offers "Xem 5 người khác" and sends the skipped ids',
    (tester) async {
      final world = InstantCustomerWorld();
      await pumpInstantFlow(tester, world);
      await _swipe(tester, [false, false, false, false, false]);
      expect(find.text(_summaryTitle), findsNothing);
      expect(find.text('Xem 5 người khác'), findsOneWidget);
      expect(_enabled(tester, _more), isTrue);

      await _tap(tester, _more);
      expect(world.repo.callsOf('nextCandidates').single.args, {
        'requestId': 'req1',
        'skipped': ['p1', 'p2', 'p3', 'p4', 'p5'],
      });
    },
  );

  testWidgets(
    'deck end with nobody liked: Hoàn tác brings the last card back',
    (tester) async {
      await pumpInstantFlow(tester, InstantCustomerWorld());
      await _swipe(tester, [false, false, false, false, false]);
      expect(_more, findsOneWidget);
      await _tap(tester, find.byKey(_undo));
      expect(find.text('Gia Huy'), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(_more, findsNothing);
    },
  );

  testWidgets('Hoàn tác still works after Back from the summary', (
    tester,
  ) async {
    await pumpInstantFlow(tester, InstantCustomerWorld());
    await _swipe(tester, [true, true]);
    await _tap(tester, _done);
    await _tap(tester, find.byTooltip('Quay lại'));
    expect(find.text('3 / 5'), findsOneWidget);
    await _tap(tester, find.byKey(_undo));
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('Đã chọn 1 người'), findsOneWidget);
    await _tap(tester, find.byKey(_undo));
    expect(find.text('1 / 5'), findsOneWidget);
    expect(_done, findsNothing);
  });

  testWidgets('every chosen person unavailable: the toast names them', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    world.repo.inviteResult = const InstantInvited(
      invited: [],
      unavailable: ['p1', 'p2'],
    );
    await pumpInstantFlow(tester, world);
    await _swipe(tester, [true, true]);
    await _tap(tester, _done);
    await _tap(tester, _invite);
    const busy = 'Minh Trí, Hồng Nhung vừa nhận việc khác';
    expect(find.text(busy), findsOneWidget);

    // The server ends the round without inviting anyone: the banner says
    // why, not "Chưa ai nhận".
    ScaffoldMessenger.of(tester.element(find.byType(ChooseView)))
        .removeCurrentSnackBar();
    world.repo.emitRequest(
      'req1',
      customerRequestOf(
        committed: true,
        roundEnded: true,
        candidates: const [],
      ).copyWith(
        offers: const [
          InstantOfferRow(
            photographerId: 'p1',
            name: 'Minh Trí',
            outcome: OfferOutcome.unavailable,
          ),
          InstantOfferRow(
            photographerId: 'p2',
            name: 'Hồng Nhung',
            outcome: OfferOutcome.unavailable,
          ),
        ],
      ),
    );
    await settleInstant(tester);
    expect(_code(tester).label, 'round');
    expect(
      find.descendant(
        of: find.byKey(const Key('choose-round-banner')),
        matching: find.text(busy),
      ),
      findsOneWidget,
    );
    expect(find.text(_roundEnded), findsNothing);
  });

  testWidgets('some chosen people unavailable: the toast names them', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    world.repo.inviteResult = const InstantInvited(
      invited: ['p1'],
      unavailable: ['p2'],
    );
    await pumpInstantFlow(tester, world);
    await _swipe(tester, [true, true]);
    await _tap(tester, _done);
    await _tap(tester, _invite);
    expect(find.text('Hồng Nhung vừa nhận việc khác'), findsOneWidget);
  });

  testWidgets('"Bỏ chọn" says whom for a screen reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpInstantFlow(tester, InstantCustomerWorld());
    await _swipe(tester, [true]);
    await _tap(tester, _done);
    expect(
      tester.getSemantics(find.byKey(const Key('choose-unpick-p1'))),
      isSemantics(
        label: 'Bỏ chọn Minh Trí',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets(
    'summary "Bỏ chọn" removes a person; none left disables the primary',
    (tester) async {
      await pumpInstantFlow(tester, InstantCustomerWorld());
      await _swipe(tester, [true, true]);
      await _tap(tester, _done);
      expect(_enabled(tester, _invite), isTrue);

      await _tap(tester, find.byKey(const Key('choose-unpick-p1')));
      expect(find.text('Minh Trí'), findsNothing);
      expect(find.text('Hồng Nhung'), findsOneWidget);
      expect(_enabled(tester, _invite), isTrue);

      await _tap(tester, find.byKey(const Key('choose-unpick-p2')));
      expect(find.text('Hồng Nhung'), findsNothing);
      expect(_enabled(tester, _invite), isFalse);
    },
  );

  for (final committed in [false, true]) {
    testWidgets(
      'summary primary is "Gửi lời mời" with no method picker in every round (#140), committed: $committed',
      (tester) async {
        final world = InstantCustomerWorld();
        await pumpInstantFlow(
          tester,
          world,
          request: customerRequestOf(
            committed: committed,
            round: committed ? 2 : 1,
          ),
        );
        await _swipe(tester, [true]);
        await _tap(tester, _done);
        expect(
          find.descendant(of: _invite, matching: find.text('Gửi lời mời')),
          findsOneWidget,
        );
        expect(find.textContaining('Thanh toán'), findsNothing);
        expect(find.text('Chuyển khoản QR'), findsNothing);
        expect(find.byType(PayMethodSelector), findsNothing);
        expect(find.byType(PayMethodPicker), findsNothing);
        // One gradient button on the view.
        expect(find.byType(CtaSurface), findsOneWidget);

        await _tap(tester, _invite);
        final call = world.repo.callsOf('invite').single;
        expect(call.args['photographerIds'], ['p1']);
        expect(call.args['payMethod'], isNull);
      },
    );
  }

  testWidgets('cards show the tomato meta, never a star', (tester) async {
    await pumpInstantFlow(tester, InstantCustomerWorld());
    final meta = findMeta('97% · 112 buổi · đến khoảng 9 phút');
    expect(tomatoIconIn(meta), findsOneWidget);
    expect(find.byIcon(AppIcons.star), findsNothing);

    // Under five reviews: "Mới", no percent.
    await _swipe(tester, [false, false, false]);
    expect(find.text('Thu Hà'), findsOneWidget);
    final fresh = findMeta('Mới · 3 đánh giá · 4 buổi · đến khoảng 12 phút');
    expect(fresh, findsOneWidget);
    expect(tomatoIconIn(fresh), findsNothing);
    expect(find.byIcon(AppIcons.star), findsNothing);
  });

  testWidgets(
    'round ended: banner "Chưa ai nhận. Chọn thêm người nhé." and "Xem 5 người khác"',
    (tester) async {
      final world = InstantCustomerWorld();
      await pumpInstantFlow(
        tester,
        world,
        request: customerRequestOf(
          committed: true,
          roundEnded: true,
          round: 2,
          candidates: const [],
        ),
      );
      expect(_code(tester).code, ScreenCodes.instantChoose);
      expect(_code(tester).label, 'round');
      expect(find.text(_roundEnded), findsOneWidget);
      expect(find.text('Xem 5 người khác'), findsOneWidget);
      expect(find.byKey(_like), findsNothing);

      await _tap(tester, _more);
      expect(world.repo.callsOf('nextCandidates').single.args, {
        'requestId': 'req1',
        'skipped': <String>[],
      });
    },
  );

  testWidgets(
    'unpaid with no candidates: empty view, "Thử lại" calls nextCandidates, "Đặt lịch thường" opens /action',
    (tester) async {
      final world = InstantCustomerWorld();
      final router = await pumpInstantFlow(
        tester,
        world,
        request: customerRequestOf(candidates: const []),
      );
      expect(_code(tester).label, 'empty');
      expect(find.text(_emptyTitle), findsOneWidget);
      expect(
        find.text(
          'Bạn chưa phải trả gì. Thử lại sau ít phút hoặc đặt lịch thường.',
        ),
        findsOneWidget,
      );
      expect(find.text(_roundEnded), findsNothing);

      await _tap(tester, find.byKey(const Key('choose-retry')));
      expect(world.repo.callsOf('nextCandidates'), hasLength(1));

      await _tap(tester, find.byKey(const Key('choose-book-normally')));
      expect(router.state.uri.toString(), '/action');
      // The request stays open: nothing was cancelled.
      expect(world.repo.callsOf('cancel'), isEmpty);
    },
  );

  testWidgets('price changed: snackbar with the new amount, summary stays', (
    tester,
  ) async {
    final world = InstantCustomerWorld();
    world.repo.inviteResult = const InstantPriceChanged(amountVnd: 720000);
    await pumpInstantFlow(tester, world);
    await _swipe(tester, [true]);
    await _tap(tester, _done);
    await _tap(tester, _invite);
    expect(
      find.text(
        'Giá vừa đổi thành 720.000₫. Kiểm tra lại trước khi thanh toán.',
      ),
      findsOneWidget,
    );
    expect(find.text(_summaryTitle), findsOneWidget);
    expect(find.text('Chân dung · 1 giờ · 720.000₫'), findsOneWidget);
  });

  testWidgets('a failed invite says so and keeps the summary', (tester) async {
    final world = InstantCustomerWorld();
    world.repo.failNext('invite', 'network');
    await pumpInstantFlow(tester, world);
    await _swipe(tester, [true]);
    await _tap(tester, _done);
    await _tap(tester, _invite);
    expect(find.text('Mất kết nối. Thử lại nhé.'), findsOneWidget);
    expect(find.text(_summaryTitle), findsOneWidget);
    expect(_enabled(tester, _invite), isTrue);
  });

  testWidgets('back on the summary returns to the deck', (tester) async {
    final world = InstantCustomerWorld();
    final router = await pumpInstantFlow(tester, world);
    await _swipe(tester, [true]);
    await _tap(tester, _done);
    await _tap(tester, find.byTooltip('Quay lại'));
    expect(find.text(_summaryTitle), findsNothing);
    expect(find.text('Đã chọn 1 người'), findsOneWidget);
    expect(router.state.uri.toString(), '/instant/req1');
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp at 1.3× text ($brightness)', (tester) async {
      const small = Size(320, 640);
      final world = InstantCustomerWorld();
      final long = [
        for (final c in instantCandidates)
          c.copyWith(
            name: '${c.name} Nguyễn Hoàng Phương',
            reasons: ['Chuyên chân dung ngoài trời', 'Cách 1,2 km từ bạn'],
          ),
      ];
      await pumpInstantFlow(
        tester,
        world,
        request: customerRequestOf(candidates: long),
        viewSize: small,
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      await _swipe(tester, [true, true]);
      expect(tester.takeException(), isNull);
      await _tap(tester, _done);
      expect(tester.takeException(), isNull);

      for (final request in [
        customerRequestOf(
          committed: true,
          roundEnded: true,
          candidates: const [],
          round: 2,
        ),
        customerRequestOf(candidates: const [], round: 3),
      ]) {
        world.repo.emitRequest('req1', request);
        await settleInstant(tester);
        expect(tester.takeException(), isNull);
      }
      // The router is still on the request.
      expect(
        GoRouter.of(tester.element(find.byType(ChooseView))).state.uri
            .toString(),
        '/instant/req1',
      );
    });
  }
}
