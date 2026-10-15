import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';

const full = PhotographerSkills(
  specialties: [
    SpecialtySkill(
      id: 'portrait',
      level: 3,
      years: 6,
      evidencePostIds: ['p1', 'p2'],
    ),
    SpecialtySkill(id: 'couple'),
  ],
  styles: ['natural_light', 'film'],
  extras: ['retouch', 'posing'],
  languages: ['vi', 'en'],
  audiences: ['couple', 'shy_subjects'],
  yearsExperience: 6,
);

void main() {
  test('writes the spec 3e.3 shape, without server fields', () {
    expect(skillsToMap(full), {
      'schemaVersion': 1,
      'specialties': [
        {
          'id': 'portrait',
          'level': 3,
          'years': 6,
          'evidencePostIds': ['p1', 'p2'],
        },
        {'id': 'couple', 'level': 2, 'evidencePostIds': <String>[]},
      ],
      'styles': ['natural_light', 'film'],
      'extras': ['retouch', 'posing'],
      'languages': ['vi', 'en'],
      'audiences': ['couple', 'shy_subjects'],
      'yearsExperience': 6,
    });
    expect(skillsToMap(PhotographerSkills.empty)['yearsExperience'], isNull);
    expect(skillsToMap(full).containsKey('completeness'), isFalse);
  });

  test('round-trips through the map and through JSON', () {
    expect(skillsFromMap(skillsToMap(full)), full);
    expect(skillsFromMap(jsonDecode(jsonEncode(skillsToMap(full)))), full);
  });

  test('reads missing or broken data without throwing', () {
    expect(skillsFromMap(null), PhotographerSkills.empty);
    expect(skillsFromMap('x'), PhotographerSkills.empty);
    final s = skillsFromMap({
      'specialties': [
        {'id': 'portrait', 'level': 9},
        {'id': 'portrait', 'level': 1},
        {'level': 2},
        'junk',
        {
          'id': 'wedding',
          'level': 3,
          'evidencePostIds': ['a', 7, 'a'],
        },
      ],
      'styles': ['film', 3, 'film'],
      'languages': 'vi',
      'yearsExperience': '6',
      'completeness': 72,
    });
    expect(s.specialties, const [
      SpecialtySkill(id: 'portrait'),
      SpecialtySkill(id: 'wedding', level: 3, evidencePostIds: ['a']),
    ]);
    expect(s.styles, ['film']);
    expect(s.languages, isEmpty);
    expect(s.yearsExperience, isNull);
  });

  test('derived values', () {
    expect(full.specialtyIds, ['portrait', 'couple']);
    expect(full.expertCount, 1);
    expect(full.evidencePostIds, {'p1', 'p2'});
    expect(full.specialty('couple')!.level, SkillLevels.proficient);
    expect(full.specialty('food'), isNull);
    expect(full.tags(SkillGroup.audience), ['couple', 'shy_subjects']);
    expect(full.tags(SkillGroup.specialty), ['portrait', 'couple']);
    expect(PhotographerSkills.empty.isEmpty, isTrue);
    expect(full.isEmpty, isFalse);
    expect(PhotographerSkills.initial.languages, ['vi']);
  });

  test('value equality, copyWith and withTags', () {
    expect(skillsFromMap(skillsToMap(full)).hashCode, full.hashCode);
    expect(full.copyWith(yearsExperience: null).yearsExperience, isNull);
    expect(full.copyWith().yearsExperience, 6);
    expect(full.withTags(SkillGroup.style, ['minimal']).styles, ['minimal']);
    expect(full.withTags(SkillGroup.language, ['ja']).languages, ['ja']);
    expect(
      () => full.withTags(SkillGroup.specialty, const []),
      throwsArgumentError,
    );
    expect(full == full.copyWith(styles: ['film', 'natural_light']), isFalse);
    expect(
      const SpecialtySkill(id: 'x', years: 2).copyWith(level: 3),
      const SpecialtySkill(id: 'x', level: 3, years: 2),
    );
  });

  test('limits match spec 3e.2', () {
    expect(SkillLimits.maxFor(SkillGroup.specialty), 6);
    expect(SkillLimits.maxFor(SkillGroup.style), 4);
    expect(SkillLimits.maxFor(SkillGroup.extra), 8);
    expect(SkillLimits.maxFor(SkillGroup.language), 5);
    expect(SkillLimits.maxFor(SkillGroup.audience), 4);
    expect(SkillLimits.maxExpert, 3);
    expect(SkillLimits.maxEvidence, 3);
    expect(SkillLimits.maxYears, 50);
    expect(SkillLevels.all, [1, 2, 3]);
  });
}
