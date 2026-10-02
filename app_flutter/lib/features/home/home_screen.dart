import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/features/home/home_controller.dart';

const _chipSpecialties = ['portrait', 'wedding', 'family', 'graduation'];

/// Items load when fewer than this many dp remain below the viewport.
const _loadMoreExtent = 600.0;

/// Width of the "Rảnh tuần này" cards (mock) and their 3:4 aspect.
const _freeCardWidth = 120.0;
const _freeCardAspect = 3 / 4;

/// "Buổi chụp thật" is a two-column grid at every width.
const _realShootColumns = 2;
const _realShootAspect = 0.8;

/// The hero card never grows past this on wide screens.
const _heroMaxWidth = 560.0;

/// S02.01. Photos first: the large card, who is free this week, real shoots.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _offsets = <String?, double>{};
  String? _selected;
  double? _restoreTo;

  @override
  void initState() {
    super.initState();
    // The feed provider outlives the screen: start on its chip.
    _selected = ref.read(homeFeedProvider).value?.category;
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < _loadMoreExtent) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _select(String? category) async {
    if (category == _selected) {
      return;
    }
    if (_scroll.hasClients) {
      _offsets[_selected] = _scroll.offset;
    }
    setState(() => _selected = category);
    _restoreTo = _offsets[category] ?? 0.0;
    await ref.read(homeFeedProvider.notifier).selectCategory(category);
    final target = _restoreTo;
    _restoreTo = null;
    if (target == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          math.min(_scroll.position.maxScrollExtent, math.max(0.0, target)),
        );
      }
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(freeThisWeekProvider);
    ref.invalidate(realShootsProvider);
    await ref.read(homeFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final feed = ref.watch(homeFeedProvider);
    ref.listen(homeFeedProvider, (_, next) {
      // A reset (another user signed in) puts the feed back on "Dành cho bạn".
      final loaded = next.hasValue && !next.isLoading ? next.value : null;
      if (loaded != null && loaded.category != _selected) {
        setState(() => _selected = loaded.category);
      }
    });
    final profile = ref.watch(currentProfileProvider).value;
    final customer = profile?.role != UserRole.photographer;

    List<Widget> body() {
      if (feed.isLoading) {
        return [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpace.s4),
            sliver: SliverToBoxAdapter(child: AppSkeleton.card(height: 360)),
          ),
        ];
      }
      if (!feed.hasValue) {
        return [
          SliverToBoxAdapter(
            child: ErrorState(
              message: l.homeLoadError,
              onRetry: () =>
                  ref.read(homeFeedProvider.notifier).selectCategory(_selected),
            ),
          ),
        ];
      }
      final data = feed.requireValue;
      if (data.items.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: l.homeEmptyTitle,
              body: l.homeEmptyBody,
              actionLabel: l.homeEmptyAction,
              onAction: () => context.go(AppTab.explore.path),
            ),
          ),
        ];
      }
      final items = data.items;
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _heroMaxWidth),
                child: _PostBlock(item: items.first),
              ),
            ),
          ),
        ),
        _FreeThisWeekSection(customer: customer),
        const _RealShootsSection(),
        if (items.length > 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s5,
              AppSpace.s4,
              0,
            ),
            sliver: SliverAdaptiveRows(
              itemCount: items.length - 1,
              itemBuilder: (_, i) => _PostBlock(item: items[i + 1]),
            ),
          ),
        if (data.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s4),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s8)),
      ];
    }

    // The greeting and the chips stay put; only the feed scrolls, so a chip is
    // always reachable and each keeps its own scroll position.
    return ScreenCode(
      ScreenCodes.home,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  AppSpace.s4,
                  AppSpace.s4,
                  AppSpace.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.homeGreeting(profile?.displayName ?? ''),
                      style: theme.textTheme.bodySmall,
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l.homeTitle,
                        style: tabRootTitleStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                child: Row(
                  children: [
                    AppChip(
                      key: const Key('home-chip-all'),
                      kind: AppChipKind.context,
                      label: l.homeForYou,
                      selected: _selected == null,
                      onChanged: (_) => _select(null),
                    ),
                    for (final id in _chipSpecialties) ...[
                      const SizedBox(width: AppSpace.s2),
                      AppChip(
                        key: Key('home-chip-$id'),
                        kind: AppChipKind.context,
                        label: specialtyLabel(id),
                        selected: _selected == id,
                        onChanged: (_) => _select(id),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: body(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s5,
        AppSpace.s4,
        AppSpace.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A large post: photo with pills, the author row and a save disc on it (as
/// in the mock), then the reasons it is recommended.
class _PostBlock extends ConsumerWidget {
  const _PostBlock({required this.item});
  final RecommendedPost item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final post = item.post;
    final p = item.photographer;
    final saved = ref.watch(
      engagementProvider.select((m) => m[post.id]?.saved ?? false),
    );
    final pill = freeThisWeekLabel(p, ref.watch(clockProvider)(), l);
    final specialty =
        post.specialtyId ??
        (p.specialtyIds.isEmpty ? null : p.specialtyIds.first);
    final from = [
      if (specialty != null) specialtyLabel(specialty),
      ?priceFromLabel(p.startingPriceVnd, l),
    ].join(' · ');
    final nameStyle = theme.textTheme.titleMedium?.copyWith(
      color: AppColors.foregroundInverse,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoCard(
          key: Key('post-${post.id}'),
          imageUrl: post.cover.url,
          blurHash: post.cover.blurHash,
          aspect: 4 / 5,
          leadingPill: pill == null
              ? null
              : PhotoPill(label: pill, dot: PhotoPillDot.ok),
          trailingPill: from.isEmpty ? null : PhotoPill(label: from),
          overlay: InkWell(
            key: Key('author-${post.id}'),
            onTap: () => context.push('/u/${p.id}'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: controlHeight),
              child: Row(
                children: [
                  AppAvatar(
                    url: p.avatarUrl,
                    name: p.displayName,
                    size: AppAvatarSize.sm,
                    decorative: true,
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.verified)
                          VerifiedName(p.displayName, style: nameStyle)
                        else
                          Text(p.displayName, style: nameStyle),
                        Text(
                          areaRatingMeta(p, l),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.foregroundInverse,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          action: IconButton(
            key: Key('save-${post.id}'),
            tooltip: saved ? l.photoUnsave : l.photoSave,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.overlay,
              foregroundColor: AppColors.foregroundInverse,
            ),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              final ok = await ref
                  .read(engagementProvider.notifier)
                  .toggleSave(post.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.engagementError)));
              }
            },
          ),
          onTap: () => context.push('/p/${post.id}'),
        ),
        ReasonChips(reasons: item.reasons),
      ],
    );
  }
}

class _FreeThisWeekSection extends ConsumerWidget {
  const _FreeThisWeekSection({required this.customer});
  final bool customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref
        .watch(freeThisWeekProvider)
        .when(
          loading: () => const SliverToBoxAdapter(),
          error: (_, _) => const SliverToBoxAdapter(),
          data: (list) {
            final shown = list.where((p) => p.heroUrl != null).toList();
            if (shown.isEmpty) {
              return const SliverToBoxAdapter();
            }
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: l.homeFreeThisWeek,
                    trailing: customer
                        ? TextButton(
                            onPressed: () => context.go(AppTab.action.path),
                            child: Text(l.exploreSeeAll),
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: _freeCardWidth / _freeCardAspect,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s4,
                      ),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpace.s2),
                      itemBuilder: (context, i) {
                        final p = shown[i];
                        final specialty = p.specialtyIds.isEmpty
                            ? null
                            : specialtyLabel(p.specialtyIds.first);
                        final from = [
                          ?specialty,
                          ?priceFromLabel(p.startingPriceVnd, l),
                        ].join(' · ');
                        return SizedBox(
                          width: _freeCardWidth,
                          child: PhotoCard(
                            key: Key('free-${p.id}'),
                            imageUrl: p.heroUrl!,
                            aspect: _freeCardAspect,
                            title: p.displayName,
                            subtitle: from.isEmpty ? null : from,
                            onTap: () => context.push('/u/${p.id}'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _RealShootsSection extends ConsumerWidget {
  const _RealShootsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref
        .watch(realShootsProvider)
        .when(
          loading: () => const SliverToBoxAdapter(),
          error: (_, _) => const SliverToBoxAdapter(),
          data: (list) {
            if (list.isEmpty) {
              return const SliverToBoxAdapter();
            }
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: l.homeRealShoots,
                    trailing: Text(
                      l.homeFromCustomers,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _realShootColumns,
                          mainAxisSpacing: AppSpace.s2,
                          crossAxisSpacing: AppSpace.s2,
                          childAspectRatio: _realShootAspect,
                        ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final f = list[i];
                      return PhotoCard(
                        key: Key('real-${f.post.id}'),
                        imageUrl: f.post.cover.url,
                        aspect: 4 / 5,
                        title: l.homeRealShootBy(f.photographer.displayName),
                        onTap: () => context.push('/p/${f.post.id}'),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}
