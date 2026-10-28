// test/features/jobs/job_entry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/jobs/job_entry.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('without a phone, posting opens /profile/phone?returnTo=/jobs/new', (tester) async {
    final repo = FakeJobRepository(currentUid: 'u1');
    final routesVisited = <String>[];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Consumer(
            builder: (ctx, ref, _) => ElevatedButton(
              onPressed: () => startJobPost(ctx, ref),
              child: const Text('Post'),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/phone',
          builder: (ctx, state) {
            routesVisited.add(state.uri.toString());
            return const Scaffold(body: Text('Phone Screen'));
          },
        ),
        GoRoute(
          path: '/jobs/new',
          builder: (ctx, state) {
            routesVisited.add(state.uri.toString());
            return const Scaffold(body: Text('New Job Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
          currentContactProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(routesVisited, contains('/profile/phone?returnTo=%2Fjobs%2Fnew'));
  });

  testWidgets('with 3 open jobs the entry shows the limit message and stays', (tester) async {
    final now = DateTime.utc(2026, 10, 20);
    final repo = FakeJobRepository(currentUid: 'u1', clock: () => now);

    final openJobsList = <Job>[];
    for (int i = 1; i <= 3; i++) {
      final j = Job(
        id: 'j$i',
        customerId: 'u1',
        customer: const JobCustomer(name: 'User 1'),
        specialtyId: 'portrait',
        title: 'Job $i',
        description: 'Mô tả',
        schedule: const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-25', durationMinutes: 60),
        dayFrom: '2026-10-25',
        dayTo: '2026-10-25',
        area: const JobArea(
          areaId: 'a1',
          name: 'Hoàn Kiếm, Hà Nội',
          city: 'Hà Nội',
          cityKey: 'ha-noi',
          lat: 21.0,
          lng: 105.8,
          geohash5: 'w4gxx',
        ),
        wants: const JobWants(),
        allowedProviders: AllowedProviders.all,
        quoteDeadline: now.add(const Duration(days: 3)),
        status: JobStatus.open,
        createdAt: now,
        updatedAt: now,
      );
      repo.jobs['j$i'] = j;
      openJobsList.add(j);
    }

    final routesVisited = <String>[];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => ElevatedButton(
                onPressed: () => startJobPost(ctx, ref),
                child: const Text('Post'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/jobs/new',
          builder: (ctx, state) {
            routesVisited.add(state.uri.toString());
            return const Scaffold(body: Text('New Job Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
          myJobsProvider.overrideWith((ref) => Stream.value(openJobsList)),
          currentContactProvider.overrideWith(
            (ref) => Stream.value(
              const UserContact(phone: '0901234567', phoneVerified: true),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify limit toast shown and did not navigate
    expect(find.text('Bạn đang có 3 việc mở. Đóng bớt một việc để đăng tiếp.'), findsOneWidget);
    expect(routesVisited, isEmpty);
  });
}
