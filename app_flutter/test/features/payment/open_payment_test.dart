import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_screen.dart';

import '../../support/screen_host.dart';

void main() {
  final exp = DateTime.utc(2026, 10, 13, 10, 0);

  PaymentInstructions inst({
    PayMethod method = PayMethod.bankQr,
    String? payUrl,
  }) =>
      PaymentInstructions(
        paymentId: 'p1',
        method: method,
        amount: 250000,
        expiresAt: exp,
        transferCode: 'PB 123456',
        payUrl: payUrl,
      );

  testWidgets('bank_qr pushes S04.04 with the instructions as extra', (
    tester,
  ) async {
    final launcher = FakeExternalLauncher();
    late BuildContext ctx;
    late WidgetRef ref;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Consumer(
            builder: (c2, r2, _) {
              ctx = c2;
              ref = r2;
              return const Text('Home');
            },
          ),
        ),
        GoRoute(
          path: '/b/:id/pay',
          builder: (c, s) => PaymentScreen(
            subject: BookingPay(s.pathParameters['id']!),
            initial: s.extra as PaymentInstructions?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          externalLauncherProvider.overrideWithValue(launcher),
          realPaymentsProvider.overrideWithValue(true),
        ],
      ),
    );

    await openPayment(
      ctx,
      ref,
      subject: const BookingPay('b1'),
      instructions: inst(method: PayMethod.bankQr, payUrl: 'https://pay.test/qr'),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/b/b1/pay');
    expect(launcher.opened, isEmpty);
  });

  testWidgets('a wallet with real payments opens payUrl then S04.04', (
    tester,
  ) async {
    final launcher = FakeExternalLauncher();
    late BuildContext ctx;
    late WidgetRef ref;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Consumer(
            builder: (c2, r2, _) {
              ctx = c2;
              ref = r2;
              return const Text('Home');
            },
          ),
        ),
        GoRoute(
          path: '/b/:id/pay',
          builder: (c, s) => PaymentScreen(
            subject: BookingPay(s.pathParameters['id']!),
            initial: s.extra as PaymentInstructions?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          externalLauncherProvider.overrideWithValue(launcher),
          realPaymentsProvider.overrideWithValue(true),
        ],
      ),
    );

    await openPayment(
      ctx,
      ref,
      subject: const BookingPay('b1'),
      instructions: inst(
        method: PayMethod.momo,
        payUrl: 'https://pay.test/momo',
      ),
    );
    await tester.pumpAndSettle();

    expect(launcher.opened.map((u) => u.toString()), ['https://pay.test/momo']);
    expect(router.state.uri.toString(), '/b/b1/pay');
  });

  testWidgets('a wallet in fake mode goes straight to S04.04', (tester) async {
    final launcher = FakeExternalLauncher();
    late BuildContext ctx;
    late WidgetRef ref;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Consumer(
            builder: (c2, r2, _) {
              ctx = c2;
              ref = r2;
              return const Text('Home');
            },
          ),
        ),
        GoRoute(
          path: '/b/:id/pay',
          builder: (c, s) => PaymentScreen(
            subject: BookingPay(s.pathParameters['id']!),
            initial: s.extra as PaymentInstructions?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          externalLauncherProvider.overrideWithValue(launcher),
          realPaymentsProvider.overrideWithValue(false),
        ],
      ),
    );

    await openPayment(
      ctx,
      ref,
      subject: const BookingPay('b1'),
      instructions: inst(
        method: PayMethod.momo,
        payUrl: 'https://pay.test/momo',
      ),
    );
    await tester.pumpAndSettle();

    expect(launcher.opened, isEmpty);
    expect(router.state.uri.toString(), '/b/b1/pay');
  });

  testWidgets('replace: true replaces the current route', (tester) async {
    final launcher = FakeExternalLauncher();
    late BuildContext ctx;
    late WidgetRef ref;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, _) => Consumer(
            builder: (c2, r2, _) {
              ctx = c2;
              ref = r2;
              return const Text('Home');
            },
          ),
        ),
        GoRoute(
          path: '/b/:id/pay',
          builder: (c, s) => PaymentScreen(
            subject: BookingPay(s.pathParameters['id']!),
            initial: s.extra as PaymentInstructions?,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          externalLauncherProvider.overrideWithValue(launcher),
          realPaymentsProvider.overrideWithValue(false),
        ],
      ),
    );

    await openPayment(
      ctx,
      ref,
      subject: const BookingPay('b1'),
      instructions: inst(method: PayMethod.bankQr),
      replace: true,
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/b/b1/pay');
  });
}
