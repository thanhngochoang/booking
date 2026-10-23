// test/core/widgets/job_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/job_card.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import 'widget_host.dart';

void main() {
  final l = AppLocalizationsVi();
  final now = DateTime.utc(2026, 10, 18, 10, 0);

  Job makeJob({
    required String id,
    JobStatus status = JobStatus.open,
    String title = 'Kỷ yếu lớp 12A1',
    String description = 'Mô tả công việc không có thông tin liên lạc 0901234567 hay 123 Lê Lợi',
    DateTime? quoteDeadline,
    AllowedProviders allowedProviders = AllowedProviders.all,
    JobBudget? budget = const JobBudget(min: 3000000, max: 5000000),
    int quoteCount = 5,
    int newQuoteCount = 3,
    AwardedTo? awardedTo,
  }) {
    return Job(
      id: id,
      customerId: 'cust_1',
      customer: const JobCustomer(name: 'Cust'),
      specialtyId: 'graduation',
      title: title,
      description: description,
      schedule: const JobSchedule(
        kind: ScheduleKind.fixed,
        day: '2026-10-20',
        start: '07:00',
        durationMinutes: 240,
      ),
      dayFrom: '2026-10-20',
      dayTo: '2026-10-20',
      area: const JobArea(
        areaId: 'a1',
        name: 'Quận 1, TP.HCM',
        city: 'TP.HCM',
        cityKey: 'tphcm',
        lat: 10.7769,
        lng: 106.7009,
        geohash5: 'w4rqp',
      ),
      budget: budget,
      wants: const JobWants(),
      allowedProviders: allowedProviders,
      quoteDeadline: quoteDeadline ?? now.add(const Duration(days: 2)),
      status: status,
      quoteCount: quoteCount,
      newQuoteCount: newQuoteCount,
      awardedTo: awardedTo,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
    );
  }

  group('JobCard rendering', () {
    testWidgets('customer open card shows status, quotes and new count, and time left', (tester) async {
      final job = makeJob(id: 'j1');
      final data = customerJobCardOf(job, now, l);

      await tester.pumpWidget(
        hostWidget(JobCard(data: data, variant: JobCardVariant.customer)),
      );

      expect(find.text('Kỷ yếu'), findsOneWidget);
      expect(find.text('ĐANG NHẬN BÁO GIÁ'), findsOneWidget);
      expect(find.text('Kỷ yếu lớp 12A1'), findsOneWidget);
      expect(find.text('5 báo giá · 3 mới'), findsOneWidget);
      expect(find.text('còn 2 ngày'), findsOneWidget);
    });

    testWidgets('customer awarded card shows the link', (tester) async {
      final job = makeJob(
        id: 'j2',
        status: JobStatus.awarded,
        awardedTo: const AwardedTo(
          photographerId: 'p1',
          name: 'Studio Mây',
          price: 2800000,
        ),
      );
      bool linkTapped = false;
      final data = customerJobCardOf(job, now, l, onLinkTap: () => linkTapped = true);

      await tester.pumpWidget(
        hostWidget(JobCard(data: data, variant: JobCardVariant.customer)),
      );

      expect(find.text('ĐÃ CHỌN THỢ'), findsOneWidget);
      expect(find.text('Mở buổi chụp →'), findsOneWidget);

      await tester.tap(find.text('Mở buổi chụp →'));
      expect(linkTapped, isTrue);
    });

    testWidgets('customer expired card is dimmed with Đăng lại', (tester) async {
      final job = makeJob(id: 'j3', status: JobStatus.expired, quoteCount: 4);
      bool repostTapped = false;
      final data = customerJobCardOf(job, now, l, onLinkTap: () => repostTapped = true);

      await tester.pumpWidget(
        hostWidget(JobCard(data: data, variant: JobCardVariant.customer)),
      );

      expect(find.text('HẾT HẠN'), findsOneWidget);
      expect(find.text('Hết hạn · 4 báo giá · chưa chọn ai'), findsOneWidget);
      expect(find.text('Đăng lại'), findsOneWidget);

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.75);

      await tester.tap(find.text('Đăng lại'));
      expect(repostTapped, isTrue);
    });

    testWidgets('photographer card puts the invited tag first and shows the fit', (tester) async {
      final job = makeJob(id: 'j4');
      final me = const PhotographerSummary(
        id: 'p1',
        displayName: 'Minh Trí',
        lat: 10.78,
        lng: 106.71,
      );
      final item = OpenJobItem(job: job, fit: 92, invited: true);
      final data = photographerJobCardOf(item, me, now, l);

      await tester.pumpWidget(
        hostWidget(JobCard(data: data, variant: JobCardVariant.photographer)),
      );

      expect(find.text('Kỷ yếu'), findsOneWidget);
      expect(find.text('Bạn được mời'), findsOneWidget);
      expect(find.text('Hợp 92%'), findsOneWidget);
      expect(find.text('3–5M'), findsOneWidget);
      expect(find.text('5 báo giá · còn 2 ngày'), findsOneWidget);
    });

    testWidgets('a locked card shows the artist tag and the lock line, no fit', (tester) async {
      final job = makeJob(
        id: 'j5',
        allowedProviders: AllowedProviders.artist,
      );
      final me = const PhotographerSummary(
        id: 'p1',
        displayName: 'Minh Trí',
        providerType: ProviderType.individual,
        approvedAwardCount: 2,
      );
      final item = OpenJobItem(job: job, fit: 80, locked: true);
      final data = photographerJobCardOf(item, me, now, l);

      await tester.pumpWidget(
        hostWidget(JobCard(data: data, variant: JobCardVariant.photographer)),
      );

      expect(find.text('Chỉ Nhiếp ảnh gia'), findsOneWidget);
      expect(find.text('Hợp 80%'), findsNothing);
      expect(find.text('Chỉ NAG báo giá được · bạn còn 1 giải đã duyệt nữa'), findsOneWidget);

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.7);
    });

    testWidgets('no card ever renders a phone or street address', (tester) async {
      final job = makeJob(
        id: 'j6',
        description: 'Số 123 Lê Lợi, SĐT: 0901234567',
      );
      final dataCust = customerJobCardOf(job, now, l);
      await tester.pumpWidget(
        hostWidget(JobCard(data: dataCust, variant: JobCardVariant.customer)),
      );

      expect(find.textContaining('0901234567'), findsNothing);
      expect(find.textContaining('Lê Lợi'), findsNothing);

      final me = const PhotographerSummary(id: 'p1', displayName: 'Minh Trí');
      final dataPhoto = photographerJobCardOf(OpenJobItem(job: job), me, now, l);
      await tester.pumpWidget(
        hostWidget(JobCard(data: dataPhoto, variant: JobCardVariant.photographer)),
      );

      expect(find.textContaining('0901234567'), findsNothing);
      expect(find.textContaining('Lê Lợi'), findsNothing);
    });

    testWidgets('light and dark render without overflow at 320dp', (tester) async {
      final job = makeJob(id: 'j7');
      final data = customerJobCardOf(job, now, l);

      // Light
      await tester.pumpWidget(
        hostWidget(
          JobCard(data: data, variant: JobCardVariant.customer),
          width: 320,
          textScale: 1.3,
          brightness: Brightness.light,
        ),
      );
      var err = tester.takeException();
      if (err != null) {
        // no error
      }
      expect(err, isNull);

      // Dark
      await tester.pumpWidget(
        hostWidget(
          JobCard(data: data, variant: JobCardVariant.customer),
          width: 320,
          textScale: 1.3,
          brightness: Brightness.dark,
        ),
      );
      err = tester.takeException();
      if (err != null) {
        // no error
      }
      expect(err, isNull);

      // Skeleton
      await tester.pumpWidget(
        hostWidget(
          JobCard.skeleton(variant: JobCardVariant.customer),
          width: 320,
        ),
      );
      err = tester.takeException();
      if (err != null) {
        // no error
      }
      expect(err, isNull);
    });

    test('customerJobCardOf picks the right status label', () {
      final openJob = makeJob(id: '1', status: JobStatus.open);
      expect(customerJobCardOf(openJob, now, l).statusLabel, 'Đang nhận báo giá');

      final awardedJob = makeJob(
        id: '2',
        status: JobStatus.awarded,
        awardedTo: const AwardedTo(photographerId: 'p1', name: 'NAG', price: 1000000),
      );
      expect(customerJobCardOf(awardedJob, now, l).statusLabel, 'Đã chọn thợ');

      final closedJob = makeJob(id: '3', status: JobStatus.closed);
      expect(customerJobCardOf(closedJob, now, l).statusLabel, 'Đã đóng');

      final expiredJob = makeJob(id: '4', status: JobStatus.expired);
      expect(customerJobCardOf(expiredJob, now, l).statusLabel, 'Hết hạn');
    });

    test('photographerJobCardOf locks artist-only for an individual with k = 3 − approved awards', () {
      final job = makeJob(id: '5', allowedProviders: AllowedProviders.artist);
      final me = const PhotographerSummary(
        id: 'p1',
        displayName: 'Test',
        providerType: ProviderType.individual,
        approvedAwardCount: 1,
      );

      final data = photographerJobCardOf(OpenJobItem(job: job), me, now, l);
      expect(data.locked, isTrue);
      expect(data.lockLabel, 'Chỉ NAG báo giá được · bạn còn 2 giải đã duyệt nữa');
    });
  });
}
