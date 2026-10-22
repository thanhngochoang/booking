// lib/data/instant/firestore_instant_mapping.dart
//
// Firestore documents and callable answers → Chụp ngay models. Mirrors the
// server mappers (`firebase/functions/src/infra/instant_firestore.ts`): a
// request whose status or genre is unknown reads as absent, an offer row
// with an unknown outcome reads as expired, Timestamps become UTC.
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

DateTime? _date(Object? v) => switch (v) {
  Timestamp() => v.toDate().toUtc(),
  DateTime() => v.toUtc(),
  _ => null,
};

String _str(Object? v) => v is String ? v : '';
String? _code(Object? v) => v is String ? v : null;
String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;
int _int(Object? v, [int fallback = 0]) =>
    v is num && v.isFinite ? v.round() : fallback;
int? _intOrNull(Object? v) => v is num && v.isFinite ? v.round() : null;
double _dbl(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;
double? _dblOrNull(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
bool _bool(Object? v) => v == true;
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];
List<String> _strings(Object? v) => _list(v).whereType<String>().toList();

InstantCandidate _candidate(Object? v) {
  final d = _map(v);
  return InstantCandidate(
    photographerId: _str(d['photographerId']),
    name: _str(d['name']),
    avatarUrl: _strOrNull(d['avatarUrl']),
    verified: _bool(d['verified']),
    tomatoPct: _int(d['tomatoPct']),
    reviewCount: _int(d['reviewCount']),
    completedCount: _int(d['completedCount']),
    distanceKm: _dbl(d['distanceKm']),
    etaMinutes: _int(d['etaMinutes'], 1),
    photos: _strings(d['photos']),
    reasons: [
      for (final r in _list(d['reasons']))
        if (_map(r) case {
          'code': 'genre' || 'distance',
          'text': final String text,
        })
          text,
    ],
  );
}

InstantOfferRow _offerRow(Object? v) {
  final d = _map(v);
  return InstantOfferRow(
    photographerId: _str(d['photographerId']),
    name: _str(d['name']),
    avatarUrl: _strOrNull(d['avatarUrl']),
    tomatoPct: _int(d['tomatoPct']),
    reviewCount: _int(d['reviewCount']),
    etaMinutes: _int(d['etaMinutes'], 1),
    outcome: OfferOutcome.fromCode(_code(d['outcome'])),
    expiresAt: _date(d['expiresAt']),
  );
}

InstantParty? _party(Object? v) {
  if (v is! Map) return null;
  final d = _map(v);
  return InstantParty(
    id: _str(d['id']),
    name: _str(d['name']),
    avatarUrl: _strOrNull(d['avatarUrl']),
    verified: _bool(d['verified']),
    tomatoPct: _int(d['tomatoPct']),
    reviewCount: _int(d['reviewCount']),
    completedCount: _int(d['completedCount']),
  );
}

/// `instant_requests/{id}` → request; null when missing or when its status
/// or genre is unknown to this build (never act on a request we cannot read).
InstantRequest? instantRequestFromFirestore(
  String id,
  Map<String, dynamic>? d,
) {
  if (d == null) return null;
  final status = InstantStatus.fromCode(_code(d['status']));
  final genre = InstantGenre.fromCode(_code(d['genre']));
  if (status == null || genre == null) return null;
  final meet = _map(d['meetPoint']);
  return InstantRequest(
    id: id,
    customerId: _str(d['customerId']),
    customerName: _str(d['customerName']),
    customerAvatarUrl: _strOrNull(d['customerAvatarUrl']),
    status: status,
    packageCode: _str(d['packageCode']),
    durationMin: _int(d['durationMin']),
    photos: _int(d['photos']),
    genre: genre,
    note: _str(d['note']),
    meetPoint: InstantMeetPoint(
      lat: _dbl(meet['lat']),
      lng: _dbl(meet['lng']),
      name: _str(meet['name']),
    ),
    areaLabel: _str(d['areaLabel']),
    amountVnd: _int(d['amountVnd']),
    earningVnd: _int(d['earningVnd']),
    platformFeeBp: _int(d['platformFeeBp']),
    arrivedCancelPhotographerPercent: _int(
      d['arrivedCancelPhotographerPercent'],
    ),
    payMethod: PayMethod.fromCode(_code(d['payMethod'])),
    paid: _date(d['paidAt']) != null,
    committed: _date(d['committedAt']) != null,
    round: _int(d['round'], 1),
    invitedTotal: _int(d['invitedTotal']),
    roundsWithInvites: _int(d['roundsWithInvites']),
    candidates: _list(d['candidates']).map(_candidate).toList(),
    offers: _list(d['offers']).map(_offerRow).toList(),
    roundEnded: _bool(d['roundEnded']),
    photographerId: _strOrNull(d['photographerId']),
    photographer: _party(d['photographer']),
    chatId: _strOrNull(d['chatId']),
    etaMinutes: _intOrNull(d['etaMinutes']),
    assignedAt: _date(d['assignedAt']),
    freeCancelUntil: _date(d['freeCancelUntil']),
    lateDeadlineAt: _date(d['lateDeadlineAt']),
    startedRouteAt: _date(d['startedRouteAt']),
    arrivedAt: _date(d['arrivedAt']),
    startedAt: _date(d['startedAt']),
    shootEndsAt: _date(d['shootEndsAt']),
    finishedAt: _date(d['finishedAt']),
    completedAt: _date(d['completedAt']),
    cancelledAt: _date(d['cancelledAt']),
    cancelledBy: InstantParticipant.fromCode(_code(d['cancelledBy'])),
    cancelRule: InstantCancelRule.fromCode(_code(d['cancelRule'])),
    refundPercent: _intOrNull(d['refundPercent']),
    feeVnd: _intOrNull(d['feeVnd']),
    searchDeadlineAt: _date(d['searchDeadlineAt']),
    paymentDeadlineAt: _date(d['paymentDeadlineAt']),
  );
}

/// `instant_offers/{uid}/offers/{id}` → offer; null when missing, without
/// its instants, or of an unknown genre (as on the server). Its outcome
/// falls back to expired.
InstantOffer? instantOfferFromFirestore(String id, Map<String, dynamic>? d) {
  if (d == null) return null;
  final offeredAt = _date(d['offeredAt']);
  final expiresAt = _date(d['expiresAt']);
  final genre = InstantGenre.fromCode(_code(d['genre']));
  if (offeredAt == null || expiresAt == null || genre == null) return null;
  return InstantOffer(
    id: id,
    requestId: _str(d['requestId']),
    round: _int(d['round'], 1),
    offeredAt: offeredAt,
    expiresAt: expiresAt,
    outcome: OfferOutcome.fromCode(_code(d['outcome'])),
    packageCode: _str(d['packageCode']),
    durationMin: _int(d['durationMin']),
    photos: _int(d['photos']),
    genre: genre,
    areaLabel: _str(d['areaLabel']),
    distanceKm: _dbl(d['distanceKm']),
    etaMinutes: _int(d['etaMinutes'], 1),
    earningVnd: _int(d['earningVnd']),
    note: _str(d['note']),
    invitedCount: _int(d['invitedCount'], 1),
  );
}

/// `instant_presence/{uid}` → the owner's Live Shutter state; null when missing.
LiveShutterState? liveShutterStateFromFirestore(Map<String, dynamic>? d) {
  if (d == null) return null;
  return LiveShutterState(
    online: _bool(d['online']),
    helpReady: _bool(d['helpReady']),
    priceListVersion: _intOrNull(d['priceListVersion']),
    heartbeatAt: _date(d['heartbeatAt']),
    activeRequestId: _strOrNull(d['activeRequestId']),
  );
}

/// An integer in [min]..[max] (a Firestore double like 1.0 counts, as
/// `Number.isInteger` does on the server).
int? _intIn(Object? v, int min, [int max = 9007199254740991]) {
  if (v is! num || !v.isFinite || v != v.roundToDouble()) return null;
  final i = v.toInt();
  return i >= min && i <= max ? i : null;
}

bool _numIn(Object? v, double min, double max) =>
    v is num && v.isFinite && v >= min && v <= max;

bool _text(Object? v) => v is String && v.trim().isNotEmpty;

/// `instant_config/current` → config, with the server's `parseInstantConfig`
/// checks: null (Chụp ngay unavailable, `not_eligible`) when the document is
/// missing or anything in it is missing, malformed or out of range. There is
/// no default in code: the seed holds the defaults.
InstantConfig? instantConfigFromFirestore(Map<String, dynamic>? d) {
  if (d == null) return null;
  final enabled = d['enabled'];
  final version = _intIn(d['priceListVersion'], 1);
  final feeBp = _intIn(d['platformFeeBp'], 0, 10000);
  final split = _intIn(d['instantArrivedCancelPhotographerPercent'], 0, 100);
  final rawPackages = d['packages'];
  final rawCities = d['cities'];
  final rawAreas = d['areas'];
  if (enabled is! bool || version == null || feeBp == null || split == null) {
    return null;
  }
  if (rawPackages is! List || rawPackages.isEmpty) return null;
  if (rawCities is! List || rawCities.isEmpty) return null;
  if (rawAreas is! List || !rawAreas.every(_validArea)) return null;
  final packages = rawPackages.map(_package).toList();
  if (packages.contains(null)) return null;
  final cities = rawCities.map(_city).toList();
  if (cities.contains(null)) return null;
  if (packages.map((p) => p!.code).toSet().length != packages.length) {
    return null;
  }
  if (cities.map((c) => c!.id).toSet().length != cities.length) return null;
  return InstantConfig(
    enabled: enabled,
    priceListVersion: version,
    platformFeeBp: feeBp,
    instantArrivedCancelPhotographerPercent: split,
    packages: [for (final p in packages) p!],
    cityNames: [for (final c in cities) c!.name],
  );
}

InstantPackage? _package(Object? v) {
  if (v is! Map) return null;
  final d = _map(v);
  final code = d['code'];
  final durationMin = _intIn(d['durationMin'], 1);
  final photos = _intIn(d['photos'], 1);
  final priceVnd = _intIn(d['priceVnd'], 1);
  if (!_text(code) ||
      durationMin == null ||
      photos == null ||
      priceVnd == null) {
    return null;
  }
  return InstantPackage(
    code: code as String,
    durationMin: durationMin,
    photos: photos,
    priceVnd: priceVnd,
  );
}

({String id, String name})? _city(Object? v) {
  if (v is! Map) return null;
  final d = _map(v);
  final id = d['id'];
  final name = d['name'];
  final south = d['south'];
  final west = d['west'];
  final north = d['north'];
  final east = d['east'];
  if (!_text(id) || !_text(name) || _intIn(d['surgeBp'], 1) == null) {
    return null;
  }
  if (!_numIn(south, -90, 90) ||
      !_numIn(north, -90, 90) ||
      !_numIn(west, -180, 180) ||
      !_numIn(east, -180, 180)) {
    return null;
  }
  if ((south as num) >= (north as num) || (west as num) >= (east as num)) {
    return null;
  }
  return (id: id as String, name: name as String);
}

bool _validArea(Object? v) {
  if (v is! Map) return false;
  final d = _map(v);
  return _text(d['name']) &&
      _numIn(d['lat'], -90, 90) &&
      _numIn(d['lng'], -180, 180);
}

/// `instant_tracks/{requestId}` → last position; null when missing or
/// without a position.
InstantTrack? instantTrackFromFirestore(Map<String, dynamic>? d) {
  if (d == null) return null;
  final lat = _dblOrNull(d['lat']);
  final lng = _dblOrNull(d['lng']);
  final at = _date(d['at']);
  if (lat == null || lng == null || at == null) return null;
  return InstantTrack(
    lat: lat,
    lng: lng,
    accuracyM: _dbl(d['accuracyM']),
    at: at,
  );
}

/// `cancelInstantRequest`'s `{rule, refundPercent, refundVnd, feeVnd, amountVnd, status}`.
InstantCancelQuote instantCancelQuoteFromJson(Object? data) {
  final d = _map(data);
  return InstantCancelQuote(
    rule: InstantCancelRule.fromCode(_code(d['rule'])),
    refundPercent: _int(d['refundPercent']),
    refundVnd: _int(d['refundVnd']),
    feeVnd: _int(d['feeVnd']),
    amountVnd: _int(d['amountVnd']),
  );
}

/// `inviteInstant`'s answer; a kind this build does not know is an
/// `unknown` error rather than a silent success.
InstantInviteResult instantInviteResultFromJson(Object? data) {
  final d = _map(data);
  return switch (d['kind']) {
    'invited' => InstantInvited(
      invited: _strings(d['invited']),
      unavailable: _strings(d['unavailable']),
    ),
    'price_changed' => InstantPriceChanged(amountVnd: _int(d['amountVnd'])),
    _ => throw const InstantError('unknown'),
  };
}
