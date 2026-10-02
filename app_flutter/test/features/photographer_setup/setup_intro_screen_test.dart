import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_screen.dart';

import '../../support/photographer_world.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/setup/1', builder: (_, _) => const SetupIntroScreen()),
  GoRoute(path: '/setup/2', builder: (_, _) => const Text('step 2')),
];

Future<PhotographerWorld> _world() async {
  final w = PhotographerWorld();
  await w.init();
  return w;
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('prefills the name and the saved intro, shows step 1 of 4', (
    tester,
  ) async {
    final w = await _world();
    w.intro.seed(
      w.uid,
      const PhotographerIntro(
        bio: 'Chân dung ngoài trời',
        equipment: ['Sony A7 IV'],
      ),
    );
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Chân dung ngoài trời'), findsOneWidget);
    expect(_key('equipment-Sony A7 IV'), findsOneWidget);
  });

  testWidgets('says what is missing and saves nothing', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-name'), ' ');
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(find.text('Viết vài dòng giới thiệu'), findsOneWidget);
    expect(find.text('Vui lòng nhập tên hiển thị.'), findsOneWidget);
    expect(w.intro.saves, 0);
    expect(find.text('step 2'), findsNothing);
  });

  testWidgets('saves name, intro and equipment, then opens step 2', (
    tester,
  ) async {
    usePhone(tester, height: 1400); // the avatar row pushes the form down
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-name'), 'Minh Trí Studio');
    await tester.enterText(
      _key('setup-bio'),
      'Ánh sáng tự nhiên, ít dàn dựng.',
    );
    await tester.enterText(_key('setup-equipment-field'), 'Sony A7 IV');
    await tester.tap(_key('setup-equipment-add'));
    await tester.pump();
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(
      w.intro.stored(w.uid),
      const PhotographerIntro(
        bio: 'Ánh sáng tự nhiên, ít dàn dựng.',
        equipment: ['Sony A7 IV'],
      ),
    );
    expect((await w.users.watch(w.uid).first)!.displayName, 'Minh Trí Studio');
    expect(SetupDraftStore(w.prefs).step(w.uid), 2);
    expect(
      SetupDraftStore(w.prefs).intro(w.uid),
      isNull,
      reason: 'the draft is cleared once saved',
    );
    expect(find.text('step 2'), findsOneWidget);
  });

  testWidgets('equipment typed but not added is saved with the rest', (
    tester,
  ) async {
    usePhone(tester, height: 1400); // the avatar row pushes the form down
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-bio'), 'Chân dung ngoài trời');
    await tester.enterText(_key('setup-equipment-field'), 'Sony A7 IV');
    await tester.tap(_key('setup-equipment-add'));
    await tester.pump();
    await tester.enterText(_key('setup-equipment-field'), '  Godox V1 ');
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(w.intro.stored(w.uid)!.equipment, ['Sony A7 IV', 'Godox V1']);
    expect(find.text('step 2'), findsOneWidget);
  });

  testWidgets('typing is kept as a draft and comes back after leaving', (
    tester,
  ) async {
    final w = await _world();
    w.intro.seed(w.uid, const PhotographerIntro(bio: 'Bản đã lưu'));
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-bio'), 'Nháp chưa lưu');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Nháp chưa lưu'), findsOneWidget);
    expect(find.text('Bản đã lưu'), findsNothing);
  });

  testWidgets('equipment stops at eight and ignores duplicates', (
    tester,
  ) async {
    usePhone(tester, height: 1400); // the avatar row pushes the form down
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    for (final name in [
      'Sony A7',
      'sony a7',
      'M1',
      'M2',
      'M3',
      'M4',
      'M5',
      'M6',
      'M7',
    ]) {
      await tester.enterText(_key('setup-equipment-field'), name);
      await tester.tap(_key('setup-equipment-add'));
      await tester.pump();
    }
    expect(find.byType(InputChip), findsNWidgets(8));
    expect(
      tester.widget<IconButton>(_key('setup-equipment-add')).onPressed,
      isNull,
    );
    expect(find.text('Tối đa 8 thiết bị.'), findsOneWidget);
    await tester.tap(find.byTooltip('Xoá M7'));
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(7));
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final w = await _world();
    w.intro.failSave = true;
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-bio'), 'Ánh sáng tự nhiên.');
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    // The existing setup-flow message (ARB `setupSaveError`, shared with S08.05).
    expect(
      find.text('Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(find.text('step 2'), findsNothing);
    expect(find.text('Ánh sáng tự nhiên.'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world();
      w.intro.seed(
        w.uid,
        PhotographerIntro(
          bio: 'x' * 300,
          equipment: const ['Sony A7 IV', 'Godox V1', 'Sigma 35mm f/1.4 Art'],
        ),
      );
      await tester.pumpWidget(
        w.app(
          location: '/setup/1',
          routes: _routes,
          brightness: b,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
