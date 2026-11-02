// test/features/settings/settings_organizer_row_test.dart
//
// S09.02's S30 rows: "Tổ chức sự kiện / quản lý địa điểm" for everyone,
// "Địa điểm của tôi" for an organizer, "Soát vé · {spot}" for gate staff.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_organizer_repository.dart';
import '../../support/fake_push.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/organizer_world.dart';
import '../../support/photo_scope.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<GoRouter> _open(
  WidgetTester tester, {
  void Function(FakeOrganizerRepository organizers, String uid)? seed,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Lan');
  await users.ensureProfile(u);
  await users.setRole(u.uid, UserRole.customer);
  final organizers = FakeOrganizerRepository(uid: u.uid);
  seed?.call(organizers, u.uid);
  final spots = FakeSpotRepository()..seedSpot(makeSpot(managedBy: 'org1'));

  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      for (final p in [
        '/organizer/apply',
        '/organizer/spots/claim',
        '/organizer/spots/:spotId',
        '/scan',
        '/profile/phone',
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
          FakePublicProfileRepository(const []),
        ),
        awardRepositoryProvider.overrideWithValue(
          FakeAwardRepository(uid: u.uid)..setTier(null),
        ),
        photographerIntroRepositoryProvider.overrideWithValue(
          FakePhotographerIntroRepository(),
        ),
        studioRepositoryProvider.overrideWithValue(
          FakeStudioRepository(uid: u.uid),
        ),
        organizerRepositoryProvider.overrideWithValue(organizers),
        spotRepositoryProvider.overrideWithValue(spots),
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
  return router;
}

void main() {
  testWidgets('the row appears for everyone and opens S30.01', (tester) async {
    final router = await _open(tester);

    expect(find.text('Tổ chức sự kiện / quản lý địa điểm'), findsOneWidget);
    expect(_key('settings-group-organizer'), findsOneWidget);
    await tester.tap(_key('settings-organizer'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/organizer/apply');
  });

  testWidgets('becomes "Địa điểm của tôi" for an organizer with spots', (
    tester,
  ) async {
    final router = await _open(
      tester,
      seed: (o, uid) => o.putOrganizer(makeOrganizer(id: uid)),
    );

    expect(find.text('Tổ chức sự kiện / quản lý địa điểm'), findsNothing);
    expect(find.text('Địa điểm của tôi'), findsOneWidget);
    await tester.tap(_key('settings-organizer'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/organizer/spots/bd');
  });

  testWidgets('an organizer without a spot goes to S30.02', (tester) async {
    final router = await _open(
      tester,
      seed: (o, uid) =>
          o.putOrganizer(makeOrganizer(id: uid, managedSpotIds: const [])),
    );

    expect(find.text('Địa điểm của tôi'), findsOneWidget);
    await tester.tap(_key('settings-organizer'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/organizer/spots/claim');
  });

  testWidgets('"Soát vé · {spot}" for active gate staff only', (tester) async {
    final router = await _open(
      tester,
      seed: (o, uid) {
        o.putOrganizer(makeOrganizer());
        o.putGateStaff(
          GateStaff(
            organizerId: 'org1',
            staffUid: uid,
            status: GateStaffStatus.active,
            invitedAt: DateTime.utc(2026, 11, 1),
          ),
        );
        o.putGateStaff(
          GateStaff(
            organizerId: 'org2',
            staffUid: uid,
            status: GateStaffStatus.invited,
            invitedAt: DateTime.utc(2026, 11, 1),
          ),
        );
      },
    );

    expect(find.text('Soát vé · Bãi đá sông Hồng'), findsOneWidget);
    expect(_key('settings-gate-org2'), findsNothing);
    await tester.tap(_key('settings-gate-org1'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/scan');
  });
}
