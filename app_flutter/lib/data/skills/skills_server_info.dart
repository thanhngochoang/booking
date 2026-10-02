import 'package:photobooking/data/skills/photographer_skills.dart';

/// Step codes of `skills.completenessNext`, written by the Cloud Function
/// `onPhotographerWrite` (`COMPLETENESS_STEPS` in packages/domain), highest
/// weight first. The app shows them; it never computes them.
enum CompletenessStepCode {
  specialties,
  levels,
  evidence,
  styles,
  languages,
  audiences,
  extras;

  static CompletenessStepCode? fromCode(Object? code) {
    for (final c in values) {
      if (c.name == code) return c;
    }
    return null;
  }
}

/// What the server wrote into `photographers/{uid}.skills`. All null until
/// the Function has scored the skills once.
class SkillsServerInfo {
  const SkillsServerInfo({
    this.completeness,
    this.next,
    this.nextAfter,
    this.evidenceRemovedAt,
  });

  static const none = SkillsServerInfo();

  /// "Độ khớp hồ sơ", 0..100.
  final int? completeness;

  /// The first missing step; null when complete or not scored yet.
  final CompletenessStepCode? next;

  /// The score once [next] is done (`skills.completenessNextAfter`, 0..100);
  /// null when complete or not scored yet.
  final int? nextAfter;

  /// UTC instant of the last time the Function removed invalid evidence.
  final DateTime? evidenceRemovedAt;

  @override
  bool operator ==(Object other) =>
      other is SkillsServerInfo &&
      other.completeness == completeness &&
      other.next == next &&
      other.nextAfter == nextAfter &&
      other.evidenceRemovedAt == evidenceRemovedAt;

  @override
  int get hashCode =>
      Object.hash(completeness, next, nextAfter, evidenceRemovedAt);

  @override
  String toString() =>
      'SkillsServerInfo($completeness, ${next?.name}, $nextAfter, '
      '$evidenceRemovedAt)';
}

/// Reads the server fields of a stored skills map. [instant] turns the stored
/// time value into a [DateTime] (the adapter passes its own converter, so no
/// Firebase type reaches this file). Anything malformed reads as null.
SkillsServerInfo skillsServerInfoFromMap(
  Object? raw,
  DateTime? Function(Object? value) instant,
) {
  if (raw is! Map) return SkillsServerInfo.none;
  return SkillsServerInfo(
    completeness: _percent(raw['completeness']),
    next: CompletenessStepCode.fromCode(raw['completenessNext']),
    nextAfter: _percent(raw['completenessNextAfter']),
    evidenceRemovedAt: instant(raw['evidenceRemovedAt'])?.toUtc(),
  );
}

int? _percent(Object? v) => v is int && v >= 0 && v <= 100 ? v : null;

/// One read of `photographers/{uid}.skills`: the client part and the
/// server's part.
class SkillsSnapshot {
  const SkillsSnapshot(this.skills, [this.server = SkillsServerInfo.none]);

  final PhotographerSkills skills;
  final SkillsServerInfo server;

  @override
  bool operator ==(Object other) =>
      other is SkillsSnapshot &&
      other.skills == skills &&
      other.server == server;

  @override
  int get hashCode => Object.hash(skills, server);
}
