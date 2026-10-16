import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/role_mode_card.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_push.dart';

/// Holds [setRole] until [hold] completes, to look at the screen mid-switch.
class _HeldUsers extends FakeUserRepository {
  Completer<void>? hold;

  @override
  Future<void> setRole(String uid, UserRole role) async {
    await hold?.future;
    return super.setRole(uid, role);
  }
}

/// A profile stream that lags the write: [setRole] succeeds at once but the
/// stream only shows the new role after [release].
class _LaggingUsers extends FakeUserRepository {
  bool lag = false;
  (String, UserRole)? _pending;

  @override
  Future<void> setRole(String uid, UserRole role) async {
    if (!lag) return super.setRole(uid, role);
    _pending = (uid, role);
  }

  Future<void> release() async {
    final p = _pending;
    _pending = null;
    if (p != null) await super.setRole(p.$1, p.$2);
  }
}

Future<(FakeAuthRepository, FakeUserRepository)> _signedIn(
  UserRole role, {
  FakeUserRepository? users,
}) async {
  final auth = FakeAuthRepository();
  final repo = users ?? FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await repo.ensureProfile(u);
  await repo.setRole(u.uid, role);
  return (auth, repo);
}

Future<Widget> _app(
  FakeAuthRepository auth,
  FakeUserRepository users, {
  FakePhotographerIntroRepository? intro,
  String initial = '/settings',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/profile', builder: stub),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [GoRoute(path: 'profile', builder: stub)],
      ),
      GoRoute(path: '/setup', builder: stub),
    ],
  );
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      photographerIntroRepositoryProvider.overrideWithValue(
        intro ?? FakePhotographerIntroRepository(),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      userContactRepositoryProvider.overrideWithValue(
        FakeUserContactRepository(),
      ),
      skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
      publicProfileRepositoryProvider.overrideWithValue(
        FakePublicProfileRepository(),
      ),
      awardRepositoryProvider.overrideWithValue(
        FakeAwardRepository(uid: auth.currentUser!.uid),
      ),
      pushMessagingProvider.overrideWithValue(FakePushMessaging()),
      notificationPermissionProvider.overrideWithValue(
        FakeNotificationPermission(NotificationPermissionStatus.denied),
      ),
      deviceRegistryProvider.overrideWithValue(FakeDeviceRegistry()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Brings the lazily built mode card into the list (rows above it, e.g.
/// "Xác minh & nhận đơn", can push it below the 800x600 test view).
Future<void> _showModeCard(WidgetTester tester) => tester.scrollUntilVisible(
  find.byKey(const Key('switch-role')),
  200,
  scrollable: find.byType(Scrollable).first,
);

Future<void> _tapSwitch(WidgetTester tester) async {
  final sw = find.byKey(const Key('switch-role'));
  await _showModeCard(tester);
  await tester.ensureVisible(sw);
  await tester.pumpAndSettle();
  await tester.tap(sw);
}

void main() {
  testWidgets('a customer sees "Tôi là nhiếp ảnh gia" and an outline '
      '"Chuyển qua chế độ nhiếp ảnh"', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(await _app(auth, users));
    await tester.pumpAndSettle();
    expect(find.byType(RoleModeCard), findsOneWidget);
    expect(find.text('CHẾ ĐỘ'), findsOneWidget);
    expect(find.text('Tôi là nhiếp ảnh gia'), findsOneWidget);
    expect(
      find.text(
        'Đăng ảnh, nhận booking và quản lý lịch. Bạn vẫn đổi lại được bất '
        'cứ lúc nào.',
      ),
      findsOneWidget,
    );
    final sw = find.byKey(const Key('switch-role'));
    expect(
      find.descendant(
        of: sw,
        matching: find.text('Chuyển qua chế độ nhiếp ảnh'),
      ),
      findsOneWidget,
    );
    expect(tester.widget<AppButton>(sw).size, AppButtonSize.small);
    // Outline, not the gradient: the screen's primary is "Xem trước nút".
    expect(
      find.descendant(of: sw, matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sw, matching: find.byType(CtaSurface)),
      findsNothing,
    );
    expect(
      find.descendant(of: sw, matching: find.byIcon(AppIcons.swap)),
      findsOneWidget,
    );
  });

  testWidgets('a photographer is offered "Tôi cần đặt lịch"', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(await _app(auth, users));
    await tester.pumpAndSettle();
    await _showModeCard(tester);
    expect(find.text('Tôi cần đặt lịch'), findsOneWidget);
    expect(find.text('Chuyển qua chế độ đặt lịch'), findsOneWidget);
  });

  testWidgets('switching to photographer with setup unfinished opens /setup', (
    tester,
  ) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    final uid = auth.currentUser!.uid;
    final intro = FakePhotographerIntroRepository()
      ..seed(uid, const PhotographerIntro());
    await tester.pumpWidget(await _app(auth, users, intro: intro));
    await tester.pumpAndSettle();
    await _tapSwitch(tester);
    await tester.pumpAndSettle();
    expect((await users.watch(uid).first)?.role, UserRole.photographer);
    expect(find.text('stub /setup'), findsOneWidget);
    expect(find.text('Đã chuyển qua chế độ nhiếp ảnh.'), findsOneWidget);

    // Setup sits over Hồ sơ: Back (system or arrow) returns there.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('stub /profile'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('switching to photographer with setup complete goes back to '
      '/profile', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    final uid = auth.currentUser!.uid;
    final intro = FakePhotographerIntroRepository()
      ..seed(uid, const PhotographerIntro(onboardingComplete: true));
    await tester.pumpWidget(await _app(auth, users, intro: intro));
    await tester.pumpAndSettle();
    await _tapSwitch(tester);
    await tester.pumpAndSettle();
    expect(find.text('stub /profile'), findsOneWidget);
    expect(find.text('Đã chuyển qua chế độ nhiếp ảnh.'), findsOneWidget);
  });

  testWidgets('switching to customer goes back to /profile', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final uid = auth.currentUser!.uid;
    await tester.pumpWidget(await _app(auth, users));
    await tester.pumpAndSettle();
    await _tapSwitch(tester);
    await tester.pumpAndSettle();
    expect((await users.watch(uid).first)?.role, UserRole.customer);
    expect(users.photographerDocs, contains(uid), reason: 'kept for later');
    expect(find.text('stub /profile'), findsOneWidget);
    expect(find.text('Đã chuyển qua chế độ đặt lịch.'), findsOneWidget);
  });

  testWidgets('a failed switch keeps the role and says so', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository(failSetRole: true);
    await users.ensureProfile(
      await auth.registerWithEmail('a@b.vn', 'password1', 'Minh'),
    );
    await tester.pumpWidget(await _app(auth, users));
    await tester.pumpAndSettle();
    await _tapSwitch(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Không đổi được chế độ. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      (await users.watch(auth.currentUser!.uid).first)?.role,
      isNot(UserRole.photographer),
    );
    expect(find.text('Tôi là nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets('while switching, the other rows do not react to taps', (
    tester,
  ) async {
    final held = _HeldUsers();
    final (auth, users) = await _signedIn(UserRole.customer, users: held);
    final intro = FakePhotographerIntroRepository()
      ..seed(
        auth.currentUser!.uid,
        const PhotographerIntro(onboardingComplete: true),
      );
    await tester.pumpWidget(await _app(auth, users, intro: intro));
    await tester.pumpAndSettle();
    held.hold = Completer<void>();
    await _tapSwitch(tester);
    await tester.pump();
    expect(
      tester.widget<AppButton>(find.byKey(const Key('switch-role'))).loading,
      isTrue,
    );

    // Scrolled above the fold by the tap on the switch.
    final edit = find.byKey(
      const Key('settings-edit-profile'),
      skipOffstage: false,
    );
    await tester.ensureVisible(edit);
    await tester.pump();
    expect(edit.hitTestable(), findsNothing, reason: 'absorbed');
    await tester.tap(edit, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('stub /settings/profile'), findsNothing);

    held.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('stub /profile'), findsOneWidget);
  });

  testWidgets('the card scrolled out of the list mid-switch still gets its '
      'SnackBar and redirect', (tester) async {
    // A short phone, so the list scrolls well past the card.
    tester.view
      ..physicalSize = const Size(390, 480)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final held = _HeldUsers();
    final (auth, users) = await _signedIn(UserRole.photographer, users: held);
    await tester.pumpWidget(await _app(auth, users));
    await tester.pumpAndSettle();
    held.hold = Completer<void>();
    await tester.scrollUntilVisible(
      find.byKey(const Key('switch-role')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _tapSwitch(tester);
    await tester.pump();

    // Far enough down that the lazily built card is disposed (once the tap's
    // ink splash, which keeps it alive, has faded).
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    list.position.jumpTo(list.position.maxScrollExtent);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RoleModeCard, skipOffstage: false), findsNothing);

    held.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('stub /profile'), findsOneWidget);
    expect(find.text('Đã chuyển qua chế độ đặt lịch.'), findsOneWidget);
  });

  testWidgets('during the switch, back does not leave Cài đặt', (tester) async {
    final held = _HeldUsers();
    final (auth, users) = await _signedIn(UserRole.customer, users: held);
    final intro = FakePhotographerIntroRepository()
      ..seed(
        auth.currentUser!.uid,
        const PhotographerIntro(onboardingComplete: true),
      );
    await tester.pumpWidget(
      await _app(auth, users, intro: intro, initial: '/profile'),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('stub /profile'))).push('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget, reason: 'pushed');

    held.hold = Completer<void>();
    await _tapSwitch(tester);
    await tester.pump();
    // The arrow is shown but disabled, and system back is refused.
    expect(find.byType(BackButton), findsNothing);
    final arrow = tester.widget<IconButton>(
      find.byKey(const Key('settings-back-disabled')),
    );
    expect(arrow.onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SettingsScreen), findsOneWidget);

    held.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('stub /profile'), findsOneWidget);
    expect(find.text('Đã chuyển qua chế độ nhiếp ảnh.'), findsOneWidget);
  });

  testWidgets('a failed switch can be left again after its message', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository(failSetRole: true);
    await users.ensureProfile(
      await auth.registerWithEmail('a@b.vn', 'password1', 'Minh'),
    );
    await tester.pumpWidget(await _app(auth, users, initial: '/profile'));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('stub /profile'))).push('/settings');
    await tester.pumpAndSettle();
    await _tapSwitch(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Không đổi được chế độ. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('stub /profile'), findsOneWidget);
  });

  group('the profile stream lags the switch', () {
    testWidgets('to photographer: the SnackBar and /setup follow the '
        "controller's value", (tester) async {
      final lagging = _LaggingUsers();
      final (auth, users) = await _signedIn(UserRole.customer, users: lagging);
      final uid = auth.currentUser!.uid;
      await tester.pumpWidget(
        await _app(
          auth,
          users,
          intro: FakePhotographerIntroRepository()
            ..seed(uid, const PhotographerIntro()),
        ),
      );
      await tester.pumpAndSettle();
      lagging.lag = true;
      await _tapSwitch(tester);
      await tester.pumpAndSettle();
      expect(
        (await users.watch(uid).first)?.role,
        UserRole.customer,
        reason: 'the stream has not caught up',
      );
      expect(find.text('Đã chuyển qua chế độ nhiếp ảnh.'), findsOneWidget);
      expect(find.text('Đã chuyển qua chế độ đặt lịch.'), findsNothing);
      expect(find.text('stub /setup'), findsOneWidget);

      await lagging.release();
      await tester.pumpAndSettle();
      expect(find.text('stub /setup'), findsOneWidget);
    });

    testWidgets("to customer: the SnackBar names Đặt lịch and goes to "
        '/profile', (tester) async {
      final lagging = _LaggingUsers();
      final (auth, users) = await _signedIn(
        UserRole.photographer,
        users: lagging,
      );
      await tester.pumpWidget(await _app(auth, users));
      await tester.pumpAndSettle();
      lagging.lag = true;
      await _tapSwitch(tester);
      await tester.pumpAndSettle();
      expect(
        (await users.watch(auth.currentUser!.uid).first)?.role,
        UserRole.photographer,
      );
      expect(find.text('Đã chuyển qua chế độ đặt lịch.'), findsOneWidget);
      expect(find.text('stub /profile'), findsOneWidget);
      await lagging.release();
      await tester.pumpAndSettle();
    });
  });
}
