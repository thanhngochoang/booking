// test/features/discovery/engagement_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';

import '../../support/content_fixtures.dart';

Future<(ProviderContainer, FakePostEngagementRepository, String?)> _make({
  bool signedIn = true,
}) async {
  final auth = FakeAuthRepository();
  String? uid;
  if (signedIn) {
    uid = (await auth.registerWithEmail('a@b.vn', 'password1', 'Lan')).uid;
  }
  final repo = FakePostEngagementRepository();
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      postEngagementRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return (c, repo, uid);
}

Future<(ProviderContainer, FakeAuthRepository)> _makeWithAuth() async {
  final auth = FakeAuthRepository();
  await auth.registerWithEmail('a@b.vn', 'password1', 'Lan');
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      postEngagementRepositoryProvider.overrideWithValue(
        FakePostEngagementRepository(),
      ),
    ],
  );
  addTearDown(c.dispose);
  return (c, auth);
}

Future<void> _settle(ProviderContainer c) async {
  await Future<void>.delayed(Duration.zero);
  await c.pump();
}

void main() {
  group('seed and load', () {
    test(
      'seed takes the counts from the posts and the saved marks in one batch',
      () async {
        final (c, repo, uid) = await _make();
        await repo.setSaved(uid!, 'a', true);
        await c.read(engagementProvider.notifier).seed([
          fixturePost('a', likes: 3, saves: 1),
          fixturePost('b', likes: 9),
        ]);
        final s = c.read(engagementProvider);
        expect(s['a'], isA<EngagementView>());
        expect(
          (s['a']!.likeCount, s['a']!.saveCount, s['a']!.saved),
          (3, 1, true),
        );
        expect((s['b']!.likeCount, s['b']!.saved), (9, false));
      },
    );

    test('a failing batch is ignored: counts stay, marks stay false', () async {
      final (c, repo, _) = await _make();
      repo.failWith = StateError('offline');
      await c.read(engagementProvider.notifier).seed([
        fixturePost('a', likes: 3),
      ]);
      expect(c.read(engagementProvider)['a']!.likeCount, 3);
      expect(c.read(engagementProvider)['a']!.saved, isFalse);
    });

    test('seeding again keeps what the viewer already did', () async {
      final (c, _, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      await n.toggleLike('a');
      await n.seed([fixturePost('a', likes: 3)]);
      expect(c.read(engagementProvider)['a']!.liked, isTrue);
      expect(c.read(engagementProvider)['a']!.likeCount, 4);
    });

    test('load reads liked and saved for one post', () async {
      final (c, repo, uid) = await _make();
      await repo.setLiked(uid!, 'a', true);
      await repo.setSaved(uid, 'a', true);
      await c
          .read(engagementProvider.notifier)
          .load(fixturePost('a', likes: 5, saves: 2));
      final v = c.read(engagementProvider)['a']!;
      expect((v.liked, v.saved, v.likeCount, v.saveCount), (true, true, 5, 2));
    });
  });

  group('toggle', () {
    test(
      'a like is shown at once and stored; undoing restores the count',
      () async {
        final (c, repo, uid) = await _make();
        final n = c.read(engagementProvider.notifier);
        await n.seed([fixturePost('a', likes: 3)]);
        final pending = n.toggleLike('a');
        expect(
          c.read(engagementProvider)['a']!.liked,
          isTrue,
          reason: 'optimistic',
        );
        expect(c.read(engagementProvider)['a']!.likeCount, 4);
        expect(await pending, isTrue);
        expect((await repo.engagementFor(uid!, 'a')).liked, isTrue);
        expect(await n.toggleLike('a'), isTrue);
        expect(c.read(engagementProvider)['a']!.likeCount, 3);
        expect((await repo.engagementFor(uid, 'a')).liked, isFalse);
      },
    );

    test('a failed write puts everything back and says so', () async {
      final (c, repo, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      repo.failWith = StateError('offline');
      expect(await n.toggleLike('a'), isFalse);
      final v = c.read(engagementProvider)['a']!;
      expect((v.liked, v.likeCount), (false, 3));
      expect(await n.toggleSave('a'), isFalse);
      expect(c.read(engagementProvider)['a']!.saved, isFalse);
    });

    test('a second tap while the first is in flight is ignored', () async {
      final (c, repo, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      final first = n.toggleLike('a');
      final second = n.toggleLike('a');
      await Future.wait([first, second]);
      expect(repo.writeCalls, 1);
      expect(c.read(engagementProvider)['a']!.liked, isTrue);
    });

    test(
      'like and save are independent, and counts never go below zero',
      () async {
        final (c, _, _) = await _make();
        final n = c.read(engagementProvider.notifier);
        await n.seed([fixturePost('a', likes: 0, saves: 0)]);
        await n.toggleSave('a');
        var v = c.read(engagementProvider)['a']!;
        expect((v.saved, v.saveCount, v.liked), (true, 1, false));
        await n.toggleSave('a');
        await n.toggleSave('a');
        await n.toggleSave('a');
        v = c.read(engagementProvider)['a']!;
        expect(v.saveCount, greaterThanOrEqualTo(0));
      },
    );

    test('nothing happens when signed out or for an unknown post', () async {
      final (c, repo, _) = await _make(signedIn: false);
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a')]);
      expect(await n.toggleLike('a'), isFalse);
      expect(repo.writeCalls, 0);
      final (c2, _, _) = await _make();
      expect(
        await c2.read(engagementProvider.notifier).toggleLike('ghost'),
        isFalse,
      );
    });
  });

  group('user change', () {
    test('engagement is emptied on sign-out and for another user', () async {
      final (c, auth) = await _makeWithAuth();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      await _settle(c);
      expect(c.read(engagementProvider), isNotEmpty, reason: 'same user stays');
      await auth.signOut();
      await _settle(c);
      expect(c.read(engagementProvider), isEmpty);
      await n.seed([fixturePost('a')]);
      await auth.registerWithEmail('b@b.vn', 'password1', 'Bình');
      await _settle(c);
      expect(c.read(engagementProvider), isEmpty);
    });

    test('follow marks are emptied on sign-out', () async {
      final (c, auth) = await _makeWithAuth();
      final n = c.read(followProvider.notifier);
      expect(await n.toggle('p1'), isTrue);
      await _settle(c);
      expect(c.read(followProvider)['p1'], isTrue);
      await auth.signOut();
      await _settle(c);
      expect(c.read(followProvider), isEmpty);
    });
  });

  group('follow', () {
    test('load, toggle and revert', () async {
      final (c, repo, uid) = await _make();
      await repo.setFollowing(uid!, 'p1', true);
      final n = c.read(followProvider.notifier);
      await n.load('p1');
      expect(c.read(followProvider)['p1'], isTrue);
      expect(await n.toggle('p1'), isTrue);
      expect(c.read(followProvider)['p1'], isFalse);
      repo.failWith = StateError('offline');
      expect(await n.toggle('p1'), isFalse);
      expect(
        c.read(followProvider)['p1'],
        isFalse,
        reason: 'back to the value before the failed tap',
      );
    });
  });
}
