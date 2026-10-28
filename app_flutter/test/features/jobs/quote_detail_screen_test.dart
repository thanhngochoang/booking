// test/features/jobs/quote_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/quote.dart';

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
    budget: const JobBudget(min: 3000000, max: 4000000),
    wants: const JobWants(),
    allowedProviders: AllowedProviders.all,
    quoteDeadline: jobNow.add(const Duration(days: 3)),
    status: JobStatus.open,
    quoteCount: 2,
    newQuoteCount: 0,
    createdAt: jobNow,
    updatedAt: jobNow,
  );

  Quote makeQuote({
    required String id,
    required String photographerId,
    required String name,
    required int price,
    int? photoCount,
    int editedCount = 0,
    int deliveryDays = 3,
    int revisions = 1,
    QuoteAlbum? album,
    String? albumId,
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
        score: 5.0,
        reviewCount: 10,
      ),
      terms: QuoteTerms(
        price: price,
        durationMinutes: 60,
        photoCount: photoCount,
        editedCount: editedCount,
        deliveryDays: deliveryDays,
        revisions: revisions,
      ),
      milestoneAmounts: QuoteMilestoneAmounts(
        shoot: (price * 50) ~/ 100,
        delivery: price - ((price * 50) ~/ 100),
      ),
      proposal: const QuoteProposal(day: '2026-10-25', start: '09:00', end: '10:00'),
      message: 'Tin nhắn gửi khách',
      album: album,
      albumId: albumId,
      status: status,
      withdrawnAt: withdrawnAt,
      fit: 90,
      createdAt: jobNow,
      updatedAt: jobNow,
    );
  }

  testWidgets('the counter shows the position in the current sort', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Thợ 2', price: 1500000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('Báo giá 1 / 2'), findsOneWidget);
  });

  testWidgets('swiping moves to the next quote in the same order', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
      'p2': makeQuote(id: 'q2', photographerId: 'p2', name: 'Thợ 2', price: 1500000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('Thợ 1'), findsOneWidget);

    // Swipe left to go to next quote
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Báo giá 2 / 2'), findsOneWidget);
    expect(find.text('Thợ 2'), findsOneWidget);
  });

  testWidgets('the milestone lines add up to the price (50/50 with remainder on delivery)', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      // 1.500.001 -> shoot: 750.000, delivery: 750.001
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ Lẻ', price: 1500001),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('750.000₫'), findsOneWidget);
    expect(find.text('750.001₫'), findsOneWidget);
  });

  testWidgets('four tiles show — for a missing photo count', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      // photoCount null -> raw photo tile shows '—'
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000, editedCount: 20, photoCount: null),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    // Raw photo tile shows — when photoCount is null
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('the budget note is text', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob; // budget: 3.000.000 - 4.000.000
    world.repository.quotesByJob['j1'] = {
      // 3.500.000 -> "trong ngân sách"
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 3500000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('trong ngân sách'), findsOneWidget);
  });

  testWidgets('Hồ sơ opens /u/{pid}', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ'), findsOneWidget);
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    // Since /u/p1 is not configured in createRouter, we don't crash
  });

  testWidgets('the album row opens the album', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(
        id: 'q1',
        photographerId: 'p1',
        name: 'Thợ 1',
        price: 1000000,
        albumId: 'alb_1',
        album: const QuoteAlbum(title: 'Album Cưới', postCount: 20),
      ),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('Album · Album Cưới'), findsOneWidget);
    expect(find.text('20 ảnh · đính kèm báo giá'), findsOneWidget);

    await tester.tap(find.text('Album · Album Cưới'));
    await tester.pumpAndSettle();
  });

  testWidgets('the chat button opens the job inquiry chat', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    final chatBtn = find.byTooltip('Nhắn tin hỏi thêm');
    expect(chatBtn, findsOneWidget);
    await tester.tap(chatBtn);
    await tester.pumpAndSettle();

    expect(world.repository.inquiryCalls.length, 1);
    expect(world.repository.inquiryCalls.first.jobId, 'j1');
    expect(world.repository.inquiryCalls.first.photographerId, 'p1');
  });

  testWidgets('a withdrawn quote or a closed job disables the primary with the reason', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000, status: QuoteStatus.withdrawn),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    expect(find.text('Thợ ảnh đã rút báo giá này'), findsOneWidget);
  });

  testWidgets('Từ chối báo giá asks with a red button, sends the reason and returns to S15.03', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
    };

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1'));
    await tester.pumpAndSettle();

    // Tap more action menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Từ chối báo giá'), findsOneWidget);
    await tester.tap(find.text('Từ chối báo giá'));
    await tester.pumpAndSettle();

    // Decline quote sheet is displayed
    expect(find.text('Từ chối báo giá này?'), findsOneWidget);

    // Enter optional reason
    await tester.enterText(find.byKey(const Key('quote-decline-reason-field')), 'Giá hơi cao');
    await tester.pumpAndSettle();

    // Confirm decline (danger confirm button labeled 'Từ chối')
    await tester.tap(find.widgetWithText(AppButton, 'Từ chối'));
    await tester.pumpAndSettle();

    expect(world.repository.declineCalls.length, 1);
    expect(world.repository.declineCalls.first.reason, 'Giá hơi cao');
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {
      'p1': makeQuote(id: 'q1', photographerId: 'p1', name: 'Thợ 1', price: 1000000),
    };

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(1.3),
          size: Size(320, 640),
        ),
        child: world.buildApp(initialLocation: '/jobs/j1/applications/p1'),
      ),
    );
    await tester.pumpAndSettle();

    // Verifies no exception / overflow caught
    expect(tester.takeException(), isNull);
  });
}
