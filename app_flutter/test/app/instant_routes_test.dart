import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';
import 'package:photobooking/features/notifications/notification_targets.dart';

import '../support/photographer_world.dart';

/// Resolves [location] through the app router's top-level and route
/// redirects, as a push tap (`openNotificationTarget`) would, and returns
/// where it lands plus the page the last route builds.
Future<(String, Widget?)> _land(
  WidgetTester tester, {
  required UserRole role,
  required String location,
  bool enabled = true,
}) async {
  final w = PhotographerWorld(role: role);
  await w.init();
  final container = ProviderContainer(
    overrides: [
      ...w.overrides,
      instantEnabledProvider.overrideWithValue(enabled),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(currentProfileProvider, (_, _) {});
  await container.read(authStateProvider.future);
  await container.read(currentProfileProvider.future);
  final router = container.read(routerProvider);
  final config = router.configuration;
  await tester.pumpWidget(const SizedBox());
  final context = tester.element(find.byType(SizedBox));
  final matches = await config.redirect(
    context,
    config.findMatch(Uri.parse(location)),
    redirectHistory: [],
  );
  final last = matches.matches.lastOrNull;
  final route = last?.route;
  final page = route is GoRoute
      ? route.builder?.call(
          context,
          last!.buildState(config, matches, metadata: const {}),
        )
      : null;
  return (matches.uri.toString(), page);
}

void main() {
  testWidgets(
    'a push to /instant/{id} lands on the flow screen for a customer',
    (tester) async {
      final target = safeTarget('/instant/req1');
      expect(target, '/instant/req1');
      final (landed, page) = await _land(
        tester,
        role: UserRole.customer,
        location: target!,
      );
      expect(landed, '/instant/req1');
      expect(page, isA<InstantFlowScreen>());
      expect((page! as InstantFlowScreen).requestId, 'req1');
    },
  );

  testWidgets('a photographer opening /instant/{id} lands on /home', (
    tester,
  ) async {
    final (landed, _) = await _land(
      tester,
      role: UserRole.photographer,
      location: '/instant/req1',
    );
    expect(landed, '/home');
  });

  testWidgets('with Chụp ngay off, /instant/{id} lands on /home', (
    tester,
  ) async {
    final (landed, _) = await _land(
      tester,
      role: UserRole.customer,
      location: '/instant/req1',
      enabled: false,
    );
    expect(landed, '/home');
  });
}
