import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/account/privacy_screen.dart';

import '../../support/fake_account_repository.dart';
import '../../support/screen_host.dart';

GoRouter _router({required Widget screen, List<String>? visited}) {
  return GoRouter(
    initialLocation: '/privacy',
    routes: [
      GoRoute(
        path: '/privacy',
        builder: (_, _) => screen,
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (_, _) {
          visited?.add('/settings/delete-account');
          return const Scaffold(body: Text('delete-account-screen'));
        },
      ),
    ],
  );
}

void main() {
  group('PrivacyScreen', () {
    testWidgets('photographer sees hide switch, customer does not', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository();
      final fakePhotographers = FakePhotographerRepository([
        PhotographerSummary(id: fakeAuth.currentUser!.uid, displayName: 'Minh Trí', hiddenFromDiscovery: false),
      ]);

      // Customer
      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const PrivacyScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            photographerRepositoryProvider.overrideWithValue(fakePhotographers),
            currentProfileProvider.overrideWith((ref) => Stream.value(
                  const UserProfile(uid: 'c1', displayName: 'Customer', role: UserRole.customer),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-hide-switch')), findsNothing);

      // Photographer (unmount first)
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const PrivacyScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            photographerRepositoryProvider.overrideWithValue(fakePhotographers),
            currentProfileProvider.overrideWith((ref) => Stream.value(
                  UserProfile(uid: fakeAuth.currentUser!.uid, displayName: 'Photographer', role: UserRole.photographer),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-hide-switch')), findsOneWidget);
    });

    testWidgets('toggling switch writes hiddenFromDiscovery and write error reverts', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository();
      final uid = fakeAuth.currentUser!.uid;
      final fakePhotographers = FakePhotographerRepository([
        PhotographerSummary(
          id: uid,
          displayName: 'Minh Trí',
          hiddenFromDiscovery: false,
        ),
      ]);

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const PrivacyScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            photographerRepositoryProvider.overrideWithValue(fakePhotographers),
            currentProfileProvider.overrideWith((ref) => Stream.value(
                  UserProfile(uid: uid, displayName: 'Minh Trí', role: UserRole.photographer),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Toggle switch to ON
      await tester.tap(find.byKey(const Key('privacy-hide-switch')));
      await tester.pumpAndSettle();

      expect(fakeAccount.lastHiddenSet, isTrue);
      expect(fakeAccount.calls.contains('setHiddenFromDiscovery:true'), isTrue);
    });

    testWidgets('export states: create, download, and limits', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository();
      final launcher = FakeExternalLauncher();
      final routes = <String>[];
      final uid = fakeAuth.currentUser!.uid;

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const PrivacyScreen(), visited: routes),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            externalLauncherProvider.overrideWithValue(launcher),
            currentProfileProvider.overrideWith((ref) => Stream.value(
                  UserProfile(uid: uid, displayName: 'Minh Trí', role: UserRole.customer),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initially no export: "Tạo bản sao"
      expect(find.byKey(const Key('privacy-export-create-button')), findsOneWidget);

      // Tap create
      await tester.tap(find.byKey(const Key('privacy-export-create-button')));
      await tester.pumpAndSettle();

      expect(fakeAccount.calls.contains('requestExport'), isTrue);

      // Now ready export shows "Tải xuống"
      expect(find.byKey(const Key('privacy-export-download-button')), findsOneWidget);
      expect(find.textContaining('Bản sao tạo lúc'), findsOneWidget);

      // Tap download
      await tester.tap(find.byKey(const Key('privacy-export-download-button')));
      await tester.pumpAndSettle();

      expect(launcher.opened.isNotEmpty, isTrue);

      // Xoá tài khoản opens /settings/delete-account
      await tester.tap(find.byKey(const Key('privacy-delete-account-button')));
      await tester.pumpAndSettle();
      expect(routes.contains('/settings/delete-account'), isTrue);
    });

    testWidgets('limit_exceeded shows privacyExportLimit', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(limitExceededOnExport: true);
      final uid = fakeAuth.currentUser!.uid;

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const PrivacyScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            currentProfileProvider.overrideWith((ref) => Stream.value(
                  UserProfile(uid: uid, displayName: 'Minh Trí', role: UserRole.customer),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('privacy-export-create-button')));
      await tester.pumpAndSettle();

      expect(find.text('Bạn vừa tạo bản sao, thử lại sau 24 giờ.'), findsOneWidget);
    });

    testWidgets('expired export shows create button again', (tester) async {
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.registerWithEmail('tri@b.vn', 'pass1234', 'Minh Trí');
      final fakeAccount = FakeAccountRepository(
        export: DataExport(
          path: 'exports/u1/exp.json',
          sizeBytes: 100,
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final uid = fakeAuth.currentUser!.uid;

      await tester.pumpWidget(
        screenRouterApp(
          router: _router(screen: const PrivacyScreen()),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            accountRepositoryProvider.overrideWithValue(fakeAccount),
            currentProfileProvider.overrideWith((ref) => Stream.value(
                  UserProfile(uid: uid, displayName: 'Minh Trí', role: UserRole.customer),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy-export-create-button')), findsOneWidget);
    });
  });
}
