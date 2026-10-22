import 'dart:async';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repository.dart';

/// One recorded call: the repository method name and its arguments.
typedef InstantCall = ({String name, Map<String, Object?> args});

/// A replaying broadcast stream: new listeners get the last value first.
class _Live<T> {
  _Live(this.value);

  T value;
  Object? _error;
  final _controller = StreamController<T>.broadcast();

  void emit(T v) {
    value = v;
    _error = null;
    _controller.add(v);
  }

  void fail(Object e) {
    _error = e;
    _controller.addError(e);
  }

  Stream<T> get stream async* {
    final error = _error;
    if (error != null) throw error;
    yield value;
    yield* _controller.stream;
  }

  Future<void> close() => _controller.close();
}

/// In-memory [InstantRepository] for widget and controller tests: streams
/// are driven by `emit*`, every call is recorded in [calls], and [failNext]
/// makes the next call of a method throw `InstantError(code)`.
class FakeInstantRepository implements InstantRepository {
  FakeInstantRepository({
    InstantConfig? config,
    LiveShutterState? presence,
    List<InstantOffer> offers = const [],
    InstantRequest? activeJob,
    this.activeRequestId,
  }) : configValue =
           config ??
           const InstantConfig(
             enabled: true,
             priceListVersion: 1,
             packages: [
               InstantPackage(
                 code: 'p30',
                 durationMin: 30,
                 photos: 15,
                 priceVnd: 390000,
               ),
               InstantPackage(
                 code: 'p60',
                 durationMin: 60,
                 photos: 30,
                 priceVnd: 690000,
               ),
               InstantPackage(
                 code: 'p120',
                 durationMin: 120,
                 photos: 60,
                 priceVnd: 1190000,
               ),
             ],
             cityNames: ['TP.HCM', 'Hà Nội', 'Đà Nẵng'],
           ),
       _presence = _Live(presence),
       _offers = _Live(List.of(offers)),
       _activeJob = _Live(activeJob);

  // ---- configurable answers ------------------------------------------------

  InstantConfig configValue;
  String createdRequestId = 'req_new';
  InstantInviteResult inviteResult = const InstantInvited(
    invited: [],
    unavailable: [],
  );
  List<LiveShutterReason> liveShutterReasons = const [];
  InstantCancelQuote cancelQuote = const InstantCancelQuote(
    rule: InstantCancelRule.unpaid,
  );

  /// `answerOffer`'s request id; defaults to the offer's own request.
  String? answeredRequestId;
  InstantStatus? jobStatus;
  String? activeRequestId;

  /// Completes a call only when it completes (for "busy" states); null = at once.
  Completer<void>? gate;

  /// Models the accept transaction: the photographer's pending offers are
  /// withdrawn (the listener sees them go) before `answerOffer` returns,
  /// i.e. before [gate] opens.
  bool withdrawOnAccept = false;

  // ---- recording -----------------------------------------------------------

  final calls = <InstantCall>[];
  final _failures = <String, String>{};

  /// The next call of [method] (e.g. `'answerOffer'`) throws `InstantError(code)`.
  void failNext(String method, String code) => _failures[method] = code;

  Iterable<InstantCall> callsOf(String name) =>
      calls.where((c) => c.name == name);

  Future<void> _record(String name, Map<String, Object?> args) async {
    calls.add((name: name, args: args));
    final code = _failures.remove(name);
    if (code != null) throw InstantError(code);
    final g = gate;
    if (g != null) await g.future;
  }

  // ---- streams -------------------------------------------------------------

  final Map<String, _Live<InstantRequest?>> _requests = {};
  final Map<String, _Live<InstantTrack?>> _tracks = {};
  final Map<String, _Live<BookingContactSnapshot?>> _contacts = {};
  final _Live<LiveShutterState?> _presence;
  final _Live<List<InstantOffer>> _offers;
  final _Live<InstantRequest?> _activeJob;

  _Live<V?> _slot<V>(Map<String, _Live<V?>> m, String id) =>
      m.putIfAbsent(id, () => _Live<V?>(null));

  void emitRequest(String id, InstantRequest? request) =>
      _slot(_requests, id).emit(request);
  void emitTrack(String requestId, InstantTrack? track) =>
      _slot(_tracks, requestId).emit(track);
  void emitContact(String requestId, BookingContactSnapshot? contact) =>
      _slot(_contacts, requestId).emit(contact);
  void emitPresence(LiveShutterState? presence) => _presence.emit(presence);
  void emitOffers(List<InstantOffer> offers) => _offers.emit(
    List.of(offers)..sort((a, b) => a.expiresAt.compareTo(b.expiresAt)),
  );
  void emitActiveJob(InstantRequest? job) => _activeJob.emit(job);

  /// Makes a stream fail (e.g. a listener refused), to test error states.
  void failRequest(String id, Object error) => _slot(_requests, id).fail(error);
  void failPresence(Object error) => _presence.fail(error);
  void failOffers(Object error) => _offers.fail(error);
  void failActiveJob(Object error) => _activeJob.fail(error);

  LiveShutterState? get presence => _presence.value;
  List<InstantOffer> get offers => _offers.value;

  Future<void> dispose() async {
    for (final l in [
      ..._requests.values,
      ..._tracks.values,
      ..._contacts.values,
      _presence,
      _offers,
      _activeJob,
    ]) {
      await l.close();
    }
  }

  // ---- InstantRepository ---------------------------------------------------

  @override
  Future<InstantConfig> config() async {
    await _record('config', const {});
    return configValue;
  }

  @override
  Future<String> createRequest({
    required String packageCode,
    required InstantGenre genre,
    required double lat,
    required double lng,
    required String meetPointName,
    String? note,
  }) async {
    await _record('createRequest', {
      'packageCode': packageCode,
      'genre': genre,
      'lat': lat,
      'lng': lng,
      'meetPointName': meetPointName,
      'note': note,
    });
    return createdRequestId;
  }

  @override
  Future<void> nextCandidates(
    String requestId, {
    List<String> skipped = const [],
  }) => _record('nextCandidates', {'requestId': requestId, 'skipped': skipped});

  @override
  Future<InstantInviteResult> invite(
    String requestId, {
    required List<String> photographerIds,
    required List<String> skipped,
    required int expectedAmountVnd,
    PayMethod? payMethod,
  }) async {
    await _record('invite', {
      'requestId': requestId,
      'photographerIds': photographerIds,
      'skipped': skipped,
      'expectedAmountVnd': expectedAmountVnd,
      'payMethod': payMethod,
    });
    return inviteResult;
  }

  @override
  Future<void> confirmComplete(String requestId) =>
      _record('confirmComplete', {'requestId': requestId});

  @override
  Future<String?> myActiveRequestId() async {
    await _record('myActiveRequestId', const {});
    return activeRequestId;
  }

  @override
  Stream<InstantTrack?> watchTrack(String requestId) =>
      _slot(_tracks, requestId).stream;

  @override
  Stream<InstantRequest?> watchRequest(String requestId) =>
      _slot(_requests, requestId).stream;

  @override
  Future<InstantCancelQuote> cancel(
    String requestId, {
    required bool dryRun,
  }) async {
    await _record('cancel', {'requestId': requestId, 'dryRun': dryRun});
    return cancelQuote;
  }

  @override
  Future<void> tick(String requestId) =>
      _record('tick', {'requestId': requestId});

  @override
  Stream<LiveShutterState?> watchPresence() => _presence.stream;

  @override
  Future<List<LiveShutterReason>> setLiveShutter({
    required bool online,
    bool dryRun = false,
    InstantLocation? location,
  }) async {
    await _record('setLiveShutter', {
      'online': online,
      'dryRun': dryRun,
      'location': location,
    });
    final reasons = List.of(liveShutterReasons);
    if (!dryRun && reasons.isEmpty) {
      final p = _presence.value ?? const LiveShutterState();
      _presence.emit(p.copyWith(online: online));
    }
    return reasons;
  }

  @override
  Future<void> saveSettings({
    int? acceptPriceListVersion,
    bool? helpReady,
  }) async {
    await _record('saveSettings', {
      'acceptPriceListVersion': acceptPriceListVersion,
      'helpReady': helpReady,
    });
    final p = _presence.value ?? const LiveShutterState();
    _presence.emit(
      p.copyWith(
        priceListVersion: acceptPriceListVersion ?? p.priceListVersion,
        helpReady: helpReady ?? p.helpReady,
      ),
    );
  }

  @override
  Future<void> heartbeat({
    required double lat,
    required double lng,
    required double accuracyM,
  }) => _record('heartbeat', {'lat': lat, 'lng': lng, 'accuracyM': accuracyM});

  @override
  Stream<List<InstantOffer>> watchPendingOffers() => _offers.stream;

  @override
  Future<String> answerOffer(String offerId, {required bool accept}) async {
    final requestId = _offers.value
        .where((o) => o.id == offerId)
        .firstOrNull
        ?.requestId;
    if (accept && withdrawOnAccept && !_failures.containsKey('answerOffer')) {
      _offers.emit(const []);
    }
    await _record('answerOffer', {'offerId': offerId, 'accept': accept});
    return answeredRequestId ?? requestId ?? 'req1';
  }

  @override
  Future<InstantStatus> updateJob(
    String requestId,
    InstantJobAction action, {
    InstantLocation? location,
    bool force = false,
  }) async {
    await _record('updateJob', {
      'requestId': requestId,
      'action': action,
      'location': location,
      'force': force,
    });
    return jobStatus ??
        switch (action) {
          InstantJobAction.startRoute => InstantStatus.enRoute,
          InstantJobAction.arrive => InstantStatus.arrived,
          InstantJobAction.start => InstantStatus.inProgress,
          InstantJobAction.finish => InstantStatus.finished,
          InstantJobAction.noShow => InstantStatus.noShowCustomer,
        };
  }

  @override
  Future<void> shareTrack(
    String requestId, {
    required double lat,
    required double lng,
    required double accuracyM,
    double? heading,
  }) => _record('shareTrack', {
    'requestId': requestId,
    'lat': lat,
    'lng': lng,
    'accuracyM': accuracyM,
    'heading': heading,
  });

  @override
  Stream<BookingContactSnapshot?> watchCustomerContact(String requestId) =>
      _slot(_contacts, requestId).stream;

  @override
  Stream<InstantRequest?> watchMyActiveJob() => _activeJob.stream;
}
