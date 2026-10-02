import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Changes the signed-in user's avatar (S09.03, S08.01 step 1): pick one photo
/// from the gallery, upload it to `avatars/{uid}/{ulid}.jpg`, point
/// `users/{uid}` at it, then delete the previous upload. A cancelled pick
/// changes nothing. The value turns true after a change went through.
class AvatarController extends AsyncNotifier<bool> {
  bool _busy = false;

  @override
  bool build() => false;

  Future<void> change() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return;
    }
    // Leaving S09.03 (Lưu, Back) must not drop the change halfway.
    final link = ref.keepAlive();
    try {
      await _change(uid);
    } finally {
      link.close();
    }
  }

  Future<void> _change(String uid) async {
    if (_busy) {
      return; // a second tap while the picker or upload is open
    }
    _busy = true;
    try {
      await _pickAndUpload(uid);
    } finally {
      _busy = false;
    }
  }

  Future<void> _pickAndUpload(String uid) async {
    final List<PickedImage> picked;
    try {
      picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    } catch (e, st) {
      if (ref.mounted) {
        state = AsyncError(e, st);
      }
      return;
    }
    if (picked.isEmpty) {
      return; // cancelled: nothing changes
    }
    if (!ref.mounted) {
      return;
    }
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
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
    if (ref.mounted) {
      state = next;
    }
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
