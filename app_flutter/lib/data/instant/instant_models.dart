// lib/data/instant/instant_models.dart
//
// Chụp ngay (S13–S14, plan #140 Contract "App data"): the app's view of
// `instant_config/current`, `instant_requests/{id}`, `instant_offers/{uid}/offers`,
// `instant_presence/{uid}` and `instant_tracks/{id}`, and of the callables'
// answers. No Firebase types: the adapter (firestore_instant_mapping.dart)
// turns Timestamps into UTC DateTimes. Every enum keeps the server's string code.
import 'dart:io' show SocketException;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photobooking/core/core.dart';

part 'instant_models.freezed.dart';

/// The request status (domain `INSTANT_STATUSES`).
enum InstantStatus {
  choosing('choosing'),
  pendingPayment('pending_payment'),
  searching('searching'),
  assigned('assigned'),
  enRoute('en_route'),
  arrived('arrived'),
  inProgress('in_progress'),
  finished('finished'),
  completed('completed'),
  noMatch('no_match'),
  abandoned('abandoned'),
  cancelledByCustomer('cancelled_by_customer'),
  noShowCustomer('no_show_customer');

  const InstantStatus(this.code);
  final String code;

  /// Null for a code this build does not know (the request then reads as absent).
  static InstantStatus? fromCode(String? c) {
    for (final s in values) {
      if (s.code == c) return s;
    }
    return null;
  }

  /// Domain `isInstantActive`: everything but the four terminal statuses
  /// (`no_match` stays active: the customer can choose again or cancel).
  bool get isActive => !const {
    completed,
    abandoned,
    cancelledByCustomer,
    noShowCustomer,
  }.contains(this);
}

/// The five kinds of shoot (spec §2.1; `event` reads "Sự kiện nhỏ").
enum InstantGenre {
  portrait,
  couple,
  family,
  event,
  product;

  String get code => name;

  static InstantGenre? fromCode(String? c) {
    for (final g in values) {
      if (g.code == c) return g;
    }
    return null;
  }
}

/// An offer's outcome; `unavailable` only appears on the request's offer rows
/// (chosen, but busy or gated when the offers went out).
enum OfferOutcome {
  pending,
  accepted,
  declined,
  expired,
  withdrawn,
  unavailable;

  String get code => name;

  /// An unknown outcome reads as expired: the offer is over.
  static OfferOutcome fromCode(String? c) {
    for (final o in values) {
      if (o.code == c) return o;
    }
    return expired;
  }
}

/// `updateInstantJob` actions of the assigned photographer (S14.03).
enum InstantJobAction {
  startRoute('start_route'),
  arrive('arrive'),
  start('start'),
  finish('finish'),
  noShow('no_show');

  const InstantJobAction(this.code);
  final String code;
}

/// Why Live Shutter cannot be switched on (S14.01-locked). The first four are
/// the server's (`setLiveShutter.reasons`); [locationRequired] is the app's
/// own (no location permission, so no position to send).
enum LiveShutterReason {
  notAcceptingOrders('not_accepting_orders'),
  phoneRequired('phone_required'),
  priceListNotAccepted('price_list_not_accepted'),
  outsideServiceArea('outside_service_area'),
  locationRequired('location_required');

  const LiveShutterReason(this.code);
  final String code;

  /// An unknown server reason still blocks: it reads as [notAcceptingOrders]
  /// (dropping it would look like a successful switch-on).
  static LiveShutterReason fromCode(String? c) {
    for (final r in values) {
      if (r.code == c) return r;
    }
    return notAcceptingOrders;
  }
}

/// Who cancelled a request.
enum InstantParticipant {
  customer,
  photographer;

  static InstantParticipant? fromCode(String? c) => switch (c) {
    'customer' => customer,
    'photographer' => photographer,
    _ => null,
  };
}

/// The cancellation rule the server applied or would apply (domain `InstantCancelRule`).
enum InstantCancelRule {
  unpaid('unpaid'),
  fullRefund('full_refund'),
  freeWindow('free_window'),
  photographerLate('photographer_late'),
  enRoute('en_route'),
  arrived('arrived'),
  photographerCancel('photographer_cancel'),
  noShow('no_show');

  const InstantCancelRule(this.code);
  final String code;

  static InstantCancelRule? fromCode(String? c) {
    for (final r in values) {
      if (r.code == c) return r;
    }
    return null;
  }
}

/// One package of the price list (`instant_config/current.packages[]`).
@freezed
abstract class InstantPackage with _$InstantPackage {
  const factory InstantPackage({
    required String code,
    required int durationMin,
    required int photos,
    required int priceVnd,
  }) = _InstantPackage;
}

/// `instant_config/current` as the app needs it (signed-in read).
@freezed
abstract class InstantConfig with _$InstantConfig {
  const InstantConfig._();

  const factory InstantConfig({
    required bool enabled,
    required int priceListVersion,

    /// 0–10 000; 0 = the photographer gets everything (Decision 6).
    @Default(0) int platformFeeBp,

    /// 0–100: what the photographer keeps on an `arrived` cancel (Decision 9).
    @Default(50) int instantArrivedCancelPhotographerPercent,
    @Default(<InstantPackage>[]) List<InstantPackage> packages,
    @Default(<String>[]) List<String> cityNames,
  }) = _InstantConfig;

  /// Domain `photographerEarning`: amount − round(amount × platformFeeBp / 10 000).
  int earningOf(int amountVnd) =>
      amountVnd - (amountVnd * platformFeeBp / 10000).round();
}

/// A person on a request (`photographer` snapshot, Contract "Party snapshot").
@freezed
abstract class InstantParty with _$InstantParty {
  const factory InstantParty({
    required String id,
    @Default('') String name,
    String? avatarUrl,
    @Default(false) bool verified,
    @Default(0) int tomatoPct,
    @Default(0) int reviewCount,
    @Default(0) int completedCount,
  }) = _InstantParty;
}

/// A suggested photographer of the current round (S13.02).
@freezed
abstract class InstantCandidate with _$InstantCandidate {
  const factory InstantCandidate({
    required String photographerId,
    @Default('') String name,
    String? avatarUrl,
    @Default(false) bool verified,
    @Default(0) int tomatoPct,
    @Default(0) int reviewCount,
    @Default(0) int completedCount,
    @Default(0) double distanceKm,
    @Default(1) int etaMinutes,
    @Default(<String>[]) List<String> photos,

    /// The reason texts (≤ 2), as the server wrote them.
    @Default(<String>[]) List<String> reasons,
  }) = _InstantCandidate;
}

/// One invitee of the current round and how their offer went (S13.03).
@freezed
abstract class InstantOfferRow with _$InstantOfferRow {
  const factory InstantOfferRow({
    required String photographerId,
    @Default('') String name,
    String? avatarUrl,
    @Default(0) int tomatoPct,
    @Default(0) int reviewCount,
    @Default(1) int etaMinutes,
    required OfferOutcome outcome,
    DateTime? expiresAt,
  }) = _InstantOfferRow;
}

/// GPS fix plus the name the customer typed (Decision 19).
@freezed
abstract class InstantMeetPoint with _$InstantMeetPoint {
  const factory InstantMeetPoint({
    required double lat,
    required double lng,
    @Default('') String name,
  }) = _InstantMeetPoint;
}

/// `instant_requests/{id}`, read by its customer and its assigned photographer.
/// Every instant is UTC. Money fields stay empty throughout #140.
@freezed
abstract class InstantRequest with _$InstantRequest {
  const factory InstantRequest({
    required String id,
    required String customerId,
    @Default('') String customerName,
    String? customerAvatarUrl,
    required InstantStatus status,
    required String packageCode,
    @Default(0) int durationMin,
    @Default(0) int photos,
    required InstantGenre genre,
    @Default('') String note,
    required InstantMeetPoint meetPoint,
    @Default('') String areaLabel,
    @Default(0) int amountVnd,
    @Default(0) int earningVnd,
    @Default(0) int platformFeeBp,
    @Default(50) int arrivedCancelPhotographerPercent,
    PayMethod? payMethod,

    /// `paidAt != null` (never in #140).
    @Default(false) bool paid,

    /// `committedAt != null`: offers went out at least once.
    @Default(false) bool committed,
    @Default(1) int round,
    @Default(0) int invitedTotal,
    @Default(0) int roundsWithInvites,
    @Default(<InstantCandidate>[]) List<InstantCandidate> candidates,
    @Default(<InstantOfferRow>[]) List<InstantOfferRow> offers,
    @Default(false) bool roundEnded,
    String? photographerId,
    InstantParty? photographer,
    String? chatId,
    int? etaMinutes,
    DateTime? assignedAt,
    DateTime? freeCancelUntil,
    DateTime? lateDeadlineAt,
    DateTime? startedRouteAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? shootEndsAt,
    DateTime? finishedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    InstantParticipant? cancelledBy,
    InstantCancelRule? cancelRule,
    int? refundPercent,
    int? feeVnd,
    DateTime? searchDeadlineAt,
    DateTime? paymentDeadlineAt,
  }) = _InstantRequest;
}

/// `instant_offers/{uid}/offers/{id}`: area and distance only, never the
/// meet point (spec §9).
@freezed
abstract class InstantOffer with _$InstantOffer {
  const factory InstantOffer({
    required String id,
    required String requestId,
    @Default(1) int round,
    required DateTime offeredAt,
    required DateTime expiresAt,
    required OfferOutcome outcome,
    @Default('') String packageCode,
    @Default(0) int durationMin,
    @Default(0) int photos,
    required InstantGenre genre,
    @Default('') String areaLabel,
    @Default(0) double distanceKm,
    @Default(1) int etaMinutes,
    @Default(0) int earningVnd,
    @Default('') String note,
    @Default(1) int invitedCount,
  }) = _InstantOffer;
}

/// `instant_tracks/{requestId}`: the photographer's last position while en route.
@freezed
abstract class InstantTrack with _$InstantTrack {
  const factory InstantTrack({
    required double lat,
    required double lng,
    @Default(0) double accuracyM,
    required DateTime at,
  }) = _InstantTrack;
}

/// The photographer's own `instant_presence/{uid}` (S14.01).
@freezed
abstract class LiveShutterState with _$LiveShutterState {
  const LiveShutterState._();

  const factory LiveShutterState({
    @Default(false) bool online,
    @Default(false) bool helpReady,

    /// The price list version accepted; null = never accepted.
    int? priceListVersion,
    DateTime? heartbeatAt,
    String? activeRequestId,
  }) = _LiveShutterState;

  /// Domain `presenceFresh`: online and a heartbeat less than 30 minutes old.
  bool fresh(DateTime now) =>
      online &&
      heartbeatAt != null &&
      now.difference(heartbeatAt!) < kInstantPresenceFresh;
}

/// Domain `INSTANT.PRESENCE_FRESH_MIN`.
const kInstantPresenceFresh = Duration(minutes: 30);

/// What a cancel costs (`cancelInstantRequest`, S13.08 dry run or the real one).
@freezed
abstract class InstantCancelQuote with _$InstantCancelQuote {
  const factory InstantCancelQuote({
    InstantCancelRule? rule,

    /// 0..100: the customer's share.
    @Default(0) int refundPercent,
    @Default(0) int refundVnd,

    /// What the photographer keeps.
    @Default(0) int feeVnd,

    /// The money collected (0 while unpaid, every #140 request).
    @Default(0) int amountVnd,
  }) = _InstantCancelQuote;
}

/// `inviteInstant`'s answer. #202 (Task 11) adds the payment case.
sealed class InstantInviteResult {
  const InstantInviteResult();
}

/// The offers went out to [invited]; [unavailable] were busy, offline or gated.
final class InstantInvited extends InstantInviteResult {
  const InstantInvited({required this.invited, required this.unavailable});
  final List<String> invited;
  final List<String> unavailable;
}

/// The price moved (spec §10): the new amount is saved, nothing was sent.
final class InstantPriceChanged extends InstantInviteResult {
  const InstantPriceChanged({required this.amountVnd});
  final int amountVnd;
}

/// The refusals the app tells apart (server `details.code`, plus `network`).
enum InstantErrorKind {
  noMatch('no_match'),
  offerExpired('offer_expired'),
  alreadyAssigned('already_assigned'),
  outsideServiceArea('outside_service_area'),
  notEligible('not_eligible'),
  notAcceptingOrders('not_accepting_orders'),
  blocked('blocked'),
  phoneRequired('phone_required'),
  priceChanged('price_changed'),
  deadlinePassed('deadline_passed'),
  conflict('conflict'),
  notFound('not_found'),
  permissionDenied('permission_denied'),
  invalidArgument('invalid_argument'),
  network('network'),
  unknown('unknown');

  const InstantErrorKind(this.code);
  final String code;

  static InstantErrorKind fromCode(String? c) {
    for (final k in values) {
      if (k.code == c) return k;
    }
    return unknown;
  }
}

/// A refusal of a Chụp ngay call; [code] is the server's `details.code`.
class InstantError implements Exception {
  const InstantError(this.code);
  final String code;

  InstantErrorKind get kind => InstantErrorKind.fromCode(code);

  @override
  bool operator ==(Object other) => other is InstantError && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'InstantError($code)';
}

/// [InstantError.code]; a socket failure is `network`; anything else `unknown`.
String instantErrorCodeOf(Object e) => switch (e) {
  InstantError(:final code) => code,
  SocketException() => 'network',
  _ => 'unknown',
};
