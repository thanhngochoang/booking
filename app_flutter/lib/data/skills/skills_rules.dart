import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';

enum SkillIssueCode {
  noSpecialty,
  noLanguage,
  tooManyItems,
  duplicateItem,
  unknownItem,
  retiredItem,
  invalidLevel,
  tooManyExpert,
  expertNeedsEvidence,
  tooManyEvidence,
  duplicateEvidence,
  invalidEvidenceId,
  yearsOutOfRange,
}

/// One reason the skills cannot be saved. [group] says which section to
/// show it in; [itemId] is the offending id (a genre for evidence/levels).
class SkillIssue {
  const SkillIssue(this.code, {this.group, this.itemId});

  final SkillIssueCode code;
  final SkillGroup? group;
  final String? itemId;

  @override
  bool operator ==(Object other) =>
      other is SkillIssue &&
      other.code == code &&
      other.group == group &&
      other.itemId == itemId;

  @override
  int get hashCode => Object.hash(code, group, itemId);

  @override
  String toString() => 'SkillIssue(${code.name}, ${group?.code}, $itemId)';
}

/// Same pattern as data-model ids and the Firestore rules.
final _postId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Everything that stops [s] from being saved, in the order the sections
/// appear on S08.02/S08.03. Ids already in [previous] may be retired items.
List<SkillIssue> validateSkills(
  PhotographerSkills s,
  TaxonomyCatalog catalog, {
  PhotographerSkills previous = PhotographerSkills.empty,
}) {
  final issues = <SkillIssue>[];

  void checkItems(SkillGroup group, List<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        issues.add(
          SkillIssue(SkillIssueCode.duplicateItem, group: group, itemId: id),
        );
      } else if (!catalog.isKnown(group, id)) {
        issues.add(
          SkillIssue(SkillIssueCode.unknownItem, group: group, itemId: id),
        );
      } else if (!catalog.isSelectable(group, id) &&
          !previous.tags(group).contains(id)) {
        issues.add(
          SkillIssue(SkillIssueCode.retiredItem, group: group, itemId: id),
        );
      }
    }
    if (ids.length > SkillLimits.maxFor(group)) {
      issues.add(SkillIssue(SkillIssueCode.tooManyItems, group: group));
    }
  }

  const g = SkillGroup.specialty;
  if (s.specialties.isEmpty) {
    issues.add(const SkillIssue(SkillIssueCode.noSpecialty, group: g));
  }
  checkItems(g, s.specialtyIds);
  for (final sp in s.specialties) {
    if (!SkillLevels.all.contains(sp.level)) {
      issues.add(
        SkillIssue(SkillIssueCode.invalidLevel, group: g, itemId: sp.id),
      );
    }
    final years = sp.years;
    if (years != null && (years < 0 || years > SkillLimits.maxYears)) {
      issues.add(
        SkillIssue(SkillIssueCode.yearsOutOfRange, group: g, itemId: sp.id),
      );
    }
    final ev = sp.evidencePostIds;
    if (ev.length > SkillLimits.maxEvidence) {
      issues.add(
        SkillIssue(SkillIssueCode.tooManyEvidence, group: g, itemId: sp.id),
      );
    }
    if (ev.toSet().length != ev.length) {
      issues.add(
        SkillIssue(SkillIssueCode.duplicateEvidence, group: g, itemId: sp.id),
      );
    }
    if (ev.any((id) => !_postId.hasMatch(id))) {
      issues.add(
        SkillIssue(SkillIssueCode.invalidEvidenceId, group: g, itemId: sp.id),
      );
    }
    if (sp.isExpert && ev.isEmpty) {
      issues.add(
        SkillIssue(SkillIssueCode.expertNeedsEvidence, group: g, itemId: sp.id),
      );
    }
  }
  if (s.expertCount > SkillLimits.maxExpert) {
    issues.add(const SkillIssue(SkillIssueCode.tooManyExpert, group: g));
  }
  checkItems(SkillGroup.style, s.styles);
  checkItems(SkillGroup.extra, s.extras);
  checkItems(SkillGroup.language, s.languages);
  if (s.languages.isEmpty) {
    issues.add(
      const SkillIssue(SkillIssueCode.noLanguage, group: SkillGroup.language),
    );
  }
  checkItems(SkillGroup.audience, s.audiences);
  final years = s.yearsExperience;
  if (years != null && (years < 0 || years > SkillLimits.maxYears)) {
    issues.add(const SkillIssue(SkillIssueCode.yearsOutOfRange));
  }
  return issues;
}

enum SkillEditRejection {
  tooManyItems,
  tooManyExpert,
  tooManyEvidence,
  notSelectable,
}

/// Result of one edit: the new skills, or the unchanged input plus why the
/// edit was refused ([group] tells which limit for `tooManyItems`).
class SkillEdit {
  const SkillEdit(this.skills, {this.rejection, this.group});

  final PhotographerSkills skills;
  final SkillEditRejection? rejection;
  final SkillGroup? group;

  bool get accepted => rejection == null;
}

/// Ticks or unticks a genre. A new genre starts at "Thành thạo"; unticking
/// removes its level and evidence.
SkillEdit withSpecialtyToggled(
  PhotographerSkills s,
  String id,
  TaxonomyCatalog catalog,
) {
  if (s.specialty(id) != null) {
    return SkillEdit(
      s.copyWith(
        specialties: [
          for (final sp in s.specialties)
            if (sp.id != id) sp,
        ],
      ),
    );
  }
  if (!catalog.isSelectable(SkillGroup.specialty, id)) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.notSelectable,
      group: SkillGroup.specialty,
    );
  }
  if (s.specialties.length >= SkillLimits.maxSpecialties) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyItems,
      group: SkillGroup.specialty,
    );
  }
  return SkillEdit(
    s.copyWith(
      specialties: [
        ...s.specialties,
        SpecialtySkill(id: id),
      ],
    ),
  );
}

/// Sets a chosen genre's level; a 4th "Chuyên sâu" is refused.
SkillEdit withSpecialtyLevel(PhotographerSkills s, String id, int level) {
  final current = s.specialty(id);
  if (current == null) {
    throw ArgumentError.value(id, 'id', 'genre is not chosen');
  }
  if (!SkillLevels.all.contains(level)) {
    throw ArgumentError.value(level, 'level', 'must be 1..3');
  }
  if (current.level == level) return SkillEdit(s);
  if (level == SkillLevels.expert && s.expertCount >= SkillLimits.maxExpert) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyExpert,
      group: SkillGroup.specialty,
    );
  }
  return SkillEdit(
    s.copyWith(
      specialties: [
        for (final sp in s.specialties)
          sp.id == id ? sp.copyWith(level: level) : sp,
      ],
    ),
  );
}

/// Ticks or unticks a style, extra skill, language or audience.
SkillEdit withTagToggled(
  PhotographerSkills s,
  SkillGroup group,
  String id,
  TaxonomyCatalog catalog,
) {
  if (group == SkillGroup.specialty) {
    throw ArgumentError.value(group, 'group', 'use withSpecialtyToggled');
  }
  final ids = s.tags(group);
  if (ids.contains(id)) {
    return SkillEdit(
      s.withTags(group, [
        for (final x in ids)
          if (x != id) x,
      ]),
    );
  }
  if (!catalog.isSelectable(group, id)) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.notSelectable,
      group: group,
    );
  }
  if (ids.length >= SkillLimits.maxFor(group)) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyItems,
      group: group,
    );
  }
  return SkillEdit(s.withTags(group, [...ids, id]));
}

/// Replaces a genre's evidence posts (order kept, duplicates dropped).
SkillEdit withEvidence(
  PhotographerSkills s,
  String specialtyId,
  List<String> postIds,
) {
  if (s.specialty(specialtyId) == null) {
    throw ArgumentError.value(
      specialtyId,
      'specialtyId',
      'genre is not chosen',
    );
  }
  final unique = <String>{...postIds}.toList();
  if (unique.length > SkillLimits.maxEvidence) {
    return SkillEdit(
      s,
      rejection: SkillEditRejection.tooManyEvidence,
      group: SkillGroup.specialty,
    );
  }
  return SkillEdit(
    s.copyWith(
      specialties: [
        for (final sp in s.specialties)
          sp.id == specialtyId ? sp.copyWith(evidencePostIds: unique) : sp,
      ],
    ),
  );
}

PhotographerSkills withYearsExperience(PhotographerSkills s, int? years) =>
    s.copyWith(yearsExperience: years);

/// Drops evidence ids whose post no longer exists (spec S08.04: a deleted post
/// leaves the evidence and the S08.02 warning comes back).
PhotographerSkills withoutMissingEvidence(
  PhotographerSkills s,
  Set<String> existingPostIds,
) => s.copyWith(
  specialties: [
    for (final sp in s.specialties)
      sp.copyWith(
        evidencePostIds: [
          for (final id in sp.evidencePostIds)
            if (existingPostIds.contains(id)) id,
        ],
      ),
  ],
);
