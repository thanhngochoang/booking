import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/edit_profile_screen.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/settings/show_screen_codes_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/idle.dart';
import '../../support/photo_scope.dart';

Future<Widget> _app({
  required FakeAuthRepository auth,
  required FakeUserRepository users,
  required SharedPreferences prefs,
  FakeUserContactRepository? contacts,
  FakeImagePicker? picker,
  FakeMediaUploader? uploader,
  FakeSkillsRepository? skills,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, _) => const EditProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/phone',
        builder: (_, s) => Text('phone ${s.uri}'),
      ),
      GoRoute(path: '/profile/skills', builder: (_, _) => const Text('skills')),
      GoRoute(
        path: '/u/:uid',
        builder: (_, s) => Text('public ${s.pathParameters['uid']}'),
      ),
    ],
  );
  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      userContactRepositoryProvider.overrideWithValue(
        contacts ?? FakeUserContactRepository(),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      imagePickerProvider.overrideWithValue(picker ?? FakeImagePicker()),
      mediaUploaderProvider.overrideWithValue(uploader ?? FakeMediaUploader()),
      skillsRepositoryProvider.overrideWithValue(
        skills ?? FakeSkillsRepository(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => testPhotoScope(child: child!),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<(FakeAuthRepository, FakeUserRepository)> _signedIn([
  UserRole? role,
]) async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  if (role != null) await users.setRole(u.uid, role);
  return (auth, users);
}

void main() {
  test(
    'button style defaults to gradient and restores the saved choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(buttonStyleProvider), ButtonStyleMode.gradient);
      await c.read(buttonStyleProvider.notifier).set(ButtonStyleMode.avatar);
      expect(prefs.getString('buttonStyle'), 'avatar');
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(buttonStyleProvider), ButtonStyleMode.avatar);
    },
  );

  test('theme mode defaults to dark and restores the saved choice', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(themeModeProvider), ThemeMode.dark);
    await c.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(prefs.getString('themeMode'), 'light');

    final again = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('choosing a theme marks it selected and saves it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    ListTile tile(String k) => tester.widget<ListTile>(find.byKey(Key(k)));
    expect(tile('theme-dark').selected, isTrue);

    await tester.tap(find.byKey(const Key('theme-system')));
    await tester.pumpAndSettle();
    expect(tile('theme-system').selected, isTrue);
    expect(tile('theme-dark').selected, isFalse);
    expect(prefs.getString('themeMode'), 'system');
  });

  testWidgets('editing the display name saves it and returns to settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Minh'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('edit-name')), '  Minh Thư ');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    final uid = auth.currentUser!.uid;
    expect((await users.watch(uid).first)?.displayName, 'Minh Thư');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Minh Thư'), findsOneWidget);
    expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
  });

  testWidgets('an empty name is rejected before saving', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-name')), '   ');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên hiển thị.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      (await users.watch(auth.currentUser!.uid).first)?.displayName,
      'Minh',
    );
  });

  test(
    'screen codes are on by default in debug and the choice is remembered',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      // Tests run in debug mode, where the tags are shown by default.
      expect(c.read(showScreenCodesProvider), isTrue);
      await c.read(showScreenCodesProvider.notifier).set(false);
      expect(prefs.getBool('showScreenCodes'), isFalse);

      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(showScreenCodesProvider), isFalse);
    },
  );

  testWidgets('the screen-code switch is offered in debug and saves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('show-screen-codes'));
    await tester.scrollUntilVisible(row, 200);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(row).value, isTrue);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(row).value, isFalse);
    expect(prefs.getBool('showScreenCodes'), isFalse);
  });

  testWidgets('settings with the screen-code switch on stays idle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'showScreenCodes': true});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await expectIdle(tester);
  });

  testWidgets('editing the phone saves it to the private contact only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(
      await _app(auth: auth, users: users, prefs: prefs, contacts: contacts),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit-phone')), '0903123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-allow-whatsapp')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    final uid = auth.currentUser!.uid;
    expect(
      contacts.stored(uid),
      const UserContact(
        phone: '+84903123456',
        allowZalo: true,
        allowWhatsApp: true,
      ),
    );
    expect(
      (await users.watch(uid).first)!.toJson().containsKey('phone'),
      isFalse,
    );
  });

  testWidgets('without a stored number the switches wait for a valid one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(
      await _app(auth: auth, users: users, prefs: prefs, contacts: contacts),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();

    SwitchListTile tile(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key)));
    expect(tile('edit-allow-zalo').onChanged, isNull);
    expect(tile('edit-allow-whatsapp').onChanged, isNull);

    await tester.enterText(find.byKey(const Key('edit-phone')), '0903123456');
    await tester.pump();
    expect(tile('edit-allow-zalo').onChanged, isNotNull);
    expect(tile('edit-allow-whatsapp').onChanged, isNotNull);

    await tester.tap(find.byKey(const Key('edit-allow-whatsapp')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(contacts.stored(auth.currentUser!.uid)!.allowWhatsApp, isTrue);
  });

  testWidgets('an invalid phone blocks saving', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(
      await _app(auth: auth, users: users, prefs: prefs, contacts: contacts),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-phone')), '90312345');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Số điện thoại chưa đúng. Ví dụ: 903 123 456'),
      findsOneWidget,
    );
    expect(contacts.stored(auth.currentUser!.uid), isNull);
    expect(
      find.byType(SettingsScreen),
      findsNothing,
    ); // still on the edit screen
  });

  testWidgets(
    'a stored number prefills the field and an empty field keeps it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final (auth, users) = await _signedIn();
      final contacts = FakeUserContactRepository()
        ..seed(
          auth.currentUser!.uid,
          const UserContact(phone: '+84903123456', allowZalo: false),
        );
      await tester.pumpWidget(
        await _app(auth: auth, users: users, prefs: prefs, contacts: contacts),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-edit-profile')));
      await tester.pumpAndSettle();
      // The hint text is also '903 123 456', so read the field's own text.
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('edit-phone')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '903 123 456',
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('edit-allow-zalo')))
            .value,
        isFalse,
      );

      await tester.enterText(find.byKey(const Key('edit-phone')), '');
      await tester.tap(find.byKey(const Key('edit-save')));
      await tester.pumpAndSettle();
      expect(contacts.stored(auth.currentUser!.uid)!.phone, '+84903123456');
    },
  );

  testWidgets('S42 listens to the private contact only while open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(
      await _app(auth: auth, users: users, prefs: prefs, contacts: contacts),
    );
    await tester.pumpAndSettle();
    // S31's phone row already holds the (autoDispose) contact stream; S42
    // shares that one subscription instead of opening a second.
    expect(contacts.watchers, 1);

    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(contacts.watchers, 1);
    await expectIdle(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(contacts.watchers, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(contacts.watchers, 0);
  });

  group('mock layout', () {
    Future<void> openSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final (auth, users) = await _signedIn();
      await tester.pumpWidget(
        await _app(auth: auth, users: users, prefs: prefs),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('S42: own phone hint, fields on the page, sticky "Lưu"', (
      tester,
    ) async {
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings-edit-profile')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.',
        ),
        findsOneWidget,
      );
      expect(find.byType(GlassCard), findsNothing);
      expect(
        find.ancestor(
          of: find.byKey(const Key('edit-save')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('edit-save')),
          matching: find.byType(AppFooterBar),
        ),
        findsOneWidget,
      );
    });

    testWidgets('S31: small-caps muted group labels', (tester) async {
      await openSettings(tester);
      final label = tester.widget<Text>(find.text('TÀI KHOẢN'));
      expect(label.style?.fontSize, AppText.xs2);
      expect(label.style?.letterSpacing, closeTo(0.88, 0.01));
      final dark =
          Theme.of(tester.element(find.text('TÀI KHOẢN'))).brightness ==
          Brightness.dark;
      expect(
        label.style?.color,
        dark ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted,
      );
      expect(
        tester.getSemantics(find.text('TÀI KHOẢN')),
        matchesSemantics(label: 'Tài khoản', isHeader: true),
      );
    });

    testWidgets('S31: hairlines between rows, small preview button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openSettings(tester);
      // Account: 2 rows (edit profile, phone) + 1; three theme rows and two
      // button-style rows: 2 + 1.
      expect(find.byType(Divider), findsNWidgets(4));
      final preview = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Xem trước nút'),
      );
      expect(preview.size, AppButtonSize.small);
    });
  });

  testWidgets('S42 name field has no icon', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('edit-name')),
        matching: find.byIcon(Icons.person_outline_rounded),
      ),
      findsNothing,
    );
  });

  Future<void> openEdit(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
  }

  testWidgets('S42 keyboard up at 320x568: name field and Lưu reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    await openEdit(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('edit-save')).hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('edit-name')));
    expect(find.byKey(const Key('edit-name')).hitTestable(), findsOneWidget);
  });

  testWidgets('S42 fits 320x640 at 1.3x', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openEdit(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('edit-save')).hitTestable(), findsOneWidget);
  });

  testWidgets('S42 changes the avatar and shows it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final uploader = FakeMediaUploader();
    await tester.pumpWidget(
      await _app(
        auth: auth,
        users: users,
        prefs: prefs,
        picker: FakeImagePicker([
          [const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg')],
        ]),
        uploader: uploader,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Đã đổi ảnh đại diện.'), findsOneWidget);
    expect(
      tester.widget<AppAvatar>(find.byType(AppAvatar)).url,
      'https://storage.test/${uploader.uploaded.single}',
    );
  });

  group('S31 account rows', () {
    Future<void> open(
      WidgetTester tester,
      FakeAuthRepository auth,
      FakeUserRepository users, {
      FakeUserContactRepository? contacts,
      FakeSkillsRepository? skills,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        await _app(
          auth: auth,
          users: users,
          prefs: prefs,
          contacts: contacts,
          skills: skills,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('everyone can add a phone number; customers see no more', (
      tester,
    ) async {
      final (auth, users) = await _signedIn(UserRole.customer);
      await open(tester, auth, users);
      expect(find.byKey(const Key('profile-skills')), findsNothing);
      expect(find.byKey(const Key('profile-public')), findsNothing);
      expect(find.text('Chưa thêm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-phone')));
      await tester.pumpAndSettle();
      expect(find.text('phone /profile/phone'), findsOneWidget);
    });

    testWidgets('the phone row shows only the last 4 digits', (tester) async {
      final (auth, users) = await _signedIn(UserRole.customer);
      final contacts = FakeUserContactRepository()
        ..seed(auth.currentUser!.uid, const UserContact(phone: '0912345678'));
      await open(tester, auth, users, contacts: contacts);
      expect(find.text('•••• 5678'), findsOneWidget);
      expect(find.textContaining('091234'), findsNothing);
    });

    testWidgets('photographers see skills with the meter and public profile', (
      tester,
    ) async {
      final (auth, users) = await _signedIn(UserRole.photographer);
      final uid = auth.currentUser!.uid;
      final skills = FakeSkillsRepository()
        ..seed(
          uid,
          const PhotographerSkills(
            specialties: [SpecialtySkill(id: 'portrait')],
            languages: ['vi'],
          ),
        );
      await open(tester, auth, users, skills: skills);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-skills')),
          matching: find.byType(CompletenessMeter),
        ),
        findsOneWidget,
      );
      final before = skills.loadCalls;
      await tester.tap(find.byKey(const Key('profile-skills')));
      await tester.pumpAndSettle();
      expect(find.text('skills'), findsOneWidget);

      await open(tester, auth, users, skills: skills);
      expect(skills.loadCalls, greaterThanOrEqualTo(before));
      await tester.tap(find.byKey(const Key('profile-public')));
      await tester.pumpAndSettle();
      expect(find.text('public $uid'), findsOneWidget);
    });
  });
}
