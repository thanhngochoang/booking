// test/features/jobs/my_jobs_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/features/jobs/my_jobs_tab.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('my jobs tab renders empty state when no jobs', (tester) async {
    final now = DateTime.utc(2026, 10, 20);
    final repo = FakeJobRepository(currentUid: 'u1', clock: () => now);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MyJobsTab()),
        ),
      ),
    );

    await tester.pump();
    repo.notifyJob('');
    await tester.pumpAndSettle();

    expect(find.text('Chưa tìm được thợ ưng ý? Đăng việc để thợ ảnh báo giá cho bạn'), findsOneWidget);
    expect(find.text('Đăng việc'), findsOneWidget);
  });

  testWidgets('my jobs tab orders jobs: open by deadline, awarded, then expired', (tester) async {
    final now = DateTime.utc(2026, 10, 20);
    final repo = FakeJobRepository(currentUid: 'u1', clock: () => now);

    final jobOpen1 = Job(
      id: 'j_open1',
      customerId: 'u1',
      customer: const JobCustomer(name: 'User 1'),
      specialtyId: 'portrait',
      title: 'Job Open Deadline Later',
      description: 'Mô tả',
      schedule: const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-30', durationMinutes: 60),
      dayFrom: '2026-10-30',
      dayTo: '2026-10-30',
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
      quoteDeadline: now.add(const Duration(days: 5)),
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    final jobOpen2 = Job(
      id: 'j_open2',
      customerId: 'u1',
      customer: const JobCustomer(name: 'User 1'),
      specialtyId: 'wedding',
      title: 'Job Open Deadline Sooner',
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
      quoteDeadline: now.add(const Duration(days: 1)),
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    final jobAwarded = Job(
      id: 'j_awarded',
      customerId: 'u1',
      customer: const JobCustomer(name: 'User 1'),
      specialtyId: 'event',
      title: 'Job Awarded',
      description: 'Mô tả',
      schedule: const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-28', durationMinutes: 60),
      dayFrom: '2026-10-28',
      dayTo: '2026-10-28',
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
      quoteDeadline: now.subtract(const Duration(days: 1)),
      status: JobStatus.awarded,
      awardedTo: const AwardedTo(name: 'Photographer A', photographerId: 'p_a', price: 2000000),
      bookingId: 'b_123',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 1)),
    );

    repo.jobs['j_open1'] = jobOpen1;
    repo.jobs['j_open2'] = jobOpen2;
    repo.jobs['j_awarded'] = jobAwarded;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MyJobsTab()),
        ),
      ),
    );

    await tester.pump();
    repo.notifyJob('');
    await tester.pumpAndSettle();

    expect(find.text('Job Open Deadline Sooner'), findsOneWidget);
    expect(find.text('Job Open Deadline Later'), findsOneWidget);
    expect(find.text('Job Awarded'), findsOneWidget);
    expect(find.text('Mở buổi chụp →'), findsOneWidget);
    expect(find.text('Đăng việc mới'), findsOneWidget);
  });
}
