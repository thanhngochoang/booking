import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';

/// Builds the actual image widget. [cacheWidth] is the decode width in pixels
/// (null when unknown); [retry] says whether a failed load may show a retry
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
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final width = constraints.maxWidth;
        final cacheWidth = (width.isFinite && width > 0)
            ? ((width * ratio) / 50).ceil() * 50
            : null;
        final image = PhotoImageScope.of(context)(
          context,
          url,
          fit,
          cacheWidth,
          retry,
        );
        return semanticLabel == null
            ? ExcludeSemantics(child: image)
            : Semantics(
                image: true,
                label: semanticLabel,
                child: ExcludeSemantics(child: image),
              );
      },
    );
  }
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
    await CachedNetworkImage.evictFromCache(widget.url);
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
      fit: widget.fit,
      memCacheWidth: widget.cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) =>
          widget.retry ? ColoredBox(color: fill) : const SizedBox.shrink(),
      errorWidget: (context, _, _) => widget.retry
          ? ColoredBox(
              color: fill,
              child: Center(
                child: IconButton(
                  tooltip: context.l10n.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _reload,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
