import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/features/account/restore_account_screen.dart';

import '../../support/fake_account_repository.dart';
import '../../support/profile_world.dart';
import '../../support/screen_host.dart';

GoRouter _router({required Widget screen, List<String>? visited}) {
  return GoRouter(
    initialLocation: '/restore',
    routes: [
      GoRoute(
        path: '/restore',
        builder: (_, _) => screen,
      ),
      GoRoute(
        path: '/',
        builder: (_, _) {
          visited?.add('/');
          return const Scaffold(body: Text('home-screen'));
        },
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) {
          visited?.add('/login');
          return const Scaffold(body: Text('login-screen'));
        },
      ),
    ],
  );
}

void main() {
  group('RestoreAccountScreen', () {
    testWidgets('shows "Tài khoản đang chờ xoá" with date and restores to /', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(
        lock: AccountLock(DateTime(2026, 11, 20)),
      );
      final visited = <String>[];

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const RestoreAccountScreen(), visited: visited),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tài khoản đang chờ xoá'), findsOneWidget);
      expect(find.textContaining('20/11'), findsWidgets);
      expect(find.byKey(const Key('restore-account-button')), findsOneWidget);
      expect(find.byKey(const Key('restore-continue-delete-button')), findsOneWidget);

      // Tap "Khôi phục tài khoản"
      await tester.tap(find.byKey(const Key('restore-account-button')));
      await tester.pumpAndSettle();

      expect(fakeAccount.calls.contains('restore'), isTrue);
      expect(visited.contains('/'), isTrue);
      expect(find.text('Đã khôi phục tài khoản.'), findsOneWidget);
    });

    testWidgets('deadline_passed shows restoreAccountExpired and signs out', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(
        lock: AccountLock(DateTime(2026, 11, 20)),
        deadlinePassedOnRestore: true,
      );
      final visited = <String>[];

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const RestoreAccountScreen(), visited: visited),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('restore-account-button')));
      await tester.pumpAndSettle();

      expect(find.text('Đã quá 30 ngày, tài khoản không khôi phục được nữa.'), findsOneWidget);
      expect(visited.contains('/login'), isTrue);
      expect(fakeAuth.currentUser, isNull);
    });

    testWidgets('Tiếp tục xoá signs out', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(
        lock: AccountLock(DateTime(2026, 11, 20)),
      );
      final visited = <String>[];

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const RestoreAccountScreen(), visited: visited),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('restore-continue-delete-button')));
      await tester.pumpAndSettle();

      expect(visited.contains('/login'), isTrue);
      expect(fakeAuth.currentUser, isNull);
    });

    testWidgets('export link shows only for usable export and opens download url', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(
        lock: AccountLock(DateTime(2026, 11, 20)),
        export: DataExport(
          path: 'exports/u1/data.json',
          sizeBytes: 1024,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 5)),
        ),
      );
      final launcher = FakeExternalLauncher();

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const RestoreAccountScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            externalLauncherProvider.overrideWithValue(launcher),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tải bản sao dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Tải bản sao dữ liệu'));
      await tester.pumpAndSettle();

      expect(launcher.opened.isNotEmpty, isTrue);
      expect(fakeAccount.calls.contains('exportDownloadUrl:exports/u1/data.json'), isTrue);
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      usePhoneFor(tester, width: 320, height: 640);
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(
        lock: AccountLock(DateTime(2026, 11, 20)),
      );

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const RestoreAccountScreen()),
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
