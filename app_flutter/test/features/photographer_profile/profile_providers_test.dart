// test/features/photographer_profile/profile_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';

class _Similar implements RecommendationRepository {
  _Similar({this.fail = false});
  final bool fail;

  @override
  Future<RecommendationPage> similar(
    String photographerId, {
    int limit = 8,
  }) async {
    if (fail) {
      throw StateError('down');
    }
    return RecommendationPage(
      items: [
        for (final (i, id) in ['p2', photographerId, 'p3'].indexed)
          RecommendedPhotographer(
            photographer: fixturePhotographer(id),
            rank: i + 1,
            score: 1,
          ),
      ],
      requestId: 'r1',
      algorithm: 'test',
      algorithmVersion: '1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final l = AppLocalizationsVi();

  test('small helpers', () {
    expect(profileSectionFromQuery('services'), ProfileSection.services);
    expect(profileSectionFromQuery('calendar'), ProfileSection.calendar);
    expect(profileSectionFromQuery('reviews'), ProfileSection.reviews);
    expect(profileSectionFromQuery(null), ProfileSection.portfolio);
    expect(profileSectionFromQuery('x'), ProfileSection.portfolio);
    expect(inquiryPath('p1'), '/u/p1/ask');
    expect(
      startingPriceOf(
        discoveryServices().where((s) => s.photographerId == 'p1'),
      ),
      1500000,
    );
    expect(startingPriceOf(const []), isNull);
    expect(responseLabel(45, l), '~45 phút');
    expect(responseLabel(60, l), '~1 giờ');
    expect(responseLabel(150, l), '~3 giờ');
    expect([1, 2, 3].map((v) => skillLevelLabel(v, l)), [
      'Cơ bản',
      'Thành thạo',
      'Chuyên sâu',
    ]);
  });

  test('packages: active only, cheapest first', () async {
    final c = ProviderContainer(
      overrides: [
        serviceRepositoryProvider.overrideWithValue(
          FakeServiceRepository(discoveryServices()),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    final list = await c.read(profilePackagesProvider('p1').future);
    expect(list.map((s) => s.id), ['s1', 's2']);
  });

  test('portfolio pages by 20 and stops at the end', () async {
    final posts = FakePostRepository([
      for (var i = 0; i < 25; i++)
        fixturePost(
          'x$i',
          photographerId: 'p1',
          age: Duration(minutes: i + 1),
        ),
    ]);
    final c = ProviderContainer(
      overrides: [postRepositoryProvider.overrideWithValue(posts)],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    final sub = c.listen(portfolioProvider('p1'), (_, _) {});
    addTearDown(sub.close);
    final first = await c.read(portfolioProvider('p1').future);
    expect((first.posts.length, first.hasMore), (20, true));
    await c.read(portfolioProvider('p1').notifier).loadMore();
    final all = c.read(portfolioProvider('p1')).value!;
    expect(
      (all.posts.length, all.hasMore, all.posts.first.id),
      (25, false, 'x0'),
    );
    await c
        .read(portfolioProvider('p1').notifier)
        .loadMore(); // nothing more: no error
    expect(c.read(portfolioProvider('p1')).value!.posts.length, 25);
  });

  test(
    'similar photographers leave out the photographer and fail quietly',
    () async {
      final ok = ProviderContainer(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(_Similar()),
        ],
        retry: (_, _) => null,
      );
      addTearDown(ok.dispose);
      expect(
        (await ok.read(similarPhotographersProvider('p1').future))
            .map((p) => p.id),
        ['p2', 'p3'],
      );
      final down = ProviderContainer(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(
            _Similar(fail: true),
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(down.dispose);
      expect(
        await down.read(similarPhotographersProvider('p1').future),
        isEmpty,
      );
    },
  );
}
