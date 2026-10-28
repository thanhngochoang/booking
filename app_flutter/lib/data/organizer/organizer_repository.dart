// lib/data/organizer/organizer_repository.dart
import 'dart:io' show SocketException;

import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/organizer/organizer.dart';

/// A refused or failed organizer call. [code] is the domain code the callable
/// sent in `details.code`: `phone_required`, `conflict` (suspended),
/// `spot_managed`, `spot_archived`, `limit_exceeded`, `not_spot_manager`,
/// `not_accepting_orders`, `not_found`, `deadline_passed`,
/// `permission_denied`, `invalid_argument`, or `network` / `unknown`.
class OrganizerError implements Exception {
  const OrganizerError(this.code, {this.field});

  final String code;

  /// The refused input (`details.field`, e.g. `name`, `proofPaths`).
  final String? field;

  @override
  String toString() =>
      'OrganizerError($code${field == null ? '' : ', $field'})';
}

/// The error code of anything an organizer call threw, for screens.
String organizerErrorCodeOf(Object error) => switch (error) {
  OrganizerError(:final code) => code,
  SocketException() => 'network',
  _ => 'unknown',
};

/// S30 organizer reads and writes (S30.01–S30.04, S30.06, S12.03-entry).
/// Every write is a callable; spot residents and the entry event on sale are
/// read through `SpotRepository` (they belong to the spot, S29.02 reads them
/// too).
abstract class OrganizerRepository {
  /// My `organizers/{uid}`; null when I am not an organizer (or signed out).
  Stream<Organizer?> watchMine();

  /// Anyone's organizer profile ("Bán bởi {org}", the invitee's sheet).
  Stream<Organizer?> watch(String uid);

  /// S30.01 "Gửi yêu cầu": uploads [avatar] to `avatars/{uid}/` first.
  Future<Organizer?> becomeOrganizer({
    required String name,
    required String bio,
    PickedImage? avatar,
  });

  /// S30.02: uploads [proofs] (1–3 photos) to `spot_claims/{uid}/{folder}/`
  /// and sends their paths with [spotId], or with [proposal] for a place that
  /// is not a spot yet. Returns the claim id.
  Future<String> claimSpot({
    String? spotId,
    SpotProposal? proposal,
    required List<PickedImage> proofs,
    String? note,
  });

  /// My claims and proposals, newest first.
  Stream<List<SpotClaim>> watchMyClaims();

  /// S30.03 "Lưu": only the given fields change; [cover] is uploaded to
  /// `spots/{spotId}/` first; [clearAccess] sends `access: null`.
  Future<void> updateManagedSpot(
    String spotId, {
    String? description,
    List<String>? tips,
    PickedImage? cover,
    OpenHours? openHours,
    SpotAccess? access,
    bool clearAccess = false,
  });

  /// S30.03-residents: add or edit a resident photographer.
  Future<void> saveResident(String spotId, Resident resident);

  /// The manager removes a resident (or the provider leaves the list).
  Future<void> removeResident(String spotId, String providerId);

  /// My gate staff (S30.06), every status but `removed`.
  Stream<List<GateStaff>> watchGateStaff();

  /// Rows naming me as gate staff across organizers (`invited` / `active`):
  /// the invitee's sheet and "Soát vé · {spot}".
  Stream<List<GateStaff>> watchMyGateInvites();

  /// [target] is a phone number (an `@username` answers `not_found` until
  /// usernames exist).
  Future<void> inviteGateStaff(String target);

  Future<void> respondGateStaff(String organizerId, {required bool accept});

  Future<void> removeGateStaff(String staffUid);

  /// `entry_days/{eventId}_{day}`; null before the first sale.
  Stream<EntryDay?> watchEntryDay(String eventId, String day);

  /// S12.03-entry "Đóng ngày": refunds 100% (the rest by eventClock when more
  /// than 20).
  Future<({int refunded, int left})> closeEntryDay(String eventId, String day);
}
