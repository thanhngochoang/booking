import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/saved_follow.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';
import 'package:photobooking/features/saved/follow_list_controller.dart';
import 'package:photobooking/features/saved/saved_controller.dart';

class FollowersScreen extends ConsumerStatefulWidget {
  const FollowersScreen({super.key});

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      ref.read(followersControllerProvider.notifier).loadMore();
    }
  }

  String _formatSince(DateTime since) {
    return '${since.day}/${since.month}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final asyncFollowers = ref.watch(followersControllerProvider);
    final countAsync = ref.watch(myFollowerCountProvider);
    final count = countAsync.value ?? (asyncFollowers.value?.items.length ?? 0);

    return ScreenCode(
      ScreenCodes.followers,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l.followersTitle),
          leading: context.canPop()
              ? BackButton(
                  onPressed: () => context.pop(),
                )
              : null,
        ),
        body: AsyncView<SavedListState<Follower>>(
          value: asyncFollowers,
          onRetry: () =>
              ref.read(followersControllerProvider.notifier).refresh(),
          skeleton: (_) => _FollowersSkeletonList(),
          isEmpty: (state) => state.items.isEmpty,
          empty: (context) => EmptyState(
            title: l.followersEmptyTitle,
            body: l.followersEmptyBody,
          ),
          data: (context, state) {
            final items = state.items;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardBg = isDark ? AppColorsDark.glass : AppColors.glass;

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4,
                      AppSpace.s2,
                      AppSpace.s4,
                      AppSpace.s3,
                    ),
                    child: Text(
                      l.followersCount(count),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColorsDark.foregroundSecondary
                                : AppColors.foregroundSecondary,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                            _FollowerRow(
                              follower: items[i],
                              formattedSince: _formatSince(items[i].since),
                            ),
                          ],
                        ],
                      ),
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
                          key: const Key('followers-retry'),
                          onPressed: () => ref
                              .read(followersControllerProvider.notifier)
                              .loadMore(),
                          child: const Text('Thử lại'),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpace.s6),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FollowerRow extends StatelessWidget {
  const _FollowerRow({
    required this.follower,
    required this.formattedSince,
  });

  final Follower follower;
  final String formattedSince;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      key: Key('follower-row-${follower.userId}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s2h,
      ),
      child: Row(
        children: [
          AppAvatar(
            url: follower.avatarUrl,
            name: follower.displayName,
            size: AppAvatarSize.sm,
            decorative: true,
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  follower.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  l.followersSince(formattedSince),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColorsDark.foregroundSecondary
                            : AppColors.foregroundSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowersSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s4),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
              child: Row(
                children: [
                  AppAvatar.skeleton(size: AppAvatarSize.sm),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton.box(width: 120, height: 14),
                        const SizedBox(height: AppSpace.s1),
                        AppSkeleton.box(width: 90, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
