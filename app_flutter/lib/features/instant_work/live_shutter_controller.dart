// S14.01: the photographer's Live Shutter state, its locks and its actions.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';

/// Switching on needs a position and none came: the OS refused this time
/// (it can still ask again), or no fix arrived (location off, timeout). The
/// screen says so with the location line; nothing is locked.
class LiveShutterNoLocation implements Exception {
  const LiveShutterNoLocation();
}

/// What S14.01 shows.
class LiveShutterView {
  const LiveShutterView({
    required this.presence,
    required this.config,
    this.reasons = const [],
    this.busy = false,
  });

  /// The own presence; null before the first save.
  final LiveShutterState? presence;
  final InstantConfig config;

  /// Why it cannot be switched on, in [LiveShutterReason] order: the
  /// server's dry run on open (or its answer to a switch-on) plus the app's
  /// own [LiveShutterReason.locationRequired].
  final List<LiveShutterReason> reasons;

  /// A call is in flight; every control waits for it.
  final bool busy;

  bool get online => presence?.online ?? false;

  bool get priceListAccepted =>
      presence?.priceListVersion == config.priceListVersion;

  /// Reasons that lock the switch (S14.01-locked). The price list has its own
  /// state (S14.01-terms), read from the presence; being outside the area is
  /// listed but leaves the switch usable, since the photographer may move.
  List<LiveShutterReason> get blocking => [
    for (final r in reasons)
      if (r != LiveShutterReason.priceListNotAccepted &&
          r != LiveShutterReason.outsideServiceArea)
        r,
  ];

  /// The rows of "Chưa bật được Live Shutter"; the price list is a row only
  /// while another reason locks the switch (otherwise it is the terms state,
  /// whose footer already has "Đồng ý bảng giá": never two of them).
  List<LiveShutterReason> get reasonRows {
    if (online) return const [];
    final other = reasons.where(
      (r) => r != LiveShutterReason.priceListNotAccepted,
    );
    if (other.isEmpty) return const [];
    return [
      for (final r in LiveShutterReason.values)
        if (r == LiveShutterReason.priceListNotAccepted
            ? !priceListAccepted && locked
            : reasons.contains(r))
          r,
    ];
  }

  bool get locked => !online && blocking.isNotEmpty;

  /// Offline with the current price list not yet accepted.
  bool get needsTerms => !online && !priceListAccepted;

  /// The switch takes a tap: always to switch off, to switch on only when
  /// nothing locks it and the price list is accepted.
  bool get canSwitch => !busy && (online || (!locked && priceListAccepted));

  LiveShutterView withPresence(LiveShutterState? p) => LiveShutterView(
    presence: p,
    config: config,
    reasons: reasons,
    busy: busy,
  );

  LiveShutterView copyWith({List<LiveShutterReason>? reasons, bool? busy}) =>
      LiveShutterView(
        presence: presence,
        config: config,
        reasons: reasons ?? this.reasons,
        busy: busy ?? this.busy,
      );
}

List<LiveShutterReason> _ordered(Iterable<LiveShutterReason> rs) {
  final set = rs.toSet();
  return [
    for (final r in LiveShutterReason.values)
      if (set.contains(r)) r,
  ];
}

/// Owns S14.01. Every state change is a callable; the presence stream
/// brings the result back (online, price list, helpReady). A failed call
/// leaves the previous state and rethrows its [InstantError] for the toast.
class LiveShutterController extends AsyncNotifier<LiveShutterView> {
  bool _primerAsked = false;

  @override
  Future<LiveShutterView> build() async {
    _primerAsked = false;
    ref.listen(livePresenceProvider, (_, next) {
      final v = state.value;
      if (v != null && next.hasValue) {
        state = AsyncData(v.withPresence(next.value));
      }
    });
    final config = await ref.watch(instantConfigProvider.future);
    final presence = await ref.read(livePresenceProvider.future);
    final repo = ref.read(instantRepositoryProvider);
    final server = await repo.setLiveShutter(online: true, dryRun: true);
    final location = await _locationReason();
    // The presence may have moved on while the dry run was out.
    final latest = ref.read(livePresenceProvider);
    return LiveShutterView(
      presence: latest.hasValue ? latest.value : presence,
      config: config,
      reasons: _ordered([...server, ?location]),
    );
  }

  LocationRepository get _location => ref.read(locationRepositoryProvider);

  /// A lock with "Mở cài đặt" only when the OS will not ask again (refused
  /// for good, or location off). Never asked or refused once is not a lock:
  /// switching on asks.
  Future<LiveShutterReason?> _locationReason() async =>
      _locks(await _location.permissionStatus())
      ? LiveShutterReason.locationRequired
      : null;

  static bool _locks(LocationPermissionStatus s) =>
      s == LocationPermissionStatus.deniedForever ||
      s == LocationPermissionStatus.serviceOff;

  void _settle({List<LiveShutterReason>? reasons}) {
    final v = state.value;
    if (v == null || !ref.mounted) return;
    state = AsyncData(v.copyWith(busy: false, reasons: reasons));
  }

  /// Starts a call, or returns null when one is already running.
  LiveShutterView? _begin() {
    final v = state.value;
    if (v == null || v.busy) return null;
    state = AsyncData(v.copyWith(busy: true));
    return v;
  }

  /// Re-reads the location permission (back from the Settings app).
  Future<void> refreshLocation() async {
    final v = state.value;
    if (v == null) return;
    final location = await _locationReason();
    final now = state.value;
    if (now == null || !ref.mounted) return;
    state = AsyncData(
      now.copyWith(
        reasons: _ordered([
          ...now.reasons.where((r) => r != LiveShutterReason.locationRequired),
          ?location,
        ]),
      ),
    );
  }

  /// On: permission → a fix → `setLiveShutter(online, location)`, then
  /// [askPrimer] after the first successful switch-on. A refusal shows its
  /// reasons and leaves the switch off; no position throws
  /// [LiveShutterNoLocation]. Off: `setLiveShutter(online: false)`.
  Future<void> setOnline(bool on, {Future<void> Function()? askPrimer}) async {
    final v = _begin();
    if (v == null) return;
    final repo = ref.read(instantRepositoryProvider);
    try {
      if (!on) {
        await repo.setLiveShutter(online: false);
        _settle();
        return;
      }
      var status = await _location.permissionStatus();
      if (status == LocationPermissionStatus.notAsked ||
          status == LocationPermissionStatus.denied) {
        try {
          status = await _location.request();
        } on Object {
          status = LocationPermissionStatus.denied;
        }
      }
      if (_locks(status)) {
        _settle(
          reasons: _ordered([...v.reasons, LiveShutterReason.locationRequired]),
        );
        return;
      }
      if (status != LocationPermissionStatus.granted) {
        throw const LiveShutterNoLocation();
      }
      // The presence carries the fix's real accuracy (the server trusts it).
      final fix = await _location.currentFix();
      if (fix == null) throw const LiveShutterNoLocation();
      final reasons = await repo.setLiveShutter(
        online: true,
        location: (lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM),
      );
      _settle(reasons: _ordered(reasons));
      if (reasons.isEmpty && !_primerAsked && askPrimer != null) {
        _primerAsked = true;
        await askPrimer();
      }
    } on Object {
      _settle();
      rethrow;
    }
  }

  /// "Sẵn sàng hỗ trợ".
  Future<void> setHelpReady(bool on) async {
    if (_begin() == null) return;
    try {
      await ref.read(instantRepositoryProvider).saveSettings(helpReady: on);
      _settle();
    } on Object {
      _settle();
      rethrow;
    }
  }

  /// "Đồng ý bảng giá": accepts the version on screen. A newer list on the
  /// server (`price_changed`) reloads the config so the new one is shown.
  Future<void> acceptPriceList() async {
    final v = _begin();
    if (v == null) return;
    try {
      await ref
          .read(instantRepositoryProvider)
          .saveSettings(acceptPriceListVersion: v.config.priceListVersion);
      _settle(
        reasons: [
          for (final r in v.reasons)
            if (r != LiveShutterReason.priceListNotAccepted) r,
        ],
      );
    } on Object catch (e) {
      _settle();
      if (e is InstantError && e.kind == InstantErrorKind.priceChanged) {
        ref.invalidate(instantConfigProvider);
      }
      rethrow;
    }
  }
}

final liveShutterControllerProvider =
    AsyncNotifierProvider.autoDispose<LiveShutterController, LiveShutterView>(
      LiveShutterController.new,
    );
