// lib/features/album/edit_album_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/features/album/add_posts_sheet.dart';
import 'package:photobooking/features/album/album_detail_controller.dart';
import 'package:photobooking/features/album/my_albums_controller.dart';

/// Limits of the form (plan C, Global Constraints).
const int kAlbumTitleMax = 40;
const int kAlbumDescriptionMax = 300;

/// What the sheet reports back before [showEditAlbumSheet] returns.
class _EditResult {
  const _EditResult(this.id, {this.created = false});
  final String? id;
  final bool created;
}

/// S24.03: create an album, or edit [album]. Returns the id of the album
/// created or edited, or null when closed without saving (or after the album
/// was deleted).
///
/// A new album opens the add-posts sheet (S24.04) right after it is created,
/// unless [addPostsAfterCreate] is false: the album picker (S24.05) passes
/// false so that it can return to the post being composed with the new album
/// selected.
Future<String?> showEditAlbumSheet(
  BuildContext context, {
  AlbumSummary? album,
  bool addPostsAfterCreate = true,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await showAppSheet<_EditResult>(
    context,
    // A drag would pop past PopScope: edits and a running save must survive.
    enableDrag: false,
    builder: (_) => ScreenCode(
      ScreenCodes.editAlbum,
      child: _EditAlbumBody(album: album, addPosts: addPostsAfterCreate),
    ),
  );
  final id = result?.id;
  if (id == null) {
    return null;
  }
  if (result!.created && addPostsAfterCreate && context.mounted) {
    final created = await container.read(albumRepositoryProvider).album(id);
    if (created != null && context.mounted) {
      await showAddPostsSheet(context, album: created);
    }
  }
  return id;
}

class _EditAlbumBody extends ConsumerStatefulWidget {
  const _EditAlbumBody({required this.album, required this.addPosts});
  final AlbumSummary? album;
  final bool addPosts;

  @override
  ConsumerState<_EditAlbumBody> createState() => _EditAlbumBodyState();
}

class _EditAlbumBodyState extends ConsumerState<_EditAlbumBody> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  bool _busy = false;
  bool _touched = false;
  String? _titleError;
  String? _formError;

  /// Null = cover unchanged.
  AlbumCoverChoice? _cover;

  AlbumSummary? get _album => widget.album;
  bool get _editing => _album != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: _album?.title ?? '');
    _desc = TextEditingController(text: _album?.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  String get _name => _title.text.trim();

  bool get _dirty =>
      _cover != null ||
      (_editing
          ? (_title.text != _album!.title || _desc.text != _album!.description)
          : (_title.text.isNotEmpty || _desc.text.isNotEmpty));

  bool get _canSave => _name.isNotEmpty && !_busy && (!_editing || _dirty);

  Future<void> _close() async {
    if (_busy) {
      return;
    }
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final l = context.l10n;
    final discard = await showConfirmSheet(
      context,
      title: l.albumEditDiscardTitle,
      body: l.albumEditDiscardBody,
      confirmLabel: l.albumEditDiscard,
      keepLabel: l.albumEditKeep,
    );
    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    final l = context.l10n;
    final repo = ref.read(albumRepositoryProvider);
    setState(() {
      _busy = true;
      _titleError = null;
      _formError = null;
    });
    try {
      final a = _album;
      if (a == null) {
        final id = await repo.create(title: _name, description: _desc.text);
        if (mounted) {
          Navigator.of(context).pop(_EditResult(id, created: true));
        }
        return;
      }
      await repo.update(
        a.id,
        title: _name == a.title ? null : _name,
        description: _desc.text == a.description ? null : _desc.text,
        cover: _cover,
      );
      if (mounted) {
        ref.invalidate(albumProvider(a.id));
        ref.invalidate(albumPostsProvider(a.id));
        Navigator.of(context).pop(_EditResult(a.id));
      }
    } on AlbumError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        switch (e.code) {
          case 'conflict':
            _titleError = l.albumPickDup;
          case 'limit_exceeded':
            _formError = l.albumPickLimit;
          default:
            _formError = _editing
                ? l.albumEditSaveError
                : l.albumPickCreateError;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _formError = _editing ? l.albumEditSaveError : l.albumPickCreateError;
        });
      }
    }
  }

  Future<void> _delete() async {
    final a = _album;
    if (a == null || _busy) {
      return;
    }
    final l = context.l10n;
    final repo = ref.read(albumRepositoryProvider);
    final deleted = await showConfirmSheet(
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
    if (deleted && mounted) {
      ref.invalidate(albumProvider(a.id));
      ref.invalidate(myPostsProvider(MyPostsFilter.unsorted));
      Navigator.of(context).pop(const _EditResult(null));
    }
  }

  Future<void> _pickCover() async {
    final a = _album;
    if (a == null) {
      return;
    }
    final pick = await showAppSheet<AlbumCoverChoice>(
      context,
      builder: (_) => _CoverPickerBody(
        albumId: a.id,
        current: switch (_cover) {
          AlbumCoverPick() => _cover,
          AlbumCoverAuto() => null,
          null =>
            a.coverPostId == null
                ? null
                : AlbumCoverPick(a.coverPostId!, a.coverImageIndex ?? 0),
        },
      ),
    );
    if (pick != null && mounted) {
      setState(() => _cover = pick);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final a = _album;
    final hasCover = _cover is AlbumCoverPick
        ? true
        : (_cover is AlbumCoverAuto ? false : a?.coverPostId != null);
    final createLabel = widget.addPosts ? l.albumEditCreate : l.albumPickCreate;
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      _editing ? l.albumEditTitle : l.albumEditNew,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('album-edit-close'),
                  tooltip: l.albumEditClose,
                  constraints: const BoxConstraints.tightFor(
                    width: AppSpace.s12,
                    height: AppSpace.s12,
                  ),
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _busy ? null : _close,
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpace.s2),
                    TextField(
                      key: const Key('album-edit-title'),
                      controller: _title,
                      enabled: !_busy,
                      autofocus: !_editing,
                      maxLength: kAlbumTitleMax,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {
                        _touched = true;
                        _titleError = null;
                        _formError = null;
                      }),
                      buildCounter: _counter(kAlbumTitleMax),
                      decoration: InputDecoration(
                        labelText: l.albumEditName,
                        errorText:
                            _titleError ??
                            (_touched && _name.isEmpty
                                ? l.albumEditNameRequired
                                : null),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    TextField(
                      key: const Key('album-edit-desc'),
                      controller: _desc,
                      enabled: !_busy,
                      maxLength: kAlbumDescriptionMax,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (_) => setState(() => _formError = null),
                      buildCounter: _counter(kAlbumDescriptionMax),
                      decoration: InputDecoration(labelText: l.albumEditDesc),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Semantics(
                      container: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.albumEditCover,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            hasCover
                                ? l.albumEditCoverChosen
                                : l.albumEditCoverAuto,
                            key: const Key('album-edit-cover-value'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    AppButton.outline(
                      l.albumEditCoverPick,
                      key: const Key('album-edit-cover-pick'),
                      onPressed: (a != null && a.postCount > 0 && !_busy)
                          ? _pickCover
                          : null,
                    ),
                    if (!_editing) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.albumEditNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                    if (_formError != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _formError!,
                          key: const Key('album-edit-error'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              _editing ? l.albumEditSave : createLabel,
              key: const Key('album-edit-save'),
              loading: _busy,
              onPressed: _canSave ? _save : null,
            ),
            if (_editing)
              TextButton(
                key: const Key('album-edit-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  minimumSize: const Size.fromHeight(AppSpace.s12),
                ),
                onPressed: _busy ? null : _delete,
                child: Text(l.albumDetailDelete),
              ),
          ],
        ),
      ),
    );
  }

  InputCounterWidgetBuilder _counter(int max) =>
      (context, {required currentLength, required isFocused, maxLength}) =>
          Text(
            context.l10n.albumEditNameCount(currentLength, max),
            style: Theme.of(context).textTheme.bodySmall,
          );
}

/// The grid of every image in the album, for choosing its cover.
class _CoverPickerBody extends ConsumerStatefulWidget {
  const _CoverPickerBody({required this.albumId, required this.current});
  final String albumId;
  final AlbumCoverChoice? current;

  @override
  ConsumerState<_CoverPickerBody> createState() => _CoverPickerBodyState();
}

class _CoverPickerBodyState extends ConsumerState<_CoverPickerBody> {
  @override
  void initState() {
    super.initState();
    Future(() async {
      final notifier = ref.read(albumPostsProvider(widget.albumId).notifier);
      await ref.read(albumPostsProvider(widget.albumId).future);
      if (mounted) {
        await notifier.loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final posts = ref.watch(albumPostsProvider(widget.albumId));
    final cur = widget.current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s3,
          ),
          child: Semantics(
            header: true,
            child: Text(
              l.albumEditCoverTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        Flexible(
          child: AsyncView<AlbumPostsState>(
            value: posts,
            onRetry: () => ref.invalidate(albumPostsProvider(widget.albumId)),
            skeleton: (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpace.s1),
                    Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 2)),
                  ],
                ],
              ),
            ),
            error: (context, _, _) => ErrorState(
              message: l.albumEditCoverLoadError,
              onRetry: () => ref.invalidate(albumPostsProvider(widget.albumId)),
            ),
            data: (context, state) {
              final tiles = <(String, int, String)>[
                for (final p in state.posts)
                  for (var i = 0; i < p.images.length; i++)
                    (p.id, i, p.images[i].url),
              ];
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpace.s1,
                  crossAxisSpacing: AppSpace.s1,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, n) {
                  final (postId, index, url) = tiles[n];
                  final selected =
                      cur is AlbumCoverPick &&
                      cur.postId == postId &&
                      cur.imageIndex == index;
                  return _CoverTile(
                    key: Key('cover-$postId-$index'),
                    url: url,
                    selected: selected,
                    label: l.albumEditCoverTile(n + 1, tiles.length),
                    onTap: () =>
                        Navigator.of(context)
                            .pop(AlbumCoverPick(postId, index)),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: AppButton.outline(
            l.albumEditCoverReset,
            key: const Key('cover-auto'),
            onPressed: () => Navigator.of(context).pop(const AlbumCoverAuto()),
          ),
        ),
      ],
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    super.key,
    required this.url,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final String url;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: selected
                ? Border.all(color: scheme.primary, width: 3)
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: NetworkPhoto(url: url, retry: false),
          ),
        ),
      ),
    );
  }
}
