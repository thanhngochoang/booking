// test/data/content/fake_content_repositories_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';

import 'content_contracts.dart';

void main() {
  postRepositoryContract('fake', (seed) async => FakePostRepository(seed));
  engagementContract('fake', () async => FakePostEngagementRepository());
  photographerRepositoryContract(
    'fake',
    (seed) async => FakePhotographerRepository(seed),
  );
  serviceRepositoryContract(
    'fake',
    (seed) async => FakeServiceRepository(seed),
  );

  test('failWith makes every call throw, for testing error states', () async {
    final posts = FakePostRepository()..failWith = StateError('offline');
    expect(() => posts.feed(), throwsStateError);
    expect(() => posts.byId('a'), throwsStateError);
    final eng = FakePostEngagementRepository()
      ..failWith = StateError('offline');
    expect(() => eng.setLiked('u', 'a', true), throwsStateError);
    expect(eng.writeCalls, 0);
    final ph = FakePhotographerRepository()..failWith = StateError('offline');
    expect(() => ph.candidates(), throwsStateError);
    final sv = FakeServiceRepository()..failWith = StateError('offline');
    expect(() => sv.activeFor('p1'), throwsStateError);
  });

  test('add makes a new post show at the top of the feed', () async {
    final posts = FakePostRepository(contractPosts());
    posts.add(fixturePostNewest());
    expect((await posts.feed()).posts.first.id, 'new');
  });

  test('reads are counted too', () async {
    final eng = FakePostEngagementRepository();
    await eng.engagementFor('u', 'a');
    await eng.savedAmong('u', ['a', 'b']);
    await eng.isFollowing('u', 'p1');
    expect(eng.readCalls, 3);
  });

  test('writes are counted so tests can assert optimistic behaviour', () async {
    final eng = FakePostEngagementRepository();
    await eng.setLiked('u', 'a', true);
    await eng.setSaved('u', 'a', true);
    await eng.setFollowing('u', 'p1', true);
    expect(eng.writeCalls, 3);
  });
}
