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

/// Keeps the heartbeat while a photographer is online and the app is
/// foregrounded: a low-power fix (`currentFix`, with its real accuracy) every
/// [sample]; writes at once on resume, then when the position moved more than
/// 300 m or [maxSilence] passed since the last write; never two writes closer
/// than 60 s (the rules refuse them). No background work: a backgrounded app
/// stops here and the server stops suggesting it 30 minutes after the last
/// write. With [enabled] false (Chụp ngay off, not a photographer) nothing is
/// listened to; the widget stays in the tree so the child keeps its place.
class LiveShutterHeartbeat extends ConsumerStatefulWidget {
  const LiveShutterHeartbeat({
    super.key,
    required this.child,
    this.enabled = true,
    this.sample = const Duration(seconds: 60),
    this.maxSilence = const Duration(minutes: 5),
  });

  final Widget child;
  final bool enabled;
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
  ProviderSubscription<AsyncValue<LiveShutterState?>>? _presence;
  Timer? _timer;
  bool _online = false;
  bool _foreground = true;
  bool _sampling = false;
  bool _writing = false;

  /// The last successful write of ours; the server's own write
  /// (`setLiveShutter`) arrives as [_serverHeartbeatAt].
  DateTime? _lastWriteAt;
  DateTime? _serverHeartbeatAt;

  /// Where the last move is measured from: the last written position, or the
  /// first fix after switching on (the server wrote that one).
  ({double lat, double lng})? _lastPos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (widget.enabled) _listen();
  }

  @override
  void didUpdateWidget(LiveShutterHeartbeat old) {
    super.didUpdateWidget(old);
    if (widget.enabled == old.enabled) return;
    if (widget.enabled) {
      _listen();
    } else {
      _presence?.close();
      _presence = null;
      _online = false;
      _stop();
    }
  }

  void _listen() {
    _presence = ref.listenManual<AsyncValue<LiveShutterState?>>(
      livePresenceProvider,
      (_, next) {
        if (next.hasValue) _onPresence(next.value);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presence?.close();
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
      _lastPos = null;
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

  bool get _active => mounted && _online && _foreground;

  Future<void> _tick({bool resume = false}) async {
    if (_sampling || _writing || !_active) return;
    final clock = ref.read(clockProvider);
    // Too soon to write; still take a fix when there is no baseline yet.
    if (_tooSoon(clock()) && _lastPos != null) return;
    _sampling = true;
    LocationFix? fix;
    try {
      fix = await ref.read(locationRepositoryProvider).currentFix();
    } on Object catch (e) {
      // Errors as well: a timer callback must not leak an uncaught error.
      debugPrint('instant heartbeat: no fix (${e.runtimeType})');
    } finally {
      _sampling = false;
    }
    if (fix == null || !_active) return;
    final prev = _lastPos;
    _lastPos ??= (lat: fix.lat, lng: fix.lng);
    final now = clock();
    if (_tooSoon(now)) return;
    final last = _last;
    final moved =
        prev != null &&
        haversineKm(prev.lat, prev.lng, fix.lat, fix.lng) > _moveKm;
    final silent = last == null || now.difference(last) >= widget.maxSilence;
    if (!resume && !moved && !silent) return;
    // Not awaited by the timer: a write made offline completes only once
    // back online; until then no other write starts.
    unawaited(_write(fix, now));
  }

  Future<void> _write(LocationFix fix, DateTime at) async {
    _writing = true;
    try {
      await ref
          .read(instantRepositoryProvider)
          .heartbeat(lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM);
      _lastWriteAt = at;
      _lastPos = (lat: fix.lat, lng: fix.lng);
    } on Object catch (e) {
      // Not recorded as written: the next sample tries again.
      debugPrint('instant heartbeat failed: ${instantErrorCodeOf(e)}');
    } finally {
      _writing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
