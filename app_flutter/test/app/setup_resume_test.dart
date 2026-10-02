import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

import '../support/photographer_world.dart';

/// Resolves [location] through the app router's top-level and route
/// redirects, as `context.go(location)` would, and returns where it lands.
Future<String> _land(
  WidgetTester tester,
  PhotographerWorld w,
  String location,
) async {
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
  return matches.uri.toString();
}

Future<PhotographerWorld> _world({
  UserRole role = UserRole.photographer,
  int? step,
}) async {
  final w = PhotographerWorld(role: role);
  await w.init();
  if (step != null) {
    await SetupDraftStore(w.prefs).setStep(w.uid, step);
  }
  return w;
}

void main() {
  testWidgets('/setup with no stored step opens step 1', (tester) async {
    final w = await _world();
    expect(await _land(tester, w, '/setup'), '/setup/1');
  });

  for (final step in [2, 3, 4]) {
    testWidgets('/setup resumes at the stored step $step', (tester) async {
      final w = await _world(step: step);
      expect(await _land(tester, w, '/setup'), '/setup/$step');
    });
  }

  testWidgets('a customer opening /setup or /setup/2 lands on /home', (
    tester,
  ) async {
    final w = await _world(role: UserRole.customer, step: 3);
    expect(await _land(tester, w, '/setup'), '/home');
    expect(await _land(tester, w, '/setup/2'), '/home');
  });
}
