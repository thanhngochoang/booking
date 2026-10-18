import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/dot_ring_loader.dart';
import 'package:photobooking/core/widgets/signature_loader.dart' show LoaderSize;
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/features/delivery/submit_delivery_controller.dart';

class SampleTile extends ConsumerWidget {
  const SampleTile({
    super.key,
    required this.tile,
    required this.onRetry,
    required this.onRemove,
  });

  final SampleTileState tile;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content;
    switch (tile.phase) {
      case SampleTilePhase.uploading:
        content = Stack(
          fit: StackFit.expand,
          children: [
            _LocalThumbnail(path: tile.local.path),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
            const Center(
              child: DotRingLoader(
                size: LoaderSize.inline,
                color: Colors.white,
              ),
            ),
          ],
        );
      case SampleTilePhase.processing:
        content = Stack(
          fit: StackFit.expand,
          children: [
            _LocalThumbnail(path: tile.local.path),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
            const Center(
              child: DotRingLoader(
                size: LoaderSize.inline,
                color: Colors.white70,
              ),
            ),
          ],
        );
      case SampleTilePhase.ready:
        final thumbPath = tile.thumbPath;
        if (thumbPath != null && thumbPath.isNotEmpty) {
          final url = ref.watch(deliveryImageUrlProvider(thumbPath)).value;
          if (url != null) {
            content = Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _LocalThumbnail(path: tile.local.path),
            );
          } else {
            content = _LocalThumbnail(path: tile.local.path);
          }
        } else {
          content = _LocalThumbnail(path: tile.local.path);
        }
      case SampleTilePhase.failed:
        content = Stack(
          fit: StackFit.expand,
          children: [
            _LocalThumbnail(path: tile.local.path),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.7),
              ),
            ),
            Center(
              child: IconButton(
                icon: const AppIcon(AppIcons.refresh, color: Colors.white),
                tooltip: 'Thử lại',
                onPressed: onRetry,
              ),
            ),
          ],
        );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            Positioned(
              top: 4,
              right: 4,
              child: Semantics(
                button: true,
                label: 'Bỏ ảnh này',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColorsDark.glass : Colors.black54,
                    ),
                    child: const AppIcon(
                      AppIcons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalThumbnail extends StatelessWidget {
  const _LocalThumbnail({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty || !File(path).existsSync()) {
      return const ColoredBox(
        color: Colors.grey,
        child: Center(
          child: AppIcon(AppIcons.image, color: Colors.white54),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.grey,
        child: Center(
          child: AppIcon(AppIcons.image, color: Colors.white54),
        ),
      ),
    );
  }
}
