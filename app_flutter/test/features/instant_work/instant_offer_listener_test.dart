import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/features/instant_work/instant_offer_listener.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';
import '../../support/screen_host.dart';

Widget _stub(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('stub ${s.uri}'));

/// The listener wraps `/home` the way it wraps the tab shell.
Future<GoRouter> _mount(
  WidgetTester tester,
  FakeInstantRepository repo, {
  bool enabled = true,
}) async {
  final world = InstantWorld(repo: repo);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => InstantOfferListener(
          enabled: enabled,
          child: const Scaffold(body: Text('home')),
        ),
      ),
      GoRoute(path: '/work/instant/offer/:offerId', builder: _stub),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(router: router, overrides: world.overrides),
  );
  await settleInstant(tester);
  return router;
}

Future<void> _end(WidgetTester tester, FakeInstantRepository repo) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await repo.dispose();
}

void main() {
  testWidgets('a new offer opens /work/instant/offer/{id}', (tester) async {
    final repo = FakeInstantRepository(presence: presenceOf(online: true));
    final router = await _mount(tester, repo);
    expect(find.text('home'), findsOneWidget);

    repo.emitOffers([offerOf('o1')]);
    await settleInstant(tester);

    expect(router.state.uri.path, '/work/instant/offer/o1');
    // The same offer again (a stream update) does not open a second screen.
    router.pop();
    await settleInstant(tester);
    repo.emitOffers([offerOf('o1')]);
    await settleInstant(tester);
    expect(router.state.uri.path, '/home');
    await _end(tester, repo);
  });

  testWidgets('an offer already pending when the app opens is shown', (
    tester,
  ) async {
    final repo = FakeInstantRepository(
      presence: presenceOf(online: true),
      offers: [offerOf('o1')],
    );
    final router = await _mount(tester, repo);

    expect(router.state.uri.path, '/work/instant/offer/o1');
    await _end(tester, repo);
  });

  testWidgets('does nothing when S14.02 is already open', (tester) async {
    final repo = FakeInstantRepository(
      presence: presenceOf(online: true),
      offers: [offerOf('o1')],
    );
    final router = await _mount(tester, repo);
    expect(router.state.uri.path, '/work/instant/offer/o1');

    repo.emitOffers([offerOf('o1'), offerOf('o2', requestId: 'req2')]);
    await settleInstant(tester);

    // The open S14.02 adds the new card to its stack itself.
    expect(router.state.uri.path, '/work/instant/offer/o1');
    router.pop();
    await settleInstant(tester);
    expect(router.state.uri.path, '/home');
    await _end(tester, repo);
  });

  testWidgets('does nothing when the photographer is offline', (tester) async {
    final repo = FakeInstantRepository(presence: presenceOf());
    final router = await _mount(tester, repo);

    repo.emitOffers([offerOf('o1')]);
    await settleInstant(tester);

    expect(router.state.uri.path, '/home');
    await _end(tester, repo);
  });

  testWidgets(
    'does nothing while the app is in the background, opens on resume',
    (tester) async {
      final repo = FakeInstantRepository(presence: presenceOf(online: true));
      final router = await _mount(tester, repo);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      repo.emitOffers([offerOf('o1')]);
      await settleInstant(tester);
      expect(router.state.uri.path, '/home');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleInstant(tester);
      expect(router.state.uri.path, '/work/instant/offer/o1');
      await _end(tester, repo);
    },
  );

  testWidgets(
    'disabled (not a photographer, Chụp ngay off) listens to nothing',
    (tester) async {
      final repo = FakeInstantRepository(
        presence: presenceOf(online: true),
        offers: [offerOf('o1')],
      );
      final router = await _mount(tester, repo, enabled: false);

      expect(router.state.uri.path, '/home');
      await _end(tester, repo);
    },
  );
}
