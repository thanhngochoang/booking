// lib/data/instant/instant_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// A position sent with a call (`{lat, lng, accuracyM}`).
typedef InstantLocation = ({double lat, double lng, double accuracyM});

/// Port of Chụp ngay (S13–S14). Every state change is a callable; the only
/// direct writes are the photographer's own heartbeat and track point.
/// Calls throw [InstantError] (server `details.code`, or `network`).
/// Streams surface their errors, except where a document is legitimately
/// unreadable (see each method).
abstract class InstantRepository {
  /// `instant_config/current`; `not_eligible` when it does not exist.
  Future<InstantConfig> config();

  // ---- customer (used by the companion plan) -------------------------------

  /// `createInstantRequest`; returns the new request id.
  Future<String> createRequest({
    required String packageCode,
    required InstantGenre genre,
    required double lat,
    required double lng,
    required String meetPointName,
    String? note,
  });

  /// `nextInstantCandidates`: a new round without [skipped].
  Future<void> nextCandidates(
    String requestId, {
    List<String> skipped = const [],
  });

  /// `inviteInstant`. #140 sends no [payMethod]; #202 sends its code.
  Future<InstantInviteResult> invite(
    String requestId, {
    required List<String> photographerIds,
    required List<String> skipped,
    required int expectedAmountVnd,
    PayMethod? payMethod,
  });

  /// `confirmInstantComplete`.
  Future<void> confirmComplete(String requestId);

  /// The signed-in customer's active request, if any (one read).
  Future<String?> myActiveRequestId();

  /// The photographer's position while en route; null before and after
  /// (the track exists only en route and the rules deny it otherwise).
  Stream<InstantTrack?> watchTrack(String requestId);

  // ---- both ------------------------------------------------------------------

  /// The request; null when missing, unknown, or no longer readable by the
  /// caller (e.g. the photographer cancelled and was removed from it).
  Stream<InstantRequest?> watchRequest(String requestId);

  /// `cancelInstantRequest`; [dryRun] only quotes.
  Future<InstantCancelQuote> cancel(String requestId, {required bool dryRun});

  /// `tickInstantRequest`: settles timers when a countdown reaches zero.
  Future<void> tick(String requestId);

  // ---- photographer ------------------------------------------------------------

  /// The signed-in photographer's presence; null when there is none yet.
  Stream<LiveShutterState?> watchPresence();

  /// `setLiveShutter`; returns the reasons it was refused (empty = done).
  Future<List<LiveShutterReason>> setLiveShutter({
    required bool online,
    bool dryRun = false,
    InstantLocation? location,
  });

  /// `saveInstantSettings`.
  Future<void> saveSettings({int? acceptPriceListVersion, bool? helpReady});

  /// Direct write of the own presence position (rules: ≥ 60 s apart).
  Future<void> heartbeat({
    required double lat,
    required double lng,
    required double accuracyM,
  });

  /// The signed-in photographer's pending offers, soonest expiry first.
  Stream<List<InstantOffer>> watchPendingOffers();

  /// `answerInstantOffer`; returns the request id.
  Future<String> answerOffer(String offerId, {required bool accept});

  /// `updateInstantJob`; returns the new status.
  Future<InstantStatus> updateJob(
    String requestId,
    InstantJobAction action, {
    InstantLocation? location,
    bool force = false,
  });

  /// Direct write of the own track point (rules: en route, ≥ 15 s apart).
  Future<void> shareTrack(
    String requestId, {
    required double lat,
    required double lng,
    required double accuracyM,
    double? heading,
  });

  /// The customer's contact copy for the assigned photographer; null while
  /// it is not readable (unpaid — always in #140 — or the request ended).
  Stream<BookingContactSnapshot?> watchCustomerContact(String requestId);

  /// The signed-in photographer's active job, if any.
  Stream<InstantRequest?> watchMyActiveJob();
}
