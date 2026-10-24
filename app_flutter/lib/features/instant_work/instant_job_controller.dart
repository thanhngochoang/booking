// S14.03: the assigned photographer's job — start of the route, the track
// while en route (Decision 11), the arrival check and the job steps. Every
// state change is a callable (`updateInstantJob`); the only direct write is
// the track point, through [RouteTracker].
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant_work/route_tracker.dart';

/// Domain `INSTANT.ARRIVE_RADIUS_M`: "Đã đến" within 200 m of the meet point.
const kArriveRadiusM = 200.0;

/// Domain `INSTANT.POOR_ACCURACY_M`: a fix worse than this may force arrival.
const kPoorAccuracyM = 100.0;

/// While `assigned`, a `start_route` that failed (or got no fix) is tried
/// again after this long, on the track's cadence.
const kRouteRetry = Duration(seconds: 16);

/// Domain `INSTANT.NO_SHOW_WAIT_MIN`.
const kNoShowWait = Duration(minutes: 15);

/// Metres from [fix] to the meet point of [r] (client estimate).
double metresToMeetPoint(InstantRequest r, LocationFix fix) =>
    haversineKm(fix.lat, fix.lng, r.meetPoint.lat, r.meetPoint.lng) * 1000;

/// What "Đã đến" does with the latest fix (before any call).
enum ArriveButton {
  /// Within 200 m, or no fix yet (the tap takes a GPS fix and decides).
  ready,

  /// Farther than 200 m with a fix worse than 100 m: the tap may force it.
  poorAccuracy,

  /// Farther than 200 m with a good fix: disabled, "Còn cách …".
  far,
}

ArriveButton arriveButtonOf(InstantRequest r, LocationFix? fix) {
  if (fix == null || metresToMeetPoint(r, fix) <= kArriveRadiusM) {
    return ArriveButton.ready;
  }
  return fix.accuracyM > kPoorAccuracyM
      ? ArriveButton.poorAccuracy
      : ArriveButton.far;
}

/// How an arrival attempt ended.
sealed class ArrivalOutcome {
  const ArrivalOutcome();
}

/// `arrive` was accepted.
final class Arrived extends ArrivalOutcome {
  const Arrived();
}

/// Too far by a fix worse than 100 m: ask before `arrive(force: true)`.
final class ArrivalNeedsForce extends ArrivalOutcome {
  const ArrivalNeedsForce(this.fix);
  final LocationFix fix;
}

/// Too far by a good fix (the button now shows how far).
final class ArrivalTooFar extends ArrivalOutcome {
  const ArrivalTooFar(this.metres);
  final double metres;
}

/// No fix at all (permission gone, no signal).
final class ArrivalNoFix extends ArrivalOutcome {
  const ArrivalNoFix();
}

class InstantJobUi {
  const InstantJobUi({this.fix, this.permission, this.busy});

  /// The latest fix (route samples, or the arrival's GPS fix). In memory only.
  final LocationFix? fix;

  /// Null until checked; anything but granted shows `jobLocationNeeded`.
  final LocationPermissionStatus? permission;

  /// The job call in flight; every action button waits for it.
  final InstantJobAction? busy;

  bool get locationDenied =>
      permission != null && permission != LocationPermissionStatus.granted;

  InstantJobUi copyWith({
    LocationFix? fix,
    LocationPermissionStatus? permission,
    InstantJobAction? busy,
    bool clearBusy = false,
    bool clearFix = false,
  }) => InstantJobUi(
    fix: clearFix ? null : (fix ?? this.fix),
    permission: permission ?? this.permission,
    busy: clearBusy ? null : (busy ?? this.busy),
  );
}

/// Owns one S14.03: starts the route on the first fix while `assigned`,
/// shares the track only while `en_route` and the app is in the foreground,
/// and runs the job actions. Calls rethrow their error for the screen's toast.
class InstantJobController extends Notifier<InstantJobUi> {
  InstantJobController(this.requestId);

  final String requestId;

  RouteTracker? _tracker;
  bool _foreground = true;
  bool _startingRoute = false;

  /// Retries `start_route` while the request stays `assigned`.
  Timer? _routeRetry;

  /// An arrival is in flight or done: no track may start again.
  bool _arriving = false;
  bool _arrived = false;

  /// The point `start_route` sent: the server wrote it as the first track point.
  LocationFix? _routeFix;
  InstantStatus? _status;

  @override
  InstantJobUi build() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    ref.onDispose(() {
      _tracker?.stop();
      _routeRetry?.cancel();
    });
    ref.listen<AsyncValue<InstantRequest?>>(
      instantRequestProvider(requestId),
      (_, next) => _onRequest(next.value),
      fireImmediately: true,
    );
    return const InstantJobUi();
  }

  LocationRepository get _location => ref.read(locationRepositoryProvider);

  void _onRequest(InstantRequest? r) {
    _status = r?.status;
    unawaited(_follow());
  }

  /// Puts the route and the track where the status says.
  Future<void> _follow() async {
    final status = _status;
    final routing =
        _foreground &&
        (status == InstantStatus.assigned || status == InstantStatus.enRoute);
    if (!routing) {
      _tracker?.stop();
      _cancelRouteRetry();
      return;
    }
    final permission = await _location.permissionStatus();
    if (!ref.mounted) return;
    if (permission != LocationPermissionStatus.granted) {
      // Revoked mid-route too: no stale position on the map or the button.
      _tracker?.stop();
      _cancelRouteRetry();
      state = state.copyWith(permission: permission, clearFix: true);
      return;
    }
    if (permission != state.permission) {
      state = state.copyWith(permission: permission);
    }
    if (_status == InstantStatus.assigned) {
      await _startRoute();
    } else if (_status == InstantStatus.enRoute &&
        _foreground &&
        !_arriving &&
        !_arrived) {
      _cancelRouteRetry();
      final tracker = _tracker ??= RouteTracker(
        location: _location,
        repo: ref.read(instantRepositoryProvider),
        requestId: requestId,
        now: ref.read(clockProvider),
        onFix: (fix) {
          if (ref.mounted) state = state.copyWith(fix: fix);
        },
        // Maybe the permission went: check, so the screen says so.
        onNoFix: () {
          if (ref.mounted) unawaited(_follow());
        },
      );
      final sent = _routeFix;
      _routeFix = null;
      tracker.start(sent: sent);
    }
  }

  void _cancelRouteRetry() {
    _routeRetry?.cancel();
    _routeRetry = null;
  }

  /// Tries `start_route` again after [kRouteRetry] with a fresh fix, unless
  /// the request moved on by then ([_follow] checks).
  void _retryRouteLater() {
    _routeRetry?.cancel();
    _routeRetry = Timer(kRouteRetry, () {
      _routeRetry = null;
      if (ref.mounted) unawaited(_follow());
    });
  }

  /// `start_route` with the first fix (the server writes it as the track).
  /// No fix or a refusal: tried again on the cadence while still `assigned`.
  Future<void> _startRoute() async {
    if (_startingRoute || _arriving || _arrived) return;
    _startingRoute = true;
    try {
      final fix = await _location.currentFix();
      if (!ref.mounted) return;
      if (fix == null) {
        _retryRouteLater();
        return;
      }
      state = state.copyWith(fix: fix);
      // Set first: the en_route snapshot may arrive before the call returns.
      _routeFix = fix;
      await ref
          .read(instantRepositoryProvider)
          .updateJob(
            requestId,
            InstantJobAction.startRoute,
            location: (lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM),
          );
    } on Object catch (e) {
      _routeFix = null;
      debugPrint('instant start_route failed: ${instantErrorCodeOf(e)}');
      if (ref.mounted) _retryRouteLater();
    } finally {
      _startingRoute = false;
    }
  }

  /// App to the background: no fixes, no track; back: resume (Decision 10's
  /// foreground-only rule, no background location).
  void setForeground(bool foreground) {
    if (foreground == _foreground) return;
    _foreground = foreground;
    unawaited(_follow());
  }

  /// "Cho phép": asks the OS again, or opens Settings when it no longer can.
  Future<void> askLocation() async {
    final status = state.permission;
    if (status == LocationPermissionStatus.deniedForever ||
        status == LocationPermissionStatus.serviceOff) {
      await _location.openSettings();
      return;
    }
    try {
      await _location.request();
    } on Object catch (e) {
      debugPrint('instant location request failed: ${e.runtimeType}');
    }
    if (!ref.mounted) return;
    await _follow();
  }

  /// "Đã đến": one GPS-grade fix (the only `highAccuracy` use), then the
  /// 200 m check; a fix worse than 100 m and farther than 200 m asks first.
  Future<ArrivalOutcome> arrive() async {
    final r = ref.read(instantRequestProvider(requestId)).value;
    if (r == null || state.busy != null) return const ArrivalNoFix();
    state = state.copyWith(busy: InstantJobAction.arrive);
    try {
      final fix = await _location.currentFix(highAccuracy: true) ?? state.fix;
      if (!ref.mounted) return const ArrivalNoFix();
      if (fix == null) return const ArrivalNoFix();
      state = state.copyWith(fix: fix);
      final metres = metresToMeetPoint(r, fix);
      if (metres <= kArriveRadiusM) {
        await _arrive(fix);
        return const Arrived();
      }
      if (fix.accuracyM > kPoorAccuracyM) return ArrivalNeedsForce(fix);
      return ArrivalTooFar(metres);
    } finally {
      if (ref.mounted) state = state.copyWith(clearBusy: true);
    }
  }

  /// "Xác nhận đã đến" in the GPS sheet: `arrive(force: true)` with that fix
  /// and its real accuracy (the server checks it is worse than 100 m).
  Future<void> forceArrive(LocationFix fix) =>
      _run(InstantJobAction.arrive, () => _arrive(fix, force: true));

  /// `arrive`; a request still `assigned` (its `start_route` never went
  /// through) gets `start_route` with the same fix first, since the server
  /// only accepts an arrival from `en_route`. A `conflict` there means the
  /// route already started: go on.
  Future<void> _arrive(LocationFix fix, {bool force = false}) async {
    _arriving = true;
    try {
      if (_status == InstantStatus.assigned) {
        _cancelRouteRetry();
        try {
          await _update(InstantJobAction.startRoute, fix: fix);
        } on Object catch (e) {
          if (InstantError(instantErrorCodeOf(e)).kind !=
              InstantErrorKind.conflict) {
            rethrow;
          }
        }
      }
      await _update(InstantJobAction.arrive, fix: fix, force: force);
      _arrived = true;
    } finally {
      _arriving = false;
      // Refused: the route (or its retry) carries on where it was.
      if (!_arrived && ref.mounted) unawaited(_follow());
    }
  }

  Future<void> startShoot() =>
      _run(InstantJobAction.start, () => _update(InstantJobAction.start));

  Future<void> finish() =>
      _run(InstantJobAction.finish, () => _update(InstantJobAction.finish));

  Future<void> noShow() =>
      _run(InstantJobAction.noShow, () => _update(InstantJobAction.noShow));

  /// The server's split for a no-show (#202): what the confirm sheet shows.
  Future<InstantCancelQuote> noShowQuote() =>
      ref.read(instantRepositoryProvider).noShowQuote(requestId);

  /// The shoot countdown reached zero: let the server settle the timer.
  Future<void> tick() async {
    try {
      await ref.read(instantRepositoryProvider).tick(requestId);
    } on Object catch (e) {
      debugPrint('instant tick failed: ${instantErrorCodeOf(e)}');
    }
  }

  Future<void> _run(
    InstantJobAction action,
    Future<void> Function() call,
  ) async {
    if (state.busy != null) return;
    state = state.copyWith(busy: action);
    try {
      await call();
    } finally {
      if (ref.mounted) state = state.copyWith(clearBusy: true);
    }
  }

  Future<void> _update(
    InstantJobAction action, {
    LocationFix? fix,
    bool force = false,
  }) async {
    await ref
        .read(instantRepositoryProvider)
        .updateJob(
          requestId,
          action,
          location: fix == null
              ? null
              : (lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM),
          force: force,
        );
    // Arrival ends the sharing at once (the server deletes the track).
    if (action == InstantJobAction.arrive) _tracker?.stop();
  }
}

final instantJobControllerProvider = NotifierProvider.autoDispose
    .family<InstantJobController, InstantJobUi, String>(
      InstantJobController.new,
    );
