/// What an uploaded photo is for. The call site picks one; it decides the
/// longest side, JPEG quality, size ceiling and cache header of the upload.
///
/// [maxBytes] is also the limit the Storage rules enforce for the paths of that
/// purpose (`jpegUpTo(...)` in `firebase/storage.rules`).
enum ImagePurpose {
  avatar(
    'avatar',
    longSide: 512,
    quality: 80,
    maxBytes: 512 * 1024,
    publicCache: true,
  ),
  chat(
    'chat',
    longSide: 1280,
    quality: 75,
    maxBytes: 1536 * 1024,
    publicCache: false,
  ),
  share(
    'share',
    longSide: 1600,
    quality: 80,
    maxBytes: 2 * 1024 * 1024,
    publicCache: true,
  ),
  deliverySample(
    'delivery_sample',
    longSide: 1600,
    quality: 75,
    maxBytes: 2 * 1024 * 1024,
    publicCache: false,
  ),
  portfolio(
    'portfolio',
    longSide: 2048,
    quality: 82,
    maxBytes: 3 * 1024 * 1024,
    publicCache: true,
  ),
  document(
    'document',
    longSide: 2048,
    quality: 85,
    maxBytes: 3 * 1024 * 1024,
    publicCache: false,
  );

  const ImagePurpose(
    this.code, {
    required this.longSide,
    required this.quality,
    required this.maxBytes,
    required this.publicCache,
  });

  /// Stored as `customMetadata.purpose` on the object.
  final String code;

  /// Longest side in pixels; smaller photos are never upscaled.
  final int longSide;

  /// JPEG quality of the first encode (the fit loop may lower it).
  final int quality;

  /// Largest file the app will upload for this purpose.
  final int maxBytes;

  /// `public` for images anyone may see, `private` for chat, samples and
  /// documents (kept out of shared caches).
  final bool publicCache;

  /// File names are never reused for other content, so a year is safe.
  String get cacheControl =>
      '${publicCache ? 'public' : 'private'}, max-age=31536000';
}
