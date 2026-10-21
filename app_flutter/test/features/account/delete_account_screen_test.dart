import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/features/account/delete_account_screen.dart';

import '../../support/fake_account_repository.dart';
import '../../support/profile_world.dart';
import '../../support/screen_host.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

GoRouter _router({required Widget screen, List<String>? visited}) {
  return GoRouter(
    initialLocation: '/delete',
    routes: [
      GoRoute(
        path: '/delete',
        builder: (_, _) => screen,
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) {
          visited?.add('/login');
          return const Scaffold(body: Text('login-screen'));
        },
      ),
      GoRoute(
        path: '/b/:id',
        builder: (_, s) {
          visited?.add('/b/${s.pathParameters['id']}');
          return const Scaffold(body: Text('booking-screen'));
        },
      ),
      GoRoute(
        path: '/me/payments',
        builder: (_, _) {
          visited?.add('/me/payments');
          return const Scaffold(body: Text('payments-screen'));
        },
      ),
      GoRoute(
        path: '/work/earnings',
        builder: (_, _) {
          visited?.add('/work/earnings');
          return const Scaffold(body: Text('earnings-screen'));
        },
      ),
      GoRoute(
        path: '/instant/:id',
        builder: (_, s) {
          visited?.add('/instant/${s.pathParameters['id']}');
          return const Scaffold(body: Text('instant-screen'));
        },
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, _) {
          visited?.add('/settings/privacy');
          return const Scaffold(body: Text('privacy-screen'));
        },
      ),
    ],
  );
}

void main() {
  group('DeleteAccountScreen', () {
    testWidgets('lists blockers and opens links', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');

      final fakeAccount = FakeAccountRepository(
        blockers: [
          const DeletionBlocker(
            kind: BlockerKind.openBooking,
            count: 1,
            first: (id: 'b1', title: 'Minh Trí', day: 'T7 12/10', eventId: null),
          ),
          const DeletionBlocker(
            kind: BlockerKind.refundInProgress,
            count: 1,
            amount: 500000,
          ),
          const DeletionBlocker(
            kind: BlockerKind.unpaidEarnings,
            count: 1,
            amount: 1500000,
          ),
          const DeletionBlocker(
            kind: BlockerKind.activeInstant,
            count: 1,
            first: (id: 'inst1', title: 'Chụp tại Quận 1', day: null, eventId: null),
          ),
        ],
      );

      final opened = <String>[];
      final router = _router(screen: const DeleteAccountScreen(), visited: opened);
      await tester.pumpWidget(
        screenRouterApp(
          router: router,
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 buổi chụp chưa xong'), findsOneWidget);
      expect(find.text('Minh Trí · T7 12/10'), findsOneWidget);
      expect(find.text('500.000₫ đang hoàn'), findsOneWidget);
      expect(find.text('1.500.000₫ chờ chi trả'), findsOneWidget);
      expect(find.text('1 yêu cầu Chụp ngay chưa xong'), findsOneWidget);
      expect(find.text('Chụp tại Quận 1'), findsOneWidget);

      // Tap on booking blocker
      await tester.tap(find.text('1 buổi chụp chưa xong'));
      await tester.pumpAndSettle();
      expect(opened.contains('/b/b1'), isTrue);

      // Go back to /delete
      router.go('/delete');
      await tester.pumpAndSettle();

      // Tap on refund blocker
      await tester.tap(find.text('500.000₫ đang hoàn'));
      await tester.pumpAndSettle();
      expect(opened.contains('/me/payments'), isTrue);

      // Go back to /delete
      router.go('/delete');
      await tester.pumpAndSettle();

      // With blockers, "Xoá tài khoản" button is disabled
      await tester.scrollUntilVisible(find.byKey(const Key('delete-account-button')), 100);
      final btn = tester.widget<AppButton>(find.byKey(const Key('delete-account-button')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('without blockers opens confirmation sheet and calls requestDeletion', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');

      final fakeAccount = FakeAccountRepository(
        blockers: [],
        restoreUntil: DateTime(2026, 11, 6),
      );

      final routes = <String>[];
      final router = _router(screen: const DeleteAccountScreen(), visited: routes);
      await tester.pumpWidget(
        screenRouterApp(
          router: router,
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // No blockers shows export hint
      expect(find.text('Muốn giữ dữ liệu? Tải bản sao trước khi xoá.'), findsOneWidget);
      await tester.tap(find.text('Tải bản sao dữ liệu'));
      await tester.pumpAndSettle();
      expect(routes.contains('/settings/privacy'), isTrue);

      // Go back to /delete
      router.go('/delete');
      await tester.pumpAndSettle();

      // Enabled "Xoá tài khoản" button
      final btn = tester.widget<AppButton>(find.byKey(const Key('delete-account-button')));
      expect(btn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      // Confirmation sheet
      expect(find.text('Xoá tài khoản?'), findsOneWidget);
      expect(find.text('Giữ tài khoản'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Xoá tài khoản').last);
      await tester.pumpAndSettle();

      expect(fakeAccount.calls.contains('requestDeletion'), isTrue);
      expect(find.text('Tài khoản đã khoá, sẽ xoá hẳn vào 06/11.'), findsOneWidget);
      expect(routes.contains('/login'), isTrue);
    });

    testWidgets('reauth_required opens reauth sheet and retries once', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');

      final fakeAccount = FakeAccountRepository(
        blockers: [],
        reauthRequiredOnDeletion: true,
      );

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const DeleteAccountScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Xoá tài khoản').last);
      await _settle(tester);

      // Reauth sheet opens
      expect(find.text('Xác nhận lại để tiếp tục'), findsOneWidget);

      // Type password and submit
      fakeAccount.reauthRequiredOnDeletion = false; // Next call succeeds
      await tester.enterText(find.byKey(const Key('reauth-password')), 'pass1234');
      await tester.tap(find.byKey(const Key('reauth-go')));
      await _settle(tester);
      await tester.pumpAndSettle();

      expect(fakeAccount.calls.where((c) => c == 'requestDeletion').length, 2);
    });

    testWidgets('conflict reloads blockers', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');

      final fakeAccount = FakeAccountRepository(
        blockers: [],
        conflictOnDeletion: true,
      );

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const DeleteAccountScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Add a blocker for reload
      fakeAccount.blockers.add(
        const DeletionBlocker(kind: BlockerKind.heldPayment, count: 1, amount: 200000),
      );

      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Xoá tài khoản').last);
      await tester.pumpAndSettle();

      expect(find.text('200.000₫ đang được giữ'), findsOneWidget);
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      usePhoneFor(tester, width: 320, height: 640);
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(blockers: []);

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const DeleteAccountScreen()),
          textScale: 1.3,
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
