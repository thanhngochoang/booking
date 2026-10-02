import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/media/firebase_media_uploader.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/media/plugin_image_picker.dart';

final imagePickerProvider = Provider<ImagePickerPort>(
  (ref) => PluginImagePicker(),
);

final mediaUploaderProvider = Provider<MediaUploader>(
  (ref) => FirebaseMediaUploader(),
);
