import 'package:photobooking/data/safety/safety.dart';

abstract class SafetyRepository {
  /// Live stream of `users/{uid}/private/blocks`.
  /// Emits an empty [BlockIndex] if signed out or document does not exist.
  Stream<BlockIndex> watchIndex();

  /// Fetches users blocked by the signed-in user, newest first.
  Future<List<BlockedUser>> blocked({int limit = 50});

  /// Blocks [userId]. [source] defaults to 'menu'.
  Future<void> block(String userId, {String source = 'menu'});

  /// Unblocks [userId].
  Future<void> unblock(String userId);

  /// Submits a safety report, optionally also blocking the target owner.
  Future<ReportResult> report(ReportDraft draft);
}
