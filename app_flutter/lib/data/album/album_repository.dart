import 'dart:async';

import 'package:photobooking/data/album/album.dart';

/// Reads are direct; writes go through the album callables, which enforce the
/// limits and keep positions and counts consistent. Writes throw
/// [AlbumError] with the server code.
abstract class AlbumRepository {
  /// Albums of one photographer ordered by position. Visitors pass
  /// `includeEmpty: false` (visible albums only); the owner passes true.
  Stream<List<AlbumSummary>> watchAlbums(
    String photographerId, {
    required bool includeEmpty,
  });

  /// Null when the album does not exist.
  Future<AlbumSummary?> album(String albumId);

  /// Returns the new album id.
  Future<String> create({required String title, String description = ''});

  Future<void> update(
    String albumId, {
    String? title,
    String? description,
    AlbumCoverChoice? cover,
  });

  Future<void> delete(String albumId);
  Future<void> reorder(List<String> albumIds);

  /// [albumId] null removes the posts from their albums.
  Future<void> movePosts(String? albumId, List<String> postIds);
  Future<void> reorderPosts(String albumId, List<String> postIds);
}

/// In-memory repository for widget tests. Counts and positions are kept
/// simple: it does not model the server's limits unless [failWith] is set.
class FakeAlbumRepository implements AlbumRepository {
  FakeAlbumRepository([List<AlbumSummary> albums = const []])
    : _albums = List.of(albums);

  final List<AlbumSummary> _albums;
  final _changes = StreamController<void>.broadcast();

  /// When set, every call throws it.
  AlbumError? failWith;

  /// Calls made, as `name` or `name:arg`, for assertions.
  final calls = <String>[];

  /// Every `movePosts` call: target album id (null = none) and post ids.
  final moves = <(String?, List<String>)>[];

  void _check() {
    final e = failWith;
    if (e != null) {
      throw e;
    }
  }

  List<AlbumSummary> _sorted(bool includeEmpty) =>
      _albums.where((a) => includeEmpty || a.visible).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  void add(AlbumSummary a) {
    _albums.add(a);
    _changes.add(null);
  }

  @override
  Stream<List<AlbumSummary>> watchAlbums(
    String photographerId, {
    required bool includeEmpty,
  }) async* {
    List<AlbumSummary> mine() => [
      for (final a in _sorted(includeEmpty))
        if (a.photographerId == photographerId) a,
    ];
    yield mine();
    await for (final _ in _changes.stream) {
      yield mine();
    }
  }

  @override
  Future<AlbumSummary?> album(String albumId) async {
    _check();
    for (final a in _albums) {
      if (a.id == albumId) {
        return a;
      }
    }
    return null;
  }

  @override
  Future<String> create({
    required String title,
    String description = '',
  }) async {
    _check();
    calls.add('create:$title');
    final id = 'fake${_albums.length + 1}';
    add(
      AlbumSummary(
        id: id,
        photographerId: 'me',
        title: title,
        description: description,
        position: _albums.length + 1,
        postCount: 0,
        mediaCount: 0,
        visible: false,
      ),
    );
    return id;
  }

  @override
  Future<void> update(
    String albumId, {
    String? title,
    String? description,
    AlbumCoverChoice? cover,
  }) async {
    _check();
    calls.add('update:$albumId');
    final i = _albums.indexWhere((a) => a.id == albumId);
    if (i < 0) {
      throw const AlbumError('not_found');
    }
    final a = _albums[i];
    _albums[i] = AlbumSummary(
      id: a.id,
      photographerId: a.photographerId,
      title: title ?? a.title,
      description: description ?? a.description,
      position: a.position,
      postCount: a.postCount,
      mediaCount: a.mediaCount,
      visible: a.visible,
      coverPostId: switch (cover) {
        AlbumCoverPick(:final postId) => postId,
        AlbumCoverAuto() => null,
        null => a.coverPostId,
      },
      coverImageIndex: switch (cover) {
        AlbumCoverPick(:final imageIndex) => imageIndex,
        AlbumCoverAuto() => null,
        null => a.coverImageIndex,
      },
      coverUrl: a.coverUrl,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(String albumId) async {
    _check();
    calls.add('delete:$albumId');
    _albums.removeWhere((a) => a.id == albumId);
    _changes.add(null);
  }

  @override
  Future<void> reorder(List<String> albumIds) async {
    _check();
    calls.add('reorder:${albumIds.join(',')}');
    for (var n = 0; n < albumIds.length; n++) {
      final i = _albums.indexWhere((a) => a.id == albumIds[n]);
      if (i >= 0) {
        final a = _albums[i];
        _albums[i] = AlbumSummary(
          id: a.id,
          photographerId: a.photographerId,
          title: a.title,
          description: a.description,
          position: n + 1,
          postCount: a.postCount,
          mediaCount: a.mediaCount,
          visible: a.visible,
          coverPostId: a.coverPostId,
          coverImageIndex: a.coverImageIndex,
          coverUrl: a.coverUrl,
        );
      }
    }
    _changes.add(null);
  }

  @override
  Future<void> movePosts(String? albumId, List<String> postIds) async {
    _check();
    calls.add('movePosts:$albumId');
    moves.add((albumId, List.of(postIds)));
  }

  @override
  Future<void> reorderPosts(String albumId, List<String> postIds) async {
    _check();
    calls.add('reorderPosts:$albumId:${postIds.join(',')}');
  }
}
