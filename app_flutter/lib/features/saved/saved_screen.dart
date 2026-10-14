import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/saved/saved_controller.dart';

enum SavedTab { posts, photographers }

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({
    super.key,
    this.initialTab = SavedTab.posts,
  });

  final SavedTab initialTab;

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  late SavedTab _tab = widget.initialTab;
  final ScrollController _postsScroll = ScrollController();
  final ScrollController _photographersScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _postsScroll.addListener(_onPostsScroll);
    _photographersScroll.addListener(_onPhotographersScroll);
  }

  @override
  void dispose() {
    _postsScroll.removeListener(_onPostsScroll);
    _photographersScroll.removeListener(_onPhotographersScroll);
    _postsScroll.dispose();
    _photographersScroll.dispose();
    super.dispose();
  }

  void _onPostsScroll() {
    if (_postsScroll.position.extentAfter < 300) {
      ref.read(savedPostsControllerProvider.notifier).loadMore();
    }
  }

  void _onPhotographersScroll() {
    if (_photographersScroll.position.extentAfter < 300) {
      ref.read(savedPhotographersControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final counts = ref.watch(socialCountsProvider).value;

    final postCount = counts?.savedPosts ?? 0;
    final photographerCount = counts?.savedPhotographers ?? 0;

    return ScreenCode(
      ScreenCodes.saved,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l.savedTitle),
          leading: context.canPop()
              ? BackButton(
                  onPressed: () => context.pop(),
                )
              : null,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              child: SegmentedTabs<SavedTab>(
                key: const Key('saved-tabs'),
                options: [
                  SegmentOption(
                    value: SavedTab.posts,
                    label: l.savedTabPosts(postCount),
                  ),
                  SegmentOption(
                    value: SavedTab.photographers,
                    label: l.savedTabPhotographers(photographerCount),
                  ),
                ],
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: _tab == SavedTab.posts
                  ? _SavedPostsView(scrollController: _postsScroll)
                  : _SavedPhotographersView(
                      scrollController: _photographersScroll,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostsView extends ConsumerWidget {
  const _SavedPostsView({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final asyncPosts = ref.watch(savedPostsControllerProvider);

    return AsyncView<SavedListState<PostSummary>>(
      value: asyncPosts,
      onRetry: () => ref.read(savedPostsControllerProvider.notifier).refresh(),
      skeleton: (_) => _PostsSkeletonGrid(),
      isEmpty: (state) => state.items.isEmpty,
      empty: (context) => EmptyState(
        title: l.savedPostsEmptyTitle,
        body: l.savedPostsEmptyBody,
      ),
      data: (context, state) {
        final items = state.items;
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.s4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpace.s2,
                  crossAxisSpacing: AppSpace.s2,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = items[index];
                    final heroUrl = post.images.isNotEmpty ? post.cover.url : null;
                    return Semantics(
                      button: true,
                      label: post.caption.isNotEmpty ? post.caption : 'Bài đã lưu',
                      child: InkWell(
                        key: Key('saved-post-${post.id}'),
                        onTap: () => context.push('/p/${post.id}'),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: heroUrl != null && heroUrl.isNotEmpty
                              ? NetworkPhoto(
                                  url: heroUrl,
                                  fit: BoxFit.cover,
                                  retry: false,
                                )
                              : ColoredBox(
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
            if (state.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.s4),
                  child: Center(
                    child: DotRingLoader(size: LoaderSize.inline),
                  ),
                ),
              ),
            if (state.moreFailed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Center(
                    child: TextButton(
                      key: const Key('saved-posts-retry'),
                      onPressed: () => ref
                          .read(savedPostsControllerProvider.notifier)
                          .loadMore(),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PostsSkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.s2,
          crossAxisSpacing: AppSpace.s2,
          childAspectRatio: 1,
        ),
        itemCount: 9,
        itemBuilder: (context, index) => AppSkeleton.box(
          height: double.infinity,
          radius: AppRadius.sm,
        ),
      ),
    );
  }
}

class _SavedPhotographersView extends ConsumerWidget {
  const _SavedPhotographersView({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final asyncPhotographers = ref.watch(savedPhotographersControllerProvider);

    return AsyncView<SavedListState<PhotographerSummary>>(
      value: asyncPhotographers,
      onRetry: () =>
          ref.read(savedPhotographersControllerProvider.notifier).refresh(),
      skeleton: (_) => _PhotographersSkeletonList(),
      isEmpty: (state) => state.items.isEmpty,
      empty: (context) => EmptyState(
        title: l.savedPhotographersEmptyTitle,
        body: l.savedPhotographersEmptyBody,
      ),
      data: (context, state) {
        final items = state.items;
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s3),
                      child: PhotographerCard(
                        data: item,
                        saved: true,
                        onProfile: () => context.push('/u/${item.id}'),
                        onBook: item.acceptingOrders
                            ? () => startBooking(
                                  context,
                                  ref,
                                  photographerId: item.id,
                                )
                            : null,
                        onToggleSave: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final controller = ref.read(
                            savedPhotographersControllerProvider.notifier,
                          );
                          controller.removeLocally(item.id);
                          await ref
                              .read(savedPhotographerProvider.notifier)
                              .toggle(item.id);

                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l.savedUnsaved(item.displayName)),
                              action: SnackBarAction(
                                label: l.savedUndo,
                                onPressed: () async {
                                  controller.restore(item, index);
                                  await ref
                                      .read(savedPhotographerProvider.notifier)
                                      .toggle(item.id);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
            if (state.loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.s4),
                  child: Center(
                    child: DotRingLoader(size: LoaderSize.inline),
                  ),
                ),
              ),
            if (state.moreFailed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Center(
                    child: TextButton(
                      key: const Key('saved-photographers-retry'),
                      onPressed: () => ref
                          .read(savedPhotographersControllerProvider.notifier)
                          .loadMore(),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotographersSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s2,
      ),
      child: Column(
        children: [
          PhotographerCard.skeleton(),
          const SizedBox(height: AppSpace.s3),
          PhotographerCard.skeleton(),
        ],
      ),
    );
  }
}
