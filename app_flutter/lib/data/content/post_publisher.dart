// lib/data/content/post_publisher.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';

/// Everything needed to create a post. The photos are already uploaded; their
/// download URLs are in [images].
@immutable
class PostDraft {
  const PostDraft({
    required this.id,
    required this.photographerId,
    required this.serviceId,
    this.specialtyId,
    required this.images,
    this.caption = '',
    this.locationName,
    this.styleId,
    this.inPortfolio = true,
  });

  /// A ULID created on the device; publishing the same id again overwrites.
  final String id;
  final String photographerId;
  final String serviceId;

  /// Specialty of the package, stored on the post for the Home category chips.
  final String? specialtyId;
  final List<PostImage> images;
  final String caption;
  final String? locationName;
  final String? styleId;
  final bool inPortfolio;
}

abstract class PostPublisher {
  /// Creates the post (and its portfolio entry) and returns it.
  Future<PostSummary> publish(PostDraft draft);
}

class FakePostPublisher implements PostPublisher {
  FakePostPublisher({required this.posts, DateTime Function()? clock})
    : _now = clock ?? (() => DateTime.now().toUtc());

  /// The feed the new post is added to.
  final FakePostRepository posts;
  final DateTime Function() _now;
  final List<PostDraft> published = [];
  Object? failWith;

  @override
  Future<PostSummary> publish(PostDraft draft) async {
    if (failWith != null) {
      throw failWith!;
    }
    final post = PostSummary(
      id: draft.id,
      kind: PostKind.work,
      authorId: draft.photographerId,
      photographerId: draft.photographerId,
      serviceId: draft.serviceId,
      images: draft.images,
      caption: draft.caption,
      locationName: draft.locationName,
      styleId: draft.styleId,
      specialtyId: draft.specialtyId,
      hashtags: extractHashtags(draft.caption),
      inPortfolio: draft.inPortfolio,
      createdAt: _now(),
    );
    posts.removeById(draft.id);
    posts.add(post);
    published.add(draft);
    return post;
  }
}
