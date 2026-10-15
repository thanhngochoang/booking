import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';

List<String> _idsOf(String rules, String function) {
  final m = RegExp(
    'function $function\\(\\)\\s*\\{\\s*return\\s*\\[([^\\]]*)\\]',
  ).firstMatch(rules);
  expect(m, isNotNull, reason: '$function() not found in firestore.rules');
  return [
    for (final x in RegExp(r"'([a-z_]+)'").allMatches(m!.group(1)!))
      x.group(1)!,
  ];
}

void main() {
  test('firestore.rules accepts exactly the built-in catalogue ids', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    for (final (function, group) in [
      ('skillSpecialtyIds', SkillGroup.specialty),
      ('skillStyleIds', SkillGroup.style),
      ('skillExtraIds', SkillGroup.extra),
      ('skillLanguageIds', SkillGroup.language),
      ('skillAudienceIds', SkillGroup.audience),
    ]) {
      expect(
        _idsOf(rules, function),
        builtInSkillCatalog.ids(group),
        reason: function,
      );
    }
  });
}
