import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Disputes of the signed-in user (S18). Reads are direct (parties only, by
/// rule); opening goes through the `openDispute` callable, which throws
/// [DisputeError] with the server code.
abstract class DisputeRepository {
  /// `disputeEvidence/{uid}/{disputeId}/{fileId}.jpg`. [fileId] must be fresh
  /// for every upload (a new ULID): Storage refuses overwrites.
  String evidencePath(String disputeId, String fileId);

  /// Uploads one evidence photo as an `ImagePurpose.document` JPEG.
  Stream<UploadEvent> uploadEvidence(PickedImage image, String storagePath);

  /// Removes an uploaded photo (allowed only before the dispute exists). A
  /// missing object is fine.
  Future<void> deleteEvidence(String storagePath);

  /// Opens the dispute; resolves to its id.
  Future<String> open(DisputeDraft draft);

  /// The dispute, live; null when it does not exist or is not readable.
  Stream<Dispute?> watch(String disputeId);

  /// My disputes (either party), newest first, one `get`.
  Future<List<Dispute>> mine({int limit = 10});

  /// A download URL for an evidence path (checked by the Storage rule).
  Future<String> evidenceUrl(String storagePath);
}
