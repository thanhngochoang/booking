// Decision 10: the photographer's presence heartbeat, foreground only.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant_work/live_shutter_controller.dart';

/// Keeps the heartbeat while a photographer is online and the app is
/// foregrounded: a low-accuracy fix (`currentApproxLocation`) every [sample];
/// writes at once on resume, then when the position moved more than 300 m
/// or [maxSilence] passed since the last write; never two writes closer than
/// 60 s (the rules refuse them). No background work: a backgrounded app stops
/// here and the server stops suggesting it 30 minutes after the last write.
class LiveShutterHeartbeat extends ConsumerStatefulWidget {
  const LiveShutterHeartbeat({
    super.key,
    required this.child,
    this.sample = const Duration(seconds: 60),
    this.maxSilence = const Duration(minutes: 5),
  });

  final Widget child;
  final Duration sample;
  final Duration maxSilence;

  @override
  ConsumerState<LiveShutterHeartbeat> createState() =>
      _LiveShutterHeartbeatState();
}

/// The rules' minimum gap between two heartbeats.
const _minGap = Duration(seconds: 60);

/// Spec §9: "khi đi > 300 m".
const _moveKm = 0.3;

class _LiveShutterHeartbeatState extends ConsumerState<LiveShutterHeartbeat>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _online = false;
  bool _foreground = true;
  bool _sampling = false;

  /// The last write, ours or the server's (`setLiveShutter` writes one too).
  DateTime? _lastWriteAt;
  DateTime? _serverHeartbeatAt;
  ({double lat, double lng})? _lastPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    ref.listenManual<AsyncValue<LiveShutterState?>>(livePresenceProvider, (
      _,
      next,
    ) {
      if (next.hasValue) _onPresence(next.value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_foreground) return;
        _foreground = true;
        _start();
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _foreground = false;
        _stop();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onPresence(LiveShutterState? p) {
    _serverHeartbeatAt = p?.heartbeatAt;
    final was = _online;
    _online = p?.online ?? false;
    if (_online && !was) {
      _start();
    } else if (!_online && was) {
      _stop();
    }
  }

  void _start() {
    if (!_online || !_foreground) return;
    _timer?.cancel();
    _timer = Timer.periodic(widget.sample, (_) => _tick());
    unawaited(_tick(resume: true));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  DateTime? get _last {
    final a = _lastWriteAt;
    final b = _serverHeartbeatAt;
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  bool _tooSoon(DateTime now) {
    final last = _last;
    return last != null && now.difference(last) < _minGap;
  }

  Future<void> _tick({bool resume = false}) async {
    if (_sampling || !_online || !_foreground) return;
    final clock = ref.read(clockProvider);
    if (_tooSoon(clock())) return;
    _sampling = true;
    final ApproxLocation? fix;
    try {
      fix = await ref.read(locationRepositoryProvider).currentApproxLocation();
    } finally {
      _sampling = false;
    }
    if (!mounted || fix == null || !_online || !_foreground) return;
    final now = clock();
    if (_tooSoon(now)) return;
    final last = _last;
    final prev = _lastPos;
    final moved =
        prev != null &&
        haversineKm(prev.lat, prev.lng, fix.lat, fix.lng) > _moveKm;
    final silent = last == null || now.difference(last) >= widget.maxSilence;
    if (!resume && !moved && !silent) return;
    _lastWriteAt = now;
    _lastPos = (lat: fix.lat, lng: fix.lng);
    // Not awaited: a write made offline completes only once back online.
    unawaited(_write(fix.lat, fix.lng));
  }

  Future<void> _write(double lat, double lng) async {
    try {
      await ref
          .read(instantRepositoryProvider)
          .heartbeat(lat: lat, lng: lng, accuracyM: kApproxFixAccuracyM);
    } on Object catch (e) {
      // A refused or failed heartbeat is retried by the next sample.
      debugPrint('instant heartbeat failed: ${instantErrorCodeOf(e)}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
