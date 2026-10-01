import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_completeness.dart';

void main() {
  test('weights add up to 100', () {
    expect(CompletenessStep.values.fold(0, (s, x) => s + x.points), 100);
  });

  test('empty: 0%, first thing to do is choosing a genre', () {
    final r = skillsCompleteness(PhotographerSkills.empty);
    expect(r.percent, 0);
    expect(r.missing, CompletenessStep.values);
    expect(r.next!.step, CompletenessStep.specialties);
    expect(r.next!.percentAfter, 65);
  });

  test('a new photographer with Vietnamese ticked starts at 10%', () {
    final r = skillsCompleteness(PhotographerSkills.initial);
    expect(r.percent, 10);
    expect(r.next!.percentAfter, 75);
  });

  test('one genre at Thành thạo earns genre, level and evidence points', () {
    const s = PhotographerSkills(
      specialties: [SpecialtySkill(id: 'portrait')],
      languages: ['vi'],
    );
    final r = skillsCompleteness(s);
    expect(r.percent, 75);
    expect(r.next!.step, CompletenessStep.styles);
    expect(r.next!.percentAfter, 85);
  });

  test('a Chuyên sâu genre without evidence is named in the hint', () {
    const s = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'couple'),
        SpecialtySkill(id: 'portrait', level: 3),
      ],
      styles: ['film'],
      extras: ['retouch'],
      languages: ['vi', 'en'],
      audiences: ['couple'],
    );
    final r = skillsCompleteness(s);
    expect(r.percent, 80);
    expect(r.missing, [CompletenessStep.evidence]);
    expect(r.next!.step, CompletenessStep.evidence);
    expect(r.next!.specialtyId, 'portrait');
    expect(r.next!.percentAfter, 100);
  });

  test('a complete profile is 100% with no hint', () {
    const s = PhotographerSkills(
      specialties: [
        SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['a']),
      ],
      styles: ['film'],
      extras: ['retouch'],
      languages: ['vi'],
      audiences: ['couple'],
    );
    final r = skillsCompleteness(s);
    expect(r.percent, 100);
    expect(r.missing, isEmpty);
    expect(r.next, isNull);
  });
}
