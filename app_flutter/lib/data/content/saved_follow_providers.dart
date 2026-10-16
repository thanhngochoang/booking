import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/firestore_saved_follow_repository.dart';
import 'package:photobooking/data/content/saved_follow.dart';
import 'package:photobooking/data/content/saved_follow_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

final savedFollowRepositoryProvider = Provider<SavedFollowRepository>(
  (ref) => FirestoreSavedFollowRepository(
    posts: ref.watch(postRepositoryProvider),
    photographers: ref.watch(photographerRepositoryProvider),
  ),
);

/// Social counts for the signed-in user: following, savedPosts, savedPhotographers.
final socialCountsProvider = FutureProvider<SocialCounts>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return const SocialCounts();
  final repo = ref.watch(savedFollowRepositoryProvider);
  return repo.counts(user.uid);
});

/// Followed photographer IDs for the signed-in user (up to 100), used for feed boost.
final followingIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return const {};
  final repo = ref.watch(savedFollowRepositoryProvider);
  return repo.followingIds(user.uid);
});

/// Follower count for the current user if they are a photographer; null otherwise.
final myFollowerCountProvider = FutureProvider<int?>((ref) async {
  final profileAsync = ref.watch(currentProfileProvider);
  final profile = profileAsync.value;
  if (profile == null || profile.role != UserRole.photographer) return null;
  final repo = ref.watch(savedFollowRepositoryProvider);
  return repo.followerCount(profile.uid);
});
