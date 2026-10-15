// lib/features/create_post/album_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/features/album/edit_album_sheet.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';

/// What the album picker returns: "Không xếp album" or one album.
@immutable
class AlbumPick {
  const AlbumPick.none() : albumId = null;
  const AlbumPick.album(String id) : albumId = id;

  /// Null for [AlbumPick.none].
  final String? albumId;
}

/// S24.05: choose the album a new post is filed in. Choosing closes the sheet;
/// null means it was dismissed. [selected] marks the current choice (null =
/// "Không xếp album"). [allowNone] false hides that choice, for callers that
/// need an album (S24.02 filing unsorted posts).
Future<AlbumPick?> showAlbumPicker(
  BuildContext context, {
  String? selected,
  bool allowNone = true,
}) {
  return showAppSheet<AlbumPick>(
    context,
    builder: (sheet) => ScreenCode(
      ScreenCodes.pickAlbum,
      child: _AlbumPickerBody(selected: selected, allowNone: allowNone),
    ),
  );
}

class _AlbumPickerBody extends ConsumerWidget {
  const _AlbumPickerBody({required this.selected, required this.allowNone});
  final String? selected;
  final bool allowNone;

  static const double _thumb = 40;

  Future<void> _newAlbum(BuildContext context, WidgetRef ref) async {
    // S24.03 returns here with the new album chosen, not on to S24.04.
    final id = await showEditAlbumSheet(context, addPostsAfterCreate: false);
    if (id != null && context.mounted) {
      Navigator.of(context).pop(AlbumPick.album(id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = ref.watch(myAlbumsProvider);
    final recent = ref.watch(lastAlbumProvider);
    final theme = Theme.of(context);
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
            child: Text(l.albumPickTitle, style: theme.textTheme.titleLarge),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              0,
              AppSpace.s4,
              AppSpace.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (allowNone)
                  AppOptionTile(
                    key: const Key('album-pick-none'),
                    label: l.albumPickNone,
                    description: l.albumPickNoneSub,
                    selected: selected == null,
                    onTap: () =>
                        Navigator.of(context).pop(const AlbumPick.none()),
                  ),
                AsyncView<List<AlbumSummary>>(
                  value: albums,
                  onRetry: () => ref.invalidate(myAlbumsProvider),
                  skeleton: (_) => Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s2),
                    child: Column(
                      children: [
                        for (var i = 0; i < 2; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpace.s2),
                          AppOptionTile.skeleton(withThumb: true),
                        ],
                      ],
                    ),
                  ),
                  error: (context, _, _) => ErrorState(
                    message: l.albumPickLoadError,
                    onRetry: () => ref.invalidate(myAlbumsProvider),
                  ),
                  data: (context, list) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in list) ...[
                        const SizedBox(height: AppSpace.s2),
                        AppOptionTile(
                          key: Key('album-pick-${a.id}'),
                          label: a.title,
                          description: a.id == recent
                              ? '${l.albumPickCount(a.postCount)} · '
                                    '${l.albumPickRecent}'
                              : l.albumPickCount(a.postCount),
                          selected: a.id == selected,
                          leading: _Cover(url: a.coverUrl, size: _thumb),
                          onTap: () =>
                              Navigator.of(context).pop(AlbumPick.album(a.id)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
                AppButton.outline(
                  l.albumPickNew,
                  key: const Key('album-pick-new'),
                  onPressed: () => _newAlbum(context, ref),
                ),
              ],
            ),
          ),
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
