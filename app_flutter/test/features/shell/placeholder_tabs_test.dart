import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<(FakeAuthRepository, FakeUserRepository)> _signedIn(
  UserRole role,
) async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await users.setRole(u.uid, role);
  return (auth, users);
}

Widget _app(Widget home, FakeAuthRepository auth, FakeUserRepository users) =>
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(
          FakePhotographerIntroRepository(),
        ),
      ],
      child: MaterialApp(
        theme: buildDarkTheme(),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  testWidgets('bookings tab shows work empty state for photographers', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(_app(const BookingsTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có yêu cầu nào'), findsOneWidget);
  });
  testWidgets('bookings tab shows customer empty state for customers', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const BookingsTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
  });
  testWidgets('profile tab signs out', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const ProfileTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Minh'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });
  testWidgets('photographer switches to customer and back from profile', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(_app(const ProfileTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Nhiếp ảnh gia'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing, reason: 'nothing switched yet');

    await tester.tap(find.text('Chuyển qua chế độ đặt lịch'));
    await tester.pumpAndSettle();
    final uid = auth.currentUser!.uid;
    expect((await users.watch(uid).first)?.role, UserRole.customer);
    expect(find.text('Khách hàng'), findsOneWidget);
    expect(find.text('Đã chuyển qua chế độ đặt lịch.'), findsOneWidget);
    expect(users.photographerDocs, contains(uid), reason: 'kept for later');

    await tester.tap(find.text('Chuyển qua chế độ nhiếp ảnh'));
    await tester.pumpAndSettle();
    expect((await users.watch(uid).first)?.role, UserRole.photographer);
    expect(find.text('Đã chuyển qua chế độ nhiếp ảnh.'), findsOneWidget);
  });
  testWidgets('a failed switch keeps the role and says so', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository(failSetRole: true);
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await tester.pumpWidget(_app(const ProfileTab(), auth, users));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-role')));
    await tester.pumpAndSettle();
    expect(
      find.text('Không đổi được chế độ. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
  });
  for (final size in const [Size(320, 640), Size(430, 932)]) {
    testWidgets('bookings tab fits $size at text scale 1.3', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (auth, users) = await _signedIn(UserRole.customer);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: _app(const BookingsTab(), auth, users),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('S30: switch is the small primary, shared avatar, h3 title', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const ProfileTab(), auth, users));
    await tester.pumpAndSettle();
    final sw = find.byKey(const Key('switch-role'));
    expect(tester.widget<AppButton>(sw).size, AppButtonSize.small);
    expect(
      find.descendant(of: sw, matching: find.byType(CtaSurface)),
      findsOneWidget,
    );
    final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
    expect(avatar.size, AppAvatarSize.lg);
    final title = tester.widget<Text>(find.text('Tôi là nhiếp ảnh gia'));
    expect(title.style?.fontSize, 17);
    expect(title.style?.fontFamily, AppFonts.display);
  });

  Widget routed(
    FakeAuthRepository auth,
    FakeUserRepository users,
    FakePhotographerIntroRepository intro, {
    String initial = '/profile',
  }) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
        GoRoute(path: '/bookings', builder: (_, _) => const BookingsTab()),
        GoRoute(path: '/setup', builder: (_, _) => const Text('setup')),
        GoRoute(
          path: '/work/calendar',
          builder: (_, _) => const Text('calendar'),
        ),
      ],
    );
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(intro),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets(
    'a photographer with unfinished setup is offered to continue it',
    (tester) async {
      final (auth, users) = await _signedIn(UserRole.photographer);
      final intro = FakePhotographerIntroRepository()
        ..seed(auth.currentUser!.uid, const PhotographerIntro());
      await tester.pumpWidget(routed(auth, users, intro));
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thiện hồ sơ nhiếp ảnh gia'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('continue-setup')));
      await tester.tap(find.byKey(const Key('continue-setup')));
      await tester.pumpAndSettle();
      expect(find.text('setup'), findsOneWidget);
    },
  );

  testWidgets('the setup card is gone once setup is complete', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final intro = FakePhotographerIntroRepository()
      ..seed(
        auth.currentUser!.uid,
        const PhotographerIntro(onboardingComplete: true),
      );
    await tester.pumpWidget(routed(auth, users, intro));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue-setup')), findsNothing);
  });

  testWidgets('switching to photographer opens setup while it is unfinished', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(
      routed(auth, users, FakePhotographerIntroRepository()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch-role')));
    await tester.tap(find.byKey(const Key('switch-role')));
    await tester.pumpAndSettle();
    expect(find.text('setup'), findsOneWidget);
  });

  testWidgets('photographers open their calendar from the work tab', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(
      routed(
        auth,
        users,
        FakePhotographerIntroRepository(),
        initial: '/bookings',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('customers have no calendar entry', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(
      routed(
        auth,
        users,
        FakePhotographerIntroRepository(),
        initial: '/bookings',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-calendar')), findsNothing);
  });
}
