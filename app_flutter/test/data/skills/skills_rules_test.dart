import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_rules.dart';

final catalog = builtInSkillCatalog;

SpecialtySkill sp(String id, [int level = 2, List<String> ev = const []]) =>
    SpecialtySkill(id: id, level: level, evidencePostIds: ev);

const valid = PhotographerSkills(
  specialties: [
    SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1']),
    SpecialtySkill(id: 'couple'),
  ],
  styles: ['film'],
  languages: ['vi'],
);

SkillIssue issue(SkillIssueCode code, [SkillGroup? group, String? id]) =>
    SkillIssue(code, group: group, itemId: id);

void main() {
  group(
    'validateSkills (spec §7: limits, unknown ids, level 3 without evidence)',
    () {
      const g = SkillGroup.specialty;
      final cases = <(String, PhotographerSkills, List<SkillIssue>)>[
        ('a valid profile', valid, []),
        (
          'the mock profile',
          const PhotographerSkills(
            specialties: [
              SpecialtySkill(
                id: 'portrait',
                level: 3,
                evidencePostIds: ['a', 'b'],
              ),
              SpecialtySkill(id: 'couple'),
              SpecialtySkill(id: 'family', level: 1),
            ],
            styles: ['natural_light', 'film'],
            extras: ['retouch', 'posing', 'kids'],
            languages: ['vi', 'en'],
            audiences: ['couple', 'family_kids', 'shy_subjects'],
            yearsExperience: 6,
          ),
          [],
        ),
        (
          'no genre',
          valid.copyWith(specialties: []),
          [issue(SkillIssueCode.noSpecialty, g)],
        ),
        (
          '7 genres',
          valid.copyWith(
            specialties: [
              for (final id in [
                'portrait',
                'wedding',
                'couple',
                'family',
                'graduation',
                'event',
                'product',
              ])
                sp(id),
            ],
          ),
          [issue(SkillIssueCode.tooManyItems, g)],
        ),
        (
          'unknown genre',
          valid.copyWith(specialties: [sp('underwater')]),
          [issue(SkillIssueCode.unknownItem, g, 'underwater')],
        ),
        (
          'an audience code used as a genre',
          valid.copyWith(specialties: [sp('shy_subjects')]),
          [issue(SkillIssueCode.unknownItem, g, 'shy_subjects')],
        ),
        (
          'duplicate genre',
          valid.copyWith(specialties: [sp('portrait'), sp('portrait')]),
          [issue(SkillIssueCode.duplicateItem, g, 'portrait')],
        ),
        (
          'level 4',
          valid.copyWith(specialties: [sp('portrait', 4)]),
          [issue(SkillIssueCode.invalidLevel, g, 'portrait')],
        ),
        (
          'level 0',
          valid.copyWith(specialties: [sp('portrait', 0)]),
          [issue(SkillIssueCode.invalidLevel, g, 'portrait')],
        ),
        (
          'level 3 without evidence',
          valid.copyWith(specialties: [sp('portrait', 3)]),
          [issue(SkillIssueCode.expertNeedsEvidence, g, 'portrait')],
        ),
        (
          '4 genres at level 3',
          valid.copyWith(
            specialties: [
              sp('portrait', 3, ['a']),
              sp('wedding', 3, ['b']),
              sp('couple', 3, ['c']),
              sp('family', 3, ['d']),
            ],
          ),
          [issue(SkillIssueCode.tooManyExpert, g)],
        ),
        (
          '4 evidence posts',
          valid.copyWith(
            specialties: [
              sp('portrait', 2, ['a', 'b', 'c', 'd']),
            ],
          ),
          [issue(SkillIssueCode.tooManyEvidence, g, 'portrait')],
        ),
        (
          'duplicate evidence',
          valid.copyWith(
            specialties: [
              sp('portrait', 3, ['a', 'a']),
            ],
          ),
          [issue(SkillIssueCode.duplicateEvidence, g, 'portrait')],
        ),
        (
          'malformed evidence id',
          valid.copyWith(
            specialties: [
              sp('portrait', 2, ['a/b']),
            ],
          ),
          [issue(SkillIssueCode.invalidEvidenceId, g, 'portrait')],
        ),
        (
          'genre years 60',
          valid.copyWith(
            specialties: [const SpecialtySkill(id: 'portrait', years: 60)],
          ),
          [issue(SkillIssueCode.yearsOutOfRange, g, 'portrait')],
        ),
        (
          '5 styles',
          valid.copyWith(
            styles: [
              'natural_light',
              'film',
              'minimal',
              'editorial',
              'documentary',
            ],
          ),
          [issue(SkillIssueCode.tooManyItems, SkillGroup.style)],
        ),
        (
          'unknown style',
          valid.copyWith(styles: ['neon']),
          [issue(SkillIssueCode.unknownItem, SkillGroup.style, 'neon')],
        ),
        (
          'duplicate style',
          valid.copyWith(styles: ['film', 'film']),
          [issue(SkillIssueCode.duplicateItem, SkillGroup.style, 'film')],
        ),
        (
          '9 extras',
          valid.copyWith(
            extras: [
              'retouch',
              'posing',
              'video',
              'drone',
              'studio',
              'kids',
              'pets',
              'low_light',
              'outdoor',
            ],
          ),
          [issue(SkillIssueCode.tooManyItems, SkillGroup.extra)],
        ),
        (
          '5 audiences',
          valid.copyWith(
            audiences: [
              'couple',
              'family_kids',
              'business',
              'foreigner',
              'shy_subjects',
            ],
          ),
          [issue(SkillIssueCode.tooManyItems, SkillGroup.audience)],
        ),
        (
          'unknown language',
          valid.copyWith(languages: ['vi', 'fr']),
          [issue(SkillIssueCode.unknownItem, SkillGroup.language, 'fr')],
        ),
        (
          'no language',
          valid.copyWith(languages: []),
          [issue(SkillIssueCode.noLanguage, SkillGroup.language)],
        ),
        (
          'all five languages',
          valid.copyWith(languages: ['vi', 'en', 'zh', 'ko', 'ja']),
          [],
        ),
        (
          '51 years',
          valid.copyWith(yearsExperience: 51),
          [issue(SkillIssueCode.yearsOutOfRange)],
        ),
        (
          '-1 years',
          valid.copyWith(yearsExperience: -1),
          [issue(SkillIssueCode.yearsOutOfRange)],
        ),
        ('0 and 50 years', valid.copyWith(yearsExperience: 50), []),
      ];
      for (final (name, skills, expected) in cases) {
        test(name, () => expect(validateSkills(skills, catalog), expected));
      }

      test('several problems are all reported, in screen order', () {
        final s = valid.copyWith(
          specialties: [sp('portrait', 3)],
          styles: ['neon'],
          languages: [],
          yearsExperience: 99,
        );
        expect(validateSkills(s, catalog), [
          issue(SkillIssueCode.expertNeedsEvidence, g, 'portrait'),
          issue(SkillIssueCode.unknownItem, SkillGroup.style, 'neon'),
          issue(SkillIssueCode.noLanguage, SkillGroup.language),
          issue(SkillIssueCode.yearsOutOfRange),
        ]);
      });

      test(
        'a retired item is refused when new, kept when it was already saved',
        () {
          final c = TaxonomyCatalog([
            ...SkillGroup.values.expand(
              (grp) => [
                for (final id in builtInSkillCatalog.ids(grp))
                  builtInSkillCatalog.item(grp, id)!,
              ],
            ),
            const TaxonomyItem(
              id: 'lomo',
              group: SkillGroup.style,
              labelVi: 'Lomo',
              order: 99,
              active: false,
            ),
          ]);
          final s = valid.copyWith(styles: ['lomo']);
          expect(validateSkills(s, c), [
            issue(SkillIssueCode.retiredItem, SkillGroup.style, 'lomo'),
          ]);
          expect(validateSkills(s, c, previous: s), isEmpty);
        },
      );
    },
  );

  group('edits', () {
    test(
      'choosing a genre adds a Thành thạo row; removing drops its evidence',
      () {
        final added = withSpecialtyToggled(
          PhotographerSkills.initial,
          'portrait',
          catalog,
        );
        expect(added.accepted, isTrue);
        expect(added.skills.specialties, [
          const SpecialtySkill(id: 'portrait'),
        ]);
        final withEv = withEvidence(added.skills, 'portrait', ['a']).skills;
        final removed = withSpecialtyToggled(withEv, 'portrait', catalog);
        expect(removed.skills.specialties, isEmpty);
        expect(removed.skills.evidencePostIds, isEmpty);
      },
    );

    test('the 7th genre is refused and nothing changes', () {
      final six = valid.copyWith(
        specialties: [
          for (final id in [
            'portrait',
            'wedding',
            'couple',
            'family',
            'graduation',
            'event',
          ])
            sp(id),
        ],
      );
      final e = withSpecialtyToggled(six, 'product', catalog);
      expect(e.rejection, SkillEditRejection.tooManyItems);
      expect(e.group, SkillGroup.specialty);
      expect(e.skills, six);
    });

    test('unknown or retired items cannot be chosen', () {
      expect(
        withSpecialtyToggled(valid, 'underwater', catalog).rejection,
        SkillEditRejection.notSelectable,
      );
      expect(
        withTagToggled(valid, SkillGroup.style, 'neon', catalog).rejection,
        SkillEditRejection.notSelectable,
      );
    });

    test('the 4th Chuyên sâu is refused and the old level is kept', () {
      final three = valid.copyWith(
        specialties: [
          sp('portrait', 3, ['a']),
          sp('wedding', 3, ['b']),
          sp('couple', 3, ['c']),
          sp('family'),
        ],
      );
      final e = withSpecialtyLevel(three, 'family', SkillLevels.expert);
      expect(e.rejection, SkillEditRejection.tooManyExpert);
      expect(e.skills.specialty('family')!.level, SkillLevels.proficient);
      expect(
        withSpecialtyLevel(three, 'portrait', 3).accepted,
        isTrue,
        reason: 'already expert',
      );
      expect(
        withSpecialtyLevel(
          three,
          'family',
          1,
        ).skills.specialty('family')!.level,
        1,
      );
    });

    test('level edits need a chosen genre and a level of 1..3', () {
      expect(() => withSpecialtyLevel(valid, 'food', 2), throwsArgumentError);
      expect(() => withSpecialtyLevel(valid, 'couple', 4), throwsArgumentError);
    });

    test('tag limits per group', () {
      var s = PhotographerSkills.initial;
      for (final id in ['natural_light', 'film', 'minimal', 'editorial']) {
        s = withTagToggled(s, SkillGroup.style, id, catalog).skills;
      }
      final fifth = withTagToggled(s, SkillGroup.style, 'documentary', catalog);
      expect(
        (fifth.rejection, fifth.group),
        (SkillEditRejection.tooManyItems, SkillGroup.style),
      );
      expect(
        withTagToggled(s, SkillGroup.style, 'film', catalog).skills.styles,
        ['natural_light', 'minimal', 'editorial'],
      );
      for (final id in ['en', 'zh', 'ko', 'ja']) {
        s = withTagToggled(s, SkillGroup.language, id, catalog).skills;
      }
      expect(s.languages, hasLength(5));
      expect(
        withTagToggled(s, SkillGroup.language, 'vi', catalog).skills.languages,
        hasLength(4),
        reason: 'unticking the last language is allowed; Tiếp tục reports it',
      );
      expect(
        () => withTagToggled(s, SkillGroup.specialty, 'portrait', catalog),
        throwsArgumentError,
      );
    });

    test('evidence: order kept, duplicates dropped, more than 3 refused', () {
      expect(
        withEvidence(valid, 'couple', [
          'b',
          'a',
          'b',
        ]).skills.specialty('couple')!.evidencePostIds,
        ['b', 'a'],
      );
      final e = withEvidence(valid, 'couple', ['a', 'b', 'c', 'd']);
      expect(e.rejection, SkillEditRejection.tooManyEvidence);
      expect(e.skills, valid);
      expect(() => withEvidence(valid, 'food', ['a']), throwsArgumentError);
    });

    test('years are stored as given and checked by validation', () {
      expect(withYearsExperience(valid, 7).yearsExperience, 7);
      expect(withYearsExperience(valid, null).yearsExperience, isNull);
    });

    test('deleted posts leave the evidence lists', () {
      final s = valid.copyWith(
        specialties: [
          sp('portrait', 3, ['a', 'gone']),
          sp('couple', 2, ['gone']),
        ],
      );
      final pruned = withoutMissingEvidence(s, {'a'});
      expect(pruned.specialty('portrait')!.evidencePostIds, ['a']);
      expect(pruned.specialty('couple')!.evidencePostIds, isEmpty);
    });
  });
}
