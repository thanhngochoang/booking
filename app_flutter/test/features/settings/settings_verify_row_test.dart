// test/features/settings/settings_verify_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
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
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/content_fixtures.dart';
import '../../support/fake_push.dart';
import '../../support/photo_scope.dart';

/// S09.02 signed in as a provider of [type] (null: a customer), with the
/// verification record [doc] (null: none yet) and the own intro [intro].
Future<GoRouter> _open(
  WidgetTester tester, {
  ProviderType? type = ProviderType.individual,
  Map<String, dynamic>? doc,
  bool phoneVerified = false,
  PhotographerIntro intro = const PhotographerIntro(),
}) async {
  tester.view.physicalSize = const Size(390, 2000);
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
  final contacts = FakeUserContactRepository();
  if (phoneVerified) {
    contacts.seed(
      u.uid,
      const UserContact(phone: '+84912343456', phoneVerified: true),
    );
  }
  final verifications = FakeVerificationRepository(uid: u.uid);
  if (doc != null) {
    verifications.seed(u.uid, doc);
  }
  final intros = FakePhotographerIntroRepository()
    ..seed(
      u.uid,
      PhotographerIntro(
        verified: intro.verified,
        providerType: type ?? ProviderType.individual,
      ),
    );

  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      for (final p in [
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
        userContactRepositoryProvider.overrideWithValue(contacts),
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
        verificationRepositoryProvider.overrideWithValue(verifications),
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

Map<String, dynamic> _doc(String status, {bool identity = false}) => {
  'uid': 'u',
  'status': status,
  'steps': {
    if (identity)
      'identity': {
        'method': 'vneid',
        'result': 'passed',
        'maskedName': 'NGUYỄN M** T**',
      },
  },
  'freeResubmitsLeft': 1,
};

Finder _subtitle(String text) => find.descendant(
  of: find.byKey(const Key('settings-verify')),
  matching: find.text(text),
);

void main() {
  testWidgets('S09.02 shows Xác minh & nhận đơn with settingsVerifyBody / Còn '
      '3 bước / Đang chờ duyệt / Đã xác minh', (tester) async {
    await _open(tester);
    final row = find.byKey(const Key('settings-verify'));
    expect(
      find.descendant(of: row, matching: find.text('Xác minh & nhận đơn')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIcons.verified)),
      findsOneWidget,
    );
    expect(_subtitle('Xác minh danh tính để bắt đầu nhận đơn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await _open(tester, doc: _doc('in_progress'), phoneVerified: true);
    // Phone done; fee (#203), identity and rules left.
    expect(_subtitle('Còn 3 bước'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    for (final (status, text) in [
      ('submitted', 'Đang chờ duyệt'),
      ('approved', 'Đã xác minh'),
      ('rejected', 'Chưa được duyệt'),
      ('revoked', 'Đã thu hồi'),
    ]) {
      await _open(tester, doc: _doc(status, identity: true));
      expect(_subtitle(text), findsOneWidget, reason: status);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    final router = await _open(tester);
    await tester.ensureVisible(find.byKey(const Key('settings-verify')));
    await tester.tap(find.byKey(const Key('settings-verify')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/verify/start');
  });

  testWidgets('a verified studio also sees Xác minh doanh nghiệp', (
    tester,
  ) async {
    final router = await _open(
      tester,
      type: ProviderType.studio,
      doc: _doc('approved', identity: true),
      intro: const PhotographerIntro(verified: true),
    );
    final row = find.byKey(const Key('settings-verify-business'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Xác minh doanh nghiệp')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('Con dấu Studio, tới 30 thợ'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(AppIcons.businessVerify)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('settings-verify'))).dy,
      ),
    );
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/verify/business');
  });

  testWidgets('an unverified studio and a verified individual see no '
      'business row', (tester) async {
    await _open(tester, type: ProviderType.studio);
    expect(find.byKey(const Key('settings-verify')), findsOneWidget);
    expect(find.byKey(const Key('settings-verify-business')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    await _open(
      tester,
      doc: _doc('approved', identity: true),
      intro: const PhotographerIntro(verified: true),
    );
    expect(find.byKey(const Key('settings-verify-business')), findsNothing);
  });

  testWidgets('a customer sees neither row', (tester) async {
    await _open(tester, type: null);
    expect(find.byKey(const Key('settings-verify')), findsNothing);
    expect(find.byKey(const Key('settings-verify-business')), findsNothing);
  });
}
