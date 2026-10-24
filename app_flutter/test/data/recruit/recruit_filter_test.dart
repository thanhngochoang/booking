import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

RecruitPost _post({
  List<String> areas = const ['hcm-q1', 'hcm-q3'],
  List<String> specialties = const ['wedding'],
}) => RecruitPost(
  id: 'p1',
  studioId: 'cuc',
  studioName: 'Studio Cúc',
  studioAvatarUrl: null,
  studioBusinessVerified: false,
  kind: RecruitKind.collaborator,
  title: 'Tuyển CTV chụp cưới',
  specialties: specialties,
  areas: areas,
  frequency: RecruitFrequency.weekly,
  fee: const NegotiableFee(),
  requirements: '',
  status: RecruitPostStatus.open,
  renewed: false,
  applicationCount: 0,
  matchKeys: [
    for (final a in areas)
      for (final s in specialties) 'a=$a|s=$s',
  ],
  createdAt: DateTime.utc(2026, 10, 20),
  expiresAt: DateTime.utc(2026, 11, 19),
);

void main() {
  test('recruitFilterKey matches the domain format', () {
    // The cases of packages/domain/test/recruit.test.ts
    // "recruitFilterKey orders kind, area, specialty".
    expect(
      recruitFilterKey(
        specialty: 'wedding',
        kind: RecruitKind.member,
        area: 'hue',
      ),
      'k=member|a=hue|s=wedding',
    );
    expect(recruitFilterKey(area: 'hue'), 'a=hue');
    expect(recruitFilterKey(), '');
    // Keys of "recruitFilterKeys has every non-empty combination".
    expect(recruitFilterKey(kind: RecruitKind.collaborator), 'k=collaborator');
    expect(
      recruitFilterKey(kind: RecruitKind.collaborator, area: 'hcm-q3'),
      'k=collaborator|a=hcm-q3',
    );
    expect(
      recruitFilterKey(area: 'hcm-q1', specialty: 'wedding'),
      'a=hcm-q1|s=wedding',
    );
    expect(
      recruitFilterKey(kind: RecruitKind.collaborator, specialty: 'family'),
      'k=collaborator|s=family',
    );
  });

  test('RecruitFilter.key and isEmpty follow recruitFilterKey', () {
    expect(const RecruitFilter().isEmpty, isTrue);
    expect(const RecruitFilter().key, '');
    const f = RecruitFilter(kind: RecruitKind.member, specialty: 'portrait');
    expect(f.isEmpty, isFalse);
    expect(f.key, 'k=member|s=portrait');
    expect(const RecruitFilter(studioId: 'cuc').isEmpty, isFalse);
  });

  test('recruitMatchScore 2/1/0', () {
    const viewer = ['a=hcm-q1|s=wedding', 'a=hcm-q7|s=wedding'];
    // An area and a specialty both match.
    expect(recruitMatchScore(_post(), viewer), 2);
    // Only the area matches.
    expect(recruitMatchScore(_post(specialties: ['family']), viewer), 1);
    // Only the specialty matches.
    expect(recruitMatchScore(_post(areas: ['hue']), viewer), 1);
    // Nothing matches; a viewer without keys (studio, customer mode) is 0.
    expect(
      recruitMatchScore(_post(areas: ['hue'], specialties: ['family']), viewer),
      0,
    );
    expect(recruitMatchScore(_post(), const []), 0);
  });

  test('sortByMatch puts score 2 first, then newer posts', () {
    const viewer = ['a=hcm-q1|s=wedding'];
    final older2 = _post();
    final newer0 = RecruitPost(
      id: 'p2',
      studioId: 'x',
      studioName: 'X',
      studioAvatarUrl: null,
      studioBusinessVerified: false,
      kind: RecruitKind.member,
      title: 'Tin khác hoàn toàn',
      specialties: const ['food'],
      areas: const ['hue'],
      frequency: RecruitFrequency.occasional,
      fee: const NegotiableFee(),
      requirements: '',
      status: RecruitPostStatus.open,
      renewed: false,
      applicationCount: 0,
      matchKeys: const ['a=hue|s=food'],
      createdAt: DateTime.utc(2026, 10, 22),
      expiresAt: DateTime.utc(2026, 11, 21),
    );
    expect(sortByMatch([newer0, older2], viewer).map((p) => p.id), [
      'p1',
      'p2',
    ]);
    expect(sortByMatch([older2, newer0], const []).map((p) => p.id), [
      'p2',
      'p1',
    ]);
  });
}
