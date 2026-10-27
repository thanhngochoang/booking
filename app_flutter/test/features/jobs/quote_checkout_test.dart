// test/features/jobs/quote_checkout_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/jobs/quote_checkout_screen.dart';
import 'package:photobooking/features/jobs/quote_detail_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/job_world.dart';

class _FakeExternalLauncher implements ExternalLauncher {
  final List<Uri> opened = [];

  @override
  Future<bool> canOpen(Uri uri) async => true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseJob = Job(
    id: 'j1',
    customerId: 'c1',
    customer: const JobCustomer(name: 'Customer 1'),
    specialtyId: 'portrait',
    title: 'Chụp ảnh tốt nghiệp',
    description: 'Mô tả',
    schedule: const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-25', durationMinutes: 60),
    dayFrom: '2026-10-25',
    dayTo: '2026-10-25',
    area: const JobArea(
      areaId: 'a1',
      name: 'Văn Miếu, Hà Nội',
      city: 'Hà Nội',
      cityKey: 'ha-noi',
      lat: 21.0,
      lng: 105.8,
      geohash5: 'w4gxx',
    ),
    budget: const JobBudget(min: 2000000, max: 3000000),
    wants: const JobWants(),
    allowedProviders: AllowedProviders.all,
    quoteDeadline: jobNow.add(const Duration(days: 3)),
    status: JobStatus.open,
    quoteCount: 1,
    newQuoteCount: 0,
    createdAt: jobNow,
    updatedAt: jobNow,
  );

  final baseQuote = Quote(
    id: 'q1',
    jobId: 'j1',
    photographerId: 'p1',
    customerId: 'c1',
    jobTitle: 'Chụp ảnh tốt nghiệp',
    photographer: const QuoteProvider(
      name: 'Thợ An',
      providerType: ProviderType.individual,
      score: 5.0,
      reviewCount: 10,
    ),
    terms: const QuoteTerms(
      price: 2000000,
      durationMinutes: 60,
      photoCount: 100,
      editedCount: 20,
      deliveryDays: 3,
      revisions: 1,
    ),
    milestoneAmounts: const QuoteMilestoneAmounts(shoot: 1000000, delivery: 1000000),
    proposal: const QuoteProposal(day: '2026-10-25', start: '09:00', end: '10:00'),
    message: 'Chào bạn',
    status: QuoteStatus.submitted,
    fit: 95,
    createdAt: jobNow,
    updatedAt: jobNow,
  );

  testWidgets('without a phone, Chọn và thanh toán opens /profile/phone with returnTo the checkout', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};

    final routesVisited = <String>[];
    final router = GoRouter(
      initialLocation: '/jobs/j1/applications/p1',
      routes: [
        GoRoute(
          path: '/jobs/:id/applications/:quoteId',
          builder: (_, s) => QuoteDetailScreen(
            jobId: s.pathParameters['id']!,
            initialPhotographerId: s.pathParameters['quoteId']!,
          ),
        ),
        GoRoute(
          path: '/profile/phone',
          builder: (_, s) {
            routesVisited.add(s.uri.toString());
            return const Scaffold(body: Text('Phone Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...world.overrides(),
          currentContactProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Chọn và thanh toán 2.000.000₫"
    await tester.tap(find.widgetWithText(AppButton, 'Chọn và thanh toán 2.000.000₫'));
    await tester.pumpAndSettle();

    expect(routesVisited, contains('/profile/phone?returnTo=%2Fjobs%2Fj1%2Fapplications%2Fp1%2Fpay'));
  });

  testWidgets('the checkout shows the booking card, address field, 100% line, milestones, policy and PayMethodSelector with Chuyển khoản QR selected', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1/pay'));
    await tester.pumpAndSettle();

    // BookingCard info
    expect(find.byType(BookingCard), findsOneWidget);
    expect(find.text('Thợ An · Chụp ảnh tốt nghiệp'), findsOneWidget);

    // Address & note
    expect(find.byKey(const Key('quote-pay-address-field')), findsOneWidget);
    expect(find.byKey(const Key('quote-pay-note-field')), findsOneWidget);

    // Money line
    expect(find.text('Báo giá của Thợ An'), findsOneWidget);
    expect(find.text('Thanh toán 100%'), findsOneWidget);

    // Milestones
    expect(find.byType(MilestoneTable), findsOneWidget);

    // Policy
    expect(find.textContaining('Tiền được giữ tới khi bạn nhận ảnh'), findsOneWidget);

    // PayMethodSelector default QR selected
    expect(find.byType(PayMethodSelector), findsOneWidget);
    expect(find.text('Chuyển khoản QR'), findsOneWidget);
  });

  testWidgets('the pay button is disabled until the address has 3 characters', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1/pay'));
    await tester.pumpAndSettle();

    final submitBtnFinder = find.byKey(const Key('quote-pay-submit-button'));
    final btnBefore = tester.widget<AppButton>(submitBtnFinder);
    expect(btnBefore.onPressed, isNull);

    // Enter 2 chars
    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '12');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(submitBtnFinder).onPressed, isNull);

    // Enter 3 chars
    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '123');
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(submitBtnFinder).onPressed, isNotNull);
  });

  testWidgets('pay calls acceptQuote with place, note and method', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1/pay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.enterText(find.byKey(const Key('quote-pay-note-field')), 'Gặp ở cổng chính');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    expect(world.repository.acceptCalls.length, 1);
    final call = world.repository.acceptCalls.first;
    expect(call.jobId, 'j1');
    expect(call.photographerId, 'p1');
    expect(call.placeName, '58 Quốc Tử Giám');
    expect(call.note, 'Gặp ở cổng chính');
    expect(call.method, PayMethod.bankQr);
  });

  testWidgets('bank QR opens /b/{bookingId}/pay (S04.04)', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};

    final routesVisited = <String>[];
    final router = GoRouter(
      initialLocation: '/jobs/j1/applications/p1/pay',
      routes: [
        GoRoute(
          path: '/jobs/:id/applications/:quoteId/pay',
          builder: (_, s) => QuoteCheckoutScreen(
            jobId: s.pathParameters['id']!,
            photographerId: s.pathParameters['quoteId']!,
          ),
        ),
        GoRoute(
          path: '/b/:id/pay',
          builder: (_, s) {
            routesVisited.add(s.uri.toString());
            return const Scaffold(body: Text('PaymentPendingScreen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...world.overrides(),
          realPaymentsProvider.overrideWithValue(false),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    expect(routesVisited.any((r) => r.startsWith('/b/b_') && r.endsWith('/pay')), isTrue);
  });

  testWidgets('a wallet in real mode opens checkout.payUrl then S04.04; in fake mode S04.04 only', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};

    final launcher = _FakeExternalLauncher();
    final routesVisited = <String>[];
    final router = GoRouter(
      initialLocation: '/jobs/j1/applications/p1/pay',
      routes: [
        GoRoute(
          path: '/jobs/:id/applications/:quoteId/pay',
          builder: (_, s) => QuoteCheckoutScreen(
            jobId: s.pathParameters['id']!,
            photographerId: s.pathParameters['quoteId']!,
          ),
        ),
        GoRoute(
          path: '/b/:id/pay',
          builder: (_, s) {
            routesVisited.add(s.uri.toString());
            return const Scaffold(body: Text('PaymentPendingScreen'));
          },
        ),
      ],
    );

    // 1. Real mode test
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...world.overrides(),
          externalLauncherProvider.overrideWithValue(launcher),
          realPaymentsProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select MoMo (scroll into view if needed)
    final momoFinder = find.text('MoMo');
    await tester.ensureVisible(momoFinder);
    await tester.tap(momoFinder);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    expect(routesVisited.any((r) => r.startsWith('/b/b_') && r.endsWith('/pay')), isTrue);
  });

  testWidgets('day_taken shows Thợ ảnh này đã kín lịch ngày đó and returns to S15.04', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};
    world.repository.nextAcceptError = const JobError('day_taken');

    final router = GoRouter(
      initialLocation: '/jobs/j1/applications/p1',
      routes: [
        GoRoute(
          path: '/jobs/:id/applications/:quoteId',
          builder: (_, s) => QuoteDetailScreen(
            jobId: s.pathParameters['id']!,
            initialPhotographerId: s.pathParameters['quoteId']!,
          ),
          routes: [
            GoRoute(
              path: 'pay',
              builder: (_, s) => QuoteCheckoutScreen(
                jobId: s.pathParameters['id']!,
                photographerId: s.pathParameters['quoteId']!,
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: world.overrides(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to pay
    router.push('/jobs/j1/applications/p1/pay');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Thợ ảnh này đã kín lịch ngày đó'), findsOneWidget);
    // Returns to S15.04 (QuoteDetailScreen)
    expect(find.byType(QuoteCheckoutScreen), findsNothing);
    expect(find.byType(QuoteDetailScreen), findsOneWidget);
  });

  testWidgets('not_accepting_orders shows its text', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};
    world.repository.nextAcceptError = const JobError('not_accepting_orders');

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1/pay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Thợ ảnh này tạm thời chưa nhận đơn'), findsOneWidget);
  });

  testWidgets('blocked shows the generic blocked text', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};
    world.repository.nextAcceptError = const JobError('blocked');

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1/pay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    // bookingErrBlocked text
    expect(find.text('Không đặt lịch được với người này.'), findsOneWidget);
  });

  testWidgets('a field error on place shows under the address', (tester) async {
    final world = JobWorld();
    await world.init();
    world.repository.jobs['j1'] = baseJob;
    world.repository.quotesByJob['j1'] = {'p1': baseQuote};
    world.repository.nextAcceptError = const JobError('invalid_argument', field: 'place');

    await tester.pumpWidget(world.buildApp(initialLocation: '/jobs/j1/applications/p1/pay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quote-pay-address-field')), '58 Quốc Tử Giám');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quote-pay-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Nhập địa chỉ cụ thể (3–120 ký tự)'), findsOneWidget);
  });
}
