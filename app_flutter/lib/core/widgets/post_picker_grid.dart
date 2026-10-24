// lib/core/widgets/post_picker_grid.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// One post in [PostPickerGrid].
@immutable
class PostPickItem {
  const PostPickItem({
    required this.postId,
    required this.thumbUrl,
    this.imageCount = 1,
    this.albumTitle,
    this.label,
  });

  final String postId;
  final String thumbUrl;

  /// More than one shows a "{n} ảnh" label in the corner.
  final int imageCount;

  /// The album the post is in now, shown in the corner instead of the count.
  final String? albumTitle;

  /// Spoken name of the tile, e.g. the first line of the caption. Without it
  /// (and without an album or count) the tile is read by its position.
  final String? label;
}

/// Multi-select grid of posts, three columns (mock `.ck`, S24.03). Selected
/// tiles show their number in selection order. At [maxSelected] the other
/// tiles are disabled; selected ones can still be deselected.
class PostPickerGrid extends StatelessWidget {
  const PostPickerGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.onToggle,
    this.maxSelected,
    this.crossAxisCount = columns,
  });

  final List<PostPickItem> items;

  /// Post ids; the order is the selection order.
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final int? maxSelected;

  /// Tiles per row; S27.03 shows five small ones.
  final int crossAxisCount;

  static const int columns = 3;

  @override
  Widget build(BuildContext context) {
    final full = maxSelected != null && selected.length >= maxSelected!;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpace.s1,
        crossAxisSpacing: AppSpace.s1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final order = selected.indexOf(item.postId);
        return _PickTile(
          key: ValueKey('post-pick-${item.postId}'),
          item: item,
          position: i + 1,
          total: items.length,
          order: order < 0 ? null : order + 1,
          disabled: full && order < 0,
          onTap: () => onToggle(item.postId),
        );
      },
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.item,
    required this.position,
    required this.total,
    required this.order,
    required this.disabled,
    required this.onTap,
  });

  final PostPickItem item;
  final int position;
  final int total;
  final int? order;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final corner =
        item.albumTitle ??
        (item.imageCount > 1 ? l.servicePhotos(item.imageCount) : null);
    final selected = order != null;
    final named = item.label != null && item.label!.isNotEmpty;
    final hasDetail = named || item.albumTitle != null || item.imageCount > 1;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      excludeSemantics: true,
      label: [
        if (named) item.label!,
        if (!hasDetail) l.postPickPosition(position, total),
        if (item.albumTitle != null) l.postPickInAlbum(item.albumTitle!),
        if (item.albumTitle == null && item.imageCount > 1)
          l.servicePhotos(item.imageCount),
        if (selected) l.postPickSelectedOrder(order!),
      ].join(', '),
      onTap: disabled ? null : onTap,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkPhoto(url: item.thumbUrl, retry: false),
                if (corner != null)
                  Positioned(
                    left: AppSpace.s1,
                    right: AppSpace.s1,
                    bottom: AppSpace.s1,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.overlay,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: 2,
                          ),
                          child: Text(
                            corner,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppText.xs,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: AppSpace.s1,
                  right: AppSpace.s1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? scheme.primary : AppColors.overlayLight,
                      border: Border.all(
                        color: selected ? scheme.primary : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: AppSpace.s6 - 2,
                      child: Center(
                        child: selected
                            ? Text(
                                '$order',
                                style: TextStyle(
                                  fontSize: AppText.xs2,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : null,
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
