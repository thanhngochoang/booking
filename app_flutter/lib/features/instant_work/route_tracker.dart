// Decision 11: the photographer's position while en route (S14.03), foreground only.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';

/// Starts the periodic sampling; injected so tests drive the ticks by hand.
typedef TrackTimerFactory = Timer Function(
  Duration every,
  void Function() onTick,
);

Timer _periodic(Duration every, void Function() onTick) =>
    Timer.periodic(every, (_) => onTick());

/// Spec §9 / mock S14.03 caption: "ghi khi đi ≥ 25 m hoặc sau 60 giây".
const _moveM = 25.0;
const _maxSilence = Duration(seconds: 60);

/// The rules refuse a track point within 15 s of the last one by the
/// server's clock; one more second covers the client/server jitter.
const kTrackMinGap = Duration(seconds: 16);

/// Fix every 15 s while en route and the screen is visible; writes when moved
/// ≥ 25 m or 60 s passed. A low-power fix (`currentFix()`, with its real
/// accuracy): the GPS-grade one is only for the arrival check. Never two
/// writes within 16 s of each other by this clock (the rules' 15 s plus
/// jitter); a write the server still
/// refuses (clock jitter, the request just left `en_route`) is not counted and
/// the next fix tries again. Nothing is kept beyond the last written point
/// (spec §9: no point history).
class RouteTracker {
  RouteTracker({
    required this._location,
    required this._repo,
    required this._requestId,
    required this._now,
    this._every = const Duration(seconds: 15),
    TrackTimerFactory timer = _periodic,
    this.onFix,
    this.onNoFix,
  }) : _timerFactory = timer;

  final LocationRepository _location;
  final InstantRepository _repo;
  final String _requestId;
  final DateTime Function() _now;
  final Duration _every;
  final TrackTimerFactory _timerFactory;

  /// Every fix taken, written or not (the screen's distance to the meet point).
  final void Function(LocationFix fix)? onFix;

  /// A sample brought no fix (permission revoked, location off, no signal).
  final void Function()? onNoFix;

  Timer? _timer;
  bool _sampling = false;
  ({double lat, double lng})? _lastPos;
  DateTime? _lastWriteAt;

  bool get running => _timer != null;

  /// Samples at once, then every [every]. [sent] is a point the server
  /// already wrote (with `start_route`): it counts as the last write now.
  void start({LocationFix? sent}) {
    if (sent != null) {
      _lastPos = (lat: sent.lat, lng: sent.lng);
      _lastWriteAt = _now();
    }
    if (running) return;
    _timer = _timerFactory(_every, () => unawaited(_sample()));
    unawaited(_sample());
  }

  /// Stops sampling (background, arrival, any end). The last written point
  /// is kept, so a quick restart never writes within 15 s.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sample() async {
    if (!running || _sampling) return;
    _sampling = true;
    try {
      final fix = await _location.currentFix();
      if (!running) return;
      if (fix == null) {
        onNoFix?.call();
        return;
      }
      onFix?.call(fix);
      if (!_due(fix)) return;
      final at = _now();
      await _repo.shareTrack(
        _requestId,
        lat: fix.lat,
        lng: fix.lng,
        accuracyM: fix.accuracyM,
      );
      _lastPos = (lat: fix.lat, lng: fix.lng);
      _lastWriteAt = at;
    } on Object catch (e) {
      // Refused or offline: the next fix tries again.
      debugPrint('instant track not written: ${instantErrorCodeOf(e)}');
    } finally {
      _sampling = false;
    }
  }

  bool _due(LocationFix fix) {
    final last = _lastPos;
    final at = _lastWriteAt;
    if (last == null || at == null) return true;
    final since = _now().difference(at);
    if (since < kTrackMinGap) return false;
    if (since >= _maxSilence) return true;
    return haversineKm(last.lat, last.lng, fix.lat, fix.lng) * 1000 >= _moveM;
  }
}
