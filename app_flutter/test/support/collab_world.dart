// test/support/collab_world.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/features/collab/collab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recruit_world.dart';
import 'studio_world.dart';

/// S27.06 (`/collab`, query `offer`) over a [RecruitWorld]: the studio side
/// signed in as `cuc`, the photographer side as `dung`. [studios] answers
/// the S26.02 search of the collaborator invite sheet.
class CollabWorld {
  CollabWorld({bool studio = true, bool businessVerified = false})
    : world = RecruitWorld(uid: studio ? 'cuc' : 'dung'),
      studios = FakeStudioRepository(
        uid: studio ? 'cuc' : 'dung',
        clock: () => recruitNow,
      ) {
    world.recruits.setFacts(
      world.uid,
      makeProviderFacts(
        providerType: studio ? ProviderType.studio : ProviderType.individual,
        businessVerified: businessVerified,
      ),
    );
    world.recruits.setCounters(
      world.uid,
      const RecruitCounters(
        activeCollabCount: 3,
        collabActions: RecruitDaily(day: '2026-10-21', count: 2),
      ),
    );
  }

  final RecruitWorld world;
  final FakeStudioRepository studios;
  late SharedPreferences prefs;

  /// What the screen copied to the clipboard, newest last.
  final clipboard = <String>[];

  String get uid => world.uid;
  String get location => world.location;

  /// Pumps `/collab` (or [location]) with stub pages for the places S27.06
  /// leaves to.
  Future<void> pump(
    WidgetTester tester, {
    String location = '/collab',
    Size size = const Size(390, 1400),
    double textScale = 1.0,
    Map<String, Object> prefsValues = const {},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      world.app(
        location,
        routes: [
          GoRoute(
            path: '/collab',
            builder: (_, s) =>
                CollabScreen(offerBookingId: s.uri.queryParameters['offer']),
          ),
        ],
        stubs: const ['/chat/:id', '/u/:uid', '/b/:id', '/recruit'],
        textScale: textScale,
        extraOverrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          studioRepositoryProvider.overrideWithValue(studios),
        ],
      ),
    );
    await settle(tester);
  }

  /// S27.06 has bounded loaders only: a second of frames.
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// [call] (a fake's `(name, payload)`) is [name] with [payload]: a record of
/// differently typed maps is never `==`.
void expectCall(
  (String, Map<String, Object?>) call,
  String name,
  Map<String, Object?> payload,
) {
  expect(call.$1, name);
  expect(call.$2, payload);
}
