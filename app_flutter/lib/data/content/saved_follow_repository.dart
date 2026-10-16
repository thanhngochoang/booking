import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/saved_follow.dart';

abstract class SavedFollowRepository {
  Future<MarkerPage<PostSummary>> savedPosts(
    String uid, {
    String? cursor,
    int limit = 30,
  });

  Future<MarkerPage<PhotographerSummary>> savedPhotographers(
    String uid, {
    String? cursor,
    int limit = 20,
  });

  Future<MarkerPage<PhotographerSummary>> following(
    String uid, {
    String? cursor,
    int limit = 20,
  });

  Future<MarkerPage<Follower>> followers(
    String photographerId, {
    String? cursor,
    int limit = 30,
  });

  Future<bool> isPhotographerSaved(String uid, String photographerId);

  Future<void> setPhotographerSaved(
    String uid,
    String photographerId,
    bool saved,
  );

  Future<Set<String>> followingIds(String uid, {int limit = 100});

  Future<SocialCounts> counts(String uid);

  /// Reads photographers/{id}.followerCount, returning null when absent.
  Future<int?> followerCount(String photographerId);
}
