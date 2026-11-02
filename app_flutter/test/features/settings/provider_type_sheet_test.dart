import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/provider_repository.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';

import '../../support/photographer_world.dart';
import '../../support/screen_host.dart';
import '../../support/studio_world.dart' show FakeStudioRepository;
import '../../support/fake_organizer_repository.dart';

Future<PhotographerWorld> _open(
  WidgetTester tester, {
  ProviderType type = ProviderType.individual,
}) async {
  usePhone(tester, height: 1400);
  final w = PhotographerWorld();
  await w.init();
  w.seedProfile(type: type);
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/setup/4',
        builder: (_, s) =>
            Text('address form ${s.uri.queryParameters['from']}'),
      ),
      GoRoute(path: '/profile/phone', builder: (_, _) => const Text('phone')),
      GoRoute(path: '/profile/skills', builder: (_, _) => const Text('skills')),
      GoRoute(path: '/u/:id', builder: (_, _) => const Text('public')),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: [
        ...w.overrides,
        studioRepositoryProvider.overrideWithValue(FakeStudioRepository()),
        organizerRepositoryProvider.overrideWithValue(
          FakeOrganizerRepository(),
        ),
        userContactRepositoryProvider.overrideWithValue(
          FakeUserContactRepository(),
        ),
        skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return w;
}

Finder _key(String k) => find.byKey(Key(k));

Future<void> _openSheet(WidgetTester tester) async {
  await tester.ensureVisible(_key('profile-provider-type'));
  await tester.tap(_key('profile-provider-type'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the row shows the current type', (tester) async {
    await _open(tester);
    expect(
      find.descendant(
        of: _key('profile-provider-type'),
        matching: find.text('Cá nhân'),
      ),
      findsOneWidget,
    );
    expect(find.text('Hình thức nhận việc'), findsOneWidget);
  });

  testWidgets('an artist reads Cá nhân · Nhiếp ảnh gia', (tester) async {
    await _open(tester, type: ProviderType.artist);
    expect(find.text('Cá nhân · Nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets("the sheet's tiles use the icon variant", (tester) async {
    await _open(tester);
    await _openSheet(tester);
    expect(find.byKey(const ValueKey('option-icon-tile')), findsNWidgets(2));
  });

  testWidgets('switching opens the address form, flagged as from Settings', (
    tester,
  ) async {
    final w = await _open(tester);
    await _openSheet(tester);
    await tester.tap(_key('type-studio'));
    await tester.pumpAndSettle();
    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    expect(w.providerRepo.type, ProviderType.studio);
    expect(find.text('address form settings'), findsOneWidget);
  });

  testWidgets('saving without a change closes the sheet and calls nothing', (
    tester,
  ) async {
    final w = await _open(tester);
    var calls = 0;
    w.providerRepo.onSetType = () => calls++;
    await _openSheet(tester);
    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(_key('type-save'), findsNothing);
  });

  testWidgets('not eligible shows the reason and keeps the selection', (
    tester,
  ) async {
    final w = await _open(tester);
    w.providerRepo.failWith = const ProviderError('not_eligible');
    await _openSheet(tester);
    await tester.tap(_key('type-studio'));
    await tester.pumpAndSettle();
    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Còn booking chưa xong hoặc tiền đang giữ. Hoàn tất chúng trước khi đổi.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<AppOptionTile>(_key('type-studio')).selected, isTrue);
    expect(_key('type-save'), findsOneWidget, reason: 'sheet stays open');
    expect(find.text('address form settings'), findsNothing);
  });

  testWidgets('a network failure shows a generic error and stays open', (
    tester,
  ) async {
    final w = await _open(tester);
    w.providerRepo.failWithNetwork = true;
    await _openSheet(tester);
    await tester.tap(_key('type-studio'));
    await tester.pumpAndSettle();
    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không lưu được thiết lập'), findsOneWidget);
    expect(_key('type-save'), findsOneWidget);
  });

  testWidgets('an artist is asked before switching to Studio', (tester) async {
    final w = await _open(tester, type: ProviderType.artist);
    await _openSheet(tester);
    await tester.tap(_key('type-studio'));
    await tester.pumpAndSettle();
    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Đổi sang Studio sẽ bỏ hạng Nhiếp ảnh gia. Giải thưởng vẫn giữ.',
      ),
      findsOneWidget,
    );
    expect(w.providerRepo.type, ProviderType.artist, reason: 'not yet');

    // Keeping leaves everything as it was.
    await tester.tap(find.text('Giữ nguyên'));
    await tester.pumpAndSettle();
    expect(w.providerRepo.type, ProviderType.artist);

    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Đổi sang Studio'));
    await tester.pumpAndSettle();
    expect(w.providerRepo.type, ProviderType.studio);
  });

  testWidgets('a tier that turns artist mid-session updates the row and '
      'asks before switching to Studio', (tester) async {
    final w = await _open(tester);
    expect(find.text('Cá nhân · Nhiếp ảnh gia'), findsNothing);
    // The third award was approved: the server set artist, the cached
    // profile still says individual.
    w.awardRepo.setTier(const AwardTier(providerType: ProviderType.artist));
    await tester.pumpAndSettle();
    expect(find.text('Cá nhân · Nhiếp ảnh gia'), findsOneWidget);

    await _openSheet(tester);
    await tester.tap(_key('type-studio'));
    await tester.pumpAndSettle();
    await tester.tap(_key('type-save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Đổi sang Studio sẽ bỏ hạng Nhiếp ảnh gia. Giải thưởng vẫn giữ.',
      ),
      findsOneWidget,
    );
    expect(w.providerRepo.type, ProviderType.individual, reason: 'not yet');
  });

  testWidgets('no photographer document reads as Cá nhân, not loading', (
    tester,
  ) async {
    usePhone(tester, height: 1400);
    final w = PhotographerWorld();
    await w.init();
    w.awardRepo.setTier(null);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...w.overrides,
          studioRepositoryProvider.overrideWithValue(FakeStudioRepository()),
          organizerRepositoryProvider.overrideWithValue(
            FakeOrganizerRepository(),
          ),
          userContactRepositoryProvider.overrideWithValue(
            FakeUserContactRepository(),
          ),
          skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _key('profile-provider-type'),
        matching: find.text('Cá nhân'),
      ),
      findsOneWidget,
    );
  });
}
