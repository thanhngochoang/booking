// test/features/jobs/job_owner_detail_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/features/jobs/job_owner_detail.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('job owner detail shows stats, latest quotes, compare button and popup actions', (tester) async {
    final now = DateTime.utc(2026, 10, 20);
    final repo = FakeJobRepository(currentUid: 'u1', clock: () => now);

    final job = Job(
      id: 'j1',
      customerId: 'u1',
      customer: const JobCustomer(name: 'User 1'),
      specialtyId: 'portrait',
      title: 'Chụp ảnh tốt nghiệp Văn Miếu',
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
      quoteCount: 1,
      viewCount: 12,
      inviteCount: 2,
      createdAt: now,
      updatedAt: now,
    );

    final quote = Quote(
      id: 'q1',
      jobId: 'j1',
      photographerId: 'p1',
      customerId: 'u1',
      jobTitle: 'Chụp ảnh tốt nghiệp Văn Miếu',
      photographer: const QuoteProvider(name: 'An Thợ Ảnh', providerType: ProviderType.individual),
      terms: const QuoteTerms(
        price: 1500000,
        durationMinutes: 60,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 1,
      ),
      milestoneAmounts: const QuoteMilestoneAmounts(shoot: 750000, delivery: 750000),
      proposal: const QuoteProposal(day: '2026-10-25', start: '08:00', end: '09:00'),
      message: 'Chào bạn',
      status: QuoteStatus.submitted,
      fit: 90,
      createdAt: now,
      updatedAt: now,
    );

    repo.jobs['j1'] = job;
    repo.quotesByJob['j1'] = {'p1': quote};

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: JobOwnerDetail(job: job),
        ),
      ),
    );

    // Initial pump subscribes to watchQuotes stream
    await tester.pump();
    repo.notifyQuotes('j1');
    await tester.pumpAndSettle();

    // Verify stats
    expect(find.text('Báo giá'), findsWidgets);
    expect(find.text('Lượt xem'), findsOneWidget);
    expect(find.text('Đã mời'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Verify quote shown
    expect(find.text('An Thợ Ảnh'), findsOneWidget);
    expect(find.text('1,5M'), findsOneWidget);

    // Verify footer button has "So sánh 1 báo giá"
    expect(find.text('So sánh 1 báo giá'), findsOneWidget);
  });
}
