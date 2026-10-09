import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/awards/award_nudge.dart';
import 'package:photobooking/features/profile/profile_posts_controller.dart';
import 'package:photobooking/features/settings/settings_links.dart';

/// S09.01 Hồ sơ: the user's own posts (all kinds, newest first) under a
/// header row, the Thông báo row, counts and badges; photographers also get
/// their work links. Mode switch and sign-out live in S09.02 (gear). No
/// primary button, except "Đăng bài đầu tiên" on a photographer's empty tab.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  /// The kind chip; null for "Tất cả".
  PostKind? _filter;

  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// After a page lands (or the filter changes) the content may not reach
  /// past the screen, so no scroll will come: check the position once laid
  /// out.
  void _checkEndAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _onScrollMetrics(_scroll.position, 0);
      }
    });
  }

  void _choose(PostKind? kind) {
    if (kind != _filter) {
      setState(() => _filter = kind);
    }
  }

  /// Pull to refresh (and the first-load retry): the grid of the current
  /// filter from its first page, and the counts. When the grid was showing
  /// posts and the reload failed, they stay and a SnackBar says so.
  Future<void> _refresh() async {
    final filter = _filter;
    final hadPosts = ref.read(profilePostsProvider(filter)).hasValue;
    ref.invalidate(profilePostCountsProvider);
    final (ok, _) = await (
      ref.read(profilePostsProvider(filter).notifier).refresh(),
      ref
          .read(profilePostCountsProvider.future)
          .then<void>((_) {}, onError: (_) {}),
    ).wait;
    if (!ok && hadPosts && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.profilePostsError)));
    }
  }

  /// How close to the end of the tab (px still below the viewport) the next
  /// page is asked for: about one row of tiles.
  static const _loadMoreWithin = 200.0;

  /// The tab's own vertical scroll moved or its content changed: near the
  /// end, ask for the next page. Driven by the scroll position, not by a
  /// built widget: slivers build ahead within the cache extent, so a footer
  /// or the last tile is built on open and would read pages unasked.
  bool _onScrollMetrics(ScrollMetrics metrics, int depth) {
    if (depth == 0 &&
        metrics.axis == Axis.vertical &&
        metrics.extentAfter < _loadMoreWithin) {
      _loadMoreSoon(_filter);
    }
    return false;
  }

  /// After the frame, and only if the state still wants the same page it
  /// wanted when the scroll got near the end (a page that landed in between
  /// moved the end away); the controller also ignores calls while a page is
  /// in flight.
  void _loadMoreSoon(PostKind? filter) {
    bool wants(ProfilePostsState? s) =>
        s != null && s.nextCursor != null && !s.loadingMore && !s.moreError;
    final now = ref.read(profilePostsProvider(filter)).value;
    if (!wants(now)) {
      return;
    }
    final cursor = now!.nextCursor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || filter != _filter) {
        return;
      }
      final s = ref.read(profilePostsProvider(filter)).value;
      if (!wants(s) || s!.nextCursor != cursor) {
        return;
      }
      ref.read(profilePostsProvider(filter).notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    // A chosen kind that no longer has posts (or the only kind left, whose
    // chip row hides) falls back to "Tất cả".
    ref.listen<AsyncValue<ProfilePostCounts>>(profilePostCountsProvider, (
      _,
      next,
    ) {
      final counts = next.value;
      final kind = _filter;
      if (counts != null &&
          kind != null &&
          (counts.of(kind) == 0 || counts.present.length < 2)) {
        _choose(null);
      }
    });
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider).value;
    final isPhotographer = profile?.role == UserRole.photographer;
    final setupOpen =
        isPhotographer &&
        !(ref.watch(myIntroProvider).value?.onboardingComplete ?? true);
    final counts = ref.watch(profilePostCountsProvider);
    final present = counts.value?.present ?? const <PostKind>[];
    const gap = SizedBox(height: AppSpace.s3);
    return ScreenCode(
      ScreenCodes.profile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          title: Text(l.tabProfile),
          actions: [
            IconButton(
              key: const Key('open-settings'),
              tooltip: l.settingsTitle,
              icon: const AppIcon(AppIcons.settings),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _onScrollMetrics(n.metrics, n.depth),
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (n) => _onScrollMetrics(n.metrics, n.depth),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s4,
                        AppSpace.s1,
                        AppSpace.s4,
                        AppSpace.s3,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _Header(profile: profile),
                          gap,
                          const _NotificationsRow(),
                          gap,
                          _CountsRow(counts: counts),
                          if (profile != null) ...[
                            gap,
                            _BadgesRow(uid: profile.uid),
                          ],
                          if (setupOpen) ...[gap, const _SetupCard()],
                          if (isPhotographer) ...[
                            gap,
                            const _MyAlbumsRow(),
                            const SizedBox(height: AppSpace.s2),
                            const _EarningsRow(),
                            AwardNudgeRow(uid: profile!.uid),
                          ],
                          if (present.length >= 2) ...[
                            gap,
                            _KindChips(
                              counts: counts.requireValue,
                              selected: _filter,
                              onChanged: _choose,
                            ),
                          ],
                        ],
                      ),
                    ),
                    ..._grid(context, isPhotographer: isPhotographer),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _grid(BuildContext context, {required bool isPhotographer}) {
    final l = context.l10n;
    final filter = _filter;
    final async = ref.watch(profilePostsProvider(filter));
    const pad = EdgeInsets.symmetric(horizontal: AppSpace.s4);
    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: AppSpace.s1,
      crossAxisSpacing: AppSpace.s1,
    );
    final state = async.value;
    if (state == null) {
      if (async.hasError) {
        return [
          SliverToBoxAdapter(
            child: ErrorState(message: l.profilePostsError, onRetry: _refresh),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverGrid.builder(
            gridDelegate: delegate,
            itemCount: 9,
            itemBuilder: (_, _) => const _TileSkeleton(),
          ),
        ),
      ];
    }
    if (state.posts.isEmpty && state.nextCursor == null) {
      if (filter != null) {
        return const [];
      }
      return [
        SliverToBoxAdapter(
          child: isPhotographer
              ? EmptyState(
                  title: l.profileEmptyPhotographerTitle,
                  actionLabel: l.profileEmptyPhotographerAction,
                  onAction: () => context.go('/action'),
                )
              : EmptyState(
                  title: l.profileEmptyCustomerTitle,
                  body: l.profileEmptyCustomerBody,
                ),
        ),
      ];
    }
    final notifier = ref.read(profilePostsProvider(filter).notifier);
    if (state.nextCursor != null && !state.loadingMore && !state.moreError) {
      _checkEndAfterLayout();
    }
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverGrid.builder(
          gridDelegate: delegate,
          itemCount: state.posts.length,
          itemBuilder: (_, i) {
            final post = state.posts[i];
            return _PostTile(
              key: Key('profile-post-${post.id}'),
              post: post,
              index: i,
              showTag: filter == null,
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _GridFooter(state: state, onLoadMore: notifier.loadMore),
      ),
    ];
  }
}

/// Mock row: large avatar left; name (display font) and role right.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final name = profile?.displayName ?? '';
    final role = profile?.role == UserRole.photographer
        ? l.profileRolePhotographer
        : l.profileRoleCustomer;
    return Row(
      key: const Key('profile-header'),
      children: [
        AppAvatar(url: profile?.avatarUrl, name: name, size: AppAvatarSize.lg),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              Text(
                role,
                key: const Key('profile-role'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "9 bài đăng"; "đang theo dõi" and "đã lưu" join once S19 exists (no
/// links until then).
class _CountsRow extends ConsumerWidget {
  const _CountsRow({required this.counts});

  final AsyncValue<ProfilePostCounts> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final total = counts.value?.total;
    return Wrap(
      spacing: AppSpace.s5,
      runSpacing: AppSpace.s2,
      children: [
        _CountTile(
          key: const Key('profile-count-posts'),
          value: total?.toString(),
          loading: total == null && !counts.hasError,
          label: l.profilePostsCount,
        ),
        if (ref.watch(savedListsReadyProvider)) ...[
          _CountTile(
            key: const Key('profile-count-following'),
            value: null,
            label: l.profileFollowingCount,
          ),
          _CountTile(
            key: const Key('profile-count-saved'),
            value: null,
            label: l.profileSavedCount,
          ),
        ],
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    super.key,
    required this.value,
    required this.label,
    this.loading = false,
  });

  /// Null shows "—" (unknown).
  final String? value;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: AppSkeleton.line(width: AppSpace.s6, height: 16),
            )
          else
            Text(
              value ?? '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// "Tất cả · n" and one chip per kind the user has, in kind order.
class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  final ProfilePostCounts counts;
  final PostKind? selected;
  final ValueChanged<PostKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String label(PostKind kind) => switch (kind) {
      PostKind.work => l.profileFilterWork(counts.of(kind)),
      PostKind.realShoot => l.profileFilterRealShoot(counts.of(kind)),
      PostKind.eventShare => l.profileFilterEventShare(counts.of(kind)),
    };
    Widget chip(PostKind? kind, String text) => Padding(
      padding: const EdgeInsets.only(right: AppSpace.s2),
      child: AppChip(
        key: Key('profile-filter-${kind?.code ?? 'all'}'),
        label: text,
        selected: selected == kind,
        onChanged: (_) => onChanged(kind),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(null, l.profileFilterAll(counts.total)),
          for (final kind in counts.present) chip(kind, label(kind)),
        ],
      ),
    );
  }
}

/// A square cover; on "Tất cả" real shoots and event shares carry a corner
/// tag. Opens S02.02.
class _PostTile extends StatelessWidget {
  const _PostTile({
    super.key,
    required this.post,
    required this.index,
    required this.showTag,
  });

  final PostSummary post;
  final int index;
  final bool showTag;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final caption = post.caption.split('\n').first.trim();
    final tag = !showTag
        ? null
        : switch (post.kind) {
            PostKind.work => null,
            PostKind.realShoot => l.profileTagRealShoot,
            PostKind.eventShare => l.profileTagEventShare,
          };
    void open() => context.push('/p/${post.id}');
    return Semantics(
      button: true,
      label: caption.isEmpty ? l.profilePostTile(index + 1) : caption,
      excludeSemantics: true,
      onTap: open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkPhoto(url: post.cover.url),
            if (tag != null)
              Positioned(
                left: AppSpace.s1,
                bottom: AppSpace.s1,
                right: AppSpace.s1,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _KindTag(tag),
                ),
              ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: open),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mock `.tag` on a tile corner.
class _KindTag extends StatelessWidget {
  const _KindTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: dark ? AppColorsDark.border : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: dark ? AppColorsDark.foreground : AppColors.foreground,
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) =>
        AppSkeleton.box(height: box.maxHeight, radius: AppRadius.md),
  );
}

/// Under the grid: a loader while the next page comes, or a retry row after
/// a failure. The page itself is asked for by the scroll position (see
/// `_onScrollMetrics`), never by this eagerly built footer.
class _GridFooter extends StatelessWidget {
  const _GridFooter({required this.state, required this.onLoadMore});

  final ProfilePostsState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.moreError) {
      final theme = Theme.of(context);
      return Semantics(
        button: true,
        child: InkWell(
          key: const Key('profile-posts-more-error'),
          onTap: onLoadMore,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Text(
                context.l10n.profilePostsMoreError,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.s4),
        child: Center(child: DotRingLoader(size: LoaderSize.inline)),
      );
    }
    return const SizedBox(height: AppSpace.s6);
  }
}

/// The unfinished-setup card (S08.01), photographers only.
class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.profileSetupTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpace.s1),
            Text(l.profileSetupBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              l.profileSetupContinue,
              key: const Key('continue-setup'),
              icon: const AppIcon(AppIcons.forward),
              onPressed: () => context.push('/setup'),
            ),
          ],
        ),
      ),
    );
  }
}

/// S09.01: up to three earned badges under the Thông báo row. "Tất cả" is
/// always there so S03.02 (locked badges and progress) stays reachable.
class _BadgesRow extends ConsumerWidget {
  const _BadgesRow({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeChipsProvider(uid)).value ?? const [];
    return BadgeRow(
      key: const Key('profile-tab-badges'),
      badges: badges,
      max: 3,
      alwaysShowSeeAll: true,
      onSeeAll: () => context.push('/u/$uid/badges'),
    );
  }
}

/// S09.01: photographers open S24.02 from here.
class _MyAlbumsRow extends StatelessWidget {
  const _MyAlbumsRow();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkRow(
      key: const Key('open-my-albums'),
      icon: AppIcons.album,
      title: l.profileMyAlbums,
      sub: l.profileMyAlbumsSub,
      path: '/me/albums',
    );
  }
}

/// S09.01: photographers open S06.05 Thu nhập from here (the mock is silent;
/// same card as "Album của tôi").
class _EarningsRow extends StatelessWidget {
  const _EarningsRow();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkRow(
      key: const Key('open-earnings'),
      icon: AppIcons.wallet,
      title: l.profileEarnings,
      sub: l.profileEarningsSub,
      path: '/work/earnings',
    );
  }
}

/// A glass card with an icon, a title and a sub line that opens [path].
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String sub;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      highlight: false,
      child: Semantics(
        button: true,
        label: '$title. $sub',
        excludeSemantics: true,
        onTap: () => context.push(path),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push(path),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                children: [
                  AppIcon(icon),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(sub, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const AppIcon(AppIcons.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S09.01: the newest notification and the unread count; opens S17.01. Reads
/// the count from the one `unreadCount` document and re-fetches the newest
/// row when it changes; it never listens to the inbox itself.
class _NotificationsRow extends ConsumerWidget {
  const _NotificationsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final latest = ref.watch(latestNotificationProvider).value;
    final summary = latest?.title ?? l.notifEmptyTitle;
    final scheme = theme.colorScheme;
    void open() => context.push('/notifications');
    return GlassCard(
      highlight: false,
      child: Semantics(
        button: true,
        label: unread > 0
            ? l.notifRowSemantics(unread, summary)
            : l.notifRowSemanticsRead(summary),
        excludeSemantics: true,
        onTap: open,
        child: InkWell(
          key: const Key('open-notifications'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColorsDark.surfaceMuted
                          : AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: AppIcon(
                          AppIcons.notifications,
                          color: context.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.notificationTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: AppSpace.s2),
                    DecoratedBox(
                      key: const Key('notifications-count'),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: 2,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppText.xs2,
                              fontWeight: FontWeight.w700,
                              color: scheme.onError,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpace.s1),
                  const AppIcon(AppIcons.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
