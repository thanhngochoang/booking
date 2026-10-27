// test/features/job_market/open_jobs_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/work/work_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 20);

  Job makeTestJob({
    required String id,
    String title = 'Chụp ảnh kỷ yếu',
    String specialtyId = 'graduation',
    JobSchedule schedule = const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-25', durationMinutes: 120),
    JobArea area = const JobArea(
      areaId: 'a1',
      name: 'Cầu Giấy, Hà Nội',
      city: 'Hà Nội',
      cityKey: 'ha-noi',
      lat: 21.03,
      lng: 105.78,
      geohash5: 'w4gxx',
    ),
    JobBudget? budget = const JobBudget(min: 1000000, max: 2000000),
    AllowedProviders allowed = AllowedProviders.all,
    JobStatus status = JobStatus.open,
    int quoteCount = 0,
  }) {
    return Job(
      id: id,
      customerId: 'c1',
      customer: const JobCustomer(name: 'Khách Hàng'),
      specialtyId: specialtyId,
      title: title,
      description: 'Mô tả công việc',
      schedule: schedule,
      dayFrom: '2026-10-25',
      dayTo: '2026-10-25',
      area: area,
      budget: budget,
      wants: const JobWants(editedCount: 30, deliveryDays: 3),
      allowedProviders: allowed,
      quoteDeadline: now.add(const Duration(days: 3)),
      status: status,
      quoteCount: quoteCount,
      viewCount: 5,
      inviteCount: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget buildTestWidget({
    required FakeJobRepository repo,
    String? initialTab,
    PhotographerProfile? profile,
    PhotographerIntro? intro,
  }) {
    final effectiveProfile = profile ??
        const PhotographerProfile(
          summary: PhotographerSummary(
            id: 'p1',
            displayName: 'Photographer 1',
            specialtyIds: ['graduation', 'portrait'],
            startingPriceVnd: 1500000,
            providerType: ProviderType.individual,
            approvedAwardCount: 3,
          ),
        );

    final fakeProfileRepo = FakePublicProfileRepository([effectiveProfile]);

    final router = GoRouter(
      initialLocation: '/work',
      routes: [
        GoRoute(
          path: '/work',
          builder: (_, _) => WorkScreen(initialTab: initialTab),
        ),
        GoRoute(
          path: '/jobs/:id',
          builder: (_, state) => Scaffold(body: Text('JobDetail ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/setup',
          builder: (_, _) => const Scaffold(body: Text('SetupScreen')),
        ),
        GoRoute(
          path: '/profile/skills',
          builder: (_, _) => const Scaffold(body: Text('SkillsScreen')),
        ),
        GoRoute(
          path: '/me/awards',
          builder: (_, _) => const Scaffold(body: Text('AwardsScreen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(uid: 'p1'))),
        publicProfileRepositoryProvider.overrideWithValue(fakeProfileRepo),
        myIntroProvider.overrideWith((ref) => Stream.value(intro ?? const PhotographerIntro(bio: 'Hello', onboardingComplete: true))),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('the tab label carries the count and switching tabs works', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job1 = makeTestJob(id: 'j1', title: 'Job 1');
    final job2 = makeTestJob(id: 'j2', title: 'Job 2');
    repo.openJobsOverride = [
      OpenJobItem(job: job1, fit: 85),
      OpenJobItem(job: job2, fit: 90),
    ];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'today'));
    await tester.pumpAndSettle();

    expect(find.text('Hôm nay'), findsWidgets);
    expect(find.text('Việc đang tuyển · 2'), findsOneWidget);
    expect(find.text('Báo giá của tôi'), findsOneWidget);

    await tester.tap(find.text('Việc đang tuyển · 2'));
    await tester.pumpAndSettle();

    expect(find.text('Job 1'), findsOneWidget);
    expect(find.text('Job 2'), findsOneWidget);
  });

  testWidgets('Hợp với bạn lists invited jobs first with Bạn được mời and the fit', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final jobRegular = makeTestJob(id: 'j1', title: 'Job Normal');
    final jobInvited = makeTestJob(id: 'j2', title: 'Job Invited');
    repo.openJobsOverride = [
      OpenJobItem(job: jobInvited, fit: 92, invited: true),
      OpenJobItem(job: jobRegular, fit: 85, invited: false),
    ];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Bạn được mời'), findsOneWidget);
    expect(find.text('Hợp 92%'), findsOneWidget);
    expect(find.text('Hợp 85%'), findsOneWidget);

    expect(
      tester.getTopLeft(find.text('Job Invited')).dy,
      lessThan(tester.getTopLeft(find.text('Job Normal')).dy),
    );
  });

  testWidgets('Gần tôi lists city jobs without a fit pill when there is no match', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final jobNear = makeTestJob(id: 'j_near', title: 'Job Near Me');
    repo.openJobsOverride = [
      OpenJobItem(job: jobNear, fit: null),
    ];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gần tôi'));
    await tester.pumpAndSettle();

    expect(find.text('Job Near Me'), findsOneWidget);
    expect(find.byType(FitPill), findsNothing);
  });

  testWidgets('an artist-only job is dimmed for an individual with the lock line and tapping it opens S25.01', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final artistJob = makeTestJob(
      id: 'j_artist',
      title: 'Job Artist Only',
      allowed: AllowedProviders.artist,
    );
    repo.openJobsOverride = [
      OpenJobItem(job: artistJob, locked: true),
    ];

    // User is an individual with 1 award (so needs 2 more for 3)
    final profile = const PhotographerProfile(
      summary: PhotographerSummary(
        id: 'p1',
        displayName: 'Photographer 1',
        providerType: ProviderType.individual,
        approvedAwardCount: 1,
        specialtyIds: ['graduation'],
      ),
    );

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs', profile: profile));
    await tester.pumpAndSettle();

    expect(find.text('Job Artist Only'), findsOneWidget);
    expect(find.text('Chỉ Nhiếp ảnh gia'), findsOneWidget);
    expect(find.text('Chỉ NAG báo giá được · bạn còn 2 giải đã duyệt nữa'), findsOneWidget);

    await tester.tap(find.text('Job Artist Only'));
    await tester.pumpAndSettle();

    expect(find.text('AwardsScreen'), findsOneWidget);
  });

  testWidgets('a studio-only job is not listed for an individual', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final studioJob = makeTestJob(
      id: 'j_studio',
      title: 'Job Studio Only',
      allowed: AllowedProviders.studio,
    );
    repo.openJobsOverride = [
      OpenJobItem(job: studioJob),
    ];

    final profile = const PhotographerProfile(
      summary: PhotographerSummary(
        id: 'p1',
        displayName: 'Photographer 1',
        providerType: ProviderType.individual,
        specialtyIds: ['graduation'],
      ),
    );

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs', profile: profile));
    await tester.pumpAndSettle();

    expect(find.text('Job Studio Only'), findsNothing);
  });

  testWidgets('the specialty chip filters', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final jobGrad = makeTestJob(id: 'j1', title: 'Graduation Shoot', specialtyId: 'graduation');
    final jobPortrait = makeTestJob(id: 'j2', title: 'Portrait Shoot', specialtyId: 'portrait');
    repo.openJobsOverride = [
      OpenJobItem(job: jobGrad),
      OpenJobItem(job: jobPortrait),
    ];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Graduation Shoot'), findsOneWidget);
    expect(find.text('Portrait Shoot'), findsOneWidget);

    // Tap first specialty chip
    await tester.tap(find.byKey(const Key('filter-specialty')));
    await tester.pumpAndSettle();

    expect(find.text('Graduation Shoot'), findsOneWidget);
    expect(find.text('Portrait Shoot'), findsNothing);
  });

  testWidgets('Ngân sách keeps jobs whose budget reaches my starting price', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    repo.myStartingPrice = 1500000;
    final jobLow = makeTestJob(id: 'j_low', title: 'Low Budget', budget: const JobBudget(min: 500000, max: 1000000));
    final jobHigh = makeTestJob(id: 'j_high', title: 'High Budget', budget: const JobBudget(min: 1000000, max: 2000000));
    repo.openJobsOverride = [
      OpenJobItem(job: jobLow),
      OpenJobItem(job: jobHigh),
    ];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ngân sách'));
    await tester.pumpAndSettle();

    expect(find.text('High Budget'), findsOneWidget);
    expect(find.text('Low Budget'), findsNothing);
  });

  testWidgets('an unfinished profile shows Hoàn tất hồ sơ để thấy việc đang tuyển with an action to /setup', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);

    final incompleteIntro = const PhotographerIntro(
      bio: '',
      onboardingComplete: false,
    );

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs', intro: incompleteIntro));
    await tester.pumpAndSettle();

    expect(find.text('Hoàn tất hồ sơ để thấy việc đang tuyển'), findsOneWidget);
    expect(find.text('Hoàn tất hồ sơ'), findsOneWidget);

    await tester.tap(find.text('Hoàn tất hồ sơ'));
    await tester.pumpAndSettle();

    expect(find.text('SetupScreen'), findsOneWidget);
  });

  testWidgets('no jobs shows the empty text and Sửa thể loại → /profile/skills', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    repo.openJobsOverride = [];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có việc hợp với bạn. Thêm thể loại hoặc mở rộng khu vực.'), findsOneWidget);
    expect(find.text('Sửa thể loại'), findsOneWidget);

    await tester.tap(find.text('Sửa thể loại'));
    await tester.pumpAndSettle();

    expect(find.text('SkillsScreen'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob(id: 'j1', title: 'Refreshable Job');
    repo.openJobsOverride = [
      OpenJobItem(job: job),
    ];

    await tester.pumpWidget(buildTestWidget(repo: repo, initialTab: 'jobs'));
    await tester.pumpAndSettle();

    expect(find.text('Refreshable Job'), findsOneWidget);

    await tester.fling(find.text('Refreshable Job'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Refreshable Job'), findsOneWidget);
  });
}
