// test/data/jobs/open_jobs_assembly_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/firestore_job_repository.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_repository.dart';
import 'package:photobooking/data/jobs/quote.dart';

void main() {
  group('assembleOpenJobs pure function', () {
    final now = DateTime.utc(2026, 10, 20, 10, 0);

    Job makeJob({
      required String id,
      JobStatus status = JobStatus.open,
      DateTime? quoteDeadline,
      AllowedProviders allowedProviders = AllowedProviders.all,
      String specialtyId = 'portrait',
      JobBudget? budget,
      double lat = 10.7769,
      double lng = 106.7009,
    }) {
      return Job(
        id: id,
        customerId: 'cust_1',
        customer: const JobCustomer(name: 'Cust'),
        specialtyId: specialtyId,
        title: 'Job $id',
        description: 'Description $id',
        schedule: const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60),
        dayFrom: '2026-10-25',
        dayTo: '2026-10-25',
        area: JobArea(
          areaId: 'a1',
          name: 'Quận 1, TP.HCM',
          city: 'TP.HCM',
          cityKey: 'tphcm',
          lat: lat,
          lng: lng,
          geohash5: 'w4rqp',
        ),
        budget: budget,
        wants: const JobWants(),
        allowedProviders: allowedProviders,
        quoteDeadline: quoteDeadline ?? now.add(const Duration(days: 3)),
        status: status,
        createdAt: now,
        updatedAt: now,
      );
    }

    PhotographerSummary makeMe({
      ProviderType providerType = ProviderType.individual,
      int? startingPriceVnd = 1000000,
    }) {
      return PhotographerSummary(
        id: 'photo_me',
        displayName: 'My Name',
        providerType: providerType,
        startingPriceVnd: startingPriceVnd,
      );
    }

    test('invited jobs come first', () {
      final j1 = makeJob(id: 'j1');
      final j2 = makeJob(id: 'j2');
      final j3 = makeJob(id: 'j3');

      // j2 is invited, j1 has match fit 95, j3 has match fit 80
      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j1', photographerId: 'photo_me', fit: 95, jobStatus: 'open', createdAt: now),
        JobMatch(id: 'photo_me', jobId: 'j3', photographerId: 'photo_me', fit: 80, jobStatus: 'open', createdAt: now),
      ];
      final invites = [
        JobInvite(id: 'photo_me', jobId: 'j2', photographerId: 'photo_me', customerId: 'c1', fit: 70, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: invites,
        jobs: [j1, j2, j3],
        me: makeMe(),
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit),
        now: now,
      );

      expect(items.length, 3);
      expect(items[0].job.id, 'j2');
      expect(items[0].invited, true);
      expect(items[1].job.id, 'j1');
      expect(items[1].invited, false);
      expect(items[2].job.id, 'j3');
      expect(items[2].invited, false);
    });

    test('closed or expired jobs are dropped', () {
      final openJob = makeJob(id: 'j_open');
      final closedJob = makeJob(id: 'j_closed', status: JobStatus.closed);
      final expiredJob = makeJob(id: 'j_expired', quoteDeadline: now.subtract(const Duration(minutes: 1)));

      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j_open', photographerId: 'photo_me', fit: 90, jobStatus: 'open', createdAt: now),
        JobMatch(id: 'photo_me', jobId: 'j_closed', photographerId: 'photo_me', fit: 90, jobStatus: 'open', createdAt: now),
        JobMatch(id: 'photo_me', jobId: 'j_expired', photographerId: 'photo_me', fit: 90, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: const [],
        jobs: [openJob, closedJob, expiredJob],
        me: makeMe(),
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit),
        now: now,
      );

      expect(items.length, 1);
      expect(items.first.job.id, 'j_open');
    });

    test('artist-only is kept locked for an individual', () {
      final artistJob = makeJob(id: 'j_artist', allowedProviders: AllowedProviders.artist);

      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j_artist', photographerId: 'photo_me', fit: 85, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: const [],
        jobs: [artistJob],
        me: makeMe(providerType: ProviderType.individual),
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit),
        now: now,
      );

      expect(items.length, 1);
      expect(items.first.job.id, 'j_artist');
      expect(items.first.locked, true);
    });

    test('artist-only is dropped for a studio', () {
      final artistJob = makeJob(id: 'j_artist', allowedProviders: AllowedProviders.artist);

      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j_artist', photographerId: 'photo_me', fit: 85, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: const [],
        jobs: [artistJob],
        me: makeMe(providerType: ProviderType.studio),
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit),
        now: now,
      );

      expect(items.isEmpty, true);
    });

    test('studio-only is dropped for an individual', () {
      final studioJob = makeJob(id: 'j_studio', allowedProviders: AllowedProviders.studio);

      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j_studio', photographerId: 'photo_me', fit: 85, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: const [],
        jobs: [studioJob],
        me: makeMe(providerType: ProviderType.individual),
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit),
        now: now,
      );

      expect(items.isEmpty, true);
    });

    test('near mode drops jobs outside the radius when a centre exists', () {
      // Centre at Quận 1 (10.7769, 106.7009)
      final center = (lat: 10.7769, lng: 106.7009);
      final radiusKm = 10.0;

      // Close job (approx 2 km away)
      final nearJob = makeJob(id: 'j_near', lat: 10.7800, lng: 106.6900);
      // Far job: Vũng Tàu (approx 65 km away)
      final farJob = makeJob(id: 'j_far', lat: 10.3460, lng: 107.0843);

      final items = assembleOpenJobs(
        matches: const [],
        invites: const [],
        jobs: [nearJob, farJob],
        me: makeMe(),
        filter: const OpenJobsFilter(mode: OpenJobsMode.near),
        now: now,
        myCenter: center,
        myRadiusKm: radiusKm,
      );

      expect(items.length, 1);
      expect(items.first.job.id, 'j_near');
    });

    test('budgetOnly keeps jobs whose budget max reaches my starting price and drops open-budget jobs', () {
      // My starting price is 1,500,000
      final me = makeMe(startingPriceVnd: 1500000);

      final reachBudgetJob = makeJob(id: 'j_reach', budget: const JobBudget(min: 1000000, max: 2000000));
      final lowBudgetJob = makeJob(id: 'j_low', budget: const JobBudget(min: 500000, max: 1200000));
      final openBudgetJob = makeJob(id: 'j_open_budget', budget: null);

      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j_reach', photographerId: 'photo_me', fit: 90, jobStatus: 'open', createdAt: now),
        JobMatch(id: 'photo_me', jobId: 'j_low', photographerId: 'photo_me', fit: 90, jobStatus: 'open', createdAt: now),
        JobMatch(id: 'photo_me', jobId: 'j_open_budget', photographerId: 'photo_me', fit: 90, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: const [],
        jobs: [reachBudgetJob, lowBudgetJob, openBudgetJob],
        me: me,
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit, budgetOnly: true),
        now: now,
      );

      expect(items.length, 1);
      expect(items.first.job.id, 'j_reach');
    });

    test('fit comes from the match or invite', () {
      final j1 = makeJob(id: 'j1');
      final j2 = makeJob(id: 'j2');

      final matches = [
        JobMatch(id: 'photo_me', jobId: 'j1', photographerId: 'photo_me', fit: 91, jobStatus: 'open', createdAt: now),
      ];
      final invites = [
        JobInvite(id: 'photo_me', jobId: 'j2', photographerId: 'photo_me', customerId: 'c1', fit: 88, jobStatus: 'open', createdAt: now),
      ];

      final items = assembleOpenJobs(
        matches: matches,
        invites: invites,
        jobs: [j1, j2],
        me: makeMe(),
        filter: const OpenJobsFilter(mode: OpenJobsMode.fit),
        now: now,
      );

      final item1 = items.firstWhere((i) => i.job.id == 'j1');
      final item2 = items.firstWhere((i) => i.job.id == 'j2');

      expect(item1.fit, 91);
      expect(item2.fit, 88);
    });
  });
}
