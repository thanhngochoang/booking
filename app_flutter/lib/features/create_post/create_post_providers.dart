// lib/features/create_post/create_post_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/firestore_post_publisher.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/service_summary.dart';
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

final postPublisherProvider = Provider<PostPublisher>(
  (ref) => FirestorePostPublisher(),
);

/// The signed-in photographer's active packages, for the package field.
final myServicesProvider = FutureProvider.autoDispose<List<ServiceSummary>>((
  ref,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return const [];
  }
  return ref.watch(serviceRepositoryProvider).activeFor(uid);
});
