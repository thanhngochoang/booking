// test/features/skills/evidence_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/skills/evidence_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/content_fixtures.dart';
import '../../support/photo_scope.dart';
import '../../support/skills_world.dart';

class _Probe {
  List<String>? result;
  bool closed = false;
  int createPost = 0;
}

Widget _app(
  SkillsWorld w,
  _Probe probe, {
  bool requiresOne = false,
  List<String> initial = const [],
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) => ProviderScope(
  retry: (_, _) => null,
  overrides: w.overrides,
  child: MaterialApp(
    theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => testPhotoScope(
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            probe.result = await showEvidenceSheet(
              context,
              specialtyName: 'Chân dung',
              initial: initial,
              requiresOne: requiresOne,
              onCreatePost: () => probe.createPost++,
            );
            probe.closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<SkillsWorld> _world({int own = 6}) => SkillsWorld.create(
  posts: (uid) => [
    for (var i = 0; i < own; i++)
      fixturePost(
        'm$i',
        photographerId: uid,
        age: Duration(minutes: i + 1),
      ),
    fixturePost(
      'shared',
      photographerId: uid,
      authorId: 'customer1',
      kind: PostKind.realShoot,
    ),
  ],
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'own posts only; picking updates "n / 3"; Xong returns them in order',
    (tester) async {
      final w = await _world();
      final probe = _Probe();
      await tester.pumpWidget(_app(w, probe));
      await _open(tester);
      expect(find.text('Minh chứng · Chân dung'), findsOneWidget);
      expect(
        find.text(
          'Chọn 1–3 ảnh trong portfolio thể hiện rõ thể loại này. Ảnh minh chứng giúp xếp hạng đáng tin hơn.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('evidence-shared')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('evidence-count'))).data,
        '0 / 3',
      );
      await tester.tap(find.byKey(const Key('evidence-m3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('evidence-m1')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('evidence-count'))).data,
        '2 / 3',
      );
      await tester.tap(find.byKey(const Key('evidence-done')));
      await tester.pumpAndSettle();
      expect(probe.result, ['m3', 'm1']);
    },
  );

  testWidgets('a 4th pick shows the limit message inside the sheet', (
    tester,
  ) async {
    final w = await _world();
    await tester.pumpWidget(_app(w, _Probe(), initial: ['m0', 'm1', 'm2']));
    await _open(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('evidence-count'))).data,
      '3 / 3',
    );
    await tester.tap(find.byKey(const Key('evidence-m4')));
    await tester.pump();
    expect(
      find.text('Tối đa 3 ảnh. Bỏ chọn một ảnh để chọn ảnh khác.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('evidence-m0')));
    await tester.pump();
    expect(find.byKey(const Key('evidence-max')), findsNothing);
  });

  testWidgets('Chuyên sâu: Xong stays off until one photo is picked', (
    tester,
  ) async {
    final w = await _world();
    await tester.pumpWidget(_app(w, _Probe(), requiresOne: true));
    await _open(tester);
    FilledButton done() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('evidence-done')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(done().onPressed, isNull);
    expect(find.text('Mức Chuyên sâu cần ít nhất 1 ảnh'), findsOneWidget);
    await tester.tap(find.byKey(const Key('evidence-m0')));
    await tester.pump();
    expect(done().onPressed, isNotNull);
  });

  testWidgets('no posts: "Đăng bài trước" and a way to S21, no Xong', (
    tester,
  ) async {
    final w = await SkillsWorld.create();
    final probe = _Probe();
    await tester.pumpWidget(_app(w, probe));
    await _open(tester);
    expect(find.text('Đăng bài trước'), findsOneWidget);
    expect(find.byKey(const Key('evidence-done')), findsNothing);
    await tester.tap(find.text('Đăng bài'));
    await tester.pumpAndSettle();
    expect(probe.createPost, 1);
    expect(probe.closed, isTrue);
    expect(probe.result, isNull);
  });

  testWidgets('a load error offers a retry', (tester) async {
    final w = await _world();
    w.posts.failWith = StateError('offline');
    await tester.pumpWidget(_app(w, _Probe()));
    await _open(tester);
    expect(find.text('Không tải được bài đăng của bạn.'), findsOneWidget);
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence-m0')), findsOneWidget);
  });

  testWidgets('dismissing returns null and changes nothing', (tester) async {
    final w = await _world();
    final probe = _Probe();
    await tester.pumpWidget(_app(w, probe, initial: ['m0']));
    await _open(tester);
    await tester.tap(find.byKey(const Key('evidence-m1')));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(probe.closed, isTrue);
    expect(probe.result, isNull);
  });

  testWidgets('320dp at 1.3x in both themes; Xong is 52dp tall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final b in Brightness.values) {
      final w = await _world();
      await tester.pumpWidget(_app(w, _Probe(), brightness: b, textScale: 1.3));
      await _open(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('evidence-done'))).height,
        controlHeight,
      );
      Navigator.of(tester.element(find.byType(EvidenceSheet))).pop();
      await tester.pumpAndSettle();
    }
  });
}
