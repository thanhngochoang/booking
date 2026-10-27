// test/features/jobs/quotes_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/features/jobs/invite_sheet.dart';

import '../../support/job_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseJob = Job(
    id: 'j1',
    customerId: 'c1',
    customer: const JobCustomer(name: 'Customer 1'),
    specialtyId: 'portrait',
    title: 'Chụp chân dung',
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
    quoteDeadline: jobNow.add(const Duration(days: 3)),
    status: JobStatus.open,
    quoteCount: 0,
    newQuoteCount: 3,
    createdAt: jobNow,
    updatedAt: jobNow,
  );

  Quote makeQuote({
    required String id,
    required String photographerId,
    required String name,
    required int price,
    int fit = 80,
    double score = 5.0,
    int reviewCount = 10,
    bool invited = false,
    QuoteStatus status = QuoteStatus.submitted,
    DateTime? withdrawnAt,
  }) {
    return Quote(
      id: id,
      jobId: 'j1',
      photographerId: photographerId,
      customerId: 'c1',
      jobTitle: 'Chụp chân dung',
      photographer: QuoteProvider(
        name: name,
        providerType: ProviderType.individual,
        score: score,
        reviewCount: reviewCount,
      ),
      terms: QuoteTerms(
        price: price,
        durationMinutes: 60,
        editedCount: 20,
        deliveryDays: 3,
        revisions: 1,
      ),
      milestoneAmounts: QuoteMilestoneAmounts(shoot: price ~/ 2, delivery: price - price ~/ 2),
      proposal: const QuoteProposal(day: '2026-10-25', start: '09:00', end: '10:00'),
      message: 'Xin chào',
      status: status,
      withdrawnAt: withdrawnAt,
      fit: fit,
      invited: invited,
      createdAt: jobNow,
      updatedAt: jobNow,
    );
  }

  testWidgets('header counts submitted quotes', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000, status: QuoteStatus.submitted),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Thợ 2', price: 1200000, status: QuoteStatus.submitted),
      'p3': makeQuote(id: 'q3', photographerId: 'p3', name: 'Thợ 3', price: 1500000, status: QuoteStatus.declined),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    expect(find.text('2 báo giá'), findsOneWidget);
  });

  testWidgets('opening the screen resets newQuoteCount once', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    expect(world.repository.markQuotesSeenCalls, contains('j1'));
    expect(world.repository.markQuotesSeenCalls.length, 1);
  });

  testWidgets('default sort is fit, invited first on ties', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ B (Not Invited)', price: 1000000, fit: 90, invited: false),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Thợ A (Invited)', price: 1500000, fit: 90, invited: true),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    final names = find.byType(QuoteCard).evaluate().map((el) {
      final widget = el.widget as QuoteCard;
      return widget.data.name;
    }).toList();

    expect(names, ['Thợ A (Invited)', 'Thợ B (Not Invited)']);
  });

  testWidgets('Giá thấp sorts by price', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Đắt', price: 3000000, fit: 99),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Rẻ', price: 1000000, fit: 80),
      'p3': makeQuote(id: 'q3', photographerId: 'p3', name: 'Vừa', price: 2000000, fit: 90),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giá thấp'));
    await tester.pumpAndSettle();

    final names = find.byType(QuoteCard).evaluate().map((el) {
      final widget = el.widget as QuoteCard;
      return widget.data.name;
    }).toList();

    expect(names, ['Rẻ', 'Vừa', 'Đắt']);
  });

  testWidgets('Đánh giá sorts by smoothed score then review count', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    // p1: 5.0 with 1 review => lower smoothed Bayesian score than 4.9 with 100 reviews
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1 review', price: 1000000, score: 5.0, reviewCount: 1),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Thợ 100 reviews', price: 1000000, score: 4.9, reviewCount: 100),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đánh giá'));
    await tester.pumpAndSettle();

    final names = find.byType(QuoteCard).evaluate().map((el) {
      final widget = el.widget as QuoteCard;
      return widget.data.name;
    }).toList();

    expect(names, ['Thợ 100 reviews', 'Thợ 1 review']);
  });

  testWidgets('Đã lưu shows only saved quotes, saved locally per job', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Thợ 2', price: 2000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    // Tap bookmark on Thợ 1
    final bookmarkBtn = find.byTooltip('Lưu báo giá').first;
    await tester.tap(bookmarkBtn);
    await tester.pumpAndSettle();

    // Tap "Đã lưu" chip
    await tester.tap(find.text('Đã lưu'));
    await tester.pumpAndSettle();

    expect(find.text('Thợ 1'), findsOneWidget);
    expect(find.text('Thợ 2'), findsNothing);
  });

  testWidgets('a withdrawn quote shows dimmed for 24 hours then disappears', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    // Withdrawn 12 hours ago
    final withdrawnRecent = jobNow.subtract(const Duration(hours: 12));
    // Withdrawn 25 hours ago
    final withdrawnOld = jobNow.subtract(const Duration(hours: 25));

    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Withdrawn Recent', price: 1000000, status: QuoteStatus.withdrawn, withdrawnAt: withdrawnRecent),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Withdrawn Old', price: 1000000, status: QuoteStatus.withdrawn, withdrawnAt: withdrawnOld),
      'p3': makeQuote(id: 'q3', photographerId: 'p3', name: 'Active', price: 1000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Withdrawn Recent'), findsOneWidget);
    expect(find.text('Withdrawn Old'), findsNothing);
  });

  testWidgets('declined quotes are not listed', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Active', price: 1000000),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Declined', price: 1000000, status: QuoteStatus.declined),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Declined'), findsNothing);
  });

  testWidgets('tapping Xem opens /jobs/{id}/applications/{pid}', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ Xem', price: 1000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xem'));
    await tester.pumpAndSettle();

    // Should navigate to quote detail
    expect(find.byType(QuoteCard), findsNothing);
    expect(find.text('Báo giá 1 / 1'), findsOneWidget);
  });

  testWidgets('empty state invites photographers', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {};

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications'));
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ báo giá đầu tiên'), findsOneWidget);
    expect(find.text('Mời thợ ảnh báo giá'), findsOneWidget);

    await tester.tap(find.text('Mời thợ ảnh báo giá'));
    await tester.pumpAndSettle();

    // Invite sheet opens
    expect(find.byType(InviteSheet), findsOneWidget);
  });
}
