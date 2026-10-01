// lib/core/widgets/photo_card.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// A photo with optional text on a bottom gradient (S01, S13, S21, S03). No
/// border, no shadow, and no blur: a feed of these must stay cheap.
class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.imageUrl,
    this.blurHash,
    required this.aspect,
    this.title,
    this.subtitle,
    this.leadingPill,
    this.trailingPill,
    this.action,
    this.onTap,
    this.semanticLabel,
  });

  /// The photo is shown with `retry: false`: tapping the card opens the
  /// detail, which retries, and pull-to-refresh reloads the feed.
  final String imageUrl;

  /// Kept for the blurhash placeholder (a later enhancement); the fill under
  /// the photo today is the flat theme colour.
  final String? blurHash;

  /// Width divided by height: 4/5 for the large card, 3/4 for small ones.
  final double aspect;
  final String? title;
  final String? subtitle;
  final Widget? leadingPill;
  final Widget? trailingPill;

  /// Shown at the right of the text row, for example a save button. It gets a
  /// 48dp minimum slot and its own semantics node; narrow cards (under 200dp
  /// wide) should not pass one, as it crowds the text.
  final Widget? action;
  final VoidCallback? onTap;

  /// The card label for screen readers. Without it the card reads its text
  /// and pill labels; pass one for cards that show no text.
  final String? semanticLabel;

  static const _radius = AppRadius.lg + 8;

  @override
  Widget build(BuildContext context) {
    final hasText = title != null || subtitle != null;
    // One node reads the whole card: text, then the labels of PhotoPill pills.
    final label =
        semanticLabel ??
        [
          title,
          subtitle,
          if (leadingPill case PhotoPill(:final label)) label,
          if (trailingPill case PhotoPill(:final label)) label,
        ].whereType<String>().join(', ');
    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      image: true,
      label: label.isEmpty ? null : label,
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final small = constraints.maxWidth < 200;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Flat fill under the photo: shown while it loads and after a
                  // failure (retry: false draws nothing of its own).
                  ColoredBox(
                    key: const ValueKey('photo-card-fill'),
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  NetworkPhoto(url: imageUrl, retry: false),
                  if (hasText)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const Key('photo-card-scrim'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              // Clear above 40% height, 0.6 alpha by 75%, 0.8
                              // at the bottom: 2+2 lines at 1.3x stay readable.
                              colors: [
                                Colors.black.withValues(alpha: 0),
                                Colors.black.withValues(alpha: 0),
                                Colors.black.withValues(alpha: 0.6),
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0, 0.4, 0.75, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // The tap layer sits under the labels and the action, so an
                  // action button receives its own taps and the rest of the
                  // card opens it.
                  if (onTap != null)
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onTap,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  if (leadingPill != null)
                    Positioned(
                      left: AppSpace.s2,
                      top: AppSpace.s2,
                      child: ExcludeSemantics(
                        child: IgnorePointer(child: leadingPill!),
                      ),
                    ),
                  if (trailingPill != null)
                    Positioned(
                      right: AppSpace.s2,
                      top: AppSpace.s2,
                      child: ExcludeSemantics(
                        child: IgnorePointer(child: trailingPill!),
                      ),
                    ),
                  if (hasText || action != null)
                    Positioned(
                      left: AppSpace.s3,
                      right: AppSpace.s3,
                      bottom: AppSpace.s3,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: ExcludeSemantics(
                              child: IgnorePointer(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (title != null)
                                      Text(
                                        title!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: small
                                              ? AppText.sm
                                              : AppText.base,
                                        ),
                                      ),
                                    if (subtitle != null)
                                      Text(
                                        subtitle!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          fontSize: small ? 10.5 : AppText.sm,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (action != null)
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: Center(child: action),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A small dark pill over a photo: availability ("Rảnh T7 này"), package and
/// price. White text on a 55% black fill keeps 4.5:1 on any photo.
class PhotoPill extends StatelessWidget {
  const PhotoPill({super.key, required this.label, this.dot = false});

  final String label;

  /// A green dot before the label, meaning "free".
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
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
            if (dot) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 6),
              ),
              const SizedBox(width: AppSpace.s1),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
