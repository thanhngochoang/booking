import 'package:flutter/foundation.dart' show listEquals;

import 'package:photobooking/data/skills/skill_taxonomy.dart';

/// Specialty levels. The data model keeps them as the numbers 1..3 on
/// purpose (they have a real order); the recommender weighs them
/// 0.4 / 0.7 / 1.0 (spec 3e.6).
abstract final class SkillLevels {
  static const basic = 1;
  static const proficient = 2;
  static const expert = 3;
  static const all = [basic, proficient, expert];
}

/// Limits of spec 3e.2, shared by validation, edits, widgets and the
/// Firestore rules (which repeat the numbers).
abstract final class SkillLimits {
  static const schemaVersion = 1;
  static const maxSpecialties = 6;
  static const maxExpert = 3;
  static const maxEvidence = 3;
  static const maxStyles = 4;
  static const maxExtras = 8;
  static const maxLanguages = 5;
  static const maxAudiences = 4;
  static const maxYears = 50;

  static int maxFor(SkillGroup group) => switch (group) {
    SkillGroup.specialty => maxSpecialties,
    SkillGroup.style => maxStyles,
    SkillGroup.extra => maxExtras,
    SkillGroup.language => maxLanguages,
    SkillGroup.audience => maxAudiences,
  };
}

/// One chosen genre with its level and evidence posts.
class SpecialtySkill {
  const SpecialtySkill({
    required this.id,
    this.level = SkillLevels.proficient,
    this.years,
    this.evidencePostIds = const [],
  });

  final String id;

  /// 1 Cơ bản, 2 Thành thạo, 3 Chuyên sâu.
  final int level;

  /// Optional years in this genre (kept as read; not edited in S08.02).
  final int? years;

  /// The photographer's own post ids, 0..3, in the order they were picked.
  final List<String> evidencePostIds;

  bool get isExpert => level == SkillLevels.expert;

  SpecialtySkill copyWith({int? level, List<String>? evidencePostIds}) =>
      SpecialtySkill(
        id: id,
        level: level ?? this.level,
        years: years,
        evidencePostIds: evidencePostIds ?? this.evidencePostIds,
      );

  @override
  bool operator ==(Object other) =>
      other is SpecialtySkill &&
      other.id == id &&
      other.level == level &&
      other.years == years &&
      listEquals(other.evidencePostIds, evidencePostIds);

  @override
  int get hashCode =>
      Object.hash(id, level, years, Object.hashAll(evidencePostIds));

  @override
  String toString() => 'SpecialtySkill($id, $level, $years, $evidencePostIds)';
}

const Object _keep = Object();

/// The client-owned part of `photographers/{uid}.skills` (spec 3e.3).
/// `completeness` and `updatedAt` belong to the server and are not here.
class PhotographerSkills {
  const PhotographerSkills({
    this.specialties = const [],
    this.styles = const [],
    this.extras = const [],
    this.languages = const [],
    this.audiences = const [],
    this.yearsExperience,
  });

  static const empty = PhotographerSkills();

  /// Where a photographer without saved skills starts: Vietnamese ticked.
  static const initial = PhotographerSkills(languages: ['vi']);

  final List<SpecialtySkill> specialties;
  final List<String> styles;
  final List<String> extras;
  final List<String> languages;
  final List<String> audiences;
  final int? yearsExperience;

  List<String> get specialtyIds => [for (final s in specialties) s.id];

  SpecialtySkill? specialty(String id) {
    for (final s in specialties) {
      if (s.id == id) return s;
    }
    return null;
  }

  int get expertCount => specialties.where((s) => s.isExpert).length;

  /// Every post used as evidence, for the small badge on S03.01.
  Set<String> get evidencePostIds => {
    for (final s in specialties) ...s.evidencePostIds,
  };

  /// The chosen ids of one group.
  List<String> tags(SkillGroup group) => switch (group) {
    SkillGroup.specialty => specialtyIds,
    SkillGroup.style => styles,
    SkillGroup.extra => extras,
    SkillGroup.language => languages,
    SkillGroup.audience => audiences,
  };

  bool get isEmpty => this == empty;

  /// [yearsExperience] takes an `int?`; pass `null` to clear it.
  PhotographerSkills copyWith({
    List<SpecialtySkill>? specialties,
    List<String>? styles,
    List<String>? extras,
    List<String>? languages,
    List<String>? audiences,
    Object? yearsExperience = _keep,
  }) => PhotographerSkills(
    specialties: specialties ?? this.specialties,
    styles: styles ?? this.styles,
    extras: extras ?? this.extras,
    languages: languages ?? this.languages,
    audiences: audiences ?? this.audiences,
    yearsExperience: identical(yearsExperience, _keep)
        ? this.yearsExperience
        : yearsExperience as int?,
  );

  /// Replaces the ids of a tag group; specialties have their own rows.
  PhotographerSkills withTags(SkillGroup group, List<String> ids) =>
      switch (group) {
        SkillGroup.specialty => throw ArgumentError.value(
          group,
          'group',
          'specialties are edited as SpecialtySkill rows',
        ),
        SkillGroup.style => copyWith(styles: ids),
        SkillGroup.extra => copyWith(extras: ids),
        SkillGroup.language => copyWith(languages: ids),
        SkillGroup.audience => copyWith(audiences: ids),
      };

  @override
  bool operator ==(Object other) =>
      other is PhotographerSkills &&
      listEquals(other.specialties, specialties) &&
      listEquals(other.styles, styles) &&
      listEquals(other.extras, extras) &&
      listEquals(other.languages, languages) &&
      listEquals(other.audiences, audiences) &&
      other.yearsExperience == yearsExperience;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(specialties),
    Object.hashAll(styles),
    Object.hashAll(extras),
    Object.hashAll(languages),
    Object.hashAll(audiences),
    yearsExperience,
  );

  @override
  String toString() => 'PhotographerSkills(${skillsToMap(this)})';
}

/// The map written to `photographers/{uid}.skills` (and the device draft's
/// JSON). `yearsExperience` is always present (null when unknown) so a merge
/// write clears an old value; server fields are never included.
Map<String, Object?> skillsToMap(PhotographerSkills s) => {
  'schemaVersion': SkillLimits.schemaVersion,
  'specialties': [
    for (final sp in s.specialties)
      {
        'id': sp.id,
        'level': sp.level,
        if (sp.years != null) 'years': sp.years,
        'evidencePostIds': [...sp.evidencePostIds],
      },
  ],
  'styles': [...s.styles],
  'extras': [...s.extras],
  'languages': [...s.languages],
  'audiences': [...s.audiences],
  'yearsExperience': s.yearsExperience,
};

/// Tolerant reader: malformed entries are dropped and a bad level becomes
/// [SkillLevels.proficient], so old or partial documents still open.
PhotographerSkills skillsFromMap(Object? raw) {
  if (raw is! Map) return PhotographerSkills.empty;
  final specialties = <SpecialtySkill>[];
  final seen = <String>{};
  final list = raw['specialties'];
  if (list is List) {
    for (final e in list) {
      if (e is! Map) continue;
      final id = e['id'];
      if (id is! String || !seen.add(id)) continue;
      final level = e['level'];
      final years = e['years'];
      specialties.add(
        SpecialtySkill(
          id: id,
          level: level is int && SkillLevels.all.contains(level)
              ? level
              : SkillLevels.proficient,
          years: years is int ? years : null,
          evidencePostIds: _strings(e['evidencePostIds']),
        ),
      );
    }
  }
  final years = raw['yearsExperience'];
  return PhotographerSkills(
    specialties: specialties,
    styles: _strings(raw['styles']),
    extras: _strings(raw['extras']),
    languages: _strings(raw['languages']),
    audiences: _strings(raw['audiences']),
    yearsExperience: years is int ? years : null,
  );
}

List<String> _strings(Object? v) => v is List
    ? [
        ...<String>{
          for (final x in v)
            if (x is String) x,
        },
      ]
    : const [];
