import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/features/help/help_faq.dart';
import 'package:photobooking/features/help/help_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/dispute_world.dart';
import '../../support/fake_dispute_repository.dart';
import '../../support/screen_host.dart';

class _FakeExternalLauncher implements ExternalLauncher {
  Uri? lastOpened;
  @override
  Future<bool> canOpen(Uri uri) async => true;
  @override
  Future<bool> open(Uri uri) async {
    lastOpened = uri;
    return true;
  }
}

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  FakeDisputeRepository? disputes,
}) {
  return ProviderScope(
    overrides: [
      // No disputes unless a test says otherwise.
      disputeRepositoryProvider.overrideWithValue(
        disputes ?? FakeDisputeRepository(),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('help without disputes shows no "Khiếu nại của bạn" section', (
    tester,
  ) async {
    final disputes = FakeDisputeRepository();
    await tester.pumpWidget(_wrap(const HelpScreen(), disputes: disputes));
    await tester.pumpAndSettle();

    // The list was read and came back empty: no section.
    expect(disputes.mineCalls, 1);
    expect(find.text('Khiếu nại của bạn'), findsNothing);
    expect(find.byKey(const Key('help-dispute-01JDZ8Y3VQK7Q2')), findsNothing);
    expect(find.text('Câu hỏi thường gặp'), findsOneWidget);
  });

  testWidgets(
    'topic chips switch the questions; the first topic is Thanh toán',
    (tester) async {
      await tester.pumpWidget(_wrap(const HelpScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vì sao phải trả trước 100%?'), findsOneWidget);

      // Switch to Huỷ & hoàn tiền
      await tester.tap(find.byKey(const Key('topic-chip-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Huỷ buổi chụp được hoàn bao nhiêu?'), findsOneWidget);
      expect(find.text('Vì sao phải trả trước 100%?'), findsNothing);
    },
  );

  testWidgets('a question expands to its exact answer and collapses again', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const HelpScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền không đến tay thợ ngay'), findsNothing);

    // Tap the question to expand
    await tester.tap(find.text('Vì sao phải trả trước 100%?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền không đến tay thợ ngay'), findsOneWidget);

    // Tap again to collapse
    await tester.tap(find.text('Vì sao phải trả trước 100%?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền không đến tay thợ ngay'), findsNothing);
  });

  testWidgets('every FAQ key has a non-empty question and answer', (
    tester,
  ) async {
    late AppLocalizations localizations;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            localizations = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topics = faqTopics(localizations);
    expect(topics.isNotEmpty, isTrue);

    for (final topic in topics) {
      expect(topic.id.isNotEmpty, isTrue);
      expect(topic.label.isNotEmpty, isTrue);
      expect(topic.items.isNotEmpty, isTrue);
      for (final item in topic.items) {
        expect(item.question.trim().isNotEmpty, isTrue);
        expect(item.answer.trim().isNotEmpty, isTrue);
      }
    }
  });

  testWidgets(
    'the email line is hidden when supportEmail is null and opens mailto when set',
    (tester) async {
      // 1. When supportEmail is null -> line is hidden
      await tester.pumpWidget(
        _wrap(
          const HelpScreen(),
          overrides: [supportEmailProvider.overrideWithValue(null)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('help-support-email')), findsNothing);

      // 2. When supportEmail is set -> line is shown and opens mailto
      // A new scope: Riverpod refuses a changed number of overrides.
      await tester.pumpWidget(const SizedBox());
      final fakeLauncher = _FakeExternalLauncher();
      await tester.pumpWidget(
        _wrap(
          const HelpScreen(),
          overrides: [
            supportEmailProvider.overrideWithValue('support@example.com'),
            externalLauncherProvider.overrideWithValue(fakeLauncher),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('help-support-email')), findsOneWidget);
      expect(find.text('Email hỗ trợ: support@example.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('help-support-email')));
      await tester.pumpAndSettle();

      expect(fakeLauncher.lastOpened?.scheme, 'mailto');
      expect(fakeLauncher.lastOpened?.path, 'support@example.com');
    },
  );

  testWidgets('help fits 320dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          disputeRepositoryProvider.overrideWithValue(
            FakeDisputeRepository(disputes: [fixtureDispute('01JDZ8Y3VQK7Q2')]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: HelpScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('help shows "Khiếu nại của bạn" with "Khiếu nại #K7Q2 · Minh '
      'Trí" / "Đang xem xét · 14/10" only when the user has disputes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const HelpScreen(),
        disputes: FakeDisputeRepository(
          disputes: [
            fixtureDispute(
              '01JDZ8Y3VQK7Q2',
              // 10:12 on 14/10 in Vietnam.
              createdAt: DateTime.utc(2026, 10, 14, 3, 12),
            ),
            fixtureDispute(
              '01JDZ8Y3VQAB9X',
              status: DisputeStatus.resolved,
              createdAt: DateTime.utc(2026, 10, 2, 3),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Khiếu nại của bạn'), findsOneWidget);
    expect(find.text('Khiếu nại #K7Q2 · Minh Trí'), findsOneWidget);
    expect(find.text('Đang xem xét · 14/10'), findsOneWidget);
    expect(find.text('Khiếu nại #AB9X · Minh Trí'), findsOneWidget);
    expect(find.text('Đã xử lý · 02/10'), findsOneWidget);
    // The section comes before the FAQ (mock S18.03).
    expect(
      tester.getTopLeft(find.text('Khiếu nại của bạn')).dy,
      lessThan(tester.getTopLeft(find.text('Câu hỏi thường gặp')).dy),
    );
  });

  testWidgets('a failing disputes read leaves the help screen usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const HelpScreen(),
        disputes: FakeDisputeRepository()..mineError = Exception('unavailable'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Khiếu nại của bạn'), findsNothing);
    expect(find.text('Câu hỏi thường gặp'), findsOneWidget);
  });

  testWidgets('tapping a dispute row pushes /disputes/:id', (tester) async {
    final router = GoRouter(
      initialLocation: '/help',
      routes: [
        GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
        GoRoute(
          path: '/disputes/:id',
          builder: (_, s) =>
              Scaffold(body: Text('dispute ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          disputeRepositoryProvider.overrideWithValue(
            FakeDisputeRepository(disputes: [fixtureDispute('01JDZ8Y3VQK7Q2')]),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Khiếu nại #K7Q2 · Minh Trí'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('dispute 01JDZ8Y3VQK7Q2'), findsOneWidget);
  });

  testWidgets('the provider\'s row shows the booking\'s date and slot instead '
      'of their own name', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HelpScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(initialUser: const AuthUser(uid: 'p1')),
          ),
        ],
        disputes: FakeDisputeRepository(
          uid: 'p1',
          disputes: [fixtureDispute('01JDZ8Y3VQK7Q2')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Khiếu nại #K7Q2 · T2 19/10 · 15:30–17:30'),
      findsOneWidget,
    );
    expect(find.text('Khiếu nại #K7Q2 · Minh Trí · Chân dung'), findsNothing);
  });
}
