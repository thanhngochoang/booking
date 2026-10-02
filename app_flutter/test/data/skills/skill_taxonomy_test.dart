import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

void main() {
  test('each group mirrors the seed list of relational-schema.md §6', () {
    final c = builtInSkillCatalog;
    expect(c.ids(SkillGroup.specialty), [
      'portrait',
      'wedding',
      'couple',
      'family',
      'graduation',
      'event',
      'product',
      'travel',
      'fashion',
      'food',
      'real_estate',
      'newborn',
      'street',
      'commercial',
    ]);
    expect(c.ids(SkillGroup.style), [
      'natural_light',
      'film',
      'minimal',
      'editorial',
      'documentary',
    ]);
    expect(c.ids(SkillGroup.extra), [
      'retouch',
      'posing',
      'video',
      'drone',
      'studio',
      'kids',
      'pets',
      'low_light',
      'outdoor',
    ]);
    expect(c.ids(SkillGroup.language), ['vi', 'en', 'zh', 'ko', 'ja']);
    expect(c.ids(SkillGroup.audience), [
      'couple',
      'family_kids',
      'business',
      'foreigner',
      'shy_subjects',
    ]);
  });

  test(
    'ids are snake_case codes, unique inside their group, labels are not empty',
    () {
      for (final list in [
        kSpecialties,
        kStyles,
        kExtras,
        kLanguages,
        kAudiences,
      ]) {
        expect(list.map((o) => o.id).toSet(), hasLength(list.length));
        for (final o in list) {
          expect(o.id, matches(RegExp(r'^[a-z][a-z_]*$')));
          expect(o.labelVi.trim(), isNotEmpty);
        }
      }
    },
  );

  test('the same code may live in two groups without clashing', () {
    final c = builtInSkillCatalog;
    expect(c.label(SkillGroup.specialty, 'couple'), 'Cặp đôi');
    expect(c.label(SkillGroup.audience, 'couple'), 'Cặp đôi');
    expect(c.isKnown(SkillGroup.style, 'couple'), isFalse);
  });

  test('labels follow the spec and the mock', () {
    final c = builtInSkillCatalog;
    expect(c.label(SkillGroup.specialty, 'graduation'), 'Kỷ yếu');
    expect(c.label(SkillGroup.extra, 'posing'), 'Chỉ đạo tạo dáng');
    expect(c.label(SkillGroup.extra, 'drone'), 'Flycam');
    expect(c.label(SkillGroup.language, 'vi'), 'Tiếng Việt');
    expect(c.label(SkillGroup.language, 'ko'), '한국어');
    expect(c.label(SkillGroup.audience, 'shy_subjects'), 'Người ngại ống kính');
    expect(extraLabel('low_light'), 'Thiếu sáng');
    expect(languageLabel('en'), 'English');
    expect(audienceLabel('foreigner'), 'Khách nước ngoài');
  });

  test('unknown codes render as themselves', () {
    expect(builtInSkillCatalog.label(SkillGroup.style, 'neon'), 'neon');
    expect(extraLabel('juggling'), 'juggling');
    expect(builtInSkillCatalog.item(SkillGroup.style, 'neon'), isNull);
  });

  test('retired items stay readable, are not offered, and are kept when already chosen', () {
    final c = TaxonomyCatalog(const [
      TaxonomyItem(id: 'b', group: SkillGroup.style, labelVi: 'B', order: 2),
      TaxonomyItem(id: 'a', group: SkillGroup.style, labelVi: 'A', order: 1),
      TaxonomyItem(
        id: 'old',
        group: SkillGroup.style,
        labelVi: 'Cũ',
        order: 0,
        active: false,
      ),
    ]);
    expect(c.ids(SkillGroup.style), ['a', 'b']);
    expect(c.isKnown(SkillGroup.style, 'old'), isTrue);
    expect(c.isSelectable(SkillGroup.style, 'old'), isFalse);
    expect(c.label(SkillGroup.style, 'old'), 'Cũ');
    expect(c.options(SkillGroup.style, keep: ['old']).map((i) => i.id), [
      'old',
      'a',
      'b',
    ]);
    expect(c.options(SkillGroup.extra), isEmpty);
  });

  test('group codes round-trip', () {
    for (final g in SkillGroup.values) {
      expect(SkillGroup.fromCode(g.code), g);
    }
    expect(SkillGroup.fromCode('area'), isNull);
    expect(SkillGroup.fromCode(null), isNull);
  });
}
