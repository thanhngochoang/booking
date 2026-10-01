import 'package:photobooking/data/skills/photographer_skills.dart';

/// The parts of the "Độ khớp hồ sơ" score (spec 3e.2), highest first.
/// The server Function that writes `skills.completeness` uses the same
/// weights; keep both in sync.
enum CompletenessStep {
  specialties(25),
  levels(20),
  evidence(20),
  styles(10),
  languages(10),
  audiences(10),
  extras(5);

  const CompletenessStep(this.points);
  final int points;
}

/// The next thing to do and what the score becomes once it is done.
class CompletenessHint {
  const CompletenessHint(
    this.step, {
    required this.percentAfter,
    this.specialtyId,
  });

  final CompletenessStep step;
  final int percentAfter;

  /// For [CompletenessStep.evidence]: the first level-3 genre without posts.
  final String? specialtyId;
}

class CompletenessReport {
  const CompletenessReport({
    required this.percent,
    required this.missing,
    this.next,
  });

  /// 0..100; shown only to the photographer.
  final int percent;
  final List<CompletenessStep> missing;
  final CompletenessHint? next;
}

bool _done(PhotographerSkills s, CompletenessStep step) => switch (step) {
  CompletenessStep.specialties => s.specialties.isNotEmpty,
  CompletenessStep.levels =>
    s.specialties.isNotEmpty &&
        s.specialties.every((x) => SkillLevels.all.contains(x.level)),
  CompletenessStep.evidence =>
    s.specialties.isNotEmpty &&
        s.specialties.every((x) => !x.isExpert || x.evidencePostIds.isNotEmpty),
  CompletenessStep.styles => s.styles.isNotEmpty,
  CompletenessStep.languages => s.languages.isNotEmpty,
  CompletenessStep.audiences => s.audiences.isNotEmpty,
  CompletenessStep.extras => s.extras.isNotEmpty,
};

int _percent(PhotographerSkills s) => CompletenessStep.values
    .where((step) => _done(s, step))
    .fold(0, (sum, step) => sum + step.points);

/// Score and next step for [s]; pure, so S38 updates it on every tap.
CompletenessReport skillsCompleteness(PhotographerSkills s) {
  final missing = [
    for (final step in CompletenessStep.values)
      if (!_done(s, step)) step,
  ];
  final percent = _percent(s);
  if (missing.isEmpty) {
    return CompletenessReport(percent: percent, missing: missing);
  }
  final step = missing.first;
  final after = switch (step) {
    CompletenessStep.specialties => s.copyWith(
      specialties: const [SpecialtySkill(id: '_')],
    ),
    CompletenessStep.levels => s.copyWith(
      specialties: [
        for (final x in s.specialties)
          SkillLevels.all.contains(x.level)
              ? x
              : x.copyWith(level: SkillLevels.proficient),
      ],
    ),
    CompletenessStep.evidence => s.copyWith(
      specialties: [
        for (final x in s.specialties)
          x.isExpert && x.evidencePostIds.isEmpty
              ? x.copyWith(evidencePostIds: const ['_'])
              : x,
      ],
    ),
    CompletenessStep.styles => s.copyWith(styles: const ['_']),
    CompletenessStep.languages => s.copyWith(languages: const ['_']),
    CompletenessStep.audiences => s.copyWith(audiences: const ['_']),
    CompletenessStep.extras => s.copyWith(extras: const ['_']),
  };
  String? specialtyId;
  if (step == CompletenessStep.evidence) {
    specialtyId = s.specialties
        .firstWhere((x) => x.isExpert && x.evidencePostIds.isEmpty)
        .id;
  }
  return CompletenessReport(
    percent: percent,
    missing: missing,
    next: CompletenessHint(
      step,
      percentAfter: _percent(after),
      specialtyId: specialtyId,
    ),
  );
}
