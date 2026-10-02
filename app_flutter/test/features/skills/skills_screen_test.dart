import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/skills/evidence_sheet.dart';
import 'package:photobooking/features/skills/skills_draft_store.dart';

import '../../support/content_fixtures.dart';
import '../../support/skills_app.dart';
import '../../support/skills_world.dart';

void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<SkillsWorld> _pump(
  WidgetTester tester, {
  String at = '/setup/3',
  PhotographerSkills? saved,
  List<PostSummary> Function(String uid)? posts,
  Future<void> Function(SkillsWorld w)? before,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) async {
  final w = await SkillsWorld.create(saved: saved, posts: posts);
  await before?.call(w);
  await tester.pumpWidget(
    skillsApp(
      w,
      initialLocation: at,
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();
  return w;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(Key(key)));

Future<void> _level(WidgetTester tester, String id, String label) => _tap(
  tester,
  find.descendant(of: find.byKey(Key('level-$id')), matching: find.text(label)),
);

VoidCallback? _submitPressed(WidgetTester tester) => tester
    .widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('skills-submit')),
        matching: find.byType(FilledButton),
      ),
    )
    .onPressed;

List<PostSummary> Function(String) _ownPosts(int n) =>
    (uid) => [
      for (var i = 0; i < n; i++)
        fixturePost(
          'm$i',
          photographerId: uid,
          age: Duration(minutes: i + 1),
        ),
    ];

const _portraitWithEvidence = PhotographerSkills(
  specialties: [
    SpecialtySkill(id: 'portrait', evidencePostIds: ['m0']),
  ],
  languages: ['vi'],
);

void main() {
  testWidgets(
    'setup: step 3/4, intro, meter; Tiếp tục off until a genre is chosen',
    (tester) async {
      _tallPhone(tester);
      final w = await _pump(tester);
      final step = tester.widget<StepProgress>(find.byType(StepProgress));
      expect((step.current, step.total), (3, 4));
      expect(
        find.text(
          'Chọn đúng thể loại và mức độ để được gợi ý cho khách cần đúng việc đó.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CompletenessMeter>(find.byType(CompletenessMeter))
            .percent,
        10,
      );
      expect(find.text('Chọn ít nhất 1 thể loại để lên 75%'), findsOneWidget);
      expect(_submitPressed(tester), isNull);
      await _tapKey(tester, 'specialty-portrait');
      expect(find.byKey(const Key('level-portrait')), findsOneWidget);
      expect(
        tester
            .widget<LevelSelector>(find.byKey(const Key('level-portrait')))
            .level,
        2,
      );
      expect(find.text('1 / 6'), findsOneWidget);
      expect(find.text('Chân dung: 0 / 3 ảnh minh chứng'), findsOneWidget);
      expect(_submitPressed(tester), isNotNull);
      expect(w.event('screen_view'), {'code': 'S38'});
    },
  );

  testWidgets('the 7th genre is refused with "Tối đa 6 thể loại"', (
    tester,
  ) async {
    _tallPhone(tester);
    await _pump(tester);
    for (final id in [
      'portrait',
      'wedding',
      'couple',
      'family',
      'graduation',
      'event',
    ]) {
      await _tapKey(tester, 'specialty-$id');
    }
    await _tapKey(tester, 'specialty-product');
    expect(find.text('Tối đa 6 thể loại'), findsOneWidget);
    expect(find.byType(LevelSelector), findsNWidgets(6));
  });

  testWidgets('the 4th Chuyên sâu is refused and the old level kept', (
    tester,
  ) async {
    _tallPhone(tester);
    await _pump(tester);
    for (final id in ['portrait', 'wedding', 'couple', 'family']) {
      await _tapKey(tester, 'specialty-$id');
    }
    for (final id in ['portrait', 'wedding', 'couple']) {
      await _level(tester, id, 'Chuyên sâu');
    }
    await _level(tester, 'family', 'Chuyên sâu');
    expect(
      find.text('Chỉ chọn tối đa 3 thể loại mức Chuyên sâu'),
      findsOneWidget,
    );
    expect(
      tester.widget<LevelSelector>(find.byKey(const Key('level-family'))).level,
      2,
    );
    expect(
      tester
          .widget<LevelSelector>(find.byKey(const Key('level-family')))
          .expertDisabled,
      isTrue,
    );
  });

  testWidgets(
    'Chuyên sâu without evidence: warning, and Tiếp tục saves nothing',
    (tester) async {
      _tallPhone(tester);
      final w = await _pump(tester);
      await _tapKey(tester, 'specialty-portrait');
      await _level(tester, 'portrait', 'Chuyên sâu');
      expect(
        find.text('Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng'),
        findsOneWidget,
      );
      expect(
        find.text('Thêm ảnh minh chứng cho Chân dung để lên 75%'),
        findsOneWidget,
      );
      await _tapKey(tester, 'skills-submit');
      expect(find.text('Kiểm tra lại các mục được đánh dấu'), findsOneWidget);
      expect(find.text('S34'), findsNothing);
      expect(w.skills.saveCalls, 0);
    },
  );

  testWidgets('no language: the error appears under Ngôn ngữ', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'language-vi');
    expect(find.text('Chọn ít nhất 1 ngôn ngữ'), findsNothing);
    await _tapKey(tester, 'skills-submit');
    expect(find.text('Chọn ít nhất 1 ngôn ngữ'), findsOneWidget);
    await _tapKey(tester, 'language-en');
    expect(find.text('Chọn ít nhất 1 ngôn ngữ'), findsNothing);
  });

  testWidgets('a valid setup saves catalogue ids and opens S34', (
    tester,
  ) async {
    _tallPhone(tester);
    final w = await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'style-film');
    await _tapKey(tester, 'extra-posing');
    await _tapKey(tester, 'audience-shy_subjects');
    await tester.ensureVisible(find.byKey(const Key('skills-years')));
    await tester.enterText(find.byKey(const Key('skills-years')), '6');
    await tester.pumpAndSettle();
    await _tapKey(tester, 'skills-submit');
    expect(find.text('S34'), findsOneWidget);
    expect(
      w.skills.stored(w.uid),
      const PhotographerSkills(
        specialties: [SpecialtySkill(id: 'portrait')],
        styles: ['film'],
        extras: ['posing'],
        languages: ['vi'],
        audiences: ['shy_subjects'],
        yearsExperience: 6,
      ),
    );
    expect(w.event('skills_step'), {'n': 3});
    expect(w.event('skills_save'), {'specialties': 1, 'expert': 0});
  });

  testWidgets('evidence: pick in S40, the row updates, saved with the skills', (
    tester,
  ) async {
    _tallPhone(tester);
    final w = await _pump(tester, posts: _ownPosts(4));
    await _tapKey(tester, 'specialty-portrait');
    await _level(tester, 'portrait', 'Chuyên sâu');
    await _tapKey(tester, 'evidence-edit-portrait');
    expect(find.byType(EvidenceSheet), findsOneWidget);
    await _tapKey(tester, 'evidence-m1');
    await _tapKey(tester, 'evidence-m2');
    await _tapKey(tester, 'evidence-done');
    expect(find.text('Chân dung: 2 / 3 ảnh minh chứng'), findsOneWidget);
    expect(
      find.text('Mức Chuyên sâu cần ít nhất 1 ảnh minh chứng'),
      findsNothing,
    );
    await _tapKey(tester, 'skills-submit');
    expect(find.text('S34'), findsOneWidget);
    expect(w.skills.stored(w.uid)!.specialty('portrait')!.evidencePostIds, [
      'm1',
      'm2',
    ]);
  });

  testWidgets('no posts yet: the sheet leads to S21', (tester) async {
    _tallPhone(tester);
    await _pump(tester);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'evidence-edit-portrait');
    expect(find.text('Đăng bài trước'), findsOneWidget);
    await _tap(tester, find.text('Đăng bài'));
    expect(find.text('S21'), findsOneWidget);
  });

  testWidgets(
    'edit mode: saved skills shown; Lưu thay đổi only after a change; saving goes back',
    (tester) async {
      _tallPhone(tester);
      final w = await _pump(
        tester,
        at: '/start',
        saved: _portraitWithEvidence,
        posts: _ownPosts(1),
      );
      await _tap(tester, find.text('open skills'));
      expect(find.byType(StepProgress), findsNothing);
      expect(find.byKey(const Key('skills-back')), findsNothing);
      expect(find.text('Lưu thay đổi'), findsOneWidget);
      expect(_submitPressed(tester), isNull);
      await _tapKey(tester, 'style-minimal');
      expect(_submitPressed(tester), isNotNull);
      await _tapKey(tester, 'skills-submit');
      expect(find.text('open skills'), findsOneWidget);
      expect(w.skills.stored(w.uid)!.styles, ['minimal']);
    },
  );

  testWidgets(
    'leaving with changes asks; "Giữ bản nháp" keeps the device draft',
    (tester) async {
      _tallPhone(tester);
      final w = await _pump(tester, at: '/start');
      await _tap(tester, find.text('open skills'));
      await _tapKey(tester, 'specialty-wedding');
      await _tap(tester, find.byType(BackButton));
      expect(find.text('Lưu bản nháp?'), findsOneWidget);
      await _tapKey(tester, 'confirm-keep');
      expect(find.text('open skills'), findsOneWidget);
      expect(SkillsDraftStore(w.prefs).read(w.uid)!.specialtyIds, ['wedding']);
    },
  );

  testWidgets('"Bỏ thay đổi" forgets the draft and leaves; dismissing stays', (
    tester,
  ) async {
    _tallPhone(tester);
    final w = await _pump(tester, at: '/start');
    await _tap(tester, find.text('open skills'));
    await _tapKey(tester, 'specialty-wedding');
    await _tap(tester, find.byType(BackButton));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('skills-submit')),
      findsOneWidget,
      reason: 'dismissed: still here',
    );
    await _tap(tester, find.byType(BackButton));
    await _tapKey(tester, 'confirm-discard');
    expect(find.text('open skills'), findsOneWidget);
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNull);
  });

  testWidgets('unticking a genre with evidence asks first', (tester) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: _portraitWithEvidence,
      posts: _ownPosts(1),
    );
    await _tapKey(tester, 'specialty-portrait');
    expect(find.text('Bỏ thể loại Chân dung?'), findsOneWidget);
    await _tapKey(tester, 'confirm-keep');
    expect(find.byKey(const Key('level-portrait')), findsOneWidget);
    await _tapKey(tester, 'specialty-portrait');
    await _tapKey(tester, 'confirm-discard');
    expect(find.byKey(const Key('level-portrait')), findsNothing);
  });

  testWidgets('setup "Quay lại" without changes goes to step 2', (
    tester,
  ) async {
    _tallPhone(tester);
    await _pump(tester);
    await _tapKey(tester, 'skills-back');
    expect(find.text('S24 bước 2'), findsOneWidget);
  });

  testWidgets('the deep link opens S40 for that genre', (tester) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills/evidence?skill=portrait',
      saved: _portraitWithEvidence,
      posts: _ownPosts(2),
    );
    expect(find.byType(EvidenceSheet), findsOneWidget);
    expect(find.text('Minh chứng · Chân dung'), findsOneWidget);
  });

  testWidgets('a reopened device draft is announced', (tester) async {
    _tallPhone(tester);
    await _pump(
      tester,
      at: '/profile/skills',
      saved: _portraitWithEvidence,
      posts: _ownPosts(1),
      before: (w) => SkillsDraftStore(w.prefs).write(
        w.uid,
        const PhotographerSkills(
          specialties: [SpecialtySkill(id: 'food')],
          languages: ['vi'],
        ),
      ),
    );
    expect(find.text('Đã mở lại bản nháp chưa lưu'), findsOneWidget);
    expect(find.byKey(const Key('level-food')), findsOneWidget);
  });

  testWidgets('a load error shows a message and retries', (tester) async {
    _tallPhone(tester);
    final w = await SkillsWorld.create();
    w.skills.failLoadWith = StateError('offline');
    await tester.pumpWidget(skillsApp(w, initialLocation: '/setup/3'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được kỹ năng.'), findsOneWidget);
    w.skills.failLoadWith = null;
    await _tapKey(tester, 'error-retry');
    expect(find.byKey(const Key('specialty-portrait')), findsOneWidget);
  });

  testWidgets('320dp at 1.3x in both themes: no overflow, buttons 52dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const rich = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'real_estate', level: 3),
        SpecialtySkill(id: 'graduation'),
        SpecialtySkill(id: 'newborn', level: 1),
      ],
      styles: ['natural_light'],
      audiences: ['shy_subjects', 'family_kids'],
      languages: ['vi', 'ko'],
      yearsExperience: 12,
    );
    for (final b in Brightness.values) {
      await _pump(tester, saved: rich, brightness: b, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('skills-submit'))).height,
        controlHeight,
      );
      expect(
        tester.getSize(find.byKey(const Key('skills-back'))).height,
        controlHeight,
      );
    }
  });

  testWidgets(
    '320x568 with the keyboard up: years field and footer stay tappable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      final w = await _pump(
        tester,
        saved: _portraitWithEvidence,
        textScale: 1.3,
      );
      final years = find.byKey(const Key('skills-years'));
      await tester.ensureVisible(years);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(years.hitTestable(), findsOneWidget);
      await tester.tap(years);
      await tester.enterText(years, '4');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('skills-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('skills-back')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('skills-submit')));
      await tester.pumpAndSettle();
      expect(find.text('S34'), findsOneWidget);
      expect(w.skills.stored(w.uid)!.yearsExperience, 4);
    },
  );

  testWidgets('the app router registers the three skills routes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final paths = container
        .read(routerProvider)
        .configuration
        .routes
        .whereType<GoRoute>()
        .map((r) => r.path);
    expect(
      paths,
      containsAll(['/setup/3', '/profile/skills', '/profile/skills/evidence']),
    );
  });
}
