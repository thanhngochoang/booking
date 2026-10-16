import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';

void main() {
  test('reads what is there and falls back for the rest', () {
    expect(
      introFromFirestore({
        'bio': 'Ánh sáng tự nhiên.',
        'equipment': ['Sony A7 IV', 3, 'Godox V1'],
        'onboardingComplete': true,
        'verified': true,
        'skills': {'yearsExperience': 6},
      }),
      const PhotographerIntro(
        bio: 'Ánh sáng tự nhiên.',
        equipment: ['Sony A7 IV', 'Godox V1'],
        onboardingComplete: true,
        acceptingOrders: true,
        verified: true,
      ),
    );
    expect(
      introFromFirestore({'bio': 12, 'equipment': 'Sony'}),
      const PhotographerIntro(),
    );
  });

  test('reads verified, businessVerified and providerType (S21)', () {
    final i = introFromFirestore({
      'verified': true,
      'businessVerified': true,
      'providerType': 'studio',
    });
    expect(i.verified, isTrue);
    expect(i.businessVerified, isTrue);
    expect(i.providerType, ProviderType.studio);
    final none = introFromFirestore({'providerType': 'x'});
    expect(none.verified, isFalse);
    expect(none.businessVerified, isFalse);
    expect(none.providerType, ProviderType.individual);
  });

  test('PhotographerIntro.acceptingOrders: stored flag wins; '
      'missing flag falls back to verified && onboardingComplete', () {
    bool accepting(Map<String, dynamic> d) =>
        introFromFirestore(d).acceptingOrders;
    expect(
      accepting({
        'acceptingOrders': false,
        'verified': true,
        'onboardingComplete': true,
      }),
      isFalse,
    );
    expect(
      accepting({
        'acceptingOrders': true,
        'verified': false,
        'onboardingComplete': false,
      }),
      isTrue,
    );
    expect(accepting({'verified': true, 'onboardingComplete': true}), isTrue);
    expect(accepting({'verified': true, 'onboardingComplete': false}), isFalse);
    expect(accepting({'verified': false, 'onboardingComplete': true}), isFalse);
    expect(accepting({'acceptingOrders': 'yes', 'verified': true}), isFalse);
    expect(accepting({}), isFalse);
    expect(
      const PhotographerIntro(acceptingOrders: true),
      isNot(const PhotographerIntro()),
    );
  });

  test('writes only the two intro fields', () {
    expect(introToFirestore(bio: 'B', equipment: const ['X']), {
      'bio': 'B',
      'equipment': ['X'],
    });
  });

  test(
    'the fake keeps the onboarding flag, streams changes and counts listeners',
    () async {
      final repo = FakePhotographerIntroRepository()
        ..seed(
          'p1',
          const PhotographerIntro(
            onboardingComplete: true,
            acceptingOrders: true,
            bio: 'Cũ',
          ),
        );
      final seen = <PhotographerIntro?>[];
      final sub = repo.watch('p1').listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(repo.watchers, 1);
      await repo.save('p1', bio: 'Mới', equipment: const ['Sony']);
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.last,
        const PhotographerIntro(
          bio: 'Mới',
          equipment: ['Sony'],
          onboardingComplete: true,
          acceptingOrders: true,
        ),
      );
      expect(await repo.get('p2'), isNull);
      await sub.cancel();
      expect(repo.watchers, 0);
    },
  );

  test('a failing save throws and stores nothing', () async {
    final repo = FakePhotographerIntroRepository(failSave: true);
    await expectLater(
      repo.save('p1', bio: 'x', equipment: const []),
      throwsStateError,
    );
    expect(repo.stored('p1'), isNull);
  });
}
