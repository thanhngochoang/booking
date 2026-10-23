// test/support/job_world.dart
//
// Test harness for jobs & quotes: fake repository, signed in user,
// router stubs, and clock.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/jobs/job_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_job_repository.dart';

final jobNow = DateTime.utc(2026, 10, 20, 3); // 10:00 VN

class JobWorld {
  JobWorld({
    this.uid = 'c1',
    this.role = UserRole.customer,
    FakeJobRepository? repository,
    DateTime? now,
  })  : clock = (now ?? jobNow),
        repository = repository ?? FakeJobRepository(currentUid: uid, clock: () => now ?? jobNow);

  final String uid;
  final UserRole role;
  final DateTime clock;
  final FakeJobRepository repository;

  late SharedPreferences prefs;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }

  List<Override> overrides() {
    return [
      jobRepositoryProvider.overrideWithValue(repository),
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => clock),
      currentProfileProvider.overrideWith(
        (ref) => Stream.value(
          UserProfile(
            uid: uid,
            email: '$uid@example.com',
            displayName: 'Test User $uid',
            role: role,
          ),
        ),
      ),
    ];
  }

  GoRouter createRouter({String initialLocation = '/jobs/j1'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/jobs/new',
          builder: (_, state) => JobScreen(
            jobId: state.uri.queryParameters['from'] ??
                state.uri.queryParameters['edit'] ??
                'new',
          ),
        ),
        GoRoute(
          path: '/jobs/:id',
          builder: (_, state) => JobScreen(
            jobId: state.pathParameters['id']!,
          ),
          routes: [
            GoRoute(
              path: 'quote',
              builder: (_, state) => JobScreen(
                jobId: state.pathParameters['id']!,
                openQuote: true,
              ),
            ),
            GoRoute(
              path: 'applications',
              builder: (_, state) => JobScreen(
                jobId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: ':quoteId',
                  builder: (_, state) => JobScreen(
                    jobId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'pay',
                      builder: (_, state) => JobScreen(
                        jobId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget buildApp({String initialLocation = '/jobs/j1'}) {
    final router = createRouter(initialLocation: initialLocation);
    return ProviderScope(
      overrides: overrides(),
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }
}
