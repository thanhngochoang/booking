// lib/features/album/my_albums_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/features/album/add_posts_sheet.dart';
import 'package:photobooking/features/album/edit_album_sheet.dart';
import 'package:photobooking/features/album/my_albums_controller.dart';
import 'package:photobooking/features/create_post/album_picker_sheet.dart';

/// S24.02 "Album của tôi" at `/me/albums`: create albums and put them in the
/// order they have on the profile, like folders. Drag the handle, or use the
/// "…" menu to move a row without dragging.
class MyAlbumsScreen extends ConsumerWidget {
  const MyAlbumsScreen({super.key});

  Future<void> _new(BuildContext context) => showEditAlbumSheet(context);

  /// Saves [after] as the new order, then offers to undo for five seconds.
  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    List<String> before,
    List<String> after,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // The undo may run after this screen is gone, so it uses the repository
    // itself, not a provider that is then disposed.
    final repo = ref.read(albumRepositoryProvider);
    final view = View.of(context);
    final direction = Directionality.of(context);
    HapticFeedback.selectionClick();
    final ok = await ref.read(albumOrderProvider.notifier).reorder(after);
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
              await repo.reorder(before);
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
    await SemanticsService.sendAnnouncement(
      view,
      l.albumDetailReordered,
      direction,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AlbumSummary a,
  ) async {
    final l = context.l10n;
    final repo = ref.read(albumRepositoryProvider);
    await showConfirmSheet(
      context,
      title: l.albumDetailDeleteTitle,
      body: l.albumDetailDeleteBody,
      confirmLabel: l.albumDetailDelete,
      keepLabel: l.actionCancel,
      onConfirm: () async {
        try {
          await repo.delete(a.id);
        } catch (_) {
          throw Exception(l.albumDetailDeleteError);
        }
      },
    );
  }

  /// "Chưa xếp album": pick the album to file posts in, then pick the posts.
  Future<void> _openUnsorted(BuildContext context, WidgetRef ref) async {
    final pick = await showAlbumPicker(context, allowNone: false);
    final id = pick?.albumId;
    if (id == null || !context.mounted) {
      return;
    }
    final known = ref.read(myAlbumsProvider).value ?? const <AlbumSummary>[];
    AlbumSummary? album;
    for (final a in known) {
      if (a.id == id) {
        album = a;
      }
    }
    album ??= await ref.read(albumRepositoryProvider).album(id);
    if (album != null && context.mounted) {
      await showAddPostsSheet(context, album: album);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = ref.watch(myAlbumsProvider);
    final order = ref.watch(albumOrderProvider);
    ref.listen(myAlbumsProvider, (_, next) {
      if (next.hasValue) {
        ref.read(albumOrderProvider.notifier).settle();
      }
    });
    final count = albums.value?.length ?? 0;
    final atLimit = count >= kMaxAlbums;
    final empty = albums.hasValue && count == 0;
    return ScreenCode(
      ScreenCodes.myAlbums,
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
                    onPressed: () => context.go('/profile'),
                  ),
            title: Text(l.myAlbumsTitle),
            actions: [
              IconButton(
                key: const Key('my-albums-add'),
                tooltip: atLimit ? l.albumPickLimit : l.albumPickNew,
                icon: const Icon(Icons.add_rounded),
                onPressed: albums.hasValue && !atLimit
                    ? () => _new(context)
                    : null,
              ),
            ],
          ),
          body: AsyncView<List<AlbumSummary>>(
            value: albums,
            onRetry: () => ref.invalidate(myAlbumsProvider),
            skeleton: (_) => const _Skeleton(),
            error: (context, _, _) => ErrorState(
              message: l.albumPickLoadError,
              onRetry: () => ref.invalidate(myAlbumsProvider),
            ),
            isEmpty: (list) => list.isEmpty,
            empty: (_) => EmptyState(
              title: l.myAlbumsEmptyTitle,
              body: l.myAlbumsEmptyBody,
              actionLabel: l.albumPickNew,
              onAction: () => _new(context),
            ),
            data: (context, list) {
              final shown = _ordered(list, order.pending);
              return _Body(
                albums: shown,
                saving: order.saving,
                onApply: (before, after) => _apply(context, ref, before, after),
                onDelete: (a) => _delete(context, ref, a),
                onOpenUnsorted: () => _openUnsorted(context, ref),
              );
            },
          ),
          bottomNavigationBar: empty || !albums.hasValue
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4,
                      AppSpace.s2,
                      AppSpace.s4,
                      AppSpace.s3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (atLimit)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.s2),
                            child: Text(
                              l.albumPickLimit,
                              key: const Key('my-albums-limit'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        AppButton.primary(
                          l.albumPickNew,
                          key: const Key('my-albums-new'),
                          onPressed: atLimit ? null : () => _new(context),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// [list] in the [pending] order while that is a rearrangement of it.
  List<AlbumSummary> _ordered(List<AlbumSummary> list, List<String>? pending) {
    if (pending == null || pending.length != list.length) {
      return list;
    }
    final byId = {for (final a in list) a.id: a};
    if (!pending.every(byId.containsKey)) {
      return list;
    }
    return [for (final id in pending) byId[id]!];
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      AppSkeleton.line(widthFactor: 0.8),
      const SizedBox(height: AppSpace.s3),
      for (var i = 0; i < 4; i++) ...[
        AppSkeleton.box(height: AppSpace.s12 + AppSpace.s4),
        const SizedBox(height: AppSpace.s2),
      ],
    ],
  );
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.albums,
    required this.saving,
    required this.onApply,
    required this.onDelete,
    required this.onOpenUnsorted,
  });

  final List<AlbumSummary> albums;
  final bool saving;
  final void Function(List<String> before, List<String> after) onApply;
  final void Function(AlbumSummary) onDelete;
  final VoidCallback onOpenUnsorted;

  static const double _saveDim = 0.7;
  static const double _emptyDim = 0.7;
  static const double _cover = 44;

  void _move(int from, int to) {
    if (to < 0 || to >= albums.length || to == from) {
      return;
    }
    final before = [for (final a in albums) a.id];
    onApply(before, _placed(before, from, to));
  }

  List<String> _placed(List<String> ids, int from, int to) {
    final next = List.of(ids);
    next.insert(to, next.removeAt(from));
    return next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final unsorted = ref.watch(myPostsProvider(MyPostsFilter.unsorted));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s1,
        AppSpace.s4,
        AppSpace.s4,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s3),
          child: Text(l.myAlbumsHint, style: theme.textTheme.bodySmall),
        ),
        Opacity(
          opacity: saving ? _saveDim : 1,
          child: ReorderableListView.builder(
            key: const Key('my-albums-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: albums.length,
            onReorderItem: _move,
            itemBuilder: (context, i) {
              final a = albums[i];
              final empty = a.postCount == 0;
              final counts = l.albumDetailCounts(a.postCount, a.mediaCount);
              final subtitle = empty
                  ? l.albumEmptyNote
                  : (i == 0 ? '$counts · ${l.myAlbumsFeatured}' : counts);
              return KeyedSubtree(
                key: ValueKey(a.id),
                child: Opacity(
                  opacity: empty ? _emptyDim : 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () =>
                        context.push('/u/${a.photographerId}/albums/${a.id}'),
                    child: ReorderableRow(
                      index: i,
                      count: albums.length,
                      title: a.title,
                      subtitle: subtitle,
                      leading: _Cover(url: a.coverUrl, size: _cover),
                      onMove: (to) async {
                        final before = [for (final x in albums) x.id];
                        final view = View.of(context);
                        final dir = Directionality.of(context);
                        final msg = l.reorderPosition(to + 1, albums.length);
                        onApply(before, _placed(before, i, to));
                        await SemanticsService.sendAnnouncement(view, msg, dir);
                      },
                      extraMenu: [
                        PopupMenuItem<VoidCallback>(
                          value: () => context.push(
                            '/u/${a.photographerId}/albums/${a.id}',
                          ),
                          child: Text(l.myAlbumsOpen),
                        ),
                        PopupMenuItem<VoidCallback>(
                          value: () => showEditAlbumSheet(context, album: a),
                          child: Text(l.myAlbumsEdit),
                        ),
                        PopupMenuItem<VoidCallback>(
                          value: () => onDelete(a),
                          child: Text(
                            l.albumDetailDelete,
                            style: const TextStyle(
                              color: AppColors.destructive,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        _UnsortedRow(
          countLabel: unsorted.value?.countLabel ?? '…',
          onTap: onOpenUnsorted,
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.size});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = url;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: u == null
            ? ColoredBox(color: scheme.secondary)
            : NetworkPhoto(url: u, retry: false),
      ),
    );
  }
}

/// The fixed last row: posts that are in no album. It cannot be dragged.
class _UnsortedRow extends StatelessWidget {
  const _UnsortedRow({required this.countLabel, required this.onTap});
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final border = dark ? AppColorsDark.border : AppColors.border;
    final radius = BorderRadius.circular(AppRadius.lg);
    return Semantics(
      button: true,
      label: '${l.myAlbumsUnsorted}, ${l.myAlbumsUnsortedSub(countLabel)}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: const Key('my-albums-unsorted'),
        borderRadius: radius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpace.s12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.myAlbumsUnsorted,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l.myAlbumsUnsortedSub(countLabel),
                          style: TextStyle(fontSize: AppText.xs2, color: muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
