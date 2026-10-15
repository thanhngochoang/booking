import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';

void main() {
  test('every provider can be replaced by a fake', () async {
    final posts = FakePostRepository();
    final eng = FakePostEngagementRepository();
    final ph = FakePhotographerRepository();
    final sv = FakeServiceRepository();
    final c = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(posts),
        postEngagementRepositoryProvider.overrideWithValue(eng),
        photographerRepositoryProvider.overrideWithValue(ph),
        serviceRepositoryProvider.overrideWithValue(sv),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(postRepositoryProvider), same(posts));
    expect(c.read(postEngagementRepositoryProvider), same(eng));
    expect(c.read(photographerRepositoryProvider), same(ph));
    expect(c.read(serviceRepositoryProvider), same(sv));
  });
}
