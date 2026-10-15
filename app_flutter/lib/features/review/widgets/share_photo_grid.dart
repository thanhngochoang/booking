import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/review/review_controller.dart';

class SharePhotoGrid extends StatelessWidget {
  const SharePhotoGrid({
    super.key,
    required this.photos,
    required this.photographerName,
    this.onAdd,
    this.onRemove,
    this.onRetry,
    this.enabled = true,
  });

  final List<SharedPhotoTile> photos;
  final String photographerName;
  final VoidCallback? onAdd;
  final ValueChanged<String>? onRemove;
  final ValueChanged<String>? onRetry;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canAdd = enabled && photos.length < 10 && onAdd != null;
    final itemCount = photos.length + (canAdd ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.reviewShareHint(photographerName),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.dark
                ? AppColorsDark.foregroundMuted
                : AppColors.foregroundMuted,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        if (itemCount > 0)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpace.s2,
              crossAxisSpacing: AppSpace.s2,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == photos.length) {
                return _AddPhotoTile(
                  key: const Key('add_photo_tile'),
                  onTap: enabled ? onAdd : null,
                );
              }
              final tile = photos[index];
              return _PhotoTile(
                key: Key('photo_tile_$index'),
                index: index,
                tile: tile,
                enabled: enabled,
                onRemove: () => onRemove?.call(tile.key),
                onRetry: () => onRetry?.call(tile.key),
              );
            },
          ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final radius = BorderRadius.circular(AppRadius.control);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: context.l10n.reviewShare,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(child: AppIcon(AppIcons.add, color: muted, size: 32)),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.index,
    required this.tile,
    required this.enabled,
    required this.onRemove,
    required this.onRetry,
  });

  final int index;
  final SharedPhotoTile tile;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final radius = BorderRadius.circular(AppRadius.control);

    const ink = AppColors.foregroundInverse;
    final scrim = IconButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size.square(AppSpace.s12),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image preview
          Image.file(
            File(tile.local.path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
          ),

          // Uploading overlay
          if (tile.status == SharedPhotoStatus.uploading) ...[
            const ColoredBox(color: AppColors.overlay),
            Center(
              child: Semantics(
                label: l10n.reviewPhotoUploading(
                  index + 1,
                  (tile.progress.clamp(0.0, 1.0) * 100).round(),
                ),
                child: UploadProgressRing(fraction: tile.progress, size: 32),
              ),
            ),
          ],

          // Failed overlay
          if (tile.status == SharedPhotoStatus.failed) ...[
            const ColoredBox(color: AppColors.overlay),
            Center(
              child: IconButton(
                key: Key('retry_photo_$index'),
                icon: const AppIcon(AppIcons.refresh, color: ink, size: 28),
                tooltip: l10n.reviewUploadFailed,
                onPressed: enabled ? onRetry : null,
              ),
            ),
          ],

          // Done indicator
          if (tile.status == SharedPhotoStatus.done)
            const Positioned(
              bottom: AppSpace.s1,
              left: AppSpace.s1,
              child: AppIcon(
                AppIcons.checkCircle,
                color: AppColors.success,
                size: 18,
              ),
            ),

          // Remove button (top right)
          if (enabled)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                key: Key('remove_photo_$index'),
                icon: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.overlay,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpace.s1),
                    child: AppIcon(AppIcons.close, size: 18),
                  ),
                ),
                tooltip: l10n.createRemove,
                style: scrim,
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}
