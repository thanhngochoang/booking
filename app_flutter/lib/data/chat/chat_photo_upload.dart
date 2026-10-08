import 'package:firebase_core/firebase_core.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Uploads a chat photo (1-1 or event group) to [storagePath] with
/// [ImagePurpose.chat] and waits for it to finish. A failure is a
/// [ChatException]: Storage `unauthorized` → `permissionDenied`, any other
/// Firebase error → `network`, anything else (e.g. the compressor) → `unknown`.
Future<void> uploadChatPhoto(
  MediaUploader uploader,
  PickedImage image,
  String storagePath,
) async {
  try {
    await uploader
        .upload(image, storagePath: storagePath, purpose: ImagePurpose.chat)
        .lastWhere((event) => event.isDone);
  } on FirebaseException catch (e) {
    throw ChatException(
      e.code == 'unauthorized'
          ? ChatErrorCode.permissionDenied
          : ChatErrorCode.network,
      e.code,
    );
  } catch (e) {
    throw ChatException(ChatErrorCode.unknown, e.toString());
  }
}
