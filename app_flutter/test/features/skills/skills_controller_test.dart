// test/features/skills/skills_controller_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_rules.dart';
import 'package:photobooking/features/skills/skills_controller.dart';
import 'package:photobooking/features/skills/skills_draft_store.dart';

import '../../support/content_fixtures.dart';
import '../../support/skills_world.dart';

Future<(SkillsWorld, ProviderContainer)> _open({
  PhotographerSkills? saved,
  List<PostSummary> Function(String uid)? posts,
  Future<void> Function(SkillsWorld w)? before,
}) async {
  final w = await SkillsWorld.create(saved: saved, posts: posts);
  await before?.call(w);
  final c = w.container();
  addTearDown(c.dispose);
  c.listen(skillsControllerProvider, (_, _) {});
  await c.read(skillsControllerProvider.future);
  return (w, c);
}

SkillsController _ctrl(ProviderContainer c) =>
    c.read(skillsControllerProvider.notifier);
SkillsEditorState _st(ProviderContainer c) =>
    c.read(skillsControllerProvider).requireValue;

const _wedding = PhotographerSkills(
  specialties: [SpecialtySkill(id: 'wedding')],
  languages: ['vi'],
);

void main() {
  test('nothing saved yet: Vietnamese ticked, nothing to leave behind, Tiếp tục off', () async {
    final (w, c) = await _open();
    expect(_st(c).draft, PhotographerSkills.initial);
    expect(_st(c).saved, PhotographerSkills.empty);
    expect(_st(c).dirty, isFalse);
    expect(_st(c).canSubmit, isFalse);
    expect(_st(c).completeness.percent, 10);
    expect(w.skills.loadCalls, 1);
  });

  test('an edit changes the draft and keeps a copy on the device', () async {
    final (w, c) = await _open();
    expect(_ctrl(c).toggleSpecialty('portrait')!.accepted, isTrue);
    expect(_st(c).draft.specialtyIds, ['portrait']);
    expect(_st(c).dirty, isTrue);
    expect(_st(c).canSubmit, isTrue);
    await pumpEventQueue();
    expect(SkillsDraftStore(w.prefs).read(w.uid), _st(c).draft);
  });

  test(
    'the 7th genre and the 4th Chuyên sâu are refused; the draft stays',
    () async {
      final (_, c) = await _open();
      for (final id in [
        'portrait',
        'wedding',
        'couple',
        'family',
        'graduation',
        'event',
      ]) {
        _ctrl(c).toggleSpecialty(id);
      }
      final before = _st(c).draft;
      final e = _ctrl(c).toggleSpecialty('product')!;
      expect(
        (e.rejection, e.group),
        (SkillEditRejection.tooManyItems, SkillGroup.specialty),
      );
      expect(_st(c).draft, before);
      for (final id in ['portrait', 'wedding', 'couple']) {
        _ctrl(c).setLevel(id, SkillLevels.expert);
      }
      expect(
        _ctrl(c).setLevel('family', SkillLevels.expert)!.rejection,
        SkillEditRejection.tooManyExpert,
      );
      expect(_st(c).draft.specialty('family')!.level, SkillLevels.proficient);
    },
  );

  test(
    'submit with problems saves nothing; issues refresh as they are fixed',
    () async {
      final (w, c) = await _open();
      _ctrl(c).toggleSpecialty('portrait');
      _ctrl(c).setLevel('portrait', SkillLevels.expert);
      _ctrl(c).toggleTag(SkillGroup.language, 'vi');
      expect(await _ctrl(c).submit(), SkillsSubmitResult.invalid);
      expect(w.skills.saveCalls, 0);
      expect(
        _st(c).hasIssue(SkillIssueCode.expertNeedsEvidence, itemId: 'portrait'),
        isTrue,
      );
      expect(_st(c).hasIssue(SkillIssueCode.noLanguage), isTrue);
      _ctrl(c).toggleTag(SkillGroup.language, 'en');
      expect(_st(c).hasIssue(SkillIssueCode.noLanguage), isFalse);
      expect(
        _st(c).hasIssue(SkillIssueCode.expertNeedsEvidence, itemId: 'portrait'),
        isTrue,
      );
    },
  );

  test(
    'a valid submit writes ids once, clears the device draft and logs',
    () async {
      final (w, c) = await _open();
      _ctrl(c).toggleSpecialty('portrait');
      _ctrl(c).setLevel('portrait', SkillLevels.expert);
      _ctrl(c).setEvidence('portrait', ['p1']);
      _ctrl(c).toggleTag(SkillGroup.style, 'film');
      _ctrl(c).toggleTag(SkillGroup.audience, 'couple');
      _ctrl(c).setYears(6);
      expect(await _ctrl(c).submit(), SkillsSubmitResult.saved);
      expect(w.skills.saveCalls, 1);
      expect(
        w.skills.stored(w.uid),
        const PhotographerSkills(
          specialties: [
            SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1']),
          ],
          styles: ['film'],
          languages: ['vi'],
          audiences: ['couple'],
          yearsExperience: 6,
        ),
      );
      expect(SkillsDraftStore(w.prefs).read(w.uid), isNull);
      expect(_st(c).dirty, isFalse);
      expect(_st(c).unsaved, isFalse);
      expect(w.event('skills_save'), {'specialties': 1, 'expert': 1});
      expect(w.event('skill_evidence_set'), {
        'skillId': 'portrait',
        'count': 1,
      });
    },
  );

  test('an unchanged submit writes nothing', () async {
    final (w, c) = await _open(saved: _wedding);
    expect(await _ctrl(c).submit(), SkillsSubmitResult.saved);
    expect(w.skills.saveCalls, 0);
  });

  test('a failed save keeps the draft and the device copy', () async {
    final (w, c) = await _open();
    _ctrl(c).toggleSpecialty('portrait');
    w.skills.failSaveWith = StateError('offline');
    expect(await _ctrl(c).submit(), SkillsSubmitResult.failed);
    expect(_st(c).saving, isFalse);
    expect(_st(c).draft.specialtyIds, ['portrait']);
    await pumpEventQueue();
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNotNull);
  });

  test('"Bỏ thay đổi" while a save is in flight changes nothing', () async {
    final (w, c) = await _open();
    _ctrl(c).toggleSpecialty('portrait');
    final gate = Completer<void>();
    w.skills.holdSave = gate.future;
    final saving = _ctrl(c).submit();
    expect(_st(c).saving, isTrue);
    await _ctrl(c).discardDraft();
    expect(_st(c).draft.specialtyIds, ['portrait'], reason: 'not discarded');
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNotNull);
    gate.complete();
    expect(await saving, SkillsSubmitResult.saved);
    expect(w.skills.stored(w.uid)!.specialtyIds, ['portrait']);
  });

  test('a device draft is reopened, and can be thrown away', () async {
    const draft = PhotographerSkills(
      specialties: [SpecialtySkill(id: 'food')],
      languages: ['vi'],
    );
    final (w, c) = await _open(
      saved: _wedding,
      before: (w) => SkillsDraftStore(w.prefs).write(w.uid, draft),
    );
    expect(_st(c).draft, draft);
    expect(_st(c).restoredDraft, isTrue);
    expect(_st(c).saved, _wedding);
    expect(
      _st(c).dirty,
      isFalse,
      reason: 'nothing changed since it was reopened',
    );
    expect(_st(c).unsaved, isTrue);
    await _ctrl(c).discardDraft();
    expect(_st(c).draft, _wedding);
    expect(SkillsDraftStore(w.prefs).read(w.uid), isNull);
  });

  test('evidence of deleted posts is dropped when the screen opens', () async {
    const saved = PhotographerSkills(
      specialties: [
        SpecialtySkill(
          id: 'portrait',
          level: 3,
          evidencePostIds: ['kept', 'gone'],
        ),
      ],
      languages: ['vi'],
    );
    final (_, c) = await _open(
      saved: saved,
      posts: (uid) => [fixturePost('kept', photographerId: uid)],
    );
    expect(_st(c).draft.specialty('portrait')!.evidencePostIds, ['kept']);
    expect(
      _st(c).unsaved,
      isTrue,
      reason: '"Lưu thay đổi" stores the cleaned list',
    );
  });

  test('offline, the evidence check is skipped and the list kept', () async {
    const saved = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['a']),
      ],
      languages: ['vi'],
    );
    final (_, c) = await _open(
      saved: saved,
      before: (w) async => w.posts.failWith = StateError('offline'),
    );
    expect(_st(c).draft, saved);
  });

  test('a failed load is an error state, without a retry timer', () async {
    final w = await SkillsWorld.create();
    w.skills.failLoadWith = StateError('offline');
    final c = w.container();
    addTearDown(c.dispose);
    c.listen(skillsControllerProvider, (_, _) {});
    await expectLater(
      c.read(skillsControllerProvider.future),
      throwsStateError,
    );
    expect(c.read(skillsControllerProvider).hasError, isTrue);
  });

  test(
    'restored draft, edited back to saved, submit: dirty is false',
    () async {
      const draft = PhotographerSkills(
        specialties: [SpecialtySkill(id: 'food')],
        languages: ['vi'],
      );
      final (_, c) = await _open(
        saved: _wedding,
        before: (w) => SkillsDraftStore(w.prefs).write(w.uid, draft),
      );
      _ctrl(c).toggleSpecialty('food');
      _ctrl(c).toggleSpecialty('wedding');
      expect(_st(c).draft, _wedding);
      expect(_st(c).dirty, isTrue);
      expect(await _ctrl(c).submit(), SkillsSubmitResult.saved);
      expect(_st(c).dirty, isFalse);
      expect(_st(c).unsaved, isFalse);
    },
  );

  test('a malformed draft looks up at most 18 evidence posts', () async {
    final ids = [for (var i = 0; i < 25; i++) 'p$i'];
    final draft = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ids),
      ],
      languages: const ['vi'],
    );
    final (_, c) = await _open(
      posts: (uid) => [
        for (final id in ids) fixturePost(id, photographerId: uid),
      ],
      before: (w) => SkillsDraftStore(w.prefs).write(w.uid, draft),
    );
    expect(
      _st(c).draft.specialty('portrait')!.evidencePostIds,
      ids.take(18).toList(),
    );
  });
}
