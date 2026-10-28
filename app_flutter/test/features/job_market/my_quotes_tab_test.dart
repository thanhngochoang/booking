// test/features/job_market/my_quotes_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/features/job_market/my_quotes_tab.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 20);

  Quote makeTestQuote({
    required String id,
    required String jobId,
    required String jobTitle,
    required QuoteStatus status,
    int price = 1500000,
    String? notSelectedReason,
    bool autoWithdrawn = false,
    String? bookingId,
  }) {
    return Quote(
      id: id,
      jobId: jobId,
      photographerId: 'p1',
      customerId: 'c1',
      jobTitle: jobTitle,
      photographer: const QuoteProvider(name: 'Thợ Ảnh 1', providerType: ProviderType.individual),
      terms: QuoteTerms(
        price: price,
        durationMinutes: 120,
        editedCount: 30,
        deliveryDays: 3,
        revisions: 1,
      ),
      milestoneAmounts: const QuoteMilestoneAmounts(shoot: 750000, delivery: 750000),
      proposal: const QuoteProposal(day: '2026-10-25', start: '09:00', end: '11:00'),
      message: 'Lời nhắn gửi khách hàng dài đủ số ký tự.',
      status: status,
      notSelectedReason: notSelectedReason,
      autoWithdrawn: autoWithdrawn,
      bookingId: bookingId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget buildTestWidget({required FakeJobRepository repo}) {
    final router = GoRouter(
      initialLocation: '/quotes',
      routes: [
        GoRoute(
          path: '/quotes',
          builder: (_, _) => const Scaffold(body: MyQuotesTab()),
        ),
        GoRoute(
          path: '/jobs/:id',
          builder: (_, state) => Scaffold(body: Text('JobScreen ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/b/:id',
          builder: (_, state) => Scaffold(body: Text('BookingScreen ${state.pathParameters['id']}')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(uid: 'p1'))),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('quotes are grouped Đang chờ / Được chọn / Không được chọn / Đã rút', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);

    final qPending = makeTestQuote(
      id: 'q1',
      jobId: 'j1',
      jobTitle: 'Việc Đang Chờ',
      status: QuoteStatus.submitted,
    );
    final qChosen = makeTestQuote(
      id: 'q2',
      jobId: 'j2',
      jobTitle: 'Việc Được Chọn',
      status: QuoteStatus.accepted,
      bookingId: 'b_123',
    );
    final qNotChosen = makeTestQuote(
      id: 'q3',
      jobId: 'j3',
      jobTitle: 'Việc Không Được Chọn',
      status: QuoteStatus.notSelected,
    );
    final qWithdrawn = makeTestQuote(
      id: 'q4',
      jobId: 'j4',
      jobTitle: 'Việc Đã Rút',
      status: QuoteStatus.withdrawn,
    );

    repo.myQuotesList = [qPending, qChosen, qNotChosen, qWithdrawn];

    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ'), findsOneWidget);
    expect(find.text('Việc Đang Chờ'), findsOneWidget);

    expect(find.text('Được chọn'), findsOneWidget);
    expect(find.text('Việc Được Chọn'), findsOneWidget);

    expect(find.text('Không được chọn'), findsOneWidget);
    expect(find.text('Việc Không Được Chọn'), findsOneWidget);

    expect(find.text('Đã rút'), findsOneWidget);
    expect(find.text('Việc Đã Rút'), findsOneWidget);
  });

  testWidgets('an auto-withdrawn quote says Tự rút · bạn đã kín lịch ngày này', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);

    final qAuto = makeTestQuote(
      id: 'q_auto',
      jobId: 'j_auto',
      jobTitle: 'Việc Tự Rút',
      status: QuoteStatus.withdrawn,
      autoWithdrawn: true,
      notSelectedReason: 'day_taken',
    );
    repo.myQuotesList = [qAuto];

    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Tự rút · bạn đã kín lịch ngày này'), findsOneWidget);
  });

  testWidgets('a chosen quote opens /b/{bookingId}', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);

    final qChosen = makeTestQuote(
      id: 'q_chosen',
      jobId: 'j_chosen',
      jobTitle: 'Việc Thành Booking',
      status: QuoteStatus.accepted,
      bookingId: 'b_456',
    );
    repo.myQuotesList = [qChosen];

    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Việc Thành Booking'));
    await tester.pumpAndSettle();

    expect(find.text('BookingScreen b_456'), findsOneWidget);
  });

  testWidgets('others open /jobs/{id}', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);

    final qPending = makeTestQuote(
      id: 'q_pend',
      jobId: 'j_pend',
      jobTitle: 'Việc Chờ Mở Job',
      status: QuoteStatus.submitted,
    );
    repo.myQuotesList = [qPending];

    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Việc Chờ Mở Job'));
    await tester.pumpAndSettle();

    expect(find.text('JobScreen j_pend'), findsOneWidget);
  });

  testWidgets('empty state renders when no quotes', (tester) async {
    final repo = FakeJobRepository(currentUid: 'p1', clock: () => now);
    repo.myQuotesList = [];

    await tester.pumpWidget(buildTestWidget(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Bạn chưa gửi báo giá nào'), findsOneWidget);
  });
}
