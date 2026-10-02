import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Changes the signed-in user's avatar (S42, S24 step 1): pick one photo
/// from the gallery, upload it to `avatars/{uid}/{ulid}.jpg`, point
/// `users/{uid}` at it, then delete the previous upload. A cancelled pick
/// changes nothing. The value turns true after a change went through.
class AvatarController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> change() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (picked.isEmpty) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final path = 'avatars/$uid/${newUlid()}.jpg';
      UploadedMedia? media;
      await for (final e
          in ref
              .read(mediaUploaderProvider)
              .upload(picked.first, storagePath: path)) {
        if (e.isDone) {
          media = e.media;
        }
      }
      final done = media;
      if (done == null) {
        throw StateError('upload ended without a file');
      }
      final String? previous;
      try {
        previous = await ref
            .read(userRepositoryProvider)
            .setAvatar(uid, url: done.url, storagePath: path);
      } catch (_) {
        await _quietDelete(path); // nothing points at the new file
        rethrow;
      }
      if (previous != null && previous != path) {
        await _quietDelete(previous);
      }
      return true;
    });
  }

  /// A leftover file is harmless; a failed clean-up must not fail the change.
  Future<void> _quietDelete(String path) async {
    try {
      await ref.read(mediaUploaderProvider).delete(path);
    } catch (_) {}
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider.autoDispose<AvatarController, bool>(
      AvatarController.new,
    );
