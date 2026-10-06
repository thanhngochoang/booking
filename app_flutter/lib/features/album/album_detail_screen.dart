// lib/features/album/album_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/album/album_detail_controller.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_bottom_bar.dart';

/// S24.01 "Chi tiết album" at `/u/:uid/albums/:albumId`: an album read as a
/// set, with the way to book and to ask first kept in the bottom bar. The
/// owner can also arrange the posts in place and delete the album.
class AlbumDetailScreen extends ConsumerStatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.uid,
    required this.albumId,
  });

  final String uid;
  final String albumId;

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

enum _Menu { arrange, delete }

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  bool _arranging = false;
  bool _preparing = false;

  /// No public web host exists yet, so the in-app path is what is copied.
  String get _link => '/u/${widget.uid}/albums/${widget.albumId}';

  Future<void> _share() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.albumDetailLinkCopied)));
  }

  Future<void> _startArranging() async {
    setState(() => _preparing = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(albumPostsProvider(widget.albumId).notifier).loadAll();
    if (!mounted) {
      return;
    }
    // Reordering needs every post; a page that failed leaves some out.
    final complete =
        ref.read(albumPostsProvider(widget.albumId)).value?.hasMore == false;
    setState(() {
      _preparing = false;
      _arranging = complete;
    });
    if (!complete) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.albumDetailArrangeLoadFailed)));
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final deleted = await showConfirmSheet(
      context,
      title: l.albumDetailDeleteTitle,
      body: l.albumDetailDeleteBody,
      confirmLabel: l.albumDetailDelete,
      keepLabel: l.actionCancel,
      onConfirm: () async {
        try {
          await ref.read(albumRepositoryProvider).delete(widget.albumId);
        } catch (_) {
          throw Exception(l.albumDetailDeleteError);
        }
      },
    );
    if (!deleted || !mounted) {
      return;
    }
    _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/u/${widget.uid}');
    }
  }

  Future<void> _onMenu(_Menu item) async {
    switch (item) {
      case _Menu.arrange:
        await _startArranging();
      case _Menu.delete:
        await _delete();
    }
  }

  /// Saves a new order, then offers to undo it for a few seconds.
  Future<void> _reorder(List<String> before, List<String> after) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(albumPostsProvider(widget.albumId).notifier);
    // The undo may run after this screen is gone, so it uses the repository
    // itself, not the (then disposed) notifier.
    final repo = ref.read(albumRepositoryProvider);
    final ok = await notifier.reorder(after);
    if (!mounted) {
      return;
    }
    messenger.hideCurrentSnackBar();
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.albumDetailReorderFailed)),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.albumDetailReordered),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l.albumDetailUndo,
          onPressed: () async {
            try {
              await repo.reorderPosts(widget.albumId, before);
              if (mounted) {
                ref.invalidate(albumPostsProvider(widget.albumId));
              }
            } catch (_) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l.albumDetailReorderFailed)),
                );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final album = ref.watch(albumProvider(widget.albumId));
    final me = ref.watch(authRepositoryProvider).currentUser?.uid;
    final a = album.value;
    // The URL's uid must be the album's real owner, else it is not shown.
    final owner = a != null && me == a.photographerId;
    final visible =
        a != null && a.photographerId == widget.uid && (owner || a.visible);
    return ScreenCode(
      ScreenCodes.albumDetail,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/u/${widget.uid}'),
                  ),
            actions: [
              if (_arranging)
                TextButton(
                  key: const Key('album-arrange-done'),
                  onPressed: () => setState(() => _arranging = false),
                  child: Text(l.albumDetailArrangeDone),
                )
              else if (visible) ...[
                IconButton(
                  key: const Key('album-share'),
                  tooltip: l.albumDetailShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: _share,
                ),
                if (owner)
                  PopupMenuButton<_Menu>(
                    key: const Key('album-menu'),
                    tooltip: l.albumDetailMenu,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: _onMenu,
                    itemBuilder: (_) => [
                      if (a.postCount > 1)
                        PopupMenuItem(
                          value: _Menu.arrange,
                          child: Text(l.albumDetailArrange),
                        ),
                      PopupMenuItem(
                        value: _Menu.delete,
                        child: Text(
                          l.albumDetailDelete,
                          style: const TextStyle(color: AppColors.destructive),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
          body: AsyncView<AlbumSummary?>(
            value: album,
            onRetry: () => ref.invalidate(albumProvider(widget.albumId)),
            skeleton: (_) => const _Skeleton(),
            data: (context, value) => value == null || !visible
                ? _Gone(uid: widget.uid)
                : _Body(
                    album: value,
                    owner: owner,
                    arranging: _arranging,
                    preparing: _preparing,
                    onReorder: _reorder,
                  ),
          ),
          bottomNavigationBar: visible && !owner
              ? ProfileBottomBar(
                  photographerId: widget.uid,
                  owner: false,
                  onEdit: () {},
                )
              : null,
        ),
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      title: l.albumDetailGone,
      body: l.albumDetailGoneBody,
      actionLabel: l.photoViewProfile,
      onAction: () => context.go('/u/$uid'),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      AppSkeleton.line(widthFactor: 0.6, height: AppText.xl),
      const SizedBox(height: AppSpace.s3),
      AppSkeleton.line(widthFactor: 0.5),
      const SizedBox(height: AppSpace.s4),
      Row(
        children: [
          Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 3)),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 3)),
        ],
      ),
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.album,
    required this.owner,
    required this.arranging,
    required this.preparing,
    required this.onReorder,
  });

  final AlbumSummary album;
  final bool owner;
  final bool arranging;
  final bool preparing;
  final Future<void> Function(List<String> before, List<String> after)
  onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final posts = ref.watch(albumPostsProvider(album.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(
            album.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        _AuthorRow(album: album),
        if (album.description.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s3),
          Text(album.description, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpace.s4),
        if (preparing)
          const Padding(
            padding: EdgeInsets.all(AppSpace.s6),
            child: Center(child: DotRingLoader()),
          ),
        AsyncView<AlbumPostsState>(
          value: posts,
          onRetry: () => ref.invalidate(albumPostsProvider(album.id)),
          skeleton: (_) => Row(
            children: [
              Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 4)),
              const SizedBox(width: AppSpace.s2),
              Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 4)),
            ],
          ),
          isEmpty: (s) => s.posts.isEmpty,
          empty: (_) => owner
              ? EmptyState(
                  title: l.albumDetailEmptyOwner,
                  body: l.albumDetailEmptyOwnerBody,
                  actionLabel: l.albumDetailAddPosts,
                  onAction: () => context.push('/me/albums'),
                )
              : _Gone(uid: album.photographerId),
          data: (context, state) => arranging
              ? _ArrangeList(
                  albumId: album.id,
                  posts: state.posts,
                  onReorder: onReorder,
                )
              : _PostGrid(albumId: album.id, state: state),
        ),
      ],
    );
  }
}

class _AuthorRow extends ConsumerWidget {
  const _AuthorRow({required this.album});
  final AlbumSummary album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(
      photographerProfileProvider(album.photographerId),
    );
    return AsyncView(
      value: profile,
      skeleton: (_) => AppSkeleton.line(widthFactor: 0.5),
      error: (_, _, _) => const SizedBox.shrink(),
      data: (context, p) {
        if (p == null) {
          return const SizedBox.shrink();
        }
        final s = p.summary;
        return Row(
          key: const Key('album-author'),
          children: [
            AppAvatar(
              url: s.avatarUrl,
              name: s.displayName,
              size: AppAvatarSize.xs,
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: ProviderName(
                        s.displayName,
                        mark: providerMarkOf(
                          type: s.providerType,
                          verified: s.verified,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextSpan(
                      text:
                          ' · ${l.albumDetailCounts(album.postCount, album.mediaCount)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PostGrid extends ConsumerWidget {
  const _PostGrid({required this.albumId, required this.state});
  final String albumId;
  final AlbumPostsState state;

  /// Keeps one very tall or very wide photo from ruling its column.
  static const _minRatio = 0.75;
  static const _maxRatio = 1.25;

  double _ratio(PostSummary p) {
    final w = p.cover.width;
    final h = p.cover.height;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return 1;
    }
    return (w / h).clamp(_minRatio, _maxRatio);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Two columns: each post goes to the shorter one, in album order.
    final columns = [<PostSummary>[], <PostSummary>[]];
    final heights = [0.0, 0.0];
    for (final p in state.posts) {
      final c = heights[0] <= heights[1] ? 0 : 1;
      columns[c].add(p);
      heights[c] += 1 / _ratio(p);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, col) in columns.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Column(
                  children: [
                    for (final p in col)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s2),
                        child: _PostTile(post: p, ratio: _ratio(p)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: AppButton.outline(
              l.profileMorePhotos,
              key: const Key('album-more'),
              loading: state.loadingMore,
              onPressed: () =>
                  ref.read(albumPostsProvider(albumId).notifier).loadMore(),
            ),
          ),
      ],
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.ratio});
  final PostSummary post;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final radius = BorderRadius.circular(AppRadius.md);
    final n = post.images.length;
    return Semantics(
      button: true,
      label: [
        post.caption.isEmpty ? l.profilePhoto : post.caption,
        if (n > 1) l.albumPhotoCount(n),
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('album-post-${post.id}'),
        borderRadius: radius,
        onTap: () => context.push('/p/${post.id}'),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkPhoto(url: post.cover.url),
                if (n > 1)
                  Positioned(
                    top: AppSpace.s1,
                    right: AppSpace.s1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.overlay,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s2,
                          vertical: AppSpace.s1,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: AppText.xs2,
                              color: Colors.white,
                            ),
                            const SizedBox(width: AppSpace.s1),
                            Text(
                              '$n',
                              key: Key('album-post-count-${post.id}'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppText.xs,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owner's "Sắp xếp bài": a list instead of draggable grid tiles, saved on
/// every drop or menu move (Decision 10).
class _ArrangeList extends ConsumerWidget {
  const _ArrangeList({
    required this.albumId,
    required this.posts,
    required this.onReorder,
  });

  final String albumId;
  final List<PostSummary> posts;
  final Future<void> Function(List<String> before, List<String> after)
  onReorder;

  static const _thumb = AppSpace.s12;

  Future<void> _move(BuildContext context, int from, int to) async {
    if (to < 0 || to >= posts.length || to == from) {
      return;
    }
    final before = [for (final p in posts) p.id];
    final after = List.of(before);
    after.insert(to, after.removeAt(from));
    final l = context.l10n;
    final message = l.reorderPosition(to + 1, posts.length);
    final view = View.of(context);
    final direction = Directionality.of(context);
    await onReorder(before, after);
    await SemanticsService.sendAnnouncement(view, message, direction);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ReorderableListView.builder(
      key: const Key('album-arrange-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: posts.length,
      onReorderItem: (from, to) => _move(context, from, to),
      itemBuilder: (context, i) {
        final p = posts[i];
        final caption = p.caption.split('\n').first.trim();
        return ReorderableRow(
          key: ValueKey(p.id),
          index: i,
          count: posts.length,
          title: caption.isEmpty ? l.profilePhoto : caption,
          subtitle: l.albumPhotoCount(p.images.length),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: _thumb,
              height: _thumb,
              child: NetworkPhoto(url: p.cover.url),
            ),
          ),
          onMove: (to) => _move(context, i, to),
          extraMenu: [
            PopupMenuItem<VoidCallback>(
              value: () async {
                final ok = await ref
                    .read(albumPostsProvider(albumId).notifier)
                    .remove(p.id);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.albumDetailRemoveFailed)),
                  );
                }
              },
              child: Text(l.albumDetailRemove),
            ),
          ],
        );
      },
    );
  }
}
