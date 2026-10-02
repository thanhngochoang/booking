import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';

class PhotoRequest {
  const PhotoRequest(this.url, this.fit, this.cacheWidth, this.retry);
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final bool retry;
}

/// Hosts photos as flat grey boxes, so widget tests need no network and no
/// image plugin. Every request is appended to [log] when given.
Widget testPhotoScope({required Widget child, List<PhotoRequest>? log}) {
  return PhotoImageScope(
    builder: (context, url, fit, cacheWidth, retry) {
      log?.add(PhotoRequest(url, fit, cacheWidth, retry));
      return ColoredBox(
        key: ValueKey('photo:$url'),
        color: const Color(0xFF888888),
      );
    },
    child: child,
  );
}
