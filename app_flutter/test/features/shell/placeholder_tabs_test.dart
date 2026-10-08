import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/booking/my_bookings_screen.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/features/work/work_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/content_fixtures.dart';
import '../../support/fake_booking_repository.dart';
import '../../support/fake_push.dart';

Future<(FakeAuthRepository, FakeUserRepository)> _signedIn(
  UserRole role,
) async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await users.setRole(u.uid, role);
  return (auth, users);
}

Widget _app(Widget home, FakeAuthRepository auth, FakeUserRepository users) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(
          FakePhotographerIntroRepository(),
        ),
        bookingRepositoryProvider.overrideWithValue(FakeBookingRepository()),
        // S06.02's inputs (portfolio, packages, skills score).
        postRepositoryProvider.overrideWithValue(FakePostRepository()),
        servicePackageRepositoryProvider.overrideWithValue(
          FakeServicePackageRepository(),
        ),
        skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
        // Push ports: no plugin runs in tests.
        pushMessagingProvider.overrideWithValue(FakePushMessaging()),
        notificationPermissionProvider.overrideWithValue(
          FakeNotificationPermission(NotificationPermissionStatus.denied),
        ),
        deviceRegistryProvider.overrideWithValue(FakeDeviceRegistry()),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  testWidgets('bookings tab shows S06.01 (here its empty S06.02) for '
      'photographers', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(_app(const BookingsTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.byType(WorkScreen), findsOneWidget);
    expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
    expect(find.byType(MyBookingsScreen), findsNothing);
  });
  testWidgets('bookings tab shows S05.01 for customers', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const BookingsTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.byType(MyBookingsScreen), findsOneWidget);
    expect(find.text('Chưa có buổi chụp sắp tới'), findsOneWidget);
  });
  for (final size in const [Size(320, 640), Size(430, 932)]) {
    testWidgets('bookings tab fits $size at text scale 1.3', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (auth, users) = await _signedIn(UserRole.customer);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _app(const BookingsTab(), auth, users),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S09.01: large avatar; mode switch and sign-out live in '
      'S09.02', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const ProfileTab(), auth, users));
    await tester.pumpAndSettle();
    final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
    expect(avatar.size, AppAvatarSize.lg);
    expect(find.byKey(const Key('switch-role')), findsNothing);
    expect(find.byKey(const Key('sign-out')), findsNothing);
    expect(find.text('Tôi là nhiếp ảnh gia'), findsNothing);
  });

  Widget routed(
    FakeAuthRepository auth,
    FakeUserRepository users,
    FakePhotographerIntroRepository intro, {
    String initial = '/profile',
    FakePublicProfileRepository? profiles,
    SharedPreferences? prefs,
    FakeAwardRepository? awards,
  }) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
        GoRoute(path: '/bookings', builder: (_, _) => const BookingsTab()),
        GoRoute(path: '/setup', builder: (_, _) => const Text('setup')),
        GoRoute(
          path: '/me/albums',
          builder: (_, _) => const Text('stub /me/albums'),
        ),
        GoRoute(
          path: '/me/awards',
          builder: (_, _) => const Text('stub /me/awards'),
        ),
        GoRoute(
          path: '/work/earnings',
          builder: (_, _) => const Text('stub /work/earnings'),
        ),
        GoRoute(
          path: '/work/calendar',
          builder: (_, _) => const Text('calendar'),
        ),
      ],
    );
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(intro),
        bookingRepositoryProvider.overrideWithValue(FakeBookingRepository()),
        // S06.02's inputs (portfolio, packages, skills score).
        postRepositoryProvider.overrideWithValue(FakePostRepository()),
        servicePackageRepositoryProvider.overrideWithValue(
          FakeServicePackageRepository(),
        ),
        skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
        if (profiles != null)
          publicProfileRepositoryProvider.overrideWithValue(profiles),
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        if (awards != null) awardRepositoryProvider.overrideWithValue(awards),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('S09.01: photographers see Album của tôi, customers do not', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final intro = FakePhotographerIntroRepository()
      ..seed(
        auth.currentUser!.uid,
        const PhotographerIntro(onboardingComplete: true),
      );
    await tester.pumpWidget(routed(auth, users, intro));
    await tester.pumpAndSettle();
    expect(find.text('Album của tôi'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open-my-albums')));
    await tester.tap(find.byKey(const Key('open-my-albums')));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/albums'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    final (auth2, users2) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(
      routed(auth2, users2, FakePhotographerIntroRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Album của tôi'), findsNothing);
  });

  testWidgets('S09.01: photographers see Thu nhập and it opens S06.05', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final intro = FakePhotographerIntroRepository()
      ..seed(
        auth.currentUser!.uid,
        const PhotographerIntro(onboardingComplete: true),
      );
    await tester.pumpWidget(routed(auth, users, intro));
    await tester.pumpAndSettle();
    expect(find.text('Thu nhập'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open-earnings')));
    await tester.tap(find.byKey(const Key('open-earnings')));
    await tester.pumpAndSettle();
    expect(find.text('stub /work/earnings'), findsOneWidget);
  });

  testWidgets('S09.01: customers do not see Thu nhập', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(
      routed(auth, users, FakePhotographerIntroRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thu nhập'), findsNothing);
    expect(find.byKey(const Key('open-earnings')), findsNothing);
  });

  /// The signed-in photographer's public profile with [type].
  FakePublicProfileRepository profileOf(String uid, ProviderType type) =>
      FakePublicProfileRepository([
        PhotographerProfile(
          summary: fixturePhotographer(uid, providerType: type),
        ),
      ]);

  testWidgets('S09.01: the awards nudge shows for individuals and hides after '
      'Để sau', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn(UserRole.photographer);
    final uid = auth.currentUser!.uid;
    final intro = FakePhotographerIntroRepository()
      ..seed(uid, const PhotographerIntro(onboardingComplete: true));
    final profiles = profileOf(uid, ProviderType.individual);
    await tester.pumpWidget(
      routed(auth, users, intro, profiles: profiles, prefs: prefs),
    );
    await tester.pumpAndSettle();
    expect(find.text('Có giải thưởng? Lên hạng Nhiếp ảnh gia'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('award-nudge')));
    await tester.tap(find.byKey(const Key('award-nudge')));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/awards'), findsOneWidget);

    // Back on the tab, "Để sau" hides it and remembers per user.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      routed(auth, users, intro, profiles: profiles, prefs: prefs),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('award-nudge-later')));
    await tester.tap(find.byKey(const Key('award-nudge-later')));
    await tester.pumpAndSettle();
    expect(find.text('Có giải thưởng? Lên hạng Nhiếp ảnh gia'), findsNothing);
    expect(prefs.getBool('awardNudgeDismissed:$uid'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      routed(auth, users, intro, profiles: profiles, prefs: prefs),
    );
    await tester.pumpAndSettle();
    expect(find.text('Có giải thưởng? Lên hạng Nhiếp ảnh gia'), findsNothing);
  });

  testWidgets('S09.01: the nudge hides when the live tier becomes artist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn(UserRole.photographer);
    final uid = auth.currentUser!.uid;
    final intro = FakePhotographerIntroRepository()
      ..seed(uid, const PhotographerIntro(onboardingComplete: true));
    final awards = FakeAwardRepository(uid: uid)..setTier(const AwardTier());
    await tester.pumpWidget(
      routed(
        auth,
        users,
        intro,
        profiles: profileOf(uid, ProviderType.individual),
        prefs: prefs,
        awards: awards,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('award-nudge')), findsOneWidget);

    // The cached profile still says individual; the tier stream moves on.
    awards.setTier(const AwardTier(providerType: ProviderType.artist));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('award-nudge')), findsNothing);
  });

  testWidgets('S09.01: no awards nudge for an artist, a studio or a customer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (final type in [ProviderType.artist, ProviderType.studio]) {
      final (auth, users) = await _signedIn(UserRole.photographer);
      final uid = auth.currentUser!.uid;
      final intro = FakePhotographerIntroRepository()
        ..seed(uid, const PhotographerIntro(onboardingComplete: true));
      await tester.pumpWidget(
        routed(
          auth,
          users,
          intro,
          profiles: profileOf(uid, type),
          prefs: prefs,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('award-nudge')),
        findsNothing,
        reason: '$type',
      );
      await tester.pumpWidget(const SizedBox());
    }
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(
      routed(auth, users, FakePhotographerIntroRepository(), prefs: prefs),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('award-nudge')), findsNothing);
  });

  testWidgets(
    'a photographer with unfinished setup is offered to continue it',
    (tester) async {
      final (auth, users) = await _signedIn(UserRole.photographer);
      final intro = FakePhotographerIntroRepository()
        ..seed(auth.currentUser!.uid, const PhotographerIntro());
      await tester.pumpWidget(routed(auth, users, intro));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thiện hồ sơ nhiếp ảnh gia'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('continue-setup')));
      await tester.tap(find.byKey(const Key('continue-setup')));
      await tester.pumpAndSettle();
      expect(find.text('setup'), findsOneWidget);
    },
  );

  testWidgets('the setup card is gone once setup is complete', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final intro = FakePhotographerIntroRepository()
      ..seed(
        auth.currentUser!.uid,
        const PhotographerIntro(onboardingComplete: true),
      );
    await tester.pumpWidget(routed(auth, users, intro));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue-setup')), findsNothing);
  });

  testWidgets('photographers open their calendar from the work tab', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(
      routed(
        auth,
        users,
        FakePhotographerIntroRepository(),
        initial: '/bookings',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('customers have no calendar entry', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(
      routed(
        auth,
        users,
        FakePhotographerIntroRepository(),
        initial: '/bookings',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MyBookingsScreen), findsOneWidget);
    expect(find.byKey(const Key('open-calendar')), findsNothing);
  });
}
