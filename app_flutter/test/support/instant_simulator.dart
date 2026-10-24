// One in-memory Chụp ngay backend for the two-party flow test (plan #140
// Task 7): the customer's app and a photographer's app each get an
// [InstantRepository] facade ([InstantSimulator.customer],
// [InstantSimulator.photographer]) on the same requests, offers and tracks.
//
// It follows the server's rules (packages/domain `instant_requests.ts`,
// `instant_jobs.ts`, `instant_settle.ts`, `instant_cancel.ts`) at the level the
// screens see: rounds of five, 60 s offers, first accept wins, the status
// arrows, lazy timers settled by every call and by `tick`, and the cancel
// table. Time comes from the injected [InstantSimulator.now]. #140 moves no
// money: a request is unpaid unless the test calls [InstantSimulator.markPaid]
// (standing in for #202's payment) to show the paid quotes.
import 'dart:async';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repository.dart';

import 'instant_customer_world.dart' show instantCandidates;

// Domain `INSTANT` (instant.ts).
const _offerTtl = Duration(seconds: 60);
const _searchWindow = Duration(minutes: 10);
const _abandonAfter = Duration(minutes: 30);
const _freeCancel = Duration(minutes: 2);
const _lateGrace = Duration(minutes: 15);
const _noShowWait = Duration(minutes: 15);
const _autoComplete = Duration(hours: 2);
const _roundSize = 5;
const _arriveRadiusM = 200.0;
const _poorAccuracyM = 100.0;

/// Domain `nextInstantStatus`: the allowed arrows; anything else is `conflict`.
const _arrows = <(InstantStatus, String), InstantStatus>{
  (InstantStatus.choosing, 'invite'): InstantStatus.searching,
  (InstantStatus.searching, 'round_ended'): InstantStatus.choosing,
  (InstantStatus.searching, 'accept'): InstantStatus.assigned,
  (InstantStatus.choosing, 'no_match'): InstantStatus.noMatch,
  (InstantStatus.searching, 'no_match'): InstantStatus.noMatch,
  (InstantStatus.noMatch, 'reopen'): InstantStatus.choosing,
  (InstantStatus.assigned, 'start_route'): InstantStatus.enRoute,
  (InstantStatus.enRoute, 'arrive'): InstantStatus.arrived,
  (InstantStatus.arrived, 'start'): InstantStatus.inProgress,
  (InstantStatus.inProgress, 'finish'): InstantStatus.finished,
  (InstantStatus.inProgress, 'complete'): InstantStatus.completed,
  (InstantStatus.finished, 'complete'): InstantStatus.completed,
  (InstantStatus.assigned, 'photographer_cancel'): InstantStatus.choosing,
  (InstantStatus.enRoute, 'photographer_cancel'): InstantStatus.choosing,
  (InstantStatus.arrived, 'photographer_cancel'): InstantStatus.choosing,
  (InstantStatus.choosing, 'customer_cancel'):
      InstantStatus.cancelledByCustomer,
  (InstantStatus.searching, 'customer_cancel'):
      InstantStatus.cancelledByCustomer,
  (InstantStatus.noMatch, 'customer_cancel'): InstantStatus.cancelledByCustomer,
  (InstantStatus.assigned, 'customer_cancel'):
      InstantStatus.cancelledByCustomer,
  (InstantStatus.enRoute, 'customer_cancel'): InstantStatus.cancelledByCustomer,
  (InstantStatus.arrived, 'customer_cancel'): InstantStatus.cancelledByCustomer,
  (InstantStatus.arrived, 'no_show'): InstantStatus.noShowCustomer,
};

InstantStatus _next(InstantStatus from, String event) =>
    _arrows[(from, event)] ?? (throw const InstantError('conflict'));

/// The photographers who are online near Tao Đàn, best match first: the five
/// of mock `#S13.02`, then three more for a second round.
const instantSimulatorPool = [
  ...instantCandidates,
  InstantCandidate(
    photographerId: 'p6',
    name: 'Anh Thư',
    verified: true,
    tomatoPct: 94,
    reviewCount: 19,
    completedCount: 33,
    distanceKm: 2.6,
    etaMinutes: 15,
  ),
  InstantCandidate(
    photographerId: 'p7',
    name: 'Đức Long',
    tomatoPct: 90,
    reviewCount: 12,
    completedCount: 20,
    distanceKm: 3.4,
    etaMinutes: 17,
  ),
  InstantCandidate(
    photographerId: 'p8',
    name: 'Bảo Ngọc',
    tomatoPct: 92,
    reviewCount: 27,
    completedCount: 45,
    distanceKm: 3.9,
    etaMinutes: 19,
  ),
];

/// The server's own part of a request (what the app's model does not carry).
class _Row {
  _Row(this.request, {required this.lastActivityAt});

  InstantRequest request;
  DateTime lastActivityAt;
  final excluded = <String>{};
}

class InstantSimulator {
  InstantSimulator({
    required this.now,
    InstantConfig? config,
    this.pool = instantSimulatorPool,
    this.customerId = 'cus1',
    this.customerName = 'Lan Anh',
  }) : config =
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
             cityNames: ['TP.HCM'],
           );

  final DateTime Function() now;

  /// `instant_config/current`; `instantArrivedCancelPhotographerPercent` is
  /// snapshotted on each new request.
  InstantConfig config;
  final List<InstantCandidate> pool;
  final String customerId;
  final String customerName;

  final _rows = <String, _Row>{};

  /// Every offer ever sent, by photographer.
  final _offers = <String, List<InstantOffer>>{};
  final _tracks = <String, InstantTrack>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  /// The customer's app.
  late final InstantRepository customer = _SimRepository(this, customerId);

  /// [uid]'s app (one of [pool]).
  InstantRepository photographer(String uid) => _SimRepository(this, uid);

  /// The request as the server holds it.
  InstantRequest? request(String id) => _rows[id]?.request;

  /// The offer [uid] got in [requestId]'s current round.
  InstantOffer offerOf(String requestId, String uid) => _offers[uid]!.lastWhere(
    (o) => o.requestId == requestId,
  );

  /// Stands in for #202's payment: from now on the request holds its money.
  void markPaid(String id) => _write(id, (r) => r.copyWith(paid: true));

  /// Closes the change feed. Not awaited by callers: its done future may
  /// wait on root-zone work the widget tester's fake async never runs.
  void dispose() {
    _changes.close();
  }

  // ---- storage ---------------------------------------------------------------

  _Row _row(String id) => _rows[id] ?? (throw const InstantError('not_found'));

  void _write(String id, InstantRequest Function(InstantRequest) change) {
    final row = _row(id);
    row.request = change(row.request);
    _changed();
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// A listener that reads [read] now and after every write (deduplicated).
  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> c;
    StreamSubscription<void>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(read());
        sub = _changes.stream.listen((_) => c.add(read()));
      },
      // Returns nothing: a cancel future of the broadcast source lives in
      // the root zone and would keep `.first` from completing under the
      // widget tester's fake async.
      onCancel: () {
        sub?.cancel();
      },
    );
    return c.stream.distinct();
  }

  void _setOffer(String uid, String offerId, OfferOutcome outcome) {
    final list = _offers[uid];
    if (list == null) return;
    final i = list.indexWhere((o) => o.id == offerId);
    if (i >= 0) list[i] = list[i].copyWith(outcome: outcome);
  }

  String _offerIdOf(String requestId, int round, String uid) =>
      'o_${requestId}_${round}_$uid';

  bool _busy(String uid) => _rows.values.any(
    (row) =>
        row.request.photographerId == uid &&
        row.request.status.isActive &&
        row.request.status != InstantStatus.finished,
  );

  List<InstantCandidate> _candidates(_Row row) => [
    for (final c in pool)
      if (!row.excluded.contains(c.photographerId) && !_busy(c.photographerId))
        c,
  ].take(_roundSize).toList();

  // ---- settle (domain settleInstant) -----------------------------------------

  /// Applies every timer due now; idempotent.
  InstantRequest _settle(String id) {
    final row = _row(id);
    var r = row.request;
    if (!r.status.isActive) return r;
    final t = now();
    if (r.status == InstantStatus.searching) {
      r = r.copyWith(
        offers: [
          for (final o in r.offers)
            if (o.outcome == OfferOutcome.pending &&
                o.expiresAt != null &&
                !o.expiresAt!.isAfter(t))
              _expire(row, r, o)
            else
              o,
        ],
      );
      if (r.offers.isNotEmpty &&
          !r.offers.any((o) => o.outcome == OfferOutcome.pending)) {
        r = r.copyWith(
          status: _next(r.status, 'round_ended'),
          roundEnded: true,
          candidates: [],
        );
      }
    }
    final deadline = r.searchDeadlineAt;
    if (r.committed &&
        (r.status == InstantStatus.choosing ||
            r.status == InstantStatus.searching) &&
        deadline != null &&
        !deadline.isAfter(t)) {
      r = r.copyWith(
        status: _next(r.status, 'no_match'),
        roundEnded: false,
        candidates: [],
        offers: [for (final o in r.offers) _withdraw(r, o)],
      );
    }
    if (!r.committed &&
        r.status == InstantStatus.choosing &&
        !row.lastActivityAt.add(_abandonAfter).isAfter(t)) {
      r = r.copyWith(
        status: InstantStatus.abandoned,
        candidates: [],
        offers: [],
      );
    }
    final ends = r.shootEndsAt;
    if (r.status == InstantStatus.inProgress &&
        ends != null &&
        !ends.isAfter(t)) {
      r = r.copyWith(status: InstantStatus.finished, finishedAt: ends);
    }
    final finished = r.finishedAt;
    if (r.status == InstantStatus.finished &&
        finished != null &&
        !finished.add(_autoComplete).isAfter(t)) {
      r = r.copyWith(
        status: InstantStatus.completed,
        completedAt: finished.add(_autoComplete),
      );
    }
    if (r != row.request) {
      row.request = r;
      _changed();
    }
    return r;
  }

  InstantOfferRow _expire(_Row row, InstantRequest r, InstantOfferRow o) {
    row.excluded.add(o.photographerId);
    _setOffer(
      o.photographerId,
      _offerIdOf(r.id, r.round, o.photographerId),
      OfferOutcome.expired,
    );
    return o.copyWith(outcome: OfferOutcome.expired);
  }

  InstantOfferRow _withdraw(InstantRequest r, InstantOfferRow o) {
    if (o.outcome != OfferOutcome.pending) return o;
    _setOffer(
      o.photographerId,
      _offerIdOf(r.id, r.round, o.photographerId),
      OfferOutcome.withdrawn,
    );
    return o.copyWith(outcome: OfferOutcome.withdrawn);
  }

  // ---- cancel table (domain quoteInstantCancel) ------------------------------

  InstantCancelQuote _quote(
    InstantRequest r,
    InstantCancelRule rule,
    int refundPercent,
  ) {
    final amount = r.paid ? r.amountVnd : 0;
    // Domain computeRefund: floored.
    final refund = amount * refundPercent ~/ 100;
    return InstantCancelQuote(
      rule: rule,
      refundPercent: refundPercent,
      refundVnd: refund,
      feeVnd: amount - refund,
      amountVnd: amount,
    );
  }

  static const _unpaid = InstantCancelQuote(rule: InstantCancelRule.unpaid);

  InstantCancelQuote _cancelQuote(InstantRequest r, bool byCustomer) {
    final t = now();
    if (!byCustomer) {
      if (!const {
        InstantStatus.assigned,
        InstantStatus.enRoute,
        InstantStatus.arrived,
      }.contains(r.status)) {
        throw const InstantError('conflict');
      }
      return r.paid
          ? _quote(r, InstantCancelRule.photographerCancel, 100)
          : _unpaid;
    }
    switch (r.status) {
      case InstantStatus.choosing ||
          InstantStatus.pendingPayment ||
          InstantStatus.searching ||
          InstantStatus.noMatch:
        return r.paid ? _quote(r, InstantCancelRule.fullRefund, 100) : _unpaid;
      case InstantStatus.assigned || InstantStatus.enRoute:
        if (!r.paid) return _unpaid;
        final free = r.freeCancelUntil;
        final late = r.lateDeadlineAt;
        if (free == null || t.isBefore(free)) {
          return _quote(r, InstantCancelRule.freeWindow, 100);
        }
        if (late != null && t.isAfter(late)) {
          return _quote(r, InstantCancelRule.photographerLate, 100);
        }
        return _quote(r, InstantCancelRule.enRoute, 80);
      case InstantStatus.arrived:
        return r.paid
            ? _quote(
                r,
                InstantCancelRule.arrived,
                100 - r.arrivedCancelPhotographerPercent,
              )
            : _unpaid;
      default:
        throw const InstantError('conflict');
    }
  }

  // ---- calls -------------------------------------------------------------------

  String _create({
    required String uid,
    required String packageCode,
    required InstantGenre genre,
    required double lat,
    required double lng,
    required String meetPointName,
    String? note,
  }) {
    if (uid != customerId) throw const InstantError('permission_denied');
    if (!config.enabled) throw const InstantError('not_eligible');
    for (final id in _rows.keys.toList()) {
      if (_settle(id).status.isActive && request(id)!.customerId == uid) {
        throw const InstantError('conflict');
      }
    }
    final pkg = config.packages.firstWhere(
      (p) => p.code == packageCode,
      orElse: () => throw const InstantError('invalid_argument'),
    );
    final id = 'req${_nextId++}';
    final row = _Row(
      InstantRequest(
        id: id,
        customerId: uid,
        customerName: customerName,
        status: InstantStatus.choosing,
        packageCode: pkg.code,
        durationMin: pkg.durationMin,
        photos: pkg.photos,
        genre: genre,
        note: note ?? '',
        meetPoint: InstantMeetPoint(lat: lat, lng: lng, name: meetPointName),
        areaLabel: 'Phường Bến Thành, Quận 1',
        amountVnd: pkg.priceVnd,
        earningVnd: config.earningOf(pkg.priceVnd),
        platformFeeBp: config.platformFeeBp,
        arrivedCancelPhotographerPercent:
            config.instantArrivedCancelPhotographerPercent,
      ),
      lastActivityAt: now(),
    );
    row.request = row.request.copyWith(candidates: _candidates(row));
    _rows[id] = row;
    _changed();
    return id;
  }

  InstantRequest _customerRequest(String id, String uid) {
    final r = _row(id).request;
    if (r.customerId != uid) throw const InstantError('permission_denied');
    return _settle(id);
  }

  void _nextCandidates(String id, String uid, List<String> skipped) {
    final r = _customerRequest(id, uid);
    if (r.status != InstantStatus.choosing &&
        r.status != InstantStatus.noMatch) {
      throw const InstantError('conflict');
    }
    final row = _row(id)..excluded.addAll(skipped);
    final reopened = r.status == InstantStatus.noMatch;
    final t = now();
    row.lastActivityAt = t;
    var next = r.copyWith(
      status: reopened ? _next(r.status, 'reopen') : r.status,
      round: r.round + 1,
      candidates: _candidates(row),
      offers: [],
      roundEnded: false,
      searchDeadlineAt: reopened ? t.add(_searchWindow) : r.searchDeadlineAt,
    );
    if (next.candidates.isEmpty && next.committed) {
      next = next.copyWith(status: _next(next.status, 'no_match'));
    }
    row.request = next;
    _changed();
  }

  InstantInviteResult _invite(
    String id,
    String uid,
    List<String> ids,
    List<String> skipped,
  ) {
    final r = _customerRequest(id, uid);
    if (r.status != InstantStatus.choosing) {
      throw const InstantError('conflict');
    }
    if (!ids.every((p) => r.candidates.any((c) => c.photographerId == p))) {
      throw const InstantError('not_eligible');
    }
    final row = _row(id)..excluded.addAll(skipped);
    final t = now();
    final expiresAt = t.add(_offerTtl);
    final invited = [
      for (final p in ids)
        if (!_busy(p)) p,
    ];
    final unavailable = [
      for (final p in ids)
        if (!invited.contains(p)) p,
    ];
    final rows = <InstantOfferRow>[];
    for (final p in ids) {
      final c = r.candidates.firstWhere((c) => c.photographerId == p);
      final sent = invited.contains(p);
      rows.add(
        InstantOfferRow(
          photographerId: p,
          name: c.name,
          avatarUrl: c.avatarUrl,
          tomatoPct: c.tomatoPct,
          reviewCount: c.reviewCount,
          etaMinutes: c.etaMinutes,
          outcome: sent ? OfferOutcome.pending : OfferOutcome.unavailable,
          expiresAt: sent ? expiresAt : null,
        ),
      );
      if (!sent) continue;
      (_offers[p] ??= []).add(
        InstantOffer(
          id: _offerIdOf(id, r.round, p),
          requestId: id,
          round: r.round,
          offeredAt: t,
          expiresAt: expiresAt,
          outcome: OfferOutcome.pending,
          packageCode: r.packageCode,
          durationMin: r.durationMin,
          photos: r.photos,
          genre: r.genre,
          areaLabel: r.areaLabel,
          distanceKm: c.distanceKm,
          etaMinutes: c.etaMinutes,
          earningVnd: r.earningVnd,
          note: r.note,
          invitedCount: invited.length,
        ),
      );
    }
    row.lastActivityAt = t;
    final common = r.copyWith(
      offers: rows,
      committed: true,
      searchDeadlineAt: t.add(_searchWindow),
    );
    row.request = invited.isEmpty
        ? common.copyWith(roundEnded: true, candidates: [])
        : common.copyWith(
            status: _next(r.status, 'invite'),
            roundEnded: false,
            invitedTotal: r.invitedTotal + invited.length,
            roundsWithInvites: r.roundsWithInvites + 1,
          );
    _changed();
    return InstantInvited(invited: invited, unavailable: unavailable);
  }

  InstantCancelQuote _cancel(String id, String uid, {required bool dryRun}) {
    final first = _row(id).request;
    final byCustomer = first.customerId == uid;
    if (!byCustomer && first.photographerId != uid) {
      throw const InstantError('permission_denied');
    }
    final r = _settle(id);
    if (!byCustomer && r.photographerId != uid) {
      throw const InstantError('permission_denied');
    }
    final q = _cancelQuote(r, byCustomer);
    if (dryRun) return q;
    final t = now();
    final recorded = r.copyWith(
      cancelRule: q.rule,
      refundPercent: q.refundPercent,
      feeVnd: q.feeVnd,
      cancelledAt: t,
    );
    _tracks.remove(id);
    final row = _row(id);
    if (byCustomer) {
      row.request = recorded.copyWith(
        status: _next(r.status, 'customer_cancel'),
        cancelledBy: InstantParticipant.customer,
        candidates: [],
        offers: [for (final o in r.offers) _withdraw(r, o)],
      );
    } else {
      row.excluded.add(uid);
      row.request = recorded.copyWith(
        status: _next(r.status, 'photographer_cancel'),
        cancelledBy: InstantParticipant.photographer,
        photographerId: null,
        photographer: null,
        chatId: null,
        etaMinutes: null,
        assignedAt: null,
        freeCancelUntil: null,
        lateDeadlineAt: null,
        startedRouteAt: null,
        arrivedAt: null,
        candidates: [],
        offers: [],
        roundEnded: true,
        searchDeadlineAt: t.add(_searchWindow),
      );
    }
    _changed();
    return q;
  }

  void _confirmComplete(String id, String uid) {
    final r = _customerRequest(id, uid);
    if (r.status == InstantStatus.completed) return;
    final t = now();
    _row(id).request = r.copyWith(
      status: _next(r.status, 'complete'),
      completedAt: t,
      finishedAt: r.finishedAt ?? t,
    );
    _changed();
  }

  void _tick(String id, String uid) {
    final r = _row(id).request;
    final allowed =
        r.customerId == uid ||
        r.photographerId == uid ||
        r.offers.any(
          (o) =>
              o.photographerId == uid && o.outcome != OfferOutcome.unavailable,
        );
    if (!allowed) throw const InstantError('permission_denied');
    _settle(id);
  }

  String _answer(String uid, String offerId, {required bool accept}) {
    final offers = _offers[uid] ?? const <InstantOffer>[];
    final first = offers.where((o) => o.id == offerId).firstOrNull;
    if (first == null) throw const InstantError('not_found');
    final r = _settle(first.requestId);
    final offer = _offers[uid]!.firstWhere((o) => o.id == offerId);
    final t = now();
    if (offer.outcome == OfferOutcome.accepted && r.photographerId == uid) {
      return r.id;
    }
    if (offer.outcome == OfferOutcome.expired ||
        (offer.outcome == OfferOutcome.pending &&
            !offer.expiresAt.isAfter(t))) {
      throw const InstantError('offer_expired');
    }
    if (offer.outcome == OfferOutcome.withdrawn) {
      throw InstantError(
        r.photographerId == null ? 'offer_expired' : 'already_assigned',
      );
    }
    if (offer.outcome != OfferOutcome.pending) {
      throw const InstantError('conflict');
    }
    final row = _row(r.id);
    if (!accept) {
      _setOffer(uid, offerId, OfferOutcome.declined);
      row.excluded.add(uid);
      var next = r.copyWith(
        offers: [
          for (final o in r.offers)
            o.photographerId == uid
                ? o.copyWith(outcome: OfferOutcome.declined)
                : o,
        ],
      );
      if (!next.offers.any((o) => o.outcome == OfferOutcome.pending)) {
        next = next.copyWith(
          status: _next(next.status, 'round_ended'),
          roundEnded: true,
          candidates: [],
        );
      }
      row.request = next;
      _changed();
      return r.id;
    }
    if (r.status != InstantStatus.searching || _busy(uid)) {
      throw const InstantError('already_assigned');
    }
    for (final o in r.offers) {
      if (o.photographerId != uid) _withdraw(r, o);
    }
    _setOffer(uid, offerId, OfferOutcome.accepted);
    // The winner's other pending offers go (one job at a time).
    for (final o in List.of(_offers[uid]!)) {
      if (o.id != offerId && o.outcome == OfferOutcome.pending) {
        _setOffer(uid, o.id, OfferOutcome.withdrawn);
      }
    }
    final c = pool.firstWhere((c) => c.photographerId == uid);
    row.request = r.copyWith(
      status: _next(r.status, 'accept'),
      candidates: [],
      offers: [],
      roundEnded: false,
      searchDeadlineAt: null,
      photographerId: uid,
      photographer: InstantParty(
        id: uid,
        name: c.name,
        avatarUrl: c.avatarUrl,
        verified: c.verified,
        tomatoPct: c.tomatoPct,
        reviewCount: c.reviewCount,
        completedCount: c.completedCount,
      ),
      chatId: 'chat_${r.customerId}_$uid',
      etaMinutes: offer.etaMinutes,
      assignedAt: t,
      freeCancelUntil: t.add(_freeCancel),
      lateDeadlineAt: t.add(Duration(minutes: offer.etaMinutes) + _lateGrace),
      startedRouteAt: null,
      arrivedAt: null,
      cancelledAt: null,
      cancelledBy: null,
      cancelRule: null,
      refundPercent: null,
      feeVnd: null,
    );
    _changed();
    return r.id;
  }

  InstantStatus _updateJob(
    String id,
    String uid,
    InstantJobAction action,
    InstantLocation? location,
    bool force,
  ) {
    if (_row(id).request.photographerId != uid) {
      throw const InstantError('permission_denied');
    }
    final r = _settle(id);
    final t = now();
    final InstantRequest next;
    switch (action) {
      case InstantJobAction.startRoute:
        final status = _next(r.status, 'start_route');
        if (location == null) throw const InstantError('invalid_argument');
        _tracks[id] = InstantTrack(
          lat: location.lat,
          lng: location.lng,
          accuracyM: location.accuracyM,
          at: t,
        );
        next = r.copyWith(status: status, startedRouteAt: t);
      case InstantJobAction.arrive:
        final status = _next(r.status, 'arrive');
        if (location == null) throw const InstantError('invalid_argument');
        final metres =
            haversineKm(
              location.lat,
              location.lng,
              r.meetPoint.lat,
              r.meetPoint.lng,
            ) *
            1000;
        final near = metres <= _arriveRadiusM;
        if (!near && !(force && location.accuracyM > _poorAccuracyM)) {
          throw const InstantError('not_eligible');
        }
        _tracks.remove(id);
        next = r.copyWith(status: status, arrivedAt: t);
      case InstantJobAction.start:
        next = r.copyWith(
          status: _next(r.status, 'start'),
          startedAt: t,
          shootEndsAt: t.add(Duration(minutes: r.durationMin)),
        );
      case InstantJobAction.finish:
        next = r.copyWith(status: _next(r.status, 'finish'), finishedAt: t);
      case InstantJobAction.noShow:
        final arrivedAt = r.arrivedAt;
        if (r.status != InstantStatus.arrived || arrivedAt == null) {
          throw const InstantError('conflict');
        }
        if (t.isBefore(arrivedAt.add(_noShowWait))) {
          throw const InstantError('deadline_passed');
        }
        final q = r.paid
            ? _quote(r, InstantCancelRule.noShow, 50)
            : const InstantCancelQuote(rule: InstantCancelRule.noShow);
        _tracks.remove(id);
        next = r.copyWith(
          status: _next(r.status, 'no_show'),
          cancelRule: q.rule,
          refundPercent: q.refundPercent,
          feeVnd: q.feeVnd,
          cancelledAt: t,
        );
    }
    _row(id).request = next;
    _changed();
    return next.status;
  }

  void _shareTrack(String id, String uid, InstantLocation at) {
    final r = _row(id).request;
    if (r.photographerId != uid || r.status != InstantStatus.enRoute) {
      throw const InstantError('permission_denied');
    }
    _tracks[id] = InstantTrack(
      lat: at.lat,
      lng: at.lng,
      accuracyM: at.accuracyM,
      at: now(),
    );
    _changed();
  }

  /// What [uid] may read of [id]: the customer everything, the assigned
  /// photographer their job, anyone else nothing (the rules deny it).
  InstantRequest? _readable(String id, String uid) {
    final r = _rows[id]?.request;
    if (r == null) return null;
    if (r.customerId == uid || r.photographerId == uid) return r;
    return null;
  }

  InstantRequest? _activeJobOf(String uid) => _rows.values
      .map((row) => row.request)
      .where((r) => r.photographerId == uid && r.status.isActive)
      .firstOrNull;
}

/// The callables and listeners as signed-in [uid] sees them.
class _SimRepository implements InstantRepository {
  _SimRepository(this.sim, this.uid);

  final InstantSimulator sim;
  final String uid;

  /// Every call answers asynchronously, like a callable.
  Future<T> _call<T>(T Function() body) => Future.microtask(body);

  @override
  Future<InstantConfig> config() => _call(() => sim.config);

  @override
  Future<String> createRequest({
    required String packageCode,
    required InstantGenre genre,
    required double lat,
    required double lng,
    required String meetPointName,
    String? note,
  }) => _call(
    () => sim._create(
      uid: uid,
      packageCode: packageCode,
      genre: genre,
      lat: lat,
      lng: lng,
      meetPointName: meetPointName,
      note: note,
    ),
  );

  @override
  Future<void> nextCandidates(
    String requestId, {
    List<String> skipped = const [],
  }) => _call(() => sim._nextCandidates(requestId, uid, skipped));

  @override
  Future<InstantInviteResult> invite(
    String requestId, {
    required List<String> photographerIds,
    required List<String> skipped,
    required int expectedAmountVnd,
    PayMethod? payMethod,
  }) => _call(() => sim._invite(requestId, uid, photographerIds, skipped));

  @override
  Future<void> confirmComplete(String requestId) =>
      _call(() => sim._confirmComplete(requestId, uid));

  @override
  Future<String?> myActiveRequestId() => _call(
    () => sim._rows.values
        .map((row) => row.request)
        .where((r) => r.customerId == uid && r.status.isActive)
        .firstOrNull
        ?.id,
  );

  @override
  Stream<InstantTrack?> watchTrack(String requestId) =>
      sim._watch(() => sim._tracks[requestId]);

  @override
  Stream<InstantRequest?> watchRequest(String requestId) =>
      sim._watch(() => sim._readable(requestId, uid));

  @override
  Future<InstantCancelQuote> cancel(String requestId, {required bool dryRun}) =>
      _call(() => sim._cancel(requestId, uid, dryRun: dryRun));

  @override
  Future<void> tick(String requestId) => _call(() => sim._tick(requestId, uid));

  @override
  Stream<LiveShutterState?> watchPresence() => sim._watch(
    () => LiveShutterState(
      online: true,
      helpReady: true,
      priceListVersion: sim.config.priceListVersion,
      activeRequestId: sim._activeJobOf(uid)?.id,
    ),
  );

  @override
  Future<List<LiveShutterReason>> setLiveShutter({
    required bool online,
    bool dryRun = false,
    InstantLocation? location,
  }) => _call(() => const <LiveShutterReason>[]);

  @override
  Future<void> saveSettings({int? acceptPriceListVersion, bool? helpReady}) =>
      _call(() {});

  @override
  Future<void> heartbeat({
    required double lat,
    required double lng,
    required double accuracyM,
  }) => _call(() {});

  @override
  Stream<List<InstantOffer>> watchPendingOffers() => sim._watch(
    () => [
      for (final o in sim._offers[uid] ?? const <InstantOffer>[])
        if (o.outcome == OfferOutcome.pending) o,
    ]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt)),
  );

  @override
  Future<String> answerOffer(String offerId, {required bool accept}) =>
      _call(() => sim._answer(uid, offerId, accept: accept));

  @override
  Future<InstantStatus> updateJob(
    String requestId,
    InstantJobAction action, {
    InstantLocation? location,
    bool force = false,
  }) => _call(() => sim._updateJob(requestId, uid, action, location, force));

  @override
  Future<void> shareTrack(
    String requestId, {
    required double lat,
    required double lng,
    required double accuracyM,
    double? heading,
  }) => _call(
    () => sim._shareTrack(requestId, uid, (
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
    )),
  );

  /// #140 never shares the customer's number (unpaid).
  @override
  Stream<BookingContactSnapshot?> watchCustomerContact(String requestId) =>
      Stream.value(null);

  @override
  Stream<InstantRequest?> watchMyActiveJob() =>
      sim._watch(() => sim._activeJobOf(uid));
}
