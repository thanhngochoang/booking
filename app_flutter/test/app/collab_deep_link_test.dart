// A cold-start deep link keeps its query through /splash (#151 Task 9).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/collab/collab_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../support/recruit_world.dart';

void main() {
  test('the splash remembers the whole URI and resumes it', () {
    final parked = computeRedirect(
      authLoading: true,
      signedIn: false,
      profileLoaded: false,
      needsRole: false,
      location: '/collab',
      target: '/collab?offer=b2',
    );
    expect(parked, '/splash?from=%2Fcollab%3Foffer%3Db2');
    final from = Uri.parse(parked!).queryParameters['from'];
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/splash',
        from: from,
      ),
      '/collab?offer=b2',
    );
    // A non-resumable target with a query still goes home.
    expect(
      computeRedirect(
        signedIn: true,
        profileLoaded: true,
        needsRole: false,
        location: '/splash',
        from: '/login?next=x',
      ),
      '/home',
    );
  });

  testWidgets('a cold-start /collab?offer=b2 lands on S27.06 with the offer', (
    tester,
  ) async {
    final auth = StreamController<AuthUser?>();
    final profile = StreamController<UserProfile?>();
    addTearDown(auth.close);
    addTearDown(profile.close);
    final w = RecruitWorld(uid: 'dung');
    w.recruits.setFacts('dung', makeProviderFacts());
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        currentProfileProvider.overrideWith((ref) => profile.stream),
        accountLockProvider.overrideWith((ref) => Stream.value(null)),
        clockProvider.overrideWithValue(() => recruitNow),
        recruitRepositoryProvider.overrideWithValue(w.recruits),
        collabRepositoryProvider.overrideWithValue(w.collabs),
      ],
    );
    addTearDown(container.dispose);
    // Watched, as the app widget does: a provider nobody listens to is
    // paused, and so are the router's auth and profile listeners.
    final router = container.listen(routerProvider, (_, _) {}).read();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildDarkTheme(),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    String location() =>
        router.routerDelegate.currentConfiguration.uri.toString();

    router.go('/collab?offer=b2');
    await tester.pump(const Duration(milliseconds: 100));
    expect(location(), '/splash?from=%2Fcollab%3Foffer%3Db2');

    auth.add(const AuthUser(uid: 'dung'));
    profile.add(
      const UserProfile(
        uid: 'dung',
        displayName: 'Dũng',
        role: UserRole.photographer,
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(location(), '/collab?offer=b2');
    expect(
      tester.widget<CollabScreen>(find.byType(CollabScreen)).offerBookingId,
      'b2',
    );
  });
}
