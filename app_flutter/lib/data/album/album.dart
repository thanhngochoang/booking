import 'package:flutter/foundation.dart';

/// A portfolio album of one photographer. [coverUrl] is filled by the
/// repository (explicit cover, else the first image of the first post): album
/// documents do not copy URLs.
@immutable
class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.photographerId,
    required this.title,
    this.description = '',
    required this.position,
    required this.postCount,
    required this.mediaCount,
    required this.visible,
    this.coverPostId,
    this.coverImageIndex,
    this.coverUrl,
  });

  final String id;
  final String photographerId;
  final String title;
  final String description;
  final int position;
  final int postCount;
  final int mediaCount;
  final bool visible;
  final String? coverPostId;
  final int? coverImageIndex;
  final String? coverUrl;

  AlbumSummary withCoverUrl(String? url) => AlbumSummary(
    id: id,
    photographerId: photographerId,
    title: title,
    description: description,
    position: position,
    postCount: postCount,
    mediaCount: mediaCount,
    visible: visible,
    coverPostId: coverPostId,
    coverImageIndex: coverImageIndex,
    coverUrl: url,
  );
}

/// What to do with an album's cover: let the first post decide, or pick one
/// image of a post in the album.
sealed class AlbumCoverChoice {
  const AlbumCoverChoice();
}

class AlbumCoverAuto extends AlbumCoverChoice {
  const AlbumCoverAuto();
}

class AlbumCoverPick extends AlbumCoverChoice {
  const AlbumCoverPick(this.postId, this.imageIndex);
  final String postId;
  final int imageIndex;
}

/// Carries the server's error code (`conflict`, `limit_exceeded`,
/// `invalid_argument`, `permission_denied`, `not_found`, ...).
class AlbumError implements Exception {
  const AlbumError(this.code);
  final String code;

  @override
  String toString() => 'AlbumError($code)';
}
