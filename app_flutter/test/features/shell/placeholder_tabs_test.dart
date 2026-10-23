import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/booking/my_bookings_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/features/work/work_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_booking_repository.dart';
import '../../support/fake_push.dart';
import '../../support/fake_spot_repository.dart';

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
        spotRepositoryProvider.overrideWithValue(FakeSpotRepository()),
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

  Widget routed(
    FakeAuthRepository auth,
    FakeUserRepository users,
    FakePhotographerIntroRepository intro, {
    String initial = '/bookings',
  }) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/bookings', builder: (_, _) => const BookingsTab()),
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
        spotRepositoryProvider.overrideWithValue(FakeSpotRepository()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

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
