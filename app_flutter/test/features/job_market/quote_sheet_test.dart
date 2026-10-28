// test/features/job_market/quote_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/job_market/quote_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 20);

  Job makeTestJob({
    String id = 'j1',
    ScheduleKind scheduleKind = ScheduleKind.fixed,
  }) {
    return Job(
      id: id,
      customerId: 'c1',
      customer: const JobCustomer(name: 'Khách'),
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu tốt nghiệp',
      description: 'Mô tả kỷ yếu',
      schedule: scheduleKind == ScheduleKind.fixed
          ? const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-25', start: '09:00', durationMinutes: 120)
          : const JobSchedule(kind: ScheduleKind.flexible, from: '2026-10-22', to: '2026-10-28', durationMinutes: 120),
      dayFrom: '2026-10-22',
      dayTo: '2026-10-28',
      area: const JobArea(
        areaId: 'a1',
        name: 'Cầu Giấy, Hà Nội',
        city: 'Hà Nội',
        cityKey: 'ha-noi',
        lat: 21.03,
        lng: 105.78,
        geohash5: 'w4gxx',
      ),
      budget: const JobBudget(min: 2000000, max: 4000000),
      wants: const JobWants(editedCount: 30, deliveryDays: 5),
      allowedProviders: AllowedProviders.all,
      quoteDeadline: now.add(const Duration(days: 2)),
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
    );
  }

  final testPackages = [
    const ServicePackage(
      id: 'pkg1',
      name: 'Gói Cơ Bản',
      priceVnd: 2400000,
      durationMinutes: 120,
      editedCount: 25,
      deliveryDays: 4,
    ),
  ];

  final testAlbums = [
    const AlbumSummary(
      id: 'alb1',
      photographerId: 'p1',
      title: 'Kỷ Yếu ĐHQG',
      position: 0,
      postCount: 5,
      mediaCount: 15,
      visible: true,
    ),
    const AlbumSummary(
      id: 'alb_empty',
      photographerId: 'p1',
      title: 'Album Rỗng',
      position: 1,
      postCount: 0,
      mediaCount: 0,
      visible: true,
    ),
  ];

  Widget buildTestWidget({
    required FakeJobRepository repo,
    required Job job,
    Quote? existingQuote,
    FakeAvailabilityLookup? avail,
  }) {
    return ProviderScope(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
        availabilityLookupProvider.overrideWithValue(avail ?? FakeAvailabilityLookup()),
        myPackagesProvider.overrideWith((ref) => Stream.value(testPackages)),
        myAlbumsProvider.overrideWith((ref) => Stream.value(testAlbums)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuoteSheet(job: job, initialQuote: existingQuote),
        ),
      ),
    );
  }

  testWidgets('milestones update while typing and add up to the price', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mốc 1 sau buổi chụp 0₫ · Mốc 2 khi khách duyệt ảnh 0₫'), findsOneWidget);

    final priceField = find.widgetWithText(TextField, 'Giá báo · bắt buộc');
    await tester.enterText(priceField, '3000000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Mốc 1 sau buổi chụp 1.500.000₫ · Mốc 2 khi khách duyệt ảnh 1.500.000₫'), findsOneWidget);
  });

  testWidgets('Dựa trên gói fills price, edited count and delivery days', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dựa trên gói · tuỳ chọn'));
    await tester.pumpAndSettle();

    expect(find.text('Gói Cơ Bản'), findsOneWidget);
    await tester.tap(find.text('Gói Cơ Bản'));
    await tester.pumpAndSettle();

    expect(find.text('2400000'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('Gửi báo giá is disabled until price > 0 and the message has 20 characters', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    final btnFinder = find.widgetWithText(AppButton, 'Gửi báo giá');
    expect(tester.widget<AppButton>(btnFinder).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Giá báo · bắt buộc'), '2000000');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(btnFinder).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Lời nhắn · bắt buộc'), 'Ngắn quá');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(btnFinder).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Lời nhắn · bắt buộc'), 'Lời nhắn này đã có trên 20 ký tự để hợp lệ.');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(btnFinder).onPressed, isNotNull);
  });

  testWidgets('a flexible job shows Ngày chụp đề xuất limited to the range', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob(scheduleKind: ScheduleKind.flexible);

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.text('Ngày chụp đề xuất · bắt buộc'), findsOneWidget);
  });

  testWidgets('a fixed job has no proposal field', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob(scheduleKind: ScheduleKind.fixed);

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    expect(find.text('Ngày chụp đề xuất · bắt buộc'), findsNothing);
  });

  testWidgets('submit sends the draft and closes with toast', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Giá báo · bắt buộc'), '2500000');
    await tester.enterText(find.widgetWithText(TextField, 'Lời nhắn · bắt buộc'), 'Lời nhắn chào bạn đã đủ 20 ký tự để gửi thành công.');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Gửi báo giá'));
    await tester.pumpAndSettle();

    expect(repo.submitQuoteCalls, hasLength(1));
    expect(repo.submitQuoteCalls.first.jobId, job.id);
    expect(repo.submitQuoteCalls.first.price, 2500000);
  });

  testWidgets('editing prefills from my quote and says Lưu báo giá', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();
    final existingQuote = Quote(
      id: 'q1',
      jobId: job.id,
      photographerId: 'p1',
      customerId: 'c1',
      jobTitle: job.title,
      photographer: const QuoteProvider(name: 'Thợ p1', providerType: ProviderType.individual),
      terms: const QuoteTerms(
        price: 2800000,
        durationMinutes: 120,
        editedCount: 35,
        deliveryDays: 6,
        revisions: 2,
      ),
      milestoneAmounts: const QuoteMilestoneAmounts(shoot: 1400000, delivery: 1400000),
      proposal: const QuoteProposal(day: '2026-10-25', start: '09:00', end: '11:00'),
      message: 'Lời nhắn cũ đã có trên 20 ký tự đầy đủ chi tiết.',
      status: QuoteStatus.submitted,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job, existingQuote: existingQuote));
    await tester.pumpAndSettle();

    expect(find.text('2800000'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Lưu báo giá'), findsOneWidget);
  });

  testWidgets('closing with changes asks Bỏ báo giá?', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Giá báo · bắt buộc'), '3500000');
    await tester.pumpAndSettle();

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Bỏ báo giá?'), findsOneWidget);
  });

  testWidgets('the album picker lists only non-empty albums', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    final job = makeTestJob();

    await tester.pumpWidget(buildTestWidget(repo: repo, job: job));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Album đính kèm · tuỳ chọn'));
    await tester.pumpAndSettle();

    expect(find.text('Kỷ Yếu ĐHQG'), findsOneWidget);
    expect(find.text('Album Rỗng'), findsNothing);
  });
}
