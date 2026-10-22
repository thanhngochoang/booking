// lib/data/instant/firestore_instant_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/instant/firestore_instant_mapping.dart';
import 'package:photobooking/data/instant/instant_geo.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repository.dart';

/// Calls the callable [name] with [data] and returns its data. Injected in
/// tests; the default goes through `FirebaseFunctions`.
typedef InstantCallable = Future<Object?> Function(
  String name,
  Map<String, Object?> data,
);

/// Callables that run with the server's 30 s `PAYMENT_CALLABLE_OPTIONS`
/// (contended transactions); the others have the 10 s `CALLABLE_OPTIONS`.
const _longCallables = {
  'inviteInstant',
  'answerInstantOffer',
  'cancelInstantRequest',
  'confirmInstantComplete',
};

/// The client waits longer than the server may run (30 s / 10 s) plus a cold
/// start, so a slow win (an accepted offer) is not reported as `network`.
@visibleForTesting
Duration instantCallableTimeout(String name) =>
    Duration(seconds: _longCallables.contains(name) ? 40 : 15);

/// A callable refusal without `details.code`, by its transport code only
/// (never the message).
@visibleForTesting
String instantTransportErrorCode(String code) => switch (code) {
  'unavailable' || 'deadline-exceeded' => 'network',
  'unauthenticated' || 'permission-denied' => 'permission_denied',
  'not-found' => 'not_found',
  'invalid-argument' => 'invalid_argument',
  'aborted' => 'conflict',
  _ => 'unknown',
};

/// A direct write's Firestore failure code as an [InstantError] code.
@visibleForTesting
String instantWriteErrorCode(String code) => switch (code) {
  'permission-denied' => 'permission_denied',
  'not-found' => 'not_found',
  'unavailable' || 'deadline-exceeded' => 'network',
  _ => 'unknown',
};

/// Reads `instant_*` documents directly (as the rules allow) and changes
/// state only through the callables (Contract "Callables").
class FirestoreInstantRepository implements InstantRepository {
  FirestoreInstantRepository({
    FirebaseFirestore? firestore,
    this._functions,
    required this.uid,
    this._callable,
  }) : _override = firestore;

  /// The signed-in user; null while signed out (own-data streams are empty).
  final String? uid;
  final FirebaseFirestore? _override;
  final FirebaseFunctions? _functions;
  final InstantCallable? _callable;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  Future<Object?> _invoke(String name, Map<String, Object?> data) async {
    final callable = _callable;
    if (callable != null) return callable(name, data);
    final functions =
        _functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);
    final r = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: instantCallableTimeout(name)),
        )
        .call<Object?>(data);
    return r.data;
  }

  /// Like `callEventFunction`: a refusal becomes [InstantError] with the
  /// server's `details.code`; an unreachable backend is `network`. Without a
  /// `details.code` the transport code decides, never the message.
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final r = await _invoke(name, data);
      return r is Map ? r.cast<String, dynamic>() : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        throw InstantError(details['code'] as String);
      }
      throw InstantError(instantTransportErrorCode(e.code));
    }
  }

  /// A direct write's Firestore failure as an [InstantError].
  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on FirebaseException catch (e) {
      throw InstantError(instantWriteErrorCode(e.code));
    }
  }

  static bool _validId(String id) => id.isNotEmpty && !id.contains('/');

  static Map<String, Object?> _location(InstantLocation l) => {
    'lat': l.lat,
    'lng': l.lng,
    'accuracyM': l.accuracyM,
  };

  // ---- config ----------------------------------------------------------------

  @override
  Future<InstantConfig> config() async {
    final snap = await _db.doc('instant_config/current').get();
    final cfg = instantConfigFromFirestore(snap.data());
    if (cfg == null) throw const InstantError('not_eligible');
    return cfg;
  }

  // ---- customer --------------------------------------------------------------

  @override
  Future<String> createRequest({
    required String packageCode,
    required InstantGenre genre,
    required double lat,
    required double lng,
    required String meetPointName,
    String? note,
  }) async {
    final r = await _call('createInstantRequest', {
      'packageCode': packageCode,
      'genre': genre.code,
      'meetPoint': {'lat': lat, 'lng': lng, 'name': meetPointName},
      'note': ?note,
    });
    final id = r['requestId'];
    if (id is! String || id.isEmpty) throw const InstantError('unknown');
    return id;
  }

  @override
  Future<void> nextCandidates(
    String requestId, {
    List<String> skipped = const [],
  }) async {
    await _call('nextInstantCandidates', {
      'requestId': requestId,
      'skipped': skipped,
    });
  }

  @override
  Future<InstantInviteResult> invite(
    String requestId, {
    required List<String> photographerIds,
    required List<String> skipped,
    required int expectedAmountVnd,
    PayMethod? payMethod,
  }) async {
    final r = await _call('inviteInstant', {
      'requestId': requestId,
      'photographerIds': photographerIds,
      'skipped': skipped,
      'expectedAmountVnd': expectedAmountVnd,
      'payMethod': ?payMethod?.code,
    });
    return instantInviteResultFromJson(r);
  }

  @override
  Future<void> confirmComplete(String requestId) async {
    await _call('confirmInstantComplete', {'requestId': requestId});
  }

  @override
  Future<String?> myActiveRequestId() async {
    final me = uid;
    if (me == null) return null;
    final snap = await _db
        .collection('instant_requests')
        .where('customerId', isEqualTo: me)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  @override
  Stream<InstantTrack?> watchTrack(String requestId) {
    if (uid == null || !_validId(requestId)) return Stream.value(null);
    return nullWhenDenied(
      _db
          .doc('instant_tracks/$requestId')
          .snapshots()
          .map((s) => s.exists ? instantTrackFromFirestore(s.data()) : null),
      label: 'instant_tracks',
    );
  }

  // ---- both ------------------------------------------------------------------

  @override
  Stream<InstantRequest?> watchRequest(String requestId) {
    if (uid == null || !_validId(requestId)) return Stream.value(null);
    return nullWhenDenied(
      _db
          .doc('instant_requests/$requestId')
          .snapshots()
          .map((s) => instantRequestFromFirestore(s.id, s.data())),
      label: 'instant_requests',
    );
  }

  @override
  Future<InstantCancelQuote> cancel(
    String requestId, {
    required bool dryRun,
  }) async {
    final r = await _call('cancelInstantRequest', {
      'requestId': requestId,
      'dryRun': dryRun,
    });
    return instantCancelQuoteFromJson(r);
  }

  @override
  Future<void> tick(String requestId) async {
    await _call('tickInstantRequest', {'requestId': requestId});
  }

  // ---- photographer ------------------------------------------------------------

  @override
  Stream<LiveShutterState?> watchPresence() {
    final me = uid;
    if (me == null) return Stream.value(null);
    return _db
        .doc('instant_presence/$me')
        .snapshots()
        .map((s) => liveShutterStateFromFirestore(s.data()));
  }

  @override
  Future<List<LiveShutterReason>> setLiveShutter({
    required bool online,
    bool dryRun = false,
    InstantLocation? location,
  }) async {
    final r = await _call('setLiveShutter', {
      'online': online,
      'dryRun': dryRun,
      if (location != null) 'location': _location(location),
    });
    final reasons = r['reasons'];
    return [
      if (reasons is List)
        for (final c in reasons)
          LiveShutterReason.fromCode(c is String ? c : null),
    ];
  }

  @override
  Future<void> saveSettings({
    int? acceptPriceListVersion,
    bool? helpReady,
  }) async {
    await _call('saveInstantSettings', {
      'acceptPriceListVersion': ?acceptPriceListVersion,
      'helpReady': ?helpReady,
    });
  }

  @override
  Future<void> heartbeat({
    required double lat,
    required double lng,
    required double accuracyM,
  }) async {
    final me = uid;
    if (me == null) throw const InstantError('permission_denied');
    final cells = instantGeohashes(lat, lng);
    // Exactly the six fields the rules allow (validPresenceHeartbeat).
    await _write(
      () => _db.doc('instant_presence/$me').update({
        'lat': lat,
        'lng': lng,
        'accuracyM': accuracyM,
        'geohash5': cells.geohash5,
        'geohash4': cells.geohash4,
        'heartbeatAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Stream<List<InstantOffer>> watchPendingOffers() {
    final me = uid;
    if (me == null) return Stream.value(const []);
    return _db
        .collection('instant_offers/$me/offers')
        .where('outcome', isEqualTo: 'pending')
        .snapshots(includeMetadataChanges: true)
        .map((q) {
          final offers = [
            for (final d in q.docs)
              if (instantOfferFromFirestore(d.id, d.data())
                  case final InstantOffer o)
                o,
          ]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
          return (offers: offers, fromCache: q.metadata.isFromCache);
        })
        .transform(StreamTransformer.fromBind(settledPendingOffers));
  }

  @override
  Future<String> answerOffer(String offerId, {required bool accept}) async {
    final r = await _call('answerInstantOffer', {
      'offerId': offerId,
      'action': accept ? 'accept' : 'decline',
    });
    final id = r['requestId'];
    if (id is! String || id.isEmpty) throw const InstantError('unknown');
    return id;
  }

  @override
  Future<InstantStatus> updateJob(
    String requestId,
    InstantJobAction action, {
    InstantLocation? location,
    bool force = false,
  }) async {
    final r = await _call('updateInstantJob', {
      'requestId': requestId,
      'action': action.code,
      if (location != null) 'location': _location(location),
      if (force) 'force': true,
    });
    final status = r['status'];
    final parsed = InstantStatus.fromCode(status is String ? status : null);
    // A status this build does not know (a newer server): the step was done,
    // but there is nothing to return, so the caller gets `unknown`; the
    // request stream (which reads such a request as absent) drives the screen.
    if (parsed == null) throw const InstantError('unknown');
    return parsed;
  }

  @override
  Future<void> shareTrack(
    String requestId, {
    required double lat,
    required double lng,
    required double accuracyM,
    double? heading,
  }) async {
    if (uid == null) throw const InstantError('permission_denied');
    if (!_validId(requestId)) throw const InstantError('invalid_argument');
    // Exactly the five fields the rules allow (validTrackPoint).
    await _write(
      () => _db.doc('instant_tracks/$requestId').update({
        'lat': lat,
        'lng': lng,
        'accuracyM': accuracyM,
        'heading': heading,
        'at': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Stream<BookingContactSnapshot?> watchCustomerContact(String requestId) {
    if (uid == null || !_validId(requestId)) return Stream.value(null);
    return nullWhenDenied(
      _db
          .doc('instant_requests/$requestId/private/contact')
          .snapshots()
          .map((s) => s.exists ? bookingContactFromFirestore(s.data()) : null),
      label: 'instant_contact',
    );
  }

  @override
  Stream<InstantRequest?> watchMyActiveJob() {
    final me = uid;
    if (me == null) return Stream.value(null);
    return _db
        .collection('instant_requests')
        .where('photographerId', isEqualTo: me)
        .where('active', isEqualTo: true)
        .limit(_activeJobsCap)
        .snapshots()
        .map(
          (q) => pickActiveJob([
            for (final d in q.docs)
              ?instantRequestFromFirestore(d.id, d.data()),
          ]),
        );
  }
}

/// Upper bound on a photographer's active requests: at most one job in hand
/// plus the `finished` ones still waiting for the customer's confirmation
/// (auto-completed after 2 h).
const _activeJobsCap = 10;

/// The job S06.01 should show: the photographer is freed at "Hoàn thành", so
/// a newer job can be active next to `finished` ones awaiting confirmation.
/// Prefer a job not yet finished, then the latest assignment.
InstantRequest? pickActiveJob(List<InstantRequest> jobs) {
  if (jobs.isEmpty) return null;
  int rank(InstantRequest r) => r.status == InstantStatus.finished ? 0 : 1;
  final sorted = [...jobs]
    ..sort((a, b) {
      final byStatus = rank(b).compareTo(rank(a));
      if (byStatus != 0) return byStatus;
      final never = DateTime.utc(0);
      return (b.assignedAt ?? never).compareTo(a.assignedAt ?? never);
    });
  return sorted.first;
}

/// A document listener whose rules can stop allowing the read (a track
/// deleted at arrival, a request the photographer no longer holds, a contact
/// copy that is not unlocked): `permission-denied` emits null and ENDS the
/// stream (a later change is not seen; re-subscribe, e.g. on a status
/// change); every other error is passed on. Denials are logged in debug
/// builds by [label], so rules that refuse by mistake leave a trace.
Stream<T?> nullWhenDenied<T>(Stream<T?> source, {String label = 'instant'}) =>
    source.transform(
      StreamTransformer<T?, T?>.fromHandlers(
        handleError: (error, stack, sink) {
          if (error is FirebaseException && error.code == 'permission-denied') {
            debugPrint('$label: read denied, reading as absent');
            sink
              ..add(null)
              ..close();
          } else {
            sink.addError(error, stack);
          }
        },
      ),
    );

/// The pending offers as S14.02 may trust them. A cold start (the app opened
/// from an offer's push) first gets the local cache, often empty, before the
/// server's answer with the new offer: an empty list from the cache is held
/// back until the server has answered once. A non-empty cached list passes
/// (offline, it is all there is), and a metadata-only change that leaves the
/// list as it was is not repeated.
@visibleForTesting
Stream<List<InstantOffer>> settledPendingOffers(
  Stream<({List<InstantOffer> offers, bool fromCache})> snapshots,
) async* {
  var server = false;
  List<InstantOffer>? last;
  await for (final s in snapshots) {
    if (!s.fromCache) {
      server = true;
    } else if (!server && s.offers.isEmpty) {
      continue;
    }
    if (last != null && listEquals(last, s.offers)) continue;
    last = s.offers;
    yield s.offers;
  }
}
