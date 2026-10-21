// test/features/settings/settings_studio_rows_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/content_fixtures.dart';
import '../../support/fake_push.dart';
import '../../support/photo_scope.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

/// S09.02 signed in as a provider of [type] (null: a customer); [seed] fills
/// the studio relations of the signed-in uid.
Future<void> _open(
  WidgetTester tester, {
  ProviderType? type = ProviderType.individual,
  bool businessVerified = false,
  void Function(FakeStudioRepository studios, String uid)? seed,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await users.setRole(
    u.uid,
    type == null ? UserRole.customer : UserRole.photographer,
  );
  final intros = FakePhotographerIntroRepository()
    ..seed(
      u.uid,
      PhotographerIntro(
        verified: true,
        businessVerified: businessVerified,
        providerType: type ?? ProviderType.individual,
      ),
    );
  final studios = FakeStudioRepository(uid: u.uid);
  seed?.call(studios, u.uid);

  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      for (final p in [
        '/studio/members',
        '/me/studio',
        '/verify/start',
        '/verify/business',
        '/me/awards',
        '/u/:uid',
        '/profile/phone',
        '/profile/skills',
        '/setup/4',
      ])
        GoRoute(path: p, builder: stub),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        userContactRepositoryProvider.overrideWithValue(
          FakeUserContactRepository(),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
        pushMessagingProvider.overrideWithValue(FakePushMessaging()),
        notificationPermissionProvider.overrideWithValue(
          FakeNotificationPermission(NotificationPermissionStatus.denied),
        ),
        deviceRegistryProvider.overrideWithValue(FakeDeviceRegistry()),
        publicProfileRepositoryProvider.overrideWithValue(
          FakePublicProfileRepository([
            if (type != null)
              PhotographerProfile(
                summary: fixturePhotographer(u.uid, providerType: type),
              ),
          ]),
        ),
        awardRepositoryProvider.overrideWithValue(
          FakeAwardRepository(uid: u.uid)..setTier(null),
        ),
        photographerIntroRepositoryProvider.overrideWithValue(intros),
        studioRepositoryProvider.overrideWithValue(studios),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => testPhotoScope(child: child!),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _in(String key, String text) =>
    find.descendant(of: _key(key), matching: find.text(text));

void main() {
  testWidgets('a studio sees Thành viên studio with {n}/{max} thợ', (
    tester,
  ) async {
    await _open(
      tester,
      type: ProviderType.studio,
      businessVerified: true,
      seed: (studios, uid) {
        for (var i = 0; i < 6; i++) {
          studios.seedRelation(
            makeRelation(id: 'm$i', studioId: uid, memberId: 'x$i'),
          );
        }
        // Pending invites are not members yet.
        studios.seedRelation(
          makeRelation(
            id: 'inv',
            studioId: uid,
            memberId: 'y',
            status: RelationStatus.invited,
          ),
        );
      },
    );
    expect(_in('settings-studio-members', 'Thành viên studio'), findsOneWidget);
    expect(_in('settings-studio-members', '6/30 thợ'), findsOneWidget);
    expect(_key('settings-my-studio'), findsNothing);
    await tester.tap(_key('settings-studio-members'));
    await tester.pumpAndSettle();
    expect(find.text('stub /studio/members'), findsOneWidget);
  });

  testWidgets('an unverified studio counts against 3', (tester) async {
    await _open(tester, type: ProviderType.studio);
    expect(_in('settings-studio-members', '0/3 thợ'), findsOneWidget);
  });

  testWidgets('a photographer sees Studio của tôi with the studio name or '
      'Chưa ở studio nào', (tester) async {
    await _open(
      tester,
      seed: (studios, uid) => studios.seedRelation(
        makeRelation(studioId: 'may', studioName: 'Studio Mây', memberId: uid),
      ),
    );
    expect(_in('settings-my-studio', 'Studio của tôi'), findsOneWidget);
    expect(_in('settings-my-studio', 'Studio Mây'), findsOneWidget);
    expect(_key('settings-studio-members'), findsNothing);
    await tester.tap(_key('settings-my-studio'));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/studio'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    // An invite alone is not a studio.
    await _open(
      tester,
      type: ProviderType.artist,
      seed: (studios, uid) => studios.seedRelation(
        makeRelation(
          studioId: 'nang',
          studioName: 'Studio Nắng',
          memberId: uid,
          status: RelationStatus.invited,
        ),
      ),
    );
    expect(_in('settings-my-studio', 'Chưa ở studio nào'), findsOneWidget);
  });

  testWidgets('a customer sees neither', (tester) async {
    await _open(tester, type: null);
    expect(_key('settings-studio-members'), findsNothing);
    expect(_key('settings-my-studio'), findsNothing);
  });
}
