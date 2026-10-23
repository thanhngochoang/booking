// test/core/widgets/quote_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/quote_card.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import 'widget_host.dart';

void main() {
  final l = AppLocalizationsVi();
  final now = DateTime.utc(2026, 10, 18, 10, 0);

  Job makeJob({JobBudget? budget = const JobBudget(min: 3000000, max: 5000000)}) {
    return Job(
      id: 'job_1',
      customerId: 'cust_1',
      customer: const JobCustomer(name: 'Cust'),
      specialtyId: 'graduation',
      title: 'Job 1',
      description: 'Desc 1',
      schedule: const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60),
      dayFrom: '2026-10-20',
      dayTo: '2026-10-20',
      area: const JobArea(
        areaId: 'a1',
        name: 'Quận 1, TP.HCM',
        city: 'TP.HCM',
        cityKey: 'tphcm',
        lat: 10.7,
        lng: 106.7,
        geohash5: 'w4rqp',
      ),
      budget: budget,
      wants: const JobWants(),
      allowedProviders: AllowedProviders.all,
      quoteDeadline: now.add(const Duration(days: 3)),
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
    );
  }

  Quote makeQuote({
    int price = 4200000,
    bool invited = false,
    QuoteStatus status = QuoteStatus.submitted,
    int fit = 92,
  }) {
    return Quote(
      id: 'q1',
      jobId: 'job_1',
      photographerId: 'p1',
      customerId: 'cust_1',
      jobTitle: 'Job 1',
      photographer: const QuoteProvider(
        name: 'Lê Hoàng Vũ',
        providerType: ProviderType.artist,
        verified: true,
        tomatoPct: 97,
        completedCount: 64,
        approvedAwardCount: 7,
      ),
      terms: QuoteTerms(
        price: price,
        durationMinutes: 120,
        editedCount: 60,
        deliveryDays: 5,
        revisions: 2,
      ),
      milestoneAmounts: const QuoteMilestoneAmounts(shoot: 2100000, delivery: 2100000),
      proposal: const QuoteProposal(day: '2026-10-20', start: '08:00', end: '10:00'),
      message: 'Mình chụp kỷ yếu cho 6 lớp năm ngoái\nDòng 2 tin nhắn',
      invited: invited,
      fit: fit,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('QuoteCard rendering & mappers', () {
    testWidgets('price with in-budget note', (tester) async {
      final job = makeJob();
      final quote = makeQuote(price: 4200000);
      final data = quoteCardOf(quote, job, saved: false, now: now, l: l);

      await tester.pumpWidget(hostWidget(QuoteCard(data: data)));

      expect(find.text('4,2M'), findsOneWidget);
      expect(find.text('trong ngân sách'), findsOneWidget);
      expect(find.textContaining('Lê Hoàng Vũ'), findsOneWidget);
      expect(find.text('Hợp 92%'), findsOneWidget);
    });

    testWidgets('over budget shows vượt {amount} in text', (tester) async {
      final job = makeJob(); // budget max = 5M
      final quote = makeQuote(price: 5500000); // over 0,5M
      final data = quoteCardOf(quote, job, saved: false, now: now, l: l);

      await tester.pumpWidget(hostWidget(QuoteCard(data: data)));

      expect(find.text('5,5M'), findsOneWidget);
      expect(find.text('vượt 0,5M'), findsOneWidget);
    });

    testWidgets('invited tag', (tester) async {
      final job = makeJob();
      final quote = makeQuote(invited: true);
      final data = quoteCardOf(quote, job, saved: false, now: now, l: l);

      await tester.pumpWidget(hostWidget(QuoteCard(data: data)));

      expect(find.text('Được mời'), findsOneWidget);
    });

    testWidgets('withdrawn card is dimmed with Đã rút and no Xem', (tester) async {
      final job = makeJob();
      final quote = makeQuote(status: QuoteStatus.withdrawn);
      final data = quoteCardOf(quote, job, saved: false, now: now, l: l);

      await tester.pumpWidget(hostWidget(QuoteCard(data: data)));

      expect(find.text('Đã rút'), findsOneWidget);
      expect(find.text('Xem'), findsNothing);

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.6);
    });

    testWidgets('tapping Xem and the bookmark call back', (tester) async {
      final job = makeJob();
      final quote = makeQuote();
      final data = quoteCardOf(quote, job, saved: false, now: now, l: l);

      bool viewTapped = false;
      bool saveTapped = false;

      await tester.pumpWidget(
        hostWidget(
          QuoteCard(
            data: data,
            onView: () => viewTapped = true,
            onToggleSave: () => saveTapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Xem'));
      expect(viewTapped, isTrue);

      await tester.tap(find.byTooltip('Lưu báo giá'));
      expect(saveTapped, isTrue);
    });

    testWidgets('light and dark render without overflow at 320dp', (tester) async {
      final job = makeJob();
      final quote = makeQuote();
      final data = quoteCardOf(quote, job, saved: true, now: now, l: l);

      // Light
      await tester.pumpWidget(
        hostWidget(
          QuoteCard(data: data),
          width: 320,
          textScale: 1.3,
          brightness: Brightness.light,
        ),
      );
      expect(tester.takeException(), isNull);

      // Dark
      await tester.pumpWidget(
        hostWidget(
          QuoteCard(data: data),
          width: 320,
          textScale: 1.3,
          brightness: Brightness.dark,
        ),
      );
      expect(tester.takeException(), isNull);

      // Skeleton
      await tester.pumpWidget(
        hostWidget(
          QuoteCard.skeleton(),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
