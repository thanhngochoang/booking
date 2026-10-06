import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_repository.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

int _int(Object? v) => v is num ? v.toInt() : 0;

/// Reads `albums` and `posts` directly; writes go through the album callables.
class FirestoreAlbumRepository implements AlbumRepository {
  FirestoreAlbumRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseFirestore? _override;
  final FirebaseFunctions _functions;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : (e.message ?? e.code);
      throw AlbumError(code);
    }
  }

  /// The image URL at [index] of post [postId], null when it cannot be shown.
  Future<String?> _imageUrl(String postId, int index) async {
    if (!_validId(postId)) {
      return null;
    }
    final d = (await _db.collection('posts').doc(postId).get()).data();
    final p = d == null ? null : postFromFirestore(postId, d);
    if (p == null) {
      return null;
    }
    return p.images[index >= 0 && index < p.images.length ? index : 0].url;
  }

  /// Decision 6: an explicit cover, else the first image of the post at
  /// `albumPosition == 1` (the lowest position when 1 is missing).
  Future<String?> _coverUrl(
    String albumId,
    String? coverPostId,
    int? coverIndex,
  ) async {
    if (coverPostId != null) {
      final url = await _imageUrl(coverPostId, coverIndex ?? 0);
      if (url != null) {
        return url;
      }
    }
    final snap = await _db
        .collection('posts')
        .where('albumId', isEqualTo: albumId)
        .orderBy('albumPosition')
        .limit(3)
        .get();
    for (final d in snap.docs) {
      final p = postFromFirestore(d.id, d.data());
      if (p != null) {
        return p.images.first.url;
      }
    }
    return null;
  }

  Future<AlbumSummary?> _parse(String id, Map<String, dynamic>? d) async {
    if (d == null) {
      return null;
    }
    final photographerId = d['photographerId'];
    final title = d['title'];
    if (photographerId is! String || title is! String) {
      return null;
    }
    final cover = d['cover'];
    final coverPostId = cover is Map && cover['postId'] is String
        ? cover['postId'] as String
        : null;
    final coverIndex = coverPostId != null && cover is Map
        ? _int(cover['imageIndex'])
        : null;
    final postCount = _int(d['postCount']);
    final album = AlbumSummary(
      id: id,
      photographerId: photographerId,
      title: title,
      description: d['description'] is String ? d['description'] as String : '',
      position: _int(d['position']),
      postCount: postCount,
      mediaCount: _int(d['mediaCount']),
      visible: d['visible'] == true,
      coverPostId: coverPostId,
      coverImageIndex: coverIndex,
    );
    if (postCount == 0) {
      return album;
    }
    // A failing cover read (offline, rules) must not fail the album: the tile
    // shows its placeholder instead.
    try {
      return album.withCoverUrl(await _coverUrl(id, coverPostId, coverIndex));
    } on Object {
      return album;
    }
  }

  @override
  Stream<List<AlbumSummary>> watchAlbums(
    String photographerId, {
    required bool includeEmpty,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('albums')
        .where('photographerId', isEqualTo: photographerId);
    if (!includeEmpty) {
      q = q.where('visible', isEqualTo: true);
    }
    return q.orderBy('position').snapshots().asyncMap((snap) async {
      final albums = await Future.wait([
        for (final d in snap.docs) _parse(d.id, d.data()),
      ]);
      return albums.whereType<AlbumSummary>().toList();
    });
  }

  @override
  Future<AlbumSummary?> album(String albumId) async {
    if (!_validId(albumId)) {
      return null;
    }
    final snap = await _db.collection('albums').doc(albumId).get();
    return _parse(snap.id, snap.data());
  }

  @override
  Future<String> create({
    required String title,
    String description = '',
  }) async {
    final data = await _call('createAlbum', {
      'title': title,
      if (description.isNotEmpty) 'description': description,
    });
    final id = data is Map ? data['albumId'] : null;
    if (id is! String) {
      throw const AlbumError('internal');
    }
    return id;
  }

  @override
  Future<void> update(
    String albumId, {
    String? title,
    String? description,
    AlbumCoverChoice? cover,
  }) async {
    final data = <String, Object?>{
      'albumId': albumId,
      'title': ?title,
      'description': ?description,
    };
    // null clears the cover back to automatic; leaving the key out keeps it.
    switch (cover) {
      case AlbumCoverAuto():
        data['cover'] = null;
      case AlbumCoverPick(:final postId, :final imageIndex):
        data['cover'] = {'postId': postId, 'imageIndex': imageIndex};
      case null:
        break;
    }
    await _call('updateAlbum', data);
  }

  @override
  Future<void> delete(String albumId) async {
    await _call('deleteAlbum', {'albumId': albumId});
  }

  @override
  Future<void> reorder(List<String> albumIds) async {
    await _call('reorderAlbums', {'albumIds': albumIds});
  }

  @override
  Future<void> movePosts(String? albumId, List<String> postIds) async {
    await _call('movePostsToAlbum', {'albumId': albumId, 'postIds': postIds});
  }

  @override
  Future<void> reorderPosts(String albumId, List<String> postIds) async {
    await _call('reorderAlbumPosts', {'albumId': albumId, 'postIds': postIds});
  }
}
