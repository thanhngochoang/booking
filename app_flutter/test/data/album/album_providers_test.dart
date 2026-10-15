import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/album/album_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

import '../../support/content_fixtures.dart';

class _Repo implements AlbumRepository {
  final asked = <String>[];

  @override
  Stream<List<AlbumSummary>> watchAlbums(
    String photographerId, {
    required bool includeEmpty,
  }) {
    asked.add(photographerId);
    return Stream.value([fixtureAlbum('a', photographerId: photographerId)]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('signed out gives an empty list', () async {
    final repo = _Repo();
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        albumRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.listen(myAlbumsProvider, (_, _) {});
    await c.read(authStateProvider.future);
    expect(await c.read(myAlbumsProvider.future), isEmpty);
    expect(repo.asked, isEmpty);
  });

  test('signed in asks the own albums, empty ones included', () async {
    final repo = _Repo();
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'p1')),
        ),
        albumRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.listen(myAlbumsProvider, (_, _) {});
    await c.read(authStateProvider.future);
    final list = await c.read(myAlbumsProvider.future);
    expect(list.single.photographerId, 'p1');
  });
}
