// test/features/job_market/job_photographer_detail_test.dart
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
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/job_market/job_photographer_detail.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 20);

  Job makeTestJob({
    String id = 'j1',
    JobStatus status = JobStatus.open,
    AllowedProviders allowed = AllowedProviders.all,
  }) {
    return Job(
      id: id,
      customerId: 'c1',
      customer: const JobCustomer(
        name: 'Trần Khách',
        hireCount: 3,
        phoneVerified: true,
      ),
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu Đại học Quốc gia',
      description: 'Chụp nhóm 20 bạn, có trang phục cử nhân.',
      schedule: const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-25', start: '08:00', durationMinutes: 120),
      dayFrom: '2026-10-25',
      dayTo: '2026-10-25',
      area: const JobArea(
        areaId: 'a1',
        name: 'Cầu Giấy, Hà Nội',
        city: 'Hà Nội',
        cityKey: 'ha-noi',
        lat: 21.03,
        lng: 105.78,
        geohash5: 'w4gxx',
      ),
      budget: const JobBudget(min: 2000000, max: 3000000),
      wants: const JobWants(editedCount: 40, deliveryDays: 5),
      allowedProviders: allowed,
      quoteDeadline: now.add(const Duration(days: 2)),
      status: status,
      quoteCount: 4,
      viewCount: 10,
      inviteCount: 2,
      createdAt: now,
      updatedAt: now,
    );
  }

  Quote makeTestQuote({
    String id = 'q1',
    String jobId = 'j1',
    QuoteStatus status = QuoteStatus.submitted,
    int price = 2500000,
    String? bookingId,
  }) {
    return Quote(
      id: id,
      jobId: jobId,
      photographerId: 'p1',
      customerId: 'c1',
      jobTitle: 'Chụp kỷ yếu Đại học Quốc gia',
      photographer: const QuoteProvider(name: 'Thợ Ảnh p1', providerType: ProviderType.individual),
      terms: QuoteTerms(
        price: price,
        durationMinutes: 120,
        editedCount: 40,
        deliveryDays: 5,
        revisions: 1,
      ),
      milestoneAmounts: const QuoteMilestoneAmounts(shoot: 1250000, delivery: 1250000),
      proposal: const QuoteProposal(day: '2026-10-25', start: '08:00', end: '10:00'),
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm.',
      status: status,
      bookingId: bookingId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget buildTestWidget({
    required FakeJobRepository repo,
    required Job job,
    FakeAvailabilityLookup? availability,
    PhotographerProfile? profile,
    bool openQuote = false,
  }) {
    final avail = availability ?? FakeAvailabilityLookup();
    final effectiveProfile = profile ??
        const PhotographerProfile(
          summary: PhotographerSummary(
            id: 'p1',
            displayName: 'Photographer 1',
            providerType: ProviderType.individual,
            approvedAwardCount: 3,
            specialtyIds: ['graduation'],
          ),
        );

    final fakeProfileRepo = FakePublicProfileRepository([effectiveProfile]);

    final router = GoRouter(
      initialLocation: '/jobs/${job.id}',
      routes: [
        GoRoute(
          path: '/jobs/:id',
          builder: (_, _) => Scaffold(
            body: JobPhotographerDetail(job: job, openQuote: openQuote),
          ),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) => Scaffold(body: Text('ChatScreen ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/b/:id',
          builder: (_, state) => Scaffold(body: Text('BookingScreen ${state.pathParameters['id']}')),
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
        availabilityLookupProvider.overrideWithValue(avail),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('matches mock rows: poster, date status, area, budget & wants, records view and marks invite seen', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.text('Trần Khách'), findsOneWidget);
    expect(find.text('Bạn rảnh ngày này'), findsOneWidget);
    expect(find.textContaining('Cầu Giấy, Hà Nội'), findsOneWidget);
    expect(find.text('Địa chỉ cụ thể gửi khi bạn được chọn'), findsOneWidget);
    expect(find.text('Bàn giao ≥ 40 ảnh chỉnh · trong 5 ngày'), findsOneWidget);
    expect(find.text('Gửi báo giá'), findsOneWidget);

    expect(repo.viewsByJob[job.id], contains('p1'));
    expect(repo.seenInvites[job.id], contains('p1'));
  });

  testWidgets('a busy day disables the primary with Ngày này bạn đã có lịch', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    final avail = FakeAvailabilityLookup();
    avail.set('p1', '2026-10-25', DayAvailability.booked);

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job, availability: avail));
    await tester.pumpAndSettle();

    expect(find.text('Bạn đã có lịch'), findsOneWidget);
    expect(find.text('Ngày này bạn đã có lịch'), findsOneWidget);
    final btn = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Ngày này bạn đã có lịch'));
    expect(btn.onPressed, isNull);
  });

  testWidgets('a pending day shows Bạn có yêu cầu đang chờ and keeps Gửi báo giá enabled', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    final avail = FakeAvailabilityLookup();
    avail.set('p1', '2026-10-25', DayAvailability.pending);

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job, availability: avail));
    await tester.pumpAndSettle();

    expect(find.text('Bạn có yêu cầu đang chờ'), findsOneWidget);
    expect(find.text('Gửi báo giá'), findsOneWidget);
    final btn = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Gửi báo giá'));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('an artist-only job for an individual disables the primary and links to S25.01', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob(allowed: AllowedProviders.artist);
    repo.jobs[job.id] = job;

    final profile = const PhotographerProfile(
      summary: PhotographerSummary(
        id: 'p1',
        displayName: 'Photographer 1',
        providerType: ProviderType.individual,
        approvedAwardCount: 1, // < 3
        specialtyIds: ['graduation'],
      ),
    );

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job, profile: profile));
    await tester.pumpAndSettle();

    expect(find.text('Chỉ Nhiếp ảnh gia báo giá được'), findsOneWidget);
    final btn = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Chỉ Nhiếp ảnh gia báo giá được'));
    expect(btn.onPressed, isNull);

    // Tap link to awards
    await tester.tap(find.text('Chỉ NAG báo giá được · bạn còn 2 giải đã duyệt nữa'));
    await tester.pumpAndSettle();
    expect(find.text('AwardsScreen'), findsOneWidget);
  });

  testWidgets('after quoting: shows card Báo giá của bạn, Sửa báo giá, and red Rút báo giá with confirm sheet', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    final quote = makeTestQuote(jobId: job.id, price: 2500000, status: QuoteStatus.submitted);
    repo.quotesByJob[job.id] = {'p1': quote};

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.text('Báo giá của bạn · 2,5M · Đang chờ'), findsOneWidget);
    expect(find.text('Sửa báo giá'), findsOneWidget);
    expect(find.text('Rút báo giá'), findsOneWidget);

    await tester.tap(find.text('Rút báo giá'));
    await tester.pumpAndSettle();

    expect(find.text('Rút báo giá?'), findsOneWidget);
    // Confirm withdraw
    await tester.tap(find.widgetWithText(AppButton, 'Rút báo giá'));
    await tester.pumpAndSettle();

    expect(repo.withdrawCalls, contains(job.id));
  });

  testWidgets('a chosen quote shows Khách đã chọn bạn and Mở buổi chụp', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob(status: JobStatus.awarded);
    repo.jobs[job.id] = job;

    final quote = makeTestQuote(jobId: job.id, status: QuoteStatus.accepted, bookingId: 'b_789');
    repo.quotesByJob[job.id] = {'p1': quote};

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.text('Khách đã chọn bạn'), findsOneWidget);
    expect(find.text('Mở buổi chụp'), findsOneWidget);

    await tester.tap(find.text('Mở buổi chụp'));
    await tester.pumpAndSettle();

    expect(find.text('BookingScreen b_789'), findsOneWidget);
  });

  testWidgets('a closed job is read-only with Việc đã đóng', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob(status: JobStatus.closed);
    repo.jobs[job.id] = job;

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.text('Việc đã đóng'), findsWidgets);
  });

  testWidgets('Hỏi khách opens the job inquiry chat', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('job-ask-customer-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ChatScreen chat_'), findsOneWidget);
  });

  testWidgets('the screen never shows a phone number or a street address', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'(\+84|0[35789])\d{8}')), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    repo.jobs[job.id] = job;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: buildTestWidget(repo: repo, job: job),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chụp kỷ yếu Đại học Quốc gia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
