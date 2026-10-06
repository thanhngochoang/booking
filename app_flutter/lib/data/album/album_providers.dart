import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_repository.dart';
import 'package:photobooking/data/album/firestore_album_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';

final albumRepositoryProvider = Provider<AlbumRepository>(
  (ref) => FirestoreAlbumRepository(),
);

/// A photographer's albums as visitors see them (visible only).
final profileAlbumsProvider = StreamProvider.autoDispose
    .family<List<AlbumSummary>, String>(
      (ref, photographerId) => ref
          .watch(albumRepositoryProvider)
          .watchAlbums(photographerId, includeEmpty: false),
    );

/// The signed-in photographer's own albums, empty ones included.
final myAlbumsProvider = StreamProvider.autoDispose<List<AlbumSummary>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return Stream.value(const <AlbumSummary>[]);
  }
  return ref
      .watch(albumRepositoryProvider)
      .watchAlbums(uid, includeEmpty: true);
});
