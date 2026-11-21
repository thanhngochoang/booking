import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/media/firebase_media_uploader.dart';
import 'package:photobooking/data/media/http_media_uploader.dart';
import 'package:photobooking/data/media/http_media_url_resolver.dart';
import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/media/native_image_compressor.dart';
import 'package:photobooking/data/media/plugin_image_picker.dart';

final imagePickerProvider = Provider<ImagePickerPort>(
  (ref) => PluginImagePicker(),
);

final imageCompressorProvider = Provider<ImageCompressor>(
  (ref) => NativeImageCompressor(),
);

final mediaUploaderProvider = Provider<MediaUploader>((ref) {
  final config = ref.watch(backendConfigProvider);
  if (config.uses(SelfhostedRepo.platform)) {
    return HttpMediaUploader(
      api: ref.watch(apiClientProvider),
      compressor: ref.watch(imageCompressorProvider),
    );
  }
  return FirebaseMediaUploader(compressor: ref.watch(imageCompressorProvider));
});

final mediaUrlResolverProvider = Provider<MediaUrlResolver>((ref) {
  final config = ref.watch(backendConfigProvider);
  if (config.uses(SelfhostedRepo.platform)) {
    return HttpMediaUrlResolver(
      api: ref.watch(apiClientProvider),
    );
  }
  return FirebaseMediaUrlResolver();
});
