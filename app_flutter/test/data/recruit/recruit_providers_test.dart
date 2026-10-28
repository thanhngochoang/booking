import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

import '../../support/recruit_world.dart';

void main() {
  test(
    'the providers read the signed-in account through the repository',
    () async {
      final world = RecruitWorld(uid: 'cuc');
      world.recruits
        ..setFacts('cuc', makeProviderFacts())
        ..setCounters('cuc', const RecruitCounters(openPostCount: 2))
        ..seedPost(makeRecruitPost(id: 'a'))
        ..seedPost(makeRecruitPost(id: 'b', status: RecruitPostStatus.closed));
      final c = ProviderContainer(overrides: world.overrides);
      addTearDown(c.dispose);
      c.listen(myProviderFactsProvider, (_, _) {});
      c.listen(myRecruitCountersProvider, (_, _) {});
      expect(await c.read(myProviderFactsProvider.future), makeProviderFacts());
      expect((await c.read(myRecruitCountersProvider.future)).openPostCount, 2);
      expect(await c.read(studioOpenRecruitCountProvider('cuc').future), 1);
    },
  );

  test('signed out: no facts and zero counters', () async {
    final world = RecruitWorld();
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        recruitRepositoryProvider.overrideWithValue(world.recruits),
      ],
    );
    addTearDown(c.dispose);
    c.listen(myProviderFactsProvider, (_, _) {});
    c.listen(myRecruitCountersProvider, (_, _) {});
    expect(await c.read(myProviderFactsProvider.future), isNull);
    expect(
      await c.read(myRecruitCountersProvider.future),
      RecruitCounters.empty,
    );
  });
}
