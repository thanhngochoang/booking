import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/saved/follow_list_controller.dart';
import 'package:photobooking/features/saved/saved_controller.dart';

class FollowingScreen extends ConsumerStatefulWidget {
  const FollowingScreen({super.key});

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _locallyUnfollowed = {};

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
      ref.read(followingControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final asyncFollowing = ref.watch(followingControllerProvider);
    final counts = ref.watch(socialCountsProvider).value;
    final count = counts?.following ?? (asyncFollowing.value?.items.length ?? 0);

    return ScreenCode(
      ScreenCodes.following,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l.followingTitle),
          leading: context.canPop()
              ? BackButton(
                  onPressed: () => context.pop(),
                )
              : null,
        ),
        body: AsyncView<SavedListState<PhotographerSummary>>(
          value: asyncFollowing,
          onRetry: () =>
              ref.read(followingControllerProvider.notifier).refresh(),
          skeleton: (_) => _FollowingSkeletonList(),
          isEmpty: (state) => state.items.isEmpty,
          empty: (context) => EmptyState(
            title: l.followingEmptyTitle,
            body: l.followingEmptyBody,
            actionLabel: l.followingEmptyAction,
            onAction: () => context.go('/explore'),
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
                      l.followingCount(count),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColorsDark.foregroundSecondary
                                : AppColors.foregroundSecondary,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
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
                            _FollowingRow(
                              photographer: items[i],
                              isUnfollowedLocally:
                                  _locallyUnfollowed.contains(items[i].id),
                              onToggle: (unfollowedNow) {
                                setState(() {
                                  if (unfollowedNow) {
                                    _locallyUnfollowed.add(items[i].id);
                                  } else {
                                    _locallyUnfollowed.remove(items[i].id);
                                  }
                                });
                              },
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
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    ),
                  ),
                if (state.moreFailed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: Center(
                        child: TextButton(
                          key: const Key('following-retry'),
                          onPressed: () => ref
                              .read(followingControllerProvider.notifier)
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

class _FollowingRow extends ConsumerWidget {
  const _FollowingRow({
    required this.photographer,
    required this.isUnfollowedLocally,
    required this.onToggle,
  });

  final PhotographerSummary photographer;
  final bool isUnfollowedLocally;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mark = providerMarkOf(
      type: photographer.providerType,
      verified: photographer.verified,
    );

    final genre = photographer.specialtyIds.isNotEmpty
        ? specialtyLabel(photographer.specialtyIds.first)
        : null;
    final area = photographer.areaLabel;
    final metaText = [genre, area]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');

    final isFollowing = !isUnfollowedLocally;

    return InkWell(
      key: Key('following-row-${photographer.id}'),
      onTap: () => context.push('/u/${photographer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2h,
          vertical: AppSpace.s2h,
        ),
        child: Row(
          children: [
            AppAvatar(
              url: photographer.avatarUrl,
              name: photographer.displayName,
              size: AppAvatarSize.sm,
              decorative: true,
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProviderName(
                    photographer.displayName,
                    mark: mark,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (metaText.isNotEmpty)
                    Text(
                      metaText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColorsDark.foregroundSecondary
                                : AppColors.foregroundSecondary,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            AppButton.outline(
              isFollowing ? l.followingButton : l.followButton,
              key: Key('following-btn-${photographer.id}'),
              size: AppButtonSize.xsmall,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final wantUnfollow = isFollowing;

                // Toggle state
                onToggle(wantUnfollow);
                final ok = await ref
                    .read(followProvider.notifier)
                    .toggle(photographer.id);

                if (!ok) {
                  // Revert if failed
                  onToggle(!wantUnfollow);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text(l.socialToggleFailed)),
                  );
                  return;
                }

                if (wantUnfollow) {
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        l.followingUnfollowed(photographer.displayName),
                      ),
                      action: SnackBarAction(
                        label: l.savedUndo,
                        onPressed: () async {
                          onToggle(false);
                          final undoOk = await ref
                              .read(followProvider.notifier)
                              .toggle(photographer.id);
                          if (!undoOk) {
                            onToggle(true);
                            messenger.showSnackBar(
                              SnackBar(content: Text(l.socialToggleFailed)),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s4),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
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
                        AppSkeleton.box(width: 80, height: 12),
                      ],
                    ),
                  ),
                  AppSkeleton.box(width: 70, height: 30, radius: AppRadius.lg),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
