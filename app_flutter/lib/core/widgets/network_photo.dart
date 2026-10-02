import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';

/// Builds the actual image widget. [cacheWidth] is the decode width in pixels
/// (always set; [NetworkPhoto] falls back to the screen width); [retry] says whether a failed load may show a retry
/// button.
typedef PhotoImageBuilder = Widget Function(
  BuildContext context,
  String url,
  BoxFit fit,
  int? cacheWidth,
  bool retry,
);

/// Lets tests (and previews) replace how photos are loaded. Without a scope,
/// photos come from [cachedPhotoBuilder].
class PhotoImageScope extends InheritedWidget {
  const PhotoImageScope({
    super.key,
    required this.builder,
    required super.child,
  });

  final PhotoImageBuilder builder;

  static PhotoImageBuilder of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoImageScope>()?.builder ??
      cachedPhotoBuilder;

  @override
  bool updateShouldNotify(PhotoImageScope old) => builder != old.builder;
}

/// A network photo, decoded at the size it is shown (never the original) and
/// cached on disk.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.retry = true,
  });

  final String url;
  final BoxFit fit;
  final String? semanticLabel;
  final bool retry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = _decodeWidth(context, constraints.maxWidth);
        final image = PhotoImageScope.of(context)(
          context,
          url,
          fit,
          cacheWidth,
          retry,
        );
        // The image itself is silent; a failed load's retry control (built by
        // the production builder) stays reachable by screen readers.
        return semanticLabel == null
            ? image
            : Semantics(
                image: true,
                label: semanticLabel,
                container: true,
                child: image,
              );
      },
    );
  }
}

/// Decode width in px, rounded up to 50. Never null, so the original size is
/// never decoded: an unbounded or zero layout width falls back to the screen
/// width, and that to a fixed 1080.
int _decodeWidth(BuildContext context, double layoutWidth) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  int round(double dp) => ((dp * ratio) / 50).ceil() * 50;
  if (layoutWidth.isFinite && layoutWidth > 0) {
    return round(layoutWidth);
  }
  final screen = MediaQuery.sizeOf(context).width;
  if (screen.isFinite && screen > 0) {
    return round(screen);
  }
  return 1080;
}

/// Production image: disk cache, decode at [cacheWidth], flat placeholder, and
/// an error tile that can retry. No automatic retry loop (that would burn
/// battery on a dead link).
Widget cachedPhotoBuilder(
  BuildContext context,
  String url,
  BoxFit fit,
  int? cacheWidth,
  bool retry,
) => _CachedPhoto(url: url, fit: fit, cacheWidth: cacheWidth, retry: retry);

class _CachedPhoto extends StatefulWidget {
  const _CachedPhoto({
    required this.url,
    required this.fit,
    required this.cacheWidth,
    required this.retry,
  });

  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final bool retry;

  @override
  State<_CachedPhoto> createState() => _CachedPhotoState();
}

class _CachedPhotoState extends State<_CachedPhoto> {
  int _attempt = 0;

  Future<void> _reload() async {
    try {
      await CachedNetworkImage.evictFromCache(widget.url);
    } on Object {
      // A cache that cannot be cleared must not block the reload.
    }
    if (mounted) {
      setState(() => _attempt++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.secondary;
    return CachedNetworkImage(
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      // A retry gets a fresh cache key, so the failed (resized) entry is not
      // reused; the original is evicted in _reload as well.
      cacheKey: _attempt > 0 ? '${widget.url}#$_attempt' : null,
      fit: widget.fit,
      memCacheWidth: widget.cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) =>
          widget.retry ? ColoredBox(color: fill) : const SizedBox.shrink(),
      errorWidget: (context, _, _) => widget.retry
          ? PhotoRetryTile(fill: fill, onRetry: _reload)
          : const SizedBox.shrink(),
    );
  }
}

/// The failed-load tile: the whole tile is the tap target (so it works in
/// boxes under 48 dp) and one "Thử lại" button node for screen readers.
@visibleForTesting
class PhotoRetryTile extends StatelessWidget {
  const PhotoRetryTile({super.key, required this.fill, required this.onRetry});

  final Color fill;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.retry,
      onTap: onRetry,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: ExcludeSemantics(
          child: ColoredBox(
            color: fill,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(4),
                child: FittedBox(child: Icon(Icons.refresh_rounded, size: 24)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
