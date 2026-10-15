// lib/features/spots/spot_posts_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/spots/spot_providers.dart';

class SpotPostsController extends AsyncNotifier<List<PostSummary>> {
  SpotPostsController(this.spotId);

  final String spotId;

  @override
  Future<List<PostSummary>> build() async {
    final repo = ref.watch(spotRepositoryProvider);
    final hidden = ref.watch(hiddenUsersProvider);
    final list = await repo.postsAt(spotId, limit: 20);
    return list
        .where((p) =>
            !hidden.contains(p.authorId) && !hidden.contains(p.photographerId))
        .toList();
  }

  Future<void> loadMore() async {
    final current = state.value ?? [];
    if (current.isEmpty) return;
    final repo = ref.read(spotRepositoryProvider);
    final hidden = ref.read(hiddenUsersProvider);
    final lastTime = current.last.createdAt;
    final more = await repo.postsAt(spotId, before: lastTime, limit: 20);
    final filtered = more
        .where((p) =>
            !hidden.contains(p.authorId) && !hidden.contains(p.photographerId))
        .toList();
    state = AsyncData([...current, ...filtered]);
  }
}

final spotPostsProvider = AsyncNotifierProvider.autoDispose
    .family<SpotPostsController, List<PostSummary>, String>(
  SpotPostsController.new,
);
