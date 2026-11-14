import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/day_pricing/day_pricing_screen.dart';
import 'package:photobooking/features/day_pricing/price_rules_screen.dart';

import '../support/photographer_world.dart';

/// Resolves [location] through the app router's redirects and returns where
/// it lands plus the page the last route builds.
Future<(String, Widget?)> _land(
  WidgetTester tester, {
  required UserRole role,
  required String location,
}) async {
  final w = PhotographerWorld(role: role);
  await w.init();
  final container = ProviderContainer(
    overrides: w.overrides,
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(currentProfileProvider, (_, _) {});
  await container.read(authStateProvider.future);
  await container.read(currentProfileProvider.future);
  final config = container.read(routerProvider).configuration;
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
  testWidgets('/me/day-pricing?service= opens S08.10 for that package', (
    tester,
  ) async {
    final (landed, page) = await _land(
      tester,
      role: UserRole.photographer,
      location: '/me/day-pricing?service=p2',
    );
    expect(landed, '/me/day-pricing?service=p2');
    expect((page! as DayPricingScreen).serviceId, 'p2');
  });

  testWidgets('/me/day-pricing without a package opens S08.10', (tester) async {
    final (_, page) = await _land(
      tester,
      role: UserRole.photographer,
      location: '/me/day-pricing',
    );
    expect((page! as DayPricingScreen).serviceId, isNull);
  });

  testWidgets('/me/day-pricing/rules opens the list', (tester) async {
    final (landed, page) = await _land(
      tester,
      role: UserRole.photographer,
      location: '/me/day-pricing/rules?from=calendar',
    );
    expect(landed, '/me/day-pricing/rules?from=calendar');
    expect((page! as PriceRulesScreen).fromCalendar, isTrue);
    final (_, direct) = await _land(
      tester,
      role: UserRole.photographer,
      location: '/me/day-pricing/rules',
    );
    expect((direct! as PriceRulesScreen).fromCalendar, isFalse);
  });

  testWidgets('the old /me/special-days lands on the calendar', (tester) async {
    final (landed, page) = await _land(
      tester,
      role: UserRole.photographer,
      location: '/me/special-days',
    );
    expect(landed, '/me/day-pricing');
    expect(page, isA<DayPricingScreen>());
  });

  testWidgets('a customer is sent home from all three', (tester) async {
    for (final location in [
      '/me/day-pricing',
      '/me/day-pricing/rules',
      '/me/special-days',
    ]) {
      final (landed, _) = await _land(
        tester,
        role: UserRole.customer,
        location: location,
      );
      expect(landed, '/home', reason: location);
    }
  });
}
