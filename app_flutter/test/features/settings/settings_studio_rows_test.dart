// test/features/settings/settings_studio_rows_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
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
import '../../support/recruit_world.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

/// S09.02 signed in as a provider of [type] (null: a customer); [seed] fills
/// the studio relations of the signed-in uid.
Future<void> _open(
  WidgetTester tester, {
  ProviderType? type = ProviderType.individual,
  bool businessVerified = false,
  StreamController<PhotographerIntro?>? introLater,
  void Function(FakeStudioRepository studios, String uid)? seed,
  void Function(
    FakeCollabRepository collabs,
    FakeRecruitRepository recruits,
    String uid,
  )?
  seedCollab,
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
  final collabs = FakeCollabRepository(uid: u.uid);
  final recruits = FakeRecruitRepository(uid: u.uid);
  seedCollab?.call(collabs, recruits, u.uid);

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
        '/collab',
        '/studio/recruit',
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
        collabRepositoryProvider.overrideWithValue(collabs),
        recruitRepositoryProvider.overrideWithValue(recruits),
        if (introLater != null)
          myIntroProvider.overrideWith((ref) => introLater.stream),
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

  testWidgets('until the own intro loads the studio row keeps its line, '
      'never a max that changes', (tester) async {
    final intro = StreamController<PhotographerIntro?>();
    addTearDown(intro.close);
    await _open(
      tester,
      type: ProviderType.studio,
      businessVerified: true,
      introLater: intro,
      seed: (studios, uid) =>
          studios.seedRelation(makeRelation(studioId: uid, memberId: 'x')),
    );
    expect(
      _in('settings-studio-members', 'Mời thợ, giao việc cho thành viên'),
      findsOneWidget,
    );
    expect(_in('settings-studio-members', '1/3 thợ'), findsNothing);
    intro.add(
      const PhotographerIntro(
        businessVerified: true,
        providerType: ProviderType.studio,
      ),
    );
    await tester.pumpAndSettle();
    expect(_in('settings-studio-members', '1/30 thợ'), findsOneWidget);
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

  group('S27 rows', () {
    testWidgets('photographer sees "Cộng tác" with "{n} studio · {m} việc chờ '
        'nhận" → /collab', (tester) async {
      await _open(
        tester,
        seedCollab: (collabs, recruits, uid) {
          final later = DateTime.now().toUtc().add(const Duration(hours: 4));
          collabs
            ..seedCollaboration(makeCollaboration(collaboratorId: uid))
            ..seedCollaboration(
              makeCollaboration(
                studioId: 'nang',
                collaboratorId: uid,
                status: CollabStatus.invited,
              ),
            )
            ..seedJob(
              makeCollabJob(
                collaboratorId: uid,
                offerStatus: OfferStatus.pending,
                offerExpiresAt: later,
              ),
            )
            ..seedJob(
              makeCollabJob(
                bookingId: 'b2',
                collaboratorId: uid,
                offerStatus: OfferStatus.accepted,
              ),
            );
        },
      );
      expect(_in('settings-collab', 'Cộng tác'), findsOneWidget);
      expect(
        _in('settings-collab', '1 studio · 1 việc chờ nhận'),
        findsOneWidget,
      );
      expect(_key('settings-recruit'), findsNothing);
      // Group Tài khoản: after "Studio của tôi", before the public profile.
      final y = tester.getTopLeft(_key('settings-collab')).dy;
      expect(y, greaterThan(tester.getTopLeft(_key('settings-my-studio')).dy));
      expect(y, lessThan(tester.getTopLeft(_key('profile-public')).dy));
      await tester.tap(_key('settings-collab'));
      await tester.pumpAndSettle();
      expect(find.text('stub /collab'), findsOneWidget);
    });

    testWidgets('studio sees "Cộng tác" with "{n} cộng tác viên" and "Tin '
        'tuyển" with "{n}/3 tin mở" → /studio/recruit', (tester) async {
      await _open(
        tester,
        type: ProviderType.studio,
        seedCollab: (collabs, recruits, uid) {
          collabs
            ..seedCollaboration(makeCollaboration(studioId: uid))
            ..seedCollaboration(
              makeCollaboration(studioId: uid, collaboratorId: 'hoa'),
            )
            ..seedCollaboration(
              makeCollaboration(
                studioId: uid,
                collaboratorId: 'yen',
                status: CollabStatus.invited,
              ),
            );
          recruits.setCounters(uid, const RecruitCounters(openPostCount: 1));
        },
      );
      expect(_in('settings-collab', '2 cộng tác viên'), findsOneWidget);
      expect(_in('settings-recruit', 'Tin tuyển'), findsOneWidget);
      expect(_in('settings-recruit', '1/3 tin mở'), findsOneWidget);
      final collab = tester.getTopLeft(_key('settings-collab')).dy;
      final recruit = tester.getTopLeft(_key('settings-recruit')).dy;
      expect(
        collab,
        greaterThan(tester.getTopLeft(_key('settings-studio-members')).dy),
      );
      expect(recruit, greaterThan(collab));
      expect(recruit, lessThan(tester.getTopLeft(_key('profile-public')).dy));
      await tester.tap(_key('settings-recruit'));
      await tester.pumpAndSettle();
      expect(find.text('stub /studio/recruit'), findsOneWidget);
    });

    testWidgets('customer sees neither', (tester) async {
      await _open(tester, type: null);
      expect(_key('settings-collab'), findsNothing);
      expect(_key('settings-recruit'), findsNothing);
    });
  });
}
