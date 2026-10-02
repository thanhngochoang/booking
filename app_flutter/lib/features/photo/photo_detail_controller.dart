// lib/features/photo/photo_detail_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

@immutable
class PostDetail {
  const PostDetail({
    required this.post,
    this.photographer,
    this.service,
    this.more = const [],
  });

  final PostSummary post;
  final PhotographerSummary? photographer;

  /// The package the post is tagged with; null when it cannot be found.
  final ServiceSummary? service;

  /// Up to three other posts of the same photographer.
  final List<PostSummary> more;
}

Future<T?> _orNull<T>(Future<T> f) =>
    f.then<T?>((v) => v, onError: (_) => null);

/// The post, its photographer, its package and more of the photographer's
/// work. Null when the post does not exist (or was removed).
final postDetailProvider = FutureProvider.autoDispose
    .family<PostDetail?, String>((ref, postId) async {
      final posts = ref.watch(postRepositoryProvider);
      final post = await posts.byId(postId);
      if (post == null) {
        return null;
      }
      final (authors, service, others) = await (
        _orNull(
          ref.watch(photographerRepositoryProvider).summaries([
            post.photographerId,
          ]),
        ),
        _orNull(
          ref
              .watch(serviceRepositoryProvider)
              .byId(post.photographerId, post.serviceId),
        ),
        _orNull(posts.byPhotographer(post.photographerId, limit: 7)),
      ).wait;
      return PostDetail(
        post: post,
        photographer: authors?[post.photographerId],
        service: service,
        more: (others?.posts ?? const <PostSummary>[])
            .where((p) => p.id != post.id)
            .take(3)
            .toList(),
      );
    });
