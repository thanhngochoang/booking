enum PostKind {
  work('work'),
  realShoot('real_shoot'),
  eventShare('event_share');

  const PostKind(this.code);
  final String code;

  static PostKind fromCode(String? code) =>
      values.firstWhere((k) => k.code == code, orElse: () => PostKind.work);
}

class PostImage {
  const PostImage({required this.url, this.blurHash, this.width, this.height});
  final String url;

  /// Placeholder hash stored with the post; decoding it is a later
  /// enhancement of `PhotoCard`.
  final String? blurHash;
  final int? width;
  final int? height;
}

class PostSummary {
  const PostSummary({
    required this.id,
    required this.kind,
    required this.authorId,
    required this.photographerId,
    required this.serviceId,
    this.bookingId,
    required this.images,
    this.caption = '',
    this.locationName,
    this.styleId,
    this.specialtyId,
    this.hashtags = const [],
    this.inPortfolio = false,
    this.likeCount = 0,
    this.saveCount = 0,
    required this.createdAt,
  }) : assert(images.length > 0, 'a post has at least one image');

  final String id;
  final PostKind kind;

  /// The photographer for `work` posts, the customer for `real_shoot`.
  final String authorId;
  final String photographerId;
  final String serviceId;
  final String? bookingId;
  final List<PostImage> images;
  final String caption;
  final String? locationName;
  final String? styleId;

  /// Specialty of the service this post is tagged with.
  final String? specialtyId;

  /// Lower-case tags without `#`, extracted from the caption.
  final List<String> hashtags;
  final bool inPortfolio;
  final int likeCount;
  final int saveCount;
  final DateTime createdAt;

  PostImage get cover => images.first;
}

class PostPage {
  const PostPage({this.posts = const [], this.nextCursor});
  final List<PostSummary> posts;

  /// Pass it back to load the next page; null on the last page.
  final String? nextCursor;
}
