import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import 'fake_dispute_repository.dart';

/// "Now" of the dispute fixtures (UTC).
final disputeNow = DateTime.utc(2026, 10, 20, 8);

/// A dispute as the server writes it: booking `b1` of customer `c1` against
/// photographer `p1`, open, opened an hour before [disputeNow].
Dispute fixtureDispute(
  String id, {
  DisputeSubjectType subjectType = DisputeSubjectType.booking,
  String subjectId = 'b1',
  String? eventId,
  String customerId = 'c1',
  String providerId = 'p1',
  DisputeReason reason = DisputeReason.photosMissing,
  String description = 'Thiếu 20 ảnh so với gói đã chọn',
  List<String> evidencePaths = const [],
  String title = 'Minh Trí · Chân dung',
  String subtitle = 'T2 19/10 · 15:30–17:30',
  String? providerName = 'Minh Trí',
  String? thumbUrl,
  int amountHeld = 1500000,
  DisputeStatus status = DisputeStatus.open,
  DisputeOutcome? outcome,
  DateTime? createdAt,
  DateTime? resolvedAt,
}) => Dispute(
  id: id,
  subjectType: subjectType,
  subjectId: subjectId,
  eventId: eventId,
  customerId: customerId,
  providerId: providerId,
  reason: reason,
  description: description,
  evidencePaths: evidencePaths,
  title: title,
  subtitle: subtitle,
  providerName: providerName,
  thumbUrl: thumbUrl,
  amountHeld: amountHeld,
  status: status,
  outcome: outcome,
  threadId: 'dispute_$id',
  createdAt: createdAt ?? disputeNow.subtract(const Duration(hours: 1)),
  resolvedAt: resolvedAt,
);

/// The signed-in [uid] with an in-memory dispute repository (its uploader is
/// [uploader]), a queued image picker and the clock at [now].
class DisputeWorld {
  DisputeWorld({
    this.uid = 'c1',
    Iterable<Dispute> disputes = const [],
    List<List<PickedImage>> picks = const [],
    DateTime? now,
  }) : now = now ?? disputeNow,
       picker = FakeImagePicker(picks) {
    repo = FakeDisputeRepository(
      uid: uid,
      uploader: uploader,
      disputes: disputes,
      clock: () => this.now,
    );
  }

  final String uid;
  DateTime now;
  final uploader = FakeMediaUploader();
  final FakeImagePicker picker;
  late final FakeDisputeRepository repo;

  List<Override> get overrides => [
    disputeRepositoryProvider.overrideWithValue(repo),
    imagePickerProvider.overrideWithValue(picker),
    clockProvider.overrideWithValue(() => now),
  ];
}
