// lib/features/album/add_posts_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/album/album_detail_controller.dart';
import 'package:photobooking/features/album/my_albums_controller.dart';

/// S24.04: choose posts of your own and file them in [album], at its end and
/// in the order chosen. Returns how many posts were added (null when closed
/// without adding any).
Future<int?> showAddPostsSheet(
  BuildContext context, {
  required AlbumSummary album,
}) async {
  final added = _Added();
  final result = await showAppSheet<int>(
    context,
    builder: (_) => ScreenCode(
      ScreenCodes.addPostsToAlbum,
      child: _AddPostsBody(album: album, added: added),
    ),
  );
  // Posts added before a failed batch still count when the sheet is closed.
  return result ?? (added.count > 0 ? added.count : null);
}

/// How many posts the sheet has filed so far, kept outside the sheet so the
/// caller still gets it after a partial failure.
class _Added {
  int count = 0;
}

class _AddPostsBody extends ConsumerStatefulWidget {
  const _AddPostsBody({required this.album, required this.added});
  final AlbumSummary album;
  final _Added added;

  @override
  ConsumerState<_AddPostsBody> createState() => _AddPostsBodyState();
}

class _AddPostsBodyState extends ConsumerState<_AddPostsBody> {
  MyPostsFilter _tab = MyPostsFilter.unsorted;

  /// Post ids in the order they were picked.
  List<String> _selected = [];
  bool _busy = false;
  String? _error;

  AlbumSummary get _album => widget.album;
  int get _room => (kMaxAlbumPosts - _album.postCount - widget.added.count)
      .clamp(0, kMaxAlbumPosts);

  void _toggle(String id) {
    if (_busy) {
      return;
    }
    setState(() {
      _error = null;
      _selected = _selected.contains(id)
          ? [
              for (final s in _selected)
                if (s != id) s,
            ]
          : [..._selected, id];
    });
  }

  void _refresh() {
    ref.invalidate(myPostsProvider(MyPostsFilter.unsorted));
    ref.invalidate(myPostsProvider(MyPostsFilter.all));
    ref.invalidate(albumProvider(_album.id));
    ref.invalidate(albumPostsProvider(_album.id));
  }

  /// Sends the picked posts in batches of [kMaxMovePerCall], in order.
  Future<void> _add() async {
    if (_selected.isEmpty || _busy) {
      return;
    }
    final l = context.l10n;
    final repo = ref.read(albumRepositoryProvider);
    final ids = List.of(_selected);
    setState(() {
      _busy = true;
      _error = null;
    });
    var done = 0;
    try {
      for (var i = 0; i < ids.length; i += kMaxMovePerCall) {
        final end = (i + kMaxMovePerCall).clamp(0, ids.length);
        await repo.movePosts(_album.id, ids.sublist(i, end));
        done = end;
        widget.added.count += end - i;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (done > 0) {
        _refresh();
      }
      setState(() {
        _busy = false;
        _selected = ids.sublist(done);
        _error = done > 0
            ? l.addPostsPartial(done, ids.length - done)
            : (e is AlbumError && e.code == 'limit_exceeded'
                  ? l.addPostsFull
                  : l.addPostsError);
      });
      return;
    }
    _refresh();
    if (mounted) {
      Navigator.of(context).pop(done);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unsorted = ref.watch(myPostsProvider(MyPostsFilter.unsorted));
    final all = ref.watch(myPostsProvider(MyPostsFilter.all));
    final titles = {
      for (final a in ref.watch(myAlbumsProvider).value ?? const [])
        a.id: a.title,
    };

    // Every post seen so far, to look up the picked ones.
    final known = <String, PostSummary>{
      for (final p in all.value?.posts ?? const <PostSummary>[]) p.id: p,
      for (final p in unsorted.value?.posts ?? const <PostSummary>[]) p.id: p,
    };
    final inThis = (all.value?.posts ?? const <PostSummary>[])
        .where((p) => p.albumId == _album.id)
        .length;
    final allCount = all.hasValue
        ? '${all.value!.posts.length - inThis}${all.value!.hasMore ? '+' : ''}'
        : '…';
    final unsortedCount = unsorted.value?.countLabel ?? '…';

    final from = <String>{};
    var moving = 0;
    for (final id in _selected) {
      final other = known[id]?.albumId;
      if (other != null && other != _album.id) {
        moving++;
        from.add(titles[other] ?? '');
      }
    }
    final full = _selected.length >= _room;

    final noPosts =
        all.hasValue && all.value!.posts.isEmpty && !all.value!.hasMore;

    final active = _tab == MyPostsFilter.unsorted ? unsorted : all;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s2,
            AppSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l.addPostsTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l.addPostsSelected(_selected.length),
                        key: const Key('add-posts-selected'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('add-posts-close'),
                tooltip: l.albumEditClose,
                constraints: const BoxConstraints.tightFor(
                  width: AppSpace.s12,
                  height: AppSpace.s12,
                ),
                icon: const Icon(Icons.close_rounded),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (noPosts)
          Flexible(
            child: EmptyState(
              title: l.addPostsNoneTitle,
              body: l.addPostsNoneBody,
              actionLabel: l.addPostsNoneAction,
              onAction: () {
                final router = GoRouter.maybeOf(context);
                Navigator.of(context).pop();
                router?.go(AppTab.action.path);
              },
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            child: SegmentedTabs<MyPostsFilter>(
              value: _tab,
              onChanged: (t) => setState(() => _tab = t),
              options: [
                SegmentOption(
                  value: MyPostsFilter.unsorted,
                  label: l.addPostsTabUnsorted(unsortedCount),
                ),
                SegmentOption(
                  value: MyPostsFilter.all,
                  label: l.addPostsTabAll(allCount),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: AsyncView<MyPostsState>(
                value: active,
                onRetry: () => ref.invalidate(myPostsProvider(_tab)),
                skeleton: (_) => _GridSkeleton(),
                error: (context, _, _) => ErrorState(
                  message: l.addPostsLoadError,
                  onRetry: () => ref.invalidate(myPostsProvider(_tab)),
                ),
                data: (context, state) {
                  final posts = [
                    for (final p in state.posts)
                      if (p.albumId != _album.id) p,
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (posts.isEmpty && !state.hasMore)
                        Padding(
                          padding: const EdgeInsets.all(AppSpace.s5),
                          child: Text(
                            l.addPostsUnsortedEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      else if (posts.isNotEmpty)
                        PostPickerGrid(
                          items: [
                            for (final p in posts)
                              PostPickItem(
                                postId: p.id,
                                thumbUrl: p.cover.url,
                                imageCount: p.images.length,
                                albumTitle: p.albumId == null
                                    ? null
                                    : (titles[p.albumId] ?? ''),
                                label: p.caption.split('\n').first.trim(),
                              ),
                          ],
                          selected: _selected,
                          maxSelected: _room,
                          onToggle: _toggle,
                        ),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s2),
                          child: AppButton.outline(
                            l.addPostsMore,
                            key: const Key('add-posts-more'),
                            loading: state.loadingMore,
                            onPressed: () => ref
                                .read(myPostsProvider(_tab).notifier)
                                .loadMore(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s5,
              AppSpace.s3,
              AppSpace.s5,
              AppSpace.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (moving > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: AppText.base,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Text(
                            from.length == 1
                                ? l.addPostsMoveWarn(moving, from.single)
                                : l.addPostsMoveWarnMany(moving),
                            key: const Key('add-posts-warn'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (full)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: Text(
                      l.addPostsFull,
                      key: const Key('add-posts-full'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const Key('add-posts-error'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ),
                AppButton.primary(
                  _selected.isEmpty
                      ? l.addPostsPick
                      : l.addPostsAdd(_selected.length),
                  key: const Key('add-posts-submit'),
                  loading: _busy,
                  onPressed: _selected.isEmpty ? null : _add,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var r = 0; r < 2; r++) ...[
        if (r > 0) const SizedBox(height: AppSpace.s1),
        Row(
          children: [
            for (var c = 0; c < PostPickerGrid.columns; c++) ...[
              if (c > 0) const SizedBox(width: AppSpace.s1),
              Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 2)),
            ],
          ],
        ),
      ],
    ],
  );
}
