// lib/core/widgets/album_tile.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// A portfolio album (mock `.alb`, S03.01, S24.02): a square cover with two
/// stacked edges above it (hinting at a pile of photos), the title on one or
/// two lines and the photo count.
///
/// [featured] spans the whole row at 16:7 and moves the count onto the cover
/// as a pill besides the caption. [dimmedNote] is the owner's view of an empty album: the tile is
/// drawn at 70% opacity and the note replaces the count.
class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.title,
    required this.photoCount,
    this.coverUrl,
    this.featured = false,
    this.dimmedNote,
    required VoidCallback this.onTap,
  }) : _skeleton = false;

  const AlbumTile.skeleton({super.key, this.featured = false})
    : title = '',
      photoCount = 0,
      coverUrl = null,
      dimmedNote = null,
      onTap = null,
      _skeleton = true;

  /// Key of the cover box, so tests and galleries can measure it.
  static const coverKey = ValueKey('album-tile-cover');

  static const double _featuredRatio = 16 / 7;
  static const double _dimmedOpacity = 0.7;
  static const double _edgeStep = AppSpace.s1;

  final String title;
  final int photoCount;
  final String? coverUrl;

  /// Full row, 16:7, count pill on the cover.
  final bool featured;

  /// Shown instead of the count, and the tile is dimmed.
  final String? dimmedNote;
  final VoidCallback? onTap;
  final bool _skeleton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final line = dark ? AppColorsDark.border : AppColors.border;
    final lineStrong = dark ? AppColorsDark.borderStrong : AppColors.borderStrong;
    final muted = dark ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted;
    final field = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final l = context.l10n;
    final ratio = featured ? _featuredRatio : 1.0;
    final countText = l.servicePhotos(photoCount);

    Widget edges(Widget cover) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (i, c) in [line, lineStrong].indexed)
            Positioned(
              top: -_edgeStep * (2 - i),
              left: _edgeStep * (2 - i),
              right: _edgeStep * (2 - i),
              height: _edgeStep * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          cover,
        ],
      ),
    );

    if (_skeleton) {
      return AppSkeleton.group(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            edges(
              LayoutBuilder(
                builder: (context, c) => SizedBox(
                  key: coverKey,
                  width: c.maxWidth,
                  height: c.maxWidth / ratio,
                  child: AppSkeleton.box(
                    height: c.maxWidth / ratio,
                    radius: AppRadius.lg,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(widthFactor: 0.7, height: AppText.base),
            const SizedBox(height: AppSpace.s1),
            AppSkeleton.line(widthFactor: 0.35, height: AppText.sm),
          ],
        ),
      );
    }

    final cover = AspectRatio(
      key: coverKey,
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverUrl == null
                ? ColoredBox(
                    color: field,
                    child: Icon(Icons.photo_library_outlined, color: muted),
                  )
                : NetworkPhoto(url: coverUrl!),
            if (featured && dimmedNote == null)
              Positioned(
                top: AppSpace.s2,
                right: AppSpace.s2,
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
                    child: Text(
                      countText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppText.xs,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final caption = dimmedNote ?? countText;
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        edges(cover),
        const SizedBox(height: AppSpace.s1 + 2),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: AppText.base2,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: AppText.xs2, color: muted),
          ),
      ],
    );

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '$title, ${dimmedNote ?? countText}',
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: dimmedNote == null
            ? tile
            : Opacity(opacity: _dimmedOpacity, child: tile),
      ),
    );
  }
}
