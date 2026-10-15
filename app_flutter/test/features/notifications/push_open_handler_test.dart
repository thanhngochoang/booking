import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/push/push_messaging.dart';
import 'package:photobooking/features/notifications/push_open_handler.dart';

import '../../support/notifications_world.dart';

Future<(NotificationsWorld, GoRouter)> _mount(
  WidgetTester tester, {
  PushOpen? initial,
  bool signedIn = true,
}) async {
  final world = NotificationsWorld();
  await world.init();
  world.push.initial = initial;
  if (!signedIn) {
    await world.auth.signOut();
  }
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      for (final p in ['/home', '/b/:id', '/chat/:id', '/bookings'])
        GoRoute(path: p, builder: stub),
    ],
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [...world.overrides, routerProvider.overrideWithValue(router)],
  );
  addTearDown(container.dispose);
  container.listen(pushOpenHandlerProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (world, router);
}

void main() {
  testWidgets('push open marks read and navigates after sign-in', (
    tester,
  ) async {
    final (world, _) = await _mount(tester, signedIn: false);
    world.push.emitOpened(
      const PushOpen(target: '/b/abc', notificationId: 'n_booking_abc'),
    );
    await tester.pumpAndSettle();
    // Nobody is signed in yet: it waits.
    expect(find.text('stub /home'), findsOneWidget);
    expect(world.fake.calls, isEmpty);

    await world.auth.signInWithEmail('lan@b.vn', 'password1');
    await tester.pumpAndSettle();
    expect(find.text('stub /b/abc'), findsOneWidget);
    expect(world.fake.calls, contains('markRead:n_booking_abc'));
  });

  testWidgets('initial push open is handled once', (tester) async {
    final (world, router) = await _mount(
      tester,
      initial: const PushOpen(target: '/chat/c1', notificationId: 'g_chat_c1'),
    );
    expect(find.text('stub /chat/c1'), findsOneWidget);
    expect(
      world.fake.calls.where((c) => c == 'markRead:g_chat_c1'),
      hasLength(1),
    );
    // Signing out and in again does not replay it.
    router.go('/home');
    await world.auth.signOut();
    await world.auth.signInWithEmail('lan@b.vn', 'password1');
    await tester.pumpAndSettle();
    expect(find.text('stub /home'), findsOneWidget);
    expect(
      world.fake.calls.where((c) => c == 'markRead:g_chat_c1'),
      hasLength(1),
    );
  });

  testWidgets('a push to a target outside the allowlist opens nothing', (
    tester,
  ) async {
    final (world, _) = await _mount(tester);
    world.push.emitOpened(
      const PushOpen(target: 'https://evil.example/', notificationId: 'n1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('stub /home'), findsOneWidget);
    expect(world.fake.calls, contains('markRead:n1'));
  });

  testWidgets('a push to the Work tab switches tabs instead of stacking', (
    tester,
  ) async {
    final (world, _) = await _mount(tester);
    world.push.emitOpened(const PushOpen(target: '/bookings'));
    await tester.pumpAndSettle();
    expect(find.text('stub /bookings'), findsOneWidget);
  });
}
