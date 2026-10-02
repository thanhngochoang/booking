import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/firestore_public_profile_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';

import '../../support/content_fixtures.dart';

void main() {
  test('maps the public user and photographer documents, never a phone', () {
    final p = photographerProfileFrom(
      id: 'p1',
      user: {'displayName': 'Minh Trí', 'avatarUrl': 'https://img.test/a.jpg'},
      photographer: {
        'verified': true,
        'bio': 'Ánh sáng tự nhiên.',
        'equipment': ['Sony A7 IV'],
        'onboardingComplete': true,
        'serviceArea': {'city': 'Quận 3', 'radiusKm': 15},
        'stats': {
          'rating': 4.9,
          'reviewCount': 58,
          'completedCount': 112,
          'responseMinutes': 60,
        },
      },
    );
    expect(p.id, 'p1');
    expect(
      (p.summary.displayName, p.summary.verified, p.summary.areaLabel),
      ('Minh Trí', true, 'Quận 3'),
    );
    expect((p.summary.reviewCount, p.summary.completedCount), (58, 112));
    expect(
      p.intro,
      const PhotographerIntro(
        bio: 'Ánh sáng tự nhiên.',
        equipment: ['Sony A7 IV'],
        onboardingComplete: true,
      ),
    );
    expect(p.published, isTrue);
  });

  test('the fake loads by id, counts loads and fails on request', () async {
    final repo = FakePublicProfileRepository([
      PhotographerProfile(summary: fixturePhotographer('p1')),
    ]);
    expect((await repo.load('p1'))!.published, isFalse);
    expect(await repo.load('nobody'), isNull);
    expect(repo.loads, 2);
    repo.failWith = StateError('offline');
    await expectLater(repo.load('p1'), throwsStateError);
  });
}
